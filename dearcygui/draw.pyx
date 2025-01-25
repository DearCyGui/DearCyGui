#!python
#cython: language_level=3
#cython: boundscheck=False
#cython: wraparound=False
#cython: nonecheck=False
#cython: embedsignature=False
#cython: cdivision=True
#cython: cdivision_warnings=False
#cython: always_allow_keywords=False
#cython: profile=False
#cython: infer_types=False
#cython: initializedcheck=False
#cython: c_line_in_traceback=False
#cython: auto_pickle=False
#distutils: language=c++

from dearcygui.wrapper cimport imgui
from .core cimport baseItem, drawingItem, \
    lock_gil_friendly, draw_drawing_children, read_point, read_coord
from .widget cimport SharedBool, SharedInt, SharedFloat, SharedDouble, \
    SharedColor, SharedInt4, SharedFloat4, SharedDouble4, SharedStr
from .imgui_types cimport \
    unparse_color, parse_color
from .c_types cimport *
from .types cimport child_type, Coord

from libcpp.algorithm cimport swap
from libcpp.cmath cimport atan, atan2, sin, cos, sqrt, trunc, floor, round as cround
from libc.math cimport M_PI, INFINITY
from libc.stdint cimport uint32_t, int32_t
from libcpp cimport bool

import scipy
import scipy.spatial

cdef inline bint is_counter_clockwise(imgui.ImVec2 p1,
                                      imgui.ImVec2 p2,
                                      imgui.ImVec2 p3) noexcept nogil:
    cdef float det = (p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x)
    return det > 0.

