Here are some technical details on how DearCyGui is designed:

## The rendering tree
Each DCG context is associated a single viewport, which corresponds to a system window.
This viewport is an item like any other, but cannot be replaced. Rendering starts from the viewports and spans to its children.

The children of any item are rendered recursively from the first one to the last one.
In practice, rather than holding a table of its children, each item only points to its LAST child. It is the responsibility of this child to render first its previous sibling before rendering itself. Then this previous sibling has the responsibility to render its previous sibling too before itself, etc.

As a result a strong impact of this design is that a parent does not draw its children itself, and cannot insert rendering commands between each item. This impacts the implementation of tables, layouts, etc.

There are pros and cons to this design choice. The original reason for this design choice is that I thought it was not possible to have a table of objects in Cython without the gil. In fact it is possible if one uses PyObject pointers.

All rendering items have a draw() function that renders the object. To avoid redundant code, most code in fact implement a class specific method that is called by draw(). This draw() function is implemented with noexcept nogil enforced, which means Cython is not allowed to access Python fields or to increase/decrease any object refcount. This constraint generates efficient C++ code that should be pretty close in performance to native C++ code.

The viewport holds some temporary information needed during rendering, which avoid passing arguments to draw().

Some parents define a clipping region, and rendering cannot be done by children outside the clipping region.

## Item locks

One of the main issues with DPG is it had a single lock to protect any item access during rendering. However it had issues and it was not uncommon to have deadlocks when doing multithreading due to the GIL.

DearCyGUI instead uses a lock per item. Locks are known to be very cheap when there is no contention, which is going to be almost always in DCG's usecase.

The lock rule to guarantee thread safety and no deadlock is:
The topmost lock in the rendering tree must be acquired before any lower lock.
For instance imagine you want to access an item field. You only need to lock this item. Now imagine you need to change the parent of the item. In that case you need to acquire the parent lock BEFORE acquiring the item lock. This complex mecanism is implemented by baseItem, and for simplicity, when moving an item, it is first detached of its former parent, and then attached to its new parent.
In that specific case, as the parent might change when the item lock is not acquired, baseItem implements locking first the item, then trying to lock the parent, and if it fails, unlock the item, then lock again the item, then try to lock the parent, etc.
In all other cases, the locks are always acquired in a specific order to guarantee the lock rule. For instance during rendering, the viewport lock is first held, then the lock of the last child, which then locks its previous siblings, etc. Then the first child renders itself, and locks the lock of its last child, etc. Thus during rendering, when an item is rendered, we hold the lock of this item, as well as all its next siblings, and the lock of its parent, all its next siblings, etc. As the rendering tree is ... a tree, that generally means only a portion of the locks of the tree is held at a given time.

As in practice the rendering of the item tree itself is not as expensive as can be other OS operations to prepare and finish rendering, the viewport is actually associated with three locks, such that one can access viewport fields or lock the main viewport lock while slow OS operations are done.

In order to avoid any deadlock caused by the gil, whenever an entry point holding the gil requires a lock, we actually first only 'try' to lock, and if we fail, then we release the gil and block until the lock is achieved.


## Child slots

There are several main classes of items from which all items derive. Almost all items derive from baseItem which defines an item that can have a tag, can be attached to parent, have siblings, etc. Exceptions to that are Callback and SharedValue.

Subclassing baseItem are some other base classes. uiItem, drawingItem, baseTheme, baseHandler, plotElement. Each of these will get into different child slots and are incompatible to each other as siblings. Any subclass of these elements can be siblings and children of the same parents. Each parent defines which children base class they support. It is similar but not equivalent to DPG children slots.

uiItem is the base class of most elements. It defines an object with a state, which accepts handlers, themes and optionally a Callback and a SharedValue. By default the position of the item corresponds to the current internal cursor position, which is incremented after every item (with a line jump by default). It accepts positioning arguments to override that.

drawingItem is a simpler class of elements which map to imgui drawing operations. They have no state maintained, no callback, theme, value, etc. Their coordinates are in screen space transformed by their parent (if in a window, the coordinates are offsetted. If in a plot, the coordinates are offsetted and scaled.)

baseTheme corresponds to theme elements that can be bound to items

baseHandler corresponds to handler elements that can be bound to items

plotElement corresponds to plot children and define the axes to which they relate to.

All element subclass these base classes and override their main rendering methods. It is possible to subclass these elements in Python or Cython and be inserted as siblings to elements of the same base class.

## Everything is attributes

In DPG, all items were associated with item configuration attributes, states and status. During item creation, some parameters were passed as mandatory as positional parameters.

DCG uses a slightly different paradigm, as no positional parameters are required anymore. In addition DCG uses the full potential of implementing Python extension classes that Cython enables to do easily. On every DCG item, one can access the attributes as you would in any python class. This is very fast, and enables significant performance gains compared to DPG's configure.

Under the hood, DCG implements all these attributes as class properties, and during initialisation, a table of all the properties, their names and their functions set read and write them are passed by Cython to Python. A docstring is passed to every attribute, thus one can use the help() command to get the information on an attribute. a Pyi is also generated by Cython to enable autocompletion in compatible code editors. Sadly this autocompletion is not useful when creating an item, but it is very well functionnal when accessing attributes.

When an item is created, DCG first initializes all class specific fields with default values. Then in a second step all the names parameters are converted into attributes.
Basically item creation is a loop doing:
```python
for (key, value) in kwargs.items():
    if hasattr(self, key):
        setattr(self, key, value)
```
In other words any optional parameter you pass during item creation is equivalent to setting the attribute of the same name after you have created the item.

Note that this is a slight abuse on our side on the intent of python extension attributes, are they are meant to be cheap access to object attributes (with potential cheap conversion), and more heavy functions should rather be implemented as functions. item.parent = other_item should probably not be an attribute in this spirit, but this allows to implement better compatibility with DPG.

In the spirit of everything is attributes, Themes override getattr and setattr in order to be able to set theme fields directly (and only what you have set is passed to the object).