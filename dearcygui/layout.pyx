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
from .callback_values cimport uiItemCallbackNoneValue
from .imgui_types cimport ImVec2Vec2, Vec2ImVec2
from .sizing cimport resolve_size
from .types cimport child_type
from .wrapper cimport imgui

from warnings import warn as _warn

cdef class Layout(uiItem):
    """
    A layout is a group of elements organized together.
    
    The layout states correspond to the OR of all the item states, and the rect 
    size corresponds to the minimum rect containing all the items. The position 
    of the layout is used to initialize the default position for the first item.
    An indentation will shift all the items of the Layout.

    ## Subclassing `Layout`:

    As layout can hold several objects, subclassing `Layout` can be used to 
    implement containers composed of several items. `ChildWindow` can be
    used as well. Visually `Layout` is comparable to a `ChildWindow` created with
    without border, scrollbars and padding, but with subtle differences:
    * ```
    ChildWindow(
        context,
        auto_resize_x=True,
        auto_resize_y=True,
        border=False,
        flattened_navigation=True,
        no_background=True,
        no_scroll_with_mouse=True,
        no_scrollbar=True
        )
      ``` behaves similarly to `Layout(context)`. Both visually have no difference
        to whether the items were directly added to the parent container rather
        than the `Layout`/`ChildWindow`.
    * When setting a width/height on a `Layout`, they affect the content area
       seen as available by child items. For instance 'dcg.Slider(context, width=-1)'
       will fill available space as defined by the parent Layout. On the other hand,
       the real height/width advertised by the `Layout` will always correspond
       to the minimum bounding box containing the items, regardless of the width/height set
       on the `Layout`. Note for this reason prefer `"fillx"`, `"fullx"`, etc, which refer
       to the content area, rather than `"parent.height"`, etc when specifying sizes
       for child items.
       In other words, in regard to the size of the `Layout` advertised, the behaviour
       corresponds to `ChildWindow`'s `auto_resize_x` and `auto_resize_y` parameters
       being always True. However the size available inside the `Layout` corresponds
       to the requested width/height.
       Unlike `ChildWindow`, the content will not be clipped and may overflow the
       requested width/height.
    * In contrast, when setting a width/height on a `ChildWindow`, this affects both the
      content area seen by children and the real height/width of the `ChildWindow`. If
      the content exceeds the size, it will be clipped or scrollbars will appear depending on
      the scrollbar settings.

    Due to the above difference, `ChildWindow` is more suitable when you want to enforce
    a specific size or to clip overflowing content. In the other cases, `Layout` offers
    a lighter-weight alternative.

    ## Layout update

    One interest of `Layout̀` is in its subclasses such as `HorizontalLayout` or
    `VerticalLayout` which automatically organize the position of their children.
    All three share a similar implementation to detect changes in the layout that
    justify a recomputation of the position of the children. If using `Layout`
    directly, the user can implement their own logic by attaching a callback. 
    The callback is triggered when the layout needs to update the position of the children.
    If this logic is not sufficient, the user can manually trigger an update by calling `update_layout()`.
    Currently the detection logic consists of checking for a change in the size of the remaining 
    content area available locally within the window, or whether the size of child items changed,
    or if the last item has changed. It also checks for changes in the spacing style, which can
    affect the layout. This logic may be improved in the future.

    ## Positioning of children

    Layout items work by changing the x, y and no_newline fields
    of its children, and thus there is no guarantee that the user set
    x, y and no_newline fields of the children are preserved.
    When using `Layout` directly, the user is responsible for
    setting the x, y and no_newline fields of the children. When using
    `HorizontalLayout` or `VerticalLayout`, the x, y and no_newline fields
    of the children are managed by the layout. In this case,
    the user values for these fields on the children will be overridden
    by the layout's logic.

    ## Removing items from the layout

    As said above, the contents of an item x, y and no_newline fields are not managed by DearCyGui
    for `Layout` but are managed for `HorizontalLayout` and `VerticalLayout`. For them,
    the values are managed and undefined. They may differ from a DearCyGui version to
    another. Thus if an item is moved out of the layout, the user has to manually
    set the x, y and no_newline fields of the item to their new desired values.

    ## Size of the layout

    As mentioned above, the size of a layout always corresponds to the minimum
    bounding box containing the items, regardless of the width/height set on the `Layout`.
    The content area available for the children is defined by the width/height set on
    the `Layout` and is independent of the real size of the `Layout`. Be careful
    of this fact and avoid `parent.width` and `parent.height` when specifying sizes
    or positions for children, prefer `"fillx"`, `"fullx"`, etc, which refer to the content area.

    By default, width=0 and height=0, which for `Layout` and subclasses are interpreted as
    width="fillx" and height="filly". In other words, the full remaining area available
    in the parent is advertised as available to the children.

    It is possible to have larger content area than real size and vice versa.

    If you intend to force a specific size, use a `ChildWindow`. 
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
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._force_update = True

    # final enables inlining
    @cython.final
    cdef Vec2 update_content_area(self) noexcept nogil:
        """
        Update the content area size based on the requested width/height
        and the remaining space in the parent.
        """
        # Retrieve fillx/filly area
        cdef Vec2 full_content_area = self.context.viewport.parent_size
        full_content_area.x -= self.state.cur.pos_to_parent.x
        full_content_area.y -= self.state.cur.pos_to_parent.y

        # Fetch requested content area size
        cdef Vec2 requested_size = self.get_requested_size()

        # Interpret zero/negative values as "fill" from the right/bottom
        cdef Vec2 cur_content_area
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

        # Clamp to ensure non-negative content area. A larger
        # content area than the real size is allowed.
        cur_content_area.x = fmax(0., cur_content_area.x)
        cur_content_area.y = fmax(0., cur_content_area.y)

        # Set the content area for this frame
        self.state.cur.content_region_size = cur_content_area

        # Also update content_pos (Layout/HorizontalLayout/VerticalLayout
        # only, not ChildWindow) to match pos_to_viewport (filled before draw_item)
        self.state.cur.content_pos = self.state.cur.pos_to_viewport
        return cur_content_area

    cdef bint check_change(self) noexcept nogil:
        """
        Check if the layout has changed since the last frame.
        """
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
        # Draw the child
        child.draw()

        # If the size of the child changed, mark for redraw. Indeed
        # the size of the layout may be affected, which might
        # change other items including the layout.
        if child.state.cur.rect_size.x != child.state.prev.rect_size.x or \
           child.state.cur.rect_size.y != child.state.prev.rect_size.y:
            child.context.viewport.ask_immediate_redraw()
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
        if self.last_widgets_child is None:
            return False

        # Note: when the item is not visible, it may get an empty
        # content area (cur_content_area.x <= 0 or cur_content_area.y <= 0).
        # We might want to call set_hidden_no_handler_and_propagate_to_children_with_handlers
        # in this case.

        # Compute the content area
        self.update_content_area()

        # Check whether the callback should be called
        # and reset _force_update
        cdef bint changed = self.check_change()

        # Pack the children inside a group to get
        # the correct states
        imgui.PushID(self.uuid)
        imgui.BeginGroup()
        cdef Vec2 pos_p
        if self.last_widgets_child is not None:
            pos_p = ImVec2Vec2(imgui.GetCursorScreenPos())
            swap_Vec2(pos_p, self.context.viewport.parent_pos)
            self.draw_children()
            self.context.viewport.parent_pos = pos_p
        imgui.EndGroup()
        imgui.PopID()

        # Update states by reading from the group.
        self.update_current_state()
        return changed

cdef class HorizontalLayout(Layout):
    """
    A layout that organizes items horizontally from left to right.
    
    HorizontalLayout arranges child elements in a row, with customizable 
    alignment modes, spacing, and wrapping options. It can align items to 
    the left or right edge, center them, distribute them evenly using the
    justified mode.
    
    The layout automatically tracks content width changes and repositions 
    children when needed. Wrapping behavior can be customized to control 
    how items overflow when they exceed available width.

    The `height` attribute attribute does not affect the horizontal layout
    algorithm, but does set the content area height available for
    children's sizing expressions.
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
        if <int>value < 0 or value > Alignment.JUSTIFIED:
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

    cdef bint __check_children_neutral(self) noexcept nogil:
        """
        Returns True if all children are already in neutral positioning state:
        no_newline=False, requested_x/y stored as plain float values (not items),
        and both equal zero.  Any item that deviates causes False to be returned
        so that __apply_children_neutral can clean up stale overrides.

        The logic is split from __apply_children_neutral to allow
        for faster run times (__apply_children_neutral being expected
        to be rarely called). In addition __check_children_neutral
        doesn't require GIL.
        """
        if self.last_widgets_child is None:
            return True

        # Walk backwards to the first sibling
        cdef PyObject *child = <PyObject*>self.last_widgets_child
        while (<uiItem>child).prev_sibling is not None:
            child = <PyObject*>(<uiItem>child).prev_sibling

        # Check every child for any positioning override
        while (<uiItem>child) is not None:
            if (<uiItem>child).no_newline or \
               (<uiItem>child).requested_x.is_item() or \
               (<uiItem>child).requested_y.is_item() or \
               (<uiItem>child).requested_x.get_value() != 0. or \
               (<uiItem>child).requested_y.get_value() != 0.:
                return False
            child = <PyObject*>(<uiItem>child).next_sibling
        return True

    cdef void __apply_children_neutral(self):
        """
        Reset all children to neutral positioning state (no overrides).
        Requires the GIL because set_value() may call Python code.
        """
        if self.last_widgets_child is None:
            return

        # Walk backwards to the first sibling
        cdef PyObject *child = <PyObject*>self.last_widgets_child
        while (<uiItem>child).prev_sibling is not None:
            child = <PyObject*>(<uiItem>child).prev_sibling

        # Clear every positioning override
        while (<uiItem>child) is not None:
            (<uiItem>child).no_newline = False
            (<uiItem>child).requested_x.set_value(0.)
            (<uiItem>child).requested_y.set_value(0.)
            child = <PyObject*>(<uiItem>child).next_sibling

    cdef bint __draw_item_left_no_wrap(self) noexcept nogil:
        """
        LEFT alignment, no wrapping: draw items left-to-right using SameLine.
        Fast path for the most common HorizontalLayout configuration.
        SameLine is skipped after zero-size / hidden items to avoid spurious gaps.
        """
        # Walk backwards to the first sibling
        cdef PyObject *child = <PyObject*>self.last_widgets_child
        while (<uiItem>child).prev_sibling is not None:
            child = <PyObject*>(<uiItem>child).prev_sibling

        cdef float spacing_x = imgui.GetStyle().ItemSpacing.x
        cdef float cursor_y_before  # sampled before draw to detect vertical advancement
        cdef bint changed = False
        cdef bint first_item_drawn = False  # True after a visible item moved the cursor down

        while (<uiItem>child) is not None:
            # Stay on the same row as the previous item.
            # The first_item_drawn condition helps prevent applying spacing_x
            # before the first item.
            # Note the last SameLine call overwrites the previous one.
            if first_item_drawn:
                imgui.SameLine(0., spacing_x)

            # Catch original y cursor
            cursor_y_before = imgui.GetCursorScreenPos().y

            # Draw the item
            (<uiItem>child).draw()

            # Track size changes so the parent knows to redraw next frame
            if (<uiItem>child).state.cur.rect_size.x != (<uiItem>child).state.prev.rect_size.x or \
               (<uiItem>child).state.cur.rect_size.y != (<uiItem>child).state.prev.rect_size.y:
                changed = True

            # Check if anything moved the cursor (Tooltip or items with show=False don't)
            if not first_item_drawn:
                first_item_drawn = imgui.GetCursorScreenPos().y > cursor_y_before
            child = <PyObject*>(<uiItem>child).next_sibling
        return changed

    cdef bint __draw_item_left_wrap(self) noexcept nogil:
        """
        LEFT alignment, wrapping enabled: draw items left-to-right, starting a
        new row when the next item would exceed the available width.
        No-size items (tooltips etc.) are kept on the current line with zero
        spacing so they don't trigger spurious row breaks.
        """
        # Walk backwards to the first sibling
        cdef PyObject *child = <PyObject*>self.last_widgets_child
        while (<uiItem>child).prev_sibling is not None:
            child = <PyObject*>(<uiItem>child).prev_sibling

        # Retrieve horizontal spacing
        cdef float spacing_x = imgui.GetStyle().ItemSpacing.x

        # Retrieve min/max x bounds
        cdef float parent_start_x = self.context.viewport.parent_pos.x
        cdef float end_x = parent_start_x + self.state.cur.content_region_size.x

        # Deduce wrapping start region.
        # First row starts at parent_start_x; wrapped rows start at wrap_start_x.
        cdef float wrap_start_x = parent_start_x + fmax(-self.state.cur.pos_to_window.x, 0.)
        wrap_start_x = fmax(parent_start_x, wrap_start_x)

        cdef float cursor_y_before # Y coordinate before drawing the item
        cdef bint changed = False
        cdef bint first_item_drawn = False  # True after a visible item moved the cursor down
        cdef bint first_item_on_row_drawn = False  # True after a visible item moved the cursor down for this row
        cdef bint has_sz  # whether the current child has a rect size

        while (<uiItem>child) is not None:
            # Tooltips have no size.
            has_sz = (<uiItem>child).state.cap.has_rect_size

            # If the previous item moved y (not same line), use SameLine
            # to keep on the same line, unless we need to wrap.
            # first_item_on_row_drawn enables to avoid applying spacing_x
            # before any item is drawn on a row..
            if first_item_on_row_drawn:
                imgui.SameLine(0., spacing_x)

                # Change line if item doesn't fit (wrapping)
                if has_sz and \
                   imgui.GetCursorScreenPos().x + (<uiItem>child).state.cur.rect_size.x > end_x:
                    # Item doesn't fit: move to next line
                    # Cancel previous sameline
                    # NOTE: we cancel rather than
                    # skipping the above SameLine call
                    # because we need to handle previous SameLine
                    # called that weren't followed by an actual item
                    # drawn (SameLine overwrites previous calls).
                    # This simplifies end_x tracking (becomes imgui.GetCursorScreenPos().x)
                    imgui.SameLine(0., 0.)
                    imgui.Dummy(imgui.ImVec2(0., 0.))

                    # Reposition x to the wrap indent when one is configured.
                    if -self.state.cur.pos_to_window.x > 0.:
                        imgui.SetCursorScreenPos(
                            imgui.ImVec2(
                                wrap_start_x,
                                imgui.GetCursorScreenPos().y
                            )
                        )

                    # Reset row statistics
                    first_item_on_row_drawn = False

            # Retrieve y before the item is drawn
            cursor_y_before = imgui.GetCursorScreenPos().y

            # Draw the item
            (<uiItem>child).draw()

            # Track whether the item size changed, in which case we trigger a redraw (for size convergence)
            if (<uiItem>child).state.cur.rect_size.x != (<uiItem>child).state.prev.rect_size.x or \
               (<uiItem>child).state.cur.rect_size.y != (<uiItem>child).state.prev.rect_size.y:
                changed = True

            # Track whether anything was drawn and moved the cursor.
            if imgui.GetCursorScreenPos().y > cursor_y_before:
                first_item_drawn = True
                first_item_on_row_drawn = True
            else:
                # If the jumped line but nothing was drawn (show=False for instance), undo the line break.
                if first_item_drawn:
                    first_item_on_row_drawn = True

            # Move on to next child
            child = <PyObject*>(<uiItem>child).next_sibling
        return changed

    cdef bint __draw_item_aligned(self) noexcept nogil:
        """
        RIGHT / CENTER / JUSTIFIED alignment.

        Items are grouped into rows by a pre-pass that uses the previous
        frame's rect_sizes to predict which items fit on each row.  The
        pre-pass totals each row's width so the alignment offset can be
        computed before any drawing begins.

        For JUSTIFIED, inter-item spacing is widened to fill the row.
        The last item on a RIGHT/JUSTIFIED row is snapped to end_x once
        its size stabilises, absorbing accumulated floor() rounding error.

        Hidden items (show=False) have state.cur.traversed set to False by
        _update_current_state_as_hidden, so the pre-pass uses traversed as a
        visibility proxy.  Items that were drawn off-screen last frame still
        have traversed=True (draw() was called) and their rect_size was set by
        ImGui's ItemAdd even when clipped, allowing RIGHT/CENTER/JUSTIFIED
        layouts to converge in two frames even on the very first render.
        Any rect_size or rendered change triggers a forced redraw so the
        pre-pass re-evaluates with the new sizes.  In the draw pass,
        cursor-advancement detection (same technique as __draw_item_left_wrap)
        ensures hidden items do not corrupt the first_on_row flag or leave a
        dangling SameLine at the end of a row.
        """
        # Walk backwards to the first sibling
        cdef PyObject *child = <PyObject*>self.last_widgets_child
        while (<uiItem>child).prev_sibling is not None:
            child = <PyObject*>(<uiItem>child).prev_sibling

        # Retrieve horizontal spacing
        cdef float spacing_x = imgui.GetStyle().ItemSpacing.x

        # Retrieve min/max x bounds
        cdef float parent_start_x = self.context.viewport.parent_pos.x
        cdef float end_x = parent_start_x + self.state.cur.content_region_size.x
        cdef float available_width = self.state.cur.content_region_size.x

        # Deduce wrapping start region.
        # First row starts at parent_start_x; wrapped rows start at wrap_start_x.
        cdef float wrap_start_x = parent_start_x + fmax(-self.state.cur.pos_to_window.x, 0.)
        wrap_start_x = fmax(parent_start_x, wrap_start_x)

        cdef bint changed = False
        cdef bint is_first_row = True
        cdef float cur_y = imgui.GetCursorScreenPos().y  # screen-y of the current row's top

        # Loop variables: declared here because Cython forbids cdef inside loops.
        cdef float row_avail      # available width for this row
        cdef float row_sx         # screen-x start of this row
        cdef float expected_size  # sum of widths (+spacings) on this row (pre-pass, visible only)
        cdef float sz             # one item's width
        cdef float next_sz        # tentative expected_size after adding one more item
        cdef int32_t n_with_size  # count of visible has_rect_size items on this row
        cdef PyObject *last_with_size  # last visible has_rect_size item on this row
        cdef PyObject *s          # iteration cursor used in both passes
        cdef PyObject *row_end    # first item of the next row (None = end of list)
        cdef float target_x       # screen-x where this row begins drawing
        cdef float row_spacing_x  # per-gap spacing (wider for JUSTIFIED)
        cdef bint first_on_row    # True until the first visible has_rect_size item is placed
        cdef bint has_sz          # current item's has_rect_size flag
        cdef float cursor_y_before  # cursor y sampled before each draw, to detect advancement

        cdef PyObject *row_start = child
        while (<uiItem>row_start) is not None:
            # Width budget: first row uses full content width; wrapped rows use
            # the narrower region starting at wrap_start_x.
            row_avail = available_width if is_first_row else (end_x - wrap_start_x)
            row_sx = parent_start_x if is_first_row else wrap_start_x

            # Pre-pass: walk siblings to determine which items belong to this row
            # and sum their widths.  state.cur.traversed is False for hidden items
            # (zeroed by _update_current_state_as_hidden when show=False), and also
            # False for brand-new items that have never been drawn.  Using traversed
            # (rather than rendered) means that items drawn off-screen in the previous
            # frame (traversed=True, rendered=False) are still included here with their
            # actual rect_size, allowing RIGHT/CENTER/JUSTIFIED layouts to converge in
            # two frames even on the very first render.  Note: rect_size is NOT reset
            # to zero on hide, so sz alone is not a reliable proxy for visibility.
            # The row-break condition uses n_with_size (traversed items only), so
            # hidden items never cause a row break by themselves.
            expected_size = 0.
            n_with_size = 0
            last_with_size = NULL
            s = row_start
            while (<uiItem>s) is not None:
                if (<uiItem>s).state.cap.has_rect_size and (<uiItem>s).state.cur.traversed:
                    sz = (<uiItem>s).state.cur.rect_size.x
                    next_sz = expected_size + (spacing_x if n_with_size > 0 else 0.) + sz
                    # Overflow: stop here (only when wrapping is allowed)
                    if not(self._no_wrap) and next_sz > row_avail and n_with_size > 0:
                        break
                    expected_size = next_sz
                    n_with_size += 1
                    last_with_size = s
                s = <PyObject*>(<uiItem>s).next_sibling
            # s is None (end of list) or the first item that starts the next row
            row_end = s

            # Compute the row's start x and per-gap spacing
            row_spacing_x = spacing_x
            if self._alignment_mode == Alignment.RIGHT:
                target_x = max(row_sx, end_x - expected_size)
            elif self._alignment_mode == Alignment.CENTER:
                target_x = row_sx + floor((row_avail - expected_size) / 2.)
                target_x = max(row_sx, target_x)
            else:  # JUSTIFIED
                target_x = row_sx
                if n_with_size > 1:
                    # Spread the extra space evenly; floor() avoids overshoot
                    row_spacing_x = spacing_x + max(0., floor(
                        (row_avail - expected_size) / (n_with_size - 1)))

            # Position the ImGui cursor at the row's starting point
            imgui.SetCursorScreenPos(imgui.ImVec2(target_x, cur_y))

            # Draw pass: emit items with SameLine/SetCursorScreenPos between items.
            # The last RIGHT/JUSTIFIED item is snapped to end_x when its size is stable.
            # Cursor advancement (cursor_y_before vs after) is used to decide whether
            # an item was actually drawn, matching the __draw_item_left_wrap technique:
            # hidden items do not flip first_on_row and leave the row state consistent.
            s = row_start
            first_on_row = True
            while s is not row_end:
                has_sz = (<uiItem>s).state.cap.has_rect_size

                if not first_on_row:
                    if has_sz:
                        if s == last_with_size and n_with_size > 1 and \
                           (self._alignment_mode == Alignment.RIGHT or
                            self._alignment_mode == Alignment.JUSTIFIED) and \
                           (<uiItem>s).state.cur.rect_size.x == (<uiItem>s).state.prev.rect_size.x:
                            # Snap right edge to end_x (eliminates floor() rounding error).
                            # Use cur_y explicitly: GetCursorScreenPos().y may be wrong here
                            # because a previous SameLine call restores y to cur_y, but if
                            # no SameLine was called (e.g. after a visible item drew and
                            # advanced the cursor), y would be the next-row y.
                            imgui.SetCursorScreenPos(imgui.ImVec2(
                                end_x - (<uiItem>s).state.cur.rect_size.x,
                                cur_y))
                        else:
                            imgui.SameLine(0., row_spacing_x)
                    else:
                        # No-size items (tooltips etc.): attach inline, no gap
                        imgui.SameLine(0., 0.)

                cursor_y_before = imgui.GetCursorScreenPos().y
                (<uiItem>s).draw()

                # Track size changes so the parent knows to redraw next frame
                if (<uiItem>s).state.cur.rect_size.x != (<uiItem>s).state.prev.rect_size.x or \
                   (<uiItem>s).state.cur.rect_size.y != (<uiItem>s).state.prev.rect_size.y or \
                   (<uiItem>s).state.cur.rendered != (<uiItem>s).state.prev.rendered:
                    changed = True

                # Only mark the row as having a visible item when the cursor
                # actually advanced (i.e. ItemSize was called).  Hidden items
                # (show=False) return early from draw() without calling ItemSize,
                # so the cursor does not move and first_on_row is left unchanged.
                if imgui.GetCursorScreenPos().y > cursor_y_before:
                    first_on_row = False

                s = <PyObject*>(<uiItem>s).next_sibling

            # If the row ended with a hidden item, SameLine will have pulled the
            # cursor back to cur_y.  Commit the row now so that cur_y advances to
            # the correct next-row position.  SameLine(0,0) resets CursorPos.x to
            # the last visible item's right edge; Dummy(0,0) then calls ItemSize
            # with IsSameLine=true, which uses CurrLineSize.y (the max row height
            # preserved by SameLine) to advance the cursor past the row.
            if not first_on_row and not (imgui.GetCursorScreenPos().y > cur_y):
                imgui.SameLine(0., 0.)
                imgui.Dummy(imgui.ImVec2(0., 0.))

            # After the row ImGui's cursor is on the next line; record its y
            cur_y = imgui.GetCursorScreenPos().y
            row_start = row_end
            is_first_row = False
        return changed

    cdef bint draw_item(self) noexcept nogil:
        if self.last_widgets_child is None:
            return False

        # Compute available content area from parent context and requested size
        self.update_content_area()

        # Capture _force_update before clearing it so that update_layout() callers
        # trigger callbacks even when the layout is otherwise stable this frame.
        cdef bint forced = self._force_update
        self._force_update = False
        cdef bint children_changed = False

        imgui.PushID(self.uuid)
        imgui.BeginGroup()

        # Expose this layout's content area as the parent context so that children
        # can resolve sizing expressions like "fillx", "fullx", etc.
        cdef Vec2 parent_size_backup = self.context.viewport.parent_size
        cdef Vec2 parent_pos_backup = self.context.viewport.parent_pos
        self.context.viewport.parent_size = self.state.cur.content_region_size
        self.context.viewport.parent_pos = ImVec2Vec2(imgui.GetCursorScreenPos())

        # Lock all siblings for the entire draw to prevent concurrent modification
        # of child positions while ImGui draw calls are being emitted.
        self.last_widgets_child.lock_and_previous_siblings()

        # Clear any stale positioning overrides left by previous code paths
        # The current implementation relies on SetCursorScreenPos and SameLine,
        # rather than per-item string positioning. This enables to react more
        # gracefully if the size of an item differs from what is expected.
        # It also simplifies the handling of items with no size (e.g. tooltips)
        # which should be attached to the previous item but should not induce
        # spacing.
        if not(self.__check_children_neutral()):
            with gil:
                self.__apply_children_neutral()

        # Dispatch to the appropriate inline drawing strategy
        if self._alignment_mode == Alignment.LEFT:
            if self._no_wrap:
                children_changed = self.__draw_item_left_no_wrap()
            else:
                children_changed = self.__draw_item_left_wrap()
        else:  # RIGHT, CENTER, JUSTIFIED
            children_changed = self.__draw_item_aligned()

        self.last_widgets_child.unlock_and_previous_siblings()

        imgui.EndGroup()
        imgui.PopID()

        # Restore parent context so siblings drawn after us see the correct values
        self.context.viewport.parent_size = parent_size_backup
        self.context.viewport.parent_pos = parent_pos_backup

        # EndGroup + update_current_state records the actual bounding box
        self.update_current_state()

        # If our bounding box changed, the parent layout must also re-evaluate
        if self.state.cur.rect_size.x != self.state.prev.rect_size.x or \
           self.state.cur.rect_size.y != self.state.prev.rect_size.y:
            self.context.viewport.ask_immediate_redraw()

        # If child bounding boxes actually changed, schedule one more redraw so
        # alignment/justification can converge.  We only set _force_update when
        # children genuinely changed this frame — not when we merely consumed a
        # prior _force_update — to prevent an infinite redraw loop.
        if children_changed:
            self._force_update = True
            self.context.viewport.ask_immediate_redraw()

        return forced | children_changed

