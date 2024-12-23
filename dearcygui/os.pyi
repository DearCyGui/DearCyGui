"""
This type stub file was generated by cyright.
"""

def show_open_file_dialog(callback, default_location: str = ..., allow_multiple_files: bool = ...): # -> None:
    """
    Open the OS file open selection dialog

    callback is a function that will be called with a single
    argument: a list of paths. Can be None or [] if the dialog
    was cancelled or nothing was selected.

    default_location: optional default location
    allow_multiple_files (default to False): if True, allow
        selecting several paths which will be passed to the list
        given to the callback. If False, the list has maximum a
        single argument.
    """
    ...

def show_save_file_dialog(callback, default_location: str = ...): # -> None:
    """
    Open the OS file save selection dialog

    callback is a function that will be called with a single
    argument: a list of paths. Can be None or [] if the dialog
    was cancelled or nothing was selected. else, the list
    will contain a single path.

    default_location: optional default location
    """
    ...

def show_open_folder_dialog(callback, default_location: str = ..., allow_multiple_files: bool = ...): # -> None:
    """
    Open the OS directory open selection dialog

    callback is a function that will be called with a single
    argument: a list of paths. Can be None or [] if the dialog
    was cancelled or nothing was selected.

    default_location: optional default location
    allow_multiple_files (default to False): if True, allow
        selecting several paths which will be passed to the list
        given to the callback. If False, the list has maximum a
        single argument.
    """
    ...

