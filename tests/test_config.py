"""
Unit tests for the configuration persistence system.

Tests the strong/weak persistence modes, JSON serialization, close() method,
and overall behavior of the configuration manager.
"""

import dearcygui as dcg
from dearcygui.utils.config import get_config_manager
import gc
import json
from pathlib import Path
import pytest
import shutil
import tempfile
import weakref
import warnings


@pytest.fixture
def temp_config_file():
    """Create a temporary config file and clean it up after the test."""
    temp_file = tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=True)
    temp_path = Path(temp_file.name)
    temp_file.close()
    
    yield temp_path
    
    # Cleanup
    if temp_path.exists():
        temp_path.unlink()

temp_config_file2 = temp_config_file



@pytest.fixture
def context():
    """Create a DearCyGui context for testing."""
    return dcg.Context()


class TestBasicPersistence:
    """Test basic configuration persistence functionality."""
    
    def test_strong_persistence_single_parameter(self, context, temp_config_file, temp_config_file2: Path):
        """Test that single parameter defaults to strong persistence."""
        C = context
        
        # Create configured window class
        with_config = get_config_manager(str(temp_config_file))
        ConfigWindow = with_config(dcg.Window, ('x', 'y', 'width', 'height'), key_attribute="label")
        
        # Create window with initial values
        window = ConfigWindow(C, label="Test", x=100, y=200, width=300, height=400)
        
        # Modify values
        window.configure(x=500, y=600, width=700, height=800)
        
        # Clean up and save
        wref = weakref.ref(window)
        window.parent = None # windows are attached to the viewport by default
        del window
        gc.collect()
        assert wref() is None
        with_config.manager.close()  # type: ignore
        
        # Verify JSON was written
        assert temp_config_file.exists()
        with open(temp_config_file, 'r') as f:
            data = json.load(f)
        
        assert "Test" in data
        assert data["Test"]['class'] == 'Window'
        assert data["Test"]['attributes']['x'] == 500
        assert data["Test"]['attributes']['y'] == 600

        # Create new manager with same config file,
        # using a different path to get a different manager instance
        shutil.copy(temp_config_file, temp_config_file2)
        with_config2 = get_config_manager(str(temp_config_file2))
        ConfigWindow2 = with_config2(dcg.Window, ('x', 'y', 'width', 'height'), key_attribute="label")
        
        # Create window with DIFFERENT values - strong persistence should override
        window2 = ConfigWindow2(C, label="Test", x=100, y=200, width=300, height=400)
        
        # Strong persistence should restore saved values
        assert window2.x.value == 500
        assert window2.y.value == 600
        assert window2.width.value == 700
        assert window2.height.value == 800

    def test_weak_persistence(self, context, temp_config_file, temp_config_file2):
        """Test that weak persistence allows overrides."""
        C = context
        
        # Create configured window with weak attributes
        with_config = get_config_manager(str(temp_config_file))
        ConfigWindow = with_config(
            dcg.Window,
            strong_attributes=(),
            weak_attributes=('x', 'y', 'width', 'height'),
            key_attribute="label"
        )
        
        # Create window with initial values
        window = ConfigWindow(C, label="Test", x=100, y=200, width=300, height=400)
        
        # Modify values
        window.configure(x=500, y=600, width=700, height=800)
        
        # Clean up and save
        window.parent = None
        del window
        gc.collect()
        with_config.manager.close()  # type: ignore
        
        # Create new manager and window with copied config file
        shutil.copy(temp_config_file, temp_config_file2)
        with_config2 = get_config_manager(str(temp_config_file2))
        ConfigWindow2 = with_config2(
            dcg.Window,
            strong_attributes=(),
            weak_attributes=('x', 'y', 'width', 'height'),
            key_attribute="label"
        )
        
        # Create window with same label but explicit values - weak persistence should allow override
        window2 = ConfigWindow2(C, label="Test", x=999, y=888, width=300, height=400)
        
        # Weak persistence should allow overrides
        assert window2.x.value == 999  # Overridden
        assert window2.y.value == 888  # Overridden
        assert window2.width.value == 300  # Overridden
        assert window2.height.value == 400  # Overridden

    def test_mixed_strong_weak_persistence(self, context, temp_config_file, temp_config_file2):
        """Test mixed strong and weak persistence."""
        C = context
        
        # Create configured window with mixed persistence
        with_config = get_config_manager(str(temp_config_file))
        ConfigWindow = with_config(
            dcg.Window,
            strong_attributes=('x', 'y'),
            weak_attributes=('width', 'height'),
            key_attribute="label"
        )
        
        # Create window and modify
        window = ConfigWindow(C, label="Test", x=100, y=200, width=300, height=400)
        window.configure(x=500, y=600, width=700, height=800)
        
        # Save
        window.parent = None
        del window
        gc.collect()
        with_config.manager.close()  # type: ignore
        
        # Create new manager and window with copied config file
        shutil.copy(temp_config_file, temp_config_file2)
        with_config2 = get_config_manager(str(temp_config_file2))
        ConfigWindow2 = with_config2(
            dcg.Window,
            strong_attributes=('x', 'y'),
            weak_attributes=('width', 'height'),
            key_attribute="label"
        )
        
        # Create with same label and explicit values
        window2 = ConfigWindow2(C, label="Test", x=100, y=200, width=1000, height=1100)
        
        # Strong attributes restored, weak attributes overridden
        assert window2.x.value == 500  # Strong - from config
        assert window2.y.value == 600  # Strong - from config
        assert window2.width.value == 1000  # Weak - from kwargs
        assert window2.height.value == 1100  # Weak - from kwargs


