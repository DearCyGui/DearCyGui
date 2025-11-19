"""
A Node editor for DearCyGui.

This module provides both base classes for advanced users and full-featured
classes for quick node editor development.

Base classes (for advanced users who want full control):
--------------------------------------------------------
- BaseNodeEditor: Basic node editor container with background, nodes layer, and foreground
- BaseNode: Basic node with positioning and pinning capabilities
- BaseLink: Basic link between items with bezier curve rendering

"""

from collections.abc import Callable, Sequence
import dearcygui as dcg
from dearcygui.utils.handler import auto_cleanup_handler
from enum import StrEnum
import math
from typing import TypeVar


def _get_bezier_control_points(start_pos: tuple[float, float], 
                               end_pos: tuple[float, float]) -> tuple[tuple[float, float], 
                                                                      tuple[float, float], 
                                                                      tuple[float, float], 
                                                                      tuple[float, float]]:
    """Calculate control points for a cubic Bezier curve with horizontal tangents at both ends.
    
    Args:
        start_pos: Starting position (x, y)
        end_pos: Ending position (x, y)
        
    Returns:
        Tuple of four control points (p1, p2, p3, p4) for the cubic Bezier curve
    """
    x1, y1 = start_pos
    x4, y4 = end_pos

    if x1 > x4:
        # Swap points to always draw left to right
        x1, y1, x4, y4 = x4, y4, x1, y1
    
    # Horizontal distance for control points (can be adjusted for curve tension)
    # Use a minimum offset to handle vertical alignment -> commented for consistent behaviour on zooming
    dx = x4 - x1
    offset = max(abs(dx) * 0.5, abs(y4 - y1) * 0.25)#, 50.0)
    
    # Control points with horizontal tangents
    # p2 is to the right of p1 at the same height
    p1: tuple[float, float] = (x1, y1)
    p2: tuple[float, float] = (x1 + offset, y1)
    # p3 is to the left of p4 at the same height
    p3: tuple[float, float] = (x4 - offset, y4)
    p4: tuple[float, float] = (x4, y4)
    
    return (p1, p2, p3, p4)

def _point_on_cubic_bezier(p1: tuple[float, float],
                           p2: tuple[float, float],
                           p3: tuple[float, float],
                           p4: tuple[float, float],
                           t: float) -> tuple[float, float]:
    """Calculate a point on a cubic Bezier curve at parameter t.
    
    Uses the standard cubic Bezier formula:
    B(t) = (1-t)³P1 + 3(1-t)²tP2 + 3(1-t)t²P3 + t³P4
    
    Args:
        p1, p2, p3, p4: Control points of the cubic Bezier curve
        t: Parameter in range [0, 1]
        
    Returns:
        Point (x, y) on the curve at parameter t
    """
    t = max(0.0, min(1.0, t))  # Clamp t to [0, 1]
    
    one_minus_t = 1.0 - t
    one_minus_t_sq = one_minus_t * one_minus_t
    one_minus_t_cu = one_minus_t_sq * one_minus_t
    t_sq = t * t
    t_cu = t_sq * t
    
    x = (one_minus_t_cu * p1[0] +
         3.0 * one_minus_t_sq * t * p2[0] +
         3.0 * one_minus_t * t_sq * p3[0] +
         t_cu * p4[0])
    
    y = (one_minus_t_cu * p1[1] +
         3.0 * one_minus_t_sq * t * p2[1] +
         3.0 * one_minus_t * t_sq * p3[1] +
         t_cu * p4[1])
    
    return (x, y)

def _distance_point_to_bezier(point: tuple[float, float],
                              p1: tuple[float, float],
                              p2: tuple[float, float],
                              p3: tuple[float, float],
                              p4: tuple[float, float],
                              num_samples: int = 20) -> float:
    """Calculate approximate distance from a point to a cubic Bezier curve.
    
    This uses a sampling approach: divides the curve into segments and finds
    the minimum distance to any sampled point.
    
    Args:
        point: The point (x, y) to measure distance from
        p1, p2, p3, p4: Control points of the cubic Bezier curve
        num_samples: Number of points to sample along the curve (default: 20)
        
    Returns:
        Approximate minimum distance from point to curve
    """
    min_dist_sq = float('inf')
    px, py = point

    num_samples = max(2, num_samples)  # Ensure at least 2 samples
    points = [
        _point_on_cubic_bezier(p1, p2, p3, p4, i / num_samples) for i in range(num_samples + 1)
    ]

    # Find closest sample point
    distances_sq = [(bx - px) ** 2 + (by - py) ** 2 for (bx, by) in points]
    best_idx = min(range(len(distances_sq)), key=lambda i: distances_sq[i])

    # Take closest segment
    if best_idx == 0:
        seg_idx = 0  # Use segment [0, 1]
    elif best_idx == len(points) - 1:
        seg_idx = best_idx - 1  # Use segment [n-1, n]
    else:
        # Choose segment with closer neighbor
        if distances_sq[best_idx - 1] < distances_sq[best_idx + 1]:
            seg_idx = best_idx - 1  # Use segment [best_idx-1, best_idx]
        else:
            seg_idx = best_idx  # Use segment [best_idx, best_idx+1]

    # Get segment endpoints
    x1, y1 = points[seg_idx]
    x2, y2 = points[seg_idx + 1]

    # Approximate locally the curve by this segment
    dx = x2 - x1
    dy = y2 - y1
    seg_len_sq = dx * dx + dy * dy
    
    # Handle degenerate segment (both points are the same)
    if seg_len_sq < 1e-10:
        return distances_sq[best_idx] ** 0.5

    # Project point onto line defined by segment
    # t = dot(point - p1, p2 - p1) / ||p2 - p1||^2
    t = ((px - x1) * dx + (py - y1) * dy) / seg_len_sq
    t = max(0.0, min(1.0, t))  # Clamp to segment [0, 1]
    
    # Closest point on segment
    closest_x = x1 + t * dx
    closest_y = y1 + t * dy
    
    # Distance to closest point
    dist_x = px - closest_x
    dist_y = py - closest_y
    return (dist_x * dist_x + dist_y * dist_y) ** 0.5

def _get_children_recursively(item: dcg.uiItem) -> set[dcg.uiItem]:
    """
    Recursively collect all descendants of an item.
    
    This performs a depth-first traversal to find all children, grandchildren,
    and so on.
    
    Args:
        item: The root item to start from
        
    Returns:
        Set of all descendant items (does not include the root item itself)
    """
    children = set()
    for child in item.children:
        children.add(child)
        children.update(_get_children_recursively(child))
    return children

def _apply_children_recursively(item: dcg.uiItem, attribute: str, value) -> None:
    """
    Recursively collect all descendants of an item and apply them an attribute.
    
    This performs a depth-first traversal to find all children, grandchildren,
    and so on, and apply them the given attribute.

    If the attribute succeeds, the child tree below is not traversed.
    
    Args:
        item: The root item to start from
        
    Returns:
        None
    """
    for child in item.children:
        if hasattr(child, attribute):
            setattr(child, attribute, value)
            continue
        _apply_children_recursively(child, attribute, value)

T = TypeVar('T')
def _get_parent_of_type(item: dcg.baseItem, parent_type: type[T]) -> T | None:
    """
    Find the first ancestor of a specific type.
    
    Walks up the parent chain until finding an instance of the requested type.
    Useful for locating containing NodeEditor, Window, or other parent widgets.
    
    Args:
        item: The item to start searching from
        parent_type: The type to search for (e.g., NodeEditor, Window)
        
    Returns:
        The first parent matching the type, or None if not found
    """
    current = item.parent
    while current is not None:
        if isinstance(current, parent_type):
            return current
        current = current.parent
    return None

# Note: the _get_current methods are needed because of current
# DCG scaling limitations that may be addressed in future versions.
# They are needed for wheel DPI scaling to work properly in NodeEditors.

def _get_current_dpi_scale(item: dcg.uiItem) -> float:
    """
    Get the current DPI scale factor for an item.
    
    Walks up the parent chain to accumulate scaling factors,
    up to the viewport level where the screen dpi is retrieved.
    """
    scale = 1.0
    current = item
    while current is not None and not isinstance(current, dcg.Viewport):
        scale *= current.scaling_factor
        current = current.parent
    if isinstance(current, dcg.Viewport):
        # viewport has both scale and dpi
        scale *= current.dpi * current.scale
    return scale

def _get_current_font(item: dcg.uiItem) -> dcg.Font | None:
    """
    Get the current font for an item.
    
    Walks up the parent chain to find the first font assigned,
    up to the viewport level where the default font is retrieved.
    """
    current = item
    while current is not None:
        if current.font is not None:
            return current.font
        current = current.parent
    return None

def _get_current_style(item: dcg.uiItem) -> dcg.ThemeStyleImGui:
    """
    Get the current theme style for an item.
    """
    theme = dcg.ThemeStyleImGui(item.context)
    for attribute in dir(dcg.ThemeStyleImGui):
        try:
            setattr(theme, attribute, dcg.resolve_theme(item, dcg.ThemeStyleImGui, attribute))
        except:
            pass # all attributes that are not theme components

    return theme

"""
===========================================================================
Base classes (building blocks) to build custom Node Editors
===========================================================================
BaseNodeEditor:
    Base class to create a node editor container. It is
    composed of three layers: background, nodes, and foreground.

    The background layer can be used to draw background elements (grid, patterns, etc).
    The nodes layer holds BaseNode instances.
    The foreground layer can be used to draw links and highlights.

    In this base class, there is no notion of pins. Any item can act as one.

BaseNode:
    Base class for nodes in the NodeEditor. It is a ChildWindow
    that can contain any uiItem. Nodes are pinned to other items
    (for instance a title bar) using pin_to().

BaseLink:
    Base class for links between two uiItems in the NodeEditor.
    It draws a cubic Bezier curve between the two items and updates
    its position when either item moves.

As a design choice, no particular structures are used to directly list
links, nodes, or to retrieve the current NodeEditor from a node or link.
Retrieving these structures is done using parent or children traversal functions,
and thus are easily compatible with extensions.

In addition all node and link management goes through the NodeEditor instance.
This allows for maximum flexibility in defining what a node or link is.
"""


