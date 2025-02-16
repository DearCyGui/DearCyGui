import time
import threading
from concurrent.futures import ThreadPoolExecutor
from typing import Any, Callable
from contextlib import contextmanager
from dearcygui import Context, Callback
from functools import wraps
import inspect
from difflib import get_close_matches

# Global verbosity setting - default to warnings only
_VERBOSITY = 1

def set_debug_verbosity(level: int):
    """Set the global debug verbosity level
    
    Args:
        level: Debug verbosity level (0-4)
            0 - No debug output
            1 - Warnings for possible mistakes
            2 - Detailed callback info and descriptor access
            3 - Full item state changes
            4 - Exhaustive configuration details
    """
    global _VERBOSITY
    if not 0 <= level <= 4:
        raise ValueError("Verbosity level must be between 0 and 4")
    _VERBOSITY = level

class DebugQueue(ThreadPoolExecutor):
    """ThreadPoolExecutor that logs job execution with timestamps and thread info"""

    def __init__(self, max_workers=1):
        """Initialize debug queue with specified verbosity level
        
        Args:
            max_workers: Max number of worker threads
        """
        super().__init__(max_workers=max_workers)

    def _log(self, level: int, msg: str):
        """Log message if verbosity >= level"""
        if _VERBOSITY >= level:
            thread = threading.current_thread()
            print(f"[{time.time():.6f}] [{thread.name}] {msg}")

    def submit(self, fn: Callback, *args, **kwargs) -> Any:
        """Submit job with debug logging"""
        submit_time = time.time()
        self._log(2, f"Queueing callback {fn.callback}")
        if _VERBOSITY >= 2:
            for i, arg in enumerate(args):
                self._log(2, f"  Arg {i}: {type(arg).__name__} = {arg}")
            for k, v in kwargs.items():
                self._log(2, f"  Kwarg {k}: {type(v).__name__} = {v}")

        # Wrap function to add timing and logging
        @contextmanager
        def _debug_context():
            start_time = time.time()
            queue_delay = (start_time - submit_time) * 1000
            if queue_delay > 10:  # Warning if delay > 10ms
                self._log(1, f"WARNING: Long callback delay ({queue_delay:.2f}ms) for {fn.callback}. "
                            "Possible causes: previous callback too slow, too many callbacks, or GIL contention")
            else:
                self._log(2, f"Starting callback {fn.callback} (queued for {queue_delay:.2f}ms)")
            start = time.perf_counter()
            try:
                yield
            finally:
                duration = (time.perf_counter() - start) * 1000
                if duration > 10:  # Warning if callback takes > 10ms
                    self._log(1, f"WARNING: Slow callback {fn.callback} ({duration:.2f}ms). "
                               "Consider moving heavy work to another thread")
                else:
                    self._log(2, f"Finished callback {fn.callback} in {duration:.2f}ms")

        def _wrapped_fn(*args, **kwargs):
            with _debug_context():
                return fn(*args, **kwargs)

        return super().submit(_wrapped_fn, *args, **kwargs)

class DebugContext(Context):
    def __init__(self, **kwargs):
        """Initialize debug context using global verbosity level"""
        if kwargs.pop("queue", None) is not None:
            raise ValueError("DebugContext does not support custom queues")
        queue=DebugQueue()
        super().__init__(queue=queue,
                         **kwargs)

def _get_attr_type(item, name: str) -> str:
    """Determine the type of an attribute
        
    Returns:
        str: One of 'descriptor', 'property', 'instance', or 'inherited'
    """
    cls = type(item)
        
    # Check class hierarchy for descriptors/properties
    for base in cls.__mro__:
        if name in base.__dict__:
            attr = base.__dict__[name]
            # Check for property first since it's also a descriptor
            if isinstance(attr, property):
                return "property"
            # Check for descriptor protocol
            if hasattr(attr, '__set__') or hasattr(attr, '__get__'):
                return "descriptor"
                
    # Check for slots-based descriptors
    for base in cls.__mro__:
        if hasattr(base, '__slots__') and name in base.__slots__:
            return "descriptor"
                
    # Check instance dict
    if hasattr(item, '__dict__') and name in item.__dict__:
        return "instance"
            
    return "inherited"

