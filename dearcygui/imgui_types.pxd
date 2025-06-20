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

cdef bint is_ButtonDirection(value)
cdef object make_ButtonDirection(value)

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

cdef int32_t check_Axis(value)
cdef object make_Axis(int32_t value)

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
    ALPHA = imgui.ImGuiStyleVar_Alpha
    DISABLED_ALPHA = imgui.ImGuiStyleVar_DisabledAlpha
    WINDOW_PADDING = imgui.ImGuiStyleVar_WindowPadding
    WINDOW_ROUNDING = imgui.ImGuiStyleVar_WindowRounding
    WINDOW_BORDER_SIZE = imgui.ImGuiStyleVar_WindowBorderSize
    WINDOW_MIN_SIZE = imgui.ImGuiStyleVar_WindowMinSize
    WINDOW_TITLE_ALIGN = imgui.ImGuiStyleVar_WindowTitleAlign
    CHILD_ROUNDING = imgui.ImGuiStyleVar_ChildRounding
    CHILD_BORDER_SIZE = imgui.ImGuiStyleVar_ChildBorderSize
    POPUP_ROUNDING = imgui.ImGuiStyleVar_PopupRounding
    POPUP_BORDER_SIZE = imgui.ImGuiStyleVar_PopupBorderSize
    FRAME_PADDING = imgui.ImGuiStyleVar_FramePadding
    FRAME_ROUNDING = imgui.ImGuiStyleVar_FrameRounding
    FRAME_BORDER_SIZE = imgui.ImGuiStyleVar_FrameBorderSize
    ITEM_SPACING = imgui.ImGuiStyleVar_ItemSpacing
    ITEM_INNER_SPACING = imgui.ImGuiStyleVar_ItemInnerSpacing
    INDENT_SPACING = imgui.ImGuiStyleVar_IndentSpacing
    CELL_PADDING = imgui.ImGuiStyleVar_CellPadding
    SCROLLBAR_SIZE = imgui.ImGuiStyleVar_ScrollbarSize
    SCROLLBAR_ROUNDING = imgui.ImGuiStyleVar_ScrollbarRounding
    GRAB_MIN_SIZE = imgui.ImGuiStyleVar_GrabMinSize
    GRAB_ROUNDING = imgui.ImGuiStyleVar_GrabRounding
    TAB_ROUNDING = imgui.ImGuiStyleVar_TabRounding
    TAB_BORDER_SIZE = imgui.ImGuiStyleVar_TabBorderSize
    TAB_BAR_BORDER_SIZE = imgui.ImGuiStyleVar_TabBarBorderSize
    TAB_BAR_OVERLINE_SIZE = imgui.ImGuiStyleVar_TabBarOverlineSize
    TABLE_ANGLED_HEADERS_ANGLE = imgui.ImGuiStyleVar_TableAngledHeadersAngle
    TABLE_ANGLED_HEADERS_TEXT_ALIGN = imgui.ImGuiStyleVar_TableAngledHeadersTextAlign
    BUTTON_TEXT_ALIGN = imgui.ImGuiStyleVar_ButtonTextAlign
    SELECTABLE_TEXT_ALIGN = imgui.ImGuiStyleVar_SelectableTextAlign
    SEPARATOR_TEXT_BORDER_SIZE = imgui.ImGuiStyleVar_SeparatorTextBorderSize
    SEPARATOR_TEXT_ALIGN = imgui.ImGuiStyleVar_SeparatorTextAlign
    SEPARATOR_TEXT_PADDING = imgui.ImGuiStyleVar_SeparatorTextPadding

