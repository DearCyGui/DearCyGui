from libcpp.atomic cimport atomic
from libcpp.string cimport string

cdef extern from "backend.h" nogil:
    cdef cppclass GLContext:
        void makeCurrent()
        void release()

    ctypedef void (*on_resize_fun)(void*)
    ctypedef void (*on_close_fun)(void*)  
    ctypedef void (*render_fun)(void*)
    ctypedef void (*on_drop_fun)(void*, int, const char*)

    cdef cppclass platformViewport:        
        # Virtual methods
        void cleanup()
        bint initialize(bint, bint) 
        void maximize()
        void minimize()
        void restore()
        void processEvents()
        bint renderFrame(bint)
        void present()
        void toggleFullScreen()
        void wakeRendering()
        void makeUploadContextCurrent()
        void releaseUploadContext()
        GLContext *createSharedContext(int, int)

        # Texture methods
        void* allocateTexture(unsigned, unsigned, unsigned, unsigned, unsigned, unsigned)
        void freeTexture(void*)
        bint updateDynamicTexture(void*, unsigned, unsigned, unsigned, unsigned, void*, unsigned)
        bint updateStaticTexture(void*, unsigned, unsigned, unsigned, unsigned, void*, unsigned)

        bint downloadBackBuffer(void*, int)

        # Public members
        float dpiScale
        bint isFullScreen
        bint isMinimized
        bint isMaximized

        # Rendering properties
        float[4] clearColor
        bint hasVSync
        bint waitForEvents
        bint shouldSkipPresenting
        atomic[bint] activityDetected
        atomic[bint] needsRefresh

        # Window properties
        string iconSmall
        string iconLarge
        string windowTitle
        bint titleChangeRequested
        bint windowResizable
        bint windowAlwaysOnTop
        bint windowDecorated
        bint windowPropertyChangeRequested

        # Window position/size
        int positionX
        int positionY
        bint positionChangeRequested
        unsigned minWidth
        unsigned minHeight
        unsigned maxWidth
        unsigned maxHeight
        int frameWidth
        int frameHeight
        int windowWidth
        int windowHeight
        bint sizeChangeRequested

        # Protected members
        string iconSmall
        string iconLarge
        string windowTitle
        render_fun renderCallback
        on_resize_fun resizeCallback
        on_close_fun closeCallback
        on_drop_fun dropCallback
        void* callbackData

    cdef cppclass SDLViewport(platformViewport):
        @staticmethod
        platformViewport* create(render_fun, on_resize_fun, on_close_fun, on_drop_fun, void*)