def _debug_class_init(cls):
    """Class decorator to dynamically add debug special methods"""
    # Map of special method names to their wrapped versions
    special_methods = {
        '__len__': '_wrapped_len',
        '__iter__': '_wrapped_iter',
        '__contains__': '_wrapped_contains',
        '__getitem__': '_wrapped_getitem',
        '__setitem__': '_wrapped_setitem',
        '__delitem__': '_wrapped_delitem',
        '__enter__': '_wrapped_enter',
        '__exit__': '_wrapped_exit',
        '__init__': '_wrapped_init',
        '__del__': '_wrapped_del'
    }
    
    # Only add special methods that exist in any parent class
    wrapped = set()
    for method_name, wrapped_name in special_methods.items():
        # Check if method exists in any parent class (excluding DebugMixin)
        for base in cls.__mro__[1:]:  # Skip self
            if hasattr(base, method_name):
                assert hasattr(cls, wrapped_name), f"Missing wrapped method {wrapped_name}"
                setattr(cls, method_name, getattr(cls, wrapped_name))
                wrapped.add(method_name)
                break

    # when __init__ and __del__ are missing,
    # we add dummy one, because we want to log them
    if '__init__' not in wrapped:
        setattr(cls, '__init__', getattr(cls, '_dummy_init'))
    if '__del__' not in wrapped:
        setattr(cls, '__del__', getattr(cls, '_dummy_del'))

    return cls

class DebugMixin:
    """Mixin class that adds debug logging to DearCyGui objects"""
    
    _debug_disabled = threading.local()
    
    @contextmanager
    def _disable_debug(self):
        """Temporarily disable debug output"""
        old_state = getattr(self._debug_disabled, 'value', False)
        self._debug_disabled.value = True
        try:
            yield
        finally:
            self._debug_disabled.value = old_state
            
    def _is_debug_disabled(self):
        """Check if debug output is currently disabled"""
        return getattr(self._debug_disabled, 'value', False)
    
    def _log(self, level: int, msg: str):
        """Log message if verbosity >= level and debug is not disabled"""
        if not self._is_debug_disabled() and _VERBOSITY >= level:
            thread = threading.current_thread()
            print(f"[{time.time():.6f}] [{thread.name}] {msg}")

    def __dir__(self):
        # the same as the baseItem one, but somehow
        # redefining avoids an error (only for dynamic
        # subclassing like here. Python bug ?)
        default_dir = dir(type(self).__base__)
        if hasattr(self, '__dict__'): # Can happen with python subclassing
            default_dir += list(self.__dict__.keys())
        # Remove invalid ones
        results = []
        for e in default_dir:
            if hasattr(self, e):
                results.append(e)
        return list(set(results))
     
    def __getstate__(self):
        """Get object state without printing debug logs"""
        with self._disable_debug():
            return super().__getstate__()

    def __getattribute__(self, name: str) -> Any:
        value = super().__getattribute__(name)
        # Skip debug logging for special methods, internal attributes,
        # or when debug is disabled
        if name.startswith('_') or \
           self._is_debug_disabled():
            return value

        # skip uuid
        if name == 'uuid':
            return value
        
        attr_type = _get_attr_type(self, name)
        
        # Log based on attribute type
        cls = type(self)
        self._log({
            "descriptor": 2,
            "property": 3,
            "instance": 3,
            "inherited": 4
        }[attr_type], f"GET {attr_type} {cls.__name__}.{name} = {value}")
            
        return value
        
    def __setattr__(self, name: str, value: Any):
        # Skip debug logging for special methods, internal attributes,
        # or when debug is disabled
        if name.startswith('_'):
            return super().__setattr__(name, value)
            
        if self._is_debug_disabled():
            return super().__setattr__(name, value)

        # Check for possible typos in attribute names
        if not hasattr(self, name):
            # Get all attributes from the base class
            base_attrs = set()
            for base in type(self).__mro__[1:]:  # Skip self
                base_attrs.update(dir(base))
            
            # Check for close matches
            matches = get_close_matches(name, base_attrs, n=3, cutoff=0.7)
            if matches:
                self._log(1, f"WARNING: Setting non-existent attribute '{name}'. "
                            f"Did you mean: {', '.join(matches)}?")
                
        attr_type = _get_attr_type(self, name)
        cls = type(self)
        
        # Move non-warning logs to higher verbosity
        self._log({
            "descriptor": 3,
            "property": 3, 
            "instance": 4,
            "inherited": 4
        }[attr_type], f"SET {attr_type} {cls.__name__}.{name} = {value}")
            
        return super().__setattr__(name, value)

    # Rename special methods to wrapped versions
    def _wrapped_enter(self):
        self._log(4, f"ENTER context {self.__class__.__name__}")
        return super().__enter__()
        
    def _wrapped_exit(self, exc_type, exc_val, exc_tb):
        self._log(4, f"EXIT context {self.__class__.__name__} ({exc_type})")
        return super().__exit__(exc_type, exc_val, exc_tb)

    def _wrapped_len(self):
        self._log(4, f"LEN {self.__class__.__name__}")
        return super().__len__()
        
    def _wrapped_iter(self):
        self._log(4, f"ITER {self.__class__.__name__}")
        return super().__iter__()
        
    def _wrapped_contains(self, item):
        self._log(4, f"CONTAINS {self.__class__.__name__} <- {item}")
        return super().__contains__(item)

    def _wrapped_getitem(self, key):
        self._log(4, f"GETITEM {self.__class__.__name__}[{key}]")
        return super().__getitem__(key)

    def _wrapped_setitem(self, key, value):
        self._log(4, f"SETITEM {self.__class__.__name__}[{key}] = {value}")
        super().__setitem__(key, value)

    def _wrapped_delitem(self, key):
        self._log(4, f"DELITEM {self.__class__.__name__}[{key}]")
        super().__delitem__(key)

    def _wrapped_init(self, *args, **kwargs):
        self._log(4, f"INIT {self.__class__.__name__}")
        # print args info
        for i, arg in enumerate(args):
            self._log(4, f"  Arg {i}: {type(arg).__name__} = {arg}")
        # print kwargs info
        for k, v in kwargs.items():
            self._log(4, f"  Kwarg {k}: {type(v).__name__} = {v}")
        return super().__init__(*args, **kwargs)

    def _wrapped_del(self):
        self._log(4, f"DEL {self.__class__.__name__}")
        return super().__del__()

    def _dummy_init(self, *args, **kwargs):
        self._log(4, f"INIT {self.__class__.__name__}")
        # print args info
        for i, arg in enumerate(args):
            self._log(4, f"  Unused Arg {i}: {type(arg).__name__} = {arg}")
        # print kwargs info
        for k, v in kwargs.items():
            self._log(4, f"  Unused Kwarg {k}: {type(v).__name__} = {v}")

    def _dummy_del(self):
        self._log(4, f"DEL {self.__class__.__name__}")

