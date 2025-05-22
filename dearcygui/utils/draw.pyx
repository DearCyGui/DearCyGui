#cython: freethreading_compatible=True

cimport dearcygui as dcg
import dearcygui as dcg


from dearcygui.c_types cimport unique_lock, DCGMutex
from cpython.ref cimport PyObject
cimport dearcygui.backends.time as ctime
from libcpp.map cimport pair
from libcpp.deque cimport deque
from libcpp.set cimport set
from libc.stdint cimport int32_t
from libc.math cimport fmod

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
        """Radius of the draggable point.
        
        Controls both the visual circle size and the interactive hit area.
        """
        with getattr(self, "mutex"):
            return self._radius

    @radius.setter
    def radius(self, value):
        with getattr(self, "mutex"):
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
        with getattr(self, "mutex"):
            return self.invisible.p1[0]

    @x.setter
    def x(self, value):
        with getattr(self, "mutex"):
            y = self.invisible.p1[1]
            self.invisible.p1 = [value, y]
            self.invisible.p2 = [value, y]
            self.visible.center = [value, y]

    @property
    def y(self):
        """Y coordinate in screen space.
        
        The vertical position of the point.
        """
        with getattr(self, "mutex"):
            return self.invisible.p1[1]

    @y.setter
    def y(self, value):
        with getattr(self, "mutex"):
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
        with getattr(self, "mutex"):
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
        with getattr(self, "mutex"):
            return self.visible.fill

    @color.setter
    def color(self, value):
        with getattr(self, "mutex"):
            self.visible.fill = value

    @property
    def on_hover(self):
        """Callback triggered when the point is hovered by the cursor.
        
        This callback is invoked whenever the mouse cursor hovers over the
        draggable point.
        """
        with getattr(self, "mutex"):
            return self._on_hover

    @on_hover.setter
    def on_hover(self, value):
        with getattr(self, "mutex"):
            self._on_hover = value if value is None or \
                                isinstance(value, dcg.Callback) else \
                                dcg.Callback(value)

    @property
    def on_dragging(self):
        """Callback triggered during active dragging.
        
        This callback is continuously invoked while the user is dragging the
        point, allowing real-time tracking of position changes.
        """
        with getattr(self, "mutex"):
            return self._on_dragging

    @on_dragging.setter
    def on_dragging(self, value):
        with getattr(self, "mutex"):
            self._on_dragging = value if value is None or \
                                isinstance(value, dcg.Callback) else \
                                dcg.Callback(value)

    @property
    def on_dragged(self):
        """Callback triggered when a drag operation completes.
        
        This callback is invoked once when the user releases the point after
        dragging it, signaling the completion of a position change.
        """
        with getattr(self, "mutex"):
            return self._on_dragged

    @on_dragged.setter
    def on_dragged(self, value):
        with getattr(self, "mutex"):
            self._on_dragged = value if value is None or \
                               isinstance(value, dcg.Callback) else \
                               dcg.Callback(value)

    def handler_dragging(self, _, __, drag_deltas):
        # During the dragging we might not hover anymore the button
        # Note: we must not lock our mutex before we access viewport
        # attributes
        with getattr(self, "mutex"):
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
        with getattr(self, "mutex"):
            self.was_dragging = False
            # update the coordinates
            self.x = self.backup_x + drag_deltas[0]
            self.y = self.backup_y + drag_deltas[1]
            _on_dragged = self._on_dragged
        if _on_dragged is not None:
            _on_dragged(self, self, (self.x, self.y))

    def handler_hover(self):
        with getattr(self, "mutex"):
            _on_hover = self._on_hover
        if _on_hover is not None:
            _on_hover(self, self, None)

    def handler_visible_for_clamping(self, handler, plot : dcg.Plot):
        # Every time the plot is visible, we
        # clamp the content if needed
        with getattr(plot, "mutex"): # We must lock the plot first
            with getattr(self, "mutex"):
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
        """Whether the point is in active state.
        
        Reflects whether the point is currently being interacted with.
        """
        return self.invisible.active

    @property
    def activated(self):
        """Whether the point was activated this frame.
        
        True if the point transitioned to active state in the current frame.
        """
        return self.invisible.activated

    @property
    def clicked(self):
        """Whether the point was clicked this frame.
        
        True if the point was clicked in the current frame.
        """
        return self.invisible.clicked

    @property
    def double_clicked(self):
        """Whether the point was double clicked this frame.
        
        True if the point was double clicked in the current frame.
        """
        return self.invisible.double_clicked

    @property
    def deactivated(self):
        """Whether the point was deactivated this frame.
        
        True if the point transitioned from active to inactive in this frame.
        """
        return self.invisible.deactivated

    @property
    def pos_to_viewport(self):
        """The point's position relative to viewport coordinates.
        
        Provides the position converted to the viewport's coordinate system.
        """
        return self.invisible.pos_to_viewport

    @property
    def pos_to_window(self):
        """The point's position relative to window coordinates.
        
        Provides the position converted to the window's coordinate system.
        """
        return self.invisible.pos_to_window

    @property
    def pos_to_parent(self):
        """The point's position relative to parent coordinates.
        
        Provides the position converted to the parent's coordinate system.
        """
        return self.invisible.pos_to_parent

    @property
    def rect_size(self):
        """The rectangular size of the point's interactive area.
        
        Gives the dimensions of the rectangular area that responds to
        mouse interactions.
        """
        return self.invisible.rect_size

    @property
    def resized(self):
        """Whether the point's size changed this frame.
        
        True if the point was resized in the current frame.
        """
        return self.invisible.resized

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
        
        Controls how the point interacts with mouse events that occur
        within its bounds.
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


