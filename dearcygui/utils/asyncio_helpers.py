"""Helpers to run DearCyGui callbacks and the viewport loop with asyncio."""

import asyncio
from asyncio import ( # import directly for faster access
    CancelledError as _asyncio_CancelledError,
    Future as _asyncio_Future,
    iscoroutine as _iscoroutine,
    sleep as _asyncio_sleep,
    Task as _asyncio_Task
)
from collections.abc import Callable, Coroutine
from concurrent.futures import Executor, Future
from math import ceil as _ceil
from threading import (
    Event as _threading_Event,
    Thread as _threading_Thread,
    get_ident as _threading_get_ident
)
from typing import Any, Final, NoReturn
import warnings

import dearcygui as dcg

_START_TIMEOUT_S: Final[float] = 1.0
_STOP_TIMEOUT_S: Final[float] = 10.0
_JOIN_TIMEOUT_S: Final[float] = 1.0

type _AnyFuture = Future | _asyncio_Future
type _Submittable = Callable[..., Any] | Coroutine[Any, Any, Any]

def _set_exception(future: _AnyFuture, exc: BaseException) -> None:
    """Set *exc* on *future* unless it was cancelled."""
    # asyncio.Future
    if isinstance(future, _asyncio_Future):
        if not future.cancelled():
            future.set_exception(exc)

    # concurrent.futures.Future
    elif future.set_running_or_notify_cancel():
        # A cancelled concurrent future cannot report the exception
        future.set_exception(exc)


def _cancel(future: _AnyFuture) -> None:
    """Cancel *future* and notify its waiters."""
    future.cancel()
    if isinstance(future, Future):
        future.set_running_or_notify_cancel()


async def _async_task(
    future: _AnyFuture, 
    fn: _Submittable,
    args: tuple,
    kwargs: dict,
    defer: bool
) -> None:
    """Run `fn(*args, **kwargs)` in the running event loop and report the outcome in *future*.

    Both regular callables and coroutine functions are supported.

    Args:
        future: Future receiving the result or the exception.
        fn: The callable (or coroutine).
        args: Positional arguments to pass to *fn*.
        kwargs: Keyword arguments to pass to *fn*.
        defer: If True, yield to the event loop once before running the call.
            This shields against eager task factories, as the call must
            not run in the submitting thread before the frame is rendered.
    """
    # Never start the call synchronously from the submitter
    if defer:
        await _asyncio_sleep(0)

    try:
        # A coroutine function returns a coroutine that must be awaited
        if callable(fn):
            result = fn(*args, **kwargs)
            if _iscoroutine(result):
                result = await result
        
        # If the function is a coroutine, await it directly
        elif _iscoroutine(fn):
            if args or kwargs:
                warnings.warn(
                    "Coroutine passed directly to submit with args or kwargs. "
                    "Ignoring args and kwargs.",
                    RuntimeWarning,
                )
            result = await fn
        else:
            raise TypeError(
                f"Unsupported callable type: {type(fn)}. "
                "Must be a coroutine function, regular function, or coroutine."
            )

        # Report the result to the future
        # asyncio.Future
        if isinstance(future, _asyncio_Future):
            if not future.cancelled():
                future.set_result(result)
    
        # concurrent.futures.Future
        elif future.set_running_or_notify_cancel():
            future.set_result(result)

    # Handle exceptions and cancellation
    except Exception as exc:
        _set_exception(future, exc)
    except _asyncio_CancelledError:
        _cancel(future)
    except (SystemExit, KeyboardInterrupt):
        asyncio.get_running_loop().stop()
        _cancel(future)



