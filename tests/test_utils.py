"""This test file is meant to test modules provided in dearcygui.utils (except asyncio)"""

import asyncio
import gc
from collections.abc import Generator
from datetime import datetime
from types import SimpleNamespace

import dearcygui as dcg
import pytest

from dearcygui.utils.handler import (
    add_callbacks_to_handler,
    async_generator_from_handlers,
    auto_cleanup_handler,
    future_from_handlers,
    generator_from_handlers,
)
from dearcygui.utils.widget import DatePicker, DateTimePicker, TimePicker


@pytest.fixture
def ctx() -> Generator[dcg.Context, None, None]:
    """Create and clean up a DearCyGui context."""
    context = dcg.Context()
    yield context
    context.queue.shutdown(wait=True)
    context.viewport.destroy()
    gc.collect()


# handler.py



def test_add_callbacks_to_handler_preserves_and_chains_callbacks(
    ctx: dcg.Context,
) -> None:
    """Run the existing callback before all newly-added callbacks."""
    handler = dcg.ClickedHandler(ctx)
    target = dcg.Button(ctx)
    calls: list[tuple[str, object, object, object]] = []
    handler.callback = lambda sender, item, data: calls.append(
        ("existing", sender, item, data)
    )
    add_callbacks_to_handler(
        handler,
        lambda sender, item, data: calls.append(("first", sender, item, data)),
        lambda sender, item, data: calls.append(("second", sender, item, data)),
    )

    handler.callback(handler, target, "payload")

    assert calls == [
        ("existing", handler, target, "payload"),
        ("first", handler, target, "payload"),
        ("second", handler, target, "payload"),
    ]


def test_auto_cleanup_handler_removes_triggered_handler_and_keeps_callback(
    ctx: dcg.Context,
) -> None:
    """Remove a triggered handler after its previous callback runs."""
    handler = dcg.ClickedHandler(ctx)
    target = dcg.Button(ctx)
    calls: list[tuple[object, object, object]] = []
    handler.callback = lambda sender, item, data: calls.append((sender, item, data))
    target.handlers = [handler]

    auto_cleanup_handler(handler)
    handler.callback(handler, target, "payload")

    assert calls == [(handler, target, "payload")]
    assert handler not in target.handlers


def test_auto_cleanup_handler_rejects_non_handler() -> None:
    """Reject values that cannot be used as event handlers."""
    with pytest.raises(TypeError, match="handler must be"):
        auto_cleanup_handler(object())


@pytest.mark.parametrize(("cleanup", "handler_remains"), [(False, True), (True, False)])
def test_future_from_handlers_resolves_once_and_cleans_up_triggered_handler(
    ctx: dcg.Context,
    cleanup: bool,
    handler_remains: bool,
) -> None:
    """Resolve with the first event and honor the cleanup option."""
    first_handler = dcg.ClickedHandler(ctx)
    second_handler = dcg.ClickedHandler(ctx)
    first_target = dcg.Button(ctx)
    second_target = dcg.Button(ctx)
    first_target.handlers = [first_handler]
    second_target.handlers = [second_handler]

    future = future_from_handlers(first_handler, second_handler, cleanup=cleanup)
    first_handler.callback(first_handler, first_target, "first")

    assert future.result() == (first_handler, first_target, "first")
    assert future.done()
    assert (first_handler in first_target.handlers) is handler_remains
    assert second_handler in second_target.handlers


def test_generator_from_handlers_yields_each_callback_event(
    ctx: dcg.Context,
) -> None:
    """Yield every queued event with its handler, target, and data."""
    handler = dcg.ClickedHandler(ctx)
    target = dcg.Button(ctx)
    events = generator_from_handlers(handler)

    handler.callback(handler, target, "first")
    handler.callback(handler, target, "second")

    assert next(events) == (handler, target, "first")
    assert next(events) == (handler, target, "second")
    events.close()


