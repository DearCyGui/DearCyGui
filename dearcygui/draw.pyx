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
#cython: freethreading_compatible=True
#distutils: language=c++

from dearcygui.wrapper cimport imgui
from .core cimport drawingItem, \
    lock_gil_friendly, draw_drawing_children
from .widget cimport SharedBool, SharedFloat, \
    SharedColor, SharedStr
from .imgui_types cimport unparse_color, parse_color
from .c_types cimport DCGMutex, DCGString, unique_lock, make_Vec2,\
    string_from_bytes, string_from_str, string_to_str, Vec4
from .types cimport child_type, Coord, read_point, read_coord

from libcpp.algorithm cimport swap
from libcpp.cmath cimport atan, atan2, sin, cos, sqrt, fabs, fmod
from libc.math cimport M_PI
from libc.stdint cimport int32_t
from libcpp cimport bool
from libcpp.vector cimport vector

from .wrapper.delaunator cimport delaunator_get_triangles, DelaunationResult
from .imgui cimport t_draw_polygon, t_draw_polyline,\
    t_draw_elliptical_arc, t_draw_elliptical_pie_slice, t_draw_elliptical_ring_segment,\
    t_draw_elliptical_ring, t_draw_ellipse, draw_regular_polygon,\
    t_draw_line, t_draw_triangle, draw_star, draw_triangle, draw_quad, draw_text_quad,\
    get_scaled_thickness, get_scaled_radius, draw_circle, t_item_fully_clipped


cdef inline bint is_counter_clockwise_array(float[2] p1,
                                            float[2] p2,
                                            float[2] p3) noexcept nogil:
    """
    Determines if three points in array format form a counter-clockwise triangle.
    
    Similar to is_counter_clockwise but works with float[2] arrays instead of ImVec2.
    Used for coordinate calculations where the native array format is more convenient
    than creating temporary ImVec2 objects.
    """
    cdef float det = (p2[0] - p1[0]) * (p3[1] - p1[1]) - (p2[1] - p1[1]) * (p3[0] - p1[0])
    return det > 0.

