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

from .core cimport Context
from .c_types cimport unique_lock, mutex, condition_variable

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

cdef extern from "SDL3/SDL_init.h" nogil:
    ctypedef void (*SDL_MainThreadCallback)(void *userdata)
    bint SDL_RunOnMainThread(SDL_MainThreadCallback callback, void *, bint)
    const char* SDL_PROP_APP_METADATA_NAME_STRING
    const char* SDL_PROP_APP_METADATA_VERSION_STRING
    const char* SDL_PROP_APP_METADATA_IDENTIFIER_STRING
    const char* SDL_PROP_APP_METADATA_CREATOR_STRING
    const char* SDL_PROP_APP_METADATA_COPYRIGHT_STRING
    const char* SDL_PROP_APP_METADATA_URL_STRING
    const char* SDL_PROP_APP_METADATA_TYPE_STRING
    bint SDL_SetAppMetadataProperty(const char *name, const char *value)

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

cdef extern from "SDL3/SDL_error.h" nogil:
    bint SDL_ClearError()
    const char *SDL_GetError()

cdef extern from "SDL3/SDL_messagebox.h" nogil:
    unsigned SDL_MESSAGEBOX_ERROR
    unsigned SDL_MESSAGEBOX_WARNING
    unsigned SDL_MESSAGEBOX_INFORMATION
    unsigned SDL_MESSAGEBOX_BUTTONS_LEFT_TO_RIGHT
    unsigned SDL_MESSAGEBOX_BUTTONS_RIGHT_TO_LEFT
    bint SDL_ShowSimpleMessageBox(unsigned flags, const char *title, const char *message, SDL_Window *window)

cdef extern from "SDL3/SDL_misc.h" nogil:
    bint SDL_OpenURL(const char*)

cdef extern from "SDL3/SDL_power.h" nogil:
    enum SDL_PowerState:
        SDL_POWERSTATE_ERROR,
        SDL_POWERSTATE_UNKNOWN,
        SDL_POWERSTATE_ON_BATTERY,
        SDL_POWERSTATE_NO_BATTERY,
        SDL_POWERSTATE_CHARGING,
        SDL_POWERSTATE_CHARGED
    SDL_PowerState SDL_GetPowerInfo(int*, int*)

cdef extern from "SDL3/SDL_video.h" nogil:
    enum SDL_SystemTheme:
        SDL_SYSTEM_THEME_UNKNOWN,
        SDL_SYSTEM_THEME_LIGHT,
        SDL_SYSTEM_THEME_DARK
    SDL_SystemTheme SDL_GetSystemTheme()


# The SDL commands need to be called in the 'main' thread, that is the
# on that initialize SDL (the one for which the context was created).
# Thus why we use SDL_RunInMainThread


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

    def submit(self):
        """
        Submits the dialog to run via SDL_RunOnMainThread.
        """
        assert(not self.submitted)
        self.submitted = True

        # Increase reference count as the object will be used in callbacks
        Py_INCREF(self)

        # Run on main thread
        if not SDL_RunOnMainThread(_show_file_dialog, <void*>self, False):
            Py_DECREF(self)  # Decrease reference count on error
            _raise_error()

        # Note: we do not need to call viewport.wake() here,
        # as when waiting the viewport still processes events.


