"""Test DPI and zoom behavior for drawing geometry and stroke widths.

Render red primitives in a hidden viewport and compare framebuffer pixels
with expected screen-space sizes.
"""

import gc
import time
from collections.abc import Iterator
from dataclasses import dataclass
from itertools import product

import dearcygui as dcg
import numpy as np
import pytest


@dataclass(frozen=True, kw_only=True)
class _DrawingCase:
    """Describe the drawing container, viewport scale, and coordinate zoom.

    ``zoom`` is applied by DrawingScale. For plots, ``axis_range`` independently
    controls axis zoom: a smaller range maps coordinate units to more pixels.
    ``no_global_scaling`` applies only to DrawInWindow.
    """

    container: str # window or plot
    dpi: float # viewport dpi scaling
    zoom: float # drawing scale zoom factor
    no_global_scaling: bool = False # disable global DPI scaling for DrawInWindow
    axis_range: float = 100 # axis range for plots


@pytest.fixture
def context() -> Iterator[dcg.Context]:
    """Create a hidden viewport with framebuffer readback enabled."""
    ctx = dcg.Context()
    ctx.viewport.initialize(
        visible=False,
        width=1000,
        height=800,
        always_submit_to_gpu=True,
        retrieve_framebuffer=True,
    )
    yield ctx
    # Framebuffer readback can briefly keep viewport resources in use.
    ctx.queue.shutdown(wait=True)
    gc.collect()
    deadline = time.monotonic() + 2
    while True:
        try:
            ctx.viewport.destroy()
            break
        except RuntimeError as error:
            if "resources are in use" not in str(error) or time.monotonic() >= deadline:
                raise
            time.sleep(0.01)


def _drawing_parent(ctx: dcg.Context, case: _DrawingCase) -> dcg.baseItem:
    """Create a drawing scale inside a window or linear plot."""
    # Set the viewport DPI scale
    # Hidden viewports have OS DPI 1,
    # so viewport.scale supplies the test DPI.
    ctx.viewport.scale = case.dpi

    # Create a window
    window = dcg.Window(ctx, width=450, height=350)

    # Create the drawing container based on the specified type and parameters
    if case.container == "window":
        parent = dcg.DrawInWindow(
            ctx, parent=window, width=360, height=260,
            no_global_scaling=case.no_global_scaling,
        )
    elif case.container == "plot":
        plot = dcg.Plot(ctx, parent=window, width=360, height=260)
        for axis in (plot.X1, plot.Y1):
            axis.no_initial_fit = True
            axis.min = 0
            axis.max = case.axis_range
        parent = dcg.DrawInPlot(ctx, parent=plot)
    else:
        raise ValueError(f"Unknown drawing container: {case.container}")

    # Create a drawing scale as the final parent for the drawing content.
    return dcg.DrawingScale(ctx, parent=parent, scales=(case.zoom, case.zoom))


def _render_pixels(ctx: dcg.Context) -> np.ndarray:
    """Render stabilized frames and return the framebuffer."""
    # Allow layout and framebuffer readback to settle before measuring pixels.
    for _ in range(6):
        ctx.viewport.render_frame()
    framebuffer = ctx.viewport.framebuffer
    assert framebuffer is not None
    # Readback is bottom-up; state positions use a top-left origin.
    return np.asarray(framebuffer.read())[::-1].copy()


def _red_bounds(pixels: np.ndarray) -> tuple[int, int, int, int]:
    """Return red pixel bounds, with exclusive right and bottom edges.

    Reject partially antialiased pixels so the measured bounds are stable
    enough to compare with the geometric edges using a small tolerance.
    """
    # Build a mask of sufficiently red pixels
    pixels_are_red = (pixels[:, :, 0] > 180) & (pixels[:, :, 1] < 80) & (pixels[:, :, 2] < 80)

    # Return minimal bounding box of red pixels (exclusive right and bottom edges)
    ys, xs = np.nonzero(pixels_are_red)
    assert xs.size > 0, "No sufficiently opaque red pixels were found"
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def _red_size(pixels: np.ndarray) -> tuple[int, int]:
    """Count columns and rows containing red pixels, including zero for subpixel shapes."""
    # Build a mask of sufficiently red pixels and count the non-empty columns and rows.
    pixels_are_red = (pixels[:, :, 0] > 180) & (pixels[:, :, 1] < 80) & (pixels[:, :, 2] < 80)
    return int(np.count_nonzero(np.any(pixels_are_red, axis=0))), int(np.count_nonzero(np.any(pixels_are_red, axis=1)))


def _assert_button_child_rendered(pixels: np.ndarray) -> None:
    """Check that the independent green button-child control was rendered."""
    pixels_are_green = (pixels[:, :, 0] < 80) & (pixels[:, :, 1] > 180) & (pixels[:, :, 2] < 80)
    assert np.any(pixels_are_green), "The green button-child control was not rendered"


# Compare window and plot coordinates under DPI, DrawingScale, and axis zoom.
# The no-global case checks that negative screen sizes also ignore DPI.
_CASES = (
    pytest.param(_DrawingCase(container="window", dpi=1, zoom=1), id="window-dpi1-zoom1"),
    pytest.param(_DrawingCase(container="window", dpi=2, zoom=1), id="window-dpi2-zoom1"),
    pytest.param(_DrawingCase(container="window", dpi=1, zoom=2), id="window-dpi1-zoom2"),
    pytest.param(_DrawingCase(container="window", dpi=2, zoom=2), id="window-dpi2-zoom2"),
    pytest.param(
        _DrawingCase(container="window", dpi=2, zoom=2, no_global_scaling=True),
        id="window-dpi2-zoom2-no-global",
    ),
    pytest.param(_DrawingCase(container="plot", dpi=1, zoom=1), id="plot-dpi1-zoom1"),
    pytest.param(_DrawingCase(container="plot", dpi=2, zoom=1), id="plot-dpi2-zoom1"),
    pytest.param(_DrawingCase(container="plot", dpi=1, zoom=2), id="plot-dpi1-zoom2"),
    pytest.param(_DrawingCase(container="plot", dpi=2, zoom=2), id="plot-dpi2-zoom2"),
    pytest.param(
        _DrawingCase(container="plot", dpi=2, zoom=1, axis_range=50),
        id="plot-dpi2-axis-zoom2",
    ),
)


@pytest.mark.parametrize("case", _CASES)
def test_coordinate_radius_tracks_transformed_coordinate_distance(
    context: dcg.Context, case: _DrawingCase
) -> None:
    """Check that a positive radius extends to center +/- radius in X.

    This compares an item of 4x4 coordinate units with a circle
    of radius 4. the 4x4 item width must match the observed
    radius.
    """
    parent = _drawing_parent(context, case)
    marker = dcg.DrawInvisibleButton(
        context, parent=parent, p1=(20, 20), p2=(24, 24), no_input=True
    )
    dcg.DrawCircle(
        context, parent=parent, center=(20, 20), radius=4,
        color=(0, 0, 0, 0), fill=(255, 0, 0, 255), segments=128,
    )
    bounds = _red_bounds(_render_pixels(context))
    assert marker.state.visible
    left, _, right, _ = bounds
    center_x = marker.state.pos_to_viewport.x
    radius_px = marker.state.rect_size.x
    # Allow for pixel quantization and antialiasing at each fill edge.
    assert left == pytest.approx(center_x - radius_px, abs=2)
    assert right == pytest.approx(center_x + radius_px, abs=2)


