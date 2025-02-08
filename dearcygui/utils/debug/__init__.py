import sys
import inspect
from typing import Any, Callable
from functools import wraps
from dearcygui.core import baseItem as _baseItem
from ._impl import (
    DebugContext, 
    create_debug_class, 
    create_debug_wrapper,
    set_debug_verbosity
)

# Get all item classes from dearcygui module
this_module = sys.modules[__name__]
parent_module = sys.modules['dearcygui']

# Copy all attributes from parent, wrapping item classes and methods
for name in dir(parent_module):
    if name.startswith('_'):
        continue
        
    obj = getattr(parent_module, name)
    if isinstance(obj, type) and issubclass(obj, _baseItem):
        # Create debug version of item classes directly
        try:
            setattr(this_module, name, create_debug_class(obj))
        except TypeError:
            # Some items cannot be subclassed
            setattr(this_module, name, obj)
    elif callable(obj) and inspect.isfunction(obj):
        # Wrap standalone functions
        setattr(this_module, name, create_debug_wrapper(obj))
    else:
        # Keep other objects as-is
        setattr(this_module, name, obj)

# Override Context to return DebugContext by default
setattr(this_module, 'Context', DebugContext)

# Define what symbols to export
__all__ = ['DebugContext', 'create_debug_class', 'create_debug_wrapper', 'set_debug_verbosity']
