import pytest
import dearcygui as dcg

@pytest.fixture
def ctx():
    # Create a minimal context for testing.
    C = dcg.Context()
    #C.viewport.initialize(visible=False)
    return C

def test_draw_invisible_button_properties(ctx):
    # Instantiate a DrawInvisibleButton and verify get/set properties.
    btn = dcg.DrawInvisibleButton(ctx)
    
    # Test setting and getting the button property.
    btn.button = dcg.MouseButtonMask.MIDDLE
    assert btn.button is dcg.MouseButtonMask.MIDDLE
    
    # Set and test coordinate properties.
    btn.p1 = (0, 0)
    assert btn.p1 == (0, 0)
    
    btn.p2 = (1, 1)
    assert btn.p2 == (1, 1)
    
    # Test min_side and max_side
    btn.min_side = 10
    assert btn.min_side == 10
    
    btn.max_side = 20
    assert btn.max_side == 20

def test_button_callback(ctx):
    triggered = {"value": False}
    
    def on_click(sender):
        triggered["value"] = True
    
    # Create a Button with a callback.
    btn = dcg.Button(ctx, label="Click Me", callbacks=on_click)
    
    btn.callbacks[0](btn, btn, True)
    
    assert triggered["value"] is True

def test_ui_item_inheritance(ctx):
    # Create a window and add a checkbox to it.
    win = dcg.Window(ctx, label="Test Window")
    checkbox = dcg.Checkbox(ctx, label="Check Me")
    
    checkbox.parent = win

    # Verify the widget shares the context from the Window.
    assert checkbox.context == ctx
    assert win.context == ctx

def test_shared_values(ctx):
    # Test a shared value between a Slider and its backing SharedFloat.
    shared_float = dcg.SharedFloat(ctx, 10)
    slider = dcg.Slider(ctx, shareable_value=shared_float)
    
    # Change slider's value and check the shared value is updated.
    slider.value = 20
    assert shared_float.value == 20

def test_text_widget(ctx):
    # Test basic creation and value assignment for a Text widget.
    txt = dcg.Text(ctx, value="Hello")
    assert txt.value == "Hello"
    
    # Update the text and check the new value.
    txt.value = "World"
    assert txt.value == "World"

def test_input_text_widget(ctx):
    # Test basic creation and value assignment for an InputText widget.
    input_txt = dcg.InputText(ctx, value="Initial Text")
    assert input_txt.value == "Initial Text"
    
    # Update the text and check the new value.
    input_txt.value = "New Text"
    assert input_txt.value == "New Text"

def test_checkbox_widget(ctx):
    # Test basic creation and value assignment for a Checkbox widget.
    checkbox = dcg.Checkbox(ctx, label="Check Me")
    assert checkbox.value is False
    
    # Update the checkbox and check the new value.
    checkbox.value = True
    assert checkbox.value is True

def test_slider_widget(ctx):
    # Test basic creation and value assignment for a Slider widget.
    slider = dcg.Slider(ctx, min_value=0.0, max_value=100.0, print_format="%.2f")
    assert slider.value == 0.0
    
    # Update the slider and check the new value.
    slider.value = 50.0
    assert slider.value == 50.0

def test_combo_widget(ctx):
    # Test basic creation and value assignment for a Combo widget.
    combo = dcg.Combo(ctx, items=["Item1", "Item2", "Item3"])
    assert combo.value == ""  # Default value is empty
    
    # Update the combo and check the new value.
    combo.value = "Item2"
    assert combo.value == "Item2"

def test_listbox_widget(ctx):
    # Test basic creation and value assignment for a ListBox widget.
    listbox = dcg.ListBox(ctx, items=["ItemA", "ItemB", "ItemC"])
    assert listbox.value == ""  # Default value is empty
    
    # Update the listbox and check the new value.
    listbox.value = "ItemB"
    assert listbox.value == "ItemB"

def test_radiobutton_widget(ctx):
    # Test basic creation and value assignment for a RadioButton widget.
    radiobutton1 = dcg.RadioButton(ctx, items=["ItemA", "ItemB", "ItemC"])
    radiobutton2 = dcg.RadioButton(ctx, items=["ItemA", "ItemB", "ItemC"])
    
    assert radiobutton1.value == ""  # Default value is empty
    assert radiobutton2.value == ""  # Default value is empty
    
    # Select radiobutton1 and check the value.
    radiobutton1.value = "ItemB"
    assert radiobutton1.value == "ItemB"
    assert radiobutton2.value == ""  # Value should not change

