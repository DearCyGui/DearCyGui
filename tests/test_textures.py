import pytest
import numpy as np
import dearcygui as dcg
import time
import threading
import sys

# Define constants for testing
MAX_TEXTURE_SIZE = 8192  # Most GPUs support at least this size

@pytest.fixture
def capture_context():
    """Create a context for texture testing."""
    ctx = dcg.Context()
    # Initialize with framebuffer retrieval
    ctx.viewport.initialize(visible=False,
                            always_submit_to_gpu=True,
                            retrieve_framebuffer=True,
                            width=512, height=512)
    yield ctx

@pytest.fixture
def ctx():
    # Create a minimal context for testing.
    C = dcg.Context()
    return C

def test_texture_creation_with_numpy_arrays(ctx):
    """Test creating textures with numpy arrays of different shapes and types."""
    # 0D array (scalar)
    data_0d = np.empty((0,), dtype=np.uint8)
    with pytest.raises(ValueError, match="Cannot set empty texture"):
        dcg.Texture(ctx, data_0d)

    # 1D array (height=1)
    data_1d = np.zeros((10,), dtype=np.uint8)
    tex_1d = dcg.Texture(ctx, data_1d)
    assert tex_1d.width == 1
    assert tex_1d.height == 10
    assert tex_1d.num_chans == 1
    
    # 2D array (single channel)
    data_2d = np.zeros((20, 30), dtype=np.uint8)
    tex_2d = dcg.Texture(ctx, data_2d)
    assert tex_2d.width == 30
    assert tex_2d.height == 20
    assert tex_2d.num_chans == 1
    
    # 3D array (RGB)
    data_3d_rgb = np.zeros((40, 50, 3), dtype=np.uint8)
    tex_3d_rgb = dcg.Texture(ctx, data_3d_rgb)
    assert tex_3d_rgb.width == 50
    assert tex_3d_rgb.height == 40
    assert tex_3d_rgb.num_chans == 3
    
    # 3D array (RGBA)
    data_3d_rgba = np.zeros((60, 70, 4), dtype=np.uint8)
    tex_3d_rgba = dcg.Texture(ctx, data_3d_rgba)
    assert tex_3d_rgba.width == 70
    assert tex_3d_rgba.height == 60
    assert tex_3d_rgba.num_chans == 4
    
    # Float texture
    data_float = np.zeros((20, 30, 3), dtype=np.float32)
    tex_float = dcg.Texture(ctx, data_float)
    assert tex_float.width == 30
    assert tex_float.height == 20
    assert tex_float.num_chans == 3

def test_texture_creation_with_python_lists(ctx):
    """Test creating textures with Python lists."""
    # 1D list
    data_1d = [0] * 10
    tex_1d = dcg.Texture(ctx, data_1d)
    assert tex_1d.width == 10
    assert tex_1d.height == 1
    assert tex_1d.num_chans == 1
    
    # 2D list
    data_2d = [[0] * 30 for _ in range(20)]
    tex_2d = dcg.Texture(ctx, data_2d)
    assert tex_2d.width == 30
    assert tex_2d.height == 20
    assert tex_2d.num_chans == 1
    
    # 3D list (RGB)
    data_3d_rgb = [[[0, 128, 255] for _ in range(50)] for _ in range(40)]
    tex_3d_rgb = dcg.Texture(ctx, data_3d_rgb)
    assert tex_3d_rgb.width == 50
    assert tex_3d_rgb.height == 40
    assert tex_3d_rgb.num_chans == 3

def test_texture_creation_invalid_dimensions(ctx):
    """Test error handling for invalid dimensions."""
    # Empty array
    with pytest.raises(ValueError, match="Cannot set empty texture"):
        dcg.Texture(ctx, np.array([]))
    
    # 4D array (too many dimensions)
    with pytest.raises(ValueError, match="Invalid number of texture dimensions"):
        dcg.Texture(ctx, np.zeros((10, 10, 3, 2), dtype=np.uint8))

