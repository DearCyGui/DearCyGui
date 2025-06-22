import asyncio
from collections.abc import Callable, Coroutine
from concurrent.futures import Executor, Future
import dearcygui as dcg
import math
import threading
import time
import warnings

class _SimpleBarrier:
    """
    A simple barrier that can be set/checked only once,
    and goes back to a pool after being checked.
    """
    def __init__(self, barrier_pool: list['_SimpleBarrier'], pool_mutex: threading.Lock) -> None:
        self._set = False
        self._checked = False
        self._barrier_pool = barrier_pool
        self._pool_mutex = pool_mutex

    def _discard(self) -> None:
        """
        Discard the barrier, returning it to the pool.
        This method is called when the barrier is no longer needed.
        """
        # Reset the barrier
        self._set = False
        self._checked = False
        # Return the barrier to the pool
        with self._pool_mutex:
            self._barrier_pool.append(self)

    def check_and_discard(self) -> bool:
        """
        Check if the barrier is set.
        
        Returns:
            bool: True if the barrier is set, False otherwise.
        """
        value = self._set
        if value:
            self._discard()
        else:
            self._checked = True
        return value

    def set(self) -> None:
        """
        Set the barrier, allowing it to be checked.
        """
        if self._checked:
            # The barrier has been checked already,
            # no need to set it.
            self._discard()
            return
        self._set = True
        # Note: theorically, we could miss some _discard() calls here,
        # as _checked and _value may modify concurrently.
        # But this is not a problem as the barrier is meant to be used
        # in a single-threaded context (the mutex being here mainly to
        # protect the unlikely case it is not in this scenario).
        # In the multithreaded we don't care what check_and_discard returns,
        # and in the worst case, we will miss calling _discard and need
        # to create a new barrier.

async def _async_task(future: Future | asyncio.Future | None,
                      barrier: _SimpleBarrier | None,
                      fn: Callable | Coroutine, args: tuple, kwargs: dict) -> None:
    """
    Internal function to run a callable in the asyncio event loop.
    This function is designed to be run as a task in the event loop,
    allowing it to handle both synchronous and asynchronous functions.

    Args:
        future: A Future object to set the result or exception.
        barrier: An optional _SimpleBarrier to control execution flow.
        fn: The callable to execute.
        args: Positional arguments to pass to the callable.
        kwargs: Keyword arguments to pass to the callable.
    """
    if barrier is not None and not barrier.check_and_discard():
        # The barrier here is to shield ourselves from eager task execution,
        # as we don't want the function to run in the same
        # thread immediately (unsafe to change the item
        # attributes when frame rendering isn't finished).
        # we do not need to recheck the barrier after the first await
        await asyncio.sleep(0)
    try:
        if callable(fn):
            # For functions, call them and handle returned coroutines
            result = fn(*args, **kwargs)
            # If the function returned a coroutine (async function), await it
            if asyncio.iscoroutine(result):
                result = await result
        elif asyncio.iscoroutine(fn):
            if len(args) > 0 or len(kwargs) > 0:
                warnings.warn(
                    "Coroutine passed directly to submit with args or kwargs. "
                    "Ignoring args and kwargs.",
                    RuntimeWarning
                )
            # If the function is a coroutine, await it directly
            result = await fn
        else:
            raise TypeError(f"Unsupported callable type: {type(fn)}. "
                            "Must be a coroutine function, regular function, or coroutine.")
        # Set the result if not cancelled
        if future and not future.cancelled():
            future.set_result(result)
    except Exception as exc:
        if future and not future.cancelled():
            future.set_exception(exc)


def _create_task(loop: asyncio.AbstractEventLoop,
                 future: Future | None, fn: Callable | Coroutine, args: tuple,
                 kwargs: dict) -> asyncio.Task:
    """
    Helper function to instantiate an awaitable for the
    task in the asyncio event loop
    """
    task = loop.create_task(_async_task(future, None, fn, args, kwargs))

    if future is not None:
        # Setup bi-directional cancellation propagation
        def cancel_task_if_not_done(task=task):
            if not task.done():
                task.cancel()

        future.add_done_callback(
            lambda f: loop.call_soon_threadsafe(cancel_task_if_not_done) if f.cancelled() else None
        )
        
        task.add_done_callback(
            lambda t: future.cancel() if t.cancelled() and not future.done() else None
        )
        
        # Prevent task from being garbage collected before completion
        # Unsure if needed, as task is referenced in the lambda above
        future.task = task
    
    return task


