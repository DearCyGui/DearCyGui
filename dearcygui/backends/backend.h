#include <atomic>
#include <mutex>
#include <vector>
#include <string>
#include <SDL3/SDL.h>
#include <imgui.h>

typedef void (*on_resize_fun)(void*);
typedef void (*on_close_fun)(void*);
typedef void (*render_fun)(void*);
typedef void (*on_drop_fun)(void*, int, const char*);


// A class to wrap a GL context, make it current, release it.
class GLContext
{
public:
    GLContext() = default;
    virtual ~GLContext() = default;

    virtual void makeCurrent() = 0;
    virtual void release() = 0;
};

class platformViewport
{
public:
    platformViewport() = default;
    virtual ~platformViewport() = default;

    virtual void cleanup() = 0;
    virtual bool initialize(bool start_minimized, bool start_maximized) = 0;
    virtual void maximize() = 0;
    virtual void minimize() = 0;
    virtual void restore() = 0;
    virtual void processEvents() = 0;
    virtual bool renderFrame(bool can_skip_presenting) = 0;
    virtual void present() = 0;
    virtual void toggleFullScreen() = 0;
    virtual void wakeRendering() = 0;
    virtual void makeUploadContextCurrent() = 0;
    virtual void releaseUploadContext() = 0;
    virtual GLContext* createSharedContext(int major, int minor) = 0;

	// makeUploadContextCurrent must be called before any texture
	// operations are performed, and releaseUploadContext must be
	// called after the texture operations are done.
    virtual void* allocateTexture(unsigned width, unsigned height, unsigned num_chans, 
                                unsigned dynamic, unsigned type, unsigned filtering_mode) = 0;
    virtual void freeTexture(void* texture) = 0;
    virtual bool updateDynamicTexture(void* texture, unsigned width, unsigned height,
                                   unsigned num_chans, unsigned type, void* data, 
                                   unsigned src_stride) = 0;
    virtual bool updateStaticTexture(void* texture, unsigned width, unsigned height,
                                   unsigned num_chans, unsigned type, void* data, 
                                   unsigned src_stride) = 0;
    virtual bool downloadBackBuffer(void* data, int size) = 0;

	// Window state
    float dpiScale = 1.;
    bool isFullScreen = false;
    bool isMinimized = false;
    bool isMaximized = false;

	// Rendering properties
    float clearColor[4] = { 0., 0., 0., 1. };
    bool hasModesChanged = false;
    bool hasVSync = true;
    bool waitForEvents = false;
    bool shouldSkipPresenting = false;
    std::atomic<bool> activityDetected{true};
    std::atomic<bool> needsRefresh{true};

    // Window properties
    std::string iconSmall; // not allowed to change after init
    std::string iconLarge; // same
    std::string windowTitle = "DearCyGui Window";
    bool titleChangeRequested = false;
    bool windowResizable = true;
    bool windowAlwaysOnTop = false;
    bool windowDecorated = true;
    bool windowPropertyChangeRequested = false;

    // Window position/size
    int positionX = 100;
    int positionY = 100;
    bool positionChangeRequested = false;
    unsigned minWidth = 250;
    unsigned minHeight = 250;
    unsigned maxWidth = 10000;
    unsigned maxHeight = 10000;
    int frameWidth = 1280;   // frame buffer size
    int frameHeight = 800;
    int windowWidth = 1280;  // window size
    int windowHeight = 800;
    bool sizeChangeRequested = false;

protected:

    // Callbacks
    render_fun renderCallback;
    on_resize_fun resizeCallback;
    on_close_fun closeCallback;
    on_drop_fun dropCallback;
    void* callbackData;

    // Utility the does a cheap test for 
	// there has been any activity the
	// requires a render.
    static bool fastActivityCheck();
};


class SDLViewport : public platformViewport 
{
public:
    virtual void cleanup() override;
    virtual bool initialize(bool start_minimized, bool start_maximized) override;
    virtual void maximize() override;
    virtual void minimize() override;
    virtual void restore() override;
    virtual void processEvents() override;
    virtual bool renderFrame(bool can_skip_presenting) override;
    virtual void present() override;
    virtual void toggleFullScreen() override;
    virtual void wakeRendering() override;
    virtual void makeUploadContextCurrent() override;
    virtual void releaseUploadContext() override;
    virtual GLContext* createSharedContext(int major, int minor) override;

    virtual void* allocateTexture(unsigned width, unsigned height, unsigned num_chans, 
                                  unsigned dynamic, unsigned type, unsigned filtering_mode) override;
    virtual void freeTexture(void* texture) override;
    virtual bool updateDynamicTexture(void* texture, unsigned width, unsigned height,
                                      unsigned num_chans, unsigned type, void* data, 
                                      unsigned src_stride) override;
    virtual bool updateStaticTexture(void* texture, unsigned width, unsigned height,
                                     unsigned num_chans, unsigned type, void* data, 
                                     unsigned src_stride) override;
    virtual bool downloadBackBuffer(void* data, int size) override;

    static SDLViewport* create(render_fun render,
                               on_resize_fun on_resize,
                               on_close_fun on_close,
                               on_drop_fun on_drop,
                               void* callback_data);

private:
    SDL_Window* windowHandle = nullptr;
    SDL_Window* uploadWindowHandle = nullptr;
    SDL_GLContext glContext = nullptr;
    SDL_GLContext uploadGLContext = nullptr;
    std::mutex renderContextLock;
    std::mutex uploadContextLock;
    bool hasOpenGL3Init = false;
    bool hasSDL3Init = false;
    bool hasResized = false;

    // GL extension support flags
    bool has_texture_storage = false;
    bool has_buffer_storage = false;

    void preparePresentFrame();
    bool updateTexture(void* texture,
                       unsigned width, unsigned height,
                       unsigned num_chans, unsigned type, void* data, 
                       unsigned src_stride, bool dynamic);
};