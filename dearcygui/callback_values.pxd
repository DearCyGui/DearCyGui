from libc.stdint cimport int32_t, int64_t
from .c_types cimport DCGString, DCGVector
from .core cimport Context, baseCallbackValue
from .types cimport MouseButton

cdef class uiItemCallbackValue(baseCallbackValue):
    cdef object _value

cdef class uiItemCallbackBoolValue(uiItemCallbackValue):
    pass

cdef class uiItemCallbackFloatValue(uiItemCallbackValue):
    pass

cdef class uiItemCallbackNoneValue(uiItemCallbackValue):
    pass

cdef class uiItemCallbackStringValue(uiItemCallbackValue):
    pass

cdef class HandlerCallbackValue(baseCallbackValue):
    pass

cdef class KeyHandlerCallbackValue(HandlerCallbackValue):
    cdef int32_t _key

cdef class MultiKeyHandlerCallbackValue(HandlerCallbackValue):
    cdef DCGVector[int32_t] _keys

cdef class MouseButtonHandlerCallbackValue(HandlerCallbackValue):
    cdef MouseButton _button

cdef class MultiMouseButtonHandlerCallbackValue(HandlerCallbackValue):
    cdef DCGVector[int32_t] _buttons

# subtypes for misc callback values

cdef class TimeWatcherCallbackValue(baseCallbackValue):
    cdef int64_t _time_start
    cdef int64_t _time_end
    cdef int64_t _viewport_last_t_before_rendering
    cdef int64_t _viewport_frame_count

cdef class ViewportCloseCallbackValue(baseCallbackValue):
    pass

cdef class ViewportResizeCallbackValue(baseCallbackValue):
    cdef int64_t _frame_width
    cdef int64_t _frame_height
    cdef int64_t _window_width
    cdef int64_t _window_height

cdef class WindowCloseCallbackValue(baseCallbackValue):
    pass

# Specific callback types for each handlers

cdef class CustomHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class HandlerListCallbackValue(HandlerCallbackValue):
    pass

cdef class ConditionalHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class OtherItemHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class BoolHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class ActivatedHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class ActiveHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class ClickedHandlerCallbackValue(MouseButtonHandlerCallbackValue):
    pass

cdef class DoubleClickedHandlerCallbackValue(MouseButtonHandlerCallbackValue):
    pass

cdef class DeactivatedHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class DeactivatedAfterEditHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class DraggedHandlerCallbackValue(MouseButtonHandlerCallbackValue):
    cdef float _drag_delta_x
    cdef float _drag_delta_y
    @staticmethod
    cdef DraggedHandlerCallbackValue build(Context context, MouseButton _button, float drag_delta_x, float drag_delta_y)

cdef class DraggingHandlerCallbackValue(MouseButtonHandlerCallbackValue):
    cdef float _drag_delta_x
    cdef float _drag_delta_y
    @staticmethod
    cdef DraggingHandlerCallbackValue build(Context context, MouseButton _button, float drag_delta_x, float drag_delta_y)

cdef class EditedHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class FocusedHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class GotFocusHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class LostFocusHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class MouseOverHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class GotMouseOverHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class LostMouseOverHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class HoverHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class GotHoverHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class LostHoverHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class MotionHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class ContentResizeHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class ResizeHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class ToggledOpenHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class ToggledCloseHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class OpenHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class CloseHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class RenderHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class GotRenderHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class LostRenderHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class MouseCursorHandlerCallbackValue(HandlerCallbackValue):
    pass

cdef class KeyDownHandlerCallbackValue(KeyHandlerCallbackValue):
    cdef float _duration
    @staticmethod
    cdef KeyDownHandlerCallbackValue build(Context context, int32_t key, float duration)

cdef class KeyPressHandlerCallbackValue(KeyHandlerCallbackValue):
    pass

cdef class KeyReleaseHandlerCallbackValue(KeyHandlerCallbackValue):
    pass # TODO: cdef float _duration

