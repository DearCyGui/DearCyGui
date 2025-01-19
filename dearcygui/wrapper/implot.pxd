# generated with  pxdgen thirdparty/implot/implot.h -x c++ -f defines -f importall -w ImPlot -I thirdparty/imgui/

from dearcygui.wrapper.imgui cimport ImDrawList
from dearcygui.wrapper.imgui cimport ImGuiContext
from dearcygui.wrapper.imgui cimport ImGuiDragDropFlags
from dearcygui.wrapper.imgui cimport ImGuiMouseButton
from dearcygui.wrapper.imgui cimport ImTextureID
from dearcygui.wrapper.imgui cimport ImU32
from dearcygui.wrapper.imgui cimport ImVec2
from dearcygui.wrapper.imgui cimport ImVec4

cdef extern from "implot.h" nogil:
    struct ImPlotContext:
        pass
    int IMPLOT_API
    int IMPLOT_VERSION
    long IMPLOT_AUTO = -1
    int IMPLOT_AUTO_COL
    int IMPLOT_TMP
    int IMPLOT_DEPRECATED(...)
    ctypedef int ImAxis
    ctypedef int ImPlotFlags
    ctypedef int ImPlotAxisFlags
    ctypedef int ImPlotSubplotFlags
    ctypedef int ImPlotLegendFlags
    ctypedef int ImPlotMouseTextFlags
    ctypedef int ImPlotDragToolFlags
    ctypedef int ImPlotColormapScaleFlags
    ctypedef int ImPlotItemFlags
    ctypedef int ImPlotLineFlags
    ctypedef int ImPlotScatterFlags
    ctypedef int ImPlotStairsFlags
    ctypedef int ImPlotShadedFlags
    ctypedef int ImPlotBarsFlags
    ctypedef int ImPlotBarGroupsFlags
    ctypedef int ImPlotErrorBarsFlags
    ctypedef int ImPlotStemsFlags
    ctypedef int ImPlotInfLinesFlags
    ctypedef int ImPlotPieChartFlags
    ctypedef int ImPlotHeatmapFlags
    ctypedef int ImPlotHistogramFlags
    ctypedef int ImPlotDigitalFlags
    ctypedef int ImPlotImageFlags
    ctypedef int ImPlotTextFlags
    ctypedef int ImPlotDummyFlags
    ctypedef int ImPlotCond
    ctypedef int ImPlotCol
    ctypedef int ImPlotStyleVar
    ctypedef int ImPlotScale
    ctypedef int ImPlotMarker
    ctypedef int ImPlotColormap
    ctypedef int ImPlotLocation
    ctypedef int ImPlotBin
    enum ImAxis_:
        ImAxis_X1 = 0
        ImAxis_X2 = 1
        ImAxis_X3 = 2
        ImAxis_Y1 = 3
        ImAxis_Y2 = 4
        ImAxis_Y3 = 5
        ImAxis_COUNT = 6
    enum ImPlotFlags_:
        ImPlotFlags_None = 0
        ImPlotFlags_NoTitle = 1
        ImPlotFlags_NoLegend = 2
        ImPlotFlags_NoMouseText = 4
        ImPlotFlags_NoInputs = 8
        ImPlotFlags_NoMenus = 16
        ImPlotFlags_NoBoxSelect = 32
        ImPlotFlags_NoFrame = 64
        ImPlotFlags_Equal = 128
        ImPlotFlags_Crosshairs = 256
        ImPlotFlags_CanvasOnly = 55
    enum ImPlotAxisFlags_:
        ImPlotAxisFlags_None = 0
        ImPlotAxisFlags_NoLabel = 1
        ImPlotAxisFlags_NoGridLines = 2
        ImPlotAxisFlags_NoTickMarks = 4
        ImPlotAxisFlags_NoTickLabels = 8
        ImPlotAxisFlags_NoInitialFit = 16
        ImPlotAxisFlags_NoMenus = 32
        ImPlotAxisFlags_NoSideSwitch = 64
        ImPlotAxisFlags_NoHighlight = 128
        ImPlotAxisFlags_Opposite = 256
        ImPlotAxisFlags_Foreground = 512
        ImPlotAxisFlags_Invert = 1024
        ImPlotAxisFlags_AutoFit = 2048
        ImPlotAxisFlags_RangeFit = 4096
        ImPlotAxisFlags_PanStretch = 8192
        ImPlotAxisFlags_LockMin = 16384
        ImPlotAxisFlags_LockMax = 32768
        ImPlotAxisFlags_Lock = 49152
        ImPlotAxisFlags_NoDecorations = 15
        ImPlotAxisFlags_AuxDefault = 258
    enum ImPlotSubplotFlags_:
        ImPlotSubplotFlags_None = 0
        ImPlotSubplotFlags_NoTitle = 1
        ImPlotSubplotFlags_NoLegend = 2
        ImPlotSubplotFlags_NoMenus = 4
        ImPlotSubplotFlags_NoResize = 8
        ImPlotSubplotFlags_NoAlign = 16
        ImPlotSubplotFlags_ShareItems = 32
        ImPlotSubplotFlags_LinkRows = 64
        ImPlotSubplotFlags_LinkCols = 128
        ImPlotSubplotFlags_LinkAllX = 256
        ImPlotSubplotFlags_LinkAllY = 512
        ImPlotSubplotFlags_ColMajor = 1024
    enum ImPlotLegendFlags_:
        ImPlotLegendFlags_None = 0
        ImPlotLegendFlags_NoButtons = 1
        ImPlotLegendFlags_NoHighlightItem = 2
        ImPlotLegendFlags_NoHighlightAxis = 4
        ImPlotLegendFlags_NoMenus = 8
        ImPlotLegendFlags_Outside = 16
        ImPlotLegendFlags_Horizontal = 32
        ImPlotLegendFlags_Sort = 64
    enum ImPlotMouseTextFlags_:
        ImPlotMouseTextFlags_None = 0
        ImPlotMouseTextFlags_NoAuxAxes = 1
        ImPlotMouseTextFlags_NoFormat = 2
        ImPlotMouseTextFlags_ShowAlways = 4
    enum ImPlotDragToolFlags_:
        ImPlotDragToolFlags_None = 0
        ImPlotDragToolFlags_NoCursors = 1
        ImPlotDragToolFlags_NoFit = 2
        ImPlotDragToolFlags_NoInputs = 4
        ImPlotDragToolFlags_Delayed = 8
    enum ImPlotColormapScaleFlags_:
        ImPlotColormapScaleFlags_None = 0
        ImPlotColormapScaleFlags_NoLabel = 1
        ImPlotColormapScaleFlags_Opposite = 2
        ImPlotColormapScaleFlags_Invert = 4
    enum ImPlotItemFlags_:
        ImPlotItemFlags_None = 0
        ImPlotItemFlags_NoLegend = 1
        ImPlotItemFlags_NoFit = 2
    enum ImPlotLineFlags_:
        ImPlotLineFlags_None = 0
        ImPlotLineFlags_Segments = 1024
        ImPlotLineFlags_Loop = 2048
        ImPlotLineFlags_SkipNaN = 4096
        ImPlotLineFlags_NoClip = 8192
        ImPlotLineFlags_Shaded = 16384
    enum ImPlotScatterFlags_:
        ImPlotScatterFlags_None = 0
        ImPlotScatterFlags_NoClip = 1024
    enum ImPlotStairsFlags_:
        ImPlotStairsFlags_None = 0
        ImPlotStairsFlags_PreStep = 1024
        ImPlotStairsFlags_Shaded = 2048
    enum ImPlotShadedFlags_:
        ImPlotShadedFlags_None = 0
    enum ImPlotBarsFlags_:
        ImPlotBarsFlags_None = 0
        ImPlotBarsFlags_Horizontal = 1024
    enum ImPlotBarGroupsFlags_:
        ImPlotBarGroupsFlags_None = 0
        ImPlotBarGroupsFlags_Horizontal = 1024
        ImPlotBarGroupsFlags_Stacked = 2048
    enum ImPlotErrorBarsFlags_:
        ImPlotErrorBarsFlags_None = 0
        ImPlotErrorBarsFlags_Horizontal = 1024
    enum ImPlotStemsFlags_:
        ImPlotStemsFlags_None = 0
        ImPlotStemsFlags_Horizontal = 1024
    enum ImPlotInfLinesFlags_:
        ImPlotInfLinesFlags_None = 0
        ImPlotInfLinesFlags_Horizontal = 1024
    enum ImPlotPieChartFlags_:
        ImPlotPieChartFlags_None = 0
        ImPlotPieChartFlags_Normalize = 1024
        ImPlotPieChartFlags_IgnoreHidden = 2048
    enum ImPlotHeatmapFlags_:
        ImPlotHeatmapFlags_None = 0
        ImPlotHeatmapFlags_ColMajor = 1024
    enum ImPlotHistogramFlags_:
        ImPlotHistogramFlags_None = 0
        ImPlotHistogramFlags_Horizontal = 1024
        ImPlotHistogramFlags_Cumulative = 2048
        ImPlotHistogramFlags_Density = 4096
        ImPlotHistogramFlags_NoOutliers = 8192
        ImPlotHistogramFlags_ColMajor = 16384
    enum ImPlotDigitalFlags_:
        ImPlotDigitalFlags_None = 0
    enum ImPlotImageFlags_:
        ImPlotImageFlags_None = 0
    enum ImPlotTextFlags_:
        ImPlotTextFlags_None = 0
        ImPlotTextFlags_Vertical = 1024
    enum ImPlotDummyFlags_:
        ImPlotDummyFlags_None = 0
    enum ImPlotCond_:
        ImPlotCond_None = 0
        ImPlotCond_Always = 1
        ImPlotCond_Once = 2
    enum ImPlotCol_:
        ImPlotCol_Line = 0
        ImPlotCol_Fill = 1
        ImPlotCol_MarkerOutline = 2
        ImPlotCol_MarkerFill = 3
        ImPlotCol_ErrorBar = 4
        ImPlotCol_FrameBg = 5
        ImPlotCol_PlotBg = 6
        ImPlotCol_PlotBorder = 7
        ImPlotCol_LegendBg = 8
        ImPlotCol_LegendBorder = 9
        ImPlotCol_LegendText = 10
        ImPlotCol_TitleText = 11
        ImPlotCol_InlayText = 12
        ImPlotCol_AxisText = 13
        ImPlotCol_AxisGrid = 14
        ImPlotCol_AxisTick = 15
        ImPlotCol_AxisBg = 16
        ImPlotCol_AxisBgHovered = 17
        ImPlotCol_AxisBgActive = 18
        ImPlotCol_Selection = 19
        ImPlotCol_Crosshairs = 20
        ImPlotCol_COUNT = 21
    enum ImPlotStyleVar_:
        ImPlotStyleVar_LineWeight = 0
        ImPlotStyleVar_Marker = 1
        ImPlotStyleVar_MarkerSize = 2
        ImPlotStyleVar_MarkerWeight = 3
        ImPlotStyleVar_FillAlpha = 4
        ImPlotStyleVar_ErrorBarSize = 5
        ImPlotStyleVar_ErrorBarWeight = 6
        ImPlotStyleVar_DigitalBitHeight = 7
        ImPlotStyleVar_DigitalBitGap = 8
        ImPlotStyleVar_PlotBorderSize = 9
        ImPlotStyleVar_MinorAlpha = 10
        ImPlotStyleVar_MajorTickLen = 11
        ImPlotStyleVar_MinorTickLen = 12
        ImPlotStyleVar_MajorTickSize = 13
        ImPlotStyleVar_MinorTickSize = 14
        ImPlotStyleVar_MajorGridSize = 15
        ImPlotStyleVar_MinorGridSize = 16
        ImPlotStyleVar_PlotPadding = 17
        ImPlotStyleVar_LabelPadding = 18
        ImPlotStyleVar_LegendPadding = 19
        ImPlotStyleVar_LegendInnerPadding = 20
        ImPlotStyleVar_LegendSpacing = 21
        ImPlotStyleVar_MousePosPadding = 22
        ImPlotStyleVar_AnnotationPadding = 23
        ImPlotStyleVar_FitPadding = 24
        ImPlotStyleVar_PlotDefaultSize = 25
        ImPlotStyleVar_PlotMinSize = 26
        ImPlotStyleVar_COUNT = 27
    enum ImPlotScale_:
        ImPlotScale_Linear = 0
        ImPlotScale_Time = 1
        ImPlotScale_Log10 = 2
        ImPlotScale_SymLog = 3
    enum ImPlotMarker_:
        ImPlotMarker_None = -1
        ImPlotMarker_Circle = 0
        ImPlotMarker_Square = 1
        ImPlotMarker_Diamond = 2
        ImPlotMarker_Up = 3
        ImPlotMarker_Down = 4
        ImPlotMarker_Left = 5
        ImPlotMarker_Right = 6
        ImPlotMarker_Cross = 7
        ImPlotMarker_Plus = 8
        ImPlotMarker_Asterisk = 9
        ImPlotMarker_COUNT = 10
    enum ImPlotColormap_:
        ImPlotColormap_Deep = 0
        ImPlotColormap_Dark = 1
        ImPlotColormap_Pastel = 2
        ImPlotColormap_Paired = 3
        ImPlotColormap_Viridis = 4
        ImPlotColormap_Plasma = 5
        ImPlotColormap_Hot = 6
        ImPlotColormap_Cool = 7
        ImPlotColormap_Pink = 8
        ImPlotColormap_Jet = 9
        ImPlotColormap_Twilight = 10
        ImPlotColormap_RdBu = 11
        ImPlotColormap_BrBG = 12
        ImPlotColormap_PiYG = 13
        ImPlotColormap_Spectral = 14
        ImPlotColormap_Greys = 15
    enum ImPlotLocation_:
        ImPlotLocation_Center = 0
        ImPlotLocation_North = 1
        ImPlotLocation_South = 2
        ImPlotLocation_West = 4
        ImPlotLocation_East = 8
        ImPlotLocation_NorthWest = 5
        ImPlotLocation_NorthEast = 9
        ImPlotLocation_SouthWest = 6
        ImPlotLocation_SouthEast = 10
    enum ImPlotBin_:
        ImPlotBin_Sqrt = -1
        ImPlotBin_Sturges = -2
        ImPlotBin_Rice = -3
        ImPlotBin_Scott = -4
    cppclass ImPlotPoint:
        double x
        double y
        ImPlotPoint()
        ImPlotPoint(double, double)
        ImPlotPoint(ImVec2&)
        double& operator[](size_t)
        double operator[](size_t)
    cppclass ImPlotRange:
        double Min
        double Max
        ImPlotRange()
        ImPlotRange(double, double)
        bint Contains(double)
        double Size()
        double Clamp(double)
    cppclass ImPlotRect:
        ImPlotRange X
        ImPlotRange Y
        ImPlotRect()
        ImPlotRect(double, double, double, double)
        bint Contains(ImPlotPoint&)
        bint Contains(double, double)
        ImPlotPoint Size()
        ImPlotPoint Clamp(ImPlotPoint&)
        ImPlotPoint Clamp(double, double)
        ImPlotPoint Min()
        ImPlotPoint Max()
    cppclass ImPlotStyle:
        float LineWeight
        int Marker
        float MarkerSize
        float MarkerWeight
        float FillAlpha
        float ErrorBarSize
        float ErrorBarWeight
        float DigitalBitHeight
        float DigitalBitGap
        float PlotBorderSize
        float MinorAlpha
        ImVec2 MajorTickLen
        ImVec2 MinorTickLen
        ImVec2 MajorTickSize
        ImVec2 MinorTickSize
        ImVec2 MajorGridSize
        ImVec2 MinorGridSize
        ImVec2 PlotPadding
        ImVec2 LabelPadding
        ImVec2 LegendPadding
        ImVec2 LegendInnerPadding
        ImVec2 LegendSpacing
        ImVec2 MousePosPadding
        ImVec2 AnnotationPadding
        ImVec2 FitPadding
        ImVec2 PlotDefaultSize
        ImVec2 PlotMinSize
        ImVec4 Colors[21]
        ImPlotColormap Colormap
        bint UseLocalTime
        bint UseISO8601
        bint Use24HourClock
        ImPlotStyle()
    cppclass ImPlotInputMap:
        ImGuiMouseButton Pan
        int PanMod
        ImGuiMouseButton Fit
        ImGuiMouseButton Select
        ImGuiMouseButton SelectCancel
        int SelectMod
        int SelectHorzMod
        int SelectVertMod
        ImGuiMouseButton Menu
        int OverrideMod
        int ZoomMod
        float ZoomRate
        ImPlotInputMap()
    ctypedef int (*ImPlotFormatter)(double, char*, int, void*)
    ctypedef ImPlotPoint (*ImPlotGetter)(int, void*)
    ctypedef double (*ImPlotTransform)(double, void*)
    enum ImPlotFlagsObsolete_:
        ImPlotFlags_YAxis2 = 1048576
        ImPlotFlags_YAxis3 = 2097152

