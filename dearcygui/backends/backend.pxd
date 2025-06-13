from libc.stdint cimport uint8_t, uint64_t
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
        bint initialize() except +
        bint processEvents(int)
        bint renderFrame(bint)
        void present()
        bint checkPrimaryThread()
        void toggleFullScreen()
        void addWindowIcon(void*, int, int, int, int, int) except +
        void wakeRendering(uint64_t, bint)
        void setHitTestSurface(uint8_t*, int, int) except +
        void makeUploadContextCurrent()
        void releaseUploadContext()
        GLContext *createSharedContext(int, int) except +

        # Texture methods
        void* allocateTexture(unsigned, unsigned, unsigned, unsigned, unsigned, unsigned, unsigned) except +
        void freeTexture(void*)
        bint updateDynamicTexture(void*, unsigned, unsigned, unsigned, unsigned, void*, unsigned) except +
        bint updateStaticTexture(void*, unsigned, unsigned, unsigned, unsigned, void*, unsigned) except +

        bint downloadTexture(void*, int, int,
                             unsigned, unsigned, unsigned, unsigned,
                             void*, unsigned) except +
        bint backBufferToTexture(void*, unsigned, unsigned, unsigned, unsigned) except +

        # Texture sync methods
        void beginExternalWrite(unsigned int)
        void endExternalWrite(unsigned int) 
        void beginExternalRead(unsigned int)
        void endExternalRead(unsigned int)

        # Public members
        float dpiScale
        bint isFullScreen
        bint isMinimized
        bint isMaximized
        bint isVisible
        bint isTransparent

        bint shouldFullscreen
        bint shouldMinimize
        bint shouldMaximize
        bint shouldRestore
        bint shouldShow
        bint shouldHide

        # Rendering properties
        float[4] clearColor
        bint hasVSync
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
        string windowTitle
        render_fun renderCallback
        on_resize_fun resizeCallback
        on_close_fun closeCallback
        on_drop_fun dropCallback
        void* callbackData

    cdef cppclass SDLViewport(platformViewport):
        @staticmethod
        platformViewport* create(render_fun, on_resize_fun, on_close_fun, on_drop_fun, void*) except +
        void *getSDLWindowHandle()

