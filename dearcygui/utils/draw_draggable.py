import dearcygui as dcg
import weakref

class DragPoint(dcg.DrawingList):
    """A draggable point represented as a circle.
    
    This drawing element can be dragged by the user and will report its position.
    It provides hover and drag callbacks for interactive behavior.
    It can optionally be constrained to stay within plot boundaries when clamping
    is enabled.
    """
    __handlers_ref: weakref.ReferenceType[dcg.baseHandler] | None = None
    def __init__(self, context : dcg.Context, *args, **kwargs) -> None:
        # Create the drawing elements
        with self:
            self._invisible = dcg.DrawInvisibleButton(context)
            self._visible = dcg.DrawCircle(context)
        # Set default parameters
        self._radius = 4.
        kwargs.setdefault("radius", self._radius)
        self._color = (0, 255, 0, 255)
        kwargs.setdefault("color", self._color)
        self._visible.color = 0 # Invisible outline
        self._backup_x = 0.0
        self._backup_y = 0.0
        self._on_hover = None
        self._on_dragged = None
        self._on_dragging = None
        self._clamp_inside = False
        self._was_dragging = False
        self._handlers = DragPoint._get_handlers(context)
        # We do in a separate function to allow
        # subclasses to override the callbacks
        self.setup_callbacks()
        # Configure
        super().__init__(context, *args, **kwargs)

    @classmethod
    def _get_handlers(cls, context: dcg.Context) -> dcg.baseHandler:
        """Get or create handlers for DragPoint instances.
        
        While it is perfectly fine to recreate new
        handlers for each instance, we demonstrate here
        a better practice for performance:
        reusing the same handlers for all instances.

        This will impact performance positively
        when creating a huge number of draggable points,
        in which case you will notice:
        - Reduced memory usage, as handlers are shared
        - Faster DragPoint creation, as handlers are not recreated
        - Faster Python garbage collection, as fewer objects are managed

        We use a weakref to automatically release the handlers
        when the last DragPoint is released.
        """
        # Check if we have valid shared handlers
        if cls.__handlers_ref is not None:
            handlers = cls.__handlers_ref()
            if handlers is not None and handlers.context == context:
                return handlers
        
        # Create new shared handlers
        handlers = dcg.HandlerList(context)
        with handlers:
            dcg.HoverHandler(context, callback=cls.handler_hover)
            dcg.DraggingHandler(context, callback=cls.handler_dragging)
            dcg.DraggedHandler(context, callback=cls.handler_dragged)
            # Conditional handler for cursor change
            set_cursor_on_hover = dcg.ConditionalHandler(context)
            with set_cursor_on_hover:
                dcg.MouseCursorHandler(context, cursor=dcg.MouseCursor.RESIZE_ALL)
                dcg.HoverHandler(context)
        
        # Store as weak reference
        cls.__handlers_ref = weakref.ref(handlers)
        return handlers

    def setup_callbacks(self) -> None:
        """Setup the handlers that respond to user interaction.
        
        Creates and attaches handlers for hover, drag, and cursor appearance.
        This is called during initialization before the element is attached
        to the parent tree.
        """
        # Note: Since this is done before configure,
        # we are not in the parent tree yet
        # and do not need the mutex
        self._invisible.handlers += [self._handlers]

    @property
    def radius(self) -> float:
        """Radius of the draggable point.
        
        Controls both the visual circle size and the interactive hit area.
        """
        with self.mutex:
            return self._radius

    @radius.setter
    def radius(self, value: float) -> None:
        with self.mutex:
            self._radius: float = value
            # We rely solely on min_side to make a
            # point with desired screen space size,
            # thus why we set p1 = p2
            self._invisible.min_side = value * 2.
            # Negative value to not rescale
            self._visible.radius = -value

    @property
    def x(self) -> float:
        """X coordinate in screen space.
        
        The horizontal position of the point.
        """
        with self.mutex:
            return self._invisible.p1[0]

    @x.setter
    def x(self, value: float) -> None:
        with self.mutex:
            y: float = self._invisible.p1[1]
            self._invisible.p1 = [value, y]
            self._invisible.p2 = [value, y]
            self._visible.center = [value, y]

    @property
    def y(self) -> float:
        """Y coordinate in screen space.
        
        The vertical position of the point.
        """
        with self.mutex:
            return self._invisible.p1[1]

    @y.setter
    def y(self, value: float) -> None:
        with self.mutex:
            x: float = self._invisible.p1[0]
            self._invisible.p1 = [x, value]
            self._invisible.p2 = [x, value]
            self._visible.center = [x, value]

    @property
    def clamp_inside(self) -> bool:
        """Controls whether the point is constrained to remain inside the plot area.
        
        When enabled, the point will be automatically repositioned if it would
        otherwise fall outside the plot's visible boundaries.
        """
        with self.mutex:
            return self._clamp_inside

    @clamp_inside.setter
    def clamp_inside(self, value: bool) -> None:
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
                assert plot_element is not None, "item not attached to the rendering tree"
                plot_element = plot_element.parent
            self.axes = plot_element.axes
            plot = plot_element.parent
            assert plot is not None, "item not attached to the rendering tree"
            if self._clamp_inside:
                plot.handlers += [
                    dcg.RenderHandler(self.context,
                                       callback=self.handler_visible_for_clamping)
                ]
            else:
                plot.handlers = [h for h in plot.handlers if h is not self.handler_visible_for_clamping]

    @property
    def color(self):
        """Color of the displayed circle.
        
        The fill color for the draggable point, specified as an RGBA tuple.
        """
        with self.mutex:
            return self._visible.fill

    @color.setter
    def color(self, value) -> None:
        with self.mutex:
            self._visible.fill = value

    @property
    def on_hover(self) -> None | dcg.Callback:
        """Callback triggered when the point is hovered by the cursor.
        
        This callback is invoked whenever the mouse cursor hovers over the
        draggable point.
        """
        with self.mutex:
            return self._on_hover

    @on_hover.setter
    def on_hover(self, value: 'None | dcg.DCGCallable') -> None:
        with self.mutex:
            self._on_hover = value if value is None or \
                                isinstance(value, dcg.Callback) else \
                                dcg.Callback(value)

    @property
    def on_dragging(self) -> None | dcg.Callback:
        """Callback triggered during active dragging.
        
        This callback is continuously invoked while the user is dragging the
        point, allowing real-time tracking of position changes.
        """
        with self.mutex:
            return self._on_dragging

    @on_dragging.setter
    def on_dragging(self, value: 'None | dcg.DCGCallable') -> None:
        with self.mutex:
            self._on_dragging = value if value is None or \
                                isinstance(value, dcg.Callback) else \
                                dcg.Callback(value)

    @property
    def on_dragged(self) -> None | dcg.Callback:
        """Callback triggered when a drag operation completes.
        
        This callback is invoked once when the user releases the point after
        dragging it, signaling the completion of a position change.
        """
        with self.mutex:
            return self._on_dragged

    @on_dragged.setter
    def on_dragged(self, value: 'None | dcg.DCGCallable') -> None:
        with self.mutex:
            self._on_dragged = value if value is None or \
                               isinstance(value, dcg.Callback) else \
                               dcg.Callback(value)

    # We use classmethods to enable sharing the handlers

    @classmethod
    def handler_dragging(cls, _, target: dcg.DrawInvisibleButton, drag_deltas: tuple[float, float]) -> None:
        # During the dragging we might not hover anymore the button
        # Note: we must not lock our mutex before we access viewport
        # attributes
        self: DragPoint = target.parent # type: ignore
        if self is None:
            # deleted before we could handle drag
            return
        with self.mutex:
            # backup coordinates before dragging
            if not(self._was_dragging):
                self._backup_x = self.x
                self._backup_y = self.y
                self._was_dragging = True
            # update the coordinates
            self.x = self._backup_x + drag_deltas[0]
            self.y = self._backup_y + drag_deltas[1]
            _on_dragging = self._on_dragging
        self.context.viewport.wake() # The screen must be redrawn
        # Release our mutex before calling the callback
        if _on_dragging is not None:
            _on_dragging(self, self, (self.x, self.y))

    @classmethod
    def handler_dragged(cls, _, target: dcg.DrawInvisibleButton, drag_deltas: tuple[float, float]) -> None:
        self: DragPoint = target.parent # type: ignore
        if self is None:
            # deleted before we could handle drag
            return
        with self.mutex:
            self._was_dragging = False
            # update the coordinates
            self.x = self._backup_x + drag_deltas[0]
            self.y = self._backup_y + drag_deltas[1]
            _on_dragged = self._on_dragged
        self.context.viewport.wake() # The screen must be redrawn
        if _on_dragged is not None:
            _on_dragged(self, self, (self.x, self.y))

    @classmethod
    def handler_hover(cls, _, target: dcg.DrawInvisibleButton) -> None:
        self: DragPoint = target.parent # type: ignore
        if self is None:
            # deleted before we could handle hover
            return
        with self.mutex:
            _on_hover = self._on_hover
        if _on_hover is not None:
            _on_hover(self, self, None)

    def handler_visible_for_clamping(self, handler, plot : dcg.Plot) -> None:
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
        return self._invisible.state

    @property
    def no_input(self) -> bool:
        """Whether user input is disabled for the point.
        
        When set to True, the point will not respond to mouse interaction.
        """
        return self._invisible.no_input

    @no_input.setter
    def no_input(self, value: bool) -> None:
        self._invisible.no_input = value

    @property
    def capture_mouse(self) -> bool:
        """Whether the point captures mouse events.
        
        This forces the point to catch the mouse if
        it is in front of the points, even if another
        element was being dragged.

        This defaults to True, and resets to False
        every frame.
        """
        return self._invisible.capture_mouse

    @capture_mouse.setter
    def capture_mouse(self, value: bool) -> None:
        self._invisible.capture_mouse = value

    @property
    def handlers(self) -> list[dcg.baseHandler]:
        """The event handlers attached to this point.
        
        Collection of handlers that process events for this draggable point.
        """
        # hide our handler
        return [handler for handler in self._invisible.handlers if handler is not self._handlers]

    @handlers.setter
    def handlers(self, value) -> None:
        self._invisible.handlers = value
        # add back our handler
        # we do let self.invisible treat value
        # to convert it to list if needed
        self._invisible.handlers = [self._handlers] + self._invisible.handlers



