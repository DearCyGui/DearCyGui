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


# ---- Tests for state.rendered (state.visible) property ----

def test_item_rendered_starts_false(ctx):
    """Test that items start with rendered=False before being displayed"""
    # Test various UI item types
    button = dcg.Button(ctx, label="Test Button")
    assert not button.state.visible, "Button should start with rendered=False"
    
    text = dcg.Text(ctx, value="Test Text")
    assert not text.state.visible, "Text should start with rendered=False"
    
    checkbox = dcg.Checkbox(ctx, label="Test Checkbox")
    assert not checkbox.state.visible, "Checkbox should start with rendered=False"
    
    slider = dcg.Slider(ctx, label="Test Slider")
    assert not slider.state.visible, "Slider should start with rendered=False"


def test_draw_invisible_button_rendered_starts_false(ctx):
    """Test that DrawInvisibleButton starts with rendered=False (it's the only draw item with state)"""
    from dearcygui import DrawInvisibleButton
    
    draw_button = DrawInvisibleButton(ctx, p1=(0, 0), p2=(100, 100))
    assert not draw_button.state.visible, "DrawInvisibleButton should start with rendered=False"


def test_item_rendered_becomes_true_when_displayed(ctx):
    """Test that rendered becomes True when item is displayed"""
    viewport = ctx.viewport
    viewport.initialize(visible=False)
    
    # Create a window with items
    win = dcg.Window(ctx, label="Test Window")
    button = dcg.Button(ctx, label="Test Button", parent=win)
    text = dcg.Text(ctx, value="Test Text", parent=win)
    
    # Before rendering
    assert not button.state.visible
    assert not text.state.visible
    
    # Render a frame
    viewport.render_frame()
    
    # After rendering, items should be visible
    assert button.state.visible, "Button should be rendered after render_frame()"
    assert text.state.visible, "Text should be rendered after render_frame()"


def test_draw_invisible_button_rendered_lifecycle(ctx):
    """Test DrawInvisibleButton rendered property through its lifecycle"""
    from dearcygui import DrawInvisibleButton, ViewportDrawList
    
    viewport = ctx.viewport
    viewport.initialize(visible=False)
    
    # Create a viewport draw list and a draw button
    draw_list = ViewportDrawList(ctx)
    draw_button = DrawInvisibleButton(ctx, p1=(10, 10), p2=(100, 100), parent=draw_list)
    
    # Should start False
    assert not draw_button.state.visible, "DrawInvisibleButton should start with rendered=False"
    
    # Render a frame
    viewport.render_frame()
    
    # Should become True after rendering
    assert draw_button.state.visible, "DrawInvisibleButton should be rendered after render_frame()"
    
    # Detach the button
    draw_button.parent = None
    
    # Should immediately become False after detachment
    assert not draw_button.state.visible, "DrawInvisibleButton rendered should be False immediately after detachment"


def test_item_rendered_false_when_detached(ctx):
    """Test that rendered becomes False immediately when item is detached"""
    viewport = ctx.viewport
    viewport.initialize(visible=False)
    
    # Create and render items
    win = dcg.Window(ctx, label="Test Window", primary=True)
    button = dcg.Button(ctx, label="Test Button", parent=win)
    text = dcg.Text(ctx, value="Test Text", parent=win)
    slider = dcg.Slider(ctx, label="Test Slider", parent=win)
    
    viewport.render_frame()
    
    # Items should be visible
    assert button.state.visible
    assert text.state.visible
    assert slider.state.visible
    
    # Detach button
    button.parent = None
    
    # Should be False immediately without rendering another frame
    assert not button.state.visible, "Button rendered should be False immediately after detachment"
    
    # Other items should still be True
    assert text.state.visible
    assert slider.state.visible
    
    # Detach text
    text.parent = None
    assert not text.state.visible, "Text rendered should be False immediately after detachment"
    assert slider.state.visible


def test_item_rendered_false_when_parent_detached(ctx):
    """Test that rendered becomes False when parent item is detached"""
    viewport = ctx.viewport
    viewport.initialize(visible=False)
    
    # Create hierarchy: window -> tree node -> button
    win = dcg.Window(ctx, label="Parent Window")
    tree = dcg.TreeNode(ctx, label="Tree", parent=win, value=True)  # Start expanded so button is rendered
    button = dcg.Button(ctx, label="Test Button", parent=tree)
    
    viewport.render_frame()
    
    # All should be visible
    assert win.state.visible
    assert tree.state.visible
    assert button.state.visible
    
    # Detach the tree node
    tree.parent = None
    
    # Tree and its children should immediately be not rendered
    assert not tree.state.visible, "Tree should not be rendered after detachment"
    assert not button.state.visible, "Button should not be rendered when parent is detached"
    
    # Parent window should still be visible
    assert win.state.visible