def test_menu_widget(ctx):
    # Test basic creation of a Menu widget.
    menu_bar = dcg.MenuBar(ctx)
    menu = dcg.Menu(ctx, label="File", parent=menu_bar)
    menu_item = dcg.MenuItem(ctx, label="Open", parent=menu)
    
    assert menu.label == "File"
    assert menu_item.label == "Open"

def test_image_widget(ctx):
    # Test basic creation of an Image widget.  Requires a texture to be loaded.
    # This is a placeholder, as loading textures requires more setup.
    # image = dcg.Image(ctx, texture_tag="test_texture")
    pass

def test_color_edit_widget(ctx):
    # Test basic creation and value assignment for a ColorEdit widget.
    color_edit = dcg.ColorEdit(ctx, value=(0.0, 0.0, 0.0, 1.0))
    assert dcg.color_as_int(color_edit.value) == dcg.color_as_int((0.0, 0.0, 0.0, 1.0))
    
    # Update the color and check the new value.
    color_edit.value = (1.0, 0.0, 0.0, 1.0)
    assert dcg.color_as_int(color_edit.value) == dcg.color_as_int((1.0, 0.0, 0.0, 1.0))

def test_progress_bar_widget(ctx):
    # Test basic creation and value assignment for a ProgressBar widget.
    progress_bar = dcg.ProgressBar(ctx, width=200)
    assert progress_bar.value == 0.0
    
    # Update the progress and check the new value.
    progress_bar.value = 0.5
    assert progress_bar.value == 0.5

def test_tooltip_widget(ctx):
    # Test basic creation of a Tooltip widget.
    button = dcg.Button(ctx, label="Hover Me")
    with dcg.Tooltip(ctx, target=button):
        dcg.Text(ctx, value="This is a tooltip")

def test_tabbar_tab_widgets(ctx):
    # Test basic creation of TabBar and Tab widgets.
    tab_bar = dcg.TabBar(ctx)
    tab1 = dcg.Tab(ctx, label="Tab 1", parent=tab_bar)
    tab2 = dcg.Tab(ctx, label="Tab 2", parent=tab_bar)
    
    assert tab1.label == "Tab 1"
    assert tab2.label == "Tab 2"

def test_tree_node_widget(ctx):
    # Test basic creation of a TreeNode widget.
    tree_node = dcg.TreeNode(ctx, label="My Node")
    assert tree_node.label == "My Node"

def test_collapsing_header_widget(ctx):
    # Test basic creation of a CollapsingHeader widget.
    collapsing_header = dcg.CollapsingHeader(ctx, label="My Header")
    assert collapsing_header.label == "My Header"

def test_child_window_widget(ctx):
    # Test basic creation of a ChildWindow widget.
    child_window = dcg.ChildWindow(ctx, width=100, height=100)
    assert int(child_window.width) == 100
    assert int(child_window.height) == 100

def test_selectable_widget(ctx):
    # Test basic creation and value assignment for a Selectable widget.
    selectable = dcg.Selectable(ctx, label="Selectable Item")
    assert selectable.value is False
    
    # "Select" the item and check the new value.
    selectable.value = True
    assert selectable.value is True

def test_shared_string(ctx):
    shared_str = dcg.SharedStr(ctx, "Initial Value")
    assert shared_str.value == "Initial Value"

    shared_str.value = "New Value"
    assert shared_str.value == "New Value"

def test_shared_float_vect(ctx):
    shared_float_vect = dcg.SharedFloatVect(ctx, (1.0, 2.0, 3.0))
    assert tuple(shared_float_vect.value) == (1.0, 2.0, 3.0)

    shared_float_vect.value = [4.0, 5.0, 6.0]
    assert tuple(shared_float_vect.value) == (4.0, 5.0, 6.0)

def test_button_basic():
    """Test basic Button functionality"""
    ctx = dcg.Context()
    btn = dcg.Button(ctx, label="Test Button")
    assert btn.label == "Test Button"
    assert not btn.repeat
    btn.repeat = True
    assert btn.repeat

