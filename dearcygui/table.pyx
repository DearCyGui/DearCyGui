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

from libc.stdint cimport uint32_t, int32_t
from libc.stdlib cimport malloc, free
from libcpp cimport bool
from libcpp.algorithm cimport stable_sort
from libcpp.map cimport map, pair
from libcpp.vector cimport vector

from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF
from cpython.sequence cimport PySequence_Check
cimport cython
from cython.operator cimport dereference, preincrement

from .core cimport baseItem, baseHandler, uiItem, \
    lock_gil_friendly, clear_obj_vector, append_obj_vector, \
    update_current_mouse_states, ItemStateView
from .c_types cimport DCGMutex, unique_lock, string_to_str,\
    string_from_str, Vec2
from .imgui_types cimport unparse_color, parse_color, Vec2ImVec2, \
    ImVec2Vec2
from .widget cimport Tooltip
from .wrapper cimport imgui

from .types cimport is_TableFlag, make_TableFlag


cdef class TableElement:
    """
    Configuration for a table element.
    
    A table element represents a cell in a table and contains all information
    about its content, appearance, and behavior. Each element can hold either
    a UI widget, text content, or nothing, and can optionally have a tooltip
    and background color.
    
    Elements can be created directly or via the table's indexing operation.
    """

    def __init__(self, *args, **kwargs):
        # set content first (ordering_value)
        if len(args) == 1:
            self.content = args[0]
        elif len(args) > 1:
            raise ValueError("TableElement accepts at most 1 positional argument")
        if "content" in kwargs:
            self.content = kwargs.pop("content")
        for key, value in kwargs.items():
            setattr(self, key, value)

    def configure(self, **kwargs):
        """
        Configure multiple attributes at once.
        
        This method allows setting multiple attributes in a single call, which
        can be more convenient and efficient than setting them individually.
        """
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
        The item to display in the table cell.
        
        This can be a UI widget (uiItem), a string, or any object that can be 
        converted to a string. When setting non-widget content, the ordering_value 
        is automatically set to the same value to ensure proper sorting behavior.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self.element.ui_item != NULL:
            return <uiItem>self.element.ui_item
        if not self.element.str_item.empty():
            return string_to_str(self.element.str_item)
        return None

    @content.setter
    def content(self, value):
        cdef unique_lock[DCGMutex] m
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
            self.element.str_item = string_from_str(str(value))
            self.ordering_value = value

    @property
    def tooltip(self):
        """
        The tooltip displayed when hovering over the cell.
        
        This can be a UI widget (like a Tooltip), a string, or any object that can be 
        converted to a string. The tooltip is displayed when the user hovers over 
        the cell's content.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self.element.tooltip_ui_item != NULL:
            return <uiItem>self.element.tooltip_ui_item
        if not self.element.str_tooltip.empty():
            return string_to_str(self.element.str_tooltip)
        return None

    @tooltip.setter
    def tooltip(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self.element.tooltip_ui_item != NULL:
            Py_DECREF(<object>self.element.tooltip_ui_item)
        self.element.tooltip_ui_item = NULL
        self.element.str_tooltip.clear()
        if isinstance(value, uiItem):
            Py_INCREF(value)
            self.element.tooltip_ui_item = <PyObject*>value
        elif value is not None:
            self.element.str_tooltip = string_from_str(str(value))

    @property
    def ordering_value(self):
        """
        The value used for ordering the table.
        
        This value is used when sorting the table. By default, it's automatically set 
        to the content value when content is set to a string or number. For UI widgets, 
        it defaults to the widget's UUID (creation order) if not explicitly specified.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self.element.ordering_value != NULL:
            return <object>self.element.ordering_value
        if self.element.ui_item != NULL:
            return (<uiItem>self.element.ui_item).uuid
        return None

    @ordering_value.setter
    def ordering_value(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self.element.ordering_value != NULL:
            Py_DECREF(<object>self.element.ordering_value)
        Py_INCREF(value)
        self.element.ordering_value = <PyObject*>value

    @property
    def bg_color(self):
        """
        The background color for the cell.
        
        This color overrides any default table cell background colors.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self.element.bg_color)
        return color

    @bg_color.setter
    def bg_color(self, value):
        cdef unique_lock[DCGMutex] m
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
    
    This special container is used internally by row and column views to temporarily 
    hold UI items created during a context manager block before they're assigned to 
    table cells. This allows for a cleaner, more intuitive API for populating tables.
    """
    def __cinit__(self):
        self.can_have_widget_child = True

cdef class TableRowView:
    """
    View class for accessing and manipulating a single row of a Table.
    
    This class provides a convenient interface for working with a specific row 
    in a table. It supports both indexing operations to access individual cells 
    and a context manager interface for adding multiple items to the row.
    """

    def __init__(self):
        raise TypeError("TableRowView cannot be instantiated directly")

    def __cinit__(self):
        self.table = None
        self.row_idx = 0
        self._temp_parent = None

    def __enter__(self):
        """
        Start a context for adding items to this row.
        
        When used as a context manager, TableRowView allows for intuitive 
        creation of UI elements that will be added to the row in sequence.
        Any Tooltip elements will be associated with the immediately preceding item.
        """
        self._temp_parent = TablePlaceHolderParent(self.table.context)
        self.table.context.push_next_parent(self._temp_parent)
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        """
        Convert children added during context into row values.
        
        When the context block ends, all items created within it are properly 
        arranged into the table row. Tooltip elements are associated with their 
        preceding items automatically.
        """
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
        """
        Get the element at the specified column in this row.
        
        This provides direct access to individual cells in the row by column index.
        If no element exists at the specified position, None is returned.
        """
        return self.table._get_single_item(self.row_idx, col_idx)

    def __setitem__(self, int32_t col_idx, value):  
        """
        Set the element at the specified column in this row.
        
        This allows directly setting a cell's content. The value can be a TableElement, 
        a UI widget, or any value that can be converted to a string.
        """
        self.table._set_single_item(self.row_idx, col_idx, value)

    def __delitem__(self, int32_t col_idx):
        """
        Delete the element at the specified column in this row.
        
        This removes a cell's content completely, leaving an empty cell.
        """
        cdef pair[int32_t, int32_t] key = pair[int32_t, int32_t](self.row_idx, col_idx)
        self.table._delete_item(key)

    @staticmethod
    cdef create(baseTable table, int32_t row_idx):
        """
        Create a TableRowView for the specified row.
        
        This static factory method creates a view object for the specified row
        in the given table. It's used internally by the Table class.
        """
        cdef TableRowView view = TableRowView.__new__(TableRowView)
        view.row_idx = row_idx
        view.table = table
        return view

cdef class TableColView:
    """
    View class for accessing and manipulating a single column of a Table.
    
    This class provides a convenient interface for working with a specific column 
    in a table. It supports both indexing operations to access individual cells 
    and a context manager interface for adding multiple items to the column.
    """

    def __init__(self):
        raise TypeError("TableColView cannot be instantiated directly")

    def __cinit__(self):
        self.table = None
        self.col_idx = 0
        self._temp_parent = None

    def __enter__(self):
        """
        Start a context for adding items to this column.
        
        When used as a context manager, TableColView allows for intuitive 
        creation of UI elements that will be added to the column in sequence.
        Any Tooltip elements will be associated with the immediately preceding item.
        """
        self._temp_parent = TablePlaceHolderParent(self.table.context)
        self.table.context.push_next_parent(self._temp_parent)
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        """
        Convert children added during context into column values.
        
        When the context block ends, all items created within it are properly
        arranged into the table column. Tooltip elements are associated with their
        preceding items automatically.
        """
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
        """
        Get the element at the specified row in this column.
        
        This provides direct access to individual cells in the column by row index.
        If no element exists at the specified position, None is returned.
        """
        return self.table._get_single_item(row_idx, self.col_idx)

    def __setitem__(self, int32_t row_idx, value):
        """
        Set the element at the specified row in this column.
        
        This allows directly setting a cell's content. The value can be a TableElement, 
        a UI widget, or any value that can be converted to a string.
        """  
        self.table._set_single_item(row_idx, self.col_idx, value)

    def __delitem__(self, int32_t row_idx):
        """
        Delete the element at the specified row in this column.
        
        This removes a cell's content completely, leaving an empty cell.
        """
        cdef pair[int32_t, int32_t] key = pair[int32_t, int32_t](row_idx, self.col_idx)
        self.table._delete_item(key)

    @staticmethod
    cdef create(baseTable table, int32_t col_idx):
        """
        Create a TableColView for the specified column.
        
        This static factory method creates a view object for the specified column
        in the given table. It's used internally by the Table class.
        """
        cdef TableColView view = TableColView.__new__(TableColView)
        view.col_idx = col_idx
        view.table = table
        return view

cdef extern from * nogil:
    """
    struct SortingPair {
        int32_t first;
        PyObject* second;
        
        SortingPair() : first(0), second(nullptr) {}
        SortingPair(int32_t f, PyObject* s) : first(f), second(s) {}
    };
    """
    cdef cppclass SortingPair:
        SortingPair()
        SortingPair(int32_t, PyObject*)
        int32_t first
        PyObject* second

cdef bool object_lower(SortingPair a, SortingPair b):
    if a.second == NULL:
        return True
    if b.second == NULL:
        return False
    try:
        return <object>a.second < <object>b.second
    except:
        return False

cdef bool object_higher(SortingPair a, SortingPair b):
    if a.second == NULL:
        return False
    if b.second == NULL:
        return True
    try:
        return <object>a.second > <object>b.second
    except:
        return False

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
    def __cinit__(self):
        self._num_rows = 0
        self._num_cols = 0
        self._dirty_num_rows_cols = False
        self._num_rows_visible = -1
        self._num_cols_visible = -1
        self._num_rows_frozen = 0
        self._num_cols_frozen = 0
        self.can_have_widget_child = True
        self._items = new map[pair[int32_t, int32_t], TableElementData]()
        self._iter_state = NULL  # Initialize iterator state to NULL

    def __dealloc__(self):
        self.clear_items()
        if self._items != NULL:
            del self._items
        if self._iter_state != NULL:
            free(self._iter_state)
            self._iter_state = NULL

    @property
    def num_rows(self):
        """
        Get the number of rows in the table.

        This corresponds to the maximum row
        index used in the table.
        """
        cdef unique_lock[DCGMutex] m
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
        cdef unique_lock[DCGMutex] m
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
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self._num_rows_visible < 0:
            return None
        return self._num_rows_visible

    @num_rows_visible.setter
    def num_rows_visible(self, value):
        cdef unique_lock[DCGMutex] m
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
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self._num_cols_visible < 0:
            return None
        return self._num_cols_visible

    @num_cols_visible.setter
    def num_cols_visible(self, value):
        cdef unique_lock[DCGMutex] m
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
        Number of rows with scroll frozen.

        Default is 0.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._num_rows_frozen

    @num_rows_frozen.setter
    def num_rows_frozen(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value < 0:
            raise ValueError("num_rows_frozen must be a non-negative integer")
        if value >= 128: # imgui limit
            raise ValueError("num_rows_frozen must be < 128")
        self._num_rows_frozen = value

    @property
    def num_cols_frozen(self):
        """
        Number of columns with scroll frozen.

        Default is 0.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._num_cols_frozen

    @num_cols_frozen.setter
    def num_cols_frozen(self, int32_t value):
        cdef unique_lock[DCGMutex] m
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
            for key_element in dereference(self._items):
                element = key_element.second
                if element.ui_item == item:
                    found = True
                    break
                if element.tooltip_ui_item == item:
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
        for key_element in dereference(self._items):
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
        """
        Release all items attached to the table.
        
        Does now clear row and column configurations.
        These are cleared only when the Table is released.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.clear_items()
        self.children = []

    cpdef void delete_item(self):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
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

    cdef TableElement _get_single_item(self, int32_t row, int32_t col):
        """
        Get item at specific target
        """
        cdef unique_lock[DCGMutex] m
        cdef pair[int32_t, int32_t] map_key = pair[int32_t, int32_t](row, col)
        lock_gil_friendly(m, self.mutex)
        cdef map[pair[int32_t, int32_t], TableElementData].iterator it
        it = self._items.find(map_key)
        if it == self._items.end():
            return None
        cdef TableElement element_config = \
            TableElement.from_element(dereference(it).second)
        return element_config

    @cython.annotation_typing(False)
    def __getitem__(self, key: tuple[int, int]) -> TableElement:
        """
        Get items at specific target
        """
        if PySequence_Check(key) == 0 or len(key) != 2:
            raise ValueError("index must be a list of length 2")
        cdef int32_t row, col
        (row, col) = key
        return self._get_single_item(row, col)

    def _set_single_item(self, int32_t row, int32_t col, value):
        """
        Set items at specific target
        """
        cdef unique_lock[DCGMutex] m
        if isinstance(value, dict):
            value = TableElement(**value)
        cdef TableElementData element
        # initialize element (not needed in C++ ?)
        element.ui_item = NULL
        element.tooltip_ui_item = NULL
        element.ordering_value = NULL
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
                element.str_item = string_from_str(str(value))
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
        dereference(self._items)[map_key] = element
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

    @cython.annotation_typing(False)
    def __setitem__(self, key: tuple[int, int], value: TableElement | uiItem | str | object) -> None:
        """
        Set items at specific target
        """

        if PySequence_Check(key) == 0 or len(key) != 2:
            raise ValueError("index must be of length 2")
        cdef int32_t row, col
        (row, col) = key
        self._set_single_item(row, col, value)

    @cython.annotation_typing(False)
    def __delitem__(self, key: tuple[int, int]) -> None:
        """
        Delete items at specific target
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if PySequence_Check(key) == 0 or len(key) != 2:
            raise ValueError("value must be a list of length 2")
        cdef int32_t row, col
        (row, col) = key
        cdef pair[int32_t, int32_t] map_key = pair[int32_t, int32_t](row, col)
        self._delete_item(map_key)

    @cython.annotation_typing(False)
    def __iter__(self) -> list[tuple[int, int]]:
        """
        Iterate over the keys in the table.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef pair[pair[int32_t, int32_t], TableElementData] key_element
        for key_element in dereference(self._items):
            yield key_element.first

    @cython.annotation_typing(False)
    def __len__(self) -> int:
        """
        Get the number of items in the table.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._items.size()

    @cython.annotation_typing(False)
    def __contains__(self, key: tuple[int, int]) -> bool:
        """
        Check if a key is in the table.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if PySequence_Check(key) == 0 or len(key) != 2:
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
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef pair[pair[int32_t, int32_t], TableElementData] key_element
        for key_element in dereference(self._items):
            yield key_element.first

    def values(self):
        """
        Get the values of the table.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef pair[pair[int32_t, int32_t], TableElementData] key_element
        for key_element in dereference(self._items):
            element_config = TableElement.from_element(key_element.second)
            yield element_config

    def get(self, key, default=None):
        """
        Get the value at a specific key.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if PySequence_Check(key) == 0 or len(key) != 2:
            raise ValueError("key must be a list of length 2")
        cdef int32_t row, col
        (row, col) = key
        cdef pair[int32_t, int32_t] map_key = pair[int32_t, int32_t](row, col)
        cdef map[pair[int32_t, int32_t], TableElementData].iterator it
        it = self._items.find(map_key)
        if it != self._items.end():
            return TableElement.from_element(dereference(it).second)
        return default

    @cython.final
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
            dereference(self._items)[key1] = dereference(it2).second
            self._items.erase(it2)
            self._dirty_num_rows_cols |= \
                row2 == self._num_rows - 1 or \
                col2 == self._num_cols - 1 or \
                row1 == self._num_rows - 1 or \
                col1 == self._num_cols - 1
            return
        if it1 != self._items.end() and it2 == self._items.end():
            dereference(self._items)[key2] = dereference(it1).second
            self._items.erase(it1)
            self._dirty_num_rows_cols |= \
                row2 == self._num_rows - 1 or \
                col2 == self._num_cols - 1 or \
                row1 == self._num_rows - 1 or \
                col1 == self._num_cols - 1
            return
        cdef TableElementData tmp = dereference(it1).second
        dereference(self._items)[key1] = dereference(it2).second
        dereference(self._items)[key2] = tmp

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
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if PySequence_Check(key1) == 0 or len(key1) != 2:
            raise ValueError("key1 must be a list of length 2")
        if PySequence_Check(key2) == 0 or len(key2) != 2:
            raise ValueError("key2 must be a list of length 2")
        cdef int32_t row1, col1, row2, col2
        (row1, col1) = key1
        (row2, col2) = key2
        self._swap_items(row1, col1, row2, col2)
        # _dirty_num_rows_cols managed by _swap_items

    cpdef void swap_rows(self, int32_t row1, int32_t row2):
        """
        Swaps the rows at the two indices.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        cdef int32_t i
        for i in range(self._num_cols):
            # TODO: can be optimized to avoid the find()
            self._swap_items(row1, i, row2, i)
        # _dirty_num_rows_cols managed by _swap_items

    cpdef void swap_cols(self, int32_t col1, int32_t col2):
        """
        Swaps the cols at the two indices.
        """
        cdef unique_lock[DCGMutex] m
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
        cdef unique_lock[DCGMutex] m
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
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        cdef int32_t i
        # Shift all rows
        for i in range(self._num_rows - 1, row-1, -1):
            self.swap_rows(i, i + 1)
        self._dirty_num_rows_cols = True
        if items is not None:
            if PySequence_Check(items) == 0:
                raise ValueError("items must be a sequence")
            for i in range(len(items)):
                self._set_single_item(row, i, items[i])

    def set_row(self, int32_t row, items):
        """
        Sets the row at the given index.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        if PySequence_Check(items) == 0:
            raise ValueError("items must be a sequence")
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
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        if PySequence_Check(items) == 0:
            raise ValueError("items must be a sequence")
        cdef int32_t i
        for i in range(len(items)):
            self._set_single_item(self._num_rows, i, items[i])
        self._dirty_num_rows_cols = True

    def remove_col(self, int32_t col):
        """
        Removes the column at the given index.
        """
        cdef unique_lock[DCGMutex] m
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
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        cdef int32_t i
        # Shift all columns
        for i in range(self._num_cols - 1, col-1, -1):
            self.swap_cols(i, i + 1)
        self._dirty_num_rows_cols = True
        if items is not None:
            if PySequence_Check(items) == 0:
                raise ValueError("items must be a sequence")
            for i in range(len(items)):
                self._set_single_item(i, col, items[i])

    def set_col(self, int32_t col, items):
        """
        Sets the column at the given index.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        if PySequence_Check(items) == 0:
            raise ValueError("items must be a sequence")
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
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        if PySequence_Check(items) == 0:
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
        for key_element in dereference(self._items):
            max_row = max(max_row, key_element.first.first)
            max_col = max(max_col, key_element.first.second) 

        self._num_rows = (max_row + 1) if max_row >= 0 else 0
        self._num_cols = (max_col + 1) if max_col >= 0 else 0
        self._dirty_num_rows_cols = False

    def row(self, int32_t idx):
        """Get a view of the specified row."""
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex) 
        self._update_row_col_counts()
        if idx < 0:
            raise IndexError("Row index out of range")
        return TableRowView.create(self, idx)

    def col(self, int32_t idx):
        """Get a view of the specified column."""
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        if idx < 0:
            raise IndexError("Column index out of range")
        return TableColView.create(self, idx)

    @property
    def next_row(self):
        """Get a view of the next row."""
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        return TableRowView.create(self, self._num_rows)

    @property
    def next_col(self):
        """Get a view of the next column."""
        cdef unique_lock[DCGMutex] m
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
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        cdef int32_t num_rows = self._num_rows

        if num_rows <= 1:
            return

        # Create vector of row indices and values to sort
        cdef vector[SortingPair] row_values
        cdef SortingPair sort_element
        row_values.reserve(num_rows)
        
        # Get values for sorting
        cdef int32_t i
        for i in range(num_rows):
            element = self._get_single_item(i, ref_col)
            sort_element.first = i
            if element is None:
                sort_element.second = NULL
            else:
                value = element.ordering_value
                # we don't need to incref as the items
                # are kept alive during this function
                # (due to the lock)
                sort_element.second = <PyObject*>value
            row_values.push_back(sort_element)

        # Sort the indices based on values
        if ascending:
            stable_sort(row_values.begin(), row_values.end(), object_lower)
        else:
            stable_sort(row_values.begin(), row_values.end(), object_higher)

        # Store in a temporary map the index mapping
        cdef vector[int32_t] row_mapping
        row_mapping.resize(num_rows)
        for i in range(num_rows):
            row_mapping[row_values[i].first] = i

        # Create copy of items and remap using sorted indices
        cdef map[pair[int32_t, int32_t], TableElementData] items_copy = dereference(self._items)
        self._items.clear()

        # Apply new ordering
        cdef pair[pair[int32_t, int32_t], TableElementData] element_key
        cdef int32_t src_row, target_row
        cdef pair[int32_t, int32_t] target_key
        for element_key in items_copy:
            src_row = element_key.first.first
            target_row = row_mapping[src_row]
            target_key.first = target_row
            target_key.second = element_key.first.second
            dereference(self._items)[target_key] = element_key.second

    def sort_cols(self, int32_t ref_row, bint ascending=True):
        """Sort the columns using the value in ref_row as index.
        
        The sorting order is defined using the items's ordering_value
        when ordering_value is not set, it defaults to:
        - The content string (if it is a string)
        - The content before its conversion into string 
        - If content is an uiItem, it defaults to the UUID (item creation order)
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._update_row_col_counts()
        cdef int32_t num_cols = self._num_cols

        if num_cols <= 1:
            return

        # Create vector of column indices and values to sort
        cdef vector[SortingPair] col_values
        cdef SortingPair sort_element
        col_values.reserve(num_cols)
        
        # Get values for sorting
        cdef int32_t i
        for i in range(num_cols):
            element = self._get_single_item(ref_row, i)
            sort_element.first = i
            if element is None:
                sort_element.second = NULL
            else:
                value = element.ordering_value
                # we don't need to incref as the items
                # are kept alive during this function
                # (due to the lock)
                sort_element.second = <PyObject*>value
            col_values.push_back(sort_element)

        # Sort the indices based on values
        if ascending:
            stable_sort(col_values.begin(), col_values.end(), object_lower)
        else:
            stable_sort(col_values.begin(), col_values.end(), object_higher)

        # Store in a temporary map the index mapping
        cdef vector[int32_t] col_mapping
        col_mapping.resize(num_cols)
        for i in range(num_cols):
            col_mapping[col_values[i].first] = i

        # Create copy of items and remap using sorted indices
        cdef map[pair[int32_t, int32_t], TableElementData] items_copy = dereference(self._items)
        self._items.clear()

        # Apply new ordering
        cdef pair[pair[int32_t, int32_t], TableElementData] element_key
        cdef int32_t src_col, target_col
        cdef pair[int32_t, int32_t] target_key
        for element_key in items_copy:
            src_col = element_key.first.second
            target_col = col_mapping[src_col]
            target_key.first = element_key.first.first
            target_key.second = target_col
            dereference(self._items)[target_key] = element_key.second

    cdef void _items_iter_prepare(self) noexcept nogil:
        """Start iterating over items."""
        if self._iter_state == NULL:
            self._iter_state = <TableIterState*>malloc(sizeof(TableIterState))
        self._iter_state.started = False
        self._iter_state.it = self._items.begin()
        self._iter_state.end = self._items.end()

    cdef bint _items_iter_next(self, int32_t* row, int32_t* col, TableElementData** element) noexcept nogil:
        """Get next item in iteration. Returns False when done."""
        if self._iter_state.started:
            preincrement(self._iter_state.it)
        self._iter_state.started = True
            
        if self._iter_state.it == self._iter_state.end:
            return False
            
        row[0] = dereference(self._iter_state.it).first.first
        col[0] = dereference(self._iter_state.it).first.second
        element[0] = &dereference(self._iter_state.it).second
        return True

    cdef void _items_iter_finish(self) noexcept nogil:
        """Clean up iteration state."""
        pass # No need to free, we keep the allocated memory for reuse

    cdef size_t _get_num_items(self) noexcept nogil:
        """Get total number of items."""
        return self._items.size()

    cdef bint _items_contains(self, int32_t row, int32_t col) noexcept nogil:
        """Check if an item exists at the given position."""
        cdef pair[int32_t, int32_t] key = pair[int32_t, int32_t](row, col)
        return self._items.find(key) != self._items.end()

cdef class TableColConfig(baseItem):
    """
    Configuration for a table column.
    
    A table column can be hidden, stretched, resized, and more. This class provides
    properties to control all visual and behavioral aspects of a table column.
    
    The states can be changed programmatically but can also be modified by user 
    interaction. To listen for state changes, use handlers such as:
    - ToggledOpenHandler/ToggledCloseHandler to detect when the user shows/hides the column
    - ContentResizeHandler to detect when the user resizes the column
    - HoveredHandler to detect when the user hovers over the column
    """
    def __cinit__(self):
        self.p_state = &self.state
        self.state.cur.open = True
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_toggled = True # hide/enable
        self.state.cap.can_be_clicked = True
        #self.state.cap.can_be_active = True # sort request. can be implemented (manual header submission)
        #self.state.cap.has_position = True # can be implemented (manual header submission)
        #self.state.cap.has_content_region = True # can be implemented (manual header submission)
        self._flags = <uint32_t>imgui.ImGuiTableColumnFlags_None
        self._width = 0.0
        self._stretch_weight = 1.0
        self._fixed = False
        self._stretch = False
        self._dpi_scaling = True

    @property
    def state(self):
        """
        The current state of the column header
        
        The state is an instance of ItemStateView which is a class
        with property getters to retrieve various readonly states.

        The ItemStateView instance is just a view over the current states,
        not a copy, thus the states get updated automatically.
        """
        return ItemStateView.create(self)

    @property
    def show(self):
        """
        Whether the column should be shown.
        
        This differs from 'enabled' as it cannot be changed through user interaction.
        Setting show=False will hide the column regardless of user preferences.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_Disabled) == 0

    @show.setter
    def show(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_Disabled
        if not(value):
            self._flags |= imgui.ImGuiTableColumnFlags_Disabled

    @property
    def enabled(self):
        """
        Whether the column is currently enabled.
        
        This can be changed both programmatically and through user interaction
        via the table's context menu.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.open

    @enabled.setter
    def enabled(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.state.cur.open = value

    @property
    def stretch(self):
        """
        The column's sizing behavior.
        
        Three values are possible:
        - True: Column will stretch based on its stretch_weight
        - False: Column has fixed width based on the width property
        - None: Column follows the table's default sizing behavior
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self._stretch:
            return True
        elif self._fixed:
            return False
        return None

    @stretch.setter
    def stretch(self, value):
        cdef unique_lock[DCGMutex] m
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

    @property
    def default_sort(self):
        """
        Whether the column is set as the default sorting column.
        
        When True, this column will be used for initial sorting when the
        table is first displayed.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_DefaultSort) != 0

    @default_sort.setter
    def default_sort(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_DefaultSort
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_DefaultSort

    @property
    def no_resize(self):
        """
        Whether the column can be resized by the user.
        
        When True, the user will not be able to drag the column's edge to resize it.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_NoResize) != 0

    @no_resize.setter
    def no_resize(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_NoResize
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_NoResize

    @property
    def no_hide(self):
        """
        Whether the column can be hidden by the user.
        
        When True, the user will not be able to hide this column through
        the context menu.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_NoHide) != 0 

    @no_hide.setter
    def no_hide(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_NoHide
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_NoHide

    @property 
    def no_clip(self):
        """
        Whether content in this column should be clipped.
        
        When True, content that overflows the column width will not be clipped,
        which may cause it to overlap with adjacent columns.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_NoClip) != 0

    @no_clip.setter
    def no_clip(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_NoClip
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_NoClip

    @property
    def no_sort(self):
        """
        Whether the column can be used for sorting.
        
        When True, clicking on this column's header will not trigger 
        sorting of the table.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_NoSort) != 0

    @no_sort.setter
    def no_sort(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_NoSort
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_NoSort

    @property
    def prefer_sort_ascending(self):
        """
        Whether to use ascending order for initial sort.
        
        When True and this column is used for sorting, the initial sort
        direction will be ascending.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_PreferSortAscending) != 0

    @prefer_sort_ascending.setter  
    def prefer_sort_ascending(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_PreferSortAscending
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_PreferSortAscending

    @property
    def prefer_sort_descending(self):
        """
        Whether to use descending order for initial sort.
        
        When True and this column is used for sorting, the initial sort
        direction will be descending.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_PreferSortDescending) != 0

    @prefer_sort_descending.setter
    def prefer_sort_descending(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_PreferSortDescending
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_PreferSortDescending

    @property
    def no_sort_ascending(self):
        """
        Whether sorting in ascending order is allowed.
        
        When True, the user will not be able to sort this column in ascending order.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_NoSortAscending) != 0

    @no_sort_ascending.setter
    def no_sort_ascending(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_NoSortAscending
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_NoSortAscending

    @property
    def no_sort_descending(self):
        """
        Whether sorting in descending order is allowed.
        
        When True, the user will not be able to sort this column in descending order.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_NoSortDescending) != 0

    @no_sort_descending.setter
    def no_sort_descending(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_NoSortDescending
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_NoSortDescending

    @property
    def no_header_label(self):
        """
        Whether to display the column header label.
        
        When True, the column header will not display the label text but
        will still be interactive for sorting and other operations.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_NoHeaderLabel) != 0

    @no_header_label.setter
    def no_header_label(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_NoHeaderLabel
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_NoHeaderLabel

    @property
    def no_header_width(self):
        """
        Whether to show column width when the header is hovered.
        
        When True, the column width tooltip will not be shown when hovering
        over the edge between columns.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_NoHeaderWidth) != 0

    @no_header_width.setter
    def no_header_width(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_NoHeaderWidth
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_NoHeaderWidth

    @property
    def width(self):
        """
        The fixed width of the column in pixels.
        
        This is used only when the column is in fixed width mode (stretch=False).
        A value of 0 means automatic width based on content.
        Note that this width is only used when the column is initialized and won't 
        update automatically after user resizing.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._width

    @width.setter
    def width(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._width = value

    @property
    def no_scaling(self):
        """
        Whether to disable automatic DPI scaling for this column.
        
        By default, the requested width is multiplied by the global scale 
        factor based on the viewport's DPI settings. When True, this automatic
        scaling is disabled.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return not(self._dpi_scaling)

    @no_scaling.setter
    def no_scaling(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._dpi_scaling = not(value)

    @property 
    def stretch_weight(self):
        """
        The weight used when stretching this column.
        
        When the column is in stretch mode (stretch=True), this weight determines
        how much space this column gets relative to other stretched columns.
        Higher values result in wider columns.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._stretch_weight

    @stretch_weight.setter
    def stretch_weight(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value < 0:
            raise ValueError("stretch_weight must be >= 0")
        self._stretch_weight = value

    @property
    def no_reorder(self): 
        """
        Whether the column can be reordered by the user.
        
        When True, the user will not be able to drag this column header to
        change its position in the table.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & imgui.ImGuiTableColumnFlags_NoReorder) != 0

    @no_reorder.setter
    def no_reorder(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~imgui.ImGuiTableColumnFlags_NoReorder
        if value:
            self._flags |= imgui.ImGuiTableColumnFlags_NoReorder

    @property
    def label(self):
        """
        The text displayed in the column header.
        
        This label appears in the header row and is used for identifying the column.
        It's also displayed in the context menu when right-clicking on the header.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return string_to_str(self._label)

    @label.setter
    def label(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._label = string_from_str(value)

    @property
    def handlers(self):
        """
        The event handlers bound to this column.
        
        Handlers can be used to react to various events like clicking, hovering,
        or enabling/disabling the column. You can add multiple handlers to respond
        to different events.
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
    
    A table row can be customized with various appearance and behavior settings.
    This includes hiding/showing rows, setting background colors, and defining
    minimum height requirements.
    
    Row configurations work alongside column configurations to provide complete
    control over the table's appearance.
    """

    def __cinit__(self):
        #self.p_state = &self.state
        #self.state.has_content_region
        self.min_height = 0.0
        self.bg_color = 0
        self.show = True

    @property
    def show(self):
        """
        Controls whether the row is visible.
        
        When set to False, the row will be completely hidden from view and
        will not take up any space in the table. This is different from
        setting a zero height, as a zero-height row would still create
        a visible gap.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.show

    @show.setter
    def show(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.show = value

    @property
    def bg_color(self):
        """
        Background color for the entire row.
        
        This color is applied to the entire row as a background. When set to a
        non-zero value, it will blend with any theme-defined row background colors.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self.bg_color)
        return color

    @bg_color.setter
    def bg_color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex) 
        self.bg_color = parse_color(value)

    @property
    def min_height(self):
        """
        Minimum height of the row in pixels.
        
        When set to a value greater than zero, this ensures the row will be at
        least this tall, regardless of its content. This can be useful for creating
        consistent row heights or ensuring sufficient space for content.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.min_height

    @min_height.setter
    def min_height(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex) 
        self.min_height = value

    @property
    def handlers(self):
        """
        Event handlers bound to this row.
        
        Handlers can be used to respond to events related to this row.
        You can add multiple handlers to respond to different events,
        allowing for complex interactions with the row's state and appearance.
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

cdef class TableRowConfigView:
    """
    A view for accessing and manipulating row configurations in a table.
    
    This view provides a convenient interface for working with row configurations.
    It supports indexing to access individual row configurations and setting
    specific attributes on those configurations.
    
    The view is typically accessed through the `table.row_config` property.
    """

    def __init__(self):
        raise TypeError("TableRowConfigView cannot be instantiated directly")

    def __cinit__(self):
        self.table = None

    def __getitem__(self, int32_t row_idx) -> TableRowConfig:
        """
        Get the row configuration for the specified row.
        
        This retrieves the configuration object for a specific row, allowing
        you to inspect or modify its properties. If the row doesn't have an
        existing configuration, a default one will be created.
        """
        return self.table.get_row_config(row_idx)

    def __setitem__(self, int32_t row_idx, TableRowConfig config) -> None:
        """
        Set the row configuration for the specified row.
        
        This replaces the entire configuration for a specific row with a new
        configuration object. This allows for complete customization of the
        row's appearance and behavior.
        """
        self.table.set_row_config(row_idx, config)

    def __delitem__(self, int32_t row_idx) -> None:
        """
        Reset the row configuration to default for the specified row.
        
        This removes any custom configuration for the specified row and
        replaces it with a new default configuration. This effectively
        resets all row settings to their default values.
        """
        self.table.set_row_config(row_idx, TableRowConfig(self.table.context))

    def __call__(self, int32_t row_idx, str attribute, value) -> TableRowConfig:
        """
        Set a specific attribute on a row's configuration.
        
        This is a convenient shorthand for getting a row configuration,
        setting a single attribute, and then updating the configuration.
        It returns the modified configuration object for further chaining.
        
        Example: table.row_config(0, 'bg_color', (1.0, 0.0, 0.0, 1.0))
        """
        cdef TableRowConfig config = self.table.get_row_config(row_idx)
        setattr(config, attribute, value)
        self.table.set_row_config(row_idx, config)
        return config

    @staticmethod
    cdef TableRowConfigView create(Table table):
        """
        Create a TableRowConfigView for the specified table.
        
        This factory method creates a view object for the row configurations
        in the given table. It's used internally by the Table class to provide
        access to row configurations through the row_config property.
        """
        cdef TableRowConfigView view = TableRowConfigView.__new__(TableRowConfigView)
        view.table = table
        return view

cdef class Table(baseTable):
    """Table widget with advanced display and interaction capabilities.
    
    A table is a grid of cells that can contain text, images, buttons, or any other
    UI elements. This implementation provides full ImGui table functionality including
    sortable columns, scrolling, resizable columns, and customizable headers.
    
    Tables can be populated with data in multiple ways: directly setting cell contents,
    using row or column views, or bulk operations like append_row/col. The appearance
    and behavior can be customized through column and row configurations.
    """
    def __cinit__(self):
        self.state.cap.can_be_hovered = True
        #self.state.cap.can_be_toggled = True # TODO needs manual header submission
        #self.state.cap.can_be_active = True # TODO needs manual header submission
        self.state.cap.can_be_clicked = True
        self.state.cap.has_position = True
        #self.state.cap.has_content_region = True # TODO, unsure if possible
        self._col_configs = new map[int32_t, PyObject*]()
        self._row_configs = new map[int32_t, PyObject*]()
        self._inner_width = 0.
        self._flags = imgui.ImGuiTableFlags_None

    def __dealloc(self):
        cdef pair[int32_t, PyObject*] key_value
        for key_value in dereference(self._col_configs):
            Py_DECREF(<object>key_value.second)
        for key_value in dereference(self._row_configs):
            Py_DECREF(<object>key_value.second)
        self._col_configs.clear()
        self._row_configs.clear()
        if self._col_configs != NULL:
            del self._col_configs
        if self._row_configs != NULL:
            del self._row_configs

    cdef TableColConfig get_col_config(self, int32_t col_idx):
        """Retrieve the configuration object for the specified column.
        
        This method gets the existing column configuration or creates a default
        one if none exists. Column configurations control various aspects of
        column appearance and behavior, including width, sorting capability,
        and visibility.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if col_idx < 0:
            raise ValueError(f"Invalid column index {col_idx}")
        cdef map[int32_t, PyObject*].iterator it
        it = self._col_configs.find(col_idx)
        if it == self._col_configs.end():
            config = TableColConfig(self.context)
            Py_INCREF(config)
            dereference(self._col_configs)[col_idx] = <PyObject*>config
            return config
        cdef PyObject* item = dereference(it).second
        cdef TableColConfig found_config = <TableColConfig>item
        return found_config

    cdef void set_col_config(self, int32_t col_idx, TableColConfig config):
        """Set the configuration for the specified column.
        
        This replaces any existing column configuration with the provided one.
        This allows complete customization of column appearance and behavior,
        including width, visibility, sorting options and more.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if col_idx < 0:
            raise ValueError(f"Invalid column index {col_idx}")
        cdef map[int32_t, PyObject*].iterator it
        it = self._col_configs.find(col_idx)
        if it != self._col_configs.end():
            Py_DECREF(<object>dereference(it).second)
        Py_INCREF(config)
        dereference(self._col_configs)[col_idx] = <PyObject*>config

    cdef TableRowConfig get_row_config(self, int32_t row_idx):
        """Retrieve the configuration object for the specified row.
        
        This method gets the existing row configuration or creates a default one
        if none exists. Row configurations control various aspects of row appearance
        and behavior, including visibility, background color, and minimum height.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if row_idx < 0:
            raise ValueError(f"Invalid row index {row_idx}")
        cdef map[int32_t, PyObject*].iterator it
        it = self._row_configs.find(row_idx)
        if it == self._row_configs.end():
            config = TableRowConfig(self.context)
            Py_INCREF(config)
            dereference(self._row_configs)[row_idx] = <PyObject*>config
            return config
        cdef PyObject* item = dereference(it).second
        cdef TableRowConfig found_config = <TableRowConfig>item
        return found_config

    cdef void set_row_config(self, int32_t row_idx, TableRowConfig config):
        """Set the configuration for the specified row.
        
        This replaces any existing row configuration with the provided one.
        This allows complete customization of row appearance and behavior,
        including visibility, background color, and minimum height.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if row_idx < 0:
            raise ValueError(f"Invalid row index {row_idx}")
        cdef map[int32_t, PyObject*].iterator it
        it = self._row_configs.find(row_idx)
        if it != self._row_configs.end():
            Py_DECREF(<object>dereference(it).second)
        Py_INCREF(config)
        dereference(self._row_configs)[row_idx] = <PyObject*>config

    @property
    def col_config(self):
        """Access interface for column configurations.
        
        This property provides a specialized view for accessing and manipulating the
        configurations for individual columns in the table. Through this view, you can
        get, set, or modify column properties like width, visibility, and sorting behavior.
        
        The view supports both indexing (col_config[0]) and attribute setting
        (col_config(0, 'width', 100)).
        """
        return TableColConfigView.create(self)

    @property
    def row_config(self):
        """Access interface for row configurations.
        
        This property provides a specialized view for accessing and manipulating the
        configurations for individual rows in the table. Through this view, you can
        get, set, or modify row properties like visibility, background color, and
        minimum height.
        
        The view supports both indexing (row_config[0]) and attribute setting
        (row_config(0, 'bg_color', (1,0,0,1))).
        """
        return TableRowConfigView.create(self)

    @property 
    def flags(self):
        """Table behavior and appearance flags.
        
        These flags control many aspects of the table's behavior, including:
        - Scrolling capabilities (horizontal, vertical)
        - Resizing behavior (fixed/flexible columns)
        - Border styles and visibility
        - Row/column highlighting
        - Sorting capabilities
        - Context menu availability
        
        Multiple flags can be combined using bitwise OR operations.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return make_TableFlag(<uint32_t>self._flags)

    @flags.setter  
    def flags(self, value):
        """
        Set the table flags.

        Args:
            value: A TableFlag value or combination of TableFlag values
        """
        if not is_TableFlag(value):
            raise TypeError("flags must be a TableFlag value")
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags = <imgui.ImGuiTableFlags><uint32_t>make_TableFlag(value)

    @property
    def inner_width(self):
        """Width of the table content when horizontal scrolling is enabled.
        
        This property controls the inner content width of the table, which affects
        how horizontal scrolling behaves:
        
        - With ScrollX disabled: This property is ignored
        - With ScrollX enabled and value = 0: Table fits within the outer width
        - With ScrollX enabled and value > 0: Table has a fixed content width
          that may be larger than the visible area, enabling horizontal scrolling
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._inner_width

    @inner_width.setter
    def inner_width(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._inner_width = value

    @property
    def header(self):
        """Whether to display a table header row.
        
        When enabled, the table shows a header row at the top with column labels
        and interactive elements for sorting and resizing columns. This header
        uses the labels defined in each column's configuration.
        
        Disabling this hides the header entirely, which can be useful for data
        display tables where column manipulation is not needed.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._header

    @header.setter
    def header(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._header = value

    cdef bint draw_item(self) noexcept nogil:
        """Draw the table with all its content and apply configurations.
        
        This method handles the complete rendering of the table, including:
        - Setting up columns based on their configurations
        - Rendering the optional header row
        - Drawing all cell contents (text, widgets, etc.)
        - Handling tooltips and background colors
        - Applying sorting when requested
        - Managing row and column visibility
        
        The drawing respects all configuration settings for both rows and columns.
        """
        cdef Vec2 requested_size = self.get_requested_size()
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
        cdef TableElementData *element
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
        for col_data in dereference(self._col_configs):
            if col_data.first >= actual_num_cols:
                break
            (<TableColConfig>col_data.second).mutex.lock()
            if not((<TableColConfig>col_data.second).state.cur.open):
                num_cols_disabled += 1

        if num_cols_disabled == actual_num_cols and num_cols_disabled > 0:
            for col_data in dereference(self._col_configs):
                if col_data.first >= actual_num_cols:
                    break
                (<TableColConfig>col_data.second).state.cur.open = True

        # Lock row configuration
        for row_data in dereference(self._row_configs):
            if row_data.first >= actual_num_rows:
                break
            (<TableRowConfig>row_data.second).mutex.lock()

        if imgui.BeginTable(self._imgui_label.c_str(),
                            actual_num_cols,
                            self._flags,
                            Vec2ImVec2(requested_size),
                            self._inner_width):
            # Set column configurations
            for col_data in dereference(self._col_configs):
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

            # Prepare iteration
            self._items_iter_prepare()

            while self._items_iter_next(&row, &col, &element):
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

                # Draw element content
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

            # Clean up iteration
            self._items_iter_finish()

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
            for col_data in dereference(self._col_configs):
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
            self.update_current_state()
        else:
            self.set_hidden_no_handler_and_propagate_to_children_with_handlers()

        # Release the row configurations
        for row_data in dereference(self._row_configs):
            if row_data.first >= actual_num_rows:
                break
            (<TableRowConfig>row_data.second).mutex.unlock()

        # Release the column configurations
        for col_data in dereference(self._col_configs):
            if col_data.first >= actual_num_cols:
                break
            (<TableColConfig>col_data.second).mutex.unlock()

        return False
