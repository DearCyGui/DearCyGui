import colorsys
import dearcygui as dcg
from datetime import datetime
import typing

class TemporaryTooltip(dcg.Tooltip):
    """
    A tooltip that removes itself when its showing condition is no longer met.
    
    This tooltip variant monitors its visibility condition and automatically
    deletes itself from the widget hierarchy when the condition becomes false.
    The tooltip uses a LostRenderHandler to detect when it should be removed.
    """
    def __init__(self,
                 context : dcg.Context,
                 **kwargs) -> None:
        super().__init__(context, **kwargs)
        self.handlers += [
            dcg.LostRenderHandler(context,
                                  callback=self.destroy_tooltip)]

    def destroy_tooltip(self) -> None:
        """
        Remove this tooltip from the widget tree.
        
        This method is called automatically when the tooltip's condition is
        no longer met. It safely deletes the tooltip item from the hierarchy.
        """
        if self.context is None:
            return # Already deleted
        # self.parent = None would work too but would wait GC.
        self.delete_item()

class TimePicker(dcg.Layout):
    """
    A widget for picking time values, similar to ImPlot's time picker.
    
    The widget displays hour/minute/second spinners and AM/PM selection.
    It uses seconds internally via SharedFloat but provides a datetime 
    interface for convenient time manipulation.
    
    The picker can be configured to use 12-hour or 24-hour time formats,
    and seconds display can be optionally hidden for a simpler interface.
    """
    def __init__(self, context, *, value=None, use_24hr=False, show_seconds=True, **kwargs) -> None:
        super().__init__(context, **kwargs)

        # Default to current time if no value provided
        if value is None:
            value = datetime.now()
        if isinstance(value, datetime):
            total_seconds = value.hour * 3600 + value.minute * 60 + value.second
        else:
            total_seconds = float(value)
            
        self._value = dcg.SharedFloat(context, total_seconds)
        self._use_24hr = use_24hr
        self._show_seconds = show_seconds

        # Apply consistent styling
        self.border = True
        self.no_scrollbar = True
        self.no_scroll_with_mouse = True
        with dcg.ThemeList(self.context) as self.theme:
            self._container_style = dcg.ThemeStyleImGui(self.context, 
                                frame_rounding=4.0,
                                child_rounding=4.0,
                                frame_padding=(6, 3),
                                item_spacing=(4, 4))
            self._container_colors = dcg.ThemeColorImGui(self.context)
        self._input_colors = dcg.ThemeColorImGui(context)
        self._separator_colors = dcg.ThemeColorImGui(context)
        self._ampm_colors = dcg.ThemeColorImGui(context)

        self.handlers += [
            dcg.GotRenderHandler(context, callback=self._update_theme_style)
        ]


        with dcg.HorizontalLayout(context, parent=self):
            # Hours spinner
            self._hours = dcg.InputValue(context, print_format="%.0f", 
                                  min_value=0,
                                  max_value=23 if use_24hr else 12,
                                  value=self._get_display_hour(),
                                  width=100, step=1, step_fast=5,
                                  callback=self._on_hour_change)
            self._hours.theme = self._input_colors

            # Minutes spinner 
            dcg.Text(context, value=":", width=10, theme = self._separator_colors)
            self._minutes = dcg.InputValue(context, print_format="%.0f",
                                    min_value=0, max_value=59,
                                    value=int((total_seconds % 3600) // 60),
                                    width=100, step=1, step_fast=5,
                                    callback=self._on_minute_change)
            self._minutes.theme = self._input_colors
            
            # Optional seconds spinner
            if show_seconds:
                dcg.Text(context, value=":", width=10, theme = self._separator_colors)
                self._seconds = dcg.InputValue(context, print_format="%.0f",
                                        min_value=0, max_value=59, 
                                        value=int(total_seconds % 60),
                                        width=100, step=1, step_fast=5,
                                        callback=self._on_second_change)
                self._seconds.theme = self._input_colors
            
            # AM/PM selector for 12-hour format
            if not use_24hr:
                dcg.Text(context, value=" ", width=10)
                self._am_pm = dcg.RadioButton(context,
                                        items=["AM", "PM"],
                                        value="PM" if (total_seconds // 3600) >= 12 else "AM",
                                        horizontal=True,
                                        callback=self._on_ampm_change)
                self._am_pm.theme = self._ampm_colors

    def _update_theme_style(self) -> None:
        """Update all theme objects based on current theme settings"""
        # Get base colors from current theme
        parent = self.parent
        assert parent is not None
        text_color = typing.cast(int, dcg.resolve_theme(parent, dcg.ThemeColorImGui, "text"))
        frame_bg = typing.cast(int, dcg.resolve_theme(parent, dcg.ThemeColorImGui, "frame_bg"))
        frame_bg_hovered = typing.cast(int, dcg.resolve_theme(parent, dcg.ThemeColorImGui, "frame_bg_hovered"))
        frame_bg_active = typing.cast(int, dcg.resolve_theme(parent, dcg.ThemeColorImGui, "frame_bg_active"))
        child_bg = typing.cast(int, dcg.resolve_theme(parent, dcg.ThemeColorImGui, "child_bg"))

        # Get accent color for highlights
        accent_color = dcg.resolve_theme(parent, dcg.ThemeColorImGui, "check_mark")
        accent_color = dcg.color_as_floats(accent_color)
        if sum(accent_color[:3]) < 0.1:  # Fallback if too dark
            accent_color = (0.4, 0.5, 0.8, 0.7)
            
        # Update container theme
        self._container_colors.text = text_color
        self._container_colors.child_bg = child_bg
        
        # Update input field colors
        self._input_colors.text = text_color
        self._input_colors.frame_bg = frame_bg
        self._input_colors.frame_bg_hovered = frame_bg_hovered
        self._input_colors.frame_bg_active = frame_bg_active
        text_color = dcg.color_as_floats(text_color)
        frame_bg = dcg.color_as_floats(frame_bg)
        frame_bg_hovered = dcg.color_as_floats(frame_bg_hovered)
        frame_bg_active = dcg.color_as_floats(frame_bg_active)
        
        # Update separator color - make it slightly accent-colored
        self._separator_colors.text = tuple(0.3 * text_color[i] + 0.7 * accent_color[i] 
                                           for i in range(3)) + (text_color[3],)
        
        # Update AM/PM selector theme
        self._ampm_colors.frame_bg = tuple(c * 0.95 for c in frame_bg[:3]) + (frame_bg[3],)
        self._ampm_colors.frame_bg_hovered = tuple(min(1.0, c * 1.05) for c in frame_bg_hovered[:3]) + (frame_bg_hovered[3],)
        self._ampm_colors.frame_bg_active = tuple(c * 0.9 for c in frame_bg_active[:3]) + (frame_bg_active[3],)
        self._ampm_colors.text = text_color

    def _get_display_hour(self) -> int:
        """
        Convert internal seconds to display hour format.
        
        Handles the conversion between 24-hour and 12-hour formats,
        ensuring proper display in the selected time format.
        """
        hour = int(self._value.value // 3600)
        if not self._use_24hr:
            hour = hour % 12
            if hour == 0:
                hour = 12
        return hour

    def _get_total_seconds(self, hour: int, minute: int, second: int | None = None) -> int:
        """
        Convert hours, minutes, and seconds to total seconds.
        
        If seconds are not provided, the current seconds value is used.
        """
        if second is None:
            second = int(self._value.value % 60)
        return hour * 3600 + minute * 60 + second
        
    def _on_hour_change(self, sender, target, value) -> None:
        """
        Handle hour input changes.
        
        Converts 12-hour format to internal 24-hour representation
        if necessary and updates the internal time value.
        """
        hour = int(value)
        if not self._use_24hr:
            is_pm = self._am_pm.value == "PM"
            if hour == 12:
                hour = 0 if not is_pm else 12
            elif is_pm:
                hour += 12
        
        minute = int((self._value.value % 3600) // 60)
        self._value.value = self._get_total_seconds(hour, minute)
        self.run_callbacks()

    def _on_minute_change(self, sender, target, value) -> None: 
        """
        Handle minute input changes.
        
        Updates the internal time value while preserving hours and seconds.
        """
        hour = int(self._value.value // 3600)
        self._value.value = self._get_total_seconds(hour, int(value))
        self.run_callbacks()

    def _on_second_change(self, sender, target, value) -> None:
        """
        Handle second input changes.
        
        Updates the internal time value while preserving hours and minutes.
        """
        if self._show_seconds:
            hour = int(self._value.value // 3600)
            minute = int((self._value.value % 3600) // 60)
            self._value.value = self._get_total_seconds(hour, minute, int(value))
            self.run_callbacks()

    def _on_ampm_change(self, sender, target, value) -> None:
        """
        Handle AM/PM selection changes.
        
        Adjusts the internal 24-hour representation based on AM/PM selection.
        """
        if not self._use_24hr:
            hour = int(self._value.value // 3600)
            cur_is_pm = hour >= 12
            new_is_pm = value == "PM"
            
            if cur_is_pm != new_is_pm:
                hour = (hour + 12) % 24
                minute = int((self._value.value % 3600) // 60)
                self._value.value = self._get_total_seconds(hour, minute)
                self.run_callbacks()

    def run_callbacks(self) -> None:
        """
        Execute all registered callbacks with the current time value.
        
        Passes the current time as a datetime object to all callbacks.
        """
        for callback in self.callbacks:
            callback(self, self, self.value_as_datetime)

    @property
    def value(self) -> float:
        """
        Current time value represented as seconds since midnight.
        
        This is the raw internal representation that can be used for 
        calculations or for sharing the time value between components.
        """
        return self._value.value

    @value.setter 
    def value(self, value: float | datetime) -> None:
        """Set current time in seconds"""
        if isinstance(value, datetime):
            value = value.hour * 3600 + value.minute * 60 + value.second
        self._value.value = float(value)
        
        # Update UI controls
        self._hours.value = self._get_display_hour()
        self._minutes.value = int((self._value.value % 3600) // 60)
        if self._show_seconds:
            self._seconds.value = int(self._value.value % 60)
        if not self._use_24hr:
            self._am_pm.value = "PM" if (self._value.value // 3600) >= 12 else "AM"

    @property
    def value_as_datetime(self) -> datetime:
        """
        Current time as a datetime object.
        
        Returns a datetime object representing the currently selected time,
        using today's date with the selected time components.
        """
        total_secs = int(self._value.value)
        hours = total_secs // 3600
        minutes = (total_secs % 3600) // 60
        seconds = total_secs % 60
        return datetime.now().replace(hour=hours, minute=minutes, second=seconds)

    @value_as_datetime.setter
    def value_as_datetime(self, value) -> None:
        """Set current time from datetime"""
        if not isinstance(value, datetime):
            raise ValueError("Value must be a datetime object")
        self.value = value

    @property
    def use_24hr(self) -> bool:
        """
        Whether the time picker uses 24-hour format.
        
        When true, hours range from 0-23 and no AM/PM indicator is shown.
        When false, hours range from 1-12 and an AM/PM selector is displayed.
        """
        return self._use_24hr

    @use_24hr.setter
    def use_24hr(self, value: bool) -> None:
        """Set whether to use 24 hour format"""
        if value != self._use_24hr:
            self._use_24hr = value
            # Update hour display & limits
            self._hours.max_value = 23 if value else 12
            self._hours.value = self._get_display_hour()
            # Show/hide AM/PM
            if hasattr(self, '_am_pm'):
                self._am_pm.show = not value

    @property 
    def show_seconds(self) -> bool:
        """
        Whether seconds are shown in the time picker.
        
        When true, hours, minutes, and seconds are displayed.
        When false, only hours and minutes are shown.
        """
        return self._show_seconds

    @show_seconds.setter
    def show_seconds(self, value: bool) -> None:
        """Set whether to show seconds"""
        if value != self._show_seconds:
            self._show_seconds = value
            if hasattr(self, '_seconds'):
                self._seconds.show = value

class DatePicker(dcg.ChildWindow):
    """
    A widget for picking dates.
    
    The widget displays a calendar interface with month/year navigation and allows
    selecting dates within the valid range. Users can navigate between day, month, 
    and year views using the header button. The calendar supports date ranges 
    from 1970 to 2999 by default, which can be customized with min_date and 
    max_date parameters.
    """
    
    MONTH_NAMES = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    
    MONTH_ABBREV = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ]
    
    WEEKDAY_ABBREV = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    def __init__(self, context, *, value=None, min_date=None, max_date=None, **kwargs):
        super().__init__(context, **kwargs)
        
        self._value = dcg.SharedFloat(context, 0)
        self._view_level = 0  # 0=days, 1=months, 2=years
        
        # Set default value to current date if none provided
        if value is None:
            value = datetime.now()
        if not isinstance(value, datetime):
            raise ValueError("Value must be a datetime object")
            
        # Set min/max dates
        self._min_date = datetime(1970, 1, 1) if min_date is None else min_date
        self._max_date = datetime(2999, 12, 31) if max_date is None else max_date
        
        # Initial setup
        self._value.value = value.timestamp()
        self._current_month = value.month - 1
        self._current_year = value.year
        self._current_year_block = value.year - (value.year % 20)

        # Styling
        self.border = True
        self.auto_resize_y = True
        self.no_scrollbar = True
        self.no_scroll_with_mouse = True
        self._container_style = \
            dcg.ThemeStyleImGui(context, 
                                frame_rounding=4.0,
                                frame_padding=(6, 3),
                                child_rounding=4.0,
                                item_spacing=(8, 4))
        self._container_colors = dcg.ThemeColorImGui(context)
        self.theme = dcg.ThemeList(context)
        self._container_style.parent = self.theme
        self._container_colors.parent = self.theme
        
        # Nav buttons theme
        self._nav_button_colors = dcg.ThemeColorImGui(context)
        
        # Header button theme
        self._header_button_colors = dcg.ThemeColorImGui(context)
        
        # Weekday header theme
        self._weekday_header_colors = dcg.ThemeColorImGui(context)
        
        # Day button themes
        self._day_button_colors = dcg.ThemeColorImGui(context)
        self._selected_day_colors = dcg.ThemeColorImGui(context)
        self._today_day_colors = dcg.ThemeColorImGui(context)
        self._disabled_day_colors = dcg.ThemeColorImGui(context)

        # Add handler to update themes when rendered
        self.handlers += [
            dcg.GotRenderHandler(context, callback=self._update_theme_style)
        ]

        with self:
            # Header row with navigation
            with dcg.HorizontalLayout(context):
                # Left button - styling for a cleaner arrow
                self._left_btn = dcg.Button(context, label="<", width=30,
                                          callback=self._on_prev_click)
                self._left_btn.theme = self._nav_button_colors
                
                # Center label/button with more professional styling
                self._header_btn = dcg.Button(context, 
                                            label=self._get_header_text(),
                                            callback=self._on_header_click)
                self._header_btn.theme = self._header_button_colors
                
                # Right button
                self._right_btn = dcg.Button(context, label=">", width=30,
                                           callback=self._on_next_click)
                self._right_btn.theme = self._nav_button_colors
            
            # Calendar grid
            self._grid = dcg.Layout(context)
            self._update_grid()

    def _update_theme_style(self) -> None:
        """Update all theme objects based on current theme settings"""
        # Get base colors from current theme
        parent = self.parent
        assert parent is not None
        text_color = typing.cast(int, dcg.resolve_theme(parent, dcg.ThemeColorImGui, "text"))
        button_color = typing.cast(int, dcg.resolve_theme(parent, dcg.ThemeColorImGui, "button"))
        button_hovered = typing.cast(int, dcg.resolve_theme(parent, dcg.ThemeColorImGui, "button_hovered"))
        button_active = typing.cast(int, dcg.resolve_theme(parent, dcg.ThemeColorImGui, "button_active"))
        child_bg = typing.cast(int, dcg.resolve_theme(parent, dcg.ThemeColorImGui, "child_bg"))
        border_color = typing.cast(int, dcg.resolve_theme(parent, dcg.ThemeColorImGui, "border"))

        # Here we follow closely the current theme style, but
        # you can adapt to your needs.
        
        # Get accent color for highlights
        accent_color = dcg.resolve_theme(parent, dcg.ThemeColorImGui, "check_mark")
        accent_color = dcg.color_as_floats(accent_color)
        if sum(accent_color[:3]) < 0.1:  # Fallback if too dark or not found
            accent_color = (0.4, 0.5, 0.8, 0.7)
        
        # Calculate complementary color for today highlight
        h, s, v = colorsys.rgb_to_hsv(*accent_color[:3])
        h = (h + 0.5) % 1.0  # Complementary hue
        today_color = colorsys.hsv_to_rgb(h, s * 0.8, v)
        today_color = today_color[:3] + (0.7,)

        text_color = dcg.color_as_floats(text_color)
        
        # Update container theme
        self._container_colors.text = text_color
        self._container_colors.button = button_color
        self._container_colors.child_bg = child_bg
        self._container_colors.border = border_color
        
        # Update navigation button themes
        self._nav_button_colors.button = button_color
        self._nav_button_colors.button_hovered = button_hovered
        self._nav_button_colors.button_active = button_active
        self._nav_button_colors.text = text_color
        
        # Update header button theme (slightly lighter than normal buttons)
        button_color = dcg.color_as_floats(button_color)
        header_bg = tuple(min(1.0, c * 1.1) for c in button_color[:3]) + (button_color[3],)
        self._header_button_colors.button = header_bg
        self._header_button_colors.button_hovered = tuple(min(1.0, c * 1.05) for c in header_bg[:3]) + (header_bg[3],)
        self._header_button_colors.button_active = tuple(max(0.0, c * 0.95) for c in header_bg[:3]) + (header_bg[3],)
        self._header_button_colors.text = accent_color[:3] + (1.0,)  # Use accent color for header text
        
        # Update weekday header theme
        self._weekday_header_colors.text = tuple(0.6 * c + 0.4 * accent_color[i] for i, c in enumerate(text_color[:3])) + (text_color[3],)
        
        # Update day button themes
        self._day_button_colors.text = text_color
        self._day_button_colors.button = button_color
        self._day_button_colors.button_hovered = button_hovered
        self._day_button_colors.button_active = button_active
        
        # Selected day theme
        self._selected_day_colors.button = accent_color
        self._selected_day_colors.button_hovered = tuple(min(1.0, c * 1.2) for c in accent_color[:3]) + (min(1.0, accent_color[3] * 1.1),)
        self._selected_day_colors.button_active = tuple(min(1.0, c * 1.4) for c in accent_color[:3]) + (min(1.0, accent_color[3] * 1.2),)
        self._selected_day_colors.text = (1.0, 1.0, 1.0, 1.0)
        
        # Today theme
        self._today_day_colors.button = today_color
        self._today_day_colors.button_hovered = tuple(min(1.0, c * 1.2) for c in today_color[:3]) + (min(1.0, today_color[3] * 1.1),)
        self._today_day_colors.button_active = tuple(min(1.0, c * 1.4) for c in today_color[:3]) + (min(1.0, today_color[3] * 1.2),)
        self._today_day_colors.text = (1.0, 1.0, 1.0, 1.0)
        
        # Disabled day theme
        self._disabled_day_colors.text = text_color[:3] + (0.5,)  # Dimmed text
        
        # Update grid to apply new themes if it exists
        if hasattr(self, '_grid') and self._grid:
            self._update_grid()

    def _get_header_text(self) -> str:
        """
        Generate the header text based on current view level.
        
        Returns month and year in day view, year in month view, or year range
        in year view.
        """
        if self._view_level == 0:  # Day view
            return f"{self.MONTH_NAMES[self._current_month]} {self._current_year}"
        elif self._view_level == 1:  # Month view
            return str(self._current_year)
        else:  # Year view
            return f"{self._current_year_block}-{self._current_year_block+19}"
            
    def _update_grid(self) -> None:
        """
        Update the calendar grid based on current view level.
        
        Clears existing grid and builds a new one according to the current
        view level (days, months, or years).
        """
        self._header_btn.label = self._get_header_text()
        
        # Clear existing grid
        for child in self._grid.children[:]:
            child.delete_item()
            
        if self._view_level == 0:  # Day view
            self._build_day_grid()
        elif self._view_level == 1:  # Month view
            self._build_month_grid()
        else:  # Year view
            self._build_year_grid()
            
    def _build_day_grid(self) -> None:
        """Build the day view calendar grid."""
        # Create a table for better layout
        table = dcg.Table(self.context, parent=self._grid, 
                          flags=dcg.TableFlag.SIZING_STRETCH_SAME | 
                                dcg.TableFlag.NO_HOST_EXTEND_X,
                          header=False)
        
        # Add weekday headers with themed styling
        with table.next_row:
            for day in self.WEEKDAY_ABBREV:
                header_cell = dcg.Text(self.context, value=day)
                header_cell.theme = self._weekday_header_colors
        
        # Calculate first day of month
        first_day = datetime(self._current_year, self._current_month + 1, 1)
        days_in_month = (datetime(self._current_year + (self._current_month == 11),
                                ((self._current_month + 1) % 12) + 1, 1) -
                        datetime(self._current_year, self._current_month + 1, 1)).days
        
        # Get previous month info for padding
        if self._current_month == 0:
            prev_month_days = (datetime(self._current_year - 1, 12, 1) -
                             datetime(self._current_year - 1, 11, 1)).days
        else:
            prev_month_days = (datetime(self._current_year, self._current_month + 1, 1) -
                             datetime(self._current_year, self._current_month, 1)).days

        # Today's date for highlighting
        today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
        
        # Build calendar grid
        day = 1
        start_weekday = first_day.weekday()
        
        # Create weeks (6 rows max in a month view)
        for week in range(6):
            with table.next_row:
                for weekday in range(7):
                    if week == 0 and weekday < start_weekday:
                        # Previous month padding
                        pad_day = prev_month_days - start_weekday + weekday + 1
                        btn = dcg.Button(self.context, 
                                      label=str(pad_day), 
                                      enabled=False,
                                      width=-1)
                        # Use theme colors for disabled days
                        btn.theme = self._disabled_day_colors
                    elif day > days_in_month:
                        # Next month padding
                        next_day = day - days_in_month
                        btn = dcg.Button(self.context, 
                                      label=str(next_day), 
                                      enabled=False,
                                      width=-1)
                        # Use theme colors for disabled days
                        btn.theme = self._disabled_day_colors
                        day += 1
                    else:
                        # Current month
                        date = datetime(self._current_year, self._current_month + 1, day)
                        enabled = self._min_date <= date <= self._max_date
                        
                        btn = dcg.Button(self.context, 
                                      label=str(day),
                                      enabled=enabled,
                                      callback=self._on_day_select,
                                      width=-1)
                        
                        # Apply appropriate theme based on day state
                        is_selected = date.date() == self.value_as_datetime.date()
                        is_today = date.date() == today.date()
                        
                        if is_selected:
                            btn.theme = self._selected_day_colors
                        elif is_today:
                            btn.theme = self._today_day_colors
                        else:
                            btn.theme = self._day_button_colors
                        
                        day += 1
            
            # If we've displayed all days in this month and next month, stop
            if day > days_in_month and week >= 3:  # At least 4 rows always
                break

    def _build_month_grid(self) -> None:
        """Build the month selection grid."""
        table = dcg.Table(self.context, parent=self._grid,
                        flags=dcg.TableFlag.SIZING_STRETCH_SAME | 
                              dcg.TableFlag.NO_HOST_EXTEND_X,
                        header=False)
        
        # Get current selected month for highlighting
        selected_date = self.value_as_datetime
        
        # Build 3x4 grid of months
        month = 0
        for row in range(3):
            with table.next_row:
                for col in range(4):
                    date = datetime(self._current_year, month + 1, 1)
                    enabled = (self._min_date.year < self._current_year or 
                             (self._min_date.year == self._current_year and 
                              self._min_date.month <= month + 1))
                    enabled &= (self._max_date.year > self._current_year or
                              (self._max_date.year == self._current_year and
                               self._max_date.month >= month + 1))
                    
                    btn = dcg.Button(self.context,
                                   label=self.MONTH_ABBREV[month],
                                   enabled=enabled,
                                   callback=self._on_month_select,
                                   width=-1)
                    
                    # Apply appropriate theme
                    is_selected = (month == selected_date.month - 1 and 
                                 self._current_year == selected_date.year)
                    
                    if is_selected:
                        btn.theme = self._selected_day_colors
                    else:
                        btn.theme = self._day_button_colors
                    
                    month += 1

    def _build_year_grid(self) -> None:
        """Build the year selection grid."""
        table = dcg.Table(self.context, parent=self._grid,
                        flags=dcg.TableFlag.SIZING_STRETCH_SAME | 
                              dcg.TableFlag.NO_HOST_EXTEND_X,
                        header=False)
        
        # Current selected year for highlighting
        selected_date = self.value_as_datetime
        
        # Build 5x4 grid of years (20 years total)
        year = self._current_year_block
        for row in range(5):
            with table.next_row:
                for col in range(4):
                    if year <= 2999:
                        enabled = self._min_date.year <= year <= self._max_date.year
                        btn = dcg.Button(self.context,
                                       label=str(year),
                                       enabled=enabled,
                                       callback=self._on_year_select,
                                       width=-1)
                        
                        # Apply appropriate theme
                        is_selected = year == selected_date.year
                        if is_selected:
                            btn.theme = self._selected_day_colors
                        else:
                            btn.theme = self._day_button_colors
                    
                    year += 1
                            
    def _on_prev_click(self) -> None:
        """
        Handle previous button click.
        
        Moves to the previous month in day view, previous year in month view,
        or previous 20-year block in year view.
        """
        if self._view_level == 0:  # Day view
            if self._current_month == 0:
                self._current_month = 11
                self._current_year -= 1
            else:
                self._current_month -= 1
        elif self._view_level == 1:  # Month view
            self._current_year -= 1
        else:  # Year view
            self._current_year_block -= 20
        self._update_grid()
        
    def _on_next_click(self) -> None:
        """
        Handle next button click.
        
        Moves to the next month in day view, next year in month view,
        or next 20-year block in year view.
        """
        if self._view_level == 0:  # Day view
            if self._current_month == 11:
                self._current_month = 0
                self._current_year += 1
            else:
                self._current_month += 1
        elif self._view_level == 1:  # Month view
            self._current_year += 1
        else:  # Year view
            self._current_year_block += 20
        self._update_grid()
        
    def _on_header_click(self) -> None:
        """
        Handle header button click.
        
        Cycles through the view levels: day view -> month view -> year view -> day view.
        """
        self._view_level = (self._view_level + 1) % 3
        self._update_grid()
        
    def _on_day_select(self, sender) -> None:
        """
        Handle day selection.
        
        Sets the selected date to the chosen day and triggers callbacks.
        """
        day = int(sender.label)
        new_date = datetime(self._current_year, self._current_month + 1, day)
        self._set_value_and_run_callbacks(new_date)
        
    def _on_month_select(self, sender) -> None:
        """
        Handle month selection.
        
        Sets the current month and switches to day view.
        """
        month = self.MONTH_ABBREV.index(sender.label)
        self._current_month = month
        self._view_level = 0
        self._update_grid()
        
    def _on_year_select(self, sender) -> None:
        """
        Handle year selection.
        
        Sets the current year and switches to month view.
        """
        self._current_year = int(sender.label)
        self._view_level = 1
        self._update_grid()
        
    def _set_value_and_run_callbacks(self, value) -> None:
        """
        Set date value and trigger callbacks.
        
        Updates the internal date value and notifies all registered callbacks.
        """
        self._set_value(value)
        self.run_callbacks()

    def _set_value(self, value) -> None:
        """
        Internal method to set value without triggering callbacks.
        
        Updates the internal date value and refreshes the calendar display
        without notifying callbacks.
        """
        if not isinstance(value, datetime):
            raise ValueError("Value must be a datetime object")
        if not (self._min_date <= value <= self._max_date):
            raise ValueError("Date must be between min_date and max_date")
            
        self._value.value = value.timestamp()
        self._current_month = value.month - 1
        self._current_year = value.year
        self._current_year_block = value.year - (value.year % 20)
        self._update_grid()

    @property
    def min_date(self) -> datetime:
        """
        The minimum selectable date for the calendar.
        
        Dates before this value will be displayed as disabled in the calendar view.
        """
        return self._min_date

    @min_date.setter
    def min_date(self, value) -> None:
        """Set the minimum selectable date"""
        if not isinstance(value, datetime):
            raise ValueError("min_date must be a datetime object")
        self._min_date = value
        
        # Make sure current value is still valid
        current_date = self.value_as_datetime
        if current_date < self._min_date:
            self._value.value = self._min_date.timestamp()
        
        # Update the calendar view
        self._update_grid()

    @property
    def max_date(self) -> datetime:
        """
        The maximum selectable date for the calendar.
        
        Dates after this value will be displayed as disabled in the calendar view.
        """
        return self._max_date

    @max_date.setter
    def max_date(self, value) -> None:
        """Set the maximum selectable date"""
        if not isinstance(value, datetime):
            raise ValueError("max_date must be a datetime object")
        self._max_date = value
        
        # Make sure current value is still valid
        current_date = self.value_as_datetime
        if current_date > self._max_date:
            self._value.value = self._max_date.timestamp()
        
        # Update the calendar view
        self._update_grid()

    @property
    def value(self) -> float: # type: ignore
        """
        Current date value represented as seconds since epoch.
        
        This is the raw internal representation that can be used for calculations
        or for sharing the date value between components.
        """
        return self._value.value

    @property
    def value_as_datetime(self) -> datetime:
        """
        Current selected date as a datetime object.
        
        Provides a convenient datetime interface for date manipulation.
        """
        return datetime.fromtimestamp(self._value.value)

    def run_callbacks(self) -> None:
        """
        Execute all registered callbacks with the current date value.
        
        Passes the current date as a datetime object to all callbacks.
        """
        for callback in self.callbacks:
            callback(self, self, self.value_as_datetime)

class DateTimePicker(dcg.Layout):
    """
    A widget combining DatePicker and TimePicker for selecting both date and time.
    
    The widget displays date and time selection controls in a unified interface.
    It maintains both components synchronized through a shared timestamp value, 
    allowing complete datetime selection with a single control.
    
    Different layout modes (horizontal, vertical, compact) can be used to suit 
    various UI needs. The widget inherits the capabilities of both date and time 
    pickers, including support for date ranges, 12/24 hour formats, and optional
    seconds display.
    """

    def __init__(self, context, *, 
                 value=None,
                 min_date=None,
                 max_date=None,
                 layout="horizontal",
                 use_24hr=False,
                 show_seconds=True,
                 **kwargs) -> None:
        super().__init__(context, **kwargs)
        
        # Initialize shared value
        self._value = dcg.SharedFloat(context, 0)
        
        # Create date and time pickers
        if layout == "compact":
            with dcg.HorizontalLayout(context, parent=self):
                self._date_picker = DatePicker(context,
                                             min_date=min_date,
                                             max_date=max_date,
                                             shareable_value=self._value,
                                             callbacks=[self._on_change],
                                             width=250)
                dcg.Text(context, value=" @ ", width=20)
                self._time_picker = TimePicker(context,
                                             use_24hr=use_24hr,
                                             show_seconds=show_seconds,
                                             shareable_value=self._value,
                                             callbacks=[self._on_change],
                                             width=250)
        else:
            # Create layout container
            container = (dcg.HorizontalLayout if layout == "horizontal" 
                       else dcg.VerticalLayout)(context, parent=self)
            
            with container:
                self._date_picker = DatePicker(context,
                                             min_date=min_date,
                                             max_date=max_date, 
                                             shareable_value=self._value,
                                             callbacks=[self._on_change])

                self._time_picker = TimePicker(context,
                                             use_24hr=use_24hr,
                                             show_seconds=show_seconds,
                                             shareable_value=self._value,
                                             callbacks=[self._on_change])

        # Set initial value 
        if value is not None:
            self.value = value
        else:
            self.value = datetime.now()

    def _on_change(self, sender, target, value) -> None:
        """
        Handle date/time changes from either picker.
        
        This internal method is called when either the date or time picker component
        changes its value. It synchronizes the overall combined value and propagates
        the change by running registered callbacks.
        """
        self.run_callbacks()

    @property
    def value(self):
        """
        Current value in seconds since epoch.
        
        This is the raw internal representation of the datetime, stored as seconds
        since the Unix epoch (January 1, 1970). This format allows for easy sharing
        between components and precise time calculations.
        """
        return self._value.value
    
    @value.setter
    def value(self, value) -> None:
        self._value.value = value.timestamp() if isinstance(value, datetime) else float(value)

    @property
    def value_as_datetime(self) -> datetime:
        """
        Current value as a datetime object.
        
        This provides a convenient datetime interface for the selected date and time,
        allowing for easy integration with Python's datetime functionality.
        """
        return datetime.fromtimestamp(self._value.value)
    
    @value_as_datetime.setter
    def value_as_datetime(self, value) -> None:
        if not isinstance(value, datetime):
            raise ValueError("Value must be a datetime object")
        self.value = value

    def run_callbacks(self):
        """
        Execute all registered callbacks with the current datetime value.
        
        This method notifies all registered callbacks about changes to the selected
        datetime. The callbacks receive the current datetime as a parameter.
        """
        for callback in self.callbacks:
            callback(self, self, self.value_as_datetime)

    @property
    def use_24hr(self) -> bool:
        """
        Whether the time picker uses 24-hour format.
        
        When true, hours range from 0-23 and no AM/PM indicator is shown.
        When false, hours range from 1-12 and an AM/PM selector is displayed.
        """
        return self._time_picker.use_24hr

    @use_24hr.setter 
    def use_24hr(self, value) -> None:
        self._time_picker.use_24hr = value

    @property
    def show_seconds(self) -> bool:
        """
        Whether seconds are shown in the time picker.
        
        When true, hours, minutes, and seconds are displayed.
        When false, only hours and minutes are shown.
        """
        return self._time_picker.show_seconds
    
    @show_seconds.setter
    def show_seconds(self, value) -> None:
        self._time_picker.show_seconds = value

    @property
    def date_picker(self) -> DatePicker:
        """
        The internal DatePicker widget.
        
        Provides direct access to the embedded DatePicker component, allowing
        for customization of its specific properties and behaviors.
        """
        return self._date_picker

    @property
    def time_picker(self) -> TimePicker:
        """
        The internal TimePicker widget.
        
        Provides direct access to the embedded TimePicker component, allowing
        for customization of its specific properties and behaviors.
        """
        return self._time_picker


class DraggableBar(dcg.DrawInWindow):
    """
    A draggable bar widget that can be moved in the direction perpendicular to its orientation.
    
    The bar is only visible when hovered and can only be dragged from a specific grab region.
    Colors are automatically resolved from the current theme.
    
    Parameters:
        context: DearCyGui context
        vertical (bool): True for vertical bar, False for horizontal
        position (float): Initial position (0.0-1.0) along parent
        callback: Function to call when position changes
    """
    
    def __init__(self, context, *, vertical=True, position=0.5, 
                 callback=None, **kwargs) -> None:
        # for better dragging interactions
        kwargs["button"] = True
        # Do not include spacing for the frame
        kwargs["frame"] = False
        # We will use pixel-based positioning of the drawing
        kwargs["no_global_scaling"] = True
        kwargs["relative"] = False

        # Configure positioning based on orientation
        if vertical:
            kwargs.setdefault("width", "theme.grab_min_size + theme.separator_text_border_size")
            kwargs.setdefault("x", f"parent.x1 + {position} * parent.width")
        else:
            kwargs.setdefault("height", "theme.grab_min_size + theme.separator_text_border_size")
            kwargs.setdefault("y", f"parent.y1 + {position} * parent.height")

        super().__init__(context, **kwargs)

        # Store parameters
        self._vertical = vertical
        self._position = position
        self._dragging_in_grab = False
        self._callbacks = [callback] if callback else []

        # Create drawing list for the bar (initially hidden)
        self._drawing_list = dcg.DrawingList(context, parent=self, show=False)

        # Theme styles
        self._grab_rounding = 0.
        self._grab_radius = 0.

        # Set up handlers
        self.handlers += [
            # Handle hover state
            dcg.GotHoverHandler(context, callback=self._on_got_hover),
            dcg.LostHoverHandler(context, callback=self._on_lost_hover),
            # Check if click is in grab area
            dcg.ClickedHandler(context, callback=self._on_clicked),
            # Handle dragging
            dcg.DraggingHandler(context, callback=self._on_dragging),
            # Reset state when dragging ends
            dcg.DraggedHandler(context, callback=self._on_dragged)
        ]

        # Add conditional handler for cursor change when in grab area
        cursor = dcg.MouseCursor.RESIZE_EW if vertical else dcg.MouseCursor.RESIZE_NS

        class InGrabAreaHandler(dcg.CustomHandler):
            """Custom handler to check if mouse is in the grab area."""
            def __init__(self, context, **kwargs) -> None:
                super().__init__(context, **kwargs)

            def check_can_bind(self, item) -> bool:
                return isinstance(item, DraggableBar)

            def check_status(self, item: DraggableBar) -> bool:
                """Check if mouse is in the grab area."""
                return item._is_in_grab_area()

        with dcg.ConditionalHandler(context) as handler:
            # We use an double conditional handler to avoid
            # running InGrabAreaHandler on every frame
            with dcg.ConditionalHandler(context):
                dcg.MouseCursorHandler(context, cursor=cursor)
                InGrabAreaHandler(context)
            dcg.HoverHandler(context)
        self.handlers += [handler]
    
    @property
    def position(self) -> float:
        """Current position (0.0-1.0) of the bar along parent."""
        return self._position
    
    @position.setter
    def position(self, value) -> None:
        """Set position and update bar location."""
        # Clamp position between 0 and 1
        value = max(0.0, min(1.0, value))
        
        # Only update if changed
        if value != self._position:
            self._position = value
            
            # Update position formula
            if self._vertical:
                self.x = f"parent.x1 + {self._position} * parent.width"
            else:
                self.y = f"parent.y1 + {self._position} * parent.height"
            self.context.viewport.wake(delay=0.033) # redraw in max 30 FPS
            
            # Call any registered callbacks
            self.run_callbacks()
    
    def run_callbacks(self) -> None:
        """Execute all registered callbacks with current position."""
        for callback in self._callbacks:
            if callback:
                callback(self, self, self._position)

    def _on_got_hover(self) -> None:
        """Called when the widget is hovered."""
        # Resolve theme styles
        self._grab_rounding = typing.cast(float, dcg.resolve_theme(self, dcg.ThemeStyleImGui, "grab_rounding"))
        self._grab_radius = typing.cast(float, dcg.resolve_theme(self, dcg.ThemeStyleImGui, "grab_min_size")) / 2.0 +\
            typing.cast(float, dcg.resolve_theme(self, dcg.ThemeStyleImGui, "separator_text_border_size")) / 2.0

        # Show the bar
        self._drawing_list.show = True
        self._update_bar_appearance()
    
    def _on_lost_hover(self, sender, target) -> None:
        """Called when the widget is no longer hovered."""
        self._drawing_list.show = self._dragging_in_grab
    
    def _on_clicked(self, sender, target, button) -> None:
        """Check if click was in the grab area."""
        self._dragging_in_grab = self._is_in_grab_area()
    
    def _on_dragging(self):
        """Update position when dragging in grab area."""
        # Only update position if we started dragging in the grab area
        if not self._dragging_in_grab:
            return

        # Get parent dimensions
        parent = self.parent
        if parent is None:
            return
        assert isinstance(parent, dcg.uiItem), "DraggableBar cannot be in a plot"
        parent_size = parent.state.rect_size
        parent_width = parent_size.x
        parent_height = parent_size.y
        mouse_pos = self.context.get_mouse_position()

        # Update position based on orientation
        if self._vertical and parent_width > 0:
            new_position = (mouse_pos.x - parent.state.pos_to_viewport.x) / parent_width
        elif not self._vertical and parent_height > 0:
            new_position = (mouse_pos.y - parent.state.pos_to_viewport.y) / parent_height
        else:
            return

        # Update position (will clamp to 0-1 range)
        self.position = new_position
    
    def _on_dragged(self) -> None:
        """Reset dragging state when dragging ends."""
        self._dragging_in_grab = False
        self._drawing_list.show = self.state.hovered
    
    def _is_in_grab_area(self) -> bool:
        """Check if mouse is within the grab area of the bar."""
        if self._dragging_in_grab:
            return True
        # Get mouse position and widget bounds
        mouse_pos = self.context.get_mouse_position()
            
        widget_pos = self.state.pos_to_viewport
        widget_size = self.state.rect_size
        
        # Calculate relative mouse position within widget
        rel_x = mouse_pos[0] - widget_pos.x
        rel_y = mouse_pos[1] - widget_pos.y

        # Check if in grab area based on orientation
        if self._vertical:
            # Vertical bar: check horizontal position within grab width
            return (abs(rel_x - 0.5 * widget_size.x) < self._grab_radius and 
                    self._grab_rounding <= rel_y <= widget_size.y - self._grab_rounding)
        else:
            # Horizontal bar: check vertical position within grab height
            return (abs(rel_y - 0.5 * widget_size.y) < self._grab_radius and 
                    self._grab_rounding <= rel_x <= widget_size.x - self._grab_rounding)

    def _update_bar_appearance(self) -> None:
        """Update the visual appearance of the bar."""
        # Clear existing drawings
        self._drawing_list.children = []
        
        # Get widget size
        size = self.state.rect_size
        width = size.x
        height = size.y
        thickness = typing.cast(float, dcg.resolve_theme(self, dcg.ThemeStyleImGui, "separator_text_border_size"))
        center_x = width / 2.
        center_y = height / 2.

        # Resolve theme colors
        border_color = typing.cast(int, dcg.resolve_theme(self, dcg.ThemeColorImGui, "separator_hovered"))
        shadow_color = typing.cast(int, dcg.resolve_theme(self, dcg.ThemeColorImGui, "border_shadow"))

        # Draw based on orientation
        with self._drawing_list:
            if self._vertical:
                # Vertical bar
                # Shadow
                dcg.DrawRect(self.context, 
                             pmin=(center_x-0.5*thickness-1, 0), 
                             pmax=(center_x+0.5*thickness+1, height-1), 
                             color=0, 
                             fill=shadow_color)
                
                # Main bar
                dcg.DrawLine(self.context,
                             p1=(center_x, 0), 
                             p2=(center_x, height-1),
                             color=border_color,
                             thickness=thickness)
            else:
                # Horizontal bar
                # Shadow
                dcg.DrawRect(self.context, 
                             pmin=(0, center_y-0.5*thickness-1), 
                             pmax=(width-1, center_y+0.5*thickness+1), 
                             color=0, 
                             fill=shadow_color)

                # Main bar
                dcg.DrawLine(self.context,
                             p1=(0, center_y), 
                             p2=(width-1, center_y),
                             color=border_color,
                             thickness=thickness)
        self.context.viewport.wake(delay=0.033) # redraw in max 30 FPS


class InputValueN(dcg.ChildWindow):
    """
    A widget for entering multiple numeric values with optional step buttons.
    
    This widget combines multiple InputValue instances in a horizontal layout
    to simulate a multi-field numeric input. The number of input fields is 
    determined dynamically by the length of values passed.
    
    All InputValue properties are supported and applied to all contained fields.
    The label is only displayed on the rightmost input field.
    """
    __properties = [
            'step', 'step_fast', 'min_value', 'max_value', 'print_format',
            'decimal', 'hexadecimal', 'scientific', 'callback_on_enter',
            'escape_clears_all', 'readonly', 'password', 'always_overwrite',
            'auto_select_all', 'empty_as_zero', 'empty_if_zero',
            'no_horizontal_scroll', 'no_undo_redo'
        ]
    
    def __init__(self, context, *, values=None, shareable_values=None, **kwargs):
        # Configure visuals
        self.border = False
        self.auto_resize_y = True
        self.no_scroll_with_mouse = True
        self.no_scrollbar = True
        self.theme = dcg.ThemeColorImGui(context, child_bg=0)
        kwargs.setdefault("width", "0.65*fillx")

        # Extract InputValue-specific properties to apply later
        input_value_props = {}
        for prop in self.__properties:
            if prop in kwargs:
                input_value_props[prop] = kwargs.pop(prop)

        label = kwargs.pop('label', "")
        
        self._inputs = []
        self._callbacks = []
        self._label = dcg.Text(context, value=label, parent=self)
        self._label.show = label != ""
        self._shareable_values = None
        
        # Create reference InputValue with all properties
        self._reference_input = dcg.InputValue(
            context,
            parent=None,  # Not added to layout
            attach=False,
            label="",
            callback=self._handle_input_callback,
            **input_value_props  # Apply all InputValue-specific properties
        )
        
        # Create at least one input
        self._create_inputs(1)
        
        # Set values or shareable_values if provided
        if values is not None:
            self.values = values
        elif shareable_values is not None:
            self.shareable_values = shareable_values

        # Initialize base class
        super().__init__(context, **kwargs)
    
    def _create_inputs(self, count) -> None:
        """Create or resize to the specified number of input fields"""
        if count < 1:
            count = 1
            
        # Save current values if any
        current_values = self.values if self._inputs else [0.0]
        
        # Ensure we have enough values
        while len(current_values) < count:
            current_values.append(0.0)
            
        # Remove excess inputs if needed
        while len(self._inputs) > count:
            self._inputs[-1].delete_item()
            self._inputs.pop()
            
        # Add new inputs if needed
        while len(self._inputs) < count:
            # Copy properties from reference input
            new_input = dcg.InputValue(self.context)
            for prop in self.__properties:
                setattr(new_input, prop, getattr(self._reference_input, prop))
            new_input.callback = self._handle_input_callback
            new_input.parent = self
            new_input.no_newline = True
            self._inputs.append(new_input)
            
        # Put the label last
        self._label.parent = self

        # Update positions of all inputs
        self._update_positions()
        
        # Restore values
        for i, value in enumerate(current_values[:count]):
            self._inputs[i].value = value

    def _update_positions(self):
        """Update positions of all input fields (and the label)"""
        num_inputs = len(self._inputs)
        num_items = (1 if self._label.show else 0) + num_inputs
        field_width = f"(parent.width - {num_items - 1} * theme.item_inner_spacing.x)/{num_inputs}"
        if self._label.show:
            field_width = field_width - self._label.width / num_inputs
        x = "parent.x1"
        for i, input_field in enumerate(self._inputs):
            input_field.x = x
            input_field.width = field_width
            x = input_field.x + input_field.width + "theme.item_inner_spacing.x"
        self._label.x = x
    
    def _handle_input_callback(self, sender, target, value) -> None:
        """Handler for individual input callbacks that forwards to parent callback"""
        # Call parent callbacks with all values
        for callback in self._callbacks:
            callback(self, self, self.values)

    @property
    def callbacks(self) -> list[dcg.Callback]:
        """List of callbacks to be called when values change"""
        return self._callbacks
        
    @callbacks.setter
    def callbacks(self, value) -> None:
        """Set callbacks for value changes"""
        if value is None:
            value = []
        if not isinstance(value, (list, tuple)):
            value = [value]
        # we override the callbacks attribute to prevent
        # callback calls from the layout
        self._callbacks = [dcg.Callback(c) for c in value]
        
        # Set callbacks for each input field
        for input_field in self._inputs:
            input_field.callback = self._handle_input_callback
    
    @property
    def values(self) -> list[float]:
        """Get values from all input fields as a list"""
        return [input_field.value for input_field in self._inputs]
    
    @values.setter
    def values(self, values) -> None:
        """Set values and adjust number of input fields if needed"""
        if not isinstance(values, (list, tuple)):
            values = [values]
        
        # Resize inputs if needed
        if len(values) != len(self._inputs):
            self._create_inputs(len(values))
        
        # Set values
        for i, value in enumerate(values):
            self._inputs[i].value = value
    
    @property
    def value(self) -> list[float]:
        """Get values as a list (alias for values)"""
        return self.values
    
    @value.setter
    def value(self, value) -> None:
        """Set value(s), handling both scalar and list inputs"""
        self.values = value
    
    @property
    def shareable_values(self) -> list[dcg.SharedFloat]:
        """Get the list of SharedFloat objects used by the input fields"""
        return self._shareable_values or [input_field.shareable_value for input_field in self._inputs]
    
    @shareable_values.setter
    def shareable_values(self, values):
        """Link with external SharedFloat objects"""
        if not isinstance(values, (list, tuple)):
            values = [values]
        
        # Resize inputs if needed
        if len(values) != len(self._inputs):
            self._create_inputs(len(values))
        
        # Set shareable values
        for i, shareable_value in enumerate(values):
            self._inputs[i].shareable_value = shareable_value
        
        self._shareable_values = values
    
    @property
    def shareable_value(self) -> dcg.SharedFloat | None:
        """Get first SharedFloat object (for backward compatibility)"""
        return self.shareable_values[0] if self._inputs else None
    
    @shareable_value.setter
    def shareable_value(self, value) -> None:
        """Set a single shareable value (extends to list if needed)"""
        if isinstance(value, (list, tuple)):
            self.shareable_values = value
        else:
            self.shareable_values = [value]
    
    @property
    def label(self):
        """Get the label displayed next to the last input field"""
        return self._label.value
    
    @label.setter
    def label(self, value) -> None:
        """Set the label for the last input field"""
        self._label.value = value
            
    # Forward all InputValue properties to reference input and all active inputs
    @property
    def step(self) -> float:
        """Step size for incrementing/decrementing the values"""
        return self._reference_input.step
    
    @step.setter
    def step(self, value):
        self._reference_input.step = value
        for input_field in self._inputs:
            input_field.step = value
    
    @property
    def step_fast(self):
        """Fast step size for quick value changes with modifier keys"""
        return self._reference_input.step_fast
    
    @step_fast.setter
    def step_fast(self, value):
        self._reference_input.step_fast = value
        for input_field in self._inputs:
            input_field.step_fast = value
    
    @property
    def min_value(self):
        """Minimum value the inputs will be clamped to"""
        return self._reference_input.min_value
    
    @min_value.setter
    def min_value(self, value) -> None:
        self._reference_input.min_value = value
        for input_field in self._inputs:
            input_field.min_value = value
    
    @property
    def max_value(self) -> float:
        """Maximum value the inputs will be clamped to"""
        return self._reference_input.max_value
    
    @max_value.setter
    def max_value(self, value) -> None:
        self._reference_input.max_value = value
        for input_field in self._inputs:
            input_field.max_value = value
    
    @property
    def print_format(self) -> str:
        """Format string for displaying the numeric values"""
        return self._reference_input.print_format
    
    @print_format.setter
    def print_format(self, value) -> None:
        self._reference_input.print_format = value
        for input_field in self._inputs:
            input_field.print_format = value
    
    @property
    def decimal(self) -> bool:
        """Restricts input to decimal numeric characters"""
        return self._reference_input.decimal
    
    @decimal.setter
    def decimal(self, value) -> None:
        self._reference_input.decimal = value
        for input_field in self._inputs:
            input_field.decimal = value
    
    @property
    def hexadecimal(self):
        """Restricts input to hexadecimal characters"""
        return self._reference_input.hexadecimal
    
    @hexadecimal.setter
    def hexadecimal(self, value) -> None:
        self._reference_input.hexadecimal = value
        for input_field in self._inputs:
            input_field.hexadecimal = value
    
    @property
    def scientific(self):
        """Restricts input to scientific notation characters"""
        return self._reference_input.scientific
    
    @scientific.setter
    def scientific(self, value) -> None:
        self._reference_input.scientific = value
        for input_field in self._inputs:
            input_field.scientific = value
    
    @property
    def callback_on_enter(self) -> bool:
        """Triggers callback when Enter key is pressed"""
        return self._reference_input.callback_on_enter
    
    @callback_on_enter.setter
    def callback_on_enter(self, value):
        self._reference_input.callback_on_enter = value
        for input_field in self._inputs:
            input_field.callback_on_enter = value
    
    @property
    def escape_clears_all(self) -> bool:
        """Makes Escape key clear the field's content"""
        return self._reference_input.escape_clears_all
    
    @escape_clears_all.setter
    def escape_clears_all(self, value):
        self._reference_input.escape_clears_all = value
        for input_field in self._inputs:
            input_field.escape_clears_all = value
    
    @property
    def readonly(self) -> bool:
        """Makes the input fields non-editable by the user"""
        return self._reference_input.readonly
    
    @readonly.setter
    def readonly(self, value) -> None:
        self._reference_input.readonly = value
        for input_field in self._inputs:
            input_field.readonly = value
    
    @property
    def password(self) -> bool:
        """Hides the input by displaying asterisks"""
        return self._reference_input.password
    
    @password.setter
    def password(self, value) -> None:
        self._reference_input.password = value
        for input_field in self._inputs:
            input_field.password = value
    
    @property
    def always_overwrite(self) -> bool:
        """Enables overwrite mode for text input"""
        return self._reference_input.always_overwrite
    
    @always_overwrite.setter
    def always_overwrite(self, value) -> None:
        self._reference_input.always_overwrite = value
        for input_field in self._inputs:
            input_field.always_overwrite = value
    
    @property
    def auto_select_all(self) -> bool:
        """Automatically selects all content when the field is focused"""
        return self._reference_input.auto_select_all
    
    @auto_select_all.setter
    def auto_select_all(self, value) -> None:
        self._reference_input.auto_select_all = value
        for input_field in self._inputs:
            input_field.auto_select_all = value
    
    @property
    def empty_as_zero(self) -> bool:
        """Treats empty input fields as zero values"""
        return self._reference_input.empty_as_zero
    
    @empty_as_zero.setter
    def empty_as_zero(self, value) -> None:
        self._reference_input.empty_as_zero = value
        for input_field in self._inputs:
            input_field.empty_as_zero = value
    
    @property
    def empty_if_zero(self) -> bool:
        """Displays an empty field when the value is zero"""
        return self._reference_input.empty_if_zero
    
    @empty_if_zero.setter
    def empty_if_zero(self, value) -> None:
        self._reference_input.empty_if_zero = value
        for input_field in self._inputs:
            input_field.empty_if_zero = value
    
    @property
    def no_horizontal_scroll(self):
        """Disables automatic horizontal scrolling during input"""
        return self._reference_input.no_horizontal_scroll
    
    @no_horizontal_scroll.setter
    def no_horizontal_scroll(self, value) -> None:
        self._reference_input.no_horizontal_scroll = value
        for input_field in self._inputs:
            input_field.no_horizontal_scroll = value
    
    @property
    def no_undo_redo(self) -> bool:
        """Disables the undo/redo functionality for input fields"""
        return self._reference_input.no_undo_redo
    
    @no_undo_redo.setter
    def no_undo_redo(self, value) -> None:
        self._reference_input.no_undo_redo = value
        for input_field in self._inputs:
            input_field.no_undo_redo = value


class SliderN(dcg.ChildWindow):
    """
    A widget for multiple sliders arranged horizontally.
    
    This widget combines multiple Slider instances in a horizontal layout
    to create a multi-dimensional value editor. The number of sliders is 
    determined dynamically by the length of values passed.
    
    All Slider properties are supported and applied to all contained sliders.
    The label is displayed at the right side of the widget.
    
    Parameters:
        context: The DearCyGui context
        values: Initial values for the sliders (determines number of sliders)
        shareable_values: SharedFloat objects to link with the sliders
        **kwargs: Additional keyword arguments for configuring the widget and sliders
    """
    __properties = [
        'keyboard_clamped', 'drag', 'logarithmic', 'min_value', 'max_value',
        'no_input', 'print_format', 'no_round', 'speed', 'vertical'
    ]
    
    def __init__(self, context, *, values=None, shareable_values=None, **kwargs):
        # Configure visuals
        self.border = False
        self.auto_resize_y = True
        self.no_scroll_with_mouse = True
        self.no_scrollbar = True
        self.theme = dcg.ThemeColorImGui(context, child_bg=0)
        kwargs.setdefault("width", "0.65*fillx")

        # Extract Slider-specific properties to apply later
        slider_props = {}
        for prop in self.__properties:
            if prop in kwargs:
                slider_props[prop] = kwargs.pop(prop)

        label = kwargs.pop('label', "")
        
        self._sliders = []
        self._callbacks = []
        self._label = dcg.Text(context, value=label, parent=self)
        self._label.show = label != ""
        self._shareable_values = None
        
        # Create reference Slider with all properties
        self._reference_slider = dcg.Slider(
            context,
            parent=None,  # Not added to layout
            attach=False,
            label="",
            y=0, height=0,
            callback=self._handle_slider_callback,
            **slider_props  # Apply all Slider-specific properties
        )
        
        # Create at least one slider
        self._create_sliders(1)
        
        # Set values or shareable_values if provided
        if values is not None:
            self.values = values
        elif shareable_values is not None:
            self.shareable_values = shareable_values

        # Initialize base class
        super().__init__(context, **kwargs)
    
    def _create_sliders(self, count) -> None:
        """Create or resize to the specified number of sliders"""
        if count < 1:
            count = 1
            
        # Save current values if any
        current_values = self.values if self._sliders else [0.0]
        
        # Ensure we have enough values
        while len(current_values) < count:
            current_values.append(0.0)
            
        # Remove excess sliders if needed
        while len(self._sliders) > count:
            self._sliders[-1].delete_item()
            self._sliders.pop()
            
        # Add new sliders if needed
        while len(self._sliders) < count:
            # Copy properties from reference slider
            #new_slider = self._reference_slider.copy()
            new_slider = dcg.Slider(self.context)
            for prop in self.__properties:
                setattr(new_slider, prop, getattr(self._reference_slider, prop))
            new_slider.callback=self._handle_slider_callback
            new_slider.parent = self
            new_slider.no_newline = True
            self._sliders.append(new_slider)
            
        # Put the label last
        self._label.parent = self

        # Update positions of all sliders
        self._update_positions()
        
        # Restore values
        for i, value in enumerate(current_values[:count]):
            self._sliders[i].value = value

    def _update_positions(self) -> None:
        """Update positions and sizes of all sliders (and the label)"""
        num_sliders = len(self._sliders)
        num_items = (1 if self._label.show else 0) + num_sliders
        
        # Calculate field width
        field_width = f"(parent.width - {num_items - 1} * theme.item_inner_spacing.x)/{num_sliders}"
        if self._label.show:
            field_width = field_width - self._label.width / num_sliders
            
        # Set positions of sliders
        x = "parent.x1"
        for i, slider in enumerate(self._sliders):
            slider.x = x
            slider.width = field_width
            x = slider.x + slider.width + "theme.item_inner_spacing.x"
        
        # Position label at the end
        self._label.x = x
    
    def _handle_slider_callback(self, sender, target, value) -> None:
        """Handler for individual slider callbacks that forwards to parent callback"""
        # Call parent callbacks with all values
        for callback in self._callbacks:
            callback(self, self, self.values)

    @property
    def callbacks(self) -> list[dcg.Callback]:
        """List of callbacks to be called when values change"""
        return self._callbacks
        
    @callbacks.setter
    def callbacks(self, value) -> None:
        """Set callbacks for value changes"""
        if value is None:
            value = []
        if not isinstance(value, (list, tuple)):
            value = [value]
        # Override the callbacks attribute to prevent
        # callback calls from the layout
        self._callbacks = [dcg.Callback(c) for c in value]
        
        # Set callbacks for each slider
        for slider in self._sliders:
            slider.callback = self._handle_slider_callback
    
    @property
    def values(self) -> list[float]:
        """Get values from all sliders as a list"""
        return [slider.value for slider in self._sliders]
    
    @values.setter
    def values(self, values) -> None:
        """Set values and adjust number of sliders if needed"""
        if not isinstance(values, (list, tuple)):
            values = [values]
        
        # Resize sliders if needed
        if len(values) != len(self._sliders):
            self._create_sliders(len(values))
        
        # Set values
        for i, value in enumerate(values):
            self._sliders[i].value = value
    
    @property
    def value(self) -> list[float]:
        """Get values as a list (alias for values)"""
        return self.values
    
    @value.setter
    def value(self, value) -> None:
        """Set value(s), handling both scalar and list inputs"""
        self.values = value
    
    @property
    def shareable_values(self) -> list[dcg.SharedFloat]:
        """Get the list of SharedFloat objects used by the sliders"""
        return self._shareable_values or [slider.shareable_value for slider in self._sliders]
    
    @shareable_values.setter
    def shareable_values(self, values) -> None:
        """Link with external SharedFloat objects"""
        if not isinstance(values, (list, tuple)):
            values = [values]
        
        # Resize sliders if needed
        if len(values) != len(self._sliders):
            self._create_sliders(len(values))
        
        # Set shareable values
        for i, shareable_value in enumerate(values):
            self._sliders[i].shareable_value = shareable_value
        
        self._shareable_values = values
    
    @property
    def shareable_value(self) -> dcg.SharedFloat | None:
        """Get first SharedFloat object (for backward compatibility)"""
        return self.shareable_values[0] if self._sliders else None
    
    @shareable_value.setter
    def shareable_value(self, value) -> None:
        """Set a single shareable value (extends to list if needed)"""
        if isinstance(value, (list, tuple)):
            self.shareable_values = value
        else:
            self.shareable_values = [value]
    
    @property
    def label(self) -> str:
        """Get the label displayed next to the last slider"""
        return self._label.value
    
    @label.setter
    def label(self, value) -> None:
        """Set the label for the widget"""
        self._label.value = value
        self._label.show = value != ""
        self._update_positions()
            
    # Forward all Slider properties to reference slider and all active sliders
    @property
    def keyboard_clamped(self) -> bool:
        """Whether slider values are clamped even when set via keyboard"""
        return self._reference_slider.keyboard_clamped
    
    @keyboard_clamped.setter
    def keyboard_clamped(self, value) -> None:
        self._reference_slider.keyboard_clamped = value
        for slider in self._sliders:
            slider.keyboard_clamped = value
    
    @property
    def drag(self) -> bool:
        """Whether to use 'drag' sliders rather than regular ones"""
        return self._reference_slider.drag
    
    @drag.setter
    def drag(self, value) -> None:
        self._reference_slider.drag = value
        for slider in self._sliders:
            slider.drag = value
    
    @property
    def logarithmic(self) -> bool:
        """Whether sliders should use logarithmic scaling"""
        return self._reference_slider.logarithmic
    
    @logarithmic.setter
    def logarithmic(self, value) -> None:
        self._reference_slider.logarithmic = value
        for slider in self._sliders:
            slider.logarithmic = value
    
    @property
    def min_value(self) -> float:
        """Minimum value the sliders will be clamped to"""
        return self._reference_slider.min_value
    
    @min_value.setter
    def min_value(self, value) -> None:
        self._reference_slider.min_value = value
        for slider in self._sliders:
            slider.min_value = value
    
    @property
    def max_value(self) -> float:
        """Maximum value the sliders will be clamped to"""
        return self._reference_slider.max_value
    
    @max_value.setter
    def max_value(self, value) -> None:
        self._reference_slider.max_value = value
        for slider in self._sliders:
            slider.max_value = value
    
    @property
    def no_input(self) -> bool:
        """Whether to disable keyboard input for the sliders"""
        return self._reference_slider.no_input
    
    @no_input.setter
    def no_input(self, value) -> None:
        self._reference_slider.no_input = value
        for slider in self._sliders:
            slider.no_input = value
    
    @property
    def print_format(self) -> str:
        """Format string for displaying slider values"""
        return self._reference_slider.print_format
    
    @print_format.setter
    def print_format(self, value) -> None:
        self._reference_slider.print_format = value
        for slider in self._sliders:
            slider.print_format = value
    
    @property
    def no_round(self) -> bool:
        """Whether to disable rounding of values according to print_format"""
        return self._reference_slider.no_round
    
    @no_round.setter
    def no_round(self, value) -> None:
        self._reference_slider.no_round = value
        for slider in self._sliders:
            slider.no_round = value
    
    @property
    def speed(self) -> float:
        """Speed at which values change in drag mode"""
        return self._reference_slider.speed
    
    @speed.setter
    def speed(self, value) -> None:
        self._reference_slider.speed = value
        for slider in self._sliders:
            slider.speed = value
    
    @property
    def vertical(self) -> bool:
        """Whether to display sliders vertically"""
        return self._reference_slider.vertical
    
    @vertical.setter
    def vertical(self, value) -> None:
        self._reference_slider.vertical = value
        for slider in self._sliders:
            slider.vertical = value