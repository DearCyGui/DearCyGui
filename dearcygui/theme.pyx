#!python
#cython: language_level=3
#cython: boundscheck=False
#cython: wraparound=False
#cython: nonecheck=False
#cython: embedsignature=False
#cython: cdivision=True
#cython: cdivision_warnings=False
#cython: always_allow_keywords=False
#cython: profile=False
#cython: infer_types=False
#cython: initializedcheck=False
#cython: c_line_in_traceback=False
#cython: auto_pickle=False
#cython: freethreading_compatible=True
#distutils: language=c++

from libc.stdint cimport int32_t, uint32_t
from libcpp.cmath cimport round
from libcpp.unordered_map cimport unordered_map, pair

from cpython.object cimport PyObject
from cpython.sequence cimport PySequence_Check
from cython.operator cimport dereference
cimport cython


from .core cimport lock_gil_friendly, baseItem, baseTheme
from .c_types cimport DCGMutex, unique_lock
from .imgui_types cimport ImGuiColorIndex, ImPlotColorIndex,\
    ImGuiStyleIndex, ImPlotStyleIndex, parse_color
from .types cimport make_PlotMarker, PlotMarker
from .wrapper cimport imgui, implot


cdef inline void imgui_PushStyleVar2(int i, float[2] val) noexcept nogil:
    imgui.PushStyleVar(<imgui.ImGuiStyleVar>i, imgui.ImVec2(val[0], val[1]))

cdef inline void implot_PushStyleVar2(int i, float[2] val) noexcept nogil:
    implot.PushStyleVar(<implot.ImPlotStyleVar>i, imgui.ImVec2(val[0], val[1]))

cdef inline void push_theme_children(baseItem item) noexcept nogil:
    if item.last_theme_child is None:
        return
    cdef PyObject *child = <PyObject*> item.last_theme_child
    while (<baseItem>child).prev_sibling is not None:
        child = <PyObject *>(<baseItem>child).prev_sibling
    while (<baseItem>child) is not None:
        (<baseTheme>child).push()
        child = <PyObject *>(<baseItem>child).next_sibling

cdef inline void pop_theme_children(baseItem item) noexcept nogil:
    if item.last_theme_child is None:
        return
    # Note: we are guaranteed to have the same
    # children than during push()
    # We do pop in reverse order to match push.
    cdef PyObject *child = <PyObject*> item.last_theme_child
    while (<baseItem>child) is not None:
        (<baseTheme>child).pop()
        child = <PyObject *>(<baseItem>child).prev_sibling

