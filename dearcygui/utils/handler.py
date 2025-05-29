from asyncio import Queue as asyncio_Queue, get_event_loop
from concurrent.futures import Future
import dearcygui as dcg
from threading import Event, Lock
from warnings import warn


def add_callbacks_to_handler(handler: dcg.baseHandler, *callbacks):
    """
    handlers only accept a single callback. This function
    creates a wrapping function that calls all callbacks, and
    attaches it to the handler.

    If the handler already has a callback set, it is added at the
    start of the wrapped callback chain.

    Note an alternative way is to duplicate the handler. If using
    base handlers, you can use the `copy` method to create a new
    handler with the same properties (works with handler trees as well).
    """
    with handler.mutex:
        callbacks_chain = []
        if handler.callback is not None:
            # If the handler already has a callback, chain it
            callbacks_chain.append(handler.callback)
        callbacks_chain.extend(callbacks)
        # We need to wrap them in a dcg.Callback to handle
        # the sender, target, and data parameters correctly
        callbacks_chain = [dcg.Callback(cb) for cb in callbacks_chain]
        def wrapped_callback(sender, target, data, callbacks_chain=callbacks_chain):
            for cb in callbacks_chain:
                cb(sender, target, data)
        handler.callback = wrapped_callback


def auto_cleanup_callback(sender: dcg.baseHandler, target):
    """
    Automatically cleans up the handler after it is triggered.

    This function is intended to be used as a callback that will
    remove the handler from its target item when the handler is triggered.
    This is useful for handlers that are only needed temporarily.

    Note the previous handler callback is preserved and
    will be called before the cleanup callback.
    """
    if hasattr(target, 'handlers'):
        with target.mutex:
            target.handlers = [h for h in target.handlers if h is not sender]
    if sender.parent is not None:
        warn(
            "auto_cleanup_callback may have no effect on handlers"
            " that are children of another handler.",
            RuntimeWarning
        )


def auto_cleanup_handler(handler: dcg.baseHandler):
    """
    Automatically cleans up the handler after it is triggered.

    This function adds a cleanup callback to the handler that will
    remove it from its target item when the handler is triggered.
    This is useful for handlers that are only needed temporarily.

    Note the previous handler callback is preserved and
    will be called before the cleanup callback.

    If the handler is attached to multiple items,
    it will only be removed from the target items when the
    condition is met for each item separately.

    The handler cannot be a child of another handler,
    for this to work properly.
    """
    if not isinstance(handler, dcg.baseHandler):
        raise TypeError("handler must be an instance of dcg.baseHandler")
    add_callbacks_to_handler(handler, auto_cleanup_callback)


def future_from_handler(handler: dcg.baseHandler, cleanup=False) -> Future:
    """
    Create a Future that waits for the event described by the handler to occur.

    When the event occurs once, the Future is resolved. It does not
    watch for multiple occurrences of the event.

    Note the event described by the handler might be already True when
    this function is called, but the Future will only wait for the
    next occurrence of the event.

    The handler is not cleaned up automatically (unless cleanup=True),
    so you should remove it from the item or context when you no longer need it.  

    Args:
        handler (dcg.baseHandler): The handler to convert into a Future.
        cleanup (bool, defaults to False): If True, the handler will be removed
            from the target item after the Future is resolved. Note if you
            attach the handler to multiple items, it will only be removed
            when the condition is met for each item separately.
            For this to work properly, the handler cannot be
            a child of another handler.

    Returns:
        Future: A Future object representing the handler's completion.
        The Future will be resolved with a tuple containing
        (sender, target, data) when the event occurs, where sender
        is the handler, target the item the handler is attached to,
        and data the optional event data passed to the callback.

    Example:
    >>> C = dcg.Context()
    >>> button = dcg.Button(C)
    >>> handler = dcg.GotHoveredHandler(C)
    >>> future = future_from_handler(handler)
    >>> button.handlers += [handler] # can be done before or after creating the future
    >>> # can also be attached to multiple items to wait for the first occurrence
    >>> # Use future.add_done_callback to append a callback
    >>> # that will be called when the future is resolved
    >>> ....
    >>> ## Wait for the future in a separate thread
    >>> (handler, item, data) = future.result()  # blocks until the event occurs
    >>> ## Wait for the future in a async function
    >>> await asyncio.wrap_future(future)  # blocks until the event occurs
    """
    if not isinstance(handler, dcg.baseHandler):
        raise TypeError("handler must be an instance of dcg.baseHandler")

    future = Future()
    def fill_future(sender: dcg.baseHandler, target: dcg.baseItem,
                    data, future=future, cleanup=cleanup):
        if not future.done():
            future.set_result((sender, target, data))
        if cleanup:
            with target.mutex:
                if hasattr(target, 'handlers'):
                    # Remove this handler from the target's handlers
                    # if it is still attached to the target
                    target.handlers = [h for h in target.handlers if h is not sender]
            if sender.parent is not None:
                warn(
                    "cleanup=True may have no effect on handlers"
                    " that are children of another handler.",
                    RuntimeWarning
                )

    add_callbacks_to_handler(handler, fill_future)
    return future