@pytest.mark.parametrize("case", _CASES)
def test_positive_thickness_tracks_coordinate_distance(
    context: dcg.Context, case: _DrawingCase
) -> None:
    """Check that positive thickness tracks the X coordinate scale.

    Compare the width of a 4-unit marker with the height of a line of
    thickness 4. The coordinate transform already includes any DPI scale;
    no extra DPI factor is applied. Plot cases use the default line weight.
    """
    parent = _drawing_parent(context, case)
    marker = dcg.DrawInvisibleButton(
        context, parent=parent, p1=(10, 15), p2=(14, 19), no_input=True
    )
    dcg.DrawLine(
        context, parent=parent, p1=(10, 15), p2=(30, 15),
        color=(255, 0, 0, 255), thickness=4,
    )
    _, top, _, bottom = _red_bounds(_render_pixels(context))
    assert marker.state.visible
    assert bottom - top == pytest.approx(marker.state.rect_size.x, abs=2)


@pytest.mark.parametrize("container", ("window", "plot"))
def test_positive_thickness_preserves_physical_size_across_dpi(
    context: dcg.Context, *, container: str
) -> None:
    """Check that doubling DPI doubles coordinate distances and stroke pixels.

    Render the same drawing at scales 1 and 2, using an unchanged plot axis
    range or window coordinates. Compare both the coordinate marker width and
    the line thickness, so an extra DPI multiplication cannot pass unnoticed.
    """
    parent = _drawing_parent(context, _DrawingCase(container=container, dpi=1, zoom=1))
    marker = dcg.DrawInvisibleButton(
        context, parent=parent, p1=(10, 50), p2=(14, 54), no_input=True
    )
    dcg.DrawLine(
        context, parent=parent, p1=(10, 50), p2=(30, 50),
        color=(255, 0, 0, 255), thickness=4,
    )
    _, top, _, bottom = _red_bounds(_render_pixels(context))
    marker_width = marker.state.rect_size.x
    thickness = bottom - top
    context.viewport.scale = 2
    _, top, _, bottom = _red_bounds(_render_pixels(context))
    assert marker.state.rect_size.x == pytest.approx(2 * marker_width, abs=2)
    assert bottom - top == pytest.approx(2 * thickness, abs=2)


@pytest.mark.parametrize("case", _CASES)
def test_negative_thickness_ignores_coordinate_zoom(
    context: dcg.Context, case: _DrawingCase
) -> None:
    """Check that negative thickness ignores coordinate zoom.

    Measure a horizontal line of thickness -4 in the framebuffer. Its height
    should be 4 times the viewport DPI scale, or 4 pixels when the window opts
    out of global scaling, across both DrawingScale and plot-axis zoom cases.
    """
    parent = _drawing_parent(context, case)
    dcg.DrawLine(
        context, parent=parent, p1=(10, 15), p2=(30, 15),
        color=(255, 0, 0, 255), thickness=-4,
    )
    _, top, _, bottom = _red_bounds(_render_pixels(context))
    scale = 1 if case.no_global_scaling else case.dpi
    assert bottom - top == pytest.approx(4 * scale, abs=2)


@pytest.mark.parametrize("case", _CASES)
def test_negative_radius_ignores_coordinate_zoom(
    context: dcg.Context, case: _DrawingCase
) -> None:
    """Check that negative radius ignores coordinate zoom.

    Measure the diameter of a filled circle with radius -8. It should be 16
    times the viewport DPI scale, or 16 pixels when a window opts out of global
    scaling.
    """
    parent = _drawing_parent(context, case)
    dcg.DrawCircle(
        context, parent=parent, center=(20, 20), radius=-8,
        color=(0, 0, 0, 0), fill=(255, 0, 0, 255), segments=128,
    )
    left, _, right, _ = _red_bounds(_render_pixels(context))
    scale = 1 if case.no_global_scaling else case.dpi
    assert right - left == pytest.approx(16 * scale, abs=2)


@pytest.mark.parametrize("relative", (False, True))
@pytest.mark.parametrize("button_child", (False, True))
def test_negative_radius_respects_window_dpi_opt_out(
    context: dcg.Context, *, relative: bool, button_child: bool
) -> None:
    """Check that the DPI opt-out reaches negative radii, including button children."""
    context.viewport.scale = 2
    window = dcg.Window(context, width=450, height=350)
    drawing = dcg.DrawInWindow(
        context, parent=window, width=360, height=260,
        relative=relative, no_global_scaling=True,
    )
    center = (0.25, 0.25) if relative else (50, 50)
    parent = drawing
    if button_child:
        p2 = (0.5, 0.5) if relative else (100, 100)
        parent = dcg.DrawInvisibleButton(
            context, parent=drawing, p1=center, p2=p2, no_input=True
        )
        center = (0.5, 0.5)
    dcg.DrawCircle(
        context, parent=parent, center=center, radius=-8,
        color=(0, 0, 0, 0), fill=(255, 0, 0, 255), segments=128,
    )
    left, _, right, _ = _red_bounds(_render_pixels(context))
    assert right - left == pytest.approx(16, abs=2)


@pytest.mark.parametrize("parent_opt_out", (False, True))
@pytest.mark.parametrize("reset_opt_out", (False, True))
def test_negative_radius_no_parent_scaling_uses_own_dpi_policy(
    context: dcg.Context, *, parent_opt_out: bool, reset_opt_out: bool
) -> None:
    """Check that a scaling reset chooses its own DPI policy for negative radii."""
    context.viewport.scale = 2
    window = dcg.Window(context, width=450, height=350)
    drawing = dcg.DrawInWindow(
        context, parent=window, width=360, height=260, no_global_scaling=parent_opt_out
    )
    reset = dcg.DrawingScale(
        context, parent=drawing, origin=(50, 50),
        no_parent_scaling=True, no_global_scaling=reset_opt_out,
    )
    dcg.DrawCircle(
        context, parent=reset, center=(0, 0), radius=-8,
        color=(0, 0, 0, 0), fill=(255, 0, 0, 255), segments=128,
    )
    left, _, right, _ = _red_bounds(_render_pixels(context))
    assert right - left == pytest.approx(16 if reset_opt_out else 32, abs=2)


