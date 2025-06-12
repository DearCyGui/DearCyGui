import gc
import sys
import weakref
import pytest
import dearcygui as dcg

def test_basic_gc():
    """Test that basic items are garbage collected when no longer referenced"""
    C = dcg.Context()
    button = dcg.Button(C, label="Test")
    button_ref = weakref.ref(button)
    del button
    gc.collect()
    assert button_ref() is None

def test_nested_gc():
    """Test that nested items are garbage collected properly"""
    C = dcg.Context()

    with dcg.Window(C, attach=False) as window:
        button1 = dcg.Button(C, label="Test1")
        button2 = dcg.Button(C, label="Test2")
    
    window_ref = weakref.ref(window)
    button1_ref = weakref.ref(button1)
    button2_ref = weakref.ref(button2)

    assert window.parent is None
    
    del window
    del button1
    del button2
    gc.collect()
    
    assert window_ref() is None
    assert button1_ref() is None
    assert button2_ref() is None

def test_circular_references():
    """Test that circular references are properly collected"""
    C = dcg.Context()
    
    class CircularTest:
        def __init__(self):
            self.window = dcg.Window(C, attach=False)
            self.button = dcg.Button(C, parent=self.window)
            self.button.user_data = self  # Create circular reference
    
    circular = CircularTest()
    window_ref = weakref.ref(circular.window)
    button_ref = weakref.ref(circular.button)
    
    del circular
    gc.collect()
    
    assert window_ref() is None
    assert button_ref() is None

def test_callback_gc():
    """Test that items with callbacks are properly collected"""
    C = dcg.Context()
    
    def callback(sender, target, data):
        pass
    
    button = dcg.Button(C, callbacks=callback)
    button_ref = weakref.ref(button)
    
    del button
    gc.collect()
    
    assert button_ref() is None

def test_handler_gc():
    """Test that items with handlers are properly collected"""
    C = dcg.Context()
    
    button = dcg.Button(C)
    handler = dcg.ClickedHandler(C, callback=lambda: None)
    button.handlers += [handler]
    
    button_ref = weakref.ref(button)
    handler_ref = weakref.ref(handler)
    
    del button
    del handler
    gc.collect()
    
    assert button_ref() is None
    assert handler_ref() is None

def test_plot_gc():
    """Test that plots and their components are properly collected"""
    C = dcg.Context()
    
    with dcg.Plot(C) as plot:
        line = dcg.PlotLine(C, X=[0,1], Y=[0,1])
        scatter = dcg.PlotScatter(C, X=[0,1], Y=[0,1])
    
    plot_ref = weakref.ref(plot)
    line_ref = weakref.ref(line)
    scatter_ref = weakref.ref(scatter)
    
    del plot
    del line
    del scatter
    gc.collect()
    
    assert plot_ref() is None
    assert line_ref() is None
    assert scatter_ref() is None

def test_table_gc():
    """Test that tables and their contents are properly collected"""
    C = dcg.Context()
    
    table = dcg.Table(C)
    for i in range(3):
        for j in range(3):
            table[i,j] = dcg.Text(C, value=f"{i},{j}")
    
    table_ref = weakref.ref(table)
    cell_refs = [[weakref.ref(table[i,j].content) for j in range(3)] for i in range(3)]
    
    del table
    gc.collect()
    
    assert table_ref() is None
    for row in cell_refs:
        for cell_ref in row:
            assert cell_ref() is None

def test_theme_gc():
    """Test that themes are properly collected"""
    C = dcg.Context()
    
    with dcg.ThemeList(C) as theme:
        color_theme = dcg.ThemeColorImGui(C, button=(255,0,0))
        style_theme = dcg.ThemeStyleImGui(C, frame_padding=(2,2))
    
    button = dcg.Button(C, theme=theme)
    
    theme_ref = weakref.ref(theme)
    color_theme_ref = weakref.ref(color_theme)
    style_theme_ref = weakref.ref(style_theme)
    button_ref = weakref.ref(button)
    
    del theme
    del color_theme
    del style_theme
    del button
    gc.collect()
    
    assert theme_ref() is None
    assert color_theme_ref() is None
    assert style_theme_ref() is None
    assert button_ref() is None

