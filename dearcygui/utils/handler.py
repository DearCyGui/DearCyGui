from asyncio import Queue as asyncio_Queue, get_event_loop
from collections.abc import Generator, AsyncGenerator
from concurrent.futures import Future
import dearcygui as dcg
from threading import Event, Lock
from warnings import warn


def add_callbacks_to_handler(handler: dcg.baseHandler, *callbacks) -> None:
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


def auto_cleanup_callback(sender: dcg.baseHandler, target: dcg.baseItem) -> None:
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
            target.handlers = [h for h in target.handlers if h is not sender] # type: ignore
    if sender.parent is not None:
        warn(
            "auto_cleanup_callback may have no effect on handlers"
            " that are children of another handler.",
            RuntimeWarning
        )


def auto_cleanup_handler(handler: dcg.baseHandler) -> None:
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


def future_from_handlers(*handlers, cleanup=False) -> Future:
    """
    Create a Future that waits for any of the events described by the handlers to occur.

    When any of the events occurs once, the Future is resolved. It does not
    watch for multiple occurrences of the events.

    Note the events described by the handlers might be already True when
    this function is called, but the Future will only wait for the
    next occurrence of any of the events.

    The handlers are not cleaned up automatically (unless cleanup=True),
    so you should remove them from the items or contexts when you no longer need them.  

    Args:
        *handlers (dcg.baseHandler): The handler(s) to convert into a Future.
        cleanup (bool, defaults to False): If True, the handler that triggered the event
            will be removed from the target item after the Future is resolved. Note if you
            attach handlers to multiple items, a handler will only be removed
            when its condition is met for a specific target item.
            For this to work properly, the handlers cannot be
            children of another handler.

    Returns:
        Future: A Future object representing the completion of any of the handlers.
        The Future will be resolved with a tuple containing
        (sender, target, data) when any of the events occurs, where sender
        is the handler that triggered, target the item the handler is attached to,
        and data the optional event data passed to the callback.

    Example:
    >>> C = dcg.Context()
    >>> button = dcg.Button(C)
    >>> handler1 = dcg.GotHoveredHandler(C)
    >>> handler2 = dcg.GotClickedHandler(C)
    >>> future = future_from_handlers(handler1, handler2)
    >>> button.handlers += [handler1, handler2] # can be done before or after creating the future
    >>> # can also be attached to multiple items to wait for the first occurrence of any event
    >>> # Use future.add_done_callback to append a callback
    >>> # that will be called when the future is resolved
    >>> ....
    >>> ## Wait for the future in a separate thread
    >>> (handler, item, data) = future.result()  # blocks until any of the events occurs
    >>> ## Wait for the future in a async function
    >>> await asyncio.wrap_future(future)  # blocks until any of the events occurs
    """
    if not handlers:
        raise ValueError("At least one handler must be provided")
    
    for handler in handlers:
        if not isinstance(handler, dcg.baseHandler):
            raise TypeError("All handlers must be instances of dcg.baseHandler")

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
                    target.handlers = [h for h in target.handlers if h is not sender] # type: ignore
            if sender.parent is not None:
                warn(
                    "cleanup=True may have no effect on handlers"
                    " that are children of another handler.",
                    RuntimeWarning
                )

    # Add our callback to all handlers
    for handler in handlers:
        add_callbacks_to_handler(handler, fill_future)
    
    return future


def generator_from_handlers(*handlers) -> Generator[tuple, None, None]:
    """
    Create a generator that yields events described by the handlers.

    When any of the events occurs, the generator yields a tuple containing
    (sender, target, data) where sender is the handler that triggered,
    target the item the handler is attached to,
    and data the optional event data passed to the callback.

    The generator will yield every time any of the events occur,
    until it is closed or all handlers are removed from their target item(s).

    Note the events described by the handlers might be already True when
    this function is called, but the generator will only start yielding
    when the next occurrence of any event happens.

    Args:
        *handlers (dcg.baseHandler): The handler(s) to convert into a generator.
    Yields:
        tuple: A tuple containing (sender, target, data) when an event occurs.
        The sender is the handler, target is the item the handler is attached to,
        and data is the optional event data passed to the callback.

    Example:
    >>> C = dcg.Context()
    >>> button = dcg.Button(C)
    >>> handler1 = dcg.GotHoveredHandler(C)
    >>> handler2 = dcg.GotClickedHandler(C)
    >>> generator = generator_from_handlers(handler1, handler2)
    >>> button.handlers += [handler1, handler2]  # can be done before or after creating the generator
    >>> # can also be attached to multiple items to wait for any occurrences
    >>> # Use next(generator) to get the next occurrence
    >>> # for e.g. in a loop:
    >>> for event in generator:
    >>>     print(event)  # prints (handler, item, data) when the event occurs
    """
    if not handlers:
        raise ValueError("At least one handler must be provided")
    
    for handler in handlers:
        if not isinstance(handler, dcg.baseHandler):
            raise TypeError("All handlers must be instances of dcg.baseHandler")
    
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
    
    # Add our callback to all handlers
    for handler in handlers:
        add_callbacks_to_handler(handler, on_event)
    
    # Return the generator
    return event_generator()


async def async_generator_from_handlers(*handlers) -> AsyncGenerator[tuple, None]:
    """
    Create an async generator that yields events described by the handlers.

    When any of the events occurs, the generator yields a tuple containing
    (sender, target, data) where sender is the handler that triggered,
    target the item the handler is attached to,
    and data the optional event data passed to the callback.

    The generator will yield every time any of the events occur,
    until it is closed or all handlers are removed from their target item(s).

    Note the events described by the handlers might be already True when
    this function is called, but the generator will only start yielding
    when the next occurrence of any event happens.

    It is safe to use this generator in an async loop that is different
    from the one used by the context queue (if using AsyncPoolExecutor,
    or AsyncThreadPoolExecutor, or similar).

    Args:
        *handlers (dcg.baseHandler): The handler(s) to convert into an async generator.
    Yields:
        tuple: A tuple containing (sender, target, data) when the event occurs.
        The sender is the handler, target is the item the handler is attached to,
        and data is the optional event data passed to the callback.

    Example:
    >>> C = dcg.Context()
    >>> button = dcg.Button(C)
    >>> handler1 = dcg.GotHoveredHandler(C)
    >>> handler2 = dcg.GotClickedHandler(C)
    >>> button.handlers += [handler1, handler2]  # can be done before or after creating the generator
    >>> # Usage in an async function:
    >>> async for event in async_generator_from_handlers(handler1, handler2):
    >>>     print(event)  # prints (handler, item, data) when the event occurs
    >>> # or with asyncio.create_task() to run in the background
    """
    if not handlers:
        raise ValueError("At least one handler must be provided")
    
    for handler in handlers:
        if not isinstance(handler, dcg.baseHandler):
            raise TypeError("All handlers must be instances of dcg.baseHandler")
    
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
    
    # Add our callback to all handlers
    for handler in handlers:
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