from libc.stdint cimport uint32_t, int32_t, int64_t
from libcpp cimport bool
from libcpp.atomic cimport atomic

from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .c_types cimport DCGMutex, DCGVector, DCGString, ValueOrItem,\
    unique_lock, defer_lock_t
from .types cimport Vec2

"""
Thread safety:
. The gil must be held whenever a cdef class or Python object
  is allocated/deallocated or assigned. The Cython compiler will
  ensure this. Note that Python might free the gil while we are
  executing to let other threads use it.
. All items are organized in a tree structure. All items are assigned
  a mutex.
. Whenever access to item fields need to be done atomically, the item
  mutex must be held. Item edition must always hold the mutex.
. Whenever the tree structure is going to be edited,
  the parent node must have the mutex lock first and foremost.
  Then the item mutex (unless the item is being inserted, in which
  case the item mutex is held first). As a result when a parent
  mutex is held, the children are fixed (but not their individual
  states).
. During rendering of an item, the mutex of all its parent is held.
  Thus we can safely edit the tree structure in another thread (if we have
  managed to lock the relevant mutexes) while rendering is performed.
. An item cannot hold the lock of its neighboring children unless
  the parent mutex is already held. If there is no parent, the viewport
  mutex is held.
. As imgui is not thread-safe, all imgui calls are protected by a mutex.
  To prevent dead-locks, the imgui mutex must be locked first before any
  item/parent mutex. During rendering, the mutex is held.
"""

"""
Variable naming convention:
. Variable not prefixed with an underscore are public,
  and can be accessed by other items.
. Variable prefixed with an underscore are private, or
  protected. They should not be accessed by other items,
  (except for subclasses).
"""

cdef void lock_gil_friendly_block(unique_lock[DCGMutex] &m) noexcept

cdef inline void lock_gil_friendly(unique_lock[DCGMutex] &m,
                                   DCGMutex &mutex) noexcept:
    """
    Must be called to lock our mutexes whenever we hold the gil
    """
    m = unique_lock[DCGMutex](mutex, defer_lock_t())
    # Fast path which will be hit almost always
    if m.try_lock():
        return
    # Slow path
    lock_gil_friendly_block(m)

cdef void ensure_correct_im_context(Context context) noexcept nogil

cdef inline void clear_obj_vector(DCGVector[PyObject *] &items) noexcept:
    cdef int32_t i
    cdef object obj
    for i in range(<int>items.size()):
        obj = <object> items[i]
        Py_DECREF(obj)
    items.clear()

cdef inline void append_obj_vector(DCGVector[PyObject *] &items, item_list) noexcept:
    for item in item_list:
        Py_INCREF(item)
        items.push_back(<PyObject*>item)

