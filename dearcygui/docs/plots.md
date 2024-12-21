Plots are square items which enable to draw plot elements or drawings in a customizable coordinate system.

Various styles of the plot can be customized. By default a legend is shown, as well as axes and ticks. It is
possible with handlers to detect hovering and clicks over the legend, the axes area or the plot area, as well
as changes in the coordinates system (`AxesResizeHandler`)

Each Plot has three separate X axes (X1, X2, X3) and three separate Y axes (Y1, Y2, Y3).
By default only X1 and Y1 are enabled, and plotElements are assigned to X1/Y1.

The configuration of the axes and the legend can be done by accessing directly the X1, X2, X3, Y1, Y2, Y3 and legend attributes of a plot. They are respectively of type PlotAxisConfig and PlotLegendConfig.

The mouse position can be obtained in plot coordinate space by looking at the `mouse_coord` attribute
of each PlotAxisConfig. The min and max of the coordinates of that axis can be set directly using the `min` and `max` attributes, but it can also be set automatically using an automated fit to the drawn data. See the description of `auto_fit`, `contraint_min/max`, `no_initial_fit`, `lock_min/max` and `ignore_fit` for more details.

Plots can include:
- `PlotLine`. To draw line plots, or segment plots.
- `PlotScatter`. For a scatter plot
- `PlotShadedLine`. For line plots with shaded area beneath for line.
- `PlotStairs`. For stairs plot
- `PlotStems`. For stems plot
- `PlotBars`. For bars plot
- `DrawInPlot`. For custom rendering in plot coordinate space. Useful to inherit from the coordinates, resizing, zoom and panning features of a plot.

By default, hovering an element legend increases the thickness of the element. If the plot element
is assigned children widgets, right clicking on it on its legend opens a small window with these elements. The legend can be disabled globally on a plot, or individually for each item.

The implementation of plots is using the **ImGui** extension library **ImPlot**.