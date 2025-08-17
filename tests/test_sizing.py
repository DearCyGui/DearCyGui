import pytest
import dearcygui as dcg

def parse_size(expr):
    # Helper function to parse a size expression
    return dcg.parse_size(expr)

@pytest.fixture
def ctx():
    # Create a minimal context for testing
    C = dcg.Context()
    return C

def test_parse_numeric_literals():
    # Test parsing simple numeric literals
    assert float(parse_size("100")) == 100
    assert float(parse_size("123.5")) == 123.5

def test_parse_keywords():
    # Test parsing built-in keywords
    assert str(parse_size("fillx")) == "fillx"
    assert str(parse_size("filly")) == "filly"
    assert str(parse_size("fullx")) == "fullx"
    assert str(parse_size("fully")) == "fully"
    assert str(parse_size("dpi")) == "dpi"

def test_parse_self_references():
    # Test parsing self references
    assert str(parse_size("self.width")) == "self.width"
    assert str(parse_size("self.height")) == "self.height"
    assert str(parse_size("self.x1")) == "self.x1"
    assert str(parse_size("self.x2")) == "self.x2"
    assert str(parse_size("self.y1")) == "self.y1"
    assert str(parse_size("self.y2")) == "self.y2"
    assert str(parse_size("self.xc")) == "self.xc"
    assert str(parse_size("self.yc")) == "self.yc"

def test_parse_basic_expressions():
    # Test parsing basic arithmetic expressions
    assert str(parse_size("100 + 50")) == "(100.0 + 50.0)"
    assert str(parse_size("100 - 50")) == "(100.0 - 50.0)"
    assert str(parse_size("100 * 0.5")) == "(100.0 * 0.5)"
    assert str(parse_size("100 / 2")) == "(100.0 / 2.0)"
    assert str(parse_size("100 // 3")) == "(100.0 // 3.0)"
    assert str(parse_size("100 % 30")) == "(100.0 % 30.0)"
    assert str(parse_size("10 ** 2")) == "(10.0 ** 2.0)"
    assert str(parse_size("-(100+1)")) == "(-(100.0 + 1.0))"

def test_parse_function_calls():
    # Test parsing function calls
    assert str(parse_size("min(100, 50)")) == "Min(100.0, 50.0)"
    assert str(parse_size("max(100, 50)")) == "Max(100.0, 50.0)"
    assert str(parse_size("abs(-100)")) == "abs((-100.0))"

def test_parse_operator_precedence():
    # Test operator precedence is respected
    # This should be parsed as 1 + (2 * 3) = 7, not (1 + 2) * 3 = 9
    expr = parse_size("1 + 2 * 3")
    assert str(expr) == "(1.0 + (2.0 * 3.0))"
    
    # Test that parentheses override default precedence
    expr = parse_size("(1 + 2) * 3")
    assert str(expr) == "((1.0 + 2.0) * 3.0)"

def test_parse_whitespace_handling():
    # Test that whitespace is handled correctly
    assert str(parse_size("100+50")) == str(parse_size("100 + 50"))
    assert float(parse_size(" 100 ")) == 100
    assert "Min" in str(parse_size("min( 100, 50 )"))

def test_parse_complex_expressions():
    # Test parsing more complex expressions
    expr = parse_size("(100 + 50) * 0.5")
    assert "+" in str(expr)
    assert "*" in str(expr)
    
    # Test a complex expression with functions and keywords
    complex_expr = parse_size("min(100 * dpi, fillx - 20)")
    assert "Min" in str(complex_expr)
    assert "dpi" in str(complex_expr)
    assert "fillx" in str(complex_expr)

