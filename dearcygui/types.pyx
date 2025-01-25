cimport cython
from dearcygui.wrapper cimport imgui

from enum import IntFlag, IntEnum




@cython.freelist(8)
cdef class Coord:
    """
    Fast writable 2D coordinate tuple (x, y) which supports a lot of operations.
    Provides various arithmetic operations and properties for easy manipulation.
    """
    #def __cinit__(self): Commented as trivial. Commenting enables auto-generated __reduce__
    #    self._x = 0
    #    self._y = 0

    def __init__(self, double x = 0., double y = 0.):
        self._x = x
        self._y = y

    @property
    def x(self):
        """Coordinate on the horizontal axis"""
        return self._x

    @property
    def y(self):
        """Coordinate on the vertical axis"""
        return self._y

    @x.setter
    def x(self, value):
        self._x = value

    @y.setter
    def y(self, value):
        self._y = value

    def __len__(self):
        return 2

    def __getitem__(self, key):
        cdef int32_t index
        if isinstance(key, int):
            index = <int>key
            if index == 0:
                return self._x
            if index == 1:
                return self._y
        elif isinstance(key, str):
            if key == "x":
                return self._x
            if key == "y":
                return self._y
        raise IndexError(f"Invalid key: {key}")

    def __setitem__(self, key, value):
        cdef int32_t index
        if isinstance(key, int):
            index = <int>key
            if index == 0:
                self._x = <double>value
                return
            if index == 1:
                self._y = <double>value
                return
        elif isinstance(key, str):
            if key == "x":
                self._x = <double>value
                return
            if key == "y":
                self._y = <double>value
                return
        raise IndexError(f"Invalid key: {key}")

    def __add__(self, other):
        cdef double[2] other_coord
        try:
            read_coord(other_coord, other)
        except TypeError:
            return NotImplemented
        other_coord[0] += self._x
        other_coord[1] += self._y
        return Coord.build(other_coord)

    def __radd__(self, other):
        cdef double[2] other_coord
        try:
            read_coord(other_coord, other)
        except TypeError:
            return NotImplemented
        other_coord[0] += self._x
        other_coord[1] += self._y
        return Coord.build(other_coord)

    def __iadd__(self, other):
        cdef double[2] other_coord
        try:
            read_coord(other_coord, other)
        except TypeError:
            return NotImplemented
        self._x += other_coord[0]
        self._y += other_coord[1]
        return self

    def __sub__(self, other):
        cdef double[2] other_coord
        try:
            read_coord(other_coord, other)
        except TypeError:
            return NotImplemented
        other_coord[0] -= self._x
        other_coord[1] -= self._y
        return Coord.build(other_coord)

    def __rsub__(self, other):
        cdef double[2] other_coord
        try:
            read_coord(other_coord, other)
        except TypeError:
            return NotImplemented
        other_coord[0] -= self._x
        other_coord[1] -= self._y
        return Coord.build(other_coord)

    def __isub__(self, other):
        cdef double[2] other_coord
        try:
            read_coord(other_coord, other)
        except TypeError:
            return NotImplemented
        self._x -= other_coord[0]
        self._y -= other_coord[1]
        return self

    def __mul__(self, other):
        cdef double[2] other_coord
        if hasattr(other, '__len__'):
            try:
                read_coord(other_coord, other)
            except TypeError:
                return NotImplemented
        else:
            # scalar
            other_coord[0] = other
            other_coord[1] = other
        other_coord[0] *= self._x
        other_coord[1] *= self._y
        return Coord.build(other_coord)

    def __rmul__(self, other):
        cdef double[2] other_coord
        if hasattr(other, '__len__'):
            try:
                read_coord(other_coord, other)
            except TypeError:
                return NotImplemented
        else:
            # scalar
            other_coord[0] = other
            other_coord[1] = other
        other_coord[0] *= self._x
        other_coord[1] *= self._y
        return Coord.build(other_coord)

    def __imul__(self, other):
        cdef double[2] other_coord
        if hasattr(other, '__len__'):
            try:
                read_coord(other_coord, other)
            except TypeError:
                return NotImplemented
            self._x *= other_coord[0]
            self._y *= other_coord[1]
        else:
            # scalar
            other_coord[0] = other 
            self._x *= other_coord[0]
            self._y *= other_coord[0]
        return self

    def __truediv__(self, other):
        cdef double[2] other_coord
        if hasattr(other, '__len__'):
            try:
                read_coord(other_coord, other)
            except TypeError:
                return NotImplemented
        else:
            # scalar
            other_coord[0] = other
            other_coord[1] = other
        other_coord[0] = self._x / other_coord[0]
        other_coord[1] = self._y / other_coord[1]
        return Coord.build(other_coord)

    def __rtruediv__(self, other):
        cdef double[2] other_coord
        if hasattr(other, '__len__'):
            try:
                read_coord(other_coord, other)
            except TypeError:
                return NotImplemented
        else:
            # scalar
            other_coord[0] = other
            other_coord[1] = other
        other_coord[0] = other_coord[0] / self._x
        other_coord[1] = other_coord[1] / self._y
        return Coord.build(other_coord)

    def __itruediv__(self, other):
        cdef double[2] other_coord
        if hasattr(other, '__len__'):
            try:
                read_coord(other_coord, other)
            except TypeError:
                return NotImplemented
            self._x /= other_coord[0]
            self._y /= other_coord[1]
        else:
            # scalar
            other_coord[0] = other 
            self._x /= other_coord[0]
            self._y /= other_coord[0]
        return self

    def __neg__(self):
        cdef double[2] other_coord
        other_coord[0] = -self._x
        other_coord[1] = -self._y
        return Coord.build(other_coord)

    def __pos__(self):
        cdef double[2] other_coord
        other_coord[0] = self._x
        other_coord[1] = self._y
        return Coord.build(other_coord)

    def __abs__(self):
        cdef double[2] other_coord
        other_coord[0] = abs(self._x)
        other_coord[1] = abs(self._y)
        return Coord.build(other_coord)

    # lexicographic ordering
    def __lt__(self, other):
        cdef double[2] other_coord
        try:
            read_coord(other_coord, other)
        except TypeError:
            return NotImplemented
        if self._x < other_coord[0]:
            return True
        if self._x == other_coord[0] and self._y < other_coord[1]:
            return True
        return False

    def __le__(self, other):
        cdef double[2] other_coord
        try:
            read_coord(other_coord, other)
        except TypeError:
            return NotImplemented
        if self._x < other_coord[0]:
            return True
        if self._x == other_coord[0] and self._y <= other_coord[1]:
            return True
        return False

    def __eq__(self, other):
        cdef double[2] other_coord
        try:
            read_coord(other_coord, other)
        except TypeError:
            return NotImplemented
        return self._x == other_coord[0] and self._y == other_coord[1]

    def __ne__(self, other):
        cdef double[2] other_coord
        try:
            read_coord(other_coord, other)
        except TypeError:
            return NotImplemented
        return self._x != other_coord[0] or self._y != other_coord[1]

    def __gt__(self, other):
        cdef double[2] other_coord
        try:
            read_coord(other_coord, other)
        except TypeError:
            return NotImplemented
        if self._x > other_coord[0]:
            return True
        if self._x == other_coord[0] and self._y > other_coord[1]:
            return True
        return False

    def __ge__(self, other):
        cdef double[2] other_coord
        try:
            read_coord(other_coord, other)
        except TypeError:
            return NotImplemented
        if self._x > other_coord[0]:
            return True
        if self._x == other_coord[0] and self._y >= other_coord[1]:
            return True
        return False

    def __hash__(self):
        return hash((self._x, self._y))

    def __bool__(self):
        return self._x == 0 and self._y == 0

    def __str__(self):
        return str((self._x, self._y))

    def __repr__(self):
        return f"Coord({self._x}, {self._y})"

    # Fast instanciation from Cython
    @staticmethod
    cdef Coord build(double[2] &coord):
        cdef Coord item = Coord.__new__(Coord)
        item._x = coord[0]
        item._y = coord[1]
        return item

    @staticmethod
    cdef Coord build_v(Vec2 &coord):
        cdef Coord item = Coord.__new__(Coord)
        item._x = coord.x
        item._y = coord.y
        return item