class DragHLine(dcg.DrawingList):
    """A draggable horizontal line that spans infinitely across the plot.
    
    This drawing element represents an infinite horizontal line that can be dragged
    vertically by the user. It uses screen space rendering (negative thickness) to
    maintain consistent visual appearance regardless of zoom level.
    
    The line provides hover and drag callbacks for interactive behavior and can
    optionally be constrained to stay within plot boundaries when clamping is enabled.
    """
    __handlers_ref: weakref.ReferenceType[dcg.baseHandler] | None = None
    
    def __init__(self, context: dcg.Context, *args, **kwargs) -> None:
        # Create the drawing elements
        with self:
            self._invisible = dcg.DrawInvisibleButton(context)
            self._visible = dcg.DrawLine(context)
        
        # Set default parameters
        self._y = 0.0
        self._thickness = -2.0  # Negative for screen space
        self._color = (255, 255, 0, 255)  # Yellow by default
        kwargs.setdefault("color", self._color)
        self._button_height = 5.0  # Height of the invisible button area
        self._backup_y = 0.0
        self._on_hover = None
        self._on_dragged = None
        self._on_dragging = None
        self._clamp_inside = False
        self._was_dragging = False
        self._handlers = DragHLine._get_handlers(context)
        
        # Setup callbacks
        self.setup_callbacks()
        
        # Initialize line position
        self._update_line_geometry()

        super().__init__(context, *args, **kwargs)

    @classmethod
    def _get_handlers(cls, context: dcg.Context) -> dcg.baseHandler:
        """Get or create handlers for DragHLine instances.
        
        Reuses the same pattern as DragPoint for performance optimization.
        """
        # Check if we have valid shared handlers
        if cls.__handlers_ref is not None:
            handlers = cls.__handlers_ref()
            if handlers is not None and handlers.context == context:
                return handlers
        
        # Create new shared handlers
        handlers = dcg.HandlerList(context)
        with handlers:
            dcg.HoverHandler(context, callback=cls.handler_hover)
            dcg.DraggingHandler(context, callback=cls.handler_dragging)
            dcg.DraggedHandler(context, callback=cls.handler_dragged)
            # Conditional handler for cursor change
            set_cursor_on_hover = dcg.ConditionalHandler(context)
            with set_cursor_on_hover:
                dcg.MouseCursorHandler(context, cursor=dcg.MouseCursor.RESIZE_NS)
                dcg.HoverHandler(context)
        
        # Store as weak reference
        cls.__handlers_ref = weakref.ref(handlers)
        return handlers

    def setup_callbacks(self) -> None:
        """Setup the handlers that respond to user interaction."""
        self._invisible.handlers += [self._handlers]

    def _update_line_geometry(self) -> None:
        """Update the line and button geometry based on current position."""
        # Get plot bounds for infinite line (we'll use a large range)
        line_extend = 1e6  # Large number for "infinite" appearance
        
        # Update the visible line
        self._visible.direction = 0  # Horizontal line
        self._visible.center = [0, self.y]
        self._visible.length = -line_extend
        self._visible.thickness = self._thickness
        
        # Update the invisible button (centered on the line)
        self._invisible.p1 = [-line_extend, self.y]
        self._invisible.p2 = [line_extend, self.y]
        self._invisible.min_side = self._button_height

    @property
    def y(self) -> float:
        """Y coordinate of the horizontal line."""
        with self.mutex:
            return self._y

    @y.setter
    def y(self, value: float) -> None:
        with self.mutex:
            self._y = float(value)
            self._update_line_geometry()

    @property
    def thickness(self) -> float:
        """Thickness of the line. Negative values use screen space."""
        with self.mutex:
            return self._thickness

    @thickness.setter
    def thickness(self, value: float) -> None:
        with self.mutex:
            self._thickness = float(value)
            self._visible.thickness = self._thickness

    @property
    def color(self):
        """Color of the horizontal line."""
        with self.mutex:
            return self._visible.color

    @color.setter
    def color(self, value) -> None:
        with self.mutex:
            self._visible.color = value

    @property
    def button_height(self) -> float:
        """Height of the invisible button area for interaction."""
        with self.mutex:
            return self._button_height

    @button_height.setter
    def button_height(self, value: float) -> None:
        with self.mutex:
            self._button_height = float(value)
            self._update_line_geometry()

    @property
    def clamp_inside(self) -> bool:
        """Controls whether the line is constrained to remain inside the plot area."""
        with self.mutex:
            return self._clamp_inside

    @clamp_inside.setter
    def clamp_inside(self, value: bool) -> None:
        with self.parents_mutex:
            if self._clamp_inside == bool(value):
                return
            self._clamp_inside = bool(value)
            plot_element = self.parent
            while not(isinstance(plot_element, dcg.plotElement)):
                if isinstance(plot_element, dcg.Viewport):
                    # We reached the top parent without finding a plotElement
                    raise ValueError("clamp_inside requires to be in a plot")
                assert plot_element is not None, "item not attached to the rendering tree"
                plot_element = plot_element.parent
            self.axes = plot_element.axes
            plot = plot_element.parent
            assert plot is not None, "item not attached to the rendering tree"
            if self._clamp_inside:
                plot.handlers += [
                    dcg.RenderHandler(self.context,
                                       callback=self.handler_visible_for_clamping)
                ]
            else:
                plot.handlers = [h for h in plot.handlers if h is not self.handler_visible_for_clamping]

    @property
    def on_hover(self) -> None | dcg.Callback:
        """Callback triggered when the line is hovered by the cursor."""
        with self.mutex:
            return self._on_hover

    @on_hover.setter
    def on_hover(self, value: 'None | dcg.DCGCallable') -> None:
        with self.mutex:
            self._on_hover = value if value is None or \
                                isinstance(value, dcg.Callback) else \
                                dcg.Callback(value)

    @property
    def on_dragging(self) -> None | dcg.Callback:
        """Callback triggered during active dragging."""
        with self.mutex:
            return self._on_dragging

    @on_dragging.setter
    def on_dragging(self, value: 'None | dcg.DCGCallable') -> None:
        with self.mutex:
            self._on_dragging = value if value is None or \
                                isinstance(value, dcg.Callback) else \
                                dcg.Callback(value)

    @property
    def on_dragged(self) -> None | dcg.Callback:
        """Callback triggered when a drag operation completes."""
        with self.mutex:
            return self._on_dragged

    @on_dragged.setter
    def on_dragged(self, value: 'None | dcg.DCGCallable') -> None:
        with self.mutex:
            self._on_dragged = value if value is None or \
                               isinstance(value, dcg.Callback) else \
                               dcg.Callback(value)

    # Class methods for shared handlers
    @classmethod
    def handler_dragging(cls, _, target: dcg.DrawInvisibleButton, drag_deltas: tuple[float, float]) -> None:
        """Handler for dragging events - only allows vertical movement."""
        self: DragHLine = target.parent # type: ignore
        if self is None:
            # deleted before we could handle drag
            return
        with self.mutex:
            # backup coordinates before dragging
            if not(self._was_dragging):
                self._backup_y = self.y
                self._was_dragging = True
            # update the y coordinate (only vertical movement)
            self.y = self._backup_y + drag_deltas[1]
            _on_dragging = self._on_dragging
        self.context.viewport.wake()
        # Release mutex before calling callback
        if _on_dragging is not None:
            _on_dragging(self, self, self.y)

    @classmethod
    def handler_dragged(cls, _, target: dcg.DrawInvisibleButton, drag_deltas: tuple[float, float]) -> None:
        """Handler for drag completion events."""
        self: DragHLine = target.parent # type: ignore
        if self is None:
            # deleted before we could handle drag
            return
        with self.mutex:
            self._was_dragging = False
            # update the final y coordinate
            self.y = self._backup_y + drag_deltas[1]
            _on_dragged = self._on_dragged
        self.context.viewport.wake()
        if _on_dragged is not None:
            _on_dragged(self, self, self.y)

    @classmethod
    def handler_hover(cls, _, target: dcg.DrawInvisibleButton) -> None:
        """Handler for hover events."""
        self: DragHLine = target.parent # type: ignore
        if self is None:
            # deleted before we could handle hover
            return
        with self.mutex:
            _on_hover = self._on_hover
        if _on_hover is not None:
            _on_hover(self, self, None)

    def handler_visible_for_clamping(self, handler, plot: dcg.Plot) -> None:
        """Handler for clamping the line inside plot bounds."""
        with plot.mutex:
            with self.mutex:
                y_axis = plot.axes[self.axes[1]]
                my = y_axis.min
                My = y_axis.max
                if self.y < my:
                    self.y = my
                if self.y > My:
                    self.y = My

    # Redirect button state queries to the invisible button
    @property
    def state(self) -> dcg.ItemStateView:
        """The current state of the line interaction area."""
        return self._invisible.state

    @property
    def no_input(self) -> bool:
        """Whether user input is disabled for the line."""
        return self._invisible.no_input

    @no_input.setter
    def no_input(self, value: bool) -> None:
        self._invisible.no_input = value

    @property
    def capture_mouse(self) -> bool:
        """Whether the line captures mouse events."""
        return self._invisible.capture_mouse

    @capture_mouse.setter
    def capture_mouse(self, value: bool) -> None:
        self._invisible.capture_mouse = value

    @property
    def handlers(self) -> list[dcg.baseHandler]:
        """The event handlers attached to this line."""
        # Hide our internal handler
        return [handler for handler in self._invisible.handlers if handler is not self._handlers]

    @handlers.setter
    def handlers(self, value) -> None:
        self._invisible.handlers = value
        # Add back our internal handler
        self._invisible.handlers = [self._handlers] + self._invisible.handlers


