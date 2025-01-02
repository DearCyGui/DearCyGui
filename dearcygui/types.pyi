"""
This type stub file was generated by cyright.
"""

import cython
from enum import IntEnum, IntFlag

@cython.freelist(8)
class Coord:
    """
    Fast writable 2D coordinate tuple (x, y) which supports a lot of operations.
    Provides various arithmetic operations and properties for easy manipulation.
    """
    def __init__(self, x: float = ..., y: float = ...) -> None:
        ...
    
    @property
    def x(self): # -> float:
        """Coordinate on the horizontal axis"""
        ...
    
    @property
    def y(self): # -> float:
        """Coordinate on the vertical axis"""
        ...
    
    @x.setter
    def x(self, value): # -> None:
        ...
    
    @y.setter
    def y(self, value): # -> None:
        ...
    
    def __len__(self): # -> Literal[2]:
        ...
    
    def __getitem__(self, key): # -> float:
        ...
    
    def __setitem__(self, key, value): # -> None:
        ...
    
    def __add__(self, other): # -> _NotImplementedType:
        ...
    
    def __radd__(self, other): # -> _NotImplementedType:
        ...
    
    def __iadd__(self, other): # -> _NotImplementedType | Self@Coord:
        ...
    
    def __sub__(self, other): # -> _NotImplementedType:
        ...
    
    def __rsub__(self, other): # -> _NotImplementedType:
        ...
    
    def __isub__(self, other): # -> _NotImplementedType | Self@Coord:
        ...
    
    def __mul__(self, other): # -> _NotImplementedType:
        ...
    
    def __rmul__(self, other): # -> _NotImplementedType:
        ...
    
    def __imul__(self, other): # -> _NotImplementedType | Self@Coord:
        ...
    
    def __truediv__(self, other): # -> _NotImplementedType:
        ...
    
    def __rtruediv__(self, other): # -> _NotImplementedType:
        ...
    
    def __itruediv__(self, other): # -> _NotImplementedType | Self@Coord:
        ...
    
    def __neg__(self):
        ...
    
    def __pos__(self):
        ...
    
    def __abs__(self):
        ...
    
    def __lt__(self, other) -> bool:
        ...
    
    def __le__(self, other) -> bool:
        ...
    
    def __eq__(self, other) -> bool:
        ...
    
    def __ne__(self, other) -> bool:
        ...
    
    def __gt__(self, other) -> bool:
        ...
    
    def __ge__(self, other) -> bool:
        ...
    
    def __hash__(self) -> int:
        ...
    
    def __bool__(self): # -> bool:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __repr__(self): # -> str:
        ...
    


@cython.freelist(8)
class Rect:
    """
    Fast writable rectangle class with diagonal points (x1,y1) and (x2,y2) which supports a lot of operations.
    Provides various arithmetic operations and properties for easy manipulation.
    """
    def __init__(self, x1: float = ..., y1: float = ..., x2: float = ..., y2: float = ...) -> None:
        ...
    
    @property
    def xmin(self): # -> float:
        """Left coordinate"""
        ...
    
    @property
    def ymin(self): # -> float:
        """Top coordinate"""
        ...
    
    @property
    def xmax(self): # -> float:
        """Right coordinate"""
        ...
    
    @property
    def ymax(self): # -> float:
        """Bottom coordinate"""
        ...
    
    @property
    def x1(self): # -> float:
        """Coordinate of the first corner point"""
        ...
    
    @property
    def y1(self): # -> float:
        """Coordinate of the first corner point"""
        ...
    
    @property
    def x2(self): # -> float:
        """Coordinate of the second corner point"""
        ...
    
    @property
    def y2(self): # -> float:
        """Coordinate of the second corner point"""
        ...
    
    @property
    def w(self): # -> float:
        """Width of rectangle"""
        ...
    
    @property
    def h(self): # -> float:
        """Height of rectangle"""
        ...
    
    @property
    def p1(self):
        """Coord(x1,y1)"""
        ...
    
    @property
    def p2(self):
        """Coord(x2,y2)"""
        ...
    
    @property
    def pmin(self):
        """Coord(xmin,ymin)"""
        ...
    
    @property
    def pmax(self):
        """Coord(xmax,ymax)"""
        ...
    
    @property
    def center(self):
        """Center as Coord(x,y)"""
        ...
    
    @property
    def size(self):
        """Size as Coord(w,h)"""
        ...
    
    @x1.setter
    def x1(self, value): # -> None:
        ...
    
    @x2.setter
    def x2(self, value): # -> None:
        ...
    
    @y1.setter
    def y1(self, value): # -> None:
        ...
    
    @y2.setter
    def y2(self, value): # -> None:
        ...
    
    @center.setter
    def center(self, value): # -> None:
        ...
    
    def __len__(self): # -> Literal[4]:
        ...
    
    def __getitem__(self, key): # -> float:
        ...
    
    def __setitem__(self, key, value): # -> None:
        ...
    
    def __eq__(self, other) -> bool:
        ...
    
    def __ne__(self, other) -> bool:
        ...
    
    def __hash__(self) -> int:
        ...
    
    def __bool__(self): # -> bool:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __repr__(self): # -> str:
        ...
    
    def __add__(self, other): # -> _NotImplementedType:
        ...
    
    def __radd__(self, other):
        ...
    
    def __iadd__(self, other): # -> _NotImplementedType | Self@Rect:
        ...
    
    def __sub__(self, other): # -> _NotImplementedType:
        ...
    
    def __isub__(self, other): # -> _NotImplementedType | Self@Rect:
        ...
    
    def __mul__(self, other): # -> _NotImplementedType:
        ...
    
    def __rmul__(self, other):
        ...
    
    def __imul__(self, other): # -> _NotImplementedType | Self@Rect:
        ...
    
    def __truediv__(self, other): # -> _NotImplementedType:
        ...
    
    def __itruediv__(self, other): # -> _NotImplementedType | Self@Rect:
        ...
    
    def __neg__(self):
        ...
    
    def __pos__(self):
        ...
    
    def __abs__(self):
        ...
    
    def __contains__(self, point): # -> _NotImplementedType | bool:
        ...
    


