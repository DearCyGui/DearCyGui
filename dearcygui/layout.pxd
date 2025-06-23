from libc.stdint cimport int32_t
from cpython.object cimport PyObject

from .core cimport uiItem
from .c_types cimport Vec2, DCGVector
from .types cimport Alignment

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
    cdef DCGVector[float] _positions
    cdef bint _no_wrap
    cdef float _wrap_x
    cdef float __compute_items_size(self, int32_t&) noexcept nogil
    cdef void __update_layout_manual(self)
    cdef void __update_layout(self)
    cdef bint draw_item(self) noexcept nogil

cdef class VerticalLayout(Layout):
    cdef Alignment _alignment_mode
    cdef DCGVector[float] _positions
    cdef bint _no_wrap
    cdef float _wrap_y
    cdef float __compute_items_size(self, int32_t&) noexcept nogil
    cdef void __update_layout_manual(self)
    cdef void __update_layout(self)
    cdef bint draw_item(self) noexcept nogil

cdef class WindowLayout(uiItem):
    cdef bint _force_update
    cdef bint _clip
    cdef PyObject* _previous_last_child
    cdef Vec2 update_content_area(self) noexcept nogil
    cdef void draw_child(self, uiItem child) noexcept nogil
    cdef void draw_children(self) noexcept nogil
    cdef bint check_change(self) noexcept nogil
    cdef void draw(self) noexcept nogil
