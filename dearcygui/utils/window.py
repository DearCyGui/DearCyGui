from array import array
import dearcygui as dcg
import dearcygui.utils as utils
from collections import deque


class ScrollingBuffer:
    """A scrolling buffer with a large memory backing.

    Data is copied only when the memory backing is full.

    This class is not thread-safe.
    """

    __slots__ = {
        "_data": "Memory backing of the buffer",
        "_max_size": "Capacity of the memory backing",
        "_scrolling_size": "Number of most recent values exposed by get()",
        "_size": "Number of values currently stored in the backing",
    }

    _data: array
    _max_size: int
    _scrolling_size: int
    _size: int

    def __init__(self, *, scrolling_size: int = 2000, max_size: int = 1000000) -> None:
        """Allocate the memory backing of the buffer.

        Args:
            scrolling_size: Number of most recent values exposed by `get`.
            max_size: Capacity of the memory backing.

        Raises:
            ValueError: If *scrolling_size* is not positive or *max_size* is
                not greater than twice *scrolling_size*.
        """

        # Validate the sizes
        if scrolling_size <= 0 or max_size <= 2 * scrolling_size:
            raise ValueError(
                f"max_size ({max_size}) must be greater than twice scrolling_size "
                f"({scrolling_size}), which must be positive"
            )

        # Allocate the backing
        self._data = array("d", [0.0] * max_size)
        self._max_size = max_size
        self._scrolling_size = scrolling_size
        self._size = 0

    def get(self, requested_size: int | None = None) -> array:
        """Return the most recent values.

        Args:
            requested_size: Maximum number of values to return. Capped to
                the scrolling size. Defaults to the scrolling size.

        Returns:
            The most recent values, oldest first.
        """

        if requested_size is None:
            requested_size = self._scrolling_size
        else:
            requested_size = min(self._scrolling_size, requested_size)
        start = max(0, self._size - requested_size)
        return self._data[start : self._size]

    def push(self, value: float) -> None:
        """Append a value, discarding the oldest ones when the backing is full.

        Args:
            value: The value to append.
        """

        # Restart from the beginning when the end of the backing is reached
        if self._size >= self._max_size:
            self._data[: self._scrolling_size] = self._data[-self._scrolling_size :]
            self._size = self._scrolling_size

        # Store the value
        self._data[self._size] = value
        self._size += 1

_TEXT_HINTS = {
    "Low FPS": "In this region the application may appear to have stutter, not be smooth",
    "30+ FPS": "Application will appear smooth, but it's not ideal",
    "60+ FPS": "Application will appear smooth",
    "Frame": "Time measured between rendering this frame and the previous one",
    "Presentation": "Time taken by the GPU to process the data and OS throttling",
    "Rendering(other)": "Time taken to render all items except this window",
    "Rendering(this)": "Time taken to render this window",
    "Events": "Time taken to process keyboard/mouse events and preparing rendering",
    "X": "Time in seconds since the window was launched",
    "Y": "Measured time spent in ms"
}