def _create_task(
    loop: asyncio.AbstractEventLoop,
    tasks: set[_asyncio_Task],
    future: Future,
    fn: _Submittable,
    args: tuple,
    kwargs: dict
) -> None:
    """Instantiate in *loop* the task running `fn(*args, **kwargs)`, linked to *future*.

    Must be run in the thread of *loop*. Failures are reported in *future*.
    """
    # Create the task
    coro = _async_task(future, fn, args, kwargs, False)
    try:
        task = loop.create_task(coro)
    except RuntimeError as exc:
        # The loop is closed or stopping
        coro.close()
        future.set_exception(RuntimeError(f"Cannot create task: {exc}"))
        return

    # Keep a strong reference to prevent GC (Python 3.14 free-threaded)
    tasks.add(task)
    #task.add_done_callback(tasks.discard) -> done in _cancel_future_with_task_and_discard

    # Propagate cancellation in both directions
    def _cancel_task_with_future(future: Future) -> None:
        # Cancel *task* (thread-safely) when *future* gets cancelled.
        if future.cancelled():
            task.get_loop().call_soon_threadsafe(task.cancel)
    def _cancel_future_with_task_and_discard(task: _asyncio_Task) -> None:
        # Discard the task from the set of pending tasks
        tasks.discard(task)
        # Cancel *future* when *task* gets cancelled.
        if task.cancelled() and not future.done():
            future.cancel()
    future.add_done_callback(_cancel_task_with_future)
    task.add_done_callback(_cancel_future_with_task_and_discard)


class AsyncPoolExecutor:
    """Execute callbacks in an existing asyncio event loop.

    This is a ThreadPoolExecutor-like object that forwards all submitted
    tasks to the asyncio event loop instead of using threads, enabling
    seamless integration with asyncio-based applications.

    `submit` must be called from the thread running the loop, while
    `submit_threadsafe` can be called from any thread.
    """

    __slots__ = {
        "_loop": "Event loop running the submitted tasks",
        "_loop_thread_id": "Identifier of the thread running the loop (None until known)",
        "_tasks": "Strong references to the pending tasks",
    }

    _loop: asyncio.AbstractEventLoop
    _loop_thread_id: int | None
    _tasks: set[_asyncio_Task]

    def __init__(self, loop: asyncio.AbstractEventLoop | None = None) -> None:
        """Initialize the executor.

        Args:
            loop: The event loop to use. Defaults to the current event loop.

        Raises:
            RuntimeError: If no loop is given and no event loop is available.
            TypeError: If *loop* is not an event loop.
        """
        # Resolve the event loop
        if loop is None:
            try:
                loop = asyncio.get_event_loop()
            except RuntimeError:
                # Python 3.14+ raises when there is no current loop
                loop = None
            if loop is None:
                raise RuntimeError(
                    "No event loop found. Please set an event loop "
                    "before using AsyncPoolExecutor."
                )
        elif not isinstance(loop, asyncio.AbstractEventLoop):
            raise TypeError("Expected an instance of asyncio.AbstractEventLoop.")

        # Initialize state
        self._loop = loop
        self._loop_thread_id = None
        self._tasks = set()

        # Learn the loop thread once it runs
        loop.call_soon(self._record_loop_thread)

    @property
    def loop(self) -> asyncio.AbstractEventLoop:
        """The event loop used by this executor.

        It can be used to schedule work from another thread with
        `loop.call_soon_threadsafe()`.
        """
        return self._loop

    def map(self, *args, **kwargs) -> NoReturn:
        """Not supported.

        Raises:
            NotImplementedError: Always.
        """
        raise NotImplementedError("AsyncPoolExecutor does not support map operation.")

    def shutdown(self, *args, **kwargs) -> None:
        """Do nothing, as the event loop is not owned by the executor."""

    def submit(self, fn: _Submittable, /, *args, **kwargs) -> _asyncio_Future:
        """Schedule *fn* to run in the event loop.

        Since this call is meant to be run during frame rendering, it
        guarantees that no eager execution of the task will happen:
        the task is not started yet when this method returns.

        Args:
            fn: Callable, coroutine function or coroutine to run.
            *args: Positional arguments passed to *fn*.
            **kwargs: Keyword arguments passed to *fn*.

        Returns:
            A future representing the execution of *fn*.

        Raises:
            RuntimeError: If called from a thread other than the loop thread.
        """
        # Check the calling thread
        thread_id = self._loop_thread_id
        if thread_id is not None and thread_id != _threading_get_ident():
            raise RuntimeError(
                "Cannot submit tasks from a different thread. "
                f"Current thread ID: {_threading_get_ident()}, "
                f"Expected thread ID: {thread_id}"
            )

        # Schedule the task, deferring its start in case of eager task factory
        loop = self._loop
        future = loop.create_future()
        task = loop.create_task(
            _async_task(future, fn, args, kwargs, True)
        )

        # Keep a strong reference to the task
        tasks = self._tasks
        tasks.add(task)
        task.add_done_callback(tasks.discard)

        return future

    def submit_threadsafe(self, fn: _Submittable, /, *args, **kwargs) -> Future:
        """Schedule *fn* to run in the event loop from any thread.

        This is a drop-in replacement of `ThreadPoolExecutor.submit()`,
        and thus returns a `concurrent.futures.Future`. A use case is
        running functions that must be executed in the thread running the
        event loop (such as creating a context or some `dcg.os` functions).

        Args:
            fn: Callable, coroutine function or coroutine to run.
            *args: Positional arguments passed to *fn*.
            **kwargs: Keyword arguments passed to *fn*.

        Returns:
            A future representing the execution of *fn*.
        """
        future: Future = Future()
        self._loop.call_soon_threadsafe(_create_task, self._loop, self._tasks, future, fn, args, kwargs)
        return future

    def _record_loop_thread(self) -> None:
        """Record the current thread as the one running the loop."""
        self._loop_thread_id = _threading_get_ident()

    def __enter__(self) -> NoReturn:
        """Not supported.

        Raises:
            NotImplementedError: Always.
        """
        raise NotImplementedError("AsyncPoolExecutor cannot be used as a context manager.")