class ChildType(IntFlag):
    """
    Enum representing different types of child elements that can be attached to items.
    """
    NOCHILD = ...
    DRAWING = ...
    HANDLER = ...
    MENUBAR = ...
    PLOTELEMENT = ...
    TAB = ...
    THEME = ...
    VIEWPORTDRAWLIST = ...
    WIDGET = ...
    WINDOW = ...
    AXISTAG = ...


class Key(IntEnum):
    """
    Enum representing various keyboard keys.
    """
    TAB = ...
    LEFTARROW = ...
    RIGHTARROW = ...
    UPARROW = ...
    DOWNARROW = ...
    PAGEUP = ...
    PAGEDOWN = ...
    HOME = ...
    END = ...
    INSERT = ...
    DELETE = ...
    BACKSPACE = ...
    SPACE = ...
    ENTER = ...
    ESCAPE = ...
    LEFTCTRL = ...
    LEFTSHIFT = ...
    LEFTALT = ...
    LEFTSUPER = ...
    RIGHTCTRL = ...
    RIGHTSHIFT = ...
    RIGHTALT = ...
    RIGHTSUPER = ...
    MENU = ...
    ZERO = ...
    ONE = ...
    TWO = ...
    THREE = ...
    FOUR = ...
    FIVE = ...
    SIX = ...
    SEVEN = ...
    EIGHT = ...
    NINE = ...
    A = ...
    B = ...
    C = ...
    D = ...
    E = ...
    F = ...
    G = ...
    H = ...
    I = ...
    J = ...
    K = ...
    L = ...
    M = ...
    N = ...
    O = ...
    P = ...
    Q = ...
    R = ...
    S = ...
    T = ...
    U = ...
    V = ...
    W = ...
    X = ...
    Y = ...
    Z = ...
    F1 = ...
    F2 = ...
    F3 = ...
    F4 = ...
    F5 = ...
    F6 = ...
    F7 = ...
    F8 = ...
    F9 = ...
    F10 = ...
    F11 = ...
    F12 = ...
    F13 = ...
    F14 = ...
    F15 = ...
    F16 = ...
    F17 = ...
    F18 = ...
    F19 = ...
    F20 = ...
    F21 = ...
    F22 = ...
    F23 = ...
    F24 = ...
    APOSTROPHE = ...
    COMMA = ...
    MINUS = ...
    PERIOD = ...
    SLASH = ...
    SEMICOLON = ...
    EQUAL = ...
    LEFTBRACKET = ...
    BACKSLASH = ...
    RIGHTBRACKET = ...
    GRAVEACCENT = ...
    CAPSLOCK = ...
    SCROLLLOCK = ...
    NUMLOCK = ...
    PRINTSCREEN = ...
    PAUSE = ...
    KEYPAD0 = ...
    KEYPAD1 = ...
    KEYPAD2 = ...
    KEYPAD3 = ...
    KEYPAD4 = ...
    KEYPAD5 = ...
    KEYPAD6 = ...
    KEYPAD7 = ...
    KEYPAD8 = ...
    KEYPAD9 = ...
    KEYPADDECIMAL = ...
    KEYPADDIVIDE = ...
    KEYPADMULTIPLY = ...
    KEYPADSUBTRACT = ...
    KEYPADADD = ...
    KEYPADENTER = ...
    KEYPADEQUAL = ...
    APPBACK = ...
    APPFORWARD = ...
    GAMEPADSTART = ...
    GAMEPADBACK = ...
    GAMEPADFACELEFT = ...
    GAMEPADFACERIGHT = ...
    GAMEPADFACEUP = ...
    GAMEPADFACEDOWN = ...
    GAMEPADDPADLEFT = ...
    GAMEPADDPADRIGHT = ...
    GAMEPADDPADUP = ...
    GAMEPADDPADDOWN = ...
    GAMEPADL1 = ...
    GAMEPADR1 = ...
    GAMEPADL2 = ...
    GAMEPADR2 = ...
    GAMEPADL3 = ...
    GAMEPADR3 = ...
    GAMEPADLSTICKLEFT = ...
    GAMEPADLSTICKRIGHT = ...
    GAMEPADLSTICKUP = ...
    GAMEPADLSTICKDOWN = ...
    GAMEPADRSTICKLEFT = ...
    GAMEPADRSTICKRIGHT = ...
    GAMEPADRSTICKUP = ...
    GAMEPADRSTICKDOWN = ...
    MOUSELEFT = ...
    MOUSERIGHT = ...
    MOUSEMIDDLE = ...
    MOUSEX1 = ...
    MOUSEX2 = ...
    MOUSEWHEELX = ...
    MOUSEWHEELY = ...
    RESERVEDFORMODCTRL = ...
    RESERVEDFORMODSHIFT = ...
    RESERVEDFORMODALT = ...
    RESERVEDFORMODSUPER = ...


