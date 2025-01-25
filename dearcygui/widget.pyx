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

from libcpp cimport bool
from libc.stdint cimport uint32_t, int32_t
from libc.stdlib cimport malloc, free
from libc.string cimport memcpy, memset

from dearcygui.wrapper cimport imgui, implot
from libcpp.cmath cimport trunc
from libcpp.string cimport string
from libc.math cimport INFINITY


from .core cimport baseHandler, drawingItem, uiItem, \
    lock_gil_friendly, read_point, clear_obj_vector, append_obj_vector, \
    draw_drawing_children, draw_menubar_children, \
    draw_ui_children, button_area, \
    draw_tab_children, Callback, \
    Context, read_vec4, read_point, \
    SharedValue, update_current_mouse_states
from .c_types cimport *
from .imgui_types cimport unparse_color, parse_color, Vec2ImVec2, \
    Vec4ImVec4, ImVec2Vec2, ImVec4Vec4, ButtonDirection
from .types cimport *

import numpy as np
cimport numpy as cnp
cnp.import_array()



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
        self._button = 31
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return <MouseButtonMask>self._button

    @button.setter
    def button(self, MouseButtonMask value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if <int>value < 0 or <int>value > 31:
            raise ValueError(f"Invalid button mask {value} passed to {self}")
        self._button = <imgui.ImGuiButtonFlags>value

    @property
    def p1(self):
        """
        Corner of the invisible button in plot/drawing
        space
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p1)

    @p1.setter
    def p1(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_point[double](self._p1, value)

    @property
    def p2(self):
        """
        Opposite corner of the invisible button in plot/drawing
        space
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build(self._p2)

    @p2.setter
    def p2(self, value):
        cdef unique_lock[recursive_mutex] m
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._min_side

    @min_side.setter
    def min_side(self, int32_t value):
        cdef unique_lock[recursive_mutex] m
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._max_side

    @max_side.setter
    def max_side(self, int32_t value):
        cdef unique_lock[recursive_mutex] m
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
        cdef unique_lock[recursive_mutex] m
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list items = []
        cdef int32_t i
        if value is None:
            clear_obj_vector(self._handlers)
            return
        if not hasattr(value, "__len__"):
            value = [value]
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
    def activated(self):
        """
        Readonly attribute: has the button just been pressed
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.active and not(self.state.prev.active)

    @property
    def active(self):
        """
        Readonly attribute: is the button held
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.active

    @property
    def clicked(self):
        """
        Readonly attribute: has the item just been clicked.
        The returned value is a tuple of len 5 containing the individual test
        mouse buttons (up to 5 buttons)
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return tuple(self.state.cur.clicked)

    @property
    def double_clicked(self):
        """
        Readonly attribute: has the item just been double-clicked.
        The returned value is a tuple of len 5 containing the individual test
        mouse buttons (up to 5 buttons)
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.double_clicked

    @property
    def deactivated(self):
        """
        Readonly attribute: has the button just been unpressed
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.prev.active and not(self.state.cur.active)

    @property
    def hovered(self):
        """
        Readonly attribute: Is the mouse inside area
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.hovered

    @property
    def pos_to_viewport(self):
        """
        Readonly attribute:
        Current screen-space position of the top left
        of the item's rectangle. Basically the coordinate relative
        to the top left of the viewport.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build_v(self.state.cur.pos_to_viewport)

    @property
    def pos_to_window(self):
        """
        Readonly attribute:
        Relative position to the window's starting inner
        content area.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build_v(self.state.cur.pos_to_window)

    @property
    def pos_to_parent(self):
        """
        Readonly attribute:
        Relative position to latest non-drawing parent
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build_v(self.state.cur.pos_to_parent)

    @property
    def rect_size(self):
        """
        Readonly attribute: actual (width, height) in pixels of the item on screen
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build_v(self.state.cur.rect_size)

    @property
    def resized(self):
        """
        Readonly attribute: has the item size just changed
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.rect_size.x != self.state.prev.rect_size.x or \
               self.state.cur.rect_size.y != self.state.prev.rect_size.y

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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._no_input

    @no_input.setter
    def no_input(self, bint value):
        cdef unique_lock[recursive_mutex] m
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._capture_mouse

    @capture_mouse.setter
    def capture_mouse(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._capture_mouse = value

    cdef void draw(self,
                   void* drawlist) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
    Enables to insert Draw* Elements inside a window.

    Inside a DrawInWindow elements, the (0, 0) coordinate
    starts at the top left of the DrawWindow and y increases
    when going down.
    The drawing region is clipped by the available width/height
    of the item (set manually, or deduced).

    An invisible button is created to span the entire drawing
    area, which is used to retrieve button states on the area
    (hovering, active, etc). If set, the callback is called when
    the mouse is pressed inside the area with any of the left,
    middle or right button.
    In addition, the use of an invisible button enables the drag
    and drop behaviour proposed by imgui.

    If you intend on dragging elements inside the drawing area,
    you can either implement yourself a hovering test for your
    specific items and use the context's is_mouse_dragging, or
    add invisible buttons on top of the elements you want to
    interact with, and combine the active and mouse dragging
    handlers. Note if you intend to make an element draggable
    that way, you must not make the element source of a Drag
    and Drop, as it impacts the hovering tests.

    Note that Drawing items do not have any hovering/clicked/
    visible/etc tests maintained and thus do not have a callback.
    """
    def __cinit__(self):
        self.can_have_drawing_child = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_active = True
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
        Writable attribute: If True, the entire DrawInWindow area
        will behave like a single button.

        If False (default), clicks and the hovered status
        will be forwarded to the window underneath.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.button

    @button.setter
    def button(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.button = value

    @property
    def frame(self):
        """
        Writable attribute: Whether the item has a frame.
        By default the frame is disabled for DrawInWindow.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.has_frame

    @frame.setter
    def frame(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.has_frame = value

    @property
    def orig_x(self):
        """
        Starting X coordinate inside the item (top-left)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.orig_x

    @orig_x.setter
    def orig_x(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.orig_x = value

    @property
    def orig_y(self):
        """
        Starting Y coordinate inside the item (top-left)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.orig_x

    @orig_y.setter
    def orig_y(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.orig_y = value

    @property
    def scale_x(self):
        """
        X Scaling of items inside the item.

        If set to 1. (default), the scaling corresponds
        to the unit of a pixel (as per global_scale).
        That is, the coordinate of the end of the visible area
        corresponds to item.width
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.scale_x

    @scale_x.setter
    def scale_x(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.scale_x = value

    @property
    def scale_y(self):
        """
        Y Scaling of items inside the item.

        If set to 1. (default), the scaling corresponds
        to the unit of a pixel (as per global_scale).
        That is, the coordinate of end of the visible area
        corresponds to item.height
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.scale_y

    @scale_y.setter
    def scale_y(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.scale_y = value

    @property
    def relative(self):
        """
        Writable attribute: If set, the scaling is relative
        to the item's width and height. That is, the
        coordinate of the end of the visible area
        is (orig_x, orig_y) + (scale_x, scale_y)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.relative_scaling

    @relative.setter
    def relative(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.relative_scaling = value

    @property
    def invert_y(self):
        """
        When set to True, orig_x/orig_y correspond
        to the bottom left of the item, and y
        increases when going up.

        When False, this is the top left, and y
        increases when going down.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.invert_y

    @invert_y.setter
    def invert_y(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.invert_y = value

    cdef bint draw_item(self) noexcept nogil:
        cdef bint no_frame = not(self.has_frame)
        # Remove frames
        if no_frame:
            imgui.PushStyleVar(imgui.ImGuiStyleVar_FrameBorderSize, imgui.ImVec2(0., 0.))
            imgui.PushStyleVar(imgui.ImGuiStyleVar_FramePadding, imgui.ImVec2(0., 0.))
        cdef Vec2 requested_size = self.scaled_requested_size()
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
            scale = <double>self.context.viewport.global_scale if self._dpi_scaling else 1.
            scale_x = self.scale_x * scale
            scale_y = self.scale_y * scale
        self.context.viewport.scales = [scale_x, scale_y]
        self.context.viewport.thickness_multiplier =  <double>self.context.viewport.global_scale if self._dpi_scaling else 1.
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
    def __cinit__(self):
        self._theme_condition_category = ThemeCategories.t_simpleplot
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
        Writable attribute: value corresponding to the minimum value of plot scale
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
        Writable attribute: value corresponding to the maximum value of plot scale
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
    def histogram(self):
        """
        Writable attribute: Whether the data should be plotted as an histogram
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._histogram

    @histogram.setter
    def histogram(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._histogram = value

    @property
    def autoscale(self):
        """
        Writable attribute: Whether scale_min and scale_max should be deduced
        from the data
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._autoscale

    @autoscale.setter
    def autoscale(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._autoscale = value

    @property
    def overlay(self):
        """
        Writable attribute: Overlay text
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._overlay

    @overlay.setter
    def overlay(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._overlay = bytes(str(value), 'utf-8')

    cdef bint draw_item(self) noexcept nogil:
        cdef float[:] data = SharedFloatVect.get(<SharedFloatVect>self._value)
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
                                Vec2ImVec2(self.scaled_requested_size()),
                                sizeof(float))
        else:
            imgui.PlotLines(self._imgui_label.c_str(),
                            &data[0],
                            <int>data.shape[0],
                            0,
                            self._overlay.c_str(),
                            self._scale_min,
                            self._scale_max,
                            Vec2ImVec2(self.scaled_requested_size()),
                            sizeof(float))
        self.update_current_state()
        return False

cdef class Button(uiItem):
    def __cinit__(self):
        self._theme_condition_category = ThemeCategories.t_button
        self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self._direction = imgui.ImGuiDir_Up
        self._small = False
        self._arrow = False
        self._repeat = False

    @property
    def direction(self):
        """
        Writable attribute: Direction of the arrow if any
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return <ButtonDirection>self._direction

    @direction.setter
    def direction(self, ButtonDirection value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if <imgui.ImGuiDir>value < imgui.ImGuiDir_None or <imgui.ImGuiDir>value >= imgui.ImGuiDir_COUNT:
            raise ValueError("Invalid direction {value}")
        self._direction = <imgui.ImGuiDir>value

    @property
    def small(self):
        """
        Writable attribute: Whether to display a small button
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._small

    @small.setter
    def small(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._small = value

    @property
    def arrow(self):
        """
        Writable attribute: Whether to display an arrow.
        Not compatible with small
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._arrow

    @arrow.setter
    def arrow(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._arrow = value

    @property
    def repeat(self):
        """
        Writable attribute: Whether to generate many clicked events
        when the button is held repeatedly, instead of a single.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._repeat

    @repeat.setter
    def repeat(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._repeat = value

    cdef bint draw_item(self) noexcept nogil:
        cdef bint activated
        imgui.PushItemFlag(imgui.ImGuiItemFlags_ButtonRepeat, self._repeat)
        if self._small:
            activated = imgui.SmallButton(self._imgui_label.c_str())
        elif self._arrow:
            activated = imgui.ArrowButton(self._imgui_label.c_str(), <imgui.ImGuiDir>self._direction)
        else:
            activated = imgui.Button(self._imgui_label.c_str(),
                                     Vec2ImVec2(self.scaled_requested_size()))
        imgui.PopItemFlag()
        self.update_current_state()
        SharedBool.set(<SharedBool>self._value, self.state.cur.active) # Unsure. Not in original
        return activated


cdef class Combo(uiItem):
    def __cinit__(self):
        self._theme_condition_category = ThemeCategories.t_combo
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
        Writable attribute: List of text values to select
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return [str(v, encoding='utf-8') for v in self._items]

    @items.setter
    def items(self, value):
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] value_m
        lock_gil_friendly(m, self.mutex)
        self._items.clear()
        if value is None:
            return
        if value is str:
            self._items.push_back(bytes(value, 'utf-8'))
        elif hasattr(value, '__len__'):
            for v in value:
                self._items.push_back(bytes(v, 'utf-8'))
        else:
            raise ValueError(f"Invalid type {type(value)} passed as items. Expected array of strings")
        lock_gil_friendly(value_m, self._value.mutex)
        if self._value._num_attached == 1 and \
           self._value._last_frame_update == -1 and \
           self._items.size() > 0:
            # initialize the value with the first element
            SharedStr.set(<SharedStr>self._value, self._items[0])

    @property
    def height_mode(self):
        """
        Writable attribute: height mode of the combo.
        Supported values are
        "small"
        "regular"
        "large"
        "largest"
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if (self._flags & imgui.ImGuiComboFlags_HeightSmall) != 0:
            return "small"
        elif (self._flags & imgui.ImGuiComboFlags_HeightLargest) != 0:
            return "largest"
        elif (self._flags & imgui.ImGuiComboFlags_HeightLarge) != 0:
            return "large"
        return "regular"

    @height_mode.setter
    def height_mode(self, str value):
        cdef unique_lock[recursive_mutex] m
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
        Writable attribute: Whether to align left
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiComboFlags_PopupAlignLeft) != 0

    @popup_align_left.setter
    def popup_align_left(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiComboFlags_PopupAlignLeft
        if value:
            self._flags |= imgui.ImGuiComboFlags_PopupAlignLeft

    @property
    def no_arrow_button(self):
        """
        Writable attribute: Whether the combo should not display an arrow on top
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiComboFlags_NoArrowButton) != 0

    @no_arrow_button.setter
    def no_arrow_button(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiComboFlags_NoArrowButton
        if value:
            self._flags |= imgui.ImGuiComboFlags_NoArrowButton

    @property
    def no_preview(self):
        """
        Writable attribute: Whether the preview should be disabled
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiComboFlags_NoPreview) != 0

    @no_preview.setter
    def no_preview(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiComboFlags_NoPreview
        if value:
            self._flags |= imgui.ImGuiComboFlags_NoPreview

    @property
    def fit_width(self):
        """
        Writable attribute: Whether the combo should fit available width
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiComboFlags_WidthFitPreview) != 0

    @fit_width.setter
    def fit_width(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiComboFlags_WidthFitPreview
        if value:
            self._flags |= imgui.ImGuiComboFlags_WidthFitPreview

    cdef bint draw_item(self) noexcept nogil:
        cdef bint open
        cdef int32_t i
        cdef string current_value
        SharedStr.get(<SharedStr>self._value, current_value)
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
                                                Vec2ImVec2(self.scaled_requested_size()))
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
                                 Vec2ImVec2(self.scaled_requested_size()))
            imgui.PopID()
            imgui.EndCombo()
        # TODO: rect_size/min/max: with the popup ? Use clipper for rect_max ?
        self.state.cur.edited = changed
        self.state.cur.deactivated_after_edited = self.state.prev.active and changed and not(self.state.cur.active)
        return pressed


cdef class Checkbox(uiItem):
    def __cinit__(self):
        self._theme_condition_category = ThemeCategories.t_checkbox
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
    def __cinit__(self):
        self._theme_condition_category = ThemeCategories.t_slider
        self._format = 1
        self._size = 1
        self._drag = False
        self._drag_speed = 1.
        self._print_format = b"%.3f"
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

    def configure(self, **kwargs):
        # Since some options cancel each other, one
        # must enable them in a specific order
        if "format" in kwargs:
            self.format = kwargs.pop("format")
        if "size" in kwargs:
            self.size = kwargs.pop("size")
        if "logarithmic" in kwargs:
            self.logarithmic = kwargs.pop("logarithmic")
        # baseItem configure will configure the rest.
        return super().configure(**kwargs)

    @property
    def format(self):
        """
        Writable attribute: Format of the slider.
        Must be "int", "float" or "double".
        Note that float here means the 32 bits version.
        The python float corresponds to a double.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._format == 1:
            return "float"
        elif self._format == 0:
            return "int"
        return "double"

    @format.setter
    def format(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef int32_t target_format
        if value == "int":
            target_format = 0
        elif value == "float":
            target_format = 1
        elif value == "double":
            target_format = 2
        else:
            raise ValueError(f"Expected 'int', 'float' or 'double'. Got {value}")
        if target_format == self._format:
            return
        self._format = target_format
        # Allocate a new value of the right type
        previous_value = self.value # Pass though the property to do the conversion for us
        if self._size == 1:
            if target_format == 0:
                self._value = <SharedValue>(SharedInt.__new__(SharedInt, self.context))
            elif target_format == 1:
                self._value = <SharedValue>(SharedFloat.__new__(SharedFloat, self.context))
            else:
                self._value = <SharedValue>(SharedDouble.__new__(SharedDouble, self.context))
        else:
            if target_format == 0:
                self._value = <SharedValue>(SharedInt4.__new__(SharedInt4, self.context))
            elif target_format == 1:
                self._value = <SharedValue>(SharedFloat4.__new__(SharedFloat4, self.context))
            else:
                self._value = <SharedValue>(SharedDouble4.__new__(SharedDouble4, self.context))
        self.value = previous_value # Use property to pass through python for the conversion
        self._print_format = b"%d" if target_format == 0 else b"%.3f"

    @property
    def size(self):
        """
        Writable attribute: Size of the slider.
        Can be 1, 2, 3 or 4.
        When 1 the item's value is held with
        a scalar shared value, else it is held
        with a vector of 4 elements (even for
        size 2 and 3)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._size
        

    @size.setter
    def size(self, int32_t target_size):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if target_size < 0 or target_size > 4:
            raise ValueError(f"Expected 1, 2, 3, or 4 for size. Got {target_size}")
        if self._size == target_size:
            return
        if (self._size > 1 and target_size > 1):
            self._size = target_size
            return
        # Reallocate the internal vector
        previous_value = self.value # Pass though the property to do the conversion for us
        if target_size == 1:
            if self._format == 0:
                self._value = <SharedValue>(SharedInt.__new__(SharedInt, self.context))
            elif self._format == 1:
                self._value = <SharedValue>(SharedFloat.__new__(SharedFloat, self.context))
            else:
                self._value = <SharedValue>(SharedDouble.__new__(SharedDouble, self.context))
            self.value = previous_value[0]
        else:
            if self._format == 0:
                self._value = <SharedValue>(SharedInt4.__new__(SharedInt4, self.context))
            elif self._format == 1:
                self._value = <SharedValue>(SharedFloat4.__new__(SharedFloat4, self.context))
            else:
                self._value = <SharedValue>(SharedDouble4.__new__(SharedDouble4, self.context))
            self.value = (previous_value, 0, 0, 0)
        self._size = target_size

    @property
    def clamped(self):
        """
        Writable attribute: Whether the slider value should be clamped even when keyboard set
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiSliderFlags_AlwaysClamp) != 0

    @clamped.setter
    def clamped(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiSliderFlags_AlwaysClamp
        if value:
            self._flags |= imgui.ImGuiSliderFlags_AlwaysClamp

    @property
    def drag(self):
        """
        Writable attribute: Whether the use a 'drag'
        slider rather than a regular one.
        Incompatible with 'vertical'.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._drag

    @drag.setter
    def drag(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._drag = value
        if value:
            self._vertical = False

    @property
    def logarithmic(self):
        """
        Writable attribute: Make the slider logarithmic.
        Disables round_to_format if enabled
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiSliderFlags_Logarithmic) != 0

    @logarithmic.setter
    def logarithmic(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~(imgui.ImGuiSliderFlags_Logarithmic | imgui.ImGuiSliderFlags_NoRoundToFormat)
        if value:
            self._flags |= (imgui.ImGuiSliderFlags_Logarithmic | imgui.ImGuiSliderFlags_NoRoundToFormat)

    @property
    def min_value(self):
        """
        Writable attribute: Minimum value the slider
        will be clamped to.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._min

    @min_value.setter
    def min_value(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._min = value

    @property
    def max_value(self):
        """
        Writable attribute: Maximum value the slider
        will be clamped to.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._max

    @max_value.setter
    def max_value(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._max = value

    @property
    def no_input(self):
        """
        Writable attribute: Disable Ctrl+Click and Enter key to
        manually set the value
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiSliderFlags_NoInput) != 0

    @no_input.setter
    def no_input(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiSliderFlags_NoInput
        if value:
            self._flags |= imgui.ImGuiSliderFlags_NoInput

    @property
    def print_format(self):
        """
        Writable attribute: format string
        for the value -> string conversion
        for display. If round_to_format is
        enabled, the value is converted
        back and thus appears rounded.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(bytes(self._print_format), encoding="utf-8")

    @print_format.setter
    def print_format(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._print_format = bytes(value, 'utf-8')

    @property
    def round_to_format(self):
        """
        Writable attribute: If set (default),
        the value will not have more digits precision
        than the requested format string for display.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiSliderFlags_NoRoundToFormat) == 0

    @round_to_format.setter
    def round_to_format(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value and (self._flags & imgui.ImGuiSliderFlags_Logarithmic) != 0:
            # Note this is not a limitation from imgui, but they strongly
            # advise not to combine both, and thus we let the user do his
            # own rounding if he really wants to.
            raise ValueError("round_to_format cannot be enabled with logarithmic set")
        self._flags &= ~imgui.ImGuiSliderFlags_NoRoundToFormat
        if not(value):
            self._flags |= imgui.ImGuiSliderFlags_NoRoundToFormat

    @property
    def speed(self):
        """
        Writable attribute: When drag is true,
        this attributes sets the drag speed.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._drag_speed

    @speed.setter
    def speed(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._drag_speed = value

    @property
    def vertical(self):
        """
        Writable attribute: Whether the use a vertical
        slider. Only sliders of size 1 and drag False
        are supported.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._vertical

    @vertical.setter
    def vertical(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._size != 1:
            return
        self._drag = False
        self._vertical = value
        if value:
            self._drag = False

    cdef bint draw_item(self) noexcept nogil:
        cdef imgui.ImGuiSliderFlags flags = self._flags
        if not(self._enabled):
            flags |= imgui.ImGuiSliderFlags_NoInput
        cdef imgui.ImGuiDataType type
        cdef int32_t value_int
        cdef float value_float
        cdef double value_double
        cdef int32_t[4] value_int4
        cdef float[4] value_float4
        cdef double[4] value_double4
        cdef void *data
        cdef void *data_min
        cdef void *data_max
        cdef bint modified
        cdef int32_t imin, imax
        cdef float fmin, fmax
        cdef double dmin, dmax
        # Prepare data type
        if self._format == 0:
            type = imgui.ImGuiDataType_S32
            imin = <int>self._min
            imax = <int>self._max
            data_min = &imin
            data_max = &imax
        elif self._format == 1:
            type = imgui.ImGuiDataType_Float
            fmin = <float>self._min
            fmax = <float>self._max
            data_min = &fmin
            data_max = &fmax
        else:
            type = imgui.ImGuiDataType_Double
            dmin = <double>self._min
            dmax = <double>self._max
            data_min = &dmin
            data_max = &dmax

        # Read the value
        if self._format == 0:
            if self._size == 1:
                value_int = SharedInt.get(<SharedInt>self._value)
                data = &value_int
            else:
                SharedInt4.get(<SharedInt4>self._value, value_int4)
                data = &value_int4
        elif self._format == 1:
            if self._size == 1:
                value_float = SharedFloat.get(<SharedFloat>self._value)
                data = &value_float
            else:
                SharedFloat4.get(<SharedFloat4>self._value, value_float4)
                data = &value_float4
        else:
            if self._size == 1:
                value_double = SharedDouble.get(<SharedDouble>self._value)
                data = &value_double
            else:
                SharedDouble4.get(<SharedDouble4>self._value, value_double4)
                data = &value_double4

        # Draw
        if self._drag:
            if self._size == 1:
                modified = imgui.DragScalar(self._imgui_label.c_str(),
                                            type,
                                            data,
                                            self._drag_speed,
                                            data_min,
                                            data_max,
                                            self._print_format.c_str(),
                                            flags)
            else:
                modified = imgui.DragScalarN(self._imgui_label.c_str(),
                                             type,
                                             data,
                                             self._size,
                                             self._drag_speed,
                                             data_min,
                                             data_max,
                                             self._print_format.c_str(),
                                             flags)
        else:
            if self._size == 1:
                if self._vertical:
                    modified = imgui.VSliderScalar(self._imgui_label.c_str(),
                                                   GetDefaultItemSize(Vec2ImVec2(self.scaled_requested_size())),
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
            else:
                modified = imgui.SliderScalarN(self._imgui_label.c_str(),
                                               type,
                                               data,
                                               self._size,
                                               data_min,
                                               data_max,
                                               self._print_format.c_str(),
                                               flags)
		
        # Write the value
        if self._enabled:
            if self._format == 0:
                if self._size == 1:
                    SharedInt.set(<SharedInt>self._value, value_int)
                else:
                    SharedInt4.set(<SharedInt4>self._value, value_int4)
            elif self._format == 1:
                if self._size == 1:
                    SharedFloat.set(<SharedFloat>self._value, value_float)
                else:
                    SharedFloat4.set(<SharedFloat4>self._value, value_float4)
            else:
                if self._size == 1:
                    SharedDouble.set(<SharedDouble>self._value, value_double)
                else:
                    SharedDouble4.set(<SharedDouble4>self._value, value_double4)
        self.update_current_state()
        return modified


cdef class ListBox(uiItem):
    def __cinit__(self):
        self._theme_condition_category = ThemeCategories.t_listbox
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
        Writable attribute: List of text values to select
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return [str(v, encoding='utf-8') for v in self._items]

    @items.setter
    def items(self, value):
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] value_m
        lock_gil_friendly(m, self.mutex)
        self._items.clear()
        if value is None:
            return
        if value is str:
            self._items.push_back(bytes(value, 'utf-8'))
        elif hasattr(value, '__len__'):
            for v in value:
                self._items.push_back(bytes(v, 'utf-8'))
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
        Writable attribute: Number of items
        shown when the menu is opened
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._num_items_shown_when_open

    @num_items_shown_when_open.setter
    def num_items_shown_when_open(self, int32_t value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._num_items_shown_when_open = value

    cdef bint draw_item(self) noexcept nogil:
        # TODO: Merge with ComboBox
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef bint visible
        cdef int32_t i
        cdef string current_value
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
                                                Vec2ImVec2(self.scaled_requested_size()))
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
                                 Vec2ImVec2(self.scaled_requested_size()))
            imgui.PopID()
            imgui.EndListBox()
        # TODO: rect_size/min/max: with the popup ? Use clipper for rect_max ?
        self.state.cur.edited = changed
        #self.state.cur.deactivated_after_edited = self.state.cur.deactivated and changed -> TODO Unsure. Isn't it rather focus loss ?
        return pressed


cdef class RadioButton(uiItem):
    def __cinit__(self):
        self._theme_condition_category = ThemeCategories.t_radiobutton
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return [str(v, encoding='utf-8') for v in self._items]

    @items.setter
    def items(self, value):
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] value_m
        lock_gil_friendly(m, self.mutex)
        self._items.clear()
        if value is None:
            return
        if value is str:
            self._items.push_back(bytes(value, 'utf-8'))
        elif hasattr(value, '__len__'):
            for v in value:
                self._items.push_back(bytes(v, 'utf-8'))
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._horizontal

    @horizontal.setter
    def horizontal(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._horizontal = value

    cdef bint draw_item(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef bint open
        cdef int32_t i
        cdef string current_value
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
    def __cinit__(self):
        self._theme_condition_category = ThemeCategories.t_inputtext
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
        if 'max_characters' in kwargs:
            self.max_characters = kwargs.pop('max_characters')
        return super().configure(**kwargs)

    @property
    def hint(self):
        """
        Writable attribute: text hint.
        Doesn't work with multiline.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(self._hint, encoding='utf-8')

    @hint.setter
    def hint(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._hint = bytes(value, 'utf-8')
        if len(value) > 0:
            self.multiline = False

    @property
    def multiline(self):
        """
        Writable attribute: multiline text input.
        Doesn't work with non-empty hint.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._multiline

    @multiline.setter
    def multiline(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._multiline = value
        if value:
            self._hint = b""

    @property
    def max_characters(self):
        """
        Writable attribute: Maximal number of characters that can be written
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._max_characters

    @max_characters.setter
    def max_characters(self, int32_t value):
        cdef unique_lock[recursive_mutex] m
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
        Writable attribute: Allow 0123456789.+-
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_CharsDecimal) != 0

    @decimal.setter
    def decimal(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_CharsDecimal
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_CharsDecimal

    @property
    def hexadecimal(self):
        """
        Writable attribute:  Allow 0123456789ABCDEFabcdef
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_CharsHexadecimal) != 0

    @hexadecimal.setter
    def hexadecimal(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_CharsHexadecimal
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_CharsHexadecimal

    @property
    def scientific(self):
        """
        Writable attribute: Allow 0123456789.+-*/eE
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_CharsScientific) != 0

    @scientific.setter
    def scientific(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_CharsScientific
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_CharsScientific

    @property
    def uppercase(self):
        """
        Writable attribute: Turn a..z into A..Z
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_CharsUppercase) != 0

    @uppercase.setter
    def uppercase(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_CharsUppercase
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_CharsUppercase

    @property
    def no_spaces(self):
        """
        Writable attribute: Filter out spaces, tabs
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_CharsNoBlank) != 0

    @no_spaces.setter
    def no_spaces(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_CharsNoBlank
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_CharsNoBlank

    @property
    def tab_input(self):
        """
        Writable attribute: Pressing TAB input a '\t' character into the text field
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_AllowTabInput) != 0

    @tab_input.setter
    def tab_input(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_AllowTabInput
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_AllowTabInput

    @property
    def on_enter(self):
        """
        Writable attribute: Callback called everytime Enter is pressed,
        not just when the value is modified.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_EnterReturnsTrue) != 0

    @on_enter.setter
    def on_enter(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_EnterReturnsTrue
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_EnterReturnsTrue

    @property
    def escape_clears_all(self):
        """
        Writable attribute: Escape key clears content if not empty,
        and deactivate otherwise
        (contrast to default behavior of Escape to revert)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_EscapeClearsAll) != 0

    @escape_clears_all.setter
    def escape_clears_all(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_EscapeClearsAll
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_EscapeClearsAll

    @property
    def ctrl_enter_for_new_line(self):
        """
        Writable attribute: In multi-line mode, validate with Enter,
        add new line with Ctrl+Enter
        (default is opposite: validate with Ctrl+Enter, add line with Enter).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_CtrlEnterForNewLine) != 0

    @ctrl_enter_for_new_line.setter
    def ctrl_enter_for_new_line(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_CtrlEnterForNewLine
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_CtrlEnterForNewLine

    @property
    def readonly(self):
        """
        Writable attribute: Read-only mode
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_ReadOnly) != 0

    @readonly.setter
    def readonly(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_ReadOnly
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_ReadOnly

    @property
    def password(self):
        """
        Writable attribute: Password mode, display all characters as '*', disable copy
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_Password) != 0

    @password.setter
    def password(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_Password
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_Password

    @property
    def always_overwrite(self):
        """
        Writable attribute: Overwrite mode
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_AlwaysOverwrite) != 0

    @always_overwrite.setter
    def always_overwrite(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_AlwaysOverwrite
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_AlwaysOverwrite

    @property
    def auto_select_all(self):
        """
        Writable attribute: Select entire text when first taking mouse focus
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_AutoSelectAll) != 0

    @auto_select_all.setter
    def auto_select_all(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_AutoSelectAll
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_AutoSelectAll

    @property
    def no_horizontal_scroll(self):
        """
        Writable attribute: Disable following the scroll horizontally
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_NoHorizontalScroll) != 0

    @no_horizontal_scroll.setter
    def no_horizontal_scroll(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_NoHorizontalScroll
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_NoHorizontalScroll

    @property
    def no_undo_redo(self):
        """
        Writable attribute: Disable undo/redo.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_NoUndoRedo) != 0

    @no_undo_redo.setter
    def no_undo_redo(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_NoUndoRedo
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_NoUndoRedo

    cdef bint draw_item(self) noexcept nogil:
        cdef string current_value
        cdef int32_t size
        cdef imgui.ImGuiInputTextFlags flags = self._flags
        
        # Get current value from source if needed
        SharedStr.get(<SharedStr>self._value, current_value)
        cdef bint need_update = (<SharedStr>self._value)._last_frame_change >= self._last_frame_update 

        if need_update:
            size = min(current_value.size(), self._max_characters)
            # Copy value to buffer
            memcpy(self._buffer, current_value.data(), size)
            self._buffer[size] = 0
            self._last_frame_update = (<SharedStr>self._value)._last_frame_update

        cdef bint changed = False
        if not(self._enabled):
            flags |= imgui.ImGuiInputTextFlags_ReadOnly

        if self._multiline:
            changed = imgui.InputTextMultiline(
                self._imgui_label.c_str(),
                self._buffer,
                self._max_characters+1,
                Vec2ImVec2(self.scaled_requested_size()),
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
            current_value.assign(<char*>self._buffer)
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

cdef inline void clamp4(clamp_types[4] &value, double lower, double upper) noexcept nogil:
    if lower != -INFINITY:
        value[0] = <clamp_types>max(<double>value[0], lower)
        value[1] = <clamp_types>max(<double>value[1], lower)
        value[2] = <clamp_types>max(<double>value[2], lower)
        value[3] = <clamp_types>max(<double>value[3], lower)
    if upper != INFINITY:
        value[0] = <clamp_types>min(<double>value[0], upper)
        value[1] = <clamp_types>min(<double>value[1], upper)
        value[2] = <clamp_types>min(<double>value[2], upper)
        value[3] = <clamp_types>min(<double>value[3], upper)

cdef class InputValue(uiItem):
    def __cinit__(self):
        self._theme_condition_category = ThemeCategories.t_inputvalue
        self._format = 1
        self._size = 1
        self._print_format = b"%.3f"
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

    def configure(self, **kwargs):
        # Since some options cancel each other, one
        # must enable them in a specific order
        if "format" in kwargs:
            self.format = kwargs.pop("format")
        if "size" in kwargs:
            self.size = kwargs.pop("size")
        # baseItem configure will configure the rest.
        return super().configure(**kwargs)

    @property
    def format(self):
        """
        Writable attribute: Format of the slider.
        Must be "int", "float" or "double".
        Note that float here means the 32 bits version.
        The python float corresponds to a double.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._format == 1:
            return "float"
        elif self._format == 0:
            return "int"
        return "double"

    @format.setter
    def format(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef int32_t target_format
        if value == "int":
            target_format = 0
        elif value == "float":
            target_format = 1
        elif value == "double":
            target_format = 2
        else:
            raise ValueError(f"Expected 'int', 'float' or 'double'. Got {value}")
        if target_format == self._format:
            return
        self._format = target_format
        # Allocate a new value of the right type
        previous_value = self.value # Pass though the property to do the conversion for us
        if self._size == 1:
            if target_format == 0:
                self._value = <SharedValue>(SharedInt.__new__(SharedInt, self.context))
            elif target_format == 0:
                self._value = <SharedValue>(SharedFloat.__new__(SharedFloat, self.context))
            else:
                self._value = <SharedValue>(SharedDouble.__new__(SharedDouble, self.context))
        else:
            if target_format == 0:
                self._value = <SharedValue>(SharedInt4.__new__(SharedInt4, self.context))
            elif target_format == 0:
                self._value = <SharedValue>(SharedFloat4.__new__(SharedFloat4, self.context))
            else:
                self._value = <SharedValue>(SharedDouble4.__new__(SharedDouble4, self.context))
        self.value = previous_value # Use property to pass through python for the conversion
        self._print_format = b"%d" if target_format == 0 else b"%.3f"

    @property
    def size(self):
        """
        Writable attribute: Size of the slider.
        Can be 1, 2, 3 or 4.
        When 1 the item's value is held with
        a scalar shared value, else it is held
        with a vector of 4 elements (even for
        size 2 and 3)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._size
        

    @size.setter
    def size(self, int32_t target_size):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if target_size < 0 or target_size > 4:
            raise ValueError(f"Expected 1, 2, 3, or 4 for size. Got {target_size}")
        if self._size == target_size:
            return
        if (self._size > 1 and target_size > 1):
            self._size = target_size
            return
        # Reallocate the internal vector
        previous_value = self.value # Pass though the property to do the conversion for us
        if target_size == 1:
            if self._format == 0:
                self._value = <SharedValue>(SharedInt.__new__(SharedInt, self.context))
            elif self._format == 1:
                self._value = <SharedValue>(SharedFloat.__new__(SharedFloat, self.context))
            else:
                self._value = <SharedValue>(SharedDouble.__new__(SharedDouble, self.context))
            self.value = previous_value[0]
        else:
            if self._format == 0:
                self._value = <SharedValue>(SharedInt4.__new__(SharedInt4, self.context))
            elif self._format == 1:
                self._value = <SharedValue>(SharedFloat4.__new__(SharedFloat4, self.context))
            else:
                self._value = <SharedValue>(SharedDouble4.__new__(SharedDouble4, self.context))
            self.value = (previous_value, 0, 0, 0)
        self._size = target_size

    @property
    def step(self):
        """
        Writable attribute: 
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._step

    @step.setter
    def step(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._step = value

    @property
    def step_fast(self):
        """
        Writable attribute: 
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._step_fast

    @step_fast.setter
    def step_fast(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._step_fast = value

    @property
    def min_value(self):
        """
        Writable attribute: Minimum value the input
        will be clamped to.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._min

    @min_value.setter
    def min_value(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._min = value

    @property
    def max_value(self):
        """
        Writable attribute: Maximum value the input
        will be clamped to.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._max

    @max_value.setter
    def max_value(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._max = value

    @property
    def print_format(self):
        """
        Writable attribute: format string
        for the value -> string conversion
        for display. If round_to_format is
        enabled, the value is converted
        back and thus appears rounded.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(bytes(self._print_format), encoding="utf-8")

    @print_format.setter
    def print_format(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._print_format = bytes(value, 'utf-8')

    @property
    def decimal(self):
        """
        Writable attribute: Allow 0123456789.+-
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_CharsDecimal) != 0

    @decimal.setter
    def decimal(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_CharsDecimal
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_CharsDecimal

    @property
    def hexadecimal(self):
        """
        Writable attribute:  Allow 0123456789ABCDEFabcdef
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_CharsHexadecimal) != 0

    @hexadecimal.setter
    def hexadecimal(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_CharsHexadecimal
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_CharsHexadecimal

    @property
    def scientific(self):
        """
        Writable attribute: Allow 0123456789.+-*/eE
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_CharsScientific) != 0

    @scientific.setter
    def scientific(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_CharsScientific
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_CharsScientific

    @property
    def on_enter(self):
        """
        Writable attribute: Callback called everytime Enter is pressed,
        not just when the value is modified.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_EnterReturnsTrue) != 0

    @on_enter.setter
    def on_enter(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_EnterReturnsTrue
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_EnterReturnsTrue

    @property
    def escape_clears_all(self):
        """
        Writable attribute: Escape key clears content if not empty,
        and deactivate otherwise
        (contrast to default behavior of Escape to revert)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_EscapeClearsAll) != 0

    @escape_clears_all.setter
    def escape_clears_all(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_EscapeClearsAll
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_EscapeClearsAll

    @property
    def readonly(self):
        """
        Writable attribute: Read-only mode
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_ReadOnly) != 0

    @readonly.setter
    def readonly(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_ReadOnly
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_ReadOnly

    @property
    def password(self):
        """
        Writable attribute: Password mode, display all characters as '*', disable copy
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_Password) != 0

    @password.setter
    def password(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_Password
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_Password

    @property
    def always_overwrite(self):
        """
        Writable attribute: Overwrite mode
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_AlwaysOverwrite) != 0

    @always_overwrite.setter
    def always_overwrite(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_AlwaysOverwrite
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_AlwaysOverwrite

    @property
    def auto_select_all(self):
        """
        Writable attribute: Select entire text when first taking mouse focus
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_AutoSelectAll) != 0

    @auto_select_all.setter
    def auto_select_all(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_AutoSelectAll
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_AutoSelectAll

    @property
    def empty_as_zero(self):
        """
        Writable attribute: parse empty string as zero value
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_ParseEmptyRefVal) != 0

    @empty_as_zero.setter
    def empty_as_zero(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_ParseEmptyRefVal
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_ParseEmptyRefVal

    @property
    def empty_if_zero(self):
        """
        Writable attribute: when value is zero, do not display it
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_DisplayEmptyRefVal) != 0

    @empty_if_zero.setter
    def empty_if_zero(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_DisplayEmptyRefVal
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_DisplayEmptyRefVal

    @property
    def no_horizontal_scroll(self):
        """
        Writable attribute: Disable following the scroll horizontally
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_NoHorizontalScroll) != 0

    @no_horizontal_scroll.setter
    def no_horizontal_scroll(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_NoHorizontalScroll
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_NoHorizontalScroll

    @property
    def no_undo_redo(self):
        """
        Writable attribute: Disable undo/redo.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiInputTextFlags_NoUndoRedo) != 0

    @no_undo_redo.setter
    def no_undo_redo(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiInputTextFlags_NoUndoRedo
        if value:
            self._flags |= imgui.ImGuiInputTextFlags_NoUndoRedo

    cdef bint draw_item(self) noexcept nogil:
        cdef imgui.ImGuiInputTextFlags flags = self._flags
        if not(self._enabled):
            flags |= imgui.ImGuiInputTextFlags_ReadOnly
        cdef imgui.ImGuiDataType type
        cdef int32_t value_int
        cdef float value_float
        cdef double value_double
        cdef int32_t[4] value_int4
        cdef float[4] value_float4
        cdef double[4] value_double4
        cdef void *data
        cdef void *data_step = NULL
        cdef void *data_step_fast = NULL
        cdef bint modified
        cdef int32_t istep, istep_fast
        cdef float fstep, fstep_fast
        cdef double dstep, dstep_fast
        # Prepare data type
        if self._format == 0:
            type = imgui.ImGuiDataType_S32
            istep = <int>self._step
            istep_fast = <int>self._step_fast
            if istep > 0:
                data_step = &istep
            if istep_fast > 0:
                data_step_fast = &istep_fast
        elif self._format == 1:
            type = imgui.ImGuiDataType_Float
            fstep = <float>self._step
            fstep_fast = <float>self._step_fast
            if fstep > 0:
                data_step = &fstep
            if fstep_fast > 0:
                data_step_fast = &fstep_fast
        else:
            type = imgui.ImGuiDataType_Double
            dstep = <double>self._step
            dstep_fast = <double>self._step_fast
            if dstep > 0:
                data_step = &dstep
            if dstep_fast > 0:
                data_step_fast = &dstep_fast

        # Read the value
        if self._format == 0:
            if self._size == 1:
                value_int = SharedInt.get(<SharedInt>self._value)
                data = &value_int
            else:
                SharedInt4.get(<SharedInt4>self._value, value_int4)
                data = &value_int4
        elif self._format == 1:
            if self._size == 1:
                value_float = SharedFloat.get(<SharedFloat>self._value)
                data = &value_float
            else:
                SharedFloat4.get(<SharedFloat4>self._value, value_float4)
                data = &value_float4
        else:
            if self._size == 1:
                value_double = SharedDouble.get(<SharedDouble>self._value)
                data = &value_double
            else:
                SharedDouble4.get(<SharedDouble4>self._value, value_double4)
                data = &value_double4

        # Draw
        if self._size == 1:
            modified = imgui.InputScalar(self._imgui_label.c_str(),
                                         type,
                                         data,
                                         data_step,
                                         data_step_fast,
                                         self._print_format.c_str(),
                                         flags)
        else:
            modified = imgui.InputScalarN(self._imgui_label.c_str(),
                                          type,
                                          data,
                                          self._size,
                                          data_step,
                                          data_step_fast,
                                          self._print_format.c_str(),
                                          flags)

        # Clamp and write the value
        if self._enabled:
            if self._format == 0:
                if self._size == 1:
                    if modified:
                        clamp1[int32_t](value_int, self._min, self._max)
                    SharedInt.set(<SharedInt>self._value, value_int)
                else:
                    if modified:
                        clamp4[int32_t](value_int4, self._min, self._max)
                    SharedInt4.set(<SharedInt4>self._value, value_int4)
            elif self._format == 1:
                if self._size == 1:
                    if modified:
                        clamp1[float](value_float, self._min, self._max)
                    SharedFloat.set(<SharedFloat>self._value, value_float)
                else:
                    if modified:
                        clamp4[float](value_float4, self._min, self._max)
                    SharedFloat4.set(<SharedFloat4>self._value, value_float4)
            else:
                if self._size == 1:
                    if modified:
                        clamp1[double](value_double, self._min, self._max)
                    SharedDouble.set(<SharedDouble>self._value, value_double)
                else:
                    if modified:
                        clamp4[double](value_double4, self._min, self._max)
                    SharedDouble4.set(<SharedDouble4>self._value, value_double4)
            modified = modified and (self._value._last_frame_update == self._value._last_frame_change)
        self.update_current_state()
        return modified


cdef class Text(uiItem):
    def __cinit__(self):
        self._theme_condition_category = ThemeCategories.t_text
        self._color = 0 # invisible
        self._wrap = -1
        self._bullet = False
        self._show_label = False
        self._value = <SharedValue>(SharedStr.__new__(SharedStr, self.context))
        self.state.cap.can_be_active = True # unsure
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True

    @property
    def color(self):
        """
        Writable attribute: text color.
        If set to 0 (default), that is
        full transparent text, use the
        default value given by the style
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return <int>self._color

    @color.setter
    def color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)

    @property
    def label(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        """
        Writable attribute: label assigned to the item.
        Used for text fields, window titles, etc
        """
        return self._user_label
    @label.setter
    def label(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._user_label = ""
        else:
            self._user_label = value
        # uuid is not used for text, and we don't want to
        # add it when we show the label, thus why we override
        # the label property here.
        self._imgui_label = bytes(self._user_label, 'utf-8')

    @property
    def wrap(self):
        """
        Writable attribute: wrap width in pixels
        -1 for no wrapping
        The width is multiplied by the global scale
        unless the no_scaling option is set.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return <int>self._wrap

    @wrap.setter
    def wrap(self, int32_t value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._wrap = value

    @property
    def bullet(self):
        """
        Writable attribute: Whether to add a bullet
        before the text
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._bullet

    @bullet.setter
    def bullet(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._bullet = value

    @property
    def show_label(self):
        """
        Writable attribute: Whether to display the
        label next to the text stored in value
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._show_label

    @show_label.setter
    def show_label(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._show_label = value

    cdef bint draw_item(self) noexcept nogil:
        imgui.AlignTextToFramePadding()
        if self._color > 0:
            imgui.PushStyleColor(imgui.ImGuiCol_Text, self._color)
        if self._wrap == 0:
            imgui.PushTextWrapPos(0.)
        elif self._wrap > 0:
            imgui.PushTextWrapPos(imgui.GetCursorPosX() + <float>self._wrap * (self.context.viewport.global_scale if self._dpi_scaling else 1.))
        if self._show_label or self._bullet:
            imgui.BeginGroup()
        if self._bullet:
            imgui.Bullet()

        cdef string current_value
        SharedStr.get(<SharedStr>self._value, current_value)

        imgui.TextUnformatted(current_value.c_str(), current_value.c_str()+current_value.size())

        if self._wrap >= 0:
            imgui.PopTextWrapPos()
        if self._color > 0:
            imgui.PopStyleColor(1)

        if self._show_label:
            imgui.SameLine(0., -1.)
            imgui.TextUnformatted(self._imgui_label.c_str(), NULL)
        if self._show_label or self._bullet:
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
    A text item that displays a SharedValue.
    assign the shareable_value property of another item
    to the shareable_value property of this item in order
    to display it.
    Unlike other items, this items accepts shareable_value of any type (except text).
    Use Text for SharedStr.
    """
    def __cinit__(self):
        self._theme_condition_category = ThemeCategories.t_text
        self._print_format = b"%.3f"
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
               isinstance(value, SharedFloatVect)):
            raise ValueError(f"Expected a shareable value of type SharedBool, SharedInt, SharedFloat, SharedDouble, SharedColor, SharedInt4, SharedFloat4, SharedDouble4 or SharedColor. Received {type(value)}")
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
        elif isinstance(value, SharedFloatVect):
            self._type = 8
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

        One exception of SharedFloatVect, as the size is not known.
        In this case the print_format is applied separately to each value.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(bytes(self._print_format), encoding="utf-8")

    @print_format.setter
    def print_format(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._print_format = bytes(value, 'utf-8')

    cdef bint draw_item(self) noexcept nogil:
        cdef bool value_bool
        cdef int32_t value_int
        cdef float value_float
        cdef double value_double
        cdef Vec4 value_color
        cdef int32_t[4] value_int4
        cdef float[4] value_float4
        cdef double[4] value_double4
        cdef float[:] value_vect
        cdef int32_t i
        if self._type == 0:
            value_bool = SharedBool.get(<SharedBool>self._value)
            imgui.Text(self._print_format.c_str(), value_bool)
        elif self._type == 1:
            value_int = SharedInt.get(<SharedInt>self._value)
            imgui.Text(self._print_format.c_str(), value_int)
        elif self._type == 2:
            value_float = SharedFloat.get(<SharedFloat>self._value)
            imgui.Text(self._print_format.c_str(), value_float)
        elif self._type == 3:
            value_double = SharedDouble.get(<SharedDouble>self._value)
            imgui.Text(self._print_format.c_str(), value_double)
        elif self._type == 4:
            value_color = SharedColor.getF4(<SharedColor>self._value)
            imgui.Text(self._print_format.c_str(), 
                       value_color.x, value_color.y, 
                       value_color.z, value_color.w)
        elif self._type == 5:
            SharedInt4.get(<SharedInt4>self._value, value_int4)
            imgui.Text(self._print_format.c_str(),
                       value_int4[0], value_int4[1],
                       value_int4[2], value_int4[3])
        elif self._type == 6:
            SharedFloat4.get(<SharedFloat4>self._value, value_float4)
            imgui.Text(self._print_format.c_str(),
                       value_float4[0], value_float4[1],
                       value_float4[2], value_float4[3])
        elif self._type == 7:
            SharedDouble4.get(<SharedDouble4>self._value, value_double4)
            imgui.Text(self._print_format.c_str(),
                       value_double4[0], value_double4[1],
                       value_double4[2], value_double4[3])
        elif self._type == 8:
            value_vect = SharedFloatVect.get(<SharedFloatVect>self._value)
            for i in range(value_vect.shape[0]):
                imgui.Text(self._print_format.c_str(), value_vect[i])

        self.update_current_state()
        return False

cdef class Selectable(uiItem):
    def __cinit__(self):
        self._theme_condition_category = ThemeCategories.t_selectable
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
        Writable attribute: Clicking this doesn't close parent popup window
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiSelectableFlags_NoAutoClosePopups) != 0

    @disable_popup_close.setter
    def disable_popup_close(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiSelectableFlags_NoAutoClosePopups
        if value:
            self._flags |= imgui.ImGuiSelectableFlags_NoAutoClosePopups

    @property
    def span_columns(self):
        """
        Writable attribute: Frame will span all columns of its container table (text will still fit in current column)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiSelectableFlags_SpanAllColumns) != 0

    @span_columns.setter
    def span_columns(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiSelectableFlags_SpanAllColumns
        if value:
            self._flags |= imgui.ImGuiSelectableFlags_SpanAllColumns

    @property
    def on_double_click(self):
        """
        Writable attribute: call callbacks on double clicks too
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiSelectableFlags_AllowDoubleClick) != 0

    @on_double_click.setter
    def on_double_click(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiSelectableFlags_AllowDoubleClick
        if value:
            self._flags |= imgui.ImGuiSelectableFlags_AllowDoubleClick

    @property
    def highlighted(self):
        """
        Writable attribute: highlighted as if hovered
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiSelectableFlags_Highlight) != 0

    @highlighted.setter
    def highlighted(self, bint value):
        cdef unique_lock[recursive_mutex] m
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
                                             Vec2ImVec2(self.scaled_requested_size()))
        if self._enabled:
            SharedBool.set(<SharedBool>self._value, checked)
        self.update_current_state()
        return changed


cdef class MenuItem(uiItem):
    def __cinit__(self):
        self._theme_condition_category = ThemeCategories.t_menuitem
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
        Writable attribute:
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._check

    @check.setter
    def check(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._check = value

    @property
    def shortcut(self):
        """
        Writable attribute:
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(self._shortcut, encoding='utf-8')

    @shortcut.setter
    def shortcut(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._shortcut = bytes(value, 'utf-8')

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
    def __cinit__(self):
        self._theme_condition_category = ThemeCategories.t_progressbar
        self._value = <SharedValue>(SharedFloat.__new__(SharedFloat, self.context))
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True

    @property
    def overlay(self):
        """
        Writable attribute:
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(self._overlay, encoding='utf-8')

    @overlay.setter
    def overlay(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._overlay = bytes(value, 'utf-8')

    cdef bint draw_item(self) noexcept nogil:
        cdef float current_value = SharedFloat.get(<SharedFloat>self._value)
        cdef const char *overlay_text = self._overlay.c_str()
        imgui.PushID(self.uuid)
        imgui.ProgressBar(current_value,
                          Vec2ImVec2(self.scaled_requested_size()),
                          <const char *>NULL if self._overlay.size() == 0 else overlay_text)
        imgui.PopID()
        self.update_current_state()
        return False

cdef class Image(uiItem):
    def __cinit__(self):
        self._theme_condition_category = ThemeCategories.t_image
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self._uv = [0., 0., 1., 1.]
        self._border_color = 0
        self._color_multiplier = 4294967295

    @property
    def texture(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._texture
    @texture.setter
    def texture(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(isinstance(value, Texture)):
            raise TypeError("texture must be a Texture")
        self._texture = value
    @property
    def uv(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._uv)
    @uv.setter
    def uv(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_vec4[float](self._uv, value)
    @property
    def color_multiplier(self):
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
    def border_color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] border_color
        unparse_color(border_color, self._border_color)
        return list(border_color)
    @border_color.setter
    def border_color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._border_color = parse_color(value)

    cdef bint draw_item(self) noexcept nogil:
        if self._texture is None:
            return False
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self._texture.mutex)
        if self._texture.allocated_texture == NULL:
            return False
        cdef Vec2 size = self.scaled_requested_size()
        if size.x == 0.:
            size.x = self._texture.width * (self.context.viewport.global_scale if self._dpi_scaling else 1.)
        if size.y == 0.:
            size.y = self._texture.height * (self.context.viewport.global_scale if self._dpi_scaling else 1.)

        imgui.PushID(self.uuid)
        imgui.Image(<imgui.ImTextureID>self._texture.allocated_texture,
                    Vec2ImVec2(size),
                    imgui.ImVec2(self._uv[0], self._uv[1]),
                    imgui.ImVec2(self._uv[2], self._uv[3]),
                    imgui.ColorConvertU32ToFloat4(self._color_multiplier),
                    imgui.ColorConvertU32ToFloat4(self._border_color))
        imgui.PopID()
        self.update_current_state()
        return False


cdef class ImageButton(uiItem):
    def __cinit__(self):
        self._theme_condition_category = ThemeCategories.t_imagebutton
        self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self._background_color = 0
        self._color_multiplier = 4294967295
        self._frame_padding = -1
        self._uv = [0., 0., 1., 1.]

    @property
    def texture(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._texture
    @texture.setter
    def texture(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(isinstance(value, Texture)):
            raise TypeError("texture must be a Texture")
        self._texture = value
    @property
    def frame_padding(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._frame_padding
    @frame_padding.setter
    def frame_padding(self, int32_t value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._frame_padding = value
    @property
    def uv(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._uv)
    @uv.setter
    def uv(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_vec4[float](self._uv, value)
    @property
    def color_multiplier(self):
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
    def background_color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] background_color
        unparse_color(background_color, self._background_color)
        return list(background_color)
    @background_color.setter
    def background_color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._background_color = parse_color(value)

    cdef bint draw_item(self) noexcept nogil:
        if self._texture is None:
            return False
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self._texture.mutex)
        if self._texture.allocated_texture == NULL:
            return False
        cdef Vec2 size = self.scaled_requested_size()
        if size.x == 0.:
            size.x = self._texture.width * (self.context.viewport.global_scale if self._dpi_scaling else 1.)
        if size.y == 0.:
            size.y = self._texture.height * (self.context.viewport.global_scale if self._dpi_scaling else 1.)

        imgui.PushID(self.uuid)
        if self._frame_padding >= 0:
            imgui.PushStyleVar(imgui.ImGuiStyleVar_FramePadding,
                               imgui.ImVec2(<float>self._frame_padding,
                                            <float>self._frame_padding))
        cdef bint activated
        activated = imgui.ImageButton(self._imgui_label.c_str(),
                                      <imgui.ImTextureID>self._texture.allocated_texture,
                                      Vec2ImVec2(size),
                                      imgui.ImVec2(self._uv[0], self._uv[1]),
                                      imgui.ImVec2(self._uv[2], self._uv[3]),
                                      imgui.ColorConvertU32ToFloat4(self._background_color),
                                      imgui.ColorConvertU32ToFloat4(self._color_multiplier))
        if self._frame_padding >= 0:
            imgui.PopStyleVar(1)
        imgui.PopID()
        self.update_current_state()
        return activated

cdef class Separator(uiItem):
    def __cinit__(self):
        return
    # TODO: is label override really needed ?
    @property
    def label(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        """
        Writable attribute: label assigned to the item.
        Used for text fields, window titles, etc
        """
        return self._user_label
    @label.setter
    def label(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._user_label = ""
        else:
            self._user_label = value
        # uuid is not used for text, and we don't want to
        # add it when we show the label, thus why we override
        # the label property here.
        self._imgui_label = bytes(self._user_label, 'utf-8')

    cdef bint draw_item(self) noexcept nogil:
        if self._user_label is None:
            imgui.Separator()
        else:
            imgui.SeparatorText(self._imgui_label.c_str())
        self.state.cur.rect_size = ImVec2Vec2(imgui.GetItemRectSize())
        return False

cdef class Spacer(uiItem):
    def __cinit__(self):
        self.can_be_disabled = False
    cdef bint draw_item(self) noexcept nogil:
        if self.requested_size.x == 0 and \
           self.requested_size.y == 0:
            imgui.Spacing()
            # TODO rect_size
        else:
            imgui.Dummy(Vec2ImVec2(self.scaled_requested_size()))
        self.state.cur.rect_size = ImVec2Vec2(imgui.GetItemRectSize())
        return False

cdef class MenuBar(uiItem):
    def __cinit__(self):
        # We should maybe restrict to menuitem ?
        self.can_have_widget_child = True
        self.element_child_category = child_type.cat_menubar
        self._theme_condition_category = ThemeCategories.t_menubar
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self.state.cap.has_content_region = True # TODO

    cdef void draw(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)

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
        self.context.viewport.push_pending_theme_actions(
            self._theme_condition_enabled,
            self._theme_condition_category
        )
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
        self.context.viewport.pop_applied_pending_theme_actions()

        if self._font is not None:
            self._font.pop()

        # Restore original scale
        self.context.viewport.global_scale = original_scale 

        self.run_handlers()


cdef class Menu(uiItem):
    # TODO: MUST be inside a menubar
    def __cinit__(self):
        # We should maybe restrict to menuitem ?
        self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.can_have_widget_child = True
        self._theme_condition_category = ThemeCategories.t_menu
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
    def __cinit__(self):
        # We should maybe restrict to menuitem ?
        self.can_have_widget_child = True
        self._theme_condition_category = ThemeCategories.t_tooltip
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
        Target item which state will be checked
        to trigger the tooltip.
        Note if the item is after this tooltip
        in the rendering tree, there will be
        a frame delay.
        If no target is set, the previous sibling
        is the target.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._target

    @target.setter
    def target(self, baseItem target):
        cdef unique_lock[recursive_mutex] m
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
        When set, the handler referenced in
        this field will be used to replace
        the target hovering check. It will
        apply to target, which must be set.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._secondary_handler

    @condition_from_handler.setter
    def condition_from_handler(self, baseHandler handler):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._target is not None:
            handler.check_bind(self._target)
        self._secondary_handler = handler

    @property
    def delay(self):
        """
        Delay in seconds with no motion before showing the tooltip
        -1: Use imgui defaults
        Defaults to 0.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._delay

    @delay.setter
    def delay(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._delay = value

    @property
    def hide_on_activity(self):
        """
        Hide the tooltip when the mouse moves
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._hide_on_activity

    @hide_on_activity.setter
    def hide_on_activity(self, bint value):
        cdef unique_lock[recursive_mutex] m
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

        if display_condition and delay != 0:
            if delay < 0:
                delay = imgui.GetStyle().HoverStationaryDelay
            if not(self.state.prev.rendered) and \
               imgui.GetCurrentContext().MouseStationaryTimer < delay:
                display_condition = False

        cdef bint was_visible = self.state.cur.rendered
        cdef Vec2 pos_w, pos_p, parent_size_backup
        cdef Vec2 content_min, content_max
        if display_condition and imgui.BeginTooltip():
            self.state.cur.content_region_size = ImVec2Vec2(imgui.GetContentRegionAvail())
            if self.last_widgets_child is not None:
                # We are in a popup window
                pos_w = ImVec2Vec2(imgui.GetCursorScreenPos())
                pos_p = pos_w
                self._content_pos = pos_w
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
    def __cinit__(self):
        self._theme_condition_category = ThemeCategories.t_tabbutton
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
        Writable attribute: Disable reordering this tab or
        having another tab cross over this tab
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabItemFlags_NoReorder) != 0

    @no_reorder.setter
    def no_reorder(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabItemFlags_NoReorder
        if value:
            self._flags |= imgui.ImGuiTabItemFlags_NoReorder

    @property
    def leading(self):
        """
        Writable attribute: Enforce the tab position to the
        left of the tab bar (after the tab list popup button)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabItemFlags_Leading) != 0

    @leading.setter
    def leading(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabItemFlags_Leading
        if value:
            self._flags &= ~imgui.ImGuiTabItemFlags_Trailing
            self._flags |= imgui.ImGuiTabItemFlags_Leading

    @property
    def trailing(self):
        """
        Writable attribute: Enforce the tab position to the
        right of the tab bar (before the scrolling buttons)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabItemFlags_Trailing) != 0

    @trailing.setter
    def trailing(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabItemFlags_Trailing
        if value:
            self._flags &= ~imgui.ImGuiTabItemFlags_Leading
            self._flags |= imgui.ImGuiTabItemFlags_Trailing

    @property
    def no_tooltip(self):
        """
        Writable attribute: Disable tooltip for the given tab
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabItemFlags_NoTooltip) != 0

    @no_tooltip.setter
    def no_tooltip(self, bint value):
        cdef unique_lock[recursive_mutex] m
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
    def __cinit__(self):
        self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.can_have_widget_child = True
        self.element_child_category = child_type.cat_tab
        self._theme_condition_category = ThemeCategories.t_tab
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
        Writable attribute: Can the tab be closed
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._closable 

    @closable.setter
    def closable(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._closable = value

    @property
    def no_reorder(self):
        """
        Writable attribute: Disable reordering this tab or
        having another tab cross over this tab
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabItemFlags_NoReorder) != 0

    @no_reorder.setter
    def no_reorder(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabItemFlags_NoReorder
        if value:
            self._flags |= imgui.ImGuiTabItemFlags_NoReorder

    @property
    def leading(self):
        """
        Writable attribute: Enforce the tab position to the
        left of the tab bar (after the tab list popup button)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabItemFlags_Leading) != 0

    @leading.setter
    def leading(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabItemFlags_Leading
        if value:
            self._flags &= ~imgui.ImGuiTabItemFlags_Trailing
            self._flags |= imgui.ImGuiTabItemFlags_Leading

    @property
    def trailing(self):
        """
        Writable attribute: Enforce the tab position to the
        right of the tab bar (before the scrolling buttons)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabItemFlags_Trailing) != 0

    @trailing.setter
    def trailing(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabItemFlags_Trailing
        if value:
            self._flags &= ~imgui.ImGuiTabItemFlags_Leading
            self._flags |= imgui.ImGuiTabItemFlags_Trailing

    @property
    def no_tooltip(self):
        """
        Writable attribute: Disable tooltip for the given tab
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabItemFlags_NoTooltip) != 0

    @no_tooltip.setter
    def no_tooltip(self, bint value):
        cdef unique_lock[recursive_mutex] m
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
    def __cinit__(self):
        #self._value = <SharedValue>(SharedBool.__new__(SharedBool, self.context))
        self.can_have_tab_child = True
        self._theme_condition_category = ThemeCategories.t_tabbar
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_active = True
        self.state.cap.has_rect_size = True
        self._flags = imgui.ImGuiTabBarFlags_None

    @property
    def reorderable(self):
        """
        Writable attribute: Allow manually dragging tabs
        to re-order them + New tabs are appended at the end of list
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabBarFlags_Reorderable) != 0

    @reorderable.setter
    def reorderable(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabBarFlags_Reorderable
        if value:
            self._flags |= imgui.ImGuiTabBarFlags_Reorderable

    @property
    def autoselect_new_tabs(self):
        """
        Writable attribute: Automatically select new
        tabs when they appear
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabBarFlags_AutoSelectNewTabs) != 0

    @autoselect_new_tabs.setter
    def autoselect_new_tabs(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabBarFlags_AutoSelectNewTabs
        if value:
            self._flags |= imgui.ImGuiTabBarFlags_AutoSelectNewTabs

    @property
    def no_tab_list_popup_button(self):
        """
        Writable attribute: Disable buttons to open the tab list popup
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabBarFlags_TabListPopupButton) != 0

    @no_tab_list_popup_button.setter
    def no_tab_list_popup_button(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabBarFlags_TabListPopupButton
        if value:
            self._flags |= imgui.ImGuiTabBarFlags_TabListPopupButton

    @property
    def no_close_with_middle_mouse_button(self):
        """
        Writable attribute: Disable behavior of closing tabs with middle mouse button.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabBarFlags_NoCloseWithMiddleMouseButton) != 0

    @no_close_with_middle_mouse_button.setter
    def no_close_with_middle_mouse_button(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabBarFlags_NoCloseWithMiddleMouseButton
        if value:
            self._flags |= imgui.ImGuiTabBarFlags_NoCloseWithMiddleMouseButton

    @property
    def no_scrolling_button(self):
        """
        Writable attribute: Disable scrolling buttons
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabBarFlags_NoTabListScrollingButtons) != 0

    @no_scrolling_button.setter
    def no_scrolling_button(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabBarFlags_NoTabListScrollingButtons
        if value:
            self._flags |= imgui.ImGuiTabBarFlags_NoTabListScrollingButtons

    @property
    def no_tooltip(self):
        """
        Writable attribute: Disable tooltip for all tabs
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabBarFlags_NoTooltip) != 0

    @no_tooltip.setter
    def no_tooltip(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabBarFlags_NoTooltip
        if value:
            self._flags |= imgui.ImGuiTabBarFlags_NoTooltip

    @property
    def selected_overline(self):
        """
        Writable attribute: Draw selected overline markers over selected tab
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabBarFlags_DrawSelectedOverline) != 0

    @selected_overline.setter
    def selected_overline(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabBarFlags_DrawSelectedOverline
        if value:
            self._flags |= imgui.ImGuiTabBarFlags_DrawSelectedOverline

    @property
    def resize_to_fit(self):
        """
        Writable attribute: Resize tabs when they don't fit
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabBarFlags_FittingPolicyResizeDown) != 0

    @resize_to_fit.setter
    def resize_to_fit(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTabBarFlags_FittingPolicyResizeDown
        if value:
            self._flags |= imgui.ImGuiTabBarFlags_FittingPolicyResizeDown

    @property
    def allow_tab_scroll(self):
        """
        Writable attribute: Add scroll buttons when tabs don't fit
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTabBarFlags_FittingPolicyScroll) != 0

    @allow_tab_scroll.setter
    def allow_tab_scroll(self, bint value):
        cdef unique_lock[recursive_mutex] m
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
        cdef Vec2 pos_p
        if visible:
            if self.last_tab_child is not None:
                pos_p = ImVec2Vec2(imgui.GetCursorScreenPos())
                swap_Vec2(pos_p, self.context.viewport.parent_pos)
                draw_tab_children(self)
                self.context.viewport.parent_pos = pos_p
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
        self._theme_condition_category = ThemeCategories.t_treenode

    @property
    def selectable(self):
        """
        Writable attribute: Draw the TreeNode as selected when opened
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._selectable

    @selectable.setter
    def selectable(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._selectable = value

    @property
    def default_open(self):
        """
        Writable attribute: Default node to be open
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTreeNodeFlags_DefaultOpen) != 0

    @default_open.setter
    def default_open(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTreeNodeFlags_DefaultOpen
        if value:
            self._flags |= imgui.ImGuiTreeNodeFlags_DefaultOpen

    @property
    def open_on_double_click(self):
        """
        Writable attribute: Need double-click to open node
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTreeNodeFlags_OpenOnDoubleClick) != 0

    @open_on_double_click.setter
    def open_on_double_click(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTreeNodeFlags_OpenOnDoubleClick
        if value:
            self._flags |= imgui.ImGuiTreeNodeFlags_OpenOnDoubleClick

    @property
    def open_on_arrow(self):
        """
        Writable attribute:  Only open when clicking on the arrow part.
        If ImGuiTreeNodeFlags_OpenOnDoubleClick is also set,
        single-click arrow or double-click all box to open.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTreeNodeFlags_OpenOnArrow) != 0

    @open_on_arrow.setter
    def open_on_arrow(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTreeNodeFlags_OpenOnArrow
        if value:
            self._flags |= imgui.ImGuiTreeNodeFlags_OpenOnArrow

    @property
    def leaf(self):
        """
        Writable attribute: No collapsing, no arrow (use as a convenience for leaf nodes).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTreeNodeFlags_Leaf) != 0

    @leaf.setter
    def leaf(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTreeNodeFlags_Leaf
        if value:
            self._flags |= imgui.ImGuiTreeNodeFlags_Leaf

    @property
    def bullet(self):
        """
        Writable attribute: Display a bullet instead of arrow.
        IMPORTANT: node can still be marked open/close if
        you don't set the _Leaf flag!
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTreeNodeFlags_Bullet) != 0

    @bullet.setter
    def bullet(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTreeNodeFlags_Bullet
        if value:
            self._flags |= imgui.ImGuiTreeNodeFlags_Bullet

    @property
    def span_text_width(self):
        """
        Writable attribute: Narrow hit box + narrow hovering
        highlight, will only cover the label text.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTreeNodeFlags_SpanTextWidth) != 0

    @span_text_width.setter
    def span_text_width(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTreeNodeFlags_SpanTextWidth
        if value:
            self._flags |= imgui.ImGuiTreeNodeFlags_SpanTextWidth

    @property
    def span_full_width(self):
        """
        Writable attribute: Extend hit box to the left-most
        and right-most edges (cover the indent area).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTreeNodeFlags_SpanFullWidth) != 0

    @span_full_width.setter
    def span_full_width(self, bint value):
        cdef unique_lock[recursive_mutex] m
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
        self._theme_condition_category = ThemeCategories.t_collapsingheader

    @property
    def closable(self):
        """
        Writable attribute: Display a close button
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._closable

    @closable.setter
    def closable(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._closable = value

    @property
    def open_on_double_click(self):
        """
        Writable attribute: Need double-click to open node
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTreeNodeFlags_OpenOnDoubleClick) != 0

    @open_on_double_click.setter
    def open_on_double_click(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTreeNodeFlags_OpenOnDoubleClick
        if value:
            self._flags |= imgui.ImGuiTreeNodeFlags_OpenOnDoubleClick

    @property
    def open_on_arrow(self):
        """
        Writable attribute:  Only open when clicking on the arrow part.
        If ImGuiTreeNodeFlags_OpenOnDoubleClick is also set,
        single-click arrow or double-click all box to open.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTreeNodeFlags_OpenOnArrow) != 0

    @open_on_arrow.setter
    def open_on_arrow(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTreeNodeFlags_OpenOnArrow
        if value:
            self._flags |= imgui.ImGuiTreeNodeFlags_OpenOnArrow

    @property
    def leaf(self):
        """
        Writable attribute: No collapsing, no arrow (use as a convenience for leaf nodes).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTreeNodeFlags_Leaf) != 0

    @leaf.setter
    def leaf(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTreeNodeFlags_Leaf
        if value:
            self._flags |= imgui.ImGuiTreeNodeFlags_Leaf

    @property
    def bullet(self):
        """
        Writable attribute: Display a bullet instead of arrow.
        IMPORTANT: node can still be marked open/close if
        you don't set the _Leaf flag!
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTreeNodeFlags_Bullet) != 0

    @bullet.setter
    def bullet(self, bint value):
        cdef unique_lock[recursive_mutex] m
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
        # TODO: rect_size from group ?
        return not(was_open) and self.state.cur.open

cdef class ChildWindow(uiItem):
    """A child window container that enables hierarchical UI layout.

    A child window creates a scrollable/clippable region within a parent window that can contain any UI elements 
    and apply its own visual styling.

    Key Features:
    - Independent scrolling/clipping region 
    - Optional borders and background
    - Can contain most UI elements including other child windows
    - Automatic size fitting to content or parent
    - Optional scrollbars (vertical & horizontal)
    - Optional menu bar
    - DPI-aware scaling

    Properties:
    -----------
    always_show_vertical_scrollvar : bool
        Always show vertical scrollbar even when content fits. Default is False.

    always_show_horizontal_scrollvar : bool
        Always show horizontal scrollbar when enabled. Default is False. 

    no_scrollbar : bool
        Hide scrollbars but still allow scrolling with mouse/keyboard. Default is False.

    no_scroll_with_mouse : bool
        If set, mouse wheel scrolls parent instead of this child (unless no_scrollbar is set). Default is False.

    horizontal_scrollbar : bool
        Enable horizontal scrollbar. Default is False.

    menubar : bool 
        Enable menu bar at top of window. Default is False.

    border : bool
        Show window border and enable padding. Default is True.

    flattened_navigation: bool
        Share focus scope and allow keyboard/gamepad navigation to cross between parent and child.
        Default is True.

    Notes:
    ------
    - Child windows provide independent scrolling regions within a parent window
    - Content is automatically clipped to the visible region
    - Content size can be fixed or dynamic based on settings
    - Can enable borders and backgrounds independently
    - Keyboard focus and navigation can be customized
    - Menu bar support allows structured layouts
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
        self._theme_condition_category = ThemeCategories.t_child

    @property
    def always_show_vertical_scrollvar(self):
        """
        Writable attribute to tell to always show a vertical scrollbar
        even when the size does not require it
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_AlwaysVerticalScrollbar) else False

    @always_show_vertical_scrollvar.setter
    def always_show_vertical_scrollvar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_AlwaysVerticalScrollbar
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_AlwaysVerticalScrollbar

    @property
    def always_show_horizontal_scrollvar(self):
        """
        Writable attribute to tell to always show a horizontal scrollbar
        even when the size does not require it (only if horizontal scrollbar
        are enabled)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_AlwaysHorizontalScrollbar) else False

    @always_show_horizontal_scrollvar.setter
    def always_show_horizontal_scrollvar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_AlwaysHorizontalScrollbar
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_AlwaysHorizontalScrollbar

    @property
    def no_scrollbar(self):
        """Writable attribute to indicate the window should have no scrollbar
           Does not disable scrolling via mouse or keyboard
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoScrollbar) else False

    @no_scrollbar.setter
    def no_scrollbar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoScrollbar
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoScrollbar

    @property
    def horizontal_scrollbar(self):
        """
        Writable attribute to enable having an horizontal scrollbar
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_HorizontalScrollbar) else False

    @horizontal_scrollbar.setter
    def horizontal_scrollbar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_HorizontalScrollbar
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_HorizontalScrollbar

    @property
    def menubar(self):
        """
        Writable attribute to indicate whether the window has a menu bar.

        There will be menubar if either the user has asked for it,
        or there is a menubar child.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.last_menubar_child is not None) or (self._window_flags & imgui.ImGuiWindowFlags_MenuBar) != 0

    @menubar.setter
    def menubar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_MenuBar
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_MenuBar

    @property
    def no_scroll_with_mouse(self):
        """
        Writable attribute: mouse wheel will be forwarded to the parent
        unless NoScrollbar is also set.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._window_flags & imgui.ImGuiWindowFlags_NoScrollWithMouse) != 0

    @no_scroll_with_mouse.setter
    def no_scroll_with_mouse(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoScrollWithMouse
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoScrollWithMouse

    @property
    def flattened_navigation(self):
        """
        Writable attribute: share focus scope, allow gamepad/keyboard
        navigation to cross over parent border to this child or
        between sibling child windows.
        Defaults to True.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._child_flags & imgui.ImGuiChildFlags_NavFlattened) != 0

    @flattened_navigation.setter
    def flattened_navigation(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._child_flags &= ~imgui.ImGuiChildFlags_NavFlattened
        if value:
            self._child_flags |= imgui.ImGuiChildFlags_NavFlattened

    @property
    def border(self):
        """
        Writable attribute: show an outer border and enable WindowPadding.
        Defaults to True.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._child_flags & imgui.ImGuiChildFlags_Borders) != 0

    @border.setter
    def border(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._child_flags &= ~imgui.ImGuiChildFlags_Borders
        if value:
            self._child_flags |= imgui.ImGuiChildFlags_Borders

    @property
    def always_auto_resize(self):
        """
        Writable attribute: combined with AutoResizeX/AutoResizeY.
        Always measure size even when child is hidden,
        Note the item will render its children even if hidden.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._child_flags & imgui.ImGuiChildFlags_AlwaysAutoResize) != 0

    @always_auto_resize.setter
    def always_auto_resize(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._child_flags &= ~imgui.ImGuiChildFlags_AlwaysAutoResize
        if value:
            self._child_flags |= imgui.ImGuiChildFlags_AlwaysAutoResize

    @property
    def always_use_window_padding(self):
        """
        Writable attribute: pad with style WindowPadding even if
        no border are drawn (no padding by default for non-bordered
        child windows)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._child_flags & imgui.ImGuiChildFlags_AlwaysUseWindowPadding) != 0

    @always_use_window_padding.setter
    def always_use_window_padding(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._child_flags &= ~imgui.ImGuiChildFlags_AlwaysUseWindowPadding
        if value:
            self._child_flags |= imgui.ImGuiChildFlags_AlwaysUseWindowPadding

    @property
    def auto_resize_x(self):
        """
        Writable attribute: enable auto-resizing width based on the content
        Set instead width to 0 to use the remaining size of the parent
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._child_flags & imgui.ImGuiChildFlags_AutoResizeX) != 0

    @auto_resize_x.setter
    def auto_resize_x(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._child_flags &= ~imgui.ImGuiChildFlags_AutoResizeX
        if value:
            self._child_flags |= imgui.ImGuiChildFlags_AutoResizeX

    @property
    def auto_resize_y(self):
        """
        Writable attribute: enable auto-resizing height based on the content
        Set instead height to 0 to use the remaining size of the parent
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._child_flags & imgui.ImGuiChildFlags_AutoResizeY) != 0

    @auto_resize_y.setter
    def auto_resize_y(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._child_flags &= ~imgui.ImGuiChildFlags_AutoResizeY
        if value:
            self._child_flags |= imgui.ImGuiChildFlags_AutoResizeY

    @property
    def frame_style(self):
        """
        Writable attribute: if set, style the child window like a framed item.
        That is: use FrameBg, FrameRounding, FrameBorderSize, FramePadding
        instead of ChildBg, ChildRounding, ChildBorderSize, WindowPadding.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._child_flags & imgui.ImGuiChildFlags_FrameStyle) != 0

    @frame_style.setter
    def frame_style(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._child_flags &= ~imgui.ImGuiChildFlags_FrameStyle
        if value:
            self._child_flags |= imgui.ImGuiChildFlags_FrameStyle

    @property
    def resizable_x(self):
        """
        Writable attribute: allow resize from right border (layout direction).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._child_flags & imgui.ImGuiChildFlags_ResizeX) != 0

    @resizable_x.setter
    def resizable_x(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._child_flags &= ~imgui.ImGuiChildFlags_ResizeX
        if value:
            self._child_flags |= imgui.ImGuiChildFlags_ResizeX

    @property
    def resizable_y(self):
        """
        Writable attribute: allow resize from bottom border (layout direction).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._child_flags & imgui.ImGuiChildFlags_ResizeY) != 0

    @resizable_y.setter
    def resizable_y(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._child_flags &= ~imgui.ImGuiChildFlags_ResizeY
        if value:
            self._child_flags |= imgui.ImGuiChildFlags_ResizeY

    cdef bint draw_item(self) noexcept nogil:
        cdef imgui.ImGuiWindowFlags flags = self._window_flags
        if self.last_menubar_child is not None:
            flags |= imgui.ImGuiWindowFlags_MenuBar
        cdef Vec2 pos_p, pos_w, parent_size_backup
        cdef Vec2 requested_size = self.scaled_requested_size()
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
            self._content_pos = pos_p
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
    def __cinit__(self):
        self._flags = imgui.ImGuiColorEditFlags_DefaultOptions_
        self._theme_condition_category = ThemeCategories.t_colorbutton
        self._value = <SharedValue>(SharedColor.__new__(SharedColor, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True

    @property
    def no_alpha(self):
        """
        Writable attribute: ignore Alpha component (will only read 3 components from the input pointer)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoAlpha) != 0

    @no_alpha.setter
    def no_alpha(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoAlpha
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoAlpha

    @property
    def no_tooltip(self):
        """
        Writable attribute: disable default tooltip when hovering the preview
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoTooltip) != 0

    @no_tooltip.setter
    def no_tooltip(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoTooltip
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoTooltip

    @property
    def no_drag_drop(self):
        """
        Writable attribute: disable drag and drop source
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoDragDrop) != 0

    @no_drag_drop.setter
    def no_drag_drop(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoDragDrop
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoDragDrop

    @property
    def no_border(self):
        """
        Writable attribute: disable the default border
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoBorder) != 0

    @no_border.setter
    def no_border(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoBorder
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoBorder

    @property
    def alpha_preview(self):
        """
        Writable attribute: Show preview with either full alpha or checker pattern
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if (self._flags & imgui.ImGuiColorEditFlags_AlphaPreviewHalf) != 0:
            return "half" 
        elif (self._flags & imgui.ImGuiColorEditFlags_AlphaPreview) != 0:
            return "full"
        return "none"

    @alpha_preview.setter
    def alpha_preview(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~(imgui.ImGuiColorEditFlags_AlphaPreview | imgui.ImGuiColorEditFlags_AlphaPreviewHalf)
        if value == "half":
            self._flags |= imgui.ImGuiColorEditFlags_AlphaPreviewHalf
        elif value == "full":
            self._flags |= imgui.ImGuiColorEditFlags_AlphaPreview
        elif value != "none":
            raise ValueError("alpha_preview must be 'none', 'full' or 'half'")

    @property
    def data_type(self):
        """
        Writable attribute: Data type: float vs uint8
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return "uint8" if (self._flags & imgui.ImGuiColorEditFlags_Uint8) != 0 else "float" 

    @data_type.setter
    def data_type(self, str value):  
        cdef unique_lock[recursive_mutex] m
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
                                      Vec2ImVec2(self.scaled_requested_size()))
        self.update_current_state()
        SharedColor.setF4(<SharedColor>self._value, col)
        return activated


cdef class ColorEdit(uiItem):
    def __cinit__(self):
        self._flags = imgui.ImGuiColorEditFlags_DefaultOptions_
        self._theme_condition_category = ThemeCategories.t_coloredit
        self._value = <SharedValue>(SharedColor.__new__(SharedColor, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True

    @property
    def no_alpha(self):
        """
        Writable attribute: ignore Alpha component (will only read 3 components from the input pointer)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoAlpha) != 0

    @no_alpha.setter
    def no_alpha(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoAlpha
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoAlpha

    @property
    def no_picker(self):
        """
        Writable attribute: disable picker when clicking on color square.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoPicker) != 0

    @no_picker.setter
    def no_picker(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoPicker
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoPicker

    @property
    def no_options(self):
        """
        Writable attribute: disable toggling options menu when right-clicking on inputs/small preview.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoOptions) != 0

    @no_options.setter
    def no_options(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoOptions
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoOptions

    @property
    def no_small_preview(self):
        """
        Writable attribute: disable color square preview next to the inputs. (e.g. to show only the inputs)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoSmallPreview) != 0

    @no_small_preview.setter
    def no_small_preview(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoSmallPreview
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoSmallPreview

    @property
    def no_inputs(self):
        """
        Writable attribute: disable inputs sliders/text widgets (e.g. to show only the small preview color square).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoInputs) != 0

    @no_inputs.setter
    def no_inputs(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoInputs
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoInputs

    @property
    def no_tooltip(self):
        """
        Writable attribute: disable default tooltip when hovering the preview
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoTooltip) != 0

    @no_tooltip.setter
    def no_tooltip(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoTooltip
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoTooltip

    @property
    def no_label(self):
        """
        Writable attribute: disable display of inline text label (the label is still forwarded to the tooltip and picker).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoLabel) != 0

    @no_label.setter
    def no_label(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoLabel
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoLabel

    @property
    def no_drag_drop(self):
        """
        Writable attribute: disable drag and drop target
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoDragDrop) != 0

    @no_drag_drop.setter
    def no_drag_drop(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoDragDrop
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoDragDrop

    @property
    def alpha_bar(self):
        """
        Writable attribute: Show vertical alpha bar/gradient
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_AlphaBar) != 0

    @alpha_bar.setter 
    def alpha_bar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_AlphaBar
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_AlphaBar

    @property
    def alpha_preview(self):
        """
        Writable attribute: Show preview with either full alpha or checker pattern
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if (self._flags & imgui.ImGuiColorEditFlags_AlphaPreviewHalf) != 0:
            return "half" 
        elif (self._flags & imgui.ImGuiColorEditFlags_AlphaPreview) != 0:
            return "full"
        return "none"

    @alpha_preview.setter
    def alpha_preview(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~(imgui.ImGuiColorEditFlags_AlphaPreview | imgui.ImGuiColorEditFlags_AlphaPreviewHalf)
        if value == "half":
            self._flags |= imgui.ImGuiColorEditFlags_AlphaPreviewHalf
        elif value == "full":
            self._flags |= imgui.ImGuiColorEditFlags_AlphaPreview
        elif value != "none":
            raise ValueError("alpha_preview must be 'none', 'full' or 'half'")

    @property
    def display_mode(self):
        """
        Writable attribute: Color display mode: RGB/HSV/Hex
        """  
        cdef unique_lock[recursive_mutex] m
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
        cdef unique_lock[recursive_mutex] m
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
        Writable attribute: Color input mode: RGB/HSV
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return "hsv" if (self._flags & imgui.ImGuiColorEditFlags_InputHSV) != 0 else "rgb"

    @input_mode.setter
    def input_mode(self, str value):
        cdef unique_lock[recursive_mutex] m  
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
        Writable attribute: Data type: float vs uint8
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return "uint8" if (self._flags & imgui.ImGuiColorEditFlags_Uint8) != 0 else "float" 

    @data_type.setter
    def data_type(self, str value):  
        cdef unique_lock[recursive_mutex] m
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
        Writable attribute: Support HDR colors (multiplier can go beyond 1.0f and values can go above 1.0)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_HDR) != 0

    @hdr.setter
    def hdr(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_HDR
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_HDR

    cdef bint draw_item(self) noexcept nogil:
        cdef bint activated
        cdef Vec4 col = SharedColor.getF4(<SharedColor>self._value)
        cdef float[4] color = [col.x, col.y, col.z, col.w]
        activated = imgui.ColorEdit4(self._imgui_label.c_str(),
                                      color,
                                      self._flags)
        self.update_current_state()
        col = ImVec4Vec4(imgui.ImVec4(color[0], color[1], color[2], color[3]))
        SharedColor.setF4(<SharedColor>self._value, col)
        return activated

cdef class ColorPicker(uiItem):
    def __cinit__(self):
        self._flags = imgui.ImGuiColorEditFlags_DefaultOptions_
        self._theme_condition_category = ThemeCategories.t_colorpicker
        self._value = <SharedValue>(SharedColor.__new__(SharedColor, self.context))
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True

    @property
    def no_alpha(self):
        """
        Writable attribute: ignore Alpha component (will only read 3 components from the input pointer)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoAlpha) != 0

    @no_alpha.setter
    def no_alpha(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoAlpha
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoAlpha

    @property
    def no_small_preview(self):
        """
        Writable attribute: disable color square preview next to the inputs. (e.g. to show only the inputs)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoSmallPreview) != 0

    @no_small_preview.setter
    def no_small_preview(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoSmallPreview
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoSmallPreview

    @property
    def no_inputs(self):
        """
        Writable attribute: disable inputs sliders/text widgets (e.g. to show only the small preview color square).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoInputs) != 0

    @no_inputs.setter
    def no_inputs(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoInputs
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoInputs

    @property
    def no_tooltip(self):
        """
        Writable attribute: disable default tooltip when hovering the preview
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoTooltip) != 0

    @no_tooltip.setter
    def no_tooltip(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoTooltip
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoTooltip

    @property
    def no_label(self):
        """
        Writable attribute: disable display of inline text label (the label is still forwarded to the tooltip and picker).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoLabel) != 0

    @no_label.setter
    def no_label(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoLabel
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoLabel

    @property
    def no_side_preview(self):
        """
        Writable attribute: disable bigger color preview on right side of the picker
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_NoSidePreview) != 0

    @no_side_preview.setter  
    def no_side_preview(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_NoSidePreview
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_NoSidePreview

    @property
    def picker_mode(self):
        """
        Writable attribute: Color picker mode: bar vs wheel
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)  
        return "wheel" if (self._flags & imgui.ImGuiColorEditFlags_PickerHueWheel) != 0 else "bar"

    @picker_mode.setter
    def picker_mode(self, str value):
        cdef unique_lock[recursive_mutex] m
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
        Writable attribute: Show vertical alpha bar/gradient
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiColorEditFlags_AlphaBar) != 0

    @alpha_bar.setter 
    def alpha_bar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiColorEditFlags_AlphaBar
        if value:
            self._flags |= imgui.ImGuiColorEditFlags_AlphaBar

    @property
    def alpha_preview(self):
        """
        Writable attribute: Show preview with either full alpha or checker pattern
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if (self._flags & imgui.ImGuiColorEditFlags_AlphaPreviewHalf) != 0:
            return "half" 
        elif (self._flags & imgui.ImGuiColorEditFlags_AlphaPreview) != 0:
            return "full"
        return "none"

    @alpha_preview.setter
    def alpha_preview(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~(imgui.ImGuiColorEditFlags_AlphaPreview | imgui.ImGuiColorEditFlags_AlphaPreviewHalf)
        if value == "half":
            self._flags |= imgui.ImGuiColorEditFlags_AlphaPreviewHalf
        elif value == "full":
            self._flags |= imgui.ImGuiColorEditFlags_AlphaPreview
        elif value != "none":
            raise ValueError("alpha_preview must be 'none', 'full' or 'half'")

    @property
    def display_mode(self):
        """
        Writable attribute: Color display mode: RGB/HSV/Hex
        """  
        cdef unique_lock[recursive_mutex] m
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
        cdef unique_lock[recursive_mutex] m
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
        Writable attribute: Color input mode: RGB/HSV
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return "hsv" if (self._flags & imgui.ImGuiColorEditFlags_InputHSV) != 0 else "rgb"

    @input_mode.setter
    def input_mode(self, str value):
        cdef unique_lock[recursive_mutex] m  
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
        Writable attribute: Data type: float vs uint8
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return "uint8" if (self._flags & imgui.ImGuiColorEditFlags_Uint8) != 0 else "float" 

    @data_type.setter
    def data_type(self, str value):  
        cdef unique_lock[recursive_mutex] m
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._value
    @value.setter
    def value(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef bint changed = value != self._value
        self._value = value
        self.on_update(changed)
    cdef bint get(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self._value
    cdef void set(self, bint value) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef bint changed = value != self._value
        self._value = value
        self.on_update(changed)

cdef class SharedFloat(SharedValue):
    def __init__(self, Context context, float value):
        self._value = value
        self._num_attached = 0
    @property
    def value(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._value
    @value.setter
    def value(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef bint changed = value != self._value
        self._value = value
        self.on_update(changed)
    cdef float get(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self._value
    cdef void set(self, float value) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef bint changed = value != self._value
        self._value = value
        self.on_update(changed)

cdef class SharedInt(SharedValue):
    def __init__(self, Context context, int32_t value):
        self._value = value
        self._num_attached = 0
    @property
    def value(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._value
    @value.setter
    def value(self, int32_t value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef bint changed = value != self._value
        self._value = value
        self.on_update(changed)
    cdef int32_t get(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self._value
    cdef void set(self, int32_t value) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        #"Color data is an int32 (rgba, little endian),\n" \
        #"If you pass an array of int (r, g, b, a), or float\n" \
        #"(r, g, b, a) normalized it will get converted automatically"
        return <int>self._value
    @value.setter
    def value(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._value = parse_color(value)
        self._value_asfloat4 = ImVec4Vec4(imgui.ColorConvertU32ToFloat4(self._value))
        self.on_update(True)
    cdef uint32_t getU32(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self._value
    cdef Vec4 getF4(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self._value_asfloat4
    cdef void setU32(self, uint32_t value) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self._value = value
        self._value_asfloat4 = ImVec4Vec4(imgui.ColorConvertU32ToFloat4(self._value))
        self.on_update(True)
    cdef void setF4(self, Vec4 value) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self._value_asfloat4 = value
        self._value = imgui.ColorConvertFloat4ToU32(Vec4ImVec4(self._value_asfloat4))
        self.on_update(True)

cdef class SharedDouble(SharedValue):
    def __init__(self, Context context, double value):
        self._value = value
        self._num_attached = 0
    @property
    def value(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._value
    @value.setter
    def value(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef bint changed = value != self._value
        self._value = value
        self.on_update(changed)
    cdef double get(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self._value
    cdef void set(self, double value) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef bint changed = value != self._value
        self._value = value
        self.on_update(changed)

cdef class SharedStr(SharedValue):
    def __init__(self, Context context, str value):
        self._value = bytes(str(value), 'utf-8')
        self._num_attached = 0
    @property
    def value(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(self._value, encoding='utf-8')
    @value.setter
    def value(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._value = bytes(str(value), 'utf-8')
        self.on_update(True)
    cdef void get(self, string& out) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        out = self._value
    cdef void set(self, string value) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self._value = value
        self.on_update(True)

cdef class SharedFloat4(SharedValue):
    def __init__(self, Context context, value):
        read_vec4[float](self._value, value)
        self._num_attached = 0
    @property
    def value(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._value)
    @value.setter
    def value(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_vec4[float](self._value, value)
        self.on_update(True)
    cdef void get(self, float *dst) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        dst[0] = self._value[0]
        dst[1] = self._value[1]
        dst[2] = self._value[2]
        dst[3] = self._value[3]
    cdef void set(self, float[4] value) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self._value[0] = value[0]
        self._value[1] = value[1]
        self._value[2] = value[2]
        self._value[3] = value[3]
        self.on_update(True)

cdef class SharedInt4(SharedValue):
    def __init__(self, Context context, value):
        read_vec4[int32_t](self._value, value)
        self._num_attached = 0
    @property
    def value(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._value)
    @value.setter
    def value(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_vec4[int32_t](self._value, value)
        self.on_update(True)
    cdef void get(self, int32_t *dst) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        dst[0] = self._value[0]
        dst[1] = self._value[1]
        dst[2] = self._value[2]
        dst[3] = self._value[3]
    cdef void set(self, int32_t[4] value) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self._value[0] = value[0]
        self._value[1] = value[1]
        self._value[2] = value[2]
        self._value[3] = value[3]
        self.on_update(True)

cdef class SharedDouble4(SharedValue):
    def __init__(self, Context context, value):
        read_vec4[double](self._value, value)
    @property
    def value(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return list(self._value)
    @value.setter
    def value(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        read_vec4[double](self._value, value)
        self.on_update(True)
    cdef void get(self, double *dst) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        dst[0] = self._value[0]
        dst[1] = self._value[1]
        dst[2] = self._value[2]
        dst[3] = self._value[3]
    cdef void set(self, double[4] value) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self._value[0] = value[0]
        self._value[1] = value[1]
        self._value[2] = value[2]
        self._value[3] = value[3]
        self.on_update(True)

cdef class SharedFloatVect(SharedValue):
    def __init__(self, Context context, value):
        self._value = value
    def __cinit__(self):
        self._value_np = np.zeros([1], dtype=np.float32)
        self._value = self._value_np
    @property
    def value(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._value_np is None:
            return None
        return np.copy(self._value)
    @value.setter
    def value(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._value_np = np.array(value, dtype=np.float32)
        self._value = self._value_np
        self.on_update(True)
    cdef float[:] get(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return self._value
    cdef void set(self, float[:] value) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self._value = value
        self.on_update(True)

"""
cdef class SharedDoubleVect:
    cdef double[:] value
    cdef double[:] get(self) noexcept nogil
    cdef void set(self, double[:]) noexcept nogil

cdef class SharedTime:
    cdef tm value
    cdef tm get(self) noexcept nogil
    cdef void set(self, tm) noexcept nogil
"""





