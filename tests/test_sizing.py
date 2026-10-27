import pytest
import dearcygui as dcg

def parse_size(expr):
    # Helper function to parse a size expression
    return dcg.parse_size(expr)

@pytest.fixture
def ctx():
    # Create a minimal context for testing
    C = dcg.Context()
    yield C
    C.queue.shutdown(wait=True)
    C.viewport.destroy()

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


# ---------------------------------------------------------------------------
# Shared helpers for rendering tests
# ---------------------------------------------------------------------------

@pytest.fixture
def vp_ctx():
    """Context with initialized, hidden viewport for rendering-based tests."""
    C = dcg.Context()
    C.viewport.initialize(visible=False, width=800, height=600)
    yield C
    C.queue.shutdown(wait=True)
    C.viewport.destroy()


def _render(vp, n=15):
    """Render n frames so that layout sizes stabilize."""
    for _ in range(n):
        vp.render_frame()


def _stable_window(ctx, w=700, h=500):
    """A fixed-size, non-resizable, non-scrolling window for sizing tests."""
    return dcg.Window(
        ctx, label="T",
        width=w, height=h,
        no_resize=True, no_move=True,
        no_scrollbar=True,
    )


def _sizes_converged(sizes, last_n=5):
    """Return True if the last `last_n` entries of `sizes` are all equal."""
    tail = sizes[-last_n:]
    return all(s == tail[0] for s in tail)


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

@pytest.mark.xfail(reason="Text widgets don't support setting their size")
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

# Note: these fails are due to the label and pass if we set an empty one
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
    
    size = dcg.Size.FILLX()
    slider = dcg.Slider(ctx, label="Slider", width=size, parent=window)
    w = get_size(slider)
    content_w = window.state.content_region_avail[0]
    assert content_w == size.value
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
    
    input_text = dcg.InputText(ctx, label="Input", width="fillx", parent=window)
    w = get_size(input_text)
    content_w = window.state.content_region_avail[0]
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

    color_edit = dcg.ColorEdit(ctx, label="Color", width="fillx", parent=window)
    w = get_size(color_edit)
    content_w = window.state.content_region_avail[0]
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

    combo = dcg.Combo(ctx, items=["A", "B"], label="Combo", width="fillx", parent=window)
    w = get_size(combo)
    content_w = window.state.content_region_avail[0]
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
    viewport.render_frame()
    expected_max = max(100, content_w / 4)
    assert btn_max.state.rect_size[0] == expected_max, f"max() should be exact: expected {expected_max}"
    
    # min(fillx, 300) - should be exactly the smaller value  
    btn_min = dcg.Button(ctx, label="Min", width="min(fillx, 300)", parent=window)
    viewport.render_frame()
    expected_min = min(content_w, 300)
    assert btn_min.state.rect_size[0] == expected_min, f"min() should be exact: expected {expected_min}"


# ===========================================================================
# HorizontalLayout alignment mode tests
# ===========================================================================

def test_hlayout_left_alignment(vp_ctx):
    """HorizontalLayout LEFT: first item at x=0, items left-to-right."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.HorizontalLayout(ctx, parent=window):
        b1 = dcg.Button(ctx, label="", width=80, height=30)
        b2 = dcg.Button(ctx, label="", width=80, height=30)
        b3 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    p1, p2, p3 = [b.state.pos_to_parent[0] for b in (b1, b2, b3)]
    # First item at left edge of layout
    assert p1 == 0, f"LEFT: first item x should be 0, got {p1}"
    # Items ordered left-to-right with no overlap
    assert p1 < p2 < p3
    assert p2 >= p1 + b1.state.rect_size[0]
    assert p3 >= p2 + b2.state.rect_size[0]


def test_hlayout_right_alignment(vp_ctx):
    """HorizontalLayout RIGHT: last item's right edge aligns with content width."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    _render(ctx.viewport)  # stable content width
    content_w = window.state.content_region_avail[0]
    with dcg.HorizontalLayout(ctx, alignment_mode=dcg.Alignment.RIGHT, parent=window):
        b1 = dcg.Button(ctx, label="", width=80, height=30)
        b2 = dcg.Button(ctx, label="", width=80, height=30)
        b3 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    p1, p2, p3 = [b.state.pos_to_parent[0] for b in (b1, b2, b3)]
    # Items ordered left-to-right
    assert p1 < p2 < p3
    # Last item's right edge at the layout content width
    last_right = p3 + b3.state.rect_size[0]
    assert abs(last_right - content_w) <= 1, (
        f"RIGHT: last right {last_right} should be at content_w {content_w}"
    )


def test_hlayout_center_alignment(vp_ctx):
    """HorizontalLayout CENTER: items are centered in the content area."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    _render(ctx.viewport)
    content_w = window.state.content_region_avail[0]
    with dcg.HorizontalLayout(ctx, alignment_mode=dcg.Alignment.CENTER, parent=window):
        b1 = dcg.Button(ctx, label="", width=80, height=30)
        b2 = dcg.Button(ctx, label="", width=80, height=30)
        b3 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    p1 = b1.state.pos_to_parent[0]
    p3 = b3.state.pos_to_parent[0]
    w3 = b3.state.rect_size[0]
    # Center of the items group ≈ center of content area
    group_center = (p1 + p3 + w3) / 2
    assert abs(group_center - content_w / 2) <= 1, (
        f"CENTER: group center {group_center} should ≈ content center {content_w / 2}"
    )
    # Symmetric gaps on both sides
    gap_left = p1
    gap_right = content_w - (p3 + w3)
    assert abs(gap_left - gap_right) <= 1, (
        f"CENTER: gaps should be symmetric, left={gap_left} right={gap_right}"
    )


def test_hlayout_justified_alignment(vp_ctx):
    """HorizontalLayout JUSTIFIED: first at left, last right edge at content width."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    _render(ctx.viewport)
    content_w = window.state.content_region_avail[0]
    with dcg.HorizontalLayout(ctx, alignment_mode=dcg.Alignment.JUSTIFIED, parent=window):
        b1 = dcg.Button(ctx, label="", width=80, height=30)
        b2 = dcg.Button(ctx, label="", width=80, height=30)
        b3 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    p1 = b1.state.pos_to_parent[0]
    p3 = b3.state.pos_to_parent[0]
    w3 = b3.state.rect_size[0]
    # First item at left edge
    assert abs(p1) <= 1, f"JUSTIFIED: first item x should be ≈0, got {p1}"
    # Last item's right edge at content width
    last_right = p3 + w3
    assert abs(last_right - content_w) <= 1, (
        f"JUSTIFIED: last right {last_right} should be at content_w {content_w}"
    )
    # Middle item between first and last
    p2 = b2.state.pos_to_parent[0]
    assert p1 < p2 < p3

# ===========================================================================
# HorizontalLayout wrapping tests
# ===========================================================================

def test_hlayout_wrapping_enabled(vp_ctx):
    """HorizontalLayout no_wrap=False (default): items wrap to the next row."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    _render(ctx.viewport)
    content_w = window.state.content_region_avail[0]
    # Items wider than half content so 3 can't fit in one row
    item_w = int(content_w * 0.4)
    with dcg.HorizontalLayout(ctx, no_wrap=False, parent=window) as layout:
        b1 = dcg.Button(ctx, label="", width=item_w, height=30)
        b2 = dcg.Button(ctx, label="", width=item_w, height=30)
        b3 = dcg.Button(ctx, label="", width=item_w, height=30)
    _render(ctx.viewport)

    p1_y = b1.state.pos_to_parent[1]
    p3_y = b3.state.pos_to_parent[1]
    # b3 must be on a lower row than b1
    assert p3_y > p1_y, (
        f"Wrap enabled: b3 y={p3_y} should be below b1 y={p1_y}"
    )
    # The layout overall height spans more than one row
    assert layout.state.rect_size[1] > b1.state.rect_size[1], (
        "Layout height should span more than one row"
    )


def test_hlayout_wrapping_disabled(vp_ctx):
    """HorizontalLayout no_wrap=True: all items remain on the same row."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    _render(ctx.viewport)
    content_w = window.state.content_region_avail[0]
    item_w = int(content_w * 0.4)
    with dcg.HorizontalLayout(ctx, no_wrap=True, parent=window):
        b1 = dcg.Button(ctx, label="", width=item_w, height=30)
        b2 = dcg.Button(ctx, label="", width=item_w, height=30)
        b3 = dcg.Button(ctx, label="", width=item_w, height=30)
    _render(ctx.viewport)

    # All items on the same row (y coordinate equal)
    p1_y = b1.state.pos_to_parent[1]
    p2_y = b2.state.pos_to_parent[1]
    p3_y = b3.state.pos_to_parent[1]
    assert p1_y == p2_y == p3_y, (
        f"no_wrap=True: all items on same row, got y={p1_y},{p2_y},{p3_y}"
    )
    # Items still ordered left-to-right even beyond content width
    p1_x, p2_x, p3_x = [b.state.pos_to_parent[0] for b in (b1, b2, b3)]
    assert p1_x < p2_x < p3_x


# ===========================================================================
# VerticalLayout alignment mode tests
# ===========================================================================

def test_vlayout_top_alignment(vp_ctx):
    """VerticalLayout TOP: first item at y=0, items stacked top-to-bottom."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.VerticalLayout(ctx, parent=window):
        b1 = dcg.Button(ctx, label="", width=100, height=30)
        b2 = dcg.Button(ctx, label="", width=100, height=30)
        b3 = dcg.Button(ctx, label="", width=100, height=30)
    _render(ctx.viewport)

    p1, p2, p3 = [b.state.pos_to_parent[1] for b in (b1, b2, b3)]
    assert p1 == 0, f"TOP: first item y should be 0, got {p1}"
    assert p1 < p2 < p3
    assert p2 >= p1 + b1.state.rect_size[1]
    assert p3 >= p2 + b2.state.rect_size[1]


def test_vlayout_bottom_alignment(vp_ctx):
    """VerticalLayout BOTTOM: last item's bottom edge aligns with layout content height."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    _render(ctx.viewport)
    with dcg.VerticalLayout(ctx, alignment_mode=dcg.Alignment.BOTTOM, parent=window) as layout:
        b1 = dcg.Button(ctx, label="", width=100, height=30)
        b2 = dcg.Button(ctx, label="", width=100, height=30)
        b3 = dcg.Button(ctx, label="", width=100, height=30)
    _render(ctx.viewport)

    p3 = b3.state.pos_to_parent[1]
    h3 = b3.state.rect_size[1]
    layout_h = layout.state.content_region_avail[1]
    last_bottom = p3 + h3
    assert abs(last_bottom - layout_h) <= 1, (
        f"BOTTOM: last bottom {last_bottom} should ≈ layout height {layout_h}"
    )
    p1, p2 = b1.state.pos_to_parent[1], b2.state.pos_to_parent[1]
    assert p1 < p2 < p3