class KeyMod(IntFlag):
    """
    Enum representing key modifiers (Ctrl, Shift, Alt, Super).
    """
    NOMOD = ...
    CTRL = ...
    SHIFT = ...
    ALT = ...
    SUPER = ...


class KeyOrMod(IntFlag):
    """
    Enum representing both keys and key modifiers.
    """
    NOMOD = ...
    TAB = ...
    LEFTARROW = ...
    RIGHTARROW = ...
    UPARROW = ...
    DOWNARROW = ...
    PAGEUP = ...
    PAGEDOWN = ...
    HOME = ...
    END = ...
    INSERT = ...
    DELETE = ...
    BACKSPACE = ...
    SPACE = ...
    ENTER = ...
    ESCAPE = ...
    LEFTCTRL = ...
    LEFTSHIFT = ...
    LEFTALT = ...
    LEFTSUPER = ...
    RIGHTCTRL = ...
    RIGHTSHIFT = ...
    RIGHTALT = ...
    RIGHTSUPER = ...
    MENU = ...
    ZERO = ...
    ONE = ...
    TWO = ...
    THREE = ...
    FOUR = ...
    FIVE = ...
    SIX = ...
    SEVEN = ...
    EIGHT = ...
    NINE = ...
    A = ...
    B = ...
    C = ...
    D = ...
    E = ...
    F = ...
    G = ...
    H = ...
    I = ...
    J = ...
    K = ...
    L = ...
    M = ...
    N = ...
    O = ...
    P = ...
    Q = ...
    R = ...
    S = ...
    T = ...
    U = ...
    V = ...
    W = ...
    X = ...
    Y = ...
    Z = ...
    F1 = ...
    F2 = ...
    F3 = ...
    F4 = ...
    F5 = ...
    F6 = ...
    F7 = ...
    F8 = ...
    F9 = ...
    F10 = ...
    F11 = ...
    F12 = ...
    F13 = ...
    F14 = ...
    F15 = ...
    F16 = ...
    F17 = ...
    F18 = ...
    F19 = ...
    F20 = ...
    F21 = ...
    F22 = ...
    F23 = ...
    F24 = ...
    APOSTROPHE = ...
    COMMA = ...
    MINUS = ...
    PERIOD = ...
    SLASH = ...
    SEMICOLON = ...
    EQUAL = ...
    LEFTBRACKET = ...
    BACKSLASH = ...
    RIGHTBRACKET = ...
    GRAVEACCENT = ...
    CAPSLOCK = ...
    SCROLLLOCK = ...
    NUMLOCK = ...
    PRINTSCREEN = ...
    PAUSE = ...
    KEYPAD0 = ...
    KEYPAD1 = ...
    KEYPAD2 = ...
    KEYPAD3 = ...
    KEYPAD4 = ...
    KEYPAD5 = ...
    KEYPAD6 = ...
    KEYPAD7 = ...
    KEYPAD8 = ...
    KEYPAD9 = ...
    KEYPADDECIMAL = ...
    KEYPADDIVIDE = ...
    KEYPADMULTIPLY = ...
    KEYPADSUBTRACT = ...
    KEYPADADD = ...
    KEYPADENTER = ...
    KEYPADEQUAL = ...
    APPBACK = ...
    APPFORWARD = ...
    GAMEPADSTART = ...
    GAMEPADBACK = ...
    GAMEPADFACELEFT = ...
    GAMEPADFACERIGHT = ...
    GAMEPADFACEUP = ...
    GAMEPADFACEDOWN = ...
    GAMEPADDPADLEFT = ...
    GAMEPADDPADRIGHT = ...
    GAMEPADDPADUP = ...
    GAMEPADDPADDOWN = ...
    GAMEPADL1 = ...
    GAMEPADR1 = ...
    GAMEPADL2 = ...
    GAMEPADR2 = ...
    GAMEPADL3 = ...
    GAMEPADR3 = ...
    GAMEPADLSTICKLEFT = ...
    GAMEPADLSTICKRIGHT = ...
    GAMEPADLSTICKUP = ...
    GAMEPADLSTICKDOWN = ...
    GAMEPADRSTICKLEFT = ...
    GAMEPADRSTICKRIGHT = ...
    GAMEPADRSTICKUP = ...
    GAMEPADRSTICKDOWN = ...
    MOUSELEFT = ...
    MOUSERIGHT = ...
    MOUSEMIDDLE = ...
    MOUSEX1 = ...
    MOUSEX2 = ...
    MOUSEWHEELX = ...
    MOUSEWHEELY = ...
    RESERVEDFORMODCTRL = ...
    RESERVEDFORMODSHIFT = ...
    RESERVEDFORMODALT = ...
    RESERVEDFORMODSUPER = ...
    CTRL = ...
    SHIFT = ...
    ALT = ...
    SUPER = ...


