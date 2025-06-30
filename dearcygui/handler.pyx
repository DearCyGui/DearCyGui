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

from cpython.object cimport PyObject
from cpython.sequence cimport PySequence_Check
cimport cython
from cython.operator cimport dereference
from libc.string cimport strcmp

from .core cimport baseHandler, baseItem, lock_gil_friendly,\
    itemState, ensure_correct_im_context
from .c_types cimport DCGMutex, unique_lock, string_to_str, string_from_str
from .types cimport make_Positioning, read_rect, Rect,\
    is_Key, make_Key, Positioning
from .widget cimport SharedBool
from .wrapper cimport imgui

import traceback

ctypedef void* void_p

cdef class CustomHandler(baseHandler):
    """
    A base class to be subclassed in python for custom state checking.

    This class provides a framework for implementing custom handlers that can monitor
    and respond to specific item states. As this is called every frame rendered,
    and locks the GIL, be careful not to perform anything computationally heavy.

    Required Methods:
        check_can_bind(self, item): 
            Must return a boolean indicating if this handler can be bound to the target item.
            Use isinstance() to check item types.
        
        check_status(self, item):
            Must return a boolean indicating if the watched condition is met.
            Should only check state, not perform actions.
        
        run(self, item) (Optional):
            If implemented, handles the response when conditions are met.
            Even with run() implemented, check_status() is still required.

    Warning:
        DO NOT modify item parent/sibling/child relationships during rendering.
        Changes to values or status are allowed except for parent modifications.
        For tree structure changes, delay until outside render_frame() or queue 
        for execution in another thread.
    """
    def __cinit__(self):
        self._has_run = False  # Cache whether run() method exists

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Check and cache if the subclass has a run method
        self._has_run = hasattr(self, "run")

    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef bint condition = False
        condition = self.check_can_bind(item)
        if not(condition):
            raise TypeError(f"Cannot bind handler {self} for {item}")

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef bint condition = False
        with gil:
            try:
                condition = self.check_status(item)
            except Exception as e:
                print(f"An error occured running check_status of {self} on {item}", traceback.format_exc())
        ensure_correct_im_context(self.context)
        return condition

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._enabled):
            return
        
        # Early exit if no callback and no run method
        if self._callback is None and not(self._has_run):
            return

        cdef bint condition = False
        with gil:
            if self._has_run:
                try:
                    self.run(item)
                except Exception as e:
                    print(f"An error occured running run of {self} on {item}", traceback.format_exc())
            elif self._callback is not None:
                try:
                    condition = self.check_status(item)
                except Exception as e:
                    print(f"An error occured running check_status of {self} on {item}", traceback.format_exc())
        ensure_correct_im_context(self.context) # TODO: should probably be done at the queue level too
        if condition:
            self.run_callback(item)


cdef inline void check_bind_children(baseItem item, baseItem target):
    if item.last_handler_child is None:
        return
    cdef PyObject *child = <PyObject*> item.last_handler_child
    while (<baseItem>child).prev_sibling is not None:
        child = <PyObject *>(<baseItem>child).prev_sibling
    while (<baseItem>child) is not None:
        (<baseHandler>child).check_bind(target)
        child = <PyObject *>(<baseItem>child).next_sibling

cdef bint check_state_from_list(baseHandler start_handler,
                                HandlerListOP op,
                                baseItem item) noexcept nogil:
        """
        Helper for handler lists
        """
        if start_handler is None:
            return False
        start_handler.lock_and_previous_siblings()
        # We use PyObject to avoid refcounting and thus the gil
        cdef PyObject* child = <PyObject*>start_handler
        cdef bint current_state = False
        cdef bint child_state
        if op == HandlerListOP.ALL:
            current_state = True
        if (<baseHandler>child) is not None:
            while (<baseItem>child).prev_sibling is not None:
                child = <PyObject *>(<baseItem>child).prev_sibling
        while (<baseHandler>child) is not None:
            child_state = (<baseHandler>child).check_state(item)
            if not((<baseHandler>child)._enabled):
                child = <PyObject*>((<baseHandler>child).next_sibling)
                continue
            if op == HandlerListOP.ALL:
                current_state = current_state and child_state
                if not(current_state):
                    # Leave early. Useful to skip expensive check_states,
                    # for instance from custom handlers.
                    # We will return FALSE (not all are conds met)
                    break
            elif op == HandlerListOP.ANY:
                current_state = current_state or child_state
                if current_state:
                    # We will return TRUE (at least one cond is met)
                    break
            else: # NONE:
                current_state = current_state or child_state
                if current_state:
                    # We will return FALSE (at least one cond is met)
                    break
            child = <PyObject*>((<baseHandler>child).next_sibling)
        if op == HandlerListOP.NONE:
            # NONE = not(ANY)
            current_state = not(current_state)
        start_handler.unlock_and_previous_siblings()
        return current_state

cdef inline void run_handler_children(baseItem item, baseItem target) noexcept nogil:
    if item.last_handler_child is None:
        return
    cdef PyObject *child = <PyObject*> item.last_handler_child
    while (<baseItem>child).prev_sibling is not None:
        child = <PyObject *>(<baseItem>child).prev_sibling
    while (<baseItem>child) is not None:
        (<baseHandler>child).run_handler(target)
        child = <PyObject *>(<baseItem>child).next_sibling

cdef class HandlerList(baseHandler):
    """
    A container for multiple handlers that can be attached to an item.

    This handler allows grouping multiple handlers together and optionally 
    executing a callback based on the combined state of all child handlers.

    The callback can be triggered based on three conditions:
    - ALL: All child handlers' states must be true (default)
    - ANY: At least one child handler's state must be true
    - NONE: No child handler's states are true

    Skipping heavy CustomHandlers:
        One use case is to skip expensive check_status() calls from CustomHandlers.
        If the status of the first children is incompatible with the checked condition,
        the status of further children is not checked.

    Note:
        Handlers are not checked if their parent item is not rendered.
    """
    def __cinit__(self):
        self.can_have_handler_child = True
        self._op = HandlerListOP.ALL

    @property
    def op(self):
        """
        HandlerListOP that defines which condition
        is required to trigger the callback of this
        handler.
        Default is ALL
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._op

    @op.setter
    def op(self, HandlerListOP value):
        if value not in [HandlerListOP.ALL, HandlerListOP.ANY, HandlerListOP.NONE]:
            raise ValueError("Unknown op")
        self._op = value

    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        check_bind_children(self, item)

    cdef bint check_state(self, baseItem item) noexcept nogil:
        return check_state_from_list(self.last_handler_child, self._op, item)

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._enabled):
            return
        run_handler_children(self, item)
        if self._callback is not None:
            if self.check_state(item):
                self.run_callback(item)


cdef class ConditionalHandler(baseHandler):
    """
    A handler that runs the FIRST handler child if all other handler children conditions are met.

    Unlike HandlerList, this handler:
    1. Only executes the first handler when conditions are met
    2. Uses other handlers only for condition checking (their callbacks are not called)

    One interest of this handler is to tests conditions immediately, rather than in a callback,
    avoiding timing issues with callback queues

    Useful for combining conditions, such as detecting clicks when specific keys are pressed.

    Skipping heavy CustomHandlers:
        One use case is to skip expensive run() calls from CustomHandlers.

    Note:
        Only the first handler's callback is executed when all conditions are met.
        Other handlers are used purely for their state conditions.
    """
    def __cinit__(self):
        self.can_have_handler_child = True

    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        check_bind_children(self, item)

    cdef bint check_state(self, baseItem item) noexcept nogil:
        if self.last_handler_child is None:
            return False
        self.last_handler_child.lock_and_previous_siblings()
        # We use PyObject to avoid refcounting and thus the gil
        cdef PyObject* child = <PyObject*>self.last_handler_child
        cdef bint current_state = True
        cdef bint child_state
        while child is not <PyObject*>None:
            child_state = (<baseHandler>child).check_state(item)
            child = <PyObject*>((<baseHandler>child).prev_sibling)
            if not((<baseHandler>child)._enabled):
                continue
            current_state = current_state and child_state
        self.last_handler_child.unlock_and_previous_siblings()
        return current_state

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._enabled):
            return
        if self.last_handler_child is None:
            return
        self.last_handler_child.lock_and_previous_siblings()
        # Retrieve the first child and combine the states of the previous ones
        cdef bint condition_held = True
        cdef PyObject* child = <PyObject*>self.last_handler_child
        cdef bint child_state
        # Note: we already have tested there is at least one child
        while ((<baseHandler>child).prev_sibling) is not None:
            child_state = (<baseHandler>child).check_state(item)
            child = <PyObject*>((<baseHandler>child).prev_sibling)
            if not((<baseHandler>child)._enabled):
                continue
            condition_held = condition_held and child_state
        if condition_held:
            (<baseHandler>child).run_handler(item)
        self.last_handler_child.unlock_and_previous_siblings()
        if self._callback is not None:
            if self.check_state(item):
                self.run_callback(item)


cdef class OtherItemHandler(HandlerList):
    """
    A handler that monitors states from a different item than the one it's attached to.

    This handler allows checking states of an item different from its attachment point,
    while still sending callbacks with the attached item as the target.

    Use cases:
    - Combining states between different items (AND/OR operations)
    - Monitoring items that might not be rendered
    - Creating dependencies between different interface elements

    Note:
        Callbacks still reference the attached item as target, not the monitored item.
    """
    def __cinit__(self):
        self._target = None

    @property
    def target(self):
        """
        Target item which state will be used
        for children handlers.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._target

    @target.setter
    def target(self, baseItem target):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._target = target

    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        check_bind_children(self, self._target)

    cdef bint check_state(self, baseItem item) noexcept nogil:
        return check_state_from_list(self.last_handler_child, self._op, self._target)

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._enabled):
            return

        # TODO: reintroduce that feature. Here we use item, and not self._target. Idem above
        run_handler_children(self, self._target)
        if self._callback is not None:
            if self.check_state(item):
                self.run_callback(item)