cdef class AnyKeyPressHandlerCallbackValue(MultiKeyHandlerCallbackValue):
    @staticmethod
    cdef AnyKeyPressHandlerCallbackValue build(Context context, DCGVector[int32_t] &keys)

cdef class AnyKeyReleaseHandlerCallbackValue(MultiKeyHandlerCallbackValue):
    @staticmethod
    cdef AnyKeyReleaseHandlerCallbackValue build(Context context, DCGVector[int32_t] &keys)

cdef class AnyKeyDownHandlerCallbackValue(MultiKeyHandlerCallbackValue):
    cdef DCGVector[float] _durations
    @staticmethod
    cdef AnyKeyDownHandlerCallbackValue build(Context context, DCGVector[int32_t] &keys, DCGVector[float] &durations)

cdef class MouseClickHandlerCallbackValue(MouseButtonHandlerCallbackValue):
    pass

cdef class MouseDoubleClickHandlerCallbackValue(MouseButtonHandlerCallbackValue):
    pass

cdef class MouseDownHandlerCallbackValue(MouseButtonHandlerCallbackValue):
    cdef float _duration
    @staticmethod
    cdef MouseDownHandlerCallbackValue build(Context context, MouseButton _button, float duration)

cdef class MouseDragHandlerCallbackValue(MouseButtonHandlerCallbackValue):
    cdef float _delta_x
    cdef float _delta_y
    @staticmethod
    cdef MouseDragHandlerCallbackValue build(Context context, MouseButton _button, float delta_x, float delta_y)

cdef class MouseMoveHandlerCallbackValue(HandlerCallbackValue):
    cdef float _cur_x
    cdef float _cur_y
    cdef float _prev_x
    cdef float _prev_y
    @staticmethod
    cdef MouseMoveHandlerCallbackValue build(Context context, float cur_x, float cur_y, float prev_x, float prev_y)

cdef class MouseReleaseHandlerCallbackValue(MouseButtonHandlerCallbackValue):
    pass # TODO float _duration

cdef class MouseWheelHandlerCallbackValue(HandlerCallbackValue):
    cdef float _wheel_value
    @staticmethod
    cdef MouseWheelHandlerCallbackValue build(Context context, float wheel_value)

cdef class MouseInRectHandlerCallbackValue(HandlerCallbackValue):
    cdef float _mouse_x
    cdef float _mouse_y

cdef class AxesResizeHandlerCallbackValue(HandlerCallbackValue):
    cdef double _x_min
    cdef double _x_max
    cdef double _x_scale
    cdef double _y_min
    cdef double _y_max
    cdef double _y_scale

cdef class AnyMouseClickHandlerCallbackValue(MultiMouseButtonHandlerCallbackValue):
    pass

cdef class AnyMouseDoubleClickHandlerCallbackValue(MultiMouseButtonHandlerCallbackValue):
    pass

cdef class AnyMouseReleaseHandlerCallbackValue(MultiMouseButtonHandlerCallbackValue):
    pass # TODO DCGVector[float] _durations

cdef class AnyMouseDownHandlerCallbackValue(MultiMouseButtonHandlerCallbackValue):
    cdef DCGVector[float] _durations
    @staticmethod
    cdef AnyMouseDownHandlerCallbackValue build(Context context, DCGVector[int32_t] &buttons, DCGVector[float] &durations)

cdef class DragDropSourceHandlerCallbackValue(HandlerCallbackValue):
    cdef float _mouse_x
    cdef float _mouse_y
    cdef object _state_copy

cdef class DragDropActiveHandlerCallbackValue(HandlerCallbackValue):
    cdef object _payload_data
    cdef str _payload_type

cdef class DragDropTargetHandlerCallbackValue(HandlerCallbackValue):
    cdef float _mouse_x
    cdef float _mouse_y
    cdef object _payload_data
    cdef str _payload_type
    cdef object _state_copy