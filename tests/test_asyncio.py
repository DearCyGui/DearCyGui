import pytest
import asyncio
import concurrent.futures
from dearcygui.utils.asyncio_helpers import (
    AsyncPoolExecutor,
    AsyncThreadPoolExecutor,
    BatchingEventLoop
)
import gc
import sys
import threading
import time
import weakref

# Custom task factory for testing
def custom_task_factory(loop, coro):
    """Custom task factory that adds a tag to the task"""
    task = asyncio.tasks.Task(coro, loop=loop)
    task.custom_tag = "custom_factory_task"
    return task

# Single-threaded event loop fixture
@pytest.fixture(
    params=[
        "standard",
        "standard_debug",
        "standard_eager",
        "batching",
        "custom_task_factory",
        pytest.param("uvloop", marks=pytest.mark.skipif(
            "uvloop" not in sys.modules, 
            reason="uvloop not installed"
        )),
    ],
    ids=["standard", "debug", "eager", "batching", "custom_factory", "uvloop"]
)
def event_loop(request):
    """Create and return different single-threaded event loop implementations."""
    loop_type = request.param
    
    if loop_type == "standard":
        loop = asyncio.new_event_loop()
    elif loop_type == "standard_debug":
        loop = asyncio.new_event_loop()
        loop.set_debug(True)
    elif loop_type == "standard_eager":
        loop = asyncio.new_event_loop()
        loop.set_task_factory(asyncio.eager_task_factory)
    elif loop_type == "batching":
        loop = BatchingEventLoop()
    elif loop_type == "custom_task_factory":
        loop = asyncio.new_event_loop()
        loop.set_task_factory(custom_task_factory)
    elif loop_type == "uvloop":
        import uvloop
        loop = uvloop.new_event_loop()

    yield loop
    loop.close()

@pytest.fixture(
    params=[
        "standard",
        "standard_debug",
        "standard_eager",
        "batching",
        "custom_task_factory",
        pytest.param("uvloop", marks=pytest.mark.skipif(
            "uvloop" not in sys.modules, 
            reason="uvloop not installed"
        )),
    ],
    ids=["standard", "debug", "eager", "batching", "custom_factory", "uvloop"]
)
def event_loop_factory(request):
    """Create and return different event loop factories."""
    loop_type = request.param
    
    if loop_type == "standard":
        loop = asyncio.new_event_loop()
    elif loop_type == "standard_debug":
        loop = asyncio.new_event_loop()
        loop.set_debug(True)
    elif loop_type == "standard_eager":
        loop = asyncio.new_event_loop()
        loop.set_task_factory(asyncio.eager_task_factory)
    elif loop_type == "batching":
        loop = BatchingEventLoop()
    elif loop_type == "custom_task_factory":
        loop = asyncio.new_event_loop()
        loop.set_task_factory(custom_task_factory)
    elif loop_type == "uvloop":
        import uvloop
        loop = uvloop.new_event_loop()
    return lambda: loop  # Return a factory function to create the loop

