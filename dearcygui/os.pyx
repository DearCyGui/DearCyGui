from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF
import traceback


"""
System File dialog
"""

cdef extern from "SDL3/SDL_dialog.h" nogil:
    struct SDL_Window_:
        pass
    ctypedef SDL_Window_* SDL_Window
    struct SDL_DialogFileFilter:
        const char* name
        const char* pattern
    ctypedef void (*SDL_DialogFileCallback)(void*, const char*const*, int)
    void SDL_ShowOpenFileDialog(SDL_DialogFileCallback, void*, SDL_Window_*, SDL_DialogFileFilter*, int, const char*, bint)
    void SDL_ShowSaveFileDialog(SDL_DialogFileCallback, void*, SDL_Window_*, SDL_DialogFileFilter*, int, const char*)
    void SDL_ShowOpenFolderDialog(SDL_DialogFileCallback, void*, SDL_Window_*, const char*, bint)

cdef void dialog_callback(void *userdata,
                          const char *const*filelist,
                          int filter) noexcept nogil:
    with gil:
        dialog_callback_gil(userdata, filelist, filter)

cdef void dialog_callback_gil(void *userdata,
                          const char *const*filelist,
                          int filter):
    cdef object callback
    result = None
    if filelist != NULL:
        result = []
        while filelist[0] != NULL:
            result.append(str(<bytes>filelist[0], encoding='utf-8'))
            filelist += 1
    if userdata == NULL:
        return
    callback = <object><PyObject*>userdata
    try:
        callback(result)
    except Exception as e:
        print(traceback.format_exc())
    
def show_open_file_dialog(callback, str default_location=None, bint allow_multiple_files=False):
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
    Py_INCREF(callback)
    cdef char *default_location_c = NULL
    cdef bytes default_location_array = None
    if default_location is not None:
        default_location_array = bytes(default_location, 'utf-8')
        default_location_c = <char *>default_location_array
    SDL_ShowOpenFileDialog(dialog_callback, <void*><PyObject*>callback, NULL, NULL, 0, default_location_c, allow_multiple_files)

def show_save_file_dialog(callback, str default_location=None):
    """
    Open the OS file save selection dialog

    callback is a function that will be called with a single
    argument: a list of paths. Can be None or [] if the dialog
    was cancelled or nothing was selected. else, the list
    will contain a single path.

    default_location: optional default location
    """
    Py_INCREF(callback)
    cdef char *default_location_c = NULL
    cdef bytes default_location_array = None
    if default_location is not None:
        default_location_array = bytes(default_location, 'utf-8')
        default_location_c = <char *>default_location_array
    SDL_ShowSaveFileDialog(dialog_callback, <void*><PyObject*>callback, NULL, NULL, 0, default_location_c)

def show_open_folder_dialog(callback, str default_location=None, bint allow_multiple_files=False):
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
    Py_INCREF(callback)
    cdef char *default_location_c = NULL
    cdef bytes default_location_array = None
    if default_location is not None:
        default_location_array = bytes(default_location, 'utf-8')
        default_location_c = <char *>default_location_array
    SDL_ShowOpenFolderDialog(dialog_callback, <void*><PyObject*>callback, NULL, default_location_c, allow_multiple_files)
