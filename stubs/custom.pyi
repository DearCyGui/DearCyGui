from typing import TypeAlias, Any
from enum import IntEnum
from collections.abc import Sequence
from typing import Protocol, Self, TypeVar, Iterator
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

