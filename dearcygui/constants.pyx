#!python
#cython: language_level=3
#cython: boundscheck=False
#cython: wraparound=False
#cython: nonecheck=False
#cython: embedsignature=False
#cython: cdivision=True
#cython: cdivision_warnings=False
#cython: always_allow_keywords=False
#cython: profile=False
#cython: infer_types=False
#cython: initializedcheck=False
#cython: c_line_in_traceback=False
#cython: auto_pickle=False
#distutils: language=c++

import sys
from dearcygui.wrapper cimport imgui, imnodes, implot

mvDir_None = imgui.ImGuiDir_None
mvDir_Left = imgui.ImGuiDir_Left
mvDir_Right = imgui.ImGuiDir_Right
mvDir_Up = imgui.ImGuiDir_Up
mvDir_Down = imgui.ImGuiDir_Down


mvColorEdit_AlphaPreviewNone = 0
mvColorEdit_AlphaPreview = imgui.ImGuiColorEditFlags_AlphaPreview
mvColorEdit_AlphaPreviewHalf = imgui.ImGuiColorEditFlags_AlphaPreviewHalf
mvColorEdit_uint8 = imgui.ImGuiColorEditFlags_Uint8
mvColorEdit_float = imgui.ImGuiColorEditFlags_Float
mvColorEdit_rgb = imgui.ImGuiColorEditFlags_DisplayRGB
mvColorEdit_hsv = imgui.ImGuiColorEditFlags_DisplayHSV
mvColorEdit_hex = imgui.ImGuiColorEditFlags_DisplayHex
mvColorEdit_input_rgb = imgui.ImGuiColorEditFlags_InputRGB
mvColorEdit_input_hsv = imgui.ImGuiColorEditFlags_InputHSV

mvPlotColormap_Default = implot.ImPlotColormap_Deep # implot.ImPlot default colormap (n=10)
mvPlotColormap_Deep = implot.ImPlotColormap_Deep # a.k.a. seaborn deep (default) (n=10)
mvPlotColormap_Dark = implot.ImPlotColormap_Dark # a.k.a. matplotlib "Set1"(n=9)
mvPlotColormap_Pastel = implot.ImPlotColormap_Pastel # a.k.a. matplotlib "Pastel1" (n=9)
mvPlotColormap_Paired = implot.ImPlotColormap_Paired # a.k.a. matplotlib "Paired"  (n=12)
mvPlotColormap_Viridis = implot.ImPlotColormap_Viridis # a.k.a. matplotlib "viridis" (n=11)
mvPlotColormap_Plasma = implot.ImPlotColormap_Plasma # a.k.a. matplotlib "plasma"  (n=11)
mvPlotColormap_Hot = implot.ImPlotColormap_Hot # a.k.a. matplotlib/MATLAB "hot"  (n=11)
mvPlotColormap_Cool = implot.ImPlotColormap_Cool # a.k.a. matplotlib/MATLAB "cool" (n=11)
mvPlotColormap_Pink = implot.ImPlotColormap_Pink # a.k.a. matplotlib/MATLAB "pink" (n=11)
mvPlotColormap_Jet = implot.ImPlotColormap_Jet # a.k.a. MATLAB "jet" (n=11)
mvPlotColormap_Twilight = implot.ImPlotColormap_Twilight # a.k.a. MATLAB "twilight" (n=11)
mvPlotColormap_RdBu = implot.ImPlotColormap_RdBu # red/blue, Color Brewer(n=11)
mvPlotColormap_BrBG = implot.ImPlotColormap_BrBG # brown/blue-green, Color Brewer (n=11)
mvPlotColormap_PiYG = implot.ImPlotColormap_PiYG # pink/yellow-green, Color Brewer (n=11)
mvPlotColormap_Spectral = implot.ImPlotColormap_Spectral # color spectrum, Color Brewer (n=11)
mvPlotColormap_Greys = implot.ImPlotColormap_Greys # white/black (n=11)

mvColorPicker_bar = imgui.ImGuiColorEditFlags_PickerHueBar
mvColorPicker_wheel = imgui.ImGuiColorEditFlags_PickerHueWheel



