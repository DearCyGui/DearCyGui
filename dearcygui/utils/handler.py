import dearcygui as dcg

class AnyKeyPressHandler(dcg.HandlerList):
    """
    Helper to test all keys in one handler.
    Obviously it would be better for performance
    to only test the target keys. Do not attach
    this to every item.
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
        return self._callback

    @callback.setter
    def callback(self, value):
        self._callback = value
        for c in self.children:
            c.callback = value

    @property
    def repeat(self):
        return self._repeat

    @repeat.setter
    def repeat(self, value):
        self._repeat = value
        for c in self.children:
            c.repeat = value

class AnyKeyReleaseHandler(dcg.HandlerList):
    """
    Helper to test all keys in one handler.
    Obviously it would be better for performance
    to only test the target keys. Do not attach
    this to every item.
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
        return self._callback

    @callback.setter
    def callback(self, value):
        self._callback = value
        for c in self.children:
            c.callback = value

class AnyKeyDownHandler(dcg.HandlerList):
    """
    Helper to test all keys in one handler.
    Obviously it would be better for performance
    to only test the target keys. Do not attach
    this to every item.
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
        return self._callback

    @callback.setter
    def callback(self, value):
        self._callback = value
        for c in self.children:
            c.callback = value
