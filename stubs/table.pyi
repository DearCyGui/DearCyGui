# Elements missing from the discovery
# Manually edited

from typing import Protocol

class SupportsStr(Protocol):
    def __str__(self) -> str: ...

TableContentValue : TypeAlias = 'uiItem' | SupportsStr

class TableElement:
    """
    Configuration for a table element.
    
    A table element represents a cell in a table and contains all information
    about its content, appearance, and behavior. Each element can hold either
    a UI widget, text content, or nothing, and can optionally have a tooltip
    and background color.
    
    Elements can be created directly or via the table's indexing operation.
    """
    def __init__(self,
                 content: TableContentValue | None = None,
                 *,
                 bg_color: Color = 0,
                 ordering_value: object | None = None,
                 tooltip: TableContentValue | None = None
                 ) -> None:
        """
        Content of a table cell.

        Parameters:
            - content: The item to display in the table cell.
            - bg_color: The background color for the cell, overriding any default.
            - ordering_value: The value used for this cell when ordering the table.
            - tooltip: The tooltip displayed when hovering over the cell.
        """
        ...
    
    def configure(self,
                  *,
                  content: TableContentValue | None = None,
                  bg_color: Color = 0,
                  ordering_value: object | None = None,
                  tooltip: TableContentValue | None = None
                  ) -> None:
    
        """
        Configure multiple attributes at once.
        
        Parameters:
            - content: The item to display in the table cell.
            - bg_color: The background color for the cell, overriding any default.
            - ordering_value: The value used for this cell when ordering the table.
            - tooltip: The tooltip displayed when hovering over the cell.
        """
        ...
    
    @property
    def content(self) -> TableContentValue:
        """
        The item to display in the table cell.
        
        This can be a UI widget (uiItem), a string, or any object that can be 
        converted to a string. When setting non-widget content, the ordering_value 
        is automatically set to the same value to ensure proper sorting behavior.
        """
        ...
    
    @content.setter
    def content(self, value: TableContentValue) -> None:
        ...
    
    @property
    def tooltip(self) -> TableContentValue | None:
        """
        The tooltip displayed when hovering over the cell.
        
        This can be a UI widget (like a Tooltip), a string, or any object that can be 
        converted to a string. The tooltip is displayed when the user hovers over 
        the cell's content.
        """
        ...
    
    @tooltip.setter
    def tooltip(self, value: TableContentValue | None) -> None:
        ...
    
    @property
    def ordering_value(self) -> object | None:
        """
        The value used for ordering the table.
        
        This value is used when sorting the table. By default, it's automatically set 
        to the content value when content is set to a string or number. For UI widgets, 
        it defaults to the widget's UUID (creation order) if not explicitly specified.
        """
        ...
    
    @ordering_value.setter
    def ordering_value(self, value: object | None) -> None:
        ...
    
    @property
    def bg_color(self) -> Color:
        """
        The background color for the cell.
        
        This color overrides any default table cell background colors.
        """
        ...
    
    @bg_color.setter
    def bg_color(self, value: Color) -> None:
        ...
    

TableValue : TypeAlias = 'uiItem' | TableElement | SupportsStr

class TableRowView:
    """
    View class for accessing and manipulating a single row of a Table.
    
    This class provides a convenient interface for working with a specific row 
    in a table. It supports both indexing operations to access individual cells 
    and a context manager interface for adding multiple items to the row.
    """
    def __init__(self) -> None:
        ...
    
    def __enter__(self) -> Self:
        """
        Start a context for adding items to this row.
        
        When used as a context manager, TableRowView allows for intuitive 
        creation of UI elements that will be added to the row in sequence.
        Any Tooltip elements will be associated with the immediately preceding item.
        """
        ...
    
    def __exit__(self, exc_type, exc_value, traceback) -> Literal[False]:
        """
        Convert children added during context into row values.
        
        When the context block ends, all items created within it are properly 
        arranged into the table row. Tooltip elements are associated with their 
        preceding items automatically.
        """
        ...
    
    def __getitem__(self, col_idx: int) -> TableElement  | None:
        """
        Get the element at the specified column in this row.
        
        This provides direct access to individual cells in the row by column index.
        If no element exists at the specified position, None is returned.
        """
        ...
    
    def __setitem__(self, col_idx: int, value: TableValue) -> None:
        """
        Set the element at the specified column in this row.
        
        This allows directly setting a cell's content. The value can be a TableElement, 
        a UI widget, or any value that can be converted to a string.
        """
        ...
    
    def __delitem__(self, col_idx: int) -> None:
        """
        Delete the element at the specified column in this row.
        
        This removes a cell's content completely, leaving an empty cell.
        """
        ...
    