cdef class Context:
    ### Read-only public variables ###
    cdef DCGMutex mutex
    # Mutex that must be held for any
    # call to imgui, glfw, etc
    cdef DCGMutex imgui_mutex
    cdef atomic[int64_t] next_uuid
    cdef Viewport viewport
    cdef void* imgui_context # imgui.ImGuiContext
    cdef void* implot_context # implot.ImPlotContext
    cdef uint32_t[5] prev_last_id_button_catch # for custom buttons
    cdef uint32_t[5] cur_last_id_button_catch
    ### protected variables ###
    cdef Callback _on_close_callback
    cdef object _queue
    ### private variables ###
    cdef bint _started
    cdef object __weakref__
    ### public methods ###
    cdef void queue_callback_noarg(self, Callback, baseItem, baseItem) noexcept nogil
    cdef void queue_callback_arg1obj(self, Callback, baseItem, baseItem, baseItem) noexcept nogil
    cdef void queue_callback_arg1key(self, Callback, baseItem, baseItem, int32_t) noexcept nogil
    cdef void queue_callback_arg1button(self, Callback, baseItem, baseItem, int32_t) noexcept nogil
    cdef void queue_callback_arg1float(self, Callback, baseItem, baseItem, float) noexcept nogil
    cdef void queue_callback_arg1value(self, Callback, baseItem, baseItem, SharedValue) noexcept nogil
    cdef void queue_callback_arg1key1float(self, Callback, baseItem, baseItem, int32_t, float) noexcept nogil
    cdef void queue_callback_arg1button1float(self, Callback, baseItem, baseItem, int32_t, float) noexcept nogil
    cdef void queue_callback_arg2float(self, Callback, baseItem, baseItem, float, float) noexcept nogil
    cdef void queue_callback_arg2double(self, Callback, baseItem, baseItem, double, double) noexcept nogil
    cdef void queue_callback_arg1button2float(self, Callback, baseItem, baseItem, int32_t, float, float) noexcept nogil
    cdef void queue_callback_arg4int(self, Callback, baseItem, baseItem, int32_t, int32_t, int32_t, int32_t) noexcept nogil
    cdef void queue_callback_arg3long1int(self, Callback, baseItem, baseItem, int64_t, int64_t, int64_t, int32_t) noexcept nogil
    cdef void queue_callback_argdoubletriplet(self, Callback, baseItem, baseItem, double, double, double, double, double, double) noexcept nogil
    cdef void queue_callback_arg1int1stringvector(self, Callback, baseItem, baseItem, int32_t, DCGVector[DCGString]) noexcept nogil
    cdef void queue_callback(self, Callback, baseItem, baseItem, object) noexcept
    cpdef void push_next_parent(self, baseItem next_parent)
    cpdef void pop_next_parent(self)
    cpdef object fetch_parent_queue_back(self)
    cpdef object fetch_parent_queue_front(self)
    # Helpers to write custom handlers without locking the gil
    # No validation is performed on the arguments.
    # button, key and key_chord are imgui values that should
    # be obtained by getting the int representation of the corresponding
    # Button, Key or KeyChord enum.
    # Must be called from inside draw()
    cdef Vec2 c_get_mouse_pos(self) noexcept nogil # negative pos means invalid
    cdef Vec2 c_get_mouse_prev_pos(self) noexcept nogil  
    cdef Vec2 c_get_mouse_drag_delta(self, int32_t button, float threshold) noexcept nogil
    cdef bint c_is_mouse_down(self, int32_t button) noexcept nogil
    cdef bint c_is_mouse_clicked(self, int32_t button, bint repeat) noexcept nogil
    cdef int32_t c_get_mouse_clicked_count(self, int32_t button) noexcept nogil
    cdef bint c_is_mouse_released(self, int32_t button) noexcept nogil
    cdef bint c_is_mouse_dragging(self, int32_t button, float delta) noexcept nogil
    cdef bint c_is_key_down(self, int32_t key) noexcept nogil
    cdef int32_t c_get_keymod_mask(self) noexcept nogil
    cdef bint c_is_key_pressed(self, int32_t key, bint repeat) noexcept nogil
    cdef bint c_is_key_released(self, int32_t key) noexcept nogil

"""
Main item types
"""

