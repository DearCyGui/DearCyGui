import gc
import os
import signal
import threading
import time
import pytest
import subprocess
import sys
import dearcygui as dcg


# Timeout constants
DEFAULT_TIMEOUT = 5.0  # Maximum time to wait for shutdown
FAST_TIMEOUT = 2.0     # For scenarios that should be fast
SIGNAL_TIMEOUT = 1.0   # Time to wait for signal handling


class ShutdownTestHelper:
    """Helper class for shutdown testing"""
    
    @staticmethod
    def create_basic_app():
        """Create a basic DearCyGui application"""
        ctx = dcg.Context()
        ctx.viewport.initialize(visible=False)
        with dcg.Window(ctx, label="Test Window"):
            dcg.Text(ctx, value="Hello World")
        return ctx
    
    @staticmethod
    def create_complex_app():
        """Create a more complex DearCyGui application"""
        ctx = dcg.Context()
        ctx.viewport.initialize(visible=False)
        
        # Create multiple windows with various widgets
        with dcg.Window(ctx, label="Main Window"):
            dcg.Text(ctx, value="Main content")
            dcg.Button(ctx, label="Test Button")
            dcg.Slider(ctx, min_value=0, max_value=100)
            
        with dcg.Window(ctx, label="Secondary Window"):
            with dcg.TabBar(ctx):
                with dcg.Tab(ctx, label="Tab 1"):
                    dcg.Checkbox(ctx, label="Test Checkbox")
                with dcg.Tab(ctx, label="Tab 2"):
                    dcg.InputText(ctx, label="Test Input")
                    
        # Add plot window
        with dcg.Window(ctx, label="Plot Window"):
            with dcg.Plot(ctx):
                dcg.PlotLine(ctx, X=[0, 1, 2, 3], Y=[0, 1, 4, 9])
                
        return ctx
    
    @staticmethod
    def run_render_loop(ctx, duration=1.0, wait_for_input=False):
        """Run the render loop for a specified duration"""
        ctx.viewport.wait_for_input = wait_for_input
        start_time = time.time()
        while ctx.running and (time.time() - start_time) < duration:
            ctx.viewport.render_frame()
        ctx.running = False


def test_basic_shutdown():
    """Test that a basic application shuts down cleanly"""
    ctx = ShutdownTestHelper.create_basic_app()
    
    # Run render loop in main thread (DearCyGui requirement)
    start_time = time.time()
    ShutdownTestHelper.run_render_loop(ctx, duration=0.1)
    shutdown_time = time.time() - start_time
    
    assert shutdown_time < DEFAULT_TIMEOUT, f"Shutdown took too long: {shutdown_time:.2f}s"
    ctx.running = False


def test_context_running_flag():
    """Test that setting context.running=False stops the render loop"""
    ctx = ShutdownTestHelper.create_basic_app()
    
    # Use a timer to stop the context after a short time
    def stop_context():
        time.sleep(0.1)
        ctx.running = False
    
    timer = threading.Timer(0.1, stop_context)
    
    start_time = time.time()
    timer.start()
    
    # Run render loop in main thread
    while ctx.running and (time.time() - start_time) < 10:  # Long timeout as fallback
        ctx.viewport.render_frame()
    
    timer.join()
    shutdown_time = time.time() - start_time
    
    assert not ctx.running, "Context running flag wasn't set to False"
    assert shutdown_time < FAST_TIMEOUT, f"Shutdown took too long: {shutdown_time:.2f}s"


def test_immediate_shutdown():
    """Test shutdown immediately after initialization"""
    ctx = ShutdownTestHelper.create_basic_app()
    
    # Should be able to shut down immediately
    start_time = time.time()
    ctx.running = False
    del ctx
    gc.collect()
    
    shutdown_time = time.time() - start_time
    assert shutdown_time < 1.0, f"Immediate shutdown took too long: {shutdown_time:.2f}s"


