#!python
#cython: language_level=3
#cython: boundscheck=False
#cython: wraparound=False
#cython: nonecheck=False
#cython: embedsignature=False
#cython: cdivision=True
#cython: cdivision_warnings=False
#cython: always_allow_keywords=False
#cython: profile=False
#cython: infer_types=False
#cython: initializedcheck=False
#cython: c_line_in_traceback=False
#cython: auto_pickle=False
#cython: freethreading_compatible=True
#distutils: language=c++

from libc.stdint cimport int32_t
from libcpp.cmath cimport fabs, pow, fmod
from libcpp.string cimport string
from libcpp.vector cimport vector

from cpython.object cimport PyObject

from .core cimport uiItem, lock_gil_friendly, Viewport
from .c_types cimport DCGVector, unique_lock, DCGMutex
from .imgui cimport get_theme_style_float, get_theme_style_vec2
from .types cimport Vec2

from .imgui_types import ImGuiStyleIndex

import inspect

cdef class baseSizing:
    """
    Base class for objects that compute frame to frame
    the size of target objects.
    """

    @property
    def freeze(self):
        """
        Whether to freeze the size computation (in pixels).
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._frozen

    @freeze.setter
    def freeze(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._frozen = value

    @property
    def value(self):
        """
        Last value
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._current_value

    @value.setter
    def value(self, float v):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._current_value = v

    cdef float resolve(self, uiItem target) noexcept nogil:
        """
        Function called during rendering
        that resolves for the target item
        the size it should have for the target.
        """
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)

        # Avoid recomputing multiple times in the same frame.
        # Only the previous frame affects computation.
        if self._frozen:
            return self._current_value

        cdef int32_t frame_count = target.context.viewport.frame_count
        if self._last_frame_resolved == frame_count:
            if self._push != baseSizing._push:
                self._push(target)
            return self._current_value

        cdef float current_value = self._current_value

        if self._update_value != baseSizing._update_value:
            self._current_value = self._update_value(target)

        if current_value != self._current_value:
            # Possibility of cascading updates
            target.context.viewport.redraw_needed = True

        if self._push != baseSizing._push:
            self._push(target)

        self._last_frame_resolved = target.context.viewport.frame_count
        return self._current_value

    cdef void _push(self, uiItem target) noexcept nogil:
        """
        Called during rendering to indicate resolve was
        called for this item. Some subclasses need to retrieve
        the state of the viewport and of the cursor to compute
        the value, thus they need to get their measurements here.

        The expected behaviour is that classes that need to use
        item states retrieve them during _push.
        """
        return

    cdef float _update_value(self, uiItem target) noexcept nogil:
        """
        Actual computation of the value, to be implemented by subclasses,
        and should use previous frame values retrieved during _push.
        """
        return 0.0

    @staticmethod
    cdef baseSizing Size(value):
        """
        Convert a Python object to a baseSizing object.
        """
        if isinstance(value, baseSizing):
            return value
        elif isinstance(value, (int, float)):
            return FixedSize(value)
        elif isinstance(value, str):
            return parse_size(value)
        raise TypeError(f"Cannot convert {value!r} to baseSizing")

    # Operator overloading for composition
    def __add__(baseSizing self, other):
        cdef baseSizing other_size = baseSizing.Size(other)
        if other_size is None:
            return NotImplemented
        return AddSize(self, other_size)

    def __sub__(baseSizing self, other):
        cdef baseSizing other_size = baseSizing.Size(other)
        if other_size is None:
            return NotImplemented
        return SubtractSize(self, other_size)

    def __mul__(baseSizing self, other):
        cdef baseSizing other_size = baseSizing.Size(other)
        if other_size is None:
            return NotImplemented
        return MultiplySize(self, other_size)

    def __truediv__(baseSizing self, other):
        cdef baseSizing other_size = baseSizing.Size(other)
        if other_size is None:
            return NotImplemented
        return DivideSize(self, other_size)
        
    # New operators
    def __floordiv__(baseSizing self, other):
        cdef baseSizing other_size = baseSizing.Size(other)
        if other_size is None:
            return NotImplemented
        return FloorDivideSize(self, other_size)
        
    def __mod__(baseSizing self, other):
        cdef baseSizing other_size = baseSizing.Size(other)
        if other_size is None:
            return NotImplemented
        return ModuloSize(self, other_size)
        
    def __pow__(baseSizing self, other, modulo=None):
        cdef baseSizing other_size = baseSizing.Size(other)
        if other_size is None:
            return NotImplemented
        return PowerSize(self, other_size)
        
    def __neg__(baseSizing self):
        return NegateSize(self)
        
    def __abs__(baseSizing self):
        return AbsoluteSize(self)
        
    # Right-side operators
    def __radd__(baseSizing self, other):
        cdef baseSizing other_size = baseSizing.Size(other)
        if other_size is None:
            return NotImplemented
        return AddSize(other_size, self)
        
    def __rsub__(baseSizing self, other):
        cdef baseSizing other_size = baseSizing.Size(other)
        if other_size is None:
            return NotImplemented
        return SubtractSize(other_size, self)
        
    def __rmul__(baseSizing self, other):
        cdef baseSizing other_size = baseSizing.Size(other)
        if other_size is None:
            return NotImplemented
        return MultiplySize(other_size, self)
        
    def __rtruediv__(baseSizing self, other):
        cdef baseSizing other_size = baseSizing.Size(other)
        if other_size is None:
            return NotImplemented
        return DivideSize(other_size, self)
        
    def __rfloordiv__(baseSizing self, other):
        cdef baseSizing other_size = baseSizing.Size(other)
        if other_size is None:
            return NotImplemented
        return FloorDivideSize(other_size, self)
        
    def __rmod__(baseSizing self, other):
        cdef baseSizing other_size = baseSizing.Size(other)
        if other_size is None:
            return NotImplemented
        return ModuloSize(other_size, self)
        
    def __rpow__(baseSizing self, other):
        cdef baseSizing other_size = baseSizing.Size(other)
        if other_size is None:
            return NotImplemented
        return PowerSize(other_size, self)

    def __float__(baseSizing self):
        return self._current_value

    def __int__(baseSizing self):
        return int(self._current_value)

    def __repr__(self):
        """
        Return a string representation that can be used to recreate the object.
        """
        return f"{self.__class__.__name__}({self._current_value})"
    
    def __str__(self):
        """
        Return a human-readable string representation.
        """
        if self._frozen:
            return f"{self.__class__.__name__}({self._current_value}, frozen=True)"
        return f"{self.__class__.__name__}({self._current_value})"
    
    def __reduce__(self):
        """
        Support for pickling.
        """
        return (self.__class__, (self._current_value,), {'_frozen': self._frozen})

cdef class FixedSize(baseSizing):
    """
    Fixed size in pixels.
    """
    def __cinit__(self, float size):
        self._current_value = size
        
    cdef float resolve(self, uiItem target) noexcept nogil:
        return self._current_value

    def __repr__(self):
        return f"FixedSize({self._current_value})"
    
    def __str__(self):
        return f"{self._current_value}"
        
    def __reduce__(self):
        return (self.__class__, (self._current_value,), {'_frozen': self._frozen})

cdef class DPI(baseSizing):
    """
    Resolves to the current global scale factor.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        return target.context.viewport.global_scale

    def __repr__(self):
        return "DPI()"
    
    def __str__(self):
        return "dpi"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen})

cdef class binarySizeOp(baseSizing):
    """
    Base class for binary operations on size values.
    """
    cdef baseSizing _left
    cdef baseSizing _right
    cdef float _left_value
    cdef float _right_value

    def __cinit__(self, baseSizing left not None, baseSizing right not None):
        self._left = left
        self._right = right
        self._left_value = 0.0
        self._right_value = 0.0

    cdef void _push(self, uiItem target) noexcept nogil:
        if self._left._push != baseSizing._push:
            self._left._push(target)
        if self._right._push != baseSizing._push:
            self._right._push(target)

    def __repr__(self):
        return f"{self.__class__.__name__}({self._left!r}, {self._right!r})"
    
    def __str__(self):
        return f"{self.__class__.__name__}({self._left}, {self._right})"
        
    def __reduce__(self):
        return (self.__class__, (self._left, self._right), 
                {'_frozen': self._frozen, '_current_value': self._current_value})

cdef class MinSize(binarySizeOp):
    """
    Take minimum of two size values.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        cdef float first_value = self._left.resolve(target)
        cdef float second_value = self._right.resolve(target)
        return min(first_value, second_value)

    def __str__(self):
        return f"Min({self._left}, {self._right})"

cdef class MaxSize(binarySizeOp):
    """
    Take maximum of two size values.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        cdef float first_value = self._left.resolve(target)
        cdef float second_value = self._right.resolve(target)
        return max(first_value, second_value)

    def __str__(self):
        return f"Max({self._left}, {self._right})"

# Binary operation classes for composition

cdef class AddSize(binarySizeOp):
    """
    Add two size values.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        cdef float first_value = self._left.resolve(target)
        cdef float second_value = self._right.resolve(target)
        return first_value + second_value

    def __str__(self):
        return f"({self._left} + {self._right})"

cdef class SubtractSize(binarySizeOp):
    """
    Subtract one size from another.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        cdef float first_value = self._left.resolve(target)
        cdef float second_value = self._right.resolve(target)
        return first_value - second_value

    def __str__(self):
        return f"({self._left} - {self._right})"

cdef class MultiplySize(binarySizeOp):
    """
    Multiply size values.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        cdef float first_value = self._left.resolve(target)
        cdef float second_value = self._right.resolve(target)
        return first_value * second_value

    def __str__(self):
        return f"({self._left} * {self._right})"

cdef class DivideSize(binarySizeOp):
    """
    Divide size values.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        cdef float first_value = self._left.resolve(target)
        cdef float second_value = self._right.resolve(target)

        if second_value == 0:
            return 0.0  # Avoid division by zero
        return first_value / second_value

    def __str__(self):
        return f"({self._left} / {self._right})"

cdef class FloorDivideSize(binarySizeOp):
    """
    Floor division of size values.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        cdef float first_value = self._left.resolve(target)
        cdef float second_value = self._right.resolve(target)

        if second_value == 0:
            return 0.0  # Avoid division by zero
        return <float>(<int>(first_value / second_value))  # Floor division

    def __str__(self):
        return f"({self._left} // {self._right})"

cdef class ModuloSize(binarySizeOp):
    """
    Modulo operation on size values.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        cdef float first_value = self._left.resolve(target)
        cdef float second_value = self._right.resolve(target)

        if second_value == 0:
            return 0.0  # Avoid division by zero
        return fmod(first_value, second_value)

    def __str__(self):
        return f"({self._left} % {self._right})"

cdef class PowerSize(binarySizeOp):
    """
    Power operation on size values.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        cdef float first_value = self._left.resolve(target)
        cdef float second_value = self._right.resolve(target)

        return pow(first_value, second_value)

    def __str__(self):
        return f"({self._left} ** {self._right})"

cdef class NegateSize(baseSizing):
    """
    Negation of a size value.
    """
    cdef baseSizing _operand
    
    def __cinit__(self, baseSizing operand not None):
        self._operand = operand
        
    cdef void _push(self, uiItem target) noexcept nogil:
        if self._operand._push != baseSizing._push:
            self._operand._push(target)
            
    cdef float _update_value(self, uiItem target) noexcept nogil:
        return -self._operand.resolve(target)
        
    def __repr__(self):
        return f"NegateSize({self._operand!r})"
        
    def __str__(self):
        return f"(-{self._operand})"
        
    def __reduce__(self):
        return (self.__class__, (self._operand,), 
                {'_frozen': self._frozen, '_current_value': self._current_value})

cdef class AbsoluteSize(baseSizing):
    """
    Absolute value of a size value.
    """
    cdef baseSizing _operand
    
    def __cinit__(self, baseSizing operand not None):
        self._operand = operand
        
    cdef void _push(self, uiItem target) noexcept nogil:
        if self._operand._push != baseSizing._push:
            self._operand._push(target)
            
    cdef float _update_value(self, uiItem target) noexcept nogil:
        return fabs(self._operand.resolve(target))
        
    def __repr__(self):
        return f"AbsoluteSize({self._operand!r})"
        
    def __str__(self):
        return f"abs({self._operand})"
        
    def __reduce__(self):
        return (self.__class__, (self._operand,), 
                {'_frozen': self._frozen, '_current_value': self._current_value})

# Dynamic value based on another item

cdef class FillSizeX(baseSizing):
    """
    Fill available content width.
    """
    cdef float _available_space

    def __cinit__(self):
        self._available_space = 0.0
        
    cdef void _push(self, uiItem target) noexcept nogil:
        cdef float available = target.context.viewport.parent_size.x
        # Note: at this step cur is up to date
        available -= target.state.cur.pos_to_parent.x

        if available > self._available_space:
            self._available_space = available

    cdef float _update_value(self, uiItem target) noexcept nogil:
        # Return available space
        cdef float current_value = max(0.0, self._available_space)
        # Reset available space
        self._available_space = 0.0
        return current_value

    def __repr__(self):
        return "FillSizeX()"
    
    def __str__(self):
        return "fillx"
        
    def __reduce__(self):
        return (self.__class__, (), 
                {'_frozen': self._frozen, '_current_value': self._current_value})

