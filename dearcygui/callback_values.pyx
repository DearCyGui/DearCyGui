from libc.stdint cimport int32_t, int64_t

from .core cimport Context, baseCallbackValue
from .c_types cimport DCGString, DCGVector
from .types cimport make_Key, MouseButton, Coord, make_MouseButton

cdef class uiItemCallbackValue(baseCallbackValue):
    """Callback value for a UI item."""
    def __init__(self, Context context, object value):
        self._value = value
        baseCallbackValue.__init__(self, context)

    @property
    def value(self):
        """Value of the UI item when the callback was triggered."""
        return self._value

# Those are empty but differ in the stubs (value type)

cdef class uiItemCallbackBoolValue(uiItemCallbackValue):
    """Callback value for a UI item with a boolean value."""
    pass

cdef class uiItemCallbackFloatValue(uiItemCallbackValue):
    """Callback value for a UI item with a float value."""
    pass

cdef class uiItemCallbackNoneValue(uiItemCallbackValue):
    """Callback value for a UI item with no value."""
    pass

cdef class uiItemCallbackStringValue(uiItemCallbackValue):
    """Callback value for a UI item with a string value."""
    pass

# subtypes for misc callback values

cdef class TimeWatcherCallbackValue(baseCallbackValue):
    """Callback value for a time watcher event."""

    def __init__(
        self,
        Context context,
        int64_t time_start,
        int64_t time_end,
        int64_t viewport_last_t_before_rendering,
        int64_t viewport_frame_count
    ):
        self._time_start = time_start
        self._time_end = time_end
        self._viewport_last_t_before_rendering = viewport_last_t_before_rendering
        self._viewport_frame_count = viewport_frame_count
        baseCallbackValue.__init__(self, context)

    @property
    def time_start(self):
        """Time the TimeWatcher is called for rendering (in nanoseconds)."""
        return self._time_start

    @property
    def time_end(self):
        """Time after the TimeWatcher children have finished rendering (in nanoseconds)."""
        return self._time_end

    @property
    def viewport_last_t_before_rendering(self):
        """Last time before rendering in the viewport (in nanoseconds).
        
        It corresponds to the time when viewport
        started rendering items for this frame. It is
        given to prevent the user from having to keep track of the
        viewport metrics (since the callback might be called
        after or before the viewport updated its metrics for this
        frame or another one).
        """
        return self._viewport_last_t_before_rendering

    @property
    def viewport_frame_count(self):
        """Frame count of the viewport."""
        return self._viewport_frame_count

cdef class ViewportCloseCallbackValue(baseCallbackValue):
    """Callback value for a viewport close event."""
    pass

cdef class ViewportResizeCallbackValue(baseCallbackValue):
    """Callback value for a viewport resize event."""

    def __init__(
        self,
        Context context,
        int64_t frame_width,
        int64_t frame_height,
        int64_t window_width,
        int64_t window_height
    ):
        self._frame_width = frame_width
        self._frame_height = frame_height
        self._window_width = window_width
        self._window_height = window_height
        baseCallbackValue.__init__(self, context)

    @property
    def frame_width(self):
        """Width of the viewport in actual pixels."""
        return self._frame_width

    @property
    def frame_height(self):
        """Height of the viewport in actual pixels."""
        return self._frame_height

    @property
    def window_width(self):
        """DPI invariant width of the viewport."""
        return self._window_width

    @property
    def window_height(self):
        """DPI invariant height of the viewport."""
        return self._window_height

cdef class WindowCloseCallbackValue(baseCallbackValue):
    """Callback value for a window close event."""
    pass

# subtypes for handler callback values

cdef class HandlerCallbackValue(baseCallbackValue):
    """Base class for all handler callback values."""
    pass

cdef class KeyHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for a handler with a key value."""

    def __init__(self, Context context, int32_t key):
        self._key = key
        HandlerCallbackValue.__init__(self, context)

    @property
    def key(self):
        """Key associated with the callback."""
        return self._key

cdef class MultiKeyHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for a handler with multiple key values."""
    cdef DCGVector[int32_t] _keys

    def __init__(self, Context context, keys):
        self._keys.clear()
        for key in keys:
            if not isinstance(key, int):
                raise TypeError("All elements in keys must be of type int")
            self._keys.push_back(<int32_t>key)
        HandlerCallbackValue.__init__(self, context)

    @property
    def keys(self):
        """Keys associated with the callback."""
        cdef int i
        cdef list keys = []
        for i in range(<int>self._keys.size()):
            try:
                keys.append(make_Key(self._keys[i]))
            except Exception: # key not found or invalid
                pass
        return tuple(keys)

