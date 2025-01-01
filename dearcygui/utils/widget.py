import dearcygui as dcg
from datetime import datetime

class TemporaryTooltip(dcg.Tooltip):
    """
    A tooltip that deletes itself when its
    showing condition is not met anymore.

    The handler passed as argument
    should be a new handler instance that will
    be checked for the condition. It should hold
    True as long as the item should be shown.
    """
    def __init__(self,
                 context : dcg.Context,
                 **kwargs):
        super().__init__(context, **kwargs)
        self.handlers += [
            dcg.LostRenderHandler(context,
                                  callback=self.destroy_tooltip)]

    def destroy_tooltip(self):
        if self.context is None:
            return # Already deleted
        # self.parent = None would work too but would wait GC.
        self.delete_item()

class TimePicker(dcg.Layout):
    """
    A widget for picking time values, similar to ImPlot's time picker.
    
    The widget displays hour/minute/second spinners and AM/PM selection.
    Uses seconds internally via SharedDouble but provides datetime interface.

    Properties:
        value (float): Current time value in seconds since midnight
        value_as_datetime (datetime): Get/set time as datetime object
        use_24hr (bool): Whether to use 24-hour time (default: False) 
        show_seconds (bool): Whether to show seconds spinner (default: True)
    """
    def __init__(self, context, *, value=None, use_24hr=False, show_seconds=True, **kwargs):
        super().__init__(context, **kwargs)

        # Default to current time if no value provided
        if value is None:
            value = datetime.now()
        if isinstance(value, datetime):
            total_seconds = value.hour * 3600 + value.minute * 60 + value.second
        else:
            total_seconds = float(value)
            
        self._value = dcg.SharedDouble(context, total_seconds)
        self._use_24hr = use_24hr
        self._show_seconds = show_seconds

        with dcg.HorizontalLayout(context, parent=self):
            # Hours spinner
            self._hours = dcg.InputValue(context, format="int", 
                                  min_value=0,
                                  max_value=23 if use_24hr else 12,
                                  value=self._get_display_hour(),
                                  width=45,
                                  callback=self._on_hour_change)

            # Minutes spinner 
            dcg.Text(context, value=":", width=10)
            self._minutes = dcg.InputValue(context, format="int",
                                    min_value=0, max_value=59,
                                    value=int((total_seconds % 3600) // 60),
                                    width=45,
                                    callback=self._on_minute_change)
            
            # Optional seconds spinner
            if show_seconds:
                dcg.Text(context, value=":", width=10)
                self._seconds = dcg.InputValue(context, format="int",
                                        min_value=0, max_value=59, 
                                        value=int(total_seconds % 60),
                                        width=45,
                                        callback=self._on_second_change)
            
            # AM/PM selector for 12-hour format
            if not use_24hr:
                dcg.Text(context, value=" ", width=10)
                self._am_pm = dcg.RadioButton(context,
                                        items=["AM", "PM"],
                                        value="PM" if (total_seconds // 3600) >= 12 else "AM",
                                        horizontal=True,
                                        callback=self._on_ampm_change)

    def _get_display_hour(self):
        """Convert internal seconds to display hour format"""
        hour = int(self._value.value // 3600)
        if not self._use_24hr:
            hour = hour % 12
            if hour == 0:
                hour = 12
        return hour

    def _get_total_seconds(self, hour, minute, second=None):
        """Helper to convert h:m:s to total seconds"""
        if second is None:
            second = int(self._value.value % 60)
        return hour * 3600 + minute * 60 + second
        
    def _on_hour_change(self, sender, target, value):
        """Handle hour input changes"""
        hour = value
        if not self._use_24hr:
            is_pm = self._am_pm.value == "PM"
            if hour == 12:
                hour = 0 if not is_pm else 12
            elif is_pm:
                hour += 12
        
        minute = int((self._value.value % 3600) // 60)
        self._value.value = self._get_total_seconds(hour, minute)
        self.run_callbacks()

    def _on_minute_change(self, sender, target, value): 
        """Handle minute input changes"""
        hour = int(self._value.value // 3600)
        self._value.value = self._get_total_seconds(hour, value)
        self.run_callbacks()

    def _on_second_change(self, sender, target, value):
        """Handle second input changes"""
        if self._show_seconds:
            hour = int(self._value.value // 3600)
            minute = int((self._value.value % 3600) // 60)
            self._value.value = self._get_total_seconds(hour, minute, value)
            self.run_callbacks()

    def _on_ampm_change(self, sender, target, value):
        """Handle AM/PM selection changes"""
        if not self._use_24hr:
            hour = int(self._value.value // 3600)
            cur_is_pm = hour >= 12
            new_is_pm = value == "PM"
            
            if cur_is_pm != new_is_pm:
                hour = (hour + 12) % 24
                minute = int((self._value.value % 3600) // 60)
                self._value.value = self._get_total_seconds(hour, minute)
                self.run_callbacks()

    def run_callbacks(self):
        for callback in self.callbacks:
            callback(self, self, self.value_as_datetime)

    @property
    def value(self):
        """Get current time in seconds"""
        return self._value.value

    @value.setter 
    def value(self, value):
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
    def value_as_datetime(self):
        """Get current time as datetime"""
        total_secs = int(self._value.value)
        hours = total_secs // 3600
        minutes = (total_secs % 3600) // 60
        seconds = total_secs % 60
        return datetime.now().replace(hour=hours, minute=minutes, second=seconds)

    @value_as_datetime.setter
    def value_as_datetime(self, value):
        """Set current time from datetime"""
        if not isinstance(value, datetime):
            raise ValueError("Value must be a datetime object")
        self.value = value

    @property
    def use_24hr(self):
        """Get whether using 24 hour format"""
        return self._use_24hr

    @use_24hr.setter
    def use_24hr(self, value):
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
    def show_seconds(self):
        """Get whether showing seconds"""
        return self._show_seconds

    @show_seconds.setter
    def show_seconds(self, value):
        """Set whether to show seconds"""
        if value != self._show_seconds:
            self._show_seconds = value
            if hasattr(self, '_seconds'):
                self._seconds.show = value

class DatePicker(dcg.Layout):
    """
    A widget for picking dates, similar to ImPlot's date picker.
    
    The widget displays a calendar interface with month/year navigation
    and allows selecting dates within the valid range (1970-2999).
    
    Properties:
        value (float): Current selected date as timestamp in seconds
        value_as_datetime (datetime): Current selected date as datetime object
        min_date (datetime): Minimum selectable date (default: 1970-01-01)
        max_date (datetime): Maximum selectable date (default: 2999-12-31) 
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
        
        self._value = dcg.SharedDouble(context, 0)
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
        
        with self:
            # Header row with navigation
            with dcg.HorizontalLayout(context):
                # Left button
                self._left_btn = dcg.Button(context, label="<", width=20,
                                          callback=self._on_prev_click)
                
                # Center label/button
                self._header_btn = dcg.Button(context, 
                                            label=self._get_header_text(),
                                            callback=self._on_header_click)
                
                # Right button
                self._right_btn = dcg.Button(context, label=">", width=20,
                                           callback=self._on_next_click)
            
            # Calendar grid
            self._grid = dcg.Layout(context)
            self._update_grid()
            
    def _get_header_text(self):
        """Get the header text based on current view level"""
        if self._view_level == 0:  # Day view
            return f"{self.MONTH_NAMES[self._current_month]} {self._current_year}"
        elif self._view_level == 1:  # Month view
            return str(self._current_year)
        else:  # Year view
            return f"{self._current_year_block}-{self._current_year_block+19}"
            
    def _update_grid(self):
        """Update the calendar grid based on current view level"""
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
            
    def _build_day_grid(self):
        """Build the day view calendar grid"""
        # Add weekday headers
        with dcg.HorizontalLayout(self.context, parent=self._grid):
            for day in self.WEEKDAY_ABBREV:
                dcg.Text(self.context, value=day)
                
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
        
        # Build calendar grid
        day = 1
        with dcg.Layout(self.context, parent=self._grid):
            for week in range(6):
                with dcg.HorizontalLayout(self.context):
                    for weekday in range(7):
                        if week == 0 and weekday < first_day.weekday():
                            # Previous month padding
                            pad_day = prev_month_days - first_day.weekday() + weekday + 1
                            btn = dcg.Button(self.context, label=str(pad_day), enabled=False)
                        elif day > days_in_month:
                            # Next month padding
                            btn = dcg.Button(self.context, label=str(day - days_in_month), enabled=False)
                            day += 1
                        else:
                            # Current month
                            date = datetime(self._current_year, self._current_month + 1, day)
                            enabled = self._min_date <= date <= self._max_date
                            btn = dcg.Button(self.context, 
                                          label=str(day),
                                          enabled=enabled,
                                          callback=self._on_day_select)
                            if date.date() == self.value_as_datetime.date():
                                btn.theme = dcg.ThemeStyleImGui(self.context,
                                                              button_color=(0.6, 0.6, 1.0, 0.6))
                            day += 1
                            
    def _build_month_grid(self):
        """Build the month selection grid"""
        with dcg.Layout(self.context, parent=self._grid):
            for row in range(3):
                with dcg.HorizontalLayout(self.context):
                    for col in range(4):
                        month = row * 4 + col
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
                                       callback=self._on_month_select)
                        if (month == self.value_as_datetime.month - 1 and 
                            self._current_year == self.value_as_datetime.year):
                            btn.theme = dcg.ThemeStyleImGui(self.context,
                                                          button_color=(0.6, 0.6, 1.0, 0.6))
                            
    def _build_year_grid(self):
        """Build the year selection grid"""
        with dcg.Layout(self.context, parent=self._grid):
            year = self._current_year_block
            for row in range(5):
                with dcg.HorizontalLayout(self.context):
                    for col in range(4):
                        if year <= 2999:
                            enabled = self._min_date.year <= year <= self._max_date.year
                            btn = dcg.Button(self.context,
                                           label=str(year),
                                           enabled=enabled,
                                           callback=self._on_year_select)
                            if year == self.value_as_datetime.year:
                                btn.theme = dcg.ThemeStyleImGui(self.context,
                                                              button_color=(0.6, 0.6, 1.0, 0.6))
                        year += 1
                            
    def _on_prev_click(self):
        """Handle previous button click"""
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
        
    def _on_next_click(self):
        """Handle next button click"""
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
        
    def _on_header_click(self):
        """Handle header button click"""
        self._view_level = (self._view_level + 1) % 3
        self._update_grid()
        
    def _on_day_select(self, sender):
        """Handle day selection"""
        day = int(sender.label)
        new_date = datetime(self._current_year, self._current_month + 1, day)
        self._set_value_and_run_callbacks(new_date)
        
    def _on_month_select(self, sender):
        """Handle month selection"""
        month = self.MONTH_ABBREV.index(sender.label)
        self._current_month = month
        self._view_level = 0
        self._update_grid()
        
    def _on_year_select(self, sender):
        """Handle year selection"""
        self._current_year = int(sender.label)
        self._view_level = 1
        self._update_grid()
        
    def _set_value_and_run_callbacks(self, value):
        """Set date value and trigger callbacks"""
        self._set_value(value)
        self.run_callbacks()

    def _set_value(self, value):
        """Internal method to set value without triggering callbacks"""
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
    def value(self):
        """Get current value in seconds since epoch"""
        return self._value.value
    
    @value.setter
    def value(self, value):
        """Set current value in seconds since epoch"""
        if isinstance(value, datetime):
            self._set_value(value)
        else:
            try:
                dt = datetime.fromtimestamp(float(value))
                self._set_value(dt)
            except (ValueError, TypeError, OSError):
                raise ValueError("Value must be a datetime or valid timestamp in seconds")

    @property
    def value_as_datetime(self):
        """Get current selected date as datetime"""
        return datetime.fromtimestamp(self._value.value)
    
    @value_as_datetime.setter 
    def value_as_datetime(self, value):
        """Set current selected date from datetime"""
        self.value = value

    def run_callbacks(self):
        """Run all registered callbacks"""
        for callback in self.callbacks:
            callback(self, self, self.value_as_datetime)

class DateTimePicker(dcg.Layout):
    """
    A widget combining DatePicker and TimePicker for selecting both date and time.
    
    The widget displays both date and time selection controls and manages them together.
    Uses seconds since epoch internally via SharedDouble and provides datetime interface.

    Properties:
        value (float): Current value as timestamp in seconds since epoch
        value_as_datetime (datetime): Current value as datetime object
        min_date (datetime): Minimum selectable date (default: 1970-01-01)
        max_date (datetime): Maximum selectable date (default: 2999-12-31)
        layout (str): Layout arrangement - "horizontal", "vertical", "compact" 
        use_24hr (bool): Whether to use 24-hour time (default: False)
        show_seconds (bool): Whether to show seconds spinner (default: True)
    """

    def __init__(self, context, *, 
                 value=None,
                 min_date=None,
                 max_date=None,
                 layout="horizontal",
                 use_24hr=False,
                 show_seconds=True,
                 **kwargs):
        super().__init__(context, **kwargs)
        
        # Initialize shared value
        self._value = dcg.SharedDouble(context, 0)
        
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

    def _on_change(self, sender, target, value):
        """Handle date/time changes from either picker"""
        self.run_callbacks()

    @property
    def value(self):
        """Get current value in seconds since epoch"""
        return self._value.value
    
    @value.setter
    def value(self, value):
        """Set current value in seconds since epoch"""
        if isinstance(value, datetime):
            self._value.value = value.timestamp()
        else:
            self._value.value = float(value)

    @property
    def value_as_datetime(self):
        """Get current value as datetime"""
        return datetime.fromtimestamp(self._value.value)
    
    @value_as_datetime.setter
    def value_as_datetime(self, value):
        """Set current value from datetime"""
        if not isinstance(value, datetime):
            raise ValueError("Value must be a datetime object")
        self.value = value

    def run_callbacks(self):
        """Run all registered callbacks with datetime value"""
        for callback in self.callbacks:
            callback(self, self, self.value_as_datetime)

    @property
    def use_24hr(self):
        """Get whether using 24-hour time format"""
        return self._time_picker.use_24hr

    @use_24hr.setter 
    def use_24hr(self, value):
        """Set whether to use 24-hour time format"""
        self._time_picker.use_24hr = value

    @property
    def show_seconds(self):
        """Get whether showing seconds"""
        return self._time_picker.show_seconds
    
    @show_seconds.setter
    def show_seconds(self, value):
        """Set whether to show seconds"""
        self._time_picker.show_seconds = value

    @property
    def date_picker(self):
        """Get the internal DatePicker widget"""
        return self._date_picker

    @property
    def time_picker(self):
        """Get the internal TimePicker widget"""
        return self._time_picker