class DragVLine(dcg.DrawingList):
    """A draggable vertical line that spans infinitely across the plot.
    
    This drawing element represents an infinite vertical line that can be dragged
    horizontally by the user. It uses screen space rendering (negative thickness) to
    maintain consistent visual appearance regardless of zoom level.
    
    The line provides hover and drag callbacks for interactive behavior and can
    optionally be constrained to stay within plot boundaries when clamping is enabled.
    """
    __handlers_ref: weakref.ReferenceType[dcg.baseHandler] | None = None
    
    def __init__(self, context: dcg.Context, *args, **kwargs) -> None:
        # Create the drawing elements
        with self:
            self._invisible = dcg.DrawInvisibleButton(context, )
            self._visible = dcg.DrawLine(context)
        
        # Set default parameters
        self._x = 0.0
        self._thickness = -2.0  # Negative for screen space
        self._color = (255, 0, 255, 255)  # Magenta by default
        kwargs.setdefault("color", self._color)
        self._button_width = 5.0  # Width of the invisible button area
        self._backup_x = 0.0
        self._on_hover = None
        self._on_dragged = None
        self._on_dragging = None
        self._clamp_inside = False
        self._was_dragging = False
        self._handlers = DragVLine._get_handlers(context)
        
        # Setup callbacks
        self.setup_callbacks()
        
        # Initialize line position
        self._update_line_geometry()

        super().__init__(context, *args, **kwargs)

    @classmethod
    def _get_handlers(cls, context) -> dcg.baseHandler:
        """Get or create handlers for DragVLine instances.
        
        Reuses the same pattern as DragPoint for performance optimization.
        """
        # Check if we have valid shared handlers
        if cls.__handlers_ref is not None:
            handlers = cls.__handlers_ref()
            if handlers is not None and handlers.context == context:
                return handlers
        
        # Create new shared handlers
        handlers = dcg.HandlerList(context)
        with handlers:
            dcg.HoverHandler(context, callback=cls.handler_hover)
            dcg.DraggingHandler(context, callback=cls.handler_dragging)
            dcg.DraggedHandler(context, callback=cls.handler_dragged)
            # Conditional handler for cursor change
            set_cursor_on_hover = dcg.ConditionalHandler(context)
            with set_cursor_on_hover:
                dcg.MouseCursorHandler(context, cursor=dcg.MouseCursor.RESIZE_EW)
                dcg.HoverHandler(context)
        
        # Store as weak reference
        cls.__handlers_ref = weakref.ref(handlers)
        return handlers

    def setup_callbacks(self) -> None:
        """Setup the handlers that respond to user interaction."""
        self._invisible.handlers += [self._handlers]

    def _update_line_geometry(self) -> None:
        """Update the line and button geometry based on current position."""
        # Get plot bounds for infinite line (we'll use a large range)
        line_extend = 1e6  # Large number for "infinite" appearance
        
        # Update the visible line (vertical: 90 degrees = π/2 radians)
        self._visible.direction = 1.5707963267948966  # π/2 radians (90 degrees)
        self._visible.center = [self.x, 0]
        self._visible.length = -line_extend
        self._visible.thickness = self._thickness
        
        # Update the invisible button (centered on the line)
        self._invisible.p1 = [self.x, -line_extend]
        self._invisible.p2 = [self.x, line_extend]
        self._invisible.min_side = self._button_width

    @property
    def x(self) -> float:
        """X coordinate of the vertical line."""
        with self.mutex:
            return self._x

    @x.setter
    def x(self, value: float) -> None:
        with self.mutex:
            self._x = float(value)
            self._update_line_geometry()

    @property
    def thickness(self) -> float:
        """Thickness of the line. Negative values use screen space."""
        with self.mutex:
            return self._thickness

    @thickness.setter
    def thickness(self, value: float) -> None:
        with self.mutex:
            self._thickness = float(value)
            self._visible.thickness = self._thickness

    @property
    def color(self):
        """Color of the vertical line."""
        with self.mutex:
            return self._visible.color

    @color.setter
    def color(self, value) -> None:
        with self.mutex:
            self._visible.color = value

    @property
    def button_width(self) -> float:
        """Width of the invisible button area for interaction."""
        with self.mutex:
            return self._button_width

    @button_width.setter
    def button_width(self, value: float) -> None:
        with self.mutex:
            self._button_width = float(value)
            self._update_line_geometry()

    @property
    def clamp_inside(self) -> bool:
        """Controls whether the line is constrained to remain inside the plot area."""
        with self.mutex:
            return self._clamp_inside

    @clamp_inside.setter
    def clamp_inside(self, value: bool) -> None:
        with self.parents_mutex:
            if self._clamp_inside == bool(value):
                return
            self._clamp_inside = bool(value)
            plot_element = self.parent
            while not(isinstance(plot_element, dcg.plotElement)):
                if isinstance(plot_element, dcg.Viewport):
                    # We reached the top parent without finding a plotElement
                    raise ValueError("clamp_inside requires to be in a plot")
                assert plot_element is not None, "item not attached to the rendering tree"
                plot_element = plot_element.parent
            self.axes = plot_element.axes
            plot = plot_element.parent
            assert plot is not None, "item not attached to the rendering tree"
            if self._clamp_inside:
                plot.handlers += [
                    dcg.RenderHandler(self.context,
                                       callback=self.handler_visible_for_clamping)
                ]
            else:
                plot.handlers = [h for h in plot.handlers if h is not self.handler_visible_for_clamping]

    @property
    def on_hover(self) -> None | dcg.Callback:
        """Callback triggered when the line is hovered by the cursor."""
        with self.mutex:
            return self._on_hover

    @on_hover.setter
    def on_hover(self, value: 'None | dcg.DCGCallable') -> None:
        with self.mutex:
            self._on_hover = value if value is None or \
                                isinstance(value, dcg.Callback) else \
                                dcg.Callback(value)

    @property
    def on_dragging(self) -> None | dcg.Callback:
        """Callback triggered during active dragging."""
        with self.mutex:
            return self._on_dragging

    @on_dragging.setter
    def on_dragging(self, value: 'None | dcg.DCGCallable') -> None:
        with self.mutex:
            self._on_dragging = value if value is None or \
                                isinstance(value, dcg.Callback) else \
                                dcg.Callback(value)

    @property
    def on_dragged(self) -> None | dcg.Callback:
        """Callback triggered when a drag operation completes."""
        with self.mutex:
            return self._on_dragged

    @on_dragged.setter
    def on_dragged(self, value: 'None | dcg.DCGCallable') -> None:
        with self.mutex:
            self._on_dragged = value if value is None or \
                               isinstance(value, dcg.Callback) else \
                               dcg.Callback(value)

    # Class methods for shared handlers
    @classmethod
    def handler_dragging(cls, _, target: dcg.DrawInvisibleButton, drag_deltas: tuple[float, float]) -> None:
        """Handler for dragging events - only allows horizontal movement."""
        self: DragVLine = target.parent # type: ignore
        if self is None:
            # deleted before we could handle drag
            return
        with self.mutex:
            # backup coordinates before dragging
            if not(self._was_dragging):
                self._backup_x = self.x
                self._was_dragging = True
            # update the x coordinate (only horizontal movement)
            self.x = self._backup_x + drag_deltas[0]
            _on_dragging = self._on_dragging
        self.context.viewport.wake()
        # Release mutex before calling callback
        if _on_dragging is not None:
            _on_dragging(self, self, self.x)

    @classmethod
    def handler_dragged(cls, _, target: dcg.DrawInvisibleButton, drag_deltas: tuple[float, float]) -> None:
        """Handler for drag completion events."""
        self: DragVLine = target.parent # type: ignore
        if self is None:
            # deleted before we could handle drag
            return
        with self.mutex:
            self._was_dragging = False
            # update the final x coordinate
            self.x = self._backup_x + drag_deltas[0]
            _on_dragged = self._on_dragged
        self.context.viewport.wake()
        if _on_dragged is not None:
            _on_dragged(self, self, self.x)

    @classmethod
    def handler_hover(cls, _, target: dcg.DrawInvisibleButton) -> None:
        """Handler for hover events."""
        self: DragVLine = target.parent # type: ignore
        if self is None:
            # deleted before we could handle hover
            return
        with self.mutex:
            _on_hover = self._on_hover
        if _on_hover is not None:
            _on_hover(self, self, None)

    def handler_visible_for_clamping(self, handler, plot: dcg.Plot) -> None:
        """Handler for clamping the line inside plot bounds."""
        with plot.mutex:
            with self.mutex:
                x_axis = plot.axes[self.axes[0]]
                mx = x_axis.min
                Mx = x_axis.max
                if self.x < mx:
                    self.x = mx
                if self.x > Mx:
                    self.x = Mx

    # Redirect button state queries to the invisible button
    @property
    def state(self) -> dcg.ItemStateView:
        """The current state of the line interaction area."""
        return self._invisible.state

    @property
    def no_input(self) -> bool:
        """Whether user input is disabled for the line."""
        return self._invisible.no_input

    @no_input.setter
    def no_input(self, value: bool) -> None:
        self._invisible.no_input = value

    @property
    def capture_mouse(self) -> bool:
        """Whether the line captures mouse events."""
        return self._invisible.capture_mouse

    @capture_mouse.setter
    def capture_mouse(self, value: bool) -> None:
        self._invisible.capture_mouse = value

    @property
    def handlers(self) -> list[dcg.baseHandler]:
        """The event handlers attached to this line."""
        # Hide our internal handler
        return [handler for handler in self._invisible.handlers if handler is not self._handlers]

    @handlers.setter
    def handlers(self, value) -> None:
        self._invisible.handlers = value
        # Add back our internal handler
        self._invisible.handlers = [self._handlers] + self._invisible.handlers


