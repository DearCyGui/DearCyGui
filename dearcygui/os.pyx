#!python
#cython: language_level=3
#cython: boundscheck=False
#cython: wraparound=False
#cython: nonecheck=False
#cython: embedsignature=False
#cython: cdivision=True
#cython: cdivision_warnings=False
#cython: always_allow_keywords=False
#cython: profile=False
#cython: infer_types=False
#cython: initializedcheck=False
#cython: c_line_in_traceback=False
#cython: auto_pickle=False
#cython: freethreading_compatible=True
#distutils: language=c++

from libc.stdint cimport uint32_t, int32_t, int64_t
from libcpp.string cimport string
from libcpp.vector cimport vector

from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF

from .core cimport baseItem, baseHandler, Context

import traceback

"""
System File dialog
"""

cdef extern from "SDL3/SDL_properties.h" nogil:
    ctypedef uint32_t SDL_PropertiesID
    SDL_PropertiesID SDL_CreateProperties()
    bint SDL_SetPointerProperty(SDL_PropertiesID props, const char *name, void *value)
    bint SDL_SetStringProperty(SDL_PropertiesID props, const char *name, const char *value)
    bint SDL_SetNumberProperty(SDL_PropertiesID props, const char *name, int64_t value)
    bint SDL_SetBooleanProperty(SDL_PropertiesID props, const char *name, bint value)
    void SDL_DestroyProperties(SDL_PropertiesID props)

cdef extern from * nogil:
    """
    typedef const char const_char;
    typedef const_char* const_char_p;
    """
    ctypedef const char const_char
    ctypedef const_char* const_char_p

cdef extern from "SDL3/SDL_dialog.h" nogil:
    struct SDL_Window_:
        pass
    ctypedef SDL_Window_* SDL_Window
    struct SDL_DialogFileFilter:
        const char* name
        const char* pattern
    enum SDL_FileDialogType:
        SDL_FILEDIALOG_OPENFILE,
        SDL_FILEDIALOG_SAVEFILE,
        SDL_FILEDIALOG_OPENFOLDER
    const char* SDL_PROP_FILE_DIALOG_FILTERS_POINTER
    const char* SDL_PROP_FILE_DIALOG_NFILTERS_NUMBER
    const char* SDL_PROP_FILE_DIALOG_WINDOW_POINTER
    const char* SDL_PROP_FILE_DIALOG_LOCATION_STRING
    const char* SDL_PROP_FILE_DIALOG_MANY_BOOLEAN
    const char* SDL_PROP_FILE_DIALOG_TITLE_STRING
    const char* SDL_PROP_FILE_DIALOG_ACCEPT_STRING
    const char* SDL_PROP_FILE_DIALOG_CANCEL_STRING
    ctypedef void (*SDL_DialogFileCallback)(void*, const const_char_p*, int)
    void SDL_ShowOpenFileDialog(SDL_DialogFileCallback, void*, SDL_Window_*, SDL_DialogFileFilter*, int, const char*, bint)
    void SDL_ShowSaveFileDialog(SDL_DialogFileCallback, void*, SDL_Window_*, SDL_DialogFileFilter*, int, const char*)
    void SDL_ShowOpenFolderDialog(SDL_DialogFileCallback, void*, SDL_Window_*, const char*, bint)
    void SDL_ShowFileDialogWithProperties(SDL_FileDialogType, SDL_DialogFileCallback, void *, SDL_PropertiesID)



# The SDL commands need to be called in the 'main' thread, that is the
# on that initialize SDL (the one for which the context was created).
# Thus delay the command until render_frame() in a handler

cdef class _RenderFrameCommandSubmission(baseHandler):
    cdef bint _has_run
    cdef object custom_callback
    
    def __init__(self, context, callback, **kwargs):
        baseHandler.__init__(self, context, **kwargs)
        self.custom_callback = callback
        self.callback = self._run_async

    def __cinit__(self):
        self._has_run = False

    def _run_async(self):
        self.custom_callback()
        self._delayed_delete()

    def _delayed_delete(self):
        """Free the item in the queue frame,
           as we cannot do it safely during rendering.
        """
        with getattr(self.context.viewport, "mutex"):
            setattr(self.context.viewport,
                    "handlers",
                   [h for h in getattr(self.context.viewport, "handlers") if h is not self])

    cdef void check_bind(self, baseItem item):
        if item is not self.context.viewport:
            raise TypeError("May only be attached to viewport")

    cdef bint check_state(self, baseItem item) noexcept nogil:
        return not self._has_run

    cdef void run_handler(self, baseItem item) noexcept nogil:
        if self._has_run:
            return
        self.run_callback(item)
        self._has_run = True



