# What is a callback ?

A *Callback* is a function that is called in response to an event.
Various objects in **DearCyGui** take a callback attribute in order to
react to various events.

# Callback input arguments

A valid callback takes zero, one, two or three positional arguments.
The first argument passed is the object to which the callback was attached.
The second argument is the object for which the callback was triggered.
It can be the same as the first argument, but for instance in the case
of handlers attached to an item, that is the way to know for which item
the handler reacted. Indeed a handler can be attached to many items.
The third argument is specific to how the callback was issued. In the
case of UI items, it is generally the same as `item.value`. For handlers,
see the description of the handler. The idea is that the value should
be something immediately useful to react to the callback.

If the callback takes less than three positional arguments, then
only a subset of the arguments is passed, in the above order of priority.
Non-positional arguments are ignored, and thus will take whatever default
value you have given them. This is one trick to pass by value local
variables for temporary functions defined inside another function.

# Attaching custom data to an item

Note that all items accept a `user_data` attribute, in which you can store
any information. This might be useful in your callbacks.
**DearCyGui** objects do not accept setting new attributes, but if you subclass
in Python these objects, this restriction is lifted. If you want to implement
various or complex interactions, it is recommended to subclass the target
**DearCyGui** objects and attach them new attributes and methods. Callbacks
can be class methods.

# Callback thread

Callbacks are by default issued in a single secondary thread. This can be
replaced by a custom behaviour by setting the queue attribute of the Context.
Note that appending callbacks use Python's global interpreter lock, and thus
you should ensure not to have it locked for too long to not stall rendering.

# Handlers

In general, it is best to avoid issuing more callbacks than needed. Handlers
are much cheaper than callbacks. Thus for instance it is much more recommanded
if one want to react to various key events, to have one handler per key, rather
than one handler for all keys, and filter in the callback (in particular
because in this specific case the handler has to check all possible keys of
all possible keyboards).

In order to only trigger callbacks when needed, various tools are available
to filter the handlers. We'll delve into them later in the last section.

---

# Base handlers

Handlers can detect various specific events happening to your event.
The complete list of handlers can be found in the Available items section,
but here are the description of a few:

- `ActiveHandler`. An user-interactable item is considered active when the
user is interacting with it. For instance in the case of a Button,
a button is considered active as soon as the mouse is pressed on it.
When the mouse is released, the button is not active anymore.
`ActivatedHandler` and `DeactivatedHandler` enable to only trigger callbacks
when the active status changes, rather than all frames with the status.
While checking for activation is ok for most use-cases, in the general
case, it is recommended to favor using the item's main callback. Indeed
this callback has been calibrated to correspond to the most common needs
related to these items. For instance, if the user presses the mouse on a
button, them moves the mouse out of the button area, and then unclicks,
the main `Button` callback will not trigger, while both `ActivatedHandler`
and `DeactivatedHandler` will have triggered.

- `ClickedHandler`. This handler is equivalent to checking that the item
is hovered and that a click occured. On the other hand, `MouseClickHandler`
does not care where the click occured.

- `HoverHandler`. This handler, and its peers `GotHoverHandler` and `LostHoverHandler`,
enable to react to the mouse hovering above an item. In the general case,
only a single item is considered hovered. Note that a single item
can be active as well, and that it might not be the same as the hovered
item (see above example with the Button).
Note if you need to display a message when the target item is hovered,
that you might have you need met by a Tooltip.

- `ResizeHandler`. Every UI item has a rect_size attribute that defines
its size in pixels (which might not be the requested size, due to
rounding, scaling, etc). The `ResizeHandler` triggers its callback
whenever that rect_size changes.

- `OpenHandler/CloseHandler/ToggledOpenHandler/ToggledCloseHandler`. 
Some UI items (`TreeNode`, `CollapseHeader`, `Window`) can be reduced
in a closed state (which does NOT mean the item is destroyed), in
which only a small header of the item is shown. Open refers to
the whole content being shown. These four handlers enable to react
to these states, and the changes of these states.

- `RenderHandler/GotRenderHandler/LostRenderHandler`. An item is considered
"CPU-rendered" if during `render_frame` the item was seen by the rendered.
To be considered rendered, an item must be in the render tree, its
show attribute must be set to True, as well as all its parents. In
addition, no parent must have skipped rendering some its children
with clipping optimizations. Being rendered does not mean that
the item is visible (many parents do not do clipping optimizations,
or are very conservative about it), but it needs to be rendered
to be visible.
Note that the size and position of an item might converge in a few frames
after it gets rendered, as some parent items take guesses during rendering
about the size of their children and only take the real value the next frame.
It is important to note though that an item that is not rendered will not
have any of its handlers run. `OtherItemHandler` can be used to run handlers
on an item that might not be rendered, but that should be rarely needed.
When an item gets hidden by a parent or by show being set to False, the handlers
are run one last time, in order to properly trigger `LostRenderHandler`, as well
as all the other status loss handlers.

---

# Combining handlers
In general it is best to avoid issuing callbacks, due to Python overhead. 
Combining handlers enable to create complex checks inside the handlers, in 
order to only issue the callbacks when specific events are met. 
`HandlerList` has an op attribute that can be set to `ALL/ANY/NONE`, and thus 
can be used to check when the condition of a handler is not met, or when 
the condition of a handler is met, but not the one of another one, etc. 
Any logical combination is possible by using a tree of HandlerList. 
However `HandlerList` will often not issue an interesting third argument 
to the callback, or it might be that running a specific handler is 
particularly heavy (for instance a `CustomHandler`, or a significant 
subtree of handlers in a HandlerList). In that case a `ConditionalHandler` 
is very useful. The first handler of its children list is only run if the 
`ALL/ANY/NONE` condition is met on the other elements of the children list. 
Finally a `CustomHandler` enables to insert Python checks inside the handlers, 
but do not abuse of it and be careful not to stuck rendering.