class BaseNodeEditor(dcg.ChildWindow):
    """
    SubWindow that contains nodes and links between them.

    Nodes are instances of BaseNode (or subclasses) and links are instances of BaseLink (or subclasses).
    Rendering is performed using three layers:
    - Background layer: for background drawings (textured pattern, grid, etc)
        It contains items subclassing drawingItem.
    - Nodes layer: for the nodes themselves, which are BaseNode instances.
        Note BaseNode is a ChildWindow, so it can contain any uiItem.
    - Foreground layer: for foreground drawings (links between nodes, highlights, etc)
        It contains items subclassing drawingItem.

    All layers are contained within a single ChildWindow (the canvas). This enables
    to implement panning and zooming by manipulating the canvas position and scale.

    """
    __slots__ = {
        '_background': 'DrawInWindow for background layer drawings',
        '_canvas': 'Container for the entire node editor',
        '_foreground': 'DrawInWindow for foreground layer drawings (links, highlights)',
        '_nodes': 'Layout container holding all node instances'
    }
    
    def __init__(self, C: dcg.Context, **kwargs) -> None:
        kwargs.setdefault("no_scrollbar", True)
        kwargs.setdefault("no_scroll_with_mouse", True)
        super().__init__(C, **kwargs)

        with self:
            with dcg.ChildWindow(C,
                                 border=False,
                                 no_inputs=True,
                                 no_background=True,
                                 no_scroll_with_mouse=True,
                                 no_scrollbar=True,
                                 x=self.x.x1,
                                 y=self.y.y1,
                                 width=128000,
                                 height=128000,
                                 ) as self._canvas:
                # Background drawings, convering the full inner region
                self._background = dcg.DrawInWindow(C,
                                                    x=self._canvas.x.x1, y=self._canvas.y.y1,
                                                    width=self._canvas.width.content_width,
                                                    height=self._canvas.height.content_height,
                                                    no_global_scaling=False
                                                    )
                # Node subcontainer
                self._nodes = dcg.ChildWindow(C,
                                              border=False,
                                              no_inputs=True,
                                              no_background=True,
                                              no_scroll_with_mouse=True,
                                              no_scrollbar=True,
                                              x=self._canvas.x.x1,
                                              y=self._canvas.y.y1,
                                              width=self._canvas.width.content_width,
                                              height=self._canvas.height.content_height,
                                              # We catch the font and the theme as it is currently needed to have scaling_factor apply to them
                                              # a drawback is that future changes won't be propagated
                                              font=_get_current_font(self),
                                              theme=_get_current_style(self)
                                              )
                # foreground drawings, on top of nodes
                # We encapsulate it in a ChildWindow to ensure rendering order
                with dcg.ChildWindow(C,
                                     border=False,
                                     no_inputs=True,
                                     no_background=True,
                                     no_scroll_with_mouse=True,
                                     no_scrollbar=True,
                                     x=self._canvas.x.x1,
                                     y=self._canvas.y.y1,
                                     width=self._canvas.width.content_width,
                                     height=self._canvas.height.content_height
                                     ):
                    self._foreground = \
                        dcg.DrawInWindow(C,
                                        x=self._canvas.x.x1,
                                        y=self._canvas.y.y1,
                                        width=self._canvas.width.content_width,
                                        height=self._canvas.height.content_height,
                                        no_global_scaling=True
                                        )

    def add_node(self, **kwargs) -> 'BaseNode':
        """Create and return a new node"""
        return BaseNode(self.context, parent=self._nodes, **kwargs)

    def add_link(self,
                 start: dcg.uiItem,
                 end: dcg.uiItem) -> 'BaseLink':
        """Add a link between two elements"""
        return BaseLink(self.context, start=start, end=end,
              parent=self._foreground)

    def attach_node(self, node: 'BaseNode') -> None:
        """Attach a node created elsewhere to this editor"""
        if not isinstance(node, BaseNode):
            raise TypeError("node must be a subclass of BaseNode")
        node.parent = self._nodes

    def canvas_to_screen(self, canvas_pos: dcg.Coord) -> dcg.Coord:
        """Convert a position from canvas space to viewport space"""
        return canvas_pos + self._nodes.state.pos_to_viewport

    def delete_link(self, link: 'BaseLink') -> None:
        """Delete a link from the editor"""
        if not isinstance(link, BaseLink):
            raise TypeError("link must be of type BaseLink")
        if link.parent is not self._foreground:
            raise ValueError("link is not a child of this NodeEditor")
        link.delete_item()

    def delete_links_of_node(self, node: 'BaseNode', start=True, end=True) -> None:
        """Delete all links connected to a node

        Args:
            node (BaseNode): The node to delete links for
            start (bool): If True, include links where the node is the start
            end (bool): If True, include links where the node is the end
        """
        # Remove all links connected to the node
        for link in self.get_links_of_node(node, start=start, end=end):
            self.delete_link(link)

    def delete_node(self, node: 'BaseNode') -> None:
        """Delete a node from the editor"""
        if not isinstance(node, BaseNode):
            raise TypeError("node must be of type BaseNode")
        if node.parent is not self._nodes:
            raise ValueError("node is not a child of this NodeEditor")

        # Remove all links connected to the node
        self.delete_links_of_node(node)

        # Remove the node itself
        node.delete_item()

    def get_content_area(self) -> dcg.ChildWindow:
        """Get the content area (canvas) containing nodes
        
        This method should not be used to attach node
        (use attach_node() instead), but can be used
        to retrieve the current states of the content
        area, as well as the references to its borders.
        """
        return self._nodes

    def get_foreground_area(self) -> dcg.DrawInWindow | dcg.DrawingList:
        """Get the foreground area containing links
        
        This method can be used to draw custom elements
        on top of nodes
        """
        return self._foreground

    def get_links(self) -> list['BaseLink']:
        """Return all links in the editor"""
        return [child for child in self._foreground.children if isinstance(child, BaseLink)]

    def get_links_of_node(self, node: 'BaseNode', start=True, end=True) -> list['BaseLink']:
        """Return all links connected to a node
        
        Args:
            node (BaseNode): The node to get links for
            start (bool): If True, include links where the node is the start
            end (bool): If True, include links where the node is the end
        """
        if not isinstance(node, BaseNode):
            raise TypeError("node must be of type BaseNode")
        if node.parent is not self._nodes:
            raise ValueError("node is not a child of this NodeEditor")

        # Retrieve all children recursively
        subitems = _get_children_recursively(node)

        # Retrieve all links connected to the node
        links = []
        for child in self._foreground.children:
            if isinstance(child, BaseLink):
                if (start and child.start in subitems)\
                    or (end and child.end in subitems):
                    links.append(child)
        return links

    def get_nodes(self) -> list['BaseNode']:
        """Return all nodes in the editor"""
        return [child for child in self._nodes.children if isinstance(child, BaseNode)]

    def screen_to_canvas(self, viewport_pos: dcg.Coord) -> dcg.Coord:
        """Convert a position from viewport space to canvas space"""
        return viewport_pos - self._nodes.state.pos_to_viewport


class BaseNode(dcg.ChildWindow):
    """
    Base node class to subclass for the NodeEditor.

    A node is a ChildWindow that can contain any uiItem of your choice.
    It can be pinned to one of its subitems or another item using pin_to().
    """
    __slots__ = {}
    
    def __init__(self, C: dcg.Context, **kwargs) -> None:
        super().__init__(C, **kwargs)

    @property
    def node_editor(self) -> BaseNodeEditor | None:
        """Get the parent NodeEditor of this node, or None if not inside one"""
        return _get_parent_of_type(self, BaseNodeEditor)

    def contains(self, item: dcg.uiItem) -> bool:
        """Check if the node contains the given item"""
        return item in _get_children_recursively(self)

    def move_to_front(self) -> None:
        """Move the node to the front of the nodes"""
        self.parent = self.parent  # Re-assign to move to end of children list

    def pin_to(self,
               item: dcg.uiItem,
               delta_x: str | dcg.baseSizing | float | int | None = None,
               delta_y: str | dcg.baseSizing | float | int | None = None) -> None:
        """Pin the node to a given item (make it follow the item).

        Args:
            item (uiItem): The item to pin to. The item can be a child of the node (for instance a draggable title bar)
            delta_x (str | BaseSizing | float | int | None): Optional x offset from the item's position
            delta_y (str | BaseSizing | float | int | None): Optional y offset from the item's position
        If the deltas are None, the current offset is used.
        """
        if not isinstance(item, dcg.uiItem):
            raise TypeError("item must be of type uiItem")

        if delta_x is None:
            # Resolve current delta
            delta_x = dcg.Size.FIXED(self.x.value - item.x.value)
        if delta_y is None:
            # Resolve current delta
            delta_y = dcg.Size.FIXED(self.y.value - item.y.value)

        if isinstance(delta_x, (float, int)):
            delta_x = dcg.Size.MULTIPLY(dcg.Size.FIXED(float(delta_x)), dcg.Size.DPI())
        if isinstance(delta_y, (float, int)):
            delta_y = dcg.Size.MULTIPLY(dcg.Size.FIXED(float(delta_y)), dcg.Size.DPI())

        if isinstance(delta_x, str):
            delta_x = dcg.Size.from_expression(delta_x)
        if isinstance(delta_y, str):
            delta_y = dcg.Size.from_expression(delta_y)


        self.x = item.x.x0 + delta_x
        self.y = item.y.y0 + delta_y


