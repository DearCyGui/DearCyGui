from libc.stdint cimport uint32_t, int32_t

from cpython.sequence cimport PySequence_Check

from .c_types cimport Vec2, Vec4
from .wrapper cimport imgui, implot

# Here all the types that need a cimport
# of imgui. In order to enable Cython code
# to interact with us without using imgui,
# we try to avoid as much as possible to
# include this file in the .pxd files.

cpdef enum class ButtonDirection:
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
    cdef int32_t src_size = 5 # to trigger error by default
    if PySequence_Check(src) > 0:
        src_size = len(src)
    if src_size == 0 or src_size > 4 or src_size < 0:
        raise TypeError("Color data must either an int32 (rgba, little endian),\n" \
                        "or an array of int (r, g, b, a) or float (r, g, b, a) normalized")
    cdef imgui.ImVec4 color_float4
    cdef imgui.ImU32 color_u32
    cdef bint contains_nonints = False
    cdef int32_t i
    cdef float[4] values
    cdef uint32_t[4] values_int

    for i in range(src_size):
        element = src[i]
        if not(isinstance(element, int)):
            contains_nonints = True
            values[i] = element
            values_int[i] = <uint32_t>values[i]
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

# For extensions to be able to use the
# theme style, it needs to retrieve the index
# of the style from the theme.
# The idea of these structures is not to cimport them
# in user custom extensions, but rather they would
# import the python version (import instead of cimport)
# to get the indices, and store them for use.

cpdef enum class ImGuiStyleIndex:
    Alpha = imgui.ImGuiStyleVar_Alpha
    DisabledAlpha = imgui.ImGuiStyleVar_DisabledAlpha
    WindowPadding = imgui.ImGuiStyleVar_WindowPadding
    WindowRounding = imgui.ImGuiStyleVar_WindowRounding
    WindowBorderSize = imgui.ImGuiStyleVar_WindowBorderSize
    WindowMinSize = imgui.ImGuiStyleVar_WindowMinSize
    WindowTitleAlign = imgui.ImGuiStyleVar_WindowTitleAlign
    ChildRounding = imgui.ImGuiStyleVar_ChildRounding
    ChildBorderSize = imgui.ImGuiStyleVar_ChildBorderSize
    PopupRounding = imgui.ImGuiStyleVar_PopupRounding
    PopupBorderSize = imgui.ImGuiStyleVar_PopupBorderSize
    FramePadding = imgui.ImGuiStyleVar_FramePadding
    FrameRounding = imgui.ImGuiStyleVar_FrameRounding
    FrameBorderSize = imgui.ImGuiStyleVar_FrameBorderSize
    ItemSpacing = imgui.ImGuiStyleVar_ItemSpacing
    ItemInnerSpacing = imgui.ImGuiStyleVar_ItemInnerSpacing
    IndentSpacing = imgui.ImGuiStyleVar_IndentSpacing
    CellPadding = imgui.ImGuiStyleVar_CellPadding
    ScrollbarSize = imgui.ImGuiStyleVar_ScrollbarSize
    ScrollbarRounding = imgui.ImGuiStyleVar_ScrollbarRounding
    GrabMinSize = imgui.ImGuiStyleVar_GrabMinSize
    GrabRounding = imgui.ImGuiStyleVar_GrabRounding
    TabRounding = imgui.ImGuiStyleVar_TabRounding
    TabBorderSize = imgui.ImGuiStyleVar_TabBorderSize
    TabBarBorderSize = imgui.ImGuiStyleVar_TabBarBorderSize
    TabBarOverlineSize = imgui.ImGuiStyleVar_TabBarOverlineSize
    TableAngledHeadersAngle = imgui.ImGuiStyleVar_TableAngledHeadersAngle
    TableAngledHeadersTextAlign = imgui.ImGuiStyleVar_TableAngledHeadersTextAlign
    ButtonTextAlign = imgui.ImGuiStyleVar_ButtonTextAlign
    SelectableTextAlign = imgui.ImGuiStyleVar_SelectableTextAlign
    SeparatorTextBorderSize = imgui.ImGuiStyleVar_SeparatorTextBorderSize
    SeparatorTextAlign = imgui.ImGuiStyleVar_SeparatorTextAlign
    SeparatorTextPadding = imgui.ImGuiStyleVar_SeparatorTextPadding