def test_size_factory_methods():
    # Test Size factory methods
    assert float(dcg.Size.FIXED(100)) == 100
    assert str(dcg.Size.FILLX()) == "fillx"
    assert str(dcg.Size.FILLY()) == "filly"
    assert str(dcg.Size.FULLX()) == "fullx"
    assert str(dcg.Size.FULLY()) == "fully"
    assert str(dcg.Size.DPI()) == "dpi"
    
    # Test function factories
    assert "Min" in str(dcg.Size.MIN(100, 50))
    assert "Max" in str(dcg.Size.MAX(100, 50))
    assert "abs" in str(dcg.Size.ABS(-100))
    
    # Test with more arguments
    assert "Min" in str(dcg.Size.MIN(100, 50, 25))
    
    # Test from_expression (alias for parse_size)
    assert str(dcg.Size.from_expression("100 + 50")) == "(100.0 + 50.0)"

def test_size_self_reference_factory_methods():
    # Test Size factory methods for self references
    assert str(dcg.Size.SELF_WIDTH()) == "self.width"
    assert str(dcg.Size.SELF_HEIGHT()) == "self.height"
    assert str(dcg.Size.SELF_X1()) == "self.x1"
    assert str(dcg.Size.SELF_X2()) == "self.x2"
    assert str(dcg.Size.SELF_Y1()) == "self.y1"
    assert str(dcg.Size.SELF_Y2()) == "self.y2"
    assert str(dcg.Size.SELF_XC()) == "self.xc"
    assert str(dcg.Size.SELF_YC()) == "self.yc"

def test_size_operation_factory_methods():
    # Test Size factory methods for operations
    assert "+" in str(dcg.Size.ADD(100, 50))
    assert "-" in str(dcg.Size.SUBTRACT(100, 50))
    assert "*" in str(dcg.Size.MULTIPLY(100, 0.5))
    assert "/" in str(dcg.Size.DIVIDE(100, 2))
    assert "//" in str(dcg.Size.FLOOR_DIVIDE(100, 3))
    assert "%" in str(dcg.Size.MODULO(100, 30))
    assert "**" in str(dcg.Size.POWER(10, 2))
    assert "-" in str(dcg.Size.NEGATE(100))
    assert "abs" in str(dcg.Size.ABS(-100))

def test_item_references(ctx):
    # Create UI items to reference
    button = dcg.Button(ctx, label="Test Button")
    
    # Test Size factory methods for item references
    width_ref = dcg.Size.RELATIVEX(button)
    assert "other.width" in str(width_ref)
    
    height_ref = dcg.Size.RELATIVEY(button)
    assert "other.height" in str(height_ref)
    
    # Test coordinate references
    x1_ref = dcg.Size.RELATIVE_X1(button)
    assert "other.x1" in str(x1_ref)
    
    y2_ref = dcg.Size.RELATIVE_Y2(button)
    assert "other.y2" in str(y2_ref)
    
    xc_ref = dcg.Size.RELATIVE_XC(button)
    assert "other.xc" in str(xc_ref)

