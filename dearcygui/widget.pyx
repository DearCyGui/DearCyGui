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

from libcpp cimport bool
from libc.stdint cimport uint32_t, int32_t
from libc.stdlib cimport malloc, free
from libc.string cimport memcpy, memset

from libcpp.cmath cimport trunc
from libc.math cimport INFINITY

from cpython.sequence cimport PySequence_Check
from cython.view cimport array as cython_array

from .backends.time cimport monotonic_ns

from .core cimport baseHandler, drawingItem, uiItem, \
    lock_gil_friendly, clear_obj_vector, append_obj_vector, \
    draw_drawing_children, draw_menubar_children, \
    draw_ui_children, button_area, \
    draw_tab_children, Callback, ItemStateView, \
    Context, SharedValue, update_current_mouse_states
from .c_types cimport unique_lock, DCGMutex, Vec2, Vec4, \
    DCGString, string_to_str, string_from_str, string_from_bytes,\
    swap_Vec2
from .imgui_types cimport unparse_color, parse_color, Vec2ImVec2, \
    Vec4ImVec4, ImVec2Vec2, ImVec4Vec4
from .types cimport read_point, make_MouseButtonMask, MouseButtonMask,\
    read_vec4, Coord, child_type, make_TextMarker, is_TextMarker, TextMarker
from .wrapper cimport imgui

from .imgui_types cimport is_ButtonDirection, make_ButtonDirection