cdef class ViewportDrawList(drawingItem):
    """
    A drawing item that renders its children on the viewport's background or foreground.

    This is typically used to draw items that should always be visible,
    regardless of the current window or plot being displayed.
    """
    def __cinit__(self):
        self.element_child_category = child_type.cat_viewport_drawlist
        self.can_have_drawing_child = True
        self._show = True
        self._front = True

    @property
    def front(self):
        """Display the drawings in front of all items (rather than behind)"""
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._front
    @front.setter
    def front(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._front = value

    cdef void draw(self, void* unused) noexcept nogil:
        # drawlist is an unused argument set to NULL
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
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

        # Push the current font texture rather than the default one
        # this prevents wrong white uv coordinate and bad font rendering
        cdef imgui.ImFont* cur_font = imgui.GetFont()
        cdef imgui.ImTextureID font_tex_id = cur_font.ContainerAtlas.TexID
        (<imgui.ImDrawList*>internal_drawlist).PushTextureID(font_tex_id)
        draw_drawing_children(self, internal_drawlist)
        (<imgui.ImDrawList*>internal_drawlist).PopTextureID()


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
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
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
        (xmin, ymin) of the clip region

        pmin is the (xmin, ymin) corner of the rect that
        must be on screen for the children to be rendered.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._pmin)
    @pmin.setter
    def pmin(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._pmin, value)

    @property
    def pmax(self):
        """
        (xmax, ymax) of the clip region

        pmax is the (xmax, ymax) corner of the rect that
        must be on screen for the children to be rendered.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._pmax)
    @pmax.setter
    def pmax(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._pmax, value)

    @property
    def scale_min(self):
        """
        Minimum accepted coordinate scaling to screen space.

        The coordinate space to screen space scaling
        must be strictly above this amount. The measured pixel size
        between the coordinate (x=0, y=0) and (x=1, y=0)
        for the children to be rendered.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._scale_min
    @scale_min.setter
    def scale_min(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._scale_min = value

    @property
    def scale_max(self):
        """
        Maximum accepted coordinate scaling to screen space.

        The coordinate space to screen space scaling
        must be lower or equal to this amount. The measured pixel size
        between the coordinate (x=0, y=0) and (x=1, y=0)
        for the children to be rendered.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._scale_max
    @scale_max.setter
    def scale_max(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._scale_max = value

    @property
    def no_global_scaling(self):
        """
        Disable apply global scale to the min/max scaling.

        By default, the pixel size of scale_min/max
        is multiplied by the global scale in order
        to have the same behaviour of various screens.

        Setting to True this field disables that.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._no_global_scale
    @no_global_scaling.setter
    def no_global_scaling(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._no_global_scale = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
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

    DrawingScale can be used to defined a custom
    coordinate system for the children, duplicating
    what can be done with a Plot.

    It can also be used to cheaply apply shifts and
    scaling operations to the children.
    """
    def __cinit__(self):
        self._scales = [1., 1.]
        self._shifts = [0., 0.]
        self._no_parent_scale = False
        self.can_have_drawing_child = True

    @property
    def scales(self):
        """
        Scales (tuple or value) applied to the x and y axes for the children.

        Default is (1., 1.).

        Note unless no_parent_scale is True, the 
        parent scales also apply.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._scales)
    @scales.setter
    def scales(self, values):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef int size = read_point[double](self._scales, values)
        if size == 1:
            self._scales[1] = self._scales[0]
        elif size == 0:
            self._scales[0] = 1.
            self._scales[1] = 1.

    @property
    def origin(self):
        """
        Position in coordinate space of the new origin for the children.

        Default is (0., 0.).
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._shifts)
    @origin.setter
    def origin(self, values):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self._shifts, values)

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
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._no_parent_scale
    @no_parent_scaling.setter
    def no_parent_scaling(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._no_parent_scale = value

    @property
    def no_global_scaling(self):
        """
        Disables the global scale when no_parent_scaling is True.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._no_global_scale
    @no_global_scaling.setter
    def no_global_scaling(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._no_global_scale = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
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
Draw items
"""

cdef class DrawArc(drawingItem):
    """
    Draws an arc in coordinate space.
    
    An arc is a portion of an ellipse defined by its center, radii, start and end angles. 
    The implementation follows SVG-like parametrization allowing both circular and 
    elliptical arcs with optional rotation.
    
    Arcs can be filled and/or outlined with different colors and thickness.
    Negative radius values are interpreted in screen space rather than coordinate space.
    """
    
    def __cinit__(self):
        self._center = [0., 0.]
        self._radius = [0., 0.]
        self._inner_radius = [0., 0.]
        self._start_angle = 0.
        self._end_angle = 0.
        self._rotation = 0.
        self._fill = 0
        self._color = 4294967295 # 0xffffffff, white
        self._thickness = 1.0
        self._segments = 0

    @property
    def center(self):
        """
        Center point of the arc in coordinate space.
        
        This defines the origin around which the arc is drawn. The arc's radii 
        extend from this point.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._center)
    @center.setter
    def center(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._center, value)
        
    @property
    def radius(self):
        """
        X and Y radii of the arc.
        
        Defines the shape of the ellipse from which the arc is drawn:
        - Equal values create a circular arc
        - Different values create an elliptical arc
        - Negative values are interpreted as screen space units rather than coordinate space
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._radius)
    @radius.setter
    def radius(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._radius, value)

    @property
    def inner_radius(self):
        """
        X and Y radii of the inner arc.
        
        Defines the shape of the ellipse from which the arc is drawn:
        - Equal values create a circular arc
        - Different values create an elliptical arc
        - Negative values are interpreted as screen space units rather than coordinate space

        If radius and inner_radius are equal, the shape 
        corresponds to a simple curved line, and the filling will
        join the extremities.

        An inner_radius of (0, 0) is equivalent to a filled arc (from the center)
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._inner_radius)
    @inner_radius.setter
    def inner_radius(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._inner_radius, value)

    @property
    def fill(self):
        """
        Fill color of the arc.
        
        The area between the center, start angle, and end angle is filled with this color.
        Transparency is supported through the alpha channel.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self._fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)

    @property
    def thickness(self):
        """
        Line thickness of the arc outline.
        
        Controls the width of the line along the arc's path. The actual pixel width 
        is affected by the viewport's scale and DPI settings.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    @property
    def pattern(self):
        """
        Pattern of the outline.
        
        Controls the pattern of the line tracing the path.
        None for solid line.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._pattern
    @pattern.setter
    def pattern(self, Pattern value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._pattern = value

    @property
    def color(self):
        """
        Color of the arc outline.
        
        Controls the color of the line tracing the path of the arc. Transparency
        is supported through the alpha channel.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)

    @property
    def start_angle(self):
        """
        Starting angle of the arc in radians.
        
        The angle is measured from the positive x-axis, with positive values going 
        counter-clockwise (0 = right, pi/2 = down, pi = left, 3pi/2 = up).
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._start_angle
    @start_angle.setter
    def start_angle(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._start_angle = value

    @property
    def end_angle(self):
        """
        Ending angle of the arc in radians.
        
        The arc is drawn from start_angle to end_angle in counter-clockwise direction.
        If end_angle is less than start_angle, they are swapped during rendering.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._end_angle
    @end_angle.setter
    def end_angle(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._end_angle = value

    @property
    def rotation(self):
        """
        Rotation of the entire arc around its center in radians.
        
        This allows rotating the ellipse from which the arc is drawn, which is 
        particularly useful for elliptical arcs to control their orientation.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._rotation
    @rotation.setter
    def rotation(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._rotation = value

    @property
    def segments(self):
        """
        Number of segments used to approximate the external
        outline of the shape.
        
        Returns:
            int: Number of segments. 0 for auto.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._segments
    @segments.setter
    def segments(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._segments = max(0, value)

    cdef void draw(self, void* drawlist) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = get_scaled_thickness(self.context, self._thickness)

        cdef float scale = self.context.viewport.size_multiplier
        cdef float radius_x = get_scaled_radius(self.context, self._radius[0])
        cdef float radius_y = get_scaled_radius(self.context, self._radius[1])
        cdef float inner_radius_x = get_scaled_radius(self.context, self._inner_radius[0])
        cdef float inner_radius_y = get_scaled_radius(self.context, self._inner_radius[1])

        cdef float start_angle = self._start_angle
        cdef float end_angle = self._end_angle

        # Convert coordinates to screen space
        cdef float[2] center
        self.context.viewport.coordinate_to_screen(center, self._center)
        # For proper angle conversion, we need to determine the clockwise
        # order of the points
        cdef double[2] p1
        cdef double[2] p2
        cdef float[2] p1_converted
        cdef float[2] p2_converted
        cdef float min_radius = min(radius_x, radius_y)
        # We use min_radius because coordinate_to_screen can cause
        # a fit of the tested coordinates.
        p1[0] = self._center[0] + min_radius
        p1[1] = self._center[1] + 0
        p2[0] = self._center[0] + 0
        p2[1] = self._center[1] + min_radius
        self.context.viewport.coordinate_to_screen(p1_converted, p1)
        self.context.viewport.coordinate_to_screen(p2_converted, p2)
        if not is_counter_clockwise_array(p1_converted, p2_converted, center):
            start_angle = -start_angle
            end_angle = -end_angle

        cdef bint full_ellipse = fabs(start_angle-end_angle) >= 1.999 * M_PI
        inner_radius_x = min(inner_radius_x, radius_x)
        inner_radius_y = min(inner_radius_y, radius_y)

        if full_ellipse:
            # Ellipse with full filling
            if (inner_radius_x <= 0.1 or inner_radius_y <= 0.1) or \
               (radius_x == inner_radius_x and radius_y == inner_radius_y):
                t_draw_ellipse(self.context,
                               drawlist,
                               center[0],
                               center[1],
                               radius_x,
                               radius_y,
                               self._rotation,
                               0,
                               self._pattern,
                               self._color,
                               self._fill,
                               thickness)
            # Ellipse with hole
            else:
                t_draw_elliptical_ring(self.context,
                                       drawlist,
                                       center[0],
                                       center[1],
                                       radius_x,
                                       radius_y,
                                       inner_radius_x,
                                       inner_radius_y,
                                       self._rotation,
                                       0,
                                       self._pattern,
                                       self._color,
                                       self._fill,
                                       thickness)
        elif radius_x == inner_radius_x and radius_y == inner_radius_y:
            # Arc + joined filling
            t_draw_elliptical_arc(self.context,
                                  drawlist,
                                  center[0],
                                  center[1],
                                  radius_x,
                                  radius_y,
                                  start_angle,
                                  end_angle,
                                  self._rotation,
                                  0,
                                  self._pattern,
                                  self._color,
                                  self._fill,
                                  thickness)
        elif inner_radius_x <= 0.1 or inner_radius_y <= 0.1:
            # Pie slice
            t_draw_elliptical_pie_slice(self.context,
                                        drawlist,
                                        center[0],
                                        center[1],
                                        radius_x,
                                        radius_y,
                                        start_angle,
                                        end_angle,
                                        self._rotation,
                                        0,
                                        self._pattern,
                                        self._color,
                                        self._fill,
                                        thickness)
        else:
            # Elliptical ring segment
            t_draw_elliptical_ring_segment(self.context,
                                           drawlist,
                                           center[0],
                                           center[1],
                                           radius_x,
                                           radius_y,
                                           inner_radius_x,
                                           inner_radius_y,
                                           start_angle,
                                           end_angle,
                                           self._rotation,
                                           0,
                                           self._pattern,
                                           self._color,
                                           self._fill,
                                           thickness)



cdef class DrawArrow(drawingItem):
    """
    Draws an arrow in coordinate space.
    
    An arrow consists of a line segment from p2 (start) to p1 (end) with a triangular 
    arrowhead at the p1 end. The arrow's appearance is controlled by its color, 
    line thickness, and arrowhead size.
    
    This drawing element is useful for indicating direction, marking points of interest,
    or visualizing vectors in coordinate space.
    """
    def __cinit__(self):
        # p1, p2, etc are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._thickness = 1.
        self._size = 4.

    @property
    def p1(self):
        """
        End point coordinates of the arrow (where the arrowhead is drawn).
        
        This is the destination point of the arrow, where the triangular head appears.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._end)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._end, value)
        self.__compute_tip()

    @property
    def p2(self):
        """
        Start point coordinates of the arrow (the tail end).
        
        This is the starting point of the arrow, from where the line begins.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._start)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._start, value)
        self.__compute_tip()

    @property
    def pattern(self):
        """
        Pattern of the outline.
        
        Controls the pattern of the line tracing the path.
        None for solid line.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._pattern
    @pattern.setter
    def pattern(self, Pattern value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._pattern = value

    @property
    def color(self):
        """
        Color of the arrow.
        
        Controls the color of both the line and arrowhead.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)

    @property
    def thickness(self):
        """
        Line thickness of the arrow.
        
        Controls the width of the line segment portion of the arrow. The actual pixel width 
        is affected by the viewport's scale and DPI settings.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value
        self.__compute_tip()

    @property
    def size(self):
        """
        Size of the arrow head.
        
        Controls how large the triangular head of the arrow appears. Larger values 
        create a more prominent arrowhead.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._size
    @size.setter
    def size(self, float value):
        cdef unique_lock[DCGMutex] m
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
                   void* drawlist) noexcept nogil: # TODO pattern
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = get_scaled_thickness(self.context, self._thickness)

        cdef float[2] tstart
        cdef float[2] tend
        cdef float[2] tcorner1
        cdef float[2] tcorner2
        self.context.viewport.coordinate_to_screen(tstart, self._start)
        self.context.viewport.coordinate_to_screen(tend, self._end)
        self.context.viewport.coordinate_to_screen(tcorner1, self._corner1)
        self.context.viewport.coordinate_to_screen(tcorner2, self._corner2)

        t_draw_triangle(self.context,
                        drawlist,
                        tend[0], tend[1],
                        tcorner1[0], tcorner1[1],
                        tcorner2[0], tcorner2[1],
                        self._pattern,
                        self._color,
                        self._color,
                        thickness)
        t_draw_line(self.context,
                    drawlist,
                    tstart[0], tstart[1],
                    tend[0], tend[1],
                    self._pattern,
                    self._color,
                    thickness)