class TestAsyncPoolExecutor:
    """Tests for the AsyncPoolExecutor class."""
    
    def test_sync_function_execution(self, event_loop):
        """Test execution of synchronous functions."""
        async def f():
            executor = AsyncPoolExecutor()
            
            def sync_function():
                return 42
            
            future = executor.submit(sync_function)
            assert await future == 42
            executor.shutdown()
        event_loop.run_until_complete(f())
    
    def test_async_function_execution(self, event_loop):
        """Test execution of asynchronous functions with awaits."""
        async def f():
            executor = AsyncPoolExecutor()
            
            async def async_function():
                await asyncio.sleep(0.01)
                return 42
            
            future = executor.submit(async_function)
            assert await future == 42
            executor.shutdown()
        event_loop.run_until_complete(f())
    
    def test_callbacks_execution_order(self, event_loop):
        """Test execution order with normal and async callbacks."""
        async def f():
            executor = AsyncPoolExecutor()
            result = []
            
            def sync_function():
                result.append(1)
                return "sync"
            
            async def async_function():
                result.append(2)
                await asyncio.sleep(0.01)
                result.append(5)
                return "async"

            def other_sync_function():
                time.sleep(0.1) # Simulate a blocking call
                result.append(3) # must run before async_function completes
                return "sync"

            async def other_async_function():
                result.append(4)
                await asyncio.sleep(0.001)
                result.append(6)
                return "async"
            
            future1 = executor.submit(sync_function)
            future2 = executor.submit(async_function)
            future3 = executor.submit(other_sync_function)
            future4 = executor.submit(other_async_function)

            # Ensure no early execution
            time.sleep(0.05)
            assert len(result) == 0

            assert await future1 == "sync"
            assert await future2 == "async"
            assert await future3 == "sync"
            assert await future4 == "async"
            assert result == [1, 2, 3, 4, 5, 6]
            executor.shutdown()
        event_loop.run_until_complete(f())

    
    def test_nested_callbacks(self, event_loop):
        """Test nested callbacks where one callback submits another."""
        async def f():
            executor = AsyncPoolExecutor()
            result = []
            
            async def outer_callback():
                result.append("outer_start")
                inner_future = executor.submit(inner_callback)
                result.append("outer_after_submit")
                await inner_future
                result.append("outer_end")
                return "outer"
            
            async def inner_callback():
                result.append("inner_start")
                await asyncio.sleep(0.01)
                result.append("inner_end")
                return "inner"
            
            future = executor.submit(outer_callback)
            assert await future == "outer"
            
            expected = [
                "outer_start", 
                "outer_after_submit", 
                "inner_start", 
                "inner_end", 
                "outer_end"
            ]
            assert result == expected
            executor.shutdown()
        event_loop.run_until_complete(f())