@cython.freelist(8)
cdef class Rect:
    """
    Fast writable rectangle class with diagonal points (x1,y1) and (x2,y2) which supports a lot of operations.
    Provides various arithmetic operations and properties for easy manipulation.
    """

    def __init__(self, double x1 = 0., double y1 = 0., double x2 = 0., double y2 = 0.):
        self._x1 = x1
        self._y1 = y1
        self._x2 = x2
        self._y2 = y2

    @property
    def xmin(self):
        """Left coordinate"""
        return min(self._x1, self._x2)

    @property
    def ymin(self):
        """Top coordinate"""
        return min(self._y1, self._y2)

    @property
    def xmax(self):
        """Right coordinate"""
        return max(self._x1, self._x2)

    @property
    def ymax(self):
        """Bottom coordinate"""
        return max(self._y1, self._y2)

    @property
    def x1(self):
        """Coordinate of the first corner point"""
        return self._x1

    @property
    def y1(self):
        """Coordinate of the first corner point"""
        return self._y1

    @property
    def x2(self):
        """Coordinate of the second corner point"""
        return self._x2

    @property
    def y2(self):
        """Coordinate of the second corner point"""
        return self._y2

    @property
    def w(self):
        """Width of rectangle"""
        return abs(self._x2 - self._x1)

    @property
    def h(self):
        """Height of rectangle"""
        return abs(self._y2 - self._y1)

    @property
    def p1(self):
        """Coord(x1,y1)"""
        cdef double[2] coord
        coord[0] = self._x1
        coord[1] = self._y1
        return Coord.build(coord)

    @property
    def p2(self):
        """Coord(x2,y2)"""
        cdef double[2] coord
        coord[0] = self._x2
        coord[1] = self._y2
        return Coord.build(coord)

    @property
    def pmin(self):
        """Coord(xmin,ymin)"""
        cdef double[2] coord
        coord[0] = min(self._x1, self._x2)
        coord[1] = min(self._y1, self._y2)
        return Coord.build(coord)

    @property
    def pmax(self):
        """Coord(xmax,ymax)"""
        cdef double[2] coord
        coord[0] = max(self._x1, self._x2)
        coord[1] = max(self._y1, self._y2)
        return Coord.build(coord)

    @property
    def center(self):
        """Center as Coord(x,y)"""
        cdef double[2] coord
        coord[0] = (self._x1 + self._x2) / 2
        coord[1] = (self._y1 + self._y2) / 2
        return Coord.build(coord)

    @property
    def size(self):
        """Size as Coord(w,h)"""
        cdef double[2] coord
        coord[0] = abs(self._x2 - self._x1)
        coord[1] = abs(self._y2 - self._y1)
        return Coord.build(coord)

    @x1.setter
    def x1(self, value):
        self._x1 = value

    @x2.setter
    def x2(self, value):
        self._x2 = value

    @y1.setter
    def y1(self, value):
        self._y1 = value

    @y2.setter
    def y2(self, value):
        self._y2 = value

    @center.setter
    def center(self, value):
        cdef double[2] coord
        read_coord(coord, value)
        cdef double w, h
        w = self._x2 - self._x1
        h = self._y2 - self._y1
        self._x1 = coord[0] - w / 2
        self._y1 = coord[1] - h / 2
        self._x2 = coord[0] + w / 2
        self._y2 = coord[1] + h / 2

    def __len__(self):
        return 4

    def __getitem__(self, key):
        cdef int32_t index
        if isinstance(key, int):
            index = <int>key
            if index == 0:
                return self._x1
            if index == 1:
                return self._y1
            if index == 2:
                return self._x2
            if index == 3:
                return self._y2
        elif isinstance(key, str):
            if key == "x1":
                return self._x1
            if key == "y1":
                return self._y1
            if key == "x2":
                return self._x2
            if key == "y2":
                return self._y2
        raise IndexError(f"Invalid key: {key}")

    def __setitem__(self, key, value):
        cdef int32_t index
        if isinstance(key, int):
            index = <int>key
            if index == 0:
                self._x1 = <double>value
                return
            if index == 1:
                self._y1 = <double>value
                return
            if index == 2:
                self._x2 = <double>value
                return
            if index == 3:
                self._y2 = <double>value
                return
        elif isinstance(key, str):
            if key == "x1":
                self._x1 = <double>value
                return
            if key == "y1":
                self._y1 = <double>value
                return
            if key == "x2":
                self._x2 = <double>value
                return
            if key == "y2":
                self._y2 = <double>value
                return
        raise IndexError(f"Invalid key: {key}")

    def __eq__(self, other):
        cdef double[4] other_rect
        try:
            read_rect(other_rect, other)
        except TypeError:
            return NotImplemented
        return (self._x1 == other_rect[0] and 
                self._y1 == other_rect[1] and
                self._x2 == other_rect[2] and
                self._y2 == other_rect[3])

    def __ne__(self, other):
        cdef double[4] other_rect
        try:
            read_rect(other_rect, other)
        except TypeError:
            return NotImplemented
        return (self._x1 != other_rect[0] or
                self._y1 != other_rect[1] or
                self._x2 != other_rect[2] or
                self._y2 != other_rect[3])

    def __hash__(self):
        return hash((self._x1, self._y1, self._x2, self._y2))

    def __bool__(self):
        return abs(self._x1 - self._x2) > 0 and abs(self._y1 - self._y2) > 0

    def __str__(self):
        return str((self._x1, self._y1, self._x2, self._y2))

    def __repr__(self):
        return f"Rect({self._x1}, {self._y1}, {self._x2}, {self._y2})"

    def __add__(self, other):
        cdef double[2] coord
        try:
            read_coord(coord, other)
        except TypeError:
            return NotImplemented
        cdef double[4] result
        result[0] = self._x1 + coord[0]
        result[1] = self._y1 + coord[1]
        result[2] = self._x2 + coord[0]
        result[3] = self._y2 + coord[1]
        return Rect.build(result)

    def __radd__(self, other):
        return self + other

    def __iadd__(self, other):
        cdef double[2] coord
        try:
            read_coord(coord, other)
        except TypeError:
            return NotImplemented
        self._x1 += coord[0]
        self._y1 += coord[1]
        self._x2 += coord[0]
        self._y2 += coord[1]
        return self

    def __sub__(self, other):
        cdef double[2] coord
        try:
            read_coord(coord, other)
        except TypeError:
            return NotImplemented
        cdef double[4] result
        result[0] = self._x1 - coord[0]
        result[1] = self._y1 - coord[1]
        result[2] = self._x2 - coord[0]
        result[3] = self._y2 - coord[1]
        return Rect.build(result)

    def __isub__(self, other):
        cdef double[2] coord
        try:
            read_coord(coord, other)
        except TypeError:
            return NotImplemented
        self._x1 -= coord[0]
        self._y1 -= coord[1]
        self._x2 -= coord[0]
        self._y2 -= coord[1]
        return self

    def __mul__(self, other):
        cdef double[2] coord
        if hasattr(other, '__len__'):
            try:
                read_coord(coord, other)
            except TypeError:
                return NotImplemented
        else:
            # scalar
            coord[0] = other
            coord[1] = other
        cdef double[4] result
        result[0] = self._x1 * coord[0]
        result[1] = self._y1 * coord[1]
        result[2] = self._x2 * coord[0]
        result[3] = self._y2 * coord[1]
        return Rect.build(result)

    def __rmul__(self, other):
        return self * other

    def __imul__(self, other):
        cdef double[2] coord
        if hasattr(other, '__len__'):
            try:
                read_coord(coord, other)
            except TypeError:
                return NotImplemented
        else:
            # scalar
            coord[0] = other
            coord[1] = other
        self._x1 *= coord[0]
        self._y1 *= coord[1]
        self._x2 *= coord[0]
        self._y2 *= coord[1]
        return self

    def __truediv__(self, other):
        cdef double[2] coord
        if hasattr(other, '__len__'):
            try:
                read_coord(coord, other)
            except TypeError:
                return NotImplemented
        else:
            # scalar
            coord[0] = other
            coord[1] = other
        cdef double[4] result
        result[0] = self._x1 / coord[0]
        result[1] = self._y1 / coord[1]
        result[2] = self._x2 / coord[0]
        result[3] = self._y2 / coord[1]
        return Rect.build(result)

    def __itruediv__(self, other):
        cdef double[2] coord
        if hasattr(other, '__len__'):
            try:
                read_coord(coord, other)
            except TypeError:
                return NotImplemented
        else:
            # scalar
            coord[0] = other
            coord[1] = other
        self._x1 /= coord[0]
        self._y1 /= coord[1]
        self._x2 /= coord[0]
        self._y2 /= coord[1]
        return self

    def __neg__(self):
        cdef double[4] result
        result[0] = -self._x1
        result[1] = -self._y1
        result[2] = -self._x2
        result[3] = -self._y2
        return Rect.build(result)

    def __pos__(self):
        cdef double[4] result
        result[0] = self._x1
        result[1] = self._y1
        result[2] = self._x2
        result[3] = self._y2
        return Rect.build(result)

    def __abs__(self):
        cdef double[4] result
        result[0] = abs(self._x1)
        result[1] = abs(self._y1)
        result[2] = abs(self._x2)
        result[3] = abs(self._y2)
        return Rect.build(result)

    def __contains__(self, point):
        cdef double[2] other_coord
        try:
            read_coord(other_coord, point)
        except TypeError:
            return NotImplemented
        cdef double xmin, ymin, xmax, ymax
        xmin = min(self._x1, self._x2)
        ymin = min(self._y1, self._y2)
        xmax = max(self._x1, self._x2)
        ymax = max(self._y1, self._y2)
        return xmin <= other_coord[0] <= xmax and ymin <= other_coord[1] <= ymax

    # Fast instanciation from Cython
    @staticmethod
    cdef Rect build(double[4] &rect):
        cdef Rect item = Rect.__new__(Rect)
        item._x1 = rect[0]
        item._y1 = rect[1]
        item._x2 = rect[2]
        item._y2 = rect[3]
        return item

