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
    NONE = ...
    RESIZABLE = ...
    REORDERABLE = ...
    HIDEABLE = ...
    SORTABLE = ...
    NO_SAVED_SETTINGS = ...
    CONTEXT_MENU_IN_BODY = ...
    ROW_BG = ...
    BORDERS_INNER_H = ...
    BORDERS_OUTER_H = ...
    BORDERS_INNER_V = ...
    BORDERS_OUTER_V = ...
    BORDERS_H = ...
    BORDERS_V = ...
    BORDERS_INNER = ...
    BORDERS_OUTER = ...
    BORDERS = ...
    NO_BORDERS_IN_BODY = ...
    NO_BORDERS_IN_BODY_UNTIL_RESIZE = ...
    SIZING_FIXED_FIT = ...
    SIZING_FIXED_SAME = ...
    SIZING_STRETCH_PROP = ...
    SIZING_STRETCH_SAME = ...
    NO_HOST_EXTEND_X = ...
    NO_HOST_EXTEND_Y = ...
    NO_KEEP_COLUMNS_VISIBLE = ...
    PRECISE_WIDTHS = ...
    NO_CLIP = ...
    PAD_OUTER_X = ...
    NO_PAD_OUTER_X = ...
    NO_PAD_INNER_X = ...
    SCROLL_X = ...
    SCROLL_Y = ...
    SORT_MULTI = ...
    SORT_TRISTATE = ...
    HIGHLIGHT_HOVERED_COLUMN = ...


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


