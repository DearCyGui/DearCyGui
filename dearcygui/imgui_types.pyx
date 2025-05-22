#cython: freethreading_compatible=True

from .wrapper cimport imgui

cdef imgui.ImU32 imgui_ColorConvertFloat4ToU32(imgui.ImVec4 color_float4) noexcept nogil:
    return imgui.ColorConvertFloat4ToU32(color_float4)

cdef imgui.ImVec4 imgui_ColorConvertU32ToFloat4(imgui.ImU32 color_uint) noexcept nogil:
    return imgui.ColorConvertU32ToFloat4(color_uint)

def color_as_int(val)-> int:
    """
    Convert any color representation to an integer (packed rgba).
    """
    cdef imgui.ImU32 color = parse_color(val)
    return int(color)

def color_as_ints(val) -> tuple[int, int, int, int]:
    """
    Convert any color representation to a tuple of integers (r, g, b, a).
    """
    cdef imgui.ImU32 color = parse_color(val)
    cdef imgui.ImVec4 color_vec = imgui.ColorConvertU32ToFloat4(color)
    return (int(255. * color_vec.x),
            int(255. * color_vec.y),
            int(255. * color_vec.z),
            int(255. * color_vec.w))

def color_as_floats(val) -> tuple[float, float, float, float]:
    """
    Convert any color representation to a tuple of floats (r, g, b, a).
    """
    cdef imgui.ImU32 color = parse_color(val)
    cdef imgui.ImVec4 color_vec = imgui.ColorConvertU32ToFloat4(color)
    return (color_vec.x, color_vec.y, color_vec.z, color_vec.w)