mvNode_PinShape_Circle = imnodes.ImNodesPinShape_Circle
mvNode_PinShape_CircleFilled = imnodes.ImNodesPinShape_CircleFilled
mvNode_PinShape_Triangle = imnodes.ImNodesPinShape_Triangle
mvNode_PinShape_TriangleFilled = imnodes.ImNodesPinShape_TriangleFilled
mvNode_PinShape_Quad = imnodes.ImNodesPinShape_Quad
mvNode_PinShape_QuadFilled = imnodes.ImNodesPinShape_QuadFilled



mvXAxis = implot.ImAxis_X1
mvXAxis2 = implot.ImAxis_X2
mvXAxis3 = implot.ImAxis_X3
mvYAxis = implot.ImAxis_Y1
mvYAxis2 = implot.ImAxis_Y2
mvYAxis3 = implot.ImAxis_Y3

mvPlotScale_Linear = implot.ImPlotScale_Linear  # default linear scale
mvPlotScale_Time = implot.ImPlotScale_Time  # date/time scale
mvPlotScale_Log10 = implot.ImPlotScale_Log10  # base 10 logartithmic scale
mvPlotScale_SymLog = implot.ImPlotScale_SymLog  # symmetric log scale

mvPlotMarker_None = implot.ImPlotMarker_None  # no marker
mvPlotMarker_Circle =  implot.ImPlotMarker_Circle  # a circle marker will be rendered at each point
mvPlotMarker_Square =  implot.ImPlotMarker_Square  # a square maker will be rendered at each point
mvPlotMarker_Diamond =  implot.ImPlotMarker_Diamond  # a diamond marker will be rendered at each point
mvPlotMarker_Up =  implot.ImPlotMarker_Up  # an upward-pointing triangle marker will up rendered at each point
mvPlotMarker_Down =  implot.ImPlotMarker_Down  # an downward-pointing triangle marker will up rendered at each point
mvPlotMarker_Left =  implot.ImPlotMarker_Left  # an leftward-pointing triangle marker will up rendered at each point
mvPlotMarker_Right =  implot.ImPlotMarker_Right  # an rightward-pointing triangle marker will up rendered at each point
mvPlotMarker_Cross =  implot.ImPlotMarker_Cross  # a cross marker will be rendered at each point (not filled)
mvPlotMarker_Plus =  implot.ImPlotMarker_Plus  # a plus marker will be rendered at each point (not filled)
mvPlotMarker_Asterisk =  implot.ImPlotMarker_Asterisk # a asterisk marker will be rendered at each point (not filled)

mvPlot_Location_Center = implot.ImPlotLocation_Center
mvPlot_Location_North = implot.ImPlotLocation_North
mvPlot_Location_South = implot.ImPlotLocation_South
mvPlot_Location_West = implot.ImPlotLocation_West
mvPlot_Location_East = implot.ImPlotLocation_East
mvPlot_Location_NorthWest = implot.ImPlotLocation_NorthWest
mvPlot_Location_NorthEast = implot.ImPlotLocation_NorthEast
mvPlot_Location_SouthWest = implot.ImPlotLocation_SouthWest
mvPlot_Location_SouthEast = implot.ImPlotLocation_SouthEast

mvNodeMiniMap_Location_BottomLeft = imnodes.ImNodesMiniMapLocation_BottomLeft
mvNodeMiniMap_Location_BottomRight = imnodes.ImNodesMiniMapLocation_BottomRight
mvNodeMiniMap_Location_TopLeft =imnodes. ImNodesMiniMapLocation_TopLeft
mvNodeMiniMap_Location_TopRight = imnodes.ImNodesMiniMapLocation_TopRight

mvTable_SizingFixedFit = imgui.ImGuiTableFlags_SizingFixedFit
mvTable_SizingFixedSame = imgui.ImGuiTableFlags_SizingFixedSame
mvTable_SizingStretchProp = imgui.ImGuiTableFlags_SizingStretchProp
mvTable_SizingStretchSame = imgui.ImGuiTableFlags_SizingStretchSame

