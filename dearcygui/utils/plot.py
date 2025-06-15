import datetime
import dearcygui as dcg
from collections.abc import Sized

class PlotCandleStick(dcg.DrawInPlot):
    """
    Adds a candle series to a plot.

    See the source code for how to make
    a custom version with more interactions.

    Args:
        dates (np.ndarray): x-axis values
        opens (np.ndarray): open values
        closes (np.ndarray): close values 
        lows (np.ndarray): low values
        highs (np.ndarray): high values
        bull_color (color, optional): color of the candlestick when the close is lower than the open
        bear_color (color, optional): color of the candlestick when the close is higher than the open
        weight (float, optional): Candle width as a percentage of the distance between two dates
        tooltip (bool, optional): whether to show a tooltip on hover
        time_formatter (callback, optional): callback that takes a date and returns a string
    """
    def __init__(self,
                 context : dcg.Context,
                 no_legend=False,
                 dates: Sized = [],
                 opens: Sized = [],
                 closes: Sized = [],
                 lows: Sized = [],
                 highs: Sized = [],
                 bull_color=(0, 255, 113, 255),
                 bear_color=(218, 13, 79, 255),
                 weight=0.25,
                 tooltip=True,
                 time_formatter=None,
                 **kwargs) -> None:
        super().__init__(context, **kwargs)
        # For DrawInPlot, default no_legend is True
        # Thus the override.
        self.no_legend = no_legend
        if len(dates) != len(opens) or len(dates) != len(closes) or len(dates) != len(lows) or len(dates) != len(highs):
            raise ValueError("dates, opens, closes, lows, highs must be of same length")
        # Same to local variables
        self._dates = dates
        self._opens = opens
        self._closes = closes
        self._lows = lows
        self._highs = highs

        self._bull_color = dcg.color_as_int(bull_color)
        self._bear_color = dcg.color_as_int(bear_color)
        self._weight = float(weight)
        self._tooltip = tooltip

        self._time_formatter = time_formatter
        if time_formatter is None:
            # use datetime:
            self._time_formatter = lambda x: datetime.datetime.fromtimestamp(x).strftime('%Y-%m-%d %H:%M:%S')

        self.render()


    def render(self) -> None:
        count = self._dates.shape[0]
        width_percent = self._weight
        half_width = ((self._dates[1] - self._dates[0]) * width_percent) if count > 1 else width_percent
        self.children = []
        buttons = []
        with self:
            for i in range(count):
                open_pos = (self._dates[i] - half_width, self._opens[i])
                close_pos = (self._dates[i] + half_width, self._closes[i])
                low_pos = (self._dates[i], self._lows[i])
                high_pos = (self._dates[i], self._highs[i])
                color = self._bear_color if self._opens[i] > self._closes[i] else self._bull_color
                dcg.DrawLine(self.context, p1=low_pos, p2=high_pos, color=color, thickness=0.2*half_width)
                dcg.DrawRect(self.context, pmin=open_pos, pmax=close_pos, color=0, fill=color)
                buttons.append(
                    dcg.DrawInvisibleButton(self.context, button=0,
                                            p1=(open_pos[0], low_pos[1]),
                                            p2=(close_pos[0], high_pos[1]),
                                            user_data=(self._dates[i], self._opens[i],
                                                       self._closes[i], self._lows[i],
                                                       self._highs[i]))
                )
        tooltip_handler = dcg.GotHoverHandler(self.context, callback=self._tooltip_handler)
        # Here add your handlers to the buttons to react to clicks, etc
        for button in buttons:
            button.handlers = [tooltip_handler]

    def _tooltip_handler(self, sender, target):
        data = target.user_data
        if self._tooltip:
            with dcg.utils.TemporaryTooltip(self.context, target=target,
                                            parent=self.parent.parent):
                dcg.Text(self.context, value=f"Date: {self._time_formatter(data[0])}")
                dcg.Text(self.context, value=f"Open: {data[1]}")
                dcg.Text(self.context, value=f"Close: {data[2]}")
                dcg.Text(self.context, value=f"Low: {data[3]}")
                dcg.Text(self.context, value=f"High: {data[4]}")