def generator_from_handler(handler: dcg.baseHandler):
    """
    Create a generator that yields the event described by the handler.

    When the event occurs, the generator yields a tuple containing
    (sender, target, data) where sender is the handler,
    target the item the handler is attached to,
    and data the optional event data passed to the callback.

    The generator will yield every time the event occurs,
    until it is closed or the handler is removed from the target item(s).

    Note the event described by the handler might be already True when
    this function is called, but the generator will only start yielding
    when the next occurrence of the event happens.

    Args:
        handler (dcg.baseHandler): The handler to convert into a generator.
    Yields:
        tuple: A tuple containing (sender, target, data) when the event occurs.
        The sender is the handler, target is the item the handler is attached to,
        and data is the optional event data passed to the callback.

    Example:
    >>> C = dcg.Context()
    >>> button = dcg.Button(C)
    >>> handler = dcg.GotHoveredHandler(C)
    >>> generator = generator_from_handler(handler)
    >>> button.handlers += [handler]  # can be done before or after creating the generator
    >>> # can also be attached to multiple items to wait for any occurrences
    >>> # Use next(generator) to get the next occurrence
    >>> # for e.g. in a loop:
    >>> for event in generator:
    >>>     print(event)  # prints (handler, item, data) when the event occurs
    """
    if not isinstance(handler, dcg.baseHandler):
        raise TypeError("handler must be an instance of dcg.baseHandler")
    
    # Queue to store events as they occur
    event_mutex = Lock()
    has_events = Event()
    event_queue = []
    # Flag to track if the generator is still active
    active = True
    
    def event_generator():
        nonlocal active, event_queue
        try:
            while active:
                # If there are events in the queue, yield the next one
                has_events.wait()  # Wait until there is an event
                with event_mutex:
                    if event_queue:
                        has_events.clear()
                    # Make a copy of the queue to release the mutex
                    events = event_queue.copy()
                    event_queue.clear()
                for event in events:
                    yield event
        finally:
            # Generator is being closed
            active = False
    
    # Define the callback function that will be triggered when the event occurs
    def on_event(sender, target, data):
        nonlocal active, event_queue, has_events
        if active:
            # Add the event data to the queue
            with event_mutex:
                event_queue.append((sender, target, data))
                # Set the event flag to indicate there are events to process
                has_events.set()
    
    # Add our callback to the handler
    add_callbacks_to_handler(handler, on_event)
    
    # Return the generator
    return event_generator()

async def async_generator_from_handler(handler: dcg.baseHandler):
    """
    Create an async generator that yields the event described by the handler.

    When the event occurs, the generator yields a tuple containing
    (sender, target, data) where sender is the handler,
    target the item the handler is attached to,
    and data the optional event data passed to the callback.

    The generator will yield every time the event occurs,
    until it is closed or the handler is removed from the target item(s).

    Note the event described by the handler might be already True when
    this function is called, but the generator will only start yielding
    when the next occurrence of the event happens.

    Args:
        handler (dcg.baseHandler): The handler to convert into an async generator.
    Yields:
        tuple: A tuple containing (sender, target, data) when the event occurs.
        The sender is the handler, target is the item the handler is attached to,
        and data is the optional event data passed to the callback.

    Example:
    >>> C = dcg.Context()
    >>> button = dcg.Button(C)
    >>> handler = dcg.GotHoveredHandler(C)
    >>> button.handlers += [handler]  # can be done before or after creating the generator
    >>> # Usage in an async function:
    >>> async for event in async_generator_from_handler(handler):
    >>>     print(event)  # prints (handler, item, data) when the event occurs
    >>> # or with asyncio.create_task() to run in the background
    """
    if not isinstance(handler, dcg.baseHandler):
        raise TypeError("handler must be an instance of dcg.baseHandler")
    
    # Queue to store events as they occur
    event_queue = asyncio_Queue()
    # Flag to track if the generator is still active
    active = True

    loop = get_event_loop()

    def on_event(sender, target, data):
        nonlocal active, event_queue, loop
        if active:
            # Add the event data to the queue using the asyncio event loop
            loop.call_soon_threadsafe(
                event_queue.put_nowait, (sender, target, data)
            )
    
    # Add our callback to the handler
    add_callbacks_to_handler(handler, on_event)
    
    try:
        # Async generator that yields events as they occur
        while active:
            # Await next event from the queue
            event = await event_queue.get()
            yield event
    finally:
        # Generator is being closed
        active = False