cdef class MouseButtonHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for a handler with a mouse button value."""

    def __init__(self, Context context, button):
        if not isinstance(button, MouseButton):
            raise TypeError("button must be of type MouseButton")
        self._button = button
        HandlerCallbackValue.__init__(self, context)

    @property
    def button(self):
        """Mouse button associated with the callback."""
        return make_MouseButton(self._button)

cdef class MultiMouseButtonHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for a handler with multiple mouse button values."""
    def __init__(self, Context context, buttons):
        self._buttons.clear()
        for button in buttons:
            if not isinstance(button, MouseButton):
                raise TypeError("All elements in buttons must be of type MouseButton")
            self._buttons.push_back(<int32_t>button)
        HandlerCallbackValue.__init__(self, context)

    @property
    def buttons(self):
        """Mouse buttons associated with the callback."""
        cdef int i
        cdef list buttons = []
        for i in range(<int>self._buttons.size()):
            try:
                buttons.append(make_MouseButton(self._buttons[i]))
            except Exception: # button not found or invalid
                pass
        return tuple(buttons)

# Specific callback types for each handlers

cdef class CustomHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the CustomHandler."""
    pass

cdef class HandlerListCallbackValue(HandlerCallbackValue):
    """Callback value for the HandlerList."""
    pass

cdef class ConditionalHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the ConditionalHandler."""
    pass

cdef class OtherItemHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the OtherItemHandler."""
    pass

cdef class BoolHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the BoolHandler."""
    pass

cdef class ActivatedHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the ActivatedHandler."""
    pass

cdef class ActiveHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the ActiveHandler."""
    pass

cdef class ClickedHandlerCallbackValue(MouseButtonHandlerCallbackValue):
    """Callback value for the ClickedHandler."""
    pass

cdef class DoubleClickedHandlerCallbackValue(MouseButtonHandlerCallbackValue):
    """Callback value for the DoubleClickedHandler."""
    pass

cdef class DeactivatedHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the DeactivatedHandler."""
    pass

cdef class DeactivatedAfterEditHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the DeactivatedAfterEditHandler."""
    pass

cdef class DraggedHandlerCallbackValue(MouseButtonHandlerCallbackValue):
    """Callback value for the DraggedHandler."""

    def __init__(self, Context context, MouseButton button, drag_delta):
        if isinstance(drag_delta, Coord):
            self._drag_delta_x = getattr(drag_delta, "x")
            self._drag_delta_y = getattr(drag_delta, "y")
        else:
            raise TypeError("drag_delta must be of type Coord")
        MouseButtonHandlerCallbackValue.__init__(self, context, button)
    
    @property
    def drag_delta(self):
        """Delta between the position when dragging stopped and the initial position."""
        cdef double[2] delta
        delta[0] = self._drag_delta_x
        delta[1] = self._drag_delta_y
        return Coord.build(delta)

    @staticmethod
    cdef DraggedHandlerCallbackValue build(Context context, MouseButton button, float drag_delta_x, float drag_delta_y):
        cdef DraggedHandlerCallbackValue value = DraggedHandlerCallbackValue.__new__(DraggedHandlerCallbackValue)
        value._button = button
        value._drag_delta_x = drag_delta_x
        value._drag_delta_y = drag_delta_y
        return value

cdef class DraggingHandlerCallbackValue(MouseButtonHandlerCallbackValue):
    """Callback value for the DraggingHandler."""

    def __init__(self, Context context, MouseButton button, drag_delta):
        if isinstance(drag_delta, Coord):
            self._drag_delta_x = getattr(drag_delta, "x")
            self._drag_delta_y = getattr(drag_delta, "y")
        else:
            raise TypeError("drag_delta must be of type Coord")
        MouseButtonHandlerCallbackValue.__init__(self, context, button)

    @property
    def drag_delta(self):
        """Delta between the position when dragging stopped and the initial position."""
        cdef double[2] delta
        delta[0] = self._drag_delta_x
        delta[1] = self._drag_delta_y
        return Coord.build(delta)

    @staticmethod
    cdef DraggingHandlerCallbackValue build(Context context, MouseButton button, float drag_delta_x, float drag_delta_y):
        cdef DraggingHandlerCallbackValue value = DraggingHandlerCallbackValue.__new__(DraggingHandlerCallbackValue)
        value._button = button
        value._drag_delta_x = drag_delta_x
        value._drag_delta_y = drag_delta_y
        return value