def test_draw_invisible_button_rendered_false_when_parent_detached(ctx):
    """Test that DrawInvisibleButton rendered becomes False when parent is detached"""
    from dearcygui import DrawInvisibleButton, DrawInWindow
    
    viewport = ctx.viewport
    viewport.initialize(visible=False)
    
    # Create hierarchy: window -> DrawInWindow -> DrawInvisibleButton
    # (DrawingList and other pure draw items don't have state, only DrawInvisibleButton does)
    win = dcg.Window(ctx, label="Parent Window")
    draw_in_window = DrawInWindow(ctx, parent=win)
    draw_button = DrawInvisibleButton(ctx, p1=(10, 10), p2=(100, 100), parent=draw_in_window)
    
    viewport.render_frame()
    
    # UI items with state should be visible
    assert win.state.visible
    assert draw_in_window.state.visible
    assert draw_button.state.visible
    
    # Detach the DrawInWindow
    draw_in_window.parent = None
    
    # DrawInWindow and its children should immediately be not rendered
    assert not draw_in_window.state.visible, "DrawInWindow should not be rendered after detachment"
    assert not draw_button.state.visible, "DrawInvisibleButton should not be rendered when parent is detached"
    
    # Parent window should still be visible
    assert win.state.visible


def test_item_rendered_false_when_show_false(ctx):
    """Test that rendered respects the show property"""
    viewport = ctx.viewport
    viewport.initialize(visible=False)
    
    win = dcg.Window(ctx, label="Test Window")
    button = dcg.Button(ctx, label="Test Button", parent=win)
    
    viewport.render_frame()
    assert button.state.visible
    
    # Hide the button
    button.show = False
    viewport.render_frame()
    
    # Should not be rendered
    assert not button.state.visible, "Button should not be rendered when show=False"
    
    # Show it again
    button.show = True
    viewport.render_frame()
    
    # Should be rendered again
    assert button.state.visible, "Button should be rendered when show=True"


def test_multiple_items_rendered_after_detach(ctx):
    """Test rendered property with multiple items being detached"""
    viewport = ctx.viewport
    viewport.initialize(visible=False)
    
    win = dcg.Window(ctx, label="Test Window", primary=True)
    items = [
        dcg.Button(ctx, label=f"Button {i}", parent=win)
        for i in range(5)
    ]
    
    viewport.render_frame()
    
    # All should be visible
    for item in items:
        assert item.state.visible
    
    # Detach items 1 and 3
    items[1].parent = None
    items[3].parent = None
    
    # Check states
    assert items[0].state.visible, "Item 0 should still be rendered"
    assert not items[1].state.visible, "Item 1 should not be rendered after detachment"
    assert items[2].state.visible, "Item 2 should still be rendered"
    assert not items[3].state.visible, "Item 3 should not be rendered after detachment"
    assert items[4].state.visible, "Item 4 should still be rendered"


def test_rendered_with_nested_draw_items(ctx):
    """Test rendered with deeply nested UI items"""
    viewport = ctx.viewport
    viewport.initialize(visible=False)
    
    # Create deep hierarchy with UI items that have state
    win = dcg.Window(ctx, label="Test Window", primary=True)
    tree1 = dcg.TreeNode(ctx, label="Tree1", parent=win, value=True)
    header = dcg.CollapsingHeader(ctx, label="Header", parent=tree1, value=True)
    tree2 = dcg.TreeNode(ctx, label="Tree2", parent=header, value=True)
    button = dcg.Button(ctx, label="Test Button", parent=tree2)
    
    viewport.render_frame()
    
    # All should be visible
    assert win.state.visible
    assert tree1.state.visible
    assert header.state.visible
    assert tree2.state.visible
    assert button.state.visible
    
    # Detach middle item
    header.parent = None
    
    # Everything below header should not be rendered
    assert win.state.visible
    assert tree1.state.visible
    assert not header.state.visible, "Header should not be rendered after detachment"
    assert not tree2.state.visible, "Tree 2 should not be rendered when parent is detached"

def test_rendered_reattachment(ctx):
    """Test that rendered becomes True again when item is reattached"""
    viewport = ctx.viewport
    viewport.initialize(visible=False)
    
    win = dcg.Window(ctx, label="Test Window")
    button = dcg.Button(ctx, label="Test Button", parent=win)
    
    viewport.render_frame()
    assert button.state.visible
    
    # Detach
    button.parent = None
    assert not button.state.visible
    
    # Reattach
    button.parent = win
    viewport.render_frame()
    
    # Should be rendered again
    assert button.state.visible, "Button should be rendered after reattachment"


