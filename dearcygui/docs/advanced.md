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

-----

# Multiple contexts

Several contexts can be created. However one limitation is that all contexts must be created in the same thread (and `render_frame` must always occur from that thread). This limitation is because some OSes do not support window management outside of the thread they were created, and thus the SDL library, which *DearCyGui* uses, enforces everywhere this constraint.

Objects between contexts cannot be shared. An item cannot change of context.

-----

# Offscreen rendering

Contexts do not need to be associated with an OS window.

It is possible to render into a texture (see below how to import the rendering into another library), and not show the result with *DearCyGui*. For that you need to set the `visible` property of the viewport to False.

As a result of not having an associated OS window, *DearCyGui* will not receive keyboard and mouse events. You can use the context's `inject_*` methods to workaround that.


-----
# Cython subclassing

Subclassing items is a useful tool for code organization and creating custom items. Python subclassing should be sufficient for most needs, but here are a few cases where you would want to subclass in Cython instead. Indeed, compared to Python, in Cython you can replace the draw() function of the item, which is the function called when the item is rendered. You have access to an internal API to help you implement custom behaviors.

Here is a list of the advantages of Cython subclassing
- Speed (Cython is faster)
- Expressing complex draw logic that cannot be expressed efficiently by decomposing into several simpler items.
- No lag to impact the visual. You have access to the latest states of the item and can affect the rendering of the frame directly. For instance changing the color of a button when hovered can be done without any delay with Cython subclassing, while using callbacks will introduce at least one frame delay.

But some significant disadvantages are present
- Less portable code. Your code will need to be compiled (dynamically with pyximport or statically with a setup.py or similar). The compilation has to occur everytime DearCyGui is updated, which complicates code distribution. Note however that in future releases, improvements will be brough to this area, introducing stable ABI, with compiled code compatibility for minor releases.
- More care is needed when writing the code. You have access to *DearCyGui* internals, and thus you must use it correctly. No checks will occur.

For examples and documentation of the available API, please refer to the related demo, but also to the cython codes in DearCyGui's utils directory. The cython codes in this directory have exactly the same API access as you would have for your own Cython subclassing.

-----

# Interoperating with other libraries

## Importing external content as images

### Numpy arrays

The easiest way to integrate content from external libraries into *DearCyGui* is to import into textures images produced by other libraries as numpy arrays. This is easy, but can be sub-par performance wise (in particular it will have higher latency).

### OpenGL

In order to share an OpenGL texture directly (and thus avoid GPU<->CPU transfers and synchronizations), you need to use a "shared" GL context for the library. *DearCyGui does not support creating a shared context for itself, starting from the OpenGL context of an external library. However most external libraries support creating a shared context from an existing context, or using an externally created context.

The demos give examples on shared context creation, but essentially
*DearCyGui* supports two ways of sharing *OpenGL* textures with external libraries.

- Direct context creation

```python
my_context.create_new_shared_gl_context(major, minor)
```
This method of the context will attempt to create a new GL desktop context of version major.minor, this context can then be imported for the external library, or used manually by setting it current with the call `make_current` and releasing it with `release`. Remember that a context can be current on at maximum one thread at time, and using another context releases it. For instance if you render in after `render_frame`, the context has to be made current again as render_frame used its own context.

- 'Current context' method

The second common method for GL context sharing among external libraries is to make current the target context when the external library's context is created (usually a special method or flag is needed as well).

This can be done so with the `rendering_context` property:
```python
with my_context.rendering_context:
    # DearCyGui's OpenGL context is current now
    [...] create my context [...]
```

Now that you have a shared context, the texture GL identifiers can be shared between your library and *DearCyGui*. We do not support yet importing external libraries, but the GL texture ID of an existing texture can be obtained easily.
```
texture = dcg.Texture(C)
# allocate the GL texture and fix the size
texture.allocate(width=512, height=512, num_chans=3)
gl_id = texture.texture_id
```

This ID can generally be imported by external libraries to write to, or read from.

Note that some libraries do not flush implicitly rendering commands, thus you must issue a command flush command to have their result rendered ('flush'/'finish'/releasing the context).

### CUDA and OpenCL

Cuda and OpenCL content can be shared with *DearCyGui*. The method is similar to the 'Current context' method described above, but with specific Cuda/OpenCL calls. In particular OpenCL needs compatible implementations and the `cl_khr_gl_sharing` extension. If you need portable code, prefer using OpenGL.


## Exporting *DearCyGui*'s content to an external library

### As numpy array

In order to export *DearCyGui*'s content as a numpy array:

