#include <atomic>
#include <mutex>
#include <vector>
#include <string>
#include <SDL3/SDL.h>
#include <GL/gl3w.h>
#include <imgui.h>
#include <unordered_map>
#include <unordered_set>

#pragma once

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
    /**
     * Initialize the viewport with the specified settings.
     * @throws std::runtime_error If initialization fails
     */
    virtual bool initialize() = 0;
    virtual bool processEvents(int timeout_ms = 0) = 0;
    virtual bool renderFrame(bool can_skip_presenting) = 0;
    virtual void present() = 0;
    virtual bool checkPrimaryThread() = 0;
    /**
     * Add an icon to the window icon set
     * @param data Pointer to RGBA image data
     * @param width Width of the icon in pixels
     * @param height Height of the icon in pixels
     * @param rowStride Stride between rows in bytes
     * @param colStride Stride between columns in bytes
     * @param chanStride Stride between color channels in bytes
     * @return bool Success or failure
     */
    virtual void addWindowIcon(void* data, int width, int height, 
                               int rowStride, int colStride, int chanStride) = 0;
    virtual void wakeRendering(uint64_t delay_ns, bool full_refresh) = 0;

    /**
     * Set a hit test surface for custom window border behavior
     * @param surface Pointer to uint8_t hit test data (0=normal, 1=top, 2=left, 4=bottom, 8=right, 15=drag)
     * @param width Width of the hit test surface
     * @param height Height of the hit test surface
     */
    virtual void setHitTestSurface(const uint8_t* surface, int width, int height) = 0;


    virtual void makeUploadContextCurrent() = 0;
    virtual void releaseUploadContext() = 0;
    /**
     * Create a shared OpenGL context.
     * @param major OpenGL major version
     * @param minor OpenGL minor version
     * @return A GLContext pointer which the caller is responsible for deleting
     * @throws std::runtime_error If context creation fails
     */
    virtual GLContext* createSharedContext(int major, int minor) = 0;

    /**
     * Begin exclusive write access to a texture. Must be paired with endExternalWrite.
     * Waits for any pending read operations to complete before allowing write access.
     * The GL context must be current before calling this function.
     * @param tex_id OpenGL texture identifier
     */
    virtual void beginExternalWrite(GLuint tex_id) = 0;

    /**
     * End exclusive write access to a texture and place a fence sync.
     * Must be called after beginExternalWrite once write operations are complete.
     * The GL context must be current before calling this function.
     * @param tex_id OpenGL texture identifier
     */
    virtual void endExternalWrite(GLuint tex_id) = 0;

    /**
     * Begin read access to a texture. Must be paired with endExternalRead.
     * Waits for any pending write operations to complete before allowing read access.
     * The GL context must be current before calling this function.
     * @param tex_id OpenGL texture identifier
     */
    virtual void beginExternalRead(GLuint tex_id) = 0;

    /**
     * End read access to a texture and place a fence sync.
     * Must be called after beginExternalRead once read operations are complete.
     * The GL context must be current before calling this function.
     * @param tex_id OpenGL texture identifier
     */
    virtual void endExternalRead(GLuint tex_id) = 0;

    /**
     * Allocate a new texture or reuse a cached one.
     * The upload context must be current before calling this function.
     * @param width Texture width in pixels
     * @param height Texture height in pixels
     * @param num_chans Number of color channels (1-4)
     * @param dynamic Whether texture will be frequently updated
     * @param type Pixel data type (1=byte, other=float)
     * @param filtering_mode Texture filtering (0=linear, 1=nearest, 2=font, 3=antialias)
     * @param repeat_mode Texture repeat mode flag (0=clamp, 1=repeat on x, 2=repeat on y, 3=repeat on both)
     * @return void* Cast of GLuint texture ID, or nullptr on failure
     * @throws std::runtime_error If texture allocation fails
     */
    virtual void* allocateTexture(unsigned width, unsigned height, unsigned num_chans, 
                                  unsigned dynamic, unsigned type, unsigned filtering_mode,
                                  unsigned repeat_mode) = 0;

    /**
     * Mark a texture for deletion and cache reuse.
     * Thread-safe, can be called from any thread.
     * No GL context is required as actual deletion is deferred.
     * @param texture void* Cast of GLuint texture ID
     */
    virtual void freeTexture(void* texture) = 0;

    /**
     * Update a dynamic texture with new content.
     * The upload context must be current before calling this function.
     * Uses PBO for efficient updates. PBO is created on first use.
     * @param texture void* Cast of GLuint texture ID
     * @param width Must match texture width
     * @param height Must match texture height
     * @param num_chans Must match texture channels
     * @param type Must match texture type
     * @param data Pointer to new pixel data
     * @param src_stride Bytes per row in source data
     * @return bool Success or failure
     * @throws std::runtime_error If texture update fails
     */
    virtual bool updateDynamicTexture(void* texture, unsigned width, unsigned height,
                                      unsigned num_chans, unsigned type, void* data, 
                                      unsigned src_stride) = 0;

    /**
     * Update a static texture with new content.
     * The upload context must be current before calling this function.
     * Uses PBO for efficient uploads.
     * @param texture void* Cast of GLuint texture ID 
     * @param width Must match texture width
     * @param height Must match texture height
     * @param num_chans Must match texture channels
     * @param type Must match texture type
     * @param data Pointer to new pixel data
     * @param src_stride Bytes per row in source data
     * @return bool Success or failure
     * @throws std::runtime_error If texture update fails
     */
    virtual bool updateStaticTexture(void* texture, unsigned width, unsigned height,
                                     unsigned num_chans, unsigned type, void* data, 
                                     unsigned src_stride) = 0;

    /**
     * Download texture content to CPU memory.
     * @throws std::runtime_error If texture download fails
     */
    virtual bool downloadTexture(void* texture,
                         int x,
                         int y,
                         unsigned sub_width,
                         unsigned sub_height,
                         unsigned num_chans,
                         unsigned type,
                         void* dst,
                         unsigned dst_stride) = 0;

    virtual bool backBufferToTexture(void* texture, unsigned width, unsigned height,
                                     unsigned num_chans, unsigned type) = 0;

	// Window state
    float dpiScale = 1.;
    bool isFullScreen = false;
    bool isMinimized = false;
    bool isMaximized = false;
    bool isVisible = true;
    bool isTransparent = false; // cannot change after init

    // Window requested state changes
    bool shouldFullscreen = false;
    bool shouldMinimize = false;
    bool shouldMaximize = false;
    bool shouldRestore = false;
    bool shouldShow = false;
    bool shouldHide = false;

	// Rendering properties
    float clearColor[4] = { 0., 0., 0., 1. };
    bool hasModesChanged = false;
    bool hasVSync = true; // TODO: maybe change that
    bool shouldSkipPresenting = false;
    std::atomic<bool> activityDetected{true};
    std::atomic<bool> needsRefresh{true};

    // Window properties
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
    virtual bool initialize() override;
    virtual bool processEvents(int timeout_ms) override;
    virtual bool renderFrame(bool can_skip_presenting) override;
    virtual void present() override;
    virtual bool checkPrimaryThread() override;
    virtual void addWindowIcon(void* data, int width, int height, 
                               int rowStride, int colStride, int chanStride) override;
    virtual void wakeRendering(uint64_t delay_ns, bool full_refresh) override;
    virtual void setHitTestSurface(const uint8_t* surface, int width, int height) override;
    virtual void makeUploadContextCurrent() override;
    virtual void releaseUploadContext() override;
    virtual GLContext* createSharedContext(int major, int minor) override;

    /**
     * Begin exclusive write access to a texture. Must be paired with endExternalWrite.
     * Waits for any pending read operations to complete before allowing write access.
     * The GL context must be current before calling this function.
     * @param tex_id OpenGL texture identifier
     */
    virtual void beginExternalWrite(GLuint tex_id) override;

    /**
     * End exclusive write access to a texture and place a fence sync.
     * Must be called after beginExternalWrite once write operations are complete.
     * The GL context must be current before calling this function.
     * @param tex_id OpenGL texture identifier
     */
    virtual void endExternalWrite(GLuint tex_id) override;

    /**
     * Begin read access to a texture. Must be paired with endExternalRead.
     * Waits for any pending write operations to complete before allowing read access.
     * The GL context must be current before calling this function.
     * @param tex_id OpenGL texture identifier
     */
    virtual void beginExternalRead(GLuint tex_id) override;

    /**
     * End read access to a texture and place a fence sync.
     * Must be called after beginExternalRead once read operations are complete.
     * The GL context must be current before calling this function.
     * @param tex_id OpenGL texture identifier
     */
    virtual void endExternalRead(GLuint tex_id) override;

    /**
     * Allocate a new texture or reuse a cached one.
     * The upload context must be current before calling this function.
     * @param width Texture width in pixels
     * @param height Texture height in pixels
     * @param num_chans Number of color channels (1-4)
     * @param dynamic Whether texture will be frequently updated
     * @param type Pixel data type (1=byte, other=float)
     * @param filtering_mode Texture filtering (0=linear, 1=nearest, 2=font, 3=antialias)
     * @param repeat_mode Texture repeat mode flag (0=clamp, 1=repeat on x, 2=repeat on y, 3=repeat on both)
     * @return void* Cast of GLuint texture ID, or nullptr on failure
     * @throws std::runtime_error If texture allocation fails
     */
    virtual void* allocateTexture(unsigned width, unsigned height, unsigned num_chans, 
                                  unsigned dynamic, unsigned type, unsigned filtering_mode,
                                  unsigned repeat_mode) override;

    /**
     * Mark a texture for deletion and cache reuse.
     * Thread-safe, can be called from any thread.
     * No GL context is required as actual deletion is deferred.
     * @param texture void* Cast of GLuint texture ID
     */
    virtual void freeTexture(void* texture) override;

    /**
     * Update a dynamic texture with new content.
     * The upload context must be current before calling this function.
     * Uses PBO for efficient updates. PBO is created on first use.
     * @param texture void* Cast of GLuint texture ID
     * @param width Must match texture width
     * @param height Must match texture height
     * @param num_chans Must match texture channels
     * @param type Must match texture type
     * @param data Pointer to new pixel data
     * @param src_stride Bytes per row in source data
     * @return bool Success or failure
     * @throws std::runtime_error If texture update fails
     */
    virtual bool updateDynamicTexture(void* texture, unsigned width, unsigned height,
                                      unsigned num_chans, unsigned type, void* data, 
                                      unsigned src_stride) override;

    /**
     * Update a static texture with new content.
     * The upload context must be current before calling this function.
     * Uses PBO for efficient uploads.
     * @param texture void* Cast of GLuint texture ID 
     * @param width Must match texture width
     * @param height Must match texture height
     * @param num_chans Must match texture channels
     * @param type Must match texture type
     * @param data Pointer to new pixel data
     * @param src_stride Bytes per row in source data
     * @return bool Success or failure
     * @throws std::runtime_error If texture update fails
     */
    virtual bool updateStaticTexture(void* texture, unsigned width, unsigned height,
                                     unsigned num_chans, unsigned type, void* data, 
                                     unsigned src_stride) override;

    static SDLViewport* create(render_fun render,
                               on_resize_fun on_resize,
                               on_close_fun on_close,
                               on_drop_fun on_drop,
                               void* callback_data);

    void prepareTexturesForRender(const std::unordered_set<GLuint>& tex_ids);
    void finishTextureRender(const std::unordered_set<GLuint>& tex_ids);

    virtual bool downloadTexture(void* texture,
                         int x,
                         int y,
                         unsigned sub_width,
                         unsigned sub_height,
                         unsigned num_chans,
                         unsigned type,
                         void* dst,
                         unsigned dst_stride) override;

    virtual bool backBufferToTexture(void* texture, unsigned width, unsigned height,
                                     unsigned num_chans, unsigned type) override;

    void *getSDLWindowHandle() { return (void*)windowHandle; }

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
    // Icon handling
    SDL_Surface* iconSurface = nullptr;

    // Hit test surface data
    std::recursive_mutex hitMutex; 
    std::vector<uint8_t> hitTestSurface;
    int hitTestWidth = 0;
    int hitTestHeight = 0;

    // SDL hit test callback and helper
    static SDL_HitTestResult HitTestCallback(SDL_Window* win, const SDL_Point* area, void* data);
    SDL_HitTestResult ProcessHitTest(const SDL_Point* area);

    // GL extension support flags
    bool has_texture_storage = false;
    bool has_buffer_storage = false;
    bool has_anisotropic_filter = false;
    float max_anisotropy = 1.0f;

    // Fence management
    struct FenceSync {
        GLsync sync = nullptr;
        int refcount = 0;
    };

    struct TextureInfo {
        unsigned width;
        unsigned height;
        unsigned num_chans;
        unsigned type;
        unsigned filter_mode;
        bool dynamic;
        GLuint pbo;
        int last_use_frame;
        int deletion_frame; // Frame when texture was marked for deletion, -1 if active
        FenceSync* write_fence = nullptr;  // Shared fence after writes 
        FenceSync* read_fence = nullptr;   // Shared fence after reads
        bool has_external_writers = false; // Track if external contexts are writing
        bool has_external_readers = false; // Track if external contexts are reading
    };

    // Texture management 
    static const int CACHE_REUSE_FRAMES = 3;
    static const size_t CACHE_MEMORY_THRESHOLD = 128 * 1024 * 1024; // 128MB
    std::recursive_mutex textureMutex;  
    std::unordered_map<GLuint, TextureInfo> textureInfoMap;
    size_t deletedTexturesMemory = 0;  // Track memory of textures pending deletion
    int currentFrame = 0;

    void cleanupTextures();
    GLuint findTextureInCache(unsigned width, unsigned height, unsigned num_chans,
                             unsigned type, unsigned filter_mode, bool dynamic);
    size_t getTextureSize(unsigned width, unsigned height, unsigned num_chans, unsigned type);

    void preparePresentFrame();
    bool updateTexture(void* texture, unsigned width, unsigned height,
                      unsigned num_chans, unsigned type, void* data, 
                      unsigned src_stride, bool dynamic);

    /**
     * Wait for all write operations on a texture to complete.
     * Must be called with textureMutex held and context current.
     * @param info Reference to texture info
     */
    void waitTextureReadable(TextureInfo& info);

    /**
     * Wait for all read operations on a texture to complete.
     * Must be called with textureMutex held and context current.
     * @param info Reference to texture info
     */
    void waitTextureWritable(TextureInfo& info);

    /**
     * Place a read fence sync after reading from texture.
     * Must be called with textureMutex held and context current.
     * @param info Reference to texture info
     */
    void markTextureRead(TextureInfo& info);

    /**
     * Place a write fence sync after writing to texture.
     * Must be called with textureMutex held and context current.
     * @param info Reference to texture info
     */
    void markTextureWritten(TextureInfo& info);

    // Fence management methods
    void waitOnFenceSync(FenceSync* fence);
    void retainFenceSync(FenceSync* fence);
    void releaseFenceSync(FenceSync* fence);
    FenceSync* createFenceSync();

    // Thread safety
    static SDL_ThreadID sdlMainThreadId;  // Thread that first initialized SDL
    static std::atomic<bool> sdlInitialized;
    static std::mutex sdlInitMutex;
    static std::atomic<int> viewportCount;
    
    // Event queue for forwarding events
    std::vector<SDL_Event> deferredEvents;
};