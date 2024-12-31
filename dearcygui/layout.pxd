from .core cimport uiItem
from .c_types cimport Vec2
from .types cimport Alignment

from cpython.ref cimport PyObject
from libcpp.vector cimport vector

cdef class Layout(uiItem):
    cdef bint _force_update
    cdef Vec2 _spacing
    cdef PyObject* _previous_last_child
    cdef Vec2 update_content_area(self) noexcept nogil
    cdef void draw_child(self, uiItem child) noexcept nogil
    cdef void draw_children(self) noexcept nogil
    cdef bint check_change(self) noexcept nogil
    cdef bint draw_item(self) noexcept nogil

cdef class HorizontalLayout(Layout):
    cdef Alignment _alignment_mode
    cdef vector[float] _positions
    cdef bint _no_wrap
    cdef float _wrap_x
    cdef float __compute_items_size(self, int&) noexcept nogil
    cdef void __update_layout_manual(self) noexcept nogil
    cdef void __update_layout(self) noexcept nogil
    cdef bint draw_item(self) noexcept nogil

cdef class VerticalLayout(Layout):
    cdef Alignment _alignment_mode
    cdef vector[float] _positions
    cdef float __compute_items_size(self, int&) noexcept nogil
    cdef void __update_layout(self) noexcept nogil
    cdef bint draw_item(self) noexcept nogil

cdef class WindowLayout(uiItem):
    cdef bint _force_update
    cdef Vec2 _spacing
    cdef PyObject* _previous_last_child
    cdef Vec2 update_content_area(self) noexcept nogil
    cdef void draw_child(self, uiItem child) noexcept nogil
    cdef void draw_children(self) noexcept nogil
    cdef bint check_change(self) noexcept nogil
    cdef void __update_layout(self) noexcept nogil
    cdef void draw(self) noexcept nogil

cdef class WindowHorizontalLayout(WindowLayout):
    cdef Alignment _alignment_mode
    cdef vector[float] _positions 
    cdef float __compute_items_size(self, int &n_items) noexcept nogil
    cdef void __update_layout(self) noexcept nogil

cdef class WindowVerticalLayout(WindowLayout):
    cdef Alignment _alignment_mode
    cdef vector[float] _positions 
    cdef float __compute_items_size(self, int &n_items) noexcept nogil
    cdef void __update_layout(self) noexcept nogil