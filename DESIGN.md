# DearCyGui Technical Design

This document outlines the architectural design principles and implementation details of DearCyGui.

## Core Architecture

### Rendering Tree

DearCyGui organizes all UI elements in a hierarchical tree structure:

- Each DCG **Context** is associated with a single **Viewport** (system window)
- The Viewport serves as the root node of the rendering tree
- Rendering traverses the tree depth-first, starting from the root
- Each item is responsible for rendering itself and orchestrating its children

#### Rendering Process

The initial of DearCyGui was that unlike traditional GUI frameworks:

1. Parents don't directly render their children
2. Each item points to its LAST child, creating a linked structure
3. Each child renders its previous sibling first, forming a recursive chain

This made it complicated however to implement some functionalities, such as Tables.

Thus DearCyGui moved to a more traditional tree traversal:
1. Each parent is rendered, iterating on each child to get it rendered.

All this traversal and rendering is performed with efficient C++ code generated through Cython's nogil capabilities.

### Item Management

#### Threading Safety

DearCyGui uses a lock-per-item approach for thread safety, rather than a global lock:

- Each UI element has its own lock
- Locks must be acquired in parent-to-child order (topmost first)
- Multiple thread-safe patterns are implemented for item manipulation
- The viewport uses three distinct locks to enable concurrent operations

#### Lock Acquisition Strategy

To prevent deadlocks with Python's GIL:
- Entry points first attempt to acquire locks with a non-blocking try
- If acquisition fails, the GIL is released before blocking
- This pattern prevents deadlocks between the GIL and item locks

### Class Hierarchy

DearCyGui implements a flexible component model through specialized base classes:

1. **baseItem**: Core parent class for most elements
   - Provides tagging, parent-child relationships, and sibling management

2. **Major Subclasses**:
   - **uiItem**: Interactive elements with state, theme support, and callbacks
   - **drawingItem**: Lightweight drawing primitives with no state
   - **baseTheme**: Theme components that can be bound to items
   - **baseHandler**: Event handling components
   - **plotElement**: Specialized elements for data visualization

3. **Child Slots**:
   - Each parent defines compatible child types
   - Children must match the parent's supported base classes
   - Siblings must share compatible base classes

## API Design Principles

### Everything is Attributes

DearCyGui uses Python's attribute model for all item configuration:

- No required positional parameters in constructors, except for the context, mandatory for all items
- All properties are implemented as Python item properties
- Fast attribute access through Cython's property system
- Full docstring support for IDE integration
- PYI type-stub generation for autocompletion

```python
# All parameters are passed as attributes
button = dcg.Button(context, label="Click Me", width=100)

# Equivalent to:
button = dcg.Button(context)
button.label = "Click Me"
button.width = 100
```

### Context-Based Programming

- All items require a Context instance at creation
- Python's `with` statement creates parent-child relationships
- Layout containers automatically manage child positioning

```python
with dcg.Window(context, label="My Window"):
    dcg.Text(context, value="Hello World")  # Automatically becomes child of Window
```

### Asyncio Integration

DearCyGui provides comprehensive support for asynchronous programming:

- Coroutines are accepted as callbacks 
- Various helpers such as `AsyncPoolExecutor` are provided for background task management
- Viewport rendering loop can be integrated into existing event loops

## Advanced Features

### Theming System

Themes are first-class objects that can be:
- Created and modified at runtime
- Applied to specific items or item hierarchies
- Combined through the ThemeList aggregator

```python
with dcg.ThemeList(context) as theme:
    dcg.ThemeColorImGui(context, button=(100, 50, 200))
    dcg.ThemeStyleImGui(context, frame_rounding=5.0)

button.theme = theme  # Apply to a specific item
```

### Layout System

DearCyGui offers multiple layout options:
- Absolute and dynamic positioning (x, y coordinates)
- Auto-layout with content-aware spacing
- Alignment controls (LEFT, RIGHT, CENTER)
- Responsive sizing using expressions (width="0.5*viewport.width")
- Specialized containers (HorizontalLayout, VerticalLayout, etc.)

### Framebuffer Access

The viewport provides direct access to its framebuffer for:
- Screenshot capabilities
- Custom rendering effects
- Image capture for recording/sharing

---

## Implementation Notes

### Python Extension Integration

DearCyGui leverages Cython to create true Python extension types:
- Item classes are real Python classes, not just wrapped C++ objects
- Full support for Python introspection (dir(), help(), etc.)
- Support for subclassing in both Python and Cython

### Memory Management

- Python garbage collection for all items
- Automatic cleanup of children when parents are destroyed
- Thread-safe reference counting for shared resources

### Performance Considerations

- Rendering code runs without the GIL for maximum performance
- Items track their visibility state to avoid unnecessary drawing
- Context.viewport.wait_for_input enables efficient CPU usage
- ImGui's immediate-mode architecture limits the need for state synchronization
