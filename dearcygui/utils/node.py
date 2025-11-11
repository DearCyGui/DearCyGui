"""
A Node editor of DearCyGui.

Copy paste and adapt the code to your needs
"""

import dearcygui as dcg


def get_bezier_control_points(start_pos: tuple[float, float], 
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
    # Use a minimum offset to handle vertical alignment
    dx = x4 - x1
    offset = max(abs(dx) * 0.5, abs(y4 - y1) * 0.25, 50.0)
    
    # Control points with horizontal tangents
    # p2 is to the right of p1 at the same height
    p1: tuple[float, float] = (x1, y1)
    p2: tuple[float, float] = (x1 + offset, y1)
    # p3 is to the left of p4 at the same height
    p3: tuple[float, float] = (x4 - offset, y4)
    p4: tuple[float, float] = (x4, y4)
    
    return (p1, p2, p3, p4)

def _get_children_recursively(item: dcg.uiItem) -> set[dcg.uiItem]:
    """Retrieve all children of an item recursively"""
    children = set()
    for child in item.children:
        children.add(child)
        children.update(_get_children_recursively(child))
    return children

class NodeEditor(dcg.ChildWindow):
    """
    SubWindow that contains nodes
    """
    def __init__(self, C: dcg.Context, **kwargs) -> None:
        super().__init__(C, **kwargs)

        # Background drawings, convering the full inner region
        self._background = dcg.DrawInWindow(C,
                                            x=self.x.x1, y=self.y.y1,
                                            width=self.width.content_width,
                                            height=self.height.content_height,
                                            parent=self
                                            )
        # Node subcontainer
        self._nodes = dcg.Layout(C, parent=self)

        # foreground drawings, on top of nodes
        self._foreground = dcg.DrawInWindow(C,
                                            x=self.x.x1, y=self.y.y1,
                                            width=self.width.content_width,
                                            height=self.height.content_height,
                                            parent=self
                                            )

        # Context menu
        self.handlers += [
            dcg.ClickedHandler(C, button=dcg.MouseButton.RIGHT,
                               callback=self._open_context_menu)
        ]

    def _open_context_menu(self) -> None:
        """Create a context menu upon right click"""
        with dcg.Window(self.context, popup=True, autosize=True):
            def _reset_view() -> None:
                """Clear all nodes"""
                self._nodes.children = []
            dcg.Button(self.context,
                       label="Reset",
                       callback=_reset_view
                       )
            dcg.Button(self.context,
                       label="Add Node",
                       callback=self.add_node
                       )

    def add_node(self, **kwargs) -> '_Node':
        """Add a new node to the editor"""
        node = _Node(self.context, parent=self._nodes, **kwargs)
        return node

    def add_link(self,
                 start: dcg.uiItem,
                 end: dcg.uiItem) -> None:
        """Add a link between two elements"""
        _Link(self.context, start=start, end=end,
              parent=self._foreground)
        return

    def delete_link(self, link: '_Link') -> None:
        """Delete a link from the editor"""
        if not isinstance(link, _Link):
            raise TypeError("link must be of type _Link")
        if link.parent is not self._foreground:
            raise ValueError("link is not a child of this NodeEditor")
        link.delete_item()

    def delete_links_of_node(self, node: '_Node') -> None:
        """Delete all links connected to a node"""
        if not isinstance(node, _Node):
            raise TypeError("node must be of type _Node")
        if node.parent is not self._nodes:
            raise ValueError("node is not a child of this NodeEditor")

        # Retrieve all children recursively
        subitems = _get_children_recursively(node)

        # Remove all links connected to the node
        for child in list(self._foreground.children):
            if isinstance(child, _Link):
                if child.start in subitems or child.end in subitems:
                    child.delete_item()

    def delete_node(self, node: '_Node') -> None:
        """Delete a node from the editor"""
        if not isinstance(node, _Node):
            raise TypeError("node must be of type _Node")
        if node.parent is not self._nodes:
            raise ValueError("node is not a child of this NodeEditor")

        # Remove all links connected to the node
        self.delete_links_of_node(node)

        # Remove the node itself
        node.delete_item()

    def get_links(self) -> list['_Link']:
        """Return all links in the editor"""
        return [child for child in self._foreground.children if isinstance(child, _Link)]

    def get_links_of_node(self, node: '_Node', start=True, end=True) -> list['_Link']:
        """Return all links connected to a node
        
        Args:
            node (_Node): The node to get links for
            start (bool): If True, include links where the node is the start
            end (bool): If True, include links where the node is the end
        """
        if not isinstance(node, _Node):
            raise TypeError("node must be of type _Node")
        if node.parent is not self._nodes:
            raise ValueError("node is not a child of this NodeEditor")

        # Retrieve all children recursively
        subitems = _get_children_recursively(node)

        # Retrieve all links connected to the node
        links = []
        for child in self._foreground.children:
            if isinstance(child, _Link):
                if child.start in subitems or child.end in subitems:
                    links.append(child)
        return links

    def get_nodes(self) -> list['_Node']:
        """Return all nodes in the editor"""
        return [child for child in self._nodes.children if isinstance(child, _Node)]


class _Node(dcg.ChildWindow):
    """
    A node in the NodeEditor
    """
    def __init__(self, C: dcg.Context, **kwargs) -> None:
        super().__init__(C, **kwargs)

    def contains(self, item: dcg.uiItem) -> bool:
        """Check if the node contains the given item"""
        return item in _get_children_recursively(self)

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


class _Link(dcg.DrawingList):
    """
    A link between two items in the NodeEditor
    """
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

        self._start.handlers += [
            dcg.MotionHandler(C,
                              pos_policy=(dcg.Positioning.REL_WINDOW, dcg.Positioning.REL_WINDOW),
                              callback=self._update_position)
        ]
        self._end.handlers += [
            dcg.MotionHandler(C,
                              pos_policy=(dcg.Positioning.REL_WINDOW, dcg.Positioning.REL_WINDOW),
                              callback=self._update_position)
        ]
        self._update_position()

    @property
    def start(self) -> dcg.uiItem:
        """The start item of the link"""
        return self._start

    @property
    def end(self) -> dcg.uiItem:
        """The end item of the link"""
        return self._end

    def _draw_link(self,
                   start_pos: tuple[float, float],
                   end_pos: tuple[float, float]) -> None:
        """Draw the link between two positions"""
        (p1, p2, p3, p4) = get_bezier_control_points(start_pos, end_pos)

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

    def _update_position(self) -> None:
        """Update the position of the link based on the start and end items"""
        start_state = self._start.state
        stop_state = self._end.state

        ref_parent = self.parent
        while ref_parent is not None and not isinstance(ref_parent, NodeEditor):
            ref_parent = ref_parent.parent
        if ref_parent is None:
            raise ValueError("link must be inside a NodeEditor")

        ref_position = ref_parent.state.pos_to_viewport
        start_x = start_state.pos_to_viewport.x - ref_position.x + start_state.rect_size.x * 0.5
        start_y = start_state.pos_to_viewport.y - ref_position.y + start_state.rect_size.y * 0.5
        end_x = stop_state.pos_to_viewport.x - ref_position.x + stop_state.rect_size.x * 0.5
        end_y = stop_state.pos_to_viewport.y - ref_position.y + stop_state.rect_size.y * 0.5

        start_pos = (start_x, start_y)
        end_pos = (end_x, end_y)

        self._draw_link(start_pos, end_pos)