def _select_default_loop_class() -> type[asyncio.AbstractEventLoop]:
    """Return the best available event loop class (uvloop if installed)."""
    try:
        import uvloop
    except ImportError:
        return getattr(asyncio, "EventLoop", asyncio.SelectorEventLoop)
    return uvloop.Loop


_DefaultEventLoop: Final = _select_default_loop_class()


class BatchingEventLoop(_DefaultEventLoop):  # type: ignore[misc, valid-type]
    """Event loop optimized for batching events and tasks.

    Used with AsyncThreadPoolExecutor, it can improve performance when
    having many async callbacks with timed animations. It quantizes the
    time at which tasks are scheduled, so tasks with close deadlines are
    grouped together. This reduces the overhead of thread context
    switching and GIL contention.

    Like any event loop, it must only be used from its own thread.
    """

    __slots__ = {
        "_quantize_threshold": "Delays shorter than this (s) are not quantized",
        "_time_slot": "Time quantization in seconds",
    }

    _quantize_threshold: float
    _time_slot: float

    def __init__(self, time_slot: float = 0.010) -> None:
        """Initialize the quantized event loop.

        Args:
            time_slot: Time quantization in seconds (default: 10ms).

        Raises:
            ValueError: If *time_slot* is not positive.
        """
        if time_slot <= 0:
            raise ValueError("time_slot must be positive")
        super().__init__()
        self._time_slot = time_slot
        self._quantize_threshold = min(0.001, 0.1 * time_slot)

        # Small perf gain
        if hasattr(asyncio, "eager_task_factory"):
            self.set_task_factory(asyncio.eager_task_factory)

    @classmethod
    def factory(cls, time_slot: float = 0.010) -> Callable[[], "BatchingEventLoop"]:
        """Return a factory creating quantized event loops.

        Args:
            time_slot: Time quantization in seconds (default: 10ms).

        Returns:
            A callable creating a new configured event loop.
        """

        def create_loop() -> BatchingEventLoop:
            """Create a new loop."""
            return cls(time_slot)

        return create_loop

    @property
    def quantize_threshold(self) -> float:
        """Delays (in seconds) shorter than this are not quantized."""
        return self._quantize_threshold

    @property
    def time_slot(self) -> float:
        """Time quantization in seconds."""
        return self._time_slot

    def call_at(self, when, callback, *args, **kwargs):
        """Schedule *callback* at *when*, rounded up to the next time slot."""
        # Do not quantize immediate or very short delays
        if when - self.time() >= self._quantize_threshold:
            when = _ceil(when / self._time_slot) * self._time_slot
        return super().call_at(when, callback, *args, **kwargs)  # pyright: ignore[reportAbstractUsage]

    def call_later(self, delay, callback, *args, **kwargs):
        """Schedule *callback* after *delay*, rounded up to the next time slot."""
        # Do not quantize short delays
        if delay >= self._quantize_threshold:
            now = self.time()
            delay = _ceil((now + delay) / self._time_slot) * self._time_slot - now
        return super().call_later(delay, callback, *args, **kwargs)  # pyright: ignore[reportAbstractUsage]


