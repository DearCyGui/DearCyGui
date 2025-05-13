from libcpp.unordered_map cimport unordered_map
from .core cimport baseTheme

from libc.stdint cimport uint32_t, int32_t


cdef class baseThemeColor(baseTheme):
    cdef list _names
    # We use pointers to maintain a fixed structure size,
    # even if map implementation changes.
    # Do not use these fields as they may be implemented
    # with a different map implementation than your compiler.
    cdef unordered_map[int32_t, uint32_t] *_index_to_value
    cdef object _common_getter(self, int32_t)
    cdef void _common_setter(self, int32_t, object)

cdef class ThemeColorImGui(baseThemeColor):
    cdef void push(self) noexcept nogil
    cdef void pop(self) noexcept nogil

cdef class ThemeColorImPlot(baseThemeColor):
    cdef void push(self) noexcept nogil
    cdef void pop(self) noexcept nogil

cdef enum theme_value_float2_mask:
    t_full,
    t_left,
    t_right

cdef enum theme_value_types:
    t_int,
    t_float,
    t_float2,
    t_u32

ctypedef union theme_value:
    int32_t value_int
    float value_float
    float[2] value_float2
    uint32_t value_u32

ctypedef struct theme_value_info:
    theme_value value
    theme_value_types value_type
    theme_value_float2_mask float2_mask
    bint should_round
    bint should_scale

cdef class baseThemeStyle(baseTheme):
    cdef list _names
    # We use pointers to maintain a fixed structure size,
    # even if map implementation changes.
    # Do not use these fields as they may be implemented
    # with a different map implementation than your compiler.
    cdef unordered_map[int32_t, theme_value_info] *_index_to_value
    cdef unordered_map[int32_t, theme_value_info] *_index_to_value_for_dpi
    cdef float _dpi
    cdef bint _dpi_scaling
    cdef bint _round_after_scale
    cdef object _common_getter(self, int32_t, theme_value_types)
    cdef void _common_setter(self, int32_t, theme_value_types, bint, bint, py_value)
    cdef void _compute_for_dpi(self) noexcept nogil

cdef class ThemeStyleImGui(baseThemeStyle):
    cdef void push(self) noexcept nogil
    cdef void pop(self) noexcept nogil

cdef class ThemeStyleImPlot(baseThemeStyle):
    cdef void push(self) noexcept nogil
    cdef void pop(self) noexcept nogil

cdef class ThemeList(baseTheme):
    cdef void push(self) noexcept nogil
    cdef void pop(self) noexcept nogil

