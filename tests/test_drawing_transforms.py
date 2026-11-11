"""Exercise drawing transforms and tile culling through rendered frames."""

import gc
import threading
from collections.abc import Iterator

import dearcygui as dcg
import pytest


@pytest.fixture
def context() -> Iterator[dcg.Context]:
    """Create an initialized hidden viewport."""
    ctx = dcg.Context()
    ctx.viewport.initialize(visible=False, width=800, height=600)
    yield ctx
    ctx.queue.shutdown(wait=True)
    ctx.viewport.destroy()
    gc.collect()


def _render(ctx: dcg.Context, *, count: int = 5) -> None:
    """Render enough frames for plot layout and limits to stabilize."""
    for _ in range(count):
        ctx.viewport.render_frame()


def _plot(ctx: dcg.Context) -> dcg.Plot:
    """Create a plot with fixed linear limits and no left-button panning."""
    window = dcg.Window(ctx, width=700, height=500)
    plot = dcg.Plot(ctx, parent=window, width=600, height=400)
    for axis in (plot.X1, plot.Y1):
        axis.no_initial_fit = True
        axis.min = 0
        axis.max = 30
    plot.pan_button = dcg.MouseButton.RIGHT
    return plot


@pytest.mark.parametrize(
    ("origin", "scales", "p1", "p2"),
    [
        ((0, 0), (1, 1), (2, 2), (4, 4)),
        ((10, 20), (2, -3), (1, 2), (3, 4)),
        ((20, 5), (-2, 3), (1, 2), (3, 4)),
    ],
)
def test_drawing_scale_in_plot_matches_plot_coordinates(
    context: dcg.Context,
    origin: tuple[float, float],
    scales: tuple[float, float],
    p1: tuple[float, float],
    p2: tuple[float, float],
) -> None:
    """Compare transformed geometry with independently specified plot geometry."""
    plot = _plot(context)
    drawings = dcg.DrawInPlot(context, parent=plot)
    reference = dcg.DrawInvisibleButton(
        context,
        parent=drawings,
        p1=tuple(origin[i] + scales[i] * p1[i] for i in range(2)),
        p2=tuple(origin[i] + scales[i] * p2[i] for i in range(2)),
        no_input=True,
    )
    scale = dcg.DrawingScale(context, parent=drawings, origin=origin, scales=scales)
    button = dcg.DrawInvisibleButton(context, parent=scale, p1=p1, p2=p2)

    _render(context)
    assert button.state.visible and reference.state.visible
    assert tuple(button.state.pos_to_viewport) == pytest.approx(
        tuple(reference.state.pos_to_viewport), abs=0.1
    )
    assert tuple(button.state.rect_size) == pytest.approx(
        tuple(reference.state.rect_size), abs=0.1
    )


def test_drawing_scale_in_plot_drag_delta_uses_local_coordinates(context: dcg.Context) -> None:
    """Convert injected mouse movement back into transformed drawing coordinates."""
    plot = _plot(context)
    drawings = dcg.DrawInPlot(context, parent=plot)
    scale = dcg.DrawingScale(context, parent=drawings, origin=(10, 20), scales=(2, -3))
    received = []
    ready = threading.Event()

    def on_drag(sender: dcg.DraggingHandler, target: dcg.DrawInvisibleButton, data) -> None:
        """Record the drag callback before signaling the test thread."""
        received.append(tuple(data.drag_delta))
        ready.set()

    handler = dcg.DraggingHandler(context, callback=on_drag)
    button = dcg.DrawInvisibleButton(
        context, parent=scale, p1=(1, 2), p2=(3, 4), handlers=[handler]
    )
    _render(context)
    assert button.state.visible
    x, y = button.state.pos_to_viewport
    width, height = button.state.rect_size
    assert width > 10 and height > 10
    start_x, start_y = x + width / 2, y + height / 2
    context.inject_mouse_pos(start_x, start_y)
    _render(context, count=3)
    assert button.state.hovered
    context.inject_mouse_down(dcg.MouseButton.LEFT)
    _render(context, count=1)
    assert button.state.active
    context.inject_mouse_pos(start_x + width / 4, start_y + height / 4)
    _render(context, count=1)
    assert ready.wait(5), "Dragging callback did not fire"
    assert received[-1] == pytest.approx((0.5, 0.5), abs=0.04)
    context.inject_mouse_up(dcg.MouseButton.LEFT)
    _render(context, count=1)