cdef class FillSizeY(baseSizing):
    """
    Fill available content height.
    """
    cdef float _available_space

    def __cinit__(self):
        self._available_space = 0.0
        
    cdef void _push(self, uiItem target) noexcept nogil:
        cdef float available = target.context.viewport.parent_size.y
        available -= target.state.cur.pos_to_parent.y

        if available > self._available_space:
            self._available_space = available

    cdef float _update_value(self, uiItem target) noexcept nogil:
        # Return available space
        cdef float current_value = max(0.0, self._available_space)
        # Reset available space
        self._available_space = 0.0
        return current_value

    def __repr__(self):
        return "FillSizeY()"
    
    def __str__(self):
        return "filly"
        
    def __reduce__(self):
        return (self.__class__, (), 
                {'_frozen': self._frozen, '_current_value': self._current_value})

cdef class FullSizeX(baseSizing):
    """
    Full parent content width (no position offset subtraction).
    """
    cdef float _available_space

    def __cinit__(self):
        self._available_space = 0.0
        
    cdef void _push(self, uiItem target) noexcept nogil:
        cdef float available = target.context.viewport.parent_size.x

        if available > self._available_space:
            self._available_space = available

    cdef float _update_value(self, uiItem target) noexcept nogil:
        # Return available space
        cdef float current_value = max(0.0, self._available_space)
        # Reset available space
        self._available_space = 0.0
        return current_value

    def __repr__(self):
        return "FullSizeX()"
    
    def __str__(self):
        return "fullx"
        
    def __reduce__(self):
        return (self.__class__, (), 
                {'_frozen': self._frozen, '_current_value': self._current_value})

cdef class FullSizeY(baseSizing):
    """
    Full parent content height (no position offset subtraction).
    """
    cdef float _available_space

    def __cinit__(self):
        self._available_space = 0.0
        
    cdef void _push(self, uiItem target) noexcept nogil:
        cdef float available = target.context.viewport.parent_size.y

        if available > self._available_space:
            self._available_space = available

    cdef float _update_value(self, uiItem target) noexcept nogil:
        # Return available space
        cdef float current_value = max(0.0, self._available_space)
        # Reset available space
        self._available_space = 0.0
        return current_value

    def __repr__(self):
        return "FullSizeY()"
    
    def __str__(self):
        return "fully"
        
    def __reduce__(self):
        return (self.__class__, (), 
                {'_frozen': self._frozen, '_current_value': self._current_value})

cdef class ParentHeight(baseSizing):
    """
    Parent height. Use fully instead for parent content height
    """

    cdef float _update_value(self, uiItem target) noexcept nogil:
        # Note: when called, the lock is maintaned on target and all its parents.
        if target.parent is target.context.viewport:
            return target.context.viewport.get_size().y
        if target.parent is None or target.parent.p_state is NULL:
            return 0. # Shouldn't happen, but just in case
        return target.parent.p_state.cur.rect_size.y

    def __repr__(self):
        return "ParentHeight()"
    
    def __str__(self):
        return "parent.height"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen})

cdef class ParentWidth(baseSizing):
    """
    Parent width. Use fullx instead for parent content width
    """

    cdef float _update_value(self, uiItem target) noexcept nogil:
        # Note: when called, the lock is maintaned on target and all its parents.
        if target.parent is target.context.viewport:
            return target.context.viewport.get_size().x
        if target.parent is None or target.parent.p_state is NULL:
            return 0. # Shouldn't happen, but just in case
        return target.parent.p_state.cur.rect_size.x

    def __repr__(self):
        return "ParentWidth()"
    
    def __str__(self):
        return "parent.width"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen})

cdef class ParentX0(baseSizing):
    """
    Parent actual left x coordinate (x0) without content padding.
    This refers to the outer position of the parent item.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        # Note: when called, the lock is maintaned on target and all its parents.
        if target.parent is target.context.viewport:
            return 0.0
        if target.parent is None or target.parent.p_state is NULL:
            return target.context.viewport.parent_pos.x
        if target.parent.p_state.cap.has_position:
            return target.parent.p_state.cur.pos_to_viewport.x
        # fallback to x1:
        return target.context.viewport.parent_pos.x

    def __repr__(self):
        return "ParentX0()"
    
    def __str__(self):
        return "parent.x0"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen})

cdef class ParentX1(baseSizing):
    """
    Parent left content area x coordinate (x1).
    This is the left edge of the parent's content area, accounting for padding.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        # Return the content position of the parent
        return target.context.viewport.parent_pos.x

    def __repr__(self):
        return "ParentX1()"
    
    def __str__(self):
        return "parent.x1"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen})

cdef class ParentX2(baseSizing):
    """
    Parent right content area x coordinate (x2).
    This is the right edge of the parent's content area, accounting for padding.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        # Return the content position + size
        return target.context.viewport.parent_pos.x + target.context.viewport.parent_size.x

    def __repr__(self):
        return "ParentX2()"
    
    def __str__(self):
        return "parent.x2"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen})

cdef class ParentX3(baseSizing):
    """
    Parent right-most x coordinate (x3).
    This is the right-most edge of the parent's accounting for padding and border.
    It is equivalent to parent.x0 + parent.width.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        if target.parent is target.context.viewport:
            return target.context.viewport.get_size().x
        if target.parent is None or target.parent.p_state is NULL:
            return target.context.viewport.parent_pos.x + target.context.viewport.parent_size.x
        if target.parent.p_state.cap.has_position and target.parent.p_state.cap.has_rect_size:
            return target.parent.p_state.cur.pos_to_viewport.x + target.parent.p_state.cur.rect_size.x
        # fallback to x2:
        return target.context.viewport.parent_pos.x + target.context.viewport.parent_size.x

    def __repr__(self):
        return "ParentX3()"
    
    def __str__(self):
        return "parent.x3"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen})

cdef class ParentXC(baseSizing):
    """
    Parent content area x center coordinate.
    This is the horizontal center of the parent's content area.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        # Return the content position + half size
        return target.context.viewport.parent_pos.x + (target.context.viewport.parent_size.x * 0.5)

    def __repr__(self):
        return "ParentXC()"
    
    def __str__(self):
        return "parent.xc"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen})

cdef class ParentY0(baseSizing):
    """
    Parent actual top y coordinate (y0) without content padding.
    This refers to the outer position of the parent item.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        # Note: when called, the lock is maintaned on target and all its parents.
        if target.parent is target.context.viewport:
            return 0.0
        if target.parent is None or target.parent.p_state is NULL:
            return target.context.viewport.parent_pos.y
        if target.parent.p_state.cap.has_position:
            return target.parent.p_state.cur.pos_to_viewport.y
        # fallback to y1:
        return target.context.viewport.parent_pos.y

    def __repr__(self):
        return "ParentY0()"
    
    def __str__(self):
        return "parent.y0"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen})

cdef class ParentY1(baseSizing):
    """
    Parent top content area y coordinate (y1).
    This is the top edge of the parent's content area, accounting for padding.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        # Return the content position of the parent
        return target.context.viewport.parent_pos.y

    def __repr__(self):
        return "ParentY1()"
    
    def __str__(self):
        return "parent.y1"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen})

cdef class ParentY2(baseSizing):
    """
    Parent bottom content area y coordinate (y2).
    This is the bottom edge of the parent's content area, accounting for padding.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        # Return the content position + size
        return target.context.viewport.parent_pos.y + target.context.viewport.parent_size.y

    def __repr__(self):
        return "ParentY2()"
    
    def __str__(self):
        return "parent.y2"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen})

cdef class ParentY3(baseSizing):
    """
    Parent bottom-most y coordinate (y3).
    This is the bottom-most edge of the parent's accounting for padding and border.
    It is equivalent to parent.y0 + parent.height.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        if target.parent is target.context.viewport:
            return target.context.viewport.get_size().y
        if target.parent is None or target.parent.p_state is NULL:
            return target.context.viewport.parent_pos.y + target.context.viewport.parent_size.y
        if target.parent.p_state.cap.has_position and target.parent.p_state.cap.has_rect_size:
            return target.parent.p_state.cur.pos_to_viewport.y + target.parent.p_state.cur.rect_size.y
        # fallback to y2:
        return target.context.viewport.parent_pos.y + target.context.viewport.parent_size.y

    def __repr__(self):
        return "ParentY3()"
    
    def __str__(self):
        return "parent.y3"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen})

cdef class ParentYC(baseSizing):
    """
    Parent content area y center coordinate.
    This is the vertical center of the parent's content area.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        # Return the content position + half size
        return target.context.viewport.parent_pos.y + (target.context.viewport.parent_size.y * 0.5)

    def __repr__(self):
        return "ParentYC()"
    
    def __str__(self):
        return "parent.yc"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen})

cdef class baseRefSizing(baseSizing):
    """
    Base class for references to an item's size
    and positioning attribute.

    Defines various properties to access other
    size and position attributes of this item
    """
    def __cinit__(self, uiItem ref):
        if ref is None:
            raise ValueError("Cannot reference None")
        self._ref = ref

    @property
    def content_height(self) -> baseSizing:
        """
        Height of the area available for the children
        inside the item.
        This is equivalent to y2 - y1

        For items which do not accept children, this is equal
        to the height.
        """
        return RefY2(self._ref) - RefY1(self._ref)

    @property
    def content_width(self) -> baseSizing:
        """
        Width of the area available for the children
        inside the item.
        This is equivalent to x2 - x1

        For items which do not accept children, this is equal
        to the width.
        """
        return RefX2(self._ref) - RefX1(self._ref)

    @property
    def height(self) -> baseSizing:
        """
        Height of the area taken by the item.

        Note for items with children, this may be larger
        that the area available for the children, if the
        item adds padding.
        """
        return RefHeight(self._ref)

    @property
    def width(self) -> baseSizing:
        """
        Width of the area taken by the item.

        Note for items with children, this may be larger
        that the area available for the children, if the
        item adds padding.
        """
        return RefWidth(self._ref)

    @property
    def x0(self) -> baseSizing:
        """
        Reference to the left-most x position of the item
        """
        return RefX0(self._ref)

    @property
    def x1(self) -> baseSizing:
        """
        Reference to the left x position of the item.

        This only differs from X0 for items with children
        and padding. In which case the position corresponds
        to the starting position of the area available for
        the children.
        """
        return RefX1(self._ref)

    @property
    def xc(self) -> baseSizing:
        """
        Reference to the center position between x1 and x2 of the item.
        """
        return RefXC(self._ref)

    @property
    def x2(self) -> baseSizing:
        """
        Reference to the right position of the item.

        For items with children and padding, this position is
        placed at the end of the area available for children.

        If you intend to get the right-most position for any item,
        including the case described above, you can get it by adding
        x0 and width, or by using x3.
        """
        return RefX2(self._ref)

    @property
    def x3(self) -> baseSizing:
        """
        Reference to the right-most position of the item.

        This corresponds to adding x0 and width.
        """
        return RefX0(self._ref) + RefWidth(self._ref)

    @property
    def y0(self) -> baseSizing:
        """
        Reference to the top-most y position of the item
        """
        return RefY0(self._ref)

    @property
    def y1(self) -> baseSizing:
        """
        Reference to the top y position of the item.

        This only differs from Y0 for items with children
        and padding. In which case the position corresponds
        to the starting position of the area available for
        the children.
        """
        return RefY1(self._ref)

    @property
    def yc(self) -> baseSizing:
        """
        Reference to the center position between y1 and y2 of the item.
        """
        return RefYC(self._ref)

    @property
    def y2(self) -> baseSizing:
        """
        Reference to the bottom position of the item.

        For items with children and padding, this position is
        placed at the end of the area available for children.

        If you intend to get the bottom-most position for any item,
        including the case described above, you can get it by adding
        y0 and height.
        """
        return RefY2(self._ref)

    @property
    def y3(self) -> baseSizing:
        """
        Reference to the bottom-most position of the item.

        This corresponds to adding
        y0 and height.
        """
        return RefY0(self._ref) + RefHeight(self._ref)

cdef class RefHeight(baseRefSizing):
    """
    References another item height.
    """
    def __cinit__(self):
        if not self._ref.state.cap.has_rect_size and not self._ref.state.cap.has_content_region:
            raise TypeError("Cannot reference item without size")

    cdef float _update_value(self, uiItem target) noexcept nogil:
        if self._ref.state.cap.has_rect_size:
            # Use rect_size if available
            return self._ref.state.cur.rect_size.y
        return self._ref.state.cur.content_region_size.y

    def __repr__(self):
        # Use ID to avoid circular references in repr
        return f"RefHeight(<item-{id(self._ref):#x}>)"

    def __str__(self):
        return "other.height"