cdef class DrawStream(dcg.DrawingList):
    """A drawing element that draws its children in a FIFO time stream fashion.

    Each child is associated with an expiration time.
    When the expiration time is reached, the queue
    moves onto the next child.

    Only the first child in the queue is shown.

    if time_modulus is set, the time is taken modulo
    time_modulus, and the queue loops back once the end
    is reached.

    Usage:
    ```python
    stream = DrawStream(context)
    # Add drawing element that will expire after 2 seconds
    expiration_time = time.monotonic() + 2.0 
    stream.push(DrawCircle(context),
                expiration_time)
    ```
    """
    cdef bint _allow_no_children
    cdef bint _no_skip_children
    cdef double _time_modulus
    cdef int32_t  _last_index
    cdef deque[pair[double, PyObject*]] _expiry_times # Weak ref

    def __cinit__(self):
        self._allow_no_children = False
        self._no_skip_children = False
        self._time_modulus = 0.
        self._last_index = -1
        

    cdef double _get_time_with_modulus(self) noexcept nogil:
        """Applies time_modulus"""
        cdef double current_time = (<double>ctime.monotonic_ns())*1e-9
        if self._time_modulus > 0.:
            return fmod(current_time, self._time_modulus)
        return current_time

    cdef int32_t  _get_index_to_show(self) noexcept nogil:
        """Return the index of the item to show. -1 if None"""
        cdef pair[double, PyObject*] element
        cdef double current_time = self._get_time_with_modulus()
        cdef int32_t  i = 0
        cdef int32_t  result = -1
        for element in self._expiry_times:
            if element.first > current_time:
                result = i
                break
            i = i + 1
        # All children are outdated or no children
        cdef int32_t  num_items = self._expiry_times.size()
        if result == -1:
            if self._allow_no_children:
                result = num_items
            else:
                result = num_items - 1
        if self._no_skip_children:
            if result < self._last_index:
                if self._last_index == (num_items - 1):
                    result = 0 # Loop back without skipping
                else:
                    result = self._last_index + 1
            elif result != self._last_index:
                result = self._last_index + 1
        if result >= num_items:
            result = -1
        return result

    @property
    def time(self):
        """Return the current time (monotonic clock mod time_modulus) in seconds"""
        return self._get_time_with_modulus()

    @property
    def allow_no_children(self):
        """
        If True, if the expiration date of the last
        child expires, the item is allowed to have
        no child.

        If False (default), always keep at least one child.
        """
        cdef unique_lock[DCGMutex] m
        dcg.lock_gil_friendly(m, self.mutex)
        return self._allow_no_children

    @allow_no_children.setter
    def allow_no_children(self, bint value):
        cdef unique_lock[DCGMutex] m
        dcg.lock_gil_friendly(m, self.mutex)
        self._allow_no_children = value

    @property
    def no_skip_children(self):
        """
        If True, will always show each child
        at least one frame, even if their
        expiration time is reached.
        """
        cdef unique_lock[DCGMutex] m
        dcg.lock_gil_friendly(m, self.mutex)
        return self._no_skip_children

    @no_skip_children.setter
    def no_skip_children(self, bint value):
        cdef unique_lock[DCGMutex] m
        dcg.lock_gil_friendly(m, self.mutex)
        self._no_skip_children = value

    @property
    def time_modulus(self):
        """
        If non-zero, the monotonic clock
        time will be applied this value as
        modulus, and the queue will loop back.
        """
        cdef unique_lock[DCGMutex] m
        dcg.lock_gil_friendly(m, self.mutex)
        return self._time_modulus

    @time_modulus.setter
    def time_modulus(self, double value):
        cdef unique_lock[DCGMutex] m
        dcg.lock_gil_friendly(m, self.mutex)
        self._time_modulus = value

    def clear(self, only_outdated=False):
        """Clear the drawing queue and detaches the children
        
        if only_updated is True, only items
        with past timestamps are removed
        """
        cdef unique_lock[DCGMutex] m
        dcg.lock_gil_friendly(m, self.mutex)
        if not only_outdated:
            self._expiry_times.clear()
            self.children = []
            self._last_index = -1
            return
        cdef set[PyObject*] candidates
        cdef pair[double, PyObject*] element
        cdef int32_t  index_to_show = self._get_index_to_show()
        if index_to_show == -1:
            # All are to be removed or no children
            self._expiry_times.clear()
            self.children = []
            self._last_index = -1
            return
        cdef int32_t  i = 0
        for element in self._expiry_times:
            if i < index_to_show:
                # outdated
                candidates.insert(element.second)
            else:
                # still in the queue
                candidates.erase(element.second)
            i = i + 1
        i = 0
        while i < index_to_show:
            self._expiry_times.pop_front()
            self._last_index = self._last_index - 1
            i = i + 1

        cdef PyObject *child
        cdef PyObject *other_child 
        cdef dcg.baseItem child_object
        for child in candidates:
            # As we hold only a weak reference, we need to check
            # if the child is still alive and attached to us,
            # in case the user removed it.
            # As we hold the lock, we can safely access the children
            # and detach them if needed.
            other_child = <PyObject*> self.last_drawings_child
            while <object>other_child is not None:
                if other_child == child:
                    child_object = <dcg.baseItem>child
                    child_object.detach_item()
                    break
                other_child = <PyObject *>(<dcg.baseItem>other_child).prev_sibling


    def push(self, child, double expiry_time):
        """Push a drawing item to the queue.

        The item will be attached as child if it isn't already.
        Only items associated with a push() will be
        displayed.

        An item is allowed to be several times in the queue
        (it will be attach as child only once, but will appear
         several times in the queue)

        Elements in the queue remain there unless the
        item is deleted, or clear() is called.

        Parameters:
            child: Drawing element to attach
            expiry_time: Time when child should expire and drawing
                should move on to the next one in the queue.
                The time clock corresponds to time.monotonic().
        """
        cdef unique_lock[DCGMutex] m
        dcg.lock_gil_friendly(m, self.mutex)
        if child.parent is not self:
            child.attach_to_parent(self)
        cdef pair[double, PyObject*] element
        element.first = expiry_time
        element.second = <PyObject*>child
        self._expiry_times.push_back(element)
        


    cdef void draw(self, void* draw_list) noexcept nogil:
        """Draw the first unexpired child in the stream."""
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        # Find index to show
        cdef int32_t  index_to_show = self._get_index_to_show()

        if self._last_index != index_to_show:
            # If the children have the same number of
            # vertices generated, the viewport cannot
            # detect the visual changed. We help it
            # here with this call.
            self.context.viewport.force_present()

        self._last_index = index_to_show

        # Nothing to show
        if index_to_show == -1:
            return
        if self.last_drawings_child is None: # Shouldn't be needed, but just in case
            return

        # Check if the child is still alive and attached
        cdef PyObject *child = self._expiry_times[index_to_show].second
        cdef PyObject *other_child = <PyObject *>self.last_drawings_child
        if other_child != child:
            while (<dcg.baseItem>other_child).prev_sibling is not None:
                other_child = <PyObject *>(<dcg.baseItem>other_child).prev_sibling
                if other_child == child:
                    break
            if other_child != child:
                # The child was removed by the user outside clear()
                return

        cdef double current_time, time_to_expiration
        if self._get_index_to_show() != self._last_index:
            # We are running late
            self.context.viewport.ask_refresh_after(0)
        elif self._time_modulus == 0.:
            self.context.viewport.ask_refresh_after(self._expiry_times[index_to_show].first)
        else:
            current_time = (<double>ctime.monotonic_ns())*1e-9
            time_to_expiration = self._expiry_times[index_to_show].first - self._get_time_with_modulus()
            if time_to_expiration < 0.:
                time_to_expiration += self._time_modulus
            self.context.viewport.ask_refresh_after(current_time + time_to_expiration)

        # Draw the child
        (<dcg.drawingItem>child).draw(draw_list)
