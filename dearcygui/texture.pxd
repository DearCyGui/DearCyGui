from libc.stdint cimport int32_t
from .core cimport baseItem, Context
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
    cdef int32_t _repeat_mode
    cdef bint _readonly
    cdef bint _no_realloc
    cdef void set_content(self, content)
    cdef void c_gl_begin_read(self) noexcept nogil
    cdef void c_gl_end_read(self) noexcept nogil
    cdef void c_gl_begin_write(self) noexcept nogil
    cdef void c_gl_end_write(self) noexcept nogil


cdef class Pattern(baseItem):
    cdef Texture _texture
    cdef int32_t _x_mode  # 0 = points, 1 = length
    cdef float _scale_factor
    cdef bint _screen_space

cdef inline float get_pattern_u(Context context,
                                Pattern pattern,
                                int32_t point_index,
                                float length) noexcept nogil:
    """
    Computes the sampling x position of a pattern,
    given the current path length
    """
    if pattern._x_mode == 0:
        return <float>point_index * pattern._scale_factor
    else: # 1
        if pattern._screen_space:
            return length * pattern._scale_factor
        else:
            return length * (pattern._scale_factor * (context.viewport.global_scale / context.viewport.size_multiplier))
