from libc.stdint cimport int32_t
from .core cimport baseItem
from .c_types cimport DCGMutex

cdef class Texture(baseItem):
    ### Public read-only variables ###
    cdef void* allocated_texture
    cdef int32_t width
    cdef int32_t height
    cdef int32_t num_chans
    ### private variables ###
    cdef DCGMutex _write_mutex
    cdef bint _hint_dynamic
    cdef bint _dynamic
    cdef unsigned _buffer_type
    cdef int32_t _filtering_mode
    cdef bint _readonly
    cdef bint _no_realloc
    cdef void set_content(self, content)
    cdef void c_gl_begin_read(self) noexcept nogil
    cdef void c_gl_end_read(self) noexcept nogil
    cdef void c_gl_begin_write(self) noexcept nogil
    cdef void c_gl_end_write(self) noexcept nogil