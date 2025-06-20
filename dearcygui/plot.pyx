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
#cython: freethreading_compatible=True
#distutils: language=c++

from libc.stdint cimport uint8_t, int32_t
from libc.math cimport INFINITY
from libcpp.vector cimport vector

from cpython.object cimport PyObject
from cpython.sequence cimport PySequence_Check

from .core cimport baseHandler, baseItem, uiItem, AxisTag, \
    lock_gil_friendly, clear_obj_vector, append_obj_vector, \
    draw_drawing_children, \
    draw_ui_children, baseFont, plotElement, \
    update_current_mouse_states, \
    draw_plot_element_children, itemState, ItemStateView
from .c_types cimport unique_lock, DCGMutex, DCGString, DCGVector,\
    string_to_str, string_from_str, get_object_from_1D_array_view,\
    get_object_from_2D_array_view, DCG_DOUBLE, DCG_INT32, DCG_FLOAT,\
    DCG_UINT8, Vec2, make_Vec2, swap_Vec2, string_from_bytes
from .imgui_types cimport imgui_ColorConvertU32ToFloat4, LegendLocation,\
    Vec2ImVec2, ImVec2Vec2, parse_color, unparse_color, AxisScale, \
    check_Axis, make_Axis
from .types cimport is_MouseButton, make_MouseButton,\
    is_KeyMod, make_KeyMod
from .wrapper cimport imgui, implot



cdef extern from * nogil:
    """
    ImPlotAxisFlags GetAxisConfig(int axis)
    {
        return ImPlot::GetCurrentContext()->CurrentPlot->Axes[axis].Flags;
    }
    ImPlotLocation GetLegendConfig(ImPlotLegendFlags &flags)
    {
        flags = ImPlot::GetCurrentContext()->CurrentPlot->Items.Legend.Flags;
        return ImPlot::GetCurrentContext()->CurrentPlot->Items.Legend.Location;
    }
    ImPlotFlags GetPlotConfig()
    {
        return ImPlot::GetCurrentContext()->CurrentPlot->Flags;
    }
    bool IsItemHidden(const char* label_id)
    {
        ImPlotItem* item = ImPlot::GetItem(label_id);
        return item != nullptr && !item->Show;
    }
    """
    implot.ImPlotAxisFlags GetAxisConfig(int)
    implot.ImPlotLocation GetLegendConfig(implot.ImPlotLegendFlags&)
    implot.ImPlotFlags GetPlotConfig()
    bint IsItemHidden(const char*)