def test_size_arithmetic_operations():
    # Test arithmetic operations between sizing objects
    size1 = dcg.Size.FIXED(100)
    size2 = dcg.Size.FIXED(50)
    
    assert "+" in str(size1 + size2)
    assert "-" in str(size1 - size2)
    assert "*" in str(size1 * size2)
    assert "/" in str(size1 / size2)
    assert "//" in str(size1 // size2)
    assert "%" in str(size1 % size2)
    assert "**" in str(size1 ** size2)
    assert "-" in str(-size1)
    assert "abs" in str(abs(size1))
    
    # Test with mixed types (sizing object and number)
    assert "+" in str(size1 + 50)
    assert "+" in str(50 + size1)
    assert "*" in str(size1 * 0.5)
    assert "*" in str(2 * size1)

def test_parse_error_handling():
    # Test error handling
    with pytest.raises(ValueError):
        parse_size("")
    
    with pytest.raises(ValueError):
        parse_size("invalid_keyword")
    
    with pytest.raises(ValueError):
        parse_size("100 +")  # Incomplete expression
    
    with pytest.raises(ValueError):
        parse_size("(100 + 50")  # Unclosed parenthesis

def test_size_aliases():
    # Test that Sz is an alias for Size
    assert dcg.Sz is dcg.Size
    assert float(dcg.Sz.FIXED(100)) == 100


def test_widget_sizing_comprehensive(ctx):
    """Comprehensive test of widget sizing with string specifications."""
    viewport = ctx.viewport
    viewport.initialize(visible=False, width=800, height=600)
    window = dcg.Window(ctx, label="Size Test", width="600", height="400")
    
    def get_size(widget, frames=10):
        for _ in range(frames):
            viewport.render_frame()
        return widget.state.rect_size
    
    # Test exact fixed sizes - should be precise for string specifications
    fixed_tests = [
        ("200", 200), ("100", 100), ("50.7", 51),
        ("200 + 50", 250), ("100 * 2", 200), ("min(300, 150)", 150)
    ]
    
    for spec, expected in fixed_tests:
        btn = dcg.Button(ctx, label="Test", width=spec, parent=window)
        w, _ = get_size(btn)
        assert w == expected, f"Size '{spec}': expected {expected}, got {w}"
    
    # Get exact content width for fillx tests
    get_size(dcg.Button(ctx, label="Ref", width="100", parent=window))
    content_w = window.state.content_region_avail[0]
    
    # Test exact fillx behavior
    btn = dcg.Button(ctx, label="Button", width="fillx", parent=window)
    w, _ = get_size(btn)
    assert w == content_w, f"Button fillx should be exact: {w} vs {content_w}"


@pytest.mark.xfail(reason="Text widgets don't support fillx properly")
def test_text_fillx_fails(ctx):
    """Text widgets are known to not support fillx correctly."""
    viewport = ctx.viewport
    viewport.initialize(visible=False, width=800, height=600)
    window = dcg.Window(ctx, label="Test", width="600", height="400")
    
    def get_size(widget, frames=10):
        for _ in range(frames):
            viewport.render_frame()
        return widget.state.rect_size[0]
    
    content_w = window.state.content_region_avail[0]
    text = dcg.Text(ctx, value="Text", width="fillx", parent=window)
    w = get_size(text)
    assert w == content_w, f"Text fillx should match content width: {w} vs {content_w}"


@pytest.mark.xfail(reason="Slider widgets overshoot with fillx")
def test_slider_fillx_overshoots(ctx):
    """Slider widgets are known to overshoot with fillx."""
    viewport = ctx.viewport
    viewport.initialize(visible=False, width=800, height=600)
    window = dcg.Window(ctx, label="Test", width="600", height="400")
    
    def get_size(widget, frames=10):
        for _ in range(frames):
            viewport.render_frame()
        return widget.state.rect_size[0]
    
    content_w = window.state.content_region_avail[0]
    slider = dcg.Slider(ctx, label="Slider", width="fillx", parent=window)
    w = get_size(slider)
    assert w == content_w, f"Slider fillx should match content width: {w} vs {content_w}"


@pytest.mark.xfail(reason="InputText widgets overshoot with fillx")
def test_inputtext_fillx_overshoots(ctx):
    """InputText widgets are known to overshoot with fillx."""
    viewport = ctx.viewport
    viewport.initialize(visible=False, width=800, height=600)
    window = dcg.Window(ctx, label="Test", width="600", height="400")
    
    def get_size(widget, frames=10):
        for _ in range(frames):
            viewport.render_frame()
        return widget.state.rect_size[0]
    
    content_w = window.state.content_region_avail[0]
    input_text = dcg.InputText(ctx, label="Input", width="fillx", parent=window)
    w = get_size(input_text)
    assert w == content_w, f"InputText fillx should match content width: {w} vs {content_w}"


@pytest.mark.xfail(reason="ColorEdit widgets overshoot with fillx")
def test_coloredit_fillx_overshoots(ctx):
    """ColorEdit widgets are known to overshoot with fillx."""
    viewport = ctx.viewport
    viewport.initialize(visible=False, width=800, height=600)
    window = dcg.Window(ctx, label="Test", width="600", height="400")
    
    def get_size(widget, frames=10):
        for _ in range(frames):
            viewport.render_frame()
        return widget.state.rect_size[0]
    
    content_w = window.state.content_region_avail[0]
    color_edit = dcg.ColorEdit(ctx, label="Color", width="fillx", parent=window)
    w = get_size(color_edit)
    assert w == content_w, f"ColorEdit fillx should match content width: {w} vs {content_w}"


@pytest.mark.xfail(reason="Combo widgets overshoot with fillx")
def test_combo_fillx_overshoots(ctx):
    """Combo widgets are known to overshoot with fillx."""
    viewport = ctx.viewport
    viewport.initialize(visible=False, width=800, height=600)
    window = dcg.Window(ctx, label="Test", width="600", height="400")
    
    def get_size(widget, frames=10):
        for _ in range(frames):
            viewport.render_frame()
        return widget.state.rect_size[0]
    
    content_w = window.state.content_region_avail[0]
    combo = dcg.Combo(ctx, items=["A", "B"], label="Combo", width="fillx", parent=window)
    w = get_size(combo)
    assert w == content_w, f"Combo fillx should match content width: {w} vs {content_w}"


def test_layout_sizing_patterns(ctx):
    """Test exact sizing in different layout contexts."""
    viewport = ctx.viewport
    viewport.initialize(visible=False, width=800, height=600)
    window = dcg.Window(ctx, label="Layout", width="600", height="400")
    
    def get_size(widget, frames=10):
        for _ in range(frames):
            viewport.render_frame()
        return widget.state.rect_size[0]
    
    # Test exact relative sizing
    ref = dcg.Button(ctx, label="Ref", width="200", parent=window)
    rel = dcg.Button(ctx, label="Half", width=dcg.Size.RELATIVEX(ref) * 0.5, parent=window)
    assert get_size(rel) == get_size(ref) / 2, "Relative sizing should be exact"
    
    # Test exact layout container sizing
    with dcg.VerticalLayout(ctx, parent=window):
        v1 = dcg.Button(ctx, label="V1", width="fillx")
        v2 = dcg.Button(ctx, label="V2", width="fillx - 50")
    
    assert get_size(v1) - get_size(v2) == 50, "VBox size difference should be exactly 50"
    
    # Test horizontal layout equal sizing
    with dcg.HorizontalLayout(ctx, parent=window):
        h1 = dcg.Button(ctx, label="H1", width="100")
        h2 = dcg.Button(ctx, label="H2", width="100")
    
    assert get_size(h1) == get_size(h2), "HBox equal sizes should be exact"


def test_sizing_edge_cases(ctx):
    """Test edge cases and exact convergence."""
    viewport = ctx.viewport
    viewport.initialize(visible=False, width=800, height=600)
    window = dcg.Window(ctx, label="Edge", width="600", height="400")
    
    # Test convergence timing - should stabilize quickly
    btn = dcg.Button(ctx, label="Conv", width="fillx - 100", parent=window)
    sizes = [btn.state.rect_size[0] for _ in range(10) if viewport.render_frame() or True]
    
    # Should converge to exact value quickly
    final = sizes[-1]
    converged = next((i for i, s in enumerate(sizes) if s == final), None)
    assert converged is not None and converged <= 3, f"Should converge by frame 3, got frame {converged}"

    # Test exact complex expressions
    content_w = window.state.content_region_avail[0]
    
    # max(100, fillx/4) - should be exactly the larger value
    btn_max = dcg.Button(ctx, label="Max", width="max(100, fillx/4)", parent=window)
    while not viewport.render_frame():
        pass
    expected_max = max(100, content_w / 4)
    assert btn_max.state.rect_size[0] == expected_max, f"max() should be exact: expected {expected_max}"
    
    # min(fillx, 300) - should be exactly the smaller value  
    btn_min = dcg.Button(ctx, label="Min", width="min(fillx, 300)", parent=window)
    while not viewport.render_frame(): # TODO: fill x should instantly converge. Investigate why needed.
        pass
    viewport.render_frame() # TODO investigate why needed.
    expected_min = min(content_w, 300)
    assert btn_min.state.rect_size[0] == expected_min, f"min() should be exact: expected {expected_min}"