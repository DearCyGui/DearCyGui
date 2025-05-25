import asyncio
import dearcygui as dcg
from concurrent.futures import ThreadPoolExecutor

class AsyncThreadPoolExecutor(ThreadPoolExecutor):
    """
    A ThreadPoolExecutor implementation that executes callbacks in the asyncio event loop.
    
    This executor forwards all submitted tasks to the asyncio event loop instead of
    executing them in separate threads, enabling seamless integration with asyncio-based
    applications.
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
        raise NotImplementedError("AsyncThreadPoolExecutor does not support map operation.")

    def __enter__(self):
        raise NotImplementedError("AsyncThreadPoolExecutor cannot be used as a context manager.")

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
        
        # Define a callback wrapper that sets the future result or exception
        def callback_wrapper(future=future, fn=fn, args=args, kwargs=kwargs):
            try:
                result = fn(*args, **kwargs)
                if not future.cancelled():
                    future.set_result(result)
            except Exception as exc:
                if not future.cancelled():
                    future.set_exception(exc)

        # Schedule the callback to run soon in the event loop
        # This ensures render_frame continues without waiting
        self._loop.call_soon(callback_wrapper)

        return future


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
