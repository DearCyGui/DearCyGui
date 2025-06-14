
from typing import Union, overload, TypeVar, Literal, NotImplementedType

NumStrT = Union[int, float, str]


class baseSizing:
    """
    Base class for objects that compute frame to frame
    the size of target objects.
    """
    @property
    def freeze(self) -> bool:
        """
        Whether to freeze the size computation (in pixels).
        """
        ...
    
    @freeze.setter
    def freeze(self, value: bool) -> None:
        ...
    
    @property
    def value(self) -> float:
        """
        Last value
        """
        ...
    
    @value.setter
    def value(self, v: float) -> None:
        ...
    
    def __add__(self, other: Union[NumStrT, 'baseSizing']) -> Union[NotImplementedType, 'AddSize']:
        ...
    
    def __sub__(self, other: Union[NumStrT, 'baseSizing']) -> Union[NotImplementedType, 'SubtractSize']:
        ...
    
    def __mul__(self, other: Union[NumStrT, 'baseSizing']) -> Union[NotImplementedType, 'MultiplySize']:
        ...
    
    def __truediv__(self, other: Union[NumStrT, 'baseSizing']) -> Union[NotImplementedType, 'DivideSize']:
        ...
    
    def __floordiv__(self, other: Union[NumStrT, 'baseSizing']) -> Union[NotImplementedType, 'FloorDivideSize']:
        ...
    
    def __mod__(self, other: Union[NumStrT, 'baseSizing']) -> Union[NotImplementedType, 'ModuloSize']:
        ...
    
    def __pow__(self, other: Union[NumStrT, 'baseSizing'], modulo=...) -> Union[NotImplementedType, 'PowerSize']:
        ...
    
    # Right-side operations
    def __radd__(self, other: NumStrT) -> 'AddSize':
        ...
    
    def __rsub__(self, other: NumStrT) -> 'SubtractSize':
        ...
    
    def __rmul__(self, other: NumStrT) -> 'MultiplySize':
        ...
    
    def __rtruediv__(self, other: NumStrT) -> 'DivideSize':
        ...
    
    def __rfloordiv__(self, other: NumStrT) -> 'FloorDivideSize':
        ...
    
    def __rmod__(self, other: NumStrT) -> 'ModuloSize':
        ...
    
    def __rpow__(self, other: NumStrT) -> 'PowerSize':
        ...
    
    def __float__(self: baseSizing) -> float:
        ...
    
    def __int__(self: baseSizing) -> int:
        ...
    
    def __repr__(self) -> str:
        """
        Return a string representation that can be used to recreate the object.
        """
        ...
    
    def __str__(self) -> str:
        """
        Return a human-readable string representation.
        """
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@baseSizing], tuple[float], dict[str, bint]]:
        """
        Support for pickling.
        """
        ...

DynamicSizeT = NumStrT | baseSizing


class FixedSize(baseSizing):
    """
    Fixed size in pixels.
    """
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@FixedSize], tuple[float], dict[str, bint]]:
        ...
    


class DPI(baseSizing):
    """
    Resolves to the current global scale factor.
    """
    def __repr__(self) -> str: # -> Literal['DPI()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@DPI], tuple[()], dict[str, bint]]:
        ...
    


class binarySizeOp(baseSizing):
    """
    Base class for binary operations on size values.
    """
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@binarySizeOp], tuple[baseSizing, baseSizing], dict[str, Any]]:
        ...
    


class MinSize(binarySizeOp):
    """
    Take minimum of two size values.
    """
    def __str__(self) -> str:
        ...
    


class MaxSize(binarySizeOp):
    """
    Take maximum of two size values.
    """
    def __str__(self) -> str:
        ...
    


class AddSize(binarySizeOp):
    """
    Add two size values.
    """
    def __str__(self) -> str:
        ...
    


class SubtractSize(binarySizeOp):
    """
    Subtract one size from another.
    """
    def __str__(self) -> str:
        ...
    


class MultiplySize(binarySizeOp):
    """
    Multiply size values.
    """
    def __str__(self) -> str:
        ...
    


class DivideSize(binarySizeOp):
    """
    Divide size values.
    """
    def __str__(self) -> str:
        ...
    


class FloorDivideSize(binarySizeOp):
    """
    Floor division of size values.
    """
    def __str__(self) -> str:
        ...
    