def test_vlayout_center_alignment(vp_ctx):
    """VerticalLayout CENTER: items are centered vertically."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    _render(ctx.viewport)
    with dcg.VerticalLayout(ctx, alignment_mode=dcg.Alignment.CENTER, parent=window) as layout:
        b1 = dcg.Button(ctx, label="", width=100, height=30)
        b2 = dcg.Button(ctx, label="", width=100, height=30)
        b3 = dcg.Button(ctx, label="", width=100, height=30)
    _render(ctx.viewport)

    p1 = b1.state.pos_to_parent[1]
    p3 = b3.state.pos_to_parent[1]
    h3 = b3.state.rect_size[1]
    layout_h = layout.state.content_region_avail[1]
    group_center = (p1 + p3 + h3) / 2
    assert abs(group_center - layout_h / 2) <= 1, (
        f"CENTER: group center {group_center} should ≈ {layout_h / 2}"
    )
    gap_top = p1
    gap_bottom = layout_h - (p3 + h3)
    assert abs(gap_top - gap_bottom) <= 1, (
        f"CENTER: gaps should be symmetric, top={gap_top} bottom={gap_bottom}"
    )


def test_vlayout_justified_alignment(vp_ctx):
    """VerticalLayout JUSTIFIED: first at top, last bottom edge at layout height."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    _render(ctx.viewport)
    with dcg.VerticalLayout(ctx, alignment_mode=dcg.Alignment.JUSTIFIED, parent=window) as layout:
        b1 = dcg.Button(ctx, label="", width=100, height=30)
        b2 = dcg.Button(ctx, label="", width=100, height=30)
        b3 = dcg.Button(ctx, label="", width=100, height=30)
    _render(ctx.viewport)

    p1 = b1.state.pos_to_parent[1]
    p3 = b3.state.pos_to_parent[1]
    h3 = b3.state.rect_size[1]
    layout_h = layout.state.content_region_avail[1]
    assert abs(p1) <= 1, f"JUSTIFIED: first item y should be ≈0, got {p1}"
    last_bottom = p3 + h3
    assert abs(last_bottom - layout_h) <= 1, (
        f"JUSTIFIED: last bottom {last_bottom} should ≈ layout_h {layout_h}"
    )
    p2 = b2.state.pos_to_parent[1]
    assert p1 < p2 < p3


def test_vlayout_wrapping_into_columns(vp_ctx):
    """VerticalLayout wrap=True: items overflow into the next column."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    _render(ctx.viewport)
    content_h = window.state.content_region_avail[1]
    # Items taller than half the content so 3 can't fit in one column
    item_h = int(content_h * 0.4)
    with dcg.VerticalLayout(ctx, wrap=True, parent=window):
        b1 = dcg.Button(ctx, label="", width=80, height=item_h)
        b2 = dcg.Button(ctx, label="", width=80, height=item_h)
        b3 = dcg.Button(ctx, label="", width=80, height=item_h)
    _render(ctx.viewport)

    p1_x = b1.state.pos_to_parent[0]
    p3_x = b3.state.pos_to_parent[0]
    # b3 must be in a new column to the right of b1
    assert p3_x > p1_x, (
        f"wrap=True: b3 x={p3_x} should be in a new column (> b1 x={p1_x})"
    )


# ===========================================================================
# Nested layout stability tests
# ===========================================================================

def test_nested_hlayout_left_in_hlayout_left_stable(vp_ctx):
    """HorizontalLayout(LEFT) inside HorizontalLayout(LEFT): converges quickly."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.HorizontalLayout(ctx, parent=window):
        with dcg.HorizontalLayout(ctx) as inner:
            dcg.Button(ctx, label="", width=60, height=30)
            dcg.Button(ctx, label="", width=60, height=30)
        dcg.Button(ctx, label="", width=60, height=30)

    sizes = []
    for _ in range(20):
        ctx.viewport.render_frame()
        sizes.append(inner.state.rect_size)
    assert _sizes_converged(sizes, last_n=5), (
        f"Nested LEFT/LEFT hlayout should stabilize; last: {sizes[-6:]}"
    )


def test_nested_hlayout_left_in_hlayout_center_stable(vp_ctx):
    """HorizontalLayout(LEFT) with fixed children inside HorizontalLayout(CENTER): stable."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.HorizontalLayout(ctx, alignment_mode=dcg.Alignment.CENTER, parent=window):
        with dcg.HorizontalLayout(ctx) as inner:
            dcg.Button(ctx, label="", width=60, height=30)
            dcg.Button(ctx, label="", width=60, height=30)

    sizes = []
    for _ in range(20):
        ctx.viewport.render_frame()
        sizes.append(inner.state.rect_size)
    assert _sizes_converged(sizes, last_n=5), (
        f"Nested LEFT inside CENTER should stabilize; last: {sizes[-6:]}"
    )


def test_nested_vlayout_in_hlayout_stable(vp_ctx):
    """VerticalLayout inside HorizontalLayout: stable with fixed-size children."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.HorizontalLayout(ctx, parent=window):
        with dcg.VerticalLayout(ctx) as vlay:
            dcg.Button(ctx, label="", width=80, height=25)
            dcg.Button(ctx, label="", width=80, height=25)
        dcg.Button(ctx, label="", width=80, height=30)

    sizes = []
    for _ in range(20):
        ctx.viewport.render_frame()
        sizes.append(vlay.state.rect_size)
    assert _sizes_converged(sizes, last_n=5), (
        f"VerticalLayout inside HorizontalLayout should stabilize; last: {sizes[-6:]}"
    )


def test_nested_hlayout_in_vlayout_stable(vp_ctx):
    """HorizontalLayout inside VerticalLayout: stable with fixed-size children."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.VerticalLayout(ctx, parent=window):
        with dcg.HorizontalLayout(ctx) as hlay:
            dcg.Button(ctx, label="", width=80, height=25)
            dcg.Button(ctx, label="", width=80, height=25)
        dcg.Button(ctx, label="", width=80, height=30)

    sizes = []
    for _ in range(20):
        ctx.viewport.render_frame()
        sizes.append(hlay.state.rect_size)
    assert _sizes_converged(sizes, last_n=5), (
        f"HorizontalLayout inside VerticalLayout should stabilize; last: {sizes[-6:]}"
    )


def test_nested_3level_layout_stable(vp_ctx):
    """Three levels of nested layouts stabilize."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.HorizontalLayout(ctx, parent=window):
        with dcg.VerticalLayout(ctx):
            with dcg.HorizontalLayout(ctx) as inner_h:
                dcg.Button(ctx, label="", width=60, height=25)
                dcg.Button(ctx, label="", width=60, height=25)
            dcg.Button(ctx, label="", width=60, height=25)
        dcg.Button(ctx, label="", width=60, height=30)

    sizes = []
    for _ in range(25):
        ctx.viewport.render_frame()
        sizes.append(inner_h.state.rect_size)
    assert _sizes_converged(sizes, last_n=5), (
        f"3-level nested layout should stabilize; last: {sizes[-6:]}"
    )

def test_nested_3level_layout_stable_with_string_sizing(vp_ctx):
    """Three levels of nested layouts stabilize with string-based sizing."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.Layout(ctx, parent=window, width="fillx", height="filly"):
        with dcg.Layout(ctx, width="0.5*fullx", height="filly", no_newline=True):
            with dcg.Layout(ctx):
                dcg.Button(ctx, label="", width="fullx/2", height="fully")
                dcg.Button(ctx, label="", width="fillx", height="25")
            dcg.Button(ctx, label="", width="fullx", height="25")
        with dcg.Layout(ctx, width="fillx", height="filly"):
            with dcg.Layout(ctx) as inner_h:
                dcg.Button(ctx, label="", width="fullx/2", height="fully")
                dcg.Button(ctx, label="", width="fillx", height="25")
            dcg.Button(ctx, label="", width="fullx", height="25")
        dcg.Button(ctx, label="", width="60", height="30")

    sizes = []
    for _ in range(25):
        ctx.viewport.render_frame()
        sizes.append(inner_h.state.rect_size)
    assert _sizes_converged(sizes, last_n=5), (
        f"3-level nested layout should stabilize; last: {sizes[-6:]}"
    )


# ===========================================================================
# ChildWindow basic sizing tests
# ===========================================================================

def test_childwindow_fixed_size_with_border(vp_ctx):
    """ChildWindow with explicit size and border=True: rect_size matches request."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    # Use string sizes so they are not DPI-scaled (integer sizes are scaled by dpi)
    cw = dcg.ChildWindow(ctx, width='200', height='150', border=True, parent=window)
    _render(ctx.viewport)

    assert cw.state.rect_size[0] == 200, (
        f"ChildWindow width: expected 200, got {cw.state.rect_size[0]}"
    )
    assert cw.state.rect_size[1] == 150, (
        f"ChildWindow height: expected 150, got {cw.state.rect_size[1]}"
    )


def test_childwindow_fixed_size_without_border(vp_ctx):
    """ChildWindow with explicit size and border=False: rect_size matches request."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    cw = dcg.ChildWindow(ctx, width='200', height='150', border=False, parent=window)
    _render(ctx.viewport)

    assert cw.state.rect_size[0] == 200, (
        f"ChildWindow width: expected 200, got {cw.state.rect_size[0]}"
    )
    assert cw.state.rect_size[1] == 150, (
        f"ChildWindow height: expected 150, got {cw.state.rect_size[1]}"
    )


def test_childwindow_fillx(vp_ctx):
    """ChildWindow with fillx fills the parent's content width."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    _render(ctx.viewport)
    content_w = window.state.content_region_avail[0]

    cw = dcg.ChildWindow(ctx, width="fillx", height=100, parent=window)
    _render(ctx.viewport)
    assert cw.state.rect_size[0] == content_w, (
        f"fillx ChildWindow: expected width {content_w}, got {cw.state.rect_size[0]}"
    )


def test_childwindow_filly(vp_ctx):
    """ChildWindow with filly fills the parent's remaining content height."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    _render(ctx.viewport)
    content_h = window.state.content_region_avail[1]

    cw = dcg.ChildWindow(ctx, width=100, height="filly", parent=window)
    _render(ctx.viewport)
    assert cw.state.rect_size[1] == content_h, (
        f"filly ChildWindow: expected height {content_h}, got {cw.state.rect_size[1]}"
    )


# ===========================================================================
# ChildWindow border vs. no-border content area tests
# ===========================================================================

def test_childwindow_border_shrinks_content(vp_ctx):
    """ChildWindow with border: content_region_avail < rect_size."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    cw = dcg.ChildWindow(ctx, width='200', height='150', border=True, parent=window)
    _render(ctx.viewport)

    w, h = cw.state.rect_size
    cw_x, cw_y = cw.state.content_region_avail
    assert cw_x < w, f"Border: content_w {cw_x} should be < rect_w {w}"
    assert cw_y < h, f"Border: content_h {cw_y} should be < rect_h {h}"