class TestAsyncThreadPoolExecutor:
    """Tests for the AsyncThreadPoolExecutor class."""
    
    def test_sync_function_execution(self, event_loop_factory):
        """Test with default loop factory."""
        executor = AsyncThreadPoolExecutor(event_loop_factory)
        results = []
        
        def sync_function():
            results.append(threading.current_thread().name)
            return 42
        
        future = executor.submit(sync_function)
        assert future.result() == 42
        assert len(results) == 1
        assert "MainThread" not in results[0]  # Should run in a different thread
        executor.shutdown()
    
    def test_async_function_execution(self, event_loop_factory):
        """Test execution of asynchronous functions with awaits."""
        executor = AsyncThreadPoolExecutor(event_loop_factory)
        result = []
        
        async def async_function():
            result.append(1)
            await asyncio.sleep(0.01)
            result.append(2)
            return 42
        
        future = executor.submit(async_function)
        assert future.result() == 42
        assert result == [1, 2]
        executor.shutdown()
    
    def test_mixed_callbacks_execution_order(self):
        """Test execution order when mixing normal and async callbacks."""
        executor = AsyncThreadPoolExecutor()
        result = []
  
        def sync_function():
            result.append(1)
            return "sync"
        
        async def async_function():
            result.append(2)
            await asyncio.sleep(0.01)
            result.append(5)
            return "async"

        def other_sync_function():
            time.sleep(0.1) # Simulate a blocking call
            result.append(3) # must run before async_function completes
            return "sync"

        async def other_async_function():
            result.append(4)
            await asyncio.sleep(0.001)
            result.append(6)
            return "async"
        
        future1 = executor.submit(sync_function)
        future2 = executor.submit(async_function)
        future3 = executor.submit(other_sync_function)
        future4 = executor.submit(other_async_function)

        # Unlike with AsyncPoolExecutor, early execution is ok here

        assert future1.result() == "sync"
        assert future2.result() == "async"
        assert future3.result() == "sync"
        assert future4.result() == "async"
        assert result == [1, 2, 3, 4, 5, 6]
        executor.shutdown()
    
    
    def test_varying_timeslot_batching(self):
        """Test BatchingEventLoop with different time slots."""
        results = []
        timing = []
        
        # Create executor with a larger time slot (50ms)
        executor = AsyncThreadPoolExecutor(BatchingEventLoop.factory(time_slot=0.050))
        
        async def timed_task(delay, idx):
            start = time.time()
            results.append(f"start_{idx}")
            await asyncio.sleep(delay)  # Should be quantized
            end = time.time()
            timing.append((idx, end - start))  # Record actual wait time
            results.append(f"end_{idx}")
            return idx
        
        # Submit tasks with similar but different delays
        futures = [
            executor.submit(timed_task, 0.020, 1),
            executor.submit(timed_task, 0.030, 2),
            executor.submit(timed_task, 0.040, 3),
        ]
        
        # Get results from all tasks
        results_values = [f.result() for f in futures]
        assert results_values == [1, 2, 3]
        
        # All tasks should have started in order
        assert results[0:3] == ["start_1", "start_2", "start_3"]
        
        # Due to time quantization, tasks might finish in batches
        # We're not strictly testing the order, but ensuring all finish
        assert set(results[3:]) == {"end_1", "end_2", "end_3"}
        
        # Check if quantization occurred - delays should be grouped
        # At least some tasks should have longer than requested delays due to quantization
        longer_delays = [t for _, t in timing if t > 0.045]
        assert len(longer_delays) > 0, "No evidence of time quantization found"
        
        executor.shutdown()
    
    def test_many_concurrent_callbacks(self):
        """Test with many concurrent callbacks to stress the executor."""
        executor = AsyncThreadPoolExecutor()
        results = []
        NUM_TASKS = 50
        
        async def async_task(idx):
            results.append(idx)
            if idx % 5 == 0:
                await asyncio.sleep(0.001)  # Add occasional sleep
            return idx
        
        # Submit many tasks rapidly
        futures = [executor.submit(async_task, i) for i in range(NUM_TASKS)]
        
        # Verify all tasks complete successfully
        for i, future in enumerate(futures):
            assert future.result() == i
        
        # All tasks should eventually complete
        assert len(results) == NUM_TASKS
        assert set(results) == set(range(NUM_TASKS))
        
        executor.shutdown()
    
    def test_complex_async_patterns(self):
        """Test complex async patterns with multiple awaits and nested calls."""
        executor = AsyncThreadPoolExecutor()
        results = []
        
        async def nested_async_fn(depth, idx):
            results.append(f"start_{depth}_{idx}")
            if depth > 0:
                await asyncio.sleep(0.01 * depth)
                await nested_async_fn(depth - 1, idx)
            else:
                # Base case
                await asyncio.sleep(0.01)
            results.append(f"end_{depth}_{idx}")
            return depth
        
        # Submit tasks with different recursion depths
        futures = [
            executor.submit(nested_async_fn, 3, 1),
            executor.submit(nested_async_fn, 2, 2),
            executor.submit(nested_async_fn, 1, 3)
        ]
        
        results_values = [f.result() for f in futures]
        assert results_values == [3, 2, 1]
        
        # Check we have the right number of starts and ends
        starts = [r for r in results if r.startswith("start")]
        ends = [r for r in results if r.startswith("end")]
        assert len(starts) == 9  # 4+3+2 levels of recursion
        assert len(ends) == 9    # Same number of ends
        
        executor.shutdown()

    def test_shutdown_with_pending_tasks(self):
        """Test shutdown behavior with pending tasks."""
        executor = AsyncThreadPoolExecutor()
        results = []
        
        async def long_task():
            results.append("start")
            await asyncio.sleep(0.5)  # Long delay
            results.append("end")
            return 42
        
        # Submit task but don't wait for it
        future = executor.submit(long_task)
        
        # Give task time to start but not complete
        time.sleep(0.1)
        
        # Task should have started
        assert "start" in results
        assert "end" not in results
        
        # Shutdown without waiting (should cancel pending tasks)
        executor.shutdown(wait=False)
        
        # The future may be cancelled or may complete depending on timing
        try:
            future.result(timeout=0.1)
        except:
            pass  # Exception is expected
            
        # Create a new executor and make sure it still works
        executor2 = AsyncThreadPoolExecutor()
        result_future = executor2.submit(lambda: 123)
        assert result_future.result() == 123
        executor2.shutdown()

    def test_shutdown_with_wait_true(self):
        """Test shutdown with wait=True completes all pending tasks."""
        executor = AsyncThreadPoolExecutor()
        results = []
        
        async def slow_task(idx):
            results.append(f"start_{idx}")
            await asyncio.sleep(0.1)
            results.append(f"end_{idx}")
            return idx
        
        # Submit multiple tasks
        futures = [executor.submit(slow_task, i) for i in range(5)]
        
        # Wait for all tasks to start
        time.sleep(0.05)
        
        # Shutdown with wait=True (default)
        start_time = time.time()
        executor.shutdown(wait=True)
        shutdown_time = time.time() - start_time
        
        # All tasks should complete
        assert len([r for r in results if r.startswith("end")]) == 5
        assert all(f.done() for f in futures)
        assert all(f.result() == i for i, f in enumerate(futures))
        
        # Shutdown should have waited for tasks
        assert shutdown_time >= 0.05, "Shutdown didn't seem to wait for tasks"
    
    def test_shutdown_with_wait_false(self):
        """Test shutdown with wait=False cancels pending tasks."""
        executor = AsyncThreadPoolExecutor()
        results = []
        completion_event = threading.Event()
        
        async def slow_task():
            results.append("start")
            try:
                await asyncio.sleep(1.0)
                results.append("middle")
                await asyncio.sleep(1.0)
                results.append("end")
                completion_event.set()
                return 42
            except asyncio.CancelledError:
                results.append("cancelled")
                raise
        
        # Submit a slow task
        future = executor.submit(slow_task)
        
        # Wait for task to start
        time.sleep(0.1)
        assert "start" in results
        
        # Shutdown without waiting
        start_time = time.time()
        executor.shutdown(wait=False)
        shutdown_time = time.time() - start_time
        
        # Shutdown should be quick
        assert shutdown_time < 0.5, "Shutdown took too long"
        
        # Task should eventually be cancelled or completed
        try:
            future.result(timeout=0.2)
            assert False, "Future should have been cancelled or timed out"
        except (concurrent.futures.CancelledError, TimeoutError):
            # Expected - either cancelled or still running but will be abandoned
            pass
        
        # The task should never complete normally
        assert not completion_event.wait(0.2), "Task completed after shutdown"
        assert "end" not in results
    
    def test_multiple_shutdown_calls(self):
        """Test that calling shutdown multiple times is safe."""
        executor = AsyncThreadPoolExecutor()
        
        # Submit a simple task
        future = executor.submit(lambda: 42)
        assert future.result() == 42
        
        # First shutdown
        executor.shutdown()
        
        # Second shutdown should not raise exceptions
        executor.shutdown()
        
        # Third shutdown with different parameters
        executor.shutdown(wait=False)
    
    def test_shutdown_with_exceptions(self):
        """Test shutdown behavior when tasks raise exceptions."""
        executor = AsyncThreadPoolExecutor()
        results = []
        
        async def failing_task():
            results.append("start")
            await asyncio.sleep(0.1)
            raise ValueError("Deliberate exception")
        
        async def normal_task():
            results.append("normal_start")
            await asyncio.sleep(0.2)
            results.append("normal_end")
            return 42
        
        # Submit both tasks
        failing_future = executor.submit(failing_task)
        normal_future = executor.submit(normal_task)
        
        # Wait for tasks to start
        time.sleep(0.05)
        
        # Shutdown - should handle the exception gracefully
        executor.shutdown()
        
        # The failing task should have an exception
        with pytest.raises(ValueError, match="Deliberate exception"):
            failing_future.result()
        
        # The normal task should complete successfully
        assert normal_future.result() == 42
        assert "normal_end" in results
    
    def test_resource_cleanup(self):
        """Test that all resources are properly cleaned up after shutdown."""
        # Get thread count before
        threads_before = threading.active_count()

        executor = AsyncThreadPoolExecutor()
        
        # Submit some tasks
        for _ in range(5):
            executor.submit(lambda: time.sleep(0.1))
        
        # Should have created threads
        time.sleep(0.05)
        threads_during = threading.active_count()
        assert threads_during == threads_before + 1, "No worker thread were created"
        
        # Create a weak reference to track if executor is garbage collected
        executor_ref = weakref.ref(executor)
        
        # Shutdown and delete
        executor.shutdown()
        del executor
        
        # Force garbage collection
        gc.collect()
        
        # All worker threads should eventually exit
        for _ in range(10):  # Try for up to 1 second
            if threading.active_count() <= threads_before:
                break
            time.sleep(0.1)
        
        assert threading.active_count() <= threads_before + 1, "Not all threads exited"
        assert executor_ref() is None, "Executor wasn't garbage collected"
    
    def test_nested_executor_shutdown(self):
        """Test shutdown with nested executor."""
        outer_executor = AsyncThreadPoolExecutor()
        results = []
        
        async def outer_task():
            results.append("outer_start")
            # Create a nested executor
            inner_executor = AsyncThreadPoolExecutor()
            
            inner_future = inner_executor.submit(inner_task)
            results.append("outer_after_submit")
            
            # Shutdown inner executor
            inner_executor.shutdown()
            
            # Inner task should be complete
            assert inner_future.result() == "inner_done"
            results.append("outer_end")
            return "outer_done"
        
        async def inner_task():
            results.append("inner_start")
            await asyncio.sleep(0.1)
            results.append("inner_end")
            return "inner_done"
        
        # Submit outer task
        future = outer_executor.submit(outer_task)
        
        # Wait and shutdown
        assert future.result() == "outer_done"
        outer_executor.shutdown()
        
        # Verify execution order
        assert results == [
            "outer_start", 
            "outer_after_submit", 
            "inner_start", 
            "inner_end", 
            "outer_end"
        ]
    
    def test_submit_during_shutdown(self):
        """Test behavior when tasks are submitted during shutdown."""
        executor = AsyncThreadPoolExecutor()
        results = []
        
        # Submit initial task
        executor.submit(lambda: results.append("initial"))
        
        # Start shutdown in separate thread
        shutdown_thread = threading.Thread(
            target=lambda: executor.shutdown(wait=True)
        )
        shutdown_thread.start()
        
        # Try to submit tasks during shutdown
        time.sleep(0.1)  # Give shutdown a chance to start
        
        try:
            # These might raise RuntimeError if executor is shutting down
            executor.submit(lambda: results.append("during_shutdown_1"))
            executor.submit(lambda: results.append("during_shutdown_2"))
        except RuntimeError:
            # Expected behavior - rejected submissions during shutdown
            results.append("rejected")
        
        # Wait for shutdown to complete
        shutdown_thread.join()
        
        # Initial task should have run
        assert "initial" in results
        
        # Create a new executor to verify system isn't broken
        new_executor = AsyncThreadPoolExecutor()
        future = new_executor.submit(lambda: "new_executor_works")
        assert future.result() == "new_executor_works"
        new_executor.shutdown()
    
    def test_graceful_cancellation(self):
        """Test that tasks support cancellation during shutdown."""
        executor = AsyncThreadPoolExecutor()
        results = []
        cancel_handled = threading.Event()
        
        async def cancellable_task():
            results.append("task_start")
            try:
                await asyncio.sleep(0.5)
                results.append("task_middle")
                await asyncio.sleep(0.5)
                results.append("task_end")
                return "completed"
            except asyncio.CancelledError:
                results.append("task_cancelled")
                cancel_handled.set()
                raise
        
        # Submit task
        future = executor.submit(cancellable_task)
        
        # Wait for task to start
        time.sleep(0.1)
        assert "task_start" in results
        
        # Request cancellation
        future.cancel()
        
        # Shutdown with wait=True
        executor.shutdown()
        
        # Task should handle cancellation
        assert cancel_handled.wait(timeout=1.0), "Task didn't handle cancellation"
        assert "task_cancelled" in results
        assert "task_end" not in results
        
        # Future should be marked as cancelled
        assert future.cancelled()