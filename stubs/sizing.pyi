
from types import NotImplementedType
NumStrT = int | float | str


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
    
    def __add__(self, other: NumStrT | 'baseSizing') -> NotImplementedType | 'AddSize':
        ...
    
    def __sub__(self, other: NumStrT | 'baseSizing') -> NotImplementedType | 'SubtractSize':
        ...
    
    def __mul__(self, other: NumStrT | 'baseSizing') -> NotImplementedType | 'MultiplySize':
        ...
    
    def __truediv__(self, other: NumStrT | 'baseSizing') -> NotImplementedType | 'DivideSize':
        ...
    
    def __floordiv__(self, other: NumStrT | 'baseSizing') -> NotImplementedType | 'FloorDivideSize':
        ...
    
    def __mod__(self, other: NumStrT | 'baseSizing') -> NotImplementedType | 'ModuloSize':
        ...
    
    def __pow__(self, other: NumStrT | 'baseSizing', modulo=...) -> NotImplementedType | 'PowerSize':
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
    


class ParentX0(baseSizing):
    """
    Parent actual left x coordinate (x0) without content padding.
    This refers to the outer position of the parent item.
    """
    def __repr__(self) -> str: # -> Literal['ParentX0()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@ParentX0], tuple[()], dict[str, bint]]:
        ...
    


class ParentX1(baseSizing):
    """
    Parent left content area x coordinate (x1).
    This is the left edge of the parent's content area, accounting for padding.
    """
    def __repr__(self) -> str: # -> Literal['ParentX1()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@ParentX1], tuple[()], dict[str, bint]]:
        ...
    


class ParentX2(baseSizing):
    """
    Parent right content area x coordinate (x2).
    This is the right edge of the parent's content area, accounting for padding.
    """
    def __repr__(self) -> str: # -> Literal['ParentX2()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@ParentX2], tuple[()], dict[str, bint]]:
        ...
    


class ParentX3(baseSizing):
    """
    Parent right-most x coordinate (x3).
    This is the right-most edge of the parent's accounting for padding and border.
    It is equivalent to parent.x0 + parent.width.
    """
    def __repr__(self) -> str: # -> Literal['ParentX3()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@ParentX3], tuple[()], dict[str, bint]]:
        ...
    


class ParentXC(baseSizing):
    """
    Parent content area x center coordinate.
    This is the horizontal center of the parent's content area.
    """
    def __repr__(self) -> str: # -> Literal['ParentXC()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@ParentXC], tuple[()], dict[str, bint]]:
        ...
    


class ParentY0(baseSizing):
    """
    Parent actual top y coordinate (y0) without content padding.
    This refers to the outer position of the parent item.
    """
    def __repr__(self) -> str: # -> Literal['ParentY0()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@ParentY0], tuple[()], dict[str, bint]]:
        ...
    


class ParentY1(baseSizing):
    """
    Parent top content area y coordinate (y1).
    This is the top edge of the parent's content area, accounting for padding.
    """
    def __repr__(self) -> str: # -> Literal['ParentY1()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@ParentY1], tuple[()], dict[str, bint]]:
        ...
    


class ParentY2(baseSizing):
    """
    Parent bottom content area y coordinate (y2).
    This is the bottom edge of the parent's content area, accounting for padding.
    """
    def __repr__(self) -> str: # -> Literal['ParentY2()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@ParentY2], tuple[()], dict[str, bint]]:
        ...
    


class ParentY3(baseSizing):
    """
    Parent bottom-most y coordinate (y3).
    This is the bottom-most edge of the parent's accounting for padding and border.
    It is equivalent to parent.y0 + parent.height.
    """
    def __repr__(self) -> str: # -> Literal['ParentY3()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@ParentY3], tuple[()], dict[str, bint]]:
        ...
    


class ParentYC(baseSizing):
    """
    Parent content area y center coordinate.
    This is the vertical center of the parent's content area.
    """
    def __repr__(self) -> str: # -> Literal['ParentYC()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@ParentYC], tuple[()], dict[str, bint]]:
        ...
    