def test_treenode_collapse_hides_children(ctx):
    """Test that collapsing a TreeNode sets children's visible to False"""
    viewport = ctx.viewport
    viewport.initialize(visible=False)
    
    win = dcg.Window(ctx, label="Test Window", primary=True)
    tree = dcg.TreeNode(ctx, label="Tree", parent=win, value=True)  # Start expanded
    button1 = dcg.Button(ctx, label="Button 1", parent=tree)
    text = dcg.Text(ctx, value="Text", parent=tree)
    
    # Render multiple frames to ensure nested items are drawn
    for _ in range(3):
        viewport.render_frame()
    
    # All should be visible when tree is expanded
    assert win.state.visible
    assert tree.state.visible
    assert button1.state.visible, "Button1 should be visible when tree is expanded"
    assert text.state.visible, "Text should be visible when tree is expanded"
    
    # Collapse the tree
    tree.value = False
    # Try rendering multiple frames to see if visibility updates
    for _ in range(3):
        viewport.render_frame()
    
    # Tree should still be visible (it's just collapsed), but children should not be
    assert tree.state.visible, "Tree itself should still be visible when collapsed"
    # Note: This reveals a bug - children's visible state is not updated when parent is collapsed
    # The children are not actually drawn, but their visible flag remains True
    assert not button1.state.visible, "Button1 should not be visible when tree is collapsed"
    assert not text.state.visible, "Text should not be visible when tree is collapsed"
    
    # Expand again
    tree.value = True
    for _ in range(2):
        viewport.render_frame()
    
    # Children should be visible again
    assert button1.state.visible, "Button1 should be visible when tree is re-expanded"
    assert text.state.visible, "Text should be visible when tree is re-expanded"


def test_nested_treenode_collapse(ctx):
    """Test that collapsing parent TreeNode affects nested children"""
    viewport = ctx.viewport
    viewport.initialize(visible=False)
    
    win = dcg.Window(ctx, label="Test Window", primary=True)
    tree1 = dcg.TreeNode(ctx, label="Tree1", parent=win, value=True)
    button = dcg.Button(ctx, label="Button", parent=tree1)
    
    # Render multiple frames for nested items
    for _ in range(3):
        viewport.render_frame()
    
    # All should be visible
    assert tree1.state.visible
    assert button.state.visible
    
    # Collapse the tree
    tree1.value = False
    viewport.render_frame()
    
    # Tree visible but collapsed, children not visible
    assert tree1.state.visible, "Tree1 should be visible when collapsed"
    assert not button.state.visible, "Button should not be visible when parent is collapsed"
    
    # Expand again
    tree1.value = True
    for _ in range(2):
        viewport.render_frame()
    
    # Both should be visible
    assert tree1.state.visible
    assert button.state.visible, "Button should be visible when parent is expanded"


def test_collapsing_header_collapse_hides_children(ctx):
    """Test that collapsing a CollapsingHeader sets children's visible to False"""
    viewport = ctx.viewport
    viewport.initialize(visible=False)
    
    win = dcg.Window(ctx, label="Test Window", primary=True)
    header = dcg.CollapsingHeader(ctx, label="Header", parent=win, value=True)  # Start expanded
    button = dcg.Button(ctx, label="Button", parent=header)
    
    # Render multiple frames
    for _ in range(3):
        viewport.render_frame()
    
    # All should be visible when header is expanded
    assert header.state.visible
    assert button.state.visible
    
    # Collapse the header
    header.value = False
    viewport.render_frame()
    
    # Header visible but children not
    assert header.state.visible, "Header should be visible when collapsed"
    assert not button.state.visible, "Button should not be visible when header is collapsed"


def test_show_false_immediately_hides_item(ctx):
    """Test that setting show=False immediately sets visible to False"""
    viewport = ctx.viewport
    viewport.initialize(visible=False)
    
    win = dcg.Window(ctx, label="Test Window")
    button = dcg.Button(ctx, label="Button", parent=win)
    text = dcg.Text(ctx, value="Text", parent=win)
    
    viewport.render_frame()
    
    # Both should be visible
    assert button.state.visible
    assert text.state.visible
    
    # Set show=False without rendering
    button.show = False
    
    # Should be immediately False
    assert not button.state.visible, "Button visible should be False immediately after show=False"
    assert text.state.visible, "Text should still be visible"
    
    # Setting show back to True doesn't make it visible until rendering
    button.show = True
    # Still not visible until we render
    # (This behavior might vary, but we test the immediate effect of show=False)
    
    viewport.render_frame()
    assert button.state.visible, "Button should be visible after show=True and render"