cdef class BoolHandler(baseHandler):
    """
    Handler that fits a SharedBool condition
    inside a handler.

    Basically the handler's condition is True
    if the SharedBool evaluates to True,
    and False else.

    This handler can be used combined with
    ConditionalHandler or HandlerList to
    skip processing handlers (and their callbacks)
    when some external condition is not met.
    """
    def __cinit__(self):
        self._condition = SharedBool.__new__(SharedBool, self.context)

    @property
    def condition(self):
        """
        SharedBool condition that this handler
        will use to determine if the callback
        should be called.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._condition

    @condition.setter
    def condition(self, SharedBool value not None):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._condition = value

    cdef void check_bind(self, baseItem item):
        return

    cdef bint check_state(self, baseItem item) noexcept nogil:
        return self._condition.get()

cdef class ActivatedHandler(baseHandler):
    """
    Handler for when the target item turns from
    the non-active to the active state. For instance
    buttons turn active when the mouse is pressed on them.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_active):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.active and not(state.prev.active)

cdef class ActiveHandler(baseHandler):
    """
    Handler for when the target item is active.
    For instance buttons turn active when the mouse
    is pressed on them, and stop being active when
    the mouse is released.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_active):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.active

cdef class ClickedHandler(baseHandler):
    """
    Handler for when a hovered item is clicked on.
    The item doesn't have to be interactable,
    it can be Text for example.
    """
    def __cinit__(self):
        self._button = MouseButton.LEFT
    @property
    def button(self):
        """
        Target mouse button
        0: left click
        1: right click
        2: middle click
        3, 4: other buttons
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, MouseButton value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value < MouseButton.LEFT or value > MouseButton.X2:
            raise ValueError("Invalid button")
        self._button = value

    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_clicked):
            raise TypeError(f"Cannot bind handler {self} for {item}")

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        cdef itemState *state = item.p_state
        return state.cur.clicked[<int>self._button]

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        cdef itemState *state = item.p_state
        if not(self._enabled):
            return
        if state.cur.clicked[<int>self._button]:
            self.context.queue_callback_arg1button(self._callback, self, item, <int>self._button)

cdef class DoubleClickedHandler(baseHandler):
    """
    Handler for when a hovered item is double clicked on.
    """
    def __cinit__(self):
        self._button = MouseButton.LEFT
    @property
    def button(self):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, MouseButton value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value < MouseButton.LEFT or value > MouseButton.X2:
            raise ValueError("Invalid button")
        self._button = value

    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_clicked):
            raise TypeError(f"Cannot bind handler {self} for {item}")

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        cdef itemState *state = item.p_state
        return state.cur.double_clicked[<int>self._button]

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        cdef itemState *state = item.p_state
        if not(self._enabled):
            return
        if state.cur.double_clicked[<int>self._button]:
            self.context.queue_callback_arg1button(self._callback, self, item, <int>self._button)

cdef class DeactivatedHandler(baseHandler):
    """
    Handler for when an active item loses activation.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_active):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return not(state.cur.active) and state.prev.active

cdef class DeactivatedAfterEditHandler(baseHandler):
    """
    However for editable items when the item loses
    activation after having been edited.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_deactivated_after_edited):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.deactivated_after_edited

cdef class DraggedHandler(baseHandler):
    """
    Same as DraggingHandler, but only
    triggers the callback when the dragging
    has ended, instead of every frame during
    the dragging.
    """
    def __cinit__(self):
        self._button = MouseButton.LEFT
    @property
    def button(self):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, MouseButton value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value < MouseButton.LEFT or value > MouseButton.X2:
            raise ValueError("Invalid button")
        self._button = value

    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_dragged):
            raise TypeError(f"Cannot bind handler {self} for {item}")

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        cdef itemState *state = item.p_state
        return state.prev.dragging[<int>self._button] and not(state.cur.dragging[<int>self._button])

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        cdef itemState *state = item.p_state
        if not(self._enabled):
            return
        cdef int32_t i = <int32_t>self._button
        if state.prev.dragging[i] and not(state.cur.dragging[i]):
                self.context.queue_callback_arg2float(self._callback,
                                                      self,
                                                      item,
                                                      state.prev.drag_deltas[i].x,
                                                      state.prev.drag_deltas[i].y)

cdef class DraggingHandler(baseHandler):
    """
    Handler to catch when the item is hovered
    and the mouse is dragging (click + motion) ?
    Note that if the item is not a button configured
    to catch the target button, it will not be
    considered being dragged as soon as it is not
    hovered anymore.
    """
    def __cinit__(self):
        self._button = MouseButton.LEFT
    @property
    def button(self):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, MouseButton value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value < MouseButton.LEFT or value > MouseButton.X2:
            raise ValueError("Invalid button")
        self._button = value

    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_dragged):
            raise TypeError(f"Cannot bind handler {self} for {item}")

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        cdef itemState *state = item.p_state
        return state.cur.dragging[<int>self._button]

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        cdef itemState *state = item.p_state
        cdef int32_t i = <int32_t>self._button
        if not(self._enabled):
            return
        if state.cur.dragging[i]:
            self.context.queue_callback_arg2float(self._callback,
                                                  self,
                                                  item,
                                                  state.cur.drag_deltas[i].x,
                                                  state.cur.drag_deltas[i].y)

cdef class EditedHandler(baseHandler):
    """
    Handler to catch when a field is edited.
    Only the frames when a field is changed
    triggers the callback.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_edited):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.edited

cdef class FocusHandler(baseHandler):
    """
    Handler for windows or sub-windows that is called
    when they have focus, or for items when they
    have focus (for instance keyboard navigation,
    or editing a field).
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_focused):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.focused

cdef class GotFocusHandler(baseHandler):
    """
    Handler for when windows or sub-windows get
    focus.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_focused):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.focused and not(state.prev.focused)

cdef class LostFocusHandler(baseHandler):
    """
    Handler for when windows or sub-windows lose
    focus.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_focused):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.focused and not(state.prev.focused)