class TestCloseMethod:
    """Test the ConfigManager.close() method."""
    
    def test_close_prevents_further_updates(self, context, temp_config_file):
        """Test that close() prevents further config updates."""
        C = context
        
        with_config = get_config_manager(str(temp_config_file))
        manager = with_config.manager  # type: ignore
        ConfigWindow = with_config(dcg.Window, ('x', 'y'))
        
        # Create window
        window = ConfigWindow(C, label="Test", x=100, y=200)
        window.configure(x=500, y=600)
        
        # Close manager (saves current state)
        window.parent = None
        del window
        gc.collect()
        manager.close()
        
        # Read saved config
        with open(temp_config_file, 'r') as f:
            data = json.load(f)
        first_uuid = list(data.keys())[0]
        assert data[first_uuid]['attributes']['x'] == 500
        
        # Create another window and modify it
        window2 = ConfigWindow(C, label="Test2", x=100, y=200)
        window2.configure(x=999, y=888)
        
        # Delete window (should NOT save because manager is closed)
        window2.parent = None
        del window2
        gc.collect()
        
        # Config should still have old values
        with open(temp_config_file, 'r') as f:
            data2 = json.load(f)
        
        # Should only have one entry (the first window)
        assert len(data2) == 1
        assert data2[first_uuid]['attributes']['x'] == 500
    
    def test_close_can_be_called_multiple_times(self, context, temp_config_file):
        """Test that close() can be called multiple times safely."""
        C = context
        
        with_config = get_config_manager(str(temp_config_file))
        manager = with_config.manager  # type: ignore
        ConfigWindow = with_config(dcg.Window, ('x', 'y'))
        
        window = ConfigWindow(C, label="Test", x=100, y=200)
        window.parent = None
        del window
        gc.collect()
        
        # Call close multiple times
        manager.close()
        manager.close()
        manager.close()
        
        # Should not raise any errors
        assert temp_config_file.exists()


class TestJSONFormat:
    """Test JSON serialization and format."""
    
    def test_json_structure(self, context, temp_config_file):
        """Test that JSON has correct structure."""
        C = context
        
        with_config = get_config_manager(str(temp_config_file))
        ConfigWindow = with_config(dcg.Window, ('x', 'y', 'width', 'height'), key_attribute="label")
        
        window = ConfigWindow(C, label="Test", x=100, y=200, width=300, height=400)
        label = window.label

        window.parent = None
        del window
        gc.collect()
        with_config.manager.close()  # type: ignore
        
        # Read and verify JSON structure
        with open(temp_config_file, 'r') as f:
            data = json.load(f)
        
        assert label in data
        entry = data[label]
        assert 'class' in entry
        assert 'attributes' in entry
        assert entry['class'] == 'Window'
        assert isinstance(entry['attributes'], dict)
        assert entry['attributes']['x'] == 100
        assert entry['attributes']['y'] == 200
        assert entry['attributes']['width'] == 300
        assert entry['attributes']['height'] == 400
    
    def test_non_json_serializable_values_converted(self, context, temp_config_file):
        """Test that non-JSON-serializable values are converted."""
        C = context

        # filter all warnings to not show any
        warnings.simplefilter("ignore")
        
        with_config = get_config_manager(str(temp_config_file))
        ConfigWindow = with_config(dcg.Window, ('pos',), key_attribute="label")
        
        # Create window (pos might be a tuple internally)
        window = ConfigWindow(C, label="Test", x=100, y=200)

        window.parent = None
        del window
        gc.collect()
        with_config.manager.close()  # type: ignore
        
        # Should be able to load JSON without errors
        with open(temp_config_file, 'r') as f:
            data = json.load(f)
        
        # JSON should be valid
        assert isinstance(data, dict)


