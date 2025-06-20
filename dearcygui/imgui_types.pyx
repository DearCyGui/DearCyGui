#cython: freethreading_compatible=True

from .wrapper cimport imgui, implot

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


cdef bint is_ButtonDirection(value):
    if isinstance(value, ButtonDirection):
        return True
    if isinstance(value, str):
        try:
            value = ButtonDirection[value.upper()]
            return True
        except KeyError:
            return False
    return False

cdef object make_ButtonDirection(value):
    cdef int32_t value_int
    if isinstance(value, ButtonDirection):
        return value
    if isinstance(value, str):
        try:
            return ButtonDirection[value.upper()]
        except KeyError:
            raise ValueError(f"Invalid button direction name: {value}")
    if isinstance(value, int):
        value_int = <int32_t>value
        if value_int == imgui.ImGuiDir_Left:
            return ButtonDirection.LEFT
        elif value_int == imgui.ImGuiDir_Right:
            return ButtonDirection.RIGHT
        elif value_int == imgui.ImGuiDir_Up:
            return ButtonDirection.UP
        elif value_int == imgui.ImGuiDir_Down:
            return ButtonDirection.DOWN
        raise ValueError(f"Invalid button direction value: {value}")
    raise TypeError(f"Expected ButtonDirection enum or string, got {type(value).__name__}")


cdef int32_t check_Axis(value):
    if isinstance(value, Axis):
        return <int32_t>int(value)
    if isinstance(value, str):
        try:
            return <int32_t>int(Axis[value.upper()])
        except KeyError:
            raise ValueError(f"Invalid axis name: {value}")
    if isinstance(value, int):
        if (<int32_t>value) in (implot.ImAxis_X1, implot.ImAxis_X2,
                                implot.ImAxis_X3, implot.ImAxis_Y1,
                                implot.ImAxis_Y2, implot.ImAxis_Y3):
            return <int32_t>value
        raise ValueError(f"Invalid axis value: {value}")
    raise TypeError(f"Expected Axis enum or string, got {type(value).__name__}")

cdef object make_Axis(int32_t value):
    if value == implot.ImAxis_X1:
        return Axis.X1
    elif value == implot.ImAxis_X2:
        return Axis.X2
    elif value == implot.ImAxis_X3:
        return Axis.X3
    elif value == implot.ImAxis_Y1:
        return Axis.Y1
    elif value == implot.ImAxis_Y2:
        return Axis.Y2
    elif value == implot.ImAxis_Y3:
        return Axis.Y3
    raise ValueError(f"Invalid axis value: {value}")