cdef class MouseOverHandler(baseHandler):
    """Prefer HoverHandler unless you really need to (see below)

    Handler that calls the callback when
    the mouse is over the item. In most cases,
    this is equivalent to HoverHandler,
    with the difference that a single item
    is considered hovered, while in
    some specific cases, several items could
    have the mouse above them.

    Prefer using HoverHandler for general use,
    and reserve MouseOverHandler for custom
    drag & drop operations.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or \
           not(item.p_state.cap.has_position) or \
           not(item.p_state.cap.has_rect_size):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef imgui.ImGuiIO io = imgui.GetIO()
        if not(imgui.IsMousePosValid()):
            return False
        cdef float x1 = item.p_state.cur.pos_to_viewport.x
        cdef float y1 = item.p_state.cur.pos_to_viewport.y
        cdef float x2 = x1 + item.p_state.cur.rect_size.x
        cdef float y2 = y1 + item.p_state.cur.rect_size.y
        return x1 <= io.MousePos.x and \
               y1 <= io.MousePos.y and \
               x2 > io.MousePos.x and \
               y2 > io.MousePos.y

cdef class GotMouseOverHandler(baseHandler):
    """Prefer GotHoverHandler unless you really need to (see MouseOverHandler)
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or \
           not(item.p_state.cap.has_position) or \
           not(item.p_state.cap.has_rect_size):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef imgui.ImGuiIO io = imgui.GetIO()
        if not(imgui.IsMousePosValid()):
            return False
        # Check the mouse is over the item
        cdef float x1 = item.p_state.cur.pos_to_viewport.x
        cdef float y1 = item.p_state.cur.pos_to_viewport.y
        cdef float x2 = x1 + item.p_state.cur.rect_size.x
        cdef float y2 = y1 + item.p_state.cur.rect_size.y
        if not(x1 <= io.MousePos.x and \
               y1 <= io.MousePos.y and \
               x2 > io.MousePos.x and \
               y2 > io.MousePos.y):
            return False
        # Check the mouse was not over the item
        if io.MousePosPrev.x == -1 or io.MousePosPrev.y == -1: # Invalid pos
            return True
        x1 = item.p_state.prev.pos_to_viewport.x
        y1 = item.p_state.prev.pos_to_viewport.y
        x2 = x1 + item.p_state.prev.rect_size.x
        y2 = y1 + item.p_state.prev.rect_size.y
        return not(x1 <= io.MousePosPrev.x and \
                   y1 <= io.MousePosPrev.y and \
                   x2 > io.MousePosPrev.x and \
                   y2 > io.MousePosPrev.y)

cdef class LostMouseOverHandler(baseHandler):
    """Prefer LostHoverHandler unless you really need to (see MouseOverHandler)
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or \
           not(item.p_state.cap.has_position) or \
           not(item.p_state.cap.has_rect_size):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef imgui.ImGuiIO io = imgui.GetIO()
        # Check the mouse was over the item
        if io.MousePosPrev.x == -1 or io.MousePosPrev.y == -1: # Invalid pos
            return False
        cdef float x1 = item.p_state.prev.pos_to_viewport.x
        cdef float y1 = item.p_state.prev.pos_to_viewport.y
        cdef float x2 = x1 + item.p_state.prev.rect_size.x
        cdef float y2 = y1 + item.p_state.prev.rect_size.y
        if not(x1 <= io.MousePosPrev.x and \
               y1 <= io.MousePosPrev.y and \
               x2 > io.MousePosPrev.x and \
               y2 > io.MousePosPrev.y):
            return False
        if not(imgui.IsMousePosValid()):
            return True
        # Check the mouse is not over the item
        x1 = item.p_state.cur.pos_to_viewport.x
        y1 = item.p_state.cur.pos_to_viewport.y
        x2 = x1 + item.p_state.cur.rect_size.x
        y2 = y1 + item.p_state.cur.rect_size.y
        return not(x1 <= io.MousePos.x and \
                   y1 <= io.MousePos.y and \
                   x2 > io.MousePos.x and \
                   y2 > io.MousePos.y)

cdef class HoverHandler(baseHandler):
    """
    Handler that calls the callback when
    the target item is hovered.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_hovered):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.hovered

cdef class GotHoverHandler(baseHandler):
    """
    Handler that calls the callback when
    the target item has just been hovered.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_hovered):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.hovered and not(state.prev.hovered)

cdef class LostHoverHandler(baseHandler):
    """
    Handler that calls the callback the first
    frame when the target item was hovered, but
    is not anymore.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_hovered):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return not(state.cur.hovered) and state.prev.hovered


cdef class MotionHandler(baseHandler):
    """
    Handler that calls the callback when
    the target item is moved relative to
    the positioning reference (by default the parent)
    """
    def __cinit__(self):
        self._positioning[0] = Positioning.REL_PARENT
        self._positioning[1] = Positioning.REL_PARENT

    @property
    def pos_policy(self):
        """positioning policy used as reference for the motion

        REL_PARENT: motion relative to the parent
        REL_WINDOW: motion relative to the window
        REL_VIEWPORT: motion relative to the viewport
        DEFAULT: Disabled motion detection for the axis

        pos_policy is a tuple of Positioning where the
        first element refers to the x axis and the second
        to the y axis

        Defaults to REL_PARENT on both axes.
        """
        return (make_Positioning(<int>self._positioning[0]), make_Positioning(<int>self._positioning[1]))

    @pos_policy.setter
    def pos_policy(self, value):
        if PySequence_Check(value) > 0:
            (x, y) = value
            self._positioning[0] = <Positioning><int>make_Positioning(x)
            self._positioning[1] = <Positioning><int>make_Positioning(y)
        else:
            self._positioning[0] = <Positioning><int>make_Positioning(value)
            self._positioning[1] = <Positioning><int>make_Positioning(value)

    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.has_position):
            raise TypeError(f"Cannot bind handler {self} for {item}")

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        cdef imgui.ImVec2 prev_pos, cur_pos
        if self._positioning[0] == Positioning.REL_PARENT:
            prev_pos.x = state.prev.pos_to_parent.x
            cur_pos.x = state.cur.pos_to_parent.x
        elif self._positioning[0] == Positioning.REL_WINDOW:
            prev_pos.x = state.prev.pos_to_window.x
            cur_pos.x = state.cur.pos_to_window.x
        elif self._positioning[0] == Positioning.REL_VIEWPORT:
            prev_pos.x = state.prev.pos_to_viewport.x
            cur_pos.x = state.cur.pos_to_viewport.x
        elif self._positioning[0] == Positioning.REL_DEFAULT:
            prev_pos.x = 0.
            cur_pos.x = 0.
        else:
            prev_pos.x = 0.
            cur_pos.x = 0.
        if self._positioning[1] == Positioning.REL_PARENT:
            prev_pos.y = state.prev.pos_to_parent.y
            cur_pos.y = state.cur.pos_to_parent.y
        elif self._positioning[1] == Positioning.REL_WINDOW:
            prev_pos.y = state.prev.pos_to_window.y
            cur_pos.y = state.cur.pos_to_window.y
        elif self._positioning[1] == Positioning.REL_VIEWPORT:
            prev_pos.y = state.prev.pos_to_viewport.y
            cur_pos.y = state.cur.pos_to_viewport.y
        elif self._positioning[1] == Positioning.REL_DEFAULT:
            prev_pos.y = 0.
            cur_pos.y = 0.
        else:
            prev_pos.y = 0.
            cur_pos.y = 0.
        return cur_pos.x != prev_pos.x or cur_pos.y != prev_pos.y


# TODO: Add size as data to the resize callbacks
cdef class ContentResizeHandler(baseHandler):
    """
    Handler for item containers (windows, etc)
    that triggers the callback
    whenever the item's content region box (the
    area available to the children) changes size.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.has_content_region):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.content_region_size.x != state.prev.content_region_size.x or \
               state.cur.content_region_size.y != state.prev.content_region_size.y

cdef class ResizeHandler(baseHandler):
    """
    Handler that triggers the callback
    whenever the item's bounding box changes size.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.has_rect_size):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.rect_size.x != state.prev.rect_size.x or \
               state.cur.rect_size.y != state.prev.rect_size.y

cdef class ToggledOpenHandler(baseHandler):
    """
    Handler that triggers the callback when the
    item switches from an closed state to a opened
    state. Here Close/Open refers to being in a
    reduced state when the full content is not
    shown, but could be if the user clicked on
    a specific button. The doesn't mean that
    the object is show or not shown.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_toggled):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.open and not(state.prev.open)

cdef class ToggledCloseHandler(baseHandler):
    """
    Handler that triggers the callback when the
    item switches from an opened state to a closed
    state.
    *Warning*: Does not mean an item is un-shown
    by a user interaction (what we usually mean
    by closing a window).
    Here Close/Open refers to being in a
    reduced state when the full content is not
    shown, but could be if the user clicked on
    a specific button. The doesn't mean that
    the object is show or not shown.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_toggled):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return not(state.cur.open) and state.prev.open

cdef class OpenHandler(baseHandler):
    """
    Handler that triggers the callback when the
    item is in an opened state.
    Here Close/Open refers to being in a
    reduced state when the full content is not
    shown, but could be if the user clicked on
    a specific button. The doesn't mean that
    the object is show or not shown.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_toggled):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.open

cdef class CloseHandler(baseHandler):
    """
    Handler that triggers the callback when the
    item is in an closed state.
    *Warning*: Does not mean an item is un-shown
    by a user interaction (what we usually mean
    by closing a window).
    Here Close/Open refers to being in a
    reduced state when the full content is not
    shown, but could be if the user clicked on
    a specific button. The doesn't mean that
    the object is show or not shown.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL or not(item.p_state.cap.can_be_toggled):
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return not(state.cur.open)