class MetricsWindow(dcg.Window):
    __slots__ = {
        "_data": "dict mapping metric names to ScrollingBuffer instances",
        "_history": "Slider widget for history duration",
        "_history_bounds": "Array of len 2 storing the bounds of the history slider",
        "_main_plot": "Main plot widget for displaying metrics",
        "_metrics": "deque storing viewport metrics",
        "_plots": "dict mapping plot names to plot instances",
        "_secondary_plot": "Secondary plot widget for additional metrics",
        "_self_metrics": "deque storing self metrics",
        "_start_time": "Start time for metrics tracking",
        "_stat_text": "Text widget displaying application version and stats",
        "_times": "ScrollingBuffer instance for time tracking"
    }
    _data: dict[str, ScrollingBuffer]
    _history: dcg.Slider
    _history_bounds: array
    _main_plot: dcg.Plot
    _metrics: deque[dcg.ViewportMetrics]
    _plots: dict[str, dcg.PlotLine]
    _secondary_plot: dcg.Plot
    _self_metrics: deque[tuple[int, float]]
    _start_time: float
    _stat_text: dcg.Text
    _times: ScrollingBuffer

    def __init__(self, context : dcg.Context, width=0, height=0, *args, **kwargs):
        super().__init__(context, width=width, height=height, *args, **kwargs)
        # At this step the window is created

        # Create the data reserve
        self._data = {
            "Frame": ScrollingBuffer(),
            "Events": ScrollingBuffer(),
            "Rendering(other)": ScrollingBuffer(),
            "Rendering(this)": ScrollingBuffer(),
            "Presentation": ScrollingBuffer()
        }
        self._times = ScrollingBuffer()
        self._self_metrics = deque(maxlen=10)
        self._metrics = deque(maxlen=10)
        self._plots = {}

        # Initialize metrics tracking variables
        self._start_time = self.context.viewport.metrics.last_time_before_rendering

        # Initialize the UI with a 4 line text fields, a slider history and a main plot
        with self:
            self._stat_text = dcg.Text(context, value=f"DearCyGui Version: {dcg.__version__}\n\n\n\n")
            self._history = dcg.Slider(
                context,
                value=10.,
                min_value=1.,
                max_value=30.,
                label="History",
                print_format="%.1f s"
            )
            self._main_plot = dcg.Plot(context, height=200)
            self._main_plot.Y1.auto_fit = True
            self._main_plot.Y1.restrict_fit_to_range = True

        # In the main plot (rolling history for fps for frame/presentation),
        # attach fps threshold regions 
        with self._main_plot:
            self._history_bounds = array('d', [0.0, 0.0])
            self._history_bounds[0] = 0
            self._history_bounds[1] = 10.
            dcg.PlotShadedLine(
                context,
                label='60+ FPS',
                X=self._history_bounds,
                Y1=[0., 0.],
                Y2=[16., 16.],
                theme=dcg.ThemeColorImPlot(context, fill=(0., 1., 0., 0.1)),
                ignore_fit=True
            )
            dcg.PlotShadedLine(
                context,
                label='30+ FPS',
                X=self._history_bounds,
                Y1=[16., 16.],
                Y2=[32., 32.],
                theme=dcg.ThemeColorImPlot(context, fill=(1., 1., 0., 0.1)),
                ignore_fit=True
            )
            dcg.PlotShadedLine(
                context,
                label='Low FPS',
                X=self._history_bounds,
                Y1=[32., 32.],
                Y2=[64., 64.],
                theme=dcg.ThemeColorImPlot(context, fill=(1., 0., 0., 0.1)),
                ignore_fit=True
            )

            # Add individual plot lines for "Frame" and "Presentation" metrics
            for key in ["Frame", "Presentation"]:
                self._plots[key] = dcg.PlotLine(
                    context,
                    label=key
                )

        # Attach below the main plot a secondary plot for other metrics
        with self:
            self._secondary_plot = dcg.Plot(
                context,
                theme=dcg.ThemeColorImPlot(context, plot_border=0)
            )
            self._secondary_plot.Y1.auto_fit = True
            self._secondary_plot.Y1.restrict_fit_to_range = True
        with self._secondary_plot:
            for key in self._data.keys():
                if key in ["Frame", "Presentation"]:
                    continue
                self._plots[key] = dcg.PlotLine(
                    context,
                    label=key
                )

        # Add Legend tooltips to both plots
        for plot_element in self._main_plot.children + self._secondary_plot.children:
            key = plot_element.label
            if key in _TEXT_HINTS.keys():
                with dcg.Tooltip(context, target=plot_element, parent=self):
                    dcg.Text(context, value=_TEXT_HINTS[key])

        # Add axis tooltips
        with dcg.Tooltip(context, target=self._main_plot.X1, parent=self):
            dcg.Text(context, value=_TEXT_HINTS["X"])
        with dcg.Tooltip(context, target=self._main_plot.Y1, parent=self):
            dcg.Text(context, value=_TEXT_HINTS["Y"])
        with dcg.Tooltip(context, target=self._secondary_plot.X1, parent=self):
            dcg.Text(context, value=_TEXT_HINTS["X"])
        with dcg.Tooltip(context, target=self._secondary_plot.Y1, parent=self):
            dcg.Text(context, value=_TEXT_HINTS["Y"])
        
        # Wrap all UI inside the MetricsWindow (except the menubar)
        # Inside a TimeWatch instance to measure the time
        # spent rendering this item's children. We do
        # not measure the window itself, but it should
        # be small.
        children = list(self.children)
        tw = dcg.TimeWatcher(context, parent=self, callback=self._log_times)
        # Move the ui children to TimeWatcher, except the menubar
        for child in children:
            try:
                assert not isinstance(child, dcg.MenuBar)
                child.parent = tw
            except TypeError:
                pass

    def _log_times(self, watcher, target, watcher_data: dcg.TimeWatcherCallbackValue) -> None:
        """Record timing data from a time watcher.
        
        This method processes the timing information collected by the time watcher
        and stores it for later use in metrics calculations. It triggers metrics
        logging and plot updates based on the received data.
        """
        # Measure the time to render the window UI
        delta =  watcher_data.time_end - watcher_data.time_start

        # Record the metrics
        self._self_metrics.append((
            watcher_data.viewport_frame_count,
            delta * 1e-9 # convert nanoseconds to seconds
        ))

        # Retrieve viewport metrics and log them
        # NOTE: retrieving metrics will lock the viewport and thus block
        # during parts of rendering.
        self._metrics.append(self.context.viewport.metrics)

        # Update the plots with the latest metrics data
        self._update_plot(watcher_data.viewport_frame_count)

    def _update_plot(self, frame_count: int) -> None:
        """Update visualization plots with the latest metrics data.
        
        This method processes collected metrics data, updates the various 
        performance graphs, and refreshes status text elements. It synchronizes
        metric data from different sources to ensure consistency, and applies
        appropriate visual cues based on performance levels.
        """
        treated_metrics = []
        treated_self_metrics = []

        # Treat frames where we have received both infos
        for rendering_metrics in self._metrics:

            # Iterate over self metrics to find a matching frame count
            # Note the length of self metrics is <= 10
            for self_metric in self._self_metrics:
                (frame_count, metrics_window_rendering_time) = self_metric
                if frame_count == rendering_metrics.frame_count:
                    break

            # Skip this rendering_metrics if no matching self_metric is found
            else:
                continue

            # At this point, we have a matching self_metric for the current rendering_metrics
            # Append the matched metrics to the treated lists for later removal
            treated_metrics.append(rendering_metrics)
            treated_self_metrics.append(self_metric)

            # Push the relevant metrics to the corresponding data deques
            # TODO: this means we may in theory push in a different
            # order than the presentation order...
            self._data["Frame"].push(1e3 * rendering_metrics.delta_whole_frame)
            self._data["Events"].push(1e3 * rendering_metrics.delta_event_handling)
            self._data["Rendering(other)"].push(1e3 * (rendering_metrics.delta_rendering - metrics_window_rendering_time))
            self._data["Rendering(this)"].push(1e3 * metrics_window_rendering_time)
            self._data["Presentation"].push(1e3 * rendering_metrics.delta_presenting)

        # Skip updating if there is no new data to process
        if not treated_metrics:
            return

        # Remove treated data
        for rendering_metrics in treated_metrics:
            try:
                self._metrics.remove(rendering_metrics)
            except ValueError:
                # Removed by deque length limit
                pass
        for self_metric in treated_self_metrics:
            try:
                self._self_metrics.remove(self_metric)
            except ValueError:
                # Removed by deque length limit
                pass

        # Retrieve the viewport metrics
        rendering_metrics = self.context.viewport.metrics
        rendered_vertices = rendering_metrics.rendered_vertices
        rendered_indices = rendering_metrics.rendered_indices
        rendered_windows = rendering_metrics.rendered_windows
        active_windows = rendering_metrics.active_windows
        current_time = rendering_metrics.last_time_before_rendering

        # Push the current time to the times deque
        self._times.push(current_time - self._start_time)

        # Compute the average frame time and FPS over the last 60 frames
        time_average = sum(self._data["Frame"].get()[-60:]) / 60
        fps_average = 1e3 / (max(1e-20, time_average))

        # Define the themes for the three framerate regions
        low_framerate_theme = dcg.ThemeColorImPlot(
            self.context,
            frame_bg=(1., 0., 0., 0.3),
            plot_bg=(0., 0., 0., 1.),
            plot_border=(0., 0., 0., 0.)
        )
        medium_framerate_theme = dcg.ThemeColorImPlot(
            self.context,
            frame_bg=(1., 1., 0., 0.3),
            plot_bg=(0., 0., 0., 1.),
            plot_border=(0., 0., 0., 0.)
        )
        high_framerate_theme = dcg.ThemeColorImPlot(
            self.context,
            frame_bg=(0., 0., 0., 0.),
            plot_bg=(0., 0., 0., 1.),
            plot_border=(0., 0., 0., 0.)
        )

        # Select the theme based on the average FPS
        if fps_average < 29:
            self._main_plot.theme = low_framerate_theme
        elif fps_average < 59:
            self._main_plot.theme = medium_framerate_theme
        else:
            self._main_plot.theme = high_framerate_theme

        # Update the text fields with the current metrics
        self._stat_text.value = \
           f"DearCyGui Version: {dcg.__version__}\n" \
           f"Application average {time_average:.3f} ms/frame ({fps_average:.1f} FPS)\n" \
           f"{rendered_vertices} vertices, {rendered_indices} indices ({rendered_indices//3} triangles)\n" \
           f"{active_windows} active windows ({rendered_windows} visible)"

        # Update the history bounds and plot ranges based on the current time
        DT1 = current_time - self._start_time
        DT0 = current_time - self._start_time - self._history.value
        self._history_bounds[1] = DT1
        self._history_bounds[0] = DT0
        self._main_plot.X1.min = DT0
        self._main_plot.X1.max = DT1
        self._secondary_plot.X1.min = DT0
        self._secondary_plot.X1.max = DT1

        # This is actually no copy
        for key in self._plots.keys():
            self._plots[key].X = self._times.get()
            self._plots[key].Y = self._data[key].get()

        # Mark that the plot content has updated and in case of viewport
        # refreshes, GPU submission should be done
        # Also ensure we update once every 10 seconds
        self.context.viewport.wake(delay=10, full_refresh=True)

