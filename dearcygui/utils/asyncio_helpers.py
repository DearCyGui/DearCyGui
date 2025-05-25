import asyncio
from concurrent.futures import ThreadPoolExecutor
import dearcygui as dcg
import inspect
import threading

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
        else:
            self._loop = loop

    # Replace ThreadPoolExecutor completly to avoid using threads
    def __del__(self):
        return

    def shutdown(self, *args, **kwargs):
        return

    def map(self, *args, **kwargs):
        raise NotImplementedError("AsyncPoolExecutor does not support map operation.")

    def __enter__(self):
        raise NotImplementedError("AsyncPoolExecutor cannot be used as a context manager.")

    def submit(self, fn, *args, **kwargs):
        """
        Submit a callable to be executed in the asyncio event loop.
        
        Unlike the standard ThreadPoolExecutor, this doesn't actually use a thread
        but instead schedules the function to run in the asyncio event loop.
        
        Returns:
            asyncio.Future: A future representing the execution of the callable.
        """
        # Create a future in the current event loop
        future = self._loop.create_future()

        async def run_fn(future=future, fn=fn, args=args, kwargs=kwargs):
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

        # Schedule the coroutine execution in the event loop
        self._loop.create_task(run_fn())

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

    def _thread_worker(self):
        """Background thread that runs its own event loop."""
        # Create a new event loop for this thread
        self._thread_loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self._thread_loop)

        self._running = True
        try:
            self._thread_loop.run_forever()
        finally:
            self._running = False
            self._thread_loop.close()
            self._thread_loop = None

    def _start_background_loop(self):
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
            asyncio.get_event_loop().run_until_complete(asyncio.sleep(0.))

    def submit(self, fn, *args, **kwargs):
        """
        Submit a callable to be executed in the background thread's event loop.

        Args:
            fn: The callable to execute
            *args: Arguments to pass to the callable
            **kwargs: Keyword arguments to pass to the callable

        Returns:
            Nothing. The function is scheduled to run in the background
            thread's event loop.
        """
        if not self._running:
            raise RuntimeError("Executor is not running")

        async def run_fn(fn=fn, args=args, kwargs=kwargs):
            # If it's a coroutine function, await it directly
            if inspect.iscoroutinefunction(fn):
                result = await fn(*args, **kwargs)
            else:
                # For regular functions, call them and handle returned coroutines
                result = fn(*args, **kwargs)
                # If the function returned a coroutine, await it
                if asyncio.iscoroutine(result):
                    result = await result

        # Schedule the function to run in the thread's event loop
        self._thread_loop.call_soon_threadsafe(
            lambda: self._thread_loop.create_task(run_fn())
        )

    def shutdown(self, wait=True):
        """
        Shutdown the executor, stopping the background thread and event loop.

        Args:
            wait: If True, wait for the background thread to finish.
        """
        if not self._running or self._thread_loop is None:
            return

        # Stop the event loop
        self._thread_loop.call_soon_threadsafe(self._thread_loop.stop)

        # Wait for the thread to finish if requested
        if wait and self._thread is not None:
            self._thread.join()
            self._thread = None

    def __del__(self):
        """Ensure resources are cleaned up when the executor is garbage collected."""
        if not hasattr(self, '_running') or not self._running:
            return
        self.shutdown(wait=False)


async def run_viewport_loop(viewport: dcg.Viewport,
                            frame_rate=120,
                            wait_for_input=True):
    """
    Run the viewport's rendering loop in an asyncio-friendly manner.

    Args:
        viewport: The DearCyGui viewport object
        frame_rate: Target frame rate for checking events, default is 120Hz
        wait_for_input: If True, avoids rendering when there are no events.
    """
    frame_time = 1.0 / frame_rate

    while viewport.context.running:
        # Check if there are events waiting to be processed
        if wait_for_input:
            has_events = viewport.wait_events(timeout_ms=0)
        else:
            has_events = True

        # Render a frame if there are events
        if has_events:
            viewport.render_frame()

        await asyncio.sleep(frame_time)
