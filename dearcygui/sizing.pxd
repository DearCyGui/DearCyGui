from libc.stdint cimport int32_t

from cpython.object cimport PyObject

from .core cimport uiItem
from .c_types cimport DCGMutex, DCGVector, ValueOrItem

cdef class baseSizing:
    cdef DCGMutex mutex
    cdef bint _frozen
    cdef int32_t _last_frame_resolved
    cdef float _current_value
    cdef DCGVector[PyObject*] _registered_items
    cdef void register(self, uiItem target)
    cdef void unregister(self, uiItem target)
    cdef float resolve(self, uiItem target) noexcept nogil
    cdef void _push(self, uiItem target) noexcept nogil
    cdef float _update_value(self, uiItem target) noexcept nogil
    @staticmethod
    cdef baseSizing Size(value)

cdef class RefWidth(baseSizing):
    cdef uiItem _ref
    cdef float _update_value(self, uiItem target) noexcept nogil

cdef class RefHeight(baseSizing):
    cdef uiItem _ref
    cdef float _update_value(self, uiItem target) noexcept nogil



# Implementation of sizing resolution function
cdef inline float resolve_size(ValueOrItem& sv, uiItem target) noexcept nogil:
    if not sv.is_item():
        return sv.get_value()
    cdef float result = \
        (<baseSizing>(<object>sv.get_item())).resolve(target)
    sv.set_item_value(result) # Used to catch changes
    return result

cdef inline void set_size(ValueOrItem& sv, value):
    if isinstance(value, (int, float)):
        sv.set_value(value)
        return
    cdef baseSizing value_sv = baseSizing.Size(value)
    sv.set_item(<PyObject*>value_sv)
