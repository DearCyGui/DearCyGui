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

    def __getitem__(self, key):
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

    def __setitem__(self, key, value):
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

    def __iter__(self):
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
        Text: Color for text rendering
        TextDisabled: Color for the text of disabled items
        WindowBg: Background of normal windows
        ChildBg:  Background of child windows
        PopupBg: Background of popups, menus, tooltips windows
        Border: Color of borders
        BorderShadow: Color of border shadows
        FrameBg: Background of checkbox, radio button, plot, slider, text input
        FrameBgHovered: Color of FrameBg when the item is hovered
        FrameBgActive: Color of FrameBg when the item is active
        TitleBg: Title bar
        TitleBgActive: Title bar when focused
        TitleBgCollapsed: Title bar when collapsed
        MenuBarBg: Background color of the menu bar
        ScrollbarBg: Background color of the scroll bar
        ScrollbarGrab: Color of the scroll slider
        ScrollbarGrabHovered: Color of the scroll slider when hovered
        ScrollbarGrabActive: Color of the scroll slider when selected
        CheckMark: Checkbox tick and RadioButton circle
        SliderGrab: Color of sliders
        SliderGrabActive: Color of selected sliders
        Button: Color of buttons
        ButtonHovered: Color of buttons when hovered
        ButtonActive: Color of buttons when selected
        Header: Header* colors are used for CollapsingHeader, TreeNode, Selectable, MenuItem
        HeaderHovered: Header color when hovered
        HeaderActive: Header color when clicked
        Separator: Color of separators
        SeparatorHovered: Color of separator when hovered
        SeparatorActive: Color of separator when active
        ResizeGrip: Resize grip in lower-right and lower-left corners of windows.
        ResizeGripHovered: ResizeGrip when hovered
        ResizeGripActive: ResizeGrip when clicked
        TabHovered: Tab background, when hovered
        Tab: Tab background, when tab-bar is focused & tab is unselected
        TabSelected: Tab background, when tab-bar is focused & tab is selected
        TabSelectedOverline: Tab horizontal overline, when tab-bar is focused & tab is selected
        TabDimmed: Tab background, when tab-bar is unfocused & tab is unselected
        TabDimmedSelected: Tab background, when tab-bar is unfocused & tab is selected
        TabDimmedSelectedOverline: ..horizontal overline, when tab-bar is unfocused & tab is selected
        PlotLines: Color of SimplePlot lines
        PlotLinesHovered: Color of SimplePlot lines when hovered
        PlotHistogram: Color of SimplePlot histogram
        PlotHistogramHovered: Color of SimplePlot histogram when hovered
        TableHeaderBg: Table header background
        TableBorderStrong: Table outer and header borders (prefer using Alpha=1.0 here)
        TableBorderLight: Table inner borders (prefer using Alpha=1.0 here)
        TableRowBg: Table row background (even rows)
        TableRowBgAlt: Table row background (odd rows)
        TextLink: Hyperlink color
        TextSelectedBg: Color of the background of selected text
        DragDropTarget: Rectangle highlighting a drop target
        NavCursor: Gamepad/keyboard: current highlighted item
        NavWindowingHighlight: Highlight window when using CTRL+TAB
        NavWindowingDimBg: Darken/colorize entire screen behind the CTRL+TAB window list, when active
        ModalWindowDimBg: Darken/colorize entire screen behind a modal window, when one is active
    """

    def __cinit__(self):
        self._names = [
            "Text",
            "TextDisabled", 
            "WindowBg",
            "ChildBg",
            "PopupBg",
            "Border",
            "BorderShadow",
            "FrameBg",
            "FrameBgHovered",
            "FrameBgActive",
            "TitleBg",
            "TitleBgActive", 
            "TitleBgCollapsed",
            "MenuBarBg",
            "ScrollbarBg",
            "ScrollbarGrab",
            "ScrollbarGrabHovered",
            "ScrollbarGrabActive",
            "CheckMark",
            "SliderGrab",
            "SliderGrabActive",
            "Button",
            "ButtonHovered",
            "ButtonActive",
            "Header",
            "HeaderHovered",
            "HeaderActive",
            "Separator",
            "SeparatorHovered",
            "SeparatorActive",
            "ResizeGrip",
            "ResizeGripHovered",
            "ResizeGripActive",
            "TabHovered",
            "Tab",
            "TabSelected",  
            "TabSelectedOverline",
            "TabDimmed",
            "TabDimmedSelected",
            "TabDimmedSelectedOverline",
            "PlotLines",
            "PlotLinesHovered",
            "PlotHistogram",
            "PlotHistogramHovered",
            "TableHeaderBg",
            "TableBorderStrong",
            "TableBorderLight", 
            "TableRowBg",
            "TableRowBgAlt",
            "TextLink",
            "TextSelectedBg",
            "DragDropTarget",
            "NavCursor",
            "NavWindowingHighlight",
            "NavWindowingDimBg",
            "ModalWindowDimBg"
        ]

    @property 
    def Text(self):
        """Color for text rendering. 
        Default: (1.00, 1.00, 1.00, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.Text)
        
    @Text.setter
    def Text(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.Text, value)

    @property
    def TextDisabled(self):
        """Color for the text of disabled items.
        Default: (0.50, 0.50, 0.50, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TextDisabled)

    @TextDisabled.setter
    def TextDisabled(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TextDisabled, value)

    @property
    def WindowBg(self):
        """Background of normal windows.
        Default: (0.06, 0.06, 0.06, 0.94)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.WindowBg)
        
    @WindowBg.setter
    def WindowBg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.WindowBg, value)

    @property
    def ChildBg(self):
        """Background of child windows.
        Default: (0.00, 0.00, 0.00, 0.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.ChildBg)

    @ChildBg.setter
    def ChildBg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.ChildBg, value)

    @property
    def PopupBg(self):
        """Background of popups, menus, tooltips windows.
        Default: (0.08, 0.08, 0.08, 0.94)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.PopupBg)

    @PopupBg.setter
    def PopupBg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.PopupBg, value)

    @property
    def Border(self):
        """Color of borders.
        Default: (0.43, 0.43, 0.50, 0.50)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.Border)

    @Border.setter
    def Border(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.Border, value)

    @property
    def BorderShadow(self):
        """Color of border shadows.
        Default: (0.00, 0.00, 0.00, 0.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.BorderShadow)

    @BorderShadow.setter
    def BorderShadow(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.BorderShadow, value)

    @property 
    def FrameBg(self):
        """Background of checkbox, radio button, plot, slider, text input.
        Default: (0.16, 0.29, 0.48, 0.54)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.FrameBg)

    @FrameBg.setter
    def FrameBg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.FrameBg, value)

    @property
    def FrameBgHovered(self):
        """Color of FrameBg when the item is hovered.
        Default: (0.26, 0.59, 0.98, 0.40)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.FrameBgHovered)

    @FrameBgHovered.setter 
    def FrameBgHovered(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.FrameBgHovered, value)

    @property
    def FrameBgActive(self):  
        """Color of FrameBg when the item is active.
        Default: (0.26, 0.59, 0.98, 0.67)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.FrameBgActive)

    @FrameBgActive.setter
    def FrameBgActive(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.FrameBgActive, value)

    @property
    def TitleBg(self):
        """Title bar color.
        Default: (0.04, 0.04, 0.04, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TitleBg)

    @TitleBg.setter
    def TitleBg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TitleBg, value)

    @property
    def TitleBgActive(self):
        """Title bar color when focused.
        Default: (0.16, 0.29, 0.48, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TitleBgActive)

    @TitleBgActive.setter
    def TitleBgActive(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TitleBgActive, value)

    @property
    def TitleBgCollapsed(self):
        """Title bar color when collapsed.
        Default: (0.00, 0.00, 0.00, 0.51)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TitleBgCollapsed)

    @TitleBgCollapsed.setter
    def TitleBgCollapsed(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TitleBgCollapsed, value)

    @property
    def MenuBarBg(self):
        """Menu bar background color.
        Default: (0.14, 0.14, 0.14, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.MenuBarBg)

    @MenuBarBg.setter
    def MenuBarBg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.MenuBarBg, value)

    @property  
    def ScrollbarBg(self):
        """Scrollbar background color.
        Default: (0.02, 0.02, 0.02, 0.53)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.ScrollbarBg)

    @ScrollbarBg.setter
    def ScrollbarBg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.ScrollbarBg, value)

    @property
    def ScrollbarGrab(self):
        """Scrollbar grab color.
        Default: (0.31, 0.31, 0.31, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.ScrollbarGrab)

    @ScrollbarGrab.setter  
    def ScrollbarGrab(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.ScrollbarGrab, value)

    @property
    def ScrollbarGrabHovered(self):
        """Scrollbar grab color when hovered. 
        Default: (0.41, 0.41, 0.41, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.ScrollbarGrabHovered)

    @ScrollbarGrabHovered.setter
    def ScrollbarGrabHovered(self, value): 
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.ScrollbarGrabHovered, value)

    @property
    def ScrollbarGrabActive(self):
        """Scrollbar grab color when active.
        Default: (0.51, 0.51, 0.51, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.ScrollbarGrabActive)

    @ScrollbarGrabActive.setter
    def ScrollbarGrabActive(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.ScrollbarGrabActive, value)

    @property
    def CheckMark(self):
        """Checkmark color.
        Default: (0.26, 0.59, 0.98, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.CheckMark)

    @CheckMark.setter
    def CheckMark(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.CheckMark, value)

    @property
    def SliderGrab(self):
        """Slider grab color.
        Default: (0.24, 0.52, 0.88, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.SliderGrab)

    @SliderGrab.setter
    def SliderGrab(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.SliderGrab, value)

    @property 
    def SliderGrabActive(self):
        """Slider grab color when active.
        Default: (0.26, 0.59, 0.98, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.SliderGrabActive)

    @SliderGrabActive.setter
    def SliderGrabActive(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.SliderGrabActive, value)

    @property
    def Button(self):
        """Button color.
        Default: (0.26, 0.59, 0.98, 0.40)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.Button)

    @Button.setter
    def Button(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.Button, value)

    @property
    def ButtonHovered(self):
        """Button color when hovered.
        Default: (0.26, 0.59, 0.98, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.ButtonHovered)

    @ButtonHovered.setter
    def ButtonHovered(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.ButtonHovered, value)

    @property
    def ButtonActive(self):
        """Button color when active.
        Default: (0.06, 0.53, 0.98, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.ButtonActive)

    @ButtonActive.setter
    def ButtonActive(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.ButtonActive, value)

    @property
    def Header(self):
        """Colors used for CollapsingHeader, TreeNode, Selectable, MenuItem.
        Default: (0.26, 0.59, 0.98, 0.31)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.Header)

    @Header.setter
    def Header(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.Header, value)

    @property 
    def HeaderHovered(self):
        """Header colors when hovered.
        Default: (0.26, 0.59, 0.98, 0.80)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.HeaderHovered)

    @HeaderHovered.setter
    def HeaderHovered(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.HeaderHovered, value)

    @property
    def HeaderActive(self):
        """Header colors when activated/clicked.
        Default: (0.26, 0.59, 0.98, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.HeaderActive) 

    @HeaderActive.setter
    def HeaderActive(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.HeaderActive, value)

    @property
    def Separator(self):
        """Color of separating lines.
        Default: Same as Border color (0.43, 0.43, 0.50, 0.50)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.Separator)

    @Separator.setter
    def Separator(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.Separator, value)

    @property
    def SeparatorHovered(self):
        """Separator color when hovered.
        Default: (0.10, 0.40, 0.75, 0.78)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.SeparatorHovered)

    @SeparatorHovered.setter
    def SeparatorHovered(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.SeparatorHovered, value)

    @property
    def SeparatorActive(self):
        """Separator color when active.
        Default: (0.10, 0.40, 0.75, 1.00)""" 
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.SeparatorActive)

    @SeparatorActive.setter
    def SeparatorActive(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.SeparatorActive, value)

    @property
    def ResizeGrip(self):
        """Resize grip in lower-right and lower-left corners of windows.
        Default: (0.26, 0.59, 0.98, 0.20)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.ResizeGrip)
    
    @ResizeGrip.setter 
    def ResizeGrip(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.ResizeGrip, value)
    
    @property
    def ResizeGripHovered(self):
        """ResizeGrip color when hovered.
        Default: (0.26, 0.59, 0.98, 0.67)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.ResizeGripHovered)
    
    @ResizeGripHovered.setter
    def ResizeGripHovered(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.ResizeGripHovered, value)
    
    @property
    def ResizeGripActive(self):
        """ResizeGrip color when clicked.
        Default: (0.26, 0.59, 0.98, 0.95)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.ResizeGripActive)
    
    @ResizeGripActive.setter
    def ResizeGripActive(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.ResizeGripActive, value)
    
    @property
    def TabHovered(self):
        """Tab background when hovered.
        Default: Same as HeaderHovered color"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TabHovered)
    
    @TabHovered.setter
    def TabHovered(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TabHovered, value)
    
    @property
    def Tab(self):
        """Tab background when tab-bar is focused & tab is unselected.
        Default: Value interpolated between Header and TitleBgActive colors with factor 0.80"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.Tab)
    
    @Tab.setter
    def Tab(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.Tab, value)
    
    @property
    def TabSelected(self):
        """Tab background when tab-bar is focused & tab is selected.
        Default: Value interpolated between HeaderActive and TitleBgActive colors with factor 0.60"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TabSelected)
    
    @TabSelected.setter
    def TabSelected(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TabSelected, value)
    
    @property
    def TabSelectedOverline(self):
        """Tab horizontal overline when tab-bar is focused & tab is selected.
        Default: Same as HeaderActive color"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TabSelectedOverline)
    
    @TabSelectedOverline.setter
    def TabSelectedOverline(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TabSelectedOverline, value)
    
    @property
    def TabDimmed(self):
        """Tab background when tab-bar is unfocused & tab is unselected.
        Default: Value interpolated between Tab and TitleBg colors with factor 0.80"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TabDimmed)
    
    @TabDimmed.setter
    def TabDimmed(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TabDimmed, value)
    
    @property
    def TabDimmedSelected(self):
        """Tab background when tab-bar is unfocused & tab is selected.
        Default: Value interpolated between TabSelected and TitleBg colors with factor 0.40""" 
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TabDimmedSelected)
    
    @TabDimmedSelected.setter
    def TabDimmedSelected(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TabDimmedSelected, value)
    
    @property
    def TabDimmedSelectedOverline(self):
        """Tab horizontal overline when tab-bar is unfocused & tab is selected.
        Default: (0.50, 0.50, 0.50, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TabDimmedSelectedOverline)
    
    @TabDimmedSelectedOverline.setter
    def TabDimmedSelectedOverline(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TabDimmedSelectedOverline, value)
    
    @property
    def PlotLines(self):
        """Color of SimplePlot lines.
        Default: (0.61, 0.61, 0.61, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.PlotLines) 
    
    @PlotLines.setter
    def PlotLines(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.PlotLines, value)
    
    @property
    def PlotLinesHovered(self):
        """Color of SimplePlot lines when hovered.
        Default: (1.00, 0.43, 0.35, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.PlotLinesHovered)
    
    @PlotLinesHovered.setter
    def PlotLinesHovered(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.PlotLinesHovered, value)
    
    @property
    def PlotHistogram(self):
        """Color of SimplePlot histogram.
        Default: (0.90, 0.70, 0.00, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.PlotHistogram)
    
    @PlotHistogram.setter
    def PlotHistogram(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.PlotHistogram, value)
    
    @property
    def PlotHistogramHovered(self):
        """Color of SimplePlot histogram when hovered.
        Default: (1.00, 0.60, 0.00, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.PlotHistogramHovered)
    
    @PlotHistogramHovered.setter
    def PlotHistogramHovered(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.PlotHistogramHovered, value)
    
    @property
    def TableHeaderBg(self):
        """Table header background.
        Default: (0.19, 0.19, 0.20, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TableHeaderBg)
    
    @TableHeaderBg.setter
    def TableHeaderBg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TableHeaderBg, value)
    
    @property
    def TableBorderStrong(self):
        """Table outer borders and headers (prefer using Alpha=1.0 here).
        Default: (0.31, 0.31, 0.35, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TableBorderStrong)
    
    @TableBorderStrong.setter
    def TableBorderStrong(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TableBorderStrong, value)
    
    @property
    def TableBorderLight(self):
        """Table inner borders (prefer using Alpha=1.0 here).
        Default: (0.23, 0.23, 0.25, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TableBorderLight)
    
    @TableBorderLight.setter
    def TableBorderLight(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TableBorderLight, value)
    
    @property
    def TableRowBg(self):
        """Table row background (even rows).
        Default: (0.00, 0.00, 0.00, 0.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TableRowBg)
    
    @TableRowBg.setter
    def TableRowBg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TableRowBg, value)
    
    @property
    def TableRowBgAlt(self):
        """Table row background (odd rows).
        Default: (1.00, 1.00, 1.00, 0.06)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TableRowBgAlt)
    
    @TableRowBgAlt.setter
    def TableRowBgAlt(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TableRowBgAlt, value)
    
    @property
    def TextLink(self):
        """Hyperlink color.
        Default: Same as HeaderActive color"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TextLink)
    
    @TextLink.setter
    def TextLink(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TextLink, value)

    @property
    def TextSelectedBg(self):
        """Background color of selected text.
        Default: (0.26, 0.59, 0.98, 0.35)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.TextSelectedBg)

    @TextSelectedBg.setter
    def TextSelectedBg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.TextSelectedBg, value)

    @property
    def DragDropTarget(self):
        """Rectangle highlighting a drop target.
        Default: (1.00, 1.00, 0.00, 0.90)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.DragDropTarget)
    
    @DragDropTarget.setter
    def DragDropTarget(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.DragDropTarget, value)

    @property
    def NavCursor(self):
        """Color of keyboard/gamepad navigation cursor/rectangle, when visible.
        Default: Same as HeaderHovered (0.26, 0.59, 0.98, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.NavCursor)

    @NavCursor.setter
    def NavCursor(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.NavCursor, value)

    @property
    def NavWindowingHighlight(self):
        """Highlight window when using CTRL+TAB.
        Default: (1.00, 1.00, 1.00, 0.70)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.NavWindowingHighlight)

    @NavWindowingHighlight.setter
    def NavWindowingHighlight(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.NavWindowingHighlight, value)

    @property 
    def NavWindowingDimBg(self):
        """Darken/colorize entire screen behind CTRL+TAB window list.
        Default: (0.80, 0.80, 0.80, 0.20)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.NavWindowingDimBg)

    @NavWindowingDimBg.setter
    def NavWindowingDimBg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.NavWindowingDimBg, value)

    @property
    def ModalWindowDimBg(self):
        """Darken/colorize entire screen behind a modal window.
        Default: (0.80, 0.80, 0.80, 0.35)"""
        return baseThemeColor._common_getter(self, <int>ImGuiColorIndex.ModalWindowDimBg)

    @ModalWindowDimBg.setter
    def ModalWindowDimBg(self, value):
        baseThemeColor._common_setter(self, <int>ImGuiColorIndex.ModalWindowDimBg, value)

    @classmethod
    def get_default(self, str color_name):
        """Get the default color value for the given color name."""
        if color_name == "Text":
            return (1.00, 1.00, 1.00, 1.00)
        elif color_name == "TextDisabled":
            return (0.50, 0.50, 0.50, 1.00)
        elif color_name == "WindowBg":
            return (0.06, 0.06, 0.06, 0.94)
        elif color_name == "ChildBg":
            return (0.00, 0.00, 0.00, 0.00)
        elif color_name == "PopupBg":
            return (0.08, 0.08, 0.08, 0.94)
        elif color_name == "Border":
            return (0.43, 0.43, 0.50, 0.50)
        elif color_name == "BorderShadow":
            return (0.00, 0.00, 0.00, 0.00)
        elif color_name == "FrameBg":
            return (0.16, 0.29, 0.48, 0.54)
        elif color_name == "FrameBgHovered":
            return (0.26, 0.59, 0.98, 0.40)
        elif color_name == "FrameBgActive":
            return (0.26, 0.59, 0.98, 0.67)
        elif color_name == "TitleBg":
            return (0.04, 0.04, 0.04, 1.00)
        elif color_name == "TitleBgActive":
            return (0.16, 0.29, 0.48, 1.00)
        elif color_name == "TitleBgCollapsed":
            return (0.00, 0.00, 0.00, 0.51)
        elif color_name == "MenuBarBg":
            return (0.14, 0.14, 0.14, 1.00)
        elif color_name == "ScrollbarBg":
            return (0.02, 0.02, 0.02, 0.53)
        elif color_name == "ScrollbarGrab":
            return (0.31, 0.31, 0.31, 1.00)
        elif color_name == "ScrollbarGrabHovered":
            return (0.41, 0.41, 0.41, 1.00)
        elif color_name == "ScrollbarGrabActive":
            return (0.51, 0.51, 0.51, 1.00)
        elif color_name == "CheckMark":
            return (0.26, 0.59, 0.98, 1.00)
        elif color_name == "SliderGrab":
            return (0.24, 0.52, 0.88, 1.00)
        elif color_name == "SliderGrabActive":
            return (0.26, 0.59, 0.98, 1.00)
        elif color_name == "Button":
            return (0.26, 0.59, 0.98, 0.40)
        elif color_name == "ButtonHovered":
            return (0.26, 0.59, 0.98, 1.00)
        elif color_name == "ButtonActive":
            return (0.06, 0.53, 0.98, 1.00)
        elif color_name == "Header":
            return (0.26, 0.59, 0.98, 0.31)
        elif color_name == "HeaderHovered":
            return (0.26, 0.59, 0.98, 0.80)
        elif color_name == "HeaderActive":
            return (0.26, 0.59, 0.98, 1.00)
        elif color_name == "Separator":
            return (0.43, 0.43, 0.50, 0.50)
        elif color_name == "SeparatorHovered":
            return (0.10, 0.40, 0.75, 0.78)
        elif color_name == "SeparatorActive":
            return (0.10, 0.40, 0.75, 1.00)
        elif color_name == "ResizeGrip":
            return (0.26, 0.59, 0.98, 0.20)
        elif color_name == "ResizeGripHovered":
            return (0.26, 0.59, 0.98, 0.67)
        elif color_name == "ResizeGripActive":
            return (0.26, 0.59, 0.98, 0.95)
        elif color_name == "TabHovered":
            return (0.26, 0.59, 0.98, 0.80)
        elif color_name == "Tab":
            return (0.26, 0.59, 0.98, 0.80)
        elif color_name == "TabSelected":
            return (0.26, 0.59, 0.98, 0.60)
        elif color_name == "TabSelectedOverline":
            return (0.26, 0.59, 0.98, 1.00)
        elif color_name == "TabDimmed":
            return (0.26, 0.59, 0.98, 0.80)
        elif color_name == "TabDimmedSelected":
            return (0.26, 0.59, 0.98, 0.40)
        elif color_name == "TabDimmedSelectedOverline":
            return (0.50, 0.50, 0.50, 1.00)
        elif color_name == "PlotLines":
            return (0.61, 0.61, 0.61, 1.00)
        elif color_name == "PlotLinesHovered":
            return (1.00, 0.43, 0.35, 1.00)
        elif color_name == "PlotHistogram":
            return (0.90, 0.70, 0.00, 1.00)
        elif color_name == "PlotHistogramHovered":
            return (1.00, 0.60, 0.00, 1.00)
        elif color_name == "TableHeaderBg":
            return (0.19, 0.19, 0.20, 1.00)
        elif color_name == "TableBorderStrong":
            return (0.31, 0.31, 0.35, 1.00)
        elif color_name == "TableBorderLight":
            return (0.23, 0.23, 0.25, 1.00)
        elif color_name == "TableRowBg":
            return (0.00, 0.00, 0.00, 0.00)
        elif color_name == "TableRowBgAlt":
            return (1.00, 1.00, 1.00, 0.06)
        elif color_name == "TextLink":
            return (0.26, 0.59, 0.98, 1.00)
        elif color_name == "TextSelectedBg":
            return (0.26, 0.59, 0.98, 0.35)
        elif color_name == "DragDropTarget":
            return (1.00, 1.00, 0.00, 0.90)
        elif color_name == "NavCursor":
            return (0.26, 0.59, 0.98, 1.00)
        elif color_name == "NavWindowingHighlight":
            return (1.00, 1.00, 1.00, 0.70)
        elif color_name == "NavWindowingDimBg":
            return (0.80, 0.80, 0.80, 0.20)
        elif color_name == "ModalWindowDimBg":
            return (0.80, 0.80, 0.80, 0.35)
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
            imgui.PushStyleColor(<imgui.ImGuiCol>element_content.first, <imgui.ImU32>element_content.second)
        self._last_push_size.push_back(<int>self._index_to_value.size())

    cdef void pop(self) noexcept nogil:
        cdef int32_t count = self._last_push_size.back()
        self._last_push_size.pop_back()
        if count > 0:
            imgui.PopStyleColor(count)
        self.mutex.unlock()


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
        Line: Plot line color. Auto - derived from Text color
        Fill: Plot fill color. Auto - derived from Line color
        MarkerOutline: Plot marker outline color. Auto - derived from Line color
        MarkerFill: Plot marker fill color. Auto - derived from Line color 
        ErrorBar: Error bar color. Auto - derived from Text color
        FrameBg: Plot frame background color. Auto - derived from FrameBg color
        PlotBg: Plot area background color. Auto - derived from WindowBg color
        PlotBorder: Plot area border color. Auto - derived from Border color
        LegendBg: Legend background color. Auto - derived from PopupBg color
        LegendBorder: Legend border color. Auto - derived from Border color
        LegendText: Legend text color. Auto - derived from Text color
        TitleText: Plot title text color. Auto - derived from Text color
        InlayText: Color of text appearing inside plots. Auto - derived from Text color
        AxisText: Axis text labels color. Auto - derived from Text color
        AxisGrid: Axis grid color. Auto - derived from Text color with reduced alpha
        AxisTick: Axis tick marks color. Auto - derived from AxisGrid color
        AxisBg: Background color of axis hover region. Auto - transparent
        AxisBgHovered: Axis background color when hovered. Auto - derived from ButtonHovered color
        AxisBgActive: Axis background color when clicked. Auto - derived from ButtonActive color
        Selection: Box-selection color. Default: (1.00, 1.00, 0.00, 1.00)
        Crosshairs: Crosshairs color. Auto - derived from PlotBorder color
    """
    def __cinit__(self):
        self._names = [
            "Line",
            "Fill",
            "MarkerOutline",
            "MarkerFill",
            "ErrorBar",
            "FrameBg",
            "PlotBg",
            "PlotBorder",
            "LegendBg",
            "LegendBorder",
            "LegendText",
            "TitleText",
            "InlayText",
            "AxisText",
            "AxisGrid",
            "AxisTick",
            "AxisBg",
            "AxisBgHovered",
            "AxisBgActive",
            "Selection",
            "Crosshairs"
        ]

    @property
    def Line(self):
        """Plot line color.
        Default: Auto - derived from Text color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.Line)

    @Line.setter
    def Line(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.Line, value)

    @property
    def Fill(self):
        """Plot fill color.
        Default: Auto - derived from Line color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.Fill)

    @Fill.setter
    def Fill(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.Fill, value)

    @property
    def MarkerOutline(self):
        """Plot marker outline color.
        Default: Auto - derived from Line color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.MarkerOutline)

    @MarkerOutline.setter
    def MarkerOutline(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.MarkerOutline, value)

    @property
    def MarkerFill(self):
        """Plot marker fill color.
        Default: Auto - derived from Line color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.MarkerFill)

    @MarkerFill.setter
    def MarkerFill(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.MarkerFill, value)

    @property
    def ErrorBar(self):
        """Error bar color.
        Default: Auto - derived from Text color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.ErrorBar)

    @ErrorBar.setter
    def ErrorBar(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.ErrorBar, value)

    @property
    def FrameBg(self):
        """Plot frame background color.
        Default: Auto - derived from FrameBg color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.FrameBg)

    @FrameBg.setter
    def FrameBg(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.FrameBg, value)

    @property
    def PlotBg(self):
        """Plot area background color.
        Default: Auto - derived from WindowBg color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.PlotBg)

    @PlotBg.setter
    def PlotBg(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.PlotBg, value)

    @property
    def PlotBorder(self):
        """Plot area border color.
        Default: Auto - derived from Border color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.PlotBorder)

    @PlotBorder.setter
    def PlotBorder(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.PlotBorder, value)

    @property
    def LegendBg(self):
        """Legend background color.
        Default: Auto - derived from PopupBg color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.LegendBg)

    @LegendBg.setter
    def LegendBg(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.LegendBg, value)

    @property
    def LegendBorder(self):
        """Legend border color.
        Default: Auto - derived from Border color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.LegendBorder)

    @LegendBorder.setter
    def LegendBorder(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.LegendBorder, value)

    @property
    def LegendText(self):
        """Legend text color.
        Default: Auto - derived from Text color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.LegendText)

    @LegendText.setter
    def LegendText(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.LegendText, value)

    @property
    def TitleText(self):
        """Plot title text color.
        Default: Auto - derived from Text color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.TitleText)

    @TitleText.setter
    def TitleText(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.TitleText, value)

    @property
    def InlayText(self):
        """Color of text appearing inside of plots.
        Default: Auto - derived from Text color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.InlayText)

    @InlayText.setter
    def InlayText(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.InlayText, value)

    @property
    def AxisText(self):
        """Axis text labels color.
        Default: Auto - derived from Text color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.AxisText)

    @AxisText.setter
    def AxisText(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.AxisText, value)

    @property
    def AxisGrid(self):
        """Axis grid color.
        Default: Auto - derived from Text color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.AxisGrid)

    @AxisGrid.setter
    def AxisGrid(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.AxisGrid, value)

    @property
    def AxisTick(self):
        """Axis tick marks color.
        Default: Auto - derived from AxisGrid color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.AxisTick)

    @AxisTick.setter
    def AxisTick(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.AxisTick, value)

    @property
    def AxisBg(self):
        """Background color of axis hover region.
        Default: transparent"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.AxisBg)

    @AxisBg.setter
    def AxisBg(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.AxisBg, value)

    @property
    def AxisBgHovered(self):
        """Axis background color when hovered.
        Default: Auto - derived from ButtonHovered color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.AxisBgHovered)

    @AxisBgHovered.setter
    def AxisBgHovered(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.AxisBgHovered, value)

    @property
    def AxisBgActive(self):
        """Axis background color when clicked.
        Default: Auto - derived from ButtonActive color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.AxisBgActive)

    @AxisBgActive.setter
    def AxisBgActive(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.AxisBgActive, value)

    @property
    def Selection(self):
        """Box-selection color.
        Default: (1.00, 1.00, 0.00, 1.00)"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.Selection)

    @Selection.setter
    def Selection(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.Selection, value)

    @property
    def Crosshairs(self):
        """Crosshairs color.
        Default: Auto - derived from PlotBorder color"""
        return baseThemeColor._common_getter(self, <int>ImPlotColorIndex.Crosshairs)

    @Crosshairs.setter
    def Crosshairs(self, value):
        baseThemeColor._common_setter(self, <int>ImPlotColorIndex.Crosshairs, value)

    @classmethod
    def get_default(self, str color_name):
        """Get the default color value for the given color name."""
        if color_name == "Line":
            return ThemeColorImGui.get_default("Text")
        elif color_name == "Fill":
            return self.get_default("Line")
        elif color_name == "MarkerOutline":
            return self.get_default("Line")
        elif color_name == "MarkerFill":
            return self.get_default("Line")
        elif color_name == "ErrorBar":
            return ThemeColorImGui.get_default("Text")
        elif color_name == "FrameBg":
            return ThemeColorImGui.get_default("FrameBg")
        elif color_name == "PlotBg":
            return ThemeColorImGui.get_default("WindowBg")
        elif color_name == "PlotBorder":
            return ThemeColorImGui.get_default("Border")
        elif color_name == "LegendBg":
            return ThemeColorImGui.get_default("PopupBg")
        elif color_name == "LegendBorder":
            return ThemeColorImGui.get_default("Border")
        elif color_name == "LegendText":
            return ThemeColorImGui.get_default("Text")
        elif color_name == "TitleText":
            return ThemeColorImGui.get_default("Text")
        elif color_name == "InlayText":
            return ThemeColorImGui.get_default("Text")
        elif color_name == "AxisText":
            return ThemeColorImGui.get_default("Text")
        elif color_name == "AxisGrid":
            (r, g, b, a) = ThemeColorImGui.get_default("Text")
            return (r, g, b, 0.25 * a)
        elif color_name == "AxisTick":
            return self.get_default("AxisGrid")
        elif color_name == "AxisBg":
            return (0.00, 0.00, 0.00, 0.00)  # Transparent
        elif color_name == "AxisBgHovered":
            return ThemeColorImGui.get_default("ButtonHovered")
        elif color_name == "AxisBgActive":
            return ThemeColorImGui.get_default("ButtonActive")
        elif color_name == "Selection":
            return (1.00, 1.00, 0.00, 1.00)
        elif color_name == "Crosshairs":
            return self.get_default("PlotBorder")
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

    def __getitem__(self, key):
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

    def __setitem__(self, key, value):
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

    def __iter__(self):
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
            "Alpha",                    # float     Alpha
            "DisabledAlpha",            # float     DisabledAlpha
            "WindowPadding",            # ImVec2    WindowPadding
            "WindowRounding",           # float     WindowRounding
            "WindowBorderSize",         # float     WindowBorderSize
            "WindowMinSize",            # ImVec2    WindowMinSize
            "WindowTitleAlign",         # ImVec2    WindowTitleAlign
            "ChildRounding",            # float     ChildRounding
            "ChildBorderSize",          # float     ChildBorderSize
            "PopupRounding",            # float     PopupRounding
            "PopupBorderSize",          # float     PopupBorderSize
            "FramePadding",             # ImVec2    FramePadding
            "FrameRounding",            # float     FrameRounding
            "FrameBorderSize",          # float     FrameBorderSize
            "ItemSpacing",              # ImVec2    ItemSpacing
            "ItemInnerSpacing",         # ImVec2    ItemInnerSpacing
            "IndentSpacing",            # float     IndentSpacing
            "CellPadding",              # ImVec2    CellPadding
            "ScrollbarSize",            # float     ScrollbarSize
            "ScrollbarRounding",        # float     ScrollbarRounding
            "GrabMinSize",              # float     GrabMinSize
            "GrabRounding",             # float     GrabRounding
            "TabRounding",              # float     TabRounding
            "TabBorderSize",            # float     TabBorderSize
            "TabBarBorderSize",         # float     TabBarBorderSize
            "TabBarOverlineSize",       # float     TabBarOverlineSize
            "TableAngledHeadersAngle",  # float     TableAngledHeadersAngle
            "TableAngledHeadersTextAlign",# ImVec2  TableAngledHeadersTextAlign
            "ButtonTextAlign",          # ImVec2    ButtonTextAlign
            "SelectableTextAlign",      # ImVec2    SelectableTextAlign
            "SeparatorTextBorderSize",  # float     SeparatorTextBorderSize
            "SeparatorTextAlign",       # ImVec2    SeparatorTextAlign
            "SeparatorTextPadding",     # ImVec2    SeparatorTextPadding
        ]

    @property
    def Alpha(self):
        """
        Global alpha applied to everything in Dear ImGui.

        The value is in the range [0, 1]. Defaults to 1.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.Alpha, theme_value_types.t_float)

    @Alpha.setter
    def Alpha(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.Alpha, theme_value_types.t_float, False, False, value)

    @property
    def DisabledAlpha(self):
        """
        Unused currently.

        The value is in the range [0, 1]. Defaults to 0.6
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.DisabledAlpha, theme_value_types.t_float)

    @DisabledAlpha.setter
    def DisabledAlpha(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.DisabledAlpha, theme_value_types.t_float, False, False, value)

    @property
    def WindowPadding(self):
        """
        Padding within a window.

        The value is a pair of float (dx, dy). Defaults to (8, 8)
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.WindowPadding, theme_value_types.t_float2)

    @WindowPadding.setter
    def WindowPadding(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.WindowPadding, theme_value_types.t_float2, True, True, value)

    @property
    def WindowRounding(self):
        """
        Radius of window corners rounding. Set to 0.0 to have rectangular windows. Large values tend to lead to variety of artifacts and are not recommended.

        The value is a float. Defaults to 0.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.WindowRounding, theme_value_types.t_float)

    @WindowRounding.setter
    def WindowRounding(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.WindowRounding, theme_value_types.t_float, True, False, value)

    @property
    def WindowBorderSize(self):
        """
        Thickness of border around windows. Generally set to 0.0 or 1.0f. Other values not well tested.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.WindowBorderSize, theme_value_types.t_float)

    @WindowBorderSize.setter
    def WindowBorderSize(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.WindowBorderSize, theme_value_types.t_float, True, True, value)

    @property
    def WindowMinSize(self):
        """
        Minimum window size

        The value is a pair of float (dx, dy). Defaults to (32, 32)
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.WindowMinSize, theme_value_types.t_float2)

    @WindowMinSize.setter
    def WindowMinSize(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.WindowMinSize, theme_value_types.t_float2, True, True, value)

    @property
    def WindowTitleAlign(self):
        """
        Alignment for window title bar text in percentages

        The value is a pair of float (dx, dy). Defaults to (0., 0.5), which means left-aligned, vertical centering on the row
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.WindowTitleAlign, theme_value_types.t_float2)

    @WindowTitleAlign.setter
    def WindowTitleAlign(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.WindowTitleAlign, theme_value_types.t_float2, False, False, value)

    @property
    def ChildRounding(self):
        """
        Radius of child window corners rounding. Set to 0.0 to have rectangular child windows.

        The value is a float. Defaults to 0.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.ChildRounding, theme_value_types.t_float)

    @ChildRounding.setter
    def ChildRounding(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.ChildRounding, theme_value_types.t_float, True, False, value)

    @property
    def ChildBorderSize(self):
        """
        Thickness of border around child windows. Generally set to 0.0f or 1.0f. Other values not well tested.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.ChildBorderSize, theme_value_types.t_float)

    @ChildBorderSize.setter
    def ChildBorderSize(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.ChildBorderSize, theme_value_types.t_float, True, True, value)

    @property
    def PopupRounding(self):
        """
        Radius of popup or tooltip window corners rounding. Set to 0.0 to have rectangular popup or tooltip windows.

        The value is a float. Defaults to 0.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.PopupRounding, theme_value_types.t_float)

    @PopupRounding.setter
    def PopupRounding(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.PopupRounding, theme_value_types.t_float, True, False, value)

    @property
    def PopupBorderSize(self):
        """
        Thickness of border around popup or tooltip windows. Generally set to 0.0f or 1.0f. Other values not well tested.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.PopupBorderSize, theme_value_types.t_float)

    @PopupBorderSize.setter
    def PopupBorderSize(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.PopupBorderSize, theme_value_types.t_float, True, True, value)

    @property
    def FramePadding(self):
        """
        Padding within a framed rectangle (used by most widgets)

        The value is a pair of floats. Defaults to (4,3).
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.FramePadding, theme_value_types.t_float2)

    @FramePadding.setter
    def FramePadding(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.FramePadding, theme_value_types.t_float2, True, True, value)

    @property
    def FrameRounding(self):
        """
        Radius of frame corners rounding. Set to 0.0 to have rectangular frame (most widgets).

        The value is a float. Defaults to 0.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.FrameRounding, theme_value_types.t_float)

    @FrameRounding.setter
    def FrameRounding(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.FrameRounding, theme_value_types.t_float, True, False, value)

    @property
    def FrameBorderSize(self):
        """
        Thickness of border around frames (most widgets). Generally set to 0.0f or 1.0f. Other values not well tested.

        The value is a float. Defaults to 0.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.FrameBorderSize, theme_value_types.t_float)

    @FrameBorderSize.setter
    def FrameBorderSize(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.FrameBorderSize, theme_value_types.t_float, True, True, value)

    @property
    def ItemSpacing(self):
        """
        Horizontal and vertical spacing between widgets/lines.

        The value is a pair of floats. Defaults to (8, 4).
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.ItemSpacing, theme_value_types.t_float2)

    @ItemSpacing.setter
    def ItemSpacing(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.ItemSpacing, theme_value_types.t_float2, True, True, value)

    @property
    def ItemInnerSpacing(self):
        """
        Horizontal and vertical spacing between elements inside of a composed widget.

        The value is a pair of floats. Defaults to (4, 4).
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.ItemInnerSpacing, theme_value_types.t_float2)

    @ItemInnerSpacing.setter
    def ItemInnerSpacing(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.ItemInnerSpacing, theme_value_types.t_float2, True, True, value)

    @property
    def IndentSpacing(self):
        """
        Default horizontal spacing for indentations. For instance when entering a tree node.
        A good value is Generally == (FontSize + FramePadding.x*2).

        The value is a float. Defaults to 21.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.IndentSpacing, theme_value_types.t_float)

    @IndentSpacing.setter
    def IndentSpacing(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.IndentSpacing, theme_value_types.t_float, True, True, value)

    @property
    def CellPadding(self):
        """
        Tables: padding between cells.
        The x padding is applied for the whole Table,
        while y can be different for every row.

        The value is a pair of floats. Defaults to (4, 2).
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.CellPadding, theme_value_types.t_float2)

    @CellPadding.setter
    def CellPadding(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.CellPadding, theme_value_types.t_float2, True, True, value)

    @property
    def ScrollbarSize(self):
        """
        Width of the vertical scrollbar, Height of the horizontal scrollbar

        The value is a float. Defaults to 14.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.ScrollbarSize, theme_value_types.t_float)

    @ScrollbarSize.setter
    def ScrollbarSize(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.ScrollbarSize, theme_value_types.t_float, True, True, value)

    @property
    def ScrollbarRounding(self):
        """
        Radius of grab corners rounding for scrollbar.

        The value is a float. Defaults to 9.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.ScrollbarRounding, theme_value_types.t_float)

    @ScrollbarRounding.setter
    def ScrollbarRounding(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.ScrollbarRounding, theme_value_types.t_float, True, True, value)

    @property
    def GrabMinSize(self):
        """
        Minimum width/height of a grab box for slider/scrollbar.

        The value is a float. Defaults to 12.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.GrabMinSize, theme_value_types.t_float)

    @GrabMinSize.setter
    def GrabMinSize(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.GrabMinSize, theme_value_types.t_float, True, True, value)

    @property
    def GrabRounding(self):
        """
        Radius of grabs corners rounding. Set to 0.0f to have rectangular slider grabs.

        The value is a float. Defaults to 0.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.GrabRounding, theme_value_types.t_float)

    @GrabRounding.setter
    def GrabRounding(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.GrabRounding, theme_value_types.t_float, True, False, value)

    @property
    def TabRounding(self):
        """
        Radius of upper corners of a tab. Set to 0.0f to have rectangular tabs.

        The value is a float. Defaults to 4.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.TabRounding, theme_value_types.t_float)

    @TabRounding.setter
    def TabRounding(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.TabRounding, theme_value_types.t_float, True, False, value)

    @property
    def TabBorderSize(self):
        """
        Thickness of borders around tabs.

        The value is a float. Defaults to 0.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.TabBorderSize, theme_value_types.t_float)

    @TabBorderSize.setter
    def TabBorderSize(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.TabBorderSize, theme_value_types.t_float, True, True, value)

    @property
    def TabBarBorderSize(self):
        """
        Thickness of tab-bar separator, which takes on the tab active color to denote focus.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.TabBarBorderSize, theme_value_types.t_float)

    @TabBarBorderSize.setter
    def TabBarBorderSize(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.TabBarBorderSize, theme_value_types.t_float, True, True, value)

    @property
    def TabBarOverlineSize(self):
        """
        Thickness of tab-bar overline, which highlights the selected tab-bar.

        The value is a float. Defaults to 2.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.TabBarOverlineSize, theme_value_types.t_float)

    @TabBarOverlineSize.setter
    def TabBarOverlineSize(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.TabBarOverlineSize, theme_value_types.t_float, True, True, value)

    @property
    def TableAngledHeadersAngle(self):
        """
        Tables: Angle of angled headers (supported values range from -50 degrees to +50 degrees).

        The value is a float. Defaults to 35.0f * (IM_PI / 180.0f).
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.TableAngledHeadersAngle, theme_value_types.t_float)

    @TableAngledHeadersAngle.setter
    def TableAngledHeadersAngle(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.TableAngledHeadersAngle, theme_value_types.t_float, False, False, value)

    @property
    def TableAngledHeadersTextAlign(self):
        """
        Tables: Alignment (percentages) of angled headers within the cell
    
        The value is a pair of floats. Defaults to (0.5, 0.), i.e. top-centered
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.TableAngledHeadersTextAlign, theme_value_types.t_float2)

    @TableAngledHeadersTextAlign.setter
    def TableAngledHeadersTextAlign(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.TableAngledHeadersTextAlign, theme_value_types.t_float2, False, False, value)

    @property
    def ButtonTextAlign(self):
        """
        Alignment of button text when button is larger than text.
    
        The value is a pair of floats. Defaults to (0.5, 0.5), i.e. centered
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.ButtonTextAlign, theme_value_types.t_float2)

    @ButtonTextAlign.setter
    def ButtonTextAlign(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.ButtonTextAlign, theme_value_types.t_float2, False, False, value)

    @property
    def SelectableTextAlign(self):
        """
        Alignment of selectable text (in percentages).
    
        The value is a pair of floats. Defaults to (0., 0.), i.e. top-left. It is advised to keep the default.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.SelectableTextAlign, theme_value_types.t_float2)

    @SelectableTextAlign.setter
    def SelectableTextAlign(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.SelectableTextAlign, theme_value_types.t_float2, False, False, value)

    @property
    def SeparatorTextBorderSize(self):
        """
        Thickness of border in Separator() text.
    
        The value is a float. Defaults to 3.
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.SeparatorTextBorderSize, theme_value_types.t_float)

    @SeparatorTextBorderSize.setter
    def SeparatorTextBorderSize(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.SeparatorTextBorderSize, theme_value_types.t_float, True, True, value)

    @property
    def SelectableTextAlign(self):
        """
        Alignment of text within the separator in percentages.
    
        The value is a pair of floats. Defaults to (0., 0.5), i.e. left-centered
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.SelectableTextAlign, theme_value_types.t_float2)

    @SelectableTextAlign.setter
    def SelectableTextAlign(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.SelectableTextAlign, theme_value_types.t_float2, False, False, value)

    @property
    def SeparatorTextPadding(self):
        """
        Horizontal offset of text from each edge of the separator + spacing on other axis. Generally small values. .y is recommended to be == FramePadding.y.
    
        The value is a pair of floats. Defaults to (20., 3.).
        """
        return baseThemeStyle._common_getter(self, <int>ImGuiStyleIndex.SeparatorTextPadding, theme_value_types.t_float2)

    @SeparatorTextPadding.setter
    def SeparatorTextPadding(self, value):
        baseThemeStyle._common_setter(self, <int>ImGuiStyleIndex.SeparatorTextPadding, theme_value_types.t_float2, True, True, value)

    @classmethod
    def get_default(self, str style_name):
        """Get the default style value for the given style name."""
        if style_name == "Alpha":
            return 1.0
        elif style_name == "DisabledAlpha":
            return 0.6
        elif style_name == "WindowPadding":
            return (8.0, 8.0)
        elif style_name == "WindowRounding":
            return 0.0
        elif style_name == "WindowBorderSize":
            return 1.0
        elif style_name == "WindowMinSize":
            return (32.0, 32.0)
        elif style_name == "WindowTitleAlign":
            return (0.0, 0.5)
        elif style_name == "ChildRounding":
            return 0.0
        elif style_name == "ChildBorderSize":
            return 1.0
        elif style_name == "PopupRounding":
            return 0.0
        elif style_name == "PopupBorderSize":
            return 1.0
        elif style_name == "FramePadding":
            return (4.0, 3.0)
        elif style_name == "FrameRounding":
            return 0.0
        elif style_name == "FrameBorderSize":
            return 0.0
        elif style_name == "ItemSpacing":
            return (8.0, 4.0)
        elif style_name == "ItemInnerSpacing":
            return (4.0, 4.0)
        elif style_name == "IndentSpacing":
            return 21.0
        elif style_name == "CellPadding":
            return (4.0, 2.0)
        elif style_name == "ScrollbarSize":
            return 14.0
        elif style_name == "ScrollbarRounding":
            return 9.0
        elif style_name == "GrabMinSize":
            return 12.0
        elif style_name == "GrabRounding":
            return 0.0
        elif style_name == "TabRounding":
            return 4.0
        elif style_name == "TabBorderSize":
            return 0.0
        elif style_name == "TabBarBorderSize":
            return 1.0
        elif style_name == "TabBarOverlineSize":
            return 2.0
        elif style_name == "TableAngledHeadersAngle":
            return 35.0 * (3.141592653589793 / 180.0)
        elif style_name == "TableAngledHeadersTextAlign":
            return (0.5, 0.0)
        elif style_name == "ButtonTextAlign":
            return (0.5, 0.5)
        elif style_name == "SelectableTextAlign":
            return (0.0, 0.0)
        elif style_name == "SeparatorTextBorderSize":
            return 3.0
        elif style_name == "SeparatorTextAlign":
            return (0.0, 0.5)
        elif style_name == "SeparatorTextPadding":
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
            "LineWeight",         # float,  plot item line weight in pixels
            "Marker",             # int,    marker specification
            "MarkerSize",         # float,  marker size in pixels (roughly the marker's "radius")
            "MarkerWeight",       # float,  plot outline weight of markers in pixels
            "FillAlpha",          # float,  alpha modifier applied to all plot item fills
            "ErrorBarSize",       # float,  error bar whisker width in pixels
            "ErrorBarWeight",     # float,  error bar whisker weight in pixels
            "DigitalBitHeight",   # float,  digital channels bit height (at 1) in pixels
            "DigitalBitGap",      # float,  digital channels bit padding gap in pixels
            "PlotBorderSize",     # float,  thickness of border around plot area
            "MinorAlpha",         # float,  alpha multiplier applied to minor axis grid lines
            "MajorTickLen",       # ImVec2, major tick lengths for X and Y axes
            "MinorTickLen",       # ImVec2, minor tick lengths for X and Y axes
            "MajorTickSize",      # ImVec2, line thickness of major ticks
            "MinorTickSize",      # ImVec2, line thickness of minor ticks
            "MajorGridSize",      # ImVec2, line thickness of major grid lines
            "MinorGridSize",      # ImVec2, line thickness of minor grid lines
            "PlotPadding",        # ImVec2, padding between widget frame and plot area, labels, or outside legends (i.e. main padding)
            "LabelPadding",       # ImVec2, padding between axes labels, tick labels, and plot edge
            "LegendPadding",      # ImVec2, legend padding from plot edges
            "LegendInnerPadding", # ImVec2, legend inner padding from legend edges
            "LegendSpacing",      # ImVec2, spacing between legend entries
            "MousePosPadding",    # ImVec2, padding between plot edge and interior info text
            "AnnotationPadding",  # ImVec2, text padding around annotation labels
            "FitPadding",         # ImVec2, additional fit padding as a percentage of the fit extents (e.g. ImVec2(0.1f,0.1f) adds 10% to the fit extents of X and Y)
            "PlotDefaultSize",    # ImVec2, default size used when ImVec2(0,0) is passed to BeginPlot
            "PlotMinSize",        # ImVec2, minimum size plot frame can be when shrunk
        ]

    @property
    def LineWeight(self):
        """
        Plot item line weight in pixels.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.LineWeight, theme_value_types.t_float)

    @LineWeight.setter
    def LineWeight(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.LineWeight, theme_value_types.t_float, True, False, value)

    @property
    def Marker(self):
        """
        Marker specification.

        The value is a PlotMarker. Defaults to PlotMarker.NONE.
        """
        value = baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.Marker, theme_value_types.t_int)
        return None if value is None else make_PlotMarker(value)

    @Marker.setter
    def Marker(self, value):
        cdef int32_t value_int = int(make_PlotMarker(value))
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.Marker, theme_value_types.t_int, False, False, value_int)

    @property
    def MarkerSize(self):
        """
        Marker size in pixels (roughly the marker's "radius").

        The value is a float. Defaults to 4.
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.MarkerSize, theme_value_types.t_float)

    @MarkerSize.setter
    def MarkerSize(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.MarkerSize, theme_value_types.t_float, True, False, value)

    @property
    def MarkerWeight(self):
        """
        Plot outline weight of markers in pixels.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.MarkerWeight, theme_value_types.t_float)

    @MarkerWeight.setter
    def MarkerWeight(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.MarkerWeight, theme_value_types.t_float, True, False, value)

    @property
    def FillAlpha(self):
        """
        Alpha modifier applied to all plot item fills.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.FillAlpha, theme_value_types.t_float)

    @FillAlpha.setter
    def FillAlpha(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.FillAlpha, theme_value_types.t_float, False, False, value)

    @property
    def ErrorBarSize(self):
        """
        Error bar whisker width in pixels.

        The value is a float. Defaults to 5.
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.ErrorBarSize, theme_value_types.t_float)

    @ErrorBarSize.setter
    def ErrorBarSize(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.ErrorBarSize, theme_value_types.t_float, True, True, value)

    @property
    def ErrorBarWeight(self):
        """
        Error bar whisker weight in pixels.

        The value is a float. Defaults to 1.5.
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.ErrorBarWeight, theme_value_types.t_float)

    @ErrorBarWeight.setter
    def ErrorBarWeight(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.ErrorBarWeight, theme_value_types.t_float, True, False, value)

    @property
    def DigitalBitHeight(self):
        """
        Digital channels bit height (at 1) in pixels.

        The value is a float. Defaults to 8.
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.DigitalBitHeight, theme_value_types.t_float)

    @DigitalBitHeight.setter
    def DigitalBitHeight(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.DigitalBitHeight, theme_value_types.t_float, True, True, value)

    @property
    def DigitalBitGap(self):
        """
        Digital channels bit padding gap in pixels.

        The value is a float. Defaults to 4.
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.DigitalBitGap, theme_value_types.t_float)

    @DigitalBitGap.setter
    def DigitalBitGap(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.DigitalBitGap, theme_value_types.t_float, True, True, value)

    @property
    def PlotBorderSize(self):
        """
        Thickness of border around plot area.

        The value is a float. Defaults to 1.
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.PlotBorderSize, theme_value_types.t_float)

    @PlotBorderSize.setter
    def PlotBorderSize(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.PlotBorderSize, theme_value_types.t_float, True, True, value)

    @property
    def MinorAlpha(self):
        """
        Alpha multiplier applied to minor axis grid lines.

        The value is a float. Defaults to 0.25.
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.MinorAlpha, theme_value_types.t_float)

    @MinorAlpha.setter
    def MinorAlpha(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.MinorAlpha, theme_value_types.t_float, False, False, value)

    @property
    def MajorTickLen(self):
        """
        Major tick lengths for X and Y axes.

        The value is a pair of floats. Defaults to (10, 10).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.MajorTickLen, theme_value_types.t_float2)

    @MajorTickLen.setter
    def MajorTickLen(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.MajorTickLen, theme_value_types.t_float2, True, True, value)

    @property
    def MinorTickLen(self):
        """
        Minor tick lengths for X and Y axes.

        The value is a pair of floats. Defaults to (5, 5).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.MinorTickLen, theme_value_types.t_float2)

    @MinorTickLen.setter
    def MinorTickLen(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.MinorTickLen, theme_value_types.t_float2, True, True, value)

    @property
    def MajorTickSize(self):
        """
        Line thickness of major ticks.

        The value is a pair of floats. Defaults to (1, 1).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.MajorTickSize, theme_value_types.t_float2)

    @MajorTickSize.setter
    def MajorTickSize(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.MajorTickSize, theme_value_types.t_float2, True, False, value)

    @property
    def MinorTickSize(self):
        """
        Line thickness of minor ticks.

        The value is a pair of floats. Defaults to (1, 1).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.MinorTickSize, theme_value_types.t_float2)

    @MinorTickSize.setter
    def MinorTickSize(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.MinorTickSize, theme_value_types.t_float2, True, False, value)

    @property
    def MajorGridSize(self):
        """
        Line thickness of major grid lines.

        The value is a pair of floats. Defaults to (1, 1).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.MajorGridSize, theme_value_types.t_float2)

    @MajorGridSize.setter
    def MajorGridSize(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.MajorGridSize, theme_value_types.t_float2, True, False, value)

    @property
    def MinorGridSize(self):
        """
        Line thickness of minor grid lines.

        The value is a pair of floats. Defaults to (1, 1).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.MinorGridSize, theme_value_types.t_float2)

    @MinorGridSize.setter
    def MinorGridSize(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.MinorGridSize, theme_value_types.t_float2, True, False, value)

    @property
    def PlotPadding(self):
        """
        Padding between widget frame and plot area, labels, or outside legends (i.e. main padding).

        The value is a pair of floats. Defaults to (10, 10).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.PlotPadding, theme_value_types.t_float2)

    @PlotPadding.setter
    def PlotPadding(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.PlotPadding, theme_value_types.t_float2, True, True, value)

    @property
    def LabelPadding(self):
        """
        Padding between axes labels, tick labels, and plot edge.

        The value is a pair of floats. Defaults to (5, 5).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.LabelPadding, theme_value_types.t_float2)

    @LabelPadding.setter
    def LabelPadding(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.LabelPadding, theme_value_types.t_float2, True, True, value)

    @property
    def LegendPadding(self):
        """
        Legend padding from plot edges.

        The value is a pair of floats. Defaults to (10, 10).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.LegendPadding, theme_value_types.t_float2)

    @LegendPadding.setter
    def LegendPadding(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.LegendPadding, theme_value_types.t_float2, True, True, value)

    @property
    def LegendInnerPadding(self):
        """
        Legend inner padding from legend edges.

        The value is a pair of floats. Defaults to (5, 5).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.LegendInnerPadding, theme_value_types.t_float2)

    @LegendInnerPadding.setter
    def LegendInnerPadding(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.LegendInnerPadding, theme_value_types.t_float2, True, True, value)

    @property
    def LegendSpacing(self):
        """
        Spacing between legend entries.

        The value is a pair of floats. Defaults to (5, 0).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.LegendSpacing, theme_value_types.t_float2)

    @LegendSpacing.setter
    def LegendSpacing(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.LegendSpacing, theme_value_types.t_float2, True, True, value)

    @property
    def MousePosPadding(self):
        """
        Padding between plot edge and interior info text.

        The value is a pair of floats. Defaults to (10, 10).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.MousePosPadding, theme_value_types.t_float2)

    @MousePosPadding.setter
    def MousePosPadding(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.MousePosPadding, theme_value_types.t_float2, True, True, value)

    @property
    def AnnotationPadding(self):
        """
        Text padding around annotation labels.

        The value is a pair of floats. Defaults to (2, 2).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.AnnotationPadding, theme_value_types.t_float2)

    @AnnotationPadding.setter
    def AnnotationPadding(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.AnnotationPadding, theme_value_types.t_float2, True, True, value)

    @property
    def FitPadding(self):
        """
        Additional fit padding as a percentage of the fit extents (e.g. (0.1,0.1) adds 10% to the fit extents of X and Y).

        The value is a pair of floats. Defaults to (0, 0).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.FitPadding, theme_value_types.t_float2)

    @FitPadding.setter
    def FitPadding(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.FitPadding, theme_value_types.t_float2, False, False, value)

    @property
    def PlotDefaultSize(self):
        """
        Default size used for plots

        The value is a pair of floats. Defaults to (400, 300).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.PlotDefaultSize, theme_value_types.t_float2)

    @PlotDefaultSize.setter
    def PlotDefaultSize(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.PlotDefaultSize, theme_value_types.t_float2, True, True, value)

    @property
    def PlotMinSize(self):
        """
        Minimum size plot frame can be when shrunk.

        The value is a pair of floats. Defaults to (200, 150).
        """
        return baseThemeStyle._common_getter(self, <int>ImPlotStyleIndex.PlotMinSize, theme_value_types.t_float2)

    @PlotMinSize.setter
    def PlotMinSize(self, value):
        baseThemeStyle._common_setter(self, <int>ImPlotStyleIndex.PlotMinSize, theme_value_types.t_float2, True, True, value)

    @classmethod
    def get_default(self, str style_name):
        """Get the default style value for the given style name."""
        if style_name == "LineWeight":
            return 1.0
        elif style_name == "Marker":
            return make_PlotMarker(<int32_t>PlotMarker.NONE)
        elif style_name == "MarkerSize":
            return 4.0
        elif style_name == "MarkerWeight":
            return 1.0
        elif style_name == "FillAlpha":
            return 1.0
        elif style_name == "ErrorBarSize":
            return 5.0
        elif style_name == "ErrorBarWeight":
            return 1.5
        elif style_name == "DigitalBitHeight":
            return 8.0
        elif style_name == "DigitalBitGap":
            return 4.0
        elif style_name == "PlotBorderSize":
            return 1.0
        elif style_name == "MinorAlpha":
            return 0.25
        elif style_name == "MajorTickLen":
            return (10.0, 10.0)
        elif style_name == "MinorTickLen":
            return (5.0, 5.0)
        elif style_name == "MajorTickSize":
            return (1.0, 1.0)
        elif style_name == "MinorTickSize":
            return (1.0, 1.0)
        elif style_name == "MajorGridSize":
            return (1.0, 1.0)
        elif style_name == "MinorGridSize":
            return (1.0, 1.0)
        elif style_name == "PlotPadding":
            return (10.0, 10.0)
        elif style_name == "LabelPadding":
            return (5.0, 5.0)
        elif style_name == "LegendPadding":
            return (10.0, 10.0)
        elif style_name == "LegendInnerPadding":
            return (5.0, 5.0)
        elif style_name == "LegendSpacing":
            return (5.0, 0.0)
        elif style_name == "MousePosPadding":
            return (10.0, 10.0)
        elif style_name == "AnnotationPadding":
            return (2.0, 2.0)
        elif style_name == "FitPadding":
            return (0.0, 0.0)
        elif style_name == "PlotDefaultSize":
            return (400.0, 300.0)
        elif style_name == "PlotMinSize":
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


