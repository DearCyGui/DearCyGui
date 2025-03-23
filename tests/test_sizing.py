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