def test_childwindow_no_border_full_content(vp_ctx):
    """ChildWindow without border: content_region_avail equals rect_size."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    cw = dcg.ChildWindow(ctx, width='200', height='150', border=False, parent=window)
    _render(ctx.viewport)

    w, h = cw.state.rect_size
    cw_x, cw_y = cw.state.content_region_avail
    assert cw_x == w, f"No-border: content_w {cw_x} should == rect_w {w}"
    assert cw_y == h, f"No-border: content_h {cw_y} should == rect_h {h}"


def test_childwindow_border_vs_no_border_same_outer_size(vp_ctx):
    """Same outer size: bordered ChildWindow has smaller content area."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    cw_border    = dcg.ChildWindow(ctx, width='200', height='100', border=True,  parent=window)
    cw_no_border = dcg.ChildWindow(ctx, width='200', height='100', border=False, parent=window)
    _render(ctx.viewport)

    # Same outer sizes
    assert cw_border.state.rect_size[0]    == cw_no_border.state.rect_size[0] == 200
    assert cw_border.state.rect_size[1]    == cw_no_border.state.rect_size[1] == 100
    # Bordered → smaller content area
    assert cw_border.state.content_region_avail[0] < cw_no_border.state.content_region_avail[0]
    assert cw_border.state.content_region_avail[1] < cw_no_border.state.content_region_avail[1]


def test_childwindow_always_use_window_padding(vp_ctx):
    """always_use_window_padding adds padding to a borderless ChildWindow."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    cw_padded = dcg.ChildWindow(
        ctx, width='200', height='100',
        border=False, always_use_window_padding=True,
        parent=window,
    )
    cw_plain = dcg.ChildWindow(
        ctx, width='200', height='100',
        border=False, always_use_window_padding=False,
        parent=window,
    )
    _render(ctx.viewport)

    # Same outer size
    assert cw_padded.state.rect_size[0] == cw_plain.state.rect_size[0] == 200
    # Padded one has smaller content area
    assert cw_padded.state.content_region_avail[0] < cw_plain.state.content_region_avail[0]
    assert cw_padded.state.content_region_avail[1] < cw_plain.state.content_region_avail[1]


# ===========================================================================
# Nested ChildWindow tests (with and without borders)
# ===========================================================================

def test_nested_childwindow_both_bordered(vp_ctx):
    """Two bordered ChildWindows nested: each has its own requested rect_size."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    outer = dcg.ChildWindow(ctx, width='300', height='200', border=True,  parent=window)
    inner = dcg.ChildWindow(ctx, width='100', height='80',  border=True,  parent=outer)
    _render(ctx.viewport)

    assert outer.state.rect_size == (300, 200)
    assert inner.state.rect_size == (100, 80)
    # Inner has a border: its content area is smaller
    assert inner.state.content_region_avail[0] < 100
    assert inner.state.content_region_avail[1] < 80
    # Inner fits within outer's content area
    outer_cw, outer_ch = outer.state.content_region_avail
    assert inner.state.rect_size[0] <= outer_cw
    assert inner.state.rect_size[1] <= outer_ch


def test_nested_childwindow_both_no_border(vp_ctx):
    """Two borderless ChildWindows nested: both have full content regions."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    outer = dcg.ChildWindow(ctx, width='300', height='200', border=False, parent=window)
    inner = dcg.ChildWindow(ctx, width='120', height='90',  border=False, parent=outer)
    _render(ctx.viewport)

    assert outer.state.rect_size == (300, 200)
    assert inner.state.rect_size == (120, 90)
    # No-border: content == outer size
    assert inner.state.content_region_avail[0] == 120
    assert inner.state.content_region_avail[1] == 90


def test_nested_childwindow_outer_bordered_inner_not(vp_ctx):
    """Outer bordered, inner not: inner fills its content fully."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    outer = dcg.ChildWindow(ctx, width='300', height='200', border=True,  parent=window)
    inner = dcg.ChildWindow(ctx, width='100', height='60',  border=False, parent=outer)
    _render(ctx.viewport)

    # Outer's content area is reduced by border/padding
    assert outer.state.content_region_avail[0] < 300
    # Inner fits within outer
    assert inner.state.rect_size[0] <= outer.state.content_region_avail[0]
    # Inner (no border): content == rect_size
    assert inner.state.content_region_avail[0] == inner.state.rect_size[0]
    assert inner.state.content_region_avail[1] == inner.state.rect_size[1]


def test_nested_childwindow_outer_not_inner_bordered(vp_ctx):
    """Outer not bordered, inner bordered: inner's content is reduced."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    outer = dcg.ChildWindow(ctx, width='300', height='200', border=False, parent=window)
    inner = dcg.ChildWindow(ctx, width='100', height='60',  border=True,  parent=outer)
    _render(ctx.viewport)

    # Outer has no border: its content fills its rect
    assert outer.state.content_region_avail == (300, 200)
    # Inner rect_size matches request
    assert inner.state.rect_size == (100, 60)
    # Inner content is reduced by its border
    assert inner.state.content_region_avail[0] < 100
    assert inner.state.content_region_avail[1] < 60


def test_nested_childwindow_three_levels(vp_ctx):
    """Three-level nesting: each ChildWindow keeps its requested rect_size."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    outer  = dcg.ChildWindow(ctx, width='400', height='300', border=True,  parent=window)
    middle = dcg.ChildWindow(ctx, width='200', height='150', border=False, parent=outer)
    inner  = dcg.ChildWindow(ctx, width='80',  height='60',  border=True,  parent=middle)
    _render(ctx.viewport)

    assert outer.state.rect_size  == (400, 300)
    assert middle.state.rect_size == (200, 150)
    assert inner.state.rect_size  == (80, 60)
    # middle (no border): content == rect_size
    assert middle.state.content_region_avail[0] == 200
    assert middle.state.content_region_avail[1] == 150
    # inner (border): content < rect_size
    assert inner.state.content_region_avail[0] < 80
    assert inner.state.content_region_avail[1] < 60


def test_nested_childwindow_fillx_in_bordered(vp_ctx):
    """fillx inner ChildWindow fills the bordered outer's content area."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    outer = dcg.ChildWindow(ctx, width='300', height='200', border=True, parent=window)
    _render(ctx.viewport)
    outer_content_w = outer.state.content_region_avail[0]

    inner = dcg.ChildWindow(ctx, width="fillx", height='50', border=False, parent=outer)
    _render(ctx.viewport)
    assert inner.state.rect_size[0] == outer_content_w, (
        f"fillx inner: expected {outer_content_w}, got {inner.state.rect_size[0]}"
    )


# ===========================================================================
# Layout inside ChildWindow tests
# ===========================================================================

def test_hlayout_content_width_matches_childwindow(vp_ctx):
    """HorizontalLayout inside ChildWindow: layout content width = ChildWindow content width."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    cw = dcg.ChildWindow(ctx, width='300', height='150', border=True, parent=window)
    _render(ctx.viewport)
    cw_content_w = cw.state.content_region_avail[0]

    with dcg.HorizontalLayout(ctx, parent=cw) as hlay:
        dcg.Button(ctx, label="", width=60, height=25)
        dcg.Button(ctx, label="", width=60, height=25)
    _render(ctx.viewport)

    assert abs(hlay.state.content_region_avail[0] - cw_content_w) <= 1, (
        f"HLayout content_w {hlay.state.content_region_avail[0]} should ≈ "
        f"ChildWindow content_w {cw_content_w}"
    )


def test_hlayout_right_in_childwindow(vp_ctx):
    """HorizontalLayout RIGHT inside ChildWindow: items aligned to ChildWindow content edge."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    cw = dcg.ChildWindow(ctx, width='300', height='150', border=True, parent=window)
    _render(ctx.viewport)
    cw_content_w = cw.state.content_region_avail[0]

    with dcg.HorizontalLayout(ctx, alignment_mode=dcg.Alignment.RIGHT, parent=cw):
        b1 = dcg.Button(ctx, label="", width=60, height=25)
        b2 = dcg.Button(ctx, label="", width=60, height=25)
    _render(ctx.viewport)

    last_right = b2.state.pos_to_parent[0] + b2.state.rect_size[0]
    assert abs(last_right - cw_content_w) <= 1, (
        f"RIGHT in ChildWindow: last right {last_right} should ≈ content_w {cw_content_w}"
    )


def test_justified_hlayout_in_childwindow(vp_ctx):
    """JUSTIFIED HorizontalLayout in ChildWindow: first at left, last at right edge."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    cw = dcg.ChildWindow(ctx, width='300', height='80', border=True, parent=window)
    _render(ctx.viewport)
    cw_content_w = cw.state.content_region_avail[0]

    with dcg.HorizontalLayout(ctx, alignment_mode=dcg.Alignment.JUSTIFIED, parent=cw):
        b1 = dcg.Button(ctx, label="", width=60, height=25)
        b2 = dcg.Button(ctx, label="", width=60, height=25)
    _render(ctx.viewport)

    p1 = b1.state.pos_to_parent[0]
    last_right = b2.state.pos_to_parent[0] + b2.state.rect_size[0]
    assert abs(p1) <= 1, f"JUSTIFIED in CW: first item x should be ≈0, got {p1}"
    assert abs(last_right - cw_content_w) <= 1, (
        f"JUSTIFIED in CW: last right {last_right} should ≈ {cw_content_w}"
    )


def test_vlayout_in_childwindow_stable(vp_ctx):
    """VerticalLayout inside ChildWindow: sizes converge quickly."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    cw = dcg.ChildWindow(ctx, width='200', height='300', border=False, parent=window)
    with dcg.VerticalLayout(ctx, parent=cw) as vlay:
        dcg.Button(ctx, label="", width=100, height=30)
        dcg.Button(ctx, label="", width=100, height=30)

    sizes = []
    for _ in range(20):
        ctx.viewport.render_frame()
        sizes.append(vlay.state.rect_size)
    assert _sizes_converged(sizes, last_n=5), (
        f"VerticalLayout in ChildWindow should stabilize; last: {sizes[-6:]}"
    )


# ===========================================================================
# ChildWindow inside Layout tests
# ===========================================================================

def test_childwindow_in_hlayout_keeps_size(vp_ctx):
    """ChildWindow inside HorizontalLayout: ChildWindow gets its requested size."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.HorizontalLayout(ctx, parent=window):
        cw  = dcg.ChildWindow(ctx, width='150', height='80', border=True)
        dcg.Button(ctx, label="", width=80, height=80)
    _render(ctx.viewport)

    assert cw.state.rect_size[0] == 150, (
        f"ChildWindow in HLayout: width {cw.state.rect_size[0]} should be 150"
    )
    assert cw.state.rect_size[1] == 80, (
        f"ChildWindow in HLayout: height {cw.state.rect_size[1]} should be 80"
    )