# Callback handling



cdef class _FileDialogQuery:
    cdef Context context
    cdef object callback
    cdef vector[string] filters_backing
    cdef vector[SDL_DialogFileFilter] filters
    cdef SDL_FileDialogType dialog_type
    cdef SDL_PropertiesID props
    cdef bint submitted
    cdef bint many_allowed
    cdef bint _has_default_location
    cdef bint _has_title
    cdef bint _has_accept
    cdef bint _has_cancel
    cdef string default_location
    cdef string title
    cdef string accept
    cdef string cancel

    def __cinit__(self,
                  Context context,
                  SDL_FileDialogType type,
                  object callback,
                  filters,
                  bint many_allowed,
                  str default_location,
                  str title,
                  str accept,
                  str cancel):
        self.submitted = False
        self.context = context
        self.callback = callback
        self.dialog_type = type
        self.many_allowed = many_allowed
        self._has_default_location = False
        self._has_title = False
        self._has_accept = False
        self._has_cancel = False
        if default_location is not None:
            self.default_location = bytes(default_location, encoding="utf-8")
            self._has_default_location = True
        if title is not None:
            self.title = bytes(title, encoding="utf-8")
            self._has_title = True
        if accept is not None:
            self.accept = bytes(accept, encoding="utf8")
            self._has_accept = True
        if cancel is not None:
            self.cancel = bytes(cancel, encoding="utf-8")
            self._has_cancel = True
        cdef SDL_DialogFileFilter filter
        # First copy to the backing for proper cleanup
        # on error
        if filters is None:
            filters = []
        for (name, pattern) in filters:
            self.filters_backing.push_back(bytes(str(name), encoding="utf-8"))
            pattern = str(pattern)
            if len(pattern) == 0:
                raise ValueError(f"Invalid pattern: {pattern}. Extensions may not be empty.")
            if pattern != "*":
                parts = pattern.split(";")
                for part in parts:
                    if not all(c.isalnum() or c in "-_." for c in part):
                        raise ValueError(f"Invalid pattern: {pattern}. Extensions may only contain alphanumeric characters, hyphens, underscores and periods.")
            self.filters_backing.push_back(bytes(pattern, encoding="utf-8"))
        
        # Add the pointers to the actual filters
        cdef int32_t i
        for i in range(0, <int32_t>self.filters_backing.size(), 2):
            filter.name = self.filters_backing[i].c_str()
            filter.pattern = self.filters_backing[i + 1].c_str()
            self.filters.push_back(filter)
        # because we store the data in strings, proper
        # cleanup is done by the vector destructor

    cdef void treat_result(self,
                           const const_char_p* filelist,
                           int filter):
        """Call the callback with the result"""
        SDL_DestroyProperties(self.props)
        result = None
        if filelist != NULL:
            result = []
            while filelist[0] != NULL:
                result.append(str(<bytes>filelist[0], encoding='utf-8'))
                filelist += 1
        try:
            self.callback(result)
        except Exception as e:
            print(traceback.format_exc())

    def _submit_in_frame(self):
        """Submission of the dialog during the frame"""
        cdef SDL_PropertiesID props = SDL_CreateProperties()
        cdef SDL_Window* window = <SDL_Window*>self.context.viewport.get_platform_window()
        SDL_SetPointerProperty(props, SDL_PROP_FILE_DIALOG_FILTERS_POINTER, self.filters.data())
        SDL_SetNumberProperty(props, SDL_PROP_FILE_DIALOG_NFILTERS_NUMBER, self.filters.size())
        SDL_SetPointerProperty(props, SDL_PROP_FILE_DIALOG_WINDOW_POINTER, window)
        SDL_SetBooleanProperty(props, SDL_PROP_FILE_DIALOG_MANY_BOOLEAN, self.many_allowed)
        if self._has_default_location:
            SDL_SetStringProperty(props, SDL_PROP_FILE_DIALOG_LOCATION_STRING, self.default_location.c_str())
        if self._has_title:
            SDL_SetStringProperty(props, SDL_PROP_FILE_DIALOG_TITLE_STRING, self.title.c_str())
        if self._has_accept:
            SDL_SetStringProperty(props, SDL_PROP_FILE_DIALOG_ACCEPT_STRING, self.accept.c_str())
        if self._has_cancel:
            SDL_SetStringProperty(props, SDL_PROP_FILE_DIALOG_CANCEL_STRING, self.cancel.c_str())
        self.props = props
        SDL_ShowFileDialogWithProperties(self.dialog_type, _dialog_callback, <void*>self, props)

    def submit(self):
        """Submits on the next frame. Must be Incref'd before
           submission, as it will be decref'd after the callback
           is called.
        """
        cdef Context context = self.context
        assert(not self.submitted)
        self.submitted = True
        with getattr(context.viewport, "mutex"):
            handlers = getattr(context.viewport, "handlers")
            handlers += [
                _RenderFrameCommandSubmission(context, self._submit_in_frame)
            ]
            setattr(context.viewport, "handlers", handlers)
        context.viewport.wake()