cdef class RefWidth(baseRefSizing):
    """
    References another item width.
    """
    def __cinit__(self):
        if not self._ref.state.cap.has_rect_size and not self._ref.state.cap.has_content_region:
            raise TypeError("Cannot reference item without size")

    cdef float _update_value(self, uiItem target) noexcept nogil:
        if self._ref.state.cap.has_rect_size:
            # Use rect_size if available
            return self._ref.state.cur.rect_size.x
        return self._ref.state.cur.content_region_size.x

    def __repr__(self):
        # Use ID to avoid circular references in repr
        return f"RefWidth(<item-{id(self._ref):#x}>)"

    def __str__(self):
        return "other.width"

cdef class RefX0(baseRefSizing):
    """
    References another item's left x coordinate (x0).

    x0 is the left most position of the item.

    For items which accept children, and which add padding,
    x1 can be different to x0.
    """
    def __cinit__(self):
        if not self._ref.state.cap.has_position and not self._ref.state.cap.has_content_region:
            raise TypeError("Cannot reference item without position")

    cdef float _update_value(self, uiItem target) noexcept nogil:
        if self._ref.state.cap.has_position:
            # Use pos_to_viewport if item has position
            return self._ref.state.cur.pos_to_viewport.x
        # fallback to content_pos if no position
        return self._ref.state.cur.content_pos.x

    def __repr__(self):
        # Use ID to avoid circular references in repr
        return f"RefX0(<item-{id(self._ref):#x}>)"
    
    def __str__(self):
        return "other.x0"

cdef class RefX1(baseRefSizing):
    """
    References another item's left x coordinate (x1).

    x1 is the left x position of the item.

    For item which accept children, this refers to the x position
    of the area available for children. If the item adds
    padding, it can thus differ from x0.
    """
    def __cinit__(self):
        # Must have position to compute
        if not self._ref.state.cap.has_position and not self._ref.state.cap.has_content_region:
            raise TypeError("Cannot reference item without position or content area")

    cdef float _update_value(self, uiItem target) noexcept nogil:
        # Use content_pos if item has content region, otherwise use pos_to_viewport
        if self._ref.state.cap.has_content_region:
            return self._ref.state.cur.content_pos.x
        return self._ref.state.cur.pos_to_viewport.x

    def __repr__(self):
        # Use ID to avoid circular references in repr
        return f"RefX1(<item-{id(self._ref):#x}>)"
    
    def __str__(self):
        return "other.x1"

cdef class RefX2(baseRefSizing):
    """
    References another item's right x coordinate (x2).
    This is the right edge of the item's content area, accounting for padding if available.
    If the item has no content area, this is equivalent to x0 + width.
    """
    def __cinit__(self):
        # Must have position to compute
        if not self._ref.state.cap.has_position and not self._ref.state.cap.has_content_region:
            raise TypeError("Cannot reference item without position or content area")

    cdef float _update_value(self, uiItem target) noexcept nogil:
        # Use content_pos + content_region_size if item has content region
        if self._ref.state.cap.has_content_region:
            return self._ref.state.cur.content_pos.x + self._ref.state.cur.content_region_size.x
        if self._ref.state.cap.has_rect_size:
            return self._ref.state.cur.pos_to_viewport.x + self._ref.state.cur.rect_size.x
        return self._ref.state.cur.pos_to_viewport.x

    def __repr__(self):
        # Use ID to avoid circular references in repr
        return f"RefX2(<item-{id(self._ref):#x}>)"
    
    def __str__(self):
        return "other.x2"

cdef class RefX3(baseRefSizing):
    """
    References another item's right-most x coordinate (x3).
    This is equivalent to x0 + width.
    It is useful for items which do not have a content area,
    or when you want to get the right-most position regardless
    of padding.
    """
    def __cinit__(self):
        # Must have position to compute
        if not self._ref.state.cap.has_position and not self._ref.state.cap.has_content_region:
            raise TypeError("Cannot reference item without position or content area")

    cdef float _update_value(self, uiItem target) noexcept nogil:
        if self._ref.state.cap.has_position and self._ref.state.cap.has_rect_size:
            # Use pos_to_viewport + rect_size if item has position
            return self._ref.state.cur.pos_to_viewport.x + self._ref.state.cur.rect_size.x
        if self._ref.state.cap.has_content_region:
            return self._ref.state.cur.content_pos.x + self._ref.state.cur.content_region_size.x
        return self._ref.state.cur.pos_to_viewport.x

    def __repr__(self):
        # Use ID to avoid circular references in repr
        return f"RefX3(<item-{id(self._ref):#x}>)"
    
    def __str__(self):
        return "other.x3"

cdef class RefXC(baseRefSizing):
    """
    References another item's content x center coordinate.
    This is the horizontal center of the item's content area if available.
    If the item has no content area, this is equivalent to x0 + width/2.
    """
    def __cinit__(self):
        # Must have position to compute
        if not self._ref.state.cap.has_position and not self._ref.state.cap.has_content_region:
            raise TypeError("Cannot reference item without position or content area")

    cdef float _update_value(self, uiItem target) noexcept nogil:
        # Use content_pos + content_region_size/2 if item has content region
        if self._ref.state.cap.has_content_region:
            return self._ref.state.cur.content_pos.x + (self._ref.state.cur.content_region_size.x * 0.5)
        if self._ref.state.cap.has_rect_size:
            return self._ref.state.cur.pos_to_viewport.x + (self._ref.state.cur.rect_size.x * 0.5)
        return self._ref.state.cur.pos_to_viewport.x

    def __repr__(self):
        # Use ID to avoid circular references in repr
        return f"RefXC(<item-{id(self._ref):#x}>)"
    
    def __str__(self):
        return "other.xc"

cdef class RefY0(baseRefSizing):
    """
    References another item's outer top y coordinate (y0).
    This is the actual position of the item, not accounting for content area padding.
    """
    def __cinit__(self):
        # Must have position to compute
        if not self._ref.state.cap.has_position and not self._ref.state.cap.has_content_region:
            raise TypeError("Cannot reference item without position")

    cdef float _update_value(self, uiItem target) noexcept nogil:
        if self._ref.state.cap.has_position:
            return self._ref.state.cur.pos_to_viewport.y
        return self._ref.state.cur.content_pos.y

    def __repr__(self):
        # Use ID to avoid circular references in repr
        return f"RefY0(<item-{id(self._ref):#x}>)"
    
    def __str__(self):
        return "other.y0"

cdef class RefY1(baseRefSizing):
    """
    References another item's content top y coordinate (y1).
    This is the top edge of the item's content area, accounting for padding if available.
    If the item has no content area, this is equivalent to y0.
    """
    def __cinit__(self):
        # Must have position to compute
        if not self._ref.state.cap.has_position and not self._ref.state.cap.has_content_region:
            raise TypeError("Cannot reference item without position or content area")

    cdef float _update_value(self, uiItem target) noexcept nogil:
        # Use content_pos if item has content region, otherwise use pos_to_viewport
        if self._ref.state.cap.has_content_region:
            return self._ref.state.cur.content_pos.y
        return self._ref.state.cur.pos_to_viewport.y

    def __repr__(self):
        # Use ID to avoid circular references in repr
        return f"RefY1(<item-{id(self._ref):#x}>)"
    
    def __str__(self):
        return "other.y1"

cdef class RefY2(baseRefSizing):
    """
    References another item's content bottom y coordinate (y2).
    This is the bottom edge of the item's content area, accounting for padding if available.
    If the item has no content area, this is equivalent to y0 + height.
    """
    def __cinit__(self):
        # Must have position to compute
        if not self._ref.state.cap.has_position and not self._ref.state.cap.has_content_region:
            raise TypeError("Cannot reference item without position or content area")

    cdef float _update_value(self, uiItem target) noexcept nogil:
        # Use content_pos + content_region_size if item has content region
        if self._ref.state.cap.has_content_region:
            return self._ref.state.cur.content_pos.y + self._ref.state.cur.content_region_size.y
        if self._ref.state.cap.has_rect_size:
            return self._ref.state.cur.pos_to_viewport.y + self._ref.state.cur.rect_size.y
        return self._ref.state.cur.pos_to_viewport.y

    def __repr__(self):
        # Use ID to avoid circular references in repr
        return f"RefY2(<item-{id(self._ref):#x}>)"
    
    def __str__(self):
        return "other.y2"

cdef class RefY3(baseRefSizing):
    """
    References another item's bottom-most y coordinate (y3).
    This is equivalent to y0 + height.

    It is useful for items which do not have a content area,
    or when you want to get the bottom-most position regardless
    of padding.
    """
    def __cinit__(self):
        # Must have position to compute
        if not self._ref.state.cap.has_position and not self._ref.state.cap.has_content_region:
            raise TypeError("Cannot reference item without position or content area")

    cdef float _update_value(self, uiItem target) noexcept nogil:
        if self._ref.state.cap.has_position and self._ref.state.cap.has_rect_size:
            return self._ref.state.cur.pos_to_viewport.y + self._ref.state.cur.rect_size.y
        if self._ref.state.cap.has_content_region:
            return self._ref.state.cur.content_pos.y + self._ref.state.cur.content_region_size.y
        return self._ref.state.cur.pos_to_viewport.y

    def __repr__(self):
        # Use ID to avoid circular references in repr
        return f"RefY3(<item-{id(self._ref):#x}>)"
    
    def __str__(self):
        return "other.y3"

cdef class RefYC(baseRefSizing):
    """
    References another item's content y center coordinate.
    This is the vertical center of the item's content area if available.
    If the item has no content area, this is equivalent to (y1 + y2)/2.
    """
    def __cinit__(self):
        # Must have position to compute
        if not self._ref.state.cap.has_position and not self._ref.state.cap.has_content_region:
            raise TypeError("Cannot reference item without position or content area")

    cdef float _update_value(self, uiItem target) noexcept nogil:
        # Use content_pos + content_region_size/2 if item has content region
        if self._ref.state.cap.has_content_region:
            return self._ref.state.cur.content_pos.y + (self._ref.state.cur.content_region_size.y * 0.5)
        if not self._ref.state.cap.has_rect_size:
            return self._ref.state.cur.pos_to_viewport.y
        return self._ref.state.cur.pos_to_viewport.y + (self._ref.state.cur.rect_size.y * 0.5)

    def __repr__(self):
        # Use ID to avoid circular references in repr
        return f"RefYC(<item-{id(self._ref):#x}>)"
    
    def __str__(self):
        return "other.yc"

cdef class SelfHeight(baseSizing):
    """
    References the height of the item using this sizing.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        if target is None:
            return 0.0
        if target.state.cap.has_rect_size:
            return target.state.cur.rect_size.y
        if target.state.cap.has_content_region:
            return target.state.cur.content_region_size.y
        return 0.0  # Fallback if no size or content region

    def __repr__(self):
        return "SelfHeight()"

    def __str__(self):
        return f"self.height"

    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen, '_current_value': self._current_value})

cdef class SelfWidth(baseSizing):
    """
    References the width of the item using this sizing.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        if target is None:
            return 0.0
        if target.state.cap.has_rect_size:
            return target.state.cur.rect_size.x
        if target.state.cap.has_content_region:
            return target.state.cur.content_region_size.x
        return 0.0  # Fallback if no size or content region

    def __repr__(self):
        return "SelfWidth()"
    
    def __str__(self):
        return "self.width"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen, '_current_value': self._current_value})

cdef class SelfX0(baseSizing):
    """
    References the left-most x coordinate (x0) of the item using this sizing.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        if target is None:
            return 0.0
        if target.state.cap.has_position:
            return target.state.cur.pos_to_viewport.x
        if target.state.cap.has_content_region:
            return target.state.cur.content_pos.x
        return 0.0  # Fallback if no position or content region

    def __repr__(self):
        return "SelfX0()"

    def __str__(self):
        return "self.x0"

    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen, '_current_value': self._current_value})

cdef class SelfX1(baseSizing):
    """
    References the left x coordinate (x1) of the item using this sizing.

    x1 is the start of the children area of the item.
    Else it is equal to x0.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        if target is None:
            return 0.0
        if target.state.cap.has_content_region:
            return target.state.cur.content_pos.x
        if target.state.cap.has_position:
            return target.state.cur.pos_to_viewport.x
        return 0.0  # Fallback if no position or content region

    def __repr__(self):
        return "SelfX1()"

    def __str__(self):
        return "self.x1"

    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen, '_current_value': self._current_value})