"""
baseItem:
An item that can be inserted in a tree structure.
It is inserted in a tree, attached with be set to True
In the case the parent is either another baseItem or the viewport (top of the tree)

A parent only points to the last children of the list of its children,
for the four main children categories.

A child then points to its previous and next sibling of its category
"""
cdef class baseItem:
    ### Read-only public variables managed by this class ###
    cdef Context context
    cdef int64_t uuid
    cdef DCGMutex mutex
    cdef baseItem parent
    cdef baseItem prev_sibling
    cdef baseItem next_sibling
    cdef drawingItem last_drawings_child
    cdef baseHandler last_handler_child
    cdef uiItem last_menubar_child
    cdef plotElement last_plot_element_child
    cdef uiItem last_tab_child
    cdef AxisTag last_tag_child
    cdef baseTheme last_theme_child
    cdef drawingItem last_viewport_drawlist_child
    cdef uiItem last_widgets_child
    cdef Window last_window_child
    ### Read-only public variables set by subclasses during cinit ###
    cdef bint can_have_drawing_child
    cdef bint can_have_handler_child
    cdef bint can_have_menubar_child
    cdef bint can_have_plot_element_child
    cdef bint can_have_tab_child
    cdef bint can_have_tag_child
    cdef bint can_have_theme_child
    cdef bint can_have_viewport_drawlist_child
    cdef bint can_have_widget_child
    cdef bint can_have_window_child
    cdef bint can_have_sibling
    cdef int32_t element_child_category
    cdef itemState* p_state # pointer to the itemState. set to NULL if the item doesn't have any.
    ### protected variables ###
    cdef DCGVector[PyObject*] _handlers # type baseHandler. Always empty if p_state is NULL.
    ### private variables ###
    cdef int32_t _external_lock
    cdef object __weakref__
    cdef object _user_data
    ### public methods ###
    cdef void lock_parent_and_item_mutex(self, unique_lock[DCGMutex]&, unique_lock[DCGMutex]&)
    cdef void lock_and_previous_siblings(self) noexcept nogil
    cdef void unlock_and_previous_siblings(self) noexcept nogil
    cpdef void attach_to_parent(self, target_parent)
    cpdef void attach_before(self, target_before)
    cpdef void detach_item(self)
    cpdef void delete_item(self)
    cdef void set_previous_states(self) noexcept nogil
    cdef void run_handlers(self) noexcept nogil
    cdef void update_current_state_as_hidden(self) noexcept nogil
    cdef void propagate_hidden_state_to_children_with_handlers(self) noexcept nogil
    cdef void propagate_hidden_state_to_children_no_handlers(self) noexcept
    cdef void set_hidden_and_propagate_to_siblings_with_handlers(self) noexcept nogil
    cdef void set_hidden_and_propagate_to_siblings_no_handlers(self) noexcept
    cdef void set_hidden_no_handler_and_propagate_to_children_with_handlers(self) noexcept nogil
    cdef void set_hidden_and_propagate_to_children_no_handlers(self) noexcept
    ### protected methods ###
    #cdef void _copy(self, object)
    ### private methods ###
    cdef void _copy_children(self, baseItem)
    cdef bint _check_rendered(self)
    cdef void _detach_item_and_lock(self, unique_lock[DCGMutex]&)
    cdef void _delete_and_siblings(self)


# The capabilities are set during item creation
# and indicate which itemStateValues are valid
cdef struct itemStateCapabilities:
    bint can_be_active
    bint can_be_clicked
    bint can_be_deactivated_after_edited
    bint can_be_dragged
    bint can_be_edited
    bint can_be_focused
    bint can_be_hovered
    bint can_be_toggled
    bint has_position
    bint has_rect_size
    bint has_content_region

cdef struct itemStateValues:
    bint hovered  # Mouse is over the item + overlap rules of mouse ownership
    bint active # Item is 'active': mouse pressed, editing field, etc.
    bint focused # Item has focus
    bint[5] clicked # <int>imgui.ImGuiMouseButton_COUNT
    bint[5] double_clicked
    bint[5] dragging
    Vec2[5] drag_deltas # only valid when dragging
    bint edited # text fields, etc
    bint deactivated_after_edited
    bint open # menu open, etc
    Vec2 pos_to_viewport
    Vec2 pos_to_window
    Vec2 pos_to_parent
    Vec2 rect_size # size on screen in pixels
    Vec2 content_region_size # size available to the children in pixels
    Vec2 content_pos
    bint rendered # No optimization due to parent menu not open or clipped

cdef struct itemState:
    ### Read-only public variables set by subclasses during cinit ###
    itemStateCapabilities cap
    ### Read-only public variables - updated in draw() and when attached/detached ###
    itemStateValues prev # state on the previous frame
    itemStateValues cur # state on the current frame


cdef class ItemStateView:
    cdef baseItem _item  # Reference to the original item
    cdef itemState _state_copy
    cdef itemState *p_state

    # Factory method to create a view for a specific item
    @staticmethod
    cdef ItemStateView create(baseItem item)


cdef class ItemStateCopy:
    cdef baseItem _item  # Reference to the original item
    cdef itemState _state

    # Factory method to create a view for a specific item
    @staticmethod
    cdef ItemStateCopy create_from_view(ItemStateView view)


cdef void update_current_mouse_states(itemState&) noexcept nogil


