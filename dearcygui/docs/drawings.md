# Tools for rendering

**DearCyGui** contains various items to perform some light 2D rendering.
It is not possible yet to use custom shaders, or perform 3D rendering,
but the 2D rendering is optimized in order to perform well visually (antialiasing),
and in overhead (no state maintenance, drawcalls groupped as much as possible).

The items to draw have their name beginning with `Draw`
- `DrawArrow` draws an arrow
- `DrawLine`, `DrawPolyLine` enable to draw one or several lines
- `DrawTriangle`, `DrawRect`, `DrawPolygon`, draws respectively a triangle, a rectangle, a polygon
- `DrawCircle`, `DrawEllipse` draw a circle and an ellipse
- `DrawingList` enables to group several items. It is useful (by subclassing it) to create custom objects.
- `DrawingScale` enables to apply a transform to the coordinates, but you for complex cases `Plot` is more powerful

All color arguments in **DearCyGui** accept three formats:

- A packed RGBA (8 bit per channel)
- a tuple of uint8. For instance `(10, 25, 35)` means `R=10`, `G=25`, `B=35`. If a fourth coordinate is passed, it corresponds to *alpha* (255 means opaque and 0 fully transparent).
- a tuple of float32. The behaviour is similar to a tuple of uint8, except all values must be divided by 255. Values must be between 0 and 1. **BEWARE** of this behaviour, as you be careful not to multiply with a float scalar integer values without normalizing.

**DearCyGui** provides respectively `color_as_int`, `color_as_ints` and `color_as_floats` to produce these three representations. These functions take as input any of these three formats. When reading a color attribute of an item, the first format is used, thus these helpers can help convert the format to what you need.

Most Draw* items accept a `thickness` attribute. This thickness is automatically scaled by the global scale and the plot scale (in inside `Plot`).
Similarly the `radius` attribute of `DrawCircle` is scaled. To prevent this scaling and have a `thickness` or `radius` in pixels, pass a negative value.

# Coordinate system

The coordinate system in which Draw* commands reside depends on their parent. `DrawInWindow` creates a system with origin the position in the window, and such that 1 pixel = 1 unit (scaling put aside). `DrawInPlot` inherits the range from the selected axes of the `Plot`, which can be directly changed by setting the `min` and `max` attribute of the relevant axes. In all cases, the GPU clips elements that are outside of the region of the parent. Note it is possible to use `Plot` purely as a coordinate system by removing all default visual elements of a plot (legend, axes, etc). On the other hand, `DrawInPlot` enable optionnaly to appear in the legend of `Plot`, and thus Draw* elements can be used to create custom plot drawings.

# Events and `DrawInvisibleButton`

As the Draw* items do not check any state, they do not react to clicking, hovering, etc. Handlers attached to their parent `Plot` or `Window` enable to capture changes in the coordinate system (resizing, etc). `DrawInvisibleButton` enables to capture clicks inside the draw region, by creating a rectangular region that reacts to hovering, clicks, etc. Handlers can be attached to it similarly to normal UI elements. However `DrawInvisibleButton` can be overlapped. Similarly to normal buttons, a pressed `DrawInvisibleButton` remains in the active state as long as the mouse is not released, thus you can implement dragging objects without having to move the invisible button during the dragging operation. To implement an interactable Draw* Object, one can subclass `DrawingList`, and attach visuals and `DrawInvisibleButton`. But for simple needs, note that `DrawInvisibleButton` also accepts children. In that case the coordinate system scales such that (0, 0) is the top left of the button and (1, 1) the bottom right.

`DrawInvisibleButton` takes various arguments to control its behaviour. The shape is determined in plot space by setting the top left and bottom right coordinates in `p1` and `p2`, but you can assign a size on pixel space by using the `min_side` and `max_side` attribute. For example a point will be assigned identical `p1` and `p2`, but will be assigned a min_side. In the case of overlap, the last button in the rendering tree takes priority.