cdef class EditedHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the EditedHandler."""
    pass

cdef class FocusedHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the FocusedHandler."""
    pass

cdef class GotFocusHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the GotFocusHandler."""
    pass

cdef class LostFocusHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the LostFocusHandler."""
    pass

cdef class MouseOverHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the MouseOverHandler."""
    pass

cdef class GotMouseOverHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the GotMouseOverHandler."""
    pass

cdef class LostMouseOverHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the LostMouseOverHandler."""
    pass

cdef class HoverHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the HoverHandler."""
    pass

cdef class GotHoverHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the GotHoverHandler."""
    pass

cdef class LostHoverHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the LostHoverHandler."""
    pass

cdef class MotionHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the MotionHandler."""
    pass

cdef class ContentResizeHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the ContentResizeHandler."""
    pass

cdef class ResizeHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the ResizeHandler."""
    pass

cdef class ToggledOpenHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the ToggledOpenHandler."""
    pass

cdef class ToggledCloseHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the ToggledCloseHandler."""
    pass

cdef class OpenHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the OpenHandler."""
    pass

cdef class CloseHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the CloseHandler."""
    pass

cdef class RenderHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the RenderHandler."""
    pass

cdef class GotRenderHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the GotRenderHandler."""
    pass

cdef class LostRenderHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the LostRenderHandler."""
    pass

