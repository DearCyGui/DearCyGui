import pytest
import threading
import time
import asyncio
import random
from concurrent.futures import ThreadPoolExecutor
from contextlib import ExitStack

import dearcygui as dcg
from dearcygui.utils.asyncio_helpers import (
    AsyncPoolExecutor,
    AsyncThreadPoolExecutor, 
    run_viewport_loop,
)

# ---- Fixtures ----

@pytest.fixture
def ctx():
    """Create a fresh context for each test."""
    context = dcg.Context()
    yield context
    # No explicit cleanup needed as Python's GC will handle this

@pytest.fixture
def viewport(ctx: dcg.Context):
    """Get the viewport from a context."""
    return ctx.viewport

@pytest.fixture
def initialized_viewport(viewport: dcg.Viewport):
    """Get an initialized viewport (not visible)."""
    viewport.initialize(visible=False)
    return viewport

@pytest.fixture
def multiple_viewports(request):
    """Create multiple contexts and viewports."""
    count = getattr(request, "param", 2)
    contexts = [dcg.Context() for _ in range(count)]
    viewports = [ctx.viewport for ctx in contexts]
    
    yield contexts, viewports
    
    # Clean up
    for ctx in contexts:
        del ctx

# Helper functions for common test patterns
def assert_raises_with_message(func, exception_type, message_part):
    """Assert that a function raises an exception with expected message."""
    with pytest.raises(exception_type) as excinfo:
        func()
    assert message_part in str(excinfo.value)

def run_in_thread(func):
    """Run a function in a separate thread and wait for it to complete."""
    error = [None]
    finished = threading.Event()
    
    def wrapper():
        try:
            func()
        except Exception as e:
            error[0] = e
        finally:
            finished.set()
    
    thread = threading.Thread(target=wrapper)
    thread.start()
    finished.wait(timeout=5.0)
    thread.join()
    
    return error[0]

# ---- Basic Initialization Tests ----

class TestViewportInitialization:
    def test_uninitialized_methods_raise_errors(self, viewport: dcg.Viewport):
        """Test that uninitialized viewport methods raise proper errors."""
        for method_name, args in [
            ('render_frame', []),
            ('wait_events', []),
        ]:
            assert_raises_with_message(
                lambda: getattr(viewport, method_name)(*args),
                RuntimeError, "The viewport must be initialized before being used"
            )
    
    def test_multiple_initialize_calls(self, viewport: dcg.Viewport):
        """Test that multiple initialization attempts are handled correctly."""
        viewport.initialize(visible=False)
        assert_raises_with_message(
            lambda: viewport.initialize(visible=False),
            RuntimeError, "already initialized"
        )
    
    def test_initialize_with_invalid_params(self, viewport: dcg.Viewport):
        """Test initialization with invalid parameters."""
        for params in [
            {'width': -100, 'height': 800},
            {'width': 1280, 'height': -100}
        ]:
            assert_raises_with_message(
                lambda: viewport.initialize(visible=False, **params),
                ValueError, ""
            )
    
    def test_property_access_without_initialize(self, viewport: dcg.Viewport):
        """Test property access on uninitialized viewport."""
        # Basic properties should work
        assert viewport.title == "DearCyGui Window"
        
        # Setting properties should also work
        viewport.title = "Test Window"
        assert viewport.title == "Test Window"
        
        # But some properties require initialization
        with pytest.raises(Exception):
            _ = viewport.displays
    
    def test_cleanup_after_initialize(self, ctx: dcg.Context):
        """Test cleanup after initialization."""
        viewport = ctx.viewport
        viewport.initialize(visible=False)
        viewport.render_frame()
        
        # If we can delete without crashing, test passes
        del viewport
        del ctx

# ---- Thread Safety Tests ----