cdef class baseThemeColor(baseTheme):
    """
    Base class for theme colors that provides common color-related functionality.
    
    This class provides the core implementation for managing color themes in different 
    contexts (ImGui/ImPlot). Color themes allow setting colors for various UI 
    elements using different color formats:
    - unsigned int (encodes rgba little-endian)
    - (r, g, b, a) with values as integers [0-255]  
    - (r, g, b, a) with values as normalized floats [0.0-1.0]
    - If alpha is omitted, it defaults to 255

    The class implements common dictionary-style access to colors through string names
    or numeric indices.
    """
    def __cinit__(self):
        self._index_to_value = new unordered_map[int32_t, uint32_t]()

    def __dealloc__(self):
        if self._index_to_value != NULL:
            del self._index_to_value

    @cython.annotation_typing(False)
    def __getitem__(self, key: str | int) -> int:
        """Get color by string name or numeric index"""
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef int32_t color_index
        if isinstance(key, str):
            return getattr(self, key)
        elif isinstance(key, int):
            color_index = key
            if color_index < 0 or color_index >= len(self._names):
                raise KeyError("No color of index %d" % key)
            return getattr(self, self._names[color_index])
        else:
            raise TypeError("%s is an invalid index type" % str(type(key)))

    @cython.annotation_typing(False)
    def __setitem__(self, key: str | int, value: 'Color') -> None:
        """Set color by string name or numeric index"""
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef int32_t color_index
        if isinstance(key, str):
            setattr(self, key, value)
        elif isinstance(key, int):
            color_index = key
            if color_index < 0 or color_index >= len(self._names):
                raise KeyError("No color of index %d" % key)
            setattr(self, self._names[color_index], value)
        else:
            raise TypeError("%s is an invalid index type" % str(type(key)))

    @cython.annotation_typing(False)
    def __iter__(self) -> list[tuple[str, int]]:
        """Iterate over (color_name, color_value) pairs"""
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list result = []
        cdef pair[int32_t, uint32_t] element_content
        for element_content in dereference(self._index_to_value):
            name = self._names[element_content.first] 
            result.append((name, int(element_content.second)))
        return iter(result)

    cdef object _common_getter(self, int32_t index):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef unordered_map[int32_t, uint32_t].iterator element_content = self._index_to_value.find(index)
        if element_content == self._index_to_value.end():
            # None: default
            return None
        cdef uint32_t value = dereference(element_content).second
        return value

    cdef void _common_setter(self, int32_t index, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            self._index_to_value.erase(index)
            return
        cdef imgui.ImU32 color = parse_color(value)
        dereference(self._index_to_value)[index] = <uint32_t> color

cdef class ThemeColorImGui(baseThemeColor):
    """
    Theme color parameters that affect how ImGui
    renders items.
    All colors accept three formats:
    - unsigned (encodes a rgba little-endian)
    - (r, g, b, a) with r, g, b, a as integers.
    - (r, g, b, a) with r, g, b, a as floats.

    When r, g, b, a are floats, they should be normalized
    between 0 and 1, while integers are between 0 and 255.
    If a is missing, it defaults to 255.

    Keyword Arguments:
        text: Color for text rendering
        text_disabled: Color for the text of disabled items
        window_bg: Background of normal windows
        child_bg:  Background of child windows
        popup_bg: Background of popups, menus, tooltips windows
        border: Color of borders
        border_shadow: Color of border shadows
        frame_bg: Background of checkbox, radio button, plot, slider, text input
        frame_bg_hovered: Color of FrameBg when the item is hovered
        frame_bg_active: Color of FrameBg when the item is active
        title_bg: Title bar
        title_bg_active: Title bar when focused
        title_bg_collapsed: Title bar when collapsed
        menu_bar_bg: Background color of the menu bar
        scrollbar_bg: Background color of the scroll bar
        scrollbar_grab: Color of the scroll slider
        scrollbar_grab_hovered: Color of the scroll slider when hovered
        scrollbar_grab_active: Color of the scroll slider when selected
        check_mark: Checkbox tick and RadioButton circle
        slider_grab: Color of sliders
        slider_grab_active: Color of selected sliders
        button: Color of buttons
        button_hovered: Color of buttons when hovered
        button_active: Color of buttons when selected
        header: Header* colors are used for CollapsingHeader, TreeNode, Selectable, MenuItem
        header_hovered: Header color when hovered
        header_active: Header color when clicked
        separator: Color of separators
        separator_hovered: Color of separator when hovered
        separator_active: Color of separator when active
        resize_grip: Resize grip in lower-right and lower-left corners of windows.
        resize_grip_hovered: ResizeGrip when hovered
        resize_grip_active: ResizeGrip when clicked
        tab_hovered: Tab background, when hovered
        tab: Tab background, when tab-bar is focused & tab is unselected
        tab_selected: Tab background, when tab-bar is focused & tab is selected
        tab_selected_overline: Tab horizontal overline, when tab-bar is focused & tab is selected
        tab_dimmed: Tab background, when tab-bar is unfocused & tab is unselected
        tab_dimmed_selected: Tab background, when tab-bar is unfocused & tab is selected
        tab_dimmed_selected_overline: ..horizontal overline, when tab-bar is unfocused & tab is selected
        plot_lines: Color of SimplePlot lines
        plot_lines_hovered: Color of SimplePlot lines when hovered
        plot_histogram: Color of SimplePlot histogram
        plot_histogram_hovered: Color of SimplePlot histogram when hovered
        table_header_bg: Table header background
        table_border_strong: Table outer and header borders (prefer using Alpha=1.0 here)
        table_border_light: Table inner borders (prefer using Alpha=1.0 here)
        table_row_bg: Table row background (even rows)
        table_row_bg_alt: Table row background (odd rows)
        text_link: Hyperlink color
        text_selected_bg: Color of the background of selected text
        drag_drop_target: Rectangle highlighting a drop target
        nav_cursor: Gamepad/keyboard: current highlighted item
        nav_windowing_highlight: Highlight window when using CTRL+TAB
        nav_windowing_dim_bg: Darken/colorize entire screen behind the CTRL+TAB window list, when active
        modal_window_dim_bg: Darken/colorize entire screen behind a modal window, when one is active
    """

    def __cinit__(self):
        self._names = [
            "text",
            "text_disabled", 
            "window_bg",
            "child_bg",
            "popup_bg",
            "border",
            "border_shadow",
            "frame_bg",
            "frame_bg_hovered",
            "frame_bg_active",
            "title_bg",
            "title_bg_active", 
            "title_bg_collapsed",
            "menu_bar_bg",
            "scrollbar_bg",
            "scrollbar_grab",
            "scrollbar_grab_hovered",
            "scrollbar_grab_active",
            "check_mark",
            "slider_grab",
            "slider_grab_active",
            "button",
            "button_hovered",
            "button_active",
            "header",
            "header_hovered",
            "header_active",
            "separator",
            "separator_hovered",
            "separator_active",
            "resize_grip",
            "resize_grip_hovered",
            "resize_grip_active",
            "tab_hovered",
            "tab",
            "tab_selected",  
            "tab_selected_overline",
            "tab_dimmed",
            "tab_dimmed_selected",
            "tab_dimmed_selected_overline",
            "plot_lines",
            "plot_lines_hovered",
            "plot_histogram",
            "plot_histogram_hovered",
            "table_header_bg",
            "table_border_strong",
            "table_border_light", 
            "table_row_bg",
            "table_row_bg_alt",
            "text_link",
            "text_selected_bg",
            "drag_drop_target",
            "nav_cursor",
            "nav_windowing_highlight",
            "nav_windowing_dim_bg",
            "modal_window_dim_bg"
        ]

    @property 
    def text(self):
        """Color for text rendering. 
        Default: (1.00, 1.00, 1.00, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TEXT)
        
    @text.setter
    def text(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TEXT, value)

    @property
    def text_disabled(self):
        """Color for the text of disabled items.
        Default: (0.50, 0.50, 0.50, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TEXT_DISABLED)

    @text_disabled.setter
    def text_disabled(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TEXT_DISABLED, value)

    @property
    def window_bg(self):
        """Background of normal windows.
        Default: (0.06, 0.06, 0.06, 0.94)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.WINDOW_BG)
        
    @window_bg.setter
    def window_bg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.WINDOW_BG, value)

    @property
    def child_bg(self):
        """Background of child windows.
        Default: (0.00, 0.00, 0.00, 0.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.CHILD_BG)

    @child_bg.setter
    def child_bg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.CHILD_BG, value)

    @property
    def popup_bg(self):
        """Background of popups, menus, tooltips windows.
        Default: (0.08, 0.08, 0.08, 0.94)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.POPUP_BG)

    @popup_bg.setter
    def popup_bg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.POPUP_BG, value)

    @property
    def border(self):
        """Color of borders.
        Default: (0.43, 0.43, 0.50, 0.50)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.BORDER)

    @border.setter
    def border(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.BORDER, value)

    @property
    def border_shadow(self):
        """Color of border shadows.
        Default: (0.00, 0.00, 0.00, 0.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.BORDER_SHADOW)

    @border_shadow.setter
    def border_shadow(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.BORDER_SHADOW, value)

    @property 
    def frame_bg(self):
        """Background of checkbox, radio button, plot, slider, text input.
        Default: (0.16, 0.29, 0.48, 0.54)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.FRAME_BG)

    @frame_bg.setter
    def frame_bg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.FRAME_BG, value)

    @property
    def frame_bg_hovered(self):
        """Color of FrameBg when the item is hovered.
        Default: (0.26, 0.59, 0.98, 0.40)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.FRAME_BG_HOVERED)

    @frame_bg_hovered.setter 
    def frame_bg_hovered(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.FRAME_BG_HOVERED, value)

    @property
    def frame_bg_active(self):  
        """Color of FrameBg when the item is active.
        Default: (0.26, 0.59, 0.98, 0.67)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.FRAME_BG_ACTIVE)

    @frame_bg_active.setter
    def frame_bg_active(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.FRAME_BG_ACTIVE, value)

    @property
    def title_bg(self):
        """Title bar color.
        Default: (0.04, 0.04, 0.04, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TITLE_BG)

    @title_bg.setter
    def title_bg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TITLE_BG, value)

    @property
    def title_bg_active(self):
        """Title bar color when focused.
        Default: (0.16, 0.29, 0.48, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TITLE_BG_ACTIVE)

    @title_bg_active.setter
    def title_bg_active(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TITLE_BG_ACTIVE, value)

    @property
    def title_bg_collapsed(self):
        """Title bar color when collapsed.
        Default: (0.00, 0.00, 0.00, 0.51)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TITLE_BG_COLLAPSED)

    @title_bg_collapsed.setter
    def title_bg_collapsed(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TITLE_BG_COLLAPSED, value)

    @property
    def menu_bar_bg(self):
        """Menu bar background color.
        Default: (0.14, 0.14, 0.14, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.MENU_BAR_BG)

    @menu_bar_bg.setter
    def menu_bar_bg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.MENU_BAR_BG, value)

    @property  
    def scrollbar_bg(self):
        """Scrollbar background color.
        Default: (0.02, 0.02, 0.02, 0.53)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.SCROLLBAR_BG)

    @scrollbar_bg.setter
    def scrollbar_bg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.SCROLLBAR_BG, value)

    @property
    def scrollbar_grab(self):
        """Scrollbar grab color.
        Default: (0.31, 0.31, 0.31, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.SCROLLBAR_GRAB)

    @scrollbar_grab.setter  
    def scrollbar_grab(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.SCROLLBAR_GRAB, value)

    @property
    def scrollbar_grab_hovered(self):
        """Scrollbar grab color when hovered. 
        Default: (0.41, 0.41, 0.41, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.SCROLLBAR_GRAB_HOVERED)

    @scrollbar_grab_hovered.setter
    def scrollbar_grab_hovered(self, value): 
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.SCROLLBAR_GRAB_HOVERED, value)

    @property
    def scrollbar_grab_active(self):
        """Scrollbar grab color when active.
        Default: (0.51, 0.51, 0.51, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.SCROLLBAR_GRAB_ACTIVE)

    @scrollbar_grab_active.setter
    def scrollbar_grab_active(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.SCROLLBAR_GRAB_ACTIVE, value)

    @property
    def check_mark(self):
        """Checkmark color.
        Default: (0.26, 0.59, 0.98, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.CHECK_MARK)

    @check_mark.setter
    def check_mark(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.CHECK_MARK, value)

    @property
    def slider_grab(self):
        """Slider grab color.
        Default: (0.24, 0.52, 0.88, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.SLIDER_GRAB)

    @slider_grab.setter
    def slider_grab(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.SLIDER_GRAB, value)

    @property 
    def slider_grab_active(self):
        """Slider grab color when active.
        Default: (0.26, 0.59, 0.98, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.SLIDER_GRAB_ACTIVE)

    @slider_grab_active.setter
    def slider_grab_active(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.SLIDER_GRAB_ACTIVE, value)

    @property
    def button(self):
        """Button color.
        Default: (0.26, 0.59, 0.98, 0.40)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.BUTTON)

    @button.setter
    def button(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.BUTTON, value)

    @property
    def button_hovered(self):
        """Button color when hovered.
        Default: (0.26, 0.59, 0.98, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.BUTTON_HOVERED)

    @button_hovered.setter
    def button_hovered(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.BUTTON_HOVERED, value)

    @property
    def button_active(self):
        """Button color when active.
        Default: (0.06, 0.53, 0.98, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.BUTTON_ACTIVE)

    @button_active.setter
    def button_active(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.BUTTON_ACTIVE, value)

    @property
    def header(self):
        """Colors used for CollapsingHeader, TreeNode, Selectable, MenuItem.
        Default: (0.26, 0.59, 0.98, 0.31)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.HEADER)

    @header.setter
    def header(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.HEADER, value)

    @property 
    def header_hovered(self):
        """Header colors when hovered.
        Default: (0.26, 0.59, 0.98, 0.80)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.HEADER_HOVERED)

    @header_hovered.setter
    def header_hovered(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.HEADER_HOVERED, value)

    @property
    def header_active(self):
        """Header colors when activated/clicked.
        Default: (0.26, 0.59, 0.98, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.HEADER_ACTIVE) 

    @header_active.setter
    def header_active(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.HEADER_ACTIVE, value)

    @property
    def separator(self):
        """Color of separating lines.
        Default: Same as Border color (0.43, 0.43, 0.50, 0.50)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.SEPARATOR)

    @separator.setter
    def separator(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.SEPARATOR, value)

    @property
    def separator_hovered(self):
        """Separator color when hovered.
        Default: (0.10, 0.40, 0.75, 0.78)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.SEPARATOR_HOVERED)

    @separator_hovered.setter
    def separator_hovered(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.SEPARATOR_HOVERED, value)

    @property
    def separator_active(self):
        """Separator color when active.
        Default: (0.10, 0.40, 0.75, 1.00)""" 
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.SEPARATOR_ACTIVE)

    @separator_active.setter
    def separator_active(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.SEPARATOR_ACTIVE, value)

    @property
    def resize_grip(self):
        """Resize grip in lower-right and lower-left corners of windows.
        Default: (0.26, 0.59, 0.98, 0.20)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.RESIZE_GRIP)
    
    @resize_grip.setter 
    def resize_grip(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.RESIZE_GRIP, value)
    
    @property
    def resize_grip_hovered(self):
        """ResizeGrip color when hovered.
        Default: (0.26, 0.59, 0.98, 0.67)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.RESIZE_GRIP_HOVERED)
    
    @resize_grip_hovered.setter
    def resize_grip_hovered(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.RESIZE_GRIP_HOVERED, value)
    
    @property
    def resize_grip_active(self):
        """ResizeGrip color when clicked.
        Default: (0.26, 0.59, 0.98, 0.95)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.RESIZE_GRIP_ACTIVE)
    
    @resize_grip_active.setter
    def resize_grip_active(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.RESIZE_GRIP_ACTIVE, value)
    
    @property
    def tab_hovered(self):
        """Tab background when hovered.
        Default: Same as HeaderHovered color"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TAB_HOVERED)
    
    @tab_hovered.setter
    def tab_hovered(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TAB_HOVERED, value)
    
    @property
    def tab(self):
        """Tab background when tab-bar is focused & tab is unselected.
        Default: Value interpolated between Header and TitleBgActive colors with factor 0.80"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TAB)
    
    @tab.setter
    def tab(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TAB, value)
    
    @property
    def tab_selected(self):
        """Tab background when tab-bar is focused & tab is selected.
        Default: Value interpolated between HeaderActive and TitleBgActive colors with factor 0.60"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TAB_SELECTED)
    
    @tab_selected.setter
    def tab_selected(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TAB_SELECTED, value)
    
    @property
    def tab_selected_overline(self):
        """Tab horizontal overline when tab-bar is focused & tab is selected.
        Default: Same as HeaderActive color"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TAB_SELECTED_OVERLINE)
    
    @tab_selected_overline.setter
    def tab_selected_overline(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TAB_SELECTED_OVERLINE, value)
    
    @property
    def tab_dimmed(self):
        """Tab background when tab-bar is unfocused & tab is unselected.
        Default: Value interpolated between Tab and TitleBg colors with factor 0.80"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TAB_DIMMED)
    
    @tab_dimmed.setter
    def tab_dimmed(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TAB_DIMMED, value)
    
    @property
    def tab_dimmed_selected(self):
        """Tab background when tab-bar is unfocused & tab is selected.
        Default: Value interpolated between TabSelected and TitleBg colors with factor 0.40""" 
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TAB_DIMMED_SELECTED)
    
    @tab_dimmed_selected.setter
    def tab_dimmed_selected(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TAB_DIMMED_SELECTED, value)
    
    @property
    def tab_dimmed_selected_overline(self):
        """Tab horizontal overline when tab-bar is unfocused & tab is selected.
        Default: (0.50, 0.50, 0.50, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TAB_DIMMED_SELECTED_OVERLINE)
    
    @tab_dimmed_selected_overline.setter
    def tab_dimmed_selected_overline(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TAB_DIMMED_SELECTED_OVERLINE, value)
    
    @property
    def plot_lines(self):
        """Color of SimplePlot lines.
        Default: (0.61, 0.61, 0.61, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.PLOT_LINES) 
    
    @plot_lines.setter
    def plot_lines(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.PLOT_LINES, value)
    
    @property
    def plot_lines_hovered(self):
        """Color of SimplePlot lines when hovered.
        Default: (1.00, 0.43, 0.35, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.PLOT_LINES_HOVERED)
    
    @plot_lines_hovered.setter
    def plot_lines_hovered(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.PLOT_LINES_HOVERED, value)
    
    @property
    def plot_histogram(self):
        """Color of SimplePlot histogram.
        Default: (0.90, 0.70, 0.00, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.PLOT_HISTOGRAM)
    
    @plot_histogram.setter
    def plot_histogram(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.PLOT_HISTOGRAM, value)
    
    @property
    def plot_histogram_hovered(self):
        """Color of SimplePlot histogram when hovered.
        Default: (1.00, 0.60, 0.00, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.PLOT_HISTOGRAM_HOVERED)
    
    @plot_histogram_hovered.setter
    def plot_histogram_hovered(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.PLOT_HISTOGRAM_HOVERED, value)
    
    @property
    def table_header_bg(self):
        """Table header background.
        Default: (0.19, 0.19, 0.20, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TABLE_HEADER_BG)
    
    @table_header_bg.setter
    def table_header_bg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TABLE_HEADER_BG, value)
    
    @property
    def table_border_strong(self):
        """Table outer borders and headers (prefer using Alpha=1.0 here).
        Default: (0.31, 0.31, 0.35, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TABLE_BORDER_STRONG)
    
    @table_border_strong.setter
    def table_border_strong(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TABLE_BORDER_STRONG, value)
    
    @property
    def table_border_light(self):
        """Table inner borders (prefer using Alpha=1.0 here).
        Default: (0.23, 0.23, 0.25, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TABLE_BORDER_LIGHT)
    
    @table_border_light.setter
    def table_border_light(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TABLE_BORDER_LIGHT, value)
    
    @property
    def table_row_bg(self):
        """Table row background (even rows).
        Default: (0.00, 0.00, 0.00, 0.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TABLE_ROW_BG)
    
    @table_row_bg.setter
    def table_row_bg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TABLE_ROW_BG, value)
    
    @property
    def table_row_bg_alt(self):
        """Table row background (odd rows).
        Default: (1.00, 1.00, 1.00, 0.06)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TABLE_ROW_BG_ALT)
    
    @table_row_bg_alt.setter
    def table_row_bg_alt(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TABLE_ROW_BG_ALT, value)
    
    @property
    def text_link(self):
        """Hyperlink color.
        Default: Same as HeaderActive color"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TEXT_LINK)
    
    @text_link.setter
    def text_link(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TEXT_LINK, value)

    @property
    def text_selected_bg(self):
        """Background color of selected text.
        Default: (0.26, 0.59, 0.98, 0.35)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TEXT_SELECTED_BG)

    @text_selected_bg.setter
    def text_selected_bg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TEXT_SELECTED_BG, value)

    @property
    def drag_drop_target(self):
        """Rectangle highlighting a drop target.
        Default: (1.00, 1.00, 0.00, 0.90)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.DRAG_DROP_TARGET)
    
    @drag_drop_target.setter
    def drag_drop_target(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.DRAG_DROP_TARGET, value)

    @property
    def nav_cursor(self):
        """Color of keyboard/gamepad navigation cursor/rectangle, when visible.
        Default: Same as HeaderHovered (0.26, 0.59, 0.98, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.NAV_CURSOR)

    @nav_cursor.setter
    def nav_cursor(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.NAV_CURSOR, value)

    @property
    def nav_windowing_highlight(self):
        """Highlight window when using CTRL+TAB.
        Default: (1.00, 1.00, 1.00, 0.70)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.NAV_WINDOWING_HIGHLIGHT)

    @nav_windowing_highlight.setter
    def nav_windowing_highlight(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.NAV_WINDOWING_HIGHLIGHT, value)

    @property 
    def nav_windowing_dim_bg(self):
        """Darken/colorize entire screen behind CTRL+TAB window list.
        Default: (0.80, 0.80, 0.80, 0.20)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.NAV_WINDOWING_DIM_BG)

    @nav_windowing_dim_bg.setter
    def nav_windowing_dim_bg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.NAV_WINDOWING_DIM_BG, value)

    @property
    def modal_window_dim_bg(self):
        """Darken/colorize entire screen behind a modal window.
        Default: (0.80, 0.80, 0.80, 0.35)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.MODAL_WINDOW_DIM_BG)

    @modal_window_dim_bg.setter
    def modal_window_dim_bg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.MODAL_WINDOW_DIM_BG, value)

    cdef void push(self) noexcept nogil:
        self.mutex.lock()
        if not(self._enabled):
            self._last_push_size.push_back(0)
            return
        cdef pair[int32_t, uint32_t] element_content
        for element_content in dereference(self._index_to_value):
            # Note: imgui seems to convert U32 for this. Maybe use float4
            imgui.PushStyleColor(<imgui.ImGuiCol>element_content.first, <imgui.ImU32>element_content.second)
        self._last_push_size.push_back(<int>self._index_to_value.size())

    cdef void pop(self) noexcept nogil:
        cdef int32_t count = self._last_push_size.back()
        self._last_push_size.pop_back()
        if count > 0:
            imgui.PopStyleColor(count)
        self.mutex.unlock()

    @classmethod
    def get_default(cls, str color_name):
        """Get the default color value for the given color name."""
        if color_name == "text":
            return (1.00, 1.00, 1.00, 1.00)
        elif color_name == "text_disabled":
            return (0.50, 0.50, 0.50, 1.00)
        elif color_name == "window_bg":
            return (0.06, 0.06, 0.06, 0.94)
        elif color_name == "child_bg":
            return (0.00, 0.00, 0.00, 0.00)
        elif color_name == "popup_bg":
            return (0.08, 0.08, 0.08, 0.94)
        elif color_name == "border":
            return (0.43, 0.43, 0.50, 0.50)
        elif color_name == "border_shadow":
            return (0.00, 0.00, 0.00, 0.00)
        elif color_name == "frame_bg":
            return (0.16, 0.29, 0.48, 0.54)
        elif color_name == "frame_bg_hovered":
            return (0.26, 0.59, 0.98, 0.40)
        elif color_name == "frame_bg_active":
            return (0.26, 0.59, 0.98, 0.67)
        elif color_name == "title_bg":
            return (0.04, 0.04, 0.04, 1.00)
        elif color_name == "title_bg_active":
            return (0.16, 0.29, 0.48, 1.00)
        elif color_name == "title_bg_collapsed":
            return (0.00, 0.00, 0.00, 0.51)
        elif color_name == "menu_bar_bg":
            return (0.14, 0.14, 0.14, 1.00)
        elif color_name == "scrollbar_bg":
            return (0.02, 0.02, 0.02, 0.53)
        elif color_name == "scrollbar_grab":
            return (0.31, 0.31, 0.31, 1.00)
        elif color_name == "scrollbar_grab_hovered":
            return (0.41, 0.41, 0.41, 1.00)
        elif color_name == "scrollbar_grab_active":
            return (0.51, 0.51, 0.51, 1.00)
        elif color_name == "check_mark":
            return (0.26, 0.59, 0.98, 1.00)
        elif color_name == "slider_grab":
            return (0.24, 0.52, 0.88, 1.00)
        elif color_name == "slider_grab_active":
            return (0.26, 0.59, 0.98, 1.00)
        elif color_name == "button":
            return (0.26, 0.59, 0.98, 0.40)
        elif color_name == "button_hovered":
            return (0.26, 0.59, 0.98, 1.00)
        elif color_name == "button_active":
            return (0.06, 0.53, 0.98, 1.00)
        elif color_name == "header":
            return (0.26, 0.59, 0.98, 0.31)
        elif color_name == "header_hovered":
            return (0.26, 0.59, 0.98, 0.80)
        elif color_name == "header_active":
            return (0.26, 0.59, 0.98, 1.00)
        elif color_name == "separator":
            return (0.43, 0.43, 0.50, 0.50)
        elif color_name == "separator_hovered":
            return (0.10, 0.40, 0.75, 0.78)
        elif color_name == "separator_active":
            return (0.10, 0.40, 0.75, 1.00)
        elif color_name == "resize_grip":
            return (0.26, 0.59, 0.98, 0.20)
        elif color_name == "resize_grip_hovered":
            return (0.26, 0.59, 0.98, 0.67)
        elif color_name == "resize_grip_active":
            return (0.26, 0.59, 0.98, 0.95)
        elif color_name == "tab_hovered":
            return (0.26, 0.59, 0.98, 0.80)
        elif color_name == "tab":
            return (0.26, 0.59, 0.98, 0.80)
        elif color_name == "tab_selected":
            return (0.26, 0.59, 0.98, 0.60)
        elif color_name == "tab_selected_overline":
            return (0.26, 0.59, 0.98, 1.00)
        elif color_name == "tab_dimmed":
            return (0.26, 0.59, 0.98, 0.80)
        elif color_name == "tab_dimmed_selected":
            return (0.26, 0.59, 0.98, 0.40)
        elif color_name == "tab_dimmed_selected_overline":
            return (0.50, 0.50, 0.50, 1.00)
        elif color_name == "plot_lines":
            return (0.61, 0.61, 0.61, 1.00)
        elif color_name == "plot_lines_hovered":
            return (1.00, 0.43, 0.35, 1.00)
        elif color_name == "plot_histogram":
            return (0.90, 0.70, 0.00, 1.00)
        elif color_name == "plot_histogram_hovered":
            return (1.00, 0.60, 0.00, 1.00)
        elif color_name == "table_header_bg":
            return (0.19, 0.19, 0.20, 1.00)
        elif color_name == "table_border_strong":
            return (0.31, 0.31, 0.35, 1.00)
        elif color_name == "table_border_light":
            return (0.23, 0.23, 0.25, 1.00)
        elif color_name == "table_row_bg":
            return (0.00, 0.00, 0.00, 0.00)
        elif color_name == "table_row_bg_alt":
            return (1.00, 1.00, 1.00, 0.06)
        elif color_name == "text_link":
            return (0.26, 0.59, 0.98, 1.00)
        elif color_name == "text_selected_bg":
            return (0.26, 0.59, 0.98, 0.35)
        elif color_name == "drag_drop_target":
            return (1.00, 1.00, 0.00, 0.90)
        elif color_name == "nav_cursor":
            return (0.26, 0.59, 0.98, 1.00)
        elif color_name == "nav_windowing_highlight":
            return (1.00, 1.00, 1.00, 0.70)
        elif color_name == "nav_windowing_dim_bg":
            return (0.80, 0.80, 0.80, 0.20)
        elif color_name == "modal_window_dim_bg":
            return (0.80, 0.80, 0.80, 0.35)
        else:
            raise KeyError(f"Color {color_name} not found")

