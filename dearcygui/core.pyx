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

from libc.stdint cimport uint8_t, uint32_t, int32_t, int64_t, uint64_t
from libc.string cimport memset, memcpy
from libcpp cimport bool
from libcpp.cmath cimport floor, ceil, round as cround, fmin, fmax
from libcpp.set cimport set as cpp_set
from libcpp.string cimport string

cimport cython
from cpython.buffer cimport Py_buffer, PyObject_CheckBuffer, PyObject_GetBuffer,\
    PyBuffer_Release, PyBUF_RECORDS_RO, PyBUF_CONTIG_RO
from cpython.sequence cimport PySequence_Check

from .backends.backend cimport SDLViewport, platformViewport, GLContext
cimport dearcygui.backends.time as ctime
from .c_types cimport unique_lock, DCGMutex, mutex, defer_lock_t, string_to_str,\
    set_composite_label, set_uuid_label, string_from_str, Vec2, make_Vec2
from .font cimport AutoFont
from .imgui_types cimport parse_color, ImVec2Vec2, Vec2ImVec2, unparse_color,\
    check_Axis, make_Axis
from .sizing cimport resolve_size, set_size, RefX0, RefY0, RefWidth, RefHeight
from .texture cimport Texture
from .types cimport Vec2, child_type,\
    Coord, parse_texture, Display,\
    get_children_types, get_item_type, is_Key, make_Key,\
    is_KeyMod, make_KeyMod, \
    is_MouseCursor, make_MouseCursor, is_MouseButton, make_MouseButton
from .wrapper cimport imgui, implot

from concurrent.futures import Executor, ThreadPoolExecutor
import os
import time as python_time
import traceback




"""
Each .so has its own current context. To be able to work
with various .so and contexts, we must ensure the correct
context is current. The call is almost free as it's just
a pointer that is set.
If you create your own custom rendering objects, you must ensure
that you link to the same version of ImGui (ImPlot if
applicable) and you must call ensure_correct_* at the start
of your draw() overrides
"""

cdef inline void ensure_correct_imgui_context(Context context) noexcept nogil:
    imgui.SetCurrentContext(<imgui.ImGuiContext*>context.imgui_context)

cdef inline void ensure_correct_implot_context(Context context) noexcept nogil:
    implot.SetCurrentContext(<implot.ImPlotContext*>context.implot_context)

cdef void ensure_correct_im_context(Context context) noexcept nogil:
    ensure_correct_imgui_context(context)
    ensure_correct_implot_context(context)