cdef class Viewport(baseItem):
    ### Public read-only variables
    cdef int32_t frame_count # frame count
    cdef bint skipped_last_frame
    cdef itemState state
    # For timing stats
    cdef int64_t last_t_before_event_handling
    cdef int64_t last_t_before_rendering
    cdef int64_t last_t_after_rendering
    cdef int64_t last_t_after_swapping
    cdef int64_t t_first_skip
    cdef int64_t delta_event_handling
    cdef int64_t delta_rendering
    cdef int64_t delta_swapping
    cdef int64_t delta_frame
    ### Public read-write variables ###
    cdef bint wait_for_input
    cdef bint always_submit_to_gpu
    # Temporary info to be accessed during rendering
    # Shouldn't be accessed outside draw()
    cdef float global_scale # Current scale factor to apply to all rendering
    cdef bint redraw_needed # Request the viewport to redraw right away without displaying
    cdef double[2] scales # Draw*: Current multiplication factor (integrates global_scale) for all coordinates
    cdef double[2] shifts # Draw*: Current shift for all coordinates
    cdef Vec2 window_pos # Coordinates (Viewport space) of the parent window
    cdef Vec2 parent_pos # Coordinates (Viewport space) of the direct parent (skipping drawing item parents)
    cdef Vec2 parent_size # Content region size (in pixels) of the direct parent
    cdef bint in_plot # Current rendering occurs withing a plot
    cdef bint plot_fit # Current plot is fitting the axes to the data
    cdef float thickness_multiplier # scale for the thickness of all lines (Draw*)
    cdef float size_multiplier # scale for the size of all Draw* elements.
    cdef bint[6] enabled_axes # <int>implot.ImAxis_COUNT. Enabled plot axes.
    # Temporary scratch space to be accessed during rendering
    # Shouldn't be accessed outside draw()
    cdef DCGVector[float] temp_point_coords # Temporary storage for point coordinates
    cdef DCGVector[float] temp_normals # Temporary storage for normals data
    cdef DCGVector[uint32_t] temp_colors # Temporary storage for color data
    cdef DCGVector[uint32_t] temp_indices # Temporary storage for indices data
    # Storage of current drag-drop item if any
    cdef baseItem drag_drop
    # OS drop
    cdef bint drop_is_file_type
    cdef DCGVector[DCGString] drop_data
    cdef bint os_drop_pending
    cdef bint os_drop_ready
    cdef object pending_drop
    ### private variables ###
    cdef DCGMutex _mutex_backend
    cdef void *_platform # platformViewport
    cdef void *_platform_window # SDL_Window
    cdef bint _initialized
    cdef bint _retrieve_framebuffer
    cdef object _frame_buffer
    cdef Callback _resize_callback
    cdef Callback _close_callback
    cdef baseFont _font
    cdef baseTheme _theme
    cdef bint _disable_close
    cdef int32_t _cursor # imgui.ImGuiMouseCursor
    cdef float _scale
    cdef double _target_refresh_time
    ### public methods ###
    cdef void coordinate_to_screen(self, float *dst_p, const double[2] src_p) noexcept nogil
    cdef void screen_to_coordinate(self, double *dst_p, const float[2] src_p) noexcept nogil
    cdef void ask_refresh_after(self, double monotonic) noexcept nogil # might refresh before, in which case you should call again
    cdef void force_present(self) noexcept nogil
    cdef Vec2 get_size(self) noexcept nogil
    cdef void *get_platform_window(self) noexcept nogil
    ### private methods ###
    cdef void __check_initialized(self)
    cdef void __check_not_initialized(self)
    cdef void __on_resize(self)
    cdef void __on_close(self)
    cdef void __on_drop(self, int32_t, const char*)
    cdef void __render(self) noexcept nogil


cdef class Callback:
    cdef object callback
    cdef int32_t num_args

# Rendering children

cdef inline void draw_drawing_children(baseItem item,
                                       void* drawlist) noexcept nogil:
    if item.last_drawings_child is None:
        return
    cdef PyObject *child = <PyObject*> item.last_drawings_child
    while (<baseItem>child).prev_sibling is not None:
        child = <PyObject *>(<baseItem>child).prev_sibling
    while (<baseItem>child) is not None:
        (<drawingItem>child).draw(drawlist) # drawlist is imgui.ImDrawList*
        child = <PyObject *>(<baseItem>child).next_sibling

cdef inline void draw_menubar_children(baseItem item) noexcept nogil:
    if item.last_menubar_child is None:
        return
    cdef PyObject *child = <PyObject*> item.last_menubar_child
    while (<baseItem>child).prev_sibling is not None:
        child = <PyObject *>(<baseItem>child).prev_sibling
    while (<baseItem>child) is not None:
        (<uiItem>child).draw()
        child = <PyObject *>(<baseItem>child).next_sibling

