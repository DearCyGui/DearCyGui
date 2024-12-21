import dearcygui as dcg
import dearcygui.utils as utils
import numpy as np
from collections import deque

class ScrollingBuffer:
    """
    A scrolling buffer with a large memory backing.
    Does copy only when the memory backing is full.
    """
    def __init__(self,
                 scrolling_size=2000, 
                 max_size=1000000,
                 dtype=np.float64):
        self.data = np.zeros([max_size], dtype=dtype)
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
        self.metrics = deque(maxlen=10)
        self.plots = {}

        self.low_framerate_theme = dcg.ThemeColorImPlot(c)
        self.medium_framerate_theme = dcg.ThemeColorImPlot(c)
        self.high_framerate_theme = dcg.ThemeColorImPlot(c)
        self.low_framerate_theme.FrameBg = (1., 0., 0., 0.3)
        self.medium_framerate_theme.FrameBg = (1., 1., 0., 0.3)
        self.high_framerate_theme.FrameBg = (0., 0., 0., 0.)
        self.low_framerate_theme.PlotBg = (0., 0., 0., 1.)
        self.medium_framerate_theme.PlotBg = (0., 0., 0., 1.)
        self.high_framerate_theme.PlotBg = (0., 0., 0., 1.)
        self.low_framerate_theme.PlotBorder = (0., 0., 0., 0.)
        self.medium_framerate_theme.PlotBorder = (0., 0., 0., 0.)
        self.high_framerate_theme.PlotBorder = (0., 0., 0., 0.)

        with dcg.TabBar(c, label="Main Tabbar", parent=self):
            with dcg.Tab(c, label="General"):
                dcg.Text(c, label="DearCyGui Version: 0.0.1")
                self.text1 = dcg.Text(c)
                self.text2 = dcg.Text(c)
                self.text3 = dcg.Text(c)
                self.history = dcg.Slider(context, value=10., min_value=1., max_value=30., label="History", format="float", print_format="%.1f s")
                self.main_plot = dcg.Plot(c, height=200)
                self.main_plot.Y1.auto_fit = True
                self.main_plot.Y1.restrict_fit_to_range = True
                with self.main_plot:
                    self.history_bounds = np.zeros([2], dtype=np.float64)
                    self.history_bounds[0] = 0
                    self.history_bounds[1] = 10.
                    dcg.PlotShadedLine(c,
                                       label='60+ FPS',
                                       X=self.history_bounds,
                                       Y1=[0., 0.],
                                       Y2=[16., 16.],
                                       theme=dcg.ThemeColorImPlot(c, Fill=(0., 1., 0., 0.1)),
                                       ignore_fit=True)
                    dcg.PlotShadedLine(c,
                                       label='30+ FPS',
                                       X=self.history_bounds,
                                       Y1=[16., 16.],
                                       Y2=[32., 32.],
                                       theme=dcg.ThemeColorImPlot(c, Fill=(1., 1., 0., 0.1)),
                                       ignore_fit=True)
                    dcg.PlotShadedLine(c,
                                       label='Low FPS',
                                       X=self.history_bounds,
                                       Y1=[32., 32.],
                                       Y2=[64., 64.],
                                       theme=dcg.ThemeColorImPlot(c, Fill=(1., 0., 0., 0.1)),
                                       ignore_fit=True)
                    for key in ["Frame", "Presentation"]:
                        self.plots[key] = dcg.PlotLine(c,
                                                       label=key)
                self.secondary_plot = dcg.Plot(c,
                                               theme=dcg.ThemeColorImPlot(c, PlotBorder=0))
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
                child.parent = tw
            except TypeError:
                pass
        self.metrics_window_rendering_time = 0
        self.start_time = 1e-9*self.context.viewport.metrics["last_time_before_rendering"]
        self.rendering_metrics = self.context.viewport.metrics

    def log_times(self, watcher, target, watcher_data):
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

    def log_metrics(self):
        """
        The metrics we retrieve might be from a more
        recent frame than what log_times received last,
        or we might have run log_times before the metrics
        were updated. Thus we need to sync.
        """
        self.metrics.append(self.context.viewport.metrics)

    def update_plot(self, frame_count):
        treated_metrics = []
        treated_self_metrics = []
        # Treat frames where we have received both infos
        for rendering_metrics in self.metrics:
            found = False
            for self_metric in self.self_metrics:
                (frame_count, metrics_window_rendering_time, t_check) = self_metric
                if frame_count == rendering_metrics["frame_count"]:
                    found = True
                    break
            if not(found):
                continue
            rendering_metrics["delta_rendering"] = 1e-9 * (rendering_metrics["last_time_after_rendering"] - rendering_metrics["last_time_before_rendering"])
            if (rendering_metrics["delta_rendering"] - metrics_window_rendering_time) < 0:
                print(rendering_metrics, t_check, rendering_metrics["delta_rendering"], metrics_window_rendering_time)
                print(t_check[0] - rendering_metrics["last_time_before_rendering"], \
                      t_check[1] - t_check[0], \
                      rendering_metrics["last_time_after_rendering"]  - t_check[1]\
                )
            treated_metrics.append(rendering_metrics)
            treated_self_metrics.append(self_metric)
            self.data["Frame"].push(1e3 * rendering_metrics["delta_whole_frame"])
            self.data["Events"].push(1e3 * rendering_metrics["delta_event_handling"])
            self.data["Rendering(other)"].push(1e3 * (rendering_metrics["delta_rendering"] - metrics_window_rendering_time))
            self.data["Rendering(this)"].push(1e3 * metrics_window_rendering_time)
            self.data["Presentation"].push(1e3 * rendering_metrics["delta_presenting"])
        # Remove treated data
        for rendering_metrics in treated_metrics:
            self.metrics.remove(rendering_metrics)
        for self_metric in treated_self_metrics:
            self.self_metrics.remove(self_metric)
        rendered_vertices = rendering_metrics["rendered_vertices"]
        rendered_indices = rendering_metrics["rendered_indices"]
        rendered_windows = rendering_metrics["rendered_windows"]
        active_windows = rendering_metrics["active_windows"]
        current_time = 1e-9*rendering_metrics["last_time_before_rendering"]
        self.times.push(current_time - self.start_time)
        time_average = np.mean(self.data["Frame"].get()[-60:])
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