class BaseLink(dcg.DrawingList):
    """
    Base link between two items in the NodeEditor.

    A link is a drawing visual (DrawingList) drawn on the foreground of the NodeEditor,
    It connects two uiItems (start and end). The base link uses a cubic Bezier curve,
    but it can be replaced by subclassing and overriding _draw_link().
    """
    __slots__ = {
        '_color': 'Color tuple for the link line',
        '_control_points': 'Tuple of bezier curve control points',
        '_end': 'End uiItem that the link connects to',
        '_motion_handler': 'Handler tracking position changes of connected items',
        '_pattern': 'Optional line pattern for the link',
        '_start': 'Start uiItem that the link connects from',
        '_thickness': 'Line thickness for rendering',
    }
    
    def __init__(self,
                 C: dcg.Context,
                 start: dcg.uiItem,
                 end: dcg.uiItem,
                 color=(255, 255, 255),
                 thickness=-3.0,
                 pattern: dcg.Pattern | None = None,
                 **kwargs) -> None:
        """
        Args:
            C (Context): The context of the link
            start (uiItem): The start item of the link
            end (uiItem): The end item of the link

        Both start and end can be any uiItem, from inside or outside nodes,
        but must be inside the same NodeEditor (for clipping)
        """
        super().__init__(C, **kwargs)
        self._start: dcg.uiItem = start
        self._end: dcg.uiItem = end
        self._color = color
        self._thickness = thickness
        self._pattern = pattern
        self._control_points = ((0.0, 0.0), (0.0, 0.0), (0.0, 0.0), (0.0, 0.0))
        self._setup_motion_handler()
        self._update_position()

    """
    Motion handling.

    Override these to customize how the link updates its position
    """

    def _setup_motion_handler(self) -> None:
        """Setup motion handler to track position changes of connected items"""
        self._motion_handler = dcg.MotionHandler(self.context,
            pos_policy=(dcg.Positioning.REL_VIEWPORT, dcg.Positioning.REL_VIEWPORT),
            callback=self._update_position)

        with self._start.mutex:
            self._start.handlers += [
                self._motion_handler
            ]
        with self._end.mutex:
            self._end.handlers += [
                self._motion_handler
        ]

    def _cleanup_motion_handler(self) -> None:
        """Cleanup motion handler from connected items"""
        with self._start.mutex:
            self._start.handlers = [h for h in self._start.handlers if h is not self._motion_handler]
        with self._end.mutex:
            self._end.handlers = [h for h in self._end.handlers if h is not self._motion_handler]

    """
    Generic utils
    """

    def delete_item(self) -> None:
        """Delete the link and remove handlers"""
        self._cleanup_motion_handler()
        super().delete_item()

    @property
    def node_editor(self) -> BaseNodeEditor | None:
        """Get the parent NodeEditor of this node, or None if not inside one"""
        return _get_parent_of_type(self, BaseNodeEditor)

    @property
    def start(self) -> dcg.uiItem:
        """The start item of the link"""
        return self._start

    @property
    def start_node(self) -> BaseNode | None:
        """The start node of the link, or None if not inside a node"""
        return _get_parent_of_type(self._start, BaseNode)

    @property
    def end(self) -> dcg.uiItem:
        """The end item of the link"""
        return self._end

    @property
    def end_node(self) -> BaseNode | None:
        """The end node of the link, or None if not inside a node"""
        return _get_parent_of_type(self._end, BaseNode)

    """
    Link drawing.

    Override these to customize how the link looks.
    """

    def _draw_link(self,
                   start_pos: tuple[float, float],
                   end_pos: tuple[float, float]) -> None:
        """Draw the link between two positions
        
        This method is called whenever the position of either the start or end item changes.
        """
        (p1, p2, p3, p4) = _get_bezier_control_points(start_pos, end_pos)

        if (p1, p2, p3, p4) == self._control_points:
            # No need to update
            return

        # Clear previous drawings
        self.children = []

        self._control_points = (p1, p2, p3, p4)

        with self:
            dcg.DrawBezierCubic(
                self.context,
                p1=p1,
                p2=p2,
                p3=p3,
                p4=p4,
                color=self._color,
                thickness=self._thickness,
                pattern=self._pattern)

        # refresh
        self.context.viewport.wake()

    """
    Hit-testing utilities.
    """

    def distance_to_link(self, point: tuple[float, float]) -> float:
        """Calculate distance from a point to the link curve
        
        This method is used for hit-testing and selection.
        """
        (p1, p2, p3, p4) = self._control_points
        return _distance_point_to_bezier(point, p1, p2, p3, p4)

    def is_link_in_area(self,
                        area: dcg.Rect) -> bool:
        """Check if the link intersects a rectangular area
        
        This method is used for selection box testing.
        """
        (p1, p2, p3, p4) = self._control_points

        # Check if bounding box of curve intersects area
        min_x = min(p1[0], p4[0])
        max_x = max(p1[0], p4[0])
        min_y = min(p1[1], p4[1])
        max_y = max(p1[1], p4[1])
        whole_rect = dcg.Rect(x1=min_x, y1=min_y, x2=max_x, y2=max_y)
        intersects = not (whole_rect.x2 < area.x1 or
                          whole_rect.x1 > area.x2 or
                          whole_rect.y2 < area.y1 or
                          whole_rect.y1 > area.y2)
        if not intersects:
            return False

        # Sample points along the curve and check if any are inside the area
        num_samples = 20
        for i in range(num_samples + 1):
            t = i / num_samples
            x, y = _point_on_cubic_bezier(p1, p2, p3, p4, t)
            if (x, y) in area:
                return True
        return False

    def is_link_fully_in_area(self,
                              area: dcg.Rect) -> bool:
        """Check if the entire link is inside a rectangular area
        
        This method is used for selection box testing.
        """
        (p1, p2, p3, p4) = self._control_points

        if p1 in area and p4 in area:
            return True
        return False
        

    """
    Position computation
    """

    def _update_position(self) -> None:
        """Retrieve the position of the start and end items and update the link position"""
        start_state: dcg.ItemStateView = self._start.state
        stop_state: dcg.ItemStateView = self._end.state

        node_editor = self.node_editor
        if node_editor is None:
            raise ValueError("link must be inside a NodeEditor")

        ref_state = node_editor.get_content_area().state

        if (not ref_state.visible and ref_state.pos_to_viewport.x == 0)\
            or (not start_state.visible and start_state.pos_to_viewport.x == 0)\
            or (not stop_state.visible and stop_state.pos_to_viewport.x == 0):
            return # One of the items is not visible, position states are invalid

        ref_position: dcg.Coord = ref_state.pos_to_viewport
        start = start_state.pos_to_viewport + start_state.rect_size * 0.5 - ref_position
        end = stop_state.pos_to_viewport + stop_state.rect_size * 0.5 - ref_position

        start_pos: tuple[float, float] = (start.x, start.y)
        end_pos: tuple[float, float] = (end.x, end.y)

        self._draw_link(start_pos, end_pos)

        self.context.viewport.wake()


class BaseDraggableButton(dcg.Button):
    """
    A button that can be dragged around, useful for Node title bars or draggable UI elements.
    
    This base class provides:
    - Dragging the button in reference to a specified item (or parent if none)
    - Optional clamping to keep the item within reference bounds

    Subclasses can override drag behavior or add visual feedback.
    """
    __slots__ = {
        '_dragging_original_pos': 'Stored position before drag starts',
        '_no_clamp': 'If False, clamps position to reference content area',
        '_ref_item': 'Reference item for motion calculations',
    }
    
    def __init__(self, C: dcg.Context, 
                 ref_item: dcg.uiItem | None = None,
                 no_clamp: bool = False,
                 **kwargs) -> None:
        """
        Args:
            C: The context
            ref_item: Reference item for drag motion. If None, uses parent.
            no_clamp: If False (default), prevents center from leaving reference content area
            **kwargs: Additional button parameters
        """
        super().__init__(C, **kwargs)
        self._ref_item = ref_item
        self._no_clamp = no_clamp
        self._dragging_original_pos = None
        self._setup_drag_handlers()
        self._setup_init_handler()

    def _setup_init_handler(self) -> None:
        """*May be removed in the future* Wait until first render to introduce dpi scaling"""
        def move_to_init(self=self):
            """Set up the dpi position mecanics on init"""
            ref_item = self._get_ref_item()
            if ref_item is None:
                ref_item = self.parent
                if ref_item is None:
                    return  # No reference available
                assert isinstance(ref_item, dcg.uiItem)
            current_pos = self.state.pos_to_viewport
            try:
                ref_pos = ref_item.state.content_pos
            except AttributeError:
                ref_pos = ref_item.state.pos_to_viewport
            relative_pos = current_pos - ref_pos
            self._move_to(ref_item, relative_pos)
        init_handler = dcg.GotRenderHandler(self.context, callback=move_to_init)

        # spawn only once
        auto_cleanup_handler(init_handler)

        self.handlers += [init_handler]

    def _get_ref_item(self) -> dcg.uiItem | None:
        """Get the reference item for motion calculations.
        
        This method can be overridden in subclasses to provide custom logic
        for determining the reference item.
        
        Returns:
            The reference item, or None if parent should be used
        """
        return self._ref_item
    
    def _setup_drag_handlers(self) -> None:
        """Setup handlers for dragging the button"""
        self.handlers += [
            dcg.DraggingHandler(self.context, callback=self._on_dragging),
            dcg.DraggedHandler(self.context, callback=self._on_dragged)
        ]
    
    def _clamp_position(self, 
                        pos: dcg.Coord,
                        ref_item: dcg.uiItem,
                        dragged_item: dcg.uiItem) -> dcg.Coord:
        """Clamp position to keep dragged item center within reference content area.
        
        Args:
            pos: Desired position (x, y) relative to reference
            ref_item: Reference item providing the bounds
            dragged_item: Item being dragged
            
        Returns:
            Clamped position (x, y)
        """
        # Get content area bounds of reference item
        try:
            ref_content = ref_item.state.content_region_avail
        except AttributeError:
            ref_content = ref_item.state.rect_size
        
        # Get size of dragged item (use half for center calculation)
        dragged_half_size = dragged_item.state.rect_size * 0.5
        
        # Clamp position to keep center within bounds
        x = max(-dragged_half_size.x, min(pos.x, ref_content.x - dragged_half_size.x))
        y = max(-dragged_half_size.y, min(pos.y, ref_content.y - dragged_half_size.y))

        return dcg.Coord(x, y)

    def _move_to(self, ref_item: dcg.uiItem, new_pos: dcg.Coord) -> None:
        """Move the button to a new position relative to reference item"""
        # Apply clamping if enabled
        if not self._no_clamp:
            new_pos = self._clamp_position(new_pos, ref_item, self)

        # Update position to follow the mouse motion.
        # x1/y1 refer to content_pos (with pos_to_viewport fallback).
        # Using them will make us follow automatically if the ref_item moves.
        current_dpi = _get_current_dpi_scale(self) # needed for wheel DPI scaling
        self.x = ref_item.x.x1 + dcg.Size.FIXED(new_pos.x) * dcg.Size.DPI() / current_dpi
        self.y = ref_item.y.y1 + dcg.Size.FIXED(new_pos.y) * dcg.Size.DPI() / current_dpi
    
    def _on_dragging(self, handler, target, drag_deltas):
        """Handle dragging event - stores position and calls callback"""
        # Get reference item
        ref_item = self._get_ref_item()

        # Fallback to parent if none
        if ref_item is None:
            ref_item = self.parent
            if ref_item is None:
                return  # No reference available
            assert isinstance(ref_item, dcg.uiItem)
        
        if self._dragging_original_pos is None:
            # Store original position relative to reference
            cur_pos = self.state.pos_to_viewport
            try:
                ref_pos = ref_item.state.content_pos
            except AttributeError:
                ref_pos = ref_item.state.pos_to_viewport
            self._dragging_original_pos = cur_pos - ref_pos

        # Calculate new position
        new_pos = self._dragging_original_pos + drag_deltas

        # Move to new position
        self._move_to(ref_item, new_pos)
    
    def _on_dragged(self, handler, target, drag_deltas):
        """Handle drag complete - resets tracking state"""
        self._dragging_original_pos = None


# ============================================================================
# Simple Node editor with simple look and interactions
# ============================================================================

class SimplePinShape(StrEnum):
    """Simple Pin shapes"""
    CIRCLE = "circle"
    SQUARE = "square"
    TRIANGLE = "triangle"
    DIAMOND = "diamond"

class SimpleGridStyle(StrEnum):
    """Simple Grid styles"""
    NONE = "none"
    DOTS = "dots"
    LINES = "lines"
    CROSSES = "crosses"