cdef class ThemeColorImPlot(baseThemeColor):
    """
    Theme color parameters that affect how ImPlot renders plots.
    All colors accept three formats:
    - unsigned (encodes a rgba little-endian)
    - (r, g, b, a) with r, g, b, a as integers.
    - (r, g, b, a) with r, g, b, a as floats.

    When r, g, b, a are floats, they should be normalized
    between 0 and 1, while integers are between 0 and 255.
    If a is missing, it defaults to 255.

    Keyword Arguments:
        line: Plot line color. Auto - derived from text color
        fill: Plot fill color. Auto - derived from line color
        marker_outline: Plot marker outline color. Auto - derived from line color
        marker_fill: Plot marker fill color. Auto - derived from line color 
        error_bar: Error bar color. Auto - derived from Text color
        frame_bg: Plot frame background color. Auto - derived from frame_bg color
        plot_bg: Plot area background color. Auto - derived from window_bg color
        plot_border: Plot area border color. Auto - derived from border color
        legend_bg: Legend background color. Auto - derived from popup_bg color
        legend_border: Legend border color. Auto - derived from border color
        legend_text: Legend text color. Auto - derived from text color
        title_text: Plot title text color. Auto - derived from text color
        inlay_text: Color of text appearing inside plots. Auto - derived from text color
        axis_text: Axis text labels color. Auto - derived from text color
        axis_grid: Axis grid color. Auto - derived from text color with reduced alpha
        axis_tick: Axis tick marks color. Auto - derived from axis_grid color
        axis_bg: Background color of axis hover region. Auto - transparent
        axis_bg_hovered: Axis background color when hovered. Auto - derived from button_hovered color
        axis_bg_active: Axis background color when clicked. Auto - derived from button_active color
        selection: Box-selection color. Default: (1.00, 1.00, 0.00, 1.00)
        crosshairs: Crosshairs color. Auto - derived from plot_border color
    """
    def __cinit__(self):
        self._names = [
            "line",
            "fill",
            "marker_outline",
            "marker_fill",
            "error_bar",
            "frame_bg",
            "plot_bg",
            "plot_border",
            "legend_bg",
            "legend_border",
            "legend_text",
            "title_text",
            "inlay_text",
            "axis_text",
            "axis_grid",
            "axis_tick",
            "axis_bg",
            "axis_bg_hovered",
            "axis_bg_active",
            "selection",
            "crosshairs"
        ]

    @property
    def line(self):
        """Plot line color.
        Default: Auto - derived from text color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.LINE)

    @line.setter
    def line(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.LINE, value)

    @property
    def fill(self):
        """Plot fill color.
        Default: Auto - derived from line color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.FILL)

    @fill.setter
    def fill(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.FILL, value)

    @property
    def marker_outline(self):
        """Plot marker outline color.
        Default: Auto - derived from line color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.MARKER_OUTLINE)

    @marker_outline.setter
    def marker_outline(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.MARKER_OUTLINE, value)

    @property
    def marker_fill(self):
        """Plot marker fill color.
        Default: Auto - derived from line color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.MARKER_FILL)

    @marker_fill.setter
    def marker_fill(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.MARKER_FILL, value)

    @property
    def error_bar(self):
        """Error bar color.
        Default: Auto - derived from text color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.ERROR_BAR)

    @error_bar.setter
    def error_bar(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.ERROR_BAR, value)

    @property
    def frame_bg(self):
        """Plot frame background color.
        Default: Auto - derived from frame_bg color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.FRAME_BG)

    @frame_bg.setter
    def frame_bg(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.FRAME_BG, value)

    @property
    def plot_bg(self):
        """Plot area background color.
        Default: Auto - derived from window_bg color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.PLOT_BG)

    @plot_bg.setter
    def plot_bg(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.PLOT_BG, value)

    @property
    def plot_border(self):
        """Plot area border color.
        Default: Auto - derived from border color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.PLOT_BORDER)

    @plot_border.setter
    def plot_border(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.PLOT_BORDER, value)

    @property
    def legend_bg(self):
        """Legend background color.
        Default: Auto - derived from popup_bg color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.LEGEND_BG)

    @legend_bg.setter
    def legend_bg(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.LEGEND_BG, value)

    @property
    def legend_border(self):
        """Legend border color.
        Default: Auto - derived from border color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.LEGEND_BORDER)

    @legend_border.setter
    def legend_border(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.LEGEND_BORDER, value)

    @property
    def legend_text(self):
        """Legend text color.
        Default: Auto - derived from text color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.LEGEND_TEXT)

    @legend_text.setter
    def legend_text(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.LEGEND_TEXT, value)

    @property
    def title_text(self):
        """Plot title text color.
        Default: Auto - derived from text color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.TITLE_TEXT)

    @title_text.setter
    def title_text(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.TITLE_TEXT, value)

    @property
    def inlay_text(self):
        """Color of text appearing inside of plots.
        Default: Auto - derived from Text color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.INLAY_TEXT)

    @inlay_text.setter
    def inlay_text(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.INLAY_TEXT, value)

    @property
    def axis_text(self):
        """Axis text labels color.
        Default: Auto - derived from text color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.AXIS_TEXT)

    @axis_text.setter
    def axis_text(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.AXIS_TEXT, value)

    @property
    def axis_grid(self):
        """Axis grid color.
        Default: Auto - derived from text color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.AXIS_GRID)

    @axis_grid.setter
    def axis_grid(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.AXIS_GRID, value)

    @property
    def axis_tick(self):
        """Axis tick marks color.
        Default: Auto - derived from axis_grid color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.AXIS_TICK)

    @axis_tick.setter
    def axis_tick(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.AXIS_TICK, value)

    @property
    def axis_bg(self):
        """Background color of axis hover region.
        Default: transparent"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.AXIS_BG)

    @axis_bg.setter
    def axis_bg(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.AXIS_BG, value)

    @property
    def axis_bg_hovered(self):
        """Axis background color when hovered.
        Default: Auto - derived from button_hovered color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.AXIS_BG_HOVERED)

    @axis_bg_hovered.setter
    def axis_bg_hovered(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.AXIS_BG_HOVERED, value)

    @property
    def axis_bg_active(self):
        """Axis background color when clicked.
        Default: Auto - derived from button_active color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.AXIS_BG_ACTIVE)

    @axis_bg_active.setter
    def axis_bg_active(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.AXIS_BG_ACTIVE, value)

    @property
    def selection(self):
        """Box-selection color.
        Default: (1.00, 1.00, 0.00, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.SELECTION)

    @selection.setter
    def selection(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.SELECTION, value)

    @property
    def crosshairs(self):
        """Crosshairs color.
        Default: Auto - derived from plot_border color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.CROSSHAIRS)

    @crosshairs.setter
    def crosshairs(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.CROSSHAIRS, value)

    @classmethod
    def get_default(cls, str color_name):
        """Get the default color value for the given color name."""
        if color_name == "line":
            return ThemeColorImGui.get_default("text")
        elif color_name == "fill":
            return cls.get_default("line")
        elif color_name == "marker_outline":
            return cls.get_default("line")
        elif color_name == "marker_fill":
            return cls.get_default("line")
        elif color_name == "error_bar":
            return ThemeColorImGui.get_default("text")
        elif color_name == "frame_bg":
            return ThemeColorImGui.get_default("frame_bg")
        elif color_name == "plot_bg":
            return ThemeColorImGui.get_default("window_bg")
        elif color_name == "plot_border":
            return ThemeColorImGui.get_default("border")
        elif color_name == "legend_bg":
            return ThemeColorImGui.get_default("popup_bg")
        elif color_name == "legend_border":
            return ThemeColorImGui.get_default("border")
        elif color_name == "legend_text":
            return ThemeColorImGui.get_default("text")
        elif color_name == "title_text":
            return ThemeColorImGui.get_default("text")
        elif color_name == "inlay_text":
            return ThemeColorImGui.get_default("text")
        elif color_name == "axis_text":
            return ThemeColorImGui.get_default("text")
        elif color_name == "axis_grid":
            (r, g, b, a) = ThemeColorImGui.get_default("text")
            return (r, g, b, 0.25 * a)
        elif color_name == "axis_tick":
            return cls.get_default("axis_grid")
        elif color_name == "axis_bg":
            return (0.00, 0.00, 0.00, 0.00)  # Transparent
        elif color_name == "axis_bg_hovered":
            return ThemeColorImGui.get_default("button_hovered")
        elif color_name == "axis_bg_active":
            return ThemeColorImGui.get_default("button_active")
        elif color_name == "selection":
            return (1.00, 1.00, 0.00, 1.00)
        elif color_name == "crosshairs":
            return cls.get_default("plot_border")
        else:
            raise KeyError(f"Color {color_name} not found")

    cdef void push(self) noexcept nogil:
        self.mutex.lock()
        if not(self._enabled):
            self._last_push_size.push_back(0)
            return
        cdef pair[int32_t, uint32_t] element_content
        for element_content in dereference(self._index_to_value):
            # Note: imgui seems to convert U32 for this. Maybe use float4
            implot.PushStyleColor(<implot.ImPlotCol>element_content.first, <imgui.ImU32>element_content.second)
        self._last_push_size.push_back(<int>self._index_to_value.size())

    cdef void pop(self) noexcept nogil:
        cdef int32_t count = self._last_push_size.back()
        self._last_push_size.pop_back()
        if count > 0:
            implot.PopStyleColor(count)
        self.mutex.unlock()


cdef class baseThemeStyle(baseTheme):
    def __cinit__(self):
        self._dpi = -1.
        self._dpi_scaling = True
        self._index_to_value = new unordered_map[int32_t, theme_value_info]()
        self._index_to_value_for_dpi = new unordered_map[int32_t, theme_value_info]()

    def __dealloc__(self):
        if self._index_to_value != NULL:
            del self._index_to_value
        if self._index_to_value_for_dpi != NULL:
            del self._index_to_value_for_dpi

    @property
    def no_scaling(self):
        """
        boolean. Defaults to False.
        If set, disables the automated scaling to the dpi
        scale value for this theme
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return not(self._dpi_scaling)

    @no_scaling.setter
    def no_scaling(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._dpi_scaling = not(value)

    @property
    def no_rounding(self):
        """
        boolean. Defaults to False.
        If set, disables rounding (after scaling) to the
        closest integer the parameters. The rounding is only
        applied to parameters which impact item positioning
        in a way that would prevent a pixel perfect result.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return not(self._round_after_scale)

    @no_rounding.setter
    def no_rounding(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._round_after_scale = not(value)

    @cython.annotation_typing(False)
    def __getitem__(self, key: str | int) -> object:
        """Get style by string name or numeric index"""
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef int32_t style_index
        if isinstance(key, str):
            return getattr(self, key)
        elif isinstance(key, int):
            style_index = key
            if style_index < 0 or style_index >= len(self._names):
                raise KeyError("No element of index %d" % key)
            return getattr(self, self._names[style_index])
        raise TypeError("%s is an invalid index type" % str(type(key)))

    @cython.annotation_typing(False)
    def __setitem__(self, key: str | int, value: object) -> None:
        """Set style by string name or numeric index"""
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef int32_t style_index
        if isinstance(key, str):
            setattr(self, key, value)
        elif isinstance(key, int):
            style_index = key
            if style_index < 0 or style_index >= len(self._names):
                raise KeyError("No element of index %d" % key)
            setattr(self, self._names[style_index], value)
        else:
            raise TypeError("%s is an invalid index type" % str(type(key)))

    @cython.annotation_typing(False)
    def __iter__(self) -> list[tuple[str, object]]:
        """Iterate over the theme style values as (name, value) pairs."""
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list result = []
        cdef pair[int32_t, theme_value_info] element_content
        for element_content in dereference(self._index_to_value):
            name = self._names[element_content.first]
            if element_content.second.value_type == theme_value_types.t_int:
                result.append((name, element_content.second.value.value_int))
            elif element_content.second.value_type == theme_value_types.t_float:
                result.append((name, element_content.second.value.value_float))
            elif element_content.second.value_type == theme_value_types.t_float2:
                if element_content.second.float2_mask == theme_value_float2_mask.t_left:
                    result.append((name, (element_content.second.value.value_float2[0], None)))
                elif element_content.second.float2_mask == theme_value_float2_mask.t_right:
                    result.append((name, (None, element_content.second.value.value_float2[1])))
                else: # t_full
                    result.append((name, element_content.second.value.value_float2))
            elif element_content.second.value_type == theme_value_types.t_u32:
                result.append((name, element_content.second.value.value_u32))
        return iter(result)

    cdef object _common_getter(self, int32_t index, theme_value_types type):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef unordered_map[int32_t, theme_value_info].iterator element_content = self._index_to_value.find(index)
        if element_content == self._index_to_value.end():
            # None: default
            return None
        cdef theme_value_info value = dereference(element_content).second
        if value.value_type == theme_value_types.t_int:
            return value.value.value_int
        elif value.value_type == theme_value_types.t_float:
            return value.value.value_float
        elif value.value_type == theme_value_types.t_float2:
            if value.float2_mask == theme_value_float2_mask.t_left:
                return (value.value.value_float2[0], None)
            elif value.float2_mask == theme_value_float2_mask.t_right:
                return (None, value.value.value_float2[1])
            else:
                return value.value.value_float2 # t_full
        elif value.value_type == theme_value_types.t_u32:
            return value.value.value_u32
        return None

    cdef void _common_setter(self, int32_t index, theme_value_types type, bint should_scale, bint should_round, py_value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if py_value is None:
            # Delete the value
            self._index_to_value.erase(index)
            self._dpi = -1 # regenerate the scaled dpi array
            return
        cdef theme_value_info value
        if type == theme_value_types.t_float:
            value.value.value_float = float(py_value)
        elif type == theme_value_types.t_float2:
            if PySequence_Check(py_value) == 0 or len(py_value) != 2:
                raise ValueError(f"Expected a tuple, got {py_value}")
            left = py_value[0]
            right = py_value[1]
            if left is None and right is None:
                # Or maybe behave as if py_value is None
                raise ValueError("Both values in the tuple cannot be None")
            elif left is None:
                value.float2_mask = theme_value_float2_mask.t_right
                value.value.value_float2[0] = 0.
                value.value.value_float2[1] = float(right)
            elif right is None:
                value.float2_mask = theme_value_float2_mask.t_left
                value.value.value_float2[0] = float(left)
                value.value.value_float2[1] = 0.
            else:
                value.float2_mask = theme_value_float2_mask.t_full
                value.value.value_float2[0] = float(left)
                value.value.value_float2[1] = float(right)
        elif type == theme_value_types.t_int:
            value.value.value_int = int(py_value)
        elif type == theme_value_types.t_u32:
            value.value.value_u32 = <unsigned>int(py_value)
        value.value_type = type
        value.should_scale = should_scale
        value.should_round = should_round
        dereference(self._index_to_value)[index] = value
        self._dpi = -1 # regenerate the scaled dpi array

    cdef void _compute_for_dpi(self) noexcept nogil:
        cdef float dpi = self.context.viewport.global_scale
        cdef bint should_scale = self._dpi_scaling
        cdef bint should_round = self._round_after_scale
        self._dpi = dpi
        self._index_to_value_for_dpi.clear()
        cdef pair[int32_t, theme_value_info] element_content
        for element_content in dereference(self._index_to_value):
            if should_scale and element_content.second.should_scale:
                if element_content.second.value_type == theme_value_types.t_int:
                    element_content.second.value.value_int = <int>(round(element_content.second.value.value_int * dpi))
                elif element_content.second.value_type == theme_value_types.t_float:
                    element_content.second.value.value_float *= dpi
                elif element_content.second.value_type == theme_value_types.t_float2:
                    element_content.second.value.value_float2[0] *= dpi
                    element_content.second.value.value_float2[1] *= dpi
                elif element_content.second.value_type == theme_value_types.t_u32:
                    element_content.second.value.value_u32 = <unsigned>(round(element_content.second.value.value_int * dpi))
            if should_round and element_content.second.should_round:
                if element_content.second.value_type == theme_value_types.t_float:
                    element_content.second.value.value_float = round(element_content.second.value.value_float)
                elif element_content.second.value_type == theme_value_types.t_float2:
                    element_content.second.value.value_float2[0] = round(element_content.second.value.value_float2[0])
                    element_content.second.value.value_float2[1] = round(element_content.second.value.value_float2[1])
            self._index_to_value_for_dpi.insert(element_content)


cdef class ThemeStyleImGui(baseThemeStyle):
    def __cinit__(self):
        self._names = [
            "alpha",                    # float     Alpha
            "disabled_alpha",            # float     DisabledAlpha
            "window_padding",            # ImVec2    WindowPadding
            "window_rounding",           # float     WindowRounding
            "window_border_size",         # float     WindowBorderSize
            "window_min_size",           # ImVec2    WindowMinSize
            "window_title_align",         # ImVec2    WindowTitleAlign
            "child_rounding",            # float     ChildRounding
            "child_border_size",          # float     ChildBorderSize
            "popup_rounding",            # float     PopupRounding
            "popup_border_size",          # float     PopupBorderSize
            "frame_padding",             # ImVec2    FramePadding
            "frame_rounding",            # float     FrameRounding
            "frame_border_size",          # float     FrameBorderSize
            "item_spacing",              # ImVec2    ItemSpacing
            "item_inner_spacing",         # ImVec2    ItemInnerSpacing
            "indent_spacing",            # float     IndentSpacing
            "cell_padding",              # ImVec2    CellPadding
            "scrollbar_size",            # float     ScrollbarSize
            "scrollbar_rounding",        # float     ScrollbarRounding
            "grab_min_size",              # float     GrabMinSize
            "grab_rounding",             # float     GrabRounding
            "tab_rounding",              # float     TabRounding
            "tab_border_size",            # float     TabBorderSize
            "tab_bar_border_size",         # float     TabBarBorderSize
            "tab_bar_overline_size",       # float     TabBarOverlineSize
            "table_angled_headers_angle",  # float     TableAngledHeadersAngle
            "table_angled_headers_text_align",# ImVec2  TableAngledHeadersTextAlign
            "button_text_align",          # ImVec2    ButtonTextAlign
            "selectable_text_align",      # ImVec2    SelectableTextAlign
            "separator_text_border_size",  # float     SeparatorTextBorderSize
            "separator_text_align",       # ImVec2    SeparatorTextAlign
            "separator_text_padding",     # ImVec2    SeparatorTextPadding
        ]

    @property
    def alpha(self):
        """
        Global alpha applied to everything in Dear ImGui.

        The value is in the range [0, 1]. Defaults to 1.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.ALPHA, theme_value_types.t_float)

    @alpha.setter
    def alpha(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.ALPHA, theme_value_types.t_float, False, False, value)

    @property
    def disabled_alpha(self):
        """
        Unused currently.

        The value is in the range [0, 1]. Defaults to 0.6
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.DISABLED_ALPHA, theme_value_types.t_float)

    @disabled_alpha.setter
    def disabled_alpha(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.DISABLED_ALPHA, theme_value_types.t_float, False, False, value)

    @property
    def window_padding(self):
        """
        Padding within a window.

        The value is a pair of float (dx, dy). Defaults to (8, 8)
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.WINDOW_PADDING, theme_value_types.t_float2)

    @window_padding.setter
    def window_padding(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.WINDOW_PADDING, theme_value_types.t_float2, True, True, value)

    @property
    def window_rounding(self):
        """
        Radius of window corners rounding. Set to 0.0 to have rectangular windows. Large values tend to lead to variety of artifacts and are not recommended.

        The value is a float. Defaults to 0.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.WINDOW_ROUNDING, theme_value_types.t_float)

    @window_rounding.setter
    def window_rounding(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.WINDOW_ROUNDING, theme_value_types.t_float, True, False, value)

    @property
    def window_border_size(self):
        """
        Thickness of border around windows. Generally set to 0.0 or 1.0f. Other values not well tested.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.WINDOW_BORDER_SIZE, theme_value_types.t_float)

    @window_border_size.setter
    def window_border_size(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.WINDOW_BORDER_SIZE, theme_value_types.t_float, True, True, value)

    @property
    def window_min_size(self):
        """
        Minimum window size

        The value is a pair of float (dx, dy). Defaults to (32, 32)
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.WINDOW_MIN_SIZE, theme_value_types.t_float2)

    @window_min_size.setter
    def window_min_size(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.WINDOW_MIN_SIZE, theme_value_types.t_float2, True, True, value)

    @property
    def window_title_align(self):
        """
        Alignment for window title bar text in percentages

        The value is a pair of float (dx, dy). Defaults to (0., 0.5), which means left-aligned, vertical centering on the row
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.WINDOW_TITLE_ALIGN, theme_value_types.t_float2)

    @window_title_align.setter
    def window_title_align(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.WINDOW_TITLE_ALIGN, theme_value_types.t_float2, False, False, value)

    @property
    def child_rounding(self):
        """
        Radius of child window corners rounding. Set to 0.0 to have rectangular child windows.

        The value is a float. Defaults to 0.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.CHILD_ROUNDING, theme_value_types.t_float)

    @child_rounding.setter
    def child_rounding(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.CHILD_ROUNDING, theme_value_types.t_float, True, False, value)

    @property
    def child_border_size(self):
        """
        Thickness of border around child windows. Generally set to 0.0f or 1.0f. Other values not well tested.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.CHILD_BORDER_SIZE, theme_value_types.t_float)

    @child_border_size.setter
    def child_border_size(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.CHILD_BORDER_SIZE, theme_value_types.t_float, True, True, value)

    @property
    def popup_rounding(self):
        """
        Radius of popup or tooltip window corners rounding. Set to 0.0 to have rectangular popup or tooltip windows.

        The value is a float. Defaults to 0.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.POPUP_ROUNDING, theme_value_types.t_float)

    @popup_rounding.setter
    def popup_rounding(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.POPUP_ROUNDING, theme_value_types.t_float, True, False, value)

    @property
    def popup_border_size(self):
        """
        Thickness of border around popup or tooltip windows. Generally set to 0.0f or 1.0f. Other values not well tested.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.POPUP_BORDER_SIZE, theme_value_types.t_float)

    @popup_border_size.setter
    def popup_border_size(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.POPUP_BORDER_SIZE, theme_value_types.t_float, True, True, value)

    @property
    def frame_padding(self):
        """
        Padding within a framed rectangle (used by most widgets)

        The value is a pair of floats. Defaults to (4,3).
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.FRAME_PADDING, theme_value_types.t_float2)

    @frame_padding.setter
    def frame_padding(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.FRAME_PADDING, theme_value_types.t_float2, True, True, value)

    @property
    def frame_rounding(self):
        """
        Radius of frame corners rounding. Set to 0.0 to have rectangular frame (most widgets).

        The value is a float. Defaults to 0.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.FRAME_ROUNDING, theme_value_types.t_float)

    @frame_rounding.setter
    def frame_rounding(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.FRAME_ROUNDING, theme_value_types.t_float, True, False, value)

    @property
    def frame_border_size(self):
        """
        Thickness of border around frames (most widgets). Generally set to 0.0f or 1.0f. Other values not well tested.

        The value is a float. Defaults to 0.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.FRAME_BORDER_SIZE, theme_value_types.t_float)

    @frame_border_size.setter
    def frame_border_size(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.FRAME_BORDER_SIZE, theme_value_types.t_float, True, True, value)

    @property
    def item_spacing(self):
        """
        Horizontal and vertical spacing between widgets/lines.

        The value is a pair of floats. Defaults to (8, 4).
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.ITEM_SPACING, theme_value_types.t_float2)

    @item_spacing.setter
    def item_spacing(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.ITEM_SPACING, theme_value_types.t_float2, True, True, value)

    @property
    def item_inner_spacing(self):
        """
        Horizontal and vertical spacing between elements inside of a composed widget.

        The value is a pair of floats. Defaults to (4, 4).
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.ITEM_INNER_SPACING, theme_value_types.t_float2)

    @item_inner_spacing.setter
    def item_inner_spacing(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.ITEM_INNER_SPACING, theme_value_types.t_float2, True, True, value)

    @property
    def indent_spacing(self):
        """
        Default horizontal spacing for indentations. For instance when entering a tree node.
        A good value is Generally == (FontSize + FramePadding.x*2).

        The value is a float. Defaults to 21.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.INDENT_SPACING, theme_value_types.t_float)

    @indent_spacing.setter
    def indent_spacing(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.INDENT_SPACING, theme_value_types.t_float, True, True, value)

    @property
    def cell_padding(self):
        """
        Tables: padding between cells.
        The x padding is applied for the whole Table,
        while y can be different for every row.

        The value is a pair of floats. Defaults to (4, 2).
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.CELL_PADDING, theme_value_types.t_float2)

    @cell_padding.setter
    def cell_padding(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.CELL_PADDING, theme_value_types.t_float2, True, True, value)

    @property
    def scrollbar_size(self):
        """
        Width of the vertical scrollbar, Height of the horizontal scrollbar

        The value is a float. Defaults to 14.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.SCROLLBAR_SIZE, theme_value_types.t_float)

    @scrollbar_size.setter
    def scrollbar_size(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.SCROLLBAR_SIZE, theme_value_types.t_float, True, True, value)

    @property
    def scrollbar_rounding(self):
        """
        Radius of grab corners rounding for scrollbar.

        The value is a float. Defaults to 9.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.SCROLLBAR_ROUNDING, theme_value_types.t_float)

    @scrollbar_rounding.setter
    def scrollbar_rounding(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.SCROLLBAR_ROUNDING, theme_value_types.t_float, True, True, value)

    @property
    def grab_min_size(self):
        """
        Minimum width/height of a grab box for slider/scrollbar.

        The value is a float. Defaults to 12.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.GRAB_MIN_SIZE, theme_value_types.t_float)

    @grab_min_size.setter
    def grab_min_size(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.GRAB_MIN_SIZE, theme_value_types.t_float, True, True, value)

    @property
    def grab_rounding(self):
        """
        Radius of grabs corners rounding. Set to 0.0f to have rectangular slider grabs.

        The value is a float. Defaults to 0.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.GRAB_ROUNDING, theme_value_types.t_float)

    @grab_rounding.setter
    def grab_rounding(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.GRAB_ROUNDING, theme_value_types.t_float, True, False, value)

    @property
    def tab_rounding(self):
        """
        Radius of upper corners of a tab. Set to 0.0f to have rectangular tabs.

        The value is a float. Defaults to 4.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.TAB_ROUNDING, theme_value_types.t_float)

    @tab_rounding.setter
    def tab_rounding(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.TAB_ROUNDING, theme_value_types.t_float, True, False, value)

    @property
    def tab_border_size(self):
        """
        Thickness of borders around tabs.

        The value is a float. Defaults to 0.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.TAB_BORDER_SIZE, theme_value_types.t_float)

    @tab_border_size.setter
    def tab_border_size(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.TAB_BORDER_SIZE, theme_value_types.t_float, True, True, value)

    @property
    def tab_bar_border_size(self):
        """
        Thickness of tab-bar separator, which takes on the tab active color to denote focus.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.TAB_BAR_BORDER_SIZE, theme_value_types.t_float)

    @tab_bar_border_size.setter
    def tab_bar_border_size(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.TAB_BAR_BORDER_SIZE, theme_value_types.t_float, True, True, value)

    @property
    def tab_bar_overline_size(self):
        """
        Thickness of tab-bar overline, which highlights the selected tab-bar.

        The value is a float. Defaults to 2.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.TAB_BAR_OVERLINE_SIZE, theme_value_types.t_float)

    @tab_bar_overline_size.setter
    def tab_bar_overline_size(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.TAB_BAR_OVERLINE_SIZE, theme_value_types.t_float, True, True, value)

    @property
    def table_angled_headers_angle(self):
        """
        Tables: Angle of angled headers (supported values range from -50 degrees to +50 degrees).

        The value is a float. Defaults to 35.0f * (IM_PI / 180.0f).
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.TABLE_ANGLED_HEADERS_ANGLE, theme_value_types.t_float)

    @table_angled_headers_angle.setter
    def table_angled_headers_angle(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.TABLE_ANGLED_HEADERS_ANGLE, theme_value_types.t_float, False, False, value)

    @property
    def table_angled_headers_text_align(self):
        """
        Tables: Alignment (percentages) of angled headers within the cell
    
        The value is a pair of floats. Defaults to (0.5, 0.), i.e. top-centered
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.TABLE_ANGLED_HEADERS_TEXT_ALIGN, theme_value_types.t_float2)

    @table_angled_headers_text_align.setter
    def table_angled_headers_text_align(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.TABLE_ANGLED_HEADERS_TEXT_ALIGN, theme_value_types.t_float2, False, False, value)

    @property
    def button_text_align(self):
        """
        Alignment of button text when button is larger than text.
    
        The value is a pair of floats. Defaults to (0.5, 0.5), i.e. centered
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.BUTTON_TEXT_ALIGN, theme_value_types.t_float2)

    @button_text_align.setter
    def button_text_align(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.BUTTON_TEXT_ALIGN, theme_value_types.t_float2, False, False, value)

    @property
    def selectable_text_align(self):
        """
        Alignment of selectable text (in percentages).
    
        The value is a pair of floats. Defaults to (0., 0.), i.e. top-left. It is advised to keep the default.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.SELECTABLE_TEXT_ALIGN, theme_value_types.t_float2)

    @selectable_text_align.setter
    def selectable_text_align(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.SELECTABLE_TEXT_ALIGN, theme_value_types.t_float2, False, False, value)

    @property
    def separator_text_border_size(self):
        """
        Thickness of border in Separator() text.
    
        The value is a float. Defaults to 3.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.SEPARATOR_TEXT_BORDER_SIZE, theme_value_types.t_float)

    @separator_text_border_size.setter
    def separator_text_border_size(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.SEPARATOR_TEXT_BORDER_SIZE, theme_value_types.t_float, True, True, value)

    @property
    def separator_text_align(self):
        """
        Alignment of text within the separator in percentages.
    
        The value is a pair of floats. Defaults to (0., 0.5), i.e. left-centered
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.SEPARATOR_TEXT_ALIGN, theme_value_types.t_float2)

    @separator_text_align.setter
    def separator_text_align(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.SEPARATOR_TEXT_ALIGN, theme_value_types.t_float2, False, False, value)

    @property
    def separator_text_padding(self):
        """
        Horizontal offset of text from each edge of the separator + spacing on other axis. Generally small values. .y is recommended to be == FramePadding.y.
    
        The value is a pair of floats. Defaults to (20., 3.).
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.SEPARATOR_TEXT_PADDING, theme_value_types.t_float2)

    @separator_text_padding.setter
    def separator_text_padding(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.SEPARATOR_TEXT_PADDING, theme_value_types.t_float2, True, True, value)

    @classmethod
    def get_default(cls, str style_name):
        """Get the default style value for the given style name."""
        if style_name == "alpha":
            return 1.0
        elif style_name == "disabled_alpha":
            return 0.6
        elif style_name == "window_padding":
            return (8.0, 8.0)
        elif style_name == "window_rounding":
            return 0.0
        elif style_name == "window_border_size":
            return 1.0
        elif style_name == "window_min_size":
            return (32.0, 32.0)
        elif style_name == "window_title_align":
            return (0.0, 0.5)
        elif style_name == "child_rounding":
            return 0.0
        elif style_name == "child_border_size":
            return 1.0
        elif style_name == "popup_rounding":
            return 0.0
        elif style_name == "popup_border_size":
            return 1.0
        elif style_name == "frame_padding":
            return (4.0, 3.0)
        elif style_name == "frame_rounding":
            return 0.0
        elif style_name == "frame_border_size":
            return 0.0
        elif style_name == "item_spacing":
            return (8.0, 4.0)
        elif style_name == "item_inner_spacing":
            return (4.0, 4.0)
        elif style_name == "indent_spacing":
            return 21.0
        elif style_name == "cell_padding":
            return (4.0, 2.0)
        elif style_name == "scrollbar_size":
            return 14.0
        elif style_name == "scrollbar_rounding":
            return 9.0
        elif style_name == "grab_min_size":
            return 12.0
        elif style_name == "grab_rounding":
            return 0.0
        elif style_name == "tab_rounding":
            return 4.0
        elif style_name == "tab_border_size":
            return 0.0
        elif style_name == "tab_bar_border_size":
            return 1.0
        elif style_name == "tab_bar_overline_size":
            return 2.0
        elif style_name == "table_angled_headers_angle":
            return 35.0 * (3.141592653589793 / 180.0)
        elif style_name == "table_angled_headers_text_align":
            return (0.5, 0.0)
        elif style_name == "button_text_align":
            return (0.5, 0.5)
        elif style_name == "selectable_text_align":
            return (0.0, 0.0)
        elif style_name == "separator_text_border_size":
            return 3.0
        elif style_name == "separator_text_align":
            return (0.0, 0.5)
        elif style_name == "separator_text_padding":
            return (20.0, 3.0)
        else:
            raise KeyError(f"Style {style_name} not found")

    cdef void push(self) noexcept nogil:
        self.mutex.lock()
        if not(self._enabled):
            self._last_push_size.push_back(0)
            return
        if self.context.viewport.global_scale != self._dpi:
            baseThemeStyle._compute_for_dpi(self)
        cdef pair[int32_t, theme_value_info] element_content
        for element_content in dereference(self._index_to_value_for_dpi):
            if element_content.second.value_type == theme_value_types.t_float:
                imgui.PushStyleVar(element_content.first, element_content.second.value.value_float)
            else: # t_float2
                if element_content.second.float2_mask == theme_value_float2_mask.t_left:
                    imgui.PushStyleVarX(element_content.first, element_content.second.value.value_float2[0])
                elif element_content.second.float2_mask == theme_value_float2_mask.t_right:
                    imgui.PushStyleVarY(element_content.first, element_content.second.value.value_float2[1])
                else:
                    imgui_PushStyleVar2(element_content.first, element_content.second.value.value_float2)
        self._last_push_size.push_back(<int>self._index_to_value_for_dpi.size())

    cdef void pop(self) noexcept nogil:
        cdef int32_t count = self._last_push_size.back()
        self._last_push_size.pop_back()
        if count > 0:
            imgui.PopStyleVar(count)
        self.mutex.unlock()


