import dearcygui as dcg

class DragPoint(dcg.DrawingList):
    """A draggable point represented as a circle.
    
    This drawing element can be dragged by the user and will report its position.
    It provides hover and drag callbacks for interactive behavior.
    It can optionally be constrained to stay within plot boundaries when clamping
    is enabled.
    """
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
        """Setup the handlers that respond to user interaction.
        
        Creates and attaches handlers for hover, drag, and cursor appearance.
        This is called during initialization before the element is attached
        to the parent tree.
        """
        # Note: Since this is done before configure,
        # we are not in the parent tree yet
        # and do not need the mutex
        set_cursor_on_hover = dcg.ConditionalHandler(self.context)
        with set_cursor_on_hover:
            dcg.MouseCursorHandler(self.context, cursor=dcg.MouseCursor.RESIZE_ALL)
            dcg.HoverHandler(self.context)
        self.invisible.handlers += [
            dcg.HoverHandler(self.context, callback=self.handler_hover),
            dcg.DraggingHandler(self.context, callback=self.handler_dragging),
            dcg.DraggedHandler(self.context, callback=self.handler_dragged),
            set_cursor_on_hover
        ]

    @property
    def radius(self):
        """Radius of the draggable point.
        
        Controls both the visual circle size and the interactive hit area.
        """
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
        """X coordinate in screen space.
        
        The horizontal position of the point.
        """
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
        """Y coordinate in screen space.
        
        The vertical position of the point.
        """
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
        """Controls whether the point is constrained to remain inside the plot area.
        
        When enabled, the point will be automatically repositioned if it would
        otherwise fall outside the plot's visible boundaries.
        """
        with self.mutex:
            return self._clamp_inside

    @clamp_inside.setter
    def clamp_inside(self, value):
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
        """Color of the displayed circle.
        
        The fill color for the draggable point, specified as an RGBA tuple.
        """
        with self.mutex:
            return self.visible.fill

    @color.setter
    def color(self, value):
        with self.mutex:
            self.visible.fill = value

    @property
    def on_hover(self):
        """Callback triggered when the point is hovered by the cursor.
        
        This callback is invoked whenever the mouse cursor hovers over the
        draggable point.
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
        """Callback triggered during active dragging.
        
        This callback is continuously invoked while the user is dragging the
        point, allowing real-time tracking of position changes.
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
        """Callback triggered when a drag operation completes.
        
        This callback is invoked once when the user releases the point after
        dragging it, signaling the completion of a position change.
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
    def state(self) -> dcg.ItemStateView:
        """The current state of the point
        
        The state is an instance of ItemStateView which is a class
        with property getters to retrieve various readonly states.

        The ItemStateView instance is just a view over the current states,
        not a copy, thus the states get updated automatically.
        """
        return self.invisible.state

    @property
    def no_input(self):
        """Whether user input is disabled for the point.
        
        When set to True, the point will not respond to mouse interaction.
        """
        return self.invisible.no_input

    @no_input.setter
    def no_input(self, value):
        self.invisible.no_input = value

    @property
    def capture_mouse(self):
        """Whether the point captures mouse events.
        
        This forces the point to catch the mouse if
        it is in front of the points, even if another
        element was being dragged.

        This defaults to True, and resets to False
        every frame.
        """
        return self.invisible.capture_mouse

    @capture_mouse.setter
    def capture_mouse(self, value):
        self.invisible.capture_mouse = value

    @property
    def handlers(self):
        """The event handlers attached to this point.
        
        Collection of handlers that process events for this draggable point.
        """
        return self.invisible.handlers

    @handlers.setter
    def handlers(self, value):
        self.invisible.handlers = value