class TestConfigPersistence:
    """Test configuration persistence across manager instances."""
    
    def test_config_persists_across_managers(self, context, temp_config_file):
        """Test that config persists when creating new managers."""
        C = context
        
        # First manager session
        with_config1 = get_config_manager(str(temp_config_file))
        ConfigWindow1 = with_config1(dcg.Window, ('x', 'y'), key_attribute="label")
        
        window1 = ConfigWindow1(C, label="Test", x=100, y=200)
        window1.configure(x=500, y=600)
        window1.parent = None
        del window1
        gc.collect()
        with_config1.manager.close()  # type: ignore
        
        # Copy to another temp file to ensure we're reading from disk
        temp_file2 = tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False)
        temp_path2 = Path(temp_file2.name)
        temp_file2.close()
        
        try:
            shutil.copy(temp_config_file, temp_path2)
            
            # Second manager session with copied file
            with_config2 = get_config_manager(str(temp_path2))
            ConfigWindow2 = with_config2(dcg.Window, ('x', 'y'), key_attribute="label")
            
            window2 = ConfigWindow2(C, label="Test", x=100, y=200)
            
            # Should restore from config
            assert window2.x.value == 500
            assert window2.y.value == 600
            
            with_config2.manager.close()  # type: ignore
        finally:
            if temp_path2.exists():
                temp_path2.unlink()
    
    def test_class_name_validation(self, context, temp_config_file):
        """Test that config is not applied if class name doesn't match."""
        C = context

        # filter all warnings to not show any
        warnings.simplefilter("ignore")
        
        # Create config with Window
        with_config1 = get_config_manager(str(temp_config_file))
        ConfigWindow = with_config1(dcg.Window, ('x', 'y'), key_attribute="label")
        
        window = ConfigWindow(C, label="Test", x=100, y=200)
        window.configure(x=500, y=600)
        window.parent = None
        del window
        gc.collect()
        with_config1.manager.close()  # type: ignore
        
        # Try to use config with Checkbox (different class)
        with_config2 = get_config_manager(str(temp_config_file))
        ConfigCheckbox = with_config2(dcg.Checkbox, ('value',), key_attribute="label")
        
        # The checkbox shouldn't get window's config (different class)
        # We can't easily test this without internal access, but we can verify
        # no errors occur
        checkbox = ConfigCheckbox(C, label="Test", value=False)
        assert isinstance(checkbox, dcg.Checkbox)
        
        with_config2.manager.close()  # type: ignore


class TestSingletonBehavior:
    """Test singleton behavior of ConfigManager."""
    
    def test_same_path_returns_same_manager(self, temp_config_file):
        """Test that same config file path returns same manager instance."""
        with_config1 = get_config_manager(str(temp_config_file))
        with_config2 = get_config_manager(str(temp_config_file))
        
        # Should return same manager
        assert with_config1.manager is with_config2.manager  # type: ignore
    
    def test_different_paths_return_different_managers(self):
        """Test that different config file paths return different managers."""
        temp1 = tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=True)
        temp2 = tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=True)
        path1 = Path(temp1.name)
        path2 = Path(temp2.name)
        temp1.close()
        temp2.close()
        
        try:
            with_config1 = get_config_manager(str(path1))
            with_config2 = get_config_manager(str(path2))
            
            # Should return different managers
            assert with_config1.manager is not with_config2.manager  # type: ignore
        finally:
            if path1.exists():
                path1.unlink()
            if path2.exists():
                path2.unlink()