cdef void _dialog_callback(void *userdata,
                          const const_char_p *filelist,
                          int filter) noexcept nogil:
    if userdata == NULL:
        return
    with gil:
        (<_FileDialogQuery><PyObject*>userdata).treat_result(
            filelist, filter)
        Py_DECREF(<object><PyObject*>userdata)

def show_open_file_dialog(Context context,
                          callback,
                          str default_location=None,
                          bint allow_multiple_files=False,
                          filters=None,
                          str title=None,
                          str accept=None,
                          str cancel=None):
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
    filters: optional list of tuple (name, pattern) for filtering
        visible files
    title: optional title for the modal window
    accept: optional string displayed on the accept button
    cancel: optional string displayed on the cancel button
    """
    
    cdef _FileDialogQuery query = \
        _FileDialogQuery(context,
                         SDL_FILEDIALOG_OPENFILE,
                         callback,
                         filters,
                         allow_multiple_files,
                         default_location,
                         title,
                         accept,
                         cancel)
    Py_INCREF(query)
    query.submit()


def show_save_file_dialog(Context context,
                          callback,
                          str default_location=None,
                          bint allow_multiple_files=False,
                          filters=None,
                          str title=None,
                          str accept=None,
                          str cancel=None):
    """
    Open the OS file save selection dialog

    callback is a function that will be called with a single
    argument: a list of paths. Can be None or [] if the dialog
    was cancelled or nothing was selected.

    default_location: optional default location
    allow_multiple_files (default to False): if True, allow
        selecting several paths which will be passed to the list
        given to the callback. If False, the list has maximum a
        single argument.
    filters: optional list of tuple (name, pattern) for filtering
        visible files
    title: optional title for the modal window
    accept: optional string displayed on the accept button
    cancel: optional string displayed on the cancel button
    """
    
    cdef _FileDialogQuery query = \
        _FileDialogQuery(context,
                         SDL_FILEDIALOG_SAVEFILE,
                         callback,
                         filters,
                         allow_multiple_files,
                         default_location,
                         title,
                         accept,
                         cancel)
    Py_INCREF(query)
    query.submit()

def show_open_folder_dialog(Context context,
                          callback,
                          str default_location=None,
                          bint allow_multiple_files=False,
                          filters=None,
                          str title=None,
                          str accept=None,
                          str cancel=None):
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
    filters: optional list of tuple (name, pattern) for filtering
        visible files
    title: optional title for the modal window
    accept: optional string displayed on the accept button
    cancel: optional string displayed on the cancel button
    """
    
    cdef _FileDialogQuery query = \
        _FileDialogQuery(context,
                         SDL_FILEDIALOG_OPENFOLDER,
                         callback,
                         filters,
                         allow_multiple_files,
                         default_location,
                         title,
                         accept,
                         cancel)
    Py_INCREF(query)
    query.submit()