class baseRefSizing(baseSizing):
    """
    Base class for references to an item's size
    and positioning attribute.

    Defines various properties to access other
    size and position attributes of this item
    """
    @property
    def content_height(self) -> baseSizing:
        """
        Height of the area available for the children
        inside the item.
        This is equivalent to y2 - y1

        For items which do not accept children, this is equal
        to the height.
        """
        ...
    
    @property
    def content_width(self) -> baseSizing:
        """
        Width of the area available for the children
        inside the item.
        This is equivalent to x2 - x1

        For items which do not accept children, this is equal
        to the width.
        """
        ...
    
    @property
    def height(self) -> baseSizing:
        """
        Height of the area taken by the item.

        Note for items with children, this may be larger
        that the area available for the children, if the
        item adds padding.
        """
        ...
    
    @property
    def width(self) -> baseSizing:
        """
        Width of the area taken by the item.

        Note for items with children, this may be larger
        that the area available for the children, if the
        item adds padding.
        """
        ...
    
    @property
    def x0(self) -> baseSizing:
        """
        Reference to the left-most x position of the item
        """
        ...
    
    @property
    def x1(self) -> baseSizing:
        """
        Reference to the left x position of the item.

        This only differs from X0 for items with children
        and padding. In which case the position corresponds
        to the starting position of the area available for
        the children.
        """
        ...
    
    @property
    def xc(self) -> baseSizing:
        """
        Reference to the center position between x1 and x2 of the item.
        """
        ...
    
    @property
    def x2(self) -> baseSizing:
        """
        Reference to the right position of the item.

        For items with children and padding, this position is
        placed at the end of the area available for children.

        If you intend to get the right-most position for any item,
        including the case described above, you can get it by adding
        x0 and width, or by using x3.
        """
        ...
    
    @property
    def x3(self) -> baseSizing:
        """
        Reference to the right-most position of the item.

        This corresponds to adding x0 and width.
        """
        ...
    
    @property
    def y0(self) -> baseSizing:
        """
        Reference to the top-most y position of the item
        """
        ...
    
    @property
    def y1(self) -> baseSizing:
        """
        Reference to the top y position of the item.

        This only differs from Y0 for items with children
        and padding. In which case the position corresponds
        to the starting position of the area available for
        the children.
        """
        ...
    
    @property
    def yc(self) -> baseSizing:
        """
        Reference to the center position between y1 and y2 of the item.
        """
        ...
    
    @property
    def y2(self) -> baseSizing:
        """
        Reference to the bottom position of the item.

        For items with children and padding, this position is
        placed at the end of the area available for children.

        If you intend to get the bottom-most position for any item,
        including the case described above, you can get it by adding
        y0 and height.
        """
        ...
    
    @property
    def y3(self) -> baseSizing:
        """
        Reference to the bottom-most position of the item.

        This corresponds to adding
        y0 and height.
        """
        ...
    


class RefHeight(baseRefSizing):
    """
    References another item height.
    """
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    


class RefWidth(baseRefSizing):
    """
    References another item width.
    """
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    


class RefX0(baseRefSizing):
    """
    References another item's left x coordinate (x0).

    x0 is the left most position of the item.

    For items which accept children, and which add padding,
    x1 can be different to x0.
    """
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    


class RefX1(baseRefSizing):
    """
    References another item's left x coordinate (x1).

    x1 is the left x position of the item.

    For item which accept children, this refers to the x position
    of the area available for children. If the item adds
    padding, it can thus differ from x0.
    """
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    


class RefX2(baseRefSizing):
    """
    References another item's right x coordinate (x2).
    This is the right edge of the item's content area, accounting for padding if available.
    If the item has no content area, this is equivalent to x0 + width.
    """
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    


class RefX3(baseRefSizing):
    """
    References another item's right-most x coordinate (x3).
    This is equivalent to x0 + width.
    It is useful for items which do not have a content area,
    or when you want to get the right-most position regardless
    of padding.
    """
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    


class RefXC(baseRefSizing):
    """
    References another item's content x center coordinate.
    This is the horizontal center of the item's content area if available.
    If the item has no content area, this is equivalent to x0 + width/2.
    """
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    


class RefY0(baseRefSizing):
    """
    References another item's outer top y coordinate (y0).
    This is the actual position of the item, not accounting for content area padding.
    """
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    