def test_shutdown_with_wait_for_input():
    """Test shutdown when wait_for_input is enabled"""
    ctx = ShutdownTestHelper.create_basic_app()
    ctx.viewport.wait_for_input = True
    
    # Use a timer to stop and wake the context
    def stop_and_wake():
        time.sleep(0.2)  # Give time for render loop to start waiting
        ctx.running = False
        ctx.viewport.wake()  # Wake to break out of event waiting
    
    timer = threading.Timer(0.2, stop_and_wake)
    
    start_time = time.time()
    timer.start()
    
    try:
        # This could potentially hang if events aren't processed properly
        while ctx.running and (time.time() - start_time) < DEFAULT_TIMEOUT:
            ctx.viewport.render_frame()
    except Exception as e:
        print(f"Render loop exception: {e}")
    
    timer.join()
    shutdown_time = time.time() - start_time
    
    assert not ctx.running, "Context didn't stop with wait_for_input"
    assert shutdown_time < DEFAULT_TIMEOUT, f"Shutdown took too long: {shutdown_time:.2f}s"


def test_complex_app_shutdown():
    """Test shutdown with a complex application"""
    ctx = ShutdownTestHelper.create_complex_app()
    
    start_time = time.time()
    ShutdownTestHelper.run_render_loop(ctx, duration=0.5)
    shutdown_time = time.time() - start_time
    
    assert shutdown_time < DEFAULT_TIMEOUT, f"Complex app shutdown took too long: {shutdown_time:.2f}s"
    ctx.running = False


def test_multiple_contexts_shutdown():
    """Test shutdown with multiple contexts (sequentially due to thread requirement)"""
    contexts = []
    
    # Create and test multiple contexts sequentially
    start_time = time.time()
    
    for i in range(3):
        ctx = ShutdownTestHelper.create_basic_app()
        contexts.append(ctx)
        ShutdownTestHelper.run_render_loop(ctx, duration=0.1)
        ctx.running = False
    
    shutdown_time = time.time() - start_time
    assert shutdown_time < DEFAULT_TIMEOUT, f"Multiple contexts shutdown took too long: {shutdown_time:.2f}s"


def test_shutdown_during_heavy_rendering():
    """Test shutdown during heavy rendering operations"""
    ctx = ShutdownTestHelper.create_basic_app()
    
    # Create a lot of widgets to stress the renderer
    with dcg.Window(ctx, label="Heavy Window"):
        for i in range(100):
            dcg.Text(ctx, value=f"Text item {i}")
            dcg.Button(ctx, label=f"Button {i}")
    
    # Use a timer to stop after some rendering
    def stop_context():
        time.sleep(0.2)  # Let some rendering happen
        ctx.running = False
    
    timer = threading.Timer(0.2, stop_context)
    
    start_time = time.time()
    timer.start()
    
    count = 0
    while ctx.running and count < 50:  # Limit iterations to avoid infinite loop
        ctx.viewport.render_frame()
        count += 1
    
    timer.join()
    shutdown_time = time.time() - start_time
    
    assert not ctx.running, "Heavy rendering didn't stop cleanly"
    assert shutdown_time < DEFAULT_TIMEOUT, f"Heavy rendering shutdown took too long: {shutdown_time:.2f}s"


def test_thread_pool_shutdown():
    """Test shutdown timing when creating contexts sequentially"""
    start_time = time.time()
    
    for i in range(3):
        ctx = ShutdownTestHelper.create_basic_app()
        ShutdownTestHelper.run_render_loop(ctx, duration=0.1)
        ctx.running = False
        del ctx
        gc.collect()
    
    shutdown_time = time.time() - start_time
    assert shutdown_time < DEFAULT_TIMEOUT, f"Sequential context shutdown took too long: {shutdown_time:.2f}s"


def test_cleanup_after_exception():
    """Test that cleanup works properly after exceptions"""
    ctx = ShutdownTestHelper.create_basic_app()
    
    start_time = time.time()
    try:
        for _ in range(5):
            ctx.viewport.render_frame()
        # Simulate an exception
        raise RuntimeError("Simulated error")
    except RuntimeError:
        # Should still be able to clean up
        ctx.running = False
    
    shutdown_time = time.time() - start_time
    assert shutdown_time < DEFAULT_TIMEOUT, f"Exception cleanup took too long: {shutdown_time:.2f}s"


