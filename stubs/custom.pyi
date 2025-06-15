from typing import TypeAlias, Any
from enum import IntEnum
from collections.abc import Sequence
from typing import Protocol, Self, TypeVar, Iterator, Callable
from .types import *
from .core import *
from .sizing import baseSizing

SenderT = TypeVar('Sender', bound='baseItem')
TargetT = TypeVar('Target', bound='baseItem')

class DCGCallable0(Protocol):
    def __call__(self, /) -> Any:
        ...

class DCGCallable1(Protocol[SenderT]):
    def __call__(self,
                 sender : SenderT,
                 /) -> Any:
        ...

class DCGCallable2(Protocol[SenderT, TargetT]):
    def __call__(self,
                 sender : SenderT,
                 target : TargetT,
                 /) -> Any:
        ...

class DCGCallable3(Protocol[SenderT, TargetT]):
    def __call__(self,
                 sender : SenderT,
                 target : TargetT,
                 value : Any,
                 /) -> Any:
        ...

class DCGCallable0Kw(Protocol):    
    def __call__(self, /, **kwargs) -> Any:
        ...

class DCGCallable1Kw(Protocol[SenderT]):
    def __call__(self,
                 sender : SenderT,
                 /,
                 **kwargs : Any) -> Any:
        ...

class DCGCallable2Kw(Protocol[SenderT, TargetT]):
    def __call__(self,
                 sender : SenderT,
                 target : TargetT,
                 /,
                 **kwargs : Any) -> Any:
        ...

class DCGCallable3Kw(Protocol[SenderT, TargetT]):
    def __call__(self,
                 sender : SenderT,
                 target : TargetT,
                 value : Any,
                 /,  
                 **kwargs : Any) -> Any:
        ...


DCGCallable = DCGCallable0 | DCGCallable1 | DCGCallable2 | DCGCallable3 | DCGCallable0Kw | DCGCallable1Kw | DCGCallable2Kw | DCGCallable3Kw


class Callback(DCGCallable3[SenderT, TargetT]):
    """
    Wrapper class that automatically encapsulates callbacks.

    Callbacks in DCG mode can take up to 3 arguments:
        - source_item: the item to which the callback was attached
        - target_item: the item for which the callback was raised.
            Is only different to source_item for handlers' callback.
        - call_info: If applicable information about the call (key button, etc)

    This class adapts callbacks with fewer parameters to the full 3-parameter form.
    """
    def __init__(self, callback: DCGCallable) -> None:
        ...
    
    def __call__(self, sender: SenderT, target: TargetT, value: Any) -> Any:
        """
        Call the wrapped callback with appropriate number of arguments.
        
        Automatically adapts between callbacks that accept 0, 1, 2, or 3 arguments.
        """
        ...

    @property
    def callback(self) -> DCGCallable:
        """(Read-only) The original wrapped callback
        """
        ...


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
    Array: TypeAlias = memoryview | bytearray | bytes | Sequence[Any] | "np.ndarray[Any, Any]"

