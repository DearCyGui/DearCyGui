import dearcygui as dcg

class TemporaryTooltip(dcg.Tooltip):
    """
    A tooltip that deletes itself when its
    showing condition is not met anymore.

    The handler passed as argument
    should be a new handler instance that will
    be checked for the condition. It should hold
    True as long as the item should be shown.
    """
    def __init__(self,
                 context : dcg.Context,
                 **kwargs):
        super().__init__(context, **kwargs)
        not_rendered = dcg.OtherItemHandler(context, target=self, op=dcg.HandlerListOP.NONE, callback=self.destroy_tooltip)
        with not_rendered:
            dcg.RenderHandler(context)
        self.viewport_handler = not_rendered
        # += is not atomic. The mutex is to be thread safe, in case
        # another thread manipulates the handlers
        with context.viewport.mutex:
            context.viewport.handlers += [self.viewport_handler]

    def cleanup_handlers(self):
        # Remove the handlers we attached
        with self.context.viewport.mutex:
            self.context.viewport.handlers = [
                h for h in self.context.viewport.handlers\
                if h is not self.viewport_handler
            ]

    def destroy_tooltip(self):
        if self.context is None:
            return # Already deleted
        self.cleanup_handlers()
        # self.parent = None would work too but would wait GC.
        self.delete_item()