cdef class SelfX2(baseSizing):
    """
    References the right x coordinate (x2) of the item using this sizing.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        if target is None:
            return 0.0
        if target.state.cap.has_content_region:
            return target.state.cur.content_pos.x + target.state.cur.content_region_size.x
        if target.state.cap.has_position:
            if not target.state.cap.has_rect_size:
                return target.state.cur.pos_to_viewport.x
            return target.state.cur.pos_to_viewport.x + target.state.cur.rect_size.x
        return 0.0  # Fallback if no position or content region

    def __repr__(self):
        return "SelfX2()"
    
    def __str__(self):
        return "self.x2"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen, '_current_value': self._current_value})

cdef class SelfX3(baseSizing):
    """
    References the right-most x coordinate (x3) of the item using this sizing.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        if target is None:
            return 0.0
        if target.state.cap.has_position and target.state.cap.has_rect_size:
            return target.state.cur.pos_to_viewport.x + target.state.cur.rect_size.x
        if target.state.cap.has_content_region:
            return target.state.cur.content_pos.x + target.state.cur.content_region_size.x
        if target.state.cap.has_position:
            return target.state.cur.pos_to_viewport.x
        return 0.0  # Fallback if no position or content region

    def __repr__(self):
        return "SelfX3()"
    
    def __str__(self):
        return "self.x3"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen, '_current_value': self._current_value})

cdef class SelfXC(baseSizing):
    """
    References the x center coordinate of the item using this sizing.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        if target is None:
            return 0.0
        if target.state.cap.has_content_region:
            return target.state.cur.content_pos.x + (target.state.cur.content_region_size.x * 0.5)
        if target.state.cap.has_position:
            if not target.state.cap.has_rect_size:
                return target.state.cur.pos_to_viewport.x
            return target.state.cur.pos_to_viewport.x + (target.state.cur.rect_size.x * 0.5)
        return 0.0  # Fallback if no position or content region

    def __repr__(self):
        return "SelfXC()"
    
    def __str__(self):
        return "self.xc"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen, '_current_value': self._current_value})

cdef class SelfY0(baseSizing):
    """
    References the top-most y coordinate (y0) of the item using this sizing.
    This refers to the outer position of the item.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        if target is None:
            return 0.0
        if target.state.cap.has_position:
            return target.state.cur.pos_to_viewport.y
        if target.state.cap.has_content_region:
            return target.state.cur.content_pos.y
        return 0.0  # Fallback if no position or content region

    def __repr__(self):
        return "SelfY0()"
    
    def __str__(self):
        return "self.y0"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen, '_current_value': self._current_value})

cdef class SelfY1(baseSizing):
    """
    References the top y coordinate (y1) of the item using this sizing.

    y1 is the start of the children area of the item, if any.
    Else it is equal to y0.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        if target is None:
            return 0.0
        if target.state.cap.has_content_region:
            return target.state.cur.content_pos.y
        if target.state.cap.has_position:
            return target.state.cur.pos_to_viewport.y
        return 0.0  # Fallback if no position or content region

    def __repr__(self):
        return "SelfY1()"
    
    def __str__(self):
        return "self.y1"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen, '_current_value': self._current_value})

cdef class SelfY2(baseSizing):
    """
    References the bottom y coordinate (y2) of the item using this sizing.

    y2 is the end of the children area of the item, if any.
    Else it is equal to y0 + height.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        if target is None:
            return 0.0
        if target.state.cap.has_content_region:
            return target.state.cur.content_pos.y + target.state.cur.content_region_size.y
        if target.state.cap.has_position:
            if not target.state.cap.has_rect_size:
                return target.state.cur.pos_to_viewport.y
            return target.state.cur.pos_to_viewport.y + target.state.cur.rect_size.y
        return 0.0  # Fallback if no position or content region

    def __repr__(self):
        return "SelfY2()"
    
    def __str__(self):
        return "self.y2"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen, '_current_value': self._current_value})

cdef class SelfY3(baseSizing):
    """
    References the bottom-most y coordinate (y3) of the item using this sizing.
    This is equivalent to y0 + height.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        if target is None:
            return 0.0
        if target.state.cap.has_position and target.state.cap.has_rect_size:
            return target.state.cur.pos_to_viewport.y + target.state.cur.rect_size.y
        if target.state.cap.has_content_region:
            return target.state.cur.content_pos.y + target.state.cur.content_region_size.y
        if target.state.cap.has_position:
            return target.state.cur.pos_to_viewport.y
        return 0.0  # Fallback if no position or content region

    def __repr__(self):
        return "SelfY3()"
    
    def __str__(self):
        return "self.y3"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen, '_current_value': self._current_value})

cdef class SelfYC(baseSizing):
    """
    References the y center coordinate of the item using this sizing.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        if target is None:
            return 0.0
        if target.state.cap.has_content_region:
            return target.state.cur.content_pos.y + (target.state.cur.content_region_size.y * 0.5)
        if target.state.cap.has_position:
            if not target.state.cap.has_rect_size:
                return target.state.cur.pos_to_viewport.y
            return target.state.cur.pos_to_viewport.y + (target.state.cur.rect_size.y * 0.5)
        return 0.0  # Fallback if no position or content region

    def __repr__(self):
        return "SelfYC()"
    
    def __str__(self):
        return "self.yc"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen, '_current_value': self._current_value})

cdef class ThemeStyleSize(baseSizing):
    """
    References an theme style value.
    """
    cdef int32_t _style_idx
    cdef bint _use_y_component
    
    def __cinit__(self, int32_t style_idx, bint use_y_component=False):
        self._style_idx = style_idx
        self._use_y_component = use_y_component
        
    cdef float _update_value(self, uiItem target) noexcept nogil:
        if self._use_y_component:
            return get_theme_style_vec2(target.context, self._style_idx).y
        else:
            return get_theme_style_float(target.context, self._style_idx)

    def _get_style_name(self) -> str:
        """
        Retrieve the original style name
        """
        for item in list(ImGuiStyleIndex):
            if int(item) == self._style_idx:
                return item.name.lower()
        return "unknown" # fallback

    def __repr__(self):
        return f"ThemeStyleSize({self._style_idx}, {self._use_y_component})"
    
    def __str__(self):
        cdef str component = ".y" if self._use_y_component else ".x"
        return f"theme.{self._get_style_name()}{component}"
        
    def __reduce__(self):
        return (self.__class__, (self._style_idx, self._use_y_component), 
                {'_frozen': self._frozen, '_current_value': self._current_value})