class ChildType(IntFlag):
    """
    Enum representing different types of child elements that can be attached to items.
    """
    NOCHILD = 0,
    DRAWING = 1,
    HANDLER = 2,
    MENUBAR = 4,
    PLOTELEMENT = 8,
    TAB = 16,
    THEME = 32,
    VIEWPORTDRAWLIST = 64,
    WIDGET = 128,
    WINDOW = 256,
    AXISTAG = 512,

class Key(IntEnum):
    """
    Enum representing various keyboard keys.
    """
    TAB = imgui.ImGuiKey_Tab,
    LEFTARROW = imgui.ImGuiKey_LeftArrow,
    RIGHTARROW = imgui.ImGuiKey_RightArrow,
    UPARROW = imgui.ImGuiKey_UpArrow,
    DOWNARROW = imgui.ImGuiKey_DownArrow,
    PAGEUP = imgui.ImGuiKey_PageUp,
    PAGEDOWN = imgui.ImGuiKey_PageDown,
    HOME = imgui.ImGuiKey_Home,
    END = imgui.ImGuiKey_End,
    INSERT = imgui.ImGuiKey_Insert,
    DELETE = imgui.ImGuiKey_Delete,
    BACKSPACE = imgui.ImGuiKey_Backspace,
    SPACE = imgui.ImGuiKey_Space,
    ENTER = imgui.ImGuiKey_Enter,
    ESCAPE = imgui.ImGuiKey_Escape,
    LEFTCTRL = imgui.ImGuiKey_LeftCtrl,
    LEFTSHIFT = imgui.ImGuiKey_LeftShift,
    LEFTALT = imgui.ImGuiKey_LeftAlt,
    LEFTSUPER = imgui.ImGuiKey_LeftSuper,
    RIGHTCTRL = imgui.ImGuiKey_RightCtrl,
    RIGHTSHIFT = imgui.ImGuiKey_RightShift,
    RIGHTALT = imgui.ImGuiKey_RightAlt,
    RIGHTSUPER = imgui.ImGuiKey_RightSuper,
    MENU = imgui.ImGuiKey_Menu,
    ZERO = imgui.ImGuiKey_0,
    ONE = imgui.ImGuiKey_1,
    TWO = imgui.ImGuiKey_2,
    THREE = imgui.ImGuiKey_3,
    FOUR = imgui.ImGuiKey_4,
    FIVE = imgui.ImGuiKey_5,
    SIX = imgui.ImGuiKey_6,
    SEVEN = imgui.ImGuiKey_7,
    EIGHT = imgui.ImGuiKey_8,
    NINE = imgui.ImGuiKey_9,
    A = imgui.ImGuiKey_A,
    B = imgui.ImGuiKey_B,
    C = imgui.ImGuiKey_C,
    D = imgui.ImGuiKey_D,
    E = imgui.ImGuiKey_E,
    F = imgui.ImGuiKey_F,
    G = imgui.ImGuiKey_G,
    H = imgui.ImGuiKey_H,
    I = imgui.ImGuiKey_I,
    J = imgui.ImGuiKey_J,
    K = imgui.ImGuiKey_K,
    L = imgui.ImGuiKey_L,
    M = imgui.ImGuiKey_M,
    N = imgui.ImGuiKey_N,
    O = imgui.ImGuiKey_O,
    P = imgui.ImGuiKey_P,
    Q = imgui.ImGuiKey_Q,
    R = imgui.ImGuiKey_R,
    S = imgui.ImGuiKey_S,
    T = imgui.ImGuiKey_T,
    U = imgui.ImGuiKey_U,
    V = imgui.ImGuiKey_V,
    W = imgui.ImGuiKey_W,
    X = imgui.ImGuiKey_X,
    Y = imgui.ImGuiKey_Y,
    Z = imgui.ImGuiKey_Z,
    F1 = imgui.ImGuiKey_F1,
    F2 = imgui.ImGuiKey_F2,
    F3 = imgui.ImGuiKey_F3,
    F4 = imgui.ImGuiKey_F4,
    F5 = imgui.ImGuiKey_F5,
    F6 = imgui.ImGuiKey_F6,
    F7 = imgui.ImGuiKey_F7,
    F8 = imgui.ImGuiKey_F8,
    F9 = imgui.ImGuiKey_F9,
    F10 = imgui.ImGuiKey_F10,
    F11 = imgui.ImGuiKey_F11,
    F12 = imgui.ImGuiKey_F12,
    F13 = imgui.ImGuiKey_F13,
    F14 = imgui.ImGuiKey_F14,
    F15 = imgui.ImGuiKey_F15,
    F16 = imgui.ImGuiKey_F16,
    F17 = imgui.ImGuiKey_F17,
    F18 = imgui.ImGuiKey_F18,
    F19 = imgui.ImGuiKey_F19,
    F20 = imgui.ImGuiKey_F20,
    F21 = imgui.ImGuiKey_F21,
    F22 = imgui.ImGuiKey_F22,
    F23 = imgui.ImGuiKey_F23,
    F24 = imgui.ImGuiKey_F24,
    APOSTROPHE = imgui.ImGuiKey_Apostrophe,
    COMMA = imgui.ImGuiKey_Comma,
    MINUS = imgui.ImGuiKey_Minus,
    PERIOD = imgui.ImGuiKey_Period,
    SLASH = imgui.ImGuiKey_Slash,
    SEMICOLON = imgui.ImGuiKey_Semicolon,
    EQUAL = imgui.ImGuiKey_Equal,
    LEFTBRACKET = imgui.ImGuiKey_LeftBracket,
    BACKSLASH = imgui.ImGuiKey_Backslash,
    RIGHTBRACKET = imgui.ImGuiKey_RightBracket,
    GRAVEACCENT = imgui.ImGuiKey_GraveAccent,
    CAPSLOCK = imgui.ImGuiKey_CapsLock,
    SCROLLLOCK = imgui.ImGuiKey_ScrollLock,
    NUMLOCK = imgui.ImGuiKey_NumLock,
    PRINTSCREEN = imgui.ImGuiKey_PrintScreen,
    PAUSE = imgui.ImGuiKey_Pause,
    KEYPAD0 = imgui.ImGuiKey_Keypad0,
    KEYPAD1 = imgui.ImGuiKey_Keypad1,
    KEYPAD2 = imgui.ImGuiKey_Keypad2,
    KEYPAD3 = imgui.ImGuiKey_Keypad3,
    KEYPAD4 = imgui.ImGuiKey_Keypad4,
    KEYPAD5 = imgui.ImGuiKey_Keypad5,
    KEYPAD6 = imgui.ImGuiKey_Keypad6,
    KEYPAD7 = imgui.ImGuiKey_Keypad7,
    KEYPAD8 = imgui.ImGuiKey_Keypad8,
    KEYPAD9 = imgui.ImGuiKey_Keypad9,
    KEYPADDECIMAL = imgui.ImGuiKey_KeypadDecimal,
    KEYPADDIVIDE = imgui.ImGuiKey_KeypadDivide,
    KEYPADMULTIPLY = imgui.ImGuiKey_KeypadMultiply,
    KEYPADSUBTRACT = imgui.ImGuiKey_KeypadSubtract,
    KEYPADADD = imgui.ImGuiKey_KeypadAdd,
    KEYPADENTER = imgui.ImGuiKey_KeypadEnter,
    KEYPADEQUAL = imgui.ImGuiKey_KeypadEqual,
    APPBACK = imgui.ImGuiKey_AppBack,
    APPFORWARD = imgui.ImGuiKey_AppForward,
    GAMEPADSTART = imgui.ImGuiKey_GamepadStart,
    GAMEPADBACK = imgui.ImGuiKey_GamepadBack,
    GAMEPADFACELEFT = imgui.ImGuiKey_GamepadFaceLeft,
    GAMEPADFACERIGHT = imgui.ImGuiKey_GamepadFaceRight,
    GAMEPADFACEUP = imgui.ImGuiKey_GamepadFaceUp,
    GAMEPADFACEDOWN = imgui.ImGuiKey_GamepadFaceDown,
    GAMEPADDPADLEFT = imgui.ImGuiKey_GamepadDpadLeft,
    GAMEPADDPADRIGHT = imgui.ImGuiKey_GamepadDpadRight,
    GAMEPADDPADUP = imgui.ImGuiKey_GamepadDpadUp,
    GAMEPADDPADDOWN = imgui.ImGuiKey_GamepadDpadDown,
    GAMEPADL1 = imgui.ImGuiKey_GamepadL1,
    GAMEPADR1 = imgui.ImGuiKey_GamepadR1,
    GAMEPADL2 = imgui.ImGuiKey_GamepadL2,
    GAMEPADR2 = imgui.ImGuiKey_GamepadR2,
    GAMEPADL3 = imgui.ImGuiKey_GamepadL3,
    GAMEPADR3 = imgui.ImGuiKey_GamepadR3,
    GAMEPADLSTICKLEFT = imgui.ImGuiKey_GamepadLStickLeft,
    GAMEPADLSTICKRIGHT = imgui.ImGuiKey_GamepadLStickRight,
    GAMEPADLSTICKUP = imgui.ImGuiKey_GamepadLStickUp,
    GAMEPADLSTICKDOWN = imgui.ImGuiKey_GamepadLStickDown,
    GAMEPADRSTICKLEFT = imgui.ImGuiKey_GamepadRStickLeft,
    GAMEPADRSTICKRIGHT = imgui.ImGuiKey_GamepadRStickRight,
    GAMEPADRSTICKUP = imgui.ImGuiKey_GamepadRStickUp,
    GAMEPADRSTICKDOWN = imgui.ImGuiKey_GamepadRStickDown,
    MOUSELEFT = imgui.ImGuiKey_MouseLeft,
    MOUSERIGHT = imgui.ImGuiKey_MouseRight,
    MOUSEMIDDLE = imgui.ImGuiKey_MouseMiddle,
    MOUSEX1 = imgui.ImGuiKey_MouseX1,
    MOUSEX2 = imgui.ImGuiKey_MouseX2,
    MOUSEWHEELX = imgui.ImGuiKey_MouseWheelX,
    MOUSEWHEELY = imgui.ImGuiKey_MouseWheelY,
    RESERVEDFORMODCTRL = imgui.ImGuiKey_ReservedForModCtrl,
    RESERVEDFORMODSHIFT = imgui.ImGuiKey_ReservedForModShift,
    RESERVEDFORMODALT = imgui.ImGuiKey_ReservedForModAlt,
    RESERVEDFORMODSUPER = imgui.ImGuiKey_ReservedForModSuper