def test_async_generator_from_handlers_yields_callback_event(
    ctx: dcg.Context,
) -> None:
    """Yield callback events through the current asyncio event loop."""
    handler = dcg.ClickedHandler(ctx)
    target = dcg.Button(ctx)

    async def receive_event() -> tuple[dcg.baseHandler, dcg.baseItem, str]:
        events = async_generator_from_handlers(handler)
        next_event = asyncio.create_task(events.__anext__())
        await asyncio.sleep(0)
        handler.callback(handler, target, "payload")
        event = await next_event
        await events.aclose()
        return event

    assert asyncio.run(receive_event()) == (handler, target, "payload")


def test_handler_event_adapters_reject_missing_or_invalid_handlers() -> None:
    """Require at least one valid handler for synchronous adapters."""
    with pytest.raises(ValueError, match="At least one handler"):
        future_from_handlers()
    with pytest.raises(ValueError, match="At least one handler"):
        generator_from_handlers()
    with pytest.raises(TypeError, match="All handlers"):
        future_from_handlers(object())
    with pytest.raises(TypeError, match="All handlers"):
        generator_from_handlers(object())

    async def reject_invalid_async_handlers() -> None:
        with pytest.raises(ValueError, match="At least one handler"):
            await async_generator_from_handlers().__anext__()
        with pytest.raises(TypeError, match="All handlers"):
            await async_generator_from_handlers(object()).__anext__()

    asyncio.run(reject_invalid_async_handlers())



# widgets.py

def test_datetime_picker_initial_value_syncs_components(ctx: dcg.Context) -> None:
    """Initialize date and time components from one datetime."""
    value = datetime(2024, 3, 10, 15, 42, 17)
    picker = DateTimePicker(ctx, value=value)

    assert picker.value_as_datetime == value
    assert picker.date_picker.value_as_datetime == value
    assert picker.time_picker.value == 15 * 3600 + 42 * 60 + 17


def test_datetime_picker_value_updates_component_values(ctx: dcg.Context) -> None:
    """Update embedded picker values through the composite value setter."""
    picker = DateTimePicker(ctx, value=datetime(2024, 3, 10, 15, 42, 17))
    value = datetime(2025, 6, 12, 9, 8, 7)

    picker.value = value

    assert picker.value_as_datetime == value
    assert picker.date_picker.value_as_datetime == value
    assert picker.time_picker.value == 9 * 3600 + 8 * 60 + 7


def test_time_picker_refreshes_ampm_after_24_hour_edit(ctx: dcg.Context) -> None:
    """Keep the hidden meridiem control synchronized with 24-hour edits."""
    picker = TimePicker(ctx, value=datetime(2024, 3, 10, 15, 42, 17))
    picker.use_24hr = True
    picker._on_hour_change(None, None, SimpleNamespace(value=9))

    picker.use_24hr = False

    assert picker.value_as_datetime.hour == 9
    assert picker._am_pm.value == "AM"
    assert picker._hours.min_value == 1


def test_date_picker_uses_sunday_first_calendar_columns(ctx: dcg.Context) -> None:
    """Place a Sunday-first month's first day in the first calendar column."""
    picker = DatePicker(ctx, value=datetime(2024, 9, 1))
    table = picker._grid.children[0]

    assert table.children[7].label == "1"


def test_date_picker_navigation_stops_at_datetime_limits(ctx: dcg.Context) -> None:
    """Prevent navigation beyond Python's supported date endpoints."""
    picker = DatePicker(
        ctx,
        value=datetime(9999, 12, 31),
        max_date=datetime(9999, 12, 31),
    )

    picker._on_next_click()
    assert (picker._current_year, picker._current_month) == (9999, 11)

    picker._view_level = 2
    picker._on_next_click()
    assert picker._current_year_block == 9980


def test_date_picker_value_setter_accepts_timestamp(ctx: dcg.Context) -> None:
    """Set a date picker from a Unix timestamp."""
    picker = DatePicker(ctx, value=datetime(2024, 3, 10))
    value = datetime(2025, 6, 12, 13, 14, 15)

    picker.value = value.timestamp()

    assert picker.value_as_datetime == value
