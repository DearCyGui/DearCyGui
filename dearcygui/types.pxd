# This file is imported in many pxd files,
# and we avoid cimporting imgui here in order
# to enable external code to link to us using
# the pxd files and without including imgui.

from .c_types cimport float2, double2, Vec2, Vec4

cdef enum child_type:
    cat_drawing
    cat_handler
    cat_menubar
    cat_plot_element
    cat_tab
    cat_tag
    cat_theme
    cat_viewport_drawlist
    cat_widget
    cat_window

cpdef enum class HandlerListOP:
    ALL,
    ANY,
    NONE

cpdef enum class MouseButton:
    LEFT = 0,
    RIGHT = 1,
    MIDDLE = 2,
    X1 = 3,
    X2 = 4

cpdef enum class MouseButtonMask:
    NOBUTTON = 0,
    LEFT = 1,
    RIGHT = 2,
    LEFTRIGHT = 3,
    MIDDLE = 4,
    LEFTMIDDLE = 5,
    MIDDLERIGHT = 6,
    ANY = 7
#    X1 = 8
#    X2 = 16,
#    ANY = 31


cpdef enum class MouseCursor:
    CursorNone = -1,
    CursorArrow = 0,
    CursorTextInput,         # When hovering over InputText, etc.
    ResizeAll,         # (Unused by Dear ImGui functions)
    ResizeNS,          # When hovering over a horizontal border
    ResizeEW,          # When hovering over a vertical border or a column
    ResizeNESW,        # When hovering over the bottom-left corner of a window
    ResizeNWSE,        # When hovering over the bottom-right corner of a window
    Hand,              # (Unused by Dear ImGui functions. Use for e.g. hyperlinks)
    NotAllowed

"""Class to describe the positioning policy of an item"""
cpdef enum class Positioning:
    DEFAULT, # Cursor position
    REL_DEFAULT, # Shift relative to the cursor position
    REL_PARENT, # Shift relative to the parent position
    REL_WINDOW, # Shift relative to the window position
    REL_VIEWPORT # Shift relative to the viewport position

"""Class to describe the sizing policy of an item"""
cpdef enum class Sizing:
    SCALED, # fixed, but scaled by the global scale factor
    ABSOLUTE, # fixed, not affected by the global scale factor
    RELATIVE, # Delta relative to the parent size
    PERCENTAGE, # Percentage of the parent size
    AUTO # Automatically calculated

cpdef enum class Alignment:
    LEFT=0,
    TOP=0,
    RIGHT=1,
    BOTTOM=1,
    CENTER=2,
    JUSTIFIED=3,
    MANUAL=4

# Marker specification, with values matching ImPlot
cpdef enum class PlotMarker:
    NONE=-1, # No marker
    CIRCLE=0, # Circle marker
    SQUARE=1, # Square marker
    DIAMOND=2, # Diamond marker
    UP=3, # An upward-pointing triangle marker
    DOWN=4, # A downward-pointing triangle marker
    LEFT=5, # A left-pointing triangle marker
    RIGHT=6, # A right-pointing triangle marker
    CROSS=7, # A cross marker
    PLUS=8, # A plus marker
    ASTERISK=9 # An asterisk marker

# needed to return an object from other cython files
# rather that using the cdef version of PlotMarker
cdef object make_PlotMarker(int marker)

cdef enum theme_types:
    t_color,
    t_style

cdef enum theme_backends:
    t_imgui,
    t_implot,
    t_imnodes

cpdef enum class ThemeEnablers:
    ANY,
    FALSE,
    TRUE,
    DISCARDED

cpdef enum class ThemeCategories:
    t_any,
    t_simpleplot,
    t_button,
    t_combo,
    t_checkbox,
    t_slider,
    t_listbox,
    t_radiobutton,
    t_inputtext,
    t_inputvalue,
    t_text,
    t_selectable,
    t_tab,
    t_tabbar,
    t_tabbutton,
    t_menuitem,
    t_progressbar,
    t_image,
    t_imagebutton,
    t_menubar,
    t_menu,
    t_tooltip,
    t_layout,
    t_treenode,
    t_collapsingheader,
    t_child,
    t_colorbutton,
    t_coloredit,
    t_colorpicker,
    t_window,
    t_plot

cdef enum theme_value_float2_mask:
    t_full,
    t_left,
    t_right

cdef enum theme_value_types:
    t_int,
    t_float,
    t_float2,
    t_u32

ctypedef union theme_value:
    int value_int
    float value_float
    float[2] value_float2
    unsigned value_u32

ctypedef struct theme_action:
    ThemeEnablers activation_condition_enabled
    ThemeCategories activation_condition_category
    theme_types type
    theme_backends backend
    int theme_index
    theme_value_types value_type
    theme_value value
    theme_value_float2_mask float2_mask

ctypedef fused point_type:
    int
    float
    double


cdef class Coord:
    cdef double _x
    cdef double _y
    @staticmethod
    cdef Coord build(double[2] &coord)
    @staticmethod
    cdef Coord build_v(Vec2 &coord)

cdef class Rect:
    cdef double _x1
    cdef double _y1
    cdef double _x2
    cdef double _y2
    @staticmethod
    cdef Rect build(double[4] &rect)

cdef inline void read_point(point_type* dst, src):
    if not(hasattr(src, '__len__')):
        raise TypeError("Point data must be an array of up to 2 coordinates")
    cdef int src_size = len(src)
    if src_size > 2:
        raise TypeError("Point data must be an array of up to 2 coordinates")
    dst[0] = <point_type>0.
    dst[1] = <point_type>0.
    if src_size > 0:
        dst[0] = <point_type>src[0]
    if src_size > 1:
        dst[1] = <point_type>src[1]

cdef inline void read_coord(double* dst, src):
    if isinstance(src, Coord):
        dst[0] = (<Coord>src)._x
        dst[1] = (<Coord>src)._y
    else:
        read_point[double](dst, src)

cdef inline void read_rect(double* dst, src):
    if isinstance(src, Rect):
        dst[0] = (<Rect>src)._x1
        dst[1] = (<Rect>src)._y1
        dst[2] = (<Rect>src)._x2
        dst[3] = (<Rect>src)._y2
        return
    try:
        if isinstance(src, tuple) and len(src) == 2 and \
            hasattr(src[0], "__len__") and hasattr(src[1], "__len__"):
            read_coord(dst, src[0])
            read_coord(dst + 2, src[1])
        else:
            read_vec4[double](dst, src)
    except TypeError:
        raise TypeError("Rect data must be a tuple of two points or an array of up to 4 coordinates")

cdef inline void read_vec4(point_type* dst, src):
    if not(hasattr(src, '__len__')):
        raise TypeError("Point data must be an array of up to 4 coordinates")
    cdef int src_size = len(src)
    if src_size > 4:
        raise TypeError("Point data must be an array of up to 4 coordinates")
    dst[0] = <point_type>0.
    dst[1] = <point_type>0.
    dst[2] = <point_type>0.
    dst[3] = <point_type>0.
    if src_size > 0:
        dst[0] = <point_type>src[0]
    if src_size > 1:
        dst[1] = <point_type>src[1]
    if src_size > 2:
        dst[2] = <point_type>src[2]
    if src_size > 3:
        dst[3] = <point_type>src[3]

