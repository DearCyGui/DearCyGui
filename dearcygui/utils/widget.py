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
        self.handlers += [
            dcg.LostRenderHandler(context,
                                  callback=self.destroy_tooltip)]

    def destroy_tooltip(self):
        if self.context is None:
            return # Already deleted
        # self.parent = None would work too but would wait GC.
        self.delete_item()