class ModuloSize(binarySizeOp):
    """
    Modulo operation on size values.
    """
    def __str__(self) -> str:
        ...
    


class PowerSize(binarySizeOp):
    """
    Power operation on size values.
    """
    def __str__(self) -> str:
        ...
    


class NegateSize(baseSizing):
    """
    Negation of a size value.
    """
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@NegateSize], tuple[baseSizing], dict[str, Any]]:
        ...
    


class AbsoluteSize(baseSizing):
    """
    Absolute value of a size value.
    """
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@AbsoluteSize], tuple[baseSizing], dict[str, Any]]:
        ...
    


class FillSizeX(baseSizing):
    """
    Fill available content width.
    """
    def __repr__(self) -> str: # -> Literal['FillSizeX()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@FillSizeX], tuple[()], dict[str, Any]]:
        ...
    


class FillSizeY(baseSizing):
    """
    Fill available content height.
    """
    def __repr__(self) -> str: # -> Literal['FillSizeY()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@FillSizeY], tuple[()], dict[str, Any]]:
        ...
    


class FullSizeX(baseSizing):
    """
    Full parent content width (no position offset subtraction).
    """
    def __repr__(self) -> str: # -> Literal['FullSizeX()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@FullSizeX], tuple[()], dict[str, Any]]:
        ...
    


class FullSizeY(baseSizing):
    """
    Full parent content height (no position offset subtraction).
    """
    def __repr__(self) -> str: # -> Literal['FullSizeY()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@FullSizeY], tuple[()], dict[str, Any]]:
        ...
    


class ParentHeight(baseSizing):
    """
    Parent height. Use fully instead for parent content height
    """
    def __repr__(self) -> str: # -> Literal['ParentHeight()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@ParentHeight], tuple[()], dict[str, bint]]:
        ...
    


class ParentWidth(baseSizing):
    """
    Parent width. Use fullx instead for parent content width
    """
    def __repr__(self) -> str: # -> Literal['ParentWidth()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@ParentWidth], tuple[()], dict[str, bint]]:
        ...
    


class ParentX1(baseSizing):
    """
    Parent left x coordinate (x1).
    """
    def __repr__(self) -> str: # -> Literal['ParentX1()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@ParentX1], tuple[()], dict[str, bint]]:
        ...
    


class ParentX2(baseSizing):
    """
    Parent right x coordinate (x2).
    """
    def __repr__(self) -> str: # -> Literal['ParentX2()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@ParentX2], tuple[()], dict[str, bint]]:
        ...
    


class ParentXC(baseSizing):
    """
    Parent x center coordinate.
    """
    def __repr__(self) -> str: # -> Literal['ParentXC()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@ParentXC], tuple[()], dict[str, bint]]:
        ...
    


class ParentY1(baseSizing):
    """
    Parent top y coordinate (y1).
    """
    def __repr__(self) -> str: # -> Literal['ParentY1()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@ParentY1], tuple[()], dict[str, bint]]:
        ...
    


class ParentY2(baseSizing):
    """
    Parent bottom y coordinate (y2).
    """
    def __repr__(self) -> str: # -> Literal['ParentY2()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@ParentY2], tuple[()], dict[str, bint]]:
        ...
    


class ParentYC(baseSizing):
    """
    Parent y center coordinate.
    """
    def __repr__(self) -> str: # -> Literal['ParentYC()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@ParentYC], tuple[()], dict[str, bint]]:
        ...
    


class RefHeight(baseSizing):
    """
    References another item height.
    """
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    


class RefWidth(baseSizing):
    """
    References another item width.
    """
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    


class RefX1(baseSizing):
    """
    References another item's left x coordinate (x1).
    """
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    


class RefX2(baseSizing):
    """
    References another item's right x coordinate (x2).
    """
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    


class RefXC(baseSizing):
    """
    References another item's x center coordinate.
    """
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    


class RefY1(baseSizing):
    """
    References another item's top y coordinate (y1).
    """
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    


class RefY2(baseSizing):
    """
    References another item's bottom y coordinate (y2).
    """
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    


class RefYC(baseSizing):
    """
    References another item's y center coordinate.
    """
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    