def _get_children_recursive(item: dcg.baseItem) -> list[dcg.baseItem]:
    """Recursively collect all children of an item.
    
    This function traverses the item hierarchy and returns a flat list containing
    the given item and all of its descendants.
    """
    result = [item]
    children = item.children
    for c in children:
        result += _get_children_recursive(c)
    return result

class ItemInspecter(dcg.Window):
    """Inspector window for examining and interacting with items.

    This window allows users to hover over items to inspect them and
    provides functionality to drag items while holding the Alt key.
    """
    __slots__ = {
        "_dragging_item": "Currently dragged item",
        "_dragging_item_original_state": "Original state of the dragged item",
        "_inspected_items": "List of currently inspected items",
        "_item_handler": "Handler list for managing item events"
    }

    _dragging_item: dcg.baseItem | None
    _dragging_item_original_state: dcg.ItemStateCopy | None
    _inspected_items: list[dcg.baseItem]
    _item_handler: dcg.HandlerList

    def __init__(self, context : dcg.Context, autosize=True, *args, **kwargs):
        super().__init__(context, autosize=autosize, *args, **kwargs)
        # Initialize dragging state and item handler
        self._dragging_item = None
        self._dragging_item_original_state = None
        self._inspected_items = []
        self._item_handler = dcg.HandlerList(context)

        # Create the main layout for the inspector window
        with self:
            with dcg.HorizontalLayout(context, alignment_mode=dcg.Alignment.LEFT, no_wrap=True):
                dcg.Button(context, label="Install handlers", callback=self.setup_handlers)
                dcg.Button(context, label="Remove handlers", callback=self.remove_handlers)
            with dcg.HorizontalLayout(context, alignment_mode=dcg.Alignment.CENTER):
                with dcg.VerticalLayout(context):
                    dcg.Text(context, wrap=0).value = \
                    "Help: Hover an item to inspect it. Alt+right click to move it."

        # Create the item handler for managing inspection events
        with self._item_handler:
            dcg.GotHoverHandler(context, callback=self.handle_item_hovered)
            # If an item is hovered and the Alt key is pressed,
            # handle dragging an item.
            with dcg.ConditionalHandler(context):
                dcg.DraggingHandler(context, button=dcg.MouseButton.RIGHT, callback=self.handle_item_dragging)
                dcg.KeyDownHandler(context, key=dcg.Key.LEFTALT)
            dcg.DraggedHandler(context, button=dcg.MouseButton.RIGHT, callback=self.handle_item_dragged)
            # If a compatible item is hovered and the ALT key is set,
            # change the cursor to show we can drag
            with dcg.ConditionalHandler(context):
                dcg.MouseCursorHandler(context, cursor=dcg.MouseCursor.HAND)
                dcg.HoverHandler(context)
                dcg.KeyDownHandler(context, key=dcg.Key.LEFTALT)

    def setup_handlers(self) -> None:
        """Install inspection handlers on all UI elements.
        
        This method installs event handlers on all UI elements in the viewport,
        enabling them to be inspected and manipulated through the inspector
        interface. It cleans up any previously installed handlers first.
        """
        # Uninstall previous handlers first
        if len(self._inspected_items) > 0:
            self.remove_handlers()

        # Get all children of the viewport recursively
        children_list = _get_children_recursive(self.context.viewport)

        # Add the retrieved children to the list of inspected items
        self._inspected_items += children_list
        for c in children_list:
            try:
                with c.mutex:
                    c.handlers += [self._item_handler] # type: ignore
            except Exception:
                # Pass incompatible items
                pass

    def remove_handlers(self) -> None:
        """Remove all inspection handlers from UI elements.
        
        This method removes the previously installed inspection handlers from
        all tracked UI elements, effectively disabling the inspection 
        functionality.
        """
        for item in self._inspected_items:
            try:
                with item.mutex:
                    handlers = item.handlers # type: ignore
                    handlers = [h for h in handlers if h is not self._item_handler]
                    item.handlers = handlers # type: ignore
            except AttributeError:
                pass
        self._inspected_items = []

    def handle_item_dragging(self, handler, item: dcg.uiItem, data: dcg.DraggingHandlerCallbackValue) -> None:
        """Process UI element dragging events.
        
        This method handles the dragging of UI elements, updating their position
        relative to their parent based on the mouse movement. It tracks the
        currently dragged item and maintains its original position for reference.
        """
        # Just to be safe. Might not be needed
        if item is not self._dragging_item and self._dragging_item is not None:
            return

        # If we were not dragging, start dragging the current item
        if self._dragging_item is None:
            self._dragging_item = item
            self._dragging_item_original_state = item.state.snapshot()

        # Calculate the new position based on the original position and drag delta
        assert self._dragging_item_original_state is not None
        new_pos = self._dragging_item_original_state.pos_to_viewport + data.drag_delta

        # Display the item at the new position
        item.x = dcg.Size.FIXED(new_pos.x)
        item.y = dcg.Size.FIXED(new_pos.y)

    def handle_item_dragged(self, handler, item: dcg.uiItem) -> None:
        """Handle the completion of a UI element drag operation.
        
        This method is called when a drag operation ends, cleaning up the 
        dragging state and preparing for potential future drag operations.
        """
        # For safety
        if self._dragging_item is None or item is not self._dragging_item:
            return

        # Place the item relative to its parent without changing its current position
        assert self._dragging_item_original_state is not None
        item.x = dcg.Size.PARENT_X1() + dcg.Size.FIXED(item.state.pos_to_parent.x)
        item.y = dcg.Size.PARENT_Y1() + dcg.Size.FIXED(item.state.pos_to_parent.y)

        # Reset dragging state
        self._dragging_item = None
        self._dragging_item_original_state = None

    def handle_item_hovered(self, handler, item):
        """Display detailed information about a hovered UI element.
        
        This method creates a tooltip showing properties of the hovered UI
        element. It compares the element's current state with default values
        to highlight customized properties, and presents this information in
        an organized two-column layout.
        """
        # Retrieve all visible states of the item for inspection
        item_states = dir(item)
        C = self.context

        # Create a default instance of the item for comparison
        try:
            default_item = item.__class__(C, attach=False)
        except:
            default_item = None

        # Ignore some specific states that are not relevant for display
        ignore_list = [
            "shareable_value",
        ]

        # Create a tooltip for the hovered item
        # Attach the tooltip to our window.
        # This is to not perturb the item states
        # and child tree.
        with utils.TemporaryTooltip(C, target=item, parent=self):
            dcg.Text(C).value = f"{item}:"
            dcg.Spacer(C, width="theme.indent_spacing.x - theme.item_spacing.x", no_newline=True)

            # On the left side display the names
            left = dcg.VerticalLayout(C,
                theme=dcg.ThemeStyleImGui(C, item_spacing=(40., -3.)),
                no_newline=True
            )

            # On the right side display the corresponding values
            right = dcg.VerticalLayout(C, theme=left.theme)

            # Display each state and its value, ignoring defaults and irrelevant states
            for state in item_states:
                if state[0] == "_":
                    continue
                try:
                    value = getattr(item, state)
                    if hasattr(value, '__code__'):
                        # ignore methods
                        continue
                    if state == "handlers":
                        # remove ourselves
                        value = [v for v in value if v is not self._item_handler]
                    try:
                        if value == getattr(default_item, state):
                            # ignore non defaults
                            continue
                    except Exception: # Not all states can be compared
                        pass
                    if state in ignore_list:
                        continue
                except AttributeError:
                    # Some states are advertised, but not
                    # available
                    continue
                with left:
                    dcg.Text(C, value=f"{state}:")
                with right:
                    dcg.Text(C, value=str(value))

