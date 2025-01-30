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
#distutils: language=c++

from libcpp cimport bool
import traceback

cimport cython
cimport cython.view
from cython.operator cimport dereference
from libc.string cimport memset, memcpy

# This file is the only one that is linked to the C++ code
# Thus it is the only one allowed to make calls to it

from dearcygui.wrapper cimport *
from dearcygui.backends.backend cimport SDLViewport, platformViewport, GLContext
# We use unique_lock rather than lock_guard as
# the latter doesn't support nullary constructor
# which causes trouble to cython
from dearcygui.font import AutoFont

from concurrent.futures import Executor, ThreadPoolExecutor
from libcpp.cmath cimport floor, ceil
from libcpp.cmath cimport round as cround
from libcpp.set cimport set as cpp_set
from libcpp.vector cimport vector
from libc.math cimport M_PI, INFINITY
from libc.stdint cimport uintptr_t, uint32_t, int32_t, int64_t

cimport dearcygui.backends.time as ctime

from .c_types cimport unique_lock, recursive_mutex, mutex, defer_lock_t
from .imgui_types cimport *
from .types cimport *
from .types import ChildType, Key, KeyMod, KeyOrMod

import os
import numpy as np
cimport numpy as cnp
cnp.import_array()

import time as python_time
import threading
import weakref



"""
Each .so has its own current context. To be able to work
with various .so and contexts, we must ensure the correct
context is current. The call is almost free as it's just
a pointer that is set.
If you create your own custom rendering objects, you must ensure
that you link to the same version of ImGui (ImPlot/ImNodes if
applicable) and you must call ensure_correct_* at the start
of your draw() overrides
"""

cdef inline void ensure_correct_imgui_context(Context context) noexcept nogil:
    imgui.SetCurrentContext(<imgui.ImGuiContext*>context.imgui_context)

cdef inline void ensure_correct_implot_context(Context context) noexcept nogil:
    implot.SetCurrentContext(<implot.ImPlotContext*>context.implot_context)

cdef inline void ensure_correct_imnodes_context(Context context) noexcept nogil:
    imnodes.SetCurrentContext(<imnodes.ImNodesContext*>context.imnodes_context)

cdef inline void ensure_correct_im_context(Context context) noexcept nogil:
    ensure_correct_imgui_context(context)
    ensure_correct_implot_context(context)
    ensure_correct_imnodes_context(context)


cdef class BackendRenderingContext:
    """
    Object used to create contexts
    with object sharing with the internal context.
    """
    cdef Context context
    def __init__(self):
        raise ValueError("Cannot create a BackendRenderingContext directly. Use the context object.")

    @property
    def name(self):
        return "GL" # For now only GL is supported

    def __enter__(self):
        # TODO: check thread safety
        (<platformViewport*>self.context.viewport._platform).makeUploadContextCurrent()
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        (<platformViewport*>self.context.viewport._platform).releaseUploadContext()

    @staticmethod
    cdef BackendRenderingContext from_context(Context context):
        cdef BackendRenderingContext rendering_context = BackendRenderingContext.__new__(BackendRenderingContext)
        rendering_context.context = context
        return rendering_context

cdef class SharedGLContext:
    """
    Object used to create shared OpenGL contexts
    with the internal context.
    """
    cdef GLContext* gl_context
    cdef Context context
    cdef mutex mutex
    def __init__(self):
        raise ValueError("Cannot create a SharedGLContext directly.")
    def __cinit__(self):
        self.gl_context = NULL

    def __dealloc__(self):
        if self.gl_context != NULL:
            del self.gl_context

    def make_current(self):
        """ Make the attached context current.
        Only one thread can make the context current at a time.
        release() has to be called after make_current()
        """
        assert(self.gl_context != NULL)
        self.mutex.lock()
        self.gl_context.makeCurrent()

    def release(self):
        assert(self.gl_context != NULL)
        """ Release the attached context """
        self.gl_context.release()
        self.mutex.unlock()

    def destroy(self):
        """ Destroy the attached context """
        if self.gl_context != NULL:
            del self.gl_context
            self.gl_context = NULL

    def __enter__(self):
        assert(self.gl_context != NULL)
        self.mutex.lock()
        self.gl_context.makeCurrent()
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        assert(self.gl_context != NULL)
        self.gl_context.release()
        self.mutex.unlock()

    @staticmethod
    cdef SharedGLContext from_context(Context context, GLContext* gl_context):
        cdef SharedGLContext shared_context = SharedGLContext.__new__(SharedGLContext)
        shared_context.context = context
        shared_context.gl_context = gl_context
        return shared_context

cdef void lock_gil_friendly_block(unique_lock[recursive_mutex] &m) noexcept:
    """
    Same as lock_gil_friendly, but blocks until the job is done.
    We inline the fast path, but not this one as it generates
    more code.
    """
    # Release the gil to enable python processes eventually
    # holding the lock to run and release it.
    # Block until we get the lock
    cdef bint locked = False
    while not(locked):
        with nogil:
            # Block until the mutex is released
            m.lock()
            # Unlock to prevent deadlock if another
            # thread holding the gil requires m
            # somehow
            m.unlock()
        locked = m.try_lock()

cdef inline void sched_yield():
    if os.name == 'posix':
        # os sched is only available on posix
        os.sched_yield()
    else:
        # time.sleep(0) on Windows has a
        # similar effect to sched_yield.
        # behaviour on non-posix is different
        # thus why we don't use it for posix.
        python_time.sleep(0)

cdef void internal_resize_callback(void *object) noexcept nogil:
    with gil:
        try:
            (<Viewport>object).__on_resize()
        except Exception as e:
            print("An error occured in the viewport resize callback", traceback.format_exc())

cdef void internal_close_callback(void *object) noexcept nogil:
    with gil:
        try:
            (<Viewport>object).__on_close()
        except Exception as e:
            print("An error occured in the viewport close callback", traceback.format_exc())

cdef void internal_drop_callback(void *object, int type, const char *data) noexcept nogil:
    with gil:
        try:
            (<Viewport>object).__on_drop(type, data)
        except Exception as e:
            print("An error occured in the viewport drop callback", traceback.format_exc())

cdef void internal_render_callback(void *object) noexcept nogil:
    (<Viewport>object).__render()

# Placeholder global where the last created Context is stored.
C : Context = None

# The no gc clear flag enforces that in case
# of no-reference cycle detected, the Context is freed last.
# The cycle is due to Context referencing Viewport
# and vice-versa

