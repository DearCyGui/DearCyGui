## Widgets

**DearCyGui** supports many widgets to implement various interactions with the users, for instance:

- `Button`, to trigger an event on a click
- `Checkbox`, to enable or disable something
- `Slider`, to pick a value with a slider
- `InputValue` and `InputText`, to manually enter a value or text
- `Combo`, `ListBox` or `RadioButton` to select an item in a list
- `Menu`, to add menu options to a window or the viewport.

In addition, various objects enable to contain groups of objects and assign them a behaviour.

- `TreeNode`, `CollapsingHeader` to quickly show/hide items with a click
- `Tab` to have a header and a subwindow subwindow with content corresponding to the selected header
- `ChildWindow`, to encapsulate on or several items into a dedicated limited space

Almost all widgets have a *value* attribute which contains a value related to the
widget main state. For instance the checkbox's value indicate if the item is selected
or not. The slider's value contains the value at which the slider is set.
In order to share values between widgets, one can use the shareable_value attribute,
which returns an instance of a SharedValue which can be passed to other items. The
type of the shared value must be compatible for this. It can also be useful to manipulate
shared values if you need to reference in your code the value of an item before this
item is created (you then pass the shared value you created earlier).

Widgets can react to various user-interactions. See the *Callbacks* section for more details.

## Positioning elements

UI element positioning uses a top-left origin coordinate system.
When inside a `dcg.Window`, the backend library ImGui does maintain an internal cursor with (0, 0)
being the first position of the cursor inside the window. This position is affected by various theme elements
determining the size of window borders and padding.
Everytime a widget is rendered, the internal cursor is moved down. If the `no_newline` attribute is set on an
item, then the cursor is moved right instead. Some items, such as `Separator` and `Spacer` enable to
add some vertical or horizontal space.

It is advised if possible to favor these to correctly place your items, as the positioning will
respect the theme policy and scale properly with the global scale.

The current position of an item relative to its parent, the window, or the viewport can be retrieved
using the `state.pos_to_parent`, `state.pos_to_window` and `state.pos_to_viewport` attributes.
They are read-only attributes and cannot be written to. Instead the position of elements is controled
by the `x` and `y` attributes. The default values are 0 and 0, and are interpreted as "current cursor position".
When a value is assigned to these fields, it is interpreted as an offset against the cursor position.
More advanced, it is also possible to write a string formula to these fields, in which case the formula
is interpreted in viewport coordinates, and the cursor is not moved after the item is drawn.

It should be avoided if possible to directly write to the `x` and `y` fields, however it has its useful use-cases.
For instance the formula x="parent.xc-self.width/2" will center horizontally the item in the parent area,
and maintain this placement even if the parent or the item have their size changed.

A more general, and prefered way to control placement is to use `Layout` objects. They are containers which organize elements automatically. The vanilla `Layout` object does not implement any placement, but calls its callback whenever the item placement may need to change (area resize, etc). It can be used as default class to subclass as you can attach UI items to it. For positioning control, two common `Layout` classes are provided: `VerticalLayout` and `HorizontalLayout`. They will automatically set the x/y/no_newline fields of their children to organize them
in a vertical only or horizontal only layout. They accept doing left, right, center, or justified
positioning, as well as wrapping.


## Items sizes

Most items accept having their size set by a `width` and a `height` attribute.
These correspond to a *desired* size, and are automatically scaled by the global scale.

A positive value directly correspond to a desired pixel size (putting aside the global scale). Note
some items unfortunately do not include some parts of their elements in this size.

A negative value is used to mean a delta relative to the available size inside the parent. For instance
a value of "-1" means "remaining size inside the parent - 1".

A zero value means "default value", and depending to the item can mean fitting to the smallest size containing the content,
or to a fixed size determined by the theme.

The real pixel size obtained when the item is drawn is stored in `state.rect_size`, and changes to that value can be caught using
the `ResizeHandler`. In some cases, it can be useful to use this handler to fit an item that is outside the bounds,
or to center one.

## String formulas

The fields `x`, `y`, `width` and `height` do accept string formulas to specify how the field should be dynamically updated.

The following keywords are supported:
    - `fillx`: Fill available width
    - `filly`: Fill available height
    - `fullx`: Full parent content width (no position offset)
    - `fully`: Full parent content height (no position offset)
    - `parent.width`: Width of the parent item (larger than fullx as contains parent borders)
    - `parent.height`: Height of the parent item (larger than fully as contains parent borders)
    - `viewport.width`: Width of the viewport (application window)
    - `viewport.height`: Height of the viewport (application window)
    - `min`: Take minimum of two size values
    - `max`: Take maximum of two size values
    - `mean`: Calculate the mean (average) of two or more size values
    - `dpi`: Current global scale factor
    - `self.width`: Reference to the width of the current item
    - `self.height`: Reference to the height of the current item
    - `item.width`/`item.height`: Reference to another item's size (item must be in globals()/locals())
    - `{self, parent, item}.{x1, x2, xc, y1, y2, yc}`: Reference to left/center/right/top/bottom of the current, parent, or a target item.
    - `+`, `-`, `*`, `/`, `//`, `%`, `**`: Arithmetic operators. Parentheses can be used for grouping.
    - `abs()`: Absolute value function
    - Numbers: Fixed size in pixels (NOT dpi scaled. Use dpi keyword for that)

Note that referencing another item's attribute in the string (except for the special parent and viewport keywords) uses a CPython implementation feature that is not available on Pypy. In addition, it might break in future releases. A more reliable way to reference another item's size is by reading the `x`, `y`, `width` and `height` fields of the target item. They return a reference to the item's x1/y1/width/height that can be inserted in the string formula. For instance `x=item.x + "5 * dpi"` is the same as `x="item.x1 + 5 * dpi"`.

When set to the `width` or `height` attribute of an item, the string is interpreted in unscaled pixel space (1 unit = 1 pixel on screen). In other words, `width = 5` is equivalent to `width = "5 * dpi"`.

When set to the `x` or `y` attribute of an item, the string is interpreted in unscaled pixel coordinate space of the viewport (top left origin).

Internally, the formula is converted into a series of objects to compute the result, and the resolution does not use Python (for speed). When referencing a dynamic value, the current value is used. For instance self.width will resolve to the self.state.rect_size value of the previous frame (self being not yet rendered at this step of rendering), and item.x1 will use the item.state.pos_to_viewport value for this frame if item is rendered before self, or the value for the previous frame if it is rendered after. It is possible to reference objects outside the rendering tree, in which case the last know value is used. When a change is detected in the resolution of the formula, cpu rendering is restarted at the end of the frame (skipping gpu presentation, unless `always_present_to_gpu` is set), in order to converge before presenting. As a result of all these implementation details, the use of string formulas is not free. Prefer using the default cursor when possible.

Reading the `x`, `y`, `width` and `height` attribute of an item returns a item referencing the target property in a string formula (for the reason explained in the Note above). Use `state.pos_to_viewport/pos_to_window/pos_to_parent/rect_size` to get the actual current size and position in unscaled pixels of the item. It is possible to convert the item reference into a floating point representation `float(item.x)` but it is not recommended. It is not possible to retrieve the previous string representation passed.