def test_nested_drawing_scales_compose_in_plot(context: dcg.Context) -> None:
    """Compose the two affine transforms before applying the plot transform."""
    plot = _plot(context)
    drawings = dcg.DrawInPlot(context, parent=plot)
    outer = dcg.DrawingScale(context, parent=drawings, origin=(10, 20), scales=(2, -3))
    inner = dcg.DrawingScale(context, parent=outer, origin=(1, 2), scales=(2, -1))
    transformed = dcg.DrawInvisibleButton(context, parent=inner, p1=(0, 0), p2=(1, 1))
    reference = dcg.DrawInvisibleButton(
        context, parent=drawings, p1=(12, 14), p2=(16, 17), no_input=True
    )
    _render(context)
    assert transformed.state.visible and reference.state.visible
    assert tuple(transformed.state.pos_to_viewport) == pytest.approx(
        tuple(reference.state.pos_to_viewport), abs=0.1
    )
    assert tuple(transformed.state.rect_size) == pytest.approx(
        tuple(reference.state.rect_size), abs=0.1
    )


def test_drawing_scale_no_parent_scaling_in_plot(context: dcg.Context) -> None:
    """Place a screen-scaled child at the transformed parent origin."""
    plot = _plot(context)
    drawings = dcg.DrawInPlot(context, parent=plot)
    outer = dcg.DrawingScale(context, parent=drawings, origin=(10, 20), scales=(2, -3))
    inner = dcg.DrawingScale(
        context, parent=outer, origin=(1, 2), scales=(20, 30),
        no_parent_scaling=True, no_global_scaling=True,
    )
    button = dcg.DrawInvisibleButton(context, parent=inner, p1=(0, 0), p2=(1, 1))
    origin = dcg.DrawInvisibleButton(
        context, parent=drawings, p1=(12, 14), p2=(12, 14), min_side=2, no_input=True
    )
    _render(context)
    assert button.state.visible and origin.state.visible
    origin_pos = origin.state.pos_to_viewport
    assert tuple(button.state.pos_to_viewport) == pytest.approx(
        (origin_pos.x + 1, origin_pos.y + 1), abs=0.1
    )
    assert tuple(button.state.rect_size) == pytest.approx((20, 30), abs=0.1)


def test_drawing_scale_plot_fit_uses_transformed_coordinates(context: dcg.Context) -> None:
    """Fit axes to transformed drawing coordinates rather than local coordinates."""
    plot = _plot(context)
    drawings = dcg.DrawInPlot(context, parent=plot)
    scale = dcg.DrawingScale(context, parent=drawings, origin=(100, 200), scales=(2, -3))
    dcg.DrawRect(context, parent=scale, pmin=(1, 2), pmax=(3, 4))
    _render(context)
    plot.X1.fit()
    plot.Y1.fit()
    _render(context)
    assert plot.X1.min <= 102 <= plot.X1.max
    assert plot.X1.min <= 106 <= plot.X1.max
    assert plot.Y1.min <= 188 <= plot.Y1.max
    assert plot.Y1.min <= 194 <= plot.Y1.max
    assert plot.X1.min > 30 and plot.Y1.min > 30


def test_drawing_scale_in_log_plot_matches_plot_coordinates(context: dcg.Context) -> None:
    """Apply the affine transform before a nonlinear plot transform."""
    plot = _plot(context)
    plot.X1.scale = dcg.AxisScale.LOG10
    plot.X1.min = 1
    plot.X1.max = 100
    drawings = dcg.DrawInPlot(context, parent=plot)
    scale = dcg.DrawingScale(context, parent=drawings, origin=(10, 20), scales=(2, -3))
    transformed = dcg.DrawInvisibleButton(context, parent=scale, p1=(1, 2), p2=(3, 4))
    reference = dcg.DrawInvisibleButton(
        context, parent=drawings, p1=(12, 14), p2=(16, 8), no_input=True
    )
    _render(context)
    assert transformed.state.visible and reference.state.visible
    assert tuple(transformed.state.pos_to_viewport) == pytest.approx(
        tuple(reference.state.pos_to_viewport), abs=0.1
    )
    assert tuple(transformed.state.rect_size) == pytest.approx(
        tuple(reference.state.rect_size), abs=0.1
    )

@pytest.mark.parametrize(
    "value_type",
    [dcg.DraggedHandlerCallbackValue, dcg.DraggingHandlerCallbackValue],
)
def test_drag_callback_constructor_preserves_legacy_and_explicit_positions(
    context: dcg.Context, value_type: type
) -> None:
    """Keep the original constructor usable while accepting a separate mouse position."""
    delta = dcg.Coord(2, 3)
    click = dcg.Coord(10, 20)
    legacy = value_type(context, dcg.MouseButton.LEFT, delta, click)
    explicit = value_type(context, dcg.MouseButton.LEFT, delta, click, dcg.Coord(40, 50))
    assert tuple(legacy.mouse_position) == (12, 23)
    assert tuple(explicit.mouse_position) == (40, 50)
    assert tuple(explicit.drag_delta) == (2, 3)
    with pytest.raises(TypeError, match="mouse_position"):
        value_type(context, dcg.MouseButton.LEFT, delta, click, (40, 50))