@pytest.mark.parametrize("parent_opt_out", (False, True))
def test_negative_radius_scaling_reset_restores_parent_policy(
    context: dcg.Context, *, parent_opt_out: bool
) -> None:
    """Check that a reset's DPI policy does not leak to subsequent siblings.

    Compare both the radius of a red circle and the width of a blue stroke
    after the reset with the parent drawing's screen-space DPI policy.
    """
    context.viewport.scale = 2
    window = dcg.Window(context, width=450, height=350)
    drawing = dcg.DrawInWindow(
        context, parent=window, width=360, height=260, no_global_scaling=parent_opt_out
    )
    reset = dcg.DrawingScale(
        context, parent=drawing, no_parent_scaling=True, no_global_scaling=not parent_opt_out
    )
    dcg.DrawCircle(
        context, parent=reset, center=(30, 30), radius=-8, fill=(0, 255, 0, 255)
    )
    dcg.DrawCircle(
        context, parent=drawing, center=(100, 100), radius=-8,
        color=(0, 0, 0, 0), fill=(255, 0, 0, 255), segments=128,
    )
    dcg.DrawLine(
        context, parent=drawing, p1=(50, 150), p2=(150, 150),
        color=(0, 0, 255, 255), thickness=-4,
    )
    pixels = _render_pixels(context)
    left, _, right, _ = _red_bounds(pixels)
    assert right - left == pytest.approx(16 if parent_opt_out else 32, abs=2)
    blue = (pixels[:, :, 0] < 80) & (pixels[:, :, 1] < 80) & (pixels[:, :, 2] > 180)
    assert np.count_nonzero(np.any(blue, axis=1)) == pytest.approx(
        4 if parent_opt_out else 8, abs=1
    )


def test_negative_radius_ignores_plot_line_weight(context: dcg.Context) -> None:
    """Check that plot line-weight styling does not change screen-space radii."""
    context.viewport.scale = 2
    window = dcg.Window(context, width=450, height=350)
    plot = dcg.Plot(context, parent=window, width=360, height=260)
    for axis in (plot.X1, plot.Y1):
        axis.no_initial_fit = True
        axis.min = 0
        axis.max = 100
    theme = dcg.ThemeStyleImPlot(context, line_weight=3)
    drawing = dcg.DrawInPlot(context, parent=plot, theme=theme)
    dcg.DrawCircle(
        context, parent=drawing, center=(50, 50), radius=-8,
        color=(0, 0, 0, 0), fill=(255, 0, 0, 255), segments=128,
    )
    dcg.DrawLine(
        context, parent=drawing, p1=(30, 30), p2=(70, 30),
        color=(0, 255, 0, 255), thickness=-2,
    )
    pixels = _render_pixels(context)
    left, _, right, _ = _red_bounds(pixels)
    assert right - left == pytest.approx(32, abs=2)
    green = (pixels[:, :, 0] < 80) & (pixels[:, :, 1] > 180) & (pixels[:, :, 2] < 80)
    assert np.count_nonzero(np.any(green, axis=1)) == pytest.approx(12, abs=2)


def test_negative_radius_viewport_drawlist_uses_pixels(context: dcg.Context) -> None:
    """Check that viewport draw-list radii use physical pixels regardless of DPI."""
    context.viewport.scale = 2
    drawing = dcg.ViewportDrawList(context)
    dcg.DrawCircle(
        context, parent=drawing, center=(100, 100), radius=-8,
        color=(0, 0, 0, 0), fill=(255, 0, 0, 255), segments=128,
    )
    left, _, right, _ = _red_bounds(_render_pixels(context))
    assert right - left == pytest.approx(16, abs=2)


@dataclass(frozen=True, kw_only=True)
class _PlotStrokeCase:
    """Describe the DPI, axis zoom, theme scaling and drawing thickness."""

    dpi: float
    axis_range: float
    no_scaling: bool
    thickness: float


_PLOT_STROKE_CASES = tuple(
    pytest.param(
        _PlotStrokeCase(
            dpi=dpi, axis_range=axis_range, no_scaling=no_scaling, thickness=thickness
        ),
        id=f"dpi{dpi}-range{axis_range}-no-scaling{no_scaling}-thickness{thickness}",
    )
    for dpi, axis_range, no_scaling, thickness in product(
        (1.0, 1.5, 2.0), (50.0, 100.0), (False, True), (2.0, -2.0)
    )
)


@pytest.mark.parametrize("case", _PLOT_STROKE_CASES)
@pytest.mark.parametrize("orientation", ("horizontal", "vertical"))
def test_plot_line_width_matches_drawing_style(
    context: dcg.Context, case: _PlotStrokeCase, *, orientation: str
) -> None:
    """Compare an ImPlot line series and DrawLine under the same plot style.

    The red PlotLine uses the effective line weight in pixels regardless of
    axis zoom. The green DrawLine uses twice that weight for negative thickness
    or twice the X coordinate scale for positive thickness, regardless of style.
    A marker independently measures that coordinate scale.
    """
    # Apply one shared plot style to both the series and the drawing.
    context.viewport.scale = case.dpi
    window = dcg.Window(context, width=450, height=350)
    style = dcg.ThemeStyleImPlot(context, line_weight=4, no_scaling=case.no_scaling)
    plot = dcg.Plot(context, parent=window, width=360, height=260, theme=style)
    for axis in (plot.X1, plot.Y1):
        axis.no_initial_fit = True
        axis.min = 0
        axis.max = case.axis_range

    # Keep the differently colored lines apart so each width is measurable.
    color = dcg.ThemeColorImPlot(context, line=(255, 0, 0, 255))
    if orientation == "horizontal":
        x, y = [10, 40], [15, 15]
        p1, p2 = (10, 35), (40, 35)
    else:
        x, y = [15, 15], [10, 40]
        p1, p2 = (35, 10), (35, 40)
    dcg.PlotLine(context, parent=plot, X=x, Y=y, theme=color)
    drawing = dcg.DrawInPlot(context, parent=plot)
    marker = dcg.DrawInvisibleButton(
        context, parent=drawing, p1=(20, 20), p2=(22, 22), no_input=True
    )
    dcg.DrawLine(
        context, parent=drawing, p1=p1, p2=p2,
        color=(0, 255, 0, 255), thickness=case.thickness,
    )

    # The series weight is a pixel size and does not depend on axis zoom.
    pixels = _render_pixels(context)
    assert marker.state.visible
    red_left, red_top, red_right, red_bottom = _red_bounds(pixels)
    red_width = red_bottom - red_top if orientation == "horizontal" else red_right - red_left
    red_length = red_right - red_left if orientation == "horizontal" else red_bottom - red_top
    assert red_length > 20
    line_weight = 4 if case.no_scaling else 4 * case.dpi
    assert red_width == pytest.approx(line_weight, abs=1.5)

    # Compare the drawing against the independent coordinate-scale marker.
    green = (pixels[:, :, 0] < 80) & (pixels[:, :, 1] > 180) & (pixels[:, :, 2] < 80)
    green_width = np.count_nonzero(np.any(green, axis=1 if orientation == "horizontal" else 0))
    if case.thickness > 0:
        expected = case.thickness * marker.state.rect_size.x / 2
    else:
        expected = -case.thickness * line_weight
    assert green_width == pytest.approx(expected, abs=2)


