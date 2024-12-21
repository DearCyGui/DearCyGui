from libcpp.unordered_map cimport unordered_map
from .core cimport *
from .types cimport *

cdef class baseThemeColor(baseTheme):
    cdef list _names
    cdef unordered_map[int, unsigned int] _index_to_value
    cdef object __common_getter(self, int)
    cdef void __common_setter(self, int, object)

cdef class ThemeColorImGui(baseThemeColor):
    cdef void push(self) noexcept nogil
    cdef void push_to_list(self, vector[theme_action]&) noexcept nogil
    cdef void pop(self) noexcept nogil

cdef class ThemeColorImPlot(baseThemeColor):
    cdef void push(self) noexcept nogil
    cdef void push_to_list(self, vector[theme_action]&) noexcept nogil
    cdef void pop(self) noexcept nogil

'''
cdef class ThemeColorImNodes(baseThemeColor):
    cdef void push(self) noexcept nogil
    cdef void push_to_list(self, vector[theme_action]&) noexcept nogil
    cdef void pop(self) noexcept nogil
'''

ctypedef struct theme_value_info:
    theme_value value
    theme_value_types value_type
    theme_value_float2_mask float2_mask
    bint should_round
    bint should_scale

cdef class baseThemeStyle(baseTheme):
    cdef list _names
    cdef theme_backends _backend
    cdef unordered_map[int, theme_value_info] _index_to_value
    cdef unordered_map[int, theme_value_info] _index_to_value_for_dpi
    cdef float _dpi
    cdef bint _dpi_scaling
    cdef bint _round_after_scale
    cdef object __common_getter(self, int, theme_value_types)
    cdef void __common_setter(self, int, theme_value_types, bint, bint, py_value)
    cdef void __compute_for_dpi(self) noexcept nogil
    cdef void push_to_list(self, vector[theme_action]&) noexcept nogil
    cdef void push(self) noexcept nogil
    cdef void pop(self) noexcept nogil

cdef class ThemeStyleImGui(baseThemeStyle):
    pass

cdef class ThemeStyleImPlot(baseThemeStyle):
    pass

cdef class ThemeStyleImNodes(baseThemeStyle):
    pass

cdef class ThemeList(baseTheme):
    cdef void push(self) noexcept nogil
    cdef void push_to_list(self, vector[theme_action]&) noexcept nogil
    cdef void pop(self) noexcept nogil

cdef class ThemeListWithCondition(baseTheme):
    cdef ThemeEnablers _activation_condition_enabled
    cdef ThemeCategories _activation_condition_category
    cdef void push(self) noexcept nogil
    cdef void pop(self) noexcept nogil
    cdef void push_to_list(self, vector[theme_action]& v) noexcept nogil

cdef class ThemeStopCondition(baseTheme):
    cdef vector[int] _start_pending_theme_actions_backup
    cdef void push(self) noexcept nogil
    cdef void pop(self) noexcept nogil
    cdef void push_to_list(self, vector[theme_action]& v) noexcept nogil
