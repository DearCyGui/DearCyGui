from libc.stdint cimport int32_t

from .core cimport baseItem, baseFont, itemState, \
    plotElement, uiItem, Callback, baseHandler
from .c_types cimport DCGString, DCGVector, DCG1DArrayView, DCG2DContiguousArrayView
from .types cimport Vec2

cdef class AxesResizeHandler(baseHandler):
    cdef int[2] _axes
    cdef void check_bind(self, baseItem)
    cdef bint check_state(self, baseItem) noexcept nogil
    cdef void run_handler(self, baseItem) noexcept nogil


cdef class PlotAxisConfig(baseItem):
    cdef bint _enabled
    cdef int32_t _scale # AxisScale
    cdef DCGString _tick_format
    cdef int32_t _flags # implot.ImPlotAxisFlags
    cdef double _min
    cdef double _max
    cdef double _prev_min
    cdef double _prev_max
    cdef bint _dirty_minmax
    cdef double _constraint_min
    cdef double _constraint_max
    cdef double _zoom_min
    cdef double _zoom_max
    cdef double _mouse_coord
    cdef bint _to_fit
    cdef itemState state
    cdef Callback _resize_callback
    cdef DCGString _label
    cdef DCGString _format
    cdef DCGVector[DCGString] _labels
    cdef DCGVector[const char*] _labels_cstr
    cdef DCGVector[double] _labels_coord
    cdef bint _keep_default_ticks
    cdef void setup(self, int32_t) noexcept nogil # implot.ImAxis
    cdef void after_setup(self, int32_t) noexcept nogil # implot.ImAxis
    cdef void after_plot(self, int32_t) noexcept nogil # implot.ImAxis
    cdef void set_hidden(self) noexcept nogil

cdef class PlotLegendConfig(baseItem):
    cdef bint _show
    cdef int32_t _location # LegendLocation
    cdef int32_t _flags # implot.ImPlotLegendFlags
    cdef void setup(self) noexcept nogil
    cdef void after_setup(self) noexcept nogil

cdef class Plot(uiItem):
    cdef PlotAxisConfig _X1
    cdef PlotAxisConfig _X2
    cdef PlotAxisConfig _X3
    cdef PlotAxisConfig _Y1
    cdef PlotAxisConfig _Y2
    cdef PlotAxisConfig _Y3
    cdef PlotLegendConfig _legend
    cdef int32_t _pan_button
    cdef int32_t _pan_modifier # imgui.ImGuiKeyChord
    cdef int32_t _fit_button
    cdef int32_t _menu_button
    cdef int32_t _override_mod # imgui.ImGuiKeyChord
    cdef int32_t _zoom_mod # imgui.ImGuiKeyChord
    cdef float _zoom_rate
    cdef bint _use_local_time
    cdef bint _use_ISO8601
    cdef bint _use_24hour_clock
    cdef int32_t _mouse_location # LegendLocation
    cdef int32_t _flags # implot.ImPlotFlags
    cdef bint draw_item(self) noexcept nogil

cdef class plotElementWithLegend(plotElement):
    cdef itemState state
    cdef bint _legend
    cdef int32_t _legend_button
    cdef baseFont _font
    cdef bint _enabled
    cdef bint _enabled_dirty
    cdef void draw(self) noexcept nogil
    cdef void draw_element(self) noexcept nogil

cdef class plotElementXY(plotElementWithLegend):
    cdef DCG1DArrayView _X
    cdef DCG1DArrayView _Y
    cdef void check_arrays(self) noexcept nogil

cdef class PlotLine(plotElementXY):
    cdef void draw_element(self) noexcept nogil

cdef class plotElementXYY(plotElementWithLegend):
    cdef DCG1DArrayView _X
    cdef DCG1DArrayView _Y1
    cdef DCG1DArrayView _Y2
    cdef void check_arrays(self) noexcept nogil

cdef class PlotShadedLine(plotElementXYY):
    cdef void draw_element(self) noexcept nogil

cdef class PlotStems(plotElementXY):
    cdef void draw_element(self) noexcept nogil

cdef class PlotBars(plotElementXY):
    cdef double _weight
    cdef void draw_element(self) noexcept nogil

cdef class PlotStairs(plotElementXY):
    cdef void draw_element(self) noexcept nogil

cdef class plotElementX(plotElementWithLegend):
    cdef DCG1DArrayView _X
    cdef void check_arrays(self) noexcept nogil

cdef class PlotInfLines(plotElementX):
    cdef void draw_element(self) noexcept nogil

cdef class PlotScatter(plotElementXY):
    cdef void draw_element(self) noexcept nogil

cdef class DrawInPlot(plotElementWithLegend):
    cdef bint _ignore_fit
    cdef void draw(self) noexcept nogil

cdef class Subplots(uiItem):
    cdef int32_t _rows 
    cdef int32_t _cols
    cdef DCGVector[float] _row_ratios
    cdef DCGVector[float] _col_ratios
    cdef int32_t _flags # implot.ImPlotSubplotFlags
    cdef bint draw_item(self) noexcept nogil

cdef class PlotBarGroups(plotElementWithLegend):
    cdef DCG2DContiguousArrayView _values
    cdef DCGVector[DCGString] _labels
    cdef double _group_size
    cdef double _shift
    cdef void draw_element(self) noexcept nogil

cdef class PlotPieChart(plotElementWithLegend):
    cdef DCG1DArrayView _values
    cdef DCGVector[DCGString] _labels
    cdef double _x
    cdef double _y
    cdef double _radius
    cdef double _angle
    cdef DCGString _label_format
    cdef void draw_element(self) noexcept nogil

cdef class PlotDigital(plotElementXY):
    cdef void draw_element(self) noexcept nogil

cdef class PlotErrorBars(plotElementXY):
    cdef DCG1DArrayView _pos
    cdef DCG1DArrayView _neg
    cdef void draw_element(self) noexcept nogil

cdef class PlotAnnotation(plotElement):
    cdef DCGString _text
    cdef double _x
    cdef double _y
    cdef int32_t _bg_color
    cdef Vec2 _offset
    cdef bint _clamp
    cdef void draw_element(self) noexcept nogil

cdef class PlotHistogram(plotElementX):
    cdef int32_t _bins
    cdef double _bar_scale
    cdef double _range_min
    cdef double _range_max
    cdef bint _has_range
    cdef void draw_element(self) noexcept nogil

cdef class PlotHistogram2D(plotElementXY):
    cdef int32_t _x_bins
    cdef int32_t _y_bins 
    cdef double _range_min_x
    cdef double _range_max_x
    cdef double _range_min_y
    cdef double _range_max_y
    cdef bint _has_range_x
    cdef bint _has_range_y
    cdef void draw_element(self) noexcept nogil

cdef class PlotHeatmap(plotElementWithLegend):
    cdef DCG2DContiguousArrayView _values
    cdef int32_t _rows
    cdef int32_t _cols
    cdef double _scale_min
    cdef double _scale_max
    cdef bint _auto_scale
    cdef DCGString _label_format
    cdef double[2] _bounds_min
    cdef double[2] _bounds_max
    cdef void draw_element(self) noexcept nogil