# nodes
mvNodeCol_NodeBackground = imnodes.ImNodesCol_NodeBackground
mvNodeCol_NodeBackgroundHovered = imnodes.ImNodesCol_NodeBackgroundHovered
mvNodeCol_NodeBackgroundSelected = imnodes.ImNodesCol_NodeBackgroundSelected
mvNodeCol_NodeOutline = imnodes.ImNodesCol_NodeOutline
mvNodeCol_TitleBar = imnodes.ImNodesCol_TitleBar
mvNodeCol_TitleBarHovered = imnodes.ImNodesCol_TitleBarHovered
mvNodeCol_TitleBarSelected = imnodes.ImNodesCol_TitleBarSelected
mvNodeCol_Link = imnodes.ImNodesCol_Link
mvNodeCol_LinkHovered = imnodes.ImNodesCol_LinkHovered
mvNodeCol_LinkSelected = imnodes.ImNodesCol_LinkSelected
mvNodeCol_Pin = imnodes.ImNodesCol_Pin
mvNodeCol_PinHovered = imnodes.ImNodesCol_PinHovered
mvNodeCol_BoxSelector = imnodes.ImNodesCol_BoxSelector
mvNodeCol_BoxSelectorOutline = imnodes.ImNodesCol_BoxSelectorOutline
mvNodeCol_GridBackground = imnodes.ImNodesCol_GridBackground
mvNodeCol_GridLine = imnodes.ImNodesCol_GridLine
mvNodesCol_GridLinePrimary = imnodes.ImNodesCol_GridLinePrimary
mvNodesCol_MiniMapBackground = imnodes.ImNodesCol_MiniMapBackground
mvNodesCol_MiniMapBackgroundHovered = imnodes.ImNodesCol_MiniMapBackgroundHovered
mvNodesCol_MiniMapOutline = imnodes.ImNodesCol_MiniMapOutline
mvNodesCol_MiniMapOutlineHovered = imnodes.ImNodesCol_MiniMapOutlineHovered
mvNodesCol_MiniMapNodeBackground = imnodes.ImNodesCol_MiniMapNodeBackground
mvNodesCol_MiniMapNodeBackgroundHovered = imnodes.ImNodesCol_MiniMapNodeBackgroundHovered
mvNodesCol_MiniMapNodeBackgroundSelected = imnodes.ImNodesCol_MiniMapNodeBackgroundSelected
mvNodesCol_MiniMapNodeOutline = imnodes.ImNodesCol_MiniMapNodeOutline
mvNodesCol_MiniMapLink = imnodes.ImNodesCol_MiniMapLink
mvNodesCol_MiniMapLinkSelected = imnodes.ImNodesCol_MiniMapLinkSelected
mvNodesCol_MiniMapCanvas = imnodes.ImNodesCol_MiniMapCanvas
mvNodesCol_MiniMapCanvasOutline = imnodes.ImNodesCol_MiniMapCanvasOutline


