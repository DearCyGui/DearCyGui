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
Everytime a widget is rendered, the internal cursor is moved down. If the no_newline attribute is set on an
item, then the cursor is moved right instead. Some items, such as `Separator` and `Spacer` enable to
add some vertical or horizontal space.

It is advised if possible to favor use these to correctly place your items, as the positioning will
respect the theme policy and scale properly with the global scale.

The current position of an item relative to its parent, the window, or the viewport can be retrieved
using the pos_to_parent, pos_to_window and pos_to_viewport attributes. Setting them will automatically
change the positioning policy from DEFAULT to being linked to the attribute you have set. When
the positions or sizes of parents and siblings change, the position attribute set will remain constant,
while the other might move freely.

It should be avoided if possible to directly position the items that way, as it does not scale well with
the global scale, the themes and the font sizes. However it has its useful use-cases.

For instance, one can implement dragging a button using these attributes. One can also overlap items.
Items set with a non-default policy will not move the default cursor for other items.

`Layout` objects are containers which can be a useful way to organize elements automatically.
`Layout` objects have the special property that their state is an OR of the item states. For instance
if an item is clicked, the Layout will also be considered clicked. The callback of a `Layout` is called
whenever it is detected that the available region has changed, and it is meant that the parent `Layout`
of an item will eventually set the pos_* attributes of its children to organize them in a custom Layout.

For simplicity, two common `Layout` classes are provided: `VerticalLayout` and `HorizontalLayout`. They will
automatically set the pos_* fields and no_newline fields of their children to organize them
in a vertical only or horizontal only layout. They accept doing left, right, center, or justified
positioning.

## Items sizes

Most items accept having their size set by a `width` and a `height` attribute.
These correspond to a *desired* size, and are automatically scaled by the global scale, unless
the `no_scale` attribute is set.

A positive value directly correspond to a desired pixel size (putting aside the global scale). Note
some items unfortunately do not include some parts of their elements in this size.

A negative value is used to mean a delta relative to the available size inside the parent. For instance
a value of "-1" means "remaining size inside the parent - 1".

A zero value means "default value", and depending to the item can mean fitting to the smallest size containing the content,
or to a fixed size determined by the theme.

The real pixel size obtained when the item is drawn is stored in `rect_size`, and changes to that value can be caught using
the `ResizeHandler`. In some cases, it can be useful to use this handler to fit an item that is outside the bounds,
or to center one.