def test_childwindow_in_vlayout_keeps_size(vp_ctx):
    """ChildWindow inside VerticalLayout: ChildWindow gets its requested size."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.VerticalLayout(ctx, parent=window):
        cw = dcg.ChildWindow(ctx, width='150', height='80', border=False)
        dcg.Button(ctx, label="", width=150, height=30)
    _render(ctx.viewport)

    assert cw.state.rect_size[0] == 150
    assert cw.state.rect_size[1] == 80


def test_nested_childwindow_in_layout_in_childwindow(vp_ctx):
    """Deep nesting: ChildWindow → Layout → ChildWindow keeps inner rect_size."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    outer_cw = dcg.ChildWindow(ctx, width='350', height='250', border=True, parent=window)
    with dcg.HorizontalLayout(ctx, alignment_mode=dcg.Alignment.CENTER, parent=outer_cw):
        inner_cw = dcg.ChildWindow(ctx, width='100', height='80', border=True)
    _render(ctx.viewport)

    assert inner_cw.state.rect_size[0] == 100
    assert inner_cw.state.rect_size[1] == 80


# --- Stable cases (no sibling) — regression guards, expected to pass -------

def test_layout_filly_single_parent_height_child_stable(vp_ctx):
    """A filly layout with only a parent.height button and no siblings is stable."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.Layout(ctx, parent=window, height="filly") as layout:
        dcg.Button(ctx, label="", width="50", height="parent.height")

    sizes = []
    for _ in range(25):
        ctx.viewport.render_frame()
        sizes.append(layout.state.rect_size)
    assert _sizes_converged(sizes, last_n=5), (
        f"filly + single parent.height child should stabilize; last: {sizes[-6:]}"
    )


def test_layout_fully_single_parent_height_child_stable(vp_ctx):
    """A fully layout with only a parent.height button and no siblings is stable."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.Layout(ctx, parent=window, height="fully") as layout:
        dcg.Button(ctx, label="", width="50", height="parent.height")

    sizes = []
    for _ in range(25):
        ctx.viewport.render_frame()
        sizes.append(layout.state.rect_size)
    assert _sizes_converged(sizes, last_n=5), (
        f"fully + single parent.height child should stabilize; last: {sizes[-6:]}"
    )


def test_nested_filly_single_parent_height_child_stable(vp_ctx):
    """Two nested filly layouts with only a parent.height button is stable."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.Layout(ctx, parent=window, height="filly"):
        with dcg.Layout(ctx, height="filly") as inner:
            dcg.Button(ctx, label="", width="50", height="parent.height")

    sizes = []
    for _ in range(25):
        ctx.viewport.render_frame()
        sizes.append(inner.state.rect_size)
    assert _sizes_converged(sizes, last_n=5), (
        f"Nested filly + single parent.height child should stabilize; last: {sizes[-6:]}"
    )


# --- ChildWindow-only stable cases — confirm issue is absent outside Layout --

def test_childwindow_filly_parent_height_with_sibling_stable(vp_ctx):
    """ChildWindow with filly: parent.height button alongside fixed sibling stays stable.

    This is the ChildWindow equivalent of the broken Layout pattern; it should
    NOT exhibit the height-growth loop, confirming the bug is specific to Layout.
    """
    ctx = vp_ctx
    window = _stable_window(ctx)
    cw = dcg.ChildWindow(ctx, parent=window, width="fillx", height="filly")
    dcg.Button(ctx, label="", width="50", height="parent.height", parent=cw)
    dcg.Button(ctx, label="", width="50", height="25", parent=cw)

    sizes = []
    for _ in range(25):
        ctx.viewport.render_frame()
        sizes.append(cw.state.rect_size)
    assert _sizes_converged(sizes, last_n=5), (
        f"filly ChildWindow + parent.height + fixed sibling should stabilize; last: {sizes[-6:]}"
    )


def test_childwindow_fixed_parent_height_with_sibling_stable(vp_ctx):
    """Fixed-height ChildWindow: parent.height button alongside fixed sibling stays stable."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    cw = dcg.ChildWindow(ctx, parent=window, width="200", height="200")
    dcg.Button(ctx, label="", width="50", height="parent.height", parent=cw)
    dcg.Button(ctx, label="", width="50", height="25", parent=cw)

    sizes = []
    for _ in range(25):
        ctx.viewport.render_frame()
        sizes.append(cw.state.rect_size)
    assert _sizes_converged(sizes, last_n=5), (
        f"Fixed ChildWindow + parent.height + fixed sibling should stabilize; last: {sizes[-6:]}"
    )


def test_nested_childwindows_parent_height_with_sibling_stable(vp_ctx):
    """Nested ChildWindows: inner filly CW with parent.height button + sibling stays stable."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    outer = dcg.ChildWindow(ctx, parent=window, width="300", height="300")
    inner = dcg.ChildWindow(ctx, parent=outer, width="fillx", height="filly")
    dcg.Button(ctx, label="", width="50", height="parent.height", parent=inner)
    dcg.Button(ctx, label="", width="50", height="25", parent=inner)

    sizes = []
    for _ in range(25):
        ctx.viewport.render_frame()
        sizes.append(inner.state.rect_size)
    assert _sizes_converged(sizes, last_n=5), (
        f"Nested ChildWindows + parent.height + sibling should stabilize; last: {sizes[-6:]}"
    )


# --- Broken cases (with fixed-height sibling) — expected to fail -----------

def test_layout_filly_mixed_children_stable(vp_ctx):
    """Minimal reproducer: filly layout, parent.height button alongside fixed-height sibling."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.Layout(ctx, parent=window, height="filly") as layout:
        dcg.Button(ctx, label="", width="50", height="filly")
        dcg.Button(ctx, label="", width="50", height="25")

    sizes = []
    for _ in range(25):
        ctx.viewport.render_frame()
        sizes.append(layout.state.rect_size)
    assert _sizes_converged(sizes, last_n=5), (
        f"filly + parent.height + fixed sibling should stabilize; last: {sizes[-6:]}"
    )


def test_layout_fully_mixed_children_stable(vp_ctx):
    """fully layout, parent.height button alongside fixed-height sibling."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.Layout(ctx, parent=window, height="fully") as layout:
        dcg.Button(ctx, label="", width="50", height="filly")
        dcg.Button(ctx, label="", width="50", height="25")

    sizes = []
    for _ in range(25):
        ctx.viewport.render_frame()
        sizes.append(layout.state.rect_size)
    assert _sizes_converged(sizes, last_n=5), (
        f"fully + parent.height + fixed sibling should stabilize; last: {sizes[-6:]}"
    )


def test_layout_in_childwindow_mixed_children_stable(vp_ctx):
    """filly layout inside a fixed ChildWindow: parent.height button + fixed sibling."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    cw = dcg.ChildWindow(ctx, parent=window, width="200", height="200")
    with dcg.Layout(ctx, parent=cw, height="filly") as layout:
        dcg.Button(ctx, label="", width="50", height="filly")
        dcg.Button(ctx, label="", width="50", height="25")

    sizes = []
    for _ in range(25):
        ctx.viewport.render_frame()
        sizes.append(layout.state.rect_size)
    assert _sizes_converged(sizes, last_n=5), (
        f"filly layout in ChildWindow + parent.height + sibling should stabilize; last: {sizes[-6:]}"
    )


def test_nested_filly_mixed_children_stable(vp_ctx):
    """Two nested filly layouts, innermost has parent.height button and fixed sibling."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.Layout(ctx, parent=window, height="filly"):
        with dcg.Layout(ctx, height="filly") as inner:
            dcg.Button(ctx, label="", width="50", height="filly")
            dcg.Button(ctx, label="", width="50", height="25")

    sizes = []
    for _ in range(25):
        ctx.viewport.render_frame()
        sizes.append(inner.state.rect_size)
    assert _sizes_converged(sizes, last_n=5), (
        f"Nested filly + parent.height + sibling should stabilize; last: {sizes[-6:]}"
    )


# ===========================================================================
# HorizontalLayout / VerticalLayout — zero-size items and hidden items
#
# "Zero-size items": has_rect_size=False (dcg.Tooltip is the canonical proxy).
#   They draw as floating popups; the inline ImGui cursor does not advance.
#
# "Hidden items": show=False.  has_rect_size=True capability but rect_size==0
#   when not drawn.
# ===========================================================================


# ---------------------------------------------------------------------------
# Phase 1 — HorizontalLayout LEFT+no_wrap, zero-size items (Tooltip)
# ---------------------------------------------------------------------------

def test_hlayout_left_no_wrap_item_tooltip_item_spacing(vp_ctx):
    """HLayout LEFT+no_wrap: Tooltip between items preserves normal spacing_x."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    # Reference: two adjacent buttons (no tooltip)
    with dcg.HorizontalLayout(ctx, parent=window):
        rb1 = dcg.Button(ctx, label="", width=80, height=30)
        rb2 = dcg.Button(ctx, label="", width=80, height=30)
    # Test: same setup with a Tooltip between them
    with dcg.HorizontalLayout(ctx, parent=window):
        tb1 = dcg.Button(ctx, label="", width=80, height=30)
        dcg.Tooltip(ctx)
        tb2 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    ref_gap = (rb2.state.pos_to_parent.x
               - rb1.state.pos_to_parent.x - rb1.state.rect_size.x)
    test_gap = (tb2.state.pos_to_parent.x
                - tb1.state.pos_to_parent.x - tb1.state.rect_size.x)
    assert abs(test_gap - ref_gap) <= 1, (
        f"LEFT+no_wrap item+tooltip+item: gap={test_gap} should equal ref gap={ref_gap}"
    )


def test_hlayout_left_no_wrap_tooltip_as_first_child(vp_ctx):
    """HLayout LEFT+no_wrap: leading Tooltip does not shift first visible item from x=0."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.HorizontalLayout(ctx, parent=window):
        dcg.Tooltip(ctx)
        b1 = dcg.Button(ctx, label="", width=80, height=30)
        b2 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    assert b1.state.pos_to_parent.x == 0, (
        f"Leading tooltip: first button x={b1.state.pos_to_parent.x} should be 0"
    )
    # b2 must be to the right of b1 with some positive gap
    gap = b2.state.pos_to_parent.x - (b1.state.pos_to_parent.x + b1.state.rect_size.x)
    assert gap > 0, (
        f"Leading tooltip: gap between b1 and b2 should be > 0, got {gap}"
    )


def test_hlayout_left_no_wrap_tooltip_as_last_child(vp_ctx):
    """HLayout LEFT+no_wrap: trailing Tooltip does not inflate the layout rect_size."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    # Reference: two buttons with no trailing tooltip
    with dcg.HorizontalLayout(ctx, parent=window, no_newline=True) as ref:
        dcg.Button(ctx, label="", width=80, height=30)
        dcg.Button(ctx, label="", width=80, height=30)
    r = dcg.Button(ctx, label="", width=80, height=30)
    # Test: same buttons followed by a Tooltip
    with dcg.HorizontalLayout(ctx, parent=window, no_newline=True) as test:
        dcg.Button(ctx, label="", width=80, height=30)
        dcg.Button(ctx, label="", width=80, height=30)
        dcg.Tooltip(ctx)
    t = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    assert abs(test.state.rect_size.x - ref.state.rect_size.x) <= 1, (
        f"Trailing tooltip: layout width {test.state.rect_size.x} "
        f"should match no-tooltip width {ref.state.rect_size.x}"
    )
    assert abs(t.state.pos_to_parent.x - r.state.pos_to_parent.x) <= 1, (
        f"Trailing tooltip: next item x={t.state.pos_to_parent.x} should match "
        f"no-tooltip next item x={r.state.pos_to_parent.x}"
    )