def create_debug_wrapper(func: Callable) -> Callable:
    """Create a debug-enabled wrapper for a function"""
    # Do not wrap private methods
    if func.__name__.startswith('_'):
        return func

    # Check if this is a classmethod
    is_classmethod = isinstance(func, classmethod) or hasattr(func, '__self__')
        
    @wraps(func)
    def wrapper(*args, **kwargs):
        if not _VERBOSITY:
            return func(*args, **kwargs)
            
        thread = threading.current_thread()
        start = time.perf_counter()
        
        # Log call
        if _VERBOSITY >= 2:
            print(f"[{time.time():.6f}] [{thread.name}] CALL {func.__name__}")
            # Skip logging self argument for instance methods
            arg_start = 1 if args else 0
            for i, arg in enumerate(args[arg_start:], start=arg_start):
                print(f"[{time.time():.6f}] [{thread.name}]   Arg {i}: {type(arg).__name__} = {arg}")
            for k, v in kwargs.items():
                print(f"[{time.time():.6f}] [{thread.name}]   Kwarg {k}: {type(v).__name__} = {v}")
                
        try:
            # Handle classmethod binding 
            if is_classmethod and hasattr(func, '__get__'):
                result = func.__get__(None, args[0])(*args[1:], **kwargs)
            else:
                result = func(*args, **kwargs)

            duration = (time.perf_counter() - start) * 1000
            if _VERBOSITY >= 2:
                print(f"[{time.time():.6f}] [{thread.name}] RETURN {func.__name__} -> {type(result).__name__} ({duration:.2f}ms)")
            if _VERBOSITY >= 3:
                print(f"[{time.time():.6f}] [{thread.name}]   Value: {result}")
                
            return result
            
        except Exception as e:
            duration = (time.perf_counter() - start) * 1000
            if func.__name__ == "attach_to_parent":
                # Errors are expected for this function when the parent is incompatible
                if _VERBOSITY >= 2:
                    print(f"[{time.time():.6f}] [{thread.name}] INFO {func.__name__}: {type(e).__name__}: {e} ({duration:.2f}ms)")
                    print("This warning can be safely ignored if you didn't intend to attach this item to this parent")
            else:
                print(f"[{time.time():.6f}] [{thread.name}] ERROR {func.__name__} -> {type(e).__name__}: {e} ({duration:.2f}ms)")
            raise
            
    # Preserve classmethod decoration
    return classmethod(wrapper) if is_classmethod else wrapper

def create_debug_class(cls: type) -> type:
    """Create a debug-enabled subclass of the given class with wrapped methods
    
    Args:
        cls: The class to create a debug version of
        
    Returns:
        A new class that inherits from DebugMixin and the original class
    """
    # Avoid creating duplicate debug classes
    if cls.__name__.startswith('Debug'):
        return cls
        
    # Collect methods to wrap
    wrapped_methods = {}
    for name, method in inspect.getmembers(cls):
        try:
            if callable(method) and not name.startswith('_') and not isinstance(method, property):
                wrapped = create_debug_wrapper(method)
                wrapped_methods[name] = wrapped
        except (TypeError, AttributeError):
            continue
            
    # Create debug class with wrapped methods
    debug_cls = type(
        f"Debug{cls.__name__}",
        (DebugMixin, cls),
        {
            **wrapped_methods,
            '__module__': cls.__module__,
            '__doc__': cls.__doc__,
            '__qualname__': cls.__qualname__
        }
    )
    
    # Apply the debug class initializer
    return _debug_class_init(debug_cls)