'''
cdef object extract_theme_value(baseTheme theme, str name, type target_class):
    """
    Helper function that takes a baseTheme and walks recursively to retrieve the value
    attached to the target name/class if this baseTheme is pushed. Returns None if the
    target name/class is not present at all.
    """
    cdef unique_lock[DCGMutex] m
    lock_gil_friendly(m, theme.mutex)
    if isinstance(theme, ThemeListWithCondition):
        return None # handled in another function
    if isinstance(theme, target_class):
        try:
            return getattr(theme, name)
        except AttributeError:
            pass
    cdef PyObject *child
    if theme.can_have_theme_child and theme.last_theme_child is not None:
        child = <PyObject*> theme.last_theme_child
        while (<baseItem>child) is not None:
            value = extract_theme_value(<baseTheme>child, name, target_class)
            if value is not None:
                return value
            child = <PyObject *>(<baseItem>child).prev_sibling
    return None


# UNFINISHED


More work needed to support theme conditions,
but also apply scaling
def resolve_theme(baseItem item, str name, type target_class) -> object:
    """
    Function that given a baseItem, a style/color name, and a target style or color class,
    resolves the theme value that is applied for this item. If it is not found for any parent,
    returns the default value.

    It can be used outside rendering to determines the style value
    that would be applied to an item during rendering.

    Note: currently does not work with ThemeListWithCondition
    """
    if not issubclass(target_class, baseTheme):
        raise TypeError("target_class must be a subclass of baseTheme")
    parent_tree = [item]
    item_parent = item.parent
    while item_parent is not None:
        parent_tree.append(item_parent)
        item_parent = item_parent.parent
    parent_tree = parent_tree[::-1]
    # TODO: for each item in parent_tree, build the list
    # of applicable ThemeListWithCondition. If a ThemeStopCondition
    # is found, reset the list for the next item
    # Starting from the top-most parent, iteratively apply
    # the theme lists with conditions, (stop if a ThemeStopCondition
    # is found), and then apply the theme list without conditions
    # Deduce the final value for the target name
    current_target_value = None
    for item in parent_tree:
        theme = item.theme
        # Apply theme conditions that should apply for the item
        #value = apply_theme_conditions(name, current_theme_conditions, item, target_class)
        #if value is not None:
        #        current_target_value = value
        # Apply the theme value
        if theme is not None:
            value = extract_theme_value(theme, name, target_class)
            if value is not None:
                current_target_value = value
            # Append conditions, reset when a ThemeStopCondition is met
            update_theme_conditions(theme, current_theme_conditions)
    try:
        if current_target_value is None:
            return target_class.get_default(name)
    except KeyError:
        raise KeyError(f"Style {name} not found")
    # catch if the class doesn't have a get_default
    except AttributeError:
        raise TypeError(f"{target_class} does not have a get_default method")
    return current_target_value

'''