def get_children_recursive(item):
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
                dcg.Button(C, label="Install handlers", callbacks=self.setup_handlers)
                dcg.Button(C, label="Remove handlers", callbacks=self.remove_handlers)
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
                with dcg.HandlerList(C):
                    dcg.DraggingHandler(C, button=1, callback=self.handle_item_dragging)
                    dcg.DraggedHandler(C, button=1, callback=self.handle_item_dragged)
                dcg.HoverHandler(C)
                dcg.KeyDownHandler(C, key=dcg.constants.mvKey_LAlt) # TODO: modifiers
            # If a compatible item is hovered and the ALT key is set,
            # change the cursor to show we can drag
            with dcg.ConditionalHandler(C):
                dcg.MouseCursorHandler(C, cursor=dcg.MouseCursor.Hand)
                dcg.HoverHandler(C)
                dcg.KeyDownHandler(C, key=dcg.constants.mvKey_LAlt)

        self.dragging_item = None
        self.dragging_item_original_pos = None

    def setup_handlers(self):
        if len(self.inspected_items) > 0:
            # Uninstall previous handlers first
            self.remove_handlers()
        children_list = get_children_recursive(self.context.viewport)
        self.inspected_items += children_list
        for c in children_list:
            try:
                c.handlers += [self.item_handler]
            except Exception:
                # Pass incompatible items
                pass

    def remove_handlers(self):
        for item in self.inspected_items:
            try:
                handlers = item.handlers
                handlers = [h for h in handlers if h is not self.item_handler]
                item.handlers = handlers
            except AttributeError:
                pass
        self.inspected_items = []

    def handle_item_dragging(self, handler, item, drag_deltas):
        # Just to be safe. Might not be needed
        if item is not self.dragging_item and self.dragging_item is not None:
            return
        if self.dragging_item is None:
            self.dragging_item = item
            self.dragging_item_original_pos = item.pos_to_parent
        item.pos_to_parent = [
            self.dragging_item_original_pos[0] + drag_deltas[0],
            self.dragging_item_original_pos[1] + drag_deltas[1]
        ]

    def handle_item_dragged(self, handler, item):
        self.dragging_item = None

    def handle_item_hovered(self, handler, item):
        item_states = dir(item)
        C = self.context
        # Attach the tooltip to our window.
        # This is to not perturb the item states
        # and child tree.
        default_item = item.__class__(C, attach=False)
        ignore_list = [
            "shareable_value",
        ]
        with utils.TemporaryTooltip(C, target=item, parent=self):
            dcg.Text(C).value = f"{item}:"
            with dcg.HorizontalLayout(C, indent=-1, theme=dcg.ThemeStyleImGui(C, ItemSpacing=(40., -3.))):
                left = dcg.VerticalLayout(C)
                right = dcg.VerticalLayout(C)
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
                        dcg.Text(C, value=value)