mvStyleVar_Alpha = imgui.ImGuiStyleVar_Alpha # float Alpha
mvStyleVar_DisabledAlpha = imgui.ImGuiStyleVar_DisabledAlpha # float DisabledAlpha
mvStyleVar_WindowPadding = imgui.ImGuiStyleVar_WindowPadding # ImVec2WindowPadding
mvStyleVar_WindowRounding = imgui.ImGuiStyleVar_WindowRounding   # float WindowRounding
mvStyleVar_WindowBorderSize = imgui.ImGuiStyleVar_WindowBorderSize   # float WindowBorderSize
mvStyleVar_WindowMinSize = imgui.ImGuiStyleVar_WindowMinSize # ImVec2WindowMinSize
mvStyleVar_WindowTitleAlign = imgui.ImGuiStyleVar_WindowTitleAlign   # ImVec2WindowTitleAlign
mvStyleVar_ChildRounding = imgui.ImGuiStyleVar_ChildRounding # float ChildRounding
mvStyleVar_ChildBorderSize = imgui.ImGuiStyleVar_ChildBorderSize # float ChildBorderSize
mvStyleVar_PopupRounding = imgui.ImGuiStyleVar_PopupRounding # float PopupRounding
mvStyleVar_PopupBorderSize = imgui.ImGuiStyleVar_PopupBorderSize # float PopupBorderSize
mvStyleVar_FramePadding = imgui.ImGuiStyleVar_FramePadding   # ImVec2FramePadding
mvStyleVar_FrameRounding = imgui.ImGuiStyleVar_FrameRounding # float FrameRounding
mvStyleVar_FrameBorderSize = imgui.ImGuiStyleVar_FrameBorderSize # float FrameBorderSize
mvStyleVar_ItemSpacing = imgui.ImGuiStyleVar_ItemSpacing # ImVec2ItemSpacing
mvStyleVar_ItemInnerSpacing = imgui.ImGuiStyleVar_ItemInnerSpacing   # ImVec2ItemInnerSpacing
mvStyleVar_IndentSpacing = imgui.ImGuiStyleVar_IndentSpacing # float IndentSpacing
mvStyleVar_CellPadding = imgui.ImGuiStyleVar_CellPadding # ImVec2CellPadding
mvStyleVar_ScrollbarSize = imgui.ImGuiStyleVar_ScrollbarSize # float ScrollbarSize
mvStyleVar_ScrollbarRounding = imgui.ImGuiStyleVar_ScrollbarRounding # float ScrollbarRounding
mvStyleVar_GrabMinSize = imgui.ImGuiStyleVar_GrabMinSize # float GrabMinSize
mvStyleVar_GrabRounding = imgui.ImGuiStyleVar_GrabRounding   # float GrabRounding
mvStyleVar_TabRounding = imgui.ImGuiStyleVar_TabRounding # float TabRounding
mvStyleVar_TabBorderSize = imgui.ImGuiStyleVar_TabBorderSize	# float TabBorderSize
mvStyleVar_TabBarBorderSize = imgui.ImGuiStyleVar_TabBarBorderSize	# float TabBarBorderSize
mvStyleVar_TableAngledHeadersAngle = imgui.ImGuiStyleVar_TableAngledHeadersAngle# float TableAngledHeadersAngle
mvStyleVar_TableAngledHeadersTextAlign = imgui.ImGuiStyleVar_TableAngledHeadersTextAlign # ImVec2 TableAngledHeadersTextAlign
mvStyleVar_ButtonTextAlign = imgui.ImGuiStyleVar_ButtonTextAlign # ImVec2ButtonTextAlign
mvStyleVar_SelectableTextAlign = imgui.ImGuiStyleVar_SelectableTextAlign # ImVec2SelectableTextAlign
mvStyleVar_SeparatorTextBorderSize = imgui.ImGuiStyleVar_SeparatorTextBorderSize	# float SeparatorTextBorderSize
mvStyleVar_SeparatorTextAlign = imgui.ImGuiStyleVar_SeparatorTextAlign# ImVec2SeparatorTextAlign
mvStyleVar_SeparatorTextPadding = imgui.ImGuiStyleVar_SeparatorTextPadding	# ImVec2SeparatorTextPadding

# item styling variables
mvPlotStyleVar_LineWeight = implot.ImPlotStyleVar_LineWeight # float,  plot item line weight in pixels
mvPlotStyleVar_Marker = implot.ImPlotStyleVar_Marker # int,marker specification
mvPlotStyleVar_MarkerSize = implot.ImPlotStyleVar_MarkerSize # float,  marker size in pixels (roughly the marker's "radius")
mvPlotStyleVar_MarkerWeight =   implot.ImPlotStyleVar_MarkerWeight   # float,  plot outline weight of markers in pixels
mvPlotStyleVar_FillAlpha =  implot.ImPlotStyleVar_FillAlpha  # float,  alpha modifier applied to all plot item fills
mvPlotStyleVar_ErrorBarSize =   implot.ImPlotStyleVar_ErrorBarSize   # float,  error bar whisker width in pixels
mvPlotStyleVar_ErrorBarWeight = implot.ImPlotStyleVar_ErrorBarWeight # float,  error bar whisker weight in pixels
mvPlotStyleVar_DigitalBitHeight =   implot.ImPlotStyleVar_DigitalBitHeight   # float,  digital channels bit height (at 1) in pixels
mvPlotStyleVar_DigitalBitGap =  implot.ImPlotStyleVar_DigitalBitGap  # float,  digital channels bit padding gap in pixels