cpdef enum class ImGuiColorIndex:
    TEXT = imgui.ImGuiCol_Text
    TEXT_DISABLED = imgui.ImGuiCol_TextDisabled
    WINDOW_BG = imgui.ImGuiCol_WindowBg
    CHILD_BG = imgui.ImGuiCol_ChildBg
    POPUP_BG = imgui.ImGuiCol_PopupBg
    BORDER = imgui.ImGuiCol_Border
    BORDER_SHADOW = imgui.ImGuiCol_BorderShadow
    FRAME_BG = imgui.ImGuiCol_FrameBg
    FRAME_BG_HOVERED = imgui.ImGuiCol_FrameBgHovered
    FRAME_BG_ACTIVE = imgui.ImGuiCol_FrameBgActive
    TITLE_BG = imgui.ImGuiCol_TitleBg
    TITLE_BG_ACTIVE = imgui.ImGuiCol_TitleBgActive
    TITLE_BG_COLLAPSED = imgui.ImGuiCol_TitleBgCollapsed
    MENU_BAR_BG = imgui.ImGuiCol_MenuBarBg
    SCROLLBAR_BG = imgui.ImGuiCol_ScrollbarBg
    SCROLLBAR_GRAB = imgui.ImGuiCol_ScrollbarGrab
    SCROLLBAR_GRAB_HOVERED = imgui.ImGuiCol_ScrollbarGrabHovered
    SCROLLBAR_GRAB_ACTIVE = imgui.ImGuiCol_ScrollbarGrabActive
    CHECK_MARK = imgui.ImGuiCol_CheckMark
    SLIDER_GRAB = imgui.ImGuiCol_SliderGrab
    SLIDER_GRAB_ACTIVE = imgui.ImGuiCol_SliderGrabActive
    BUTTON = imgui.ImGuiCol_Button
    BUTTON_HOVERED = imgui.ImGuiCol_ButtonHovered
    BUTTON_ACTIVE = imgui.ImGuiCol_ButtonActive
    HEADER = imgui.ImGuiCol_Header
    HEADER_HOVERED = imgui.ImGuiCol_HeaderHovered
    HEADER_ACTIVE = imgui.ImGuiCol_HeaderActive
    SEPARATOR = imgui.ImGuiCol_Separator
    SEPARATOR_HOVERED = imgui.ImGuiCol_SeparatorHovered
    SEPARATOR_ACTIVE = imgui.ImGuiCol_SeparatorActive
    RESIZE_GRIP = imgui.ImGuiCol_ResizeGrip
    RESIZE_GRIP_HOVERED = imgui.ImGuiCol_ResizeGripHovered
    RESIZE_GRIP_ACTIVE = imgui.ImGuiCol_ResizeGripActive
    TAB_HOVERED = imgui.ImGuiCol_TabHovered
    TAB = imgui.ImGuiCol_Tab
    TAB_SELECTED = imgui.ImGuiCol_TabSelected
    TAB_SELECTED_OVERLINE = imgui.ImGuiCol_TabSelectedOverline
    TAB_DIMMED = imgui.ImGuiCol_TabDimmed
    TAB_DIMMED_SELECTED = imgui.ImGuiCol_TabDimmedSelected
    TAB_DIMMED_SELECTED_OVERLINE = imgui.ImGuiCol_TabDimmedSelectedOverline
    PLOT_LINES = imgui.ImGuiCol_PlotLines
    PLOT_LINES_HOVERED = imgui.ImGuiCol_PlotLinesHovered
    PLOT_HISTOGRAM = imgui.ImGuiCol_PlotHistogram
    PLOT_HISTOGRAM_HOVERED = imgui.ImGuiCol_PlotHistogramHovered
    TABLE_HEADER_BG = imgui.ImGuiCol_TableHeaderBg
    TABLE_BORDER_STRONG = imgui.ImGuiCol_TableBorderStrong
    TABLE_BORDER_LIGHT = imgui.ImGuiCol_TableBorderLight
    TABLE_ROW_BG = imgui.ImGuiCol_TableRowBg
    TABLE_ROW_BG_ALT = imgui.ImGuiCol_TableRowBgAlt
    TEXT_LINK = imgui.ImGuiCol_TextLink
    TEXT_SELECTED_BG = imgui.ImGuiCol_TextSelectedBg
    DRAG_DROP_TARGET = imgui.ImGuiCol_DragDropTarget
    NAV_CURSOR = imgui.ImGuiCol_NavCursor
    NAV_WINDOWING_HIGHLIGHT = imgui.ImGuiCol_NavWindowingHighlight
    NAV_WINDOWING_DIM_BG = imgui.ImGuiCol_NavWindowingDimBg
    MODAL_WINDOW_DIM_BG = imgui.ImGuiCol_ModalWindowDimBg