cdef class BackendRenderingContext:
    """
    Object used to create contexts with object sharing with the internal context.
    """
    cdef Context context
    def __init__(self):
        raise ValueError("Cannot create a BackendRenderingContext directly. Use the context object.")

    @property
    def name(self) -> str:
        return "GL" # For now only GL is supported

    def __enter__(self) -> BackendRenderingContext:
        # TODO: check thread safety
        (<platformViewport*>self.context.viewport._platform).makeUploadContextCurrent()
        return self

    def __exit__(self, exc_type, exc_value, traceback) -> bool:
        (<platformViewport*>self.context.viewport._platform).releaseUploadContext()
        return False

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
        """
        Make the attached context current.

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
        return False

    @staticmethod
    cdef SharedGLContext from_context(Context context, GLContext* gl_context):
        cdef SharedGLContext shared_context = SharedGLContext.__new__(SharedGLContext)
        shared_context.context = context
        shared_context.gl_context = gl_context
        return shared_context

# We use unique_lock rather than lock_guard as
# the latter doesn't support nullary constructor
# which causes trouble to cython

cdef void lock_gil_friendly_block(unique_lock[DCGMutex] &m) noexcept:
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

# parent stack for the 'with' syntax
cdef extern from * nogil:
    """
    thread_local std::vector<PyObject*> thread_local_parent_queue;
    inline bool thread_local_parent_empty() {
        return thread_local_parent_queue.empty();
    }
    inline void thread_local_parent_push(PyObject* obj) {
        Py_INCREF(obj);
        thread_local_parent_queue.push_back(obj);
    }
    inline void thread_local_parent_pop() {
        Py_DECREF(thread_local_parent_queue.back());
        thread_local_parent_queue.pop_back();
    }
    inline PyObject* thread_local_parent_fetch_back() {
        PyObject* obj = thread_local_parent_queue.back();
        Py_INCREF(obj);
        return obj;
    }
    inline PyObject* thread_local_parent_fetch_front() {
        PyObject* obj = thread_local_parent_queue.front();
        Py_INCREF(obj);
        return obj;
    }
    """
    bint thread_local_parent_empty()
    void thread_local_parent_push(object)
    void thread_local_parent_pop()
    object thread_local_parent_fetch_back()
    object thread_local_parent_fetch_front()

# The no gc clear flag enforces that in case
# of no-reference cycle detected, the Context is freed last.
# The cycle is due to Context referencing Viewport
# and vice-versa

cdef class Context:
    """
    Main class managing the DearCyGui items and imgui context.

    The Context class serves as the central manager for the DearCyGui application, handling:
        - GUI rendering and event processing
        - Item creation and lifecycle management
        - Thread-safe callback execution
        - Global viewport management
        - ImGui/ImPlot context management

    There is exactly one viewport per context. The last created context can be accessed 
    as dearcygui.C.

    Implementation Notes
    -------------------
    - Thread safety is achieved through recursive mutexes on items and ImGui context
    - Callbacks are executed in a separate thread pool to prevent blocking the render loop
    - References between items form a tree structure with viewport as root
    - ImGui/ImPlot contexts are managed to support multiple contexts
    """

    def __init__(self,
                 queue=None):
        """
        Initialize the Context.

        Parameters
        ----------
        queue : concurrent.futures.Executor, optional
            Executor for managing thread-pooled callbacks. 
            Defaults to ThreadPoolExecutor(max_workers=1)
        
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
            if not(isinstance(queue, Executor)) and \
                (not hasattr(queue, 'submit') and callable(queue.submit)):
                raise TypeError("queue must be a subclass of concurrent.futures.Executor or implement a 'submit' method")
            self._queue = queue
        C = self

    def __cinit__(self):
        """
        Cython-specific initializer for Context.
        """
        self.next_uuid.store(21)
        self._started = True
        self.imgui_context = NULL
        self.implot_context = NULL
        self.viewport = Viewport(self)
        imgui.IMGUI_CHECKVERSION()
        self.imgui_context = imgui.CreateContext()
        self.implot_context = implot.CreateContext()
        ensure_correct_im_context(self)

    def __dealloc__(self):
        """
        Deallocate resources for Context.
        """
        self._started = True
        ensure_correct_im_context(self)
        if self.implot_context != NULL:
            implot.DestroyContext(<implot.ImPlotContext*>self.implot_context)
        if self.imgui_context != NULL:
            imgui.DestroyContext(<imgui.ImGuiContext*>self.imgui_context)

    def __del__(self):
        """
        Destructor for Context.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self._on_close_callback is not None:
            self._started = True
            self.queue_callback_noarg(self._on_close_callback, self, self)
            self._started = False

        #mvToolManager::Reset()
        #ClearItemRegistry(*GContext->itemRegistry)
        #if self._queue is not None and hasattr(self._queue, 'shutdown') and callable(self._queue.shutdown):
        #    self._queue.shutdown(wait=False) # Commented because the queue can do it itself in its __del__

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
    def queue(self, queue): # TODO: thread safety
        """
        Set the Executor for managing thread-pooled callbacks.
        """
        if queue is self._queue:
            return
        # Check type
        if not(isinstance(queue, Executor)) and \
            (not hasattr(queue, 'submit') and callable(queue.submit)):
            raise TypeError("queue must be a subclass of concurrent.futures.Executor or implement a 'submit' method")
        #old_queue = self._queue
        self._queue = queue
        ## Finish previous queue
        #if old_queue is not None and hasattr(old_queue, 'shutdown') and callable(old_queue.shutdown):
        #    old_queue.shutdown(wait=False)
        # Commented out to let the user reuse the queue if it wants to.

    @property
    def rendering_context(self) -> BackendRenderingContext:
        """
        Readonly attribute: rendering context for the backend.
        Used to create contexts with object sharing.
        """
        return BackendRenderingContext.from_context(self)

    def create_new_shared_gl_context(self, int32_t major, int32_t minor) -> SharedGLContext:
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
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.viewport._mutex_backend)
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
                self._queue.submit(callback, parent_item, target_item, make_Key(arg1))
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
                self._queue.submit(callback, parent_item, target_item, make_MouseButton(arg1))
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
                self._queue.submit(callback, parent_item, target_item, (make_Key(arg1), arg2))
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
                self._queue.submit(callback, parent_item, target_item, (make_MouseButton(arg1), arg2))
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
                self._queue.submit(callback, parent_item, target_item, (make_MouseButton(arg1), arg2, arg3))
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
                                                  int32_t arg1, DCGVector[DCGString] arg2) noexcept nogil:
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
        cdef int i
        with gil:
            try:
                element_list = []
                for i in range(<int>arg2.size()):
                    element_list.append(string_to_str(arg2[i]))
                self._queue.submit(callback, parent_item, target_item, (arg1, element_list))
            except Exception as e:
                print(traceback.format_exc())

    cdef void queue_callback(self, Callback callback, baseItem sender, baseItem item, object data) noexcept:
        """
        Queue a callback with an item and data of any type.

        Parameters:
        callback : Callback
            The callback to be queued.
        item : baseItem
            The item associated with the callback.
        data : object
            Additional data to be passed to the callback.
        """
        if callback is None:
            return
        try:
            self._queue.submit(callback, sender, item, data)
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
        thread_local_parent_push(next_parent)

    cpdef void pop_next_parent(self):
        """
        Remove an item from the potential parent list.
        """
        if not thread_local_parent_empty():
            thread_local_parent_pop()

    cpdef object fetch_parent_queue_back(self):
        """
        Retrieve the last item from the potential parent list.

        Returns:
        object
            The last item from the potential parent list.
        """
        if thread_local_parent_empty():
            return None
        return thread_local_parent_fetch_back()

    cpdef object fetch_parent_queue_front(self):
        """
        Retrieve the top item from the potential parent list.

        Returns:
        object
            The top item from the potential parent list.
        """
        if thread_local_parent_empty():
            return None
        return thread_local_parent_fetch_front()

    cdef bint c_is_key_down(self, int32_t key) noexcept nogil:
        return imgui.IsKeyDown(<imgui.ImGuiKey>key)

    cdef int32_t c_get_keymod_mask(self) noexcept nogil:
        return <int>imgui.GetIO().KeyMods

    def is_key_down(self, key, keymod = None) -> bool:
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
        cdef unique_lock[DCGMutex] m
        if key is None or not(is_Key(key)):
            raise TypeError(f"key must be a valid Key, not {key}")
        if keymod is not None and not(is_KeyMod(keymod)):
            raise TypeError(f"keymod must be a valid KeyMod, not {keymod}")
        cdef imgui.ImGuiKey keycode = make_Key(key)
        ensure_correct_im_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        if keymod is not None and (<int>make_KeyMod(keymod) & imgui.ImGuiMod_Mask_) != imgui.GetIO().KeyMods:
            return False
        return imgui.IsKeyDown(keycode)

    cdef bint c_is_key_pressed(self, int32_t key, bint repeat) noexcept nogil:
        return imgui.IsKeyPressed(<imgui.ImGuiKey>key, repeat)

    def is_key_pressed(self, key, keymod = None, repeat: bool = True) -> bool:
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
        cdef unique_lock[DCGMutex] m
        if key is None or not(is_Key(key)):
            raise TypeError(f"key must be a valid Key, not {key}")
        if keymod is not None and not(is_KeyMod(keymod)):
            raise TypeError(f"keymod must be a valid KeyMod, not {keymod}")
        cdef imgui.ImGuiKey keycode = make_Key(key)
        ensure_correct_im_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        if keymod is not None and (<int>make_KeyMod(keymod) & imgui.ImGuiMod_Mask_) != imgui.GetIO().KeyMods:
            return False
        return imgui.IsKeyPressed(keycode, repeat)

    cdef bint c_is_key_released(self, int32_t key) noexcept nogil:
        return imgui.IsKeyReleased(<imgui.ImGuiKey>key)

    def is_key_released(self, key, keymod = None) -> bool:
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
        cdef unique_lock[DCGMutex] m
        if key is None or not(is_Key(key)):
            raise TypeError(f"key must be a valid Key, not {key}")
        if keymod is not None and not(is_KeyMod(keymod)):
            raise TypeError(f"keymod must be a valid KeyMod, not {keymod}")
        cdef imgui.ImGuiKey keycode = make_Key(key)
        ensure_correct_im_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        if keymod is not None and (<int>make_KeyMod(keymod) & imgui.GetIO().KeyMods) != keymod:
            return True
        return imgui.IsKeyReleased(keycode)

    cdef bint c_is_mouse_down(self, int32_t button) noexcept nogil:
        return imgui.IsMouseDown(button)

    def is_mouse_down(self, button) -> bool:
        """
        Check if a mouse button is held down.

        Parameters:
        button : MouseButton
            Mouse button constant.

        Returns:
        bool
            True if the mouse button is down, False otherwise.
        """
        cdef unique_lock[DCGMutex] m
        if button is None or not(is_MouseButton(button)):
            raise TypeError(f"button must be a valid MouseButton, not {button}")
        button = make_MouseButton(button)
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_im_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return imgui.IsMouseDown(<int>button)

    cdef bint c_is_mouse_clicked(self, int32_t button, bint repease) noexcept nogil:
        return imgui.IsMouseClicked(button, repease)

    def is_mouse_clicked(self, button, repeat: bool = False) -> bool:
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
        cdef unique_lock[DCGMutex] m
        if button is None or not(is_MouseButton(button)):
            raise TypeError(f"button must be a valid MouseButton, not {button}")
        button = make_MouseButton(button)
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_im_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return imgui.IsMouseClicked(<int>button, repeat)

    def is_mouse_double_clicked(self, button) -> bool:
        """
        Check if a mouse button was double-clicked.

        Parameters:
        button : MouseButton
            Mouse button constant.

        Returns:
        bool
            True if the mouse button was double-clicked, False otherwise.
        """
        cdef unique_lock[DCGMutex] m
        if button is None or not(is_MouseButton(button)):
            raise TypeError(f"button must be a valid MouseButton, not {button}")
        button = make_MouseButton(button)
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_im_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return imgui.IsMouseDoubleClicked(<int>button)

    cdef int32_t c_get_mouse_clicked_count(self, int32_t button) noexcept nogil:
        return imgui.GetMouseClickedCount(button)

    def get_mouse_clicked_count(self, button) -> int:
        """
        Get the number of times a mouse button is clicked in a row.

        Parameters:
        button : MouseButton
            Mouse button constant.

        Returns:
        int
            Number of times the mouse button is clicked in a row.
        """
        cdef unique_lock[DCGMutex] m
        if button is None or not(is_MouseButton(button)):
            raise TypeError(f"button must be a valid MouseButton, not {button}")
        button = make_MouseButton(button)
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_im_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return imgui.GetMouseClickedCount(<int>button)

    cdef bint c_is_mouse_released(self, int32_t button) noexcept nogil:
        return imgui.IsMouseReleased(button)

    def is_mouse_released(self, button) -> bool:
        """
        Check if a mouse button was released (went from Down to !Down).

        Parameters:
        button : MouseButton
            Mouse button constant.

        Returns:
        bool
            True if the mouse button was released, False otherwise.
        """
        cdef unique_lock[DCGMutex] m
        if button is None or not(is_MouseButton(button)):
            raise TypeError(f"button must be a valid MouseButton, not {button}")
        button = make_MouseButton(button)
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_im_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return imgui.IsMouseReleased(<int>button)

    cdef Vec2 c_get_mouse_pos(self) noexcept nogil:
        return ImVec2Vec2(imgui.GetMousePos())

    cdef Vec2 c_get_mouse_prev_pos(self) noexcept nogil:
        cdef imgui.ImGuiIO io = imgui.GetIO()
        return ImVec2Vec2(io.MousePosPrev)

    def get_mouse_position(self) -> Coord:
        """
        Retrieve the mouse position (x, y).

        Returns:
        tuple
            Coord containing the mouse position (x, y).

        Raises:
        KeyError
            If there is no mouse.
        """
        cdef unique_lock[DCGMutex] m
        ensure_correct_im_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        cdef imgui.ImVec2 pos = imgui.GetMousePos()
        if not(imgui.IsMousePosValid(&pos)):
            raise KeyError("Cannot get mouse position: no mouse found")
        cdef double[2] coord = [pos.x, pos.y]
        return Coord.build(coord)

    cdef bint c_is_mouse_dragging(self, int32_t button, float lock_threshold) noexcept nogil:
        return imgui.IsMouseDragging(button, lock_threshold)

    def is_mouse_dragging(self, button, lock_threshold : float = -1.) -> bool:
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
        cdef unique_lock[DCGMutex] m
        if button is None or not(is_MouseButton(button)):
            raise TypeError(f"button must be a valid MouseButton, not {button}")
        button = make_MouseButton(button)
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_im_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return imgui.IsMouseDragging(<int>button, lock_threshold)

    cdef Vec2 c_get_mouse_drag_delta(self, int32_t button, float threshold) noexcept nogil:
        return ImVec2Vec2(imgui.GetMouseDragDelta(button, threshold))

    def get_mouse_drag_delta(self, button, lock_threshold : float = -1.) -> Coord:
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
        cdef unique_lock[DCGMutex] m
        if button is None or not(is_MouseButton(button)):
            raise TypeError(f"button must be a valid MouseButton, not {button}")
        button = make_MouseButton(button)
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_im_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        cdef imgui.ImVec2 delta =  imgui.GetMouseDragDelta(<int>button, lock_threshold)
        cdef double[2] coord = [delta.x, delta.y]
        return Coord.build(coord)

    def reset_mouse_drag_delta(self, button) -> None:
        """
        Reset the drag delta for the target button to 0.

        Parameters:
        button : MouseButton
            Mouse button constant.
        """
        cdef unique_lock[DCGMutex] m
        if button is None or not(is_MouseButton(button)):
            raise TypeError(f"button must be a valid MouseButton, not {button}")
        button = make_MouseButton(button)
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_im_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return imgui.ResetMouseDragDelta(<int>button)

    def inject_key_down(self, key) -> None:
        """
        Inject a key down event for the next frame.

        Parameters:
        key : Key
            Key constant.
        """
        cdef unique_lock[DCGMutex] m
        if key is None or not(is_Key(key)):
            raise TypeError(f"key must be a valid Key, not {key}")
        cdef imgui.ImGuiKey keycode = make_Key(key)
        ensure_correct_im_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        imgui.GetIO().AddKeyEvent(keycode, True)

    def inject_key_up(self, key) -> None:
        """
        Inject a key up event for the next frame.

        Parameters:
        key : Key
            Key constant.
        """
        cdef unique_lock[DCGMutex] m
        if key is None or not(is_Key(key)):
            raise TypeError(f"key must be a valid Key, not {key}")
        cdef imgui.ImGuiKey keycode = make_Key(key)
        ensure_correct_im_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        imgui.GetIO().AddKeyEvent(keycode, False)

    def inject_mouse_down(self, button) -> None:
        """
        Inject a mouse down event for the next frame.

        Parameters:
        button : MouseButton
            Mouse button constant.
        """
        cdef unique_lock[DCGMutex] m
        if button is None or not(is_MouseButton(button)):
            raise TypeError(f"button must be a valid MouseButton, not {button}")
        button = make_MouseButton(button)
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_im_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        imgui.GetIO().AddMouseButtonEvent(<int>button, True)

    def inject_mouse_up(self, button) -> None:
        """
        Inject a mouse up event for the next frame.

        Parameters:
        button : MouseButton
            Mouse button constant.
        """
        cdef unique_lock[DCGMutex] m
        if button is None or not(is_MouseButton(button)):
            raise TypeError(f"button must be a valid MouseButton, not {button}")
        button = make_MouseButton(button)
        if <int>button < 0 or <int>button >= imgui.ImGuiMouseButton_COUNT:
            raise ValueError("Invalid button")
        ensure_correct_im_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        imgui.GetIO().AddMouseButtonEvent(<int>button, False)

    def inject_mouse_wheel(self, wheel_x : float, wheel_y : float) -> None:
        """
        Inject a mouse wheel event for the next frame.

        Parameters:
        wheel_x : float
            Horizontal wheel movement in pixels.
        wheel_y : float
            Vertical wheel movement in pixels.
        """
        cdef unique_lock[DCGMutex] m
        ensure_correct_im_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        imgui.GetIO().AddMouseWheelEvent(wheel_x, wheel_y)

    def inject_mouse_pos(self, x : float, y : float) -> None:
        """
        Inject a mouse position event for the next frame.

        Parameters:
        x : float
            X position of the mouse in pixels.
        y : float
            Y position of the mouse in pixels.
        """
        cdef unique_lock[DCGMutex] m
        ensure_correct_im_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        imgui.GetIO().AddMousePosEvent(x, y)

    @property 
    def running(self):
        """
        Whether the context is currently running and processing frames.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._started

    @running.setter
    def running(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._started = value

    @property
    def clipboard(self):
        """
        Content of the system clipboard.

        The clipboard can be read and written to interact with the system clipboard.

        Reading returns an empty string if the viewport is not yet initialized.
        """
        cdef unique_lock[DCGMutex] m
        if not(self.viewport._initialized):
            return ""
        ensure_correct_im_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        return str(imgui.GetClipboardText())

    @clipboard.setter
    def clipboard(self, str value):
        cdef string value_str = bytes(value, 'utf-8')
        cdef unique_lock[DCGMutex] m
        if not(self.viewport._initialized):
            return
        ensure_correct_im_context(self)
        lock_gil_friendly(m, self.imgui_mutex)
        imgui.SetClipboardText(value_str.c_str())



cdef class baseItem:
    """
    Base class for all items (except shared values).

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

    The parent, previous_sibling and next_sibling relationships form a doubly-linked tree structure that determines rendering order and hierarchy.
    The children attribute provides access to all child items.

    Special Cases:
    -------------
    Some items cannot be children in the rendering tree:
        - PlaceHolderParent: Can be parent to any item but cannot be in rendering tree
        - Textures, themes, colormaps and fonts: Cannot be children but can be bound to items
    """

    def __init__(self, context, **kwargs):
        # Automatic attachment
        cdef bint ignore_if_fail
        cdef bint should_attach
        cdef object attach, before, parent
        cdef bint default_behaviour = True
        # The most common case is neither
        # attach, parent, nor before as set.
        # The code is optimized with this case
        # in mind.
        if self.parent is None:
            ignore_if_fail = False
            # attach = None => default behaviour
            if "attach" in <dict>kwargs:
                attach = (<dict>kwargs).pop("attach")
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
                if "before" in <dict>kwargs:
                    before = (<dict>kwargs).pop("before")
                # For attach and before, which are rarely used,
                # we improve performance by checking before "pop",
                # however parent is more commonly used. Using pop
                # directly skips a call.
                parent = (<dict>kwargs).pop("parent", None)
                if before is not None:
                    # parent manually set. Do not ignore failure
                    ignore_if_fail = False
                    self.attach_before(before)
                else:
                    if parent is None:
                        if not thread_local_parent_empty():
                            parent = thread_local_parent_fetch_back()
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
                        except (ValueError, TypeError) as e:
                            if not(ignore_if_fail):
                                raise(e)
        # Configuring attributes
        for (key, value) in (<dict>kwargs).items():
            setattr(self, key, value)

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

    def configure(self, **kwargs) -> None:
        """
        Shortcut to set multiple attributes at once.
        """
        for (key, value) in (<dict>kwargs).items():
            setattr(self, key, value)

    def __dealloc__(self):
        clear_obj_vector(self._handlers)

    def __reduce__(self) -> tuple:
        """
        Pickle support.
        """
        return (self.__class__, (self.context,), self.__getstate__())

    def __getstate__(self) -> dict:
        """
        Retrieve the item configuration and child tree (Pickle support.)
        """
        result = {}

        blacklist = set([
            "parent", "previous_sibling", "next_sibling",
            "children", "children_types", "item_type",
            "context", "uuid", "mutex", "shareable_value",
            "mutex", "parents_mutex"
        ])

        # items for which we want to avoid setattr
        whitelist = set([
        ])

        pending_test = dict()

        # Retrieve the attributes of the item
        # that are not methods.
        # We use type(self) to ignore attributes of Python subclasses
        for key in dir(type(self)):
            if key in blacklist:
                continue
            if key.startswith("__"):
                continue
            # Ignore attributes of Python subclasses
            if hasattr(type(self), "__dict__"):
                if key in type(self).__dict__:
                    continue
            try:
                value = getattr(self, key)
            except AttributeError:
                continue
            if key in whitelist:
                result[key] = value
                continue
            pending_test[key] = value

        # We try only after retrieving all values
        # as setting some values can impact others
        for key, value in pending_test.items():
            try:
                setattr(self, key, value)
            except (AttributeError, TypeError):
                continue
            result[key] = value

        result["children"] = self.children

        return result

    def __setstate__(self, state) -> None:
        """
        Restore the item configuration and child tree (Pickle support.)
        """
        self.configure(**state)

    @property
    def context(self):
        """
        Context in which the item resides
        """
        return self.context

    @property
    def user_data(self):
        """
        User data of any type.

        To prevent programmer mistakes and improved performance,
        base DearCyGui items do only accept predefined attributes.

        This attribute is meant to be used by the user to attach
        any custom data to the item.

        An alternative for more complex needs is to subclass
        the item and add your own attributes. Subclassed items
        (unless using slots explicitly) do accept any attribute.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._user_data

    @user_data.setter
    def user_data(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._user_data = value

    @property
    def uuid(self):
        """
        Unique identifier created by the context for the item.

        uuid serves as an internal identifier for the item.
        It is not meant to be used as a key for the item, use the
        item directly for that purpose.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return int(self.uuid)

    @property
    def parent(self):
        """
        Parent of the item in the rendering tree.

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
            - Remove the item from the tree, remove all your references.
            If the item has children or siblings, the item will not be
            released until Python's garbage collection detects a
            circular reference.
            - Use delete_item to remove the item from the tree, and remove
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
        cdef unique_lock[DCGMutex] m
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
        Child of the parent rendered just before this item.

        It is not possible to have siblings if you have no parent,
        thus if you intend to attach together items outside the
        rendering tree, there must be a toplevel parent item.

        If you write to this attribute, the item will be moved
        to be inserted just after the target item.
        In case of failure, the item remains in a detached state.

        Note that a parent can have several child queues, and thus
        child elements are not guaranteed to be siblings of each other.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.prev_sibling

    @previous_sibling.setter
    def previous_sibling(self, baseItem target not None):
        cdef unique_lock[DCGMutex] m
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
        else:
            self.attach_before(next_sibling)

    @property
    def next_sibling(self):
        """
        Child of the parent rendered just after this item.

        It is not possible to have siblings if you have no parent,
        thus if you intend to attach together items outside the
        rendering tree, there must be a toplevel parent item.

        If you write to this attribute, the item will be moved
        to be inserted just before the target item.
        In case of failure, the item remains in a detached state.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.next_sibling

    @next_sibling.setter
    def next_sibling(self, baseItem target not None):
        # It is important to not lock the mutex before the call
        self.attach_before(target)

    @property
    def children(self):
        """
        List of all the children of the item, from first rendered, to last rendered.

        When written to, an error is raised if the children already
        have other parents. This error is meant to prevent programming
        mistakes, as users might not realize the children were
        unattached from their former parents.
        """
        cdef unique_lock[DCGMutex] m
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
        if PySequence_Check(value) == 0:
            raise TypeError("children must be a array of child items")
        cdef unique_lock[DCGMutex] item_m
        cdef unique_lock[DCGMutex] child_m
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
        """
        Returns which types of children can be attached to this item
        """
        return get_children_types(
            self.can_have_drawing_child,
            self.can_have_handler_child,
            self.can_have_menubar_child,
            self.can_have_plot_element_child,
            self.can_have_tab_child,
            self.can_have_tag_child,
            self.can_have_theme_child,
            self.can_have_viewport_drawlist_child,
            self.can_have_widget_child,
            self.can_have_window_child
        )

    @property
    def item_type(self):
        """
        Returns which type of child this item is
        """
        return get_item_type(self.element_child_category)

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
            print(f"Warning: {self} cannot have children but is pushed as container")
        self.context.push_next_parent(self)
        return self

    def __exit__(self, exc_type, exc_value, traceback) -> bool:
        self.context.pop_next_parent()
        return False # Do not catch exceptions

    cdef void lock_parent_and_item_mutex(self,
                                         unique_lock[DCGMutex] &parent_m,
                                         unique_lock[DCGMutex] &item_m):
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
                    parent_m = unique_lock[DCGMutex](self.parent.mutex)
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
        Used when the parent needs to prevent any change to its children.

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
        cdef unique_lock[DCGMutex] m
        cdef unique_lock[DCGMutex] m2
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
        Same as item.parent = target, but target must not be None
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

        cdef unique_lock[DCGMutex] m
        cdef unique_lock[DCGMutex] m2
        cdef unique_lock[DCGMutex] m3
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
        Same as item.next_sibling = target, but target must not be None
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

        cdef unique_lock[DCGMutex] m
        cdef unique_lock[DCGMutex] target_before_m
        cdef unique_lock[DCGMutex] target_parent_m
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
        cdef unique_lock[DCGMutex] prev_m
        if prev_sibling is not None:
            lock_gil_friendly(prev_m, prev_sibling.mutex)
            prev_sibling.next_sibling = self
        self.prev_sibling = prev_sibling
        self.next_sibling = target_before
        target_before.prev_sibling = self
        if not(self.parent._check_rendered()):
            self.set_hidden_and_propagate_to_children_no_handlers()

    cdef void _detach_item_and_lock(self, unique_lock[DCGMutex]& m):
        # NOTE: the mutex is not locked if we raise an exception.
        # Detach the item from its parent and siblings
        # We are going to change the tree structure, we must lock
        # the parent mutex first and foremost
        cdef unique_lock[DCGMutex] parent_m
        cdef unique_lock[DCGMutex] sibling_m
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
        cdef unique_lock[DCGMutex] m0
        cdef unique_lock[DCGMutex] m
        self._detach_item_and_lock(m)
        # Mark as hidden. Useful for OtherItemHandler
        # when we want to detect loss of hover, render, etc
        self.set_hidden_and_propagate_to_children_no_handlers()

    cpdef void delete_item(self):
        """
        Deletes the item and all its children.

        When an item is not referenced anywhere, it might
        not get deleted immediately, due to circular references.
        The Python garbage collector will eventually catch
        the circular references, but to speedup the process,
        delete_item will recursively detach the item
        and all elements in its subtree, as well as bound
        items. As a result, items with no more references
        will be freed immediately.
        """
        cdef unique_lock[DCGMutex] sibling_m

        cdef unique_lock[DCGMutex] m
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
        cdef unique_lock[DCGMutex] m
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
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if self.last_window_child is not None:
            (<baseItem>self.last_window_child).set_hidden_and_propagate_to_siblings_with_handlers()
        if self.last_widgets_child is not None:
            (<baseItem>self.last_widgets_child).set_hidden_and_propagate_to_siblings_with_handlers()
        if self.last_tab_child is not None:
            (<baseItem>self.last_tab_child).set_hidden_and_propagate_to_siblings_with_handlers()
        if self.last_menubar_child is not None:
            (<baseItem>self.last_menubar_child).set_hidden_and_propagate_to_siblings_with_handlers()
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
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)

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
        TODO - If item was shown the frame before and is still shown,
          there will be no jump in the item status (for example
          it won't go from rendered, to not rendered, to rendered),
          as the current state will be overwritten when frame is rendered.
        - Possibly undesired effect, but with limited implications:
          when the item states will be read by the user before the frame
          is rendered, it will show the default hidden values.
        - The main reason we are doing this: if the item is not rendered,
          the states are correct (else they would remain as rendered forever),
          and thus we can have handlers attached to other items using
          OtherItemHandler to catch this item being not rendered. This is
          required for instance for items that should destroy when
          an item is not rendered anymore. 
        """
        cdef unique_lock[DCGMutex] m
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
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)

        # Skip propagating and handlers if already hidden.
        if self.p_state == NULL or \
            self.p_state.cur.rendered:
            self.update_current_state_as_hidden()
            self.propagate_hidden_state_to_children_with_handlers()

    @cython.final
    cdef void set_hidden_and_propagate_to_children_no_handlers(self) noexcept:
        """
        See set_hidden_and_propagate_to_siblings_no_handlers.

        Assumes the lock is already held.
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
            - Other threads from reading/writing
            attributes or calling methods with this item,
            editing the children/parent of the item
            - Any rendering of this item and its children.
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
            - wait (default = False): if locking the mutex fails (mutex
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
            - Other threads from reading/writing
            attributes or calling methods with this item,
            editing the children/parent of the item
            - Any rendering of this item and its children.
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
        """
        Context manager instance for the item mutex and all its parents
        
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
    def __enter__(self) -> None:
        self.target.lock_mutex(wait=True)
    def __exit__(self, exc_type, exc_value, traceback) -> bool:
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


cdef extern from "SDL3/SDL_error.h" nogil:
    bint SDL_ClearError()
    const char *SDL_GetError()


cdef extern from "SDL3/SDL_video.h" nogil:
    ctypedef uint32_t SDL_DisplayID
    
    SDL_DisplayID SDL_GetPrimaryDisplay()
    SDL_DisplayID* SDL_GetDisplays(int *count)
    const char* SDL_GetDisplayName(SDL_DisplayID displayID)
    bint SDL_GetDisplayBounds(SDL_DisplayID displayID, SDL_Rect *rect)
    bint SDL_GetDisplayUsableBounds(SDL_DisplayID displayID, SDL_Rect *rect)
    float SDL_GetDisplayContentScale(SDL_DisplayID displayID)
    SDL_DisplayOrientation SDL_GetCurrentDisplayOrientation(SDL_DisplayID displayID)
    void SDL_free(void* mem)
    struct SDL_Window:
        pass
    SDL_DisplayID SDL_GetDisplayForWindow(SDL_Window *window)
    
    struct SDL_Rect:
        int x, y
        int w, h
        
    enum SDL_DisplayOrientation:
        SDL_ORIENTATION_UNKNOWN,
        SDL_ORIENTATION_LANDSCAPE,
        SDL_ORIENTATION_LANDSCAPE_FLIPPED,
        SDL_ORIENTATION_PORTRAIT,
        SDL_ORIENTATION_PORTRAIT_FLIPPED

cdef void _raise_sdl_error() noexcept:
    """
    Raise an error if there is one.
    """
    cdef const char* error = SDL_GetError()
    cdef str error_str = str(error, encoding='utf-8') if error is not NULL else ''
    SDL_ClearError()  # Clear the error
    raise RuntimeError(error_str)


cdef class ViewportMetrics:
    """
    Provides detailed rendering metrics for viewport performance analysis.
    
    This class exposes timing and rendering statistics for the viewport's frame lifecycle.
    All timing values are based on the monotonic clock for consistent measurements.
    """
    cdef int64_t last_time_before_event_handling
    cdef int64_t last_time_before_rendering
    cdef int64_t last_time_after_rendering
    cdef int64_t last_time_after_swapping
    cdef int64_t delta_event_handling
    cdef int64_t delta_rendering
    cdef int64_t delta_presenting
    cdef int64_t delta_whole_frame
    cdef int64_t rendered_vertices
    cdef int64_t rendered_indices
    cdef int64_t rendered_windows
    cdef int64_t active_windows
    cdef int64_t frame_count
    
    def __cinit__(self, 
                  int64_t last_time_before_event_handling,
                  int64_t last_time_before_rendering,
                  int64_t last_time_after_rendering,
                  int64_t last_time_after_swapping,
                  int64_t delta_event_handling,
                  int64_t delta_rendering,
                  int64_t delta_presenting,
                  int64_t delta_whole_frame,
                  int64_t rendered_vertices,
                  int64_t rendered_indices,
                  int64_t rendered_windows,
                  int64_t active_windows,
                  int64_t frame_count):
        self.last_time_before_event_handling = last_time_before_event_handling
        self.last_time_before_rendering = last_time_before_rendering
        self.last_time_after_rendering = last_time_after_rendering
        self.last_time_after_swapping = last_time_after_swapping
        self.delta_event_handling = delta_event_handling
        self.delta_rendering = delta_rendering
        self.delta_presenting = delta_presenting
        self.delta_whole_frame = delta_whole_frame
        self.rendered_vertices = rendered_vertices
        self.rendered_indices = rendered_indices
        self.rendered_windows = rendered_windows
        self.active_windows = active_windows
        self.frame_count = frame_count
        
    @property
    def last_time_before_event_handling(self) -> float:
        """
        Timestamp (s) when event handling started for the current frame.
        
        This marks the beginning of the frame lifecycle, before any input events 
        are processed. Useful for measuring total frame time or comparing with
        external event timings.
        """
        return (<double>self.last_time_before_event_handling) * 1e-9
        
    @property
    def last_time_before_rendering(self) -> float:
        """
        Timestamp (s) when UI rendering started for the current frame.
        
        This marks when the system finished processing events and began the
        rendering phase. The difference between this and last_time_before_event_handling
        indicates how much time was spent processing input.
        """
        return (<double>self.last_time_before_rendering) * 1e-9
        
    @property
    def last_time_after_rendering(self) -> float:
        """
        Timestamp (s) when UI rendering finished for the current frame.
        
        This marks when all drawing commands were submitted to ImGui/ImPlot and
        CPU-side rendering work was completed. The GPU may still be processing
        these commands at this point.
        """
        return (<double>self.last_time_after_rendering) * 1e-9
        
    @property
    def last_time_after_swapping(self) -> float:
        """
        Timestamp (s) when the frame was completely presented to the screen.
        
        This marks the end of the frame lifecycle, after the backbuffer has been
        swapped with the frontbuffer and presented to the display. If vsync is
        enabled, this includes any time spent waiting for the display refresh.
        """
        return (<double>self.last_time_after_swapping) * 1e-9
        
    @property
    def delta_event_handling(self) -> float:
        """
        Time (seconds) spent processing input events for the current frame.
        
        This measures how long the system spent handling mouse, keyboard, and
        other input events. High values might indicate complex event processing
        or delays from input devices.

        This time may differ from the time between
        last_time_before_event_handling and last_time_before_rendering,
        if event processing is being run when the metrics were collected.
        """
        return (<double>self.delta_event_handling) * 1e-9
        
    @property
    def delta_rendering(self) -> float:
        """
        Time (seconds) spent on CPU rendering work for the current frame.
        
        This measures how long it took to traverse the UI hierarchy, compute layouts,
        and generate the render commands for ImGui/ImPlot. High values might indicate
        complex UI structures or inefficient layout calculations.

        This time may differ from the time between
        last_time_before_rendering and last_time_after_rendering,
        if rendering is being run when the metrics were collected.
        """
        return (<double>self.delta_rendering) * 1e-9
        
    @property
    def delta_presenting(self) -> float:
        """
        Time (seconds) spent presenting the frame to the display.
        
        This includes the time to submit draw commands to the GPU, wait for them
        to complete, and swap the buffers. With vsync enabled, this will include
        time waiting for the monitor refresh, which can artificially inflate the value.

        This time may differ from the time between
        last_time_after_rendering and last_time_after_swapping,
        if presenting is being run when the metrics were collected.
        """
        return (<double>self.delta_presenting) * 1e-9
        
    @property
    def delta_whole_frame(self) -> float:
        """
        Total time (seconds) for the complete frame lifecycle.
        
        This measures the time from the end of the processing of the last frame
        to its previous one. It represents the total frame time and is the inverse
        of the effective frame rate (1.0/delta_whole_frame = FPS).

        This time may differ from the time between
        last_time_before_event_handling and last_time_after_swapping,
        if frame processing is being run when the metrics were collected.
        In addition it will be larger than the sum of
        delta_event_handling, delta_rendering, and delta_presenting,
        as it includes any additional time spent executing user code
        between render_frame calls.
        """
        return (<double>self.delta_whole_frame) * 1e-9
        
    @property
    def rendered_vertices(self) -> int:
        """
        Number of vertices rendered in the current frame.
        
        This count represents the total geometry complexity of the UI. Higher numbers
        indicate more complex visuals which may impact GPU performance.
        """
        return self.rendered_vertices
        
    @property
    def rendered_indices(self) -> int:
        """
        Number of indices rendered in the current frame.
        
        This count relates to how many triangles were drawn. Like vertex count,
        this is an indicator of visual complexity and potential GPU load.
        """
        return self.rendered_indices
        
    @property
    def rendered_windows(self) -> int:
        """
        Number of windows rendered in the current frame.
        
        This counts all ImGui windows that were visible and rendered. Windows that
        are hidden, collapsed, or clipped don't contribute to this count.
        """
        return self.rendered_windows
        
    @property
    def active_windows(self) -> int:
        """
        Number of active windows in the current frame.
        
        This counts windows that are processing updates, even if not visually rendered.
        The difference between this and rendered_windows can indicate hidden but
        still processing windows.
        """
        return self.active_windows
        
    @property
    def frame_count(self) -> float:
        """
        Counter indicating which frame these metrics belong to.
        
        This monotonically increasing value allows tracking metrics across multiple
        frames and correlating with other frame-specific data.
        """
        return self.frame_count

@cython.final
@cython.no_gc_clear
cdef class Viewport(baseItem):
    """
    The viewport corresponds to the main item containing all the visuals.

    It is decorated by the operating system and can be minimized/maximized/made fullscreen.
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
        self.always_submit_to_gpu = False
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
        cdef unique_lock[DCGMutex] m
        cdef unique_lock[DCGMutex] m2
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self._mutex_backend) # To not release while we render a frame
        if self._platform != NULL:
            ensure_correct_im_context(self.context)
            # Maybe just a warning ? Not sure how to solve this issue.
            #if not (<platformViewport*>self._platform).checkPrimaryThread():
            #    raise RuntimeError("Viewport deallocated from a different thread than the one it was created in")
            (<platformViewport*>self._platform).cleanup()
            self._platform = NULL

    def initialize(self, **kwargs) -> None:
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
        cdef unique_lock[DCGMutex] m
        cdef unique_lock[DCGMutex] m2
        cdef unique_lock[DCGMutex] m3
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
        ensure_correct_im_context(self.context)
        if not(self._initialized):
            raise RuntimeError("The viewport must be initialized before being used")

    cdef void __check_not_initialized(self):
        ensure_correct_im_context(self.context)
        if self._initialized:
            raise RuntimeError("The viewport must be not be initialized to set this field")

    @property
    def clear_color(self):
        """
        Color used to clear the viewport background.
        
        This RGBA color is applied to the entire viewport before any rendering takes
        place. Setting an appropriate clear color helps establish the visual
        foundation for your application and improves contrast with UI elements.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return ((<platformViewport*>self._platform).clearColor[0],
                (<platformViewport*>self._platform).clearColor[1],
                (<platformViewport*>self._platform).clearColor[2],
                (<platformViewport*>self._platform).clearColor[3])

    @clear_color.setter
    def clear_color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef uint32_t color = parse_color(value)
        if color & 0xFF000000 != 0xFF000000:
            if self._initialized and not((<platformViewport*>self._platform).isTransparent):
                raise ValueError("Transparency requires setting transparent before init")
            (<platformViewport*>self._platform).isTransparent = True
        unparse_color((<platformViewport*>self._platform).clearColor, color)

    @property
    def icon(self):
        """
        Set the window icon from one or more images.
        
        The property accepts a single image or a sequence of images with different sizes.
        Each image should be a 3D array with shape (height, width, 4) representing RGBA data.
        The OS will automatically select the most appropriate size for different contexts
        (window decoration, taskbar, alt-tab switcher, etc).
        
        This property can only be set before the window is initialized,
        and cannot be retrieved once set. The icon data is not stored
        in the viewport object, but passed directly to the platform backend.
        
        Accepts:
        - A single array-like image with RGBA data (height, width, 4)
        - A sequence of array-like images with RGBA data
        """
        # Cannot return the icon data once set
        return None  

    @icon.setter
    def icon(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        
        if value is None:
            return
        
        # Check if window is already initialized
        self.__check_not_initialized()
        
        # Handle single image case vs sequence of images
        cdef list icon_list = []
        if isinstance(value, (list, tuple)):
            icon_list = list(value)
        else:
            icon_list = [value]
            
        if not icon_list:
            return
        
        # Process each icon one by one
        cdef Py_buffer buf_info

        for img in icon_list:
            # Initialize buffer info
            memset(&buf_info, 0, sizeof(Py_buffer))
            
            # Parse the texture data if needed
            if not PyObject_CheckBuffer(img):
                img = parse_texture(img)
            
            try:
                # Get buffer info
                if PyObject_GetBuffer(img, &buf_info, PyBUF_RECORDS_RO) < 0:
                    raise TypeError("Failed to retrieve buffer information for icon")
                    
                # Validate dimensions
                if buf_info.ndim != 3:
                    raise ValueError("Icon must be a 3D array (height, width, channels)")

                if buf_info.format[0] != b'B':
                    raise ValueError("Invalid texture format. Must be uint8[0-255]")
                    
                height = buf_info.shape[0]
                width = buf_info.shape[1]

                if height <= 0 or width <= 0:
                    raise ValueError("Icon dimensions must be positive")
                
                if buf_info.shape[2] != 4:
                    raise ValueError("Icon must have 4 channels (RGBA)")
                    
                # Set strides
                row_stride = buf_info.strides[0]
                col_stride = buf_info.strides[1]
                chan_stride = buf_info.strides[2]
                
                # Call the backend to add this icon
                (<platformViewport*>self._platform).addWindowIcon(
                    buf_info.buf, width, height,
                    row_stride, col_stride, chan_stride
                )

            finally:
                # Free buffer resources
                if buf_info.buf != NULL:
                    PyBuffer_Release(&buf_info)

    @property
    def hit_test_surface(self):
        """
        Define custom window hit regions for borderless windows using a 2D array.
        
        This property accepts a 2D numpy array or array-like object of uint8 values
        that defines how mouse interactions behave across different regions of the window.
        This is particularly useful for creating custom window borders when window.decorated=False.
        
        The values in the array determine how each region responds to mouse interactions:
        - 0: Normal region (default behavior, passes clicks through)
        - 1: Top resize border
        - 2: Left resize border
        - 3: Top-left resize corner
        - 4: Bottom resize border
        - 6: Bottom-left resize corner
        - 8: Right resize border
        - 9: Top-right resize corner
        - 12: Bottom-right resize corner
        - 15: Draggable region (window can be moved by dragging)
        
        The array is extended to cover the entire window area, where the extension
        is performed at the center of the window, not at the edges. Thus you only
        need to define the behaviour for the border regions, for which a small
        surface is enough. There is no need to send a new surface if the viewport
        is resized but the custom decorations remain the same.
        
        Args:
            value: A 2D array of uint8 values defining window regions
            
        Returns:
            None: Cannot retrieve the current hit test surface data

        Setting this attribute will raise an exception if the OS does
        not support custom hit test surfaces. All currently supported
        platforms (Windows, macOS, Linux) support this feature.

        Example:
            # Create a resizable borderless window with no draggable area
            border_width = 5
            hit_test = np.zeros((2 * border_width + 1, 
                                 2 * border_width + 1), dtype=np.uint8)
            for i in range(hit_test.shape[0]):
                for j in range(hit_test.shape[1]):
                    if i < border_width:  # Top border
                        hit_test[i, j] |= 1
                    elif i >= hit_test.shape[0] - border_width:  # Bottom border
                        hit_test[i, j] |= 4
                    if j < border_width:  # Left border
                        hit_test[i, j] |= 2
                    elif j >= hit_test.shape[1] - border_width:  # Right border
                        hit_test[i, j] |= 8

            viewport.decorated = False
            viewport.hit_test_surface = hit_test
        """
        # Cannot return the surface data once set
        return None
    
    @hit_test_surface.setter
    def hit_test_surface(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)

        if value is None:
            # Clear the hit test surface
            (<platformViewport*>self._platform).setHitTestSurface(<uint8_t*>NULL, 0, 0)
            return

        # Get buffer info
        cdef Py_buffer buf_info
        memset(&buf_info, 0, sizeof(Py_buffer))

        # Parse the data if needed (ensure it's compatible with buffer protocol)
        if not PyObject_CheckBuffer(value):
            raise TypeError("hit_test_surface must support the buffer protocol")

        try:
            # Get buffer info
            if PyObject_GetBuffer(value, &buf_info, PyBUF_RECORDS_RO | PyBUF_CONTIG_RO) < 0:
                raise TypeError("Failed to retrieve contiguous buffer for hit test surface")
            
            # Validate dimensions
            if buf_info.ndim != 2:
                raise ValueError("Hit test surface must be a 2D array")
            
            if buf_info.format[0] != b'B' and buf_info.format[0] != b'b':
                raise ValueError("Hit test surface must contain uint8 values (0-15)")
            
            height = buf_info.shape[0]
            width = buf_info.shape[1]

            if height <= 0 or width <= 0:
                raise ValueError("Hit test surface dimensions must be positive")

            # Call the backend to set the hit test surface
            (<platformViewport*>self._platform).setHitTestSurface(
                <uint8_t*>buf_info.buf, 
                width, 
                height
            )

        finally:
            # Free buffer resources
            if buf_info.buf != NULL:
                PyBuffer_Release(&buf_info)

    @property
    def transparent(self):
        """
        Whether the window is created with a back buffer allowing for transparent windows

        This attribute must be set before or during initialize()
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).isTransparent

    @transparent.setter
    def transparent(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if (<platformViewport*>self._platform).isTransparent == value:
            return
        self.__check_not_initialized()
        (<platformViewport*>self._platform).isTransparent = value

    @property
    def x_pos(self):
        """
        X position of the viewport window on the screen.
        
        Represents the horizontal position of the top-left corner of the viewport
        window in screen coordinates. This position is relative to the primary
        monitor's origin and may include OS-specific decorations.

        Note: Not all platforms support setting the X position of the window.
        In which case, this property may be ignored.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).positionX

    @x_pos.setter
    def x_pos(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value == (<platformViewport*>self._platform).positionX:
            return
        (<platformViewport*>self._platform).positionX = value
        (<platformViewport*>self._platform).positionChangeRequested = True

    @property
    def y_pos(self):
        """
        Y position of the viewport window on the screen.
        
        Represents the vertical position of the top-left corner of the viewport
        window in screen coordinates. This position is relative to the primary
        monitor's origin and may include OS-specific decorations.

        Note: Not all platforms support setting the Y position of the window.
        In which case, this property may be ignored.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).positionY

    @y_pos.setter
    def y_pos(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value == (<platformViewport*>self._platform).positionY:
            return
        (<platformViewport*>self._platform).positionY = value
        (<platformViewport*>self._platform).positionChangeRequested = True

    @property
    def display(self) -> Display:
        """
        Get information about the current display for the window
        """
        cdef unique_lock[DCGMutex] self_m
        lock_gil_friendly(self_m, self.mutex)
        self.__check_initialized()
        if not (<platformViewport*>self._platform).checkPrimaryThread():
            raise RuntimeError("displays must be retrieved from the thread where the context was created")
        cdef list displays = self.displays
        cdef SDL_DisplayID display_id = SDL_GetDisplayForWindow(<SDL_Window*>self.get_platform_window())
        cdef Display display
        for display in displays:
            if display._id == display_id:
                return display
        raise RuntimeError(f"Display with ID {display_id} not found in available displays")

    @property
    def displays(self) -> list[Display]:
        """
        Get information about available displays.
        
        Returns:
            A list of Display objects, each containing:
            - id: The display ID
            - name: The display name
            - bounds: Rect object with display bounds (x1,y1,x2,y2)
            - usable_bounds: Rect object with usable display bounds
            (accounting for taskbars, docks, etc.)
            - content_scale: The content scale factor of the display (DPI scaling)
            - is_primary: True if this is the primary display
            - orientation: The current orientation of the display
        
        Raises:
            RuntimeError: If there was an error retrieving display information
        """
        cdef unique_lock[DCGMutex] self_m
        lock_gil_friendly(self_m, self.mutex)
        self.__check_initialized()
        if not (<platformViewport*>self._platform).checkPrimaryThread():
            raise RuntimeError("displays must be retrieved from the thread where the context was created")

        cdef int i, count = 0
        cdef SDL_DisplayID* displays = SDL_GetDisplays(&count)
        
        if displays == NULL:
            _raise_sdl_error()

        cdef SDL_DisplayID primary_display = SDL_GetPrimaryDisplay()
        cdef SDL_Rect bounds_rect
        cdef SDL_Rect usable_bounds_rect
        cdef SDL_DisplayOrientation orientation
        cdef const char* display_name
        cdef float scale
        cdef double[4] bounds_array
        cdef double[4] usable_bounds_array
        
        result = []
        
        try:
            for i in range(count):
                display_id = displays[i]
                
                # Get display name
                display_name = SDL_GetDisplayName(display_id)
                if display_name == NULL:
                    name = ""
                else:
                    name = str(<bytes>display_name, encoding='utf-8')
                
                # Get display bounds
                if not SDL_GetDisplayBounds(display_id, &bounds_rect):
                    _raise_sdl_error()
                    
                # Convert to Rect (using x1,y1,x2,y2 format)
                bounds_array[0] = bounds_rect.x
                bounds_array[1] = bounds_rect.y
                bounds_array[2] = bounds_rect.x + bounds_rect.w
                bounds_array[3] = bounds_rect.y + bounds_rect.h            
                # Get usable bounds
                if not SDL_GetDisplayUsableBounds(display_id, &usable_bounds_rect):
                    _raise_sdl_error()
                    
                # Convert to Rect
                usable_bounds_array[0] = usable_bounds_rect.x
                usable_bounds_array[1] = usable_bounds_rect.y
                usable_bounds_array[2] = usable_bounds_rect.x + usable_bounds_rect.w
                usable_bounds_array[3] = usable_bounds_rect.y + usable_bounds_rect.h
                
                # Get content scale
                scale = SDL_GetDisplayContentScale(display_id)
                if scale <= 0.0:
                    _raise_sdl_error()
                
                # Get orientation
                orientation = SDL_GetCurrentDisplayOrientation(display_id)
                orientation_str = {
                    SDL_ORIENTATION_UNKNOWN: "unknown",
                    SDL_ORIENTATION_LANDSCAPE: "landscape",
                    SDL_ORIENTATION_LANDSCAPE_FLIPPED: "landscape_flipped",
                    SDL_ORIENTATION_PORTRAIT: "portrait",
                    SDL_ORIENTATION_PORTRAIT_FLIPPED: "portrait_flipped"
                }.get(orientation, "unknown")
                
                # Create and add a Display object
                display_obj = Display.build(
                    display_id,
                    name,
                    scale,
                    display_id == primary_display,
                    orientation_str,
                    bounds_array,
                    usable_bounds_array,
                )
                
                result.append(display_obj)
        finally:
            SDL_free(displays)
        
        return result

    @property
    def width(self):
        """
        DPI invariant width of the viewport window.
        
        Represents the logical width of the viewport in DPI-independent units.
        The actual pixel width may differ based on the DPI scaling factor of the
        display. Use this value when you want consistent sizing across different
        display configurations.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).windowWidth

    @width.setter
    def width(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float dpi_scale = (<platformViewport*>self._platform).dpiScale
        (<platformViewport*>self._platform).windowWidth = value
        (<platformViewport*>self._platform).frameWidth = <int>(<float>value * dpi_scale)
        (<platformViewport*>self._platform).sizeChangeRequested = True

    @property
    def height(self):
        """
        DPI invariant height of the viewport window.
        
        Represents the logical height of the viewport in DPI-independent units.
        The actual pixel height may differ based on the DPI scaling factor of the
        display. Use this value when you want consistent sizing across different
        display configurations.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).windowHeight

    @height.setter
    def height(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float dpi_scale = (<platformViewport*>self._platform).dpiScale
        (<platformViewport*>self._platform).windowHeight = value
        (<platformViewport*>self._platform).frameHeight = <int>(<float>value * dpi_scale)
        (<platformViewport*>self._platform).sizeChangeRequested = True

    @property
    def pixel_width(self):
        """
        Actual width of the viewport in pixels.
        
        This is the true width in device pixels after applying DPI scaling. When
        rendering custom graphics or calculating exact screen positions, use this
        value rather than the logical width.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).frameWidth

    @pixel_width.setter
    def pixel_width(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float dpi_scale = (<platformViewport*>self._platform).dpiScale
        (<platformViewport*>self._platform).windowWidth = <int>(<float>value / dpi_scale)
        (<platformViewport*>self._platform).frameWidth = value
        (<platformViewport*>self._platform).sizeChangeRequested = True

    @property
    def pixel_height(self):
        """
        Actual height of the viewport in pixels.
        
        This is the true height in device pixels after applying DPI scaling. When
        rendering custom graphics or calculating exact screen positions, use this
        value rather than the logical height.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).frameHeight

    @pixel_height.setter
    def pixel_height(self, int32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float dpi_scale = (<platformViewport*>self._platform).dpiScale
        (<platformViewport*>self._platform).windowHeight = <int>(<float>value / dpi_scale)
        (<platformViewport*>self._platform).frameHeight = value
        (<platformViewport*>self._platform).sizeChangeRequested = True

    @property
    def resizable(self) -> bool:
        """
        Whether the viewport window can be resized by the user.
        
        When enabled, the user can resize the window by dragging its edges or
        corners. When disabled, the window size remains fixed and can only be 
        changed programmatically through the width and height properties.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).windowResizable

    @resizable.setter
    def resizable(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        (<platformViewport*>self._platform).windowResizable = value
        (<platformViewport*>self._platform).windowPropertyChangeRequested = True

    @property
    def vsync(self) -> bool:
        """
        Whether vertical synchronization is enabled.
        
        When enabled, frame rendering synchronizes with the display refresh rate
        to eliminate screen tearing. This provides smoother visuals but may limit
        the maximum frame rate to the display's refresh rate. Disabling vsync can
        increase responsiveness at the cost of potential visual artifacts.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).hasVSync

    @vsync.setter
    def vsync(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        (<platformViewport*>self._platform).hasVSync = value

    @property
    def dpi(self) -> float:
        """
        Requested scaling (DPI) from the OS for this window.
        
        This value represents the display scaling factor for the current monitor.
        It's used to automatically scale UI elements for readability across
        different screen densities. The value is valid after initialization and
        may change if the window moves to another monitor with different DPI.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).dpiScale

    @property
    def scale(self) -> float:
        """
        Multiplicative scale applied on top of the system DPI scaling.
        
        This user-defined scaling factor is combined with the system DPI to
        determine the final size of UI elements. Increasing this value makes
        all UI elements appear larger, which can improve readability or
        accommodate specific usability needs.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._scale

    @scale.setter
    def scale(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._scale = value

    @property
    def min_width(self):
        """
        Minimum width the viewport window can be resized to.
        
        This sets a lower bound on the window width when the window is resizable.
        The user will not be able to resize the window smaller than this value
        horizontally. This helps ensure your interface remains usable at smaller
        sizes.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).minWidth

    @min_width.setter
    def min_width(self, uint32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        (<platformViewport*>self._platform).minWidth = value
        (<platformViewport*>self._platform).sizeChangeRequested = True

    @property
    def max_width(self):
        """
        Maximum width the viewport window can be resized to.
        
        This sets an upper bound on the window width when the window is resizable.
        The user will not be able to resize the window larger than this value
        horizontally. This can be useful to prevent the window from becoming
        impractically large.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).maxWidth

    @max_width.setter
    def max_width(self, uint32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        (<platformViewport*>self._platform).maxWidth = value
        (<platformViewport*>self._platform).sizeChangeRequested = True

    @property
    def min_height(self):
        """
        Minimum height the viewport window can be resized to.
        
        This sets a lower bound on the window height when the window is resizable.
        The user will not be able to resize the window smaller than this value
        vertically. This helps ensure your interface remains usable at smaller
        sizes.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).minHeight

    @min_height.setter
    def min_height(self, uint32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        (<platformViewport*>self._platform).minHeight = value
        (<platformViewport*>self._platform).sizeChangeRequested = True

    @property
    def max_height(self):
        """
        Maximum height the viewport window can be resized to.
        
        This sets an upper bound on the window height when the window is resizable.
        The user will not be able to resize the window larger than this value
        vertically. This can be useful to prevent the window from becoming
        impractically large.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).maxHeight

    @max_height.setter
    def max_height(self, uint32_t value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        (<platformViewport*>self._platform).maxHeight = value
        (<platformViewport*>self._platform).sizeChangeRequested = True

    @property
    def always_on_top(self) -> bool:
        """
        Whether the viewport window stays above other windows.
        
        When enabled, the viewport window will remain visible on top of other
        application windows even when it doesn't have focus. This is useful for
        tool palettes, monitoring displays, or any window that needs to remain
        visible while the user interacts with other applications.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).windowAlwaysOnTop

    @always_on_top.setter
    def always_on_top(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        (<platformViewport*>self._platform).windowAlwaysOnTop = value
        (<platformViewport*>self._platform).windowPropertyChangeRequested = True

    @property
    def decorated(self) -> bool:
        """
        Whether the viewport window shows OS-provided decorations.
        
        When enabled, the window includes standard OS decorations such as title bar,
        borders, and window control buttons. When disabled, the window appears as a
        plain rectangle without these decorations, which is useful for custom UI
        designs that implement their own window controls.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).windowDecorated

    @decorated.setter
    def decorated(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        (<platformViewport*>self._platform).windowDecorated = value
        (<platformViewport*>self._platform).windowPropertyChangeRequested = True

    @property
    def handlers(self):
        """
        Event handlers attached to the viewport.
        
        Handlers allow responding to keyboard and mouse events at the viewport
        level, regardless of which specific UI element has focus. Only Key and
        Mouse handlers are compatible with the viewport; handlers that check item
        states won't work at this level.
        """
        cdef unique_lock[DCGMutex] m
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
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list items = []
        cdef int32_t i
        if value is None:
            clear_obj_vector(self._handlers)
            return
        if PySequence_Check(value) == 0:
            value = (value,)
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
        Current mouse cursor appearance.
        
        Controls which cursor shape is displayed when the mouse is over the viewport.
        The cursor is reset to the default arrow at the beginning of each frame,
        so this property must be set each frame to maintain a consistent non-default
        cursor appearance.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return make_MouseCursor(self._cursor)

    @cursor.setter
    def cursor(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None or not(is_MouseCursor(value)):
            raise TypeError("Cursor must be a MouseCursor type")
        value = make_MouseCursor(value)
        if <int32_t>value < imgui.ImGuiMouseCursor_None or \
           <int32_t>value >= imgui.ImGuiMouseCursor_COUNT:
            raise ValueError("Invalid cursor type {value}")
        self._cursor = <int32_t>value

    @property
    def font(self):
        """
        Global font applied to all text within the viewport.
        
        Sets the default font used for rendering text throughout the application.
        Individual UI elements can override this by setting their own font
        property. The font is automatically scaled according to the viewport's
        DPI and scale settings.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._font

    @font.setter
    def font(self, baseFont value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._font = value

    @property
    def theme(self):
        """
        Global theme applied to all elements within the viewport.
        
        Sets the default visual style for all UI elements in the application.
        Individual UI elements can override this by setting their own theme
        property. The theme controls colors, spacing, and other appearance
        aspects of the interface.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._theme

    @theme.setter
    def theme(self, baseTheme value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._theme = value

    @property
    def title(self):
        """
        Text displayed in the viewport window's title bar.
        
        Sets the title text shown in the window decoration and in OS task
        switchers. This property has no effect if the window is undecorated
        or if the title bar is hidden.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef string title = (<platformViewport*>self._platform).windowTitle
        return str(title, "utf-8")

    @title.setter
    def title(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef string title = value.encode("utf-8")
        (<platformViewport*>self._platform).windowTitle = title
        (<platformViewport*>self._platform).titleChangeRequested = True

    @property
    def disable_close(self) -> bool:
        """
        Whether window close operations are blocked.
        
        When enabled, the viewport ignores close requests triggered by clicking
        the window's close button or by other OS-specific close mechanisms.
        The window can still be closed programmatically. This is useful for
        applications that need to perform cleanup or prompt for confirmation
        before closing.

        Note: This property does not affect the close callback; it only
        prevents the window from being closed through standard OS interactions.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._disable_close

    @disable_close.setter
    def disable_close(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._disable_close = value

    @property
    def fullscreen(self):
        """
        Whether the viewport is currently in fullscreen mode.
        
        When in fullscreen mode, the window occupies the entire screen area
        without decorations. This is useful for immersive applications or
        presentations. Setting this property toggles between windowed and
        fullscreen modes.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).isFullScreen

    @fullscreen.setter
    def fullscreen(self, bint value):
        cdef unique_lock[DCGMutex] m
        cdef unique_lock[DCGMutex] m2
        cdef unique_lock[DCGMutex] m3
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
        """
        Whether the viewport is currently minimized.
        
        When minimized, the window is hidden from view and typically appears as an
        icon in the taskbar or dock. Setting this property to True minimizes the
        window, while setting it to False when minimized restores the window to
        its previous size and position.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).isMinimized

    @minimized.setter
    def minimized(self, bint value):
        cdef unique_lock[DCGMutex] m
        cdef unique_lock[DCGMutex] m2
        cdef unique_lock[DCGMutex] m3
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
        """
        Whether the viewport is currently maximized.
        
        When maximized, the window occupies the maximum available space on the
        screen while still preserving its decorations. Setting this property to
        True maximizes the window, while setting it to False when maximized
        restores the window to its previous size and position.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).isMaximized

    @maximized.setter
    def maximized(self, bint value):
        cdef unique_lock[DCGMutex] m
        cdef unique_lock[DCGMutex] m2
        cdef unique_lock[DCGMutex] m3
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
        """
        State to control whether the viewport is associated to a window.

        If False, no window will be displayed for the viewport (offscreen rendering).
        Defaults to True.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (<platformViewport*>self._platform).isVisible

    @visible.setter
    def visible(self, bint value):
        cdef unique_lock[DCGMutex] m
        cdef unique_lock[DCGMutex] m2
        cdef unique_lock[DCGMutex] m3
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self.mutex)
        lock_gil_friendly(m3, self._mutex_backend)
        ensure_correct_im_context(self.context)
        if value and not((<platformViewport*>self._platform).isVisible):
            (<platformViewport*>self._platform).shouldShow = True
        elif not value and (<platformViewport*>self._platform).isVisible:
            (<platformViewport*>self._platform).shouldHide = True

    @property
    def wait_for_input(self):
        """
        Stop refreshing when no mouse/keyboard event is detected.

        When this state is set, render_frame will block until
        a mouse or keyboard event is detected.

        It is possible to manually unblock render_frame by
        calling wake().

        In addition to mouse and keyboard events, many internal
        events also trigger a refresh. For instance DrawStream
        will trigger a refresh when it is time to draw the next
        element of the stream, or Tooltip will trigger a refresh
        after the requested delay without mouse movement.

        The goal is that any DearCyGui item handles viewport
        waking automatically themselves. This way, the user
        only needs to call wake() when he has appended new items,
        modified visual item properties or when he wants to.
        wake() is not called for the user for such operations
        because the idea is for the user to call wake() after a
        batch of operations.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.wait_for_input

    @wait_for_input.setter
    def wait_for_input(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.wait_for_input = value

    @property
    def always_submit_to_gpu(self):
        """
        By default DearCyGui attemps to skip submitting to the GPU
        frames when no change have been detected during the CPU preparation
        of the frame.

        However some cases may be missed. This state is available in order to
        have a fallback in case issues are met.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.always_submit_to_gpu

    @always_submit_to_gpu.setter
    def always_submit_to_gpu(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.always_submit_to_gpu = value

    @property
    def shown(self) -> bool:
        """
        Whether the viewport window has been created by the operating system.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._initialized

    @property
    def resize_callback(self):
        """
        Callback to be issued when the viewport is resized.

        The callback takes as input (sender, target, data), where
        data is a tuple containing:
            - The width in pixels
            - The height in pixels
            - The width according to the OS (OS dependent)
            - The height according to the OS (OS dependent)
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._resize_callback

    @resize_callback.setter
    def resize_callback(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._resize_callback = value if isinstance(value, Callback) or value is None else Callback(value)

    @property
    def close_callback(self):
        """
        Callback to be issued when the viewport is closed.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._close_callback

    @close_callback.setter
    def close_callback(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._close_callback = value if isinstance(value, Callback) or value is None else Callback(value)

    def copy(self, target_context=None) -> None:
        raise TypeError("The viewport cannot be copied")

    @property
    def metrics(self):
        """
        Return rendering related metrics for the last frame.
        
        Returns a ViewportMetrics object containing detailed timing and rendering
        statistics for performance monitoring and diagnostics. All timing values
        use the system monotonic clock for consistent measurements across frames.
        
        The metrics track the complete frame lifecycle:
        1. Event handling (mouse/keyboard input processing)
        2. Rendering (traversing UI tree and generating ImGui/ImPlot commands)
        3. Presenting (submitting to GPU and swapping buffers)
        
        Use these metrics to identify performance bottlenecks or calculate the
        effective frame rate (1.0/delta_whole_frame = FPS).
        """
        cdef unique_lock[DCGMutex] m
        cdef unique_lock[DCGMutex] m2
        lock_gil_friendly(m, self.context.imgui_mutex)
        lock_gil_friendly(m2, self.mutex)

        return ViewportMetrics(
            self.last_t_before_event_handling,
            self.last_t_before_rendering,
            self.last_t_after_rendering,
            self.last_t_after_swapping,
            self.delta_event_handling,
            self.delta_rendering,
            self.delta_swapping,
            self.delta_frame,
            imgui.GetIO().MetricsRenderVertices,
            imgui.GetIO().MetricsRenderIndices,
            imgui.GetIO().MetricsRenderWindows,
            imgui.GetIO().MetricsActiveWindows,
            self.frame_count-1
        )

    @property
    def retrieve_framebuffer(self):
        """
        Whether to activate the framebuffer retrieval.

        If set to true, the framebuffer field will be
        populated. This has a performance cost.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._retrieve_framebuffer

    @retrieve_framebuffer.setter
    def retrieve_framebuffer(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._retrieve_framebuffer = value

    @property
    def framebuffer(self):
        """
        Content of the framebuffer (dcg.Texture)

        This field is only populated upon frame rendering
        when retrieve_framebuffer is set.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._frame_buffer

    cdef void __on_resize(self):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.context.queue_callback_arg4int(self._resize_callback,
                                            self,
                                            self,
                                            (<platformViewport*>self._platform).frameWidth,
                                            (<platformViewport*>self._platform).frameHeight,
                                            (<platformViewport*>self._platform).windowWidth,
                                            (<platformViewport*>self._platform).windowHeight)

    cdef void __on_close(self):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if not(self._disable_close):
            self.context._started = False
        self.context.queue_callback_noarg(self._close_callback, self, self)

    cdef void __on_drop(self, int32_t type, const char* data):
        """
        Drop operations are received in several pieces,
        we concatenate them before calling the user callback.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef DCGString data_str
        if type == 0:
            # Start of a new drop operation
            self.drop_data.clear()
            self.os_drop_ready = False
            self.os_drop_pending = True
            self.drop_is_file_type = False
        elif type == 1:
            # Drop file
            data_str = DCGString(data)
            self.drop_is_file_type = True
            self.drop_data.push_back(data_str)
        elif type == 2:
            # Drop text
            data_str = DCGString(data)
            self.drop_is_file_type = False
            self.drop_data.push_back(data_str)
        elif type == 3:
            # End of drop operation
            self.os_drop_ready = True
            if self._pending_drop is not None:
                # We had a pending drop, process it now
                (callback, handler, item, state_copy, mouse_x, mouse_y) = self._pending_drop
                element_list = []
                for i in range(<int>self.context.viewport.drop_data.size()):
                    element_list.append(string_to_str(self.context.viewport.drop_data[i]))
                self.context.queue_callback(
                    callback,
                    handler,
                    item,
                    ("file" if self.drop_is_file_type else "text",
                    element_list,
                    state_copy,
                    (mouse_x, mouse_y)))
                self.os_drop_ready = False
                self.os_drop_pending = False
                self.drop_data.clear()
                self._pending_drop = None


    cdef void __render(self) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        cdef bint any_change = False
        self.last_t_before_rendering = ctime.monotonic_ns()
        # Initialize drawing state
        ensure_correct_im_context(self.context)
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
        # Clean finished drop payload
        cdef const imgui.ImGuiPayload *payload = imgui.GetDragDropPayload()
        if self.drag_drop is not None:
            if (payload == NULL): # It is sufficient to only check NULL
                #payload.DataSize != 4 or
                #(*<void**>payload.Data) != <PyObject*>self.drag_drop)): # we could also check the payload type
                with gil:
                    self.drag_drop = None
        elif self.os_drop_pending:
            if imgui.BeginDragDropSource(imgui.ImGuiDragDropFlags_SourceNoPreviewTooltip |
                                         imgui.ImGuiDragDropFlags_SourceExtern |
                                         imgui.ImGuiDragDropFlags_PayloadAutoExpire) != 0:
                if imgui.SetDragDropPayload(<char*>r"file" if self.drop_is_file_type else <char*>r"text",
                                            NULL, 0, imgui.ImGuiCond_Always):
                    # Data has been accepted, we can clear it
                    self.os_drop_pending = False
                    self.os_drop_ready = False
                    self.drop_data.clear()
                imgui.EndDragDropSource()

        self.shifts = [0., 0.]
        self.scales = [1., 1.]
        self.in_plot = False
        self.parent_pos = make_Vec2(0., 0.)
        self.parent_size = make_Vec2((<platformViewport*>self._platform).frameWidth,
                                     (<platformViewport*>self._platform).frameHeight)
        self.window_pos = make_Vec2(0., 0.)
        imgui.PushID(self.uuid)
        draw_menubar_children(self)
        # TODO: if menubar, we beed to shift parent_pos and parent_size
        # to account for the menubar size
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

    cdef void coordinate_to_screen(self, float *dst_p, const double[2] src_p) noexcept nogil:
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

    cdef void screen_to_coordinate(self, double *dst_p, const float[2] src_p) noexcept nogil:
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

    def wait_events(self, int32_t timeout_ms=0) -> bool:
        """
        Waits for an event that justifies running render_frame to occur.

        When using wait_for_input, render_frame will block until a relevant
        event such as a mouse or keyboard event occurs, or until logical
        events such as timed UI behaviours are triggered.
        This method allows the application to implement its own waiting logic.

        When this method returns True, and wait_for_input is True, the next
        render_frame call is guaranteed to not block on events.

        When wait_for_input is False, render_frame does not block on events
        whether this method returns True or False.

        This method blocks until an event occurs or the timeout is reached.
        Args:
            timeout_ms (int): The maximum time to wait in milliseconds.
                If 0, no wait is performed and the method returns immediately.

        Returns:
            bool: True if an event requires render_frame to be processed,
                  False if no such event was met in the allocated time.
        """
        cdef unique_lock[DCGMutex] self_m
        cdef unique_lock[DCGMutex] backend_m = unique_lock[DCGMutex](self._mutex_backend, defer_lock_t())
        lock_gil_friendly(self_m, self.mutex)
        self.__check_initialized()
        if not (<platformViewport*>self._platform).checkPrimaryThread():
            raise RuntimeError("wait_events must be called from the thread where the context was created")
        cdef bint has_events
        cdef double current_time_s
        cdef int32_t internal_timeout_ms
        cdef bint is_internal_timeout = False
        with nogil:
            ensure_correct_im_context(self.context) # Doesn't really need the imgui mutex
            backend_m.lock()
            self_m.unlock()
            current_time_s = (<double>ctime.monotonic_ns()) * 1e-9
            internal_timeout_ms = <int32_t>(ceil((self._target_refresh_time - current_time_s) * 1000.))
            internal_timeout_ms = max(0, internal_timeout_ms)
            timeout_ms = max(0, timeout_ms)
            if internal_timeout_ms <= timeout_ms:
                is_internal_timeout = True # internal timeout event will occur before requested timeout.
                timeout_ms = internal_timeout_ms
            has_events = (<platformViewport*>self._platform).processEvents(timeout_ms)
            if is_internal_timeout:
                has_events = True # Either has_events was already True, or we meet internal timeout event
        return has_events

    def render_frame(self) -> bool:
        """Render one frame of the application.

        Rendering occurs in several sequential steps:
        1. Mouse/Keyboard events are processed (wait_for_input applies here)
        2. The viewport and entire rendering tree are traversed to prepare
        rendering commands using ImGui and ImPlot
        3. Rendering commands are submitted to the GPU, if a change was detected
           (unless always_submit_to_gpu is set, in which case it is always submitted.)
        4. If submitted to the GPU, a window update is requested to the OS, using
            vsync if applicable

        Returns
        -------
        bool
            True if the frame was presented to the screen, False otherwise
        """
        # to lock in this order
        cdef unique_lock[DCGMutex] imgui_m = unique_lock[DCGMutex](self.context.imgui_mutex, defer_lock_t())
        cdef unique_lock[DCGMutex] self_m
        cdef unique_lock[DCGMutex] backend_m = unique_lock[DCGMutex](self._mutex_backend, defer_lock_t())
        lock_gil_friendly(self_m, self.mutex)
        self.__check_initialized()
        if not (<platformViewport*>self._platform).checkPrimaryThread():
            raise RuntimeError("render_frame must be called from the thread where the context was created")
        cdef double current_time_s, target_timeout_ms
        cdef bint should_present
        cdef float gs
        cdef imgui.ImGuiStyle *style
        cdef implot.ImPlotStyle *style_p
        cdef Texture framebuffer
        with nogil:
            # Configuring imgui's style. Uses imgui variables and viewport variables
            self_m.unlock() # lock order
            imgui_m.lock()
            self_m.lock()
            ensure_correct_im_context(self.context)
            self.last_t_before_event_handling = ctime.monotonic_ns()
            gs = self.global_scale
            self.global_scale = (<platformViewport*>self._platform).dpiScale * self._scale
            style = &imgui.GetStyle()
            style_p = &implot.GetStyle()
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

            backend_m.lock()
            self_m.unlock()
            # Process input events (needs imgui mutex and backend mutex)
            # Doesn't need viewport mutex.
            # if wait_for_input is set, can take a long time
            current_time_s = self.last_t_before_event_handling * 1e-9
            target_timeout_ms = (self._target_refresh_time - current_time_s) * 1000.
            target_timeout_ms = max(0., ceil(target_timeout_ms))
            # TODO: we really want to not have imgui_m locked here, but
            # this is not really correct...
            imgui_m.unlock()
            (<platformViewport*>self._platform).processEvents(
                <int>target_timeout_ms if self.wait_for_input else 0)
            backend_m.unlock() # important to respect lock order
            # Core rendering - uses imgui and viewport
            imgui_m.lock()
            self_m.lock()
            backend_m.lock()
            #self.last_t_before_rendering = ctime.monotonic_ns()
            
            #imgui.GetMainViewport().DpiScale = self.viewport.dpi
            #imgui.GetIO().FontGlobalScale = self.viewport.dpi
            current_time_s = (<double>ctime.monotonic_ns()) * 1e-9
            if current_time_s >= self._target_refresh_time:
                # If we are past the target time, we should present
                # to avoid blocking the viewport.
                (<platformViewport*>self._platform).needsRefresh.store(True)
                self._target_refresh_time = current_time_s + 5. # maximum time before next frame
            else:
                should_present = False
            ensure_correct_im_context(self.context)
            should_present = \
                (<platformViewport*>self._platform).renderFrame(not(self.always_submit_to_gpu))
            ensure_correct_im_context(self.context)
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
        cdef long long current_time = ctime.monotonic_ns()
        if not(should_present) and (<platformViewport*>self._platform).hasVSync\
           and (current_time - self.last_t_after_swapping) < 5000000: # 5 ms
            # cap 'cpu' framerate when not presenting
            python_time.sleep(0.005 - <double>(current_time - self.last_t_after_swapping) * 1e-9)
            current_time = ctime.monotonic_ns()
        lock_gil_friendly(self_m, self.mutex)
        self.delta_frame = current_time - self.last_t_after_swapping
        self.last_t_after_swapping = current_time
        self.delta_swapping = current_time - self.last_t_after_rendering
        self.delta_rendering = self.last_t_after_rendering - self.last_t_before_rendering
        self.delta_event_handling = self.last_t_before_rendering - self.last_t_before_event_handling
        self.frame_count += 1
        return should_present

    def wake(self, double delay=0., bint full_refresh=True):
        """
        Wake the viewport to force a redraw.

        In case rendering is waiting for an input (wait_for_input),
        generate a fake input to force rendering.

        Use-cases are:
            - You have updated the content of several items, and you
               request an immediate refresh.
            - You have updated the content of several items, and while
               you don't need an immediate refresh, you want refresh
               to occur not in a too long delay.
            - You have a timed event, and you wish rendering to occur
               again before or at the timed event.

        Args:
            - delay: Delay in seconds (starting from now) until the wakeup
                should take effect. Note that rendering may occur earlier,
                in which case you need to make a new wake call if you intended
                a refresh to occur at a specific target time.
            - full_refresh: If True (the default), requests that a full screen
                redraw with gpu submission is performed. if False, render_frame
                may decide to not submit to the gpu if it thinks no change occured.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if not self._initialized:
            return
        cdef uint64_t delay_ns = <uint64_t>fmax(0, delay * 1e9)
        (<platformViewport*>self._platform).wakeRendering(delay_ns, full_refresh) # doesn't need any mutex

    cdef void ask_refresh_after(self, double monotonic) noexcept nogil:
        """
        Called during draw to request that a new draw should
        occur when monotonic time is reached. The next draw might
        still occur before the target, in which case, the function
        should be called again.
        """
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
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
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        (<platformViewport*>self._platform).needsRefresh.store(True)

    cdef Vec2 get_size(self) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        cdef Vec2 size
        size.x = (<platformViewport*>self._platform).frameWidth
        size.y = (<platformViewport*>self._platform).frameHeight
        return size

    cdef void *get_platform_window(self) noexcept nogil:
        if not self._initialized:
            return NULL
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
        if getattr(callback, "__defaults__", None) is not None:
            num_defaults = len(callback.__defaults__)
        try:
            self.num_args = callback.__code__.co_argcount - num_defaults
            if hasattr(callback, '__self__'):
                self.num_args -= 1
        except AttributeError:
            self.num_args = 3

    @property
    def callback(self):
        """Wrapped callback"""
        return self.callback

    def __call__(self, source_item, target_item, call_info):
        try:
            if self.num_args == 3:
                return self.callback(source_item, target_item, call_info)
            elif self.num_args == 2:
                return self.callback(source_item, target_item)
            elif self.num_args == 1:
                return self.callback(source_item)
            else:
                return self.callback()
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
        except (KeyboardInterrupt, SystemExit) as e:
            if C is not None:
                C._started = False
            raise e


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
                return self.callback(source_item.uuid, call_info, source_item.user_data)
            elif self.num_args == 2:
                return self.callback(source_item.uuid, call_info)
            elif self.num_args == 1:
                return self.callback(source_item.uuid)
            else:
                return self.callback()
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



@cython.freelist(8)
cdef class ItemStateView:
    """
    View class for accessing UI item state properties.
    
    This class provides a consolidated interface to access state properties
    of UI items, such as whether they are hovered, active, focused, etc.
    Each property is checked against the item's capabilities to ensure
    it supports that state.
    
    The view references the original item and uses its mutex for thread safety.
    """
    def __init__(self):
        raise RuntimeError("ItemStateView cannot be instantiated directly. Read item.state instead.")

    @staticmethod
    cdef ItemStateView create(baseItem item):
        if item.p_state is NULL:
            raise AttributeError("Cannot create a state view for an item without state")

        if (not(item.p_state.cap.can_be_active) and
            not(item.p_state.cap.can_be_clicked) and
            not(item.p_state.cap.can_be_deactivated_after_edited) and
            not(item.p_state.cap.can_be_dragged) and
            not(item.p_state.cap.can_be_edited) and
            not(item.p_state.cap.can_be_focused) and
            not(item.p_state.cap.can_be_hovered) and
            not(item.p_state.cap.can_be_toggled) and
            not(item.p_state.cap.has_position) and
            not(item.p_state.cap.has_rect_size) and
            not(item.p_state.cap.has_content_region)):
            raise AttributeError("Item does not support any state view properties")
        cdef ItemStateView view = ItemStateView.__new__(ItemStateView)
        view._item = item
        return view

    def __dir__(self):
        default_dir = dir(type(self))
        if hasattr(self, '__dict__'): # Can happen with python subclassing
            default_dir += list(self.__dict__.keys())
        # Remove invalid ones
        results = set()
        for e in default_dir:
            if hasattr(self, e):
                results.add(e)
        return sorted(list(results))
    
    @property
    def active(self):
        """
        Whether the item is in an active state.
        
        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.
        """
        if self._item is None:
            raise ValueError("Item has been deleted or is invalid")
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self._item.mutex)
        if self._item.p_state is NULL:
            raise ValueError("Item state is not available")
        if not(self._item.p_state.cap.can_be_active):
            raise AttributeError("Field undefined for this item type")
        return self._item.p_state.cur.active
    
    @property
    def activated(self):
        """
        Whether the item just transitioned to the active state this frame.
        
        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use 
        event handlers instead as they provide more robust state tracking.
        """
        if self._item is None:
            raise ValueError("Item has been deleted or is invalid")
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self._item.mutex)
        if self._item.p_state is NULL:
            raise ValueError("Item state is not available")
        if not(self._item.p_state.cap.can_be_active):
            raise AttributeError("Field undefined for this item type")
        return self._item.p_state.cur.active and not(self._item.p_state.prev.active)
    
    @property
    def clicked(self):
        """
        Whether any mouse button was clicked on this item this frame.
        
        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.
        """
        if self._item is None:
            raise ValueError("Item has been deleted or is invalid")
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self._item.mutex)
        if self._item.p_state is NULL:
            raise ValueError("Item state is not available")
        if not(self._item.p_state.cap.can_be_clicked):
            raise AttributeError("Field undefined for this item type")
        return tuple(self._item.p_state.cur.clicked)
    
    @property
    def double_clicked(self):
        """
        Whether any mouse button was double-clicked on this item this frame.
        
        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.
        """
        if self._item is None:
            raise ValueError("Item has been deleted or is invalid")
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self._item.mutex)
        if self._item.p_state is NULL:
            raise ValueError("Item state is not available")
        if not(self._item.p_state.cap.can_be_clicked):
            raise AttributeError("Field undefined for this item type")
        return self._item.p_state.cur.double_clicked
    
    @property
    def deactivated(self):
        """
        Whether the item just transitioned from active to inactive this frame.
        
        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.
        """
        if self._item is None:
            raise ValueError("Item has been deleted or is invalid")
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self._item.mutex)
        if self._item.p_state is NULL:
            raise ValueError("Item state is not available")
        if not(self._item.p_state.cap.can_be_active):
            raise AttributeError("Field undefined for this item type")
        return not(self._item.p_state.cur.active) and self._item.p_state.prev.active
    
    @property
    def deactivated_after_edited(self):
        """
        Whether the item was edited and then deactivated in this frame.
        
        Useful for detecting when user completes an edit operation, such as
        finishing text input or adjusting a value. This property is only true
        for the frame when the deactivation occurs after editing.
        """
        if self._item is None:
            raise ValueError("Item has been deleted or is invalid")
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self._item.mutex)
        if self._item.p_state is NULL:
            raise ValueError("Item state is not available")
        if not(self._item.p_state.cap.can_be_deactivated_after_edited):
            raise AttributeError("Field undefined for this item type")
        return self._item.p_state.cur.deactivated_after_edited
    
    @property
    def edited(self):
        """
        Whether the item's value was modified this frame.
        
        This flag indicates that the user has made a change to the item's value,
        such as typing in an input field or adjusting a slider. It is only true
        for the frame when the edit occurs.
        """
        if self._item is None:
            raise ValueError("Item has been deleted or is invalid")
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self._item.mutex)
        if self._item.p_state is NULL:
            raise ValueError("Item state is not available")
        if not(self._item.p_state.cap.can_be_edited):
            raise AttributeError("Field undefined for this item type")
        return self._item.p_state.cur.edited
    
    @property
    def focused(self):
        """
        Whether this item has input focus.
        
        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.
        """
        if self._item is None:
            raise ValueError("Item has been deleted or is invalid")
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self._item.mutex)
        if self._item.p_state is NULL:
            raise ValueError("Item state is not available")
        if not(self._item.p_state.cap.can_be_focused):
            raise AttributeError("Field undefined for this item type")
        return self._item.p_state.cur.focused
    
    @property
    def hovered(self):
        """
        Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.
        """
        if self._item is None:
            raise ValueError("Item has been deleted or is invalid")
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self._item.mutex)
        if self._item.p_state is NULL:
            raise ValueError("Item state is not available")
        if not(self._item.p_state.cap.can_be_hovered):
            raise AttributeError("Field undefined for this item type")
        return self._item.p_state.cur.hovered
    
    @property
    def resized(self):
        """
        Whether the item's size changed this frame.
        
        This property is true only for the frame when the size change occurs.
        It can detect both user-initiated resizing (like dragging a window edge)
        and programmatic size changes.
        """
        if self._item is None:
            raise ValueError("Item has been deleted or is invalid")
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self._item.mutex)
        if self._item.p_state is NULL:
            raise ValueError("Item state is not available")
        if not(self._item.p_state.cap.has_rect_size):
            raise AttributeError("Field undefined for this item type")
        return self._item.p_state.cur.rect_size.x != self._item.p_state.prev.rect_size.x or \
               self._item.p_state.cur.rect_size.y != self._item.p_state.prev.rect_size.y
    
    @property
    def toggled(self):
        """
        Whether the item was just toggled open this frame.
        
        Applies to items that can be expanded or collapsed, such as tree nodes,
        collapsing headers, or menus. This property is only true during the frame
        when the toggle from closed to open occurs.
        """
        if self._item is None:
            raise ValueError("Item has been deleted or is invalid")
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self._item.mutex)
        if self._item.p_state is NULL:
            raise ValueError("Item state is not available")
        if not(self._item.p_state.cap.can_be_toggled):
            raise AttributeError("Field undefined for this item type")
        return self._item.p_state.cur.open and not(self._item.p_state.prev.open)
    
    @property
    def visible(self):
        """
        Whether the item was rendered in the current frame.
        
        An item is visible when it and all its ancestors have show=True and are
        within the visible region of their containers. Invisible items skip
        rendering and event handling entirely.
        """
        if self._item is None:
            raise ValueError("Item has been deleted or is invalid")
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self._item.mutex)
        if self._item.p_state is NULL:
            raise ValueError("Item state is not available")
        return self._item.p_state.cur.rendered
    
    # Position and size properties
    
    @property
    def rect_size(self):
        """
        Actual pixel size of the element including margins.
        
        This property represents the width and height of the rectangle occupied
        by the item in the layout. The rectangle's top-left corner is at the
        position given by the relevant position property.
        
        Note that this size refers only to the item within its parent window and
        does not include any popup or child windows that might be spawned by
        this item.
        """
        if self._item is None:
            raise ValueError("Item has been deleted or is invalid")
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self._item.mutex)
        if self._item.p_state is NULL:
            raise ValueError("Item state is not available")
        if not(self._item.p_state.cap.has_rect_size):
            raise AttributeError("Field undefined for this item type")
        return Coord.build_v(self._item.p_state.cur.rect_size)
    
    @property
    def pos_to_viewport(self):
        """
        Position relative to the viewport's top-left corner.
        """
        if self._item is None:
            raise ValueError("Item has been deleted or is invalid")
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self._item.mutex)
        if self._item.p_state is NULL:
            raise ValueError("Item state is not available")
        if not(self._item.p_state.cap.has_position):
            raise AttributeError("Field undefined for this item type")
        return Coord.build_v(self._item.p_state.cur.pos_to_viewport)
    
    @property
    def pos_to_window(self):
        """
        Position relative to the containing window's content area.
        """
        if self._item is None:
            raise ValueError("Item has been deleted or is invalid")
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self._item.mutex)
        if self._item.p_state is NULL:
            raise ValueError("Item state is not available")
        if not(self._item.p_state.cap.has_position):
            raise AttributeError("Field undefined for this item type")
        return Coord.build_v(self._item.p_state.cur.pos_to_window)
    
    @property
    def pos_to_parent(self):
        """
        Position relative to the parent item's content area.
        """
        if self._item is None:
            raise ValueError("Item has been deleted or is invalid")
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self._item.mutex)
        if self._item.p_state is NULL:
            raise ValueError("Item state is not available")
        if not(self._item.p_state.cap.has_position):
            raise AttributeError("Field undefined for this item type")
        return Coord.build_v(self._item.p_state.cur.pos_to_parent)
    
    @property
    def content_region_avail(self):
        """
        Available space for child items.
        
        For container items like windows, child windows, this
        property represents the available space for placing child items. This is
        the item's inner area after accounting for padding, borders, and other
        non-content elements.
        
        Areas that require scrolling to see are not included in this measurement.
        """
        if self._item is None:
            raise ValueError("Item has been deleted or is invalid")
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self._item.mutex)
        if self._item.p_state is NULL:
            raise ValueError("Item state is not available")
        if not(self._item.p_state.cap.has_content_region):
            raise AttributeError("Field undefined for this item type")
        return Coord.build_v(self._item.p_state.cur.content_region_size)

    @property
    def content_pos(self):
        """
        Position of the content area's top-left corner.
        
        This property provides the viewport-relative coordinates of the starting
        point for an item's content area. This is where child elements begin to be
        placed by default.
        
        Used together with content_region_avail, this defines the rectangle
        available for child elements.
        """
        if self._item is None:
            raise ValueError("Item has been deleted or is invalid")
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self._item.mutex)
        if self._item.p_state is NULL:
            raise ValueError("Item state is not available")
        if not(self._item.p_state.cap.has_content_region):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        return Coord.build_v(self._item.p_state.cur.content_pos)

    # Accessor
    @property
    def item(self):
        """
        item from which the states are extracted.
        """
        return self._item

    def snapshot(self) -> ItemStateCopy:
        """
        Create a snapshot copy of the current item state.
        
        This method captures the current state values and returns a new
        ItemStateCopy instance containing those values. The snapshot is
        immutable and does not change with future updates to the item.
        
        This is useful for preserving state at a specific point in time.
        """
        return ItemStateCopy.create_from_view(self)


cdef class ItemStateCopy:
    """
    A snapshot copy of UI item state properties at a specific point in time.
    
    This class contains a complete copy of an item's state values, allowing you
    to capture and examine the state at a specific moment without being affected
    by subsequent changes. Unlike ItemStateView which provides live access to changing
    states, itemStateCopy preserves the values as they were when the copy was made.
    
    This is useful for:
    - Comparing states between frames
    - Storing historical state information
    - Analyzing state changes over time
    - Debugging state-related issues
    
    All properties return the copied values and are read-only.
    """
    def __init__(self):
        raise RuntimeError("ItemStateCopy cannot be instantiated directly. Use item.state.snapshot() instead.")

    @staticmethod
    cdef ItemStateCopy create_from_view(ItemStateView view):
        cdef baseItem item = view._item
        if item is None:
            raise ValueError("Cannot create a state copy for an item that has been deleted or is invalid")
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, item.mutex)
        if item.p_state is NULL:
            raise AttributeError("Cannot create a state view for an item without state")
        cdef ItemStateCopy self = ItemStateCopy.__new__(ItemStateCopy)
        self._item = item
        # Create a copy of the state
        memcpy(
            <void*>&self._state,
            <const void*>item.p_state,
            sizeof(itemState)
        )
        return self

    def __dir__(self):
        default_dir = dir(type(self))
        if hasattr(self, '__dict__'): # Can happen with python subclassing
            default_dir += list(self.__dict__.keys())
        # Remove invalid ones
        results = set()
        for e in default_dir:
            if hasattr(self, e):
                results.add(e)
        return sorted(list(results))

    # Note: Since all attributes are read-only and immutable, we don't need a mutex
    @property
    def active(self):
        """
        Whether the item is in an active state.
        
        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.
        """
        if not(self._state.cap.can_be_active):
            raise AttributeError("Field undefined for this item type")
        return self._state.cur.active
    
    @property
    def activated(self):
        """
        Whether the item just transitioned to the active state this frame.
        
        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use 
        event handlers instead as they provide more robust state tracking.
        """
        if not(self._state.cap.can_be_active):
            raise AttributeError("Field undefined for this item type")
        return self._state.cur.active and not(self._state.prev.active)
    
    @property
    def clicked(self):
        """
        Whether any mouse button was clicked on this item this frame.
        
        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.
        """
        if not(self._state.cap.can_be_clicked):
            raise AttributeError("Field undefined for this item type")
        return tuple(self._state.cur.clicked)
    
    @property
    def double_clicked(self):
        """
        Whether any mouse button was double-clicked on this item this frame.
        
        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.
        """
        if not(self._state.cap.can_be_clicked):
            raise AttributeError("Field undefined for this item type")
        return self._state.cur.double_clicked
    
    @property
    def deactivated(self):
        """
        Whether the item just transitioned from active to inactive this frame.
        
        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.
        """
        if not(self._state.cap.can_be_active):
            raise AttributeError("Field undefined for this item type")
        return not(self._state.cur.active) and self._state.prev.active
    
    @property
    def deactivated_after_edited(self):
        """
        Whether the item was edited and then deactivated in this frame.
        
        Useful for detecting when user completes an edit operation, such as
        finishing text input or adjusting a value. This property is only true
        for the frame when the deactivation occurs after editing.
        """
        if not(self._state.cap.can_be_deactivated_after_edited):
            raise AttributeError("Field undefined for this item type")
        return self._state.cur.deactivated_after_edited
    
    @property
    def edited(self):
        """
        Whether the item's value was modified this frame.
        
        This flag indicates that the user has made a change to the item's value,
        such as typing in an input field or adjusting a slider. It is only true
        for the frame when the edit occurs.
        """
        if not(self._state.cap.can_be_edited):
            raise AttributeError("Field undefined for this item type")
        return self._state.cur.edited
    
    @property
    def focused(self):
        """
        Whether this item has input focus.
        
        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.
        """
        if not(self._state.cap.can_be_focused):
            raise AttributeError("Field undefined for this item type")
        return self._state.cur.focused
    
    @property
    def hovered(self):
        """
        Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.
        """
        if not(self._state.cap.can_be_hovered):
            raise AttributeError("Field undefined for this item type")
        return self._state.cur.hovered
    
    @property
    def resized(self):
        """
        Whether the item's size changed this frame.
        
        This property is true only for the frame when the size change occurs.
        It can detect both user-initiated resizing (like dragging a window edge)
        and programmatic size changes.
        """
        if not(self._state.cap.has_rect_size):
            raise AttributeError("Field undefined for this item type")
        return self._state.cur.rect_size.x != self._state.prev.rect_size.x or \
               self._state.cur.rect_size.y != self._state.prev.rect_size.y
    
    @property
    def toggled(self):
        """
        Whether the item was just toggled open this frame.
        
        Applies to items that can be expanded or collapsed, such as tree nodes,
        collapsing headers, or menus. This property is only true during the frame
        when the toggle from closed to open occurs.
        """
        if not(self._state.cap.can_be_toggled):
            raise AttributeError("Field undefined for this item type")
        return self._state.cur.open and not(self._state.prev.open)
    
    @property
    def visible(self):
        """
        Whether the item was rendered in the current frame.
        
        An item is visible when it and all its ancestors have show=True and are
        within the visible region of their containers. Invisible items skip
        rendering and event handling entirely.
        """
        return self._state.cur.rendered
    
    # Position and size properties
    
    @property
    def rect_size(self):
        """
        Actual pixel size of the element including margins.
        
        This property represents the width and height of the rectangle occupied
        by the item in the layout. The rectangle's top-left corner is at the
        position given by the relevant position property.
        
        Note that this size refers only to the item within its parent window and
        does not include any popup or child windows that might be spawned by
        this item.
        """
        if not(self._state.cap.has_rect_size):
            raise AttributeError("Field undefined for this item type")
        return Coord.build_v(self._state.cur.rect_size)
    
    @property
    def pos_to_viewport(self):
        """
        Position relative to the viewport's top-left corner.
        """
        if not(self._state.cap.has_position):
            raise AttributeError("Field undefined for this item type")
        return Coord.build_v(self._state.cur.pos_to_viewport)
    
    @property
    def pos_to_window(self):
        """
        Position relative to the containing window's content area.
        """
        if not(self._state.cap.has_position):
            raise AttributeError("Field undefined for this item type")
        return Coord.build_v(self._state.cur.pos_to_window)
    
    @property
    def pos_to_parent(self):
        """
        Position relative to the parent item's content area.
        """
        if not(self._state.cap.has_position):
            raise AttributeError("Field undefined for this item type")
        return Coord.build_v(self._state.cur.pos_to_parent)
    
    @property
    def content_region_avail(self):
        """
        Available space for child items.
        
        For container items like windows, child windows, this
        property represents the available space for placing child items. This is
        the item's inner area after accounting for padding, borders, and other
        non-content elements.
        
        Areas that require scrolling to see are not included in this measurement.
        """
        if not(self._state.cap.has_content_region):
            raise AttributeError("Field undefined for this item type")
        return Coord.build_v(self._state.cur.content_region_size)

    @property
    def content_pos(self):
        """
        Position of the content area's top-left corner.
        
        This property provides the viewport-relative coordinates of the starting
        point for an item's content area. This is where child elements begin to be
        placed by default.
        
        Used together with content_region_avail, this defines the rectangle
        available for child elements.
        """
        if not(self._state.cap.has_content_region):
            raise AttributeError("Field undefined for type {}".format(type(self)))
        return Coord.build_v(self._state.cur.content_pos)

    # Accessor
    @property
    def item(self):
        """
        item from which the states were extracted.
        """
        return self._item


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
    cdef int32_t start_button = 0
    if state.cap.can_be_dragged:
        for i in range(<int>imgui.ImGuiMouseButton_COUNT):
            state.cur.dragging[i] = False
        # An item can be dragged while not hovered anymore. Activation (clicked + press maintained)
        # is the most reliable criteria. If the item does not support activation, rely on hovering
        # test, and keeping dragging active.
        # We do this only for left click as it is usually the button for activation

        if state.cap.can_be_active:
            if state.cur.active:
                dragging = imgui.IsMouseDragging(0, -1.)
                if dragging:
                    state.cur.drag_deltas[0] = ImVec2Vec2(imgui.GetMouseDragDelta(0, -1.))
                    state.cur.dragging[0] = True
            start_button = 1
        for i in range(start_button, <int>imgui.ImGuiMouseButton_COUNT):
            dragging = imgui.IsMouseDragging(i, -1.)
            if dragging:
                if not state.prev.dragging[i]:
                    if state.cur.hovered:
                        # check if the item was hovered when the mouse was pressed
                        if state.cur.pos_to_viewport.x > imgui.GetIO().MouseClickedPos[i].x or \
                            state.cur.pos_to_viewport.y > imgui.GetIO().MouseClickedPos[i].y or \
                            (state.cur.pos_to_viewport.x + state.cur.rect_size.x) < imgui.GetIO().MouseClickedPos[i].x or \
                            (state.cur.pos_to_viewport.y + state.cur.rect_size.y) < imgui.GetIO().MouseClickedPos[i].y:
                            # The item was not hovered when the mouse was pressed
                            dragging = False
                    else:
                        # Item is not hovered at all, so we cannot be starting dragging it
                        dragging = False
            if dragging:
                state.cur.drag_deltas[i] = ImVec2Vec2(imgui.GetMouseDragDelta(i, -1.))
                state.cur.dragging[i] = True

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
        Should the object be drawn/shown ?

        In case show is set to False, this disables any
        callback (for example the close callback won't be called
        if a window is hidden with show = False).
        In the case of items that can be closed,
        show is set to False automatically on close.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._show

    @show.setter
    def show(self, bint value):
        cdef unique_lock[DCGMutex] m
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
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
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
        if (catch_active && !first_hovered_wins)
            toplevel = true;  // If we catch active, we are toplevel

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
        if (hovered && g.HoveredIdPreviousFrame == id) {
            ImGui::SetHoveredID(id);
        }
        // Catch hover if we requested to
        else if (hovered && catch_ui_hover) {
            ImGui::SetHoveredID(id);
        }
        // No other UI item hovered rendered before
        else if (hovered && (g.HoveredId == id || g.HoveredId == 0)) {
            ImGui::SetHoveredID(id);
        }

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
    Represents a value that can be shared between multiple UI items.
    
    Shared values allow multiple UI elements to reference the same underlying data
    without duplicating it. When one item updates the value, all items sharing it
    will immediately reflect the change, providing a straightforward way to link
    elements together.
    
    SharedValue tracks when the value was last changed or updated, making it
    possible to detect changes and optimize rendering when the value hasn't
    been modified.
    
    Each concrete shared value type (like SharedFloat, SharedStr, etc.) extends
    this base class to provide type-specific functionality while maintaining
    consistent behavior around tracking and sharing.
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
        """
        The current value stored by this object.
        
        This property represents the actual data being shared between UI elements.
        Reading this property returns a copy of the value. Modifying the returned
        value will not affect the shared value unless it is set back using this
        property.
        """
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
        """
        Reference to the shared value object itself.
        
        Returns a reference to this SharedValue instance, allowing it to be
        assigned to another item's shareable_value property to establish
        value sharing between items.
        
        This property is primarily used when connecting multiple UI elements
        to the same data source.
        """
        return self

    @property
    def last_frame_update(self):
        """
        Frame index when the value was last updated.
        
        Tracks the frame number when the value was last modified or validated,
        even if the new value was identical to the previous one. This can be
        used to detect when any access or modification attempt occurred.
        """
        return self._last_frame_update

    @property
    def last_frame_change(self):
        """
        Frame index when the value was last changed to a different value.
        
        Records the frame number when the value actually changed. For scalar
        types, this differs from last_frame_update when a value is set to
        its current value (no actual change). For complex data types like
        vectors or colors, this equals last_frame_update for efficiency.
        """
        return self._last_frame_change

    @property
    def num_attached(self):
        """
        Number of items currently sharing this value.
        
        Counts how many UI items are currently using this shared value. When
        this count reaches zero, the shared value becomes eligible for garbage
        collection if no other references exist.
        """
        return self._num_attached

    cdef void on_update(self, bint changed) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        # TODO: figure out if not using mutex is ok
        self._last_frame_update = self.context.viewport.frame_count
        if changed:
            self._last_frame_change = self.context.viewport.frame_count

    cdef void inc_num_attached(self) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        self._num_attached += 1

    cdef void dec_num_attached(self) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        self._num_attached -= 1


"""
UI input event handlers
"""

cdef class baseHandler(baseItem):
    """
    Base class for UI input event handlers.
    
    Handlers track and respond to various UI states and events, allowing callbacks
    to be triggered when specific conditions are met. They can be attached to any
    item to monitor its state changes.
    
    Handlers provide a flexible way to implement interactive behavior without 
    cluttering application logic with state checking code. Multiple handlers can be
    attached to a single item to respond to different aspects of its state.
    """
    def __cinit__(self):
        self._enabled = True
        self.can_have_sibling = True
        self.element_child_category = child_type.cat_handler
    @property
    def enabled(self):
        """
        Controls whether the handler is active and processing events.
        
        When disabled, the handler will not check states or trigger callbacks,
        effectively pausing its functionality without removing it. This allows
        for temporarily disabling interaction behaviors.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._enabled
    @enabled.setter
    def enabled(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._enabled = value
    # for backward compatibility
    @property
    def show(self):
        """
        Alias for the enabled property provided for backward compatibility.
        
        This property mirrors the enabled property in all aspects, maintaining
        compatibility with code that uses show instead of enabled.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._enabled
    @show.setter
    def show(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._enabled = value

    @property
    def callback(self):
        """
        Function called when the handler's condition is met.
        
        The callback is invoked with three arguments: the handler itself,
        the item that triggered the callback, and optional additional data
        specific to the handler type. The callback format is compatible with
        the Callback class.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._callback
    @callback.setter
    def callback(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._callback = value if isinstance(value, Callback) or value is None else Callback(value)

    cdef void check_bind(self, baseItem item):
        """
        Must raise en error if the handler cannot be bound for the target item.
        """
        cdef unique_lock[DCGMutex] m
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
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._enabled):
            return
        if self.check_state(item):
            self.run_callback(item)

    cdef void run_callback(self, baseItem item) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        self.context.queue_callback_arg1obj(self._callback, self, item, item)


cdef class uiItem(baseItem):
    """
    Base class for UI items with various properties and states.

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
        - rect_size: Current size in pixels including padding
        - content_region_avail: Available content area within item for children
        - height/width: Requested size of the item
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
        - Positions can be relative to viewport, window, parent (see string specifications)
        - Size can be fixed, automatic, or stretch to fill space
        - no_newline prevents automatic line breaks after the item

    All attributes are protected by mutexes to enable thread-safe access.
    """
    def __cinit__(self):
        # mvAppItemInfo
        #self._imgui_label = string_from_bytes(bytes(b'###%ld'% self.uuid))
        set_uuid_label(self._imgui_label, self.uuid)
        self._user_label = ""
        self._show = True
        self._enabled = True
        self.can_be_disabled = True
        #self.location = -1
        # next frame triggers
        self.focus_requested = False
        self._show_update_requested = True
        self._enabled_update_requested = False
        # mvAppItemConfig
        #self.filter = b""
        #self.alias = b""
        #self._dpi_scaling = True
        self.can_have_sibling = True
        self.element_child_category = child_type.cat_widget
        self.state.cap.has_position = True # ALL widgets have position
        self.state.cap.has_rect_size = True # ALL items have a rectangle size
        self.p_state = &self.state
        #self.size_policy = [Sizing.AUTO, Sizing.AUTO]
        self._scaling_factor = 1.0
        #self.trackOffset = 0.5 # 0.0f:top, 0.5f:center, 1.0f:bottom
        #self.tracked = False
        self._value = SharedValue(self.context) # To be changed by class

    def __init__(self, context, *args, **kwargs):
        self.focus_requested = kwargs.pop('focused', False)
        baseItem.__init__(self, context, *args, **kwargs)

    def __dealloc__(self):
        clear_obj_vector(self._callbacks)

    def configure(self, **kwargs):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.focus_requested = kwargs.pop('focused', self.focus_requested)
        m.unlock()
        return baseItem.configure(self, **kwargs)

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
            default_dir += list(self.__dict__.keys())
        # Remove invalid ones
        results = set()
        for e in default_dir:
            if hasattr(self, e):
                results.add(e)
        return list(results)

    def focus(self) -> None:
        """
        Request focus for this item.

        This methods requests keyboard focus for the item. The focus
        request will be processed in the next frame. It is the same
        as requested focused=True during __init__ or configure().

        Raises ValueError if the item cannot be focused.
        """
        if not(self.state.cap.can_be_focused):
            raise ValueError("Items of type {} cannot be focused".format(type(self)))
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.focus_requested = True

    @property
    def callbacks(self):
        """
        List of callbacks to invoke when the item's value changes.
        
        Callbacks are functions that receive three arguments: the item with the
        callback, the item that triggered the change, and any additional data.
        Multiple callbacks can be attached to track different value changes.
        """
        cdef unique_lock[DCGMutex] m
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
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list items = []
        cdef int32_t i
        if value is None:
            clear_obj_vector(self._callbacks)
            return
        if PySequence_Check(value) == 0:
            value = (value,)
        # Convert to callbacks
        for i in range(len(value)):
            items.append(value[i] if isinstance(value[i], Callback) else Callback(value[i]))
        clear_obj_vector(self._callbacks)
        append_obj_vector(self._callbacks, items)

    @property
    def callback(self):
        """
        Callback to invoke when the item's value changes

        This is an alias for the callbacks property
        """
        return self.callbacks

    @callback.setter
    def callback(self, value):
        self.callbacks = value

    @property
    def enabled(self):
        """
        Whether the item is interactive and fully styled.
        
        When disabled, items appear grayed out and do not respond to user
        interaction like hovering, clicking, or keyboard input. Unlike hidden
        items (show=False), disabled items still appear in the interface but
        with visual cues indicating their non-interactive state.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._enabled

    @enabled.setter
    def enabled(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if not(self.can_be_disabled) and value != True:
            raise AttributeError(f"Objects of type {type(self)} cannot be disabled")
        self._enabled_update_requested = True
        self._enabled = value

    @property
    def font(self):
        """
        Font used for rendering text in this item and its children.
        
        Specifies a font to use when rendering text within this item's hierarchy.
        When set, this overrides any font specified by parent items. Setting to
        None uses the parent's font or the default font if no parent specifies one.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._font

    @font.setter
    def font(self, baseFont value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._font = value

    @property
    def label(self):
        """
        Text label displayed with or within the item.
        
        The label is displayed differently depending on the item type. For buttons
        and selectable items it appears inside them, for windows it becomes the
        title, and for sliders and input fields it appears next to them.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._user_label

    @label.setter
    def label(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._user_label = ""
        else:
            self._user_label = value
        # Using ### means that imgui will ignore the user_label for
        # its internal ID of the object. Indeed else the ID would change
        # when the user label would change
        #self._imgui_label = string_from_bytes(bytes(self._user_label, 'utf-8') + bytes(b'###%ld'% self.uuid))
        set_composite_label(self._imgui_label, self._user_label, self.uuid)

    @property
    def value(self):
        """
        Main value associated with this item.
        
        The meaning of this value depends on the item type: for buttons it's
        whether pressed, for text inputs it's the text content, for selectable
        items it's whether selected, and so on. This property provides a
        unified interface for accessing an item's core data.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._value.value

    @value.setter
    def value(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._value.value = value

    @property
    def shareable_value(self):
        """
        Reference to the underlying value that can be shared between items.
        
        Unlike the value property which returns a copy, this returns a reference
        to the underlying SharedValue object. This object can be assigned to other
        items' shareable_value properties, creating a link where all items share
        and update the same underlying value.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._value

    @shareable_value.setter
    def shareable_value(self, value):
        cdef unique_lock[DCGMutex] m
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
        Whether the item should be rendered and process events.
        
        When set to False, the item and all its children are skipped during
        rendering, effectively hiding them and disabling all their functionality
        including callbacks and event handling. This is different from the enabled
        property which renders items but in a non-interactive state.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return <bint>self._show

    @show.setter
    def show(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self._show == value:
            return
        if not(value) and self._show:
            self.set_hidden_and_propagate_to_children_no_handlers() # TODO: already handled in draw() ?
        self._show_update_requested = True
        self._show = value

    @property
    def state(self):
        """
        The current state of the item
        
        The state is an instance of ItemStateView which is a class
        with property getters to retrieve various readonly states.

        The ItemStateView instance is just a view over the current states,
        not a copy, thus the states get updated automatically.
        """
        return ItemStateView.create(self)

    @property
    def handlers(self):
        """
        List of event handlers attached to this item.
        
        Handlers are objects that monitor the item's state and trigger callbacks
        when specific conditions are met, like when an item is clicked, hovered,
        or has its value changed. Multiple handlers can be attached to respond to
        different events or the same event in different ways.
        """
        cdef unique_lock[DCGMutex] m
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
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list items = []
        cdef int32_t i
        if value is None:
            clear_obj_vector(self._handlers)
            return
        if PySequence_Check(value) == 0:
            value = (value,)
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
        Visual styling applied to this item and its children.
        
        Themes control the appearance of items including colors, spacing, and
        other visual attributes. When set, this theme overrides any theme specified
        by parent items. Setting to None uses the parent's theme or the default
        theme if no parent specifies one.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._theme

    @theme.setter
    def theme(self, baseTheme value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._theme = value

    @property 
    def scaling_factor(self):
        """
        Additional scaling multiplier applied to this item and its children.
        
        This factor multiplies the global scaling to adjust the size of this
        item hierarchy. It affects sizes, themes, and fonts that are applied
        directly to this item or its children, but not those inherited from
        parent items. Default is 1.0 (no additional scaling).
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._scaling_factor

    @scaling_factor.setter
    def scaling_factor(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._scaling_factor = value

    ### Positioning and size requests

    @property
    def x(self):
        """
        Requested horizontal position of the item.
        
        This property specifies the desired horizontal position of the item.

        By default, items are positioned inside their parent container,
        from top to bottom, left-aligned. In other words the default
        position for the item is below the previous one. This default is
        altered by the `no_newline` property (applied on the previous item),
        which will place the item after the previous one on the same
        horizontal line (with the theme's itemSpacing applied).

        Special values:
            - 0: Use default horizontal position (see explanation above).
            - Positive values: Request a specific position in scaled pixels,
                relative to the default horizontal position. For instance,
                10 means "position 10 scaled pixels to the right of the
                default position".
            - Negative values: Unsupported for now
            - string: A string specification to automatically position the item. See the
                documentation for details on how to use this feature.

        Note when a string specification is used, the cursor will not be changed.
        If you want several items to be positioned next to each other at a specific
        target position, position a Layout item.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        try:
            ref = RefX0(self)
            if self.state.cap.has_position and \
               self.state.cur.pos_to_viewport.x > 0:
                ref.value = self.state.cur.pos_to_viewport.x
            else:
                ref.value = self.requested_x.get_value()
            return ref
        except TypeError:
            pass
        return self.requested_x.get_value()

    @property
    def y(self):
        """
        Requested vertical position of the item.
        
        This property specifies the desired vertical position of the item.

        By default, items are positioned inside their parent container,
        from top to bottom, left-aligned. In other words the default
        position for the item is below the previous one (with the theme's
        itemSpacing applied). This default is altered by the `no_newline`
        property (applied on the previous item), which will place the item
        after the previous one on the same horizontal line.

        Special values:
            - 0: Use default vertical position (see explanation above).
            - Positive values: Request a specific position in scaled pixels,
                relative to the default vertical position. For instance,
                10 means "position 10 scaled pixels below the default position".
            - Negative values: Unsupported for now
            - string: A string specification to automatically position the item. See the
                documentation for details on how to use this feature.

        Note when a string specification is used, the cursor will not be changed.
        If you want several items to be positioned next to each other at a specific
        target position, position a Layout item.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        try:
            ref = RefY0(self)
            if self.state.cap.has_position and \
               self.state.cur.pos_to_viewport.y > 0:
                ref.value = self.state.cur.pos_to_viewport.y
            else:
                ref.value = self.requested_y.get_value()
            return ref
        except TypeError:
            pass
        return self.requested_y.get_value()

    @property
    def height(self):
        """
        Requested height for the item.
        
        This property specifies the desired height for the item, though the
        actual height may differ depending on item type and constraints. 
        
        Special values:
            - 0: Use default height. May trigger content-fitting for windows or
                containers, or style-based sizing for other items.
            - Positive values: Request a specific height in scaled pixels.
            - Negative values: Request a height that fills the remaining parent space
                minus the absolute value (e.g., -1 means "fill minus 1 scaled pixel").
            - string: A string specification to automatically size the item. See the
                documentation for details on how to use this feature.
        
        Some items may ignore this property or interpret it differently. The
        actual final height in real pixels is available via the rect_size property.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        try:
            ref = RefHeight(self)
            if self.state.cap.has_rect_size and \
               self.state.cur.rect_size.y > 0:
                ref.value = self.state.cur.rect_size.y
            else:
                ref.value = self.requested_height.get_value()
            return ref
        except TypeError:
            pass
        return self.requested_height.get_value()

    @property
    def width(self):
        """
        Requested width for the item.
        
        This property specifies the desired width for the item, though the
        actual width may differ depending on item type and constraints.
        
        Special values:
            - 0: Use default width. May trigger content-fitting for windows or
                containers, or style-based sizing for other items.
            - Positive values: Request a specific width in scaled pixels.
            - Negative values: Request a width that fills the remaining parent space
                minus the absolute value (e.g., -1 means "fill minus 1 scaled pixel").
            - string: A string specification to automatically size the item. See the
                documentation for details on how to use this feature.
        
        Some items may ignore this property or interpret it differently. The
        actual final width in real pixels is available via the rect_size property.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        try:
            ref = RefWidth(self)
            if self.state.cap.has_rect_size and \
               self.state.cur.rect_size.x > 0:
                ref.value = self.state.cur.rect_size.x
            else:
                ref.value = self.requested_width.get_value()
            return ref
        except TypeError:
            pass
        return self.requested_width.get_value()

    @property
    def no_newline(self):
        """
        Controls whether to advance to the next line after rendering.
        
        When True, the cursor position does not advance
        to the next line after this item is drawn, allowing the next item to
        appear on the same line. When False, the cursor advances as normal,
        placing the next item on a new line.
        
        This property is commonly used to create horizontal layouts or to place
        multiple items side-by-side.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.no_newline

    ## setters

    @y.setter
    def y(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if isinstance(value, (int, float)) and float(value) < 0:
            raise ValueError("Negative y values are not supported. Use a string specification instead.")
        set_size(self.requested_y, value)

    @x.setter
    def x(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if isinstance(value, (int, float)) and float(value) < 0:
            raise ValueError("Negative x values are not supported. Use a string specification instead.")
        set_size(self.requested_x, value)

    @height.setter
    def height(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        set_size(self.requested_height, value)

    @width.setter
    def width(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        set_size(self.requested_width, value)

    @no_newline.setter
    def no_newline(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.no_newline = value

    @cython.final
    cdef Vec2 get_requested_size(self) noexcept nogil:
        cdef Vec2 requested_size

        cdef float global_scale = self.context.viewport.global_scale

        requested_size.x = resolve_size(self.requested_width, self)
        requested_size.y = resolve_size(self.requested_height, self)

        if self.requested_width.has_changed() or\
           self.requested_height.has_changed():
            self.context.viewport.force_present()

        # dpi scaling for the fast case of float value
        if not self.requested_width.is_item():
            if requested_size.x > 0 and requested_size.x < 1.:
                requested_size.x = floor(self.context.viewport.parent_size.x * requested_size.x)
            else:
                requested_size.x *= global_scale

        if not self.requested_height.is_item():
            if requested_size.y > 0 and requested_size.y < 1.:
                requested_size.y = floor(self.context.viewport.parent_size.y * requested_size.y)
            else:
                requested_size.y *= global_scale

        requested_size.x = cround(requested_size.x)
        requested_size.y = cround(requested_size.y)

        return requested_size

    cdef void draw(self) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)

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

        if self.focus_requested:
            imgui.SetKeyboardFocusHere(0)
            self.focus_requested = False

        cdef Vec2 cursor_pos_backup = ImVec2Vec2(imgui.GetCursorScreenPos())
        cdef Vec2 pos = cursor_pos_backup
        cdef bint restore_cursor_x = False
        cdef bint restore_cursor_y = False

        if not(self.requested_x.is_item()):
            if self.requested_x.get_value() == 0:
                pass # nothing to do, and most likely path
            else:
                pos.x = pos.x + cround(self.context.viewport.global_scale * self.requested_x.get_value())
        else:
            pos.x = cround(resolve_size(self.requested_x, self))
            restore_cursor_x = True

        if not(self.requested_y.is_item()):
            if self.requested_y.get_value() == 0:
                pass # nothing to do, and most likely path
            else:
                pos.y = pos.y + cround(self.context.viewport.global_scale * self.requested_y.get_value())
        else:
            pos.y = cround(resolve_size(self.requested_y, self))
            restore_cursor_y = True

        if self.requested_x.has_changed() or self.requested_y.has_changed():
            self.context.viewport.force_present()

        imgui.SetCursorScreenPos(Vec2ImVec2(pos))

        # Retrieve current positions
        self.state.cur.pos_to_viewport = ImVec2Vec2(imgui.GetCursorScreenPos())
        self.state.cur.pos_to_window.x = self.state.cur.pos_to_viewport.x - self.context.viewport.window_pos.x
        self.state.cur.pos_to_window.y = self.state.cur.pos_to_viewport.y - self.context.viewport.window_pos.y
        self.state.cur.pos_to_parent.x = self.state.cur.pos_to_viewport.x - self.context.viewport.parent_pos.x
        self.state.cur.pos_to_parent.y = self.state.cur.pos_to_viewport.y - self.context.viewport.parent_pos.y

        # handle fonts
        if self._font is not None:
            self._font.push()

        # themes
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

        if self._font is not None:
            self._font.pop()

        # Restore original scale
        self.context.viewport.global_scale = original_scale 

        # Advance the cursor only for default position (or offset to it)
        pos = ImVec2Vec2(imgui.GetCursorScreenPos())
        if restore_cursor_x:
            pos.x = cursor_pos_backup.x

        if restore_cursor_y:
            pos.y = cursor_pos_backup.y

        imgui.SetCursorScreenPos(Vec2ImVec2(pos))

        if self.no_newline and \
           not(restore_cursor_y):
            imgui.SameLine(0., -1.)

        self.run_handlers()


    cdef bint draw_item(self) noexcept nogil:
        """
        Function to override for the core rendering of the item.
        What is already handled outside draw_item (see draw()):
            - The mutex is held (as is the mutex of the following siblings,
            and the mutex of the parents, including the viewport and imgui
            mutexes)
            - The previous siblings are already rendered
            - Current themes, fonts
            - Widget starting position (GetCursorPos to get it)
            - Focus

        What remains to be done by draw_item:
            - Rendering the item. Set its width, its height, etc
            - Calling update_current_state or manage itself the state
            - Render children if any

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
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
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


cdef extern from * nogil:
    """
bool GetNamedWindowPos(const char* name, ImVec2& pos)
{
    if (ImGuiWindow* window = ImGui::FindWindowByName(name)) {
        pos = window->Pos;
        return true;
    }
    return false;
}

bool BringWindowToBack(const char* name)
{
    if (ImGuiWindow* window = ImGui::FindWindowByName(name))
    {
        ImGui::BringWindowToDisplayBack(window);
        return true;
    }
    return false;
}
    """
    cdef bint GetNamedWindowPos(const char* name, imgui.ImVec2& pos) noexcept
    cdef bint BringWindowToBack(const char* name) noexcept


cdef class Window(uiItem):
    """
    A window with configurable behaviors, appearance, and parent-child relationships.
    
    Windows provide containers for other UI elements and can be styled in various ways.
    They support features like collapsing, resizing, scrolling, and dragging, with
    optional title bars and close buttons.
    
    Windows can be configured as popups (temporary windows that close when clicking 
    outside), modals (blocking windows that require explicit closure), or as primary 
    windows (covering the entire viewport and serving as application backgrounds).
    
    Child items can be added using the standard parent-child mechanisms, and additional
    menu bars can be attached using menubar items.
    """
    def __cinit__(self):
        self.x_update_requested = False
        self.y_update_requested = False
        self.width_update_requested = False
        self.height_update_requested = False
        self._window_flags = imgui.ImGuiWindowFlags_None
        self._main_window = False
        self._modal = False
        self._popup = False
        self._has_close_button = True
        self.state.cur.open = True
        self._collapse_update_requested = False
        self._no_open_over_existing_popup = False
        self._on_close_callback = None
        self._min_size = make_Vec2(100., 100.)
        self._max_size = make_Vec2(30000., 30000.)
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
        self.state.cap.can_be_toggled = True
        self.state.cap.has_content_region = True

    @property
    def no_title_bar(self):
        """
        Hides the title bar of the window.
        
        When enabled, the window will not display its title bar, which includes
        the window title, collapse button, and close button if enabled.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoTitleBar) else False

    @no_title_bar.setter
    def no_title_bar(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoTitleBar
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoTitleBar

    @property
    def no_resize(self):
        """
        Disables resizing of the window by the user.
        
        When enabled, the window cannot be resized by dragging its borders or corners.
        The size can still be changed programmatically.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoResize) else False

    @no_resize.setter
    def no_resize(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoResize
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoResize

    @property
    def no_move(self):
        """
        Prevents the window from being moved by the user.
        
        When enabled, the window cannot be repositioned by dragging the title bar.
        The position can still be changed programmatically.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoMove) else False

    @no_move.setter
    def no_move(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoMove
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoMove

    @property
    def no_scrollbar(self):
        """
        Hides the scrollbars when content overflows.
        
        When enabled, scrollbars will not be shown even when content exceeds the
        window's size. Note that this only affects the visual appearance - scrolling
        via keyboard or mouse wheel remains possible unless disabled separately.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoScrollbar) else False

    @no_scrollbar.setter
    def no_scrollbar(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoScrollbar
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoScrollbar
    
    @property
    def no_scroll_with_mouse(self):
        """
        Disables scrolling the window content with the mouse wheel.
        
        When enabled, the mouse wheel will not scroll the window's content, though
        scrolling via keyboard or programmatic means remains possible.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoScrollWithMouse) else False

    @no_scroll_with_mouse.setter
    def no_scroll_with_mouse(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoScrollWithMouse
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoScrollWithMouse

    @property
    def no_collapse(self):
        """
        Disables collapsing the window by double-clicking the title bar.
        
        When enabled, the window cannot be collapsed (minimized) by double-clicking
        its title bar. The collapsed state can still be changed programmatically.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoCollapse) else False

    @no_collapse.setter
    def no_collapse(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoCollapse
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoCollapse

    @property
    def autosize(self):
        """
        Makes the window automatically resize to fit its contents.
        
        When enabled, the window will continuously adjust its size to fit its
        content area. This can be useful for dialog boxes or panels that should
        always show all their contents without scrolling.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_AlwaysAutoResize) else False

    @autosize.setter
    def autosize(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_AlwaysAutoResize
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_AlwaysAutoResize

    @property
    def no_background(self):
        """
        Makes the window background transparent and removes the border.
        
        When enabled, the window's background color and border will not be drawn,
        allowing content behind the window to show through. Useful for overlay windows
        or custom-drawn windows.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoBackground) else False

    @no_background.setter
    def no_background(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoBackground
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoBackground

    @property
    def no_saved_settings(self):
        """
        Prevents the window from saving its position and size between sessions.
        
        When enabled, the window's position, size, and collapsed state will not be
        saved to or loaded from the ImGui .ini file, keeping the window's appearance
        consistent across application restarts.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoSavedSettings) else False

    @no_saved_settings.setter
    def no_saved_settings(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoSavedSettings
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoSavedSettings

    @property
    def no_mouse_inputs(self):
        """
        Disables mouse input events for the window and its contents.
        
        When enabled, mouse events like clicking, hovering, and dragging will pass
        through the window to items behind it. Items within the window will not
        receive mouse events either.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoMouseInputs) else False

    @no_mouse_inputs.setter
    def no_mouse_inputs(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoMouseInputs
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoMouseInputs

    @property
    def no_keyboard_inputs(self):
        """
        Disables keyboard input and keyboard navigation for the window.
        
        When enabled, the window will not take keyboard focus or respond to keyboard
        navigation commands. Items inside the window can still receive keyboard focus
        and inputs if focused directly.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoNav) else False

    @no_keyboard_inputs.setter
    def no_keyboard_inputs(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoNav
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoNav

    @property
    def menubar(self):
        """
        Controls whether the window displays a menu bar.
        
        When enabled, the window will reserve space for a menu bar at the top.
        Menu items can be added as child elements with the appropriate type.
        The menu bar will appear automatically if any menu child items exist,
        even if this property is set to False.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (self.last_menubar_child is not None) or (self._window_flags & imgui.ImGuiWindowFlags_MenuBar) != 0

    @menubar.setter
    def menubar(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_MenuBar
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_MenuBar

    @property
    def horizontal_scrollbar(self):
        """
        Enables horizontal scrolling for content that exceeds window width.
        
        When enabled, the window will display a horizontal scrollbar when content
        extends beyond the window's width. Otherwise, content will simply be clipped
        at the window's edge.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_HorizontalScrollbar) else False

    @horizontal_scrollbar.setter
    def horizontal_scrollbar(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_HorizontalScrollbar
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_HorizontalScrollbar

    @property
    def no_focus_on_appearing(self):
        """
        Prevents the window from gaining focus when it first appears.
        
        When enabled, the window will not automatically gain keyboard focus when it
        is first shown or when changing from hidden to visible state. This can be
        useful for non-interactive windows or background panels.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoFocusOnAppearing) else False

    @no_focus_on_appearing.setter
    def no_focus_on_appearing(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoFocusOnAppearing
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoFocusOnAppearing

    @property
    def no_bring_to_front_on_focus(self):
        """
        Prevents the window from coming to the front when focused.
        
        When enabled, the window will not rise to the top of the window stack when
        clicked or otherwise focused. This is useful for background windows that
        should remain behind other windows even when interacted with.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoBringToFrontOnFocus) else False

    @no_bring_to_front_on_focus.setter
    def no_bring_to_front_on_focus(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoBringToFrontOnFocus
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoBringToFrontOnFocus

    @property
    def always_show_vertical_scrollvar(self):
        """
        Always displays the vertical scrollbar even when content fits.
        
        When enabled, the vertical scrollbar will always be visible, even when the
        content does not exceed the window height. This can provide a more consistent
        appearance across different content states.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_AlwaysVerticalScrollbar) else False

    @always_show_vertical_scrollvar.setter
    def always_show_vertical_scrollvar(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_AlwaysVerticalScrollbar
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_AlwaysVerticalScrollbar

    @property
    def always_show_horizontal_scrollvar(self):
        """
        Always displays the horizontal scrollbar even when content fits.
        
        When enabled, the horizontal scrollbar will always be visible (if horizontal
        scrolling is enabled), even when the content does not exceed the window width.
        This provides a consistent appearance across different content states.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_AlwaysHorizontalScrollbar) else False

    @always_show_horizontal_scrollvar.setter
    def always_show_horizontal_scrollvar(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_AlwaysHorizontalScrollbar
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_AlwaysHorizontalScrollbar

    @property
    def unsaved_document(self):
        """
        Displays a dot next to the window title to indicate unsaved changes.
        
        When enabled, the window's title bar will display a small indicator dot,
        similar to how many applications mark documents with unsaved changes.
        This is purely visual and does not affect window behavior.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_UnsavedDocument) else False

    @unsaved_document.setter
    def unsaved_document(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_UnsavedDocument
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_UnsavedDocument

    '''
    @property
    def disallow_docking(self):
        """
        Disables docking the window into dock nodes.
        
        When enabled, the window will not participate in ImGui's docking system,
        preventing it from being docked with other windows or into dock spaces.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if (self._window_flags & imgui.ImGuiWindowFlags_NoDocking) else False

    @disallow_docking.setter
    def disallow_docking(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._window_flags &= ~imgui.ImGuiWindowFlags_NoDocking
        if value:
            self._window_flags |= imgui.ImGuiWindowFlags_NoDocking
    '''

    @property
    def no_open_over_existing_popup(self):
        """
        Prevents opening if another popup is already visible.
        
        When enabled for modal and popup windows, the window will not open if another
        popup/modal window is already active. This prevents layering of popups that
        could confuse users.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._no_open_over_existing_popup

    @no_open_over_existing_popup.setter
    def no_open_over_existing_popup(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._no_open_over_existing_popup = value

    @property
    def modal(self):
        """
        Makes the window a modal dialog that blocks interaction with other windows.
        
        When enabled, the window will behave as a modal dialog - it will capture all
        input until closed, preventing interaction with any other windows behind it.
        Modal windows typically have close buttons and must be explicitly dismissed.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._modal

    @modal.setter
    def modal(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._modal = value

    @property
    def popup(self):
        """
        Makes the window a popup that closes when clicking outside it.
        
        When enabled, the window will behave as a popup - it will be centered on
        screen by default and will close automatically when the user clicks outside
        of it. Popups do not have close buttons.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._popup

    @popup.setter
    def popup(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._popup = value

    @property
    def has_close_button(self):
        """
        Controls whether the window displays a close button in its title bar.
        
        When enabled, the window will show a close button in its title bar that
        allows users to close the window. This applies only to regular and
        modal windows, as popup windows do not have close buttons.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._has_close_button and not(self._popup)

    @has_close_button.setter
    def has_close_button(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._has_close_button = value

    @property
    def collapsed(self):
        """
        Controls and reflects the collapsed state of the window.
        
        When True, the window is collapsed (minimized) showing only its title bar.
        When False, the window is expanded showing its full content. This property
        can both be read to detect the current state and written to collapse or
        expand the window.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return not(self.state.cur.open)

    @collapsed.setter
    def collapsed(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.state.cur.open = not(value)
        self._collapse_update_requested = True

    @property
    def on_close(self):
        """
        Callback that will be triggered when the window is closed.
        
        This callback is invoked when the window is closed, either by clicking the
        close button or programmatically. Note that closing a window doesn't destroy
        it, but sets its show property to False. The callback receives the window as
        both source and target parameters.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._on_close_callback

    @on_close.setter
    def on_close(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._on_close_callback = value if isinstance(value, Callback) or value is None else Callback(value)

    @property
    def primary(self):
        """
        Controls whether this window serves as the primary application window.
        
        When set to True, the window becomes the primary window covering the entire
        viewport. It will be drawn behind all other windows, have no decorations,
        and cannot be moved or resized. Only one window can be primary at a time.
        
        Primary windows are useful for implementing main application backgrounds
        or base layouts that other windows will overlay.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._main_window

    @primary.setter
    def primary(self, bint value):
        cdef unique_lock[DCGMutex] m
        cdef unique_lock[DCGMutex] m2
        cdef unique_lock[DCGMutex] m3
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
            # Note: this means the window position will be reset
            # regardless of user changes. We might want to actually
            # use current state
            self._backup_requested_x = self.requested_x
            self._backup_requested_y = self.requested_y
            self._backup_requested_height = self.requested_height
            self._backup_requested_width = self.requested_width
            # Make primary
            self._window_flags = \
                imgui.ImGuiWindowFlags_NoBringToFrontOnFocus | \
                imgui.ImGuiWindowFlags_NoSavedSettings | \
                imgui.ImGuiWindowFlags_NoResize | \
                imgui.ImGuiWindowFlags_NoCollapse | \
                imgui.ImGuiWindowFlags_NoTitleBar | \
                imgui.ImGuiWindowFlags_NoMove
            self.requested_x.set_value(0)
            self.requested_y.set_value(0)
            self.requested_width.set_value(0)
            self.requested_height.set_value(0)
            self.x_update_requested = True
            self.y_update_requested = True
            self.width_update_requested = True
            self.height_update_requested = True
            # Put us in the back
            self.focus_requested = True
        else:
            # Restore previous state
            self._window_flags = self._backup_window_flags
            self.requested_x = self._backup_requested_x
            self.requested_y = self._backup_requested_y
            self.requested_width = self._backup_requested_width
            self.requested_height = self._backup_requested_height
            # Tell imgui to update the window shape
            self.x_update_requested = True
            self.y_update_requested = True
            self.width_update_requested = True
            self.height_update_requested = True
            # Put us in front
            self.focus_requested = True

    @property
    def min_size(self):
        """
        Sets the minimum allowed size for the window.
        
        Defines the minimum width and height the window can be resized to, either
        by the user or programmatically. Values are given as (width, height) in
        logical pixels, and will be multiplied by the DPI scaling factor.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build_v(self._min_size)

    @min_size.setter
    def min_size(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._min_size.x = max(1, value[0])
        self._min_size.y = max(1, value[1])

    @property
    def max_size(self):
        """
        Sets the maximum allowed size for the window.
        
        Defines the maximum width and height the window can be resized to, either
        by the user or programmatically. Values are given as (width, height) in
        logical pixels, and will be multiplied by the DPI scaling factor.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return Coord.build_v(self._max_size)

    @max_size.setter
    def max_size(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._max_size.x = max(1, value[0])
        self._max_size.y = max(1, value[1])

    # Copy of the uiItem propertties, but with some flags added
    @property
    def x(self):
        """
        Requested horizontal position of the item.
        
        This property specifies the desired horizontal position of the item.

        By default, items are positioned inside their parent container,
        from top to bottom, left-aligned. In other words the default
        position for the item is below the previous one. This default is
        altered by the `no_newline` property (applied on the previous item),
        which will place the item after the previous one on the same
        horizontal line (with the theme's itemSpacing applied).

        Special values:
            - 0: Use default horizontal position (see explanation above).
            - Positive values: Request a specific position in scaled pixels,
                relative to the default horizontal position. For instance,
                10 means "position 10 scaled pixels to the right of the
                default position".
            - Negative values: Unsupported for now
            - string: A string specification to automatically position the item. See the
                documentation for details on how to use this feature.

        Note when a string specification is used, the cursor will not be changed.
        If you want several items to be positioned next to each other at a specific
        target position, position a Layout item.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        ref = RefX0(self)
        if self.state.cur.pos_to_viewport.x > 0:
            ref.value = self.state.cur.pos_to_viewport.x
        else:
            ref.value = self.requested_x.get_value()
        return ref

    @property
    def y(self):
        """
        Requested vertical position of the item.
        
        This property specifies the desired vertical position of the item.

        By default, items are positioned inside their parent container,
        from top to bottom, left-aligned. In other words the default
        position for the item is below the previous one (with the theme's
        itemSpacing applied). This default is altered by the `no_newline`
        property (applied on the previous item), which will place the item
        after the previous one on the same horizontal line.

        Special values:
            - 0: Use default vertical position (see explanation above).
            - Positive values: Request a specific position in scaled pixels,
                relative to the default vertical position. For instance,
                10 means "position 10 scaled pixels below the default position".
            - Negative values: Unsupported for now
            - string: A string specification to automatically position the item. See the
                documentation for details on how to use this feature.

        Note when a string specification is used, the cursor will not be changed.
        If you want several items to be positioned next to each other at a specific
        target position, position a Layout item.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        ref = RefY0(self)
        if self.state.cur.pos_to_viewport.y > 0:
            ref.value = self.state.cur.pos_to_viewport.y
        else:
            ref.value = self.requested_y.get_value()
        return ref

    @property
    def height(self):
        """
        Requested height for the item.
        
        This property specifies the desired height for the item, though the
        actual height may differ depending on item type and constraints. 
        
        Special values:
            - 0: Use default height. May trigger content-fitting for windows or
                containers, or style-based sizing for other items.
            - Positive values: Request a specific height in scaled pixels.
            - Negative values: Request a height that fills the remaining parent space
                minus the absolute value (e.g., -1 means "fill minus 1 scaled pixel").
            - string: A string specification to automatically size the item. See the
                documentation for details on how to use this feature.
        
        Some items may ignore this property or interpret it differently. The
        actual final height in real pixels is available via the rect_size property.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        ref = RefHeight(self)
        if self.state.cur.rect_size.y > 0:
            ref.value = self.state.cur.rect_size.y
        else:
            ref.value = self.requested_height.get_value()
        return ref

    @property
    def width(self):
        """
        Requested width for the item.
        
        This property specifies the desired width for the item, though the
        actual width may differ depending on item type and constraints.
        
        Special values:
            - 0: Use default width. May trigger content-fitting for windows or
                containers, or style-based sizing for other items.
            - Positive values: Request a specific width in scaled pixels.
            - Negative values: Request a width that fills the remaining parent space
                minus the absolute value (e.g., -1 means "fill minus 1 scaled pixel").
            - string: A string specification to automatically size the item. See the
                documentation for details on how to use this feature.
        
        Some items may ignore this property or interpret it differently. The
        actual final width in real pixels is available via the rect_size property.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        ref = RefWidth(self)
        if self.state.cur.rect_size.x > 0:
            ref.value = self.state.cur.rect_size.x
        else:
            ref.value = self.requested_width.get_value()
        return ref

    @y.setter
    def y(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if isinstance(value, (int, float)) and float(value) < 0:
            raise ValueError("Negative y values are not supported. Use a string specification instead.")
        set_size(self.requested_y, value)
        self.y_update_requested = True

    @x.setter
    def x(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if isinstance(value, (int, float)) and float(value) < 0:
            raise ValueError("Negative x values are not supported. Use a string specification instead.")
        set_size(self.requested_x, value)
        self.x_update_requested = True

    @height.setter
    def height(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        set_size(self.requested_height, value)
        self.height_update_requested = True

    @width.setter
    def width(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        set_size(self.requested_width, value)
        self.width_update_requested = True

    cdef void draw(self) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)

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

        cdef bint focus_requested = self.focus_requested
        if focus_requested:
            if self._main_window:
                if BringWindowToBack(self._imgui_label.c_str()):
                    # if failed (window doesn't exist), retry next frame
                    self.focus_requested = False
                else:
                    self.context.viewport.redraw_needed = True
            else:
                imgui.SetNextWindowFocus()
                self.focus_requested = False

        cdef bint no_move = (self._window_flags & imgui.ImGuiWindowFlags_NoMove) == imgui.ImGuiWindowFlags_NoMove
        cdef imgui.ImVec2 current_pos, new_pos
        cdef float visibility_padding, draggable_area_height, clamp_min, clamp_max
        if GetNamedWindowPos(self._imgui_label.c_str(), current_pos):
            # Window already exists, with current_pos
            # Note: current_pos differs from state.cur.pos_to_viewport
            # in the case the window was moved by user input (this is
            # resolved at the end of the frame)
            new_pos = current_pos
            if no_move and not self.x_update_requested:
                # We shouldn't move relative to the parent. While imgui enforces
                # no motion relative to the viewport, we set here the pos manually
                # to enforce it against the parent which may be a window layout.
                # We do not read requested_x because the no_move flag may
                # have been set after the window was moved.
                new_pos.x = self.context.viewport.parent_pos.x + self.state.prev.pos_to_parent.x
                # However string positioning overrides that
                if self.requested_x.is_item():
                    new_pos.x = resolve_size(self.requested_x, self)
            elif self.x_update_requested:
                # There has been a request to update the x position
                if self.requested_x.is_item():
                    new_pos.x = resolve_size(self.requested_x, self)
                else:
                    new_pos.x = self.context.viewport.parent_pos.x + \
                        cround(self.context.viewport.global_scale * self.requested_x.get_value())
                self.x_update_requested = False
            else:
                # keep imgui position, but apply clamping to the parent (formula from imgui)
                visibility_padding = fmax(imgui.GetStyle().DisplayWindowPadding.x, imgui.GetStyle().DisplaySafeAreaPadding.x)
                clamp_min = self.context.viewport.parent_pos.x + visibility_padding - self.state.prev.rect_size.x
                clamp_max = self.context.viewport.parent_pos.x + self.context.viewport.parent_size.x - visibility_padding
                new_pos.x = fmin(fmax(new_pos.x, clamp_min), clamp_max)

            # same for y:
            if no_move and not self.y_update_requested:
                new_pos.y = self.context.viewport.parent_pos.y + self.state.prev.pos_to_parent.y
                if self.requested_y.is_item():
                    new_pos.y = resolve_size(self.requested_y, self)
            elif self.y_update_requested:
                if self.requested_y.is_item():
                    new_pos.y = resolve_size(self.requested_y, self)
                else:
                    new_pos.y = self.context.viewport.parent_pos.y + \
                        cround(self.context.viewport.global_scale * self.requested_y.get_value())
                self.y_update_requested = False
            else:
                # keep imgui position, but apply clamping to the parent (formula from imgui)
                visibility_padding = fmax(imgui.GetStyle().DisplayWindowPadding.y, imgui.GetStyle().DisplaySafeAreaPadding.y)
                draggable_area_height = imgui.GetFontSize() + 2. * imgui.GetStyle().FramePadding.y
                if (self._window_flags & imgui.ImGuiWindowFlags_NoTitleBar) == imgui.ImGuiWindowFlags_NoTitleBar:
                    draggable_area_height = fmax(draggable_area_height, self.state.prev.rect_size.y)
                clamp_min = self.context.viewport.parent_pos.y + visibility_padding - draggable_area_height
                clamp_max = self.context.viewport.parent_pos.y + self.context.viewport.parent_size.y - visibility_padding
                # Note: we use the parent size, not the viewport size
                new_pos.y = fmin(fmax(new_pos.y, clamp_min), clamp_max)


            if new_pos.x != current_pos.x or new_pos.y != current_pos.y:
                # There has been a change to show the user.
                self.context.viewport.force_present()

            imgui.SetNextWindowPos(new_pos, imgui.ImGuiCond_Always)

        elif self.x_update_requested or self.y_update_requested:
            # If the window does not exist, we need to set the position
            # relative to the parent, which is the viewport in this case.
            # Note in theory the window might not exist for imgui, but have a nonzero
            # prev field, for instance if the window was hidden for some frames.
            # in practice that is not the case, as imgui never frees the window

            # We cannot set just x or just y, so we set both
            if self.requested_x.is_item():
                new_pos.x = resolve_size(self.requested_x, self)
            else:
                new_pos.x = self.context.viewport.parent_pos.x + \
                    cround(self.context.viewport.global_scale * self.requested_x.get_value())

            if self.requested_y.is_item():
                new_pos.y = resolve_size(self.requested_y, self)
            else:
                new_pos.y = self.context.viewport.parent_pos.y + \
                    cround(self.context.viewport.global_scale * self.requested_y.get_value())

            self.x_update_requested = False
            self.y_update_requested = False
            self.context.viewport.force_present() # maybe self.context.redraw_needed = True as well ?

            imgui.SetNextWindowPos(new_pos, imgui.ImGuiCond_Always)

        cdef Vec2 requested_size = self.get_requested_size()
        cdef bint no_resize = (self._window_flags & imgui.ImGuiWindowFlags_NoResize) == imgui.ImGuiWindowFlags_NoResize

        if requested_size.x == 0:
            requested_size.x = self.context.viewport.parent_size.x
            if no_resize:
                self.width_update_requested = True
        if requested_size.y == 0:
            requested_size.y = self.context.viewport.parent_size.y
            if no_resize:
                self.height_update_requested = True

        if self.requested_width.is_item() and no_resize:
            # Always take into account the formula when noresize is set
            self.width_update_requested = True

        if self.requested_height.is_item() and no_resize:
            self.height_update_requested = True

        if not self.width_update_requested:
            # will fill the previous value here for the case we
            # call SetNextWindowSize for the other dimension only
            requested_size.x = self.state.prev.rect_size.x
        if not self.height_update_requested:
            requested_size.y = self.state.prev.rect_size.y

        if self.width_update_requested or self.height_update_requested:
            imgui.SetNextWindowSize(Vec2ImVec2(requested_size),
                                    imgui.ImGuiCond_Always)

            self.width_update_requested = False
            self.height_update_requested = False

        if self._collapse_update_requested:
            imgui.SetNextWindowCollapsed(not(self.state.cur.open), imgui.ImGuiCond_Always)
            self._collapse_update_requested = False

        cdef Vec2 min_size = self._min_size
        cdef Vec2 max_size = self._max_size
        #if self._dpi_scaling:
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

        # handle fonts
        if self._font is not None:
            self._font.push()

        # themes
        if self._theme is not None:
            self._theme.push()

        cdef bint visible = True
        # Modal/Popup windows must be manually opened
        if self._modal or self._popup:
            if (self._show_update_requested or focus_requested)\
               and self._show:
                self._show_update_requested = False
                imgui.OpenPopup(self._imgui_label.c_str(),
                                (imgui.ImGuiPopupFlags_NoOpenOverExistingPopup if self._no_open_over_existing_popup else imgui.ImGuiPopupFlags_None)
                                | imgui.ImGuiPopupFlags_NoReopen)

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
        cdef Vec2 parent_pos_backup

        if visible:
            parent_size_backup = self.context.viewport.parent_size
            parent_pos_backup = self.context.viewport.parent_pos
            # Retrieve the full region size before the cursor is moved.
            self.state.cur.content_region_size = ImVec2Vec2(imgui.GetContentRegionAvail())
            self.state.cur.content_pos = ImVec2Vec2(imgui.GetCursorScreenPos())

            self.context.viewport.window_pos = self.state.cur.content_pos
            self.context.viewport.parent_pos = self.state.cur.content_pos
            self.context.viewport.parent_size = self.state.cur.content_region_size

            draw_menubar_children(self) # TODO: should we shift content pos after the menubar ?
            draw_ui_children(self)

            self.context.viewport.parent_size = parent_size_backup
            self.context.viewport.parent_pos = parent_pos_backup
            self.context.viewport.window_pos = parent_pos_backup 

        if visible:
            # Set current states
            self.state.cur.rendered = True
            self.state.cur.hovered = imgui.IsWindowHovered(imgui.ImGuiHoveredFlags_None)
            self.state.cur.focused = imgui.IsWindowFocused(imgui.ImGuiFocusedFlags_None)
            self.state.cur.rect_size = ImVec2Vec2(imgui.GetWindowSize())
            self.state.cur.pos_to_viewport = ImVec2Vec2(imgui.GetWindowPos())
            self.state.cur.pos_to_window.x = self.state.cur.pos_to_viewport.x - self.context.viewport.window_pos.x
            self.state.cur.pos_to_window.y = self.state.cur.pos_to_viewport.y - self.context.viewport.window_pos.y
            self.state.cur.pos_to_parent.x = self.state.cur.pos_to_viewport.x - self.context.viewport.parent_pos.x
            self.state.cur.pos_to_parent.y = self.state.cur.pos_to_viewport.y - self.context.viewport.parent_pos.y
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
    Base class for plot children with rendering capabilities.
    
    Provides the foundation for all plot elements like lines, scatter plots, 
    and bars. These elements can be attached to a parent plot and will be 
    rendered according to their configuration.
    
    Plot elements can be assigned to specific axes pairs, allowing for 
    multiple data series with different scales to coexist on the same plot.
    They also support themes for consistent visual styling.
    """
    def __cinit__(self):
        #self._imgui_label = string_from_bytes(bytes(b'###%ld'% self.uuid))
        set_uuid_label(self._imgui_label, self.uuid)
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
        Controls whether the plot element is visible.
        
        When set to False, the element is not rendered and its callbacks are not
        executed. This allows for temporarily hiding plot elements without
        removing them from the plot hierarchy.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._show

    @show.setter
    def show(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if not(value) and self._show:
            self.set_hidden_and_propagate_to_children_no_handlers()
        self._show = value

    @property
    def axes(self):
        """
        The X and Y axes that the plot element is attached to.
        
        Returns a tuple of (X axis, Y axis) identifiers that determine which
        coordinate system this element will use. Each plot can have up to three
        X axes and three Y axes, allowing for multiple scales on the same plot.
        Default is (X1, Y1).
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return (make_Axis(self._axes[0]), make_Axis(self._axes[1]))

    @axes.setter
    def axes(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef int32_t axis_x, axis_y
        axis_x = check_Axis(value[0])
        axis_y = check_Axis(value[1])
        self._axes[0] = axis_x
        self._axes[1] = axis_y

    @property
    def label(self):
        """
        Text label for the plot element.
        
        This label is used in the plot legend and for tooltip identification.
        Setting a meaningful label helps users understand what each element
        represents in a multi-element plot.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._user_label

    @label.setter
    def label(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._user_label = ""
        else:
            self._user_label = value
        # Using ### means that imgui will ignore the user_label for
        # its internal ID of the object. Indeed else the ID would change
        # when the user label would change
        #self._imgui_label = string_from_bytes(bytes(self._user_label, 'utf-8') + bytes(b'###%ld'% self.uuid))
        set_composite_label(self._imgui_label, self._user_label, self.uuid)

    @property
    def theme(self):
        """
        Visual theme applied to the plot element.
        
        The theme controls the appearance of the plot element, including line
        colors, point styles, fill patterns, and other visual attributes. A theme
        can be shared between multiple plot elements for consistent styling.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._theme

    @theme.setter
    def theme(self, baseTheme value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._theme = value

    cdef void draw(self) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)

        # Check the axes are enabled
        if not(self._show) or \
           not(self.context.viewport.enabled_axes[self._axes[0]]) or \
           not(self.context.viewport.enabled_axes[self._axes[1]]):
            self.propagate_hidden_state_to_children_with_handlers()
            return

        # push theme
        if self._theme is not None:
            self._theme.push()

        implot.SetAxes(self._axes[0], self._axes[1])

        self.draw_element()

        # pop theme, font
        if self._theme is not None:
            self._theme.pop()

    cdef void draw_element(self) noexcept nogil:
        return


cdef class AxisTag(baseItem):
    """
    Visual marker with text attached to a specific coordinate on a plot axis.
    
    Axis tags provide a way to highlight and label specific values on a plot axis.
    Tags appear as small markers with optional text labels and background colors.
    They can be used to mark thresholds, important values, or add explanatory
    annotations directly on the axes.
    
    Tags can only be attached as children to plot axes, and their position is
    specified as a coordinate value on that axis.
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
        Controls the visibility of the axis tag.
        
        When set to True, the tag is visible on the axis. When set to False,
        the tag is not rendered, though it remains in the object hierarchy.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.show

    @show.setter
    def show(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.show = value

    @property
    def bg_color(self):
        """
        Background color of the tag as RGBA values.
        
        A value of 0 (default) means no background color will be applied, and
        ThemeStyleImPlot's AxisText will be used for the text color. When a background
        color is specified, the text color automatically adjusts to white or
        black for optimal contrast with the background.
        
        Color values are represented as a list of RGBA components in the [0,1]
        range.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef float[4] color
        unparse_color(color, self.bg_color)
        return list(color)

    @bg_color.setter
    def bg_color(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.bg_color = parse_color(value)

    @property
    def coord(self):
        """
        Position of the tag along the parent axis.
        
        Specifies the coordinate value where the tag should be placed on the
        parent axis. The coordinate is in the same units as the axis data
        (not in pixels or screen coordinates).
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.coord

    @coord.setter
    def coord(self, double value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.coord = value

    @property
    def text(self):
        """
        Text label displayed with the axis tag.
        
        The text is rendered alongside the tag marker. If no text is provided,
        only the marker itself will be shown. Formatting options such as color
        and size are controlled by the tag's style properties rather than
        embedded in this text.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return string_to_str(self.text)

    @text.setter
    def text(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.text = string_from_str(value)


cdef class baseFont(baseItem):
    def __cinit__(self, context, *args, **kwargs):
        self.can_have_sibling = False

    cdef void push(self) noexcept nogil:
        return

    cdef void pop(self) noexcept nogil:
        return


cdef class baseTheme(baseItem):
    """
    Base theme element containing visual style settings.
    
    A theme defines a set of visual properties that can be applied to UI elements
    to control their appearance. Themes can target different backends (ImGui, ImPlot) and different aspects (colors, styles).
    
    Themes are applied hierarchically - a theme attached to a parent item will 
    affect all its children unless overridden. Multiple themes can be combined,
    with more specific themes taking precedence over more general ones.
    
    Themes can be conditionally applied based on element states (enabled/disabled,
    hovered/unhovered) and element categories (window, plot, node, etc).
    """
    def __init__(self, context, **kwargs):
        self._enabled = kwargs.pop("enabled", self._enabled)
        self._enabled = kwargs.pop("show", self._enabled)
        baseItem.__init__(self, context, **kwargs)
    def __cinit__(self):
        self.element_child_category = child_type.cat_theme
        self.can_have_sibling = True
        self._enabled = True
    def configure(self, **kwargs):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._enabled = kwargs.pop("enabled", self._enabled)
        self._enabled = kwargs.pop("show", self._enabled)
        m.unlock()
        baseItem.configure(self, **kwargs)
    @property
    def enabled(self):
        """
        Controls whether the theme is currently active.
        
        When set to False, the theme will not be applied when its push() method is
        called, effectively disabling its visual effects without removing it from
        the item hierarchy.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._enabled
    @enabled.setter
    def enabled(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._enabled = value
    # should be always defined by subclass
    cdef void push(self) noexcept nogil:
        return
    cdef void pop(self) noexcept nogil:
        return