cdef class ThemeStyleImPlot(baseThemeStyle):
    def __cinit__(self):
        self._names = [
            "line_weight",         # float,  plot item line weight in pixels
            "marker",             # int,    marker specification
            "marker_size",         # float,  marker size in pixels (roughly the marker's "radius")
            "marker_weight",       # float,  plot outline weight of markers in pixels
            "fill_alpha",          # float,  alpha modifier applied to all plot item fills
            "error_bar_size",       # float,  error bar whisker width in pixels
            "error_bar_weight",     # float,  error bar whisker weight in pixels
            "digital_bit_height",   # float,  digital channels bit height (at 1) in pixels
            "digital_bit_gap",      # float,  digital channels bit padding gap in pixels
            "plot_border_size",     # float,  thickness of border around plot area
            "minor_alpha",         # float,  alpha multiplier applied to minor axis grid lines
            "major_tick_len",       # ImVec2, major tick lengths for X and Y axes
            "minor_tick_len",       # ImVec2, minor tick lengths for X and Y axes
            "major_tick_size",      # ImVec2, line thickness of major ticks
            "minor_tick_size",      # ImVec2, line thickness of minor ticks
            "major_grid_size",      # ImVec2, line thickness of major grid lines
            "minor_grid_size",      # ImVec2, line thickness of minor grid lines
            "plot_padding",        # ImVec2, padding between widget frame and plot area, labels, or outside legends (i.e. main padding)
            "label_padding",       # ImVec2, padding between axes labels, tick labels, and plot edge
            "legend_padding",      # ImVec2, legend padding from plot edges
            "legend_inner_padding", # ImVec2, legend inner padding from legend edges
            "legend_spacing",      # ImVec2, spacing between legend entries
            "mouse_pos_padding",    # ImVec2, padding between plot edge and interior info text
            "annotation_padding",  # ImVec2, text padding around annotation labels
            "fit_padding",         # ImVec2, additional fit padding as a percentage of the fit extents (e.g. ImVec2(0.1f,0.1f) adds 10% to the fit extents of X and Y)
            "plot_default_size",    # ImVec2, default size used when ImVec2(0,0) is passed to BeginPlot
            "plot_min_size",        # ImVec2, minimum size plot frame can be when shrunk
        ]

    @property
    def line_weight(self):
        """
        Plot item line weight in pixels.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.LINE_WEIGHT, theme_value_types.t_float)

    @line_weight.setter
    def line_weight(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.LINE_WEIGHT, theme_value_types.t_float, True, False, value)

    @property
    def marker(self):
        """
        Marker specification.

        The value is a PlotMarker. Defaults to PlotMarker.NONE.
        """
        value = baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.MARKER, theme_value_types.t_int)
        return None if value is None else make_PlotMarker(value)

    @marker.setter
    def marker(self, value):
        cdef int32_t value_int = int(make_PlotMarker(value))
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.MARKER, theme_value_types.t_int, False, False, value_int)

    @property
    def marker_size(self):
        """
        Marker size in pixels (roughly the marker's "radius").

        The value is a float. Defaults to 4.
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.MARKER_SIZE, theme_value_types.t_float)

    @marker_size.setter
    def marker_size(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.MARKER_SIZE, theme_value_types.t_float, True, False, value)

    @property
    def marker_weight(self):
        """
        Plot outline weight of markers in pixels.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.MARKER_WEIGHT, theme_value_types.t_float)

    @marker_weight.setter
    def marker_weight(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.MARKER_WEIGHT, theme_value_types.t_float, True, False, value)

    @property
    def fill_alpha(self):
        """
        Alpha modifier applied to all plot item fills.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.FILL_ALPHA, theme_value_types.t_float)

    @fill_alpha.setter
    def fill_alpha(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.FILL_ALPHA, theme_value_types.t_float, False, False, value)

    @property
    def error_bar_size(self):
        """
        Error bar whisker width in pixels.

        The value is a float. Defaults to 5.
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.ERROR_BAR_SIZE, theme_value_types.t_float)

    @error_bar_size.setter
    def error_bar_size(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.ERROR_BAR_SIZE, theme_value_types.t_float, True, True, value)

    @property
    def error_bar_weight(self):
        """
        Error bar whisker weight in pixels.

        The value is a float. Defaults to 1.5.
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.ERROR_BAR_WEIGHT, theme_value_types.t_float)

    @error_bar_weight.setter
    def error_bar_weight(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.ERROR_BAR_WEIGHT, theme_value_types.t_float, True, False, value)

    @property
    def digital_bit_height(self):
        """
        Digital channels bit height (at 1) in pixels.

        The value is a float. Defaults to 8.
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.DIGITAL_BIT_HEIGHT, theme_value_types.t_float)

    @digital_bit_height.setter
    def digital_bit_height(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.DIGITAL_BIT_HEIGHT, theme_value_types.t_float, True, True, value)

    @property
    def digital_bit_gap(self):
        """
        Digital channels bit padding gap in pixels.

        The value is a float. Defaults to 4.
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.DIGITAL_BIT_GAP, theme_value_types.t_float)

    @digital_bit_gap.setter
    def digital_bit_gap(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.DIGITAL_BIT_GAP, theme_value_types.t_float, True, True, value)

    @property
    def plot_border_size(self):
        """
        Thickness of border around plot area.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.PLOT_BORDER_SIZE, theme_value_types.t_float)

    @plot_border_size.setter
    def plot_border_size(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.PLOT_BORDER_SIZE, theme_value_types.t_float, True, True, value)

    @property
    def minor_alpha(self):
        """
        Alpha multiplier applied to minor axis grid lines.

        The value is a float. Defaults to 0.25.
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.MINOR_ALPHA, theme_value_types.t_float)

    @minor_alpha.setter
    def minor_alpha(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.MINOR_ALPHA, theme_value_types.t_float, False, False, value)

    @property
    def major_tick_len(self):
        """
        Major tick lengths for X and Y axes.

        The value is a pair of floats. Defaults to (10, 10).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.MAJOR_TICK_LEN, theme_value_types.t_float2)

    @major_tick_len.setter
    def major_tick_len(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.MAJOR_TICK_LEN, theme_value_types.t_float2, True, True, value)

    @property
    def minor_tick_len(self):
        """
        Minor tick lengths for X and Y axes.

        The value is a pair of floats. Defaults to (5, 5).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.MINOR_TICK_LEN, theme_value_types.t_float2)

    @minor_tick_len.setter
    def minor_tick_len(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.MINOR_TICK_LEN, theme_value_types.t_float2, True, True, value)

    @property
    def major_tick_size(self):
        """
        Line thickness of major ticks.

        The value is a pair of floats. Defaults to (1, 1).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.MAJOR_TICK_SIZE, theme_value_types.t_float2)

    @major_tick_size.setter
    def major_tick_size(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.MAJOR_TICK_SIZE, theme_value_types.t_float2, True, False, value)

    @property
    def minor_tick_size(self):
        """
        Line thickness of minor ticks.

        The value is a pair of floats. Defaults to (1, 1).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.MINOR_TICK_SIZE, theme_value_types.t_float2)

    @minor_tick_size.setter
    def minor_tick_size(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.MINOR_TICK_SIZE, theme_value_types.t_float2, True, False, value)

    @property
    def major_grid_size(self):
        """
        Line thickness of major grid lines.

        The value is a pair of floats. Defaults to (1, 1).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.MAJOR_GRID_SIZE, theme_value_types.t_float2)

    @major_grid_size.setter
    def major_grid_size(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.MAJOR_GRID_SIZE, theme_value_types.t_float2, True, False, value)

    @property
    def minor_grid_size(self):
        """
        Line thickness of minor grid lines.

        The value is a pair of floats. Defaults to (1, 1).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.MINOR_GRID_SIZE, theme_value_types.t_float2)

    @minor_grid_size.setter
    def minor_grid_size(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.MINOR_GRID_SIZE, theme_value_types.t_float2, True, False, value)

    @property
    def plot_padding(self):
        """
        Padding between widget frame and plot area, labels, or outside legends (i.e. main padding).

        The value is a pair of floats. Defaults to (10, 10).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.PLOT_PADDING, theme_value_types.t_float2)

    @plot_padding.setter
    def plot_padding(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.PLOT_PADDING, theme_value_types.t_float2, True, True, value)

    @property
    def label_padding(self):
        """
        Padding between axes labels, tick labels, and plot edge.

        The value is a pair of floats. Defaults to (5, 5).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.LABEL_PADDING, theme_value_types.t_float2)

    @label_padding.setter
    def label_padding(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.LABEL_PADDING, theme_value_types.t_float2, True, True, value)

    @property
    def legend_padding(self):
        """
        Legend padding from plot edges.

        The value is a pair of floats. Defaults to (10, 10).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.LEGEND_PADDING, theme_value_types.t_float2)

    @legend_padding.setter
    def legend_padding(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.LEGEND_PADDING, theme_value_types.t_float2, True, True, value)

    @property
    def legend_inner_padding(self):
        """
        Legend inner padding from legend edges.

        The value is a pair of floats. Defaults to (5, 5).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.LEGEND_INNER_PADDING, theme_value_types.t_float2)

    @legend_inner_padding.setter
    def legend_inner_padding(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.LEGEND_INNER_PADDING, theme_value_types.t_float2, True, True, value)

    @property
    def legend_spacing(self):
        """
        Spacing between legend entries.

        The value is a pair of floats. Defaults to (5, 0).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.LEGEND_SPACING, theme_value_types.t_float2)

    @legend_spacing.setter
    def legend_spacing(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.LEGEND_SPACING, theme_value_types.t_float2, True, True, value)

    @property
    def mouse_pos_padding(self):
        """
        Padding between plot edge and interior info text.

        The value is a pair of floats. Defaults to (10, 10).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.MOUSE_POS_PADDING, theme_value_types.t_float2)

    @mouse_pos_padding.setter
    def mouse_pos_padding(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.MOUSE_POS_PADDING, theme_value_types.t_float2, True, True, value)

    @property
    def annotation_padding(self):
        """
        Text padding around annotation labels.

        The value is a pair of floats. Defaults to (2, 2).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.ANNOTATION_PADDING, theme_value_types.t_float2)

    @annotation_padding.setter
    def annotation_padding(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.ANNOTATION_PADDING, theme_value_types.t_float2, True, True, value)

    @property
    def fit_padding(self):
        """
        Additional fit padding as a percentage of the fit extents (e.g. (0.1,0.1) adds 10% to the fit extents of X and Y).

        The value is a pair of floats. Defaults to (0, 0).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.FIT_PADDING, theme_value_types.t_float2)

    @fit_padding.setter
    def fit_padding(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.FIT_PADDING, theme_value_types.t_float2, False, False, value)

    @property
    def plot_default_size(self):
        """
        Default size used for plots

        The value is a pair of floats. Defaults to (400, 300).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.PLOT_DEFAULT_SIZE, theme_value_types.t_float2)

    @plot_default_size.setter
    def plot_default_size(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.PLOT_DEFAULT_SIZE, theme_value_types.t_float2, True, True, value)

    @property
    def plot_min_size(self):
        """
        Minimum size plot frame can be when shrunk.

        The value is a pair of floats. Defaults to (200, 150).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.PLOT_MIN_SIZE, theme_value_types.t_float2)

    @plot_min_size.setter
    def plot_min_size(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.PLOT_MIN_SIZE, theme_value_types.t_float2, True, True, value)

    @classmethod
    def get_default(cls, str style_name):
        """Get the default style value for the given style name."""
        if style_name == "line_weight":
            return 1.0
        elif style_name == "marker":
            return make_PlotMarker(<int32_t>PlotMarker.NONE)
        elif style_name == "marker_size":
            return 4.0
        elif style_name == "marker_weight":
            return 1.0
        elif style_name == "fill_alpha":
            return 1.0
        elif style_name == "error_bar_size":
            return 5.0
        elif style_name == "error_bar_weight":
            return 1.5
        elif style_name == "digital_bit_height":
            return 8.0
        elif style_name == "digital_bit_gap":
            return 4.0
        elif style_name == "plot_border_size":
            return 1.0
        elif style_name == "minor_alpha":
            return 0.25
        elif style_name == "major_tick_len":
            return (10.0, 10.0)
        elif style_name == "minor_tick_len":
            return (5.0, 5.0)
        elif style_name == "major_tick_size":
            return (1.0, 1.0)
        elif style_name == "minor_tick_size":
            return (1.0, 1.0)
        elif style_name == "major_grid_size":
            return (1.0, 1.0)
        elif style_name == "minor_grid_size":
            return (1.0, 1.0)
        elif style_name == "plot_padding":
            return (10.0, 10.0)
        elif style_name == "label_padding":
            return (5.0, 5.0)
        elif style_name == "legend_padding":
            return (10.0, 10.0)
        elif style_name == "legend_inner_padding":
            return (5.0, 5.0)
        elif style_name == "legend_spacing":
            return (5.0, 0.0)
        elif style_name == "mouse_pos_padding":
            return (10.0, 10.0)
        elif style_name == "annotation_padding":
            return (2.0, 2.0)
        elif style_name == "fit_padding":
            return (0.0, 0.0)
        elif style_name == "plot_default_size":
            return (400.0, 300.0)
        elif style_name == "plot_min_size":
            return (200.0, 150.0)
        else:
            raise KeyError(f"Style {style_name} not found")

    cdef void push(self) noexcept nogil:
        self.mutex.lock()
        if not(self._enabled):
            self._last_push_size.push_back(0)
            return
        if self.context.viewport.global_scale != self._dpi:
            baseThemeStyle._compute_for_dpi(self)
        cdef pair[int32_t, theme_value_info] element_content
        for element_content in dereference(self._index_to_value_for_dpi):
            if element_content.second.value_type == theme_value_types.t_float:
                implot.PushStyleVar(element_content.first, element_content.second.value.value_float)
            elif element_content.second.value_type == theme_value_types.t_int:
                implot.PushStyleVar(element_content.first, element_content.second.value.value_int)
            else: # t_float2
                if element_content.second.float2_mask == theme_value_float2_mask.t_left:
                    implot.PushStyleVarX(element_content.first, element_content.second.value.value_float2[0])
                elif element_content.second.float2_mask == theme_value_float2_mask.t_right:
                    implot.PushStyleVarY(element_content.first, element_content.second.value.value_float2[1])
                else:
                    implot_PushStyleVar2(element_content.first, element_content.second.value.value_float2)
        self._last_push_size.push_back(<int>self._index_to_value_for_dpi.size())

    cdef void pop(self) noexcept nogil:
        cdef int32_t count = self._last_push_size.back()
        self._last_push_size.pop_back()
        if count > 0:
            implot.PopStyleVar(count)
        self.mutex.unlock()


