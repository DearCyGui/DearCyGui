# This file is imported in many pxd files,
# and we avoid cimporting imgui here in order
# to enable external code to link to us using
# the pxd files and without including imgui.


from libc.stdint cimport uint32_t, int32_t

from cpython.tuple cimport PyTuple_CheckExact
from cpython.list cimport PyList_CheckExact
from cpython.sequence cimport PySequence_Check
cimport cython

from .c_types cimport Vec2

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

cdef object get_children_types(
    bint can_have_drawing_child,
    bint can_have_handler_child,
    bint can_have_menubar_child,
    bint can_have_plot_element_child,
    bint can_have_tab_child,
    bint can_have_tag_child,
    bint can_have_theme_child,
    bint can_have_viewport_drawlist_child,
    bint can_have_widget_child,
    bint can_have_window_child
)
cdef object get_item_type(int element_child_category)

cpdef enum class HandlerListOP:
    ALL,
    ANY,
    NONE

cdef bint is_Key(object key)
cdef object make_Key(object key)
cdef bint is_KeyMod(object key)
cdef object make_KeyMod(object key)

cpdef enum class MouseButton:
    LEFT = 0,
    RIGHT = 1,
    MIDDLE = 2,
    X1 = 3,
    X2 = 4

cdef bint is_MouseButton(value)
cdef object make_MouseButton(value)

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

cdef bint is_MouseButtonMask(value)
cdef object make_MouseButtonMask(value)

cpdef enum class MouseCursor:
    NONE = -1,
    ARROW = 0,
    TEXTINPUT,         # When hovering over InputText, etc.
    RESIZE_ALL,         # (Unused by Dear ImGui functions)
    RESIZE_NS,          # When hovering over a horizontal border
    RESIZE_EW,          # When hovering over a vertical border or a column
    RESIZE_NESW,        # When hovering over the bottom-left corner of a window
    RESIZE_NWSE,        # When hovering over the bottom-right corner of a window
    HAND,              # (Unused by Dear ImGui functions. Use for e.g. hyperlinks)
    WAIT,
    PROGRESS,
    NOT_ALLOWED

cdef bint is_MouseCursor(value)
cdef object make_MouseCursor(value)

#Class that used to describe the positioning policy of an item (used now only by MotionHandler)
cpdef enum class Positioning:
    DEFAULT, # Cursor position
    REL_DEFAULT, # Shift relative to the cursor position
    REL_PARENT, # Shift relative to the parent position
    REL_WINDOW, # Shift relative to the window position
    REL_VIEWPORT # Shift relative to the viewport position

cdef object make_Positioning(value)

cpdef enum class Alignment:
    LEFT=0,
    TOP=0,
    RIGHT=1,
    BOTTOM=1,
    CENTER=2,
    JUSTIFIED=3,
    MANUAL=4

# Text Marker specification
cpdef enum class TextMarker:
    NONE, # No marker
    BULLET # Circle marker

# needed to return an object from other cython files
# rather that using the cdef version of PlotMarker
cdef object make_TextMarker(marker)
cdef bint is_TextMarker(value)

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
cdef object make_PlotMarker(marker)

cdef bint is_TableFlag(value)
cdef object make_TableFlag(value)

ctypedef fused point_type:
    int32_t
    float
    double

ctypedef fused src_source:
    tuple
    list

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

cdef class Display:
    cdef uint32_t _id
    cdef str _name
    cdef double[4] _bounds
    cdef double[4] _usable_bounds
    cdef float _content_scale
    cdef bint _is_primary
    cdef str _orientation

    @staticmethod
    cdef Display build(uint32_t id, str name, 
                 float content_scale, bint is_primary, str orientation,
                 double[4] bounds, double[4] usable_bounds)

@cython.boundscheck(False)
@cython.wraparound(False)
cdef inline int32_t read_point_exact(point_type* dst, src_source src):
    cdef int32_t src_size = len(src)
    if src_size > 2:
        raise TypeError("Expecting array, tuple, list, Coord, etc of len up to 2")
    if src_size == 2:
        dst[0] = <point_type>src[0]
        dst[1] = <point_type>src[1]
    elif src_size == 1:
        dst[0] = <point_type>src[0]
        dst[1] = <point_type>0.
    else:
        dst[0] = <point_type>0.
        dst[1] = <point_type>0.
    return src_size