@pytest.mark.parametrize("dpi", (1.0, 2.0))
@pytest.mark.parametrize("axis_range", (50.0, 100.0))
def test_plot_line_default_width_scales_once_with_dpi(
    context: dcg.Context, *, dpi: float, axis_range: float
) -> None:
    """Check that the default PlotLine is one logical pixel wide.

    Render a horizontal series without a line-weight override and count its
    red framebuffer rows. DPI should change that pixel count, but axis zoom
    should not. Use integer DPI scales to avoid subpixel rasterization.
    """
    context.viewport.scale = dpi
    window = dcg.Window(context, width=450, height=350)
    plot = dcg.Plot(context, parent=window, width=360, height=260)
    for axis in (plot.X1, plot.Y1):
        axis.no_initial_fit = True
        axis.min = 0
        axis.max = axis_range
    color = dcg.ThemeColorImPlot(context, line=(255, 0, 0, 255))
    dcg.PlotLine(
        context, parent=plot, X=[10, 40], Y=[axis_range / 2, axis_range / 2], theme=color
    )

    left, top, right, bottom = _red_bounds(_render_pixels(context))
    assert right - left > 20
    assert bottom - top == dpi


@pytest.mark.parametrize("dpi", (1.0, 2.0))
def test_plot_line_item_theme_does_not_change_sibling_strokes(
    context: dcg.Context, *, dpi: float
) -> None:
    """Check that a line-series theme does not leak to subsequent plot drawings.

    Draw a red series with an item-local line weight of 2, followed by a blue
    series and green DrawLine using their plot's weight of 4. Their measured
    widths must reflect the distinct weights, each scaled once by DPI.
    """
    # Use different weights on the plot and its first child.
    context.viewport.scale = dpi
    window = dcg.Window(context, width=450, height=350)
    style = dcg.ThemeStyleImPlot(context, line_weight=4)
    plot = dcg.Plot(context, parent=window, width=360, height=260, theme=style)
    for axis in (plot.X1, plot.Y1):
        axis.no_initial_fit = True
        axis.min = 0
        axis.max = 100
    item_theme = dcg.ThemeList(context)
    dcg.ThemeStyleImPlot(context, parent=item_theme, line_weight=2)
    dcg.ThemeColorImPlot(context, parent=item_theme, line=(255, 0, 0, 255))
    dcg.PlotLine(context, parent=plot, X=[10, 40], Y=[25, 25], theme=item_theme)
    blue_theme = dcg.ThemeColorImPlot(context, line=(0, 0, 255, 255))
    dcg.PlotLine(context, parent=plot, X=[10, 40], Y=[38, 38], theme=blue_theme)
    drawing = dcg.DrawInPlot(context, parent=plot)
    dcg.DrawLine(
        context, parent=drawing, p1=(10, 50), p2=(40, 50),
        color=(0, 255, 0, 255), thickness=-1,
    )
    # Both subsequent children must use the restored plot weight.
    pixels = _render_pixels(context)
    _, top, _, bottom = _red_bounds(pixels)
    assert bottom - top == pytest.approx(2 * dpi, abs=1)
    green = (pixels[:, :, 0] < 80) & (pixels[:, :, 1] > 180) & (pixels[:, :, 2] < 80)
    blue = (pixels[:, :, 0] < 80) & (pixels[:, :, 1] < 80) & (pixels[:, :, 2] > 180)
    assert np.count_nonzero(np.any(green, axis=1)) == pytest.approx(4 * dpi, abs=1)
    assert np.count_nonzero(np.any(blue, axis=1)) == pytest.approx(4 * dpi, abs=1)


@pytest.mark.parametrize("dpi", (1.0, 2.0))
@pytest.mark.parametrize("no_scaling", (False, True))
@pytest.mark.parametrize("button_child", (False, True))
def test_plot_line_weight_affects_only_negative_thickness(
    context: dcg.Context, *, dpi: float, no_scaling: bool, button_child: bool
) -> None:
    """Check that line weight affects negative, but not positive, thickness.

    Compare a positive red stroke to a one-unit marker and a negative green
    stroke to the effective pixel line weight. Change the theme after rendering:
    the red width must stay the same while the green width follows the new
    weight. With no_scaling, the line weight remains in physical pixels.
    """
    context.viewport.scale = dpi
    window = dcg.Window(context, width=450, height=350)
    plot = dcg.Plot(context, parent=window, width=360, height=260)
    for axis in (plot.X1, plot.Y1):
        axis.no_initial_fit = True
        axis.min = 0
        axis.max = 100
    theme = dcg.ThemeStyleImPlot(context, line_weight=3, no_scaling=no_scaling)
    drawing = dcg.DrawInPlot(context, parent=plot, theme=theme)
    marker = dcg.DrawInvisibleButton(
        context, parent=drawing, p1=(20, 40), p2=(40, 60), no_input=True
    )
    if button_child:
        parent = marker
        p1, p2 = (0.2, 0.5), (0.8, 0.5)
        thickness = 0.05
    else:
        parent = drawing
        p1, p2 = (20, 50), (60, 50)
        thickness = 1
    dcg.DrawLine(
        context, parent=parent, p1=p1, p2=p2,
        color=(255, 0, 0, 255), thickness=thickness,
    )
    dcg.DrawLine(
        context, parent=drawing, p1=(20, 25), p2=(60, 25),
        color=(0, 255, 0, 255), thickness=-4,
    )
    pixels = _render_pixels(context)
    assert marker.state.visible
    _, top, _, bottom = _red_bounds(pixels)
    line_weight = 3 if no_scaling else 3 * dpi
    assert bottom - top == pytest.approx(marker.state.rect_size.x * 0.05, abs=2)
    green = (pixels[:, :, 0] < 80) & (pixels[:, :, 1] > 180) & (pixels[:, :, 2] < 80)
    assert np.count_nonzero(np.any(green, axis=1)) == pytest.approx(4 * line_weight, abs=2)

    # Changing the theme affects the screen-space stroke but not coordinate sizing.
    theme.line_weight = 5
    pixels = _render_pixels(context)
    _, new_top, _, new_bottom = _red_bounds(pixels)
    assert new_bottom - new_top == bottom - top
    green = (pixels[:, :, 0] < 80) & (pixels[:, :, 1] > 180) & (pixels[:, :, 2] < 80)
    new_line_weight = 5 if no_scaling else 5 * dpi
    assert np.count_nonzero(np.any(green, axis=1)) == pytest.approx(4 * new_line_weight, abs=2)


@pytest.mark.parametrize("no_global_scaling", (False, True))
@pytest.mark.parametrize("thickness", (4.0, -4.0))
def test_thickness_scaling_reset_uses_own_dpi_policy(
    context: dcg.Context, *, no_global_scaling: bool, thickness: float
) -> None:
    """Check that a scaling reset applies DPI once and ignores parent zoom."""
    context.viewport.scale = 2
    window = dcg.Window(context, width=450, height=350)
    drawing = dcg.DrawInWindow(context, parent=window, width=360, height=260)
    zoom = dcg.DrawingScale(context, parent=drawing, scales=(2, 2))
    reset = dcg.DrawingScale(
        context, parent=zoom, origin=(40, 40), scales=(2, 2),
        no_parent_scaling=True, no_global_scaling=no_global_scaling,
    )
    dcg.DrawLine(
        context, parent=reset, p1=(0, 0), p2=(30, 0),
        color=(255, 0, 0, 255), thickness=thickness,
    )
    _, top, _, bottom = _red_bounds(_render_pixels(context))
    dpi_scale = 1 if no_global_scaling else 2
    zoom_scale = 2 if thickness > 0 else 1
    assert bottom - top == pytest.approx(4 * dpi_scale * zoom_scale, abs=2)