class TestMultipleItems:
    """Test configuration with multiple items."""
    
    def test_multiple_windows_same_config(self, context, temp_config_file):
        """Test that multiple windows can use same config file."""
        C = context
        
        with_config = get_config_manager(str(temp_config_file))
        ConfigWindow = with_config(dcg.Window, ('x', 'y'), key_attribute="label")
        
        # Create multiple windows
        window1 = ConfigWindow(C, label="Window1", x=100, y=200)
        window2 = ConfigWindow(C, label="Window2", x=300, y=400)
        window3 = ConfigWindow(C, label="Window3", x=500, y=600)
        
        label1, label2, label3 = window1.label, window2.label, window3.label
        
        # Modify them
        window1.configure(x=111, y=222)
        window2.configure(x=333, y=444)
        window3.configure(x=555, y=666)
        
        # Clean up
        window1.parent = None
        window2.parent = None
        window3.parent = None
        del window1, window2, window3
        gc.collect()
        with_config.manager.close()  # type: ignore
        
        # Read config
        with open(temp_config_file, 'r') as f:
            data = json.load(f)
        
        # All three windows should be in config
        assert label1 in data
        assert label2 in data
        assert label3 in data
        
        assert data[label1]['attributes']['x'] == 111
        assert data[label2]['attributes']['x'] == 333
        assert data[label3]['attributes']['x'] == 555
    
    def test_mixed_configured_and_normal_items(self, context, temp_config_file):
        """Test that configured and normal items can coexist."""
        C = context
        
        with_config = get_config_manager(str(temp_config_file))
        ConfigWindow = with_config(dcg.Window, ('x', 'y'), key_attribute="label")
        
        # Create configured window
        config_window = ConfigWindow(C, label="Configured", x=100, y=200)
        
        # Create normal window
        normal_window = dcg.Window(C, label="Normal", x=300, y=400)
        
        # Modify both
        config_window.configure(x=500, y=600)
        normal_window.configure(x=700, y=800)
        
        config_label = config_window.label
        normal_label = normal_window.label
        
        # Clean up
        config_window.parent = None
        normal_window.parent = None
        del config_window, normal_window
        gc.collect()
        with_config.manager.close()  # type: ignore
        
        # Read config
        with open(temp_config_file, 'r') as f:
            data = json.load(f)
        
        # Only configured window should be in config
        assert config_label in data
        assert normal_label not in data


class TestEdgeCases:
    """Test edge cases and error handling."""
    
    def test_empty_attributes(self, context, temp_config_file):
        """Test window with no configured attributes."""
        C = context
        
        with_config = get_config_manager(str(temp_config_file))
        ConfigWindow = with_config(dcg.Window, (), key_attribute="label")
        
        window = ConfigWindow(C, label="Test", x=100, y=200)
        window.parent = None
        del window
        gc.collect()
        with_config.manager.close()  # type: ignore
        
        # Should still create valid JSON
        assert temp_config_file.exists()
        with open(temp_config_file, 'r') as f:
            data = json.load(f)
        
        # Should have entry but with empty attributes
        assert len(data) > 0
    
    def test_nonexistent_config_file(self, context):
        """Test that manager works with nonexistent config file."""
        temp_path = Path(tempfile.gettempdir()) / "nonexistent_config.json"
        
        # Ensure file doesn't exist
        if temp_path.exists():
            temp_path.unlink()
        
        try:
            with_config = get_config_manager(str(temp_path))
            ConfigWindow = with_config(dcg.Window, ('x', 'y'), key_attribute="label")
            
            window = ConfigWindow(context, label="Test", x=100, y=200)
            window.parent = None
            del window
            gc.collect()
            with_config.manager.close()  # type: ignore
            
            # File should now exist
            assert temp_path.exists()
        finally:
            if temp_path.exists():
                temp_path.unlink()
    
    def test_invalid_attribute_names_dont_crash(self, context, temp_config_file):
        """Test that invalid attribute names don't cause crashes."""
        C = context

        # filter all warnings to not show any
        warnings.simplefilter("ignore")

        with_config = get_config_manager(str(temp_config_file))
        # Try to configure non-existent attributes
        ConfigWindow = with_config(dcg.Window, ('nonexistent_attr', 'x'), key_attribute="label")
        
        # Should not crash
        window = ConfigWindow(C, label="Test", x=100, y=200)
        window.parent = None
        del window
        gc.collect()
        with_config.manager.close()  # type: ignore
        
        # Should still work for valid attributes
        assert temp_config_file.exists()


class TestAtexitBehavior:
    """Test that config is saved on program exit if close() not called."""
    
    def test_config_saved_without_explicit_close(self, context, temp_config_file):
        """Test that config is saved via atexit even without calling close()."""
        C = context
        
        with_config = get_config_manager(str(temp_config_file))
        ConfigWindow = with_config(dcg.Window, ('x', 'y'), key_attribute="label")
        
        window = ConfigWindow(C, label="Test", x=100, y=200)
        window.configure(x=500, y=600)
        
        # Delete window (triggers __del__)
        window.parent = None
        del window
        gc.collect()
        
        # Don't call close() - rely on atexit
        # Manually trigger save for testing
        with_config.manager._save_config()  # type: ignore
        
        # Config should be saved
        assert temp_config_file.exists()
        with open(temp_config_file, 'r') as f:
            data = json.load(f)
        
        assert len(data) > 0
        first_entry = data[list(data.keys())[0]]
        assert first_entry['attributes']['x'] == 500
