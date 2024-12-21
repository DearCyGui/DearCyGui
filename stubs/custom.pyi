from typing import Any
from enum import IntEnum
from typing import Protocol, Sequence
from .types import *

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
