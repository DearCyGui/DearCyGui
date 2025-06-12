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

cimport cython
from cpython.ref cimport PyObject

from libc.stdint cimport int32_t
from libcpp.cmath cimport floor, fmax

from .core cimport uiItem, Callback, lock_gil_friendly
from .c_types cimport Vec2, make_Vec2, swap_Vec2, DCGMutex, unique_lock
from .imgui_types cimport ImVec2Vec2
from .sizing cimport resolve_size
from .sizing import Size
from .types cimport child_type
from .wrapper cimport imgui

cdef class Layout(uiItem):
    """
    A layout is a group of elements organized together.
    
    The layout states correspond to the OR of all the item states, and the rect 
    size corresponds to the minimum rect containing all the items. The position 
    of the layout is used to initialize the default position for the first item.
    An indentation will shift all the items of the Layout.

    Subclassing Layout:
    For custom layouts, you can use Layout with a callback. The callback is 
    called whenever the layout should be updated.

    If the automated update detection is not sufficient, update_layout() can be 
    called to force a recomputation of the layout.

    Currently the update detection detects a change in the size of the remaining 
    content area available locally within the window, or if the last item has 
    changed.

    The layout item works by changing the x, y and no_newline fields
    of its children, and thus there is no guarantee that the user set
    x, y and no_newline fields of the children are preserved.

    If an item is moved out of the layout, the user has to manually
    set the x, y and no_newline fields of the item to their new desired values.
    """
    def __cinit__(self):
        self.can_have_widget_child = True
        self.state.cap.can_be_active = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_deactivated_after_edited = True
        self.state.cap.can_be_edited = True
        self.state.cap.can_be_focused = True
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_toggled = True
        self.state.cap.has_content_region = True
        self._previous_last_child = NULL

    def update_layout(self):
        """
        Force an update of the layout next time the scene is rendered.
        
        This method triggers the recalculation of item positions and sizes 
        within the layout. It's useful when the automated update detection 
        is not sufficient to detect layout changes.
        """
        cdef int32_t i
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        for i in range(<int>self._callbacks.size()):
            self.context.queue_callback_arg1value(<Callback>self._callbacks[i], self, self, self._value)

    # final enables inlining
    @cython.final
    cdef Vec2 update_content_area(self) noexcept nogil:
        cdef Vec2 full_content_area = self.context.viewport.parent_size
        cdef Vec2 cur_content_area, requested_size

        full_content_area.x -= self.state.cur.pos_to_parent.x
        full_content_area.y -= self.state.cur.pos_to_parent.y

        requested_size = self.get_requested_size()

        if requested_size.x == 0:
            cur_content_area.x = full_content_area.x
        elif requested_size.x < 0:
            cur_content_area.x = full_content_area.x + requested_size.x
        else:
            cur_content_area.x = requested_size.x

        if requested_size.y == 0:
            cur_content_area.y = full_content_area.y
        elif requested_size.y < 0:
            cur_content_area.y = full_content_area.y + requested_size.y
        else:
            cur_content_area.y = requested_size.y

        cur_content_area.x = max(0, cur_content_area.x)
        cur_content_area.y = max(0, cur_content_area.y)
        self.state.cur.content_region_size = cur_content_area
        return cur_content_area

    cdef bint check_change(self) noexcept nogil:
        cdef Vec2 cur_content_area = self.state.cur.content_region_size
        cdef Vec2 prev_content_area = self.state.prev.content_region_size
        cdef Vec2 cur_spacing = ImVec2Vec2(imgui.GetStyle().ItemSpacing)
        cdef bint changed = False
        if cur_content_area.x != prev_content_area.x or \
           cur_content_area.y != prev_content_area.y or \
           self._previous_last_child != <PyObject*>self.last_widgets_child or \
           cur_spacing.x != self._spacing.x or \
           cur_spacing.y != self._spacing.y or \
           self._force_update:
            changed = True
            self._spacing = cur_spacing
            self._previous_last_child = <PyObject*>self.last_widgets_child
            self._force_update = False
        return changed

    @cython.final
    cdef void draw_child(self, uiItem child) noexcept nogil:
        child.draw()
        if child.state.cur.rect_size.x != child.state.prev.rect_size.x or \
           child.state.cur.rect_size.y != child.state.prev.rect_size.y:
            child.context.viewport.redraw_needed = True
            self._force_update = True

    @cython.final
    cdef void draw_children(self) noexcept nogil:
        """
        Similar to draw_ui_children, but detects
        any change relative to expected sizes
        """
        if self.last_widgets_child is None:
            return
        cdef Vec2 parent_size_backup = self.context.viewport.parent_size
        self.context.viewport.parent_size = self.state.cur.content_region_size
        cdef PyObject *child = <PyObject*> self.last_widgets_child
        while (<uiItem>child).prev_sibling is not None:
            child = <PyObject *>(<uiItem>child).prev_sibling
        while (<uiItem>child) is not None:
            self.draw_child(<uiItem>child)
            child = <PyObject *>(<uiItem>child).next_sibling
        self.context.viewport.parent_size = parent_size_backup

    cdef bint draw_item(self) noexcept nogil:
        if self.last_widgets_child is None:# or \
            #cur_content_area.x <= 0 or \
            #cur_content_area.y <= 0: # <= 0 occurs when not visible
            #self.set_hidden_no_handler_and_propagate_to_children_with_handlers()
            return False
        self.update_content_area()
        cdef bint changed = self.check_change()
        imgui.PushID(self.uuid)
        imgui.BeginGroup()
        cdef Vec2 pos_p
        if self.last_widgets_child is not None:
            pos_p = ImVec2Vec2(imgui.GetCursorScreenPos())
            swap_Vec2(pos_p, self.context.viewport.parent_pos)
            self.draw_children()
            self.context.viewport.parent_pos = pos_p
        #imgui.PushStyleVar(imgui.ImGuiStyleVar_ItemSpacing,
        #                       imgui.ImVec2(0., 0.))
        imgui.EndGroup()
        #imgui.PopStyleVar(1)
        imgui.PopID()
        self.update_current_state()
        return changed