def test_show_false_hides_children_immediately(ctx):
    """Test that setting show=False on parent immediately hides children"""
    viewport = ctx.viewport
    viewport.initialize(visible=False)
    
    win = dcg.Window(ctx, label="Test Window", primary=True)
    tree = dcg.TreeNode(ctx, label="Tree", parent=win, value=True)
    button1 = dcg.Button(ctx, label="Button 1", parent=tree)
    
    # Render multiple frames
    for _ in range(3):
        viewport.render_frame()
    
    # All should be visible
    assert tree.state.visible
    assert button1.state.visible
    
    # Set show=False on parent
    tree.show = False
    
    # Parent and children should immediately be not visible
    assert not tree.state.visible, "Tree should not be visible immediately after show=False"
    assert not button1.state.visible, "Button should not be visible when parent show=False"


def test_detach_hides_children_immediately(ctx):
    """Test that detaching a parent immediately hides all children"""
    viewport = ctx.viewport
    viewport.initialize(visible=False)
    
    win = dcg.Window(ctx, label="Test Window", primary=True)
    tree1 = dcg.TreeNode(ctx, label="Tree1", parent=win, value=True)
    tree2 = dcg.TreeNode(ctx, label="Tree2", parent=tree1, value=True)
    button = dcg.Button(ctx, label="Button", parent=tree2)
    
    # Render multiple frames for nested items
    for _ in range(3):
        viewport.render_frame()
    
    # All should be visible
    assert tree1.state.visible
    assert tree2.state.visible
    assert button.state.visible
    
    # Detach tree1
    tree1.parent = None
    
    # All should immediately be not visible
    assert not tree1.state.visible, "Tree1 should not be visible after detachment"
    assert not tree2.state.visible, "Tree2 should not be visible when parent detached"
    assert not button.state.visible, "Button should not be visible when ancestor detached"


def test_detach_deeply_nested_children(ctx):
    """Test that detaching affects deeply nested children immediately"""
    viewport = ctx.viewport
    viewport.initialize(visible=False)
    
    win = dcg.Window(ctx, label="Test Window", primary=True)
    tree1 = dcg.TreeNode(ctx, label="Tree1", parent=win, value=True)
    tree2 = dcg.TreeNode(ctx, label="Tree2", parent=tree1, value=True)
    button = dcg.Button(ctx, label="Button", parent=tree2)
    
    # Render multiple frames for nested items
    for _ in range(3):
        viewport.render_frame()
    
    # All should be visible
    assert tree1.state.visible
    assert tree2.state.visible
    assert button.state.visible
    
    # Detach middle tree
    tree2.parent = None
    
    # tree2 and all its descendants should be not visible
    assert tree1.state.visible, "Tree1 should still be visible"
    assert not tree2.state.visible, "Tree2 should not be visible after detachment"
    assert not button.state.visible, "Button should not be visible when parent detached"


def test_show_false_with_draw_invisible_button(ctx):
    """Test that show=False works correctly with DrawInvisibleButton"""
    from dearcygui import DrawInvisibleButton, ViewportDrawList
    
    viewport = ctx.viewport
    viewport.initialize(visible=False)
    
    draw_list = ViewportDrawList(ctx)
    draw_button = DrawInvisibleButton(ctx, p1=(10, 10), p2=(100, 100), parent=draw_list)
    
    viewport.render_frame()
    
    assert draw_button.state.visible
    
    # Set show=False
    draw_button.show = False
    
    # Should be immediately not visible
    assert not draw_button.state.visible, "DrawInvisibleButton should not be visible after show=False"
    
    # Render to confirm it stays False
    viewport.render_frame()
    assert not draw_button.state.visible
    
    # Set show=True and render
    draw_button.show = True
    viewport.render_frame()
    
    assert draw_button.state.visible, "DrawInvisibleButton should be visible after show=True"


def test_mixed_show_and_detach_effects(ctx):
    """Test combinations of show=False and detachment"""
    viewport = ctx.viewport
    viewport.initialize(visible=False)
    
    win = dcg.Window(ctx, label="Test Window", primary=True)
    button1 = dcg.Button(ctx, label="Button 1", parent=win)
    button2 = dcg.Button(ctx, label="Button 2", parent=win)
    
    # Render multiple frames
    for _ in range(3):
        viewport.render_frame()
    
    # All visible
    assert button1.state.visible
    assert button2.state.visible
    
    # Hide button1
    button1.show = False
    assert not button1.state.visible
    
    # button2 should still be visible
    assert button2.state.visible
    
    # Render to make sure states persist correctly
    viewport.render_frame()
    assert not button1.state.visible, "Button1 should remain hidden"
    assert button2.state.visible, "Button2 should remain visible"
    
    # Now detach button2 and check
    button2.parent = None
    assert not button2.state.visible, "Button2 should not be visible after detachment"