cdef void _show_file_dialog(void* userdata) noexcept nogil:
    """Callback run in the main thread to request the file dialog"""
    # Create properties and show dialog
    cdef SDL_PropertiesID props = SDL_CreateProperties()
    cdef SDL_Window* window = <SDL_Window*>(<_FileDialogQuery><PyObject*>userdata).context.viewport.get_platform_window()
    
    SDL_SetPointerProperty(props, SDL_PROP_FILE_DIALOG_FILTERS_POINTER, (<_FileDialogQuery><PyObject*>userdata).filters.data())
    SDL_SetNumberProperty(props, SDL_PROP_FILE_DIALOG_NFILTERS_NUMBER, (<_FileDialogQuery><PyObject*>userdata).filters.size())
    SDL_SetPointerProperty(props, SDL_PROP_FILE_DIALOG_WINDOW_POINTER, window)
    SDL_SetBooleanProperty(props, SDL_PROP_FILE_DIALOG_MANY_BOOLEAN, (<_FileDialogQuery><PyObject*>userdata).many_allowed)
    
    if (<_FileDialogQuery><PyObject*>userdata)._has_default_location:
        SDL_SetStringProperty(props, SDL_PROP_FILE_DIALOG_LOCATION_STRING, (<_FileDialogQuery><PyObject*>userdata).default_location.c_str())
    if (<_FileDialogQuery><PyObject*>userdata)._has_title:
        SDL_SetStringProperty(props, SDL_PROP_FILE_DIALOG_TITLE_STRING, (<_FileDialogQuery><PyObject*>userdata).title.c_str())
    if (<_FileDialogQuery><PyObject*>userdata)._has_accept:
        SDL_SetStringProperty(props, SDL_PROP_FILE_DIALOG_ACCEPT_STRING, (<_FileDialogQuery><PyObject*>userdata).accept.c_str())
    if (<_FileDialogQuery><PyObject*>userdata)._has_cancel:
        SDL_SetStringProperty(props, SDL_PROP_FILE_DIALOG_CANCEL_STRING, (<_FileDialogQuery><PyObject*>userdata).cancel.c_str())
    
    (<_FileDialogQuery><PyObject*>userdata).props = props
    
    # Show the file dialog (this is non-blocking)
    SDL_ShowFileDialogWithProperties((<_FileDialogQuery><PyObject*>userdata).dialog_type, _dialog_callback, userdata, props)

cdef void _dialog_callback(void *userdata,
                          const const_char_p *filelist,
                          int filter) noexcept nogil:
    """
    Callback called when the dialog is closed.
    Args:
       - userdata is the _FileDialogQuery instance.
       - filelist is a list of selected files, or NULL if
            the dialog was cancelled.
       - filter is the index of the selected filter, or -1 if
            no filter was selected.
    """
    if userdata == NULL:
        return
    with gil:
        (<_FileDialogQuery><PyObject*>userdata).treat_result(
            filelist, filter)
        Py_DECREF(<object><PyObject*>userdata)