class SimpleNodeEditorTheme:
    """Simple Node Editor theme colors and styles"""
    background_color: 'dcg.Color' = (30, 30, 30, 255)
    grid_color: 'dcg.Color' = (50, 50, 50, 200)
    grid_style: SimpleGridStyle = SimpleGridStyle.LINES
    grid_spacing: int = 64 # Size of grid cells in pixels

    node_background_color: 'dcg.Color' = (60, 60, 60, 255)
    node_border_color: 'dcg.Color' = (100, 100, 100, 255)

    node_title_bg_color: 'dcg.Color' = (45, 45, 45, 255)
    node_title_text_color: 'dcg.Color' = (220, 220, 220, 255)
    node_title_border_color: 'dcg.Color' = (80, 80, 80, 255)
    node_title_hover_color: 'dcg.Color' = (70, 70, 70, 255)
    node_title_active_color: 'dcg.Color' = (90, 90, 90, 255)
    node_title_scale: float = 1.5

    # Pin/link colors
    color_map: dict[str, 'dcg.Color'] = {
        'flow': (255, 255, 255, 255),
        'bool': (220, 48, 48, 255),
        'int': (68, 201, 156, 255),
        'float': (147, 226, 74, 255),
        'string': (218, 95, 218, 255),
        'vector': (255, 220, 40, 255),
        'object': (51, 150, 215, 255),
        'any': (160, 160, 160, 255),
    }

    # Pin shapes
    shape_map: dict[str, SimplePinShape] = {
        'flow': SimplePinShape.CIRCLE,
        'bool': SimplePinShape.DIAMOND,
        'int': SimplePinShape.SQUARE,
        'float': SimplePinShape.TRIANGLE,
        'string': SimplePinShape.DIAMOND,
        'vector': SimplePinShape.TRIANGLE,
        'object': SimplePinShape.SQUARE,
        'any': SimplePinShape.CIRCLE,
    }

    # None: use color from color_map
    # float: use a factor to darken/lighten the color from color_map
    # Color: use this color directly
    pin_fill_color: 'dcg.Color | float | None' = None
    pin_fill_hover_color: 'dcg.Color | float | None' = 1.2
    pin_border_color: 'dcg.Color | float | None' = None
    pin_border_hover_color: 'dcg.Color | float | None' = 1.2
    pin_border_thickness: float = 0.1 # in proportion of pin size
    pin_border_hover_thickness: float = 0.13 # in proportion of pin size

    link_color: 'dcg.Color | float | None' = None
    link_selected_color: 'dcg.Color | float | None' = 1.2
    link_thickness: float = 1.8

    # Optional modifier or key that must be held to start a drag from a pin
    drag_mod : dcg.Key | None = None
    # button used to drag from a pin
    drag_button_key : dcg.MouseButton = dcg.MouseButton.LEFT

    def add_type(self,
                 type_name: str,
                 color: 'dcg.Color',
                 shape: SimplePinShape) -> None:
        """Add a new type to the theme"""
        if not isinstance(type_name, str):
            raise TypeError("type_name must be a string")
        try:
            color = dcg.color_as_ints(color)
        except Exception:
            raise TypeError("color must be dcg.Color compatible")
        # No check for shape, as user might implement custom shapes
        self.color_map[type_name] = color
        self.shape_map[type_name] = shape

def _resolve_color(base_color: 'dcg.Color',
                   modifier: 'dcg.Color | float | None') -> 'dcg.Color':
    """Resolve a color modifier on a base color"""
    if modifier is None:
        return base_color
    if isinstance(modifier, float):
        # Apply factor in yuv space
        r, g, b, a = dcg.color_as_ints(base_color)
        y = 0.299 * r + 0.587 * g + 0.114 * b
        u = 0.492 * (b - y)
        v = 0.877 * (r - y) 
        y *= modifier
        r = int(y + 1.140 * v)
        g = int(y - 0.395 * u - 0.581 * v)
        b = int(y + 2.032 * u)
        r = max(0, min(255, r))
        g = max(0, min(255, g))
        b = max(0, min(255, b))
        return (r, g, b, a)
    return modifier


class SimplePin(dcg.DrawInWindow):
    """
    Base Pin class with simple look.

    The SimplePin class represents a pin (where link connects) in a node editor.
    It implements:
    - Simple static shapes (circle, square, triangle, diamond)
    - Basic configurable colors and theme from SimpleNodeEditorTheme
    - Basic drag and drop interactions for connecting pins

    To extend it, you can subclass and override:
    - _draw(): to customize the pin appearance
    - _setup_handlers() and _update_handlers(): to customize drag and drop behavior,
         or add new interactions

    When no theme is provided, the pin will try to retrieve the theme from its parent node
    or node editor, and fallback to a default one if none is found.
    """
    __slots__ = {
        '_accepted_drops': 'List of accepted drop type names',
        '_drag_type': 'Type name used when dragging from this pin',
        '_drag_handler': 'Handler for drag interactions',
        '_drag_mouse_handler': 'Handler for drag mouse button interactions',
        '_drag_mod_handler': 'Handler for the optional modifier key used to start drag',
        '_drop_handler': 'Handler for drop interactions',
        '_fill_color': 'Requested fill color of the pin',
        '_outline_color': 'Requested outline color of the pin',
        '_node_editor_theme': 'Theme to use for the pin colors',
        '_shape': 'Requested shape of the pin',
        '_type_name': 'Type name of the pin for color mapping',
    }
    def __init__(self,
                 C: dcg.Context,
                 accepted_drops: str | Sequence[str] | None = None,
                 drag_type: str | None = None,
                 fill_color: 'dcg.Color' | None = None,
                 outline_color: 'dcg.Color' | None = None,
                 node_editor_theme: SimpleNodeEditorTheme | None = None,
                 shape: SimplePinShape | None = None,
                 type_name: str = "any",
                 **kwargs) -> None:
        """Simple pin constructor
         Args:
            C: The context of the pin
            accepted_drops: accepted type name accepted for drag and drop (string or list of strings).
               if None, no drag and drop is accepted. If "*", all types are accepted.
            drag_type: type name used when dragging from this pin (string). If None, no drag is possible.
            fill_color: Override fill color of the pin. If None, use theme color.
            outline_color: Override outline color of the pin. If None, use theme color.
            node_editor_theme: Theme to use for the pin colors. If None, use the one from the parent node or editor, or default.
            shape: Override shape of the pin. If None, use theme shape.
            type_name: Type name of the pin for color mapping
        """
        self._type_name = type_name
        self._fill_color = fill_color
        self._outline_color = outline_color
        self._shape = shape
        self._accepted_drops = accepted_drops
        self._drag_type = drag_type

        kwargs.setdefault("width", self.height)
        kwargs.setdefault("relative", True)
        kwargs.setdefault("button", True)
        super().__init__(C, **kwargs)

        if node_editor_theme is None:
            node_editor_theme = self._deduce_theme()

        self._node_editor_theme = node_editor_theme

        self._draw()
        self._setup_handlers()

    @property
    def type_name(self) -> str:
        """The type name of the pin"""
        return self._type_name

    @type_name.setter
    def type_name(self, value: str) -> None:
        self._type_name = value
        self._draw()

    @property
    def node(self) -> BaseNode | None:
        """Get the parent Node of this node, or None if not inside one"""
        return _get_parent_of_type(self, BaseNode)

    @property
    def node_editor(self) -> BaseNodeEditor | None:
        """Get the parent NodeEditor of this node, or None if not inside one"""
        return _get_parent_of_type(self, BaseNodeEditor)

    @property
    def node_editor_theme(self) -> SimpleNodeEditorTheme:
        """The node editor theme used by the pin"""
        return self._node_editor_theme

    @node_editor_theme.setter
    def node_editor_theme(self, value: SimpleNodeEditorTheme | None) -> None:
        if not isinstance(value, SimpleNodeEditorTheme) and value is not None:
            raise TypeError("node_editor_theme must a SimpleNodeEditorTheme instance or None")
        if value is None:
            value = self._deduce_theme()
        self._node_editor_theme = value
        self._update_handlers()
        self._draw()

    @property
    def shape(self) -> SimplePinShape | None:
        """Override shape of the pin"""
        return self._shape

    @shape.setter
    def shape(self, value: SimplePinShape | None) -> None:
        self._shape = value
        self._draw()

    @property
    def fill_color(self) -> 'dcg.Color' | None:
        """Override fill color of the pin"""
        return self._fill_color

    @fill_color.setter
    def fill_color(self, value: 'dcg.Color' | None) -> None:
        self._fill_color = value
        self._draw()

    @property
    def outline_color(self) -> 'dcg.Color' | None:
        """Override outline color of the pin"""
        return self._outline_color

    @outline_color.setter
    def outline_color(self, value: 'dcg.Color' | None) -> None:
        self._outline_color = value
        self._draw()

    def _get_default_theme(self) -> SimpleNodeEditorTheme:
        """Retrieve the default theme for the pin"""
        return SimpleNodeEditorTheme()

    def _deduce_theme(self) -> SimpleNodeEditorTheme:
        """Deduce the theme from parent node or editor"""
        parent_node = _get_parent_of_type(self, BaseNode)
        if hasattr(parent_node, 'node_editor_theme'):
            return getattr(parent_node, 'node_editor_theme')
        parent_editor = _get_parent_of_type(self, BaseNodeEditor)
        if hasattr(parent_editor, 'node_editor_theme'):
            return getattr(parent_editor, 'node_editor_theme')
        return self._get_default_theme()

    def _setup_handlers(self) -> None:
        """Setup handlers to handling of interactions"""
        # Add handlers for visual feedback and drag-drop
        C = self.context

        # Dragging away from this pin
        with dcg.ConditionalHandler(C, enabled=self._drag_type is not None) as conditional_drag_handler:
            drag_type = self._drag_type if self._drag_type is not None else ""
            self._drag_handler = \
                dcg.DragDropSourceHandler(C,
                                          drag_type=drag_type,
                                          callback=self._on_drag_start)
            self._drag_mouse_handler = \
                dcg.ClickedHandler(C,
                                   button=self.node_editor_theme.drag_button_key)  # Only start drag on click
            key = self.node_editor_theme.drag_mod
            if key is None:
                key = dcg.Key.A # Dummy key that is never checked
            self._drag_mod_handler = \
                dcg.KeyDownHandler(C,
                                   key=key,
                                   enabled=self.node_editor_theme.drag_mod is not None)  # Only start drag with modifier

        # Dropping onto this pin
        drop_types = []
        if self._accepted_drops is not None:
            if isinstance(self._accepted_drops, str):
                if self._accepted_drops == "*":
                    drop_types = []  # Accept all types
                else:
                    drop_types = [self._accepted_drops]
            else:
                drop_types = self._accepted_drops
        drop_types = ["item_" + t for t in drop_types]
        self._drop_handler = \
            dcg.DragDropTargetHandler(C, 
                                      accepted_types=drop_types,
                                      enabled=self._accepted_drops is not None, 
                                      callback=self._on_drop_received)

        self.handlers += [
            dcg.GotHoverHandler(self.context, callback=self._on_hover),
            dcg.LostHoverHandler(self.context, callback=self._on_unhover),
            conditional_drag_handler,
            self._drop_handler
        ]
        if self._accepted_drops is not None:
            self.handlers.append(self._drop_handler)

    def _update_handlers(self) -> None:
        """Update handlers based on current settings"""
        # Update drag handler
        if self._drag_type is None:
            self._drag_handler.enabled = False
        else:
            self._drag_handler.enabled = True
            self._drag_handler.drag_type = self._drag_type
        self._drag_mouse_handler.button = self.node_editor_theme.drag_button_key
        if self.node_editor_theme.drag_mod is None:
            self._drag_mod_handler.enabled = False
        else:
            self._drag_mod_handler.enabled = True
            self._drag_mod_handler.key = self.node_editor_theme.drag_mod

        # Update drop handler
        drop_types = []
        if self._accepted_drops is not None:
            if isinstance(self._accepted_drops, str):
                if self._accepted_drops == "*":
                    drop_types = []  # Accept all types
                else:
                    drop_types = [self._accepted_drops]
            else:
                drop_types = self._accepted_drops
        drop_types = ["item_" + t for t in drop_types]
        if self._accepted_drops is None:
            self._drop_handler.enabled = False
        else:
            self._drop_handler.enabled = True
            self._drop_handler.accepted_types = drop_types

    def _on_hover(self) -> None:
        """Called when the pin is hovered"""
        self._draw()

    def _on_unhover(self) -> None:
        """Called when the pin is no longer hovered"""
        self._draw()

    def _on_drag_start(self, handler, item, data) -> None:
        """Called when a drag is started from this pin"""
        pass  # Can be extended in subclasses

    def _on_drop_received(self, handler, item, data) -> None:
        """Called when a drop is received on this pin"""
        pass  # Can be extended in subclasses

    def _draw(self):
        self.children = []

        # Resolve theme
        type_name = self.type_name
        fill_color = self.fill_color
        outline_color = self.outline_color
        shape = self.shape
        theme = self.node_editor_theme
        hovered = self.state.hovered


        fill_color = _resolve_color(
            theme.color_map.get(type_name, (160, 160, 160, 255)),
            theme.pin_fill_color
        )
        outline_color = _resolve_color(
            theme.color_map.get(type_name, (160, 160, 160, 255)),
            theme.pin_border_color
        )

        if hovered:
            fill_color = _resolve_color(
                fill_color,
                theme.pin_fill_hover_color
            )
            outline_color = _resolve_color(
                outline_color,
                theme.pin_border_hover_color
            )

        if shape is None:
            shape = theme.shape_map.get(type_name, SimplePinShape.CIRCLE)

        thickness = theme.pin_border_thickness
        if hovered:
            thickness = theme.pin_border_hover_thickness

        npoints = 0
        direction_angle = 0
        if shape == SimplePinShape.TRIANGLE:
            npoints = 3
            direction_angle = 3.1415 / 2.0  # Pointing top
        elif shape == SimplePinShape.SQUARE:
            npoints = 4
            direction_angle = 3.1415 / 4.0  # Pointing top-right
        elif shape == SimplePinShape.DIAMOND:
            npoints = 4

        radius = 0.35
        if thickness > 0. and thickness < 1.:
            radius = radius * (1. - thickness)

        with self:
            dcg.DrawRegularPolygon(
                self.context,
                center=(0.5, 0.5),
                radius=radius,
                thickness=thickness,
                direction=direction_angle,
                color=outline_color,
                fill=fill_color,
                num_points=npoints
            )