def test_texture_creation_invalid_types(ctx):
    """Test error handling for invalid types."""
    # Complex type (not supported)
    with pytest.raises(ValueError, match="Invalid texture format"):
        dcg.Texture(ctx, np.zeros((10, 10), dtype=np.complex64))


def test_texture_creation_large(ctx):
    """Test creating very large textures."""
    # Create a texture just below the maximum size
    try:
        # Start with a smaller size that won't fail on most systems
        medium_size = 4096
        medium_tex = dcg.Texture(ctx, np.zeros((medium_size, medium_size), dtype=np.uint8))
        assert medium_tex.width == medium_size
        assert medium_tex.height == medium_size
    except Exception as e:
        print(f"Note: Could not create texture of size {medium_size}x{medium_size}: {e}")
    
    # Create a texture way beyond reasonable limits
    with pytest.raises((ValueError, MemoryError, RuntimeError)):
        # This should be too large for any GPU
        # GPUs have limits on the width and height of textures,
        # due to the hardware bilinear filtering.
        dcg.Texture(ctx, np.zeros((100000, 2), dtype=np.uint8))

def test_texture_properties(ctx):
    """Test texture properties."""
    # Create a texture
    tex = dcg.Texture(ctx)
    
    # Test hint_dynamic property
    assert not tex.hint_dynamic
    tex.hint_dynamic = True
    assert tex.hint_dynamic
    
    # Test nearest_neighbor_upsampling property
    assert not tex.nearest_neighbor_upsampling
    tex.nearest_neighbor_upsampling = True
    assert tex.nearest_neighbor_upsampling
    
    # Test wrap_x and wrap_y properties
    assert not tex.wrap_x
    assert not tex.wrap_y
    tex.wrap_x = True
    tex.wrap_y = True
    assert tex.wrap_x
    assert tex.wrap_y
    
    # Test antialiased property
    assert not tex.antialiased
    tex.antialiased = True
    assert tex.antialiased

def test_texture_property_changes_after_allocation(ctx):
    """Test that changing properties after allocation raises appropriate errors."""
    # Create and allocate texture
    tex = dcg.Texture(ctx)
    # Set initial properties
    tex.hint_dynamic = False
    tex.nearest_neighbor_upsampling = False
    tex.wrap_x = False
    tex.wrap_y = False
    tex.antialiased = False
    tex.allocate(width=100, height=100, num_chans=3, uint8=True)
    
    # Changing properties after allocation should raise PermissionError
    with pytest.raises(PermissionError):
        tex.hint_dynamic = True
    
    with pytest.raises(PermissionError):
        tex.nearest_neighbor_upsampling = True
    
    with pytest.raises(PermissionError):
        tex.wrap_x = True
    
    with pytest.raises(PermissionError):
        tex.wrap_y = True
    
    with pytest.raises(PermissionError):
        tex.antialiased = True

def test_texture_update_same_size(ctx):
    """Test updating a texture with the same dimensions and type."""
    # Create initial texture
    data = np.zeros((20, 30, 3), dtype=np.uint8)
    tex = dcg.Texture(ctx, data)
    
    # Update with same dimensions
    data_new = np.ones((20, 30, 3), dtype=np.uint8) * 255
    tex.set_value(data_new)
    
    # Verify dimensions haven't changed
    assert tex.width == 30
    assert tex.height == 20
    assert tex.num_chans == 3
    
    # Verify content by reading back the texture
    read_data = tex.read()
    assert read_data.shape == (20, 30, 3)
    assert read_data[0, 0, 0] == 255

def test_texture_update_different_size(ctx):
    """Test updating a texture with different dimensions."""
    # Create initial texture
    data = np.zeros((20, 30, 3), dtype=np.uint8)
    tex = dcg.Texture(ctx, data)
    
    # Update with different dimensions
    data_new = np.ones((40, 50, 3), dtype=np.uint8) * 255
    tex.set_value(data_new)
    
    # Verify dimensions have changed
    assert tex.width == 50
    assert tex.height == 40
    assert tex.num_chans == 3
    
    # Verify content
    read_data = tex.read()
    assert read_data.shape == (40, 50, 3)
    assert read_data[0, 0, 0] == 255

