from dearcygui.wrapper cimport imgui, implot
from .c_types cimport Vec2, Vec4

# Here all the types that need a cimport
# of imgui. In order to enable Cython code
# to interact with us without using imgui,
# we try to avoid as much as possible to
# include this file in the .pxd files.

cpdef enum class ButtonDirection:
    NONE = imgui.ImGuiDir_None,
    LEFT = imgui.ImGuiDir_Left,
    RIGHT = imgui.ImGuiDir_Right,
    UP = imgui.ImGuiDir_Up,
    DOWN = imgui.ImGuiDir_Down

cpdef enum class AxisScale:
    LINEAR=implot.ImPlotScale_Linear
    TIME=implot.ImPlotScale_Time
    LOG10=implot.ImPlotScale_Log10
    SYMLOG=implot.ImPlotScale_SymLog

cpdef enum class Axis:
    X1=implot.ImAxis_X1
    X2=implot.ImAxis_X2
    X3=implot.ImAxis_X3
    Y1=implot.ImAxis_Y1
    Y2=implot.ImAxis_Y2
    Y3=implot.ImAxis_Y3

cpdef enum class LegendLocation:
    CENTER=implot.ImPlotLocation_Center
    NORTH=implot.ImPlotLocation_North
    SOUTH=implot.ImPlotLocation_South
    WEST=implot.ImPlotLocation_West
    EAST=implot.ImPlotLocation_East
    NORTHWEST=implot.ImPlotLocation_NorthWest
    NORTHEAST=implot.ImPlotLocation_NorthEast
    SOUTHWEST=implot.ImPlotLocation_SouthWest
    SOUTHEAST=implot.ImPlotLocation_SouthEast

cdef imgui.ImU32 imgui_ColorConvertFloat4ToU32(imgui.ImVec4) noexcept nogil
cdef imgui.ImVec4 imgui_ColorConvertU32ToFloat4(imgui.ImU32) noexcept nogil

cdef inline imgui.ImU32 parse_color(src):
    if isinstance(src, int):
        # RGBA, little endian
        return <imgui.ImU32>(<long long>src)
    cdef int src_size = 5 # to trigger error by default
    if hasattr(src, '__len__'):
        src_size = len(src)
    if src_size == 0 or src_size > 4:
        raise TypeError("Color data must either an int32 (rgba, little endian),\n" \
                        "or an array of int (r, g, b, a) or float (r, g, b, a) normalized")
    cdef imgui.ImVec4 color_float4
    cdef imgui.ImU32 color_u32
    cdef bint contains_nonints = False
    cdef int i
    cdef float[4] values
    cdef int[4] values_int

    for i in range(src_size):
        element = src[i]
        if not(isinstance(element, int)):
            contains_nonints = True
            values[i] = element
            values_int[i] = <int>values[i]
        else:
            values_int[i] = element
            values[i] = <float>values_int[i]
    for i in range(src_size, 4):
        values[i] = 1.
        values_int[i] = 255

    if not(contains_nonints):
        for i in range(4):
            if values_int[i] < 0 or values_int[i] > 255:
                raise ValueError("Color value component outside bounds (0...255)")
        color_u32 = <imgui.ImU32>values_int[0]
        color_u32 |= (<imgui.ImU32>values_int[1]) << 8
        color_u32 |= (<imgui.ImU32>values_int[2]) << 16
        color_u32 |= (<imgui.ImU32>values_int[3]) << 24
        return color_u32

    for i in range(4):
        if values[i] < 0. or values[i] > 1.:
            raise ValueError("Color value component outside bounds (0...1)")

    color_float4.x = values[0]
    color_float4.y = values[1]
    color_float4.z = values[2]
    color_float4.w = values[3]
    return imgui_ColorConvertFloat4ToU32(color_float4)

cdef inline void unparse_color(float *dst, imgui.ImU32 color_uint) noexcept nogil:
    cdef imgui.ImVec4 color_float4 = imgui_ColorConvertU32ToFloat4(color_uint)
    dst[0] = color_float4.x
    dst[1] = color_float4.y
    dst[2] = color_float4.z
    dst[3] = color_float4.w

# These conversions are to avoid
# using imgui.* in pxd files.

cdef inline imgui.ImVec2 Vec2ImVec2(Vec2 src) noexcept nogil:
    cdef imgui.ImVec2 dst
    dst.x = src.x
    dst.y = src.y
    return dst

cdef inline imgui.ImVec4 Vec4ImVec4(Vec4 src) noexcept nogil:
    cdef imgui.ImVec4 dst
    dst.x = src.x
    dst.y = src.y
    dst.z = src.z
    dst.w = src.w
    return dst

cdef inline Vec2 ImVec2Vec2(imgui.ImVec2 src) noexcept nogil:
    cdef Vec2 dst
    dst.x = src.x
    dst.y = src.y
    return dst

cdef inline Vec4 ImVec4Vec4(imgui.ImVec4 src) noexcept nogil:
    cdef Vec4 dst
    dst.x = src.x
    dst.y = src.y
    dst.z = src.z
    dst.w = src.w
    return dst