class SelfHeight(baseSizing):
    """
    References the height of the item using this sizing.
    """
    def __repr__(self) -> str: # -> Literal['SelfHeight()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@SelfHeight], tuple[()], dict[str, Any]]:
        ...
    


class SelfWidth(baseSizing):
    """
    References the width of the item using this sizing.
    """
    def __repr__(self) -> str: # -> Literal['SelfWidth()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@SelfWidth], tuple[()], dict[str, Any]]:
        ...
    


class SelfX1(baseSizing):
    """
    References the left x coordinate (x1) of the item using this sizing.
    """
    def __repr__(self) -> str: # -> Literal['SelfX1()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@SelfX1], tuple[()], dict[str, Any]]:
        ...
    


class SelfX2(baseSizing):
    """
    References the right x coordinate (x2) of the item using this sizing.
    """
    def __repr__(self) -> str: # -> Literal['SelfX2()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@SelfX2], tuple[()], dict[str, Any]]:
        ...
    


class SelfXC(baseSizing):
    """
    References the x center coordinate of the item using this sizing.
    """
    def __repr__(self) -> str: # -> Literal['SelfXC()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@SelfXC], tuple[()], dict[str, Any]]:
        ...
    


class SelfY1(baseSizing):
    """
    References the top y coordinate (y1) of the item using this sizing.
    """
    def __repr__(self) -> str: # -> Literal['SelfY1()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@SelfY1], tuple[()], dict[str, Any]]:
        ...
    


class SelfY2(baseSizing):
    """
    References the bottom y coordinate (y2) of the item using this sizing.
    """
    def __repr__(self) -> str: # -> Literal['SelfY2()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@SelfY2], tuple[()], dict[str, Any]]:
        ...
    


class SelfYC(baseSizing):
    """
    References the y center coordinate of the item using this sizing.
    """
    def __repr__(self) -> str: # -> Literal['SelfYC()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@SelfYC], tuple[()], dict[str, Any]]:
        ...
    


class ViewportHeight(baseSizing):
    """
    References the viewport's height.
    """
    def __repr__(self) -> str: # -> Literal['ViewportHeight()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@ViewportHeight], tuple[()], dict[str, Any]]:
        ...
    


class ViewportWidth(baseSizing):
    """
    References the viewport's width.
    """
    def __repr__(self) -> str: # -> Literal['ViewportWidth()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@ViewportWidth], tuple[()], dict[str, Any]]:
        ...
    


def parse_size(size_str: str) -> baseSizing:
    """
    Parse a sizing string into sizing objects
    
    Args:
        size_str: String expression

    Examples:
        "0.8*fillx-4": MultiplySize(FillSizeX(), 0.8) - FixedSize(4)
        "min(0.8*filly, 100)": MinSize(MultiplySize(FillSizeY(), 0.8), FixedSize(100))
        "0.5*self.width": MultiplySize(SelfWidth(), 0.5)
        "0.7*self.height": MultiplySize(SelfHeight(), 0.7)
        "400*dpi": MultiplySize(DPI(), 400)
        "0.8*my_button.width": MultiplySize(RefWidth(my_button), 0.8)

    The following keywords are supported:
    - fillx: Fill available width
    - filly: Fill available height
    - fullx: Full parent width (no position offset)
    - fully: Full parent height (no position offset)
    - min: Take minimum of two size values
    - max: Take maximum of two size values
    - mean: Calculate the mean (average) of two or more size values
    - dpi: Current global scale factor
    - self.width: Reference to the width of the current item
    - self.height: Reference to the height of the current item
    - parent.width/height: Reference to the parent item's size (usually larger than fullx/fully)
    - item.width/item.height: Reference to another item's size (item must be in globals()/locals())
    - For all the above, you can also use x1/x2/y1/y2/xc/yc to retrieve coordinates in viewport space
    - viewport.width/height: Reference to the viewport size
    - +, -, *, /, //, %, **: Arithmetic operators. Parentheses can be used for grouping.
    - abs(): Absolute value function
    - Numbers: Fixed size in pixels (NOT dpi scaled. Use dpi keyword for that)

    Returns:
        A baseSizing object
        
    Raises:
        ValueError: If the expression is empty or invalid
    """
    ...