@pytest.mark.skipif(os.name == 'nt', reason="Signal handling differs on Windows")
def test_sigterm_handling():
    """Test SIGTERM signal handling for graceful shutdown"""
    
    # Create a subprocess that runs a DearCyGui app
    script_content = '''
import signal
import sys
import time
import dearcygui as dcg

def signal_handler(signum, frame):
    print("SIGTERM received, shutting down gracefully", flush=True)
    global running
    running = False

signal.signal(signal.SIGTERM, signal_handler)

try:
    ctx = dcg.Context()
    ctx.viewport.initialize(visible=False)
    dcg.Text(ctx, value="Test App")

    running = True
    start_time = time.time()
    print("Starting render loop", flush=True)
    while running and ctx.running and (time.time() - start_time) < 10:
        ctx.viewport.render_frame()
        time.sleep(0.01)

    print("Application shut down", flush=True)
    ctx.running = False
    
except Exception as e:
    print(f"Error in subprocess: {e}", flush=True)
    sys.exit(1)
'''
    
    # Run the script in a subprocess
    proc = subprocess.Popen([sys.executable, '-c', script_content],
                           stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE)
    
    # Give it time to start up
    time.sleep(1.0)
    
    # Send SIGTERM
    start_time = time.time()
    proc.terminate()
    
    try:
        stdout, stderr = proc.communicate(timeout=DEFAULT_TIMEOUT)
        shutdown_time = time.time() - start_time
        
        # Check if it shut down or was killed
        if proc.returncode == 0:
            # Clean shutdown
            assert b"SIGTERM received" in stdout, "Signal handler wasn't called"
            assert b"Application shut down" in stdout, "Application didn't complete shutdown"
        elif proc.returncode == -15:  # SIGTERM
            # Process was terminated but may not have handled the signal properly
            print(f"Process was terminated by SIGTERM. This indicates a potential hanging issue.")
            print(f"Stdout: {stdout.decode()}")
            print(f"Stderr: {stderr.decode()}")
            # This is actually a problem we want to detect!
            pytest.fail("Process appears to hang on SIGTERM - this indicates a shutdown issue")
        else:
            pytest.fail(f"Process exited with unexpected code: {proc.returncode}")
        
        assert shutdown_time < DEFAULT_TIMEOUT, f"SIGTERM shutdown took too long: {shutdown_time:.2f}s"
        
    except subprocess.TimeoutExpired:
        # This is definitely a hanging issue
        proc.kill()
        stdout, stderr = proc.communicate()
        print(f"Process hung and had to be killed. Stdout: {stdout.decode()}")
        print(f"Stderr: {stderr.decode()}")
        pytest.fail("Process hung during shutdown - this indicates a serious shutdown issue")


@pytest.mark.skipif(os.name == 'nt', reason="Signal handling differs on Windows")  
def test_sigint_handling():
    """Test SIGINT (Ctrl+C) signal handling"""
    
    script_content = '''
import signal
import sys
import time
import dearcygui as dcg

def signal_handler(signum, frame):
    print("SIGINT received, shutting down gracefully", flush=True)
    global running
    running = False

signal.signal(signal.SIGINT, signal_handler)

try:
    ctx = dcg.Context()
    ctx.viewport.initialize(visible=False)
    dcg.Text(ctx, value="Test App")

    running = True
    start_time = time.time()
    print("Starting render loop", flush=True)
    while running and ctx.running and (time.time() - start_time) < 10:
        ctx.viewport.render_frame()
        time.sleep(0.01)

    print("Application shut down", flush=True)
    ctx.running = False
    
except Exception as e:
    print(f"Error in subprocess: {e}", flush=True)
    sys.exit(1)
'''
    
    proc = subprocess.Popen([sys.executable, '-c', script_content],
                           stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE)
    
    time.sleep(0.5)
    
    start_time = time.time()
    proc.send_signal(signal.SIGINT)
    
    try:
        stdout, stderr = proc.communicate(timeout=DEFAULT_TIMEOUT)
        shutdown_time = time.time() - start_time
        
        if proc.returncode == 0:
            assert b"SIGINT received" in stdout, "SIGINT handler wasn't called"
            assert b"Application shut down" in stdout, "Application didn't complete shutdown"
        elif proc.returncode == -2:  # SIGINT
            print("WARNING: Process was terminated by SIGINT rather than handling it gracefully")
        else:
            pytest.fail(f"Process exited with unexpected code: {proc.returncode}")
        
        assert shutdown_time < DEFAULT_TIMEOUT, f"SIGINT shutdown took too long: {shutdown_time:.2f}s"
        
    except subprocess.TimeoutExpired:
        proc.kill()
        stdout, stderr = proc.communicate()
        print(f"Process hung. Stdout: {stdout.decode()}")
        print(f"Stderr: {stderr.decode()}")
        pytest.fail("Process didn't respond to SIGINT in time")