cdef class AxesResizeHandler(baseHandler):
    """
    Handler that detects changes in plot axes dimensions or view area.
    
    This handler monitors both the axes min/max values and the plot region size,
    triggering the callback whenever these dimensions change. This is useful for
    detecting when the scale of pixels within plot coordinates has changed, such 
    as after zoom operations or window resizing.
    
    The data field passed to the callback contains:
    ((x_min, x_max, x_scale), (y_min, y_max, y_scale))
    
    Where:
    - x_min, x_max: Current axis limits
    - x_scale: Scaling factor (max-min)/pixels
    - First tuple is for X axis (default X1)
    - Second tuple is for Y axis (default Y1)
    """
    def __cinit__(self):
        self._axes = [implot.ImAxis_X1, implot.ImAxis_Y1]
    @property
    def axes(self):
        """
        The (X axis, Y axis) pair monitored by this handler.
        
        Specifies which axes this handler should monitor for dimensional changes.
        Valid X axes are X1, X2, X3. Valid Y axes are Y1, Y2, Y3.
        Default is (X1, Y1).
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (make_Axis(self._axes[0]), make_Axis(self._axes[1]))

    @axes.setter
    def axes(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef int32_t axis_x, axis_y
        axis_x = check_Axis(value[0])
        axis_y = check_Axis(value[1])
        self._axes[0] = axis_x
        self._axes[1] = axis_y

    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if not(isinstance(item, Plot)):
            raise TypeError(f"Cannot only bind handler {self} to a plot, not {item}")

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        cdef bint changed = \
               state.cur.content_region_size.x != state.prev.content_region_size.x or \
               state.cur.content_region_size.y != state.prev.content_region_size.y
        if changed:
            return True
        if self._axes[0] == implot.ImAxis_X1:
            changed = (<Plot>item)._X1._min != (<Plot>item)._X1._prev_min or \
                      (<Plot>item)._X1._max != (<Plot>item)._X1._prev_max
        elif self._axes[0] == implot.ImAxis_X2:
            changed = (<Plot>item)._X2._min != (<Plot>item)._X2._prev_min or \
                      (<Plot>item)._X2._max != (<Plot>item)._X2._prev_max
        elif self._axes[0] == implot.ImAxis_X3:
            changed = (<Plot>item)._X3._min != (<Plot>item)._X3._prev_min or \
                      (<Plot>item)._X3._max != (<Plot>item)._X3._prev_max
        if changed:
            return True
        if self._axes[1] == implot.ImAxis_Y1:
            changed = (<Plot>item)._Y1._min != (<Plot>item)._Y1._prev_min or \
                      (<Plot>item)._Y1._max != (<Plot>item)._Y1._prev_max
        elif self._axes[1] == implot.ImAxis_Y2:
            changed = (<Plot>item)._Y2._min != (<Plot>item)._Y2._prev_min or \
                      (<Plot>item)._Y2._max != (<Plot>item)._Y2._prev_max
        elif self._axes[1] == implot.ImAxis_Y3:
            changed = (<Plot>item)._Y3._min != (<Plot>item)._Y3._prev_min or \
                      (<Plot>item)._Y3._max != (<Plot>item)._Y3._prev_max

        return changed

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        cdef itemState *state = item.p_state
        if not(self._enabled):
            return
        if self._callback is None or not(self.check_state(item)):
            return
        cdef double x_min = 0., x_max = 0., x_scale = 0.
        cdef double y_min = 0., y_max = 0., y_scale = 0.
        if self._axes[0] == implot.ImAxis_X1:
            x_min = (<Plot>item)._X1._min
            x_max = (<Plot>item)._X1._max
        elif self._axes[0] == implot.ImAxis_X2:
            x_min = (<Plot>item)._X2._min
            x_max = (<Plot>item)._X2._max
        elif self._axes[0] == implot.ImAxis_X3:
            x_min = (<Plot>item)._X3._min
            x_max = (<Plot>item)._X3._max
        if self._axes[1] == implot.ImAxis_Y1:
            y_min = (<Plot>item)._Y1._min
            y_max = (<Plot>item)._Y1._max
        elif self._axes[1] == implot.ImAxis_Y2:
            y_min = (<Plot>item)._Y2._min
            y_max = (<Plot>item)._Y2._max
        elif self._axes[1] == implot.ImAxis_Y3:
            y_min = (<Plot>item)._Y3._min
            y_max = (<Plot>item)._Y3._max
        x_scale = (x_max - x_min) / <double>state.cur.content_region_size.x
        y_scale = (y_max - y_min) / <double>state.cur.content_region_size.y
        self.context.queue_callback_argdoubletriplet(self._callback,
                                                     self,
                                                     item,
                                                     x_min,
                                                     x_max,
                                                     x_scale,
                                                     y_min,
                                                     y_max,
                                                     y_scale)

# BaseItem that has has no parent/child nor sibling
cdef class PlotAxisConfig(baseItem):
    """
    Configuration for a plot axis.
    
    Controls the appearance, behavior and limits of an axis in a plot. Each plot 
    can have up to six axes (X1, X2, X3, Y1, Y2, Y3) that can be configured 
    individually. By default, only X1 and Y1 are enabled.
    
    Can have AxisTag elements as children to add markers at specific positions
    along the axis.
    """
    def __cinit__(self):
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_clicked = True
        self.p_state = &self.state
        self._enabled = True
        self._scale = <int>AxisScale.LINEAR
        self._flags = 0
        self._min = 0
        self._max = 1
        self._to_fit = True
        self._dirty_minmax = False
        self._constraint_min = -INFINITY
        self._constraint_max = INFINITY
        self._zoom_min = 0
        self._zoom_max = INFINITY
        self._keep_default_ticks = False
        self.can_have_tag_child = True

    @property
    def enabled(self):
        """
        Whether elements using this axis should be drawn.
        
        When disabled, plot elements assigned to this axis will not be rendered.
        At least one X and one Y axis must be enabled for the plot to display
        properly.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._enabled

    @enabled.setter
    def enabled(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._enabled = value

    @property
    def scale(self):
        """
        Current axis scale type.
        
        Controls how values are mapped along the axis. Options include:
        - LINEAR: Linear mapping (default)
        - TIME: Display values as dates/times
        - LOG10: Logarithmic scale (base 10)
        - SYMLOG: Symmetric logarithmic scale
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return <AxisScale>self._scale

    @scale.setter
    def scale(self, AxisScale value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value == AxisScale.LINEAR or \
           value == AxisScale.TIME or \
           value == AxisScale.LOG10 or\
           value == AxisScale.SYMLOG:
            self._scale = <int>value
        else:
            raise ValueError("Invalid scale. Expecting an AxisScale")

    @property
    def min(self):
        """
        Current minimum value of the axis range.
        
        Sets the lower bound of the visible range. Should be less than max.
        To reverse the axis direction, use the invert property instead of
        swapping min/max values.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._min

    @min.setter
    def min(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._min = value
        self._dirty_minmax = True

    @property
    def max(self):
        """
        Current maximum value of the axis range.
        
        Sets the upper bound of the visible range. Should be greater than min.
        To reverse the axis direction, use the invert property instead of
        swapping min/max values.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._max

    @max.setter
    def max(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._max = value
        self._dirty_minmax = True

    @property
    def constraint_min(self):
        """
        Minimum allowed value for the axis minimum.
        
        Sets a hard limit on how far the axis can be zoomed or panned out.
        The minimum value of the axis will never go below this value.
        Default is negative infinity (no constraint).
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._constraint_min

    @constraint_min.setter
    def constraint_min(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._constraint_min = value

    @property
    def constraint_max(self):
        """
        Maximum allowed value for the axis maximum.
        
        Sets a hard limit on how far the axis can be zoomed or panned out.
        The maximum value of the axis will never go above this value.
        Default is positive infinity (no constraint).
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._constraint_max

    @constraint_max.setter
    def constraint_max(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._constraint_max = value

    @property
    def zoom_min(self):
        """
        Minimum allowed width of the axis range.
        
        Constrains the minimum zoom level by enforcing a minimum distance
        between min and max. Prevents extreme zooming in.
        Default is 0 (no constraint).
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._zoom_min

    @zoom_min.setter
    def zoom_min(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._zoom_min = value

    @property
    def zoom_max(self):
        """
        Maximum allowed width of the axis range.
        
        Constrains the maximum zoom level by enforcing a maximum distance
        between min and max. Prevents extreme zooming out.
        Default is infinity (no constraint).
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._zoom_max

    @zoom_max.setter
    def zoom_max(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._zoom_max = value

    @property
    def no_label(self):
        """
        Whether to hide the axis label.
        
        When True, the axis label will not be displayed, saving space in
        the plot. Useful for minimalist plots or when space is limited.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotAxisFlags_NoLabel) != 0

    @no_label.setter
    def no_label(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotAxisFlags_NoLabel
        if value:
            self._flags |= implot.ImPlotAxisFlags_NoLabel

    @property
    def no_gridlines(self):
        """
        Whether to hide the grid lines.
        
        When True, the grid lines that extend from the axis ticks across
        the plot area will not be drawn, creating a cleaner appearance.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotAxisFlags_NoGridLines) != 0

    @no_gridlines.setter
    def no_gridlines(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotAxisFlags_NoGridLines
        if value:
            self._flags |= implot.ImPlotAxisFlags_NoGridLines

    @property
    def no_tick_marks(self):
        """
        Whether to hide the tick marks on the axis.
        
        When True, the small lines that indicate tick positions on the axis
        will not be drawn, while still keeping tick labels if enabled.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotAxisFlags_NoTickMarks) != 0

    @no_tick_marks.setter
    def no_tick_marks(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotAxisFlags_NoTickMarks
        if value:
            self._flags |= implot.ImPlotAxisFlags_NoTickMarks

    @property
    def no_tick_labels(self):
        """
        Whether to hide the text labels for tick marks.
        
        When True, the numerical or text labels that display the value at
        each tick position will not be drawn, while still keeping the tick
        marks themselves if enabled.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotAxisFlags_NoTickLabels) != 0

    @no_tick_labels.setter
    def no_tick_labels(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotAxisFlags_NoTickLabels
        if value:
            self._flags |= implot.ImPlotAxisFlags_NoTickLabels

    @property
    def no_initial_fit(self):
        """
        Whether to disable automatic fitting on the first frame.
        
        When True, the axis will not automatically adjust to fit the data 
        on the first frame. The axis will maintain its default range until 
        explicitly fitted or adjusted.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotAxisFlags_NoInitialFit) != 0

    @no_initial_fit.setter
    def no_initial_fit(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotAxisFlags_NoInitialFit
        if value:
            self._flags |= implot.ImPlotAxisFlags_NoInitialFit
            self._to_fit = False

    @property
    def no_menus(self):
        """
        Whether to disable context menus for this axis.
        
        When True, right-clicking on the axis will not open the context menu
        that provides options to fit data, set scales, etc.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotAxisFlags_NoMenus) != 0

    @no_menus.setter
    def no_menus(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotAxisFlags_NoMenus
        if value:
            self._flags |= implot.ImPlotAxisFlags_NoMenus

    @property
    def no_side_switch(self):
        """
        Whether to prevent the user from switching the axis side.
        
        When True, the user cannot drag the axis to the opposite side of the
        plot. For example, an X-axis cannot be moved from bottom to top.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotAxisFlags_NoSideSwitch) != 0

    @no_side_switch.setter
    def no_side_switch(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotAxisFlags_NoSideSwitch
        if value:
            self._flags |= implot.ImPlotAxisFlags_NoSideSwitch

    @property
    def no_highlight(self):
        """
        Whether to disable axis highlighting when hovered or selected.
        
        When True, the axis background will not be highlighted when the mouse
        hovers over it or when it is selected, providing a more consistent
        appearance.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotAxisFlags_NoHighlight) != 0

    @no_highlight.setter
    def no_highlight(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotAxisFlags_NoHighlight
        if value:
            self._flags |= implot.ImPlotAxisFlags_NoHighlight

    @property
    def opposite(self):
        """
        Whether to display ticks and labels on the opposite side of the axis.
        
        When True, labels and ticks are rendered on the opposite side from
        their default position. For example, ticks on an X-axis would appear
        above rather than below the axis line.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotAxisFlags_Opposite) != 0

    @opposite.setter
    def opposite(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotAxisFlags_Opposite
        if value:
            self._flags |= implot.ImPlotAxisFlags_Opposite

    @property
    def foreground_grid(self):
        """
        Whether to draw grid lines in the foreground.
        
        When True, grid lines are drawn on top of plot data rather than
        behind it. This can improve grid visibility when plot elements would
        otherwise obscure the grid.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotAxisFlags_Foreground) != 0

    @foreground_grid.setter
    def foreground_grid(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotAxisFlags_Foreground
        if value:
            self._flags |= implot.ImPlotAxisFlags_Foreground

    @property
    def invert(self):
        """
        Whether the axis direction is inverted.
        
        When True, the axis will be displayed in the reverse direction, with
        values decreasing rather than increasing along the axis direction.
        This is the proper way to flip axis direction, rather than swapping
        min/max values.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotAxisFlags_Invert) != 0

    @invert.setter
    def invert(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotAxisFlags_Invert
        if value:
            self._flags |= implot.ImPlotAxisFlags_Invert

    @property
    def auto_fit(self):
        """
        Whether the axis automatically fits to data every frame.
        
        When True, the axis will continuously adjust its range to ensure
        all plotted data is visible, regardless of user interactions. This
        overrides manual zooming and panning.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotAxisFlags_AutoFit) != 0

    @auto_fit.setter
    def auto_fit(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotAxisFlags_AutoFit
        if value:
            self._flags |= implot.ImPlotAxisFlags_AutoFit

    @property
    def restrict_fit_to_range(self):
        """
        Whether to restrict fitting to data within the opposing axis range.
        
        When True, data points that are outside the visible range of the
        opposite axis will be ignored when auto-fitting this axis. This can
        prevent outliers from one dimension affecting the scale of the other.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotAxisFlags_RangeFit) != 0

    @restrict_fit_to_range.setter
    def restrict_fit_to_range(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotAxisFlags_RangeFit
        if value:
            self._flags |= implot.ImPlotAxisFlags_RangeFit

    @property
    def pan_stretch(self):
        """
        Whether panning can stretch locked or constrained axes.
        
        When True, if the axis is being panned while in a locked or 
        constrained state, it will stretch instead of maintaining fixed 
        bounds. Useful for maintaining context while exploring limited ranges.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotAxisFlags_PanStretch) != 0

    @pan_stretch.setter
    def pan_stretch(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotAxisFlags_PanStretch
        if value:
            self._flags |= implot.ImPlotAxisFlags_PanStretch

    @property
    def lock_min(self):
        """
        Whether the axis minimum value is locked when panning/zooming.
        
        When True, the minimum value of the axis will not change during
        panning or zooming operations. Only the maximum value will adjust.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotAxisFlags_LockMin) != 0

    @lock_min.setter
    def lock_min(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotAxisFlags_LockMin
        if value:
            self._flags |= implot.ImPlotAxisFlags_LockMin

    @property
    def lock_max(self):
        """
        Whether the axis maximum value is locked when panning/zooming.
        
        When True, the maximum value of the axis will not change during
        panning or zooming operations. Only the minimum value will adjust.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotAxisFlags_LockMax) != 0

    @lock_max.setter
    def lock_max(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotAxisFlags_LockMax
        if value:
            self._flags |= implot.ImPlotAxisFlags_LockMax

    @property
    def state(self):
        """
        The current state of the item
        
        The state is an instance of ItemStateView which is a class
        with property getters to retrieve various readonly states.

        The ItemStateView instance is just a view over the current states,
        not a copy, thus the states get updated automatically.
        """
        return ItemStateView.create(self)

    @property
    def mouse_coord(self):
        """
        Current mouse position in plot units for this axis.
        
        Contains the estimated coordinate of the mouse cursor along this axis.
        Updated every time the plot is drawn when this axis is enabled.
        
        When using the same axis instance with multiple plots, this value will
        reflect whichever plot was last rendered.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._mouse_coord

    @property
    def handlers(self):
        """
        Event handlers attached to this axis.
        
        Handlers can respond to visibility changes, hover events, and click
        events. Use this to implement custom interactions with the axis.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int32_t i
        cdef baseHandler handler
        for i in range(<int>self._handlers.size()):
            handler = <baseHandler>self._handlers[i]
            result.append(handler)
        return result

    @handlers.setter
    def handlers(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list items = []
        cdef int32_t i
        if value is None:
            clear_obj_vector(self._handlers)
            return
        if PySequence_Check(value) == 0:
            value = (value,)
        for i in range(len(value)):
            if not(isinstance(value[i], baseHandler)):
                raise TypeError(f"{value[i]} is not a handler")
            # Check the handlers can use our states. Else raise error
            (<baseHandler>value[i]).check_bind(self)
            items.append(value[i])
        # Success: bind
        clear_obj_vector(self._handlers)
        append_obj_vector(self._handlers, items)

    def fit(self):
        """
        Request an axis fit to the data on the next frame.
        
        This will adjust the axis range to encompass all plotted data during
        the next rendering cycle. The fit operation is a one-time action that
        doesn't enable auto-fitting for subsequent frames.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._to_fit = True

    @property
    def label(self):
        """
        Text label for the axis.
        
        This text appears beside the axis and describes what the axis
        represents. For example, "Time (s)" or "Voltage (V)".
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return string_to_str(self._label)

    @label.setter
    def label(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._label = string_from_str(value)

    @property
    def tick_format(self):
        """
        Format string for displaying tick labels.
        
        Controls how numeric values are formatted on the axis. Uses printf-style
        format specifiers like "%.2f" for 2 decimal places or "%d" for integers.
        Leave empty to use the default format.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return string_to_str(self._format)

    @tick_format.setter
    def tick_format(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._format = string_from_str(value)

    @property
    def labels(self):
        """
        Custom text labels for specific tick positions.
        
        Replace default numeric tick labels with text. Must be used in
        conjunction with labels_coord to specify positions. Useful for 
        categorical data or custom annotations.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int i
        for i in range(<int>self._labels.size()):
            result.append(string_to_str(self._labels[i]))
        return result

    @labels.setter
    def labels(self, value):
        cdef unique_lock[DCGMutex] m
        cdef int32_t i
        lock_gil_friendly(m, self.mutex)
        self._labels.clear()
        self._labels_cstr.clear()
        if value is None:
            return
        if PySequence_Check(value) > 0:
            for v in value:
                self._labels.push_back(string_from_str(v))
            for i in range(<int>self._labels.size()):
                self._labels_cstr.push_back(self._labels[i].c_str())
        else:
            raise ValueError(f"Invalid type {type(value)} passed as labels. Expected array of strings")

    @property
    def labels_coord(self):
        """
        Coordinate positions for custom tick labels.
        
        Specifies where to place each label from the labels property along
        the axis. Must contain the same number of elements as labels.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int i
        for i in range(<int>self._labels_coord.size()):
            result.append(self._labels_coord[i])
        return result

    @labels_coord.setter
    def labels_coord(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._labels_coord.clear()
        if value is None:
            return
        if PySequence_Check(value) > 0:
            for v in value:
                self._labels_coord.push_back(v)
        else:
            raise ValueError(f"Invalid type {type(value)} passed as labels_coord. Expected array of strings")

    @property 
    def keep_default_ticks(self):
        """
        Whether to keep default ticks when using custom labels.
        
        When True and custom labels are set, both the default numeric ticks
        and the custom labels will be displayed. When False, only the
        custom labels will be shown.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._keep_default_ticks

    @keep_default_ticks.setter
    def keep_default_ticks(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._keep_default_ticks = value

    cdef void setup(self, int32_t axis) noexcept nogil:
        """
        Apply the config to the target axis during plot
        setup
        """
        self.set_previous_states()
        self.state.cur.hovered = False
        self.state.cur.rendered = False

        if self._enabled == False:
            self.context.viewport.enabled_axes[axis] = False
            return
        self.context.viewport.enabled_axes[axis] = True
        self.state.cur.rendered = True

        cdef implot.ImPlotAxisFlags flags = self._flags
        if self._to_fit:
            flags |= implot.ImPlotAxisFlags_AutoFit
        if <int>self._label.size() > 0:
            implot.SetupAxis(axis, self._label.c_str(), flags)
        else:
            implot.SetupAxis(axis, NULL, flags)
        """
        if self._dirty_minmax:
            # enforce min < max
            self._max = max(self._max, self._min + 1e-12)
            implot.SetupAxisLimits(axis,
                                   self._min,
                                   self._max,
                                   implot.ImPlotCond_Always)
        """
        self._prev_min = self._min
        self._prev_max = self._max
        # We use SetupAxisLinks to get the min/max update
        # right away during EndPlot(), rather than the
        # next frame
        # TODO: fix incompatibility with subplot axis link
        implot.SetupAxisLinks(axis, &self._min, &self._max)

        implot.SetupAxisScale(axis, <int>self._scale)

        if <int>self._format.size() > 0:
            implot.SetupAxisFormat(axis, self._format.c_str())

        if self._constraint_min != -INFINITY or \
           self._constraint_max != INFINITY:
            self._constraint_max = max(self._constraint_max, self._constraint_min + 1e-12)
            implot.SetupAxisLimitsConstraints(axis,
                                              self._constraint_min,
                                              self._constraint_max)
        if self._zoom_min > 0 or \
           self._zoom_max != INFINITY:
            self._zoom_min = max(0, self._zoom_min)
            self._zoom_max = max(self._zoom_min, self._zoom_max)
            implot.SetupAxisZoomConstraints(axis,
                                            self._zoom_min,
                                            self._zoom_max)
        cdef int32_t label_count = min(<int>self._labels_coord.size(), <int>self._labels_cstr.size())
        if label_count > 0:
            implot.SetupAxisTicks(axis,
                                  self._labels_coord.data(),
                                  label_count,
                                  self._labels_cstr.data(),
                                  self._keep_default_ticks)

    cdef void after_setup(self, int32_t axis) noexcept nogil:
        """
        Update states, etc. after the elements were setup
        """
        if not(self.context.viewport.enabled_axes[axis]):
            if self.state.cur.rendered:
                self.set_hidden()
            return

        # Render the tags
        cdef PyObject *child
        cdef char[3] format_str = [37, 115, 0] # %s 
        if self.last_tag_child is not None:
            implot.SetAxis(axis)
            child = <PyObject*> self.last_tag_child
            while (<baseItem>child).prev_sibling is not None:
                child = <PyObject *>(<baseItem>child).prev_sibling
            if axis <= implot.ImAxis_X3:
                while (<baseItem>child) is not None:
                    if (<AxisTag>child).show:
                        implot.TagX((<AxisTag>child).coord,
                                    imgui_ColorConvertU32ToFloat4((<AxisTag>child).bg_color),
                                    format_str, (<AxisTag>child).text.c_str())
                    child = <PyObject *>(<baseItem>child).next_sibling
            else:
                while (<baseItem>child) is not None:
                    if (<AxisTag>child).show:
                        implot.TagY((<AxisTag>child).coord,
                                    imgui_ColorConvertU32ToFloat4((<AxisTag>child).bg_color),
                                    format_str, (<AxisTag>child).text.c_str())
                    child = <PyObject *>(<baseItem>child).next_sibling

        cdef implot.ImPlotRect rect
        #self._prev_min = self._min
        #self._prev_max = self._max
        self._dirty_minmax = False
        if axis <= implot.ImAxis_X3:
            rect = implot.GetPlotLimits(axis, implot.IMPLOT_AUTO)
            #self._min = rect.X.Min
            #self._max = rect.X.Max
            self._mouse_coord = implot.GetPlotMousePos(axis, implot.IMPLOT_AUTO).x
        else:
            rect = implot.GetPlotLimits(implot.IMPLOT_AUTO, axis)
            #self._min = rect.Y.Min
            #self._max = rect.Y.Max
            self._mouse_coord = implot.GetPlotMousePos(implot.IMPLOT_AUTO, axis).y

        # Take into accounts flags changed by user interactions
        cdef implot.ImPlotAxisFlags flags = GetAxisConfig(<int>axis)
        if self._to_fit and (self._flags & implot.ImPlotAxisFlags_AutoFit) == 0:
            # Remove Autofit flag introduced for to_fit
            flags &= ~implot.ImPlotAxisFlags_AutoFit
            self._to_fit = False
        self._flags = flags

        cdef bint hovered = implot.IsAxisHovered(axis)
        cdef int32_t i
        for i in range(<int>imgui.ImGuiMouseButton_COUNT):
            self.state.cur.clicked[i] = hovered and imgui.IsMouseClicked(i, False)
            self.state.cur.double_clicked[i] = hovered and imgui.IsMouseDoubleClicked(i)
        cdef bint backup_hovered = self.state.cur.hovered
        self.state.cur.hovered = hovered
        self.run_handlers() # TODO FIX multiple configs tied. Maybe just not support ?
        if not(backup_hovered) or self.state.cur.hovered:
            return
        # Restore correct states
        # We do it here and not above to trigger the handlers only once
        self.state.cur.hovered |= backup_hovered
        for i in range(<int>imgui.ImGuiMouseButton_COUNT):
            self.state.cur.clicked[i] = self.state.cur.hovered and imgui.IsMouseClicked(i, False)
            self.state.cur.double_clicked[i] = self.state.cur.hovered and imgui.IsMouseDoubleClicked(i)

    cdef void after_plot(self, int32_t axis) noexcept nogil:
        # The fit only impacts the next frame
        if self._enabled and (self._min != self._prev_min or self._max != self._prev_max):
            self.context.viewport.redraw_needed = True

    cdef void set_hidden(self) noexcept nogil:
        self.set_previous_states()
        self.state.cur.hovered = False
        self.state.cur.rendered = False
        cdef int32_t i
        for i in range(<int>imgui.ImGuiMouseButton_COUNT):
            self.state.cur.clicked[i] = False
            self.state.cur.double_clicked[i] = False
        self.run_handlers()


cdef class PlotLegendConfig(baseItem):
    """
    Configuration for a plot's legend.
    
    Controls the appearance, behavior and position of the legend in a plot. 
    The legend displays labels for each plotted element and allows the user 
    to toggle visibility of individual plot items. Various options control 
    interaction behavior and layout.
    """
    def __cinit__(self):
        self._show = True
        self._location = <int>LegendLocation.NORTHWEST
        self._flags = 0

    '''
    # Probable doesn't work. Use instead plot no_legend
    @property
    def show(self):
        """
        Whether the legend is shown or hidden
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._show

    @show.setter
    def show(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if not(value) and self._show:
            self.set_hidden_and_propagate_to_siblings_no_handlers()
        self._show = value
    '''

    @property
    def location(self):
        """
        Position of the legend within the plot.
        
        Controls where the legend is positioned relative to the plot area.
        Default is LegendLocation.northwest (top-left corner of the plot).
        If the 'outside' property is True, this determines position outside
        the plot area.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return <LegendLocation>self._location

    @location.setter
    def location(self, LegendLocation value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value == LegendLocation.CENTER or \
           value == LegendLocation.NORTH or \
           value == LegendLocation.SOUTH or \
           value == LegendLocation.WEST or \
           value == LegendLocation.EAST or \
           value == LegendLocation.NORTHEAST or \
           value == LegendLocation.NORTHWEST or \
           value == LegendLocation.SOUTHEAST or \
           value == LegendLocation.SOUTHWEST:
            self._location = <int>value
        else:
            raise ValueError("Invalid location. Must be a LegendLocation")

    @property
    def no_buttons(self):
        """
        Whether legend icons can be clicked to hide/show plot items.
        
        When True, the legend entries will not function as interactive buttons.
        Users won't be able to toggle visibility of plot elements by clicking
        on their legend entries.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotLegendFlags_NoButtons) != 0

    @no_buttons.setter
    def no_buttons(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotLegendFlags_NoButtons
        if value:
            self._flags |= implot.ImPlotLegendFlags_NoButtons

    @property
    def no_highlight_item(self):
        """
        Whether to disable highlighting plot items on legend hover.
        
        When True, hovering over a legend entry will not highlight the 
        corresponding plot item. This can be useful for dense plots where
        highlighting might be visually distracting.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotLegendFlags_NoHighlightItem) != 0

    @no_highlight_item.setter
    def no_highlight_item(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotLegendFlags_NoHighlightItem
        if value:
            self._flags |= implot.ImPlotLegendFlags_NoHighlightItem

    @property
    def no_highlight_axis(self):
        """
        Whether to disable highlighting axes on legend hover.
        
        When True, hovering over an axis entry in the legend will not highlight
        that axis. Only relevant when multiple axes are enabled (X2/X3/Y2/Y3).
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotLegendFlags_NoHighlightAxis) != 0

    @no_highlight_axis.setter
    def no_highlight_axis(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotLegendFlags_NoHighlightAxis
        if value:
            self._flags |= implot.ImPlotLegendFlags_NoHighlightAxis

    @property
    def no_menus(self):
        """
        Whether to disable context menus in the legend.
        
        When True, right-clicking on legend entries will not open the context
        menu that provides additional options for controlling the plot. This
        simplifies the interface when these advanced features aren't needed.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotLegendFlags_NoMenus) != 0

    @no_menus.setter
    def no_menus(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotLegendFlags_NoMenus
        if value:
            self._flags |= implot.ImPlotLegendFlags_NoMenus

    @property
    def outside(self):
        """
        Whether to render the legend outside the plot area.
        
        When True, the legend will be positioned outside the main plot area,
        preserving more space for the actual plot content. The location 
        property still controls which side or corner the legend appears on.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotLegendFlags_Outside) != 0

    @outside.setter
    def outside(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotLegendFlags_Outside
        if value:
            self._flags |= implot.ImPlotLegendFlags_Outside

    @property
    def horizontal(self):
        """
        Whether to arrange legend entries horizontally instead of vertically.
        
        When True, legend entries will be displayed in a horizontal row rather
        than the default vertical column. This can be useful for plots with
        many elements when the legend would otherwise be too tall.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotLegendFlags_Horizontal) != 0

    @horizontal.setter
    def horizontal(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotLegendFlags_Horizontal
        if value:
            self._flags |= implot.ImPlotLegendFlags_Horizontal

    @property
    def sorted(self):
        """
        Whether to sort legend entries alphabetically.
        
        When True, legend entries will be displayed in alphabetical order
        rather than in the order they were added to the plot. This can make
        it easier to locate specific items in plots with many elements.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotLegendFlags_Sort) != 0

    @sorted.setter
    def sorted(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotLegendFlags_Sort
        if value:
            self._flags |= implot.ImPlotLegendFlags_Sort

    cdef void setup(self) noexcept nogil:
        implot.SetupLegend(<int>self._location, self._flags)
        # NOTE: Setup does just fill the location and flags.
        # No item is created at this point,
        # and thus we don't push fonts, check states, etc.

    cdef void after_setup(self) noexcept nogil:
        # The user can interact with legend configuration
        # with the mouse
        self._location = <int>GetLegendConfig(self._flags)


cdef class Plot(uiItem):
    """
    Interactive 2D plot that displays data with customizable axes and legend.
    
    A plot provides a canvas for visualizing data through various plot elements
    like lines, scatter points, bars, etc. The plot has up to six configurable
    axes (X1-X3, Y1-Y3) with X1 and Y1 enabled by default.
    
    The plot supports user interactions like panning, zooming, and context menus.
    Mouse hover and click events can be handled through the plot's handlers to
    implement custom interactions with the plotted data.
    
    Child elements are added as plot elements that represent different
    visualizations of data. These elements are rendered in the plotting area
    and can appear in the legend.
    """
    def __cinit__(self, context, *args, **kwargs):
        self.can_have_plot_element_child = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_hovered = True
        self.state.cap.has_content_region = True
        self._X1 = PlotAxisConfig(context)
        self._X2 = PlotAxisConfig(context, enabled=False)
        self._X3 = PlotAxisConfig(context, enabled=False)
        self._Y1 = PlotAxisConfig(context)
        self._Y2 = PlotAxisConfig(context, enabled=False)
        self._Y3 = PlotAxisConfig(context, enabled=False)
        self._legend = PlotLegendConfig(context)
        self._pan_button = imgui.ImGuiMouseButton_Left
        self._pan_modifier = 0
        self._fit_button = imgui.ImGuiMouseButton_Left
        self._menu_button = imgui.ImGuiMouseButton_Right
        self._override_mod = imgui.ImGuiMod_Ctrl
        self._zoom_mod = 0
        self._zoom_rate = 0.1
        self._use_local_time = False
        self._use_ISO8601 = False
        self._use_24hour_clock = False
        self._mouse_location = implot.ImPlotLocation_SouthEast
        # Box select/Query rects. To remove
        # Disabling implot query rects. This is better
        # to have it implemented outside implot.
        self._flags = implot.ImPlotFlags_NoBoxSelect

    @property
    def X1(self):
        """
        Configuration for the primary X-axis.
        
        This is the main horizontal axis, enabled by default. Use this property
        to configure axis appearance, scale, range limits, and other settings
        for the primary X-axis.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._X1

    @X1.setter
    def X1(self, PlotAxisConfig value not None):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._X1 = value

    @property
    def X2(self):
        """
        Configuration for the secondary X-axis.
        
        This is a supplementary horizontal axis, disabled by default. Enable
        it to plot data against a different horizontal scale than X1, useful
        for comparing different units or scales on the same plot.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._X2

    @X2.setter
    def X2(self, PlotAxisConfig value not None):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._X2 = value

    @property
    def X3(self):
        """
        Configuration for the tertiary X-axis.
        
        This is an additional horizontal axis, disabled by default. Enable
        it when you need a third horizontal scale, which can be useful for
        complex multi-scale plots or specialized scientific visualizations.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._X3

    @X3.setter
    def X3(self, PlotAxisConfig value not None):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._X3 = value

    @property
    def Y1(self):
        """
        Configuration for the primary Y-axis.
        
        This is the main vertical axis, enabled by default. Use this property
        to configure axis appearance, scale, range limits, and other settings
        for the primary Y-axis.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._Y1

    @Y1.setter
    def Y1(self, PlotAxisConfig value not None):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._Y1 = value

    @property
    def Y2(self):
        """
        Configuration for the secondary Y-axis.
        
        This is a supplementary vertical axis, disabled by default. Enable
        it to plot data against a different vertical scale than Y1, useful
        for displaying relationships between variables with different units.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._Y2

    @Y2.setter
    def Y2(self, PlotAxisConfig value not None):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._Y2 = value

    @property
    def Y3(self):
        """
        Configuration for the tertiary Y-axis.
        
        This is an additional vertical axis, disabled by default. Enable
        it when you need a third vertical scale, useful for specialized
        visualizations with multiple related but differently scaled variables.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._Y3

    @Y3.setter
    def Y3(self, PlotAxisConfig value not None):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._Y3 = value

    @property
    def axes(self):
        """
        All six axes configurations in a list.
        
        Returns the axes in the order [X1, X2, X3, Y1, Y2, Y3]. This property
        provides a convenient way to access all axes at once, for operations
        that need to apply to multiple axes simultaneously.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return [self._X1, self._X2, self._X3, \
                self._Y1, self._Y2, self._Y3]

    @property
    def legend_config(self):
        """
        Configuration for the plot legend.
        
        Controls the appearance and behavior of the legend, which displays
        labels for each plotted element. The legend can be positioned, styled,
        and configured to allow different interactions with plot elements.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._legend

    @legend_config.setter
    def legend_config(self, PlotLegendConfig value not None):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._legend = value

    @property
    def pan_button(self):
        """
        Mouse button used for panning the plot.
        
        When this button is held down while the cursor is over the plot area,
        moving the mouse will pan the view. The default is the left mouse button.
        Can be combined with pan_mod for more complex interaction patterns.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return make_MouseButton(self._pan_button)

    @pan_button.setter
    def pan_button(self, button):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if not(is_MouseButton(button)):
            raise ValueError(f"pan_button must be a MouseButton, not {button}")
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self._pan_button = <int>make_MouseButton(button)

    @property
    def pan_mod(self):
        """
        Keyboard modifier required for panning the plot.
        
        Specifies which keyboard keys (Shift, Ctrl, Alt, etc.) must be held
        down along with the pan_button to initiate panning. Default is no
        modifier, meaning pan_button works without any keys pressed.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return make_KeyMod(self._pan_modifier)

    @pan_mod.setter
    def pan_mod(self, modifier):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if not(is_KeyMod(modifier)):
            raise ValueError(f"pan_mod must be a combinaison of modifiers (KeyMod), not {modifier}")
        self._pan_modifier = <int>make_KeyMod(modifier)

    @property
    def fit_button(self):
        """
        Mouse button used to fit axes to data when double-clicked.
        
        When this button is double-clicked while the cursor is over the plot area,
        the axes will automatically adjust to fit all visible data. Default is
        the left mouse button.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return make_MouseButton(self._fit_button)

    @fit_button.setter
    def fit_button(self, button):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if not(is_MouseButton(button)):
            raise ValueError(f"fit_button must be a MouseButton, not {button}")
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self._fit_button = <int>make_MouseButton(button)

    @property
    def menu_button(self):
        """
        Mouse button used to open context menus.
        
        When this button is clicked over various parts of the plot, context
        menus will appear with relevant options. Default is the right mouse
        button. Context menus can be disabled entirely with no_menus.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return make_MouseButton(self._menu_button)

    @menu_button.setter
    def menu_button(self, button):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if not(is_MouseButton(button)):
            raise ValueError(f"menu_button must be a MouseButton, not {button}")
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self._menu_button = <int>make_MouseButton(button)

    @property
    def zoom_mod(self):
        """
        Keyboard modifier required for mouse wheel zooming.
        
        Specifies which keyboard keys (Shift, Ctrl, Alt, etc.) must be held
        down for the mouse wheel to zoom the plot. Default is no modifier,
        meaning the wheel zooms without any keys pressed.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return make_KeyMod(self._zoom_mod)

    @zoom_mod.setter
    def zoom_mod(self, modifier):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if not(is_KeyMod(modifier)):
            raise ValueError(f"zoom_mod must be a combinaison of modifiers (KeyMod), not {modifier}")
        self._zoom_mod = <int>make_KeyMod(modifier)

    @property
    def zoom_rate(self):
        """
        Zooming speed when using the mouse wheel.
        
        Determines how much the plot zooms with each mouse wheel tick. Default
        is 0.1 (10% of plot range per tick). Negative values invert the zoom
        direction, making scrolling up zoom out instead of in.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._zoom_rate

    @zoom_rate.setter
    def zoom_rate(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._zoom_rate = value

    @property
    def use_local_time(self):
        """
        Whether to display time axes in local timezone.
        
        When True and an axis is in time scale mode, times will be displayed
        according to the system's timezone. When False, UTC is used instead.
        Default is False.
        """
        return self._use_local_time

    @use_local_time.setter
    def use_local_time(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._use_local_time = value

    @property
    def use_ISO8601(self):
        """
        Whether to format dates according to ISO 8601.
        
        When True and an axis is in time scale mode, dates will be formatted
        according to the ISO 8601 standard (YYYY-MM-DD, etc.). Default is False,
        using locale-specific date formatting.
        """
        return self._use_ISO8601

    @use_ISO8601.setter
    def use_ISO8601(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._use_ISO8601 = value

    @property
    def use_24hour_clock(self):
        """
        Whether to use 24-hour time format.
        
        When True and an axis is displaying time, times will use 24-hour format
        (e.g., 14:30 instead of 2:30 PM). Default is False, using 12-hour format
        with AM/PM indicators where appropriate.
        """
        return self._use_24hour_clock

    @use_24hour_clock.setter
    def use_24hour_clock(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._use_24hour_clock = value

    @property
    def no_title(self):
        """
        Whether to hide the plot title.
        
        When True, the plot's title (provided in the label parameter) will not
        be displayed, saving vertical space. Useful for plots where the title
        is redundant or when maximizing the plotting area.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotFlags_NoTitle) != 0

    @no_title.setter
    def no_title(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotFlags_NoTitle
        if value:
            self._flags |= implot.ImPlotFlags_NoTitle

    @property
    def no_menus(self):
        """
        Whether to disable context menus.
        
        When True, right-clicking (or using the assigned menu_button) will not
        open context menus that provide options for fitting data, changing
        scales, etc. Useful for plots meant for viewing only.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotFlags_NoMenus) != 0

    @no_menus.setter
    def no_menus(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotFlags_NoMenus
        if value:
            self._flags |= implot.ImPlotFlags_NoMenus

    @property
    def no_mouse_pos(self):
        """
        Whether to hide the mouse position text.
        
        When True, the current coordinates of the mouse cursor within the plot
        area will not be displayed. Useful for cleaner appearance or when
        mouse position information is not relevant.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotFlags_NoMouseText) != 0

    @no_mouse_pos.setter
    def no_mouse_pos(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotFlags_NoMouseText
        if value:
            self._flags |= implot.ImPlotFlags_NoMouseText

    @property
    def crosshairs(self):
        """
        Whether to display crosshair lines at the mouse position.
        
        When True, horizontal and vertical lines will follow the mouse cursor
        while hovering over the plot area, making it easier to visually align
        points with the axes values.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotFlags_Crosshairs) != 0

    @crosshairs.setter
    def crosshairs(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotFlags_Crosshairs
        if value:
            self._flags |= implot.ImPlotFlags_Crosshairs

    @property
    def equal_aspects(self):
        """
        Whether to maintain equal pixel-to-data ratio for X and Y axes.
        
        When True, the plot ensures that one unit along the X axis has the
        same pixel length as one unit along the Y axis. Essential for
        visualizations where spatial proportions matter, like maps or shapes.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotFlags_Equal) != 0

    @equal_aspects.setter
    def equal_aspects(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotFlags_Equal
        if value:
            self._flags |= implot.ImPlotFlags_Equal

    @property
    def no_inputs(self):
        """
        Whether to disable all user interactions with the plot.
        
        When True, the plot becomes view-only, disabling panning, zooming,
        and all other mouse/keyboard interactions. Useful for display-only
        plots or when handling interactions through custom code.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotFlags_NoInputs) != 0

    @no_inputs.setter
    def no_inputs(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotFlags_NoInputs
        if value:
            self._flags |= implot.ImPlotFlags_NoInputs

    @property
    def no_frame(self):
        """
        Whether to hide the plot's outer frame.
        
        When True, the rectangular border around the entire plot will not be
        drawn. Creates a more minimal appearance, especially when plots need to
        blend with the surrounding UI.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotFlags_NoFrame) != 0

    @no_frame.setter
    def no_frame(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotFlags_NoFrame
        if value:
            self._flags |= implot.ImPlotFlags_NoFrame

    @property
    def no_legend(self):
        """
        Whether to hide the plot legend.
        
        When True, the legend showing labels for plotted elements will not be
        displayed. Useful when plot elements are self-explanatory or to
        maximize the plotting area when space is limited.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotFlags_NoLegend) != 0

    @no_legend.setter
    def no_legend(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotFlags_NoLegend
        if value:
            self._flags |= implot.ImPlotFlags_NoLegend

    @property
    def mouse_location(self):
        """
        Position where mouse coordinates are displayed within the plot.
        
        Controls where the text showing the current mouse position (in plot
        coordinates) appears. Default is the southeast corner (bottom-right).
        Only relevant when no_mouse_pos is False.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return <LegendLocation>self._mouse_location

    @mouse_location.setter
    def mouse_location(self, LegendLocation value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value == LegendLocation.CENTER or \
           value == LegendLocation.NORTH or \
           value == LegendLocation.SOUTH or \
           value == LegendLocation.WEST or \
           value == LegendLocation.EAST or \
           value == LegendLocation.NORTHEAST or \
           value == LegendLocation.NORTHWEST or \
           value == LegendLocation.SOUTHEAST or \
           value == LegendLocation.SOUTHWEST:
            self._mouse_location = <int>value
        else:
            raise ValueError("Invalid location. Must be a LegendLocation")

    cdef bint draw_item(self) noexcept nogil:
        cdef bint visible
        implot.GetStyle().UseLocalTime = self._use_local_time
        implot.GetStyle().UseISO8601 = self._use_ISO8601
        implot.GetStyle().Use24HourClock = self._use_24hour_clock
        implot.GetInputMap().Pan = self._pan_button
        implot.GetInputMap().Fit = self._fit_button
        implot.GetInputMap().Menu = self._menu_button
        implot.GetInputMap().ZoomRate = self._zoom_rate
        implot.GetInputMap().PanMod = self._pan_modifier
        implot.GetInputMap().ZoomMod = self._zoom_mod
        implot.GetInputMap().OverrideMod = self._override_mod

        self._X1.mutex.lock()
        self._X2.mutex.lock()
        self._X3.mutex.lock()
        self._Y1.mutex.lock()
        self._Y2.mutex.lock()
        self._Y3.mutex.lock()
        self._legend.mutex.lock()

        # Check at least one axis of each is enabled ?

        visible = implot.BeginPlot(self._imgui_label.c_str(),
                                   Vec2ImVec2(self.get_requested_size()),
                                   self._flags)
        # BeginPlot created the imgui Item
        if visible:
            self.state.cur.rect_size = ImVec2Vec2(imgui.GetItemRectSize())
            self.state.cur.rendered = True
            
            # Setup mouse position text
            implot.SetupMouseText(self._mouse_location, 0)
            
            # Setup axes
            self._X1.setup(implot.ImAxis_X1)
            self._X2.setup(implot.ImAxis_X2)
            self._X3.setup(implot.ImAxis_X3)
            self._Y1.setup(implot.ImAxis_Y1)
            self._Y2.setup(implot.ImAxis_Y2)
            self._Y3.setup(implot.ImAxis_Y3)

            # From DPG: workaround for stuck selection
            # Unsure why it should be done here and not above
            # -> Not needed because query rects are not implemented with implot
            #if (imgui.GetIO().KeyMods & self._query_toggle_mod) == imgui.GetIO().KeyMods and \
            #    (imgui.IsMouseDown(self._select_button) or imgui.IsMouseReleased(self._select_button)):
            #    implot.GetInputMap().OverrideMod = imgui.ImGuiMod_None

            self._legend.setup()

            implot.SetupFinish()

            # These states are valid after SetupFinish
            # Update now to have up to date data for handlers of children.
            self.state.cur.hovered = implot.IsPlotHovered()
            update_current_mouse_states(self.state)
            self.state.cur.content_region_size =ImVec2Vec2( implot.GetPlotSize())
            self.state.cur.content_pos = ImVec2Vec2(implot.GetPlotPos())

            self._X1.after_setup(implot.ImAxis_X1)
            self._X2.after_setup(implot.ImAxis_X2)
            self._X3.after_setup(implot.ImAxis_X3)
            self._Y1.after_setup(implot.ImAxis_Y1)
            self._Y2.after_setup(implot.ImAxis_Y2)
            self._Y3.after_setup(implot.ImAxis_Y3)
            self._legend.after_setup()

            implot.PushPlotClipRect(0.)

            draw_plot_element_children(self)

            implot.PopPlotClipRect()
            # The user can interact with the plot
            # configuration with the mouse
            self._flags = GetPlotConfig()
            implot.EndPlot()
            self._X1.after_plot(implot.ImAxis_X1)
            self._X2.after_plot(implot.ImAxis_X2)
            self._X3.after_plot(implot.ImAxis_X3)
            self._Y1.after_plot(implot.ImAxis_Y1)
            self._Y2.after_plot(implot.ImAxis_Y2)
            self._Y3.after_plot(implot.ImAxis_Y3)

            # If we show the mouse position text,
            # a mouse motion impacts the visual
            if (self._flags & implot.ImPlotFlags_NoMouseText) == 0:
                if self.state.cur.hovered or self.state.prev.hovered:
                    self.context.viewport.force_present()

        elif self.state.cur.rendered:
            self.set_hidden_no_handler_and_propagate_to_children_with_handlers()
            self._X1.set_hidden()
            self._X2.set_hidden()
            self._X3.set_hidden()
            self._Y1.set_hidden()
            self._Y2.set_hidden()
            self._Y3.set_hidden()
        self._X1.mutex.unlock()
        self._X2.mutex.unlock()
        self._X3.mutex.unlock()
        self._Y1.mutex.unlock()
        self._Y2.mutex.unlock()
        self._Y3.mutex.unlock()
        self._legend.mutex.unlock()
        return False
        # We don't need to restore the plot config as we
        # always overwrite it.


cdef class plotElementWithLegend(plotElement):
    """
    Base class for plot children with a legend entry.
    
    Plot elements derived from this class appear in the plot legend and can
    have their own popup menu when their legend entry is right-clicked. This
    popup can contain additional widgets as children of the element.
    
    The legend entry can be hovered, clicked, or toggled to show/hide the
    element. Custom handlers can be attached to respond to these interactions.
    """
    def __cinit__(self):
        self.state.cap.can_be_hovered = True # The legend only
        self.p_state = &self.state
        self._enabled = True
        self._enabled_dirty = True
        self._legend_button = imgui.ImGuiMouseButton_Right
        self._legend = True
        self.state.cap.can_be_hovered = True
        self.can_have_widget_child = True

    @property
    def no_legend(self):
        """
        Whether to hide this element from the plot legend.
        
        When True, this element will not appear in the legend, though the
        element itself will still be plotted. This is useful for auxiliary
        elements that don't need their own legend entry.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return not(self._legend)

    @no_legend.setter
    def no_legend(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._legend = not(value)
        # unsure if needed
        self._flags &= ~implot.ImPlotItemFlags_NoLegend
        if value:
            self._flags |= implot.ImPlotItemFlags_NoLegend

    @property
    def ignore_fit(self):
        """
        Whether to exclude this element when auto-fitting axes.
        
        When True, this element's data range will be ignored when automatically
        determining the plot's axis limits. This is useful for reference lines
        or annotations that shouldn't affect the data view.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotItemFlags_NoFit) != 0

    @ignore_fit.setter
    def ignore_fit(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotItemFlags_NoFit
        if value:
            self._flags |= implot.ImPlotItemFlags_NoFit

    @property
    def enabled(self):
        """
        Whether this element is currently visible in the plot.
        
        Controls the visibility of this element while keeping its entry in the
        legend. When False, the element isn't drawn but can still be toggled
        through the legend. This is different from the show property which
        completely hides both the element and its legend entry.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._enabled

    @enabled.setter
    def enabled(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value != self._enabled:
            self._enabled_dirty = True
        self._enabled = value

    @property
    def font(self):
        """
        Font used for rendering this element's text.
        
        Determines the font applied to any text rendered as part of this
        element and its child elements. If None, the parent plot's font
        is used instead.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._font

    @font.setter
    def font(self, baseFont value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._font = value

    @property
    def legend_button(self):
        """
        Mouse button that opens this element's legend popup.
        
        Specifies which mouse button activates the popup menu when clicked on
        this element's legend entry. Default is the right mouse button.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return make_MouseButton(self._legend_button)

    @legend_button.setter
    def legend_button(self, button):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if not(is_MouseButton(button)):
            raise ValueError(f"legend_button must be a MouseButton, not {button}")
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        self._legend_button = <int>make_MouseButton(button)

    @property
    def legend_handlers(self):
        """
        Event handlers attached to this element's legend entry.
        
        These handlers respond to interactions with this element's legend
        entry, such as when it's hovered or clicked. They don't respond to
        interactions with the plotted element itself.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int32_t i
        cdef baseHandler handler
        for i in range(<int>self._handlers.size()):
            handler = <baseHandler>self._handlers[i]
            result.append(handler)
        return result

    @legend_handlers.setter
    def legend_handlers(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list items = []
        cdef int32_t i
        if value is None:
            clear_obj_vector(self._handlers)
            return
        if PySequence_Check(value) == 0:
            value = (value,)
        for i in range(len(value)):
            if not(isinstance(value[i], baseHandler)):
                raise TypeError(f"{value[i]} is not a handler")
            # Check the handlers can use our states. Else raise error
            (<baseHandler>value[i]).check_bind(self)
            items.append(value[i])
        # Success: bind
        clear_obj_vector(self._handlers)
        append_obj_vector(self._handlers, items)

    @property
    def legend_state(self):
        """
        The current state of the legend
        
        The state is an instance of ItemStateView which is a class
        with property getters to retrieve various readonly states.

        The ItemStateView instance is just a view over the current states,
        not a copy, thus the states get updated automatically.
        """
        return ItemStateView.create(self)

    cdef void draw(self) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)

        # Check the axes are enabled
        if not(self._show) or \
           not(self.context.viewport.enabled_axes[self._axes[0]]) or \
           not(self.context.viewport.enabled_axes[self._axes[1]]):
            self.set_previous_states()
            self.state.cur.rendered = False
            self.state.cur.hovered = False
            self.propagate_hidden_state_to_children_with_handlers()
            self.run_handlers()
            return

        self.set_previous_states()

        # push theme, font
        if self._font is not None:
            self._font.push()

        if self._theme is not None:
            self._theme.push()

        implot.SetAxes(self._axes[0], self._axes[1])

        if self._enabled_dirty:
            implot.HideNextItem(not(self._enabled), implot.ImPlotCond_Always)
            self._enabled_dirty = False
        else:
            self._enabled = IsItemHidden(self._imgui_label.c_str())
        self.draw_element()

        self.state.cur.rendered = True
        self.state.cur.hovered = False
        cdef Vec2 pos_w, pos_p
        if self._legend:
            # Popup that gets opened with a click on the entry
            # We don't open it if it will be empty as it will
            # display a small rect with nothing in it. It's surely
            # better to not display anything in this case.
            if self.last_widgets_child is not None:
                if implot.BeginLegendPopup(self._imgui_label.c_str(),
                                           self._legend_button):
                    if self.last_widgets_child is not None:
                        # sub-window
                        pos_w = ImVec2Vec2(imgui.GetCursorScreenPos())
                        pos_p = pos_w
                        swap_Vec2(pos_w, self.context.viewport.window_pos)
                        swap_Vec2(pos_p, self.context.viewport.parent_pos)
                        draw_ui_children(self)
                        self.context.viewport.window_pos = pos_w
                        self.context.viewport.parent_pos = pos_p
                    implot.EndLegendPopup()
            self.state.cur.hovered = implot.IsLegendEntryHovered(self._imgui_label.c_str())


        # pop theme, font
        if self._theme is not None:
            self._theme.pop()

        if self._font is not None:
            self._font.pop()

        self.run_handlers()

    cdef void draw_element(self) noexcept nogil:
        return

cdef class plotElementXY(plotElementWithLegend):
    def __cinit__(self):
        return
        #self._X = DCG1DArrayView() # implicit
        #self._Y = DCG1DArrayView()

    @property 
    def X(self):
        """
        Values on the X axis.
        
        Accepts numpy arrays or buffer compatible objects.
        Supported types for no copy are int32, float32, float64,
        else a float64 copy is used.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return get_object_from_1D_array_view(self._X)

    @X.setter
    def X(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._X.reset()
        else:
            self._X.reset(value)

    @property
    def Y(self):
        """
        Values on the Y axis
        
        Accepts numpy arrays or buffer compatible objects.
        Supported types for no copy are int32, float32, float64,
        else a float64 copy is used.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return get_object_from_1D_array_view(self._Y)

    @Y.setter
    def Y(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._Y.reset()
        else:
            self._Y.reset(value)

    cdef void check_arrays(self) noexcept nogil:
        # plot function require same type
        # and same stride
        if self._X.type() != self._Y.type():
            with gil:
                self._X.ensure_double()
                self._Y.ensure_double()
        if self._X.stride() != self._Y.stride():
            with gil:
                self._X.ensure_contiguous()
                self._Y.ensure_contiguous()

cdef class PlotLine(plotElementXY):
    """
    Plots a line graph from X,Y data points.
    
    Displays a connected line through a series of data points defined by X and Y
    coordinates. Various styling options like segmented lines, closed loops, 
    shading beneath the line, and NaN handling can be configured.
    """
    @property
    def segments(self):
        """
        Whether to draw disconnected line segments rather than a continuous line.
        
        When enabled, line segments are drawn between consecutive points without
        connecting the whole series. Useful for representing discontinuous data
        or creating dashed/dotted effects.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotLineFlags_Segments) != 0

    @segments.setter
    def segments(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotLineFlags_Segments
        if value:
            self._flags |= implot.ImPlotLineFlags_Segments

    @property
    def loop(self):
        """
        Whether to connect the first and last points of the line.
        
        When enabled, the line plot becomes a closed shape by adding a segment
        from the last point back to the first point. Useful for plotting cyclic
        data or creating closed shapes.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotLineFlags_Loop) != 0

    @loop.setter
    def loop(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotLineFlags_Loop
        if value:
            self._flags |= implot.ImPlotLineFlags_Loop

    @property
    def skip_nan(self):
        """
        Whether to skip NaN values instead of breaking the line.
        
        When enabled, NaN values in the data will be skipped, connecting the
        points on either side directly. When disabled, a NaN creates a break
        in the line. Useful for handling missing data points.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotLineFlags_SkipNaN) != 0

    @skip_nan.setter
    def skip_nan(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotLineFlags_SkipNaN
        if value:
            self._flags |= implot.ImPlotLineFlags_SkipNaN

    @property
    def no_clip(self):
        """
        Whether to disable clipping of markers at the plot edges.
        
        When enabled, point markers that would normally be clipped at the edge of
        the plot will be fully visible. This can be useful for ensuring all data
        points are displayed, even when they are partially outside the plotting area.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotLineFlags_NoClip) != 0

    @no_clip.setter
    def no_clip(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotLineFlags_NoClip
        if value:
            self._flags |= implot.ImPlotLineFlags_NoClip

    @property
    def shaded(self):
        """
        Whether to fill the area between the line and the x-axis.
        
        When enabled, the region between the line and the horizontal axis will
        be filled with the line's color at reduced opacity. This is useful for
        emphasizing areas under curves or visualizing integrals.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotLineFlags_Shaded) != 0

    @shaded.setter
    def shaded(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotLineFlags_Shaded
        if value:
            self._flags |= implot.ImPlotLineFlags_Shaded

    cdef void draw_element(self) noexcept nogil:
        self.check_arrays()
        cdef int32_t size = min(self._X.size(), self._Y.size())
        if size == 0:
            return

        if self._X.type() == DCG_INT32:
            implot.PlotLine[int32_t](self._imgui_label.c_str(),
                                 self._X.data[int32_t](),
                                 self._Y.data[int32_t](),
                                 size,
                                 self._flags,
                                 0,
                                 self._X.stride())
        elif self._X.type() == DCG_FLOAT:
            implot.PlotLine[float](self._imgui_label.c_str(),
                                   self._X.data[float](),
                                   self._Y.data[float](),
                                   size,
                                   self._flags,
                                   0,
                                   self._X.stride())
        elif self._X.type() == DCG_DOUBLE:
            implot.PlotLine[double](self._imgui_label.c_str(),
                                    self._X.data[double](),
                                    self._Y.data[double](),
                                    size,
                                    self._flags,
                                    0,
                                    self._X.stride())
        elif self._X.type() == DCG_UINT8:
            implot.PlotLine[uint8_t](self._imgui_label.c_str(),
                                    self._X.data[uint8_t](),
                                    self._Y.data[uint8_t](),
                                    size,
                                    self._flags,
                                    0,
                                    self._X.stride())

cdef class plotElementXYY(plotElementWithLegend):
    def __cinit__(self):
        return
        #self._X = DCG1DArrayView() # implicit
        #self._Y1 = DCG1DArrayView()
        #self._Y2 = DCG1DArrayView()

    @property 
    def X(self):
        """
        Values on the X axis.
        
        Accepts numpy arrays or buffer compatible objects.
        Supported types for no copy are int32, float32, float64,
        else a float64 copy is used.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return get_object_from_1D_array_view(self._X)

    @X.setter
    def X(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._X.reset()
        else:
            self._X.reset(value)

    @property
    def Y1(self):
        """
        Values on the Y1 axis.

        Accepts numpy arrays or buffer compatible objects.
        Supported types for no copy are int32, float32, float64,
        else a float64 copy is used.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return get_object_from_1D_array_view(self._Y1)

    @Y1.setter
    def Y1(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._Y1.reset()
        else:
            self._Y1.reset(value)

    @property
    def Y2(self):
        """
        Values on the Y2 axis.

        Accepts numpy arrays or buffer compatible objects.
        Supported types for no copy are int32, float32, float64,
        else a float64 copy is used.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return get_object_from_1D_array_view(self._Y2)

    @Y2.setter
    def Y2(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._Y2.reset()
        else:
            self._Y2.reset(value)

    cdef void check_arrays(self) noexcept nogil:
        # plot function require same type
        # and same stride
        if self._X.type() != self._Y1.type() or self._X.type() != self._Y2.type():
            with gil:
                self._X.ensure_double()
                self._Y1.ensure_double()
                self._Y2.ensure_double()
        if self._X.stride() != self._Y1.stride() or self._X.stride() != self._Y2.stride():
            with gil:
                self._X.ensure_contiguous()
                self._Y1.ensure_contiguous()
                self._Y2.ensure_contiguous()

cdef class PlotShadedLine(plotElementXYY):
    cdef void draw_element(self) noexcept nogil:
        self.check_arrays()
        cdef int32_t size = min(min(self._X.size(), self._Y1.size()), self._Y2.size())
        if size == 0:
            return

        if self._X.type() == DCG_INT32:
            implot.PlotShaded[int32_t](self._imgui_label.c_str(),
                                   self._X.data[int32_t](),
                                   self._Y1.data[int32_t](),
                                   self._Y2.data[int32_t](),
                                   size,
                                   self._flags,
                                   0,
                                   self._X.stride())
        elif self._X.type() == DCG_FLOAT:
            implot.PlotShaded[float](self._imgui_label.c_str(),
                                     self._X.data[float](),
                                     self._Y1.data[float](),
                                     self._Y2.data[float](),
                                     size,
                                     self._flags,
                                     0,
                                     self._X.stride())
        elif self._X.type() == DCG_DOUBLE:
            implot.PlotShaded[double](self._imgui_label.c_str(),
                                      self._X.data[double](),
                                      self._Y1.data[double](),
                                      self._Y2.data[double](),
                                      size,
                                      self._flags,
                                      0,
                                      self._X.stride())
        elif self._X.type() == DCG_UINT8:
            implot.PlotShaded[uint8_t](self._imgui_label.c_str(),
                                      self._X.data[uint8_t](),
                                      self._Y1.data[uint8_t](),
                                      self._Y2.data[uint8_t](),
                                      size,
                                      self._flags,
                                      0,
                                      self._X.stride())

cdef class PlotStems(plotElementXY):
    """
    Plots stem graphs from X,Y data points.
    
    Displays a series of data points as vertical or horizontal lines (stems)
    extending from a baseline to each point. This representation emphasizes 
    individual data points and their values relative to a fixed reference.
    Useful for discrete data visualization like impulse responses or digital
    signals.
    """
    @property
    def horizontal(self):
        """
        Whether to render stems horizontally instead of vertically.
        
        When True, the stems extend horizontally from the Y-axis to each data
        point. When False (default), stems extend vertically from the X-axis
        to each data point. Horizontal stems are useful when the independent
        variable is on the Y-axis.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotStemsFlags_Horizontal) != 0

    @horizontal.setter
    def horizontal(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotStemsFlags_Horizontal
        if value:
            self._flags |= implot.ImPlotStemsFlags_Horizontal

    cdef void draw_element(self) noexcept nogil:
        self.check_arrays()
        cdef int32_t size = min(self._X.size(), self._Y.size())
        if size == 0:
            return

        if self._X.type() == DCG_INT32:
            implot.PlotStems[int32_t](self._imgui_label.c_str(),
                                 self._X.data[int32_t](),
                                 self._Y.data[int32_t](),
                                 size,
                                 0.,
                                 self._flags,
                                 0,
                                 self._X.stride())
        elif self._X.type() == DCG_FLOAT:
            implot.PlotStems[float](self._imgui_label.c_str(),
                                   self._X.data[float](),
                                   self._Y.data[float](),
                                   size,
                                   0.,
                                   self._flags,
                                   0,
                                   self._X.stride())
        elif self._X.type() == DCG_DOUBLE:
            implot.PlotStems[double](self._imgui_label.c_str(),
                                    self._X.data[double](),
                                    self._Y.data[double](),
                                    size,
                                    0.,
                                    self._flags,
                                    0,
                                    self._X.stride())
        elif self._X.type() == DCG_UINT8:
            implot.PlotStems[uint8_t](self._imgui_label.c_str(),
                                    self._X.data[uint8_t](),
                                    self._Y.data[uint8_t](),
                                    size,
                                    0.,
                                    self._flags,
                                    0,
                                    self._X.stride())

cdef class PlotBars(plotElementXY):
    """
    Plots bar graphs from X,Y data points.
    
    Displays a series of bars at the X positions with heights determined by Y
    values. Unlike PlotBarGroups which shows grouped categorical data, this 
    element shows individual bars for continuous or discrete data points. 
    Suitable for histograms, bar charts, and column graphs.
    """
    def __cinit__(self):
        self._weight = 1.

    @property
    def weight(self):
        """
        Width of each bar in plot units.
        
        Controls the thickness of each bar. A value of 1.0 means bars will 
        touch when X values are spaced 1.0 units apart. Smaller values create
        thinner bars with gaps between them, larger values create overlapping
        bars.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._weight

    @weight.setter
    def weight(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._weight = value

    @property
    def horizontal(self):
        """
        Whether to render bars horizontally instead of vertically.
        
        When True, bars extend horizontally from the Y-axis with lengths
        determined by Y values. When False (default), bars extend vertically
        from the X-axis with heights determined by Y values.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotBarsFlags_Horizontal) != 0

    @horizontal.setter
    def horizontal(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotBarsFlags_Horizontal
        if value:
            self._flags |= implot.ImPlotBarsFlags_Horizontal

    cdef void draw_element(self) noexcept nogil:
        self.check_arrays()
        cdef int32_t size = min(self._X.size(), self._Y.size())
        if size == 0:
            return

        if self._X.type() == DCG_INT32:
            implot.PlotBars[int32_t](self._imgui_label.c_str(),
                                 self._X.data[int32_t](),
                                 self._Y.data[int32_t](),
                                 size,
                                 self._weight,
                                 self._flags,
                                 0,
                                 self._X.stride())
        elif self._X.type() == DCG_FLOAT:
            implot.PlotBars[float](self._imgui_label.c_str(),
                                   self._X.data[float](),
                                   self._Y.data[float](),
                                   size,
                                   self._weight,
                                   self._flags,
                                   0,
                                   self._X.stride())
        elif self._X.type() == DCG_DOUBLE:
            implot.PlotBars[double](self._imgui_label.c_str(),
                                    self._X.data[double](),
                                    self._Y.data[double](),
                                    size,
                                    self._weight,
                                    self._flags,
                                    0,
                                    self._X.stride())
        elif self._X.type() == DCG_UINT8:
            implot.PlotBars[uint8_t](self._imgui_label.c_str(),
                                    self._X.data[uint8_t](),
                                    self._Y.data[uint8_t](),
                                    size,
                                    self._weight,
                                    self._flags,
                                    0,
                                    self._X.stride())

cdef class PlotStairs(plotElementXY):
    """
    Plots a stair-step graph from X,Y data points.
    
    Creates a step function visualization where values change abruptly at each
    X coordinate rather than smoothly as in a line plot. This is useful for
    representing discrete state changes, piecewise constant functions, or
    signals that maintain a value until an event causes a change.
    """
    @property
    def pre_step(self):
        """
        Whether steps occur before or after each X position.
        
        When True, the Y value steps happen before (to the left of) each X
        position, making the interval (x[i-1], x[i]] have the value y[i].
        When False (default), steps happen after each X position, making the
        interval [x[i], x[i+1]) have value y[i].
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotStairsFlags_PreStep) != 0

    @pre_step.setter
    def pre_step(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotStairsFlags_PreStep
        if value:
            self._flags |= implot.ImPlotStairsFlags_PreStep

    @property
    def shaded(self):
        """
        Whether to fill the area between the stairs and the axis.
        
        When True, the region between the step function and the X-axis is
        filled with the line's color at reduced opacity. This creates a more
        prominent visual representation and helps emphasize the cumulative
        effect of the steps.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotStairsFlags_Shaded) != 0

    @shaded.setter
    def shaded(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotStairsFlags_Shaded
        if value:
            self._flags |= implot.ImPlotStairsFlags_Shaded

    cdef void draw_element(self) noexcept nogil:
        self.check_arrays()
        cdef int32_t size = min(self._X.size(), self._Y.size())
        if size == 0:
            return

        if self._X.type() == DCG_INT32:
            implot.PlotStairs[int32_t](self._imgui_label.c_str(),
                                 self._X.data[int32_t](),
                                 self._Y.data[int32_t](),
                                 size,
                                 self._flags,
                                 0,
                                 self._X.stride())
        elif self._X.type() == DCG_FLOAT:
            implot.PlotStairs[float](self._imgui_label.c_str(),
                                   self._X.data[float](),
                                   self._Y.data[float](),
                                   size,
                                   self._flags,
                                   0,
                                   self._X.stride())
        elif self._X.type() == DCG_DOUBLE:
            implot.PlotStairs[double](self._imgui_label.c_str(),
                                    self._X.data[double](),
                                    self._Y.data[double](),
                                    size,
                                    self._flags,
                                    0,
                                    self._X.stride())
        elif self._X.type() == DCG_UINT8:
            implot.PlotStairs[uint8_t](self._imgui_label.c_str(),
                                    self._X.data[uint8_t](),
                                    self._Y.data[uint8_t](),
                                    size,
                                    self._flags,
                                    0,
                                    self._X.stride())

cdef class plotElementX(plotElementWithLegend):
    def __cinit__(self):
        return
        #self._X = DCG1DArrayView() # Implicit

    @property
    def X(self):
        """
        Values on the X axis.
        
        Accepts numpy arrays or buffer compatible objects.
        Supported types for no copy are int32, float32, float64,
        else a float64 copy is used.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return get_object_from_1D_array_view(self._X)

    @X.setter 
    def X(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._X.reset()
        else:
            self._X.reset(value)

    cdef void check_arrays(self) noexcept nogil:
        return


cdef class PlotInfLines(plotElementX):
    """
    Draw infinite lines at specified positions.
    
    Creates vertical or horizontal lines that span the entire plot area at each
    X coordinate provided. These lines are useful for highlighting specific values,
    thresholds, or reference points across the entire plotting area.
    """
    @property
    def horizontal(self):
        """
        Whether to draw horizontal lines instead of vertical.
        
        When True, lines are drawn horizontally across the plot at each Y position.
        When False (default), lines are drawn vertically at each X position.
        Horizontal lines span the entire width of the plot while vertical lines
        span the entire height.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotInfLinesFlags_Horizontal) != 0

    @horizontal.setter
    def horizontal(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotInfLinesFlags_Horizontal
        if value:
            self._flags |= implot.ImPlotInfLinesFlags_Horizontal

    cdef void draw_element(self) noexcept nogil:
        self.check_arrays()
        cdef int32_t size = self._X.size()
        if size == 0:
            return

        if self._X.type() == DCG_INT32:
            implot.PlotInfLines[int32_t](self._imgui_label.c_str(),
                                 self._X.data[int32_t](),
                                 size,
                                 self._flags,
                                 0,
                                 self._X.stride())
        elif self._X.type() == DCG_FLOAT:
            implot.PlotInfLines[float](self._imgui_label.c_str(),
                                   self._X.data[float](),
                                   size,
                                   self._flags,
                                   0,
                                   self._X.stride())
        elif self._X.type() == DCG_DOUBLE:
            implot.PlotInfLines[double](self._imgui_label.c_str(),
                                    self._X.data[double](),
                                    size,
                                    self._flags,
                                    0,
                                    self._X.stride())
        elif self._X.type() == DCG_UINT8:
            implot.PlotInfLines[uint8_t](self._imgui_label.c_str(),
                                    self._X.data[uint8_t](),
                                    size,
                                    self._flags,
                                    0,
                                    self._X.stride())

cdef class PlotScatter(plotElementXY):
    """
    Plot data points as individual markers.
    
    Creates a scatter plot from X,Y coordinate pairs with customizable point
    markers. Unlike line plots, scatter plots show individual data points
    without connecting lines, making them ideal for visualizing discrete
    data points, correlations, or distributions where the relationship
    between points is not continuous.
    """
    @property
    def no_clip(self):
        """
        Whether to prevent clipping markers at plot edges.
        
        When True, point markers that would normally be clipped at the edge of
        the plot will be fully visible. This can be useful for ensuring all data
        points are displayed completely, even when they are partially outside
        the plotting area.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotScatterFlags_NoClip) != 0

    @no_clip.setter
    def no_clip(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotScatterFlags_NoClip
        if value:
            self._flags |= implot.ImPlotScatterFlags_NoClip

    cdef void draw_element(self) noexcept nogil:
        self.check_arrays()
        cdef int32_t size = min(self._X.size(), self._Y.size())
        if size == 0:
            return

        if self._X.type() == DCG_INT32:
            implot.PlotScatter[int32_t](self._imgui_label.c_str(),
                                 self._X.data[int32_t](),
                                 self._Y.data[int32_t](),
                                 size,
                                 self._flags,
                                 0,
                                 self._X.stride())
        elif self._X.type() == DCG_FLOAT:
            implot.PlotScatter[float](self._imgui_label.c_str(),
                                   self._X.data[float](),
                                   self._Y.data[float](),
                                   size,
                                   self._flags,
                                   0,
                                   self._X.stride())
        elif self._X.type() == DCG_DOUBLE:
            implot.PlotScatter[double](self._imgui_label.c_str(),
                                    self._X.data[double](),
                                    self._Y.data[double](),
                                    size,
                                    self._flags,
                                    0,
                                    self._X.stride())
        elif self._X.type() == DCG_UINT8:
            implot.PlotScatter[uint8_t](self._imgui_label.c_str(),
                                    self._X.data[uint8_t](),
                                    self._Y.data[uint8_t](),
                                    size,
                                    self._flags,
                                    0,
                                    self._X.stride())

'''
cdef class plotDraggable(plotElement):
    """
    Base class for plot draggable elements.
    """
    def __cinit__(self):
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_active = True
        self._flags = implot.ImPlotDragToolFlags_None

    @property
    def color(self):
        """
        Writable attribute: text color.
        If set to 0 (default), that is
        full transparent text, use the
        default value given by the style
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return <int>self._color

    @color.setter
    def color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._color = parse_color(value)

    @property
    def no_cursors(self):
        """
        Writable attribute to make drag tools
        not change cursor icons when hovered or held.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotDragToolFlags_NoCursors) != 0

    @no_cursors.setter
    def no_cursors(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotDragToolFlags_NoCursors
        if value:
            self._flags |= implot.ImPlotDragToolFlags_NoCursors

    @property
    def ignore_fit(self):
        """
        Writable attribute to make the drag tool
        not considered for plot fits.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotDragToolFlags_NoFit) != 0

    @ignore_fit.setter
    def ignore_fit(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotDragToolFlags_NoFit
        if value:
            self._flags |= implot.ImPlotDragToolFlags_NoFit

    @property
    def ignore_inputs(self):
        """
        Writable attribute to lock the tool from user inputs
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotDragToolFlags_NoInputs) != 0

    @ignore_inputs.setter
    def ignore_inputs(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotDragToolFlags_NoInputs
        if value:
            self._flags |= implot.ImPlotDragToolFlags_NoInputs

    @property
    def delayed(self):
        """
        Writable attribute to delay rendering
        by one frame.

        One use case is position-contraints.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotDragToolFlags_Delayed) != 0

    @delayed.setter
    def delayed(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotDragToolFlags_Delayed
        if value:
            self._flags |= implot.ImPlotDragToolFlags_Delayed

    @property
    def active(self):
        """
        Readonly attribute: is the drag tool held
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.active

    @property
    def clicked(self):
        """
        Readonly attribute: has the item just been clicked.
        The returned value is a tuple of len 5 containing the individual test
        mouse buttons (up to 5 buttons)
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return tuple(self.state.cur.clicked)

    @property
    def double_clicked(self):
        """
        Readonly attribute: has the item just been double-clicked.
        The returned value is a tuple of len 5 containing the individual test
        mouse buttons (up to 5 buttons)
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.double_clicked

    @property
    def hovered(self):
        """
        Readonly attribute: Is the item hovered.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.hovered

    cdef void draw(self) noexcept nogil:
        cdef int32_t i
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)

        # Check the axes are enabled
        if not(self._show) or \
           not(self.context.viewport.enabled_axes[self._axes[0]]) or \
           not(self.context.viewport.enabled_axes[self._axes[1]]):
            self.state.cur.hovered = False
            self.state.cur.rendered = False
            for i in range(imgui.ImGuiMouseButton_COUNT):
                self.state.cur.clicked[i] = False
                self.state.cur.double_clicked[i] = False
            self.propagate_hidden_state_to_children_with_handlers()
            return

        # push theme, font

        if self._theme is not None:
            self._theme.push()

        implot.SetAxes(self._axes[0], self._axes[1])
        self.state.cur.rendered = True
        self.draw_element()

        # pop theme, font
        if self._theme is not None:
            self._theme.pop()

        self.run_handlers()

    cdef void draw_element(self) noexcept nogil:
        return
'''

cdef class DrawInPlot(plotElementWithLegend):
    """
    Enables drawing items inside a plot using plot coordinates.
    
    This element allows you to add drawing elements (shapes, texts, etc.) 
    as children that will be rendered within the plot area and positioned
    according to the plot's coordinate system. This makes it easy to add
    annotations, highlights, and custom visualizations that adapt to plot
    scaling.
    
    By default, this element does not show up in the legend, though this
    can be changed.
    """
    def __cinit__(self):
        self.can_have_drawing_child = True
        self._legend = False
        self._ignore_fit = False

    @property
    def ignore_fit(self):
        """
        Whether this element should be excluded when auto-fitting axes.
        
        When set to True, the drawing elements within this container won't 
        influence the automatic fitting of axes. This is useful when adding
        reference elements or annotations that shouldn't affect the scale of
        the plot.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._ignore_fit

    @ignore_fit.setter
    def ignore_fit(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._ignore_fit = value

    cdef void draw(self) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)

        # Check the axes are enabled
        if not(self._show) or \
           not(self.context.viewport.enabled_axes[self._axes[0]]) or \
           not(self.context.viewport.enabled_axes[self._axes[1]]):
            self.set_previous_states()
            self.state.cur.rendered = False
            self.state.cur.hovered = False
            self.propagate_hidden_state_to_children_with_handlers()
            self.run_handlers()
            return

        self.set_previous_states()

        # push theme, font
        if self._font is not None:
            self._font.push()

        if self._theme is not None:
            self._theme.push()

        implot.SetAxes(self._axes[0], self._axes[1])

        cdef bint render = True

        if self._legend:
            render = implot.BeginItem(self._imgui_label.c_str(), self._flags, -1)
        else:
            implot.PushPlotClipRect(0.)

        # Reset current drawInfo
        self.context.viewport.scales = [1., 1.]
        self.context.viewport.shifts = [0., 0.]
        self.context.viewport.in_plot = True
        self.context.viewport.plot_fit = False if self._ignore_fit else implot.FitThisFrame()
        self.context.viewport.thickness_multiplier = implot.GetStyle().LineWeight
        self.context.viewport.size_multiplier = implot.GetPlotSize().x / implot.GetPlotLimits(self._axes[0], self._axes[1]).Size().x
        self.context.viewport.parent_pos = ImVec2Vec2(implot.GetPlotPos())

        if render:
            draw_drawing_children(self, implot.GetPlotDrawList())

            if self._legend:
                implot.EndItem()
            else:
                implot.PopPlotClipRect()

        self.state.cur.rendered = True
        self.state.cur.hovered = False
        cdef Vec2 pos_w, pos_p
        if self._legend:
            # Popup that gets opened with a click on the entry
            # We don't open it if it will be empty as it will
            # display a small rect with nothing in it. It's surely
            # better to not display anything in this case.
            if self.last_widgets_child is not None:
                if implot.BeginLegendPopup(self._imgui_label.c_str(),
                                           self._legend_button):
                    if self.last_widgets_child is not None:
                        # sub-window
                        pos_w = ImVec2Vec2(imgui.GetCursorScreenPos())
                        pos_p = pos_w
                        swap_Vec2(pos_w, self.context.viewport.window_pos)
                        swap_Vec2(pos_p, self.context.viewport.parent_pos)
                        draw_ui_children(self)
                        self.context.viewport.window_pos = pos_w
                        self.context.viewport.parent_pos = pos_p
                    implot.EndLegendPopup()
            self.state.cur.hovered = implot.IsLegendEntryHovered(self._imgui_label.c_str())

        # pop theme, font
        if self._theme is not None:
            self._theme.pop()

        if self._font is not None:
            self._font.pop()

        self.run_handlers()

cdef class Subplots(uiItem):
    """
    Creates a grid of plots that share various axis properties.
    
    Organizes multiple Plot objects in a grid layout, allowing for shared axes, 
    synchronized zooming/panning, and compact visualization of related data. 
    Plots can share legends to conserve space and maintain consistency of 
    visualization across the grid.
    
    The grid dimensions are configurable, and individual row/column sizes can 
    be customized through size ratios. Plot children are added in row-major 
    order by default, but can be changed to column-major ordering as needed.
    """
    def __cinit__(self):
        self.can_have_widget_child = True
        self._flags = implot.ImPlotSubplotFlags_None
        self._rows = 1
        self._cols = 1
        self.state.cap.can_be_clicked = True
        self.state.cap.can_be_dragged = True
        self.state.cap.can_be_hovered = True

    @property
    def rows(self):
        """
        Number of subplot rows in the grid.
        
        Controls the vertical division of the subplot area. Each row can 
        contain multiple plots depending on the number of columns. Must be 
        at least 1.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex) 
        return self._rows

    @rows.setter 
    def rows(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value < 1:
            raise ValueError("Rows must be > 0")
        self._rows = value

    @property
    def cols(self):
        """
        Number of subplot columns in the grid.
        
        Controls the horizontal division of the subplot area. Each column can 
        contain multiple plots depending on the number of rows. Must be at 
        least 1.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._cols

    @cols.setter
    def cols(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value < 1:
            raise ValueError("Columns must be > 0")
        self._cols = value

    @property
    def row_ratios(self):
        """
        Size ratios for subplot rows.
        
        Controls the relative height of each row in the grid. For example, 
        setting [1, 2] would make the second row twice as tall as the first.
        When not specified, rows have equal heights.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int i
        for i in range(<int>self._row_ratios.size()):
            result.append(self._row_ratios[i])
        return result

    @row_ratios.setter
    def row_ratios(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._row_ratios.clear()
        cdef float v
        if PySequence_Check(value) > 0:
            if len(value) < self._rows:
                raise ValueError("Not enough row ratios provided")
            for v in value:
                if v <= 0:
                    raise ValueError("Ratios must be > 0")
                self._row_ratios.push_back(v)

    @property
    def col_ratios(self):
        """
        Size ratios for subplot columns.
        
        Controls the relative width of each column in the grid. For example, 
        setting [1, 2, 1] would make the middle column twice as wide as the 
        others. When not specified, columns have equal widths.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int i
        for i in range(<int>self._col_ratios.size()):
            result.append(self._col_ratios[i])
        return result

    @col_ratios.setter
    def col_ratios(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._col_ratios.clear()
        cdef float v
        if PySequence_Check(value) > 0:
            if len(value) < self._cols:
                raise ValueError("Not enough column ratios provided") 
            for v in value:
                if v <= 0:
                    raise ValueError("Ratios must be > 0")
                self._col_ratios.push_back(v)

    @property
    def no_legend(self):
        """
        Whether to hide subplot legends.
        
        When True and share_legends is active, the shared legend is hidden.
        When False, the legend is displayed according to the legend settings
        of each individual plot or the shared legend if enabled.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotSubplotFlags_NoLegend) != 0

    @property 
    def no_title(self):
        """
        Whether to hide subplot titles.
        
        When True, titles of all subplot children are hidden, even if they have
        titles specified in their label property. This creates a cleaner, more
        compact appearance when titles would be redundant or unnecessary.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotSubplotFlags_NoTitle) != 0

    @no_title.setter
    def no_title(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotSubplotFlags_NoTitle
        if value:
            self._flags |= implot.ImPlotSubplotFlags_NoTitle

    @property 
    def no_menus(self):
        """
        Whether to disable subplot context menus.
        
        When True, right-clicking on any subplot will not open the context menu
        that provides options for fitting data, changing scales, etc. This 
        simplifies the interface and prevents accidental changes to the 
        appearance.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotSubplotFlags_NoMenus) != 0

    @no_menus.setter
    def no_menus(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex) 
        self._flags &= ~implot.ImPlotSubplotFlags_NoMenus
        if value:
            self._flags |= implot.ImPlotSubplotFlags_NoMenus

    @property
    def no_resize(self):
        """
        Whether to disable subplot resize splitters.
        
        When True, the splitter bars between subplots are removed, preventing
        users from adjusting the relative sizes of individual plots. This 
        ensures a consistent layout and prevents accidental resizing during
        interaction.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotSubplotFlags_NoResize) != 0

    @no_resize.setter
    def no_resize(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotSubplotFlags_NoResize
        if value:
            self._flags |= implot.ImPlotSubplotFlags_NoResize

    @property
    def no_align(self): 
        """
        Whether to disable subplot edge alignment.
        
        When True, edge alignment between subplots is disabled, allowing 
        for more flexible layout but potentially creating misaligned axes.
        When False, subplot edges are aligned to create a clean grid 
        appearance.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotSubplotFlags_NoAlign) != 0

    @no_align.setter
    def no_align(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotSubplotFlags_NoAlign
        if value:
            self._flags |= implot.ImPlotSubplotFlags_NoAlign

    @property
    def col_major(self):
        """
        Whether to add plots in column-major order.
        
        When True, child plots are arranged going down columns first, then 
        across rows. When False (default), plots are arranged across rows first, 
        then down columns. This affects the order in which child plots are 
        assigned to grid positions.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotSubplotFlags_ColMajor) != 0

    @col_major.setter
    def col_major(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotSubplotFlags_ColMajor
        if value:
            self._flags |= implot.ImPlotSubplotFlags_ColMajor

    @property
    def share_legends(self):
        """
        Whether to share legend items across all subplots.
        
        When True, legend entries from all plots are combined into a single 
        legend. This creates a cleaner appearance and avoids duplicate entries 
        when the same data series appears in multiple plots. The location of 
        this shared legend is determined by the first plot's legend settings.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotSubplotFlags_ShareItems) != 0

    @share_legends.setter
    def share_legends(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotSubplotFlags_ShareItems
        if value:
            self._flags |= implot.ImPlotSubplotFlags_ShareItems

    ''' -> does not work, use config item sharing instead
    @property
    def share_x_all(self):
        """
        Whether to link X1-axis limits across all plots.
        
        When True, all plots share the same X1-axis limits, meaning that 
        zooming or panning on the X-axis of any plot affects all other plots. 
        This is useful for comparing multiple series across the same domain, 
        such as time series over the same period.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotSubplotFlags_LinkAllX) != 0

    @share_x_all.setter
    def share_x_all(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotSubplotFlags_LinkAllX
        if value:
            self._flags |= implot.ImPlotSubplotFlags_LinkAllX

    @property
    def share_rows(self):
        """
        Whether to link X1/Y1-axis limits within each row.
        
        When True, plots in the same row share the same X1-axis limits, and 
        plots in the same column share the same Y1-axis limits. This creates 
        alignment for comparing data across related plots while preserving 
        independence between different rows and columns.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotSubplotFlags_LinkRows) != 0

    @share_rows.setter
    def share_rows(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotSubplotFlags_LinkRows
        if value:
            self._flags |= implot.ImPlotSubplotFlags_LinkRows

    @property
    def share_cols(self):
        """
        Whether to link X1/Y1-axis limits within each column.
        
        When True, plots in the same column share the same Y1-axis limits, and
        plots in the same row share the same X1-axis limits. This is useful for
        comparing distributions or trends across different groups while 
        maintaining aligned scales.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotSubplotFlags_LinkCols) != 0

    @share_cols.setter
    def share_cols(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotSubplotFlags_LinkCols
        if value:
            self._flags |= implot.ImPlotSubplotFlags_LinkCols

    @property
    def share_y_all(self):
        """
        Whether to link Y1-axis limits across all plots.
        
        When True, all plots share the same Y1-axis limits, meaning that 
        zooming or panning on the Y-axis of any plot affects all other plots. 
        This ensures consistent scale across all visualizations, making direct 
        value comparisons easier between plots.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotSubplotFlags_LinkAllY) != 0

    @share_y_all.setter
    def share_y_all(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotSubplotFlags_LinkAllY
        if value:
            self._flags |= implot.ImPlotSubplotFlags_LinkAllY
    '''

    cdef bint draw_item(self) noexcept nogil:
        cdef float* row_sizes = NULL
        cdef float* col_sizes = NULL
        cdef bint visible
        cdef Vec2 pos_p, parent_size_backup
        cdef PyObject *child
        cdef int32_t n = self._rows * self._cols
        cdef int32_t i

        # TODO: Not sure if shared legend needs specific handling.

        # Get row/col ratios if specified
        if <int>self._row_ratios.size() >= self._rows:
            row_sizes = self._row_ratios.data()
        if <int>self._col_ratios.size() >= self._cols:
            col_sizes = self._col_ratios.data()

        # Begin subplot layout
        visible = implot.BeginSubplots(self._imgui_label.c_str(),
                                       self._rows,
                                       self._cols,
                                       Vec2ImVec2(self.get_requested_size()),
                                       self._flags,
                                       row_sizes,
                                       col_sizes)
        self.state.cur.rect_size = ImVec2Vec2(imgui.GetItemRectSize())
        if visible:
            self.state.cur.hovered = implot.IsSubplotsHovered()
            update_current_mouse_states(self.state)

            pos_p = ImVec2Vec2(imgui.GetCursorScreenPos())
            swap_Vec2(pos_p, self.context.viewport.parent_pos)
            parent_size_backup = self.context.viewport.parent_size
            self.context.viewport.parent_size = self.state.cur.rect_size
            # Render child plots
            if self.last_widgets_child is not None:
                child = <PyObject*> self.last_widgets_child
                while (<baseItem>child).prev_sibling is not None:
                    child = <PyObject *>(<baseItem>child).prev_sibling
                # There must be at maximum n children
                for i in range(n):
                    if (<uiItem>child) is None:
                        break
                    # Only accept plot children
                    # for now only plots set can_have_plot_element_child
                    if not((<uiItem>child).can_have_plot_element_child):
                        continue
                    (<uiItem>child).draw()
                    child = <PyObject *>(<baseItem>child).next_sibling

            self.context.viewport.parent_pos = pos_p
            self.context.viewport.parent_size = parent_size_backup

            # End subplot 
            implot.EndSubplots()
        elif self.state.cur.rendered:
            self.set_hidden_no_handler_and_propagate_to_children_with_handlers()
        return False

cdef class PlotBarGroups(plotElementWithLegend):
    """
    Plots grouped bar charts with multiple series of data.
    
    Creates groups of bars where each group has multiple bars side-by-side (or
    stacked). This is ideal for comparing multiple data series across different
    categories. Each row in the values array represents a series (with consistent
    color), and each column represents a group position.
    """
    def __cinit__(self):
        self._group_size = 0.67
        self._shift = 0
        #self._values = DCG2DContiguousArrayView()  # Replace numpy array
        self._labels = DCGVector[DCGString]()
        self._labels.push_back(string_from_bytes(b"Item 0"))

    @property
    def values(self):
        """
        2D array containing the values for each bar.
        
        The array should be row-major where each row represents one data series 
        (one color/legend entry) and each column represents a group position.
        For example, with 3 series and 4 groups, the shape would be (3,4).
        By default, the implementation tries to use the array without copying.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return get_object_from_2D_array_view(self._values)

    @values.setter
    def values(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._values.reset()
        else:
            self._values.reset(value)
        cdef int32_t k
        for k in range(<int>self._labels.size(), <int>self._values.rows()):
            self._labels.push_back(string_from_str(f"Item {k}"))

    @property
    def labels(self):
        """
        Labels for each data series.
        
        These labels appear in the legend and identify each data series (row in
        the values array). The number of labels should match the number of rows
        in the values array. If not enough labels are provided, default labels
        like "Item N" will be generated.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int i
        for i in range(<int>self._labels.size()):
            result.append(string_to_str(self._labels[i]))
        return result

    @labels.setter 
    def labels(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef int32_t i, k
        self._labels.clear()
        if value is None:
            return
        if PySequence_Check(value) > 0:
            i = 0
            for v in value:
                self._labels.push_back(string_from_str(v))
                i = i + 1
            for k in range(i, <int>self._values.rows()):
                self._labels.push_back(string_from_bytes(b"Item %d" % k))
        else:
            raise ValueError(f"Invalid type {type(value)} passed as labels. Expected array of strings")

    @property 
    def group_size(self):
        """
        Portion of the available width used for bars within each group.
        
        Controls how much of the available space between groups is filled with
        bars. Value ranges from 0.0 to 1.0, where 1.0 means no space between
        groups and 0.0 means no visible bars. The default value of 0.67 leaves
        some space between groups while making bars large enough to read easily.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._group_size

    @group_size.setter
    def group_size(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._group_size = value

    @property
    def shift(self):
        """
        Horizontal offset for all groups in plot units.
        
        Allows shifting the entire group chart left or right. This is useful for
        aligning multiple bar group plots or creating animations. A positive value
        shifts all groups to the right, while a negative value shifts them to
        the left.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._shift

    @shift.setter
    def shift(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._shift = value

    @property
    def horizontal(self):
        """
        Whether bars are oriented horizontally instead of vertically.
        
        When True, bars extend horizontally from the Y-axis with groups arranged
        vertically. When False (default), bars extend vertically from the X-axis
        with groups arranged horizontally. Horizontal orientation is useful when
        dealing with long category names or when comparing values across many
        groups.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotBarGroupsFlags_Horizontal) != 0

    @horizontal.setter
    def horizontal(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotBarGroupsFlags_Horizontal
        if value:
            self._flags |= implot.ImPlotBarGroupsFlags_Horizontal

    @property
    def stacked(self):
        """
        Whether bars within each group are stacked.
        
        When True, bars in each group are stacked on top of each other (or side
        by side for horizontal orientation) rather than being displayed side by
        side. Stacking is useful for showing both individual components and their
        sum, such as for part-to-whole relationships within categories.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotBarGroupsFlags_Stacked) != 0

    @stacked.setter
    def stacked(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotBarGroupsFlags_Stacked
        if value:
            self._flags |= implot.ImPlotBarGroupsFlags_Stacked

    cdef void draw_element(self) noexcept nogil:
        if self._values.rows() == 0 or self._values.cols() == 0:
            return

        cdef int32_t i
        # Note: we ensured that self._values.rows() <= <int>self._labels.size()

        cdef vector[const char*] labels_cstr
        for i in range(<int>self._values.rows()):
            labels_cstr.push_back(self._labels[i].c_str())

        if self._values.type() == DCG_INT32:
            implot.PlotBarGroups[int32_t](labels_cstr.data(),
                                      self._values.data[int32_t](),
                                      <int>self._values.rows(),
                                      <int>self._values.cols(),
                                      self._group_size,
                                      self._shift,
                                      self._flags)
        elif self._values.type() == DCG_FLOAT:
            implot.PlotBarGroups[float](labels_cstr.data(),
                                      self._values.data[float](),
                                      <int>self._values.rows(),
                                      <int>self._values.cols(),
                                      self._group_size,
                                      self._shift,
                                      self._flags)
        elif self._values.type() == DCG_DOUBLE:
            implot.PlotBarGroups[double](labels_cstr.data(),
                                      self._values.data[double](),
                                      <int>self._values.rows(),
                                      <int>self._values.cols(),
                                      self._group_size,
                                      self._shift,
                                      self._flags)
        elif self._values.type() == DCG_UINT8:
            implot.PlotBarGroups[uint8_t](labels_cstr.data(),
                                      self._values.data[uint8_t](),
                                      <int>self._values.rows(),
                                      <int>self._values.cols(),
                                      self._group_size,
                                      self._shift,
                                      self._flags)

cdef class PlotPieChart(plotElementWithLegend):
    """
    Plots a pie chart from value arrays.
    
    Creates a circular pie chart where each slice represents a value from the provided
    array. The chart can be positioned anywhere in the plot area and sized as needed.
    Each slice can have a label and a value displayed alongside it. The chart can
    automatically normalize values to ensure a complete circle, or maintain relative
    proportions of the values as provided.
    """
    def __cinit__(self):
        # self._values = DCG1DArrayView()
        self._x = 0.0
        self._y = 0.0
        self._radius = 1.0
        self._angle = 90.0
        self._label_format = string_from_bytes(b"%.1f")
        self._labels = DCGVector[DCGString]()
        self._labels.push_back(string_from_bytes(b"Slice 0"))

    @property
    def values(self):
        """
        Array of values for each pie slice.
        
        By default, will try to use the passed array directly for its 
        internal backing (no copy). Supported types for no copy are 
        np.int32, np.float32, np.float64.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return get_object_from_1D_array_view(self._values)

    @values.setter
    def values(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._values.reset()
        else:
            self._values.reset(value)
            self._values.ensure_contiguous()
        cdef int32_t k
        for k in range(<int>self._labels.size(), <int32_t>self._values.size()):
            self._labels.push_back(string_from_str(f"Slice {k}"))

    @property
    def labels(self):
        """
        Array of labels for each pie slice.
        
        These labels identify each slice in the chart and appear in the legend
        if enabled. If fewer labels than values are provided, default labels like
        "Slice N" will be generated for the remaining slices.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int i
        for i in range(<int>self._labels.size()):
            result.append(string_to_str(self._labels[i]))
        return result

    @labels.setter
    def labels(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._labels.clear()
        cdef int32_t k
        if value is None:
            return
        if PySequence_Check(value) > 0:
            for v in value:
                self._labels.push_back(string_from_str(v))
            for k in range(len(value), <int32_t>self._values.size()):
                self._labels.push_back(string_from_bytes(b"Slice %d" % k))
        else:
            raise ValueError(f"Invalid type {type(value)} passed as labels. Expected array of strings")

    @property
    def x(self):
        """
        X coordinate of pie chart center in plot units.
        
        Determines the horizontal position of the pie chart within the plot area.
        This position is in plot coordinate space, not screen pixels.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._x

    @x.setter
    def x(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._x = value

    @property
    def y(self):
        """
        Y coordinate of pie chart center in plot units.
        
        Determines the vertical position of the pie chart within the plot area.
        This position is in plot coordinate space, not screen pixels.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._y

    @y.setter
    def y(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._y = value

    @property
    def radius(self):
        """
        Radius of pie chart in plot units.
        
        Controls the size of the pie chart. The radius is in plot coordinate units,
        not screen pixels, so the visual size will adjust when zooming the plot.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._radius

    @radius.setter
    def radius(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._radius = value

    @property
    def angle(self):
        """
        Starting angle for first slice in degrees.
        
        Controls the rotation of the entire pie chart. The default value of 90 
        places the first slice at the top. The angle increases clockwise with 0
        being at the right side of the circle.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._angle

    @angle.setter
    def angle(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._angle = value

    @property
    def normalize(self):
        """
        Whether to normalize values to always create a full circle.
        
        When enabled, the values will be treated as relative proportions and scaled
        to fill the entire circle, regardless of their sum. When disabled, the
        slices will maintain their exact proportions, potentially not completing
        a full circle if the sum is less than the expected total.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotPieChartFlags_Normalize) != 0

    @normalize.setter
    def normalize(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotPieChartFlags_Normalize
        if value:
            self._flags |= implot.ImPlotPieChartFlags_Normalize

    @property
    def ignore_hidden(self):
        """
        Whether to ignore hidden slices when drawing the pie chart.
        
        When enabled, slices that have been hidden (via legend toggling) will be
        completely removed from the chart as if they were not present. When disabled,
        hidden slices still take up their space in the pie but are not visible.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotPieChartFlags_IgnoreHidden) != 0

    @ignore_hidden.setter
    def ignore_hidden(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotPieChartFlags_IgnoreHidden
        if value:
            self._flags |= implot.ImPlotPieChartFlags_IgnoreHidden

    @property
    def label_format(self):
        """
        Format string for slice value labels.
        
        Controls how numeric values are displayed alongside each slice. Uses 
        printf-style formatting like "%.1f" for one decimal place. Set to an
        empty string to disable value labels entirely.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return string_to_str(self._label_format)

    @label_format.setter
    def label_format(self, str value not None):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._label_format = string_from_str(value)

    cdef void draw_element(self) noexcept nogil:
        if self._values.size() == 0:
            return

        cdef int32_t i
        # Note: we ensured that self._values.size() <= <int>self._labels.size()

        cdef vector[const char*] labels_cstr
        for i in range(<int32_t>self._values.size()):
            labels_cstr.push_back(self._labels[i].c_str())

        if self._values.type() == DCG_INT32:
            implot.PlotPieChart[int32_t](labels_cstr.data(),
                                    self._values.data[int32_t](),
                                    <int>self._values.size(),
                                    self._x,
                                    self._y,
                                    self._radius,
                                    self._label_format.c_str(),
                                    self._angle,
                                    self._flags)
        elif self._values.type() == DCG_FLOAT:
            implot.PlotPieChart[float](labels_cstr.data(),
                                      self._values.data[float](),
                                      <int>self._values.size(),
                                      self._x,
                                      self._y,
                                      self._radius, 
                                      self._label_format.c_str(),
                                      self._angle,
                                      self._flags)
        elif self._values.type() == DCG_DOUBLE:
            implot.PlotPieChart[double](labels_cstr.data(),
                                       self._values.data[double](),
                                       <int>self._values.size(),
                                       self._x,
                                       self._y,
                                       self._radius,
                                       self._label_format.c_str(),
                                       self._angle,
                                       self._flags)
        elif self._values.type() == DCG_UINT8:
            implot.PlotPieChart[uint8_t](labels_cstr.data(),
                                      self._values.data[uint8_t](),
                                      <int>self._values.size(),
                                      self._x,
                                      self._y,
                                      self._radius,
                                      self._label_format.c_str(),
                                      self._angle,
                                      self._flags)

cdef class PlotDigital(plotElementXY):
    """
    Plots a digital signal as a step function from X,Y data.
    
    Digital plots represent binary or multi-level signals where values change
    instantaneously rather than continuously. These plots are anchored to the 
    bottom of the plot area and do not scale with Y-axis zooming, making them
    ideal for displaying digital signals, logic traces, or state changes over
    time.
    """

    cdef void draw_element(self) noexcept nogil:
        self.check_arrays()
        cdef int32_t size = min(self._X.size(), self._Y.size())
        if size == 0:
            return

        if self._X.type() == DCG_INT32:
            implot.PlotDigital[int32_t](self._imgui_label.c_str(),
                                   self._X.data[int32_t](),
                                   self._Y.data[int32_t](),
                                   size,
                                   self._flags,
                                   0,
                                   self._X.stride())
        elif self._X.type() == DCG_FLOAT:
            implot.PlotDigital[float](self._imgui_label.c_str(),
                                     self._X.data[float](),
                                     self._Y.data[float](),
                                     size,
                                     self._flags,
                                     0,
                                     self._X.stride())
        elif self._X.type() == DCG_DOUBLE:
            implot.PlotDigital[double](self._imgui_label.c_str(),
                                      self._X.data[double](),
                                      self._Y.data[double](),
                                      size,
                                      self._flags,
                                      0,
                                      self._X.stride())
        elif self._X.type() == DCG_UINT8:
            implot.PlotDigital[uint8_t](self._imgui_label.c_str(),
                                     self._X.data[uint8_t](),
                                     self._Y.data[uint8_t](),
                                     size,
                                     self._flags,
                                     0,
                                     self._X.stride())


cdef class PlotErrorBars(plotElementXY):
    """
    Plots vertical or horizontal error bars for X,Y data points.
    
    Error bars visualize uncertainty or variation in measurements by displaying
    a line extending from each data point. Each error bar can have different 
    positive and negative values, allowing for asymmetrical error representation.
    This is particularly useful for scientific data where measurements have known
    or estimated uncertainties.
    """
    def __cinit__(self):
        return
        #self._pos = DCG1DArrayView()
        #self._neg = DCG1DArrayView() # optional - empty when unused

    @property
    def positives(self):
        """
        Positive error values array.
        
        Specifies the positive (upward for vertical, rightward for horizontal) 
        error magnitude for each data point. If negatives is not provided, these 
        values will be used for both directions, creating symmetrical error bars.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return get_object_from_1D_array_view(self._pos)

    @positives.setter
    def positives(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._pos.reset()
        else:
            self._pos.reset(value)

    @property
    def negatives(self):
        """
        Negative error values array.
        
        Specifies the negative (downward for vertical, leftward for horizontal)
        error magnitude for each data point. When not provided or empty, the
        error bars will be symmetrical, using the values in positives for both
        directions.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return get_object_from_1D_array_view(self._neg)

    @negatives.setter
    def negatives(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._neg.reset()
        else: 
            self._neg.reset(value)

    @property
    def horizontal(self):
        """
        Whether error bars are oriented horizontally instead of vertically.
        
        When True, error bars extend horizontally from each data point along the
        X axis. When False (default), error bars extend vertically along the Y
        axis. Horizontal error bars are useful when the uncertainty is in the
        independent variable rather than the dependent one.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotErrorBarsFlags_Horizontal) != 0

    @horizontal.setter
    def horizontal(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotErrorBarsFlags_Horizontal
        if value:
            self._flags |= implot.ImPlotErrorBarsFlags_Horizontal

    cdef void draw_element(self) noexcept nogil:
        self.check_arrays()
        cdef int32_t size = min(<int32_t>self._X.size(),
                              min(<int32_t>self._Y.size(), 
                                  <int32_t>self._pos.size()))
        if <int32_t>self._neg.size() > 0:
            size = min(size, <int32_t>self._neg.size())
        if size == 0:
            return
        cdef const void* neg_data
        if self._neg.size() > 0:
            neg_data = self._neg.data[int32_t]()
        else:
            neg_data = self._pos.data[int32_t]()

        if self._X.type() == DCG_INT32:
            implot.PlotErrorBars[int32_t](self._imgui_label.c_str(),
                                      self._X.data[int32_t](),
                                      self._Y.data[int32_t](),
                                      <const int32_t*>neg_data,
                                      self._pos.data[int32_t](),
                                      size,
                                      self._flags,
                                      0,
                                      self._X.stride())
        elif self._X.type() == DCG_FLOAT:
            implot.PlotErrorBars[float](self._imgui_label.c_str(),
                                        self._X.data[float](),
                                        self._Y.data[float](),
                                        <const float*>neg_data,
                                        self._pos.data[float](),
                                        size,
                                        self._flags,
                                        0,
                                        self._X.stride())
            
        elif self._X.type() == DCG_DOUBLE:
            implot.PlotErrorBars[double](self._imgui_label.c_str(),
                                         self._X.data[double](),
                                         self._Y.data[double](),
                                         <const double*>neg_data,
                                         self._pos.data[double](),
                                         size,
                                         self._flags,
                                         0,
                                         self._X.stride())
        elif self._X.type() == DCG_UINT8:
            implot.PlotErrorBars[uint8_t](self._imgui_label.c_str(),
                                        self._X.data[uint8_t](),
                                        self._Y.data[uint8_t](),
                                        <const uint8_t*>neg_data,
                                        self._pos.data[uint8_t](),
                                        size,
                                        self._flags,
                                        0,
                                        self._X.stride())

cdef class PlotAnnotation(plotElement):
    """
    Adds a text annotation at a specific point in a plot.
    
    Annotations are small text bubbles that can be attached to specific points
    in the plot to provide additional context, labels, or explanations. They
    are always rendered on top of other plot elements and can have customizable
    background colors, offsets, and clamping behavior to ensure visibility.
    """
    def __cinit__(self):
        self._x = 0.0
        self._y = 0.0
        self._offset = make_Vec2(0., 0.)

    @property
    def x(self):
        """
        X coordinate of the annotation in plot units.
        
        Specifies the horizontal position of the annotation anchor point within
        the plot's coordinate system. This position will be used as the base
        point from which the annotation offset is applied.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._x

    @x.setter
    def x(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._x = value

    @property
    def y(self):
        """
        Y coordinate of the annotation in plot units.
        
        Specifies the vertical position of the annotation anchor point within
        the plot's coordinate system. This position will be used as the base
        point from which the annotation offset is applied.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._y

    @y.setter
    def y(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._y = value

    @property
    def text(self):
        """
        Text content of the annotation.
        
        The string to display in the annotation bubble. This text can include
        any characters and will be rendered using the current font settings.
        For dynamic annotations, this property can be updated on each frame.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return string_to_str(self._text)

    @text.setter
    def text(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._text = string_from_str(value)

    @property
    def bg_color(self):
        """
        Background color of the annotation bubble.
        
        Color values are provided as an RGBA list with values in the [0,1] range.
        When set to 0 (fully transparent), the text color is determined by the
        ImPlotCol_InlayText style. Otherwise, the text color is automatically 
        set to white or black for optimal contrast with the background.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self._bg_color)
        return list(color)

    @bg_color.setter
    def bg_color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._bg_color = parse_color(value)

    @property
    def offset(self):
        """
        Offset in pixels from the anchor point.
        
        Specifies the displacement of the annotation bubble from its anchor 
        position in screen pixels. This allows placing the annotation near 
        a data point without overlapping it. Provided as a tuple of (x, y)
        values, where positive values move right and down.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._offset.x, self._offset.y)

    @offset.setter
    def offset(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if PySequence_Check(value) == 0 or len(value) != 2:
            raise ValueError("Offset must be a 2-tuple")
        self._offset = make_Vec2(value[0], value[1])

    @property
    def clamp(self):
        """
        Whether to ensure the annotation stays within the plot area.
        
        When enabled, the annotation will always be visible within the plot area
        even if its anchor point is outside or near the edge. When disabled,
        annotations may be partially or completely hidden if their anchor points
        are outside the plot boundaries.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._clamp

    @clamp.setter
    def clamp(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._clamp = value

    cdef void draw_element(self) noexcept nogil:
        cdef char[3] format_str = [37, 115, 0] # %s 
        implot.Annotation(self._x,
                          self._y,
                          imgui_ColorConvertU32ToFloat4(self._bg_color),
                          Vec2ImVec2(self._offset),
                          self._clamp,
                          format_str,
                          self._text.c_str())

cdef class PlotHistogram(plotElementX):
    """
    Plots a histogram from X data points.
    
    Creates bins from input data and displays the count (or density) of values 
    falling within each bin as vertical or horizontal bars. Various binning 
    methods are available to automatically determine appropriate bin sizes,
    or explicit bin counts can be specified. The display can be customized
    with cumulative counts, density normalization, and range constraints.
    """
    def __cinit__(self):
        self._bins = -1  # Default to sqrt
        self._bar_scale = 1.0
        self._range_min = 0.0
        self._range_max = 0.0
        self._has_range = False

    @property
    def bins(self):
        """
        Number of bins or automatic binning method to use.
        
        Accepts positive integers for explicit bin count or negative values for 
        automatic binning methods:
        - -1: sqrt(n) bins [default]
        - -2: Sturges formula: k = log2(n) + 1
        - -3: Rice rule: k = 2 * cuberoot(n)
        - -4: Scott's rule: h = 3.49 sigma/cuberoot(n)
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._bins

    @bins.setter 
    def bins(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value < -4:
            raise ValueError("Invalid bins value")
        self._bins = value

    @property
    def bar_scale(self):
        """
        Scale factor for bar heights.
        
        Multiplies all bin heights by this value before display. This allows 
        visual amplification or reduction of the histogram without changing the
        underlying data. Default is 1.0.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._bar_scale

    @bar_scale.setter
    def bar_scale(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._bar_scale = value

    @property 
    def range(self):
        """
        Optional (min, max) range for binning.
        
        When set, only values within this range will be included in the
        histogram bins. Values outside this range are either ignored or counted 
        toward the edge bins, depending on the no_outliers property. Returns 
        None if no range constraint is set.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self._has_range:
            return (self._range_min, self._range_max)
        return None

    @range.setter
    def range(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._has_range = False
            return
        if PySequence_Check(value) == 0 or len(value) != 2:
            raise ValueError("Range must be None or (min,max) tuple")
        self._range_min = float(value[0])
        self._range_max = float(value[1])
        self._has_range = True

    @property
    def horizontal(self):
        """
        Whether to render the histogram with horizontal bars.
        
        When True, histogram bars extend horizontally from the Y-axis with
        bar lengths representing bin counts. When False (default), bars extend
        vertically from the X-axis. Horizontal orientation is useful for
        better visibility of labels when dealing with many narrow bins.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotHistogramFlags_Horizontal) != 0

    @horizontal.setter
    def horizontal(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotHistogramFlags_Horizontal
        if value:
            self._flags |= implot.ImPlotHistogramFlags_Horizontal

    @property
    def cumulative(self):
        """
        Whether to display the histogram as a cumulative distribution.
        
        When True, each bin displays a count that includes all previous bins, 
        creating a cumulative distribution function (CDF). When False (default),
        each bin shows only its own count. This is useful for visualizing 
        percentiles and distribution properties.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotHistogramFlags_Cumulative) != 0

    @cumulative.setter
    def cumulative(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotHistogramFlags_Cumulative
        if value:
            self._flags |= implot.ImPlotHistogramFlags_Cumulative

    @property
    def density(self):
        """
        Whether to normalize counts to form a probability density.
        
        When True, bin heights are scaled so that the total area of the 
        histogram equals 1, creating a probability density function (PDF).
        This allows comparison of distributions with different sample sizes
        and bin widths. When False (default), raw counts are displayed.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotHistogramFlags_Density) != 0

    @density.setter
    def density(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotHistogramFlags_Density
        if value:
            self._flags |= implot.ImPlotHistogramFlags_Density

    @property
    def no_outliers(self):
        """
        Whether to exclude values outside the specified range.
        
        When True and a range is specified, values outside the range will not 
        contribute to the counts or density. When False (default), outliers are 
        counted in the edge bins. This property has no effect if no range is 
        specified.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotHistogramFlags_NoOutliers) != 0

    @no_outliers.setter
    def no_outliers(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotHistogramFlags_NoOutliers
        if value:
            self._flags |= implot.ImPlotHistogramFlags_NoOutliers

    cdef void draw_element(self) noexcept nogil:
        self.check_arrays()
        cdef int32_t size = self._X.size()
        if size == 0:
            return

        # Set up range if specified
        cdef implot.ImPlotRange hist_range
        if self._has_range:
            hist_range.Min = self._range_min 
            hist_range.Max = self._range_max
        else:
            # (0, 0) means unspecified
            hist_range.Min = 0
            hist_range.Max = 0

        if self._X.type() == DCG_INT32:
            implot.PlotHistogram[int32_t](self._imgui_label.c_str(), 
                                     self._X.data[int32_t](),
                                     size,
                                     self._bins,
                                     self._bar_scale,
                                     hist_range,
                                     self._flags)
        elif self._X.type() == DCG_FLOAT:
            implot.PlotHistogram[float](self._imgui_label.c_str(),
                                       self._X.data[float](), 
                                       size,
                                       self._bins,
                                       self._bar_scale,
                                       hist_range,
                                       self._flags)
        elif self._X.type() == DCG_DOUBLE:
            implot.PlotHistogram[double](self._imgui_label.c_str(),
                                        self._X.data[double](),
                                        size,
                                        self._bins,
                                        self._bar_scale, 
                                        hist_range,
                                        self._flags)
        elif self._X.type() == DCG_UINT8:
            implot.PlotHistogram[uint8_t](self._imgui_label.c_str(),
                                       self._X.data[uint8_t](),
                                       size,
                                       self._bins,
                                       self._bar_scale,
                                       hist_range,
                                       self._flags)

cdef class PlotHistogram2D(plotElementXY):
    """
    Plots a 2D histogram as a heatmap from X,Y coordinate pairs.
    
    Creates a two-dimensional histogram where the frequency of data points 
    falling within each 2D bin is represented by color intensity. This is 
    useful for visualizing the joint distribution of two variables, density 
    estimation, and identifying clusters or patterns in bivariate data.
    Various binning methods are available for both X and Y dimensions.
    """
    def __cinit__(self):
        self._x_bins = -1  # Default to sqrt
        self._y_bins = -1  # Default to sqrt
        self._range_min_x = 0.0
        self._range_max_x = 0.0
        self._range_min_y = 0.0 
        self._range_max_y = 0.0
        self._has_range_x = False
        self._has_range_y = False

    @property
    def x_bins(self):
        """
        Number of X-axis bins or automatic binning method to use.
        
        Accepts positive integers for explicit bin count or negative values for 
        automatic binning methods:
        - -1: sqrt(n) bins [default]
        - -2: Sturges formula: k = log2(n) + 1
        - -3: Rice rule: k = 2 * cuberoot(n)
        - -4: Scott's rule: h = 3.49 sigma/cuberoot(n)
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._x_bins

    @x_bins.setter
    def x_bins(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value < -4:
            raise ValueError("Invalid x_bins value")
        self._x_bins = value

    @property
    def y_bins(self):
        """
        Number of Y-axis bins or automatic binning method to use.
        
        Accepts positive integers for explicit bin count or negative values for 
        automatic binning methods:
        - -1: sqrt(n) bins [default]
        - -2: Sturges formula: k = log2(n) + 1
        - -3: Rice rule: k = 2 * cuberoot(n)
        - -4: Scott's rule: h = 3.49 sigma/cuberoot(n)
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._y_bins

    @y_bins.setter
    def y_bins(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value < -4:
            raise ValueError("Invalid y_bins value")
        self._y_bins = value

    @property
    def range_x(self):
        """
        Optional (min, max) range for X-axis binning.
        
        When set, only X values within this range will be included in the
        histogram bins. X values outside this range are either ignored or 
        counted toward the edge bins, depending on the no_outliers property.
        Returns None if no range constraint is set.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self._has_range_x:
            return (self._range_min_x, self._range_max_x)
        return None

    @range_x.setter
    def range_x(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._has_range_x = False
            return
        if PySequence_Check(value) == 0 or len(value) != 2:
            raise ValueError("X range must be None or (min,max) tuple")
        self._range_min_x = float(value[0])
        self._range_max_x = float(value[1])
        self._has_range_x = True

    @property
    def range_y(self):
        """
        Optional (min, max) range for Y-axis binning.
        
        When set, only Y values within this range will be included in the
        histogram bins. Y values outside this range are either ignored or 
        counted toward the edge bins, depending on the no_outliers property.
        Returns None if no range constraint is set.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self._has_range_y:
            return (self._range_min_y, self._range_max_y)
        return None

    @range_y.setter 
    def range_y(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._has_range_y = False
            return
        if PySequence_Check(value) == 0 or len(value) != 2:
            raise ValueError("Y range must be None or (min,max) tuple")
        self._range_min_y = float(value[0])
        self._range_max_y = float(value[1])
        self._has_range_y = True

    @property
    def density(self):
        """
        Whether to normalize counts to form a probability density.
        
        When True, bin values are scaled so that the total volume of the 
        histogram equals 1, creating a probability density function (PDF).
        This allows comparison of distributions with different sample sizes
        and bin sizes. When False (default), raw counts are displayed.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotHistogramFlags_Density) != 0

    @density.setter
    def density(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotHistogramFlags_Density
        if value:
            self._flags |= implot.ImPlotHistogramFlags_Density

    @property
    def no_outliers(self):
        """
        Whether to exclude values outside the specified ranges.
        
        When True and range(s) are specified, data points with coordinates
        outside the range(s) will not contribute to the counts or density. When 
        False (default), outliers are counted in the edge bins. This property
        has no effect if no ranges are specified.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotHistogramFlags_NoOutliers) != 0

    @no_outliers.setter
    def no_outliers(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotHistogramFlags_NoOutliers
        if value:
            self._flags |= implot.ImPlotHistogramFlags_NoOutliers

    cdef void draw_element(self) noexcept nogil:
        self.check_arrays()
        cdef int32_t size = min(self._X.size(), self._Y.size())
        if size == 0:
            return

        # Set up ranges independently
        cdef implot.ImPlotRange hist_range_x, hist_range_y
        if self._has_range_x:
            hist_range_x.Min = self._range_min_x
            hist_range_x.Max = self._range_max_x
        else:
            # (0, 0) means unspecified
            hist_range_x.Min = 0
            hist_range_x.Max = 0
            
        if self._has_range_y:
            hist_range_y.Min = self._range_min_y
            hist_range_y.Max = self._range_max_y
        else:
            # (0, 0) means unspecified
            hist_range_y.Min = 0
            hist_range_y.Max = 0
            
        cdef implot.ImPlotRect hist_rect
        hist_rect.X = hist_range_x
        hist_rect.Y = hist_range_y

        if self._X.type() == DCG_INT32:
            implot.PlotHistogram2D[int32_t](self._imgui_label.c_str(),
                                        self._X.data[int32_t](),
                                        self._Y.data[int32_t](),
                                        size,
                                        self._x_bins,
                                        self._y_bins,
                                        hist_rect,
                                        self._flags)
        elif self._X.type() == DCG_FLOAT:
            implot.PlotHistogram2D[float](self._imgui_label.c_str(),
                                          self._X.data[float](),
                                          self._Y.data[float](),
                                          size,
                                          self._x_bins,
                                          self._y_bins,
                                          hist_rect,
                                          self._flags)
        elif self._X.type() == DCG_DOUBLE:
            implot.PlotHistogram2D[double](self._imgui_label.c_str(),
                                           self._X.data[double](),
                                           self._Y.data[double](),
                                           size,
                                           self._x_bins,
                                           self._y_bins,
                                           hist_rect,
                                           self._flags)
        elif self._X.type() == DCG_UINT8:
            implot.PlotHistogram2D[uint8_t](self._imgui_label.c_str(),
                                          self._X.data[uint8_t](),
                                          self._Y.data[uint8_t](),
                                          size,
                                          self._x_bins,
                                          self._y_bins,
                                          hist_rect,
                                          self._flags)

cdef class PlotHeatmap(plotElementWithLegend):
    """
    Plots a 2D grid of values as a color-mapped heatmap.
    
    Visualizes 2D data by assigning colors to values based on their magnitude.
    Each cell in the grid is colored according to a colormap that maps values 
    to colors. The heatmap can display patterns, correlations or distributions
    in 2D data such as matrices, images, or gridded measurements.
    
    The data is provided as a 2D array and can be interpreted in either row-major
    or column-major order. Optional value labels can be displayed on each cell,
    and the color scaling can be automatic or manually specified.
    """
    def __cinit__(self):
        #self._values = DCG2DContiguousArrayView()
        self._rows = 1
        self._cols = 1
        self._scale_min = 0
        self._scale_max = 0
        self._auto_scale = True
        self._label_format = string_from_bytes(b"%.1f")
        self._bounds_min = [0., 0.]
        self._bounds_max = [1., 1.]

    @property
    def values(self):
        """
        2D array of values to visualize in the heatmap.
        
        The array shape should be (rows, cols) for row-major order, or 
        (cols, rows) when col_major is True. The values determine the colors
        assigned to each cell based on the current colormap and scale settings.
        
        By default, compatible arrays are used directly without copying.
        Supported types for direct use are int32, float32, and float64.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return get_object_from_2D_array_view(self._values)

    @values.setter
    def values(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._values.reset()
            self._rows = self._cols = 0
            return
        self._values.reset(value)
        if self.col_major:
            self._cols = self._values.rows()
            self._rows = self._values.cols()
        else:
            self._rows = self._values.rows()
            self._cols = self._values.cols()

    @property
    def scale_min(self):
        """
        Minimum value for color mapping.
        
        Sets the lower bound of the color scale. Values at or below this level
        will be assigned the minimum color in the colormap. When both scale_min
        and scale_max are 0, automatic scaling is used based on the data's
        actual minimum and maximum values.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._scale_min

    @scale_min.setter
    def scale_min(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._scale_min = value
        self._auto_scale = (value == 0 and self._scale_max == 0)

    @property
    def scale_max(self):
        """
        Maximum value for color mapping.
        
        Sets the upper bound of the color scale. Values at or above this level
        will be assigned the maximum color in the colormap. When both scale_min
        and scale_max are 0, automatic scaling is used based on the data's
        actual minimum and maximum values.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._scale_max

    @scale_max.setter
    def scale_max(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._scale_max = value
        self._auto_scale = (value == 0 and self._scale_min == 0)

    @property
    def label_format(self):
        """
        Format string for displaying cell values.
        
        Controls how numeric values are formatted when displayed on each cell.
        Uses printf-style format specifiers like "%.2f" for 2 decimal places.
        Set to an empty string to disable value labels completely.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return string_to_str(self._label_format)

    @label_format.setter
    def label_format(self, str value not None):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._label_format = string_from_str(value)

    @property
    def bounds_min(self):
        """
        Bottom-left corner position of the heatmap in plot coordinates.
        
        Specifies the (x,y) coordinates of the lower-left corner of the heatmap
        within the plot area. Combined with bounds_max, this determines the
        size and position of the heatmap. Default is (0,0).
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._bounds_min[0], self._bounds_min[1])

    @bounds_min.setter
    def bounds_min(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if PySequence_Check(value) == 0 or len(value) != 2:
            raise ValueError("bounds_min must be a 2-tuple")
        self._bounds_min[0] = value[0]
        self._bounds_min[1] = value[1]

    @property
    def bounds_max(self):
        """
        Top-right corner position of the heatmap in plot coordinates.
        
        Specifies the (x,y) coordinates of the upper-right corner of the heatmap
        within the plot area. Combined with bounds_min, this determines the
        size and position of the heatmap. Default is (1,1).
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._bounds_max[0], self._bounds_max[1])

    @bounds_max.setter
    def bounds_max(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if PySequence_Check(value) == 0 or len(value) != 2:
            raise ValueError("bounds_max must be a 2-tuple")
        self._bounds_max[0] = value[0]
        self._bounds_max[1] = value[1]

    @property
    def col_major(self):
        """
        Whether values array is interpreted in column-major order.
        
        When True, the values array is interpreted as having dimensions 
        (columns, rows) rather than the default row-major order (rows, columns).
        Column-major is typical for some data formats like Fortran arrays or
        certain image processing libraries.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & implot.ImPlotHeatmapFlags_ColMajor) != 0

    @col_major.setter
    def col_major(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._flags &= ~implot.ImPlotHeatmapFlags_ColMajor
        if value:
            self._flags |= implot.ImPlotHeatmapFlags_ColMajor
            # Update dimensions if array exists
            self._cols = self._values.rows()
            self._rows = self._values.cols()
        else:
            self._rows = self._values.rows() 
            self._cols = self._values.cols()

    cdef void draw_element(self) noexcept nogil:
        if self._values.rows() == 0 or self._values.cols() == 0:
            return

        if self._values.type() == DCG_INT32:
            implot.PlotHeatmap[int32_t](self._imgui_label.c_str(),
                                    self._values.data[int32_t](),
                                    self._rows,
                                    self._cols,
                                    self._scale_min,
                                    self._scale_max,
                                    self._label_format.c_str(),
                                    implot.ImPlotPoint(self._bounds_min[0], self._bounds_min[1]),
                                    implot.ImPlotPoint(self._bounds_max[0], self._bounds_max[1]),
                                    self._flags)
        elif self._values.type() == DCG_FLOAT:
            implot.PlotHeatmap[float](self._imgui_label.c_str(),
                                      self._values.data[float](),
                                      self._rows,
                                      self._cols,
                                      self._scale_min,
                                      self._scale_max,
                                      self._label_format.c_str(),
                                      implot.ImPlotPoint(self._bounds_min[0], self._bounds_min[1]),
                                      implot.ImPlotPoint(self._bounds_max[0], self._bounds_max[1]),
                                      self._flags)
        elif self._values.type() == DCG_DOUBLE:
            implot.PlotHeatmap[double](self._imgui_label.c_str(),
                                       self._values.data[double](),
                                       self._rows,
                                       self._cols,
                                       self._scale_min,
                                       self._scale_max,
                                       self._label_format.c_str(),
                                       implot.ImPlotPoint(self._bounds_min[0], self._bounds_min[1]),
                                       implot.ImPlotPoint(self._bounds_max[0], self._bounds_max[1]),
                                       self._flags)
        elif self._values.type() == DCG_UINT8:
            implot.PlotHeatmap[uint8_t](self._imgui_label.c_str(),
                                      self._values.data[uint8_t](),
                                      self._rows,
                                      self._cols,
                                      self._scale_min,
                                      self._scale_max,
                                      self._label_format.c_str(),
                                      implot.ImPlotPoint(self._bounds_min[0], self._bounds_min[1]),
                                      implot.ImPlotPoint(self._bounds_max[0], self._bounds_max[1]),
                                      self._flags)