def _is_style_element(class_obj: type[dcg.baseTheme], name: str) -> bool:
    """Return whether *name* identifies a valid theme element."""
    try:
        class_obj.get_default(name)
        return True
    except KeyError:
        return False


class StyleEditor(dcg.Window):
    """Provide controls for editing, previewing, and exporting application themes.

    The editor exposes controls for ImGui and ImPlot colors and styles. Changes
    are composed in ``main_theme`` and can be applied, canceled, reset, or exported.
    """

    __slots__ = {
        "_current_theme": "Theme active when the editor was created",
        "_export_button": "Button used to export the current theme",
        "_filter_defaults": "Checkbox controlling default-value filtering",
        "_imgui_color_theme": "ImGui color theme being edited",
        "_imgui_style_theme": "ImGui style theme being edited",
        "_implot_color_theme": "ImPlot color theme being edited",
        "_implot_style_theme": "ImPlot style theme being edited",
        "_main_theme": "Theme list containing all edited themes",
    }

    _current_theme: dcg.baseTheme | None
    _export_button: dcg.Button
    _filter_defaults: dcg.Checkbox
    _imgui_color_theme: dcg.ThemeColorImGui
    _imgui_style_theme: dcg.ThemeStyleImGui
    _implot_color_theme: dcg.ThemeColorImPlot
    _implot_style_theme: dcg.ThemeStyleImPlot
    _main_theme: dcg.ThemeList

    def __init__(self, context: dcg.Context, **kwargs) -> None:
        """Create a theme editor for *context*.

        Args:
            context: Context that owns the editor and its widgets.
            **kwargs: Additional window configuration.
        """
        super().__init__(context, **kwargs)

        # Create theme state
        self._current_theme = context.viewport.theme
        self._main_theme = dcg.ThemeList(self.context)
        self._imgui_color_theme = dcg.ThemeColorImGui(self.context, parent=self._main_theme)
        self._imgui_style_theme = dcg.ThemeStyleImGui(self.context, parent=self._main_theme)
        self._implot_color_theme = dcg.ThemeColorImPlot(self.context, parent=self._main_theme)
        self._implot_style_theme = dcg.ThemeStyleImPlot(self.context, parent=self._main_theme)

        # Create editor controls
        with dcg.HorizontalLayout(context, parent=self, alignment_mode=dcg.Alignment.CENTER):
            dcg.Button(context, label="Reset", callback=self.reset_values)
            dcg.Button(
                context,
                label="Apply",
                callback=lambda: context.viewport.configure(theme=self._main_theme),
            )
            dcg.Button(
                context,
                label="Cancel",
                callback=lambda: context.viewport.configure(theme=self._current_theme),
            )
            self._export_button = dcg.Button(
                context,
                label="Export",
                callback=self.export_to_clipboard,
            )
            with dcg.Tooltip(context):
                dcg.Text(context, value="Export the current theme to the clipboard")
            self._filter_defaults = dcg.Checkbox(context, label="Filter defaults", value=True)
            with dcg.Tooltip(context):
                dcg.Text(context, value="Include only non-default values in the export")
                dcg.Text(
                    context,
                    value="Generates shorter code, but may be affected if defaults change",
                )
            dcg.Button(context, label="Help", callback=self.launch_help_window)

        # Create color and style controls
        with dcg.TabBar(context, label="Style Editor", parent=self):
            with dcg.Tab(context, label="Colors"):
                with dcg.TabBar(context, label="Category"):
                    with dcg.Tab(context, label="ImGui"):
                        imgui_color_names = [
                            name
                            for name in dir(self._imgui_color_theme)
                            if _is_style_element(dcg.ThemeColorImGui, name)
                        ]
                        for color_name in imgui_color_names:
                            default_color = self._imgui_color_theme.get_default(color_name)

                            def callback_imgui_color(
                                source: dcg.baseItem,
                                target: dcg.baseItem,
                                data: dcg.uiItemCallbackValue,
                                color_name: str = color_name,
                            ) -> None:
                                setattr(self._imgui_color_theme, color_name, data.value)

                            dcg.ColorEdit(
                                context,
                                label=color_name,
                                value=default_color,
                                user_data=default_color,
                                callback=callback_imgui_color,
                            )
                    with dcg.Tab(context, label="ImPlot"):
                        implot_color_names = [
                            name
                            for name in dir(self._implot_color_theme)
                            if _is_style_element(dcg.ThemeColorImPlot, name)
                        ]
                        for color_name in implot_color_names:
                            default_color = self._implot_color_theme.get_default(color_name)

                            def callback_implot_color(
                                source: dcg.baseItem,
                                target: dcg.baseItem,
                                data: dcg.uiItemCallbackValue,
                                color_name: str = color_name,
                            ) -> None:
                                setattr(self._implot_color_theme, color_name, data.value)

                            dcg.ColorEdit(
                                context,
                                label=color_name,
                                value=default_color,
                                user_data=default_color,
                                callback=callback_implot_color,
                            )
            with dcg.Tab(context, label="Styles"):
                with dcg.TabBar(context, label="Category"):
                    with dcg.Tab(context, label="ImGui"):
                        imgui_style_names = [
                            name
                            for name in dir(self._imgui_style_theme)
                            if _is_style_element(dcg.ThemeStyleImGui, name)
                        ]
                        for style_name in imgui_style_names:
                            default_style = self._imgui_style_theme.get_default(style_name)
                            item_type = type(default_style)
                            if item_type is tuple:
                                item_type = type(default_style[0])
                            if item_type is float:
                                print_format = "%.2f"
                            elif item_type is int:
                                print_format = "%.0f"
                            else:
                                continue

                            def callback_imgui_style(
                                source: dcg.baseItem,
                                target: dcg.baseItem,
                                data: dcg.uiItemCallbackValue,
                                style_name: str = style_name,
                            ) -> None:
                                value = data.value
                                if isinstance(value, list) and len(value) == 1:
                                    value = value[0]
                                setattr(self._imgui_style_theme, style_name, value)

                            with dcg.HorizontalLayout(context, no_wrap=True):
                                utils.SliderN(
                                    context,
                                    print_format=print_format,
                                    label="",
                                    logarithmic=True,
                                    value=default_style,
                                    user_data=default_style,
                                    callback=callback_imgui_style,
                                )
                                dcg.Text(context, value=style_name)
                    with dcg.Tab(context, label="ImPlot"):
                        implot_style_names = [
                            name
                            for name in dir(self._implot_style_theme)
                            if _is_style_element(dcg.ThemeStyleImPlot, name)
                        ]
                        for style_name in implot_style_names:
                            default_style = self._implot_style_theme.get_default(style_name)
                            item_type = type(default_style)
                            if item_type is tuple:
                                item_type = type(default_style[0])
                            if item_type is float:
                                print_format = "%.2f"
                            elif item_type is int:
                                print_format = "%.0f"
                            elif item_type is dcg.PlotMarker:
                                def callback_implot_style_marker(
                                    source: dcg.baseItem,
                                    target: dcg.baseItem,
                                    data: dcg.uiItemCallbackValue,
                                    style_name: str = style_name,
                                ) -> None:
                                    setattr(
                                        self._implot_style_theme,
                                        style_name,
                                        dcg.PlotMarker[data.value],
                                    )

                                dcg.Combo(
                                    context,
                                    label=style_name,
                                    items=[
                                        name
                                        for name in dir(dcg.PlotMarker)
                                        if name[0].isupper()
                                    ],
                                    value=default_style.name,
                                    user_data=default_style,
                                    callback=callback_implot_style_marker,
                                )
                                continue
                            else:
                                continue

                            def callback_implot_style(
                                source: dcg.baseItem,
                                target: dcg.baseItem,
                                data: dcg.uiItemCallbackValue,
                                style_name: str = style_name,
                            ) -> None:
                                value = data.value
                                if isinstance(value, list) and len(value) == 1:
                                    value = value[0]
                                setattr(self._implot_style_theme, style_name, value)

                            with dcg.HorizontalLayout(context, no_wrap=True):
                                utils.SliderN(
                                    context,
                                    print_format=print_format,
                                    logarithmic=True,
                                    label="",
                                    value=default_style,
                                    user_data=default_style,
                                    callback=callback_implot_style,
                                )
                                dcg.Text(context, value=style_name)

    def _recursive_reset_values(self, item: dcg.baseItem) -> None:
        """Reset each descendant control to its stored default value."""
        for child in item.children:
            self._recursive_reset_values(child)
            if getattr(child, "user_data", None) is not None:
                if isinstance(child, dcg.ColorEdit):
                    child.value = child.user_data
                if isinstance(child, utils.SliderN):
                    child.value = child.user_data
                if isinstance(child, dcg.Combo):
                    child.value = child.user_data.name

    def reset_values(self) -> None:
        """Reset all theme values and controls to their defaults."""
        self._recursive_reset_values(self)

        # Clear theme overrides that can otherwise mask default values
        for key, _ in self._imgui_color_theme:
            setattr(self._imgui_color_theme, key, None)
        for key, _ in self._implot_color_theme:
            setattr(self._implot_color_theme, key, None)
        for key, _ in self._imgui_style_theme:
            setattr(self._imgui_style_theme, key, None)
        for key, _ in self._implot_style_theme:
            setattr(self._implot_style_theme, key, None)

    def export_to_text(self) -> str:
        """Return Python code that recreates the current theme."""
        non_default_imgui_colors: dict[str, object] = {}
        non_default_imgui_styles: dict[str, object] = {}
        non_default_implot_colors: dict[str, object] = {}
        non_default_implot_styles: dict[str, object] = {}
        should_filter = self._filter_defaults.value

        # Collect changed values or all values, depending on the filter setting
        if should_filter:
            for name, value in self._imgui_color_theme:
                if value != self._imgui_color_theme.get_default(name):
                    non_default_imgui_colors[name] = dcg.color_as_floats(value)
            for name, value in self._imgui_style_theme or ():
                if value != self._imgui_style_theme.get_default(name):
                    non_default_imgui_styles[name] = value
            for name, value in self._implot_color_theme:
                if value != self._implot_color_theme.get_default(name):
                    non_default_implot_colors[name] = dcg.color_as_floats(value)
            for name, value in self._implot_style_theme:
                if value != self._implot_style_theme.get_default(name):
                    non_default_implot_styles[name] = value
        else:
            imgui_color_names = [
                name for name in dir(self._imgui_color_theme) if name[0].isupper()
            ]
            for name in imgui_color_names:
                value = getattr(self._imgui_color_theme, name, None)
                if value is None:
                    value = self._imgui_color_theme.get_default(name)
                non_default_imgui_colors[name] = dcg.color_as_floats(value)
            imgui_style_names = [
                name for name in dir(self._imgui_style_theme) if name[0].isupper()
            ]
            for name in imgui_style_names:
                value = getattr(self._imgui_style_theme, name, None)
                if value is None:
                    value = self._imgui_style_theme.get_default(name)
                non_default_imgui_styles[name] = value
            implot_color_names = [
                name for name in dir(self._implot_color_theme) if name[0].isupper()
            ]
            for name in implot_color_names:
                value = getattr(self._implot_color_theme, name, None)
                if value is None:
                    value = self._implot_color_theme.get_default(name)
                non_default_implot_colors[name] = dcg.color_as_floats(value)
            implot_style_names = [
                name for name in dir(self._implot_style_theme) if name[0].isupper()
            ]
            for name in implot_style_names:
                value = getattr(self._implot_style_theme, name, None)
                if value is None:
                    value = self._implot_style_theme.get_default(name)
                non_default_implot_styles[name] = value

        # Format theme constructors
        imgui_color_str = ""
        if non_default_imgui_colors:
            string_setters = [
                f"{name}={value}" for name, value in non_default_imgui_colors.items()
            ]
            imgui_color_str = (
                "    dcg.ThemeColorImGui(context,\n        "
                + ",\n        ".join(string_setters)
                + ")"
            )
        imgui_style_str = ""
        if non_default_imgui_styles:
            string_setters = [
                f"{name}={value}" for name, value in non_default_imgui_styles.items()
            ]
            imgui_style_str = (
                "    dcg.ThemeStyleImGui(context,\n        "
                + ",\n        ".join(string_setters)
                + ")"
            )
        implot_color_str = ""
        if non_default_implot_colors:
            string_setters = [
                f"{name}={value}" for name, value in non_default_implot_colors.items()
            ]
            implot_color_str = (
                "    dcg.ThemeColorImPlot(context,\n        "
                + ",\n        ".join(string_setters)
                + ")"
            )
        implot_style_str = ""
        if non_default_implot_styles:
            string_setters = [
                f"{name}={value}" for name, value in non_default_implot_styles.items()
            ]
            implot_style_str = (
                "    dcg.ThemeStyleImPlot(context,\n        "
                + ",\n        ".join(string_setters)
                + ")"
            )

        # Return the empty or single-theme result directly
        active_theme_count = sum(
            bool(values)
            for values in (
                non_default_imgui_colors,
                non_default_imgui_styles,
                non_default_implot_colors,
                non_default_implot_styles,
            )
        )
        if active_theme_count == 0:
            return "theme = None"

        theme_strings = (
            imgui_color_str,
            imgui_style_str,
            implot_color_str,
            implot_style_str,
        )
        if active_theme_count == 1:
            return "theme = \\\n" + "".join(theme_strings)

        # Combine multiple theme constructors into a theme list
        full_text = ""
        if non_default_imgui_colors:
            full_text += f"theme_imgui_color = \\\n{imgui_color_str}\n"
        if non_default_imgui_styles:
            full_text += f"theme_imgui_style = \\\n{imgui_style_str}\n"
        if non_default_implot_colors:
            full_text += f"theme_implot_color = \\\n{implot_color_str}\n"
        if non_default_implot_styles:
            full_text += f"theme_implot_style = \\\n{implot_style_str}\n"

        full_text += "theme = dcg.ThemeList(context)\ntheme.children = [\n"
        if non_default_imgui_colors:
            full_text += "    theme_imgui_color,\n"
        if non_default_imgui_styles:
            full_text += "    theme_imgui_style,\n"
        if non_default_implot_colors:
            full_text += "    theme_implot_color,\n"
        if non_default_implot_styles:
            full_text += "    theme_implot_style,\n"
        full_text += "]\n"
        return full_text

    def export_to_clipboard(self) -> None:
        """Copy the current theme as Python code to the clipboard."""
        self.context.clipboard = self.export_to_text()
        with dcg.utils.TemporaryTooltip(self.context, target=self._export_button, parent=self):
            dcg.Text(self.context, value="Theme copied to clipboard")

    def launch_help_window(self) -> None:
        """Open a modal help window with a live theme preview."""
        context = self.context
        with dcg.Window(context, label="Theme Editor Help", autosize=True, modal=True):
            dcg.Text(
                context,
                value="Theme colors and styles allow customizing the appearance of UI elements.",
            )
            dcg.Separator(context)

            # Create a demo button with its own theme
            demo_theme = dcg.ThemeList(context)
            demo_colors = dcg.ThemeColorImGui(context, parent=demo_theme)
            demo_styles = dcg.ThemeStyleImGui(context, parent=demo_theme)

            # Create controls for the most relevant button properties
            with dcg.HorizontalLayout(context):
                with dcg.VerticalLayout(context):
                    dcg.Text(context, value="Colors:")
                    dcg.ColorEdit(
                        context,
                        label="Button Color",
                        value=demo_colors.get_default("button"),
                        callback=lambda source, target, data: setattr(
                            demo_colors, "button", data.value
                        ),
                    )
                    dcg.ColorEdit(
                        context,
                        label="Button Hovered",
                        value=demo_colors.get_default("button_hovered"),
                        callback=lambda source, target, data: setattr(
                            demo_colors, "button_hovered", data.value
                        ),
                    )
                    dcg.ColorEdit(
                        context,
                        label="Button Active",
                        value=demo_colors.get_default("button_active"),
                        callback=lambda source, target, data: setattr(
                            demo_colors, "button_active", data.value
                        ),
                    )
                    dcg.ColorEdit(
                        context,
                        label="Text",
                        value=demo_colors.get_default("text"),
                        callback=lambda source, target, data: setattr(
                            demo_colors, "text", data.value
                        ),
                    )

                with dcg.VerticalLayout(context):
                    dcg.Text(context, value="Styles:")
                    with dcg.HorizontalLayout(context, no_wrap=True):
                        utils.SliderN(
                            context,
                            value=demo_styles.get_default("frame_padding"),
                            callback=lambda source, target, data: setattr(
                                demo_styles, "frame_padding", data.value[:2]
                            ),
                        )
                        dcg.Text(context, value="Frame Padding")
                    dcg.Slider(
                        context,
                        label="Frame Rounding",
                        value=demo_styles.get_default("frame_rounding"),
                        min_value=0,
                        max_value=12,
                        callback=lambda source, target, data: setattr(
                            demo_styles, "frame_rounding", data.value
                        ),
                    )
                    dcg.Slider(
                        context,
                        label="Frame Border",
                        value=demo_styles.get_default("frame_border_size"),
                        min_value=0,
                        max_value=3,
                        callback=lambda source, target, data: setattr(
                            demo_styles, "frame_border_size", data.value
                        ),
                    )

            dcg.Separator(context)

            # Display the demo button with applied theme
            dcg.Text(context, value="Live Preview:")
            dcg.Button(
                context,
                x="parent.x1 + theme.item_spacing.x",
                label="Demo Button",
                theme=demo_theme,
            )

            dcg.Separator(context)

            # Add descriptions
            with dcg.VerticalLayout(context):
                dcg.Text(context, value="Key Concepts:")
                dcg.Text(
                    context,
                    marker="bullet",
                    value="Colors control the visual appearance like button colors and text",
                )
                dcg.Text(
                    context,
                    marker="bullet",
                    value="Styles control sizing, spacing, borders and other layout properties",
                )
                dcg.Text(
                    context,
                    marker="bullet",
                    value="Themes can be applied to individual items or entire windows",
                )
                dcg.Text(
                    context,
                    marker="bullet",
                    value="Child items inherit parent themes unless overridden",
                )