cpdef enum class ImPlotStyleIndex:
    LINE_WEIGHT = implot.ImPlotStyleVar_LineWeight
    MARKER = implot.ImPlotStyleVar_Marker
    MARKER_SIZE = implot.ImPlotStyleVar_MarkerSize
    MARKER_WEIGHT = implot.ImPlotStyleVar_MarkerWeight
    FILL_ALPHA = implot.ImPlotStyleVar_FillAlpha
    ERROR_BAR_SIZE = implot.ImPlotStyleVar_ErrorBarSize
    ERROR_BAR_WEIGHT = implot.ImPlotStyleVar_ErrorBarWeight
    DIGITAL_BIT_HEIGHT = implot.ImPlotStyleVar_DigitalBitHeight
    DIGITAL_BIT_GAP = implot.ImPlotStyleVar_DigitalBitGap
    PLOT_BORDER_SIZE = implot.ImPlotStyleVar_PlotBorderSize
    MINOR_ALPHA = implot.ImPlotStyleVar_MinorAlpha
    MAJOR_TICK_LEN = implot.ImPlotStyleVar_MajorTickLen
    MINOR_TICK_LEN = implot.ImPlotStyleVar_MinorTickLen
    MAJOR_TICK_SIZE = implot.ImPlotStyleVar_MajorTickSize
    MINOR_TICK_SIZE = implot.ImPlotStyleVar_MinorTickSize
    MAJOR_GRID_SIZE = implot.ImPlotStyleVar_MajorGridSize
    MINOR_GRID_SIZE = implot.ImPlotStyleVar_MinorGridSize
    PLOT_PADDING = implot.ImPlotStyleVar_PlotPadding
    LABEL_PADDING = implot.ImPlotStyleVar_LabelPadding
    LEGEND_PADDING = implot.ImPlotStyleVar_LegendPadding
    LEGEND_INNER_PADDING = implot.ImPlotStyleVar_LegendInnerPadding
    LEGEND_SPACING = implot.ImPlotStyleVar_LegendSpacing
    MOUSE_POS_PADDING = implot.ImPlotStyleVar_MousePosPadding
    ANNOTATION_PADDING = implot.ImPlotStyleVar_AnnotationPadding
    FIT_PADDING = implot.ImPlotStyleVar_FitPadding
    PLOT_DEFAULT_SIZE = implot.ImPlotStyleVar_PlotDefaultSize
    PLOT_MIN_SIZE = implot.ImPlotStyleVar_PlotMinSize

cpdef enum class ImPlotColorIndex:
    LINE = implot.ImPlotCol_Line
    FILL = implot.ImPlotCol_Fill
    MARKER_OUTLINE = implot.ImPlotCol_MarkerOutline
    MARKER_FILL = implot.ImPlotCol_MarkerFill
    ERROR_BAR = implot.ImPlotCol_ErrorBar
    FRAME_BG = implot.ImPlotCol_FrameBg
    PLOT_BG = implot.ImPlotCol_PlotBg
    PLOT_BORDER = implot.ImPlotCol_PlotBorder
    LEGEND_BG = implot.ImPlotCol_LegendBg
    LEGEND_BORDER = implot.ImPlotCol_LegendBorder
    LEGEND_TEXT = implot.ImPlotCol_LegendText
    TITLE_TEXT = implot.ImPlotCol_TitleText
    INLAY_TEXT = implot.ImPlotCol_InlayText
    AXIS_TEXT = implot.ImPlotCol_AxisText
    AXIS_GRID = implot.ImPlotCol_AxisGrid
    AXIS_TICK = implot.ImPlotCol_AxisTick
    AXIS_BG = implot.ImPlotCol_AxisBg
    AXIS_BG_HOVERED = implot.ImPlotCol_AxisBgHovered
    AXIS_BG_ACTIVE = implot.ImPlotCol_AxisBgActive
    SELECTION = implot.ImPlotCol_Selection
    CROSSHAIRS = implot.ImPlotCol_Crosshairs