def _close_loop(loop: asyncio.AbstractEventLoop) -> None:
    """Cancel the remaining tasks, shut down async generators and close *loop*."""
    try:
        pending = asyncio.all_tasks(loop)
        for task in pending:
            task.cancel()
        if pending:
            loop.run_until_complete(asyncio.gather(*pending, return_exceptions=True))
        loop.run_until_complete(loop.shutdown_asyncgens())
    except Exception as exc:
        warnings.warn(f"AsyncThreadPoolExecutor cleanup failed: {exc}", RuntimeWarning)
    finally:
        loop.close()


def _stop_when_idle(loop: asyncio.AbstractEventLoop, stopped: _threading_Event) -> None:
    """Stop *loop* once all its other tasks are done. Must run in the loop thread."""
    current_task = asyncio.current_task(loop)
    tasks = [t for t in asyncio.all_tasks(loop) if t is not current_task]

    def stop(_: object = None) -> None:
        """Stop the loop and notify the waiter."""
        loop.stop()
        stopped.set()

    if tasks:
        asyncio.gather(*tasks, return_exceptions=True).add_done_callback(stop)
    else:
        stop()


class AsyncThreadPoolExecutor(Executor):
    """Executor running callbacks in a single thread with its own event loop.

    It can be used as a drop-in replacement of the default context queue.
    The main difference is that it enables running `async def` callbacks,
    off the main thread.

    If available, uvloop is used as the event loop implementation, in which
    case the performance of normal callbacks is very similar to that of
    the default ThreadPoolExecutor queue.

    The default loop factory is
    `dearcygui.utils.asyncio_helpers.BatchingEventLoop.factory()`, an event
    loop that batches tasks by quantizing the scheduling time (default
    accuracy is 10ms). It is optimized for many async callbacks running
    timed animations. The quantization only affects operations such as
    `asyncio.sleep()`.

    This class is thread-safe.
    """

    __slots__ = {
        "_loop_factory": "Callable creating the event loop of the thread",
        "_ready": "Set when the thread loop is about to run (or the thread died)",
        "_running": "True while the thread loop runs",
        "_shutdown": "True once shutdown has been requested",
        "_tasks": "Strong references to the pending tasks",
        "_thread": "Background thread running the event loop",
        "_thread_loop": "Event loop of the background thread",
    }

    _loop_factory: Callable[[], asyncio.AbstractEventLoop]
    _ready: _threading_Event
    _running: bool
    _shutdown: bool
    _tasks: set[_asyncio_Task]
    _thread: _threading_Thread | None
    _thread_loop: asyncio.AbstractEventLoop | None

    def __init__(
        self,
        loop_factory: Callable[[], asyncio.AbstractEventLoop] | None = None,
    ) -> None:
        """Start the background thread and its event loop.

        Args:
            loop_factory: Callable creating the event loop. Defaults to
                `BatchingEventLoop.factory()`.

        Raises:
            TypeError: If *loop_factory* is not callable.
            RuntimeError: If the background thread fails to start.
        """
        # Initialize state first so that __del__ is always safe
        self._running = False
        self._shutdown = False
        self._thread = None
        self._thread_loop = None
        self._tasks = set()
        self._ready = _threading_Event()

        # Validate the loop factory
        factory = loop_factory or BatchingEventLoop.factory()
        if not callable(factory):
            raise TypeError(
                "loop_factory must be a callable that returns "
                "an asyncio.AbstractEventLoop instance."
            )
        self._loop_factory = factory

        self._start_background_loop()

    def map(self, *args, **kwargs) -> NoReturn:
        """Not supported.

        Raises:
            NotImplementedError: Always.
        """
        raise NotImplementedError("AsyncThreadPoolExecutor does not support map operation.")

    def shutdown(
        self, wait: bool = True, *args, cancel_futures: bool = False, **kwargs
    ) -> None:
        """Stop the background thread and its event loop.

        After shutdown, calls to submit() raise RuntimeError. This method can
        be called multiple times, and from within a task running in the
        executor, in which case *wait* is ignored.

        Args:
            wait: If True, block until all pending tasks are done.
            *args: Ignored (compatibility with Executor).
            cancel_futures: If True, cancel all pending tasks.
            **kwargs: Ignored (compatibility with Executor).
        """
        # Only shut down once
        if self._shutdown:
            return
        self._shutdown = True

        loop = self._thread_loop
        if not self._running or loop is None:
            return

        # Detect calls from the executor thread (waiting would deadlock)
        in_thread = self._thread is not None and _threading_get_ident() == self._thread.ident
        in_loop = False
        if in_thread:
            try:
                in_loop = asyncio.get_running_loop() is loop
            except RuntimeError:
                # Can happen from __del__ when the loop is not running
                pass

        # Cancel the pending tasks
        if cancel_futures:
            if in_loop:
                self._cancel_all_tasks()
            else:
                loop.call_soon_threadsafe(self._cancel_all_tasks)

        # Stop the loop once the tasks are done
        stopped = _threading_Event()
        loop.call_soon_threadsafe(_stop_when_idle, loop, stopped)
        block = wait and not in_thread
        if block:
            if not stopped.wait(timeout=_STOP_TIMEOUT_S):
                warnings.warn(
                    "Executor shutdown timed out, some tasks may not have completed.",
                    RuntimeWarning,
                )

        # Wait for the thread to finish for proper cleanup
        thread = self._thread
        if block and thread is not None and thread.is_alive():
            thread.join(timeout=_JOIN_TIMEOUT_S)
            self._thread = None

    def submit(self, fn: _Submittable, /, *args, **kwargs) -> Future:
        """Schedule *fn* to run in the background thread's event loop.

        Args:
            fn: Callable, coroutine function or coroutine to run.
            *args: Positional arguments passed to *fn*.
            **kwargs: Keyword arguments passed to *fn*.

        Returns:
            A future representing the execution of *fn*.

        Raises:
            RuntimeError: If the executor is shut down or not running.
        """
        # Check the executor state
        loop = self._thread_loop
        if self._shutdown:
            raise RuntimeError("Cannot schedule new futures after shutdown")
        if not self._running or loop is None:
            raise RuntimeError(
                f"Executor is not running, cannot submit {fn}, args={args}, kwargs={kwargs}"
            )

        # Schedule the task creation in the thread's event loop
        future: Future = Future()
        loop.call_soon_threadsafe(_create_task, loop, self._tasks, future, fn, args, kwargs)
        return future

    def _build_loop(self) -> asyncio.AbstractEventLoop:
        """Create and install the event loop of the background thread."""
        # Create the loop, falling back to the default one if invalid
        if self._loop_factory is asyncio.new_event_loop:
            loop = asyncio.new_event_loop()
            # Eager tasks are faster
            if hasattr(asyncio, "eager_task_factory"):
                loop.set_task_factory(asyncio.eager_task_factory)
        else:
            loop = self._loop_factory()
            if not isinstance(loop, asyncio.AbstractEventLoop):
                warnings.warn(
                    "The provided loop_factory did not return a valid asyncio event loop. "
                    "Using asyncio.new_event_loop instead.",
                    RuntimeWarning,
                )
                loop = asyncio.new_event_loop()
            elif loop.is_running():
                warnings.warn(
                    "The provided loop_factory returned an already running event loop. "
                    "Using asyncio.new_event_loop instead.",
                    RuntimeWarning,
                )
                loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)

        # Stop on system exit rather than hanging on unhandled exceptions
        def exception_handler(loop: asyncio.AbstractEventLoop, context: dict) -> None:
            """Stop the loop on SystemExit/KeyboardInterrupt."""
            if isinstance(context.get("exception"), (KeyboardInterrupt, SystemExit)):
                loop.stop()
                return
            loop.default_exception_handler(context)

        loop.set_exception_handler(exception_handler)
        return loop

    def _cancel_all_tasks(self) -> None:
        """Cancel all tasks of the thread loop. Must run in the loop thread."""
        loop = self._thread_loop
        if loop is None or loop.is_closed():
            return

        # Cancel all tasks except the one calling us
        current_task = asyncio.current_task(loop)
        for task in asyncio.all_tasks(loop):
            if task is not current_task and not task.done():
                task.cancel()

    def _run_thread_loop(self, loop: asyncio.AbstractEventLoop) -> None:
        """Run *loop* until stopped, then cancel the leftover tasks and close it."""
        try:
            loop.run_forever()
        except (KeyboardInterrupt, SystemExit):
            # Handle system-level interrupts gracefully
            pass
        except Exception as exc:
            # Do not let unexpected exceptions crash the thread silently
            warnings.warn(
                f"AsyncThreadPoolExecutor thread worker exception: {exc}", RuntimeWarning
            )
        finally:
            self._running = False
            _close_loop(loop)
            self._thread_loop = None


    def _start_background_loop(self) -> None:
        """Start the background thread and wait for its loop to be ready."""
        thread = _threading_Thread(
            target=self._thread_worker, daemon=True, name="AsyncThreadPoolExecutor"
        )
        self._thread = thread
        thread.start()

        # Wait for the thread loop to be ready
        if not self._ready.wait(timeout=_START_TIMEOUT_S):
            raise RuntimeError("Background thread did not start within 1 second")
        if not self._running:
            raise RuntimeError("Background thread failed to start")


    def _thread_worker(self) -> None:
        """Run the event loop of the background thread."""
        try:
            loop = self._build_loop()
            self._thread_loop = loop
            self._running = True
        finally:
            # Wake the starter (also if the loop creation failed)
            self._ready.set()
        self._run_thread_loop(loop)

    def __del__(self) -> None:
        """Ensure resources are cleaned up when the executor is garbage collected."""
        if getattr(self, "_running", False):
            self.shutdown(wait=False, cancel_futures=True)

    def __enter__(self) -> NoReturn:
        """Not supported.

        Raises:
            NotImplementedError: Always.
        """
        raise NotImplementedError("AsyncThreadPoolExecutor cannot be used as a context manager.")


async def run_viewport_loop(viewport: dcg.Viewport, *, frame_rate: float = 120) -> None:
    """Run the viewport's rendering loop in an asyncio-friendly manner.

    Args:
        viewport: The DearCyGui viewport to render.
        frame_rate: Target frame rate for checking events, in Hz.
    """
    frame_time = 1.0 / frame_rate

    while viewport.context.running:
        # Check for pending events. viewport.wait_for_input must be
        # set to True for wait_events to not always return True
        has_events = viewport.wait_events(timeout_ms=0) if viewport.wait_for_input else True

        # Render a frame if there are events
        if has_events and not viewport.render_frame():
            # The frame needs to be re-rendered, but let other tasks run
            await _asyncio_sleep(0)
            continue

        await _asyncio_sleep(frame_time)
