class ItemStateView:
    """
    View class for accessing UI item state properties.
    
    This class provides a consolidated interface to access state properties
    of UI items, such as whether they are hovered, active, focused, etc.
    Each property is checked against the item's capabilities to ensure
    it supports that state.
    
    The view references the original item and uses its mutex for thread safety.
    """
    
    @property
    def active(self) -> bool:
        """
        Whether the item is in an active state.
        
        Active states vary by item type: for buttons it means pressed; for tabs,
        selected; for input fields, being edited. This state is tracked between
        frames to enable interactive behaviors.
        """
        ...
    
    @property
    def activated(self) -> bool:
        """
        Whether the item just transitioned to the active state this frame.
        
        This property is only true during the frame when the item becomes active,
        making it useful for one-time actions. For persistent monitoring, use 
        event handlers instead as they provide more robust state tracking.
        """
        ...
    
    @property
    def clicked(self) -> tuple[bool, bool, bool, bool, bool]:
        """
        Whether any mouse button was clicked on this item this frame.
        
        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the click occurs.
        For consistent event handling across frames, use click handlers instead.
        """
        ...
    
    @property
    def double_clicked(self) -> tuple[bool, bool, bool, bool, bool]:
        """
        Whether any mouse button was double-clicked on this item this frame.
        
        Returns a tuple of five boolean values, one for each possible mouse button.
        This property is only true during the frame when the double-click occurs.
        For consistent event handling across frames, use click handlers instead.
        """
        ...
    
    @property
    def deactivated(self) -> bool:
        """
        Whether the item just transitioned from active to inactive this frame.
        
        This property is only true during the frame when deactivation occurs.
        For persistent monitoring across frames, use event handlers instead
        as they provide more robust state tracking.
        """
        ...
    
    @property
    def deactivated_after_edited(self) -> bool:
        """
        Whether the item was edited and then deactivated in this frame.
        
        Useful for detecting when user completes an edit operation, such as
        finishing text input or adjusting a value. This property is only true
        for the frame when the deactivation occurs after editing.
        """
        ...
    
    @property
    def edited(self) -> bool:
        """
        Whether the item's value was modified this frame.
        
        This flag indicates that the user has made a change to the item's value,
        such as typing in an input field or adjusting a slider. It is only true
        for the frame when the edit occurs.
        """
        ...
    
    @property
    def focused(self) -> bool:
        """
        Whether this item has input focus.
        
        For windows, focus means the window is at the top of the stack. For
        input items, focus means keyboard inputs are directed to this item.
        Unlike hover state, focus persists until explicitly changed or lost.
        """
        ...
    
    @property
    def hovered(self) -> bool:
        """
        Whether the mouse cursor is currently positioned over this item.

        Only one element can be hovered at a time in the UI hierarchy. When
        elements overlap, the topmost item (typically a child item rather than
        a parent) receives the hover state.
        """
        ...
    
    @property
    def resized(self) -> bool:
        """
        Whether the item's size changed this frame.
        
        This property is true only for the frame when the size change occurs.
        It can detect both user-initiated resizing (like dragging a window edge)
        and programmatic size changes.
        """
        ...
    
    @property
    def toggled(self) -> bool:
        """
        Whether the item was just toggled open this frame.
        
        Applies to items that can be expanded or collapsed, such as tree nodes,
        collapsing headers, or menus. This property is only true during the frame
        when the toggle from closed to open occurs.
        """
        ...
    
    @property
    def visible(self) -> bool:
        """
        Whether the item was rendered in the current frame.
        
        An item is visible when it and all its ancestors have show=True and are
        within the visible region of their containers. Invisible items skip
        rendering and event handling entirely.
        """
        ...
    
    @property
    def rect_size(self) -> 'Coord':
        """
        Actual pixel size of the element including margins.
        
        This property represents the width and height of the rectangle occupied
        by the item in the layout. The rectangle's top-left corner is at the
        position given by the relevant position property.
        
        Note that this size refers only to the item within its parent window and
        does not include any popup or child windows that might be spawned by
        this item.
        """
        ...
    
    @property
    def pos_to_viewport(self) -> 'Coord':
        """
        Position relative to the viewport's top-left corner.
        """
        ...
    
    @property
    def pos_to_window(self) -> 'Coord':
        """
        Position relative to the containing window's content area.
        """
        ...
    
    @property
    def pos_to_parent(self) -> 'Coord':
        """
        Position relative to the parent item's content area.
        """
        ...
    
    @property
    def pos_to_default(self) -> 'Coord':
        """
        Offset from the item's default layout position.
        """
        ...
    
    @property
    def content_region_avail(self) -> 'Coord':
        """
        Available space for child items.
        
        For container items like windows, child windows, this
        property represents the available space for placing child items. This is
        the item's inner area after accounting for padding, borders, and other
        non-content elements.
        
        Areas that require scrolling to see are not included in this measurement.
        """
        ...
    
    @property
    def content_pos(self) -> 'Coord':
        """
        Position of the content area's top-left corner.
        
        This property provides the viewport-relative coordinates of the starting
        point for an item's content area. This is where child elements begin to be
        placed by default.
        
        Used together with content_region_avail, this defines the rectangle
        available for child elements.
        """
        ...
    
    @property
    def item(self):
        """
        item from which the states are extracted.
        """
        ...