class AsyncPoolExecutor:
    """
    A ThreadPoolExecutor-line implementation that executes callbacks
    in the asyncio event loop.
    
    This executor forwards all submitted tasks to the asyncio
    event loop instead of executing them in separate threads,
    enabling seamless integration with asyncio-based applications.
    """
    
    def __init__(self, loop: asyncio.AbstractEventLoop | None = None):
        """Initialize the executor with standard ThreadPoolExecutor parameters."""
        if loop is None:
            self._loop = asyncio.get_event_loop()
            if self._loop is None:
                raise RuntimeError("No event loop found. Please set an event loop before using AsyncPoolExecutor.")
        else:
            if not isinstance(loop, asyncio.AbstractEventLoop):
                raise TypeError("Expected an instance of asyncio.AbstractEventLoop.")
            self._loop = loop
        self._barrier_pool = []
        self._pool_mutex = threading.Lock()
        self._loop_thread_id = None
        def _set_loop_thread_id() -> None:
            """Set the thread ID of the loop to the current thread."""
            self._loop_thread_id = threading.get_ident()
        self._loop.call_soon(_set_loop_thread_id)

    def __del__(self) -> None:
        return

    def shutdown(self, *args, **kwargs) -> None:
        return

    def map(self, *args, **kwargs):
        raise NotImplementedError("AsyncPoolExecutor does not support map operation.")

    def __enter__(self):
        raise NotImplementedError("AsyncPoolExecutor cannot be used as a context manager.")

    @property
    def loop(self) -> asyncio.AbstractEventLoop:
        """
        Get the event loop associated with this executor.
        
        Returns:
            asyncio.AbstractEventLoop: The event loop used by this executor.

        This can be used to access the loop directly, for instance
        by appending tasks from another thread (using `loop.call_soon_threadsafe()`).
        """
        return self._loop

    def submit(self, fn: Callable | Coroutine, *args, **kwargs) -> asyncio.Future:
        """
        Submit a callable to be executed in the asyncio event loop.
        
        Unlike the standard ThreadPoolExecutor, this doesn't actually use a thread
        but instead schedules the function to run in the asyncio event loop.

        Since this call is meant to be run during frame rendering,
        it guarantees that no eager execution of the task will happen.
        In other words, the task is not started yet when this method returns.
        
        Returns:
            asyncio.Future: A future representing the execution of the callable.
        """
        if self._loop_thread_id != threading.get_ident() and self._loop_thread_id is not None:
            raise RuntimeError(
                f"Cannot submit tasks from a different thread. "
                f"Current thread ID: {threading.get_ident()}, "
                f"Expected thread ID: {self._loop_thread_id}"
            )

        # Create a future in the current event loop
        future = self._loop.create_future()

        # If we are using eager task factory, we need to use a barrier
        # to ensure the function is not executed immediately in the same thread
        # (which would be unsafe if we are in the middle of rendering a frame)
        with self._pool_mutex:
            if self._barrier_pool:
                barrier = self._barrier_pool.pop()
            else:
                barrier = _SimpleBarrier(self._barrier_pool, self._pool_mutex)

        # Schedule the coroutine execution in the event loop
        self._loop.create_task(_async_task(future, barrier, fn, args, kwargs))

        return future

    def submit_threadsafe(self, fn: Callable | Coroutine, *args, **kwargs) -> Future:
        """
        Submit a callable to be executed in the asyncio event loop
        represented by this `AsyncPoolExecutor`.
        
        The `submit` method can only be called from the thread
        running the event loop. It returns an `asyncio.Future`.
        
        Two alternatives are available to submit tasks from other threads:
        - Use the `loop` property and `loop.call_soon_threadsafe()` to
            schedule a task in the event loop.
        - Call `submit_threadsafe()`. For convenience, this method
            is a drop-in replacement for the standard `ThreadPoolExecutor.submit()`
            method, and thus returns a `concurrent.futures.Future`.

        One use case of scheduling tasks in the `AsyncPoolExecutor` from another thread
        is if you need to run functions that require to be in the thread
        running the event loop (such as creating a new context and some `dcg.os` functions),
        """

        future = Future()

        self._loop.call_soon_threadsafe(_create_task, self._loop, future, fn, args, kwargs)

        return future