class Size:
    """
    Factory for creating size descriptors that can be used with width/height properties.
    
    This class provides a clean, user-friendly API for programmatically constructing
    sizing expressions without needing to directly instantiate the underlying sizing classes.
    
    Examples:
        # Fixed size of 100 pixels
        Size.FIXED(100)
        
        # Fill available space
        Size.FILL()
        
        # 80% of available width
        0.8 * Size.FILL())
        
        # Minimum of 50% of parent width and 300 pixels
        Size.MIN(0.5 * Size.FILL(), 300)
        
        # Get current DPI scale
        Size.DPI()
        
        # 500 pixels scaled by DPI
        500 * Size.DPI()
        
        # Reference another item's size
        Size.RELATIVE(my_button)
    """
    @staticmethod
    def FIXED(value: float) -> FixedSize:
        """
        Create a fixed size in pixels.
        
        Args:
            value (float): Size in pixels
            
        Returns:
            FixedSize: Fixed size object
        """
        ...
    
    @staticmethod
    def FILLX() -> FillSizeX:
        """
        Create a size that fills the available width.
        
        Returns:
            FillSizeX: Fill size object
        """
        ...
    
    @staticmethod
    def FILLY() -> FillSizeY:
        """
        Create a size that fills the available height.
        
        Returns:
            FillSizeY: Fill size object
        """
        ...
    
    @staticmethod
    def FULLX() -> FullSizeX:
        """
        Create a size that uses the full parent width (without position offset).
        
        Returns:
            FullSizeX: Full size object
        """
        ...
    
    @staticmethod
    def FULLY() -> FullSizeY:
        """
        Create a size that uses the full parent height (without position offset).
        
        Returns:
            FullSizeY: Full size object
        """
        ...
    
    @staticmethod
    def DPI() -> DPI:
        """
        Create a size that resolves to the current DPI scale factor.
        
        Returns:
            DPI: DPI scale object
        """
        ...
    
    @staticmethod
    def RELATIVEX(item: uiItem) -> RefWidth:
        """
        Create a size relative to another item's width.

        Args:
            item (uiItem): The reference item
            
        Returns:
            baseSizing: Size object relative to the reference item's width
        """
        ...
    
    @staticmethod
    def RELATIVEY(item: uiItem) -> RefHeight:
        """
        Create a size relative to another item's height.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            baseSizing: Size object relative to the reference item's height
        """
        ...
    
    @staticmethod
    def PARENT_WIDTH() -> ParentWidth:
        """
        Create a size that references the parent's width.
        
        Returns:
            ParentWidth: Size object referencing the parent's width
        """
        ...
    
    @staticmethod
    def PARENT_HEIGHT() -> ParentHeight:
        """
        Create a size that references the parent's height.
        
        Returns:
            ParentHeight: Size object referencing the parent's height
        """
        ...
    
    @staticmethod
    def PARENT_X1() -> ParentX1:
        """
        Create a size that references the parent's left x coordinate.
        
        Returns:
            ParentX1: Size object referencing the parent's x1
        """
        ...
    
    @staticmethod
    def PARENT_X2() -> ParentX2:
        """
        Create a size that references the parent's right x coordinate.
        
        Returns:
            ParentX2: Size object referencing the parent's x2
        """
        ...
    
    @staticmethod
    def PARENT_Y1() -> ParentY1:
        """
        Create a size that references the parent's top y coordinate.
        
        Returns:
            ParentY1: Size object referencing the parent's y1
        """
        ...
    
    @staticmethod
    def PARENT_Y2() -> ParentY2:
        """
        Create a size that references the parent's bottom y coordinate.
        
        Returns:
            ParentY2: Size object referencing the parent's y2
        """
        ...
    
    @staticmethod
    def PARENT_XC() -> ParentXC:
        """
        Create a size that references the parent's x center coordinate.
        
        Returns:
            ParentXC: Size object referencing the parent's x center
        """
        ...
    
    @staticmethod
    def PARENT_YC() -> ParentYC:
        """
        Create a size that references the parent's y center coordinate.
        
        Returns:
            ParentYC: Size object referencing the parent's y center
        """
        ...
    
    @staticmethod
    def SELF_WIDTH() -> SelfWidth:
        """
        Create a size relative to the item's own width.
        
        Args:
            factor (float, optional): Multiplier for the width (default: 1.0)
            offset (float, optional): Offset to add to the scaled width (default: 0)
            
        Returns:
            baseSizing: Size object relative to the item's own width
        """
        ...
    
    @staticmethod
    def SELF_HEIGHT() -> SelfHeight:
        """
        Create a size relative to the item's own height.
        
        Args:
            factor (float, optional): Multiplier for the height (default: 1.0)
            offset (float, optional): Offset to add to the scaled height (default: 0)
            
        Returns:
            baseSizing: Size object relative to the item's own height
        """
        ...
    
    @staticmethod
    def VIEWPORT_WIDTH() -> ViewportWidth:
        """
        Create a size that references the viewport's width.
        
        Returns:
            ViewportWidth: Size object referencing the viewport's width
        """
        ...
    
    @staticmethod
    def VIEWPORT_HEIGHT() -> ViewportHeight:
        """
        Create a size that references the viewport's height.
        
        Returns:
            ViewportHeight: Size object referencing the viewport's height
        """
        ...
    
    @staticmethod
    def MIN(first: DynamicSizeT, second: DynamicSizeT, *args) -> MinSize:
        """
        Take minimum of two or more size values.
        
        Args:
            first: First size value (can be a number or baseSizing object)
            second: Second size value (can be a number or baseSizing object)
            *args: Additional size values to include in the minimum
            
        Returns:
            baseSizing: Minimum size object
        """
        ...
    
    @staticmethod
    def MAX(first: DynamicSizeT, second: DynamicSizeT, *args) -> MaxSize:
        """
        Take maximum of two or more size values.
        
        Args:
            first: First size value (can be a number or baseSizing object)
            second: Second size value (can be a number or baseSizing object)
            *args: Additional size values to include in the maximum
            
        Returns:
            baseSizing: Maximum size object
        """
        ...
    
    @staticmethod
    def MEAN(first: DynamicSizeT, second: DynamicSizeT, *args) -> DivideSize:
        """
        Calculate the mean (average) of two or more size values.
        
        Args:
            first: First size value (can be a number or baseSizing object)
            second: Second size value (can be a number or baseSizing object)
            *args: Additional size values to include in the average
            
        Returns:
            baseSizing: Mean of the size values
        """
        ...
    
    @staticmethod
    def ADD(first: DynamicSizeT, second: DynamicSizeT, *args) -> AddSize:
        """
        Add two or more size values.
        
        Args:
            first: First size value (can be a number or baseSizing object)
            second: Second size value (can be a number or baseSizing object)
            *args: Additional size values to add
            
        Returns:
            baseSizing: Sum of the size values
        """
        ...
    
    @staticmethod
    def SUBTRACT(minuend: DynamicSizeT, subtrahend: DynamicSizeT) -> SubtractSize:
        """
        Subtract one size value from another.
        
        Args:
            minuend: Size value to subtract from (can be a number or baseSizing object)
            subtrahend: Size value to subtract (can be a number or baseSizing object)
            
        Returns:
            baseSizing: Difference of the size values
        """
        ...
    
    @staticmethod
    def MULTIPLY(first: DynamicSizeT, second: DynamicSizeT) -> MultiplySize:
        """
        Multiply two size values.
        
        Args:
            first: First size value (can be a number or baseSizing object)
            second: Second size value (can be a number or baseSizing object)
            
        Returns:
            baseSizing: Product of the size values
        """
        ...
    
    @staticmethod
    def DIVIDE(dividend: DynamicSizeT, divisor: DynamicSizeT) -> DivideSize:
        """
        Divide one size value by another.
        
        Args:
            dividend: Size value to divide (can be a number or baseSizing object)
            divisor: Size value to divide by (can be a number or baseSizing object)
            
        Returns:
            baseSizing: Quotient of the size values
        """
        ...
    
    @staticmethod
    def FLOOR_DIVIDE(dividend: DynamicSizeT, divisor: DynamicSizeT) -> FloorDivideSize:
        """
        Floor divide one size value by another.
        
        Args:
            dividend: Size value to divide (can be a number or baseSizing object)
            divisor: Size value to divide by (can be a number or baseSizing object)
            
        Returns:
            baseSizing: Floor quotient of the size values
        """
        ...
    
    @staticmethod
    def MODULO(dividend: DynamicSizeT, divisor: DynamicSizeT) -> ModuloSize:
        """
        Calculate the remainder when dividing one size by another.
        
        Args:
            dividend: Size value to divide (can be a number or baseSizing object)
            divisor: Size value to divide by (can be a number or baseSizing object)
            
        Returns:
            baseSizing: Remainder of the division
        """
        ...
    
    @staticmethod
    def POWER(base: DynamicSizeT, exponent: DynamicSizeT) -> PowerSize:
        """
        Raise a size value to a power.
        
        Args:
            base: Base size value (can be a number or baseSizing object)
            exponent: Exponent to raise to (can be a number or baseSizing object)
            
        Returns:
            baseSizing: Base raised to the exponent
        """
        ...
    
    @staticmethod
    def NEGATE(value: DynamicSizeT) -> NegateSize:
        """
        Negate a size value.
        
        Args:
            value: Size value to negate (can be a number or baseSizing object)
            
        Returns:
            baseSizing: Negated size value
        """
        ...
    
    @staticmethod
    def ABS(value: DynamicSizeT) -> AbsoluteSize:
        """
        Get the absolute value of a size.
        
        Args:
            value: Size value (can be a number or baseSizing object)
            
        Returns:
            baseSizing: Absolute size value
        """
        ...
    
    @staticmethod
    def from_expression(expr: str) -> baseSizing:
        """
        Create a size object from a string expression.
        
        This is an alias for parse_size().
        
        Args:
            expr (str): String expression to parse
            
        Returns:
            baseSizing: Parsed size object
            
        Raises:
            ValueError: If the expression is empty or invalid
        """
        ...
    
    @staticmethod
    def SELF_X1() -> SelfX1:
        """
        Create a size that references the item's own left x coordinate (x1).
        
        Returns:
            SelfX1: Size object referencing the item's x1
        """
        ...
    
    @staticmethod
    def SELF_X2() -> SelfX2:
        """
        Create a size that references the item's own right x coordinate (x2).
        
        Returns:
            SelfX2: Size object referencing the item's x2
        """
        ...
    
    @staticmethod
    def SELF_Y1() -> SelfY1:
        """
        Create a size that references the item's own top y coordinate (y1).
        
        Returns:
            SelfY1: Size object referencing the item's y1
        """
        ...
    
    @staticmethod
    def SELF_Y2() -> SelfY2:
        """
        Create a size that references the item's own bottom y coordinate (y2).
        
        Returns:
            SelfY2: Size object referencing the item's y2
        """
        ...
    
    @staticmethod
    def RELATIVE_X1(item: uiItem) -> RefX1:
        """
        Create a size relative to another item's left x coordinate.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            RefX1: Size object relative to the reference item's x1
        """
        ...
    
    @staticmethod
    def RELATIVE_X2(item: uiItem) -> RefX2:
        """
        Create a size relative to another item's right x coordinate.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            RefX2: Size object relative to the reference item's x2
        """
        ...
    
    @staticmethod
    def RELATIVE_Y1(item: uiItem) -> RefY1:
        """
        Create a size relative to another item's top y coordinate.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            RefY1: Size object relative to the reference item's y1
        """
        ...
    
    @staticmethod
    def RELATIVE_Y2(item: uiItem) -> RefY2:
        """
        Create a size relative to another item's bottom y coordinate.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            RefY2: Size object relative to the reference item's y2
        """
        ...
    
    @staticmethod
    def SELF_XC() -> SelfXC:
        """
        Create a size that references the item's own x center coordinate.
        
        Returns:
            SelfXC: Size object referencing the item's x center
        """
        ...
    
    @staticmethod
    def SELF_YC() -> SelfYC:
        """
        Create a size that references the item's own y center coordinate.
        
        Returns:
            SelfYC: Size object referencing the item's y center
        """
        ...
    
    @staticmethod
    def RELATIVE_XC(item: uiItem) -> RefXC:
        """
        Create a size relative to another item's x center coordinate.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            RefXC: Size object relative to the reference item's x center
        """
        ...
    
    @staticmethod
    def RELATIVE_YC(item: uiItem) -> RefYC:
        """
        Create a size relative to another item's y center coordinate.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            RefYC: Size object relative to the reference item's y center
        """
        ...
    