cdef class RenderHandler(baseHandler):
    """
    Handler that calls the callback
    whenever the item is rendered during
    frame rendering. This doesn't mean
    that the item is visible as it can be
    occluded by an item in front of it.
    Usually rendering skips items that
    are outside the window's clipping region,
    or items that are inside a menu that is
    currently closed.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL:
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.rendered

cdef class GotRenderHandler(baseHandler):
    """
    Same as RenderHandler, but only calls the
    callback when the item switches from a
    non-rendered to a rendered state.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL:
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return state.cur.rendered and not(state.prev.rendered)

cdef class LostRenderHandler(baseHandler):
    """
    Handler that only calls the
    callback when the item switches from a
    rendered to non-rendered state. Note
    that when an item is not rendered, subsequent
    frames will not run handlers. Only the first time
    an item is non-rendered will trigger the handlers.
    """
    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if item.p_state == NULL:
            raise TypeError(f"Cannot bind handler {self} for {item}")
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef itemState *state = item.p_state
        return not(state.cur.rendered) and state.prev.rendered

cdef class MouseCursorHandler(baseHandler):
    """
    Since the mouse cursor is reset every frame,
    this handler is used to set the cursor automatically
    the frames where this handler is run.
    Typical usage would be in a ConditionalHandler,
    combined with a HoverHandler.
    """
    def __cinit__(self):
        self._mouse_cursor = MouseCursor.ARROW

    @property
    def cursor(self):
        """
        Change the mouse cursor to one of MouseCursor,
        but only for the frames where this handler
        is run.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._mouse_cursor

    @cursor.setter
    def cursor(self, MouseCursor value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if <int>value < imgui.ImGuiMouseCursor_None or \
           <int>value >= imgui.ImGuiMouseCursor_COUNT:
            raise ValueError("Invalid cursor type {value}")
        self._mouse_cursor = value

    cdef void check_bind(self, baseItem item):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return

    cdef bint check_state(self, baseItem item) noexcept nogil:
        return True

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._enabled):
            return
        # Applies only for this frame. Is reset the next frame
        imgui.SetMouseCursor(<imgui.ImGuiMouseCursor>self._mouse_cursor)
        if self._callback is not None:
            if self.check_state(item):
                self.run_callback(item)


"""
Global handlers

A global handler doesn't look at the item states,
but at global states. It is usually attached to the
viewport, but can be attached to items. If attached
to items, the items needs to be visible for the callback
to be executed.
"""

cdef class KeyDownHandler(baseHandler):
    """
    Handler that triggers when a key is held down.

    Properties:
        key (Key): Target key to monitor.
        
    Callback receives:
        - key: The key being pressed
        - duration: How long the key has been held down
    """
    def __cinit__(self):
        self._key = imgui.ImGuiKey_Enter
    @property
    def key(self):
        """
        The key that this handler is monitoring.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return make_Key(self._key)
    @key.setter
    def key(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None or not(is_Key(value)):
            raise TypeError(f"key must be a valid Key, not {value}")
        self._key = <int>make_Key(value)

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef imgui.ImGuiKeyData *key_info
        key_info = imgui.GetKeyData(<imgui.ImGuiKey>self._key)
        if key_info.Down:
            return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        cdef imgui.ImGuiKeyData *key_info
        if not(self._enabled):
            return
        key_info = imgui.GetKeyData(<imgui.ImGuiKey>self._key)
        if key_info.Down:
            self.context.queue_callback_arg1key1float(self._callback, self, item, self._key, key_info.DownDuration)


cdef class KeyPressHandler(baseHandler):
    """
    Handler that triggers when a key is initially pressed.

    Properties:
        key (Key): Target key to monitor
        repeat (bool): Whether to trigger repeatedly while key is held

    Callback receives:
        - key: The key that was pressed
    """
    def __cinit__(self):
        self._key = imgui.ImGuiKey_Enter
        self._repeat = True

    @property
    def key(self):
        """
        The key that this handler is monitoring.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return make_Key(self._key)
    @key.setter
    def key(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None or not(is_Key(value)):
            raise TypeError(f"key must be a valid Key, not {value}")
        self._key = <int>make_Key(value)
    @property
    def repeat(self):
        """
        Whether to trigger repeatedly while a key is held down.

        When True, the callback will be called multiple times as keys remain pressed.
        When False, the callback is only called once when the key is initially pressed.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._repeat
    @repeat.setter
    def repeat(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._repeat = value

    cdef bint check_state(self, baseItem item) noexcept nogil:
        return imgui.IsKeyPressed(<imgui.ImGuiKey>self._key, self._repeat)

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._enabled):
            return
        if imgui.IsKeyPressed(<imgui.ImGuiKey>self._key, self._repeat):
            self.context.queue_callback_arg1key(self._callback, self, item, self._key)


cdef class KeyReleaseHandler(baseHandler):
    """
    Handler that triggers when a key is released.

    Properties:
        key (Key): Target key to monitor

    Callback receives:
        - key: The key that was released
    """
    def __cinit__(self):
        self._key = imgui.ImGuiKey_Enter

    @property
    def key(self):
        """
        The key that this handler is monitoring.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return make_Key(self._key)
    @key.setter
    def key(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None or not(is_Key(value)):
            raise TypeError(f"key must be a valid Key, not {value}")
        self._key = <int>make_Key(value)

    cdef bint check_state(self, baseItem item) noexcept nogil:
        if imgui.IsKeyReleased(<imgui.ImGuiKey>self._key):
            return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        cdef int32_t i
        if not(self._enabled):
            return
        if imgui.IsKeyReleased(<imgui.ImGuiKey>self._key):
            self.context.queue_callback_arg1key(self._callback, self, item, self._key)

cdef inline tuple build_keys_tuple(DCGVector[int32_t] &keys_array):
    """Builds a tuple out of a key array"""
    cdef int i
    cdef list keys = []
    for i in range(<int>keys_array.size()):
        try:
            keys.append(make_Key(keys_array[i]))
        except: # key not found or invalid
            pass
    return tuple(keys)

cdef class AnyKeyPressHandler(baseHandler):
    """
    Handler that triggers when any keyboard key is pressed.
    
    This handler monitors all keys simultaneously
    without creating individual handlers for each key.
    
    Properties:
        repeat (bool): Whether to trigger repeatedly while keys are held down
    
    Callback receives:
        - data: A tuple of Key objects that were pressed this frame
    """
    def __cinit__(self):
        self._repeat = False
        
    @property
    def repeat(self):
        """
        Whether to trigger repeatedly while a key is held down.

        When True, the callback will be called multiple times as keys remain pressed.
        When False, the callback is only called once when the key is initially pressed.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._repeat
        
    @repeat.setter
    def repeat(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._repeat = value
    
    cdef bint check_state(self, baseItem item) noexcept nogil:
        # Check if any key is pressed
        cdef int32_t key
        for key in range(imgui.ImGuiKey_NamedKey_BEGIN, imgui.ImGuiKey_NamedKey_END):
            if imgui.IsKeyPressed(<imgui.ImGuiKey>key, self._repeat):
                return True
        return False
    
    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._enabled) or self._callback is None:
            return
            
        cdef int32_t key, i
        
        # Clear previous keys and collect all pressed keys
        self._keys_vector.clear()
        for key in range(imgui.ImGuiKey_NamedKey_BEGIN, imgui.ImGuiKey_NamedKey_END):
            if imgui.IsKeyPressed(<imgui.ImGuiKey>key, self._repeat):
                self._keys_vector.push_back(key)

        # If we found any pressed keys, convert to Python tuple and queue callback
        if not self._keys_vector.empty():
            with gil:
                # Convert to Python objects
                self.context.queue_callback(
                    self._callback,
                    self,
                    item,
                    build_keys_tuple(self._keys_vector))


cdef class AnyKeyReleaseHandler(baseHandler):
    """
    Handler that triggers when any key is released.
    
    This handler monitors all keys simultaneously
    without creating individual handlers for each key.
    
    Callback receives:
        - data: A tuple of Key objects that were released this frame
    """
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef int key
        for key in range(imgui.ImGuiKey_NamedKey_BEGIN, imgui.ImGuiKey_NamedKey_END):
            if imgui.IsKeyReleased(<imgui.ImGuiKey>key):
                return True
        return False
    
    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._enabled) or self._callback is None:
            return
            
        # Clear and populate the vector with released keys
        self._keys_vector.clear()
        cdef int key, i
        for key in range(imgui.ImGuiKey_NamedKey_BEGIN, imgui.ImGuiKey_NamedKey_END):
            if imgui.IsKeyReleased(<imgui.ImGuiKey>key):
                self._keys_vector.push_back(<int32_t>key)

        # If we found any released keys, send in a single callback
        if not self._keys_vector.empty():
            with gil:
                self.context.queue_callback(
                    self._callback,
                    self,
                    item,
                    build_keys_tuple(self._keys_vector))