cdef class VerticalLayout(Layout):
    """
    A layout that organizes items vertically from top to bottom.
    
    VerticalLayout arranges child elements in a column, with customizable 
    alignment modes, spacing, and wrapping options. It can align items to 
    the top or bottom edge, center them, distribute them evenly using the
    justified mode.
    
    The layout automatically tracks content height changes and repositions 
    children when needed. Wrapping behavior can be customized to control 
    how items overflow when they exceed available height.

    The `width` attribute does not affect the vertical layout algorithm,
    but does set the content area width available for children's
    sizing expressions.
    """
    def __cinit__(self):
        self._alignment_mode = Alignment.TOP
        self._no_wrap = True

    @property
    def alignment_mode(self):
        """
        Vertical alignment mode of the items.
        
        TOP: items are appended from the top
        BOTTOM: items are appended from the bottom
        CENTER: items are centered
        JUSTIFIED: spacing is organized such that items start at the top 
            and end at the bottom
        
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
        if <int>value < 0 or value > Alignment.JUSTIFIED:
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

    cdef bint __check_children_neutral(self) noexcept nogil:
        """
        Returns True if all children are already in neutral positioning state:
        no_newline=False, requested_x/y stored as plain float values (not items),
        and both equal zero.  Any item that deviates causes False to be returned
        so that __apply_children_neutral can clean up stale overrides.

        The logic is split from __apply_children_neutral to allow
        for faster run times (__apply_children_neutral being expected
        to be rarely called). In addition __check_children_neutral
        doesn't require GIL.
        """
        if self.last_widgets_child is None:
            return True

        # Walk backwards to the first sibling
        cdef PyObject *child = <PyObject*>self.last_widgets_child
        while (<uiItem>child).prev_sibling is not None:
            child = <PyObject*>(<uiItem>child).prev_sibling

        # Check every child for any positioning override
        while (<uiItem>child) is not None:
            if (<uiItem>child).no_newline or \
               (<uiItem>child).requested_x.is_item() or \
               (<uiItem>child).requested_y.is_item() or \
               (<uiItem>child).requested_x.get_value() != 0. or \
               (<uiItem>child).requested_y.get_value() != 0.:
                return False
            child = <PyObject*>(<uiItem>child).next_sibling
        return True

    cdef void __apply_children_neutral(self):
        """
        Reset all children to neutral positioning state (no overrides).
        Requires the GIL because set_value() may call Python code.
        """
        if self.last_widgets_child is None:
            return

        # Walk backwards to the first sibling
        cdef PyObject *child = <PyObject*>self.last_widgets_child
        while (<uiItem>child).prev_sibling is not None:
            child = <PyObject*>(<uiItem>child).prev_sibling

        # Clear every positioning override
        while (<uiItem>child) is not None:
            (<uiItem>child).no_newline = False
            (<uiItem>child).requested_x.set_value(0.)
            (<uiItem>child).requested_y.set_value(0.)
            child = <PyObject*>(<uiItem>child).next_sibling

    cdef bint __draw_item_top_no_wrap(self) noexcept nogil:
        """
        TOP alignment, no wrapping: items stack top-to-bottom sequentially.
        Fast path for the most common VerticalLayout configuration.
        ImGui's natural cursor advancement handles all positioning.
        """
        # Walk backwards to the first sibling
        cdef PyObject *child = <PyObject*>self.last_widgets_child
        while (<uiItem>child).prev_sibling is not None:
            child = <PyObject*>(<uiItem>child).prev_sibling

        cdef bint changed = False

        while (<uiItem>child) is not None:
            (<uiItem>child).draw()

            # Track size changes so the parent knows to redraw next frame
            if (<uiItem>child).state.cur.rect_size.x != (<uiItem>child).state.prev.rect_size.x or \
               (<uiItem>child).state.cur.rect_size.y != (<uiItem>child).state.prev.rect_size.y:
                changed = True

            child = <PyObject*>(<uiItem>child).next_sibling
        return changed

    cdef bint __draw_item_top_wrap(self) noexcept nogil:
        """
        TOP alignment, wrapping enabled: draw items top-to-bottom, starting a
        new column when the next item would exceed the available height.
        No-size items (tooltips etc.) do not advance the vertical flow and must
        not trigger spurious column breaks for the next visible item.
        """
        # Walk backwards to the first sibling
        cdef PyObject *child = <PyObject*>self.last_widgets_child
        while (<uiItem>child).prev_sibling is not None:
            child = <PyObject*>(<uiItem>child).prev_sibling

        # Retrieve item spacing
        cdef float spacing_x = imgui.GetStyle().ItemSpacing.x
        cdef float spacing_y = imgui.GetStyle().ItemSpacing.y

        # Retrieve min/max y bounds
        cdef float parent_start_x = self.context.viewport.parent_pos.x
        cdef float parent_start_y = self.context.viewport.parent_pos.y
        cdef float end_y = parent_start_y + self.state.cur.content_region_size.y

        # Deduce wrapping start region.
        # First column starts at parent_start_y; wrapped columns start at wrap_start_y.
        cdef float wrap_start_y = parent_start_y + fmax(-self.state.cur.pos_to_window.y, 0.)
        wrap_start_y = fmax(parent_start_y, wrap_start_y)

        cdef float col_x = parent_start_x       # screen-x of the current column's left edge
        cdef float col_max_width = 0.            # widest item seen so far in this column
        cdef float cur_end_y = parent_start_y    # screen-y of the bottom edge of the last drawn item
        cdef bint changed = False
        cdef bint is_first_col = True            # False once we have wrapped to a second column
        cdef bint first_item_drawn = False       # True after any visible item moved the cursor down
        cdef bint first_item_on_col_drawn = False  # True after a visible item moved the cursor down in this column
        cdef bint had_item_on_col_before = False   # snapshot before drawing this child
        cdef float cursor_y_before               # cursor y sampled before draw to detect advancement
        cdef bint has_sz                         # whether the current child has a rect size
        cdef float new_col_x, new_col_y          # position for the start of a new column

        while (<uiItem>child) is not None:
            had_item_on_col_before = first_item_on_col_drawn

            # Tooltips have no size.
            has_sz = (<uiItem>child).state.cap.has_rect_size

            # If the current column already contains a visible item, decide
            # whether the next visible item still fits or must wrap.
            if first_item_on_col_drawn and has_sz:
                if (<uiItem>child).state.cur.traversed and \
                   cur_end_y + spacing_y + (<uiItem>child).state.cur.rect_size.y > end_y:
                    # Item doesn't fit: start a new column to the right.
                    new_col_x = col_x + col_max_width + spacing_x
                    new_col_y = parent_start_y if is_first_col else wrap_start_y
                    imgui.SetCursorScreenPos(imgui.ImVec2(new_col_x, new_col_y))
                    col_x = new_col_x
                    col_max_width = 0.
                    cur_end_y = new_col_y
                    is_first_col = False
                    first_item_on_col_drawn = False
                    had_item_on_col_before = False
                # else: item fits; natural cursor advancement places it correctly

            # Retrieve y before the item is drawn
            cursor_y_before = imgui.GetCursorScreenPos().y

            # Draw the item
            (<uiItem>child).draw()

            # Track whether the item size changed, in which case we trigger a redraw
            if (<uiItem>child).state.cur.rect_size.x != (<uiItem>child).state.prev.rect_size.x or \
               (<uiItem>child).state.cur.rect_size.y != (<uiItem>child).state.prev.rect_size.y:
                changed = True

            # Track whether anything was drawn and moved the cursor down.
            # Items with show=False and tooltips do not call ItemSize here,
            # so the cursor does not move.
            if imgui.GetCursorScreenPos().y > cursor_y_before:
                cur_end_y = (<uiItem>child).state.cur.pos_to_viewport.y + \
                             (<uiItem>child).state.cur.rect_size.y
                col_max_width = fmax(col_max_width, (<uiItem>child).state.cur.rect_size.x)
                first_item_drawn = True
                first_item_on_col_drawn = True
            else:
                # Preserve the current-column state across hidden / zero-size
                # items so the next visible child still performs the wrap check
                # against cur_end_y.  If we just wrapped, had_item_on_col_before
                # is False and the new column correctly remains empty.
                if first_item_drawn and had_item_on_col_before:
                    first_item_on_col_drawn = True

            # Move on to next child
            child = <PyObject*>(<uiItem>child).next_sibling
        return changed

    cdef bint __draw_item_aligned(self) noexcept nogil:
        """
        BOTTOM / CENTER / JUSTIFIED alignment.

        Items are grouped into columns by a pre-pass that uses the previous
        frame's rect_sizes to predict which items fit in each column.  The
        pre-pass totals each column's height so the alignment offset can be
        computed before any drawing begins.

        Each item is placed with an explicit SetCursorScreenPos so its y is
        fully controlled regardless of ImGui's cursor state.

        For JUSTIFIED, inter-item spacing is widened to fill the column.
        The last item on a BOTTOM/JUSTIFIED column is snapped to end_y once
        its size stabilises, absorbing accumulated floor() rounding error.

        Hidden items (show=False) have state.cur.traversed set to False by
        _update_current_state_as_hidden, so the pre-pass uses traversed as a
        visibility proxy.  Items drawn off-screen last frame still have
        traversed=True (draw() was called) and their rect_size was set by
        ImGui's ItemAdd even when clipped, allowing BOTTOM/CENTER/JUSTIFIED
        layouts to converge in two frames even on the very first render.
        Any rect_size or rendered change triggers a forced redraw so the
        pre-pass re-evaluates with the new sizes.  Hidden items do not advance
        cur_y in the draw pass so they do not corrupt alignment calculations.
        """
        # Walk backwards to the first sibling
        cdef PyObject *child = <PyObject*>self.last_widgets_child
        while (<uiItem>child).prev_sibling is not None:
            child = <PyObject*>(<uiItem>child).prev_sibling

        cdef float spacing_x = imgui.GetStyle().ItemSpacing.x
        cdef float spacing_y = imgui.GetStyle().ItemSpacing.y
        cdef float parent_start_x = self.context.viewport.parent_pos.x
        cdef float parent_start_y = self.context.viewport.parent_pos.y
        cdef float end_y = parent_start_y + self.state.cur.content_region_size.y  # bottom edge (screen coords)
        cdef float available_height = self.state.cur.content_region_size.y
        # Columns after the first start at wrap_start_y (mirrors the old wrap_y calc).
        cdef float wrap_start_y = parent_start_y + max(-self.state.cur.pos_to_window.y, 0.)
        wrap_start_y = max(parent_start_y, wrap_start_y)

        cdef float col_x = parent_start_x  # screen-x of the current column
        cdef float col_max_width = 0.  # widest item drawn in the current column
        cdef bint changed = False
        cdef bint is_first_col = True  # False once we have wrapped to a second column

        # Loop variables: declared here because Cython forbids cdef inside loops.
        cdef float col_avail      # available height for this column
        cdef float col_sy         # screen-y where this column starts
        cdef float expected_size  # sum of heights (+spacings) in this column (pre-pass)
        cdef float sz             # one item's height
        cdef float next_sz        # tentative expected_size after adding one more item
        cdef int32_t n_with_size  # count of has_rect_size items in this column
        cdef PyObject *last_with_size  # last has_rect_size item in this column
        cdef PyObject *s          # iteration cursor used in both passes
        cdef PyObject *col_end    # first item of the next column (None = end of list)
        cdef float target_y       # screen-y where this column begins drawing
        cdef float col_spacing_y  # per-gap spacing (wider for JUSTIFIED)
        cdef float cur_y          # current draw position within the column
        cdef bint has_sz          # current item's has_rect_size flag

        cdef PyObject *col_start = child
        while (<uiItem>col_start) is not None:
            # Height budget: first column uses full content height; subsequent
            # columns use the narrower region from wrap_start_y to end_y.
            col_avail = available_height if is_first_col else (end_y - wrap_start_y)
            col_sy = parent_start_y if is_first_col else wrap_start_y

            # Pre-pass: walk siblings to determine which items belong to this
            # column and sum their heights.  state.cur.traversed is False for
            # hidden items (zeroed by _update_current_state_as_hidden when
            # show=False), and also False for brand-new items that have never
            # been drawn.  Using traversed (rather than rendered) means that
            # items drawn off-screen in the previous frame (traversed=True,
            # rendered=False) are still included here with their actual
            # rect_size, allowing BOTTOM/CENTER/JUSTIFIED layouts to converge
            # in two frames even on the very first render.  Note: rect_size is
            # NOT reset to zero on hide, so sz alone is not a reliable proxy
            # for visibility.  Stop when adding the next item would overflow
            # the budget (only when wrapping is enabled).
            expected_size = 0.
            n_with_size = 0
            last_with_size = NULL
            s = col_start
            while (<uiItem>s) is not None:
                if (<uiItem>s).state.cap.has_rect_size and (<uiItem>s).state.cur.traversed:
                    sz = (<uiItem>s).state.cur.rect_size.y
                    next_sz = expected_size + (spacing_y if n_with_size > 0 else 0.) + sz
                    # Overflow: stop here (only when wrapping is allowed)
                    if not(self._no_wrap) and next_sz > col_avail and n_with_size > 0:
                        break
                    expected_size = next_sz
                    n_with_size += 1
                    last_with_size = s
                s = <PyObject*>(<uiItem>s).next_sibling
            # s is None (end of list) or the first item that starts the next column
            col_end = s

            # Compute the column's start y and per-gap spacing
            col_spacing_y = spacing_y
            if self._alignment_mode == Alignment.BOTTOM:
                target_y = max(col_sy, end_y - expected_size)
            elif self._alignment_mode == Alignment.CENTER:
                target_y = col_sy + floor((col_avail - expected_size) / 2.)
                target_y = max(col_sy, target_y)
            else:  # JUSTIFIED
                target_y = col_sy
                if n_with_size > 1:
                    # Spread the extra space evenly; floor() avoids overshoot
                    col_spacing_y = spacing_y + max(0., floor(
                        (col_avail - expected_size) / (n_with_size - 1)))

            # Draw pass: place each item with an explicit cursor position.
            # The last BOTTOM/JUSTIFIED item is snapped to end_y when stable.
            s = col_start
            col_max_width = 0.
            cur_y = target_y
            while s is not col_end:
                has_sz = (<uiItem>s).state.cap.has_rect_size

                if has_sz and s == last_with_size and n_with_size > 1 and \
                   (self._alignment_mode == Alignment.BOTTOM or
                    self._alignment_mode == Alignment.JUSTIFIED) and \
                   (<uiItem>s).state.cur.rect_size.y == (<uiItem>s).state.prev.rect_size.y:
                    # Snap last item's bottom to end_y (eliminates floor() rounding error)
                    imgui.SetCursorScreenPos(imgui.ImVec2(col_x,
                        end_y - (<uiItem>s).state.cur.rect_size.y))
                else:
                    imgui.SetCursorScreenPos(imgui.ImVec2(col_x, cur_y))

                (<uiItem>s).draw()

                # Track size and visibility changes so the parent knows to redraw next frame
                if (<uiItem>s).state.cur.rect_size.x != (<uiItem>s).state.prev.rect_size.x or \
                   (<uiItem>s).state.cur.rect_size.y != (<uiItem>s).state.prev.rect_size.y or \
                   (<uiItem>s).state.cur.rendered != (<uiItem>s).state.prev.rendered:
                    changed = True

                if has_sz:
                    col_max_width = max(col_max_width, (<uiItem>s).state.cur.rect_size.x)
                    # Only advance cur_y for items that were actually drawn (traversed).
                    # Hidden items (show=False) return early from draw() with rect_size.y=0;
                    # skipping them here prevents a stray col_spacing_y from shifting
                    # all subsequent items downward.
                    if (<uiItem>s).state.cur.traversed:
                        cur_y += (<uiItem>s).state.cur.rect_size.y + col_spacing_y
                # else: no-size items don't advance cur_y

                s = <PyObject*>(<uiItem>s).next_sibling

            col_x += col_max_width + spacing_x
            col_start = col_end
            is_first_col = False
        return changed

    cdef bint draw_item(self) noexcept nogil:
        if self.last_widgets_child is None:
            return False

        # Compute available content area from parent context and requested size
        self.update_content_area()

        # Capture _force_update before clearing it so that update_layout() callers
        # trigger callbacks even when the layout is otherwise stable this frame.
        cdef bint forced = self._force_update
        self._force_update = False
        cdef bint children_changed = False

        imgui.PushID(self.uuid)
        imgui.BeginGroup()

        # Expose this layout's content area as the parent context so that children
        # can resolve sizing expressions like "filly", "parent.height", etc.
        cdef Vec2 parent_size_backup = self.context.viewport.parent_size
        cdef Vec2 parent_pos_backup = self.context.viewport.parent_pos
        self.context.viewport.parent_size = self.state.cur.content_region_size
        self.context.viewport.parent_pos = ImVec2Vec2(imgui.GetCursorScreenPos())

        # Lock all siblings for the entire draw to prevent concurrent modification
        # of child positions while ImGui draw calls are being emitted.
        self.last_widgets_child.lock_and_previous_siblings()

        # Clear any stale positioning overrides left by previous code paths
        # The current implementation relies on SetCursorScreenPos,
        # rather than per-item string positioning. This enables to react more
        # gracefully if the size of an item differs from what is expected.
        # It also simplifies the handling of items with no size (e.g. tooltips)
        # which should be attached to the previous item but should not induce
        # spacing.
        if not(self.__check_children_neutral()):
            with gil:
                self.__apply_children_neutral()

        # Dispatch to the appropriate inline drawing strategy
        if self._alignment_mode == Alignment.TOP:
            if self._no_wrap:
                children_changed = self.__draw_item_top_no_wrap()
            else:
                children_changed = self.__draw_item_top_wrap()
        else:  # BOTTOM, CENTER, JUSTIFIED
            children_changed = self.__draw_item_aligned()

        self.last_widgets_child.unlock_and_previous_siblings()

        imgui.EndGroup()
        imgui.PopID()

        # Restore parent context so siblings drawn after us see the correct values
        self.context.viewport.parent_size = parent_size_backup
        self.context.viewport.parent_pos = parent_pos_backup

        # EndGroup + update_current_state records the actual bounding box
        self.update_current_state()

        # If our bounding box changed, the parent layout must also re-evaluate
        if self.state.cur.rect_size.x != self.state.prev.rect_size.x or \
           self.state.cur.rect_size.y != self.state.prev.rect_size.y:
            self.context.viewport.ask_immediate_redraw()

        # If child bounding boxes actually changed, schedule one more redraw so
        # alignment/justification can converge.  We only set _force_update when
        # children genuinely changed this frame — not when we merely consumed a
        # prior _force_update — to prevent an infinite redraw loop.
        if children_changed:
            self._force_update = True
            self.context.viewport.ask_immediate_redraw()

        return forced | children_changed


cdef class WindowLayout(uiItem):
    """
    Same as Layout, but for windows.

    Unlike Layout, WindowLayout doesn't have any accessible state, except
    for the position, the content and rect sizes.

    Similar to Layout, the `height` and `width` values filled in the 
    attributes will apply to the content area visible inside the layout (
    for instance when referencing the parent size: "fillx", "fullx", etc).
    The final size fitted to the position and size of the children is then
    stored in the `rect_size` attribute. In other words, it is possible
    to have `content_area_avail` larger than `rect_size`, and `item.y2` > `item.y3`.
    """
    def __cinit__(self):
        # Accept Window children (not regular UI widgets)
        self.can_have_window_child = True
        self.element_child_category = child_type.cat_window
        self.can_be_disabled = False
        # Sentinel used by check_change to detect child list mutations
        self._previous_last_child = NULL
        self._clip = False
        # Expose content_region_size in state so children can reference it
        self.state.cap.has_content_region = True

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

    @property
    def clip(self):
        """
        Whether to clip the children to the content area of this layout.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._clip

    @clip.setter
    def clip(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._clip = value

    # final enables inlining
    @cython.final
    cdef Vec2 update_content_area(self) noexcept nogil:
        """
        Resolve the layout's content area from the requested width/height and
        the space available from the parent.

        Convention (mirrors Layout.update_content_area):
          0        → fill the remaining parent space on that axis
          positive → explicit pixel size
          negative → parent size minus the absolute value (shrink-from-edge)
        """
        cdef Vec2 full_content_area = self.context.viewport.parent_size
        cdef Vec2 cur_content_area, requested_size

        # Subtract our own offset so we only count the space to the right/below us
        full_content_area.x -= self.state.cur.pos_to_parent.x
        full_content_area.y -= self.state.cur.pos_to_parent.y

        requested_size = self.get_requested_size()

        # X axis: 0 = fill, negative = relative, positive = absolute
        if requested_size.x == 0:
            cur_content_area.x = full_content_area.x
        elif requested_size.x < 0:
            cur_content_area.x = full_content_area.x + requested_size.x
        else:
            cur_content_area.x = requested_size.x

        # Y axis: same convention
        if requested_size.y == 0:
            cur_content_area.y = full_content_area.y
        elif requested_size.y < 0:
            cur_content_area.y = full_content_area.y + requested_size.y
        else:
            cur_content_area.y = requested_size.y

        # Never negative — clamp to zero
        cur_content_area.x = max(0, cur_content_area.x)
        cur_content_area.y = max(0, cur_content_area.y)
        self.state.cur.content_region_size = cur_content_area
        return cur_content_area

    cdef bint check_change(self) noexcept nogil:
        """
        Return True if the layout needs to lock its children and redraw.

        Triggers are:
          - A change in the requested width or height expression
          - The available content area changed (parent resized or layout moved)
          - The child list mutated (child added or removed)
          - _force_update was set (e.g. by update_layout() or draw_child())
        """
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
            # Update sentinel so we detect the *next* mutation
            self._previous_last_child = <PyObject*>self.last_window_child
            self._force_update = False
        return changed

    @cython.final
    cdef void draw_child(self, uiItem child) noexcept nogil:
        """
        Draw one window child and react to any size or position change.

        Window children manage their own position (the user sets it directly),
        so we do not need to push a cursor position before calling draw().
        If the child's bounding box or position changes between frames we
        schedule a redraw and request a re-evaluation of the layout so that
        the bounding-box aggregation in draw_children() stays accurate.
        """
        child.draw()
        # If the child moved or resized, propagate the change upward so the
        # viewport redraws and draw_children() re-computes the aggregate bbox.
        if child.state.cur.rect_size.x != child.state.prev.rect_size.x or \
           child.state.cur.rect_size.y != child.state.prev.rect_size.y or \
           child.state.cur.pos_to_viewport.x != child.state.prev.pos_to_viewport.x or \
           child.state.cur.pos_to_viewport.y != child.state.prev.pos_to_viewport.y:
            child.context.viewport.ask_immediate_redraw()
            self._force_update = True

    @cython.final
    cdef void draw_children(self) noexcept nogil:
        """
        Draw all window children and compute the aggregate bounding box.

        Unlike draw_ui_children, each child is drawn via draw_child() which
        also detects size/position changes and schedules redraws as needed.
        The layout's own rect_size is set to the tightest bounding box that
        contains all positioned children, anchored at pos_to_viewport.
        """
        if self.last_window_child is None:
            return

        # Start the bounding box at the layout's own top-left corner;
        # it will expand rightward and downward as children are drawn.
        cdef Vec2 bot_right = self.state.cur.pos_to_viewport

        # Walk forward from the first (oldest) child
        cdef PyObject *child = <PyObject*> self.last_window_child
        while (<uiItem>child).prev_sibling is not None:
            child = <PyObject *>(<uiItem>child).prev_sibling
        while (<uiItem>child) is not None:
            self.draw_child(<uiItem>child)
            # Only items with both a size and a known position contribute to the bbox
            if (<uiItem>child).state.cap.has_rect_size and (<uiItem>child).state.cap.has_position:
                # Expand the bounding box to include this child's bottom-right corner
                bot_right.y = fmax(bot_right.y, (<uiItem>child).state.cur.pos_to_viewport.y + (<uiItem>child).state.cur.rect_size.y)
                bot_right.x = fmax(bot_right.x, (<uiItem>child).state.cur.pos_to_viewport.x + (<uiItem>child).state.cur.rect_size.x)
            child = <PyObject *>(<uiItem>child).next_sibling

        # Convert the absolute bottom-right corner back to a size relative to us
        self.state.cur.rect_size = make_Vec2(bot_right.x - self.state.cur.pos_to_viewport.x,
                                             bot_right.y - self.state.cur.pos_to_viewport.y)

    cdef void draw(self) noexcept nogil:
        # Nothing to do without children
        if self.last_window_child is None:
            return

        # Hidden: propagate the hide event to children when the visibility
        # state just changed, then bail out without drawing anything.
        if not(self._show):
            if self._show_update_requested:
                self.set_previous_states()
                self._set_hidden_and_propagate_to_children_with_handlers()
                self._show_update_requested = False
            return

        # Apply per-item DPI scaling for the duration of this subtree
        cdef float original_scale = self.context.viewport.global_scale
        self.context.viewport.global_scale = original_scale * self._scaling_factor

        # Snapshot previous state so handlers can compare cur vs prev
        self.set_previous_states()

        # Resolve our position relative to the parent and the viewport
        cdef Vec2 pos_to_viewport = self.context.viewport.parent_pos
        cdef Vec2 pos_to_parent
        pos_to_parent.x = resolve_size(self.requested_x, self)
        pos_to_parent.y = resolve_size(self.requested_y, self)
        pos_to_viewport.x = pos_to_viewport.x + pos_to_parent.x
        pos_to_viewport.y = pos_to_viewport.y + pos_to_parent.y

        self.state.cur.pos_to_window = pos_to_parent
        self.state.cur.pos_to_parent = pos_to_parent
        self.state.cur.pos_to_viewport = pos_to_viewport
        self.state.cur.content_pos = pos_to_viewport

        # Position must be set before calling update_content_area so that
        # pos_to_parent is available for the fill-remaining-space calculation.
        self.update_content_area()

        # Push font and theme overrides for this subtree
        if self._font is not None:
            self._font.push()

        if self._theme is not None:
            self._theme.push()

        # check_change decides whether children need to be locked (and thus
        # whether their positions/sizes may be re-evaluated this frame).
        cdef bint changed = self.check_change()
        if changed:
            self.last_window_child.lock_and_previous_siblings()

        # Expose our content area as the parent context so that children can
        # resolve sizing expressions like "fillx", "parent.height", etc.
        cdef Vec2 parent_pos_backup = self.context.viewport.parent_pos
        cdef Vec2 parent_size_backup = self.context.viewport.parent_size
        cdef bint clip = self._clip
        # Saved viewport geometry, needed only when clipping is enabled
        cdef imgui.ImVec2 Pos_backup, Size_backup
        cdef imgui.ImVec2 WorkPos_backup, WorkSize_backup

        if self.last_window_child is not None:
            self.context.viewport.parent_pos = pos_to_viewport
            self.context.viewport.window_pos = pos_to_viewport
            self.context.viewport.parent_size = self.state.cur.content_region_size
            if clip:
                # Clipping is implemented by shrinking ImGui's main-viewport
                # geometry to our content area.  Window children that call
                # imgui.Begin() will then clamp themselves to this rectangle.
                # We save and restore all four fields so nested layouts are
                # unaffected after we return.
                Pos_backup = imgui.GetMainViewport().Pos
                Size_backup = imgui.GetMainViewport().Size
                WorkPos_backup = imgui.GetMainViewport().WorkPos
                WorkSize_backup = imgui.GetMainViewport().WorkSize
                imgui.GetMainViewport().Pos = Vec2ImVec2(pos_to_viewport)
                imgui.GetMainViewport().WorkPos = Vec2ImVec2(pos_to_viewport)
                imgui.GetMainViewport().Size = Vec2ImVec2(self.state.cur.content_region_size)
                imgui.GetMainViewport().WorkSize = Vec2ImVec2(self.state.cur.content_region_size)
            self.draw_children()
            if clip:
                # Restore the viewport geometry so sibling items drawn after us
                # see the original unconstrained viewport
                imgui.GetMainViewport().Pos = Pos_backup
                imgui.GetMainViewport().Size = Size_backup
                imgui.GetMainViewport().WorkPos = WorkPos_backup
                imgui.GetMainViewport().WorkSize = WorkSize_backup
            self.context.viewport.parent_size = parent_size_backup
            self.context.viewport.parent_pos = parent_pos_backup
            self.context.viewport.window_pos = parent_pos_backup
        else:
            # No children: zero the bounding box so the layout is invisible
            self.state.cur.rect_size = make_Vec2(0., 0.)

        if changed:
            self.last_window_child.unlock_and_previous_siblings()

        # Pop theme and font overrides in reverse order
        if self._theme is not None:
            self._theme.pop()

        if self._font is not None:
            self._font.pop()

        # Restore original scale
        self.context.viewport.global_scale = original_scale

        # Fire layout-change callbacks when the child configuration changed
        cdef int i
        if changed and not(self._callbacks.empty()):
            with gil:
                for i in range(<int>self._callbacks.size()):
                    self.context.queue_callback(
                        <Callback>self._callbacks[i],
                        self,
                        self,
                        uiItemCallbackNoneValue(None)
                    )

        self.run_handlers()