class SimpleLink(BaseLink):
    """A BaseLink with handling of the SimpleNodeEditorTheme for colors and thickness"""
    __slots__ = {
        '_color_override': 'Override color for the link line',
        '_node_editor_theme': 'Theme to use for the link colors and thickness',
        '_type_name': 'Type name of the link for color mapping',
        '_selected': 'Boolean indicating if link is selected',
    }
    
    def __init__(self,
                 C: dcg.Context,
                 start: dcg.uiItem,
                 end: dcg.uiItem,
                 color: 'dcg.Color' | None = None,
                 node_editor_theme: SimpleNodeEditorTheme | None = None,
                 type_name: str | None = None,
                 **kwargs) -> None:
        """Simple link constructor
        
        Args:
            C: The context of the link
            start: The start item of the link
            end: The end item of the link
            color: Override color of the link. If None, use theme color based on pins.
            node_editor_theme: Theme to use for the link colors and thickness. If None, use the one from the parent editor, or default.
            type_name: Type name of the link for color mapping. If None, deduced from connected pins.
        """
        self._selected = False
        
        self._color_override = color
        if type_name is None:
            type_name = self._deduce_type(start, end)
        self._type_name = type_name
        
        super().__init__(C, start=start, end=end, **kwargs)

        # We do it after parent init.
        if node_editor_theme is None:
            node_editor_theme = self._deduce_theme()
        self._node_editor_theme = node_editor_theme
        self._update_appearance()
    
    @property
    def node_editor_theme(self) -> SimpleNodeEditorTheme:
        """The node editor theme used by the link"""
        return self._node_editor_theme
    
    @node_editor_theme.setter
    def node_editor_theme(self, value: SimpleNodeEditorTheme | None) -> None:
        if not isinstance(value, SimpleNodeEditorTheme) and value is not None:
            raise TypeError("node_editor_theme must a SimpleNodeEditorTheme instance or None")
        if value is None:
            value = self._deduce_theme()
        self._node_editor_theme = value
        self._update_appearance()
    
    @property
    def selected(self) -> bool:
        """Whether the link is currently selected"""
        return self._selected
    
    @selected.setter
    def selected(self, value: bool) -> None:
        self._selected = bool(value)
        self._update_appearance()

    @property
    def type_name(self) -> str:
        """The type name of the link"""
        return self._type_name

    @type_name.setter
    def type_name(self, value: str) -> None:
        self._type_name = value
        self._update_appearance()

    def _get_default_theme(self) -> SimpleNodeEditorTheme:
        """Retrieve the default theme for the link"""
        return SimpleNodeEditorTheme()
    
    def _deduce_theme(self) -> SimpleNodeEditorTheme:
        """Deduce the theme from parent editor"""
        parent_editor = _get_parent_of_type(self, BaseNodeEditor)
        if hasattr(parent_editor, 'node_editor_theme'):
            return getattr(parent_editor, 'node_editor_theme')
        return self._get_default_theme()
    
    def _deduce_type(self, start: dcg.uiItem, end: dcg.uiItem) -> str:
        """Deduce link color based on connected pins"""
        # Try to get type from pins
        type_name = "any"
        start_pin = self._find_pin(start)
        if start_pin is not None and hasattr(start_pin, 'type_name'):
            type_name = start_pin.type_name
        else:
            end_pin = self._find_pin(end)
            if end_pin is not None and hasattr(end_pin, 'type_name'):
                type_name = end_pin.type_name
        return type_name
    
    def _find_pin(self, item: dcg.uiItem) -> SimplePin | None:
        """Find a SimplePin parent of the given item"""
        current = item
        while current is not None:
            if isinstance(current, SimplePin):
                return current
            current = current.parent
        return None
    
    def _calculate_appearance(self) -> tuple['dcg.Color', float]:
        """Calculate color and thickness based on current state"""
        # Determine color based on state
        if self._color_override is None:
            base_color = self._node_editor_theme.color_map.get(
                self._type_name,
                (160, 160, 160, 255)
            )
            base_color = _resolve_color(base_color, self._node_editor_theme.link_color)
        else:
            base_color = self._color_override
        
        if self._selected:
            color = _resolve_color(base_color, self._node_editor_theme.link_selected_color)
        else:
            color = base_color
        
        thickness = self._node_editor_theme.link_thickness
        
        return color, thickness
    
    def _update_appearance(self) -> None:
        """Update link appearance based on state"""
        color, thickness = self._calculate_appearance()
        self._color = color
        self._thickness = thickness
        
        # Force redraw
        self._control_points = (-1, -1, -1, -1)
        self._update_position()


class SimpleNodeTitleBar(BaseDraggableButton):
    """
    A themed title bar button for SimpleNode with dragging support.
    
    Features:
    - Dragging to move parent node
    - Theme support from SimpleNodeEditorTheme
    - Right-click context menu support
    - Visual feedback on hover/active states
    - Optional clamping to keep node within editor bounds
    
    The title bar automatically applies theme colors and styles,
    and can be extended with custom context menu items.
    """
    __slots__ = {
        '_context_menu_callback': 'Optional callback for context menu',
        '_node_editor_theme': 'Theme to use for the title bar',
    }
    
    def __init__(self,
                 C: dcg.Context,
                 context_menu_callback: Callable | None = None,
                 node_editor_theme: SimpleNodeEditorTheme | None = None,
                 no_clamp: bool = False,
                 **kwargs) -> None:
        """
        Args:
            C: The context
            context_menu_callback: Optional callback(sender, target) called on right-click
            node_editor_theme: Theme to use. If None, deduced from parent
            no_clamp: If False (default), prevents node from leaving editor bounds
            **kwargs: Additional button parameters (label, width, height, etc.)
        """
        self._context_menu_callback = context_menu_callback
        
        # Initialize base draggable button (ref_item will be resolved in _get_ref_item)
        super().__init__(C, ref_item=None, no_clamp=no_clamp, **kwargs)

        # Deduce theme if not provided
        if node_editor_theme is None:
            node_editor_theme = self._deduce_theme()
        self._node_editor_theme = node_editor_theme

        # Apply theme
        self.theme = self._create_title_theme(C)
        
        # Add additional handlers
        self._setup_title_handlers()
    
    def _get_ref_item(self) -> dcg.uiItem | None:
        """Get the NodeEditor as the reference item for drag motion.
        
        This override ensures the title bar drag is calculated relative to
        the NodeEditor's coordinate system, and clamping keeps nodes within
        the editor bounds.
        
        Returns:
            The parent NodeEditor, or None if not found
        """
        ref_item = super()._get_ref_item()
        if ref_item is not None:
            return ref_item
        node_editor = _get_parent_of_type(self, BaseNodeEditor)
        if node_editor is not None:
            return node_editor.get_content_area()
        return None
    
    @property
    def node_editor_theme(self) -> SimpleNodeEditorTheme:
        """The node editor theme used by the title bar"""
        return self._node_editor_theme
    
    @node_editor_theme.setter
    def node_editor_theme(self, value: SimpleNodeEditorTheme | None) -> None:
        if not isinstance(value, SimpleNodeEditorTheme) and value is not None:
            raise TypeError("node_editor_theme must be SimpleNodeEditorTheme instance or None")
        if value is None:
            value = self._deduce_theme()
        self._node_editor_theme = value
        self.theme = self._create_title_theme(self.context)
    
    def _deduce_theme(self) -> SimpleNodeEditorTheme:
        """Deduce theme from parent node or editor"""
        parent_node = _get_parent_of_type(self, BaseNode)
        if hasattr(parent_node, 'node_editor_theme'):
            return getattr(parent_node, 'node_editor_theme')
        parent_editor = _get_parent_of_type(self, BaseNodeEditor)
        if hasattr(parent_editor, 'node_editor_theme'):
            return getattr(parent_editor, 'node_editor_theme')
        return SimpleNodeEditorTheme()
    
    def _create_title_theme(self, C: dcg.Context) -> dcg.ThemeList:
        """Create theme for the title bar based on node editor theme"""
        theme = self._node_editor_theme
        
        with dcg.ThemeList(C) as title_theme:
            # Use node title colors from theme
            dcg.ThemeColorImGui(C,
                                button=theme.node_title_bg_color,
                                button_hovered=theme.node_title_hover_color,
                                button_active=theme.node_title_active_color,
                                text=theme.node_title_text_color,
                                border=theme.node_title_border_color)

            #cur_rounding = dcg.resolve_theme(self, dcg.ThemeStyleImGui, 'frame_rounding')
            #cur_padding = dcg.resolve_theme(self, dcg.ThemeStyleImGui, 'frame_padding')

            # Scale based on theme's title_scale if needed
            if hasattr(theme, 'node_title_scale') and theme.node_title_scale != 1.0:
                self.scaling_factor: float = theme.node_title_scale
        return title_theme
    
    def _setup_title_handlers(self) -> None:
        """Setup additional handlers for title bar"""
        self.handlers += [
            dcg.ClickedHandler(self.context, callback=self._on_clicked),
            dcg.ClickedHandler(self.context, button=dcg.MouseButton.RIGHT,
                             callback=self._on_right_click)
        ]
    
    def _on_clicked(self) -> None:
        """Handle left click - bring node to front"""
        parent_node = _get_parent_of_type(self, BaseNode)
        if parent_node is not None and hasattr(parent_node, 'move_to_front'):
            parent_node.move_to_front()
    
    def _on_right_click(self) -> None:
        """Handle right click - show context menu"""
        if self._context_menu_callback is not None:
            self._context_menu_callback(self)