# plot styling variables
mvPlotStyleVar_PlotBorderSize = implot.ImPlotStyleVar_PlotBorderSize # float,  thickness of border around plot area
mvPlotStyleVar_MinorAlpha = implot.ImPlotStyleVar_MinorAlpha # float,  alpha multiplier applied to minor axis grid lines
mvPlotStyleVar_MajorTickLen = implot.ImPlotStyleVar_MajorTickLen # ImVec2, major tick lengths for X and Y axes
mvPlotStyleVar_MinorTickLen = implot.ImPlotStyleVar_MinorTickLen # ImVec2, minor tick lengths for X and Y axes
mvPlotStyleVar_MajorTickSize = implot.ImPlotStyleVar_MajorTickSize   # ImVec2, line thickness of major ticks
mvPlotStyleVar_MinorTickSize = implot.ImPlotStyleVar_MinorTickSize   # ImVec2, line thickness of minor ticks
mvPlotStyleVar_MajorGridSize = implot.ImPlotStyleVar_MajorGridSize   # ImVec2, line thickness of major grid lines
mvPlotStyleVar_MinorGridSize = implot.ImPlotStyleVar_MinorGridSize   # ImVec2, line thickness of minor grid lines
mvPlotStyleVar_PlotPadding = implot.ImPlotStyleVar_PlotPadding   # ImVec2, padding between widget frame and plot area, labels, or outside legends (i.e. main padding)
mvPlotStyleVar_LabelPadding = implot.ImPlotStyleVar_LabelPadding # ImVec2, padding between axes labels, tick labels, and plot edge
mvPlotStyleVar_LegendPadding = implot.ImPlotStyleVar_LegendPadding   # ImVec2, legend padding from plot edges
mvPlotStyleVar_LegendInnerPadding = implot.ImPlotStyleVar_LegendInnerPadding # ImVec2, legend inner padding from legend edges
mvPlotStyleVar_LegendSpacing = implot.ImPlotStyleVar_LegendSpacing   # ImVec2, spacing between legend entries
mvPlotStyleVar_MousePosPadding = implot.ImPlotStyleVar_MousePosPadding   # ImVec2, padding between plot edge and interior info text
mvPlotStyleVar_AnnotationPadding = implot.ImPlotStyleVar_AnnotationPadding   # ImVec2, text padding around annotation labels
mvPlotStyleVar_FitPadding = implot.ImPlotStyleVar_FitPadding # ImVec2, additional fit padding as a percentage of the fit extents (e.g. ImVec2(0.1f,0.1f) adds 10% to the fit extents of X and Y)
mvPlotStyleVar_PlotDefaultSize = implot.ImPlotStyleVar_PlotDefaultSize   # ImVec2, default size used when ImVec2(0,0) is passed to BeginPlot
mvPlotStyleVar_PlotMinSize = implot.ImPlotStyleVar_PlotMinSize   # ImVec2, minimum size plot frame can be when shrunk

# nodes
mvNodeStyleVar_GridSpacing = imnodes.ImNodesStyleVar_GridSpacing
mvNodeStyleVar_NodeCornerRounding = imnodes.ImNodesStyleVar_NodeCornerRounding
mvNodeStyleVar_NodePadding = imnodes.ImNodesStyleVar_NodePadding
mvNodeStyleVar_NodeBorderThickness = imnodes.ImNodesStyleVar_NodeBorderThickness
mvNodeStyleVar_LinkThickness = imnodes.ImNodesStyleVar_LinkThickness
mvNodeStyleVar_LinkLineSegmentsPerLength = imnodes.ImNodesStyleVar_LinkLineSegmentsPerLength
mvNodeStyleVar_LinkHoverDistance = imnodes.ImNodesStyleVar_LinkHoverDistance
mvNodeStyleVar_PinCircleRadius = imnodes.ImNodesStyleVar_PinCircleRadius
mvNodeStyleVar_PinQuadSideLength = imnodes.ImNodesStyleVar_PinQuadSideLength
mvNodeStyleVar_PinTriangleSideLength = imnodes.ImNodesStyleVar_PinTriangleSideLength
mvNodeStyleVar_PinLineThickness = imnodes.ImNodesStyleVar_PinLineThickness
mvNodeStyleVar_PinHoverRadius = imnodes.ImNodesStyleVar_PinHoverRadius
mvNodeStyleVar_PinOffset = imnodes.ImNodesStyleVar_PinOffset
mvNodesStyleVar_MiniMapPadding = imnodes.ImNodesStyleVar_MiniMapPadding
mvNodesStyleVar_MiniMapOffset = imnodes.ImNodesStyleVar_MiniMapOffset
