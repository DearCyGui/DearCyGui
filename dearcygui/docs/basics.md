# Starting with **DearCyGui**

## What is **DearCyGui**

**DearCyGui** is a **Python** library
to write *GUI* applications.
It is based on **Dear ImGui** to manage and render the GUI.
**DearCyGui** is mainly written in **Cython**, thus the name.
**Cython** knowledge is not required.

**Python** is quite handy,
but is not performant enough to render at full frame-rate
complex UIs. The main idea of this library is to create items
and declare how they should behave, and let the library handle
rendering the items and check the conditions you registered for.
The library is written mostly using **Cython** code,
which is converted into efficient **C ++** code and
compiled. The interest of using **Cython** is that it simplifies
writing interaction code with **Python**. **DearCyGui** features
a lot of these to ease the programmer's life.

## Why should I consider using **DearCyGui** ?

There are a lot of available *GUI* libraries with
**Python** support. **DearCyGui** targets only **Python**.

Here are the main features of **DearCyGui**:

- Cross-platform. It uses GL and SDL3 under the hood.
- Free and MIT License. It can be integrated into industrial applications.
- Fast. Item creation and configuration is optimized and can be
significantly faster than on other frameworks. In addition rendering uses
**Dear ImGui** which does an efficient work at packing draw calls and has
a reduced overhead.
- Type hinting and docstrings. There are a lot of available *GUI* libraries with
**Python** support. **DearCyGui** targets only **Python**, which thus has
first class support.
- Low CPU/GPU usage. Rendering can be skipped when it is not needed.
- Support for custom widgets. As with many (but not all) *GUI*, it is possible
to subclass all items in custom classes. This simplifies making items
with custom behaviours.
- Not too verbose, not too slim. Several features allow the code to be easy
to read (use of properties, passing properties values during init, `with`
syntax, type hinting, etc.) However there is little unspecified *magic*
happening. Items won't be attached to a parent unless you specified one
(using `with` or `parent`), and events won't be magically received because
you named you class methods with a specific naming scheme (you have to
register them with handlers).
- Avoiding calling **Python** code when not needed. **Python** is nice,
but a bit heavy. **DearCyGui** features an extended event filter system
to only call your **Python** callbacks when required. For instance,
you can register a callback that will be called only the first frame
an item is rendered, or when it is resized. You can combine conditions
and add custom ones.
- Interactable drawing items. It is possible to have custom interactable
regions in drawing space, and thus implement various drawing interactions,
such as interacting with a circle, a rectangle, a point, etc. Such possible
interactions that can be implemented are resizing, clicking, rotating, 
displaying a tooltip when hovered, etc.


## When should I consider using another framework ?

You might consider using another framework if one of these
points is problematic for you:

- No touchscreen support. It is very much keyboard and mouse.
- It is still in heavy developpement, and thus there might be
small changes there and there in variable names, etc.
- It will update with the latest ImGui releases, which can
introduce some small changes in variable names and behaviours.
- Right now it has mostly been developped and tested on Linux,
but it aims for Windows and MAC support as well.
- No 'native' look. It uses the native file dialog, but besides
that won't use the system colors or style.
- This project is not developped by a company. Thus no paid support
or other support plans.
- While there is no current plan for that, it might stop being
maintained one day. The last project I maintained lasted 10 years.


## The Context

The first item you need to create is a *Context*.
```python
    C = dcg.Context()
```

The Context manages the state of your UI items and
all items reference it. The context is stored
in every item in the `context` attribute.

It is possible to subclass the context, in order to
attach additional information for your items, or
to extend some features. For instance it is possible
to log item creation and deletion, or to add custom
configuration arguments to all items.

## The viewport and the rendering tree