if hasattr(asyncio, 'EventLoop'):
    _DefaultEventLoop = asyncio.EventLoop
else:
    # Older versions of Python
    _DefaultEventLoop = asyncio.SelectorEventLoop

try:
    # If available, use uvloop for better performance
    import uvloop
    _DefaultEventLoop = uvloop.Loop
except:
    pass

class BatchingEventLoop(_DefaultEventLoop):
    """
    Loop optimized for batching events and tasks.

    Used with AsyncThreadPoolExecutor, it can improve performance
    when having many async callbacks with timed animations. It works
    by quantizing the time at which tasks are scheduled, resulting in
    tasks with close time deadlines being grouped together.
    This reduces the overhead of thread context switching and GIL
    contention.
    """
    
    def __init__(self, time_slot=0.010) -> None:
        """
        Initialize the quantized event loop.
        
        Args:
            time_slot: Time quantization in seconds (default: 0.010s = 10ms)
        """
        super().__init__()
        self.time_slot = time_slot  # Time quantization in seconds
        self.quantize_threshold = min(0.001, 0.1 * time_slot)  # Don't quantize delays shorter than this
        if hasattr(asyncio, 'eager_task_factory'):
            self.set_task_factory(asyncio.eager_task_factory) # small perf gain
    
    @classmethod
    def factory(cls, time_slot=0.010):
        """
        Returns a factory function that creates quantized event loops.

        Args:
            time_slot: Time quantization in seconds (default: 0.010s = 10ms)
                
        Returns:
            Callable: A factory function that creates properly configured event loops
        """
        def create_loop():
            return cls(time_slot)
        return create_loop
    
    def call_at(self, when, callback, *args, **kwargs):
        """Override call_at to quantize the scheduling time."""
        now = self.time()
        delay = when - now

        # Only quantize if the delay is above our threshold
        if delay < self.quantize_threshold:
            # For immediate or very short delays, don't quantize
            return super().call_at(when, callback, *args, **kwargs)

        quantized_when = math.ceil(when / self.time_slot) * self.time_slot

        # Use the quantized time instead
        return super().call_at(quantized_when, callback, *args, **kwargs)
    
    def call_later(self, delay, callback, *args, **kwargs):
        # Only quantize if the delay is above our threshold
        if delay < self.quantize_threshold:
            return super().call_later(delay, callback, *args, **kwargs)

        # Quantize the target time
        current_time = self.time()
        when = current_time + delay
        quantized_when = math.ceil(when / self.time_slot) * self.time_slot
        delay = quantized_when - current_time

        # Use the quantized time instead
        return super().call_later(delay, callback, *args, **kwargs)