cdef class DrawInvisibleButton(drawingItem):
    """
    Invisible rectangular area, parallel to axes, behaving
    like a button (using imgui default handling of buttons).

    Unlike other Draw items, this item accepts handlers and callbacks.

    DrawInvisibleButton can be overlapped on top of each other. In that
    case only one will be considered hovered. This one corresponds to the
    last one of the rendering tree that is hovered. If the button is
    considered active (see below), it retains the hover status to itself.
    Thus if you drag an invisible button on top of items later in the
    rendering tree, they will not be considered hovered.

    Note that only the mouse button(s) that trigger activation will
    have the above described behaviour for hover tests. If the mouse
    doesn't hover anymore the item, it will remain active as long
    as the configured buttons are pressed.

    When inside a plot, drag deltas are returned in plot coordinates,
    that is the deltas correspond to the deltas you must apply
    to your drawing coordinates compared to their original position
    to apply the dragging. When not in a plot, the drag deltas are
    in screen coordinates, and you must convert yourself to drawing
    coordinates if you are applying matrix transforms to your data.
    Generally matrix transforms are not well supported by
    DrawInvisibleButtons, and the shifted position that is updated
    during dragging might be invalid.

    Dragging handlers will not be triggered if the item is not active
    (unlike normal imgui items).

    If you create a DrawInvisibleButton in front of the mouse while
    the mouse is clicked with one of the activation buttons, it will
    steal hovering and activation tests. This is not the case of other
    gui items (except modal windows).

    If your Draw Button is not part of a window (ViewportDrawList),
    the hovering test might not be reliable (except specific case above).

    DrawInvisibleButton accepts children. In that case, the children
    are drawn relative to the coordinates of the DrawInvisibleButton,
    where top left is (0, 0) and bottom right is (1, 1).
    """
    def __cinit__(self):
        self._button = <int32_t>MouseButtonMask.ANY
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_hovered = True
        self.state.cap.has_rect_size = True
        self.state.cap.has_position = True
        self.p_state = &self.state
        self.can_have_drawing_child = True
        self._min_side = 0
        self._max_side = INFINITY
        self._capture_mouse = True
        self._no_input = False

    @property
    def button(self):
        """
        Mouse button mask that makes the invisible button
        active and triggers the item's callback.

        Default is all buttons

        The mask is an (OR) combination of
        1: left button
        2: right button
        4: middle button
        8: X1
        16: X2
        (See also MouseButtonMask)
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return make_MouseButtonMask(<MouseButtonMask>self._button)

    @button.setter
    def button(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._button = <int32_t>make_MouseButtonMask(value)

    @property
    def p1(self):
        """
        Corner of the invisible button in plot/drawing
        space
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)

    @p1.setter
    def p1(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self._p1, value)

    @property
    def p2(self):
        """
        Opposite corner of the invisible button in plot/drawing
        space
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p2)

    @p2.setter
    def p2(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self._p2, value)

    @property
    def min_side(self):
        """
        If the rectangle width or height after
        coordinate transform is lower than this,
        resize the screen space transformed coordinates
        such that the width/height are at least min_side.
        Retains original ratio.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._min_side

    @min_side.setter
    def min_side(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value < 0:
            value = 0
        self._min_side = value

    @property
    def max_side(self):
        """
        If the rectangle width or height after
        coordinate transform is higher than this,
        resize the screen space transformed coordinates
        such that the width/height are at max max_side.
        Retains original ratio.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._max_side

    @max_side.setter
    def max_side(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value < 0:
            value = 0
        self._max_side = value

    @property
    def handlers(self):
        """
        Writable attribute: bound handlers for the item.
        If read returns a list of handlers. Accept
        a handler or a list of handlers as input.
        This enables to do item.handlers += [new_handler].
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int32_t i
        cdef baseHandler handler
        for i in range(<int>self._handlers.size()):
            handler = <baseHandler>self._handlers[i]
            result.append(handler)
        return result

    @handlers.setter
    def handlers(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list items = []
        cdef int32_t i
        if value is None:
            clear_obj_vector(self._handlers)
            return
        if PySequence_Check(value) == 0:
            value = (value,)
        for i in range(len(value)):
            if not(isinstance(value[i], baseHandler)):
                raise TypeError(f"{value[i]} is not a handler")
            # Check the handlers can use our states. Else raise error
            (<baseHandler>value[i]).check_bind(self)
            items.append(value[i])
        # Success: bind
        clear_obj_vector(self._handlers)
        append_obj_vector(self._handlers, items)

    @property
    def no_input(self):
        """
        Writable attribute: If enabled, this item will not
        detect hovering or activation, thus letting other
        items taking the inputs.

        This is useful to use no_input - rather than show=False,
        if you want to still have handlers run if the item
        is in the visible region.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._no_input

    @no_input.setter
    def no_input(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._no_input = value

    @property
    def capture_mouse(self):
        """
        Writable attribute: If set, the item will
        capture the mouse if hovered even if another
        item was already active.

        As it is not in general a good behaviour (and
        will not behave well if several items with this
        state are overlapping),
        this is reset to False every frame.

        Default is True on creation. Thus creating an item
        in front of the mouse will capture it.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._capture_mouse

    @capture_mouse.setter
    def capture_mouse(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._capture_mouse = value

    @property
    def state(self):
        """
        The current state of the button
        
        The state is an instance of ItemStateView which is a class
        with property getters to retrieve various readonly states.

        The ItemStateView instance is just a view over the current states,
        not a copy, thus the states get updated automatically.
        """
        return ItemStateView.create(self)

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._show):
            return

        self.set_previous_states()

        # Get button position in screen space
        cdef float[2] p1
        cdef float[2] p2
        self.context.viewport.coordinate_to_screen(p1, self._p1)
        self.context.viewport.coordinate_to_screen(p2, self._p2)
        cdef imgui.ImVec2 top_left
        cdef imgui.ImVec2 bottom_right
        cdef imgui.ImVec2 center
        cdef imgui.ImVec2 size
        top_left.x = min(p1[0], p2[0])
        top_left.y = min(p1[1], p2[1])
        bottom_right.x = max(p1[0], p2[0])
        bottom_right.y = max(p1[1], p2[1])
        center.x = (top_left.x + bottom_right.x) / 2.
        center.y = (top_left.y + bottom_right.y) / 2.
        size.x = bottom_right.x - top_left.x
        size.y = bottom_right.y - top_left.y
        cdef float ratio = 1e30
        if size.y != 0.:
            ratio = size.x/size.y
        elif size.x == 0:
            ratio = 1.

        if size.x < self._min_side:
            #size.y += (self._min_side - size.x) / ratio
            size.x = self._min_side
        if size.y < self._min_side:
            #size.x += (self._min_side - size.y) * ratio
            size.y = self._min_side
        if size.x > self._max_side:
            #size.y = max(0., size.y - (size.x - self._max_side) / ratio)
            size.x = self._max_side
        if size.y > self._max_side:
            #size.x += max(0., size.x - (size.y - self._max_side) * ratio)
            size.y = self._max_side
        top_left.x = center.x - size.x * 0.5
        bottom_right.x = top_left.x + size.x * 0.5
        top_left.y = center.y - size.y * 0.5
        bottom_right.y = top_left.y + size.y
        # Update rect and position size
        self.state.cur.rect_size = ImVec2Vec2(size)
        self.state.cur.pos_to_viewport = ImVec2Vec2(top_left)
        self.state.cur.pos_to_window.x = self.state.cur.pos_to_viewport.x - self.context.viewport.window_pos.x
        self.state.cur.pos_to_window.y = self.state.cur.pos_to_viewport.y - self.context.viewport.window_pos.y
        self.state.cur.pos_to_parent.x = self.state.cur.pos_to_viewport.x - self.context.viewport.parent_pos.x
        self.state.cur.pos_to_parent.y = self.state.cur.pos_to_viewport.y - self.context.viewport.parent_pos.y
        cdef bint was_visible = self.state.cur.rendered
        self.state.cur.rendered = imgui.IsRectVisible(top_left, bottom_right) or self.state.cur.active
        if not(was_visible) and not(self.state.cur.rendered):
            # Item is entirely clipped.
            # Do not skip the first time it is clipped,
            # in order to update the relevant states to False.
            # If the button is active, do not skip anything.
            return

        # Render children if any
        cdef double[2] cur_scales = self.context.viewport.scales
        cdef double[2] cur_shifts = self.context.viewport.shifts
        cdef bint cur_in_plot = self.context.viewport.in_plot

        # draw children
        if self.last_drawings_child is not None:
            self.context.viewport.shifts[0] = <double>top_left.x
            self.context.viewport.shifts[1] = <double>top_left.y
            self.context.viewport.scales = [<double>size.x, <double>size.y]
            self.context.viewport.in_plot = False
            # TODO: Unsure...
            self.context.viewport.thickness_multiplier = 1.
            self.context.viewport.size_multiplier = 1.
            draw_drawing_children(self, drawlist)

        # restore states
        self.context.viewport.scales = cur_scales
        self.context.viewport.shifts = cur_shifts
        self.context.viewport.in_plot = cur_in_plot

        cdef bint mouse_down = False
        if (self._button & 1) != 0 and imgui.IsMouseDown(imgui.ImGuiMouseButton_Left):
            mouse_down = True
        if (self._button & 2) != 0 and imgui.IsMouseDown(imgui.ImGuiMouseButton_Right):
            mouse_down = True
        if (self._button & 4) != 0 and imgui.IsMouseDown(imgui.ImGuiMouseButton_Middle):
            mouse_down = True


        cdef Vec2 cur_mouse_pos
        cdef float[2] screen_p
        cdef double[2] coordinate_p

        cdef bool hovered = False
        cdef bool held = False
        cdef bint activated
        if not(self._no_input):
            activated = button_area(self.context,
                                    self.uuid,
                                    ImVec2Vec2(top_left),
                                    ImVec2Vec2(size),
                                    self._button,
                                    True,
                                    True,
                                    self._capture_mouse,
                                    &hovered,
                                    &held)
        else:
            activated = False
        self._capture_mouse = False
        self.state.cur.active = activated or held
        self.state.cur.hovered = hovered
        if activated:
            cur_mouse_pos = ImVec2Vec2(imgui.GetMousePos())
            screen_p[0] = cur_mouse_pos.x
            screen_p[1] = cur_mouse_pos.y
            self.context.viewport.screen_to_coordinate(coordinate_p, screen_p)
            cur_mouse_pos.x = coordinate_p[0]
            cur_mouse_pos.y = coordinate_p[1]
            self._initial_mouse_position = cur_mouse_pos
        cdef bint dragging = False
        cdef int32_t i
        if self.state.cur.active:
            cur_mouse_pos = ImVec2Vec2(imgui.GetMousePos())
            screen_p[0] = cur_mouse_pos.x
            screen_p[1] = cur_mouse_pos.y
            self.context.viewport.screen_to_coordinate(coordinate_p, screen_p)
            cur_mouse_pos.x = coordinate_p[0]
            cur_mouse_pos.y = coordinate_p[1]
            dragging = cur_mouse_pos.x != self._initial_mouse_position.x or \
                       cur_mouse_pos.y != self._initial_mouse_position.y
            for i in range(<int>imgui.ImGuiMouseButton_COUNT):
                self.state.cur.dragging[i] = dragging and imgui.IsMouseDown(i)
                if dragging:
                    self.state.cur.drag_deltas[i].x = cur_mouse_pos.x - self._initial_mouse_position.x
                    self.state.cur.drag_deltas[i].y = cur_mouse_pos.y - self._initial_mouse_position.y
        else:
            for i in range(<int>imgui.ImGuiMouseButton_COUNT):
                self.state.cur.dragging[i] = False

        if self.state.cur.hovered:
            for i in range(<int>imgui.ImGuiMouseButton_COUNT):
                self.state.cur.clicked[i] = imgui.IsMouseClicked(i, False)
                self.state.cur.double_clicked[i] = imgui.IsMouseDoubleClicked(i)
        else:
            for i in range(<int>imgui.ImGuiMouseButton_COUNT):
                self.state.cur.clicked[i] = False
                self.state.cur.double_clicked[i] = False

        self.run_handlers()


cdef class DrawInWindow(uiItem):
    """
    An UI item that contains a region for Draw* elements.

    Enables to insert Draw* Elements inside a window. Inside a DrawInWindow 
    elements, the (0, 0) coordinate starts at the top left of the DrawWindow 
    and y increases when going down. The drawing region is clipped by the 
    available width/height of the item (set manually, or deduced).

    An invisible button is created to span the entire drawing area, which is 
    used to retrieve button states on the area (hovering, active, etc). If set, 
    the callback is called when the mouse is pressed inside the area with any 
    of the left, middle or right button. In addition, the use of an invisible 
    button enables the drag and drop behaviour proposed by imgui.

    If you intend on dragging elements inside the drawing area, you can either 
    implement yourself a hovering test for your specific items and use the 
    context's is_mouse_dragging, or add invisible buttons on top of the elements 
    you want to interact with, and combine the active and mouse dragging handlers. 
    Note if you intend to make an element draggable that way, you must not make 
    the element source of a Drag and Drop, as it impacts the hovering tests.

    Note that Drawing items do not have any hovering/clicked/visible/etc tests 
    maintained and thus do not have a callback.
    """
    def __cinit__(self):
        self.can_have_drawing_child = True
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_hovered = True
        self.state.cap.has_rect_size = True
        self.has_frame = False
        self.orig_x = 0
        self.orig_y = 0
        self.scale_x = 1.
        self.scale_y = 1.
        self.relative_scaling = False
        self.invert_y = False
        self.button = False

    @property
    def button(self):
        """
        Controls if the entire DrawInWindow area behaves like a single button.

        When True, the area acts as a clickable button with hover detection.
        When False (default), clicks and the hovered status will be forwarded
        to the window underneath.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.button

    @button.setter
    def button(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.button = value

    @property
    def frame(self):
        """
        Controls whether the item has a visual frame.

        By default the frame is disabled for DrawInWindow. When enabled,
        a border will be drawn around the drawing area.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.has_frame

    @frame.setter
    def frame(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.has_frame = value

    @property
    def orig_x(self):
        """
        The starting X coordinate inside the item (top-left).

        This value represents the horizontal offset that will be applied to
        the origin of the drawing coordinates. It effectively shifts all
        child drawing elements by this amount horizontally.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.orig_x

    @orig_x.setter
    def orig_x(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.orig_x = value

    @property
    def orig_y(self):
        """
        The starting Y coordinate inside the item (top-left).

        This value represents the vertical offset that will be applied to
        the origin of the drawing coordinates. It effectively shifts all
        child drawing elements by this amount vertically.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.orig_x

    @orig_y.setter
    def orig_y(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.orig_y = value

    @property
    def scale_x(self):
        """
        The X scaling factor for items inside the drawing area.

        If set to 1.0 (default), the scaling corresponds to the unit of a pixel
        (as per global_scale). That is, the coordinate of the end of the visible
        area corresponds to item.width.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.scale_x

    @scale_x.setter
    def scale_x(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.scale_x = value

    @property
    def scale_y(self):
        """
        The Y scaling factor for items inside the drawing area.

        If set to 1.0 (default), the scaling corresponds to the unit of a pixel
        (as per global_scale). That is, the coordinate of the end of the visible
        area corresponds to item.height.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.scale_y

    @scale_y.setter
    def scale_y(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.scale_y = value

    @property
    def relative(self):
        """
        Determines if scaling is relative to the item's dimensions.

        When enabled, the scaling is relative to the item's width and height.
        This means the coordinate of the end of the visible area is
        (orig_x, orig_y) + (scale_x, scale_y). When disabled (default),
        scaling is absolute in pixel units.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.relative_scaling

    @relative.setter
    def relative(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.relative_scaling = value

    @property
    def no_global_scaling(self):
        """
        Disables the global dpi scale.

        When enabled, one unit in drawing space corresponds to exactly
        one pixel on the screen, rather than to one scaled pixel (scaled
        to be dpi invariant).

        In additions, outline thickness in screen space (items with negative
        thickness) will not be scaled when this setting is set. Unlike the
        previous statement, this also applies when relative is set to True.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._no_global_scale

    @no_global_scaling.setter
    def no_global_scaling(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._no_global_scale = value

    @property
    def invert_y(self):
        """
        Controls the direction of the Y coordinate axis.

        When True, orig_x/orig_y correspond to the bottom left of the item, and y
        increases when going up (Cartesian coordinates). When False (default),
        this is the top left, and y increases when going down (screen 
        coordinates).
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.invert_y

    @invert_y.setter
    def invert_y(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.invert_y = value

    cdef bint draw_item(self) noexcept nogil:
        cdef bint no_frame = not(self.has_frame)
        # Remove frames
        if no_frame:
            imgui.PushStyleVar(imgui.ImGuiStyleVar_FrameBorderSize, imgui.ImVec2(0., 0.))
            imgui.PushStyleVar(imgui.ImGuiStyleVar_FramePadding, imgui.ImVec2(0., 0.))
        cdef Vec2 requested_size = self.get_requested_size()
        cdef float clip_width, clip_height
        if requested_size.x == 0:
            clip_width = self.context.viewport.parent_size.x
        elif requested_size.x > 0:
            clip_width = requested_size.x
        else:
            clip_width = self.context.viewport.parent_size.x - requested_size.x
        if requested_size.y == 0:
            clip_height = imgui.GetFrameHeight()
        elif requested_size.y > 0:
            clip_height = requested_size.y
        else:
            clip_height = self.context.viewport.parent_size.y
        if clip_height <= 0 or clip_width <= 0:
            if no_frame:
                imgui.PopStyleVar(2)
            self.set_hidden_no_handler_and_propagate_to_children_with_handlers() # won't propagate though
            return False
        cdef imgui.ImDrawList* drawlist = imgui.GetWindowDrawList()

        cdef float startx = <float>imgui.GetCursorScreenPos().x
        cdef float starty = <float>imgui.GetCursorScreenPos().y

        # Reset current drawInfo
        self.context.viewport.in_plot = False
        self.context.viewport.parent_pos = ImVec2Vec2(imgui.GetCursorScreenPos())
        self.context.viewport.shifts[0] = <double>startx
        self.context.viewport.shifts[1] = <double>starty
        cdef double scale, scale_x, scale_y
        if self.relative_scaling:
            scale_x = clip_width / self.scale_x
            scale_y = clip_height / self.scale_y
            scale = min(scale_x, scale_y)
        else:
            scale = 1. if self._no_global_scale else <double>self.context.viewport.global_scale
            scale_x = self.scale_x * scale
            scale_y = self.scale_y * scale
        self.context.viewport.scales = [scale_x, scale_y]
        self.context.viewport.thickness_multiplier = 1. if self._no_global_scale else <double>self.context.viewport.global_scale
        self.context.viewport.size_multiplier = scale_x #min(scale_x, scale_y) -> scale_x for compatibility with plots

        if self.invert_y:
            self.context.viewport.shifts[1] = \
                self.context.viewport.shifts[1] + clip_height - 1
            self.context.viewport.scales[1] = -self.context.viewport.scales[1]

        self.context.viewport.shifts[1] = \
            self.context.viewport.shifts[1] - self.orig_y
        self.context.viewport.shifts[0] = \
            self.context.viewport.shifts[0] - self.orig_x

        imgui.PushClipRect(imgui.ImVec2(startx, starty),
                           imgui.ImVec2(startx + clip_width,
                                        starty + clip_height),
                           True)

        draw_drawing_children(self, drawlist)

        imgui.PopClipRect()

        # Indicate the item might be overlapped by over UI,
        # for correct hovering tests. Indeed the user might want
        # to insert some UI on top of the draw elements.
        imgui.SetNextItemAllowOverlap()
        cdef bint active
        if self.button:
            active = imgui.InvisibleButton(self._imgui_label.c_str(),
                                           imgui.ImVec2(clip_width,
                                                        clip_height),
                                           imgui.ImGuiButtonFlags_MouseButtonLeft | \
                                           imgui.ImGuiButtonFlags_MouseButtonRight | \
                                           imgui.ImGuiButtonFlags_MouseButtonMiddle)
        else:
            imgui.Dummy(imgui.ImVec2(clip_width, clip_height))
            active = False

        self.update_current_state()
        if no_frame:
            imgui.PopStyleVar(2)
        return active



cdef class SimplePlot(uiItem):
    """
    A simple plot widget that displays data as a line graph or histogram.
    
    This widget provides a straightforward way to visualize numerical data
    with minimal configuration. It supports both line plots and histograms,
    with automatic or manual scaling.
    
    The data to display is stored in a SharedFloatVect, which can be accessed
    and modified through the value property inherited from uiItem.
    """
    def __cinit__(self):
        self._value = <SharedValue>(SharedFloatVect.__new__(SharedFloatVect, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self._scale_min = 0.
        self._scale_max = 0.
        self.histogram = False
        self._autoscale = True
        self._last_frame_autoscale_update = -1

    @property
    def scale_min(self):
        """
        The minimum value of the plot's vertical scale.
        
        When autoscale is False, this value defines the lower bound of the
        plot's vertical axis. Values below this threshold will be clipped.
        Ignored when autoscale is True.
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
        The maximum value of the plot's vertical scale.
        
        When autoscale is False, this value defines the upper bound of the
        plot's vertical axis. Values above this threshold will be clipped.
        Ignored when autoscale is True.
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
    def histogram(self):
        """
        Determines if the plot displays data as a histogram.
        
        When True, data is displayed as a bar chart (histogram). When False,
        data is displayed as a line plot. Default is False.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._histogram

    @histogram.setter
    def histogram(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._histogram = value

    @property
    def autoscale(self):
        """
        Controls whether the plot automatically scales to fit the data.
        
        When True, scale_min and scale_max are automatically calculated based
        on the minimum and maximum values in the data. When False, the
        manually set scale_min and scale_max values are used. Default is True.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._autoscale

    @autoscale.setter
    def autoscale(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._autoscale = value

    @property
    def overlay(self):
        """
        Text to display as an overlay on the plot.
        
        This text appears in the top-left corner of the plot area and can
        be used to display additional information about the data being shown.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return string_to_str(self._overlay)

    @overlay.setter
    def overlay(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._overlay = string_from_str(value)

    cdef bint draw_item(self) noexcept nogil:
        cdef float[::1] data = SharedFloatVect.get(<SharedFloatVect>self._value)
        cdef int32_t i
        if self._autoscale and data.shape[0] > 0:
            if self._value._last_frame_change != self._last_frame_autoscale_update:
                self._last_frame_autoscale_update = self._value._last_frame_change
                self._scale_min = data[0]
                self._scale_max = data[0]
                for i in range(1, data.shape[0]):
                    if self._scale_min > data[i]:
                        self._scale_min = data[i]
                    if self._scale_max < data[i]:
                        self._scale_max = data[i]

        if self._histogram:
            imgui.PlotHistogram(self._imgui_label.c_str(),
                                &data[0],
                                <int>data.shape[0],
                                0,
                                self._overlay.c_str(),
                                self._scale_min,
                                self._scale_max,
                                Vec2ImVec2(self.get_requested_size()),
                                sizeof(float))
        else:
            imgui.PlotLines(self._imgui_label.c_str(),
                            &data[0],
                            <int>data.shape[0],
                            0,
                            self._overlay.c_str(),
                            self._scale_min,
                            self._scale_max,
                            Vec2ImVec2(self.get_requested_size()),
                            sizeof(float))
        self.update_current_state()
        return False

cdef class Button(uiItem):
    """
    A clickable UI button that can trigger actions when pressed.
    
    Buttons are one of the most common UI elements for user interaction.
    They can be styled in different ways (normal, small, arrow) and can
    be configured to repeat actions when held down. The button's state
    is stored in a SharedBool value that tracks whether it's active.
    """
    def __cinit__(self):
        self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self._direction = imgui.ImGuiDir_None
        self._small = False
        self._arrow = False
        self._repeat = False

    @property
    def arrow(self):
        """
        If not None, draw an arrow with the specified direction.
        
        This property is ignored when small is set, and in addition the requested
        size is ignored (but is affected by theme settings).

        Possible values are defined in the ButtonDirection enum: Up, Down, Left, Right.
        None means the feature is disabled and the button will be drawn normally.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self._direction == imgui.ImGuiDir_None:
            return None
        return make_ButtonDirection(self._direction)

    @arrow.setter
    def arrow(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._direction = imgui.ImGuiDir_None
        elif not is_ButtonDirection(value):
            raise TypeError("Invalid type for arrow property. Expected ButtonDirection or None.")
        else:
            self._direction = <imgui.ImGuiDir><int>make_ButtonDirection(value)

    @property
    def small(self):
        """
        Whether the button should be displayed in a small size.
        
        Small buttons have a more compact appearance with less padding than 
        standard buttons. When set to True, overrides the arrow property.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._small

    @small.setter
    def small(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._small = value

    @property
    def repeat(self):
        """
        Whether the button generates repeated events when held down.
        
        When enabled, the button will trigger clicked events repeatedly while
        being held down, rather than just a single event when clicked. This
        is useful for actions that should be repeatable, like incrementing
        or decrementing values.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._repeat

    @repeat.setter
    def repeat(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._repeat = value

    cdef bint draw_item(self) noexcept nogil:
        cdef bint activated
        imgui.PushItemFlag(imgui.ImGuiItemFlags_ButtonRepeat, self._repeat)
        if self._small:
            activated = imgui.SmallButton(self._imgui_label.c_str())
        elif <imgui.ImGuiDir>self._direction != imgui.ImGuiDir_None:
            activated = imgui.ArrowButton(self._imgui_label.c_str(), <imgui.ImGuiDir>self._direction)
        else:
            activated = imgui.Button(self._imgui_label.c_str(),
                                     Vec2ImVec2(self.get_requested_size()))
        imgui.PopItemFlag()
        self.update_current_state()
        SharedBool.set(<SharedBool>self._value, self.state.cur.active) # Unsure. Not in original
        if self._repeat:
            if self.state.cur.active != self.state.prev.active:
                # Just clicked: prepare a check for press after the repeat delay
                self.context.viewport.ask_refresh_after(imgui.GetIO().KeyRepeatDelay)
            elif self.state.cur.active:
                # Still active: check if we are still pressed after the repeat delay
                # Refresh frequently to spawn the activated events at the expected rate
                self.context.viewport.ask_refresh_after(imgui.GetIO().KeyRepeatRate)
        return activated


cdef class Combo(uiItem):
    """
    A dropdown selection widget that displays a list of choices.
    
    Combo widgets provide an efficient way to select a single option from a
    list of items. When clicked, the dropdown expands to reveal a scrollable
    list of selectable options. Only one option can be selected at a time.
    
    The widget features configurable height modes, arrow button visibility,
    preview display options, and alignment settings to accommodate different
    interface needs.

    The selected value is stored in a SharedStr value, which can be accessed
    and modified through the value property inherited from uiItem. It corresponds
    to the currently selected item in the dropdown list.
    """
    def __cinit__(self):
        self._value = <SharedValue>(SharedStr.__new__(SharedStr, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_deactivated_after_edited = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_edited = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_toggled = True
        self._flags = imgui.ImGuiComboFlags_HeightRegular

    @property
    def items(self):
        """
        List of text values to select from in the combo dropdown.
        
        This property contains all available options that will be displayed
        when the combo is opened. If the value of the combo is not in this
        list, no item will appear selected. When the list is first created
        and the value is not yet set, the first item in this list (if any)
        will be automatically selected.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int i
        for i in range(<int>self._items.size()):
            result.append(string_to_str(self._items[i]))
        return result

    @items.setter
    def items(self, value):
        cdef unique_lock[DCGMutex] m
        cdef unique_lock[DCGMutex] value_m
        lock_gil_friendly(m, self.mutex)
        self._items.clear()
        if value is None:
            return
        if value is str:
            self._items.push_back(string_from_str(value))
        elif PySequence_Check(value) > 0:
            for v in value:
                self._items.push_back(string_from_str(v))
        else:
            raise ValueError(f"Invalid type {type(value)} passed as items. Expected array of strings")
        lock_gil_friendly(value_m, self._value.mutex)
        if self._value._num_attached == 1 and \
           self._value._last_frame_update == -1 and \
           self._items.size() > 0: # TODO: this doesn't seem reliable enough
            # initialize the value with the first element
            SharedStr.set(<SharedStr>self._value, self._items[0])

    @property
    def height_mode(self):
        """
        Controls the height of the dropdown portion of the combo.
        
        Supported values are "small", "regular", "large", and "largest".
        This affects how many items are visible at once when the dropdown
        is open, with "regular" being the default size.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if (self._flags & imgui.ImGuiComboFlags_HeightSmall) != 0:
            return "small"
        elif (self._flags & imgui.ImGuiComboFlags_HeightLargest) != 0:
            return "largest"
        elif (self._flags & imgui.ImGuiComboFlags_HeightLarge) != 0:
            return "large"
        return "regular" # TODO: add type for that ?

    @height_mode.setter
    def height_mode(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~(imgui.ImGuiComboFlags_HeightSmall |
                        imgui.ImGuiComboFlags_HeightRegular |
                        imgui.ImGuiComboFlags_HeightLarge |
                        imgui.ImGuiComboFlags_HeightLargest)
        if value == "small":
            self._flags |= imgui.ImGuiComboFlags_HeightSmall
        elif value == "regular":
            self._flags |= imgui.ImGuiComboFlags_HeightRegular
        elif value == "large":
            self._flags |= imgui.ImGuiComboFlags_HeightLarge
        elif value == "largest":
            self._flags |= imgui.ImGuiComboFlags_HeightLargest
        else:
            self._flags |= imgui.ImGuiComboFlags_HeightRegular
            raise ValueError("Invalid height mode {value}")

    @property
    def popup_align_left(self):
        """
        Aligns the dropdown popup with the left edge of the combo button.
        
        When enabled, the dropdown list will be aligned with the left edge
        instead of the default alignment. This can be useful when the combo
        is positioned near the right edge of the screen.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiComboFlags_PopupAlignLeft) != 0

    @popup_align_left.setter
    def popup_align_left(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiComboFlags_PopupAlignLeft
        if value:
            self._flags |= imgui.ImGuiComboFlags_PopupAlignLeft

    @property
    def no_arrow_button(self):
        """
        Hides the dropdown arrow button on the combo widget.
        
        When enabled, the combo will not display the arrow button that typically
        appears on the right side. This can be useful for creating more compact
        interfaces or custom styling.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiComboFlags_NoArrowButton) != 0

    @no_arrow_button.setter
    def no_arrow_button(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiComboFlags_NoArrowButton
        if value:
            self._flags |= imgui.ImGuiComboFlags_NoArrowButton

    @property
    def no_preview(self):
        """
        Disables the preview of the selected item in the combo button.
        
        When enabled, the combo button will not display the currently selected
        value. This can be useful for creating more compact interfaces or when
        the selection is indicated elsewhere.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiComboFlags_NoPreview) != 0

    @no_preview.setter
    def no_preview(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiComboFlags_NoPreview
        if value:
            self._flags |= imgui.ImGuiComboFlags_NoPreview

    @property
    def fit_width(self):
        """
        Makes the combo resize to fit the width of its content.
        
        When enabled, the combo width will expand to fit the content of the
        preview. This ensures that long text items don't get truncated in
        the combo display.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiComboFlags_WidthFitPreview) != 0

    @fit_width.setter
    def fit_width(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiComboFlags_WidthFitPreview
        if value:
            self._flags |= imgui.ImGuiComboFlags_WidthFitPreview

    cdef bint draw_item(self) noexcept nogil:
        cdef bint open
        cdef int32_t i
        cdef DCGString current_value
        SharedStr.get(<SharedStr>self._value, current_value)

        cdef Vec2 requested_size = self.get_requested_size()
        if requested_size.x != 0:
            imgui.SetNextItemWidth(requested_size.x)

        open = imgui.BeginCombo(self._imgui_label.c_str(),
                                current_value.c_str(),
                                self._flags)
        # Old code called update_current_state now, and updated edited state
        # later. Looking at ImGui code there seems to be two items. One
        # for the combo, and one for the popup that opens. The edited flag
        # is not set, looking at imgui demo so we have to handle it manually.
        self.state.cur.open = open
        self.update_current_state_subset()

        cdef bool pressed = False
        cdef bint changed = False
        cdef bool selected
        cdef bool selected_backup
        # we push an ID because we didn't append ###uuid to the items
        
        # TODO: there are nice ImGuiSelectableFlags to add in the future
        if open:
            imgui.PushID(self.uuid)
            if self._enabled:
                for i in range(<int>self._items.size()):
                    selected = self._items[i] == current_value
                    selected_backup = selected
                    pressed |= imgui.Selectable(self._items[i].c_str(),
                                                &selected,
                                                imgui.ImGuiSelectableFlags_None,
                                                Vec2ImVec2(self.get_requested_size()))
                    if selected:
                        imgui.SetItemDefaultFocus()
                    if selected and selected != selected_backup:
                        changed = True
                        SharedStr.set(<SharedStr>self._value, self._items[i])
            else:
                # TODO: test
                selected = True
                imgui.Selectable(current_value.c_str(),
                                 &selected,
                                 imgui.ImGuiSelectableFlags_Disabled,
                                 Vec2ImVec2(self.get_requested_size()))
            imgui.PopID()
            imgui.EndCombo()
        # TODO: rect_size/min/max: with the popup ? Use clipper for rect_max ?
        self.state.cur.edited = changed
        self.state.cur.deactivated_after_edited = self.state.prev.active and changed and not(self.state.cur.active)
        return pressed


cdef class Checkbox(uiItem):
    """
    A checkbox UI element that allows toggling a boolean value.
    
    A checkbox is a standard UI control that displays a square box which can be 
    checked or unchecked by the user. It's commonly used to represent binary 
    choices or toggle settings in an application.
    
    The checkbox's state is stored in a SharedBool value, which can be accessed 
    and modified through the inherited value property. When clicked, the checkbox 
    toggles between checked and unchecked states.
    
    The checkbox responds to user interaction with proper hover and focus states,
    and can be disabled to prevent user interaction while still displaying the
    current value.

    If a label is provided, it will be displayed at the right of the checkbox.
    """
    def __cinit__(self):
        self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True

    cdef bint draw_item(self) noexcept nogil:
        cdef bool checked = SharedBool.get(<SharedBool>self._value)
        cdef bint pressed = imgui.Checkbox(self._imgui_label.c_str(),
                                             &checked)
        if self._enabled:
            SharedBool.set(<SharedBool>self._value, checked)
        self.update_current_state()
        return pressed

cdef extern from * nogil:
    """
    ImVec2 GetDefaultItemSize(ImVec2 requested_size)
    {
        return ImTrunc(ImGui::CalcItemSize(requested_size, ImGui::CalcItemWidth(), ImGui::GetTextLineHeightWithSpacing() * 7.25f + ImGui::GetStyle().FramePadding.y * 2.0f));
    }
    """
    imgui.ImVec2 GetDefaultItemSize(imgui.ImVec2)

cdef class Slider(uiItem):
    """
    A widget that allows selecting values by dragging a handle along a track.
    
    Sliders provide an intuitive way to select numeric values within a defined 
    range. They can be configured as horizontal or vertical bars, or as drag 
    controls that adjust values based on mouse movement distance rather than 
    absolute position.
    
    The appearance and behavior 
    can be customized with various options including logarithmic scaling and 
    different display formats.
    """
    def __cinit__(self):
        self._drag = False
        self._drag_speed = 1.
        self._print_format = string_from_bytes(b"%.3f")
        self._flags = 0
        self._min = 0.
        self._max = 100.
        self._vertical = False
        self._value = <SharedValue>(SharedFloat.__new__(SharedFloat, self.context))
        self.state.cap.can_be_active = True # unsure
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_edited = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True

    @property
    def keyboard_clamped(self):
        """
        Whether the slider value should be clamped even when set via keyboard.
        
        When enabled, the value will always be restricted to the min_value and 
        max_value range, even when the value is manually entered via keyboard 
        input (Ctrl+Click).
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiSliderFlags_AlwaysClamp) != 0

    @keyboard_clamped.setter
    def keyboard_clamped(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiSliderFlags_AlwaysClamp
        if value:
            self._flags |= imgui.ImGuiSliderFlags_AlwaysClamp

    @property
    def drag(self):
        """
        Whether to use a 'drag' slider rather than a regular one.
        
        When enabled, the slider behaves as a draggable control where the value 
        changes based on the distance the mouse moves, rather than the absolute 
        position within a fixed track. This is incompatible with the 'vertical' 
        property and will disable it if set.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._drag

    @drag.setter
    def drag(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._drag = value
        if value:
            self._vertical = False

    @property
    def logarithmic(self):
        """
        Whether the slider should use logarithmic scaling.
        
        When enabled, the slider will use logarithmic scaling, making it easier 
        to select values across different orders of magnitude.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiSliderFlags_Logarithmic) != 0

    @logarithmic.setter
    def logarithmic(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiSliderFlags_Logarithmic
        if value:
            self._flags |= imgui.ImGuiSliderFlags_Logarithmic

    @property
    def min_value(self):
        """
        Minimum value the slider will be clamped to.
        
        This defines the lower bound of the range within which the slider can be 
        adjusted. Values below this will be clamped to this minimum.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._min

    @min_value.setter
    def min_value(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._min = value

    @property
    def max_value(self):
        """
        Maximum value the slider will be clamped to.
        
        This defines the upper bound of the range within which the slider can be 
        adjusted. Values above this will be clamped to this maximum.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._max

    @max_value.setter
    def max_value(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._max = value

    @property
    def no_input(self):
        """
        Whether to disable keyboard input for the slider.
        
        When enabled, the slider will not respond to Ctrl+Click or Enter key 
        events that would normally allow manual value entry. The slider can 
        still be adjusted using the mouse.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiSliderFlags_NoInput) != 0

    @no_input.setter
    def no_input(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiSliderFlags_NoInput
        if value:
            self._flags |= imgui.ImGuiSliderFlags_NoInput

    @property
    def print_format(self):
        """
        Format string for converting the slider value to text for display.
        
        This follows standard printf-style formatting. If round_to_format is 
        enabled, the value will be rounded according to this format.
        
        Examples: "%.3f" for 3 decimal places (Default), "%.0f" for integers.

        If the value is not printed (for instance ""), the value is not rounded.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return string_to_str(self._print_format)

    @print_format.setter
    def print_format(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._print_format = string_from_str(value)

    @property
    def no_round(self):
        """
        Whether to disable the rounding of values according to the print_format.

        By default the slider's value is the value displayed in the UI.
        This setting will enable higher precision values to be set.

        For instance one could want a short version of the slider
        that display no decimals, but still allows setting a floating
        point value with a higher precision.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiSliderFlags_NoRoundToFormat) != 0

    @no_round.setter
    def no_round(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiSliderFlags_NoRoundToFormat
        if value:
            self._flags |= imgui.ImGuiSliderFlags_NoRoundToFormat

    @property
    def speed(self):
        """
        The speed at which the value changes when using drag mode.
        
        This setting controls how quickly the value changes when dragging in drag 
        mode. Higher values make the slider more sensitive to movement. Only 
        applies when the drag property is set to True.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._drag_speed

    @speed.setter
    def speed(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._drag_speed = value

    @property
    def vertical(self):
        """
        Whether to display the slider vertically instead of horizontally.
        
        When enabled, the slider will be displayed as a vertical bar. 

        This is only supported for sliders with drag=False.
        The setting will be ignored else.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._vertical

    @vertical.setter
    def vertical(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._vertical = value

    cdef bint draw_item(self) noexcept nogil:
        cdef imgui.ImGuiSliderFlags flags = self._flags
        if not(self._enabled):
            flags |= imgui.ImGuiSliderFlags_NoInput
        cdef imgui.ImGuiDataType type = imgui.ImGuiDataType_Double
        cdef double value_float
        cdef void *data
        cdef void *data_min
        cdef void *data_max
        cdef bint modified

        data_min = &self._min
        data_max = &self._max

        # Read the value
        value_float = SharedFloat.get(<SharedFloat>self._value)
        data = &value_float

        # Draw
        cdef Vec2 requested_size = self.get_requested_size()
        if requested_size.x != 0 and (self._drag or not self._vertical):
            imgui.SetNextItemWidth(requested_size.x)

        if self._drag:
            modified = imgui.DragScalar(self._imgui_label.c_str(),
                                        type,
                                        data,
                                        self._drag_speed,
                                        data_min,
                                        data_max,
                                        self._print_format.c_str(),
                                        flags)
        else:
            if self._vertical:
                modified = imgui.VSliderScalar(self._imgui_label.c_str(),
                                                GetDefaultItemSize(Vec2ImVec2(self.get_requested_size())),
                                                type,
                                                data,
                                                data_min,
                                                data_max,
                                                self._print_format.c_str(),
                                                flags)
            else:
                modified = imgui.SliderScalar(self._imgui_label.c_str(),
                                                type,
                                                data,
                                                data_min,
                                                data_max,
                                                self._print_format.c_str(),
                                                flags)

        # Write the value
        if self._enabled:
            SharedFloat.set(<SharedFloat>self._value, value_float)
        self.update_current_state()
        return modified


cdef class ListBox(uiItem):
    """
    A scrollable list of selectable text items with single selection support.
    
    ListBox provides a way to display a list of selectable strings in a scrollable 
    container. Users can select a single item from the list, which is then stored 
    in the item's value property.
    
    The list height can be controlled by setting the num_items_shown_when_open 
    property, which determines how many items are visible before scrolling is 
    required. When an item is selected, the widget's value is updated to contain 
    the text of the selected item.
    """
    def __cinit__(self):
        self._value = <SharedValue>(SharedStr.__new__(SharedStr, self.context))
        #self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        #self.state.cap.can_be_deactivated_after_edited = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_edited = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self._num_items_shown_when_open = -1

    @property
    def items(self):
        """
        List of text values from which the user can select.
        
        This property contains all available options that will be displayed in the 
        listbox. If the value of the listbox is not in this list, no item will 
        appear selected. When the list is first created and the value is not yet 
        set, the first item in this list (if any) will be automatically selected.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int i
        for i in range(<int>self._items.size()):
            result.append(string_to_str(self._items[i]))
        return result

    @items.setter
    def items(self, value):
        cdef unique_lock[DCGMutex] m
        cdef unique_lock[DCGMutex] value_m
        lock_gil_friendly(m, self.mutex)
        self._items.clear()
        if value is None:
            return
        if value is str:
            self._items.push_back(string_from_str(value))
        elif PySequence_Check(value) > 0:
            for v in value:
                self._items.push_back(string_from_str(v))
        else:
            raise ValueError(f"Invalid type {type(value)} passed as items. Expected array of strings")
        lock_gil_friendly(value_m, self._value.mutex)
        if self._value._num_attached == 1 and \
           self._value._last_frame_update == -1 and \
           self._items.size() > 0:
            # initialize the value with the first element
            SharedStr.set(<SharedStr>self._value, self._items[0])

    @property
    def num_items_shown_when_open(self):
        """
        Number of items visible in the listbox before scrolling is required.
        
        This controls the height of the listbox widget. If set to -1 (default), 
        the listbox will show up to 7 items or the total number of items if less 
        than 7. Setting a specific positive value will display that many items 
        at once, with scrolling enabled for additional items.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._num_items_shown_when_open

    @num_items_shown_when_open.setter
    def num_items_shown_when_open(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._num_items_shown_when_open = value

    cdef bint draw_item(self) noexcept nogil:
        # TODO: Merge with ComboBox
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        cdef bint visible
        cdef int32_t i
        cdef DCGString current_value
        SharedStr.get(<SharedStr>self._value, current_value)
        cdef imgui.ImVec2 popup_size = imgui.ImVec2(0., 0.)
        cdef float text_height = imgui.GetTextLineHeightWithSpacing()
        cdef int32_t num_items = min(7, <int>self._items.size())
        if self._num_items_shown_when_open > 0:
            num_items = self._num_items_shown_when_open
        # Computation from imgui
        popup_size.y = trunc(<float>0.25 + <float>num_items) * text_height
        popup_size.y += 2. * imgui.GetStyle().FramePadding.y
        visible = imgui.BeginListBox(self._imgui_label.c_str(),
                                     popup_size)

        cdef bool pressed = False
        cdef bint changed = False
        cdef bool selected
        cdef bool selected_backup
        # we push an ID because we didn't append ###uuid to the items
        
        # TODO: there are nice ImGuiSelectableFlags to add in the future
        # TODO: use clipper
        if visible:
            # ListBox is simply a ChildWindow wrapped in a group
            self.state.cur.hovered = imgui.IsWindowHovered(imgui.ImGuiHoveredFlags_None)
            self.state.cur.focused = imgui.IsWindowFocused(imgui.ImGuiFocusedFlags_None)
            self.state.cur.rect_size = ImVec2Vec2(imgui.GetWindowSize())
            update_current_mouse_states(self.state)
            imgui.PushID(self.uuid)
            if self._enabled:
                for i in range(<int>self._items.size()):
                    imgui.PushID(i)
                    selected = self._items[i] == current_value
                    selected_backup = selected
                    pressed |= imgui.Selectable(self._items[i].c_str(),
                                                &selected,
                                                imgui.ImGuiSelectableFlags_None,
                                                Vec2ImVec2(self.get_requested_size()))
                    if selected:
                        imgui.SetItemDefaultFocus()
                    if selected and selected != selected_backup:
                        changed = True
                        SharedStr.set(<SharedStr>self._value, self._items[i])
                    imgui.PopID()
            else:
                # TODO: test
                selected = True
                imgui.Selectable(current_value.c_str(),
                                 &selected,
                                 imgui.ImGuiSelectableFlags_Disabled,
                                 Vec2ImVec2(self.get_requested_size()))
            imgui.PopID()
            imgui.EndListBox()
        # TODO: rect_size/min/max: with the popup ? Use clipper for rect_max ?
        self.state.cur.edited = changed
        #self.state.cur.deactivated_after_edited = self.state.cur.deactivated and changed -> TODO Unsure. Isn't it rather focus loss ?
        return pressed


cdef class RadioButton(uiItem):
    def __cinit__(self):
        self._value = <SharedValue>(SharedStr.__new__(SharedStr, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_deactivated_after_edited = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_edited = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self._horizontal = False

    @property
    def items(self):
        """
        Writable attribute: List of text values to select
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int i
        for i in range(<int>self._items.size()):
            result.append(string_to_str(self._items[i]))
        return result

    @items.setter
    def items(self, value):
        cdef unique_lock[DCGMutex] m
        cdef unique_lock[DCGMutex] value_m
        lock_gil_friendly(m, self.mutex)
        self._items.clear()
        if value is None:
            return
        if value is str:
            self._items.push_back(string_from_str(value))
        elif PySequence_Check(value) > 0:
            for v in value:
                self._items.push_back(string_from_str(v))
        else:
            raise ValueError(f"Invalid type {type(value)} passed as items. Expected array of strings")
        lock_gil_friendly(value_m, self._value.mutex)
        if self._value._num_attached == 1 and \
           self._value._last_frame_update == -1 and \
           self._items.size() > 0:
            # initialize the value with the first element
            SharedStr.set(<SharedStr>self._value, self._items[0])

    @property
    def horizontal(self):
        """
        Writable attribute: Horizontal vs vertical placement
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._horizontal

    @horizontal.setter
    def horizontal(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._horizontal = value

    cdef bint draw_item(self) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        cdef bint open
        cdef int32_t i
        cdef DCGString current_value
        SharedStr.get(<SharedStr>self._value, current_value)
        imgui.PushID(self.uuid)
        imgui.BeginGroup()

        cdef bint changed = False
        cdef bool selected
        cdef bool selected_backup
        # we push an ID because we didn't append ###uuid to the items
        
        for i in range(<int>self._items.size()):
            imgui.PushID(i)
            if (self._horizontal and i != 0):
                imgui.SameLine(0., -1.)
            selected_backup = self._items[i] == current_value
            selected = imgui.RadioButton(self._items[i].c_str(),
                                         selected_backup)
            if self._enabled and selected and selected != selected_backup:
                changed = True
                SharedStr.set(<SharedStr>self._value, self._items[i])
            imgui.PopID()
        #imgui.PushStyleVar(imgui.ImGuiStyleVar_ItemSpacing,
        #                   imgui.ImVec2(0., 0.))
        imgui.EndGroup()
        #imgui.PopStyleVar(1)
        imgui.PopID()
        self.update_current_state()
        return changed


cdef class InputText(uiItem):
    """
    A text input widget for single or multi-line text entry.
    
    InputText provides a field for text entry with various configuration options
    including character filtering, password input, and multiline support. The entered
    text is stored in a SharedStr value that can be accessed via the value property.
    
    The widget supports features like input validation, auto-selection, and custom
    behaviors for special keys like Tab, Enter and Escape. It can be configured
    with a hint text that appears when the field is empty, and can limit input to
    specific character types (decimals, hexadecimal, etc).
    
    For multiline text entry, enable the multiline property which creates a text
    area instead of a single-line field.
    """
    def __init__(self, context, **kwargs):
        # Must be configured first
        if 'max_characters' in kwargs:
            self.max_characters = kwargs.pop('max_characters')
        uiItem.__init__(self, context, **kwargs)

    def __cinit__(self):
        self._value = <SharedValue>(SharedStr.__new__(SharedStr, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_deactivated_after_edited = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_edited = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self._multiline = False
        self._max_characters = 1024
        self._flags = imgui.ImGuiInputTextFlags_None
        self._buffer = <char*>malloc(self._max_characters + 1)
        if self._buffer == NULL:
            raise MemoryError("Failed to allocate input buffer")
        memset(<void*>self._buffer, 0, self._max_characters + 1)

    def __dealloc__(self):
        if self._buffer != NULL:
            free(<void*>self._buffer)

    def configure(self, **kwargs):
        """
        Configure the InputText widget with provided keyword arguments.
        
        Handles the 'max_characters' option before delegating to the parent class
        for standard configuration options.
        """
        if 'max_characters' in kwargs:
            self.max_characters = kwargs.pop('max_characters')
        return uiItem.configure(self, **kwargs)

    @property
    def hint(self):
        """
        Placeholder text shown when the input field is empty.
        
        This text appears in a light color when the input field contains no text,
        providing guidance to users about what should be entered. The hint is
        only available for single-line input fields and cannot be used with
        multiline mode.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return string_to_str(self._hint)

    @hint.setter
    def hint(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._hint = string_from_str(value)
        if len(value) > 0:
            self.multiline = False

    @property
    def multiline(self):
        """
        Whether the input field accepts multiple lines of text.
        
        When enabled, the input field becomes a text area that can contain line
        breaks and supports multiple paragraphs. When multiline is enabled,
        hint text cannot be used.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._multiline

    @multiline.setter
    def multiline(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._multiline = value
        if value:
            # reset hint
            self._hint = DCGString()

    @property
    def max_characters(self):
        """
        Maximum number of characters allowed in the input field.
        
        This sets the capacity of the internal buffer used to store the text.
        The default is 1024 characters. If you need to store longer text,
        increase this value before adding text that would exceed it.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._max_characters

    @max_characters.setter
    def max_characters(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value < 1:
            raise ValueError("There must be at least space for one character")
        if value == self._max_characters:
            return
        # Reallocate buffer
        cdef char* new_buffer = <char*>malloc(value + 1)
        if new_buffer == NULL:
            raise MemoryError("Failed to allocate input buffer")
        if self._buffer != NULL:
            # Copy old content 
            memcpy(<void*>new_buffer, <void*>self._buffer, min(value, self._max_characters))
            new_buffer[value] = 0
            free(<void*>self._buffer)
        self._buffer = new_buffer
        self._max_characters = value

    @property
    def decimal(self):
        """
        Restricts input to decimal numeric characters (0-9, +, -, .).
        
        When enabled, the input field will only allow characters suitable for
        entering decimal numbers. This is useful for creating numeric entry fields
        that don't require a full numeric widget.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_CharsDecimal) != 0

    @decimal.setter
    def decimal(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_CharsDecimal
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_CharsDecimal

    @property
    def hexadecimal(self):
        """
        Restricts input to hexadecimal characters (0-9, A-F, a-f).
        
        When enabled, the input field will only allow characters suitable for
        entering hexadecimal numbers. This is useful for entering color codes,
        memory addresses, or other hexadecimal values.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_CharsHexadecimal) != 0

    @hexadecimal.setter
    def hexadecimal(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_CharsHexadecimal
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_CharsHexadecimal

    @property
    def scientific(self):
        """
        Restricts input to scientific notation characters (0-9, +, -, ., *, /, e, E).
        
        When enabled, the input field will only allow characters suitable for
        entering numbers in scientific notation. This is useful for fields that
        need to accept very large or small numbers in scientific format.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_CharsScientific) != 0

    @scientific.setter
    def scientific(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_CharsScientific
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_CharsScientific

    @property
    def uppercase(self):
        """
        Automatically converts lowercase letters (a-z) to uppercase (A-Z).
        
        When enabled, any lowercase letters entered into the field will be
        automatically converted to uppercase. This is useful for fields where
        standardized uppercase input is desired, such as product codes or
        reference numbers.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_CharsUppercase) != 0

    @uppercase.setter
    def uppercase(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_CharsUppercase
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_CharsUppercase

    @property
    def no_spaces(self):
        """
        Prevents spaces and tabs from being entered into the field.
        
        When enabled, the input field will reject space and tab characters,
        ensuring the text contains no whitespace. This is useful for fields
        that require compact, whitespace-free input like usernames or identifiers.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_CharsNoBlank) != 0

    @no_spaces.setter
    def no_spaces(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_CharsNoBlank
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_CharsNoBlank

    @property
    def tab_input(self):
        """
        Allows tab key to insert a tab character into the text.
        
        When enabled, pressing the Tab key will insert a tab character ('\t')
        into the text field instead of moving focus to the next widget. This
        is particularly useful in multiline text areas where tab indentation
        is needed.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_AllowTabInput) != 0

    @tab_input.setter
    def tab_input(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_AllowTabInput
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_AllowTabInput

    @property
    def callback_on_enter(self):
        """
        Triggers callback when Enter key is pressed, regardless of edit state.
        
        When enabled, the item's callback will be triggered whenever the Enter key
        is pressed while the input is focused, not just when the value changes.
        This is useful for creating form-like interfaces where Enter submits the
        current input.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_EnterReturnsTrue) != 0

    @callback_on_enter.setter
    def callback_on_enter(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_EnterReturnsTrue
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_EnterReturnsTrue

    @property
    def escape_clears_all(self):
        """
        Makes Escape key clear the field's content instead of reverting changes.
        
        When enabled, pressing the Escape key will clear the entire text content
        if the field is not empty, or deactivate the field if it is empty.
        This differs from the default behavior where Escape reverts the field
        to its previous content.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_EscapeClearsAll) != 0

    @escape_clears_all.setter
    def escape_clears_all(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_EscapeClearsAll
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_EscapeClearsAll

    @property
    def ctrl_enter_for_new_line(self):
        """
        Reverses Enter and Ctrl+Enter behavior in multiline mode.
        
        When enabled in multiline mode, pressing Enter will submit the input,
        while Ctrl+Enter will insert a new line. This is the opposite of the
        default behavior where Enter inserts a new line and Ctrl+Enter submits.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_CtrlEnterForNewLine) != 0

    @ctrl_enter_for_new_line.setter
    def ctrl_enter_for_new_line(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_CtrlEnterForNewLine
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_CtrlEnterForNewLine

    @property
    def readonly(self):
        """
        Makes the input field non-editable by the user.
        
        When enabled, the text field will display its content but prevent the
        user from modifying it. The content can still be updated programmatically
        through the value property. This is useful for displaying information
        that should not be altered by the user.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_ReadOnly) != 0

    @readonly.setter
    def readonly(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_ReadOnly
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_ReadOnly

    @property
    def password(self):
        """
        Hides the input text by displaying asterisks and disables text copying.
        
        When enabled, all characters in the input field will be displayed as
        asterisks (*), hiding the actual content from view. This is useful for
        password entry fields or other sensitive information. Copy functionality
        is also disabled for security.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_Password) != 0

    @password.setter
    def password(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_Password
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_Password

    @property
    def always_overwrite(self):
        """
        Enables overwrite mode for text input.
        
        When enabled, typing in the input field will replace existing text
        rather than inserting new characters. This mimics the behavior of
        pressing the Insert key in many text editors, where the cursor
        overwrites characters instead of pushing them forward.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_AlwaysOverwrite) != 0

    @always_overwrite.setter
    def always_overwrite(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_AlwaysOverwrite
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_AlwaysOverwrite

    @property
    def auto_select_all(self):
        """
        Automatically selects the entire text when the field is first clicked.
        
        When enabled, clicking on the input field for the first time will
        select all of its content, making it easy to replace the entire text
        with a new entry. This is particularly useful for fields that contain
        default values that users are likely to change completely.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_AutoSelectAll) != 0

    @auto_select_all.setter
    def auto_select_all(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_AutoSelectAll
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_AutoSelectAll

    @property
    def no_horizontal_scroll(self):
        """
        Prevents automatic horizontal scrolling as text is entered.
        
        When enabled, the input field will not automatically scroll horizontally
        when text exceeds the visible width. This can be useful for fields where
        you want users to be aware of the field's capacity limits visually.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_NoHorizontalScroll) != 0

    @no_horizontal_scroll.setter
    def no_horizontal_scroll(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_NoHorizontalScroll
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_NoHorizontalScroll

    @property
    def no_undo_redo(self):
        """
        Disables the undo/redo functionality for this input field.
        
        When enabled, the field will not store the history of changes,
        preventing users from using undo (Ctrl+Z) or redo (Ctrl+Y) operations.
        This can be useful for fields where undoing operations might be
        confusing or undesirable.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_NoUndoRedo) != 0

    @no_undo_redo.setter
    def no_undo_redo(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_NoUndoRedo
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_NoUndoRedo

    cdef bint draw_item(self) noexcept nogil:
        cdef DCGString current_value
        cdef int32_t size
        cdef imgui.ImGuiInputTextFlags flags = self._flags
        
        # Get current value from source if needed
        SharedStr.get(<SharedStr>self._value, current_value)
        cdef bint need_update = (<SharedStr>self._value)._last_frame_change >= self._last_frame_update 

        if need_update:
            size = min(<int>current_value.size(), self._max_characters)
            # Copy value to buffer
            memcpy(self._buffer, current_value.data(), size)
            self._buffer[size] = 0
            self._last_frame_update = (<SharedStr>self._value)._last_frame_update

        cdef bint changed = False
        if not(self._enabled):
            flags |= imgui.ImGuiInputTextFlags_ReadOnly

        cdef Vec2 requested_size = self.get_requested_size()
        if requested_size.x != 0:
            imgui.SetNextItemWidth(requested_size.x)

        if self._multiline:
            changed = imgui.InputTextMultiline(
                self._imgui_label.c_str(),
                self._buffer,
                self._max_characters+1,
                Vec2ImVec2(self.get_requested_size()),
                flags)
        elif self._hint.empty():
            changed = imgui.InputText(
                self._imgui_label.c_str(),
                self._buffer,
                self._max_characters+1,
                flags)
        else:
            changed = imgui.InputTextWithHint(
                self._imgui_label.c_str(),
                self._hint.c_str(),
                self._buffer,
                self._max_characters+1,
                flags)

        self.update_current_state()
        if changed:
            current_value = DCGString(<char*>self._buffer)
            SharedStr.set(<SharedStr>self._value, current_value)

        if not(self._enabled):
            changed = False
            self.state.cur.edited = False
            self.state.cur.deactivated_after_edited = False
            self.state.cur.active = False

        return changed

ctypedef fused clamp_types:
    int32_t
    float
    double

cdef inline void clamp1(clamp_types &value, double lower, double upper) noexcept nogil:
    if lower != -INFINITY:
        value = <clamp_types>max(<double>value, lower)
    if upper != INFINITY:
        value = <clamp_types>min(<double>value, upper)

cdef class InputValue(uiItem):
    """
    A widget for entering numeric values with optional step buttons.

    It offers precise control over value ranges, step sizes, and formatting options.

    The widget can be configured with various input restrictions, keyboard behaviors,
    and visual settings to adapt to different use cases, from simple number entry
    to multi-dimensional vector editing.
    """

    def __cinit__(self):
        self._print_format = string_from_bytes(b"%.3f")
        self._flags = 0
        self._min = -INFINITY
        self._max = INFINITY
        self._step = 0.1
        self._step_fast = 1.
        self._flags = imgui.ImGuiInputTextFlags_None
        self._value = <SharedValue>(SharedFloat.__new__(SharedFloat, self.context))
        self.state.cap.can_be_active = True # unsure
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_edited = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True

    @property
    def step(self):
        """
        Step size for incrementing/decrementing the value with buttons.
        
        When step buttons are shown, clicking them will adjust the value by
        this amount. The step value is applied according to the current format
        (int, float, double).
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._step

    @step.setter
    def step(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._step = value

    @property
    def step_fast(self):
        """
        Fast step size for quick incrementing/decrementing with modifier keys.
        
        When using keyboard or clicking step buttons with modifier keys held,
        this larger step value will be used for quicker adjustments.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._step_fast

    @step_fast.setter
    def step_fast(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._step_fast = value

    @property
    def min_value(self):
        """
        Minimum value the input will be clamped to.
        
        This defines the lower bound of the acceptable range for the input.
        Any value below this will be automatically clamped to this minimum.
        Use -INFINITY to specify no lower bound.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._min

    @min_value.setter
    def min_value(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._min = value

    @property
    def max_value(self):
        """
        Maximum value the input will be clamped to.
        
        This defines the upper bound of the acceptable range for the input.
        Any value above this will be automatically clamped to this maximum.
        Use INFINITY to specify no upper bound.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._max

    @max_value.setter
    def max_value(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._max = value

    @property
    def print_format(self):
        """
        Format string for displaying the numeric value.
        
        Uses printf-style formatting to control how the value is displayed.
        Example formats: "%.0f" for integers, "%.3f" for floats with 3 decimal
        places (default), etc.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return string_to_str(self._print_format)

    @print_format.setter
    def print_format(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._print_format = string_from_str(value)

    @property
    def decimal(self):
        """
        Restricts input to decimal numeric characters.
        
        When enabled, only characters valid for decimal numbers (0-9, +, -, .)
        will be accepted, filtering out any other input.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_CharsDecimal) != 0

    @decimal.setter
    def decimal(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_CharsDecimal
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_CharsDecimal

    @property
    def hexadecimal(self):
        """
        Restricts input to hexadecimal characters.
        
        When enabled, only characters valid for hexadecimal numbers
        (0-9, A-F, a-f) will be accepted, filtering out any other input.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_CharsHexadecimal) != 0

    @hexadecimal.setter
    def hexadecimal(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_CharsHexadecimal
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_CharsHexadecimal

    @property
    def scientific(self):
        """
        Restricts input to scientific notation characters.
        
        When enabled, only characters valid for scientific notation
        (0-9, +, -, ., *, /, e, E) will be accepted, suitable for entering
        numbers in scientific format.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_CharsScientific) != 0

    @scientific.setter
    def scientific(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_CharsScientific
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_CharsScientific

    @property
    def callback_on_enter(self):
        """
        Triggers callback when Enter key is pressed.
        
        When enabled, the widget's callback will be triggered whenever the user
        presses Enter, regardless of whether the value has changed. This is
        useful for form-like interfaces where Enter submits the current input.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_EnterReturnsTrue) != 0

    @callback_on_enter.setter
    def callback_on_enter(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_EnterReturnsTrue
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_EnterReturnsTrue

    @property
    def escape_clears_all(self):
        """
        Makes Escape key clear the field's content.
        
        When enabled, pressing the Escape key will clear all text if the field
        is not empty, or deactivate the field if it is empty. This differs from
        the default behavior where Escape reverts to the previous value.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_EscapeClearsAll) != 0

    @escape_clears_all.setter
    def escape_clears_all(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_EscapeClearsAll
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_EscapeClearsAll

    @property
    def readonly(self):
        """
        Makes the input field non-editable by the user.
        
        When enabled, the input will display its current value but users cannot
        modify it. The value can still be updated programmatically through the
        value property.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_ReadOnly) != 0

    @readonly.setter
    def readonly(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_ReadOnly
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_ReadOnly

    @property
    def password(self):
        """
        Hides the input by displaying asterisks and disables copying.
        
        When enabled, all characters will be displayed as asterisks (*), hiding
        the actual content from view. This is useful for password entry or other
        sensitive numeric information.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_Password) != 0

    @password.setter
    def password(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_Password
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_Password

    @property
    def always_overwrite(self):
        """
        Enables overwrite mode for text input.
        
        When enabled, typing in the input field will replace existing text at
        the cursor position rather than inserting new characters. This mimics
        the behavior of pressing the Insert key in many text editors.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_AlwaysOverwrite) != 0

    @always_overwrite.setter
    def always_overwrite(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_AlwaysOverwrite
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_AlwaysOverwrite

    @property
    def auto_select_all(self):
        """
        Automatically selects all content when the field is first focused.
        
        When enabled, clicking on the input field for the first time will
        select all of its content, making it easy to replace the entire value
        with a new entry.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_AutoSelectAll) != 0

    @auto_select_all.setter
    def auto_select_all(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_AutoSelectAll
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_AutoSelectAll

    @property
    def empty_as_zero(self):
        """
        Treats empty input fields as zero values.
        
        When enabled, an empty input field will be interpreted as having a value
        of zero rather than being treated as invalid input or retaining the
        previous value.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_ParseEmptyRefVal) != 0

    @empty_as_zero.setter
    def empty_as_zero(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_ParseEmptyRefVal
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_ParseEmptyRefVal

    @property
    def empty_if_zero(self):
        """
        Displays an empty field when the value is zero.
        
        When enabled, a value of exactly zero will be displayed as an empty
        field rather than showing "0". This is useful for cleaner interfaces
        where zero is the default state.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_DisplayEmptyRefVal) != 0

    @empty_if_zero.setter
    def empty_if_zero(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_DisplayEmptyRefVal
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_DisplayEmptyRefVal

    @property
    def no_horizontal_scroll(self):
        """
        Disables automatic horizontal scrolling during input.
        
        When enabled, the input field will not automatically scroll horizontally
        when text exceeds the visible width. This can be useful for fields where
        you want users to be aware of the field's capacity limits visually.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_NoHorizontalScroll) != 0

    @no_horizontal_scroll.setter
    def no_horizontal_scroll(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_NoHorizontalScroll
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_NoHorizontalScroll

    @property
    def no_undo_redo(self):
        """
        Disables the undo/redo functionality for this input field.
        
        When enabled, the field will not store the history of changes, 
        preventing users from using undo (Ctrl+Z) or redo (Ctrl+Y) operations.
        This can reduce memory usage for frequently changed values.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_NoUndoRedo) != 0

    @no_undo_redo.setter
    def no_undo_redo(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_NoUndoRedo
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_NoUndoRedo

    cdef bint draw_item(self) noexcept nogil:
        cdef imgui.ImGuiInputTextFlags flags = self._flags
        if not(self._enabled):
            flags |= imgui.ImGuiInputTextFlags_ReadOnly
        cdef imgui.ImGuiDataType type = imgui.ImGuiDataType_Double
        cdef double value_float
        cdef void *data
        cdef void *data_step = NULL
        cdef void *data_step_fast = NULL
        cdef bint modified
        cdef double fstep, fstep_fast

        fstep = <double>self._step
        fstep_fast = <double>self._step_fast
        if fstep > 0:
            data_step = &fstep
        if fstep_fast > 0:
            data_step_fast = &fstep_fast

        # Read the value
        value_float = SharedFloat.get(<SharedFloat>self._value)
        data = &value_float

        # Draw
        cdef Vec2 requested_size = self.get_requested_size()
        if requested_size.x != 0:
            imgui.SetNextItemWidth(requested_size.x)

        modified = imgui.InputScalar(self._imgui_label.c_str(),
                                     type,
                                     data,
                                     data_step,
                                     data_step_fast,
                                     self._print_format.c_str(),
                                     flags)

        # Clamp and write the value
        if self._enabled:
            if modified:
                clamp1[double](value_float, self._min, self._max)
            SharedFloat.set(<SharedFloat>self._value, value_float)
            modified = modified and (self._value._last_frame_update == self._value._last_frame_change)
        self.update_current_state()
        return modified


cdef class Text(uiItem):
    """
    A widget that displays text with customizable appearance.
    
    Text widgets provide a way to show informational text in the UI with options
    for styling, wrapping, and layout. The text, stored in a SharedStr value,
    can be updated dynamically.
    
    Text can be customized with colors, bullets, wrapping, and can be made
    selectable.
    """
    def __cinit__(self):
        self._color = 0 # invisible
        self._wrap = -1
        self._marker = <int32_t>TextMarker.NONE
        self._value = <SharedValue>(SharedStr.__new__(SharedStr, self.context))
        self.state.cap.can_be_active = True # unsure
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True

    @property
    def color(self):
        """
        Color of the text displayed by the widget.
        
        If set to 0 (default), the text uses the default color defined by the
        current theme style. Otherwise, the provided color value will be used
        to override the default text color.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return <int>self._color

    @color.setter
    def color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)

    @property
    def wrap(self):
        """
        Width in pixels at which to wrap the text.
        
        Controls text wrapping behavior with these possible values:
        -1: No wrapping (default)
         0: Wrap at the edge of the window
        >0: Wrap at the specified width in pixels
        
        The wrap width is automatically scaled by the global scale factor
        unless DPI scaling is disabled for this widget.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return <int>self._wrap

    @wrap.setter
    def wrap(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._wrap = value

    @property
    def marker(self):
        """
        Whether to display a marker point before the text.

        Accepted values are:
            - None: No marker (default)
            - "bullet" or TextMarker.BULLET: A small bullet point before the text
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return None if self._marker == <int32_t>TextMarker.NONE else make_TextMarker(self._marker)

    @marker.setter
    def marker(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._marker = <int32_t>TextMarker.NONE
        elif is_TextMarker(value):
            self._marker = <int32_t>make_TextMarker(value)
        else:
            raise TypeError(f"Expected None, TextMarker or str, got {type(value)}")

    @property
    def label(self):
        raise AttributeError("Label not available for Text")

    cdef bint draw_item(self) noexcept nogil:
        imgui.AlignTextToFramePadding()
        if self._color > 0:
            imgui.PushStyleColor(imgui.ImGuiCol_Text, self._color)
        if self._wrap == 0:
            imgui.PushTextWrapPos(0.)
        elif self._wrap > 0:
            imgui.PushTextWrapPos(imgui.GetCursorPosX() + <float>self._wrap * self.context.viewport.global_scale)
            # <float>self._wrap * (self.context.viewport.global_scale if self._dpi_scaling else 1.)) # TODO dpi scaling control
        cdef bint bullet = self._marker == <int32_t>TextMarker.BULLET
        if bullet:
            imgui.BeginGroup()
        if bullet:
            imgui.Bullet()

        cdef DCGString current_value
        SharedStr.get(<SharedStr>self._value, current_value)

        imgui.TextUnformatted(current_value.c_str(), current_value.c_str()+current_value.size())

        if self._wrap >= 0:
            imgui.PopTextWrapPos()
        if self._color > 0:
            imgui.PopStyleColor(1)

        if bullet:
            # Group enables to share the states for all items
            # And have correct rect_size
            #imgui.PushStyleVar(imgui.ImGuiStyleVar_ItemSpacing,
            #                   imgui.ImVec2(0., 0.))
            imgui.EndGroup()
            #imgui.PopStyleVar(1)

        self.update_current_state()
        return False


cdef class TextValue(uiItem):
    """
    A widget that displays values from any type of SharedValue.
    
    TextValue provides a way to visualize the current value of any SharedValue
    in the UI. Unlike the Text widget which only displays string values, TextValue
    can display values from numeric types, vectors, colors and more.
    
    By connecting a SharedValue from another widget to this one through the
    shareable_value property, you can create displays that automatically
    update when the source value changes. This is useful for creating
    readouts, labels, or debugging displays that show the current state
    of interactive elements.
    
    The display format can be customized using printf-style format strings
    to control precision, alignment, and presentation.
    """
    def __cinit__(self):
        self._print_format = string_from_bytes(b"%.3f")
        self._value = <SharedValue>(SharedFloat.__new__(SharedFloat, self.context))
        self._type = 2
        self.state.cap.can_be_active = False
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_edited = False
        self.state.cap.can_be_focused = False
        self.state.cap.can_be_hovered = True

    @property
    def shareable_value(self):
        """
        The SharedValue object that provides the displayed value.
        
        This property allows connecting any SharedValue object (except SharedStr)
        to this TextValue widget. The widget will display the current value and
        update automatically whenever the source value changes.
        
        Supported types include SharedBool, SharedFloat,
        SharedColor, and SharedFloatVect.
        
        For displaying string values, use the Text widget instead.
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
               isinstance(value, SharedFloatVect)):
            raise ValueError(f"Expected a shareable value of type SharedBool, SharedFloat, SharedColor or SharedColor. Received {type(value)}")
        if isinstance(value, SharedBool):
            self._type = 0
        elif isinstance(value, SharedFloat):
            self._type = 2
        elif isinstance(value, SharedColor):
            self._type = 4
        elif isinstance(value, SharedFloatVect):
            self._type = 8
        self._value.dec_num_attached()
        self._value = value
        self._value.inc_num_attached()

    @property
    def print_format(self):
        """
        The format string used to convert values to display text.
        
        Uses printf-style format specifiers to control how values are displayed.
        For scalar values, use a single format specifier like '%d' or '%.2f'.
        
        For SharedFloatVect, the format is applied individually to each element
        in the vector as they are displayed on separate lines.
        
        Examples:
          '%.0f' - Display integers with no decimal places
          '%.2f' - Display floats with 2 decimal places
          'Value: %g' - Add prefix text to the displayed value
          'RGB: (%.0f, %.0f, %.0f)' - Format color values as integers
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return string_to_str(self._print_format)

    @print_format.setter
    def print_format(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._print_format = string_from_str(value)

    cdef bint draw_item(self) noexcept nogil:
        cdef bool value_bool
        cdef int32_t value_int
        cdef double value_float
        cdef Vec4 value_color
        cdef int32_t[4] value_int4
        cdef double[4] value_float4
        cdef float[::1] value_vect
        cdef int32_t i
        if self._type == 0:
            value_bool = SharedBool.get(<SharedBool>self._value)
            imgui.Text(self._print_format.c_str(), value_bool)
        elif self._type == 2:
            value_float = SharedFloat.get(<SharedFloat>self._value)
            imgui.Text(self._print_format.c_str(), value_float)
        elif self._type == 4:
            value_color = SharedColor.getF4(<SharedColor>self._value)
            imgui.Text(self._print_format.c_str(), 
                       value_color.x, value_color.y, 
                       value_color.z, value_color.w)
        elif self._type == 8:
            value_vect = SharedFloatVect.get(<SharedFloatVect>self._value)
            for i in range(value_vect.shape[0]):
                imgui.Text(self._print_format.c_str(), value_vect[i])

        self.update_current_state()
        return False

cdef class Selectable(uiItem):
    """
    A selectable item that can be clicked to change its selected state.
    
    Selectable widgets provide a clickable area that can maintain a selected state,
    similar to checkboxes but with more flexible styling options. They can be 
    configured to behave in various ways when clicked or hovered, and can span
    across multiple columns in tables.
    
    Selectables are useful for creating list items, menu entries, or any UI element
    that needs to show a selected/unselected state with custom appearance. The 
    selection state is stored in a SharedBool value accessible via the value 
    property.
    """
    def __cinit__(self):
        self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_deactivated_after_edited = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_edited = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self._flags = imgui.ImGuiSelectableFlags_None

    @property
    def disable_popup_close(self):
        """
        Controls whether clicking the selectable will close parent popup windows.
        
        When enabled, clicking this selectable won't automatically close any parent
        popup window that contains it. This is useful when creating popup menus 
        where you want to allow multiple selections without the popup closing after
        each click.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiSelectableFlags_NoAutoClosePopups) != 0

    @disable_popup_close.setter
    def disable_popup_close(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiSelectableFlags_NoAutoClosePopups
        if value:
            self._flags |= imgui.ImGuiSelectableFlags_NoAutoClosePopups

    @property
    def span_columns(self):
        """
        Controls whether the selectable spans all columns in a table.
        
        When enabled in a table context, the selectable's frame will span across
        all columns of its container table, while the text content will still be
        confined to the current column. This creates a visual effect where the
        highlight/selection extends across the entire row width.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiSelectableFlags_SpanAllColumns) != 0

    @span_columns.setter
    def span_columns(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiSelectableFlags_SpanAllColumns
        if value:
            self._flags |= imgui.ImGuiSelectableFlags_SpanAllColumns

    @property
    def callback_on_double_click(self):
        """
        Controls whether the selectable responds to double-clicks.
        
        When enabled, the selectable will also generate callbacks when double-clicked,
        not just on single clicks. This is useful for items where double-clicking
        might trigger a secondary action, such as opening a detailed view or 
        entering an edit mode.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiSelectableFlags_AllowDoubleClick) != 0

    @callback_on_double_click.setter
    def callback_on_double_click(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiSelectableFlags_AllowDoubleClick
        if value:
            self._flags |= imgui.ImGuiSelectableFlags_AllowDoubleClick

    @property
    def highlighted(self):
        """
        Controls whether the selectable appears highlighted regardless of hover state.
        
        When enabled, the selectable will always draw with a highlighted appearance
        as if it were being hovered by the mouse, regardless of the actual hover
        state. This can be useful for drawing attention to a specific item in a
        list or indicating a special status.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiSelectableFlags_Highlight) != 0

    @highlighted.setter
    def highlighted(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiSelectableFlags_Highlight
        if value:
            self._flags |= imgui.ImGuiSelectableFlags_Highlight

    cdef bint draw_item(self) noexcept nogil:
        cdef imgui.ImGuiSelectableFlags flags = self._flags
        if not(self._enabled):
            flags |= imgui.ImGuiSelectableFlags_Disabled

        cdef bool checked = SharedBool.get(<SharedBool>self._value)
        cdef bint changed = imgui.Selectable(self._imgui_label.c_str(),
                                             &checked,
                                             flags,
                                             Vec2ImVec2(self.get_requested_size()))
        if self._enabled:
            SharedBool.set(<SharedBool>self._value, checked)
        self.update_current_state()
        return changed


cdef class MenuItem(uiItem):
    """
    A clickable menu item that can be used inside Menu components.
    
    MenuItem represents a clickable option in a dropdown menu or context menu.
    It can be configured to display a checkmark and keyboard shortcut hint,
    making it suitable for commands and toggleable options.
    
    Menu items can be checked/unchecked to represent binary states, and can
    display shortcut text to inform users of keyboard alternatives. When clicked,
    menu items trigger their callback function and update their associated
    SharedBool value.
    """
    def __cinit__(self):
        self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_deactivated_after_edited = True
        self.state.cap.can_be_edited = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self._check = False

    @property
    def check(self):
        """
        Whether the menu item displays a checkmark.
        
        When enabled, the menu item shows a checkmark that reflects the state
        of the associated value. This is useful for options that can be toggled
        on and off. The checkmark state is controlled through the item's value
        property.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._check

    @check.setter
    def check(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._check = value

    @property
    def shortcut(self):
        """
        Text displayed on the right side of the menu item as a shortcut hint.
        
        This text provides a visual indicator of keyboard shortcuts associated
        with this menu command. The shortcut is not functional by itself - it
        only displays text to inform the user. Actual keyboard shortcut handling
        must be implemented separately.
        
        Common formats include "Ctrl+S" or "Alt+F4".
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return string_to_str(self._shortcut)

    @shortcut.setter
    def shortcut(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._shortcut = string_from_str(value)

    cdef bint draw_item(self) noexcept nogil:
        # TODO dpg does overwrite textdisabled...
        cdef bool current_value = SharedBool.get(<SharedBool>self._value)
        cdef bint activated = imgui.MenuItem(self._imgui_label.c_str(),
                                             self._shortcut.c_str(),
                                             &current_value if self._check else NULL,
                                             self._enabled)
        self.update_current_state()
        SharedBool.set(<SharedBool>self._value, current_value)
        return activated

cdef class ProgressBar(uiItem):
    """
    A widget that displays a visual indicator of progress.
    
    The ProgressBar shows a filled rectangle that grows from left to right
    proportionally to the current value (0.0 to 1.0). It's useful for showing
    the status of ongoing operations, loading processes, or completion percentages.
    
    The appearance can be customized through themes, and optional text can be 
    displayed on top of the progress indicator using the overlay property. The
    widget can also be sized explicitly through the width and height properties
    inherited from uiItem.
    """
    def __cinit__(self):
        self._value = <SharedValue>(SharedFloat.__new__(SharedFloat, self.context))
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True

    @property
    def overlay(self):
        """
        Optional text to display centered in the progress bar.
        
        This text is displayed in the center of the progress bar and can be used
        to show textual information about the progress, such as percentages or
        status messages. Leave empty for no text overlay.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return string_to_str(self._overlay)

    @overlay.setter
    def overlay(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._overlay = string_from_str(value)

    cdef bint draw_item(self) noexcept nogil:
        cdef float current_value = SharedFloat.get(<SharedFloat>self._value)
        cdef const char *overlay_text = self._overlay.c_str()
        imgui.PushID(self.uuid)
        imgui.ProgressBar(current_value,
                          Vec2ImVec2(self.get_requested_size()),
                          <const char *>NULL if self._overlay.size() == 0 else overlay_text)
        imgui.PopID()
        self.update_current_state()
        return False

cdef class Image(uiItem):
    """
    A widget that displays a texture image in the UI.
    
    Image widgets allow displaying textures with options for resizing, tinting,
    and UV coordinate mapping. They can be used to show static images, icons,
    or dynamic content from render targets.
    
    The image's appearance can be customized through colors and UV coordinates
    to display specific regions of a texture. The size can be explicitly set or
    derived automatically from the texture dimensions with optional DPI scaling.
    
    The widget supports hover detection and can be used with callbacks to create
    interactive image elements without button behavior. When setting the
    button attribute, the widget integrates full button functionality and visual.
    In which case value is a SharedBool that indicates whether the button is pressed.

    Image borders: this widget is affected by the theme elements related to border:
    FrameBorderSize (style), Border (color). In addition when a button, is also
    affected by FramePadding (style) and FrameRounding (style).
    """
    def __cinit__(self):
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self._uv = [0., 0., 1., 1.]
        self._background_color = 0
        self._color_multiplier = 4294967295
        self._button = False

    @property
    def texture(self):
        """
        The texture to display in the image widget.
        
        This must be a Texture object that has been loaded or created. The image
        will update automatically if the texture content changes. If no texture
        is set or the texture is invalid, the image will not be rendered.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._texture

    @texture.setter
    def texture(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if not(isinstance(value, Texture)):
            raise TypeError("texture must be a Texture")
        self._texture = value

    @property
    def uv(self):
        """
        UV coordinates defining the region of the texture to display.
        
        A list of 4 values [u1, v1, u2, v2] that specify the texture coordinates
        to use for mapping the texture onto the image rectangle. This allows
        displaying only a portion of the texture. 
        
        Default is [0.0, 0.0, 1.0, 1.0], which displays the entire texture.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._uv)

    @uv.setter
    def uv(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        read_vec4[float](self._uv, value)

    @property
    def color_multiplier(self):
        """
        Color tint applied to the image texture.
        
        A color value used to multiply with the texture's colors, allowing 
        tinting, fading, or other color adjustments. The color can be specified
        as an RGBA list with values from 0.0 to 1.0, or as a packed integer.
        
        Default is white [1., 1., 1., 1.], which displays the texture with its
        original colors.
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
    def background_color(self):
        """
        Color of the background drawn behind the image.
        
        A color value for the image's background. The color can be specified as an
        RGBA list with values from 0.0 to 1.0, or as a packed integer. Setting
        this to a transparent color (alpha=0) effectively hides the background.
        
        Default is transparent black [0, 0, 0, 0], which displays no background.

        Setting this attribute will have no effect if the image is opaque.
        The background color is not affected by the theme.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] background_color
        unparse_color(background_color, self._background_color)
        return list(background_color)

    @background_color.setter
    def background_color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._background_color = parse_color(value)

    @property
    def button(self):
        """
        Whether the image behaves as a button.
        
        When enabled, the image acts like a button and can be clicked to trigger
        actions. The value property is used to indicate whether the button is
        currently pressed or not. If set to False, the image behaves as a static
        image without button functionality.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button

    @button.setter
    def button(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._button = value

    @property
    def no_global_scaling(self):
        """
        Disables the global dpi scale.

        When the size of this widget is not specified, it defaults
        to the texture size.

        When enabled this state is enabled, the texture size will
        not be scaled by the global dpi scaling factor.
        That is, one pixel of the texture will match exactly to
        one pixel on the screen, rather than to one scaled pixel (scaled
        to be dpi invariant).
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._no_global_scale

    @no_global_scaling.setter
    def no_global_scaling(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._no_global_scale = value

    cdef bint draw_item(self) noexcept nogil:
        cdef Vec2 size = self.get_requested_size()
        if self._texture is None:
            if size.x > 0 and size.y > 0:
                imgui.Dummy(Vec2ImVec2(size))
            return False
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self._texture.mutex)
        if self._texture.allocated_texture == NULL:
            if size.x > 0 and size.y > 0:
                imgui.Dummy(Vec2ImVec2(size))
            return False

        if size.x == 0.:
            size.x = self._texture.width * (1. if self._no_global_scale else self.context.viewport.global_scale)
        if size.y == 0.:
            size.y = self._texture.height * (1. if self._no_global_scale else self.context.viewport.global_scale)

        cdef bint activated
        imgui.PushID(self.uuid)
        if self._button:
            activated = imgui.ImageButton(self._imgui_label.c_str(),
                                          <imgui.ImTextureID>self._texture.allocated_texture,
                                          Vec2ImVec2(size),
                                          imgui.ImVec2(self._uv[0], self._uv[1]),
                                          imgui.ImVec2(self._uv[2], self._uv[3]),
                                          imgui.ColorConvertU32ToFloat4(self._background_color),
                                          imgui.ColorConvertU32ToFloat4(self._color_multiplier))
        else:
            imgui.PushStyleVar(imgui.ImGuiStyleVar_ImageBorderSize, imgui.GetStyle().FrameBorderSize)
            imgui.ImageWithBg(<imgui.ImTextureID>self._texture.allocated_texture,
                        Vec2ImVec2(size),
                        imgui.ImVec2(self._uv[0], self._uv[1]),
                        imgui.ImVec2(self._uv[2], self._uv[3]),
                        imgui.ColorConvertU32ToFloat4(self._background_color),
                        imgui.ColorConvertU32ToFloat4(self._color_multiplier))
            imgui.PopStyleVar(1)
            activated = False
        imgui.PopID()
        self.update_current_state()
        return activated


cdef class Separator(uiItem):
    """
    A horizontal line that visually separates UI elements.
    
    Separator creates a horizontal dividing line that spans the width of its 
    parent container. It helps organize UI components by creating visual 
    boundaries between different groups of elements.
    
    When a label is provided, the separator will display text centered on the line,
    creating a section header. Without a label, it renders as a simple line.
    """
    def __cinit__(self):
        return

    @property
    def label(self):
        """
        Text to display centered on the separator line.
        
        When set, creates a labeled separator that displays text centered on the
        horizontal line. This is useful for creating titled sections within a UI.
        If not set or None, renders as a plain horizontal line.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._user_label

    @label.setter
    def label(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._user_label = ""
        else:
            self._user_label = value
        # uuid is not used for text, and we don't want to
        # add it when we show the label, thus why we override
        # the label property here.
        self._imgui_label = string_from_str(self._user_label)

    cdef bint draw_item(self) noexcept nogil:
        if self._user_label is None:
            imgui.Separator()
        else:
            imgui.SeparatorText(self._imgui_label.c_str())
        self.state.cur.rect_size = ImVec2Vec2(imgui.GetItemRectSize())
        return False

cdef class Spacer(uiItem):
    """
    A blank area that creates space between UI elements.
    
    Spacer adds empty vertical or horizontal space between UI components to 
    improve layout and visual separation. It can be configured with explicit 
    dimensions or use the default spacing from the current style.
    
    Without specified dimensions, Spacer creates a standard-sized gap using the
    current style's ItemSpacing value. With dimensions, it creates an empty area
    of the precise requested size.
    """
    def __cinit__(self):
        self.can_be_disabled = False

    cdef bint draw_item(self) noexcept nogil:
        cdef Vec2 requested_size = self.get_requested_size()
        if requested_size.x == 0 and \
           requested_size.y == 0:
            imgui.Spacing()
            # TODO rect_size
        else:
            imgui.Dummy(Vec2ImVec2(requested_size))
        self.state.cur.rect_size = ImVec2Vec2(imgui.GetItemRectSize())
        return False

cdef class MenuBar(uiItem):
    """
    A horizontal container for menu items at the top of a window.
    
    MenuBar creates a horizontal area at the top of a window where menu items and
    other interactive controls can be placed. It can function as either a main
    menu bar (attached to the application window) or as a child menu bar within
    another window.
    
    MenuBars can contain Menu widgets, which in turn can contain MenuItem widgets
    to create dropdown menus. They automatically adapt to different window sizes
    and can be styled using themes.
    
    When placed directly under the viewport, the MenuBar becomes a main menu bar
    that appears at the top of the application window. When placed within another
    window, it creates a local menu bar for that window.
    """
    def __cinit__(self):
        # We should maybe restrict to menuitem ?
        self.can_have_widget_child = True
        self.element_child_category = child_type.cat_menubar
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self.state.cap.has_content_region = True
        #self.state.cap.has_rect_size = False -> Unsure about current advertised size

    cdef void draw(self) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)

        if not(self._show):
            if self._show_update_requested:
                self.set_previous_states()
                self.set_hidden_no_handler_and_propagate_to_children_with_handlers()
                self.run_handlers()
                self._show_update_requested = False
            return

        cdef float original_scale = self.context.viewport.global_scale
        self.context.viewport.global_scale = original_scale * self._scaling_factor

        self.set_previous_states()
        # handle fonts
        if self._font is not None:
            self._font.push()

        # themes
        if self._theme is not None:
            self._theme.push()

        cdef bint enabled = self._enabled
        if not(enabled):
            imgui.PushItemFlag(1 << 10, True) #ImGuiItemFlags_Disabled

        cdef bint menu_allowed
        cdef bint parent_viewport = self.parent is self.context.viewport
        if parent_viewport:
            menu_allowed = imgui.BeginMainMenuBar()
        else:
            menu_allowed = imgui.BeginMenuBar()
        cdef Vec2 pos_w, pos_p, parent_size_backup
        if menu_allowed:
            self.update_current_state()
            self.state.cur.content_region_size = ImVec2Vec2(imgui.GetContentRegionAvail())
            # Only one row is reserved for menubar, while the content region avail sees the whole window.
            self.state.cur.content_region_size.y = imgui.GetFrameHeight()
            # TODO: compute real size. At least this is not what update_current_state
            # seems to fill (it is significantly too large)
            self.state.cur.rect_size.x = self.state.cur.content_region_size.x
            self.state.cur.rect_size.y = self.state.cur.content_region_size.y
            if self.last_widgets_child is not None:
                # We are at the top of the window, but behave as if popup
                pos_w = ImVec2Vec2(imgui.GetCursorScreenPos())
                pos_p = pos_w
                swap_Vec2(pos_w, self.context.viewport.window_pos)
                swap_Vec2(pos_p, self.context.viewport.parent_pos)
                parent_size_backup = self.context.viewport.parent_size
                self.context.viewport.parent_size = self.state.cur.content_region_size
                draw_ui_children(self)
                self.context.viewport.window_pos = pos_w
                self.context.viewport.parent_pos = pos_p
                self.context.viewport.parent_size = parent_size_backup
            if parent_viewport:
                imgui.EndMainMenuBar()
            else:
                imgui.EndMenuBar()
        else:
            # We should hit this only if window is invisible
            # or has no menu bar
            self.set_hidden_no_handler_and_propagate_to_children_with_handlers()
        cdef bint activated = self.state.cur.active and not(self.state.prev.active)
        cdef int32_t i
        if activated and not(self._callbacks.empty()):
            for i in range(<int>self._callbacks.size()):
                self.context.queue_callback_arg1value(<Callback>self._callbacks[i], self, self, self._value)

        if not(enabled):
            imgui.PopItemFlag()

        if self._theme is not None:
            self._theme.pop()

        if self._font is not None:
            self._font.pop()

        # Restore original scale
        self.context.viewport.global_scale = original_scale 

        self.run_handlers()


cdef class Menu(uiItem):
    """A Menu creates a menu container within a menu bar.

    Menus are used to organize menu items and sub-menus within a menu bar. They
    provide a hierarchical structure for your application's command system. Each
    menu can contain multiple menu items or other menus.

    Menus must be created within a MenuBar or as a child of another Menu.
    """
    # TODO: MUST be inside a menubar
    def __cinit__(self):
        # We should maybe restrict to menuitem ?
        self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.can_have_widget_child = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_active = True
        self.state.cap.has_rect_size = True
        self.state.cap.can_be_toggled = True

    cdef bint draw_item(self) noexcept nogil:
        cdef bint menu_open = imgui.BeginMenu(self._imgui_label.c_str(),
                                              self._enabled)
        self.update_current_state()
        cdef Vec2 pos_w, pos_p, parent_size_backup
        if menu_open:
            self.state.cur.hovered = imgui.IsWindowHovered(imgui.ImGuiHoveredFlags_None)
            self.state.cur.focused = imgui.IsWindowFocused(imgui.ImGuiFocusedFlags_None)
            self.state.cur.rect_size.x = imgui.GetWindowWidth()
            self.state.cur.rect_size.y = imgui.GetWindowHeight()
            if self.last_widgets_child is not None:
                # We are in a separate window
                pos_w = ImVec2Vec2(imgui.GetCursorScreenPos())
                pos_p = pos_w
                swap_Vec2(pos_w, self.context.viewport.window_pos)
                swap_Vec2(pos_p, self.context.viewport.parent_pos)
                parent_size_backup = self.context.viewport.parent_size
                self.context.viewport.parent_size = self.state.cur.rect_size # TODO: probably incorrect
                draw_ui_children(self)
                self.context.viewport.window_pos = pos_w
                self.context.viewport.parent_pos = pos_p
                self.context.viewport.parent_size = parent_size_backup
            imgui.EndMenu()
        else:
            self.propagate_hidden_state_to_children_with_handlers()
        self.state.cur.open = menu_open
        SharedBool.set(<SharedBool>self._value, menu_open)
        return self.state.cur.active and not(self.state.prev.active)

cdef class Tooltip(uiItem):
    """
    A floating popup that displays additional information when hovering an item.
    
    Tooltips appear when the user hovers over a target element, providing 
    contextual help or additional details without requiring interaction. They 
    automatically position themselves near the target and can be configured to 
    appear after a delay or respond to specific conditions.
    
    Tooltips can contain any UI elements as children, allowing for rich content 
    including text, images, and interactive widgets. They automatically size to 
    fit their content and disappear when the user moves away from the target.
    
    The tooltip's appearance can be controlled through themes, and its behavior 
    can be customized with properties like delay time and activity-based hiding.
    """
    def __cinit__(self):
        self.can_have_widget_child = True
        # Tooltip is basically a window but with no control
        # on anything. Cannot be hovered, and thus clicked,
        # dragged, focused, etc.
        # self.state.cap.can_be_toggled = True -> rendered
        # no rect size and position as uiItem because the popup
        # is outside the window
        self.state.cap.has_position = False
        self.state.cap.has_rect_size = False
        # It has a content region, but it is hard to define it
        # as all tooltips append to the same window.
        self.state.cap.has_content_region = True
        self._delay = 0.
        self._hide_on_activity = False
        self._target = None


    @property
    def target(self):
        """
        The UI item that triggers this tooltip when hovered.
        
        When set, the tooltip will appear when this target item is hovered by 
        the mouse. If no target is set, the tooltip will use the previous 
        sibling in the UI hierarchy as its target.
        
        Note that if the target item appears after this tooltip in the rendering 
        tree, there will be a one-frame delay before the tooltip responds to the 
        target's hover state.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._target

    @target.setter
    def target(self, baseItem target):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._target = None
        if target is None:
            return
        if self._secondary_handler is not None:
            self._secondary_handler.check_bind(target)
        # We do not raise a warning to allow to bind
        # the target before the handler
        #elif target.p_state == NULL or not(target.p_state.cap.can_be_hovered):
        #    raise TypeError(f"Unsupported target instance {target}")
        self._target = target

    @property
    def condition_from_handler(self):
        """
        A handler that determines when the tooltip should be displayed.
        
        When set, this handler replaces the default hover detection logic for 
        determining when to show the tooltip. The handler is applied to the 
        target item (which must be set) and can implement custom conditions 
        beyond simple hovering.
        
        This allows for advanced tooltip behaviors such as showing tooltips 
        based on item state, user interactions, or application logic rather 
        than just mouse position.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._secondary_handler

    @condition_from_handler.setter
    def condition_from_handler(self, baseHandler handler):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self._target is not None and handler is not None:
            handler.check_bind(self._target)
        self._secondary_handler = handler

    @property
    def delay(self):
        """
        Time in seconds to wait before showing the tooltip.
        
        Controls how long the mouse must remain stationary over the target 
        before the tooltip appears. This prevents tooltips from flickering 
        when the user moves the mouse across the interface.
        
        Values:
        - Positive: Number of seconds to wait
        - 0: Show immediately (default)
        - -1: Use ImGui default delay from the current style
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._delay

    @delay.setter
    def delay(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._delay = value

    @property
    def hide_on_activity(self):
        """
        Whether to hide the tooltip when the mouse moves.
        
        When enabled, any mouse movement will immediately hide the tooltip, 
        even if the mouse remains over the target item. This creates a more 
        responsive interface where tooltips only appear when the user explicitly 
        pauses on an item.
        
        This can be useful for tooltips that might obscure important UI elements 
        or for interfaces where the user is expected to perform quick actions.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._hide_on_activity

    @hide_on_activity.setter
    def hide_on_activity(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._hide_on_activity = value

    cdef bint draw_item(self) noexcept nogil: # TODO: maybe subclass draw() instead ?
        cdef float hoverDelay_backup
        cdef bint display_condition = False
        cdef float delay = self._delay
        if self._secondary_handler is None:
            if self._target is None:
                if self._delay >= 0:
                    display_condition = imgui.IsItemHovered(imgui.ImGuiHoveredFlags_None)
                else:
                    display_condition = imgui.IsItemHovered(imgui.ImGuiHoveredFlags_ForTooltip)
                    delay = 0 # to skip handling it later
            elif self._target.p_state != NULL:
                display_condition = self._target.p_state.cur.hovered
        elif self._target is not None:
            display_condition = self._secondary_handler.check_state(self._target)

        if self._hide_on_activity and \
           (imgui.GetIO().MouseDelta.x != 0. or \
            imgui.GetIO().MouseDelta.y != 0.):
            display_condition = False

        cdef float current_time, remaining_delay
        if display_condition and delay != 0:
            if delay < 0:
                delay = imgui.GetStyle().HoverStationaryDelay
            if not(self.state.prev.rendered) and \
               imgui.GetCurrentContext().MouseStationaryTimer < delay:
                display_condition = False # not yet time to show
                current_time = (<double>monotonic_ns())*1e-9
                remaining_delay = delay - imgui.GetCurrentContext().MouseStationaryTimer
                self.context.viewport.ask_refresh_after(
                    current_time + remaining_delay
                )

        cdef bint was_visible = self.state.cur.rendered
        cdef Vec2 pos_w, pos_p, parent_size_backup
        cdef Vec2 content_min, content_max
        if display_condition and imgui.BeginTooltip():
            #self.state.cur.pos_to_viewport = ImVec2Vec2(imgui.GetWindowPos())
            #self.state.cur.pos_to_window.x = 0.
            #self.state.cur.pos_to_window.y = 0.
            #self.state.cur.pos_to_parent.x = 0.
            #self.state.cur.pos_to_parent.y = 0.
            #self.state.cur.rect_size = ImVec2Vec2(imgui.GetWindowSize()) # Note: breaks layouts
            # Supported field
            self.state.cur.content_region_size = ImVec2Vec2(imgui.GetContentRegionAvail())
            if self.last_widgets_child is not None:
                # We are in a popup window
                pos_w = ImVec2Vec2(imgui.GetCursorScreenPos())
                pos_p = pos_w
                self.state.cur.content_pos = pos_w
                swap_Vec2(pos_w, self.context.viewport.window_pos)
                swap_Vec2(pos_p, self.context.viewport.parent_pos)
                parent_size_backup = self.context.viewport.parent_size
                self.context.viewport.parent_size = self.state.cur.content_region_size
                draw_ui_children(self)
                self.context.viewport.window_pos = pos_w
                self.context.viewport.parent_pos = pos_p
                self.context.viewport.parent_size = parent_size_backup

            imgui.EndTooltip() 
            self.state.cur.rendered = True
        else:
            self.set_hidden_no_handler_and_propagate_to_children_with_handlers()
            # NOTE: we could also set the rects. DPG does it.
        # The sizing of a tooltip takes a few frames to converge
        if self.state.cur.rendered != was_visible or \
           self.state.cur.content_region_size.x != self.state.prev.content_region_size.x or \
           self.state.cur.content_region_size.y != self.state.prev.content_region_size.y:
            self.context.viewport.redraw_needed = True
        return self.state.cur.rendered and not(was_visible)

cdef class TabButton(uiItem):
    """
    A button that appears within a tab bar without tab content.
    
    TabButton provides a clickable element that looks like a tab but doesn't 
    have an associated panel. This is useful for creating actions within a 
    tab bar, such as a "+" button to add new tabs or other special controls.
    
    Unlike regular Tab elements, TabButtons don't maintain a content area or 
    open/closed state. They simply trigger their callbacks when clicked, making
    them ideal for implementing custom tab bar behaviors.
    
    TabButtons can be positioned at specific locations in the tab bar using
    the leading or trailing properties, and their appearance can be customized
    using themes.
    """
    def __cinit__(self):
        self.element_child_category = child_type.cat_tab
        self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_deactivated_after_edited = True
        self.state.cap.can_be_edited = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self._flags = imgui.ImGuiTabItemFlags_None

    @property
    def no_reorder(self):
        """
        Prevents this tab button from being reordered or crossed over.
        
        When enabled, this tab button cannot be dragged to a new position, and 
        other tabs cannot be dragged across it. This is useful for pinning 
        special function tabs in a fixed position within the tab bar.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabItemFlags_NoReorder) != 0

    @no_reorder.setter
    def no_reorder(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabItemFlags_NoReorder
        if value:
            self._flags |= imgui.ImGuiTabItemFlags_NoReorder

    @property
    def leading(self):
        """
        Positions the tab button at the left side of the tab bar.
        
        When enabled, the tab button will be positioned at the beginning of the 
        tab bar, after the tab list popup button (if present). This is useful 
        for creating primary action buttons that should appear before regular
        tabs. Setting this property will automatically disable the trailing
        property if it was enabled.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabItemFlags_Leading) != 0

    @leading.setter
    def leading(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabItemFlags_Leading
        if value:
            self._flags &= ~imgui.ImGuiTabItemFlags_Trailing
            self._flags |= imgui.ImGuiTabItemFlags_Leading

    @property
    def trailing(self):
        """
        Positions the tab button at the right side of the tab bar.
        
        When enabled, the tab button will be positioned at the end of the tab
        bar, before the scrolling buttons (if present). This is useful for
        creating secondary action buttons that should appear after regular tabs.
        Setting this property will automatically disable the leading property
        if it was enabled.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabItemFlags_Trailing) != 0

    @trailing.setter
    def trailing(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabItemFlags_Trailing
        if value:
            self._flags &= ~imgui.ImGuiTabItemFlags_Leading
            self._flags |= imgui.ImGuiTabItemFlags_Trailing

    @property
    def no_tooltip(self):
        """
        Disables the tooltip that would appear when hovering over the tab button.
        
        When enabled, no tooltip will be displayed when the mouse hovers over
        the tab button, even if a tooltip is associated with it. This can be
        useful for tab buttons that have self-explanatory icons or text labels
        that don't require additional explanation.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabItemFlags_NoTooltip) != 0

    @no_tooltip.setter
    def no_tooltip(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabItemFlags_NoTooltip
        if value:
            self._flags |= imgui.ImGuiTabItemFlags_NoTooltip

    cdef bint draw_item(self) noexcept nogil:
        cdef bint pressed = imgui.TabItemButton(self._imgui_label.c_str(),
                                                self._flags)
        self.update_current_state()
        #SharedBool.set(<SharedBool>self._value, self.state.cur.active) # Unsure. Not in original
        return pressed


cdef class Tab(uiItem):
    """
    A content container that appears as a clickable tab within a TabBar.
    
    Tabs create labeled sections within a TabBar, allowing users to switch between 
    different content panels by clicking on tab headers. When a tab is selected, 
    its contents are displayed below the tab bar while other tab contents are 
    hidden.
    
    Tabs can contain any UI element as children and support various customization 
    options including positioning (leading/trailing), reordering restrictions, and 
    optional close buttons. They work in conjunction with the TabBar container, 
    which manages the overall tab display and interaction.
    
    The tab's state is stored in a SharedBool value that tracks whether it's 
    currently selected/open. This allows programmatic control of tab switching in 
    addition to user interaction.
    """
    def __cinit__(self):
        self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.can_have_widget_child = True
        self.element_child_category = child_type.cat_tab
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_active = True
        self.state.cap.can_be_toggled = True
        self.state.cap.has_rect_size = True
        self._closable = False
        self._flags = imgui.ImGuiTabItemFlags_None

    @property
    def closable(self):
        """
        Whether the tab displays a close button.
        
        When enabled, a small 'x' button appears on the tab that allows users to 
        close the tab by clicking it. When a tab is closed this way, the tab's 
        'show' property is set to False, which can be detected through handlers 
        or callbacks. Closed tabs are not destroyed, just hidden.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._closable 

    @closable.setter
    def closable(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._closable = value

    @property
    def no_reorder(self):
        """
        Whether tab reordering is disabled for this tab.
        
        When enabled, this tab cannot be dragged to a new position in the tab bar,
        and other tabs cannot be dragged across it. This is useful for pinning 
        important tabs in a fixed position or creating sections of fixed and 
        movable tabs within the same tab bar.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabItemFlags_NoReorder) != 0

    @no_reorder.setter
    def no_reorder(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabItemFlags_NoReorder
        if value:
            self._flags |= imgui.ImGuiTabItemFlags_NoReorder

    @property
    def leading(self):
        """
        Whether the tab is positioned at the left side of the tab bar.
        
        When enabled, the tab will be positioned at the beginning of the tab bar, 
        after the tab list popup button (if present). This is useful for creating 
        primary or frequently used tabs that should always be visible. Setting 
        this property will automatically disable the trailing property if it was 
        enabled.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabItemFlags_Leading) != 0

    @leading.setter
    def leading(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabItemFlags_Leading
        if value:
            self._flags &= ~imgui.ImGuiTabItemFlags_Trailing
            self._flags |= imgui.ImGuiTabItemFlags_Leading

    @property
    def trailing(self):
        """
        Whether the tab is positioned at the right side of the tab bar.
        
        When enabled, the tab will be positioned at the end of the tab bar, 
        before the scrolling buttons (if present). This is useful for creating 
        secondary or less frequently used tabs that should be separated from the 
        main tabs. Setting this property will automatically disable the leading 
        property if it was enabled.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabItemFlags_Trailing) != 0

    @trailing.setter
    def trailing(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabItemFlags_Trailing
        if value:
            self._flags &= ~imgui.ImGuiTabItemFlags_Leading
            self._flags |= imgui.ImGuiTabItemFlags_Trailing

    @property
    def no_tooltip(self):
        """
        Whether tooltips are disabled for this tab.
        
        When enabled, no tooltip will be displayed when hovering over this tab, 
        even if a tooltip is associated with it. This can be useful for tabs with 
        self-explanatory labels that don't require additional explanation, or when 
        you want to selectively enable tooltips for only certain tabs.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabItemFlags_NoTooltip) != 0

    @no_tooltip.setter
    def no_tooltip(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabItemFlags_NoTooltip
        if value:
            self._flags |= imgui.ImGuiTabItemFlags_NoTooltip

    cdef bint draw_item(self) noexcept nogil:
        cdef imgui.ImGuiTabItemFlags flags = self._flags
        if (<SharedBool>self._value)._last_frame_change == self.context.viewport.frame_count:
            # The value was changed after the last time we drew
            # TODO: will have no effect if we switch from show to no show.
            # maybe have a counter here.
            if SharedBool.get(<SharedBool>self._value):
                flags |= imgui.ImGuiTabItemFlags_SetSelected
        cdef bint menu_open = imgui.BeginTabItem(self._imgui_label.c_str(),
                                                 &self._show if self._closable else NULL,
                                                 flags)
        if not(self._show):
            self._show_update_requested = True
        self.update_current_state()
        cdef Vec2 pos_p, parent_size_backup
        cdef float dx, dy
        if menu_open:
            if self.last_widgets_child is not None:
                pos_p = ImVec2Vec2(imgui.GetCursorScreenPos())
                dx = pos_p.x - self.context.viewport.parent_pos.x
                dy = pos_p.y - self.context.viewport.parent_pos.y
                swap_Vec2(pos_p, self.context.viewport.parent_pos)
                parent_size_backup = self.context.viewport.parent_size
                # TODO: is there a frame border on the right to subtract ?
                
                self.context.viewport.parent_size.x = parent_size_backup.x - dx
                self.context.viewport.parent_size.y = parent_size_backup.y - dy
                draw_ui_children(self)
                self.context.viewport.parent_pos = pos_p
                self.context.viewport.parent_size = parent_size_backup
            imgui.EndTabItem()
        else:
            self.propagate_hidden_state_to_children_with_handlers()
        self.state.cur.open = menu_open
        SharedBool.set(<SharedBool>self._value, menu_open)
        return self.state.cur.active and not(self.state.prev.active)


cdef class TabBar(uiItem):
    """
    A container for Tab and TabButton elements that creates a tabbed interface.
    
    TabBar provides a horizontal row of clickable tabs that can be used to switch
    between different content panels. Each tab corresponds to a Tab widget child
    that contains its own content.
    
    The tab bar supports various interactive behaviors including tab reordering,
    scrolling, and automatic selection. It can also be styled using themes to
    match the overall look of your application.
    
    Tab elements within the TabBar can contain any UI components, allowing complex
    layouts to be organized into a compact, user-friendly interface. Only the
    content of the currently selected tab is visible, while other tab contents are
    hidden until selected.
    """
    def __cinit__(self):
        #self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.can_have_tab_child = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_active = True
        self.state.cap.has_rect_size = True
        self._flags = imgui.ImGuiTabBarFlags_None

    @property
    def reorderable(self):
        """
        Whether tabs can be manually dragged to reorder them.
        
        When enabled, users can click and drag tabs to reposition them within 
        the tab bar. New tabs will be appended at the end of the list by default. 
        This provides a flexible interface where users can organize tabs according 
        to their preferences.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabBarFlags_Reorderable) != 0

    @reorderable.setter
    def reorderable(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabBarFlags_Reorderable
        if value:
            self._flags |= imgui.ImGuiTabBarFlags_Reorderable

    @property
    def autoselect_new_tabs(self):
        """
        Whether newly created tabs are automatically selected.
        
        When enabled, any new tab added to the tab bar will be automatically 
        selected and displayed. This is useful for workflows where a new tab 
        should immediately receive focus, such as when creating a new document 
        or opening a new view that requires immediate attention.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabBarFlags_AutoSelectNewTabs) != 0

    @autoselect_new_tabs.setter
    def autoselect_new_tabs(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabBarFlags_AutoSelectNewTabs
        if value:
            self._flags |= imgui.ImGuiTabBarFlags_AutoSelectNewTabs

    @property
    def no_tab_list_popup_button(self):
        """
        Whether the popup button for the tab list is disabled.
        
        When enabled, the button that would normally appear at the right side of 
        the tab bar for accessing a dropdown list of all tabs is hidden. This can 
        be useful for simpler interfaces or when you want to ensure users navigate 
        only through the visible tabs.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabBarFlags_TabListPopupButton) != 0

    @no_tab_list_popup_button.setter
    def no_tab_list_popup_button(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabBarFlags_TabListPopupButton
        if value:
            self._flags |= imgui.ImGuiTabBarFlags_TabListPopupButton

    @property
    def no_close_with_middle_mouse_button(self):
        """
        Whether closing tabs with middle mouse button is disabled.
        
        When enabled, the default behavior of closing closable tabs by clicking 
        them with the middle mouse button is disabled. This can be useful to 
        prevent accidental closure of tabs or to enforce a specific pattern for 
        closing tabs through explicit close buttons.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabBarFlags_NoCloseWithMiddleMouseButton) != 0

    @no_close_with_middle_mouse_button.setter
    def no_close_with_middle_mouse_button(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabBarFlags_NoCloseWithMiddleMouseButton
        if value:
            self._flags |= imgui.ImGuiTabBarFlags_NoCloseWithMiddleMouseButton

    @property
    def no_scrolling_button(self):
        """
        Whether scrolling buttons are hidden when tabs exceed the visible area.
        
        When enabled, the arrow buttons that would normally appear when there are 
        more tabs than can fit in the visible tab bar area are hidden. This forces 
        users to rely on alternative navigation methods like the tab list popup or 
        direct horizontal scrolling.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabBarFlags_NoTabListScrollingButtons) != 0

    @no_scrolling_button.setter
    def no_scrolling_button(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabBarFlags_NoTabListScrollingButtons
        if value:
            self._flags |= imgui.ImGuiTabBarFlags_NoTabListScrollingButtons

    @property
    def no_tooltip(self):
        """
        Whether tooltips are disabled for all tabs in this tab bar.
        
        When enabled, tooltips that would normally appear when hovering over tabs 
        are suppressed for all tabs in this tab bar. This can be useful for 
        creating a cleaner interface or when the tab labels are already clear 
        enough without additional tooltip information.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabBarFlags_NoTooltip) != 0

    @no_tooltip.setter
    def no_tooltip(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabBarFlags_NoTooltip
        if value:
            self._flags |= imgui.ImGuiTabBarFlags_NoTooltip

    @property
    def selected_overline(self):
        """
        Whether to draw an overline marker on the selected tab.
        
        When enabled, the currently selected tab will display an additional line 
        along its top edge, making the active tab more visually distinct from 
        inactive tabs. This can help improve visual feedback about which tab is 
        currently selected, especially in interfaces with custom styling.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabBarFlags_DrawSelectedOverline) != 0

    @selected_overline.setter
    def selected_overline(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabBarFlags_DrawSelectedOverline
        if value:
            self._flags |= imgui.ImGuiTabBarFlags_DrawSelectedOverline

    @property
    def resize_to_fit(self):
        """
        Whether tabs should resize when they don't fit the available space.
        
        When enabled, tabs will automatically resize to smaller widths when there 
        are too many to fit in the available tab bar space. This ensures all tabs 
        remain visible but with potentially truncated labels. When disabled, tabs 
        maintain their optimal size but may require scrolling to access.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabBarFlags_FittingPolicyResizeDown) != 0

    @resize_to_fit.setter
    def resize_to_fit(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabBarFlags_FittingPolicyResizeDown
        if value:
            self._flags |= imgui.ImGuiTabBarFlags_FittingPolicyResizeDown

    @property
    def allow_tab_scroll(self):
        """
        Whether to add scroll buttons when tabs don't fit the available space.
        
        When enabled and tabs cannot fit in the available tab bar width, scroll 
        buttons will appear to allow navigation through all tabs. This preserves 
        the original size and appearance of each tab while ensuring all tabs 
        remain accessible, even when there are many tabs or limited screen space.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabBarFlags_FittingPolicyScroll) != 0

    @allow_tab_scroll.setter
    def allow_tab_scroll(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabBarFlags_FittingPolicyScroll
        if value:
            self._flags |= imgui.ImGuiTabBarFlags_FittingPolicyScroll

    cdef bint draw_item(self) noexcept nogil:
        imgui.PushID(self.uuid)
        imgui.BeginGroup() # from original. Unsure if needed
        cdef bint visible = imgui.BeginTabBar(self._imgui_label.c_str(),
                                              self._flags)
        self.update_current_state()
        cdef Vec2 pos_p, parent_size_backup
        cdef float dx, dy
        if visible:
            if self.last_tab_child is not None:
                pos_p = ImVec2Vec2(imgui.GetCursorScreenPos())
                dx = pos_p.x - self.context.viewport.parent_pos.x
                dy = pos_p.y - self.context.viewport.parent_pos.y

                parent_size_backup = self.context.viewport.parent_size
                self.context.viewport.parent_size.x = parent_size_backup.x - dx
                self.context.viewport.parent_size.y = parent_size_backup.y - dy

                swap_Vec2(pos_p, self.context.viewport.parent_pos)
                draw_tab_children(self)
                self.context.viewport.parent_pos = pos_p
                self.context.viewport.parent_size = parent_size_backup
            imgui.EndTabBar()
        else:
            self.propagate_hidden_state_to_children_with_handlers()
        # PushStyleVar was added because EngGroup adds itemSpacing
        # which messed up requested sizes. However it seems the
        # issue was fixed by imgui
        #imgui.PushStyleVar(imgui.ImGuiStyleVar_ItemSpacing,
        #                       imgui.ImVec2(0., 0.))
        imgui.EndGroup()
        #imgui.PopStyleVar(1)
        imgui.PopID()
        return self.state.cur.active and not(self.state.prev.active)



cdef class TreeNode(uiItem):
    """
    A collapsible UI element that can contain child widgets in a hierarchical structure.
    
    TreeNode creates a collapsible section in the UI that can be expanded or collapsed
    by the user. When expanded, it displays its child elements, allowing for hierarchical
    organization of content. When collapsed, children are hidden to save space.
    
    TreeNodes can be nested to create multi-level hierarchies, and can be styled with
    various visual options like bullets, arrows, or leaf nodes. They support different
    interaction modes including single/double-click expansion, selection highlighting,
    and variable hit-box sizes.
    
    The open/closed state is stored in a SharedBool value that can be accessed through
    the value property, allowing programmatic control of the tree structure in addition
    to user interaction.
    """
    def __cinit__(self):
        self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.can_have_widget_child = True
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_toggled = True
        self._selectable = False
        self._flags = imgui.ImGuiTreeNodeFlags_None

    @property
    def selectable(self):
        """
        Whether the TreeNode appears selected when opened.
        
        When enabled, the tree node will draw with selection highlighting when it's
        in the open state. This provides visual feedback about which nodes are
        expanded, making it easier to navigate complex hierarchies.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._selectable

    @selectable.setter
    def selectable(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._selectable = value

    @property
    def open_on_double_click(self):
        """
        Whether a double-click is required to open the node.
        
        When enabled, the tree node will only open when double-clicked, making it
        harder to accidentally expand nodes. This can be useful for dense trees where
        you want to prevent unintended expansion during navigation or selection.
        
        Can be combined with open_on_arrow to allow both arrow single-clicks and
        label double-clicks to open the node.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTreeNodeFlags_OpenOnDoubleClick) != 0

    @open_on_double_click.setter
    def open_on_double_click(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTreeNodeFlags_OpenOnDoubleClick
        if value:
            self._flags |= imgui.ImGuiTreeNodeFlags_OpenOnDoubleClick

    @property
    def open_on_arrow(self):
        """
        Whether the node opens only when clicking the arrow.
        
        When enabled, the tree node will only open when the user clicks specifically
        on the arrow icon, not anywhere on the label. This makes it easier to select
        nodes without expanding them.
        
        If combined with open_on_double_click, the node can be opened either by a
        single click on the arrow or a double click anywhere on the label.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTreeNodeFlags_OpenOnArrow) != 0

    @open_on_arrow.setter
    def open_on_arrow(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTreeNodeFlags_OpenOnArrow
        if value:
            self._flags |= imgui.ImGuiTreeNodeFlags_OpenOnArrow

    @property
    def leaf(self):
        """
        Whether the node is displayed as a leaf with no expand/collapse control.
        
        When enabled, the tree node will be displayed without an arrow or expansion
        capability, indicating it's an end point in the hierarchy. This is useful for
        terminal nodes that don't contain children, or for creating visual hierarchies
        where some items are not meant to be expanded.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTreeNodeFlags_Leaf) != 0

    @leaf.setter
    def leaf(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTreeNodeFlags_Leaf
        if value:
            self._flags |= imgui.ImGuiTreeNodeFlags_Leaf

    @property
    def bullet(self):
        """
        Whether to display a bullet instead of an arrow.
        
        When enabled, the tree node will show a bullet point instead of the default
        arrow icon. This provides a different visual style that can be used to
        distinguish certain types of nodes or to create bullet list appearances.
        
        Note that the node can still be expanded/collapsed unless the leaf property
        is also set.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTreeNodeFlags_Bullet) != 0

    @bullet.setter
    def bullet(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTreeNodeFlags_Bullet
        if value:
            self._flags |= imgui.ImGuiTreeNodeFlags_Bullet

    @property
    def span_text_width(self):
        """
        Whether the clickable area only covers the text label.
        
        When enabled, the hitbox for clicking and hovering will be narrowed to only
        cover the text label portion of the tree node. This creates a more precise
        interaction where clicks outside the text (but still on the row) won't
        activate the node.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTreeNodeFlags_SpanLabelWidth) != 0

    @span_text_width.setter
    def span_text_width(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTreeNodeFlags_SpanLabelWidth
        if value:
            self._flags |= imgui.ImGuiTreeNodeFlags_SpanLabelWidth

    @property
    def span_full_width(self):
        """
        Whether the clickable area spans the entire width of the window.
        
        When enabled, the hitbox for clicking and hovering will extend to the full
        width of the available area, including the indentation space to the left and
        any empty space to the right. This creates a more accessible target for
        interaction and makes the entire row visually respond to hovering.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTreeNodeFlags_SpanFullWidth) != 0

    @span_full_width.setter
    def span_full_width(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTreeNodeFlags_SpanFullWidth
        if value:
            self._flags |= imgui.ImGuiTreeNodeFlags_SpanFullWidth

    cdef bint draw_item(self) noexcept nogil:
        cdef bint was_open = SharedBool.get(<SharedBool>self._value)
        cdef bint closed = False
        cdef imgui.ImGuiTreeNodeFlags flags = self._flags
        imgui.PushID(self.uuid)
        # Unsure group is needed
        imgui.BeginGroup()
        if was_open and self._selectable:
            flags |= imgui.ImGuiTreeNodeFlags_Selected

        imgui.SetNextItemOpen(was_open, imgui.ImGuiCond_Always)
        self.state.cur.open = was_open
        cdef bint open_and_visible = imgui.TreeNodeEx(self._imgui_label.c_str(),
                                                      flags)
        self.update_current_state()
        if imgui.IsItemToggledOpen() and not(was_open):
            SharedBool.set(<SharedBool>self._value, True)
            self.state.cur.open = True
        elif self.state.cur.rendered and was_open and not(open_and_visible):
            SharedBool.set(<SharedBool>self._value, False)
            self.state.cur.open = False
            self.propagate_hidden_state_to_children_with_handlers()
        cdef Vec2 pos_p, parent_size_backup
        cdef float dx, dy
        if open_and_visible:
            if self.last_widgets_child is not None:
                pos_p = ImVec2Vec2(imgui.GetCursorScreenPos())
                dx = pos_p.x - self.context.viewport.parent_pos.x
                dy = pos_p.y - self.context.viewport.parent_pos.y
                swap_Vec2(pos_p, self.context.viewport.parent_pos)
                parent_size_backup = self.context.viewport.parent_size
                self.context.viewport.parent_size.x = parent_size_backup.x - dx
                self.context.viewport.parent_size.y = parent_size_backup.y - dy
                draw_ui_children(self)
                self.context.viewport.parent_pos = pos_p
                self.context.viewport.parent_size = parent_size_backup
            imgui.TreePop()

        #imgui.PushStyleVar(imgui.ImGuiStyleVar_ItemSpacing,
        #                   imgui.ImVec2(0., 0.))
        imgui.EndGroup()
        #imgui.PopStyleVar(1)
        # TODO; rect size from group ?
        imgui.PopID()

cdef class CollapsingHeader(uiItem):
    """
    A collapsible section header that can show or hide a group of widgets.
    
    CollapsingHeader creates a header element that can be expanded or collapsed by 
    the user to reveal or hide its child elements. This helps organize interfaces 
    with multiple sections by allowing users to focus on specific content areas.
    
    The header's open/closed state is stored in a SharedBool value accessible via 
    the value property. Headers can be configured with various interaction modes, 
    visual styles, and can optionally include a close button for hiding the entire 
    section.
    
    CollapsingHeader is often used to create an accordion-like interface where 
    multiple sections can be independently expanded or collapsed to manage screen 
    space in complex interfaces.
    """
    def __cinit__(self):
        self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.can_have_widget_child = True
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_toggled = True
        self._closable = False
        self._flags = imgui.ImGuiTreeNodeFlags_None

    @property
    def closable(self):
        """
        Whether the header displays a close button.
        
        When enabled, a small close button appears on the header that allows users 
        to hide the entire section. When closed this way, the header's 'show' 
        property is set to False, which can be detected through handlers or 
        callbacks. Closed headers are not destroyed, just hidden.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._closable

    @closable.setter
    def closable(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._closable = value

    @property
    def open_on_double_click(self):
        """
        Whether a double-click is required to open the header.
        
        When enabled, the header will only toggle its open state when double-clicked, 
        making it harder to accidentally expand sections. This can be useful for 
        dense interfaces where you want to prevent unintended expansion during 
        navigation.
        
        Can be combined with open_on_arrow to allow both arrow single-clicks and 
        header double-clicks to toggle the section.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTreeNodeFlags_OpenOnDoubleClick) != 0

    @open_on_double_click.setter
    def open_on_double_click(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTreeNodeFlags_OpenOnDoubleClick
        if value:
            self._flags |= imgui.ImGuiTreeNodeFlags_OpenOnDoubleClick

    @property
    def open_on_arrow(self):
        """
        Whether the header opens only when clicking the arrow.
        
        When enabled, the header will only toggle its open state when the user 
        clicks specifically on the arrow icon, not anywhere on the header label. 
        This makes it easier to click on headers without expanding them.
        
        If combined with open_on_double_click, the header can be toggled either by 
        a single click on the arrow or a double click anywhere on the header.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTreeNodeFlags_OpenOnArrow) != 0

    @open_on_arrow.setter
    def open_on_arrow(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTreeNodeFlags_OpenOnArrow
        if value:
            self._flags |= imgui.ImGuiTreeNodeFlags_OpenOnArrow

    @property
    def leaf(self):
        """
        Whether the header is displayed without expansion controls.
        
        When enabled, the header will be displayed without an arrow or expansion 
        capability, creating a non-collapsible section header. This is useful for 
        creating visual hierarchies where some items are fixed headers without 
        collapsible content.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTreeNodeFlags_Leaf) != 0

    @leaf.setter
    def leaf(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTreeNodeFlags_Leaf
        if value:
            self._flags |= imgui.ImGuiTreeNodeFlags_Leaf

    @property
    def bullet(self):
        """
        Whether to display a bullet instead of an arrow.
        
        When enabled, the header will show a bullet point instead of the default 
        arrow icon. This provides a different visual style that can be used to 
        distinguish certain types of sections or to create bullet list appearances.
        
        Note that the header can still be expanded/collapsed unless the leaf 
        property is also set.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTreeNodeFlags_Bullet) != 0

    @bullet.setter
    def bullet(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTreeNodeFlags_Bullet
        if value:
            self._flags |= imgui.ImGuiTreeNodeFlags_Bullet

    cdef bint draw_item(self) noexcept nogil:
        cdef bint was_open = SharedBool.get(<SharedBool>self._value)
        cdef bint closed = False
        cdef imgui.ImGuiTreeNodeFlags flags = self._flags
        if self._closable:
            flags |= imgui.ImGuiTreeNodeFlags_Selected

        imgui.SetNextItemOpen(was_open, imgui.ImGuiCond_Always)
        self.state.cur.open = was_open
        cdef bint open_and_visible = \
            imgui.CollapsingHeader(self._imgui_label.c_str(),
                                   &self._show if self._closable else NULL,
                                   flags)
        if not(self._show):
            self._show_update_requested = True
        self.update_current_state()
        if imgui.IsItemToggledOpen() and not(was_open):
            SharedBool.set(<SharedBool>self._value, True)
            self.state.cur.open = True
        elif self.state.cur.rendered and was_open and not(open_and_visible): # TODO: unsure
            SharedBool.set(<SharedBool>self._value, False)
            self.state.cur.open = False
            self.propagate_hidden_state_to_children_with_handlers()
        cdef Vec2 pos_p, parent_size_backup
        cdef float dx, dy
        if open_and_visible:
            if self.last_widgets_child is not None:
                pos_p = ImVec2Vec2(imgui.GetCursorScreenPos())
                dx = pos_p.x - self.context.viewport.parent_pos.x
                dy = pos_p.y - self.context.viewport.parent_pos.y
                swap_Vec2(pos_p, self.context.viewport.parent_pos)
                parent_size_backup = self.context.viewport.parent_size
                self.context.viewport.parent_size.x = parent_size_backup.x - dx
                self.context.viewport.parent_size.y = parent_size_backup.y - dy
                draw_ui_children(self)
                self.context.viewport.parent_pos = pos_p
                self.context.viewport.parent_size = parent_size_backup
        # TODO: rect_size from group ?
        return not(was_open) and self.state.cur.open

cdef class ChildWindow(uiItem): # TODO: remove label
    """
    A child window container that enables hierarchical UI layout.
    
    A child window creates a scrollable/clippable region within a parent window 
    that can contain any UI elements and apply its own visual styling.
    
    Child windows provide independent scrolling regions within a parent window
    with content automatically clipped to the visible region. Content size can
    be fixed or dynamic based on settings. You can enable borders and backgrounds
    independently, customize keyboard focus navigation, and add menu bars for
    structured layouts.
    """
    def __cinit__(self):
        self._child_flags = imgui.ImGuiChildFlags_Borders | imgui.ImGuiChildFlags_NavFlattened
        self._window_flags = imgui.ImGuiWindowFlags_NoSavedSettings
        # TODO scrolling
        self.can_have_widget_child = True
        self.can_have_menubar_child = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self.state.cap.has_content_region = True

    @property
    def always_show_vertical_scrollvar(self):
        """
        Always show a vertical scrollbar even when content fits.
        
        When enabled, the vertical scrollbar will always be displayed regardless
        of whether the content requires scrolling. This can be useful for
        maintaining consistent layouts where scrollbars may appear and disappear.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_AlwaysVerticalScrollbar) else False

    @always_show_vertical_scrollvar.setter
    def always_show_vertical_scrollvar(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_AlwaysVerticalScrollbar
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_AlwaysVerticalScrollbar

    @property
    def always_show_horizontal_scrollvar(self):
        """
        Always show a horizontal scrollbar when horizontal scrolling is enabled.
        
        When enabled, the horizontal scrollbar will always be displayed if
        horizontal scrolling is enabled, regardless of content width. This creates
        a consistent layout where the scrollbar space is always reserved.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_AlwaysHorizontalScrollbar) else False

    @always_show_horizontal_scrollvar.setter
    def always_show_horizontal_scrollvar(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_AlwaysHorizontalScrollbar
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_AlwaysHorizontalScrollbar

    @property
    def no_scrollbar(self):
        """
        Hide scrollbars but still allow scrolling with mouse/keyboard.
        
        When enabled, the window will not display scrollbars but content can
        still be scrolled using mouse wheel, keyboard, or programmatically.
        This creates a cleaner visual appearance while maintaining scrolling
        functionality.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoScrollbar) else False

    @no_scrollbar.setter
    def no_scrollbar(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoScrollbar
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoScrollbar

    @property
    def horizontal_scrollbar(self):
        """
        Enable horizontal scrolling and show horizontal scrollbar.
        
        When enabled, the window will support horizontal scrolling and display
        a horizontal scrollbar when content exceeds the window width. This is
        useful for wide content such as tables or long text lines that shouldn't
        wrap.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_HorizontalScrollbar) else False

    @horizontal_scrollbar.setter
    def horizontal_scrollbar(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_HorizontalScrollbar
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_HorizontalScrollbar

    @property
    def menubar(self):
        """
        Enable a menu bar at the top of the child window.
        
        When enabled, the child window will display a menu bar at the top that
        can contain Menu elements. This property returns True if either the
        user has explicitly enabled it or if the window contains MenuBar child
        elements.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.last_menubar_child is not None) or (self._window_flags & imgui.ImGuiWindowFlags_MenuBar) != 0

    @menubar.setter
    def menubar(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_MenuBar
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_MenuBar

    @property
    def no_scroll_with_mouse(self):
        """
        Forward mouse wheel events to parent instead of scrolling this window.
        
        When enabled, mouse wheel scrolling over this window will be forwarded
        to the parent window instead of scrolling this child window's content.
        This setting is ignored if no_scrollbar is also enabled. Useful for
        windows where you want to prioritize the parent's scrolling behavior.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._window_flags & imgui.ImGuiWindowFlags_NoScrollWithMouse) != 0

    @no_scroll_with_mouse.setter
    def no_scroll_with_mouse(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoScrollWithMouse
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoScrollWithMouse

    @property
    def flattened_navigation(self):
        """
        Share focus scope with parent window for keyboard/gamepad navigation.
        
        When enabled, the focus scope is shared between parent and child windows,
        allowing keyboard and gamepad navigation to seamlessly cross between the
        parent window and this child or between sibling child windows. This
        creates a more intuitive navigation experience.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._child_flags & imgui.ImGuiChildFlags_NavFlattened) != 0

    @flattened_navigation.setter
    def flattened_navigation(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._child_flags &= ~imgui.ImGuiChildFlags_NavFlattened
        if value:
            self._child_flags |= imgui.ImGuiChildFlags_NavFlattened

    @property
    def border(self):
        """
        Show an outer border and enable window padding.
        
        When enabled, the child window will display a border around its edges
        and automatically apply padding inside. This helps visually separate
        the child window's content from its surroundings and creates a cleaner,
        more structured appearance.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._child_flags & imgui.ImGuiChildFlags_Borders) != 0

    @border.setter
    def border(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._child_flags &= ~imgui.ImGuiChildFlags_Borders
        if value:
            self._child_flags |= imgui.ImGuiChildFlags_Borders

    @property
    def always_auto_resize(self):
        """
        Measure content size even when window is hidden.
        
        When enabled in combination with auto_resize_x/auto_resize_y, the window
        will always measure its content size even when hidden. This causes the
        children to be rendered (though not visible) which allows for more
        consistent layouts when showing/hiding child windows.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._child_flags & imgui.ImGuiChildFlags_AlwaysAutoResize) != 0

    @always_auto_resize.setter
    def always_auto_resize(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._child_flags &= ~imgui.ImGuiChildFlags_AlwaysAutoResize
        if value:
            self._child_flags |= imgui.ImGuiChildFlags_AlwaysAutoResize

    @property
    def always_use_window_padding(self):
        """
        Apply window padding even when borders are disabled.
        
        When enabled, the child window will use the style's WindowPadding even if
        no borders are drawn. By default, non-bordered child windows don't apply
        padding. This creates consistent internal spacing regardless of whether
        borders are displayed.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._child_flags & imgui.ImGuiChildFlags_AlwaysUseWindowPadding) != 0

    @always_use_window_padding.setter
    def always_use_window_padding(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._child_flags &= ~imgui.ImGuiChildFlags_AlwaysUseWindowPadding
        if value:
            self._child_flags |= imgui.ImGuiChildFlags_AlwaysUseWindowPadding

    @property
    def auto_resize_x(self):
        """
        Automatically adjust width based on content.
        
        When enabled, the child window will automatically resize its width based
        on the content inside it. Setting width to 0 with this option disabled
        will instead use the remaining width of the parent. This option is
        incompatible with resizable_x.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._child_flags & imgui.ImGuiChildFlags_AutoResizeX) != 0

    @auto_resize_x.setter
    def auto_resize_x(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._child_flags &= ~imgui.ImGuiChildFlags_AutoResizeX
        if value:
            self._child_flags |= imgui.ImGuiChildFlags_AutoResizeX

    @property
    def auto_resize_y(self):
        """
        Automatically adjust height based on content.
        
        When enabled, the child window will automatically resize its height based
        on the content inside it. Setting height to 0 with this option disabled
        will instead use the remaining height of the parent. This option is
        incompatible with resizable_y.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._child_flags & imgui.ImGuiChildFlags_AutoResizeY) != 0

    @auto_resize_y.setter
    def auto_resize_y(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._child_flags &= ~imgui.ImGuiChildFlags_AutoResizeY
        if value:
            self._child_flags |= imgui.ImGuiChildFlags_AutoResizeY

    @property
    def frame_style(self):
        """
        Style the child window like a framed item instead of a window.
        
        When enabled, the child window will use frame-related style variables
        (FrameBg, FrameRounding, FrameBorderSize, FramePadding) instead of
        window-related ones (ChildBg, ChildRounding, ChildBorderSize,
        WindowPadding). This creates visual consistency with other framed elements.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._child_flags & imgui.ImGuiChildFlags_FrameStyle) != 0

    @frame_style.setter
    def frame_style(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._child_flags &= ~imgui.ImGuiChildFlags_FrameStyle
        if value:
            self._child_flags |= imgui.ImGuiChildFlags_FrameStyle

    @property
    def resizable_x(self):
        """
        Allow the user to resize the window width by dragging the right border.
        
        When enabled, the user can click and drag the right border of the child
        window to adjust its width. The direction respects the current layout
        direction. This option is incompatible with auto_resize_x and provides
        interactive resizing abilities to the child window.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._child_flags & imgui.ImGuiChildFlags_ResizeX) != 0

    @resizable_x.setter
    def resizable_x(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._child_flags &= ~imgui.ImGuiChildFlags_ResizeX
        if value:
            self._child_flags |= imgui.ImGuiChildFlags_ResizeX

    @property
    def resizable_y(self):
        """
        Allow the user to resize the window height by dragging the bottom border.
        
        When enabled, the user can click and drag the bottom border of the child
        window to adjust its height. The direction respects the current layout
        direction. This option is incompatible with auto_resize_y and provides
        interactive resizing abilities to the child window.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._child_flags & imgui.ImGuiChildFlags_ResizeY) != 0

    @resizable_y.setter
    def resizable_y(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._child_flags &= ~imgui.ImGuiChildFlags_ResizeY
        if value:
            self._child_flags |= imgui.ImGuiChildFlags_ResizeY

    cdef bint draw_item(self) noexcept nogil:
        cdef imgui.ImGuiWindowFlags flags = self._window_flags
        if self.last_menubar_child is not None:
            flags |= imgui.ImGuiWindowFlags_MenuBar
        cdef Vec2 pos_p, pos_w, parent_size_backup
        cdef Vec2 requested_size = self.get_requested_size()
        cdef imgui.ImGuiChildFlags child_flags = self._child_flags
        # Else they have no effect
        if child_flags & imgui.ImGuiChildFlags_AutoResizeX:
            requested_size.x = 0
            # incompatible flags
            child_flags &= ~imgui.ImGuiChildFlags_ResizeX
        if child_flags & imgui.ImGuiChildFlags_AutoResizeY:
            requested_size.y = 0
            child_flags &= ~imgui.ImGuiChildFlags_ResizeY
        # Else imgui is not happy
        if child_flags & imgui.ImGuiChildFlags_AlwaysAutoResize:
            if (child_flags & (imgui.ImGuiChildFlags_AutoResizeX | imgui.ImGuiChildFlags_AutoResizeY)) == 0:
                child_flags &= ~imgui.ImGuiChildFlags_AlwaysAutoResize
        if imgui.BeginChild(self._imgui_label.c_str(),
                            Vec2ImVec2(requested_size),
                            child_flags,
                            flags):
            self.state.cur.content_region_size = ImVec2Vec2(imgui.GetContentRegionAvail())
            pos_p = ImVec2Vec2(imgui.GetCursorScreenPos())
            pos_w = pos_p
            self.state.cur.content_pos = pos_p
            swap_Vec2(pos_p, self.context.viewport.parent_pos)
            swap_Vec2(pos_w, self.context.viewport.window_pos)
            parent_size_backup = self.context.viewport.parent_size
            self.context.viewport.parent_size = self.state.cur.content_region_size
            draw_ui_children(self)
            draw_menubar_children(self)
            self.context.viewport.window_pos = pos_w
            self.context.viewport.parent_pos = pos_p
            self.context.viewport.parent_size = parent_size_backup
            self.state.cur.rendered = True
            self.state.cur.hovered = imgui.IsWindowHovered(imgui.ImGuiHoveredFlags_None)
            self.state.cur.focused = imgui.IsWindowFocused(imgui.ImGuiFocusedFlags_None)
            self.state.cur.rect_size = ImVec2Vec2(imgui.GetWindowSize())
            update_current_mouse_states(self.state)
            # TODO scrolling
            # The sizing of windows might not converge right away
            if self.state.cur.content_region_size.x != self.state.prev.content_region_size.x or \
               self.state.cur.content_region_size.y != self.state.prev.content_region_size.y:
                self.context.viewport.redraw_needed = True
        else:
            self.set_hidden_no_handler_and_propagate_to_children_with_handlers()
        imgui.EndChild()
        return False # maybe True when visible ?

cdef class ColorButton(uiItem):
    """
    A button that displays a color preview and opens a color picker when clicked.
    
    ColorButton creates an interactive color swatch that can be clicked to open a
    color picker popup. It displays the current color value and allows users to
    select a new color through the popup interface.
    
    The button's appearance can be customized with options for alpha display,
    borders, tooltips, and drag-and-drop functionality. The color value is stored
    in a SharedColor object accessible through the value property.
    
    When clicked, the button opens a color picker popup with the same options
    and behavior as the ColorPicker widget. This provides a compact way to
    integrate color selection into interfaces with limited space.
    """
    def __cinit__(self):
        self._flags = imgui.ImGuiColorEditFlags_DefaultOptions_
        self._value = <SharedValue>(SharedColor.__new__(SharedColor, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True

    @property
    def no_alpha(self):
        """
        Whether to ignore the Alpha component of the color.
        
        When enabled, the button will display and operate only on the RGB
        components of the color, ignoring transparency. This is useful for
        interfaces where you only need to select solid colors without alpha
        transparency.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoAlpha) != 0

    @no_alpha.setter
    def no_alpha(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoAlpha
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoAlpha

    @property
    def no_tooltip(self):
        """
        Whether to disable the default tooltip when hovering.
        
        When enabled, the automatic tooltip showing color information when
        hovering over the button will be suppressed. This is useful for cleaner
        interfaces or when you want to provide your own tooltip through a
        separate Tooltip widget.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoTooltip) != 0

    @no_tooltip.setter
    def no_tooltip(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoTooltip
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoTooltip

    @property
    def no_drag_drop(self):
        """
        Whether to disable drag and drop functionality for the button.
        
        When enabled, the button won't work as a drag source for color values.
        By default, color buttons can be dragged to compatible drop targets
        (like other color widgets) to transfer their color value. Disabling this
        prevents that behavior.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoDragDrop) != 0

    @no_drag_drop.setter
    def no_drag_drop(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoDragDrop
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoDragDrop

    @property
    def no_border(self):
        """
        Whether to disable the default border around the color button.
        
        When enabled, the button will be displayed without its normal border.
        This can be useful for creating a cleaner look or when you want the
        color swatch to blend seamlessly with surrounding elements.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoBorder) != 0

    @no_border.setter
    def no_border(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoBorder
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoBorder

    @property
    def alpha_preview(self):
        """
        How transparency is displayed in the color button.
        
        Controls how the alpha component of colors is displayed:
        - "none": No special alpha visualization 
        - "full": Shows the entire button with alpha applied (default)
        - "half": Shows half the button with alpha applied
        
        The "half" mode is particularly useful as it allows seeing both the
        color with alpha applied and without in a single preview.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if (self._flags & imgui.ImGuiColorEditFlags_AlphaPreviewHalf) != 0:
            return "half" 
        elif (self._flags & imgui.ImGuiColorEditFlags_AlphaOpaque) != 0:
            return "none"
        return "full" # TODO: ImGuiColorEditFlags_AlphaNoBg

    @alpha_preview.setter
    def alpha_preview(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~(imgui.ImGuiColorEditFlags_AlphaOpaque | imgui.ImGuiColorEditFlags_AlphaPreviewHalf)
        if value == "half":
            self._flags |= imgui.ImGuiColorEditFlags_AlphaPreviewHalf
        elif value == "none":
            self._flags |= imgui.ImGuiColorEditFlags_AlphaOpaque
        elif value != "full":
            raise ValueError("alpha_preview must be 'none', 'full' or 'half'")

    @property
    def data_type(self):
        """
        The data type used for color representation.
        
        Controls how color values are stored and processed:
        - "float": Colors as floating point values from 0.0 to 1.0
        - "uint8": Colors as 8-bit integers from 0 to 255
        
        This affects both the internal representation and how colors are passed
        to and from other widgets when using drag and drop.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return "uint8" if (self._flags & imgui.ImGuiColorEditFlags_Uint8) != 0 else "float" 

    @data_type.setter
    def data_type(self, str value):  
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~(imgui.ImGuiColorEditFlags_Float | imgui.ImGuiColorEditFlags_Uint8)
        if value == "uint8":
            self._flags |= imgui.ImGuiColorEditFlags_Uint8
        elif value == "float":
            self._flags |= imgui.ImGuiColorEditFlags_Float
        else:
            raise ValueError("data_type must be 'uint8' or 'float'")


    cdef bint draw_item(self) noexcept nogil:
        cdef bint activated
        cdef Vec4 col = SharedColor.getF4(<SharedColor>self._value)
        activated = imgui.ColorButton(self._imgui_label.c_str(),
                                      Vec4ImVec4(col),
                                      self._flags,
                                      Vec2ImVec2(self.get_requested_size()))
        self.update_current_state()
        SharedColor.setF4(<SharedColor>self._value, col)
        return activated


cdef class ColorEdit(uiItem):
    """
    A widget for editing RGB or RGBA color values with customizable input methods.
    
    ColorEdit provides interactive color editing through various input methods
    including sliders, hex input fields, and preview swatches. The chosen color
    is stored in a SharedColor value that can be accessed via the value property.
    
    The editor supports different color formats (RGB, HSV, Hex), input modes,
    and display options including alpha transparency. It can be configured to
    show or hide specific components like input fields, preview swatches,
    or alpha controls.
    
    When clicked, the color editor can optionally open a more comprehensive
    color picker popup for additional selection methods. The widget also supports
    drag-and-drop functionality for transferring colors between compatible widgets.
    """
    def __cinit__(self):
        self._flags = imgui.ImGuiColorEditFlags_DefaultOptions_
        self._value = <SharedValue>(SharedColor.__new__(SharedColor, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True

    @property
    def no_alpha(self):
        """
        Whether to ignore the Alpha component of the color.
        
        When enabled, the color editor will display and operate only on the RGB
        components of the color, ignoring transparency. This is useful for
        interfaces where you only need to select solid colors without alpha
        transparency.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoAlpha) != 0

    @no_alpha.setter
    def no_alpha(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoAlpha
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoAlpha

    @property
    def no_picker(self):
        """
        Whether to disable the color picker popup when clicking the color square.
        
        When enabled, clicking on the color preview square won't open the more
        comprehensive color picker popup. This creates a simpler interface limited
        to the main editing controls and can prevent users from accessing the
        additional selection methods in the popup.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoPicker) != 0

    @no_picker.setter
    def no_picker(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoPicker
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoPicker

    @property
    def no_options(self):
        """
        Whether to disable the right-click options menu.
        
        When enabled, right-clicking on the inputs or small preview won't open
        the options context menu. This simplifies the interface by removing
        access to the format switching and other advanced options that would
        normally be available through the right-click menu.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoOptions) != 0

    @no_options.setter
    def no_options(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoOptions
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoOptions

    @property
    def no_small_preview(self):
        """
        Whether to hide the color square preview next to the inputs.
        
        When enabled, the small color swatch that normally appears next to the
        input fields will be hidden, showing only the numeric inputs. This is
        useful for minimalist interfaces or when space is limited, especially
        when combined with other preview options.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoSmallPreview) != 0

    @no_small_preview.setter
    def no_small_preview(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoSmallPreview
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoSmallPreview

    @property
    def no_inputs(self):
        """
        Whether to hide the input sliders and text fields.
        
        When enabled, the numeric input fields and sliders will be hidden,
        showing only the color preview swatch. This creates a compact color
        selector that still allows choosing colors through the picker popup
        when clicked, while taking minimal screen space.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoInputs) != 0

    @no_inputs.setter
    def no_inputs(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoInputs
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoInputs

    @property
    def no_tooltip(self):
        """
        Whether to disable the tooltip when hovering the preview.
        
        When enabled, no tooltip will be shown when hovering over the color
        preview. By default, hovering the preview shows a tooltip with the
        color's values in different formats (RGB, HSV, Hex). This option
        creates a cleaner interface with less automatic popups.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoTooltip) != 0

    @no_tooltip.setter
    def no_tooltip(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoTooltip
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoTooltip

    @property
    def no_label(self):
        """
        Whether to hide the text label next to the color editor.
        
        When enabled, the widget's label won't be displayed inline with the
        color controls. The label text is still used for tooltips and in the
        color picker popup title if enabled. This creates a more compact
        interface when the label content is obvious from context.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoLabel) != 0

    @no_label.setter
    def no_label(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoLabel
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoLabel

    @property
    def no_drag_drop(self):
        """
        Whether to disable drag and drop functionality.
        
        When enabled, the color editor won't work as a drag source or drop
        target for color values. By default, colors can be dragged from 
        this widget to other color widgets, and this widget can receive
        dragged colors. Disabling this creates a simpler interface with no
        drag interaction.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoDragDrop) != 0

    @no_drag_drop.setter
    def no_drag_drop(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoDragDrop
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoDragDrop

    @property
    def alpha_bar(self):
        """
        Whether to show a vertical alpha bar/gradient.
        
        When enabled and when alpha editing is supported, a vertical bar will
        be displayed showing the alpha gradient from transparent to opaque.
        This provides a visual reference for selecting alpha values and makes
        transparency editing more intuitive.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_AlphaBar) != 0

    @alpha_bar.setter 
    def alpha_bar(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_AlphaBar
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_AlphaBar

    @property
    def alpha_preview(self):
        """
        How transparency is displayed in the color button.
        
        Controls how the alpha component of colors is displayed:
        - "none": No special alpha visualization 
        - "full": Shows the entire button with alpha applied (default)
        - "half": Shows half the button with alpha applied
        
        The "half" mode is particularly useful as it allows seeing both the
        color with alpha applied and without in a single preview.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if (self._flags & imgui.ImGuiColorEditFlags_AlphaPreviewHalf) != 0:
            return "half" 
        elif (self._flags & imgui.ImGuiColorEditFlags_AlphaOpaque) != 0:
            return "none"
        return "full" # TODO: ImGuiColorEditFlags_AlphaNoBg

    @alpha_preview.setter
    def alpha_preview(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~(imgui.ImGuiColorEditFlags_AlphaOpaque | imgui.ImGuiColorEditFlags_AlphaPreviewHalf)
        if value == "half":
            self._flags |= imgui.ImGuiColorEditFlags_AlphaPreviewHalf
        elif value == "none":
            self._flags |= imgui.ImGuiColorEditFlags_AlphaOpaque
        elif value != "full":
            raise ValueError("alpha_preview must be 'none', 'full' or 'half'")

    @property
    def display_mode(self):
        """
        The color display format for the input fields.
        
        Controls how color values are displayed in the editor:
        - "rgb": Red, Green, Blue components (default)
        - "hsv": Hue, Saturation, Value components
        - "hex": Hexadecimal color code
        
        This affects only the display format in the editor; the underlying
        color value storage remains consistent regardless of the display mode.
        """  
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if (self._flags & imgui.ImGuiColorEditFlags_DisplayRGB) != 0:
            return "rgb"
        elif (self._flags & imgui.ImGuiColorEditFlags_DisplayHSV) != 0: 
            return "hsv"
        elif (self._flags & imgui.ImGuiColorEditFlags_DisplayHex) != 0:
            return "hex"
        return "rgb" # Default in imgui

    @display_mode.setter 
    def display_mode(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~(imgui.ImGuiColorEditFlags_DisplayRGB | imgui.ImGuiColorEditFlags_DisplayHSV | imgui.ImGuiColorEditFlags_DisplayHex)
        if value == "rgb":
            self._flags |= imgui.ImGuiColorEditFlags_DisplayRGB
        elif value == "hsv":
            self._flags |= imgui.ImGuiColorEditFlags_DisplayHSV
        elif value == "hex":  
            self._flags |= imgui.ImGuiColorEditFlags_DisplayHex
        else:
            raise ValueError("display_mode must be 'rgb', 'hsv' or 'hex'")

    @property
    def input_mode(self):
        """
        The color input format for editing operations.
        
        Controls which color model is used for input operations:
        - "rgb": Edit in Red, Green, Blue color space (default)
        - "hsv": Edit in Hue, Saturation, Value color space
        
        This determines how slider adjustments behave - HSV mode often provides
        more intuitive color editing since it separates color (hue) from
        brightness and intensity.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return "hsv" if (self._flags & imgui.ImGuiColorEditFlags_InputHSV) != 0 else "rgb"

    @input_mode.setter
    def input_mode(self, str value):
        cdef unique_lock[DCGMutex] m  
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~(imgui.ImGuiColorEditFlags_InputRGB | imgui.ImGuiColorEditFlags_InputHSV)
        if value == "rgb":
            self._flags |= imgui.ImGuiColorEditFlags_InputRGB
        elif value == "hsv":
            self._flags |= imgui.ImGuiColorEditFlags_InputHSV
        else:
            raise ValueError("input_mode must be 'rgb' or 'hsv'")

    @property
    def data_type(self):
        """
        The data type used for color representation.
        
        Controls how color values are stored and processed:
        - "float": Colors as floating point values from 0.0 to 1.0
        - "uint8": Colors as 8-bit integers from 0 to 255
        
        This affects both the internal representation and how colors are passed
        to and from other widgets when using drag and drop.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return "uint8" if (self._flags & imgui.ImGuiColorEditFlags_Uint8) != 0 else "float" 

    @data_type.setter
    def data_type(self, str value):  
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~(imgui.ImGuiColorEditFlags_Float | imgui.ImGuiColorEditFlags_Uint8)
        if value == "uint8":
            self._flags |= imgui.ImGuiColorEditFlags_Uint8
        elif value == "float":
            self._flags |= imgui.ImGuiColorEditFlags_Float
        else:
            raise ValueError("data_type must be 'uint8' or 'float'")

    @property
    def hdr(self):
        """
        Whether to support HDR (High Dynamic Range) colors.
        
        When enabled, the color editor will support values outside the standard
        0.0-1.0 range, allowing for HDR color selection. This is useful for
        applications working with lighting, rendering, or other contexts where
        color intensities can exceed standard display ranges.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_HDR) != 0

    @hdr.setter
    def hdr(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_HDR
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_HDR

    cdef bint draw_item(self) noexcept nogil:
        cdef bint activated
        cdef Vec4 col = SharedColor.getF4(<SharedColor>self._value)
        cdef float[4] color = [col.x, col.y, col.z, col.w]

        cdef Vec2 requested_size = self.get_requested_size()
        if requested_size.x != 0:
            imgui.SetNextItemWidth(requested_size.x)

        activated = imgui.ColorEdit4(self._imgui_label.c_str(),
                                     color,
                                     self._flags)
        self.update_current_state()
        col = ImVec4Vec4(imgui.ImVec4(color[0], color[1], color[2], color[3]))
        SharedColor.setF4(<SharedColor>self._value, col)
        return activated

cdef class ColorPicker(uiItem):
    """
    A comprehensive color selection widget with multiple input and display options.
    
    ColorPicker provides a full-featured interface for selecting colors with 
    multiple input methods including RGB/HSV sliders, color wheels, and hex input. 
    It includes preview panels showing both the current and previous color, and 
    supports advanced features like alpha transparency editing.
    
    The picker can be configured with various display modes, input formats, and 
    visual options to adjust its appearance and behavior. It's ideal for 
    applications requiring precise color selection with immediate visual feedback.
    
    The selected color is stored in a SharedColor value accessible through the
    value property inherited from uiItem.
    """
    def __cinit__(self):
        self._flags = imgui.ImGuiColorEditFlags_DefaultOptions_
        self._value = <SharedValue>(SharedColor.__new__(SharedColor, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True

    @property
    def no_alpha(self):
        """
        Whether to ignore the Alpha component of the color.
        
        When enabled, the color picker will display and operate only on the RGB
        components of the color, ignoring transparency. This is useful for
        interfaces where you only need to select solid colors without alpha
        transparency.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoAlpha) != 0

    @no_alpha.setter
    def no_alpha(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoAlpha
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoAlpha

    @property
    def no_small_preview(self):
        """
        Whether to hide the color square preview next to the inputs.
        
        When enabled, the small color swatch that normally appears next to the
        input fields will be hidden, showing only the numeric inputs. This is
        useful for minimalist interfaces or when space is limited, especially
        when combined with other preview options.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoSmallPreview) != 0

    @no_small_preview.setter
    def no_small_preview(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoSmallPreview
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoSmallPreview

    @property
    def no_inputs(self):
        """
        Whether to hide the input sliders and text fields.
        
        When enabled, the numeric input fields and sliders will be hidden,
        showing only the color preview and picker elements. This creates a more
        visual color selection experience focused on the color wheel or bars
        rather than numeric precision.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoInputs) != 0

    @no_inputs.setter
    def no_inputs(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoInputs
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoInputs

    @property
    def no_tooltip(self):
        """
        Whether to disable the tooltip when hovering the preview.
        
        When enabled, no tooltip will be shown when hovering over the color
        preview. By default, hovering the preview shows a tooltip with the
        color's values in different formats (RGB, HSV, Hex). This option
        creates a cleaner interface with less automatic popups.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoTooltip) != 0

    @no_tooltip.setter
    def no_tooltip(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoTooltip
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoTooltip

    @property
    def no_label(self):
        """
        Whether to hide the text label next to the color picker.
        
        When enabled, the widget's label won't be displayed inline with the
        color controls. The label text is still used for tooltips and in the
        picker title. This creates a more compact interface when the label
        content is obvious from context.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoLabel) != 0

    @no_label.setter
    def no_label(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoLabel
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoLabel

    @property
    def no_side_preview(self):
        """
        Whether to disable the large color preview on the picker's side.
        
        When enabled, the larger color preview area on the right side of the 
        picker (which typically shows both current and original colors) will be 
        hidden. This reduces the picker's width and creates a more compact 
        interface when space is limited.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoSidePreview) != 0

    @no_side_preview.setter  
    def no_side_preview(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoSidePreview
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoSidePreview

    @property
    def picker_mode(self):
        """
        The visual style of the color picker control.
        
        Controls whether the color picker uses a bar or wheel interface for hue 
        selection. The "bar" mode shows horizontal bars for hue, saturation and 
        value, while "wheel" mode displays a circular hue selector with a 
        square saturation/value selector. Different modes may be preferred 
        depending on personal preference or specific color selection tasks.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)  
        return "wheel" if (self._flags & imgui.ImGuiColorEditFlags_PickerHueWheel) != 0 else "bar"

    @picker_mode.setter
    def picker_mode(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~(imgui.ImGuiColorEditFlags_PickerHueBar | imgui.ImGuiColorEditFlags_PickerHueWheel)
        if value == "bar":
            self._flags |= imgui.ImGuiColorEditFlags_PickerHueBar
        elif value == "wheel":
            self._flags |= imgui.ImGuiColorEditFlags_PickerHueWheel
        else:
            raise ValueError("picker_mode must be 'bar' or 'wheel'")

    @property
    def alpha_bar(self):
        """
        Whether to show a vertical alpha bar/gradient.
        
        When enabled and when alpha editing is supported, a vertical bar will
        be displayed showing the alpha gradient from transparent to opaque.
        This provides a visual reference for selecting alpha values and makes
        transparency editing more intuitive.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_AlphaBar) != 0

    @alpha_bar.setter 
    def alpha_bar(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_AlphaBar
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_AlphaBar

    @property
    def alpha_preview(self):
        """
        How transparency is displayed in the color button.
        
        Controls how the alpha component of colors is displayed:
        - "none": No special alpha visualization 
        - "full": Shows the entire button with alpha applied (default)
        - "half": Shows half the button with alpha applied
        
        The "half" mode is particularly useful as it allows seeing both the
        color with alpha applied and without in a single preview.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if (self._flags & imgui.ImGuiColorEditFlags_AlphaPreviewHalf) != 0:
            return "half" 
        elif (self._flags & imgui.ImGuiColorEditFlags_AlphaOpaque) != 0:
            return "none"
        return "full" # TODO: ImGuiColorEditFlags_AlphaNoBg

    @alpha_preview.setter
    def alpha_preview(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~(imgui.ImGuiColorEditFlags_AlphaOpaque | imgui.ImGuiColorEditFlags_AlphaPreviewHalf)
        if value == "half":
            self._flags |= imgui.ImGuiColorEditFlags_AlphaPreviewHalf
        elif value == "none":
            self._flags |= imgui.ImGuiColorEditFlags_AlphaOpaque
        elif value != "full":
            raise ValueError("alpha_preview must be 'none', 'full' or 'half'")

    @property
    def display_mode(self):
        """
        The color display format for the input fields.
        
        Controls how color values are displayed in the picker:
        - "rgb": Red, Green, Blue components (default)
        - "hsv": Hue, Saturation, Value components
        - "hex": Hexadecimal color code
        
        This affects only the display format in the editor; the underlying
        color value storage remains consistent regardless of the display mode.
        """  
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if (self._flags & imgui.ImGuiColorEditFlags_DisplayRGB) != 0:
            return "rgb"
        elif (self._flags & imgui.ImGuiColorEditFlags_DisplayHSV) != 0: 
            return "hsv"
        elif (self._flags & imgui.ImGuiColorEditFlags_DisplayHex) != 0:
            return "hex"
        return "rgb" # Default in imgui

    @display_mode.setter 
    def display_mode(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~(imgui.ImGuiColorEditFlags_DisplayRGB | imgui.ImGuiColorEditFlags_DisplayHSV | imgui.ImGuiColorEditFlags_DisplayHex)
        if value == "rgb":
            self._flags |= imgui.ImGuiColorEditFlags_DisplayRGB
        elif value == "hsv":
            self._flags |= imgui.ImGuiColorEditFlags_DisplayHSV
        elif value == "hex":  
            self._flags |= imgui.ImGuiColorEditFlags_DisplayHex
        else:
            raise ValueError("display_mode must be 'rgb', 'hsv' or 'hex'")

    @property
    def input_mode(self):
        """
        The color input format for editing operations.
        
        Controls which color model is used for input operations:
        - "rgb": Edit in Red, Green, Blue color space (default)
        - "hsv": Edit in Hue, Saturation, Value color space
        
        This determines how slider adjustments behave - HSV mode often provides
        more intuitive color editing since it separates color (hue) from
        brightness and intensity.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return "hsv" if (self._flags & imgui.ImGuiColorEditFlags_InputHSV) != 0 else "rgb"

    @input_mode.setter
    def input_mode(self, str value):
        cdef unique_lock[DCGMutex] m  
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~(imgui.ImGuiColorEditFlags_InputRGB | imgui.ImGuiColorEditFlags_InputHSV)
        if value == "rgb":
            self._flags |= imgui.ImGuiColorEditFlags_InputRGB
        elif value == "hsv":
            self._flags |= imgui.ImGuiColorEditFlags_InputHSV
        else:
            raise ValueError("input_mode must be 'rgb' or 'hsv'")

    @property
    def data_type(self):
        """
        The data type used for color representation.
        
        Controls how color values are stored and processed:
        - "float": Colors as floating point values from 0.0 to 1.0
        - "uint8": Colors as 8-bit integers from 0 to 255
        
        This affects both the internal representation and how colors are passed
        to and from other widgets when using drag and drop.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return "uint8" if (self._flags & imgui.ImGuiColorEditFlags_Uint8) != 0 else "float" 

    @data_type.setter
    def data_type(self, str value):  
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~(imgui.ImGuiColorEditFlags_Float | imgui.ImGuiColorEditFlags_Uint8)
        if value == "uint8":
            self._flags |= imgui.ImGuiColorEditFlags_Uint8
        elif value == "float":
            self._flags |= imgui.ImGuiColorEditFlags_Float
        else:
            raise ValueError("data_type must be 'uint8' or 'float'")

    cdef bint draw_item(self) noexcept nogil:
        cdef bint activated
        cdef Vec4 col = SharedColor.getF4(<SharedColor>self._value)
        cdef float[4] color = [col.x, col.y, col.z, col.w]

        cdef Vec2 requested_size = self.get_requested_size()
        if requested_size.x != 0:
            imgui.SetNextItemWidth(requested_size.x)

        activated = imgui.ColorPicker4(self._imgui_label.c_str(),
                                       color,
                                       self._flags,
                                       NULL) # ref_col ??
        self.update_current_state()
        col = ImVec4Vec4(imgui.ImVec4(color[0], color[1], color[2], color[3]))
        SharedColor.setF4(<SharedColor>self._value, col)
        return activated



cdef class SharedBool(SharedValue):
    def __init__(self, Context context, bint value):
        self._value = value
        self._num_attached = 0
    @property
    def value(self):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._value
    @value.setter
    def value(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef bint changed = value != self._value
        self._value = value
        self.on_update(changed)
    cdef bint get(self) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        return self._value
    cdef void set(self, bint value) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        cdef bint changed = value != self._value
        self._value = value
        self.on_update(changed)

cdef class SharedFloat(SharedValue):
    def __init__(self, Context context, double value):
        self._value = value
        self._num_attached = 0
    @property
    def value(self):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._value
    @value.setter
    def value(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef bint changed = value != self._value
        self._value = value
        self.on_update(changed)
    cdef double get(self) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        return self._value
    cdef void set(self, double value) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        cdef bint changed = value != self._value
        self._value = value
        self.on_update(changed)

cdef class SharedColor(SharedValue):
    def __init__(self, Context context, value):
        self._value = parse_color(value)
        self._value_asfloat4 = ImVec4Vec4(imgui.ColorConvertU32ToFloat4(self._value))
        self._num_attached = 0
    @property
    def value(self):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        #"Color data is an int32 (rgba, little endian),\n" \
        #"If you pass an array of int (r, g, b, a), or float\n" \
        #"(r, g, b, a) normalized it will get converted automatically"
        return <int>self._value
    @value.setter
    def value(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._value = parse_color(value)
        self._value_asfloat4 = ImVec4Vec4(imgui.ColorConvertU32ToFloat4(self._value))
        self.on_update(True)
    cdef uint32_t getU32(self) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        return self._value
    cdef Vec4 getF4(self) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        return self._value_asfloat4
    cdef void setU32(self, uint32_t value) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        self._value = value
        self._value_asfloat4 = ImVec4Vec4(imgui.ColorConvertU32ToFloat4(self._value))
        self.on_update(True)
    cdef void setF4(self, Vec4 value) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        self._value_asfloat4 = value
        self._value = imgui.ColorConvertFloat4ToU32(Vec4ImVec4(self._value_asfloat4))
        self.on_update(True)

cdef class SharedStr(SharedValue):
    def __init__(self, Context context, str value):
        self._value = string_from_str(value)
        self._num_attached = 0
    @property
    def value(self):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return string_to_str(self._value)
    @value.setter
    def value(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._value = string_from_str(str(value))
        self.on_update(True)
    cdef void get(self, DCGString& out) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        out = self._value
    cdef void set(self, DCGString value) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        self._value = value
        self.on_update(True)


cdef class SharedFloatVect(SharedValue):
    def __init__(self, Context context, value):
        self._value =  cython_array(shape=(len(value),), itemsize=4, format='f')
        # Copy values into array
        cdef size_t i
        for i in range(<size_t>len(value)):
            self._value[i] = value[i]
        self._num_attached = 0

    def __cinit__(self):
        # Initialize empty array
        cdef cython_array arr = cython_array(shape=(1,), itemsize=4, format='f')
        self._value = arr[:0]

    @property 
    def value(self):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        # Create new array and copy values
        cdef cython_array arr = cython_array(shape=(self._value.shape[0],), itemsize=4, format='f')
        cdef float[::1] arr_view = arr
        cdef size_t i
        for i in range(self._value.shape[0]):
            arr_view[i] = self._value[i]
        return arr

    @value.setter
    def value(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        # Create new array with the input values
        if len(value) != self._value.shape[0]:
            self._value = cython_array(shape=(len(value),), itemsize=4, format='f')
        cdef size_t i
        for i in range(len(value)):
            self._value[i] = value[i]
        self._last_frame_change = self.context.viewport.frame_count
        self.on_update(True)

    cdef float[::1] get(self) noexcept nogil:
        return self._value

    cdef void set(self, float[::1] value) noexcept nogil:
        # Create new array and copy values
        if value.shape[0] != self._value.shape[0]:
            with gil:
                self._value = cython_array(shape=(value.shape[0],), itemsize=4, format='f')
        cdef size_t i
        for i in range(value.shape[0]):
            self._value[i] = value[i]
        self._last_frame_change = self.context.viewport.frame_count
        self.on_update(True)