cdef inline void draw_plot_element_children(baseItem item) noexcept nogil:
    if item.last_plot_element_child is None:
        return
    cdef PyObject *child = <PyObject*> item.last_plot_element_child
    while (<baseItem>child).prev_sibling is not None:
        child = <PyObject *>(<baseItem>child).prev_sibling
    while (<baseItem>child) is not None:
        (<plotElement>child).draw()
        child = <PyObject *>(<baseItem>child).next_sibling

cdef inline void draw_tab_children(baseItem item) noexcept nogil:
    if item.last_tab_child is None:
        return
    cdef PyObject *child = <PyObject*> item.last_tab_child
    while (<baseItem>child).prev_sibling is not None:
        child = <PyObject *>(<baseItem>child).prev_sibling
    while (<baseItem>child) is not None:
        (<uiItem>child).draw()
        child = <PyObject *>(<baseItem>child).next_sibling

cdef inline void draw_viewport_drawlist_children(baseItem item) noexcept nogil:
    if item.last_viewport_drawlist_child is None:
        return
    cdef PyObject *child = <PyObject*> item.last_viewport_drawlist_child
    while (<baseItem>child).prev_sibling is not None:
        child = <PyObject *>(<baseItem>child).prev_sibling
    while (<baseItem>child) is not None:
        (<drawingItem>child).draw(NULL)
        child = <PyObject *>(<baseItem>child).next_sibling

cdef inline void draw_ui_children(baseItem item) noexcept nogil:
    if item.last_widgets_child is None:
        return
    cdef PyObject *child = <PyObject*> item.last_widgets_child
    while (<baseItem>child).prev_sibling is not None:
        child = <PyObject *>(<baseItem>child).prev_sibling
    while (<baseItem>child) is not None:
        (<uiItem>child).draw()
        child = <PyObject *>(<baseItem>child).next_sibling

cdef inline void draw_window_children(baseItem item) noexcept nogil:
    if item.last_window_child is None:
        return
    cdef PyObject *child = <PyObject*> item.last_window_child
    while (<baseItem>child).prev_sibling is not None:
        child = <PyObject *>(<baseItem>child).prev_sibling
    while (<baseItem>child) is not None:
        (<uiItem>child).draw()
        child = <PyObject *>(<baseItem>child).next_sibling


"""
Drawing Items
"""

cdef class drawingItem(baseItem):
    cdef bint _show
    #cdef void _copy(self, object)
    cdef void draw(self, void *) noexcept nogil # imgui.ImDrawList*
    pass


cdef bint button_area(Context context,
                      int32_t uuid,
                      Vec2 pos,
                      Vec2 size,
                      int32_t button_mask,
                      bint catch_ui_hover,
                      bint first_hovered_wins,
                      bint catch_active,
                      bool *out_hovered,
                      bool *out_held) noexcept nogil
