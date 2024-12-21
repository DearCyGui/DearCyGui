# Thread Safety

**DearCyGui** is fully thread-safe and uses a separate mutex for each item.
A mutex is a lock that a single thread can keep at a single time.
Any time a field of an item is read or written to, the lock is held.

The only except is the viewport, which has several mutexes in order to protect
various parts, and enable to access some of its fields while work is occuring.

Locking a mutex that is not already locked is pretty cheap on modern CPU architectures,
which makes this solution viable. The significant advantage, against a single global
mutex, is that item fields can be read and written to while other internal work
(such as rendering) is occuring. Indeed if a thread owns a mutex, other threads
attempting to lock will wait until the mutex is released.

When having many mutexes, in order to prevent deadlocks, one technique is to
use a specific locking order at all times. Since **DearCyGui** objects are stored
in a tree structure and have at most a single parent, and possibly many children,
a natural locking order is that if you need a lock on an item and one of its ancestors,
you need to lock the ancestors' mutexes first.
During rendering this order is respected.

```
order of mutex locking during rendering
lock of the viewport
for each child:
    lock the viewport child
    render recursively the child
    unlock the viewport child
```

The above process occurs recursively at every node of the tree.
If the mutex of an item is held in another thread, rendering is paused
until it is released. Thus it might be useful in some scenarios to lock the mutex
in your program in order to make sure rendering does not occur while you are modifying
several properties of an item in the rendering tree, and avoid showing on one frame an
item in an incomplete state.

If you need to lock several items, this gets harder to get right. Indeed as stated,
the lock of the parents must be held before the lock of the children is held.
And attempting to read or write an item's field is internally locking the mutex.
Thus for instance these codes are easy mistakes that will cause a hang:

```python
a.parent = b
C = a.context

# The mutex can be locked
# with the mutex context manager
# or with lock_mutex()

with a.mutex:
    # Potential deadlock because accessing
    # any b field locks its mutex
    is_single_child = len(b.children) == 1

with a.mutex:
    # if a is in the rendering tree,
    # the viewport is an ancestor, thus
    # this can hang
    C.viewport.handlers += ...
```

The simplest way to avoid complications is to not use the mutex, or to lock the viewport mutex instead
of the item mutex. You can also use the `parents_mutex` property, which will lock the mutexes of all ancestors.