cdef inline int32_t read_point(point_type* dst, src):
    if PyTuple_CheckExact(src) > 0:
        return read_point_exact[point_type, tuple](dst, <tuple>src)
    if PyList_CheckExact(src) > 0:
        return read_point_exact[point_type, list](dst, <list>src)
    if isinstance(src, Coord):
        dst[0] = <point_type>(<Coord>src)._x
        dst[1] = <point_type>(<Coord>src)._y
        return 2
    if PySequence_Check(src) == 0:
        raise TypeError("Expecting array, tuple, list, Coord, etc of len up to 2")
    cdef int32_t src_size = <int32_t>len(src)
    if src_size > 2 or src_size < 0:
        raise TypeError("Expecting array, tuple, list, Coord, etc of len up to 2")
    dst[0] = <point_type>0.
    dst[1] = <point_type>0.
    if src_size > 0:
        dst[0] = <point_type>src[0]
    if src_size > 1:
        dst[1] = <point_type>src[1]
    return src_size

cdef inline int32_t read_coord(double* dst, src):
    return read_point[double](dst, src)

cdef inline int32_t read_rect(double* dst, src):
    if isinstance(src, Rect):
        dst[0] = (<Rect>src)._x1
        dst[1] = (<Rect>src)._y1
        dst[2] = (<Rect>src)._x2
        dst[3] = (<Rect>src)._y2
        return 4
    try:
        if PySequence_Check(src) > 0 and len(src) == 2 and \
            PySequence_Check(src[0]) > 0 and PySequence_Check(src[1]) > 0:
            return read_coord(dst, src[0]) + \
                read_coord(dst + 2, src[1])
        else:
            return read_vec4[double](dst, src)
    except TypeError:
        raise TypeError("Rect data must be a tuple of two points or an array of up to 4 coordinates")

@cython.boundscheck(False)
@cython.wraparound(False)
cdef inline int32_t read_vec4_exact(point_type* dst, src_source src):
    cdef int32_t src_size = len(src)
    if src_size > 4:
        raise TypeError("Point data must be a tuple of up to 4 coordinates")
    if src_size == 4:
        dst[0] = <point_type>src[0]
        dst[1] = <point_type>src[1]
        dst[2] = <point_type>src[2]
        dst[3] = <point_type>src[3]
    elif src_size == 3:
        dst[0] = <point_type>src[0]
        dst[1] = <point_type>src[1]
        dst[2] = <point_type>src[2]
        dst[3] = <point_type>0.
    elif src_size == 2:
        dst[0] = <point_type>src[0]
        dst[1] = <point_type>src[1]
        dst[2] = <point_type>0.
        dst[3] = <point_type>0.
    elif src_size == 1:
        dst[0] = <point_type>src[0]
        dst[1] = <point_type>0.
        dst[2] = <point_type>0.
        dst[3] = <point_type>0.
    else:
        dst[0] = <point_type>0.
        dst[1] = <point_type>0.
        dst[2] = <point_type>0.
        dst[3] = <point_type>0.
    return src_size

cdef inline int32_t read_vec4(point_type* dst, src):
    if PyTuple_CheckExact(src) > 0:
        return read_vec4_exact[point_type, tuple](dst, <tuple>src)
    if PyList_CheckExact(src) > 0:
        return read_vec4_exact[point_type, list](dst, <list>src)
    if PySequence_Check(src) == 0:
        raise TypeError("Point data must be an array of up to 4 coordinates")
    cdef int32_t src_size = <int32_t>len(src)
    if src_size > 4 or src_size < 0:
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
    return src_size


# Helper to parse a texture from a python object.
# Returns a contiguous 3D array of floats (0..1) or uint8_t (max 4 channels)
cdef object parse_texture(src)