def test_button_shared_value():
    """Test Button's shared value functionality"""
    ctx = dcg.Context()
    shared = dcg.SharedBool(ctx, False)
    btn = dcg.Button(ctx, label="Test Button", shareable_value=shared)
    assert not btn.value
    btn.value = True
    assert btn.value
    assert shared.value

def test_slider_basic():
    """Test basic Slider functionality"""
    ctx = dcg.Context()
    slider = dcg.Slider(ctx, label="Test Slider")
    slider.min_value = 0
    slider.max_value = 100
    assert slider.min_value == 0
    assert slider.max_value == 100

def test_text_basic():
    """Test basic Text functionality"""
    ctx = dcg.Context()
    text = dcg.Text(ctx, value="Test Text")
    assert text.value == "Test Text"
    assert text.marker is None
    text.marker = "bullet"
    assert text.marker is dcg.TextMarker.BULLET

def test_checkbox_basic():
    """Test basic Checkbox functionality"""
    ctx = dcg.Context()
    checkbox = dcg.Checkbox(ctx, label="Test Checkbox")
    assert checkbox.label == "Test Checkbox"
    assert not checkbox.value
    checkbox.value = True
    assert checkbox.value

def test_combo_basic():
    """Test basic Combo functionality"""
    ctx = dcg.Context()
    combo = dcg.Combo(ctx, label="Test Combo")
    items = ["One", "Two", "Three"]
    combo.items = items
    assert combo.items == items
    assert not combo.popup_align_left
    combo.popup_align_left = True
    assert combo.popup_align_left

def test_input_text_basic():
    """Test basic InputText functionality"""
    ctx = dcg.Context()
    input_text = dcg.InputText(ctx, label="Test Input")
    assert input_text.label == "Test Input"
    assert not input_text.password
    input_text.password = True
    assert input_text.password
    assert input_text.max_characters == 1024

def test_child_window_basic():
    """Test basic ChildWindow functionality"""
    ctx = dcg.Context()
    child = dcg.ChildWindow(ctx, label="Test Child")
    assert child.label == "Test Child"
    assert child.border
    child.border = False
    assert not child.border
    assert not child.menubar
    child.menubar = True
    assert child.menubar

def test_tab_bar_basic():
    """Test basic TabBar functionality"""
    ctx = dcg.Context()
    tab_bar = dcg.TabBar(ctx, label="Test TabBar")
    assert tab_bar.label == "Test TabBar"
    assert not tab_bar.reorderable
    tab_bar.reorderable = True
    assert tab_bar.reorderable

def test_shared_values():
    """Test various shared value types"""
    ctx = dcg.Context()
    
    bool_val = dcg.SharedBool(ctx, True)
    assert bool_val.value == True
    
    float_val = dcg.SharedFloat(ctx, 1.5)
    assert float_val.value == 1.5
    
    str_val = dcg.SharedStr(ctx, "test")
    assert str_val.value == "test"
    
    color_val = dcg.SharedColor(ctx, 0xFF0000FF)  # Red
    assert isinstance(color_val.value, int)

def test_tooltip_basic():
    """Test basic Tooltip functionality"""
    ctx = dcg.Context()
    tooltip = dcg.Tooltip(ctx, label="Test Tooltip")
    assert tooltip.delay == 0.0
    tooltip.delay = 1.0
    assert tooltip.delay == 1.0
    assert not tooltip.hide_on_activity
    tooltip.hide_on_activity = True
    assert tooltip.hide_on_activity

def test_tree_node_basic():
    """Test basic TreeNode functionality"""
    ctx = dcg.Context()
    tree = dcg.TreeNode(ctx, label="Test Tree")
    assert tree.label == "Test Tree"
    assert not tree.leaf
    tree.leaf = True
    assert tree.leaf
    assert not tree.bullet
    tree.bullet = True
    assert tree.bullet

def test_color_edit_basic():
    """Test basic ColorEdit functionality"""
    ctx = dcg.Context()
    color_edit = dcg.ColorEdit(ctx, label="Test Color")
    assert color_edit.label == "Test Color"
    assert not color_edit.no_alpha
    color_edit.no_alpha = True
    assert color_edit.no_alpha
    assert color_edit.display_mode == "rgb"
    color_edit.display_mode = "hsv"
    assert color_edit.display_mode == "hsv"

