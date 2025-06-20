#cython: freethreading_compatible=True

cimport dearcygui as dcg
import dearcygui as dcg

from dearcygui.utils.draw_draggable import DragPoint # To avoid breaking compatibility with v0.1.0

from dearcygui.c_types cimport unique_lock, DCGMutex
from cpython.ref cimport PyObject
cimport dearcygui.backends.time as ctime
from libcpp.map cimport pair
from libcpp.deque cimport deque
from libcpp.set cimport set
from libc.stdint cimport int32_t
from libc.math cimport fmod


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
    cdef bint _no_wake
    cdef double _time_modulus
    cdef int32_t  _last_index
    cdef deque[pair[double, PyObject*]] _expiry_times # Weak ref

    def __cinit__(self):
        self._allow_no_children = False
        self._no_skip_children = False
        self._no_wake = False
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
    def no_wake(self):
        """
        If set, disables asking the viewport to refresh
        at the target time of the next element in the stream.
        """
        cdef unique_lock[DCGMutex] m
        dcg.lock_gil_friendly(m, self.mutex)
        return self._no_wake

    @no_wake.setter
    def no_wake(self, bint value):
        cdef unique_lock[DCGMutex] m
        dcg.lock_gil_friendly(m, self.mutex)
        self._no_wake = value

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
        if not(self._no_wake):
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