class TestViewportThreadSafety:
    def test_secondary_thread_without_initialize(self, viewport: dcg.Viewport):
        """Test that using uninitialized viewport from another thread fails properly."""
        error = run_in_thread(lambda: viewport.wait_events())
        assert isinstance(error, RuntimeError)
        assert "The viewport must be initialized before being used" in str(error)
    
    def test_render_frame_from_wrong_thread(self, initialized_viewport: dcg.Viewport):
        """Test that render_frame from wrong thread fails properly."""
        error = run_in_thread(lambda: initialized_viewport.render_frame())
        assert isinstance(error, RuntimeError)
        assert "thread" in str(error)
    
    def test_initialize_from_wrong_thread(self, viewport: dcg.Viewport):
        """Test that initialize from wrong thread fails properly."""
        error = run_in_thread(lambda: viewport.initialize(visible=False))
        assert isinstance(error, RuntimeError)
        assert "thread" in str(error)
    
    def test_wake_from_another_thread(self, initialized_viewport: dcg.Viewport):
        """Test that wake() can be called from another thread."""
        success = [False]
        
        def wake_viewport():
            initialized_viewport.wake()
            success[0] = True
        
        error = run_in_thread(wake_viewport)
        assert error is None
        assert success[0]
    
    def test_property_access_from_threads(self, initialized_viewport: dcg.Viewport):
        """Test accessing properties from multiple threads."""
        exceptions = []
        barrier = threading.Barrier(10)
        
        def access_properties(thread_id):
            try:
                barrier.wait()
                # Reading properties should work
                _ = initialized_viewport.title
                _ = initialized_viewport.width
                
                # Setting properties should work
                initialized_viewport.title = f"Thread {thread_id}"
                
                # Rendering should fail with thread error
                try:
                    initialized_viewport.render_frame()
                    exceptions.append("render_frame didn't raise exception")
                except RuntimeError as e:
                    if "must be called from the thread where the context was created" not in str(e):
                        exceptions.append(f"Wrong error: {e}")
            except Exception as e:
                exceptions.append(f"Unexpected: {type(e).__name__}: {e}")
        
        threads = [threading.Thread(target=access_properties, args=(i,)) 
                  for i in range(10)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        
        assert not exceptions

# ---- Multi-Viewport Tests ----

class TestMultipleViewports:
    def test_multiple_viewports_contexts(self, multiple_viewports: tuple[list[dcg.Context], list[dcg.Viewport]]):
        """Test creating and using multiple contexts and viewports."""
        contexts, viewports = multiple_viewports
        
        # Initialize with different settings
        for i, vp in enumerate(viewports):
            vp.initialize(title=f"VP {i}", width=500 + i*50, visible=False)
        
        # Verify separate settings
        for i, vp in enumerate(viewports):
            assert vp.title == f"VP {i}"
            assert vp.width == 500 + i*50
            vp.render_frame()
    
    def test_rendering_sequence(self, multiple_viewports: tuple[list[dcg.Context], list[dcg.Viewport]]):
        """Test rendering frames across multiple viewports in sequence."""
        contexts, viewports = multiple_viewports
        
        # Initialize viewports and create content
        texts: list[dcg.Text] = []
        for i, (ctx, vp) in enumerate(zip(contexts, viewports)):
            vp.initialize(title=f"VP {i}", visible=False)
            win = dcg.Window(ctx, label=f"Window {i}")
            texts.append(dcg.Text(ctx, value=f"Initial {i}", parent=win))
        
        # Render frames in sequence
        for i in range(3):
            for j, vp in enumerate(viewports):
                texts[j].value = f"Update {j}.{i}"
                vp.render_frame()
        
        # Verify each text has the correct value
        for j, text in enumerate(texts):
            assert text.value == f"Update {j}.2"

# ---- Worker Thread Tests ----

class TestWorkerThreads:
    def test_main_thread_render_with_workers(self, initialized_viewport: dcg.Viewport, ctx: dcg.Context):
        """Test main thread rendering with worker threads updating data."""
        shared_data = {"counter": 0}
        win = dcg.Window(ctx, label="Thread Test")
        text = dcg.Text(ctx, value="Initial", parent=win)
        
        def worker():
            for _ in range(5):
                shared_data["counter"] += 1
                initialized_viewport.wake()
                time.sleep(0.01)
        
        # Start worker threads
        threads = [threading.Thread(target=worker) for _ in range(3)]
        for t in threads:
            t.start()
        
        # Render in main thread
        for _ in range(3):
            text.value = f"Counter: {shared_data['counter']}"
            initialized_viewport.render_frame()
            time.sleep(0.02)
        
        # Wait for workers to finish
        for t in threads:
            t.join()
        
        # Verify counter was updated
        text.value = f"Counter: {shared_data['counter']}"
        initialized_viewport.render_frame()
        assert shared_data["counter"] == 15

# ---- Asyncio Integration Tests ----

class TestAsyncioIntegration:
    def test_viewport_with_asyncio_run(self, initialized_viewport: dcg.Viewport, ctx: dcg.Context):
        """Test using a viewport with asyncio.run."""
        win = dcg.Window(ctx, label="Asyncio Test")
        text = dcg.Text(ctx, value="Initial", parent=win)
        
        async def update_viewport():
            for i in range(3):
                text.value = f"Update {i}"
                initialized_viewport.render_frame()
                await asyncio.sleep(0.01)
            return "Done"
        
        result = asyncio.run(update_viewport())
        assert result == "Done"
        assert text.value == "Update 2"
    
    def test_run_viewport_loop(self, initialized_viewport: dcg.Viewport, ctx: dcg.Context):
        """Test run_viewport_loop helper function."""
        dcg.Window(ctx, label="Loop Test")

        try:
            asyncio.run(asyncio.wait_for(run_viewport_loop(initialized_viewport), 
                                         timeout=1.0))
        except TimeoutError:
            pass
        ctx.running = False
    
    def test_uninitialized_viewport_in_async_thread_pool(self, ctx: dcg.Context):
        """Test graceful failure with uninitialized viewport in thread pool."""
        # Create two viewports - one initialized, one not
        ctx1 = ctx
        ctx2 = dcg.Context()
        viewport1 = ctx1.viewport
        viewport2 = ctx2.viewport  # This one won't be initialized
        
        viewport1.initialize(visible=False)
        
        # Create the executor and error tracking
        executor = AsyncThreadPoolExecutor()
        
        async def run_uninitialized():
            await run_viewport_loop(viewport2)
            return True
        
        # Run the uninitialized viewport in thread pool
        future = executor.submit(run_uninitialized)
        
        # Run the main viewport in main thread
        async def run_main():
            viewport1.render_frame()
            await asyncio.sleep(0.1)
            
            # Wait for error event
            for _ in range(5):
                viewport1.render_frame()
                await asyncio.sleep(0.05)
        
        asyncio.run(run_main())
        
        # Check for proper error handling
        assert future.done()
        assert isinstance(future.exception(), RuntimeError)
        assert "The viewport must be initialized before being used" in str(future.exception())
        
        # Clean up
        executor.shutdown()