def test_hlayout_left_no_wrap_multiple_consecutive_tooltips(vp_ctx):
    """HLayout LEFT+no_wrap: multiple consecutive Tooltips between items don't add spacing."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    # Reference: two adjacent buttons
    with dcg.HorizontalLayout(ctx, parent=window):
        rb1 = dcg.Button(ctx, label="", width=80, height=30)
        rb2 = dcg.Button(ctx, label="", width=80, height=30)
    # Test: three tooltips between the same two buttons
    with dcg.HorizontalLayout(ctx, parent=window):
        tb1 = dcg.Button(ctx, label="", width=80, height=30)
        dcg.Tooltip(ctx)
        dcg.Tooltip(ctx)
        dcg.Tooltip(ctx)
        tb2 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    ref_gap = (rb2.state.pos_to_parent.x
               - rb1.state.pos_to_parent.x - rb1.state.rect_size.x)
    test_gap = (tb2.state.pos_to_parent.x
                - tb1.state.pos_to_parent.x - tb1.state.rect_size.x)
    assert abs(test_gap - ref_gap) <= 1, (
        f"3 consecutive tooltips: gap={test_gap} should equal ref gap={ref_gap}"
    )


def test_hlayout_left_wrap_item_tooltip_item_spacing(vp_ctx):
    """HLayout LEFT+wrap: Tooltip between items should preserve spacing_x (currently broken)."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    # Reference: two adjacent buttons, wrapping enabled
    with dcg.HorizontalLayout(ctx, no_wrap=False, parent=window):
        rb1 = dcg.Button(ctx, label="", width=80, height=30)
        rb2 = dcg.Button(ctx, label="", width=80, height=30)
    # Test: same buttons with a tooltip between them
    with dcg.HorizontalLayout(ctx, no_wrap=False, parent=window):
        tb1 = dcg.Button(ctx, label="", width=80, height=30)
        dcg.Tooltip(ctx)
        tb2 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    ref_gap = (rb2.state.pos_to_parent.x
               - rb1.state.pos_to_parent.x - rb1.state.rect_size.x)
    test_gap = (tb2.state.pos_to_parent.x
                - tb1.state.pos_to_parent.x - tb1.state.rect_size.x)
    assert abs(test_gap - ref_gap) <= 1, (
        f"LEFT+wrap item+tooltip+item: gap={test_gap} should equal ref gap={ref_gap}"
    )


# ---------------------------------------------------------------------------
# Phase 2 — HorizontalLayout LEFT, hidden items (show=False)
# ---------------------------------------------------------------------------

def test_hlayout_left_no_wrap_item_hidden_item(vp_ctx):
    """HLayout LEFT+no_wrap: hidden middle item keeps next item on the same row, no double-spacing."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    # Reference: two visible adjacent buttons
    with dcg.HorizontalLayout(ctx, parent=window):
        rb1 = dcg.Button(ctx, label="", width=80, height=30)
        rb2 = dcg.Button(ctx, label="", width=80, height=30)
    # Test: hidden button between them
    with dcg.HorizontalLayout(ctx, parent=window):
        tb1 = dcg.Button(ctx, label="", width=80, height=30)
        dcg.Button(ctx, label="", width=80, height=30, show=False)
        tb2 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    # tb2 must be on the same row as tb1
    assert tb2.state.pos_to_parent.y == tb1.state.pos_to_parent.y, (
        f"Hidden middle item: tb2 y={tb2.state.pos_to_parent.y} "
        f"should equal tb1 y={tb1.state.pos_to_parent.y}"
    )
    # Gap between tb1 and tb2 should match the reference (no hidden item)
    ref_gap = (rb2.state.pos_to_parent.x
               - rb1.state.pos_to_parent.x - rb1.state.rect_size.x)
    test_gap = (tb2.state.pos_to_parent.x
                - tb1.state.pos_to_parent.x - tb1.state.rect_size.x)
    assert abs(test_gap - ref_gap) <= 1, (
        f"Hidden middle item: gap={test_gap} should equal ref gap={ref_gap}"
    )


def test_hlayout_left_no_wrap_first_item_hidden(vp_ctx):
    """HLayout LEFT+no_wrap: hidden first item → second item starts at x=0."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.HorizontalLayout(ctx, parent=window):
        dcg.Button(ctx, label="", width=80, height=30, show=False)
        b2 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    assert b2.state.pos_to_parent.x == 0, (
        f"Hidden first item: second button x={b2.state.pos_to_parent.x} should be 0"
    )


def test_hlayout_left_no_wrap_last_item_hidden_layout_width(vp_ctx):
    """HLayout LEFT+no_wrap: hidden last item does not inflate layout rect_size."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    # Reference: one visible button
    with dcg.HorizontalLayout(ctx, parent=window) as ref:
        dcg.Button(ctx, label="", width=80, height=30)
    # Test: same button followed by a hidden one
    with dcg.HorizontalLayout(ctx, parent=window) as test:
        dcg.Button(ctx, label="", width=80, height=30)
        dcg.Button(ctx, label="", width=80, height=30, show=False)
    _render(ctx.viewport)

    assert abs(test.state.rect_size.x - ref.state.rect_size.x) <= 1, (
        f"Hidden last item: layout width {test.state.rect_size.x} "
        f"should equal single-button width {ref.state.rect_size.x}"
    )


def test_hlayout_left_no_wrap_all_hidden(vp_ctx):
    """HLayout LEFT+no_wrap: all items hidden → layout rect_size is (0, 0)."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.HorizontalLayout(ctx, parent=window) as layout:
        dcg.Button(ctx, label="", width=80, height=30, show=False)
        dcg.Button(ctx, label="", width=80, height=30, show=False)
    _render(ctx.viewport)

    # When all children are hidden, HLayout's width = available content width (not 0)
    # because the Group still measures available space; only height is 0.
    assert layout.state.rect_size.y == 0, (
        f"All hidden: layout height={layout.state.rect_size.y} should be 0"
    )
    assert layout.state.rect_size.x > 0, (
        f"All hidden: layout width={layout.state.rect_size.x} should be > 0 (available content width)"
    )


def test_hlayout_left_wrap_hidden_item_no_spurious_wrap(vp_ctx):
    """HLayout LEFT+wrap: hidden middle item does not affect wrapping decisions."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    _render(ctx.viewport)
    content_w = window.state.content_region_avail[0]
    # Each visible item is ~45% of content_w; b1 and b2 fit on one row together.
    # The hidden item has the same nominal width but is invisible → should not cause a wrap.
    item_w = str(int(content_w * 0.45))
    with dcg.HorizontalLayout(ctx, no_wrap=False, parent=window):
        b1 = dcg.Button(ctx, label="", width=item_w, height=30)
        dcg.Button(ctx, label="", width=item_w, height=30, show=False)
        b2 = dcg.Button(ctx, label="", width=item_w, height=30)
    _render(ctx.viewport)

    # b1 and b2 must be on the same row (same y)
    assert b1.state.pos_to_parent.y == b2.state.pos_to_parent.y, (
        f"Hidden middle: b1 y={b1.state.pos_to_parent.y}, "
        f"b2 y={b2.state.pos_to_parent.y} should be on the same row"
    )
    # b2 must be to the right of b1
    assert b2.state.pos_to_parent.x > b1.state.pos_to_parent.x, (
        f"Hidden middle: b2 x={b2.state.pos_to_parent.x} should be > b1 x={b1.state.pos_to_parent.x}"
    )


def test_hlayout_left_wrap_stale_hidden_item_no_spurious_wrap(vp_ctx):
    """
    HLayout LEFT+wrap: an item that was visible (stale large rect_size) and then
    hidden must not trigger a spurious line-break for the following item.

    Unlike test_hlayout_left_wrap_hidden_item_no_spurious_wrap, here b_hidden is
    first rendered visible so its rect_size is recorded, then hidden.  Its stale
    rect_size is large enough to overflow when combined with b1, so the wrap-check
    fires on the hidden item.  The layout must absorb this and keep b2 on the same
    row as b1.
    """
    ctx = vp_ctx
    window = _stable_window(ctx)
    _render(ctx.viewport)
    content_w = window.state.content_region_avail[0]
    # b_hidden is 70% wide — combined with b1 (40%) it overflows end_x.
    small_w = str(int(content_w * 0.40))
    large_w = str(int(content_w * 0.70))
    with dcg.HorizontalLayout(ctx, no_wrap=False, parent=window):
        b1 = dcg.Button(ctx, label="", width=small_w, height=30)
        b_hidden = dcg.Button(ctx, label="", width=large_w, height=30)
        b2 = dcg.Button(ctx, label="", width=small_w, height=30)
    # Establish sizes with b_hidden visible so rect_size is recorded as large.
    _render(ctx.viewport)
    # Now hide it; its stale rect_size still reflects the 70% width.
    b_hidden.show = False
    _render(ctx.viewport)

    # b1 and b2 must be on the same row despite the stale large rect_size.
    assert b1.state.pos_to_parent.y == b2.state.pos_to_parent.y, (
        f"Stale-hidden overflow: b1 y={b1.state.pos_to_parent.y}, "
        f"b2 y={b2.state.pos_to_parent.y} should be on the same row"
    )
    # b2 must be placed to the right of b1 with a single ItemSpacing gap.
    assert b2.state.pos_to_parent.x > b1.state.pos_to_parent.x, (
        f"Stale-hidden overflow: b2 x={b2.state.pos_to_parent.x} "
        f"should be > b1 x={b1.state.pos_to_parent.x}"
    )


# ---------------------------------------------------------------------------
# Phase 3 — HorizontalLayout ALIGNED modes, special items
# ---------------------------------------------------------------------------

def test_hlayout_right_item_tooltip_item_spacing(vp_ctx):
    """HLayout RIGHT: Tooltip excluded from pre-pass; visible item positions unchanged."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    # Reference: two buttons RIGHT-aligned
    with dcg.HorizontalLayout(ctx, alignment_mode=dcg.Alignment.RIGHT, parent=window):
        rb1 = dcg.Button(ctx, label="", width=80, height=30)
        rb2 = dcg.Button(ctx, label="", width=80, height=30)
    # Test: same buttons with a Tooltip between them
    with dcg.HorizontalLayout(ctx, alignment_mode=dcg.Alignment.RIGHT, parent=window):
        tb1 = dcg.Button(ctx, label="", width=80, height=30)
        dcg.Tooltip(ctx)
        tb2 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    assert abs(tb1.state.pos_to_parent.x - rb1.state.pos_to_parent.x) <= 1, (
        f"RIGHT+tooltip: tb1 x={tb1.state.pos_to_parent.x} "
        f"should match ref rb1={rb1.state.pos_to_parent.x}"
    )
    assert abs(tb2.state.pos_to_parent.x - rb2.state.pos_to_parent.x) <= 1, (
        f"RIGHT+tooltip: tb2 x={tb2.state.pos_to_parent.x} "
        f"should match ref rb2={rb2.state.pos_to_parent.x}"
    )