cdef class ViewportDrawList(drawingItem):
    """
    A drawing item that renders its children on the viewport's background or foreground.

    This is typically used to draw items that should always be visible,
    regardless of the current window or plot being displayed.

    Attributes:
        front (bool): When True, renders drawings in front of all items. When False, renders behind.
    """
    def __cinit__(self):
        self.element_child_category = child_type.cat_viewport_drawlist
        self.can_have_drawing_child = True
        self._show = True
        self._front = True
    @property
    def front(self):
        """Writable attribute: Display the drawings in front of all items (rather than behind)"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._front
    @front.setter
    def front(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._front = value

    cdef void draw(self, void* unused) noexcept nogil:
        # drawlist is an unused argument set to NULL
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return
        if self.last_drawings_child is None:
            return

        # Reset current drawInfo
        self.context.viewport.in_plot = False
        self.context.viewport.window_pos = make_Vec2(0., 0.)
        self.context.viewport.parent_pos = make_Vec2(0., 0.)
        # TODO: dpi scaling
        self.context.viewport.shifts = [0., 0.]
        self.context.viewport.scales = [1., 1.]
        self.context.viewport.thickness_multiplier = 1.
        self.context.viewport.size_multiplier = 1.

        cdef void* internal_drawlist = \
            imgui.GetForegroundDrawList() if self._front else \
            imgui.GetBackgroundDrawList()
        draw_drawing_children(self, internal_drawlist)


"""
Draw containers
"""

cdef class DrawingList(drawingItem):
    """
    A simple drawing item that renders its children.

    Useful to arrange your items and quickly
    hide/show/delete them by manipulating the list.
    """
    def __cinit__(self):
        self.can_have_drawing_child = True

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return
        draw_drawing_children(self, drawlist)


cdef class DrawingClip(drawingItem):
    """
    A DrawingList, but with clipping.

    By default, all items are submitted to the GPU.
    The GPU handles efficiently clipping items that are outside
    the clipping regions.

    In most cases, that's enough and you don't need
    this item.

    However if you have a really huge amount of drawing
    primitives, the submission can be CPU intensive.
    In this case you might want to skip submitting
    groups of drawing primitives that are known to be
    outside the visible region.

    Another use case, is when you want to have a different
    density of items depending on the zoom level.

    Both the above use-cases can be done manually
    using a DrawingList and setting the show
    attribute programmatically.

    This item enables to do this automatically.

    This item defines a clipping rectangle space-wise
    and zoom-wise. If this clipping rectangle is not
    in the visible space, the children are not rendered.
    """
    def __cinit__(self):
        self.can_have_drawing_child = True
        self._scale_max = 1e300
        self._pmin = [-1e300, -1e300]
        self._pmax = [1e300, 1e300]

    @property
    def pmin(self):
        """
        (xmin, ymin) corner of the rect that
        must be on screen for the children to be rendered.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._pmin)
    @pmin.setter
    def pmin(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._pmin, value)
    @property
    def pmax(self):
        """
        (xmax, ymax) corner of the rect that
        must be on screen for the children to be rendered.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._pmax)
    @pmax.setter
    def pmax(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._pmax, value)

    @property
    def scale_min(self):
        """
        The coordinate space to screen space scaling
        must be strictly above this amount (measured pixel size
        between the coordinate (x=0, y=0) and (x=1, y=0))
        for the children to be rendered.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._scale_min
    @scale_min.setter
    def scale_min(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._scale_min = value
    @property
    def scale_max(self):
        """
        The coordinate space to screen space scaling
        must be lower or equal to this amount (measured pixel size
        between the coordinate (x=0, y=0) and (x=1, y=0))
        for the children to be rendered.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._scale_max
    @scale_max.setter
    def scale_max(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._scale_max = value

    @property
    def no_global_scaling(self):
        """
        By default, the pixel size of scale_min/max
        is multiplied by the global scale in order
        to have the same behaviour of various screens.

        Setting to True this field disables that.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._no_global_scale

    @no_global_scaling.setter
    def no_global_scaling(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._no_global_scale = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return
        if self.last_drawings_child is None:
            return

        cdef float[2] pmin
        cdef float[2] pmax
        cdef double[2] unscaled_p1
        cdef double[2] unscaled_p2
        cdef float[2] p1
        cdef float[2] p2
        cdef float scale

        self.context.viewport.coordinate_to_screen(pmin, self._pmin)
        self.context.viewport.coordinate_to_screen(pmax, self._pmax)

        cdef imgui.ImVec2 rect_min = (<imgui.ImDrawList*>drawlist).GetClipRectMin()
        cdef imgui.ImVec2 rect_max = (<imgui.ImDrawList*>drawlist).GetClipRectMax()
        cdef bint visible = True
        if max(pmin[0], pmax[0]) < rect_min.x:
            visible = False
        elif min(pmin[0], pmax[0]) > rect_max.x:
            visible = False
        elif max(pmin[1], pmax[1]) < rect_min.y:
            visible = False
        elif min(pmin[1], pmax[1]) > rect_max.y:
            visible = False
        else:
            unscaled_p1[0] = 0
            unscaled_p1[1] = 0
            unscaled_p2[0] = 1
            unscaled_p2[1] = 0
            self.context.viewport.coordinate_to_screen(p1, unscaled_p1)
            self.context.viewport.coordinate_to_screen(p2, unscaled_p2)
            scale = p2[0] - p1[0]
            if not(self._no_global_scale):
                scale /= self.context.viewport.global_scale
            if scale <= self._scale_min or scale > self._scale_max:
                visible = False

        if visible:
            # draw children
            draw_drawing_children(self, drawlist)


cdef class DrawingScale(drawingItem):
    """
    A DrawingList, with a change in origin and scaling.
    """
    def __cinit__(self):
        self._scales = [1., 1.]
        self._shifts = [0., 0.]
        self._no_parent_scale = False
        self.can_have_drawing_child = True

    @property
    def scales(self):
        """
        Scales applied to the x and y axes
        for the children.

        Default is (1., 1.).

        Unless no_parent_scale is True,
        when applied, scales multiplies any previous
        scales already set (including plot scales).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._scales)

    @scales.setter
    def scales(self, values):
        if not(hasattr(values, '__len__')) or len(values) != 2:
            raise ValueError(f"Expected tuple, got {values}")
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._scales[0] = values[0]
        self._scales[1] = values[1]

    @property
    def origin(self):
        """
        Position in coordinate space of the
        new origin for the children.

        Default is (0., 0.)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._shifts)

    @origin.setter
    def origin(self, values):
        if not(hasattr(values, '__len__')) or len(values) != 2:
            raise ValueError(f"Expected tuple, got {values}")
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._shifts[0] = values[0]
        self._shifts[1] = values[1]

    @property
    def no_parent_scaling(self):
        """
        Resets any previous scaling to screen space.

        Note origin is still transformed to screen space
        using the parent transform.

        When set to True, the global scale still
        impacts the scaling. Use no_global_scaling to
        disable this behaviour.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._no_parent_scale

    @no_parent_scaling.setter
    def no_parent_scaling(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._no_parent_scale = value

    @property
    def no_global_scaling(self):
        """
        Disables the global scale when no_parent_scaling is True.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._no_global_scale

    @no_global_scaling.setter
    def no_global_scaling(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._no_global_scale = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return
        if self.last_drawings_child is None:
            return

        # save states
        cdef float global_scale = self.context.viewport.global_scale
        cdef double[2] cur_scales = self.context.viewport.scales
        cdef double[2] cur_shifts = self.context.viewport.shifts
        cdef bint cur_in_plot = self.context.viewport.in_plot
        cdef float cur_size_mul = self.context.viewport.size_multiplier
        cdef float cur_thick_mul = self.context.viewport.thickness_multiplier

        cdef float[2] p
        if self._no_parent_scale:
            self.context.viewport.coordinate_to_screen(p, self._shifts)
            self.context.viewport.shifts[0] = <double>p[0]
            self.context.viewport.shifts[1] = <double>p[1]
        else:
            # Doing manually keeps precision and plot transform
            self.context.viewport.shifts[0] = self.context.viewport.shifts[0] + cur_scales[0] * self._shifts[0]
            self.context.viewport.shifts[1] = self.context.viewport.shifts[1] + cur_scales[1] * self._shifts[1]

        if self._no_parent_scale:
            self.context.viewport.scales = self._scales
            if not(self._no_global_scale):
                self.context.viewport.scales[0] = self.context.viewport.scales[0] * global_scale
                self.context.viewport.scales[1] = self.context.viewport.scales[1] * global_scale
                self.context.viewport.thickness_multiplier = global_scale
            else:
                self.context.viewport.thickness_multiplier = 1.
            self.context.viewport.size_multiplier = self.context.viewport.scales[0]
            # Disable using plot transform
            self.context.viewport.in_plot = False
        else:
            self.context.viewport.scales[0] = cur_scales[0] * self._scales[0]
            self.context.viewport.scales[1] = cur_scales[1] * self._scales[1]
            self.context.viewport.size_multiplier = self.context.viewport.size_multiplier * self._scales[0]

        # draw children
        draw_drawing_children(self, drawlist)

        # restore states
        #self.context.viewport.global_scale = global_scale
        self.context.viewport.scales = cur_scales
        self.context.viewport.shifts = cur_shifts
        self.context.viewport.in_plot = cur_in_plot
        self.context.viewport.size_multiplier = cur_size_mul
        self.context.viewport.thickness_multiplier = cur_thick_mul


"""
Useful items
"""

cdef class DrawSplitBatch(drawingItem):
    """
    By default the rendering algorithms tries
    to batch drawing primitives together as much
    as possible. It detects when items need to be
    drawn in separate batches (for instance UI rendering,
    or drawing an image), but it is not always enough.

    When you need to force some items to be
    drawn after others, for instance to have a line
    overlap another, this item will force later items
    to be drawn in separate batches to the previous one.
    """
    cdef void draw(self, void* drawlist) noexcept nogil:
        (<imgui.ImDrawList*>drawlist).AddDrawCmd()


"""
Draw items
"""

cdef class DrawArc(drawingItem):
    """
    Draws an arc in coordinate space.
    
    The arc is defined using SVG-like parameters for compatibility with SVG paths.
    
    Properties
    ----------
    center : tuple (x, y)
        Center point coordinates of the arc in coordinate space
    
    radius : tuple (rx, ry)
        Radii in x and y directions. Controls the ellipse shape:
        - Equal values (rx=ry) create circular arcs
        - Different values create elliptical arcs
    
    start_angle : float
        Starting angle in radians (0 = right, π/2 = down, π = left, 3π/2 = up)
    
    end_angle : float
        Ending angle in radians. Arc is drawn counter-clockwise from start to end
    
    rotation : float
        Rotation of the entire arc around its center point in radians
    
    color : outline color
    
    fill : fill color
    
    thickness : float
        Line thickness in pixels for the arc outline
        
    Examples
    --------
    # Create a quarter circle
    arc = DrawArc(context,
                 center=(0, 0),
                 radius=(100, 100),
                 start_angle=0,
                 end_angle=π/2,
                 rotation=0,
                 color=(255,255,255,255),
                 fill_color=(255,0,0,128),
                 thickness=2.0)
    
    # Create an elliptical arc
    arc = DrawArc(context,
                 center=(0, 0),
                 radius=(200, 100),
                 start_angle=0,
                 end_angle=π,
                 rotation=π/4,
                 color=(255,255,255,255),
                 fill_color=(0,0,0,0),
                 thickness=1.0)
    """
    
    def __cinit__(self):
        self._center = [0., 0.]
        self._radius = [0., 0.]
        self._start_angle = 0.
        self._end_angle = 0.
        self._rotation = 0.
        self._fill = 0
        self._color = 4294967295 # 0xffffffff, white
        self._thickness = 1.0

    @property
    def center(self):
        """Center point"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._center)
    @center.setter
    def center(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._center, value)
        
    @property
    def radius(self):
        """X and Y radii"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._radius)

    @radius.setter
    def radius(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._radius, value)

    @property
    def fill(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self._fill)
        return list(fill)

    @fill.setter
    def fill(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)

    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness

    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)

    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)

    @property
    def start_angle(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._start_angle

    @start_angle.setter
    def start_angle(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._start_angle = value

    @property
    def end_angle(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._end_angle

    @end_angle.setter
    def end_angle(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._end_angle = value

    @property
    def rotation(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._rotation

    @rotation.setter
    def rotation(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._rotation = value


    cdef void draw(self, void* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self._thickness
        thickness *= self.context.viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context.viewport.size_multiplier
        thickness = abs(thickness)

        cdef float[2] center
        self.context.viewport.coordinate_to_screen(center, self._center)
        
        # Convert coordinates to screen space
        cdef float scale = self.context.viewport.size_multiplier
        cdef imgui.ImVec2 radius = imgui.ImVec2(self._radius[0] * scale, self._radius[1] * scale)
        # For convert filling, angles must be increasing
        cdef float start_angle = self._start_angle
        cdef float end_angle = self._end_angle
        if start_angle > end_angle:
            swap(start_angle, end_angle)
        
        # Draw filled arc if fill color has alpha
        if self._fill & imgui.IM_COL32_A_MASK != 0:
            (<imgui.ImDrawList*>drawlist).PathEllipticalArcTo(
                imgui.ImVec2(center[0], center[1]),
                radius,
                self._rotation,
                start_angle,
                end_angle,
                0)
            (<imgui.ImDrawList*>drawlist).PathFillConvex(self._fill)

        # Draw outline
        if self._color & imgui.IM_COL32_A_MASK != 0:
            (<imgui.ImDrawList*>drawlist).PathEllipticalArcTo(
                imgui.ImVec2(center[0], center[1]),
                radius,
                self._rotation,
                start_angle,
                end_angle,
                0)
            (<imgui.ImDrawList*>drawlist).PathStroke(self._color, False, thickness)

cdef class DrawArrow(drawingItem):
    """
    Draws an arrow in coordinate space.

    The arrow consists of a line with a triangle at one end.

    Attributes:
        p1 (tuple): End point coordinates (x, y) 
        p2 (tuple): Start point coordinates (x, y)
        color (list): RGBA color of the arrow
        thickness (float): Line thickness
        size (float): Size of the arrow head
    """
    def __cinit__(self):
        # p1, p2, etc are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._thickness = 1.
        self._size = 4.
    @property
    def p1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._end)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._end, value)
        self.__compute_tip()
    @property
    def p2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._start)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._start, value)
        self.__compute_tip()
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value
        self.__compute_tip()
    @property
    def size(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._size
    @size.setter
    def size(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._size = value
        self.__compute_tip()

    cdef void __compute_tip(self):
        # Copy paste from original code

        cdef double xsi = self._end[0]
        cdef double xfi = self._start[0]
        cdef double ysi = self._end[1]
        cdef double yfi = self._start[1]

        # length of arrow head
        cdef double xoffset = self._size
        cdef double yoffset = self._size

        # get pointer angle w.r.t +X (in radians)
        cdef double angle = 0.0
        if xsi >= xfi and ysi >= yfi:
            angle = atan((ysi - yfi) / (xsi - xfi))
        elif xsi < xfi and ysi >= yfi:
            angle = M_PI + atan((ysi - yfi) / (xsi - xfi))
        elif xsi < xfi and ysi < yfi:
            angle = -M_PI + atan((ysi - yfi) / (xsi - xfi))
        elif xsi >= xfi and ysi < yfi:
            angle = atan((ysi - yfi) / (xsi - xfi))

        cdef double x1 = <double>(xsi - xoffset * cos(angle))
        cdef double y1 = <double>(ysi - yoffset * sin(angle))
        self._corner1 = [x1 - 0.5 * self._size * sin(angle),
                        y1 + 0.5 * self._size * cos(angle)]
        self._corner2 = [x1 + 0.5 * self._size * cos((M_PI / 2.0) - angle),
                        y1 - 0.5 * self._size * sin((M_PI / 2.0) - angle)]

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self._thickness
        thickness *= self.context.viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context.viewport.size_multiplier
        thickness = abs(thickness)

        cdef float[2] tstart
        cdef float[2] tend
        cdef float[2] tcorner1
        cdef float[2] tcorner2
        self.context.viewport.coordinate_to_screen(tstart, self._start)
        self.context.viewport.coordinate_to_screen(tend, self._end)
        self.context.viewport.coordinate_to_screen(tcorner1, self._corner1)
        self.context.viewport.coordinate_to_screen(tcorner2, self._corner2)
        cdef imgui.ImVec2 itstart = imgui.ImVec2(tstart[0], tstart[1])
        cdef imgui.ImVec2 itend  = imgui.ImVec2(tend[0], tend[1])
        cdef imgui.ImVec2 itcorner1 = imgui.ImVec2(tcorner1[0], tcorner1[1])
        cdef imgui.ImVec2 itcorner2 = imgui.ImVec2(tcorner2[0], tcorner2[1])
        (<imgui.ImDrawList*>drawlist).AddTriangleFilled(itend, itcorner1, itcorner2, <imgui.ImU32>self._color)
        (<imgui.ImDrawList*>drawlist).AddLine(itend, itstart, <imgui.ImU32>self._color, thickness)
        (<imgui.ImDrawList*>drawlist).AddTriangle(itend, itcorner1, itcorner2, <imgui.ImU32>self._color, thickness)


cdef class DrawBezierCubic(drawingItem):
    """
    Draws a cubic Bezier curve in coordinate space.

    The curve is defined by four control points.

    Attributes:
        p1 (tuple): First control point coordinates (x, y)
        p2 (tuple): Second control point coordinates (x, y)
        p3 (tuple): Third control point coordinates (x, y)
        p4 (tuple): Fourth control point coordinates (x, y)
        color (list): RGBA color of the curve
        thickness (float): Line thickness
        segments (int): Number of line segments used to approximate the curve
    """
    def __cinit__(self):
        # p1, etc are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._thickness = 0.
        self._segments = 0

    @property
    def p1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p1, value)
    @property
    def p2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p2, value)
    @property
    def p3(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p3, value)
    @property
    def p4(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p4)
    @p4.setter
    def p4(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p4, value)
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value
    @property
    def segments(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._segments
    @segments.setter
    def segments(self, int32_t value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._segments = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self._thickness
        thickness *= self.context.viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context.viewport.size_multiplier
        thickness = abs(thickness)

        cdef float[2] p1
        cdef float[2] p2
        cdef float[2] p3
        cdef float[2] p4
        self.context.viewport.coordinate_to_screen(p1, self._p1)
        self.context.viewport.coordinate_to_screen(p2, self._p2)
        self.context.viewport.coordinate_to_screen(p3, self._p3)
        self.context.viewport.coordinate_to_screen(p4, self._p4)
        cdef imgui.ImVec2 ip1 = imgui.ImVec2(p1[0], p1[1])
        cdef imgui.ImVec2 ip2 = imgui.ImVec2(p2[0], p2[1])
        cdef imgui.ImVec2 ip3 = imgui.ImVec2(p3[0], p3[1])
        cdef imgui.ImVec2 ip4 = imgui.ImVec2(p4[0], p4[1])
        (<imgui.ImDrawList*>drawlist).AddBezierCubic(ip1, ip2, ip3, ip4, <imgui.ImU32>self._color, thickness, self._segments)

cdef class DrawBezierQuadratic(drawingItem):
    """
    Draws a quadratic Bezier curve in coordinate space.

    The curve is defined by three control points.

    Attributes:
        p1 (tuple): First control point coordinates (x, y)
        p2 (tuple): Second control point coordinates (x, y)
        p3 (tuple): Third control point coordinates (x, y)
        color (list): RGBA color of the curve
        thickness (float): Line thickness
        segments (int): Number of line segments used to approximate the curve
    """
    def __cinit__(self):
        # p1, etc are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._thickness = 0.
        self._segments = 0

    @property
    def p1(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p1, value)
    @property
    def p2(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p2, value)
    @property
    def p3(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p3, value)
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value
    @property
    def segments(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._segments
    @segments.setter
    def segments(self, int32_t value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._segments = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self._thickness
        thickness *= self.context.viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context.viewport.size_multiplier
        thickness = abs(thickness)

        cdef float[2] p1
        cdef float[2] p2
        cdef float[2] p3
        self.context.viewport.coordinate_to_screen(p1, self._p1)
        self.context.viewport.coordinate_to_screen(p2, self._p2)
        self.context.viewport.coordinate_to_screen(p3, self._p3)
        cdef imgui.ImVec2 ip1 = imgui.ImVec2(p1[0], p1[1])
        cdef imgui.ImVec2 ip2 = imgui.ImVec2(p2[0], p2[1])
        cdef imgui.ImVec2 ip3 = imgui.ImVec2(p3[0], p3[1])
        (<imgui.ImDrawList*>drawlist).AddBezierQuadratic(ip1, ip2, ip3, <imgui.ImU32>self._color, thickness, self._segments)

cdef class DrawCircle(drawingItem):
    """
    Draws a circle in coordinate space.

    The circle can be filled and/or outlined.

    Attributes:
        center (tuple): Center coordinates (x, y)
        radius (float): Circle radius
        color (list): RGBA color of the outline
        fill (list): RGBA color of the fill
        thickness (float): Outline thickness
        segments (int): Number of segments used to approximate the circle
    """
    def __cinit__(self):
        # center is zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._fill = 0
        self._radius = 1.
        self._thickness = 1.
        self._segments = 0

    @property
    def center(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._center)
    @center.setter
    def center(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._center, value)
    @property
    def radius(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._radius
    @radius.setter
    def radius(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._radius = value
    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def fill(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self._fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value
    @property
    def segments(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._segments
    @segments.setter
    def segments(self, int32_t value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._segments = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self._thickness
        cdef float radius = self._radius
        thickness *= self.context.viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context.viewport.size_multiplier
        if radius > 0:
            radius *= self.context.viewport.size_multiplier
        else:
            radius *= self.context.viewport.global_scale
        thickness = abs(thickness)
        radius = abs(radius)

        cdef float[2] center
        self.context.viewport.coordinate_to_screen(center, self._center)
        cdef imgui.ImVec2 icenter = imgui.ImVec2(center[0], center[1])
        if self._fill & imgui.IM_COL32_A_MASK != 0:
            (<imgui.ImDrawList*>drawlist).AddCircleFilled(icenter, radius, <imgui.ImU32>self._fill, self._segments)
        (<imgui.ImDrawList*>drawlist).AddCircle(icenter, radius, <imgui.ImU32>self._color, self._segments, thickness)


cdef class DrawEllipse(drawingItem):
    """
    Draws an ellipse in coordinate space.

    The ellipse is defined by its bounding box and can be filled and/or outlined.

    Attributes:
        pmin (tuple): Top-left corner coordinates (x, y)
        pmax (tuple): Bottom-right corner coordinates (x, y)
        color (list): RGBA color of the outline
        fill (list): RGBA color of the fill
        thickness (float): Outline thickness
        segments (int): Number of segments used to approximate the ellipse
    """
    # TODO: I adapted the original code,
    # But these deserves rewrite: call the imgui Ellipse functions instead
    # and add rotation parameter
    def __cinit__(self):
        # pmin/pmax is zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._fill = 0
        self._thickness = 1.
        self._segments = 0
    @property
    def pmin(self):
        """
        Top-left corner position of the drawing in coordinate space.
        
        Returns:
            tuple: (x, y) coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._pmin)
    @pmin.setter
    def pmin(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._pmin, value)
        self.__fill_points()
    @property
    def pmax(self):
        """
        Bottom-right corner position of the drawing in coordinate space.
        
        Returns:
            tuple: (x, y) coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._pmax)
    @pmax.setter
    def pmax(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._pmax, value)
        self.__fill_points()
    @property
    def color(self):
        """
        Color of the drawing outline.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def fill(self):
        """
        Fill color of the drawing.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self._fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)
    @property
    def thickness(self):
        """
        Line thickness of the drawing outline.
        
        Returns:
            float: Thickness value in pixels
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value
    @property
    def segments(self):
        """
        Number of segments used to approximate the ellipse.
        
        Returns:
            int: Number of segments
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._segments
    @segments.setter
    def segments(self, int32_t value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._segments = value
        self.__fill_points()

    cdef void __fill_points(self):
        cdef int32_t segments = max(self._segments, 3)
        cdef double width = self._pmax[0] - self._pmin[0]
        cdef double height = self._pmax[1] - self._pmin[1]
        cdef double cx = width / 2. + self._pmin[0]
        cdef double cy = height / 2. + self._pmin[1]
        cdef double radian_inc = (M_PI * 2.) / <double>segments
        self._points.clear()
        self._points.reserve(segments+1)
        cdef int32_t i
        # vector needs double2 rather than double[2]
        cdef double2 p
        width = abs(width)
        height = abs(height)
        for i in range(segments):
            p.p[0] = cx + cos(<double>i * radian_inc) * width / 2.
            p.p[1] = cy - sin(<double>i * radian_inc) * height / 2.
            self._points.push_back(p)
        self._points.push_back(self._points[0])

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show) or self._points.size() < 3:
            return

        cdef float thickness = self._thickness
        thickness *= self.context.viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context.viewport.size_multiplier
        thickness = abs(thickness)

        cdef vector[imgui.ImVec2] transformed_points
        transformed_points.reserve(self._points.size())
        cdef int32_t i
        cdef float[2] p
        for i in range(<int>self._points.size()):
            self.context.viewport.coordinate_to_screen(p, self._points[i].p)
            transformed_points.push_back(imgui.ImVec2(p[0], p[1]))
        # TODO imgui requires clockwise order for correct AA
        # Reverse order if needed
        if self._fill & imgui.IM_COL32_A_MASK != 0:
            (<imgui.ImDrawList*>drawlist).AddConvexPolyFilled(transformed_points.data(),
                                                <int>transformed_points.size(),
                                                self._fill)
        (<imgui.ImDrawList*>drawlist).AddPolyline(transformed_points.data(),
                                    <int>transformed_points.size(),
                                    self._color,
                                    0,
                                    thickness)


cdef class DrawImage(drawingItem):
    """
    Draw an image in coordinate space.

    DrawImage supports three ways to express its position in space:
    - p1, p2, p3, p4, the positions of the corners of the image, in
       a clockwise order
    - pmin and pmax, where pmin = p1, and pmax = p3, and p2/p4
        are automatically set such that the image is parallel
        to the axes.
    - center, direction, width, height for the coordinate of the center,
        the angle of (center, middle of p2 and p3) against the x horizontal axis,
        and the width/height of the image at direction 0.

    uv1/uv2/uv3/uv4 are the normalized texture coordinates at p1/p2/p3/p4

    The systems are similar, but writing to p1/p2/p3/p4 is more expressive
    as it allows to have non-rectangular shapes.
    The last system enables to indicate a size in screen space rather
    than in coordinate space by passing negative values to width and height.
    """

    def __cinit__(self):
        self.uv1 = [0., 0.]
        self.uv2 = [1., 0.]
        self.uv3 = [1., 1.]
        self.uv4 = [0., 1.]
        self._color_multiplier = 4294967295 # 0xffffffff
    @property
    def texture(self):
        """Image content"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._texture
    @texture.setter
    def texture(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(isinstance(value, Texture)) and value is not None:
            raise TypeError("texture must be a Texture")
        self._texture = value
    @property
    def pmin(self):
        """
        Top-left corner position of the drawing in coordinate space.
        
        Returns:
            tuple: (x, y) coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)
    @pmin.setter
    def pmin(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p1, value)
        self._p2[1] = self._p1[1]
        self._p4[0] = self._p1[0]
        self.update_center()
    @property
    def pmax(self):
        """
        Bottom-right corner position of the drawing in coordinate space.
        
        Returns:
            tuple: (x, y) coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p3)
    @pmax.setter
    def pmax(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p3, value)
        self._p2[0] = self._p3[0]
        self._p4[1] = self._p3[1]
        self.update_center()
    @property
    def center(self):
        """
        Center of pmin/pmax
        
        Returns:
            tuple: (x, y) coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._center)
    @center.setter
    def center(self, value):
        """
        Center of pmin/pmax
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._center, value)
        self.update_extremities()
    @property
    def height(self):
        """
        Height of the shape. Negative means screen space.
        
        Returns:
            float: Height value
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._height
    @height.setter
    def height(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._height = value
        self.update_extremities()
    @property
    def width(self):
        """
        Width of the shape. Negative means screen space.
        
        Returns:
            float: Width value
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._width
    @width.setter
    def width(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._width = value
        self.update_extremities()
    @property
    def direction(self):
        """
        Angle of (center, middle of p2/p3) with the horizontal axis
        
        Returns:
            float: Angle in radians
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._direction
    @direction.setter
    def direction(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._direction = value
    @property
    def p1(self):
        """
        Top left corner
        
        Returns:
            tuple: (x, y) coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p1, value)
        self.update_center()
    @property
    def p2(self):
        """
        Top right corner
        
        Returns:
            tuple: (x, y) coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p2, value)
    @property
    def p3(self):
        """
        Bottom right corner
        
        Returns:
            tuple: (x, y) coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p3, value)
        self.update_center()
    @property
    def p4(self):
        """ 
        Bottom left corner
        
        Returns:
            tuple: (x, y) coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p4)
    @p4.setter
    def p4(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p4, value)
    @property
    def uv_min(self):
        """
        Texture coordinate for pmin. Writes to uv1/2/4.
        
        Returns:
            list: UV coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._uv1)
    @uv_min.setter
    def uv_min(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self._uv1, value)
        self._uv2[1] = self._uv1[0]
        self._uv4[0] = self._uv1[1]
    @property
    def uv_max(self):
        """
        Texture coordinate for pmax. Writes to uv2/3/4.
        
        Returns:
            list: UV coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._uv3)
    @uv_max.setter
    def uv_max(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self._uv3, value)
        self._uv2[0] = self._uv3[0]
        self._uv4[1] = self._uv3[1]
    @property
    def uv1(self):
        """
        Texture coordinate for p1
        
        Returns:
            list: UV coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._uv1)
    @uv1.setter
    def uv1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self._uv1, value)
    @property
    def uv2(self):
        """
        Texture coordinate for p2
        
        Returns:
            list: UV coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._uv2)
    @uv2.setter
    def uv2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self._uv2, value)
    @property
    def uv3(self):
        """
        Texture coordinate for p3
        
        Returns:
            list: UV coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._uv3)
    @uv3.setter
    def uv3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self._uv3, value)
    @property
    def uv4(self):
        """
        Texture coordinate for p4
        
        Returns:
            list: UV coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._uv4)
    @uv4.setter
    def uv4(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self._uv4, value)
    @property
    def color_multiplier(self):
        """
        The image is mixed with this color.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color_multiplier
        unparse_color(color_multiplier, self._color_multiplier)
        return list(color_multiplier)
    @color_multiplier.setter
    def color_multiplier(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color_multiplier = parse_color(value)
    @property
    def rounding(self):
        """
        Rounding of the corners of the shape.
        
        If non-zero, the renderered image will be rectangular
        and parallel to the axes.
        (p1/p2/p3/p4 will behave like pmin/pmax)
        
        Returns:
            float: Rounding radius
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._rounding
    @rounding.setter
    def rounding(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._rounding = value

    cdef void update_extremities(self) noexcept nogil:
        cdef double dx = cos(self._direction)
        cdef double dy = sin(self._direction)
        dx = 0.5 * self._width * dx
        dy = 0.5 * self._height * dy
        self._p1[0] = self._center[0] - dx
        self._p1[1] = self._center[1] - dy
        self._p3[0] = self._center[0] + dx
        self._p3[1] = self._center[1] + dy
        self._p2[1] = self._p1[0]
        self._p4[0] = self._p1[1]
        self._p2[0] = self._p3[0]
        self._p4[1] = self._p3[1]

    cdef void update_center(self) noexcept nogil:
        self._center[0] = (self._p1[0] + self._p3[0]) * 0.5
        self._center[1] = (self._p1[1] + self._p3[1]) * 0.5
        cdef double width2 = (self._p1[0] - self._p2[0]) * (self._p1[0] - self._p2[0]) +\
            (self._p1[1] - self._p2[1]) * (self._p1[1] - self._p2[1])
        cdef double height2 = (self._p2[0] - self._p3[0]) * (self._p2[0] - self._p3[0]) +\
            (self._p2[1] - self._p3[1]) * (self._p2[1] - self._p3[1])
        self._width = sqrt(width2)
        self._height = sqrt(height2)
        # center of p2/p3
        cdef double x, y
        x = 0.5 * (self._p2[0] + self._p3[0])
        y = 0.5 * (self._p2[1] + self._p3[1])
        if max(width2, height2) < 1e-60:
            self._direction = 0
        else:
            self._direction = atan2( \
                y - self._center[1],
                x - self._center[0]
                )

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return
        if self._texture is None:
            return
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self._texture.mutex)
        if self._texture.allocated_texture == NULL:
            return

        cdef float[2] p1
        cdef float[2] p2
        cdef float[2] p3
        cdef float[2] p4
        cdef float[2] center
        cdef float dx, dy
        cdef imgui.ImVec2 ip1
        cdef imgui.ImVec2 ip2
        cdef imgui.ImVec2 ip3
        cdef imgui.ImVec2 ip4
        cdef float actual_width
        cdef double actual_height

        if self._width >= 0 and self._height >= 0:
            self.context.viewport.coordinate_to_screen(p1, self._p1)
            self.context.viewport.coordinate_to_screen(p2, self._p2)
            self.context.viewport.coordinate_to_screen(p3, self._p3)
            self.context.viewport.coordinate_to_screen(p4, self._p4)
        else:
            self.context.viewport.coordinate_to_screen(center, self._center)
            actual_width = -self._width
            actual_height = -self._height
            if self._height >= 0 or self._width >= 0:
                self.context.viewport.coordinate_to_screen(p1, self._p1)
                self.context.viewport.coordinate_to_screen(p2, self._p2)
                self.context.viewport.coordinate_to_screen(p3, self._p3)
                if actual_width < 0:
                    # compute the coordinate space width
                    actual_width = sqrt(
                        (p1[0] - p2[0]) * (p1[0] - p2[0]) +\
                        (p1[1] - p2[1]) * (p1[1] - p2[1])
                    )
                else:
                    # compute the coordinate space height
                    actual_height = sqrt(
                        (p2[0] - p3[0]) * (p2[0] - p3[0]) +\
                        (p2[1] - p3[1]) * (p2[1] - p3[1])
                    )
            dx = 0.5 * cos(self._direction) * actual_width
            dy = 0.5 * sin(self._direction) * actual_height
            p1[0] = center[0] - dx
            p1[1] = center[1] - dy
            p3[0] = center[0] + dx
            p3[1] = center[1] + dy
            p2[1] = p1[0]
            p4[0] = p1[1]
            p2[0] = p3[0]
            p4[1] = p3[1]

        ip1 = imgui.ImVec2(p1[0], p1[1])
        ip2 = imgui.ImVec2(p2[0], p2[1])
        ip3 = imgui.ImVec2(p3[0], p3[1])
        ip4 = imgui.ImVec2(p4[0], p4[1])
        cdef imgui.ImVec2 iuv1 = imgui.ImVec2(self._uv1[0], self._uv1[1])
        cdef imgui.ImVec2 iuv2 = imgui.ImVec2(self._uv2[0], self._uv2[1])
        cdef imgui.ImVec2 iuv3 = imgui.ImVec2(self._uv3[0], self._uv3[1])
        cdef imgui.ImVec2 iuv4 = imgui.ImVec2(self._uv4[0], self._uv4[1])

        # TODO: should be ensure clockwise order for ImageQuad ?

        if self._rounding != 0.:
            # AddImageRounded requires ip1.x < ip3.x and ip1.y < ip3.y
            if ip1.x > ip3.x:
                ip1.x, ip3.x = ip3.x, ip1.x
                iuv1.x, iuv3.x = iuv3.x, iuv1.x
            if ip1.y > ip3.y:
                ip1.y, ip3.y = ip3.y, ip1.y
                iuv1.y, iuv3.y = iuv3.y, iuv1.y
            # TODO: we could allow to control what is rounded.
            (<imgui.ImDrawList*>drawlist).AddImageRounded(<imgui.ImTextureID>self._texture.allocated_texture, \
            ip1, ip3, iuv1, iuv3, <imgui.ImU32>self._color_multiplier, self._rounding, imgui.ImDrawFlags_RoundCornersAll)
        else:
            (<imgui.ImDrawList*>drawlist).AddImageQuad(<imgui.ImTextureID>self._texture.allocated_texture, \
                ip1, ip2, ip3, ip4, iuv1, iuv2, iuv3, iuv4, <imgui.ImU32>self._color_multiplier)

cdef class DrawLine(drawingItem):
    """
    A line segment is coordinate space.

    DrawLine supports two ways to express its position in space:
    - p1 and p2 for the coordinate of its extremities
    - center, direction, length for the coordinate of the center,
        the angle of (center, p2) against the x horizontal axis,
        and the segment length.

    Both systems are equivalent and the related fields are always valid.
    The main difference is that length can be set to a negative value,
    to indicate a length in screen space rather than in coordinate space.
    """
    def __cinit__(self):
        # p1, p2 are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._thickness = 1.

    @property
    def p1(self):
        cdef unique_lock[recursive_mutex] m
        """
        Coordinates of one of the extremities of the line segment
        
        Returns:
            tuple: (x, y) coordinates
        """
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p1, value)
        self.update_center()
    @property
    def p2(self):
        """
        Coordinates of one of the extremities of the line segment
        
        Returns:
            tuple: (x, y) coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p2, value)
        self.update_center()

    cdef void update_extremities(self) noexcept nogil:
        cdef double length = abs(self._length)
        cdef double dx = cos(self._direction)
        cdef double dy = sin(self._direction)
        dx = 0.5 * length * dx
        dy = 0.5 * length * dy
        self._p1[0] = self._center[0] - dx
        self._p1[1] = self._center[1] - dy
        self._p2[0] = self._center[0] + dx
        self._p2[1] = self._center[1] + dy

    @property
    def center(self):
        cdef unique_lock[recursive_mutex] m
        """
        Coordinates of the center of the line segment
        
        Returns:
            tuple: (x, y) coordinates
        """
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._center)
    @center.setter
    def center(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._center, value)
        self.update_extremities()
    @property
    def length(self):
        """
        Length of the line segment. Negatives mean screen space.
        
        Returns:
            float: Length value
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._length
    @length.setter
    def length(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._length = value
        self.update_extremities()
    @property
    def direction(self):
        """
        Angle (rad) of the line segment relative to the horizontal axis.
        
        Returns:
            float: Angle in radians
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._direction
    @direction.setter
    def direction(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._direction = value
        self.update_extremities()

    cdef void update_center(self) noexcept nogil:
        self._center[0] = (self._p1[0] + self._p2[0]) * 0.5
        self._center[1] = (self._p1[1] + self._p2[1]) * 0.5
        cdef double length2 = (self._p1[0] - self._p2[0]) * (self._p1[0] - self._p2[0]) +\
            (self._p1[1] - self._p2[1]) * (self._p1[1] - self._p2[1])
        self._length = sqrt(length2)
        if length2 < 1e-60:
            self._direction = 0
        else:
            self._direction = atan2( \
                self._p2[1] - self._center[1],
                self._p2[0] - self._center[0]
                )

    @property
    def color(self):
        cdef unique_lock[recursive_mutex] m
        """
        Color of the drawing outline.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def thickness(self):
        cdef unique_lock[recursive_mutex] m
        """
        Line thickness of the drawing outline.
        
        Returns:
            float: Thickness value in pixels
        """
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self._thickness
        thickness *= self.context.viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context.viewport.size_multiplier
        thickness = abs(thickness)

        cdef float[2] p1
        cdef float[2] p2
        cdef float[2] center
        cdef float dx, dy
        if self._length >= 0:
            self.context.viewport.coordinate_to_screen(p1, self._p1)
            self.context.viewport.coordinate_to_screen(p2, self._p2)
        else:
            self.context.viewport.coordinate_to_screen(center, self._center)
            dx = -0.5 * cos(self._direction) * self._length
            dy = -0.5 * sin(self._direction) * self._length
            p1[0] = center[0] - dx
            p1[1] = center[1] - dy
            p2[0] = center[0] + dx
            p2[1] = center[1] + dy

        cdef imgui.ImVec2 ip1 = imgui.ImVec2(p1[0], p1[1])
        cdef imgui.ImVec2 ip2 = imgui.ImVec2(p2[0], p2[1])
        (<imgui.ImDrawList*>drawlist).AddLine(ip1, ip2, <imgui.ImU32>self._color, thickness)

cdef class DrawPolyline(drawingItem):
    """
    Draws a sequence of connected line segments in coordinate space.

    The line segments connect consecutive points in the given sequence.
    Can optionally be closed to form a complete loop.

    Attributes:
        points (list): List of (x,y) coordinates defining the vertices
        color (list): RGBA color of the lines
        thickness (float): Line thickness
        closed (bool): Whether to connect the last point back to the first
    """
    def __cinit__(self):
        # points is empty init by cython
        self._color = 4294967295 # 0xffffffff
        self._thickness = 1.
        self._closed = False

    @property
    def points(self):
        """
        List of vertex positions defining the shape.
        
        Returns:
            list: List of (x,y) coordinate tuples
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        res = []
        cdef double2 p
        cdef int32_t i
        for i in range(<int>self._points.size()):
            res.append(Coord.build(self._points[i].p))
        return res
    @points.setter
    def points(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef double2 p
        cdef int32_t i
        self._points.clear()
        for i in range(len(value)):
            read_coord(p.p, value[i])
            self._points.push_back(p)
    @property
    def color(self):
        """
        Color of the drawing outline.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def closed(self):
        """
        Whether the shape is closed by connecting first and last points.
        
        Returns:
            bool: True if shape is closed
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._closed
    @closed.setter
    def closed(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._closed = value
    @property
    def thickness(self):
        """
        Line thickness of the drawing outline.
        
        Returns:
            float: Thickness value in pixels
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show) or self._points.size() < 2:
            return

        cdef float thickness = self._thickness
        thickness *= self.context.viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context.viewport.size_multiplier
        thickness = abs(thickness)

        cdef float[2] p
        cdef imgui.ImVec2 ip1
        cdef imgui.ImVec2 ip1_
        cdef imgui.ImVec2 ip2
        self.context.viewport.coordinate_to_screen(p, self._points[0].p)
        ip1 = imgui.ImVec2(p[0], p[1])
        ip1_ = ip1
        # imgui has artifacts for PolyLine when thickness is small.
        # in that case use AddLine
        # For big thickness, use AddPolyline
        cdef int32_t i
        cdef vector[imgui.ImVec2] ipoints
        if thickness < 2.:
            for i in range(1, <int>self._points.size()):
                self.context.viewport.coordinate_to_screen(p, self._points[i].p)
                ip2 = imgui.ImVec2(p[0], p[1])
                (<imgui.ImDrawList*>drawlist).AddLine(ip1, ip2, <imgui.ImU32>self._color, thickness)
                ip1 = ip2
            if self._closed and self._points.size() > 2:
                (<imgui.ImDrawList*>drawlist).AddLine(ip1_, ip2, <imgui.ImU32>self._color, thickness)
        else:
            ipoints.reserve(self._points.size())
            ipoints.push_back(ip1_)
            for i in range(1, <int>self._points.size()):
                self.context.viewport.coordinate_to_screen(p, self._points[i].p)
                ip2 = imgui.ImVec2(p[0], p[1])
                ipoints.push_back(ip2)
            if self._closed:
                ipoints.push_back(ip1_)
            (<imgui.ImDrawList*>drawlist).AddPolyline(ipoints.data(), <int>ipoints.size(), <imgui.ImU32>self._color, self._closed, thickness)


cdef class DrawPolygon(drawingItem):
    """
    Draws a filled polygon in coordinate space.

    The polygon is defined by a sequence of points that form its vertices.
    Can be filled and/or outlined. Non-convex polygons are automatically
    triangulated for proper filling.

    Attributes:
        points (list): List of (x,y) coordinates defining the vertices 
        color (list): RGBA color of the outline
        fill (list): RGBA color of the fill
        thickness (float): Outline thickness
    """
    def __cinit__(self):
        # points is empty init by cython
        self._color = 4294967295 # 0xffffffff
        self._fill = 0
        self._thickness = 1.

    @property
    def points(self):
        """
        List of vertex positions defining the shape.
        
        Returns:
            list: List of (x,y) coordinate tuples
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        res = []
        cdef double2 p
        cdef int32_t i
        for i in range(<int>self._points.size()):
            res.append(Coord.build(self._points[i].p))
        return res
    @points.setter
    def points(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef double2 p
        cdef int32_t i
        self._points.clear()
        for i in range(len(value)):
            read_coord(p.p, value[i])
            self._points.push_back(p)
        self.__triangulate()
    @property
    def color(self):
        """
        Color of the drawing outline.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def fill(self):
        """
        Fill color of the drawing.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self._fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)
    @property
    def thickness(self):
        """
        Line thickness of the drawing outline.
        
        Returns:
            float: Thickness value in pixels
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    # ImGui Polygon fill requires clockwise order and convex polygon.
    # We want to be more lenient -> triangulate
    cdef void __triangulate(self):
        if self._fill & imgui.IM_COL32_A_MASK != 0:
            return
        # TODO: optimize with arrays
        points = []
        cdef int32_t i
        for i in range(<int>self._points.size()):
            # For now perform only in 2D
            points.append([self._points[i].p[0], self._points[i].p[1]])
        # order is counter clock-wise
        self._triangulation_indices = scipy.spatial.Delaunay(points).simplices

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show) or self._points.size() < 2:
            return

        cdef float thickness = self._thickness
        thickness *= self.context.viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context.viewport.size_multiplier
        thickness = abs(thickness)

        cdef float[2] p
        cdef imgui.ImVec2 ip
        cdef vector[imgui.ImVec2] ipoints
        cdef int32_t i
        cdef bint ccw
        ipoints.reserve(self._points.size())
        for i in range(<int>self._points.size()):
            self.context.viewport.coordinate_to_screen(p, self._points[i].p)
            ip = imgui.ImVec2(p[0], p[1])
            ipoints.push_back(ip)

        # Draw interior
        if self._fill & imgui.IM_COL32_A_MASK != 0 and self._triangulation_indices.shape[0] > 0:
            # imgui requires clockwise order + convexity for correct AA
            # The triangulation always returns counter-clockwise
            # but the matrix can change the order.
            # The order should be the same for all triangles, except in plot with log
            # scale.
            for i in range(self._triangulation_indices.shape[0]):
                ccw = is_counter_clockwise(ipoints[self._triangulation_indices[i, 0]],
                                           ipoints[self._triangulation_indices[i, 1]],
                                           ipoints[self._triangulation_indices[i, 2]])
                if ccw:
                    (<imgui.ImDrawList*>drawlist).AddTriangleFilled(ipoints[self._triangulation_indices[i, 0]],
                                                      ipoints[self._triangulation_indices[i, 2]],
                                                      ipoints[self._triangulation_indices[i, 1]],
                                                      self._fill)
                else:
                    (<imgui.ImDrawList*>drawlist).AddTriangleFilled(ipoints[self._triangulation_indices[i, 0]],
                                                      ipoints[self._triangulation_indices[i, 1]],
                                                      ipoints[self._triangulation_indices[i, 2]],
                                                      self._fill)

        # Draw closed boundary
        # imgui requires clockwise order + convexity for correct AA of AddPolyline
        # Thus we only call AddLine
        for i in range(1, <int>self._points.size()):
            (<imgui.ImDrawList*>drawlist).AddLine(ipoints[i-1], ipoints[i], <imgui.ImU32>self._color, thickness)
        if self._points.size() > 2:
            (<imgui.ImDrawList*>drawlist).AddLine(ipoints[0], ipoints[<int>self._points.size()-1], <imgui.ImU32>self._color, thickness)

cdef class DrawQuad(drawingItem):
    """
    Draws a quadrilateral in coordinate space.

    The quad is defined by four corner points in clockwise order.
    Can be filled and/or outlined.

    Attributes:
        p1 (tuple): First corner coordinates (x,y)
        p2 (tuple): Second corner coordinates (x,y)
        p3 (tuple): Third corner coordinates (x,y) 
        p4 (tuple): Fourth corner coordinates (x,y)
        color (list): RGBA color of the outline
        fill (list): RGBA color of the fill
        thickness (float): Outline thickness
    """
    def __cinit__(self):
        # p1, p2, p3, p4 are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._fill = 0
        self._thickness = 1.

    @property
    def p1(self):
        """
        First vertex position in coordinate space.
        
        Returns:
            tuple: (x, y) coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p1, value)
    @property
    def p2(self):
        """
        Second vertex position in coordinate space.
        
        Returns:
            tuple: (x, y) coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p2, value)
    @property
    def p3(self):
        """
        Third vertex position in coordinate space.
        
        Returns:
            tuple: (x, y) coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p3, value)
    @property
    def p4(self):
        """ 
        Fourth vertex position in coordinate space.
        
        Returns:
            tuple: (x, y) coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p4)
    @p4.setter
    def p4(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p4, value)
    @property
    def color(self):
        """
        Color of the drawing outline.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def fill(self):
        """
        Fill color of the drawing.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self._fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)
    @property
    def thickness(self):
        """
        Line thickness of the drawing outline.
        
        Returns:
            float: Thickness value in pixels
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self._thickness
        thickness *= self.context.viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context.viewport.size_multiplier
        thickness = abs(thickness)

        cdef float[2] p1
        cdef float[2] p2
        cdef float[2] p3
        cdef float[2] p4
        cdef imgui.ImVec2 ip1
        cdef imgui.ImVec2 ip2
        cdef imgui.ImVec2 ip3
        cdef imgui.ImVec2 ip4
        cdef bint ccw

        self.context.viewport.coordinate_to_screen(p1, self._p1)
        self.context.viewport.coordinate_to_screen(p2, self._p2)
        self.context.viewport.coordinate_to_screen(p3, self._p3)
        self.context.viewport.coordinate_to_screen(p4, self._p4)
        ip1 = imgui.ImVec2(p1[0], p1[1])
        ip2 = imgui.ImVec2(p2[0], p2[1])
        ip3 = imgui.ImVec2(p3[0], p3[1])
        ip4 = imgui.ImVec2(p4[0], p4[1])

        # imgui requires clockwise order + convex for correct AA
        if self._fill & imgui.IM_COL32_A_MASK != 0:
            ccw = is_counter_clockwise(ip1,
                                       ip2,
                                       ip3)
            if ccw:
                (<imgui.ImDrawList*>drawlist).AddTriangleFilled(ip1, ip3, ip2, <imgui.ImU32>self._fill)
            else:
                (<imgui.ImDrawList*>drawlist).AddTriangleFilled(ip1, ip2, ip3, <imgui.ImU32>self._fill)
            ccw = is_counter_clockwise(ip1,
                                       ip4,
                                       ip3)
            if ccw:
                (<imgui.ImDrawList*>drawlist).AddTriangleFilled(ip1, ip3, ip4, <imgui.ImU32>self._fill)
            else:
                (<imgui.ImDrawList*>drawlist).AddTriangleFilled(ip1, ip4, ip3, <imgui.ImU32>self._fill)

        (<imgui.ImDrawList*>drawlist).AddLine(ip1, ip2, <imgui.ImU32>self._color, thickness)
        (<imgui.ImDrawList*>drawlist).AddLine(ip2, ip3, <imgui.ImU32>self._color, thickness)
        (<imgui.ImDrawList*>drawlist).AddLine(ip3, ip4, <imgui.ImU32>self._color, thickness)
        (<imgui.ImDrawList*>drawlist).AddLine(ip4, ip1, <imgui.ImU32>self._color, thickness)

cdef class DrawRect(drawingItem):
    """
    Draws a rectangle in coordinate space.

    The rectangle is defined by its min/max corners.
    Can be filled with a solid color, a color gradient, and/or outlined.
    Corners can be rounded.

    Attributes:
        pmin (tuple): Top-left corner coordinates (x,y)
        pmax (tuple): Bottom-right corner coordinates (x,y)
        color (list): RGBA color of the outline
        fill (list): RGBA color for solid fill
        fill_p1/p2/p3/p4 (list): RGBA colors for gradient fill at each corner
        thickness (float): Outline thickness
        rounding (float): Radius of rounded corners
    """
    def __cinit__(self):
        self._pmin = [0., 0.]
        self._pmax = [1., 1.]
        self._color = 4294967295 # 0xffffffff
        self._fill = 0
        self._color_upper_left = 0
        self._color_upper_right = 0
        self._color_bottom_left = 0
        self._color_bottom_right = 0
        self._rounding = 0.
        self._thickness = 1.
        self._multicolor = False

    @property
    def pmin(self):
        """
        Top-left corner position of the drawing in coordinate space.
        
        Returns:
            tuple: (x, y) coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._pmin)
    @pmin.setter
    def pmin(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._pmin, value)
    @property
    def pmax(self):
        """
        Bottom-right corner position of the drawing in coordinate space.
        
        Returns:
            tuple: (x, y) coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._pmax)
    @pmax.setter
    def pmax(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._pmax, value)
    @property
    def color(self):
        """
        Color of the drawing outline.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def fill(self):
        """
        Fill color of the drawing.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self._fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)
        self._color_upper_left = self._fill
        self._color_upper_right = self._fill
        self._color_bottom_right = self._fill
        self._color_bottom_left = self._fill
        self._multicolor = False
    @property
    def fill_p1(self):
        """
        Fill color at point p1 for gradient fills.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color_upper_left
        unparse_color(color_upper_left, self._color_upper_left)
        return list(color_upper_left)
    @fill_p1.setter
    def fill_p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color_upper_left = parse_color(value)
        self._multicolor = True
    @property
    def fill_p2(self):
        """
        Fill color at point p2 for gradient fills.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color_upper_right
        unparse_color(color_upper_right, self._color_upper_right)
        return list(color_upper_right)
    @fill_p2.setter
    def fill_p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color_upper_right = parse_color(value)
        self._multicolor = True
    @property
    def fill_p3(self):
        """
        Fill color at point p3 for gradient fills.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color_bottom_right
        unparse_color(color_bottom_right, self._color_bottom_right)
        return list(color_bottom_right)
    @fill_p3.setter
    def fill_p3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color_bottom_right = parse_color(value)
        self._multicolor = True
    @property
    def fill_p4(self):
        """
        Fill color at point p4 for gradient fills.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color_bottom_left
        unparse_color(color_bottom_left, self._color_bottom_left)
        return list(color_bottom_left)
    @fill_p4.setter
    def fill_p4(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color_bottom_left = parse_color(value)
        self._multicolor = True
    @property
    def thickness(self):
        """
        Line thickness of the drawing outline.
        
        Returns:
            float: Thickness value in pixels
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value
    @property
    def rounding(self):
        """
        Rounding of the corners of the shape.
        
        Returns:
            float: Rounding radius
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._rounding
    @rounding.setter
    def rounding(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._rounding = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float rounding = self._rounding
        cdef float thickness = self._thickness
        thickness *= self.context.viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context.viewport.size_multiplier
        thickness = abs(thickness)

        cdef float[2] pmin
        cdef float[2] pmax
        cdef imgui.ImVec2 ipmin
        cdef imgui.ImVec2 ipmax
        cdef imgui.ImU32 col_up_left = self._color_upper_left
        cdef imgui.ImU32 col_up_right = self._color_upper_right
        cdef imgui.ImU32 col_bot_left = self._color_bottom_left
        cdef imgui.ImU32 col_bot_right = self._color_bottom_right

        self.context.viewport.coordinate_to_screen(pmin, self._pmin)
        self.context.viewport.coordinate_to_screen(pmax, self._pmax)
        ipmin = imgui.ImVec2(pmin[0], pmin[1])
        ipmax = imgui.ImVec2(pmax[0], pmax[1])

        # imgui requires clockwise order + convex for correct AA
        # The transform might invert the order
        if ipmin.x > ipmax.x:
            swap(ipmin.x, ipmax.x)
            swap(col_up_left, col_up_right)
            swap(col_bot_left, col_bot_right)
        if ipmin.y > ipmax.y:
            swap(ipmin.y, ipmax.y)
            swap(col_up_left, col_bot_left)
            swap(col_up_right, col_bot_right)


        if self._multicolor:
            if col_up_left == col_up_right and \
               col_up_left == col_bot_left and \
               col_up_left == col_up_right:
                self._fill = col_up_left
                self._multicolor = False

        if self._multicolor:
            if (col_up_left|col_up_right|col_bot_left|col_up_right) & imgui.IM_COL32_A_MASK != 0:
                (<imgui.ImDrawList*>drawlist).AddRectFilledMultiColor(ipmin,
                                                 ipmax,
                                                 col_up_left,
                                                 col_up_right,
                                                 col_bot_right,
                                                 col_bot_left)
                rounding = 0
        else:
            if self._fill & imgui.IM_COL32_A_MASK != 0:
                (<imgui.ImDrawList*>drawlist).AddRectFilled(ipmin,
                                       ipmax,
                                       self._fill,
                                       rounding,
                                       imgui.ImDrawFlags_RoundCornersAll)

        (<imgui.ImDrawList*>drawlist).AddRect(ipmin,
                                ipmax,
                                self._color,
                                rounding,
                                imgui.ImDrawFlags_RoundCornersAll,
                                thickness)


cdef class DrawRegularPolygon(drawingItem):
    """
    Draws a regular polygon with n points

    The polygon is defined by the center,
    the direction of the first point, and
    the radius.

    Radius can be negative to mean screen space.
    """
    def __cinit__(self):
        # p1, p2 are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._thickness = 1.
        self._num_points = 1

    @property
    def center(self):
        cdef unique_lock[recursive_mutex] m
        """
        Coordinates of the center of the shape
        
        Returns:
            tuple: (x, y) coordinates
        """
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._center)
    @center.setter
    def center(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._center, value)
    @property
    def radius(self):
        """
        Radius of the shape. Negative means screen space.
        
        Returns:
            float: Radius value
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._radius
    @radius.setter
    def radius(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._radius = value
    @property
    def direction(self):
        """
        Angle (rad) of the first point of the shape.

        The angle is relative to the horizontal axis.
        
        Returns:
            float: Angle in radians
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._direction
    @direction.setter
    def direction(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._direction = value
        self._dirty = True
    @property
    def num_points(self):
        """
        Number of points in the shape.
        num_points=1 gives a circle.
        
        Returns:
            int: Number of points
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._num_points
    @num_points.setter
    def num_points(self, int32_t value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._num_points = value
        self._dirty = True
    @property
    def color(self):
        """
        Color of the drawing outline.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def fill(self):
        """
        Fill color of the drawing.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._fill)
        return list(color)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)
    @property
    def thickness(self):
        """
        Line thickness of the drawing outline.
        
        Returns:
            float: Thickness value in pixels
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self._thickness
        thickness *= self.context.viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context.viewport.size_multiplier
        thickness = abs(thickness)
        cdef float radius = self._radius
        cdef int32_t num_points = self._num_points

        if radius == 0 or num_points <= 0:
            return

        # Angle of the first point
        cdef float start_angle = -self._direction # - because inverted y

        cdef float[2] center
        cdef imgui.ImVec2 icenter

        cdef float[2] p
        cdef imgui.ImVec2 ip
        cdef vector[imgui.ImVec2] ipoints
        cdef int32_t i
        cdef float angle
        cdef float2 pp

        if self._dirty and num_points >= 2:
            self._points.clear()
            for i in range(num_points):
                # Similar to imgui draw code, we guarantee
                # increasing angle to force a specific order.
                angle = start_angle + (<float>i / <float>num_points) * (M_PI * 2.)
                pp.p[0] = cos(angle)
                pp.p[1] = sin(angle)
                self._points.push_back(pp)
            self._dirty = False

        if radius < 0:
            # screen space radius
            radius = -radius * self.context.viewport.global_scale
        else:
            radius = radius * self.context.viewport.size_multiplier

        self.context.viewport.coordinate_to_screen(center, self._center)
        icenter = imgui.ImVec2(center[0], center[1])

        if num_points == 1:
            if self._fill & imgui.IM_COL32_A_MASK != 0:
                (<imgui.ImDrawList*>drawlist).AddCircleFilled(icenter, radius, <imgui.ImU32>self._fill, 0)
            (<imgui.ImDrawList*>drawlist).AddCircle(icenter, radius, <imgui.ImU32>self._color, 0, thickness)
            return

        # TODO: imgui does (radius - 0.5) for outline and radius for fill... Should we ? Is it correct with thickness != 1 ?
        ipoints.reserve(self._points.size())
        for i in range(<int>self._points.size()):
            p[0] = center[0] + radius * self._points[i].p[0]
            p[1] = center[1] + radius * self._points[i].p[1]
            ip = imgui.ImVec2(p[0], p[1])
            ipoints.push_back(ip)

        if num_points == 2:
            (<imgui.ImDrawList*>drawlist).AddLine(ipoints[0], ipoints[1], <imgui.ImU32>self._color, thickness)
            return

        if self._fill & imgui.IM_COL32_A_MASK != 0:
            (<imgui.ImDrawList*>drawlist).AddConvexPolyFilled(ipoints.data(), <int>ipoints.size(), <imgui.ImU32>self._fill)
        (<imgui.ImDrawList*>drawlist).AddPolyline(ipoints.data(), <int>ipoints.size(), <imgui.ImU32>self._color, imgui.ImDrawFlags_Closed, thickness)


cdef class DrawStar(drawingItem):
    """
    Draws a star shaped polygon with n points
    on the exterior circle.

    The polygon is defined by the center,
    the direction of the first point, the radius
    of the exterior circle and the inner radius.

    Crosses, astrisks, etc can be obtained using
    a radius of 0.

    Radius can be negative to mean screen space.
    """
    def __cinit__(self):
        # p1, p2 are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._thickness = 1.
        self._num_points = 5
        self._dirty = True

    @property
    def center(self):
        cdef unique_lock[recursive_mutex] m
        """
        Coordinates of the center of the shape
        
        Returns:
            tuple: (x, y) coordinates
        """
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._center)
    @center.setter
    def center(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._center, value)
    @property
    def radius(self):
        """
        Radius of the shape. Negative means screen space.
        
        Returns:
            float: Radius value
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._radius
    @radius.setter
    def radius(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._radius = value
    @property
    def inner_radius(self):
        """
        Radius of the inner shape.
        
        Returns:
            float: Inner radius value
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._inner_radius
    @inner_radius.setter
    def inner_radius(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._inner_radius = value
    @property
    def direction(self):
        """
        Angle (rad) of the first point of the shape.

        The angle is relative to the horizontal axis.
        
        Returns:
            float: Angle in radians
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._direction
    @direction.setter
    def direction(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._direction = value
        self._dirty = True
    @property
    def num_points(self):
        """
        Number of points in the shape.
        Must be >= 3.
        
        Returns:
            int: Number of points
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._num_points
    @num_points.setter
    def num_points(self, int32_t value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._num_points = value
        self._dirty = True
    @property
    def color(self):
        """
        Color of the drawing outline.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def fill(self):
        """
        Fill color of the drawing.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._fill)
        return list(color)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)
    @property
    def thickness(self):
        """
        Line thickness of the drawing outline.
        
        Returns:
            float: Thickness value in pixels
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self._thickness
        thickness *= self.context.viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context.viewport.size_multiplier
        thickness = abs(thickness)
        cdef float radius = self._radius
        cdef float inner_radius = self._inner_radius
        cdef int32_t num_points = self._num_points
        cdef int32_t num_segments = max(1, num_points - 1)

        if radius == 0 or num_points <= 2:
            return

        # In coordinate space. We can't assume that the axis is not in log scale
        # thus we pass the points via the transform, fix later...

        # Angle of the first point
        cdef float angle
        cdef float start_angle = -self._direction # - because inverted y
        cdef float start_angle_inner = -self._direction - M_PI / <float>num_points
        
        cdef float[2] center
        cdef imgui.ImVec2 icenter, ip
        cdef float[2] p
        cdef float2 pp
        cdef int32_t i
        cdef vector[imgui.ImVec2] ipoints
        cdef vector[imgui.ImVec2] inner_ipoints

        if self._dirty:
            self._points.clear()
            for i in range(num_points):
                # Similar to imgui draw code, we guarantee
                # increasing angle to force a specific order.
                angle = start_angle + (<float>i / <float>num_points) * (M_PI * 2.)
                pp.p[0] = cos(angle)
                pp.p[1] = sin(angle)
                self._points.push_back(pp)
            self._inner_points.clear()
            for i in range(num_points):
                # Similar to imgui draw code, we guarantee
                # increasing angle to force a specific order.
                angle = start_angle_inner + (<float>i / <float>num_points) * (M_PI * 2.)
                pp.p[0] = cos(angle)
                pp.p[1] = sin(angle)
                self._inner_points.push_back(pp)
            self._dirty = False

        if radius < 0:
            # screen space radius
            radius = -radius * self.context.viewport.global_scale
            inner_radius = abs(inner_radius) * self.context.viewport.global_scale
        else:
            radius = radius * self.context.viewport.size_multiplier
            inner_radius = abs(inner_radius) * self.context.viewport.size_multiplier
        inner_radius = min(radius, inner_radius)

        self.context.viewport.coordinate_to_screen(center, self._center)
        icenter = imgui.ImVec2(center[0], center[1])

        ipoints.reserve(self._points.size())
        for i in range(<int>self._points.size()):
            p[0] = center[0] + radius * self._points[i].p[0]
            p[1] = center[1] + radius * self._points[i].p[1]
            ip = imgui.ImVec2(p[0], p[1])
            ipoints.push_back(ip)

        if inner_radius == 0.:
            if num_points % 2 == 0:
                for i in range(num_points//2):
                    (<imgui.ImDrawList*>drawlist).AddLine(ipoints[i], ipoints[i+num_points//2], <imgui.ImU32>self._color, thickness)
            else:
                for i in range(num_points):
                    (<imgui.ImDrawList*>drawlist).AddLine(ipoints[i], icenter, <imgui.ImU32>self._color, thickness)
            return

        inner_ipoints.reserve(self._inner_points.size())
        for i in range(<int>self._inner_points.size()):
            p[0] = center[0] + inner_radius * self._inner_points[i].p[0]
            p[1] = center[1] + inner_radius * self._inner_points[i].p[1]
            ip = imgui.ImVec2(p[0], p[1])
            inner_ipoints.push_back(ip)

        if self._fill & imgui.IM_COL32_A_MASK != 0:
            # fill inner region
            (<imgui.ImDrawList*>drawlist).AddConvexPolyFilled(inner_ipoints.data(), <int>inner_ipoints.size(), <imgui.ImU32>self._fill)
            # fill the rest
            for i in range(num_points-1):
                (<imgui.ImDrawList*>drawlist).AddTriangleFilled(ipoints[i],
                                           inner_ipoints[i],
                                           inner_ipoints[i+1],
                                           self._fill)
            (<imgui.ImDrawList*>drawlist).AddTriangleFilled(ipoints[num_points-1],
                                       inner_ipoints[num_points-1],
                                       inner_ipoints[0],
                                       self._fill)

        for i in range(num_points-1):
            (<imgui.ImDrawList*>drawlist).AddLine(ipoints[i], inner_ipoints[i], <imgui.ImU32>self._color, thickness)
            (<imgui.ImDrawList*>drawlist).AddLine(ipoints[i], inner_ipoints[i+1], <imgui.ImU32>self._color, thickness)
        (<imgui.ImDrawList*>drawlist).AddLine(ipoints[num_points-1], inner_ipoints[num_points-1], <imgui.ImU32>self._color, thickness)
        (<imgui.ImDrawList*>drawlist).AddLine(ipoints[num_points-1], inner_ipoints[0], <imgui.ImU32>self._color, thickness)

cdef class DrawText(drawingItem):
    """
    Draws text in coordinate space.

    The text is positioned at a specific point and can use a custom font and size.
    The size can be specified in coordinate space (positive values) or screen space (negative values).

    Attributes:
        pos (tuple): Position coordinates (x,y) of the text
        text (str): The text string to display
        color (list): RGBA color of the text
        font (Font): Optional custom font to use
        size (float): Text size. Negative means screen space units.
    """
    def __cinit__(self):
        self._color = 4294967295 # 0xffffffff
        self._size = 0. # 0: default size. DearPyGui uses 1. internally, then 10. in the wrapper.

    @property
    def pos(self):
        """
        Position of the drawing element in coordinate space.
        
        Returns:
            tuple: (x, y) coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._pos)
    @pos.setter
    def pos(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._pos, value)
    @property
    def color(self):
        """
        Color of the text.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def font(self):
        """
        Writable attribute: font used for the text rendered
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._font

    @font.setter
    def font(self, baseFont value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._font = value

    @property
    def text(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(self._text, encoding='utf-8')
    @text.setter
    def text(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._text = bytes(value, 'utf-8')
    @property
    def size(self):
        """
        Text size. Negative means screen space units.
        
        Returns:
            float: Size value
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._size
    @size.setter
    def size(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._size = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float[2] p

        self.context.viewport.coordinate_to_screen(p, self._pos)
        cdef imgui.ImVec2 ip = imgui.ImVec2(p[0], p[1])
        cdef float size = self._size
        if size > 0:
            size *= self.context.viewport.size_multiplier
        else:
            size *= self.context.viewport.global_scale
        size = abs(size)
        if self._font is not None:
            self._font.push()
        if size == 0:
            (<imgui.ImDrawList*>drawlist).AddText(ip, <imgui.ImU32>self._color, self._text.c_str())
        else:
            (<imgui.ImDrawList*>drawlist).AddText(NULL, size, ip, <imgui.ImU32>self._color, self._text.c_str())
        if self._font is not None:
            self._font.pop()



cdef class DrawTriangle(drawingItem):
    """
    Draws a triangle in coordinate space.

    The triangle is defined by three points.
    Can be filled and/or outlined.

    Attributes:
        p1 (tuple): First vertex coordinates (x,y)
        p2 (tuple): Second vertex coordinates (x,y)
        p3 (tuple): Third vertex coordinates (x,y)
        color (list): RGBA color of the outline
        fill (list): RGBA color of the fill
        thickness (float): Outline thickness 
    """
    def __cinit__(self):
        # p1, p2, p3 are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._fill = 0
        self._thickness = 1.

    @property
    def p1(self):
        """
        First vertex position in coordinate space.
        
        Returns:
            tuple: (x, y) coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p1, value)
    @property
    def p2(self):
        """
        Second vertex position in coordinate space.
        
        Returns:
            tuple: (x, y) coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p2, value)
    @property
    def p3(self):
        """
        Third vertex position in coordinate space.
        
        Returns:
            tuple: (x, y) coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p3, value)
    @property
    def color(self):
        """
        Color of the drawing outline.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def fill(self):
        """
        Fill color of the drawing.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self._fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)
    @property
    def thickness(self):
        """
        Line thickness of the drawing outline.
        
        Returns:
            float: Thickness value in pixels
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = self._thickness
        thickness *= self.context.viewport.thickness_multiplier
        if thickness > 0:
            thickness *= self.context.viewport.size_multiplier
        thickness = abs(thickness)

        cdef float[2] p1
        cdef float[2] p2
        cdef float[2] p3
        cdef imgui.ImVec2 ip1
        cdef imgui.ImVec2 ip2
        cdef imgui.ImVec2 ip3
        cdef bint ccw

        self.context.viewport.coordinate_to_screen(p1, self._p1)
        self.context.viewport.coordinate_to_screen(p2, self._p2)
        self.context.viewport.coordinate_to_screen(p3, self._p3)
        ip1 = imgui.ImVec2(p1[0], p1[1])
        ip2 = imgui.ImVec2(p2[0], p2[1])
        ip3 = imgui.ImVec2(p3[0], p3[1])
        ccw = is_counter_clockwise(ip1,
                                   ip2,
                                   ip3)

        # imgui requires clockwise order + convex for correct AA
        if ccw:
            if self._fill & imgui.IM_COL32_A_MASK != 0:
                (<imgui.ImDrawList*>drawlist).AddTriangleFilled(ip1, ip3, ip2, <imgui.ImU32>self._fill)
            (<imgui.ImDrawList*>drawlist).AddTriangle(ip1, ip3, ip2, <imgui.ImU32>self._color, thickness)
        else:
            if self._fill & imgui.IM_COL32_A_MASK != 0:
                (<imgui.ImDrawList*>drawlist).AddTriangleFilled(ip1, ip2, ip3, <imgui.ImU32>self._fill)
            (<imgui.ImDrawList*>drawlist).AddTriangle(ip1, ip2, ip3, <imgui.ImU32>self._color, thickness)


cdef class DrawValue(drawingItem):
    """
    Draws a SharedValue in coordinate space.

    The text is positioned at a specific point and can use a custom font and size.
    The size can be specified in coordinate space (positive values) or screen space (negative values).

    Unlike TextValue, SharedFloatVect cannot be displayed, however
    SharedStr can be.

    For security reasons, an intermediate buffer of fixed size is used,
    and the limit of characters is currently 256.

    Attributes:
        pos (tuple): Position coordinates (x,y) of the text
        text (str): The text string to display
        color (list): RGBA color of the text
        font (Font): Optional custom font to use
        size (float): Text size. Negative means screen space units.
        shareable_value (SharedValue): SharedValue to display
    """
    def __cinit__(self):
        self._print_format = b"%.3f"
        self._value = <SharedValue>(SharedFloat.__new__(SharedFloat, self.context))
        self._type = 2
        self._color = 4294967295 # 0xffffffff
        self._size = 0. # 0: default size. DearPyGui uses 1. internally, then 10. in the wrapper.

    @property
    def pos(self):
        """
        Position of the drawing element in coordinate space.
        
        Returns:
            tuple: (x, y) coordinates
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._pos)
    @pos.setter
    def pos(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._pos, value)
    @property
    def color(self):
        """
        Color of the text.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
    @property
    def font(self):
        """
        Writable attribute: font used for the text rendered
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._font

    @font.setter
    def font(self, baseFont value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._font = value

    @property
    def text(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(self._text, encoding='utf-8')
    @text.setter
    def text(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._text = bytes(value, 'utf-8')
    @property
    def size(self):
        """
        Text size. Negative means screen space units.
        
        Returns:
            float: Size value
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._size
    @size.setter
    def size(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._size = value

    @property
    def shareable_value(self):
        """
        Same as the value field, but rather than a copy of the internal value
        of the object, return a python object that holds a value field that
        is in sync with the internal value of the object. This python object
        can be passed to other items using an internal value of the same
        type to share it.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._value

    @shareable_value.setter
    def shareable_value(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._value is value:
            return
        if not(isinstance(value, SharedBool) or
               isinstance(value, SharedInt) or
               isinstance(value, SharedFloat) or
               isinstance(value, SharedDouble) or
               isinstance(value, SharedColor) or
               isinstance(value, SharedInt4) or
               isinstance(value, SharedFloat4) or
               isinstance(value, SharedDouble4) or
               isinstance(value, SharedStr)):
            raise ValueError(f"Unsupported type. Received {type(value)}")
        if isinstance(value, SharedBool):
            self._type = 0
        elif isinstance(value, SharedInt):
            self._type = 1
        elif isinstance(value, SharedFloat):
            self._type = 2
        elif isinstance(value, SharedDouble):
            self._type = 3
        elif isinstance(value, SharedColor):
            self._type = 4
        elif isinstance(value, SharedInt4):
            self._type = 5
        elif isinstance(value, SharedFloat4):
            self._type = 6
        elif isinstance(value, SharedDouble4):
            self._type = 7
        elif isinstance(value, SharedStr):
            self._type = 9
        self._value.dec_num_attached()
        self._value = value
        self._value.inc_num_attached()

    @property
    def print_format(self):
        """
        Writable attribute: format string
        for the value -> string conversion
        for display.

        For example:
        %d for a SharedInt
        [%d, %d, %d, %d] for a SharedInt4
        (%f, %f, %f, %f) for a SharedFloat4 or a SharedColor (which are displayed as floats)
        %s for a SharedStr
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(bytes(self._print_format), encoding="utf-8")

    @print_format.setter
    def print_format(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._print_format = bytes(value, 'utf-8')

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._show):
            return

        cdef float[2] p

        self.context.viewport.coordinate_to_screen(p, self._pos)
        cdef imgui.ImVec2 ip = imgui.ImVec2(p[0], p[1])
        cdef float size = self._size
        if size > 0:
            size *= self.context.viewport.size_multiplier
        else:
            size *= self.context.viewport.global_scale
        size = abs(size)
        if self._font is not None:
            self._font.push()

        cdef bool value_bool
        cdef int32_t value_int
        cdef float value_float
        cdef double value_double
        cdef Vec4 value_color
        cdef int32_t[4] value_int4
        cdef float[4] value_float4
        cdef double[4] value_double4
        cdef string value_str

        cdef int32_t ret

        if self._type == 0:
            value_bool = SharedBool.get(<SharedBool>self._value)
            ret = imgui.ImFormatString(self.buffer, 256, self._print_format.c_str(), value_bool)
        elif self._type == 1:
            value_int = SharedInt.get(<SharedInt>self._value)
            ret = imgui.ImFormatString(self.buffer, 256, self._print_format.c_str(), value_int)
        elif self._type == 2:
            value_float = SharedFloat.get(<SharedFloat>self._value)
            ret = imgui.ImFormatString(self.buffer, 256, self._print_format.c_str(), value_float)
        elif self._type == 3:
            value_double = SharedDouble.get(<SharedDouble>self._value)
            ret = imgui.ImFormatString(self.buffer, 256, self._print_format.c_str(), value_double)
        elif self._type == 4:
            value_color = SharedColor.getF4(<SharedColor>self._value)
            ret = imgui.ImFormatString(self.buffer, 256, self._print_format.c_str(), value_color.x, value_color.y, value_color.z, value_color.w)
        elif self._type == 5:
            SharedInt4.get(<SharedInt4>self._value, value_int4)
            ret = imgui.ImFormatString(self.buffer, 256, self._print_format.c_str(), value_int4[0], value_int4[1], value_int4[2], value_int4[3])
        elif self._type == 6:
            SharedFloat4.get(<SharedFloat4>self._value, value_float4)
            ret = imgui.ImFormatString(self.buffer, 256, self._print_format.c_str(), value_float4[0], value_float4[1], value_float4[2], value_float4[3])
        elif self._type == 7:
            SharedDouble4.get(<SharedDouble4>self._value, value_double4)
            ret = imgui.ImFormatString(self.buffer, 256, self._print_format.c_str(), value_double4[0], value_double4[1], value_double4[2], value_double4[3])
        elif self._type == 9:
            SharedStr.get(<SharedStr>self._value, value_str)
            ret = imgui.ImFormatString(self.buffer, 256, self._print_format.c_str(), value_str.c_str())
        # just in case
        self.buffer[255] = 0
        if size == 0:
            (<imgui.ImDrawList*>drawlist).AddText(ip, <imgui.ImU32>self._color, self.buffer)
        else:
            (<imgui.ImDrawList*>drawlist).AddText(NULL, size, ip, <imgui.ImU32>self._color, self.buffer)

        if self._font is not None:
            self._font.pop()