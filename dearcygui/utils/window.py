from array import array
import dearcygui as dcg
import dearcygui.utils as utils
from collections import deque

class ScrollingBuffer:
    """
    A scrolling buffer with a large memory backing.
    Does copy only when the memory backing is full.
    """
    def __init__(self,
                 scrolling_size=2000, 
                 max_size=1000000):
        self.data = array('d', [0.0] * max_size)
        assert(2 * scrolling_size < max_size)
        self.size = 0
        self.scrolling_size = scrolling_size
        self.max_size = max_size

    def push(self, value):
        if self.size >= self.max_size:
            # We reached the end of the buffer.
            # Restart from the beginning
            self.data[:self.scrolling_size] = self.data[-self.scrolling_size:]
            self.size = self.scrolling_size
        self.data[self.size] = value
        self.size += 1

    def get(self, requested_size=None):
        if requested_size is None:
            requested_size = self.scrolling_size
        else:
            requested_size = min(self.scrolling_size, requested_size)
        start = max(0, self.size-requested_size)
        return self.data[start:self.size]

text_hints = {
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
    def __init__(self, context : dcg.Context, width=0, height=0, *args, **kwargs):
        super().__init__(context, width=width, height=height, *args, **kwargs)
        c = context
        # At this step the window is created

        # Create the data reserve
        self.data = {
            "Frame": ScrollingBuffer(),
            "Events": ScrollingBuffer(),
            "Rendering(other)": ScrollingBuffer(),
            "Rendering(this)": ScrollingBuffer(),
            "Presentation": ScrollingBuffer()
        }
        self.times = ScrollingBuffer()
        self.self_metrics = deque(maxlen=10)
        self.metrics : deque[dcg.ViewportMetrics] = deque(maxlen=10)
        self.plots = {}

        self.low_framerate_theme = dcg.ThemeColorImPlot(c)
        self.medium_framerate_theme = dcg.ThemeColorImPlot(c)
        self.high_framerate_theme = dcg.ThemeColorImPlot(c)
        self.low_framerate_theme.frame_bg = (1., 0., 0., 0.3)
        self.medium_framerate_theme.frame_bg = (1., 1., 0., 0.3)
        self.high_framerate_theme.frame_bg = (0., 0., 0., 0.)
        self.low_framerate_theme.plot_bg = (0., 0., 0., 1.)
        self.medium_framerate_theme.plot_bg = (0., 0., 0., 1.)
        self.high_framerate_theme.plot_bg = (0., 0., 0., 1.)
        self.low_framerate_theme.plot_border = (0., 0., 0., 0.)
        self.medium_framerate_theme.plot_border = (0., 0., 0., 0.)
        self.high_framerate_theme.plot_border = (0., 0., 0., 0.)

        with dcg.TabBar(c, label="Main Tabbar", parent=self):
            with dcg.Tab(c, label="General"):
                dcg.Text(c, value="DearCyGui Version: 0.1.0")
                self.text1 = dcg.Text(c)
                self.text2 = dcg.Text(c)
                self.text3 = dcg.Text(c)
                self.history = dcg.Slider(context, value=10., min_value=1., max_value=30., label="History", print_format="%.1f s")
                self.main_plot = dcg.Plot(c, height=200)
                self.main_plot.Y1.auto_fit = True
                self.main_plot.Y1.restrict_fit_to_range = True
                with self.main_plot:
                    self.history_bounds = array('d', [0.0, 0.0])
                    self.history_bounds[0] = 0
                    self.history_bounds[1] = 10.
                    dcg.PlotShadedLine(c,
                                       label='60+ FPS',
                                       X=self.history_bounds,
                                       Y1=[0., 0.],
                                       Y2=[16., 16.],
                                       theme=dcg.ThemeColorImPlot(c, fill=(0., 1., 0., 0.1)),
                                       ignore_fit=True)
                    dcg.PlotShadedLine(c,
                                       label='30+ FPS',
                                       X=self.history_bounds,
                                       Y1=[16., 16.],
                                       Y2=[32., 32.],
                                       theme=dcg.ThemeColorImPlot(c, fill=(1., 1., 0., 0.1)),
                                       ignore_fit=True)
                    dcg.PlotShadedLine(c,
                                       label='Low FPS',
                                       X=self.history_bounds,
                                       Y1=[32., 32.],
                                       Y2=[64., 64.],
                                       theme=dcg.ThemeColorImPlot(c, fill=(1., 0., 0., 0.1)),
                                       ignore_fit=True)
                    for key in ["Frame", "Presentation"]:
                        self.plots[key] = dcg.PlotLine(c,
                                                       label=key)
                self.secondary_plot = dcg.Plot(c,
                                               theme=dcg.ThemeColorImPlot(c, plot_border=0))
                self.secondary_plot.Y1.auto_fit = True
                self.secondary_plot.Y1.restrict_fit_to_range = True
                with self.secondary_plot:
                    for key in self.data.keys():
                        if key in ["Frame", "Presentation"]:
                            continue
                        self.plots[key] = dcg.PlotLine(c,
                                                       label=key)

        # Add Legend tooltips
        # Contrary to DPG, they are not children of the elements, but children of the window.
        for plot_element in self.main_plot.children + self.secondary_plot.children:
            key = plot_element.label
            if key in text_hints.keys():
                with dcg.Tooltip(c, target=plot_element, parent=self):
                    dcg.Text(c, value=text_hints[key])
        # Add axis tooltips
        with dcg.Tooltip(c, target=self.main_plot.X1, parent=self):
            dcg.Text(c, value=text_hints["X"])
        with dcg.Tooltip(c, target=self.main_plot.Y1, parent=self):
            dcg.Text(c, value=text_hints["Y"])
        with dcg.Tooltip(c, target=self.secondary_plot.X1, parent=self):
            dcg.Text(c, value=text_hints["X"])
        with dcg.Tooltip(c, target=self.secondary_plot.Y1, parent=self):
            dcg.Text(c, value=text_hints["Y"])
        
        # Attach a TimeWatch Instance to measure the time
        # spent rendering this item's children. We do
        # not measure the window itself, but it should
        # be small.
        children = self.children
        tw = dcg.TimeWatcher(context, parent=self, callback=self.log_times)
        # Move the ui children to TimeWatcher
        for child in children:
            try:
                assert not isinstance(child, dcg.MenuBar)
                child.parent = tw
            except TypeError:
                pass
        self.metrics_window_rendering_time = 0
        self.start_time = self.context.viewport.metrics.last_time_before_rendering
        self.rendering_metrics = self.context.viewport.metrics

    def log_times(self, watcher, target, watcher_data) -> None:
        """Record timing data from a time watcher.
        
        This method processes the timing information collected by the time watcher
        and stores it for later use in metrics calculations. It triggers metrics
        logging and plot updates based on the received data.
        """
        start_metrics_rendering = watcher_data[0]
        stop_metrics_rendering = watcher_data[1]
        frame_count = watcher_data[3]
        delta = stop_metrics_rendering - start_metrics_rendering
        # Perform a running average
        #self.metrics_window_rendering_time = \
        #    0.9 * self.metrics_window_rendering_time + \
        #    0.1 * delta
        #self.metrics_window_rendering_time = delta * 1e-9
        self.self_metrics.append((frame_count, delta * 1e-9, watcher_data))
        self.log_metrics()
        self.update_plot(frame_count)

    def log_metrics(self) -> None:
        """Record viewport metrics for performance tracking.
        
        This method captures the current viewport metrics and stores them in the
        metrics queue for later processing. It handles potential timing 
        differences between when metrics are recorded and when they're processed.
        """
        self.metrics.append(self.context.viewport.metrics)

    def update_plot(self, frame_count) -> None:
        """Update visualization plots with the latest metrics data.
        
        This method processes collected metrics data, updates the various 
        performance graphs, and refreshes status text elements. It synchronizes
        metric data from different sources to ensure consistency, and applies
        appropriate visual cues based on performance levels.
        """
        treated_metrics = []
        treated_self_metrics = []
        # Treat frames where we have received both infos
        for rendering_metrics in self.metrics:
            for self_metric in self.self_metrics:
                (frame_count, metrics_window_rendering_time, t_check) = self_metric
                if frame_count == rendering_metrics.frame_count:
                    break
            else:
                continue
            treated_metrics.append(rendering_metrics)
            treated_self_metrics.append(self_metric)
            self.data["Frame"].push(1e3 * rendering_metrics.delta_whole_frame)
            self.data["Events"].push(1e3 * rendering_metrics.delta_event_handling)
            self.data["Rendering(other)"].push(1e3 * (rendering_metrics.delta_rendering - metrics_window_rendering_time))
            self.data["Rendering(this)"].push(1e3 * metrics_window_rendering_time)
            self.data["Presentation"].push(1e3 * rendering_metrics.delta_presenting)
        # Remove treated data
        for rendering_metrics in treated_metrics:
            try:
                self.metrics.remove(rendering_metrics)
            except ValueError:
                # Removed by deque length limit
                pass
        for self_metric in treated_self_metrics:
            try:
                self.self_metrics.remove(self_metric)
            except ValueError:
                # Removed by deque length limit
                pass
        # Update the plots
        rendering_metrics = self.context.viewport.metrics
        rendered_vertices = rendering_metrics.rendered_vertices
        rendered_indices = rendering_metrics.rendered_indices
        rendered_windows = rendering_metrics.rendered_windows
        active_windows = rendering_metrics.active_windows
        current_time = rendering_metrics.last_time_before_rendering
        self.times.push(current_time - self.start_time)
        time_average = sum(self.data["Frame"].get()[-60:]) / 60
        fps_average = 1e3 / (max(1e-20, time_average))
        if fps_average < 29:
            self.main_plot.theme = self.low_framerate_theme
        elif fps_average < 59:
            self.main_plot.theme = self.medium_framerate_theme
        else:
            self.main_plot.theme = self.high_framerate_theme

        self.text1.value = "Application average %.3f ms/frame (%.1f FPS)" % (time_average, fps_average)
        self.text2.value = "%d vertices, %d indices (%d triangles)" % (rendered_vertices, rendered_indices, rendered_indices//3)
        self.text3.value = "%d active windows (%d visible)" % (active_windows, rendered_windows)
        DT1 = current_time - self.start_time
        DT0 = current_time - self.start_time - self.history.value
        self.history_bounds[1] = DT1
        self.history_bounds[0] = DT0
        self.main_plot.X1.min = DT0 # TODO: do that in a thread to avoid waking
        self.main_plot.X1.max = DT1
        self.secondary_plot.X1.min = DT0
        self.secondary_plot.X1.max = DT1

        # This is actually no copy
        for key in self.plots.keys():
            self.plots[key].X = self.times.get()
            self.plots[key].Y = self.data[key].get()

def get_children_recursive(item: dcg.baseItem) -> list[dcg.baseItem]:
    """Recursively collect all children of an item.
    
    This function traverses the item hierarchy and returns a flat list containing
    the given item and all of its descendants.
    """
    result = [item]
    children = item.children
    for c in children:
        result += get_children_recursive(c)
    return result

class ItemInspecter(dcg.Window):
    def __init__(self, context : dcg.Context, width=0, height=0, *args, **kwargs):
        super().__init__(context, width=width, height=height, *args, **kwargs)
        self.inspected_items = []
        C = context
        with self:
            with dcg.HorizontalLayout(C, alignment_mode=dcg.Alignment.LEFT):
                dcg.Button(C, label="Install handlers", callback=self.setup_handlers)
                dcg.Button(C, label="Remove handlers", callback=self.remove_handlers)
            with dcg.HorizontalLayout(C, alignment_mode=dcg.Alignment.CENTER):
                with dcg.VerticalLayout(C):
                    dcg.Text(C, wrap=0).value = \
                    "Help: Hover an item to inspect it. Alt+right click to move it."

        self.item_handler = dcg.HandlerList(C)
        with self.item_handler:
            dcg.GotHoverHandler(C, callback=self.handle_item_hovered)
            # If an item is hovered and the Alt key is pressed,
            # handle dragging an item.
            with dcg.ConditionalHandler(C):
                dcg.DraggingHandler(C, button=dcg.MouseButton.RIGHT, callback=self.handle_item_dragging)
                dcg.KeyDownHandler(C, key=dcg.Key.LEFTALT)
            dcg.DraggedHandler(C, button=dcg.MouseButton.RIGHT, callback=self.handle_item_dragged)
            # If a compatible item is hovered and the ALT key is set,
            # change the cursor to show we can drag
            with dcg.ConditionalHandler(C):
                dcg.MouseCursorHandler(C, cursor=dcg.MouseCursor.HAND)
                dcg.HoverHandler(C)
                dcg.KeyDownHandler(C, key=dcg.Key.LEFTALT)

        self.dragging_item = None
        self.dragging_item_original_pos = None

    def setup_handlers(self) -> None:
        """Install inspection handlers on all UI elements.
        
        This method installs event handlers on all UI elements in the viewport,
        enabling them to be inspected and manipulated through the inspector
        interface. It cleans up any previously installed handlers first.
        """
        if len(self.inspected_items) > 0:
            # Uninstall previous handlers first
            self.remove_handlers()
        children_list = get_children_recursive(self.context.viewport)
        self.inspected_items += children_list
        for c in children_list:
            try:
                c.handlers += [self.item_handler] # type: ignore
            except Exception:
                # Pass incompatible items
                pass

    def remove_handlers(self) -> None:
        """Remove all inspection handlers from UI elements.
        
        This method removes the previously installed inspection handlers from
        all tracked UI elements, effectively disabling the inspection 
        functionality.
        """
        for item in self.inspected_items:
            try:
                handlers = item.handlers
                handlers = [h for h in handlers if h is not self.item_handler]
                item.handlers = handlers
            except AttributeError:
                pass
        self.inspected_items = []

    def handle_item_dragging(self, handler, item: dcg.uiItem, drag_deltas) -> None:
        """Process UI element dragging events.
        
        This method handles the dragging of UI elements, updating their position
        relative to their parent based on the mouse movement. It tracks the
        currently dragged item and maintains its original position for reference.
        """
        # Just to be safe. Might not be needed
        if item is not self.dragging_item and self.dragging_item is not None:
            return
        if self.dragging_item is None:
            self.dragging_item = item
            self.dragging_item_original_pos = item.state.pos_to_parent
        new_pos = [
            self.dragging_item_original_pos[0] + drag_deltas[0], # type: ignore
            self.dragging_item_original_pos[1] + drag_deltas[1] # type: ignore
        ]
        item.x = f"parent.x1 + {new_pos[0]}"
        item.y = f"parent.y1 + {new_pos[1]}"

    def handle_item_dragged(self, handler, item) -> None:
        """Handle the completion of a UI element drag operation.
        
        This method is called when a drag operation ends, cleaning up the 
        dragging state and preparing for potential future drag operations.
        """
        self.dragging_item = None

    def handle_item_hovered(self, handler, item):
        """Display detailed information about a hovered UI element.
        
        This method creates a tooltip showing properties of the hovered UI
        element. It compares the element's current state with default values
        to highlight customized properties, and presents this information in
        an organized two-column layout.
        """
        item_states = dir(item)
        C = self.context
        # Attach the tooltip to our window.
        # This is to not perturb the item states
        # and child tree.
        try:
            default_item = item.__class__(C, attach=False)
        except:
            default_item = None
        ignore_list = [
            "shareable_value",
        ]
        with utils.TemporaryTooltip(C, target=item, parent=self):
            dcg.Text(C).value = f"{item}:"
            dcg.Spacer(C, width="theme.indent_spacing.x - theme.item_spacing.x", no_newline=True)
            left = dcg.VerticalLayout(C,
                theme=dcg.ThemeStyleImGui(C, item_spacing=(40., -3.)),
                no_newline=True)
            right = dcg.VerticalLayout(C, theme=left.theme)
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
                        value = [v for v in value if v is not self.item_handler]
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

def _is_style_element(class_obj, name: str) -> bool:
    """
    Returns True if name is a valid theme element
    """
    try:
        class_obj.get_default(name) # type: ignore
        return True
    except KeyError:
        return False

class StyleEditor(dcg.Window):
    """A visual tool to edit the global style of the application.
    
    This window provides interactive controls for customizing colors, sizes,
    spacing and other visual aspects of the UI. It allows real-time preview
    of changes and provides options to apply, reset or export the theme.
    """
    def __init__(self, context : dcg.Context, **kwargs) -> None:
        super().__init__(context, **kwargs)
        self.current_theme = context.viewport.theme
        self.main_theme = dcg.ThemeList(self.context)
        self.imgui_color_theme = dcg.ThemeColorImGui(self.context, parent=self.main_theme)
        self.imgui_style_theme = dcg.ThemeStyleImGui(self.context, parent=self.main_theme)
        self.implot_color_theme = dcg.ThemeColorImPlot(self.context, parent=self.main_theme)
        self.implot_style_theme = dcg.ThemeStyleImPlot(self.context, parent=self.main_theme)

        with dcg.HorizontalLayout(context, parent=self, alignment_mode=dcg.Alignment.CENTER):
            dcg.Button(context, label="Reset", callback=self.reset_values)
            dcg.Button(context, label="Apply", callback=lambda: context.viewport.configure(theme=self.main_theme))
            dcg.Button(context, label="Cancel", callback=lambda: context.viewport.configure(theme=self.current_theme))
            self.export_button = dcg.Button(context, label="Export", callback=self.export_to_clipboard)
            with dcg.Tooltip(context):
                dcg.Text(context, value = "Export the current theme to the clipboard")
            self.filter_defaults = dcg.Checkbox(context, label="Filter defaults", value=True)
            with dcg.Tooltip(context):
                dcg.Text(context, value="Include only non-default values in the export")
                dcg.Text(context, value="Generates shorter code, but may be affected if defaults change")
            dcg.Button(context, label="Help", callback=lambda: self.launch_help_window())

        with dcg.TabBar(context, label="Style Editor", parent=self):
            with dcg.Tab(context, label="Colors"):
                with dcg.TabBar(context, label="Category"):
                    with dcg.Tab(context, label="ImGui"):
                        imgui_color_names = [name for name in dir(self.imgui_color_theme) if _is_style_element(dcg.ThemeColorImGui, name)]
                        for color_name in imgui_color_names:
                            default_color = self.imgui_color_theme.get_default(color_name)
                            def callback_imgui_color(s, t, d, color_name=color_name) -> None:
                                setattr(self.imgui_color_theme, color_name, d)
                            dcg.ColorEdit(context,
                                          label=color_name,
                                          value=default_color,
                                          user_data=default_color, # for Reset
                                          callback=callback_imgui_color
                                          )
                    with dcg.Tab(context, label="ImPlot"):
                        implot_color_names = [name for name in dir(self.implot_color_theme) if _is_style_element(dcg.ThemeColorImPlot, name)]
                        for color_name in implot_color_names:
                            default_color = self.implot_color_theme.get_default(color_name)
                            def callback_implot_color(s, t, d, color_name=color_name) -> None:
                                setattr(self.implot_color_theme, color_name, d)
                            dcg.ColorEdit(context,
                                          label=color_name,
                                          value=default_color,
                                          user_data=default_color, # for Reset
                                          callback=callback_implot_color
                                          )
            with dcg.Tab(context, label="Styles"):
                with dcg.TabBar(context, label="Category"):
                    with dcg.Tab(context, label="ImGui"):
                        imgui_style_names = [name for name in dir(self.imgui_style_theme) if _is_style_element(dcg.ThemeStyleImGui, name)]
                        for style_name in imgui_style_names:
                            default_style = self.imgui_style_theme.get_default(style_name)
                            item_type = type(default_style)
                            if item_type is tuple:
                                item_type = type(default_style[0])
                                size = 2
                            else:
                                size = 1
                            if item_type is float:
                                print_format="%.2f"
                            elif item_type is int:
                                print_format="%.0f"
                            else:
                                continue # Skip unsupported types
                            def callback_imgui_style(s, t, d, style_name=style_name) -> None:
                                try:
                                    if len(d) == 1:
                                        d = d[0]
                                except:
                                    pass
                                setattr(self.imgui_style_theme, style_name, d)
                            with dcg.HorizontalLayout(context, no_wrap=True):
                                utils.SliderN(context,
                                              print_format=print_format,
                                              label="",
                                              logarithmic=True,
                                              value=default_style,
                                              user_data=default_style, # for Reset
                                              callback=callback_imgui_style
                                              )
                                dcg.Text(context, value=style_name)
                    with dcg.Tab(context, label="ImPlot"):
                        implot_style_names = [name for name in dir(self.implot_style_theme) if _is_style_element(dcg.ThemeStyleImPlot, name)]
                        for style_name in implot_style_names:
                            default_style = self.implot_style_theme.get_default(style_name)
                            item_type = type(default_style)
                            if item_type is tuple:
                                item_type = type(default_style[0])
                                size = 2
                            else:
                                size = 1
                            if item_type is float:
                                print_format="%.2f"
                            elif item_type is int:
                                print_format="%.0f"
                            elif item_type is dcg.PlotMarker:
                                def callback_implot_style_marker(s, t, d, style_name=style_name) -> None:
                                    setattr(self.implot_style_theme, style_name, dcg.PlotMarker[d])
                                dcg.Combo(context,
                                          label=style_name,
                                          items=[name for name in dir(dcg.PlotMarker) if name[0].isupper()],
                                          value=default_style.name,
                                          user_data=default_style, # for Reset
                                          callback=callback_implot_style_marker
                                          )
                                continue
                            else:
                                continue # Skip unsupported types
                            def callback_implot_style(s, t, d, style_name=style_name) -> None:
                                try:
                                    if len(d) == 1:
                                        d = d[0]
                                except:
                                    pass
                                setattr(self.implot_style_theme, style_name, d)
                            with dcg.HorizontalLayout(context, no_wrap=True):
                                utils.SliderN(context,
                                              print_format=print_format,
                                              logarithmic=True,
                                              label="",
                                              value=default_style,
                                              user_data=default_style, # for Reset
                                              callback=callback_implot_style
                                              )
                                dcg.Text(context, value=style_name)

    def _recursive_reset_values(self, item) -> None:
        """Recursively reset all theme values to their defaults.
        
        This internal method traverses the widget hierarchy and resets all
        color and style values to their default states, ensuring all controls
        reflect these reset values.
        """
        for child in item.children:
            self._recursive_reset_values(child)
            if isinstance(child, dcg.ColorEdit):
                child.value = child.user_data
                child.callbacks[0](self, child, child.value)
            if isinstance(child, dcg.Slider):
                child.value = child.user_data
                child.callbacks[0](self, child, child.value)
            if isinstance(child, dcg.Combo):
                child.value = child.user_data.name
                child.callbacks[0](self, child, child.value)

    def reset_values(self) -> None:
        """Reset all theme values to their defaults.
        
        This method resets all color and style values to their default states
        by triggering a recursive traversal of the style editor's widgets.
        """
        self._recursive_reset_values(self)

    def export_to_text(self) -> str:
        """Convert the current theme to Python code.
        
        This method generates Python code that recreates the current theme
        configuration. It can optionally filter out default values to produce
        more concise code.
        """
        non_default_imgui_colors = {}
        non_default_imgui_styles = {}
        non_default_implot_colors = {}
        non_default_implot_styles = {}
        should_filter = self.filter_defaults.value

        if should_filter:
            for (name, value) in self.imgui_color_theme:
                if value != self.imgui_color_theme.get_default(name):
                    non_default_imgui_colors[name] = dcg.color_as_floats(value)
            for (name, value) in self.imgui_style_theme or not(should_filter):
                if value != self.imgui_style_theme.get_default(name):
                    non_default_imgui_styles[name] = value
            for (name, value) in self.implot_color_theme:
                if value != self.implot_color_theme.get_default(name):
                    non_default_implot_colors[name] = dcg.color_as_floats(value)
            for (name, value) in self.implot_style_theme:
                if value != self.implot_style_theme.get_default(name):
                    non_default_implot_styles[name] = value
        else:
            imgui_color_names = [name for name in dir(self.imgui_color_theme) if name[0].isupper()]
            for name in imgui_color_names:
                value = getattr(self.imgui_color_theme, name, None)
                if value is None:
                    value = self.imgui_color_theme.get_default(name)
                non_default_imgui_colors[name] = dcg.color_as_floats(value)
            imgui_style_names = [name for name in dir(self.imgui_style_theme) if name[0].isupper()]
            for name in imgui_style_names:
                value = getattr(self.imgui_style_theme, name, None)
                if value is None:
                    value = self.imgui_style_theme.get_default(name)
                non_default_imgui_styles[name] = value
            implot_color_names = [name for name in dir(self.implot_color_theme) if name[0].isupper()]
            for name in implot_color_names:
                value = getattr(self.implot_color_theme, name, None)
                if value is None:
                    value = self.implot_color_theme.get_default(name)
                non_default_implot_colors[name] = dcg.color_as_floats(value)
            implot_style_names = [name for name in dir(self.implot_style_theme) if name[0].isupper()]
            for name in implot_style_names:
                value = getattr(self.implot_style_theme, name, None)
                if value is None:
                    value = self.implot_style_theme.get_default(name)
                non_default_implot_styles[name] = value

        imgui_color_str = ""
        if len(non_default_imgui_colors) > 0:
            string_setters = [f"{name}={value}" for (name, value) in non_default_imgui_colors.items()]
            imgui_color_str = "    dcg.ThemeColorImGui(context,\n        " + ",\n        ".join(string_setters) + ")"
        imgui_style_str = ""
        if len(non_default_imgui_styles) > 0:
            string_setters = [f"{name}={value}" for (name, value) in non_default_imgui_styles.items()]
            imgui_style_str = "    dcg.ThemeStyleImGui(context,\n        " + ",\n        ".join(string_setters) + ")"
        implot_color_str = ""
        if len(non_default_implot_colors) > 0:
            string_setters = [f"{name}={value}" for (name, value) in non_default_implot_colors.items()]
            implot_color_str = "    dcg.ThemeColorImPlot(context,\n        " + ",\n        ".join(string_setters) + ")"
        implot_style_str = ""
        if len(non_default_implot_styles) > 0:
            string_setters = [f"{name}={value}" for (name, value) in non_default_implot_styles.items()]
            implot_style_str = "    dcg.ThemeStyleImPlot(context,\n        " + ",\n        ".join(string_setters) + ")"

        # no theme
        if sum([len(non_default_imgui_colors) > 0,
                len(non_default_imgui_styles) > 0,
                len(non_default_implot_colors) > 0,
                len(non_default_implot_styles) > 0]) == 0:
            return "theme = None"

        if sum([len(non_default_imgui_colors) > 0,
                len(non_default_imgui_styles) > 0,
                len(non_default_implot_colors) > 0,
                len(non_default_implot_styles) > 0]) == 1:
            return "theme = \\\n" +\
                imgui_color_str + imgui_style_str + \
                implot_color_str + implot_style_str

        full_text = ""
        if len(non_default_imgui_colors) > 0:
            full_text += "theme_imgui_color = \\\n" + imgui_color_str + "\n"
        if len(non_default_imgui_styles) > 0:
            full_text += "theme_imgui_style = \\\n" + imgui_style_str + "\n"
        if len(non_default_implot_colors) > 0:
            full_text += "theme_implot_color = \\\n" + implot_color_str + "\n"
        if len(non_default_implot_styles) > 0:
            full_text += "theme_implot_style = \\\n" + implot_style_str + "\n"

        # combine in a theme list
        full_text += "theme = dcg.ThemeList(context)\ntheme.children = [\n"
        if len(non_default_imgui_colors) > 0:
            full_text += "    theme_imgui_color,\n"
        if len(non_default_imgui_styles) > 0:
            full_text += "    theme_imgui_style,\n"
        if len(non_default_implot_colors) > 0:
            full_text += "    theme_implot_color,\n"
        if len(non_default_implot_styles) > 0:
            full_text += "    theme_implot_style,\n"
        full_text += "]\n"
        return full_text

    def export_to_clipboard(self) -> None:
        """Copy the current theme as Python code to the clipboard.
        
        This method generates Python code for the current theme and places it
        in the system clipboard, allowing for easy pasting into other files.
        """
        self.context.clipboard = self.export_to_text()
        with dcg.utils.TemporaryTooltip(self.context, target=self.export_button, parent=self):
            dcg.Text(self.context, value="Theme copied to clipboard")

    def launch_help_window(self) -> None:
        """Display a help window with information about theming.
        
        This method creates a modal window explaining theme concepts and 
        providing interactive examples to demonstrate how different theme 
        properties affect the appearance of UI elements.
        """
        C = self.context
        with dcg.Window(C, label="Theme Editor Help", autosize=True, modal=True):
            dcg.Text(C, value="Theme colors and styles allow customizing the appearance of UI elements.")
            dcg.Separator(C)
            
            # Create a demo button with its own theme
            demo_theme = dcg.ThemeList(C)
            demo_colors = dcg.ThemeColorImGui(C, parent=demo_theme)
            demo_styles = dcg.ThemeStyleImGui(C, parent=demo_theme)

            # Create controls for the most relevant button properties
            with dcg.HorizontalLayout(C):
                with dcg.VerticalLayout(C):
                    dcg.Text(C, value="Colors:")
                    dcg.ColorEdit(C, label="Button Color",
                                  value=demo_colors.get_default("button"),
                                  callback=lambda s,t,d: setattr(demo_colors, "button", d))
                    dcg.ColorEdit(C, label="Button Hovered",
                                  value=demo_colors.get_default("button_hovered"),
                                  callback=lambda s,t,d: setattr(demo_colors, "button_hovered", d))
                    dcg.ColorEdit(C, label="Button Active",
                                  value=demo_colors.get_default("Button_active"),
                                  callback=lambda s,t,d: setattr(demo_colors, "button_active", d))
                    dcg.ColorEdit(C, label="Text",
                                  value=demo_colors.get_default("text"),
                                  callback=lambda s,t,d: setattr(demo_colors, "text", d))
                
                with dcg.VerticalLayout(C):
                    dcg.Text(C, value="Styles:")
                    with dcg.HorizontalLayout(C, no_wrap=True):
                        utils.SliderN(C,
                                      value=demo_styles.get_default("frame_padding"),
                                      callback=lambda s,t,d: setattr(demo_styles, "frame_padding", d[:2]))
                        dcg.Text(C, value="Frame Padding")
                    dcg.Slider(C, label="Frame Rounding",
                               value=demo_styles.get_default("frame_rounding"),
                               min_value=0, max_value=12,
                               callback=lambda s,t,d: setattr(demo_styles, "frame_rounding", d))
                    dcg.Slider(C, label="Frame Border",
                               value=demo_styles.get_default("frame_border_size"),
                               min_value=0, max_value=3,
                               callback=lambda s,t,d: setattr(demo_styles, "frame_border_size", d))
            
            dcg.Separator(C)
            
            # Display the demo button with applied theme
            dcg.Text(C, value="Live Preview:")
            dcg.Button(C, x="parent.x1 + theme.item_spacing.x", label="Demo Button", theme=demo_theme)
            
            dcg.Separator(C)
            
            # Add descriptions
            with dcg.VerticalLayout(C):
                dcg.Text(C, value="Key Concepts:")
                dcg.Text(C, marker="bullet", value="Colors control the visual appearance like button colors and text")
                dcg.Text(C, marker="bullet", value="Styles control sizing, spacing, borders and other layout properties")
                dcg.Text(C, marker="bullet", value="Themes can be applied to individual items or entire windows")
                dcg.Text(C, marker="bullet", value="Child items inherit parent themes unless overridden")

