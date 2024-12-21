## New features that DearCyGui supports

# Items
- You can subclass any item in Python and create new items that can be inserted in the rendering tree.
- You can subclass any item in Cython and create new items that can be inserted in the rendering tree. In Cython, contrary to Python, you can access the item internal fields (states, etc) directly and override the drawing function. This can be useful for advanced usage, but is more complex. Python subclassing should be sufficient for most.
- Writing/reading item attributes is much faster (benchmark shows ~40 times faster when almost no item is created. But as DPG item access times is linear in the number of items, the gap quickly grows with the number of items). In addition the attributes can be accessed during rendering if rendering is not using the item at the moment.
- Possibility for uiItems to access their position relative to the parent, the window or the viewport, and to set the placement relative to any of these.
- Contrary to DPG which had a global lock, every item has its own lock.
- And item can be created without any parent, and be attached later.
- A lot of states that were not meaningful and were sometimes misleading were removed or raise an error when not valid. For instance Drawing items do not have an 'ok' or a 'visible' state as in practice they were always True no matter what.
- A lot of states were not correctly updated, and special care has been done to properly update them. You can trust the value of the states much more.

# Viewport
- wait_for_input is now more useful as wake() enables to force rendering
of a frame even if no mouse/key input is detected.
- The viewport is an item like any other. Any item which is connected to the viewport is rendered. The viewport supports the same attributes as the other items (fewer specific attributes).
- Several locks are used. Each item has its own lock, and the viewport uses three different locks to protect several parts of the rendering process that can take time. Only the needed locks are taken at a given time, thus accelerating multithread acccess to the items.


# Layouts
Layouts replace Groups.
- You can subclass the main Layout class to do custom layouts by implement as callback a function that organizes the children of the Layout. The callback is called whenever the parent area changes or a new child is added.
- Horizontal and vertical layouts support left/center/right/justified alignment, as well as manual alignment, where you pass a list of positions (which can be percentages) for the items. The callback is called when the parent are changes to give you a chance to pass new positions.

# Handlers
- The global handlers and item handlers categories are merged.
- You don't need a global / item registry anymore.
- You can combine handlers with conditions (test this handler only if these handlers are true)
- You can combine handlers with NONE, ANY or ALL.
- New handlers enable to catch mouse dragging an item.
- You can create custom handlers with python subclassing. For instance you can have a handler that holds True only if a specific other item is visible, or if a user condition is true, or if the framecount is a multiple of 5, or anything you want.
- As a result of all the above, you can make it so specific callbacks are only called if very specific conditions are met. This contrasts with DPG, where you had to check the specific conditions in your callback, and these might not be True anymore by the time you handle the callback.
- You can append handlers to an item that already has handlers.
- repeat argument for KeyPressHandler

# Callbacks
- While handlers only accept a single callback (because you can just duplicate your handlers if you need several callbacks to be called), item callbacks accept appending several callbacks.
- When the callback fails for any reason, a detailed traceback is printed in the console.
- Callbacks are issued right away, and can run while rendering is performed and manipulate items of the rendering tree while rendering is performed (as long as rendering is not using these items).
- Since global handlers and item handlers were merged, a break in compatibility was required for callback inputs in order to indicate to which item the global handler was bound when it was triggered. The DPG wrapper handles passing the old arguments (which were sender, call_data, user_data), but normal DCG wrappers use instead sender, target_item, call_data. target_item can be the sender (item callback for instance). user_data is dropped as it can be simply accessed doing sender.user_data. In addition sender and target_item are directly the python objects rather than uuids.
- Callbacks now work properly for bound methods (self.your_function).

# Textures
- Support for R, RG, RGB, RGBA in both uint8 and float32 formats
- Textures are uploaded only once when you set their value, rather than every frame rendered.

# Fonts
- Default font looks much nicer.
- Support for bold, italics and bold-italics in the default font.
- Helpers and documentation to make your own fonts.

# Plots
- Support for X2 and X3 axes
- Support for handlers on the axes
- Support for zero copy when passing plot data (requires int32, float32 or float64 data)
- It is possible to fit the plot to contained drawing items
- Extended Custom Plot functionnality (possibility to add legend to groups of drawing items drawn in plot space)

# DPI scaling
- Support for automated and manual handling of the screen requested dpi scaling
- Possibility to set a global scale factor in addition to the dpi scaling

## Features that DearCyGui does not support yet
- Tables
- Drag rects/lines
- colormaps
- some types of plots
- Colormaps
- DragNDrop. Not 100% sure yet it will be supported.

## Features that DearCyGui does not intend to support
- Filter sets: Filter sets in DPG allow to give names to items, and have their parent filter which parent should be drawn or not depending on the names given. The reason that DCG will not implement this feature is because first it tries to avoid bloat, and adding a filter field that will almost never be useful is not good for that, second this feature would be much more efficient if implemented on the user side, as the filter will be run every frame, rather than just when needed. Instead the user can store his filters in user_data and manipulate the `show` field to his liking. 
- Knobs, 3D sliders: May be implemented as utilities, but will not be in core DCG.
- Plot query rects: This type of feature needs a lot of customization. The new features of DCG enables the user to implement their own query rects. Some helpers will be available as utilities.