class KeyMod(IntFlag):
    """
    Enum representing key modifiers (Ctrl, Shift, Alt, Super).
    """
    NOMOD = 0,
    CTRL = imgui.ImGuiMod_Ctrl,
    SHIFT = imgui.ImGuiMod_Shift,
    ALT = imgui.ImGuiMod_Alt,
    SUPER = imgui.ImGuiMod_Super

class KeyOrMod(IntFlag):
    """
    Enum representing both keys and key modifiers.
    """
    NOMOD = 0,
    TAB = imgui.ImGuiKey_Tab,
    LEFTARROW = imgui.ImGuiKey_LeftArrow,
    RIGHTARROW = imgui.ImGuiKey_RightArrow,
    UPARROW = imgui.ImGuiKey_UpArrow,
    DOWNARROW = imgui.ImGuiKey_DownArrow,
    PAGEUP = imgui.ImGuiKey_PageUp,
    PAGEDOWN = imgui.ImGuiKey_PageDown,
    HOME = imgui.ImGuiKey_Home,
    END = imgui.ImGuiKey_End,
    INSERT = imgui.ImGuiKey_Insert,
    DELETE = imgui.ImGuiKey_Delete,
    BACKSPACE = imgui.ImGuiKey_Backspace,
    SPACE = imgui.ImGuiKey_Space,
    ENTER = imgui.ImGuiKey_Enter,
    ESCAPE = imgui.ImGuiKey_Escape,
    LEFTCTRL = imgui.ImGuiKey_LeftCtrl,
    LEFTSHIFT = imgui.ImGuiKey_LeftShift,
    LEFTALT = imgui.ImGuiKey_LeftAlt,
    LEFTSUPER = imgui.ImGuiKey_LeftSuper,
    RIGHTCTRL = imgui.ImGuiKey_RightCtrl,
    RIGHTSHIFT = imgui.ImGuiKey_RightShift,
    RIGHTALT = imgui.ImGuiKey_RightAlt,
    RIGHTSUPER = imgui.ImGuiKey_RightSuper,
    MENU = imgui.ImGuiKey_Menu,
    ZERO = imgui.ImGuiKey_0,
    ONE = imgui.ImGuiKey_1,
    TWO = imgui.ImGuiKey_2,
    THREE = imgui.ImGuiKey_3,
    FOUR = imgui.ImGuiKey_4,
    FIVE = imgui.ImGuiKey_5,
    SIX = imgui.ImGuiKey_6,
    SEVEN = imgui.ImGuiKey_7,
    EIGHT = imgui.ImGuiKey_8,
    NINE = imgui.ImGuiKey_9,
    A = imgui.ImGuiKey_A,
    B = imgui.ImGuiKey_B,
    C = imgui.ImGuiKey_C,
    D = imgui.ImGuiKey_D,
    E = imgui.ImGuiKey_E,
    F = imgui.ImGuiKey_F,
    G = imgui.ImGuiKey_G,
    H = imgui.ImGuiKey_H,
    I = imgui.ImGuiKey_I,
    J = imgui.ImGuiKey_J,
    K = imgui.ImGuiKey_K,
    L = imgui.ImGuiKey_L,
    M = imgui.ImGuiKey_M,
    N = imgui.ImGuiKey_N,
    O = imgui.ImGuiKey_O,
    P = imgui.ImGuiKey_P,
    Q = imgui.ImGuiKey_Q,
    R = imgui.ImGuiKey_R,
    S = imgui.ImGuiKey_S,
    T = imgui.ImGuiKey_T,
    U = imgui.ImGuiKey_U,
    V = imgui.ImGuiKey_V,
    W = imgui.ImGuiKey_W,
    X = imgui.ImGuiKey_X,
    Y = imgui.ImGuiKey_Y,
    Z = imgui.ImGuiKey_Z,
    F1 = imgui.ImGuiKey_F1,
    F2 = imgui.ImGuiKey_F2,
    F3 = imgui.ImGuiKey_F3,
    F4 = imgui.ImGuiKey_F4,
    F5 = imgui.ImGuiKey_F5,
    F6 = imgui.ImGuiKey_F6,
    F7 = imgui.ImGuiKey_F7,
    F8 = imgui.ImGuiKey_F8,
    F9 = imgui.ImGuiKey_F9,
    F10 = imgui.ImGuiKey_F10,
    F11 = imgui.ImGuiKey_F11,
    F12 = imgui.ImGuiKey_F12,
    F13 = imgui.ImGuiKey_F13,
    F14 = imgui.ImGuiKey_F14,
    F15 = imgui.ImGuiKey_F15,
    F16 = imgui.ImGuiKey_F16,
    F17 = imgui.ImGuiKey_F17,
    F18 = imgui.ImGuiKey_F18,
    F19 = imgui.ImGuiKey_F19,
    F20 = imgui.ImGuiKey_F20,
    F21 = imgui.ImGuiKey_F21,
    F22 = imgui.ImGuiKey_F22,
    F23 = imgui.ImGuiKey_F23,
    F24 = imgui.ImGuiKey_F24,
    APOSTROPHE = imgui.ImGuiKey_Apostrophe,
    COMMA = imgui.ImGuiKey_Comma,
    MINUS = imgui.ImGuiKey_Minus,
    PERIOD = imgui.ImGuiKey_Period,
    SLASH = imgui.ImGuiKey_Slash,
    SEMICOLON = imgui.ImGuiKey_Semicolon,
    EQUAL = imgui.ImGuiKey_Equal,
    LEFTBRACKET = imgui.ImGuiKey_LeftBracket,
    BACKSLASH = imgui.ImGuiKey_Backslash,
    RIGHTBRACKET = imgui.ImGuiKey_RightBracket,
    GRAVEACCENT = imgui.ImGuiKey_GraveAccent,
    CAPSLOCK = imgui.ImGuiKey_CapsLock,
    SCROLLLOCK = imgui.ImGuiKey_ScrollLock,
    NUMLOCK = imgui.ImGuiKey_NumLock,
    PRINTSCREEN = imgui.ImGuiKey_PrintScreen,
    PAUSE = imgui.ImGuiKey_Pause,
    KEYPAD0 = imgui.ImGuiKey_Keypad0,
    KEYPAD1 = imgui.ImGuiKey_Keypad1,
    KEYPAD2 = imgui.ImGuiKey_Keypad2,
    KEYPAD3 = imgui.ImGuiKey_Keypad3,
    KEYPAD4 = imgui.ImGuiKey_Keypad4,
    KEYPAD5 = imgui.ImGuiKey_Keypad5,
    KEYPAD6 = imgui.ImGuiKey_Keypad6,
    KEYPAD7 = imgui.ImGuiKey_Keypad7,
    KEYPAD8 = imgui.ImGuiKey_Keypad8,
    KEYPAD9 = imgui.ImGuiKey_Keypad9,
    KEYPADDECIMAL = imgui.ImGuiKey_KeypadDecimal,
    KEYPADDIVIDE = imgui.ImGuiKey_KeypadDivide,
    KEYPADMULTIPLY = imgui.ImGuiKey_KeypadMultiply,
    KEYPADSUBTRACT = imgui.ImGuiKey_KeypadSubtract,
    KEYPADADD = imgui.ImGuiKey_KeypadAdd,
    KEYPADENTER = imgui.ImGuiKey_KeypadEnter,
    KEYPADEQUAL = imgui.ImGuiKey_KeypadEqual,
    APPBACK = imgui.ImGuiKey_AppBack,
    APPFORWARD = imgui.ImGuiKey_AppForward,
    GAMEPADSTART = imgui.ImGuiKey_GamepadStart,
    GAMEPADBACK = imgui.ImGuiKey_GamepadBack,
    GAMEPADFACELEFT = imgui.ImGuiKey_GamepadFaceLeft,
    GAMEPADFACERIGHT = imgui.ImGuiKey_GamepadFaceRight,
    GAMEPADFACEUP = imgui.ImGuiKey_GamepadFaceUp,
    GAMEPADFACEDOWN = imgui.ImGuiKey_GamepadFaceDown,
    GAMEPADDPADLEFT = imgui.ImGuiKey_GamepadDpadLeft,
    GAMEPADDPADRIGHT = imgui.ImGuiKey_GamepadDpadRight,
    GAMEPADDPADUP = imgui.ImGuiKey_GamepadDpadUp,
    GAMEPADDPADDOWN = imgui.ImGuiKey_GamepadDpadDown,
    GAMEPADL1 = imgui.ImGuiKey_GamepadL1,
    GAMEPADR1 = imgui.ImGuiKey_GamepadR1,
    GAMEPADL2 = imgui.ImGuiKey_GamepadL2,
    GAMEPADR2 = imgui.ImGuiKey_GamepadR2,
    GAMEPADL3 = imgui.ImGuiKey_GamepadL3,
    GAMEPADR3 = imgui.ImGuiKey_GamepadR3,
    GAMEPADLSTICKLEFT = imgui.ImGuiKey_GamepadLStickLeft,
    GAMEPADLSTICKRIGHT = imgui.ImGuiKey_GamepadLStickRight,
    GAMEPADLSTICKUP = imgui.ImGuiKey_GamepadLStickUp,
    GAMEPADLSTICKDOWN = imgui.ImGuiKey_GamepadLStickDown,
    GAMEPADRSTICKLEFT = imgui.ImGuiKey_GamepadRStickLeft,
    GAMEPADRSTICKRIGHT = imgui.ImGuiKey_GamepadRStickRight,
    GAMEPADRSTICKUP = imgui.ImGuiKey_GamepadRStickUp,
    GAMEPADRSTICKDOWN = imgui.ImGuiKey_GamepadRStickDown,
    MOUSELEFT = imgui.ImGuiKey_MouseLeft,
    MOUSERIGHT = imgui.ImGuiKey_MouseRight,
    MOUSEMIDDLE = imgui.ImGuiKey_MouseMiddle,
    MOUSEX1 = imgui.ImGuiKey_MouseX1,
    MOUSEX2 = imgui.ImGuiKey_MouseX2,
    MOUSEWHEELX = imgui.ImGuiKey_MouseWheelX,
    MOUSEWHEELY = imgui.ImGuiKey_MouseWheelY,
    RESERVEDFORMODCTRL = imgui.ImGuiKey_ReservedForModCtrl,
    RESERVEDFORMODSHIFT = imgui.ImGuiKey_ReservedForModShift,
    RESERVEDFORMODALT = imgui.ImGuiKey_ReservedForModAlt,
    RESERVEDFORMODSUPER = imgui.ImGuiKey_ReservedForModSuper,
    CTRL = imgui.ImGuiMod_Ctrl,
    SHIFT = imgui.ImGuiMod_Shift,
    ALT = imgui.ImGuiMod_Alt,
    SUPER = imgui.ImGuiMod_Super