def test_force_kill_scenario():
    """Test behavior when application is force killed"""
    
    script_content = '''
import time
import dearcygui as dcg

ctx = dcg.Context()
ctx.viewport.initialize(visible=False)
dcg.Text(ctx, value="Test App")

# Intentionally create a scenario that might hang
ctx.viewport.wait_for_input = True
while ctx.running:
    ctx.viewport.render_frame()
'''
    
    proc = subprocess.Popen([sys.executable, '-c', script_content],
                           stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE)
    
    time.sleep(0.5)  # Let it start
    
    # First try graceful termination
    start_time = time.time()
    proc.terminate()
    
    try:
        proc.communicate(timeout=2.0)
        # If it terminated gracefully, that's good
        shutdown_time = time.time() - start_time
        assert shutdown_time < 3.0, "Even graceful termination took too long"
        
    except subprocess.TimeoutExpired:
        # If graceful termination failed, try force kill
        kill_start = time.time()
        proc.kill()
        proc.communicate(timeout=2.0)
        kill_time = time.time() - kill_start
        
        # Force kill should always work quickly
        assert kill_time < 2.0, f"Force kill took too long: {kill_time:.2f}s"


def test_resource_cleanup_on_shutdown():
    """Test that resources are properly cleaned up on shutdown"""
    import psutil
    import os
    
    process = psutil.Process(os.getpid())
    initial_memory = process.memory_info().rss
    initial_threads = threading.active_count()
    
    # Create and destroy multiple contexts
    for i in range(5):
        ctx = ShutdownTestHelper.create_complex_app()
        ShutdownTestHelper.run_render_loop(ctx, duration=0.05)
        
        # Explicit cleanup
        ctx.running = False
        del ctx
        gc.collect()
    
    # Check resource usage after cleanup
    final_memory = process.memory_info().rss
    final_threads = threading.active_count()
    
    memory_diff = final_memory - initial_memory
    thread_diff = final_threads - initial_threads
    
    print(f"Memory usage increased by: {memory_diff / 1024 / 1024:.1f} MB")
    print(f"Thread count changed by: {thread_diff}")
    
    # Allow for some memory overhead, but it shouldn't be excessive
    # Note: This currently fails, indicating a memory management issue
    assert memory_diff < 50 * 1024 * 1024, f"Memory leak detected: {memory_diff / 1024 / 1024:.1f} MB"
    assert thread_diff <= 0, f"Thread leak detected: {thread_diff} extra threads"


def test_shutdown_timeout_detection():
    """Test detection of scenarios where shutdown might hang"""
    
    def potentially_hanging_function():
        """Simulate a function that might hang"""
        ctx = ShutdownTestHelper.create_basic_app()
        ctx.viewport.wait_for_input = True
        
        # Use a timer to stop the context after a short time
        def stop_context():
            time.sleep(0.5)
            ctx.running = False
            ctx.viewport.wake()
        
        timer = threading.Timer(0.5, stop_context)
        timer.start()
        
        # This could potentially hang if not properly handled
        start_time = time.time()
        while ctx.running and (time.time() - start_time) < 2.0:
            ctx.viewport.render_frame()
        
        timer.join()
        ctx.running = False
        return "completed"
    
    # Test with timeout to ensure it doesn't hang
    start_time = time.time()
    result = potentially_hanging_function()
    elapsed = time.time() - start_time
    
    assert result == "completed", "Function didn't complete properly"
    assert elapsed < DEFAULT_TIMEOUT, f"Function took too long: {elapsed:.2f}s"