class RefY1(baseRefSizing):
    """
    References another item's content top y coordinate (y1).
    This is the top edge of the item's content area, accounting for padding if available.
    If the item has no content area, this is equivalent to y0.
    """
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    


class RefY2(baseRefSizing):
    """
    References another item's content bottom y coordinate (y2).
    This is the bottom edge of the item's content area, accounting for padding if available.
    If the item has no content area, this is equivalent to y0 + height.
    """
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    


class RefY3(baseRefSizing):
    """
    References another item's bottom-most y coordinate (y3).
    This is equivalent to y0 + height.

    It is useful for items which do not have a content area,
    or when you want to get the bottom-most position regardless
    of padding.
    """
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    


class RefYC(baseRefSizing):
    """
    References another item's content y center coordinate.
    This is the vertical center of the item's content area if available.
    If the item has no content area, this is equivalent to (y1 + y2)/2.
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
    


class SelfX0(baseSizing):
    """
    References the left-most x coordinate (x0) of the item using this sizing.
    """
    def __repr__(self) -> str: # -> Literal['SelfX0()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@SelfX0], tuple[()], dict[str, Any]]:
        ...
    


class SelfX1(baseSizing):
    """
    References the left x coordinate (x1) of the item using this sizing.

    x1 is the start of the children area of the item.
    Else it is equal to x0.
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
    


class SelfX3(baseSizing):
    """
    References the right-most x coordinate (x3) of the item using this sizing.
    """
    def __repr__(self) -> str: # -> Literal['SelfX3()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@SelfX3], tuple[()], dict[str, Any]]:
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
    


class SelfY0(baseSizing):
    """
    References the top-most y coordinate (y0) of the item using this sizing.
    This refers to the outer position of the item.
    """
    def __repr__(self) -> str: # -> Literal['SelfY0()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@SelfY0], tuple[()], dict[str, Any]]:
        ...
    


class SelfY1(baseSizing):
    """
    References the top y coordinate (y1) of the item using this sizing.

    y1 is the start of the children area of the item, if any.
    Else it is equal to y0.
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

    y2 is the end of the children area of the item, if any.
    Else it is equal to y0 + height.
    """
    def __repr__(self) -> str: # -> Literal['SelfY2()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@SelfY2], tuple[()], dict[str, Any]]:
        ...
    


class SelfY3(baseSizing):
    """
    References the bottom-most y coordinate (y3) of the item using this sizing.
    This is equivalent to y0 + height.
    """
    def __repr__(self) -> str: # -> Literal['SelfY3()']:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@SelfY3], tuple[()], dict[str, Any]]:
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
    