class AsyncThreadPoolExecutor(Executor):
    """
    A threaded concurrent.future.Executor that executes callbacks in a
    single secondary thread with its own event loop.

    It can be used as a drop-in replacement of the default
    context queue. The main difference is that this
    executor enables running `async def` callbacks.

    This executor runs an asyncio event loop in a dedicated
    thread and forwards all submitted tasks to that loop,
    enabling asyncio operations to run off the main thread.

    If available, uvloop is used as the event loop implementation,
    in which case performance of normal callbacks are very similar
    to that of the default ThreadPoolExecutor queue.

    The default loop factory is
    `dearcygui.utils.asyncio_helpers.BatchingEventLoop.factory()`,
    a custom event loop that batches tasks by quantizing
    the scheduling time (default accuracy is 10ms). It is an
    optimized event loop when having many async callbacks
    running with timed animations. The quantization only
    affects operations such as `asyncio.sleep()`, etc.
    """

    def __init__(self, loop_factory: Callable[[], asyncio.AbstractEventLoop] = None):
        self.loop_factory = loop_factory or BatchingEventLoop.factory()
        if not callable(self.loop_factory):
            raise TypeError("loop_factory must be a callable that returns an asyncio.AbstractEventLoop instance.")
        self._thread_loop = None
        self._shutdown = False
        self._running = False
        self._thread = None
        self._start_background_loop()

    # Replace ThreadPoolExecutor completly

    def map(self, *args, **kwargs):
        raise NotImplementedError("AsyncThreadPoolExecutor does not support map operation.")

    def __enter__(self):
        raise NotImplementedError("AsyncThreadPoolExecutor cannot be used as a context manager.")

    def _thread_worker(self) -> None:
        """Background thread that runs its own event loop."""
        # Create a new event loop for this thread
        if self.loop_factory is not asyncio.new_event_loop:
            self._thread_loop = self.loop_factory()
            if self._thread_loop is None or not isinstance(self._thread_loop, asyncio.AbstractEventLoop):
                warnings.warn(
                    "The provided loop_factory did not return a valid asyncio event loop. "
                    "Using asyncio.new_event_loop instead.",
                    RuntimeWarning
                )
                self._thread_loop = asyncio.new_event_loop()
            if self._thread_loop.is_running():
                warnings.warn(
                    "The provided loop_factory returned an already running event loop. "
                    "Using asyncio.new_event_loop instead.",
                    RuntimeWarning
                )
                self._thread_loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self._thread_loop)
        else:
            self._thread_loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self._thread_loop)
            # for speed, use eager task factory
            if hasattr(asyncio, 'eager_task_factory'):
                self._thread_loop.set_task_factory(asyncio.eager_task_factory)

        self._running = True
        try:
            self._thread_loop.run_forever()
        finally:
            self._running = False
            self._thread_loop.close()
            self._thread_loop = None

    def _cancel_all_tasks(self) -> None:
        """Cancel all tasks in the thread's event loop. Called in the thread"""
        if self._thread_loop is None or self._thread is None:
            return

        # Cancel all tasks in the loop
        tasks = asyncio.all_tasks(self._thread_loop)

        # If we are in the thread itself,
        # do not cancel ourselves
        if threading.get_ident() == self._thread.ident:
            current_task = asyncio.current_task(self._thread_loop)
            tasks = [task for task in tasks if task is not current_task]

        for task in tasks:
            task.cancel()

        # Shutdown async generators
        async def run_shutdown():
            await self._thread_loop.shutdown_asyncgens()
        
        self._thread_loop.create_task(run_shutdown())

    def _start_background_loop(self) -> None:
        """Start the background thread with its event loop."""
        if self._thread is not None:
            return

        self._thread = threading.Thread(
            target=self._thread_worker,
            daemon=True,
            name="AsyncThreadPoolExecutor"
        )
        self._thread.start()

        # Wait for the thread loop to be ready
        timer = time.monotonic()
        while not(self._running):
            if not self._thread.is_alive():
                raise RuntimeError("Background thread failed to start")
            time.sleep(0.)  # Avoid busy-waiting
            if time.monotonic() - timer > 1.0:
                raise RuntimeError("Background thread did not start within 1 second")

    def submit(self, fn: Callable | Coroutine, *args, **kwargs) -> Future:
        """
        Submit a callable to be executed in the background thread's event loop.

        Args:
            fn: The callable to execute
            *args: Arguments to pass to the callable
            **kwargs: Keyword arguments to pass to the callable

        Returns:
            concurrent.futures.Future: A future representing the execution of the callable.
        """
        if self._shutdown:
            raise RuntimeError("Cannot schedule new futures after shutdown")

        if not self._running:
            raise RuntimeError(f"Executor is not running, cannot submit {fn}, args={args}, kwargs={kwargs}")

        future = Future()

        # Schedule the function to run in the thread's event loop
        self._thread_loop.call_soon_threadsafe(_create_task, self._thread_loop, future, fn, args, kwargs)

        return future

    def shutdown(self, wait: bool = True, *args, cancel_futures=False, **kwargs) -> None:
        """
        Shutdown the executor, stopping the background thread and event loop.

        Args:
            wait: If True, blocks until all pending futures are done.
            cancel_futures: If True, cancels all pending futures that haven't started.

        After shutdown, calls to submit() will raise RuntimeError.
        
        This method is thread-safe and can be called multiple times.
        It can also be called from within a task running in the executor, in which
        case the wait parameter is ignored.
        """
        if self._shutdown:
            return # Already shut down
        self._shutdown = True

        if not self._running or self._thread_loop is None:
            return

        # Check if we're calling from the executor's own thread
        in_executor_thread = (self._thread is not None and 
                              threading.get_ident() == self._thread.ident)
        in_executor = False
        if in_executor_thread:
            try:
                in_executor = asyncio.get_running_loop() == self._thread_loop
            except RuntimeError:
                # __del__ can be called from the executor thread
                # when the loop is not running, so we ignore this
                pass

        stop_executed = threading.Event()

        # Wait for tasks to complete when wait=True
        def wait_for_tasks_and_stop():
            # Get all tasks except our own current task
            current_task = asyncio.current_task(self._thread_loop)
            tasks = [t for t in asyncio.all_tasks(self._thread_loop) 
                    if t is not current_task]
            
            if tasks:
                # Create a future that completes when all tasks are done
                future = asyncio.gather(*tasks, return_exceptions=True)
                future.add_done_callback(lambda _: self._thread_loop.stop())
                future.add_done_callback(lambda _: stop_executed.set())
            else:
                # No tasks to wait for, stop immediately
                self._thread_loop.stop()
                stop_executed.set()

        # Schedule task handling in the thread's event loop
         # Cancel any pending tasks in the loop
        if cancel_futures:
            print("Cancelling all pending tasks in AsyncThreadPoolExecutor...")
            if in_executor:
                # If we are in the executor, we can cancel tasks directly
                self._cancel_all_tasks()
            else:
                self._thread_loop.call_soon_threadsafe(self._cancel_all_tasks)

        print("Shutting down AsyncThreadPoolExecutor...", in_executor, in_executor_thread)

        if in_executor_thread:
            # Don't wait if we're in the executor thread (deadlock)
            self._thread_loop.call_soon_threadsafe(wait_for_tasks_and_stop)
            stop_executed.set()
        elif wait:
            self._thread_loop.call_soon_threadsafe(wait_for_tasks_and_stop)
        else:
            self._thread_loop.call_soon_threadsafe(wait_for_tasks_and_stop)
            stop_executed.set() # do not wait for tasks to complete

        stop_executed.wait(timeout=10.0)
        if not stop_executed.is_set():
            warnings.warn("Executor shutdown timed out, some tasks may not have completed.", RuntimeWarning)

        # Wait for the thread to finish for proper cleanup
        # (unless we are in the thread itself)
        if wait and self._thread is not None and self._thread.is_alive() and not in_executor_thread:
            print("Waiting for background thread to finish...")
            self._thread.join(timeout=1.0)
            self._thread = None

    def __del__(self):
        """Ensure resources are cleaned up when the executor is garbage collected."""
        if not hasattr(self, '_running') or not self._running:
            return
        self.shutdown(wait=False)


async def run_viewport_loop(viewport: dcg.Viewport,
                            frame_rate: float = 120) -> None:
    """
    Run the viewport's rendering loop in an asyncio-friendly manner.

    Args:
        viewport: The DearCyGui viewport object
        frame_rate: Target frame rate for checking events, default is 120Hz
    """
    frame_time = 1.0 / frame_rate

    while viewport.context.running:
        # Check if there are events waiting to be processed
        if viewport.wait_for_input:
            # Note: viewport.wait_for_input must be set to True
            # for wait_events to not always return True
            has_events = viewport.wait_events(timeout_ms=0)
        else:
            has_events = True

        # Render a frame if there are events
        if has_events:
            if not viewport.render_frame():
                # frame needs to be re-rendered
                # we still yield to allow other tasks to run
                await asyncio.sleep(0)
                continue

        await asyncio.sleep(frame_time)
