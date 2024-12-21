from .core cimport baseItem, uiItem, drawingItem, itemState, \
    baseHandler, Texture, SharedValue
from .c_types cimport Vec2, Vec4

from libcpp.string cimport string
from libcpp.vector cimport vector

cimport numpy as cnp

cdef class DrawInvisibleButton(drawingItem):
    cdef itemState state
    cdef int _button # imgui.ImGuiButtonFlags
    cdef float _min_side
    cdef float _max_side
    cdef bint _no_input
    cdef bint _capture_mouse
    cdef double[2] _p1
    cdef double[2] _p2
    cdef Vec2 _initial_mouse_position

cdef class DrawInWindow(uiItem):
    cdef bint draw_item(self) noexcept nogil

cdef class SimplePlot(uiItem):
    cdef string _overlay
    cdef float _scale_min
    cdef float _scale_max
    cdef bint _histogram
    cdef bint _autoscale
    cdef int _last_frame_autoscale_update
    cdef bint draw_item(self) noexcept nogil


cdef class Button(uiItem):
    cdef int _direction # imgui.ImGuiDir
    cdef bint _small
    cdef bint _arrow
    cdef bint _repeat
    cdef bint draw_item(self) noexcept nogil


cdef class Combo(uiItem):
    cdef int _flags # imgui.ImGuiComboFlags
    cdef vector[string] _items
    cdef string _disabled_value
    cdef bint draw_item(self) noexcept nogil


cdef class Checkbox(uiItem):
    cdef bint draw_item(self) noexcept nogil


cdef class Slider(uiItem):
    cdef int _size
    cdef int _format
    cdef bint _drag
    cdef float _drag_speed
    cdef double _min
    cdef double _max
    cdef string _print_format
    cdef bint _vertical
    cdef int _flags # imgui.ImGuiSliderFlags
    cdef bint draw_item(self) noexcept nogil


cdef class ListBox(uiItem):
    cdef vector[string] _items
    cdef int _num_items_shown_when_open
    cdef bint draw_item(self) noexcept nogil


cdef class RadioButton(uiItem):
    cdef vector[string] _items
    cdef bint _horizontal
    cdef bint draw_item(self) noexcept nogil


cdef class InputText(uiItem):
    cdef string _hint
    cdef bint _multiline
    cdef int _max_characters
    cdef char* _buffer
    cdef int _last_frame_update
    cdef int _flags # imgui.ImGuiInputTextFlags
    cdef bint draw_item(self) noexcept nogil


cdef class InputValue(uiItem):
    cdef int _size
    cdef int _format
    cdef double _step
    cdef double _step_fast
    cdef double _min
    cdef double _max
    cdef string _print_format
    cdef int _flags # imgui.ImGuiInputTextFlags
    cdef bint draw_item(self) noexcept nogil


cdef class Text(uiItem):
    cdef unsigned int _color # imgui.ImU32
    cdef int _wrap
    cdef bint _bullet
    cdef bint _show_label
    cdef bint draw_item(self) noexcept nogil

cdef class TextValue(uiItem):
    cdef string _print_format
    cdef int _type
    cdef bint draw_item(self) noexcept nogil

cdef class Selectable(uiItem):
    cdef int _flags # imgui.ImGuiSelectableFlags
    cdef bint draw_item(self) noexcept nogil

cdef class MenuItem(uiItem):
    cdef string _shortcut
    cdef bint _check
    cdef bint draw_item(self) noexcept nogil


cdef class ProgressBar(uiItem):
    cdef string _overlay
    cdef bint draw_item(self) noexcept nogil


cdef class Image(uiItem):
    cdef float[4] _uv
    cdef unsigned int _color_multiplier # imgui.ImU32
    cdef unsigned int _border_color # imgui.ImU32
    cdef Texture _texture
    cdef bint draw_item(self) noexcept nogil


cdef class ImageButton(uiItem):
    cdef float[4] _uv
    cdef unsigned int _color_multiplier # imgui.ImU32
    cdef unsigned int _background_color # imgui.ImU32
    cdef Texture _texture
    cdef int _frame_padding
    cdef bint draw_item(self) noexcept nogil

cdef class Separator(uiItem):
    cdef bint draw_item(self) noexcept nogil

cdef class Spacer(uiItem):
    cdef bint draw_item(self) noexcept nogil

cdef class MenuBar(uiItem):
    cdef void draw(self) noexcept nogil

cdef class Menu(uiItem):
    cdef bint draw_item(self) noexcept nogil