class HandlerListOP(IntEnum):
    ALL = ...
    ANY = ...
    NONE = ...


class MouseButton(IntEnum):
    LEFT = ...
    RIGHT = ...
    MIDDLE = ...
    X1 = ...
    X2 = ...


class MouseButtonMask(IntEnum):
    NOBUTTON = ...
    LEFT = ...
    RIGHT = ...
    LEFTRIGHT = ...
    MIDDLE = ...
    LEFTMIDDLE = ...
    MIDDLERIGHT = ...
    ANY = ...


class MouseCursor(IntEnum):
    CursorNone = ...
    CursorArrow = ...
    CursorTextInput = ...
    ResizeAll = ...
    ResizeNS = ...
    ResizeEW = ...
    ResizeNESW = ...
    ResizeNWSE = ...
    Hand = ...
    NotAllowed = ...


class Positioning(IntEnum):
    DEFAULT = ...
    REL_DEFAULT = ...
    REL_PARENT = ...
    REL_WINDOW = ...
    REL_VIEWPORT = ...


class Sizing(IntEnum):
    SCALED = ...
    ABSOLUTE = ...
    RELATIVE = ...
    PERCENTAGE = ...
    AUTO = ...


class Alignment(IntEnum):
    LEFT = ...
    TOP = ...
    RIGHT = ...
    BOTTOM = ...
    CENTER = ...
    JUSTIFIED = ...
    MANUAL = ...


class PlotMarker(IntEnum):
    NONE = ...
    CIRCLE = ...
    SQUARE = ...
    DIAMOND = ...
    UP = ...
    DOWN = ...
    LEFT = ...
    RIGHT = ...
    CROSS = ...
    PLUS = ...
    ASTERISK = ...


class ThemeEnablers(IntEnum):
    ANY = ...
    FALSE = ...
    TRUE = ...
    DISCARDED = ...


class ThemeCategories(IntEnum):
    t_any = ...
    t_simpleplot = ...
    t_button = ...
    t_combo = ...
    t_checkbox = ...
    t_slider = ...
    t_listbox = ...
    t_radiobutton = ...
    t_inputtext = ...
    t_inputvalue = ...
    t_text = ...
    t_selectable = ...
    t_tab = ...
    t_tabbar = ...
    t_tabbutton = ...
    t_menuitem = ...
    t_progressbar = ...
    t_image = ...
    t_imagebutton = ...
    t_menubar = ...
    t_menu = ...
    t_tooltip = ...
    t_layout = ...
    t_treenode = ...
    t_collapsingheader = ...
    t_child = ...
    t_colorbutton = ...
    t_coloredit = ...
    t_colorpicker = ...
    t_window = ...
    t_plot = ...