class DragRect(dcg.DrawingList):
    """A draggable and resizable rectangle.
    
    This drawing element represents a rectangle that can be dragged by its center
    or resized by dragging its edges and corners. It uses 9 invisible buttons for
    interaction: 4 corner buttons, 4 edge buttons, and 1 center button.
    
    The rectangle provides hover and drag callbacks for interactive behavior and can
    optionally be constrained to stay within plot boundaries when clamping is enabled.
    """
    __handlers_ref: list[weakref.ReferenceType[dcg.baseHandler]] | None = None
    
    def __init__(self, context: dcg.Context, *args, **kwargs) -> None:
        # Create the drawing elements
        with self:
            # Create the visible rectangle and diagonal lines
            self._visible_rect = dcg.DrawRect(context)
            self._diagonal1 = dcg.DrawLine(context, show=False)  # Top-left to bottom-right
            self._diagonal2 = dcg.DrawLine(context, show=False)  # Top-right to bottom-left
            
            # Create 9 invisible buttons for interaction
            # The order in the child tree matters for grab priority

            # Center button for moving the entire rectangle
            self._center_button = dcg.DrawInvisibleButton(context)

            # Edge buttons
            self._edge_top = dcg.DrawInvisibleButton(context)    # Top edge
            self._edge_bottom = dcg.DrawInvisibleButton(context) # Bottom edge
            self._edge_left = dcg.DrawInvisibleButton(context)   # Left edge
            self._edge_right = dcg.DrawInvisibleButton(context)  # Right edge

            # Corner buttons (these will naturally take priority due to render order)
            self._corner_tl = dcg.DrawInvisibleButton(context)  # Top-left
            self._corner_tr = dcg.DrawInvisibleButton(context)  # Top-right
            self._corner_bl = dcg.DrawInvisibleButton(context)  # Bottom-left
            self._corner_br = dcg.DrawInvisibleButton(context)  # Bottom-right
        
        # Set default parameters
        self._rect = dcg.Rect(0, 0, 100, 100)
        self._backup_rect = self._rect
        self._thickness = -2.0  # Negative for screen space
        self._color = (255, 255, 255, 255)  # White by default
        kwargs.setdefault("color", self._color)
        self._fill = (0, 0, 0, 0)  # Transparent fill by default
        self._grab_thickness = 5.0  # Thickness of grab areas
        self._on_hover = None
        self._on_dragged = None
        self._on_dragging = None
        self._clamp_inside = False
        self._was_dragging = False
        self._hover_count = 0
        self._drag_type = "unknown"
        self._handlers = DragRect._get_handlers(context)
        
        # Setup callbacks
        self.setup_callbacks()
        
        # Initialize rectangle geometry
        self._update_rect_geometry()

        super().__init__(context, *args, **kwargs)

    @classmethod
    def _get_handlers(cls, context: dcg.Context) -> list[dcg.baseHandler]:
        """Get or create handlers for DragRect instances."""
        # Check if we have valid shared handlers
        if cls.__handlers_ref is not None:
            handlers = cls.__handlers_ref
            if handlers is not None:
                handlers = []
                for handler_ref in cls.__handlers_ref:
                    handler = handler_ref()
                    if handler is not None:
                        handlers.append(handler)
                if handlers and len(handlers) == 9 \
                    and handlers[0].context == context:
                    return handlers
        
        # Create new shared handlers
        handlers = []
        for i in range(9):
            handler = dcg.HandlerList(context)
            with handler:
                # Hover handlers
                dcg.HoverHandler(context, callback=cls.handler_hover)
                dcg.GotHoverHandler(context, callback=cls.handler_got_hover)
                dcg.LostHoverHandler(context, callback=cls.handler_lost_hover)
                
                # Drag handlers
                dcg.DraggingHandler(context, callback=cls.handler_dragging)
                dcg.DraggedHandler(context, callback=cls.handler_dragged)
                
                # Conditional handler for cursor changes
                cursor_on_hover = dcg.ConditionalHandler(context)
                with cursor_on_hover:
                    if i == 0:  # center
                        cursor = dcg.MouseCursor.RESIZE_ALL
                    elif i in (1, 2, 3, 4):  # edges
                        cursor = dcg.MouseCursor.RESIZE_NS if i <= 2 else dcg.MouseCursor.RESIZE_EW
                    else:  # corners
                        cursor = dcg.MouseCursor.RESIZE_NESW if i == 5 else \
                                dcg.MouseCursor.RESIZE_NWSE if i == 6 else \
                                dcg.MouseCursor.RESIZE_NWSE if i == 7 else \
                                dcg.MouseCursor.RESIZE_NESW

                    dcg.MouseCursorHandler(context, cursor=cursor)
                    dcg.HoverHandler(context)
            handlers.append(handler)
        
        # Store as weak references
        cls.__handlers_ref = [weakref.ref(handler) for handler in handlers]
        return handlers

    def setup_callbacks(self) -> None:
        """Setup the handlers that respond to user interaction."""
        # Attach handlers to all invisible buttons
        buttons: list[dcg.DrawInvisibleButton] = [
            self._center_button,
            self._edge_top, self._edge_bottom, self._edge_left, self._edge_right,
            self._corner_tl, self._corner_tr, self._corner_bl, self._corner_br,
        ]
        
        for button, handler in zip(buttons, self._handlers):
            button.handlers += [handler]

    def _update_rect_geometry(self) -> None:
        """Update the rectangle and button geometry based on current position."""
        # Update the visible rectangle
        self._visible_rect.pmin = self._rect.p1
        self._visible_rect.pmax = self._rect.p2
        self._visible_rect.thickness = self._thickness
        self._visible_rect.color = self.color
        self._visible_rect.fill = self.fill
        
        # Update diagonal lines
        self._diagonal1.p1 = self._rect.p1
        self._diagonal1.p2 = self._rect.p2
        self._diagonal1.thickness = self._thickness
        self._diagonal1.color = self.color
        
        self._diagonal2.p1 = (self._rect.x2, self._rect.y1)
        self._diagonal2.p2 = (self._rect.x1, self._rect.y2)
        self._diagonal2.thickness = self._thickness
        self._diagonal2.color = self.color
        
        # Update invisible button positions and sizes
        
        # Corner buttons
        self._corner_tl.p1 = self._rect.p1
        self._corner_tl.p2 = self._rect.p1
        self._corner_tl.min_side = self._grab_thickness
        
        self._corner_tr.p1 = (self._rect.x2, self._rect.y1)
        self._corner_tr.p2 = (self._rect.x2, self._rect.y1)
        self._corner_tr.min_side = self._grab_thickness
        
        self._corner_bl.p1 = (self._rect.x1, self._rect.y2)
        self._corner_bl.p2 = (self._rect.x1, self._rect.y2)
        self._corner_bl.min_side = self._grab_thickness
        
        self._corner_br.p1 = self._rect.p2
        self._corner_br.p2 = self._rect.p2
        self._corner_br.min_side = self._grab_thickness
        
        # Edge buttons
        self._edge_top.p1 = self._rect.p1
        self._edge_top.p2 = (self._rect.x2, self._rect.y1)
        self._edge_top.min_side = self._grab_thickness
        
        self._edge_bottom.p1 = (self._rect.x1, self._rect.y2)
        self._edge_bottom.p2 = self._rect.p2
        self._edge_bottom.min_side = self._grab_thickness
        
        self._edge_left.p1 = self._rect.p1
        self._edge_left.p2 = (self._rect.x1, self._rect.y2)
        self._edge_left.min_side = self._grab_thickness
        
        self._edge_right.p1 = (self._rect.x2, self._rect.y1)
        self._edge_right.p2 = self._rect.p2
        self._edge_right.min_side = self._grab_thickness
        
        # Center button (center plus margin)
        self._center_button.p1 = 0.75 * self._rect.center + 0.25 * self._rect.p1
        self._center_button.p2 = 0.75 * self._rect.center + 0.25 * self._rect.p2
        self._center_button.min_side = self._grab_thickness

    @property
    def rect(self) -> dcg.Rect:
        """The rectangle coordinates as a Rect object."""
        with self.mutex:
            return dcg.Rect(self._rect.x1, self._rect.y1, self._rect.x2, self._rect.y2)

    @rect.setter
    def rect(self, value: dcg.Rect | list[float] | tuple[float, float, float, float]) -> None:
        with self.mutex:
            if isinstance(value, dcg.Rect):
                self._rect = value
            else:
                # Assume it's a sequence [x1, y1, x2, y2]
                self._rect = dcg.Rect(*value)
            self._update_rect_geometry()

    @property
    def thickness(self) -> float:
        """Thickness of the rectangle outline. Negative values use screen space."""
        with self.mutex:
            return self._thickness

    @thickness.setter
    def thickness(self, value: float) -> None:
        with self.mutex:
            self._thickness = float(value)
            self._visible_rect.thickness = self._thickness
            self._diagonal1.thickness = self._thickness
            self._diagonal2.thickness = self._thickness

    @property
    def color(self):
        """Color of the rectangle outline and diagonals."""
        with self.mutex:
            return self._color

    @color.setter
    def color(self, value) -> None:
        with self.mutex:
            self._color = value
            self._visible_rect.color = value
            self._diagonal1.color = value
            self._diagonal2.color = value

    @property
    def fill(self):
        """Fill color of the rectangle."""
        with self.mutex:
            return self._fill

    @fill.setter
    def fill(self, value) -> None:
        with self.mutex:
            self._fill = value
            self._visible_rect.fill = value

    @property
    def grab_thickness(self) -> float:
        """Thickness of the grab areas for interaction."""
        with self.mutex:
            return self._grab_thickness

    @grab_thickness.setter
    def grab_thickness(self, value: float) -> None:
        with self.mutex:
            self._grab_thickness = float(value)
            self._update_rect_geometry()

    @property
    def clamp_inside(self) -> bool:
        """Controls whether the rectangle is constrained to remain inside the plot area."""
        with self.mutex:
            return self._clamp_inside

    @clamp_inside.setter
    def clamp_inside(self, value: bool) -> None:
        with self.parents_mutex:
            if self._clamp_inside == bool(value):
                return
            self._clamp_inside = bool(value)
            plot_element = self.parent
            while not(isinstance(plot_element, dcg.plotElement)):
                if isinstance(plot_element, dcg.Viewport):
                    # We reached the top parent without finding a plotElement
                    raise ValueError("clamp_inside requires to be in a plot")
                assert plot_element is not None, "item not attached to the rendering tree"
                plot_element = plot_element.parent
            self.axes = plot_element.axes
            plot = plot_element.parent
            assert plot is not None, "item not attached to the rendering tree"
            if self._clamp_inside:
                plot.handlers += [
                    dcg.RenderHandler(self.context,
                                       callback=self.handler_visible_for_clamping)
                ]
            else:
                plot.handlers = [h for h in plot.handlers if h is not self.handler_visible_for_clamping]

    @property
    def on_hover(self) -> None | dcg.Callback:
        """Callback triggered when any part of the rectangle is hovered."""
        with self.mutex:
            return self._on_hover

    @on_hover.setter
    def on_hover(self, value: 'None | dcg.DCGCallable') -> None:
        with self.mutex:
            self._on_hover = value if value is None or \
                                isinstance(value, dcg.Callback) else \
                                dcg.Callback(value)

    @property
    def on_dragging(self) -> None | dcg.Callback:
        """Callback triggered during active dragging."""
        with self.mutex:
            return self._on_dragging

    @on_dragging.setter
    def on_dragging(self, value: 'None | dcg.DCGCallable') -> None:
        with self.mutex:
            self._on_dragging = value if value is None or \
                                isinstance(value, dcg.Callback) else \
                                dcg.Callback(value)

    @property
    def on_dragged(self) -> None | dcg.Callback:
        """Callback triggered when a drag operation completes."""
        with self.mutex:
            return self._on_dragged

    @on_dragged.setter
    def on_dragged(self, value: 'None | dcg.DCGCallable') -> None:
        with self.mutex:
            self._on_dragged = value if value is None or \
                               isinstance(value, dcg.Callback) else \
                               dcg.Callback(value)

    def _get_button_type(self, button) -> str:
        """Determine what type of operation this button performs."""
        if button == self._corner_tl:
            return "corner_tl"
        elif button == self._corner_tr:
            return "corner_tr"
        elif button == self._corner_bl:
            return "corner_bl"
        elif button == self._corner_br:
            return "corner_br"
        elif button == self._edge_top:
            return "edge_top"
        elif button == self._edge_bottom:
            return "edge_bottom"
        elif button == self._edge_left:
            return "edge_left"
        elif button == self._edge_right:
            return "edge_right"
        elif button == self._center_button:
            return "move"
        else:
            return "unknown"

    # Class methods for shared handlers
    @classmethod
    def handler_hover(cls, _, target: dcg.DrawInvisibleButton) -> None:
        """Handler for hover events."""
        self: DragRect = target.parent # type: ignore
        if self is None:
            # deleted before we could handle hover
            return
        with self.mutex:
            _on_hover = self._on_hover
        if _on_hover is not None:
            _on_hover(self, self, self.rect)

    @classmethod
    def handler_got_hover(cls, _, target: dcg.DrawInvisibleButton) -> None:
        """Handler for when hover starts - shows diagonals."""
        self: DragRect = target.parent # type: ignore
        if self is None:
            # deleted before we could handle hover
            return
        with self.mutex:
            self._hover_count += 1
            if self._hover_count == 1:  # First hover
                self._diagonal1.show = True
                self._diagonal2.show = True

    @classmethod
    def handler_lost_hover(cls, _, target: dcg.DrawInvisibleButton) -> None:
        """Handler for when hover ends - hides diagonals when no more hovers."""
        self: DragRect = target.parent # type: ignore
        if self is None:
            # deleted before we could handle hover
            return
        with self.mutex:
            self._hover_count = max(0, self._hover_count - 1)
            if self._hover_count == 0:  # No more hovers
                self._diagonal1.show = False
                self._diagonal2.show = False

    @classmethod
    def handler_dragging(cls, _, target: dcg.DrawInvisibleButton, drag_deltas: tuple[float, float]) -> None:
        """Handler for dragging events."""
        self: DragRect = target.parent # type: ignore
        if self is None:
            # deleted before we could handle drag
            return
        
        with self.mutex:
            drag_type = self._get_button_type(target)
            # backup coordinates before dragging
            if not(self._was_dragging) or self._drag_type != drag_type:
                self._backup_rect = dcg.Rect(self._rect.x1, self._rect.y1, self._rect.x2, self._rect.y2)
                self._was_dragging = True
                self._drag_type = drag_type
                self._hover_count += 1 # Increment hover count to ensure diagonals are shown
            
            # Apply the appropriate transformation based on which button is being dragged
            new_rect = dcg.Rect(self._backup_rect.x1, self._backup_rect.y1, 
                               self._backup_rect.x2, self._backup_rect.y2)
            
            dx, dy = drag_deltas[0], drag_deltas[1]
            
            if self._drag_type == "move":
                # Move entire rectangle
                new_rect.x1 = self._backup_rect.x1 + dx
                new_rect.y1 = self._backup_rect.y1 + dy
                new_rect.x2 = self._backup_rect.x2 + dx
                new_rect.y2 = self._backup_rect.y2 + dy
            elif self._drag_type == "corner_tl":
                # Resize from top-left corner
                new_rect.x1 = self._backup_rect.x1 + dx
                new_rect.y1 = self._backup_rect.y1 + dy
            elif self._drag_type == "corner_tr":
                # Resize from top-right corner
                new_rect.x2 = self._backup_rect.x2 + dx
                new_rect.y1 = self._backup_rect.y1 + dy
            elif self._drag_type == "corner_bl":
                # Resize from bottom-left corner
                new_rect.x1 = self._backup_rect.x1 + dx
                new_rect.y2 = self._backup_rect.y2 + dy
            elif self._drag_type == "corner_br":
                # Resize from bottom-right corner
                new_rect.x2 = self._backup_rect.x2 + dx
                new_rect.y2 = self._backup_rect.y2 + dy
            elif self._drag_type == "edge_top":
                # Resize top edge
                new_rect.y1 = self._backup_rect.y1 + dy
            elif self._drag_type == "edge_bottom":
                # Resize bottom edge
                new_rect.y2 = self._backup_rect.y2 + dy
            elif self._drag_type == "edge_left":
                # Resize left edge
                new_rect.x1 = self._backup_rect.x1 + dx
            elif self._drag_type == "edge_right":
                # Resize right edge
                new_rect.x2 = self._backup_rect.x2 + dx
            
            # Ensure rectangle doesn't become inverted
            if new_rect.x2 < new_rect.x1:
                new_rect.x1, new_rect.x2 = new_rect.x2, new_rect.x1
            if new_rect.y2 < new_rect.y1:
                new_rect.y1, new_rect.y2 = new_rect.y2, new_rect.y1
            
            self._rect = new_rect
            self._update_rect_geometry()
            _on_dragging = self._on_dragging
        
        self.context.viewport.wake()
        
        # Release mutex before calling callback
        if _on_dragging is not None:
            _on_dragging(self, self, self.rect)

    @classmethod
    def handler_dragged(cls, _, target: dcg.DrawInvisibleButton, drag_deltas: tuple[float, float]) -> None:
        """Handler for drag completion events."""
        self: DragRect = target.parent # type: ignore
        if self is None:
            # deleted before we could handle drag
            return
        if self._drag_type != self._get_button_type(target):
            self._hover_count = max(0, self._hover_count - 1)
            return  # Another button took priority for the drag
        with self.mutex:
            self._was_dragging = False
            self._hover_count = max(0, self._hover_count - 1)
            _on_dragged = self._on_dragged
        self.context.viewport.wake()
        if _on_dragged is not None:
            _on_dragged(self, self, self.rect)

    def handler_visible_for_clamping(self, handler, plot: dcg.Plot) -> None:
        """Handler for clamping the rectangle inside plot bounds."""
        with plot.mutex:
            with self.mutex:
                x_axis = plot.axes[self.axes[0]]
                y_axis = plot.axes[self.axes[1]]
                mx, Mx = x_axis.min, x_axis.max
                my, My = y_axis.min, y_axis.max
                
                # Clamp rectangle to plot bounds
                width = self._rect.x2 - self._rect.x1
                height = self._rect.y2 - self._rect.y1
                
                if self._rect.x1 < mx:
                    self._rect.x1 = mx
                    self._rect.x2 = mx + width
                if self._rect.x2 > Mx:
                    self._rect.x2 = Mx
                    self._rect.x1 = Mx - width
                if self._rect.y1 < my:
                    self._rect.y1 = my
                    self._rect.y2 = my + height
                if self._rect.y2 > My:
                    self._rect.y2 = My
                    self._rect.y1 = My - height
                
                self._update_rect_geometry()

    # Redirect button state queries to the center button (representative)
    @property
    def state(self) -> dcg.ItemStateView:
        """The current state of the rectangle interaction area."""
        return self._center_button.state

    @property
    def no_input(self) -> bool:
        """Whether user input is disabled for the rectangle."""
        return self._center_button.no_input

    @no_input.setter
    def no_input(self, value: bool) -> None:
        # Apply to all buttons
        buttons = [
            self._center_button,
            self._edge_top, self._edge_bottom, self._edge_left, self._edge_right,
            self._corner_tl, self._corner_tr, self._corner_bl, self._corner_br
        ]
        for button in buttons:
            button.no_input = value

    @property
    def capture_mouse(self) -> bool:
        """Whether the rectangle captures mouse events."""
        return self._center_button.capture_mouse

    @capture_mouse.setter
    def capture_mouse(self, value: bool) -> None:
        # Apply to all buttons
        buttons = [
            self._center_button,
            self._edge_top, self._edge_bottom, self._edge_left, self._edge_right,
            self._corner_tl, self._corner_tr, self._corner_bl, self._corner_br
        ]
        for button in buttons:
            button.capture_mouse = value

    @property
    def handlers(self) -> list[dcg.baseHandler]:
        """The event handlers attached to this rectangle."""
        # Hide our internal handler, return handlers from center button as representative
        return [handler for handler in self._center_button.handlers if handler is not self._handlers[0]]

    @handlers.setter
    def handlers(self, value) -> None:
        # Apply to all buttons
        buttons = [
            self._center_button,
            self._edge_top, self._edge_bottom, self._edge_left, self._edge_right,
            self._corner_tl, self._corner_tr, self._corner_bl, self._corner_br
        ]
        for button, handler in zip(buttons, self._handlers):
            button.handlers = value
            # Add back our internal handler
            button.handlers = [handler] + button.handlers