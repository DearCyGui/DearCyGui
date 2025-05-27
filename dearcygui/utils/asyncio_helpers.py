import asyncio
from concurrent.futures import ThreadPoolExecutor, Future
import dearcygui as dcg
import inspect
import threading
import time

from typing import Callable

async def _async_task(future: Future | asyncio.Future,
                      barrier: threading.Event | None,
                      fn: Callable, args: tuple, kwargs: dict) -> None:
    """
    Internal function to run a callable in the asyncio event loop.
    This function is designed to be run as a task in the event loop,
    allowing it to handle both synchronous and asynchronous functions.

    Args:
        future: A Future object to set the result or exception.
        barrier: An optional threading.Event to control execution flow.
        fn: The callable to execute.
        args: Positional arguments to pass to the callable.
        kwargs: Keyword arguments to pass to the callable.
    """
    if barrier is not None and not barrier.is_set():
        # The barrier here is to shield ourselves from eager task execution,
        # as we don't want the function to run in the same
        # thread immediately (unsafe to change the item
        # attributes when frame rendering isn't finished).
        # we do not need to recheck the barrier after the first await
        await asyncio.sleep(0)
    try:
        # If it's a coroutine function, await it directly
        if inspect.iscoroutinefunction(fn):
            result = await fn(*args, **kwargs)
        else:
            # For regular functions, call them and handle returned coroutines
            result = fn(*args, **kwargs)
            # If the function returned a coroutine, await it
            if asyncio.iscoroutine(result):
                result = await result
        # Set the result if not cancelled
        if not future.cancelled():
            future.set_result(result)
    except Exception as exc:
        if not future.cancelled():
            future.set_exception(exc)


def _create_task(loop: asyncio.AbstractEventLoop,
                 future: Future, fn: Callable, args: tuple,
                 kwargs: dict) -> asyncio.Task:
    """
    Helper function to instantiate an awaitable for the
    task in the asyncio event loop
    """
    return loop.create_task(_async_task(future, None, fn, args, kwargs))


class AsyncPoolExecutor(ThreadPoolExecutor):
    """
    A ThreadPoolExecutor implementation that executes callbacks
    in the asyncio event loop.
    
    This executor forwards all submitted tasks to the asyncio
    event loop instead of executing them in separate threads,
    enabling seamless integration with asyncio-based applications.
    """
    
    def __init__(self, loop: asyncio.AbstractEventLoop = None):
        """Initialize the executor with standard ThreadPoolExecutor parameters."""
        if loop is None:
            self._loop = asyncio.get_event_loop()
            if self._loop is None:
                raise RuntimeError("No event loop found. Please set an event loop before using AsyncPoolExecutor.")
        else:
            self._loop = loop

    # Replace ThreadPoolExecutor completly to avoid using threads
    def __del__(self):
        return

    def shutdown(self, *args, **kwargs) -> None:
        return

    def map(self, *args, **kwargs):
        raise NotImplementedError("AsyncPoolExecutor does not support map operation.")

    def __enter__(self):
        raise NotImplementedError("AsyncPoolExecutor cannot be used as a context manager.")

    def submit(self, fn: Callable, *args, **kwargs) -> asyncio.Future:
        """
        Submit a callable to be executed in the asyncio event loop.
        
        Unlike the standard ThreadPoolExecutor, this doesn't actually use a thread
        but instead schedules the function to run in the asyncio event loop.
        
        Returns:
            asyncio.Future: A future representing the execution of the callable.
        """
        # Create a future in the current event loop
        future = self._loop.create_future()

        barrier = None
        if self._loop.get_task_factory() is not None:
            # If we are using eager task factory, we need to use a barrier
            # to ensure the function is not executed immediately in the same thread
            # (which would be unsafe if we are in the middle of rendering a frame)
            barrier = threading.Event()

        # Schedule the coroutine execution in the event loop
        self._loop.create_task(_async_task(future, barrier, fn, args, kwargs))

        if barrier is not None:
            barrier.set()  # if we are here, the frame rendering can continue

        return future


class AsyncThreadPoolExecutor(ThreadPoolExecutor):
    """
    A ThreadPoolExecutor that executes callbacks in a
    single secondary thread with its own event loop.

    It can be used as a drop-in replacement of the default
    context queue. The main difference is that this
    executor enables running `async def` callbacks.

    This executor runs an asyncio event loop in a dedicated
    thread and forwards all submitted tasks to that loop,
    enabling asyncio operations to run off the main thread.
    """

    def __init__(self):
        self._thread_loop = None
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
        self._thread_loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self._thread_loop)
        # for speed, use eager task factory
        self._thread_loop.set_task_factory(asyncio.eager_task_factory)

        self._running = True
        try:
            self._thread_loop.run_forever()
        finally:
            self._running = False
            self._thread_loop.close()
            self._thread_loop = None

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
        while self._thread_loop is None:
            if not self._thread.is_alive():
                raise RuntimeError("Background thread failed to start")
            time.sleep(0.)  # Avoid busy-waiting

    def submit(self, fn: Callable, *args, **kwargs) -> Future:
        """
        Submit a callable to be executed in the background thread's event loop.

        Args:
            fn: The callable to execute
            *args: Arguments to pass to the callable
            **kwargs: Keyword arguments to pass to the callable

        Returns:
            concurrent.futures.Future: A future representing the execution of the callable.
        """
        if not self._running:
            raise RuntimeError("Executor is not running")

        future = Future()

        # Schedule the function to run in the thread's event loop
        self._thread_loop.call_soon_threadsafe(_create_task, self._thread_loop, future, fn, args, kwargs)

        return future

    def shutdown(self, wait: bool = True, *args, **kwargs) -> None:
        """
        Shutdown the executor, stopping the background thread and event loop.

        Args:
            wait: If True, wait for the background thread to finish.
        """
        if not self._running or self._thread_loop is None:
            return

        # Cancel any pending tasks in the loop
        def cancel_all_tasks():
            for task in asyncio.all_tasks(self._thread_loop):
                task.cancel()
            # Add a final callback to stop the loop after tasks have a chance to cancel
            self._thread_loop.call_soon(self._thread_loop.stop)

        # Schedule task cancellation in the thread's event loop
        if not wait:
            self._thread_loop.call_soon_threadsafe(cancel_all_tasks)
        else:
            self._thread_loop.call_soon_threadsafe(self._thread_loop.stop)

        # Wait for the thread to finish for proper cleanup
        if self._thread is not None:
            self._thread.join()

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