cdef inline tuple build_keys_durations_tuple(DCGVector[int32_t] &keys_array,
                                             DCGVector[float] &durations_array):
    """Builds a tuple of tuples from keys and durations arrays"""
    cdef int i
    cdef list keys_durations = []
    for i in range(<int>keys_array.size()):
        try:
            keys_durations.append((make_Key(keys_array[i]), durations_array[i]))
        except: # key not found or invalid
            pass
    return tuple(keys_durations)


cdef class AnyKeyDownHandler(baseHandler):
    """
    Handler that triggers when any key is held down.
    
    This native implementation efficiently monitors all keys simultaneously
    without creating individual handlers for each key.
    
    Callback receives:
        - data: A tuple of tuples, each containing (Key, duration), where:
          - Key: The specific key being held down
          - duration: How long the key has been held (in seconds)
    """   
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef imgui.ImGuiKeyData *key_data
        cdef int key
        for key in range(imgui.ImGuiKey_NamedKey_BEGIN, imgui.ImGuiKey_NamedKey_END):
            key_data = imgui.GetKeyData(<imgui.ImGuiKey>key)
            if key_data.Down:
                return True
        return False
    
    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._enabled) or self._callback is None:
            return
            
        cdef imgui.ImGuiKeyData *key_data
        
        # Clear and populate vectors with currently held keys and durations
        self._keys_vector.clear()
        self._durations_vector.clear()
        cdef int key, i
        
        for key in range(imgui.ImGuiKey_NamedKey_BEGIN, imgui.ImGuiKey_NamedKey_END):
            key_data = imgui.GetKeyData(<imgui.ImGuiKey>key)
            if key_data.Down:
                self._keys_vector.push_back(<int32_t>key)
                self._durations_vector.push_back(key_data.DownDuration)
                
        # If we found any keys being held down, send in a single callback
        if not self._keys_vector.empty():
            with gil:
                self.context.queue_callback(
                    self._callback,
                    self,
                    item,
                    build_keys_durations_tuple(self._keys_vector, self._durations_vector))


cdef class MouseClickHandler(baseHandler):
    """
    Handler for mouse button clicks anywhere.

    Properties:
        button (MouseButton): Target mouse button to monitor
        repeat (bool): Whether to trigger repeatedly while button held

    Callback receives:
        - button: The button that was clicked
    """
    def __cinit__(self):
        self._button = MouseButton.LEFT
        self._repeat = False
    @property
    def button(self):
        """
        The mouse button that this handler is monitoring.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, MouseButton value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value < MouseButton.LEFT or value > MouseButton.X2:
            raise ValueError(f"Invalid button {value} passed to {self}")
        self._button = value
    @property
    def repeat(self):
        """
        Whether to trigger repeatedly while a mouse button is held down.

        When True, the callback will be called multiple times as the button remains pressed.
        When False, the callback is only called once when the button is initially clicked.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._repeat
    @repeat.setter
    def repeat(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._repeat = value

    cdef bint check_state(self, baseItem item) noexcept nogil:
        if imgui.IsMouseClicked(<int>self._button, self._repeat):
            return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._enabled):
            return
        if imgui.IsMouseClicked(<int>self._button, self._repeat):
            self.context.queue_callback_arg1button(self._callback, self, item, <int>self._button)


cdef class MouseDoubleClickHandler(baseHandler):
    """
    Handler for mouse button double-clicks anywhere.

    Properties:
        button (MouseButton): Target mouse button to monitor

    Callback receives:
        - button: The button that was double-clicked
    """
    def __cinit__(self):
        self._button = MouseButton.LEFT
    @property
    def button(self):
        """
        The button this handler monitors.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, MouseButton value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value < MouseButton.LEFT or value > MouseButton.X2:
            raise ValueError(f"Invalid button {value} passed to {self}")
        self._button = value

    cdef bint check_state(self, baseItem item) noexcept nogil:
        if imgui.IsMouseDoubleClicked(<int>self._button):
            return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._enabled):
            return
        if imgui.IsMouseDoubleClicked(<int>self._button):
            self.context.queue_callback_arg1button(self._callback, self, item, <int>self._button)


cdef class MouseDownHandler(baseHandler):
    """
    Handler for mouse button being held down.

    Properties:
        button (MouseButton): Target mouse button to monitor

    Callback receives:
        - button: The button being held
        - duration: How long the button has been held
    """
    def __cinit__(self):
        self._button = MouseButton.LEFT

    @property
    def button(self):
        """
        The button this handler monitors.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, MouseButton value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value < MouseButton.LEFT or value > MouseButton.X2:
            raise ValueError(f"Invalid button {value} passed to {self}")
        self._button = value

    cdef bint check_state(self, baseItem item) noexcept nogil:
        if imgui.IsMouseDown(<int>self._button):
            return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._enabled):
            return
        if imgui.IsMouseDown(<int>self._button):
            self.context.queue_callback_arg1button1float(self._callback, self, item, <int>self._button, imgui.GetIO().MouseDownDuration[<int>self._button])


cdef class MouseDragHandler(baseHandler):
    """
    Handler for mouse dragging motions.

    Properties:
        button (MouseButton): Target mouse button for drag
        threshold (float): Movement threshold to trigger drag.
                         Negative means use default.

    Callback receives:
        - button: The button used for dragging
        - delta_x: Horizontal drag distance
        - delta_y: Vertical drag distance
    """
    def __cinit__(self):
        self._button = MouseButton.LEFT
        self._threshold = -1 # < 0. means use default

    @property
    def button(self):
        """
        The button this handler monitors.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, MouseButton value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value < MouseButton.LEFT or value > MouseButton.X2:
            raise ValueError(f"Invalid button {value} passed to {self}")
        self._button = value
    @property
    def threshold(self):
        """
        The movement threshold to trigger a drag.
        If negative, uses the default threshold.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._threshold
    @threshold.setter
    def threshold(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._threshold = value

    cdef bint check_state(self, baseItem item) noexcept nogil:
        if imgui.IsMouseDragging(<int>self._button, self._threshold):
            return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        cdef imgui.ImVec2 delta
        if not(self._enabled):
            return
        if imgui.IsMouseDragging(<int>self._button, self._threshold):
            delta = imgui.GetMouseDragDelta(<int>self._button, self._threshold)
            self.context.queue_callback_arg1button2float(self._callback, self, item, <int>self._button, delta.x, delta.y)


cdef class MouseMoveHandler(baseHandler):
    """
    Handler that triggers when the mouse cursor moves.

    Callback receives:
        - x: New mouse x position
        - y: New mouse y position
        
    Note:
        Position is relative to the viewport.
    """
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef imgui.ImGuiIO io = imgui.GetIO()
        if not(imgui.IsMousePosValid()):
            return False
        if io.MousePos.x != io.MousePosPrev.x or \
           io.MousePos.y != io.MousePosPrev.y:
            return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._enabled):
            return
        if not(imgui.IsMousePosValid()):
            return
        cdef imgui.ImGuiIO io = imgui.GetIO()
        if io.MousePos.x != io.MousePosPrev.x or \
           io.MousePos.y != io.MousePosPrev.y:
            self.context.queue_callback_arg2float(self._callback, self, item, io.MousePos.x, io.MousePos.y)