def test_hlayout_center_tooltip_excluded_from_centering(vp_ctx):
    """HLayout CENTER: leading Tooltip does not shift the centered group."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    # Reference: two buttons, CENTER alignment
    with dcg.HorizontalLayout(ctx, alignment_mode=dcg.Alignment.CENTER, parent=window):
        rb1 = dcg.Button(ctx, label="", width=80, height=30)
        rb2 = dcg.Button(ctx, label="", width=80, height=30)
    # Test: tooltip before the first button
    with dcg.HorizontalLayout(ctx, alignment_mode=dcg.Alignment.CENTER, parent=window):
        dcg.Tooltip(ctx)
        tb1 = dcg.Button(ctx, label="", width=80, height=30)
        tb2 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    assert abs(tb1.state.pos_to_parent.x - rb1.state.pos_to_parent.x) <= 1, (
        f"CENTER+leading tooltip: tb1 x={tb1.state.pos_to_parent.x} "
        f"should match ref rb1={rb1.state.pos_to_parent.x}"
    )


def test_hlayout_justified_single_visible_item_with_tooltips(vp_ctx):
    """HLayout JUSTIFIED: single visible item flanked by Tooltips → item at left edge."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.HorizontalLayout(ctx, alignment_mode=dcg.Alignment.JUSTIFIED, parent=window):
        dcg.Tooltip(ctx)
        b1 = dcg.Button(ctx, label="", width=80, height=30)
        dcg.Tooltip(ctx)
    _render(ctx.viewport)

    # n_with_size == 1: JUSTIFIED target_x = row_sx = 0 (no stretch applied)
    assert b1.state.pos_to_parent.x == 0, (
        f"JUSTIFIED single visible item: b1 x={b1.state.pos_to_parent.x} should be 0"
    )


def test_hlayout_right_snap_with_trailing_tooltip(vp_ctx):
    """HLayout RIGHT: snap-to-right-edge works when last child is a Tooltip."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    _render(ctx.viewport)
    content_w = window.state.content_region_avail.x 
    with dcg.HorizontalLayout(ctx, alignment_mode=dcg.Alignment.RIGHT, parent=window):
        b1 = dcg.Button(ctx, label="", width=80, height=30)
        b2 = dcg.Button(ctx, label="", width=80, height=30)
        dcg.Tooltip(ctx)   # trailing tooltip after the last visible item
    _render(ctx.viewport)

    last_right = b2.state.pos_to_parent.x + b2.state.rect_size.x
    assert abs(last_right - content_w) <= 1, (
        f"RIGHT snap+trailing tooltip: last right={last_right} should ≈ content_w={content_w}"
    )


def test_hlayout_right_hidden_item_alignment(vp_ctx):
    """HLayout RIGHT: hidden item must not affect the alignment of visible items."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    # Reference: two visible buttons RIGHT-aligned
    with dcg.HorizontalLayout(ctx, alignment_mode=dcg.Alignment.RIGHT, parent=window):
        rb1 = dcg.Button(ctx, label="", width=80, height=30)
        rb2 = dcg.Button(ctx, label="", width=80, height=30)
    # Test: same buttons with a hidden button between them
    with dcg.HorizontalLayout(ctx, alignment_mode=dcg.Alignment.RIGHT, parent=window):
        tb1 = dcg.Button(ctx, label="", width=80, height=30)
        dcg.Button(ctx, label="", width=80, height=30, show=False)
        tb2 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    assert abs(tb1.state.pos_to_parent.x - rb1.state.pos_to_parent.x) <= 1, (
        f"RIGHT+hidden: tb1 x={tb1.state.pos_to_parent.x} "
        f"should match ref rb1={rb1.state.pos_to_parent.x}"
    )
    assert abs(tb2.state.pos_to_parent.x - rb2.state.pos_to_parent.x) <= 1, (
        f"RIGHT+hidden: tb2 x={tb2.state.pos_to_parent.x} "
        f"should match ref rb2={rb2.state.pos_to_parent.x}"
    )


# ---------------------------------------------------------------------------
# Phase 4 — VerticalLayout, zero-size items and hidden items
# ---------------------------------------------------------------------------

def test_vlayout_top_no_wrap_item_tooltip_item(vp_ctx):
    """VLayout TOP+no_wrap: Tooltip between items adds no vertical gap."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    # Reference: two adjacent buttons
    with dcg.VerticalLayout(ctx, parent=window):
        rb1 = dcg.Button(ctx, label="", width=80, height=30)
        rb2 = dcg.Button(ctx, label="", width=80, height=30)
    # Test: same buttons with a tooltip between them
    with dcg.VerticalLayout(ctx, parent=window):
        tb1 = dcg.Button(ctx, label="", width=80, height=30)
        dcg.Tooltip(ctx)
        tb2 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    ref_gap = (rb2.state.pos_to_parent.y
               - rb1.state.pos_to_parent.y - rb1.state.rect_size.y)
    test_gap = (tb2.state.pos_to_parent.y
                - tb1.state.pos_to_parent.y - tb1.state.rect_size.y)
    assert abs(test_gap - ref_gap) <= 1, (
        f"VLayout TOP item+tooltip+item: vertical gap={test_gap} should equal ref={ref_gap}"
    )


def test_vlayout_top_no_wrap_item_hidden_item(vp_ctx):
    """VLayout TOP+no_wrap: hidden middle item adds no vertical gap."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    # Reference: two adjacent buttons
    with dcg.VerticalLayout(ctx, parent=window):
        rb1 = dcg.Button(ctx, label="", width=80, height=30)
        rb2 = dcg.Button(ctx, label="", width=80, height=30)
    # Test: hidden button between them
    with dcg.VerticalLayout(ctx, parent=window):
        tb1 = dcg.Button(ctx, label="", width=80, height=30)
        dcg.Button(ctx, label="", width=80, height=30, show=False)
        tb2 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    ref_gap = (rb2.state.pos_to_parent.y
               - rb1.state.pos_to_parent.y - rb1.state.rect_size.y)
    test_gap = (tb2.state.pos_to_parent.y
                - tb1.state.pos_to_parent.y - tb1.state.rect_size.y)
    assert abs(test_gap - ref_gap) <= 1, (
        f"VLayout TOP item+hidden+item: vertical gap={test_gap} should equal ref={ref_gap}"
    )


def test_vlayout_bottom_tooltip_excluded_from_height_calc(vp_ctx):
    """VLayout BOTTOM: Tooltip between items excluded from column height; last item at bottom."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.VerticalLayout(ctx, alignment_mode=dcg.Alignment.BOTTOM, parent=window) as layout:
        tb1 = dcg.Button(ctx, label="", width=80, height=30)
        dcg.Tooltip(ctx)
        tb2 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    # Items must be vertically ordered
    assert tb1.state.pos_to_parent.y < tb2.state.pos_to_parent.y, (
        f"BOTTOM+tooltip: tb1 y={tb1.state.pos_to_parent.y} should be < tb2 y={tb2.state.pos_to_parent.y}"
    )
    # Last visible item's bottom edge must align with the layout's content bottom
    layout_h = layout.state.content_region_avail.y
    last_bottom = tb2.state.pos_to_parent.y + tb2.state.rect_size.y
    assert abs(last_bottom - layout_h) <= 1, (
        f"BOTTOM+tooltip: last bottom={last_bottom} should ≈ layout_h={layout_h}"
    )


# ---------------------------------------------------------------------------
# Phase 1 addendum — VerticalLayout TOP+no_wrap, zero-size items (Tooltip)
# ---------------------------------------------------------------------------

def test_vlayout_top_no_wrap_tooltip_as_first_child(vp_ctx):
    """VLayout TOP+no_wrap: leading Tooltip does not shift first visible item from y=0."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.VerticalLayout(ctx, parent=window):
        dcg.Tooltip(ctx)
        b1 = dcg.Button(ctx, label="", width=80, height=30)
        b2 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    assert b1.state.pos_to_parent.y == 0, (
        f"Leading tooltip: first button y={b1.state.pos_to_parent.y} should be 0"
    )
    gap = b2.state.pos_to_parent.y - (b1.state.pos_to_parent.y + b1.state.rect_size.y)
    assert gap > 0, (
        f"Leading tooltip: gap between b1 and b2 should be > 0, got {gap}"
    )


def test_vlayout_top_no_wrap_tooltip_as_last_child(vp_ctx):
    """VLayout TOP+no_wrap: trailing Tooltip does not inflate the layout rect_size."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    # Reference: two buttons with no trailing tooltip
    with dcg.VerticalLayout(ctx, parent=window) as ref:
        dcg.Button(ctx, label="", width=80, height=30)
        dcg.Button(ctx, label="", width=80, height=30)
    # Test: same buttons followed by a Tooltip
    with dcg.VerticalLayout(ctx, parent=window) as test:
        dcg.Button(ctx, label="", width=80, height=30)
        dcg.Button(ctx, label="", width=80, height=30)
        dcg.Tooltip(ctx)
    _render(ctx.viewport)

    assert abs(test.state.rect_size.y - ref.state.rect_size.y) <= 1, (
        f"Trailing tooltip: layout height {test.state.rect_size.y} "
        f"should match no-tooltip height {ref.state.rect_size.y}"
    )


def test_vlayout_top_no_wrap_multiple_consecutive_tooltips(vp_ctx):
    """VLayout TOP+no_wrap: multiple consecutive Tooltips between items don't add spacing."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    # Reference: two adjacent buttons
    with dcg.VerticalLayout(ctx, parent=window):
        rb1 = dcg.Button(ctx, label="", width=80, height=30)
        rb2 = dcg.Button(ctx, label="", width=80, height=30)
    # Test: three tooltips between the same two buttons
    with dcg.VerticalLayout(ctx, parent=window):
        tb1 = dcg.Button(ctx, label="", width=80, height=30)
        dcg.Tooltip(ctx)
        dcg.Tooltip(ctx)
        dcg.Tooltip(ctx)
        tb2 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    ref_gap = (rb2.state.pos_to_parent.y
               - rb1.state.pos_to_parent.y - rb1.state.rect_size.y)
    test_gap = (tb2.state.pos_to_parent.y
                - tb1.state.pos_to_parent.y - tb1.state.rect_size.y)
    assert abs(test_gap - ref_gap) <= 1, (
        f"3 consecutive tooltips: gap={test_gap} should equal ref gap={ref_gap}"
    )