cdef class MouseCursorHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the MouseCursorHandler."""
    pass

cdef class KeyDownHandlerCallbackValue(KeyHandlerCallbackValue):
    """Callback value for the KeyDownHandler."""

    def __init__(self, Context context, int32_t key, float duration):
        self._duration = duration
        KeyHandlerCallbackValue.__init__(self, context, key)

    @property
    def duration(self):
        """Duration for which the key has been held down."""
        return self._duration

    @staticmethod
    cdef KeyDownHandlerCallbackValue build(Context context, int32_t key, float duration):
        cdef KeyDownHandlerCallbackValue value = KeyDownHandlerCallbackValue.__new__(KeyDownHandlerCallbackValue)
        value._key = key
        value._duration = duration
        return value

cdef class KeyPressHandlerCallbackValue(KeyHandlerCallbackValue):
    """Callback value for the KeyPressHandler."""
    pass

cdef class KeyReleaseHandlerCallbackValue(KeyHandlerCallbackValue):
    """Callback value for the KeyReleaseHandler."""
    pass # TODO: cdef float _duration

cdef class AnyKeyPressHandlerCallbackValue(MultiKeyHandlerCallbackValue):
    """Callback value for the AnyKeyPressHandler."""
    @staticmethod
    cdef AnyKeyPressHandlerCallbackValue build(Context context, DCGVector[int32_t] &keys): 
        cdef AnyKeyPressHandlerCallbackValue value = AnyKeyPressHandlerCallbackValue.__new__(AnyKeyPressHandlerCallbackValue)
        value._keys = keys
        return value

cdef class AnyKeyReleaseHandlerCallbackValue(MultiKeyHandlerCallbackValue):
    """Callback value for the AnyKeyReleaseHandler."""
    @staticmethod
    cdef AnyKeyReleaseHandlerCallbackValue build(Context context, DCGVector[int32_t] &keys): 
        cdef AnyKeyReleaseHandlerCallbackValue value = AnyKeyReleaseHandlerCallbackValue.__new__(AnyKeyReleaseHandlerCallbackValue)
        value._keys = keys
        return value

cdef class AnyKeyDownHandlerCallbackValue(MultiKeyHandlerCallbackValue):
    """Callback value for the AnyKeyDownHandler."""

    def __init__(self, Context context, keys, durations):
        self._durations.clear()
        for duration in durations:
            self._durations.push_back(<float>duration)
        MultiKeyHandlerCallbackValue.__init__(self, context, keys)

        # Clamp if the numbers of items do not match
        if self._durations.size() < self._keys.size():
            self._keys.resize(self._durations.size())
        elif self._durations.size() > self._keys.size():
            self._durations.resize(self._keys.size())

    @property
    def durations(self):
        """Durations for which the keys have been held down."""
        cdef int i
        cdef list durations = []
        for i in range(<int>self._durations.size()):
            durations.append(self._durations[i])
        return tuple(durations)

    @staticmethod
    cdef AnyKeyDownHandlerCallbackValue build(Context context, DCGVector[int32_t] &keys, DCGVector[float] &durations):
        cdef AnyKeyDownHandlerCallbackValue value = AnyKeyDownHandlerCallbackValue.__new__(AnyKeyDownHandlerCallbackValue)
        value._keys = keys
        value._durations = durations
        return value

cdef class MouseClickHandlerCallbackValue(MouseButtonHandlerCallbackValue):
    """Callback value for the MouseClickHandler."""
    pass

cdef class MouseDoubleClickHandlerCallbackValue(MouseButtonHandlerCallbackValue):
    """Callback value for the MouseDoubleClickHandler."""
    pass

cdef class MouseDownHandlerCallbackValue(MouseButtonHandlerCallbackValue):
    """Callback value for the MouseDownHandler."""
    def __init__(self, Context context, MouseButton button, float duration):
        self._duration = duration
        MouseDownHandlerCallbackValue.__init__(self, context, button)

    @property
    def duration(self):
        """Duration for which the button has been held down."""
        return self._duration

    @staticmethod
    cdef MouseDownHandlerCallbackValue build(Context context, MouseButton button, float duration):
        cdef MouseDownHandlerCallbackValue value = MouseDownHandlerCallbackValue.__new__(MouseDownHandlerCallbackValue)
        value._button = button
        value._duration = duration
        return value

cdef class MouseDragHandlerCallbackValue(MouseButtonHandlerCallbackValue):
    """Callback value for the MouseDragHandler."""

    def __init__(self, Context context, MouseButton button, drag_delta):
        if isinstance(drag_delta, Coord):
            self._delta_x = getattr(drag_delta, "x")
            self._delta_y = getattr(drag_delta, "y")
        else:
            raise TypeError("drag_delta must be of type Coord")
        MouseButtonHandlerCallbackValue.__init__(self, context, button)

    @property
    def drag_delta(self):
        """Delta between the position when dragging stopped and the initial position."""
        cdef double[2] delta
        delta[0] = self._delta_x
        delta[1] = self._delta_y
        return Coord.build(delta)

    @staticmethod
    cdef MouseDragHandlerCallbackValue build(Context context, MouseButton button, float delta_x, float delta_y):
        cdef MouseDragHandlerCallbackValue value = MouseDragHandlerCallbackValue.__new__(MouseDragHandlerCallbackValue)
        value._button = button
        value._delta_x = delta_x
        value._delta_y = delta_y
        return value

cdef class MouseMoveHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the MouseMoveHandler."""

    def __init__(self, Context context, previous_position, current_position):
        if isinstance(previous_position, Coord) and isinstance(current_position, Coord):
            self._prev_x = getattr(previous_position, "x")
            self._prev_y = getattr(previous_position, "y")
            self._cur_x = getattr(current_position, "x")
            self._cur_y = getattr(current_position, "y")
        else:
            raise TypeError("previous_position and current_position must be of type Coord")
        HandlerCallbackValue.__init__(self, context)

    @property
    def previous_position(self):
        """Previous position of the mouse cursor."""
        cdef double[2] prev
        prev[0] = self._prev_x
        prev[1] = self._prev_y
        return Coord.build(prev)

    @property
    def current_position(self):
        """Current position of the mouse cursor (when the callback was queued)."""
        cdef double[2] cur
        cur[0] = self._cur_x
        cur[1] = self._cur_y
        return Coord.build(cur)

    @staticmethod
    cdef MouseMoveHandlerCallbackValue build(Context context, float cur_x, float cur_y, float prev_x, float prev_y):
        cdef MouseMoveHandlerCallbackValue value = MouseMoveHandlerCallbackValue.__new__(MouseMoveHandlerCallbackValue)
        value._cur_x = cur_x
        value._cur_y = cur_y
        value._prev_x = prev_x
        value._prev_y = prev_y
        return value

cdef class MouseReleaseHandlerCallbackValue(MouseButtonHandlerCallbackValue):
    """Callback value for the MouseReleaseHandler."""
    pass # TODO float _duration

cdef class MouseWheelHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the MouseWheelHandler."""

    def __init__(self, context, wheel_value):
        self._wheel_value = wheel_value
        HandlerCallbackValue.__init__(self, context)

    @property
    def wheel_value(self):
        """Value of the mouse wheel."""
        return self._wheel_value

    @staticmethod
    cdef MouseWheelHandlerCallbackValue build(Context context, float wheel_value):
        cdef MouseWheelHandlerCallbackValue value = MouseWheelHandlerCallbackValue.__new__(MouseWheelHandlerCallbackValue)
        value._wheel_value = wheel_value
        return value

cdef class MouseInRectHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the MouseInRectHandler."""

    def __init__(self, Context context, mouse_position):
        if not isinstance(mouse_position, Coord):
            raise TypeError("mouse_position must be an instance of Coord")
        self._mouse_x = getattr(mouse_position, "x")
        self._mouse_y = getattr(mouse_position, "y")
        HandlerCallbackValue.__init__(self, context)

    @property
    def mouse_position(self):
        """Current mouse position as a Coord object."""
        cdef double[2] coords
        coords[0] = self._mouse_x
        coords[1] = self._mouse_y
        return Coord.build(coords)

