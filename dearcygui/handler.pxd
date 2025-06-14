from libc.stdint cimport int32_t
from .core cimport baseHandler, baseItem
from .c_types cimport DCGVector
from .types cimport MouseButton, Positioning, HandlerListOP, MouseCursor
from .widget cimport SharedBool

cdef class CustomHandler(baseHandler):
    cdef bint _has_run
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class HandlerList(baseHandler):
    cdef HandlerListOP _op
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class ConditionalHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class OtherItemHandler(HandlerList):
    cdef baseItem _target
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class BoolHandler(baseHandler):
    cdef SharedBool _condition
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class ActivatedHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class ActiveHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class ClickedHandler(baseHandler):
    cdef MouseButton _button
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class DoubleClickedHandler(baseHandler):
    cdef MouseButton _button
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class DeactivatedHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class DeactivatedAfterEditHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class DraggedHandler(baseHandler):
    cdef MouseButton _button
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class DraggingHandler(baseHandler):
    cdef MouseButton _button
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class EditedHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class FocusHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class GotFocusHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class LostFocusHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class MouseOverHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class GotMouseOverHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class LostMouseOverHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class HoverHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class GotHoverHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class LostHoverHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class MotionHandler(baseHandler):
    cdef Positioning[2] _positioning
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class ContentResizeHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class ResizeHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class ToggledOpenHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class ToggledCloseHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class OpenHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class CloseHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class RenderHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class GotRenderHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class LostRenderHandler(baseHandler):
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil

cdef class MouseCursorHandler(baseHandler):
    cdef MouseCursor _mouse_cursor
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class KeyDownHandler(baseHandler):
    cdef int32_t _key
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class KeyPressHandler(baseHandler):
    cdef int32_t _key
    cdef bint _repeat
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class KeyReleaseHandler(baseHandler):
    cdef int32_t _key
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class AnyKeyPressHandler(baseHandler):
    cdef bint _repeat
    cdef DCGVector[int32_t] _keys_vector
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class AnyKeyReleaseHandler(baseHandler):
    cdef DCGVector[int32_t] _keys_vector
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class AnyKeyDownHandler(baseHandler):
    cdef DCGVector[int32_t] _keys_vector
    cdef DCGVector[float] _durations_vector
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class MouseClickHandler(baseHandler):
    cdef MouseButton _button
    cdef bint _repeat
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class MouseDoubleClickHandler(baseHandler):
    cdef MouseButton _button
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class MouseDownHandler(baseHandler):
    cdef MouseButton _button
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class MouseDragHandler(baseHandler):
    cdef MouseButton _button
    cdef float _threshold
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class MouseMoveHandler(baseHandler):
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class MouseInRect(baseHandler):
    cdef double _x1, _y1, _x2, _y2
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class MouseReleaseHandler(baseHandler):
    cdef MouseButton _button
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class MouseWheelHandler(baseHandler):
    cdef bint _horizontal
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class AnyMouseClickHandler(baseHandler):
    cdef bint _repeat
    cdef DCGVector[int32_t] _buttons_vector
    cdef bint check_state(self, baseItem item) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class AnyMouseDoubleClickHandler(baseHandler):
    cdef DCGVector[int32_t] _buttons_vector
    cdef bint check_state(self, baseItem item) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class AnyMouseReleaseHandler(baseHandler):
    cdef DCGVector[int32_t] _buttons_vector
    cdef bint check_state(self, baseItem item) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil

cdef class AnyMouseDownHandler(baseHandler):
    cdef DCGVector[int32_t] _buttons_vector
    cdef DCGVector[float] _durations_vector
    cdef bint check_state(self, baseItem item) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil