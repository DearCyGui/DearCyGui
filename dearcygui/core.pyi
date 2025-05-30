from typing import TypeAlias, Any
from enum import IntEnum
from collections.abc import Sequence
from typing import Protocol, TypeVar
from .types import *
from .core import *

Sender = TypeVar('Sender', baseHandler, uiItem, covariant=True)
Target = TypeVar('Target', baseItem, covariant=True)

class DCGCallable0(Protocol):
    def __call__(self, /) -> Any:
        ...

class DCGCallable1(Protocol):
    def __call__(self,
                 sender : Sender,
                 /) -> Any:
        ...

class DCGCallable2(Protocol):
    def __call__(self,
                 sender : Sender,
                 target : Target,
                 /) -> Any:
        ...

class DCGCallable3(Protocol):
    def __call__(self,
                 sender : Sender,
                 target : Target,
                 value : Any,
                 /) -> Any:
        ...

class DCGCallable0Kw(Protocol):    
    def __call__(self, /, **kwargs) -> Any:
        ...

class DCGCallable1Kw(Protocol):
    def __call__(self,
                 sender : Sender,
                 /,
                 **kwargs : Any) -> Any:
        ...

class DCGCallable2Kw(Protocol):
    def __call__(self,
                 sender : Sender,
                 target : Target,
                 /,
                 **kwargs : Any) -> Any:
        ...

class DCGCallable3Kw(Protocol):
    def __call__(self,
                 sender : Sender,
                 target : Target,
                 value : Any,
                 /,  
                 **kwargs : Any) -> Any:
        ...


DCGCallable = DCGCallable0 | DCGCallable1 | DCGCallable2 | DCGCallable3 | DCGCallable0Kw | DCGCallable1Kw | DCGCallable2Kw | DCGCallable3Kw

Color = int | tuple[int, int, int] | tuple[int, int, int, int] | tuple[float, float, float] | tuple[float, float, float, float] | Sequence[int] | Sequence[float]


class wrap_mutex:
    def __init__(self, target) -> None:
        ...
    
    def __enter__(self): # -> None:
        ...
    
    def __exit__(self, exc_type, exc_value, traceback): # -> Literal[False]:
        ...
    


class wrap_this_and_parents_mutex:
    def __init__(self, target) -> None:
        ...
    
    def __enter__(self): # -> None:
        ...
    
    def __exit__(self, exc_type, exc_value, traceback): # -> Literal[False]:
        ...

baseItemSubCls = TypeVar('baseItemSubCls', bound='baseItem')
drawingItemSubCls = TypeVar('drawingItemSubCls', bound='drawingItem')
plotElementSubCls = TypeVar('plotElementSubCls', bound='plotElement')
uiItemSubCls = TypeVar('uiItemSubCls', bound='uiItem')
baseHandlerSubCls = TypeVar('baseHandlerSubCls', bound='baseHandler')
baseThemeSubCls = TypeVar('baseThemeSubCls', bound='baseTheme')


ChildWindowSubCls = TypeVar('ChildWindowSubCls', bound='ChildWindow')
DrawInWindowSubCls = TypeVar('DrawInWindowSubCls', bound='DrawInWindow')
DrawInPlotSubCls = TypeVar('DrawInPlotSubCls', bound='DrawInPlot')
MenuBarSubCls = TypeVar('MenuBarSubCls', bound='MenuBar')
PlotSubCls = TypeVar('PlotSubCls', bound='Plot')
ViewportDrawListSubCls = TypeVar('ViewportDrawListSubCls', bound='ViewportDrawList')
WindowSubCls = TypeVar('WindowSubCls', bound='Window')

try:
    from collections.abc import Buffer
    Array: TypeAlias = memoryview | bytearray | bytes | Sequence[Any] | Buffer
except ImportError:
    Array: TypeAlias = memoryview | bytearray | bytes | Sequence[Any]
    pass
class ActivatedHandler(baseHandler):
    """
    Handler for when the target item turns from
    the non-active to the active state. For instance
    buttons turn active when the mouse is pressed on them.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class ActiveHandler(baseHandler):
    """
    Handler for when the target item is active.
    For instance buttons turn active when the mouse
    is pressed on them, and stop being active when
    the mouse is released.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class AnyKeyDownHandler(baseHandler):
    """
    Handler that triggers when any key is held down.

    This native implementation efficiently monitors all keys simultaneously
    without creating individual handlers for each key.

    Callback receives:
        - data: A tuple of tuples, each containing (Key, duration), where:
          - Key: The specific key being held down
          - duration: How long the key has been held (in seconds)

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class AnyKeyPressHandler(baseHandler):
    """
    Handler that triggers when any keyboard key is pressed.

    This handler monitors all keys simultaneously
    without creating individual handlers for each key.

    Properties:
        repeat (bool): Whether to trigger repeatedly while keys are held down

    Callback receives:
        - data: A tuple of Key objects that were pressed this frame

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, repeat : bool = False, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - repeat: Whether to trigger repeatedly while a key is held down.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


    @property
    def repeat(self) -> bool:
        """
        Whether to trigger repeatedly while a key is held down.

        When True, the callback will be called multiple times as keys remain pressed.
        When False, the callback is only called once when the key is initially pressed.

        """
        ...


    @repeat.setter
    def repeat(self, value : bool):
        ...


class AnyKeyReleaseHandler(baseHandler):
    """
    Handler that triggers when any key is released.

    This handler monitors all keys simultaneously
    without creating individual handlers for each key.

    Callback receives:
        - data: A tuple of Key objects that were released this frame

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class AnyMouseClickHandler(baseHandler):
    """
    Handler that triggers when any mouse button is clicked.

    This handler monitors all mouse buttons simultaneously
    without creating individual handlers for each button.

    Properties:
        repeat (bool): Whether to trigger repeatedly while buttons are held

    Callback receives:
        - data: A tuple of MouseButton objects that were clicked this frame

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, repeat : bool = False, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - repeat: Whether to trigger repeatedly while a button is held down.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


    @property
    def repeat(self) -> bool:
        """
        Whether to trigger repeatedly while a button is held down.

        When True, the callback will be called multiple times as buttons remain pressed.
        When False, the callback is only called once when the button is initially pressed.

        """
        ...


    @repeat.setter
    def repeat(self, value : bool):
        ...


class AnyMouseDoubleClickHandler(baseHandler):
    """
    Handler that triggers when any mouse button is double-clicked.

    This handler monitors all mouse buttons simultaneously
    without creating individual handlers for each button.

    Callback receives:
        - data: A tuple of MouseButton objects that were double-clicked this frame

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class AnyMouseDownHandler(baseHandler):
    """
    Handler that triggers when any mouse button is held down.

    This handler monitors all mouse buttons simultaneously
    without creating individual handlers for each button.

    Callback receives:
        - data: A tuple of tuples, each containing (MouseButton, duration), where:
          - MouseButton: The specific button being held down
          - duration: How long the button has been held (in seconds)

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class AnyMouseReleaseHandler(baseHandler):
    """
    Handler that triggers when any mouse button is released.

    This handler monitors all mouse buttons simultaneously
    without creating individual handlers for each button.

    Callback receives:
        - data: A tuple of MouseButton objects that were released this frame

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class AutoFont(FontMultiScales):
    """
    A self-managing font container that automatically creates and caches fonts at different scales.

    Automatically creates new font sizes when needed to match global_scale changes.

    Parameters
    ----------
    context : Context
        The context this font belongs to
    base_size : float = 17.0
        Base font size before scaling
    font_creator : callable = None
        Function to create fonts. Takes size as first argument and optional kwargs.
        The output should be a GlyphSet.
        If None, uses make_extended_latin_font.
    **kwargs :
        Additional arguments passed to font_creator

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = ..., children : Sequence[baseItemSubCls] = [], fonts : list = ..., next_sibling : baseItemSubCls | None = None, parent : baseItemSubCls | None = None, previous_sibling : baseItemSubCls | None = None, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Callbacks triggered when a new scale is encountered.
        - callbacks: Callbacks triggered when a new scale is encountered.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - fonts: List of attached fonts with different scales.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - user_data: User data of any type.
        """
        ...


    def _create_font_at_scale(self, scale, no_fail):
        """
Create a new font at the given scale
        """
        ...


    def _on_new_scale(self, sender, target, scale) -> None:
        """
Called when a new global scale is encountered
        """
        ...


class AxesResizeHandler(baseHandler):
    """
    Handler that detects changes in plot axes dimensions or view area.

    This handler monitors both the axes min/max values and the plot region size,
    triggering the callback whenever these dimensions change. This is useful for
    detecting when the scale of pixels within plot coordinates has changed, such
    as after zoom operations or window resizing.

    The data field passed to the callback contains:
    ((x_min, x_max, x_scale), (y_min, y_max, y_scale))

    Where:
    - x_min, x_max: Current axis limits
    - x_scale: Scaling factor (max-min)/pixels
    - First tuple is for X axis (default X1)
    - Second tuple is for Y axis (default Y1)

    """
    def __init__(self, context : Context, attach : Any = ..., axes : tuple = (0, 3), before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - axes: The (X axis, Y axis) pair monitored by this handler.
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


    @property
    def axes(self) -> tuple:
        """
        The (X axis, Y axis) pair monitored by this handler.

        Specifies which axes this handler should monitor for dimensional changes.
        Valid X axes are X1, X2, X3. Valid Y axes are Y1, Y2, Y3.
        Default is (X1, Y1).

        """
        ...


    @axes.setter
    def axes(self, value : tuple):
        ...


class AxisTag(baseItem):
    """
    Visual marker with text attached to a specific coordinate on a plot axis.

    Axis tags provide a way to highlight and label specific values on a plot axis.
    Tags appear as small markers with optional text labels and background colors.
    They can be used to mark thresholds, important values, or add explanatory
    annotations directly on the axes.

    Tags can only be attached as children to plot axes, and their position is
    specified as a coordinate value on that axis.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., bg_color : list = [0.0, 0.0, 0.0, 0.0], children : Sequence[baseItemSubCls] = [], coord : float = 0.0, next_sibling : baseItemSubCls | None = None, parent : baseItemSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, text : str = "", user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - bg_color: Background color of the tag as RGBA values.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - coord: Position of the tag along the parent axis.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Controls the visibility of the axis tag.
        - text: Text label displayed with the axis tag.
        - user_data: User data of any type.
        """
        ...


    @property
    def bg_color(self) -> list:
        """
        Background color of the tag as RGBA values.

        A value of 0 (default) means no background color will be applied, and
        ThemeStyleImPlot's AxisText will be used for the text color. When a background
        color is specified, the text color automatically adjusts to white or
        black for optimal contrast with the background.

        Color values are represented as a list of RGBA components in the [0,1]
        range.

        """
        ...


    @bg_color.setter
    def bg_color(self, value : list):
        ...


    @property
    def coord(self) -> float:
        """
        Position of the tag along the parent axis.

        Specifies the coordinate value where the tag should be placed on the
        parent axis. The coordinate is in the same units as the axis data
        (not in pixels or screen coordinates).

        """
        ...


    @coord.setter
    def coord(self, value : float):
        ...


    @property
    def show(self) -> bool:
        """
        Controls the visibility of the axis tag.

        When set to True, the tag is visible on the axis. When set to False,
        the tag is not rendered, though it remains in the object hierarchy.

        """
        ...


    @show.setter
    def show(self, value : bool):
        ...


    @property
    def text(self) -> str:
        """
        Text label displayed with the axis tag.

        The text is rendered alongside the tag marker. If no text is provided,
        only the marker itself will be shown. Formatting options such as color
        and size are controlled by the tag's style properties rather than
        embedded in this text.

        """
        ...


    @text.setter
    def text(self, value : str):
        ...


class Button(uiItem):
    """
    A clickable UI button that can trigger actions when pressed.

    Buttons are one of the most common UI elements for user interaction.
    They can be styled in different ways (normal, small, arrow) and can
    be configured to repeat actions when held down. The button's state
    is stored in a SharedBool value that tracks whether it's active.

    """
    def __init__(self, context : Context, arrow : Any = ..., attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : None  = [], enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, repeat : bool = False, scaling_factor : float = 1.0, shareable_value : SharedBool = ..., show : bool = True, small : bool = False, theme : Any = ..., user_data : Any = ..., value : bool = False, width : float = 0.0):
        """
        Parameters
        ----------
        - arrow: If not None, draw an arrow with the specified direction.
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - repeat: Whether the button generates repeated events when held down.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - small: Whether the button should be displayed in a small size.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def activated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned to the active state this frame.

        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use
        event handlers instead as they provide more robust state tracking.

        """
        ...


    @property
    def active(self) -> bool:
        """
        (Read-only) Whether the item is in an active state.

        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.

        """
        ...


    @property
    def arrow(self):
        """
        If not None, draw an arrow with the specified direction.

        This property is ignored when small is set, and in addition the requested
        size is ignored (but is affected by theme settings).

        Possible values are defined in the ButtonDirection enum: Up, Down, Left, Right.
        None means the feature is disabled and the button will be drawn normally.

        """
        ...


    @arrow.setter
    def arrow(self, value):
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def deactivated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned from active to inactive this frame.

        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def repeat(self) -> bool:
        """
        Whether the button generates repeated events when held down.

        When enabled, the button will trigger clicked events repeatedly while
        being held down, rather than just a single event when clicked. This
        is useful for actions that should be repeatable, like incrementing
        or decrementing values.

        """
        ...


    @repeat.setter
    def repeat(self, value : bool):
        ...


    @property
    def small(self) -> bool:
        """
        Whether the button should be displayed in a small size.

        Small buttons have a more compact appearance with less padding than
        standard buttons. When set to True, overrides the arrow property.

        """
        ...


    @small.setter
    def small(self, value : bool):
        ...


class Callback(object):
    """
    Wrapper class that automatically encapsulate callbacks.

    Callbacks in DCG mode can take up to 3 arguments:
        - source_item: the item to which the callback was attached
        - target_item: the item for which the callback was raised.
            Is only different to source_item for handlers' callback.
        - call_info: If applicable information about the call (key button, etc)

    """
    def __init__(self, callback : DCGCallable):
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """(Read-only) Wrapped callback
        """
        ...


class Checkbox(uiItem):
    """
    A checkbox UI element that allows toggling a boolean value.

    A checkbox is a standard UI control that displays a square box which can be
    checked or unchecked by the user. It's commonly used to represent binary
    choices or toggle settings in an application.

    The checkbox's state is stored in a SharedBool value, which can be accessed
    and modified through the inherited value property. When clicked, the checkbox
    toggles between checked and unchecked states.

    The checkbox responds to user interaction with proper hover and focus states,
    and can be disabled to prevent user interaction while still displaying the
    current value.

    If a label is provided, it will be displayed at the right of the checkbox.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : None  = [], enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedBool = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : bool = False, width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


class ChildWindow(uiItem):
    """
    A child window container that enables hierarchical UI layout.

    A child window creates a scrollable/clippable region within a parent window
    that can contain any UI elements and apply its own visual styling.

    Child windows provide independent scrolling regions within a parent window
    with content automatically clipped to the visible region. Content size can
    be fixed or dynamic based on settings. You can enable borders and backgrounds
    independently, customize keyboard focus navigation, and add menu bars for
    structured layouts.

    """
    def __init__(self, context : Context, always_auto_resize : bool = False, always_show_horizontal_scrollvar : bool = False, always_show_vertical_scrollvar : bool = False, always_use_window_padding : bool = False, attach : Any = ..., auto_resize_x : bool = False, auto_resize_y : bool = False, before : Any = ..., border : bool = True, callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : Sequence[uiItemSubCls | MenuBarSubCls] = [], enabled : bool = True, flattened_navigation : bool = True, focused : bool = False, font : Font = None, frame_style : bool = False, handlers : list = [], height : float = 0.0, horizontal_scrollbar : bool = False, indent : float = 0.0, label : str = "", menubar : bool = False, next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, no_scroll_with_mouse : bool = False, no_scrollbar : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, resizable_x : bool = False, resizable_y : bool = False, scaling_factor : float = 1.0, shareable_value : SharedValue = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : Any = ..., width : float = 0.0):
        """
        Parameters
        ----------
        - always_auto_resize: Measure content size even when window is hidden.
        - always_show_horizontal_scrollvar: Always show a horizontal scrollbar when horizontal scrolling is enabled.
        - always_show_vertical_scrollvar: Always show a vertical scrollbar even when content fits.
        - always_use_window_padding: Apply window padding even when borders are disabled.
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - auto_resize_x: Automatically adjust width based on content.
        - auto_resize_y: Automatically adjust height based on content.
        - before: Attach the item just before the target item. Default is None (disabled)
        - border: Show an outer border and enable window padding.
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - flattened_navigation: Share focus scope with parent window for keyboard/gamepad navigation.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - frame_style: Style the child window like a framed item instead of a window.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - horizontal_scrollbar: Enable horizontal scrolling and show horizontal scrollbar.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - menubar: Enable a menu bar at the top of the child window.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - no_scroll_with_mouse: Forward mouse wheel events to parent instead of scrolling this window.
        - no_scrollbar: Hide scrollbars but still allow scrolling with mouse/keyboard.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - resizable_x: Allow the user to resize the window width by dragging the right border.
        - resizable_y: Allow the user to resize the window height by dragging the bottom border.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def always_auto_resize(self) -> bool:
        """
        Measure content size even when window is hidden.

        When enabled in combination with auto_resize_x/auto_resize_y, the window
        will always measure its content size even when hidden. This causes the
        children to be rendered (though not visible) which allows for more
        consistent layouts when showing/hiding child windows.

        """
        ...


    @always_auto_resize.setter
    def always_auto_resize(self, value : bool):
        ...


    @property
    def always_show_horizontal_scrollvar(self) -> bool:
        """
        Always show a horizontal scrollbar when horizontal scrolling is enabled.

        When enabled, the horizontal scrollbar will always be displayed if
        horizontal scrolling is enabled, regardless of content width. This creates
        a consistent layout where the scrollbar space is always reserved.

        """
        ...


    @always_show_horizontal_scrollvar.setter
    def always_show_horizontal_scrollvar(self, value : bool):
        ...


    @property
    def always_show_vertical_scrollvar(self) -> bool:
        """
        Always show a vertical scrollbar even when content fits.

        When enabled, the vertical scrollbar will always be displayed regardless
        of whether the content requires scrolling. This can be useful for
        maintaining consistent layouts where scrollbars may appear and disappear.

        """
        ...


    @always_show_vertical_scrollvar.setter
    def always_show_vertical_scrollvar(self, value : bool):
        ...


    @property
    def always_use_window_padding(self) -> bool:
        """
        Apply window padding even when borders are disabled.

        When enabled, the child window will use the style's WindowPadding even if
        no borders are drawn. By default, non-bordered child windows don't apply
        padding. This creates consistent internal spacing regardless of whether
        borders are displayed.

        """
        ...


    @always_use_window_padding.setter
    def always_use_window_padding(self, value : bool):
        ...


    @property
    def auto_resize_x(self) -> bool:
        """
        Automatically adjust width based on content.

        When enabled, the child window will automatically resize its width based
        on the content inside it. Setting width to 0 with this option disabled
        will instead use the remaining width of the parent. This option is
        incompatible with resizable_x.

        """
        ...


    @auto_resize_x.setter
    def auto_resize_x(self, value : bool):
        ...


    @property
    def auto_resize_y(self) -> bool:
        """
        Automatically adjust height based on content.

        When enabled, the child window will automatically resize its height based
        on the content inside it. Setting height to 0 with this option disabled
        will instead use the remaining height of the parent. This option is
        incompatible with resizable_y.

        """
        ...


    @auto_resize_y.setter
    def auto_resize_y(self, value : bool):
        ...


    @property
    def border(self) -> bool:
        """
        Show an outer border and enable window padding.

        When enabled, the child window will display a border around its edges
        and automatically apply padding inside. This helps visually separate
        the child window's content from its surroundings and creates a cleaner,
        more structured appearance.

        """
        ...


    @border.setter
    def border(self, value : bool):
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def content_pos(self) -> Coord:
        """
        (Read-only) Position of the content area's top-left corner.

        This property provides the viewport-relative coordinates of the starting
        point for an item's content area. This is where child elements begin to be
        placed by default.

        Used together with content_region_avail, this defines the rectangle
        available for child elements.

        """
        ...


    @property
    def content_region_avail(self) -> Coord:
        """
        (Read-only) Available space for child items.

        For container items like windows, child windows, this
        property represents the available space for placing child items. This is
        the item's inner area after accounting for padding, borders, and other
        non-content elements.

        Areas that require scrolling to see are not included in this measurement.

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def flattened_navigation(self) -> bool:
        """
        Share focus scope with parent window for keyboard/gamepad navigation.

        When enabled, the focus scope is shared between parent and child windows,
        allowing keyboard and gamepad navigation to seamlessly cross between the
        parent window and this child or between sibling child windows. This
        creates a more intuitive navigation experience.

        """
        ...


    @flattened_navigation.setter
    def flattened_navigation(self, value : bool):
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def frame_style(self) -> bool:
        """
        Style the child window like a framed item instead of a window.

        When enabled, the child window will use frame-related style variables
        (FrameBg, FrameRounding, FrameBorderSize, FramePadding) instead of
        window-related ones (ChildBg, ChildRounding, ChildBorderSize,
        WindowPadding). This creates visual consistency with other framed elements.

        """
        ...


    @frame_style.setter
    def frame_style(self, value : bool):
        ...


    @property
    def horizontal_scrollbar(self) -> bool:
        """
        Enable horizontal scrolling and show horizontal scrollbar.

        When enabled, the window will support horizontal scrolling and display
        a horizontal scrollbar when content exceeds the window width. This is
        useful for wide content such as tables or long text lines that shouldn't
        wrap.

        """
        ...


    @horizontal_scrollbar.setter
    def horizontal_scrollbar(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def menubar(self) -> bool:
        """
        Enable a menu bar at the top of the child window.

        When enabled, the child window will display a menu bar at the top that
        can contain Menu elements. This property returns True if either the
        user has explicitly enabled it or if the window contains MenuBar child
        elements.

        """
        ...


    @menubar.setter
    def menubar(self, value : bool):
        ...


    @property
    def no_scroll_with_mouse(self) -> bool:
        """
        Forward mouse wheel events to parent instead of scrolling this window.

        When enabled, mouse wheel scrolling over this window will be forwarded
        to the parent window instead of scrolling this child window's content.
        This setting is ignored if no_scrollbar is also enabled. Useful for
        windows where you want to prioritize the parent's scrolling behavior.

        """
        ...


    @no_scroll_with_mouse.setter
    def no_scroll_with_mouse(self, value : bool):
        ...


    @property
    def no_scrollbar(self) -> bool:
        """
        Hide scrollbars but still allow scrolling with mouse/keyboard.

        When enabled, the window will not display scrollbars but content can
        still be scrolled using mouse wheel, keyboard, or programmatically.
        This creates a cleaner visual appearance while maintaining scrolling
        functionality.

        """
        ...


    @no_scrollbar.setter
    def no_scrollbar(self, value : bool):
        ...


    @property
    def resizable_x(self) -> bool:
        """
        Allow the user to resize the window width by dragging the right border.

        When enabled, the user can click and drag the right border of the child
        window to adjust its width. The direction respects the current layout
        direction. This option is incompatible with auto_resize_x and provides
        interactive resizing abilities to the child window.

        """
        ...


    @resizable_x.setter
    def resizable_x(self, value : bool):
        ...


    @property
    def resizable_y(self) -> bool:
        """
        Allow the user to resize the window height by dragging the bottom border.

        When enabled, the user can click and drag the bottom border of the child
        window to adjust its height. The direction respects the current layout
        direction. This option is incompatible with auto_resize_y and provides
        interactive resizing abilities to the child window.

        """
        ...


    @resizable_y.setter
    def resizable_y(self, value : bool):
        ...


class ClickedHandler(baseHandler):
    """
    Handler for when a hovered item is clicked on.
    The item doesn't have to be interactable,
    it can be Text for example.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., button : MouseButton = 0, callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - button: Target mouse button
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


    @property
    def button(self) -> MouseButton:
        """
        Target mouse button
        0: left click
        1: right click
        2: middle click
        3, 4: other buttons

        """
        ...


    @button.setter
    def button(self, value : MouseButton):
        ...


class CloseHandler(baseHandler):
    """
    Handler that triggers the callback when the
    item is in an closed state.
    *Warning*: Does not mean an item is un-shown
    by a user interaction (what we usually mean
    by closing a window).
    Here Close/Open refers to being in a
    reduced state when the full content is not
    shown, but could be if the user clicked on
    a specific button. The doesn't mean that
    the object is show or not shown.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class CollapsingHeader(uiItem):
    """
    A collapsible section header that can show or hide a group of widgets.

    CollapsingHeader creates a header element that can be expanded or collapsed by
    the user to reveal or hide its child elements. This helps organize interfaces
    with multiple sections by allowing users to focus on specific content areas.

    The header's open/closed state is stored in a SharedBool value accessible via
    the value property. Headers can be configured with various interaction modes,
    visual styles, and can optionally include a close button for hiding the entire
    section.

    CollapsingHeader is often used to create an accordion-like interface where
    multiple sections can be independently expanded or collapsed to manage screen
    space in complex interfaces.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., bullet : bool = False, callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : Sequence[uiItemSubCls] = [], closable : bool = False, enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", leaf : bool = False, next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, open_on_arrow : bool = False, open_on_double_click : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedBool = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : bool = False, width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - bullet: Whether to display a bullet instead of an arrow.
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - closable: Whether the header displays a close button.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - leaf: Whether the header is displayed without expansion controls.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - open_on_arrow: Whether the header opens only when clicking the arrow.
        - open_on_double_click: Whether a double-click is required to open the header.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def activated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned to the active state this frame.

        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use
        event handlers instead as they provide more robust state tracking.

        """
        ...


    @property
    def active(self) -> bool:
        """
        (Read-only) Whether the item is in an active state.

        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.

        """
        ...


    @property
    def bullet(self) -> bool:
        """
        Whether to display a bullet instead of an arrow.

        When enabled, the header will show a bullet point instead of the default
        arrow icon. This provides a different visual style that can be used to
        distinguish certain types of sections or to create bullet list appearances.

        Note that the header can still be expanded/collapsed unless the leaf
        property is also set.

        """
        ...


    @bullet.setter
    def bullet(self, value : bool):
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def closable(self) -> bool:
        """
        Whether the header displays a close button.

        When enabled, a small close button appears on the header that allows users
        to hide the entire section. When closed this way, the header's 'show'
        property is set to False, which can be detected through handlers or
        callbacks. Closed headers are not destroyed, just hidden.

        """
        ...


    @closable.setter
    def closable(self, value : bool):
        ...


    @property
    def deactivated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned from active to inactive this frame.

        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def leaf(self) -> bool:
        """
        Whether the header is displayed without expansion controls.

        When enabled, the header will be displayed without an arrow or expansion
        capability, creating a non-collapsible section header. This is useful for
        creating visual hierarchies where some items are fixed headers without
        collapsible content.

        """
        ...


    @leaf.setter
    def leaf(self, value : bool):
        ...


    @property
    def open_on_arrow(self) -> bool:
        """
        Whether the header opens only when clicking the arrow.

        When enabled, the header will only toggle its open state when the user
        clicks specifically on the arrow icon, not anywhere on the header label.
        This makes it easier to click on headers without expanding them.

        If combined with open_on_double_click, the header can be toggled either by
        a single click on the arrow or a double click anywhere on the header.

        """
        ...


    @open_on_arrow.setter
    def open_on_arrow(self, value : bool):
        ...


    @property
    def open_on_double_click(self) -> bool:
        """
        Whether a double-click is required to open the header.

        When enabled, the header will only toggle its open state when double-clicked,
        making it harder to accidentally expand sections. This can be useful for
        dense interfaces where you want to prevent unintended expansion during
        navigation.

        Can be combined with open_on_arrow to allow both arrow single-clicks and
        header double-clicks to toggle the section.

        """
        ...


    @open_on_double_click.setter
    def open_on_double_click(self, value : bool):
        ...


    @property
    def toggled(self) -> bool:
        """
        (Read-only) Whether the item was just toggled open this frame.

        Applies to items that can be expanded or collapsed, such as tree nodes,
        collapsing headers, or menus. This property is only true during the frame
        when the toggle from closed to open occurs.

        """
        ...


class ColorButton(uiItem):
    """
    A button that displays a color preview and opens a color picker when clicked.

    ColorButton creates an interactive color swatch that can be clicked to open a
    color picker popup. It displays the current color value and allows users to
    select a new color through the popup interface.

    The button's appearance can be customized with options for alpha display,
    borders, tooltips, and drag-and-drop functionality. The color value is stored
    in a SharedColor object accessible through the value property.

    When clicked, the button opens a color picker popup with the same options
    and behavior as the ColorPicker widget. This provides a compact way to
    integrate color selection into interfaces with limited space.

    """
    def __init__(self, context : Context, alpha_preview : str = "full", attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : None  = [], data_type : str = "uint8", enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_alpha : bool = False, no_border : bool = False, no_drag_drop : bool = False, no_newline : bool = False, no_scaling : bool = False, no_tooltip : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedColor = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : int = 0, width : float = 0.0):
        """
        Parameters
        ----------
        - alpha_preview: How transparency is displayed in the color button.
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - data_type: The data type used for color representation.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_alpha: Whether to ignore the Alpha component of the color.
        - no_border: Whether to disable the default border around the color button.
        - no_drag_drop: Whether to disable drag and drop functionality for the button.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - no_tooltip: Whether to disable the default tooltip when hovering.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def activated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned to the active state this frame.

        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use
        event handlers instead as they provide more robust state tracking.

        """
        ...


    @property
    def active(self) -> bool:
        """
        (Read-only) Whether the item is in an active state.

        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.

        """
        ...


    @property
    def alpha_preview(self) -> str:
        """
        How transparency is displayed in the color button.

        Controls how the alpha component of colors is displayed:
        - "none": No special alpha visualization
        - "full": Shows the entire button with alpha applied (default)
        - "half": Shows half the button with alpha applied

        The "half" mode is particularly useful as it allows seeing both the
        color with alpha applied and without in a single preview.

        """
        ...


    @alpha_preview.setter
    def alpha_preview(self, value : str):
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def data_type(self) -> str:
        """
        The data type used for color representation.

        Controls how color values are stored and processed:
        - "float": Colors as floating point values from 0.0 to 1.0
        - "uint8": Colors as 8-bit integers from 0 to 255

        This affects both the internal representation and how colors are passed
        to and from other widgets when using drag and drop.

        """
        ...


    @data_type.setter
    def data_type(self, value : str):
        ...


    @property
    def deactivated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned from active to inactive this frame.

        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def no_alpha(self) -> bool:
        """
        Whether to ignore the Alpha component of the color.

        When enabled, the button will display and operate only on the RGB
        components of the color, ignoring transparency. This is useful for
        interfaces where you only need to select solid colors without alpha
        transparency.

        """
        ...


    @no_alpha.setter
    def no_alpha(self, value : bool):
        ...


    @property
    def no_border(self) -> bool:
        """
        Whether to disable the default border around the color button.

        When enabled, the button will be displayed without its normal border.
        This can be useful for creating a cleaner look or when you want the
        color swatch to blend seamlessly with surrounding elements.

        """
        ...


    @no_border.setter
    def no_border(self, value : bool):
        ...


    @property
    def no_drag_drop(self) -> bool:
        """
        Whether to disable drag and drop functionality for the button.

        When enabled, the button won't work as a drag source for color values.
        By default, color buttons can be dragged to compatible drop targets
        (like other color widgets) to transfer their color value. Disabling this
        prevents that behavior.

        """
        ...


    @no_drag_drop.setter
    def no_drag_drop(self, value : bool):
        ...


    @property
    def no_tooltip(self) -> bool:
        """
        Whether to disable the default tooltip when hovering.

        When enabled, the automatic tooltip showing color information when
        hovering over the button will be suppressed. This is useful for cleaner
        interfaces or when you want to provide your own tooltip through a
        separate Tooltip widget.

        """
        ...


    @no_tooltip.setter
    def no_tooltip(self, value : bool):
        ...


class ColorEdit(uiItem):
    """
    A widget for editing RGB or RGBA color values with customizable input methods.

    ColorEdit provides interactive color editing through various input methods
    including sliders, hex input fields, and preview swatches. The chosen color
    is stored in a SharedColor value that can be accessed via the value property.

    The editor supports different color formats (RGB, HSV, Hex), input modes,
    and display options including alpha transparency. It can be configured to
    show or hide specific components like input fields, preview swatches,
    or alpha controls.

    When clicked, the color editor can optionally open a more comprehensive
    color picker popup for additional selection methods. The widget also supports
    drag-and-drop functionality for transferring colors between compatible widgets.

    """
    def __init__(self, context : Context, alpha_bar : bool = False, alpha_preview : str = "full", attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : None  = [], data_type : str = "uint8", display_mode : str = "rgb", enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], hdr : bool = False, height : float = 0.0, indent : float = 0.0, input_mode : str = "rgb", label : str = "", next_sibling : baseItemSubCls | None = None, no_alpha : bool = False, no_drag_drop : bool = False, no_inputs : bool = False, no_label : bool = False, no_newline : bool = False, no_options : bool = False, no_picker : bool = False, no_scaling : bool = False, no_small_preview : bool = False, no_tooltip : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedColor = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : int = 0, width : float = 0.0):
        """
        Parameters
        ----------
        - alpha_bar: Whether to show a vertical alpha bar/gradient.
        - alpha_preview: How transparency is displayed in the color button.
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - data_type: The data type used for color representation.
        - display_mode: The color display format for the input fields.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - hdr: Whether to support HDR (High Dynamic Range) colors.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - input_mode: The color input format for editing operations.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_alpha: Whether to ignore the Alpha component of the color.
        - no_drag_drop: Whether to disable drag and drop functionality.
        - no_inputs: Whether to hide the input sliders and text fields.
        - no_label: Whether to hide the text label next to the color editor.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_options: Whether to disable the right-click options menu.
        - no_picker: Whether to disable the color picker popup when clicking the color square.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - no_small_preview: Whether to hide the color square preview next to the inputs.
        - no_tooltip: Whether to disable the tooltip when hovering the preview.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def activated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned to the active state this frame.

        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use
        event handlers instead as they provide more robust state tracking.

        """
        ...


    @property
    def active(self) -> bool:
        """
        (Read-only) Whether the item is in an active state.

        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.

        """
        ...


    @property
    def alpha_bar(self) -> bool:
        """
        Whether to show a vertical alpha bar/gradient.

        When enabled and when alpha editing is supported, a vertical bar will
        be displayed showing the alpha gradient from transparent to opaque.
        This provides a visual reference for selecting alpha values and makes
        transparency editing more intuitive.

        """
        ...


    @alpha_bar.setter
    def alpha_bar(self, value : bool):
        ...


    @property
    def alpha_preview(self) -> str:
        """
        How transparency is displayed in the color button.

        Controls how the alpha component of colors is displayed:
        - "none": No special alpha visualization
        - "full": Shows the entire button with alpha applied (default)
        - "half": Shows half the button with alpha applied

        The "half" mode is particularly useful as it allows seeing both the
        color with alpha applied and without in a single preview.

        """
        ...


    @alpha_preview.setter
    def alpha_preview(self, value : str):
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def data_type(self) -> str:
        """
        The data type used for color representation.

        Controls how color values are stored and processed:
        - "float": Colors as floating point values from 0.0 to 1.0
        - "uint8": Colors as 8-bit integers from 0 to 255

        This affects both the internal representation and how colors are passed
        to and from other widgets when using drag and drop.

        """
        ...


    @data_type.setter
    def data_type(self, value : str):
        ...


    @property
    def deactivated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned from active to inactive this frame.

        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.

        """
        ...


    @property
    def display_mode(self) -> str:
        """
        The color display format for the input fields.

        Controls how color values are displayed in the editor:
        - "rgb": Red, Green, Blue components (default)
        - "hsv": Hue, Saturation, Value components
        - "hex": Hexadecimal color code

        This affects only the display format in the editor; the underlying
        color value storage remains consistent regardless of the display mode.

        """
        ...


    @display_mode.setter
    def display_mode(self, value : str):
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def hdr(self) -> bool:
        """
        Whether to support HDR (High Dynamic Range) colors.

        When enabled, the color editor will support values outside the standard
        0.0-1.0 range, allowing for HDR color selection. This is useful for
        applications working with lighting, rendering, or other contexts where
        color intensities can exceed standard display ranges.

        """
        ...


    @hdr.setter
    def hdr(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def input_mode(self) -> str:
        """
        The color input format for editing operations.

        Controls which color model is used for input operations:
        - "rgb": Edit in Red, Green, Blue color space (default)
        - "hsv": Edit in Hue, Saturation, Value color space

        This determines how slider adjustments behave - HSV mode often provides
        more intuitive color editing since it separates color (hue) from
        brightness and intensity.

        """
        ...


    @input_mode.setter
    def input_mode(self, value : str):
        ...


    @property
    def no_alpha(self) -> bool:
        """
        Whether to ignore the Alpha component of the color.

        When enabled, the color editor will display and operate only on the RGB
        components of the color, ignoring transparency. This is useful for
        interfaces where you only need to select solid colors without alpha
        transparency.

        """
        ...


    @no_alpha.setter
    def no_alpha(self, value : bool):
        ...


    @property
    def no_drag_drop(self) -> bool:
        """
        Whether to disable drag and drop functionality.

        When enabled, the color editor won't work as a drag source or drop
        target for color values. By default, colors can be dragged from
        this widget to other color widgets, and this widget can receive
        dragged colors. Disabling this creates a simpler interface with no
        drag interaction.

        """
        ...


    @no_drag_drop.setter
    def no_drag_drop(self, value : bool):
        ...


    @property
    def no_inputs(self) -> bool:
        """
        Whether to hide the input sliders and text fields.

        When enabled, the numeric input fields and sliders will be hidden,
        showing only the color preview swatch. This creates a compact color
        selector that still allows choosing colors through the picker popup
        when clicked, while taking minimal screen space.

        """
        ...


    @no_inputs.setter
    def no_inputs(self, value : bool):
        ...


    @property
    def no_label(self) -> bool:
        """
        Whether to hide the text label next to the color editor.

        When enabled, the widget's label won't be displayed inline with the
        color controls. The label text is still used for tooltips and in the
        color picker popup title if enabled. This creates a more compact
        interface when the label content is obvious from context.

        """
        ...


    @no_label.setter
    def no_label(self, value : bool):
        ...


    @property
    def no_options(self) -> bool:
        """
        Whether to disable the right-click options menu.

        When enabled, right-clicking on the inputs or small preview won't open
        the options context menu. This simplifies the interface by removing
        access to the format switching and other advanced options that would
        normally be available through the right-click menu.

        """
        ...


    @no_options.setter
    def no_options(self, value : bool):
        ...


    @property
    def no_picker(self) -> bool:
        """
        Whether to disable the color picker popup when clicking the color square.

        When enabled, clicking on the color preview square won't open the more
        comprehensive color picker popup. This creates a simpler interface limited
        to the main editing controls and can prevent users from accessing the
        additional selection methods in the popup.

        """
        ...


    @no_picker.setter
    def no_picker(self, value : bool):
        ...


    @property
    def no_small_preview(self) -> bool:
        """
        Whether to hide the color square preview next to the inputs.

        When enabled, the small color swatch that normally appears next to the
        input fields will be hidden, showing only the numeric inputs. This is
        useful for minimalist interfaces or when space is limited, especially
        when combined with other preview options.

        """
        ...


    @no_small_preview.setter
    def no_small_preview(self, value : bool):
        ...


    @property
    def no_tooltip(self) -> bool:
        """
        Whether to disable the tooltip when hovering the preview.

        When enabled, no tooltip will be shown when hovering over the color
        preview. By default, hovering the preview shows a tooltip with the
        color's values in different formats (RGB, HSV, Hex). This option
        creates a cleaner interface with less automatic popups.

        """
        ...


    @no_tooltip.setter
    def no_tooltip(self, value : bool):
        ...


class ColorPicker(uiItem):
    """
    A comprehensive color selection widget with multiple input and display options.

    ColorPicker provides a full-featured interface for selecting colors with
    multiple input methods including RGB/HSV sliders, color wheels, and hex input.
    It includes preview panels showing both the current and previous color, and
    supports advanced features like alpha transparency editing.

    The picker can be configured with various display modes, input formats, and
    visual options to adjust its appearance and behavior. It's ideal for
    applications requiring precise color selection with immediate visual feedback.

    The selected color is stored in a SharedColor value accessible through the
    value property inherited from uiItem.

    """
    def __init__(self, context : Context, alpha_bar : bool = False, alpha_preview : str = "full", attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : None  = [], data_type : str = "uint8", display_mode : str = "rgb", enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, input_mode : str = "rgb", label : str = "", next_sibling : baseItemSubCls | None = None, no_alpha : bool = False, no_inputs : bool = False, no_label : bool = False, no_newline : bool = False, no_scaling : bool = False, no_side_preview : bool = False, no_small_preview : bool = False, no_tooltip : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, picker_mode : str = "bar", pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedColor = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : int = 0, width : float = 0.0):
        """
        Parameters
        ----------
        - alpha_bar: Whether to show a vertical alpha bar/gradient.
        - alpha_preview: How transparency is displayed in the color button.
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - data_type: The data type used for color representation.
        - display_mode: The color display format for the input fields.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - input_mode: The color input format for editing operations.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_alpha: Whether to ignore the Alpha component of the color.
        - no_inputs: Whether to hide the input sliders and text fields.
        - no_label: Whether to hide the text label next to the color picker.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - no_side_preview: Whether to disable the large color preview on the picker's side.
        - no_small_preview: Whether to hide the color square preview next to the inputs.
        - no_tooltip: Whether to disable the tooltip when hovering the preview.
        - parent: Parent of the item in the rendering tree.
        - picker_mode: The visual style of the color picker control.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def activated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned to the active state this frame.

        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use
        event handlers instead as they provide more robust state tracking.

        """
        ...


    @property
    def active(self) -> bool:
        """
        (Read-only) Whether the item is in an active state.

        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.

        """
        ...


    @property
    def alpha_bar(self) -> bool:
        """
        Whether to show a vertical alpha bar/gradient.

        When enabled and when alpha editing is supported, a vertical bar will
        be displayed showing the alpha gradient from transparent to opaque.
        This provides a visual reference for selecting alpha values and makes
        transparency editing more intuitive.

        """
        ...


    @alpha_bar.setter
    def alpha_bar(self, value : bool):
        ...


    @property
    def alpha_preview(self) -> str:
        """
        How transparency is displayed in the color button.

        Controls how the alpha component of colors is displayed:
        - "none": No special alpha visualization
        - "full": Shows the entire button with alpha applied (default)
        - "half": Shows half the button with alpha applied

        The "half" mode is particularly useful as it allows seeing both the
        color with alpha applied and without in a single preview.

        """
        ...


    @alpha_preview.setter
    def alpha_preview(self, value : str):
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def data_type(self) -> str:
        """
        The data type used for color representation.

        Controls how color values are stored and processed:
        - "float": Colors as floating point values from 0.0 to 1.0
        - "uint8": Colors as 8-bit integers from 0 to 255

        This affects both the internal representation and how colors are passed
        to and from other widgets when using drag and drop.

        """
        ...


    @data_type.setter
    def data_type(self, value : str):
        ...


    @property
    def deactivated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned from active to inactive this frame.

        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.

        """
        ...


    @property
    def display_mode(self) -> str:
        """
        The color display format for the input fields.

        Controls how color values are displayed in the picker:
        - "rgb": Red, Green, Blue components (default)
        - "hsv": Hue, Saturation, Value components
        - "hex": Hexadecimal color code

        This affects only the display format in the editor; the underlying
        color value storage remains consistent regardless of the display mode.

        """
        ...


    @display_mode.setter
    def display_mode(self, value : str):
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def input_mode(self) -> str:
        """
        The color input format for editing operations.

        Controls which color model is used for input operations:
        - "rgb": Edit in Red, Green, Blue color space (default)
        - "hsv": Edit in Hue, Saturation, Value color space

        This determines how slider adjustments behave - HSV mode often provides
        more intuitive color editing since it separates color (hue) from
        brightness and intensity.

        """
        ...


    @input_mode.setter
    def input_mode(self, value : str):
        ...


    @property
    def no_alpha(self) -> bool:
        """
        Whether to ignore the Alpha component of the color.

        When enabled, the color picker will display and operate only on the RGB
        components of the color, ignoring transparency. This is useful for
        interfaces where you only need to select solid colors without alpha
        transparency.

        """
        ...


    @no_alpha.setter
    def no_alpha(self, value : bool):
        ...


    @property
    def no_inputs(self) -> bool:
        """
        Whether to hide the input sliders and text fields.

        When enabled, the numeric input fields and sliders will be hidden,
        showing only the color preview and picker elements. This creates a more
        visual color selection experience focused on the color wheel or bars
        rather than numeric precision.

        """
        ...


    @no_inputs.setter
    def no_inputs(self, value : bool):
        ...


    @property
    def no_label(self) -> bool:
        """
        Whether to hide the text label next to the color picker.

        When enabled, the widget's label won't be displayed inline with the
        color controls. The label text is still used for tooltips and in the
        picker title. This creates a more compact interface when the label
        content is obvious from context.

        """
        ...


    @no_label.setter
    def no_label(self, value : bool):
        ...


    @property
    def no_side_preview(self) -> bool:
        """
        Whether to disable the large color preview on the picker's side.

        When enabled, the larger color preview area on the right side of the
        picker (which typically shows both current and original colors) will be
        hidden. This reduces the picker's width and creates a more compact
        interface when space is limited.

        """
        ...


    @no_side_preview.setter
    def no_side_preview(self, value : bool):
        ...


    @property
    def no_small_preview(self) -> bool:
        """
        Whether to hide the color square preview next to the inputs.

        When enabled, the small color swatch that normally appears next to the
        input fields will be hidden, showing only the numeric inputs. This is
        useful for minimalist interfaces or when space is limited, especially
        when combined with other preview options.

        """
        ...


    @no_small_preview.setter
    def no_small_preview(self, value : bool):
        ...


    @property
    def no_tooltip(self) -> bool:
        """
        Whether to disable the tooltip when hovering the preview.

        When enabled, no tooltip will be shown when hovering over the color
        preview. By default, hovering the preview shows a tooltip with the
        color's values in different formats (RGB, HSV, Hex). This option
        creates a cleaner interface with less automatic popups.

        """
        ...


    @no_tooltip.setter
    def no_tooltip(self, value : bool):
        ...


    @property
    def picker_mode(self) -> str:
        """
        The visual style of the color picker control.

        Controls whether the color picker uses a bar or wheel interface for hue
        selection. The "bar" mode shows horizontal bars for hue, saturation and
        value, while "wheel" mode displays a circular hue selector with a
        square saturation/value selector. Different modes may be preferred
        depending on personal preference or specific color selection tasks.

        """
        ...


    @picker_mode.setter
    def picker_mode(self, value : str):
        ...


class Combo(uiItem):
    """
    A dropdown selection widget that displays a list of choices.

    Combo widgets provide an efficient way to select a single option from a
    list of items. When clicked, the dropdown expands to reveal a scrollable
    list of selectable options. Only one option can be selected at a time.

    The widget features configurable height modes, arrow button visibility,
    preview display options, and alignment settings to accommodate different
    interface needs.

    The selected value is stored in a SharedStr value, which can be accessed
    and modified through the value property inherited from uiItem. It corresponds
    to the currently selected item in the dropdown list.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : None  = [], enabled : bool = True, fit_width : bool = False, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, height_mode : str = "regular", indent : float = 0.0, items : list = [], label : str = "", next_sibling : baseItemSubCls | None = None, no_arrow_button : bool = False, no_newline : bool = False, no_preview : bool = False, no_scaling : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, popup_align_left : bool = False, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedStr = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : str = "", width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - fit_width: Makes the combo resize to fit the width of its content.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - height_mode: Controls the height of the dropdown portion of the combo.
        - indent: Horizontal indentation applied to the item.
        - items: List of text values to select from in the combo dropdown.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_arrow_button: Hides the dropdown arrow button on the combo widget.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_preview: Disables the preview of the selected item in the combo button.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - parent: Parent of the item in the rendering tree.
        - popup_align_left: Aligns the dropdown popup with the left edge of the combo button.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def activated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned to the active state this frame.

        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use
        event handlers instead as they provide more robust state tracking.

        """
        ...


    @property
    def active(self) -> bool:
        """
        (Read-only) Whether the item is in an active state.

        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.

        """
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def deactivated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned from active to inactive this frame.

        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.

        """
        ...


    @property
    def deactivated_after_edited(self) -> bool:
        """
        (Read-only) Whether the item was edited and then deactivated in this frame.

        Useful for detecting when user completes an edit operation, such as
        finishing text input or adjusting a value. This property is only true
        for the frame when the deactivation occurs after editing.

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def edited(self) -> bool:
        """
        (Read-only) Whether the item's value was modified this frame.

        This flag indicates that the user has made a change to the item's value,
        such as typing in an input field or adjusting a slider. It is only true
        for the frame when the edit occurs.

        """
        ...


    @property
    def fit_width(self) -> bool:
        """
        Makes the combo resize to fit the width of its content.

        When enabled, the combo width will expand to fit the content of the
        preview. This ensures that long text items don't get truncated in
        the combo display.

        """
        ...


    @fit_width.setter
    def fit_width(self, value : bool):
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def height_mode(self) -> str:
        """
        Controls the height of the dropdown portion of the combo.

        Supported values are "small", "regular", "large", and "largest".
        This affects how many items are visible at once when the dropdown
        is open, with "regular" being the default size.

        """
        ...


    @height_mode.setter
    def height_mode(self, value : str):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def items(self) -> list:
        """
        List of text values to select from in the combo dropdown.

        This property contains all available options that will be displayed
        when the combo is opened. If the value of the combo is not in this
        list, no item will appear selected. When the list is first created
        and the value is not yet set, the first item in this list (if any)
        will be automatically selected.

        """
        ...


    @items.setter
    def items(self, value : list):
        ...


    @property
    def no_arrow_button(self) -> bool:
        """
        Hides the dropdown arrow button on the combo widget.

        When enabled, the combo will not display the arrow button that typically
        appears on the right side. This can be useful for creating more compact
        interfaces or custom styling.

        """
        ...


    @no_arrow_button.setter
    def no_arrow_button(self, value : bool):
        ...


    @property
    def no_preview(self) -> bool:
        """
        Disables the preview of the selected item in the combo button.

        When enabled, the combo button will not display the currently selected
        value. This can be useful for creating more compact interfaces or when
        the selection is indicated elsewhere.

        """
        ...


    @no_preview.setter
    def no_preview(self, value : bool):
        ...


    @property
    def popup_align_left(self) -> bool:
        """
        Aligns the dropdown popup with the left edge of the combo button.

        When enabled, the dropdown list will be aligned with the left edge
        instead of the default alignment. This can be useful when the combo
        is positioned near the right edge of the screen.

        """
        ...


    @popup_align_left.setter
    def popup_align_left(self, value : bool):
        ...


    @property
    def toggled(self) -> bool:
        """
        (Read-only) Whether the item was just toggled open this frame.

        Applies to items that can be expanded or collapsed, such as tree nodes,
        collapsing headers, or menus. This property is only true during the frame
        when the toggle from closed to open occurs.

        """
        ...


class ConditionalHandler(baseHandler):
    """
    A handler that runs the FIRST handler child if all other handler children conditions are met.

    Unlike HandlerList, this handler:
    1. Only executes the first handler when conditions are met
    2. Uses other handlers only for condition checking (their callbacks are not called)

    One interest of this handler is to tests conditions immediately, rather than in a callback,
    avoiding timing issues with callback queues

    Useful for combining conditions, such as detecting clicks when specific keys are pressed.

    Skipping heavy CustomHandlers:
        One use case is to skip expensive run() calls from CustomHandlers.

    Note:
        Only the first handler's callback is executed when all conditions are met.
        Other handlers are used purely for their state conditions.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : Sequence[baseHandlerSubCls] = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class ContentResizeHandler(baseHandler):
    """
    Handler for item containers (windows, etc)
    that triggers the callback
    whenever the item's content region box (the
    area available to the children) changes size.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class Context(object):
    """
    Main class managing the DearCyGui items and imgui context.

    The Context class serves as the central manager for the DearCyGui application, handling:
        - GUI rendering and event processing
        - Item creation and lifecycle management
        - Thread-safe callback execution
        - Global viewport management
        - ImGui/ImPlot context management

    There is exactly one viewport per context. The last created context can be accessed
    as dearcygui.C.

    Implementation Notes
    -------------------
    - Thread safety is achieved through recursive mutexes on items and ImGui context
    - Callbacks are executed in a separate thread pool to prevent blocking the render loop
    - References between items form a tree structure with viewport as root
    - ImGui/ImPlot contexts are managed to support multiple contexts

    """
    def create_new_shared_gl_context(self, major, minor):
        """
        Create a new shared OpenGL context with the current context.

        Parameters:
        major : int
            Major version of the OpenGL context.
        minor : int
            Minor version of the OpenGL context.

        Returns:
            SharedGLContext instance

        """
        ...


    def fetch_parent_queue_back(self):
        """
        Retrieve the last item from the potential parent list.

        Returns:
        object
            The last item from the potential parent list.

        """
        ...


    def fetch_parent_queue_front(self):
        """
        Retrieve the top item from the potential parent list.

        Returns:
        object
            The top item from the potential parent list.

        """
        ...


    def get_mouse_clicked_count(self, button):
        """
        Get the number of times a mouse button is clicked in a row.

        Parameters:
        button : MouseButton
            Mouse button constant.

        Returns:
        int
            Number of times the mouse button is clicked in a row.

        """
        ...


    def get_mouse_drag_delta(self, button, lock_threshold=-1.0):
        """
        Return the delta (dx, dy) from the initial clicking position while the mouse button is pressed or was just released.

        Parameters:
        button : MouseButton
            Mouse button constant.
        lock_threshold : float, optional
            Distance threshold for locking the drag. Uses default distance if lock_threshold < 0.0f. Defaults to -1.

        Returns:
        tuple
            Tuple containing the drag delta (dx, dy).

        """
        ...


    def get_mouse_position(self):
        """
        Retrieve the mouse position (x, y).

        Returns:
        tuple
            Coord containing the mouse position (x, y).

        Raises:
        KeyError
            If there is no mouse.

        """
        ...


    def inject_key_down(self, key: 'Key'):
        """
        Inject a key down event for the next frame.

        Parameters:
        key : Key
            Key constant.

        """
        ...


    def inject_key_up(self, key: 'Key'):
        """
        Inject a key up event for the next frame.

        Parameters:
        key : Key
            Key constant.

        """
        ...


    def inject_mouse_down(self, button):
        """
        Inject a mouse down event for the next frame.

        Parameters:
        button : MouseButton
            Mouse button constant.

        """
        ...


    def inject_mouse_pos(self, x, y):
        """
        Inject a mouse position event for the next frame.

        Parameters:
        x : float
            X position of the mouse in pixels.
        y : float
            Y position of the mouse in pixels.

        """
        ...


    def inject_mouse_up(self, button):
        """
        Inject a mouse up event for the next frame.

        Parameters:
        button : MouseButton
            Mouse button constant.

        """
        ...


    def inject_mouse_wheel(self, wheel_x, wheel_y):
        """
        Inject a mouse wheel event for the next frame.

        Parameters:
        wheel_x : float
            Horizontal wheel movement in pixels.
        wheel_y : float
            Vertical wheel movement in pixels.

        """
        ...


    def is_key_down(self, key: 'Key', keymod: 'KeyMod' = None):
        """
        Check if a key is being held down.

        Parameters:
        key : Key
            Key constant.
        keymod : KeyMod, optional
            Key modifier mask (ctrl, shift, alt, super). If None, ignores any key modifiers.

        Returns:
        bool
            True if the key is down, False otherwise.

        """
        ...


    def is_key_pressed(self, key: 'Key', keymod: 'KeyMod' = None, repeat=True):
        """
        Check if a key was pressed (went from !Down to Down).

        Parameters:
        key : Key
            Key constant.
        keymod : KeyMod, optional
            Key modifier mask (ctrl, shift, alt, super). If None, ignores any key modifiers.
        repeat : bool, optional
            If True, the pressed state is repeated if the user continues pressing the key. Defaults to True.

        Returns:
        bool
            True if the key was pressed, False otherwise.

        """
        ...


    def is_key_released(self, key: 'Key', keymod: 'KeyMod' = None):
        """
        Check if a key was released (went from Down to !Down).

        Parameters:
        key : Key
            Key constant.
        keymod : KeyMod, optional
            Key modifier mask (ctrl, shift, alt, super). If None, ignores any key modifiers.

        Returns:
        bool
            True if the key was released, False otherwise.

        """
        ...


    def is_mouse_clicked(self, button, repeat=False):
        """
        Check if a mouse button was clicked (went from !Down to Down).

        Parameters:
        button : MouseButton
            Mouse button constant.
        repeat : bool, optional
            If True, the clicked state is repeated if the user continues pressing the button. Defaults to False.

        Returns:
        bool
            True if the mouse button was clicked, False otherwise.

        """
        ...


    def is_mouse_double_clicked(self, button):
        """
        Check if a mouse button was double-clicked.

        Parameters:
        button : MouseButton
            Mouse button constant.

        Returns:
        bool
            True if the mouse button was double-clicked, False otherwise.

        """
        ...


    def is_mouse_down(self, button):
        """
        Check if a mouse button is held down.

        Parameters:
        button : MouseButton
            Mouse button constant.

        Returns:
        bool
            True if the mouse button is down, False otherwise.

        """
        ...


    def is_mouse_dragging(self, button, lock_threshold=-1.0):
        """
        Check if the mouse is dragging.

        Parameters:
        button : MouseButton
            Mouse button constant.
        lock_threshold : float, optional
            Distance threshold for locking the drag. Uses default distance if lock_threshold < 0.0f. Defaults to -1.

        Returns:
        bool
            True if the mouse is dragging, False otherwise.

        """
        ...


    def is_mouse_released(self, button):
        """
        Check if a mouse button was released (went from Down to !Down).

        Parameters:
        button : MouseButton
            Mouse button constant.

        Returns:
        bool
            True if the mouse button was released, False otherwise.

        """
        ...


    def pop_next_parent(self):
        """
        Remove an item from the potential parent list.

        """
        ...


    def push_next_parent(self, next_parent):
        """
        Each time 'with' is used on an item, it is pushed
        to the list of potential parents to use if
        no parent (or before) is set when an item is created.
        If the list is empty, items are left unattached and
        can be attached later.

        In order to enable multiple threads to use
        the 'with' syntax, thread local storage is used,
        such that each thread has its own list.

        """
        ...


    def reset_mouse_drag_delta(self, button):
        """
        Reset the drag delta for the target button to 0.

        Parameters:
        button : MouseButton
            Mouse button constant.

        """
        ...


    @property
    def clipboard(self) -> str:
        """
        Content of the system clipboard.

        The clipboard can be read and written to interact with the system clipboard.

        Reading returns an empty string if the viewport is not yet initialized.

        """
        ...


    @clipboard.setter
    def clipboard(self, value : str):
        ...


    @property
    def queue(self) -> ThreadPoolExecutor:
        """
        Executor for managing thread-pooled callbacks.

        """
        ...


    @queue.setter
    def queue(self, value : ThreadPoolExecutor):
        ...


    @property
    def rendering_context(self) -> BackendRenderingContext:
        """
        (Read-only) Readonly attribute: rendering context for the backend.
        Used to create contexts with object sharing.

        """
        ...


    @property
    def running(self) -> bool:
        """
        Whether the context is currently running and processing frames.

        """
        ...


    @running.setter
    def running(self, value : bool):
        ...


    @property
    def viewport(self) -> Viewport:
        """
        (Read-only) Readonly attribute: root item from where rendering starts.

        """
        ...


class CustomHandler(baseHandler):
    """
    A base class to be subclassed in python for custom state checking.

    This class provides a framework for implementing custom handlers that can monitor
    and respond to specific item states. As this is called every frame rendered,
    and locks the GIL, be careful not to perform anything computationally heavy.

    Required Methods:
        check_can_bind(self, item):
            Must return a boolean indicating if this handler can be bound to the target item.
            Use isinstance() to check item types.

        check_status(self, item):
            Must return a boolean indicating if the watched condition is met.
            Should only check state, not perform actions.

        run(self, item) (Optional):
            If implemented, handles the response when conditions are met.
            Even with run() implemented, check_status() is still required.

    Warning:
        DO NOT modify item parent/sibling/child relationships during rendering.
        Changes to values or status are allowed except for parent modifications.
        For tree structure changes, delay until outside render_frame() or queue
        for execution in another thread.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class DPGCallback(Callback):
    """
    Used to run callbacks created for DPG.

    """
    def __init__(self, callback : DCGCallable):
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """(Read-only) Wrapped callback
        """
        ...


class DeactivatedAfterEditHandler(baseHandler):
    """
    However for editable items when the item loses
    activation after having been edited.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class DeactivatedHandler(baseHandler):
    """
    Handler for when an active item loses activation.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class DoubleClickedHandler(baseHandler):
    """
    Handler for when a hovered item is double clicked on.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., button : MouseButton = 0, callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


    @property
    def button(self) -> MouseButton:
        ...


    @button.setter
    def button(self, value : MouseButton):
        ...


class DraggedHandler(baseHandler):
    """
    Same as DraggingHandler, but only
    triggers the callback when the dragging
    has ended, instead of every frame during
    the dragging.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., button : MouseButton = 0, callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


    @property
    def button(self) -> MouseButton:
        ...


    @button.setter
    def button(self, value : MouseButton):
        ...


class DraggingHandler(baseHandler):
    """
    Handler to catch when the item is hovered
    and the mouse is dragging (click + motion) ?
    Note that if the item is not a button configured
    to catch the target button, it will not be
    considered being dragged as soon as it is not
    hovered anymore.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., button : MouseButton = 0, callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


    @property
    def button(self) -> MouseButton:
        ...


    @button.setter
    def button(self, value : MouseButton):
        ...


class DrawArc(drawingItem):
    """
    Draws an arc in coordinate space.

    An arc is a portion of an ellipse defined by its center, radii, start and end angles.
    The implementation follows SVG-like parametrization allowing both circular and
    elliptical arcs with optional rotation.

    Arcs can be filled and/or outlined with different colors and thickness.
    Negative radius values are interpreted in screen space rather than coordinate space.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., center : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), children : None  = [], color : Color = [1.0, 1.0, 1.0, 1.0], end_angle : float = 0.0, fill : Color = [0.0, 0.0, 0.0, 0.0], inner_radius : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), next_sibling : baseItemSubCls | None = None, parent : DrawInWindowSubCls | DrawInPlotSubCls | ViewportDrawListSubCls | drawingItemSubCls | None = None, pattern : Pattern | None = None, previous_sibling : baseItemSubCls | None = None, radius : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), rotation : float = 0.0, segments : int = 0, show : bool = True, start_angle : float = 0.0, thickness : float = 1.0, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - center: Center point of the arc in coordinate space.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - color: Color of the arc outline.
        - end_angle: Ending angle of the arc in radians.
        - fill: Fill color of the arc.
        - inner_radius: X and Y radii of the inner arc.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - pattern: Pattern of the outline.
        - previous_sibling: Child of the parent rendered just before this item.
        - radius: X and Y radii of the arc.
        - rotation: Rotation of the entire arc around its center in radians.
        - segments: Number of segments used to approximate the external
        - show: Should the object be drawn/shown ?
        - start_angle: Starting angle of the arc in radians.
        - thickness: Line thickness of the arc outline.
        - user_data: User data of any type.
        """
        ...


    @property
    def center(self) -> Coord:
        """
        Center point of the arc in coordinate space.

        This defines the origin around which the arc is drawn. The arc's radii
        extend from this point.

        """
        ...


    @center.setter
    def center(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def color(self) -> Color:
        """
        Color of the arc outline.

        Controls the color of the line tracing the path of the arc. Transparency
        is supported through the alpha channel.

        """
        ...


    @color.setter
    def color(self, value : Color):
        ...


    @property
    def end_angle(self) -> float:
        """
        Ending angle of the arc in radians.

        The arc is drawn from start_angle to end_angle in counter-clockwise direction.
        If end_angle is less than start_angle, they are swapped during rendering.

        """
        ...


    @end_angle.setter
    def end_angle(self, value : float):
        ...


    @property
    def fill(self) -> Color:
        """
        Fill color of the arc.

        The area between the center, start angle, and end angle is filled with this color.
        Transparency is supported through the alpha channel.

        """
        ...


    @fill.setter
    def fill(self, value : Color):
        ...


    @property
    def inner_radius(self) -> Coord:
        """
        X and Y radii of the inner arc.

        Defines the shape of the ellipse from which the arc is drawn:
        - Equal values create a circular arc
        - Different values create an elliptical arc
        - Negative values are interpreted as screen space units rather than coordinate space

        If radius and inner_radius are equal, the shape
        corresponds to a simple curved line, and the filling will
        join the extremities.

        An inner_radius of (0, 0) is equivalent to a filled arc (from the center)

        """
        ...


    @inner_radius.setter
    def inner_radius(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def pattern(self) -> Pattern | None:
        """
        Pattern of the outline.

        Controls the pattern of the line tracing the path.
        None for solid line.

        """
        ...


    @pattern.setter
    def pattern(self, value : Pattern | None):
        ...


    @property
    def radius(self) -> Coord:
        """
        X and Y radii of the arc.

        Defines the shape of the ellipse from which the arc is drawn:
        - Equal values create a circular arc
        - Different values create an elliptical arc
        - Negative values are interpreted as screen space units rather than coordinate space

        """
        ...


    @radius.setter
    def radius(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def rotation(self) -> float:
        """
        Rotation of the entire arc around its center in radians.

        This allows rotating the ellipse from which the arc is drawn, which is
        particularly useful for elliptical arcs to control their orientation.

        """
        ...


    @rotation.setter
    def rotation(self, value : float):
        ...


    @property
    def segments(self) -> int:
        """
        Number of segments used to approximate the external
        outline of the shape.

        Returns:
            int: Number of segments. 0 for auto.

        """
        ...


    @segments.setter
    def segments(self, value : int):
        ...


    @property
    def start_angle(self) -> float:
        """
        Starting angle of the arc in radians.

        The angle is measured from the positive x-axis, with positive values going
        counter-clockwise (0 = right, pi/2 = down, pi = left, 3pi/2 = up).

        """
        ...


    @start_angle.setter
    def start_angle(self, value : float):
        ...


    @property
    def thickness(self) -> float:
        """
        Line thickness of the arc outline.

        Controls the width of the line along the arc's path. The actual pixel width
        is affected by the viewport's scale and DPI settings.

        """
        ...


    @thickness.setter
    def thickness(self, value : float):
        ...


class DrawArrow(drawingItem):
    """
    Draws an arrow in coordinate space.

    An arrow consists of a line segment from p2 (start) to p1 (end) with a triangular
    arrowhead at the p1 end. The arrow's appearance is controlled by its color,
    line thickness, and arrowhead size.

    This drawing element is useful for indicating direction, marking points of interest,
    or visualizing vectors in coordinate space.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : None  = [], color : Color = [1.0, 1.0, 1.0, 1.0], next_sibling : baseItemSubCls | None = None, p1 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), p2 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), parent : DrawInWindowSubCls | DrawInPlotSubCls | ViewportDrawListSubCls | drawingItemSubCls | None = None, pattern : Pattern | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, size : float = 4.0, thickness : float = 1.0, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - color: Color of the arrow.
        - next_sibling: Child of the parent rendered just after this item.
        - p1: End point coordinates of the arrow (where the arrowhead is drawn).
        - p2: Start point coordinates of the arrow (the tail end).
        - parent: Parent of the item in the rendering tree.
        - pattern: Pattern of the outline.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Should the object be drawn/shown ?
        - size: Size of the arrow head.
        - thickness: Line thickness of the arrow.
        - user_data: User data of any type.
        """
        ...


    @property
    def color(self) -> Color:
        """
        Color of the arrow.

        Controls the color of both the line and arrowhead.

        """
        ...


    @color.setter
    def color(self, value : Color):
        ...


    @property
    def p1(self) -> Coord:
        """
        End point coordinates of the arrow (where the arrowhead is drawn).

        This is the destination point of the arrow, where the triangular head appears.

        """
        ...


    @p1.setter
    def p1(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def p2(self) -> Coord:
        """
        Start point coordinates of the arrow (the tail end).

        This is the starting point of the arrow, from where the line begins.

        """
        ...


    @p2.setter
    def p2(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def pattern(self) -> Pattern | None:
        """
        Pattern of the outline.

        Controls the pattern of the line tracing the path.
        None for solid line.

        """
        ...


    @pattern.setter
    def pattern(self, value : Pattern | None):
        ...


    @property
    def size(self) -> float:
        """
        Size of the arrow head.

        Controls how large the triangular head of the arrow appears. Larger values
        create a more prominent arrowhead.

        """
        ...


    @size.setter
    def size(self, value : float):
        ...


    @property
    def thickness(self) -> float:
        """
        Line thickness of the arrow.

        Controls the width of the line segment portion of the arrow. The actual pixel width
        is affected by the viewport's scale and DPI settings.

        """
        ...


    @thickness.setter
    def thickness(self, value : float):
        ...


class DrawBezierCubic(drawingItem):
    """
    Draws a cubic Bezier curve in coordinate space.

    A cubic Bezier curve is defined by four control points: starting point (p1),
    two intermediate control points (p2, p3) that shape the curvature, and an
    endpoint (p4). The curve starts at p1, is pulled toward p2 and p3, and ends at p4.

    The segments parameter controls the smoothness of the curve approximation,
    with higher values creating smoother curves at the cost of performance.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : None  = [], color : Color = [1.0, 1.0, 1.0, 1.0], next_sibling : baseItemSubCls | None = None, p1 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), p2 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), p3 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), p4 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), parent : DrawInWindowSubCls | DrawInPlotSubCls | ViewportDrawListSubCls | drawingItemSubCls | None = None, pattern : Pattern | None = None, previous_sibling : baseItemSubCls | None = None, segments : int = 0, show : bool = True, thickness : float = 0.0, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - color: Color of the Bezier curve.
        - next_sibling: Child of the parent rendered just after this item.
        - p1: First control point coordinates of the Bezier curve.
        - p2: Second control point coordinates of the Bezier curve.
        - p3: Third control point coordinates of the Bezier curve.
        - p4: Fourth control point coordinates of the Bezier curve.
        - parent: Parent of the item in the rendering tree.
        - pattern: Pattern of the outline.
        - previous_sibling: Child of the parent rendered just before this item.
        - segments: Number of line segments used to approximate the Bezier curve.
        - show: Should the object be drawn/shown ?
        - thickness: Line thickness of the Bezier curve.
        - user_data: User data of any type.
        """
        ...


    @property
    def color(self) -> Color:
        """
        Color of the Bezier curve.

        The color is specified as RGBA values. The alpha channel controls
        the transparency of the curve.

        """
        ...


    @color.setter
    def color(self, value : Color):
        ...


    @property
    def p1(self) -> Coord:
        """
        First control point coordinates of the Bezier curve.

        This is the starting point of the curve, where the curve begins.

        """
        ...


    @p1.setter
    def p1(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def p2(self) -> Coord:
        """
        Second control point coordinates of the Bezier curve.

        This control point, along with p3, determines the curvature and shape.
        The curve is pulled toward this point but does not necessarily pass through it.

        """
        ...


    @p2.setter
    def p2(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def p3(self) -> Coord:
        """
        Third control point coordinates of the Bezier curve.

        This control point, along with p2, determines the curvature and shape.
        The curve is pulled toward this point but does not necessarily pass through it.

        """
        ...


    @p3.setter
    def p3(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def p4(self) -> Coord:
        """
        Fourth control point coordinates of the Bezier curve.

        This is the end point of the curve, where the curve terminates.

        """
        ...


    @p4.setter
    def p4(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def pattern(self) -> Pattern | None:
        """
        Pattern of the outline.

        Controls the pattern of the line tracing the path.
        None for solid line.

        """
        ...


    @pattern.setter
    def pattern(self, value : Pattern | None):
        ...


    @property
    def segments(self) -> int:
        """
        Number of line segments used to approximate the Bezier curve.

        Higher values create a smoother curve at the cost of performance.
        A value of 0 uses the default number of segments determined by ImGui.

        """
        ...


    @segments.setter
    def segments(self, value : int):
        ...


    @property
    def thickness(self) -> float:
        """
        Line thickness of the Bezier curve.

        This controls the width of the curve line. The actual pixel width
        is affected by the viewport's scale and DPI settings.

        """
        ...


    @thickness.setter
    def thickness(self, value : float):
        ...


class DrawBezierQuadratic(drawingItem):
    """
    Draws a quadratic Bezier curve in coordinate space.

    A quadratic Bezier curve is defined by three control points: starting point (p1),
    an intermediate control point (p2) that shapes the curvature, and an endpoint (p3).
    The curve starts at p1, is pulled toward p2, and ends at p3.

    The segments parameter controls the smoothness of the curve approximation,
    with higher values creating smoother curves at the cost of performance.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : None  = [], color : Color = [1.0, 1.0, 1.0, 1.0], next_sibling : baseItemSubCls | None = None, p1 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), p2 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), p3 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), parent : DrawInWindowSubCls | DrawInPlotSubCls | ViewportDrawListSubCls | drawingItemSubCls | None = None, pattern : Pattern | None = None, previous_sibling : baseItemSubCls | None = None, segments : int = 0, show : bool = True, thickness : float = 0.0, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - color: Color of the Bezier curve.
        - next_sibling: Child of the parent rendered just after this item.
        - p1: First control point coordinates of the Bezier curve.
        - p2: Second control point coordinates of the Bezier curve.
        - p3: Third control point coordinates of the Bezier curve.
        - parent: Parent of the item in the rendering tree.
        - pattern: Pattern of the outline.
        - previous_sibling: Child of the parent rendered just before this item.
        - segments: Number of line segments used to approximate the Bezier curve.
        - show: Should the object be drawn/shown ?
        - thickness: Line thickness of the Bezier curve.
        - user_data: User data of any type.
        """
        ...


    @property
    def color(self) -> Color:
        """
        Color of the Bezier curve.

        The color is specified as RGBA values. The alpha channel controls
        the transparency of the curve.

        """
        ...


    @color.setter
    def color(self, value : Color):
        ...


    @property
    def p1(self) -> Coord:
        """
        First control point coordinates of the Bezier curve.

        This is the starting point of the curve, where the curve begins.

        """
        ...


    @p1.setter
    def p1(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def p2(self) -> Coord:
        """
        Second control point coordinates of the Bezier curve.

        This control point determines the curvature and shape of the curve.
        The curve is pulled toward this point but does not necessarily pass through it.

        """
        ...


    @p2.setter
    def p2(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def p3(self) -> Coord:
        """
        Third control point coordinates of the Bezier curve.

        This is the end point of the curve, where the curve terminates.

        """
        ...


    @p3.setter
    def p3(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def pattern(self) -> Pattern | None:
        """
        Pattern of the outline.

        Controls the pattern of the line tracing the path.
        None for solid line.

        """
        ...


    @pattern.setter
    def pattern(self, value : Pattern | None):
        ...


    @property
    def segments(self) -> int:
        """
        Number of line segments used to approximate the Bezier curve.

        Higher values create a smoother curve at the cost of performance.
        A value of 0 uses the default number of segments determined by ImGui.

        """
        ...


    @segments.setter
    def segments(self, value : int):
        ...


    @property
    def thickness(self) -> float:
        """
        Line thickness of the Bezier curve.

        This controls the width of the curve line. The actual pixel width
        is affected by the viewport's scale and DPI settings.

        """
        ...


    @thickness.setter
    def thickness(self, value : float):
        ...


class DrawCircle(drawingItem):
    """
    Draws a circle in coordinate space.

    A circle is defined by its center point and radius. The circle can be both filled
    with a solid color and outlined with a different color and thickness.

    Negative radius values are interpreted in screen space rather than coordinate space,
    which allows maintaining consistent visual size regardless of zoom level.

    The number of segments controls how smooth the circle appears - higher values
    create a more perfect circle at the cost of rendering performance.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., center : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), children : None  = [], color : Color = [1.0, 1.0, 1.0, 1.0], fill : Color = [0.0, 0.0, 0.0, 0.0], next_sibling : baseItemSubCls | None = None, parent : DrawInWindowSubCls | DrawInPlotSubCls | ViewportDrawListSubCls | drawingItemSubCls | None = None, pattern : Pattern | None = None, previous_sibling : baseItemSubCls | None = None, radius : float = 1.0, segments : int = 0, show : bool = True, thickness : float = 1.0, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - center: Center point of the circle in coordinate space.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - color: Color of the circle outline.
        - fill: Fill color of the circle.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - pattern: Pattern of the outline.
        - previous_sibling: Child of the parent rendered just before this item.
        - radius: Radius of the circle.
        - segments: Number of line segments used to approximate the circle.
        - show: Should the object be drawn/shown ?
        - thickness: Line thickness of the circle outline.
        - user_data: User data of any type.
        """
        ...


    @property
    def center(self) -> Coord:
        """
        Center point of the circle in coordinate space.

        This defines the origin around which the circle is drawn. The circle's radius
        extends from this point in all directions.

        """
        ...


    @center.setter
    def center(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def color(self) -> Color:
        """
        Color of the circle outline.

        Controls the color of the line tracing the path of the circle. Transparency
        is supported through the alpha channel.

        """
        ...


    @color.setter
    def color(self, value : Color):
        ...


    @property
    def fill(self) -> Color:
        """
        Fill color of the circle.

        The interior area of the circle is filled with this color.
        Transparency is supported through the alpha channel.

        """
        ...


    @fill.setter
    def fill(self, value : Color):
        ...


    @property
    def pattern(self) -> Pattern | None:
        """
        Pattern of the outline.

        Controls the pattern of the line tracing the path.
        None for solid line.

        """
        ...


    @pattern.setter
    def pattern(self, value : Pattern | None):
        ...


    @property
    def radius(self) -> float:
        """
        Radius of the circle.

        Controls the size of the circle. Positive values are interpreted in coordinate space
        and will scale with zoom level. Negative values are interpreted as screen space units
        and maintain consistent visual size regardless of zoom.

        """
        ...


    @radius.setter
    def radius(self, value : float):
        ...


    @property
    def segments(self) -> int:
        """
        Number of line segments used to approximate the circle.

        Higher values create a smoother circle at the cost of performance.
        A value of 0 uses the default number of segments determined by ImGui.

        """
        ...


    @segments.setter
    def segments(self, value : int):
        ...


    @property
    def thickness(self) -> float:
        """
        Line thickness of the circle outline.

        Controls the width of the line along the circle's path. The actual pixel width
        is affected by the viewport's scale and DPI settings. Negative values are interpreted
        in screen space units, maintaining consistent visual size regardless of zoom level.

        """
        ...


    @thickness.setter
    def thickness(self, value : float):
        ...


class DrawEllipse(drawingItem):
    """
    Draws an ellipse in coordinate space.

    The ellipse is defined by its bounding box and can be filled and/or outlined.

    For a more complex ellipse, defined by a center, radii, and rotation,
    use DrawArc with start_angle=0 and end_angle=2*pi.

    Attributes:
        pmin (tuple): Top-left corner coordinates (x, y)
        pmax (tuple): Bottom-right corner coordinates (x, y)
        color (list): RGBA color of the outline
        fill (list): RGBA color of the fill
        thickness (float): Outline thickness
        segments (int): Number of segments used to approximate the ellipse

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : None  = [], color : Color = [1.0, 1.0, 1.0, 1.0], fill : Color = [0.0, 0.0, 0.0, 0.0], next_sibling : baseItemSubCls | None = None, parent : DrawInWindowSubCls | DrawInPlotSubCls | ViewportDrawListSubCls | drawingItemSubCls | None = None, pattern : Pattern | None = None, pmax : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pmin : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, segments : int = 0, show : bool = True, thickness : float = 1.0, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - color: Color of the drawing outline.
        - fill: Fill color of the drawing.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - pattern: Pattern of the outline.
        - pmax: Bottom-right corner position of the drawing in coordinate space.
        - pmin: Top-left corner position of the drawing in coordinate space.
        - previous_sibling: Child of the parent rendered just before this item.
        - segments: Number of segments used to approximate the ellipse.
        - show: Should the object be drawn/shown ?
        - thickness: Line thickness of the drawing outline.
        - user_data: User data of any type.
        """
        ...


    @property
    def color(self) -> Color:
        """
        Color of the drawing outline.

        Returns:
            list: RGBA values in [0,1] range

        """
        ...


    @color.setter
    def color(self, value : Color):
        ...


    @property
    def fill(self) -> Color:
        """
        Fill color of the drawing.

        Returns:
            list: RGBA values in [0,1] range

        """
        ...


    @fill.setter
    def fill(self, value : Color):
        ...


    @property
    def pattern(self) -> Pattern | None:
        """
        Pattern of the outline.

        Controls the pattern of the line tracing the path.
        None for solid line.

        """
        ...


    @pattern.setter
    def pattern(self, value : Pattern | None):
        ...


    @property
    def pmax(self) -> Coord:
        """
        Bottom-right corner position of the drawing in coordinate space.

        Returns:
            tuple: (x, y) coordinates

        """
        ...


    @pmax.setter
    def pmax(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def pmin(self) -> Coord:
        """
        Top-left corner position of the drawing in coordinate space.

        Returns:
            tuple: (x, y) coordinates

        """
        ...


    @pmin.setter
    def pmin(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def segments(self) -> int:
        """
        Number of segments used to approximate the ellipse.

        Returns:
            int: Number of segments. 0 for auto.

        """
        ...


    @segments.setter
    def segments(self, value : int):
        ...


    @property
    def thickness(self) -> float:
        """
        Line thickness of the drawing outline.

        Returns:
            float: Thickness value in pixels

        """
        ...


    @thickness.setter
    def thickness(self, value : float):
        ...


class DrawImage(drawingItem):
    """
    Draws an image in coordinate space.

    An image drawing element displays a texture at a specific position with flexible
    positioning options. The image can be positioned using corner coordinates, min/max bounds,
    or center with direction and dimensions.

    The texture coordinates (UV) can be customized to show specific parts of the texture.
    Images can be tinted with a color multiplier and have rounded corners if needed.

    Width and height can be specified in coordinate space (positive values) or screen
    space (negative values), allowing for consistent visual sizes regardless of zoom level.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., center : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), children : None  = [], color_multiplier : list = [1.0, 1.0, 1.0, 1.0], direction : float = 0.0, height : float = 0.0, next_sibling : baseItemSubCls | None = None, p1 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), p2 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), p3 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), p4 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), parent : DrawInWindowSubCls | DrawInPlotSubCls | ViewportDrawListSubCls | drawingItemSubCls | None = None, pmax : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pmin : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, rounding : float = 0.0, show : bool = True, texture : Texture | None = None, user_data : Any = ..., uv1 : list = [0.0, 0.0], uv2 : list = [1.0, 0.0], uv3 : list = [1.0, 1.0], uv4 : list = [0.0, 1.0], uv_max : list = [1.0, 1.0], uv_min : list = [0.0, 0.0], width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - center: Center point of the image in coordinate space.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - color_multiplier: Color tint applied to the image.
        - direction: Rotation angle of the image in radians.
        - height: Height of the image.
        - next_sibling: Child of the parent rendered just after this item.
        - p1: Top-left corner of the image in coordinate space.
        - p2: Top-right corner of the image in coordinate space.
        - p3: Bottom-right corner of the image in coordinate space.
        - p4: Bottom-left corner of the image in coordinate space.
        - parent: Parent of the item in the rendering tree.
        - pmax: Bottom-right corner position of the image in coordinate space.
        - pmin: Top-left corner position of the image in coordinate space.
        - previous_sibling: Child of the parent rendered just before this item.
        - rounding: Radius of corner rounding applied to the image.
        - show: Should the object be drawn/shown ?
        - texture: The image content to be displayed.
        - user_data: User data of any type.
        - uv1: Texture coordinate for the top-left corner (p1).
        - uv2: Texture coordinate for the top-right corner (p2).
        - uv3: Texture coordinate for the bottom-right corner (p3).
        - uv4: Texture coordinate for the bottom-left corner (p4).
        - uv_max: Texture coordinate for the bottom-right corner of the image.
        - uv_min: Texture coordinate for the top-left corner of the image.
        - width: Width of the image.
        """
        ...


    @property
    def center(self) -> Coord:
        """
        Center point of the image in coordinate space.

        The center is used as the reference point when working with direction,
        width and height parameters. Changes to the center will update all four
        corner points while maintaining the current width, height and direction.

        """
        ...


    @center.setter
    def center(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def color_multiplier(self) -> list:
        """
        Color tint applied to the image.

        This color is multiplied with the texture pixels when rendering, allowing
        for tinting effects. Use white (1,1,1,1) for no tinting. The alpha channel
        controls the overall transparency of the image.

        """
        ...


    @color_multiplier.setter
    def color_multiplier(self, value : list):
        ...


    @property
    def direction(self) -> float:
        """
        Rotation angle of the image in radians.

        This is the angle between the horizontal axis and the line from the center
        to the middle of the right side of the image. Changes to direction will
        rotate the image around its center point.

        """
        ...


    @direction.setter
    def direction(self, value : float):
        ...


    @property
    def height(self) -> float:
        """
        Height of the image.

        Positive values are interpreted in coordinate space and will scale with zoom.
        Negative values are interpreted as screen space units and maintain constant
        visual size regardless of zoom level.

        """
        ...


    @height.setter
    def height(self, value : float):
        ...


    @property
    def p1(self) -> Coord:
        """
        Top-left corner of the image in coordinate space.

        This is one of the four corner points that define the image's position and shape.
        Modifying individual corner points allows creating non-rectangular quad shapes.

        """
        ...


    @p1.setter
    def p1(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def p2(self) -> Coord:
        """
        Top-right corner of the image in coordinate space.

        This is one of the four corner points that define the image's position and shape.
        Modifying individual corner points allows creating non-rectangular quad shapes.

        """
        ...


    @p2.setter
    def p2(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def p3(self) -> Coord:
        """
        Bottom-right corner of the image in coordinate space.

        This is one of the four corner points that define the image's position and shape.
        Modifying individual corner points allows creating non-rectangular quad shapes.

        """
        ...


    @p3.setter
    def p3(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def p4(self) -> Coord:
        """
        Bottom-left corner of the image in coordinate space.

        This is one of the four corner points that define the image's position and shape.
        Modifying individual corner points allows creating non-rectangular quad shapes.

        """
        ...


    @p4.setter
    def p4(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def pmax(self) -> Coord:
        """
        Bottom-right corner position of the image in coordinate space.

        Setting this also adjusts p3 directly and affects p2/p4 to maintain
        a rectangular shape aligned with axes. The center is automatically updated.

        """
        ...


    @pmax.setter
    def pmax(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def pmin(self) -> Coord:
        """
        Top-left corner position of the image in coordinate space.

        Setting this also adjusts p1 directly and affects p2/p4 to maintain
        a rectangular shape aligned with axes. The center is automatically updated.

        """
        ...


    @pmin.setter
    def pmin(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def rounding(self) -> float:
        """
        Radius of corner rounding applied to the image.

        When non-zero, corners of the image will be rounded with this radius.
        Note that using rounding forces the image to be rendered as a rectangle
        parallel to the axes, ignoring any non-rectangular quad settings from p1-p4.

        """
        ...


    @rounding.setter
    def rounding(self, value : float):
        ...


    @property
    def texture(self) -> Texture | None:
        """
        The image content to be displayed.

        This should be a Texture object that contains the image data to render.
        Without a valid texture, nothing will be drawn.

        """
        ...


    @texture.setter
    def texture(self, value : Texture | None):
        ...


    @property
    def uv1(self) -> list:
        """
        Texture coordinate for the top-left corner (p1).

        Normalized texture coordinate in the 0-1 range where (0,0) is the top-left
        of the texture and (1,1) is the bottom-right. Allows precise control over
        which part of the texture is mapped to this corner.

        """
        ...


    @uv1.setter
    def uv1(self, value : list):
        ...


    @property
    def uv2(self) -> list:
        """
        Texture coordinate for the top-right corner (p2).

        Normalized texture coordinate in the 0-1 range where (0,0) is the top-left
        of the texture and (1,1) is the bottom-right. Allows precise control over
        which part of the texture is mapped to this corner.

        """
        ...


    @uv2.setter
    def uv2(self, value : list):
        ...


    @property
    def uv3(self) -> list:
        """
        Texture coordinate for the bottom-right corner (p3).

        Normalized texture coordinate in the 0-1 range where (0,0) is the top-left
        of the texture and (1,1) is the bottom-right. Allows precise control over
        which part of the texture is mapped to this corner.

        """
        ...


    @uv3.setter
    def uv3(self, value : list):
        ...


    @property
    def uv4(self) -> list:
        """
        Texture coordinate for the bottom-left corner (p4).

        Normalized texture coordinate in the 0-1 range where (0,0) is the top-left
        of the texture and (1,1) is the bottom-right. Allows precise control over
        which part of the texture is mapped to this corner.

        """
        ...


    @uv4.setter
    def uv4(self, value : list):
        ...


    @property
    def uv_max(self) -> list:
        """
        Texture coordinate for the bottom-right corner of the image.

        Setting this affects uv2, uv3, and uv4 to create a rectangular texture mapping.
        Coordinates are normalized in the 0-1 range where (0,0) is the top-left of
        the texture and (1,1) is the bottom-right.

        """
        ...


    @uv_max.setter
    def uv_max(self, value : list):
        ...


    @property
    def uv_min(self) -> list:
        """
        Texture coordinate for the top-left corner of the image.

        Setting this affects uv1, uv2, and uv4 to create a rectangular texture mapping.
        Coordinates are normalized in the 0-1 range where (0,0) is the top-left of
        the texture and (1,1) is the bottom-right.

        """
        ...


    @uv_min.setter
    def uv_min(self, value : list):
        ...


    @property
    def width(self) -> float:
        """
        Width of the image.

        Positive values are interpreted in coordinate space and will scale with zoom.
        Negative values are interpreted as screen space units and maintain constant
        visual size regardless of zoom level.

        """
        ...


    @width.setter
    def width(self, value : float):
        ...


class DrawInPlot(plotElementWithLegend):
    """
    Enables drawing items inside a plot using plot coordinates.

    This element allows you to add drawing elements (shapes, texts, etc.)
    as children that will be rendered within the plot area and positioned
    according to the plot's coordinate system. This makes it easy to add
    annotations, highlights, and custom visualizations that adapt to plot
    scaling.

    By default, this element does not show up in the legend, though this
    can be changed.

    """
    def __init__(self, context : Context, attach : Any = ..., axes : tuple = (0, 3), before : Any = ..., children : Sequence[drawingItemSubCls] = [], enabled : bool = True, font : Font = None, ignore_fit : bool = False, label : str = "", legend_button : MouseButton = 1, legend_handlers : list = [], next_sibling : baseItemSubCls | None = None, no_legend : bool = True, parent : PlotSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, theme : Any = ..., user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - axes: The X and Y axes that the plot element is attached to.
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether this element is currently visible in the plot.
        - font: Font used for rendering this element's text.
        - ignore_fit: Whether this element should be excluded when auto-fitting axes.
        - label: Text label for the plot element.
        - legend_button: Mouse button that opens this element's legend popup.
        - legend_handlers: Event handlers attached to this element's legend entry.
        - next_sibling: Child of the parent rendered just after this item.
        - no_legend: Whether to hide this element from the plot legend.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Controls whether the plot element is visible.
        - theme: Visual theme applied to the plot element.
        - user_data: User data of any type.
        """
        ...


    @property
    def ignore_fit(self) -> bool:
        """
        Whether this element should be excluded when auto-fitting axes.

        When set to True, the drawing elements within this container won't
        influence the automatic fitting of axes. This is useful when adding
        reference elements or annotations that shouldn't affect the scale of
        the plot.

        """
        ...


    @ignore_fit.setter
    def ignore_fit(self, value : bool):
        ...


class DrawInWindow(uiItem):
    """
    An UI item that contains a region for Draw* elements.

    Enables to insert Draw* Elements inside a window. Inside a DrawInWindow
    elements, the (0, 0) coordinate starts at the top left of the DrawWindow
    and y increases when going down. The drawing region is clipped by the
    available width/height of the item (set manually, or deduced).

    An invisible button is created to span the entire drawing area, which is
    used to retrieve button states on the area (hovering, active, etc). If set,
    the callback is called when the mouse is pressed inside the area with any
    of the left, middle or right button. In addition, the use of an invisible
    button enables the drag and drop behaviour proposed by imgui.

    If you intend on dragging elements inside the drawing area, you can either
    implement yourself a hovering test for your specific items and use the
    context's is_mouse_dragging, or add invisible buttons on top of the elements
    you want to interact with, and combine the active and mouse dragging handlers.
    Note if you intend to make an element draggable that way, you must not make
    the element source of a Drag and Drop, as it impacts the hovering tests.

    Note that Drawing items do not have any hovering/clicked/visible/etc tests
    maintained and thus do not have a callback.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., button : bool = False, callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : Sequence[drawingItemSubCls] = [], enabled : bool = True, font : Font = None, frame : bool = False, handlers : list = [], height : float = 0.0, indent : float = 0.0, invert_y : bool = False, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, orig_x : float = 0.0, orig_y : float = 0.0, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, relative : bool = False, scale_x : float = 1.0, scale_y : float = 1.0, scaling_factor : float = 1.0, shareable_value : SharedValue = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : Any = ..., width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - button: Controls if the entire DrawInWindow area behaves like a single button.
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - font: Font used for rendering text in this item and its children.
        - frame: Controls whether the item has a visual frame.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - invert_y: Controls the direction of the Y coordinate axis.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - orig_x: The starting X coordinate inside the item (top-left).
        - orig_y: The starting Y coordinate inside the item (top-left).
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - relative: Determines if scaling is relative to the item's dimensions.
        - scale_x: The X scaling factor for items inside the drawing area.
        - scale_y: The Y scaling factor for items inside the drawing area.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def activated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned to the active state this frame.

        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use
        event handlers instead as they provide more robust state tracking.

        """
        ...


    @property
    def active(self) -> bool:
        """
        (Read-only) Whether the item is in an active state.

        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.

        """
        ...


    @property
    def button(self) -> bool:
        """
        Controls if the entire DrawInWindow area behaves like a single button.

        When True, the area acts as a clickable button with hover detection.
        When False (default), clicks and the hovered status will be forwarded
        to the window underneath.

        """
        ...


    @button.setter
    def button(self, value : bool):
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def deactivated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned from active to inactive this frame.

        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def frame(self) -> bool:
        """
        Controls whether the item has a visual frame.

        By default the frame is disabled for DrawInWindow. When enabled,
        a border will be drawn around the drawing area.

        """
        ...


    @frame.setter
    def frame(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def invert_y(self) -> bool:
        """
        Controls the direction of the Y coordinate axis.

        When True, orig_x/orig_y correspond to the bottom left of the item, and y
        increases when going up (Cartesian coordinates). When False (default),
        this is the top left, and y increases when going down (screen
        coordinates).

        """
        ...


    @invert_y.setter
    def invert_y(self, value : bool):
        ...


    @property
    def orig_x(self) -> float:
        """
        The starting X coordinate inside the item (top-left).

        This value represents the horizontal offset that will be applied to
        the origin of the drawing coordinates. It effectively shifts all
        child drawing elements by this amount horizontally.

        """
        ...


    @orig_x.setter
    def orig_x(self, value : float):
        ...


    @property
    def orig_y(self) -> float:
        """
        The starting Y coordinate inside the item (top-left).

        This value represents the vertical offset that will be applied to
        the origin of the drawing coordinates. It effectively shifts all
        child drawing elements by this amount vertically.

        """
        ...


    @orig_y.setter
    def orig_y(self, value : float):
        ...


    @property
    def relative(self) -> bool:
        """
        Determines if scaling is relative to the item's dimensions.

        When enabled, the scaling is relative to the item's width and height.
        This means the coordinate of the end of the visible area is
        (orig_x, orig_y) + (scale_x, scale_y). When disabled (default),
        scaling is absolute in pixel units.

        """
        ...


    @relative.setter
    def relative(self, value : bool):
        ...


    @property
    def scale_x(self) -> float:
        """
        The X scaling factor for items inside the drawing area.

        If set to 1.0 (default), the scaling corresponds to the unit of a pixel
        (as per global_scale). That is, the coordinate of the end of the visible
        area corresponds to item.width.

        """
        ...


    @scale_x.setter
    def scale_x(self, value : float):
        ...


    @property
    def scale_y(self) -> float:
        """
        The Y scaling factor for items inside the drawing area.

        If set to 1.0 (default), the scaling corresponds to the unit of a pixel
        (as per global_scale). That is, the coordinate of the end of the visible
        area corresponds to item.height.

        """
        ...


    @scale_y.setter
    def scale_y(self, value : float):
        ...


class DrawInvisibleButton(drawingItem):
    """
    Invisible rectangular area, parallel to axes, behaving
    like a button (using imgui default handling of buttons).

    Unlike other Draw items, this item accepts handlers and callbacks.

    DrawInvisibleButton can be overlapped on top of each other. In that
    case only one will be considered hovered. This one corresponds to the
    last one of the rendering tree that is hovered. If the button is
    considered active (see below), it retains the hover status to itself.
    Thus if you drag an invisible button on top of items later in the
    rendering tree, they will not be considered hovered.

    Note that only the mouse button(s) that trigger activation will
    have the above described behaviour for hover tests. If the mouse
    doesn't hover anymore the item, it will remain active as long
    as the configured buttons are pressed.

    When inside a plot, drag deltas are returned in plot coordinates,
    that is the deltas correspond to the deltas you must apply
    to your drawing coordinates compared to their original position
    to apply the dragging. When not in a plot, the drag deltas are
    in screen coordinates, and you must convert yourself to drawing
    coordinates if you are applying matrix transforms to your data.
    Generally matrix transforms are not well supported by
    DrawInvisibleButtons, and the shifted position that is updated
    during dragging might be invalid.

    Dragging handlers will not be triggered if the item is not active
    (unlike normal imgui items).

    If you create a DrawInvisibleButton in front of the mouse while
    the mouse is clicked with one of the activation buttons, it will
    steal hovering and activation tests. This is not the case of other
    gui items (except modal windows).

    If your Draw Button is not part of a window (ViewportDrawList),
    the hovering test might not be reliable (except specific case above).

    DrawInvisibleButton accepts children. In that case, the children
    are drawn relative to the coordinates of the DrawInvisibleButton,
    where top left is (0, 0) and bottom right is (1, 1).

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., button : MouseButtonMask = 7, capture_mouse : bool = True, children : Sequence[drawingItemSubCls] = [], handlers : list = [], max_side : float = inf, min_side : float = 0.0, next_sibling : baseItemSubCls | None = None, no_input : bool = False, p1 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), p2 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), parent : DrawInWindowSubCls | DrawInPlotSubCls | ViewportDrawListSubCls | drawingItemSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - button: Mouse button mask that makes the invisible button
        - capture_mouse: Writable attribute: If set, the item will
        - children: List of all the children of the item, from first rendered, to last rendered.
        - handlers: Writable attribute: bound handlers for the item.
        - max_side: If the rectangle width or height after
        - min_side: If the rectangle width or height after
        - next_sibling: Child of the parent rendered just after this item.
        - no_input: Writable attribute: If enabled, this item will not
        - p1: Corner of the invisible button in plot/drawing
        - p2: Opposite corner of the invisible button in plot/drawing
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Should the object be drawn/shown ?
        - user_data: User data of any type.
        """
        ...


    @property
    def activated(self) -> bool:
        """
        (Read-only) Readonly attribute: has the button just been pressed

        """
        ...


    @property
    def active(self) -> bool:
        """
        (Read-only) Readonly attribute: is the button held

        """
        ...


    @property
    def button(self) -> MouseButtonMask:
        """
        Mouse button mask that makes the invisible button
        active and triggers the item's callback.

        Default is all buttons

        The mask is an (OR) combination of
        1: left button
        2: right button
        4: middle button
        8: X1
        16: X2
        (See also MouseButtonMask)

        """
        ...


    @button.setter
    def button(self, value : MouseButtonMask):
        ...


    @property
    def capture_mouse(self) -> bool:
        """
        Writable attribute: If set, the item will
        capture the mouse if hovered even if another
        item was already active.

        As it is not in general a good behaviour (and
        will not behave well if several items with this
        state are overlapping),
        this is reset to False every frame.

        Default is True on creation. Thus creating an item
        in front of the mouse will capture it.

        """
        ...


    @capture_mouse.setter
    def capture_mouse(self, value : bool):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Readonly attribute: has the item just been clicked.
        The returned value is a tuple of len 5 containing the individual test
        mouse buttons (up to 5 buttons)
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.

        """
        ...


    @property
    def deactivated(self) -> bool:
        """
        (Read-only) Readonly attribute: has the button just been unpressed

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Readonly attribute: has the item just been double-clicked.
        The returned value is a tuple of len 5 containing the individual test
        mouse buttons (up to 5 buttons)
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.

        """
        ...


    @property
    def handlers(self) -> list:
        """
        Writable attribute: bound handlers for the item.
        If read returns a list of handlers. Accept
        a handler or a list of handlers as input.
        This enables to do item.handlers += [new_handler].

        """
        ...


    @handlers.setter
    def handlers(self, value : list):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Readonly attribute: Is the mouse inside area

        """
        ...


    @property
    def max_side(self) -> float:
        """
        If the rectangle width or height after
        coordinate transform is higher than this,
        resize the screen space transformed coordinates
        such that the width/height are at max max_side.
        Retains original ratio.

        """
        ...


    @max_side.setter
    def max_side(self, value : float):
        ...


    @property
    def min_side(self) -> float:
        """
        If the rectangle width or height after
        coordinate transform is lower than this,
        resize the screen space transformed coordinates
        such that the width/height are at least min_side.
        Retains original ratio.

        """
        ...


    @min_side.setter
    def min_side(self, value : float):
        ...


    @property
    def no_input(self) -> bool:
        """
        Writable attribute: If enabled, this item will not
        detect hovering or activation, thus letting other
        items taking the inputs.

        This is useful to use no_input - rather than show=False,
        if you want to still have handlers run if the item
        is in the visible region.

        """
        ...


    @no_input.setter
    def no_input(self, value : bool):
        ...


    @property
    def p1(self) -> Coord:
        """
        Corner of the invisible button in plot/drawing
        space

        """
        ...


    @p1.setter
    def p1(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def p2(self) -> Coord:
        """
        Opposite corner of the invisible button in plot/drawing
        space

        """
        ...


    @p2.setter
    def p2(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def pos_to_parent(self) -> Coord:
        """
        (Read-only) Readonly attribute:
        Relative position to latest non-drawing parent

        """
        ...


    @property
    def pos_to_viewport(self) -> Coord:
        """
        (Read-only) Readonly attribute:
        Current screen-space position of the top left
        of the item's rectangle. Basically the coordinate relative
        to the top left of the viewport.

        """
        ...


    @property
    def pos_to_window(self) -> Coord:
        """
        (Read-only) Readonly attribute:
        Relative position to the window's starting inner
        content area.

        """
        ...


    @property
    def rect_size(self) -> Coord:
        """
        (Read-only) Readonly attribute: actual (width, height) in pixels of the item on screen

        """
        ...


    @property
    def resized(self) -> bool:
        """
        (Read-only) Readonly attribute: has the item size just changed
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.

        """
        ...


class DrawLine(drawingItem):
    """
    Draws a line segment in coordinate space.

    A line can be defined in two equivalent ways: by its endpoints (p1, p2) or by
    its center point, direction angle, and length. Both representations are maintained
    in sync when either is modified.

    The length parameter can be set to a negative value to indicate that the line's
    length should be interpreted in screen space units rather than coordinate space,
    allowing for consistent visual size regardless of zoom level.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., center : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), children : None  = [], color : Color = [1.0, 1.0, 1.0, 1.0], direction : float = 0.0, length : float = 0.0, next_sibling : baseItemSubCls | None = None, p1 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), p2 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), parent : DrawInWindowSubCls | DrawInPlotSubCls | ViewportDrawListSubCls | drawingItemSubCls | None = None, pattern : Pattern | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, thickness : float = 1.0, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - center: Center point of the line segment.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - color: Color of the line.
        - direction: Angle of the line segment in radians.
        - length: Length of the line segment.
        - next_sibling: Child of the parent rendered just after this item.
        - p1: First endpoint of the line segment.
        - p2: Second endpoint of the line segment.
        - parent: Parent of the item in the rendering tree.
        - pattern: Pattern of the line.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Should the object be drawn/shown ?
        - thickness: Line thickness in pixels.
        - user_data: User data of any type.
        """
        ...


    @property
    def center(self) -> Coord:
        """
        Center point of the line segment.

        When modified, this updates the endpoints (p1 and p2) while maintaining
        the current direction and length of the line.

        """
        ...


    @center.setter
    def center(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def color(self) -> Color:
        """
        Color of the line.

        The color is specified as RGBA values. The alpha channel controls
        the transparency of the line.

        """
        ...


    @color.setter
    def color(self, value : Color):
        ...


    @property
    def direction(self) -> float:
        """
        Angle of the line segment in radians.

        This is the angle between the horizontal axis and the line from center to p2.
        When modified, this rotates the line around its center point.

        """
        ...


    @direction.setter
    def direction(self, value : float):
        ...


    @property
    def length(self) -> float:
        """
        Length of the line segment.

        Positive values are interpreted in coordinate space and will scale with zoom.
        Negative values are interpreted as screen space units and maintain constant
        visual size regardless of zoom level.

        """
        ...


    @length.setter
    def length(self, value : float):
        ...


    @property
    def p1(self) -> Coord:
        """
        First endpoint of the line segment.

        When modified, this updates the center, direction, and length properties
        to maintain a consistent representation of the line.

        """
        ...


    @p1.setter
    def p1(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def p2(self) -> Coord:
        """
        Second endpoint of the line segment.

        When modified, this updates the center, direction, and length properties
        to maintain a consistent representation of the line.

        """
        ...


    @p2.setter
    def p2(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def pattern(self) -> Pattern | None:
        """
        Pattern of the line.

        Controls the pattern of the line tracing the path.
        None for solid line.

        """
        ...


    @pattern.setter
    def pattern(self, value : Pattern | None):
        ...


    @property
    def thickness(self) -> float:
        """
        Line thickness in pixels.

        This controls the width of the line. The actual pixel width
        is affected by the viewport's scale and DPI settings.

        """
        ...


    @thickness.setter
    def thickness(self, value : float):
        ...


class DrawPolygon(drawingItem):
    """
    Draws a filled polygon in coordinate space.

    A polygon is defined by a sequence of points that form its vertices. The polygon
    can be both filled with a solid color and outlined with a different color and thickness.

    For non-convex polygons, automatic triangulation is performed to ensure proper
    filling. When the 'hull' option is enabled, only the convex hull of the points
    is drawn instead of the exact polygon shape.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : None  = [], color : Color = [1.0, 1.0, 1.0, 1.0], fill : Color = [0.0, 0.0, 0.0, 0.0], hull : bool = False, next_sibling : baseItemSubCls | None = None, parent : DrawInWindowSubCls | DrawInPlotSubCls | ViewportDrawListSubCls | drawingItemSubCls | None = None, pattern : Pattern | None = None, points : list = [], previous_sibling : baseItemSubCls | None = None, show : bool = True, thickness : float = 1.0, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - color: Color of the polygon outline.
        - fill: Fill color of the polygon.
        - hull: Whether to draw the convex hull instead of the exact polygon shape.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - pattern: Pattern of the outline.
        - points: List of vertex positions defining the shape.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Should the object be drawn/shown ?
        - thickness: Line thickness of the polygon outline.
        - user_data: User data of any type.
        """
        ...


    @property
    def color(self) -> Color:
        """
        Color of the polygon outline.

        Controls the color of the line tracing the boundary of the polygon.
        Transparency is supported through the alpha channel.

        """
        ...


    @color.setter
    def color(self, value : Color):
        ...


    @property
    def fill(self) -> Color:
        """
        Fill color of the polygon.

        The interior area of the polygon is filled with this color.
        Transparency is supported through the alpha channel.

        """
        ...


    @fill.setter
    def fill(self, value : Color):
        ...


    @property
    def hull(self) -> bool:
        """
        Whether to draw the convex hull instead of the exact polygon shape.

        When enabled, only the convex hull of the provided points is drawn,
        creating a shape with no concavities. This can be useful for
        simplifying complex shapes or ensuring convexity.

        """
        ...


    @hull.setter
    def hull(self, value : bool):
        ...


    @property
    def pattern(self) -> Pattern | None:
        """
        Pattern of the outline.

        Controls the pattern of the line tracing the path.
        None for solid line.

        """
        ...


    @pattern.setter
    def pattern(self, value : Pattern | None):
        ...


    @property
    def points(self) -> list:
        """
        List of vertex positions defining the shape.

        These points define the vertices of the polygon in coordinate space.
        The polygon is formed by connecting these points in order, with the
        last point connected back to the first to close the shape.

        """
        ...


    @points.setter
    def points(self, value : list):
        ...


    @property
    def thickness(self) -> float:
        """
        Line thickness of the polygon outline.

        Controls the width of the line along the polygon's boundary.
        The actual pixel width is affected by the viewport's scale
        and DPI settings. Negative values are interpreted in
        pixel space.

        """
        ...


    @thickness.setter
    def thickness(self, value : float):
        ...


class DrawPolyline(drawingItem):
    """
    Draws a sequence of connected line segments in coordinate space.

    Each point in the provided sequence is connected to the adjacent points by straight lines.
    The lines can be customized with color and thickness settings. By enabling the 'closed'
    property, the last point will be connected back to the first, forming a closed shape.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : None  = [], closed : bool = False, color : Color = [1.0, 1.0, 1.0, 1.0], next_sibling : baseItemSubCls | None = None, parent : DrawInWindowSubCls | DrawInPlotSubCls | ViewportDrawListSubCls | drawingItemSubCls | None = None, pattern : Pattern | None = None, points : list = [], previous_sibling : baseItemSubCls | None = None, show : bool = True, thickness : float = 1.0, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - closed: Whether the polyline forms a closed shape.
        - color: Color of the polyline.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - pattern: Pattern of the lines.
        - points: List of vertex positions defining the shape.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Should the object be drawn/shown ?
        - thickness: Line thickness of the polyline.
        - user_data: User data of any type.
        """
        ...


    @property
    def closed(self) -> bool:
        """
        Whether the polyline forms a closed shape.

        When set to True, an additional line segment connects the last point
        back to the first point, creating a closed loop. When False, the polyline
        remains open with distinct start and end points.

        """
        ...


    @closed.setter
    def closed(self, value : bool):
        ...


    @property
    def color(self) -> Color:
        """
        Color of the polyline.

        Controls the color of all line segments. The alpha channel can be used
        to create semi-transparent lines.

        """
        ...


    @color.setter
    def color(self, value : Color):
        ...


    @property
    def pattern(self) -> Pattern | None:
        """
        Pattern of the lines.

        Controls the pattern of the line tracing the path.
        None for solid line.

        """
        ...


    @pattern.setter
    def pattern(self, value : Pattern | None):
        ...


    @property
    def points(self) -> list:
        """
        List of vertex positions defining the shape.

        These points define the vertices through which the polyline passes.
        Each consecutive pair of points forms a line segment. At least two
        points are needed to draw a visible line.

        """
        ...


    @points.setter
    def points(self, value : list):
        ...


    @property
    def thickness(self) -> float:
        """
        Line thickness of the polyline.

        Controls the width of all line segments. The actual pixel width is affected
        by the viewport's scale and DPI settings. For very thin lines (thickness < 2.0),
        individual line segments are drawn for better quality.

        """
        ...


    @thickness.setter
    def thickness(self, value : float):
        ...


class DrawQuad(drawingItem):
    """
    Draws a quadrilateral in coordinate space.

    A quadrilateral is defined by four corner points that can be positioned freely in coordinate space.
    This allows creating shapes such as trapezoids, parallelograms, or arbitrary four-sided polygons.

    The quad can be both filled with a solid color and outlined with a different color and thickness.

    When filling is enabled, the shape is automatically triangulated into two triangles,
    with proper orientation handling to ensure correct anti-aliasing.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : None  = [], color : Color = [1.0, 1.0, 1.0, 1.0], fill : Color = [0.0, 0.0, 0.0, 0.0], next_sibling : baseItemSubCls | None = None, p1 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), p2 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), p3 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), p4 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), parent : DrawInWindowSubCls | DrawInPlotSubCls | ViewportDrawListSubCls | drawingItemSubCls | None = None, pattern : Pattern | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, thickness : float = 1.0, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - color: Color of the quadrilateral outline.
        - fill: Fill color of the quadrilateral.
        - next_sibling: Child of the parent rendered just after this item.
        - p1: First vertex position of the quadrilateral.
        - p2: Second vertex position of the quadrilateral.
        - p3: Third vertex position of the quadrilateral.
        - p4:
        - parent: Parent of the item in the rendering tree.
        - pattern: Pattern of the outline.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Should the object be drawn/shown ?
        - thickness: Line thickness of the quadrilateral outline.
        - user_data: User data of any type.
        """
        ...


    @property
    def color(self) -> Color:
        """
        Color of the quadrilateral outline.

        Controls the color of the lines tracing the perimeter of the quad.
        Transparency is supported through the alpha channel.

        """
        ...


    @color.setter
    def color(self, value : Color):
        ...


    @property
    def fill(self) -> Color:
        """
        Fill color of the quadrilateral.

        The interior area of the quad is filled with this color.
        Transparency is supported through the alpha channel.

        """
        ...


    @fill.setter
    def fill(self, value : Color):
        ...


    @property
    def p1(self) -> Coord:
        """
        First vertex position of the quadrilateral.

        This defines one of the four corners of the quad.

        """
        ...


    @p1.setter
    def p1(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def p2(self) -> Coord:
        """
        Second vertex position of the quadrilateral.

        This defines one of the four corners of the quad.

        """
        ...


    @p2.setter
    def p2(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def p3(self) -> Coord:
        """
        Third vertex position of the quadrilateral.

        This defines one of the four corners of the quad.

        """
        ...


    @p3.setter
    def p3(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def p4(self) -> Coord:
        """

        Fourth vertex position of the quadrilateral.

        This defines one of the four corners of the quad.

        """
        ...


    @p4.setter
    def p4(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def pattern(self) -> Pattern | None:
        """
        Pattern of the outline.

        Controls the pattern of the line tracing the path.
        None for solid line.

        """
        ...


    @pattern.setter
    def pattern(self, value : Pattern | None):
        ...


    @property
    def thickness(self) -> float:
        """
        Line thickness of the quadrilateral outline.

        Controls the width of the lines along the quad's perimeter.
        The actual pixel width is affected by the viewport's scale and DPI settings.
        Negative values are interpreted in pixel space.

        """
        ...


    @thickness.setter
    def thickness(self, value : float):
        ...


class DrawRect(drawingItem):
    """
    Draws a rectangle in coordinate space.

    A rectangle is defined by its minimum and maximum points, creating a shape
    aligned with the coordinate axes. The rectangle can be customized with solid fill,
    gradient fill across its corners, outline, and rounded corners.

    The thickness parameter controls the width of the outline, while rounding controls
    the radius of rounded corners. When using gradient fills, different colors can be
    specified for each corner of the rectangle.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : None  = [], color : Color = [1.0, 1.0, 1.0, 1.0], fill : Color = [0.0, 0.0, 0.0, 0.0], fill_p1 : list = [0.0, 0.0, 0.0, 0.0], fill_p2 : list = [0.0, 0.0, 0.0, 0.0], fill_p3 : list = [0.0, 0.0, 0.0, 0.0], fill_p4 : list = [0.0, 0.0, 0.0, 0.0], next_sibling : baseItemSubCls | None = None, parent : DrawInWindowSubCls | DrawInPlotSubCls | ViewportDrawListSubCls | drawingItemSubCls | None = None, pattern : Pattern | None = None, pmax : Sequence[float] | tuple[float, float] | Coord = (1.0, 1.0), pmin : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, rounding : float = 0.0, show : bool = True, thickness : float = 1.0, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - color: Color of the rectangle outline.
        - fill: Solid fill color of the rectangle.
        - fill_p1: Fill color at the top-left corner (p1) for gradient fills.
        - fill_p2: Fill color at the top-right corner (p2) for gradient fills.
        - fill_p3: Fill color at the bottom-right corner (p3) for gradient fills.
        - fill_p4: Fill color at the bottom-left corner (p4) for gradient fills.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - pattern: Pattern of the outline.
        - pmax: Bottom-right corner position of the rectangle in coordinate space.
        - pmin: Top-left corner position of the rectangle in coordinate space.
        - previous_sibling: Child of the parent rendered just before this item.
        - rounding: Radius of the rectangle's rounded corners.
        - show: Should the object be drawn/shown ?
        - thickness: Line thickness of the rectangle outline.
        - user_data: User data of any type.
        """
        ...


    @property
    def color(self) -> Color:
        """
        Color of the rectangle outline.

        Controls the color of the line tracing the perimeter of the rectangle.
        Transparency is supported through the alpha channel.

        """
        ...


    @color.setter
    def color(self, value : Color):
        ...


    @property
    def fill(self) -> Color:
        """
        Solid fill color of the rectangle.

        The interior area of the rectangle is filled with this color.
        Setting this property also resets all corner gradient colors to match,
        disabling multi-color gradient filling.

        """
        ...


    @fill.setter
    def fill(self, value : Color):
        ...


    @property
    def fill_p1(self) -> list:
        """
        Fill color at the top-left corner (p1) for gradient fills.

        When different colors are set for the four corners, the rectangle
        is filled with a smooth gradient between these colors. Setting any
        corner color enables the gradient fill mode.

        """
        ...


    @fill_p1.setter
    def fill_p1(self, value : list):
        ...


    @property
    def fill_p2(self) -> list:
        """
        Fill color at the top-right corner (p2) for gradient fills.

        When different colors are set for the four corners, the rectangle
        is filled with a smooth gradient between these colors. Setting any
        corner color enables the gradient fill mode.

        """
        ...


    @fill_p2.setter
    def fill_p2(self, value : list):
        ...


    @property
    def fill_p3(self) -> list:
        """
        Fill color at the bottom-right corner (p3) for gradient fills.

        When different colors are set for the four corners, the rectangle
        is filled with a smooth gradient between these colors. Setting any
        corner color enables the gradient fill mode.

        """
        ...


    @fill_p3.setter
    def fill_p3(self, value : list):
        ...


    @property
    def fill_p4(self) -> list:
        """
        Fill color at the bottom-left corner (p4) for gradient fills.

        When different colors are set for the four corners, the rectangle
        is filled with a smooth gradient between these colors. Setting any
        corner color enables the gradient fill mode.

        """
        ...


    @fill_p4.setter
    def fill_p4(self, value : list):
        ...


    @property
    def pattern(self) -> Pattern | None:
        """
        Pattern of the outline.

        Controls the pattern of the line tracing the path.
        None for solid line.

        """
        ...


    @pattern.setter
    def pattern(self, value : Pattern | None):
        ...


    @property
    def pmax(self) -> Coord:
        """
        Bottom-right corner position of the rectangle in coordinate space.

        This defines the maximum x and y coordinates of the rectangle. When used
        with pmin, it determines the overall size and position of the rectangle.

        """
        ...


    @pmax.setter
    def pmax(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def pmin(self) -> Coord:
        """
        Top-left corner position of the rectangle in coordinate space.

        This defines the minimum x and y coordinates of the rectangle. When used
        with pmax, it determines the overall size and position of the rectangle.

        """
        ...


    @pmin.setter
    def pmin(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def rounding(self) -> float:
        """
        Radius of the rectangle's rounded corners.

        When non-zero, the corners of the rectangle are rounded with this radius.
        Note that gradient fills with rounded corners are not supported - setting
        both gradient fill and rounding will prioritize the fill and display
        sharp corners.

        """
        ...


    @rounding.setter
    def rounding(self, value : float):
        ...


    @property
    def thickness(self) -> float:
        """
        Line thickness of the rectangle outline.

        Controls the width of the line along the rectangle's perimeter.
        The actual pixel width is affected by the viewport's scale and DPI settings.

        """
        ...


    @thickness.setter
    def thickness(self, value : float):
        ...


class DrawRegularPolygon(drawingItem):
    """
    Draws a regular polygon with n sides in coordinate space.

    A regular polygon has all sides of equal length and all interior angles equal.
    The shape is defined by its center point, radius, and number of sides.
    When num_points is set to a large value (or 1), the polygon approximates a circle.

    The direction parameter controls the rotation of the polygon by specifying
    the angle of the first vertex relative to the horizontal axis.

    Like other shape elements, the polygon can be both filled and outlined
    with different colors and thicknesses.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., center : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), children : None  = [], color : Color = [1.0, 1.0, 1.0, 1.0], direction : float = 0.0, fill : Color = [0.0, 0.0, 0.0, 0.0], next_sibling : baseItemSubCls | None = None, num_points : int = 1, parent : DrawInWindowSubCls | DrawInPlotSubCls | ViewportDrawListSubCls | drawingItemSubCls | None = None, pattern : Pattern | None = None, previous_sibling : baseItemSubCls | None = None, radius : float = 0.0, show : bool = True, thickness : float = 1.0, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - center: Coordinates of the center of the regular polygon.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - color: Color of the polygon outline.
        - direction: Angle of the first vertex in radians.
        - fill: Fill color of the polygon.
        - next_sibling: Child of the parent rendered just after this item.
        - num_points: Number of sides (vertices) in the regular polygon.
        - parent: Parent of the item in the rendering tree.
        - pattern: Pattern of the outline.
        - previous_sibling: Child of the parent rendered just before this item.
        - radius: Radius of the regular polygon.
        - show: Should the object be drawn/shown ?
        - thickness: Line thickness of the polygon outline.
        - user_data: User data of any type.
        """
        ...


    @property
    def center(self) -> Coord:
        """
        Coordinates of the center of the regular polygon.

        The center serves as the origin point from which all vertices
        are positioned at equal distances (the radius).

        """
        ...


    @center.setter
    def center(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def color(self) -> Color:
        """
        Color of the polygon outline.

        Controls the color of the lines tracing the perimeter of the polygon.
        Transparency is supported through the alpha channel.

        """
        ...


    @color.setter
    def color(self, value : Color):
        ...


    @property
    def direction(self) -> float:
        """
        Angle of the first vertex in radians.

        This controls the rotation of the entire polygon around its center.
        The angle is measured from the positive x-axis in counter-clockwise direction.

        """
        ...


    @direction.setter
    def direction(self, value : float):
        ...


    @property
    def fill(self) -> Color:
        """
        Fill color of the polygon.

        The interior area of the polygon is filled with this color.
        Transparency is supported through the alpha channel.

        """
        ...


    @fill.setter
    def fill(self, value : Color):
        ...


    @property
    def num_points(self) -> int:
        """
        Number of sides (vertices) in the regular polygon.

        Higher values create polygons with more sides. Setting to 3 creates a triangle,
        4 creates a square, 5 creates a pentagon, and so on.

        Setting to 1 is a special case that creates a circle.

        """
        ...


    @num_points.setter
    def num_points(self, value : int):
        ...


    @property
    def pattern(self) -> Pattern | None:
        """
        Pattern of the outline.

        Controls the pattern of the line tracing the path.
        None for solid line.

        """
        ...


    @pattern.setter
    def pattern(self, value : Pattern | None):
        ...


    @property
    def radius(self) -> float:
        """
        Radius of the regular polygon.

        This is the distance from the center to each vertex.
        Positive values are interpreted in coordinate space and will scale with zoom.
        Negative values are interpreted as screen space units and maintain constant
        visual size regardless of zoom level.

        """
        ...


    @radius.setter
    def radius(self, value : float):
        ...


    @property
    def thickness(self) -> float:
        """
        Line thickness of the polygon outline.

        Controls the width of the line tracing the perimeter of the polygon.
        The actual pixel width is affected by the viewport's scale and DPI settings.
        Negative values are interpreted in pixel space.

        """
        ...


    @thickness.setter
    def thickness(self, value : float):
        ...


class DrawSplitBatch(drawingItem):
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : None  = [], next_sibling : baseItemSubCls | None = None, parent : DrawInWindowSubCls | DrawInPlotSubCls | ViewportDrawListSubCls | drawingItemSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Should the object be drawn/shown ?
        - user_data: User data of any type.
        """
        ...


class DrawStar(drawingItem):
    """
    Draws a star shaped polygon with n points in coordinate space.

    A star is defined by its center, radius of exterior circle, inner radius, and number of points.
    The direction parameter controls the rotation of the star. When inner_radius is set to 0,
    the star becomes a cross or asterisk shape with lines intersecting at the center point.

    Like other drawing elements, the star can be both filled with a solid color and outlined
    with a different color and thickness. Radius can be specified in coordinate space (positive values)
    or screen space (negative values) to maintain consistent visual size regardless of zoom level.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., center : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), children : None  = [], color : Color = [1.0, 1.0, 1.0, 1.0], direction : float = 0.0, fill : Color = [0.0, 0.0, 0.0, 0.0], inner_radius : float = 0.0, next_sibling : baseItemSubCls | None = None, num_points : int = 5, parent : DrawInWindowSubCls | DrawInPlotSubCls | ViewportDrawListSubCls | drawingItemSubCls | None = None, pattern : Pattern | None = None, previous_sibling : baseItemSubCls | None = None, radius : float = 0.0, show : bool = True, thickness : float = 1.0, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - center: Coordinates of the center of the star.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - color: Color of the star outline.
        - direction: Angle of the first point of the star in radians.
        - fill: Fill color of the star.
        - inner_radius: Radius of the inner points of the star.
        - next_sibling: Child of the parent rendered just after this item.
        - num_points: Number of outer points in the star.
        - parent: Parent of the item in the rendering tree.
        - pattern: Pattern of the outline.
        - previous_sibling: Child of the parent rendered just before this item.
        - radius: Radius of the outer points of the star.
        - show: Should the object be drawn/shown ?
        - thickness: Line thickness of the star outline.
        - user_data: User data of any type.
        """
        ...


    @property
    def center(self) -> Coord:
        """
        Coordinates of the center of the star.

        This defines the central point around which the star is constructed. All points
        of the star extend outward from this position.

        """
        ...


    @center.setter
    def center(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def color(self) -> Color:
        """
        Color of the star outline.

        Controls the color of the lines tracing the perimeter of the star.
        Transparency is supported through the alpha channel.

        """
        ...


    @color.setter
    def color(self, value : Color):
        ...


    @property
    def direction(self) -> float:
        """
        Angle of the first point of the star in radians.

        This controls the rotation of the entire star around its center. The angle is
        measured from the positive x-axis in counter-clockwise direction. Changing this
        value rotates the star while maintaining its shape.

        """
        ...


    @direction.setter
    def direction(self, value : float):
        ...


    @property
    def fill(self) -> Color:
        """
        Fill color of the star.

        The interior area of the star is filled with this color.
        Transparency is supported through the alpha channel.

        """
        ...


    @fill.setter
    def fill(self, value : Color):
        ...


    @property
    def inner_radius(self) -> float:
        """
        Radius of the inner points of the star.

        This controls the distance from the center to each inner vertex of the star.
        Setting this to 0 creates a cross or asterisk shape instead of a star.
        The ratio between inner_radius and radius determines how pointed the star appears.

        """
        ...


    @inner_radius.setter
    def inner_radius(self, value : float):
        ...


    @property
    def num_points(self) -> int:
        """
        Number of outer points in the star.

        This determines how many points the star has. A value of 5 creates a traditional
        five-pointed star, while higher values create stars with more points. The minimum
        valid value is 3, which creates a triangular star.

        """
        ...


    @num_points.setter
    def num_points(self, value : int):
        ...


    @property
    def pattern(self) -> Pattern | None:
        """
        Pattern of the outline.

        Controls the pattern of the line tracing the path.
        None for solid line.

        """
        ...


    @pattern.setter
    def pattern(self, value : Pattern | None):
        ...


    @property
    def radius(self) -> float:
        """
        Radius of the outer points of the star.

        This controls the distance from the center to each outer vertex of the star.
        Positive values are interpreted in coordinate space and will scale with zoom.
        Negative values are interpreted as screen space units and maintain constant
        visual size regardless of zoom level.

        """
        ...


    @radius.setter
    def radius(self, value : float):
        ...


    @property
    def thickness(self) -> float:
        """
        Line thickness of the star outline.

        Controls the width of the lines forming the star's outline.
        The actual pixel width is affected by the viewport's scale and DPI settings.

        """
        ...


    @thickness.setter
    def thickness(self, value : float):
        ...


class DrawText(drawingItem):
    """
    Draws text in coordinate space.

    Text is rendered at the specified position using either default or custom font settings.
    The text can be scaled based on either coordinate space (which changes size with zoom)
    or screen space (which maintains consistent size regardless of zoom level).

    Font appearance can be customized with color and size options. When a custom font
    is provided, the text will use its style, weight, and other characteristics instead
    of the default font.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : None  = [], color : Color = [1.0, 1.0, 1.0, 1.0], font : Font = None, next_sibling : baseItemSubCls | None = None, parent : DrawInWindowSubCls | DrawInPlotSubCls | ViewportDrawListSubCls | drawingItemSubCls | None = None, pos : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, show : bool = True, size : float = 0.0, text : str = "", user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - color: Color of the text.
        - font: Custom font for rendering the text.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - pos: Position of the text in coordinate space.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Should the object be drawn/shown ?
        - size: Size of the font used to render text.
        - text: The string content to display.
        - user_data: User data of any type.
        """
        ...


    @property
    def color(self) -> Color:
        """
        Color of the text.

        Controls the color of the rendered text characters. Transparency
        is supported through the alpha channel, allowing for effects like
        watermarks or fading text.

        """
        ...


    @color.setter
    def color(self, value : Color):
        ...


    @property
    def font(self) -> Font:
        """
        Custom font for rendering the text.

        When set to a Font object, the text will use that font's style instead of
        the default system font. This allows for custom typography, including
        different weights, styles, or even icon fonts.

        """
        ...


    @font.setter
    def font(self, value : Font):
        ...


    @property
    def pos(self) -> Coord:
        """
        Position of the text in coordinate space.

        This defines the anchor point from which the text begins. By default,
        text is aligned from the top-left of this position.

        """
        ...


    @pos.setter
    def pos(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def size(self) -> float:
        """
        Size of the font used to render text.

        Positive values are interpreted in coordinate space and will scale with zoom.
        Negative values are interpreted as screen space units and maintain constant
        visual size regardless of zoom level. A value of 0 uses the default font size.

        """
        ...


    @size.setter
    def size(self, value : float):
        ...


    @property
    def text(self) -> str:
        """
        The string content to display.

        This is the actual text that will be rendered at the specified position.
        The text can contain multiple lines using newline characters.

        """
        ...


    @text.setter
    def text(self, value : str):
        ...


class DrawTriangle(drawingItem):
    """
    Draws a triangle in coordinate space.

    A triangle is defined by three vertex points that can be positioned freely in coordinate space.
    The shape can be both filled with a solid color and outlined with a different color and thickness.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : None  = [], color : Color = [1.0, 1.0, 1.0, 1.0], fill : Color = [0.0, 0.0, 0.0, 0.0], next_sibling : baseItemSubCls | None = None, p1 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), p2 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), p3 : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), parent : DrawInWindowSubCls | DrawInPlotSubCls | ViewportDrawListSubCls | drawingItemSubCls | None = None, pattern : Pattern | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, thickness : float = 1.0, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - color: Color of the triangle outline.
        - fill: Fill color of the triangle.
        - next_sibling: Child of the parent rendered just after this item.
        - p1: First vertex position of the triangle.
        - p2: Second vertex position of the triangle.
        - p3: Third vertex position of the triangle.
        - parent: Parent of the item in the rendering tree.
        - pattern: Pattern of the outline.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Should the object be drawn/shown ?
        - thickness: Line thickness of the triangle outline.
        - user_data: User data of any type.
        """
        ...


    @property
    def color(self) -> Color:
        """
        Color of the triangle outline.

        Controls the color of the lines tracing the perimeter of the triangle.
        Transparency is supported through the alpha channel.

        """
        ...


    @color.setter
    def color(self, value : Color):
        ...


    @property
    def fill(self) -> Color:
        """
        Fill color of the triangle.

        The interior area of the triangle is filled with this color.
        Transparency is supported through the alpha channel.

        """
        ...


    @fill.setter
    def fill(self, value : Color):
        ...


    @property
    def p1(self) -> Coord:
        """
        First vertex position of the triangle.

        This defines one of the three points that form the triangle. Together with p2 and p3,
        these coordinates determine the size, shape, and position of the triangle in coordinate space.

        """
        ...


    @p1.setter
    def p1(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def p2(self) -> Coord:
        """
        Second vertex position of the triangle.

        This defines one of the three points that form the triangle. Together with p1 and p3,
        these coordinates determine the size, shape, and position of the triangle in coordinate space.

        """
        ...


    @p2.setter
    def p2(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def p3(self) -> Coord:
        """
        Third vertex position of the triangle.

        This defines one of the three points that form the triangle. Together with p1 and p2,
        these coordinates determine the size, shape, and position of the triangle in coordinate space.

        """
        ...


    @p3.setter
    def p3(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def pattern(self) -> Pattern | None:
        """
        Pattern of the outline.

        Controls the pattern of the line tracing the path.
        None for solid line.

        """
        ...


    @pattern.setter
    def pattern(self, value : Pattern | None):
        ...


    @property
    def thickness(self) -> float:
        """
        Line thickness of the triangle outline.

        Controls the width of the lines along the triangle's perimeter.
        The actual pixel width is affected by the viewport's scale and DPI settings.
        Negative values are interpreted in pixel space.

        """
        ...


    @thickness.setter
    def thickness(self, value : float):
        ...


class DrawValue(drawingItem):
    """
    Draws a SharedValue in coordinate space.

    This drawing element displays the content of a SharedValue object at a specific position.
    It's useful for showing dynamic values that can be updated elsewhere in the application.

    The value display can be formatted using printf-style format strings, and its appearance
    can be customized with different fonts, colors and sizes. The size can be specified in
    coordinate space (positive values) or screen space (negative values).

    For security reasons, an intermediate buffer of fixed size is used with a limit of
    256 characters.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : None  = [], color : Color = [1.0, 1.0, 1.0, 1.0], font : Font = None, next_sibling : baseItemSubCls | None = None, parent : DrawInWindowSubCls | DrawInPlotSubCls | ViewportDrawListSubCls | drawingItemSubCls | None = None, pos : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, print_format : str = "%.3f", shareable_value : SharedFloat = ..., show : bool = True, size : float = 0.0, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - color: Color of the text.
        - font: Custom font for rendering the text.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - pos: Position of the text in coordinate space.
        - previous_sibling: Child of the parent rendered just before this item.
        - print_format: Format string for converting the value to a displayed string.
        - shareable_value: The SharedValue object being displayed.
        - show: Should the object be drawn/shown ?
        - size: Size of the font used to render text.
        - user_data: User data of any type.
        """
        ...


    @property
    def color(self) -> Color:
        """
        Color of the text.

        Controls the color of the rendered text characters. Transparency
        is supported through the alpha channel, allowing for effects like
        watermarks or fading text.

        """
        ...


    @color.setter
    def color(self, value : Color):
        ...


    @property
    def font(self) -> Font:
        """
        Custom font for rendering the text.

        When set to a Font object, the text will use that font's style instead of
        the default system font. This allows for custom typography, including
        different weights, styles, or even icon fonts.

        """
        ...


    @font.setter
    def font(self, value : Font):
        ...


    @property
    def pos(self) -> Coord:
        """
        Position of the text in coordinate space.

        This defines the anchor point from which the text begins. By default,
        text is aligned from the top-left of this position.

        """
        ...


    @pos.setter
    def pos(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def print_format(self) -> str:
        """
        Format string for converting the value to a displayed string.

        This property accepts printf-style format strings that control how the value
        is displayed. The format depends on the type of the SharedValue:

        - %d for SharedInt
        - %f for SharedFloat/SharedDouble
        - [%d, %d, %d, %d] for SharedInt4
        - (%f, %f, %f, %f) for SharedFloat4 or SharedColor
        - %s for SharedStr

        The default format for floating-point values is "%.3f".

        """
        ...


    @print_format.setter
    def print_format(self, value : str):
        ...


    @property
    def shareable_value(self) -> SharedFloat:
        """
        The SharedValue object being displayed.

        This property provides access to the underlying SharedValue that this element
        displays. The object holds a value field that is in sync with the internal value
        of the drawing. This same object can be passed to other items to share its value.

        Supported types include SharedBool, SharedInt, SharedFloat, SharedDouble,
        SharedColor, SharedInt4, SharedFloat4, SharedDouble4, and SharedStr.

        """
        ...


    @shareable_value.setter
    def shareable_value(self, value : SharedFloat):
        ...


    @property
    def size(self) -> float:
        """
        Size of the font used to render text.

        Positive values are interpreted in coordinate space and will scale with zoom.
        Negative values are interpreted as screen space units and maintain constant
        visual size regardless of zoom level. A value of 0 uses the default font size.

        """
        ...


    @size.setter
    def size(self, value : float):
        ...


class DrawingClip(drawingItem):
    """
    A DrawingList, but with clipping.

    By default, all items are submitted to the GPU.
    The GPU handles efficiently clipping items that are outside
    the clipping regions.

    In most cases, that's enough and you don't need
    this item.

    However if you have a really huge amount of drawing
    primitives, the submission can be CPU intensive.
    In this case you might want to skip submitting
    groups of drawing primitives that are known to be
    outside the visible region.

    Another use case, is when you want to have a different
    density of items depending on the zoom level.

    Both the above use-cases can be done manually
    using a DrawingList and setting the show
    attribute programmatically.

    This item enables to do this automatically.

    This item defines a clipping rectangle space-wise
    and zoom-wise. If this clipping rectangle is not
    in the visible space, the children are not rendered.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : Sequence[drawingItemSubCls] = [], next_sibling : baseItemSubCls | None = None, no_global_scaling : bool = False, parent : DrawInWindowSubCls | DrawInPlotSubCls | ViewportDrawListSubCls | drawingItemSubCls | None = None, pmax : Sequence[float] | tuple[float, float] | Coord = (1e+300, 1e+300), pmin : Sequence[float] | tuple[float, float] | Coord = (-1e+300, -1e+300), previous_sibling : baseItemSubCls | None = None, scale_max : float = inf, scale_min : float = 0.0, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - next_sibling: Child of the parent rendered just after this item.
        - no_global_scaling: Disable apply global scale to the min/max scaling.
        - parent: Parent of the item in the rendering tree.
        - pmax: (xmax, ymax) of the clip region
        - pmin: (xmin, ymin) of the clip region
        - previous_sibling: Child of the parent rendered just before this item.
        - scale_max: Maximum accepted coordinate scaling to screen space.
        - scale_min: Minimum accepted coordinate scaling to screen space.
        - show: Should the object be drawn/shown ?
        - user_data: User data of any type.
        """
        ...


    @property
    def no_global_scaling(self) -> bool:
        """
        Disable apply global scale to the min/max scaling.

        By default, the pixel size of scale_min/max
        is multiplied by the global scale in order
        to have the same behaviour of various screens.

        Setting to True this field disables that.

        """
        ...


    @no_global_scaling.setter
    def no_global_scaling(self, value : bool):
        ...


    @property
    def pmax(self) -> Coord:
        """
        (xmax, ymax) of the clip region

        pmax is the (xmax, ymax) corner of the rect that
        must be on screen for the children to be rendered.

        """
        ...


    @pmax.setter
    def pmax(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def pmin(self) -> Coord:
        """
        (xmin, ymin) of the clip region

        pmin is the (xmin, ymin) corner of the rect that
        must be on screen for the children to be rendered.

        """
        ...


    @pmin.setter
    def pmin(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def scale_max(self) -> float:
        """
        Maximum accepted coordinate scaling to screen space.

        The coordinate space to screen space scaling
        must be lower or equal to this amount. The measured pixel size
        between the coordinate (x=0, y=0) and (x=1, y=0)
        for the children to be rendered.

        """
        ...


    @scale_max.setter
    def scale_max(self, value : float):
        ...


    @property
    def scale_min(self) -> float:
        """
        Minimum accepted coordinate scaling to screen space.

        The coordinate space to screen space scaling
        must be strictly above this amount. The measured pixel size
        between the coordinate (x=0, y=0) and (x=1, y=0)
        for the children to be rendered.

        """
        ...


    @scale_min.setter
    def scale_min(self, value : float):
        ...


class DrawingList(drawingItem):
    """
    A simple drawing item that renders its children.

    Useful to arrange your items and quickly
    hide/show/delete them by manipulating the list.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : Sequence[drawingItemSubCls] = [], next_sibling : baseItemSubCls | None = None, parent : DrawInWindowSubCls | DrawInPlotSubCls | ViewportDrawListSubCls | drawingItemSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Should the object be drawn/shown ?
        - user_data: User data of any type.
        """
        ...


class DrawingScale(drawingItem):
    """
    A DrawingList, with a change in origin and scaling.

    DrawingScale can be used to defined a custom
    coordinate system for the children, duplicating
    what can be done with a Plot.

    It can also be used to cheaply apply shifts and
    scaling operations to the children.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : Sequence[drawingItemSubCls] = [], next_sibling : baseItemSubCls | None = None, no_global_scaling : bool = False, no_parent_scaling : bool = False, origin : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), parent : DrawInWindowSubCls | DrawInPlotSubCls | ViewportDrawListSubCls | drawingItemSubCls | None = None, previous_sibling : baseItemSubCls | None = None, scales : Sequence[float] | tuple[float, float] | Coord = (1.0, 1.0), show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - next_sibling: Child of the parent rendered just after this item.
        - no_global_scaling: Disables the global scale when no_parent_scaling is True.
        - no_parent_scaling: Resets any previous scaling to screen space.
        - origin: Position in coordinate space of the new origin for the children.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - scales: Scales (tuple or value) applied to the x and y axes for the children.
        - show: Should the object be drawn/shown ?
        - user_data: User data of any type.
        """
        ...


    @property
    def no_global_scaling(self) -> bool:
        """
        Disables the global scale when no_parent_scaling is True.

        """
        ...


    @no_global_scaling.setter
    def no_global_scaling(self, value : bool):
        ...


    @property
    def no_parent_scaling(self) -> bool:
        """
        Resets any previous scaling to screen space.

        Note origin is still transformed to screen space
        using the parent transform.

        When set to True, the global scale still
        impacts the scaling. Use no_global_scaling to
        disable this behaviour.

        """
        ...


    @no_parent_scaling.setter
    def no_parent_scaling(self, value : bool):
        ...


    @property
    def origin(self) -> Coord:
        """
        Position in coordinate space of the new origin for the children.

        Default is (0., 0.).

        """
        ...


    @origin.setter
    def origin(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def scales(self) -> Coord:
        """
        Scales (tuple or value) applied to the x and y axes for the children.

        Default is (1., 1.).

        Note unless no_parent_scale is True, the
        parent scales also apply.

        """
        ...


    @scales.setter
    def scales(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


class EditedHandler(baseHandler):
    """
    Handler to catch when a field is edited.
    Only the frames when a field is changed
    triggers the callback.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class FocusHandler(baseHandler):
    """
    Handler for windows or sub-windows that is called
    when they have focus, or for items when they
    have focus (for instance keyboard navigation,
    or editing a field).

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class Font(baseFont):
    """
    Represents a font that can be used in the UI.

    A Font object encapsulates the rendering information for text in the UI.
    It contains the texture data, size information, and scaling behavior.

    Fonts are typically created through FontTexture.add_font_file() or
    FontTexture.add_custom_font() rather than directly instantiated.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : Sequence[baseItemSubCls] = [], next_sibling : baseItemSubCls | None = None, no_scaling : bool = False, parent : baseItemSubCls | None = None, previous_sibling : baseItemSubCls | None = None, scale : float = 1.0, size : Any = ..., user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - next_sibling: Child of the parent rendered just after this item.
        - no_scaling: Controls whether font is affected by DPI scaling.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - scale: Multiplicative factor to scale the font when used.
        - size: Native height of characters in pixels.
        - user_data: User data of any type.
        """
        ...


    @property
    def no_scaling(self) -> bool:
        """
        Controls whether font is affected by DPI scaling.

        When True, the font ignores the global DPI scaling and only uses its own
        scale property. This is useful for fonts that should maintain consistent
        size regardless of screen resolution. Default is False.

        """
        ...


    @no_scaling.setter
    def no_scaling(self, value : bool):
        ...


    @property
    def scale(self) -> float:
        """
        Multiplicative factor to scale the font when used.

        This scale is applied in addition to any global scaling. Can be used
        to make specific fonts larger or smaller than others. A value of 1.0
        means no additional scaling.

        """
        ...


    @scale.setter
    def scale(self, value : float):
        ...


    @property
    def size(self):
        """
        Native height of characters in pixels.

        This is the original size at which the font was created. The actual
        rendered size will be affected by the scale property and the global
        scaling factor.

        """
        ...


    @size.setter
    def size(self, value):
        ...


    @property
    def texture(self) -> Texture | None:
        """
        (Read-only) The FontTexture containing this font.

        This property returns the parent FontTexture object that created and
        contains this font. The texture stores the actual bitmap data used
        for rendering.

        """
        ...


class FontMultiScales(baseFont):
    """
    A font container that manages multiple Font objects at different scales.

    Automatically selects the font with the inverse scale closest to the
    current global scale when used. This provides sharp text rendering across
    different display densities without manual font switching. The font with
    scale closest to 1/global_scale will be selected to minimize distortion.

    This class tracks recently encountered scales to optimize font selection
    and provides a callback mechanism to notify when new scales are encountered,
    allowing for dynamic font creation as needed.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : Sequence[baseItemSubCls] = [], fonts : list = [], next_sibling : baseItemSubCls | None = None, parent : baseItemSubCls | None = None, previous_sibling : baseItemSubCls | None = None, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Callbacks triggered when a new scale is encountered.
        - callbacks: Callbacks triggered when a new scale is encountered.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - fonts: List of attached fonts with different scales.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - user_data: User data of any type.
        """
        ...


    @property
    def callbacks(self) -> Sequence[DCGCallable]:
        """
        Callbacks triggered when a new scale is encountered.

        Each callback is called with the sender (this object), the target (also
        this object), and the new scale value that was just encountered. This
        mechanism enables dynamic font generation for new display densities.

        """
        ...


    @callbacks.setter
    def callbacks(self, value : Sequence[DCGCallable]):
        ...


    @property
    def fonts(self) -> list:
        """
        List of attached fonts with different scales.

        Each font in this list should have a different scale value to provide
        optimal rendering at different display densities. The font with scale
        closest to 1/global_scale will be used when this FontMultiScales is
        pushed.

        """
        ...


    @fonts.setter
    def fonts(self, value : list):
        ...


    @property
    def recent_scales(self) -> list:
        """
        (Read-only) List of up to 10 most recent global scales encountered during rendering.

        These scales represent the display density values recently seen while
        rendering UI. This information can be used to create additional font
        instances optimized for these specific scales. The scales are not stored
        in any particular order.

        """
        ...


class FontTexture(baseItem):
    """
    Packs one or several fonts into
    a texture for internal use by ImGui.

    In order to have sharp fonts with various screen
    dpi scalings, two options are available:
    1) Handle scaling yourself:
        Whenever the global scale changes, make
        a new font using a scaled size, and
        set no_scaling to True
    2) Handle scaling yourself at init only:
        In most cases it is reasonnable to
        assume the dpi scale will not change.
        In that case the easiest is to check
        the viewport dpi scale after initialization,
        load the scaled font size, and then set
        font.scale to the inverse of the dpi scale.
        This will render at the intended size
        as long as the dpi scale is not changed,
        and will scale if it changes (but will be
        slightly blurry).

    Currently the default font uses option 2). Call
    fonts.make_extended_latin_font(your_size) and
    add_custom_font to get the default font at a different
    scale, and implement 1) or 2) yourself.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : Sequence[baseItemSubCls] = [], next_sibling : baseItemSubCls | None = None, parent : baseItemSubCls | None = None, previous_sibling : baseItemSubCls | None = None, texture : Texture | None = None, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - texture: Readonly texture containing the font data.
        - user_data: User data of any type.
        """
        ...


    def add_custom_font(self, glyph_set):
        """
        See fonts.py for a detailed explanation of
        the input arguments.

        Currently add_custom_font calls build()
        and thus prevents adding new fonts, but
        this might not be true in the future, thus
        you should still call build().

        """
        ...


    def add_font_file(self, path, size=13.0, index_in_file=0, density_scale=1.0, align_to_pixel=False):
        """
        Prepare the target font file to be added to the FontTexture,
        using ImGui's font loader.

        path: path to the input font file (ttf, otf, etc).
        size: Target pixel size at which the font will be rendered by default.
        index_in_file: index of the target font in the font file.
        density_scale: rasterizer oversampling to better render when
            the font scale is not 1. Not a miracle solution though,
            as it causes blurry inputs if the actual scale used
            during rendering is less than density_scale.
        align_to_pixel: For sharp fonts, will prevent blur by
            aligning font rendering to the pixel. The spacing
            between characters might appear slightly odd as
            a result, so don't enable when not needed.

        """
        ...


    def build(self):
        """
        Packs all the fonts appended with add_font_file
        into a readonly texture.

        """
        ...


    @property
    def built(self) -> bool:
        ...


    @property
    def texture(self) -> Texture | None:
        """
        Readonly texture containing the font data.
        build() must be called first

        """
        ...


    @texture.setter
    def texture(self, value : Texture | None):
        ...


class GotFocusHandler(baseHandler):
    """
    Handler for when windows or sub-windows get
    focus.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class GotHoverHandler(baseHandler):
    """
    Handler that calls the callback when
    the target item has just been hovered.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class GotMouseOverHandler(baseHandler):
    """
Prefer GotHoverHandler unless you really need to (see MouseOverHandler)

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class GotRenderHandler(baseHandler):
    """
    Same as RenderHandler, but only calls the
    callback when the item switches from a
    non-rendered to a rendered state.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class HandlerList(baseHandler):
    """
    A container for multiple handlers that can be attached to an item.

    This handler allows grouping multiple handlers together and optionally
    executing a callback based on the combined state of all child handlers.

    The callback can be triggered based on three conditions:
    - ALL: All child handlers' states must be true (default)
    - ANY: At least one child handler's state must be true
    - NONE: No child handler's states are true

    Skipping heavy CustomHandlers:
        One use case is to skip expensive check_status() calls from CustomHandlers.
        If the status of the first children is incompatible with the checked condition,
        the status of further children is not checked.

    Note:
        Handlers are not checked if their parent item is not rendered.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : Sequence[baseHandlerSubCls] = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, op : HandlerListOP = 0, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - op: HandlerListOP that defines which condition
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


    @property
    def op(self) -> HandlerListOP:
        """
        HandlerListOP that defines which condition
        is required to trigger the callback of this
        handler.
        Default is ALL

        """
        ...


    @op.setter
    def op(self, value : HandlerListOP):
        ...


class HorizontalLayout(Layout):
    """
    A layout that organizes items horizontally from left to right.

    HorizontalLayout arranges child elements in a row, with customizable
    alignment modes, spacing, and wrapping options. It can align items to
    the left or right edge, center them, distribute them evenly using the
    justified mode, or position them manually.

    The layout automatically tracks content width changes and repositions
    children when needed. Wrapping behavior can be customized to control
    how items overflow when they exceed available width.

    """
    def __init__(self, context : Context, alignment_mode : Alignment = 0, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : Sequence[uiItemSubCls] = [], enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, no_wrap : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), positions : list = [], previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedValue = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : Any = ..., width : float = 0.0, wrap_x : float = 0.0):
        """
        Parameters
        ----------
        - alignment_mode: Horizontal alignment mode of the items.
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - no_wrap: Controls whether items wrap to the next row when exceeding available width.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - positions: X positions for items when using MANUAL alignment mode.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        - wrap_x: X position from which items start on wrapped rows.
        """
        ...


    @property
    def alignment_mode(self) -> Alignment:
        """
        Horizontal alignment mode of the items.

        LEFT: items are appended from the left
        RIGHT: items are appended from the right
        CENTER: items are centered
        JUSTIFIED: spacing is organized such that items start at the left
            and end at the right
        MANUAL: items are positioned at the requested positions

        For LEFT/RIGHT/CENTER, ItemSpacing's style can be used to control
        spacing between the items. Default is LEFT.

        """
        ...


    @alignment_mode.setter
    def alignment_mode(self, value : Alignment):
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def no_wrap(self) -> bool:
        """
        Controls whether items wrap to the next row when exceeding available width.

        When set to True, items will continue on the same row even if they exceed
        the layout's width. When False (default), items that don't fit will
        continue on the next row.

        """
        ...


    @no_wrap.setter
    def no_wrap(self, value : bool):
        ...


    @property
    def positions(self) -> list:
        """
        X positions for items when using MANUAL alignment mode.

        When in MANUAL mode, these are the x positions from the top left of this
        layout at which to place the children items.

        Values between 0 and 1 are interpreted as percentages relative to the
        layout width. Negative values are interpreted as relative to the right
        edge rather than the left. Items are still left-aligned to the target
        position.

        Setting this property automatically sets alignment_mode to MANUAL.

        """
        ...


    @positions.setter
    def positions(self, value : list):
        ...


    @property
    def wrap_x(self) -> float:
        """
        X position from which items start on wrapped rows.

        When items wrap to a second or later row, this value determines the
        horizontal offset from the starting position. The value is in pixels
        and must be scaled if needed. The position is clamped to ensure items
        always start at a position >= 0 relative to the window content area.

        """
        ...


    @wrap_x.setter
    def wrap_x(self, value : float):
        ...


class HoverHandler(baseHandler):
    """
    Handler that calls the callback when
    the target item is hovered.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class Image(uiItem):
    """
    A widget that displays a texture image in the UI.

    Image widgets allow displaying textures with options for resizing, tinting,
    and UV coordinate mapping. They can be used to show static images, icons,
    or dynamic content from render targets.

    The image's appearance can be customized through colors and UV coordinates
    to display specific regions of a texture. The size can be explicitly set or
    derived automatically from the texture dimensions with optional DPI scaling.

    The widget supports hover detection and can be used with callbacks to create
    interactive image elements without button behavior. When setting the
    button attribute, the widget integrates full button functionality and visual.
    In which case value is a SharedBool that indicates whether the button is pressed.

    Image borders: this widget is affected by the theme elements related to border:
    FrameBorderSize (style), Border (color). In addition when a button, is also
    affected by FramePadding (style) and FrameRounding (style).

    """
    def __init__(self, context : Context, attach : Any = ..., background_color : list = [0.0, 0.0, 0.0, 0.0], before : Any = ..., button : bool = False, callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : None  = [], color_multiplier : list = [1.0, 1.0, 1.0, 1.0], enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedValue = ..., show : bool = True, texture : Texture | None = None, theme : Any = ..., user_data : Any = ..., uv : list = [0.0, 0.0, 1.0, 1.0], value : Any = ..., width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - background_color: Color of the background drawn behind the image.
        - before: Attach the item just before the target item. Default is None (disabled)
        - button: Whether the image behaves as a button.
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - color_multiplier: Color tint applied to the image texture.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - texture: The texture to display in the image widget.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - uv: UV coordinates defining the region of the texture to display.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def background_color(self) -> list:
        """
        Color of the background drawn behind the image.

        A color value for the image's background. The color can be specified as an
        RGBA list with values from 0.0 to 1.0, or as a packed integer. Setting
        this to a transparent color (alpha=0) effectively hides the background.

        Default is transparent black [0, 0, 0, 0], which displays no background.

        Setting this attribute will have no effect if the image is opaque.
        The background color is not affected by the theme.

        """
        ...


    @background_color.setter
    def background_color(self, value : list):
        ...


    @property
    def button(self) -> bool:
        """
        Whether the image behaves as a button.

        When enabled, the image acts like a button and can be clicked to trigger
        actions. The value property is used to indicate whether the button is
        currently pressed or not. If set to False, the image behaves as a static
        image without button functionality.

        """
        ...


    @button.setter
    def button(self, value : bool):
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def color_multiplier(self) -> list:
        """
        Color tint applied to the image texture.

        A color value used to multiply with the texture's colors, allowing
        tinting, fading, or other color adjustments. The color can be specified
        as an RGBA list with values from 0.0 to 1.0, or as a packed integer.

        Default is white [1., 1., 1., 1.], which displays the texture with its
        original colors.

        """
        ...


    @color_multiplier.setter
    def color_multiplier(self, value : list):
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def texture(self) -> Texture | None:
        """
        The texture to display in the image widget.

        This must be a Texture object that has been loaded or created. The image
        will update automatically if the texture content changes. If no texture
        is set or the texture is invalid, the image will not be rendered.

        """
        ...


    @texture.setter
    def texture(self, value : Texture | None):
        ...


    @property
    def uv(self) -> list:
        """
        UV coordinates defining the region of the texture to display.

        A list of 4 values [u1, v1, u2, v2] that specify the texture coordinates
        to use for mapping the texture onto the image rectangle. This allows
        displaying only a portion of the texture.

        Default is [0.0, 0.0, 1.0, 1.0], which displays the entire texture.

        """
        ...


    @uv.setter
    def uv(self, value : list):
        ...


class InputText(uiItem):
    """
    A text input widget for single or multi-line text entry.

    InputText provides a field for text entry with various configuration options
    including character filtering, password input, and multiline support. The entered
    text is stored in a SharedStr value that can be accessed via the value property.

    The widget supports features like input validation, auto-selection, and custom
    behaviors for special keys like Tab, Enter and Escape. It can be configured
    with a hint text that appears when the field is empty, and can limit input to
    specific character types (decimals, hexadecimal, etc).

    For multiline text entry, enable the multiline property which creates a text
    area instead of a single-line field.

    """
    def __init__(self, context : Context, always_overwrite : bool = False, attach : Any = ..., auto_select_all : bool = False, before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callback_on_enter : bool = False, callbacks : Sequence[DCGCallable] = [], children : None  = [], ctrl_enter_for_new_line : bool = False, decimal : bool = False, enabled : bool = True, escape_clears_all : bool = False, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, hexadecimal : bool = False, hint : str = "", indent : float = 0.0, label : str = "", max_characters : int = 1024, multiline : bool = False, next_sibling : baseItemSubCls | None = None, no_horizontal_scroll : bool = False, no_newline : bool = False, no_scaling : bool = False, no_spaces : bool = False, no_undo_redo : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, password : bool = False, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, readonly : bool = False, scaling_factor : float = 1.0, scientific : bool = False, shareable_value : SharedStr = ..., show : bool = True, tab_input : bool = False, theme : Any = ..., uppercase : bool = False, user_data : Any = ..., value : str = "", width : float = 0.0):
        """
        Parameters
        ----------
        - always_overwrite: Enables overwrite mode for text input.
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - auto_select_all: Automatically selects the entire text when the field is first clicked.
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callback_on_enter: Triggers callback when Enter key is pressed, regardless of edit state.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - ctrl_enter_for_new_line: Reverses Enter and Ctrl+Enter behavior in multiline mode.
        - decimal: Restricts input to decimal numeric characters (0-9, +, -, .).
        - enabled: Whether the item is interactive and fully styled.
        - escape_clears_all: Makes Escape key clear the field's content instead of reverting changes.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - hexadecimal: Restricts input to hexadecimal characters (0-9, A-F, a-f).
        - hint: Placeholder text shown when the input field is empty.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - max_characters: Maximum number of characters allowed in the input field.
        - multiline: Whether the input field accepts multiple lines of text.
        - next_sibling: Child of the parent rendered just after this item.
        - no_horizontal_scroll: Prevents automatic horizontal scrolling as text is entered.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - no_spaces: Prevents spaces and tabs from being entered into the field.
        - no_undo_redo: Disables the undo/redo functionality for this input field.
        - parent: Parent of the item in the rendering tree.
        - password: Hides the input text by displaying asterisks and disables text copying.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - readonly: Makes the input field non-editable by the user.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - scientific: Restricts input to scientific notation characters (0-9, +, -, ., *, /, e, E).
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - tab_input: Allows tab key to insert a tab character into the text.
        - theme: Visual styling applied to this item and its children.
        - uppercase: Automatically converts lowercase letters (a-z) to uppercase (A-Z).
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    def configure(self, always_overwrite : bool = False, auto_select_all : bool = False, callback : DCGCallable | None = None, callback : DCGCallable | None = None, callback_on_enter : bool = False, callbacks : Sequence[DCGCallable] = [], children : None  = [], ctrl_enter_for_new_line : bool = False, decimal : bool = False, enabled : bool = True, escape_clears_all : bool = False, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, hexadecimal : bool = False, hint : str = "", indent : float = 0.0, label : str = "", max_characters : int = 1024, multiline : bool = False, next_sibling : baseItemSubCls | None = None, no_horizontal_scroll : bool = False, no_newline : bool = False, no_scaling : bool = False, no_spaces : bool = False, no_undo_redo : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, password : bool = False, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, readonly : bool = False, scaling_factor : float = 1.0, scientific : bool = False, shareable_value : SharedStr = ..., show : bool = True, tab_input : bool = False, theme : Any = ..., uppercase : bool = False, user_data : Any = ..., value : str = "", width : float = 0.0):
        """
        Configure the InputText widget with provided keyword arguments.

        Handles the 'max_characters' option before delegating to the parent class
        for standard configuration options.

        Parameters
        ----------
        - always_overwrite: Enables overwrite mode for text input.
        - auto_select_all: Automatically selects the entire text when the field is first clicked.
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callback_on_enter: Triggers callback when Enter key is pressed, regardless of edit state.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - ctrl_enter_for_new_line: Reverses Enter and Ctrl+Enter behavior in multiline mode.
        - decimal: Restricts input to decimal numeric characters (0-9, +, -, .).
        - enabled: Whether the item is interactive and fully styled.
        - escape_clears_all: Makes Escape key clear the field's content instead of reverting changes.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - hexadecimal: Restricts input to hexadecimal characters (0-9, A-F, a-f).
        - hint: Placeholder text shown when the input field is empty.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - max_characters: Maximum number of characters allowed in the input field.
        - multiline: Whether the input field accepts multiple lines of text.
        - next_sibling: Child of the parent rendered just after this item.
        - no_horizontal_scroll: Prevents automatic horizontal scrolling as text is entered.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - no_spaces: Prevents spaces and tabs from being entered into the field.
        - no_undo_redo: Disables the undo/redo functionality for this input field.
        - parent: Parent of the item in the rendering tree.
        - password: Hides the input text by displaying asterisks and disables text copying.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - readonly: Makes the input field non-editable by the user.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - scientific: Restricts input to scientific notation characters (0-9, +, -, ., *, /, e, E).
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - tab_input: Allows tab key to insert a tab character into the text.
        - theme: Visual styling applied to this item and its children.
        - uppercase: Automatically converts lowercase letters (a-z) to uppercase (A-Z).
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def activated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned to the active state this frame.

        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use
        event handlers instead as they provide more robust state tracking.

        """
        ...


    @property
    def active(self) -> bool:
        """
        (Read-only) Whether the item is in an active state.

        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.

        """
        ...


    @property
    def always_overwrite(self) -> bool:
        """
        Enables overwrite mode for text input.

        When enabled, typing in the input field will replace existing text
        rather than inserting new characters. This mimics the behavior of
        pressing the Insert key in many text editors, where the cursor
        overwrites characters instead of pushing them forward.

        """
        ...


    @always_overwrite.setter
    def always_overwrite(self, value : bool):
        ...


    @property
    def auto_select_all(self) -> bool:
        """
        Automatically selects the entire text when the field is first clicked.

        When enabled, clicking on the input field for the first time will
        select all of its content, making it easy to replace the entire text
        with a new entry. This is particularly useful for fields that contain
        default values that users are likely to change completely.

        """
        ...


    @auto_select_all.setter
    def auto_select_all(self, value : bool):
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def callback_on_enter(self) -> bool:
        """
        Triggers callback when Enter key is pressed, regardless of edit state.

        When enabled, the item's callback will be triggered whenever the Enter key
        is pressed while the input is focused, not just when the value changes.
        This is useful for creating form-like interfaces where Enter submits the
        current input.

        """
        ...


    @callback_on_enter.setter
    def callback_on_enter(self, value : bool):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def ctrl_enter_for_new_line(self) -> bool:
        """
        Reverses Enter and Ctrl+Enter behavior in multiline mode.

        When enabled in multiline mode, pressing Enter will submit the input,
        while Ctrl+Enter will insert a new line. This is the opposite of the
        default behavior where Enter inserts a new line and Ctrl+Enter submits.

        """
        ...


    @ctrl_enter_for_new_line.setter
    def ctrl_enter_for_new_line(self, value : bool):
        ...


    @property
    def deactivated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned from active to inactive this frame.

        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.

        """
        ...


    @property
    def deactivated_after_edited(self) -> bool:
        """
        (Read-only) Whether the item was edited and then deactivated in this frame.

        Useful for detecting when user completes an edit operation, such as
        finishing text input or adjusting a value. This property is only true
        for the frame when the deactivation occurs after editing.

        """
        ...


    @property
    def decimal(self) -> bool:
        """
        Restricts input to decimal numeric characters (0-9, +, -, .).

        When enabled, the input field will only allow characters suitable for
        entering decimal numbers. This is useful for creating numeric entry fields
        that don't require a full numeric widget.

        """
        ...


    @decimal.setter
    def decimal(self, value : bool):
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def edited(self) -> bool:
        """
        (Read-only) Whether the item's value was modified this frame.

        This flag indicates that the user has made a change to the item's value,
        such as typing in an input field or adjusting a slider. It is only true
        for the frame when the edit occurs.

        """
        ...


    @property
    def escape_clears_all(self) -> bool:
        """
        Makes Escape key clear the field's content instead of reverting changes.

        When enabled, pressing the Escape key will clear the entire text content
        if the field is not empty, or deactivate the field if it is empty.
        This differs from the default behavior where Escape reverts the field
        to its previous content.

        """
        ...


    @escape_clears_all.setter
    def escape_clears_all(self, value : bool):
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def hexadecimal(self) -> bool:
        """
        Restricts input to hexadecimal characters (0-9, A-F, a-f).

        When enabled, the input field will only allow characters suitable for
        entering hexadecimal numbers. This is useful for entering color codes,
        memory addresses, or other hexadecimal values.

        """
        ...


    @hexadecimal.setter
    def hexadecimal(self, value : bool):
        ...


    @property
    def hint(self) -> str:
        """
        Placeholder text shown when the input field is empty.

        This text appears in a light color when the input field contains no text,
        providing guidance to users about what should be entered. The hint is
        only available for single-line input fields and cannot be used with
        multiline mode.

        """
        ...


    @hint.setter
    def hint(self, value : str):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def max_characters(self) -> int:
        """
        Maximum number of characters allowed in the input field.

        This sets the capacity of the internal buffer used to store the text.
        The default is 1024 characters. If you need to store longer text,
        increase this value before adding text that would exceed it.

        """
        ...


    @max_characters.setter
    def max_characters(self, value : int):
        ...


    @property
    def multiline(self) -> bool:
        """
        Whether the input field accepts multiple lines of text.

        When enabled, the input field becomes a text area that can contain line
        breaks and supports multiple paragraphs. When multiline is enabled,
        hint text cannot be used.

        """
        ...


    @multiline.setter
    def multiline(self, value : bool):
        ...


    @property
    def no_horizontal_scroll(self) -> bool:
        """
        Prevents automatic horizontal scrolling as text is entered.

        When enabled, the input field will not automatically scroll horizontally
        when text exceeds the visible width. This can be useful for fields where
        you want users to be aware of the field's capacity limits visually.

        """
        ...


    @no_horizontal_scroll.setter
    def no_horizontal_scroll(self, value : bool):
        ...


    @property
    def no_spaces(self) -> bool:
        """
        Prevents spaces and tabs from being entered into the field.

        When enabled, the input field will reject space and tab characters,
        ensuring the text contains no whitespace. This is useful for fields
        that require compact, whitespace-free input like usernames or identifiers.

        """
        ...


    @no_spaces.setter
    def no_spaces(self, value : bool):
        ...


    @property
    def no_undo_redo(self) -> bool:
        """
        Disables the undo/redo functionality for this input field.

        When enabled, the field will not store the history of changes,
        preventing users from using undo (Ctrl+Z) or redo (Ctrl+Y) operations.
        This can be useful for fields where undoing operations might be
        confusing or undesirable.

        """
        ...


    @no_undo_redo.setter
    def no_undo_redo(self, value : bool):
        ...


    @property
    def password(self) -> bool:
        """
        Hides the input text by displaying asterisks and disables text copying.

        When enabled, all characters in the input field will be displayed as
        asterisks (*), hiding the actual content from view. This is useful for
        password entry fields or other sensitive information. Copy functionality
        is also disabled for security.

        """
        ...


    @password.setter
    def password(self, value : bool):
        ...


    @property
    def readonly(self) -> bool:
        """
        Makes the input field non-editable by the user.

        When enabled, the text field will display its content but prevent the
        user from modifying it. The content can still be updated programmatically
        through the value property. This is useful for displaying information
        that should not be altered by the user.

        """
        ...


    @readonly.setter
    def readonly(self, value : bool):
        ...


    @property
    def scientific(self) -> bool:
        """
        Restricts input to scientific notation characters (0-9, +, -, ., *, /, e, E).

        When enabled, the input field will only allow characters suitable for
        entering numbers in scientific notation. This is useful for fields that
        need to accept very large or small numbers in scientific format.

        """
        ...


    @scientific.setter
    def scientific(self, value : bool):
        ...


    @property
    def tab_input(self) -> bool:
        """
        Allows tab key to insert a tab character into the text.

        When enabled, pressing the Tab key will insert a tab character ('	')
        into the text field instead of moving focus to the next widget. This
        is particularly useful in multiline text areas where tab indentation
        is needed.

        """
        ...


    @tab_input.setter
    def tab_input(self, value : bool):
        ...


    @property
    def uppercase(self) -> bool:
        """
        Automatically converts lowercase letters (a-z) to uppercase (A-Z).

        When enabled, any lowercase letters entered into the field will be
        automatically converted to uppercase. This is useful for fields where
        standardized uppercase input is desired, such as product codes or
        reference numbers.

        """
        ...


    @uppercase.setter
    def uppercase(self, value : bool):
        ...


class InputValue(uiItem):
    """
    A widget for entering numeric values with optional step buttons.

    This versatile input widget accepts scalar or vector numeric values with support
    for different data types (int, float, double) and dimensions (1-4 components).
    It offers precise control over value ranges, step sizes, and formatting options.

    The widget can be configured with various input restrictions, keyboard behaviors,
    and visual settings to adapt to different use cases, from simple number entry
    to multi-dimensional vector editing.

    """
    def __init__(self, context : Context, always_overwrite : bool = False, attach : Any = ..., auto_select_all : bool = False, before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callback_on_enter : bool = False, callbacks : Sequence[DCGCallable] = [], children : None  = [], decimal : bool = False, empty_as_zero : bool = False, empty_if_zero : bool = False, enabled : bool = True, escape_clears_all : bool = False, focused : bool = False, font : Font = None, format : str = "float", handlers : list = [], height : float = 0.0, hexadecimal : bool = False, indent : float = 0.0, label : str = "", max_value : float = inf, min_value : float = -inf, next_sibling : baseItemSubCls | None = None, no_horizontal_scroll : bool = False, no_newline : bool = False, no_scaling : bool = False, no_undo_redo : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, password : bool = False, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, print_format : str = "%.3f", readonly : bool = False, scaling_factor : float = 1.0, scientific : bool = False, shareable_value : SharedFloat = ..., show : bool = True, size : int = 1, step : float = 0.1, step_fast : float = 1.0, theme : Any = ..., user_data : Any = ..., value : float = 0.0, width : float = 0.0):
        """
        Parameters
        ----------
        - always_overwrite: Enables overwrite mode for text input.
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - auto_select_all: Automatically selects all content when the field is first focused.
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callback_on_enter: Triggers callback when Enter key is pressed.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - decimal: Restricts input to decimal numeric characters.
        - empty_as_zero: Treats empty input fields as zero values.
        - empty_if_zero: Displays an empty field when the value is zero.
        - enabled: Whether the item is interactive and fully styled.
        - escape_clears_all: Makes Escape key clear the field's content.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - format: Format of the input data type.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - hexadecimal: Restricts input to hexadecimal characters.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - max_value: Maximum value the input will be clamped to.
        - min_value: Minimum value the input will be clamped to.
        - next_sibling: Child of the parent rendered just after this item.
        - no_horizontal_scroll: Disables automatic horizontal scrolling during input.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - no_undo_redo: Disables the undo/redo functionality for this input field.
        - parent: Parent of the item in the rendering tree.
        - password: Hides the input by displaying asterisks and disables copying.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - print_format: Format string for displaying the numeric value.
        - readonly: Makes the input field non-editable by the user.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - scientific: Restricts input to scientific notation characters.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - size: Number of components controlled by the input widget.
        - step: Step size for incrementing/decrementing the value with buttons.
        - step_fast: Fast step size for quick incrementing/decrementing with modifier keys.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    def configure(self, always_overwrite : bool = False, auto_select_all : bool = False, callback : DCGCallable | None = None, callback : DCGCallable | None = None, callback_on_enter : bool = False, callbacks : Sequence[DCGCallable] = [], children : None  = [], decimal : bool = False, empty_as_zero : bool = False, empty_if_zero : bool = False, enabled : bool = True, escape_clears_all : bool = False, focused : bool = False, font : Font = None, format : str = "float", handlers : list = [], height : float = 0.0, hexadecimal : bool = False, indent : float = 0.0, label : str = "", max_value : float = inf, min_value : float = -inf, next_sibling : baseItemSubCls | None = None, no_horizontal_scroll : bool = False, no_newline : bool = False, no_scaling : bool = False, no_undo_redo : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, password : bool = False, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, print_format : str = "%.3f", readonly : bool = False, scaling_factor : float = 1.0, scientific : bool = False, shareable_value : SharedFloat = ..., show : bool = True, size : int = 1, step : float = 0.1, step_fast : float = 1.0, theme : Any = ..., user_data : Any = ..., value : float = 0.0, width : float = 0.0):
        """
        Configure the InputValue widget with provided keyword arguments.

        Handles special configuration options that have interdependencies
        (format, size) before delegating to the parent class for standard
        options.

        Parameters
        ----------
        - always_overwrite: Enables overwrite mode for text input.
        - auto_select_all: Automatically selects all content when the field is first focused.
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callback_on_enter: Triggers callback when Enter key is pressed.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - decimal: Restricts input to decimal numeric characters.
        - empty_as_zero: Treats empty input fields as zero values.
        - empty_if_zero: Displays an empty field when the value is zero.
        - enabled: Whether the item is interactive and fully styled.
        - escape_clears_all: Makes Escape key clear the field's content.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - format: Format of the input data type.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - hexadecimal: Restricts input to hexadecimal characters.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - max_value: Maximum value the input will be clamped to.
        - min_value: Minimum value the input will be clamped to.
        - next_sibling: Child of the parent rendered just after this item.
        - no_horizontal_scroll: Disables automatic horizontal scrolling during input.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - no_undo_redo: Disables the undo/redo functionality for this input field.
        - parent: Parent of the item in the rendering tree.
        - password: Hides the input by displaying asterisks and disables copying.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - print_format: Format string for displaying the numeric value.
        - readonly: Makes the input field non-editable by the user.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - scientific: Restricts input to scientific notation characters.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - size: Number of components controlled by the input widget.
        - step: Step size for incrementing/decrementing the value with buttons.
        - step_fast: Fast step size for quick incrementing/decrementing with modifier keys.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def activated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned to the active state this frame.

        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use
        event handlers instead as they provide more robust state tracking.

        """
        ...


    @property
    def active(self) -> bool:
        """
        (Read-only) Whether the item is in an active state.

        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.

        """
        ...


    @property
    def always_overwrite(self) -> bool:
        """
        Enables overwrite mode for text input.

        When enabled, typing in the input field will replace existing text at
        the cursor position rather than inserting new characters. This mimics
        the behavior of pressing the Insert key in many text editors.

        """
        ...


    @always_overwrite.setter
    def always_overwrite(self, value : bool):
        ...


    @property
    def auto_select_all(self) -> bool:
        """
        Automatically selects all content when the field is first focused.

        When enabled, clicking on the input field for the first time will
        select all of its content, making it easy to replace the entire value
        with a new entry.

        """
        ...


    @auto_select_all.setter
    def auto_select_all(self, value : bool):
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def callback_on_enter(self) -> bool:
        """
        Triggers callback when Enter key is pressed.

        When enabled, the widget's callback will be triggered whenever the user
        presses Enter, regardless of whether the value has changed. This is
        useful for form-like interfaces where Enter submits the current input.

        """
        ...


    @callback_on_enter.setter
    def callback_on_enter(self, value : bool):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def deactivated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned from active to inactive this frame.

        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.

        """
        ...


    @property
    def decimal(self) -> bool:
        """
        Restricts input to decimal numeric characters.

        When enabled, only characters valid for decimal numbers (0-9, +, -, .)
        will be accepted, filtering out any other input.

        """
        ...


    @decimal.setter
    def decimal(self, value : bool):
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def edited(self) -> bool:
        """
        (Read-only) Whether the item's value was modified this frame.

        This flag indicates that the user has made a change to the item's value,
        such as typing in an input field or adjusting a slider. It is only true
        for the frame when the edit occurs.

        """
        ...


    @property
    def empty_as_zero(self) -> bool:
        """
        Treats empty input fields as zero values.

        When enabled, an empty input field will be interpreted as having a value
        of zero rather than being treated as invalid input or retaining the
        previous value.

        """
        ...


    @empty_as_zero.setter
    def empty_as_zero(self, value : bool):
        ...


    @property
    def empty_if_zero(self) -> bool:
        """
        Displays an empty field when the value is zero.

        When enabled, a value of exactly zero will be displayed as an empty
        field rather than showing "0". This is useful for cleaner interfaces
        where zero is the default state.

        """
        ...


    @empty_if_zero.setter
    def empty_if_zero(self, value : bool):
        ...


    @property
    def escape_clears_all(self) -> bool:
        """
        Makes Escape key clear the field's content.

        When enabled, pressing the Escape key will clear all text if the field
        is not empty, or deactivate the field if it is empty. This differs from
        the default behavior where Escape reverts to the previous value.

        """
        ...


    @escape_clears_all.setter
    def escape_clears_all(self, value : bool):
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def format(self) -> str:
        """
        Format of the input data type.

        Must be "int", "float" or "double". Note that float here means the
        32 bits version. The python float corresponds to a double.

        Changing this value will reallocate the internal value storage.

        """
        ...


    @format.setter
    def format(self, value : str):
        ...


    @property
    def hexadecimal(self) -> bool:
        """
        Restricts input to hexadecimal characters.

        When enabled, only characters valid for hexadecimal numbers
        (0-9, A-F, a-f) will be accepted, filtering out any other input.

        """
        ...


    @hexadecimal.setter
    def hexadecimal(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def max_value(self) -> float:
        """
        Maximum value the input will be clamped to.

        This defines the upper bound of the acceptable range for the input.
        Any value above this will be automatically clamped to this maximum.
        Use INFINITY to specify no upper bound.

        """
        ...


    @max_value.setter
    def max_value(self, value : float):
        ...


    @property
    def min_value(self) -> float:
        """
        Minimum value the input will be clamped to.

        This defines the lower bound of the acceptable range for the input.
        Any value below this will be automatically clamped to this minimum.
        Use -INFINITY to specify no lower bound.

        """
        ...


    @min_value.setter
    def min_value(self, value : float):
        ...


    @property
    def no_horizontal_scroll(self) -> bool:
        """
        Disables automatic horizontal scrolling during input.

        When enabled, the input field will not automatically scroll horizontally
        when text exceeds the visible width. This can be useful for fields where
        you want users to be aware of the field's capacity limits visually.

        """
        ...


    @no_horizontal_scroll.setter
    def no_horizontal_scroll(self, value : bool):
        ...


    @property
    def no_undo_redo(self) -> bool:
        """
        Disables the undo/redo functionality for this input field.

        When enabled, the field will not store the history of changes,
        preventing users from using undo (Ctrl+Z) or redo (Ctrl+Y) operations.
        This can reduce memory usage for frequently changed values.

        """
        ...


    @no_undo_redo.setter
    def no_undo_redo(self, value : bool):
        ...


    @property
    def password(self) -> bool:
        """
        Hides the input by displaying asterisks and disables copying.

        When enabled, all characters will be displayed as asterisks (*), hiding
        the actual content from view. This is useful for password entry or other
        sensitive numeric information.

        """
        ...


    @password.setter
    def password(self, value : bool):
        ...


    @property
    def print_format(self) -> str:
        """
        Format string for displaying the numeric value.

        Uses printf-style formatting to control how the value is displayed.
        Example formats: "%d" for integers, "%.2f" for floats with 2 decimal
        places, etc.

        """
        ...


    @print_format.setter
    def print_format(self, value : str):
        ...


    @property
    def readonly(self) -> bool:
        """
        Makes the input field non-editable by the user.

        When enabled, the input will display its current value but users cannot
        modify it. The value can still be updated programmatically through the
        value property.

        """
        ...


    @readonly.setter
    def readonly(self, value : bool):
        ...


    @property
    def scientific(self) -> bool:
        """
        Restricts input to scientific notation characters.

        When enabled, only characters valid for scientific notation
        (0-9, +, -, ., *, /, e, E) will be accepted, suitable for entering
        numbers in scientific format.

        """
        ...


    @scientific.setter
    def scientific(self, value : bool):
        ...


    @property
    def size(self) -> int:
        """
        Number of components controlled by the input widget.

        Can be 1, 2, 3 or 4. When size is 1, the item's value is held with a
        scalar shared value. For sizes greater than 1, the value is held with a
        vector of 4 elements (even for size 2 and 3).

        Changing this value will reallocate the internal value storage.

        """
        ...


    @size.setter
    def size(self, value : int):
        ...


    @property
    def step(self) -> float:
        """
        Step size for incrementing/decrementing the value with buttons.

        When step buttons are shown, clicking them will adjust the value by
        this amount. The step value is applied according to the current format
        (int, float, double).

        """
        ...


    @step.setter
    def step(self, value : float):
        ...


    @property
    def step_fast(self) -> float:
        """
        Fast step size for quick incrementing/decrementing with modifier keys.

        When using keyboard or clicking step buttons with modifier keys held,
        this larger step value will be used for quicker adjustments.

        """
        ...


    @step_fast.setter
    def step_fast(self, value : float):
        ...


class KeyDownHandler(baseHandler):
    """
    Handler that triggers when a key is held down.

    Properties:
        key (Key): Target key to monitor.

    Callback receives:
        - key: The key being pressed
        - duration: How long the key has been held down

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, key : Key = 525, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - key: The key that this handler is monitoring.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


    @property
    def key(self) -> Key:
        """
        The key that this handler is monitoring.

        """
        ...


    @key.setter
    def key(self, value : Key):
        ...


class KeyPressHandler(baseHandler):
    """
    Handler that triggers when a key is initially pressed.

    Properties:
        key (Key): Target key to monitor
        repeat (bool): Whether to trigger repeatedly while key is held

    Callback receives:
        - key: The key that was pressed

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, key : Key = 525, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, repeat : bool = True, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - key: The key that this handler is monitoring.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - repeat: Whether to trigger repeatedly while a key is held down.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


    @property
    def key(self) -> Key:
        """
        The key that this handler is monitoring.

        """
        ...


    @key.setter
    def key(self, value : Key):
        ...


    @property
    def repeat(self) -> bool:
        """
        Whether to trigger repeatedly while a key is held down.

        When True, the callback will be called multiple times as keys remain pressed.
        When False, the callback is only called once when the key is initially pressed.

        """
        ...


    @repeat.setter
    def repeat(self, value : bool):
        ...


class KeyReleaseHandler(baseHandler):
    """
    Handler that triggers when a key is released.

    Properties:
        key (Key): Target key to monitor

    Callback receives:
        - key: The key that was released

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, key : Key = 525, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - key: The key that this handler is monitoring.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


    @property
    def key(self) -> Key:
        """
        The key that this handler is monitoring.

        """
        ...


    @key.setter
    def key(self, value : Key):
        ...


class Layout(uiItem):
    """
    A layout is a group of elements organized together.

    The layout states correspond to the OR of all the item states, and the rect
    size corresponds to the minimum rect containing all the items. The position
    of the layout is used to initialize the default position for the first item.
    For example setting indent will shift all the items of the Layout.

    Subclassing Layout:
    For custom layouts, you can use Layout with a callback. The callback is
    called whenever the layout should be updated.

    If the automated update detection is not sufficient, update_layout() can be
    called to force a recomputation of the layout.

    Currently the update detection detects a change in the size of the remaining
    content area available locally within the window, or if the last item has
    changed.

    The layout item works by changing the positioning policy and the target
    position of its children, and thus there is no guarantee that the user set
    positioning and position states of the children are preserved.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : Sequence[uiItemSubCls] = [], enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedValue = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : Any = ..., width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    def update_layout(self):
        """
        Force an update of the layout next time the scene is rendered.

        This method triggers the recalculation of item positions and sizes
        within the layout. It's useful when the automated update detection
        is not sufficient to detect layout changes.

        """
        ...


    @property
    def activated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned to the active state this frame.

        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use
        event handlers instead as they provide more robust state tracking.

        """
        ...


    @property
    def active(self) -> bool:
        """
        (Read-only) Whether the item is in an active state.

        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.

        """
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def content_pos(self) -> Coord:
        """
        (Read-only) Position of the content area's top-left corner.

        This property provides the viewport-relative coordinates of the starting
        point for an item's content area. This is where child elements begin to be
        placed by default.

        Used together with content_region_avail, this defines the rectangle
        available for child elements.

        """
        ...


    @property
    def content_region_avail(self) -> Coord:
        """
        (Read-only) Available space for child items.

        For container items like windows, child windows, this
        property represents the available space for placing child items. This is
        the item's inner area after accounting for padding, borders, and other
        non-content elements.

        Areas that require scrolling to see are not included in this measurement.

        """
        ...


    @property
    def deactivated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned from active to inactive this frame.

        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.

        """
        ...


    @property
    def deactivated_after_edited(self) -> bool:
        """
        (Read-only) Whether the item was edited and then deactivated in this frame.

        Useful for detecting when user completes an edit operation, such as
        finishing text input or adjusting a value. This property is only true
        for the frame when the deactivation occurs after editing.

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def edited(self) -> bool:
        """
        (Read-only) Whether the item's value was modified this frame.

        This flag indicates that the user has made a change to the item's value,
        such as typing in an input field or adjusting a slider. It is only true
        for the frame when the edit occurs.

        """
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def toggled(self) -> bool:
        """
        (Read-only) Whether the item was just toggled open this frame.

        Applies to items that can be expanded or collapsed, such as tree nodes,
        collapsing headers, or menus. This property is only true during the frame
        when the toggle from closed to open occurs.

        """
        ...


class ListBox(uiItem):
    """
    A scrollable list of selectable text items with single selection support.

    ListBox provides a way to display a list of selectable strings in a scrollable
    container. Users can select a single item from the list, which is then stored
    in the item's value property.

    The list height can be controlled by setting the num_items_shown_when_open
    property, which determines how many items are visible before scrolling is
    required. When an item is selected, the widget's value is updated to contain
    the text of the selected item.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : None  = [], enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, items : list = [], label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, num_items_shown_when_open : int = -1, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedStr = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : str = "", width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - items: List of text values from which the user can select.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - num_items_shown_when_open: Number of items visible in the listbox before scrolling is required.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def edited(self) -> bool:
        """
        (Read-only) Whether the item's value was modified this frame.

        This flag indicates that the user has made a change to the item's value,
        such as typing in an input field or adjusting a slider. It is only true
        for the frame when the edit occurs.

        """
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def items(self) -> list:
        """
        List of text values from which the user can select.

        This property contains all available options that will be displayed in the
        listbox. If the value of the listbox is not in this list, no item will
        appear selected. When the list is first created and the value is not yet
        set, the first item in this list (if any) will be automatically selected.

        """
        ...


    @items.setter
    def items(self, value : list):
        ...


    @property
    def num_items_shown_when_open(self) -> int:
        """
        Number of items visible in the listbox before scrolling is required.

        This controls the height of the listbox widget. If set to -1 (default),
        the listbox will show up to 7 items or the total number of items if less
        than 7. Setting a specific positive value will display that many items
        at once, with scrolling enabled for additional items.

        """
        ...


    @num_items_shown_when_open.setter
    def num_items_shown_when_open(self, value : int):
        ...


class LostFocusHandler(baseHandler):
    """
    Handler for when windows or sub-windows lose
    focus.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class LostHoverHandler(baseHandler):
    """
    Handler that calls the callback the first
    frame when the target item was hovered, but
    is not anymore.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class LostMouseOverHandler(baseHandler):
    """
Prefer LostHoverHandler unless you really need to (see MouseOverHandler)

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class LostRenderHandler(baseHandler):
    """
    Handler that only calls the
    callback when the item switches from a
    rendered to non-rendered state. Note
    that when an item is not rendered, subsequent
    frames will not run handlers. Only the first time
    an item is non-rendered will trigger the handlers.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class Menu(uiItem):
    """
A Menu creates a menu container within a menu bar.

    Menus are used to organize menu items and sub-menus within a menu bar. They
    provide a hierarchical structure for your application's command system. Each
    menu can contain multiple menu items or other menus.

    Menus must be created within a MenuBar or as a child of another Menu.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : Sequence[uiItemSubCls] = [], enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedBool = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : bool = False, width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def activated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned to the active state this frame.

        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use
        event handlers instead as they provide more robust state tracking.

        """
        ...


    @property
    def active(self) -> bool:
        """
        (Read-only) Whether the item is in an active state.

        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.

        """
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def deactivated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned from active to inactive this frame.

        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def toggled(self) -> bool:
        """
        (Read-only) Whether the item was just toggled open this frame.

        Applies to items that can be expanded or collapsed, such as tree nodes,
        collapsing headers, or menus. This property is only true during the frame
        when the toggle from closed to open occurs.

        """
        ...


class MenuBar(uiItem):
    """
    A horizontal container for menu items at the top of a window.

    MenuBar creates a horizontal area at the top of a window where menu items and
    other interactive controls can be placed. It can function as either a main
    menu bar (attached to the application window) or as a child menu bar within
    another window.

    MenuBars can contain Menu widgets, which in turn can contain MenuItem widgets
    to create dropdown menus. They automatically adapt to different window sizes
    and can be styled using themes.

    When placed directly under the viewport, the MenuBar becomes a main menu bar
    that appears at the top of the application window. When placed within another
    window, it creates a local menu bar for that window.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : Sequence[uiItemSubCls] = [], enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, parent : Viewport | WindowSubCls | ChildWindowSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedValue = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : Any = ..., width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def content_pos(self) -> Coord:
        """
        (Read-only) Position of the content area's top-left corner.

        This property provides the viewport-relative coordinates of the starting
        point for an item's content area. This is where child elements begin to be
        placed by default.

        Used together with content_region_avail, this defines the rectangle
        available for child elements.

        """
        ...


    @property
    def content_region_avail(self) -> Coord:
        """
        (Read-only) Available space for child items.

        For container items like windows, child windows, this
        property represents the available space for placing child items. This is
        the item's inner area after accounting for padding, borders, and other
        non-content elements.

        Areas that require scrolling to see are not included in this measurement.

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


class MenuItem(uiItem):
    """
    A clickable menu item that can be used inside Menu components.

    MenuItem represents a clickable option in a dropdown menu or context menu.
    It can be configured to display a checkmark and keyboard shortcut hint,
    making it suitable for commands and toggleable options.

    Menu items can be checked/unchecked to represent binary states, and can
    display shortcut text to inform users of keyboard alternatives. When clicked,
    menu items trigger their callback function and update their associated
    SharedBool value.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], check : bool = False, children : None  = [], enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedBool = ..., shortcut : str = "", show : bool = True, theme : Any = ..., user_data : Any = ..., value : bool = False, width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - check: Whether the menu item displays a checkmark.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - shortcut: Text displayed on the right side of the menu item as a shortcut hint.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def activated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned to the active state this frame.

        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use
        event handlers instead as they provide more robust state tracking.

        """
        ...


    @property
    def active(self) -> bool:
        """
        (Read-only) Whether the item is in an active state.

        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.

        """
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def check(self) -> bool:
        """
        Whether the menu item displays a checkmark.

        When enabled, the menu item shows a checkmark that reflects the state
        of the associated value. This is useful for options that can be toggled
        on and off. The checkmark state is controlled through the item's value
        property.

        """
        ...


    @check.setter
    def check(self, value : bool):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def deactivated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned from active to inactive this frame.

        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.

        """
        ...


    @property
    def deactivated_after_edited(self) -> bool:
        """
        (Read-only) Whether the item was edited and then deactivated in this frame.

        Useful for detecting when user completes an edit operation, such as
        finishing text input or adjusting a value. This property is only true
        for the frame when the deactivation occurs after editing.

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def edited(self) -> bool:
        """
        (Read-only) Whether the item's value was modified this frame.

        This flag indicates that the user has made a change to the item's value,
        such as typing in an input field or adjusting a slider. It is only true
        for the frame when the edit occurs.

        """
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def shortcut(self) -> str:
        """
        Text displayed on the right side of the menu item as a shortcut hint.

        This text provides a visual indicator of keyboard shortcuts associated
        with this menu command. The shortcut is not functional by itself - it
        only displays text to inform the user. Actual keyboard shortcut handling
        must be implemented separately.

        Common formats include "Ctrl+S" or "Alt+F4".

        """
        ...


    @shortcut.setter
    def shortcut(self, value : str):
        ...


class MotionHandler(baseHandler):
    """
    Handler that calls the callback when
    the target item is moved relative to
    the positioning reference (by default the parent)

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: positioning policy used as reference for the motion
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


    @property
    def pos_policy(self) -> tuple[Positioning, Positioning]:
        """positioning policy used as reference for the motion

        REL_PARENT: motion relative to the parent
        REL_WINDOW: motion relative to the window
        REL_VIEWPORT: motion relative to the viewport
        DEFAULT: Disabled motion detection for the axis

        pos_policy is a tuple of Positioning where the
        first element refers to the x axis and the second
        to the y axis

        Defaults to REL_PARENT on both axes.

        """
        ...


    @pos_policy.setter
    def pos_policy(self, value : tuple[Positioning, Positioning]):
        ...


class MouseClickHandler(baseHandler):
    """
    Handler for mouse button clicks anywhere.

    Properties:
        button (MouseButton): Target mouse button to monitor
        repeat (bool): Whether to trigger repeatedly while button held

    Callback receives:
        - button: The button that was clicked

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., button : MouseButton = 0, callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, repeat : bool = False, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - button: The mouse button that this handler is monitoring.
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - repeat: Whether to trigger repeatedly while a mouse button is held down.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


    @property
    def button(self) -> MouseButton:
        """
        The mouse button that this handler is monitoring.

        """
        ...


    @button.setter
    def button(self, value : MouseButton):
        ...


    @property
    def repeat(self) -> bool:
        """
        Whether to trigger repeatedly while a mouse button is held down.

        When True, the callback will be called multiple times as the button remains pressed.
        When False, the callback is only called once when the button is initially clicked.

        """
        ...


    @repeat.setter
    def repeat(self, value : bool):
        ...


class MouseCursorHandler(baseHandler):
    """
    Since the mouse cursor is reset every frame,
    this handler is used to set the cursor automatically
    the frames where this handler is run.
    Typical usage would be in a ConditionalHandler,
    combined with a HoverHandler.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], cursor : MouseCursor = 0, enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - cursor: Change the mouse cursor to one of MouseCursor,
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


    @property
    def cursor(self) -> MouseCursor:
        """
        Change the mouse cursor to one of MouseCursor,
        but only for the frames where this handler
        is run.

        """
        ...


    @cursor.setter
    def cursor(self, value : MouseCursor):
        ...


class MouseDoubleClickHandler(baseHandler):
    """
    Handler for mouse button double-clicks anywhere.

    Properties:
        button (MouseButton): Target mouse button to monitor

    Callback receives:
        - button: The button that was double-clicked

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., button : MouseButton = 0, callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - button: The button this handler monitors.
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


    @property
    def button(self) -> MouseButton:
        """
        The button this handler monitors.

        """
        ...


    @button.setter
    def button(self, value : MouseButton):
        ...


class MouseDownHandler(baseHandler):
    """
    Handler for mouse button being held down.

    Properties:
        button (MouseButton): Target mouse button to monitor

    Callback receives:
        - button: The button being held
        - duration: How long the button has been held

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., button : MouseButton = 0, callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - button: The button this handler monitors.
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


    @property
    def button(self) -> MouseButton:
        """
        The button this handler monitors.

        """
        ...


    @button.setter
    def button(self, value : MouseButton):
        ...


class MouseDragHandler(baseHandler):
    """
    Handler for mouse dragging motions.

    Properties:
        button (MouseButton): Target mouse button for drag
        threshold (float): Movement threshold to trigger drag.
                         Negative means use default.

    Callback receives:
        - button: The button used for dragging
        - delta_x: Horizontal drag distance
        - delta_y: Vertical drag distance

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., button : MouseButton = 0, callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, threshold : float = -1.0, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - button: The button this handler monitors.
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - threshold: The movement threshold to trigger a drag.
        - user_data: User data of any type.
        """
        ...


    @property
    def button(self) -> MouseButton:
        """
        The button this handler monitors.

        """
        ...


    @button.setter
    def button(self, value : MouseButton):
        ...


    @property
    def threshold(self) -> float:
        """
        The movement threshold to trigger a drag.
        If negative, uses the default threshold.

        """
        ...


    @threshold.setter
    def threshold(self, value : float):
        ...


class MouseInRect(baseHandler):
    """
    Handler that triggers when the mouse is inside a predefined rectangle.

    The rectangle is defined in viewport coordinates.

    Properties:
        rect: A tuple (x1, y1, x2, y2) or Rect object defining the area to monitor

    Callback receives:
        - x: Current mouse x position
        - y: Current mouse y position

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, rect : Rect = (0.0, 0.0, 0.0, 0.0), show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - rect: Rectangle to test in viewport coordinates
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


    @property
    def rect(self) -> Rect:
        """Rectangle to test in viewport coordinates
        """
        ...


    @rect.setter
    def rect(self, value : Rect):
        ...


class MouseMoveHandler(baseHandler):
    """
    Handler that triggers when the mouse cursor moves.

    Callback receives:
        - x: New mouse x position
        - y: New mouse y position

    Note:
        Position is relative to the viewport.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class MouseOverHandler(baseHandler):
    """
Prefer HoverHandler unless you really need to (see below)

    Handler that calls the callback when
    the mouse is over the item. In most cases,
    this is equivalent to HoverHandler,
    with the difference that a single item
    is considered hovered, while in
    some specific cases, several items could
    have the mouse above them.

    Prefer using HoverHandler for general use,
    and reserve MouseOverHandler for custom
    drag & drop operations.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class MouseReleaseHandler(baseHandler):
    """
    Handler for mouse button releases.

    Properties:
        button (MouseButton): Target mouse button to monitor

    Callback receives:
        - button: The button that was released

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., button : MouseButton = 0, callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - button: The button this handler monitors.
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


    @property
    def button(self) -> MouseButton:
        """
        The button this handler monitors.

        """
        ...


    @button.setter
    def button(self, value : MouseButton):
        ...


class MouseWheelHandler(baseHandler):
    """
    A handler that monitors mouse wheel scrolling events.

    Detects both vertical (default) and horizontal scrolling movements.
    For horizontal scrolling, either use Shift+vertical wheel or a horizontal
    wheel if available on the input device.

    Properties:
        horizontal (bool): When True, monitors horizontal scrolling instead of vertical.
                         Defaults to False (vertical scrolling).

    Note:
        Holding Shift while using vertical scroll wheel generates horizontal scroll events.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, horizontal : bool = False, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - horizontal: Whether to look at the horizontal wheel
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


    @property
    def horizontal(self) -> bool:
        """
        Whether to look at the horizontal wheel
        instead of the vertical wheel.

        NOTE: Shift+ vertical wheel => horizontal wheel

        """
        ...


    @horizontal.setter
    def horizontal(self, value : bool):
        ...


class OpenHandler(baseHandler):
    """
    Handler that triggers the callback when the
    item is in an opened state.
    Here Close/Open refers to being in a
    reduced state when the full content is not
    shown, but could be if the user clicked on
    a specific button. The doesn't mean that
    the object is show or not shown.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class OtherItemHandler(HandlerList):
    """
    A handler that monitors states from a different item than the one it's attached to.

    This handler allows checking states of an item different from its attachment point,
    while still sending callbacks with the attached item as the target.

    Use cases:
    - Combining states between different items (AND/OR operations)
    - Monitoring items that might not be rendered
    - Creating dependencies between different interface elements

    Note:
        Callbacks still reference the attached item as target, not the monitored item.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : Sequence[baseHandlerSubCls] = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, op : HandlerListOP = 0, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, target : Any = ..., user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - op: HandlerListOP that defines which condition
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - target: Target item which state will be used
        - user_data: User data of any type.
        """
        ...


    @property
    def target(self):
        """
        Target item which state will be used
        for children handlers.

        """
        ...


    @target.setter
    def target(self, value):
        ...


class Pattern(baseItem):
    """
    Defines a repeating pattern for outlining shapes.

    A pattern consists of a texture that gets sampled along the outline path,
    with configurable sampling behavior. The texture is applied in GL_REPEAT mode.

    The x-coordinate of the texture is sampled along the path of the outline,
    while the y-coordinate is sampled across the width of the outline (from
    interior to exterior).

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : Sequence[baseItemSubCls] = [], next_sibling : baseItemSubCls | None = None, parent : baseItemSubCls | None = None, previous_sibling : baseItemSubCls | None = None, scale_factor : float = 1.0, screen_space : bool = False, texture : Texture | None = None, user_data : Any = ..., x_mode : str = "points"):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - scale_factor: Scaling factor for the pattern repetition.
        - screen_space: Whether the 'length' mode is in screen space (pixels) or coordinate space.
        - texture: Texture to use for the pattern.
        - user_data: User data of any type.
        - x_mode: How to sample the x-coordinate of the texture.
        """
        ...


    def checkerboard(context, cell_size=5, stripe_width=1, upscale_factor=64, opaque=False, **kwargs):
        """
        Creates a checkerboard pattern with white stripes borders.

        Args:
            context: The DearCyGui context
            cell_size: Size of each square cell in pixels
            stripe_width: Width of white stripes borders (applied to both sides)
            upscale_factor: Factor to upscale the pattern for better quality (default: 8)
            opaque: Whether black squares should be opaque (True) or transparent (False)

        Returns:
            Pattern: A checkerboard pattern with white stripes

        """
        ...


    def dash_dot(context, dash_length=10, dot_size=2, spacing=5, upscale_factor=64, opaque=False, **kwargs):
        """
        Creates a dash-dot-dash pattern (commonly used in technical drawings).

        Args:
            context: The DearCyGui context
            dash_length: Length of each dash in pixels
            dot_size: Size of each dot in pixels
            spacing: Spacing between elements in pixels
            upscale_factor: Upscaling factor for the pattern
            opaque: Whether gaps should be black (True) or transparent (False)

        Returns:
            Pattern: A dash-dot pattern

        """
        ...


    def dash_dot_dot(context, dash_length=10, dot_size=2, spacing=5, upscale_factor=64, opaque=False, **kwargs):
        """
        Creates a dash-dot-dot pattern with one dash followed by two dots.

        Args:
            context: The DearCyGui context
            dash_length: Length of the dash in pixels
            dot_size: Size of each dot in pixels
            spacing: Spacing between elements in pixels
            upscale_factor: Upscaling factor for the pattern
            opaque: Whether gaps should be black (True) or transparent (False)

        Returns:
            Pattern: A dash-dot-dot pattern

        """
        ...


    def dashed(context, dash_length=10, gap_length=10, upscale_factor=32, opaque=False, **kwargs):
        """
        Creates a dashed line pattern.

        Args:
            context: The DearCyGui context
            dash_length: Length of the dash in pixels
            gap_length: Length of the gap in pixels
            upscale_factor: Upscaling factor for the pattern
            opaque: Whether gaps should be black (True) or transparent (False)

        Returns:
            Pattern: A dashed line pattern

        """
        ...


    def dotted(context, dot_size=2, spacing=8, upscale_factor=64, opaque=False, **kwargs):
        """
        Creates a dotted line pattern.

        Args:
            context: The DearCyGui context
            dot_size: Size of each dot in pixels
            spacing: Total spacing between dots in pixels
            upscale_factor: Upscaling factor for the pattern
            opaque: Whether gaps should be black (True) or transparent (False)

        Returns:
            Pattern: A dotted line pattern

        """
        ...


    def double_dash(context, dash_length=10, gap_length=5, dash_width=2, upscale_factor=64, opaque=False, **kwargs):
        """
        Creates a double-dashed line pattern with two parallel dashed lines.

        Args:
            context: The DearCyGui context
            dash_length: Length of each dash in pixels
            gap_length: Length of the gap between dashes in pixels
            dash_width: Width of each dash line in pixels
            opaque: Whether gaps should be black (True) or transparent (False)

        Returns:
            Pattern: A double-dashed pattern

        """
        ...


    def from_array(context, array, upscale_factor=1, antialiased=True, **kwargs):
        """
        Creates a pattern from a provided array with optional upscaling.

        The upscaling maintains the sharp edges of the original pattern, while the
        mipmapping system handles antialiasing when the pattern is displayed at
        different scales.

        Args:
            context: The DearCyGui context
            array: Source array defining the pattern (1D or 2D with 4th dimension as RGBA)
            upscale_factor: Integer factor to upscale the pattern (must be >= 1)
            antialiased: Whether to enable mipmapping for antialiasing
            **kwargs: Additional arguments passed to Pattern constructor

        Returns:
            Pattern: A pattern using the provided array data

        """
        ...


    def railroad(context, track_width=4, tie_width=10, tie_spacing=10, upscale_factor=64, opaque=False, **kwargs):
        """
        Creates a railroad track pattern with parallel lines and perpendicular ties.

        Args:
            context: The DearCyGui context
            track_width: Width between the parallel lines in pixels
            tie_width: Width of the perpendicular ties in pixels
            tie_spacing: Spacing between ties in pixels
            opaque: Whether gaps should be black (True) or transparent (False)

        Returns:
            Pattern: A railroad track pattern

        """
        ...


    def solid(context, **kwargs):
        """
        Creates a solid line pattern (no pattern).

        This is equivalent to not using a pattern at all.

        Args:
            context: The DearCyGui context

        Returns:
            Pattern: A solid pattern

        """
        ...


    @property
    def scale_factor(self) -> float:
        """
        Scaling factor for the pattern repetition.

        For 'points' mode: controls how many repetitions per segment
        For 'length' mode: controls how many repetitions per pixel

        Note scale_factor must be positive, but can be float.

        """
        ...


    @scale_factor.setter
    def scale_factor(self, value : float):
        ...


    @property
    def screen_space(self) -> bool:
        """
        Whether the 'length' mode is in screen space (pixels) or coordinate space.

        When True, the number of pattern repetitions depends on the zoom level,
           but the visual effect of the pattern is invariant of zoom.
        When False, the number of pattern repetitions is invariant of zoom.

        """
        ...


    @screen_space.setter
    def screen_space(self, value : bool):
        ...


    @property
    def texture(self) -> Texture | None:
        """
        Texture to use for the pattern.

        This texture will be sampled along the outline of the shape.
        The texture should have wrap_x set to True to enable repetition.

        """
        ...


    @texture.setter
    def texture(self, value : Texture | None):
        ...


    @property
    def x_mode(self) -> str:
        """
        How to sample the x-coordinate of the texture.

        'points': x goes from 0 to 1 between each point in the outline
        'length': x increases linearly with the length of the path in pixels

        """
        ...


    @x_mode.setter
    def x_mode(self, value : str):
        ...


class PlaceHolderParent(baseItem):
    """
    Placeholder parent to store items outside the rendering tree.
    Can be a parent to anything but cannot have any parent itself.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : Sequence[baseItemSubCls] = [], next_sibling : baseItemSubCls | None = None, parent : baseItemSubCls | None = None, previous_sibling : baseItemSubCls | None = None, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - user_data: User data of any type.
        """
        ...


class Plot(uiItem):
    """
    Interactive 2D plot that displays data with customizable axes and legend.

    A plot provides a canvas for visualizing data through various plot elements
    like lines, scatter points, bars, etc. The plot has up to six configurable
    axes (X1-X3, Y1-Y3) with X1 and Y1 enabled by default.

    The plot supports user interactions like panning, zooming, and context menus.
    Mouse hover and click events can be handled through the plot's handlers to
    implement custom interactions with the plotted data.

    Child elements are added as plot elements that represent different
    visualizations of data. These elements are rendered in the plotting area
    and can appear in the legend.

    """
    def __init__(self, context : Context, X1 : PlotAxisConfig = ..., X2 : PlotAxisConfig = ..., X3 : PlotAxisConfig = ..., Y1 : PlotAxisConfig = ..., Y2 : PlotAxisConfig = ..., Y3 : PlotAxisConfig = ..., attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : Sequence[plotElementSubCls] = [], crosshairs : bool = False, enabled : bool = True, equal_aspects : bool = False, fit_button : MouseButton = 0, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", legend_config : PlotLegendConfig = ..., menu_button : MouseButton = 1, mouse_location : LegendLocation = 10, next_sibling : baseItemSubCls | None = None, no_frame : bool = False, no_inputs : bool = False, no_legend : bool = False, no_menus : bool = False, no_mouse_pos : bool = False, no_newline : bool = False, no_scaling : bool = False, no_title : bool = False, pan_button : MouseButton = 0, pan_mod : KeyMod = 0, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedValue = ..., show : bool = True, theme : Any = ..., use_24hour_clock : bool = False, use_ISO8601 : bool = False, use_local_time : bool = False, user_data : Any = ..., value : Any = ..., width : float = 0.0, zoom_mod : KeyMod = 0, zoom_rate : float = 0.10000000149011612):
        """
        Parameters
        ----------
        - X1: Configuration for the primary X-axis.
        - X2: Configuration for the secondary X-axis.
        - X3: Configuration for the tertiary X-axis.
        - Y1: Configuration for the primary Y-axis.
        - Y2: Configuration for the secondary Y-axis.
        - Y3: Configuration for the tertiary Y-axis.
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - crosshairs: Whether to display crosshair lines at the mouse position.
        - enabled: Whether the item is interactive and fully styled.
        - equal_aspects: Whether to maintain equal pixel-to-data ratio for X and Y axes.
        - fit_button: Mouse button used to fit axes to data when double-clicked.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - legend_config: Configuration for the plot legend.
        - menu_button: Mouse button used to open context menus.
        - mouse_location: Position where mouse coordinates are displayed within the plot.
        - next_sibling: Child of the parent rendered just after this item.
        - no_frame: Whether to hide the plot's outer frame.
        - no_inputs: Whether to disable all user interactions with the plot.
        - no_legend: Whether to hide the plot legend.
        - no_menus: Whether to disable context menus.
        - no_mouse_pos: Whether to hide the mouse position text.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - no_title: Whether to hide the plot title.
        - pan_button: Mouse button used for panning the plot.
        - pan_mod: Keyboard modifier required for panning the plot.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - use_24hour_clock: Whether to use 24-hour time format.
        - use_ISO8601: Whether to format dates according to ISO 8601.
        - use_local_time: Whether to display time axes in local timezone.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        - zoom_mod: Keyboard modifier required for mouse wheel zooming.
        - zoom_rate: Zooming speed when using the mouse wheel.
        """
        ...


    @property
    def X1(self) -> PlotAxisConfig:
        """
        Configuration for the primary X-axis.

        This is the main horizontal axis, enabled by default. Use this property
        to configure axis appearance, scale, range limits, and other settings
        for the primary X-axis.

        """
        ...


    @X1.setter
    def X1(self, value : PlotAxisConfig):
        ...


    @property
    def X2(self) -> PlotAxisConfig:
        """
        Configuration for the secondary X-axis.

        This is a supplementary horizontal axis, disabled by default. Enable
        it to plot data against a different horizontal scale than X1, useful
        for comparing different units or scales on the same plot.

        """
        ...


    @X2.setter
    def X2(self, value : PlotAxisConfig):
        ...


    @property
    def X3(self) -> PlotAxisConfig:
        """
        Configuration for the tertiary X-axis.

        This is an additional horizontal axis, disabled by default. Enable
        it when you need a third horizontal scale, which can be useful for
        complex multi-scale plots or specialized scientific visualizations.

        """
        ...


    @X3.setter
    def X3(self, value : PlotAxisConfig):
        ...


    @property
    def Y1(self) -> PlotAxisConfig:
        """
        Configuration for the primary Y-axis.

        This is the main vertical axis, enabled by default. Use this property
        to configure axis appearance, scale, range limits, and other settings
        for the primary Y-axis.

        """
        ...


    @Y1.setter
    def Y1(self, value : PlotAxisConfig):
        ...


    @property
    def Y2(self) -> PlotAxisConfig:
        """
        Configuration for the secondary Y-axis.

        This is a supplementary vertical axis, disabled by default. Enable
        it to plot data against a different vertical scale than Y1, useful
        for displaying relationships between variables with different units.

        """
        ...


    @Y2.setter
    def Y2(self, value : PlotAxisConfig):
        ...


    @property
    def Y3(self) -> PlotAxisConfig:
        """
        Configuration for the tertiary Y-axis.

        This is an additional vertical axis, disabled by default. Enable
        it when you need a third vertical scale, useful for specialized
        visualizations with multiple related but differently scaled variables.

        """
        ...


    @Y3.setter
    def Y3(self, value : PlotAxisConfig):
        ...


    @property
    def axes(self) -> list:
        """
        (Read-only) All six axes configurations in a list.

        Returns the axes in the order [X1, X2, X3, Y1, Y2, Y3]. This property
        provides a convenient way to access all axes at once, for operations
        that need to apply to multiple axes simultaneously.

        """
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def content_pos(self) -> Coord:
        """
        (Read-only) Position of the content area's top-left corner.

        This property provides the viewport-relative coordinates of the starting
        point for an item's content area. This is where child elements begin to be
        placed by default.

        Used together with content_region_avail, this defines the rectangle
        available for child elements.

        """
        ...


    @property
    def content_region_avail(self) -> Coord:
        """
        (Read-only) Available space for child items.

        For container items like windows, child windows, this
        property represents the available space for placing child items. This is
        the item's inner area after accounting for padding, borders, and other
        non-content elements.

        Areas that require scrolling to see are not included in this measurement.

        """
        ...


    @property
    def crosshairs(self) -> bool:
        """
        Whether to display crosshair lines at the mouse position.

        When True, horizontal and vertical lines will follow the mouse cursor
        while hovering over the plot area, making it easier to visually align
        points with the axes values.

        """
        ...


    @crosshairs.setter
    def crosshairs(self, value : bool):
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def equal_aspects(self) -> bool:
        """
        Whether to maintain equal pixel-to-data ratio for X and Y axes.

        When True, the plot ensures that one unit along the X axis has the
        same pixel length as one unit along the Y axis. Essential for
        visualizations where spatial proportions matter, like maps or shapes.

        """
        ...


    @equal_aspects.setter
    def equal_aspects(self, value : bool):
        ...


    @property
    def fit_button(self) -> MouseButton:
        """
        Mouse button used to fit axes to data when double-clicked.

        When this button is double-clicked while the cursor is over the plot area,
        the axes will automatically adjust to fit all visible data. Default is
        the left mouse button.

        """
        ...


    @fit_button.setter
    def fit_button(self, value : MouseButton):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def legend_config(self) -> PlotLegendConfig:
        """
        Configuration for the plot legend.

        Controls the appearance and behavior of the legend, which displays
        labels for each plotted element. The legend can be positioned, styled,
        and configured to allow different interactions with plot elements.

        """
        ...


    @legend_config.setter
    def legend_config(self, value : PlotLegendConfig):
        ...


    @property
    def menu_button(self) -> MouseButton:
        """
        Mouse button used to open context menus.

        When this button is clicked over various parts of the plot, context
        menus will appear with relevant options. Default is the right mouse
        button. Context menus can be disabled entirely with no_menus.

        """
        ...


    @menu_button.setter
    def menu_button(self, value : MouseButton):
        ...


    @property
    def mouse_location(self) -> LegendLocation:
        """
        Position where mouse coordinates are displayed within the plot.

        Controls where the text showing the current mouse position (in plot
        coordinates) appears. Default is the southeast corner (bottom-right).
        Only relevant when no_mouse_pos is False.

        """
        ...


    @mouse_location.setter
    def mouse_location(self, value : LegendLocation):
        ...


    @property
    def no_frame(self) -> bool:
        """
        Whether to hide the plot's outer frame.

        When True, the rectangular border around the entire plot will not be
        drawn. Creates a more minimal appearance, especially when plots need to
        blend with the surrounding UI.

        """
        ...


    @no_frame.setter
    def no_frame(self, value : bool):
        ...


    @property
    def no_inputs(self) -> bool:
        """
        Whether to disable all user interactions with the plot.

        When True, the plot becomes view-only, disabling panning, zooming,
        and all other mouse/keyboard interactions. Useful for display-only
        plots or when handling interactions through custom code.

        """
        ...


    @no_inputs.setter
    def no_inputs(self, value : bool):
        ...


    @property
    def no_legend(self) -> bool:
        """
        Whether to hide the plot legend.

        When True, the legend showing labels for plotted elements will not be
        displayed. Useful when plot elements are self-explanatory or to
        maximize the plotting area when space is limited.

        """
        ...


    @no_legend.setter
    def no_legend(self, value : bool):
        ...


    @property
    def no_menus(self) -> bool:
        """
        Whether to disable context menus.

        When True, right-clicking (or using the assigned menu_button) will not
        open context menus that provide options for fitting data, changing
        scales, etc. Useful for plots meant for viewing only.

        """
        ...


    @no_menus.setter
    def no_menus(self, value : bool):
        ...


    @property
    def no_mouse_pos(self) -> bool:
        """
        Whether to hide the mouse position text.

        When True, the current coordinates of the mouse cursor within the plot
        area will not be displayed. Useful for cleaner appearance or when
        mouse position information is not relevant.

        """
        ...


    @no_mouse_pos.setter
    def no_mouse_pos(self, value : bool):
        ...


    @property
    def no_title(self) -> bool:
        """
        Whether to hide the plot title.

        When True, the plot's title (provided in the label parameter) will not
        be displayed, saving vertical space. Useful for plots where the title
        is redundant or when maximizing the plotting area.

        """
        ...


    @no_title.setter
    def no_title(self, value : bool):
        ...


    @property
    def pan_button(self) -> MouseButton:
        """
        Mouse button used for panning the plot.

        When this button is held down while the cursor is over the plot area,
        moving the mouse will pan the view. The default is the left mouse button.
        Can be combined with pan_mod for more complex interaction patterns.

        """
        ...


    @pan_button.setter
    def pan_button(self, value : MouseButton):
        ...


    @property
    def pan_mod(self) -> KeyMod:
        """
        Keyboard modifier required for panning the plot.

        Specifies which keyboard keys (Shift, Ctrl, Alt, etc.) must be held
        down along with the pan_button to initiate panning. Default is no
        modifier, meaning pan_button works without any keys pressed.

        """
        ...


    @pan_mod.setter
    def pan_mod(self, value : KeyMod):
        ...


    @property
    def use_24hour_clock(self) -> bool:
        """
        Whether to use 24-hour time format.

        When True and an axis is displaying time, times will use 24-hour format
        (e.g., 14:30 instead of 2:30 PM). Default is False, using 12-hour format
        with AM/PM indicators where appropriate.

        """
        ...


    @use_24hour_clock.setter
    def use_24hour_clock(self, value : bool):
        ...


    @property
    def use_ISO8601(self) -> bool:
        """
        Whether to format dates according to ISO 8601.

        When True and an axis is in time scale mode, dates will be formatted
        according to the ISO 8601 standard (YYYY-MM-DD, etc.). Default is False,
        using locale-specific date formatting.

        """
        ...


    @use_ISO8601.setter
    def use_ISO8601(self, value : bool):
        ...


    @property
    def use_local_time(self) -> bool:
        """
        Whether to display time axes in local timezone.

        When True and an axis is in time scale mode, times will be displayed
        according to the system's timezone. When False, UTC is used instead.
        Default is False.

        """
        ...


    @use_local_time.setter
    def use_local_time(self, value : bool):
        ...


    @property
    def zoom_mod(self) -> KeyMod:
        """
        Keyboard modifier required for mouse wheel zooming.

        Specifies which keyboard keys (Shift, Ctrl, Alt, etc.) must be held
        down for the mouse wheel to zoom the plot. Default is no modifier,
        meaning the wheel zooms without any keys pressed.

        """
        ...


    @zoom_mod.setter
    def zoom_mod(self, value : KeyMod):
        ...


    @property
    def zoom_rate(self) -> float:
        """
        Zooming speed when using the mouse wheel.

        Determines how much the plot zooms with each mouse wheel tick. Default
        is 0.1 (10% of plot range per tick). Negative values invert the zoom
        direction, making scrolling up zoom out instead of in.

        """
        ...


    @zoom_rate.setter
    def zoom_rate(self, value : float):
        ...


class PlotAnnotation(plotElement):
    """
    Adds a text annotation at a specific point in a plot.

    Annotations are small text bubbles that can be attached to specific points
    in the plot to provide additional context, labels, or explanations. They
    are always rendered on top of other plot elements and can have customizable
    background colors, offsets, and clamping behavior to ensure visibility.

    """
    def __init__(self, context : Context, attach : Any = ..., axes : tuple = (0, 3), before : Any = ..., bg_color : list = [0.0, 0.0, 0.0, 0.0], children : None  = [], clamp : bool = False, label : str = "", next_sibling : baseItemSubCls | None = None, offset : tuple = (0.0, 0.0), parent : PlotSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, text : str = "", theme : Any = ..., user_data : Any = ..., x : float = 0.0, y : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - axes: The X and Y axes that the plot element is attached to.
        - before: Attach the item just before the target item. Default is None (disabled)
        - bg_color: Background color of the annotation bubble.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - clamp: Whether to ensure the annotation stays within the plot area.
        - label: Text label for the plot element.
        - next_sibling: Child of the parent rendered just after this item.
        - offset: Offset in pixels from the anchor point.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Controls whether the plot element is visible.
        - text: Text content of the annotation.
        - theme: Visual theme applied to the plot element.
        - user_data: User data of any type.
        - x: X coordinate of the annotation in plot units.
        - y: Y coordinate of the annotation in plot units.
        """
        ...


    @property
    def bg_color(self) -> list:
        """
        Background color of the annotation bubble.

        Color values are provided as an RGBA list with values in the [0,1] range.
        When set to 0 (fully transparent), the text color is determined by the
        ImPlotCol_InlayText style. Otherwise, the text color is automatically
        set to white or black for optimal contrast with the background.

        """
        ...


    @bg_color.setter
    def bg_color(self, value : list):
        ...


    @property
    def clamp(self) -> bool:
        """
        Whether to ensure the annotation stays within the plot area.

        When enabled, the annotation will always be visible within the plot area
        even if its anchor point is outside or near the edge. When disabled,
        annotations may be partially or completely hidden if their anchor points
        are outside the plot boundaries.

        """
        ...


    @clamp.setter
    def clamp(self, value : bool):
        ...


    @property
    def offset(self) -> tuple:
        """
        Offset in pixels from the anchor point.

        Specifies the displacement of the annotation bubble from its anchor
        position in screen pixels. This allows placing the annotation near
        a data point without overlapping it. Provided as a tuple of (x, y)
        values, where positive values move right and down.

        """
        ...


    @offset.setter
    def offset(self, value : tuple):
        ...


    @property
    def text(self) -> str:
        """
        Text content of the annotation.

        The string to display in the annotation bubble. This text can include
        any characters and will be rendered using the current font settings.
        For dynamic annotations, this property can be updated on each frame.

        """
        ...


    @text.setter
    def text(self, value : str):
        ...


    @property
    def x(self) -> float:
        """
        X coordinate of the annotation in plot units.

        Specifies the horizontal position of the annotation anchor point within
        the plot's coordinate system. This position will be used as the base
        point from which the annotation offset is applied.

        """
        ...


    @x.setter
    def x(self, value : float):
        ...


    @property
    def y(self) -> float:
        """
        Y coordinate of the annotation in plot units.

        Specifies the vertical position of the annotation anchor point within
        the plot's coordinate system. This position will be used as the base
        point from which the annotation offset is applied.

        """
        ...


    @y.setter
    def y(self, value : float):
        ...


class PlotAxisConfig(baseItem):
    """
    Configuration for a plot axis.

    Controls the appearance, behavior and limits of an axis in a plot. Each plot
    can have up to six axes (X1, X2, X3, Y1, Y2, Y3) that can be configured
    individually. By default, only X1 and Y1 are enabled.

    Can have AxisTag elements as children to add markers at specific positions
    along the axis.

    """
    def __init__(self, context : Context, attach : Any = ..., auto_fit : bool = False, before : Any = ..., children : Sequence[baseItemSubCls] = [], constraint_max : float = inf, constraint_min : float = -inf, enabled : bool = True, foreground_grid : bool = False, handlers : list = [], invert : bool = False, keep_default_ticks : bool = False, label : str = "", labels : list = [], labels_coord : list = [], lock_max : bool = False, lock_min : bool = False, max : float = 1.0, min : float = 0.0, next_sibling : baseItemSubCls | None = None, no_gridlines : bool = False, no_highlight : bool = False, no_initial_fit : bool = False, no_label : bool = False, no_menus : bool = False, no_side_switch : bool = False, no_tick_labels : bool = False, no_tick_marks : bool = False, opposite : bool = False, pan_stretch : bool = False, parent : baseItemSubCls | None = None, previous_sibling : baseItemSubCls | None = None, restrict_fit_to_range : bool = False, scale : AxisScale = 0, tick_format : str = "", user_data : Any = ..., zoom_max : float = inf, zoom_min : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - auto_fit: Whether the axis automatically fits to data every frame.
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - constraint_max: Maximum allowed value for the axis maximum.
        - constraint_min: Minimum allowed value for the axis minimum.
        - enabled: Whether elements using this axis should be drawn.
        - foreground_grid: Whether to draw grid lines in the foreground.
        - handlers: Event handlers attached to this axis.
        - invert: Whether the axis direction is inverted.
        - keep_default_ticks: Whether to keep default ticks when using custom labels.
        - label: Text label for the axis.
        - labels: Custom text labels for specific tick positions.
        - labels_coord: Coordinate positions for custom tick labels.
        - lock_max: Whether the axis maximum value is locked when panning/zooming.
        - lock_min: Whether the axis minimum value is locked when panning/zooming.
        - max: Current maximum value of the axis range.
        - min: Current minimum value of the axis range.
        - next_sibling: Child of the parent rendered just after this item.
        - no_gridlines: Whether to hide the grid lines.
        - no_highlight: Whether to disable axis highlighting when hovered or selected.
        - no_initial_fit: Whether to disable automatic fitting on the first frame.
        - no_label: Whether to hide the axis label.
        - no_menus: Whether to disable context menus for this axis.
        - no_side_switch: Whether to prevent the user from switching the axis side.
        - no_tick_labels: Whether to hide the text labels for tick marks.
        - no_tick_marks: Whether to hide the tick marks on the axis.
        - opposite: Whether to display ticks and labels on the opposite side of the axis.
        - pan_stretch: Whether panning can stretch locked or constrained axes.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - restrict_fit_to_range: Whether to restrict fitting to data within the opposing axis range.
        - scale: Current axis scale type.
        - tick_format: Format string for displaying tick labels.
        - user_data: User data of any type.
        - zoom_max: Maximum allowed width of the axis range.
        - zoom_min: Minimum allowed width of the axis range.
        """
        ...


    def fit(self):
        """
        Request an axis fit to the data on the next frame.

        This will adjust the axis range to encompass all plotted data during
        the next rendering cycle. The fit operation is a one-time action that
        doesn't enable auto-fitting for subsequent frames.

        """
        ...


    @property
    def auto_fit(self) -> bool:
        """
        Whether the axis automatically fits to data every frame.

        When True, the axis will continuously adjust its range to ensure
        all plotted data is visible, regardless of user interactions. This
        overrides manual zooming and panning.

        """
        ...


    @auto_fit.setter
    def auto_fit(self, value : bool):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether the axis was clicked in the current frame.

        Returns a tuple containing the clicked state for each mouse button.
        This state is reset on the next frame, so it's recommended to use
        handlers to respond to click events rather than polling this property.

        """
        ...


    @property
    def constraint_max(self) -> float:
        """
        Maximum allowed value for the axis maximum.

        Sets a hard limit on how far the axis can be zoomed or panned out.
        The maximum value of the axis will never go above this value.
        Default is positive infinity (no constraint).

        """
        ...


    @constraint_max.setter
    def constraint_max(self, value : float):
        ...


    @property
    def constraint_min(self) -> float:
        """
        Minimum allowed value for the axis minimum.

        Sets a hard limit on how far the axis can be zoomed or panned out.
        The minimum value of the axis will never go below this value.
        Default is negative infinity (no constraint).

        """
        ...


    @constraint_min.setter
    def constraint_min(self, value : float):
        ...


    @property
    def enabled(self) -> bool:
        """
        Whether elements using this axis should be drawn.

        When disabled, plot elements assigned to this axis will not be rendered.
        At least one X and one Y axis must be enabled for the plot to display
        properly.

        """
        ...


    @enabled.setter
    def enabled(self, value : bool):
        ...


    @property
    def foreground_grid(self) -> bool:
        """
        Whether to draw grid lines in the foreground.

        When True, grid lines are drawn on top of plot data rather than
        behind it. This can improve grid visibility when plot elements would
        otherwise obscure the grid.

        """
        ...


    @foreground_grid.setter
    def foreground_grid(self, value : bool):
        ...


    @property
    def handlers(self) -> list:
        """
        Event handlers attached to this axis.

        Handlers can respond to visibility changes, hover events, and click
        events. Use this to implement custom interactions with the axis.

        """
        ...


    @handlers.setter
    def handlers(self, value : list):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse is hovering over the axis label area.

        Useful for implementing custom hover effects or tooltips for axis
        elements. This state updates automatically during rendering.

        """
        ...


    @property
    def invert(self) -> bool:
        """
        Whether the axis direction is inverted.

        When True, the axis will be displayed in the reverse direction, with
        values decreasing rather than increasing along the axis direction.
        This is the proper way to flip axis direction, rather than swapping
        min/max values.

        """
        ...


    @invert.setter
    def invert(self, value : bool):
        ...


    @property
    def keep_default_ticks(self) -> bool:
        """
        Whether to keep default ticks when using custom labels.

        When True and custom labels are set, both the default numeric ticks
        and the custom labels will be displayed. When False, only the
        custom labels will be shown.

        """
        ...


    @keep_default_ticks.setter
    def keep_default_ticks(self, value : bool):
        ...


    @property
    def label(self) -> str:
        """
        Text label for the axis.

        This text appears beside the axis and describes what the axis
        represents. For example, "Time (s)" or "Voltage (V)".

        """
        ...


    @label.setter
    def label(self, value : str):
        ...


    @property
    def labels(self) -> list:
        """
        Custom text labels for specific tick positions.

        Replace default numeric tick labels with text. Must be used in
        conjunction with labels_coord to specify positions. Useful for
        categorical data or custom annotations.

        """
        ...


    @labels.setter
    def labels(self, value : list):
        ...


    @property
    def labels_coord(self) -> list:
        """
        Coordinate positions for custom tick labels.

        Specifies where to place each label from the labels property along
        the axis. Must contain the same number of elements as labels.

        """
        ...


    @labels_coord.setter
    def labels_coord(self, value : list):
        ...


    @property
    def lock_max(self) -> bool:
        """
        Whether the axis maximum value is locked when panning/zooming.

        When True, the maximum value of the axis will not change during
        panning or zooming operations. Only the minimum value will adjust.

        """
        ...


    @lock_max.setter
    def lock_max(self, value : bool):
        ...


    @property
    def lock_min(self) -> bool:
        """
        Whether the axis minimum value is locked when panning/zooming.

        When True, the minimum value of the axis will not change during
        panning or zooming operations. Only the maximum value will adjust.

        """
        ...


    @lock_min.setter
    def lock_min(self, value : bool):
        ...


    @property
    def max(self) -> float:
        """
        Current maximum value of the axis range.

        Sets the upper bound of the visible range. Should be greater than min.
        To reverse the axis direction, use the invert property instead of
        swapping min/max values.

        """
        ...


    @max.setter
    def max(self, value : float):
        ...


    @property
    def min(self) -> float:
        """
        Current minimum value of the axis range.

        Sets the lower bound of the visible range. Should be less than max.
        To reverse the axis direction, use the invert property instead of
        swapping min/max values.

        """
        ...


    @min.setter
    def min(self, value : float):
        ...


    @property
    def mouse_coord(self) -> float:
        """
        (Read-only) Current mouse position in plot units for this axis.

        Contains the estimated coordinate of the mouse cursor along this axis.
        Updated every time the plot is drawn when this axis is enabled.

        When using the same axis instance with multiple plots, this value will
        reflect whichever plot was last rendered.

        """
        ...


    @property
    def no_gridlines(self) -> bool:
        """
        Whether to hide the grid lines.

        When True, the grid lines that extend from the axis ticks across
        the plot area will not be drawn, creating a cleaner appearance.

        """
        ...


    @no_gridlines.setter
    def no_gridlines(self, value : bool):
        ...


    @property
    def no_highlight(self) -> bool:
        """
        Whether to disable axis highlighting when hovered or selected.

        When True, the axis background will not be highlighted when the mouse
        hovers over it or when it is selected, providing a more consistent
        appearance.

        """
        ...


    @no_highlight.setter
    def no_highlight(self, value : bool):
        ...


    @property
    def no_initial_fit(self) -> bool:
        """
        Whether to disable automatic fitting on the first frame.

        When True, the axis will not automatically adjust to fit the data
        on the first frame. The axis will maintain its default range until
        explicitly fitted or adjusted.

        """
        ...


    @no_initial_fit.setter
    def no_initial_fit(self, value : bool):
        ...


    @property
    def no_label(self) -> bool:
        """
        Whether to hide the axis label.

        When True, the axis label will not be displayed, saving space in
        the plot. Useful for minimalist plots or when space is limited.

        """
        ...


    @no_label.setter
    def no_label(self, value : bool):
        ...


    @property
    def no_menus(self) -> bool:
        """
        Whether to disable context menus for this axis.

        When True, right-clicking on the axis will not open the context menu
        that provides options to fit data, set scales, etc.

        """
        ...


    @no_menus.setter
    def no_menus(self, value : bool):
        ...


    @property
    def no_side_switch(self) -> bool:
        """
        Whether to prevent the user from switching the axis side.

        When True, the user cannot drag the axis to the opposite side of the
        plot. For example, an X-axis cannot be moved from bottom to top.

        """
        ...


    @no_side_switch.setter
    def no_side_switch(self, value : bool):
        ...


    @property
    def no_tick_labels(self) -> bool:
        """
        Whether to hide the text labels for tick marks.

        When True, the numerical or text labels that display the value at
        each tick position will not be drawn, while still keeping the tick
        marks themselves if enabled.

        """
        ...


    @no_tick_labels.setter
    def no_tick_labels(self, value : bool):
        ...


    @property
    def no_tick_marks(self) -> bool:
        """
        Whether to hide the tick marks on the axis.

        When True, the small lines that indicate tick positions on the axis
        will not be drawn, while still keeping tick labels if enabled.

        """
        ...


    @no_tick_marks.setter
    def no_tick_marks(self, value : bool):
        ...


    @property
    def opposite(self) -> bool:
        """
        Whether to display ticks and labels on the opposite side of the axis.

        When True, labels and ticks are rendered on the opposite side from
        their default position. For example, ticks on an X-axis would appear
        above rather than below the axis line.

        """
        ...


    @opposite.setter
    def opposite(self, value : bool):
        ...


    @property
    def pan_stretch(self) -> bool:
        """
        Whether panning can stretch locked or constrained axes.

        When True, if the axis is being panned while in a locked or
        constrained state, it will stretch instead of maintaining fixed
        bounds. Useful for maintaining context while exploring limited ranges.

        """
        ...


    @pan_stretch.setter
    def pan_stretch(self, value : bool):
        ...


    @property
    def restrict_fit_to_range(self) -> bool:
        """
        Whether to restrict fitting to data within the opposing axis range.

        When True, data points that are outside the visible range of the
        opposite axis will be ignored when auto-fitting this axis. This can
        prevent outliers from one dimension affecting the scale of the other.

        """
        ...


    @restrict_fit_to_range.setter
    def restrict_fit_to_range(self, value : bool):
        ...


    @property
    def scale(self) -> AxisScale:
        """
        Current axis scale type.

        Controls how values are mapped along the axis. Options include:
        - LINEAR: Linear mapping (default)
        - TIME: Display values as dates/times
        - LOG10: Logarithmic scale (base 10)
        - SYMLOG: Symmetric logarithmic scale

        """
        ...


    @scale.setter
    def scale(self, value : AxisScale):
        ...


    @property
    def tick_format(self) -> str:
        """
        Format string for displaying tick labels.

        Controls how numeric values are formatted on the axis. Uses printf-style
        format specifiers like "%.2f" for 2 decimal places or "%d" for integers.
        Leave empty to use the default format.

        """
        ...


    @tick_format.setter
    def tick_format(self, value : str):
        ...


    @property
    def zoom_max(self) -> float:
        """
        Maximum allowed width of the axis range.

        Constrains the maximum zoom level by enforcing a maximum distance
        between min and max. Prevents extreme zooming out.
        Default is infinity (no constraint).

        """
        ...


    @zoom_max.setter
    def zoom_max(self, value : float):
        ...


    @property
    def zoom_min(self) -> float:
        """
        Minimum allowed width of the axis range.

        Constrains the minimum zoom level by enforcing a minimum distance
        between min and max. Prevents extreme zooming in.
        Default is 0 (no constraint).

        """
        ...


    @zoom_min.setter
    def zoom_min(self, value : float):
        ...


class PlotBarGroups(plotElementWithLegend):
    """
    Plots grouped bar charts with multiple series of data.

    Creates groups of bars where each group has multiple bars side-by-side (or
    stacked). This is ideal for comparing multiple data series across different
    categories. Each row in the values array represents a series (with consistent
    color), and each column represents a group position.

    """
    def __init__(self, context : Context, attach : Any = ..., axes : tuple = (0, 3), before : Any = ..., children : Sequence[uiItemSubCls] = [], enabled : bool = True, font : Font = None, group_size : float = 0.67, horizontal : bool = False, ignore_fit : bool = False, label : str = "", labels : list = ['Item 0'], legend_button : MouseButton = 1, legend_handlers : list = [], next_sibling : baseItemSubCls | None = None, no_legend : bool = False, parent : PlotSubCls | None = None, previous_sibling : baseItemSubCls | None = None, shift : float = 0.0, show : bool = True, stacked : bool = False, theme : Any = ..., user_data : Any = ..., values : Array = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - axes: The X and Y axes that the plot element is attached to.
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether this element is currently visible in the plot.
        - font: Font used for rendering this element's text.
        - group_size: Portion of the available width used for bars within each group.
        - horizontal: Whether bars are oriented horizontally instead of vertically.
        - ignore_fit: Whether to exclude this element when auto-fitting axes.
        - label: Text label for the plot element.
        - labels: Labels for each data series.
        - legend_button: Mouse button that opens this element's legend popup.
        - legend_handlers: Event handlers attached to this element's legend entry.
        - next_sibling: Child of the parent rendered just after this item.
        - no_legend: Whether to hide this element from the plot legend.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - shift: Horizontal offset for all groups in plot units.
        - show: Controls whether the plot element is visible.
        - stacked: Whether bars within each group are stacked.
        - theme: Visual theme applied to the plot element.
        - user_data: User data of any type.
        - values: 2D array containing the values for each bar.
        """
        ...


    @property
    def group_size(self) -> float:
        """
        Portion of the available width used for bars within each group.

        Controls how much of the available space between groups is filled with
        bars. Value ranges from 0.0 to 1.0, where 1.0 means no space between
        groups and 0.0 means no visible bars. The default value of 0.67 leaves
        some space between groups while making bars large enough to read easily.

        """
        ...


    @group_size.setter
    def group_size(self, value : float):
        ...


    @property
    def horizontal(self) -> bool:
        """
        Whether bars are oriented horizontally instead of vertically.

        When True, bars extend horizontally from the Y-axis with groups arranged
        vertically. When False (default), bars extend vertically from the X-axis
        with groups arranged horizontally. Horizontal orientation is useful when
        dealing with long category names or when comparing values across many
        groups.

        """
        ...


    @horizontal.setter
    def horizontal(self, value : bool):
        ...


    @property
    def labels(self) -> list:
        """
        Labels for each data series.

        These labels appear in the legend and identify each data series (row in
        the values array). The number of labels should match the number of rows
        in the values array. If not enough labels are provided, default labels
        like "Item N" will be generated.

        """
        ...


    @labels.setter
    def labels(self, value : list):
        ...


    @property
    def shift(self) -> float:
        """
        Horizontal offset for all groups in plot units.

        Allows shifting the entire group chart left or right. This is useful for
        aligning multiple bar group plots or creating animations. A positive value
        shifts all groups to the right, while a negative value shifts them to
        the left.

        """
        ...


    @shift.setter
    def shift(self, value : float):
        ...


    @property
    def stacked(self) -> bool:
        """
        Whether bars within each group are stacked.

        When True, bars in each group are stacked on top of each other (or side
        by side for horizontal orientation) rather than being displayed side by
        side. Stacking is useful for showing both individual components and their
        sum, such as for part-to-whole relationships within categories.

        """
        ...


    @stacked.setter
    def stacked(self, value : bool):
        ...


    @property
    def values(self) -> Array:
        """
        2D array containing the values for each bar.

        The array should be row-major where each row represents one data series
        (one color/legend entry) and each column represents a group position.
        For example, with 3 series and 4 groups, the shape would be (3,4).
        By default, the implementation tries to use the array without copying.

        """
        ...


    @values.setter
    def values(self, value : Array):
        ...


class PlotBars(plotElementXY):
    """
    Plots bar graphs from X,Y data points.

    Displays a series of bars at the X positions with heights determined by Y
    values. Unlike PlotBarGroups which shows grouped categorical data, this
    element shows individual bars for continuous or discrete data points.
    Suitable for histograms, bar charts, and column graphs.

    """
    def __init__(self, context : Context, X : Array = ..., Y : Array = ..., attach : Any = ..., axes : tuple = (0, 3), before : Any = ..., children : Sequence[uiItemSubCls] = [], enabled : bool = True, font : Font = None, horizontal : bool = False, ignore_fit : bool = False, label : str = "", legend_button : MouseButton = 1, legend_handlers : list = [], next_sibling : baseItemSubCls | None = None, no_legend : bool = False, parent : PlotSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, theme : Any = ..., user_data : Any = ..., weight : float = 1.0):
        """
        Parameters
        ----------
        - X: Values on the X axis.
        - Y: Values on the Y axis
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - axes: The X and Y axes that the plot element is attached to.
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether this element is currently visible in the plot.
        - font: Font used for rendering this element's text.
        - horizontal: Whether to render bars horizontally instead of vertically.
        - ignore_fit: Whether to exclude this element when auto-fitting axes.
        - label: Text label for the plot element.
        - legend_button: Mouse button that opens this element's legend popup.
        - legend_handlers: Event handlers attached to this element's legend entry.
        - next_sibling: Child of the parent rendered just after this item.
        - no_legend: Whether to hide this element from the plot legend.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Controls whether the plot element is visible.
        - theme: Visual theme applied to the plot element.
        - user_data: User data of any type.
        - weight: Width of each bar in plot units.
        """
        ...


    @property
    def horizontal(self) -> bool:
        """
        Whether to render bars horizontally instead of vertically.

        When True, bars extend horizontally from the Y-axis with lengths
        determined by Y values. When False (default), bars extend vertically
        from the X-axis with heights determined by Y values.

        """
        ...


    @horizontal.setter
    def horizontal(self, value : bool):
        ...


    @property
    def weight(self) -> float:
        """
        Width of each bar in plot units.

        Controls the thickness of each bar. A value of 1.0 means bars will
        touch when X values are spaced 1.0 units apart. Smaller values create
        thinner bars with gaps between them, larger values create overlapping
        bars.

        """
        ...


    @weight.setter
    def weight(self, value : float):
        ...


class PlotDigital(plotElementXY):
    """
    Plots a digital signal as a step function from X,Y data.

    Digital plots represent binary or multi-level signals where values change
    instantaneously rather than continuously. These plots are anchored to the
    bottom of the plot area and do not scale with Y-axis zooming, making them
    ideal for displaying digital signals, logic traces, or state changes over
    time.

    """
    def __init__(self, context : Context, X : Array = ..., Y : Array = ..., attach : Any = ..., axes : tuple = (0, 3), before : Any = ..., children : Sequence[uiItemSubCls] = [], enabled : bool = True, font : Font = None, ignore_fit : bool = False, label : str = "", legend_button : MouseButton = 1, legend_handlers : list = [], next_sibling : baseItemSubCls | None = None, no_legend : bool = False, parent : PlotSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, theme : Any = ..., user_data : Any = ...):
        """
        Parameters
        ----------
        - X: Values on the X axis.
        - Y: Values on the Y axis
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - axes: The X and Y axes that the plot element is attached to.
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether this element is currently visible in the plot.
        - font: Font used for rendering this element's text.
        - ignore_fit: Whether to exclude this element when auto-fitting axes.
        - label: Text label for the plot element.
        - legend_button: Mouse button that opens this element's legend popup.
        - legend_handlers: Event handlers attached to this element's legend entry.
        - next_sibling: Child of the parent rendered just after this item.
        - no_legend: Whether to hide this element from the plot legend.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Controls whether the plot element is visible.
        - theme: Visual theme applied to the plot element.
        - user_data: User data of any type.
        """
        ...


class PlotErrorBars(plotElementXY):
    """
    Plots vertical or horizontal error bars for X,Y data points.

    Error bars visualize uncertainty or variation in measurements by displaying
    a line extending from each data point. Each error bar can have different
    positive and negative values, allowing for asymmetrical error representation.
    This is particularly useful for scientific data where measurements have known
    or estimated uncertainties.

    """
    def __init__(self, context : Context, X : Array = ..., Y : Array = ..., attach : Any = ..., axes : tuple = (0, 3), before : Any = ..., children : Sequence[uiItemSubCls] = [], enabled : bool = True, font : Font = None, horizontal : bool = False, ignore_fit : bool = False, label : str = "", legend_button : MouseButton = 1, legend_handlers : list = [], negatives : Array = ..., next_sibling : baseItemSubCls | None = None, no_legend : bool = False, parent : PlotSubCls | None = None, positives : Array = ..., previous_sibling : baseItemSubCls | None = None, show : bool = True, theme : Any = ..., user_data : Any = ...):
        """
        Parameters
        ----------
        - X: Values on the X axis.
        - Y: Values on the Y axis
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - axes: The X and Y axes that the plot element is attached to.
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether this element is currently visible in the plot.
        - font: Font used for rendering this element's text.
        - horizontal: Whether error bars are oriented horizontally instead of vertically.
        - ignore_fit: Whether to exclude this element when auto-fitting axes.
        - label: Text label for the plot element.
        - legend_button: Mouse button that opens this element's legend popup.
        - legend_handlers: Event handlers attached to this element's legend entry.
        - negatives: Negative error values array.
        - next_sibling: Child of the parent rendered just after this item.
        - no_legend: Whether to hide this element from the plot legend.
        - parent: Parent of the item in the rendering tree.
        - positives: Positive error values array.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Controls whether the plot element is visible.
        - theme: Visual theme applied to the plot element.
        - user_data: User data of any type.
        """
        ...


    @property
    def horizontal(self) -> bool:
        """
        Whether error bars are oriented horizontally instead of vertically.

        When True, error bars extend horizontally from each data point along the
        X axis. When False (default), error bars extend vertically along the Y
        axis. Horizontal error bars are useful when the uncertainty is in the
        independent variable rather than the dependent one.

        """
        ...


    @horizontal.setter
    def horizontal(self, value : bool):
        ...


    @property
    def negatives(self) -> Array:
        """
        Negative error values array.

        Specifies the negative (downward for vertical, leftward for horizontal)
        error magnitude for each data point. When not provided or empty, the
        error bars will be symmetrical, using the values in positives for both
        directions.

        """
        ...


    @negatives.setter
    def negatives(self, value : Array):
        ...


    @property
    def positives(self) -> Array:
        """
        Positive error values array.

        Specifies the positive (upward for vertical, rightward for horizontal)
        error magnitude for each data point. If negatives is not provided, these
        values will be used for both directions, creating symmetrical error bars.

        """
        ...


    @positives.setter
    def positives(self, value : Array):
        ...


class PlotHeatmap(plotElementWithLegend):
    """
    Plots a 2D grid of values as a color-mapped heatmap.

    Visualizes 2D data by assigning colors to values based on their magnitude.
    Each cell in the grid is colored according to a colormap that maps values
    to colors. The heatmap can display patterns, correlations or distributions
    in 2D data such as matrices, images, or gridded measurements.

    The data is provided as a 2D array and can be interpreted in either row-major
    or column-major order. Optional value labels can be displayed on each cell,
    and the color scaling can be automatic or manually specified.

    """
    def __init__(self, context : Context, attach : Any = ..., axes : tuple = (0, 3), before : Any = ..., bounds_max : tuple = (1.0, 1.0), bounds_min : tuple = (0.0, 0.0), children : Sequence[uiItemSubCls] = [], col_major : bool = False, enabled : bool = True, font : Font = None, ignore_fit : bool = False, label : str = "", label_format : str = "%.1f", legend_button : MouseButton = 1, legend_handlers : list = [], next_sibling : baseItemSubCls | None = None, no_legend : bool = False, parent : PlotSubCls | None = None, previous_sibling : baseItemSubCls | None = None, scale_max : float = 0.0, scale_min : float = 0.0, show : bool = True, theme : Any = ..., user_data : Any = ..., values : Array = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - axes: The X and Y axes that the plot element is attached to.
        - before: Attach the item just before the target item. Default is None (disabled)
        - bounds_max: Top-right corner position of the heatmap in plot coordinates.
        - bounds_min: Bottom-left corner position of the heatmap in plot coordinates.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - col_major: Whether values array is interpreted in column-major order.
        - enabled: Whether this element is currently visible in the plot.
        - font: Font used for rendering this element's text.
        - ignore_fit: Whether to exclude this element when auto-fitting axes.
        - label: Text label for the plot element.
        - label_format: Format string for displaying cell values.
        - legend_button: Mouse button that opens this element's legend popup.
        - legend_handlers: Event handlers attached to this element's legend entry.
        - next_sibling: Child of the parent rendered just after this item.
        - no_legend: Whether to hide this element from the plot legend.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - scale_max: Maximum value for color mapping.
        - scale_min: Minimum value for color mapping.
        - show: Controls whether the plot element is visible.
        - theme: Visual theme applied to the plot element.
        - user_data: User data of any type.
        - values: 2D array of values to visualize in the heatmap.
        """
        ...


    @property
    def bounds_max(self) -> tuple:
        """
        Top-right corner position of the heatmap in plot coordinates.

        Specifies the (x,y) coordinates of the upper-right corner of the heatmap
        within the plot area. Combined with bounds_min, this determines the
        size and position of the heatmap. Default is (1,1).

        """
        ...


    @bounds_max.setter
    def bounds_max(self, value : tuple):
        ...


    @property
    def bounds_min(self) -> tuple:
        """
        Bottom-left corner position of the heatmap in plot coordinates.

        Specifies the (x,y) coordinates of the lower-left corner of the heatmap
        within the plot area. Combined with bounds_max, this determines the
        size and position of the heatmap. Default is (0,0).

        """
        ...


    @bounds_min.setter
    def bounds_min(self, value : tuple):
        ...


    @property
    def col_major(self) -> bool:
        """
        Whether values array is interpreted in column-major order.

        When True, the values array is interpreted as having dimensions
        (columns, rows) rather than the default row-major order (rows, columns).
        Column-major is typical for some data formats like Fortran arrays or
        certain image processing libraries.

        """
        ...


    @col_major.setter
    def col_major(self, value : bool):
        ...


    @property
    def label_format(self) -> str:
        """
        Format string for displaying cell values.

        Controls how numeric values are formatted when displayed on each cell.
        Uses printf-style format specifiers like "%.2f" for 2 decimal places.
        Set to an empty string to disable value labels completely.

        """
        ...


    @label_format.setter
    def label_format(self, value : str):
        ...


    @property
    def scale_max(self) -> float:
        """
        Maximum value for color mapping.

        Sets the upper bound of the color scale. Values at or above this level
        will be assigned the maximum color in the colormap. When both scale_min
        and scale_max are 0, automatic scaling is used based on the data's
        actual minimum and maximum values.

        """
        ...


    @scale_max.setter
    def scale_max(self, value : float):
        ...


    @property
    def scale_min(self) -> float:
        """
        Minimum value for color mapping.

        Sets the lower bound of the color scale. Values at or below this level
        will be assigned the minimum color in the colormap. When both scale_min
        and scale_max are 0, automatic scaling is used based on the data's
        actual minimum and maximum values.

        """
        ...


    @scale_min.setter
    def scale_min(self, value : float):
        ...


    @property
    def values(self) -> Array:
        """
        2D array of values to visualize in the heatmap.

        The array shape should be (rows, cols) for row-major order, or
        (cols, rows) when col_major is True. The values determine the colors
        assigned to each cell based on the current colormap and scale settings.

        By default, compatible arrays are used directly without copying.
        Supported types for direct use are int32, float32, and float64.

        """
        ...


    @values.setter
    def values(self, value : Array):
        ...


class PlotHistogram(plotElementX):
    """
    Plots a histogram from X data points.

    Creates bins from input data and displays the count (or density) of values
    falling within each bin as vertical or horizontal bars. Various binning
    methods are available to automatically determine appropriate bin sizes,
    or explicit bin counts can be specified. The display can be customized
    with cumulative counts, density normalization, and range constraints.

    """
    def __init__(self, context : Context, X : Array = ..., attach : Any = ..., axes : tuple = (0, 3), bar_scale : float = 1.0, before : Any = ..., bins : int = -1, children : Sequence[uiItemSubCls] = [], cumulative : bool = False, density : bool = False, enabled : bool = True, font : Font = None, horizontal : bool = False, ignore_fit : bool = False, label : str = "", legend_button : MouseButton = 1, legend_handlers : list = [], next_sibling : baseItemSubCls | None = None, no_legend : bool = False, no_outliers : bool = False, parent : PlotSubCls | None = None, previous_sibling : baseItemSubCls | None = None, range : Any = ..., show : bool = True, theme : Any = ..., user_data : Any = ...):
        """
        Parameters
        ----------
        - X: Values on the X axis.
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - axes: The X and Y axes that the plot element is attached to.
        - bar_scale: Scale factor for bar heights.
        - before: Attach the item just before the target item. Default is None (disabled)
        - bins: Number of bins or automatic binning method to use.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - cumulative: Whether to display the histogram as a cumulative distribution.
        - density: Whether to normalize counts to form a probability density.
        - enabled: Whether this element is currently visible in the plot.
        - font: Font used for rendering this element's text.
        - horizontal: Whether to render the histogram with horizontal bars.
        - ignore_fit: Whether to exclude this element when auto-fitting axes.
        - label: Text label for the plot element.
        - legend_button: Mouse button that opens this element's legend popup.
        - legend_handlers: Event handlers attached to this element's legend entry.
        - next_sibling: Child of the parent rendered just after this item.
        - no_legend: Whether to hide this element from the plot legend.
        - no_outliers: Whether to exclude values outside the specified range.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - range: Optional (min, max) range for binning.
        - show: Controls whether the plot element is visible.
        - theme: Visual theme applied to the plot element.
        - user_data: User data of any type.
        """
        ...


    @property
    def bar_scale(self) -> float:
        """
        Scale factor for bar heights.

        Multiplies all bin heights by this value before display. This allows
        visual amplification or reduction of the histogram without changing the
        underlying data. Default is 1.0.

        """
        ...


    @bar_scale.setter
    def bar_scale(self, value : float):
        ...


    @property
    def bins(self) -> int:
        """
        Number of bins or automatic binning method to use.

        Accepts positive integers for explicit bin count or negative values for
        automatic binning methods:
        - -1: sqrt(n) bins [default]
        - -2: Sturges formula: k = log2(n) + 1
        - -3: Rice rule: k = 2 * cuberoot(n)
        - -4: Scott's rule: h = 3.49 sigma/cuberoot(n)

        """
        ...


    @bins.setter
    def bins(self, value : int):
        ...


    @property
    def cumulative(self) -> bool:
        """
        Whether to display the histogram as a cumulative distribution.

        When True, each bin displays a count that includes all previous bins,
        creating a cumulative distribution function (CDF). When False (default),
        each bin shows only its own count. This is useful for visualizing
        percentiles and distribution properties.

        """
        ...


    @cumulative.setter
    def cumulative(self, value : bool):
        ...


    @property
    def density(self) -> bool:
        """
        Whether to normalize counts to form a probability density.

        When True, bin heights are scaled so that the total area of the
        histogram equals 1, creating a probability density function (PDF).
        This allows comparison of distributions with different sample sizes
        and bin widths. When False (default), raw counts are displayed.

        """
        ...


    @density.setter
    def density(self, value : bool):
        ...


    @property
    def horizontal(self) -> bool:
        """
        Whether to render the histogram with horizontal bars.

        When True, histogram bars extend horizontally from the Y-axis with
        bar lengths representing bin counts. When False (default), bars extend
        vertically from the X-axis. Horizontal orientation is useful for
        better visibility of labels when dealing with many narrow bins.

        """
        ...


    @horizontal.setter
    def horizontal(self, value : bool):
        ...


    @property
    def no_outliers(self) -> bool:
        """
        Whether to exclude values outside the specified range.

        When True and a range is specified, values outside the range will not
        contribute to the counts or density. When False (default), outliers are
        counted in the edge bins. This property has no effect if no range is
        specified.

        """
        ...


    @no_outliers.setter
    def no_outliers(self, value : bool):
        ...


    @property
    def range(self):
        """
        Optional (min, max) range for binning.

        When set, only values within this range will be included in the
        histogram bins. Values outside this range are either ignored or counted
        toward the edge bins, depending on the no_outliers property. Returns
        None if no range constraint is set.

        """
        ...


    @range.setter
    def range(self, value):
        ...


class PlotHistogram2D(plotElementXY):
    """
    Plots a 2D histogram as a heatmap from X,Y coordinate pairs.

    Creates a two-dimensional histogram where the frequency of data points
    falling within each 2D bin is represented by color intensity. This is
    useful for visualizing the joint distribution of two variables, density
    estimation, and identifying clusters or patterns in bivariate data.
    Various binning methods are available for both X and Y dimensions.

    """
    def __init__(self, context : Context, X : Array = ..., Y : Array = ..., attach : Any = ..., axes : tuple = (0, 3), before : Any = ..., children : Sequence[uiItemSubCls] = [], density : bool = False, enabled : bool = True, font : Font = None, ignore_fit : bool = False, label : str = "", legend_button : MouseButton = 1, legend_handlers : list = [], next_sibling : baseItemSubCls | None = None, no_legend : bool = False, no_outliers : bool = False, parent : PlotSubCls | None = None, previous_sibling : baseItemSubCls | None = None, range_x : Any = ..., range_y : Any = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., x_bins : int = -1, y_bins : int = -1):
        """
        Parameters
        ----------
        - X: Values on the X axis.
        - Y: Values on the Y axis
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - axes: The X and Y axes that the plot element is attached to.
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - density: Whether to normalize counts to form a probability density.
        - enabled: Whether this element is currently visible in the plot.
        - font: Font used for rendering this element's text.
        - ignore_fit: Whether to exclude this element when auto-fitting axes.
        - label: Text label for the plot element.
        - legend_button: Mouse button that opens this element's legend popup.
        - legend_handlers: Event handlers attached to this element's legend entry.
        - next_sibling: Child of the parent rendered just after this item.
        - no_legend: Whether to hide this element from the plot legend.
        - no_outliers: Whether to exclude values outside the specified ranges.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - range_x: Optional (min, max) range for X-axis binning.
        - range_y: Optional (min, max) range for Y-axis binning.
        - show: Controls whether the plot element is visible.
        - theme: Visual theme applied to the plot element.
        - user_data: User data of any type.
        - x_bins: Number of X-axis bins or automatic binning method to use.
        - y_bins: Number of Y-axis bins or automatic binning method to use.
        """
        ...


    @property
    def density(self) -> bool:
        """
        Whether to normalize counts to form a probability density.

        When True, bin values are scaled so that the total volume of the
        histogram equals 1, creating a probability density function (PDF).
        This allows comparison of distributions with different sample sizes
        and bin sizes. When False (default), raw counts are displayed.

        """
        ...


    @density.setter
    def density(self, value : bool):
        ...


    @property
    def no_outliers(self) -> bool:
        """
        Whether to exclude values outside the specified ranges.

        When True and range(s) are specified, data points with coordinates
        outside the range(s) will not contribute to the counts or density. When
        False (default), outliers are counted in the edge bins. This property
        has no effect if no ranges are specified.

        """
        ...


    @no_outliers.setter
    def no_outliers(self, value : bool):
        ...


    @property
    def range_x(self):
        """
        Optional (min, max) range for X-axis binning.

        When set, only X values within this range will be included in the
        histogram bins. X values outside this range are either ignored or
        counted toward the edge bins, depending on the no_outliers property.
        Returns None if no range constraint is set.

        """
        ...


    @range_x.setter
    def range_x(self, value):
        ...


    @property
    def range_y(self):
        """
        Optional (min, max) range for Y-axis binning.

        When set, only Y values within this range will be included in the
        histogram bins. Y values outside this range are either ignored or
        counted toward the edge bins, depending on the no_outliers property.
        Returns None if no range constraint is set.

        """
        ...


    @range_y.setter
    def range_y(self, value):
        ...


    @property
    def x_bins(self) -> int:
        """
        Number of X-axis bins or automatic binning method to use.

        Accepts positive integers for explicit bin count or negative values for
        automatic binning methods:
        - -1: sqrt(n) bins [default]
        - -2: Sturges formula: k = log2(n) + 1
        - -3: Rice rule: k = 2 * cuberoot(n)
        - -4: Scott's rule: h = 3.49 sigma/cuberoot(n)

        """
        ...


    @x_bins.setter
    def x_bins(self, value : int):
        ...


    @property
    def y_bins(self) -> int:
        """
        Number of Y-axis bins or automatic binning method to use.

        Accepts positive integers for explicit bin count or negative values for
        automatic binning methods:
        - -1: sqrt(n) bins [default]
        - -2: Sturges formula: k = log2(n) + 1
        - -3: Rice rule: k = 2 * cuberoot(n)
        - -4: Scott's rule: h = 3.49 sigma/cuberoot(n)

        """
        ...


    @y_bins.setter
    def y_bins(self, value : int):
        ...


class PlotInfLines(plotElementX):
    """
    Draw infinite lines at specified positions.

    Creates vertical or horizontal lines that span the entire plot area at each
    X coordinate provided. These lines are useful for highlighting specific values,
    thresholds, or reference points across the entire plotting area.

    """
    def __init__(self, context : Context, X : Array = ..., attach : Any = ..., axes : tuple = (0, 3), before : Any = ..., children : Sequence[uiItemSubCls] = [], enabled : bool = True, font : Font = None, horizontal : bool = False, ignore_fit : bool = False, label : str = "", legend_button : MouseButton = 1, legend_handlers : list = [], next_sibling : baseItemSubCls | None = None, no_legend : bool = False, parent : PlotSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, theme : Any = ..., user_data : Any = ...):
        """
        Parameters
        ----------
        - X: Values on the X axis.
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - axes: The X and Y axes that the plot element is attached to.
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether this element is currently visible in the plot.
        - font: Font used for rendering this element's text.
        - horizontal: Whether to draw horizontal lines instead of vertical.
        - ignore_fit: Whether to exclude this element when auto-fitting axes.
        - label: Text label for the plot element.
        - legend_button: Mouse button that opens this element's legend popup.
        - legend_handlers: Event handlers attached to this element's legend entry.
        - next_sibling: Child of the parent rendered just after this item.
        - no_legend: Whether to hide this element from the plot legend.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Controls whether the plot element is visible.
        - theme: Visual theme applied to the plot element.
        - user_data: User data of any type.
        """
        ...


    @property
    def horizontal(self) -> bool:
        """
        Whether to draw horizontal lines instead of vertical.

        When True, lines are drawn horizontally across the plot at each Y position.
        When False (default), lines are drawn vertically at each X position.
        Horizontal lines span the entire width of the plot while vertical lines
        span the entire height.

        """
        ...


    @horizontal.setter
    def horizontal(self, value : bool):
        ...


class PlotLegendConfig(baseItem):
    """
    Configuration for a plot's legend.

    Controls the appearance, behavior and position of the legend in a plot.
    The legend displays labels for each plotted element and allows the user
    to toggle visibility of individual plot items. Various options control
    interaction behavior and layout.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : Sequence[baseItemSubCls] = [], horizontal : bool = False, location : LegendLocation = 5, next_sibling : baseItemSubCls | None = None, no_buttons : bool = False, no_highlight_axis : bool = False, no_highlight_item : bool = False, no_menus : bool = False, outside : bool = False, parent : baseItemSubCls | None = None, previous_sibling : baseItemSubCls | None = None, sorted : bool = False, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - horizontal: Whether to arrange legend entries horizontally instead of vertically.
        - location: Position of the legend within the plot.
        - next_sibling: Child of the parent rendered just after this item.
        - no_buttons: Whether legend icons can be clicked to hide/show plot items.
        - no_highlight_axis: Whether to disable highlighting axes on legend hover.
        - no_highlight_item: Whether to disable highlighting plot items on legend hover.
        - no_menus: Whether to disable context menus in the legend.
        - outside: Whether to render the legend outside the plot area.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - sorted: Whether to sort legend entries alphabetically.
        - user_data: User data of any type.
        """
        ...


    @property
    def horizontal(self) -> bool:
        """
        Whether to arrange legend entries horizontally instead of vertically.

        When True, legend entries will be displayed in a horizontal row rather
        than the default vertical column. This can be useful for plots with
        many elements when the legend would otherwise be too tall.

        """
        ...


    @horizontal.setter
    def horizontal(self, value : bool):
        ...


    @property
    def location(self) -> LegendLocation:
        """
        Position of the legend within the plot.

        Controls where the legend is positioned relative to the plot area.
        Default is LegendLocation.northwest (top-left corner of the plot).
        If the 'outside' property is True, this determines position outside
        the plot area.

        """
        ...


    @location.setter
    def location(self, value : LegendLocation):
        ...


    @property
    def no_buttons(self) -> bool:
        """
        Whether legend icons can be clicked to hide/show plot items.

        When True, the legend entries will not function as interactive buttons.
        Users won't be able to toggle visibility of plot elements by clicking
        on their legend entries.

        """
        ...


    @no_buttons.setter
    def no_buttons(self, value : bool):
        ...


    @property
    def no_highlight_axis(self) -> bool:
        """
        Whether to disable highlighting axes on legend hover.

        When True, hovering over an axis entry in the legend will not highlight
        that axis. Only relevant when multiple axes are enabled (X2/X3/Y2/Y3).

        """
        ...


    @no_highlight_axis.setter
    def no_highlight_axis(self, value : bool):
        ...


    @property
    def no_highlight_item(self) -> bool:
        """
        Whether to disable highlighting plot items on legend hover.

        When True, hovering over a legend entry will not highlight the
        corresponding plot item. This can be useful for dense plots where
        highlighting might be visually distracting.

        """
        ...


    @no_highlight_item.setter
    def no_highlight_item(self, value : bool):
        ...


    @property
    def no_menus(self) -> bool:
        """
        Whether to disable context menus in the legend.

        When True, right-clicking on legend entries will not open the context
        menu that provides additional options for controlling the plot. This
        simplifies the interface when these advanced features aren't needed.

        """
        ...


    @no_menus.setter
    def no_menus(self, value : bool):
        ...


    @property
    def outside(self) -> bool:
        """
        Whether to render the legend outside the plot area.

        When True, the legend will be positioned outside the main plot area,
        preserving more space for the actual plot content. The location
        property still controls which side or corner the legend appears on.

        """
        ...


    @outside.setter
    def outside(self, value : bool):
        ...


    @property
    def sorted(self) -> bool:
        """
        Whether to sort legend entries alphabetically.

        When True, legend entries will be displayed in alphabetical order
        rather than in the order they were added to the plot. This can make
        it easier to locate specific items in plots with many elements.

        """
        ...


    @sorted.setter
    def sorted(self, value : bool):
        ...


class PlotLine(plotElementXY):
    """
    Plots a line graph from X,Y data points.

    Displays a connected line through a series of data points defined by X and Y
    coordinates. Various styling options like segmented lines, closed loops,
    shading beneath the line, and NaN handling can be configured.

    """
    def __init__(self, context : Context, X : Array = ..., Y : Array = ..., attach : Any = ..., axes : tuple = (0, 3), before : Any = ..., children : Sequence[uiItemSubCls] = [], enabled : bool = True, font : Font = None, ignore_fit : bool = False, label : str = "", legend_button : MouseButton = 1, legend_handlers : list = [], loop : bool = False, next_sibling : baseItemSubCls | None = None, no_clip : bool = False, no_legend : bool = False, parent : PlotSubCls | None = None, previous_sibling : baseItemSubCls | None = None, segments : bool = False, shaded : bool = False, show : bool = True, skip_nan : bool = False, theme : Any = ..., user_data : Any = ...):
        """
        Parameters
        ----------
        - X: Values on the X axis.
        - Y: Values on the Y axis
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - axes: The X and Y axes that the plot element is attached to.
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether this element is currently visible in the plot.
        - font: Font used for rendering this element's text.
        - ignore_fit: Whether to exclude this element when auto-fitting axes.
        - label: Text label for the plot element.
        - legend_button: Mouse button that opens this element's legend popup.
        - legend_handlers: Event handlers attached to this element's legend entry.
        - loop: Whether to connect the first and last points of the line.
        - next_sibling: Child of the parent rendered just after this item.
        - no_clip: Whether to disable clipping of markers at the plot edges.
        - no_legend: Whether to hide this element from the plot legend.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - segments: Whether to draw disconnected line segments rather than a continuous line.
        - shaded: Whether to fill the area between the line and the x-axis.
        - show: Controls whether the plot element is visible.
        - skip_nan: Whether to skip NaN values instead of breaking the line.
        - theme: Visual theme applied to the plot element.
        - user_data: User data of any type.
        """
        ...


    @property
    def loop(self) -> bool:
        """
        Whether to connect the first and last points of the line.

        When enabled, the line plot becomes a closed shape by adding a segment
        from the last point back to the first point. Useful for plotting cyclic
        data or creating closed shapes.

        """
        ...


    @loop.setter
    def loop(self, value : bool):
        ...


    @property
    def no_clip(self) -> bool:
        """
        Whether to disable clipping of markers at the plot edges.

        When enabled, point markers that would normally be clipped at the edge of
        the plot will be fully visible. This can be useful for ensuring all data
        points are displayed, even when they are partially outside the plotting area.

        """
        ...


    @no_clip.setter
    def no_clip(self, value : bool):
        ...


    @property
    def segments(self) -> bool:
        """
        Whether to draw disconnected line segments rather than a continuous line.

        When enabled, line segments are drawn between consecutive points without
        connecting the whole series. Useful for representing discontinuous data
        or creating dashed/dotted effects.

        """
        ...


    @segments.setter
    def segments(self, value : bool):
        ...


    @property
    def shaded(self) -> bool:
        """
        Whether to fill the area between the line and the x-axis.

        When enabled, the region between the line and the horizontal axis will
        be filled with the line's color at reduced opacity. This is useful for
        emphasizing areas under curves or visualizing integrals.

        """
        ...


    @shaded.setter
    def shaded(self, value : bool):
        ...


    @property
    def skip_nan(self) -> bool:
        """
        Whether to skip NaN values instead of breaking the line.

        When enabled, NaN values in the data will be skipped, connecting the
        points on either side directly. When disabled, a NaN creates a break
        in the line. Useful for handling missing data points.

        """
        ...


    @skip_nan.setter
    def skip_nan(self, value : bool):
        ...


class PlotPieChart(plotElementWithLegend):
    """
    Plots a pie chart from value arrays.

    Creates a circular pie chart where each slice represents a value from the provided
    array. The chart can be positioned anywhere in the plot area and sized as needed.
    Each slice can have a label and a value displayed alongside it. The chart can
    automatically normalize values to ensure a complete circle, or maintain relative
    proportions of the values as provided.

    """
    def __init__(self, context : Context, angle : float = 90.0, attach : Any = ..., axes : tuple = (0, 3), before : Any = ..., children : Sequence[uiItemSubCls] = [], enabled : bool = True, font : Font = None, ignore_fit : bool = False, ignore_hidden : bool = False, label : str = "", label_format : str = "%.1f", labels : list = ['Slice 0'], legend_button : MouseButton = 1, legend_handlers : list = [], next_sibling : baseItemSubCls | None = None, no_legend : bool = False, normalize : bool = False, parent : PlotSubCls | None = None, previous_sibling : baseItemSubCls | None = None, radius : float = 1.0, show : bool = True, theme : Any = ..., user_data : Any = ..., values : Array = ..., x : float = 0.0, y : float = 0.0):
        """
        Parameters
        ----------
        - angle: Starting angle for first slice in degrees.
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - axes: The X and Y axes that the plot element is attached to.
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether this element is currently visible in the plot.
        - font: Font used for rendering this element's text.
        - ignore_fit: Whether to exclude this element when auto-fitting axes.
        - ignore_hidden: Whether to ignore hidden slices when drawing the pie chart.
        - label: Text label for the plot element.
        - label_format: Format string for slice value labels.
        - labels: Array of labels for each pie slice.
        - legend_button: Mouse button that opens this element's legend popup.
        - legend_handlers: Event handlers attached to this element's legend entry.
        - next_sibling: Child of the parent rendered just after this item.
        - no_legend: Whether to hide this element from the plot legend.
        - normalize: Whether to normalize values to always create a full circle.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - radius: Radius of pie chart in plot units.
        - show: Controls whether the plot element is visible.
        - theme: Visual theme applied to the plot element.
        - user_data: User data of any type.
        - values: Array of values for each pie slice.
        - x: X coordinate of pie chart center in plot units.
        - y: Y coordinate of pie chart center in plot units.
        """
        ...


    @property
    def angle(self) -> float:
        """
        Starting angle for first slice in degrees.

        Controls the rotation of the entire pie chart. The default value of 90
        places the first slice at the top. The angle increases clockwise with 0
        being at the right side of the circle.

        """
        ...


    @angle.setter
    def angle(self, value : float):
        ...


    @property
    def ignore_hidden(self) -> bool:
        """
        Whether to ignore hidden slices when drawing the pie chart.

        When enabled, slices that have been hidden (via legend toggling) will be
        completely removed from the chart as if they were not present. When disabled,
        hidden slices still take up their space in the pie but are not visible.

        """
        ...


    @ignore_hidden.setter
    def ignore_hidden(self, value : bool):
        ...


    @property
    def label_format(self) -> str:
        """
        Format string for slice value labels.

        Controls how numeric values are displayed alongside each slice. Uses
        printf-style formatting like "%.1f" for one decimal place. Set to an
        empty string to disable value labels entirely.

        """
        ...


    @label_format.setter
    def label_format(self, value : str):
        ...


    @property
    def labels(self) -> list:
        """
        Array of labels for each pie slice.

        These labels identify each slice in the chart and appear in the legend
        if enabled. If fewer labels than values are provided, default labels like
        "Slice N" will be generated for the remaining slices.

        """
        ...


    @labels.setter
    def labels(self, value : list):
        ...


    @property
    def normalize(self) -> bool:
        """
        Whether to normalize values to always create a full circle.

        When enabled, the values will be treated as relative proportions and scaled
        to fill the entire circle, regardless of their sum. When disabled, the
        slices will maintain their exact proportions, potentially not completing
        a full circle if the sum is less than the expected total.

        """
        ...


    @normalize.setter
    def normalize(self, value : bool):
        ...


    @property
    def radius(self) -> float:
        """
        Radius of pie chart in plot units.

        Controls the size of the pie chart. The radius is in plot coordinate units,
        not screen pixels, so the visual size will adjust when zooming the plot.

        """
        ...


    @radius.setter
    def radius(self, value : float):
        ...


    @property
    def values(self) -> Array:
        """
        Array of values for each pie slice.

        By default, will try to use the passed array directly for its
        internal backing (no copy). Supported types for no copy are
        np.int32, np.float32, np.float64.

        """
        ...


    @values.setter
    def values(self, value : Array):
        ...


    @property
    def x(self) -> float:
        """
        X coordinate of pie chart center in plot units.

        Determines the horizontal position of the pie chart within the plot area.
        This position is in plot coordinate space, not screen pixels.

        """
        ...


    @x.setter
    def x(self, value : float):
        ...


    @property
    def y(self) -> float:
        """
        Y coordinate of pie chart center in plot units.

        Determines the vertical position of the pie chart within the plot area.
        This position is in plot coordinate space, not screen pixels.

        """
        ...


    @y.setter
    def y(self, value : float):
        ...


class PlotScatter(plotElementXY):
    """
    Plot data points as individual markers.

    Creates a scatter plot from X,Y coordinate pairs with customizable point
    markers. Unlike line plots, scatter plots show individual data points
    without connecting lines, making them ideal for visualizing discrete
    data points, correlations, or distributions where the relationship
    between points is not continuous.

    """
    def __init__(self, context : Context, X : Array = ..., Y : Array = ..., attach : Any = ..., axes : tuple = (0, 3), before : Any = ..., children : Sequence[uiItemSubCls] = [], enabled : bool = True, font : Font = None, ignore_fit : bool = False, label : str = "", legend_button : MouseButton = 1, legend_handlers : list = [], next_sibling : baseItemSubCls | None = None, no_clip : bool = False, no_legend : bool = False, parent : PlotSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, theme : Any = ..., user_data : Any = ...):
        """
        Parameters
        ----------
        - X: Values on the X axis.
        - Y: Values on the Y axis
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - axes: The X and Y axes that the plot element is attached to.
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether this element is currently visible in the plot.
        - font: Font used for rendering this element's text.
        - ignore_fit: Whether to exclude this element when auto-fitting axes.
        - label: Text label for the plot element.
        - legend_button: Mouse button that opens this element's legend popup.
        - legend_handlers: Event handlers attached to this element's legend entry.
        - next_sibling: Child of the parent rendered just after this item.
        - no_clip: Whether to prevent clipping markers at plot edges.
        - no_legend: Whether to hide this element from the plot legend.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Controls whether the plot element is visible.
        - theme: Visual theme applied to the plot element.
        - user_data: User data of any type.
        """
        ...


    @property
    def no_clip(self) -> bool:
        """
        Whether to prevent clipping markers at plot edges.

        When True, point markers that would normally be clipped at the edge of
        the plot will be fully visible. This can be useful for ensuring all data
        points are displayed completely, even when they are partially outside
        the plotting area.

        """
        ...


    @no_clip.setter
    def no_clip(self, value : bool):
        ...


class PlotShadedLine(plotElementXYY):
    def __init__(self, context : Context, X : Array = ..., Y1 : Array = ..., Y2 : Array = ..., attach : Any = ..., axes : tuple = (0, 3), before : Any = ..., children : Sequence[uiItemSubCls] = [], enabled : bool = True, font : Font = None, ignore_fit : bool = False, label : str = "", legend_button : MouseButton = 1, legend_handlers : list = [], next_sibling : baseItemSubCls | None = None, no_legend : bool = False, parent : PlotSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, theme : Any = ..., user_data : Any = ...):
        """
        Parameters
        ----------
        - X: Values on the X axis.
        - Y1: Values on the Y1 axis.
        - Y2: Values on the Y2 axis.
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - axes: The X and Y axes that the plot element is attached to.
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether this element is currently visible in the plot.
        - font: Font used for rendering this element's text.
        - ignore_fit: Whether to exclude this element when auto-fitting axes.
        - label: Text label for the plot element.
        - legend_button: Mouse button that opens this element's legend popup.
        - legend_handlers: Event handlers attached to this element's legend entry.
        - next_sibling: Child of the parent rendered just after this item.
        - no_legend: Whether to hide this element from the plot legend.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Controls whether the plot element is visible.
        - theme: Visual theme applied to the plot element.
        - user_data: User data of any type.
        """
        ...


class PlotStairs(plotElementXY):
    """
    Plots a stair-step graph from X,Y data points.

    Creates a step function visualization where values change abruptly at each
    X coordinate rather than smoothly as in a line plot. This is useful for
    representing discrete state changes, piecewise constant functions, or
    signals that maintain a value until an event causes a change.

    """
    def __init__(self, context : Context, X : Array = ..., Y : Array = ..., attach : Any = ..., axes : tuple = (0, 3), before : Any = ..., children : Sequence[uiItemSubCls] = [], enabled : bool = True, font : Font = None, ignore_fit : bool = False, label : str = "", legend_button : MouseButton = 1, legend_handlers : list = [], next_sibling : baseItemSubCls | None = None, no_legend : bool = False, parent : PlotSubCls | None = None, pre_step : bool = False, previous_sibling : baseItemSubCls | None = None, shaded : bool = False, show : bool = True, theme : Any = ..., user_data : Any = ...):
        """
        Parameters
        ----------
        - X: Values on the X axis.
        - Y: Values on the Y axis
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - axes: The X and Y axes that the plot element is attached to.
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether this element is currently visible in the plot.
        - font: Font used for rendering this element's text.
        - ignore_fit: Whether to exclude this element when auto-fitting axes.
        - label: Text label for the plot element.
        - legend_button: Mouse button that opens this element's legend popup.
        - legend_handlers: Event handlers attached to this element's legend entry.
        - next_sibling: Child of the parent rendered just after this item.
        - no_legend: Whether to hide this element from the plot legend.
        - parent: Parent of the item in the rendering tree.
        - pre_step: Whether steps occur before or after each X position.
        - previous_sibling: Child of the parent rendered just before this item.
        - shaded: Whether to fill the area between the stairs and the axis.
        - show: Controls whether the plot element is visible.
        - theme: Visual theme applied to the plot element.
        - user_data: User data of any type.
        """
        ...


    @property
    def pre_step(self) -> bool:
        """
        Whether steps occur before or after each X position.

        When True, the Y value steps happen before (to the left of) each X
        position, making the interval (x[i-1], x[i]] have the value y[i].
        When False (default), steps happen after each X position, making the
        interval [x[i], x[i+1]) have value y[i].

        """
        ...


    @pre_step.setter
    def pre_step(self, value : bool):
        ...


    @property
    def shaded(self) -> bool:
        """
        Whether to fill the area between the stairs and the axis.

        When True, the region between the step function and the X-axis is
        filled with the line's color at reduced opacity. This creates a more
        prominent visual representation and helps emphasize the cumulative
        effect of the steps.

        """
        ...


    @shaded.setter
    def shaded(self, value : bool):
        ...


class PlotStems(plotElementXY):
    """
    Plots stem graphs from X,Y data points.

    Displays a series of data points as vertical or horizontal lines (stems)
    extending from a baseline to each point. This representation emphasizes
    individual data points and their values relative to a fixed reference.
    Useful for discrete data visualization like impulse responses or digital
    signals.

    """
    def __init__(self, context : Context, X : Array = ..., Y : Array = ..., attach : Any = ..., axes : tuple = (0, 3), before : Any = ..., children : Sequence[uiItemSubCls] = [], enabled : bool = True, font : Font = None, horizontal : bool = False, ignore_fit : bool = False, label : str = "", legend_button : MouseButton = 1, legend_handlers : list = [], next_sibling : baseItemSubCls | None = None, no_legend : bool = False, parent : PlotSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, theme : Any = ..., user_data : Any = ...):
        """
        Parameters
        ----------
        - X: Values on the X axis.
        - Y: Values on the Y axis
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - axes: The X and Y axes that the plot element is attached to.
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether this element is currently visible in the plot.
        - font: Font used for rendering this element's text.
        - horizontal: Whether to render stems horizontally instead of vertically.
        - ignore_fit: Whether to exclude this element when auto-fitting axes.
        - label: Text label for the plot element.
        - legend_button: Mouse button that opens this element's legend popup.
        - legend_handlers: Event handlers attached to this element's legend entry.
        - next_sibling: Child of the parent rendered just after this item.
        - no_legend: Whether to hide this element from the plot legend.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Controls whether the plot element is visible.
        - theme: Visual theme applied to the plot element.
        - user_data: User data of any type.
        """
        ...


    @property
    def horizontal(self) -> bool:
        """
        Whether to render stems horizontally instead of vertically.

        When True, the stems extend horizontally from the Y-axis to each data
        point. When False (default), stems extend vertically from the X-axis
        to each data point. Horizontal stems are useful when the independent
        variable is on the Y-axis.

        """
        ...


    @horizontal.setter
    def horizontal(self, value : bool):
        ...


class ProgressBar(uiItem):
    """
    A widget that displays a visual indicator of progress.

    The ProgressBar shows a filled rectangle that grows from left to right
    proportionally to the current value (0.0 to 1.0). It's useful for showing
    the status of ongoing operations, loading processes, or completion percentages.

    The appearance can be customized through themes, and optional text can be
    displayed on top of the progress indicator using the overlay property. The
    widget can also be sized explicitly through the width and height properties
    inherited from uiItem.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : None  = [], enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, overlay : str = "", parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedFloat = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : float = 0.0, width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - overlay: Optional text to display centered in the progress bar.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def overlay(self) -> str:
        """
        Optional text to display centered in the progress bar.

        This text is displayed in the center of the progress bar and can be used
        to show textual information about the progress, such as percentages or
        status messages. Leave empty for no text overlay.

        """
        ...


    @overlay.setter
    def overlay(self, value : str):
        ...


class RadioButton(uiItem):
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : None  = [], enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, horizontal : bool = False, indent : float = 0.0, items : list = [], label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedStr = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : str = "", width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - horizontal: Writable attribute: Horizontal vs vertical placement
        - indent: Horizontal indentation applied to the item.
        - items: Writable attribute: List of text values to select
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def activated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned to the active state this frame.

        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use
        event handlers instead as they provide more robust state tracking.

        """
        ...


    @property
    def active(self) -> bool:
        """
        (Read-only) Whether the item is in an active state.

        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.

        """
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def deactivated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned from active to inactive this frame.

        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.

        """
        ...


    @property
    def deactivated_after_edited(self) -> bool:
        """
        (Read-only) Whether the item was edited and then deactivated in this frame.

        Useful for detecting when user completes an edit operation, such as
        finishing text input or adjusting a value. This property is only true
        for the frame when the deactivation occurs after editing.

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def edited(self) -> bool:
        """
        (Read-only) Whether the item's value was modified this frame.

        This flag indicates that the user has made a change to the item's value,
        such as typing in an input field or adjusting a slider. It is only true
        for the frame when the edit occurs.

        """
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def horizontal(self) -> bool:
        """
        Writable attribute: Horizontal vs vertical placement

        """
        ...


    @horizontal.setter
    def horizontal(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def items(self) -> list:
        """
        Writable attribute: List of text values to select

        """
        ...


    @items.setter
    def items(self, value : list):
        ...


class RenderHandler(baseHandler):
    """
    Handler that calls the callback
    whenever the item is rendered during
    frame rendering. This doesn't mean
    that the item is visible as it can be
    occluded by an item in front of it.
    Usually rendering skips items that
    are outside the window's clipping region,
    or items that are inside a menu that is
    currently closed.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class ResizeHandler(baseHandler):
    """
    Handler that triggers the callback
    whenever the item's bounding box changes size.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class Selectable(uiItem):
    """
    A selectable item that can be clicked to change its selected state.

    Selectable widgets provide a clickable area that can maintain a selected state,
    similar to checkboxes but with more flexible styling options. They can be
    configured to behave in various ways when clicked or hovered, and can span
    across multiple columns in tables.

    Selectables are useful for creating list items, menu entries, or any UI element
    that needs to show a selected/unselected state with custom appearance. The
    selection state is stored in a SharedBool value accessible via the value
    property.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callback_on_double_click : bool = False, callbacks : Sequence[DCGCallable] = [], children : None  = [], disable_popup_close : bool = False, enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, highlighted : bool = False, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedBool = ..., show : bool = True, span_columns : bool = False, theme : Any = ..., user_data : Any = ..., value : bool = False, width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callback_on_double_click: Controls whether the selectable responds to double-clicks.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - disable_popup_close: Controls whether clicking the selectable will close parent popup windows.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - highlighted: Controls whether the selectable appears highlighted regardless of hover state.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - span_columns: Controls whether the selectable spans all columns in a table.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def activated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned to the active state this frame.

        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use
        event handlers instead as they provide more robust state tracking.

        """
        ...


    @property
    def active(self) -> bool:
        """
        (Read-only) Whether the item is in an active state.

        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.

        """
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def callback_on_double_click(self) -> bool:
        """
        Controls whether the selectable responds to double-clicks.

        When enabled, the selectable will also generate callbacks when double-clicked,
        not just on single clicks. This is useful for items where double-clicking
        might trigger a secondary action, such as opening a detailed view or
        entering an edit mode.

        """
        ...


    @callback_on_double_click.setter
    def callback_on_double_click(self, value : bool):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def deactivated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned from active to inactive this frame.

        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.

        """
        ...


    @property
    def deactivated_after_edited(self) -> bool:
        """
        (Read-only) Whether the item was edited and then deactivated in this frame.

        Useful for detecting when user completes an edit operation, such as
        finishing text input or adjusting a value. This property is only true
        for the frame when the deactivation occurs after editing.

        """
        ...


    @property
    def disable_popup_close(self) -> bool:
        """
        Controls whether clicking the selectable will close parent popup windows.

        When enabled, clicking this selectable won't automatically close any parent
        popup window that contains it. This is useful when creating popup menus
        where you want to allow multiple selections without the popup closing after
        each click.

        """
        ...


    @disable_popup_close.setter
    def disable_popup_close(self, value : bool):
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def edited(self) -> bool:
        """
        (Read-only) Whether the item's value was modified this frame.

        This flag indicates that the user has made a change to the item's value,
        such as typing in an input field or adjusting a slider. It is only true
        for the frame when the edit occurs.

        """
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def highlighted(self) -> bool:
        """
        Controls whether the selectable appears highlighted regardless of hover state.

        When enabled, the selectable will always draw with a highlighted appearance
        as if it were being hovered by the mouse, regardless of the actual hover
        state. This can be useful for drawing attention to a specific item in a
        list or indicating a special status.

        """
        ...


    @highlighted.setter
    def highlighted(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def span_columns(self) -> bool:
        """
        Controls whether the selectable spans all columns in a table.

        When enabled in a table context, the selectable's frame will span across
        all columns of its container table, while the text content will still be
        confined to the current column. This creates a visual effect where the
        highlight/selection extends across the entire row width.

        """
        ...


    @span_columns.setter
    def span_columns(self, value : bool):
        ...


class Separator(uiItem):
    """
    A horizontal line that visually separates UI elements.

    Separator creates a horizontal dividing line that spans the width of its
    parent container. It helps organize UI components by creating visual
    boundaries between different groups of elements.

    When a label is provided, the separator will display text centered on the line,
    creating a section header. Without a label, it renders as a simple line.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : None  = [], enabled : bool = True, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedValue = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : Any = ..., width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text to display centered on the separator line.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def label(self) -> str:
        """
        Text to display centered on the separator line.

        When set, creates a labeled separator that displays text centered on the
        horizontal line. This is useful for creating titled sections within a UI.
        If not set or None, renders as a plain horizontal line.

        """
        ...


    @label.setter
    def label(self, value : str):
        ...


class SharedBool(SharedValue):
    def __init__(self, context : Context, value : bool):
        ...


    @property
    def last_frame_change(self) -> int:
        """
        (Read-only) Frame index when the value was last changed to a different value.

        Records the frame number when the value actually changed. For scalar
        types, this differs from last_frame_update when a value is set to
        its current value (no actual change). For complex data types like
        vectors or colors, this equals last_frame_update for efficiency.

        """
        ...


    @property
    def last_frame_update(self) -> int:
        """
        (Read-only) Frame index when the value was last updated.

        Tracks the frame number when the value was last modified or validated,
        even if the new value was identical to the previous one. This can be
        used to detect when any access or modification attempt occurred.

        """
        ...


    @property
    def num_attached(self) -> int:
        """
        (Read-only) Number of items currently sharing this value.

        Counts how many UI items are currently using this shared value. When
        this count reaches zero, the shared value becomes eligible for garbage
        collection if no other references exist.

        """
        ...


    @property
    def shareable_value(self) -> SharedBool:
        """
        (Read-only) Reference to the shared value object itself.

        Returns a reference to this SharedValue instance, allowing it to be
        assigned to another item's shareable_value property to establish
        value sharing between items.

        This property is primarily used when connecting multiple UI elements
        to the same data source.

        """
        ...


    @property
    def value(self) -> bool:
        ...


    @value.setter
    def value(self, value : bool):
        ...


class SharedColor(SharedValue):
    def __init__(self, context : Context, value : int):
        ...


    @property
    def last_frame_change(self) -> int:
        """
        (Read-only) Frame index when the value was last changed to a different value.

        Records the frame number when the value actually changed. For scalar
        types, this differs from last_frame_update when a value is set to
        its current value (no actual change). For complex data types like
        vectors or colors, this equals last_frame_update for efficiency.

        """
        ...


    @property
    def last_frame_update(self) -> int:
        """
        (Read-only) Frame index when the value was last updated.

        Tracks the frame number when the value was last modified or validated,
        even if the new value was identical to the previous one. This can be
        used to detect when any access or modification attempt occurred.

        """
        ...


    @property
    def num_attached(self) -> int:
        """
        (Read-only) Number of items currently sharing this value.

        Counts how many UI items are currently using this shared value. When
        this count reaches zero, the shared value becomes eligible for garbage
        collection if no other references exist.

        """
        ...


    @property
    def shareable_value(self) -> SharedColor:
        """
        (Read-only) Reference to the shared value object itself.

        Returns a reference to this SharedValue instance, allowing it to be
        assigned to another item's shareable_value property to establish
        value sharing between items.

        This property is primarily used when connecting multiple UI elements
        to the same data source.

        """
        ...


    @property
    def value(self) -> int:
        ...


    @value.setter
    def value(self, value : int):
        ...


class SharedDouble(SharedValue):
    def __init__(self, context : Context, value : float):
        ...


    @property
    def last_frame_change(self) -> int:
        """
        (Read-only) Frame index when the value was last changed to a different value.

        Records the frame number when the value actually changed. For scalar
        types, this differs from last_frame_update when a value is set to
        its current value (no actual change). For complex data types like
        vectors or colors, this equals last_frame_update for efficiency.

        """
        ...


    @property
    def last_frame_update(self) -> int:
        """
        (Read-only) Frame index when the value was last updated.

        Tracks the frame number when the value was last modified or validated,
        even if the new value was identical to the previous one. This can be
        used to detect when any access or modification attempt occurred.

        """
        ...


    @property
    def num_attached(self) -> int:
        """
        (Read-only) Number of items currently sharing this value.

        Counts how many UI items are currently using this shared value. When
        this count reaches zero, the shared value becomes eligible for garbage
        collection if no other references exist.

        """
        ...


    @property
    def shareable_value(self) -> SharedDouble:
        """
        (Read-only) Reference to the shared value object itself.

        Returns a reference to this SharedValue instance, allowing it to be
        assigned to another item's shareable_value property to establish
        value sharing between items.

        This property is primarily used when connecting multiple UI elements
        to the same data source.

        """
        ...


    @property
    def value(self) -> float:
        ...


    @value.setter
    def value(self, value : float):
        ...


class SharedDouble4(SharedValue):
    def __init__(self, context : Context, value : list):
        ...


    @property
    def last_frame_change(self) -> int:
        """
        (Read-only) Frame index when the value was last changed to a different value.

        Records the frame number when the value actually changed. For scalar
        types, this differs from last_frame_update when a value is set to
        its current value (no actual change). For complex data types like
        vectors or colors, this equals last_frame_update for efficiency.

        """
        ...


    @property
    def last_frame_update(self) -> int:
        """
        (Read-only) Frame index when the value was last updated.

        Tracks the frame number when the value was last modified or validated,
        even if the new value was identical to the previous one. This can be
        used to detect when any access or modification attempt occurred.

        """
        ...


    @property
    def num_attached(self) -> int:
        """
        (Read-only) Number of items currently sharing this value.

        Counts how many UI items are currently using this shared value. When
        this count reaches zero, the shared value becomes eligible for garbage
        collection if no other references exist.

        """
        ...


    @property
    def shareable_value(self) -> SharedDouble4:
        """
        (Read-only) Reference to the shared value object itself.

        Returns a reference to this SharedValue instance, allowing it to be
        assigned to another item's shareable_value property to establish
        value sharing between items.

        This property is primarily used when connecting multiple UI elements
        to the same data source.

        """
        ...


    @property
    def value(self) -> list:
        ...


    @value.setter
    def value(self, value : list):
        ...


class SharedFloat(SharedValue):
    def __init__(self, context : Context, value : float):
        ...


    @property
    def last_frame_change(self) -> int:
        """
        (Read-only) Frame index when the value was last changed to a different value.

        Records the frame number when the value actually changed. For scalar
        types, this differs from last_frame_update when a value is set to
        its current value (no actual change). For complex data types like
        vectors or colors, this equals last_frame_update for efficiency.

        """
        ...


    @property
    def last_frame_update(self) -> int:
        """
        (Read-only) Frame index when the value was last updated.

        Tracks the frame number when the value was last modified or validated,
        even if the new value was identical to the previous one. This can be
        used to detect when any access or modification attempt occurred.

        """
        ...


    @property
    def num_attached(self) -> int:
        """
        (Read-only) Number of items currently sharing this value.

        Counts how many UI items are currently using this shared value. When
        this count reaches zero, the shared value becomes eligible for garbage
        collection if no other references exist.

        """
        ...


    @property
    def shareable_value(self) -> SharedFloat:
        """
        (Read-only) Reference to the shared value object itself.

        Returns a reference to this SharedValue instance, allowing it to be
        assigned to another item's shareable_value property to establish
        value sharing between items.

        This property is primarily used when connecting multiple UI elements
        to the same data source.

        """
        ...


    @property
    def value(self) -> float:
        ...


    @value.setter
    def value(self, value : float):
        ...


class SharedFloat4(SharedValue):
    def __init__(self, context : Context, value : list):
        ...


    @property
    def last_frame_change(self) -> int:
        """
        (Read-only) Frame index when the value was last changed to a different value.

        Records the frame number when the value actually changed. For scalar
        types, this differs from last_frame_update when a value is set to
        its current value (no actual change). For complex data types like
        vectors or colors, this equals last_frame_update for efficiency.

        """
        ...


    @property
    def last_frame_update(self) -> int:
        """
        (Read-only) Frame index when the value was last updated.

        Tracks the frame number when the value was last modified or validated,
        even if the new value was identical to the previous one. This can be
        used to detect when any access or modification attempt occurred.

        """
        ...


    @property
    def num_attached(self) -> int:
        """
        (Read-only) Number of items currently sharing this value.

        Counts how many UI items are currently using this shared value. When
        this count reaches zero, the shared value becomes eligible for garbage
        collection if no other references exist.

        """
        ...


    @property
    def shareable_value(self) -> SharedFloat4:
        """
        (Read-only) Reference to the shared value object itself.

        Returns a reference to this SharedValue instance, allowing it to be
        assigned to another item's shareable_value property to establish
        value sharing between items.

        This property is primarily used when connecting multiple UI elements
        to the same data source.

        """
        ...


    @property
    def value(self) -> list:
        ...


    @value.setter
    def value(self, value : list):
        ...


class SharedFloatVect(SharedValue):
    def __init__(self, context : Context, value : array):
        ...


    @property
    def last_frame_change(self) -> int:
        """
        (Read-only) Frame index when the value was last changed to a different value.

        Records the frame number when the value actually changed. For scalar
        types, this differs from last_frame_update when a value is set to
        its current value (no actual change). For complex data types like
        vectors or colors, this equals last_frame_update for efficiency.

        """
        ...


    @property
    def last_frame_update(self) -> int:
        """
        (Read-only) Frame index when the value was last updated.

        Tracks the frame number when the value was last modified or validated,
        even if the new value was identical to the previous one. This can be
        used to detect when any access or modification attempt occurred.

        """
        ...


    @property
    def num_attached(self) -> int:
        """
        (Read-only) Number of items currently sharing this value.

        Counts how many UI items are currently using this shared value. When
        this count reaches zero, the shared value becomes eligible for garbage
        collection if no other references exist.

        """
        ...


    @property
    def shareable_value(self) -> SharedFloatVect:
        """
        (Read-only) Reference to the shared value object itself.

        Returns a reference to this SharedValue instance, allowing it to be
        assigned to another item's shareable_value property to establish
        value sharing between items.

        This property is primarily used when connecting multiple UI elements
        to the same data source.

        """
        ...


    @property
    def value(self) -> array:
        ...


    @value.setter
    def value(self, value : array):
        ...


class SharedInt(SharedValue):
    def __init__(self, context : Context, value : int):
        ...


    @property
    def last_frame_change(self) -> int:
        """
        (Read-only) Frame index when the value was last changed to a different value.

        Records the frame number when the value actually changed. For scalar
        types, this differs from last_frame_update when a value is set to
        its current value (no actual change). For complex data types like
        vectors or colors, this equals last_frame_update for efficiency.

        """
        ...


    @property
    def last_frame_update(self) -> int:
        """
        (Read-only) Frame index when the value was last updated.

        Tracks the frame number when the value was last modified or validated,
        even if the new value was identical to the previous one. This can be
        used to detect when any access or modification attempt occurred.

        """
        ...


    @property
    def num_attached(self) -> int:
        """
        (Read-only) Number of items currently sharing this value.

        Counts how many UI items are currently using this shared value. When
        this count reaches zero, the shared value becomes eligible for garbage
        collection if no other references exist.

        """
        ...


    @property
    def shareable_value(self) -> SharedInt:
        """
        (Read-only) Reference to the shared value object itself.

        Returns a reference to this SharedValue instance, allowing it to be
        assigned to another item's shareable_value property to establish
        value sharing between items.

        This property is primarily used when connecting multiple UI elements
        to the same data source.

        """
        ...


    @property
    def value(self) -> int:
        ...


    @value.setter
    def value(self, value : int):
        ...


class SharedInt4(SharedValue):
    def __init__(self, context : Context, value : list):
        ...


    @property
    def last_frame_change(self) -> int:
        """
        (Read-only) Frame index when the value was last changed to a different value.

        Records the frame number when the value actually changed. For scalar
        types, this differs from last_frame_update when a value is set to
        its current value (no actual change). For complex data types like
        vectors or colors, this equals last_frame_update for efficiency.

        """
        ...


    @property
    def last_frame_update(self) -> int:
        """
        (Read-only) Frame index when the value was last updated.

        Tracks the frame number when the value was last modified or validated,
        even if the new value was identical to the previous one. This can be
        used to detect when any access or modification attempt occurred.

        """
        ...


    @property
    def num_attached(self) -> int:
        """
        (Read-only) Number of items currently sharing this value.

        Counts how many UI items are currently using this shared value. When
        this count reaches zero, the shared value becomes eligible for garbage
        collection if no other references exist.

        """
        ...


    @property
    def shareable_value(self) -> SharedInt4:
        """
        (Read-only) Reference to the shared value object itself.

        Returns a reference to this SharedValue instance, allowing it to be
        assigned to another item's shareable_value property to establish
        value sharing between items.

        This property is primarily used when connecting multiple UI elements
        to the same data source.

        """
        ...


    @property
    def value(self) -> list:
        ...


    @value.setter
    def value(self, value : list):
        ...


class SharedStr(SharedValue):
    def __init__(self, context : Context, value : str):
        ...


    @property
    def last_frame_change(self) -> int:
        """
        (Read-only) Frame index when the value was last changed to a different value.

        Records the frame number when the value actually changed. For scalar
        types, this differs from last_frame_update when a value is set to
        its current value (no actual change). For complex data types like
        vectors or colors, this equals last_frame_update for efficiency.

        """
        ...


    @property
    def last_frame_update(self) -> int:
        """
        (Read-only) Frame index when the value was last updated.

        Tracks the frame number when the value was last modified or validated,
        even if the new value was identical to the previous one. This can be
        used to detect when any access or modification attempt occurred.

        """
        ...


    @property
    def num_attached(self) -> int:
        """
        (Read-only) Number of items currently sharing this value.

        Counts how many UI items are currently using this shared value. When
        this count reaches zero, the shared value becomes eligible for garbage
        collection if no other references exist.

        """
        ...


    @property
    def shareable_value(self) -> SharedStr:
        """
        (Read-only) Reference to the shared value object itself.

        Returns a reference to this SharedValue instance, allowing it to be
        assigned to another item's shareable_value property to establish
        value sharing between items.

        This property is primarily used when connecting multiple UI elements
        to the same data source.

        """
        ...


    @property
    def value(self) -> str:
        ...


    @value.setter
    def value(self, value : str):
        ...


class SharedValue(object):
    """
    Represents a value that can be shared between multiple UI items.

    Shared values allow multiple UI elements to reference the same underlying data
    without duplicating it. When one item updates the value, all items sharing it
    will immediately reflect the change, providing a straightforward way to link
    elements together.

    SharedValue tracks when the value was last changed or updated, making it
    possible to detect changes and optimize rendering when the value hasn't
    been modified.

    Each concrete shared value type (like SharedFloat, SharedStr, etc.) extends
    this base class to provide type-specific functionality while maintaining
    consistent behavior around tracking and sharing.

    """
    def __init__(self, context : Context, value : Any):
        """
        Parameters
        ----------
        - value: The current value stored by this object.
        """
        ...


    @property
    def last_frame_change(self) -> int:
        """
        (Read-only) Frame index when the value was last changed to a different value.

        Records the frame number when the value actually changed. For scalar
        types, this differs from last_frame_update when a value is set to
        its current value (no actual change). For complex data types like
        vectors or colors, this equals last_frame_update for efficiency.

        """
        ...


    @property
    def last_frame_update(self) -> int:
        """
        (Read-only) Frame index when the value was last updated.

        Tracks the frame number when the value was last modified or validated,
        even if the new value was identical to the previous one. This can be
        used to detect when any access or modification attempt occurred.

        """
        ...


    @property
    def num_attached(self) -> int:
        """
        (Read-only) Number of items currently sharing this value.

        Counts how many UI items are currently using this shared value. When
        this count reaches zero, the shared value becomes eligible for garbage
        collection if no other references exist.

        """
        ...


    @property
    def shareable_value(self) -> SharedValue:
        """
        (Read-only) Reference to the shared value object itself.

        Returns a reference to this SharedValue instance, allowing it to be
        assigned to another item's shareable_value property to establish
        value sharing between items.

        This property is primarily used when connecting multiple UI elements
        to the same data source.

        """
        ...


    @property
    def value(self):
        """
        The current value stored by this object.

        This property represents the actual data being shared between UI elements.
        Reading this property returns a copy of the value. Modifying the returned
        value will not affect the shared value unless it is set back using this
        property.

        """
        ...


    @value.setter
    def value(self, value):
        ...


class SimplePlot(uiItem):
    """
    A simple plot widget that displays data as a line graph or histogram.

    This widget provides a straightforward way to visualize numerical data
    with minimal configuration. It supports both line plots and histograms,
    with automatic or manual scaling.

    The data to display is stored in a SharedFloatVect, which can be accessed
    and modified through the value property inherited from uiItem.

    """
    def __init__(self, context : Context, attach : Any = ..., autoscale : bool = True, before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : None  = [], enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, histogram : bool = False, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, overlay : str = "", parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scale_max : float = 0.0, scale_min : float = 0.0, scaling_factor : float = 1.0, shareable_value : SharedFloatVect = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : Any = ..., width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - autoscale: Controls whether the plot automatically scales to fit the data.
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - histogram: Determines if the plot displays data as a histogram.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - overlay: Text to display as an overlay on the plot.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scale_max: The maximum value of the plot's vertical scale.
        - scale_min: The minimum value of the plot's vertical scale.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def activated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned to the active state this frame.

        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use
        event handlers instead as they provide more robust state tracking.

        """
        ...


    @property
    def active(self) -> bool:
        """
        (Read-only) Whether the item is in an active state.

        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.

        """
        ...


    @property
    def autoscale(self) -> bool:
        """
        Controls whether the plot automatically scales to fit the data.

        When True, scale_min and scale_max are automatically calculated based
        on the minimum and maximum values in the data. When False, the
        manually set scale_min and scale_max values are used. Default is True.

        """
        ...


    @autoscale.setter
    def autoscale(self, value : bool):
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def deactivated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned from active to inactive this frame.

        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def histogram(self) -> bool:
        """
        Determines if the plot displays data as a histogram.

        When True, data is displayed as a bar chart (histogram). When False,
        data is displayed as a line plot. Default is False.

        """
        ...


    @histogram.setter
    def histogram(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def overlay(self) -> str:
        """
        Text to display as an overlay on the plot.

        This text appears in the top-left corner of the plot area and can
        be used to display additional information about the data being shown.

        """
        ...


    @overlay.setter
    def overlay(self, value : str):
        ...


    @property
    def scale_max(self) -> float:
        """
        The maximum value of the plot's vertical scale.

        When autoscale is False, this value defines the upper bound of the
        plot's vertical axis. Values above this threshold will be clipped.
        Ignored when autoscale is True.

        """
        ...


    @scale_max.setter
    def scale_max(self, value : float):
        ...


    @property
    def scale_min(self) -> float:
        """
        The minimum value of the plot's vertical scale.

        When autoscale is False, this value defines the lower bound of the
        plot's vertical axis. Values below this threshold will be clipped.
        Ignored when autoscale is True.

        """
        ...


    @scale_min.setter
    def scale_min(self, value : float):
        ...


class Slider(uiItem):
    """
    A widget that allows selecting values by dragging a handle along a track.

    Sliders provide an intuitive way to select numeric values within a defined
    range. They can be configured as horizontal or vertical bars, or as drag
    controls that adjust values based on mouse movement distance rather than
    absolute position.

    Sliders support several data types (int, float, double) and can display
    single values or vectors of up to 4 components. The appearance and behavior
    can be customized with various options including logarithmic scaling and
    different display formats.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : None  = [], clamped : bool = False, drag : bool = False, enabled : bool = True, focused : bool = False, font : Font = None, format : str = "float", handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", logarithmic : bool = False, max_value : float = 100.0, min_value : float = 0.0, next_sibling : baseItemSubCls | None = None, no_input : bool = False, no_newline : bool = False, no_scaling : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, print_format : str = "%.3f", round_to_format : bool = True, scaling_factor : float = 1.0, shareable_value : SharedFloat = ..., show : bool = True, size : int = 1, speed : float = 1.0, theme : Any = ..., user_data : Any = ..., value : float = 0.0, vertical : bool = False, width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - clamped: Whether the slider value should be clamped even when set via keyboard.
        - drag: Whether to use a 'drag' slider rather than a regular one.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - format: Format of the slider's data type.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - logarithmic: Whether the slider should use logarithmic scaling.
        - max_value: Maximum value the slider will be clamped to.
        - min_value: Minimum value the slider will be clamped to.
        - next_sibling: Child of the parent rendered just after this item.
        - no_input: Whether to disable keyboard input for the slider.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - print_format: Format string for converting the slider value to text for display.
        - round_to_format: Whether to round values according to the print_format.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - size: Number of components controlled by the slider.
        - speed: The speed at which the value changes when using drag mode.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - vertical: Whether to display the slider vertically instead of horizontally.
        - width: Requested width for the item.
        """
        ...


    def configure(self, callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : None  = [], clamped : bool = False, drag : bool = False, enabled : bool = True, focused : bool = False, font : Font = None, format : str = "float", handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", logarithmic : bool = False, max_value : float = 100.0, min_value : float = 0.0, next_sibling : baseItemSubCls | None = None, no_input : bool = False, no_newline : bool = False, no_scaling : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, print_format : str = "%.3f", round_to_format : bool = True, scaling_factor : float = 1.0, shareable_value : SharedFloat = ..., show : bool = True, size : int = 1, speed : float = 1.0, theme : Any = ..., user_data : Any = ..., value : float = 0.0, vertical : bool = False, width : float = 0.0):
        """
        Configure the slider with the provided keyword arguments.

        This method handles special configuration options that have
        interdependencies (format, size, logarithmic) before delegating to the
        parent class configure method for standard options.

        Parameters
        ----------
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - clamped: Whether the slider value should be clamped even when set via keyboard.
        - drag: Whether to use a 'drag' slider rather than a regular one.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - format: Format of the slider's data type.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - logarithmic: Whether the slider should use logarithmic scaling.
        - max_value: Maximum value the slider will be clamped to.
        - min_value: Minimum value the slider will be clamped to.
        - next_sibling: Child of the parent rendered just after this item.
        - no_input: Whether to disable keyboard input for the slider.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - print_format: Format string for converting the slider value to text for display.
        - round_to_format: Whether to round values according to the print_format.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - size: Number of components controlled by the slider.
        - speed: The speed at which the value changes when using drag mode.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - vertical: Whether to display the slider vertically instead of horizontally.
        - width: Requested width for the item.
        """
        ...


    @property
    def activated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned to the active state this frame.

        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use
        event handlers instead as they provide more robust state tracking.

        """
        ...


    @property
    def active(self) -> bool:
        """
        (Read-only) Whether the item is in an active state.

        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.

        """
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clamped(self) -> bool:
        """
        Whether the slider value should be clamped even when set via keyboard.

        When enabled, the value will always be restricted to the min_value and
        max_value range, even when the value is manually entered via keyboard
        input (Ctrl+Click).

        """
        ...


    @clamped.setter
    def clamped(self, value : bool):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def deactivated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned from active to inactive this frame.

        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def drag(self) -> bool:
        """
        Whether to use a 'drag' slider rather than a regular one.

        When enabled, the slider behaves as a draggable control where the value
        changes based on the distance the mouse moves, rather than the absolute
        position within a fixed track. This is incompatible with the 'vertical'
        property and will disable it if set.

        """
        ...


    @drag.setter
    def drag(self, value : bool):
        ...


    @property
    def edited(self) -> bool:
        """
        (Read-only) Whether the item's value was modified this frame.

        This flag indicates that the user has made a change to the item's value,
        such as typing in an input field or adjusting a slider. It is only true
        for the frame when the edit occurs.

        """
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def format(self) -> str:
        """
        Format of the slider's data type.

        Must be "int", "float" or "double". Note that float here means the
        32 bits version. The python float corresponds to a double.

        Changing this value will reallocate the internal value storage.

        """
        ...


    @format.setter
    def format(self, value : str):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def logarithmic(self) -> bool:
        """
        Whether the slider should use logarithmic scaling.

        When enabled, the slider will use logarithmic scaling, making it easier
        to select values across different orders of magnitude. Enabling this
        option will automatically disable round_to_format as they are not
        compatible.

        """
        ...


    @logarithmic.setter
    def logarithmic(self, value : bool):
        ...


    @property
    def max_value(self) -> float:
        """
        Maximum value the slider will be clamped to.

        This defines the upper bound of the range within which the slider can be
        adjusted. Values above this will be clamped to this maximum.

        """
        ...


    @max_value.setter
    def max_value(self, value : float):
        ...


    @property
    def min_value(self) -> float:
        """
        Minimum value the slider will be clamped to.

        This defines the lower bound of the range within which the slider can be
        adjusted. Values below this will be clamped to this minimum.

        """
        ...


    @min_value.setter
    def min_value(self, value : float):
        ...


    @property
    def no_input(self) -> bool:
        """
        Whether to disable keyboard input for the slider.

        When enabled, the slider will not respond to Ctrl+Click or Enter key
        events that would normally allow manual value entry. The slider can
        still be adjusted using the mouse.

        """
        ...


    @no_input.setter
    def no_input(self, value : bool):
        ...


    @property
    def print_format(self) -> str:
        """
        Format string for converting the slider value to text for display.

        This follows standard printf-style formatting. If round_to_format is
        enabled, the value will be rounded according to this format.

        Examples: "%.2f" for 2 decimal places, "%d" for integers.

        """
        ...


    @print_format.setter
    def print_format(self, value : str):
        ...


    @property
    def round_to_format(self) -> bool:
        """
        Whether to round values according to the print_format.

        When enabled (default), the slider's value will be rounded to match the
        precision specified in the print_format string. This ensures that the
        displayed value matches the actual value stored.

        This cannot be enabled when logarithmic is True.

        """
        ...


    @round_to_format.setter
    def round_to_format(self, value : bool):
        ...


    @property
    def size(self) -> int:
        """
        Number of components controlled by the slider.

        Can be 1, 2, 3 or 4. When size is 1, the item's value is held with a
        scalar shared value. For sizes greater than 1, the value is held with a
        vector of 4 elements (even for size 2 and 3).

        Changing this value will reallocate the internal value storage.

        """
        ...


    @size.setter
    def size(self, value : int):
        ...


    @property
    def speed(self) -> float:
        """
        The speed at which the value changes when using drag mode.

        This setting controls how quickly the value changes when dragging in drag
        mode. Higher values make the slider more sensitive to movement. Only
        applies when the drag property is set to True.

        """
        ...


    @speed.setter
    def speed(self, value : float):
        ...


    @property
    def vertical(self) -> bool:
        """
        Whether to display the slider vertically instead of horizontally.

        When enabled, the slider will be displayed as a vertical bar. This is
        only supported for sliders with size=1 and is incompatible with drag=True.
        Setting this to True will automatically set drag to False.

        """
        ...


    @vertical.setter
    def vertical(self, value : bool):
        ...


class Spacer(uiItem):
    """
    A blank area that creates space between UI elements.

    Spacer adds empty vertical or horizontal space between UI components to
    improve layout and visual separation. It can be configured with explicit
    dimensions or use the default spacing from the current style.

    Without specified dimensions, Spacer creates a standard-sized gap using the
    current style's ItemSpacing value. With dimensions, it creates an empty area
    of the precise requested size.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : None  = [], enabled : bool = True, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedValue = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : Any = ..., width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


class Subplots(uiItem):
    """
    Creates a grid of plots that share various axis properties.

    Organizes multiple Plot objects in a grid layout, allowing for shared axes,
    synchronized zooming/panning, and compact visualization of related data.
    Plots can share legends to conserve space and maintain consistency of
    visualization across the grid.

    The grid dimensions are configurable, and individual row/column sizes can
    be customized through size ratios. Plot children are added in row-major
    order by default, but can be changed to column-major ordering as needed.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : Sequence[uiItemSubCls] = [], col_major : bool = False, col_ratios : list = [], cols : int = 1, enabled : bool = True, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_align : bool = False, no_menus : bool = False, no_newline : bool = False, no_resize : bool = False, no_scaling : bool = False, no_title : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, row_ratios : list = [], rows : int = 1, scaling_factor : float = 1.0, share_legends : bool = False, shareable_value : SharedValue = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : Any = ..., width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - col_major: Whether to add plots in column-major order.
        - col_ratios: Size ratios for subplot columns.
        - cols: Number of subplot columns in the grid.
        - enabled: Whether the item is interactive and fully styled.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_align: Whether to disable subplot edge alignment.
        - no_menus: Whether to disable subplot context menus.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_resize: Whether to disable subplot resize splitters.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - no_title: Whether to hide subplot titles.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - row_ratios: Size ratios for subplot rows.
        - rows: Number of subplot rows in the grid.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - share_legends: Whether to share legend items across all subplots.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def col_major(self) -> bool:
        """
        Whether to add plots in column-major order.

        When True, child plots are arranged going down columns first, then
        across rows. When False (default), plots are arranged across rows first,
        then down columns. This affects the order in which child plots are
        assigned to grid positions.

        """
        ...


    @col_major.setter
    def col_major(self, value : bool):
        ...


    @property
    def col_ratios(self) -> list:
        """
        Size ratios for subplot columns.

        Controls the relative width of each column in the grid. For example,
        setting [1, 2, 1] would make the middle column twice as wide as the
        others. When not specified, columns have equal widths.

        """
        ...


    @col_ratios.setter
    def col_ratios(self, value : list):
        ...


    @property
    def cols(self) -> int:
        """
        Number of subplot columns in the grid.

        Controls the horizontal division of the subplot area. Each column can
        contain multiple plots depending on the number of rows. Must be at
        least 1.

        """
        ...


    @cols.setter
    def cols(self, value : int):
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def no_align(self) -> bool:
        """
        Whether to disable subplot edge alignment.

        When True, edge alignment between subplots is disabled, allowing
        for more flexible layout but potentially creating misaligned axes.
        When False, subplot edges are aligned to create a clean grid
        appearance.

        """
        ...


    @no_align.setter
    def no_align(self, value : bool):
        ...


    @property
    def no_legend(self) -> bool:
        """
        (Read-only) Whether to hide subplot legends.

        When True and share_legends is active, the shared legend is hidden.
        When False, the legend is displayed according to the legend settings
        of each individual plot or the shared legend if enabled.

        """
        ...


    @property
    def no_menus(self) -> bool:
        """
        Whether to disable subplot context menus.

        When True, right-clicking on any subplot will not open the context menu
        that provides options for fitting data, changing scales, etc. This
        simplifies the interface and prevents accidental changes to the
        appearance.

        """
        ...


    @no_menus.setter
    def no_menus(self, value : bool):
        ...


    @property
    def no_resize(self) -> bool:
        """
        Whether to disable subplot resize splitters.

        When True, the splitter bars between subplots are removed, preventing
        users from adjusting the relative sizes of individual plots. This
        ensures a consistent layout and prevents accidental resizing during
        interaction.

        """
        ...


    @no_resize.setter
    def no_resize(self, value : bool):
        ...


    @property
    def no_title(self) -> bool:
        """
        Whether to hide subplot titles.

        When True, titles of all subplot children are hidden, even if they have
        titles specified in their label property. This creates a cleaner, more
        compact appearance when titles would be redundant or unnecessary.

        """
        ...


    @no_title.setter
    def no_title(self, value : bool):
        ...


    @property
    def row_ratios(self) -> list:
        """
        Size ratios for subplot rows.

        Controls the relative height of each row in the grid. For example,
        setting [1, 2] would make the second row twice as tall as the first.
        When not specified, rows have equal heights.

        """
        ...


    @row_ratios.setter
    def row_ratios(self, value : list):
        ...


    @property
    def rows(self) -> int:
        """
        Number of subplot rows in the grid.

        Controls the vertical division of the subplot area. Each row can
        contain multiple plots depending on the number of columns. Must be
        at least 1.

        """
        ...


    @rows.setter
    def rows(self, value : int):
        ...


    @property
    def share_legends(self) -> bool:
        """
        Whether to share legend items across all subplots.

        When True, legend entries from all plots are combined into a single
        legend. This creates a cleaner appearance and avoids duplicate entries
        when the same data series appears in multiple plots. The location of
        this shared legend is determined by the first plot's legend settings.

        """
        ...


    @share_legends.setter
    def share_legends(self, value : bool):
        ...


class Tab(uiItem):
    """
    A content container that appears as a clickable tab within a TabBar.

    Tabs create labeled sections within a TabBar, allowing users to switch between
    different content panels by clicking on tab headers. When a tab is selected,
    its contents are displayed below the tab bar while other tab contents are
    hidden.

    Tabs can contain any UI element as children and support various customization
    options including positioning (leading/trailing), reordering restrictions, and
    optional close buttons. They work in conjunction with the TabBar container,
    which manages the overall tab display and interaction.

    The tab's state is stored in a SharedBool value that tracks whether it's
    currently selected/open. This allows programmatic control of tab switching in
    addition to user interaction.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : Sequence[uiItemSubCls] = [], closable : bool = False, enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", leading : bool = False, next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_reorder : bool = False, no_scaling : bool = False, no_tooltip : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedBool = ..., show : bool = True, theme : Any = ..., trailing : bool = False, user_data : Any = ..., value : bool = False, width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - closable: Whether the tab displays a close button.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - leading: Whether the tab is positioned at the left side of the tab bar.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_reorder: Whether tab reordering is disabled for this tab.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - no_tooltip: Whether tooltips are disabled for this tab.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - trailing: Whether the tab is positioned at the right side of the tab bar.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def activated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned to the active state this frame.

        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use
        event handlers instead as they provide more robust state tracking.

        """
        ...


    @property
    def active(self) -> bool:
        """
        (Read-only) Whether the item is in an active state.

        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.

        """
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def closable(self) -> bool:
        """
        Whether the tab displays a close button.

        When enabled, a small 'x' button appears on the tab that allows users to
        close the tab by clicking it. When a tab is closed this way, the tab's
        'show' property is set to False, which can be detected through handlers
        or callbacks. Closed tabs are not destroyed, just hidden.

        """
        ...


    @closable.setter
    def closable(self, value : bool):
        ...


    @property
    def deactivated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned from active to inactive this frame.

        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def leading(self) -> bool:
        """
        Whether the tab is positioned at the left side of the tab bar.

        When enabled, the tab will be positioned at the beginning of the tab bar,
        after the tab list popup button (if present). This is useful for creating
        primary or frequently used tabs that should always be visible. Setting
        this property will automatically disable the trailing property if it was
        enabled.

        """
        ...


    @leading.setter
    def leading(self, value : bool):
        ...


    @property
    def no_reorder(self) -> bool:
        """
        Whether tab reordering is disabled for this tab.

        When enabled, this tab cannot be dragged to a new position in the tab bar,
        and other tabs cannot be dragged across it. This is useful for pinning
        important tabs in a fixed position or creating sections of fixed and
        movable tabs within the same tab bar.

        """
        ...


    @no_reorder.setter
    def no_reorder(self, value : bool):
        ...


    @property
    def no_tooltip(self) -> bool:
        """
        Whether tooltips are disabled for this tab.

        When enabled, no tooltip will be displayed when hovering over this tab,
        even if a tooltip is associated with it. This can be useful for tabs with
        self-explanatory labels that don't require additional explanation, or when
        you want to selectively enable tooltips for only certain tabs.

        """
        ...


    @no_tooltip.setter
    def no_tooltip(self, value : bool):
        ...


    @property
    def toggled(self) -> bool:
        """
        (Read-only) Whether the item was just toggled open this frame.

        Applies to items that can be expanded or collapsed, such as tree nodes,
        collapsing headers, or menus. This property is only true during the frame
        when the toggle from closed to open occurs.

        """
        ...


    @property
    def trailing(self) -> bool:
        """
        Whether the tab is positioned at the right side of the tab bar.

        When enabled, the tab will be positioned at the end of the tab bar,
        before the scrolling buttons (if present). This is useful for creating
        secondary or less frequently used tabs that should be separated from the
        main tabs. Setting this property will automatically disable the leading
        property if it was enabled.

        """
        ...


    @trailing.setter
    def trailing(self, value : bool):
        ...


class TabBar(uiItem):
    """
    A container for Tab and TabButton elements that creates a tabbed interface.

    TabBar provides a horizontal row of clickable tabs that can be used to switch
    between different content panels. Each tab corresponds to a Tab widget child
    that contains its own content.

    The tab bar supports various interactive behaviors including tab reordering,
    scrolling, and automatic selection. It can also be styled using themes to
    match the overall look of your application.

    Tab elements within the TabBar can contain any UI components, allowing complex
    layouts to be organized into a compact, user-friendly interface. Only the
    content of the currently selected tab is visible, while other tab contents are
    hidden until selected.

    """
    def __init__(self, context : Context, allow_tab_scroll : bool = False, attach : Any = ..., autoselect_new_tabs : bool = False, before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : None  = [], enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_close_with_middle_mouse_button : bool = False, no_newline : bool = False, no_scaling : bool = False, no_scrolling_button : bool = False, no_tab_list_popup_button : bool = False, no_tooltip : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, reorderable : bool = False, resize_to_fit : bool = False, scaling_factor : float = 1.0, selected_overline : bool = False, shareable_value : SharedValue = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : Any = ..., width : float = 0.0):
        """
        Parameters
        ----------
        - allow_tab_scroll: Whether to add scroll buttons when tabs don't fit the available space.
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - autoselect_new_tabs: Whether newly created tabs are automatically selected.
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_close_with_middle_mouse_button: Whether closing tabs with middle mouse button is disabled.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - no_scrolling_button: Whether scrolling buttons are hidden when tabs exceed the visible area.
        - no_tab_list_popup_button: Whether the popup button for the tab list is disabled.
        - no_tooltip: Whether tooltips are disabled for all tabs in this tab bar.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - reorderable: Whether tabs can be manually dragged to reorder them.
        - resize_to_fit: Whether tabs should resize when they don't fit the available space.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - selected_overline: Whether to draw an overline marker on the selected tab.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def activated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned to the active state this frame.

        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use
        event handlers instead as they provide more robust state tracking.

        """
        ...


    @property
    def active(self) -> bool:
        """
        (Read-only) Whether the item is in an active state.

        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.

        """
        ...


    @property
    def allow_tab_scroll(self) -> bool:
        """
        Whether to add scroll buttons when tabs don't fit the available space.

        When enabled and tabs cannot fit in the available tab bar width, scroll
        buttons will appear to allow navigation through all tabs. This preserves
        the original size and appearance of each tab while ensuring all tabs
        remain accessible, even when there are many tabs or limited screen space.

        """
        ...


    @allow_tab_scroll.setter
    def allow_tab_scroll(self, value : bool):
        ...


    @property
    def autoselect_new_tabs(self) -> bool:
        """
        Whether newly created tabs are automatically selected.

        When enabled, any new tab added to the tab bar will be automatically
        selected and displayed. This is useful for workflows where a new tab
        should immediately receive focus, such as when creating a new document
        or opening a new view that requires immediate attention.

        """
        ...


    @autoselect_new_tabs.setter
    def autoselect_new_tabs(self, value : bool):
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def deactivated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned from active to inactive this frame.

        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def no_close_with_middle_mouse_button(self) -> bool:
        """
        Whether closing tabs with middle mouse button is disabled.

        When enabled, the default behavior of closing closable tabs by clicking
        them with the middle mouse button is disabled. This can be useful to
        prevent accidental closure of tabs or to enforce a specific pattern for
        closing tabs through explicit close buttons.

        """
        ...


    @no_close_with_middle_mouse_button.setter
    def no_close_with_middle_mouse_button(self, value : bool):
        ...


    @property
    def no_scrolling_button(self) -> bool:
        """
        Whether scrolling buttons are hidden when tabs exceed the visible area.

        When enabled, the arrow buttons that would normally appear when there are
        more tabs than can fit in the visible tab bar area are hidden. This forces
        users to rely on alternative navigation methods like the tab list popup or
        direct horizontal scrolling.

        """
        ...


    @no_scrolling_button.setter
    def no_scrolling_button(self, value : bool):
        ...


    @property
    def no_tab_list_popup_button(self) -> bool:
        """
        Whether the popup button for the tab list is disabled.

        When enabled, the button that would normally appear at the right side of
        the tab bar for accessing a dropdown list of all tabs is hidden. This can
        be useful for simpler interfaces or when you want to ensure users navigate
        only through the visible tabs.

        """
        ...


    @no_tab_list_popup_button.setter
    def no_tab_list_popup_button(self, value : bool):
        ...


    @property
    def no_tooltip(self) -> bool:
        """
        Whether tooltips are disabled for all tabs in this tab bar.

        When enabled, tooltips that would normally appear when hovering over tabs
        are suppressed for all tabs in this tab bar. This can be useful for
        creating a cleaner interface or when the tab labels are already clear
        enough without additional tooltip information.

        """
        ...


    @no_tooltip.setter
    def no_tooltip(self, value : bool):
        ...


    @property
    def reorderable(self) -> bool:
        """
        Whether tabs can be manually dragged to reorder them.

        When enabled, users can click and drag tabs to reposition them within
        the tab bar. New tabs will be appended at the end of the list by default.
        This provides a flexible interface where users can organize tabs according
        to their preferences.

        """
        ...


    @reorderable.setter
    def reorderable(self, value : bool):
        ...


    @property
    def resize_to_fit(self) -> bool:
        """
        Whether tabs should resize when they don't fit the available space.

        When enabled, tabs will automatically resize to smaller widths when there
        are too many to fit in the available tab bar space. This ensures all tabs
        remain visible but with potentially truncated labels. When disabled, tabs
        maintain their optimal size but may require scrolling to access.

        """
        ...


    @resize_to_fit.setter
    def resize_to_fit(self, value : bool):
        ...


    @property
    def selected_overline(self) -> bool:
        """
        Whether to draw an overline marker on the selected tab.

        When enabled, the currently selected tab will display an additional line
        along its top edge, making the active tab more visually distinct from
        inactive tabs. This can help improve visual feedback about which tab is
        currently selected, especially in interfaces with custom styling.

        """
        ...


    @selected_overline.setter
    def selected_overline(self, value : bool):
        ...


class TabButton(uiItem):
    """
    A button that appears within a tab bar without tab content.

    TabButton provides a clickable element that looks like a tab but doesn't
    have an associated panel. This is useful for creating actions within a
    tab bar, such as a "+" button to add new tabs or other special controls.

    Unlike regular Tab elements, TabButtons don't maintain a content area or
    open/closed state. They simply trigger their callbacks when clicked, making
    them ideal for implementing custom tab bar behaviors.

    TabButtons can be positioned at specific locations in the tab bar using
    the leading or trailing properties, and their appearance can be customized
    using themes.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : None  = [], enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", leading : bool = False, next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_reorder : bool = False, no_scaling : bool = False, no_tooltip : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedBool = ..., show : bool = True, theme : Any = ..., trailing : bool = False, user_data : Any = ..., value : bool = False, width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - leading: Positions the tab button at the left side of the tab bar.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_reorder: Prevents this tab button from being reordered or crossed over.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - no_tooltip: Disables the tooltip that would appear when hovering over the tab button.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - trailing: Positions the tab button at the right side of the tab bar.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def activated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned to the active state this frame.

        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use
        event handlers instead as they provide more robust state tracking.

        """
        ...


    @property
    def active(self) -> bool:
        """
        (Read-only) Whether the item is in an active state.

        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.

        """
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def deactivated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned from active to inactive this frame.

        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.

        """
        ...


    @property
    def deactivated_after_edited(self) -> bool:
        """
        (Read-only) Whether the item was edited and then deactivated in this frame.

        Useful for detecting when user completes an edit operation, such as
        finishing text input or adjusting a value. This property is only true
        for the frame when the deactivation occurs after editing.

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def edited(self) -> bool:
        """
        (Read-only) Whether the item's value was modified this frame.

        This flag indicates that the user has made a change to the item's value,
        such as typing in an input field or adjusting a slider. It is only true
        for the frame when the edit occurs.

        """
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def leading(self) -> bool:
        """
        Positions the tab button at the left side of the tab bar.

        When enabled, the tab button will be positioned at the beginning of the
        tab bar, after the tab list popup button (if present). This is useful
        for creating primary action buttons that should appear before regular
        tabs. Setting this property will automatically disable the trailing
        property if it was enabled.

        """
        ...


    @leading.setter
    def leading(self, value : bool):
        ...


    @property
    def no_reorder(self) -> bool:
        """
        Prevents this tab button from being reordered or crossed over.

        When enabled, this tab button cannot be dragged to a new position, and
        other tabs cannot be dragged across it. This is useful for pinning
        special function tabs in a fixed position within the tab bar.

        """
        ...


    @no_reorder.setter
    def no_reorder(self, value : bool):
        ...


    @property
    def no_tooltip(self) -> bool:
        """
        Disables the tooltip that would appear when hovering over the tab button.

        When enabled, no tooltip will be displayed when the mouse hovers over
        the tab button, even if a tooltip is associated with it. This can be
        useful for tab buttons that have self-explanatory icons or text labels
        that don't require additional explanation.

        """
        ...


    @no_tooltip.setter
    def no_tooltip(self, value : bool):
        ...


    @property
    def trailing(self) -> bool:
        """
        Positions the tab button at the right side of the tab bar.

        When enabled, the tab button will be positioned at the end of the tab
        bar, before the scrolling buttons (if present). This is useful for
        creating secondary action buttons that should appear after regular tabs.
        Setting this property will automatically disable the leading property
        if it was enabled.

        """
        ...


    @trailing.setter
    def trailing(self, value : bool):
        ...


class Table(baseTable):
    """
Table widget with advanced display and interaction capabilities.

    A table is a grid of cells that can contain text, images, buttons, or any other
    UI elements. This implementation provides full ImGui table functionality including
    sortable columns, scrolling, resizable columns, and customizable headers.

    Tables can be populated with data in multiple ways: directly setting cell contents,
    using row or column views, or bulk operations like append_row/col. The appearance
    and behavior can be customized through column and row configurations.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : Sequence[uiItemSubCls] = [], enabled : bool = True, flags : TableFlag = 0, font : Font = None, handlers : list = [], header : bool = False, height : float = 0.0, indent : float = 0.0, inner_width : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, num_cols_frozen : int = 0, num_cols_visible : Any = ..., num_rows_frozen : int = 0, num_rows_visible : Any = ..., parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedValue = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : Any = ..., width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - flags: Table behavior and appearance flags.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - header: Whether to display a table header row.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - inner_width: Width of the table content when horizontal scrolling is enabled.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - num_cols_frozen: Number of columns with scroll frozen.
        - num_cols_visible: Override the number of visible columns in the table.
        - num_rows_frozen: Number of rows with scroll frozen.
        - num_rows_visible: Override the number of visible rows in the table.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    def _Table__dealloc(self):
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def col_config(self) -> TableColConfigView:
        """(Read-only) Access interface for column configurations.

        This property provides a specialized view for accessing and manipulating the
        configurations for individual columns in the table. Through this view, you can
        get, set, or modify column properties like width, visibility, and sorting behavior.

        The view supports both indexing (col_config[0]) and attribute setting
        (col_config(0, 'width', 100)).

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def flags(self) -> TableFlag:
        """Table behavior and appearance flags.

        These flags control many aspects of the table's behavior, including:
        - Scrolling capabilities (horizontal, vertical)
        - Resizing behavior (fixed/flexible columns)
        - Border styles and visibility
        - Row/column highlighting
        - Sorting capabilities
        - Context menu availability

        Multiple flags can be combined using bitwise OR operations.

        """
        ...


    @flags.setter
    def flags(self, value : TableFlag):
        ...


    @property
    def header(self) -> bool:
        """Whether to display a table header row.

        When enabled, the table shows a header row at the top with column labels
        and interactive elements for sorting and resizing columns. This header
        uses the labels defined in each column's configuration.

        Disabling this hides the header entirely, which can be useful for data
        display tables where column manipulation is not needed.

        """
        ...


    @header.setter
    def header(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def inner_width(self) -> float:
        """Width of the table content when horizontal scrolling is enabled.

        This property controls the inner content width of the table, which affects
        how horizontal scrolling behaves:

        - With ScrollX disabled: This property is ignored
        - With ScrollX enabled and value = 0: Table fits within the outer width
        - With ScrollX enabled and value > 0: Table has a fixed content width
          that may be larger than the visible area, enabling horizontal scrolling

        """
        ...


    @inner_width.setter
    def inner_width(self, value : float):
        ...


    @property
    def row_config(self) -> TableRowConfigView:
        """(Read-only) Access interface for row configurations.

        This property provides a specialized view for accessing and manipulating the
        configurations for individual rows in the table. Through this view, you can
        get, set, or modify row properties like visibility, background color, and
        minimum height.

        The view supports both indexing (row_config[0]) and attribute setting
        (row_config(0, 'bg_color', (1,0,0,1))).

        """
        ...


class TableColConfig(baseItem):
    """
    Configuration for a table column.

    A table column can be hidden, stretched, resized, and more. This class provides
    properties to control all visual and behavioral aspects of a table column.

    The states can be changed programmatically but can also be modified by user
    interaction. To listen for state changes, use handlers such as:
    - ToggledOpenHandler/ToggledCloseHandler to detect when the user shows/hides the column
    - ContentResizeHandler to detect when the user resizes the column
    - HoveredHandler to detect when the user hovers over the column

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : Sequence[baseItemSubCls] = [], default_sort : bool = False, enabled : bool = True, handlers : list = [], label : str = "", next_sibling : baseItemSubCls | None = None, no_clip : bool = False, no_header_label : bool = False, no_header_width : bool = False, no_hide : bool = False, no_reorder : bool = False, no_resize : bool = False, no_scaling : bool = False, no_sort : bool = False, no_sort_ascending : bool = False, no_sort_descending : bool = False, parent : baseItemSubCls | None = None, prefer_sort_ascending : bool = False, prefer_sort_descending : bool = False, previous_sibling : baseItemSubCls | None = None, show : bool = True, stretch : Any = ..., stretch_weight : float = 1.0, user_data : Any = ..., width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - default_sort: Whether the column is set as the default sorting column.
        - enabled: Whether the column is currently enabled.
        - handlers: The event handlers bound to this column.
        - label: The text displayed in the column header.
        - next_sibling: Child of the parent rendered just after this item.
        - no_clip: Whether content in this column should be clipped.
        - no_header_label: Whether to display the column header label.
        - no_header_width: Whether to show column width when the header is hovered.
        - no_hide: Whether the column can be hidden by the user.
        - no_reorder: Whether the column can be reordered by the user.
        - no_resize: Whether the column can be resized by the user.
        - no_scaling: Whether to disable automatic DPI scaling for this column.
        - no_sort: Whether the column can be used for sorting.
        - no_sort_ascending: Whether sorting in ascending order is allowed.
        - no_sort_descending: Whether sorting in descending order is allowed.
        - parent: Parent of the item in the rendering tree.
        - prefer_sort_ascending: Whether to use ascending order for initial sort.
        - prefer_sort_descending: Whether to use descending order for initial sort.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Whether the column should be shown.
        - stretch: The column's sizing behavior.
        - stretch_weight: The weight used when stretching this column.
        - user_data: User data of any type.
        - width: The fixed width of the column in pixels.
        """
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether the column header has just been clicked.

        Returns a tuple of length 5 containing the individual test for each mouse
        button. The value is reset at the beginning of the next frame, so it's
        generally better to use handlers to react to clicks.

        """
        ...


    @property
    def default_sort(self) -> bool:
        """
        Whether the column is set as the default sorting column.

        When True, this column will be used for initial sorting when the
        table is first displayed.

        """
        ...


    @default_sort.setter
    def default_sort(self, value : bool):
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether the column header has just been double-clicked.

        Returns a tuple of length 5 containing the individual test for each mouse
        button. The value is reset at the beginning of the next frame, so it's
        generally better to use handlers to react to double-clicks.

        """
        ...


    @property
    def enabled(self) -> bool:
        """
        Whether the column is currently enabled.

        This can be changed both programmatically and through user interaction
        via the table's context menu.

        """
        ...


    @enabled.setter
    def enabled(self, value : bool):
        ...


    @property
    def handlers(self) -> list:
        """
        The event handlers bound to this column.

        Handlers can be used to react to various events like clicking, hovering,
        or enabling/disabling the column. You can add multiple handlers to respond
        to different events.

        """
        ...


    @handlers.setter
    def handlers(self, value : list):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse is currently over the column header.

        Only one element is hovered at a time, so subitems/subwindows
        take priority over their parent.

        """
        ...


    @property
    def label(self) -> str:
        """
        The text displayed in the column header.

        This label appears in the header row and is used for identifying the column.
        It's also displayed in the context menu when right-clicking on the header.

        """
        ...


    @label.setter
    def label(self, value : str):
        ...


    @property
    def no_clip(self) -> bool:
        """
        Whether content in this column should be clipped.

        When True, content that overflows the column width will not be clipped,
        which may cause it to overlap with adjacent columns.

        """
        ...


    @no_clip.setter
    def no_clip(self, value : bool):
        ...


    @property
    def no_header_label(self) -> bool:
        """
        Whether to display the column header label.

        When True, the column header will not display the label text but
        will still be interactive for sorting and other operations.

        """
        ...


    @no_header_label.setter
    def no_header_label(self, value : bool):
        ...


    @property
    def no_header_width(self) -> bool:
        """
        Whether to show column width when the header is hovered.

        When True, the column width tooltip will not be shown when hovering
        over the edge between columns.

        """
        ...


    @no_header_width.setter
    def no_header_width(self, value : bool):
        ...


    @property
    def no_hide(self) -> bool:
        """
        Whether the column can be hidden by the user.

        When True, the user will not be able to hide this column through
        the context menu.

        """
        ...


    @no_hide.setter
    def no_hide(self, value : bool):
        ...


    @property
    def no_reorder(self) -> bool:
        """
        Whether the column can be reordered by the user.

        When True, the user will not be able to drag this column header to
        change its position in the table.

        """
        ...


    @no_reorder.setter
    def no_reorder(self, value : bool):
        ...


    @property
    def no_resize(self) -> bool:
        """
        Whether the column can be resized by the user.

        When True, the user will not be able to drag the column's edge to resize it.

        """
        ...


    @no_resize.setter
    def no_resize(self, value : bool):
        ...


    @property
    def no_scaling(self) -> bool:
        """
        Whether to disable automatic DPI scaling for this column.

        By default, the requested width is multiplied by the global scale
        factor based on the viewport's DPI settings. When True, this automatic
        scaling is disabled.

        """
        ...


    @no_scaling.setter
    def no_scaling(self, value : bool):
        ...


    @property
    def no_sort(self) -> bool:
        """
        Whether the column can be used for sorting.

        When True, clicking on this column's header will not trigger
        sorting of the table.

        """
        ...


    @no_sort.setter
    def no_sort(self, value : bool):
        ...


    @property
    def no_sort_ascending(self) -> bool:
        """
        Whether sorting in ascending order is allowed.

        When True, the user will not be able to sort this column in ascending order.

        """
        ...


    @no_sort_ascending.setter
    def no_sort_ascending(self, value : bool):
        ...


    @property
    def no_sort_descending(self) -> bool:
        """
        Whether sorting in descending order is allowed.

        When True, the user will not be able to sort this column in descending order.

        """
        ...


    @no_sort_descending.setter
    def no_sort_descending(self, value : bool):
        ...


    @property
    def prefer_sort_ascending(self) -> bool:
        """
        Whether to use ascending order for initial sort.

        When True and this column is used for sorting, the initial sort
        direction will be ascending.

        """
        ...


    @prefer_sort_ascending.setter
    def prefer_sort_ascending(self, value : bool):
        ...


    @property
    def prefer_sort_descending(self) -> bool:
        """
        Whether to use descending order for initial sort.

        When True and this column is used for sorting, the initial sort
        direction will be descending.

        """
        ...


    @prefer_sort_descending.setter
    def prefer_sort_descending(self, value : bool):
        ...


    @property
    def show(self) -> bool:
        """
        Whether the column should be shown.

        This differs from 'enabled' as it cannot be changed through user interaction.
        Setting show=False will hide the column regardless of user preferences.

        """
        ...


    @show.setter
    def show(self, value : bool):
        ...


    @property
    def stretch(self):
        """
        The column's sizing behavior.

        Three values are possible:
        - True: Column will stretch based on its stretch_weight
        - False: Column has fixed width based on the width property
        - None: Column follows the table's default sizing behavior

        """
        ...


    @stretch.setter
    def stretch(self, value):
        ...


    @property
    def stretch_weight(self) -> float:
        """
        The weight used when stretching this column.

        When the column is in stretch mode (stretch=True), this weight determines
        how much space this column gets relative to other stretched columns.
        Higher values result in wider columns.

        """
        ...


    @stretch_weight.setter
    def stretch_weight(self, value : float):
        ...


    @property
    def visible(self) -> bool:
        """
        (Read-only) Whether the column is currently visible on screen.

        A column is visible when it's not clipped and is enabled.

        """
        ...


    @property
    def width(self) -> float:
        """
        The fixed width of the column in pixels.

        This is used only when the column is in fixed width mode (stretch=False).
        A value of 0 means automatic width based on content.
        Note that this width is only used when the column is initialized and won't
        update automatically after user resizing.

        """
        ...


    @width.setter
    def width(self, value : float):
        ...


class TableColumnConfig(baseItem):
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : Sequence[baseItemSubCls] = [], next_sibling : baseItemSubCls | None = None, parent : baseItemSubCls | None = None, previous_sibling : baseItemSubCls | None = None, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - user_data: User data of any type.
        """
        ...


class TablePlaceHolderParent(baseItem):
    """
    Placeholder parent to store items outside the rendering tree.

    This special container is used internally by row and column views to temporarily
    hold UI items created during a context manager block before they're assigned to
    table cells. This allows for a cleaner, more intuitive API for populating tables.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : Sequence[baseItemSubCls] = [], next_sibling : baseItemSubCls | None = None, parent : baseItemSubCls | None = None, previous_sibling : baseItemSubCls | None = None, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - user_data: User data of any type.
        """
        ...


class TableRowConfig(baseItem):
    """
    Configuration for a table row.

    A table row can be customized with various appearance and behavior settings.
    This includes hiding/showing rows, setting background colors, and defining
    minimum height requirements.

    Row configurations work alongside column configurations to provide complete
    control over the table's appearance.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., bg_color : list = [0.0, 0.0, 0.0, 0.0], children : Sequence[baseItemSubCls] = [], handlers : list = [], min_height : float = 0.0, next_sibling : baseItemSubCls | None = None, parent : baseItemSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - bg_color: Background color for the entire row.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - handlers: Event handlers bound to this row.
        - min_height: Minimum height of the row in pixels.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Controls whether the row is visible.
        - user_data: User data of any type.
        """
        ...


    @property
    def bg_color(self) -> list:
        """
        Background color for the entire row.

        This color is applied to the entire row as a background. When set to a
        non-zero value, it will blend with any theme-defined row background colors.

        """
        ...


    @bg_color.setter
    def bg_color(self, value : list):
        ...


    @property
    def handlers(self) -> list:
        """
        Event handlers bound to this row.

        Handlers can be used to respond to events related to this row.
        You can add multiple handlers to respond to different events,
        allowing for complex interactions with the row's state and appearance.

        """
        ...


    @handlers.setter
    def handlers(self, value : list):
        ...


    @property
    def min_height(self) -> float:
        """
        Minimum height of the row in pixels.

        When set to a value greater than zero, this ensures the row will be at
        least this tall, regardless of its content. This can be useful for creating
        consistent row heights or ensuring sufficient space for content.

        """
        ...


    @min_height.setter
    def min_height(self, value : float):
        ...


    @property
    def show(self) -> bool:
        """
        Controls whether the row is visible.

        When set to False, the row will be completely hidden from view and
        will not take up any space in the table. This is different from
        setting a zero height, as a zero-height row would still create
        a visible gap.

        """
        ...


    @show.setter
    def show(self, value : bool):
        ...


class Text(uiItem):
    """
    A widget that displays text with customizable appearance.

    Text widgets provide a way to show informational text in the UI with options
    for styling, wrapping, and layout. The text, stored in a SharedStr value,
    can be updated dynamically.

    Text can be customized with colors, bullets, wrapping, and can be made
    selectable.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., bullet : bool = False, callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : None  = [], color : Color = 0, enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedStr = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : str = "", width : float = 0.0, wrap : int = -1):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - bullet: Whether to display a bullet point before the text.
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - color: Color of the text displayed by the widget.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        - wrap: Width in pixels at which to wrap the text.
        """
        ...


    @property
    def activated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned to the active state this frame.

        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use
        event handlers instead as they provide more robust state tracking.

        """
        ...


    @property
    def active(self) -> bool:
        """
        (Read-only) Whether the item is in an active state.

        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.

        """
        ...


    @property
    def bullet(self) -> bool:
        """
        Whether to display a bullet point before the text.

        When enabled, a small circular bullet is drawn at the start of the text,
        similar to list items in bulleted lists. This can be useful for
        emphasizing important information or creating visual hierarchies.

        """
        ...


    @bullet.setter
    def bullet(self, value : bool):
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def color(self) -> Color:
        """
        Color of the text displayed by the widget.

        If set to 0 (default), the text uses the default color defined by the
        current theme style. Otherwise, the provided color value will be used
        to override the default text color.

        """
        ...


    @color.setter
    def color(self, value : Color):
        ...


    @property
    def deactivated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned from active to inactive this frame.

        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def wrap(self) -> int:
        """
        Width in pixels at which to wrap the text.

        Controls text wrapping behavior with these possible values:
        -1: No wrapping (default)
         0: Wrap at the edge of the window
        >0: Wrap at the specified width in pixels

        The wrap width is automatically scaled by the global scale factor
        unless DPI scaling is disabled for this widget.

        """
        ...


    @wrap.setter
    def wrap(self, value : int):
        ...


class TextValue(uiItem):
    """
    A widget that displays values from any type of SharedValue.

    TextValue provides a way to visualize the current value of any SharedValue
    in the UI. Unlike the Text widget which only displays string values, TextValue
    can display values from numeric types, vectors, colors and more.

    By connecting a SharedValue from another widget to this one through the
    shareable_value property, you can create displays that automatically
    update when the source value changes. This is useful for creating
    readouts, labels, or debugging displays that show the current state
    of interactive elements.

    The display format can be customized using printf-style format strings
    to control precision, alignment, and presentation.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : None  = [], enabled : bool = True, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, print_format : str = "%.3f", scaling_factor : float = 1.0, shareable_value : SharedFloat = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : float = 0.0, width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - print_format: The format string used to convert values to display text.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: The SharedValue object that provides the displayed value.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def print_format(self) -> str:
        """
        The format string used to convert values to display text.

        Uses printf-style format specifiers to control how values are displayed.
        For scalar values, use a single format specifier like '%d' or '%.2f'.

        For vector types, provide multiple format specifiers within a template,
        such as '[%d, %d, %d, %d]' for SharedInt4 or '(%.1f, %.1f, %.1f, %.1f)'
        for SharedFloat4.

        For SharedFloatVect, the format is applied individually to each element
        in the vector as they are displayed on separate lines.

        Examples:
          '%d' - Display integers with no decimal places
          '%.2f' - Display floats with 2 decimal places
          'Value: %g' - Add prefix text to the displayed value
          'RGB: (%.0f, %.0f, %.0f)' - Format color values as integers

        """
        ...


    @print_format.setter
    def print_format(self, value : str):
        ...


    @property
    def shareable_value(self) -> SharedFloat:
        """
        The SharedValue object that provides the displayed value.

        This property allows connecting any SharedValue object (except SharedStr)
        to this TextValue widget. The widget will display the current value and
        update automatically whenever the source value changes.

        Supported types include SharedBool, SharedInt, SharedFloat, SharedDouble,
        SharedColor, SharedInt4, SharedFloat4, SharedDouble4, and SharedFloatVect.

        For displaying string values, use the Text widget instead.

        """
        ...


    @shareable_value.setter
    def shareable_value(self, value : SharedFloat):
        ...


class Texture(baseItem):
    """
    Represents a texture that can be used in the UI or drawings.

    A texture holds image data that can be displayed in the UI or manipulated.
    Textures can be created from various array-like data sources and can be
    dynamically updated. They support different color formats, filtering modes,
    and can be read from or written to.

    """
    def __init__(self, context : Context, antialiased : bool = False, attach : Any = ..., before : Any = ..., children : Sequence[baseItemSubCls] = [], hint_dynamic : bool = False, nearest_neighbor_upsampling : int = 0, next_sibling : baseItemSubCls | None = None, parent : baseItemSubCls | None = None, previous_sibling : baseItemSubCls | None = None, user_data : Any = ..., wrap_x : bool = False, wrap_y : bool = False):
        """
        Parameters
        ----------
        - antialiased: Whether this texture uses mipmapping with anisotropic filtering for antialiasing.
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - hint_dynamic: Hint that the texture will be updated frequently.
        - nearest_neighbor_upsampling: Whether to use nearest neighbor interpolation when upscaling.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - user_data: User data of any type.
        - wrap_x: Whether to repeat the texture on x.
        - wrap_y: Whether to repeat the texture on y.
        """
        ...


    def allocate(self, width, height, num_chans, uint8=False, float32=False, no_realloc=True):
        """
        Allocate the buffer backing for the texture.

        This function is primarily useful when working with external rendering
        tools (OpenGL, etc.) and you need a texture handle without setting
        initial content. For normal texture usage, set_value will handle
        allocation automatically.

        Parameters:
        - width: Width of the target texture in pixels
        - height: Height of the target texture in pixels
        - num_chans: Number of channels (1, 2, 3, or 4)
        - uint8: Whether the texture format is unsigned bytes (default: False)
        - float32: Whether the texture format is float32 (default: False)
        - no_realloc: Whether to prevent future reallocations (default: True)

        Either uint8 or float32 must be set to True.

        """
        ...


    def gl_begin_read(self):
        """
        Lock a texture for external GL context read operations.

        This method must be called before reading from the texture in an
        external GL context. The target GL context MUST be current when calling
        this method. A GPU fence is created to ensure any previous DearCyGui
        rendering or uploads finish before the texture is read.

        """
        ...


    def gl_begin_write(self):
        """
        Lock a texture for external GL context write operations.

        This method must be called before writing to the texture in an
        external GL context. The target GL context MUST be current when calling
        this method. A GPU fence is created to ensure any previous DearCyGui
        rendering reading from the texture finishes before writing.

        """
        ...


    def gl_end_read(self):
        """
        Unlock a texture after an external GL context read operation.

        This method must be called after reading from the texture in an
        external GL context. The target GL context MUST be current when calling
        this method. A GPU fence is created to ensure DearCyGui won't write to
        the texture until the read operation has completed.

        """
        ...


    def gl_end_write(self):
        """
        Unlock a texture after an external GL context write operation.

        This method must be called after writing to the texture in an
        external GL context. The target GL context MUST be current when calling
        this method. A GPU fence is created to ensure DearCyGui won't read from
        the texture until the write operation has completed.

        """
        ...


    def read(self, x0=0, y0=0, crop_width=0, crop_height=0):
        """
        Read the texture content.

        Retrieves the current texture data, with optional cropping. The texture
        must be allocated and have content before calling this method.

        Parameters:
        - x0: X coordinate of the top-left corner of the crop (default: 0)
        - y0: Y coordinate of the top-left corner of the crop (default: 0)
        - crop_width: Width of the crop, 0 for full width (default: 0)
        - crop_height: Height of the crop, 0 for full height (default: 0)

        Returns:
        - A Cython array containing the texture data

        """
        ...


    def set_value(self, src):
        """
        Set the texture data from an array.

        The data is uploaded immediately during this call. After uploading,
        the source data can be safely discarded. If the texture already has
        content, the previous allocation will be reused if compatible.

        Supported formats:
        - Data type: uint8 (0-255) or float32 (0.0-1.0)
          (other types will be converted to float32)
        - Channels: 1 (R), 2 (RG), 3 (RGB), or 4 (RGBA)

        Note that for single-channel textures, R is duplicated to G and B
        during rendering, displaying as gray rather than red.

        """
        ...


    @property
    def antialiased(self) -> bool:
        """
        Whether this texture uses mipmapping with anisotropic filtering for antialiasing.

        When True, the texture will use mipmaps and anisotropic filtering
        to create smoother patterns when viewed at different angles and scales.
        This is particularly useful for line patterns to prevent aliasing.

        This setting is not compatible with nearest_neighbor_upsampling.

        This should be set before uploading texture data.

        """
        ...


    @antialiased.setter
    def antialiased(self, value : bool):
        ...


    @property
    def height(self) -> int:
        """
        (Read-only) Height of the current texture content in pixels.

        """
        ...


    @property
    def hint_dynamic(self) -> bool:
        """
        Hint that the texture will be updated frequently.

        This property should be set before calling set_value or allocate to
        optimize texture memory placement for frequent updates.

        """
        ...


    @hint_dynamic.setter
    def hint_dynamic(self, value : bool):
        ...


    @property
    def nearest_neighbor_upsampling(self) -> int:
        """
        Whether to use nearest neighbor interpolation when upscaling.

        When True, nearest neighbor interpolation is used instead of bilinear
        interpolation when upscaling the texture.

        This should be set before calling `set_value` or `allocate`.

        """
        ...


    @nearest_neighbor_upsampling.setter
    def nearest_neighbor_upsampling(self, value : int):
        ...


    @property
    def num_chans(self) -> int:
        """
        (Read-only) Number of channels in the current texture content.

        This value is typically 1 (grayscale), 3 (RGB), or 4 (RGBA).

        """
        ...


    @property
    def texture_id(self) -> int:
        """
        (Read-only) Internal texture ID used by the rendering backend.

        This ID may change if set_value is called and is released when the
        Texture is freed. It can be used for advanced integration with external
        rendering systems.

        """
        ...


    @property
    def width(self) -> int:
        """
        (Read-only) Width of the current texture content in pixels.

        """
        ...


    @property
    def wrap_x(self) -> bool:
        """
        Whether to repeat the texture on x.

        When set, reading outside the texture on x will
        wrap to inside the texture (GL_REPEAT), instead
        of the default clamping to the edge.

        This should be set before calling `set_value` or `allocate`.

        """
        ...


    @wrap_x.setter
    def wrap_x(self, value : bool):
        ...


    @property
    def wrap_y(self) -> bool:
        """
        Whether to repeat the texture on y.

        When set, reading outside the texture on y will
        wrap to inside the texture (GL_REPEAT), instead
        of the default clamping to the edge.

        This should be set before calling `set_value` or `allocate`.

        """
        ...


    @wrap_y.setter
    def wrap_y(self, value : bool):
        ...


class ThemeColorImGui(baseThemeColor):
    """
    Theme color parameters that affect how ImGui
    renders items.
    All colors accept three formats:
    - unsigned (encodes a rgba little-endian)
    - (r, g, b, a) with r, g, b, a as integers.
    - (r, g, b, a) with r, g, b, a as floats.

    When r, g, b, a are floats, they should be normalized
    between 0 and 1, while integers are between 0 and 255.
    If a is missing, it defaults to 255.

    Keyword Arguments:
        Text: Color for text rendering
        TextDisabled: Color for the text of disabled items
        WindowBg: Background of normal windows
        ChildBg:  Background of child windows
        PopupBg: Background of popups, menus, tooltips windows
        Border: Color of borders
        BorderShadow: Color of border shadows
        FrameBg: Background of checkbox, radio button, plot, slider, text input
        FrameBgHovered: Color of FrameBg when the item is hovered
        FrameBgActive: Color of FrameBg when the item is active
        TitleBg: Title bar
        TitleBgActive: Title bar when focused
        TitleBgCollapsed: Title bar when collapsed
        MenuBarBg: Background color of the menu bar
        ScrollbarBg: Background color of the scroll bar
        ScrollbarGrab: Color of the scroll slider
        ScrollbarGrabHovered: Color of the scroll slider when hovered
        ScrollbarGrabActive: Color of the scroll slider when selected
        CheckMark: Checkbox tick and RadioButton circle
        SliderGrab: Color of sliders
        SliderGrabActive: Color of selected sliders
        Button: Color of buttons
        ButtonHovered: Color of buttons when hovered
        ButtonActive: Color of buttons when selected
        Header: Header* colors are used for CollapsingHeader, TreeNode, Selectable, MenuItem
        HeaderHovered: Header color when hovered
        HeaderActive: Header color when clicked
        Separator: Color of separators
        SeparatorHovered: Color of separator when hovered
        SeparatorActive: Color of separator when active
        ResizeGrip: Resize grip in lower-right and lower-left corners of windows.
        ResizeGripHovered: ResizeGrip when hovered
        ResizeGripActive: ResizeGrip when clicked
        TabHovered: Tab background, when hovered
        Tab: Tab background, when tab-bar is focused & tab is unselected
        TabSelected: Tab background, when tab-bar is focused & tab is selected
        TabSelectedOverline: Tab horizontal overline, when tab-bar is focused & tab is selected
        TabDimmed: Tab background, when tab-bar is unfocused & tab is unselected
        TabDimmedSelected: Tab background, when tab-bar is unfocused & tab is selected
        TabDimmedSelectedOverline: ..horizontal overline, when tab-bar is unfocused & tab is selected
        PlotLines: Color of SimplePlot lines
        PlotLinesHovered: Color of SimplePlot lines when hovered
        PlotHistogram: Color of SimplePlot histogram
        PlotHistogramHovered: Color of SimplePlot histogram when hovered
        TableHeaderBg: Table header background
        TableBorderStrong: Table outer and header borders (prefer using Alpha=1.0 here)
        TableBorderLight: Table inner borders (prefer using Alpha=1.0 here)
        TableRowBg: Table row background (even rows)
        TableRowBgAlt: Table row background (odd rows)
        TextLink: Hyperlink color
        TextSelectedBg: Color of the background of selected text
        DragDropTarget: Rectangle highlighting a drop target
        NavCursor: Gamepad/keyboard: current highlighted item
        NavWindowingHighlight: Highlight window when using CTRL+TAB
        NavWindowingDimBg: Darken/colorize entire screen behind the CTRL+TAB window list, when active
        ModalWindowDimBg: Darken/colorize entire screen behind a modal window, when one is active

    """
    def __init__(self, context : Context, Border : Color| None = None, BorderShadow : Color| None = None, Button : Color| None = None, ButtonActive : Color| None = None, ButtonHovered : Color| None = None, CheckMark : Color| None = None, ChildBg : Color| None = None, DragDropTarget : Color| None = None, FrameBg : Color| None = None, FrameBgActive : Color| None = None, FrameBgHovered : Color| None = None, Header : Color| None = None, HeaderActive : Color| None = None, HeaderHovered : Color| None = None, MenuBarBg : Color| None = None, ModalWindowDimBg : Color| None = None, NavCursor : Color| None = None, NavWindowingDimBg : Color| None = None, NavWindowingHighlight : Color| None = None, PlotHistogram : Color| None = None, PlotHistogramHovered : Color| None = None, PlotLines : Color| None = None, PlotLinesHovered : Color| None = None, PopupBg : Color| None = None, ResizeGrip : Color| None = None, ResizeGripActive : Color| None = None, ResizeGripHovered : Color| None = None, ScrollbarBg : Color| None = None, ScrollbarGrab : Color| None = None, ScrollbarGrabActive : Color| None = None, ScrollbarGrabHovered : Color| None = None, Separator : Color| None = None, SeparatorActive : Color| None = None, SeparatorHovered : Color| None = None, SliderGrab : Color| None = None, SliderGrabActive : Color| None = None, Tab : Color| None = None, TabDimmed : Color| None = None, TabDimmedSelected : Color| None = None, TabDimmedSelectedOverline : Color| None = None, TabHovered : Color| None = None, TabSelected : Color| None = None, TabSelectedOverline : Color| None = None, TableBorderLight : Color| None = None, TableBorderStrong : Color| None = None, TableHeaderBg : Color| None = None, TableRowBg : Color| None = None, TableRowBgAlt : Color| None = None, Text : Color| None = None, TextDisabled : Color| None = None, TextLink : Color| None = None, TextSelectedBg : Color| None = None, TitleBg : Color| None = None, TitleBgActive : Color| None = None, TitleBgCollapsed : Color| None = None, WindowBg : Color| None = None, attach : Color| None = None, before : Color| None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseHandlerSubCls | None = None, previous_sibling : baseItemSubCls | None = None, user_data : Color| None = None):
        """
        Parameters
        ----------
        - Border: Color of borders.
        - BorderShadow: Color of border shadows.
        - Button: Button color.
        - ButtonActive: Button color when active.
        - ButtonHovered: Button color when hovered.
        - CheckMark: Checkmark color.
        - ChildBg: Background of child windows.
        - DragDropTarget: Rectangle highlighting a drop target.
        - FrameBg: Background of checkbox, radio button, plot, slider, text input.
        - FrameBgActive: Color of FrameBg when the item is active.
        - FrameBgHovered: Color of FrameBg when the item is hovered.
        - Header: Colors used for CollapsingHeader, TreeNode, Selectable, MenuItem.
        - HeaderActive: Header colors when activated/clicked.
        - HeaderHovered: Header colors when hovered.
        - MenuBarBg: Menu bar background color.
        - ModalWindowDimBg: Darken/colorize entire screen behind a modal window.
        - NavCursor: Color of keyboard/gamepad navigation cursor/rectangle, when visible.
        - NavWindowingDimBg: Darken/colorize entire screen behind CTRL+TAB window list.
        - NavWindowingHighlight: Highlight window when using CTRL+TAB.
        - PlotHistogram: Color of SimplePlot histogram.
        - PlotHistogramHovered: Color of SimplePlot histogram when hovered.
        - PlotLines: Color of SimplePlot lines.
        - PlotLinesHovered: Color of SimplePlot lines when hovered.
        - PopupBg: Background of popups, menus, tooltips windows.
        - ResizeGrip: Resize grip in lower-right and lower-left corners of windows.
        - ResizeGripActive: ResizeGrip color when clicked.
        - ResizeGripHovered: ResizeGrip color when hovered.
        - ScrollbarBg: Scrollbar background color.
        - ScrollbarGrab: Scrollbar grab color.
        - ScrollbarGrabActive: Scrollbar grab color when active.
        - ScrollbarGrabHovered: Scrollbar grab color when hovered.
        - Separator: Color of separating lines.
        - SeparatorActive: Separator color when active.
        - SeparatorHovered: Separator color when hovered.
        - SliderGrab: Slider grab color.
        - SliderGrabActive: Slider grab color when active.
        - Tab: Tab background when tab-bar is focused & tab is unselected.
        - TabDimmed: Tab background when tab-bar is unfocused & tab is unselected.
        - TabDimmedSelected: Tab background when tab-bar is unfocused & tab is selected.
        - TabDimmedSelectedOverline: Tab horizontal overline when tab-bar is unfocused & tab is selected.
        - TabHovered: Tab background when hovered.
        - TabSelected: Tab background when tab-bar is focused & tab is selected.
        - TabSelectedOverline: Tab horizontal overline when tab-bar is focused & tab is selected.
        - TableBorderLight: Table inner borders (prefer using Alpha=1.0 here).
        - TableBorderStrong: Table outer borders and headers (prefer using Alpha=1.0 here).
        - TableHeaderBg: Table header background.
        - TableRowBg: Table row background (even rows).
        - TableRowBgAlt: Table row background (odd rows).
        - Text: Color for text rendering.
        - TextDisabled: Color for the text of disabled items.
        - TextLink: Hyperlink color.
        - TextSelectedBg: Background color of selected text.
        - TitleBg: Title bar color.
        - TitleBgActive: Title bar color when focused.
        - TitleBgCollapsed: Title bar color when collapsed.
        - WindowBg: Background of normal windows.
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the theme is currently active.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - user_data: User data of any type.
        """
        ...


    @property
    def Border(self) -> Color| None:
        """Color of borders.
        Default: (0.43, 0.43, 0.50, 0.50)
        """
        ...


    @Border.setter
    def Border(self, value : Color| None):
        ...


    @property
    def BorderShadow(self) -> Color| None:
        """Color of border shadows.
        Default: (0.00, 0.00, 0.00, 0.00)
        """
        ...


    @BorderShadow.setter
    def BorderShadow(self, value : Color| None):
        ...


    @property
    def Button(self) -> Color| None:
        """Button color.
        Default: (0.26, 0.59, 0.98, 0.40)
        """
        ...


    @Button.setter
    def Button(self, value : Color| None):
        ...


    @property
    def ButtonActive(self) -> Color| None:
        """Button color when active.
        Default: (0.06, 0.53, 0.98, 1.00)
        """
        ...


    @ButtonActive.setter
    def ButtonActive(self, value : Color| None):
        ...


    @property
    def ButtonHovered(self) -> Color| None:
        """Button color when hovered.
        Default: (0.26, 0.59, 0.98, 1.00)
        """
        ...


    @ButtonHovered.setter
    def ButtonHovered(self, value : Color| None):
        ...


    @property
    def CheckMark(self) -> Color| None:
        """Checkmark color.
        Default: (0.26, 0.59, 0.98, 1.00)
        """
        ...


    @CheckMark.setter
    def CheckMark(self, value : Color| None):
        ...


    @property
    def ChildBg(self) -> Color| None:
        """Background of child windows.
        Default: (0.00, 0.00, 0.00, 0.00)
        """
        ...


    @ChildBg.setter
    def ChildBg(self, value : Color| None):
        ...


    @property
    def DragDropTarget(self) -> Color| None:
        """Rectangle highlighting a drop target.
        Default: (1.00, 1.00, 0.00, 0.90)
        """
        ...


    @DragDropTarget.setter
    def DragDropTarget(self, value : Color| None):
        ...


    @property
    def FrameBg(self) -> Color| None:
        """Background of checkbox, radio button, plot, slider, text input.
        Default: (0.16, 0.29, 0.48, 0.54)
        """
        ...


    @FrameBg.setter
    def FrameBg(self, value : Color| None):
        ...


    @property
    def FrameBgActive(self) -> Color| None:
        """Color of FrameBg when the item is active.
        Default: (0.26, 0.59, 0.98, 0.67)
        """
        ...


    @FrameBgActive.setter
    def FrameBgActive(self, value : Color| None):
        ...


    @property
    def FrameBgHovered(self) -> Color| None:
        """Color of FrameBg when the item is hovered.
        Default: (0.26, 0.59, 0.98, 0.40)
        """
        ...


    @FrameBgHovered.setter
    def FrameBgHovered(self, value : Color| None):
        ...


    @property
    def Header(self) -> Color| None:
        """Colors used for CollapsingHeader, TreeNode, Selectable, MenuItem.
        Default: (0.26, 0.59, 0.98, 0.31)
        """
        ...


    @Header.setter
    def Header(self, value : Color| None):
        ...


    @property
    def HeaderActive(self) -> Color| None:
        """Header colors when activated/clicked.
        Default: (0.26, 0.59, 0.98, 1.00)
        """
        ...


    @HeaderActive.setter
    def HeaderActive(self, value : Color| None):
        ...


    @property
    def HeaderHovered(self) -> Color| None:
        """Header colors when hovered.
        Default: (0.26, 0.59, 0.98, 0.80)
        """
        ...


    @HeaderHovered.setter
    def HeaderHovered(self, value : Color| None):
        ...


    @property
    def MenuBarBg(self) -> Color| None:
        """Menu bar background color.
        Default: (0.14, 0.14, 0.14, 1.00)
        """
        ...


    @MenuBarBg.setter
    def MenuBarBg(self, value : Color| None):
        ...


    @property
    def ModalWindowDimBg(self) -> Color| None:
        """Darken/colorize entire screen behind a modal window.
        Default: (0.80, 0.80, 0.80, 0.35)
        """
        ...


    @ModalWindowDimBg.setter
    def ModalWindowDimBg(self, value : Color| None):
        ...


    @property
    def NavCursor(self) -> Color| None:
        """Color of keyboard/gamepad navigation cursor/rectangle, when visible.
        Default: Same as HeaderHovered (0.26, 0.59, 0.98, 1.00)
        """
        ...


    @NavCursor.setter
    def NavCursor(self, value : Color| None):
        ...


    @property
    def NavWindowingDimBg(self) -> Color| None:
        """Darken/colorize entire screen behind CTRL+TAB window list.
        Default: (0.80, 0.80, 0.80, 0.20)
        """
        ...


    @NavWindowingDimBg.setter
    def NavWindowingDimBg(self, value : Color| None):
        ...


    @property
    def NavWindowingHighlight(self) -> Color| None:
        """Highlight window when using CTRL+TAB.
        Default: (1.00, 1.00, 1.00, 0.70)
        """
        ...


    @NavWindowingHighlight.setter
    def NavWindowingHighlight(self, value : Color| None):
        ...


    @property
    def PlotHistogram(self) -> Color| None:
        """Color of SimplePlot histogram.
        Default: (0.90, 0.70, 0.00, 1.00)
        """
        ...


    @PlotHistogram.setter
    def PlotHistogram(self, value : Color| None):
        ...


    @property
    def PlotHistogramHovered(self) -> Color| None:
        """Color of SimplePlot histogram when hovered.
        Default: (1.00, 0.60, 0.00, 1.00)
        """
        ...


    @PlotHistogramHovered.setter
    def PlotHistogramHovered(self, value : Color| None):
        ...


    @property
    def PlotLines(self) -> Color| None:
        """Color of SimplePlot lines.
        Default: (0.61, 0.61, 0.61, 1.00)
        """
        ...


    @PlotLines.setter
    def PlotLines(self, value : Color| None):
        ...


    @property
    def PlotLinesHovered(self) -> Color| None:
        """Color of SimplePlot lines when hovered.
        Default: (1.00, 0.43, 0.35, 1.00)
        """
        ...


    @PlotLinesHovered.setter
    def PlotLinesHovered(self, value : Color| None):
        ...


    @property
    def PopupBg(self) -> Color| None:
        """Background of popups, menus, tooltips windows.
        Default: (0.08, 0.08, 0.08, 0.94)
        """
        ...


    @PopupBg.setter
    def PopupBg(self, value : Color| None):
        ...


    @property
    def ResizeGrip(self) -> Color| None:
        """Resize grip in lower-right and lower-left corners of windows.
        Default: (0.26, 0.59, 0.98, 0.20)
        """
        ...


    @ResizeGrip.setter
    def ResizeGrip(self, value : Color| None):
        ...


    @property
    def ResizeGripActive(self) -> Color| None:
        """ResizeGrip color when clicked.
        Default: (0.26, 0.59, 0.98, 0.95)
        """
        ...


    @ResizeGripActive.setter
    def ResizeGripActive(self, value : Color| None):
        ...


    @property
    def ResizeGripHovered(self) -> Color| None:
        """ResizeGrip color when hovered.
        Default: (0.26, 0.59, 0.98, 0.67)
        """
        ...


    @ResizeGripHovered.setter
    def ResizeGripHovered(self, value : Color| None):
        ...


    @property
    def ScrollbarBg(self) -> Color| None:
        """Scrollbar background color.
        Default: (0.02, 0.02, 0.02, 0.53)
        """
        ...


    @ScrollbarBg.setter
    def ScrollbarBg(self, value : Color| None):
        ...


    @property
    def ScrollbarGrab(self) -> Color| None:
        """Scrollbar grab color.
        Default: (0.31, 0.31, 0.31, 1.00)
        """
        ...


    @ScrollbarGrab.setter
    def ScrollbarGrab(self, value : Color| None):
        ...


    @property
    def ScrollbarGrabActive(self) -> Color| None:
        """Scrollbar grab color when active.
        Default: (0.51, 0.51, 0.51, 1.00)
        """
        ...


    @ScrollbarGrabActive.setter
    def ScrollbarGrabActive(self, value : Color| None):
        ...


    @property
    def ScrollbarGrabHovered(self) -> Color| None:
        """Scrollbar grab color when hovered.
        Default: (0.41, 0.41, 0.41, 1.00)
        """
        ...


    @ScrollbarGrabHovered.setter
    def ScrollbarGrabHovered(self, value : Color| None):
        ...


    @property
    def Separator(self) -> Color| None:
        """Color of separating lines.
        Default: Same as Border color (0.43, 0.43, 0.50, 0.50)
        """
        ...


    @Separator.setter
    def Separator(self, value : Color| None):
        ...


    @property
    def SeparatorActive(self) -> Color| None:
        """Separator color when active.
        Default: (0.10, 0.40, 0.75, 1.00)
        """
        ...


    @SeparatorActive.setter
    def SeparatorActive(self, value : Color| None):
        ...


    @property
    def SeparatorHovered(self) -> Color| None:
        """Separator color when hovered.
        Default: (0.10, 0.40, 0.75, 0.78)
        """
        ...


    @SeparatorHovered.setter
    def SeparatorHovered(self, value : Color| None):
        ...


    @property
    def SliderGrab(self) -> Color| None:
        """Slider grab color.
        Default: (0.24, 0.52, 0.88, 1.00)
        """
        ...


    @SliderGrab.setter
    def SliderGrab(self, value : Color| None):
        ...


    @property
    def SliderGrabActive(self) -> Color| None:
        """Slider grab color when active.
        Default: (0.26, 0.59, 0.98, 1.00)
        """
        ...


    @SliderGrabActive.setter
    def SliderGrabActive(self, value : Color| None):
        ...


    @property
    def Tab(self) -> Color| None:
        """Tab background when tab-bar is focused & tab is unselected.
        Default: Value interpolated between Header and TitleBgActive colors with factor 0.80
        """
        ...


    @Tab.setter
    def Tab(self, value : Color| None):
        ...


    @property
    def TabDimmed(self) -> Color| None:
        """Tab background when tab-bar is unfocused & tab is unselected.
        Default: Value interpolated between Tab and TitleBg colors with factor 0.80
        """
        ...


    @TabDimmed.setter
    def TabDimmed(self, value : Color| None):
        ...


    @property
    def TabDimmedSelected(self) -> Color| None:
        """Tab background when tab-bar is unfocused & tab is selected.
        Default: Value interpolated between TabSelected and TitleBg colors with factor 0.40
        """
        ...


    @TabDimmedSelected.setter
    def TabDimmedSelected(self, value : Color| None):
        ...


    @property
    def TabDimmedSelectedOverline(self) -> Color| None:
        """Tab horizontal overline when tab-bar is unfocused & tab is selected.
        Default: (0.50, 0.50, 0.50, 1.00)
        """
        ...


    @TabDimmedSelectedOverline.setter
    def TabDimmedSelectedOverline(self, value : Color| None):
        ...


    @property
    def TabHovered(self) -> Color| None:
        """Tab background when hovered.
        Default: Same as HeaderHovered color
        """
        ...


    @TabHovered.setter
    def TabHovered(self, value : Color| None):
        ...


    @property
    def TabSelected(self) -> Color| None:
        """Tab background when tab-bar is focused & tab is selected.
        Default: Value interpolated between HeaderActive and TitleBgActive colors with factor 0.60
        """
        ...


    @TabSelected.setter
    def TabSelected(self, value : Color| None):
        ...


    @property
    def TabSelectedOverline(self) -> Color| None:
        """Tab horizontal overline when tab-bar is focused & tab is selected.
        Default: Same as HeaderActive color
        """
        ...


    @TabSelectedOverline.setter
    def TabSelectedOverline(self, value : Color| None):
        ...


    @property
    def TableBorderLight(self) -> Color| None:
        """Table inner borders (prefer using Alpha=1.0 here).
        Default: (0.23, 0.23, 0.25, 1.00)
        """
        ...


    @TableBorderLight.setter
    def TableBorderLight(self, value : Color| None):
        ...


    @property
    def TableBorderStrong(self) -> Color| None:
        """Table outer borders and headers (prefer using Alpha=1.0 here).
        Default: (0.31, 0.31, 0.35, 1.00)
        """
        ...


    @TableBorderStrong.setter
    def TableBorderStrong(self, value : Color| None):
        ...


    @property
    def TableHeaderBg(self) -> Color| None:
        """Table header background.
        Default: (0.19, 0.19, 0.20, 1.00)
        """
        ...


    @TableHeaderBg.setter
    def TableHeaderBg(self, value : Color| None):
        ...


    @property
    def TableRowBg(self) -> Color| None:
        """Table row background (even rows).
        Default: (0.00, 0.00, 0.00, 0.00)
        """
        ...


    @TableRowBg.setter
    def TableRowBg(self, value : Color| None):
        ...


    @property
    def TableRowBgAlt(self) -> Color| None:
        """Table row background (odd rows).
        Default: (1.00, 1.00, 1.00, 0.06)
        """
        ...


    @TableRowBgAlt.setter
    def TableRowBgAlt(self, value : Color| None):
        ...


    @property
    def Text(self) -> Color| None:
        """Color for text rendering.
        Default: (1.00, 1.00, 1.00, 1.00)
        """
        ...


    @Text.setter
    def Text(self, value : Color| None):
        ...


    @property
    def TextDisabled(self) -> Color| None:
        """Color for the text of disabled items.
        Default: (0.50, 0.50, 0.50, 1.00)
        """
        ...


    @TextDisabled.setter
    def TextDisabled(self, value : Color| None):
        ...


    @property
    def TextLink(self) -> Color| None:
        """Hyperlink color.
        Default: Same as HeaderActive color
        """
        ...


    @TextLink.setter
    def TextLink(self, value : Color| None):
        ...


    @property
    def TextSelectedBg(self) -> Color| None:
        """Background color of selected text.
        Default: (0.26, 0.59, 0.98, 0.35)
        """
        ...


    @TextSelectedBg.setter
    def TextSelectedBg(self, value : Color| None):
        ...


    @property
    def TitleBg(self) -> Color| None:
        """Title bar color.
        Default: (0.04, 0.04, 0.04, 1.00)
        """
        ...


    @TitleBg.setter
    def TitleBg(self, value : Color| None):
        ...


    @property
    def TitleBgActive(self) -> Color| None:
        """Title bar color when focused.
        Default: (0.16, 0.29, 0.48, 1.00)
        """
        ...


    @TitleBgActive.setter
    def TitleBgActive(self, value : Color| None):
        ...


    @property
    def TitleBgCollapsed(self) -> Color| None:
        """Title bar color when collapsed.
        Default: (0.00, 0.00, 0.00, 0.51)
        """
        ...


    @TitleBgCollapsed.setter
    def TitleBgCollapsed(self, value : Color| None):
        ...


    @property
    def WindowBg(self) -> Color| None:
        """Background of normal windows.
        Default: (0.06, 0.06, 0.06, 0.94)
        """
        ...


    @WindowBg.setter
    def WindowBg(self, value : Color| None):
        ...


class ThemeColorImPlot(baseThemeColor):
    """
    Theme color parameters that affect how ImPlot renders plots.
    All colors accept three formats:
    - unsigned (encodes a rgba little-endian)
    - (r, g, b, a) with r, g, b, a as integers.
    - (r, g, b, a) with r, g, b, a as floats.

    When r, g, b, a are floats, they should be normalized
    between 0 and 1, while integers are between 0 and 255.
    If a is missing, it defaults to 255.

    Keyword Arguments:
        Line: Plot line color. Auto - derived from Text color
        Fill: Plot fill color. Auto - derived from Line color
        MarkerOutline: Plot marker outline color. Auto - derived from Line color
        MarkerFill: Plot marker fill color. Auto - derived from Line color
        ErrorBar: Error bar color. Auto - derived from Text color
        FrameBg: Plot frame background color. Auto - derived from FrameBg color
        PlotBg: Plot area background color. Auto - derived from WindowBg color
        PlotBorder: Plot area border color. Auto - derived from Border color
        LegendBg: Legend background color. Auto - derived from PopupBg color
        LegendBorder: Legend border color. Auto - derived from Border color
        LegendText: Legend text color. Auto - derived from Text color
        TitleText: Plot title text color. Auto - derived from Text color
        InlayText: Color of text appearing inside plots. Auto - derived from Text color
        AxisText: Axis text labels color. Auto - derived from Text color
        AxisGrid: Axis grid color. Auto - derived from Text color with reduced alpha
        AxisTick: Axis tick marks color. Auto - derived from AxisGrid color
        AxisBg: Background color of axis hover region. Auto - transparent
        AxisBgHovered: Axis background color when hovered. Auto - derived from ButtonHovered color
        AxisBgActive: Axis background color when clicked. Auto - derived from ButtonActive color
        Selection: Box-selection color. Default: (1.00, 1.00, 0.00, 1.00)
        Crosshairs: Crosshairs color. Auto - derived from PlotBorder color

    """
    def __init__(self, context : Context, AxisBg : Color| None = None, AxisBgActive : Color| None = None, AxisBgHovered : Color| None = None, AxisGrid : Color| None = None, AxisText : Color| None = None, AxisTick : Color| None = None, Crosshairs : Color| None = None, ErrorBar : Color| None = None, Fill : Color| None = None, FrameBg : Color| None = None, InlayText : Color| None = None, LegendBg : Color| None = None, LegendBorder : Color| None = None, LegendText : Color| None = None, Line : Color| None = None, MarkerFill : Color| None = None, MarkerOutline : Color| None = None, PlotBg : Color| None = None, PlotBorder : Color| None = None, Selection : Color| None = None, TitleText : Color| None = None, attach : Color| None = None, before : Color| None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseHandlerSubCls | None = None, previous_sibling : baseItemSubCls | None = None, user_data : Color| None = None):
        """
        Parameters
        ----------
        - AxisBg: Background color of axis hover region.
        - AxisBgActive: Axis background color when clicked.
        - AxisBgHovered: Axis background color when hovered.
        - AxisGrid: Axis grid color.
        - AxisText: Axis text labels color.
        - AxisTick: Axis tick marks color.
        - Crosshairs: Crosshairs color.
        - ErrorBar: Error bar color.
        - Fill: Plot fill color.
        - FrameBg: Plot frame background color.
        - InlayText: Color of text appearing inside of plots.
        - LegendBg: Legend background color.
        - LegendBorder: Legend border color.
        - LegendText: Legend text color.
        - Line: Plot line color.
        - MarkerFill: Plot marker fill color.
        - MarkerOutline: Plot marker outline color.
        - PlotBg: Plot area background color.
        - PlotBorder: Plot area border color.
        - Selection: Box-selection color.
        - TitleText: Plot title text color.
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the theme is currently active.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - user_data: User data of any type.
        """
        ...


    @property
    def AxisBg(self) -> Color| None:
        """Background color of axis hover region.
        Default: transparent
        """
        ...


    @AxisBg.setter
    def AxisBg(self, value : Color| None):
        ...


    @property
    def AxisBgActive(self) -> Color| None:
        """Axis background color when clicked.
        Default: Auto - derived from ButtonActive color
        """
        ...


    @AxisBgActive.setter
    def AxisBgActive(self, value : Color| None):
        ...


    @property
    def AxisBgHovered(self) -> Color| None:
        """Axis background color when hovered.
        Default: Auto - derived from ButtonHovered color
        """
        ...


    @AxisBgHovered.setter
    def AxisBgHovered(self, value : Color| None):
        ...


    @property
    def AxisGrid(self) -> Color| None:
        """Axis grid color.
        Default: Auto - derived from Text color
        """
        ...


    @AxisGrid.setter
    def AxisGrid(self, value : Color| None):
        ...


    @property
    def AxisText(self) -> Color| None:
        """Axis text labels color.
        Default: Auto - derived from Text color
        """
        ...


    @AxisText.setter
    def AxisText(self, value : Color| None):
        ...


    @property
    def AxisTick(self) -> Color| None:
        """Axis tick marks color.
        Default: Auto - derived from AxisGrid color
        """
        ...


    @AxisTick.setter
    def AxisTick(self, value : Color| None):
        ...


    @property
    def Crosshairs(self) -> Color| None:
        """Crosshairs color.
        Default: Auto - derived from PlotBorder color
        """
        ...


    @Crosshairs.setter
    def Crosshairs(self, value : Color| None):
        ...


    @property
    def ErrorBar(self) -> Color| None:
        """Error bar color.
        Default: Auto - derived from Text color
        """
        ...


    @ErrorBar.setter
    def ErrorBar(self, value : Color| None):
        ...


    @property
    def Fill(self) -> Color| None:
        """Plot fill color.
        Default: Auto - derived from Line color
        """
        ...


    @Fill.setter
    def Fill(self, value : Color| None):
        ...


    @property
    def FrameBg(self) -> Color| None:
        """Plot frame background color.
        Default: Auto - derived from FrameBg color
        """
        ...


    @FrameBg.setter
    def FrameBg(self, value : Color| None):
        ...


    @property
    def InlayText(self) -> Color| None:
        """Color of text appearing inside of plots.
        Default: Auto - derived from Text color
        """
        ...


    @InlayText.setter
    def InlayText(self, value : Color| None):
        ...


    @property
    def LegendBg(self) -> Color| None:
        """Legend background color.
        Default: Auto - derived from PopupBg color
        """
        ...


    @LegendBg.setter
    def LegendBg(self, value : Color| None):
        ...


    @property
    def LegendBorder(self) -> Color| None:
        """Legend border color.
        Default: Auto - derived from Border color
        """
        ...


    @LegendBorder.setter
    def LegendBorder(self, value : Color| None):
        ...


    @property
    def LegendText(self) -> Color| None:
        """Legend text color.
        Default: Auto - derived from Text color
        """
        ...


    @LegendText.setter
    def LegendText(self, value : Color| None):
        ...


    @property
    def Line(self) -> Color| None:
        """Plot line color.
        Default: Auto - derived from Text color
        """
        ...


    @Line.setter
    def Line(self, value : Color| None):
        ...


    @property
    def MarkerFill(self) -> Color| None:
        """Plot marker fill color.
        Default: Auto - derived from Line color
        """
        ...


    @MarkerFill.setter
    def MarkerFill(self, value : Color| None):
        ...


    @property
    def MarkerOutline(self) -> Color| None:
        """Plot marker outline color.
        Default: Auto - derived from Line color
        """
        ...


    @MarkerOutline.setter
    def MarkerOutline(self, value : Color| None):
        ...


    @property
    def PlotBg(self) -> Color| None:
        """Plot area background color.
        Default: Auto - derived from WindowBg color
        """
        ...


    @PlotBg.setter
    def PlotBg(self, value : Color| None):
        ...


    @property
    def PlotBorder(self) -> Color| None:
        """Plot area border color.
        Default: Auto - derived from Border color
        """
        ...


    @PlotBorder.setter
    def PlotBorder(self, value : Color| None):
        ...


    @property
    def Selection(self) -> Color| None:
        """Box-selection color.
        Default: (1.00, 1.00, 0.00, 1.00)
        """
        ...


    @Selection.setter
    def Selection(self, value : Color| None):
        ...


    @property
    def TitleText(self) -> Color| None:
        """Plot title text color.
        Default: Auto - derived from Text color
        """
        ...


    @TitleText.setter
    def TitleText(self, value : Color| None):
        ...


class ThemeList(baseTheme):
    """
    A set of base theme elements to apply when we render an item.
    Warning: it is bad practice to bind a theme to every item, and
    is not free on CPU. Instead set the theme as high as possible in
    the rendering hierarchy, and only change locally reduced sets
    of theme elements if needed.

    Contains theme styles and colors.
    Can contain a theme list.
    Can be bound to items.

    WARNING: if you bind a theme element to an item,
    and that theme element belongs to a theme list,
    the siblings before the theme element will get
    applied as well.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : Sequence[baseThemeSubCls] = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseHandlerSubCls | None = None, previous_sibling : baseItemSubCls | None = None, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the theme is currently active.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - user_data: User data of any type.
        """
        ...


class ThemeStyleImGui(baseThemeStyle):
    def __init__(self, context : Context, Alpha : float | None = None, ButtonTextAlign : tuple[float, float] | None = None, CellPadding : tuple[float, float] | None = None, ChildBorderSize : float | None = None, ChildRounding : float | None = None, DisabledAlpha : float | None = None, FrameBorderSize : float | None = None, FramePadding : tuple[float, float] | None = None, FrameRounding : float | None = None, GrabMinSize : float | None = None, GrabRounding : float | None = None, IndentSpacing : float | None = None, ItemInnerSpacing : tuple[float, float] | None = None, ItemSpacing : tuple[float, float] | None = None, PopupBorderSize : float | None = None, PopupRounding : float | None = None, ScrollbarRounding : float | None = None, ScrollbarSize : float | None = None, SelectableTextAlign : tuple[float, float] | None = None, SeparatorTextBorderSize : float | None = None, SeparatorTextPadding : tuple[float, float] | None = None, TabBarBorderSize : float | None = None, TabBarOverlineSize : float | None = None, TabBorderSize : float | None = None, TabRounding : float | None = None, TableAngledHeadersAngle : float | None = None, TableAngledHeadersTextAlign : tuple[float, float] | None = None, WindowBorderSize : float | None = None, WindowMinSize : tuple[float, float] | None = None, WindowPadding : tuple[float, float] | None = None, WindowRounding : float | None = None, WindowTitleAlign : tuple[float, float] | None = None, attach : Any = ..., before : Any = ..., children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, no_rounding : bool = True, no_scaling : bool = False, parent : baseHandlerSubCls | None = None, previous_sibling : baseItemSubCls | None = None, user_data : tuple[float, float] | None = None):
        """
        Parameters
        ----------
        - Alpha: Global alpha applied to everything in Dear ImGui.
        - ButtonTextAlign: Alignment of button text when button is larger than text.
        - CellPadding: Tables: padding between cells.
        - ChildBorderSize: Thickness of border around child windows. Generally set to 0.0f or 1.0f. Other values not well tested.
        - ChildRounding: Radius of child window corners rounding. Set to 0.0 to have rectangular child windows.
        - DisabledAlpha: Unused currently.
        - FrameBorderSize: Thickness of border around frames (most widgets). Generally set to 0.0f or 1.0f. Other values not well tested.
        - FramePadding: Padding within a framed rectangle (used by most widgets)
        - FrameRounding: Radius of frame corners rounding. Set to 0.0 to have rectangular frame (most widgets).
        - GrabMinSize: Minimum width/height of a grab box for slider/scrollbar.
        - GrabRounding: Radius of grabs corners rounding. Set to 0.0f to have rectangular slider grabs.
        - IndentSpacing: Default horizontal spacing for indentations. For instance when entering a tree node.
        - ItemInnerSpacing: Horizontal and vertical spacing between elements inside of a composed widget.
        - ItemSpacing: Horizontal and vertical spacing between widgets/lines.
        - PopupBorderSize: Thickness of border around popup or tooltip windows. Generally set to 0.0f or 1.0f. Other values not well tested.
        - PopupRounding: Radius of popup or tooltip window corners rounding. Set to 0.0 to have rectangular popup or tooltip windows.
        - ScrollbarRounding: Radius of grab corners rounding for scrollbar.
        - ScrollbarSize: Width of the vertical scrollbar, Height of the horizontal scrollbar
        - SelectableTextAlign: Alignment of text within the separator in percentages.
        - SeparatorTextBorderSize: Thickness of border in Separator() text.
        - SeparatorTextPadding: Horizontal offset of text from each edge of the separator + spacing on other axis. Generally small values. .y is recommended to be == FramePadding.y.
        - TabBarBorderSize: Thickness of tab-bar separator, which takes on the tab active color to denote focus.
        - TabBarOverlineSize: Thickness of tab-bar overline, which highlights the selected tab-bar.
        - TabBorderSize: Thickness of borders around tabs.
        - TabRounding: Radius of upper corners of a tab. Set to 0.0f to have rectangular tabs.
        - TableAngledHeadersAngle: Tables: Angle of angled headers (supported values range from -50 degrees to +50 degrees).
        - TableAngledHeadersTextAlign: Tables: Alignment (percentages) of angled headers within the cell
        - WindowBorderSize: Thickness of border around windows. Generally set to 0.0 or 1.0f. Other values not well tested.
        - WindowMinSize: Minimum window size
        - WindowPadding: Padding within a window.
        - WindowRounding: Radius of window corners rounding. Set to 0.0 to have rectangular windows. Large values tend to lead to variety of artifacts and are not recommended.
        - WindowTitleAlign: Alignment for window title bar text in percentages
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the theme is currently active.
        - next_sibling: Child of the parent rendered just after this item.
        - no_rounding: boolean. Defaults to False.
        - no_scaling: boolean. Defaults to False.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - user_data: User data of any type.
        """
        ...


    @property
    def Alpha(self) -> float | None:
        """
        Global alpha applied to everything in Dear ImGui.

        The value is in the range [0, 1]. Defaults to 1.

        """
        ...


    @Alpha.setter
    def Alpha(self, value : float | None):
        ...


    @property
    def ButtonTextAlign(self) -> tuple[float, float] | None:
        """
        Alignment of button text when button is larger than text.

        The value is a pair of floats. Defaults to (0.5, 0.5), i.e. centered

        """
        ...


    @ButtonTextAlign.setter
    def ButtonTextAlign(self, value : tuple[float, float] | None):
        ...


    @property
    def CellPadding(self) -> tuple[float, float] | None:
        """
        Tables: padding between cells.
        The x padding is applied for the whole Table,
        while y can be different for every row.

        The value is a pair of floats. Defaults to (4, 2).

        """
        ...


    @CellPadding.setter
    def CellPadding(self, value : tuple[float, float] | None):
        ...


    @property
    def ChildBorderSize(self) -> float | None:
        """
        Thickness of border around child windows. Generally set to 0.0f or 1.0f. Other values not well tested.

        The value is a float. Defaults to 1.

        """
        ...


    @ChildBorderSize.setter
    def ChildBorderSize(self, value : float | None):
        ...


    @property
    def ChildRounding(self) -> float | None:
        """
        Radius of child window corners rounding. Set to 0.0 to have rectangular child windows.

        The value is a float. Defaults to 0.

        """
        ...


    @ChildRounding.setter
    def ChildRounding(self, value : float | None):
        ...


    @property
    def DisabledAlpha(self) -> float | None:
        """
        Unused currently.

        The value is in the range [0, 1]. Defaults to 0.6

        """
        ...


    @DisabledAlpha.setter
    def DisabledAlpha(self, value : float | None):
        ...


    @property
    def FrameBorderSize(self) -> float | None:
        """
        Thickness of border around frames (most widgets). Generally set to 0.0f or 1.0f. Other values not well tested.

        The value is a float. Defaults to 0.

        """
        ...


    @FrameBorderSize.setter
    def FrameBorderSize(self, value : float | None):
        ...


    @property
    def FramePadding(self) -> tuple[float, float] | None:
        """
        Padding within a framed rectangle (used by most widgets)

        The value is a pair of floats. Defaults to (4,3).

        """
        ...


    @FramePadding.setter
    def FramePadding(self, value : tuple[float, float] | None):
        ...


    @property
    def FrameRounding(self) -> float | None:
        """
        Radius of frame corners rounding. Set to 0.0 to have rectangular frame (most widgets).

        The value is a float. Defaults to 0.

        """
        ...


    @FrameRounding.setter
    def FrameRounding(self, value : float | None):
        ...


    @property
    def GrabMinSize(self) -> float | None:
        """
        Minimum width/height of a grab box for slider/scrollbar.

        The value is a float. Defaults to 12.

        """
        ...


    @GrabMinSize.setter
    def GrabMinSize(self, value : float | None):
        ...


    @property
    def GrabRounding(self) -> float | None:
        """
        Radius of grabs corners rounding. Set to 0.0f to have rectangular slider grabs.

        The value is a float. Defaults to 0.

        """
        ...


    @GrabRounding.setter
    def GrabRounding(self, value : float | None):
        ...


    @property
    def IndentSpacing(self) -> float | None:
        """
        Default horizontal spacing for indentations. For instance when entering a tree node.
        A good value is Generally == (FontSize + FramePadding.x*2).

        The value is a float. Defaults to 21.

        """
        ...


    @IndentSpacing.setter
    def IndentSpacing(self, value : float | None):
        ...


    @property
    def ItemInnerSpacing(self) -> tuple[float, float] | None:
        """
        Horizontal and vertical spacing between elements inside of a composed widget.

        The value is a pair of floats. Defaults to (4, 4).

        """
        ...


    @ItemInnerSpacing.setter
    def ItemInnerSpacing(self, value : tuple[float, float] | None):
        ...


    @property
    def ItemSpacing(self) -> tuple[float, float] | None:
        """
        Horizontal and vertical spacing between widgets/lines.

        The value is a pair of floats. Defaults to (8, 4).

        """
        ...


    @ItemSpacing.setter
    def ItemSpacing(self, value : tuple[float, float] | None):
        ...


    @property
    def PopupBorderSize(self) -> float | None:
        """
        Thickness of border around popup or tooltip windows. Generally set to 0.0f or 1.0f. Other values not well tested.

        The value is a float. Defaults to 1.

        """
        ...


    @PopupBorderSize.setter
    def PopupBorderSize(self, value : float | None):
        ...


    @property
    def PopupRounding(self) -> float | None:
        """
        Radius of popup or tooltip window corners rounding. Set to 0.0 to have rectangular popup or tooltip windows.

        The value is a float. Defaults to 0.

        """
        ...


    @PopupRounding.setter
    def PopupRounding(self, value : float | None):
        ...


    @property
    def ScrollbarRounding(self) -> float | None:
        """
        Radius of grab corners rounding for scrollbar.

        The value is a float. Defaults to 9.

        """
        ...


    @ScrollbarRounding.setter
    def ScrollbarRounding(self, value : float | None):
        ...


    @property
    def ScrollbarSize(self) -> float | None:
        """
        Width of the vertical scrollbar, Height of the horizontal scrollbar

        The value is a float. Defaults to 14.

        """
        ...


    @ScrollbarSize.setter
    def ScrollbarSize(self, value : float | None):
        ...


    @property
    def SelectableTextAlign(self) -> tuple[float, float] | None:
        """
        Alignment of text within the separator in percentages.

        The value is a pair of floats. Defaults to (0., 0.5), i.e. left-centered

        """
        ...


    @SelectableTextAlign.setter
    def SelectableTextAlign(self, value : tuple[float, float] | None):
        ...


    @property
    def SeparatorTextBorderSize(self) -> float | None:
        """
        Thickness of border in Separator() text.

        The value is a float. Defaults to 3.

        """
        ...


    @SeparatorTextBorderSize.setter
    def SeparatorTextBorderSize(self, value : float | None):
        ...


    @property
    def SeparatorTextPadding(self) -> tuple[float, float] | None:
        """
        Horizontal offset of text from each edge of the separator + spacing on other axis. Generally small values. .y is recommended to be == FramePadding.y.

        The value is a pair of floats. Defaults to (20., 3.).

        """
        ...


    @SeparatorTextPadding.setter
    def SeparatorTextPadding(self, value : tuple[float, float] | None):
        ...


    @property
    def TabBarBorderSize(self) -> float | None:
        """
        Thickness of tab-bar separator, which takes on the tab active color to denote focus.

        The value is a float. Defaults to 1.

        """
        ...


    @TabBarBorderSize.setter
    def TabBarBorderSize(self, value : float | None):
        ...


    @property
    def TabBarOverlineSize(self) -> float | None:
        """
        Thickness of tab-bar overline, which highlights the selected tab-bar.

        The value is a float. Defaults to 2.

        """
        ...


    @TabBarOverlineSize.setter
    def TabBarOverlineSize(self, value : float | None):
        ...


    @property
    def TabBorderSize(self) -> float | None:
        """
        Thickness of borders around tabs.

        The value is a float. Defaults to 0.

        """
        ...


    @TabBorderSize.setter
    def TabBorderSize(self, value : float | None):
        ...


    @property
    def TabRounding(self) -> float | None:
        """
        Radius of upper corners of a tab. Set to 0.0f to have rectangular tabs.

        The value is a float. Defaults to 4.

        """
        ...


    @TabRounding.setter
    def TabRounding(self, value : float | None):
        ...


    @property
    def TableAngledHeadersAngle(self) -> float | None:
        """
        Tables: Angle of angled headers (supported values range from -50 degrees to +50 degrees).

        The value is a float. Defaults to 35.0f * (IM_PI / 180.0f).

        """
        ...


    @TableAngledHeadersAngle.setter
    def TableAngledHeadersAngle(self, value : float | None):
        ...


    @property
    def TableAngledHeadersTextAlign(self) -> tuple[float, float] | None:
        """
        Tables: Alignment (percentages) of angled headers within the cell

        The value is a pair of floats. Defaults to (0.5, 0.), i.e. top-centered

        """
        ...


    @TableAngledHeadersTextAlign.setter
    def TableAngledHeadersTextAlign(self, value : tuple[float, float] | None):
        ...


    @property
    def WindowBorderSize(self) -> float | None:
        """
        Thickness of border around windows. Generally set to 0.0 or 1.0f. Other values not well tested.

        The value is a float. Defaults to 1.

        """
        ...


    @WindowBorderSize.setter
    def WindowBorderSize(self, value : float | None):
        ...


    @property
    def WindowMinSize(self) -> tuple[float, float] | None:
        """
        Minimum window size

        The value is a pair of float (dx, dy). Defaults to (32, 32)

        """
        ...


    @WindowMinSize.setter
    def WindowMinSize(self, value : tuple[float, float] | None):
        ...


    @property
    def WindowPadding(self) -> tuple[float, float] | None:
        """
        Padding within a window.

        The value is a pair of float (dx, dy). Defaults to (8, 8)

        """
        ...


    @WindowPadding.setter
    def WindowPadding(self, value : tuple[float, float] | None):
        ...


    @property
    def WindowRounding(self) -> float | None:
        """
        Radius of window corners rounding. Set to 0.0 to have rectangular windows. Large values tend to lead to variety of artifacts and are not recommended.

        The value is a float. Defaults to 0.

        """
        ...


    @WindowRounding.setter
    def WindowRounding(self, value : float | None):
        ...


    @property
    def WindowTitleAlign(self) -> tuple[float, float] | None:
        """
        Alignment for window title bar text in percentages

        The value is a pair of float (dx, dy). Defaults to (0., 0.5), which means left-aligned, vertical centering on the row

        """
        ...


    @WindowTitleAlign.setter
    def WindowTitleAlign(self, value : tuple[float, float] | None):
        ...


class ThemeStyleImPlot(baseThemeStyle):
    def __init__(self, context : Context, AnnotationPadding : tuple[float, float] | None = None, DigitalBitGap : float | None = None, DigitalBitHeight : float | None = None, ErrorBarSize : float | None = None, ErrorBarWeight : float | None = None, FillAlpha : float | None = None, FitPadding : tuple[float, float] | None = None, LabelPadding : tuple[float, float] | None = None, LegendInnerPadding : tuple[float, float] | None = None, LegendPadding : tuple[float, float] | None = None, LegendSpacing : tuple[float, float] | None = None, LineWeight : float | None = None, MajorGridSize : tuple[float, float] | None = None, MajorTickLen : tuple[float, float] | None = None, MajorTickSize : tuple[float, float] | None = None, Marker : float | None = None, MarkerSize : float | None = None, MarkerWeight : float | None = None, MinorAlpha : float | None = None, MinorGridSize : tuple[float, float] | None = None, MinorTickLen : tuple[float, float] | None = None, MinorTickSize : tuple[float, float] | None = None, MousePosPadding : tuple[float, float] | None = None, PlotBorderSize : float | None = None, PlotDefaultSize : tuple[float, float] | None = None, PlotMinSize : tuple[float, float] | None = None, PlotPadding : tuple[float, float] | None = None, attach : Any = ..., before : Any = ..., children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, no_rounding : bool = True, no_scaling : bool = False, parent : baseHandlerSubCls | None = None, previous_sibling : baseItemSubCls | None = None, user_data : tuple[float, float] | None = None):
        """
        Parameters
        ----------
        - AnnotationPadding: Text padding around annotation labels.
        - DigitalBitGap: Digital channels bit padding gap in pixels.
        - DigitalBitHeight: Digital channels bit height (at 1) in pixels.
        - ErrorBarSize: Error bar whisker width in pixels.
        - ErrorBarWeight: Error bar whisker weight in pixels.
        - FillAlpha: Alpha modifier applied to all plot item fills.
        - FitPadding: Additional fit padding as a percentage of the fit extents (e.g. (0.1,0.1) adds 10% to the fit extents of X and Y).
        - LabelPadding: Padding between axes labels, tick labels, and plot edge.
        - LegendInnerPadding: Legend inner padding from legend edges.
        - LegendPadding: Legend padding from plot edges.
        - LegendSpacing: Spacing between legend entries.
        - LineWeight: Plot item line weight in pixels.
        - MajorGridSize: Line thickness of major grid lines.
        - MajorTickLen: Major tick lengths for X and Y axes.
        - MajorTickSize: Line thickness of major ticks.
        - Marker: Marker specification.
        - MarkerSize: Marker size in pixels (roughly the marker's "radius").
        - MarkerWeight: Plot outline weight of markers in pixels.
        - MinorAlpha: Alpha multiplier applied to minor axis grid lines.
        - MinorGridSize: Line thickness of minor grid lines.
        - MinorTickLen: Minor tick lengths for X and Y axes.
        - MinorTickSize: Line thickness of minor ticks.
        - MousePosPadding: Padding between plot edge and interior info text.
        - PlotBorderSize: Thickness of border around plot area.
        - PlotDefaultSize: Default size used for plots
        - PlotMinSize: Minimum size plot frame can be when shrunk.
        - PlotPadding: Padding between widget frame and plot area, labels, or outside legends (i.e. main padding).
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the theme is currently active.
        - next_sibling: Child of the parent rendered just after this item.
        - no_rounding: boolean. Defaults to False.
        - no_scaling: boolean. Defaults to False.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - user_data: User data of any type.
        """
        ...


    @property
    def AnnotationPadding(self) -> tuple[float, float] | None:
        """
        Text padding around annotation labels.

        The value is a pair of floats. Defaults to (2, 2).

        """
        ...


    @AnnotationPadding.setter
    def AnnotationPadding(self, value : tuple[float, float] | None):
        ...


    @property
    def DigitalBitGap(self) -> float | None:
        """
        Digital channels bit padding gap in pixels.

        The value is a float. Defaults to 4.

        """
        ...


    @DigitalBitGap.setter
    def DigitalBitGap(self, value : float | None):
        ...


    @property
    def DigitalBitHeight(self) -> float | None:
        """
        Digital channels bit height (at 1) in pixels.

        The value is a float. Defaults to 8.

        """
        ...


    @DigitalBitHeight.setter
    def DigitalBitHeight(self, value : float | None):
        ...


    @property
    def ErrorBarSize(self) -> float | None:
        """
        Error bar whisker width in pixels.

        The value is a float. Defaults to 5.

        """
        ...


    @ErrorBarSize.setter
    def ErrorBarSize(self, value : float | None):
        ...


    @property
    def ErrorBarWeight(self) -> float | None:
        """
        Error bar whisker weight in pixels.

        The value is a float. Defaults to 1.5.

        """
        ...


    @ErrorBarWeight.setter
    def ErrorBarWeight(self, value : float | None):
        ...


    @property
    def FillAlpha(self) -> float | None:
        """
        Alpha modifier applied to all plot item fills.

        The value is a float. Defaults to 1.

        """
        ...


    @FillAlpha.setter
    def FillAlpha(self, value : float | None):
        ...


    @property
    def FitPadding(self) -> tuple[float, float] | None:
        """
        Additional fit padding as a percentage of the fit extents (e.g. (0.1,0.1) adds 10% to the fit extents of X and Y).

        The value is a pair of floats. Defaults to (0, 0).

        """
        ...


    @FitPadding.setter
    def FitPadding(self, value : tuple[float, float] | None):
        ...


    @property
    def LabelPadding(self) -> tuple[float, float] | None:
        """
        Padding between axes labels, tick labels, and plot edge.

        The value is a pair of floats. Defaults to (5, 5).

        """
        ...


    @LabelPadding.setter
    def LabelPadding(self, value : tuple[float, float] | None):
        ...


    @property
    def LegendInnerPadding(self) -> tuple[float, float] | None:
        """
        Legend inner padding from legend edges.

        The value is a pair of floats. Defaults to (5, 5).

        """
        ...


    @LegendInnerPadding.setter
    def LegendInnerPadding(self, value : tuple[float, float] | None):
        ...


    @property
    def LegendPadding(self) -> tuple[float, float] | None:
        """
        Legend padding from plot edges.

        The value is a pair of floats. Defaults to (10, 10).

        """
        ...


    @LegendPadding.setter
    def LegendPadding(self, value : tuple[float, float] | None):
        ...


    @property
    def LegendSpacing(self) -> tuple[float, float] | None:
        """
        Spacing between legend entries.

        The value is a pair of floats. Defaults to (5, 0).

        """
        ...


    @LegendSpacing.setter
    def LegendSpacing(self, value : tuple[float, float] | None):
        ...


    @property
    def LineWeight(self) -> float | None:
        """
        Plot item line weight in pixels.

        The value is a float. Defaults to 1.

        """
        ...


    @LineWeight.setter
    def LineWeight(self, value : float | None):
        ...


    @property
    def MajorGridSize(self) -> tuple[float, float] | None:
        """
        Line thickness of major grid lines.

        The value is a pair of floats. Defaults to (1, 1).

        """
        ...


    @MajorGridSize.setter
    def MajorGridSize(self, value : tuple[float, float] | None):
        ...


    @property
    def MajorTickLen(self) -> tuple[float, float] | None:
        """
        Major tick lengths for X and Y axes.

        The value is a pair of floats. Defaults to (10, 10).

        """
        ...


    @MajorTickLen.setter
    def MajorTickLen(self, value : tuple[float, float] | None):
        ...


    @property
    def MajorTickSize(self) -> tuple[float, float] | None:
        """
        Line thickness of major ticks.

        The value is a pair of floats. Defaults to (1, 1).

        """
        ...


    @MajorTickSize.setter
    def MajorTickSize(self, value : tuple[float, float] | None):
        ...


    @property
    def Marker(self) -> float | None:
        """
        Marker specification.

        The value is a PlotMarker. Defaults to PlotMarker.NONE.

        """
        ...


    @Marker.setter
    def Marker(self, value : float | None):
        ...


    @property
    def MarkerSize(self) -> float | None:
        """
        Marker size in pixels (roughly the marker's "radius").

        The value is a float. Defaults to 4.

        """
        ...


    @MarkerSize.setter
    def MarkerSize(self, value : float | None):
        ...


    @property
    def MarkerWeight(self) -> float | None:
        """
        Plot outline weight of markers in pixels.

        The value is a float. Defaults to 1.

        """
        ...


    @MarkerWeight.setter
    def MarkerWeight(self, value : float | None):
        ...


    @property
    def MinorAlpha(self) -> float | None:
        """
        Alpha multiplier applied to minor axis grid lines.

        The value is a float. Defaults to 0.25.

        """
        ...


    @MinorAlpha.setter
    def MinorAlpha(self, value : float | None):
        ...


    @property
    def MinorGridSize(self) -> tuple[float, float] | None:
        """
        Line thickness of minor grid lines.

        The value is a pair of floats. Defaults to (1, 1).

        """
        ...


    @MinorGridSize.setter
    def MinorGridSize(self, value : tuple[float, float] | None):
        ...


    @property
    def MinorTickLen(self) -> tuple[float, float] | None:
        """
        Minor tick lengths for X and Y axes.

        The value is a pair of floats. Defaults to (5, 5).

        """
        ...


    @MinorTickLen.setter
    def MinorTickLen(self, value : tuple[float, float] | None):
        ...


    @property
    def MinorTickSize(self) -> tuple[float, float] | None:
        """
        Line thickness of minor ticks.

        The value is a pair of floats. Defaults to (1, 1).

        """
        ...


    @MinorTickSize.setter
    def MinorTickSize(self, value : tuple[float, float] | None):
        ...


    @property
    def MousePosPadding(self) -> tuple[float, float] | None:
        """
        Padding between plot edge and interior info text.

        The value is a pair of floats. Defaults to (10, 10).

        """
        ...


    @MousePosPadding.setter
    def MousePosPadding(self, value : tuple[float, float] | None):
        ...


    @property
    def PlotBorderSize(self) -> float | None:
        """
        Thickness of border around plot area.

        The value is a float. Defaults to 1.

        """
        ...


    @PlotBorderSize.setter
    def PlotBorderSize(self, value : float | None):
        ...


    @property
    def PlotDefaultSize(self) -> tuple[float, float] | None:
        """
        Default size used for plots

        The value is a pair of floats. Defaults to (400, 300).

        """
        ...


    @PlotDefaultSize.setter
    def PlotDefaultSize(self, value : tuple[float, float] | None):
        ...


    @property
    def PlotMinSize(self) -> tuple[float, float] | None:
        """
        Minimum size plot frame can be when shrunk.

        The value is a pair of floats. Defaults to (200, 150).

        """
        ...


    @PlotMinSize.setter
    def PlotMinSize(self, value : tuple[float, float] | None):
        ...


    @property
    def PlotPadding(self) -> tuple[float, float] | None:
        """
        Padding between widget frame and plot area, labels, or outside legends (i.e. main padding).

        The value is a pair of floats. Defaults to (10, 10).

        """
        ...


    @PlotPadding.setter
    def PlotPadding(self, value : tuple[float, float] | None):
        ...


class TimeWatcher(uiItem):
    """
    A placeholder uiItem parent that doesn't draw or have any impact on rendering.
    This item calls the callback with times in ns.
    These times can be compared with the times in the metrics
    that can be obtained from the viewport in order to
    precisely figure out the time spent rendering specific items.

    The first time corresponds to the time this item is called
    for rendering

    The second time corresponds to the time after the
    children have finished rendering.

    The third time corresponds to the time when viewport
    started rendering items for this frame. It is
    given to prevent the user from having to keep track of the
    viewport metrics (since the callback might be called
    after or before the viewport updated its metrics for this
    frame or another one).

    The fourth number corresponds to the frame count
    at the the time the callback was issued.

    Note the times relate to CPU time (checking states, preparing
    GPU data, etc), not to GPU rendering time.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : Sequence[uiItemSubCls] = [], enabled : bool = True, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedValue = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : Any = ..., width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


class ToggledCloseHandler(baseHandler):
    """
    Handler that triggers the callback when the
    item switches from an opened state to a closed
    state.
    *Warning*: Does not mean an item is un-shown
    by a user interaction (what we usually mean
    by closing a window).
    Here Close/Open refers to being in a
    reduced state when the full content is not
    shown, but could be if the user clicked on
    a specific button. The doesn't mean that
    the object is show or not shown.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class ToggledOpenHandler(baseHandler):
    """
    Handler that triggers the callback when the
    item switches from an closed state to a opened
    state. Here Close/Open refers to being in a
    reduced state when the full content is not
    shown, but could be if the user clicked on
    a specific button. The doesn't mean that
    the object is show or not shown.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


class Tooltip(uiItem):
    """
    A floating popup that displays additional information when hovering an item.

    Tooltips appear when the user hovers over a target element, providing
    contextual help or additional details without requiring interaction. They
    automatically position themselves near the target and can be configured to
    appear after a delay or respond to specific conditions.

    Tooltips can contain any UI elements as children, allowing for rich content
    including text, images, and interactive widgets. They automatically size to
    fit their content and disappear when the user moves away from the target.

    The tooltip's appearance can be controlled through themes, and its behavior
    can be customized with properties like delay time and activity-based hiding.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : Sequence[uiItemSubCls] = [], condition_from_handler : Any = ..., delay : float = 0.0, enabled : bool = True, font : Font = None, handlers : list = [], height : float = 0.0, hide_on_activity : bool = False, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedValue = ..., show : bool = True, target : Any = ..., theme : Any = ..., user_data : Any = ..., value : Any = ..., width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - condition_from_handler: A handler that determines when the tooltip should be displayed.
        - delay: Time in seconds to wait before showing the tooltip.
        - enabled: Whether the item is interactive and fully styled.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - hide_on_activity: Whether to hide the tooltip when the mouse moves.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - target: The UI item that triggers this tooltip when hovered.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def condition_from_handler(self):
        """
        A handler that determines when the tooltip should be displayed.

        When set, this handler replaces the default hover detection logic for
        determining when to show the tooltip. The handler is applied to the
        target item (which must be set) and can implement custom conditions
        beyond simple hovering.

        This allows for advanced tooltip behaviors such as showing tooltips
        based on item state, user interactions, or application logic rather
        than just mouse position.

        """
        ...


    @condition_from_handler.setter
    def condition_from_handler(self, value):
        ...


    @property
    def content_pos(self) -> Coord:
        """
        (Read-only) Position of the content area's top-left corner.

        This property provides the viewport-relative coordinates of the starting
        point for an item's content area. This is where child elements begin to be
        placed by default.

        Used together with content_region_avail, this defines the rectangle
        available for child elements.

        """
        ...


    @property
    def content_region_avail(self) -> Coord:
        """
        (Read-only) Available space for child items.

        For container items like windows, child windows, this
        property represents the available space for placing child items. This is
        the item's inner area after accounting for padding, borders, and other
        non-content elements.

        Areas that require scrolling to see are not included in this measurement.

        """
        ...


    @property
    def delay(self) -> float:
        """
        Time in seconds to wait before showing the tooltip.

        Controls how long the mouse must remain stationary over the target
        before the tooltip appears. This prevents tooltips from flickering
        when the user moves the mouse across the interface.

        Values:
        - Positive: Number of seconds to wait
        - 0: Show immediately (default)
        - -1: Use ImGui default delay from the current style

        """
        ...


    @delay.setter
    def delay(self, value : float):
        ...


    @property
    def hide_on_activity(self) -> bool:
        """
        Whether to hide the tooltip when the mouse moves.

        When enabled, any mouse movement will immediately hide the tooltip,
        even if the mouse remains over the target item. This creates a more
        responsive interface where tooltips only appear when the user explicitly
        pauses on an item.

        This can be useful for tooltips that might obscure important UI elements
        or for interfaces where the user is expected to perform quick actions.

        """
        ...


    @hide_on_activity.setter
    def hide_on_activity(self, value : bool):
        ...


    @property
    def target(self):
        """
        The UI item that triggers this tooltip when hovered.

        When set, the tooltip will appear when this target item is hovered by
        the mouse. If no target is set, the tooltip will use the previous
        sibling in the UI hierarchy as its target.

        Note that if the target item appears after this tooltip in the rendering
        tree, there will be a one-frame delay before the tooltip responds to the
        target's hover state.

        """
        ...


    @target.setter
    def target(self, value):
        ...


class TreeNode(uiItem):
    """
    A collapsible UI element that can contain child widgets in a hierarchical structure.

    TreeNode creates a collapsible section in the UI that can be expanded or collapsed
    by the user. When expanded, it displays its child elements, allowing for hierarchical
    organization of content. When collapsed, children are hidden to save space.

    TreeNodes can be nested to create multi-level hierarchies, and can be styled with
    various visual options like bullets, arrows, or leaf nodes. They support different
    interaction modes including single/double-click expansion, selection highlighting,
    and variable hit-box sizes.

    The open/closed state is stored in a SharedBool value that can be accessed through
    the value property, allowing programmatic control of the tree structure in addition
    to user interaction.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., bullet : bool = False, callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : Sequence[uiItemSubCls] = [], enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", leaf : bool = False, next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, open_on_arrow : bool = False, open_on_double_click : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, selectable : bool = False, shareable_value : SharedBool = ..., show : bool = True, span_full_width : bool = False, span_text_width : bool = False, theme : Any = ..., user_data : Any = ..., value : bool = False, width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - bullet: Whether to display a bullet instead of an arrow.
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - leaf: Whether the node is displayed as a leaf with no expand/collapse control.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - open_on_arrow: Whether the node opens only when clicking the arrow.
        - open_on_double_click: Whether a double-click is required to open the node.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - selectable: Whether the TreeNode appears selected when opened.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - span_full_width: Whether the clickable area spans the entire width of the window.
        - span_text_width: Whether the clickable area only covers the text label.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def activated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned to the active state this frame.

        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use
        event handlers instead as they provide more robust state tracking.

        """
        ...


    @property
    def active(self) -> bool:
        """
        (Read-only) Whether the item is in an active state.

        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.

        """
        ...


    @property
    def bullet(self) -> bool:
        """
        Whether to display a bullet instead of an arrow.

        When enabled, the tree node will show a bullet point instead of the default
        arrow icon. This provides a different visual style that can be used to
        distinguish certain types of nodes or to create bullet list appearances.

        Note that the node can still be expanded/collapsed unless the leaf property
        is also set.

        """
        ...


    @bullet.setter
    def bullet(self, value : bool):
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def clicked(self) -> tuple:
        """
        (Read-only) Whether any mouse button was clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def deactivated(self) -> bool:
        """
        (Read-only) Whether the item just transitioned from active to inactive this frame.

        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.

        """
        ...


    @property
    def double_clicked(self) -> list:
        """
        (Read-only) Whether any mouse button was double-clicked on this item this frame.

        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.

        """
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def leaf(self) -> bool:
        """
        Whether the node is displayed as a leaf with no expand/collapse control.

        When enabled, the tree node will be displayed without an arrow or expansion
        capability, indicating it's an end point in the hierarchy. This is useful for
        terminal nodes that don't contain children, or for creating visual hierarchies
        where some items are not meant to be expanded.

        """
        ...


    @leaf.setter
    def leaf(self, value : bool):
        ...


    @property
    def open_on_arrow(self) -> bool:
        """
        Whether the node opens only when clicking the arrow.

        When enabled, the tree node will only open when the user clicks specifically
        on the arrow icon, not anywhere on the label. This makes it easier to select
        nodes without expanding them.

        If combined with open_on_double_click, the node can be opened either by a
        single click on the arrow or a double click anywhere on the label.

        """
        ...


    @open_on_arrow.setter
    def open_on_arrow(self, value : bool):
        ...


    @property
    def open_on_double_click(self) -> bool:
        """
        Whether a double-click is required to open the node.

        When enabled, the tree node will only open when double-clicked, making it
        harder to accidentally expand nodes. This can be useful for dense trees where
        you want to prevent unintended expansion during navigation or selection.

        Can be combined with open_on_arrow to allow both arrow single-clicks and
        label double-clicks to open the node.

        """
        ...


    @open_on_double_click.setter
    def open_on_double_click(self, value : bool):
        ...


    @property
    def selectable(self) -> bool:
        """
        Whether the TreeNode appears selected when opened.

        When enabled, the tree node will draw with selection highlighting when it's
        in the open state. This provides visual feedback about which nodes are
        expanded, making it easier to navigate complex hierarchies.

        """
        ...


    @selectable.setter
    def selectable(self, value : bool):
        ...


    @property
    def span_full_width(self) -> bool:
        """
        Whether the clickable area spans the entire width of the window.

        When enabled, the hitbox for clicking and hovering will extend to the full
        width of the available area, including the indentation space to the left and
        any empty space to the right. This creates a more accessible target for
        interaction and makes the entire row visually respond to hovering.

        """
        ...


    @span_full_width.setter
    def span_full_width(self, value : bool):
        ...


    @property
    def span_text_width(self) -> bool:
        """
        Whether the clickable area only covers the text label.

        When enabled, the hitbox for clicking and hovering will be narrowed to only
        cover the text label portion of the tree node. This creates a more precise
        interaction where clicks outside the text (but still on the row) won't
        activate the node.

        """
        ...


    @span_text_width.setter
    def span_text_width(self, value : bool):
        ...


    @property
    def toggled(self) -> bool:
        """
        (Read-only) Whether the item was just toggled open this frame.

        Applies to items that can be expanded or collapsed, such as tree nodes,
        collapsing headers, or menus. This property is only true during the frame
        when the toggle from closed to open occurs.

        """
        ...


class VerticalLayout(Layout):
    """
    A layout that organizes items vertically from top to bottom.

    VerticalLayout arranges child elements in a column, with customizable
    alignment modes, spacing, and positioning options. It can align items to
    the top or bottom edge, center them, distribute them evenly using the
    justified mode, or position them manually.

    The layout automatically tracks content height changes and repositions
    children when needed. Different alignment modes can be used to control
    how items are positioned within the available vertical space.

    """
    def __init__(self, context : Context, alignment_mode : Alignment = 0, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : Sequence[uiItemSubCls] = [], enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), positions : list = [], previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedValue = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : Any = ..., width : float = 0.0):
        """
        Parameters
        ----------
        - alignment_mode: Vertical alignment mode of the items.
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - positions: Y positions for items when using MANUAL alignment mode.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def alignment_mode(self) -> Alignment:
        """
        Vertical alignment mode of the items.

        TOP: items are appended from the top
        BOTTOM: items are appended from the bottom
        CENTER: items are centered
        JUSTIFIED: spacing is organized such that items start at the top
            and end at the bottom
        MANUAL: items are positioned at the requested positions

        For TOP/BOTTOM/CENTER, ItemSpacing's style can be used to control
        spacing between items. Default is TOP.

        """
        ...


    @alignment_mode.setter
    def alignment_mode(self, value : Alignment):
        ...


    @property
    def positions(self) -> list:
        """
        Y positions for items when using MANUAL alignment mode.

        When in MANUAL mode, these are the y positions from the top left of this
        layout at which to place the children items.

        Values between 0 and 1 are interpreted as percentages relative to the
        layout height. Negative values are interpreted as relative to the bottom
        edge rather than the top. Items are still top-aligned to the target
        position.

        Setting this property automatically sets alignment_mode to MANUAL.

        """
        ...


    @positions.setter
    def positions(self, value : list):
        ...


class Viewport(baseItem):
    """
    The viewport corresponds to the main item containing all the visuals.

    It is decorated by the operating system and can be minimized/maximized/made fullscreen.

    """
    def __init__(self, context : Context, always_on_top : bool = False, always_submit_to_gpu : bool = False, attach : Any = ..., before : Any = ..., children : Sequence[WindowSubCls | ViewportDrawListSubCls | MenuBarSubCls] = [], clear_color : tuple = (0.0, 0.0, 0.0, 1.0), close_callback : Any = ..., cursor : MouseCursor = 0, decorated : bool = True, disable_close : bool = False, font : Font = None, fullscreen : bool = False, handlers : list = [], height : int = 800, icon : Any = ..., max_height : int = 10000, max_width : int = 10000, maximized : bool = False, min_height : int = 250, min_width : int = 250, minimized : bool = False, next_sibling : baseItemSubCls | None = None, parent : baseItemSubCls | None = None, pixel_height : int = 1200, pixel_width : int = 1280, previous_sibling : baseItemSubCls | None = None, resizable : bool = True, resize_callback : Any = ..., retrieve_framebuffer : bool = False, scale : float = 1.0, theme : Any = ..., title : str = "DearCyGui Window", user_data : Any = ..., visible : bool = True, vsync : bool = True, wait_for_input : bool = False, width : int = 853, x_pos : int = 100, y_pos : int = 100):
        """
        Parameters
        ----------
        - always_on_top: Whether the viewport window stays above other windows.
        - always_submit_to_gpu: By default DearCyGui attemps to skip submitting to the GPU
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - clear_color: Color used to clear the viewport background.
        - close_callback: Callback to be issued when the viewport is closed.
        - cursor: Current mouse cursor appearance.
        - decorated: Whether the viewport window shows OS-provided decorations.
        - disable_close: Whether window close operations are blocked.
        - font: Global font applied to all text within the viewport.
        - fullscreen: Whether the viewport is currently in fullscreen mode.
        - handlers: Event handlers attached to the viewport.
        - height: DPI invariant height of the viewport window.
        - icon: Set the window icon from one or more images.
        - max_height: Maximum height the viewport window can be resized to.
        - max_width: Maximum width the viewport window can be resized to.
        - maximized: Whether the viewport is currently maximized.
        - min_height: Minimum height the viewport window can be resized to.
        - min_width: Minimum width the viewport window can be resized to.
        - minimized: Whether the viewport is currently minimized.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - pixel_height: Actual height of the viewport in pixels.
        - pixel_width: Actual width of the viewport in pixels.
        - previous_sibling: Child of the parent rendered just before this item.
        - resizable: Whether the viewport window can be resized by the user.
        - resize_callback: Callback to be issued when the viewport is resized.
        - retrieve_framebuffer: Whether to activate the framebuffer retrieval.
        - scale: Multiplicative scale applied on top of the system DPI scaling.
        - theme: Global theme applied to all elements within the viewport.
        - title: Text displayed in the viewport window's title bar.
        - user_data: User data of any type.
        - visible: State to control whether the viewport is associated to a window.
        - vsync: Whether vertical synchronization is enabled.
        - wait_for_input: Stop refreshing when no mouse/keyboard event is detected.
        - width: DPI invariant width of the viewport window.
        - x_pos: X position of the viewport window on the screen.
        - y_pos: Y position of the viewport window on the screen.
        """
        ...


    def copy(self, target_context=None):
        ...


    def initialize(self, always_on_top : bool = False, always_submit_to_gpu : bool = False, children : Sequence[WindowSubCls | ViewportDrawListSubCls | MenuBarSubCls] = [], clear_color : tuple = (0.0, 0.0, 0.0, 1.0), close_callback : Any = ..., cursor : MouseCursor = 0, decorated : bool = True, disable_close : bool = False, font : Font = None, fullscreen : bool = False, handlers : list = [], height : int = 800, icon : Any = ..., max_height : int = 10000, max_width : int = 10000, maximized : bool = False, min_height : int = 250, min_width : int = 250, minimized : bool = False, next_sibling : baseItemSubCls | None = None, parent : baseItemSubCls | None = None, pixel_height : int = 1200, pixel_width : int = 1280, previous_sibling : baseItemSubCls | None = None, resizable : bool = True, resize_callback : Any = ..., retrieve_framebuffer : bool = False, scale : float = 1.0, theme : Any = ..., title : str = "DearCyGui Window", user_data : Any = ..., visible : bool = True, vsync : bool = True, wait_for_input : bool = False, width : int = 853, x_pos : int = 100, y_pos : int = 100):
        """
        Initialize the viewport for rendering and show it.

        Items can already be created and attached to the viewport
        before this call.

        Initializes the default font and attaches it to the
        viewport, if None is set already. This font size is scaled
        to be sharp at the target value of viewport.dpi * viewport.scale.
        It will scale automatically with scale changes (AutoFont).

        To change the font and have scale managements, look
        at the documentation of the FontTexture class, as well
        as AutoFont.

        Parameters
        ----------
        - always_on_top: Whether the viewport window stays above other windows.
        - always_submit_to_gpu: By default DearCyGui attemps to skip submitting to the GPU
        - children: List of all the children of the item, from first rendered, to last rendered.
        - clear_color: Color used to clear the viewport background.
        - close_callback: Callback to be issued when the viewport is closed.
        - cursor: Current mouse cursor appearance.
        - decorated: Whether the viewport window shows OS-provided decorations.
        - disable_close: Whether window close operations are blocked.
        - font: Global font applied to all text within the viewport.
        - fullscreen: Whether the viewport is currently in fullscreen mode.
        - handlers: Event handlers attached to the viewport.
        - height: DPI invariant height of the viewport window.
        - icon: Set the window icon from one or more images.
        - max_height: Maximum height the viewport window can be resized to.
        - max_width: Maximum width the viewport window can be resized to.
        - maximized: Whether the viewport is currently maximized.
        - min_height: Minimum height the viewport window can be resized to.
        - min_width: Minimum width the viewport window can be resized to.
        - minimized: Whether the viewport is currently minimized.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - pixel_height: Actual height of the viewport in pixels.
        - pixel_width: Actual width of the viewport in pixels.
        - previous_sibling: Child of the parent rendered just before this item.
        - resizable: Whether the viewport window can be resized by the user.
        - resize_callback: Callback to be issued when the viewport is resized.
        - retrieve_framebuffer: Whether to activate the framebuffer retrieval.
        - scale: Multiplicative scale applied on top of the system DPI scaling.
        - theme: Global theme applied to all elements within the viewport.
        - title: Text displayed in the viewport window's title bar.
        - user_data: User data of any type.
        - visible: State to control whether the viewport is associated to a window.
        - vsync: Whether vertical synchronization is enabled.
        - wait_for_input: Stop refreshing when no mouse/keyboard event is detected.
        - width: DPI invariant width of the viewport window.
        - x_pos: X position of the viewport window on the screen.
        - y_pos: Y position of the viewport window on the screen.
        """
        ...


    def render_frame(self):
        """
Render one frame of the application.

        Rendering occurs in several sequential steps:
        1. Mouse/Keyboard events are processed (wait_for_input applies here)
        2. The viewport and entire rendering tree are traversed to prepare
        rendering commands using ImGui and ImPlot
        3. Rendering commands are submitted to the GPU, if a change was detected
           (unless always_submit_to_gpu is set, in which case it is always submitted.)
        4. If submitted to the GPU, a window update is requested to the OS, using
            vsync if applicable

        Returns
        -------
        bool
            True if the frame was presented to the screen, False otherwise

        """
        ...


    def wait_events(self, timeout_ms=0) -> bool:
        """
        Waits for an event that justifies running render_frame to occur.

        When using wait_for_input, render_frame will block until a relevant
        event such as a mouse or keyboard event occurs, or until logical
        events such as timed UI behaviours are triggered.
        This method allows the application to implement its own waiting logic.

        When this method returns True, and wait_for_input is True, the next
        render_frame call is guaranteed to not block on events.

        When wait_for_input is False, render_frame does not block on events
        whether this method returns True or False.

        This method blocks until an event occurs or the timeout is reached.
        Args:
            timeout_ms (int): The maximum time to wait in milliseconds.
                If 0, no wait is performed and the method returns immediately.

        Returns:
            bool: True if an event requires render_frame to be processed,
                  False if no such event was met in the allocated time.

        """
        ...


    def wake(self):
        """
        Wake the viewport to force a redraw.

        In case rendering is waiting for an input (wait_for_input),
        generate a fake input to force rendering.

        This is useful if you have updated the content asynchronously
        and want to show the update

        """
        ...


    @property
    def always_on_top(self) -> bool:
        """
        Whether the viewport window stays above other windows.

        When enabled, the viewport window will remain visible on top of other
        application windows even when it doesn't have focus. This is useful for
        tool palettes, monitoring displays, or any window that needs to remain
        visible while the user interacts with other applications.

        """
        ...


    @always_on_top.setter
    def always_on_top(self, value : bool):
        ...


    @property
    def always_submit_to_gpu(self) -> bool:
        """
        By default DearCyGui attemps to skip submitting to the GPU
        frames when no change have been detected during the CPU preparation
        of the frame.

        However some cases may be missed. This state is available in order to
        have a fallback in case issues are met.

        """
        ...


    @always_submit_to_gpu.setter
    def always_submit_to_gpu(self, value : bool):
        ...


    @property
    def clear_color(self) -> tuple:
        """
        Color used to clear the viewport background.

        This RGBA color is applied to the entire viewport before any rendering takes
        place. Setting an appropriate clear color helps establish the visual
        foundation for your application and improves contrast with UI elements.

        """
        ...


    @clear_color.setter
    def clear_color(self, value : tuple):
        ...


    @property
    def close_callback(self):
        """
        Callback to be issued when the viewport is closed.

        """
        ...


    @close_callback.setter
    def close_callback(self, value):
        ...


    @property
    def cursor(self) -> MouseCursor:
        """
        Current mouse cursor appearance.

        Controls which cursor shape is displayed when the mouse is over the viewport.
        The cursor is reset to the default arrow at the beginning of each frame,
        so this property must be set each frame to maintain a consistent non-default
        cursor appearance.

        """
        ...


    @cursor.setter
    def cursor(self, value : MouseCursor):
        ...


    @property
    def decorated(self) -> bool:
        """
        Whether the viewport window shows OS-provided decorations.

        When enabled, the window includes standard OS decorations such as title bar,
        borders, and window control buttons. When disabled, the window appears as a
        plain rectangle without these decorations, which is useful for custom UI
        designs that implement their own window controls.

        """
        ...


    @decorated.setter
    def decorated(self, value : bool):
        ...


    @property
    def disable_close(self) -> bool:
        """
        Whether window close operations are blocked.

        When enabled, the viewport ignores close requests triggered by clicking
        the window's close button or by other OS-specific close mechanisms.
        The window can still be closed programmatically. This is useful for
        applications that need to perform cleanup or prompt for confirmation
        before closing.

        Note: This property does not affect the close callback; it only
        prevents the window from being closed through standard OS interactions.

        """
        ...


    @disable_close.setter
    def disable_close(self, value : bool):
        ...


    @property
    def dpi(self) -> float:
        """
        (Read-only) Requested scaling (DPI) from the OS for this window.

        This value represents the display scaling factor for the current monitor.
        It's used to automatically scale UI elements for readability across
        different screen densities. The value is valid after initialization and
        may change if the window moves to another monitor with different DPI.

        """
        ...


    @property
    def font(self) -> Font:
        """
        Global font applied to all text within the viewport.

        Sets the default font used for rendering text throughout the application.
        Individual UI elements can override this by setting their own font
        property. The font is automatically scaled according to the viewport's
        DPI and scale settings.

        """
        ...


    @font.setter
    def font(self, value : Font):
        ...


    @property
    def framebuffer(self):
        """
        (Read-only) Content of the framebuffer (dcg.Texture)

        This field is only populated upon frame rendering
        when retrieve_framebuffer is set.

        """
        ...


    @property
    def fullscreen(self) -> bool:
        """
        Whether the viewport is currently in fullscreen mode.

        When in fullscreen mode, the window occupies the entire screen area
        without decorations. This is useful for immersive applications or
        presentations. Setting this property toggles between windowed and
        fullscreen modes.

        """
        ...


    @fullscreen.setter
    def fullscreen(self, value : bool):
        ...


    @property
    def handlers(self) -> list:
        """
        Event handlers attached to the viewport.

        Handlers allow responding to keyboard and mouse events at the viewport
        level, regardless of which specific UI element has focus. Only Key and
        Mouse handlers are compatible with the viewport; handlers that check item
        states won't work at this level.

        """
        ...


    @handlers.setter
    def handlers(self, value : list):
        ...


    @property
    def height(self) -> int:
        """
        DPI invariant height of the viewport window.

        Represents the logical height of the viewport in DPI-independent units.
        The actual pixel height may differ based on the DPI scaling factor of the
        display. Use this value when you want consistent sizing across different
        display configurations.

        """
        ...


    @height.setter
    def height(self, value : int):
        ...


    @property
    def icon(self):
        """
        Set the window icon from one or more images.

        The property accepts a single image or a sequence of images with different sizes.
        Each image should be a 3D array with shape (height, width, 4) representing RGBA data.
        The OS will automatically select the most appropriate size for different contexts
        (window decoration, taskbar, alt-tab switcher, etc).

        This property can only be set before the window is initialized,
        and cannot be retrieved once set. The icon data is not stored
        in the viewport object, but passed directly to the platform backend.

        Accepts:
        - A single array-like image with RGBA data (height, width, 4)
        - A sequence of array-like images with RGBA data

        """
        ...


    @icon.setter
    def icon(self, value):
        ...


    @property
    def max_height(self) -> int:
        """
        Maximum height the viewport window can be resized to.

        This sets an upper bound on the window height when the window is resizable.
        The user will not be able to resize the window larger than this value
        vertically. This can be useful to prevent the window from becoming
        impractically large.

        """
        ...


    @max_height.setter
    def max_height(self, value : int):
        ...


    @property
    def max_width(self) -> int:
        """
        Maximum width the viewport window can be resized to.

        This sets an upper bound on the window width when the window is resizable.
        The user will not be able to resize the window larger than this value
        horizontally. This can be useful to prevent the window from becoming
        impractically large.

        """
        ...


    @max_width.setter
    def max_width(self, value : int):
        ...


    @property
    def maximized(self) -> bool:
        """
        Whether the viewport is currently maximized.

        When maximized, the window occupies the maximum available space on the
        screen while still preserving its decorations. Setting this property to
        True maximizes the window, while setting it to False when maximized
        restores the window to its previous size and position.

        """
        ...


    @maximized.setter
    def maximized(self, value : bool):
        ...


    @property
    def metrics(self) -> dict:
        """
        (Read-only) Return rendering related metrics relative to the last frame.

        Times are returned in ns and use the monotonic clock
        delta of times are return in float as seconds.

        Render frames does in the folowing order:
        event handling (wait_for_input has effect there)
        rendering (going through all objects and calling imgui)
        presenting to the os (send to the OS the rendered frame)

        No average is performed. To get FPS, one can
        average delta_whole_frame and invert it.

        frame_count corresponds to the frame number to which
        the data refers to.

        """
        ...


    @property
    def min_height(self) -> int:
        """
        Minimum height the viewport window can be resized to.

        This sets a lower bound on the window height when the window is resizable.
        The user will not be able to resize the window smaller than this value
        vertically. This helps ensure your interface remains usable at smaller
        sizes.

        """
        ...


    @min_height.setter
    def min_height(self, value : int):
        ...


    @property
    def min_width(self) -> int:
        """
        Minimum width the viewport window can be resized to.

        This sets a lower bound on the window width when the window is resizable.
        The user will not be able to resize the window smaller than this value
        horizontally. This helps ensure your interface remains usable at smaller
        sizes.

        """
        ...


    @min_width.setter
    def min_width(self, value : int):
        ...


    @property
    def minimized(self) -> bool:
        """
        Whether the viewport is currently minimized.

        When minimized, the window is hidden from view and typically appears as an
        icon in the taskbar or dock. Setting this property to True minimizes the
        window, while setting it to False when minimized restores the window to
        its previous size and position.

        """
        ...


    @minimized.setter
    def minimized(self, value : bool):
        ...


    @property
    def pixel_height(self) -> int:
        """
        Actual height of the viewport in pixels.

        This is the true height in device pixels after applying DPI scaling. When
        rendering custom graphics or calculating exact screen positions, use this
        value rather than the logical height.

        """
        ...


    @pixel_height.setter
    def pixel_height(self, value : int):
        ...


    @property
    def pixel_width(self) -> int:
        """
        Actual width of the viewport in pixels.

        This is the true width in device pixels after applying DPI scaling. When
        rendering custom graphics or calculating exact screen positions, use this
        value rather than the logical width.

        """
        ...


    @pixel_width.setter
    def pixel_width(self, value : int):
        ...


    @property
    def resizable(self) -> bool:
        """
        Whether the viewport window can be resized by the user.

        When enabled, the user can resize the window by dragging its edges or
        corners. When disabled, the window size remains fixed and can only be
        changed programmatically through the width and height properties.

        """
        ...


    @resizable.setter
    def resizable(self, value : bool):
        ...


    @property
    def resize_callback(self):
        """
        Callback to be issued when the viewport is resized.

        The callback takes as input (sender, target, data), where
        data is a tuple containing:
            - The width in pixels
            - The height in pixels
            - The width according to the OS (OS dependent)
            - The height according to the OS (OS dependent)

        """
        ...


    @resize_callback.setter
    def resize_callback(self, value):
        ...


    @property
    def retrieve_framebuffer(self) -> bool:
        """
        Whether to activate the framebuffer retrieval.

        If set to true, the framebuffer field will be
        populated. This has a performance cost.

        """
        ...


    @retrieve_framebuffer.setter
    def retrieve_framebuffer(self, value : bool):
        ...


    @property
    def scale(self) -> float:
        """
        Multiplicative scale applied on top of the system DPI scaling.

        This user-defined scaling factor is combined with the system DPI to
        determine the final size of UI elements. Increasing this value makes
        all UI elements appear larger, which can improve readability or
        accommodate specific usability needs.

        """
        ...


    @scale.setter
    def scale(self, value : float):
        ...


    @property
    def shown(self) -> bool:
        """
        (Read-only) Whether the viewport window has been created by the operating system.

        """
        ...


    @property
    def theme(self):
        """
        Global theme applied to all elements within the viewport.

        Sets the default visual style for all UI elements in the application.
        Individual UI elements can override this by setting their own theme
        property. The theme controls colors, spacing, and other appearance
        aspects of the interface.

        """
        ...


    @theme.setter
    def theme(self, value):
        ...


    @property
    def title(self) -> str:
        """
        Text displayed in the viewport window's title bar.

        Sets the title text shown in the window decoration and in OS task
        switchers. This property has no effect if the window is undecorated
        or if the title bar is hidden.

        """
        ...


    @title.setter
    def title(self, value : str):
        ...


    @property
    def visible(self) -> bool:
        """
        State to control whether the viewport is associated to a window.

        If False, no window will be displayed for the viewport (offscreen rendering).
        Defaults to True.

        """
        ...


    @visible.setter
    def visible(self, value : bool):
        ...


    @property
    def vsync(self) -> bool:
        """
        Whether vertical synchronization is enabled.

        When enabled, frame rendering synchronizes with the display refresh rate
        to eliminate screen tearing. This provides smoother visuals but may limit
        the maximum frame rate to the display's refresh rate. Disabling vsync can
        increase responsiveness at the cost of potential visual artifacts.

        """
        ...


    @vsync.setter
    def vsync(self, value : bool):
        ...


    @property
    def wait_for_input(self) -> bool:
        """
        Stop refreshing when no mouse/keyboard event is detected.

        When this state is set, render_frame will block until
        a mouse or keyboard event is detected.

        It is possible to manually unblock render_frame by
        calling wake().

        In addition to mouse and keyboard events, many internal
        events also trigger a refresh. For instance DrawStream
        will trigger a refresh when it is time to draw the next
        element of the stream, or Tooltip will trigger a refresh
        after the requested delay without mouse movement.

        The goal is that any DearCyGui item handles viewport
        waking automatically themselves. This way, the user
        only needs to call wake() when he has appended new items,
        modified visual item properties or when he wants to.
        wake() is not called for the user for such operations
        because the idea is for the user to call wake() after a
        batch of operations.

        """
        ...


    @wait_for_input.setter
    def wait_for_input(self, value : bool):
        ...


    @property
    def width(self) -> int:
        """
        DPI invariant width of the viewport window.

        Represents the logical width of the viewport in DPI-independent units.
        The actual pixel width may differ based on the DPI scaling factor of the
        display. Use this value when you want consistent sizing across different
        display configurations.

        """
        ...


    @width.setter
    def width(self, value : int):
        ...


    @property
    def x_pos(self) -> int:
        """
        X position of the viewport window on the screen.

        Represents the horizontal position of the top-left corner of the viewport
        window in screen coordinates. This position is relative to the primary
        monitor's origin and may include OS-specific decorations.

        Note: Not all platforms support setting the X position of the window.
        In which case, this property may be ignored.

        """
        ...


    @x_pos.setter
    def x_pos(self, value : int):
        ...


    @property
    def y_pos(self) -> int:
        """
        Y position of the viewport window on the screen.

        Represents the vertical position of the top-left corner of the viewport
        window in screen coordinates. This position is relative to the primary
        monitor's origin and may include OS-specific decorations.

        Note: Not all platforms support setting the Y position of the window.
        In which case, this property may be ignored.

        """
        ...


    @y_pos.setter
    def y_pos(self, value : int):
        ...


class ViewportDrawList(drawingItem):
    """
    A drawing item that renders its children on the viewport's background or foreground.

    This is typically used to draw items that should always be visible,
    regardless of the current window or plot being displayed.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : Sequence[drawingItemSubCls] = [], front : bool = True, next_sibling : baseItemSubCls | None = None, parent : Viewport | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - front: Display the drawings in front of all items (rather than behind)
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Should the object be drawn/shown ?
        - user_data: User data of any type.
        """
        ...


    @property
    def front(self) -> bool:
        """Display the drawings in front of all items (rather than behind)
        """
        ...


    @front.setter
    def front(self, value : bool):
        ...


class Window(uiItem):
    """
    A window with configurable behaviors, appearance, and parent-child relationships.

    Windows provide containers for other UI elements and can be styled in various ways.
    They support features like collapsing, resizing, scrolling, and dragging, with
    optional title bars and close buttons.

    Windows can be configured as popups (temporary windows that close when clicking
    outside), modals (blocking windows that require explicit closure), or as primary
    windows (covering the entire viewport and serving as application backgrounds).

    Child items can be added using the standard parent-child mechanisms, and additional
    menu bars can be attached using menubar items.

    """
    def __init__(self, context : Context, always_show_horizontal_scrollvar : bool = False, always_show_vertical_scrollvar : bool = False, attach : Any = ..., autosize : bool = False, before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : Sequence[uiItemSubCls | MenuBarSubCls] = [], collapsed : bool = False, enabled : bool = True, focused : bool = False, font : Font = None, handlers : list = [], has_close_button : bool = True, height : float = 0.0, horizontal_scrollbar : bool = False, indent : float = 0.0, label : str = "", max_size : Sequence[float] | tuple[float, float] | Coord = (30000.0, 30000.0), menubar : bool = False, min_size : Sequence[float] | tuple[float, float] | Coord = (100.0, 100.0), modal : bool = False, next_sibling : baseItemSubCls | None = None, no_background : bool = False, no_bring_to_front_on_focus : bool = False, no_collapse : bool = False, no_focus_on_appearing : bool = False, no_keyboard_inputs : bool = False, no_mouse_inputs : bool = False, no_move : bool = False, no_newline : bool = False, no_open_over_existing_popup : bool = False, no_resize : bool = False, no_saved_settings : bool = False, no_scaling : bool = False, no_scroll_with_mouse : bool = False, no_scrollbar : bool = False, no_title_bar : bool = False, on_close : Any = ..., on_drop : Any = ..., parent : Viewport | None = None, popup : bool = False, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, primary : bool = False, scaling_factor : float = 1.0, shareable_value : SharedValue = ..., show : bool = True, theme : Any = ..., unsaved_document : bool = False, user_data : Any = ..., value : Any = ..., width : float = 0.0):
        """
        Parameters
        ----------
        - always_show_horizontal_scrollvar: Always displays the horizontal scrollbar even when content fits.
        - always_show_vertical_scrollvar: Always displays the vertical scrollbar even when content fits.
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - autosize: Makes the window automatically resize to fit its contents.
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - collapsed: Controls and reflects the collapsed state of the window.
        - enabled: Whether the item is interactive and fully styled.
        - focused: Whether this item has input focus.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - has_close_button: Controls whether the window displays a close button in its title bar.
        - height: Requested height for the item.
        - horizontal_scrollbar: Enables horizontal scrolling for content that exceeds window width.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - max_size: Sets the maximum allowed size for the window.
        - menubar: Controls whether the window displays a menu bar.
        - min_size: Sets the minimum allowed size for the window.
        - modal: Makes the window a modal dialog that blocks interaction with other windows.
        - next_sibling: Child of the parent rendered just after this item.
        - no_background: Makes the window background transparent and removes the border.
        - no_bring_to_front_on_focus: Prevents the window from coming to the front when focused.
        - no_collapse: Disables collapsing the window by double-clicking the title bar.
        - no_focus_on_appearing: Prevents the window from gaining focus when it first appears.
        - no_keyboard_inputs: Disables keyboard input and keyboard navigation for the window.
        - no_mouse_inputs: Disables mouse input events for the window and its contents.
        - no_move: Prevents the window from being moved by the user.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_open_over_existing_popup: Prevents opening if another popup is already visible.
        - no_resize: Disables resizing of the window by the user.
        - no_saved_settings: Prevents the window from saving its position and size between sessions.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - no_scroll_with_mouse: Disables scrolling the window content with the mouse wheel.
        - no_scrollbar: Hides the scrollbars when content overflows.
        - no_title_bar: Hides the title bar of the window.
        - on_close: Callback that will be triggered when the window is closed.
        - on_drop: Callback triggered when items are drag-dropped onto the window.
        - parent: Parent of the item in the rendering tree.
        - popup: Makes the window a popup that closes when clicking outside it.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - primary: Controls whether this window serves as the primary application window.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - unsaved_document: Displays a dot next to the window title to indicate unsaved changes.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def always_show_horizontal_scrollvar(self) -> bool:
        """
        Always displays the horizontal scrollbar even when content fits.

        When enabled, the horizontal scrollbar will always be visible (if horizontal
        scrolling is enabled), even when the content does not exceed the window width.
        This provides a consistent appearance across different content states.

        """
        ...


    @always_show_horizontal_scrollvar.setter
    def always_show_horizontal_scrollvar(self, value : bool):
        ...


    @property
    def always_show_vertical_scrollvar(self) -> bool:
        """
        Always displays the vertical scrollbar even when content fits.

        When enabled, the vertical scrollbar will always be visible, even when the
        content does not exceed the window height. This can provide a more consistent
        appearance across different content states.

        """
        ...


    @always_show_vertical_scrollvar.setter
    def always_show_vertical_scrollvar(self, value : bool):
        ...


    @property
    def autosize(self) -> bool:
        """
        Makes the window automatically resize to fit its contents.

        When enabled, the window will continuously adjust its size to fit its
        content area. This can be useful for dialog boxes or panels that should
        always show all their contents without scrolling.

        """
        ...


    @autosize.setter
    def autosize(self, value : bool):
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def collapsed(self) -> bool:
        """
        Controls and reflects the collapsed state of the window.

        When True, the window is collapsed (minimized) showing only its title bar.
        When False, the window is expanded showing its full content. This property
        can both be read to detect the current state and written to collapse or
        expand the window.

        """
        ...


    @collapsed.setter
    def collapsed(self, value : bool):
        ...


    @property
    def content_pos(self) -> Coord:
        """
        (Read-only) Position of the content area's top-left corner.

        This property provides the viewport-relative coordinates of the starting
        point for an item's content area. This is where child elements begin to be
        placed by default.

        Used together with content_region_avail, this defines the rectangle
        available for child elements.

        """
        ...


    @property
    def content_region_avail(self) -> Coord:
        """
        (Read-only) Available space for child items.

        For container items like windows, child windows, this
        property represents the available space for placing child items. This is
        the item's inner area after accounting for padding, borders, and other
        non-content elements.

        Areas that require scrolling to see are not included in this measurement.

        """
        ...


    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.

        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.

        """
        ...


    @focused.setter
    def focused(self, value : bool):
        ...


    @property
    def has_close_button(self) -> bool:
        """
        Controls whether the window displays a close button in its title bar.

        When enabled, the window will show a close button in its title bar that
        allows users to close the window. This applies only to regular and
        modal windows, as popup windows do not have close buttons.

        """
        ...


    @has_close_button.setter
    def has_close_button(self, value : bool):
        ...


    @property
    def horizontal_scrollbar(self) -> bool:
        """
        Enables horizontal scrolling for content that exceeds window width.

        When enabled, the window will display a horizontal scrollbar when content
        extends beyond the window's width. Otherwise, content will simply be clipped
        at the window's edge.

        """
        ...


    @horizontal_scrollbar.setter
    def horizontal_scrollbar(self, value : bool):
        ...


    @property
    def hovered(self) -> bool:
        """
        (Read-only) Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.

        """
        ...


    @property
    def max_size(self) -> Coord:
        """
        Sets the maximum allowed size for the window.

        Defines the maximum width and height the window can be resized to, either
        by the user or programmatically. Values are given as (width, height) in
        logical pixels, and will be multiplied by the DPI scaling factor.

        """
        ...


    @max_size.setter
    def max_size(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def menubar(self) -> bool:
        """
        Controls whether the window displays a menu bar.

        When enabled, the window will reserve space for a menu bar at the top.
        Menu items can be added as child elements with the appropriate type.
        The menu bar will appear automatically if any menu child items exist,
        even if this property is set to False.

        """
        ...


    @menubar.setter
    def menubar(self, value : bool):
        ...


    @property
    def min_size(self) -> Coord:
        """
        Sets the minimum allowed size for the window.

        Defines the minimum width and height the window can be resized to, either
        by the user or programmatically. Values are given as (width, height) in
        logical pixels, and will be multiplied by the DPI scaling factor.

        """
        ...


    @min_size.setter
    def min_size(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def modal(self) -> bool:
        """
        Makes the window a modal dialog that blocks interaction with other windows.

        When enabled, the window will behave as a modal dialog - it will capture all
        input until closed, preventing interaction with any other windows behind it.
        Modal windows typically have close buttons and must be explicitly dismissed.

        """
        ...


    @modal.setter
    def modal(self, value : bool):
        ...


    @property
    def no_background(self) -> bool:
        """
        Makes the window background transparent and removes the border.

        When enabled, the window's background color and border will not be drawn,
        allowing content behind the window to show through. Useful for overlay windows
        or custom-drawn windows.

        """
        ...


    @no_background.setter
    def no_background(self, value : bool):
        ...


    @property
    def no_bring_to_front_on_focus(self) -> bool:
        """
        Prevents the window from coming to the front when focused.

        When enabled, the window will not rise to the top of the window stack when
        clicked or otherwise focused. This is useful for background windows that
        should remain behind other windows even when interacted with.

        """
        ...


    @no_bring_to_front_on_focus.setter
    def no_bring_to_front_on_focus(self, value : bool):
        ...


    @property
    def no_collapse(self) -> bool:
        """
        Disables collapsing the window by double-clicking the title bar.

        When enabled, the window cannot be collapsed (minimized) by double-clicking
        its title bar. The collapsed state can still be changed programmatically.

        """
        ...


    @no_collapse.setter
    def no_collapse(self, value : bool):
        ...


    @property
    def no_focus_on_appearing(self) -> bool:
        """
        Prevents the window from gaining focus when it first appears.

        When enabled, the window will not automatically gain keyboard focus when it
        is first shown or when changing from hidden to visible state. This can be
        useful for non-interactive windows or background panels.

        """
        ...


    @no_focus_on_appearing.setter
    def no_focus_on_appearing(self, value : bool):
        ...


    @property
    def no_keyboard_inputs(self) -> bool:
        """
        Disables keyboard input and keyboard navigation for the window.

        When enabled, the window will not take keyboard focus or respond to keyboard
        navigation commands. Items inside the window can still receive keyboard focus
        and inputs if focused directly.

        """
        ...


    @no_keyboard_inputs.setter
    def no_keyboard_inputs(self, value : bool):
        ...


    @property
    def no_mouse_inputs(self) -> bool:
        """
        Disables mouse input events for the window and its contents.

        When enabled, mouse events like clicking, hovering, and dragging will pass
        through the window to items behind it. Items within the window will not
        receive mouse events either.

        """
        ...


    @no_mouse_inputs.setter
    def no_mouse_inputs(self, value : bool):
        ...


    @property
    def no_move(self) -> bool:
        """
        Prevents the window from being moved by the user.

        When enabled, the window cannot be repositioned by dragging the title bar.
        The position can still be changed programmatically.

        """
        ...


    @no_move.setter
    def no_move(self, value : bool):
        ...


    @property
    def no_open_over_existing_popup(self) -> bool:
        """
        Prevents opening if another popup is already visible.

        When enabled for modal and popup windows, the window will not open if another
        popup/modal window is already active. This prevents layering of popups that
        could confuse users.

        """
        ...


    @no_open_over_existing_popup.setter
    def no_open_over_existing_popup(self, value : bool):
        ...


    @property
    def no_resize(self) -> bool:
        """
        Disables resizing of the window by the user.

        When enabled, the window cannot be resized by dragging its borders or corners.
        The size can still be changed programmatically.

        """
        ...


    @no_resize.setter
    def no_resize(self, value : bool):
        ...


    @property
    def no_saved_settings(self) -> bool:
        """
        Prevents the window from saving its position and size between sessions.

        When enabled, the window's position, size, and collapsed state will not be
        saved to or loaded from the ImGui .ini file, keeping the window's appearance
        consistent across application restarts.

        """
        ...


    @no_saved_settings.setter
    def no_saved_settings(self, value : bool):
        ...


    @property
    def no_scroll_with_mouse(self) -> bool:
        """
        Disables scrolling the window content with the mouse wheel.

        When enabled, the mouse wheel will not scroll the window's content, though
        scrolling via keyboard or programmatic means remains possible.

        """
        ...


    @no_scroll_with_mouse.setter
    def no_scroll_with_mouse(self, value : bool):
        ...


    @property
    def no_scrollbar(self) -> bool:
        """
        Hides the scrollbars when content overflows.

        When enabled, scrollbars will not be shown even when content exceeds the
        window's size. Note that this only affects the visual appearance - scrolling
        via keyboard or mouse wheel remains possible unless disabled separately.

        """
        ...


    @no_scrollbar.setter
    def no_scrollbar(self, value : bool):
        ...


    @property
    def no_title_bar(self) -> bool:
        """
        Hides the title bar of the window.

        When enabled, the window will not display its title bar, which includes
        the window title, collapse button, and close button if enabled.

        """
        ...


    @no_title_bar.setter
    def no_title_bar(self, value : bool):
        ...


    @property
    def on_close(self):
        """
        Callback that will be triggered when the window is closed.

        This callback is invoked when the window is closed, either by clicking the
        close button or programmatically. Note that closing a window doesn't destroy
        it, but sets its show property to False. The callback receives the window as
        both source and target parameters.

        """
        ...


    @on_close.setter
    def on_close(self, value):
        ...


    @property
    def on_drop(self):
        """
        Callback triggered when items are drag-dropped onto the window.

        This callback is invoked when the user drags external content (files or text)
        and drops it onto the window. The callback receives source, target, and data
        parameters, where data is a tuple containing the drop type (0=text, 1=files)
        and a list of strings with the actual content.

        """
        ...


    @on_drop.setter
    def on_drop(self, value):
        ...


    @property
    def popup(self) -> bool:
        """
        Makes the window a popup that closes when clicking outside it.

        When enabled, the window will behave as a popup - it will be centered on
        screen by default and will close automatically when the user clicks outside
        of it. Popups do not have close buttons.

        """
        ...


    @popup.setter
    def popup(self, value : bool):
        ...


    @property
    def primary(self) -> bool:
        """
        Controls whether this window serves as the primary application window.

        When set to True, the window becomes the primary window covering the entire
        viewport. It will be drawn behind all other windows, have no decorations,
        and cannot be moved or resized. Only one window can be primary at a time.

        Primary windows are useful for implementing main application backgrounds
        or base layouts that other windows will overlay.

        """
        ...


    @primary.setter
    def primary(self, value : bool):
        ...


    @property
    def unsaved_document(self) -> bool:
        """
        Displays a dot next to the window title to indicate unsaved changes.

        When enabled, the window's title bar will display a small indicator dot,
        similar to how many applications mark documents with unsaved changes.
        This is purely visual and does not affect window behavior.

        """
        ...


    @unsaved_document.setter
    def unsaved_document(self, value : bool):
        ...


class WindowHorizontalLayout(WindowLayout):
    """
    Layout to organize windows horizontally.

    Similar to HorizontalLayout but handles window positioning.
    Windows will be arranged left-to-right with customizable alignment
    and spacing options.

    Windows can be aligned to the left or right edge, centered, distributed
    evenly using justified mode, or positioned manually. The layout
    automatically tracks content width changes and repositions windows
    when needed.

    """
    def __init__(self, context : Context, alignment_mode : Alignment = 0, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : None  = [], enabled : bool = True, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), positions : list = [], previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedValue = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : Any = ..., width : float = 0.0):
        """
        Parameters
        ----------
        - alignment_mode: Horizontal alignment mode of the windows.
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - positions: X positions for windows when using MANUAL alignment mode.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def alignment_mode(self) -> Alignment:
        """
        Horizontal alignment mode of the windows.

        LEFT: windows are appended from the left
        RIGHT: windows are appended from the right
        CENTER: windows are centered
        JUSTIFIED: spacing is organized such that windows start at the left
            and end at the right
        MANUAL: windows are positioned at the requested positions

        The default is LEFT.

        """
        ...


    @alignment_mode.setter
    def alignment_mode(self, value : Alignment):
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def positions(self) -> list:
        """
        X positions for windows when using MANUAL alignment mode.

        When in MANUAL mode, these are the x positions from the top left of this
        layout at which to place the windows.

        Values between 0 and 1 are interpreted as percentages relative to the
        available viewport width. Negative values are interpreted as relative to
        the right edge rather than the left.

        Setting this property automatically sets alignment_mode to MANUAL.

        """
        ...


    @positions.setter
    def positions(self, value : list):
        ...


class WindowLayout(uiItem):
    """
    Same as Layout, but for windows.
    Unlike Layout, WindowLayout doesn't
    have any accessible state, except
    for the position and rect size.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : None  = [], enabled : bool = True, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedValue = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : Any = ..., width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    def update_layout(self):
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def content_pos(self) -> Coord:
        """
        (Read-only) Position of the content area's top-left corner.

        This property provides the viewport-relative coordinates of the starting
        point for an item's content area. This is where child elements begin to be
        placed by default.

        Used together with content_region_avail, this defines the rectangle
        available for child elements.

        """
        ...


    @property
    def content_region_avail(self) -> Coord:
        """
        (Read-only) Available space for child items.

        For container items like windows, child windows, this
        property represents the available space for placing child items. This is
        the item's inner area after accounting for padding, borders, and other
        non-content elements.

        Areas that require scrolling to see are not included in this measurement.

        """
        ...


class WindowVerticalLayout(WindowLayout):
    """
    Layout to organize windows vertically.

    Similar to VerticalLayout but handles window positioning.
    Windows will be arranged top-to-bottom with customizable alignment
    and spacing options. It can align windows to the top or bottom edge,
    center them, distribute them evenly using the justified mode, or position
    them manually.

    The layout automatically tracks content height changes and repositions
    windows when needed. Different alignment modes can be used to control
    how windows are positioned within the available vertical space.

    """
    def __init__(self, context : Context, alignment_mode : Alignment = 0, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : None  = [], enabled : bool = True, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), positions : list = [], previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedValue = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : Any = ..., width : float = 0.0):
        """
        Parameters
        ----------
        - alignment_mode: Vertical alignment mode of the windows.
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - positions: Y positions for windows when using MANUAL alignment mode.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def alignment_mode(self) -> Alignment:
        """
        Vertical alignment mode of the windows.

        TOP: windows are appended from the top
        BOTTOM: windows are appended from the bottom
        CENTER: windows are centered
        JUSTIFIED: spacing is organized such that windows start at the top
            and end at the bottom
        MANUAL: windows are positioned at the requested positions

        For TOP/BOTTOM/CENTER, ItemSpacing's style can be used to control
        spacing between the windows. Default is TOP.

        """
        ...


    @alignment_mode.setter
    def alignment_mode(self, value : Alignment):
        ...


    @property
    def positions(self) -> list:
        """
        Y positions for windows when using MANUAL alignment mode.

        When in MANUAL mode, these are the y positions from the top left of this
        layout at which to place the windows.

        Values between 0 and 1 are interpreted as percentages relative to the
        layout height. Negative values are interpreted as relative to the bottom
        edge rather than the top. Windows are still top-aligned to the target
        position.

        Setting this property automatically sets alignment_mode to MANUAL.

        """
        ...


    @positions.setter
    def positions(self, value : list):
        ...


class baseFont(baseItem):
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : Sequence[baseItemSubCls] = [], next_sibling : baseItemSubCls | None = None, parent : baseItemSubCls | None = None, previous_sibling : baseItemSubCls | None = None, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - user_data: User data of any type.
        """
        ...


class baseHandler(baseItem):
    """
    Base class for UI input event handlers.

    Handlers track and respond to various UI states and events, allowing callbacks
    to be triggered when specific conditions are met. They can be attached to any
    item to monitor its state changes.

    Handlers provide a flexible way to implement interactive behavior without
    cluttering application logic with state checking code. Multiple handlers can be
    attached to a single item to respond to different aspects of its state.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseThemeSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: Function called when the handler's condition is met.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the handler is active and processing events.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Alias for the enabled property provided for backward compatibility.
        - user_data: User data of any type.
        """
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        Function called when the handler's condition is met.

        The callback is invoked with three arguments: the handler itself,
        the item that triggered the callback, and optional additional data
        specific to the handler type. The callback format is compatible with
        the Callback class.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def enabled(self) -> bool:
        """
        Controls whether the handler is active and processing events.

        When disabled, the handler will not check states or trigger callbacks,
        effectively pausing its functionality without removing it. This allows
        for temporarily disabling interaction behaviors.

        """
        ...


    @enabled.setter
    def enabled(self, value : bool):
        ...


    @property
    def show(self) -> bool:
        """
        Alias for the enabled property provided for backward compatibility.

        This property mirrors the enabled property in all aspects, maintaining
        compatibility with code that uses show instead of enabled.

        """
        ...


    @show.setter
    def show(self, value : bool):
        ...


class baseItem(object):
    """
    Base class for all items (except shared values).

    To be rendered, an item must be in the child tree of the viewport (context.viewport).

    Parent-Child Relationships:
    -------------------------
    The parent of an item can be set in several ways:
        1. Using the parent attribute: `item.parent = target_item`
        2. Passing `parent=target_item` during item creation
        3. Using the context manager ('with' statement) - if no parent is explicitly set, the last item in the 'with' block becomes the parent
        4. Setting previous_sibling or next_sibling attributes to insert the item between existing siblings

    Tree Structure:
    --------------
        - Items are rendered in order from first child to last child
        - New items are inserted last by default unless previous_sibling/next_sibling is used
        - Items can be manually detached by setting parent = None
        - Most items have restrictions on what parents/children they can have
        - Some items can have multiple incompatible child lists that are concatenated when reading item.children

    The parent, previous_sibling and next_sibling relationships form a doubly-linked tree structure that determines rendering order and hierarchy.
    The children attribute provides access to all child items.

    Special Cases:
    -------------
    Some items cannot be children in the rendering tree:
        - PlaceHolderParent: Can be parent to any item but cannot be in rendering tree
        - Textures, themes, colormaps and fonts: Cannot be children but can be bound to items

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : Sequence[baseItemSubCls] = [], next_sibling : baseItemSubCls | None = None, parent : baseItemSubCls | None = None, previous_sibling : baseItemSubCls | None = None, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - user_data: User data of any type.
        """
        ...


    def attach_before(self, target):
        """
        Same as item.next_sibling = target, but target must not be None

        """
        ...


    def attach_to_parent(self, target):
        """
        Same as item.parent = target, but target must not be None

        """
        ...


    def configure(self, children : Sequence[baseItemSubCls] = [], next_sibling : baseItemSubCls | None = None, parent : baseItemSubCls | None = None, previous_sibling : baseItemSubCls | None = None, user_data : Any = ...):
        """
        Shortcut to set multiple attributes at once.

        Parameters
        ----------
        - children: List of all the children of the item, from first rendered, to last rendered.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - user_data: User data of any type.
        """
        ...


    def copy(self, target_context=None):
        """
        Shallow copy of the item to the target context.

        Performs a deep copy of the child tree.

        Parameters:
        target_context : Context, optional
            Target context for the copy. Defaults to None.
            (None = source's context)

        Returns:
        baseItem
            Copy of the item in the target context.

        """
        ...


    def delete_item(self):
        """
        Deletes the item and all its children.

        When an item is not referenced anywhere, it might
        not get deleted immediately, due to circular references.
        The Python garbage collector will eventually catch
        the circular references, but to speedup the process,
        delete_item will recursively detach the item
        and all elements in its subtree, as well as bound
        items. As a result, items with no more references
        will be freed immediately.

        """
        ...


    def detach_item(self):
        """
        Same as item.parent = None

        The item states (if any) are updated
        to indicate it is not rendered anymore,
        and the information propagated to the
        children.

        """
        ...


    def lock_mutex(self, wait=False):
        """
        Lock the internal item mutex.

        **Know what you are doing**

        Locking the mutex will prevent:
            - Other threads from reading/writing
            attributes or calling methods with this item,
            editing the children/parent of the item
            - Any rendering of this item and its children.
            If the viewport attemps to render this item,
            it will be blocked until the mutex is released.
            (if the rendering thread is holding the mutex,
            no blocking occurs)

        This is useful if you want to edit several attributes
        in several commands of an item or its subtree,
        and prevent rendering or other threads from accessing
        the item until you have finished.

        If you plan on moving the item position in the rendering
        tree, to avoid deadlock you must hold the mutex of a
        parent of all the items involved in the motion (a common
        parent of the source and target parent). This mutex has to
        be locked before you lock any mutex of your child item
        if this item is already in the rendering tree (to avoid
        deadlock with the rendering thread).
        If you are unsure and plans to move an item already
        in the rendering tree, it is thus best to lock the viewport
        mutex first.

        Input argument:
            - wait (default = False): if locking the mutex fails (mutex
            held by another thread), wait it is released

        Returns: True if the mutex is held, False else.

        The mutex is a recursive mutex, thus you can lock it several
        times in the same thread. Each lock has to be matched to an unlock.

        """
        ...


    def unlock_mutex(self):
        """
        Unlock a previously held mutex on this object by this thread.

        Returns True on success, False if no lock was held by this thread.

        """
        ...


    def __enter__(self) -> baseItem:
        ...


    def __exit__(self, exc_type : Any, exc_value : Any, traceback : Any) -> bool:
        ...


    @property
    def children(self) -> Sequence[baseItemSubCls]:
        """
        List of all the children of the item, from first rendered, to last rendered.

        When written to, an error is raised if the children already
        have other parents. This error is meant to prevent programming
        mistakes, as users might not realize the children were
        unattached from their former parents.

        """
        ...


    @children.setter
    def children(self, value : Sequence[baseItemSubCls]):
        ...


    @property
    def children_types(self) -> ChildType:
        """
        (Read-only) Returns which types of children can be attached to this item

        """
        ...


    @property
    def context(self) -> Context:
        """
        (Read-only) Context in which the item resides

        """
        ...


    @property
    def item_type(self) -> ChildType:
        """
        (Read-only) Returns which type of child this item is

        """
        ...


    @property
    def mutex(self) -> wrap_mutex:
        """
        (Read-only) Context manager instance for the item mutex

        Locking the mutex will prevent:
            - Other threads from reading/writing
            attributes or calling methods with this item,
            editing the children/parent of the item
            - Any rendering of this item and its children.
            If the viewport attemps to render this item,
            it will be blocked until the mutex is released.
            (if the rendering thread is holding the mutex,
            no blocking occurs)

        In general, you don't need to use any mutex in your code,
        unless you are writing a library and cannot make assumptions
        on what the users will do, or if you know your code manipulates
        the same objects with multiple threads.

        All attribute accesses are mutex protected.

        If you want to subclass and add attributes, you
        can use this mutex to protect your new attributes.
        Be careful not to hold the mutex if your thread
        intends to access the attributes of a parent item.
        In case of doubt use parents_mutex instead.

        """
        ...


    @property
    def next_sibling(self) -> baseItemSubCls | None:
        """
        Child of the parent rendered just after this item.

        It is not possible to have siblings if you have no parent,
        thus if you intend to attach together items outside the
        rendering tree, there must be a toplevel parent item.

        If you write to this attribute, the item will be moved
        to be inserted just before the target item.
        In case of failure, the item remains in a detached state.

        """
        ...


    @next_sibling.setter
    def next_sibling(self, value : baseItemSubCls | None):
        ...


    @property
    def parent(self) -> baseItemSubCls | None:
        """
        Parent of the item in the rendering tree.

        Rendering starts from the viewport. Then recursively each child
        is rendered from the first to the last, and each child renders
        their subtree.

        Only an item inserted in the rendering tree is rendered.
        An item that is not in the rendering tree can have children.
        Thus it is possible to build and configure various items, and
        attach them to the tree in a second phase.

        The children hold a reference to their parent, and the parent
        holds a reference to its children. Thus to be release memory
        held by an item, two options are possible:
            - Remove the item from the tree, remove all your references.
            If the item has children or siblings, the item will not be
            released until Python's garbage collection detects a
            circular reference.
            - Use delete_item to remove the item from the tree, and remove
            all the internal references inside the item structure and
            the item's children, thus allowing them to be removed from
            memory as soon as the user doesn't hold a reference on them.

        Note the viewport is referenced by the context.

        If you set this attribute, the item will be inserted at the last
        position of the children of the parent (regardless whether this
        item is already a child of the parent).
        If you set None, the item will be removed from its parent's children
        list.

        """
        ...


    @parent.setter
    def parent(self, value : baseItemSubCls | None):
        ...


    @property
    def parents_mutex(self) -> wrap_this_and_parents_mutex:
        """
        (Read-only) Context manager instance for the item mutex and all its parents

        Similar to mutex but locks not only this item, but also all
        its current parents.
        If you want to access parent fields, or if you are unsure,
        lock this mutex rather than self.mutex.
        This mutex will lock the item and all its parent in a safe
        way that does not deadlock.

        """
        ...


    @property
    def previous_sibling(self) -> baseItemSubCls | None:
        """
        Child of the parent rendered just before this item.

        It is not possible to have siblings if you have no parent,
        thus if you intend to attach together items outside the
        rendering tree, there must be a toplevel parent item.

        If you write to this attribute, the item will be moved
        to be inserted just after the target item.
        In case of failure, the item remains in a detached state.

        Note that a parent can have several child queues, and thus
        child elements are not guaranteed to be siblings of each other.

        """
        ...


    @previous_sibling.setter
    def previous_sibling(self, value : baseItemSubCls | None):
        ...


    @property
    def user_data(self):
        """
        User data of any type.

        To prevent programmer mistakes and improved performance,
        base DearCyGui items do only accept predefined attributes.

        This attribute is meant to be used by the user to attach
        any custom data to the item.

        An alternative for more complex needs is to subclass
        the item and add your own attributes. Subclassed items
        (unless using slots explicitly) do accept any attribute.

        """
        ...


    @user_data.setter
    def user_data(self, value):
        ...


    @property
    def uuid(self) -> int:
        """
        (Read-only) Unique identifier created by the context for the item.

        uuid serves as an internal identifier for the item.
        It is not meant to be used as a key for the item, use the
        item directly for that purpose.

        """
        ...


class baseTable(uiItem):
    """
    Base class for Table widgets.

    A table is a grid of cells, where each cell can contain
    text, images, buttons, etc. The table can be used to
    display data, but also to interact with the user.

    This base class implements all the python interactions
    and the basic structure of the table. The actual rendering
    is done by the derived classes.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : Sequence[uiItemSubCls] = [], enabled : bool = True, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, num_cols_frozen : int = 0, num_cols_visible : Any = ..., num_rows_frozen : int = 0, num_rows_visible : Any = ..., parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedValue = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : Any = ..., width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - num_cols_frozen: Number of columns with scroll frozen.
        - num_cols_visible: Override the number of visible columns in the table.
        - num_rows_frozen: Number of rows with scroll frozen.
        - num_rows_visible: Override the number of visible rows in the table.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    def _set_single_item(self, row, col, value):
        """
        Set items at specific target

        """
        ...


    def append_col(self, items):
        """
        Appends a column at the end of the table.

        """
        ...


    def append_row(self, items):
        """
        Appends a row at the end of the table.

        """
        ...


    def clear(self) -> None:
        """
        Release all items attached to the table.

        Does now clear row and column configurations.
        These are cleared only when the Table is released.

        """
        ...


    def col(self, idx):
        """
Get a view of the specified column.
        """
        ...


    def delete_item(self):
        ...


    def get(self, key, default=None):
        """
        Get the value at a specific key.

        """
        ...


    def insert_col(self, col, items=None):
        """
        Inserts a column at the given index.

        """
        ...


    def insert_row(self, row, items=None):
        """
        Inserts a row at the given index.

        """
        ...


    def keys(self):
        """
        Get the keys of the table.

        """
        ...


    def remove_col(self, col):
        """
        Removes the column at the given index.

        """
        ...


    def remove_row(self, row):
        """
        Removes the row at the given index.

        """
        ...


    def row(self, idx):
        """
Get a view of the specified row.
        """
        ...


    def set_col(self, col, items):
        """
        Sets the column at the given index.

        """
        ...


    def set_row(self, row, items):
        """
        Sets the row at the given index.

        """
        ...


    def sort_cols(self, ref_row, ascending=True):
        """
Sort the columns using the value in ref_row as index.

        The sorting order is defined using the items's ordering_value
        when ordering_value is not set, it defaults to:
        - The content string (if it is a string)
        - The content before its conversion into string
        - If content is an uiItem, it defaults to the UUID (item creation order)

        """
        ...


    def sort_rows(self, ref_col, ascending=True):
        """
Sort the rows using the value in ref_col as index.

        The sorting order is defined using the items's ordering_value
        when ordering_value is not set, it defaults to:
        - The content string (if it is a string)
        - The content before its conversion into string
        - If content is an uiItem, it defaults to the UUID (item creation order)

        """
        ...


    def swap(self, key1, key2):
        """
        Swaps the items at the two keys.

        Same as
        tmp = table[key1]
        table[key1] = table[key2]
        table[key2] = tmp

        But much more efficient

        """
        ...


    def swap_cols(self, col1, col2):
        """
        Swaps the cols at the two indices.

        """
        ...


    def swap_rows(self, row1, row2):
        """
        Swaps the rows at the two indices.

        """
        ...


    def values(self):
        """
        Get the values of the table.

        """
        ...


    def __enter__(self) -> baseTable:
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def next_col(self) -> TableColView:
        """(Read-only) Get a view of the next column.
        """
        ...


    @property
    def next_row(self) -> TableRowView:
        """(Read-only) Get a view of the next row.
        """
        ...


    @property
    def num_cols(self) -> int:
        """
        (Read-only) Get the number of columns in the table.

        This corresponds to the maximum column
        index used in the table.

        """
        ...


    @property
    def num_cols_frozen(self) -> int:
        """
        Number of columns with scroll frozen.

        Default is 0.

        """
        ...


    @num_cols_frozen.setter
    def num_cols_frozen(self, value : int):
        ...


    @property
    def num_cols_visible(self):
        """
        Override the number of visible columns in the table.

        By default (None), the number of visible columns
        is the same as the number of columns in the table.

        """
        ...


    @num_cols_visible.setter
    def num_cols_visible(self, value):
        ...


    @property
    def num_rows(self) -> int:
        """
        (Read-only) Get the number of rows in the table.

        This corresponds to the maximum row
        index used in the table.

        """
        ...


    @property
    def num_rows_frozen(self) -> int:
        """
        Number of rows with scroll frozen.

        Default is 0.

        """
        ...


    @num_rows_frozen.setter
    def num_rows_frozen(self, value : int):
        ...


    @property
    def num_rows_visible(self):
        """
        Override the number of visible rows in the table.

        By default (None), the number of visible rows
        is the same as the number of rows in the table.

        """
        ...


    @num_rows_visible.setter
    def num_rows_visible(self, value):
        ...


class baseTheme(baseItem):
    """
    Base theme element containing visual style settings.

    A theme defines a set of visual properties that can be applied to UI elements
    to control their appearance. Themes can target different backends (ImGui, ImPlot) and different aspects (colors, styles).

    Themes are applied hierarchically - a theme attached to a parent item will
    affect all its children unless overridden. Multiple themes can be combined,
    with more specific themes taking precedence over more general ones.

    Themes can be conditionally applied based on element states (enabled/disabled,
    hovered/unhovered) and element categories (window, plot, node, etc).

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseHandlerSubCls | None = None, previous_sibling : baseItemSubCls | None = None, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the theme is currently active.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - user_data: User data of any type.
        """
        ...


    def configure(self, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseHandlerSubCls | None = None, previous_sibling : baseItemSubCls | None = None, user_data : Any = ...):
        """
        Parameters
        ----------
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the theme is currently active.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - user_data: User data of any type.
        """
        ...


    @property
    def enabled(self) -> bool:
        """
        Controls whether the theme is currently active.

        When set to False, the theme will not be applied when its push() method is
        called, effectively disabling its visual effects without removing it from
        the item hierarchy.

        """
        ...


    @enabled.setter
    def enabled(self, value : bool):
        ...


class baseThemeColor(baseTheme):
    """
    Base class for theme colors that provides common color-related functionality.

    This class provides the core implementation for managing color themes in different
    contexts (ImGui/ImPlot). Color themes allow setting colors for various UI
    elements using different color formats:
    - unsigned int (encodes rgba little-endian)
    - (r, g, b, a) with values as integers [0-255]
    - (r, g, b, a) with values as normalized floats [0.0-1.0]
    - If alpha is omitted, it defaults to 255

    The class implements common dictionary-style access to colors through string names
    or numeric indices.

    """
    def __init__(self, context : Context, attach : Color| None = None, before : Color| None = None, children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, parent : baseHandlerSubCls | None = None, previous_sibling : baseItemSubCls | None = None, user_data : Color| None = None):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the theme is currently active.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - user_data: User data of any type.
        """
        ...


class baseThemeStyle(baseTheme):
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : None  = [], enabled : bool = True, next_sibling : baseItemSubCls | None = None, no_rounding : bool = True, no_scaling : bool = False, parent : baseHandlerSubCls | None = None, previous_sibling : baseItemSubCls | None = None, user_data : tuple[float, float] | None = None):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Controls whether the theme is currently active.
        - next_sibling: Child of the parent rendered just after this item.
        - no_rounding: boolean. Defaults to False.
        - no_scaling: boolean. Defaults to False.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - user_data: User data of any type.
        """
        ...


    @property
    def no_rounding(self) -> bool:
        """
        boolean. Defaults to False.
        If set, disables rounding (after scaling) to the
        closest integer the parameters. The rounding is only
        applied to parameters which impact item positioning
        in a way that would prevent a pixel perfect result.

        """
        ...


    @no_rounding.setter
    def no_rounding(self, value : bool):
        ...


    @property
    def no_scaling(self) -> bool:
        """
        boolean. Defaults to False.
        If set, disables the automated scaling to the dpi
        scale value for this theme

        """
        ...


    @no_scaling.setter
    def no_scaling(self, value : bool):
        ...


class drawingItem(baseItem):
    """
    A simple item with no UI state that inherits from the drawing area of its parent.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., children : None  = [], next_sibling : baseItemSubCls | None = None, parent : DrawInWindowSubCls | DrawInPlotSubCls | ViewportDrawListSubCls | drawingItemSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Should the object be drawn/shown ?
        - user_data: User data of any type.
        """
        ...


    @property
    def show(self) -> bool:
        """
        Should the object be drawn/shown ?

        In case show is set to False, this disables any
        callback (for example the close callback won't be called
        if a window is hidden with show = False).
        In the case of items that can be closed,
        show is set to False automatically on close.

        """
        ...


    @show.setter
    def show(self, value : bool):
        ...


class plotElement(baseItem):
    """
    Base class for plot children with rendering capabilities.

    Provides the foundation for all plot elements like lines, scatter plots,
    and bars. These elements can be attached to a parent plot and will be
    rendered according to their configuration.

    Plot elements can be assigned to specific axes pairs, allowing for
    multiple data series with different scales to coexist on the same plot.
    They also support themes for consistent visual styling.

    """
    def __init__(self, context : Context, attach : Any = ..., axes : tuple = (0, 3), before : Any = ..., children : None  = [], label : str = "", next_sibling : baseItemSubCls | None = None, parent : PlotSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, theme : Any = ..., user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - axes: The X and Y axes that the plot element is attached to.
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - label: Text label for the plot element.
        - next_sibling: Child of the parent rendered just after this item.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Controls whether the plot element is visible.
        - theme: Visual theme applied to the plot element.
        - user_data: User data of any type.
        """
        ...


    @property
    def axes(self) -> tuple:
        """
        The X and Y axes that the plot element is attached to.

        Returns a tuple of (X axis, Y axis) identifiers that determine which
        coordinate system this element will use. Each plot can have up to three
        X axes and three Y axes, allowing for multiple scales on the same plot.
        Default is (X1, Y1).

        """
        ...


    @axes.setter
    def axes(self, value : tuple):
        ...


    @property
    def label(self) -> str:
        """
        Text label for the plot element.

        This label is used in the plot legend and for tooltip identification.
        Setting a meaningful label helps users understand what each element
        represents in a multi-element plot.

        """
        ...


    @label.setter
    def label(self, value : str):
        ...


    @property
    def show(self) -> bool:
        """
        Controls whether the plot element is visible.

        When set to False, the element is not rendered and its callbacks are not
        executed. This allows for temporarily hiding plot elements without
        removing them from the plot hierarchy.

        """
        ...


    @show.setter
    def show(self, value : bool):
        ...


    @property
    def theme(self):
        """
        Visual theme applied to the plot element.

        The theme controls the appearance of the plot element, including line
        colors, point styles, fill patterns, and other visual attributes. A theme
        can be shared between multiple plot elements for consistent styling.

        """
        ...


    @theme.setter
    def theme(self, value):
        ...


class plotElementWithLegend(plotElement):
    """
    Base class for plot children with a legend entry.

    Plot elements derived from this class appear in the plot legend and can
    have their own popup menu when their legend entry is right-clicked. This
    popup can contain additional widgets as children of the element.

    The legend entry can be hovered, clicked, or toggled to show/hide the
    element. Custom handlers can be attached to respond to these interactions.

    """
    def __init__(self, context : Context, attach : Any = ..., axes : tuple = (0, 3), before : Any = ..., children : Sequence[uiItemSubCls] = [], enabled : bool = True, font : Font = None, ignore_fit : bool = False, label : str = "", legend_button : MouseButton = 1, legend_handlers : list = [], next_sibling : baseItemSubCls | None = None, no_legend : bool = False, parent : PlotSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, theme : Any = ..., user_data : Any = ...):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - axes: The X and Y axes that the plot element is attached to.
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether this element is currently visible in the plot.
        - font: Font used for rendering this element's text.
        - ignore_fit: Whether to exclude this element when auto-fitting axes.
        - label: Text label for the plot element.
        - legend_button: Mouse button that opens this element's legend popup.
        - legend_handlers: Event handlers attached to this element's legend entry.
        - next_sibling: Child of the parent rendered just after this item.
        - no_legend: Whether to hide this element from the plot legend.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Controls whether the plot element is visible.
        - theme: Visual theme applied to the plot element.
        - user_data: User data of any type.
        """
        ...


    @property
    def enabled(self) -> bool:
        """
        Whether this element is currently visible in the plot.

        Controls the visibility of this element while keeping its entry in the
        legend. When False, the element isn't drawn but can still be toggled
        through the legend. This is different from the show property which
        completely hides both the element and its legend entry.

        """
        ...


    @enabled.setter
    def enabled(self, value : bool):
        ...


    @property
    def font(self) -> Font:
        """
        Font used for rendering this element's text.

        Determines the font applied to any text rendered as part of this
        element and its child elements. If None, the parent plot's font
        is used instead.

        """
        ...


    @font.setter
    def font(self, value : Font):
        ...


    @property
    def ignore_fit(self) -> bool:
        """
        Whether to exclude this element when auto-fitting axes.

        When True, this element's data range will be ignored when automatically
        determining the plot's axis limits. This is useful for reference lines
        or annotations that shouldn't affect the data view.

        """
        ...


    @ignore_fit.setter
    def ignore_fit(self, value : bool):
        ...


    @property
    def legend_button(self) -> MouseButton:
        """
        Mouse button that opens this element's legend popup.

        Specifies which mouse button activates the popup menu when clicked on
        this element's legend entry. Default is the right mouse button.

        """
        ...


    @legend_button.setter
    def legend_button(self, value : MouseButton):
        ...


    @property
    def legend_handlers(self) -> list:
        """
        Event handlers attached to this element's legend entry.

        These handlers respond to interactions with this element's legend
        entry, such as when it's hovered or clicked. They don't respond to
        interactions with the plotted element itself.

        """
        ...


    @legend_handlers.setter
    def legend_handlers(self, value : list):
        ...


    @property
    def legend_hovered(self) -> bool:
        """
        (Read-only) Whether the legend entry for this element is currently hovered.

        Indicates if the mouse cursor is currently over this element's entry
        in the plot legend. Useful for implementing hover effects or tooltips
        specific to the legend entry.

        """
        ...


    @property
    def no_legend(self) -> bool:
        """
        Whether to hide this element from the plot legend.

        When True, this element will not appear in the legend, though the
        element itself will still be plotted. This is useful for auxiliary
        elements that don't need their own legend entry.

        """
        ...


    @no_legend.setter
    def no_legend(self, value : bool):
        ...


class plotElementX(plotElementWithLegend):
    def __init__(self, context : Context, X : Array = ..., attach : Any = ..., axes : tuple = (0, 3), before : Any = ..., children : Sequence[uiItemSubCls] = [], enabled : bool = True, font : Font = None, ignore_fit : bool = False, label : str = "", legend_button : MouseButton = 1, legend_handlers : list = [], next_sibling : baseItemSubCls | None = None, no_legend : bool = False, parent : PlotSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, theme : Any = ..., user_data : Any = ...):
        """
        Parameters
        ----------
        - X: Values on the X axis.
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - axes: The X and Y axes that the plot element is attached to.
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether this element is currently visible in the plot.
        - font: Font used for rendering this element's text.
        - ignore_fit: Whether to exclude this element when auto-fitting axes.
        - label: Text label for the plot element.
        - legend_button: Mouse button that opens this element's legend popup.
        - legend_handlers: Event handlers attached to this element's legend entry.
        - next_sibling: Child of the parent rendered just after this item.
        - no_legend: Whether to hide this element from the plot legend.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Controls whether the plot element is visible.
        - theme: Visual theme applied to the plot element.
        - user_data: User data of any type.
        """
        ...


    @property
    def X(self) -> Array:
        """
        Values on the X axis.

        Accepts numpy arrays or buffer compatible objects.
        Supported types for no copy are int32, float32, float64,
        else a float64 copy is used.

        """
        ...


    @X.setter
    def X(self, value : Array):
        ...


class plotElementXY(plotElementWithLegend):
    def __init__(self, context : Context, X : Array = ..., Y : Array = ..., attach : Any = ..., axes : tuple = (0, 3), before : Any = ..., children : Sequence[uiItemSubCls] = [], enabled : bool = True, font : Font = None, ignore_fit : bool = False, label : str = "", legend_button : MouseButton = 1, legend_handlers : list = [], next_sibling : baseItemSubCls | None = None, no_legend : bool = False, parent : PlotSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, theme : Any = ..., user_data : Any = ...):
        """
        Parameters
        ----------
        - X: Values on the X axis.
        - Y: Values on the Y axis
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - axes: The X and Y axes that the plot element is attached to.
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether this element is currently visible in the plot.
        - font: Font used for rendering this element's text.
        - ignore_fit: Whether to exclude this element when auto-fitting axes.
        - label: Text label for the plot element.
        - legend_button: Mouse button that opens this element's legend popup.
        - legend_handlers: Event handlers attached to this element's legend entry.
        - next_sibling: Child of the parent rendered just after this item.
        - no_legend: Whether to hide this element from the plot legend.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Controls whether the plot element is visible.
        - theme: Visual theme applied to the plot element.
        - user_data: User data of any type.
        """
        ...


    @property
    def X(self) -> Array:
        """
        Values on the X axis.

        Accepts numpy arrays or buffer compatible objects.
        Supported types for no copy are int32, float32, float64,
        else a float64 copy is used.

        """
        ...


    @X.setter
    def X(self, value : Array):
        ...


    @property
    def Y(self) -> Array:
        """
        Values on the Y axis

        Accepts numpy arrays or buffer compatible objects.
        Supported types for no copy are int32, float32, float64,
        else a float64 copy is used.

        """
        ...


    @Y.setter
    def Y(self, value : Array):
        ...


class plotElementXYY(plotElementWithLegend):
    def __init__(self, context : Context, X : Array = ..., Y1 : Array = ..., Y2 : Array = ..., attach : Any = ..., axes : tuple = (0, 3), before : Any = ..., children : Sequence[uiItemSubCls] = [], enabled : bool = True, font : Font = None, ignore_fit : bool = False, label : str = "", legend_button : MouseButton = 1, legend_handlers : list = [], next_sibling : baseItemSubCls | None = None, no_legend : bool = False, parent : PlotSubCls | None = None, previous_sibling : baseItemSubCls | None = None, show : bool = True, theme : Any = ..., user_data : Any = ...):
        """
        Parameters
        ----------
        - X: Values on the X axis.
        - Y1: Values on the Y1 axis.
        - Y2: Values on the Y2 axis.
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - axes: The X and Y axes that the plot element is attached to.
        - before: Attach the item just before the target item. Default is None (disabled)
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether this element is currently visible in the plot.
        - font: Font used for rendering this element's text.
        - ignore_fit: Whether to exclude this element when auto-fitting axes.
        - label: Text label for the plot element.
        - legend_button: Mouse button that opens this element's legend popup.
        - legend_handlers: Event handlers attached to this element's legend entry.
        - next_sibling: Child of the parent rendered just after this item.
        - no_legend: Whether to hide this element from the plot legend.
        - parent: Parent of the item in the rendering tree.
        - previous_sibling: Child of the parent rendered just before this item.
        - show: Controls whether the plot element is visible.
        - theme: Visual theme applied to the plot element.
        - user_data: User data of any type.
        """
        ...


    @property
    def X(self) -> Array:
        """
        Values on the X axis.

        Accepts numpy arrays or buffer compatible objects.
        Supported types for no copy are int32, float32, float64,
        else a float64 copy is used.

        """
        ...


    @X.setter
    def X(self, value : Array):
        ...


    @property
    def Y1(self) -> Array:
        """
        Values on the Y1 axis.

        Accepts numpy arrays or buffer compatible objects.
        Supported types for no copy are int32, float32, float64,
        else a float64 copy is used.

        """
        ...


    @Y1.setter
    def Y1(self, value : Array):
        ...


    @property
    def Y2(self) -> Array:
        """
        Values on the Y2 axis.

        Accepts numpy arrays or buffer compatible objects.
        Supported types for no copy are int32, float32, float64,
        else a float64 copy is used.

        """
        ...


    @Y2.setter
    def Y2(self, value : Array):
        ...


class uiItem(baseItem):
    """
    Base class for UI items with various properties and states.

    Core class for items that can be interacted with and displayed in the UI. Handles positioning,
    state tracking, themes, callbacks, and layout management.

    State Properties:
    ---------------
        - active: Whether the item is currently active (pressed, selected, etc.)
        - activated: Whether the item just became active this frame
        - clicked: Whether any mouse button was clicked on the item
        - double_clicked: Whether any mouse button was double-clicked
        - deactivated: Whether the item just became inactive
        - deactivated_after_edited: Whether the item was edited and then deactivated
        - edited: Whether the item's value was modified
        - focused: Whether the item has keyboard focus
        - hovered: Whether the mouse is over the item
        - resized: Whether the item's size changed
        - toggled: Whether a menu/tree node was opened/closed
        - visible: Whether the item is currently rendered

    Appearance Properties:
    -------------------
        - enabled: Whether the item is interactive or greyed out
        - font: Font used for text rendering
        - theme: Visual theme/style settings
        - show: Whether the item should be drawn
        - no_scaling: Disable DPI/viewport scaling

    Layout Properties:
    ----------------
        - pos_to_viewport: Position relative to viewport top-left
        - pos_to_window: Position relative to containing window
        - pos_to_parent: Position relative to parent item
        - pos_to_default: Position relative to default layout flow
        - rect_size: Current size in pixels including padding
        - content_region_avail: Available content area within item for children
        - pos_policy: How the item should be positioned
        - height/width: Requested size of the item
        - indent: Left indentation amount
        - no_newline: Don't advance position after item

    Value Properties:
    ---------------
        - value: Main value stored by the item
        - shareable_value: Allows sharing values between items
        - label: Text label shown with the item

    Event Properties:
    ---------------
        - handlers: Event handlers attached to the item
        - callbacks: Functions called when value changes

    Positioning Rules:
    ----------------
    Items use a combination of absolute and relative positioning:
        - Default flow places items vertically with automatic width
        - pos_policy controls how position attributes are enforced
        - Positions can be relative to viewport, window, parent or flow
        - Size can be fixed, automatic, or stretch to fill space
        - indent and no_newline provide fine-grained layout control

    All attributes are protected by mutexes to enable thread-safe access.

    """
    def __init__(self, context : Context, attach : Any = ..., before : Any = ..., callback : DCGCallable | None = None, callback : DCGCallable | None = None, callbacks : Sequence[DCGCallable] = [], children : None  = [], enabled : bool = True, font : Font = None, handlers : list = [], height : float = 0.0, indent : float = 0.0, label : str = "", next_sibling : baseItemSubCls | None = None, no_newline : bool = False, no_scaling : bool = False, parent : uiItemSubCls | plotElementSubCls | None = None, pos_policy : tuple[Positioning, Positioning] = ..., pos_to_default : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_parent : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_viewport : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), pos_to_window : Sequence[float] | tuple[float, float] | Coord = (0.0, 0.0), previous_sibling : baseItemSubCls | None = None, scaling_factor : float = 1.0, shareable_value : SharedValue = ..., show : bool = True, theme : Any = ..., user_data : Any = ..., value : Any = ..., width : float = 0.0):
        """
        Parameters
        ----------
        - attach: Whether to attach the item to a parent. Default is None (auto)
        - before: Attach the item just before the target item. Default is None (disabled)
        - callback: List of callbacks to invoke when the item's value changes.
        - callback: List of callbacks to invoke when the item's value changes.
        - callbacks: List of callbacks to invoke when the item's value changes.
        - children: List of all the children of the item, from first rendered, to last rendered.
        - enabled: Whether the item is interactive and fully styled.
        - font: Font used for rendering text in this item and its children.
        - handlers: List of event handlers attached to this item.
        - height: Requested height for the item.
        - indent: Horizontal indentation applied to the item.
        - label: Text label displayed with or within the item.
        - next_sibling: Child of the parent rendered just after this item.
        - no_newline: Controls whether to advance to the next line after rendering.
        - no_scaling: Whether DPI scaling should be disabled for this item.
        - parent: Parent of the item in the rendering tree.
        - pos_policy: Positioning strategy for placing the item in the layout.
        - pos_to_default: Offset from the item's default layout position.
        - pos_to_parent: Position relative to the parent item's content area.
        - pos_to_viewport: Position relative to the viewport's top-left corner.
        - pos_to_window: Position relative to the containing window's content area.
        - previous_sibling: Child of the parent rendered just before this item.
        - scaling_factor: Additional scaling multiplier applied to this item and its children.
        - shareable_value: Reference to the underlying value that can be shared between items.
        - show: Whether the item should be rendered and process events.
        - theme: Visual styling applied to this item and its children.
        - user_data: User data of any type.
        - value: Main value associated with this item.
        - width: Requested width for the item.
        """
        ...


    @property
    def callback(self) -> DCGCallable | None:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callback.setter
    def callback(self, value : DCGCallable | None):
        ...


    @property
    def callbacks(self) -> Sequence[DCGCallable]:
        """
        List of callbacks to invoke when the item's value changes.

        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.

        """
        ...


    @callbacks.setter
    def callbacks(self, value : Sequence[DCGCallable]):
        ...


    @property
    def enabled(self) -> bool:
        """
        Whether the item is interactive and fully styled.

        When disabled, items appear grayed out and do not respond to user
        interaction like hovering, clicking, or keyboard input. Unlike hidden
        items (show=False), disabled items still appear in the interface but
        with visual cues indicating their non-interactive state.

        """
        ...


    @enabled.setter
    def enabled(self, value : bool):
        ...


    @property
    def font(self) -> Font:
        """
        Font used for rendering text in this item and its children.

        Specifies a font to use when rendering text within this item's hierarchy.
        When set, this overrides any font specified by parent items. Setting to
        None uses the parent's font or the default font if no parent specifies one.

        """
        ...


    @font.setter
    def font(self, value : Font):
        ...


    @property
    def handlers(self) -> list:
        """
        List of event handlers attached to this item.

        Handlers are objects that monitor the item's state and trigger callbacks
        when specific conditions are met, like when an item is clicked, hovered,
        or has its value changed. Multiple handlers can be attached to respond to
        different events or the same event in different ways.

        """
        ...


    @handlers.setter
    def handlers(self, value : list):
        ...


    @property
    def height(self) -> float:
        """
        Requested height for the item.

        This property specifies the desired height for the item, though the
        actual height may differ depending on item type and constraints.

        Special values:
            - 0: Use default height. May trigger content-fitting for windows or
                containers, or style-based sizing for other items.
            - Positive values: Request a specific height in scaled pixels.
            - Negative values: Request a height that fills the remaining parent space
                minus the absolute value (e.g., -1 means "fill minus 1 scaled pixel").
            - string: A string specification to automatically size the item. See the
                documentation for details on how to use this feature.

        Some items may ignore this property or interpret it differently. The
        actual final height in real pixels is available via the rect_size property.

        """
        ...


    @height.setter
    def height(self, value : float):
        ...


    @property
    def indent(self) -> float:
        """
        Horizontal indentation applied to the item.

        This property shifts the default horizontal position of the item by the
        specified number of scaled pixels, creating an indented appearance.

        A negative value indicates an indentation of the default size based on
        the current style settings, typically equivalent to the standard tab
        size. A value of 0 means no indentation is applied.

        """
        ...


    @indent.setter
    def indent(self, value : float):
        ...


    @property
    def label(self) -> str:
        """
        Text label displayed with or within the item.

        The label is displayed differently depending on the item type. For buttons
        and selectable items it appears inside them, for windows it becomes the
        title, and for sliders and input fields it appears next to them.

        """
        ...


    @label.setter
    def label(self, value : str):
        ...


    @property
    def no_newline(self) -> bool:
        """
        Controls whether to advance to the next line after rendering.

        When True, the cursor position (DEFAULT positioning) does not advance
        to the next line after this item is drawn, allowing the next item to
        appear on the same line. When False, the cursor advances as normal,
        placing the next item on a new line.

        This property is commonly used to create horizontal layouts or to place
        multiple items side-by-side.

        """
        ...


    @no_newline.setter
    def no_newline(self, value : bool):
        ...


    @property
    def no_scaling(self) -> bool:
        """
        Whether DPI scaling should be disabled for this item.

        When True, the item ignores the global scaling factor that normally
        adjusts UI elements based on screen DPI and viewport settings. This can
        be useful for elements that should maintain specific pixel dimensions
        regardless of display resolution or scaling settings.

        """
        ...


    @no_scaling.setter
    def no_scaling(self, value : bool):
        ...


    @property
    def pos_policy(self) -> tuple[Positioning, Positioning]:
        """
        Positioning strategy for placing the item in the layout.

        This property controls how the item's position is determined:
            - DEFAULT: Placed at ImGui's cursor position, which advances vertically
            after each item is rendered.
            - REL_DEFAULT: Placed at the default position plus an offset specified
            by pos_to_default.
            - REL_PARENT: Positioned at coordinates specified by pos_to_parent
            relative to the parent's content area.
            - REL_WINDOW: Positioned at coordinates specified by pos_to_window
            relative to the containing window's content area.
            - REL_VIEWPORT: Positioned at absolute viewport coordinates specified
            by pos_to_viewport.

        Items using DEFAULT or REL_DEFAULT advance the layout cursor, while other
        policies do not. Each axis (horizontal and vertical) has its own policy.

        All position fields are updated when the item is rendered, but only the
        position corresponding to the active policy is guaranteed to remain stable.

        """
        ...


    @pos_policy.setter
    def pos_policy(self, value : tuple[Positioning, Positioning]):
        ...


    @property
    def pos_to_default(self) -> Coord:
        """
        Offset from the item's default layout position.

        This coordinate represents an offset from the position where the item
        would naturally appear in the layout flow. Setting this property
        automatically switches the positioning mode to REL_DEFAULT for the
        affected axis.

        This provides a way to fine-tune positioning while still mostly
        respecting the normal layout flow.

        When setting this property, you can use None for either component to
        leave that coordinate unchanged.

        """
        ...


    @pos_to_default.setter
    def pos_to_default(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def pos_to_parent(self) -> Coord:
        """
        Position relative to the parent item's content area.

        This coordinate represents the position of the item's top-left corner
        relative to its parent's content area. Setting this property automatically
        switches the positioning mode to REL_PARENT for the affected axis.

        The position can place the item outside the parent's content region,
        which would make the item invisible.

        When setting this property, you can use None for either component to
        leave that coordinate unchanged.

        """
        ...


    @pos_to_parent.setter
    def pos_to_parent(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def pos_to_viewport(self) -> Coord:
        """
        Position relative to the viewport's top-left corner.

        This coordinate represents the position of the item's top-left corner
        relative to the entire viewport. Setting this property automatically
        switches the positioning mode to REL_VIEWPORT for the affected axis.

        The item remains subject to the parent's clipping region, so positioning
        an item outside its parent's boundaries may make it invisible despite
        having valid coordinates.

        When setting this property, you can use None for either component to
        leave that coordinate unchanged.

        """
        ...


    @pos_to_viewport.setter
    def pos_to_viewport(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def pos_to_window(self) -> Coord:
        """
        Position relative to the containing window's content area.

        This coordinate represents the position of the item's top-left corner
        relative to the inner content area of the containing window. Setting
        this property automatically switches the positioning mode to REL_WINDOW
        for the affected axis.

        The position can place the item outside the parent's content region,
        which would make the item invisible.

        When setting this property, you can use None for either component to
        leave that coordinate unchanged.

        """
        ...


    @pos_to_window.setter
    def pos_to_window(self, value : Sequence[float] | tuple[float, float] | Coord):
        ...


    @property
    def rect_size(self) -> Coord:
        """
        (Read-only) Actual pixel size of the element including margins.

        This property represents the width and height of the rectangle occupied
        by the item in the layout. The rectangle's top-left corner is at the
        position given by the relevant position property.

        Note that this size refers only to the item within its parent window and
        does not include any popup or child windows that might be spawned by
        this item.

        """
        ...


    @property
    def resized(self) -> bool:
        """
        (Read-only) Whether the item's size changed this frame.

        This property is true only for the frame when the size change occurs.
        It can detect both user-initiated resizing (like dragging a window edge)
        and programmatic size changes.

        """
        ...


    @property
    def scaling_factor(self) -> float:
        """
        Additional scaling multiplier applied to this item and its children.

        This factor multiplies the global scaling to adjust the size of this
        item hierarchy. It affects sizes, themes, and fonts that are applied
        directly to this item or its children, but not those inherited from
        parent items. Default is 1.0 (no additional scaling).

        """
        ...


    @scaling_factor.setter
    def scaling_factor(self, value : float):
        ...


    @property
    def shareable_value(self) -> SharedValue:
        """
        Reference to the underlying value that can be shared between items.

        Unlike the value property which returns a copy, this returns a reference
        to the underlying SharedValue object. This object can be assigned to other
        items' shareable_value properties, creating a link where all items share
        and update the same underlying value.

        """
        ...


    @shareable_value.setter
    def shareable_value(self, value : SharedValue):
        ...


    @property
    def show(self) -> bool:
        """
        Whether the item should be rendered and process events.

        When set to False, the item and all its children are skipped during
        rendering, effectively hiding them and disabling all their functionality
        including callbacks and event handling. This is different from the enabled
        property which renders items but in a non-interactive state.

        """
        ...


    @show.setter
    def show(self, value : bool):
        ...


    @property
    def theme(self):
        """
        Visual styling applied to this item and its children.

        Themes control the appearance of items including colors, spacing, and
        other visual attributes. When set, this theme overrides any theme specified
        by parent items. Setting to None uses the parent's theme or the default
        theme if no parent specifies one.

        """
        ...


    @theme.setter
    def theme(self, value):
        ...


    @property
    def value(self):
        """
        Main value associated with this item.

        The meaning of this value depends on the item type: for buttons it's
        whether pressed, for text inputs it's the text content, for selectable
        items it's whether selected, and so on. This property provides a
        unified interface for accessing an item's core data.

        """
        ...


    @value.setter
    def value(self, value):
        ...


    @property
    def visible(self) -> bool:
        """
        (Read-only) Whether the item was rendered in the current frame.

        An item is visible when it and all its ancestors have show=True and are
        within the visible region of their containers. Invisible items skip
        rendering and event handling entirely.

        """
        ...


    @property
    def width(self) -> float:
        """
        Requested width for the item.

        This property specifies the desired width for the item, though the
        actual width may differ depending on item type and constraints.

        Special values:
            - 0: Use default width. May trigger content-fitting for windows or
                containers, or style-based sizing for other items.
            - Positive values: Request a specific width in scaled pixels.
            - Negative values: Request a width that fills the remaining parent space
                minus the absolute value (e.g., -1 means "fill minus 1 scaled pixel").
            - string: A string specification to automatically size the item. See the
                documentation for details on how to use this feature.

        Some items may ignore this property or interpret it differently. The
        actual final width in real pixels is available via the rect_size property.

        """
        ...


    @width.setter
    def width(self, value : float):
        ...

