from libc.stdint cimport uint32_t, int32_t

from .core cimport baseItem, uiItem, drawingItem, itemState, \
    baseHandler, SharedValue
from .c_types cimport Vec2, Vec4, DCGVector, DCGString
from .texture cimport Texture

cdef class DrawInvisibleButton(drawingItem):
    cdef itemState state
    cdef int32_t _button # imgui.ImGuiButtonFlags
    cdef float _min_side
    cdef float _max_side
    cdef bint _no_input
    cdef bint _capture_mouse
    cdef double[2] _p1
    cdef double[2] _p2
    cdef Vec2 _initial_mouse_position

cdef class DrawInWindow(uiItem):
    cdef bint has_frame
    cdef double orig_x
    cdef double orig_y
    cdef double scale_x
    cdef double scale_y
    cdef bint button
    cdef bint invert_y
    cdef bint relative_scaling
    cdef bint _no_global_scale
    cdef bint draw_item(self) noexcept nogil

cdef class SimplePlot(uiItem):
    cdef DCGString _overlay
    cdef float _scale_min
    cdef float _scale_max
    cdef bint _histogram
    cdef bint _autoscale
    cdef int32_t _last_frame_autoscale_update
    cdef bint draw_item(self) noexcept nogil


cdef class Button(uiItem):
    cdef int32_t _direction # imgui.ImGuiDir
    cdef bint _small
    cdef bint _arrow
    cdef bint _repeat
    cdef bint draw_item(self) noexcept nogil


cdef class Combo(uiItem):
    cdef int32_t _flags # imgui.ImGuiComboFlags
    cdef DCGVector[DCGString] _items
    cdef DCGString _disabled_value
    cdef bint draw_item(self) noexcept nogil


cdef class Checkbox(uiItem):
    cdef bint draw_item(self) noexcept nogil


cdef class Slider(uiItem):
    cdef bint _drag
    cdef float _drag_speed
    cdef double _min
    cdef double _max
    cdef DCGString _print_format
    cdef bint _vertical
    cdef int32_t _flags # imgui.ImGuiSliderFlags
    cdef bint draw_item(self) noexcept nogil


cdef class ListBox(uiItem):
    cdef DCGVector[DCGString] _items
    cdef int32_t _num_items_shown_when_open
    cdef bint draw_item(self) noexcept nogil


cdef class RadioButton(uiItem):
    cdef DCGVector[DCGString] _items
    cdef bint _horizontal
    cdef bint draw_item(self) noexcept nogil


cdef class InputText(uiItem):
    cdef DCGString _hint
    cdef bint _multiline
    cdef int32_t _max_characters
    cdef char* _buffer
    cdef int32_t _last_frame_update
    cdef int32_t _flags # imgui.ImGuiInputTextFlags
    cdef bint draw_item(self) noexcept nogil


cdef class InputValue(uiItem):
    cdef double _step
    cdef double _step_fast
    cdef double _min
    cdef double _max
    cdef DCGString _print_format
    cdef int32_t _flags # imgui.ImGuiInputTextFlags
    cdef bint draw_item(self) noexcept nogil


cdef class Text(uiItem):
    cdef uint32_t _color # imgui.ImU32
    cdef int32_t _wrap
    cdef int32_t _marker
    cdef bint draw_item(self) noexcept nogil

cdef class TextValue(uiItem):
    cdef DCGString _print_format
    cdef int32_t _type
    cdef bint draw_item(self) noexcept nogil

cdef class Selectable(uiItem):
    cdef int32_t _flags # imgui.ImGuiSelectableFlags
    cdef bint draw_item(self) noexcept nogil

cdef class MenuItem(uiItem):
    cdef DCGString _shortcut
    cdef bint _check
    cdef bint draw_item(self) noexcept nogil


cdef class ProgressBar(uiItem):
    cdef DCGString _overlay
    cdef bint draw_item(self) noexcept nogil


cdef class Image(uiItem):
    cdef float[4] _uv
    cdef uint32_t _color_multiplier # imgui.ImU32
    cdef uint32_t _background_color # imgui.ImU32
    cdef bint _button
    cdef Texture _texture
    cdef bint _no_global_scale
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
    cdef baseItem _target
    cdef baseHandler _secondary_handler
    cdef bint draw_item(self) noexcept nogil

cdef class TabButton(uiItem):
    cdef int32_t _flags # imgui.ImGuiTabBarFlags
    cdef bint draw_item(self) noexcept nogil

cdef class Tab(uiItem):
    cdef bint _closable
    cdef int32_t _flags # imgui.ImGuiTabItemFlags

cdef class TabBar(uiItem):
    cdef int32_t _flags # imgui.ImGuiTabBarFlags

cdef class TreeNode(uiItem):
    cdef int32_t _flags # imgui.ImGuiTreeNodeFlags
    cdef bint _selectable
    cdef bint draw_item(self) noexcept nogil

cdef class CollapsingHeader(uiItem):
    cdef int32_t _flags # imgui.ImGuiTreeNodeFlags
    cdef bint _closable
    cdef bint draw_item(self) noexcept nogil

cdef class ChildWindow(uiItem):
    cdef int32_t _window_flags # imgui.ImGuiWindowFlags
    cdef int32_t _child_flags # imgui.ImGuiChildFlags
    cdef bint draw_item(self) noexcept nogil

cdef class ColorButton(uiItem):
    cdef int32_t _flags # imgui.ImGuiColorEditFlags
    cdef bint draw_item(self) noexcept nogil

cdef class ColorEdit(uiItem):
    cdef int32_t _flags # imgui.ImGuiColorEditFlags
    cdef bint draw_item(self) noexcept nogil

cdef class ColorPicker(uiItem):
    cdef int32_t _flags # imgui.ImGuiColorEditFlags
    cdef bint draw_item(self) noexcept nogil

cdef class SharedBool(SharedValue):
    cdef bint _value
    # Internal functions.
    # python uses get_value and set_value
    cdef bint get(self) noexcept nogil
    cdef void set(self, bint) noexcept nogil

cdef class SharedFloat(SharedValue):
    cdef double _value
    cdef double get(self) noexcept nogil
    cdef void set(self, double) noexcept nogil

cdef class SharedColor(SharedValue):
    cdef uint32_t _value # imgui.ImU32
    cdef Vec4 _value_asfloat4 # imgui.ImVec4
    cdef uint32_t getU32(self) noexcept nogil # imgui.ImU32
    cdef Vec4 getF4(self) noexcept nogil # imgui.ImVec4
    cdef void setU32(self, uint32_t) noexcept nogil # imgui.ImU32
    cdef void setF4(self, Vec4) noexcept nogil # imgui.ImVec4

cdef class SharedStr(SharedValue):
    cdef DCGString _value
    cdef void get(self, DCGString&) noexcept nogil
    cdef void set(self, DCGString) noexcept nogil

cdef class SharedFloatVect(SharedValue):
    cdef float[::1] _value
    cdef float[::1] get(self) noexcept nogil
    cdef void set(self, float[::1]) noexcept nogil
"""

cdef class SharedTime:
    cdef tm _value
    cdef tm get(self) noexcept nogil
    cdef void set(self, tm) noexcept nogil
"""