# ---------------------------------------------------------------------------
# Phase 2 — VerticalLayout TOP+wrap, zero-size items (Tooltip)
# ---------------------------------------------------------------------------

def test_vlayout_top_wrap_item_tooltip_item_spacing(vp_ctx):
    """VLayout TOP+wrap: Tooltip between items should preserve spacing_y."""
    ctx = vp_ctx
    ref_window = _stable_window(ctx)
    test_window = _stable_window(ctx)
    # Reference: two adjacent buttons, wrapping enabled
    with dcg.VerticalLayout(ctx, wrap=True, parent=ref_window):
        rb1 = dcg.Button(ctx, label="", width=80, height=30)
        rb2 = dcg.Button(ctx, label="", width=80, height=30)
    # Test: same buttons with a tooltip between them
    with dcg.VerticalLayout(ctx, wrap=True, parent=test_window):
        tb1 = dcg.Button(ctx, label="", width=80, height=30)
        dcg.Tooltip(ctx)
        tb2 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    ref_gap = (rb2.state.pos_to_parent.y
               - rb1.state.pos_to_parent.y - rb1.state.rect_size.y)
    test_gap = (tb2.state.pos_to_parent.y
                - tb1.state.pos_to_parent.y - tb1.state.rect_size.y)
    assert abs(test_gap - ref_gap) <= 1, (
        f"TOP+wrap item+tooltip+item: gap={test_gap} should equal ref gap={ref_gap}"
    )


# ---------------------------------------------------------------------------
# Phase 3 — VerticalLayout TOP+no_wrap, hidden items (show=False)
# ---------------------------------------------------------------------------

def test_vlayout_top_no_wrap_first_item_hidden(vp_ctx):
    """VLayout TOP+no_wrap: hidden first item → second item starts at y=0."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.VerticalLayout(ctx, parent=window):
        dcg.Button(ctx, label="", width=80, height=30, show=False)
        b2 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    assert b2.state.pos_to_parent.y == 0, (
        f"Hidden first item: second button y={b2.state.pos_to_parent.y} should be 0"
    )


def test_vlayout_top_no_wrap_last_item_hidden_layout_height(vp_ctx):
    """VLayout TOP+no_wrap: hidden last item does not inflate layout rect_size."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    # Reference: one visible button
    with dcg.VerticalLayout(ctx, parent=window) as ref:
        dcg.Button(ctx, label="", width=80, height=30)
    # Test: same button followed by a hidden one
    with dcg.VerticalLayout(ctx, parent=window) as test:
        dcg.Button(ctx, label="", width=80, height=30)
        dcg.Button(ctx, label="", width=80, height=30, show=False)
    _render(ctx.viewport)

    assert abs(test.state.rect_size.y - ref.state.rect_size.y) <= 1, (
        f"Hidden last item: layout height {test.state.rect_size.y} "
        f"should equal single-button height {ref.state.rect_size.y}"
    )


def test_vlayout_top_no_wrap_all_hidden(vp_ctx):
    """VLayout TOP+no_wrap: all items hidden → layout height is 0."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.VerticalLayout(ctx, parent=window) as layout:
        dcg.Button(ctx, label="", width=80, height=30, show=False)
        dcg.Button(ctx, label="", width=80, height=30, show=False)
    _render(ctx.viewport)

    assert layout.state.rect_size.y == 0, (
        f"All hidden: layout height={layout.state.rect_size.y} should be 0"
    )


# ---------------------------------------------------------------------------
# Phase 4 — VerticalLayout TOP+wrap, hidden items (show=False)
# ---------------------------------------------------------------------------

def test_vlayout_top_wrap_hidden_item_no_spurious_wrap(vp_ctx):
    """VLayout TOP+wrap: hidden middle item does not affect wrapping decisions."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    _render(ctx.viewport)
    content_h = window.state.content_region_avail[1]
    # Each visible item is ~45% of content_h; b1 and b2 fit in one column together.
    # The hidden item has the same nominal height but is invisible → should not cause a wrap.
    item_h = str(int(content_h * 0.45))
    with dcg.VerticalLayout(ctx, wrap=True, parent=window):
        b1 = dcg.Button(ctx, label="", width=80, height=item_h)
        dcg.Button(ctx, label="", width=80, height=item_h, show=False)
        b2 = dcg.Button(ctx, label="", width=80, height=item_h)
    _render(ctx.viewport)

    # b1 and b2 must be in the same column (same x)
    assert b1.state.pos_to_parent.x == b2.state.pos_to_parent.x, (
        f"Hidden middle: b1 x={b1.state.pos_to_parent.x}, "
        f"b2 x={b2.state.pos_to_parent.x} should be in the same column"
    )
    # b2 must be below b1
    assert b2.state.pos_to_parent.y > b1.state.pos_to_parent.y, (
        f"Hidden middle: b2 y={b2.state.pos_to_parent.y} should be > b1 y={b1.state.pos_to_parent.y}"
    )


def test_vlayout_top_wrap_stale_hidden_item_no_spurious_wrap(vp_ctx):
    """
    VLayout TOP+wrap: an item that was visible (stale large rect_size) and then hidden
    must not trigger a spurious column-break for the following item.

    b_hidden is first rendered visible so its rect_size is recorded as large, then hidden.
    Its stale rect_size combined with b1 exceeds end_y, so without the traversed guard the
    wrap-check would fire and push b2 to a new column.  The layout must absorb this and keep
    b2 in the same column as b1.
    """
    ctx = vp_ctx
    window = _stable_window(ctx)
    _render(ctx.viewport)
    content_h = window.state.content_region_avail[1]
    # b_hidden is 70% tall — combined with b1 (40%) it overflows end_y.
    small_h = str(int(content_h * 0.40))
    large_h = str(int(content_h * 0.70))
    with dcg.VerticalLayout(ctx, wrap=True, parent=window):
        b1 = dcg.Button(ctx, label="", width=80, height=small_h)
        b_hidden = dcg.Button(ctx, label="", width=80, height=large_h)
        b2 = dcg.Button(ctx, label="", width=80, height=small_h)
    # Establish sizes with b_hidden visible so rect_size is recorded as large.
    _render(ctx.viewport)
    # Now hide it; its stale rect_size still reflects the 70% height.
    b_hidden.show = False
    _render(ctx.viewport)

    # b1 and b2 must be in the same column (same x) despite the stale large rect_size.
    assert b1.state.pos_to_parent.x == b2.state.pos_to_parent.x, (
        f"Stale-hidden overflow: b1 x={b1.state.pos_to_parent.x}, "
        f"b2 x={b2.state.pos_to_parent.x} should be in the same column"
    )
    # b2 must be placed below b1
    assert b2.state.pos_to_parent.y > b1.state.pos_to_parent.y, (
        f"Stale-hidden overflow: b2 y={b2.state.pos_to_parent.y} "
        f"should be > b1 y={b1.state.pos_to_parent.y}"
    )


# ---------------------------------------------------------------------------
# Phase 5 — VerticalLayout ALIGNED modes, special items
# ---------------------------------------------------------------------------

def test_vlayout_bottom_item_tooltip_item_spacing(vp_ctx):
    """VLayout BOTTOM: Tooltip excluded from pre-pass; visible item positions unchanged."""
    ctx = vp_ctx
    ref_window = _stable_window(ctx)
    test_window = _stable_window(ctx)
    # Reference: two buttons BOTTOM-aligned
    with dcg.VerticalLayout(ctx, alignment_mode=dcg.Alignment.BOTTOM, parent=ref_window):
        rb1 = dcg.Button(ctx, label="", width=80, height=30)
        rb2 = dcg.Button(ctx, label="", width=80, height=30)
    # Test: same buttons with a Tooltip between them
    with dcg.VerticalLayout(ctx, alignment_mode=dcg.Alignment.BOTTOM, parent=test_window):
        tb1 = dcg.Button(ctx, label="", width=80, height=30)
        dcg.Tooltip(ctx)
        tb2 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    assert abs(tb1.state.pos_to_parent.y - rb1.state.pos_to_parent.y) <= 1, (
        f"BOTTOM+tooltip: tb1 y={tb1.state.pos_to_parent.y} "
        f"should match ref rb1={rb1.state.pos_to_parent.y}"
    )
    assert abs(tb2.state.pos_to_parent.y - rb2.state.pos_to_parent.y) <= 1, (
        f"BOTTOM+tooltip: tb2 y={tb2.state.pos_to_parent.y} "
        f"should match ref rb2={rb2.state.pos_to_parent.y}"
    )


def test_vlayout_center_tooltip_excluded_from_centering(vp_ctx):
    """VLayout CENTER: leading Tooltip does not shift the centered group."""
    ctx = vp_ctx
    ref_window = _stable_window(ctx)
    test_window = _stable_window(ctx)
    # Reference: two buttons, CENTER alignment
    with dcg.VerticalLayout(ctx, alignment_mode=dcg.Alignment.CENTER, parent=ref_window):
        rb1 = dcg.Button(ctx, label="", width=80, height=30)
        rb2 = dcg.Button(ctx, label="", width=80, height=30)
    # Test: tooltip before the first button
    with dcg.VerticalLayout(ctx, alignment_mode=dcg.Alignment.CENTER, parent=test_window):
        dcg.Tooltip(ctx)
        tb1 = dcg.Button(ctx, label="", width=80, height=30)
        tb2 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    assert abs(tb1.state.pos_to_parent.y - rb1.state.pos_to_parent.y) <= 1, (
        f"CENTER+leading tooltip: tb1 y={tb1.state.pos_to_parent.y} "
        f"should match ref rb1={rb1.state.pos_to_parent.y}"
    )


def test_vlayout_justified_single_visible_item_with_tooltips(vp_ctx):
    """VLayout JUSTIFIED: single visible item flanked by Tooltips → item at top edge."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    with dcg.VerticalLayout(ctx, alignment_mode=dcg.Alignment.JUSTIFIED, parent=window):
        dcg.Tooltip(ctx)
        b1 = dcg.Button(ctx, label="", width=80, height=30)
        dcg.Tooltip(ctx)
    _render(ctx.viewport)

    # n_with_size == 1: JUSTIFIED target_y = col_sy = 0 (no stretch applied)
    assert b1.state.pos_to_parent.y == 0, (
        f"JUSTIFIED single visible item: b1 y={b1.state.pos_to_parent.y} should be 0"
    )


def test_vlayout_bottom_snap_with_trailing_tooltip(vp_ctx):
    """VLayout BOTTOM: snap-to-bottom works when last child is a Tooltip."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    _render(ctx.viewport)
    with dcg.VerticalLayout(ctx, alignment_mode=dcg.Alignment.BOTTOM, parent=window) as layout:
        b1 = dcg.Button(ctx, label="", width=80, height=30)
        b2 = dcg.Button(ctx, label="", width=80, height=30)
        dcg.Tooltip(ctx)   # trailing tooltip after the last visible item
    _render(ctx.viewport)

    layout_h = layout.state.content_region_avail.y
    last_bottom = b2.state.pos_to_parent.y + b2.state.rect_size.y
    assert abs(last_bottom - layout_h) <= 1, (
        f"BOTTOM snap+trailing tooltip: last bottom={last_bottom} should ≈ layout_h={layout_h}"
    )


