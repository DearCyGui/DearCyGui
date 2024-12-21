import dearcygui as dcg

class DragPoint(dcg.DrawingList):
    def __init__(self, context : dcg.Context, *args, **kwargs):
        # Create the drawing elements
        with self:
            self.invisible = dcg.DrawInvisibleButton(context)
            self.visible = dcg.DrawCircle(context)
        # Set default parameters
        self.radius = 4.
        self.color = (0, 255, 0, 255)
        self.visible.color = 0 # Invisible outline
        self._on_hover = None
        self._on_dragged = None
        self._on_dragging = None
        self._clamp_inside = False
        self.was_dragging = False
        # We do in a separate function to allow
        # subclasses to override the callbacks
        self.setup_callbacks()
        # Configure
        super().__init__(context, *args, **kwargs)

    def setup_callbacks(self):
        # Note: Since this is done before configure,
        # we are not in the parent tree yet
        # and do not need the mutex
        set_cursor_on_hover = dcg.ConditionalHandler(self.context)
        with set_cursor_on_hover:
            dcg.MouseCursorHandler(self.context, cursor=dcg.MouseCursor.ResizeAll)
            dcg.HoverHandler(self.context)
        self.invisible.handlers += [
            dcg.HoverHandler(self.context, callback=self.handler_hover),
            dcg.DraggingHandler(self.context, callback=self.handler_dragging),
            dcg.DraggedHandler(self.context, callback=self.handler_dragged),
            set_cursor_on_hover
        ]

    @property
    def radius(self):
        """Radius of the draggable point"""
        with self.mutex:
            return self._radius

    @radius.setter
    def radius(self, value):
        with self.mutex:
            self._radius = value
            # We rely solely on min_size to make a
            # point with desired screen space size,
            # thus why we set p1 = p2
            self.invisible.min_side = value * 2.
            # Negative value to not rescale
            self.visible.radius = -value

    @property
    def x(self):
        """X coordinate in screen space"""
        with self.mutex:
            return self.invisible.p1[0]

    @x.setter
    def x(self, value):
        with self.mutex:
            y = self.invisible.p1[1]
            self.invisible.p1 = [value, y]
            self.invisible.p2 = [value, y]
            self.visible.center = [value, y]

    @property
    def y(self):
        """Y coordinate in screen space"""
        with self.mutex:
            return self.invisible.p1[1]

    @y.setter
    def y(self, value):
        with self.mutex:
            x = self.invisible.p1[0]
            self.invisible.p1 = [x, value]
            self.invisible.p2 = [x, value]
            self.visible.center = [x, value]

    @property
    def clamp_inside(self):
        """
        If set, the point will be forced to remain
        in the plot visible area.
        """
        with self.mutex:
            return self._clamp_inside

    @clamp_inside.setter
    def clamp_inside(self, value):
        """
        If set, the point will be forced to remain
        in the plot visible area.
        """
        # We access parent elements
        # It's simpler to lock the toplevel parent in case of doubt.
        with self.parents_mutex:
            if self._clamp_inside == bool(value):
                return
            self._clamp_inside = bool(value)
            plot_element = self.parent
            while not(isinstance(plot_element, dcg.plotElement)):
                if isinstance(plot_element, dcg.Viewport):
                    # We reached the top parent without finding a plotElement
                    raise ValueError("clamp_inside requires to be in a plot")
                plot_element = plot_element.parent
            self.axes = plot_element.axes
            plot = plot_element.parent
            if self._clamp_inside:
                plot.handlers += [
                    dcg.RenderHandler(self.context,
                                       callback=self.handler_visible_for_clamping)
                ]
            else:
                plot.handlers = [h for h in self.parent.handlers if h is not self.handler_visible_for_clamping]

    @property
    def color(self):
        """Color of the displayed circle"""
        with self.mutex:
            return self.visible.fill

    @color.setter
    def color(self, value):
        with self.mutex:
            self.visible.fill = value

    @property
    def on_hover(self):
        """
        Callback that is called whenever the item
        is hovered
        """
        with self.mutex:
            return self._on_hover

    @on_hover.setter
    def on_hover(self, value):
        with self.mutex:
            self._on_hover = value if value is None or \
                                isinstance(value, dcg.Callback) else \
                                dcg.Callback(value)

    @property
    def on_dragging(self):
        """
        Callback that is called whenever the item
        changes position due to user interaction
        """
        with self.mutex:
            return self._on_dragging

    @on_dragging.setter
    def on_dragging(self, value):
        with self.mutex:
            self._on_dragging = value if value is None or \
                                isinstance(value, dcg.Callback) else \
                                dcg.Callback(value)

    @property
    def on_dragged(self):
        """
        Callback that is called whenever the item
        changes position due to user interaction and
        the user releases his interaction.
        """
        with self.mutex:
            return self._on_dragged

    @on_dragged.setter
    def on_dragged(self, value):
        with self.mutex:
            self._on_dragged = value if value is None or \
                               isinstance(value, dcg.Callback) else \
                               dcg.Callback(value)

    def handler_dragging(self, _, __, drag_deltas):
        # During the dragging we might not hover anymore the button
        # Note: we must not lock our mutex before we access viewport
        # attributes
        with self.mutex:
            # backup coordinates before dragging
            if not(self.was_dragging):
                self.backup_x = self.x
                self.backup_y = self.y
                self.was_dragging = True
            # update the coordinates
            self.x = self.backup_x + drag_deltas[0]
            self.y = self.backup_y + drag_deltas[1]
            _on_dragging = self._on_dragging
        # Release our mutex before calling the callback
        if _on_dragging is not None:
            _on_dragging(self, self, (self.x, self.y))

    def handler_dragged(self, _, __, drag_deltas):
        with self.mutex:
            self.was_dragging = False
            # update the coordinates
            self.x = self.backup_x + drag_deltas[0]
            self.y = self.backup_y + drag_deltas[1]
            _on_dragged = self._on_dragged
        if _on_dragged is not None:
            _on_dragged(self, self, (self.x, self.y))

    def handler_hover(self):
        with self.mutex:
            _on_hover = self._on_hover
        if _on_hover is not None:
            _on_hover(self, self, None)

    def handler_visible_for_clamping(self, handler, plot : dcg.Plot):
        # Every time the plot is visible, we
        # clamp the content if needed
        with plot.mutex: # We must lock the plot first
            with self.mutex:
                x_axis = plot.axes[self.axes[0]]
                y_axis = plot.axes[self.axes[1]]
                mx = x_axis.min
                Mx = x_axis.max
                my = y_axis.min
                My = y_axis.max
                if self.x < mx:
                    self.x = mx
                if self.x > Mx:
                    self.x = Mx
                if self.y < my:
                    self.y = my
                if self.y > My:
                    self.y = My
    # Redirect to the invisible button the states queries
    # We do not need the mutex to access self.invisible
    # as it is not supposed to change.
    # For the attributes themselves, self.invisible
    # will use its mutex
    @property
    def active(self):
        return self.invisible.active

    @property
    def activated(self):
        return self.invisible.activated

    @property
    def clicked(self):
        return self.invisible.clicked

    @property
    def double_clicked(self):
        return self.invisible.double_clicked

    @property
    def deactivated(self):
        return self.invisible.deactivated

    @property
    def pos_to_viewport(self):
        return self.invisible.pos_to_viewport

    @property
    def pos_to_window(self):
        return self.invisible.pos_to_window

    @property
    def pos_to_parent(self):
        return self.invisible.pos_to_parent

    @property
    def rect_size(self):
        return self.invisible.rect_size

    @property
    def resized(self):
        return self.invisible.resized

    @property
    def no_input(self):
        """
        Disable taking user inputs
        """
        return self.invisible.no_input

    @no_input.setter
    def no_input(self, value):
        self.invisible.no_input = value

    @property
    def capture_mouse(self):
        """See DrawInvisibleButton for a detailed description"""
        return self.invisible.capture_mouse

    @capture_mouse.setter
    def capture_mouse(self, value):
        self.invisible.capture_mouse = value

    @property
    def handlers(self):
        return self.invisible.handlers

    @handlers.setter
    def handlers(self, value):
        self.invisible.handlers = value