cpdef enum class ImGuiColorIndex:
    Text = imgui.ImGuiCol_Text
    TextDisabled = imgui.ImGuiCol_TextDisabled
    WindowBg = imgui.ImGuiCol_WindowBg
    ChildBg = imgui.ImGuiCol_ChildBg
    PopupBg = imgui.ImGuiCol_PopupBg
    Border = imgui.ImGuiCol_Border
    BorderShadow = imgui.ImGuiCol_BorderShadow
    FrameBg = imgui.ImGuiCol_FrameBg
    FrameBgHovered = imgui.ImGuiCol_FrameBgHovered
    FrameBgActive = imgui.ImGuiCol_FrameBgActive
    TitleBg = imgui.ImGuiCol_TitleBg
    TitleBgActive = imgui.ImGuiCol_TitleBgActive
    TitleBgCollapsed = imgui.ImGuiCol_TitleBgCollapsed
    MenuBarBg = imgui.ImGuiCol_MenuBarBg
    ScrollbarBg = imgui.ImGuiCol_ScrollbarBg
    ScrollbarGrab = imgui.ImGuiCol_ScrollbarGrab
    ScrollbarGrabHovered = imgui.ImGuiCol_ScrollbarGrabHovered
    ScrollbarGrabActive = imgui.ImGuiCol_ScrollbarGrabActive
    CheckMark = imgui.ImGuiCol_CheckMark
    SliderGrab = imgui.ImGuiCol_SliderGrab
    SliderGrabActive = imgui.ImGuiCol_SliderGrabActive
    Button = imgui.ImGuiCol_Button
    ButtonHovered = imgui.ImGuiCol_ButtonHovered
    ButtonActive = imgui.ImGuiCol_ButtonActive
    Header = imgui.ImGuiCol_Header
    HeaderHovered = imgui.ImGuiCol_HeaderHovered
    HeaderActive = imgui.ImGuiCol_HeaderActive
    Separator = imgui.ImGuiCol_Separator
    SeparatorHovered = imgui.ImGuiCol_SeparatorHovered
    SeparatorActive = imgui.ImGuiCol_SeparatorActive
    ResizeGrip = imgui.ImGuiCol_ResizeGrip
    ResizeGripHovered = imgui.ImGuiCol_ResizeGripHovered
    ResizeGripActive = imgui.ImGuiCol_ResizeGripActive
    TabHovered = imgui.ImGuiCol_TabHovered
    Tab = imgui.ImGuiCol_Tab
    TabSelected = imgui.ImGuiCol_TabSelected
    TabSelectedOverline = imgui.ImGuiCol_TabSelectedOverline
    TabDimmed = imgui.ImGuiCol_TabDimmed
    TabDimmedSelected = imgui.ImGuiCol_TabDimmedSelected
    TabDimmedSelectedOverline = imgui.ImGuiCol_TabDimmedSelectedOverline
    PlotLines = imgui.ImGuiCol_PlotLines
    PlotLinesHovered = imgui.ImGuiCol_PlotLinesHovered
    PlotHistogram = imgui.ImGuiCol_PlotHistogram
    PlotHistogramHovered = imgui.ImGuiCol_PlotHistogramHovered
    TableHeaderBg = imgui.ImGuiCol_TableHeaderBg
    TableBorderStrong = imgui.ImGuiCol_TableBorderStrong
    TableBorderLight = imgui.ImGuiCol_TableBorderLight
    TableRowBg = imgui.ImGuiCol_TableRowBg
    TableRowBgAlt = imgui.ImGuiCol_TableRowBgAlt
    TextLink = imgui.ImGuiCol_TextLink
    TextSelectedBg = imgui.ImGuiCol_TextSelectedBg
    DragDropTarget = imgui.ImGuiCol_DragDropTarget
    NavCursor = imgui.ImGuiCol_NavCursor
    NavWindowingHighlight = imgui.ImGuiCol_NavWindowingHighlight
    NavWindowingDimBg = imgui.ImGuiCol_NavWindowingDimBg
    ModalWindowDimBg = imgui.ImGuiCol_ModalWindowDimBg

