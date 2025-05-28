import pytest
import asyncio
import threading
import time
import dearcygui as dcg
from dearcygui.utils.asyncio_helpers import (
    AsyncPoolExecutor,
    AsyncThreadPoolExecutor,
    BatchingEventLoop
)

@pytest.fixture
def event_loop():
    """Create and return a standard asyncio event loop for testing."""
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    yield loop
    loop.close()

class TestAsyncPoolExecutor:
    """Tests for the AsyncPoolExecutor class."""
    
    def test_sync_function_execution(self, event_loop):
        """Test execution of synchronous functions."""
        async def f(self, event_loop):
            executor = AsyncPoolExecutor(event_loop)
            result = []
            
            def sync_function():
                result.append(1)
                return 42
            
            future = executor.submit(sync_function)
            assert await future == 42
            assert result == [1]
            executor.shutdown()
        event_loop.run_until_complete(f(self, event_loop))
    
    def test_async_function_execution(self, event_loop):
        """Test execution of asynchronous functions with awaits."""
        async def f(self, event_loop):
            executor = AsyncPoolExecutor(event_loop)
            result = []
            
            async def async_function():
                result.append(1)
                await asyncio.sleep(0.01)
                result.append(2)
                return 42
            
            future = executor.submit(async_function)
            assert await future == 42
            assert result == [1, 2]
            executor.shutdown()
        event_loop.run_until_complete(f(self, event_loop))
    
    def test_mixed_callbacks_execution_order(self, event_loop):
        """Test execution order when mixing normal and async callbacks."""
        async def f(self, event_loop):
            executor = AsyncPoolExecutor(event_loop)
            result = []
            
            def sync_function():
                result.append(1)
                return "sync"
            
            async def async_function():
                result.append(2)
                await asyncio.sleep(0.01)
                result.append(4)
                return "async"

            def other_sync_function():
                time.sleep(0.1) # Simulate a blocking call
                result.append(3)
                return "sync"
            
            future1 = executor.submit(sync_function)
            future2 = executor.submit(async_function)
            future3 = executor.submit(other_sync_function)
            
            assert await future1 == "sync"
            assert await future2 == "async"
            assert await future3 == "sync"
            assert result == [1, 2, 3, 4]
            executor.shutdown()
        event_loop.run_until_complete(f(self, event_loop))
    
    def test_no_early_execution(self, event_loop):
        """Test that callbacks don't execute before the submitting task completes."""
        async def f(self, event_loop):
            executor = AsyncPoolExecutor(event_loop)
            execution_order = []
            
            async def task_function():
                execution_order.append("task_start")
                future = executor.submit(callback_function)
                execution_order.append("task_end")
                return future
            
            def callback_function():
                execution_order.append("callback")
                return "done"
            
            future = await task_function()
            await asyncio.sleep(0.01)  # Ensure the callback completes
            
            assert execution_order == ["task_start", "task_end", "callback"]
            assert await future == "done"
            executor.shutdown()
        event_loop.run_until_complete(f(self, event_loop))
    
    def test_multiple_callbacks_order(self, event_loop):
        """Test that multiple callbacks are executed in the order they were submitted."""
        async def f(self, event_loop):
            executor = AsyncPoolExecutor(event_loop)
            result = []
            
            async def submitting_task():
                for i in range(5):
                    executor.submit(lambda x=i: result.append(x))
                return "done"
            
            await submitting_task()
            await asyncio.sleep(0.01)  # Ensure all callbacks complete
            
            assert result == [0, 1, 2, 3, 4]
            executor.shutdown()
        event_loop.run_until_complete(f(self, event_loop))
    
    def test_eager_task_factory(self, event_loop):
        """Test AsyncPoolExecutor with eager task factory."""
        async def f(self, event_loop):
            # Set eager task factory on the event loop
            old_factory = event_loop.get_task_factory()
            event_loop.set_task_factory(asyncio.eager_task_factory)
            
            executor = AsyncPoolExecutor(event_loop)
            result = []
            exec_thread = threading.current_thread()
            
            # Test that the barrier prevents eager execution
            async def submitting_task():
                result.append("task_start")
                future = executor.submit(lambda: result.append("callback"))
                result.append("task_end")
                return future
            
            future = await submitting_task()
            await future
            
            assert result == ["task_start", "task_end", "callback"]
            
            # Restore original task factory
            event_loop.set_task_factory(old_factory)
            executor.shutdown()
        event_loop.run_until_complete(f(self, event_loop))
    
    def test_varying_duration_callbacks(self, event_loop):
        """Test callbacks with varying durations to ensure order is preserved."""
        async def f(self, event_loop):
            executor = AsyncPoolExecutor(event_loop)
            result = []
            
            async def long_task(delay, idx):
                result.append(f"start_{idx}")
                await asyncio.sleep(delay)
                result.append(f"end_{idx}")
                return idx
            
            # Submit tasks with different durations in specific order
            futures = [
                executor.submit(long_task, 0.05, 1),  # Longer task
                executor.submit(long_task, 0.02, 2),  # Medium task
                executor.submit(long_task, 0.01, 3),  # Short task
            ]
            
            # Wait for all tasks to complete
            results = [await f for f in futures]
            
            # Start order should be preserved
            assert result[0:3] == ["start_1", "start_2", "start_3"]
            # End order should be duration-dependent
            assert result[3:] == ["end_3", "end_2", "end_1"]
            assert results == [1, 2, 3]
            executor.shutdown()
        event_loop.run_until_complete(f(self, event_loop))
    
    def test_nested_callbacks(self, event_loop):
        """Test nested callbacks where one callback submits another."""
        async def f(self, event_loop):
            executor = AsyncPoolExecutor(event_loop)
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
        event_loop.run_until_complete(f(self, event_loop))