cdef class AnyMouseClickHandlerCallbackValue(MultiMouseButtonHandlerCallbackValue):
    """Callback value for the AnyMouseClickHandler."""
    pass

cdef class AnyMouseDoubleClickHandlerCallbackValue(MultiMouseButtonHandlerCallbackValue):
    """Callback value for the AnyMouseDoubleClickHandler."""
    pass

cdef class AnyMouseReleaseHandlerCallbackValue(MultiMouseButtonHandlerCallbackValue):
    """Callback value for the AnyMouseReleaseHandler."""
    pass # TODO DCGVector[float] _durations

cdef class AnyMouseDownHandlerCallbackValue(MultiMouseButtonHandlerCallbackValue):
    """Callback value for the AnyMouseDownHandler."""

    def __init__(self, Context context, buttons, durations):
        self._durations.clear()
        for duration in durations:
            self._durations.push_back(<float>duration)
        MultiMouseButtonHandlerCallbackValue.__init__(self, context, buttons)

        # Clamp if the numbers of items do not match
        if self._durations.size() < self._buttons.size():
            self._buttons.resize(self._durations.size())
        elif self._durations.size() > self._buttons.size():
            self._durations.resize(self._buttons.size())

    @property
    def durations(self):
        """Durations for which the keys have been held down."""
        cdef int i
        cdef list durations = []
        for i in range(<int>self._durations.size()):
            durations.append(self._durations[i])
        return tuple(durations)

    @staticmethod
    cdef AnyMouseDownHandlerCallbackValue build(Context context, DCGVector[int32_t] &buttons, DCGVector[float] &durations):
        cdef AnyMouseDownHandlerCallbackValue value = AnyMouseDownHandlerCallbackValue.__new__(AnyMouseDownHandlerCallbackValue)
        value._buttons = buttons
        value._durations = durations
        return value

cdef class DragDropSourceHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the DragDropSourceHandler."""
    def __init__(self, Context context, mouse_position, state_copy):
        if not isinstance(mouse_position, Coord):
            raise TypeError("mouse_position must be an instance of Coord")
        self._mouse_x = getattr(mouse_position, "x")
        self._mouse_y = getattr(mouse_position, "y")
        self._state_copy = state_copy
        HandlerCallbackValue.__init__(self, context)

    @property
    def mouse_position(self):
        """Current mouse position as a Coord object."""
        cdef double[2] coords
        coords[0] = self._mouse_x
        coords[1] = self._mouse_y
        return Coord.build(coords)


cdef class DragDropActiveHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the DragDropActiveHandler."""
    def __init__(self, Context context, payload_data, payload_type):
        self._payload_data = payload_data
        self._payload_type = payload_type
        HandlerCallbackValue.__init__(self, context)

    @property
    def payload_data(self):
        """Data associated with the drag-and-drop payload."""
        return self._payload_data

    @property
    def payload_type(self):
        """Type of the drag-and-drop payload."""
        return self._payload_type

cdef class DragDropTargetHandlerCallbackValue(HandlerCallbackValue):
    """Callback value for the DragDropTargetHandler."""
    def __init__(self, Context context, mouse_position, payload_data, payload_type, state_copy):
        if not isinstance(mouse_position, Coord):
            raise TypeError("mouse_position must be an instance of Coord")
        self._mouse_x = getattr(mouse_position, "x")
        self._mouse_y = getattr(mouse_position, "y")
        self._payload_data = payload_data
        self._payload_type = payload_type
        self._state_copy = state_copy
        HandlerCallbackValue.__init__(self, context)

    @property
    def mouse_position(self):
        """Current mouse position as a Coord object."""
        cdef double[2] coords
        coords[0] = self._mouse_x
        coords[1] = self._mouse_y
        return Coord.build(coords)

    @property
    def payload_data(self):
        """Data associated with the drag-and-drop payload."""
        return self._payload_data

    @property
    def payload_type(self):
        """Type of the drag-and-drop payload."""
        return self._payload_type

    @property
    def state_copy(self):
        """Copy of the item state at the time of the drag-and-drop event."""
        return self._state_copy