@pytest.mark.parametrize("no_global_scaling", (False, True))
@pytest.mark.parametrize("no_scaling", (False, True))
def test_thickness_scaling_reset_restores_plot_style(
    context: dcg.Context, *, no_global_scaling: bool, no_scaling: bool
) -> None:
    """Check that a reset restores the plot style for negative thickness.

    Compare a positive red stroke with a coordinate marker and a negative blue
    stroke with the plot's DPI-scaled line weight after a reset has rendered.
    """
    context.viewport.scale = 2
    window = dcg.Window(context, width=450, height=350)
    plot = dcg.Plot(context, parent=window, width=360, height=260)
    for axis in (plot.X1, plot.Y1):
        axis.no_initial_fit = True
        axis.min = 0
        axis.max = 100
    theme = dcg.ThemeStyleImPlot(context, line_weight=3, no_scaling=no_scaling)
    drawing = dcg.DrawInPlot(context, parent=plot, theme=theme)
    reset = dcg.DrawingScale(
        context, parent=drawing, origin=(30, 30), no_parent_scaling=True,
        no_global_scaling=no_global_scaling,
    )
    dcg.DrawLine(
        context, parent=reset, p1=(0, 0), p2=(20, 0),
        color=(0, 255, 0, 255), thickness=4,
    )
    marker = dcg.DrawInvisibleButton(
        context, parent=drawing, p1=(20, 50), p2=(21, 51), no_input=True
    )
    dcg.DrawLine(
        context, parent=drawing, p1=(20, 50), p2=(60, 50),
        color=(255, 0, 0, 255), thickness=1,
    )
    dcg.DrawLine(
        context, parent=drawing, p1=(20, 70), p2=(60, 70),
        color=(0, 0, 255, 255), thickness=-2,
    )
    pixels = _render_pixels(context)
    _, top, _, bottom = _red_bounds(pixels)
    assert marker.state.visible
    line_weight = 3 if no_scaling else 6
    assert bottom - top == pytest.approx(marker.state.rect_size.x, abs=2)
    green = (pixels[:, :, 0] < 80) & (pixels[:, :, 1] > 180) & (pixels[:, :, 2] < 80)
    assert np.count_nonzero(np.any(green, axis=1)) == pytest.approx(
        4 if no_global_scaling else 8, abs=2
    )
    blue = (pixels[:, :, 0] < 80) & (pixels[:, :, 1] < 80) & (pixels[:, :, 2] > 180)
    assert np.count_nonzero(np.any(blue, axis=1)) == pytest.approx(2 * line_weight, abs=2)


@pytest.mark.parametrize("thickness", (4.0, -4.0))
def test_viewport_drawlist_thickness_uses_pixels(
    context: dcg.Context, *, thickness: float
) -> None:
    """Check that viewport draw-list strokes use physical pixels at DPI 2."""
    context.viewport.scale = 2
    drawing = dcg.ViewportDrawList(context)
    dcg.DrawLine(
        context, parent=drawing, p1=(50, 50), p2=(100, 50),
        color=(255, 0, 0, 255), thickness=thickness,
    )
    _, top, _, bottom = _red_bounds(_render_pixels(context))
    assert bottom - top == pytest.approx(4, abs=1)


@pytest.mark.parametrize("dpi", (1.0, 2.0))
@pytest.mark.parametrize("no_global_scaling", (False, True))
@pytest.mark.parametrize("primitive", ("circle", "line"))
def test_relative_window_positive_size_tracks_coordinate_distance(
    context: dcg.Context, *, dpi: float, no_global_scaling: bool, primitive: str
) -> None:
    """Check positive sizes in a relative DrawInWindow.

    In a relative window, compare a 0.05-unit circle radius or line thickness
    with the width of a 0.05-unit marker after a 2x DrawingScale. The circle
    diameter should be twice the marker width; the line height should equal it.
    Repeat with and without global scaling at both DPI values to check that no
    extra DPI factor is added to the already transformed X distance.
    """
    context.viewport.scale = dpi
    window = dcg.Window(context, width=450, height=350)
    drawing = dcg.DrawInWindow(
        context, parent=window, width=360, height=260,
        relative=True, no_global_scaling=no_global_scaling,
    )
    parent = dcg.DrawingScale(context, parent=drawing, scales=(2, 2))
    marker = dcg.DrawInvisibleButton(
        context, parent=parent, p1=(0.2, 0.2), p2=(0.25, 0.25), no_input=True
    )
    if primitive == "circle":
        dcg.DrawCircle(
            context, parent=parent, center=(0.2, 0.2), radius=0.05,
            color=(0, 0, 0, 0), fill=(255, 0, 0, 255), segments=128,
        )
    else:
        dcg.DrawLine(
            context, parent=parent, p1=(0.2, 0.2), p2=(0.3, 0.2),
            color=(255, 0, 0, 255), thickness=0.05,
        )
    pixels = _render_pixels(context)
    assert marker.state.visible
    left, top, right, bottom = _red_bounds(pixels)
    if primitive == "circle":
        assert right - left == pytest.approx(2 * marker.state.rect_size.x, abs=2)
    else:
        assert bottom - top == pytest.approx(marker.state.rect_size.x, abs=2)


@pytest.mark.parametrize("dpi", (1.0, 2.0))
@pytest.mark.parametrize("zoom", (1.0, 2.0))
@pytest.mark.parametrize("container", ("window", "plot"))
def test_invisible_button_coordinate_radius_tracks_button_width(
    context: dcg.Context, *, container: str, dpi: float, zoom: float
) -> None:
    """Check that a button child's positive radius uses normalized X coordinates.

    Draw a circle centered at (0.5, 0.5) with radius 0.25 inside the button.
    Its red fill should span half the button's screen width, from 25% to 75%
    of that width. The green screen-space line confirms a child was rendered
    even if the red circle is too small to produce an opaque pixel.
    """
    parent = _drawing_parent(context, _DrawingCase(container=container, dpi=dpi, zoom=zoom))
    button = dcg.DrawInvisibleButton(
        context, parent=parent, p1=(20, 20), p2=(40, 40), no_input=True
    )
    dcg.DrawLine(
        context, parent=button, p1=(0.2, 0.2), p2=(0.8, 0.2),
        color=(0, 255, 0, 255), thickness=-4,
    )
    dcg.DrawCircle(
        context, parent=button, center=(0.5, 0.5), radius=0.25,
        color=(0, 0, 0, 0), fill=(255, 0, 0, 255), segments=128,
    )
    pixels = _render_pixels(context)
    assert button.state.visible
    _assert_button_child_rendered(pixels)
    # A zero width is a meaningful failure for a subpixel red circle.
    width, _ = _red_size(pixels)
    assert width == pytest.approx(button.state.rect_size.x * 0.5, abs=2)
    left, _, right, _ = _red_bounds(pixels)
    assert left == pytest.approx(
        button.state.pos_to_viewport.x + button.state.rect_size.x * 0.25, abs=2
    )
    assert right == pytest.approx(
        button.state.pos_to_viewport.x + button.state.rect_size.x * 0.75, abs=2
    )


