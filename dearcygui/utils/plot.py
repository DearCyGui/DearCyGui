"""Plot helpers: candlestick series built from draw items."""

from collections.abc import Callable, Sequence
from dataclasses import dataclass, field
import datetime
from typing import Final

import dearcygui as dcg

_DEFAULT_BULL_COLOR: Final[tuple[int, int, int, int]] = (0, 255, 113, 255)
_DEFAULT_BEAR_COLOR: Final[tuple[int, int, int, int]] = (218, 13, 79, 255)


def _default_time_formatter(timestamp: float) -> str:
    """Format a unix timestamp as a local date and time string."""
    return datetime.datetime.fromtimestamp(timestamp).strftime("%Y-%m-%d %H:%M:%S")


@dataclass(frozen=True, kw_only=True)
class CandleData:
    """Immutable OHLC data for a candlestick series.

    Args:
        dates: x-axis values (np.ndarray expected).
        opens: open values.
        closes: close values.
        lows: low values.
        highs: high values.

    Raises:
        ValueError: If the sequences do not all have the same length.
    """

    dates: Sequence[float] = ()
    opens: Sequence[float] = ()
    closes: Sequence[float] = ()
    lows: Sequence[float] = ()
    highs: Sequence[float] = ()

    def __post_init__(self) -> None:
        """Validate that all series have the same length."""
        size = len(self.dates)
        if any(len(s) != size for s in (self.opens, self.closes, self.lows, self.highs)):
            raise ValueError("dates, opens, closes, lows, highs must be of same length")


@dataclass(frozen=True, kw_only=True)
class CandleStyle:
    """Immutable appearance and behaviour settings of a candlestick series.

    Args:
        bull_color: Color of the candle when the close is higher than the open.
        bear_color: Color of the candle when the close is lower than the open.
        weight: Candle width as a fraction of the distance between two dates.
        tooltip: Whether to show a tooltip on hover.
        time_formatter: Callback converting a date to a string.
    """

    bull_color: dcg.Color = _DEFAULT_BULL_COLOR
    bear_color: dcg.Color = _DEFAULT_BEAR_COLOR
    weight: float = 0.25
    tooltip: bool = True
    time_formatter: Callable[[float], str] = field(default=_default_time_formatter)


class PlotCandleStick(dcg.DrawInPlot):
    """Add a candle series to a plot.

    See the source code for how to make a custom version with more interactions.

    This class is not thread-safe.

    Args:
        context: The DearCyGui context.
        data: OHLC data to display.
        style: Appearance settings. Defaults to CandleStyle().
        no_legend: Hide the item from the legend (DrawInPlot defaults to True,
            hence the override).
    """

    __slots__ = {
        "_bear_color": "Packed color used when open > close",
        "_bull_color": "Packed color used when open <= close",
        "_data": "OHLC data displayed",
        "_time_formatter": "Callback converting a date to a string",
        "_tooltip": "Whether hovering a candle shows a tooltip",
        "_weight": "Candle width as a fraction of the date spacing",
    }

    _bear_color: int
    _bull_color: int
    _data: CandleData
    _time_formatter: Callable[[float], str]
    _tooltip: bool
    _weight: float

    def __init__(
        self,
        context: dcg.Context,
        data: CandleData | None = None,
        style: CandleStyle | None = None,
        *,
        no_legend: bool = False,
        **kwargs,
    ) -> None:
        """Initialize the series and build its draw items."""
        super().__init__(context, **kwargs)

        # Resolve defaults
        data = CandleData() if data is None else data
        style = CandleStyle() if style is None else style

        # DrawInPlot defaults no_legend to True, so override it
        self.no_legend = no_legend

        # Store state
        self._data = data
        self._bull_color = dcg.color_as_int(style.bull_color)
        self._bear_color = dcg.color_as_int(style.bear_color)
        self._weight = float(style.weight)
        self._tooltip = style.tooltip
        self._time_formatter = style.time_formatter

        self.render()

    def render(self) -> None:
        """Rebuild the draw items (candles and invisible hover buttons)."""
        data = self._data
        count = len(data.dates)

        # Compute candle half width
        if count > 1:
            half_width = (data.dates[1] - data.dates[0]) * self._weight
        else:
            half_width = self._weight

        # Rebuild children
        self.children = []
        buttons: list[dcg.DrawInvisibleButton] = []
        with self:
            for i in range(count):
                date = data.dates[i]
                open_pos = (date - half_width, data.opens[i])
                close_pos = (date + half_width, data.closes[i])
                low_pos = (date, data.lows[i])
                high_pos = (date, data.highs[i])
                bearish = data.opens[i] > data.closes[i]
                color = self._bear_color if bearish else self._bull_color
                dcg.DrawLine(self.context, p1=low_pos, p2=high_pos, color=color,
                             thickness=0.2 * half_width)
                dcg.DrawRect(self.context, pmin=open_pos, pmax=close_pos, color=0, fill=color)
                buttons.append(
                    dcg.DrawInvisibleButton(
                        self.context,
                        button=dcg.MouseButtonMask.LEFT,
                        p1=(open_pos[0], low_pos[1]),
                        p2=(close_pos[0], high_pos[1]),
                        user_data=(date, data.opens[i], data.closes[i],
                                   data.lows[i], data.highs[i]),
                    )
                )

        # Attach the shared hover handler; add more handlers here for clicks, etc.
        tooltip_handler = dcg.GotHoverHandler(self.context, callback=self._tooltip_handler)
        for button in buttons:
            button.handlers = [tooltip_handler]

    def _tooltip_handler(self, sender: dcg.baseItem, target: dcg.DrawInvisibleButton) -> None:
        """Show a tooltip describing the hovered candle."""
        if not self._tooltip:
            return

        # Retrieve the parent to which the tooltip should be attached
        plot = self.parent
        if plot is None:
            return
        plot_parent = plot.parent
        if plot_parent is None:
            return

        # Build the tooltip content
        date, open_, close, low, high = target.user_data
        with dcg.utils.TemporaryTooltip(self.context, target=target, parent=plot_parent):
            dcg.Text(self.context, value=f"Date: {self._time_formatter(date)}")
            dcg.Text(self.context, value=f"Open: {open_}")
            dcg.Text(self.context, value=f"Close: {close}")
            dcg.Text(self.context, value=f"Low: {low}")
            dcg.Text(self.context, value=f"High: {high}")