cdef class HorizontalLayout(Layout):
    """
    A layout that organizes items horizontally from left to right.
    
    HorizontalLayout arranges child elements in a row, with customizable 
    alignment modes, spacing, and wrapping options. It can align items to 
    the left or right edge, center them, distribute them evenly using the
    justified mode, or position them manually.
    
    The layout automatically tracks content width changes and repositions 
    children when needed. Wrapping behavior can be customized to control 
    how items overflow when they exceed available width.
    """
    def __cinit__(self):
        self._alignment_mode = Alignment.LEFT

    @property
    def alignment_mode(self):
        """
        Horizontal alignment mode of the items.
        
        LEFT: items are appended from the left
        RIGHT: items are appended from the right
        CENTER: items are centered
        JUSTIFIED: spacing is organized such that items start at the left 
            and end at the right
        MANUAL: items are positioned at the requested positions
        
        For LEFT/RIGHT/CENTER, ItemSpacing's style can be used to control 
        spacing between the items. Default is LEFT.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._alignment_mode

    @alignment_mode.setter
    def alignment_mode(self, Alignment value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if <int>value < 0 or value > Alignment.MANUAL:
            raise ValueError("Invalid alignment value")
        if value == self._alignment_mode:
            return
        self._force_update = True
        self._alignment_mode = value

    @property
    def no_wrap(self):
        """
        Controls whether items wrap to the next row when exceeding available width.
        
        When set to True, items will continue on the same row even if they exceed
        the layout's width. When False (default), items that don't fit will
        continue on the next row.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._no_wrap

    @no_wrap.setter
    def no_wrap(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value == self._no_wrap:
            return
        self._force_update = True
        self._no_wrap = value

    @property
    def wrap_x(self):
        """
        X position from which items start on wrapped rows.
        
        When items wrap to a second or later row, this value determines the
        horizontal offset from the starting position. The value is in pixels
        and must be scaled if needed. The position is clamped to ensure items
        always start at a position >= 0 relative to the window content area.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._wrap_x

    @wrap_x.setter
    def wrap_x(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._wrap_x = value

    @property
    def positions(self):
        """
        X positions for items when using MANUAL alignment mode.
        
        When in MANUAL mode, these are the x positions from the top left of this
        layout at which to place the children items.
        
        Values between 0 and 1 are interpreted as percentages relative to the
        layout width. Negative values are interpreted as relative to the right
        edge rather than the left. Items are still left-aligned to the target
        position.
        
        Setting this property automatically sets alignment_mode to MANUAL.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int i
        for i in range(<int>self._positions.size()):
            result.append(self._positions[i])
        return result

    @positions.setter
    def positions(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if len(value) > 0:
            self._alignment_mode = Alignment.MANUAL
        # TODO: checks
        self._positions.clear()
        for v in value:
            self._positions.push_back(v)
        self._force_update = True

    def update_layout(self):
        """
        Force an update of the layout next time the scene is rendered.
        
        This method triggers the recalculation of item positions and sizes 
        within the layout. It's useful when the automated update detection 
        is not sufficient to detect layout changes.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._force_update = True

    cdef float __compute_items_size(self, int32_t &n_items) noexcept nogil:
        cdef float size = 0.
        n_items = 0
        cdef PyObject *child = <PyObject*>self.last_widgets_child
        while (<uiItem>child) is not None:
            size += (<uiItem>child).state.cur.rect_size.x
            n_items += 1
            child = <PyObject*>((<uiItem>child).prev_sibling)
            if not((<uiItem>child).state.prev.rendered):
                # Will need to recompute layout after the size is computed
                self._force_update = True
        return size

    cdef void __update_layout_manual(self):
        """Position items at manually specified x positions"""
        # assumes children are locked and > 0
        cdef float available_width = self.state.cur.content_region_size.x
        cdef float pos_start = 0.
        cdef int32_t i = 0
        cdef PyObject *child = <PyObject*>self.last_widgets_child
        cdef bint pos_change = False

        # Get back to first child
        while (<uiItem>child).prev_sibling is not None:
            child = <PyObject*>((<uiItem>child).prev_sibling)

        # Position each item at specified x coordinate
        while (<uiItem>child) is not None:
            # Get position from positions list or default to 0
            if not(self._positions.empty()):
                pos_start = self._positions[min(i, <int>self._positions.size()-1)]

            # Convert relative (0-1) or negative positions
            if pos_start > 0.:
                if pos_start < 1.:
                    pos_start *= available_width
                    pos_start = floor(pos_start)
            elif pos_start < 0:
                if pos_start > -1.:
                    pos_start *= available_width 
                    pos_start += available_width
                    pos_start = floor(pos_start)
                else:
                    pos_start += available_width

            # Set item position and ensure it stays within bounds
            pos_start = max(0, pos_start)
            pos_change |= pos_start != (<uiItem>child).state.cur.pos_to_parent.x ## cur or prev ? -> to double check
            (<uiItem>child).requested_x.set_item_o(Size.ADD(Size.PARENT_X1(), Size.FIXED(pos_start)))
            (<uiItem>child).requested_y.set_value(0)
            (<uiItem>child).no_newline = True

            child = <PyObject*>(<uiItem>child).next_sibling
            i += 1

        # Ensure last item allows newline
        if self.last_widgets_child is not None:
            self.last_widgets_child.no_newline = False

        # Force update if positions changed
        if pos_change:
            self._force_update = True
            self.context.viewport.redraw_needed = True

    cdef void __update_layout(self):
        if self._alignment_mode == Alignment.MANUAL:
            self.__update_layout_manual()
            return
        # Assumes all children are locked
        cdef PyObject *child = <PyObject*>self.last_widgets_child
        cdef float end_x = self.state.cur.content_region_size.x
        cdef float available_width = end_x
        #cdef float available_height = self.prev_content_area.y
        cdef float spacing_x = self._spacing.x
        #cdef float spacing_y = self._spacing.y
        # Get back to the first child
        while ((<uiItem>child).prev_sibling) is not None:
            child = <PyObject*>((<uiItem>child).prev_sibling)
        cdef PyObject *sibling
        cdef int32_t i, n_items_this_row, row
        cdef float target_x, expected_x, expected_size, expected_size_next
        #cdef float y, next_y = 0
        cdef float wrap_x = max(-self.state.cur.pos_to_window.x, self._wrap_x)
        cdef bint pos_change = False
        cdef float global_scale_inv = 1./fmax(self.context.viewport.global_scale, 0.00001)
        row = 0
        while (<uiItem>child) is not None:
            # Compute the number of items on this row
            if row == 1:
                # starting from the second row, begin to wrap at the target
                available_width -= wrap_x
            #y = next_y
            n_items_this_row = 1
            expected_size = (<uiItem>child).state.cur.rect_size.x
            #next_y = (<uiItem>child).state.cur.rect_size.y
            sibling = child
            while (<uiItem>sibling).next_sibling is not None:
                # Does the next item fit ?
                expected_size_next = expected_size + self._spacing.x + \
                    (<uiItem>(<uiItem>sibling).next_sibling).state.cur.rect_size.x
                # No: stop there
                if expected_size_next > available_width and not(self._no_wrap):
                    break
                expected_size = expected_size_next
                if not((<uiItem>sibling).state.cap.has_rect_size):
                    # Items without rect size (tooltips for instance) do not count in the layout
                    sibling = <PyObject*>(<uiItem>sibling).next_sibling
                    continue
                #next_y = max(next_y, y + (<uiItem>sibling).state.cur.rect_size.y)
                sibling = <PyObject*>(<uiItem>sibling).next_sibling
                n_items_this_row += 1
            #next_y = next_y + spacing_y

            # Determine the element positions
            sibling = child
            if self._alignment_mode == Alignment.LEFT:
                target_x = 0 if row == 0 else wrap_x
            elif self._alignment_mode == Alignment.RIGHT:
                target_x = end_x - expected_size
            elif self._alignment_mode == Alignment.CENTER:
                # Center right away (not waiting the second row) with wrap_x
                target_x = (end_x + wrap_x) // 2 - \
                    expected_size // 2 # integer rounding to avoid blurring
            else: #self._alignment_mode == Alignment.JUSTIFIED:
                target_x = 0 if row == 0 else wrap_x
                # Increase spacing to fit target space
                spacing_x = self._spacing.x + \
                    max(0, \
                        floor((available_width - expected_size) /
                               (n_items_this_row-1)))

            # Important for auto fit windows
            target_x = max(0 if row == 0 else wrap_x, target_x)

            expected_x = 0
            i = 0
            while i < n_items_this_row-1:
                if not((<uiItem>sibling).state.cap.has_rect_size):
                    # Items without rect size do not count in the layout
                    sibling = <PyObject*>(<uiItem>sibling).next_sibling
                    continue
                pos_change |= (<uiItem>sibling).requested_x.is_item() or\
                    (target_x - expected_x) * global_scale_inv != (<uiItem>sibling).requested_x.get_value()
                (<uiItem>sibling).requested_x.set_value((target_x - expected_x) * global_scale_inv) # delta to default position
                (<uiItem>sibling).requested_y.set_value(0.) # default position
                (<uiItem>sibling).no_newline = True
                expected_x = target_x + self._spacing.x + (<uiItem>sibling).state.cur.rect_size.x
                target_x = target_x + spacing_x + (<uiItem>sibling).state.cur.rect_size.x
                sibling = <PyObject*>(<uiItem>sibling).next_sibling
                i = i + 1
            if i != 0:
                while (<uiItem>sibling).next_sibling is not None and \
                      not((<uiItem>sibling).state.cap.has_rect_size):
                    sibling = <PyObject*>(<uiItem>sibling).next_sibling
                    continue
            # Last item of the row
            if (self._alignment_mode == Alignment.RIGHT or \
               (self._alignment_mode == Alignment.JUSTIFIED and n_items_this_row != 1)) and \
               (<uiItem>child).state.cur.rect_size.x == (<uiItem>child).state.prev.rect_size.x:
                # Align right item properly even if rounding
                # occured on spacing.
                # We check the item size is fixed because if the item tries to autosize
                # to the available content, it can lead to convergence issues
                # undo previous spacing
                target_x -= spacing_x
                # ideal spacing
                spacing_x = \
                    end_x - (target_x + (<uiItem>sibling).state.cur.rect_size.x)
                # real spacing
                target_x += max(spacing_x, self._spacing.x)

            pos_change |= (<uiItem>sibling).requested_x.is_item() or\
                (target_x - expected_x) * global_scale_inv != (<uiItem>sibling).requested_x.get_value()
            (<uiItem>sibling).requested_x.set_value((target_x - expected_x) * global_scale_inv) # delta to default position
            (<uiItem>sibling).requested_y.set_value(0.) # default position
            (<uiItem>sibling).no_newline = False
            child = <PyObject*>(<uiItem>sibling).next_sibling
            row += 1
        # A change in position change alter the size for some items
        if pos_change:
            self._force_update = True
            self.context.viewport.redraw_needed = True


    cdef bint draw_item(self) noexcept nogil:
        if self.last_widgets_child is None:# or \
            #cur_content_area.x <= 0 or \
            #cur_content_area.y <= 0: # <= 0 occurs when not visible
            # self.set_hidden_no_handler_and_propagate_to_children_with_handlers()
            return False
        self.update_content_area()
        cdef bint changed = self.check_change()
        if changed:
            self.last_widgets_child.lock_and_previous_siblings()
            with gil:
                self.__update_layout()
        imgui.PushID(self.uuid)
        imgui.BeginGroup()
        cdef Vec2 pos_p
        if self.last_widgets_child is not None:
            pos_p = ImVec2Vec2(imgui.GetCursorScreenPos())
            swap_Vec2(pos_p, self.context.viewport.parent_pos)
            self.draw_children()
            self.context.viewport.parent_pos = pos_p
        if changed:
            # We maintain the lock during the rendering
            # just to be sure the user doesn't change the
            # Positioning we took care to manage :-)
            self.last_widgets_child.unlock_and_previous_siblings()
        #imgui.PushStyleVar(imgui.ImGuiStyleVar_ItemSpacing,
        #                   imgui.ImVec2(0., 0.))
        imgui.EndGroup()
        #imgui.PopStyleVar(1)
        imgui.PopID()
        self.update_current_state()
        if self.state.cur.rect_size.x != self.state.prev.rect_size.x or \
           self.state.cur.rect_size.y != self.state.prev.rect_size.y:
            self._force_update = True
            self.context.viewport.redraw_needed = True
        return changed

cdef class VerticalLayout(Layout):
    """
    A layout that organizes items vertically from top to bottom.
    
    VerticalLayout arranges child elements in a column, with customizable 
    alignment modes, spacing, and wrapping options. It can align items to 
    the top or bottom edge, center them, distribute them evenly using the
    justified mode, or position them manually.
    
    The layout automatically tracks content height changes and repositions 
    children when needed. Wrapping behavior can be customized to control 
    how items overflow when they exceed available height.
    """
    def __cinit__(self):
        self._alignment_mode = Alignment.TOP
        self._no_wrap = True
        self._wrap_y = 0.0

    @property
    def alignment_mode(self):
        """
        Vertical alignment mode of the items.
        
        TOP: items are appended from the top
        BOTTOM: items are appended from the bottom
        CENTER: items are centered
        JUSTIFIED: spacing is organized such that items start at the top 
            and end at the bottom
        MANUAL: items are positioned at the requested positions
        
        For TOP/BOTTOM/CENTER, ItemSpacing's style can be used to control 
        spacing between the items. Default is TOP.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._alignment_mode

    @alignment_mode.setter
    def alignment_mode(self, Alignment value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if <int>value < 0 or value > Alignment.MANUAL:
            raise ValueError("Invalid alignment value")
        if value == self._alignment_mode:
            return
        self._force_update = True
        self._alignment_mode = value

    @property
    def wrap(self):
        """
        Controls whether items wrap to the next column when exceeding available height.
        
        When set to False (default), items will continue in the same column even if they exceed
        the layout's height. When True, items that don't fit will
        continue in the next column.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return not(self._no_wrap)

    @wrap.setter
    def wrap(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if not(value) == self._no_wrap:
            return
        self._force_update = True
        self._no_wrap = not(value)

    @property
    def wrap_y(self):
        """
        Y position from which items start on wrapped columns.
        
        When items wrap to a second or later column, this value determines the
        vertical offset from the starting position. The value is in pixels
        and must be scaled if needed. The position is clamped to ensure items
        always start at a position >= 0 relative to the window content area.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._wrap_y

    @wrap_y.setter
    def wrap_y(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._wrap_y = value

    @property
    def positions(self):
        """
        Y positions for items when using MANUAL alignment mode.
        
        When in MANUAL mode, these are the y positions from the top left of this
        layout at which to place the children items.
        
        Values between 0 and 1 are interpreted as percentages relative to the
        layout height. Negative values are interpreted as relative to the bottom
        edge rather than the top. Items are still top-aligned to the target
        position.
        
        Setting this property automatically sets alignment_mode to MANUAL.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int i
        for i in range(<int>self._positions.size()):
            result.append(self._positions[i])
        return result

    @positions.setter
    def positions(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if len(value) > 0:
            self._alignment_mode = Alignment.MANUAL
        # TODO: checks
        self._positions.clear()
        for v in value:
            self._positions.push_back(v)
        self._force_update = True

    def update_layout(self):
        """
        Force an update of the layout next time the scene is rendered.
        
        This method triggers the recalculation of item positions and sizes 
        within the layout. It's useful when the automated update detection 
        is not sufficient to detect layout changes.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._force_update = True

    cdef float __compute_items_size(self, int32_t &n_items) noexcept nogil:
        cdef float size = 0.
        n_items = 0
        cdef PyObject *child = <PyObject*>self.last_widgets_child
        while (<uiItem>child) is not None:
            size += (<uiItem>child).state.cur.rect_size.y
            n_items += 1
            child = <PyObject*>((<uiItem>child).prev_sibling)
            if not((<uiItem>child).state.prev.rendered):
                # Will need to recompute layout after the size is computed
                self._force_update = True
        return size

    cdef void __update_layout_manual(self):
        """Position items at manually specified y positions"""
        # assumes children are locked and > 0
        cdef float available_height = self.state.cur.content_region_size.y
        cdef float pos_start = 0.
        cdef int32_t i = 0
        cdef PyObject *child = <PyObject*>self.last_widgets_child
        cdef bint pos_change = False

        # Get back to first child
        while (<uiItem>child).prev_sibling is not None:
            child = <PyObject*>((<uiItem>child).prev_sibling)

        # Position each item at specified y coordinate
        while (<uiItem>child) is not None:
            # Get position from positions list or default to 0
            if not(self._positions.empty()):
                pos_start = self._positions[min(i, <int>self._positions.size()-1)]

            # Convert relative (0-1) or negative positions
            if pos_start > 0.:
                if pos_start < 1.:
                    pos_start *= available_height
                    pos_start = floor(pos_start)
            elif pos_start < 0:
                if pos_start > -1.:
                    pos_start *= available_height 
                    pos_start += available_height
                    pos_start = floor(pos_start)
                else:
                    pos_start += available_height

            # Set item position and ensure it stays within bounds
            pos_start = max(0, pos_start)
            pos_change |= pos_start != (<uiItem>child).state.cur.pos_to_parent.y
            (<uiItem>child).requested_x.set_value(0)
            (<uiItem>child).requested_y.set_item_o(Size.ADD(Size.PARENT_Y1(), Size.FIXED(pos_start)))
            (<uiItem>child).no_newline = False

            child = <PyObject*>(<uiItem>child).next_sibling
            i += 1

        # Force update if positions changed
        if pos_change:
            self._force_update = True
            self.context.viewport.redraw_needed = True

    cdef void __update_layout(self):
        if self._alignment_mode == Alignment.MANUAL:
            self.__update_layout_manual()
            return
        # Assumes all children are locked
        cdef PyObject *child = <PyObject*>self.last_widgets_child
        cdef float end_y = self.state.cur.content_region_size.y
        cdef float available_height = end_y
        #cdef float available_width = self.state.cur.content_region_size.x
        cdef float spacing_x = self._spacing.x
        cdef float spacing_y = self._spacing.y
        # Get back to the first child
        while ((<uiItem>child).prev_sibling) is not None:
            child = <PyObject*>((<uiItem>child).prev_sibling)
        cdef PyObject *sibling
        cdef int32_t i, n_items_this_col, col
        cdef float target_y, expected_y, expected_size, expected_size_next
        cdef float x, next_x = 0
        cdef float wrap_y = max(-self.state.cur.pos_to_window.y, self._wrap_y)
        cdef bint pos_change = False
        cdef float global_scale_inv = 1./fmax(self.context.viewport.global_scale, 0.00001)
        col = 0
        while (<uiItem>child) is not None:
            # Compute the number of items in this column
            if col == 1:
                # starting from the second column, begin to wrap at the target
                available_height -= wrap_y
            x = next_x
            n_items_this_col = 1
            expected_size = (<uiItem>child).state.cur.rect_size.y
            next_x = (<uiItem>child).state.cur.rect_size.x
            sibling = child
            while (<uiItem>sibling).next_sibling is not None:
                # Does the next item fit?
                expected_size_next = expected_size + self._spacing.y + \
                    (<uiItem>(<uiItem>sibling).next_sibling).state.cur.rect_size.y
                # No: stop there
                if expected_size_next > available_height and not(self._no_wrap):
                    break
                expected_size = expected_size_next
                if not((<uiItem>sibling).state.cap.has_rect_size):
                    # Items without rect size (tooltips for instance) do not count in the layout
                    sibling = <PyObject*>(<uiItem>sibling).next_sibling
                    continue
                next_x = max(next_x, x + (<uiItem>sibling).state.cur.rect_size.x)
                sibling = <PyObject*>(<uiItem>sibling).next_sibling
                n_items_this_col += 1
            next_x = next_x + spacing_x

            # Determine the element positions
            sibling = child
            if self._alignment_mode == Alignment.TOP:
                target_y = 0 if col == 0 else wrap_y
            elif self._alignment_mode == Alignment.BOTTOM:
                target_y = end_y - expected_size
            elif self._alignment_mode == Alignment.CENTER:
                # Center right away (not waiting the second column) with wrap_y
                target_y = (end_y + wrap_y) // 2 - \
                    expected_size // 2 # integer rounding to avoid blurring
            else: #self._alignment_mode == Alignment.JUSTIFIED:
                target_y = 0 if col == 0 else wrap_y
                # Increase spacing to fit target space
                spacing_y = self._spacing.y + \
                    max(0, \
                        floor((available_height - expected_size) /
                               (n_items_this_col-1)))

            # Important for auto fit windows
            target_y = max(0 if col == 0 else wrap_y, target_y)

            expected_y = 0
            i = 0
            while i < n_items_this_col-1:
                if not((<uiItem>sibling).state.cap.has_rect_size):
                    # Items without rect size do not count in the layout
                    sibling = <PyObject*>(<uiItem>sibling).next_sibling
                    continue
                if col == 0:
                    # Use the default cursor
                    pos_change |= (<uiItem>sibling).requested_y.is_item() or\
                        (target_y - expected_y) * global_scale_inv != (<uiItem>sibling).requested_y.get_value()
                    (<uiItem>sibling).requested_x.set_value(0.) # default position
                    (<uiItem>sibling).requested_y.set_value((target_y - expected_y)*global_scale_inv) # delta to default position
                else:
                    # TODO: pos_change
                    # Use positions relative to the parent
                    (<uiItem>sibling).requested_x.set_item_o(Size.ADD(Size.PARENT_X1(), Size.FIXED(x)))
                    (<uiItem>sibling).requested_y.set_item_o(Size.ADD(Size.PARENT_Y1(), Size.FIXED(target_y)))
                (<uiItem>sibling).no_newline = False
                expected_y = target_y + self._spacing.y + (<uiItem>sibling).state.cur.rect_size.y
                target_y = target_y + spacing_y + (<uiItem>sibling).state.cur.rect_size.y
                sibling = <PyObject*>(<uiItem>sibling).next_sibling
                i = i + 1
            if i != 0:
                while (<uiItem>sibling).next_sibling is not None and \
                      not((<uiItem>sibling).state.cap.has_rect_size):
                    sibling = <PyObject*>(<uiItem>sibling).next_sibling
                    continue
            # Last item of the column
            if (self._alignment_mode == Alignment.BOTTOM or \
               (self._alignment_mode == Alignment.JUSTIFIED and n_items_this_col != 1)) and \
               (<uiItem>child).state.cur.rect_size.y == (<uiItem>child).state.prev.rect_size.y:
                # Align bottom item properly even if rounding
                # occurred on spacing.
                # We check the item size is fixed because if the item tries to autosize
                # to the available content, it can lead to convergence issues
                # undo previous spacing
                target_y -= spacing_y
                # ideal spacing
                spacing_y = \
                    end_y - (target_y + (<uiItem>sibling).state.cur.rect_size.y)
                # real spacing
                target_y += max(spacing_y, self._spacing.y)

            pos_change |= (<uiItem>sibling).requested_y.is_item() or\
                (target_y - expected_y) * global_scale_inv != (<uiItem>sibling).requested_y.get_value()
            if col == 0:
                (<uiItem>sibling).requested_x.set_value(0.) # default position
                (<uiItem>sibling).requested_y.set_value((target_y - expected_y)*global_scale_inv) # delta to default position
            else:
                (<uiItem>sibling).requested_x.set_item_o(Size.ADD(Size.PARENT_X1(), Size.FIXED(x)))
                (<uiItem>sibling).requested_y.set_item_o(Size.ADD(Size.PARENT_Y1(), Size.FIXED(target_y)))

            (<uiItem>sibling).no_newline = False
            child = <PyObject*>(<uiItem>sibling).next_sibling
            col += 1
        # A change in position change alter the size for some items
        if pos_change:
            self._force_update = True
            self.context.viewport.redraw_needed = True

    cdef bint draw_item(self) noexcept nogil:
        if self.last_widgets_child is None:
            return False
        self.update_content_area()
        cdef bint changed = self.check_change()
        if changed:
            self.last_widgets_child.lock_and_previous_siblings()
            with gil:
                self.__update_layout()
        imgui.PushID(self.uuid)
        imgui.BeginGroup()
        cdef Vec2 pos_p
        if self.last_widgets_child is not None:
            pos_p = ImVec2Vec2(imgui.GetCursorScreenPos())
            swap_Vec2(pos_p, self.context.viewport.parent_pos)
            self.draw_children()
            self.context.viewport.parent_pos = pos_p
        if changed:
            # We maintain the lock during the rendering
            # just to be sure the user doesn't change the
            # Positioning we took care to manage :-)
            self.last_widgets_child.unlock_and_previous_siblings()
        imgui.EndGroup()
        imgui.PopID()
        self.update_current_state()
        if self.state.cur.rect_size.x != self.state.prev.rect_size.x or \
           self.state.cur.rect_size.y != self.state.prev.rect_size.y:
            self._force_update = True
            self.context.viewport.redraw_needed = True
        return changed


cdef class WindowLayout(uiItem):
    """
    Same as Layout, but for windows.
    Unlike Layout, WindowLayout doesn't
    have any accessible state, except
    for the position and rect size.
    """
    def __cinit__(self):
        self.can_have_window_child = True
        self.element_child_category = child_type.cat_window
        self.can_be_disabled = False
        self._previous_last_child = NULL
        self.state.cap.has_content_region = True

    def update_layout(self):
        cdef int32_t i
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        for i in range(<int>self._callbacks.size()):
            self.context.queue_callback_arg1value(<Callback>self._callbacks[i], self, self, self._value)

    # final enables inlining
    @cython.final
    cdef Vec2 update_content_area(self) noexcept nogil:
        cdef Vec2 full_content_area = self.context.viewport.parent_size
        cdef Vec2 cur_content_area, requested_size

        full_content_area.x -= self.state.cur.pos_to_parent.x
        full_content_area.y -= self.state.cur.pos_to_parent.y

        requested_size = self.get_requested_size()

        if requested_size.x == 0:
            cur_content_area.x = full_content_area.x
        elif requested_size.x < 0:
            cur_content_area.x = full_content_area.x + requested_size.x
        else:
            cur_content_area.x = requested_size.x

        if requested_size.y == 0:
            cur_content_area.y = full_content_area.y
        elif requested_size.y < 0:
            cur_content_area.y = full_content_area.y + requested_size.y
        else:
            cur_content_area.y = requested_size.y

        cur_content_area.x = max(0, cur_content_area.x)
        cur_content_area.y = max(0, cur_content_area.y)
        self.state.cur.content_region_size = cur_content_area
        return cur_content_area

    cdef bint check_change(self) noexcept nogil:
        cdef Vec2 cur_content_area = self.state.cur.content_region_size
        cdef Vec2 prev_content_area = self.state.prev.content_region_size
        cdef bint changed = self.requested_height.has_changed()
        if self.requested_width.has_changed():
            changed = True
        if cur_content_area.x != prev_content_area.x or \
           cur_content_area.y != prev_content_area.y or \
           self._previous_last_child != <PyObject*>self.last_window_child or \
           self._force_update or changed:
            changed = True
            self._previous_last_child = <PyObject*>self.last_window_child
            self._force_update = False
        return changed

    @cython.final
    cdef void draw_child(self, uiItem child) noexcept nogil:
        #if isinstance(child, Window):
        #    (<Window>child).pos_update_requested = True -> handled by user setting the position
        child.draw()
        if child.state.cur.rect_size.x != child.state.prev.rect_size.x or \
           child.state.cur.rect_size.y != child.state.prev.rect_size.y or \
           child.state.cur.pos_to_viewport.x != child.state.prev.pos_to_viewport.x or \
           child.state.cur.pos_to_viewport.y != child.state.prev.pos_to_viewport.y:
            child.context.viewport.redraw_needed = True
            self._force_update = True

    @cython.final
    cdef void draw_children(self) noexcept nogil:
        """
        Similar to draw_ui_children, but detects
        any change relative to expected sizes
        """
        if self.last_window_child is None:
            return
        cdef Vec2 parent_size_backup = self.context.viewport.parent_size
        self.context.viewport.parent_size = self.state.cur.content_region_size
        cdef Vec2 pos_min, pos_max
        pos_min = self.context.viewport.get_size()
        pos_max = make_Vec2(0, 0)
        cdef PyObject *child = <PyObject*> self.last_window_child
        while (<uiItem>child).prev_sibling is not None:
            child = <PyObject *>(<uiItem>child).prev_sibling
        while (<uiItem>child) is not None:
            self.draw_child(<uiItem>child)
            pos_min.x = min(pos_min.x, (<uiItem>child).state.cur.pos_to_viewport.x)
            pos_min.y = min(pos_min.y, (<uiItem>child).state.cur.pos_to_viewport.y)
            pos_max.x = max(pos_max.x, (<uiItem>child).state.cur.pos_to_viewport.x + (<uiItem>child).state.cur.rect_size.x)
            pos_max.y = max(pos_max.y, (<uiItem>child).state.cur.pos_to_viewport.y + (<uiItem>child).state.cur.rect_size.y)
            child = <PyObject *>(<uiItem>child).next_sibling
        self.state.cur.rect_size.x = pos_max.x - self.state.cur.pos_to_viewport.x #pos_min.x
        self.state.cur.rect_size.y = pos_max.y - self.state.cur.pos_to_viewport.y #pos_min.y
        self.context.viewport.parent_size = parent_size_backup

    cdef void __update_layout(self) noexcept nogil:
        cdef int32_t i

        with gil:
            for i in range(<int>self._callbacks.size()):
                self.context.queue_callback_arg1value(<Callback>self._callbacks[i], self, self, self._value)

    cdef void draw(self) noexcept nogil:
        if self.last_window_child is None:
            return
        self.update_content_area()
        cdef bint changed = self.check_change()
        if changed:
            self.last_window_child.lock_and_previous_siblings()
            self.__update_layout()

        cdef Vec2 pos_p
        cdef Vec2 pos = self.context.viewport.parent_pos
        cdef Vec2 pos_to_parent
        pos_to_parent.x = resolve_size(self.requested_x, self)
        pos_to_parent.y = resolve_size(self.requested_y, self)
        pos.x = pos.x + pos_to_parent.x
        pos.y = pos.y + pos_to_parent.y
        if self.last_window_child is not None:
            pos_p = pos
            swap_Vec2(pos_p, self.context.viewport.parent_pos)
            self.context.viewport.window_pos = self.context.viewport.parent_pos
            self.draw_children()
            self.context.viewport.parent_pos = pos_p
            self.context.viewport.window_pos = pos_p

        if changed:
            self.last_window_child.unlock_and_previous_siblings()

        self.state.cur.pos_to_window = pos_to_parent
        self.state.cur.pos_to_parent = pos_to_parent
        self.state.cur.pos_to_viewport = pos