@pytest.mark.parametrize("dpi", (1.0, 2.0))
@pytest.mark.parametrize("zoom", (1.0, 2.0))
@pytest.mark.parametrize("container", ("window", "plot"))
def test_invisible_button_positive_thickness_tracks_button_width(
    context: dcg.Context, *, container: str, dpi: float, zoom: float
) -> None:
    """Check that a button child's positive thickness uses normalized X coordinates.

    Draw a horizontal line with thickness 0.2 and compare its red pixel height
    with 20% of the button's screen width. The green screen-space line confirms
    that children rendered even if the red stroke is too thin to detect.
    """
    parent = _drawing_parent(context, _DrawingCase(container=container, dpi=dpi, zoom=zoom))
    button = dcg.DrawInvisibleButton(
        context, parent=parent, p1=(20, 20), p2=(40, 40), no_input=True
    )
    dcg.DrawLine(
        context, parent=button, p1=(0.2, 0.2), p2=(0.8, 0.2),
        color=(0, 255, 0, 255), thickness=-4,
    )
    dcg.DrawLine(
        context, parent=button, p1=(0.2, 0.5), p2=(0.8, 0.5),
        color=(255, 0, 0, 255), thickness=0.2,
    )
    pixels = _render_pixels(context)
    assert button.state.visible
    _assert_button_child_rendered(pixels)
    _, height = _red_size(pixels)
    assert height == pytest.approx(button.state.rect_size.x * 0.2, abs=1.5)


@pytest.mark.parametrize("dpi", (1.0, 2.0))
@pytest.mark.parametrize("zoom", (1.0, 2.0))
@pytest.mark.parametrize("container", ("window", "plot"))
def test_invisible_button_negative_thickness_uses_parent_screen_scale(
    context: dcg.Context, *, container: str, dpi: float, zoom: float
) -> None:
    """Check that a button child's negative thickness inherits parent screen scaling.

    Draw a horizontal line with thickness -4 and measure its framebuffer height.
    It should be 4 times DPI, independent of the button width and DrawingScale
    zoom, in both a window and a plot with the default line-weight style.
    """
    parent = _drawing_parent(context, _DrawingCase(container=container, dpi=dpi, zoom=zoom))
    button = dcg.DrawInvisibleButton(
        context, parent=parent, p1=(20, 20), p2=(40, 40), no_input=True
    )
    dcg.DrawLine(
        context, parent=button, p1=(0.2, 0.5), p2=(0.8, 0.5),
        color=(255, 0, 0, 255), thickness=-4,
    )
    pixels = _render_pixels(context)
    assert button.state.visible
    _, top, _, bottom = _red_bounds(pixels)
    assert bottom - top == pytest.approx(4 * dpi, abs=2)


@pytest.mark.parametrize("no_global_scaling", (False, True))
@pytest.mark.parametrize("thickness", (0.2, -4.0))
def test_invisible_button_thickness_respects_window_dpi_policy(
    context: dcg.Context, *, no_global_scaling: bool, thickness: float
) -> None:
    """Check that button children inherit a window's DPI and zoom policy."""
    parent = _drawing_parent(
        context,
        _DrawingCase(container="window", dpi=2, zoom=2, no_global_scaling=no_global_scaling),
    )
    button = dcg.DrawInvisibleButton(
        context, parent=parent, p1=(20, 20), p2=(40, 40), no_input=True
    )
    dcg.DrawLine(
        context, parent=button, p1=(0.2, 0.5), p2=(0.8, 0.5),
        color=(255, 0, 0, 255), thickness=thickness,
    )
    _, top, _, bottom = _red_bounds(_render_pixels(context))
    assert button.state.visible
    expected = 0.2 * button.state.rect_size.x if thickness > 0 else (
        4 if no_global_scaling else 8
    )
    assert bottom - top == pytest.approx(expected, abs=1.5)


@pytest.mark.parametrize("case", _CASES)
def test_circle_positive_outline_outer_edge_tracks_radius_and_thickness(
    context: dcg.Context, case: _DrawingCase
) -> None:
    """Compare the circle outline's outer edge with the coordinate-space formula.

    An independent invisible marker measures r + t/2 coordinate units from
    the circle center. The outline should end there, within rasterization error.
    """
    parent = _drawing_parent(context, case)
    marker = dcg.DrawInvisibleButton(
        context, parent=parent, p1=(30, 30), p2=(36, 36), no_input=True
    )
    dcg.DrawCircle(
        context, parent=parent, center=(30, 30), radius=4, thickness=4,
        color=(255, 0, 0, 255), fill=(0, 0, 0, 0), segments=128,
    )
    left, _, right, _ = _red_bounds(_render_pixels(context))
    assert marker.state.visible
    center = marker.state.pos_to_viewport.x
    distance = marker.state.rect_size.x
    assert left == pytest.approx(center - distance, abs=2)
    assert right == pytest.approx(center + distance, abs=2)


@pytest.mark.parametrize("dpi", (1.0, 2.0))
@pytest.mark.parametrize("no_scaling", (False, True))
def test_circle_positive_outline_in_plot_ignores_line_weight(
    context: dcg.Context, *, dpi: float, no_scaling: bool
) -> None:
    """Check that plot line weight does not change a positive circle outline.

    Compare the visible outer edge with an independent marker measuring
    r + t/2 coordinate units, then change the theme weight and compare again.
    """
    context.viewport.scale = dpi
    window = dcg.Window(context, width=450, height=350)
    plot = dcg.Plot(context, parent=window, width=360, height=260)
    for axis in (plot.X1, plot.Y1):
        axis.no_initial_fit = True
        axis.min = 0
        axis.max = 100
    theme = dcg.ThemeStyleImPlot(context, line_weight=3, no_scaling=no_scaling)
    drawing = dcg.DrawInPlot(context, parent=plot, theme=theme)
    marker = dcg.DrawInvisibleButton(
        context, parent=drawing, p1=(50, 50), p2=(56, 56), no_input=True
    )
    dcg.DrawCircle(
        context, parent=drawing, center=(50, 50), radius=4, thickness=4,
        color=(255, 0, 0, 255), fill=(0, 0, 0, 0), segments=128,
    )
    left, _, right, _ = _red_bounds(_render_pixels(context))
    assert marker.state.visible
    center = marker.state.pos_to_viewport.x
    distance = marker.state.rect_size.x
    assert left == pytest.approx(center - distance, abs=2)
    assert right == pytest.approx(center + distance, abs=2)
    theme.line_weight = 5
    new_left, _, new_right, _ = _red_bounds(_render_pixels(context))
    assert (new_left, new_right) == (left, right)


