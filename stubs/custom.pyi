from typing import TypeAlias, Any
from enum import IntEnum
from collections.abc import Sequence
from typing import Protocol, TypeVar
from .types import *
from .core import *
from .sizing import baseSizing

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

class ItemStateView:
    """
    View class for accessing UI item state properties.
    
    This class provides a consolidated interface to access state properties
    of UI items, such as whether they are hovered, active, focused, etc.
    Each property is checked against the item's capabilities to ensure
    it supports that state.
    
    The view references the original item and uses its mutex for thread safety.
    """
    
    @property
    def active(self) -> bool:
        """
        Whether the item is in an active state.
        
        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.
        """
        ...
    
    @property
    def activated(self) -> bool:
        """
        Whether the item just transitioned to the active state this frame.
        
        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use 
        event handlers instead as they provide more robust state tracking.
        """
        ...
    
    @property
    def clicked(self) -> tuple[bool, bool, bool, bool, bool]:
        """
        Whether any mouse button was clicked on this item this frame.
        
        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.
        """
        ...
    
    @property
    def double_clicked(self) -> tuple[bool, bool, bool, bool, bool]:
        """
        Whether any mouse button was double-clicked on this item this frame.
        
        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.
        """
        ...
    
    @property
    def deactivated(self) -> bool:
        """
        Whether the item just transitioned from active to inactive this frame.
        
        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.
        """
        ...
    
    @property
    def deactivated_after_edited(self) -> bool:
        """
        Whether the item was edited and then deactivated in this frame.
        
        Useful for detecting when user completes an edit operation, such as
        finishing text input or adjusting a value. This property is only true
        for the frame when the deactivation occurs after editing.
        """
        ...
    
    @property
    def edited(self) -> bool:
        """
        Whether the item's value was modified this frame.
        
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
    
    @property
    def hovered(self) -> bool:
        """
        Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.
        """
        ...
    
    @property
    def resized(self) -> bool:
        """
        Whether the item's size changed this frame.
        
        This property is true only for the frame when the size change occurs.
        It can detect both user-initiated resizing (like dragging a window edge)
        and programmatic size changes.
        """
        ...
    
    @property
    def toggled(self) -> bool:
        """
        Whether the item was just toggled open this frame.
        
        Applies to items that can be expanded or collapsed, such as tree nodes,
        collapsing headers, or menus. This property is only true during the frame
        when the toggle from closed to open occurs.
        """
        ...
    
    @property
    def visible(self) -> bool:
        """
        Whether the item was rendered in the current frame.
        
        An item is visible when it and all its ancestors have show=True and are
        within the visible region of their containers. Invisible items skip
        rendering and event handling entirely.
        """
        ...
    
    @property
    def rect_size(self) -> Coord:
        """
        Actual pixel size of the element including margins.
        
        This property represents the width and height of the rectangle occupied
        by the item in the layout. The rectangle's top-left corner is at the
        position given by the relevant position property.
        
        Note that this size refers only to the item within its parent window and
        does not include any popup or child windows that might be spawned by
        this item.
        """
        ...
    
    @property
    def pos_to_viewport(self) -> Coord:
        """
        Position relative to the viewport's top-left corner.
        """
        ...
    
    @property
    def pos_to_window(self) -> Coord:
        """
        Position relative to the containing window's content area.
        """
        ...
    
    @property
    def pos_to_parent(self) -> Coord:
        """
        Position relative to the parent item's content area.
        """
        ...
    
    @property
    def pos_to_default(self) -> Coord:
        """
        Offset from the item's default layout position.
        """
        ...
    
    @property
    def content_region_avail(self) -> Coord:
        """
        Available space for child items.
        
        For container items like windows, child windows, this
        property represents the available space for placing child items. This is
        the item's inner area after accounting for padding, borders, and other
        non-content elements.
        
        Areas that require scrolling to see are not included in this measurement.
        """
        ...
    
    @property
    def content_pos(self) -> Coord:
        """
        Position of the content area's top-left corner.
        
        This property provides the viewport-relative coordinates of the starting
        point for an item's content area. This is where child elements begin to be
        placed by default.
        
        Used together with content_region_avail, this defines the rectangle
        available for child elements.
        """
        ...
    
    @property
    def item(self):
        """
        item from which the states are extracted.
        """
        ...