cdef class MouseReleaseHandler(baseHandler):
    """
    Handler for mouse button releases.

    Properties:
        button (MouseButton): Target mouse button to monitor

    Callback receives:  
        - button: The button that was released
    """
    def __cinit__(self):
        self._button = MouseButton.LEFT

    @property
    def button(self):
        """
        The button this handler monitors.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._button
    @button.setter
    def button(self, MouseButton value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value < MouseButton.LEFT or value > MouseButton.X2:
            raise ValueError(f"Invalid button {value} passed to {self}")
        self._button = value

    cdef bint check_state(self, baseItem item) noexcept nogil:
        if imgui.IsMouseReleased(<int>self._button):
            return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._enabled):
            return
        if imgui.IsMouseReleased(<int>self._button):
            self.context.queue_callback_arg1button(self._callback, self, item, <int>self._button)

cdef class MouseWheelHandler(baseHandler):
    """
    A handler that monitors mouse wheel scrolling events.

    Detects both vertical (default) and horizontal scrolling movements.
    For horizontal scrolling, either use Shift+vertical wheel or a horizontal
    wheel if available on the input device.

    Properties:
        horizontal (bool): When True, monitors horizontal scrolling instead of vertical.
                         Defaults to False (vertical scrolling).

    Note:
        Holding Shift while using vertical scroll wheel generates horizontal scroll events.
    """
    def __cinit__(self, *args, **kwargs):
        self._horizontal = False

    @property
    def horizontal(self):
        """
        Whether to look at the horizontal wheel
        instead of the vertical wheel.

        NOTE: Shift+ vertical wheel => horizontal wheel
        """
        return self._horizontal

    @horizontal.setter
    def horizontal(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._horizontal = value

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef imgui.ImGuiIO io = imgui.GetIO()
        if self._horizontal:
            if abs(io.MouseWheelH) > 0.:
                return True
        else:
            if abs(io.MouseWheel) > 0.:
                return True
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._enabled):
            return
        cdef imgui.ImGuiIO io = imgui.GetIO()
        if self._horizontal:
            if abs(io.MouseWheelH) > 0.:
                self.context.queue_callback_arg1float(self._callback, self, item, io.MouseWheelH)
        else:
            if abs(io.MouseWheel) > 0.:
                self.context.queue_callback_arg1float(self._callback, self, item, io.MouseWheel)


cdef class MouseInRect(baseHandler):
    """
    Handler that triggers when the mouse is inside a predefined rectangle.

    The rectangle is defined in viewport coordinates.
    
    Properties:
        rect: A tuple (x1, y1, x2, y2) or Rect object defining the area to monitor
        
    Callback receives:
        - x: Current mouse x position 
        - y: Current mouse y position
    """
    def __cinit__(self):
        self._x1 = 0
        self._y1 = 0
        self._x2 = 0
        self._y2 = 0

    @property
    def rect(self):
        """Rectangle to test in viewport coordinates"""
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef double[4] rect_data = [self._x1, self._y1, self._x2, self._y2]
        return Rect.build(rect_data)

    @rect.setter 
    def rect(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef double[4] rect_data
        read_rect(rect_data, value)
        self._x1 = min(rect_data[0], rect_data[2])
        self._y1 = min(rect_data[1], rect_data[3])
        self._x2 = max(rect_data[0], rect_data[2])
        self._y2 = max(rect_data[1], rect_data[3])

    cdef bint check_state(self, baseItem item) noexcept nogil:
        if not(imgui.IsMousePosValid()):
            return False
        cdef imgui.ImGuiIO io = imgui.GetIO()
        return self._x1 <= io.MousePos.x and \
               self._y1 <= io.MousePos.y and \
               self._x2 > io.MousePos.x and \
               self._y2 > io.MousePos.y

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._enabled):
            return
        if not(imgui.IsMousePosValid()):
            return
        cdef imgui.ImGuiIO io = imgui.GetIO()
        if self._x1 <= io.MousePos.x and \
           self._y1 <= io.MousePos.y and \
           self._x2 > io.MousePos.x and \
           self._y2 > io.MousePos.y:
            self.context.queue_callback_arg2float(self._callback, self, item, io.MousePos.x, io.MousePos.y)


cdef inline tuple build_buttons_tuple(DCGVector[int32_t] &buttons_array):
    """Builds a tuple out of a button array"""
    cdef int i
    cdef list buttons = []
    for i in range(<int>buttons_array.size()):
        try:
            buttons.append(MouseButton(buttons_array[i]))
        except: # button not found or invalid
            pass
    return tuple(buttons)


cdef class AnyMouseClickHandler(baseHandler):
    """
    Handler that triggers when any mouse button is clicked.
    
    This handler monitors all mouse buttons simultaneously
    without creating individual handlers for each button.
    
    Properties:
        repeat (bool): Whether to trigger repeatedly while buttons are held
    
    Callback receives:
        - data: A tuple of MouseButton objects that were clicked this frame
    """
    def __cinit__(self):
        self._repeat = False
        
    @property
    def repeat(self):
        """
        Whether to trigger repeatedly while a button is held down.
        
        When True, the callback will be called multiple times as buttons remain pressed.
        When False, the callback is only called once when the button is initially pressed.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._repeat
        
    @repeat.setter
    def repeat(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._repeat = value
    
    cdef bint check_state(self, baseItem item) noexcept nogil:
        # Check if any mouse button is clicked
        cdef int button
        # Check all standard mouse buttons (LEFT, RIGHT, MIDDLE, X1, X2)
        for button in range(<int>MouseButton.LEFT, <int>MouseButton.X2 + 1):
            if imgui.IsMouseClicked(button, self._repeat):
                return True
        return False
    
    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._enabled) or self._callback is None:
            return
            
        # Clear and collect all clicked buttons
        self._buttons_vector.clear()
        cdef int button, i
        for button in range(<int>MouseButton.LEFT, <int>MouseButton.X2 + 1):
            if imgui.IsMouseClicked(button, self._repeat):
                self._buttons_vector.push_back(<int32_t>button)

        # If we found any clicked buttons, send to the callback
        if not self._buttons_vector.empty():
            with gil:
                self.context.queue_callback(
                    self._callback,
                    self,
                    item,
                    build_buttons_tuple(self._buttons_vector))


cdef class AnyMouseDoubleClickHandler(baseHandler):
    """
    Handler that triggers when any mouse button is double-clicked.
    
    This handler monitors all mouse buttons simultaneously
    without creating individual handlers for each button.
    
    Callback receives:
        - data: A tuple of MouseButton objects that were double-clicked this frame
    """
    
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef int button
        for button in range(<int>MouseButton.LEFT, <int>MouseButton.X2 + 1):
            if imgui.IsMouseDoubleClicked(button):
                return True
        return False
    
    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._enabled) or self._callback is None:
            return
            
        self._buttons_vector.clear()
        cdef int button, i
        for button in range(<int>MouseButton.LEFT, <int>MouseButton.X2 + 1):
            if imgui.IsMouseDoubleClicked(button):
                self._buttons_vector.push_back(<int32_t>button)

        if not self._buttons_vector.empty():
            with gil:
                self.context.queue_callback(
                    self._callback,
                    self,
                    item,
                    build_buttons_tuple(self._buttons_vector))


cdef class AnyMouseReleaseHandler(baseHandler):
    """
    Handler that triggers when any mouse button is released.
    
    This handler monitors all mouse buttons simultaneously
    without creating individual handlers for each button.
    
    Callback receives:
        - data: A tuple of MouseButton objects that were released this frame
    """
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef int button
        for button in range(<int>MouseButton.LEFT, <int>MouseButton.X2 + 1):
            if imgui.IsMouseReleased(button):
                return True
        return False
    
    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._enabled) or self._callback is None:
            return
            
        self._buttons_vector.clear()
        cdef int button, i
        for button in range(<int>MouseButton.LEFT, <int>MouseButton.X2 + 1):
            if imgui.IsMouseReleased(button):
                self._buttons_vector.push_back(<int32_t>button)

        if not self._buttons_vector.empty():
            with gil:
                self.context.queue_callback(
                    self._callback,
                    self,
                    item,
                    build_buttons_tuple(self._buttons_vector))


cdef inline tuple build_buttons_durations_tuple(DCGVector[int32_t] &buttons_array,
                                                DCGVector[float] &durations_array):
    """Builds a tuple of tuples from buttons and durations arrays"""
    cdef int i
    cdef list buttons_durations = []
    for i in range(<int>buttons_array.size()):
        try:
            buttons_durations.append((MouseButton(buttons_array[i]), durations_array[i]))
        except: # button not found or invalid
            pass
    return tuple(buttons_durations)


cdef class AnyMouseDownHandler(baseHandler):
    """
    Handler that triggers when any mouse button is held down.
    
    This handler monitors all mouse buttons simultaneously
    without creating individual handlers for each button.
    
    Callback receives:
        - data: A tuple of tuples, each containing (MouseButton, duration), where:
          - MouseButton: The specific button being held down
          - duration: How long the button has been held (in seconds)
    """
    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef int button
        for button in range(<int>MouseButton.LEFT, <int>MouseButton.X2 + 1):
            if imgui.IsMouseDown(button):
                return True
        return False
    
    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._enabled) or self._callback is None:
            return
            
        self._buttons_vector.clear()
        self._durations_vector.clear()
        cdef int button, i
        cdef imgui.ImGuiIO io = imgui.GetIO()
        
        for button in range(<int>MouseButton.LEFT, <int>MouseButton.X2 + 1):
            if imgui.IsMouseDown(button):
                self._buttons_vector.push_back(<int32_t>button)
                self._durations_vector.push_back(io.MouseDownDuration[button])
                
        if not self._buttons_vector.empty():
            with gil:
                self.context.queue_callback(
                    self._callback,
                    self,
                    item,
                    build_buttons_durations_tuple(self._buttons_vector, self._durations_vector))