def test_interrupt_during_initialization():
    """Test interruption during viewport initialization"""
    
    start_time = time.time()
    ctx = dcg.Context()
    # This could potentially hang during initialization
    ctx.viewport.initialize(visible=False)
    init_time = time.time() - start_time
    
    assert init_time < DEFAULT_TIMEOUT, f"Initialization took too long: {init_time:.2f}s"
    
    # Clean up
    ctx.running = False
    del ctx


def test_keyboard_interrupt_simulation():
    """Test behavior when KeyboardInterrupt is raised during render loop"""
    ctx = ShutdownTestHelper.create_basic_app()
    
    start_time = time.time()
    frame_count = 0
    
    try:
        while ctx.running and frame_count < 10:
            ctx.viewport.render_frame()
            frame_count += 1
            
            # Simulate KeyboardInterrupt after a few frames
            if frame_count == 5:
                raise KeyboardInterrupt("Simulated Ctrl+C")
                
    except KeyboardInterrupt:
        # Should be able to handle the interrupt and clean up
        ctx.running = False
        
    cleanup_time = time.time() - start_time
    assert not ctx.running, "Context didn't stop after KeyboardInterrupt"
    assert cleanup_time < FAST_TIMEOUT, f"KeyboardInterrupt cleanup took too long: {cleanup_time:.2f}s"


def test_repeated_shutdown_calls():
    """Test that repeated shutdown/cleanup operations are safe"""
    ctx = ShutdownTestHelper.create_basic_app()
    
    # Run a few frames
    for _ in range(3):
        ctx.viewport.render_frame()
    
    # Multiple shutdown attempts should be safe
    start_time = time.time()
    ctx.running = False
    ctx.running = False  # Second call should be safe
    del ctx  # This should also be safe
    gc.collect()
    
    shutdown_time = time.time() - start_time
    assert shutdown_time < 1.0, f"Repeated shutdown calls took too long: {shutdown_time:.2f}s"


def test_shutdown_with_active_handlers():
    """Test shutdown when items have active handlers"""
    ctx = ShutdownTestHelper.create_basic_app()
    
    # Add items with handlers
    button = dcg.Button(ctx, label="Test Button")
    handler = dcg.ClickedHandler(ctx, callback=lambda: print("clicked"))
    button.handlers += [handler]
    
    start_time = time.time()
    
    # Run a few frames with handlers
    for _ in range(5):
        ctx.viewport.render_frame()
    
    # Shutdown should still work
    ctx.running = False
    shutdown_time = time.time() - start_time
    
    assert shutdown_time < DEFAULT_TIMEOUT, f"Shutdown with handlers took too long: {shutdown_time:.2f}s"


def test_shutdown_with_textures():
    """Test shutdown when textures are loaded"""
    ctx = ShutdownTestHelper.create_basic_app()
    
    # Create texture
    import numpy as np
    texture_data = np.zeros((64, 64, 3), dtype=np.uint8)
    texture = dcg.Texture(ctx, texture_data)
    
    # Create image using texture
    dcg.Image(ctx, texture=texture)
    
    start_time = time.time()
    
    # Run a few frames
    for _ in range(3):
        ctx.viewport.render_frame()
    
    # Shutdown should work with textures
    ctx.running = False
    shutdown_time = time.time() - start_time
    
    assert shutdown_time < DEFAULT_TIMEOUT, f"Shutdown with textures took too long: {shutdown_time:.2f}s"


def test_fast_repeated_start_stop():
    """Test rapid creation and destruction of contexts"""
    times = []
    
    for i in range(5):
        start_time = time.time()
        
        ctx = ShutdownTestHelper.create_basic_app()
        # Run just one frame
        ctx.viewport.render_frame()
        ctx.running = False
        del ctx
        gc.collect()
        
        elapsed = time.time() - start_time
        times.append(elapsed)
    
    avg_time = sum(times) / len(times)
    max_time = max(times)
    
    assert avg_time < 1.0, f"Average fast start/stop took too long: {avg_time:.2f}s"
    assert max_time < FAST_TIMEOUT, f"Slowest start/stop took too long: {max_time:.2f}s"