class ThemeStyleSize(baseSizing):
    """
    References an theme style value.
    """
    def _get_style_name(self) -> str:
        """
        Retrieve the original style name
        """
        ...
    
    def __repr__(self) -> str: # -> str:
        ...
    
    def __str__(self) -> str:
        ...
    
    def __reduce__(self): # -> tuple[Type[Self@ThemeStyleSize], tuple[int32_t, bint], dict[str, Any]]:
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
    - `fillx`: Fill available width
    - `filly`: Fill available height
    - `fullx`: Full parent content width (no position offset)
    - `fully`: Full parent content height (no position offset)
    - `parent.width`: Width of the parent item (larger than fullx as contains parent borders)
    - `parent.height`: Height of the parent item (larger than fully as contains parent borders)
    - `viewport.width`: Width of the viewport (application window)
    - `viewport.height`: Height of the viewport (application window)
    - `min`: Take minimum of two size values
    - `max`: Take maximum of two size values
    - `mean`: Calculate the mean (average) of two or more size values
    - `dpi`: Current global scale factor
    - `self.width`: Reference to the width of the current item
    - `self.height`: Reference to the height of the current item
    - `item.width`/`item.height`: Reference to another item's size (item must be in globals()/locals())
    - `{self, parent, item}.{x0, x1, x2, x3, xc, y0, y1, y2, y3, yc}`:
            Reference to left/center/right/top/bottom of the current, parent, or a target item.
            x0: left-most position
            x1: left position (=left-most if does not accept children. left of children area else)
            x2: right position (=right-most if does not accept children. right of children area else)
            x3: right-most position (right edge of the item, including borders)
            For most items, x0 == x1 and x2 == x3. width = x3 - x0.
            Same for y0, y1, y2, y3 (top-most/top/bottom/bottom-most)
    - `+`, `-`, `*`, `/`, `//`, `%`, `**`: Arithmetic operators. Parentheses can be used for grouping.
    - `abs()`: Absolute value function
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
    def RELATIVEX(item: 'uiItem') -> RefWidth:
        """
        Create a size relative to another item's width.

        Args:
            item (uiItem): The reference item
            
        Returns:
            baseSizing: Size object relative to the reference item's width
        """
        ...
    
    @staticmethod
    def RELATIVEY(item: 'uiItem') -> RefHeight:
        """
        Create a size relative to another item's height.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            baseSizing: Size object relative to the reference item's height
        """
        ...
    
    @staticmethod
    def PARENT_X0() -> ParentX0:
        """
        Create a size that references the parent's outer left x coordinate.
        This refers to the actual position of the parent item, not accounting for padding.
        
        Returns:
            ParentX0: Size object referencing the parent's outer x position
        """
        ...
    
    @staticmethod
    def PARENT_X1() -> ParentX1:
        """
        Create a size that references the parent's content left x coordinate.
        This is the left edge of the parent's content area, accounting for padding.
        
        Returns:
            ParentX1: Size object referencing the parent's content x1
        """
        ...
    
    @staticmethod
    def PARENT_X2() -> ParentX2:
        """
        Create a size that references the parent's content right x coordinate.
        This is the right edge of the parent's content area, accounting for padding.
        
        Returns:
            ParentX2: Size object referencing the parent's content x2
        """
        ...
    
    @staticmethod
    def PARENT_Y0() -> ParentY0:
        """
        Create a size that references the parent's outer top y coordinate.
        This refers to the actual position of the parent item, not accounting for padding.
        
        Returns:
            ParentY0: Size object referencing the parent's outer y position
        """
        ...
    
    @staticmethod
    def PARENT_Y1() -> ParentY1:
        """
        Create a size that references the parent's content top y coordinate.
        This is the top edge of the parent's content area, accounting for padding.
        
        Returns:
            ParentY1: Size object referencing the parent's content y1
        """
        ...
    
    @staticmethod
    def PARENT_Y2() -> ParentY2:
        """
        Create a size that references the parent's content bottom y coordinate.
        This is the bottom edge of the parent's content area, accounting for padding.
        
        Returns:
            ParentY2: Size object referencing the parent's content y2
        """
        ...
    
    @staticmethod
    def PARENT_XC() -> ParentXC:
        """
        Create a size that references the parent's content x center coordinate.
        This is the horizontal center of the parent's content area.
        
        Returns:
            ParentXC: Size object referencing the parent's content x center
        """
        ...
    
    @staticmethod
    def PARENT_YC() -> ParentYC:
        """
        Create a size that references the parent's content y center coordinate.
        This is the vertical center of the parent's content area.
        
        Returns:
            ParentYC: Size object referencing the parent's content y center
        """
        ...
    
    @staticmethod
    def SELF_WIDTH() -> SelfWidth:
        """
        Create a size relative to the item's own width.
            
        Returns:
            baseSizing: Size object relative to the item's own width
        """
        ...
    
    @staticmethod
    def SELF_HEIGHT() -> SelfHeight:
        """
        Create a size relative to the item's own height.
            
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
    def SELF_X0() -> SelfX0:
        """
        Create a size that references the item's own outer left x coordinate (x0).
        This is the actual position of the item, not accounting for content area padding.
        
        Returns:
            SelfX0: Size object referencing the item's outer x position
        """
        ...
    
    @staticmethod
    def SELF_X1() -> SelfX1:
        """
        Create a size that references the item's own content left x coordinate (x1).
        This is the left edge of the item's content area, accounting for padding if available.
        If the item has no content area, this is equivalent to x0.
        
        Returns:
            SelfX1: Size object referencing the item's content x1
        """
        ...
    
    @staticmethod
    def SELF_X2() -> SelfX2:
        """
        Create a size that references the item's own content right x coordinate (x2).
        This is the right edge of the item's content area, accounting for padding if available.
        If the item has no content area, this is equivalent to x0 + width.
        
        Returns:
            SelfX2: Size object referencing the item's content x2
        """
        ...
    
    @staticmethod
    def SELF_Y0() -> SelfY0:
        """
        Create a size that references the item's own outer top y coordinate (y0).
        This is the actual position of the item, not accounting for content area padding.
        
        Returns:
            SelfY0: Size object referencing the item's outer y position
        """
        ...
    
    @staticmethod
    def SELF_Y1() -> SelfY1:
        """
        Create a size that references the item's own content top y coordinate (y1).
        This is the top edge of the item's content area, accounting for padding if available.
        If the item has no content area, this is equivalent to y0.
        
        Returns:
            SelfY1: Size object referencing the item's content y1
        """
        ...
    
    @staticmethod
    def SELF_Y2() -> SelfY2:
        """
        Create a size that references the item's own content bottom y coordinate (y2).
        This is the bottom edge of the item's content area, accounting for padding if available.
        If the item has no content area, this is equivalent to y0 + height.
        
        Returns:
            SelfY2: Size object referencing the item's content y2
        """
        ...
    
    @staticmethod
    def RELATIVE_X0(item: 'uiItem') -> RefX0:
        """
        Create a size relative to another item's outer left x coordinate (x0).
        This is the actual position of the item, not accounting for content area padding.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            RefX0: Size object relative to the reference item's outer x position
        """
        ...
    
    @staticmethod
    def RELATIVE_X1(item: 'uiItem') -> RefX1:
        """
        Create a size relative to another item's content left x coordinate (x1).
        This is the left edge of the item's content area, accounting for padding if available.
        If the item has no content area, this is equivalent to x0.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            RefX1: Size object relative to the reference item's content x1
        """
        ...
    
    @staticmethod
    def RELATIVE_X2(item: 'uiItem') -> RefX2:
        """
        Create a size relative to another item's content right x coordinate (x2).
        This is the right edge of the item's content area, accounting for padding if available.
        If the item has no content area, this is equivalent to x0 + width.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            RefX2: Size object relative to the reference item's content x2
        """
        ...
    
    @staticmethod
    def RELATIVE_Y0(item: 'uiItem') -> RefY0:
        """
        Create a size relative to another item's outer top y coordinate (y0).
        This is the actual position of the item, not accounting for content area padding.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            RefY0: Size object relative to the reference item's outer y position
        """
        ...
    
    @staticmethod
    def RELATIVE_Y1(item: 'uiItem') -> RefY1:
        """
        Create a size relative to another item's content top y coordinate (y1).
        This is the top edge of the item's content area, accounting for padding if available.
        If the item has no content area, this is equivalent to y0.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            RefY1: Size object relative to the reference item's content y1
        """
        ...
    
    @staticmethod
    def RELATIVE_Y2(item: 'uiItem') -> RefY2:
        """
        Create a size relative to another item's content bottom y coordinate (y2).
        This is the bottom edge of the item's content area, accounting for padding if available.
        If the item has no content area, this is equivalent to y0 + height.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            RefY2: Size object relative to the reference item's content y2
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
    def RELATIVE_XC(item: 'uiItem') -> RefXC:
        """
        Create a size relative to another item's x center coordinate.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            RefXC: Size object relative to the reference item's x center
        """
        ...
    
    @staticmethod
    def RELATIVE_YC(item: 'uiItem') -> RefYC:
        """
        Create a size relative to another item's y center coordinate.
        
        Args:
            item (uiItem): The reference item
            
        Returns:
            RefYC: Size object relative to the reference item's y center
        """
        ...
    
    @staticmethod
    def THEME_STYLE(style_name: str, use_y_component: bool = False) -> ThemeStyleSize:
        """
        Create a size that references an ImGui style value.
        
        Args:
            style_name (str): Name of the ImGui style (case insensitive)
            use_y_component (bool): Whether to use the Y component for Vec2 styles
            
        Returns:
            ThemeStyleSize: Size object referencing the theme style
            
        Examples:
            Size.THEME_STYLE("item_spacing")     # X component by default
            Size.THEME_STYLE("item_spacing", True) # Y component
        """
        ...
    
