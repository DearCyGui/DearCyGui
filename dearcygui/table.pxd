from libcpp.map cimport map, pair
from libc.stdint cimport uint32_t, int32_t

from cpython.object cimport PyObject

from .core cimport baseItem, uiItem, \
    itemState
from .c_types cimport DCGMutex, DCGString



# Base structure for table data
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
    DCGString str_item
    # if tooltip_ui_item is not set, value used
    # for the tooltip
    DCGString str_tooltip
    uint32_t bg_color

# Iterator state for table items
cdef struct TableIterState:
    # Current iterator position
    map[pair[int32_t, int32_t], TableElementData].iterator it
    # End iterator for comparison
    map[pair[int32_t, int32_t], TableElementData].iterator end
    # Whether iteration has started
    bint started

cdef class TableElement:
    """
    Configuration for a table element.

    A table element can be hidden, stretched, resized, etc.
    """
    cdef DCGMutex mutex
    cdef TableElementData element
    @staticmethod
    cdef TableElement from_element(TableElementData element)

cdef class TablePlaceHolderParent(baseItem):
    """
    Placeholder parent to store items outside the rendering tree.
    Can be only be parent to items that can be attached to tables
    """
    pass

cdef class TableRowView:
    """View class for accessing and manipulating a single row of a Table."""
    cdef baseTable table
    cdef int32_t row_idx
    cdef TablePlaceHolderParent _temp_parent # For with statement

    @staticmethod
    cdef create(baseTable table, int32_t row_idx)

cdef class TableColView:
    """View class for accessing and manipulating a single column of a Table."""
    cdef baseTable table  
    cdef int32_t col_idx
    cdef TablePlaceHolderParent _temp_parent # For with statement

    @staticmethod
    cdef create(baseTable table, int32_t col_idx)

cdef class baseTable(uiItem):
    """
    Base class for Table widgets.
    
    A table is a grid of cells, where each cell can contain
    text, images, buttons, etc. The table can be used to
    display data, but also to interact with the user.

    This base class implements all the python interactions
    and the basic structure of the table. The actual rendering
    is done by the derived classes.
    """
    # protected variables
    cdef int32_t _num_rows
    cdef int32_t _num_cols
    cdef int32_t _num_rows_visible
    cdef int32_t _num_cols_visible
    cdef int32_t _num_rows_frozen
    cdef int32_t _num_cols_frozen
    # private variables
    cdef bint _dirty_num_rows_cols
    cdef TableIterState* _iter_state  # New: store iterator state
    # We use pointers to maintain a fixed structure size,
    # even if map implementation changes.
    # Do not use these fields as they may be implemented
    # with a different map implementation than your compiler.
    cdef map[pair[int32_t, int32_t], TableElementData] *_items

    # public API
    cdef void clear_items(self) # assumes mutex is held
    cpdef void delete_item(self)
    cpdef void swap_rows(self, int32_t row1, int32_t row2)
    cpdef void swap_cols(self, int32_t col1, int32_t col2)
    # protected, assumes mutex is held
    cdef void _decref_and_detach(self, PyObject* item)
    cdef void _delete_and_siblings(self)
    cdef bint _delete_item(self, pair[int32_t, int32_t] key)
    cdef TableElement _get_single_item(self, int32_t row, int32_t col)
    cdef void _swap_items(self, int32_t row1, int32_t col1, int32_t row2, int32_t col2) noexcept nogil
    cdef void _update_row_col_counts(self) noexcept nogil
    # Protected iterator helpers for derived classes
    cdef void _items_iter_prepare(self) noexcept nogil
    cdef bint _items_iter_next(self, int32_t* row, int32_t* col, TableElementData** element) noexcept nogil
    cdef void _items_iter_finish(self) noexcept nogil
    cdef size_t _get_num_items(self) noexcept nogil
    cdef bint _items_contains(self, int32_t row, int32_t col) noexcept nogil
    # private do not call outside (map ABI)
    cdef void _swap_items_from_it(self,
                             int32_t row1, int32_t col1, int32_t row2, int32_t col2,
                             map[pair[int32_t, int32_t], TableElementData].iterator &it1,
                             map[pair[int32_t, int32_t], TableElementData].iterator &it2) noexcept nogil


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
    cdef uint32_t _flags # imgui.ImGuiTableColumnFlags
    cdef float _width
    cdef float _stretch_weight
    cdef DCGString _label
    cdef bint _dpi_scaling
    cdef bint _stretch
    cdef bint _fixed

    cdef void setup(self, int32_t col_idx, uint32_t table_flags) noexcept nogil
    cdef void after_draw(self, int32_t col_idx) noexcept nogil

cdef class TableColConfigView:
    """
    A View of a Table which you can index to get the
    TableColConfig for a specific column.
    """
    cdef Table table

    @staticmethod
    cdef TableColConfigView create(Table table)

cdef class TableRowConfig(baseItem):
    """
    Configuration for a table row.

    A table row can be hidden and its background color can be changed.
    """
    #cdef itemState state
    cdef bint show
    cdef float min_height
    cdef uint32_t bg_color

cdef class TableRowConfigView:
    """
    A View of a Table which you can index to get the
    TableRowConfig for a specific row.
    """
    cdef Table table

    @staticmethod
    cdef TableRowConfigView create(Table table)

cdef class Table(baseTable):
    """Table widget.
    
    A table is a grid of cells, where each cell can contain
    text, images, buttons, etc. The table can be used to
    display data, but also to interact with the user.

    This class implements the base imgui Table visual.
    """
    cdef map[int32_t, PyObject*] *_col_configs # TableColConfig
    cdef map[int32_t, PyObject*] *_row_configs # TableRowConfig
    cdef float _inner_width
    cdef bint _header
    cdef uint32_t _flags # imgui.ImGuiTableFlags

    cdef TableColConfig get_col_config(self, int32_t col_idx)
    cdef void set_col_config(self, int32_t col_idx, TableColConfig config)
    cdef TableRowConfig get_row_config(self, int32_t row_idx)
    cdef void set_row_config(self, int32_t row_idx, TableRowConfig config)
    cdef bint draw_item(self) noexcept nogil