def test_vlayout_bottom_hidden_item_alignment(vp_ctx):
    """VLayout BOTTOM: hidden item must not affect the alignment of visible items."""
    ctx = vp_ctx
    ref_window = _stable_window(ctx)
    test_window = _stable_window(ctx)
    # Reference: two visible buttons BOTTOM-aligned
    with dcg.VerticalLayout(ctx, alignment_mode=dcg.Alignment.BOTTOM, parent=ref_window):
        rb1 = dcg.Button(ctx, label="", width=80, height=30)
        rb2 = dcg.Button(ctx, label="", width=80, height=30)
    # Test: same buttons with a hidden button between them
    with dcg.VerticalLayout(ctx, alignment_mode=dcg.Alignment.BOTTOM, parent=test_window):
        tb1 = dcg.Button(ctx, label="", width=80, height=30)
        dcg.Button(ctx, label="", width=80, height=30, show=False)
        tb2 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    assert abs(tb1.state.pos_to_parent.y - rb1.state.pos_to_parent.y) <= 1, (
        f"BOTTOM+hidden: tb1 y={tb1.state.pos_to_parent.y} "
        f"should match ref rb1={rb1.state.pos_to_parent.y}"
    )
    assert abs(tb2.state.pos_to_parent.y - rb2.state.pos_to_parent.y) <= 1, (
        f"BOTTOM+hidden: tb2 y={tb2.state.pos_to_parent.y} "
        f"should match ref rb2={rb2.state.pos_to_parent.y}"
    )


# ---------------------------------------------------------------------------
# VLayout wrapping disabled explicit test
# ---------------------------------------------------------------------------

def test_vlayout_wrapping_disabled(vp_ctx):
    """VerticalLayout default (no wrap): items stay in one column even if they overflow."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    _render(ctx.viewport)
    content_h = window.state.content_region_avail[1]
    item_h = int(content_h * 0.4)
    with dcg.VerticalLayout(ctx, parent=window):
        b1 = dcg.Button(ctx, label="", width=80, height=item_h)
        b2 = dcg.Button(ctx, label="", width=80, height=item_h)
        b3 = dcg.Button(ctx, label="", width=80, height=item_h)
    _render(ctx.viewport)

    # All items in the same column (x coordinate equal)
    p1_x = b1.state.pos_to_parent[0]
    p2_x = b2.state.pos_to_parent[0]
    p3_x = b3.state.pos_to_parent[0]
    assert p1_x == p2_x == p3_x, (
        f"no wrap: all items in same column, got x={p1_x},{p2_x},{p3_x}"
    )
    # Items ordered top-to-bottom even beyond content height
    p1_y, p2_y, p3_y = [b.state.pos_to_parent[1] for b in (b1, b2, b3)]
    assert p1_y < p2_y < p3_y


# ---------------------------------------------------------------------------
# HLayout CENTER and JUSTIFIED with hidden items (Phase 5 addendum)
# ---------------------------------------------------------------------------

def test_hlayout_center_hidden_item_alignment(vp_ctx):
    """HLayout CENTER: hidden item must not affect the centering of visible items."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    # Reference: two visible buttons CENTER-aligned
    with dcg.HorizontalLayout(ctx, alignment_mode=dcg.Alignment.CENTER, parent=window):
        rb1 = dcg.Button(ctx, label="", width=80, height=30)
        rb2 = dcg.Button(ctx, label="", width=80, height=30)
    # Test: same buttons with a hidden button between them
    with dcg.HorizontalLayout(ctx, alignment_mode=dcg.Alignment.CENTER, parent=window):
        tb1 = dcg.Button(ctx, label="", width=80, height=30)
        dcg.Button(ctx, label="", width=80, height=30, show=False)
        tb2 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    assert abs(tb1.state.pos_to_parent.x - rb1.state.pos_to_parent.x) <= 1, (
        f"CENTER+hidden: tb1 x={tb1.state.pos_to_parent.x} "
        f"should match ref rb1={rb1.state.pos_to_parent.x}"
    )
    assert abs(tb2.state.pos_to_parent.x - rb2.state.pos_to_parent.x) <= 1, (
        f"CENTER+hidden: tb2 x={tb2.state.pos_to_parent.x} "
        f"should match ref rb2={rb2.state.pos_to_parent.x}"
    )


def test_hlayout_justified_hidden_item_alignment(vp_ctx):
    """HLayout JUSTIFIED: hidden item must not affect the justification of visible items."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    # Reference: two visible buttons JUSTIFIED-aligned
    with dcg.HorizontalLayout(ctx, alignment_mode=dcg.Alignment.JUSTIFIED, parent=window):
        rb1 = dcg.Button(ctx, label="", width=80, height=30)
        rb2 = dcg.Button(ctx, label="", width=80, height=30)
    # Test: same buttons with a hidden button between them
    with dcg.HorizontalLayout(ctx, alignment_mode=dcg.Alignment.JUSTIFIED, parent=window):
        tb1 = dcg.Button(ctx, label="", width=80, height=30)
        dcg.Button(ctx, label="", width=80, height=30, show=False)
        tb2 = dcg.Button(ctx, label="", width=80, height=30)
    _render(ctx.viewport)

    assert abs(tb1.state.pos_to_parent.x - rb1.state.pos_to_parent.x) <= 1, (
        f"JUSTIFIED+hidden: tb1 x={tb1.state.pos_to_parent.x} "
        f"should match ref rb1={rb1.state.pos_to_parent.x}"
    )
    assert abs(tb2.state.pos_to_parent.x - rb2.state.pos_to_parent.x) <= 1, (
        f"JUSTIFIED+hidden: tb2 x={tb2.state.pos_to_parent.x} "
        f"should match ref rb2={rb2.state.pos_to_parent.x}"
    )


# ---------------------------------------------------------------------------
# Regression: RIGHT HLayout with interleaved Tooltip + Spacer
#
# Pattern from real user code:
#   ProgressBar → Tooltip → Spacer → ProgressBar → Tooltip → Spacer →
#   ProgressBar → Tooltip
#
# The last ProgressBar must snap to the right edge (right edge ≈ content_w).
# A reference layout with NO tooltips must produce identical item positions
# because Tooltips have has_rect_size=False and must not disturb the spacing
# chain or the RIGHT snap logic.
# ---------------------------------------------------------------------------

def test_hlayout_right_tooltip_spacer_interleaved_last_right_snap(vp_ctx):
    """RIGHT HLayout: item→Tooltip→Spacer pattern must not push the last item past end_x."""
    ctx = vp_ctx
    window = _stable_window(ctx)
    _render(ctx.viewport)
    content_w = window.state.content_region_avail[0]

    BAR_W   = 80
    SPACE_W = 20

    # Reference layout: same visible items (ProgressBars + Spacers), no Tooltips.
    # Used to confirm Tooltips do not alter item positions.
    with dcg.HorizontalLayout(
        ctx,
        alignment_mode=dcg.Alignment.RIGHT,
        no_wrap=True,
        parent=window,
    ):
        ref_pb1 = dcg.ProgressBar(ctx, value=0.3, width=BAR_W, height=20)
        ref_sp1 = dcg.Spacer(ctx, width=SPACE_W)
        ref_pb2 = dcg.ProgressBar(ctx, value=0.6, width=BAR_W, height=20)
        ref_sp2 = dcg.Spacer(ctx, width=SPACE_W)
        ref_pb3 = dcg.ProgressBar(ctx, value=0.9, width=BAR_W, height=20)

    # Test layout: same items with a Tooltip after each ProgressBar.
    with dcg.HorizontalLayout(
        ctx,
        alignment_mode=dcg.Alignment.RIGHT,
        no_wrap=True,
        parent=window,
    ):
        pb1 = dcg.ProgressBar(ctx, value=0.3, width=BAR_W, height=20)
        with dcg.Tooltip(ctx):
            dcg.Text(ctx, value="CPU Usage")
        sp1 = dcg.Spacer(ctx, width=SPACE_W)
        pb2 = dcg.ProgressBar(ctx, value=0.6, width=BAR_W, height=20)
        with dcg.Tooltip(ctx):
            dcg.Text(ctx, value="FPS")
        sp2 = dcg.Spacer(ctx, width=SPACE_W)
        pb3 = dcg.ProgressBar(ctx, value=0.9, width=BAR_W, height=20)
        with dcg.Tooltip(ctx):
            dcg.Text(ctx, value="Max FPS")

    # Extra frames so all sizes stabilise and the RIGHT snap fires.
    _render(ctx.viewport, n=20)

    # The last ProgressBar's right edge must reach content_w (RIGHT alignment).
    last_right = pb3.state.pos_to_parent[0] + pb3.state.rect_size[0]
    assert abs(last_right - content_w) <= 1, (
        f"RIGHT+Tooltip+Spacer: last pb3 right {last_right} "
        f"should be at content_w {content_w}"
    )

    # Intermediate items must be strictly ordered (no overlap).
    x_pb1, x_sp1, x_pb2, x_sp2, x_pb3 = (
        pb1.state.pos_to_parent[0],
        sp1.state.pos_to_parent[0],
        pb2.state.pos_to_parent[0],
        sp2.state.pos_to_parent[0],
        pb3.state.pos_to_parent[0],
    )
    assert x_pb1 < x_sp1 < x_pb2 < x_sp2 < x_pb3, (
        f"RIGHT+Tooltip+Spacer: items not ordered: "
        f"pb1={x_pb1} sp1={x_sp1} pb2={x_pb2} sp2={x_sp2} pb3={x_pb3}"
    )

    # Tooltips must not shift item positions: compare against the reference layout.
    for name, test_item, ref_item in (
        ("pb1", pb1, ref_pb1),
        ("sp1", sp1, ref_sp1),
        ("pb2", pb2, ref_pb2),
        ("sp2", sp2, ref_sp2),
        ("pb3", pb3, ref_pb3),
    ):
        tx = test_item.state.pos_to_parent[0]
        rx = ref_item.state.pos_to_parent[0]
        assert abs(tx - rx) <= 1, (
            f"RIGHT+Tooltip+Spacer: {name} x={tx} should match "
            f"reference x={rx} (Tooltips must not shift positions)"
        )