def test_texture_update_different_type(ctx):
    """Test updating a texture with different type."""
    # Create initial texture with uint8
    data = np.zeros((20, 30, 3), dtype=np.uint8)
    tex = dcg.Texture(ctx, data)
    
    # Update with float32
    data_new = np.ones((20, 30, 3), dtype=np.float32) * 0.5
    tex.set_value(data_new)
    
    # Read back and verify
    read_data = np.asarray(tex.read())
    # The exact value might vary due to precision, but should be close to 0.5
    assert read_data.dtype == np.float32
    assert 0.45 <= read_data[0, 0, 0] <= 0.55

def test_texture_update_different_channels(ctx):
    """Test updating a texture with different number of channels."""
    # Create initial texture with RGB
    data = np.zeros((20, 30, 3), dtype=np.uint8)
    tex = dcg.Texture(ctx, data)
    
    # Update with RGBA
    data_new = np.ones((20, 30, 4), dtype=np.uint8) * 255
    tex.set_value(data_new)
    
    # Verify channels have changed
    assert tex.num_chans == 4
    
    # Verify content
    read_data = tex.read()
    assert read_data.shape == (20, 30, 4)
    assert read_data[0, 0, 3] == 255  # Alpha channel

def test_texture_update_no_realloc(ctx):
    """Test updating a texture with no_realloc flag set."""
    # Create a texture
    tex = dcg.Texture(ctx)
    
    # Allocate with no_realloc=True
    tex.allocate(width=20, height=30, num_chans=3, uint8=True, no_realloc=True)
    
    # Update with same dimensions should work
    data_same = np.zeros((30, 20, 3), dtype=np.uint8)  # Note: shape is (height, width, channels)
    tex.set_value(data_same)
    
    # Update with different dimensions should fail
    data_different = np.zeros((40, 50, 3), dtype=np.uint8)
    with pytest.raises(ValueError, match="Texture cannot be reallocated"):
        tex.set_value(data_different)

def test_texture_read(ctx):
    """Test reading back texture content."""
    # Create a test pattern
    data = np.zeros((30, 40, 3), dtype=np.uint8)
    data[5:15, 10:20, 0] = 255  # Red rectangle
    data[8:12, 5:25, 1] = 255  # Green horizontal bar
    
    tex = dcg.Texture(ctx, data)
    
    # Read back full texture
    read_data = tex.read()
    assert read_data.shape == (30, 40, 3)
    assert read_data[10, 15, 0] == 255  # Should be in red rectangle
    assert read_data[10, 15, 1] == 255  # Should be in green bar
    assert read_data[0, 0, 0] == 0      # Should be black
    
    # Read with cropping
    crop_data = tex.read(x0=10, y0=5, crop_width=10, crop_height=10)
    assert crop_data.shape == (10, 10, 3)
    assert crop_data[5, 5, 0] == 255    # Should be in red rectangle
    assert crop_data[5, 5, 1] == 255    # Should be in green bar

def test_texture_read_invalid(ctx):
    """Test invalid texture read operations."""
    # Create a texture
    data = np.zeros((20, 30, 3), dtype=np.uint8)
    tex = dcg.Texture(ctx, data)
    
    # Test invalid coordinates
    with pytest.raises(ValueError, match="Negative x coordinate"):
        tex.read(x0=-1)
    
    with pytest.raises(ValueError, match="Negative y coordinate"):
        tex.read(y0=-1)
    
    with pytest.raises(ValueError, match="Invalid crop width"):
        tex.read(crop_width=-1)
    
    with pytest.raises(ValueError, match="Invalid crop height"):
        tex.read(crop_height=-1)
    
    # Test out-of-bounds coordinates
    with pytest.raises(ValueError, match="Crop extends beyond texture width"):
        tex.read(x0=25, crop_width=10)
    
    with pytest.raises(ValueError, match="Crop extends beyond texture height"):
        tex.read(y0=15, crop_height=10)