- The frame buffer (the output of DearCyGui's full frame rendering) can be
obtained as a dcg.Texture as the `framebuffer` property of the viewport. However
by default this field is not filled, as it incurs a cost. To enable this feature you must set the `retrieve_framebuffer` property to True.
Note the texture instance generated is different every frame.

- Once the texture is retrieved, you can download the content using the `read` method of textures.

As GPU rendering usually occurs with a non-negligeable delay, using `read()` every frame just after `render_frame()` is not a good performance behaviour. If you need to do that and are limited by performance, prefer triggering `read()` in another thread, or to apply `read()` on the texture of the previous frame, rather than the last frame.

### As an OpenGL texture

The method is the same as above, but the `texture_id` is used to import the texture in an external library as a GL texture, rather than a numpy array. 

## Syncing rendering between *DearCyGui* and the external library

If you do not sync rendering between *DearCyGui* and your external code,
you may have visual artifacts. Here's how to avoid them.

### Forcing the rendering to finish before sharing

When using a numpy array to share between *DearCyGui* and an external library,
the rendering of the array has to be finished, copied to the CPU, then copied back to the destination. The operation to finish rendering is done automatically when the arrays are exported. However the synchronization has to be performed more manually for the other methods.

A GPU is usually able to execute several rendering commands in parallel. To prevent the rendering of the operation using the texture to occur while (or before) the rendering of the operation rendering the texture, you must introduce fences.

The simplest fence is to force manually all rendering commands to finish. This operation is called `glFinish()` and is usually available in most libraries. If not, a traditional technique (which can be used for *DearCyGui*) is to read (numpy array) a portion of the content of the rendered texture.

### GL fences

As you might have deduced from reading the previous section, performance-wise there might be little gains from using a shared texture and `glFinish` over transferring numpy arrays. Both need rendering of the shared texture to completly finish before submitting new rendering commands, thus leaving the GPU dry, and introducing a small latency.

To solve this issue, and have a real performance and latency gain (for instance you are doing heavy real-time rendering using OpenGL and displaying a GUI with *DearCyGui* on top), you must submit GL fences in the GL command stream.

In order to hide the complexity of managing these fences, the submission of these fences is generally done in a 'acquire'/'release' semantic.

- For CUDA, you 'map' the GL texture to be accessible by CUDA (this will submit a GPU fence to wait for GL rendering before CUDA rendering), and when you have submitted your work using the texture, you 'unmap' it (this will submit a GPU fence for the CUDA rendering to finish before GL rendering using the texture).

- For OpenCL, clEnqueueAcquireGLObjects and clEnqueueReleaseGLObjects can acquire and release the texture (same as CUDA above)

- For OpenGL, as many external libraries do not currently have API to generate fences, *DearCyGui* introduces the properties `gl_begin_read`, `gl_end_read`, `gl_begin_write` and `gl_end_write` for textures. These will handle the generation and handling of GL sync objects. The external context has to be current when issuing these commands.

In more details, what happens is that at the beginning of every frame, *DearCyGui* inserts a wait in its GL command stream for any GL sync object found on the input textures. At the end of every frame, it generates a GL sync object, shared among all used textures and the framebuffer. Texture's `gl_begin_*` properties introduce in the current GL context a wait command on the corresponding GL sync object, in order to not write to a texture before it has finished being read, nor read to a texture before it is being rendered to. Finally the `gl_end_*` commands flush the current GL stream and generate a GL sync, which is then used by *DearCyGui*.

Note all these synchronization add minimal overhead, compared to using a single GL context for all rendering, which we do not allow, as it would be easy for the user to use the main rendering context incorrectly. For instance OpenGL mandates that the context must be released from any other thread before using it (`render_frame`), and it isn't practical for *DearCyGui* to enforce such constraint for the user.

If you use these techniques, you will not have any visual glitches, and will maximize performance.

# Updating the content of a texture frequently

The above techniques will typically be used in combination with the `Image`, `ImageButton` and `DrawImage` items which can display a texture. If you need to update the texture frequently (for instance every frame), or checks specific states that might need a texture update, several options are possible:

- Using a render callback. The callback will be called asynchronously every frame. The advantage is that the computation can be slow without affecting framerate. The disadvantage is that there is a small lag between states changes and the visual.
- Inserting your update after `render_frame`.
- Subclassing `CustomHandler` and implement there your update logic. This solution is the preferred one, as it has the advantage of having no lag. Indeed `CustomHandler` is run just after the item is processed for rendering (its states are up to date), but before the rendering is submitted to the GPU. Thus inserting a write to the texture will directly impact the current frame. Note however that you must be careful not to do heavy computation as frame rendering will wait for `CustomHandler` to return.

A fourth solution would be to use Cython subclassing, but as it is not strictly needed here, it's best to avoid it due to the several constraints it brings.