"""
    Register a button area and check its status.
    Must be called in draw() everytime the item is rendered.

    The button area behaves a bit different to normal
    buttons and is not intended to create custom UI buttons,
    but to create interactable areas in drawings and plots.

    To enable various "items" to be overlapping and reacting
    to different buttons, button_area takes a button_mask indicating
    to which mouse button the area reacts to.
    The hovered state is individual to each button (and separate
    to the hovered state of UI items).
    However the active state is similar to UI items and shared with them.

    Context: the context instance
    uuid: Must be unique (for example the item uuid for which the button is registered).
        If you need to register several buttons for an item, you have two choices:
        - Generate a different uuid for each button. Each will have a different state.
        - Share the uuid for all buttons. In that case they will share the active (held) state.
    pos: position of the top left corner of the button in screen space (top-down y)
    size: size of the button in pixels
    button_mask: binary mask for the 5 possible buttons (0 = left, 1 = right, 2 = middle)
        pressed and held will only react to mouse buttons in button_mask.
        If a button is not in button_mask, it allows another overlapped
        button to take the active state.
    catch_ui_hover:
        If True, when hovered and top level for at least one button,
        will catch the UI hover (there is a single uiItem hovered at
        a time) state even if another (uiItem) item is hovered.
        For instance if you are overlapping a plot, the plot
        will be considered hovered if catch_ui_hover=False, and
        not hovered if catch_ui_hover=True. This does not affect
        other items using this function, as it allows several
        items to be hovered at the same time if they register
        different button masks.
        It is usually set to True to disable plot panning.
        If set to False, the UI hover state might still be registered
        if the button is hovered and no other item is hovered.
    first_hovered_wins:
        if False, only the top-level item will be hovered in case of overlap,
        no matter which item was hovered the previous frame.
        If True, the first item hovered (for a given button)
        will retain the hovered state as long as it is hovered.
        In general you want to set this to True, unless you have
        small buttons completly included in other large buttons,
        in which can you want to set this to False to be able
        to access the small buttons.
        Note this is a collaborative setting. If all items
        but one have first_hovered_wins set to True, the
        one with False will steal the hovered state when hovered.
    catch_active:
        Usually one want in case of overlapping items to retain the
        active state on the first item that registers the active state.
        This state blocks this behaviour by catching the active state
        even if another item is active. active == held == registered itself
        when the mouse clicked on it and no other item stole activation,
        and the mouse is not released.
    out_hovered:
        WARNING: Should be initialized to False before this call.
        Will be set to True if the button is hovered.
        if button_mask is 0, a simple hovering test is performed,
        without checking the hovering state of other items.
        Else, the button will be hovered only if it is toplevel
        for at least one button in button_mask (+ behaviour described
        in catch_hover)
    out_held:
        WARNING: Should be initialized to False before this call.
        Will be set to True if the button is held. A button is held
        if it was clicked on and the mouse is not released. See
        the description of catch_active.

    out_held and out_hovered must be initialized outside
    the function (to False), this behaviour enables to accumulate
    the states for several buttons. Their content has no impact
    of the logic inside the function.

    Returns True if the button was pressed (clicked on), False else.
    Only the first frame of the click is considered.

    This function is very fast and in most cases will be a simple
    rectangular boundary check.

    Use cases:
    - Simple hover test: button_mask = 0
    - Many buttons of similar sizes with overlapping and equal priority:
        first_hovered_wins = True, catch_ui_hover = True, catch_active = False
    - Creating a button in front of the mouse to catch the click:
        catch_active = True

    button_mask can be played with in order to have overlapping
    buttons of various sizes listening to separate buttons.
"""

"""
UI item
A drawable item with various UI states
"""

cdef class baseHandler(baseItem):
    cdef bint _enabled
    cdef Callback _callback
    # Check (outside rendering) if the handler can
    # be bound to the target. Should raise an error
    # if it is not.
    cdef void check_bind(self, baseItem)
    # Returns True/False if the conditions holds.
    cdef bint check_state(self, baseItem) noexcept nogil
    # Checks True/False if the condition holds, and if
    # True performs an action (for instance run the callback).
    cdef void run_handler(self, baseItem) noexcept nogil
    # Helper (implemented by baseHandler) to call the
    # attached callback. You may want to call it yourself
    # if you need to pass specific arguments
    cdef void run_callback(self, baseItem) noexcept nogil

cdef void update_current_mouse_states(itemState& state) noexcept nogil

cdef class uiItem(baseItem):
    ### Public read-write ###
    # In general state is public read-only. Managed by subclasses.
    # However external items are allowed to write the states to
    # request a state change of the item. In that case the appropriate
    # '....._requested' must be set to True.
    cdef itemState state
    # Variables below are maintained by uiItem but can be set externally.
    cdef bint no_newline
    cdef bint focus_requested
    cdef ValueOrItem requested_x
    cdef ValueOrItem requested_y
    cdef ValueOrItem requested_width
    cdef ValueOrItem requested_height
    ### Set by subclass (but has default value) ###
    cdef bint can_be_disabled
    cdef SharedValue _value
    ### Protected variables. Managed by uiItem by should be read by subclasses to alter rendering ###
    cdef DCGString _imgui_label # The hidden unique imgui label for this item
    cdef str _user_label # Label assigned by the user
    cdef bool _show # If False, rendering should not occur.
    cdef bint _show_update_requested # Filled by uiItem on show value change 
    cdef bint _enabled # Needs can_be_disabled. Contrary to show, the item is rendered, but if False is unactive.
    cdef bint _enabled_update_requested # Filled by uiItem on enabled value change 
    #cdef bint _dpi_scaling # Whether to apply the global scale on the requested size. -> defaulted to True. Can be skipped with string specifications.
    cdef baseFont _font
    cdef baseTheme _theme
    cdef DCGVector[PyObject*] _callbacks # type Callback
    cdef float _scaling_factor

    cdef void update_current_state(self) noexcept nogil
    cdef void update_current_state_subset(self) noexcept nogil
    cdef Vec2 get_requested_size(self) noexcept nogil
    # draw: main function called every frame to render the item
    cdef void draw(self) noexcept nogil
    # draw_item: called by the default implementation of draw.
    # It is recommanded to overwrite draw_item instead of draw
    # if possible as draw() handle the positioning, theme, font,
    # mutex locking, calling handlers, etc.
    # draw_item just needs to draw the item.
    cdef bint draw_item(self) noexcept nogil