cdef class ViewportHeight(baseSizing):
    """
    References the viewport's height.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        cdef Vec2 size = target.context.viewport.get_size()
        return size.y

    def __repr__(self):
        return "ViewportHeight()"
    
    def __str__(self):
        return "viewport.height"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen, '_current_value': self._current_value})

cdef class ViewportWidth(baseSizing):
    """
    References the viewport's width.
    """
    cdef float _update_value(self, uiItem target) noexcept nogil:
        cdef Vec2 size = target.context.viewport.get_size()
        return size.x

    def __repr__(self):
        return "ViewportWidth()"
    
    def __str__(self):
        return "viewport.width"
        
    def __reduce__(self):
        return (self.__class__, (), {'_frozen': self._frozen, '_current_value': self._current_value})


cdef extern from * namespace "DearCyGui" nogil:
    """
    #include <cstdlib> // atof
    namespace DearCyGui {
        // Token types represent the different kinds of tokens that can appear in a sizing expression
        enum class TokenType {
            NONE,           // Invalid or unrecognized token
            NUMBER,         // Numeric literal (e.g. "123", "45.67")
            IDENTIFIER,     // Named identifier (variable name, keyword)
            PLUS,           // Addition operator '+'
            MINUS,          // Subtraction operator '-'
            MULTIPLY,       // Multiplication operator '*'
            DIVIDE,         // Division operator '/'
            FLOORDIV,       // Floor division operator '//'
            MODULO,         // Modulo operator '%'
            POWER,          // Power operator '**'
            LPAREN,         // Left parenthesis '('
            RPAREN,         // Right parenthesis ')'
            COMMA,          // Comma separator ','
            IDENT_WIDTH,    // Identifier with '.width' suffix, storing just the identifier part
            IDENT_HEIGHT,   // Identifier with '.height' suffix, storing just the identifier part
            IDENT_X0,       // Identifier with '.x0' suffix (left-most x coordinate)
            IDENT_X1,       // Identifier with '.x1' suffix (left x coordinate)
            IDENT_X2,       // Identifier with '.x2' suffix (right x coordinate)
            IDENT_X3,       // Identifier with '.x3' suffix (right-most x coordinate)
            IDENT_Y0,       // Identifier with '.y0' suffix (top-most y coordinate)
            IDENT_Y1,       // Identifier with '.y1' suffix (top y coordinate)
            IDENT_Y2,       // Identifier with '.y2' suffix (bottom y coordinate)
            IDENT_Y3,       // Identifier with '.y3' suffix (right-most x coordinate)
            IDENT_XC,       // Identifier with '.xc' suffix (x center coordinate)
            IDENT_YC,       // Identifier with '.yc' suffix (y center coordinate)
            IDENT_THEME_STYLE,   // Identifier with 'theme.' prefix, followed by a style name
            IDENT_THEME_STYLE_X, // Identifier with 'theme.' prefix, followed by a style name and .x suffix
            IDENT_THEME_STYLE_Y, // Identifier with 'theme.' prefix, followed by a style name and .y suffix
            END_STRING      // End of input marker
        };
        
        // Keywords are specific identifiers with predefined meanings
        enum class KeywordType {
            NONE,           // Not a keyword
            DPI,            // Device pixel ratio / global scale
            SELF,           // Reference to the current item
            MIN,            // Minimum function
            MAX,            // Maximum function
            ABS,            // Absolute value function
            MEAN,           // Mean function (average)
            FILLX,          // Fill available width
            FILLY,          // Fill available height
            FULLX,          // Full parent width (no position offset)
            FULLY,          // Full parent height (no position offset)
            PARENT_HEIGHT,  // Reference to parent's height
            PARENT_WIDTH,   // Reference to parent's width
            PARENT_X0,      // Reference to parent's outer left x coordinate
            PARENT_X1,      // Reference to parent's content left x coordinate
            PARENT_X2,      // Reference to parent's content right x coordinate
            PARENT_X3,      // Reference to parent's outer right x coordinate
            PARENT_XC,      // Reference to parent's content x center coordinate
            PARENT_Y0,      // Reference to parent's outer top y coordinate
            PARENT_Y1,      // Reference to parent's content top y coordinate
            PARENT_Y2,      // Reference to parent's content bottom y coordinate
            PARENT_Y3,      // Reference to parent's outer bottom y coordinate
            PARENT_YC,      // Reference to parent's content y center coordinate
            SELF_HEIGHT,    // Reference to current item's height (self.height)
            SELF_WIDTH,     // Reference to current item's width (self.width)
            SELF_X0,        // Reference to current item's outer left x coordinate
            SELF_X1,        // Reference to current item's content left x coordinate
            SELF_X2,        // Reference to current item's content right x coordinate
            SELF_X3,        // Reference to current item's outer right x coordinate
            SELF_XC,        // Reference to current item's content x center coordinate
            SELF_Y0,        // Reference to current item's outer top y coordinate
            SELF_Y1,        // Reference to current item's content top y coordinate
            SELF_Y2,        // Reference to current item's content bottom y coordinate
            SELF_YC,        // Reference to current item's content y center coordinate
            SELF_Y3,        // Reference to current item's outer bottom y coordinate
            THEME,          // Theme style reference (e.g. "theme.item_spacing")
            VIEWPORT_HEIGHT,// Reference to viewport's height
            VIEWPORT_WIDTH, // Reference to viewport's width
        };

        // Token structure representing a single token in the input
        struct Token {
            TokenType type;             // Type of token
            std::string value;          // String value (also identifier for IDENT_WIDTH/HEIGHT)
            KeywordType keyword;        // Keyword type if this is a recognized keyword
        };

        // Tokenizer class that converts input string to a sequence of tokens
        class Tokenizer {
        private:
            std::string source;         // Source text being tokenized
            size_t position;            // Current position in the source
            
            // Check if a character is a digit (0-9)
            bool isDigit(char c) const {
                return c >= '0' && c <= '9';
            }
            
            // Check if a character is a letter or underscore (a-z, A-Z, _)
            bool isAlpha(char c) const {
                return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
            }
            
            // Skip any whitespace characters
            void skipWhitespace() {
                while (position < source.size()) {
                    char c = source[position];
                    if (c == ' ' || c == '\\t' || c == '\\r' || c == '\\n') {
                        position++;
                    } else {
                        break;
                    }
                }
            }
            
            // Check if a string is a known keyword and return its type
            KeywordType getKeywordType(const std::string& id) const {
                if (id == "fillx") return KeywordType::FILLX;
                if (id == "filly") return KeywordType::FILLY;
                if (id == "fullx") return KeywordType::FULLX;
                if (id == "fully") return KeywordType::FULLY;
                if (id == "dpi") return KeywordType::DPI;
                if (id == "self") return KeywordType::SELF;
                if (id == "min") return KeywordType::MIN;
                if (id == "max") return KeywordType::MAX;
                if (id == "abs") return KeywordType::ABS;
                if (id == "mean") return KeywordType::MEAN;
                if (id == "self.width") return KeywordType::SELF_WIDTH;
                if (id == "self.height") return KeywordType::SELF_HEIGHT;
                if (id == "self.x0") return KeywordType::SELF_X0;
                if (id == "self.x1") return KeywordType::SELF_X1;
                if (id == "self.x2") return KeywordType::SELF_X2;
                if (id == "self.x3") return KeywordType::SELF_X3;
                if (id == "self.y0") return KeywordType::SELF_Y0;
                if (id == "self.y1") return KeywordType::SELF_Y1;
                if (id == "self.y2") return KeywordType::SELF_Y2;
                if (id == "self.y3") return KeywordType::SELF_Y3;
                if (id == "self.xc") return KeywordType::SELF_XC;
                if (id == "self.yc") return KeywordType::SELF_YC;
                if (id == "parent.width") return KeywordType::PARENT_WIDTH;
                if (id == "parent.height") return KeywordType::PARENT_HEIGHT;
                if (id == "parent.x0") return KeywordType::PARENT_X0;
                if (id == "parent.x1") return KeywordType::PARENT_X1;
                if (id == "parent.x2") return KeywordType::PARENT_X2;
                if (id == "parent.x3") return KeywordType::PARENT_X3;
                if (id == "parent.y0") return KeywordType::PARENT_Y0;
                if (id == "parent.y1") return KeywordType::PARENT_Y1;
                if (id == "parent.y2") return KeywordType::PARENT_Y2;
                if (id == "parent.y3") return KeywordType::PARENT_Y3;
                if (id == "parent.xc") return KeywordType::PARENT_XC;
                if (id == "parent.yc") return KeywordType::PARENT_YC;
                if (id == "viewport.width") return KeywordType::VIEWPORT_WIDTH;
                if (id == "viewport.height") return KeywordType::VIEWPORT_HEIGHT;
                if (id == "theme") return KeywordType::THEME;
                
                return KeywordType::NONE;
            }
            
            // Check if a string ends with a given suffix
            bool endsWith(const std::string& str, const std::string& suffix) const {
                if (str.length() < suffix.length()) return false;
                return str.substr(str.length() - suffix.length()) == suffix;
            }

            // Check if we've reached the end of the input
            bool isAtEnd() const {
                return position >= source.size();
            }
            
            // Look at the current character without consuming it
            char peek() const {
                if (isAtEnd()) return '\\0';
                return source[position];
            }

            // Look at the next character without consuming it
            char peekNext() const {
                if (position + 1 >= source.size()) return '\\0';
                return source[position + 1];
            }
            
            // Consume and return the current character
            char advance() {
                if (isAtEnd()) return '\\0';
                return source[position++];
            }
            
        public:
            // Constructor initializes the tokenizer with input text
            Tokenizer(const std::string& input) : source(input), position(0) {}
            
            // Scan and return the next token from the input
            Token scanToken() {
                // Skip any leading whitespace
                skipWhitespace();
                
                // Check for end of input
                if (isAtEnd()) {
                    return {TokenType::END_STRING, "", KeywordType::NONE};
                }
                
                char c = advance();
                
                // Handle multi-character operators and single character tokens
                if (c == '+') return {TokenType::PLUS, "+", KeywordType::NONE};
                if (c == '-') return {TokenType::MINUS, "-", KeywordType::NONE};
                if (c == '*') {
                    // Check for power operator '**'
                    if (peek() == '*') {
                        advance(); // Consume second '*'
                        return {TokenType::POWER, "**", KeywordType::NONE};
                    }
                    return {TokenType::MULTIPLY, "*", KeywordType::NONE};
                }
                if (c == '/') {
                    // Check for floor division operator '//'
                    if (peek() == '/') {
                        advance(); // Consume second '/'
                        return {TokenType::FLOORDIV, "//", KeywordType::NONE};
                    }
                    return {TokenType::DIVIDE, "/", KeywordType::NONE};
                }
                if (c == '%') return {TokenType::MODULO, "%", KeywordType::NONE};
                if (c == '(') return {TokenType::LPAREN, "(", KeywordType::NONE};
                if (c == ')') return {TokenType::RPAREN, ")", KeywordType::NONE};
                if (c == ',') return {TokenType::COMMA, ",", KeywordType::NONE};
                
                // Handle numbers (integers or floating point)
                if (isDigit(c) || c == '.') {
                    size_t start = position - 1;
                    // Continue reading digits and decimal point
                    while (isDigit(peek()) || peek() == '.') {
                        advance();
                    }
                    
                    std::string value = source.substr(start, position - start);
                    return {TokenType::NUMBER, value, KeywordType::NONE};
                }
                
                // Handle identifiers, keywords, and property access patterns
                if (isAlpha(c)) {
                    size_t start = position - 1;
                    // Continue reading identifier characters and dots
                    while (isAlpha(peek()) || isDigit(peek()) || peek() == '.') {
                        advance();
                    }
                    
                    std::string value = source.substr(start, position - start);
                    KeywordType keyword = getKeywordType(value);

                    // Handle theme.style_name pattern
                    if (value.length() > 6 && value.substr(0, 6) == "theme.") {
                        std::string style_name = value.substr(6); // Remove "theme." prefix
                        
                        // Check for .x or .y suffix
                        if (endsWith(style_name, ".x")) {
                            std::string style = style_name.substr(0, style_name.length() - 2); // Remove ".x"
                            return {TokenType::IDENT_THEME_STYLE_X, style, KeywordType::NONE};
                        }
                        else if (endsWith(style_name, ".y")) {
                            std::string style = style_name.substr(0, style_name.length() - 2); // Remove ".y"
                            return {TokenType::IDENT_THEME_STYLE_Y, style, KeywordType::NONE};
                        }
                        else {
                            // No suffix - default to .x component
                            return {TokenType::IDENT_THEME_STYLE, style_name, KeywordType::NONE};
                        }
                    }
                    
                    // Handle special cases for self properties
                    if (keyword == KeywordType::SELF_WIDTH || 
                        keyword == KeywordType::SELF_HEIGHT ||
                        keyword == KeywordType::SELF_X0 ||
                        keyword == KeywordType::SELF_X1 ||
                        keyword == KeywordType::SELF_X2 ||
                        keyword == KeywordType::SELF_X3 ||
                        keyword == KeywordType::SELF_Y0 ||
                        keyword == KeywordType::SELF_Y1 ||
                        keyword == KeywordType::SELF_Y2 ||
                        keyword == KeywordType::SELF_Y3 ||
                        keyword == KeywordType::SELF_XC ||
                        keyword == KeywordType::SELF_YC ||
                        keyword == KeywordType::PARENT_WIDTH ||
                        keyword == KeywordType::PARENT_HEIGHT ||
                        keyword == KeywordType::PARENT_X0 ||
                        keyword == KeywordType::PARENT_X1 ||
                        keyword == KeywordType::PARENT_X2 ||
                        keyword == KeywordType::PARENT_X3 ||
                        keyword == KeywordType::PARENT_Y0 ||
                        keyword == KeywordType::PARENT_Y1 ||
                        keyword == KeywordType::PARENT_Y2 ||
                        keyword == KeywordType::PARENT_Y3 ||
                        keyword == KeywordType::PARENT_XC ||
                        keyword == KeywordType::PARENT_YC ||
                        keyword == KeywordType::VIEWPORT_WIDTH ||
                        keyword == KeywordType::VIEWPORT_HEIGHT) {
                        return {TokenType::IDENTIFIER, value, keyword};
                    }
                    // For item.width patterns, extract the item name only
                    else if (endsWith(value, ".width")) {
                        std::string ident = value.substr(0, value.length() - 6); // remove ".width"
                        return {TokenType::IDENT_WIDTH, ident, KeywordType::NONE};
                    }
                    // For item.height patterns, extract the item name only
                    else if (endsWith(value, ".height")) {
                        std::string ident = value.substr(0, value.length() - 7); // remove ".height"
                        return {TokenType::IDENT_HEIGHT, ident, KeywordType::NONE};
                    }
                    // For item.x1, item.x2, item.y1, item.y2 patterns
                    else if (endsWith(value, ".x0")) {
                        std::string ident = value.substr(0, value.length() - 3); // remove ".x0"
                        return {TokenType::IDENT_X0, ident, KeywordType::NONE};
                    }
                    else if (endsWith(value, ".x1")) {
                        std::string ident = value.substr(0, value.length() - 3); // remove ".x1"
                        return {TokenType::IDENT_X1, ident, KeywordType::NONE};
                    }
                    else if (endsWith(value, ".x2")) {
                        std::string ident = value.substr(0, value.length() - 3); // remove ".x2"
                        return {TokenType::IDENT_X2, ident, KeywordType::NONE};
                    }
                    else if (endsWith(value, ".x3")) {
                        std::string ident = value.substr(0, value.length() - 3); // remove ".x2"
                        return {TokenType::IDENT_X3, ident, KeywordType::NONE};
                    }
                    else if (endsWith(value, ".y0")) {
                        std::string ident = value.substr(0, value.length() - 3); // remove ".y0"
                        return {TokenType::IDENT_Y0, ident, KeywordType::NONE};
                    }
                    else if (endsWith(value, ".y1")) {
                        std::string ident = value.substr(0, value.length() - 3); // remove ".y1"
                        return {TokenType::IDENT_Y1, ident, KeywordType::NONE};
                    }
                    else if (endsWith(value, ".y2")) {
                        std::string ident = value.substr(0, value.length() - 3); // remove ".y2"
                        return {TokenType::IDENT_Y2, ident, KeywordType::NONE};
                    }
                    else if (endsWith(value, ".y3")) {
                        std::string ident = value.substr(0, value.length() - 3); // remove ".y2"
                        return {TokenType::IDENT_Y3, ident, KeywordType::NONE};
                    }
                    // For item.xc, item.yc patterns (center coordinates)
                    else if (endsWith(value, ".xc")) {
                        std::string ident = value.substr(0, value.length() - 3); // remove ".xc"
                        return {TokenType::IDENT_XC, ident, KeywordType::NONE};
                    }
                    else if (endsWith(value, ".yc")) {
                        std::string ident = value.substr(0, value.length() - 3); // remove ".yc"
                        return {TokenType::IDENT_YC, ident, KeywordType::NONE};
                    }
                    else {
                        return {TokenType::IDENTIFIER, value, keyword};
                    }
                }
                
                // Unknown or invalid token
                return {TokenType::NONE, std::string(1, c), KeywordType::NONE};
            }
            
            // Tokenize the entire input string into a vector of tokens
            std::vector<Token> tokenize() {
                std::vector<Token> tokens;
                while (!isAtEnd()) {
                    Token token = scanToken();
                    if (token.type == TokenType::NONE) {
                        // Skip invalid tokens
                        continue;
                    }
                    tokens.push_back(token);
                    
                    if (token.type == TokenType::END_STRING) {
                        break;
                    }
                }
                return tokens;
            }
        };
        
        // Helper function to tokenize a string - this avoids direct instantiation of Tokenizer
        std::vector<Token> tokenizeString(const std::string& input) {
            Tokenizer tokenizer(input);
            return tokenizer.tokenize();
        }
        
        // Helper functions for parsing operations
        
        // Convert a string to a float
        float parseFloat(const std::string& str) {
            return atof(str.c_str());
        }
    }
    """
    # C++ enum definitions
    enum class TokenType:
        NONE
        NUMBER
        IDENTIFIER
        PLUS
        MINUS
        MULTIPLY
        DIVIDE
        FLOORDIV
        MODULO
        POWER
        LPAREN
        RPAREN
        COMMA
        IDENT_WIDTH
        IDENT_HEIGHT
        IDENT_X0
        IDENT_X1
        IDENT_X2
        IDENT_X3
        IDENT_Y0
        IDENT_Y1
        IDENT_Y2
        IDENT_Y3
        IDENT_XC
        IDENT_YC
        IDENT_THEME_STYLE
        IDENT_THEME_STYLE_X
        IDENT_THEME_STYLE_Y
        END_STRING
    
    enum class KeywordType:
        NONE
        DPI
        SELF
        MIN
        MAX
        ABS
        MEAN
        FILLX
        FILLY
        FULLX
        FULLY
        PARENT_HEIGHT
        PARENT_WIDTH
        PARENT_X0
        PARENT_X1
        PARENT_X2
        PARENT_X3
        PARENT_XC
        PARENT_Y0
        PARENT_Y1
        PARENT_Y2
        PARENT_Y3
        PARENT_YC
        SELF_HEIGHT
        SELF_WIDTH
        SELF_X0
        SELF_X1
        SELF_X2
        SELF_X3
        SELF_XC
        SELF_Y0
        SELF_Y1
        SELF_Y2
        SELF_Y3
        SELF_YC
        THEME
        VIEWPORT_HEIGHT
        VIEWPORT_WIDTH

    # C++ struct definitions
    struct Token:
        TokenType type
        string value
        KeywordType keyword
    
    # Helper functions
    vector[Token] tokenizeString(const string& value)
    float parseFloat(const string& value)

cdef class CythonParser:
    """
    Parser for sizing expressions that builds a sizing object tree
    from a tokenized expression.
    """
    # Token stream and current position
    cdef vector[Token] tokens
    cdef size_t position
    cdef dict scope
    
    def __cinit__(self, str expr):
        """
        Initialize the parser with an expression string.
        
        Args:
            expr (str): The expression to parse, e.g., "0.8*fillx - 10"
        """
        # Pass the input string directly to C++ tokenizeString function
        cdef string input_str = expr.encode('utf-8')
        
        # Use the C++ helper function to get tokens
        self.tokens = tokenizeString(input_str)

        # Look for identifiers in the global scope if needed
        cdef int i
        cdef bint identifier_found = False
        for i in range(<int>self.tokens.size()):
            if self.tokens[i].type in [
                TokenType.IDENT_WIDTH,
                TokenType.IDENT_HEIGHT,
                TokenType.IDENT_X0,
                TokenType.IDENT_X1,
                TokenType.IDENT_X2,
                TokenType.IDENT_X3,
                TokenType.IDENT_Y0,
                TokenType.IDENT_Y1,
                TokenType.IDENT_Y2,
                TokenType.IDENT_Y3,
                TokenType.IDENT_XC,
                TokenType.IDENT_YC]:
                identifier_found = True
                break

        if identifier_found:
            frame = inspect.currentframe()
            caller_globals = frame.f_globals
            caller_locals = frame.f_locals
            self.scope = {**caller_globals, **caller_locals}

        self.position = 0
        
    cdef Token peek(self) noexcept nogil:
        """
        Return the current token without consuming it.
        
        Returns:
            Token: The current token or an END_STRING token if at the end
        """
        cdef Token es_token
        if self.position >= self.tokens.size():
            # Return END_STRING token if we're past the end
            es_token.type = TokenType.END_STRING
            return es_token
        return self.tokens[self.position]
        
    cdef Token advance(self) noexcept nogil:
        """
        Consume and return the current token, advancing to the next one.
        
        Returns:
            Token: The current token before advancing
        """
        cdef Token token = self.peek()
        if self.position < self.tokens.size():
            self.position += 1
        return token
        
    cdef bint check(self, TokenType type) noexcept nogil:
        """
        Check if the current token is of the given type without consuming it.
        
        Args:
            type (TokenType): The type to check against
            
        Returns:
            bool: True if the current token matches, False otherwise
        """
        if self.is_at_end():
            return False
        return self.peek().type == type
        
    cdef bint match(self, TokenType type) noexcept nogil:
        """
        Check if the current token is of the given type, and if so, consume it.
        
        Args:
            type (TokenType): The type to match
            
        Returns:
            bool: True if a match was found and consumed, False otherwise
        """
        if self.check(type):
            self.advance()
            return True
        return False
        
    cdef bint is_at_end(self) noexcept nogil:
        """
        Check if we've reached the end of the token stream.
        
        Returns:
            bool: True if at the end, False otherwise
        """
        return self.position >= self.tokens.size() or self.peek().type == TokenType.END_STRING
        
    cdef str get_token_value(self, Token token):
        """
        Get the string value of a token.
        
        Args:
            token (Token): The token to get the value from
            
        Returns:
            str: The token's value as a Python string
        """
        return token.value.decode('utf-8')
        
    cdef float token_to_float(self, Token token) noexcept nogil:
        """
        Convert a token's value to a float.
        
        Args:
            token (Token): The token to convert
            
        Returns:
            float: The token's value as a floating point number
        """
        return parseFloat(token.value)
        
    cdef object find_item_in_scope(self, str name):
        """
        Find a UI item in the current scope by name.
        
        Args:
            name (str): The name of the item to find
            
        Returns:
            uiItem: The found item
            
        Raises:
            ValueError: If item is not found or is not a UI item
        """
        cdef object item = self.scope.get(name, None)
        
        # If still not found, raise an error
        if item is None:
            raise ValueError(f"Item reference '{name}' not found in current scope")
        
        # Check if it's actually a UI item
        if not isinstance(item, uiItem):
            raise ValueError(f"'{name}' is not a UI item")
            
        return item
            
    cdef baseSizing parse(self):
        """
        Parse the entire expression.
            
        Returns:
            baseSizing: The root of the parsed expression tree
            
        Raises:
            ValueError: If the expression is empty or has trailing tokens
        """
        # Check for empty expression
        if self.is_at_end():
            raise ValueError("Empty expression")
        
        # Parse the expression
        cdef baseSizing result = self.parse_expression()
        
        # Ensure we consumed all tokens
        if not self.is_at_end():
            raise ValueError(f"Unexpected tokens at end: {self.get_token_value(self.peek())}")
            
        return result
        
    cdef baseSizing parse_expression(self):
        """
        Parse an expression (sum or difference of terms).
        Expression -> Term ([+-] Term)*
            
        Returns:
            baseSizing: The parsed expression
        """
        cdef baseSizing left
        cdef TokenType op_type
        cdef baseSizing right
        
        # Parse the first term
        left = self.parse_term()
        
        # Process any following +/- operators
        while self.check(TokenType.PLUS) or self.check(TokenType.MINUS):
            op_type = self.peek().type
            self.advance()  # Manually advance after confirming the token
            right = self.parse_term()
            
            # Create the appropriate binary operation
            if op_type == TokenType.PLUS:
                left = AddSize(left, right)
            elif op_type == TokenType.MINUS:
                left = SubtractSize(left, right)
        
        return left
        
    cdef baseSizing parse_term(self):
        """
        Parse a term (product, division, floor division, or modulo of factors).
        Term -> Exponent ([*//%] Exponent)*
            
        Returns:
            baseSizing: The parsed term
        """
        cdef baseSizing left
        cdef TokenType op_type
        cdef baseSizing right
        
        # Parse the first exponent
        left = self.parse_exponent()
        
        # Process any following */÷//% operators
        while (self.check(TokenType.MULTIPLY) or self.check(TokenType.DIVIDE) or 
               self.check(TokenType.FLOORDIV) or self.check(TokenType.MODULO)):
            op_type = self.peek().type
            self.advance()  # Manually advance after confirming the token
            right = self.parse_exponent()
            
            # Create the appropriate binary operation
            if op_type == TokenType.MULTIPLY:
                left = MultiplySize(left, right)
            elif op_type == TokenType.DIVIDE:
                left = DivideSize(left, right)
            elif op_type == TokenType.FLOORDIV:
                left = FloorDivideSize(left, right)
            elif op_type == TokenType.MODULO:
                left = ModuloSize(left, right)
        
        return left
        
    cdef baseSizing parse_exponent(self):
        """
        Parse an exponentiation (base raised to a power).
        Exponent -> Unary (** Unary)*
            
        Returns:
            baseSizing: The parsed exponentiation
        """
        cdef baseSizing left
        cdef TokenType op_type
        cdef baseSizing right
        
        # Parse the first unary
        left = self.parse_unary()
        
        # Process any following ** operators
        while self.check(TokenType.POWER):
            op_type = self.peek().type
            self.advance()  # Manually advance after confirming the token
            right = self.parse_unary()
            
            # Create the appropriate binary operation
            left = PowerSize(left, right)
        
        return left
        
    cdef baseSizing parse_unary(self):
        """
        Parse a unary operation (negation or absolute value).
        Unary -> [-] Primary | abs(Primary)
            
        Returns:
            baseSizing: The parsed unary operation
        """
        cdef Token token
        cdef baseSizing expr
        
        # Handle negation
        if self.check(TokenType.MINUS):
            self.advance()  # Manually advance after confirming the token
            expr = self.parse_unary()
            return NegateSize(expr)
        
        # Handle absolute value - only consume IDENTIFIER if it's actually the abs keyword
        if (self.check(TokenType.IDENTIFIER) and self.peek().keyword == KeywordType.ABS):
            self.advance()  # Manually advance after confirming it's the abs keyword
            
            if not self.check(TokenType.LPAREN):
                raise ValueError("Expected '(' after 'abs'")
            self.advance()  # Consume the '(' token
            
            expr = self.parse_expression()
            
            if not self.check(TokenType.RPAREN):
                raise ValueError("Expected ')' after 'abs' expression")
            self.advance()  # Consume the ')' token
            
            return AbsoluteSize(expr)
        
        # Handle primary expressions
        return self.parse_primary()
        
    cdef list parse_arguments(self):
        """
        Parse a list of function arguments.
        Arguments -> Expression ("," Expression)*
        
        Returns:
            list: List of parsed expressions
        """
        cdef list args = []
        
        # Parse first argument
        args.append(self.parse_expression())
        
        # Parse any additional arguments
        while self.check(TokenType.COMMA):
            self.advance()  # Consume the comma
            args.append(self.parse_expression())
            
        return args
    
    cdef baseSizing parse_primary(self):
        """
        Parse a primary expression (number, identifier, or parenthesized expression).
        Primary -> NUMBER | IDENTIFIER | "(" Expression ")" | IDENT_WIDTH | IDENT_HEIGHT | IDENT_X0 | IDENT_X1 | IDENT_X2 | IDENT_X3| IDENT_Y0 | IDENT_Y1 | IDENT_Y2 | IDENT_Y3 | IDENT_XC | IDENT_YC
            
        Returns:
            baseSizing: The parsed primary expression
            
        Raises:
            ValueError: If the token is unexpected or invalid
        """
        cdef Token token
        cdef baseSizing expr
        cdef KeywordType keyword
        cdef str name
        cdef str item_name
        cdef object item
        cdef baseSizing left
        cdef baseSizing right
        cdef list args
        cdef baseSizing result
        cdef int i
        
        # Get the current token
        token = self.peek()
        
        # Handle numeric literals (e.g., 123.45)
        if token.type == TokenType.NUMBER:
            self.advance()  # Consume the number token
            return FixedSize(self.token_to_float(token))
            
        # Handle parenthesized expressions (e.g., (1 + 2))
        if token.type == TokenType.LPAREN:
            self.advance()  # Consume '('
            expr = self.parse_expression()
            
            # Ensure we have a matching closing parenthesis
            if not self.check(TokenType.RPAREN):
                raise ValueError("Missing closing parenthesis")
            self.advance()  # Consume ')'
                
            return expr
            
        # Handle item property references
        if token.type == TokenType.IDENT_WIDTH:
            self.advance()  # Consume the token
            item_name = self.get_token_value(token)
            item = self.find_item_in_scope(item_name)
            return RefWidth(item)
            
        if token.type == TokenType.IDENT_HEIGHT:
            self.advance()  # Consume the token
            item_name = self.get_token_value(token)
            item = self.find_item_in_scope(item_name)
            return RefHeight(item)

        # Handle the item property references
        if token.type == TokenType.IDENT_X0:
            self.advance()  # Consume the token
            item_name = self.get_token_value(token)
            item = self.find_item_in_scope(item_name)
            return RefX0(item)

        if token.type == TokenType.IDENT_X1:
            self.advance()  # Consume the token
            item_name = self.get_token_value(token)
            item = self.find_item_in_scope(item_name)
            return RefX1(item)
            
        if token.type == TokenType.IDENT_X2:
            self.advance()  # Consume the token
            item_name = self.get_token_value(token)
            item = self.find_item_in_scope(item_name)
            return RefX2(item)

        if token.type == TokenType.IDENT_X3:
            self.advance()  # Consume the token
            item_name = self.get_token_value(token)
            item = self.find_item_in_scope(item_name)
            return RefX3(item)

        if token.type == TokenType.IDENT_Y0:
            self.advance()  # Consume the token
            item_name = self.get_token_value(token)
            item = self.find_item_in_scope(item_name)
            return RefY0(item)
            
        if token.type == TokenType.IDENT_Y1:
            self.advance()  # Consume the token
            item_name = self.get_token_value(token)
            item = self.find_item_in_scope(item_name)
            return RefY1(item)
            
        if token.type == TokenType.IDENT_Y2:
            self.advance()  # Consume the token
            item_name = self.get_token_value(token)
            item = self.find_item_in_scope(item_name)
            return RefY2(item)

        if token.type == TokenType.IDENT_Y3:
            self.advance()  # Consume the token
            item_name = self.get_token_value(token)
            item = self.find_item_in_scope(item_name)
            return RefY3(item)
            
        # Handle new center coordinate references
        if token.type == TokenType.IDENT_XC:
            self.advance()  # Consume the token
            item_name = self.get_token_value(token)
            item = self.find_item_in_scope(item_name)
            return RefXC(item)
            
        if token.type == TokenType.IDENT_YC:
            self.advance()  # Consume the token
            item_name = self.get_token_value(token)
            item = self.find_item_in_scope(item_name)
            return RefYC(item)

        # Handle theme.style_name references
        if token.type == TokenType.IDENT_THEME_STYLE or token.type == TokenType.IDENT_THEME_STYLE_X:
            self.advance()  # Consume the token
            style_name = self.get_token_value(token).upper()
            try:
                style_idx = int(ImGuiStyleIndex[style_name])
            except KeyError:
                raise ValueError(f"Unknown theme style: '{style_name.lower()}'\n"\
                                  "Available styles: " +\
                                  ", ".join([e.name.lower() for e in list(ImGuiStyleIndex)]))
            return ThemeStyleSize(style_idx, False)  # x component (or scalar value)
            
        if token.type == TokenType.IDENT_THEME_STYLE_Y:
            self.advance()  # Consume the token
            style_name = self.get_token_value(token).upper()
            try:
                style_idx = int(ImGuiStyleIndex[style_name])
            except KeyError:
                raise ValueError(f"Unknown theme style: '{style_name.lower()}'\n"\
                                  "Available styles: " +\
                                  ", ".join([e.name.lower() for e in list(ImGuiStyleIndex)]))
            return ThemeStyleSize(style_idx, True)  # y component

        # Handle identifiers and keywords
        if token.type == TokenType.IDENTIFIER:
            keyword = token.keyword
            name = self.get_token_value(token)
            self.advance()  # Consume the identifier token
            
            # Process known keywords
            if keyword == KeywordType.FILLX:
                return FillSizeX()
            elif keyword == KeywordType.FILLY:
                return FillSizeY()
            elif keyword == KeywordType.FULLX:
                return FullSizeX()
            elif keyword == KeywordType.FULLY:
                return FullSizeY()
            elif keyword == KeywordType.DPI:
                return DPI()
            elif keyword == KeywordType.SELF_WIDTH:
                return SelfWidth()
            elif keyword == KeywordType.SELF_HEIGHT:
                return SelfHeight()
            elif keyword == KeywordType.SELF_X0:
                return SelfX0()
            elif keyword == KeywordType.SELF_X1:
                return SelfX1()
            elif keyword == KeywordType.SELF_X2:
                return SelfX2()
            elif keyword == KeywordType.SELF_X3:
                return SelfX3()
            elif keyword == KeywordType.SELF_Y0:
                return SelfY0()
            elif keyword == KeywordType.SELF_Y1:
                return SelfY1()
            elif keyword == KeywordType.SELF_Y2:
                return SelfY2()
            elif keyword == KeywordType.SELF_Y3:
                return SelfY3()
            elif keyword == KeywordType.SELF_XC:
                return SelfXC()
            elif keyword == KeywordType.SELF_YC:
                return SelfYC()
            elif keyword == KeywordType.PARENT_WIDTH:
                return ParentWidth()
            elif keyword == KeywordType.PARENT_HEIGHT:
                return ParentHeight()
            elif keyword == KeywordType.PARENT_X0:
                return ParentX0()
            elif keyword == KeywordType.PARENT_X1:
                return ParentX1()
            elif keyword == KeywordType.PARENT_X2:
                return ParentX2()
            elif keyword == KeywordType.PARENT_X3:
                return ParentX3()
            elif keyword == KeywordType.PARENT_Y0:
                return ParentY0()
            elif keyword == KeywordType.PARENT_Y1:
                return ParentY1()
            elif keyword == KeywordType.PARENT_Y2:
                return ParentY2()
            elif keyword == KeywordType.PARENT_Y3:
                return ParentY3()
            elif keyword == KeywordType.PARENT_XC:
                return ParentXC()
            elif keyword == KeywordType.PARENT_YC:
                return ParentYC()
            elif keyword == KeywordType.VIEWPORT_WIDTH:
                return ViewportWidth()
            elif keyword == KeywordType.VIEWPORT_HEIGHT:
                return ViewportHeight()
            
            # Handle function calls (min/max/mean)
            elif keyword == KeywordType.MIN or keyword == KeywordType.MAX or keyword == KeywordType.MEAN:
                # Check for opening parenthesis
                if not self.check(TokenType.LPAREN):
                    if keyword == KeywordType.MIN:
                        raise ValueError("Expected '(' after 'min'")
                    elif keyword == KeywordType.MAX:
                        raise ValueError("Expected '(' after 'max'")
                    else:
                        raise ValueError("Expected '(' after 'mean'")
                self.advance()  # Consume the '(' token

                # Parse arguments
                args = self.parse_arguments()
                
                # Check we have at least two arguments
                if len(args) < 2:
                    if keyword == KeywordType.MIN:
                        raise ValueError("min() function requires at least two arguments")
                    elif keyword == KeywordType.MAX:
                        raise ValueError("max() function requires at least two arguments")
                    else:
                        raise ValueError("mean() function requires at least two arguments")
                
                # Check for closing parenthesis
                if not self.check(TokenType.RPAREN):
                    if keyword == KeywordType.MIN:
                        raise ValueError("Expected ')' to close min() function")
                    elif keyword == KeywordType.MAX:
                        raise ValueError("Expected ')' to close max() function")
                    else:
                        raise ValueError("Expected ')' to close mean() function")
                self.advance()  # Consume the ')' token
                
                # Build the expression
                if keyword == KeywordType.MIN:
                    # For min, we create nested MinSize objects
                    result = MinSize(args[0], args[1])
                    for i in range(2, len(args)):
                        result = MinSize(result, args[i])
                    return result
                elif keyword == KeywordType.MAX:
                    # For max, we create nested MaxSize objects
                    result = MaxSize(args[0], args[1])
                    for i in range(2, len(args)):
                        result = MaxSize(result, args[i])
                    return result
                else:  # MEAN
                    # For mean, we sum all arguments and divide by count
                    # First, sum all arguments using AddSize
                    result = args[0]
                    for i in range(1, len(args)):
                        result = AddSize(result, args[i])
                    
                    # Then divide by number of arguments to get the mean
                    return DivideSize(result, FixedSize(float(len(args))))
                    
            else:
                # Provide more informative error message for unknown identifiers
                raise ValueError(f"Unknown keyword or identifier: '{name}' (keyword type: {keyword})")
        
        # If we get here, the token is unexpected - improve error message to be more informative
        if token.type == TokenType.END_STRING:
            raise ValueError("Unexpected end of expression")
        else:
            token_value = self.get_token_value(token) if self.position < self.tokens.size() else ""
            raise ValueError(f"Unexpected token: '{token_value}' (type: {token.type})")

cpdef baseSizing parse_size(str size_str):
    """
    Parse a sizing string into sizing objects
    
    Args:
        size_str: String expression

    Examples:
        "0.8*fillx-4": MultiplySize(FillSizeX(), 0.8) - FixedSize(4)
        "min(0.8*filly, 100)": MinSize(MultiplySize(FillSizeY(), 0.8), FixedSize(100))
        "0.5*self.width": MultiplySize(SelfWidth(), 0.5)
        "0.7*self.height": MultiplySize(SelfHeight(), 0.7)
        "400*dpi": MultiplySize(DPI(), 400)
        "0.8*my_button.width": MultiplySize(RefWidth(my_button), 0.8)

    The following keywords are supported:
    - `fillx`: Fill available width
    - `filly`: Fill available height
    - `fullx`: Full parent content width (no position offset)
    - `fully`: Full parent content height (no position offset)
    - `parent.width`: Width of the parent item (larger than fullx as contains parent borders)
    - `parent.height`: Height of the parent item (larger than fully as contains parent borders)
    - `viewport.width`: Width of the viewport (application window)
    - `viewport.height`: Height of the viewport (application window)
    - `min`: Take minimum of two size values
    - `max`: Take maximum of two size values
    - `mean`: Calculate the mean (average) of two or more size values
    - `dpi`: Current global scale factor
    - `self.width`: Reference to the width of the current item
    - `self.height`: Reference to the height of the current item
    - `item.width`/`item.height`: Reference to another item's size (item must be in globals()/locals())
    - `{self, parent, item}.{x0, x1, x2, x3, xc, y0, y1, y2, y3, yc}`:
            Reference to left/center/right/top/bottom of the current, parent, or a target item.
            x0: left-most position
            x1: left position (=left-most if does not accept children. left of children area else)
            x2: right position (=right-most if does not accept children. right of children area else)
            x3: right-most position (right edge of the item, including borders)
            For most items, x0 == x1 and x2 == x3. width = x3 - x0.
            Same for y0, y1, y2, y3 (top-most/top/bottom/bottom-most)
    - `+`, `-`, `*`, `/`, `//`, `%`, `**`: Arithmetic operators. Parentheses can be used for grouping.
    - `abs()`: Absolute value function
    - Numbers: Fixed size in pixels (NOT dpi scaled. Use dpi keyword for that)

    Returns:
        A baseSizing object
        
    Raises:
        ValueError: If the expression is empty or invalid
    """
    if not size_str:
        raise ValueError("Empty expression")
    
    # Use the C++ based parser for all expressions
    cdef CythonParser parser = CythonParser(size_str)
    return parser.parse()

# Python-friendly factory API
class Size:
    """
    Factory for creating size descriptors that can be used with width/height properties.
    
    This class provides a clean, user-friendly API for programmatically constructing
    sizing expressions without needing to directly instantiate the underlying sizing classes.
    
    Examples:
        # Fixed size of 100 pixels
        Size.FIXED(100)
        
        # Fill available space
        Size.FILL()
        
        # 80% of available width
        0.8 * Size.FILL())
        
        # Minimum of 50% of parent width and 300 pixels
        Size.MIN(0.5 * Size.FILL(), 300)
        
        # Get current DPI scale
        Size.DPI()
        
        # 500 pixels scaled by DPI
        500 * Size.DPI()
        
        # Reference another item's size
        Size.RELATIVE(my_button)
    """
    
    @staticmethod
    def FIXED(value: float):
        """
        Create a fixed size in pixels.
        
        Args:
            value (float): Size in pixels
            
        Returns:
            FixedSize: Fixed size object
        """
        return FixedSize(value)

    @staticmethod
    def FILLX():
        """
        Create a size that fills the available width.
        
        Returns:
            FillSizeX: Fill size object
        """
        return FillSizeX()

    @staticmethod
    def FILLY():
        """
        Create a size that fills the available height.
        
        Returns:
            FillSizeY: Fill size object
        """
        return FillSizeY()

    @staticmethod
    def FULLX():
        """
        Create a size that uses the full parent width (without position offset).
        
        Returns:
            FullSizeX: Full size object
        """
        return FullSizeX()

    @staticmethod
    def FULLY():
        """
        Create a size that uses the full parent height (without position offset).
        
        Returns:
            FullSizeY: Full size object
        """
        return FullSizeY()

    @staticmethod
    def DPI():
        """
        Create a size that resolves to the current DPI scale factor.
        
        Returns:
            DPI: DPI scale object
        """
        return DPI()

    @staticmethod
    def RELATIVEX(item: uiItem):
        """
        Create a size relative to another item's width.

        Args:
            item (uiItem): The reference item
            
        Returns:
            baseSizing: Size object relative to the reference item's width
        """
        return RefWidth(item)

    @staticmethod
    def RELATIVEY(item: uiItem):
        """
        Create a size relative to another item's height.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            baseSizing: Size object relative to the reference item's height
        """
        return RefHeight(item)

    @staticmethod
    def PARENT_WIDTH():
        """
        Create a size that references the parent's width.
        
        Returns:
            ParentWidth: Size object referencing the parent's width
        """
        return ParentWidth()
    
    @staticmethod
    def PARENT_HEIGHT():
        """
        Create a size that references the parent's height.
        
        Returns:
            ParentHeight: Size object referencing the parent's height
        """
        return ParentHeight()
    
    @staticmethod
    def PARENT_X0():
        """
        Create a size that references the parent's outer left x coordinate.
        This refers to the actual position of the parent item, not accounting for padding.
        
        Returns:
            ParentX0: Size object referencing the parent's outer x position
        """
        return ParentX0()
    
    @staticmethod
    def PARENT_X1():
        """
        Create a size that references the parent's content left x coordinate.
        This is the left edge of the parent's content area, accounting for padding.
        
        Returns:
            ParentX1: Size object referencing the parent's content x1
        """
        return ParentX1()
    
    @staticmethod
    def PARENT_X2():
        """
        Create a size that references the parent's content right x coordinate.
        This is the right edge of the parent's content area, accounting for padding.
        
        Returns:
            ParentX2: Size object referencing the parent's content x2
        """
        return ParentX2()
    
    @staticmethod
    def PARENT_Y0():
        """
        Create a size that references the parent's outer top y coordinate.
        This refers to the actual position of the parent item, not accounting for padding.
        
        Returns:
            ParentY0: Size object referencing the parent's outer y position
        """
        return ParentY0()
    
    @staticmethod
    def PARENT_Y1():
        """
        Create a size that references the parent's content top y coordinate.
        This is the top edge of the parent's content area, accounting for padding.
        
        Returns:
            ParentY1: Size object referencing the parent's content y1
        """
        return ParentY1()
    
    @staticmethod
    def PARENT_Y2():
        """
        Create a size that references the parent's content bottom y coordinate.
        This is the bottom edge of the parent's content area, accounting for padding.
        
        Returns:
            ParentY2: Size object referencing the parent's content y2
        """
        return ParentY2()
    
    @staticmethod
    def PARENT_XC():
        """
        Create a size that references the parent's content x center coordinate.
        This is the horizontal center of the parent's content area.
        
        Returns:
            ParentXC: Size object referencing the parent's content x center
        """
        return ParentXC()
    
    @staticmethod
    def PARENT_YC():
        """
        Create a size that references the parent's content y center coordinate.
        This is the vertical center of the parent's content area.
        
        Returns:
            ParentYC: Size object referencing the parent's content y center
        """
        return ParentYC()

    @staticmethod
    def SELF_WIDTH():
        """
        Create a size relative to the item's own width.
            
        Returns:
            baseSizing: Size object relative to the item's own width
        """
        return SelfWidth()
    
    @staticmethod
    def SELF_HEIGHT():
        """
        Create a size relative to the item's own height.
            
        Returns:
            baseSizing: Size object relative to the item's own height
        """
        return SelfHeight()

    @staticmethod
    def VIEWPORT_WIDTH():
        """
        Create a size that references the viewport's width.
        
        Returns:
            ViewportWidth: Size object referencing the viewport's width
        """
        return ViewportWidth()
    
    @staticmethod
    def VIEWPORT_HEIGHT():
        """
        Create a size that references the viewport's height.
        
        Returns:
            ViewportHeight: Size object referencing the viewport's height
        """
        return ViewportHeight()

    @staticmethod
    def MIN(first, second, *args):
        """
        Take minimum of two or more size values.
        
        Args:
            first: First size value (can be a number or baseSizing object)
            second: Second size value (can be a number or baseSizing object)
            *args: Additional size values to include in the minimum
            
        Returns:
            baseSizing: Minimum size object
        """
        first = baseSizing.Size(first)
        second = baseSizing.Size(second)
            
        result = MinSize(first, second)
        
        # Handle additional arguments
        for arg in args:
            result = MinSize(result, baseSizing.Size(arg))
            
        return result
    
    @staticmethod
    def MAX(first, second, *args):
        """
        Take maximum of two or more size values.
        
        Args:
            first: First size value (can be a number or baseSizing object)
            second: Second size value (can be a number or baseSizing object)
            *args: Additional size values to include in the maximum
            
        Returns:
            baseSizing: Maximum size object
        """
        first = baseSizing.Size(first)
        second = baseSizing.Size(second)
            
        result = MaxSize(first, second)
        
        # Handle additional arguments
        for arg in args:
            result = MaxSize(result, baseSizing.Size(arg))
        return result
        
    @staticmethod
    def MEAN(first, second, *args):
        """
        Calculate the mean (average) of two or more size values.
        
        Args:
            first: First size value (can be a number or baseSizing object)
            second: Second size value (can be a number or baseSizing object)
            *args: Additional size values to include in the average
            
        Returns:
            baseSizing: Mean of the size values
        """
        first = baseSizing.Size(first)
        second = baseSizing.Size(second)
        
        # Start with the sum of the first two arguments
        result = AddSize(first, second)
        
        # Add any additional arguments
        for arg in args:
            result = AddSize(result, baseSizing.Size(arg))
        
        # Divide by the total number of arguments to get the mean
        return DivideSize(result, FixedSize(float(2 + len(args))))
        
    @staticmethod
    def ADD(first, second, *args):
        """
        Add two or more size values.
        
        Args:
            first: First size value (can be a number or baseSizing object)
            second: Second size value (can be a number or baseSizing object)
            *args: Additional size values to add
            
        Returns:
            baseSizing: Sum of the size values
        """
        first = baseSizing.Size(first)
        second = baseSizing.Size(second)
            
        result = AddSize(first, second)
        
        # Handle additional arguments
        for arg in args:
            result = AddSize(result, baseSizing.Size(arg))
            
        return result
        
    @staticmethod
    def SUBTRACT(minuend, subtrahend):
        """
        Subtract one size value from another.
        
        Args:
            minuend: Size value to subtract from (can be a number or baseSizing object)
            subtrahend: Size value to subtract (can be a number or baseSizing object)
            
        Returns:
            baseSizing: Difference of the size values
        """
        minuend = baseSizing.Size(minuend)
        subtrahend = baseSizing.Size(subtrahend)
            
        return SubtractSize(minuend, subtrahend)
        
    @staticmethod
    def MULTIPLY(first, second):
        """
        Multiply two size values.
        
        Args:
            first: First size value (can be a number or baseSizing object)
            second: Second size value (can be a number or baseSizing object)
            
        Returns:
            baseSizing: Product of the size values
        """
        first = baseSizing.Size(first)
        second = baseSizing.Size(second)
            
        return MultiplySize(first, second)
        
    @staticmethod
    def DIVIDE(dividend, divisor):
        """
        Divide one size value by another.
        
        Args:
            dividend: Size value to divide (can be a number or baseSizing object)
            divisor: Size value to divide by (can be a number or baseSizing object)
            
        Returns:
            baseSizing: Quotient of the size values
        """
        dividend = baseSizing.Size(dividend)
        divisor = baseSizing.Size(divisor)
            
        return DivideSize(dividend, divisor)
        
    @staticmethod
    def FLOOR_DIVIDE(dividend, divisor):
        """
        Floor divide one size value by another.
        
        Args:
            dividend: Size value to divide (can be a number or baseSizing object)
            divisor: Size value to divide by (can be a number or baseSizing object)
            
        Returns:
            baseSizing: Floor quotient of the size values
        """
        dividend = baseSizing.Size(dividend)
        divisor = baseSizing.Size(divisor)
            
        return FloorDivideSize(dividend, divisor)
        
    @staticmethod
    def MODULO(dividend, divisor):
        """
        Calculate the remainder when dividing one size by another.
        
        Args:
            dividend: Size value to divide (can be a number or baseSizing object)
            divisor: Size value to divide by (can be a number or baseSizing object)
            
        Returns:
            baseSizing: Remainder of the division
        """
        dividend = baseSizing.Size(dividend)
        divisor = baseSizing.Size(divisor)
            
        return ModuloSize(dividend, divisor)
        
    @staticmethod
    def POWER(base, exponent):
        """
        Raise a size value to a power.
        
        Args:
            base: Base size value (can be a number or baseSizing object)
            exponent: Exponent to raise to (can be a number or baseSizing object)
            
        Returns:
            baseSizing: Base raised to the exponent
        """
        base = baseSizing.Size(base)
        exponent = baseSizing.Size(exponent)
            
        return PowerSize(base, exponent)
        
    @staticmethod
    def NEGATE(value):
        """
        Negate a size value.
        
        Args:
            value: Size value to negate (can be a number or baseSizing object)
            
        Returns:
            baseSizing: Negated size value
        """ 
        return NegateSize(baseSizing.Size(value))
        
    @staticmethod
    def ABS(value):
        """
        Get the absolute value of a size.
        
        Args:
            value: Size value (can be a number or baseSizing object)
            
        Returns:
            baseSizing: Absolute size value
        """
        return AbsoluteSize(baseSizing.Size(value))
        
    @staticmethod
    def from_expression(expr: str):
        """
        Create a size object from a string expression.
        
        This is an alias for parse_size().
        
        Args:
            expr (str): String expression to parse
            
        Returns:
            baseSizing: Parsed size object
            
        Raises:
            ValueError: If the expression is empty or invalid
        """
        return parse_size(expr)

    @staticmethod
    def SELF_X0():
        """
        Create a size that references the item's own outer left x coordinate (x0).
        This is the actual position of the item, not accounting for content area padding.
        
        Returns:
            SelfX0: Size object referencing the item's outer x position
        """
        return SelfX0()
    
    @staticmethod
    def SELF_X1():
        """
        Create a size that references the item's own content left x coordinate (x1).
        This is the left edge of the item's content area, accounting for padding if available.
        If the item has no content area, this is equivalent to x0.
        
        Returns:
            SelfX1: Size object referencing the item's content x1
        """
        return SelfX1()
    
    @staticmethod
    def SELF_X2():
        """
        Create a size that references the item's own content right x coordinate (x2).
        This is the right edge of the item's content area, accounting for padding if available.
        If the item has no content area, this is equivalent to x0 + width.
        
        Returns:
            SelfX2: Size object referencing the item's content x2
        """
        return SelfX2()
    
    @staticmethod
    def SELF_Y0():
        """
        Create a size that references the item's own outer top y coordinate (y0).
        This is the actual position of the item, not accounting for content area padding.
        
        Returns:
            SelfY0: Size object referencing the item's outer y position
        """
        return SelfY0()
    
    @staticmethod
    def SELF_Y1():
        """
        Create a size that references the item's own content top y coordinate (y1).
        This is the top edge of the item's content area, accounting for padding if available.
        If the item has no content area, this is equivalent to y0.
        
        Returns:
            SelfY1: Size object referencing the item's content y1
        """
        return SelfY1()
    
    @staticmethod
    def SELF_Y2():
        """
        Create a size that references the item's own content bottom y coordinate (y2).
        This is the bottom edge of the item's content area, accounting for padding if available.
        If the item has no content area, this is equivalent to y0 + height.
        
        Returns:
            SelfY2: Size object referencing the item's content y2
        """
        return SelfY2()

    @staticmethod
    def RELATIVE_X0(item: uiItem):
        """
        Create a size relative to another item's outer left x coordinate (x0).
        This is the actual position of the item, not accounting for content area padding.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            RefX0: Size object relative to the reference item's outer x position
        """
        return RefX0(item)

    @staticmethod
    def RELATIVE_X1(item: uiItem):
        """
        Create a size relative to another item's content left x coordinate (x1).
        This is the left edge of the item's content area, accounting for padding if available.
        If the item has no content area, this is equivalent to x0.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            RefX1: Size object relative to the reference item's content x1
        """
        return RefX1(item)

    @staticmethod
    def RELATIVE_X2(item: uiItem):
        """
        Create a size relative to another item's content right x coordinate (x2).
        This is the right edge of the item's content area, accounting for padding if available.
        If the item has no content area, this is equivalent to x0 + width.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            RefX2: Size object relative to the reference item's content x2
        """
        return RefX2(item)

    @staticmethod
    def RELATIVE_Y0(item: uiItem):
        """
        Create a size relative to another item's outer top y coordinate (y0).
        This is the actual position of the item, not accounting for content area padding.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            RefY0: Size object relative to the reference item's outer y position
        """
        return RefY0(item)

    @staticmethod
    def RELATIVE_Y1(item: uiItem):
        """
        Create a size relative to another item's content top y coordinate (y1).
        This is the top edge of the item's content area, accounting for padding if available.
        If the item has no content area, this is equivalent to y0.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            RefY1: Size object relative to the reference item's content y1
        """
        return RefY1(item)

    @staticmethod
    def RELATIVE_Y2(item: uiItem):
        """
        Create a size relative to another item's content bottom y coordinate (y2).
        This is the bottom edge of the item's content area, accounting for padding if available.
        If the item has no content area, this is equivalent to y0 + height.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            RefY2: Size object relative to the reference item's content y2
        """
        return RefY2(item)

    @staticmethod
    def SELF_XC():
        """
        Create a size that references the item's own x center coordinate.
        
        Returns:
            SelfXC: Size object referencing the item's x center
        """
        return SelfXC()
    
    @staticmethod
    def SELF_YC():
        """
        Create a size that references the item's own y center coordinate.
        
        Returns:
            SelfYC: Size object referencing the item's y center
        """
        return SelfYC()

    @staticmethod
    def RELATIVE_XC(item: uiItem):
        """
        Create a size relative to another item's x center coordinate.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            RefXC: Size object relative to the reference item's x center
        """
        return RefXC(item)

    @staticmethod
    def RELATIVE_YC(item: uiItem):
        """
        Create a size relative to another item's y center coordinate.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            RefYC: Size object relative to the reference item's y center
        """
        return RefYC(item)

    @staticmethod
    def THEME_STYLE(style_name, use_y_component=False):
        """
        Create a size that references an ImGui style value.
        
        Args:
            style_name (str): Name of the ImGui style (case insensitive)
            use_y_component (bool): Whether to use the Y component for Vec2 styles
            
        Returns:
            ThemeStyleSize: Size object referencing the theme style
            
        Examples:
            Size.THEME_STYLE("item_spacing")     # X component by default
            Size.THEME_STYLE("item_spacing", True) # Y component
        """
        style_name = style_name.upper()
        try:
            style_idx = int(ImGuiStyleIndex[style_name])
        except KeyError:
            raise ValueError(f"Unknown theme style: '{style_name.lower()}'\n"\
                              "Available styles: " +\
                              ", ".join([e.name.lower() for e in list(ImGuiStyleIndex)]))
        return ThemeStyleSize(style_idx, use_y_component)

# Define a shorter alias for the Size factory
Sz = Size