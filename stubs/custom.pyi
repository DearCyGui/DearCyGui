from typing import Coroutine, TypeAlias, Any, Literal
from enum import IntEnum
from collections.abc import Sequence, Iterator, Callable
from math import inf
from typing import Protocol, Self, Never, Concatenate
from contextlib import AbstractContextManager
from .core import *

# Callback parameters are contravariant (inferred): a callback accepting a parent
# class (or a union containing the exact class) of the sender/value is valid.
# Sender is the item the callback is attached to, value is the callback value
# class matching that item.

class DCGCallable0(Protocol):
    def __call__(self, /) -> Any:
        ...

class DCGCallable1[S: baseItem = baseItem](Protocol):
    def __call__(self,
                 sender : S,
                 /) -> Any:
        ...

class DCGCallable2[S: baseItem = baseItem, T: baseItem = baseItem](Protocol):
    def __call__(self,
                 sender : S,
                 target : T,
                 /) -> Any:
        ...

class DCGCallable3[S: baseItem = baseItem,
                   T: baseItem = baseItem,
                   V: baseCallbackValue = baseCallbackValue](Protocol):
    def __call__(self,
                 sender : S,
                 target : T,
                 value : V,
                 /) -> Any:
        ...

class DCGCallable0Kw(Protocol):
    def __call__(self, /, **kwargs: Any) -> Any:
        ...

class DCGCallable1Kw[S: baseItem = baseItem](Protocol):
    def __call__(self,
                 sender : S,
                 /,
                 **kwargs : Any) -> Any:
        ...

class DCGCallable2Kw[S: baseItem = baseItem, T: baseItem = baseItem](Protocol):
    def __call__(self,
                 sender : S,
                 target : T,
                 /,
                 **kwargs : Any) -> Any:
        ...

class DCGCallable3Kw[S: baseItem = baseItem,
                     T: baseItem = baseItem,
                     V: baseCallbackValue = baseCallbackValue](Protocol):
    def __call__(self,
                 sender : S,
                 target : T,
                 value : V,
                 /,
                 **kwargs : Any) -> Any:
        ...


type DCGCallable[S: baseItem = baseItem,
                 T: baseItem = baseItem,
                 V: baseCallbackValue = baseCallbackValue] = (
    DCGCallable0 | DCGCallable1[S] | DCGCallable2[S, T] | DCGCallable3[S, T, V]
    | DCGCallable0Kw | DCGCallable1Kw[S] | DCGCallable2Kw[S, T] | DCGCallable3Kw[S, T, V]
)


class Callback[S: baseItem = baseItem, T: baseItem = baseItem,
               V: baseCallbackValue = baseCallbackValue](DCGCallable3[S, T, V]):
    """
    Wrapper class that automatically encapsulates callbacks.

    Callbacks in DCG mode can take up to 3 arguments:
        - source_item: the item to which the callback was attached
        - target_item: the item for which the callback was raised.
            Is only different to source_item for handlers' callback.
        - call_info: If applicable information about the call (key button, etc)

    This class adapts callbacks with fewer parameters to the full 3-parameter form.
    """
    def __init__(self, callback: DCGCallable[S, T, V]) -> None:
        ...
    
    def __call__(self, sender: S, target: T, value: V) -> Any:
        """
        Call the wrapped callback with appropriate number of arguments.
        
        Automatically adapts between callbacks that accept 0, 1, 2, or 3 arguments.
        """
        ...

    @property
    def callback(self) -> DCGCallable[S, T, V]:
        """(Read-only) The original wrapped callback
        """
        ...


class TaskSubmitter(Protocol):
    def submit(self, fn: Callable[..., Any], /, *args: Any, **kwargs: Any) -> Any:
        ...

class AnyTaskSubmitter(Protocol):
    def submit(self, fn: Callable[..., Any] | Coroutine, /, *args: Any, **kwargs: Any) -> Any:
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

try:
    from collections.abc import Buffer
    Array: TypeAlias = memoryview | bytearray | bytes | Sequence[Any] | Buffer
except ImportError:
    Array: TypeAlias = memoryview | bytearray | bytes | Sequence[Any] | "np.ndarray[Any, Any]"