cdef class ThemeList(baseTheme):
    """
    A set of base theme elements to apply when we render an item.
    Warning: it is bad practice to bind a theme to every item, and
    is not free on CPU. Instead set the theme as high as possible in
    the rendering hierarchy, and only change locally reduced sets
    of theme elements if needed.

    Contains theme styles and colors.
    Can contain a theme list.
    Can be bound to items.

    WARNING: if you bind a theme element to an item,
    and that theme element belongs to a theme list,
    the siblings before the theme element will get
    applied as well.
    """
    def __cinit__(self):
        self.can_have_theme_child = True

    cdef void push(self) noexcept nogil:
        self.mutex.lock()
        if self._enabled:
            push_theme_children(self)

    cdef void pop(self) noexcept nogil:
        if self._enabled:
            pop_theme_children(self)
        self.mutex.unlock()


cdef object _search_theme_hierarchy(baseTheme theme, str name, type target_class):
    """
    Helper function that searches through a theme hierarchy for a value of the specified name and class.
    
    Args:
        theme: The theme node to search
        name: The name of the style/color property
        target_class: The target theme class type
        
    Returns:
        The theme value if found, otherwise None
    """
    cdef unique_lock[DCGMutex] m
    lock_gil_friendly(m, theme.mutex)

    # Check if this theme node is of the target class
    if isinstance(theme, target_class):
        try:
            value = getattr(theme, name)
            # Only return non-None values to allow for deeper searching
            if value is not None:
                return value
        except AttributeError:
            pass
    
    # If this theme can have children, process them in reverse order
    # (starting from last_theme_child as that's what would be applied last during rendering)
    cdef PyObject *child
    if theme.can_have_theme_child and theme.last_theme_child is not None:
        child = <PyObject*> theme.last_theme_child
        while child != NULL:
            value = _search_theme_hierarchy(<baseTheme>child, name, target_class)
            if value is not None:
                return value
            child = <PyObject *>(<baseItem>child).prev_sibling
    
    return None