cdef class DrawBezierCubic(drawingItem):
    """
    Draws a cubic Bezier curve in coordinate space.
    
    A cubic Bezier curve is defined by four control points: starting point (p1), 
    two intermediate control points (p2, p3) that shape the curvature, and an 
    endpoint (p4). The curve starts at p1, is pulled toward p2 and p3, and ends at p4.
    
    The segments parameter controls the smoothness of the curve approximation,
    with higher values creating smoother curves at the cost of performance.
    """
    def __cinit__(self):
        # p1, etc are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._thickness = 0.
        self._segments = 0

    @property
    def p1(self):
        """
        First control point coordinates of the Bezier curve.
        
        This is the starting point of the curve, where the curve begins.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p1, value)

    @property
    def p2(self):
        """
        Second control point coordinates of the Bezier curve.
        
        This control point, along with p3, determines the curvature and shape.
        The curve is pulled toward this point but does not necessarily pass through it.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p2, value)

    @property
    def p3(self):
        """
        Third control point coordinates of the Bezier curve.
        
        This control point, along with p2, determines the curvature and shape.
        The curve is pulled toward this point but does not necessarily pass through it.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p3, value)

    @property
    def p4(self):
        """
        Fourth control point coordinates of the Bezier curve.
        
        This is the end point of the curve, where the curve terminates.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p4)
    @p4.setter
    def p4(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p4, value)

    @property
    def pattern(self):
        """
        Pattern of the outline.
        
        Controls the pattern of the line tracing the path.
        None for solid line.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._pattern
    @pattern.setter
    def pattern(self, Pattern value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._pattern = value

    @property
    def color(self):
        """
        Color of the Bezier curve.
        
        The color is specified as RGBA values. The alpha channel controls 
        the transparency of the curve.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)

    @property
    def thickness(self):
        """
        Line thickness of the Bezier curve.
        
        This controls the width of the curve line. The actual pixel width
        is affected by the viewport's scale and DPI settings.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    @property
    def segments(self):
        """
        Number of line segments used to approximate the Bezier curve.
        
        Higher values create a smoother curve at the cost of performance.
        A value of 0 uses the default number of segments determined by ImGui.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._segments
    @segments.setter
    def segments(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._segments = max(0, value)

    cdef void draw(self,
                   void* drawlist) noexcept nogil: # TODO pattern
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = get_scaled_thickness(self.context, self._thickness)

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
    
    A quadratic Bezier curve is defined by three control points: starting point (p1), 
    an intermediate control point (p2) that shapes the curvature, and an endpoint (p3).
    The curve starts at p1, is pulled toward p2, and ends at p3.
    
    The segments parameter controls the smoothness of the curve approximation,
    with higher values creating smoother curves at the cost of performance.
    """
    def __cinit__(self):
        # p1, etc are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._thickness = 0.
        self._segments = 0

    @property
    def p1(self):
        """
        First control point coordinates of the Bezier curve.
        
        This is the starting point of the curve, where the curve begins.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p1, value)

    @property
    def p2(self):
        """
        Second control point coordinates of the Bezier curve.
        
        This control point determines the curvature and shape of the curve.
        The curve is pulled toward this point but does not necessarily pass through it.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p2, value)

    @property
    def p3(self):
        """
        Third control point coordinates of the Bezier curve.
        
        This is the end point of the curve, where the curve terminates.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p3, value)

    @property
    def pattern(self):
        """
        Pattern of the outline.
        
        Controls the pattern of the line tracing the path.
        None for solid line.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._pattern
    @pattern.setter
    def pattern(self, Pattern value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._pattern = value

    @property
    def color(self):
        """
        Color of the Bezier curve.
        
        The color is specified as RGBA values. The alpha channel controls 
        the transparency of the curve.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)

    @property
    def thickness(self):
        """
        Line thickness of the Bezier curve.
        
        This controls the width of the curve line. The actual pixel width
        is affected by the viewport's scale and DPI settings.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    @property
    def segments(self):
        """
        Number of line segments used to approximate the Bezier curve.
        
        Higher values create a smoother curve at the cost of performance.
        A value of 0 uses the default number of segments determined by ImGui.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._segments
    @segments.setter
    def segments(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._segments = max(0, value)

    cdef void draw(self,
                   void* drawlist) noexcept nogil: # TODO pattern
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = get_scaled_thickness(self.context, self._thickness)

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
    
    A circle is defined by its center point and radius. The circle can be both filled 
    with a solid color and outlined with a different color and thickness.
    
    Negative radius values are interpreted in screen space rather than coordinate space,
    which allows maintaining consistent visual size regardless of zoom level.
    
    The number of segments controls how smooth the circle appears - higher values 
    create a more perfect circle at the cost of rendering performance.
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
        """
        Center point of the circle in coordinate space.
        
        This defines the origin around which the circle is drawn. The circle's radius
        extends from this point in all directions.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._center)
    @center.setter
    def center(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._center, value)

    @property
    def radius(self):
        """
        Radius of the circle.
        
        Controls the size of the circle. Positive values are interpreted in coordinate space 
        and will scale with zoom level. Negative values are interpreted as screen space units
        and maintain consistent visual size regardless of zoom.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._radius
    @radius.setter
    def radius(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._radius = value

    @property
    def pattern(self):
        """
        Pattern of the outline.
        
        Controls the pattern of the line tracing the path.
        None for solid line.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._pattern
    @pattern.setter
    def pattern(self, Pattern value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._pattern = value

    @property
    def color(self):
        """
        Color of the circle outline.
        
        Controls the color of the line tracing the path of the circle. Transparency
        is supported through the alpha channel.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)

    @property
    def fill(self):
        """
        Fill color of the circle.
        
        The interior area of the circle is filled with this color.
        Transparency is supported through the alpha channel.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self._fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)

    @property
    def thickness(self):
        """
        Line thickness of the circle outline.
        
        Controls the width of the line along the circle's path. The actual pixel width 
        is affected by the viewport's scale and DPI settings. Negative values are interpreted
        in screen space units, maintaining consistent visual size regardless of zoom level.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    @property
    def segments(self):
        """
        Number of line segments used to approximate the circle.
        
        Higher values create a smoother circle at the cost of performance.
        A value of 0 uses the default number of segments determined by ImGui.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._segments
    @segments.setter
    def segments(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._segments = max(0, value)

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._show):
            return

        draw_circle(
            self.context,
            drawlist,
            self._center[0],
            self._center[1],
            get_scaled_radius(self.context, self._radius),
            self._pattern,
            self._color,
            self._fill,
            get_scaled_thickness(self.context, self._thickness),
            self._segments
        )


cdef class DrawEllipse(drawingItem):
    """
    Draws an ellipse in coordinate space.

    The ellipse is defined by its bounding box and can be filled and/or outlined.

    For a more complex ellipse, defined by a center, radii, and rotation,
    use DrawArc with start_angle=0 and end_angle=2*pi.

    Attributes:
        pmin (tuple): Top-left corner coordinates (x, y)
        pmax (tuple): Bottom-right corner coordinates (x, y)
        color (list): RGBA color of the outline
        fill (list): RGBA color of the fill
        thickness (float): Outline thickness
        segments (int): Number of segments used to approximate the ellipse
    """
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
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._pmin)
    @pmin.setter
    def pmin(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._pmin, value)

    @property
    def pmax(self):
        """
        Bottom-right corner position of the drawing in coordinate space.
        
        Returns:
            tuple: (x, y) coordinates
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._pmax)
    @pmax.setter
    def pmax(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._pmax, value)

    @property
    def pattern(self):
        """
        Pattern of the outline.
        
        Controls the pattern of the line tracing the path.
        None for solid line.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._pattern
    @pattern.setter
    def pattern(self, Pattern value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._pattern = value

    @property
    def color(self):
        """
        Color of the drawing outline.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)

    @property
    def fill(self):
        """
        Fill color of the drawing.
        
        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self._fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)

    @property
    def thickness(self):
        """
        Line thickness of the drawing outline.
        
        Returns:
            float: Thickness value in pixels
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    @property
    def segments(self):
        """
        Number of segments used to approximate the ellipse.
        
        Returns:
            int: Number of segments. 0 for auto.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._segments
    @segments.setter
    def segments(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._segments = max(0, value)

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = get_scaled_thickness(self.context, self._thickness)
        cdef float[2] p1
        cdef float[2] p2
        self.context.viewport.coordinate_to_screen(p1, self._pmin)
        self.context.viewport.coordinate_to_screen(p2, self._pmax)

        cdef float center_x = (p1[0] + p2[0]) / 2.
        cdef float center_y = (p1[1] + p2[1]) / 2.
        cdef float radius_x = fabs(p2[0] - p1[0]) / 2.
        cdef float radius_y = fabs(p2[1] - p1[1]) / 2.

        t_draw_ellipse(self.context,
                       drawlist,
                       center_x,
                       center_y,
                       radius_x,
                       radius_y,
                       0.,
                       self._segments,
                       self._pattern,
                       self._color,
                       self._fill,
                       thickness)


cdef class DrawImage(drawingItem):
    """
    Draws an image in coordinate space.
    
    An image drawing element displays a texture at a specific position with flexible 
    positioning options. The image can be positioned using corner coordinates, min/max bounds, 
    or center with direction and dimensions.
    
    The texture coordinates (UV) can be customized to show specific parts of the texture.
    Images can be tinted with a color multiplier and have rounded corners if needed.
    
    Width and height can be specified in coordinate space (positive values) or screen 
    space (negative values), allowing for consistent visual sizes regardless of zoom level.
    """

    def __cinit__(self):
        self.uv1 = [0., 0.]
        self.uv2 = [1., 0.]
        self.uv3 = [1., 1.]
        self.uv4 = [0., 1.]
        self._color_multiplier = 4294967295 # 0xffffffff

    @property
    def texture(self):
        """
        The image content to be displayed.
        
        This should be a Texture object that contains the image data to render.
        Without a valid texture, nothing will be drawn.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._texture
    @texture.setter
    def texture(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if not(isinstance(value, Texture)) and value is not None:
            raise TypeError("texture must be a Texture")
        self._texture = value

    @property
    def pmin(self):
        """
        Top-left corner position of the image in coordinate space.
        
        Setting this also adjusts p1 directly and affects p2/p4 to maintain
        a rectangular shape aligned with axes. The center is automatically updated.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)
    @pmin.setter
    def pmin(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p1, value)
        self._p2[1] = self._p1[1]
        self._p4[0] = self._p1[0]
        self.update_center()

    @property
    def pmax(self):
        """
        Bottom-right corner position of the image in coordinate space.
        
        Setting this also adjusts p3 directly and affects p2/p4 to maintain
        a rectangular shape aligned with axes. The center is automatically updated.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p3)
    @pmax.setter
    def pmax(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p3, value)
        self._p2[0] = self._p3[0]
        self._p4[1] = self._p3[1]
        self.update_center()

    @property
    def center(self):
        """
        Center point of the image in coordinate space.
        
        The center is used as the reference point when working with direction,
        width and height parameters. Changes to the center will update all four
        corner points while maintaining the current width, height and direction.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._center)
    @center.setter
    def center(self, value):
        """
        Center of pmin/pmax
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._center, value)
        self.update_extremities()

    @property
    def height(self):
        """
        Height of the image.
        
        Positive values are interpreted in coordinate space and will scale with zoom.
        Negative values are interpreted as screen space units and maintain constant
        visual size regardless of zoom level.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._height
    @height.setter
    def height(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._height = value
        self.update_extremities()

    @property
    def width(self):
        """
        Width of the image.
        
        Positive values are interpreted in coordinate space and will scale with zoom.
        Negative values are interpreted as screen space units and maintain constant
        visual size regardless of zoom level.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._width
    @width.setter
    def width(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._width = value
        self.update_extremities()

    @property
    def direction(self):
        """
        Rotation angle of the image in radians.
        
        This is the angle between the horizontal axis and the line from the center 
        to the middle of the right side of the image. Changes to direction will 
        rotate the image around its center point.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._direction
    @direction.setter
    def direction(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._direction = value
        self.update_extremities()

    @property
    def p1(self):
        """
        Top-left corner of the image in coordinate space.
        
        This is one of the four corner points that define the image's position and shape.
        Modifying individual corner points allows creating non-rectangular quad shapes.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p1, value)
        self.update_center()

    @property
    def p2(self):
        """
        Top-right corner of the image in coordinate space.
        
        This is one of the four corner points that define the image's position and shape.
        Modifying individual corner points allows creating non-rectangular quad shapes.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p2, value)
        self.update_center()

    @property
    def p3(self):
        """
        Bottom-right corner of the image in coordinate space.
        
        This is one of the four corner points that define the image's position and shape.
        Modifying individual corner points allows creating non-rectangular quad shapes.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p3, value)
        self.update_center()

    @property
    def p4(self):
        """
        Bottom-left corner of the image in coordinate space.
        
        This is one of the four corner points that define the image's position and shape.
        Modifying individual corner points allows creating non-rectangular quad shapes.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p4)
    @p4.setter
    def p4(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p4, value)
        self.update_center()

    @property
    def uv_min(self):
        """
        Texture coordinate for the top-left corner of the image.
        
        Setting this affects uv1, uv2, and uv4 to create a rectangular texture mapping.
        Coordinates are normalized in the 0-1 range where (0,0) is the top-left of 
        the texture and (1,1) is the bottom-right.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._uv1)
    @uv_min.setter
    def uv_min(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self._uv1, value)
        self._uv4[0] = self._uv1[0]
        self._uv2[1] = self._uv1[1]

    @property
    def uv_max(self):
        """
        Texture coordinate for the bottom-right corner of the image.
        
        Setting this affects uv2, uv3, and uv4 to create a rectangular texture mapping.
        Coordinates are normalized in the 0-1 range where (0,0) is the top-left of 
        the texture and (1,1) is the bottom-right.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._uv3)
    @uv_max.setter
    def uv_max(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self._uv3, value)
        self._uv2[0] = self._uv3[0]
        self._uv4[1] = self._uv3[1]

    @property
    def uv1(self):
        """
        Texture coordinate for the top-left corner (p1).
        
        Normalized texture coordinate in the 0-1 range where (0,0) is the top-left 
        of the texture and (1,1) is the bottom-right. Allows precise control over 
        which part of the texture is mapped to this corner.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._uv1)
    @uv1.setter
    def uv1(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self._uv1, value)

    @property
    def uv2(self):
        """
        Texture coordinate for the top-right corner (p2).
        
        Normalized texture coordinate in the 0-1 range where (0,0) is the top-left 
        of the texture and (1,1) is the bottom-right. Allows precise control over 
        which part of the texture is mapped to this corner.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._uv2)
    @uv2.setter
    def uv2(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self._uv2, value)

    @property
    def uv3(self):
        """
        Texture coordinate for the bottom-right corner (p3).
        
        Normalized texture coordinate in the 0-1 range where (0,0) is the top-left 
        of the texture and (1,1) is the bottom-right. Allows precise control over 
        which part of the texture is mapped to this corner.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._uv3)
    @uv3.setter
    def uv3(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self._uv3, value)

    @property
    def uv4(self):
        """
        Texture coordinate for the bottom-left corner (p4).
        
        Normalized texture coordinate in the 0-1 range where (0,0) is the top-left 
        of the texture and (1,1) is the bottom-right. Allows precise control over 
        which part of the texture is mapped to this corner.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._uv4)
    @uv4.setter
    def uv4(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[float](self._uv4, value)

    @property
    def color_multiplier(self):
        """
        Color tint applied to the image.
        
        This color is multiplied with the texture pixels when rendering, allowing 
        for tinting effects. Use white (1,1,1,1) for no tinting. The alpha channel 
        controls the overall transparency of the image.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color_multiplier
        unparse_color(color_multiplier, self._color_multiplier)
        return list(color_multiplier)
    @color_multiplier.setter
    def color_multiplier(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color_multiplier = parse_color(value)

    @property
    def rounding(self):
        """
        Radius of corner rounding applied to the image.
        
        When non-zero, corners of the image will be rounded with this radius. 
        Note that using rounding forces the image to be rendered as a rectangle 
        parallel to the axes, ignoring any non-rectangular quad settings from p1-p4.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._rounding
    @rounding.setter
    def rounding(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._rounding = value

    cdef void update_extremities(self) noexcept nogil:
        cdef double cos_dir = cos(self._direction)
        cdef double sin_dir = sin(self._direction)
        cdef double half_width = 0.5 * self._width
        cdef double half_height = 0.5 * self._height

        cdef double dx_width = half_width * cos_dir
        cdef double dy_width = half_width * sin_dir
        cdef double dx_height = -half_height * sin_dir
        cdef double dy_height = half_height * cos_dir

        self._p1[0] = self._center[0] - dx_width - dx_height
        self._p1[1] = self._center[1] - dy_width - dy_height
        
        self._p2[0] = self._center[0] + dx_width - dx_height
        self._p2[1] = self._center[1] + dy_width - dy_height
        
        self._p3[0] = self._center[0] + dx_width + dx_height
        self._p3[1] = self._center[1] + dy_width + dy_height
        
        self._p4[0] = self._center[0] - dx_width + dx_height
        self._p4[1] = self._center[1] - dy_width + dy_height

    cdef void update_center(self) noexcept nogil:
        self._center[0] = (\
            self._p1[0] + self._p3[0] +\
            self._p2[0] + self._p4[0]) * 0.25
        self._center[1] = (\
            self._p1[1] + self._p3[1] +\
            self._p2[1] + self._p4[1]) * 0.25
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
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._show):
            return
        if self._texture is None:
            return
        cdef unique_lock[DCGMutex] m2 = unique_lock[DCGMutex](self._texture.mutex)
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
        cdef double direction = fmod(self._direction, M_PI * 2.)

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
            dx = 0.5 * cos(direction) * actual_width
            dy = 0.5 * sin(direction) * actual_height
            p1[0] = center[0] - dx
            p1[1] = center[1] - dy
            p3[0] = center[0] + dx
            p3[1] = center[1] + dy
            p2[1] = p1[0]
            p4[0] = p1[1]
            p2[0] = p3[0]
            p4[1] = p3[1]

        if t_item_fully_clipped(
            self.context,
            drawlist,
            min(p1[0], p2[0], p3[0], p4[0]),
            max(p1[0], p2[0], p3[0], p4[0]),
            min(p1[1], p2[1], p3[1], p4[1]),
            max(p1[1], p2[1], p3[1], p4[1])
            ):
            return

        ip1 = imgui.ImVec2(p1[0], p1[1])
        ip2 = imgui.ImVec2(p2[0], p2[1])
        ip3 = imgui.ImVec2(p3[0], p3[1])
        ip4 = imgui.ImVec2(p4[0], p4[1])
        cdef imgui.ImVec2 iuv1 = imgui.ImVec2(self._uv1[0], self._uv1[1])
        cdef imgui.ImVec2 iuv2 = imgui.ImVec2(self._uv2[0], self._uv2[1])
        cdef imgui.ImVec2 iuv3 = imgui.ImVec2(self._uv3[0], self._uv3[1])
        cdef imgui.ImVec2 iuv4 = imgui.ImVec2(self._uv4[0], self._uv4[1])

        # Should be ensure clockwise order for ImageQuad ? -> no because no AA

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
    Draws a line segment in coordinate space.
    
    A line can be defined in two equivalent ways: by its endpoints (p1, p2) or by 
    its center point, direction angle, and length. Both representations are maintained 
    in sync when either is modified.
    
    The length parameter can be set to a negative value to indicate that the line's 
    length should be interpreted in screen space units rather than coordinate space, 
    allowing for consistent visual size regardless of zoom level.
    """
    def __cinit__(self):
        # p1, p2 are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._thickness = 1.

    @property
    def p1(self):
        """
        First endpoint of the line segment.
        
        When modified, this updates the center, direction, and length properties 
        to maintain a consistent representation of the line.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p1, value)
        self.update_center()

    @property
    def p2(self):
        """
        Second endpoint of the line segment.
        
        When modified, this updates the center, direction, and length properties 
        to maintain a consistent representation of the line.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p2, value)
        self.update_center()

    cdef void update_extremities(self) noexcept nogil:
        cdef double length = fabs(self._length)
        cdef double direction = fmod(self._direction, M_PI * 2.)
        cdef double dx = cos(direction)
        cdef double dy = sin(direction)
        dx = 0.5 * length * dx
        dy = 0.5 * length * dy
        self._p1[0] = self._center[0] - dx
        self._p1[1] = self._center[1] - dy
        self._p2[0] = self._center[0] + dx
        self._p2[1] = self._center[1] + dy

    @property
    def center(self):
        """
        Center point of the line segment.
        
        When modified, this updates the endpoints (p1 and p2) while maintaining 
        the current direction and length of the line.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._center)
    @center.setter
    def center(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._center, value)
        self.update_extremities()

    @property
    def length(self):
        """
        Length of the line segment.
        
        Positive values are interpreted in coordinate space and will scale with zoom.
        Negative values are interpreted as screen space units and maintain constant 
        visual size regardless of zoom level.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._length
    @length.setter
    def length(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._length = value
        self.update_extremities()

    @property
    def direction(self):
        """
        Angle of the line segment in radians.
        
        This is the angle between the horizontal axis and the line from center to p2.
        When modified, this rotates the line around its center point.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._direction
    @direction.setter
    def direction(self, double value):
        cdef unique_lock[DCGMutex] m
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
    def pattern(self):
        """
        Pattern of the line.
        
        Controls the pattern of the line tracing the path.
        None for solid line.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._pattern
    @pattern.setter
    def pattern(self, Pattern value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._pattern = value

    @property
    def color(self):
        """
        Color of the line.
        
        The color is specified as RGBA values. The alpha channel controls 
        the transparency of the line.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)

    @property
    def thickness(self):
        """
        Line thickness in pixels.
        
        This controls the width of the line. The actual pixel width
        is affected by the viewport's scale and DPI settings.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._show):
            return

        cdef float[2] p1
        cdef float[2] p2
        cdef float[2] center
        cdef float dx, dy
        cdef double direction = fmod(self._direction, M_PI * 2.)
        if self._length >= 0:
            self.context.viewport.coordinate_to_screen(p1, self._p1)
            self.context.viewport.coordinate_to_screen(p2, self._p2)
        else:
            self.context.viewport.coordinate_to_screen(center, self._center)
            dx = -0.5 * cos(direction) * self._length
            dy = -0.5 * sin(direction) * self._length
            p1[0] = center[0] - dx
            p1[1] = center[1] - dy
            p2[0] = center[0] + dx
            p2[1] = center[1] + dy

        t_draw_line(
            self.context,
            drawlist,
            p1[0],
            p1[1],
            p2[0],
            p2[1],
            self._pattern,
            self._color,
            get_scaled_thickness(self.context, self._thickness)
        )


cdef class DrawPolyline(drawingItem):
    """
    Draws a sequence of connected line segments in coordinate space.
    
    Each point in the provided sequence is connected to the adjacent points by straight lines.
    The lines can be customized with color and thickness settings. By enabling the 'closed'
    property, the last point will be connected back to the first, forming a closed shape.
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
        
        These points define the vertices through which the polyline passes.
        Each consecutive pair of points forms a line segment. At least two
        points are needed to draw a visible line.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        res = []
        cdef int32_t i
        for i in range(<int>self._points.size()):
            res.append(Coord.build(self._points[i].p))
        return res
    @points.setter
    def points(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef double2 p
        cdef int32_t i
        self._points.clear()
        for i in range(len(value)):
            read_coord(p.p, value[i])
            self._points.push_back(p)

    @property
    def pattern(self):
        """
        Pattern of the lines.
        
        Controls the pattern of the line tracing the path.
        None for solid line.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._pattern
    @pattern.setter
    def pattern(self, Pattern value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._pattern = value

    @property
    def color(self):
        """
        Color of the polyline.
        
        Controls the color of all line segments. The alpha channel can be used
        to create semi-transparent lines.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)

    @property
    def closed(self):
        """
        Whether the polyline forms a closed shape.
        
        When set to True, an additional line segment connects the last point
        back to the first point, creating a closed loop. When False, the polyline
        remains open with distinct start and end points.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._closed
    @closed.setter
    def closed(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._closed = value

    @property
    def thickness(self):
        """
        Line thickness of the polyline.
        
        Controls the width of all line segments. The actual pixel width is affected
        by the viewport's scale and DPI settings. For very thin lines (thickness < 2.0),
        individual line segments are drawn for better quality.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._show) or self._points.size() < 2:
            return

        cdef float thickness = get_scaled_thickness(self.context, self._thickness)

        cdef int32_t i
        cdef int num_points = <int>self._points.size()
        cdef DCGVector[float] *ipoints = &self.context.viewport.temp_point_coords
        ipoints.resize(2*num_points)
        cdef float *ipoints_p = ipoints.data()
        for i in range(num_points):
            self.context.viewport.coordinate_to_screen(&ipoints_p[2*i], self._points[i].p)

        t_draw_polyline(self.context, drawlist, ipoints.data(), num_points,
                        self._pattern, self._color, self._closed, thickness)

cdef class DrawPolygon(drawingItem):
    """
    Draws a filled polygon in coordinate space.
    
    A polygon is defined by a sequence of points that form its vertices. The polygon
    can be both filled with a solid color and outlined with a different color and thickness.
    
    For non-convex polygons, automatic triangulation is performed to ensure proper
    filling. When the 'hull' option is enabled, only the convex hull of the points
    is drawn instead of the exact polygon shape.
    """
    def __cinit__(self):
        # points is empty init by cython
        self._color = 4294967295 # 0xffffffff
        self._fill = 0
        self._thickness = 1.
        self._hull = False
        self._constrained_success = False

    @property
    def points(self):
        """
        List of vertex positions defining the shape.
        
        These points define the vertices of the polygon in coordinate space.
        The polygon is formed by connecting these points in order, with the
        last point connected back to the first to close the shape.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        res = []
        cdef int32_t i
        for i in range(<int32_t>self._points.size()):
            res.append(Coord.build(self._points[i].p))
        return res
    @points.setter
    def points(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef double2 p
        cdef int32_t i
        self._points.clear()
        for i in range(len(value)):
            read_coord(p.p, value[i])
            self._points.push_back(p)
        self._triangulate()

    @property
    def pattern(self):
        """
        Pattern of the outline.
        
        Controls the pattern of the line tracing the path.
        None for solid line.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._pattern
    @pattern.setter
    def pattern(self, Pattern value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._pattern = value

    @property
    def color(self):
        """
        Color of the polygon outline.
        
        Controls the color of the line tracing the boundary of the polygon.
        Transparency is supported through the alpha channel.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)

    @property
    def fill(self):
        """
        Fill color of the polygon.
        
        The interior area of the polygon is filled with this color.
        Transparency is supported through the alpha channel.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self._fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)

    @property
    def hull(self):
        """
        Whether to draw the convex hull instead of the exact polygon shape.
        
        When enabled, only the convex hull of the provided points is drawn,
        creating a shape with no concavities. This can be useful for
        simplifying complex shapes or ensuring convexity.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._hull
    @hull.setter
    def hull(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._hull = value

    @property
    def thickness(self):
        """
        Line thickness of the polygon outline.
        
        Controls the width of the line along the polygon's boundary.
        The actual pixel width is affected by the viewport's scale
        and DPI settings. Negative values are interpreted in
        pixel space.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    # ImGui Polygon fill requires clockwise order and convex polygon.
    # We want to be more lenient -> triangulate
    cdef void _triangulate(self):
        self._hull_triangulation.clear()
        self._polygon_triangulation.clear()
        self._hull_indices.clear()
        self._constrained_success = False
        
        if self._points.size() < 3:
            return
        
        # Convert points to flat coordinate array
        cdef vector[double] coords
        coords.reserve(self._points.size() * 2)
        cdef int32_t i
        for i in range(<int32_t>self._points.size()):
            coords.push_back(self._points[i].p[0])
            coords.push_back(self._points[i].p[1])

        # Create triangulation
        cdef DelaunationResult result = delaunator_get_triangles(coords)
        
        # Store hull triangulation
        self._hull_triangulation.reserve(result.hull_triangles.size())
        for i in range(<int32_t>result.hull_triangles.size()):
            self._hull_triangulation.push_back(result.hull_triangles[i])
            
        # Store hull indices for drawing the hull boundary
        self._hull_indices.reserve(result.hull_indices.size())
        for i in range(<int32_t>result.hull_indices.size()):
            self._hull_indices.push_back(result.hull_indices[i])
            
        # Store polygon triangulation if constrained triangulation was successful
        self._constrained_success = result.constrained_success
        if result.constrained_success and result.polygon_triangles.size() > 0:
            self._polygon_triangulation.reserve(result.polygon_triangles.size())
            for i in range(<int32_t>result.polygon_triangles.size()):
                self._polygon_triangulation.push_back(result.polygon_triangles[i])


    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._show) or self._points.size() < 2:
            return

        cdef float thickness = get_scaled_thickness(self.context, self._thickness)

        cdef float[2] p
        cdef imgui.ImVec2 ip
        cdef int num_points = self._points.size()
        cdef int32_t i
        
        # Convert points to screen coordinates
        cdef DCGVector[float] *ipoints = &self.context.viewport.temp_point_coords
        ipoints.resize(2*num_points)
        cdef float *ipoints_p = ipoints.data()
        for i in range(num_points):
            self.context.viewport.coordinate_to_screen(&ipoints_p[2*i], self._points[i].p)

        cdef DCGVector[uint32_t]* triangulation_ptr = NULL
        # Select which triangulation to use based on hull flag            
        if self._hull:
            triangulation_ptr = &self._hull_triangulation
        elif self._constrained_success:
            triangulation_ptr = &self._polygon_triangulation

        # Degenerate case: two points
        if self._points.size() == 2:
            (<imgui.ImDrawList*>drawlist).AddLine(
                imgui.ImVec2(ipoints_p[0], ipoints_p[1]),
                imgui.ImVec2(ipoints_p[2], ipoints_p[3]),
                <imgui.ImU32>self._color,
                thickness)
            return

        # For the convex hull, the points are not necessarily in order.
        cdef DCGVector[float] sorted_points
        cdef DCGVector[uint32_t] hull_indices
        if self._hull:
            # Sort points based on hull indices
            sorted_points.reserve(self._points.size())
            for i in range(<int32_t>self._hull_indices.size()):
                sorted_points.push_back(ipoints_p[2*self._hull_indices[i]])
                sorted_points.push_back(ipoints_p[2*self._hull_indices[i] + 1])
            ipoints = &sorted_points

            # Fix triangulation_ptr as the hull_indices are now sorted
            hull_indices.reserve(self._hull_indices.size())
            for i in range(<int32_t>self._hull_indices.size()):
                hull_indices.push_back(0)
            for i in range(<int32_t>self._hull_indices.size()):
                hull_indices[self._hull_indices[i]] = i

            triangulation_ptr = &hull_indices

        if triangulation_ptr == NULL:
            # No triangulation available, draw the polygon outline only
            t_draw_polyline(
                self.context,
                drawlist, 
                ipoints.data(), 
                num_points,
                self._pattern,
                <imgui.ImU32>self._color, 
                True, 
                thickness
            )
            return

        # Draw the polygon
        t_draw_polygon(
            self.context,
            drawlist, 
            ipoints.data(), 
            num_points,
            NULL,
            0,
            triangulation_ptr.data(), 
            <int>triangulation_ptr.size(), 
            self._pattern,
            self._color, 
            self._fill, 
            thickness
        )


cdef class DrawQuad(drawingItem):
    """
    Draws a quadrilateral in coordinate space.
    
    A quadrilateral is defined by four corner points that can be positioned freely in coordinate space.
    This allows creating shapes such as trapezoids, parallelograms, or arbitrary four-sided polygons.
    
    The quad can be both filled with a solid color and outlined with a different color and thickness.
    
    When filling is enabled, the shape is automatically triangulated into two triangles,
    with proper orientation handling to ensure correct anti-aliasing.
    """
    def __cinit__(self):
        # p1, p2, p3, p4 are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._fill = 0
        self._thickness = 1.

    @property
    def p1(self):
        """
        First vertex position of the quadrilateral.
        
        This defines one of the four corners of the quad.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p1, value)

    @property
    def p2(self):
        """
        Second vertex position of the quadrilateral.
        
        This defines one of the four corners of the quad.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p2, value)

    @property
    def p3(self):
        """
        Third vertex position of the quadrilateral.
        
        This defines one of the four corners of the quad.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p3, value)

    @property
    def p4(self):
        """ 
        Fourth vertex position of the quadrilateral.
        
        This defines one of the four corners of the quad.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p4)
    @p4.setter
    def p4(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p4, value)

    @property
    def pattern(self):
        """
        Pattern of the outline.
        
        Controls the pattern of the line tracing the path.
        None for solid line.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._pattern
    @pattern.setter
    def pattern(self, Pattern value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._pattern = value

    @property
    def color(self):
        """
        Color of the quadrilateral outline.
        
        Controls the color of the lines tracing the perimeter of the quad.
        Transparency is supported through the alpha channel.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)

    @property
    def fill(self):
        """
        Fill color of the quadrilateral.
        
        The interior area of the quad is filled with this color.
        Transparency is supported through the alpha channel.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self._fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)

    @property
    def thickness(self):
        """
        Line thickness of the quadrilateral outline.
        
        Controls the width of the lines along the quad's perimeter.
        The actual pixel width is affected by the viewport's scale and DPI settings.
        Negative values are interpreted in pixel space.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._show):
            return

        draw_quad(
            self.context,
            drawlist,
            self._p1[0],
            self._p1[1],
            self._p2[0],
            self._p2[1],
            self._p3[0],
            self._p3[1],
            self._p4[0],
            self._p4[1],
            self._pattern,
            self._color,
            self._fill,
            get_scaled_thickness(self.context, self._thickness)
        )


cdef class DrawRect(drawingItem):
    """
    Draws a rectangle in coordinate space.
    
    A rectangle is defined by its minimum and maximum points, creating a shape 
    aligned with the coordinate axes. The rectangle can be customized with solid fill,
    gradient fill across its corners, outline, and rounded corners.
    
    The thickness parameter controls the width of the outline, while rounding controls
    the radius of rounded corners. When using gradient fills, different colors can be
    specified for each corner of the rectangle.
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
        Top-left corner position of the rectangle in coordinate space.
        
        This defines the minimum x and y coordinates of the rectangle. When used
        with pmax, it determines the overall size and position of the rectangle.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._pmin)
    @pmin.setter
    def pmin(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._pmin, value)

    @property
    def pmax(self):
        """
        Bottom-right corner position of the rectangle in coordinate space.
        
        This defines the maximum x and y coordinates of the rectangle. When used
        with pmin, it determines the overall size and position of the rectangle.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._pmax)
    @pmax.setter
    def pmax(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._pmax, value)

    @property
    def pattern(self):
        """
        Pattern of the outline.
        
        Controls the pattern of the line tracing the path.
        None for solid line.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._pattern
    @pattern.setter
    def pattern(self, Pattern value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._pattern = value

    @property
    def color(self):
        """
        Color of the rectangle outline.
        
        Controls the color of the line tracing the perimeter of the rectangle.
        Transparency is supported through the alpha channel.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)

    @property
    def fill(self):
        """
        Solid fill color of the rectangle.
        
        The interior area of the rectangle is filled with this color.
        Setting this property also resets all corner gradient colors to match,
        disabling multi-color gradient filling.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self._fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[DCGMutex] m
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
        Fill color at the top-left corner (p1) for gradient fills.
        
        When different colors are set for the four corners, the rectangle 
        is filled with a smooth gradient between these colors. Setting any
        corner color enables the gradient fill mode.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color_upper_left
        unparse_color(color_upper_left, self._color_upper_left)
        return list(color_upper_left)
    @fill_p1.setter
    def fill_p1(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color_upper_left = parse_color(value)
        self._multicolor = True

    @property
    def fill_p2(self):
        """
        Fill color at the top-right corner (p2) for gradient fills.
        
        When different colors are set for the four corners, the rectangle 
        is filled with a smooth gradient between these colors. Setting any
        corner color enables the gradient fill mode.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color_upper_right
        unparse_color(color_upper_right, self._color_upper_right)
        return list(color_upper_right)
    @fill_p2.setter
    def fill_p2(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color_upper_right = parse_color(value)
        self._multicolor = True

    @property
    def fill_p3(self):
        """
        Fill color at the bottom-right corner (p3) for gradient fills.
        
        When different colors are set for the four corners, the rectangle 
        is filled with a smooth gradient between these colors. Setting any
        corner color enables the gradient fill mode.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color_bottom_right
        unparse_color(color_bottom_right, self._color_bottom_right)
        return list(color_bottom_right)
    @fill_p3.setter
    def fill_p3(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color_bottom_right = parse_color(value)
        self._multicolor = True

    @property
    def fill_p4(self):
        """
        Fill color at the bottom-left corner (p4) for gradient fills.
        
        When different colors are set for the four corners, the rectangle 
        is filled with a smooth gradient between these colors. Setting any
        corner color enables the gradient fill mode.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color_bottom_left
        unparse_color(color_bottom_left, self._color_bottom_left)
        return list(color_bottom_left)
    @fill_p4.setter
    def fill_p4(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color_bottom_left = parse_color(value)
        self._multicolor = True

    @property
    def thickness(self):
        """
        Line thickness of the rectangle outline.
        
        Controls the width of the line along the rectangle's perimeter.
        The actual pixel width is affected by the viewport's scale and DPI settings.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    @property
    def rounding(self):
        """
        Radius of the rectangle's rounded corners.
        
        When non-zero, the corners of the rectangle are rounded with this radius.
        Note that gradient fills with rounded corners are not supported - setting
        both gradient fill and rounding will prioritize the fill and display
        sharp corners.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._rounding
    @rounding.setter
    def rounding(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._rounding = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil: # TODO: pattern
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._show):
            return

        cdef float thickness = get_scaled_thickness(self.context, self._thickness)
        cdef float rounding = self._rounding

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
    Draws a regular polygon with n sides in coordinate space.
    
    A regular polygon has all sides of equal length and all interior angles equal.
    The shape is defined by its center point, radius, and number of sides.
    When num_points is set to a large value (or 1), the polygon approximates a circle.
    
    The direction parameter controls the rotation of the polygon by specifying
    the angle of the first vertex relative to the horizontal axis.
    
    Like other shape elements, the polygon can be both filled and outlined
    with different colors and thicknesses.
    """
    def __cinit__(self):
        # p1, p2 are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._thickness = 1.
        self._num_points = 1

    @property
    def center(self):
        """
        Coordinates of the center of the regular polygon.
        
        The center serves as the origin point from which all vertices
        are positioned at equal distances (the radius).
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._center)
    @center.setter
    def center(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._center, value)
        
    @property
    def radius(self):
        """
        Radius of the regular polygon.
        
        This is the distance from the center to each vertex.
        Positive values are interpreted in coordinate space and will scale with zoom.
        Negative values are interpreted as screen space units and maintain constant
        visual size regardless of zoom level.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._radius
    @radius.setter
    def radius(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._radius = value
        
    @property
    def direction(self):
        """
        Angle of the first vertex in radians.
        
        This controls the rotation of the entire polygon around its center.
        The angle is measured from the positive x-axis in counter-clockwise direction.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._direction
    @direction.setter
    def direction(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._direction = value
        
    @property
    def num_points(self):
        """
        Number of sides (vertices) in the regular polygon.
        
        Higher values create polygons with more sides. Setting to 3 creates a triangle,
        4 creates a square, 5 creates a pentagon, and so on.
        
        Setting to 1 is a special case that creates a circle.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._num_points
    @num_points.setter
    def num_points(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._num_points = value

    @property
    def pattern(self):
        """
        Pattern of the outline.
        
        Controls the pattern of the line tracing the path.
        None for solid line.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._pattern
    @pattern.setter
    def pattern(self, Pattern value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._pattern = value

    @property
    def color(self):
        """
        Color of the polygon outline.
        
        Controls the color of the lines tracing the perimeter of the polygon.
        Transparency is supported through the alpha channel.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)
        
    @property
    def fill(self):
        """
        Fill color of the polygon.
        
        The interior area of the polygon is filled with this color.
        Transparency is supported through the alpha channel.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._fill)
        return list(color)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)
        
    @property
    def thickness(self):
        """
        Line thickness of the polygon outline.
        
        Controls the width of the line tracing the perimeter of the polygon.
        The actual pixel width is affected by the viewport's scale and DPI settings.
        Negative values are interpreted in pixel space.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._show):
            return

        draw_regular_polygon(
            self.context,
            drawlist, 
            self._center[0],
            self._center[1],
            get_scaled_radius(self.context, self._radius),
            self._direction,
            self._num_points,
            self._pattern,
            self._color, 
            self._fill,
            get_scaled_thickness(self.context, self._thickness)
        )


cdef class DrawStar(drawingItem):
    """
    Draws a star shaped polygon with n points in coordinate space.
    
    A star is defined by its center, radius of exterior circle, inner radius, and number of points.
    The direction parameter controls the rotation of the star. When inner_radius is set to 0,
    the star becomes a cross or asterisk shape with lines intersecting at the center point.
    
    Like other drawing elements, the star can be both filled with a solid color and outlined
    with a different color and thickness. Radius can be specified in coordinate space (positive values) 
    or screen space (negative values) to maintain consistent visual size regardless of zoom level.
    """
    def __cinit__(self):
        # p1, p2 are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._thickness = 1.
        self._num_points = 5

    @property
    def center(self):
        """
        Coordinates of the center of the star.
        
        This defines the central point around which the star is constructed. All points
        of the star extend outward from this position.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._center)
    @center.setter
    def center(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._center, value)

    @property
    def radius(self):
        """
        Radius of the outer points of the star.
        
        This controls the distance from the center to each outer vertex of the star.
        Positive values are interpreted in coordinate space and will scale with zoom.
        Negative values are interpreted as screen space units and maintain constant
        visual size regardless of zoom level.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._radius
    @radius.setter
    def radius(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._radius = value

    @property
    def inner_radius(self):
        """
        Radius of the inner points of the star.
        
        This controls the distance from the center to each inner vertex of the star.
        Setting this to 0 creates a cross or asterisk shape instead of a star.
        The ratio between inner_radius and radius determines how pointed the star appears.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._inner_radius
    @inner_radius.setter
    def inner_radius(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._inner_radius = value

    @property
    def direction(self):
        """
        Angle of the first point of the star in radians.

        This controls the rotation of the entire star around its center. The angle is 
        measured from the positive x-axis in counter-clockwise direction. Changing this
        value rotates the star while maintaining its shape.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._direction
    @direction.setter
    def direction(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._direction = value

    @property
    def num_points(self):
        """
        Number of outer points in the star.
        
        This determines how many points the star has. A value of 5 creates a traditional
        five-pointed star, while higher values create stars with more points. The minimum
        valid value is 3, which creates a triangular star.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._num_points
    @num_points.setter
    def num_points(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._num_points = value

    @property
    def pattern(self):
        """
        Pattern of the outline.
        
        Controls the pattern of the line tracing the path.
        None for solid line.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._pattern
    @pattern.setter
    def pattern(self, Pattern value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._pattern = value

    @property
    def color(self):
        """
        Color of the star outline.
        
        Controls the color of the lines tracing the perimeter of the star.
        Transparency is supported through the alpha channel.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)

    @property
    def fill(self):
        """
        Fill color of the star.
        
        The interior area of the star is filled with this color.
        Transparency is supported through the alpha channel.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._fill)
        return list(color)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)

    @property
    def thickness(self):
        """
        Line thickness of the star outline.
        
        Controls the width of the lines forming the star's outline.
        The actual pixel width is affected by the viewport's scale and DPI settings.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._show):
            return

        draw_star(
            self.context,
            drawlist, 
            self._center[0],
            self._center[1],
            get_scaled_radius(self.context, self._radius),
            get_scaled_radius(self.context, self._inner_radius),
            self._direction,
            self._num_points,
            self._pattern,
            self._color, 
            self._fill, 
            get_scaled_thickness(self.context, self._thickness)
        )

cdef class DrawText(drawingItem):
    """
    Draws text in coordinate space.
    
    Text is rendered at the specified position using either default or custom font settings.
    The text can be scaled based on either coordinate space (which changes size with zoom)
    or screen space (which maintains consistent size regardless of zoom level).
    
    Font appearance can be customized with color and size options. When a custom font
    is provided, the text will use its style, weight, and other characteristics instead
    of the default font.
    """
    def __cinit__(self):
        self._color = 4294967295 # 0xffffffff
        self._size = 0. # 0: default size. DearPyGui uses 1. internally, then 10. in the wrapper.

    @property
    def pos(self):
        """
        Position of the text in coordinate space.
        
        This defines the anchor point from which the text begins. By default,
        text is aligned from the top-left of this position.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._pos)
    @pos.setter
    def pos(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._pos, value)

    @property
    def color(self):
        """
        Color of the text.
        
        Controls the color of the rendered text characters. Transparency 
        is supported through the alpha channel, allowing for effects like
        watermarks or fading text.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)

    @property
    def font(self):
        """
        Custom font for rendering the text.
        
        When set to a Font object, the text will use that font's style instead of
        the default system font. This allows for custom typography, including
        different weights, styles, or even icon fonts.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._font
    @font.setter
    def font(self, baseFont value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._font = value

    @property
    def text(self):
        """
        The string content to display.
        
        This is the actual text that will be rendered at the specified position.
        The text can contain multiple lines using newline characters.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return string_to_str(self._text)
    @text.setter
    def text(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._text = string_from_str(value)

    @property
    def size(self):
        """
        Size of the font used to render text.
        
        Positive values are interpreted in coordinate space and will scale with zoom.
        Negative values are interpreted as screen space units and maintain constant
        visual size regardless of zoom level. A value of 0 uses the default font size.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._size
    @size.setter
    def size(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._size = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._show):
            return

        cdef float[2] p

        self.context.viewport.coordinate_to_screen(p, self._pos)
        cdef imgui.ImVec2 ip = imgui.ImVec2(p[0], p[1])
        cdef float size = get_scaled_radius(self.context, self._size)

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
    
    A triangle is defined by three vertex points that can be positioned freely in coordinate space.
    The shape can be both filled with a solid color and outlined with a different color and thickness.
    """
    def __cinit__(self):
        # p1, p2, p3 are zero init by cython
        self._color = 4294967295 # 0xffffffff
        self._fill = 0
        self._thickness = 1.

    @property
    def p1(self):
        """
        First vertex position of the triangle.
        
        This defines one of the three points that form the triangle. Together with p2 and p3,
        these coordinates determine the size, shape, and position of the triangle in coordinate space.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)
    @p1.setter
    def p1(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p1, value)

    @property
    def p2(self):
        """
        Second vertex position of the triangle.
        
        This defines one of the three points that form the triangle. Together with p1 and p3,
        these coordinates determine the size, shape, and position of the triangle in coordinate space.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p2)
    @p2.setter
    def p2(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p2, value)

    @property
    def p3(self):
        """
        Third vertex position of the triangle.
        
        This defines one of the three points that form the triangle. Together with p1 and p2,
        these coordinates determine the size, shape, and position of the triangle in coordinate space.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p3)
    @p3.setter
    def p3(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p3, value)

    @property
    def pattern(self):
        """
        Pattern of the outline.
        
        Controls the pattern of the line tracing the path.
        None for solid line.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._pattern
    @pattern.setter
    def pattern(self, Pattern value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._pattern = value

    @property
    def color(self):
        """
        Color of the triangle outline.
        
        Controls the color of the lines tracing the perimeter of the triangle.
        Transparency is supported through the alpha channel.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)

    @property
    def fill(self):
        """
        Fill color of the triangle.
        
        The interior area of the triangle is filled with this color.
        Transparency is supported through the alpha channel.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] fill
        unparse_color(fill, self._fill)
        return list(fill)
    @fill.setter
    def fill(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._fill = parse_color(value)

    @property
    def thickness(self):
        """
        Line thickness of the triangle outline.
        
        Controls the width of the lines along the triangle's perimeter.
        The actual pixel width is affected by the viewport's scale and DPI settings.
        Negative values are interpreted in pixel space.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._thickness
    @thickness.setter
    def thickness(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._thickness = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._show):
            return

        draw_triangle(
            self.context,
            drawlist, 
            self._p1[0],
            self._p1[1],
            self._p2[0],
            self._p2[1],
            self._p3[0],
            self._p3[1],
            self._pattern,
            self._color, 
            self._fill, 
            get_scaled_thickness(self.context, self._thickness)
        )


cdef class DrawTextQuad(drawingItem):
    """
    Draws text deformed to fit inside a quadrilateral in coordinate space.
    
    Text is rendered to fill the entire quadrilateral defined by four corner points.
    This allows text to be rotated, sheared, or otherwise transformed beyond what
    is possible with standard text rendering.
    
    The text can be rendered either with aspect ratio preserved (which may leave empty
    space within the quad) or fully deformed to fill the entire quad shape.
    
    Font appearance can be customized with color options. When a custom font is provided,
    the text will use its style, weight, and other characteristics instead of the default font.
    """
    def __cinit__(self):
        self._color = 4294967295  # 0xffffffff
        self._preserve_ratio = True  # preserve aspect ratio by default
        
    @property
    def p1(self):
        """
        First point (top-left corner) of the quadrilateral in coordinate space.
        
        This defines the origin corner from which the text begins.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)
    
    @p1.setter
    def p1(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p1, value)

    @property
    def p2(self):
        """
        Second point (top-right corner) of the quadrilateral in coordinate space.
        
        Together with p1, this defines the top edge of the text quad.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p2)
    
    @p2.setter
    def p2(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p2, value)

    @property
    def p3(self):
        """
        Third point (bottom-right corner) of the quadrilateral in coordinate space.
        
        Together with p2 and p4, this defines the bottom edge and right edge of the text quad.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p3)
    
    @p3.setter
    def p3(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p3, value)

    @property
    def p4(self):
        """
        Fourth point (bottom-left corner) of the quadrilateral in coordinate space.
        
        Together with p1 and p3, this defines the left edge and bottom edge of the text quad.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p4)
    
    @p4.setter
    def p4(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._p4, value)

    @property
    def color(self):
        """
        Color of the text.
        
        Controls the color of the rendered text characters. Transparency 
        is supported through the alpha channel, allowing for effects like
        watermarks or fading text.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    
    @color.setter
    def color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)

    @property
    def font(self):
        """
        Custom font for rendering the text.
        
        When set to a Font object, the text will use that font's style instead of
        the default system font. This allows for custom typography, including
        different weights, styles, or even icon fonts.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._font
    
    @font.setter
    def font(self, baseFont value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._font = value

    @property
    def text(self):
        """
        The string content to display.
        
        This is the actual text that will be rendered within the quadrilateral.
        The text can contain multiple lines using newline characters.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return string_to_str(self._text)
    
    @text.setter
    def text(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._text = string_from_str(value)

    @property
    def preserve_ratio(self):
        """
        Whether to maintain the text's original aspect ratio.
        
        When True, the text will maintain its width-to-height ratio, which may
        leave some areas of the quad empty if the quad's shape differs from
        the text's natural dimensions.
        
        When False, the text will be deformed to completely fill the quad,
        which may result in stretched or compressed text.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._preserve_ratio
    
    @preserve_ratio.setter
    def preserve_ratio(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._preserve_ratio = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._show):
            return

        if self._font is not None:
            self._font.push()

        draw_text_quad(
            self.context,
            drawlist,
            self._p1[0], self._p1[1],  # top-left
            self._p2[0], self._p2[1],  # top-right
            self._p3[0], self._p3[1],  # bottom-right
            self._p4[0], self._p4[1],  # bottom-left
            self._text.c_str(),
            <imgui.ImU32>self._color,
            NULL,
            self._preserve_ratio
        )

        if self._font is not None:
            self._font.pop()


cdef class DrawValue(drawingItem):
    """
    Draws a SharedValue in coordinate space.
    
    This drawing element displays the content of a SharedValue object at a specific position.
    It's useful for showing dynamic values that can be updated elsewhere in the application.
    
    The value display can be formatted using printf-style format strings, and its appearance
    can be customized with different fonts, colors and sizes. The size can be specified in 
    coordinate space (positive values) or screen space (negative values).
    
    For security reasons, an intermediate buffer of fixed size is used with a limit of
    256 characters.
    """
    def __cinit__(self):
        self._print_format = string_from_bytes(b"%.3f")
        self._value = <SharedValue>(SharedFloat.__new__(SharedFloat, self.context))
        self._type = 2
        self._color = 4294967295 # 0xffffffff
        self._size = 0. # 0: default size. DearPyGui uses 1. internally, then 10. in the wrapper.

    @property
    def pos(self):
        """
        Position of the text in coordinate space.
        
        This defines the anchor point from which the text begins. By default,
        text is aligned from the top-left of this position.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._pos)
    @pos.setter
    def pos(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_coord(self._pos, value)

    @property
    def color(self):
        """
        Color of the text.
        
        Controls the color of the rendered text characters. Transparency
        is supported through the alpha channel, allowing for effects like
        watermarks or fading text.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._color)
        return list(color)
    @color.setter
    def color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)

    @property
    def font(self):
        """
        Custom font for rendering the text.
        
        When set to a Font object, the text will use that font's style instead of
        the default system font. This allows for custom typography, including
        different weights, styles, or even icon fonts.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._font
    @font.setter
    def font(self, baseFont value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._font = value

    @property
    def size(self):
        """
        Size of the font used to render text.
        
        Positive values are interpreted in coordinate space and will scale with zoom.
        Negative values are interpreted as screen space units and maintain constant
        visual size regardless of zoom level. A value of 0 uses the default font size.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._size
    @size.setter
    def size(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._size = value

    @property
    def shareable_value(self):
        """
        The SharedValue object being displayed.
        
        This property provides access to the underlying SharedValue that this element
        displays. The object holds a value field that is in sync with the internal value
        of the drawing. This same object can be passed to other items to share its value.
        
        Supported types include SharedBool, SharedFloat,
        SharedColor and SharedStr.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._value

    @shareable_value.setter
    def shareable_value(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self._value is value:
            return
        if not(isinstance(value, SharedBool) or
               isinstance(value, SharedFloat) or
               isinstance(value, SharedColor) or
               isinstance(value, SharedStr)):
            raise ValueError(f"Unsupported type. Received {type(value)}")
        if isinstance(value, SharedBool):
            self._type = 0
        elif isinstance(value, SharedFloat):
            self._type = 2
        elif isinstance(value, SharedColor):
            self._type = 4
        elif isinstance(value, SharedStr):
            self._type = 9
        self._value.dec_num_attached()
        self._value = value
        self._value.inc_num_attached()

    @property
    def print_format(self):
        """
        Format string for converting the value to a displayed string.
        
        This property accepts printf-style format strings that control how the value
        is displayed. The format depends on the type of the SharedValue:
        
        - %f for SharedFloat
        - (%f, %f, %f, %f) for SharedColor
        - %s for SharedStr
        
        The default format for floating-point values is "%.3f".
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return string_to_str(self._print_format)

    @print_format.setter
    def print_format(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._print_format = string_from_str(value)

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
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
        size = fabs(size)
        if self._font is not None:
            self._font.push()

        cdef bool value_bool
        cdef double value_float
        cdef Vec4 value_color
        cdef double[4] value_float4
        cdef DCGString value_str

        cdef int32_t ret

        if self._type == 0:
            value_bool = SharedBool.get(<SharedBool>self._value)
            ret = imgui.ImFormatString(self.buffer, 256, self._print_format.c_str(), value_bool)
        elif self._type == 2:
            value_float = SharedFloat.get(<SharedFloat>self._value)
            ret = imgui.ImFormatString(self.buffer, 256, self._print_format.c_str(), value_float)
        elif self._type == 4:
            value_color = SharedColor.getF4(<SharedColor>self._value)
            ret = imgui.ImFormatString(self.buffer, 256, self._print_format.c_str(), value_color.x, value_color.y, value_color.z, value_color.w)
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