@pytest.mark.parametrize("dpi", (1.0, 2.0))
@pytest.mark.parametrize("primitive", ("circle", "line"))
def test_positive_size_uses_x_scale_with_unequal_axes(
    context: dcg.Context, *, dpi: float, primitive: str
) -> None:
    """Check that positive radius and thickness use X rather than Y scaling.

    Use a 2:1 transform and compare the red primitive with a marker whose
    independently transformed X width and Y height differ by a factor of two.
    """
    context.viewport.scale = dpi
    window = dcg.Window(context, width=450, height=350)
    drawing = dcg.DrawInWindow(context, parent=window, width=360, height=260)
    parent = dcg.DrawingScale(context, parent=drawing, scales=(2, 1))
    marker = dcg.DrawInvisibleButton(
        context, parent=parent, p1=(30, 30), p2=(34, 34), no_input=True
    )
    if primitive == "circle":
        dcg.DrawCircle(
            context, parent=parent, center=(30, 30), radius=4,
            color=(0, 0, 0, 0), fill=(255, 0, 0, 255), segments=128,
        )
    else:
        dcg.DrawLine(
            context, parent=parent, p1=(30, 30), p2=(60, 30),
            color=(255, 0, 0, 255), thickness=4,
        )
    left, top, right, bottom = _red_bounds(_render_pixels(context))
    assert marker.state.visible
    assert marker.state.rect_size.x == pytest.approx(2 * marker.state.rect_size.y, abs=0.1)
    observed = (right - left) / 2 if primitive == "circle" else bottom - top
    assert observed == pytest.approx(marker.state.rect_size.x, abs=2)


@pytest.mark.parametrize("dpi", (1.0, 2.0))
@pytest.mark.parametrize("size", (12.0, -12.0, 0.0))
def test_draw_text_size_responds_to_zoom_by_sign(
    context: dcg.Context, *, dpi: float, size: float
) -> None:
    """Compare the same rendered glyph before and after coordinate zoom.

    Positive DrawText sizes double with X zoom; negative sizes and size zero
    remain unchanged. The latter uses the current font size, not zero pixels.
    """
    context.viewport.scale = dpi
    window = dcg.Window(context, width=450, height=350)
    drawing = dcg.DrawInWindow(context, parent=window, width=360, height=260)
    scale = dcg.DrawingScale(context, parent=drawing, scales=(1, 1))
    dcg.DrawText(context, parent=scale, pos=(20, 20), text="MMMM", size=size,
                 color=(255, 0, 0, 255))
    _, top, _, bottom = _red_bounds(_render_pixels(context))
    initial_height = bottom - top
    scale.scales = (2, 2)
    _, top, _, bottom = _red_bounds(_render_pixels(context))
    factor = 2 if size > 0 else 1
    assert bottom - top == pytest.approx(factor * initial_height, abs=2)


@pytest.mark.parametrize("dpi", (1.0, 2.0))
@pytest.mark.parametrize("no_global_scaling", (False, True))
def test_draw_text_coordinate_and_screen_sizes_render_equivalently(
    context: dcg.Context, *, dpi: float, no_global_scaling: bool
) -> None:
    """Compare glyphs with equivalent coordinate-space and screen-space sizes.

    A 2x X zoom makes size 12 equivalent to screen size -24. The whole glyph
    bounds should agree both with and without the global-scale opt-out.
    """
    context.viewport.scale = dpi
    window = dcg.Window(context, width=450, height=350)
    drawing = dcg.DrawInWindow(
        context, parent=window, width=360, height=260, no_global_scaling=no_global_scaling
    )
    scale = dcg.DrawingScale(context, parent=drawing, scales=(2, 1))
    text = dcg.DrawText(
        context, parent=scale, pos=(20, 20), text="MMMM", size=12,
        color=(255, 0, 0, 255),
    )
    coordinate_bounds = _red_bounds(_render_pixels(context))
    text.size = -24
    assert _red_bounds(_render_pixels(context)) == coordinate_bounds


@pytest.mark.parametrize("viewport_scale", (1.0, 2.0))
@pytest.mark.parametrize("size", (4.0, -4.0))
def test_window_scaling_factor_changes_drawing_size(
    context: dcg.Context, *, viewport_scale: float, size: float
) -> None:
    """Check that a UI item's scaling factor contributes to drawing sizes.

    Measure a stroke before and after doubling its window's scaling factor.
    Both coordinate and screen-space strokes should double in pixel width.
    """
    context.viewport.scale = viewport_scale
    window = dcg.Window(context, width=450, height=350, scaling_factor=1)
    drawing = dcg.DrawInWindow(context, parent=window, width=300, height=200)
    dcg.DrawLine(context, parent=drawing, p1=(20, 30), p2=(100, 30),
                 thickness=size, color=(255, 0, 0, 255))
    _, top, _, bottom = _red_bounds(_render_pixels(context))
    initial_height = bottom - top
    window.scaling_factor = 2
    _, top, _, bottom = _red_bounds(_render_pixels(context))
    assert bottom - top == pytest.approx(2 * initial_height, abs=2)


@pytest.mark.parametrize("theme_on_plot", (False, True))
@pytest.mark.parametrize("no_scaling", (False, True))
def test_plot_line_weight_inherited_from_scaled_ui_parent(
    context: dcg.Context, *, theme_on_plot: bool, no_scaling: bool
) -> None:
    """Measure theme scaling at the UI scope where the plot theme is pushed.

    The window scales by 2 and its child plot by 1.5. A theme on the window
    uses scale 2, whereas one on the plot uses scale 3. An unscaled theme uses
    physical pixels in either scope. A negative DrawLine uses that pixel weight.
    """
    theme = dcg.ThemeStyleImPlot(context, line_weight=4, no_scaling=no_scaling)
    window = dcg.Window(
        context, width=450, height=350, scaling_factor=2,
        theme=None if theme_on_plot else theme,
    )
    plot = dcg.Plot(
        context, parent=window, width=300, height=200, scaling_factor=1.5,
        theme=theme if theme_on_plot else None,
    )
    for axis in (plot.X1, plot.Y1):
        axis.no_initial_fit = True
        axis.min = 0
        axis.max = 100
    drawing = dcg.DrawInPlot(context, parent=plot)
    dcg.DrawLine(context, parent=drawing, p1=(20, 50), p2=(80, 50),
                 thickness=-2, color=(255, 0, 0, 255))
    _, top, _, bottom = _red_bounds(_render_pixels(context))
    theme_scale = 1 if no_scaling else (3 if theme_on_plot else 2)
    assert bottom - top == pytest.approx(2 * 4 * theme_scale, abs=2)