def _simple_node_context_menu(node: 'SimpleNode') -> None:
    def _request_deletion(node: 'SimpleNode') -> None:
        node_editor = node.node_editor
        if node_editor is not None:
            node_editor.delete_node(node)
    with dcg.Window(node.context, popup=True, autosize=True):
        dcg.Button(node.context, label="Delete Node",
                   callback=_request_deletion)


class SimpleNode(BaseNode):
    """
    a Simple Node with basic look and interactions.

    It features:
    - A draggable title bar
    - A simple context menu
    - Shortcuts to position items (with pins) at various locations
    """
    __slots__ = {
        '_bottom_container': 'Container for bottom-aligned content',
        '_center_container': 'Container for center-aligned content',
        '_context_menu_callback': 'Callback for context menu',
        '_dragging_original_pos': 'Stored position before drag operation starts',
        '_left_container': 'Container for left-aligned content',
        '_node_editor_theme': 'Theme to use for the node',
        '_right_container': 'Container for right-aligned content',
        '_selected': 'Boolean indicating if node is selected',
        '_title_bar': 'Draggable button serving as title bar',
    }
    
    def __init__(self,
                 C: dcg.Context,
                 node_editor_theme: SimpleNodeEditorTheme | None = None,
                 context_menu_callback: Callable[['SimpleNode'], None] = _simple_node_context_menu,
                 **kwargs) -> None:
        # the default width = 0 on ChildWindow doesn't make sense here. Make it auto_resize instead
        if not(kwargs.get('auto_resize_x', False)) and kwargs.get("width", 0) == 0:
            kwargs.setdefault('auto_resize_x', True)
            kwargs.setdefault('always_auto_resize', True) # For proper behaviour when outside of the view
        # same for height
        if not(kwargs.get('auto_resize_y', False)) and kwargs.get("height", 0) == 0:
            kwargs.setdefault('auto_resize_y', True)
            kwargs.setdefault('always_auto_resize', True)
        kwargs.setdefault('no_scrollbar', True)
        kwargs.setdefault('no_scroll_with_mouse', True)
        label = kwargs.pop('label', "Node")
        super().__init__(C, **kwargs)
        self._selected = False

        # Deduce theme if not provided
        if node_editor_theme is None:
            node_editor_theme = self._deduce_theme()
        self._node_editor_theme = node_editor_theme

        self.theme = self._create_node_theme(C)
        self._context_menu_callback = context_menu_callback
        
        # Create node structure
        with self:
            # Title bar (draggable)
            self._title_bar = SimpleNodeTitleBar(
                C,
                label=label,
                context_menu_callback=context_menu_callback)
            
            # Divide the content into 4 spaces: left, center, right, bottom
            self._left_container = \
                dcg.ChildWindow(C,
                                auto_resize_x=True,
                                auto_resize_y=True,
                                always_auto_resize=True,
                                no_scrollbar=True,
                                no_scroll_with_mouse=True,
                                border=False,
                                no_background=True)
            self._center_container = \
                dcg.ChildWindow(C,
                                auto_resize_x=True,
                                auto_resize_y=True,
                                always_auto_resize=True,
                                no_scrollbar=True,
                                no_scroll_with_mouse=True,
                                border=False,
                                no_background=True)
            self._right_container = \
                dcg.ChildWindow(C,
                                auto_resize_x=True,
                                auto_resize_y=True,
                                always_auto_resize=True,
                                no_scrollbar=True,
                                no_scroll_with_mouse=True,
                                border=False,
                                no_background=True)
            with dcg.ChildWindow(C,
                                 auto_resize_x=True,
                                 auto_resize_y=True,
                                 always_auto_resize=True,
                                 no_scrollbar=True,
                                 no_scroll_with_mouse=True,
                                 border=False,
                                 no_background=True) as bottom_container_area:
                self._bottom_container = dcg.HorizontalLayout(C, no_wrap=True, alignment_mode=dcg.Alignment.CENTER)

        # left container is left of the content area
        self._left_container.x = self.x.x1
        # center container is to the right of left container + spacing, and centered horizontally
        #self._center_container.x = dcg.Size.MAX(self._left_container.x.x3 + dcg.Size.THEME_STYLE("item_spacing", False), 
        #                                        self.x.xc - dcg.Size.SELF_WIDTH() * 0.5)
        # As long as the center container is empty, make it noop
        self._center_container.x = self._left_container.x.x3
        # bottom container is left of the content area and centerered horizontally
        bottom_container_area.x = dcg.Size.MAX(self.x.xc - dcg.Size.SELF_WIDTH() * 0.5,
                                                self._left_container.x.x0)

        if self.auto_resize_x:
            # right container is to the right of center container + spacing, and aligned to bottom container
            self._right_container.x = dcg.Size.MAX(self._center_container.x.x3 + dcg.Size.THEME_STYLE("item_spacing", False),
                                                   bottom_container_area.x.x3 - dcg.Size.SELF_WIDTH()-1)
            # title bar is aligned with the containers. But to avoid circular
            # dependency, we need only set the width
            self._title_bar.width = self._right_container.x.x3 - self._title_bar.x.x0
        else:
            # Align with the fixed width of the node
            self._right_container.x = self.x.x2 - self._right_container.width
            self._title_bar.width = self.width.content_width

        # left container is below title bar + spacing
        self._left_container.y = self._title_bar.y.y3 + dcg.Size.THEME_STYLE("item_spacing", True)
        # center container is aligned with left container vertically
        self._center_container.y = self._left_container.y.y0
        # right container is aligned with left container vertically
        self._right_container.y = self._left_container.y.y0

        if self.auto_resize_y:
            # bottom container is below left/center/right containers + spacing
            bottom_container_area.y = dcg.Size.MAX(self._left_container.y.y3,
                                                    self._center_container.y.y3,
                                                    self._right_container.y.y3)\
                                       + dcg.Size.THEME_STYLE("item_spacing", True)
        else:
            # Align with the fixed height of the node
            bottom_container_area.y = self.y.y2 - bottom_container_area.height

        # Decuple title bar from node
        node_editor = self.node_editor
        if node_editor is None:
            node_editor = self.parent
        if node_editor is not None:
            assert isinstance(node_editor, BaseNodeEditor)
            node_editor_area = node_editor.get_content_area()
            self._title_bar.x = node_editor_area.x.x1 + kwargs.pop('x', dcg.Size.FIXED(0))
            self._title_bar.y = node_editor_area.y.y1 + kwargs.pop('y', dcg.Size.FIXED(0))
        else:
            self._title_bar.x = kwargs.pop('x', dcg.Size.FIXED(0))
            self._title_bar.y = kwargs.pop('y', dcg.Size.FIXED(0))

        self.pin_to(self._title_bar,
                    -dcg.Size.THEME_STYLE("item_spacing", False),
                    -dcg.Size.THEME_STYLE("item_spacing", True))

    @property
    def node_editor_theme(self) -> SimpleNodeEditorTheme:
        """The node editor theme used by the node"""
        return self._node_editor_theme
    
    @node_editor_theme.setter
    def node_editor_theme(self, value: SimpleNodeEditorTheme | None) -> None:
        if not isinstance(value, SimpleNodeEditorTheme) and value is not None:
            raise TypeError("node_editor_theme must be SimpleNodeEditorTheme instance or None")
        if value is None:
            value = self._deduce_theme()
        self._node_editor_theme = value
        self.theme = self._create_node_theme(self.context)

        # Update children theme (pins, title bar, etc.)
        _apply_children_recursively(self, 'node_editor_theme', value)

    def _get_default_theme(self) -> SimpleNodeEditorTheme:
        """Retrieve the default theme for the node"""
        return SimpleNodeEditorTheme()
    
    def _deduce_theme(self) -> SimpleNodeEditorTheme:
        """Deduce theme from parent editor"""
        parent_editor = _get_parent_of_type(self, BaseNodeEditor)
        if hasattr(parent_editor, 'node_editor_theme'):
            return getattr(parent_editor, 'node_editor_theme')
        return self._get_default_theme()
    
    def _create_node_theme(self, C: dcg.Context) -> dcg.ThemeList:
        """Create theme for the node container"""
        theme = self._node_editor_theme
        with dcg.ThemeList(C) as node_theme:
            dcg.ThemeColorImGui(C,
                                child_bg=theme.node_background_color,
                                border=theme.node_border_color)
            dcg.ThemeStyleImGui(C,
                                child_rounding=6.0,
                                child_border_size=1.0,
                                window_padding=(8, 8),
                                item_spacing=(8, 6))
        return node_theme
    
    def _open_context_menu(self) -> None:
        """Open context menu for the node"""
        if self._context_menu_callback is not None:
            self._context_menu_callback(self)
    
    '''
    def _duplicate(self) -> BaseNode | None:
        """Duplicate this node"""
        # Find parent NodeEditor
        node_editor = _get_parent_of_type(self, BaseNodeEditor)
        if node_editor is None:
            return  # No NodeEditor found
        # Create new node with offset position
        new_node: BaseNode = node_editor.add_node(
            label=self.label + " (Copy)",
            x=dcg.Size.FIXED(self.state.pos_to_viewport.x + 20),
            y=dcg.Size.FIXED(self.state.pos_to_viewport.y + 20),
        )
        # TODO: use copy() method to copy children and pins
        return new_node
    '''

    @property
    def label(self) -> str:
        """Title of the node"""
        return self._title_bar.label
    
    @label.setter
    def label(self, value: str) -> None:
        self._title_bar.label = value

    @property
    def selected(self) -> bool:
        """Whether the node is currently selected"""
        return self._selected
    
    @selected.setter
    def selected(self, value: bool) -> None:
        self._selected = bool(value)

    @property
    def append_left(self) -> dcg.ChildWindow | dcg.Layout:
        """Container to append left-aligned content (e.g. input pins)"""
        return self._left_container

    @property
    def append_center(self) -> dcg.ChildWindow | dcg.Layout:
        """Container to append center-aligned content"""
        # Enable centering of the center container
        # center container is to the right of left container + spacing, and centered horizontally
        self._center_container.x = dcg.Size.MAX(self._left_container.x.x3 + dcg.Size.THEME_STYLE("item_spacing", False), 
                                                self.x.xc - dcg.Size.SELF_WIDTH() * 0.5)
        # Center align appended items, but return a normal layout for easy stacking,
        # and proper alignment inside an appended item
        with dcg.HorizontalLayout(self.context,
                                  parent=self._center_container,
                                  alignment_mode=dcg.Alignment.CENTER,
                                  no_wrap=True,
                                  width=dcg.Size.FILLX()):
            container = dcg.Layout(self.context)
            return container

    @property
    def append_right(self) -> dcg.ChildWindow | dcg.Layout:
        """Container to append right-aligned content (e.g. output pins)"""
        with dcg.HorizontalLayout(self.context, parent=self._right_container, alignment_mode=dcg.Alignment.RIGHT, no_wrap=True):
            container = dcg.Layout(self.context)
            return container

    @property
    def append_bottom(self) -> dcg.ChildWindow | dcg.Layout:
        """Container to append bottom-aligned content"""
        with self._bottom_container:
            container = dcg.Layout(self.context)
            return container