def test_switch_parents():
    """Test that items with switch parents are properly collected"""
    C = dcg.Context()
    
    window1 = dcg.Window(C, attach=False)
    window2 = dcg.Window(C, attach=False)
    button = dcg.Button(C, parent=window1)
    button.parent = window2  # Change parent
    
    window1_ref = weakref.ref(window1)
    window2_ref = weakref.ref(window2)
    button_ref = weakref.ref(button)
    
    del window2
    del button
    gc.collect()
    
    assert window2_ref() is None
    assert button_ref() is None

    del window1
    gc.collect()

    assert window1_ref() is None

def test_shared_resources():
    """Test that shared resources (like textures) are properly collected"""
    C = dcg.Context()
    
    import numpy as np
    texture_data = np.zeros((100, 100, 3), dtype=np.uint8)
    texture = dcg.Texture(C, texture_data)
    
    image1 = dcg.Image(C, texture=texture)
    image2 = dcg.Image(C, texture=texture)
    
    texture_ref = weakref.ref(texture)
    image1_ref = weakref.ref(image1)
    image2_ref = weakref.ref(image2)
    
    del image1
    del image2
    del texture
    gc.collect()
    
    assert texture_ref() is None
    assert image1_ref() is None
    assert image2_ref() is None

def test_dynamic_item_creation():
    """Test garbage collection with dynamically created and destroyed items"""
    C = dcg.Context()
    
    items = []
    refs = []
    
    # Create items
    for i in range(100):
        item = dcg.Button(C, label=f"Button {i}")
        items.append(item)
        refs.append(weakref.ref(item))
    
    # Delete every other item
    for i in range(0, len(items), 2):
        items[i] = None
    
    gc.collect()
    
    # Check that deleted items were collected
    for i in range(len(refs)):
        if i % 2 == 0:
            assert refs[i]() is None
        else:
            assert refs[i]() is not None

def test_tree_cleanup():
    """Test that everything is properly collected when a far parent is destroyed"""
    C = dcg.Context()
    
    # Create a complex hierarchy
    with dcg.Window(C, attach=False) as window:
        with dcg.MenuBar(C):
            with dcg.Menu(C):
                dcg.MenuItem(C)
        
        with dcg.TabBar(C):
            with dcg.Tab(C):
                dcg.Button(C)
        
        table = dcg.Table(C)
        for i in range(3):
            for j in range(3):
                table[i,j] = dcg.Text(C)

    window_ref = weakref.ref(window)
    
    del window
    del table
    gc.collect()
    
    # Verify everything was collected
    assert window_ref() is None

def test_memory_usage():
    """Test that memory usage doesn't grow with item creation/destruction"""
    import psutil
    import os
    
    process = psutil.Process(os.getpid())
    C = dcg.Context()
    gc.collect()
    
    # Create and destroy many items in a loop
    for _ in range(1000):
        window = dcg.Window(C, attach=False)
        for _ in range(1000):
            dcg.Button(C, parent=window)
        del window

    gc.collect()
    # We measuse after allocating and deallocating in
    # order to avoid impact of allocation caching
    initial_memory = process.memory_info().rss

    # Create and destroy many items in a loop
    for _ in range(1000):
        window = dcg.Window(C, attach=False)
        for _ in range(1000):
            dcg.Button(C, parent=window)
        del window
    gc.collect()
    
    final_memory = process.memory_info().rss
    memory_diff = final_memory - initial_memory
    
    # Allow for some memory overhead, but it shouldn't be significant
    assert memory_diff < 1024 * 1024  # Less than 1MB difference

if __name__ == "__main__":
    pytest.main([__file__])