cpdef enum class ImPlotStyleIndex:
    LineWeight = implot.ImPlotStyleVar_LineWeight
    Marker = implot.ImPlotStyleVar_Marker
    MarkerSize = implot.ImPlotStyleVar_MarkerSize
    MarkerWeight = implot.ImPlotStyleVar_MarkerWeight
    FillAlpha = implot.ImPlotStyleVar_FillAlpha
    ErrorBarSize = implot.ImPlotStyleVar_ErrorBarSize
    ErrorBarWeight = implot.ImPlotStyleVar_ErrorBarWeight
    DigitalBitHeight = implot.ImPlotStyleVar_DigitalBitHeight
    DigitalBitGap = implot.ImPlotStyleVar_DigitalBitGap
    PlotBorderSize = implot.ImPlotStyleVar_PlotBorderSize
    MinorAlpha = implot.ImPlotStyleVar_MinorAlpha
    MajorTickLen = implot.ImPlotStyleVar_MajorTickLen
    MinorTickLen = implot.ImPlotStyleVar_MinorTickLen
    MajorTickSize = implot.ImPlotStyleVar_MajorTickSize
    MinorTickSize = implot.ImPlotStyleVar_MinorTickSize
    MajorGridSize = implot.ImPlotStyleVar_MajorGridSize
    MinorGridSize = implot.ImPlotStyleVar_MinorGridSize
    PlotPadding = implot.ImPlotStyleVar_PlotPadding
    LabelPadding = implot.ImPlotStyleVar_LabelPadding
    LegendPadding = implot.ImPlotStyleVar_LegendPadding
    LegendInnerPadding = implot.ImPlotStyleVar_LegendInnerPadding
    LegendSpacing = implot.ImPlotStyleVar_LegendSpacing
    MousePosPadding = implot.ImPlotStyleVar_MousePosPadding
    AnnotationPadding = implot.ImPlotStyleVar_AnnotationPadding
    FitPadding = implot.ImPlotStyleVar_FitPadding
    PlotDefaultSize = implot.ImPlotStyleVar_PlotDefaultSize
    PlotMinSize = implot.ImPlotStyleVar_PlotMinSize

cpdef enum class ImPlotColorIndex:
    Line = implot.ImPlotCol_Line
    Fill = implot.ImPlotCol_Fill
    MarkerOutline = implot.ImPlotCol_MarkerOutline
    MarkerFill = implot.ImPlotCol_MarkerFill
    ErrorBar = implot.ImPlotCol_ErrorBar
    FrameBg = implot.ImPlotCol_FrameBg
    PlotBg = implot.ImPlotCol_PlotBg
    PlotBorder = implot.ImPlotCol_PlotBorder
    LegendBg = implot.ImPlotCol_LegendBg
    LegendBorder = implot.ImPlotCol_LegendBorder
    LegendText = implot.ImPlotCol_LegendText
    TitleText = implot.ImPlotCol_TitleText
    InlayText = implot.ImPlotCol_InlayText
    AxisText = implot.ImPlotCol_AxisText
    AxisGrid = implot.ImPlotCol_AxisGrid
    AxisTick = implot.ImPlotCol_AxisTick
    AxisBg = implot.ImPlotCol_AxisBg
    AxisBgHovered = implot.ImPlotCol_AxisBgHovered
    AxisBgActive = implot.ImPlotCol_AxisBgActive
    Selection = implot.ImPlotCol_Selection
    Crosshairs = implot.ImPlotCol_Crosshairs