def _simple_editor_context_menu(editor: 'SimpleNodeEditor') -> None:
    with dcg.Window(editor.context, popup=True, autosize=True):
        def _create_node_callback(editor=editor) -> None:
            node_editor = editor
            if node_editor is not None:
                mouse_pos = node_editor.screen_to_canvas(node_editor.context.get_mouse_position())
                canvas = node_editor.get_content_area()
                node_editor.add_node(
                    label="New Node",
                    x=canvas.x.x1 + dcg.Size.FIXED(mouse_pos.x),
                    y=canvas.y.y1 + dcg.Size.FIXED(mouse_pos.y)
                )
        def _clear_all_callback(editor=editor) -> None:
            for node in editor.get_nodes():
                editor.delete_node(node)

        dcg.Button(editor.context, label="Create Node",
                   callback=_create_node_callback)
        dcg.Button(editor.context, label="Clear All",
                    callback=_clear_all_callback)

class SimpleNodeEditor(BaseNodeEditor):
    """
    Node editor with simple visuals.
    
    Features:
    - Grid background with texture
    - Node creation via context menu
    - Link creation by dragging between pins
    - Context menus
    """
    __slots__ = {
        '_context_menu_callback': 'Callback for context menu',
        '_node_editor_theme': 'Theme to use for the node editor',
        '_dragging_original_pos': 'Position where a drag operation started',
    }
    
    def __init__(self,
                 C: dcg.Context,
                 node_editor_theme: SimpleNodeEditorTheme = SimpleNodeEditorTheme(),
                 context_menu_callback: Callable[['SimpleNodeEditor'], None] | None = _simple_editor_context_menu,
                 **kwargs) -> None:
        super().__init__(C, **kwargs)

        self._node_editor_theme: SimpleNodeEditorTheme = node_editor_theme
        self._context_menu_callback = context_menu_callback
        self._dragging_original_pos = None

        # Apply theme to editor background
        self._canvas.theme = self._create_editor_theme(C)

        # Create grid background
        self._create_grid_texture()

        # Setup handlers
        self._setup_handlers()

    @property
    def node_editor_theme(self) -> SimpleNodeEditorTheme:
        """The node editor theme"""
        return self._node_editor_theme
    
    @node_editor_theme.setter
    def node_editor_theme(self, value: SimpleNodeEditorTheme) -> None:
        if not isinstance(value, SimpleNodeEditorTheme):
            raise TypeError("node_editor_theme must be SimpleNodeEditorTheme instance")
        self._node_editor_theme = value
        self.theme = self._create_editor_theme(self.context)
        
        # Update grid
        self._create_grid_texture()
        
        # Update all nodes and links
        _apply_children_recursively(self, 'node_editor_theme', value)

    def _create_editor_theme(self, C: dcg.Context) -> dcg.ThemeList:
        """Create theme for the editor background"""
        theme = self._node_editor_theme
        with dcg.ThemeList(C) as editor_theme:
            dcg.ThemeColorImGui(C, child_bg=theme.background_color)
        return editor_theme

    def _create_grid_texture(self) -> None:
        """Create a repeating grid texture for the background"""
        # Clear existing grid
        self._background.children = []
        
        theme = self.node_editor_theme
        
        # Check if grid is disabled
        if theme.grid_style == SimpleGridStyle.NONE:
            return
        
        size = theme.grid_spacing
        
        # Create pixel data based on style
        pixels = []
        
        if theme.grid_style == SimpleGridStyle.LINES:
            # Grid lines on edges
            for y in range(size):
                pixels_row = []
                for x in range(size):
                    if x == 0 or y == 0:
                        pixels_row.append((255, 255, 255, 255))
                    else:
                        pixels_row.append((0, 0, 0, 0))
                pixels.append(pixels_row)
        
        elif theme.grid_style == SimpleGridStyle.DOTS:
            # Dots at intersections
            dot_radius = max(1, size // 32)
            for y in range(size):
                pixels_row = []
                for x in range(size):
                    # Check if within dot radius of corner
                    dist_sq = x * x + y * y
                    if dist_sq <= dot_radius * dot_radius:
                        pixels_row.append((255, 255, 255, 255))
                    else:
                        pixels_row.append((0, 0, 0, 0))
                pixels.append(pixels_row)
        
        elif theme.grid_style == SimpleGridStyle.CROSSES:
            # Small crosses at intersections
            cross_size = max(1, size // 16)
            for y in range(size):
                pixels_row = []
                for x in range(size):
                    # Vertical or horizontal line near origin
                    if (x < cross_size and y < cross_size * 3) or \
                       (y < cross_size and x < cross_size * 3):
                        pixels_row.append((255, 255, 255, 255))
                    else:
                        pixels_row.append((0, 0, 0, 0))
                pixels.append(pixels_row)
        
        else:
            # Default to lines if unknown style
            for y in range(size):
                pixels_row = []
                for x in range(size):
                    if x == 0 or y == 0:
                        pixels_row.append((255, 255, 255, 255))
                    else:
                        pixels_row.append((0, 0, 0, 0))
                pixels.append(pixels_row)
        # Create texture
        grid_texture = dcg.Texture(self.context, pixels, wrap_x=True, wrap_y=True, nearest_neighbor_upsampling=1, antialiased=True)
        
        # Draw the texture covering a large area
        with self._background:
            dcg.DrawImage(self.context,
                          texture=grid_texture,
                          pmin=(0, 0),
                          pmax=(128000, 128000),
                          uv_min=(0, 0),
                          uv_max=(128000 / size, 128000 / size),
                          color_multiplier=dcg.color_as_floats(theme.grid_color))

    def _setup_handlers(self) -> None:
        """Setup handlers for editor interactions"""
        self.handlers += [
            # Context menu
            dcg.ClickedHandler(self.context,
                             button=dcg.MouseButton.RIGHT,
                             callback=self._on_right_click),
            # Panning
            dcg.DraggingHandler(self.context,
                                button=dcg.MouseButton.LEFT,
                                callback=self._on_dragging),
            dcg.DraggedHandler(self.context,
                               button=dcg.MouseButton.LEFT,
                               callback=self._on_dragged),
            # zooming
            dcg.ConditionalHandler(self.context,
                                   children = [
                dcg.MouseWheelHandler(self.context,
                                      callback=self._on_wheel),
                dcg.FocusHandler(self.context)
            ])
        ]

    def _clamp_canvas_position(self, pos: dcg.Coord) -> dcg.Coord:
        """Clamp canvas position to prevent excessive panning"""
        # For now, we allow large panning, but clamp to avoid extreme values
        clamped_x = min(0, max(pos.x, self.state.content_region_avail.x-self._canvas.state.rect_size.x))
        clamped_y = min(0, max(pos.y, self.state.content_region_avail.y-self._canvas.state.rect_size.y))
        return dcg.Coord(clamped_x, clamped_y)

    def _on_dragging(self, handler, target, drag_deltas):
        """Handle panning while dragging"""
        if self._dragging_original_pos is None:
            # Store original position relative to reference
            cur_pos = self._canvas.state.pos_to_viewport
            ref_pos = self.state.content_pos
            self._dragging_original_pos = cur_pos - ref_pos

        # Calculate new position
        new_pos = self._dragging_original_pos + drag_deltas

        # Apply clamping
        new_pos = self._clamp_canvas_position(new_pos)

        # Update position to follow the mouse motion.
        # x1/y1 refer to content_pos (with pos_to_viewport fallback).
        # Using them will make us follow automatically if the ref_item moves.
        self._canvas.x = self.x.x1 + dcg.Size.FIXED(new_pos.x)
        self._canvas.y = self.y.y1 + dcg.Size.FIXED(new_pos.y)

    def _on_dragged(self, handler, target, drag_deltas):
        """Handle drag complete - resets tracking state"""
        self._dragging_original_pos = None

    def _on_wheel(self, handler, target, wheel_delta):
        """Handle zooming with mouse wheel"""
        # prevent dragging and zooming at the same time
        if self._dragging_original_pos is not None:
            return

        current_zoom = self._canvas.scaling_factor
        factor = math.exp(0.1 * wheel_delta)
        new_zoom = current_zoom * factor

        new_zoom = max(0.1, min(new_zoom, 4.0))  # Clamp zoom between 0.1x and 4x

        # Get mouse position in viewport coordinates
        mouse_viewport_pos = self.context.get_mouse_position()

        # Get canvas position in viewport coordinates
        canvas_viewport_pos = self._canvas.state.pos_to_viewport

        # Mouse position relative to canvas origin (before zoom)
        mouse_canvas_relative_x = (mouse_viewport_pos.x - canvas_viewport_pos.x) / current_zoom
        mouse_canvas_relative_y = (mouse_viewport_pos.y - canvas_viewport_pos.y) / current_zoom

        # After zoom, we want the same canvas point to be under the mouse
        # So: mouse_viewport_pos = canvas_new_pos + mouse_canvas_relative * new_zoom
        # Therefore: canvas_new_pos = mouse_viewport_pos - mouse_canvas_relative * new_zoom
        new_canvas_x = mouse_viewport_pos.x - mouse_canvas_relative_x * new_zoom
        new_canvas_y = mouse_viewport_pos.y - mouse_canvas_relative_y * new_zoom

        # Convert to position relative to editor content area
        editor_content_pos = self.state.content_pos
        new_pos = dcg.Coord(new_canvas_x - editor_content_pos.x,
                            new_canvas_y - editor_content_pos.y)

        # Apply clamping
        new_pos = self._clamp_canvas_position(new_pos)

        # Apply zoom and position
        self._canvas.scaling_factor = new_zoom
        self._canvas.x = self.x.x1 + dcg.Size.FIXED(new_pos.x)
        self._canvas.y = self.y.y1 + dcg.Size.FIXED(new_pos.y)

    def _on_right_click(self) -> None:
        """Handle right click for context menu"""
        if self._context_menu_callback is not None:
            self._context_menu_callback(self)    
    
    def add_node(self, **kwargs) -> SimpleNode:
        """Add a new node to the editor"""
        node = SimpleNode(self.context, parent=self._nodes, **kwargs)
        return node

    def add_link(self,
                 start: dcg.uiItem,
                 end: dcg.uiItem) -> 'BaseLink':
        """Add a link between two elements"""
        link = SimpleLink(self.context,
                          start=start, end=end,
                          parent=self._foreground)
        return link

class InteractiveThemeSimpleNode(SimpleNode):
    """
    A special node that provides interactive controls for configuring
    all parameters of a SimpleNodeEditorTheme.
    
    This node features:
    - Color pickers for all theme colors
    - Sliders for sizing parameters
    - Dropdowns for enum options (grid style, pin shapes)
    - Real-time theme updates
    """
    
    def __init__(self,
                 C: dcg.Context,
                 target_theme: SimpleNodeEditorTheme,
                 **kwargs):
        """
        Args:
            C: The context
            target_theme: The theme to edit (will be modified in place)
            **kwargs: Additional node parameters
        """
        kwargs.setdefault('label', 'Theme Editor')
        
        super().__init__(C, **kwargs)
        
        self.target_theme = target_theme
        
        # Create tabs for different theme categories
        with self.append_left if self.auto_resize_x else self.append_center: # Use left if auto-resize as it gives similar result and doesn't need convergence
            with dcg.TabBar(C, label="Theme Categories"):
                # Background tab
                with dcg.Tab(C, label="Background"):
                    dcg.ColorEdit(C,
                                  label="Background",
                                  value=target_theme.background_color,
                                  callback=lambda s,t,d: setattr(target_theme, 'background_color', d))
                    dcg.ColorEdit(C,
                                  label="Grid",
                                  value=target_theme.grid_color,
                                  callback=lambda s,t,d: setattr(target_theme, 'grid_color', d))
                    dcg.Combo(C,
                              label="Grid Style",
                              items=[s.value for s in SimpleGridStyle],
                              value=target_theme.grid_style.value,
                              callback=lambda s,t,d: setattr(target_theme, 'grid_style', SimpleGridStyle(d)))
                    dcg.Slider(C,
                               label="Grid Spacing",
                               value=target_theme.grid_spacing,
                               min_value=16,
                               max_value=128,
                               print_format="%.0f",
                               callback=lambda s,t,d: setattr(target_theme, 'grid_spacing', int(d)))
                
                # Node tab
                with dcg.Tab(C, label="Node"):
                    dcg.ColorEdit(C,
                                  label="Background",
                                  value=target_theme.node_background_color,
                                  callback=lambda s,t,d: setattr(target_theme, 'node_background_color', d))
                    dcg.ColorEdit(C,
                                  label="Border",
                                  value=target_theme.node_border_color,
                                  callback=lambda s,t,d: setattr(target_theme, 'node_border_color', d))
                    dcg.ColorEdit(C,
                                  label="Title BG",
                                  value=target_theme.node_title_bg_color,
                                  callback=lambda s,t,d: setattr(target_theme, 'node_title_bg_color', d))
                    dcg.ColorEdit(C,
                                  label="Title Text",
                                  value=target_theme.node_title_text_color,
                                  callback=lambda s,t,d: setattr(target_theme, 'node_title_text_color', d))
                    dcg.ColorEdit(C,
                                  label="Title Border",
                                  value=target_theme.node_title_border_color,
                                  callback=lambda s,t,d: setattr(target_theme, 'node_title_border_color', d))
                    dcg.ColorEdit(C,
                                  label="Title Hover",
                                  value=target_theme.node_title_hover_color,
                                  callback=lambda s,t,d: setattr(target_theme, 'node_title_hover_color', d))
                    dcg.ColorEdit(C,
                                  label="Title Active",
                                  value=target_theme.node_title_active_color,
                                  callback=lambda s,t,d: setattr(target_theme, 'node_title_active_color', d))
                    dcg.Slider(C,
                               label="Title Scale",
                               value=target_theme.node_title_scale,
                               min_value=0.5,
                               max_value=3.0,
                               print_format="%.2f",
                               callback=lambda s,t,d: setattr(target_theme, 'node_title_scale', d))
                
                # Pin Colors tab
                with dcg.Tab(C, label="Pin Colors"):
                    for pin_type in ['flow', 'bool', 'int', 'float', 'string', 'vector', 'object', 'any']:
                        color = target_theme.color_map.get(pin_type, (160, 160, 160, 255))
                        dcg.ColorEdit(C,
                                      label=pin_type.capitalize(),
                                      value=color,
                                      callback=lambda s,t,d,pt=pin_type: target_theme.color_map.update({pt: d}))
                
                # Pin Styles tab
                with dcg.Tab(C, label="Pin Styles"):
                    dcg.Text(C, value="Fill Color Modifier:")
                    self._create_color_modifier_controls(C, 'pin_fill_color', target_theme.pin_fill_color)
                    dcg.Separator(C)
                    
                    dcg.Text(C, value="Fill Hover Modifier:")
                    self._create_color_modifier_controls(C, 'pin_fill_hover_color', target_theme.pin_fill_hover_color)
                    dcg.Separator(C)
                    
                    dcg.Text(C, value="Border Color Modifier:")
                    self._create_color_modifier_controls(C, 'pin_border_color', target_theme.pin_border_color)
                    dcg.Separator(C)
                    
                    dcg.Text(C, value="Border Hover Modifier:")
                    self._create_color_modifier_controls(C, 'pin_border_hover_color', target_theme.pin_border_hover_color)
                    dcg.Separator(C)
                    
                    dcg.Slider(C,
                               label="Border Thickness",
                               value=target_theme.pin_border_thickness,
                               min_value=0.0,
                               max_value=0.5,
                               print_format="%.2f",
                               callback=lambda s,t,d: setattr(target_theme, 'pin_border_thickness', d))
                    dcg.Slider(C,
                               label="Border Hover Thickness",
                               value=target_theme.pin_border_hover_thickness,
                               min_value=0.0,
                               max_value=0.5,
                               print_format="%.2f",
                               callback=lambda s,t,d: setattr(target_theme, 'pin_border_hover_thickness', d))
                
                # Link Styles tab
                with dcg.Tab(C, label="Links"):
                    dcg.Text(C, value="Link Color Modifier:")
                    self._create_color_modifier_controls(C, 'link_color', target_theme.link_color)
                    dcg.Separator(C)
                    
                    dcg.Text(C, value="Selected Color Modifier:")
                    self._create_color_modifier_controls(C, 'link_selected_color', target_theme.link_selected_color)
                    dcg.Separator(C)
                    
                    dcg.Slider(C,
                               label="Link Thickness",
                               value=target_theme.link_thickness,
                               min_value=-10.0,
                               max_value=10.0,
                               print_format="%.1f",
                               callback=lambda s,t,d: setattr(target_theme, 'link_thickness', d))
        
        # Add apply button at the bottom
        with self.append_bottom:
            dcg.Button(C,
                       label="Apply Theme Changes",
                       callback=self._apply_theme_changes)

    def _create_color_modifier_controls(self,
                                        C: dcg.Context,
                                        attr_name: str,
                                        current_value) -> None:
        """Create controls for color modifier (None, float, or Color)"""

        # Determine current mode
        if current_value is None:
            mode = "Use Base"
        elif isinstance(current_value, float):
            mode = "Factor"
        else:
            mode = "Custom Color"
        
        mode_combo = dcg.Combo(C,
                               label="Mode",
                               items=["Use Base", "Factor", "Custom Color"],
                               value=mode)
        
        # Container for mode-specific controls
        controls_container = dcg.ChildWindow(C,
                                            auto_resize_x=True,
                                            auto_resize_y=True,
                                            always_auto_resize=True,
                                            no_scrollbar=True,
                                            no_scroll_with_mouse=True,
                                            border=False,
                                            no_background=True)
        
        def update_controls(sender, target, data):
            """Update controls based on selected mode"""
            controls_container.children = []
            
            if data == "Use Base":
                setattr(self.target_theme, attr_name, None)
                with controls_container:
                    dcg.Text(C, value="Using base color from pin type")
            
            elif data == "Factor":
                factor = current_value if isinstance(current_value, float) else 1.0
                setattr(self.target_theme, attr_name, factor)
                
                with controls_container:
                    dcg.Slider(C,
                               label="Brightness Factor",
                               value=factor,
                               min_value=0.0,
                               max_value=3.0,
                               print_format="%.2f",
                               callback=lambda s,t,d: setattr(self.target_theme, attr_name, d))
            
            else:  # Custom Color
                color = current_value if not isinstance(current_value, (float, type(None))) else (255, 255, 255, 255)
                setattr(self.target_theme, attr_name, color)
                
                with controls_container:
                    dcg.ColorEdit(C,
                                  label="Color",
                                  value=color,
                                  callback=lambda s,t,d: setattr(self.target_theme, attr_name, d))
        
        mode_combo.callback = update_controls
        # Initialize controls
        update_controls(None, None, mode)
    
    def _apply_theme_changes(self):
        """Apply theme changes by forcing a redraw of the editor"""
        editor = self.node_editor
        if editor is not None and hasattr(editor, 'node_editor_theme'):
            # Force theme update by reassigning it
            editor.node_editor_theme = self.target_theme