class TableColView:
    """
    View class for accessing and manipulating a single column of a Table.
    
    This class provides a convenient interface for working with a specific column 
    in a table. It supports both indexing operations to access individual cells 
    and a context manager interface for adding multiple items to the column.
    """
    def __init__(self) -> None:
        ...
    
    def __enter__(self) -> Self:
        """
        Start a context for adding items to this column.
        
        When used as a context manager, TableColView allows for intuitive 
        creation of UI elements that will be added to the column in sequence.
        Any Tooltip elements will be associated with the immediately preceding item.
        """
        ...
    
    def __exit__(self, exc_type, exc_value, traceback) -> Literal[False]:
        """
        Convert children added during context into column values.
        
        When the context block ends, all items created within it are properly
        arranged into the table column. Tooltip elements are associated with their
        preceding items automatically.
        """
        ...
    
    def __getitem__(self, row_idx: int) -> TableElement | None:
        """
        Get the element at the specified row in this column.
        
        This provides direct access to individual cells in the column by row index.
        If no element exists at the specified position, None is returned.
        """
        ...
    
    def __setitem__(self, row_idx: int, value: TableValue) -> None:
        """
        Set the element at the specified row in this column.
        
        This allows directly setting a cell's content. The value can be a TableElement, 
        a UI widget, or any value that can be converted to a string.
        """
        ...
    
    def __delitem__(self, row_idx: int) -> None:
        """
        Delete the element at the specified row in this column.
        
        This removes a cell's content completely, leaving an empty cell.
        """
        ...


class TableColConfigView:
    """
    A View of a Table which you can index to get the
    TableColConfig for a specific column.
    """
    def __init__(self) -> None:
        ...
    
    def __getitem__(self, col_idx: int) -> 'TableColConfig':
        """Get the column configuration for the specified column."""
        ...
    
    def __setitem__(self, col_idx: int, config: 'TableColConfig') -> None:
        """Set the column configuration for the specified column."""
        ...
    
    def __delitem__(self, col_idx: int) -> None:
        """Delete the column configuration for the specified column."""
        ...
    
    def __call__(self, col_idx: int, attribute: str, value) -> 'TableColConfig':
        """Set an attribute of the column configuration for the specified column."""
        ...
    

    


class TableRowConfigView:
    """
    A view for accessing and manipulating row configurations in a table.
    
    This view provides a convenient interface for working with row configurations.
    It supports indexing to access individual row configurations and setting
    specific attributes on those configurations.
    
    The view is typically accessed through the `table.row_config` property.
    """
    def __init__(self) -> None:
        ...
    
    def __getitem__(self, row_idx: int) -> 'TableRowConfig':
        """
        Get the row configuration for the specified row.
        
        This retrieves the configuration object for a specific row, allowing
        you to inspect or modify its properties. If the row doesn't have an
        existing configuration, a default one will be created.
        """
        ...
    
    def __setitem__(self, row_idx: int, config: 'TableRowConfig') -> None:
        """
        Set the row configuration for the specified row.
        
        This replaces the entire configuration for a specific row with a new
        configuration object. This allows for complete customization of the
        row's appearance and behavior.
        """
        ...
    
    def __delitem__(self, row_idx: int) -> None:
        """
        Reset the row configuration to default for the specified row.
        
        This removes any custom configuration for the specified row and
        replaces it with a new default configuration. This effectively
        resets all row settings to their default values.
        """
        ...
    
    def __call__(self, row_idx: int, attribute: str, value: Any) -> 'TableRowConfig':
        """
        Set a specific attribute on a row's configuration.
        
        This is a convenient shorthand for getting a row configuration,
        setting a single attribute, and then updating the configuration.
        It returns the modified configuration object for further chaining.
        
        Example: table.row_config(0, 'bg_color', (1.0, 0.0, 0.0, 1.0))
        """
        ...