cdef class DragDropSourceHandler(baseHandler):
    """
    *EXPERIMENTAL* Handler for drag-and-drop source events.

    When called, this handler allows initiating a drag-and-drop operation.

    Wrap it in a ConditionalHandler to control when it is active.

    If set, the callback will be called when the drag starts.

    Callback receives:
        - sender: This handler instance
        - target: The item that is being dragged
        - data: A tuple containing:
            - A dataclass containing a copy of the state field (if any)
                of the item being dragged
            - (mouse_x, mouse_y) the mouse position relative to the viewport.
    """

    @property
    def drag_type(self):
        """
        An optional string that describes the type of the drag operation.
        This is used to identify the drag operation in the target handler.

        If not set, the default type "item" will be used.
        If set, it will be appended to "item_" to form the payload type.
        For example, if drag_type is "person", the payload type will be "item_person".

        The target must have an exact match for this type
        to accept the drag operation.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef str name = string_to_str(self._drag_type)
        if name == "item":
            return ""
        return name[5:]  # Remove "item_" prefix if present

    @drag_type.setter
    def drag_type(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef str name = "item"
        if value is not None and value != "":
            name = "item_" + value
        if len(name) > 30:
            raise ValueError("Drag type string is too long, must be 30 characters or less")
        self._drag_type = string_from_str(name)

#    @property -> doesn't seem to work
#    def no_disable_hover(self):
#        """
#        If True, the hover state of items below the mouse cursor
#        during the drag operation will not be cleared.
#
#        This has flag only has an effect for the hovered state,
#        but not on the visuals managed by ImGui.
#        """
#        cdef unique_lock[DCGMutex] m
#        lock_gil_friendly(m, self.mutex)
#        return (self._flags & <int32_t>imgui.ImGuiDragDropFlags_SourceNoDisableHover) != 0
#
#    @no_disable_hover.setter
#    def no_disable_hover(self, bint value):
#        cdef unique_lock[DCGMutex] m
#        lock_gil_friendly(m, self.mutex)
#        if value:
#            self._flags |= <int32_t>imgui.ImGuiDragDropFlags_SourceNoDisableHover
#        else:
#            self._flags &= ~<int32_t>imgui.ImGuiDragDropFlags_SourceNoDisableHover

    @property
    def no_open_on_hold(self):
        """
        Disables the behaviour that holding the mouse during the drag
        over an openable item (TreeNode, etc) opens it.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & <int32_t>imgui.ImGuiDragDropFlags_SourceNoHoldToOpenOthers) != 0

    @no_open_on_hold.setter
    def no_open_on_hold(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value:
            self._flags |= <int32_t>imgui.ImGuiDragDropFlags_SourceNoHoldToOpenOthers
        else:
            self._flags &= ~<int32_t>imgui.ImGuiDragDropFlags_SourceNoHoldToOpenOthers

    @property
    def immediate_expiration(self):
        """
        If True, the drag expires as soon as this handler
        is not triggered a single frame, rather than when
        the mouse is released.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & <int32_t>imgui.ImGuiDragDropFlags_PayloadAutoExpire) != 0

    @immediate_expiration.setter
    def immediate_expiration(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value:
            self._flags |= <int32_t>imgui.ImGuiDragDropFlags_PayloadAutoExpire
        else:
            self._flags &= ~<int32_t>imgui.ImGuiDragDropFlags_PayloadAutoExpire

    @property
    def overwrite(self):
        """
        If True, overwrites any previous drag operation already occuring
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._overwrite

    @overwrite.setter
    def overwrite(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._overwrite = value


    cdef void check_bind(self, baseItem item):
        if item is None:
            raise ValueError("DragDropSourceHandler must be bound to a valid item")
        return # all non None items are acceptable sources

    cdef bint check_state(self, baseItem item) noexcept nogil:
        # Check if we would drag if we could
        if self._overwrite:
            return True
        return imgui.GetDragDropPayload() == NULL

    cdef int _trigger_callback(self, baseItem item):
        state_copy = None
        try:
            state_copy = item.state.snapshot()
        except:
            pass
        cdef float mouse_x = imgui.GetIO().MousePos.x
        cdef float mouse_y = imgui.GetIO().MousePos.y
        self.context.queue_callback(
            self._callback,
            self,
            item,
            (state_copy, (mouse_x, mouse_y))
        )

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not self.check_state(item):
            return
        cdef bint submitted = False
        cdef void_p[1] data
        if imgui.BeginDragDropSource(
            self._flags |
            imgui.ImGuiDragDropFlags_SourceNoPreviewTooltip | # Disable submitting tooltip below. Will be done by the user outside
            imgui.ImGuiDragDropFlags_SourceExtern # Ignore the last item states and always submit
            ):
            # We store a pointer to the item, but we won't use it for accessing it.
            # (we don't handle refcount either). It is used for validation that the
            # drag-drop we manage has the correct expected item.
            data[0] = <void_p><PyObject*>item
            imgui.SetDragDropPayload(self._drag_type.c_str(), &data[0],
                                     sizeof(void_p), imgui.ImGuiCond_Always)
            submitted = True
            imgui.EndDragDropSource()

        if submitted:
            with gil:
                self.context.viewport.drag_drop = item
                self._trigger_callback(item)
                


cdef class DragDropActiveHandler(baseHandler):
    """
    *EXPERIMENTAL* Handler that is triggered when a drag
    and drop event is occuring for the attached item,
    or for any item.

    The accepted_types attribute can be used
    to define a list of drag-and-drop types
    to accept. Defaults is any type.

    The any_target attribute defines if the condition
    should be raised if any item is being dragged,
    or only the item this handler refers to.

    The callback data field will contain:
        - type: The type of the payload (as a string)
        - payload:
            If the type starts with "item", it will be the item that is being dragged.
            If the type is "text" or "file", it will be None (unknown until drop).
            If the type starts with "_COL", it will be a tuple of floats
                representing the color (RGB or RGBA).
            The content for other types is undefined.
    """

    @property
    def accepted_types(self):
        """
        List of text values corresponding to the types of payloads
        that this handler accepts.

        If empty, it will accept any type.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int i
        for i in range(<int>self._items.size()):
            result.append(string_to_str(self._items[i]))
        return result

    @accepted_types.setter
    def accepted_types(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._items.clear()
        if value is None:
            return
        if isinstance(value, str):
            self._items.push_back(string_from_str(value))
        elif PySequence_Check(value) > 0:
            for v in value:
                self._items.push_back(string_from_str(v))
        else:
            raise ValueError(f"Invalid type {type(value)} passed as items. Expected array of strings")

    @property
    def any_target(self):
        """
        If True, the handler will be triggered
        when any item is being dragged, in regards to the
        accepted types. Else it will only be triggered
        when the item this handler is attached to is being dragged.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._any_target

    @any_target.setter
    def any_target(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._any_target = value

    @cython.final
    cdef bint _check_payload_type(self, const void *payload) noexcept nogil:
        if self._items.size() == 0:
            return True
        cdef int i
        for i in range(<int>self._items.size()):
            if (<const imgui.ImGuiPayload *>payload).IsDataType(self._items[i].c_str()):
                return True
        return False

    @cython.final
    cdef bint _target_check(self, baseItem item, const void *payload) noexcept nogil:
        if self._any_target:
            return True
        if (<const imgui.ImGuiPayload *>payload).DataSize != sizeof(void_p):
            return False
        cdef void *expected = <PyObject*>item
        cdef void *actual_ptr = dereference(<void_p*>(<const imgui.ImGuiPayload *>payload).Data)
        return expected == actual_ptr

    @cython.final
    cdef object _extract_payload_data(self, baseItem item, const void* payload_p):
        cdef const imgui.ImGuiPayload* payload = <const imgui.ImGuiPayload*> payload_p
        cdef str payload_type = bytes(payload.DataType).decode('utf-8')
        cdef bytes raw_data
        cdef char* data_ptr
        cdef float* color_data
        cdef int start
        
        # For item drag & drop
        if payload_type.startswith("item"):
            if payload.DataSize == sizeof(void_p) and \
               (<PyObject**>payload.Data)[0] == <PyObject*>self.context.viewport.drag_drop:
                target_item = self.context.viewport.drag_drop
                return (payload_type, target_item)
        
        # For text and files from OS
        elif strcmp(payload.DataType, "text") == 0:
            return ("text", None)

        elif strcmp(payload.DataType, "file") == 0:
            return ("file", None)

        # For color picker (3 floats - RGB)
        elif strcmp(payload.DataType, "_COL3F") == 0:
            if payload.DataSize == sizeof(float) * 3:
                color_data = <float*>payload.Data
                return (payload_type, (color_data[0], color_data[1], color_data[2]))
        
        # For color picker (4 floats - RGBA)
        elif strcmp(payload.DataType, "_COL4F") == 0:
            if payload.DataSize == sizeof(float) * 4:
                color_data = <float*>payload.Data
                return (payload_type, (color_data[0], color_data[1], color_data[2], color_data[3]))
        
        # For any other type, return the raw data size (we don't interpret it)
        elif payload.DataSize > 0:
            raw_data = bytes(<char*>payload.Data, payload.DataSize)
            # Return the raw data as a bytes object
            return (payload_type, raw_data)
        return (payload_type, None)

    @cython.final
    cdef int _trigger_callback(self, baseItem item, const void* payload_p):
        cdef const imgui.ImGuiPayload *payload = <const imgui.ImGuiPayload*>payload_p
        payload_type, payload_data = self._extract_payload_data(item, payload_p)

        self.context.queue_callback(
            self._callback,
            self,
            item,
            (payload_type, payload_data)
        )
        return 0

    cdef void check_bind(self, baseItem item):
        if item is None:
            raise ValueError("DragDropActiveHandler must be bound to a valid item")
        return # all non None items are acceptable sources

    cdef bint check_state(self, baseItem item) noexcept nogil:
        cdef const imgui.ImGuiPayload *payload = imgui.GetDragDropPayload()
        if payload == NULL:
            return False
        cdef bint type_check = self._check_payload_type(<const void*>payload)
        if not type_check:
            return False
        cdef bint target_check = self._target_check(item, <const void*>payload)
        if not target_check:
            return False
        return True

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not self.check_state(item):
            return
        cdef const imgui.ImGuiPayload *payload = imgui.GetDragDropPayload()
        # Because of check_state we know the payload is valid
        with gil:
            self._trigger_callback(item, <const void*>payload)



cdef class DragDropTargetHandler(baseHandler):
    """
    *EXPERIMENTAL* Handler for drag-and-drop target events.

    When called, this handler allows receiving a drag-and-drop operation
    on the attached item.

    The expected usage is to add this handler to your list
    of handlers without any conditions, so it is always active.

    The callback will be called when the drop occurs.

    Callback receives:
        - sender: This handler instance
        - target: The item that is being dropped onto
        - data: A tuple containing:
            - type: The type of the payload (as a string)
            - payload: The dropped data.
                - If type starts with "item", it will be the item that was dropped.
                - If type is "text", it will be a list of strings (OS initiated).
                - If type is "file", it will be a list of file paths (OS initiated).
                - If type is "_COL3F" (from a color picker), 
                    it will be a tuple of 3 floats representing the color.
                - If type is "_COL4F" (from a color picker), 
                    it will be a tuple of 4 floats representing the color with alpha.
                - The content for other types is undefined.
            - A dataclass containing a copy of the state field (if any)
                of the target item.
            - (mouse_x, mouse_y): The mouse position relative to the viewport
                when the drop occurred.

    Note for "text" and "file" types:
        DearCyGui doesn't have a way to know before the drop what the content
        of the payload will be. Thus the type will always be "text" until
        the drop occurs. In addition, the content of the payload may
        arrive later than the mouse release event. DearCyGui will remember
        the parameters of the drop and call the callback when the content
        is available. In practice that only means your callback may be
        a little delayed compared to the other types.
    """

    @property
    def accepted_types(self):
        """
        List of text values corresponding to the types of payloads
        that this handler accepts.

        If empty, it will accept any type.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int i
        for i in range(<int>self._items.size()):
            result.append(string_to_str(self._items[i]))
        return result

    @accepted_types.setter
    def accepted_types(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._items.clear()
        if value is None:
            return
        if isinstance(value, str):
            self._items.push_back(string_from_str(value))
        elif PySequence_Check(value) > 0:
            for v in value:
                self._items.push_back(string_from_str(v))
        else:
            raise ValueError(f"Invalid type {type(value)} passed as items. Expected array of strings")

    @property
    def no_draw_default_rect(self):
        """
        If True, the default highlight rectangle will not be drawn
        when hovering over the target item during a drag-and-drop operation.

        Note the rectangle is never drawn if the drag type does not match
        the accepted types of this handler.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._flags & <int32_t>imgui.ImGuiDragDropFlags_AcceptNoDrawDefaultRect) != 0

    @no_draw_default_rect.setter
    def no_draw_default_rect(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value:
            self._flags |= <int32_t>imgui.ImGuiDragDropFlags_AcceptNoDrawDefaultRect
        else:
            self._flags &= ~<int32_t>imgui.ImGuiDragDropFlags_AcceptNoDrawDefaultRect

    cdef void check_bind(self, baseItem item):
        if item is None:
            raise ValueError("DragDropTargetHandler must be bound to a valid item")
        return # all non None items are acceptable sources

    cdef bint check_state(self, baseItem item) noexcept nogil:
        return False

    @cython.final
    cdef object _extract_payload_data(self, baseItem item, const void* payload_p):
        cdef const imgui.ImGuiPayload* payload = <const imgui.ImGuiPayload*> payload_p
        cdef str payload_type = bytes(payload.DataType).decode('utf-8')
        cdef bytes raw_data
        cdef char* data_ptr
        cdef float* color_data
        cdef int start
        
        # For item drag & drop
        if payload_type.startswith("item"):
            if payload.DataSize == sizeof(void_p) and \
               (<PyObject**>payload.Data)[0] == <PyObject*>self.context.viewport.drag_drop:
                target_item = self.context.viewport.drag_drop
                self.context.viewport.drag_drop = None  # Reset the stored drag item
                return (payload_type, target_item)
        
        # For text and files from OS
        elif strcmp(payload.DataType, "text") == 0 or strcmp(payload.DataType, "file") == 0:
            if self.context.viewport.os_drop_ready:
                element_list = []
                for i in range(<int>self.context.viewport.drop_data.size()):
                    element_list.append(string_to_str(self.context.viewport.drop_data[i]))
                return ("file" if self.context.viewport.drop_is_file_type else "text",
                        element_list)
            return ("pending", None)  # Indicate that the data is pending

        # For color picker (3 floats - RGB)
        elif strcmp(payload.DataType, "_COL3F") == 0:
            if payload.DataSize == sizeof(float) * 3:
                color_data = <float*>payload.Data
                return (payload_type, (color_data[0], color_data[1], color_data[2]))
        
        # For color picker (4 floats - RGBA)
        elif strcmp(payload.DataType, "_COL4F") == 0:
            if payload.DataSize == sizeof(float) * 4:
                color_data = <float*>payload.Data
                return (payload_type, (color_data[0], color_data[1], color_data[2], color_data[3]))
        
        # For any other type, return the raw data size (we don't interpret it)
        elif payload.DataSize > 0:
            raw_data = bytes(<char*>payload.Data, payload.DataSize)
            # Return the raw data as a bytes object
            return (payload_type, raw_data)
        return (payload_type, None)

    @cython.final
    cdef int _trigger_callback(self, baseItem item, const void* payload):
        cdef str payload_type
        cdef object payload_data
        payload_type, payload_data = self._extract_payload_data(item, payload)
        state_copy = None
        try:
            state_copy = item.state.snapshot()
        except:
            pass
        cdef float mouse_x = imgui.GetIO().MousePos.x
        cdef float mouse_y = imgui.GetIO().MousePos.y
        if payload_type == "pending":
            # If the payload is pending, we will call the callback later
            self.context.viewport.pending_drop = (self._callback, self, item, state_copy, mouse_x, mouse_y)
            return 0
        self.context.queue_callback(
            self._callback,
            self,
            item,
            (payload_type, payload_data, state_copy, (mouse_x, mouse_y))
        )
        return 0

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        cdef const imgui.ImGuiPayload *received_payload = NULL
        cdef int i

        if imgui.BeginDragDropTarget():
            if self._items.size() == 0:
                # accept any type:
                received_payload = imgui.AcceptDragDropPayload(NULL, self._flags)
            else:
                for i in range(<int>self._items.size()):
                    received_payload = imgui.AcceptDragDropPayload(self._items[i].c_str(), self._flags)
                    if received_payload != NULL:
                        break
            if received_payload != NULL:
                # We have a valid payload, let's process it
                with gil:
                    self._trigger_callback(item, <const void*>received_payload)
            imgui.EndDragDropTarget()