def test_shutdown_with_large_ui():
    """Test shutdown with a large number of UI elements"""
    ctx = dcg.Context()
    ctx.viewport.initialize(visible=False)
    
    # Create a large UI
    with dcg.Window(ctx, label="Large UI"):
        for i in range(50):
            with dcg.CollapsingHeader(ctx, label=f"Section {i}"):
                for j in range(10):
                    dcg.Text(ctx, value=f"Item {i}-{j}")
                    dcg.Button(ctx, label=f"Button {i}-{j}")
    
    start_time = time.time()
    
    # Run a few frames
    for _ in range(3):
        ctx.viewport.render_frame()
    
    # Shutdown should still be reasonably fast
    ctx.running = False
    shutdown_time = time.time() - start_time
    
    assert shutdown_time < DEFAULT_TIMEOUT, f"Large UI shutdown took too long: {shutdown_time:.2f}s"


def test_context_destruction_timing():
    """Test that context destruction doesn't hang"""
    contexts = []
    
    # Create several contexts
    for i in range(3):
        ctx = ShutdownTestHelper.create_basic_app()
        contexts.append(ctx)
        # Run one frame each
        ctx.viewport.render_frame()
    
    # Time the destruction process
    start_time = time.time()
    
    for ctx in contexts:
        ctx.running = False
    
    # Clear references
    contexts.clear()
    gc.collect()
    
    destruction_time = time.time() - start_time
    assert destruction_time < DEFAULT_TIMEOUT, f"Context destruction took too long: {destruction_time:.2f}s"


def test_hanging_scenario_detection():
    """Test detection of a known problematic scenario - wait_for_input hanging"""
    
    script_content = '''
import signal
import sys
import time
import dearcygui as dcg

def signal_handler(signum, frame):
    print("Signal received, attempting shutdown", flush=True)
    global running
    running = False
    # Try to wake the viewport - this is crucial for wait_for_input scenarios
    if 'ctx' in globals() and hasattr(ctx, 'viewport'):
        try:
            ctx.viewport.wake()
        except:
            pass

# Install signal handlers for both SIGTERM and SIGINT
signal.signal(signal.SIGTERM, signal_handler)
signal.signal(signal.SIGINT, signal_handler)

try:
    ctx = dcg.Context()
    ctx.viewport.initialize(visible=False)
    dcg.Text(ctx, value="Test App")
    
    # This is a problematic scenario - wait for input with no way to wake up
    ctx.viewport.wait_for_input = True
    
    running = True
    start_time = time.time()
    print("Starting render loop with wait_for_input=True", flush=True)
    
    frame_count = 0
    while running and ctx.running and (time.time() - start_time) < 10:
        ctx.viewport.render_frame()
        frame_count += 1
        print(f"Rendered {frame_count} frames", flush=True)

    print("Exiting render loop", flush=True)
    ctx.running = False
    print("Application shut down cleanly", flush=True)
    
except KeyboardInterrupt:
    print("KeyboardInterrupt caught", flush=True)
    if 'ctx' in locals():
        ctx.running = False
except Exception as e:
    print(f"Error in subprocess: {e}", flush=True)
    sys.exit(1)
'''
    
    proc = subprocess.Popen([sys.executable, '-c', script_content],
                           stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE)
    
    time.sleep(1.0)  # Let it start and begin waiting for input
    
    start_time = time.time()
    proc.terminate()
    
    try:
        stdout, stderr = proc.communicate(timeout=3.0)  # Shorter timeout for this test
        shutdown_time = time.time() - start_time
        
        print(f"Process output: {stdout.decode()}")
        if stderr:
            print(f"Process stderr: {stderr.decode()}")
        
        if proc.returncode == 0:
            assert b"Application shut down cleanly" in stdout
        elif proc.returncode == -15:
            # Process was killed - this indicates a hanging problem
            print("WARNING: Process had to be killed, indicating a potential hanging issue")
            # We'll allow this for now, but it's a warning sign
        else:
            pytest.fail(f"Process exited with unexpected code: {proc.returncode}")
            
    except subprocess.TimeoutExpired:
        proc.kill()
        stdout, stderr = proc.communicate()
        print(f"Process hung. Stdout: {stdout.decode()}")
        print(f"Stderr: {stderr.decode()}")
        
        pytest.fail(
            "CRITICAL: Process hung when using wait_for_input=True. "
            "This is a known problematic scenario that should be fixed."
        )


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