@pytest.mark.parametrize("no_global_scaling", (False, True))
@pytest.mark.parametrize("no_scaling", (False, True))
def test_negative_thickness_in_plot_scaling_reset_ignores_plot_style(
    context: dcg.Context, *, no_global_scaling: bool, no_scaling: bool
) -> None:
    """Measure a negative stroke inside a reset under a custom plot theme.

    The reset discards the parent plot's line weight and uses its own DPI
    policy. Compare the red stroke inside the reset with a green sibling that
    retains the plot's effective line weight.
    """
    context.viewport.scale = 2
    window = dcg.Window(context, width=450, height=350)
    plot = dcg.Plot(context, parent=window, width=360, height=260)
    for axis in (plot.X1, plot.Y1):
        axis.no_initial_fit = True
        axis.min = 0
        axis.max = 100
    theme = dcg.ThemeStyleImPlot(context, line_weight=3, no_scaling=no_scaling)
    drawing = dcg.DrawInPlot(context, parent=plot, theme=theme)
    reset = dcg.DrawingScale(
        context, parent=drawing, origin=(30, 30), no_parent_scaling=True,
        no_global_scaling=no_global_scaling,
    )
    dcg.DrawLine(context, parent=reset, p1=(0, 0), p2=(30, 0),
                 thickness=-4, color=(255, 0, 0, 255))
    dcg.DrawLine(context, parent=drawing, p1=(20, 70), p2=(70, 70),
                 thickness=-2, color=(0, 255, 0, 255))
    pixels = _render_pixels(context)
    _, top, _, bottom = _red_bounds(pixels)
    assert bottom - top == pytest.approx(4 if no_global_scaling else 8, abs=1)
    green = (pixels[:, :, 0] < 80) & (pixels[:, :, 1] > 180) & (pixels[:, :, 2] < 80)
    assert np.count_nonzero(np.any(green, axis=1)) == pytest.approx(
        6 if no_scaling else 12, abs=1
    )


@pytest.mark.parametrize("parent_opt_out", (False, True))
@pytest.mark.parametrize("child_opt_out", (False, True))
def test_drawing_scale_inherit_can_disable_global_scaling(
    context: dcg.Context, *, parent_opt_out: bool, child_opt_out: bool
) -> None:
    """Check that an inheriting DrawingScale can opt out of global scaling.

    At DPI 2, measure a negative stroke under all combinations of the parent
    and child opt-out. Either opt-out makes the stroke use physical pixels.
    """
    context.viewport.scale = 2
    window = dcg.Window(context, width=450, height=350)
    drawing = dcg.DrawInWindow(
        context, parent=window, width=360, height=260, no_global_scaling=parent_opt_out
    )
    scale = dcg.DrawingScale(
        context, parent=drawing, scales=(2, 2), no_global_scaling=child_opt_out
    )
    dcg.DrawLine(
        context, parent=scale, p1=(20, 30), p2=(60, 30),
        thickness=-4, color=(255, 0, 0, 255),
    )
    _, top, _, bottom = _red_bounds(_render_pixels(context))
    assert bottom - top == pytest.approx(4 if parent_opt_out or child_opt_out else 8, abs=1)


@pytest.mark.parametrize("dpi", (1.0, 2.0))
@pytest.mark.parametrize("no_scaling", (False, True))
def test_plot_drawing_scale_opt_out_preserves_transform_and_style(
    context: dcg.Context, *, dpi: float, no_scaling: bool
) -> None:
    """Check plot scale opt-out affects only inherited screen-space sizes.

    Compare transformed positive sizes to a coordinate marker. A negative
    stroke keeps the plot's normalized style, while a sibling outside the
    scale still uses the plot's full pixel line weight.
    """
    context.viewport.scale = dpi
    window = dcg.Window(context, width=450, height=350)
    plot = dcg.Plot(context, parent=window, width=360, height=260)
    for axis in (plot.X1, plot.Y1):
        axis.no_initial_fit = True
        axis.min = 0
        axis.max = 100
    theme = dcg.ThemeStyleImPlot(context, line_weight=4, no_scaling=no_scaling)
    drawing = dcg.DrawInPlot(context, parent=plot, theme=theme)
    scale = dcg.DrawingScale(
        context, parent=drawing, origin=(10, 10), scales=(2, 2), no_global_scaling=True
    )
    marker = dcg.DrawInvisibleButton(
        context, parent=scale, p1=(10, 10), p2=(12, 12), no_input=True
    )
    reference = dcg.DrawInvisibleButton(
        context, parent=drawing, p1=(30, 30), p2=(34, 34), no_input=True
    )
    dcg.DrawLine(
        context, parent=scale, p1=(10, 10), p2=(30, 10),
        color=(255, 0, 0, 255), thickness=2,
    )
    dcg.DrawLine(
        context, parent=scale, p1=(10, 20), p2=(30, 20),
        color=(0, 255, 0, 255), thickness=-2,
    )
    dcg.DrawLine(
        context, parent=drawing, p1=(30, 70), p2=(70, 70),
        color=(0, 0, 255, 255), thickness=-2,
    )
    pixels = _render_pixels(context)
    assert marker.state.visible and reference.state.visible
    assert tuple(marker.state.pos_to_viewport) == pytest.approx(
        tuple(reference.state.pos_to_viewport), abs=0.1
    )
    assert tuple(marker.state.rect_size) == pytest.approx(
        tuple(reference.state.rect_size), abs=0.1
    )
    _, top, _, bottom = _red_bounds(pixels)
    assert bottom - top == pytest.approx(marker.state.rect_size.x, abs=2)
    green = (pixels[:, :, 0] < 80) & (pixels[:, :, 1] > 180) & (pixels[:, :, 2] < 80)
    blue = (pixels[:, :, 0] < 80) & (pixels[:, :, 1] < 80) & (pixels[:, :, 2] > 180)
    line_weight = 4 if no_scaling else 4 * dpi
    assert np.count_nonzero(np.any(green, axis=1)) == pytest.approx(2 * line_weight / dpi, abs=1)
    assert np.count_nonzero(np.any(blue, axis=1)) == pytest.approx(2 * line_weight, abs=1)


@pytest.mark.parametrize("dpi", (1.0, 2.0))
def test_drawing_scale_opt_out_negative_radius_does_not_affect_sibling(
    context: dcg.Context, *, dpi: float
) -> None:
    """Check negative radii use pixels inside an opt-out and DPI outside it.

    Measure a red circle inside the scale and a separate green circle after
    it to verify that the parent's screen-size policy is restored.
    """
    context.viewport.scale = dpi
    window = dcg.Window(context, width=450, height=350)
    drawing = dcg.DrawInWindow(context, parent=window, width=360, height=260)
    scale = dcg.DrawingScale(context, parent=drawing, no_global_scaling=True)
    dcg.DrawCircle(
        context, parent=scale, center=(60, 60), radius=-8, segments=128,
        color=(0, 0, 0, 0), fill=(255, 0, 0, 255),
    )
    dcg.DrawCircle(
        context, parent=drawing, center=(120, 60), radius=-8, segments=128,
        color=(0, 0, 0, 0), fill=(0, 255, 0, 255),
    )
    pixels = _render_pixels(context)
    left, _, right, _ = _red_bounds(pixels)
    green = (pixels[:, :, 0] < 80) & (pixels[:, :, 1] > 180) & (pixels[:, :, 2] < 80)
    assert right - left == pytest.approx(16, abs=2)
    assert np.count_nonzero(np.any(green, axis=0)) == pytest.approx(16 * dpi, abs=2)