cdef class Tooltip(uiItem):
    cdef float _delay
    cdef bint _hide_on_activity
    cdef bint _only_if_previous_item_hovered
    cdef bint _only_if_
    cdef baseItem _target
    cdef baseHandler _secondary_handler
    cdef bint draw_item(self) noexcept nogil

cdef class TabButton(uiItem):
    cdef int _flags # imgui.ImGuiTabBarFlags
    cdef bint draw_item(self) noexcept nogil

cdef class Tab(uiItem):
    cdef bint _closable
    cdef int _flags # imgui.ImGuiTabItemFlags

cdef class TabBar(uiItem):
    cdef int _flags # imgui.ImGuiTabBarFlags

cdef class TreeNode(uiItem):
    cdef int _flags # imgui.ImGuiTreeNodeFlags
    cdef bint _selectable
    cdef bint draw_item(self) noexcept nogil

cdef class CollapsingHeader(uiItem):
    cdef int _flags # imgui.ImGuiTreeNodeFlags
    cdef bint _closable
    cdef bint draw_item(self) noexcept nogil

cdef class ChildWindow(uiItem):
    cdef int _window_flags # imgui.ImGuiWindowFlags
    cdef int _child_flags # imgui.ImGuiChildFlags
    cdef bint draw_item(self) noexcept nogil

cdef class ColorButton(uiItem):
    cdef int _flags # imgui.ImGuiColorEditFlags
    cdef bint draw_item(self) noexcept nogil

cdef class ColorEdit(uiItem):
    cdef int _flags # imgui.ImGuiColorEditFlags
    cdef bint draw_item(self) noexcept nogil

cdef class ColorPicker(uiItem):
    cdef int _flags # imgui.ImGuiColorEditFlags
    cdef bint draw_item(self) noexcept nogil

cdef class SharedBool(SharedValue):
    cdef bint _value
    # Internal functions.
    # python uses get_value and set_value
    cdef bint get(self) noexcept nogil
    cdef void set(self, bint) noexcept nogil

cdef class SharedFloat(SharedValue):
    cdef float _value
    cdef float get(self) noexcept nogil
    cdef void set(self, float) noexcept nogil

cdef class SharedInt(SharedValue):
    cdef int _value
    cdef int get(self) noexcept nogil
    cdef void set(self, int) noexcept nogil

cdef class SharedColor(SharedValue):
    cdef unsigned int _value # imgui.ImU32
    cdef Vec4 _value_asfloat4 # imgui.ImVec4
    cdef unsigned int getU32(self) noexcept nogil # imgui.ImU32
    cdef Vec4 getF4(self) noexcept nogil # imgui.ImVec4
    cdef void setU32(self, unsigned int) noexcept nogil # imgui.ImU32
    cdef void setF4(self, Vec4) noexcept nogil # imgui.ImVec4

cdef class SharedDouble(SharedValue):
    cdef double _value
    cdef double get(self) noexcept nogil
    cdef void set(self, double) noexcept nogil

cdef class SharedStr(SharedValue):
    cdef string _value
    cdef void get(self, string&) noexcept nogil
    cdef void set(self, string) noexcept nogil

cdef class SharedFloat4(SharedValue):
    cdef float[4] _value
    cdef void get(self, float *) noexcept nogil# cython does support float[4] as return value
    cdef void set(self, float[4]) noexcept nogil

cdef class SharedInt4(SharedValue):
    cdef int[4] _value
    cdef void get(self, int *) noexcept nogil
    cdef void set(self, int[4]) noexcept nogil

cdef class SharedDouble4(SharedValue):
    cdef double[4] _value
    cdef void get(self, double *) noexcept nogil
    cdef void set(self, double[4]) noexcept nogil

cdef class SharedFloatVect(SharedValue):
    cdef cnp.ndarray _value_np
    cdef float[:] _value
    cdef float[:] get(self) noexcept nogil
    cdef void set(self, float[:]) noexcept nogil
"""
cdef class SharedDoubleVect:
    cdef double[:] _value
    cdef double[:] get(self) noexcept nogil
    cdef void set(self, double[:]) noexcept nogil


cdef class SharedTime:
    cdef tm _value
    cdef tm get(self) noexcept nogil
    cdef void set(self, tm) noexcept nogil
"""

cdef class TableColumnConfig(baseItem):
    cdef itemState state
    cdef int _flags # ImGuiTableColumnFlags_
    cdef bint _stretch
    cdef bint _fixed
    cdef float _width
    cdef float _stretch_weight
    cdef bint _dpi_scaling
    cdef int _bg_color # imgui.U32