class TableFlag(IntFlag):
    """
    Flags for controlling table behavior and appearance.

    Features:
        NONE (0): No flags
        RESIZABLE: Enable resizing columns
        REORDERABLE: Enable reordering columns 
        HIDEABLE: Enable hiding/disabling columns
        SORTABLE: Enable sorting
        NO_SAVED_SETTINGS: Disable persisting columns order, width and sort settings
        CONTEXT_MENU_IN_BODY: Right-click on columns body/contents will display table context menu
    
    Decorations:
        ROW_BG: Set each RowBg color with alternating colors
        BORDERS_INNER_H: Draw horizontal borders between rows
        BORDERS_OUTER_H: Draw horizontal borders at the top and bottom
        BORDERS_INNER_V: Draw vertical borders between columns
        BORDERS_OUTER_V: Draw vertical borders on the left and right sides
        BORDERS_H: Draw all horizontal borders (inner + outer)
        BORDERS_V: Draw all vertical borders (inner + outer)
        BORDERS_INNER: Draw all inner borders
        BORDERS_OUTER: Draw all outer borders
        BORDERS: Draw all borders (inner + outer)
        NO_BORDERS_IN_BODY: Disable vertical borders in columns Body
        NO_BORDERS_IN_BODY_UNTIL_RESIZE: Disable vertical borders in columns Body until hovered for resize
    
    Sizing Policy:
        SIZING_FIXED_FIT: Columns default to _WidthFixed or _WidthAuto, matching contents width
        SIZING_FIXED_SAME: Columns default to _WidthFixed or _WidthAuto, matching the maximum contents width of all columns
        SIZING_STRETCH_PROP: Columns default to _WidthStretch with default weights proportional to each columns contents widths
        SIZING_STRETCH_SAME: Columns default to _WidthStretch with default weights all equal
    
    Sizing Extra Options:
        NO_HOST_EXTEND_X: Make outer width auto-fit to columns
        NO_HOST_EXTEND_Y: Make outer height stop exactly at outer_size.y
        NO_KEEP_COLUMNS_VISIBLE: Disable keeping column always minimally visible when ScrollX is off
        PRECISE_WIDTHS: Disable distributing remainder width to stretched columns 
    
    Clipping:
        NO_CLIP: Disable clipping rectangle for every individual column
    
    Padding:
        PAD_OUTER_X: Enable outermost padding
        NO_PAD_OUTER_X: Disable outermost padding
        NO_PAD_INNER_X: Disable inner padding between columns
    
    Scrolling:
        SCROLL_X: Enable horizontal scrolling
        SCROLL_Y: Enable vertical scrolling
    
    Sorting:
        SORT_MULTI: Hold shift when clicking headers to sort on multiple columns
        SORT_TRISTATE: Allow no sorting, disable default sorting
    
    Miscellaneous:
        HIGHLIGHT_HOVERED_COLUMN: Highlight column header when hovered
    """
    
    NONE = imgui.ImGuiTableFlags_None,
    RESIZABLE = imgui.ImGuiTableFlags_Resizable,   # Enable resizing columns
    REORDERABLE = imgui.ImGuiTableFlags_Reorderable,   # Enable reordering columns 
    HIDEABLE = imgui.ImGuiTableFlags_Hideable,   # Enable hiding/disabling columns
    SORTABLE = imgui.ImGuiTableFlags_Sortable,   # Enable sorting
    NO_SAVED_SETTINGS = imgui.ImGuiTableFlags_NoSavedSettings,   # Disable persisting columns order, width and sort settings
    CONTEXT_MENU_IN_BODY = imgui.ImGuiTableFlags_ContextMenuInBody,   # Right-click on columns body/contents will display table context menu
    ROW_BG = imgui.ImGuiTableFlags_RowBg,   # Set each RowBg color
    BORDERS_INNER_H = imgui.ImGuiTableFlags_BordersInnerH,   # Draw horizontal borders between rows
    BORDERS_OUTER_H = imgui.ImGuiTableFlags_BordersOuterH,   # Draw horizontal borders at the top and bottom
    BORDERS_INNER_V = imgui.ImGuiTableFlags_BordersInnerV,   # Draw vertical borders between columns
    BORDERS_OUTER_V = imgui.ImGuiTableFlags_BordersOuterV,  # Draw vertical borders on the left and right sides
    BORDERS_H = imgui.ImGuiTableFlags_BordersH,
    BORDERS_V = imgui.ImGuiTableFlags_BordersV,
    BORDERS_INNER = imgui.ImGuiTableFlags_BordersInner,
    BORDERS_OUTER = imgui.ImGuiTableFlags_BordersOuter,
    BORDERS = imgui.ImGuiTableFlags_Borders,
    NO_BORDERS_IN_BODY = imgui.ImGuiTableFlags_NoBordersInBody,
    NO_BORDERS_IN_BODY_UNTIL_RESIZE = imgui.ImGuiTableFlags_NoBordersInBodyUntilResize,
    SIZING_FIXED_FIT = imgui.ImGuiTableFlags_SizingFixedFit,
    SIZING_FIXED_SAME = imgui.ImGuiTableFlags_SizingFixedSame,
    SIZING_STRETCH_PROP = imgui.ImGuiTableFlags_SizingStretchProp,
    SIZING_STRETCH_SAME = imgui.ImGuiTableFlags_SizingStretchSame,
    NO_HOST_EXTEND_X = imgui.ImGuiTableFlags_NoHostExtendX,
    NO_HOST_EXTEND_Y = imgui.ImGuiTableFlags_NoHostExtendY,
    NO_KEEP_COLUMNS_VISIBLE = imgui.ImGuiTableFlags_NoKeepColumnsVisible,
    PRECISE_WIDTHS = imgui.ImGuiTableFlags_PreciseWidths,
    NO_CLIP = imgui.ImGuiTableFlags_NoClip,
    PAD_OUTER_X = imgui.ImGuiTableFlags_PadOuterX,
    NO_PAD_OUTER_X = imgui.ImGuiTableFlags_NoPadOuterX,
    NO_PAD_INNER_X = imgui.ImGuiTableFlags_NoPadInnerX,
    SCROLL_X = imgui.ImGuiTableFlags_ScrollX,
    SCROLL_Y = imgui.ImGuiTableFlags_ScrollY,
    SORT_MULTI = imgui.ImGuiTableFlags_SortMulti,
    SORT_TRISTATE = imgui.ImGuiTableFlags_SortTristate,
    HIGHLIGHT_HOVERED_COLUMN = imgui.ImGuiTableFlags_HighlightHoveredColumn

cdef object make_PlotMarker(int32_t marker):
    return PlotMarker(marker)