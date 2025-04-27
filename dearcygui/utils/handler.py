import dearcygui as dcg

class AnyKeyPressHandler(dcg.HandlerList):
    """
    Handler that responds to any key press event.
    
    This helper class creates a collection of key press handlers covering all keys.
    While convenient for global key monitoring, it comes with performance overhead
    and should be used sparingly rather than attached to many individual items.
    """
    def __init__(self, context, **kwargs):
        self._callback = None
        self._repeat = False
        super().__init__(context, **kwargs)
        with self:
            for key in dcg.Key:
                dcg.KeyPressHandler(context,
                                    key=dcg.Key(key),
                                    repeat=self._repeat,
                                    callback=self._callback)

    @property
    def callback(self):
        """
        Function to call when any key is pressed.
        
        The callback will receive the key event information and can be used
        to implement custom behavior in response to key presses.
        """
        return self._callback

    @callback.setter
    def callback(self, value):
        self._callback = value
        for c in self.children:
            c.callback = value

    @property
    def repeat(self):
        """
        Whether the handler should trigger repeatedly while a key is held down.
        
        When True, the callback will be called multiple times as the key remains
        pressed. When False, the callback is only called once when the key is
        initially pressed.
        """
        return self._repeat

    @repeat.setter
    def repeat(self, value):
        self._repeat = value
        for c in self.children:
            c.repeat = value

class AnyKeyReleaseHandler(dcg.HandlerList):
    """
    Handler that responds to any key release event.
    
    This helper class creates a collection of handlers covering all key releases.
    Use this when you need to detect when any key is released, but be aware of
    the performance impact of monitoring all keys simultaneously.
    """
    def __init__(self, context, **kwargs):
        self._callback = None
        super().__init__(context, **kwargs)
        with self:
            for key in dcg.Key:
                dcg.KeyPressHandler(context,
                                    key=dcg.Key(key),
                                    callback=self._callback)

    @property
    def callback(self):
        """
        Function to call when any key is released.
        
        The callback will receive the key event information and can be used
        to implement custom behavior in response to key releases.
        """
        return self._callback

    @callback.setter
    def callback(self, value):
        self._callback = value
        for c in self.children:
            c.callback = value

class AnyKeyDownHandler(dcg.HandlerList):
    """
    Handler that responds when any key is in the down state.
    
    This helper class creates handlers for detecting when any key is currently
    pressed down. It's useful for checking key state rather than key events,
    but should be used judiciously due to its performance implications.
    """
    def __init__(self, context, **kwargs):
        self._callback = None
        super().__init__(context, **kwargs)
        with self:
            for key in dcg.Key:
                dcg.KeyPressHandler(context,
                                    key=dcg.Key(key),
                                    callback=self._callback)

    @property
    def callback(self):
        """
        Function to call when any key is in the down state.
        
        The callback will receive information about which key is down and can
        be used to implement custom behavior based on the current key state.
        """
        return self._callback

    @callback.setter
    def callback(self, value):
        self._callback = value
        for c in self.children:
            c.callback = value