With the Context is attached a single *"Viewport"*.
The Viewport basically corresponds to your application window as seen
by the operating system. It has a title, decoration, etc (this is configurable).
Every frame, rendering starts from the viewport and, in a tree traversal fashion,
all children of the viewport, their children, the children of their children,
etc will be rendered. An item outside of this *rendering* tree can
exist, but will not be rendered. In addition items attached in the rendering tree
can prevent being rendered using the `show` attribute."

Items can be created as soon as the Context is created,
but for anything to be displayed, you need to initialize the viewport.

```python
    C.viewport.initialize()
```

Once attached to the rendering tree, you do not need
to retain a reference to the item for it to remain alive. You can
retain a reference if you want to access later the object.

Rendering the tree is then performed using
```python
    while C.running:
        C.viewport.render_frame()
```

Note that due to OS-es limitations (see Advanced section), context creation, `initialize()` and `render_frame` must all be performed in the same thread.

## Building the rendering tree

To attach an item to another, several options are available.

- You can set the `parent` attribute of your
item to a reference to the parent or its `tag`.

- You can append the item to the `children` attribute of the target parent.

- Using the `with` syntax on the parent
will attach all items inside the `with` to that parent.
```python
        with my_parent_item:
            item = create_my_new_item()
```

- By default items try to attach to a parent unless
`attach=False` is set during item creation.

## Creating an item

All items in **DearCyGui** are built with the following properties:
- *Everything* is properties. Items can be configured by writing to their attributes
at any time, and their current state can be retrieved by reading their attributes.
- All items take the context instance as mandatory positional first argument. You can add more
when subclassing.
- All other arguments of standard **DearCyGui** items (except very few exceptions) are optionnal
keyword arguments. By default all item attributes are set to reasonable default values, and for
most boolean attributes, the default value is `False`. Some exceptions are `show`, or `enabled`
which are set to `True` by default.
- At item creation the default value of the attributes are set, and the keyword arguments are
then converted in a later phase in `__init__` into setting the attributes of the same name (except
very few exceptions for compatibility reasons). It is important to take this into account when
subclassing an object, as you might want to delay (or not) the configuration of the attributes.
Note when subclassing, the attributes are already initialized to the default value when entering
your custom class's `__init__`.
Essentially, the execution flow of item creation when subclassing is

> The Item's memory structure is initialized and values set to the default value
>
> Your `__init__()`
>
> (Optional) At some point in your `__init__` you call the base class `__init__` method
>
> The base class `__init__` iterates on the keyword parameters and tries to set them as attributes.

## Thread safety

Each item is protected by its own mutex instally and it is safe to manipulate items from several threads.
It is possible to lock the internal mutex, but with special care (see the advanced section).

## Autocompletion

**DearCyGui** provides .pyi files to help linters suggest code completion and show documentation.
Alternatively you can use this program to visualize the documentation of each item and see
available fields.

## Debugging

**DearCyGui** includes a debugging module that helps track item lifecycle and interactions.

Simply use:
```python
import dearcygui.utils.debug as dcg
dcg.set_debug_verbosity(target_level) # 0, 1, 2, 3 or 4
```

The debug modules redefine all dcg items with a wrapped version of the same name. No other modifications are required.

Alternatively, one can use the debug items only for specific items

```python
import dearcygui as dcg
import dearcygui.utils.debug as dcg_debug
dcg_debug.set_debug_verbosity(target_level) # 0, 1, 2, 3 or 4
...
button_to_debug = dcg_debug.Button(C, ...)
...
```

The debug module also provides a debug wrapper for the Context which provides debug information at the creation and deletion of all items, as well as configuration. To debug attribute accesses, the debug items are needed. The debug context also provides a debug callback queue which will log callback accesses and their time to execute. It can be manually used with a normal `Context` by passing `dcg_debug.DebugQueue()` to the `queue` parameter.

The verbosity levels are:
- 0: no debug output
- 1: Basic callback timing
- 2: Warnings for possible mistakes (default)
- 3: Full item state changes and property access
- 4: Exhaustive configuration details and special method calls