def show_open_file_dialog(Context context not None,
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
    query.submit()


def show_save_file_dialog(Context context not None,
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
    query.submit()

def show_open_folder_dialog(Context context not None,
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
    query.submit()

cdef void _raise_error() noexcept:
    """
    Raise an error if there is one.
    """
    cdef const char* error = SDL_GetError()
    cdef str error_str = str(error, encoding='utf-8') if error is not NULL else ''
    SDL_ClearError()  # Clear the error
    raise RuntimeError(error_str)

cdef extern from * nogil:
    """
    struct _SystemThemeResult {
        std::mutex lock;
        std::condition_variable cv;
        bool completed;
        SDL_SystemTheme theme;
        
        _SystemThemeResult() : theme(SDL_SYSTEM_THEME_UNKNOWN) {
            // Constructor initializes the mutex and condition variable
        }
        
        ~_SystemThemeResult() {
            // Destructor ensures proper cleanup
        }
    };
    """
    cdef cppclass _SystemThemeResult:
        mutex lock
        condition_variable cv
        bint completed
        SDL_SystemTheme theme
        _SystemThemeResult() except +

cdef void _get_system_theme(void* p) noexcept nogil:
    """
    Get the system theme.
    Returns:
        - SDL_SYSTEM_THEME_UNKNOWN: The system theme is unknown.
        - SDL_SYSTEM_THEME_LIGHT: The system theme is light.
        - SDL_SYSTEM_THEME_DARK: The system theme is dark.
    """
    cdef _SystemThemeResult* result = <_SystemThemeResult*>p
    cdef unique_lock[mutex] lock = unique_lock[mutex](result.lock)
    result.theme = SDL_GetSystemTheme()
    result.completed = True
    result.cv.notify_all()

def get_system_theme(Context context not None) -> str:
    """
    Get the system theme.
    Returns:
        - "unknown": The system theme is unknown.
        - "light": The system theme is light.
        - "dark": The system theme is dark.
    """
    cdef _SystemThemeResult result
    result.theme = SDL_SYSTEM_THEME_UNKNOWN
    result.completed = False

    if not SDL_RunOnMainThread(_get_system_theme, <void*>(&result), False):
        _raise_error()
    #context.viewport.wake() # -> not needed, as the main thread processes all events
    cdef unique_lock[mutex] lock
    with nogil:
        lock = unique_lock[mutex](result.lock)
        while not result.completed:
            # Wait for the result to be set
            result.cv.wait(lock)
    if result.theme == SDL_SYSTEM_THEME_UNKNOWN:
        return "unknown"
    elif result.theme == SDL_SYSTEM_THEME_LIGHT:
        return "light"
    elif result.theme == SDL_SYSTEM_THEME_DARK:
        return "dark"
    else:
        return "unknown"

def open_url(str url) -> None:
    """
    Open an URL in the default web browser.
    """
    cdef bytes url_bytes = bytes(url, encoding='utf-8')
    if not SDL_OpenURL(url_bytes):
        _raise_error()

def get_battery_info() -> tuple[int, int, str]:
    """
    Get the battery information.
    Returns:
        - percentage: The battery percentage (0-100). -1 if unknown.
        - seconds_left: The estimated time left in seconds. -1 if unknown.
        - state: The power state as a string.
            - "unknown": The power state is unknown.
            - "on_battery": The system is running on battery.
            - "no_battery": The system has no battery.
            - "charging": The system is charging the battery.
            - "charged": The battery is fully charged.

    You should never take a battery status as absolute truth. Batteries
    (especially failing batteries) are delicate hardware, and the values
    reported here are best estimates based on what that hardware reports.
    It's not uncommon for older batteries to lose stored power much faster
    than it reports, or completely drain when reporting it has 20 percent
    left, etc.

    Battery status can change at any time; if you are concerned with power
    state, you should call this function frequently, and perhaps ignore
    changes until they seem to be stable for a few seconds.

    It's possible a platform can only report battery percentage or time
    left but not both.

    On some platforms, retrieving power supply details might be expensive.
    If you want to display continuous status you could call this function
    every minute or so.
    """
    cdef int percentage = 0
    cdef int seconds_left = 0
    cdef SDL_PowerState state = SDL_GetPowerInfo(&seconds_left, &percentage)
    if state == SDL_POWERSTATE_ERROR:
        _raise_error()
    if state == SDL_POWERSTATE_UNKNOWN:
        return (percentage, seconds_left, "unknown")
    elif state == SDL_POWERSTATE_ON_BATTERY:
        return (percentage, seconds_left, "on_battery")
    elif state == SDL_POWERSTATE_NO_BATTERY:
        return (percentage, seconds_left, "no_battery")
    elif state == SDL_POWERSTATE_CHARGING:
        return (percentage, seconds_left, "charging")
    elif state == SDL_POWERSTATE_CHARGED:
        return (percentage, seconds_left, "charged")
    else:
        return (percentage, seconds_left, "unknown")

def show_message_box(Context context not None,
                     str title,
                     str message,
                     str message_type="error") -> None:
    """
    Stops the rendering thread with a blocking system
    message box. The rendering thread is blocked until
    the user to closes the message box.

    If called from the rendering thread (the one that created
    the context), this function will display the message box
    immediately, without waiting render_frame().

    Args:
        context: The context to use.
        title: The title of the message box.
        message: The message to display.
        message_type: The type of the message box. Can be "error", "warning" or "info".
    """
    cdef bytes title_bytes = bytes(title, encoding='utf-8')
    cdef bytes message_bytes = bytes(message, encoding='utf-8')
    cdef unsigned flags = 0
    
    if message_type == "warning":
        flags = SDL_MESSAGEBOX_WARNING
    elif message_type == "info":
        flags = SDL_MESSAGEBOX_INFORMATION
    else:
        flags = SDL_MESSAGEBOX_ERROR  # Default to error if not specified
    
    ## Add left-to-right button orientation ?
    #flags |= SDL_MESSAGEBOX_BUTTONS_LEFT_TO_RIGHT

    cdef SDL_Window* window = <SDL_Window*>context.viewport.get_platform_window()

    if not SDL_ShowSimpleMessageBox(flags, title_bytes, message_bytes, window):
        _raise_error()
    #context.viewport.wake()  # -> not needed, as the main thread processes all events

def set_application_metadata(str name=None,
                             str version=None,
                             str identifier=None,
                             str creator=None,
                             str copyright=None,
                             str url=None,
                             str type=None) -> None:
    """
    Set the application metadata. This is used by the OS to display
    information about the application in the system settings or
    application manager.

    To properly apply, some metadata require this call to be made
    before context creation.

    Args:
        name: The name of the application.
        version: The version of the application.
        identifier: A unique string that identifies this app.
            This must be in reverse-domain format, like "com.example.mygame2".
            This string is used by desktop compositors to identify and group
            windows together, as well as match applications with associated
            desktop settings and icons. If you plan to package your
            application in a container such as Flatpak, the app ID
            should match the name of your Flatpak container as well. 
        creator: A one line creator notice for the application.
        copyright: A one line copyright notice for the application.
        url: The URL of the application.
        type: The type of application this is.
            Currently must be one of: "game", "mediaplayer", "application".
    """
    cdef bytes name_b = bytes(name, encoding='utf-8') if name is not None else None
    cdef bytes version_b = bytes(version, encoding='utf-8') if version is not None else None
    cdef bytes identifier_b = bytes(identifier, encoding='utf-8') if identifier is not None else None
    cdef bytes creator_b = bytes(creator, encoding='utf-8') if creator is not None else None
    cdef bytes copyright_b = bytes(copyright, encoding='utf-8') if copyright is not None else None
    cdef bytes url_b = bytes(url, encoding='utf-8') if url is not None else None
    cdef bytes type_b = bytes(type, encoding='utf-8') if type is not None else None
    cdef const char* name_c = NULL
    cdef const char* version_c = NULL
    cdef const char* identifier_c = NULL
    cdef const char* creator_c = NULL
    cdef const char* copyright_c = NULL
    cdef const char* url_c = NULL
    cdef const char* type_c = NULL

    if name_b is not None:
        name_c = name_b
    if version_b is not None:
        version_c = version_b
    if identifier_b is not None:
        identifier_c = identifier_b
    if creator_b is not None:
        creator_c = creator_b
    if copyright_b is not None:
        copyright_c = copyright_b
    if url_b is not None:
        url_c = url_b
    if type_b is not None:
        type_c = type_b

    if not SDL_SetAppMetadataProperty(SDL_PROP_APP_METADATA_NAME_STRING, 
                                      name_c):
        _raise_error()
    if not SDL_SetAppMetadataProperty(SDL_PROP_APP_METADATA_VERSION_STRING, 
                                      version_c):
        _raise_error()
    if not SDL_SetAppMetadataProperty(SDL_PROP_APP_METADATA_IDENTIFIER_STRING, 
                                      identifier_c):
        _raise_error()
    if not SDL_SetAppMetadataProperty(SDL_PROP_APP_METADATA_CREATOR_STRING, 
                                      creator_c):
        _raise_error()
    if not SDL_SetAppMetadataProperty(SDL_PROP_APP_METADATA_COPYRIGHT_STRING, 
                                      copyright_c):
        _raise_error()
    if not SDL_SetAppMetadataProperty(SDL_PROP_APP_METADATA_URL_STRING, 
                                      url_c):
        _raise_error()
    if not SDL_SetAppMetadataProperty(SDL_PROP_APP_METADATA_TYPE_STRING, 
                                      type_c):
        _raise_error()