def test_visual_verification_rgba(capture_context):
    """Test that RGBA textures are rendered correctly."""
    ctx = capture_context
    
    # Create a test pattern with transparency
    data = np.zeros((100, 100, 4), dtype=np.uint8)
    data[:, :, 0] = 255  # Red channel
    data[:, :, 3] = 128  # Alpha channel (half transparent)
    
    # Create texture
    tex = dcg.Texture(ctx, data)
    
    # Clear the screen to black
    ctx.viewport.clear_color = (0, 0, 0, 255)
    
    # Display the texture
    with dcg.ViewportDrawList(ctx, front=True) as dl:
        dcg.DrawImage(ctx, texture=tex, pmin=(50, 50), pmax=(150, 150))
    
    # Render a frame
    while not ctx.viewport.render_frame():
        continue
    
    # Get the framebuffer
    framebuffer = ctx.viewport.framebuffer
    assert framebuffer is not None
    
    # Read back the texture
    fb_data = np.asarray(framebuffer.read())[::-1, :, :]  # Flip vertically for correct orientation
    assert np.max(fb_data[:,:,:3]) > 0  # Ensure something was rendered
    
    # Check the rendered pixels (accounting for blending with background)
    # The exact values might depend on the background color and blending mode
    assert fb_data[75, 75, 0] > 100  # Should have significant red
    assert fb_data[75, 75, 1] < 50   # Should have little green
    assert fb_data[75, 75, 2] < 50   # Should have little blue
    
    # Check outside the texture region (should be background color)
    assert fb_data[25, 25, 0] < 50  # Should be black outside texture

def test_visual_verification_rgb(capture_context):
    """Test that RGB textures are rendered correctly."""
    ctx = capture_context
    
    # Create a test pattern
    data = np.zeros((100, 100, 3), dtype=np.uint8)
    data[:50, :, 1] = 255  # Green in top half
    data[50:, :, 2] = 255  # Blue in bottom half
    
    # Create texture
    tex = dcg.Texture(ctx, data)
    
    # Display the texture
    with dcg.ViewportDrawList(ctx, front=True) as dl:
        dcg.DrawImage(ctx, texture=tex, pmin=(50, 50), pmax=(150, 150))
    
    # Render a frame
    while not ctx.viewport.render_frame():
        continue
    
    # Get the framebuffer
    framebuffer = ctx.viewport.framebuffer
    assert framebuffer is not None
    
    # Read back the framebuffer
    fb_data = np.asarray(framebuffer.read())[::-1, :, :]  # Flip vertically for correct orientation
    
    # Check the rendered pixels (top half - green)
    assert fb_data[60, 100, 0] < 50   # Low red
    assert fb_data[60, 100, 1] > 200  # High green
    assert fb_data[60, 100, 2] < 50   # Low blue
    
    # Check the rendered pixels (bottom half - blue)
    assert fb_data[125, 100, 0] < 50  # Low red
    assert fb_data[125, 100, 1] < 50  # Low green
    assert fb_data[125, 100, 2] > 200 # High blue

def test_texture_allocation(ctx):
    """Test allocating a texture without initial content."""
    # Create texture
    tex = dcg.Texture(ctx)
    
    # Allocate with different formats
    tex.allocate(width=100, height=200, num_chans=4, uint8=True, no_realloc=False)
    assert tex.width == 100
    assert tex.height == 200
    assert tex.num_chans == 4
    
    # Invalid allocation (missing format)
    with pytest.raises(ValueError, match="Invalid texture format"):
        tex.allocate(width=100, height=100, num_chans=3, no_realloc=False)
    
    # Invalid allocation (negative dimensions)
    with pytest.raises(ValueError, match="Width must be positive"):
        tex.allocate(width=-1, height=100, num_chans=3, uint8=True, no_realloc=False)
    
    with pytest.raises(ValueError, match="Height must be positive"):
        tex.allocate(width=100, height=-1, num_chans=3, uint8=True, no_realloc=False)
    
    # Invalid allocation (invalid channel count)
    with pytest.raises(ValueError, match="Number of channels must be between 1 and 4"):
        tex.allocate(width=100, height=100, num_chans=5, uint8=True, no_realloc=False)