cdef class Context:
    """Main class managing the DearCyGui items and imgui context.

    The Context class serves as the central manager for the DearCyGui application, handling:
    - GUI rendering and event processing
    - Item creation and lifecycle management
    - Thread-safe callback execution
    - Global viewport management
    - ImGui/ImPlot/ImNodes context management

    There is exactly one viewport per context. The last created context can be accessed 
    as dearcygui.C.

    Attributes
    ----------
    queue : Executor
        Executor for managing thread-pooled callbacks. Defaults to ThreadPoolExecutor with max_workers=1.
    
    item_creation_callback : callable, optional
        Callback function called when any new item is created, before configuration.
        Signature: func(item)
    
    item_unused_configure_args_callback : callable, optional  
        Callback function called when unused configuration arguments are found.
        Signature: func(item, unused_args_dict)
    
    item_deletion_callback : callable, optional
        Callback function called when any item is deleted.
        Signature: func(item)
        Note: May not be called if item is garbage collected without holding context reference.

    viewport : Viewport
        Root item from where rendering starts. Read-only attribute.

    running : bool
        Whether the context is currently running and processing frames.
        
    clipboard : str
        Content of the system clipboard. Can be read/written.

    Implementation Notes
    -------------------
    - Thread safety is achieved through recursive mutexes on items and ImGui context
    - Callbacks are executed in a separate thread pool to prevent blocking the render loop
    - References between items form a tree structure with viewport as root
    - ImGui/ImPlot/ImNodes contexts are managed to support multiple contexts
    """

    def __init__(self,
                 queue=None, 
                 item_creation_callback=None,
                 item_unused_configure_args_callback=None,
                 item_deletion_callback=None):
        """Initialize the Context.

        Parameters
        ----------
        queue : concurrent.futures.Executor, optional
            Executor for managing thread-pooled callbacks. 
            Defaults to ThreadPoolExecutor(max_workers=1)
            
        item_creation_callback : callable, optional
            Function called during item creation before configuration.
            Signature: func(item)

        item_unused_configure_args_callback : callable, optional  
            Function called when configure() has unused arguments.
            Signature: func(item, unused_args_dict)

        item_deletion_callback : callable, optional
            Function called during item deletion.
            Signature: func(item)
            Note: May not be called if item is garbage collected without context reference.
        
        Raises
        ------
        TypeError
            If queue is provided but is not a subclass of concurrent.futures.Executor
        """
        global C
        self._on_close_callback = None
        if queue is None:
            self._queue = ThreadPoolExecutor(max_workers=1)
        else:
            if not(isinstance(queue, Executor)):
                raise TypeError("queue must be a subclass of concurrent.futures.Executor")
            self._queue = queue
        self._item_creation_callback = item_creation_callback
        self._item_unused_configure_args_callback = item_unused_configure_args_callback
        self._item_deletion_callback = item_deletion_callback
        C = self

    def __cinit__(self):
        """
        Cython-specific initializer for Context.
        """
        self.next_uuid.store(21)
        self._started = True
        self._threadlocal_data = threading.local()
        self.viewport = Viewport(self)
        imgui.IMGUI_CHECKVERSION()
        self.imgui_context = imgui.CreateContext()
        self.implot_context = implot.CreateContext()
        self.imnodes_context = imnodes.CreateContext()

    def __dealloc__(self):
        """
        Deallocate resources for Context.
        """
        self._started = True
        if self.imnodes_context != NULL:
            imnodes.DestroyContext(<imnodes.ImNodesContext*>self.imnodes_context)
        if self.implot_context != NULL:
            implot.DestroyContext(<implot.ImPlotContext*>self.implot_context)
        if self.imgui_context != NULL:
            imgui.DestroyContext(<imgui.ImGuiContext*>self.imgui_context)

    def __del__(self):
        """
        Destructor for Context.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._on_close_callback is not None:
            self._started = True
            self.queue_callback_noarg(self._on_close_callback, self, self)
            self._started = False

        #mvToolManager::Reset()
        #ClearItemRegistry(*GContext->itemRegistry)
        if self._queue is not None:
            self._queue.shutdown(wait=True)

    def __reduce__(self):
        """
        Pickle support.
        """
        return (self.__class__, ())

    @property
    def viewport(self) -> Viewport:
        """
        Readonly attribute: root item from where rendering starts.
        """
        return self.viewport

    @property
    def queue(self) -> Executor:
        """
        Executor for managing thread-pooled callbacks.
        """
        return self._queue

    @queue.setter
    def queue(self, queue):
        """
        Set the Executor for managing thread-pooled callbacks.
        """
        if queue is self._queue:
            return
        # Check type
        if not(isinstance(queue, Executor)):
            raise TypeError("queue must be a subclass of concurrent.futures.Executor")
        # Finish current queue
        if self._queue is not None:
            self._queue.shutdown(wait=True)
        self._queue = queue

    @property
    def rendering_context(self) -> BackendRenderingContext:
        """
        Readonly attribute: rendering context for the backend.
        Used to create contexts with object sharing.
        """
        return BackendRenderingContext.from_context(self)

    @property
    def item_creation_callback(self):
        """
        Callback called during item creation before configuration.
        """
        return self._item_creation_callback

    @property
    def item_unused_configure_args_callback(self) -> Viewport:
        """
        Callback called during item creation before configuration.
        """
        return self._item_unused_configure_args_callback

    @property
    def item_deletion_callback(self) -> Viewport:
        """
        Callback called during item deletion.

        If the item is released by the garbage collector, it is not guaranteed that
        this callback is called, as the item might have lost its
        pointer on the context.
        """
        return self._item_deletion_callback

    def create_new_shared_gl_context(self, int32_t major, int32_t minor):
        """
        Create a new shared OpenGL context with the current context.

        Parameters:
        major : int
            Major version of the OpenGL context.
        minor : int
            Minor version of the OpenGL context.

        Returns:
            SharedGLContext instance
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.imgui_mutex)
        return SharedGLContext.from_context(self, (<platformViewport*>self.viewport._platform).createSharedContext(major, minor))

    cdef void queue_callback_noarg(self, Callback callback, baseItem parent_item, baseItem target_item) noexcept nogil:
        """
        Queue a callback with no arguments.

        Parameters:
        callback : Callback
            The callback to be queued.
        parent_item : baseItem
            The parent item.
        target_item : baseItem
            The target item.
        """
        if callback is None:
            return
        with gil:
            try:
                self._queue.submit(callback, parent_item, target_item, None)
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg1obj(self, Callback callback, baseItem parent_item, baseItem target_item, baseItem arg1) noexcept nogil:
        """
        Queue a callback with one object argument.

        Parameters:
        callback : Callback
            The callback to be queued.
        parent_item : baseItem
            The parent item.
        target_item : baseItem
            The target item.
        arg1 : baseItem
            The first argument.
        """
        if callback is None:
            return
        with gil:
            try:
                self._queue.submit(callback, parent_item, target_item, arg1)
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg1key(self, Callback callback, baseItem parent_item, baseItem target_item, int32_t arg1) noexcept nogil:
        """
        Queue a callback with one key argument.

        Parameters:
        callback : Callback
            The callback to be queued.
        parent_item : baseItem
            The parent item.
        target_item : baseItem
            The target item.
        arg1 : int
            The first argument.
        """
        if callback is None:
            return
        with gil:
            try:
                self._queue.submit(callback, parent_item, target_item, Key(arg1))
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg1button(self, Callback callback, baseItem parent_item, baseItem target_item, int32_t arg1) noexcept nogil:
        """
        Queue a callback with one button argument.

        Parameters:
        callback : Callback
            The callback to be queued.
        parent_item : baseItem
            The parent item.
        target_item : baseItem
            The target item.
        arg1 : int
            The first argument.
        """
        if callback is None:
            return
        with gil:
            try:
                self._queue.submit(callback, parent_item, target_item, <MouseButton>arg1)
            except Exception as e:
                print(traceback.format_exc())


    cdef void queue_callback_arg1float(self, Callback callback, baseItem parent_item, baseItem target_item, float arg1) noexcept nogil:
        """
        Queue a callback with one float argument.

        Parameters:
        callback : Callback
            The callback to be queued.
        parent_item : baseItem
            The parent item.
        target_item : baseItem
            The target item.
        arg1 : float
            The first argument.
        """
        if callback is None:
            return
        with gil:
            try:
                self._queue.submit(callback, parent_item, target_item, arg1)
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg1value(self, Callback callback, baseItem parent_item, baseItem target_item, SharedValue arg1) noexcept nogil:
        """
        Queue a callback with one shared value argument.

        Parameters:
        callback : Callback
            The callback to be queued.
        parent_item : baseItem
            The parent item.
        target_item : baseItem
            The target item.
        arg1 : SharedValue
            The first argument.
        """
        if callback is None:
            return
        with gil:
            try:
                self._queue.submit(callback, parent_item, target_item, arg1.value)
            except Exception as e:
                print(traceback.format_exc())


    cdef void queue_callback_arg1key1float(self, Callback callback, baseItem parent_item, baseItem target_item, int32_t arg1, float arg2) noexcept nogil:
        """
        Queue a callback with one key and one float argument.

        Parameters:
        callback : Callback
            The callback to be queued.
        parent_item : baseItem
            The parent item.
        target_item : baseItem
            The target item.
        arg1 : int
            The first argument.
        arg2 : float
            The second argument.
        """
        if callback is None:
            return
        with gil:
            try:
                self._queue.submit(callback, parent_item, target_item, (Key(arg1), arg2))
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg1button1float(self, Callback callback, baseItem parent_item, baseItem target_item, int32_t arg1, float arg2) noexcept nogil:
        """
        Queue a callback with one button and one float argument.

        Parameters:
        callback : Callback
            The callback to be queued.
        parent_item : baseItem
            The parent item.
        target_item : baseItem
            The target item.
        arg1 : int
            The first argument.
        arg2 : float
            The second argument.
        """
        if callback is None:
            return
        with gil:
            try:
                self._queue.submit(callback, parent_item, target_item, (<MouseButton>(arg1), arg2))
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg2float(self, Callback callback, baseItem parent_item, baseItem target_item, float arg1, float arg2) noexcept nogil:
        """
        Queue a callback with two float arguments.

        Parameters:
        callback : Callback
            The callback to be queued.
        parent_item : baseItem
            The parent item.
        target_item : baseItem
            The target item.
        arg1 : float
            The first argument.
        arg2 : float
            The second argument.
        """
        if callback is None:
            return
        with gil:
            try:
                self._queue.submit(callback, parent_item, target_item, (arg1, arg2))
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg2double(self, Callback callback, baseItem parent_item, baseItem target_item, double arg1, double arg2) noexcept nogil:
        """
        Queue a callback with two double arguments.

        Parameters:
        callback : Callback
            The callback to be queued.
        parent_item : baseItem
            The parent item.
        target_item : baseItem
            The target item.
        arg1 : double
            The first argument.
        arg2 : double
            The second argument.
        """
        if callback is None:
            return
        with gil:
            try:
                self._queue.submit(callback, parent_item, target_item, (arg1, arg2))
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg1button2float(self, Callback callback, baseItem parent_item, baseItem target_item, int32_t arg1, float arg2, float arg3) noexcept nogil:
        """
        Queue a callback with one button and two float arguments.

        Parameters:
        callback : Callback
            The callback to be queued.
        parent_item : baseItem
            The parent item.
        target_item : baseItem
            The target item.
        arg1 : int
            The first argument.
        arg2 : float
            The second argument.
        arg3 : float
            The third argument.
        """
        if callback is None:
            return
        with gil:
            try:
                self._queue.submit(callback, parent_item, target_item, (<MouseButton>(arg1), arg2, arg3))
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg4int(self, Callback callback, baseItem parent_item, baseItem target_item, int32_t arg1, int32_t arg2, int32_t arg3, int32_t arg4) noexcept nogil:
        """
        Queue a callback with four integer arguments.

        Parameters:
        callback : Callback
            The callback to be queued.
        parent_item : baseItem
            The parent item.
        target_item : baseItem
            The target item.
        arg1 : int
            The first argument.
        arg2 : int
            The second argument.
        arg3 : int
            The third argument.
        arg4 : int
            The fourth argument.
        """
        if callback is None:
            return
        with gil:
            try:
                self._queue.submit(callback, parent_item, target_item, (arg1, arg2, arg3, arg4))
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg3long1int(self, Callback callback, baseItem parent_item, baseItem target_item, int64_t arg1, int64_t arg2, int64_t arg3, int32_t arg4) noexcept nogil:
        """
        Queue a callback with three long and one integer arguments.

        Parameters:
        callback : Callback
            The callback to be queued.
        parent_item : baseItem
            The parent item.
        target_item : baseItem
            The target item.
        arg1 : long long
            The first argument.
        arg2 : long long
            The second argument.
        arg3 : long long
            The third argument.
        arg4 : int
            The fourth argument.
        """
        if callback is None:
            return
        with gil:
            try:
                self._queue.submit(callback, parent_item, target_item, (arg1, arg2, arg3, arg4))
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_argdoubletriplet(self, Callback callback, baseItem parent_item, baseItem target_item,
                                              double arg1_1, double arg1_2, double arg1_3,
                                              double arg2_1, double arg2_2, double arg2_3) noexcept nogil:
        """
        Queue a callback with two triplets of double arguments.

        Parameters:
        callback : Callback
            The callback to be queued.
        parent_item : baseItem
            The parent item.
        target_item : baseItem
            The target item.
        arg1_1 : double
            The first argument of the first triplet.
        arg1_2 : double
            The second argument of the first triplet.
        arg1_3 : double
            The third argument of the first triplet.
        arg2_1 : double
            The first argument of the second triplet.
        arg2_2 : double
            The second argument of the second triplet.
        arg2_3 : double
            The third argument of the second triplet.
        """
        if callback is None:
            return
        with gil:
            try:
                self._queue.submit(callback, parent_item, target_item,
                                  ((arg1_1, arg1_2, arg1_3), (arg2_1, arg2_2, arg2_3)))
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback_arg1int1stringvector(self, Callback callback, baseItem parent_item, baseItem target_item,
                                                  int32_t arg1, vector[string] arg2) noexcept nogil:
        """
        Queue a callback with one integer and one vector of strings arguments.

        Parameters:
        callback : Callback
            The callback to be queued.
        parent_item : baseItem
            The parent item.
        target_item : baseItem
            The target item.
        arg1 : int
            The first argument.
        arg2 : vector[string]
            The second argument.
        """
        if callback is None:
            return
        with gil:
            try:
                element_list = []
                for element in arg2:
                    element_list.append(str(element, 'utf-8'))
                self._queue.submit(callback, parent_item, target_item, (arg1, element_list))
            except Exception as e:
                print(traceback.format_exc())

    cpdef void push_next_parent(self, baseItem next_parent):
        """
        Each time 'with' is used on an item, it is pushed
        to the list of potential parents to use if
        no parent (or before) is set when an item is created.
        If the list is empty, items are left unattached and
        can be attached later.

        In order to enable multiple threads to use
        the 'with' syntax, thread local storage is used,
        such that each thread has its own list.
        """
        # Use thread local storage such that multiple threads
        # can build items trees without conflicts.
        # Mutexes are not needed due to the thread locality
        cdef list parent_queue = getattr(self._threadlocal_data, 'parent_queue', [])
        parent_queue.append(next_parent)
        self._threadlocal_data.parent_queue = parent_queue
        self._threadlocal_data.current_parent = next_parent

    cpdef void pop_next_parent(self):
        """
        Remove an item from the potential parent list.
        """
        cdef list parent_queue = getattr(self._threadlocal_data, 'parent_queue', [])
        if len(parent_queue) > 0:
            parent_queue.pop()
        self._threadlocal_data.parent_queue = parent_queue # Unsure if needed
        if len(parent_queue) > 0:
            self._threadlocal_data.current_parent = parent_queue[len(parent_queue)-1]
        else:
            self._threadlocal_data.current_parent = None

    cpdef object fetch_parent_queue_back(self):
        """
        Retrieve the last item from the potential parent list.

        Returns:
        object
            The last item from the potential parent list.
        """
        return getattr(self._threadlocal_data, 'current_parent', None)

    cpdef object fetch_parent_queue_front(self):
        """
        Retrieve the top item from the potential parent list.

        Returns:
        object
            The top item from the potential parent list.
        """
        cdef list parent_queue = getattr(self._threadlocal_data, 'parent_queue', [])
        if len(parent_queue) == 0:
            return None
        return parent_queue[0]

    cdef bint c_is_key_down(self, int32_t key) noexcept nogil:
        return imgui.IsKeyDown(<imgui.ImGuiKey>key)

    cdef int32_t c_get_keymod_mask(self) noexcept nogil:
        return <int>imgui.GetIO().KeyMods

    def is_key_down(self, key : Key, keymod : KeyMod = None):
        """
        Check if a key is being held down.

        Parameters:
        key : Key
            Key constant.
        keymod : KeyMod, optional
            Key modifier mask (ctrl, shift, alt, super). If None, ignores any key modifiers.

        Returns:
        bool
            True if the key is down, False otherwise.
        """
        cdef unique_lock[recursive_mutex] m
        if key is None or not(isinstance(key, Key)):
            raise TypeError(f"key must be a valid Key, not {key}")
        if keymod is not None and not(isinstance(keymod, KeyMod)):
            raise TypeError(f"keymod must be a valid KeyMod, not {keymod}")
        cdef imgui.ImGuiKey keycode = key
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        if keymod is not None and (<int>keymod & imgui.ImGuiMod_Mask_) != imgui.GetIO().KeyMods:
            return False
        return imgui.IsKeyDown(keycode)

    cdef bint c_is_key_pressed(self, int32_t key, bint repeat) noexcept nogil:
        return imgui.IsKeyPressed(<imgui.ImGuiKey>key, repeat)

    def is_key_pressed(self, key : Key, keymod : KeyMod = None, bint repeat=True):
        """
        Check if a key was pressed (went from !Down to Down).

        Parameters:
        key : Key
            Key constant.
        keymod : KeyMod, optional
            Key modifier mask (ctrl, shift, alt, super). If None, ignores any key modifiers.
        repeat : bool, optional
            If True, the pressed state is repeated if the user continues pressing the key. Defaults to True.

        Returns:
        bool
            True if the key was pressed, False otherwise.
        """
        cdef unique_lock[recursive_mutex] m
        if key is None or not(isinstance(key, Key)):
            raise TypeError(f"key must be a valid Key, not {key}")
        if keymod is not None and not(isinstance(keymod, KeyMod)):
            raise TypeError(f"keymod must be a valid KeyMod, not {keymod}")
        cdef imgui.ImGuiKey keycode = key
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        if keymod is not None and (<int>keymod & imgui.ImGuiMod_Mask_) != imgui.GetIO().KeyMods:
            return False
        return imgui.IsKeyPressed(keycode, repeat)

    cdef bint c_is_key_released(self, int32_t key) noexcept nogil:
        return imgui.IsKeyReleased(<imgui.ImGuiKey>key)

    def is_key_released(self, key : Key, keymod : KeyMod = None):
        """
        Check if a key was released (went from Down to !Down).

        Parameters:
        key : Key
            Key constant.
        keymod : KeyMod, optional
            Key modifier mask (ctrl, shift, alt, super). If None, ignores any key modifiers.

        Returns:
        bool
            True if the key was released, False otherwise.
        """
        cdef unique_lock[recursive_mutex] m
        if key is None or not(isinstance(key, Key)):
            raise TypeError(f"key must be a valid Key, not {key}")
        if keymod is not None and not(isinstance(keymod, KeyMod)):
            raise TypeError(f"keymod must be a valid KeyMod, not {keymod}")
        cdef imgui.ImGuiKey keycode = key
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        if keymod is not None and (<int>keymod & imgui.GetIO().KeyMods) != keymod:
            return True
        return imgui.IsKeyReleased(keycode)

    cdef bint c_is_mouse_down(self, int32_t button) noexcept nogil:
        return imgui.IsMouseDown(button)

    def is_mouse_down(self, MouseButton button):
        """
        Check if a mouse button is held down.

        Parameters:
        button : MouseButton
            Mouse button constant.

        Returns:
        bool
            True if the mouse button is down, False otherwise.
        """
        cdef unique_lock[recursive_mutex] m
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return imgui.IsMouseDown(<int>button)

    cdef bint c_is_mouse_clicked(self, int32_t button, bint repease) noexcept nogil:
        return imgui.IsMouseClicked(button, repease)

    def is_mouse_clicked(self, MouseButton button, bint repeat=False):
        """
        Check if a mouse button was clicked (went from !Down to Down).

        Parameters:
        button : MouseButton
            Mouse button constant.
        repeat : bool, optional
            If True, the clicked state is repeated if the user continues pressing the button. Defaults to False.

        Returns:
        bool
            True if the mouse button was clicked, False otherwise.
        """
        cdef unique_lock[recursive_mutex] m
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return imgui.IsMouseClicked(<int>button, repeat)

    def is_mouse_double_clicked(self, MouseButton button):
        """
        Check if a mouse button was double-clicked.

        Parameters:
        button : MouseButton
            Mouse button constant.

        Returns:
        bool
            True if the mouse button was double-clicked, False otherwise.
        """
        cdef unique_lock[recursive_mutex] m
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return imgui.IsMouseDoubleClicked(<int>button)

    cdef int32_t c_get_mouse_clicked_count(self, int32_t button) noexcept nogil:
        return imgui.GetMouseClickedCount(button)

    def get_mouse_clicked_count(self, MouseButton button):
        """
        Get the number of times a mouse button is clicked in a row.

        Parameters:
        button : MouseButton
            Mouse button constant.

        Returns:
        int
            Number of times the mouse button is clicked in a row.
        """
        cdef unique_lock[recursive_mutex] m
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return imgui.GetMouseClickedCount(<int>button)

    cdef bint c_is_mouse_released(self, int32_t button) noexcept nogil:
        return imgui.IsMouseReleased(button)

    def is_mouse_released(self, MouseButton button):
        """
        Check if a mouse button was released (went from Down to !Down).

        Parameters:
        button : MouseButton
            Mouse button constant.

        Returns:
        bool
            True if the mouse button was released, False otherwise.
        """
        cdef unique_lock[recursive_mutex] m
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return imgui.IsMouseReleased(<int>button)

    cdef Vec2 c_get_mouse_pos(self) noexcept nogil:
        return ImVec2Vec2(imgui.GetMousePos())

    cdef Vec2 c_get_mouse_prev_pos(self) noexcept nogil:
        cdef imgui.ImGuiIO io = imgui.GetIO()
        return ImVec2Vec2(io.MousePosPrev)

    def get_mouse_position(self):
        """
        Retrieve the mouse position (x, y).

        Returns:
        tuple
            Coord containing the mouse position (x, y).

        Raises:
        KeyError
            If there is no mouse.
        """
        cdef unique_lock[recursive_mutex] m
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        cdef imgui.ImVec2 pos = imgui.GetMousePos()
        if not(imgui.IsMousePosValid(&pos)):
            raise KeyError("Cannot get mouse position: no mouse found")
        cdef double[2] coord = [pos.x, pos.y]
        return Coord.build(coord)

    cdef bint c_is_mouse_dragging(self, int32_t button, float lock_threshold) noexcept nogil:
        return imgui.IsMouseDragging(button, lock_threshold)

    def is_mouse_dragging(self, MouseButton button, float lock_threshold=-1.):
        """
        Check if the mouse is dragging.

        Parameters:
        button : MouseButton
            Mouse button constant.
        lock_threshold : float, optional
            Distance threshold for locking the drag. Uses default distance if lock_threshold < 0.0f. Defaults to -1.

        Returns:
        bool
            True if the mouse is dragging, False otherwise.
        """
        cdef unique_lock[recursive_mutex] m
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return imgui.IsMouseDragging(<int>button, lock_threshold)

    cdef Vec2 c_get_mouse_drag_delta(self, int32_t button, float threshold) noexcept nogil:
        return ImVec2Vec2(imgui.GetMouseDragDelta(button, threshold))

    def get_mouse_drag_delta(self, MouseButton button, float lock_threshold=-1.):
        """
        Return the delta (dx, dy) from the initial clicking position while the mouse button is pressed or was just released.

        Parameters:
        button : MouseButton
            Mouse button constant.
        lock_threshold : float, optional
            Distance threshold for locking the drag. Uses default distance if lock_threshold < 0.0f. Defaults to -1.

        Returns:
        tuple
            Tuple containing the drag delta (dx, dy).
        """
        cdef unique_lock[recursive_mutex] m
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        cdef imgui.ImVec2 delta =  imgui.GetMouseDragDelta(<int>button, lock_threshold)
        cdef double[2] coord = [delta.x, delta.y]
        return Coord.build(coord)

    def reset_mouse_drag_delta(self, MouseButton button):
        """
        Reset the drag delta for the target button to 0.

        Parameters:
        button : MouseButton
            Mouse button constant.
        """
        cdef unique_lock[recursive_mutex] m
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return imgui.ResetMouseDragDelta(<int>button)

    def inject_key_down(self, key : Key):
        """
        Inject a key down event for the next frame.

        Parameters:
        key : Key
            Key constant.
        """
        cdef unique_lock[recursive_mutex] m
        if key is None or not(isinstance(key, Key)):
            raise TypeError(f"key must be a valid Key, not {key}")
        cdef imgui.ImGuiKey keycode = key
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        imgui.GetIO().AddKeyEvent(keycode, True)

    def inject_key_up(self, key : Key):
        """
        Inject a key up event for the next frame.

        Parameters:
        key : Key
            Key constant.
        """
        cdef unique_lock[recursive_mutex] m
        if key is None or not(isinstance(key, Key)):
            raise TypeError(f"key must be a valid Key, not {key}")
        cdef imgui.ImGuiKey keycode = key
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        imgui.GetIO().AddKeyEvent(keycode, False)

    def inject_mouse_down(self, MouseButton button):
        """
        Inject a mouse down event for the next frame.

        Parameters:
        button : MouseButton
            Mouse button constant.
        """
        cdef unique_lock[recursive_mutex] m
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        imgui.GetIO().AddMouseButtonEvent(<int>button, True)

    def inject_mouse_up(self, MouseButton button):
        """
        Inject a mouse up event for the next frame.

        Parameters:
        button : MouseButton
            Mouse button constant.
        """
        cdef unique_lock[recursive_mutex] m
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        imgui.GetIO().AddMouseButtonEvent(<int>button, False)

    def inject_mouse_wheel(self, float wheel_x, float wheel_y):
        """
        Inject a mouse wheel event for the next frame.

        Parameters:
        wheel_x : float
            Horizontal wheel movement in pixels.
        wheel_y : float
            Vertical wheel movement in pixels.
        """
        cdef unique_lock[recursive_mutex] m
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        imgui.GetIO().AddMouseWheelEvent(wheel_x, wheel_y)

    def inject_mouse_pos(self, float x, float y):
        """
        Inject a mouse position event for the next frame.

        Parameters:
        x : float
            X position of the mouse in pixels.
        y : float
            Y position of the mouse in pixels.
        """
        cdef unique_lock[recursive_mutex] m
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        imgui.GetIO().AddMousePosEvent(x, y)

    @property 
    def running(self):
        """Whether the context is currently running and processing frames.
        
        Returns
        -------
        bool
            True if the context is running, False otherwise.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._started

    @running.setter
    def running(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._started = value

    @property
    def clipboard(self):
        """Content of the system clipboard.

        The clipboard can be read and written to interact with the system clipboard.
        Reading returns an empty string if the viewport is not yet initialized.

        Returns
        -------
        str
            Current content of the system clipboard
        """
        cdef unique_lock[recursive_mutex] m
        if not(self.viewport._initialized):
            return ""
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return str(imgui.GetClipboardText())

    @clipboard.setter
    def clipboard(self, str value):
        cdef string value_str = bytes(value, 'utf-8')
        cdef unique_lock[recursive_mutex] m
        if not(self.viewport._initialized):
            return
        ensure_correct_imgui_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        imgui.SetClipboardText(value_str.c_str())



cdef class baseItem:
    """Base class for all items (except shared values).

    To be rendered, an item must be in the child tree of the viewport (context.viewport).

    Parent-Child Relationships:
    -------------------------
    The parent of an item can be set in several ways:
    1. Using the parent attribute: `item.parent = target_item`
    2. Passing `parent=target_item` during item creation 
    3. Using the context manager ('with' statement) - if no parent is explicitly set, the last item in the 'with' block becomes the parent
    4. Setting previous_sibling or next_sibling attributes to insert the item between existing siblings

    Tree Structure:
    --------------
    - Items are rendered in order from first child to last child
    - New items are inserted last by default unless previous_sibling/next_sibling is used
    - Items can be manually detached by setting parent = None
    - Most items have restrictions on what parents/children they can have
    - Some items can have multiple incompatible child lists that are concatenated when reading item.children

    Special Cases:
    -------------
    Some items cannot be children in the rendering tree:
    - PlaceHolderParent: Can be parent to any item but cannot be in rendering tree
    - Textures, themes, colormaps and fonts: Cannot be children but can be bound to items

    Attributes:
        context (Context): The context this item belongs to
        user_data (Any): Custom user data that can be attached to the item
        uuid (int): Unique identifier for this item
        parent (baseItem): Parent item in the rendering tree
        previous_sibling (baseItem): Previous sibling in parent's child list
        next_sibling (baseItem): Next sibling in parent's child list
        children (List[baseItem]): List of child items in rendering order
        children_types (ChildType): Bitmask of allowed child types
        item_type (ChildType): Type of this item as a child

    The parent, previous_sibling and next_sibling relationships form a doubly-linked tree structure that determines rendering order and hierarchy.
    The children attribute provides access to all child items.
    """

    def __init__(self, context, *args, **kwargs):
        if self.context._item_creation_callback is not None:
            self.context._item_creation_callback(self)
        self.configure(*args, **kwargs)

    def __cinit__(self, context, *args, **kwargs):
        if not(isinstance(context, Context)):
            raise ValueError("Provided context is not a valid Context instance")
        self.context = context
        self._external_lock = False
        self.uuid = self.context.next_uuid.fetch_add(1)
        self.can_have_widget_child = False
        self.can_have_drawing_child = False
        self.can_have_sibling = False
        self.element_child_category = -1

    def configure(self, **kwargs):
        # Automatic attachment
        cdef bint ignore_if_fail
        cdef bint should_attach
        cdef bint default_behaviour = True
        # The most common case is neither
        # attach, parent, nor before as set.
        # The code is optimized with this case
        # in mind.
        if self.parent is None:
            ignore_if_fail = False
            # attach = None => default behaviour
            if "attach" in kwargs:
                attach = kwargs.pop("attach")
                if attach is not None:
                    default_behaviour = False
                    should_attach = attach
            if default_behaviour:
                # default behaviour: False for items which
                # cannot be attached, True else but without
                # failure.
                if self.element_child_category == -1:
                    should_attach = False
                else:
                    should_attach = True
                    # To avoid failing on items which cannot
                    # be attached to the rendering tree but
                    # can be attached to other items
                    ignore_if_fail = True
            if should_attach:
                before = None
                parent = None
                if "before" in kwargs:
                    before = kwargs.pop("before")
                if "parent" in kwargs:
                    parent = kwargs.pop("parent")
                if before is not None:
                    # parent manually set. Do not ignore failure
                    ignore_if_fail = False
                    self.attach_before(before)
                else:
                    if parent is None:
                        parent = self.context.fetch_parent_queue_back()
                        if parent is None:
                            # The default parent is the viewport,
                            # but check right now for failure
                            # as attach_to_parent is not cheap.
                            if not(ignore_if_fail) or \
                                self.element_child_category == child_type.cat_window or \
                                self.element_child_category == child_type.cat_menubar or \
                                self.element_child_category == child_type.cat_viewport_drawlist:
                                parent = self.context.viewport
                    else:
                        # parent manually set. Do not ignore failure
                        ignore_if_fail = False
                    if parent is not None:
                        try:
                            self.attach_to_parent(parent)
                        except ValueError as e:
                            # Needed for tag support
                            if self.context._item_unused_configure_args_callback is not None and \
                                isinstance(parent, str):
                                self.context._item_unused_configure_args_callback(self, {"parent": parent})
                                pass
                            else:
                                if not(ignore_if_fail):
                                    raise(e)
                        except TypeError as e:
                            if not(ignore_if_fail):
                                raise(e)

        # Fast path for this common case
        if self.context._item_unused_configure_args_callback is None:
            for (key, value) in kwargs.items():
                setattr(self, key, value)
            return
        remaining = {}
        for (key, value) in kwargs.items():
            try:
                setattr(self, key, value)
            except AttributeError as e:
                remaining[key] = value
        if len(remaining) > 0:
            self.context._item_unused_configure_args_callback(self, remaining)

    def __del__(self):
        if self.context is not None:
            if self.context._item_deletion_callback is not None:
                self.context._item_deletion_callback(self)

    def __dealloc__(self):
        clear_obj_vector(self._handlers)

    def __reduce__(self):
        """
        Pickle support.
        """
        return (self.__class__, (self.context,), self.__getstate__())

    def __getstate__(self):
        """
        Generic implementation.

        Retrieve the item configuration and child tree (Pickle support.)
        """
        result = {}

        blacklist = set([
            "parent", "previous_sibling", "next_sibling",
            "children", "children_types", "item_type",
            "context", "uuid", "mutex", "shareable_value"
        ])

        # Retrieve the attributes of the item
        # that are not methods.
        for key in dir(self):
            if key in blacklist:
                continue
            if key.startswith("__"):
                continue
            value = getattr(self, key)
            try:
                setattr(self, key, value)
            except AttributeError, TypeError:
                continue
            result[key] = value

        result["children"] = self.children

        return result

    def __setstate__(self, state):
        """
        Restore the item configuration and child tree (Pickle support.)
        """
        self.configure(**state)

    @property
    def context(self):
        """
        Read-only attribute: Context in which the item resides
        """
        return self.context

    @property
    def user_data(self):
        """
        User data of any type.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._user_data

    @user_data.setter
    def user_data(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._user_data = value

    @property
    def uuid(self):
        """
        Readonly attribute: uuid is an unique identifier created
        by the context for the item.
        uuid can be used to access the object by name for parent=,
        previous_sibling=, next_sibling= arguments, but it is
        preferred to pass the objects directly. 
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return int(self.uuid)

    @property
    def parent(self):
        """
        Writable attribute: parent of the item in the rendering tree.

        Rendering starts from the viewport. Then recursively each child
        is rendered from the first to the last, and each child renders
        their subtree.

        Only an item inserted in the rendering tree is rendered.
        An item that is not in the rendering tree can have children.
        Thus it is possible to build and configure various items, and
        attach them to the tree in a second phase.

        The children hold a reference to their parent, and the parent
        holds a reference to its children. Thus to be release memory
        held by an item, two options are possible:
        . Remove the item from the tree, remove all your references.
          If the item has children or siblings, the item will not be
          released until Python's garbage collection detects a
          circular reference.
        . Use delete_item to remove the item from the tree, and remove
          all the internal references inside the item structure and
          the item's children, thus allowing them to be removed from
          memory as soon as the user doesn't hold a reference on them.

        Note the viewport is referenced by the context.

        If you set this attribute, the item will be inserted at the last
        position of the children of the parent (regardless whether this
        item is already a child of the parent).
        If you set None, the item will be removed from its parent's children
        list.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.parent

    @parent.setter
    def parent(self, value):
        # It is important to not lock the mutex before the call
        if value is None:
            self.detach_item()
            return
        self.attach_to_parent(value)

    @property 
    def previous_sibling(self):
        """
        Writable attribute: child of the parent of the item that
        is rendered just before this item.

        It is not possible to have siblings if you have no parent,
        thus if you intend to attach together items outside the
        rendering tree, there must be a toplevel parent item.

        If you write to this attribute, the item will be moved
        to be inserted just after the target item.
        In case of failure, the item remains in a detached state.

        Note that a parent can have several child queues, and thus
        child elements are not guaranteed to be siblings of each other.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.prev_sibling

    @previous_sibling.setter
    def previous_sibling(self, baseItem target not None):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, target.mutex)
        # Convert into an attach_before or attach_to_parent
        next_sibling = target.next_sibling
        target_parent = target.parent
        m.unlock()
        # It is important to not lock the mutex before the call
        if next_sibling is None:
            if target_parent is not None:
                self.attach_to_parent(target_parent)
            else:
                raise ValueError("Cannot bind sibling if no parent")
        self.attach_before(next_sibling)

    @property
    def next_sibling(self):
        """
        Writable attribute: child of the parent of the item that
        is rendered just after this item.

        It is not possible to have siblings if you have no parent,
        thus if you intend to attach together items outside the
        rendering tree, there must be a toplevel parent item.

        If you write to this attribute, the item will be moved
        to be inserted just before the target item.
        In case of failure, the item remains in a detached state.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.next_sibling

    @next_sibling.setter
    def next_sibling(self, baseItem target not None):
        # It is important to not lock the mutex before the call
        self.attach_before(target)

    @property
    def children(self):
        """
        Writable attribute: List of all the children of the item,
        from first rendered, to last rendered.

        When written to, an error is raised if the children already
        have other parents. This error is meant to prevent programming
        mistakes, as users might not realize the children were
        unattached from their former parents.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        # Note: the children structure is not allowed
        # to change when the parent mutex is held
        cdef baseItem item = self.last_theme_child
        while item is not None:
            result.append(item)
            item = item.prev_sibling
        item = self.last_handler_child
        while item is not None:
            result.append(item)
            item = item.prev_sibling
        item = self.last_plot_element_child
        while item is not None:
            result.append(item)
            item = item.prev_sibling
        item = self.last_tab_child
        while item is not None:
            result.append(item)
            item = item.prev_sibling
        item = self.last_tag_child
        while item is not None:
            result.append(item)
            item = item.prev_sibling
        item = self.last_drawings_child
        while item is not None:
            result.append(item)
            item = item.prev_sibling
        item = self.last_widgets_child
        while item is not None:
            result.append(item)
            item = item.prev_sibling
        item = self.last_window_child
        while item is not None:
            result.append(item)
            item = item.prev_sibling
        item = self.last_menubar_child
        while item is not None:
            result.append(item)
            item = item.prev_sibling
        result.reverse()
        return result

    @children.setter
    def children(self, value):
        if not(hasattr(value, "__len__")):
            raise TypeError("children must be a array of child items")
        cdef unique_lock[recursive_mutex] item_m
        cdef unique_lock[recursive_mutex] child_m
        lock_gil_friendly(item_m, self.mutex)
        cdef long long uuid, prev_uuid
        cdef cpp_set[long long] already_attached
        cdef baseItem sibling
        for child in value:
            if not(isinstance(child, baseItem)):
                raise TypeError(f"{child} is not a compatible item instance")
            # Find children that are already attached
            # and in the right order
            uuid = (<baseItem>child).uuid
            if (<baseItem>child).parent is self:
                if (<baseItem>child).prev_sibling is None:
                    already_attached.insert(uuid)
                    continue
                prev_uuid = (<baseItem>child).prev_sibling.uuid
                if already_attached.find(prev_uuid) != already_attached.end():
                    already_attached.insert(uuid)
                    continue

            # Note: it is fine here to hold the mutex to item_m
            # and call attach_parent, as item_m is the target
            # parent.
            # It is also fine to retain the lock to child_m
            # as it has no parent
            lock_gil_friendly(child_m, (<baseItem>child).mutex)
            if (<baseItem>child).parent is not None and \
               (<baseItem>child).parent is not self:
                # Probable programming mistake and potential deadlock
                raise ValueError(f"{child} already has a parent")
            (<baseItem>child).attach_to_parent(self)

            # Detach any previous sibling that are not in the
            # already_attached list, and thus should either
            # be removed, or their order changed.
            while (<baseItem>child).prev_sibling is not None and \
                already_attached.find((<baseItem>child).prev_sibling.uuid) == already_attached.end():
                # Setting sibling here rather than calling detach_item directly avoids
                # crash due to refcounting bug.
                sibling = (<baseItem>child).prev_sibling
                sibling.detach_item()
            already_attached.insert(uuid)

        # if no children were attached, the previous code to
        # remove outdated children didn't execute.
        # Same for child lists where we didn't append
        # new items. Clean now.
        child = self.last_theme_child
        while child is not None:
            if already_attached.find((<baseItem>child).uuid) != already_attached.end():
                break
            (<baseItem>child).detach_item()
            child = self.last_theme_child
        child = self.last_handler_child
        while child is not None:
            if already_attached.find((<baseItem>child).uuid) != already_attached.end():
                break
            (<baseItem>child).detach_item()
            child = self.last_handler_child
        child = self.last_plot_element_child
        while child is not None:
            if already_attached.find((<baseItem>child).uuid) != already_attached.end():
                break
            (<baseItem>child).detach_item()
            child = self.last_plot_element_child
        child = self.last_tab_child
        while child is not None:
            if already_attached.find((<baseItem>child).uuid) != already_attached.end():
                break
            (<baseItem>child).detach_item()
            child = self.last_tab_child
        child = self.last_tag_child
        while child is not None:
            if already_attached.find((<baseItem>child).uuid) != already_attached.end():
                break
            (<baseItem>child).detach_item()
            child = self.last_tag_child
        child = self.last_drawings_child
        while child is not None:
            if already_attached.find((<baseItem>child).uuid) != already_attached.end():
                break
            (<baseItem>child).detach_item()
            child = self.last_drawings_child
        child = self.last_widgets_child
        while child is not None:
            if already_attached.find((<baseItem>child).uuid) != already_attached.end():
                break
            (<baseItem>child).detach_item()
            child = self.last_widgets_child
        child = self.last_window_child
        while child is not None:
            if already_attached.find((<baseItem>child).uuid) != already_attached.end():
                break
            (<baseItem>child).detach_item()
            child = self.last_window_child
        child = self.last_menubar_child
        while child is not None:
            if already_attached.find((<baseItem>child).uuid) != already_attached.end():
                break
            (<baseItem>child).detach_item()
            child = self.last_menubar_child

    @property
    def children_types(self):
        """Returns which types of children can be attached to this item"""
        type = ChildType.NOCHILD
        if self.can_have_drawing_child:
            type = type | ChildType.DRAWING
        if self.can_have_handler_child:
            type = type | ChildType.HANDLER
        if self.can_have_menubar_child:
            type = type | ChildType.MENUBAR
        if self.can_have_plot_element_child:
            type = type | ChildType.PLOTELEMENT
        if self.can_have_tab_child:
            type = type | ChildType.TAB
        if self.can_have_tag_child:
            type = type | ChildType.AXISTAG
        if self.can_have_theme_child:
            type = type | ChildType.THEME
        if self.can_have_viewport_drawlist_child:
            type = type | ChildType.VIEWPORTDRAWLIST
        if self.can_have_widget_child:
            type = type | ChildType.WIDGET
        if self.can_have_window_child:
            type = type | ChildType.WINDOW
        return type

    @property
    def item_type(self):
        """Returns which type of child this item is"""
        if self.element_child_category == child_type.cat_drawing:
            return ChildType.DRAWING
        elif self.element_child_category == child_type.cat_handler:
            return ChildType.HANDLER
        elif self.element_child_category == child_type.cat_menubar:
            return ChildType.MENUBAR
        elif self.element_child_category == child_type.cat_plot_element:
            return ChildType.PLOTELEMENT
        elif self.element_child_category == child_type.cat_tab:
            return ChildType.TAB
        elif self.element_child_category == child_type.cat_theme:
            return ChildType.THEME
        elif self.element_child_category == child_type.cat_viewport_drawlist:
            return ChildType.VIEWPORTDRAWLIST
        elif self.element_child_category == child_type.cat_widget:
            return ChildType.WIDGET
        elif self.element_child_category == child_type.cat_window:
            return ChildType.WINDOW
        return ChildType.NOCHILD

    def __enter__(self):
        # Mutexes not needed
        if not(self.can_have_drawing_child or \
           self.can_have_handler_child or \
           self.can_have_menubar_child or \
           self.can_have_plot_element_child or \
           self.can_have_tab_child or \
           self.can_have_tag_child or \
           self.can_have_theme_child or \
           self.can_have_widget_child or \
           self.can_have_window_child):
            print("Warning: {self} cannot have children but is pushed as container")
        self.context.push_next_parent(self)
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self.context.pop_next_parent()
        return False # Do not catch exceptions

    cdef void lock_parent_and_item_mutex(self,
                                         unique_lock[recursive_mutex] &parent_m,
                                         unique_lock[recursive_mutex] &item_m):
        # We must make sure we lock the correct parent mutex, and for that
        # we must access self.parent and thus hold the item mutex
        cdef bint locked = False
        while not(locked):
            lock_gil_friendly(item_m, self.mutex)
            if self.parent is not None:
                # Manipulate the lock directly
                # as we don't want unique lock to point
                # to a mutex which might be freed (if the
                # parent of the item is changed by another
                # thread and the parent freed)
                locked = self.parent.mutex.try_lock()
            else:
                locked = True
            if locked:
                if self.parent is not None:
                    # Transfert the lock
                    parent_m = unique_lock[recursive_mutex](self.parent.mutex)
                    self.parent.mutex.unlock()
                return
            item_m.unlock()
            # Release the gil and give priority to other threads that might
            # hold the lock we want
            sched_yield()
            if not(locked) and self._external_lock > 0:
                raise RuntimeError(
                    "Trying to lock parent mutex while holding a lock. "
                    "If you get this error, this means you are attempting "
                    "to edit the children list of a parent of nodes you "
                    "hold a mutex to, but you are not holding a mutex of the "
                    "parent. As a result deadlock occured."
                    "To fix this issue:\n "
                    "If the item you are inserting in the parent's children "
                    "list is outside the rendering tree, (you didn't really "
                    " need a mutex) -> release your mutexes.\n "
                    "If the item is in the rendering tree you should lock first "
                    "the parent.")


    cdef void lock_and_previous_siblings(self) noexcept nogil:
        """
        Used when the parent needs to prevent any change to its
        children.
        Note when the parent mutex is held, it can rely that
        its list of children is fixed. However this is used
        when the parent needs to read the individual state
        of its children and needs these state to not change
        for some operations.
        """
        self.mutex.lock()
        if self.prev_sibling is not None:
            self.prev_sibling.lock_and_previous_siblings()

    cdef void unlock_and_previous_siblings(self) noexcept nogil:
        if self.prev_sibling is not None:
            self.prev_sibling.unlock_and_previous_siblings()
        self.mutex.unlock()


    def copy(self, target_context=None):
        """
        Shallow copy of the item to the target context.
        Performs a deep copy of the child tree.

        Parameters:
        target_context : Context, optional
            Target context for the copy. Defaults to None.
            (None = source's context)

        Returns:
        baseItem
            Copy of the item in the target context.
        """
        cdef baseItem target
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        lock_gil_friendly(m, self.mutex)
        if target_context is None:
            target_context = self.context
        target = self.__class__.__new__(self.__class__, target_context)
        lock_gil_friendly(m2, target.mutex)

        # if the class does not implement _copy itself,
        # revert to using getstate/setstate
        target.__setstate__(self.__getstate__())

        # copy children
        self._copy_children(target)

        return target

    '''
    cdef void _copy(self, object target):
        """
        Shallow copy of the item to the target item.

        Assumes both self and target are locked.
        """
        # We assume the item is already initialized
        # by __cinit__, thus capabilities, context, etc
        # are already set.
        cdef PyObject *handler
        cdef baseItem target_base = <baseItem>target

        if type(self) is not baseItem:
            self._copy_default(target)
            return

        # Copy handlers
        clear_obj_vector(target_base._handlers)
        for handler in self._handlers:
            Py_INCREF(<object>handler)
            target_base._handlers.push_back(handler)

        # copy user data
        target_base._user_data = self._user_data

        # copy children
        self._copy_children(target_base)
    '''

    cdef void _copy_children(self, baseItem target):
        """
        Copy children from source to target.
        Assumes both source and target are locked.
        """
        cdef baseItem child, new_child
        for child in self.children:
            new_child = child.__class__.__new__(child.__class__, target.context)
            child._copy(new_child)
            new_child.attach_to_parent(target)

    cdef bint _check_rendered(self):
        """
        Returns if an item is rendered
        """
        cdef baseItem item = self
        # Find a parent with state
        # Not perfect because we do not hold the mutexes,
        # but should be ok enough to fail in a few cases.
        while item is not None and item.p_state == NULL:
            item = item.parent
        if item is None or item.p_state == NULL:
            return False
        return item.p_state.cur.rendered


    cpdef void attach_to_parent(self, target):
        """
        Same as item.parent = target, but
        target must not be None
        """
        cdef baseItem target_parent
        if self.context is None:
            raise ValueError("Trying to attach a deleted item")

        if not(isinstance(target, baseItem)):
            raise ValueError(f"{target} cannot be attached")
        target_parent = <baseItem>target
        if target_parent.context is not self.context:
            raise ValueError(f"Cannot attach {self} to {target} as it was not created in the same context")

        if target_parent is None:
            raise ValueError("Trying to attach to None")
        if target_parent.context is None:
            raise ValueError("Trying to attach to a deleted item")

        if self._external_lock > 0:
            # Deadlock potential. We would need to unlock the user held mutex,
            # which could be a solution, but raises its own issues.
            if target_parent._external_lock == 0:
                raise PermissionError(f"Cannot attach {self} to {target} as the user holds a lock on {self}, but not {target}")
            if not(target_parent.mutex.try_lock()):
                raise PermissionError(f"Cannot attach {self} to {target} as the user holds a lock on {self} and {target}, but not in the same threads")
            target_parent.mutex.unlock()

        # Check compatibility with the parent before locking the mutex
        # We do this optimization to avoid locking uselessly when
        # creating items due to the automated attach feature.
        cdef bint compatible = False
        if self.element_child_category == child_type.cat_drawing:
            if target_parent.can_have_drawing_child:
                compatible = True
        elif self.element_child_category == child_type.cat_handler:
            if target_parent.can_have_handler_child:
                compatible = True
        elif self.element_child_category == child_type.cat_menubar:
            if target_parent.can_have_menubar_child:
                compatible = True
        elif self.element_child_category == child_type.cat_plot_element:
            if target_parent.can_have_plot_element_child:
                compatible = True
        elif self.element_child_category == child_type.cat_tab:
            if target_parent.can_have_tab_child:
                compatible = True
        elif self.element_child_category == child_type.cat_tag:
            if target_parent.can_have_tag_child:
                compatible = True
        elif self.element_child_category == child_type.cat_theme:
            if target_parent.can_have_theme_child:
                compatible = True
        elif self.element_child_category == child_type.cat_viewport_drawlist:
            if target_parent.can_have_viewport_drawlist_child:
                compatible = True
        elif self.element_child_category == child_type.cat_widget:
            if target_parent.can_have_widget_child:
                compatible = True
        elif self.element_child_category == child_type.cat_window:
            if target_parent.can_have_window_child:
                compatible = True
        if not(compatible):
            raise TypeError("Instance of type {} cannot be attached to {}".format(type(self), type(target_parent)))

        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        cdef unique_lock[recursive_mutex] m3
        # We must ensure a single thread attaches at a given time.
        # _detach_item_and_lock will lock both the item lock
        # and the parent lock.
        self._detach_item_and_lock(m)
        # retaining the lock enables to ensure the item is
        # still detached

        # Lock target parent mutex
        lock_gil_friendly(m2, target_parent.mutex)

        cdef bint attached = False

        # Attach to parent in the correct category
        # Note that Cython converts this into a switch().
        if self.element_child_category == child_type.cat_drawing:
            if target_parent.can_have_drawing_child:
                if target_parent.last_drawings_child is not None:
                    lock_gil_friendly(m3, target_parent.last_drawings_child.mutex)
                    target_parent.last_drawings_child.next_sibling = self
                self.prev_sibling = target_parent.last_drawings_child
                self.parent = target_parent
                target_parent.last_drawings_child = <drawingItem>self
                attached = True
        elif self.element_child_category == child_type.cat_handler:
            if target_parent.can_have_handler_child:
                if target_parent.last_handler_child is not None:
                    lock_gil_friendly(m3, target_parent.last_handler_child.mutex)
                    target_parent.last_handler_child.next_sibling = self
                self.prev_sibling = target_parent.last_handler_child
                self.parent = target_parent
                target_parent.last_handler_child = <baseHandler>self
                attached = True
        elif self.element_child_category == child_type.cat_menubar:
            if target_parent.can_have_menubar_child:
                if target_parent.last_menubar_child is not None:
                    lock_gil_friendly(m3, target_parent.last_menubar_child.mutex)
                    target_parent.last_menubar_child.next_sibling = self
                self.prev_sibling = target_parent.last_menubar_child
                self.parent = target_parent
                target_parent.last_menubar_child = <uiItem>self
                attached = True
        elif self.element_child_category == child_type.cat_plot_element:
            if target_parent.can_have_plot_element_child:
                if target_parent.last_plot_element_child is not None:
                    lock_gil_friendly(m3, target_parent.last_plot_element_child.mutex)
                    target_parent.last_plot_element_child.next_sibling = self
                self.prev_sibling = target_parent.last_plot_element_child
                self.parent = target_parent
                target_parent.last_plot_element_child = <plotElement>self
                attached = True
        elif self.element_child_category == child_type.cat_tab:
            if target_parent.can_have_tab_child:
                if target_parent.last_tab_child is not None:
                    lock_gil_friendly(m3, target_parent.last_tab_child.mutex)
                    target_parent.last_tab_child.next_sibling = self
                self.prev_sibling = target_parent.last_tab_child
                self.parent = target_parent
                target_parent.last_tab_child = <uiItem>self
                attached = True
        elif self.element_child_category == child_type.cat_tag:
            if target_parent.can_have_tag_child:
                if target_parent.last_tag_child is not None:
                    lock_gil_friendly(m3, target_parent.last_tag_child.mutex)
                    target_parent.last_tag_child.next_sibling = self
                self.prev_sibling = target_parent.last_tag_child
                self.parent = target_parent
                target_parent.last_tag_child = <AxisTag>self
                attached = True
        elif self.element_child_category == child_type.cat_theme:
            if target_parent.can_have_theme_child:
                if target_parent.last_theme_child is not None:
                    lock_gil_friendly(m3, target_parent.last_theme_child.mutex)
                    target_parent.last_theme_child.next_sibling = self
                self.prev_sibling = target_parent.last_theme_child
                self.parent = target_parent
                target_parent.last_theme_child = <baseTheme>self
                attached = True
        elif self.element_child_category == child_type.cat_viewport_drawlist:
            if target_parent.can_have_viewport_drawlist_child:
                if target_parent.last_viewport_drawlist_child is not None:
                    lock_gil_friendly(m3, target_parent.last_viewport_drawlist_child.mutex)
                    target_parent.last_viewport_drawlist_child.next_sibling = self
                self.prev_sibling = target_parent.last_viewport_drawlist_child
                self.parent = target_parent
                target_parent.last_viewport_drawlist_child = <drawingItem>self
                attached = True
        elif self.element_child_category == child_type.cat_widget:
            if target_parent.can_have_widget_child:
                if target_parent.last_widgets_child is not None:
                    lock_gil_friendly(m3, target_parent.last_widgets_child.mutex)
                    target_parent.last_widgets_child.next_sibling = self
                self.prev_sibling = target_parent.last_widgets_child
                self.parent = target_parent
                target_parent.last_widgets_child = <uiItem>self
                attached = True
        elif self.element_child_category == child_type.cat_window:
            if target_parent.can_have_window_child:
                if target_parent.last_window_child is not None:
                    lock_gil_friendly(m3, target_parent.last_window_child.mutex)
                    target_parent.last_window_child.next_sibling = self
                self.prev_sibling = target_parent.last_window_child
                self.parent = target_parent
                target_parent.last_window_child = <Window>self
                attached = True
        assert(attached) # because we checked before compatibility
        if not(self.parent._check_rendered()): # TODO: could be optimized. Also not totally correct (attaching to a menu for instance)
            self.set_hidden_and_propagate_to_children_no_handlers()

    cpdef void attach_before(self, target):
        """
        Same as item.next_sibling = target,
        but target must not be None
        """
        cdef baseItem target_before
        if self.context is None:
            raise ValueError("Trying to attach a deleted item")

        if not(isinstance(target, baseItem)):
            raise ValueError(f"{target} cannot be attached")
        target_before = <baseItem>target
        if target_before.context is not self.context:
            raise ValueError(f"Cannot attach {self} to {target} as it was not created in the same context")

        if target_before is None:
            raise ValueError("target before cannot be None")

        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] target_before_m
        cdef unique_lock[recursive_mutex] target_parent_m
         # We must ensure a single thread attaches at a given time.
        # _detach_item_and_lock will lock both the item lock
        # and the parent lock.
        self._detach_item_and_lock(m)
        # retaining the lock enables to ensure the item is
        # still detached

        # Lock target mutex and its parent mutex
        target_before.lock_parent_and_item_mutex(target_parent_m,
                                                 target_before_m)

        if target_before.parent is None:
            # We can bind to an unattached parent, but not
            # to unattached siblings. Could be implemented, but not trivial.
            # Maybe we could use the viewport mutex instead,
            # but that defeats the purpose of building items
            # outside the rendering tree.
            raise ValueError("Trying to attach to an un-attached sibling. Not yet supported")

        # Check the elements can indeed be siblings
        if not(self.can_have_sibling):
            raise ValueError("Instance of type {} cannot have a sibling".format(type(self)))
        if not(target_before.can_have_sibling):
            raise ValueError("Instance of type {} cannot have a sibling".format(type(target_before)))
        if self.element_child_category != target_before.element_child_category:
            raise ValueError("Instance of type {} cannot be sibling to {}".format(type(self), type(target_before)))

        # Attach to sibling
        cdef baseItem prev_sibling = target_before.prev_sibling
        self.parent = target_before.parent
        # Potential deadlocks are avoided by the fact that we hold the parent
        # mutex and any lock of a next sibling must hold the parent
        # mutex.
        cdef unique_lock[recursive_mutex] prev_m
        if prev_sibling is not None:
            lock_gil_friendly(prev_m, prev_sibling.mutex)
            prev_sibling.next_sibling = self
        self.prev_sibling = prev_sibling
        self.next_sibling = target_before
        target_before.prev_sibling = self
        if not(self.parent._check_rendered()):
            self.set_hidden_and_propagate_to_children_no_handlers()

    cdef void _detach_item_and_lock(self, unique_lock[recursive_mutex]& m):
        # NOTE: the mutex is not locked if we raise an exception.
        # Detach the item from its parent and siblings
        # We are going to change the tree structure, we must lock
        # the parent mutex first and foremost
        cdef unique_lock[recursive_mutex] parent_m
        cdef unique_lock[recursive_mutex] sibling_m
        self.lock_parent_and_item_mutex(parent_m, m)
        # Use unique lock for the mutexes to
        # simplify handling (parent will change)

        if self.parent is None:
            return # nothing to do

        # Remove this item from the list of siblings
        if self.prev_sibling is not None:
            lock_gil_friendly(sibling_m, self.prev_sibling.mutex)
            self.prev_sibling.next_sibling = self.next_sibling
            sibling_m.unlock()
        if self.next_sibling is not None:
            lock_gil_friendly(sibling_m, self.next_sibling.mutex)
            self.next_sibling.prev_sibling = self.prev_sibling
            sibling_m.unlock()
        else:
            # No next sibling. We might be referenced in the
            # parent
            if self.parent is not None:
                if self.parent.last_drawings_child is self:
                    self.parent.last_drawings_child = self.prev_sibling
                elif self.parent.last_handler_child is self:
                    self.parent.last_handler_child = self.prev_sibling
                elif self.parent.last_menubar_child is self:
                    self.parent.last_menubar_child = self.prev_sibling
                elif self.parent.last_plot_element_child is self:
                    self.parent.last_plot_element_child = self.prev_sibling
                elif self.parent.last_tab_child is self:
                    self.parent.last_tab_child = self.prev_sibling
                elif self.parent.last_tag_child is self:
                    self.parent.last_tag_child = self.prev_sibling
                elif self.parent.last_theme_child is self:
                    self.parent.last_theme_child = self.prev_sibling
                elif self.parent.last_widgets_child is self:
                    self.parent.last_widgets_child = self.prev_sibling
                elif self.parent.last_window_child is self:
                    self.parent.last_window_child = self.prev_sibling
        # Free references
        self.parent = None
        self.prev_sibling = None
        self.next_sibling = None

    cpdef void detach_item(self):
        """
        Same as item.parent = None

        The item states (if any) are updated
        to indicate it is not rendered anymore,
        and the information propagated to the
        children.
        """
        cdef unique_lock[recursive_mutex] m0
        cdef unique_lock[recursive_mutex] m
        self._detach_item_and_lock(m)
        # Mark as hidden. Useful for OtherItemHandler
        # when we want to detect loss of hover, render, etc
        self.set_hidden_and_propagate_to_children_no_handlers()

    cpdef void delete_item(self):
        """
        When an item is not referenced anywhere, it might
        not get deleted immediately, due to circular references.
        The Python garbage collector will eventually catch
        the circular references, but to speedup the process,
        delete_item will recursively detach the item
        and all elements in its subtree, as well as bound
        items. As a result, items with no more references
        will be freed immediately.
        """
        cdef unique_lock[recursive_mutex] sibling_m

        cdef unique_lock[recursive_mutex] m
        self._detach_item_and_lock(m)
        # retaining the lock enables to ensure the item is
        # still detached

        # delete all children recursively
        if self.last_drawings_child is not None:
            (<baseItem>self.last_drawings_child)._delete_and_siblings()
        if self.last_handler_child is not None:
            (<baseItem>self.last_handler_child)._delete_and_siblings()
        if self.last_menubar_child is not None:
            (<baseItem>self.last_menubar_child)._delete_and_siblings()
        if self.last_plot_element_child is not None:
            (<baseItem>self.last_plot_element_child)._delete_and_siblings()
        if self.last_tab_child is not None:
            (<baseItem>self.last_tab_child)._delete_and_siblings()
        if self.last_tag_child is not None:
            (<baseItem>self.last_tag_child)._delete_and_siblings()
        if self.last_theme_child is not None:
            (<baseItem>self.last_theme_child)._delete_and_siblings()
        if self.last_widgets_child is not None:
            (<baseItem>self.last_widgets_child)._delete_and_siblings()
        if self.last_window_child is not None:
            (<baseItem>self.last_window_child)._delete_and_siblings()
        # TODO: free item specific references (themes, font, etc)
        self.last_drawings_child = None
        self.last_handler_child = None
        self.last_menubar_child = None
        self.last_plot_element_child = None
        self.last_tab_child = None
        self.last_tag_child = None
        self.last_theme_child = None
        self.last_widgets_child = None
        self.last_window_child = None
        # Note we don't free self.context, nor
        # destroy anything else: the item might
        # still be referenced for instance in handlers,
        # and thus should be valid.

    cdef void _delete_and_siblings(self):
        # Must only be called from delete_item or itself.
        # Assumes the parent mutex is already held
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        # delete all its children recursively
        if self.last_drawings_child is not None:
            (<baseItem>self.last_drawings_child)._delete_and_siblings()
        if self.last_handler_child is not None:
            (<baseItem>self.last_handler_child)._delete_and_siblings()
        if self.last_plot_element_child is not None:
            (<baseItem>self.last_plot_element_child)._delete_and_siblings()
        if self.last_tab_child is not None:
            (<baseItem>self.last_tab_child)._delete_and_siblings()
        if self.last_tag_child is not None:
            (<baseItem>self.last_tag_child)._delete_and_siblings()
        if self.last_theme_child is not None:
            (<baseItem>self.last_theme_child)._delete_and_siblings()
        if self.last_widgets_child is not None:
            (<baseItem>self.last_widgets_child)._delete_and_siblings()
        if self.last_window_child is not None:
            (<baseItem>self.last_window_child)._delete_and_siblings()
        # delete previous sibling
        if self.prev_sibling is not None:
            (<baseItem>self.prev_sibling)._delete_and_siblings()
        # Free references
        self.parent = None
        self.prev_sibling = None
        self.next_sibling = None
        self.last_drawings_child = None
        self.last_handler_child = None
        self.last_menubar_child = None
        self.last_plot_element_child = None
        self.last_tab_child = None
        self.last_tag_child = None
        self.last_theme_child = None
        self.last_widgets_child = None
        self.last_window_child = None

    @cython.final # The final is for performance, to avoid a virtual function and thus allow inlining
    cdef void set_previous_states(self) noexcept nogil:
        # Move current state to previous state
        if self.p_state != NULL:
            memcpy(<void*>&self.p_state.prev, <void*>&self.p_state.cur, sizeof(self.p_state.cur))

    @cython.final
    cdef void run_handlers(self) noexcept nogil:
        cdef int32_t i
        if not(self._handlers.empty()):
            for i in range(<int>self._handlers.size()):
                (<baseHandler>(self._handlers[i])).run_handler(self)

    @cython.final
    cdef void update_current_state_as_hidden(self) noexcept nogil:
        """
        Indicates the object is hidden
        """
        if (self.p_state == NULL):
            # No state
            return
        cdef bint open = self.p_state.cur.open
        memset(<void*>&self.p_state.cur, 0, sizeof(self.p_state.cur))
        # being open/closed is unaffected by being hidden
        self.p_state.cur.open = open

    @cython.final
    cdef void propagate_hidden_state_to_children_with_handlers(self) noexcept nogil:
        """
        Called during rendering only.
        The item has children, but will not render them
        (closed window, etc). The item itself might, or
        might not be rendered.
        Propagate the hidden state to children and call
        their handlers.

        Used also to avoid duplication in the functions below.
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if self.last_window_child is not None:
            (<baseItem>self.last_window_child).set_hidden_and_propagate_to_siblings_with_handlers()
        if self.last_widgets_child is not None:
            (<baseItem>self.last_widgets_child).set_hidden_and_propagate_to_siblings_with_handlers()
        if self.last_drawings_child is not None:
            (<baseItem>self.last_drawings_child).set_hidden_and_propagate_to_siblings_with_handlers()
        if self.last_plot_element_child is not None:
            (<baseItem>self.last_plot_element_child).set_hidden_and_propagate_to_siblings_with_handlers()
        # handlers, themes, font have no states and no children that can have some.
        # TODO: plotAxis

    @cython.final
    cdef void propagate_hidden_state_to_children_no_handlers(self) noexcept:
        """
        Same as above, but will not call any handlers. Used as helper for functions below
        Assumes the lock is already held.
        """
        if self.last_window_child is not None:
            (<baseItem>self.last_window_child).set_hidden_and_propagate_to_siblings_no_handlers()
        if self.last_widgets_child is not None:
            (<baseItem>self.last_widgets_child).set_hidden_and_propagate_to_siblings_no_handlers()
        if self.last_drawings_child is not None:
            (<baseItem>self.last_drawings_child).set_hidden_and_propagate_to_siblings_no_handlers()
        if self.last_plot_element_child is not None:
            (<baseItem>self.last_plot_element_child).set_hidden_and_propagate_to_siblings_no_handlers()

    @cython.final
    cdef void set_hidden_and_propagate_to_siblings_with_handlers(self) noexcept nogil:
        """
        A parent item is hidden and this item is not going to be rendered.
        Propagate to children and siblings.
        Called during rendering, thus we call the handlers, in order to help
        users catch an item getting hidden.
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)

        # Skip propagating and handlers if already hidden.
        if self.p_state == NULL or \
            self.p_state.cur.rendered:
            self.set_previous_states()
            self.update_current_state_as_hidden()
            self.propagate_hidden_state_to_children_with_handlers()
            self.run_handlers()
        if self.prev_sibling is not None:
            self.prev_sibling.set_hidden_and_propagate_to_siblings_with_handlers()

    @cython.final
    cdef void set_hidden_and_propagate_to_siblings_no_handlers(self) noexcept:
        """
        Same as above, version without calling handlers:
        Item is programmatically made hidden, but outside rendering,
        for instance by detaching it.

        The item might still be shown the next frame, and have been
        shown the frame before.

        What this function does is set the current state of item and
        its children to a hidden state, but not running any handler.
        This has these effects:
        TODO . If item was shown the frame before and is still shown,
          there will be no jump in the item status (for example
          it won't go from rendered, to not rendered, to rendered),
          as the current state will be overwritten when frame is rendered.
        . Possibly undesired effect, but with limited implications:
          when the item states will be read by the user before the frame
          is rendered, it will show the default hidden values.
        . The main reason we are doing this: if the item is not rendered,
          the states are correct (else they would remain as rendered forever),
          and thus we can have handlers attached to other items using
          OtherItemHandler to catch this item being not rendered. This is
          required for instance for items that should destroy when
          an item is not rendered anymore. 
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)

        # Skip propagating and handlers if already hidden.
        if self.p_state == NULL or \
            self.p_state.cur.rendered:
            self.update_current_state_as_hidden()
            self.propagate_hidden_state_to_children_no_handlers()
        if self.prev_sibling is not None:
            self.prev_sibling.set_hidden_and_propagate_to_siblings_no_handlers()

    @cython.final
    cdef void set_hidden_no_handler_and_propagate_to_children_with_handlers(self) noexcept nogil:
        """
        The item is hidden, wants its state to be set to hidden, but
        manages itself his previous state and his handlers.
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)

        # Skip propagating and handlers if already hidden.
        if self.p_state == NULL or \
            self.p_state.cur.rendered:
            self.update_current_state_as_hidden()
            self.propagate_hidden_state_to_children_with_handlers()

    @cython.final
    cdef void set_hidden_and_propagate_to_children_no_handlers(self) noexcept:
        """
        See set_hidden_and_propagate_to_siblings_no_handlers.
        Assumes the lock is already held
        """

        # Skip propagating and handlers if already hidden.
        if self.p_state == NULL or \
            self.p_state.cur.rendered:
            self.update_current_state_as_hidden()
            self.propagate_hidden_state_to_children_no_handlers()

    def lock_mutex(self, wait=False):
        """
        Lock the internal item mutex.
        **Know what you are doing**
        Locking the mutex will prevent:
        . Other threads from reading/writing
          attributes or calling methods with this item,
          editing the children/parent of the item
        . Any rendering of this item and its children.
          If the viewport attemps to render this item,
          it will be blocked until the mutex is released.
          (if the rendering thread is holding the mutex,
           no blocking occurs)
        This is useful if you want to edit several attributes
        in several commands of an item or its subtree,
        and prevent rendering or other threads from accessing
        the item until you have finished.
        If you plan on moving the item position in the rendering
        tree, to avoid deadlock you must hold the mutex of a
        parent of all the items involved in the motion (a common
        parent of the source and target parent). This mutex has to
        be locked before you lock any mutex of your child item
        if this item is already in the rendering tree (to avoid
        deadlock with the rendering thread).
        If you are unsure and plans to move an item already
        in the rendering tree, it is thus best to lock the viewport
        mutex first.

        Input argument:
        . wait (default = False): if locking the mutex fails (mutex
          held by another thread), wait it is released

        Returns: True if the mutex is held, False else.

        The mutex is a recursive mutex, thus you can lock it several
        times in the same thread. Each lock has to be matched to an unlock.
        """
        cdef bint locked = False
        locked = self.mutex.try_lock()
        if not(locked) and not(wait):
            return False
        if not(locked) and wait:
            while not(locked):
                with nogil:
                    # Wait the one holding the lock is done
                    # with it
                    self.mutex.lock()
                    # Unlock because we do not want to
                    # deadlock when acquiring the gil
                    self.mutex.unlock()
                locked = self.mutex.try_lock()
        self._external_lock += 1
        return True

    def unlock_mutex(self):
        """
        Unlock a previously held mutex on this object by this thread.
        Returns True on success, False if no lock was held by this thread.
        """
        cdef bint locked = False
        locked = self.mutex.try_lock()
        if locked and self._external_lock > 0:
            # We managed to lock and an external lock is held
            # thus we are indeed the owning thread
            self.mutex.unlock()
            self._external_lock -= 1
            self.mutex.unlock()
            return True
        return False

    @property
    def mutex(self):
        """
        Context manager instance for the item mutex

        Locking the mutex will prevent:
        . Other threads from reading/writing
          attributes or calling methods with this item,
          editing the children/parent of the item
        . Any rendering of this item and its children.
          If the viewport attemps to render this item,
          it will be blocked until the mutex is released.
          (if the rendering thread is holding the mutex,
           no blocking occurs)

        In general, you don't need to use any mutex in your code,
        unless you are writing a library and cannot make assumptions
        on what the users will do, or if you know your code manipulates
        the same objects with multiple threads.

        All attribute accesses are mutex protected.

        If you want to subclass and add attributes, you
        can use this mutex to protect your new attributes.
        Be careful not to hold the mutex if your thread
        intends to access the attributes of a parent item.
        In case of doubt use parents_mutex instead.
        """
        return wrap_mutex(self)

    @property
    def parents_mutex(self):
        """Context manager instance for the item mutex and all its parents
        
        Similar to mutex but locks not only this item, but also all
        its current parents.
        If you want to access parent fields, or if you are unsure,
        lock this mutex rather than self.mutex.
        This mutex will lock the item and all its parent in a safe
        way that does not deadlock.
        """
        return wrap_this_and_parents_mutex(self)

class wrap_mutex:
    def __init__(self, target):
        self.target = target
    def __enter__(self):
        self.target.lock_mutex(wait=True)
    def __exit__(self, exc_type, exc_value, traceback):
        self.target.unlock_mutex()
        return False # Do not catch exceptions

class wrap_this_and_parents_mutex:
    def __init__(self, target):
        self.target = target
        self.locked = []
        self.nlocked = []
        # TODO: Should we use thread-local here ?
    def __enter__(self):
        while True:
            locked = []
            # try_lock recursively all parents
            item = self.target
            success = True
            while item is not None:
                success = item.lock_mutex(wait=False)
                if not(success):
                    break
                locked.append(item)
                # we have a mutex on item, we can
                # access its parent field without
                # worrying it could change
                item = item.parent
            if success:
                self.locked += locked
                self.nlocked.append(len(locked))
                return
            # We failed to lock one of the parent.
            # We must release our locks and retry
            for item in locked:
                item.unlock_mutex()
            # release gil and give a chance to the
            # thread retaining the lock to run
            sched_yield()
    def __exit__(self, exc_type, exc_value, traceback):
        cdef int32_t N = self.nlocked.pop()
        cdef int32_t i
        for i in range(N):
            self.locked.pop().unlock_mutex()
        return False # Do not catch exceptions


@cython.final
@cython.no_gc_clear
cdef class Viewport(baseItem):
    """
    The viewport corresponds to the main item containing all the visuals.
    It is decorated by the operating system and can be minimized/maximized/made fullscreen.

    Attributes:
    - clear_color: Color used to clear the viewport.
    - small_icon: Small icon for the viewport.
    - large_icon: Large icon for the viewport.
    - x_pos: X position of the viewport.
    - y_pos: Y position of the viewport.
    - width: Width of the viewport.
    - height: Height of the viewport.
    - resizable: Boolean indicating if the viewport is resizable.
    - vsync: Boolean indicating if vsync is enabled.
    - dpi: Requested scaling (DPI) from the OS for this window.
    - scale: Multiplicative scale used to scale automatically all items.
    - min_width: Minimum width of the viewport.
    - max_width: Maximum width of the viewport.
    - min_height: Minimum height of the viewport.
    - max_height: Maximum height of the viewport.
    - always_on_top: Boolean indicating if the viewport is always on top.
    - decorated: Boolean indicating if the viewport is decorated.
    - handlers: Bound handler (or handlerList) for the viewport.
    - cursor: Mouse cursor for the viewport.
    - font: Global font for the viewport.
    - theme: Global theme for the viewport.
    - title: Title of the viewport.
    - disable_close: Boolean indicating if the close button is disabled.
    - fullscreen: Boolean indicating if the viewport is in fullscreen mode.
    - minimized: Boolean indicating if the viewport is minimized.
    - maximized: Boolean indicating if the viewport is maximized.
    - wait_for_input: Boolean indicating if rendering should wait for input.
    - shown: Boolean indicating if the viewport window has been created by the OS.
    - resize_callback: Callback to be issued when the viewport is resized.
    - close_callback: Callback to be issued when the viewport is closed.
    - metrics: Rendering related metrics relative to the last frame.
    """
    def __cinit__(self, context):
        self.resize_callback = None
        self.can_have_window_child = True
        self.can_have_viewport_drawlist_child = True
        self.can_have_menubar_child = True
        self.can_have_sibling = False
        self.last_t_before_event_handling = ctime.monotonic_ns()
        self.last_t_before_rendering = self.last_t_before_event_handling
        self.last_t_after_rendering = self.last_t_before_event_handling
        self.last_t_after_swapping = self.last_t_before_event_handling
        self.skipped_last_frame = False
        self.frame_count = 0
        self.wait_for_input = False
        self._target_refresh_time = 0.
        self.state.cur.rendered = True # For compatibility with RenderHandlers
        self.p_state = &self.state
        self._cursor = imgui.ImGuiMouseCursor_Arrow
        self._scale = 1.
        self.global_scale = 1. # non-zero needed for AutoFont.
        self._platform = \
            SDLViewport.create(internal_render_callback,
                               internal_resize_callback,
                               internal_close_callback,
                               internal_drop_callback,
                               <void*>self)
        if self._platform == NULL:
            raise RuntimeError("Failed to create the viewport")

    def __dealloc__(self):
        # NOTE: Called BEFORE the context is released.
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self._mutex_backend) # To not release while we render a frame
        ensure_correct_im_context(self.context)
        if self._platform != NULL:
            # Maybe just a warning ? Not sure how to solve this issue.
            #if not (<platformViewport*>self._platform).checkPrimaryThread():
            #    raise RuntimeError("Viewport deallocated from a different thread than the one it was created in")
            (<platformViewport*>self._platform).cleanup()
            self._platform = NULL

    def initialize(self, **kwargs):
        """
        Initialize the viewport for rendering and show it.

        Items can already be created and attached to the viewport
        before this call.

        Initializes the default font and attaches it to the
        viewport, if None is set already. This font size is scaled
        to be sharp at the target value of viewport.dpi * viewport.scale.
        It will scale automatically with scale changes (AutoFont).

        To change the font and have scale managements, look
        at the documentation of the FontTexture class, as well
        as AutoFont.
        """
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        cdef unique_lock[recursive_mutex] m3
        self.configure(**kwargs)
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self.mutex)
        lock_gil_friendly(m3, self._mutex_backend)
        ensure_correct_im_context(self.context)
        if self._initialized:
            raise RuntimeError("Viewport already initialized")
        ensure_correct_im_context(self.context)
        if not (<platformViewport*>self._platform).initialize():
            raise RuntimeError("Failed to initialize the viewport")
        imgui.StyleColorsDark()
        imgui.GetIO().ConfigWindowsMoveFromTitleBarOnly = True
        imgui.GetStyle().ScaleAllSizes((<platformViewport*>self._platform).dpiScale)
        self.global_scale = (<platformViewport*>self._platform).dpiScale * self._scale
        if self._font is None:
            self._font = AutoFont(self.context)
        self._initialized = True
        imgui.GetIO().IniFilename = NULL
        """
            # TODO if (GContext->IO.autoSaveIniFile). if (!GContext->IO.iniFile.empty())
			# io.IniFilename = GContext->IO.iniFile.c_str();

            # TODO if(GContext->IO.kbdNavigation)
		    # io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;  // Enable Keyboard Controls
            #if(GContext->IO.docking)
            # io.ConfigFlags |= ImGuiConfigFlags_DockingEnable;
            # io.ConfigDockingWithShift = GContext->IO.dockingShiftOnly;
        """

    cdef void __check_initialized(self):
        if not(self._initialized):
            raise RuntimeError("The viewport must be initialized before being used")

    cdef void __check_not_initialized(self):
        if self._initialized:
            raise RuntimeError("The viewport must be not be initialized to set this field")

    @property
    def clear_color(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return ((<platformViewport*>self._platform).clearColor[0],
                (<platformViewport*>self._platform).clearColor[1],
                (<platformViewport*>self._platform).clearColor[2],
                (<platformViewport*>self._platform).clearColor[3])

    @clear_color.setter
    def clear_color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color((<platformViewport*>self._platform).clearColor, parse_color(value))

    @property
    def small_icon(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str((<platformViewport*>self._platform).iconSmall)

    @small_icon.setter
    def small_icon(self, str value):
        cdef unique_lock[recursive_mutex] m
        self.__check_not_initialized()
        cdef string icon = value.encode("utf-8")
        (<platformViewport*>self._platform).iconSmall = icon

    @property
    def large_icon(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str((<platformViewport*>self._platform).iconLarge)

    @large_icon.setter
    def large_icon(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.__check_not_initialized()
        cdef string icon = value.encode("utf-8")
        (<platformViewport*>self._platform).iconLarge = icon

    @property
    def x_pos(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).positionX

    @x_pos.setter
    def x_pos(self, int32_t value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value == (<platformViewport*>self._platform).positionX:
            return
        (<platformViewport*>self._platform).positionX = value
        (<platformViewport*>self._platform).positionChangeRequested = True

    @property
    def y_pos(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).positionY

    @y_pos.setter
    def y_pos(self, int32_t value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value == (<platformViewport*>self._platform).positionY:
            return
        (<platformViewport*>self._platform).positionY = value
        (<platformViewport*>self._platform).positionChangeRequested = True

    @property
    def width(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).frameWidth

    @width.setter
    def width(self, int32_t value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        (<platformViewport*>self._platform).frameWidth = value
        (<platformViewport*>self._platform).sizeChangeRequested = True

    @property
    def height(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).frameHeight

    @height.setter
    def height(self, int32_t value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        (<platformViewport*>self._platform).frameHeight = value
        (<platformViewport*>self._platform).sizeChangeRequested = True

    @property
    def resizable(self) -> bool:
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).windowResizable

    @resizable.setter
    def resizable(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        (<platformViewport*>self._platform).windowResizable = value
        (<platformViewport*>self._platform).windowPropertyChangeRequested = True

    @property
    def vsync(self) -> bool:
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).hasVSync

    @vsync.setter
    def vsync(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        (<platformViewport*>self._platform).hasVSync = value

    @property
    def dpi(self) -> float:
        """
        Requested scaling (DPI) from the OS for
        this window. The value is valid after
        initialize() and might change over time,
        for instance if the window is moved to another
        monitor.

        The DPI is used to scale all items automatically.
        From the developper point of view, everything behaves
        as if the DPI is 1. This behaviour can be disabled
        using the related scaling settings.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).dpiScale

    @property
    def scale(self) -> float:
        """
        Multiplicative scale that, multiplied by
        the value of dpi, is used to scale
        automatically all items.

        Defaults to 1.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._scale

    @scale.setter
    def scale(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._scale = value

    @property
    def min_width(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).minWidth

    @min_width.setter
    def min_width(self, uint32_t value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        (<platformViewport*>self._platform).minWidth = value
        (<platformViewport*>self._platform).sizeChangeRequested = True

    @property
    def max_width(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).maxWidth

    @max_width.setter
    def max_width(self, uint32_t value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        (<platformViewport*>self._platform).maxWidth = value
        (<platformViewport*>self._platform).sizeChangeRequested = True

    @property
    def min_height(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).minHeight

    @min_height.setter
    def min_height(self, uint32_t value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        (<platformViewport*>self._platform).minHeight = value
        (<platformViewport*>self._platform).sizeChangeRequested = True

    @property
    def max_height(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).maxHeight

    @max_height.setter
    def max_height(self, uint32_t value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        (<platformViewport*>self._platform).maxHeight = value
        (<platformViewport*>self._platform).sizeChangeRequested = True

    @property
    def always_on_top(self) -> bool:
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).windowAlwaysOnTop

    @always_on_top.setter
    def always_on_top(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        (<platformViewport*>self._platform).windowAlwaysOnTop = value
        (<platformViewport*>self._platform).windowPropertyChangeRequested = True

    @property
    def decorated(self) -> bool:
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).windowDecorated

    @decorated.setter
    def decorated(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        (<platformViewport*>self._platform).windowDecorated = value
        (<platformViewport*>self._platform).windowPropertyChangeRequested = True

    @property
    def handlers(self):
        """
        Writable attribute: bound handler (or handlerList)
        for the viewport.
        Only Key and Mouse handlers are compatible.
        Handlers that check item states won't work.
        """
        cdef unique_lock[recursive_mutex] m
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list items = []
        cdef int32_t i
        if value is None:
            clear_obj_vector(self._handlers)
            return
        if not hasattr(value, "__len__"):
            value = [value]
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
    def cursor(self):
        """
        Change the mouse cursor to one of MouseCursor.
        The mouse cursor is reset every frame.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return <MouseCursor>self._cursor

    @cursor.setter
    def cursor(self, int32_t value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value < imgui.ImGuiMouseCursor_None or \
           value >= imgui.ImGuiMouseCursor_COUNT:
            raise ValueError("Invalid cursor type {value}")
        self._cursor = value

    @property
    def font(self):
        """
        Writable attribute: global font
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._font

    @font.setter
    def font(self, baseFont value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._font = value

    @property
    def theme(self):
        """
        Writable attribute: global theme
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._theme

    @theme.setter
    def theme(self, baseTheme value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._theme = value

    @property
    def title(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef string title = (<platformViewport*>self._platform).windowTitle
        return str(title, "utf-8")

    @title.setter
    def title(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef string title = value.encode("utf-8")
        (<platformViewport*>self._platform).windowTitle = title

    @property
    def disable_close(self) -> bool:
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._disable_close

    @disable_close.setter
    def disable_close(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._disable_close = value

    @property
    def fullscreen(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).isFullScreen

    @fullscreen.setter
    def fullscreen(self, bint value):
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        cdef unique_lock[recursive_mutex] m3
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self.mutex)
        lock_gil_friendly(m3, self._mutex_backend)
        ensure_correct_im_context(self.context)
        if value and not((<platformViewport*>self._platform).isFullScreen):
            (<platformViewport*>self._platform).shouldFullscreen = True
        elif not(value) and ((<platformViewport*>self._platform).isFullScreen):
            # Same call
            (<platformViewport*>self._platform).shouldFullscreen = True
    @property
    def minimized(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).isMinimized

    @minimized.setter
    def minimized(self, bint value):
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        cdef unique_lock[recursive_mutex] m3
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self.mutex)
        lock_gil_friendly(m3, self._mutex_backend)
        ensure_correct_im_context(self.context)
        if value and not((<platformViewport*>self._platform).isMinimized):
            (<platformViewport*>self._platform).shouldMinimize = True
        elif (<platformViewport*>self._platform).isMinimized:
            (<platformViewport*>self._platform).shouldRestore = True

    @property
    def maximized(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).isMaximized

    @maximized.setter
    def maximized(self, bint value):
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        cdef unique_lock[recursive_mutex] m3
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self.mutex)
        lock_gil_friendly(m3, self._mutex_backend)
        ensure_correct_im_context(self.context)
        if value and not((<platformViewport*>self._platform).isMaximized):
            (<platformViewport*>self._platform).shouldMaximize = True
        elif (<platformViewport*>self._platform).isMaximized:
            (<platformViewport*>self._platform).shouldRestore = True

    @property
    def visible(self):
        """State to control whether the viewport is associated to a window.
        If False, no window will be displayed for the viewport (offscreen rendering).
        Defaults to True"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).isVisible

    @visible.setter
    def visible(self, bint value):
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        cdef unique_lock[recursive_mutex] m3
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self.mutex)
        lock_gil_friendly(m3, self._mutex_backend)
        ensure_correct_im_context(self.context)
        if value and not((<platformViewport*>self._platform).isVisible):
            (<platformViewport*>self._platform).shouldShow = True
        elif (<platformViewport*>self._platform).isVisible:
            (<platformViewport*>self._platform).shouldHide = True

    @property
    def wait_for_input(self):
        """
        Writable attribute: When the app doesn't need to be
        refreshed, one can save power comsumption by not
        rendering. wait_for_input will pause rendering until
        a mouse or keyboard event is received.
        wake() can also be used to restart rendering
        for one frame.
        """
        return self.wait_for_input

    @wait_for_input.setter
    def wait_for_input(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.wait_for_input = value

    @property
    def shown(self) -> bool:
        """
        Whether the viewport window has been created by the
        operating system.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._initialized

    @property
    def resize_callback(self):
        """
        Callback to be issued when the viewport is resized.

        The data returned is a tuple containing:
        . The width in pixels
        . The height in pixels
        . The width according to the OS (OS dependent)
        . The height according to the OS (OS dependent)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._resize_callback

    @resize_callback.setter
    def resize_callback(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._resize_callback = value if isinstance(value, Callback) or value is None else Callback(value)

    @property
    def close_callback(self):
        """
        Callback to be issued when the viewport is closed.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._close_callback

    @close_callback.setter
    def close_callback(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._close_callback = value if isinstance(value, Callback) or value is None else Callback(value)

    def copy(self, target_context=None):
        raise TypeError("The viewport cannot be copied")

    @property
    def metrics(self):
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self.mutex)

        """
        Return rendering related metrics relative to the last
        frame.
        times are returned in ns and use the monotonic clock
        delta of times are return in float as seconds.

        Render frames does in the folowing order:
        event handling (wait_for_input has effect there)
        rendering (going through all objects and calling imgui)
        presenting to the os (send to the OS the rendered frame)

        No average is performed. To get FPS, one can
        average delta_whole_frame and invert it.

        frame_count corresponds to the frame number to which
        the data refers to.
        """
        return {
            "last_time_before_event_handling" : self.last_t_before_event_handling,
            "last_time_before_rendering" : self.last_t_before_rendering,
            "last_time_after_rendering" : self.last_t_after_rendering,
            "last_time_after_swapping": self.last_t_after_swapping,
            "delta_event_handling": self.delta_event_handling,
            "delta_rendering": self.delta_rendering,
            "delta_presenting": self.delta_swapping,
            "delta_whole_frame": self.delta_frame,
            "rendered_vertices": imgui.GetIO().MetricsRenderVertices,
            "rendered_indices": imgui.GetIO().MetricsRenderIndices,
            "rendered_windows": imgui.GetIO().MetricsRenderWindows,
            "active_windows": imgui.GetIO().MetricsActiveWindows,
            "frame_count" : self.frame_count-1,
        }

    @property
    def retrieve_framebuffer(self):
        """
        Whether to activate the framebuffer retrieval.
        If set to true, the framebuffer field will be
        populated. This has a performance cost.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._retrieve_framebuffer

    @retrieve_framebuffer.setter
    def retrieve_framebuffer(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._retrieve_framebuffer = value

    @property
    def framebuffer(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._frame_buffer


    def configure(self, **kwargs):
        for (key, value) in kwargs.items():
            setattr(self, key, value)

    cdef void __on_resize(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.context.queue_callback_arg4int(self._resize_callback,
                                            self,
                                            self,
                                            (<platformViewport*>self._platform).frameWidth,
                                            (<platformViewport*>self._platform).frameHeight,
                                            (<platformViewport*>self._platform).windowWidth,
                                            (<platformViewport*>self._platform).windowHeight)

    cdef void __on_close(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(self._disable_close):
            self.context._started = False
        self.context.queue_callback_noarg(self._close_callback, self, self)

    cdef void __on_drop(self, int32_t type, const char* data):
        """
        Drop operations are received in several pieces,
        we concatenate them before calling the user callback.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef string data_str
        if type == 0:
            # Start of a new drop operation
            self._drop_data.clear()
        elif type == 1:
            # Drop file
            data_str = data
            self.drop_is_file_type = True
            self._drop_data.push_back(data_str)
        elif type == 2:
            # Drop text
            data_str = data
            self.drop_is_file_type = False
            self._drop_data.push_back(data_str)
        elif type == 3:
            # End of drop operation
            self.context.queue_callback_arg1int1stringvector(
                self._drop_callback,
                self,
                self,
                1 if self.drop_is_file_type else 0,
                self._drop_data)
            self._drop_data.clear()


    cdef void __render(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef bint any_change = False
        self.last_t_before_rendering = ctime.monotonic_ns()
        # Initialize drawing state
        imgui.SetMouseCursor(self._cursor)
        self._cursor = imgui.ImGuiMouseCursor_Arrow
        self.set_previous_states()
        if self._font is not None:
            self._font.push()
        if self._theme is not None: # maybe apply in render_frame instead ?
            self._theme.push()
        self.redraw_needed = False
        cdef int32_t i
        for i in range(5):
            self.context.prev_last_id_button_catch[i] = \
                self.context.cur_last_id_button_catch[i]
            self.context.cur_last_id_button_catch[i] = 0
        self.shifts = [0., 0.]
        self.scales = [1., 1.]
        self.in_plot = False
        self.start_pending_theme_actions = 0
        self.parent_pos = make_Vec2(0., 0.)
        self.parent_size = make_Vec2((<platformViewport*>self._platform).frameWidth,
                                     (<platformViewport*>self._platform).frameHeight)
        self.window_pos = make_Vec2(0., 0.)
        self.window_cursor = make_Vec2(0., 0.)
        imgui.PushID(self.uuid)
        draw_menubar_children(self)
        draw_window_children(self)
        draw_viewport_drawlist_children(self)
        imgui.PopID()
        if self._theme is not None:
            self._theme.pop()
        if self._font is not None:
            self._font.pop()
        self.run_handlers()
        self.last_t_after_rendering = ctime.monotonic_ns()
        if self.redraw_needed:
            (<platformViewport*>self._platform).needsRefresh.store(True)
            (<platformViewport*>self._platform).shouldSkipPresenting = True
            # Skip presenting frames if we can afford
            # it and redraw fast hoping for convergence
            if not(self.skipped_last_frame):
                self.t_first_skip = self.last_t_after_rendering
                self.skipped_last_frame = True
            elif (self.last_t_after_rendering - self.t_first_skip) > 1e7:
                # 10 ms elapsed, redraw even if might not be perfect
                self.skipped_last_frame = False
                (<platformViewport*>self._platform).shouldSkipPresenting = False
        else:
            if self.skipped_last_frame:
                # probably not needed
                (<platformViewport*>self._platform).needsRefresh.store(True)
            self.skipped_last_frame = False
        return

    cdef void coordinate_to_screen(self, float *dst_p, double[2] src_p) noexcept nogil:
        """
        Used during rendering as helper to convert drawing coordinates to pixel coordinates
        """
        # assumes imgui + viewport mutex are held

        cdef imgui.ImVec2 plot_transformed
        cdef double[2] p
        p[0] = src_p[0] * self.scales[0] + self.shifts[0]
        p[1] = src_p[1] * self.scales[1] + self.shifts[1]
        if self.in_plot:
            if self.plot_fit:
                implot.FitPointX(src_p[0])
                implot.FitPointY(src_p[1])
            plot_transformed = \
                implot.PlotToPixels(src_p[0],
                                    src_p[1],
                                    -1,
                                    -1)
            dst_p[0] = plot_transformed.x
            dst_p[1] = plot_transformed.y
        else:
            # When in a plot, PlotToPixel already handles that.
            dst_p[0] = <float>p[0]
            dst_p[1] = <float>p[1]

    cdef void screen_to_coordinate(self, double *dst_p, float[2] src_p) noexcept nogil:
        """
        Used during rendering as helper to convert pixel coordinates to drawing coordinates
        """
        # assumes imgui + viewport mutex are held
        cdef imgui.ImVec2 screen_pos
        cdef implot.ImPlotPoint plot_pos
        if self.in_plot:
            screen_pos = imgui.ImVec2(src_p[0], src_p[1])
            # IMPLOT_AUTO uses current axes
            plot_pos = \
                implot.PixelsToPlot(screen_pos,
                                    implot.IMPLOT_AUTO,
                                    implot.IMPLOT_AUTO)
            dst_p[0] = plot_pos.x
            dst_p[1] = plot_pos.y
        else:
            dst_p[0] = <double>(src_p[0] - self.shifts[0]) / <double>self.scales[0]
            dst_p[1] = <double>(src_p[1] - self.shifts[1]) / <double>self.scales[1]

    cdef void push_pending_theme_actions(self,
                                         ThemeEnablers theme_activation_condition_enabled,
                                         ThemeCategories theme_activation_condition_category) noexcept nogil:
        """
        Used during rendering to apply themes defined by items
        parents and that should activate based on specific conditions
        Returns the number of theme actions applied. This number
        should be returned to pop_applied_pending_theme_actions
        """
        self._current_theme_activation_condition_enabled = theme_activation_condition_enabled
        self._current_theme_activation_condition_category = theme_activation_condition_category
        self.push_pending_theme_actions_on_subset(self.start_pending_theme_actions,
                                                  <int32_t>self.pending_theme_actions.size())

    cdef void push_pending_theme_actions_on_subset(self,
                                                   int32_t start,
                                                   int32_t end) noexcept nogil:
        cdef int32_t i
        cdef int32_t size_init = self._applied_theme_actions.size()
        cdef theme_action action
        cdef imgui.ImVec2 value_float2
        cdef ThemeEnablers theme_activation_condition_enabled = self._current_theme_activation_condition_enabled
        cdef ThemeCategories theme_activation_condition_category = self._current_theme_activation_condition_category

        cdef bool apply
        for i in range(start, end):
            apply = True
            if self.pending_theme_actions[i].activation_condition_enabled != ThemeEnablers.ANY and \
               theme_activation_condition_enabled != ThemeEnablers.ANY and \
               self.pending_theme_actions[i].activation_condition_enabled != theme_activation_condition_enabled:
                apply = False
            if self.pending_theme_actions[i].activation_condition_category != theme_activation_condition_category and \
               self.pending_theme_actions[i].activation_condition_category != ThemeCategories.t_any:
                apply = False
            if apply:
                action = self.pending_theme_actions[i]
                self._applied_theme_actions.push_back(action)
                if action.backend == theme_backends.t_imgui:
                    if action.type == theme_types.t_color:
                        # can only be theme_value_types.t_u32
                        imgui.PushStyleColor(<imgui.ImGuiCol>action.theme_index,
                                             action.value.value_u32)
                    elif action.type == theme_types.t_style:
                        if action.value_type == theme_value_types.t_float:
                            imgui.PushStyleVar(<imgui.ImGuiStyleVar>action.theme_index,
                                               action.value.value_float)
                        elif action.value_type == theme_value_types.t_float2:
                            if action.float2_mask == theme_value_float2_mask.t_left:
                                imgui.PushStyleVarX(<imgui.ImGuiStyleVar>action.theme_index,
                                                    action.value.value_float2[0])
                            elif action.float2_mask == theme_value_float2_mask.t_right:
                                imgui.PushStyleVarY(<imgui.ImGuiStyleVar>action.theme_index,
                                                    action.value.value_float2[1])
                            else:
                                value_float2 = imgui.ImVec2(action.value.value_float2[0],
                                                            action.value.value_float2[1])
                                imgui.PushStyleVar(<imgui.ImGuiStyleVar>action.theme_index,
                                                   value_float2)
                elif action.backend == theme_backends.t_implot:
                    if action.type == theme_types.t_color:
                        # can only be theme_value_types.t_u32
                        implot.PushStyleColor(<implot.ImPlotCol>action.theme_index,
                                             action.value.value_u32)
                    elif action.type == theme_types.t_style:
                        if action.value_type == theme_value_types.t_float:
                            implot.PushStyleVar(<implot.ImPlotStyleVar>action.theme_index,
                                               action.value.value_float)
                        elif action.value_type == theme_value_types.t_int:
                            implot.PushStyleVar(<implot.ImPlotStyleVar>action.theme_index,
                                               action.value.value_int)
                        elif action.value_type == theme_value_types.t_float2:
                            if action.float2_mask == theme_value_float2_mask.t_left:
                                implot.PushStyleVarX(<implot.ImPlotStyleVar>action.theme_index,
                                                     action.value.value_float2[0])
                            elif action.float2_mask == theme_value_float2_mask.t_right:
                                implot.PushStyleVarY(<implot.ImPlotStyleVar>action.theme_index,
                                                     action.value.value_float2[1])
                            else:
                                value_float2 = imgui.ImVec2(action.value.value_float2[0],
                                                            action.value.value_float2[1])
                                implot.PushStyleVar(<implot.ImPlotStyleVar>action.theme_index,
                                                    value_float2)
                elif action.backend == theme_backends.t_imnodes:
                    if action.type == theme_types.t_color:
                        # can only be theme_value_types.t_u32
                        imnodes.PushColorStyle(<imnodes.ImNodesCol>action.theme_index,
                                             action.value.value_u32)
                    elif action.type == theme_types.t_style:
                        if action.value_type == theme_value_types.t_float:
                            imnodes.PushStyleVar(<imnodes.ImNodesStyleVar>action.theme_index,
                                               action.value.value_float)
                        elif action.value_type == theme_value_types.t_float2:
                            # TODO X/Y when needed
                            value_float2 = imnodes.ImVec2(action.value.value_float2[0],
                                                        action.value.value_float2[1])
                            imnodes.PushStyleVar(<imnodes.ImNodesStyleVar>action.theme_index,
                                               value_float2)
        self._applied_theme_actions_count.push_back(self._applied_theme_actions.size() - size_init)

    cdef void pop_applied_pending_theme_actions(self) noexcept nogil:
        """
        Used during rendering to pop what push_pending_theme_actions did
        """
        cdef int32_t count = self._applied_theme_actions_count.back()
        self._applied_theme_actions_count.pop_back()
        if count == 0:
            return
        cdef int32_t i
        cdef int32_t size = self._applied_theme_actions.size()
        cdef theme_action action
        for i in range(count):
            action = self._applied_theme_actions[size-i-1]
            if action.backend == theme_backends.t_imgui:
                if action.type == theme_types.t_color:
                    imgui.PopStyleColor(1)
                elif action.type == theme_types.t_style:
                    imgui.PopStyleVar(1)
            elif action.backend == theme_backends.t_implot:
                if action.type == theme_types.t_color:
                    implot.PopStyleColor(1)
                elif action.type == theme_types.t_style:
                    implot.PopStyleVar(1)
            elif action.backend == theme_backends.t_imnodes:
                if action.type == theme_types.t_color:
                    imnodes.PopColorStyle()
                elif action.type == theme_types.t_style:
                    imnodes.PopStyleVar(1)
        for i in range(count):
            self._applied_theme_actions.pop_back()


    def render_frame(self, bint can_skip_presenting=False):
        """
        Render one frame.

        Rendering occurs in several separated steps:
        . Mouse/Keyboard events are processed. it's there
          that wait_for_input has an effect.
        . The viewport item, and then all the rendering tree are
          walked through to query their state and prepare the rendering
          commands using ImGui, ImPlot and ImNodes
        . The rendering commands are submitted to the GPU.
        . The submission is passed to the operating system to handle the
          window update. It's usually at this step that the system will
          apply vsync by making the application wait if it rendered faster
          than the screen refresh rate.

        can_skip_presenting: rendering will occur (handlers checked, etc),
            but the backend might decide, if this flag is set, to not
            submit the rendering commands to the GPU and refresh the
            window. Can be used to avoid using the GPU in response
            to a simple mouse motion.
            Fast checks are used to determine if presenting should occur
            or not. Thus set this only if you haven't updated any content
            on the screen.
            Note wake() will automatically force a redraw the next frame.

        Returns True if the frame was presented to the screen,
            False else (can_skip_presenting)
        """
        # to lock in this order
        cdef unique_lock[recursive_mutex] imgui_m = unique_lock[recursive_mutex](self.context.imgui_mutex, defer_lock_t()) # TODO: probably needs to protect processEvents and GetIO
        cdef unique_lock[recursive_mutex] self_m
        cdef unique_lock[recursive_mutex] backend_m = unique_lock[recursive_mutex](self._mutex_backend, defer_lock_t())
        lock_gil_friendly(self_m, self.mutex)
        self.__check_initialized()
        if not (<platformViewport*>self._platform).checkPrimaryThread():
            raise RuntimeError("render_frame must be called from the thread where the context was created")
        ensure_correct_im_context(self.context)
        self.last_t_before_event_handling = ctime.monotonic_ns()
        cdef double current_time_s, target_timeout_ms
        cdef bint should_present
        cdef float gs = self.global_scale
        self.global_scale = (<platformViewport*>self._platform).dpiScale * self._scale
        cdef imgui.ImGuiStyle *style = &imgui.GetStyle()
        cdef implot.ImPlotStyle *style_p = &implot.GetStyle()
        cdef Texture framebuffer
        # Handle scaling
        if gs != self.global_scale:
            gs = self.global_scale
            style.WindowPadding = imgui.ImVec2(cround(gs*8), cround(gs*8))
            #style.WindowRounding = cround(gs*0.)
            style.WindowMinSize = imgui.ImVec2(cround(gs*32), cround(gs*32))
            #style.ChildRounding = cround(gs*0.)
            #style.PopupRounding = cround(gs*0.)
            style.FramePadding = imgui.ImVec2(cround(gs*4.), cround(gs*3.))
            #style.FrameRounding = cround(gs*0.)
            style.ItemSpacing = imgui.ImVec2(cround(gs*8.), cround(gs*4.))
            style.ItemInnerSpacing = imgui.ImVec2(cround(gs*4.), cround(gs*4.))
            style.CellPadding = imgui.ImVec2(cround(gs*4.), cround(gs*2.))
            #style.TouchExtraPadding = imgui.ImVec2(cround(gs*0.), cround(gs*0.))
            style.IndentSpacing = cround(gs*21.)
            style.ColumnsMinSpacing = cround(gs*6.)
            style.ScrollbarSize = cround(gs*14.)
            style.ScrollbarRounding = cround(gs*9.)
            style.GrabMinSize = cround(gs*12.)
            #style.GrabRounding = cround(gs*0.)
            style.LogSliderDeadzone = cround(gs*4.)
            style.TabRounding = cround(gs*4.)
            #style.TabMinWidthForCloseButton = cround(gs*0.)
            style.TabBarOverlineSize = cround(gs*2.)
            style.SeparatorTextPadding = imgui.ImVec2(cround(gs*20.), cround(gs*3.))
            style.DisplayWindowPadding = imgui.ImVec2(cround(gs*19.), cround(gs*19.))
            style.DisplaySafeAreaPadding = imgui.ImVec2(cround(gs*3.), cround(gs*3.))
            style.MouseCursorScale = gs*1.
            style_p.LineWeight = gs*1.
            style_p.MarkerSize = gs*4.
            style_p.MarkerWeight = gs*1
            style_p.ErrorBarSize = cround(gs*5.)
            style_p.ErrorBarWeight = gs * 1.5
            style_p.DigitalBitHeight = cround(gs * 8.)
            style_p.DigitalBitGap = cround(gs * 4.)
            style_p.MajorTickLen = imgui.ImVec2(gs*10, gs*10)
            style_p.MinorTickLen = imgui.ImVec2(gs*5, gs*5)
            style_p.MajorTickSize = imgui.ImVec2(gs*1, gs*1)
            style_p.MinorTickSize = imgui.ImVec2(gs*1, gs*1)
            style_p.MajorGridSize = imgui.ImVec2(gs*1, gs*1)
            style_p.MinorGridSize = imgui.ImVec2(gs*1, gs*1)
            style_p.PlotPadding = imgui.ImVec2(cround(gs*10), cround(gs*10))
            style_p.LabelPadding = imgui.ImVec2(cround(gs*5), cround(gs*5))
            style_p.LegendPadding = imgui.ImVec2(cround(gs*10), cround(gs*10))
            style_p.LegendInnerPadding = imgui.ImVec2(cround(gs*5), cround(gs*5))
            style_p.LegendSpacing = imgui.ImVec2(cround(gs*5), cround(gs*0))
            style_p.MousePosPadding = imgui.ImVec2(cround(gs*10), cround(gs*10))
            style_p.AnnotationPadding = imgui.ImVec2(cround(gs*2), cround(gs*2))
            style_p.PlotDefaultSize = imgui.ImVec2(cround(gs*400), cround(gs*300))
            style_p.PlotMinSize = imgui.ImVec2(cround(gs*200), cround(gs*150))
        with nogil:
            backend_m.lock()
            self_m.unlock()
            # Process input events.
            # Doesn't need imgui mutex.
            # if wait_for_input is set, can take a long time
            current_time_s = self.last_t_before_event_handling * 1e-9
            target_timeout_ms = (self._target_refresh_time - current_time_s) * 1000.
            target_timeout_ms = max(0., ceil(target_timeout_ms))
            (<platformViewport*>self._platform).processEvents(<int>target_timeout_ms)
            if self.wait_for_input:
                self._target_refresh_time = current_time_s + 5.
            else:
                self._target_refresh_time = 0
            backend_m.unlock() # important to respect lock order
            # Core rendering - uses imgui and viewport
            imgui_m.lock()
            self_m.lock()
            backend_m.lock()
            #self.last_t_before_rendering = ctime.monotonic_ns()
            
            #imgui.GetMainViewport().DpiScale = self.viewport.dpi
            #imgui.GetIO().FontGlobalScale = self.viewport.dpi
            should_present = \
                (<platformViewport*>self._platform).renderFrame(can_skip_presenting)
            #self.last_t_after_rendering = ctime.monotonic_ns()
            backend_m.unlock()
            self_m.unlock()
            imgui_m.unlock()
            # Present doesn't use imgui but can take time (vsync)
            backend_m.lock()
            if should_present:
                if self._retrieve_framebuffer:
                    with gil:
                        try:
                            while True:
                                framebuffer = Texture(self.context)
                                framebuffer.allocate(width=(<platformViewport*>self._platform).frameWidth,
                                                     height=(<platformViewport*>self._platform).frameHeight,
                                                     num_chans=4,
                                                     uint8=True)
                                if not (<platformViewport*>self._platform).backBufferToTexture(framebuffer.allocated_texture,
                                                                                               framebuffer.width,
                                                                                               framebuffer.height,
                                                                                               framebuffer.num_chans,
                                                                                               framebuffer._buffer_type):
                                    break
                                self._frame_buffer = framebuffer
                                break
                        except Exception as e:
                            print(f"Failed to retrieve framebuffer: {e}")
                (<platformViewport*>self._platform).present()
            backend_m.unlock()
        if not(should_present) and (<platformViewport*>self._platform).hasVSync:
            # cap 'cpu' framerate when not presenting
            python_time.sleep(0.005)
        lock_gil_friendly(self_m, self.mutex)
        cdef long long current_time = ctime.monotonic_ns()
        self.delta_frame = 1e-9 * <float>(current_time - self.last_t_after_swapping)
        self.last_t_after_swapping = current_time
        self.delta_swapping = 1e-9 * <float>(current_time - self.last_t_after_rendering)
        self.delta_rendering = 1e-9 * <float>(self.last_t_after_rendering - self.last_t_before_rendering)
        self.delta_event_handling = 1e-9 * <float>(self.last_t_before_rendering - self.last_t_before_event_handling)
        self.frame_count += 1
        assert(self.pending_theme_actions.empty())
        assert(self._applied_theme_actions.empty())
        assert(self.start_pending_theme_actions == 0)
        return should_present

    def wake(self):
        """
        In case rendering is waiting for an input (wait_for_input),
        generate a fake input to force rendering.

        This is useful if you have updated the content asynchronously
        and want to show the update
        """
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self.mutex)
        (<platformViewport*>self._platform).wakeRendering()

    cdef void ask_refresh_after(self, double monotonic) noexcept nogil:
        """
        Called during draw to request that a new draw should
        occur when monotonic time is reached. The next draw might
        still occur before the target, in which case, the function
        should be called again.
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.context.imgui_mutex)
        cdef unique_lock[recursive_mutex] m2 = unique_lock[recursive_mutex](self.mutex)
        self._target_refresh_time = min(self._target_refresh_time, monotonic)

    cdef void force_present(self) noexcept nogil:
        """
        Called during draw to disable frame presentation skipping
        for this frame. This is useful when the content of the item
        drawn has changed, but the viewport is unable to detect it.
        Note the frame might still skip presentation if a broken
        visual is detected, but in which case a new frame will
        be redrawn and presented right after.
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        (<platformViewport*>self._platform).needsRefresh.store(True)

    cdef Vec2 get_size(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef Vec2 size
        size.x = (<platformViewport*>self._platform).frameWidth
        size.y = (<platformViewport*>self._platform).frameHeight
        return size

    cdef void *get_platform_window(self) noexcept nogil:
        return (<SDLViewport*>self._platform).getSDLWindowHandle()

# Callbacks


cdef class Callback:
    """
    Wrapper class that automatically encapsulate callbacks.

    Callbacks in DCG mode can take up to 3 arguments:
    - source_item: the item to which the callback was attached
    - target_item: the item for which the callback was raised.
        Is only different to source_item for handlers' callback.
    - call_info: If applicable information about the call (key button, etc)
    """
    def __init__(self, *args, **kwargs):
        if self.num_args > 3:
            raise ValueError("Callback function takes too many arguments")
    def __cinit__(self, callback, *args, **kwargs):
        if not(callable(callback)):
            raise TypeError("Callback requires a callable object")
        self.callback = callback
        cdef int32_t num_defaults = 0
        if callback.__defaults__ is not None:
            num_defaults = len(callback.__defaults__)
        self.num_args = callback.__code__.co_argcount - num_defaults
        if hasattr(callback, '__self__'):
            self.num_args -= 1

    def __call__(self, source_item, target_item, call_info):
        try:
            if self.num_args == 3:
                self.callback(source_item, target_item, call_info)
            elif self.num_args == 2:
                self.callback(source_item, target_item)
            elif self.num_args == 1:
                self.callback(source_item)
            else:
                self.callback()
        except Exception as e:
            print(f"Callback {self.callback} raised exception {e}")
            if self.num_args == 3:
                print(f"Callback arguments were: {source_item}, {target_item}, {call_info}")
            if self.num_args == 2:
                print(f"Callback arguments were: {source_item}, {target_item}")
            if self.num_args == 1:
                print(f"Callback argument was: {source_item}")
            else:
                print("Callback called without arguments")
            print(traceback.format_exc())

cdef class DPGCallback(Callback):
    """
    Used to run callbacks created for DPG.
    """
    def __call__(self, source_item, target_item, call_info):
        try:
            if source_item is not target_item:
                if isinstance(call_info, tuple):
                    call_info = tuple(list(call_info) + [target_item])
            if self.num_args == 3:
                self.callback(source_item.uuid, call_info, source_item.user_data)
            elif self.num_args == 2:
                self.callback(source_item.uuid, call_info)
            elif self.num_args == 1:
                self.callback(source_item.uuid)
            else:
                self.callback()
        except Exception as e:
            print(f"Callback {self.callback} raised exception {e}")
            if self.num_args == 3:
                print(f"Callback arguments were: {source_item.uuid} (for {source_item}), {call_info}, {source_item.user_data}")
            if self.num_args == 2:
                print(f"Callback arguments were: {source_item.uuid} (for {source_item}), {call_info}")
            if self.num_args == 1:
                print(f"Callback argument was: {source_item.uuid} (for {source_item})")
            else:
                print("Callback called without arguments")
            print(traceback.format_exc())

"""
PlaceHolder parent
To store items outside the rendering tree
Can be parent to anything.
Cannot have any parent. Thus cannot render.
"""
cdef class PlaceHolderParent(baseItem):
    """
    Placeholder parent to store items outside the rendering tree.
    Can be a parent to anything but cannot have any parent itself.
    """
    def __cinit__(self):
        self.can_have_drawing_child = True
        self.can_have_handler_child = True
        self.can_have_menubar_child = True
        self.can_have_plot_element_child = True
        self.can_have_tab_child = True
        self.can_have_tag_child = True
        self.can_have_theme_child = True
        self.can_have_viewport_drawlist_child = True
        self.can_have_widget_child = True
        self.can_have_window_child = True


"""
States used by many items
"""

cdef void update_current_mouse_states(itemState& state) noexcept nogil:
    """
    Helper to fill common states. Must be called after the hovered state is updated
    """
    cdef int32_t i
    if state.cap.can_be_clicked:
        if state.cur.hovered:
            for i in range(<int>imgui.ImGuiMouseButton_COUNT):
                state.cur.clicked[i] = imgui.IsMouseClicked(i, False)
                state.cur.double_clicked[i] = imgui.IsMouseDoubleClicked(i)
        else:
            for i in range(<int>imgui.ImGuiMouseButton_COUNT):
                state.cur.clicked[i] = False
                state.cur.double_clicked[i] = False
    cdef bint dragging
    if state.cap.can_be_dragged:
        if state.cur.hovered:
            for i in range(<int>imgui.ImGuiMouseButton_COUNT):
                dragging = imgui.IsMouseDragging(i, -1.)
                state.cur.dragging[i] = dragging
                if dragging:
                    state.cur.drag_deltas[i] = ImVec2Vec2(imgui.GetMouseDragDelta(i, -1.))
        else:
            for i in range(<int>imgui.ImGuiMouseButton_COUNT):
                state.cur.dragging[i] = False

# Drawing items base class

cdef class drawingItem(baseItem):
    """
    A simple item with no UI state that inherits from the drawing area of its parent.
    """
    def __cinit__(self):
        self._show = True
        self.element_child_category = child_type.cat_drawing
        self.can_have_sibling = True

    @property
    def show(self):
        """
        Writable attribute: Should the object be drawn/shown ?
        In case show is set to False, this disables any
        callback (for example the close callback won't be called
        if a window is hidden with show = False).
        In the case of items that can be closed,
        show is set to False automatically on close.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._show
    @show.setter
    def show(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(value) and self._show:
            self.set_hidden_and_propagate_to_children_no_handlers()
        self._show = value

    '''
    cdef void _copy(self, object target):
        cdef drawingItem target_base = <drawingItem>target
        if type(self) is not drawingItem:
            self._copy_default(target)
            return
        target_base._show = self._show
        baseItem._copy(self, target_base)
    '''

    cdef void draw(self, void* l) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        return


"""
InvisibleDrawButton: main difference with InvisibleButton
is that it doesn't use the cursor and doesn't change
the window maximum content area. In addition it allows
overlap of InvisibleDrawButtons and considers itself
in a pressed state as soon as the mouse is down.
"""

cdef extern from * nogil:
    """
    bool InvisibleDrawButton(int32_t uuid,
                             const ImVec2& pos,
                             const ImVec2& size,
                             ImGuiID prev_last_id_button_catch[5],
                             ImGuiID cur_last_id_button_catch[5],
                             int32_t button_mask,
                             bool catch_ui_hover,
                             bool first_hovered_wins,
                             bool catch_active,
                             bool *out_hovered,
                             bool *out_held)
    {
        ImGuiContext& g = *GImGui;
        ImGuiWindow* window = ImGui::GetCurrentWindow();
        const ImVec2 end = ImVec2(pos.x + size.x, pos.y + size.y);
        const ImRect bb(pos, end);
        int32_t i;
        bool toplevel = false;

        const ImGuiID id = window->GetID(uuid);
        ImGui::KeepAliveID(id);

        bool hovered, pressed;
        bool mouse_down = false;
        bool mouse_clicked = false;
        hovered = ImGui::IsMouseHoveringRect(bb.Min, bb.Max);
        if ((!hovered || g.HoveredWindow != window) && g.ActiveId != id) {
            // Fast path
            return false;
        }

        // We are either hovered, or active.
        if (g.HoveredWindow != window)
            hovered = false;

        if (button_mask == 0) {
            // No button mask, we are not interested
            // in the button state, and want a simple
            // hover test.
            *out_hovered |= hovered;
            return false;
        }

        button_mask >>= 1;

        // Check if we are toplevel
        for (i=0; i<5; i++) {
            if (button_mask & (1 << i)) {
                if (prev_last_id_button_catch[i] == id) {
                    toplevel = true;
                    break;
                }
            }
        }

        // Set status for next frame
        // if first_hovered_wins is False, only the top
        // item will be hovered.
        // Else we will retain the hovered state
        for (i=0; i<5; i++) {
            if (button_mask & (1 << i)) {
                if (!first_hovered_wins ||
                    prev_last_id_button_catch[i] == id ||
                    prev_last_id_button_catch[i] == 0) {
                    cur_last_id_button_catch[i] = id;
                }
            }
        }

        hovered = hovered && toplevel;

        // Maintain UI hover status (needed for HoveredWindow)
        if (hovered && g.HoveredIdPreviousFrame == id)
            ImGui::SetHoveredID(id);
        // Catch hover if we requested to
        else if (hovered && catch_ui_hover)
            ImGui::SetHoveredID(id);
        // No other UI item hovered rendered before
        else if (hovered && (g.HoveredId == id || g.HoveredId == 0))
            ImGui::SetHoveredID(id);

        if (g.ActiveId != 0 && g.ActiveId != id && !catch_active) {
            // Another item is active, and we are not
            // allowed to catch active.
            *out_hovered |= hovered;
            return false;
        }

        for (i=0; i<5; i++) {
            if (button_mask & (1 << i)) {
                if (g.IO.MouseDown[i]) {
                    mouse_down = true;
                    break;
                }
            }
        }

        for (i=0; i<5; i++) {
            if (button_mask & (1 << i)) {
                if (g.IO.MouseClicked[i]) {
                    mouse_clicked = true;
                    break;
                }
            }
        }

        pressed = false;
        if (hovered && mouse_down) {
            // we are hovered, toplevel and the mouse is down
            if (g.ActiveId == 0 || catch_active) {
                // We are not active, and we are hovered.
                // We are now active.
                ImGui::SetFocusID(id, window);
                ImGui::FocusWindow(window);
                ImGui::SetActiveID(id, window);
                // TODO: KeyOwner ??
                pressed = mouse_clicked; // Pressed on click
            }
        }

        if (!mouse_down && g.ActiveId == id) {
            // We are not hovered, but we are active.
            // We are no longer active.
            ImGui::ClearActiveID();
        }

        *out_hovered |= hovered;
        *out_held |= g.ActiveId == id;

        return pressed;
    }
    """
    bint InvisibleDrawButton(int32_t uuid,
                             imgui.ImVec2& pos,
                             imgui.ImVec2& size,
                             uint32_t[5] &prev_last_id_button_catch,
                             uint32_t[5] &cur_last_id_button_catch,
                             int32_t button_mask,
                             bint catch_hover,
                             bint retain_hovership,
                             bint catch_active,
                             bool *out_hovered,
                             bool *out_held)

cdef bint button_area(Context context,
                      int32_t uuid,
                      Vec2 pos,
                      Vec2 size,
                      int32_t button_mask,
                      bint catch_ui_hover,
                      bint first_hovered_wins,
                      bint catch_active,
                      bool *out_hovered,
                      bool *out_held) noexcept nogil:
    """
    Register a button area and check its status.
    Must be called in draw() everytime the item is rendered.

    The button area behaves a bit different to normal
    buttons and is not intended to create custom UI buttons,
    but to create interactable areas in drawings and plots.

    To enable various "items" to be overlapping and reacting
    to different buttons, button_area takes a button_mask indicating
    to which mouse button the area reacts to.
    The hovered state is individual to each button (and separate
    to the hovered state of UI items).
    However the active state is similar to UI items and shared with them.

    Context: the context instance
    uuid: Must be unique (for example the item uuid for which the button is registered).
        If you need to register several buttons for an item, you have two choices:
        - Generate a different uuid for each button. Each will have a different state.
        - Share the uuid for all buttons. In that case they will share the active (held) state.
    pos: position of the top left corner of the button in screen space (top-down y)
    size: size of the button in pixels
    button_mask: binary mask for the 5 possible buttons (0 = left, 1 = right, 2 = middle)
        pressed and held will only react to mouse buttons in button_mask.
        If a button is not in button_mask, it allows another overlapped
        button to take the active state.
    catch_ui_hover:
        If True, when hovered and top level for at least one button,
        will catch the UI hover (there is a single uiItem hovered at
        a time) state even if another (uiItem) item is hovered.
        For instance if you are overlapping a plot, the plot
        will be considered hovered if catch_ui_hover=False, and
        not hovered if catch_ui_hover=True. This does not affect
        other items using this function, as it allows several
        items to be hovered at the same time if they register
        different button masks.
        It is usually set to True to disable plot panning.
        If set to False, the UI hover state might still be registered
        if the button is hovered and no other item is hovered.
    first_hovered_wins:
        if False, only the top-level item will be hovered in case of overlap,
        no matter which item was hovered the previous frame.
        If True, the first item hovered (for a given button)
        will retain the hovered state as long as it is hovered.
        In general you want to set this to True, unless you have
        small buttons completly included in other large buttons,
        in which can you want to set this to False to be able
        to access the small buttons.
        Note this is a collaborative setting. If all items
        but one have first_hovered_wins set to True, the
        one with False will steal the hovered state when hovered.
    catch_active:
        Usually one want in case of overlapping items to retain the
        active state on the first item that registers the active state.
        This state blocks this behaviour by catching the active state
        even if another item is active. active == held == registered itself
        when the mouse clicked on it and no other item stole activation,
        and the mouse is not released.
    out_hovered:
        WARNING: Should be initialized to False before this call.
        Will be set to True if the button is hovered.
        if button_mask is 0, a simple hovering test is performed,
        without checking the hovering state of other items.
        Else, the button will be hovered only if it is toplevel
        for at least one button in button_mask (+ behaviour described
        in catch_hover)
    out_held:
        WARNING: Should be initialized to False before this call.
        Will be set to True if the button is held. A button is held
        if it was clicked on and the mouse is not released. See
        the description of catch_active.

    out_held and out_hovered must be initialized outside
    the function (to False), this behaviour enables to accumulate
    the states for several buttons. Their content has no impact
    of the logic inside the function.

    Returns True if the button was pressed (clicked on), False else.
    Only the first frame of the click is considered.

    This function is very fast and in most cases will be a simple
    rectangular boundary check.

    Use cases:
    - Simple hover test: button_mask = 0
    - Many buttons of similar sizes with overlapping and equal priority:
        first_hovered_wins = True, catch_ui_hover = True, catch_active = False
    - Creating a button in front of the mouse to catch the click:
        catch_active = True

    button_mask can be played with in order to have overlapping
    buttons of various sizes listening to separate buttons.
    """
    return InvisibleDrawButton(uuid,
                               Vec2ImVec2(pos),
                               Vec2ImVec2(size),
                               context.prev_last_id_button_catch,
                               context.cur_last_id_button_catch,
                               button_mask,
                               catch_ui_hover,
                               first_hovered_wins,
                               catch_active,
                               out_hovered,
                               out_held)

"""
Sources
"""

cdef class SharedValue:
    """
    Represents a shared value that can be used by multiple items.

    Attributes:
    - value: Main value of the shared object.
    - shareable_value: Shareable value of the shared object.
    - last_frame_update: Last frame index when the value was updated.
    - last_frame_change: Last frame index when the value was changed.
    - num_attached: Number of items sharing this value.
    """
    def __init__(self, *args, **kwargs):
        # We create all shared objects using __new__, thus
        # bypassing __init__. If __init__ is called, it's
        # from the user.
        # __init__ is called after __cinit__
        self._num_attached = 0
    def __cinit__(self, Context context, *args, **kwargs):
        self.context = context
        self._last_frame_change = context.viewport.frame_count
        self._last_frame_update = context.viewport.frame_count
        self._num_attached = 1
    @property
    def value(self):
        return None
    @value.setter
    def value(self, value):
        if value is None:
            # In case of automated backup of
            # the value of all items
            return
        raise ValueError("Shared value is empty. Cannot set.")

    @property
    def shareable_value(self):
        return self

    @property
    def last_frame_update(self):
        """
        Readable attribute: last frame index when the value
        was updated (can be identical value).
        """
        return self._last_frame_update

    @property
    def last_frame_change(self):
        """
        Readable attribute: last frame index when the value
        was changed (different value).
        For non-scalar data (color, point, vector), equals to
        last_frame_update to avoid heavy comparisons.
        """
        return self._last_frame_change

    @property
    def num_attached(self):
        """
        Readable attribute: Number of items sharing this value
        """
        return self._num_attached

    cdef void on_update(self, bint changed) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        # TODO: figure out if not using mutex is ok
        self._last_frame_update = self.context.viewport.frame_count
        if changed:
            self._last_frame_change = self.context.viewport.frame_count

    cdef void inc_num_attached(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self._num_attached += 1

    cdef void dec_num_attached(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self._num_attached -= 1


"""
UI input event handlers
"""

cdef class baseHandler(baseItem):
    """
    Base class for UI input event handlers.

    Attributes:
    - enabled: Boolean indicating if the handler is enabled.
    - callback: Callback function for the handler.
    """
    def __cinit__(self):
        self._enabled = True
        self.can_have_sibling = True
        self.element_child_category = child_type.cat_handler
    @property
    def enabled(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._enabled
    @enabled.setter
    def enabled(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._enabled = value
    # for backward compatibility
    @property
    def show(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._enabled
    @show.setter
    def show(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._enabled = value

    @property
    def callback(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._callback
    @callback.setter
    def callback(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._callback = value if isinstance(value, Callback) or value is None else Callback(value)

    cdef void check_bind(self, baseItem item):
        """
        Must raise en error if the handler cannot be bound for the
        target item.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return

    cdef bint check_state(self, baseItem item) noexcept nogil:
        """
        Returns whether the target state it True.
        Is called by the default implementation of run_handler,
        which will call the default callback in this case.
        Classes that might issue non-standard callbacks should
        override run_handler in addition to check_state.
        """
        return False

    cdef void run_handler(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        if not(self._enabled):
            return
        if self.check_state(item):
            self.run_callback(item)

    cdef void run_callback(self, baseItem item) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        self.context.queue_callback_arg1obj(self._callback, self, item, item)


cdef class uiItem(baseItem):
    """Base class for UI items with various properties and states.

    Core class for items that can be interacted with and displayed in the UI. Handles positioning,
    state tracking, themes, callbacks, and layout management.

    State Properties:
    ---------------
    - active: Whether the item is currently active (pressed, selected, etc.)
    - activated: Whether the item just became active this frame  
    - clicked: Whether any mouse button was clicked on the item
    - double_clicked: Whether any mouse button was double-clicked
    - deactivated: Whether the item just became inactive
    - deactivated_after_edited: Whether the item was edited and then deactivated
    - edited: Whether the item's value was modified
    - focused: Whether the item has keyboard focus
    - hovered: Whether the mouse is over the item
    - resized: Whether the item's size changed
    - toggled: Whether a menu/tree node was opened/closed
    - visible: Whether the item is currently rendered

    Appearance Properties:
    -------------------
    - enabled: Whether the item is interactive or greyed out
    - font: Font used for text rendering
    - theme: Visual theme/style settings
    - show: Whether the item should be drawn
    - no_scaling: Disable DPI/viewport scaling
    
    Layout Properties:
    ----------------
    - pos_to_viewport: Position relative to viewport top-left
    - pos_to_window: Position relative to containing window 
    - pos_to_parent: Position relative to parent item
    - pos_to_default: Position relative to default layout flow
    - rect_size: Current size in pixels including padding
    - content_region_avail: Available content area within item for children
    - pos_policy: How the item should be positioned
    - height/width: Requested size of the item
    - indent: Left indentation amount
    - no_newline: Don't advance position after item

    Value Properties:
    ---------------
    - value: Main value stored by the item 
    - shareable_value: Allows sharing values between items
    - label: Text label shown with the item

    Event Properties:  
    ---------------
    - handlers: Event handlers attached to the item
    - callbacks: Functions called when value changes

    Positioning Rules:
    ----------------
    Items use a combination of absolute and relative positioning:
    - Default flow places items vertically with automatic width
    - pos_policy controls how position attributes are enforced
    - Positions can be relative to viewport, window, parent or flow
    - Size can be fixed, automatic, or stretch to fill space
    - indent and no_newline provide fine-grained layout control

    All attributes are protected by mutexes to enable thread-safe access.
    """
    def __cinit__(self):
        # mvAppItemInfo
        self._imgui_label = b'###%ld'% self.uuid
        self._user_label = ""
        self._show = True
        self._enabled = True
        self.can_be_disabled = True
        #self.location = -1
        # next frame triggers
        self._focus_update_requested = False
        self._show_update_requested = True
        self.size_update_requested = True
        self.pos_update_requested = False
        self._enabled_update_requested = False
        # mvAppItemConfig
        #self.filter = b""
        #self.alias = b""
        self.requested_size = make_Vec2(0., 0.)
        self._dpi_scaling = True
        self._indent = 0.
        self._theme_condition_enabled = ThemeEnablers.ENABLED
        self._theme_condition_category = ThemeCategories.t_any
        self.can_have_sibling = True
        self.element_child_category = child_type.cat_widget
        self.state.cap.has_position = True # ALL widgets have position
        self.state.cap.has_rect_size = True # ALL items have a rectangle size
        self.p_state = &self.state
        self.pos_policy = [Positioning.DEFAULT, Positioning.DEFAULT]
        #self.size_policy = [Sizing.AUTO, Sizing.AUTO]
        self._scaling_factor = 1.0
        #self.trackOffset = 0.5 # 0.0f:top, 0.5f:center, 1.0f:bottom
        #self.tracked = False
        self._dragCallback = None
        self._dropCallback = None
        self._value = SharedValue(self.context) # To be changed by class

    def __dealloc__(self):
        clear_obj_vector(self._callbacks)

    def configure(self, **kwargs):
        # Map old attribute names (the new names are handled in uiItem)
        if 'pos' in kwargs:
            pos = kwargs.pop("pos")
            if pos is not None and len(pos) == 2:
                self.pos_to_window = pos
                self.state.cur.pos_to_viewport = self.state.cur.pos_to_window # for windows TODO move to own configure
        if 'callback' in kwargs:
            self.callbacks = kwargs.pop("callback")
        return super().configure(**kwargs)

    cdef void update_current_state(self) noexcept nogil:
        """
        Helper to update the state of the last imgui object.
        Are updated:
        - hovered state
        - active state
        - clicked state and related (dragging, etc)
        - deactivated after edit, though unsure if actually used
        - edited state
        - focused state
        - rect size
        - sets rendered to ItemIsVisible, which is not 100% reliable (
            will return True if visible and rendered, but might miss
            rendered and not visible).
        """
        if self.state.cap.can_be_hovered:
            self.state.cur.hovered = imgui.IsItemHovered(imgui.ImGuiHoveredFlags_AllowWhenDisabled)
        if self.state.cap.can_be_active:
            self.state.cur.active = imgui.IsItemActive()
        if self.state.cap.can_be_clicked or self.state.cap.can_be_dragged:
            update_current_mouse_states(self.state)
        if self.state.cap.can_be_deactivated_after_edited:
            self.state.cur.deactivated_after_edited = imgui.IsItemDeactivatedAfterEdit()
        if self.state.cap.can_be_edited:
            self.state.cur.edited = imgui.IsItemEdited()
        if self.state.cap.can_be_focused:
            self.state.cur.focused = imgui.IsItemFocused()
        # Commented because all widgets with can_be_toggled handle
        # the open state themselves (because see comment below)
        #if self.state.cap.can_be_toggled:
        #    if imgui.IsItemToggledOpen(): # Wrong because it only hits True when open moves from False to True
        #        self.state.cur.open = True
        if self.state.cap.has_rect_size:
            self.state.cur.rect_size = ImVec2Vec2(imgui.GetItemRectSize())
        self.state.cur.rendered = imgui.IsItemVisible()
        #if not(self.state.cur.rendered):
        #    self.propagate_hidden_state_to_children_with_handlers()

    cdef void update_current_state_subset(self) noexcept nogil:
        """
        Helper for items that manage themselves a part of the states.
        Are updated:
        - hovered state
        - focused state
        - clicked state and related (dragging, etc)
        - rect size
        - sets rendered to ItemIsVisible, which is not 100% reliable (
            will return True if visible and rendered, but might miss
            rendered and not visible).
        """
        if self.state.cap.can_be_hovered:
            self.state.cur.hovered = imgui.IsItemHovered(imgui.ImGuiHoveredFlags_None)
        if self.state.cap.can_be_focused:
            self.state.cur.focused = imgui.IsItemFocused()
        if self.state.cap.can_be_clicked or self.state.cap.can_be_dragged:
            update_current_mouse_states(self.state)
        if self.state.cap.has_rect_size:
            self.state.cur.rect_size = ImVec2Vec2(imgui.GetItemRectSize())
        self.state.cur.rendered = imgui.IsItemVisible()
        #if not(self.state.cur.rendered):
        #    self.propagate_hidden_state_to_children_with_handlers()

    # TODO: Find a better way to share all these attributes while avoiding AttributeError
    def __dir__(self):
        default_dir = dir(type(self))
        if hasattr(self, '__dict__'): # Can happen with python subclassing
            default_dir + list(self.__dict__.keys())
        # Remove invalid ones
        results = []
        for e in default_dir:
            if hasattr(self, e):
                results.append(e)
        return list(set(results))

    @property
    def active(self):
        """
        Readonly attribute: is the item active.
        For example for a button, it is when pressed. For tabs
        it is when selected, etc.
        """
        if not(self.state.cap.can_be_active):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.active

    @property
    def activated(self):
        """
        Readonly attribute: has the item just turned active
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.cap.can_be_active):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.active and not(self.state.prev.active)

    @property
    def clicked(self):
        """
        Readonly attribute: has the item just been clicked.
        The returned value is a tuple of len 5 containing the individual test
        mouse buttons (up to 5 buttons)
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.cap.can_be_clicked):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
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
        if not(self.state.cap.can_be_clicked):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.double_clicked

    @property
    def deactivated(self):
        """
        Readonly attribute: has the item just turned un-active
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.cap.can_be_active):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return not(self.state.cur.active) and self.state.prev.active

    @property
    def deactivated_after_edited(self):
        """
        Readonly attribute: has the item just turned un-active after having
        been edited.
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.cap.can_be_deactivated_after_edited):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.deactivated_after_edited

    @property
    def edited(self):
        """
        Readonly attribute: has the item just been edited ?
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.cap.can_be_edited):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.edited

    @property
    def focused(self):
        """
        Writable attribute: Is the item focused ?
        For windows it means the window is at the top,
        while for items it could mean the keyboard inputs are redirected to it.
        """
        if not(self.state.cap.can_be_focused):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.focused

    @focused.setter
    def focused(self, bint value):
        """
        Writable attribute: Is the item focused ?
        For windows it means the window is at the top,
        while for items it could mean the keyboard inputs are redirected to it.
        """
        if not(self.state.cap.can_be_focused):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.state.cur.focused = value
        self._focus_update_requested = True

    @property
    def hovered(self):
        """
        Readonly attribute: Is the mouse inside the region of the item.
        Only one element is hovered at a time, thus
        subitems/subwindows take priority over their parent.
        """
        if not(self.state.cap.can_be_hovered):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.hovered

    @property
    def resized(self):
        """
        Readonly attribute: has the item size just changed
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.cap.has_rect_size):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.rect_size.x != self.state.prev.rect_size.x or \
               self.state.cur.rect_size.y != self.state.prev.rect_size.y

    @property
    def toggled(self):
        """
        Has a menu/bar trigger been hit for the item
        If True, the attribute is reset the next frame. It's better to rely
        on handlers to catch this event.
        """
        if not(self.state.cap.can_be_toggled):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.open and not(self.state.prev.open)

    @property
    def visible(self):
        """
        True if the item was rendered (inside the rendering region + show = True
        for the item and its ancestors). Note when an item is not visible,
        rendering is skipped (as well as running their handlers, etc).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.state.cur.rendered

    @property
    def callbacks(self):
        """
        Writable attribute: callback object or list of callback objects
        which is called when the value of the item is changed.
        If read, always returns a list of callbacks. This enables
        to do item.callbacks += [new_callback]
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int32_t i
        cdef Callback callback
        for i in range(<int>self._callbacks.size()):
            callback = <Callback>self._callbacks[i]
            result.append(callback)
        return result

    @callbacks.setter
    def callbacks(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list items = []
        cdef int32_t i
        if value is None:
            clear_obj_vector(self._callbacks)
            return
        if not hasattr(value, "__len__"):
            value = [value]
        # Convert to callbacks
        for i in range(len(value)):
            items.append(value[i] if isinstance(value[i], Callback) else Callback(value[i]))
        clear_obj_vector(self._callbacks)
        append_obj_vector(self._callbacks, items)

    @property
    def enabled(self):
        """
        Writable attribute: Should the object be displayed as enabled ?
        the enabled state can be used to prevent edition of editable fields,
        or to use a specific disabled element theme.
        Note a disabled item is still rendered. Use show=False to hide
        an object.
        A disabled item does not react to hovering or clicking.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._enabled

    @enabled.setter
    def enabled(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(self.can_be_disabled) and value != True:
            raise AttributeError(f"Objects of type {type(self)} cannot be disabled")
        self._theme_condition_enabled = ThemeEnablers.ENABLED if value else ThemeEnablers.DISABLED
        self._enabled_update_requested = True
        self._enabled = value

    @property
    def font(self):
        """
        Writable attribute: font used for the text rendered
        of this item and its subitems
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._font

    @font.setter
    def font(self, baseFont value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._font = value

    @property
    def label(self):
        """
        Writable attribute: label assigned to the item.
        Used for text fields, window titles, etc
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._user_label

    @label.setter
    def label(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._user_label = ""
        else:
            self._user_label = value
        # Using ### means that imgui will ignore the user_label for
        # its internal ID of the object. Indeed else the ID would change
        # when the user label would change
        self._imgui_label = bytes(self._user_label, 'utf-8') + b'###%ld'% self.uuid

    @property
    def value(self):
        """
        Writable attribute: main internal value for the object.
        For buttons, it is set when pressed; For text it is the
        text itself; For selectable whether it is selected, etc.
        Reading the value attribute returns a copy, while writing
        to the value attribute will edit the field of the value.
        In case the value is shared among items, setting the value
        attribute will change it for all the sharing items.
        To share a value attribute among objects, one should use
        the shareable_value attribute
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._value.value

    @value.setter
    def value(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._value.value = value

    @property
    def shareable_value(self):
        """
        Same as the value field, but rather than a copy of the internal value
        of the object, return a python object that holds a value field that
        is in sync with the internal value of the object. This python object
        can be passed to other items using an internal value of the same
        type to share it.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._value

    @shareable_value.setter
    def shareable_value(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._value is value:
            return
        if type(self._value) is not type(value):
            raise ValueError(f"Expected a shareable value of type {type(self._value)}. Received {type(value)}")
        self._value.dec_num_attached()
        self._value = value
        self._value.inc_num_attached()

    @property
    def show(self):
        """
        Writable attribute: Should the object be drawn/shown ?
        In case show is set to False, this disables any
        callback (for example the close callback won't be called
        if a window is hidden with show = False).
        In the case of items that can be closed,
        show is set to False automatically on close.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return <bint>self._show

    @show.setter
    def show(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if self._show == value:
            return
        if not(value) and self._show:
            self.set_hidden_and_propagate_to_children_no_handlers() # TODO: already handled in draw() ?
        self._show_update_requested = True
        self._show = value

    @property
    def handlers(self):
        """
        Writable attribute: bound handlers for the item.
        If read returns a list of handlers. Accept
        a handler or a list of handlers as input.
        This enables to do item.handlers += [new_handler].
        """
        cdef unique_lock[recursive_mutex] m
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
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list items = []
        cdef int32_t i
        if value is None:
            clear_obj_vector(self._handlers)
            return
        if not hasattr(value, "__len__"):
            value = [value]
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
    def theme(self):
        """
        Writable attribute: bound theme for the item
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._theme

    @theme.setter
    def theme(self, baseTheme value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._theme = value

    @property
    def no_scaling(self):
        """
        boolean. Defaults to False.
        By default, the requested width and
        height are multiplied internally by the global
        scale which is defined by the dpi and the
        viewport/window scale.
        If set, disables this automated scaling.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return not(self._dpi_scaling)

    @no_scaling.setter
    def no_scaling(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._dpi_scaling = not(value)

    @property 
    def scaling_factor(self):
        """
        Writable attribute: scaling factor
        that multiplies the global viewport scaling and
        applies to this item and its children.
        The global scaling (thus this parameter as well)
        impacts themes, sizes and fonts. Themes and fonts
        that were applied by a parent are unaffected.
        Defaults to 1.0.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._scaling_factor

    @scaling_factor.setter
    def scaling_factor(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._scaling_factor = value

    ### Positioning - layouts

    ### Current position states

    @property
    def pos_to_viewport(self):
        """
        Writable attribute:
        Current screen-space position of the top left
        of the item's rectangle. Basically the coordinate relative
        to the top left of the viewport.

        User writing this attribute automatically switches
        the positioning mode to REL_VIEWPORT position.

        Note that item is still clipped from the parent's clipping
        region, and thus the item will not be visible if placed
        outside.

        Setting None to one of component will ignore the update
        of this component.
        For example item.pos_to_viewport = (x, None) will only
        set the horizontal component of the pos_to_viewport position,
        and update the positioning policy for this component
        only.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build_v(self.state.cur.pos_to_viewport)

    @property
    def pos_to_window(self):
        """
        Writable attribute:
        Relative position to the window's starting inner
        content area.

        The position corresponds to the top left of the item's
        rectangle

        User writing this attribute automatically switches
        the positioning policy to relative position to the
        window.

        Note that the position may place the item outside the
        parent's content region, in which case the item is not
        visible.

        Setting None to one of component will ignore the update
        of this component.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build_v(self.state.cur.pos_to_window)

    @property
    def pos_to_parent(self):
        """
        Writable attribute:
        Relative position to the parent's position, or to
        its starting inner content area if any.

        The position corresponds to the top left of the item's
        rectangle

        User writing this attribute automatically switches
        the positioning policy to relative position to the
        parent.

        Note that the position may place the item outside the
        parent's content region, in which case the item is not
        visible.

        Setting None to one of component will ignore the update
        of this component.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build_v(self.state.cur.pos_to_parent)

    @property
    def pos_to_default(self):
        """
        Writable attribute:
        Relative position to the item's default position.

        User set attribute to offset the object relative to
        the position it would be drawn by default given the other
        items drawn. The position corresponds to the top left of
        the item's rectangle.

        User writing this attribute automatically switches the 
        positioning policy to relative to the default position.

        Setting None to one of component will ignore the update
        of this component.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build_v(self.state.cur.pos_to_default)

    @property
    def rect_size(self):
        """
        Readonly attribute: actual (width, height) of the element,
        including margins.

        The space taken by the item corresponds to a rectangle
        of size rect_size with top left coordinate
        the position given by the position fields.

        Not the rect_size refers to the size within the parent
        window. If a popup menu is opened, it is not included.
        """
        if not(self.state.cap.has_rect_size):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build_v(self.state.cur.rect_size)

    @property
    def content_region_avail(self):
        """
        Readonly attribute: For windows, child windows,
        table cells, etc: Available region.

        Only defined for elements that contain other items.
        Corresponds to the size inside the item to display
        other items (regions not shown which can
        be scrolled are not accounted). Basically the item size
        minus the margins and borders.
        """
        if not(self.state.cap.has_content_region):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build_v(self.state.cur.content_region_size)

    @property
    def content_pos(self):
        """
        Readable attribute indicating the top left starting
        position of the item's content in viewport coordinates.

        Only available for items with a content area.
        The size of the content area is available with
        content_region_avail.
        """
        if not(self.state.cap.has_content_region):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build_v(self._content_pos)

    ### Positioning and size requests

    @property
    def pos_policy(self):
        """
        Writable attribute: Positioning policy

        Changing the policy enables the user to
        change the position of the item relative to
        its default position.

        - DEFAULT: The item is drawn at the position
          given by ImGUI's cursor position, which by
          default is incremented vertically after each item is
          rendered.
        - REL_DEFAULT: The item is drawn at the same position
          as default, but after adding as offset the value
          contained in the pos_to_default field.
        - REL_PARENT: The item is rendered at the position
          contained in the pos_to_parent's field,
          which is respective to the top left of the content
          area of the parent.
        - REL_WINDOW: The item is rendered at the position
          contained in the pos_to_window's field,
          which is respective to the top left of the containing
          window or child window content area.
        - REL_VIEWPORT: The item is rendered in viewport
          coordinates, at the position pos_to_viewport.

        Items rendered with the DEFAULT or REL_DEFAULT policy do
        increment the cursor position, while REL_PARENT, REL_WINDOW
        and REL_VIEWPORT do not.

        Each axis has it's own positioning policy.
        pos_policy = DEFAULT will update both policies, while
        pos_policy = (None, DEFAULT) will only update the vertical
        axis policy.

        Regardless of the policy, all position fields are updated
        when the item is rendered. Only the position corresponding to
        the positioning policy can be expected to remain fixed, with no
        strong guarantees.

        Since some items react dynamically to the size of their contents,
        while items react dynamically to the size of their parent, a few
        frames may be needed for positions to stabilize.
        """
        return (make_Positioning(self.pos_policy[0]), make_Positioning(self.pos_policy[1]))

    @property
    def height(self):
        """
        Writable attribute: Requested height of the item.
        When it is written, it is set to a 'requested value' that is not
        entirely guaranteed to be enforced.
        Specific values:
            . 0 is meant to define the default size. For some items,
              such as windows, it triggers a fit to the content size.
              For other items, there is a default size deduced from the
              style policy. And for some items (such as child windows),
              it triggers a fit to the full size available within the
              parent window.
            . > 0 values is meant as a hint for rect_size.
            . < 0 values to be interpreted as 'take remaining space
              of the parent's content region from the current position,
              and subtract this value'. For example -1 will stretch to the
              remaining area minus one pixel.

        Note that for some items, the actual rect_size of the element cannot
        be changed to the requested values (for example Text). In that case, the
        item is not resized, but it behaves as if it has the requested size in terms
        of impact on the layout (default position of other items).

        In addition the real height may change if the object is resizable.
        In this case, the height may be changed back by setting again the value
        of this field.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.requested_size.y

    @property
    def width(self):
        """
        Writable attribute: Requested width of the item.
        When it is written, it is set to a 'requested value' that is not
        entirely guaranteed to be enforced.
        Specific values:
            . 0 is meant to define the default size. For some items,
              such as windows, it triggers a fit to the content size.
              For other items, there is a default size deduced from the
              style policy. And for some items (such as child windows),
              it triggers a fit to the full size available within the
              parent window.
            . > 0 values is meant as a hint for rect_size.
            . < 0 values to be interpreted as 'take remaining space
              of the parent's content region from the current position,
              and subtract this value'. For example -1 will stretch to the
              remaining area minus one pixel.

        Note that for some items, the actual rect_size of the element cannot
        be changed to the requested values (for example Text). In that case, the
        item is not resized, but it behaves as if it has the requested size in terms
        of impact on the layout (default position of other items).

        In addition the real width may change if the object is resizable.
        In this case, the width may be changed back by setting again the value
        of this field.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.requested_size.x

    @property
    def indent(self):
        """
        Writable attribute: Shifts horizontally the DEFAULT
        position of the item by the requested amount of pixels.

        A value < 0 indicates an indentation of the default size
        according to the style policy.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._indent

    @property
    def no_newline(self):
        """
        Writable attribute: Disables moving the
        cursor (DEFAULT position) by one line
        after this item.

        Might be modified by the layout
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.no_newline

    ## setters

    @pos_to_viewport.setter
    def pos_to_viewport(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if len(value) != 2:
            raise ValueError("Expected tuple for pos: (x, y)")
        (x, y) = value
        if x is not None:
            self.state.cur.pos_to_viewport.x = x
            self.pos_policy[0] = Positioning.REL_VIEWPORT
        if y is not None:
            self.state.cur.pos_to_viewport.y = y
            self.pos_policy[1] = Positioning.REL_VIEWPORT
        self.pos_update_requested = True # TODO remove ?

    @pos_to_window.setter
    def pos_to_window(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if len(value) != 2:
            raise ValueError("Expected tuple for pos: (x, y)")
        (x, y) = value
        if x is not None:
            self.state.cur.pos_to_window.x = x
            self.pos_policy[0] = Positioning.REL_WINDOW
        if y is not None:
            self.state.cur.pos_to_window.y = y
            self.pos_policy[1] = Positioning.REL_WINDOW
        self.pos_update_requested = True

    @pos_to_parent.setter
    def pos_to_parent(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if len(value) != 2:
            raise ValueError("Expected tuple for pos: (x, y)")
        (x, y) = value
        if x is not None:
            self.state.cur.pos_to_parent.x = x
            self.pos_policy[0] = Positioning.REL_PARENT
        if y is not None:
            self.state.cur.pos_to_parent.y = y
            self.pos_policy[1] = Positioning.REL_PARENT
        self.pos_update_requested = True

    @pos_to_default.setter
    def pos_to_default(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if len(value) != 2:
            raise ValueError("Expected tuple for pos: (x, y)")
        (x, y) = value
        if x is not None:
            self.state.cur.pos_to_default.x = x
            self.pos_policy[0] = Positioning.REL_DEFAULT
        if y is not None:
            self.state.cur.pos_to_default.y = y
            self.pos_policy[1] = Positioning.REL_DEFAULT
        self.pos_update_requested = True

    @pos_policy.setter
    def pos_policy(self, value):
        if hasattr(value, "__len__"):
            (x, y) = value
            self.pos_policy[0] = check_Positioning(x)
            self.pos_policy[1] = check_Positioning(y)
            self.pos_update_requested = True
        else:
            self.pos_policy[0] = check_Positioning(value)
            self.pos_policy[1] = check_Positioning(value)
            self.pos_update_requested = True

    @height.setter
    def height(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.requested_size.y = value
        self.size_update_requested = True

    @width.setter
    def width(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.requested_size.x = value
        self.size_update_requested = True

    @indent.setter
    def indent(self, float value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._indent = value

    @no_newline.setter
    def no_newline(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.no_newline = value

    @cython.final
    cdef Vec2 scaled_requested_size(self) noexcept nogil:
        cdef Vec2 requested_size = self.requested_size
        cdef float global_scale = self.context.viewport.global_scale
        if not(self._dpi_scaling):
            global_scale = 1.
        if requested_size.x > 0 and requested_size.x < 1.:
            requested_size.x = floor(self.context.viewport.parent_size.x * self.requested_size.x)
        else:
            requested_size.x *= global_scale
        if requested_size.y > 0 and requested_size.y < 1.:
            requested_size.y = floor(self.context.viewport.parent_size.y * self.requested_size.y)
        else:
            requested_size.y *= global_scale
        return requested_size

    cdef void draw(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)

        if not(self._show):
            if self._show_update_requested:
                self.set_previous_states()
                self.set_hidden_no_handler_and_propagate_to_children_with_handlers()
                self.run_handlers()
                self._show_update_requested = False
            return

        cdef float original_scale = self.context.viewport.global_scale
        self.context.viewport.global_scale = original_scale * self._scaling_factor

        self.set_previous_states()

        if self._focus_update_requested:
            if self.state.cur.focused:
                imgui.SetKeyboardFocusHere(0)
            self._focus_update_requested = False

        # Does not affect all items, but is cheap to set
        if self.requested_size.x != 0:
            imgui.SetNextItemWidth(self.requested_size.x * \
                                       (self.context.viewport.global_scale if self._dpi_scaling else 1.))

        cdef float indent = self._indent
        if indent > 0.:
            imgui.Indent(indent)
        # We use 0 to mean no indentation,
        # while imgui uses 0 for default indentation
        elif indent < 0:
            imgui.Indent(0)

        cdef Vec2 cursor_pos_backup = ImVec2Vec2(imgui.GetCursorScreenPos())

        cdef Positioning[2] policy = self.pos_policy
        cdef Vec2 pos = cursor_pos_backup

        if policy[0] == Positioning.REL_DEFAULT:
            pos.x += self.state.cur.pos_to_default.x
        elif policy[0] == Positioning.REL_PARENT:
            pos.x = self.context.viewport.parent_pos.x + self.state.cur.pos_to_parent.x
        elif policy[0] == Positioning.REL_WINDOW:
            pos.x = self.context.viewport.window_pos.x + self.state.cur.pos_to_window.x
        elif policy[0] == Positioning.REL_VIEWPORT:
            pos.x = self.state.cur.pos_to_viewport.x
        # else: DEFAULT

        if policy[1] == Positioning.REL_DEFAULT:
            pos.y += self.state.cur.pos_to_default.y
        elif policy[1] == Positioning.REL_PARENT:
            pos.y = self.context.viewport.parent_pos.y + self.state.cur.pos_to_parent.y
        elif policy[1] == Positioning.REL_WINDOW:
            pos.y = self.context.viewport.window_pos.y + self.state.cur.pos_to_window.y
        elif policy[1] == Positioning.REL_VIEWPORT:
            pos.y = self.state.cur.pos_to_viewport.y
        # else: DEFAULT

        imgui.SetCursorScreenPos(Vec2ImVec2(pos))

        # Retrieve current positions
        self.state.cur.pos_to_viewport = ImVec2Vec2(imgui.GetCursorScreenPos())
        self.state.cur.pos_to_window.x = self.state.cur.pos_to_viewport.x - self.context.viewport.window_pos.x
        self.state.cur.pos_to_window.y = self.state.cur.pos_to_viewport.y - self.context.viewport.window_pos.y
        self.state.cur.pos_to_parent.x = self.state.cur.pos_to_viewport.x - self.context.viewport.parent_pos.x
        self.state.cur.pos_to_parent.y = self.state.cur.pos_to_viewport.y - self.context.viewport.parent_pos.y
        self.state.cur.pos_to_default.x = self.state.cur.pos_to_viewport.x - cursor_pos_backup.x
        self.state.cur.pos_to_default.y = self.state.cur.pos_to_viewport.y - cursor_pos_backup.y

        # handle fonts
        if self._font is not None:
            self._font.push()

        # themes
        self.context.viewport.push_pending_theme_actions(
            self._theme_condition_enabled,
            self._theme_condition_category
        )
        if self._theme is not None:
            self._theme.push()

        cdef bint enabled = self._enabled
        if not(enabled):
            imgui.PushItemFlag(1 << 10, True) #ImGuiItemFlags_Disabled

        cdef bint action = self.draw_item()
        cdef int32_t i
        if action and not(self._callbacks.empty()):
            for i in range(<int>self._callbacks.size()):
                self.context.queue_callback_arg1value(<Callback>self._callbacks[i], self, self, self._value)

        if not(enabled):
            imgui.PopItemFlag()

        if self._theme is not None:
            self._theme.pop()
        self.context.viewport.pop_applied_pending_theme_actions()

        if self._font is not None:
            self._font.pop()

        # Restore original scale
        self.context.viewport.global_scale = original_scale 

        # Advance the cursor only for DEFAULT and REL_DEFAULT
        pos = cursor_pos_backup
        if policy[0] == Positioning.REL_DEFAULT or \
           policy[0] == Positioning.DEFAULT:
            pos.x = imgui.GetCursorScreenPos().x

        if policy[1] == Positioning.REL_DEFAULT or \
           policy[1] == Positioning.DEFAULT:
            pos.y = imgui.GetCursorScreenPos().y

        imgui.SetCursorScreenPos(Vec2ImVec2(pos))

        if indent > 0.:
            imgui.Unindent(indent)
        elif indent < 0:
            imgui.Unindent(0)

        # Note: not affected by the Unindent.
        if self.no_newline and \
           (policy[1] == Positioning.REL_DEFAULT or \
            policy[1] == Positioning.DEFAULT):
            imgui.SameLine(0., -1.)

        self.run_handlers()


    cdef bint draw_item(self) noexcept nogil:
        """
        Function to override for the core rendering of the item.
        What is already handled outside draw_item (see draw()):
        . The mutex is held (as is the mutex of the following siblings,
          and the mutex of the parents, including the viewport and imgui
          mutexes)
        . The previous siblings are already rendered
        . Current themes, fonts
        . Widget starting position (GetCursorPos to get it)
        . Focus

        What remains to be done by draw_item:
        . Rendering the item. Set its width, its height, etc
        . Calling update_current_state or manage itself the state
        . Render children if any

        The return value indicates if the main callback should be triggered.
        """
        return False

"""
Complex ui items
"""


cdef class TimeWatcher(uiItem):
    """
    A placeholder uiItem parent that doesn't draw or have any impact on rendering.
    This item calls the callback with times in ns.
    These times can be compared with the times in the metrics
    that can be obtained from the viewport in order to
    precisely figure out the time spent rendering specific items.

    The first time corresponds to the time this item is called
    for rendering

    The second time corresponds to the time after the
    children have finished rendering.

    The third time corresponds to the time when viewport
    started rendering items for this frame. It is
    given to prevent the user from having to keep track of the
    viewport metrics (since the callback might be called
    after or before the viewport updated its metrics for this
    frame or another one).

    The fourth number corresponds to the frame count
    at the the time the callback was issued.

    Note the times relate to CPU time (checking states, preparing
    GPU data, etc), not to GPU rendering time.
    """
    def __cinit__(self):
        self.state.cap.has_position = False
        self.state.cap.has_rect_size = False
        self.can_be_disabled = False
        self.can_have_widget_child = True

    cdef void draw(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        cdef long long time_start = ctime.monotonic_ns()
        draw_ui_children(self)
        cdef long long time_end = ctime.monotonic_ns()
        cdef int32_t i
        if not(self._callbacks.empty()):
            for i in range(<int>self._callbacks.size()):
                self.context.queue_callback_arg3long1int(<Callback>self._callbacks[i],
                                                         self,
                                                         self,
                                                         time_start,
                                                         time_end,
                                                         self.context.viewport.last_t_before_rendering,
                                                         self.context.viewport.frame_count)
        

cdef class Window(uiItem):
    """
    Represents a window in the UI with various configurable properties.

    Attributes:
    - no_title_bar: Boolean indicating if the title bar should be hidden.
    - no_resize: Boolean indicating if resizing should be disabled.
    - no_move: Boolean indicating if moving should be disabled.
    - no_scrollbar: Boolean indicating if the scrollbar should be hidden.
    - no_scroll_with_mouse: Boolean indicating if scrolling with the mouse should be disabled.
    - no_collapse: Boolean indicating if collapsing should be disabled.
    - autosize: Boolean indicating if the window should autosize.
    - no_background: Boolean indicating if the background should be hidden.
    - no_saved_settings: Boolean indicating if saved settings should be disabled.
    - no_mouse_inputs: Boolean indicating if mouse inputs should be disabled.
    - no_keyboard_inputs: Boolean indicating if keyboard inputs should be disabled.
    - menubar: Boolean indicating if the menubar should be shown.
    - horizontal_scrollbar: Boolean indicating if the horizontal scrollbar should be shown.
    - no_focus_on_appearing: Boolean indicating if focus on appearing should be disabled.
    - no_bring_to_front_on_focus: Boolean indicating if bringing to front on focus should be disabled.
    - always_show_vertical_scrollvar: Boolean indicating if the vertical scrollbar should always be shown.
    - always_show_horizontal_scrollvar: Boolean indicating if the horizontal scrollbar should always be shown.
    - unsaved_document: Boolean indicating if the document is unsaved.
    - disallow_docking: Boolean indicating if docking should be disallowed.
    - no_open_over_existing_popup: Boolean indicating if opening over existing popup should be disabled.
    - modal: Boolean indicating if the window is modal.
    - popup: Boolean indicating if the window is a popup.
    - has_close_button: Boolean indicating if the close button should be shown.
    - collapsed: Boolean indicating if the window is collapsed.
    - on_close: Callback function for the close event.
    - primary: Boolean indicating if the window is primary.
    - min_size: Minimum size of the window.
    - max_size: Maximum size of the window.
    """
    def __cinit__(self):
        self._window_flags = imgui.ImGuiWindowFlags_None
        self._main_window = False
        self._modal = False
        self._popup = False
        self._has_close_button = True
        self.state.cur.open = True
        self._collapse_update_requested = False
        self._no_open_over_existing_popup = True
        self._on_close_callback = None
        self._min_size = make_Vec2(100., 100.)
        self._max_size = make_Vec2(30000., 30000.)
        self._theme_condition_category = ThemeCategories.t_window
        # Default is the viewport for windows
        self.pos_policy[0] = Positioning.REL_VIEWPORT
        self.pos_policy[1] = Positioning.REL_VIEWPORT
        self._scroll_x = 0. # TODO
        self._scroll_y = 0.
        self._scroll_x_update_requested = False
        self._scroll_y_update_requested = False
        # Read-only states
        self._scroll_max_x = 0.
        self._scroll_max_y = 0.

        # backup states when we set/unset primary
        #self._backup_window_flags = imgui.ImGuiWindowFlags_None
        #self._backup_pos = self._position
        #self._backup_rect_size = self.state.cur.rect_size
        # Type info
        self.can_have_widget_child = True
        #self._can_have_drawing_child = True
        self.can_have_menubar_child = True
        self.element_child_category = child_type.cat_window
        self.state.cap.can_be_hovered = True
        self.state.cap.can_be_focused = True
        self.state.cap.has_content_region = True

    @property
    def no_title_bar(self):
        """Writable attribute to disable the title-bar"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoTitleBar) else False

    @no_title_bar.setter
    def no_title_bar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoTitleBar
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoTitleBar

    @property
    def no_resize(self):
        """Writable attribute to block resizing"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoResize) else False

    @no_resize.setter
    def no_resize(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoResize
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoResize

    @property
    def no_move(self):
        """Writable attribute the window to be move with interactions"""
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoMove) else False

    @no_move.setter
    def no_move(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoMove
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoMove

    @property
    def no_scrollbar(self):
        """Writable attribute to indicate the window should have no scrollbar
           Does not disable scrolling via mouse or keyboard
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoScrollbar) else False

    @no_scrollbar.setter
    def no_scrollbar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoScrollbar
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoScrollbar
    
    @property
    def no_scroll_with_mouse(self):
        """Writable attribute to indicate the mouse wheel
           should have no effect on scrolling of this window
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoScrollWithMouse) else False

    @no_scroll_with_mouse.setter
    def no_scroll_with_mouse(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoScrollWithMouse
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoScrollWithMouse

    @property
    def no_collapse(self):
        """Writable attribute to disable user collapsing window by double-clicking on it
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoCollapse) else False

    @no_collapse.setter
    def no_collapse(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoCollapse
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoCollapse

    @property
    def autosize(self):
        """Writable attribute to tell the window should
           automatically resize to fit its content
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_AlwaysAutoResize) else False

    @autosize.setter
    def autosize(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_AlwaysAutoResize
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_AlwaysAutoResize

    @property
    def no_background(self):
        """
        Writable attribute to disable drawing background
        color and outside border
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoBackground) else False

    @no_background.setter
    def no_background(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoBackground
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoBackground

    @property
    def no_saved_settings(self):
        """
        Writable attribute to never load/save settings in .ini file
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoSavedSettings) else False

    @no_saved_settings.setter
    def no_saved_settings(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoSavedSettings
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoSavedSettings

    @property
    def no_mouse_inputs(self):
        """
        Writable attribute to disable mouse input event catching of the window.
        Events such as clicked, hovering, etc will be passed to items behind the
        window.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoMouseInputs) else False

    @no_mouse_inputs.setter
    def no_mouse_inputs(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoMouseInputs
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoMouseInputs

    @property
    def no_keyboard_inputs(self):
        """
        Writable attribute to disable keyboard manipulation (scroll).
        The window will not take focus of the keyboard.
        Does not affect items inside the window.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoNav) else False

    @no_keyboard_inputs.setter
    def no_keyboard_inputs(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoNav
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoNav

    @property
    def menubar(self):
        """
        Writable attribute to indicate whether the window has a menu bar.

        There will be menubar if either the user has asked for it,
        or there is a menubar child.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.last_menubar_child is not None) or (self._window_flags & imgui.ImGuiWindowFlags_MenuBar) != 0

    @menubar.setter
    def menubar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_MenuBar
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_MenuBar

    @property
    def horizontal_scrollbar(self):
        """
        Writable attribute to enable having an horizontal scrollbar
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_HorizontalScrollbar) else False

    @horizontal_scrollbar.setter
    def horizontal_scrollbar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_HorizontalScrollbar
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_HorizontalScrollbar

    @property
    def no_focus_on_appearing(self):
        """
        Writable attribute to indicate when the windows moves from
        an un-shown to a shown item shouldn't be made automatically
        focused
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoFocusOnAppearing) else False

    @no_focus_on_appearing.setter
    def no_focus_on_appearing(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoFocusOnAppearing
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoFocusOnAppearing

    @property
    def no_bring_to_front_on_focus(self):
        """
        Writable attribute to indicate when the window takes focus (click on it, etc)
        it shouldn't be shown in front of other windows
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoBringToFrontOnFocus) else False

    @no_bring_to_front_on_focus.setter
    def no_bring_to_front_on_focus(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoBringToFrontOnFocus
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoBringToFrontOnFocus

    @property
    def always_show_vertical_scrollvar(self):
        """
        Writable attribute to tell to always show a vertical scrollbar
        even when the size does not require it
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_AlwaysVerticalScrollbar) else False

    @always_show_vertical_scrollvar.setter
    def always_show_vertical_scrollvar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_AlwaysVerticalScrollbar
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_AlwaysVerticalScrollbar

    @property
    def always_show_horizontal_scrollvar(self):
        """
        Writable attribute to tell to always show a horizontal scrollbar
        even when the size does not require it (only if horizontal scrollbar
        are enabled)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_AlwaysHorizontalScrollbar) else False

    @always_show_horizontal_scrollvar.setter
    def always_show_horizontal_scrollvar(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_AlwaysHorizontalScrollbar
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_AlwaysHorizontalScrollbar

    @property
    def unsaved_document(self):
        """
        Writable attribute to display a dot next to the title, as if the window
        contains unsaved changes.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_UnsavedDocument) else False

    @unsaved_document.setter
    def unsaved_document(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_UnsavedDocument
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_UnsavedDocument

    '''
    @property
    def disallow_docking(self):
        """
        Writable attribute to disable docking for the window
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoDocking) else False

    @disallow_docking.setter
    def disallow_docking(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoDocking
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoDocking
    '''

    @property
    def no_open_over_existing_popup(self):
        """
        Writable attribute for modal and popup windows to prevent them from
        showing if there is already an existing popup/modal window
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._no_open_over_existing_popup

    @no_open_over_existing_popup.setter
    def no_open_over_existing_popup(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._no_open_over_existing_popup = value

    @property
    def modal(self):
        """
        Writable attribute to indicate the window is a modal window.
        Modal windows are similar to popup windows, but they have a close
        button and are not closed by clicking outside.
        Clicking has no effect of items outside the modal window until it is closed.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._modal

    @modal.setter
    def modal(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._modal = value

    @property
    def popup(self):
        """
        Writable attribute to indicate the window is a popup window.
        Popup windows are centered (unless a pos is set), do not have a
        close button, and are closed when they lose focus (clicking outside the
        window).
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._popup

    @popup.setter
    def popup(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._popup = value

    @property
    def has_close_button(self):
        """
        Writable attribute to indicate the window has a close button.
        Has effect only for normal and modal windows.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._has_close_button and not(self._popup)

    @has_close_button.setter
    def has_close_button(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._has_close_button = value

    @property
    def collapsed(self):
        """
        Writable attribute to collapse (~minimize) or uncollapse the window
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return not(self.state.cur.open)

    @collapsed.setter
    def collapsed(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.state.cur.open = not(value)
        self._collapse_update_requested = True

    @property
    def on_close(self):
        """
        Callback to call when the window is closed.
        Note closing the window does not destroy or unattach the item.
        Instead it is switched to a show=False state.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._on_close_callback

    @on_close.setter
    def on_close(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._on_close_callback = value if isinstance(value, Callback) or value is None else Callback(value)

    @property
    def on_drop(self):
        """
        Callback to call when the window receives a system
        drag&drop operation.
        The callback takes as input (sender, target, data),
        where sender and target are always the viewport in
        this context. data is a tuple of two elements.
        The first one is 0 (for text) or 1 (for file) depending on the
        type of dropped data, and the second is a list of
        strings corresponding to the dropped content.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._on_drop_callback

    @on_drop.setter
    def on_drop(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._on_drop_callback = value if isinstance(value, Callback) or value is None else Callback(value)

    @property
    def primary(self):
        """
        Writable attribute: Indicate if the window is the primary window.
        There is maximum one primary window. The primary window covers the whole
        viewport and can be used to draw on the background.
        It is equivalent to setting:
        no_bring_to_front_on_focus
        no_saved_settings
        no_resize
        no_collapse
        no_title_bar
        and running item.focused = True on all the other windows
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._main_window

    @primary.setter
    def primary(self, bint value):
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        cdef unique_lock[recursive_mutex] m3
        # If window has a parent, it is the viewport
        lock_gil_friendly(m, self.context.viewport.mutex)
        lock_gil_friendly(m2, self.mutex)

        if self.parent is None:
            raise ValueError("Window must be attached before becoming primary")
        if self._main_window == value:
            return # Nothing to do
        self._main_window = value
        if value:
            # backup previous state
            self._backup_window_flags = self._window_flags
            self._backup_pos = self.state.cur.pos_to_viewport
            self._backup_rect_size = self.requested_size # We should backup self.state.cur.rect_size, but the we have a dpi scaling issue
            # Make primary
            self._window_flags = \
                imgui.ImGuiWindowFlags_NoBringToFrontOnFocus | \
                imgui.ImGuiWindowFlags_NoSavedSettings | \
			    imgui.ImGuiWindowFlags_NoResize | \
                imgui.ImGuiWindowFlags_NoCollapse | \
                imgui.ImGuiWindowFlags_NoTitleBar
            self.state.cur.pos_to_viewport.x = 0
            self.state.cur.pos_to_viewport.y = 0
            self.requested_size.x = 0
            self.requested_size.y = 0
            self.pos_update_requested = True
            self.size_update_requested = True
        else:
            # Restore previous state
            self._window_flags = self._backup_window_flags
            self.state.cur.pos_to_viewport = self._backup_pos
            self.requested_size = self._backup_rect_size
            # Tell imgui to update the window shape
            self.pos_update_requested = True
            self.size_update_requested = True

        # Re-tell imgui the window hierarchy
        cdef Window w = self.context.viewport.last_window_child
        cdef Window next = None
        while w is not None:
            lock_gil_friendly(m3, w.mutex)
            w.state.cur.focused = True
            w._focus_update_requested = True
            next = w.prev_sibling
            # TODO: previous code did restore previous states on each window. Figure out why
            w = next

    @property
    def min_size(self):
        """
        Writable attribute to indicate the minimum window size
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build_v(self._min_size)

    @min_size.setter
    def min_size(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._min_size.x = max(1, value[0])
        self._min_size.y = max(1, value[1])

    @property
    def max_size(self):
        """
        Writable attribute to indicate the maximum window size
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build_v(self._max_size)

    @max_size.setter
    def max_size(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._max_size.x = max(1, value[0])
        self._max_size.y = max(1, value[1])

    cdef void draw(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)

        if not(self._show):
            if self._show_update_requested:
                self.set_previous_states()
                self.set_hidden_no_handler_and_propagate_to_children_with_handlers()
                self.run_handlers()
                self._show_update_requested = False
            return

        cdef float original_scale = self.context.viewport.global_scale
        self.context.viewport.global_scale = original_scale * self._scaling_factor

        self.set_previous_states()

        if self._focus_update_requested:
            if self.state.cur.focused:
                imgui.SetNextWindowFocus()
            self._focus_update_requested = False

        cdef Positioning[2] policy = self.pos_policy
        cdef Vec2 cursor_pos_backup = self.context.viewport.window_cursor
        cdef Vec2 pos = cursor_pos_backup

        if self.pos_update_requested:
            if self._main_window:
                self.state.cur.pos_to_viewport.x = 0
                self.state.cur.pos_to_viewport.y = 0
                self.pos_policy[0] = Positioning.REL_VIEWPORT
                self.pos_policy[1] = Positioning.REL_VIEWPORT
                policy = self.pos_policy
            # Note the parent may be a WindowLayout and it is
            # considered a window (thus REL_WINDOW and REL_PARENT apply)
            if policy[0] == Positioning.REL_DEFAULT:
                pos.x += self.state.cur.pos_to_default.x
            elif policy[0] == Positioning.REL_PARENT:
                pos.x = self.context.viewport.parent_pos.x + self.state.cur.pos_to_parent.x
            elif policy[0] == Positioning.REL_WINDOW:
                pos.x = self.context.viewport.window_pos.x + self.state.cur.pos_to_window.x
            elif policy[0] == Positioning.REL_VIEWPORT:
                pos.x = self.state.cur.pos_to_viewport.x
            # else: DEFAULT

            if policy[1] == Positioning.REL_DEFAULT:
                pos.y += self.state.cur.pos_to_default.y
            elif policy[1] == Positioning.REL_PARENT:
                pos.y = self.context.viewport.parent_pos.y + self.state.cur.pos_to_parent.y
            elif policy[1] == Positioning.REL_WINDOW:
                pos.y = self.context.viewport.window_pos.y + self.state.cur.pos_to_window.y
            elif policy[1] == Positioning.REL_VIEWPORT:
                pos.y = self.state.cur.pos_to_viewport.y
            # else: DEFAULT
            imgui.SetNextWindowPos(Vec2ImVec2(pos), imgui.ImGuiCond_Always)
            self.pos_update_requested = False

        if self.size_update_requested:
            imgui.SetNextWindowSize(Vec2ImVec2(self.scaled_requested_size()),
                                    imgui.ImGuiCond_Always)
            self.size_update_requested = False

        if self._collapse_update_requested:
            imgui.SetNextWindowCollapsed(not(self.state.cur.open), imgui.ImGuiCond_Always)
            self._collapse_update_requested = False

        cdef Vec2 min_size = self._min_size
        cdef Vec2 max_size = self._max_size
        if self._dpi_scaling:
            min_size.x *= self.context.viewport.global_scale
            min_size.y *= self.context.viewport.global_scale
            max_size.x *= self.context.viewport.global_scale
            max_size.y *= self.context.viewport.global_scale
        imgui.SetNextWindowSizeConstraints(
            Vec2ImVec2(min_size), Vec2ImVec2(max_size))

        cdef imgui.ImVec2 scroll_requested
        if self._scroll_x_update_requested or self._scroll_y_update_requested:
            scroll_requested = imgui.ImVec2(-1., -1.) # -1 means no effect
            if self._scroll_x_update_requested:
                if self._scroll_x < 0.:
                    scroll_requested.x = 1. # from previous code. Not sure why
                else:
                    scroll_requested.x = self._scroll_x
                self._scroll_x_update_requested = False

            if self._scroll_y_update_requested:
                if self._scroll_y < 0.:
                    scroll_requested.y = 1.
                else:
                    scroll_requested.y = self._scroll_y
                self._scroll_y_update_requested = False
            imgui.SetNextWindowScroll(scroll_requested)

        if self._main_window:
            # No transparency
            imgui.SetNextWindowBgAlpha(1.0)
            #to prevent main window corners from showing
            imgui.PushStyleVar(imgui.ImGuiStyleVar_WindowRounding, 0.0)
            imgui.PushStyleVar(imgui.ImGuiStyleVar_WindowPadding, imgui.ImVec2(0.0, 0.))
            imgui.PushStyleVar(imgui.ImGuiStyleVar_WindowBorderSize, 0.)
            imgui.SetNextWindowSize(Vec2ImVec2(self.context.viewport.get_size()),
                                    imgui.ImGuiCond_Always)

        # handle fonts
        if self._font is not None:
            self._font.push()

        # themes
        self.context.viewport.push_pending_theme_actions(
            ThemeEnablers.ANY,
            ThemeCategories.t_window
        )
        if self._theme is not None:
            self._theme.push()

        cdef bint visible = True
        # Modal/Popup windows must be manually opened
        if self._modal or self._popup:
            if self._show_update_requested and self._show:
                self._show_update_requested = False
                imgui.OpenPopup(self._imgui_label.c_str(),
                                imgui.ImGuiPopupFlags_NoOpenOverExistingPopup if self._no_open_over_existing_popup else imgui.ImGuiPopupFlags_None)

        # Begin drawing the window
        cdef imgui.ImGuiWindowFlags flags = self._window_flags
        if self.last_menubar_child is not None:
            flags |= imgui.ImGuiWindowFlags_MenuBar

        if self._modal:
            visible = imgui.BeginPopupModal(self._imgui_label.c_str(),
                                            &self._show if self._has_close_button else <bool*>NULL,
                                            flags)
        elif self._popup:
            visible = imgui.BeginPopup(self._imgui_label.c_str(), flags)
        else:
            visible = imgui.Begin(self._imgui_label.c_str(),
                                  &self._show if self._has_close_button else <bool*>NULL,
                                  flags)

        if self._main_window:
            # To not affect children.
            # the styles are used in Begin() only
            imgui.PopStyleVar(3)

        # not(visible) means either closed or clipped
        # if has_close_button, show can be switched from True to False if closed

        cdef Vec2 parent_size_backup

        if visible:
            # Retrieve the full region size before the cursor is moved.
            self.state.cur.content_region_size = ImVec2Vec2(imgui.GetContentRegionAvail())
            # Draw the window content
            self.context.viewport.window_pos = ImVec2Vec2(imgui.GetCursorScreenPos())
            self._content_pos = self.context.viewport.window_pos
            self.context.viewport.parent_pos = self.context.viewport.window_pos # should we restore after ? TODO
            parent_size_backup = self.context.viewport.parent_size
            self.context.viewport.parent_size = self.state.cur.content_region_size

            #if self._last_0_child is not None:
            #    self._last_0_child.draw(this_drawlist, startx, starty)

            draw_ui_children(self)
            # TODO if self._children_widgets[i].tracked and show:
            #    imgui.SetScrollHereY(self._children_widgets[i].trackOffset)

            draw_menubar_children(self)
            self.context.viewport.parent_size = parent_size_backup

        cdef Vec2 rect_size
        if visible:
            # Set current states
            self.state.cur.rendered = True
            self.state.cur.hovered = imgui.IsWindowHovered(imgui.ImGuiHoveredFlags_None)
            self.state.cur.focused = imgui.IsWindowFocused(imgui.ImGuiFocusedFlags_None)
            rect_size = ImVec2Vec2(imgui.GetWindowSize())
            self.state.cur.rect_size = rect_size
            #self._last_frame_update = self.context.viewport.frame_count # TODO remove ?
            self.state.cur.pos_to_viewport = ImVec2Vec2(imgui.GetWindowPos())
            self.state.cur.pos_to_window.x = self.state.cur.pos_to_viewport.x - self.context.viewport.window_pos.x
            self.state.cur.pos_to_window.y = self.state.cur.pos_to_viewport.y - self.context.viewport.window_pos.y
            self.state.cur.pos_to_parent.x = self.state.cur.pos_to_viewport.x - self.context.viewport.parent_pos.x
            self.state.cur.pos_to_parent.y = self.state.cur.pos_to_viewport.y - self.context.viewport.parent_pos.y
            self.state.cur.pos_to_default.x = self.state.cur.pos_to_viewport.x - cursor_pos_backup.x
            self.state.cur.pos_to_default.y = self.state.cur.pos_to_viewport.y - cursor_pos_backup.y
            if self.no_newline and \
               (policy[1] == Positioning.REL_DEFAULT or \
                policy[1] == Positioning.DEFAULT):
                self.context.viewport.window_cursor.x = self.state.cur.pos_to_viewport.x + rect_size.x
                self.context.viewport.window_cursor.y = self.state.cur.pos_to_viewport.y
            else:
                self.context.viewport.window_cursor.x = 0
                self.context.viewport.window_cursor.y = self.state.cur.pos_to_viewport.y + rect_size.y
        else:
            # Window is hidden or closed
            self.set_hidden_no_handler_and_propagate_to_children_with_handlers()

        self.state.cur.open = not(imgui.IsWindowCollapsed())
        self._scroll_x = imgui.GetScrollX()
        self._scroll_y = imgui.GetScrollY()


        # Post draw

        """
        cdef float titleBarHeight
        cdef float x, y
        cdef Vec2 mousePos
        if focused:
            titleBarHeight = imgui.GetStyle().FramePadding.y * 2 + imgui.GetFontSize()

            # update mouse
            mousePos = imgui.GetMousePos()
            x = mousePos.x - self._pos.x
            y = mousePos.y - self._pos.y - titleBarHeight
            #GContext->input.mousePos.x = (int)x;
            #GContext->input.mousePos.y = (int)y;
            #GContext->activeWindow = item
        """

        if (self._modal or self._popup):
            if visible:
                # End() is called automatically for modal and popup windows if not visible
                imgui.EndPopup()
        else:
            imgui.End()

        if self._theme is not None:
            self._theme.pop()
        self.context.viewport.pop_applied_pending_theme_actions()

        if self._font is not None:
            self._font.pop()

        # Restore original scale
        self.context.viewport.global_scale = original_scale 

        cdef bint closed = not(self._show) or (not(visible) and (self._modal or self._popup))
        if closed:
            self._show = False
            self.context.queue_callback_noarg(self._on_close_callback,
                                              self,
                                              self)
        self._show_update_requested = False

        self.run_handlers()
        # The sizing of windows might not converge right away
        if self.state.cur.content_region_size.x != self.state.prev.content_region_size.x or \
           self.state.cur.content_region_size.y != self.state.prev.content_region_size.y:
            self.context.viewport.redraw_needed = True


cdef class plotElement(baseItem):
    """
    Base class for plot children.

    Attributes:
    - show: Boolean indicating if the plot element should be shown.
    - axes: Axes for the plot element.
    - label: Label for the plot element.
    - theme: Theme for the plot element.
    """
    def __cinit__(self):
        self._imgui_label = b'###%ld'% self.uuid
        self._user_label = ""
        self._flags = implot.ImPlotItemFlags_None
        self.can_have_sibling = True
        self.element_child_category = child_type.cat_plot_element
        self._show = True
        self._axes = [implot.ImAxis_X1, implot.ImAxis_Y1]
        self._theme = None

    @property
    def show(self):
        """
        Writable attribute: Should the object be drawn/shown ?
        In case show is set to False, this disables any
        callback (for example the close callback won't be called
        if a window is hidden with show = False).
        In the case of items that can be closed,
        show is set to False automatically on close.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._show

    @show.setter
    def show(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if not(value) and self._show:
            self.set_hidden_and_propagate_to_children_no_handlers()
        self._show = value

    @property
    def axes(self):
        """
        Writable attribute: (X axis, Y axis)
        used for this plot element.
        Default is (X1, Y1)
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return (self._axes[0], self._axes[1])

    @axes.setter
    def axes(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef int32_t axis_x, axis_y
        try:
            (axis_x, axis_y) = value
            assert(axis_x in [implot.ImAxis_X1,
                              implot.ImAxis_X2,
                              implot.ImAxis_X3])
            assert(axis_y in [implot.ImAxis_Y1,
                              implot.ImAxis_Y2,
                              implot.ImAxis_Y3])
        except Exception as e:
            raise ValueError("Axes must be a tuple of valid X/Y axes")
        self._axes[0] = axis_x
        self._axes[1] = axis_y

    @property
    def label(self):
        """
        Writable attribute: label assigned to the element
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._user_label

    @label.setter
    def label(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._user_label = ""
        else:
            self._user_label = value
        # Using ### means that imgui will ignore the user_label for
        # its internal ID of the object. Indeed else the ID would change
        # when the user label would change
        self._imgui_label = bytes(self._user_label, 'utf-8') + b'###%ld'% self.uuid

    @property
    def theme(self):
        """
        Writable attribute: theme for the legend and plot
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._theme

    @theme.setter
    def theme(self, baseTheme value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._theme = value

    cdef void draw(self) noexcept nogil:
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)

        # Check the axes are enabled
        if not(self._show) or \
           not(self.context.viewport.enabled_axes[self._axes[0]]) or \
           not(self.context.viewport.enabled_axes[self._axes[1]]):
            self.propagate_hidden_state_to_children_with_handlers()
            return

        # push theme

        self.context.viewport.push_pending_theme_actions(
            ThemeEnablers.ANY,
            ThemeCategories.t_plot
        )

        if self._theme is not None:
            self._theme.push()

        implot.SetAxes(self._axes[0], self._axes[1])

        self.draw_element()

        # pop theme, font
        if self._theme is not None:
            self._theme.pop()

        self.context.viewport.pop_applied_pending_theme_actions()

    cdef void draw_element(self) noexcept nogil:
        return


cdef class AxisTag(baseItem):
    """
    Class for Axis tags. Can only be child
    of a plot Axis.
    """
    def __cinit__(self):
        self.can_have_sibling = True
        self.element_child_category = child_type.cat_tag
        self.show = True
        # 0 means no background, in which case ImPlotCol_AxisText
        # is used for the text color. Else Text is automatically
        # set to white or black depending on the background color
        self.bg_color = 0

    @property
    def show(self):
        """
        Writable attribute: Should the object be drawn/shown ?
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.show

    @show.setter
    def show(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.show = value

    @property
    def bg_color(self):
        """
        Writable attribute: Background color of the tag.
        0 means no background, in which case ImPlotCol_AxisText
        is used for the text color. Else Text is automatically
        set to white or black depending on the background color

        Returns:
            list: RGBA values in [0,1] range
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self.bg_color)
        return list(color)

    @bg_color.setter
    def bg_color(self, value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.bg_color = parse_color(value)

    @property
    def coord(self):
        """
        Writable attribute: Coordinate of the tag.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.coord

    @coord.setter
    def coord(self, double value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.coord = value

    @property
    def text(self):
        """
        Writable attribute: Text of the tag.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return str(self.text, encoding='utf-8')

    @text.setter
    def text(self, str value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.text = bytes(str(value), 'utf-8')

"""
Textures
"""

cdef class Texture(baseItem):
    """
    Represents a texture that can be used in the UI.

    Attributes:
    - hint_dynamic: Boolean indicating if the texture is dynamic.
    - nearest_neighbor_upsampling: Boolean indicating if nearest neighbor upsampling is used.
    - width: Width of the texture.
    - height: Height of the texture.
    - num_chans: Number of channels in the texture.
    """
    def __cinit__(self):
        self._hint_dynamic = False
        self._dynamic = False
        self._no_realloc = False
        self._readonly = False
        self.allocated_texture = NULL
        self.width = 0
        self.height = 0
        self.num_chans = 0
        self._buffer_type = 0
        self._filtering_mode = 0

    def __dealloc__(self):
        cdef unique_lock[recursive_mutex] imgui_m
        # Note: textures might be referenced during imgui rendering.
        # Thus we should wait there is no rendering to free a texture.
        # However, doing so would stall python's garbage collection,
        # and the gil. OpenGL is fine with the texture being deleted
        # while it is still in use (there will just be an artefact),
        # plus we delay texture deletion for a few frames,
        # so it should be fine.
        if self.allocated_texture != NULL:
            (<platformViewport*>self.context.viewport._platform).makeUploadContextCurrent()
            (<platformViewport*>self.context.viewport._platform).freeTexture(self.allocated_texture)
            (<platformViewport*>self.context.viewport._platform).releaseUploadContext()

    def configure(self, *args, **kwargs):
        if len(args) == 1:
            self.set_content(np.ascontiguousarray(args[0]))
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to Texture. Expected content")
        self._filtering_mode = 1 if kwargs.pop("nearest_neighbor_upsampling", False) else 0
        return super().configure(**kwargs)

    @property
    def hint_dynamic(self):
        """
        Hint for texture placement that
        the texture will be updated very
        frequently.
        Must be set before set_value/allocate.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._hint_dynamic
    @hint_dynamic.setter
    def hint_dynamic(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._hint_dynamic = value
    @property
    def nearest_neighbor_upsampling(self):
        """
        Whether to use nearest neighbor interpolation
        instead of bilinear interpolation when upscaling
        the texture. Must be set before set_value/allocate.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return True if self._filtering_mode == 1 else 0
    @nearest_neighbor_upsampling.setter
    def nearest_neighbor_upsampling(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._filtering_mode = 1 if value else 0
    @property
    def width(self):
        """ Width of the current texture content """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.width
    @property
    def height(self):
        """ Height of the current texture content """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.height
    @property
    def num_chans(self):
        """ Number of channels of the current texture content """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self.num_chans

    @property
    def texture_id(self):
        """ Internal texture ID used by the rendering backend
        for the current allocation. May change if set_value is
        called, and is released when the Texture is freed."""
        return <uintptr_t>self.allocated_texture

    def allocate(self, *,
                 int32_t width,
                 int32_t height,
                 int32_t num_chans,
                 bint uint8 = False,
                 bint float32 = False,
                 bint no_realloc = True):
        """
        Allocate the buffer backing. You don't need
        to use this for normal texture usage as it is done
        automatically by set_value.

        This function is useful when needing to write to a texture
        using external rendering tools (OpenGL, etc) and you don't
        want to do a first set_value to initialize

        Inputs:
        - width: width of the target texture
        - height: height of the target texture
        - num_chans: number of channels (1, 2, 3, 4)
        - uint8: (False by default) the texture format is unsigned bytes
        - float32: (False by default) the texture format is float32
        - no_realloc: (True by default) reallocations of the texture
            will be prevented (set_value, etc), thus guaranteeing a fixed
            allocated_texture ID.
        uint8 or float32 must be set.
        """
        if self.allocated_texture != NULL and self._no_realloc:
            raise ValueError("Texture backing cannot be reallocated")

        cdef unsigned buffer_type
        if uint8:
            buffer_type = 1
        elif float32:
            buffer_type = 0
        else:
            raise ValueError("Invalid texture format. Float32 or uint8 must be set")

        cdef bint success
        with nogil:
            (<platformViewport*>self.context.viewport._platform).makeUploadContextCurrent()
            self.mutex.lock()
            self.allocated_texture = \
                (<platformViewport*>self.context.viewport._platform).allocateTexture(width,
                                                                    height,
                                                                    num_chans,
                                                                    self._dynamic,
                                                                    buffer_type,
                                                                    self._filtering_mode)
            (<platformViewport*>self.context.viewport._platform).releaseUploadContext()
            success = self.allocated_texture != NULL
            if success:
                self.width = width
                self.height = height
                self.num_chans = num_chans
                self._buffer_type = buffer_type
            self.mutex.unlock()
        if not(success):
            raise MemoryError("Failed to allocate target texture")


    def set_value(self, value):
        """
        Pass an array as texture data.
        The currently native formats are:
        - data type: uint8 or float32.
            Anything else will be converted to float32
            float32 data must be normalized between 0 and 1.
        - number of channels: 1 (R), 2 (RG), 3 (RGB), 4 (RGBA)

        In the case of single channel textures, during rendering, R is
        duplicated on G and B, thus the texture is displayed as gray,
        not red.

        If set_value is called on a texture which already
        has content, the previous allocation will be reused
        if the size, type and number of channels is identical.

        The data is uploaded right away during set_value,
        thus the call is not instantaneous.
        The data can be discarded after set_value.

        If you change the data of a texture, you don't
        need to bind it again to the objects it is
        bound. The objects will automatically take
        the updated texture.
        """
        self.set_content(np.asarray(value))

    cdef void set_content(self, cnp.ndarray content): # TODO: deadlock when held by external lock
        # The write mutex is to ensure order of processing of set_content
        # as we might release the item mutex to wait for imgui to render
        cdef unique_lock[recursive_mutex] m
        cdef unique_lock[recursive_mutex] m2
        lock_gil_friendly(m, self._write_mutex)
        lock_gil_friendly(m2, self.mutex)
        cdef int32_t ndim = cnp.PyArray_NDIM(content)
        if ndim > 3 or ndim == 0:
            raise ValueError("Invalid number of texture dimensions")
        if self._readonly: # set for fonts
            raise ValueError("Target texture is read-only")
        cdef int32_t height = 1
        cdef int32_t width = 1
        cdef int32_t num_chans = 1
        cdef int32_t stride = 1

        if ndim >= 1:
            height = cnp.PyArray_DIM(content, 0)
        if ndim >= 2:
            width = cnp.PyArray_DIM(content, 1)
        if ndim >= 3:
            num_chans = cnp.PyArray_DIM(content, 2)
        if width * height * num_chans == 0:
            raise ValueError("Cannot set empty texture")

        # TODO: there must be a faster test
        if not(content.dtype == np.float32 or content.dtype == np.uint8):
            content = np.asarray(content, dtype=np.float32)

        # rows must be contiguous
        if ndim >= 2 and cnp.PyArray_STRIDE(content, 1) != (num_chans * (1 if content.dtype == np.uint8 else 4)):
            content = np.ascontiguousarray(content, dtype=content.dtype)

        stride = cnp.PyArray_STRIDE(content, 0)


        cdef bint reuse = self.allocated_texture != NULL
        cdef bint success
        cdef unsigned buffer_type = 1 if content.dtype == np.uint8 else 0
        reuse = reuse and not(self.width != width or self.height != height or self.num_chans != num_chans or self._buffer_type != buffer_type)
        if not(reuse) and self._no_realloc:
            raise ValueError("Texture cannot be reallocated and upload data is not of the same size/type as the texture")

        with nogil:
            if self.allocated_texture != NULL and not(reuse):
                # We must wait there is no rendering since the current rendering might reference the texture
                # Release current lock to not block rendering
                # Wait we can prevent rendering
                if not(self.context.imgui_mutex.try_lock()):
                    m2.unlock()
                    # rendering can take some time, fortunately we avoid holding the gil
                    self.context.imgui_mutex.lock()
                    m2.lock()
                (<platformViewport*>self.context.viewport._platform).makeUploadContextCurrent()
                (<platformViewport*>self.context.viewport._platform).freeTexture(self.allocated_texture)
                self.allocated_texture = NULL
                self.context.imgui_mutex.unlock()
            else:
                m2.unlock()
                (<platformViewport*>self.context.viewport._platform).makeUploadContextCurrent()
                m2.lock()

            # Note we don't need the imgui mutex to create or upload textures.
            # In the case of GL, as only one thread can access GL data at a single
            # time, MakeUploadContextCurrent and ReleaseUploadContext enable
            # to upload/create textures from various threads. They hold a mutex.
            # That mutex is held in the relevant parts of frame rendering.

            self.width = width
            self.height = height
            self.num_chans = num_chans
            self._buffer_type = buffer_type

            if not(reuse):
                self._dynamic = self._hint_dynamic
                self.allocated_texture = \
                    (<platformViewport*>self.context.viewport._platform).allocateTexture(width,
                                                                    height,
                                                                    num_chans,
                                                                    self._dynamic,
                                                                    buffer_type,
                                                                    self._filtering_mode)

            success = self.allocated_texture != NULL
            if success:
                if self._dynamic:
                    success = \
                        (<platformViewport*>self.context.viewport._platform).updateDynamicTexture(
                                                     self.allocated_texture,
                                                     width,
                                                     height,
                                                     num_chans,
                                                     buffer_type,
                                                     cnp.PyArray_DATA(content),
                                                     stride)
                else:
                    success = (<platformViewport*>self.context.viewport._platform).updateStaticTexture(
                                                    self.allocated_texture,
                                                    width,
                                                    height,
                                                    num_chans,
                                                    buffer_type,
                                                    cnp.PyArray_DATA(content),
                                                    stride)
            (<platformViewport*>self.context.viewport._platform).releaseUploadContext()
            m.unlock()
            m2.unlock() # Release before we get gil again
        if not(success):
            raise MemoryError("Failed to upload target texture")

    def read(self, int32_t x0=0, int32_t y0=0, int32_t crop_width=0, int32_t crop_height=0):
        """
        Read the texture content. The texture must be
        allocated and have content.

        Inputs:
        - x0: x coordinate of the top left corner of the crop
        - y0: y coordinate of the top left corner of the crop
        - crop_width: width of the crop (0 for full width)
        - crop_height: height of the crop (0 for full_height)

        Returns:
        - numpy array: the texture content
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        cdef int32_t width = self.width
        cdef int32_t height = self.height
        cdef int32_t num_chans = self.num_chans
        cdef int32_t buffer_type = self._buffer_type
        cdef int32_t crop_width_ = crop_width if crop_width > 0 else width
        cdef int32_t crop_height_ = crop_height if crop_height > 0 else height
        if x0 < 0 or y0 < 0 or crop_width_ <= 0 or crop_height_ <= 0 or x0 + crop_width_ > width or y0 + crop_height_ > height:
            raise ValueError("Invalid crop coordinates")
        cdef cnp.ndarray array
        cdef void *data
        cdef bint success

        # allocate array
        if buffer_type == 1:
            array = np.empty((crop_height_, crop_width_, num_chans), dtype=np.uint8)
        else:
            array = np.empty((crop_height_, crop_width_, num_chans), dtype=np.float32)
        data = cnp.PyArray_DATA(array)

        cdef int32_t stride = cnp.PyArray_STRIDE(array, 0)
        with nogil:
            m.unlock()
            (<platformViewport*>self.context.viewport._platform).makeUploadContextCurrent()
            m.lock()
            success = \
                (<platformViewport*>self.context.viewport._platform).downloadTexture(self.allocated_texture,
                                x0, y0, crop_width_, crop_height_, num_chans,
                                self._buffer_type, data, stride)
            (<platformViewport*>self.context.viewport._platform).releaseUploadContext()
        if not(success):
            raise ValueError("Failed to read the texture")
        return array

    cdef void c_gl_begin_read(self) noexcept nogil:
        """
        Same as gl_begin_read, but for cython item draw subclassing
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        (<platformViewport*>self.context.viewport._platform).beginExternalRead(<uintptr_t>self.allocated_texture)

    def gl_begin_read(self):
        """
        Locks a texture for a read operation for an external GL context.

        The target GL context MUST be current.

        The call inserts a GPU fence to ensure any previous
        DearCyGui rendering or upload finishes before the texture
        is read.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.c_gl_begin_read()

    cdef void c_gl_end_read(self) noexcept nogil:
        """
        Same as gl_end_read, but for cython item draw subclassing
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        (<platformViewport*>self.context.viewport._platform).endExternalRead(<uintptr_t>self.allocated_texture)

    def gl_end_read(self):
        """
        Unlocks a texture after a read operation for an external GL context.

        The target GL context MUST be current.

        The call issues a GPU fence that will be used by
        DearCyGui to ensure the texture is not written to
        before the read operation has finished.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.c_gl_end_read()

    cdef void c_gl_begin_write(self) noexcept nogil:
        """
        Same as gl_begin_write, but for cython item draw subclassing
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        (<platformViewport*>self.context.viewport._platform).beginExternalWrite(<uintptr_t>self.allocated_texture)

    def gl_begin_write(self):
        """
        Locks a texture for a write operation for an external GL context.

        The target GL context MUST be current.

        The call inserts a GPU fence to ensure any previous
        DearCyGui rendering reading from the texture finishes
        before the texture is written to.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.c_gl_begin_write()

    cdef void c_gl_end_write(self) noexcept nogil:
        """
        Same as gl_end_write, but for cython item draw subclassing
        """
        cdef unique_lock[recursive_mutex] m = unique_lock[recursive_mutex](self.mutex)
        (<platformViewport*>self.context.viewport._platform).endExternalWrite(<uintptr_t>self.allocated_texture)

    def gl_end_write(self):
        """
        Unlocks a texture after a write operation for an external GL context.

        The target GL context MUST be current.

        The call issues a GPU fence that will be used by
        DearCyGui to ensure the texture is not read from
        before the write operation has finished.
        """
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self.c_gl_end_write()


cdef class baseFont(baseItem):
    def __cinit__(self, context, *args, **kwargs):
        self.can_have_sibling = False

    cdef void push(self) noexcept nogil:
        return

    cdef void pop(self) noexcept nogil:
        return


cdef class baseTheme(baseItem):
    """
    Base theme element. Contains a set of theme elements to apply for a given category (color, style)/(imgui/implot/imnode).

    Attributes:
    - enabled: Boolean indicating if the theme is enabled.
    """
    def __cinit__(self):
        self.element_child_category = child_type.cat_theme
        self.can_have_sibling = True
        self._enabled = True
    def configure(self, **kwargs):
        self._enabled = kwargs.pop("enabled", self._enabled)
        self._enabled = kwargs.pop("show", self._enabled)
        return super().configure(**kwargs)
    @property
    def enabled(self):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        return self._enabled
    @enabled.setter
    def enabled(self, bint value):
        cdef unique_lock[recursive_mutex] m
        lock_gil_friendly(m, self.mutex)
        self._enabled = value
    # should be always defined by subclass
    cdef void push(self) noexcept nogil:
        return
    cdef void pop(self) noexcept nogil:
        return
    cdef void push_to_list(self, vector[theme_action]& v) noexcept nogil:
        return