class TestAsyncThreadPoolExecutor:
    """Tests for the AsyncThreadPoolExecutor class."""
    
    def test_default_loop_configuration(self):
        """Test with default loop factory."""
        executor = AsyncThreadPoolExecutor()
        results = []
        
        def sync_function():
            results.append(threading.current_thread().name)
            return 42
        
        future = executor.submit(sync_function)
        assert future.result() == 42
        assert len(results) == 1
        assert "MainThread" not in results[0]  # Should run in a different thread
        executor.shutdown()
    
    def test_batching_loop_configuration(self):
        """Test with BatchingEventLoop as the loop factory."""
        executor = AsyncThreadPoolExecutor(BatchingEventLoop.factory())
        results = []
        
        def sync_function():
            results.append(1)
            return 42
        
        future = executor.submit(sync_function)
        assert future.result() == 42
        assert results == [1]
        executor.shutdown()
    
    def test_async_function_execution(self):
        """Test execution of asynchronous functions with awaits."""
        executor = AsyncThreadPoolExecutor()
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
            result.append(4)
            return "async"

        def other_sync_function():
            time.sleep(0.1)
            result.append(3)
            return "sync"
        
        future1 = executor.submit(sync_function)
        future2 = executor.submit(async_function)
        future3 = executor.submit(other_sync_function)
        
        assert future1.result() == "sync"
        assert future2.result() == "async"
        assert future3.result() == "sync"
        assert result == [1, 2, 3, 4]
        executor.shutdown()
    
    def test_execution_order_preservation(self):
        """Test that tasks are executed in the order they were submitted."""
        executor = AsyncThreadPoolExecutor()
        results = []
        
        for i in range(5):
            executor.submit(lambda x=i: results.append(x))
        
        # Wait for all tasks to complete
        time.sleep(0.1)
        
        assert results == [0, 1, 2, 3, 4]
        executor.shutdown()
    
    def test_custom_loop_factory(self):
        """Test with a custom loop factory."""
        def custom_loop_factory():
            loop = asyncio.new_event_loop()
            loop.set_debug(True)
            return loop
        
        executor = AsyncThreadPoolExecutor(custom_loop_factory)
        result = []
        
        def sync_function():
            result.append(1)
            return 42
        
        future = executor.submit(sync_function)
        assert future.result() == 42
        assert result == [1]
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


try:
    import uvloop
    
    class TestUVLoopCompatibility:
        """Tests for compatibility with uvloop."""
        
        def test_async_pool_with_uvloop(self):
            """Test AsyncPoolExecutor with uvloop."""
            loop = uvloop.new_event_loop()
            asyncio.set_event_loop(loop)
            
            try:
                executor = AsyncPoolExecutor(loop)
                results = []
                
                async def async_fn():
                    results.append(1)
                    await asyncio.sleep(0.01)
                    results.append(2)
                    return 42
                
                async def run_test():
                    future = executor.submit(async_fn)
                    assert await future == 42
                    assert results == [1, 2]
                
                loop.run_until_complete(run_test())
                executor.shutdown()
            finally:
                loop.close()
                asyncio.set_event_loop(None)
        
        def test_async_thread_with_uvloop_factory(self):
            """Test AsyncThreadPoolExecutor with uvloop factory."""
            def uvloop_factory():
                return uvloop.new_event_loop()
            
            executor = AsyncThreadPoolExecutor(uvloop_factory)
            results = []
            
            async def async_fn():
                results.append(1)
                await asyncio.sleep(0.01)
                results.append(2)
                return 42
            
            future = executor.submit(async_fn)
            assert future.result() == 42
            assert results == [1, 2]
            executor.shutdown()
except ImportError:
    # uvloop not available, skip these tests
    pass