"""
Shared values (sources)
"""
cdef class SharedValue:
    # Public read-only variables
    cdef DCGMutex mutex
    cdef Context context
    cdef int32_t _last_frame_update # Last frame count the value was updated
    cdef int32_t _last_frame_change # Last frame count the value changed (>= updated)
    cdef int32_t _num_attached # number of items the value is attached to
    # call when the value is updated. the second argument should be True if the
    # value changed, False else.
    cdef void on_update(self, bint) noexcept nogil
    cdef void inc_num_attached(self) noexcept nogil
    cdef void dec_num_attached(self) noexcept nogil


"""
Complex UI elements
"""

cdef class TimeWatcher(uiItem):
    pass

cdef class Window(uiItem):
    cdef bint x_update_requested
    cdef bint y_update_requested
    cdef bint width_update_requested
    cdef bint height_update_requested
    cdef int32_t _window_flags # imgui.ImGuiWindowFlags
    cdef bint _main_window
    cdef bint _resized
    cdef bint _modal
    cdef bint _popup
    cdef bint _no_resize
    cdef bint _no_title_bar
    cdef bint _no_move
    cdef bint _no_scrollbar
    cdef bint _no_collapse
    cdef bint _horizontal_scrollbar
    cdef bint _no_focus_on_appearing
    cdef bint _no_bring_to_front_on_focus
    cdef bint _has_close_button
    cdef bint _no_background
    cdef bint _no_open_over_existing_popup
    cdef Callback _on_close_callback
    cdef Vec2 _min_size
    cdef Vec2 _max_size
    cdef float _scroll_x
    cdef float _scroll_y
    cdef float _scroll_max_x
    cdef float _scroll_max_y
    cdef bint _collapse_update_requested
    cdef bint _scroll_x_update_requested
    cdef bint _scroll_y_update_requested
    cdef int32_t _backup_window_flags # imgui.ImGuiWindowFlags
    cdef ValueOrItem _backup_requested_x
    cdef ValueOrItem _backup_requested_y
    cdef ValueOrItem _backup_requested_width
    cdef ValueOrItem _backup_requested_height
    cdef void draw(self) noexcept nogil

"""
Plots

NOTE: it is unlikely you want to subclass this.
For custom plots, it is usually better to subclass
drawingItem.
"""
cdef class plotElement(baseItem):
    cdef DCGString _imgui_label
    cdef str _user_label
    cdef int32_t _flags
    cdef bint _show
    cdef int32_t[2] _axes
    cdef baseTheme _theme
    cdef void draw(self) noexcept nogil
    cdef void draw_element(self) noexcept nogil


# We don't define draw() for this class as
# the parent axis handles it.
cdef class AxisTag(baseItem):
    ### Public read-only variables ###
    cdef bint show
    cdef double coord
    cdef DCGString text
    cdef uint32_t bg_color # imgui.U32

"""
Bindable elements
"""

cdef class baseFont(baseItem):
    cdef void push(self) noexcept nogil
    cdef void pop(self) noexcept nogil

"""
Theme base class:
push: push the item components of the theme
pop: pop the item components of the theme
last_push_size is used internally during rendering
to know the size of what we pushed.
Indeed the user might add/remove elements while
we render.
"""

cdef class baseTheme(baseItem):
    cdef bint _enabled
    cdef DCGVector[int32_t] _last_push_size
    cdef void push(self) noexcept nogil
    cdef void pop(self) noexcept nogil