def test_texture_multithread_updates(capture_context):
    """Test updating a texture from multiple threads while rendering."""
    ctx = capture_context
    
    # Create initial texture - checkerboard pattern
    width, height = 200, 200
    data = np.zeros((height, width, 4), dtype=np.uint8)
    data[:, :, 3] = 255  # Full alpha
    
    # Create initial checkerboard pattern
    for y in range(height):
        for x in range(width):
            if (x // 20 + y // 20) % 2 == 0:
                data[y, x, :3] = 200  # Light gray
            else:
                data[y, x, :3] = 50   # Dark gray
    
    tex = dcg.Texture(ctx, data)
    
    # Flags for thread control
    stop_event = threading.Event()
    threads_ready = threading.Barrier(4)  # 3 update threads + main thread
    
    # Function to update a region of the texture
    def update_region(region_id):
        # Wait for all threads to be ready
        threads_ready.wait()
        
        # Update the texture multiple times
        update_count = 0
        while not stop_event.is_set() and update_count < 5:
            # Update just this region of the texture
            tex.set_value(data if region_id > 0 else data[1:, 1:]) # simulate size change
            
            update_count += 1
            time.sleep(0.05)  # Small delay between updates
    
    # Start update threads
    threads = []
    for i in range(3):
        thread = threading.Thread(target=update_region, args=(i,))
        thread.daemon = True
        thread.start()
        threads.append(thread)
    
    # Wait for all threads to be ready
    threads_ready.wait()
    
    # Render several frames while the texture is being updated
    frame_count = 0
    while frame_count < 20:
        with dcg.ViewportDrawList(ctx, front=True) as dl:
            dcg.DrawImage(ctx, texture=tex, pmin=(50, 50), pmax=(250, 250))
        
        ctx.viewport.render_frame()
        frame_count += 1
        time.sleep(0.05)
    
    # Signal threads to stop and wait for them to finish
    stop_event.set()
    for thread in threads:
        thread.join(timeout=1.0)
    
    # Render one final frame with the final texture
    with dcg.ViewportDrawList(ctx, front=True) as dl:
        dcg.DrawImage(ctx, texture=tex, pmin=(50, 50), pmax=(250, 250))
    ctx.viewport.render_frame()
    

def test_texture_id_property(ctx):
    """Test the texture_id property."""
    # Create texture
    tex = dcg.Texture(ctx, np.zeros((10, 10), dtype=np.uint8))
    
    # Check texture_id is not zero (valid texture ID)
    assert tex.texture_id > 0

def test_visual_verification_grayscale(capture_context):
    """Test that grayscale textures are rendered correctly."""
    ctx = capture_context
    
    # Create a grayscale gradient
    data = np.zeros((100, 100), dtype=np.uint8)
    for i in range(100):
        data[:, i] = int(i * 2.55)  # 0 to 255 gradient
    
    # Create texture
    tex = dcg.Texture(ctx, data)
    
    # Display the texture
    with dcg.ViewportDrawList(ctx, front=True) as dl:
        dcg.DrawImage(ctx, texture=tex, pmin=(50, 50), pmax=(150, 150))
    
    # Render a frame
    while not ctx.viewport.render_frame():
        continue
    
    # Get the framebuffer
    framebuffer = ctx.viewport.framebuffer
    assert framebuffer is not None
    
    # Read back the framebuffer
    fb_data = np.asarray(framebuffer.read())[::-1, :, :]  # Flip vertically for correct orientation
    
    # Check the rendered pixels (grayscale should be rendered as equal RGB)
    # Sample a few points along the gradient
    x_positions = [75, 100, 125]
    for i, x in enumerate(x_positions):
        y = 75
        # Check that R, G, B values are approximately equal (grayscale)
        assert abs(int(fb_data[y, x, 0]) - int(fb_data[y, x, 1])) <= 10
        assert abs(int(fb_data[y, x, 1]) - int(fb_data[y, x, 2])) <= 10
        
        # Check gradient is increasing from left to right
        if i > 0:
            prev_x = x_positions[i-1]
            assert int(fb_data[y, x, 0]) > int(fb_data[y, prev_x, 0])
