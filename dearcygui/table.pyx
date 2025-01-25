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
from libc.stdlib cimport malloc, free
from libc.string cimport memcpy, memset

from dearcygui.wrapper cimport imgui, implot
from libcpp.cmath cimport trunc
from libcpp.map cimport map, pair
from libcpp.string cimport string
from libcpp.vector cimport vector
from libc.stdint cimport uint32_t, int32_t
from libc.math cimport INFINITY

from cython.operator cimport dereference

from .core cimport baseItem, baseHandler, drawingItem, uiItem, \
    lock_gil_friendly, read_point, clear_obj_vector, append_obj_vector, \
    draw_drawing_children, draw_menubar_children, \
    draw_ui_children, button_area, \
    draw_tab_children, Callback, \
    Context, read_vec4, read_point, \
    SharedValue, update_current_mouse_states, itemState
from .c_types cimport *
from .imgui_types cimport unparse_color, parse_color, Vec2ImVec2, \
    Vec4ImVec4, ImVec2Vec2, ImVec4Vec4, ButtonDirection
from .types cimport *
from .widget cimport Tooltip

from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .types import TableFlag

import numpy as np
cimport numpy as cnp
cnp.import_array()


cdef class TableColConfig(baseItem):
    """
    Configuration for a table column.

    A table column can be hidden, stretched, resized, etc.

    The states can be changed by the user, but also by the
    application.
    To listen for state changes use:
    - ToggledOpenHandler/ToggledCloseHandler to listen if the user
        requests the column to be shown/hidden.
    - ContentResizeHandler to listen if the user resizes the column.
    - HoveredHandler to listen if the user hovers the column.
    """
    cdef itemState state
    cdef imgui.ImGuiTableColumnFlags _flags
    cdef float _width
    cdef float _stretch_weight
    cdef string _label
    cdef bint _dpi_scaling
    cdef bint _stretch
    cdef bint _fixed

    def __cinit__(self):
        self.p_state = &self.state
        self.state.cur.open = True
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_toggled = True # hide/enable
        self.state.cap.can_be_clicked = True
        #self.state.cap.can_be_active = True # sort request
        #self.state.cap.has_position = True
        #self.state.cap.has_content_region = True
        self._flags = imgui.ImGuiTableColumnFlags_None
        self._width = 0.0
        self._stretch_weight = 1.0
        self._fixed = False
        self._stretch = False
        self._dpi_scaling = True

    @property
    def clicked(self):
        """
        Readonly attribute: has the item just been clicked.
        The returned value is a tuple of len 5 containing the individual test
        mouse buttons (up to 5 buttons)
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.cap.can_be_clicked):
            raise AttributeError("Field undefined for type {}".format(type(self)))
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
        if not(self.state.cap.can_be_clicked):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.double_clicked

    @property
    def hovered(self):
        """
        Readonly attribute: Is the mouse inside the region of the item.
        Only one element is hovered at a time, thus
        subitems/subwindows take priority over their parent.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.hovered

    @property
    def visible(self):
        """
        True if the column is not clipped and is enabled.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.rendered

    @property
    def show(self):
        """
        Writable attribute: Show the column.

        show = False differs from enabled=False as
        the latter can be changed by user interaction.
        Defaults to True.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_Disabled) == 0

    @show.setter
    def show(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_Disabled
        if not(value):
            self._flags |= imgui.ImGuiTableColumnFlags_Disabled

    @property
    def enabled(self):
        """
        Writable attribute (and can change with user interaction):
        Whether the table is hidden (user can control this
        in the context menu).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.open

    @enabled.setter
    def enabled(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.state.cur.open = value

    @property
    def stretch(self):
        """
        Writable attribute to enable stretching for this column.
        True: Stretch, using the stretch_weight factor
        False: Fixed width, using the width value.
        None: Default depending on Table policy.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._stretch:
            return True
        elif self._fixed:
            return False
        return None

    @stretch.setter
    def stretch(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._stretch = False
            self._fixed = False
        elif value:
            self._stretch = True
            self._fixed = False
        else:
            self._stretch = False
            self._fixed = True

    ''' -> Redundant with enabled
    @property
    def default_hide(self):
        """
        Writable attribute: Default hide state for the column.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_DefaultHide) != 0

    @default_hide.setter
    def default_hide(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_DefaultHide
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_DefaultHide
    '''

    @property
    def default_sort(self):
        """
        Writable attribute: Default as a sorting column.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_DefaultSort) != 0

    @default_sort.setter
    def default_sort(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_DefaultSort
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_DefaultSort

    @property
    def no_resize(self):
        """Disable manual resizing"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_NoResize) != 0

    @no_resize.setter
    def no_resize(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_NoResize
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_NoResize

    @property
    def no_hide(self):
        """Disable ability to hide this column"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_NoHide) != 0 

    @no_hide.setter
    def no_hide(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_NoHide
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_NoHide

    @property 
    def no_clip(self):
        """Disable clipping for this column"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_NoClip) != 0

    @no_clip.setter
    def no_clip(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_NoClip
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_NoClip

    @property
    def no_sort(self):
        """Disable sorting for this column"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_NoSort) != 0

    @no_sort.setter
    def no_sort(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_NoSort
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_NoSort

    @property
    def prefer_sort_ascending(self):
        """Make the initial sort direction ascending when first sorting"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_PreferSortAscending) != 0

    @prefer_sort_ascending.setter  
    def prefer_sort_ascending(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_PreferSortAscending
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_PreferSortAscending

    @property
    def prefer_sort_descending(self):
        """Make the initial sort direction descending when first sorting"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_PreferSortDescending) != 0

    @prefer_sort_descending.setter
    def prefer_sort_descending(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_PreferSortDescending
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_PreferSortDescending

    @property
    def no_sort_ascending(self):
        """Disable ability to sort in ascending order"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_NoSortAscending) != 0

    @no_sort_ascending.setter
    def no_sort_ascending(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_NoSortAscending
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_NoSortAscending

    @property
    def no_sort_descending(self):
        """Disable ability to sort in descending order"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_NoSortDescending) != 0

    @no_sort_descending.setter
    def no_sort_descending(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_NoSortDescending
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_NoSortDescending

    @property
    def no_header_label(self):
        """Don't display column header for this column"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_NoHeaderLabel) != 0

    @no_header_label.setter
    def no_header_label(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_NoHeaderLabel
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_NoHeaderLabel

    @property
    def no_header_width(self):
        """Don't display column width when hovered"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_NoHeaderWidth) != 0

    @no_header_width.setter
    def no_header_width(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_NoHeaderWidth
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_NoHeaderWidth

    @property
    def width(self):
        """Requested fixed width of the column in pixels.
        Unused if in stretch mode.
        Set to 0 for auto-width.

        Note the width is used only when the column
        is initialized, and is not updated with resizes."""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._width

    @width.setter
    def width(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._width = value

    @property
    def no_scaling(self):
        """
        boolean. Defaults to False.
        By default, the requested width and
        height are multiplied internally by the global
        scale which is defined by the dpi and the
        viewport/window scale.
        If set, disables this automated scaling.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return not(self._dpi_scaling)

    @no_scaling.setter
    def no_scaling(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._dpi_scaling = not(value)

    @property 
    def stretch_weight(self):
        """Weight used when stretching this column. Must be >= 0."""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._stretch_weight

    @stretch_weight.setter
    def stretch_weight(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < 0:
            raise ValueError("stretch_weight must be >= 0")
        self._stretch_weight = value

    @property
    def no_reorder(self): 
        """Disable manual reordering"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_NoReorder) != 0

    @no_reorder.setter
    def no_reorder(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_NoReorder
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_NoReorder

    @property
    def label(self):
        """
        Label in the header for the column
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(self._label, encoding='utf-8')

    @label.setter
    def label(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._label = bytes(value, encoding='utf-8')

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

    cdef void setup(self, int32_t col_idx, uint32_t table_flags) noexcept nogil:
        """Setup the column"""
        cdef bint enabled_state_change = \
            self.state.cur.open != self.state.prev.open
        self.set_previous_states()

        cdef imgui.ImGuiTableColumnFlags flags = self._flags
        cdef float width_or_weight = 0.
        if self._stretch:
            width_or_weight = self._stretch_weight
            flags |= imgui.ImGuiTableColumnFlags_WidthStretch
        elif self._fixed:
            if self._dpi_scaling:
                width_or_weight = self._width * \
                    self.context.viewport.global_scale
            else:
                width_or_weight = self._width
            flags |= imgui.ImGuiTableColumnFlags_WidthFixed
        imgui.TableSetupColumn(self._label.c_str(),
                               flags,
                               width_or_weight,
                               self.uuid)
        if table_flags & imgui.ImGuiTableFlags_Hideable and enabled_state_change:
            imgui.TableSetColumnEnabled(col_idx, self.state.prev.open)

    cdef void after_draw(self, int32_t col_idx) noexcept nogil:
        """After draw, update the states"""
        cdef imgui.ImGuiTableColumnFlags flags = imgui.TableGetColumnFlags(col_idx)

        self.state.cur.rendered = (flags & imgui.ImGuiTableColumnFlags_IsVisible) != 0
        self.state.cur.open = (flags & imgui.ImGuiTableColumnFlags_IsEnabled) != 0
        self.state.cur.hovered = (flags & imgui.ImGuiTableColumnFlags_IsHovered) != 0

        update_current_mouse_states(self.state)
        self.run_handlers()


cdef class TableColConfigView:
    """
    A View of a Table which you can index to get the
    TableColConfig for a specific column.
    """
    cdef Table table

    def __init__(self):
        raise TypeError("TableColConfigView cannot be instantiated directly")

    def __cinit__(self):
        self.table = None

    def __getitem__(self, int32_t col_idx) -> TableColConfig:
        """Get the column configuration for the specified column."""
        return self.table.get_col_config(col_idx)

    def __setitem__(self, int32_t col_idx, TableColConfig config) -> None:
        """Set the column configuration for the specified column."""
        self.table.set_col_config(col_idx, config)

    def __delitem__(self, int32_t col_idx) -> None:
        """Delete the column configuration for the specified column."""
        self.table.set_col_config(col_idx, TableColConfig(self.table.context))

    def __call__(self, int32_t col_idx, str attribute, value) -> TableColConfig:
        """Set an attribute of the column configuration for the specified column."""
        cdef TableColConfig config = self.table.get_col_config(col_idx)
        setattr(config, attribute, value)
        self.table.set_col_config(col_idx, config)
        return config

    @staticmethod
    cdef TableColConfigView create(Table table):
        """Create a TableColConfigView for the specified table."""
        cdef TableColConfigView view = TableColConfigView.__new__(TableColConfigView)
        view.table = table
        return view

cdef class TableRowConfig(baseItem):
    """
    Configuration for a table row.

    A table row can be hidden and its background color can be changed.
    """
    #cdef itemState state
    cdef bint show
    cdef float min_height
    cdef uint32_t bg_color

    def __cinit__(self):
        #self.p_state = &self.state
        #self.state.has_content_region
        self.min_height = 0.0
        self.bg_color = 0
        self.show = True

    @property
    def show(self):
        """
        Writable attribute: Show the row.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.show

    @show.setter
    def show(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.show = value

    @property
    def bg_color(self):
        """Background color for the whole row.

        Set to 0 (default) to disable.
        This background color is applied on top
        of any row background color defined by
        the theme (blending)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self.bg_color)
        return color

    @bg_color.setter
    def bg_color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex) 
        self.bg_color = parse_color(value)

    @property
    def min_height(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.min_height

    @min_height.setter
    def min_height(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex) 
        self.min_height = value

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

cdef class TableRowConfigView:
    """
    A View of a Table which you can index to get the
    TableRowConfig for a specific row.
    """
    cdef Table table

    def __init__(self):
        raise TypeError("TableRowConfigView cannot be instantiated directly")

    def __cinit__(self):
        self.table = None

    def __getitem__(self, int32_t row_idx) -> TableRowConfig:
        """Get the column configuration for the specified column."""
        return self.table.get_row_config(row_idx)

    def __setitem__(self, int32_t row_idx, TableRowConfig config) -> None:
        """Set the column configuration for the specified column."""
        self.table.set_row_config(row_idx, config)

    def __delitem__(self, int32_t col_idx) -> None:
        """Delete the column configuration for the specified column."""
        self.table.set_row_config(col_idx, TableRowConfig(self.table.context))

    def __call__(self, int32_t row_idx, str attribute, value) -> TableRowConfig:
        """Set an attribute of the column configuration for the specified column."""
        cdef TableRowConfig config = self.table.get_row_config(row_idx)
        setattr(config, attribute, value)
        self.table.set_row_config(row_idx, config)
        return config

    @staticmethod
    cdef TableRowConfigView create(Table table):
        """Create a TableColConfigView for the specified table."""
        cdef TableRowConfigView view = TableRowConfigView.__new__(TableRowConfigView)
        view.table = table
        return view


cdef struct TableElementData:
    # Optional item to display in the table cell
    PyObject* ui_item # Is uiItem or NULL
    # Optional items to display in the tooltip
    PyObject* tooltip_ui_item # is uiItem or NULL
    # Optional value to associate the element
    # with a value used for row/col sorting
    PyObject* ordering_value
    # If ui_item is not set, value used
    # for the cell
    string str_item
    # if tooltip_ui_item is not set, value used
    # for the tooltip
    string str_tooltip
    uint32_t bg_color

cdef class TableElement:
    """
    Configuration for a table element.

    A table element can be hidden, stretched, resized, etc.
    """
    cdef recursive_mutex mutex
    cdef TableElementData element

    def __init__(self, *args, **kwargs):
        self.configure(*args, **kwargs)

    def configure(self, *args, **kwargs):
        # set content first (ordering_value)
        if len(args) == 1:
            self.content = args[0]
        elif len(args) > 1:
            raise ValueError("TableElement accepts at most 1 positional argument")
        if "content" in kwargs:
            self.content = kwargs.pop("content")
        for key, value in kwargs.items():
            setattr(self, key, value)

    def __cinit__(self):
        self.element.ui_item = NULL
        self.element.tooltip_ui_item = NULL
        self.element.ordering_value = NULL
        self.element.bg_color = 0

    def __dealloc__(self):
        if self.element.ui_item != NULL:
            Py_DECREF(<object>self.element.ui_item)
        if self.element.tooltip_ui_item != NULL:
            Py_DECREF(<object>self.element.tooltip_ui_item)
        if self.element.ordering_value != NULL:
            Py_DECREF(<object>self.element.ordering_value)

    @property
    def content(self):
        """
        Writable attribute: The item to display in the table cell.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self.element.ui_item != NULL:
            return <uiItem>self.element.ui_item
        if not self.element.str_item.empty():
            return str(self.element.str_item, encoding="utf-8")
        return None

    @content.setter
    def content(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        # clear previous content
        if self.element.ui_item != NULL:
            Py_DECREF(<object>self.element.ui_item)
        self.element.ui_item = NULL
        self.element.str_item.clear()
        if isinstance(value, uiItem):
            Py_INCREF(value)
            self.element.ui_item = <PyObject*>value
        elif value is not None:
            self.element.str_item = bytes(str(value), encoding='utf-8')
            self.ordering_value = value

    @property
    def tooltip(self):
        """
        Writable attribute: The tooltip configuration for the item.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self.element.tooltip_ui_item != NULL:
            return <uiItem>self.element.tooltip_ui_item
        if not self.element.str_tooltip.empty():
            return str(self.element.str_tooltip, encoding="utf-8")
        return None

    @tooltip.setter
    def tooltip(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self.element.tooltip_ui_item != NULL:
            Py_DECREF(<object>self.element.tooltip_ui_item)
        self.element.tooltip_ui_item = NULL
        self.element.str_tooltip.clear()
        if isinstance(value, uiItem):
            Py_INCREF(value)
            self.element.tooltip_ui_item = <PyObject*>value
        elif value is not None:
            self.element.str_tooltip = bytes(str(value), encoding='utf-8')

    @property
    def ordering_value(self):
        """
        Writable attribute: The value used for ordering the table.

        Note ordering_value is automatically set to the value
        set in content when set to a string or number.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self.element.ordering_value != NULL:
            return <object>self.element.ordering_value
        if self.element.ui_item != NULL:
            return (<uiItem>self.element.ui_item).uuid
        return None

    @ordering_value.setter
    def ordering_value(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self.element.ordering_value != NULL:
            Py_DECREF(<object>self.element.ordering_value)
        Py_INCREF(value)
        self.element.ordering_value = <PyObject*>value

    @property
    def bg_color(self):
        """
        Writable attribute: The background color for the cell.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self.element.bg_color)
        return color

    @bg_color.setter
    def bg_color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.element.bg_color = parse_color(value)

    @staticmethod
    cdef TableElement from_element(TableElementData element):
        cdef TableElement config = TableElement.__new__(TableElement)
        config.element = element
        if element.ui_item != NULL:
            Py_INCREF(<object>element.ui_item)
        if element.tooltip_ui_item != NULL:
            Py_INCREF(<object>element.tooltip_ui_item)
        if element.ordering_value != NULL:
            Py_INCREF(<object>element.ordering_value)
        return config

cdef class TablePlaceHolderParent(baseItem):
    """
    Placeholder parent to store items outside the rendering tree.
    Can be only be parent to items that can be attached to tables
    """
    def __cinit__(self):
        self.can_have_widget_child = True

cdef class TableRowView:
    """View class for accessing and manipulating a single row of a Table."""
    cdef Table table
    cdef int32_t row_idx
    cdef TablePlaceHolderParent _temp_parent # For with statement

    def __init__(self):
        raise TypeError("TableRowView cannot be instantiated directly")

    def __cinit__(self):
        self.table = None
        self.row_idx = 0
        self._temp_parent = None

    def __enter__(self):
        """Start a context for adding items to this row."""
        self._temp_parent = TablePlaceHolderParent(self.table.context)
        self.table.context.push_next_parent(self._temp_parent)
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        """Convert children added during context into row values."""
        self.table.context.pop_next_parent()
        if exc_type is not None:
            return False

        # Convert children to column values

        configs = []
        
        for child in self._temp_parent.children:
            # If child is a Tooltip, associate it with previous element
            if isinstance(child, Tooltip):
                if len(configs) > 0:
                    configs[len(configs)-1].tooltip = child
                continue
            # Create new element for non-tooltip child
            configs.append(TableElement())
            configs[len(configs)-1].content = child

        self.table.set_row(self.row_idx, configs)

        self._temp_parent = None
        return False

    def __getitem__(self, int32_t col_idx):
        """Get item at specified column."""
        return self.table._get_single_item(self.row_idx, col_idx)

    def __setitem__(self, int32_t col_idx, value):  
        """Set item at specified column."""
        self.table._set_single_item(self.row_idx, col_idx, value)

    def __delitem__(self, int32_t col_idx):
        """Delete item at specified column."""
        cdef pair[int32_t, int32_t] key = pair[int32_t, int32_t](self.row_idx, col_idx)
        self.table._delete_item(key)

    @staticmethod
    cdef create(Table table, int32_t row_idx):
        """Create a TableRowView for the specified row."""
        cdef TableRowView view = TableRowView.__new__(TableRowView)
        view.row_idx = row_idx
        view.table = table
        return view

cdef class TableColView:
    """View class for accessing and manipulating a single column of a Table."""
    cdef Table table  
    cdef int32_t col_idx
    cdef TablePlaceHolderParent _temp_parent # For with statement

    def __init__(self):
        raise TypeError("TableColView cannot be instantiated directly")

    def __cinit__(self):
        self.table = None
        self.col_idx = 0
        self._temp_parent = None

    def __enter__(self):
        """Start a context for adding items to this column."""
        self._temp_parent = TablePlaceHolderParent(self.table.context)
        self.table.context.push_next_parent(self._temp_parent)
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        """Convert children added during context into column values."""
        self.table.context.pop_next_parent()
        if exc_type is not None:
            return False

        # Convert children to row values
        
        configs = []

        for child in self._temp_parent.children:
            # If child is a Tooltip, associate it with previous element
            if isinstance(child, Tooltip):
                if len(configs) > 0:
                    configs[len(configs)-1].tooltip = child
                continue
            # Create new element for non-tooltip child
            configs.append(TableElement())
            configs[len(configs)-1].content = child

        self.table.set_col(self.col_idx, configs)

        self._temp_parent = None
        return False

    def __getitem__(self, int32_t row_idx):
        """Get item at specified row."""
        return self.table._get_single_item(row_idx, self.col_idx)

    def __setitem__(self, int32_t row_idx, value):
        """Set item at specified row."""  
        self.table._set_single_item(row_idx, self.col_idx, value)

    def __delitem__(self, int32_t row_idx):
        """Delete item at specified row."""
        cdef pair[int32_t, int32_t] key = pair[int32_t, int32_t](row_idx, self.col_idx)
        self.table._delete_item(key)

    @staticmethod
    def create(Table table, int32_t col_idx):
        """Create a TableColView for the specified column."""
        cdef TableColView view = TableColView.__new__(TableColView)
        view.col_idx = col_idx
        view.table = table
        return view


cdef class Table(uiItem):
    """
    Table widget.
    
    A table is a grid of cells, where each cell can contain
    text, images, buttons, etc. The table can be used to
    display data, but also to interact with the user.
    """
    cdef map[pair[int32_t, int32_t], TableElementData] _items
    cdef map[int32_t, PyObject*] _col_configs # TableColConfig
    cdef map[int32_t, PyObject*] _row_configs # TableRowConfig
    cdef imgui.ImGuiTableFlags _flags
    cdef bint _dirty_num_rows_cols
    cdef int32_t _num_rows
    cdef int32_t _num_cols
    cdef int32_t _num_rows_visible
    cdef int32_t _num_cols_visible
    cdef int32_t _num_rows_frozen
    cdef int32_t _num_cols_frozen
    cdef float _inner_width
    cdef bint _header
    def __cinit__(self):
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_toggled = True
        self.state.cap.can_be_active = True
        self.state.cap.has_position = True
        self.state.cap.has_content_region = True
        self._flags = imgui.ImGuiTableFlags_None
        self._num_rows = 0
        self._num_cols = 0
        self._inner_width = 0.
        self._dirty_num_rows_cols = False
        self._num_rows_visible = -1
        self._num_cols_visible = -1
        self._num_rows_frozen = 0
        self._num_cols_frozen = 0
        self.can_have_widget_child = True

    cdef TableColConfig get_col_config(self, int32_t col_idx):
        """
        Retrieve the configuration of a column,
        and create a default one if we didn't have any yet.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if col_idx < 0:
            raise ValueError(f"Invalid column index {col_idx}")
        cdef map[int32_t, PyObject*].iterator it
        it = self._col_configs.find(col_idx)
        if it == self._col_configs.end():
            config = TableColConfig(self.context)
            Py_INCREF(config)
            self._col_configs[col_idx] = <PyObject*>config
            return config
        cdef PyObject* item = dereference(it).second
        cdef TableColConfig found_config = <TableColConfig>item
        return found_config

    cdef void set_col_config(self, int32_t col_idx, TableColConfig config):
        """
        Set the configuration of a column.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if col_idx < 0:
            raise ValueError(f"Invalid column index {col_idx}")
        cdef map[int32_t, PyObject*].iterator it
        it = self._col_configs.find(col_idx)
        if it != self._col_configs.end():
            Py_DECREF(<object>dereference(it).second)
        Py_INCREF(config)
        self._col_configs[col_idx] = <PyObject*>config

    cdef TableRowConfig get_row_config(self, int32_t row_idx):
        """
        Retrieve the configuration of a row,
        and create a default one if we didn't have any yet.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if row_idx < 0:
            raise ValueError(f"Invalid row index {row_idx}")
        cdef map[int32_t, PyObject*].iterator it
        it = self._row_configs.find(row_idx)
        if it == self._row_configs.end():
            config = TableRowConfig(self.context)
            Py_INCREF(config)
            self._row_configs[row_idx] = <PyObject*>config
            return config
        cdef PyObject* item = dereference(it).second
        cdef TableRowConfig found_config = <TableRowConfig>item
        return found_config

    cdef void set_row_config(self, int32_t row_idx, TableRowConfig config):
        """
        Set the configuration of a row.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if row_idx < 0:
            raise ValueError(f"Invalid row index {row_idx}")
        cdef map[int32_t, PyObject*].iterator it
        it = self._row_configs.find(row_idx)
        if it != self._row_configs.end():
            Py_DECREF(<object>dereference(it).second)
        Py_INCREF(config)
        self._row_configs[row_idx] = <PyObject*>config

    @property
    def col_config(self):
        """
        Get the column configuration view.
        """
        return TableColConfigView.create(self)

    @property
    def row_config(self):
        """
        Get the row configuration view.
        """
        return TableRowConfigView.create(self)

    @property 
    def flags(self):
        """
        Get the table flags.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return TableFlag(<int>self._flags)

    @flags.setter  
    def flags(self, value):
        """
        Set the table flags.

        Args:
            value: A TableFlag value or combination of TableFlag values
        """
        if not isinstance(value, TableFlag):
            raise TypeError("flags must be a TableFlag value")
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags = <imgui.ImGuiTableFlags>value

    @property
    def inner_width(self):
        """
        With ScrollX disabled:
           - inner_width          ->  *ignored*
        With ScrollX enabled:
           - inner_width  < 0.  ->  *illegal* fit in known width
                 (right align from outer_size.x) <-- weird
           - inner_width  = 0.  ->  fit in outer_width:
                Fixed size columns will take space they need (if avail,
                otherwise shrink down), Stretch columns becomes Fixed columns.
           - inner_width  > 0.  ->  override scrolling width,
                generally to be larger than outer_size.x. Fixed column
                take space they need (if avail, otherwise shrink down),
                Stretch columns share remaining space!

        Defaults to 0.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._inner_width

    @inner_width.setter
    def inner_width(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._inner_width = value

    @property
    def header(self):
        """
        boolean. Defaults to True.
        Produce a table header based on the column labels.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._header

    @header.setter
    def header(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._header = value

    @property
    def num_rows(self):
        """
        Get the number of rows in the table.

        This corresponds to the maximum row
        index used in the table.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._dirty_num_rows_cols:
            self._update_row_col_counts()
        return self._num_rows

    @property
    def num_cols(self):
        """
        Get the number of columns in the table.

        This corresponds to the maximum column
        index used in the table.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._dirty_num_rows_cols:
            self._update_row_col_counts()
        return self._num_cols

    @property
    def num_rows_visible(self):
        """
        Override the number of visible rows in the table.

        By default (None), the number of visible rows
        is the same as the number of rows in the table.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._num_rows_visible < 0:
            return None
        return self._num_rows_visible

    @num_rows_visible.setter
    def num_rows_visible(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._num_rows_visible = -1
            return
        try:
            value = int(value)
            if value < 0:
                raise ValueError()
        except:
            raise ValueError("num_rows_visible must be a non-negative integer or None")
        self._num_rows_visible = value

    @property
    def num_cols_visible(self):
        """
        Override the number of visible columns in the table.

        By default (None), the number of visible columns
        is the same as the number of columns in the table.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._num_cols_visible < 0:
            return None
        return self._num_cols_visible

    @num_cols_visible.setter
    def num_cols_visible(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._num_cols_visible = -1
            return
        try:
            value = int(value)
            if value < 0:
                raise ValueError()
        except:
            raise ValueError("num_cols_visible must be a non-negative integer or None")
        if value > 512: # IMGUI_TABLE_MAX_COLUMNS
            raise ValueError("num_cols_visible must be <= 512")
        self._num_cols_visible = value

    @property
    def num_rows_frozen(self):
        """
        Writable attribute: Number of rows
        with scroll frozen.
        Default is 0.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._num_rows_frozen

    @num_rows_frozen.setter
    def num_rows_frozen(self, int32_t value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < 0:
            raise ValueError("num_rows_frozen must be a non-negative integer")
        if value >= 128: # imgui limit
            raise ValueError("num_rows_frozen must be < 128")
        self._num_rows_frozen = value

    @property
    def num_cols_frozen(self):
        """
        Writable attribute: Number of columns
        with scroll frozen.
        Default is 0.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._num_cols_frozen

    @num_cols_frozen.setter
    def num_cols_frozen(self, int32_t value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < 0:
            raise ValueError("num_cols_frozen must be a non-negative integer")
        if value >= 512: # imgui limit
            raise ValueError("num_cols_frozen must be < 512")
        self._num_cols_frozen = value

    cdef void _decref_and_detach(self, PyObject* item):
        """All items are attached as children of the table.
        This function decrefs them and detaches them if needed."""
        cdef pair[int32_t, int32_t] key
        cdef TableElementData element
        cdef pair[pair[int32_t, int32_t], TableElementData] key_element
        cdef bint found = False
        cdef uiItem ui_item
        if isinstance(<object>item, uiItem):
            for key_element in self._items:
                element = key_element.second
                if element.ui_item == item:
                    found = True
                    break
                if element.tooltip_ui_item != item:
                    found = True
                    break
            # This check is because we allow the child to appear
            # several times in the Table, but only once in the
            # children list.
            if not(found):
                # remove from the children list
                ui_item = <uiItem>item
                # Table is locked, thus we can
                # lock our child safely
                ui_item.mutex.lock()
                # This check is to prevent the case
                # where the child was attached already
                # elsewhere
                if ui_item.parent is self:
                    ui_item.detach_item()
                ui_item.mutex.unlock()
        Py_DECREF(<object>item)

    cdef void clear_items(self):
        cdef pair[pair[int32_t, int32_t], TableElementData] key_element
        for key_element in self._items:
            # No need to iterate the table
            # to see if the item is several times
            # in the table. We will detach it
            # only once.
            if key_element.second.ui_item != NULL:
                Py_DECREF(<object>key_element.second.ui_item)
            if key_element.second.tooltip_ui_item != NULL:
                Py_DECREF(<object>key_element.second.tooltip_ui_item)
            if key_element.second.ordering_value != NULL:
                Py_DECREF(<object>key_element.second.ordering_value)
        self._items.clear()
        self._num_rows = 0
        self._num_cols = 0
        self._dirty_num_rows_cols = False

    def clear(self) -> None:
        """Release all items attached to the table.
        
        Does now clear row and column configurations.
        These are cleared only when the Table is released.
        """
        self.clear_items()
        self.children = []

    def __dealloc__(self):
        self.clear_items()
        cdef pair[int32_t, PyObject*] key_value
        for key_value in self._col_configs:
            Py_DECREF(<object>key_value.second)
        for key_value in self._row_configs:
            Py_DECREF(<object>key_value.second)
        self._col_configs.clear()
        self._row_configs.clear()

    cpdef void delete_item(self):
        uiItem.delete_item(self)
        self.clear()

    cdef void _delete_and_siblings(self):
        uiItem._delete_and_siblings(self)
        self.clear()

    cdef bint _delete_item(self, pair[int32_t, int32_t] key):
        """Delete the item at target key.
        
        Returns False if there was no item to delete,
        True else."""
        cdef map[pair[int32_t, int32_t], TableElementData].iterator it
        it = self._items.find(key)
        if it == self._items.end():
            return False # already deleted
        cdef TableElementData element = dereference(it).second
        self._items.erase(it)
        self._dirty_num_rows_cols = True
        if element.ui_item != NULL:
            self._decref_and_detach(element.ui_item)
        if element.tooltip_ui_item != NULL:
            self._decref_and_detach(element.tooltip_ui_item)
        return True

    cdef _get_single_item(self, int32_t row, int32_t col):
        """
        Get item at specific target
        """
        cdef unique_lock[recursive_mutex] m
        cdef pair[int32_t, int32_t] map_key = pair[int32_t, int32_t](row, col)
        lock_gil_friendly(m, self.mutex)
        cdef map[pair[int32_t, int32_t], TableElementData].iterator it
        it = self._items.find(map_key)
        if it == self._items.end():
            return None
        cdef TableElement element_config = \
            TableElement.from_element(dereference(it).second)
        return element_config

    def __getitem__(self, key):
        """
        Get items at specific target
        """
        if not(hasattr(key, "__len__")) or not(len(key) == 2):
            raise ValueError("index must be a list of length 2")
        cdef int32_t row, col
        (row, col) = key
        return self._get_single_item(row, col)

    def _set_single_item(self, int32_t row, int32_t col, value):
        """
        Set items at specific target
        """
        cdef unique_lock[recursive_mutex] m
        if isinstance(value, dict):
            value = TableElement(**value)
        cdef TableElementData element
        # initialize element (is it needed in C++ ?)
        element.ui_item = NULL
        element.tooltip_ui_item = NULL
        element.ordering_value = NULL
        element.str_item.clear()
        element.str_tooltip.clear()
        element.bg_color = 0
        if isinstance(value, uiItem):
            if value.parent is not self:
                value.attach_to_parent(self)
            Py_INCREF(value)
            element.ui_item = <PyObject*>value
        elif isinstance(value, TableElement):
            element = (<TableElement>value).element
            if element.ui_item != NULL:
                if (<uiItem>element.ui_item).parent is not self:
                   (<uiItem>element.ui_item).attach_to_parent(self)
                Py_INCREF(<object>element.ui_item)
            if element.tooltip_ui_item != NULL:
                if (<uiItem>element.tooltip_ui_item).parent is not self:
                   (<uiItem>element.tooltip_ui_item).attach_to_parent(self)
                Py_INCREF(<object>element.tooltip_ui_item)
            if element.ordering_value != NULL:
                Py_INCREF(<object>element.ordering_value)
        else:
            try:
                element.str_item = bytes(str(value), encoding='utf-8')
                element.ordering_value = <PyObject*>value
                Py_INCREF(value)
            except:
                raise TypeError("Table values must be uiItem, TableElementConfig, or convertible to a str")
        # We lock only after in case the value was child
        # of a parent to prevent deadlock.
        lock_gil_friendly(m, self.mutex)
        cdef pair[int32_t, int32_t] map_key = pair[int32_t, int32_t](row, col)
        # delete previous element if any
        self._dirty_num_rows_cols |= not(self._delete_item(map_key))
        self._items[map_key] = element
        # _delete_item may have detached ourselves
        # from the children list. We need to reattach
        # ourselves.
        m.unlock()
        if element.ui_item != NULL and \
           (<uiItem>element.ui_item).parent is not self:
            (<uiItem>element.ui_item).attach_to_parent(self)
        if element.tooltip_ui_item != NULL and \
           (<uiItem>element.tooltip_ui_item).parent is not self:
            (<uiItem>element.tooltip_ui_item).attach_to_parent(self)

    def __setitem__(self, key, value):
        if not(hasattr(key, "__len__")) or not(len(key) == 2):
            raise ValueError("index must be of length 2")
        cdef int32_t row, col
        (row, col) = key
        self._set_single_item(row, col, value)

    def __delitem__(self, key):
        """
        Delete items at specific target
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(hasattr(key, "__len__")) or not(len(key) == 2):
            raise ValueError("value must be a list of length 2")
        cdef int32_t row, col
        (row, col) = key
        cdef pair[int32_t, int32_t] map_key = pair[int32_t, int32_t](row, col)
        self._delete_item(map_key)

    def __iter__(self):
        """
        Iterate over the keys in the table.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef pair[pair[int32_t, int32_t], TableElementData] key_element
        for key_element in self._items:
            yield key_element.first

    def __len__(self):
        """
        Get the number of items in the table.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._items.size()

    def __contains__(self, key):
        """
        Check if a key is in the table.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(hasattr(key, "__len__")) or not(len(key) == 2):
            raise ValueError("key must be a list of length 2")
        cdef int32_t row, col
        (row, col) = key
        cdef pair[int32_t, int32_t] map_key = pair[int32_t, int32_t](row, col)
        cdef map[pair[int32_t, int32_t], TableElementData].iterator it
        it = self._items.find(map_key)
        return it != self._items.end()

    def keys(self):
        """
        Get the keys of the table.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef pair[pair[int32_t, int32_t], TableElementData] key_element
        for key_element in self._items:
            yield key_element.first

    def values(self):
        """
        Get the values of the table.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef pair[pair[int32_t, int32_t], TableElementData] key_element
        for key_element in self._items:
            element_config = TableElement.from_element(key_element.second)
            yield element_config

    def get(self, key, default=None):
        """
        Get the value at a specific key.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(hasattr(key, "__len__")) or not(len(key) == 2):
            raise ValueError("key must be a list of length 2")
        cdef int32_t row, col
        (row, col) = key
        cdef pair[int32_t, int32_t] map_key = pair[int32_t, int32_t](row, col)
        cdef map[pair[int32_t, int32_t], TableElementData].iterator it
        it = self._items.find(map_key)
        if it != self._items.end():
            return TableElement.from_element(dereference(it).second)
        return default

    cdef void _swap_items_from_it(self,
                             int32_t row1, int32_t col1, int32_t row2, int32_t col2,
                             map[pair[int32_t, int32_t], TableElementData].iterator &it1,
                             map[pair[int32_t, int32_t], TableElementData].iterator &it2) noexcept nogil:
        """
        Same as _swap_items but assuming we already have
        the iterators on the items.
        """
        cdef pair[int32_t, int32_t] key1 = pair[int32_t, int32_t](row1, col1)
        cdef pair[int32_t, int32_t] key2 = pair[int32_t, int32_t](row2, col2)
        if it1 == self._items.end() and it2 == self._items.end():
            return
        if it1 == it2:
            return
        if it1 == self._items.end() and it2 != self._items.end():
            self._items[key1] = dereference(it2).second
            self._items.erase(it2)
            self._dirty_num_rows_cols |= \
                row2 == self._num_rows - 1 or \
                col2 == self._num_cols - 1 or \
                row1 == self._num_rows - 1 or \
                col1 == self._num_cols - 1
            return
        if it1 != self._items.end() and it2 == self._items.end():
            self._items[key2] = dereference(it1).second
            self._items.erase(it1)
            self._dirty_num_rows_cols |= \
                row2 == self._num_rows - 1 or \
                col2 == self._num_cols - 1 or \
                row1 == self._num_rows - 1 or \
                col1 == self._num_cols - 1
            return
        cdef TableElementData tmp = dereference(it1).second
        self._items[key1] = dereference(it2).second
        self._items[key2] = tmp

    cdef void _swap_items(self, int32_t row1, int32_t col1, int32_t row2, int32_t col2) noexcept nogil:
        """
        Swaps the items at the two keys.

        Assumes the mutex is held.
        """
        cdef pair[int32_t, int32_t] key1 = pair[int32_t, int32_t](row1, col1)
        cdef pair[int32_t, int32_t] key2 = pair[int32_t, int32_t](row2, col2)
        cdef map[pair[int32_t, int32_t], TableElementData].iterator it1, it2
        it1 = self._items.find(key1)
        it2 = self._items.find(key2)
        self._swap_items_from_it(row1, col1, row2, col2, it1, it2)

    def swap(self, key1, key2):
        """
        Swaps the items at the two keys.

        Same as
        tmp = table[key1]
        table[key1] = table[key2]
        table[key2] = tmp

        But much more efficient
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(hasattr(key1, "__len__")) or not(len(key1) == 2):
            raise ValueError("key1 must be a list of length 2")
        if not(hasattr(key2, "__len__")) or not(len(key2) == 2):
            raise ValueError("key2 must be a list of length 2")
        cdef int32_t row1, col1, row2, col2
        (row1, col1) = key1
        (row2, col2) = key2
        self._swap_items(row1, col1, row2, col2)
        # _dirty_num_rows_cols managed by _swap_items

    cpdef swap_rows(self, int32_t row1, int32_t row2):
        """
        Swaps the rows at the two indices.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        cdef int32_t i
        for i in range(self._num_cols):
            # TODO: can be optimized to avoid the find()
            self._swap_items(row1, i, row2, i)
        # _dirty_num_rows_cols managed by _swap_items

    cpdef swap_cols(self, int32_t col1, int32_t col2):
        """
        Swaps the cols at the two indices.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        cdef int32_t i
        for i in range(self._num_rows):
            # TODO: can be optimized to avoid the find()
            self._swap_items(i, col1, i, col2)
        # _dirty_num_rows_cols managed by _swap_items

    def remove_row(self, int32_t row):
        """
        Removes the row at the given index.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        cdef int32_t i
        for i in range(self._num_cols):
            self._delete_item(pair[int32_t, int32_t](row, i))
        # Shift all rows
        for i in range(row + 1, self._num_rows):
            self.swap_rows(i, i - 1)
        self._dirty_num_rows_cols = True

    def insert_row(self, int32_t row, items = None):
        """
        Inserts a row at the given index.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        cdef int32_t i
        # Shift all rows
        for i in range(self._num_rows - 1, row-1, -1):
            self.swap_rows(i, i + 1)
        self._dirty_num_rows_cols = True
        if items is not None:
            if not hasattr(items, '__len__'):
                raise ValueError("items must be a list")
            for i in range(len(items)):
                self._set_single_item(row, i, items[i])

    def set_row(self, int32_t row, items):
        """
        Sets the row at the given index.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        if not hasattr(items, '__len__'):
            raise ValueError("items must be a list")
        cdef int32_t i
        for i in range(len(items)):
            self._set_single_item(row, i, items[i])
        for i in range(len(items), self._num_cols):
            self._delete_item(pair[int32_t, int32_t](row, i))
        self._dirty_num_rows_cols = True

    def append_row(self, items):
        """
        Appends a row at the end of the table.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        if not hasattr(items, '__len__'):
            raise ValueError("items must be a list")
        cdef int32_t i
        for i in range(len(items)):
            self._set_single_item(self._num_rows, i, items[i])
        self._dirty_num_rows_cols = True

    def remove_col(self, int32_t col):
        """
        Removes the column at the given index.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        cdef int32_t i
        for i in range(self._num_rows):
            self._delete_item(pair[int32_t, int32_t](i, col))
        # Shift all columns
        for i in range(col + 1, self._num_cols):
            self.swap_cols(i, i - 1)
        self._dirty_num_rows_cols = True

    def insert_col(self, int32_t col, items=None):
        """
        Inserts a column at the given index.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        cdef int32_t i
        # Shift all columns
        for i in range(self._num_cols - 1, col-1, -1):
            self.swap_cols(i, i + 1)
        self._dirty_num_rows_cols = True
        if items is not None:
            if not hasattr(items, '__len__'):
                raise ValueError("items must be a list")
            for i in range(len(items)):
                self._set_single_item(i, col, items[i])

    def set_col(self, int32_t col, items):
        """
        Sets the column at the given index.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        if not hasattr(items, '__len__'):
            raise ValueError("items must be a list")
        cdef int32_t i
        for i in range(len(items)):
            self._set_single_item(i, col, items[i])
        for i in range(len(items), self._num_rows):
            self._delete_item(pair[int32_t, int32_t](i, col))
        self._dirty_num_rows_cols = True

    def append_col(self, items):
        """
        Appends a column at the end of the table.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        if not hasattr(items, '__len__'):
            raise ValueError("items must be a list")
        cdef int32_t i
        for i in range(len(items)):
            self._set_single_item(i, self._num_cols, items[i])
        self._dirty_num_rows_cols = True

    cdef void _update_row_col_counts(self) noexcept nogil:
        """Update row and column counts if needed."""
        if not self._dirty_num_rows_cols:
            return

        cdef pair[pair[int32_t, int32_t], TableElementData] key_element
        cdef int32_t max_row = -1
        cdef int32_t max_col = -1
        
        # Find max row/col indices
        for key_element in self._items:
            max_row = max(max_row, key_element.first.first)
            max_col = max(max_col, key_element.first.second) 

        self._num_rows = (max_row + 1) if max_row >= 0 else 0
        self._num_cols = (max_col + 1) if max_col >= 0 else 0
        self._dirty_num_rows_cols = False

    def row(self, int32_t idx):
        """Get a view of the specified row."""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex) 
        self._update_row_col_counts()
        if idx < 0:
            raise IndexError("Row index out of range")
        return TableRowView.create(self, idx)

    def col(self, int32_t idx):
        """Get a view of the specified column."""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        if idx < 0:
            raise IndexError("Column index out of range")
        return TableColView.create(self, idx)

    @property
    def next_row(self):
        """Get a view of the next row."""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        return TableRowView.create(self, self._num_rows)

    @property
    def next_col(self):
        """Get a view of the next column."""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        return TableColView.create(self, self._num_cols)

    def __enter__(self):
        """Raise an error if used as a context manager."""
        raise RuntimeError(
            "Do not attach items to the table directly.\n"
            "\n"
            "To add items to a table, use one of these methods:\n"
            "\n"
            "1. Set individual items using indexing:\n"
            "   table[row,col] = item\n"
            "\n" 
            "2. Use row views:\n"
            "   with table.row(0) as row:\n"
            "       cell1 = Button('Click')\n"
            "       cell2 = Text('Hello')\n"
            "\n"
            "3. Use column views:\n"
            "   with table.col(0) as col:\n"
            "       cell1 = Button('Top')\n"
            "       cell2 = Button('Bottom')\n" 
            "\n"
            "4. Use next_row/next_col for sequential access:\n"
            "   with table.next_row as row:\n"
            "       cell1 = Button('New')\n"
            "       cell2 = Text('Row')\n"
            "\n"
            "5. Use row/column operations:\n"
            "   table.set_row(0, [button1, button2])\n"
            "   table.set_col(0, [text1, text2])\n"
            "   table.append_row([item1, item2])\n"
            "   table.append_col([item1, item2])"
        )

    def sort_rows(self, int32_t ref_col, bint ascending=True):
        """Sort the rows using the value in ref_col as index.
        
        The sorting order is defined using the items's ordering_value
        when ordering_value is not set, it defaults to:
        - The content string (if it is a string)
        - The content before its conversion into string
        - If content is an uiItem, it defaults to the UUID (item creation order)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        cdef int32_t num_rows = self._num_rows

        if num_rows <= 1:
            return

        # Put in a list all the values to sort
        keys = []
        cdef int32_t i
        for i in range(num_rows):
            element = self._get_single_item(i, ref_col)
            if element is None:
                keys.append(0)
            keys.append(element.ordering_value)

        # Determine order
        key_array = np.array(keys, dtype=object)
        order = np.argsort(key_array, stable=True)
        if not(ascending):
            order = order[::-1]

        cdef map[pair[int32_t, int32_t], TableElementData] items_copy = self._items
        cdef pair[pair[int32_t, int32_t], TableElementData] element_key
        self._items.clear()

        # We do not need to play with refcounts because each item
        # is kept a single time. Similarly, row/col count doesn't
        # change, so we don't need to update them.

        # Create inverse permutation
        cdef vector[int32_t] inverse_order
        inverse_order.resize(len(order))
        for i in range(len(order)):
            inverse_order[order[i]] = i

        # apply the invert order
        cdef int32_t src_row
        cdef int32_t target_row
        cdef pair[int32_t, int32_t] target_key
        for element_key in items_copy:
            src_row = element_key.first.first
            target_row = inverse_order[src_row]
            target_key.first = target_row
            target_key.second = element_key.first.second
            self._items[target_key] = element_key.second

    def sort_cols(self, int32_t ref_row, bint ascending=True):
        """Sort the columns using the value in ref_row as index.
        
        The sorting order is defined using the items's ordering_value
        when ordering_value is not set, it defaults to:
        - The content string (if it is a string) 
        - The content before its conversion into string
        - If content is an uiItem, it defaults to the UUID (item creation order)
        
        Parameters:
            ref_row : int32_t 
                Row index to use for sorting
            ascending : bool, optional
                Sort in ascending order if True, descending if False.
                Defaults to True.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()

        # Put in a list all the values to sort
        keys = []
        cdef int32_t i
        for i in range(self._num_cols):
            element = self._get_single_item(ref_row, i) 
            if element is None:
                keys.append(0)
            keys.append(element.ordering_value)

        # Determine order
        key_array = np.array(keys, dtype=object)
        order = np.argsort(key_array, stable=True)
        if not(ascending):
            order = order[::-1]

        # Same as for rows
        cdef map[pair[int32_t, int32_t], TableElementData] items_copy = self._items
        cdef pair[pair[int32_t, int32_t], TableElementData] element_key
        self._items.clear()

        # Create inverse permutation
        cdef vector[int32_t] inverse_order
        inverse_order.resize(len(order))
        for i in range(len(order)):
            inverse_order[order[i]] = i

        # apply the invert order
        cdef int32_t src_col
        cdef int32_t target_col
        cdef pair[int32_t, int32_t] target_key
        for element_key in items_copy:
            src_col = element_key.first.second
            target_col = inverse_order[src_col]
            target_key.first = element_key.first.first
            target_key.second = target_col
            self._items[target_key] = element_key.second


    cdef bint draw_item(self) noexcept nogil:
        cdef Vec2 requested_size = self.scaled_requested_size()
        cdef imgui.ImGuiTableSortSpecs *sort_specs

        self._update_row_col_counts()
        cdef int32_t actual_num_cols = self._num_cols
        if self._num_cols_visible >= 0:
            actual_num_cols = self._num_cols_visible
        cdef int32_t actual_num_rows = self._num_rows
        if self._num_rows_visible >= 0:
            actual_num_rows = self._num_rows_visible

        if actual_num_cols > 512: # IMGUI_TABLE_MAX_COLUMNS
            actual_num_cols = 512

        cdef int32_t num_rows_frozen = self._num_rows_frozen
        if num_rows_frozen >= actual_num_rows:
            num_rows_frozen = actual_num_rows
        cdef int32_t num_cols_frozen = self._num_cols_frozen
        if num_cols_frozen >= actual_num_cols:
            num_cols_frozen = actual_num_cols

        cdef pair[pair[int32_t, int32_t], TableElementData] key_element
        cdef pair[int32_t, int32_t] key
        cdef TableElementData element
        cdef int32_t row, col
        cdef int32_t prev_row = -1
        cdef int32_t prev_col = -1
        cdef int32_t j
        cdef Vec2 pos_p_backup, pos_w_backup, parent_size_backup
        cdef pair[int32_t , PyObject*] col_data
        cdef pair[int32_t , PyObject*] row_data
        cdef map[int32_t , PyObject*].iterator it_row

        cdef bint row_hidden = False

        # Corruption issue for empty tables
        if actual_num_rows == 0 or actual_num_cols == 0:
            return False

        # If no column are enabled, there is a crash
        # if that occurs, force enable all of them
        # if we skip drawing instead, user cannot
        # re-enable them.
        # In addition, lock the column configurations
        cdef int32_t num_cols_disabled = 0
        for col_data in self._col_configs:
            if col_data.first >= actual_num_cols:
                break
            (<TableColConfig>col_data.second).mutex.lock()
            if not((<TableColConfig>col_data.second).state.cur.open):
                num_cols_disabled += 1

        if num_cols_disabled == actual_num_cols and num_cols_disabled > 0:
            for col_data in self._col_configs:
                if col_data.first >= actual_num_cols:
                    break
                (<TableColConfig>col_data.second).state.cur.open = True

        # Lock row configuration
        for row_data in self._row_configs:
            if row_data.first >= actual_num_rows:
                break
            (<TableRowConfig>row_data.second).mutex.lock()

        if imgui.BeginTable(self._imgui_label.c_str(),
                            actual_num_cols,
                            self._flags,
                            Vec2ImVec2(requested_size),
                            self._inner_width):
            # Set column configurations
            for col_data in self._col_configs:
                if col_data.first >= actual_num_cols:
                    break
                for j in range(prev_col+1, col_data.first):
                    # We must submit empty configs
                    # to increase the column index
                    imgui.TableSetupColumn("", 0, 0., 0)
                (<TableColConfig>col_data.second).setup(col_data.first, <uint32_t>self._flags)
                prev_col = col_data.first
            if num_cols_frozen > 0 or num_rows_frozen > 0:
                imgui.TableSetupScrollFreeze(num_cols_frozen, num_rows_frozen)
            # Submit header row
            if self._header:
                imgui.TableHeadersRow()
            # Draw each row
            pos_p_backup = self.context.viewport.parent_pos
            pos_w_backup = self.context.viewport.window_pos
            parent_size_backup = self.context.viewport.parent_size
            for key_element in self._items:
                key = key_element.first
                element = key_element.second
                row = key.first
                col = key.second
                if row >= actual_num_rows or col >= actual_num_cols:
                    continue
                if row != prev_row:
                    for j in range(prev_row, row):
                        row_hidden = False
                        it_row = self._row_configs.find(j+1) # +1 here, but not for below (empty rows)
                        if it_row == self._row_configs.end():
                            imgui.TableNextRow(0, 0.)
                            continue
                        if not((<TableRowConfig>dereference(it_row).second).show):
                            row_hidden = True
                            continue
                        imgui.TableNextRow(0, (<TableRowConfig>dereference(it_row).second).min_height)
                        imgui.TableSetBgColor(imgui.ImGuiTableBgTarget_RowBg1,
                            (<TableRowConfig>dereference(it_row).second).bg_color, -1)
                    prev_row = row
                if row_hidden:
                    continue
                imgui.TableSetColumnIndex(col)

                if element.bg_color != 0:
                    imgui.TableSetBgColor(imgui.ImGuiTableBgTarget_CellBg, element.bg_color, -1)

                # Draw the element
                if element.ui_item is not NULL:
                    # We lock because we check the parent field.
                    # Probably not needed though, as the parent
                    # must be locked to be edited.
                    (<uiItem>element.ui_item).mutex.lock()
                    if (<uiItem>element.ui_item).parent is self:
                        # Each cell is like a Child Window
                        self.context.viewport.parent_pos = ImVec2Vec2(imgui.GetCursorScreenPos())
                        self.context.viewport.window_pos = self.context.viewport.parent_pos
                        self.context.viewport.parent_size = ImVec2Vec2(imgui.GetContentRegionAvail())
                        (<uiItem>element.ui_item).draw()
                    (<uiItem>element.ui_item).mutex.unlock()
                elif not element.str_item.empty():
                    imgui.TextUnformatted(element.str_item.c_str())

                # Optional tooltip
                if element.tooltip_ui_item is not NULL:
                    (<uiItem>element.tooltip_ui_item).mutex.lock()
                    if (<uiItem>element.tooltip_ui_item).parent is self:
                        (<uiItem>element.tooltip_ui_item).draw()
                    (<uiItem>element.tooltip_ui_item).mutex.unlock()
                elif not element.str_tooltip.empty():
                    if imgui.IsItemHovered(0):
                        if imgui.BeginTooltip():
                            imgui.TextUnformatted(element.str_tooltip.c_str())
                            imgui.EndTooltip()
            # Submit empty rows if any
            for j in range(prev_row+1, actual_num_rows):
                it_row = self._row_configs.find(j)
                if it_row == self._row_configs.end():
                    imgui.TableNextRow(0, 0.)
                    continue
                if not((<TableRowConfig>dereference(it_row).second).show):
                    continue
                imgui.TableNextRow(0, (<TableRowConfig>dereference(it_row).second).min_height)
                imgui.TableSetBgColor(imgui.ImGuiTableBgTarget_RowBg1,
                    (<TableRowConfig>dereference(it_row).second).bg_color, -1)
            # Update column states
            for col_data in self._col_configs:
                if col_data.first >= actual_num_cols:
                    break
                (<TableColConfig>col_data.second).after_draw(col_data.first)
            # Sort if needed
            sort_specs = imgui.TableGetSortSpecs()
            if sort_specs != NULL and \
               sort_specs.SpecsDirty and \
               sort_specs.SpecsCount > 0:
                sort_specs.SpecsDirty = False
                with gil: # maybe do in a callback ?
                    try:
                        # Unclear if it should be in this
                        # order or the reverse one
                        for j in range(sort_specs.SpecsCount):
                            self.sort_rows(sort_specs.Specs[j].ColumnIndex,
                                           sort_specs.Specs[j].SortDirection != imgui.ImGuiSortDirection_Descending)
                    except Exception as e:
                        print(f"Error {e} while sorting column {j} of {self}")
            self.context.viewport.window_pos = pos_w_backup
            self.context.viewport.parent_pos = pos_p_backup
            self.context.viewport.parent_size = parent_size_backup
            # end table
            imgui.EndTable()

        # Release the row configurations
        for row_data in self._row_configs:
            if row_data.first >= actual_num_rows:
                break
            (<TableRowConfig>row_data.second).mutex.unlock()

        # Release the column configurations
        for col_data in self._col_configs:
            if col_data.first >= actual_num_cols:
                break
            (<TableColConfig>col_data.second).mutex.unlock()

        return False