def resolve_theme(item: baseItem, target_class: type, name: str) -> object:
    """
    Function that given a baseItem, a style/color name, and a target style or color class,
    resolves the theme value that is applied for this item. If it is not found for any parent,
    returns the default value.
    
    It can be used outside rendering to determine the style value
    that would be applied to an item during rendering.

    One use case is implementing a custom widget in Python and
    wanting to use the theme values.
    
    Args:
        item (baseItem): The item to resolve the theme for
        target_class (type): The theme class type (e.g. ThemeColorImGui, ThemeStyleImGui)
        name (str): The name of the style/color property to resolve
        
    Returns:
        The resolved theme value or the default value if not found
    
    Raises:
        TypeError: If target_class is not a subclass of baseTheme
        KeyError: If the style/color name is not found in the default values
    """
    if not issubclass(target_class, baseTheme):
        raise TypeError("target_class must be a subclass of baseTheme")
    
    # Walk down the parent tree from leaf to root to find the theme value
    cdef object current_value = None
    cdef baseItem parent_item = item

    while parent_item is not None:
        if getattr(parent_item, 'theme', None) is None:
            parent_item = parent_item.parent
            continue
        # Search the current item's theme for the value
        value = _search_theme_hierarchy(parent_item.theme, name, target_class)
        if value is not None:
            current_value = value
            break
        # Move to the parent item
        parent_item = parent_item.parent
    
    # If no value was found, return the default
    if current_value is None:
        try:
            return (<baseTheme>target_class).get_default(name)
        except KeyError:
            raise KeyError(f"Style/color '{name}' not found in default values")
        except AttributeError:
            raise TypeError(f"{target_class} does not have a get_default method")
    
    return current_value