cdef extern from "implot.h" namespace "ImPlot" nogil:
    struct ImPlotContext:
        pass
    ImPlotContext* CreateContext()
    void DestroyContext()
    void DestroyContext(ImPlotContext*)
    ImPlotContext* GetCurrentContext()
    void SetCurrentContext(ImPlotContext*)
    void SetImGuiContext(ImGuiContext*)
    bint BeginPlot(const char*)
    bint BeginPlot(const char*, ImVec2&)
    bint BeginPlot(const char*, ImVec2&, ImPlotFlags)
    void EndPlot()
    bint BeginSubplots(const char*, int, int, ImVec2&, ImPlotSubplotFlags)
    bint BeginSubplots(const char*, int, int, ImVec2&, ImPlotSubplotFlags, float*)
    bint BeginSubplots(const char*, int, int, ImVec2&, ImPlotSubplotFlags, float*, float*)
    void EndSubplots()
    void SetupAxis(ImAxis)
    void SetupAxis(ImAxis, const char*)
    void SetupAxis(ImAxis, const char*, ImPlotAxisFlags)
    void SetupAxisLimits(ImAxis, double, double)
    void SetupAxisLimits(ImAxis, double, double, ImPlotCond)
    void SetupAxisLinks(ImAxis, double*, double*)
    void SetupAxisFormat(ImAxis, const char*)
    #void SetupAxisFormat(ImAxis, ImPlotFormatter)
    #void SetupAxisFormat(ImAxis, ImPlotFormatter, void*)
    void SetupAxisTicks(ImAxis, const double*, int)
    void SetupAxisTicks(ImAxis, const double*, int, const char*[])
    void SetupAxisTicks(ImAxis, const double*, int, const char*[], bint)
    void SetupAxisTicks(ImAxis, double, double, int)
    void SetupAxisTicks(ImAxis, double, double, int, const char*[])
    void SetupAxisTicks(ImAxis, double, double, int, const char*[], bint)
    void SetupAxisScale(ImAxis, ImPlotScale)
    void SetupAxisScale(ImAxis, ImPlotTransform, ImPlotTransform)
    void SetupAxisScale(ImAxis, ImPlotTransform, ImPlotTransform, void*)
    void SetupAxisLimitsConstraints(ImAxis, double, double)
    void SetupAxisZoomConstraints(ImAxis, double, double)
    void SetupAxes(const char*, const char*, ImPlotAxisFlags, ImPlotAxisFlags)
    void SetupAxesLimits(double, double, double, double)
    void SetupAxesLimits(double, double, double, double, ImPlotCond)
    void SetupLegend(ImPlotLocation, ImPlotLegendFlags)
    void SetupMouseText(ImPlotLocation, ImPlotMouseTextFlags)
    void SetupFinish()
    void SetNextAxisLimits(ImAxis, double, double)
    void SetNextAxisLimits(ImAxis, double, double, ImPlotCond)
    void SetNextAxisLinks(ImAxis, double*, double*)
    void SetNextAxisToFit(ImAxis)
    void SetNextAxesLimits(double, double, double, double)
    void SetNextAxesLimits(double, double, double, double, ImPlotCond)
    void SetNextAxesToFit()
    #void PlotLine[T](const char*, const T*, int)
    #void PlotLine[T](const char*, const T*, int, double)
    #void PlotLine[T](const char*, const T*, int, double, double)
    #void PlotLine[T](const char*, const T*, int, double, double, ImPlotLineFlags)
    #void PlotLine[T](const char*, const T*, int, double, double, ImPlotLineFlags, int)
    #void PlotLine[T](const char*, const T*, int, double, double, ImPlotLineFlags, int, int)
    #void PlotLine[T](const char*, const T*, const T*, int, ImPlotLineFlags, int)
    void PlotLine[T](const char*, const T*, const T*, int, ImPlotLineFlags, int, int)
    void PlotLineG(const char*, ImPlotGetter, void*, int, ImPlotLineFlags)
    #void PlotScatter[T](const char*, const T*, int)
    #void PlotScatter[T](const char*, const T*, int, double)
    #void PlotScatter[T](const char*, const T*, int, double, double)
    #void PlotScatter[T](const char*, const T*, int, double, double, ImPlotScatterFlags)
    #void PlotScatter[T](const char*, const T*, int, double, double, ImPlotScatterFlags, int)
    #void PlotScatter[T](const char*, const T*, int, double, double, ImPlotScatterFlags, int, int)
    #void PlotScatter[T](const char*, const T*, const T*, int, ImPlotScatterFlags, int)
    void PlotScatter[T](const char*, const T*, const T*, int, ImPlotScatterFlags, int, int)
    void PlotScatterG(const char*, ImPlotGetter, void*, int, ImPlotScatterFlags)
    #void PlotStairs[T](const char*, const T*, int)
    #void PlotStairs[T](const char*, const T*, int, double)
    #void PlotStairs[T](const char*, const T*, int, double, double)
    #void PlotStairs[T](const char*, const T*, int, double, double, ImPlotStairsFlags)
    #void PlotStairs[T](const char*, const T*, int, double, double, ImPlotStairsFlags, int)
    #void PlotStairs[T](const char*, const T*, int, double, double, ImPlotStairsFlags, int, int)
    #void PlotStairs[T](const char*, const T*, const T*, int, ImPlotStairsFlags, int)
    void PlotStairs[T](const char*, const T*, const T*, int, ImPlotStairsFlags, int, int)
    void PlotStairsG(const char*, ImPlotGetter, void*, int, ImPlotStairsFlags)
    #void PlotShaded[T](const char*, const T*, int)
    #void PlotShaded[T](const char*, const T*, int, double)
    #void PlotShaded[T](const char*, const T*, int, double, double)
    #void PlotShaded[T](const char*, const T*, int, double, double, double)
    #void PlotShaded[T](const char*, const T*, int, double, double, double, ImPlotShadedFlags)
    #void PlotShaded[T](const char*, const T*, int, double, double, double, ImPlotShadedFlags, int)
    #void PlotShaded[T](const char*, const T*, int, double, double, double, ImPlotShadedFlags, int, int)
    #void PlotShaded[T](const char*, const T*, const T*, int)
    #void PlotShaded[T](const char*, const T*, const T*, int, double)
    #void PlotShaded[T](const char*, const T*, const T*, int, double, ImPlotShadedFlags)
    #void PlotShaded[T](const char*, const T*, const T*, int, double, ImPlotShadedFlags, int)
    #void PlotShaded[T](const char*, const T*, const T*, int, double, ImPlotShadedFlags, int, int)
    #void PlotShaded[T](const char*, const T*, const T*, const T*, int, ImPlotShadedFlags, int)
    void PlotShaded[T](const char*, const T*, const T*, const T*, int, ImPlotShadedFlags, int, int)
    void PlotShadedG(const char*, ImPlotGetter, void*, ImPlotGetter, void*, int, ImPlotShadedFlags)
    #void PlotBars[T](const char*, const T*, int, double)
    #void PlotBars[T](const char*, const T*, int, double, double)
    #void PlotBars[T](const char*, const T*, int, double, double, ImPlotBarsFlags)
    #void PlotBars[T](const char*, const T*, int, double, double, ImPlotBarsFlags, int)
    #void PlotBars[T](const char*, const T*, int, double, double, ImPlotBarsFlags, int, int)
    #void PlotBars[T](const char*, const T*, const T*, int, double, ImPlotBarsFlags, int)
    void PlotBars[T](const char*, const T*, const T*, int, double, ImPlotBarsFlags, int, int)
    void PlotBarsG(const char*, ImPlotGetter, void*, int, double, ImPlotBarsFlags)
    #void PlotBarGroups[T](const char*[], const T*, int, int, double)
    #void PlotBarGroups[T](const char*[], const T*, int, int, double, double)
    void PlotBarGroups[T](const char*[], const T*, int, int, double, double, ImPlotBarGroupsFlags)
    #void PlotErrorBars[T](const char*, const T*, const T*, const T*, int, ImPlotErrorBarsFlags, int)
    #void PlotErrorBars[T](const char*, const T*, const T*, const T*, int, ImPlotErrorBarsFlags, int, int)
    #void PlotErrorBars[T](const char*, const T*, const T*, const T*, const T*, int, ImPlotErrorBarsFlags, int)
    void PlotErrorBars[T](const char*, const T*, const T*, const T*, const T*, int, ImPlotErrorBarsFlags, int, int)
    #void PlotStems[T](const char*, const T*, int)
    #void PlotStems[T](const char*, const T*, int, double)
    #void PlotStems[T](const char*, const T*, int, double, double)
    #void PlotStems[T](const char*, const T*, int, double, double, double)
    #void PlotStems[T](const char*, const T*, int, double, double, double, ImPlotStemsFlags)
    #void PlotStems[T](const char*, const T*, int, double, double, double, ImPlotStemsFlags, int)
    #void PlotStems[T](const char*, const T*, int, double, double, double, ImPlotStemsFlags, int, int)
    #void PlotStems[T](const char*, const T*, const T*, int)
    #void PlotStems[T](const char*, const T*, const T*, int, double)
    #void PlotStems[T](const char*, const T*, const T*, int, double, ImPlotStemsFlags)
    #void PlotStems[T](const char*, const T*, const T*, int, double, ImPlotStemsFlags, int)
    void PlotStems[T](const char*, const T*, const T*, int, double, ImPlotStemsFlags, int, int)
    void PlotInfLines[T](const char*, const T*, int, ImPlotInfLinesFlags, int)
    void PlotInfLines[T](const char*, const T*, int, ImPlotInfLinesFlags, int, int)
    #void PlotPieChart[T](const char*[], const T*, int, double, double, double, ImPlotFormatter)
    #void PlotPieChart[T](const char*[], const T*, int, double, double, double, ImPlotFormatter, void*)
    #void PlotPieChart[T](const char*[], const T*, int, double, double, double, ImPlotFormatter, void*, double)
    #void PlotPieChart[T](const char*[], const T*, int, double, double, double, ImPlotFormatter, void*, double, ImPlotPieChartFlags)
    #void PlotPieChart[T](const char*[], const T*, int, double, double, double)
    void PlotPieChart[T](const char*[], const T*, int, double, double, double, const char*)
    void PlotPieChart[T](const char*[], const T*, int, double, double, double, const char*, double)
    void PlotPieChart[T](const char*[], const T*, int, double, double, double, const char*, double, ImPlotPieChartFlags)
    void PlotHeatmap[T](const char*, const T*, int, int)
    void PlotHeatmap[T](const char*, const T*, int, int, double)
    void PlotHeatmap[T](const char*, const T*, int, int, double, double)
    void PlotHeatmap[T](const char*, const T*, int, int, double, double, const char*)
    void PlotHeatmap[T](const char*, const T*, int, int, double, double, const char*, ImPlotPoint&)
    void PlotHeatmap[T](const char*, const T*, int, int, double, double, const char*, ImPlotPoint&, ImPlotPoint&)
    void PlotHeatmap[T](const char*, const T*, int, int, double, double, const char*, ImPlotPoint&, ImPlotPoint&, ImPlotHeatmapFlags)
    double PlotHistogram[T](const char*, const T*, int)
    double PlotHistogram[T](const char*, const T*, int, int)
    double PlotHistogram[T](const char*, const T*, int, int, double)
    double PlotHistogram[T](const char*, const T*, int, int, double, ImPlotRange)
    double PlotHistogram[T](const char*, const T*, int, int, double, ImPlotRange, ImPlotHistogramFlags)
    double PlotHistogram2D[T](const char*, const T*, const T*, int)
    double PlotHistogram2D[T](const char*, const T*, const T*, int, int)
    double PlotHistogram2D[T](const char*, const T*, const T*, int, int, int)
    double PlotHistogram2D[T](const char*, const T*, const T*, int, int, int, ImPlotRect)
    double PlotHistogram2D[T](const char*, const T*, const T*, int, int, int, ImPlotRect, ImPlotHistogramFlags)
    void PlotDigital[T](const char*, const T*, const T*, int, ImPlotDigitalFlags, int)
    void PlotDigital[T](const char*, const T*, const T*, int, ImPlotDigitalFlags, int, int)
    void PlotDigitalG(const char*, ImPlotGetter, void*, int, ImPlotDigitalFlags)
    void PlotImage(const char*, ImTextureID, ImPlotPoint&, ImPlotPoint&)
    void PlotImage(const char*, ImTextureID, ImPlotPoint&, ImPlotPoint&, ImVec2&)
    void PlotImage(const char*, ImTextureID, ImPlotPoint&, ImPlotPoint&, ImVec2&, ImVec2&)
    void PlotImage(const char*, ImTextureID, ImPlotPoint&, ImPlotPoint&, ImVec2&, ImVec2&, ImVec4&)
    void PlotImage(const char*, ImTextureID, ImPlotPoint&, ImPlotPoint&, ImVec2&, ImVec2&, ImVec4&, ImPlotImageFlags)
    void PlotText(const char*, double, double)
    void PlotText(const char*, double, double, ImVec2&)
    void PlotText(const char*, double, double, ImVec2&, ImPlotTextFlags)
    void PlotDummy(const char*, ImPlotDummyFlags)
    bint DragPoint(int, double*, double*, ImVec4&)
    bint DragPoint(int, double*, double*, ImVec4&, float)
    bint DragPoint(int, double*, double*, ImVec4&, float, ImPlotDragToolFlags)
    bint DragPoint(int, double*, double*, ImVec4&, float, ImPlotDragToolFlags, bint*)
    bint DragPoint(int, double*, double*, ImVec4&, float, ImPlotDragToolFlags, bint*, bint*)
    bint DragPoint(int, double*, double*, ImVec4&, float, ImPlotDragToolFlags, bint*, bint*, bint*)
    bint DragLineX(int, double*, ImVec4&)
    bint DragLineX(int, double*, ImVec4&, float)
    bint DragLineX(int, double*, ImVec4&, float, ImPlotDragToolFlags)
    bint DragLineX(int, double*, ImVec4&, float, ImPlotDragToolFlags, bint*)
    bint DragLineX(int, double*, ImVec4&, float, ImPlotDragToolFlags, bint*, bint*)
    bint DragLineX(int, double*, ImVec4&, float, ImPlotDragToolFlags, bint*, bint*, bint*)
    bint DragLineY(int, double*, ImVec4&)
    bint DragLineY(int, double*, ImVec4&, float)
    bint DragLineY(int, double*, ImVec4&, float, ImPlotDragToolFlags)
    bint DragLineY(int, double*, ImVec4&, float, ImPlotDragToolFlags, bint*)
    bint DragLineY(int, double*, ImVec4&, float, ImPlotDragToolFlags, bint*, bint*)
    bint DragLineY(int, double*, ImVec4&, float, ImPlotDragToolFlags, bint*, bint*, bint*)
    bint DragRect(int, double*, double*, double*, double*, ImVec4&, ImPlotDragToolFlags)
    bint DragRect(int, double*, double*, double*, double*, ImVec4&, ImPlotDragToolFlags, bint*)
    bint DragRect(int, double*, double*, double*, double*, ImVec4&, ImPlotDragToolFlags, bint*, bint*)
    bint DragRect(int, double*, double*, double*, double*, ImVec4&, ImPlotDragToolFlags, bint*, bint*, bint*)
    void Annotation(double, double, ImVec4&, ImVec2&, bint, bint)
    void Annotation(double, double, ImVec4&, ImVec2&, bint, const char*)
    void Annotation(double, double, ImVec4&, ImVec2&, bint, const char*, const char*)
    void TagX(double, ImVec4&, bint)
    void TagX(double, ImVec4&, const char*)
    void TagX(double, ImVec4&, const char*, const char*)
    void TagY(double, ImVec4&, bint)
    void TagY(double, ImVec4&, const char*)
    void TagY(double, ImVec4&, const char*, const char*)
    void SetAxis(ImAxis)
    void SetAxes(ImAxis, ImAxis)
    ImPlotPoint PixelsToPlot(ImVec2&, ImAxis, ImAxis)
    ImPlotPoint PixelsToPlot(float, float, ImAxis, ImAxis)
    ImVec2 PlotToPixels(ImPlotPoint&, ImAxis, ImAxis)
    ImVec2 PlotToPixels(double, double, ImAxis, ImAxis)
    ImVec2 GetPlotPos()
    ImVec2 GetPlotSize()
    ImPlotPoint GetPlotMousePos(ImAxis, ImAxis)
    ImPlotRect GetPlotLimits(ImAxis, ImAxis)
    bint IsPlotHovered()
    bint IsAxisHovered(ImAxis)
    bint IsSubplotsHovered()
    bint IsPlotSelected()
    ImPlotRect GetPlotSelection(ImAxis, ImAxis)
    void CancelPlotSelection()
    void HideNextItem(bint)
    void HideNextItem(bint, ImPlotCond)
    bint BeginAlignedPlots(const char*, bint)
    void EndAlignedPlots()
    bint BeginLegendPopup(const char*, ImGuiMouseButton)
    void EndLegendPopup()
    bint IsLegendEntryHovered(const char*)
    bint BeginDragDropTargetPlot()
    bint BeginDragDropTargetAxis(ImAxis)
    bint BeginDragDropTargetLegend()
    void EndDragDropTarget()
    bint BeginDragDropSourcePlot(ImGuiDragDropFlags)
    bint BeginDragDropSourceAxis(ImAxis, ImGuiDragDropFlags)
    bint BeginDragDropSourceItem(const char*, ImGuiDragDropFlags)
    void EndDragDropSource()
    ImPlotStyle& GetStyle()
    void StyleColorsAuto()
    void StyleColorsAuto(ImPlotStyle*)
    void StyleColorsClassic()
    void StyleColorsClassic(ImPlotStyle*)
    void StyleColorsDark()
    void StyleColorsDark(ImPlotStyle*)
    void StyleColorsLight()
    void StyleColorsLight(ImPlotStyle*)
    void PushStyleColor(ImPlotCol, ImU32)
    void PushStyleColor(ImPlotCol, ImVec4&)
    void PopStyleColor(int)
    void PushStyleVar(ImPlotStyleVar, float)
    void PushStyleVar(ImPlotStyleVar, int)
    void PushStyleVar(ImPlotStyleVar, ImVec2&)
    void PushStyleVarX(ImPlotStyleVar, float)
    void PushStyleVarY(ImPlotStyleVar, float)
    void PopStyleVar(int)
    void SetNextLineStyle()
    void SetNextLineStyle(ImVec4&)
    void SetNextLineStyle(ImVec4&, float)
    void SetNextFillStyle()
    void SetNextFillStyle(ImVec4&)
    void SetNextFillStyle(ImVec4&, float)
    void SetNextMarkerStyle(ImPlotMarker)
    void SetNextMarkerStyle(ImPlotMarker, float)
    void SetNextMarkerStyle(ImPlotMarker, float, ImVec4&)
    void SetNextMarkerStyle(ImPlotMarker, float, ImVec4&, float)
    void SetNextMarkerStyle(ImPlotMarker, float, ImVec4&, float, ImVec4&)
    void SetNextErrorBarStyle()
    void SetNextErrorBarStyle(ImVec4&)
    void SetNextErrorBarStyle(ImVec4&, float)
    void SetNextErrorBarStyle(ImVec4&, float, float)
    ImVec4 GetLastItemColor()
    const char* GetStyleColorName(ImPlotCol)
    const char* GetMarkerName(ImPlotMarker)
    ImPlotColormap AddColormap(const char*, ImVec4*, int, bint)
    ImPlotColormap AddColormap(const char*, ImU32*, int, bint)
    int GetColormapCount()
    const char* GetColormapName(ImPlotColormap)
    ImPlotColormap GetColormapIndex(const char*)
    void PushColormap(ImPlotColormap)
    void PushColormap(const char*)
    void PopColormap(int)
    ImVec4 NextColormapColor()
    int GetColormapSize(ImPlotColormap)
    ImVec4 GetColormapColor(int, ImPlotColormap)
    ImVec4 SampleColormap(float, ImPlotColormap)
    void ColormapScale(const char*, double, double)
    void ColormapScale(const char*, double, double, ImVec2&)
    void ColormapScale(const char*, double, double, ImVec2&, const char*)
    void ColormapScale(const char*, double, double, ImVec2&, const char*, ImPlotColormapScaleFlags)
    void ColormapScale(const char*, double, double, ImVec2&, const char*, ImPlotColormapScaleFlags, ImPlotColormap)
    bint ColormapSlider(const char*, float*)
    bint ColormapSlider(const char*, float*, ImVec4*)
    bint ColormapSlider(const char*, float*, ImVec4*, const char*)
    bint ColormapSlider(const char*, float*, ImVec4*, const char*, ImPlotColormap)
    bint ColormapButton(const char*)
    bint ColormapButton(const char*, ImVec2&)
    bint ColormapButton(const char*, ImVec2&, ImPlotColormap)
    void BustColorCache()
    void BustColorCache(const char*)
    ImPlotInputMap& GetInputMap()
    void MapInputDefault()
    void MapInputDefault(ImPlotInputMap*)
    void MapInputReverse()
    void MapInputReverse(ImPlotInputMap*)
    void ItemIcon(ImVec4&)
    void ItemIcon(ImU32)
    void ColormapIcon(ImPlotColormap)
    ImDrawList* GetPlotDrawList()
    void PushPlotClipRect()
    void PushPlotClipRect(float)
    void PopPlotClipRect()
    bint ShowStyleSelector(const char*)
    bint ShowColormapSelector(const char*)
    bint ShowInputMapSelector(const char*)
    void ShowStyleEditor()
    void ShowStyleEditor(ImPlotStyle*)
    void ShowUserGuide()
    void ShowMetricsWindow()
    void ShowMetricsWindow(bint*)
    void ShowDemoWindow()
    void ShowDemoWindow(bint*)
    bint BeginPlot(const char*, const char*, const char*)
    bint BeginPlot(const char*, const char*, const char*, ImVec2&)
    bint BeginPlot(const char*, const char*, const char*, ImVec2&, ImPlotFlags)
    bint BeginPlot(const char*, const char*, const char*, ImVec2&, ImPlotFlags, ImPlotAxisFlags)
    bint BeginPlot(const char*, const char*, const char*, ImVec2&, ImPlotFlags, ImPlotAxisFlags, ImPlotAxisFlags)
    bint BeginPlot(const char*, const char*, const char*, ImVec2&, ImPlotFlags, ImPlotAxisFlags, ImPlotAxisFlags, ImPlotAxisFlags)
    bint BeginPlot(const char*, const char*, const char*, ImVec2&, ImPlotFlags, ImPlotAxisFlags, ImPlotAxisFlags, ImPlotAxisFlags, ImPlotAxisFlags)
    bint BeginPlot(const char*, const char*, const char*, ImVec2&, ImPlotFlags, ImPlotAxisFlags, ImPlotAxisFlags, ImPlotAxisFlags, ImPlotAxisFlags, const char*)
    bint BeginPlot(const char*, const char*, const char*, ImVec2&, ImPlotFlags, ImPlotAxisFlags, ImPlotAxisFlags, ImPlotAxisFlags, ImPlotAxisFlags, const char*, const char*)


cdef extern from "implot_internal.h" namespace "ImPlot" nogil:
    bint BeginItem(const char*, ImPlotFlags, ImPlotCol)
    void EndItem()
    bint FitThisFrame()
    void FitPointX(double)
    void FitPointY(double)

