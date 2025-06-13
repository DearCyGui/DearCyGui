[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

DearCyGui is a powerful, performant GUI library for Python that offers a refreshing approach to creating modern graphical user interfaces. Built with performance in mind, it bridges Python's ease of use with the speed of Dear ImGui through efficient Cython bindings.

![Demo Screenshot](images/demo.gif)

## Key Features

### 🚀 Performance First
- **Blazing Fast Rendering**: Efficient rendering based on Dear ImGui
- **Low CPU/GPU Usage**: Renders only when needed
- **Multi-thread ready**: It is safe and efficient to update the UI from any thread.
- **Smooth Animation**: Maintains high framerates even with complex, animated interfaces

### 🧩 Rich Widget Collection
- **Core UI Elements**: Buttons, sliders, checkboxes, input fields, and more
- **Advanced Components**: 
  - Color pickers with multiple formats (RGB, HSV, HEX)
  - Tables with sorting, filtering, and custom styling
  - Tree nodes and collapsible sections
  - Tabbed interfaces
  - Tooltips and context menus
  - Pop-up and modal windows
  - Build you own custom widgets and dashboards

### 📊 Data Visualization
- **Extensive Plotting Library**: Built on ImPlot for high-performance data visualization
- **Plot Types**: Line, scatter, bar, histogram, pie, heat maps, error bars, stem plots, and more
- **Scientific Features**: Logarithmic axes, time series, annotations, and legends
- **Interactive Elements**: Pan, zoom, and data selection capabilities

### 🎨 Styling & Theming
- **Complete Theme Control**: Customize colors, sizing, padding, and more
- **Theme Inheritance**: Create theme hierarchies for consistent UI design
- **Four Theme Types**:
  - `ThemeColorImGui`: Control colors for UI widgets
  - `ThemeStyleImGui`: Adjust sizes and spacing
  - `ThemeColorImPlot`: Customize plot colors
  - `ThemeStyleImPlot`: Fine-tune plot styling
  - `ThemeList`: Combine multiple themes
  - Your custom items can adapt to the theme

### 💻 Developer Experience
- **Pythonic API**: Clean, intuitive interface designed specifically for Python developers
- **Object-Oriented**: Full subclassing support for extending functionality
- **Context Management**: Use Python's `with` statement for cleaner code
- **Auto-Layout**: Dynamic sizing and positioning with flexible constraints
- **Extensive Documentation**: Comprehensive guides and examples
- **Asyncio compatible**: Integrate the rendering into an asyncio loop, or use asyncio in your callbacks

### 🔍 Advanced Features
- **Drawing API**: Create custom antialiased graphics with various shapes and advanced visuals such as dashed lines
- **DPI Awareness**: Proper scaling on high-DPI displays
- **Customizable Tooltips**: Add helpful information throughout your application
- **Font Support**: Use custom fonts with FreeType rendering

## Quick Examples

### Basic Window with Button

```python
import dearcygui as dcg

def button_clicked(sender, target, data):
    print("Button clicked!")

# Create context and initialize viewport
C = dcg.Context()
C.viewport.initialize(title="Hello DearCyGui", width=400, height=200)

# Create a window with a button
with dcg.Window(C, label="My First Window", primary=True):
    dcg.Button(C, label="Click Me!", callback=button_clicked)

# Main event loop
while C.running:
    C.viewport.render_frame()
```

### Data Visualization Example

```python
import dearcygui as dcg
import numpy as np

# Create sample data
x = np.linspace(0, 10, 100)
y1 = np.sin(x)
y2 = np.cos(x)

# Create context and window
C = dcg.Context()
C.viewport.initialize(title="Plotting Example", width=600, height=400)

with dcg.Window(C, label="Plot Demo", primary=True):
    with dcg.Plot(C, label="Trigonometric Functions", height=-1, width=-1) as plot:
        # Configure axes
        plot.X1.label = "x"
        plot.Y1.label = "y"
        
        # Add data series
        dcg.PlotLine(C, X=x, Y=y1, label="sin(x)")
        dcg.PlotLine(C, X=x, Y=y2, label="cos(x)")

# Main loop
while C.running:
    C.viewport.render_frame()
```

### Custom Styling

```python
import dearcygui as dcg

C = dcg.Context()
C.viewport.initialize(title="Styled UI", width=400, height=300)

# Create a theme
with dcg.ThemeList(C) as my_theme:
    # Customize colors
    dcg.ThemeColorImGui(C, 
        button=(100, 50, 200),       # Purple buttons
        button_hovered=(130, 80, 230), 
        text=(240, 240, 240),        # Light text
        window_bg=(40, 40, 50)       # Dark background
    )
    # Customize styles
    dcg.ThemeStyleImGui(C,
        frame_rounding=5.0,          # Rounded corners
        frame_padding=(10, 5)        # Padding inside frames
    )

# Apply theme to a window
with dcg.Window(C, label="Styled Window", primary=True, theme=my_theme):
    dcg.Text(C, value="This window has custom styling!")
    dcg.Button(C, label="Styled Button")
    dcg.Slider(C, label="Slider", min_value=0, max_value=100)

while C.running:
    C.viewport.render_frame()
```

## Installation

```bash
pip install dearcygui
```

For the latest development version:

```bash
git clone --recurse-submodules https://github.com/DearCyGui/DearCyGui
cd DearCyGui
pip install .
```

## System Requirements

- **Platforms**: Windows, macOS, Linux
- **Python**: 3.10+
- **Dependencies**: freetype, automatically installed with pip. Does not depend on numpy.
- **Optional dependencies**: skia-python (svg support), uvloop (faster asyncio), pymd4c (Markdown), numpy and imageio (Demos)

## Documentation & Resources

- **Tutorials**: Getting Started Guide
- **Demo Gallery**: [https://github.com/DearCyGui/Demos](https://github.com/DearCyGui/Demos)
- **Documentation**: Extensive docstrings for all items. Documentation on the main concepts available in the `docs` folder
- **Examples**: The `main_demo` folder contains a runnable and readable demo of most features

## Why DearCyGui?

- **Unlike Tkinter/PyQt/wxPython**: No complex layout managers or event loops to manage
- **Unlike other Dear ImGui bindings**: Higher-level API designed specifically for Python
- **Unlike web-based solutions**: Native performance without browser dependencies
- **Perfect for**: Data visualization tools, scientific applications, mini-games, debugging interfaces

## Community & Support

- **GitHub Issues**: [Report bugs](https://github.com/DearCyGui/DearCyGui/issues)
- **Discussions**: [Join our Discord](https://discord.gg/sxYmbzaCvq)

## Credits

DearCyGui is built upon several excellent open-source projects:

- [Dear ImGui](https://github.com/ocornut/imgui) - Immediate mode GUI library
- [ImPlot](https://github.com/epezent/implot) - Plotting library for Dear ImGui
- [Cython](https://cython.org/) - C-extensions for Python
- [SDL3](https://www.libsdl.org/) - Cross-platform development library
- [FreeType](https://www.freetype.org/) - Font rendering library
- [Delaunator](https://github.com/delfrrr/delaunator-cpp) and [Constrainauthor](https://github.com/kninnug/Constrainautor) - For concave polygon rendering

## License

DearCyGui is available under the MIT License. See the LICENSE file for more information.

---

*Portions of this software are copyright © 2024 The FreeType Project (www.freetype.org). All rights reserved.*