class ViewportMetrics:
    """
    Provides detailed rendering metrics for viewport performance analysis.
    
    This class exposes timing and rendering statistics for the viewport's frame lifecycle.
    All timing values are based on the monotonic clock for consistent measurements.
    """
        
    @property
    def last_time_before_event_handling(self) -> float:
        """
        Timestamp (s) when event handling started for the current frame.
        
        This marks the beginning of the frame lifecycle, before any input events 
        are processed. Useful for measuring total frame time or comparing with
        external event timings.
        """
        ...
        
    @property
    def last_time_before_rendering(self) -> float:
        """
        Timestamp (s) when UI rendering started for the current frame.
        
        This marks when the system finished processing events and began the
        rendering phase. The difference between this and last_time_before_event_handling
        indicates how much time was spent processing input.
        """
        ...
        
    @property
    def last_time_after_rendering(self) -> float:
        """
        Timestamp (s) when UI rendering finished for the current frame.
        
        This marks when all drawing commands were submitted to ImGui/ImPlot and
        CPU-side rendering work was completed. The GPU may still be processing
        these commands at this point.
        """
        ...
        
    @property
    def last_time_after_swapping(self) -> float:
        """
        Timestamp (s) when the frame was completely presented to the screen.
        
        This marks the end of the frame lifecycle, after the backbuffer has been
        swapped with the frontbuffer and presented to the display. If vsync is
        enabled, this includes any time spent waiting for the display refresh.
        """
        ...
        
    @property
    def delta_event_handling(self) -> float:
        """
        Time (seconds) spent processing input events for the current frame.
        
        This measures how long the system spent handling mouse, keyboard, and
        other input events. High values might indicate complex event processing
        or delays from input devices.

        This time may differ from the time between
        last_time_before_event_handling and last_time_before_rendering,
        if event processing is being run when the metrics were collected.
        """
        ...
        
    @property
    def delta_rendering(self) -> float:
        """
        Time (seconds) spent on CPU rendering work for the current frame.
        
        This measures how long it took to traverse the UI hierarchy, compute layouts,
        and generate the render commands for ImGui/ImPlot. High values might indicate
        complex UI structures or inefficient layout calculations.

        This time may differ from the time between
        last_time_before_rendering and last_time_after_rendering,
        if rendering is being run when the metrics were collected.
        """
        ...
        
    @property
    def delta_presenting(self) -> float:
        """
        Time (seconds) spent presenting the frame to the display.
        
        This includes the time to submit draw commands to the GPU, wait for them
        to complete, and swap the buffers. With vsync enabled, this will include
        time waiting for the monitor refresh, which can artificially inflate the value.

        This time may differ from the time between
        last_time_after_rendering and last_time_after_swapping,
        if presenting is being run when the metrics were collected.
        """
        ...
        
    @property
    def delta_whole_frame(self) -> float:
        """
        Total time (seconds) for the complete frame lifecycle.
        
        This measures the time from the start of event handling to the completion
        of buffer swapping. It represents the total frame time and is the inverse
        of the effective frame rate (1.0/delta_whole_frame = FPS).

        This time may differ from the time between
        last_time_before_event_handling and last_time_after_swapping,
        if frame processing is being run when the metrics were collected.
        """
        ...
        
    @property
    def rendered_vertices(self) -> int:
        """
        Number of vertices rendered in the current frame.
        
        This count represents the total geometry complexity of the UI. Higher numbers
        indicate more complex visuals which may impact GPU performance.
        """
        ...
        
    @property
    def rendered_indices(self) -> int:
        """
        Number of indices rendered in the current frame.
        
        This count relates to how many triangles were drawn. Like vertex count,
        this is an indicator of visual complexity and potential GPU load.
        """
        ...
        
    @property
    def rendered_windows(self) -> int:
        """
        Number of windows rendered in the current frame.
        
        This counts all ImGui windows that were visible and rendered. Windows that
        are hidden, collapsed, or clipped don't contribute to this count.
        """
        ...
        
    @property
    def active_windows(self) -> int:
        """
        Number of active windows in the current frame.
        
        This counts windows that are processing updates, even if not visually rendered.
        The difference between this and rendered_windows can indicate hidden but
        still processing windows.
        """
        ...
        
    @property
    def frame_count(self) -> float:
        """
        Counter indicating which frame these metrics belong to.
        
        This monotonically increasing value allows tracking metrics across multiple
        frames and correlating with other frame-specific data.
        """
        ...