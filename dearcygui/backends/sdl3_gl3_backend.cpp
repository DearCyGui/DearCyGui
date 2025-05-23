#include <string>
#include <vector>
#include <unordered_map>
#include <unordered_set>
#include <GL/gl3w.h>
#include <GL/glext.h>
#include <SDL3/SDL.h>
#include "backend.h"

#include "implot.h"
#include "imgui.h"
#include "imgui_internal.h"
#include "imgui_impl_sdl3.h"
#include "imgui_impl_opengl3.h"
#include <stdio.h>

#include <functional>
#include <mutex>
#include <chrono>

SDL_ThreadID SDLViewport::sdlMainThreadId = 0;
std::atomic<bool> SDLViewport::sdlInitialized{false};
std::mutex SDLViewport::sdlInitMutex;
std::atomic<int> SDLViewport::viewportCount{0};

bool platformViewport::fastActivityCheck() {
    ImGuiContext& g = *GImGui;

    /* Change in active ID or hovered ID might trigger animation */
    if (g.ActiveIdPreviousFrame != g.ActiveId ||
        g.HoveredId != g.HoveredIdPreviousFrame ||
        g.NavJustMovedToId)
        return true;

    for (int button = 0; button < IM_ARRAYSIZE(g.IO.MouseDown); button++) {
        /* Dragging item likely needs refresh */
        if (g.IO.MouseDown[button] && g.IO.MouseDragMaxDistanceSqr[button] > 0)
            return true;
        /* Releasing or clicking mouse might trigger things */
        if (g.IO.MouseReleased[button] || g.IO.MouseClicked[button])
            return true;
    }

    /* Cursor needs redraw */
    if (g.IO.MouseDrawCursor && \
        (g.IO.MouseDelta.x != 0. ||
         g.IO.MouseDelta.y != 0.))
        return true;

    return false;
}

// Move prepare_present implementation into class method
void SDLViewport::preparePresentFrame() {
    SDL_GetWindowPosition(windowHandle, &positionX, &positionY);

    // Rendering
    ImGui::Render();
    renderContextLock.lock();
    SDL_GL_MakeCurrent(windowHandle, glContext);
    if (hasResized) {
        dpiScale = SDL_GetWindowDisplayScale(windowHandle);
        SDL_GetWindowSizeInPixels(windowHandle, &frameWidth, &frameHeight);
        windowWidth = (int)((float)frameWidth / dpiScale);
        windowHeight = (int)((float)frameHeight / dpiScale);
        hasResized = false;
        resizeCallback(callbackData);
    }

    int current_interval, desired_interval;
    SDL_GL_GetSwapInterval(&current_interval);
    desired_interval = hasVSync ? 1 : 0;
    if (desired_interval != current_interval)
        SDL_GL_SetSwapInterval(desired_interval);
    glDrawBuffer(GL_BACK);
    glViewport(0, 0, frameWidth, frameHeight);
    glClearColor(clearColor[0], clearColor[1], clearColor[2], clearColor[3]);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    {
        // We hold the mutex during the call to prevent
        // texture write before we set up the write syncs.
        std::lock_guard<std::recursive_mutex> lock(textureMutex);
        ImGui_ImplOpenGL3_RenderDrawData(this, ImGui::GetDrawData());
    }
    currentFrame++; // should it be mutex protected ?
    cleanupTextures();
    SDL_GL_MakeCurrent(windowHandle, NULL);
    renderContextLock.unlock();
}


GLuint SDLViewport::findTextureInCache(unsigned width, unsigned height, unsigned num_chans,
                                      unsigned type, unsigned filter_mode, bool dynamic) {
    std::lock_guard<std::recursive_mutex> lock(textureMutex);
    // Look for reusable texture in cache
    GLuint best_tex_id = 0;
    int best_deletion_frame = 0x7fffffff; // Maximum value for signed 32-bit integer

    for(auto& tex_pair : textureInfoMap) {
        GLuint tex_id = tex_pair.first;
        TextureInfo& info = tex_pair.second;
        if(info.deletion_frame >= 0 &&
           info.deletion_frame < (currentFrame - CACHE_REUSE_FRAMES) &&
           info.width == width &&
           info.height == height && 
           info.num_chans == num_chans &&
           info.type == type &&
           info.dynamic == dynamic &&
           info.filter_mode == filter_mode) {
            // Wait for any pending operations before reusing
            if(info.write_fence || info.has_external_writers || 
               info.read_fence || info.has_external_readers) {
                waitTextureReadable(info);
                waitTextureWritable(info);
                
                // Clean up fences
                releaseFenceSync(info.write_fence);
                releaseFenceSync(info.read_fence);
                info.write_fence = nullptr;
                info.read_fence = nullptr;
            }

            // Track texture with oldest deletion frame
            if (info.deletion_frame < best_deletion_frame) {
                best_tex_id = tex_id;
                best_deletion_frame = info.deletion_frame;
            }
        }
    }

    if (best_tex_id != 0) {
        // Found matching cached texture
        auto& info = textureInfoMap[best_tex_id];
        deletedTexturesMemory -= getTextureSize(info.width, info.height, info.num_chans, info.type);
        info.deletion_frame = -1; // Mark as active
        return best_tex_id;
    }

    return 0;
}

void* SDLViewport::allocateTexture(unsigned width, unsigned height, unsigned num_chans, 
                                   unsigned dynamic, unsigned type, unsigned filtering_mode,
                                   unsigned repeat_mode) {
    // Look for a cached texture first
    GLuint image_texture = 0;
    {
        std::lock_guard<std::recursive_mutex> lock(textureMutex);
        image_texture = findTextureInCache(width, height, num_chans, type, filtering_mode, dynamic != 0);
        if (image_texture != 0)
            return (void*)(size_t)image_texture;
    }

    // Making the sure the context is current
    // is the responsibility of the caller
    // But if we were to change this,
    // here is commented out code to do it.
    //makeUploadContextCurrent();
    unsigned gl_format = GL_RGBA;
    unsigned gl_internal_format = GL_RGBA8;
    unsigned gl_type = GL_FLOAT;

    switch (num_chans) {
    case 4:
        gl_format = GL_RGBA;
        gl_internal_format = type == 1 ? GL_RGBA8 : GL_RGBA32F;
        break;
    case 3:
        gl_format = GL_RGB; 
        gl_internal_format = type == 1 ? GL_RGB8 : GL_RGB32F;
        break;
    case 2:
        gl_format = GL_RG;
        gl_internal_format = type == 1 ? GL_RG8 : GL_RG32F;
        break;
    case 1:
    default:
        gl_format = GL_RED;
        gl_internal_format = type == 1 ? GL_R8 : GL_R32F;
        break;
    }

    if (type == 1) {
        gl_type = GL_UNSIGNED_BYTE;
    }

    glGenTextures(1, &image_texture);
    if (glGetError() != GL_NO_ERROR) {
        //releaseUploadContext();
        return NULL;
    }
    glBindTexture(GL_TEXTURE_2D, image_texture);

    if (filtering_mode == 2)
        repeat_mode = 0; // Fonts need clamping

    // Set wrapping mode
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, (repeat_mode & 1) ? GL_REPEAT : GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, (repeat_mode & 2) ? GL_REPEAT : GL_CLAMP_TO_EDGE);

    // Setup filtering parameters for display
    if (filtering_mode == 3) {  // New mode for mipmapped pattern textures
        // Calculate mipmap levels based primarily on width for pattern textures
        int mip_levels = 1 + floor(log2(width));

        // Set trilinear filtering for smooth transitions between mip levels
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

        // Enable anisotropic filtering if available (helps with pattern quality)
        if (has_anisotropic_filter) {
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY_EXT, max_anisotropy);
        }

        // Set the base and max mipmap levels to use
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_BASE_LEVEL, 0);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, mip_levels - 1);

        float maxLod = log2f(width);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_LOD, 0.0f);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAX_LOD, maxLod);

        // Apply small LOD bias for better antialiasing
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_LOD_BIAS, 0.5f);

        // Create texture storage with appropriate mipmap levels
        if (has_texture_storage) {
            glTexStorage2D(GL_TEXTURE_2D, mip_levels, gl_internal_format, width, height);
        } else {
            glTexImage2D(GL_TEXTURE_2D, 0, gl_internal_format, width, height, 0, gl_format, gl_type, NULL);
        }
    } else {
        // Original filtering modes (0, 1, 2)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, (filtering_mode == 1) ? GL_NEAREST : GL_LINEAR);

        // Use immutable texture storage if available (for performance)
        if (has_texture_storage) {
            glTexStorage2D(GL_TEXTURE_2D, 1, gl_internal_format, width, height);
        } else {
            glTexImage2D(GL_TEXTURE_2D, 0, gl_internal_format, width, height, 0, gl_format, gl_type, NULL);
        }
    }

    // Duplicate the first channel on g and b to display as gray
    if (num_chans == 1) {
        if (filtering_mode == 2) {
            /* Font. Load as 111A */
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_R, GL_ONE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_G, GL_ONE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_B, GL_ONE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_A, GL_RED);
        } else {
            /* rrr1 */
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_G, GL_RED);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_B, GL_RED);
        }
    }

    if (glGetError() != GL_NO_ERROR) {
        glDeleteTextures(1, &image_texture);
        //releaseUploadContext();
        return NULL;
    }

    // Unbind texture
    glBindTexture(GL_TEXTURE_2D, 0);
    glFlush();
    //releaseUploadContext();

    // Add to texture info map with initialized sync objects
    if(image_texture != 0) {
        std::lock_guard<std::recursive_mutex> lock(textureMutex);
        textureInfoMap[image_texture] = {
            width,
            height,
            num_chans, 
            type,
            filtering_mode,
            dynamic != 0,
            0, // PBO will be created later if needed
            -1, // Last use frame
            -1, // Mark as active
            nullptr, // write_sync
            nullptr, // read_sync 
            false,   // has_external_writers
            false    // has_external_readers
        };
    }

    return (void*)(size_t)image_texture;
}

void SDLViewport::freeTexture(void* texture) {
    GLuint tex_id = (GLuint)(size_t)texture;
    
    std::lock_guard<std::recursive_mutex> lock(textureMutex);
    auto it = textureInfoMap.find(tex_id);
    if(it != textureInfoMap.end()) {
        it->second.deletion_frame = currentFrame;
        deletedTexturesMemory += getTextureSize(it->second.width, it->second.height,
                                              it->second.num_chans, it->second.type);
        
        // If too much memory is in deleted textures, force a cleanup
        if (deletedTexturesMemory > CACHE_MEMORY_THRESHOLD) {
            cleanupTextures();
        }
    }
}

bool SDLViewport::updateTexture(void* texture, unsigned width, unsigned height,
                              unsigned num_chans, unsigned type, void* data,
                              unsigned src_stride, bool dynamic) {
    auto texture_id = (GLuint)(size_t)texture;
    TextureInfo info;
    bool valid_texture = false;
    
    // Quick validation under lock
    {
        std::lock_guard<std::recursive_mutex> lock(textureMutex);
        auto it = textureInfoMap.find(texture_id);
        if(it != textureInfoMap.end() && it->second.deletion_frame < 0) {
            // Copy texture info for validation outside lock
            info = it->second;
            valid_texture = true;
        }
    }

    if(!valid_texture) {
        return false;
    }

    // Validate texture parameters haven't changed
    if(info.width != width || info.height != height || 
       info.num_chans != num_chans || info.type != type) {
        return false;
    }

    unsigned gl_format = GL_RGBA;
    unsigned gl_type = GL_FLOAT;
    unsigned type_size = 4;
    GLuint pboid = 0;
    GLubyte* ptr;

    switch (num_chans)
    {
    case 4:
        gl_format = GL_RGBA;
        break;
    case 3:
        gl_format = GL_RGB;
        break;
    case 2:
        gl_format = GL_RG;
        break;
    case 1:
    default:
        gl_format = GL_RED;
        break;
    }

    if (type == 1) {
        gl_type = GL_UNSIGNED_BYTE;
        type_size = 1;
    }

    if(info.pbo == 0) {
        glGenBuffers(1, &pboid);
        if (glGetError() != GL_NO_ERROR)
            goto error;
        
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, pboid);
        if (glGetError() != GL_NO_ERROR)
            goto error;

        if (dynamic && has_buffer_storage) {
            GLbitfield flags = GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT;
            glBufferStorage(GL_PIXEL_UNPACK_BUFFER, width * height * num_chans * type_size, 
                          NULL, flags);
        } else {
            glBufferData(GL_PIXEL_UNPACK_BUFFER, width * height * num_chans * type_size,
                        NULL, dynamic ? GL_STREAM_DRAW : GL_STATIC_DRAW);
        }
    } else {
        glBindBuffer(GL_PIXEL_UNPACK_BUFFER, info.pbo);
        if (glGetError() != GL_NO_ERROR)
            goto error;
    }

    // Buffer mapping and data copy happens outside lock
    ptr = (GLubyte*)glMapBufferRange(GL_PIXEL_UNPACK_BUFFER, 0,
                                    width * height * num_chans * type_size,
                                    GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_RANGE_BIT);
    if (!ptr)
        goto error;

    if (src_stride == (width * num_chans * type_size))
        memcpy(ptr, data, width * height * num_chans * type_size);
    else {
        for (unsigned row = 0; row < height; row++) {
            memcpy(ptr, data, width * num_chans * type_size);
            ptr = (GLubyte*)(((unsigned char*)ptr) + width * num_chans * type_size);
            data = (void*)(((unsigned char*)data) + src_stride);
        }
    }
    glUnmapBuffer(GL_PIXEL_UNPACK_BUFFER);

    {
        std::lock_guard<std::recursive_mutex> lock(textureMutex);
        auto it = textureInfoMap.find(texture_id);
        if(it == textureInfoMap.end() || it->second.deletion_frame >= 0) {
            goto error;
        }

        // Store newly created PBO
        if(pboid != 0) {
            it->second.pbo = pboid;
        }

        waitTextureWritable(it->second);

        glBindTexture(GL_TEXTURE_2D, texture_id);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width, height, gl_format, gl_type, NULL);

        // Generate mipmaps for mipmapped pattern textures (mode 3)
        if (it->second.filter_mode == 3) {
            glGenerateMipmap(GL_TEXTURE_2D);
        }
        
        markTextureWritten(it->second);

        // Check if texture is on screen right now
        if (it->second.last_use_frame >= currentFrame-1)
            needsRefresh.store(true);
    }

    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
    if (glGetError() != GL_NO_ERROR)
        goto error;

    glFlush();
    return true;

error:
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
    if(pboid != 0) {
        glDeleteBuffers(1, &pboid);
    }
    return false;
}

bool SDLViewport::updateDynamicTexture(void* texture, unsigned width, unsigned height,
                                    unsigned num_chans, unsigned type, void* data,
                                    unsigned src_stride) {
    return updateTexture(texture, width, height, num_chans, type, data, src_stride, true);
}

bool SDLViewport::updateStaticTexture(void* texture, unsigned width, unsigned height,
                                   unsigned num_chans, unsigned type, void* data,
                                   unsigned src_stride) {
    return updateTexture(texture, width, height, num_chans, type, data, src_stride, false);
}

SDLViewport* SDLViewport::create(render_fun render,
                             on_resize_fun on_resize,
                             on_close_fun on_close,
                             on_drop_fun on_drop,
                             void* callback_data) {
    std::lock_guard<std::mutex> lock(sdlInitMutex);
    
    // Initialize SDL in the first thread that creates a viewport
    if (!sdlInitialized) {
#ifdef _WIN32
        if (!SDL_Init(SDL_INIT_VIDEO)) {
#else
        if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD)) {
#endif
            printf("Error: SDL_Init(): %s\n", SDL_GetError());
            return nullptr;
        }
        sdlMainThreadId = SDL_GetCurrentThreadID();
        sdlInitialized = true;
    } else if (SDL_GetCurrentThreadID() != sdlMainThreadId) {
        fprintf(stderr, "Error: Contexts creation must be performed in the same thread\n");
        return nullptr;
    }

    auto viewport = new SDLViewport();
    viewportCount++;  // Increment counter on creation
    viewport->renderCallback = render;
    viewport->resizeCallback = on_resize;
    viewport->closeCallback = on_close;
    viewport->dropCallback = on_drop;
    viewport->callbackData = callback_data;
    
    // Create secondary window/context
    viewport->uploadWindowHandle = SDL_CreateWindow("DearCyGui upload context", 
        640, 480, SDL_WINDOW_OPENGL | SDL_WINDOW_HIDDEN | SDL_WINDOW_UTILITY);
    if (viewport->uploadWindowHandle == nullptr)
        return nullptr;

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG); // Always required on Mac
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_FRAMEBUFFER_SRGB_CAPABLE, 1);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
    SDL_GL_SetAttribute(SDL_GL_SHARE_WITH_CURRENT_CONTEXT, 1);
    viewport->uploadGLContext = SDL_GL_CreateContext(viewport->uploadWindowHandle);

    // If creation failed and we tried to share, try again without sharing
    if (viewport->uploadGLContext == nullptr) {
        SDL_GL_SetAttribute(SDL_GL_SHARE_WITH_CURRENT_CONTEXT, 0);
        viewport->uploadGLContext = SDL_GL_CreateContext(viewport->uploadWindowHandle);
    }

    if (viewport->uploadGLContext == nullptr)
        return nullptr;
    if (gl3wInit() != GL3W_OK)
        return nullptr;
    // Check for important extensions 
    viewport->has_texture_storage = SDL_GL_ExtensionSupported("GL_ARB_texture_storage");
    viewport->has_buffer_storage = SDL_GL_ExtensionSupported("GL_ARB_buffer_storage");
    viewport->has_anisotropic_filter = SDL_GL_ExtensionSupported("GL_EXT_texture_filter_anisotropic");
    if (viewport->has_anisotropic_filter) {
        GLfloat max_anisotropy = 0.f;
        glGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, &max_anisotropy);
        viewport->max_anisotropy = max_anisotropy;
    }
    // All our uploads have no holes
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    SDL_GL_MakeCurrent(viewport->uploadWindowHandle, NULL);
    auto primary_display = SDL_GetPrimaryDisplay();
    viewport->dpiScale = SDL_GetDisplayContentScale(primary_display);
    if (viewport->dpiScale == 0.f)
        viewport->dpiScale = 1.0f;
    return viewport;
}

// Implementation of SDLViewport methods
void SDLViewport::cleanup() {
    if (!checkPrimaryThread()) return;
    
    std::lock_guard<std::recursive_mutex> lock(textureMutex);
    // Clean up all GL resources properly before destroying contexts
    if (uploadWindowHandle != nullptr && uploadGLContext != nullptr) {
        uploadContextLock.lock();
        SDL_GL_MakeCurrent(uploadWindowHandle, uploadGLContext);
        for (auto& pair : textureInfoMap) {
            TextureInfo& info = pair.second;
            if (info.write_fence) {
                glWaitSync(info.write_fence->sync, 0, GL_TIMEOUT_IGNORED);
                releaseFenceSync(info.write_fence);
                info.write_fence = nullptr;
            }
            if (info.read_fence) {
                glWaitSync(info.read_fence->sync, 0, GL_TIMEOUT_IGNORED);
                releaseFenceSync(info.read_fence);
                info.read_fence = nullptr;
            }
            if (info.pbo) {
                glDeleteBuffers(1, &info.pbo);
            }
            glDeleteTextures(1, &pair.first);
        }
        textureInfoMap.clear();
        deletedTexturesMemory = 0;
        SDL_GL_MakeCurrent(uploadWindowHandle, nullptr);
        uploadContextLock.unlock();
    }
    if (uploadGLContext != nullptr) {
        SDL_GL_DestroyContext(uploadGLContext);
        uploadGLContext = nullptr;
    }
    if (uploadWindowHandle != nullptr) {
        SDL_DestroyWindow(uploadWindowHandle);
        uploadWindowHandle = nullptr;
    }

    // Clean up icon surface
    if (iconSurface) {
        SDL_DestroySurface(iconSurface);
        iconSurface = nullptr;
    }

    // Only cleanup if initialization was successful
    if (hasOpenGL3Init) {
        renderContextLock.lock();
        SDL_GL_MakeCurrent(windowHandle, glContext);
        ImGui_ImplOpenGL3_Shutdown();
        SDL_GL_MakeCurrent(windowHandle, NULL);
        renderContextLock.unlock();
    }

    if (hasSDL3Init) {
        ImGui_ImplSDL3_Shutdown();
    }

    if (glContext != nullptr) {
        SDL_GL_DestroyContext(glContext);
        glContext = nullptr;
    }

    if (windowHandle != nullptr) {
        SDL_DestroyWindow(windowHandle);
        windowHandle = nullptr;
    }

    // Only quit SDL when the last viewport is destroyed
    if (--viewportCount == 0) {
        SDL_Quit();
    }
}

bool SDLViewport::initialize() {
    if (!checkPrimaryThread()) return false;
    const char* glsl_version = "#version 150";

    SDL_WindowFlags creation_flags = 0;
    if (windowResizable)
        creation_flags |= SDL_WINDOW_RESIZABLE;
    if (windowAlwaysOnTop)
        creation_flags |= SDL_WINDOW_ALWAYS_ON_TOP;
    if (shouldMaximize)
        creation_flags |= SDL_WINDOW_MAXIMIZED;
    else if (shouldMinimize)
        creation_flags |= SDL_WINDOW_MINIMIZED;
    if (!windowDecorated)
        creation_flags |= SDL_WINDOW_BORDERLESS;

    // Create window with graphics context
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG); // Always required on Mac
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
    SDL_GL_SetAttribute(SDL_GL_SHARE_WITH_CURRENT_CONTEXT, 1);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
    SDL_GL_SetAttribute(SDL_GL_FRAMEBUFFER_SRGB_CAPABLE, 1);
    //SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
    //SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, 8);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_RELEASE_BEHAVIOR, SDL_GL_CONTEXT_RELEASE_BEHAVIOR_NONE);
    uploadContextLock.lock();
    // Set current to allow sharing
    SDL_GL_MakeCurrent(uploadWindowHandle, uploadGLContext);

    // We are trying to be invariant to platforms on the user side
    // we try to maintain:
    // windowWidth = frameWidth / SDL_GetWindowDisplayScale

    // On the OS side, the actual width to request is:
    // frameWidth / SDL_GetWindowPixelDensity
    // which corresponds to
    // windowWidth * SDL_GetWindowDisplayScale / SDL_GetWindowPixelDensity
    // Since we don't now them yet as the window is not created yet,
    // we first set an initial window size and then adjust it after creation
    
    windowHandle = SDL_CreateWindow(windowTitle.c_str(), windowWidth, windowHeight,
        creation_flags | SDL_WINDOW_OPENGL | SDL_WINDOW_HIGH_PIXEL_DENSITY | SDL_WINDOW_HIDDEN);
    if (windowHandle == nullptr) {
        SDL_GL_MakeCurrent(uploadWindowHandle, NULL);
        uploadContextLock.unlock();
        return false;
    }

    // Apply icon if we have one
    if (iconSurface != nullptr) {
        SDL_SetWindowIcon(windowHandle, iconSurface);
    }

    glContext = SDL_GL_CreateContext(windowHandle);
    if (glContext == nullptr) {
        SDL_DestroyWindow(windowHandle);
        SDL_GL_MakeCurrent(uploadWindowHandle, NULL);
        uploadContextLock.unlock();
        return false;
    }

    SDL_GL_MakeCurrent(windowHandle, NULL);
    SDL_GL_MakeCurrent(uploadWindowHandle, NULL);
    uploadContextLock.unlock();
    //glfwSetWindowPos(sdlViewport->handle, viewport.xpos, viewport.ypos); // SDL_SetWindowPosition
    dpiScale = SDL_GetWindowDisplayScale(windowHandle);
    float logical_to_pixel_factor = SDL_GetWindowPixelDensity(windowHandle);
    float factor = dpiScale / logical_to_pixel_factor;
    if (dpiScale == 0. || logical_to_pixel_factor == 0.) {
        dpiScale = 1.f;
        factor = 1.f;
    }
    SDL_SetWindowSize(windowHandle, (int)(windowWidth * factor), (int)(windowHeight * factor));
    SDL_SetWindowMaximumSize(windowHandle, (int)(maxWidth * factor), (int)(maxHeight * factor));
    SDL_SetWindowMinimumSize(windowHandle, (int)(minWidth * factor), (int)(minHeight * factor));
    if (!shouldHide)
        SDL_ShowWindow(windowHandle);

    // Retry after showing the window and getting the actual values
    SDL_SyncWindow(windowHandle);
    dpiScale = SDL_GetWindowDisplayScale(windowHandle);
    logical_to_pixel_factor = SDL_GetWindowPixelDensity(windowHandle);
    float updated_factor = dpiScale / logical_to_pixel_factor;
    if (dpiScale == 0. || logical_to_pixel_factor == 0.) {
        dpiScale = 1.f;
        factor = 1.f;
    }
    if (factor != updated_factor) {
        SDL_SetWindowSize(windowHandle, (int)(windowWidth * factor), (int)(windowHeight * factor));
        SDL_SetWindowMaximumSize(windowHandle, (int)(maxWidth * factor), (int)(maxHeight * factor));
        SDL_SetWindowMinimumSize(windowHandle, (int)(minWidth * factor), (int)(minHeight * factor));
    }

    SDL_GetWindowSizeInPixels(windowHandle, &frameWidth, &frameHeight);
    windowWidth = (int)((float)frameWidth / dpiScale);
    windowHeight = (int)((float)frameHeight / dpiScale);


    // A single thread can use a context at a time
    renderContextLock.lock();

    SDL_GL_MakeCurrent(windowHandle, glContext);

    // Setup Platform/Renderer bindings 
    hasSDL3Init = ImGui_ImplSDL3_InitForOpenGL(windowHandle, glContext);
    if (!hasSDL3Init) {
        SDL_GL_DestroyContext(glContext);
        SDL_DestroyWindow(windowHandle);
        return false;
    }

    // Setup rendering
    hasOpenGL3Init = ImGui_ImplOpenGL3_Init(glsl_version);
    if (!hasOpenGL3Init) {
        ImGui_ImplSDL3_Shutdown();
        hasSDL3Init = false;
        SDL_GL_DestroyContext(glContext);
        SDL_DestroyWindow(windowHandle);
        return false;
    }

    SDL_GL_MakeCurrent(windowHandle, NULL);
    renderContextLock.unlock();

    return true;
}

void SDLViewport::processEvents(int timeout_ms) {
    if (!checkPrimaryThread()) return;
    
    if (positionChangeRequested)
    {
        SDL_SetWindowPosition(windowHandle, positionX, positionY);
        positionChangeRequested = false;
    }

    if (sizeChangeRequested)
    {
        dpiScale = SDL_GetWindowDisplayScale(windowHandle);
        float logical_to_pixel_factor = SDL_GetWindowPixelDensity(windowHandle);
        float factor = dpiScale / logical_to_pixel_factor;
        if (dpiScale == 0. || logical_to_pixel_factor == 0.) {
            dpiScale = 1.f;
            factor = 1.f;
        }
        SDL_SetWindowMaximumSize(windowHandle, (int)(maxWidth * factor), (int)(maxHeight * factor));
        SDL_SetWindowMinimumSize(windowHandle, (int)(minWidth * factor), (int)(minHeight * factor));
        SDL_SetWindowSize(windowHandle, (int)(windowWidth * factor), (int)(windowHeight * factor));
        sizeChangeRequested = false;
    }

    if (windowPropertyChangeRequested)
    {
        SDL_SetWindowResizable(windowHandle, windowResizable);
        SDL_SetWindowBordered(windowHandle, windowDecorated);
        SDL_SetWindowAlwaysOnTop(windowHandle, windowAlwaysOnTop);
        windowPropertyChangeRequested = false;
    }

    if (titleChangeRequested)
    {
        SDL_SetWindowTitle(windowHandle, windowTitle.c_str());
        titleChangeRequested = false;
    }

    if (shouldMinimize)
    {
        SDL_MinimizeWindow(windowHandle);
        shouldMinimize = false;
    }

    if (shouldMaximize)
    {
        SDL_MaximizeWindow(windowHandle);
        shouldMaximize = false;
    }

    if (shouldRestore)
    {
        SDL_RestoreWindow(windowHandle);
        shouldRestore = false;
    }

    if (shouldShow)
    {
        SDL_ShowWindow(windowHandle);
        shouldShow = false;
    }

    if (shouldHide)
    {
        SDL_HideWindow(windowHandle);
        shouldHide = false;
    }

    if (shouldFullscreen)
    {
        SDL_SetWindowFullscreen(windowHandle, !isFullScreen);
        shouldFullscreen = false;
    }

    // Poll and handle events (inputs, window resize, etc.)
    // You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear imgui wants to use your inputs.
    // - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application.
    // - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main application.
    // Generally you may always pass all inputs to dear imgui, and hide them from your application based on those two flags.

    // Activity: input activity. Needs to render to check impact
    // Needs refresh: if the content has likely changed and we must render and present
    SDL_Event event;
    auto start_time = std::chrono::high_resolution_clock::now();
    int remaining_timeout = timeout_ms;

    while (true) {
        bool new_events = SDL_PollEvent(&event);
        if (!new_events) {
            if (remaining_timeout <= 0)
                break;
            if(activityDetected.load() || needsRefresh.load())
                break;
            if (SDL_WaitEventTimeout(&event, remaining_timeout)) {
                // update the timeout for next iteration
                auto current_time = std::chrono::high_resolution_clock::now();
                auto elapsed = current_time - start_time;
                auto elapsed_ms = std::chrono::duration_cast<std::chrono::milliseconds>(elapsed).count();
                remaining_timeout = timeout_ms - elapsed_ms;
            } else
                break; // Timeout occurred
        }

        // Check if event belongs to this window
        SDL_Window* event_window = SDL_GetWindowFromEvent(&event);
        bool isOurWindowEvent = event_window == windowHandle;

        if (isOurWindowEvent || event_window == nullptr) {
            ImGui_ImplSDL3_ProcessEvent(&event);
            switch (event.type) {
                case SDL_EVENT_WINDOW_MOUSE_ENTER:
                case SDL_EVENT_WINDOW_FOCUS_GAINED:
                case SDL_EVENT_WINDOW_FOCUS_LOST:
                case SDL_EVENT_WINDOW_MOVED:
                case SDL_EVENT_MOUSE_MOTION:
                    activityDetected.store(true);
                    break;
                case SDL_EVENT_MOUSE_BUTTON_DOWN:
                case SDL_EVENT_MOUSE_BUTTON_UP:
                case SDL_EVENT_MOUSE_WHEEL:
                case SDL_EVENT_TEXT_EDITING:
                case SDL_EVENT_TEXT_INPUT:
                case SDL_EVENT_KEY_DOWN:
                case SDL_EVENT_KEY_UP:
                    needsRefresh.store(true);
                    break;
                case SDL_EVENT_WINDOW_ENTER_FULLSCREEN:
                    isFullScreen = true;
                    needsRefresh.store(true);
                    break;
                case SDL_EVENT_WINDOW_LEAVE_FULLSCREEN:
                    isFullScreen = false;
                    needsRefresh.store(true);
                    break;
                case SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED:
                case SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED:
                case SDL_EVENT_WINDOW_RESIZED:
                    hasResized = true;
                    needsRefresh.store(true);
                    break;
                case SDL_EVENT_WINDOW_EXPOSED:
                case SDL_EVENT_WINDOW_DESTROYED:
                    needsRefresh.store(true);
                    break;
                case SDL_EVENT_WINDOW_MINIMIZED:
                    activityDetected.store(true);
                    isMinimized = true;
                    break;
                case SDL_EVENT_WINDOW_MAXIMIZED:
                    activityDetected.store(true);
                    isMaximized = true;
                    break;
                case SDL_EVENT_WINDOW_RESTORED:
                    activityDetected.store(true);
                    isMinimized = false;
                    isMaximized = false;
                    break;
                case SDL_EVENT_QUIT:
                case SDL_EVENT_WINDOW_CLOSE_REQUESTED:
                    closeCallback(callbackData);
                    activityDetected.store(true);
                case SDL_EVENT_DROP_BEGIN:
                    dropCallback(callbackData, 0, nullptr);
                    break;
                case SDL_EVENT_DROP_FILE:
                    dropCallback(callbackData, 1, event.drop.data);
                    break;
                case SDL_EVENT_DROP_TEXT:
                    dropCallback(callbackData, 2, event.drop.data);
                    break;
                case SDL_EVENT_DROP_COMPLETE:
                    dropCallback(callbackData, 3, nullptr);
                    break;
                case SDL_EVENT_WINDOW_SHOWN:
                    isVisible = true;
                    activityDetected.store(true);
                    break;
                case SDL_EVENT_WINDOW_HIDDEN:
                    isVisible = false;
                    break;
                default:
                    break;
            }
        } else {
            // Queue event for other windows
            deferredEvents.push_back(event);
        }
    }

    // Move back to the queue events meant for other windows
    if (!deferredEvents.empty()) {
        if ((int)deferredEvents.size() >= 1024)
            fprintf(stderr, "Warning: %d deferred events. Events are not properly flushed. Skipping...\n", (int)deferredEvents.size());
        else
            SDL_PeepEvents(deferredEvents.data(), (int)deferredEvents.size(),
                           SDL_ADDEVENT, SDL_EVENT_FIRST, SDL_EVENT_LAST);
        deferredEvents.clear();
    }
    //if (waitForEvents || glfwGetWindowAttrib(handle, GLFW_ICONIFIED))
    //    while (!activityDetected.load() && !needs_refresh.load())
    //        glfwWaitEventsTimeout(0.001);
    activityDetected.store(false);
}

// Update renderFrame to use member prepare_present
bool SDLViewport::renderFrame(bool can_skip_presenting) {
    renderContextLock.lock();
    // Note: on X11 at least, this MakeCurrent is slow
    // when vsync is ON for some reason...
    // But we cannot avoid the MakeCurrent here,
    // as render_frame might be called from
    // various threads.
    //SDL_GL_MakeCurrent(windowHandle, glContext);
    // -> moved to calling only if needed

    // Start the Dear ImGui frame
    if (Needs_ImGui_ImplOpenGL3_NewFrame()) {
        SDL_GL_MakeCurrent(windowHandle, glContext);
        ImGui_ImplOpenGL3_NewFrame();
        SDL_GL_MakeCurrent(windowHandle, NULL);
    }
    
    renderContextLock.unlock();
    ImGui_ImplSDL3_NewFrame();
    ImGui::NewFrame();

    bool does_needs_refresh = needsRefresh.load();
    needsRefresh.store(false);

    renderCallback(callbackData);

    // Updates during the frame
    // Not all might have been made into rendering
    // thus we don't reset needs_refresh
    does_needs_refresh |= needsRefresh.load();

    if (fastActivityCheck()) {
        does_needs_refresh = true;
        /* Refresh next frame in case of activity.
         * For instance click release might open
         * a menu */
        needsRefresh.store(true);
    }

    static bool prev_needs_refresh = true;

    // shouldSkipPresenting: When we need to redraw in order
    // to improve positioning, and avoid bad frames.
    // We still return in render_frame as the user
    // might want that to handle callbacks right away.
    // The advantage of shouldSkipPresenting though,
    // is that we are not limited by vsync to
    // do the recomputation.
    if (!can_skip_presenting)
        shouldSkipPresenting = false;

    // Maybe we could use some statistics like number of vertices
    can_skip_presenting &= !does_needs_refresh && !prev_needs_refresh;

    // The frame just after an activity might trigger some visual changes
    prev_needs_refresh = does_needs_refresh;
    if (does_needs_refresh)
        activityDetected.store(true);

    if (can_skip_presenting || shouldSkipPresenting) {
        shouldSkipPresenting = false;
        ImGui::EndFrame();
        return false;
    }

    preparePresentFrame(); 
    return true;
}

void SDLViewport::present() {
    renderContextLock.lock();
    SDL_GL_MakeCurrent(windowHandle, glContext);
    SDL_GL_SwapWindow(windowHandle);
    dpiScale = SDL_GetWindowDisplayScale(windowHandle);
    if (dpiScale == 0.f)
        dpiScale = 1.0f;
    SDL_GL_MakeCurrent(windowHandle, NULL);
    renderContextLock.unlock();
}

void SDLViewport::wakeRendering() {
    needsRefresh.store(true);
    SDL_Event user_event;
    user_event.type = SDL_EVENT_USER;
    user_event.user.code = 2;
    user_event.user.data1 = NULL;
    user_event.user.data2 = NULL;
    SDL_PushEvent(&user_event);
}

void SDLViewport::makeUploadContextCurrent() {
    uploadContextLock.lock();
    SDL_GL_MakeCurrent(uploadWindowHandle, uploadGLContext);
}

void SDLViewport::releaseUploadContext() {
    SDL_GL_MakeCurrent(uploadWindowHandle, NULL);
    uploadContextLock.unlock();
}


class SDLGLContext : public GLContext {
public:
    SDLGLContext(SDL_Window* w, SDL_GLContext c) 
        : window(w), context(c) {}
    
    ~SDLGLContext() override {
        if (context) {
            SDL_GL_MakeCurrent(window, context);
            
            // Clean up any GL resources this context created
            // Note: Since contexts are shared, we only clean up resources
            // that were specifically created by this context
            
            SDL_GL_MakeCurrent(window, nullptr);
            SDL_GL_DestroyContext(context);
            context = nullptr;
        }
        
        if (window) {
            SDL_DestroyWindow(window);
            window = nullptr;
        }
    }

    void makeCurrent() override {
        SDL_GL_MakeCurrent(window, context);
    }

    void release() override {
        SDL_GL_MakeCurrent(window, nullptr);
    }

private:
    SDL_Window* window;
    SDL_GLContext context;
};

GLContext* SDLViewport::createSharedContext(int major, int minor) {
    // Lock to ensure the current context remains valid during setup
    uploadContextLock.lock();

    // Make upload context current for sharing
    SDL_GL_MakeCurrent(uploadWindowHandle, uploadGLContext);

    // Create temporary hidden window for the new context
    SDL_Window* tempWindow = SDL_CreateWindow("DearCyGui shared context", 
        640, 480, SDL_WINDOW_OPENGL | SDL_WINDOW_HIDDEN | SDL_WINDOW_UTILITY);
    if (!tempWindow) {
        SDL_GL_MakeCurrent(uploadWindowHandle, NULL);
        uploadContextLock.unlock();
        return nullptr;
    }

    // Set context attributes
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, major);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, minor);
    SDL_GL_SetAttribute(SDL_GL_SHARE_WITH_CURRENT_CONTEXT, 1);
    SDL_GL_SetAttribute(SDL_GL_FRAMEBUFFER_SRGB_CAPABLE, 1);

    // Create the shared context
    SDL_GLContext sharedContext = SDL_GL_CreateContext(tempWindow);
    // Restore original context
    SDL_GL_MakeCurrent(uploadWindowHandle, NULL);
    uploadContextLock.unlock();

    if (!sharedContext) {
        SDL_DestroyWindow(tempWindow);
        return nullptr;
    }

    return new SDLGLContext(tempWindow, sharedContext);
}

size_t SDLViewport::getTextureSize(unsigned width, unsigned height, unsigned num_chans, unsigned type) {
    return width * height * num_chans * (type == 1 ? 1 : 4);
}

void SDLViewport::cleanupTextures() {
    std::lock_guard<std::recursive_mutex> lock(textureMutex);

    // Remove textures that have been marked for deletion
    for(auto it = textureInfoMap.begin(); it != textureInfoMap.end();) {
        TextureInfo& info = it->second;
        if(info.deletion_frame >= 0 && 
           ((currentFrame - info.deletion_frame) >= 10 * CACHE_REUSE_FRAMES
            || (deletedTexturesMemory > CACHE_MEMORY_THRESHOLD))) {

            // Wait for any pending operations
            if (info.write_fence && info.write_fence->sync) {
                glWaitSync(info.write_fence->sync, 0, GL_TIMEOUT_IGNORED);
            }
            if (info.read_fence && info.read_fence->sync) {
                glWaitSync(info.read_fence->sync, 0, GL_TIMEOUT_IGNORED);
            }

            // Clean up fences
            releaseFenceSync(info.write_fence);
            releaseFenceSync(info.read_fence);
            info.write_fence = nullptr;
            info.read_fence = nullptr;
            
            // Clean up resources
            if(info.pbo != 0) {
                glDeleteBuffers(1, &info.pbo);
            }
            glDeleteTextures(1, &it->first);
            
            deletedTexturesMemory -= getTextureSize(info.width, info.height,
                                                  info.num_chans, info.type);
            it = textureInfoMap.erase(it);
        } else {
            ++it;
        }
    }
}

void SDLViewport::waitTextureReadable(TextureInfo& info) {
    if (!info.write_fence || !info.write_fence->sync) return;
    
    glWaitSync(info.write_fence->sync, 0, GL_TIMEOUT_IGNORED);
}

void SDLViewport::waitTextureWritable(TextureInfo& info) {
    if (!info.read_fence || !info.read_fence->sync) return;
    
    glWaitSync(info.read_fence->sync, 0, GL_TIMEOUT_IGNORED);
}

void SDLViewport::markTextureRead(TextureInfo& info) {
    // Clean up any existing read sync before creating a new one
    // Note: This assumes that the previous fence will not raise
    // after the one we are creating now...
    releaseFenceSync(info.read_fence);
    info.read_fence = createFenceSync();
    if (info.read_fence)
        info.read_fence->sync = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0);
}

void SDLViewport::markTextureWritten(TextureInfo& info) {;
    // Clean up old fence before assigning new one
    releaseFenceSync(info.write_fence);
    info.write_fence = createFenceSync();
    if (info.write_fence)
        info.write_fence->sync = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0);
}

void SDLViewport::prepareTexturesForRender(const std::unordered_set<GLuint>& tex_ids) {
    // Called before ImGui rendering to ensure all textures are ready
    // The mutex protection is essential as uploads might be happening
    // from another thread
    std::lock_guard<std::recursive_mutex> lock(textureMutex);
    
    for (GLuint tex_id : tex_ids) {
        auto it = textureInfoMap.find(tex_id);
        if (it != textureInfoMap.end()) {
            // Wait for any pending writes before rendering
            waitTextureReadable(it->second);
            it->second.last_use_frame = currentFrame;
        }
    }
}

void SDLViewport::finishTextureRender(const std::unordered_set<GLuint>& tex_ids) {
    std::lock_guard<std::recursive_mutex> lock(textureMutex);

    // Create new frame fence
    FenceSync* currentFrameFence = nullptr;
    currentFrameFence = createFenceSync();
    if (!currentFrameFence) {
        return;
    }

    // Create single fence for all textures
    currentFrameFence->sync = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0);
    if (!currentFrameFence->sync) {
        // Handle sync creation failure
        delete currentFrameFence;
        return;
    }

    // Assign this fence to all used textures
    for (GLuint tex_id : tex_ids) {
        auto it = textureInfoMap.find(tex_id);
        if (it != textureInfoMap.end()) {
            // Clean up old read fence
            releaseFenceSync(it->second.read_fence);
            
            // Share the current frame fence
            it->second.read_fence = currentFrameFence;
            retainFenceSync(currentFrameFence);
        }
    }
    releaseFenceSync(currentFrameFence);
}

void SDLViewport::beginExternalWrite(GLuint tex_id) {
    std::lock_guard<std::recursive_mutex> lock(textureMutex);
    
    auto it = textureInfoMap.find(tex_id);
    if (it != textureInfoMap.end()) {
        it->second.has_external_writers = true;
        waitTextureWritable(it->second);
    }
}

void SDLViewport::endExternalWrite(GLuint tex_id) {
    std::lock_guard<std::recursive_mutex> lock(textureMutex);
    
    auto it = textureInfoMap.find(tex_id);
    if (it != textureInfoMap.end()) {
        markTextureWritten(it->second);
        it->second.has_external_writers = false;
    }
}

void SDLViewport::beginExternalRead(GLuint tex_id) {
    std::lock_guard<std::recursive_mutex> lock(textureMutex);
    
    auto it = textureInfoMap.find(tex_id);
    if (it != textureInfoMap.end()) {
        it->second.has_external_readers = true;
        waitTextureReadable(it->second);
    }
}

void SDLViewport::endExternalRead(GLuint tex_id) {
    std::lock_guard<std::recursive_mutex> lock(textureMutex);
    
    auto it = textureInfoMap.find(tex_id);
    if (it != textureInfoMap.end()) {
        markTextureRead(it->second);
        it->second.has_external_readers = false;
    }
}

void SDLViewport::waitOnFenceSync(FenceSync* fence) {
    if (fence && fence->sync) {
        glWaitSync(fence->sync, 0, GL_TIMEOUT_IGNORED);
        glFlush(); // Ensure commands are submitted to GPU
    }
}

void SDLViewport::retainFenceSync(FenceSync* fence) {
    if (fence) {
        std::lock_guard<std::recursive_mutex> lock(textureMutex);
        fence->refcount++;
    }
}

void SDLViewport::releaseFenceSync(FenceSync* fence) {
    if (fence) {
        std::lock_guard<std::recursive_mutex> lock(textureMutex);
        fence->refcount--;
        if (fence->refcount <= 0) {
            if (fence->sync) {
                glDeleteSync(fence->sync);
            }
            delete fence;
        }
    }
}

SDLViewport::FenceSync* SDLViewport::createFenceSync() {
    SDLViewport::FenceSync* fence = new SDLViewport::FenceSync();
    fence->refcount = 1;
    return fence;
}

bool SDLViewport::backBufferToTexture(void* texture, unsigned width, unsigned height,
                                      unsigned num_chans, unsigned type)
{
    GLuint tex_id = (GLuint)(size_t)texture;
    if (!tex_id) return false;

    renderContextLock.lock();
    SDL_GL_MakeCurrent(windowHandle, glContext);

    // Create and bind a temporary FBO for writing
    GLuint fbo = 0;
    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, fbo);
    glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex_id, 0);

    bool success = false;
    if (glCheckFramebufferStatus(GL_DRAW_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE)
    {
        // Default framebuffer is 0, used as READ source
        glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
        glBlitFramebuffer(0, 0, width, height, 0, 0, width, height,
                          GL_COLOR_BUFFER_BIT, GL_LINEAR);
        success = true;
    }

    // Clean up
    glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
    glDeleteFramebuffers(1, &fbo);
    SDL_GL_MakeCurrent(windowHandle, NULL);
    renderContextLock.unlock();
    return success;
}

bool SDLViewport::downloadTexture(void* texture,
                                  int x,
                                  int y,
                                  unsigned sub_width,
                                  unsigned sub_height,
                                  unsigned num_chans,
                                  unsigned type,
                                  void* dst,
                                  unsigned dst_stride)
{
    GLuint tex_id = (GLuint)(size_t)texture;
    if (!tex_id) return false;

    // Prevent writing outside bounds
    if (dst_stride < sub_width * num_chans * ((type == 1) ? 1 : 4)) {
        return false;
    }

    // Check texture data matches
    std::lock_guard<std::recursive_mutex> lock(textureMutex);
    auto it = textureInfoMap.find(tex_id);
    if (it == textureInfoMap.end()) {
        return false;
    }

    // Wait for any pending writes before reading
    waitTextureReadable(it->second);

    // Bind texture to FBO
    glBindTexture(GL_TEXTURE_2D, tex_id);

    // Determine format and type
    GLenum gl_format = GL_RED;
    switch (num_chans) {
        case 2: gl_format = GL_RG; break;
        case 3: gl_format = GL_RGB; break;
        case 4: gl_format = GL_RGBA; break;
    }

    GLenum gl_type = (type == 1) ? GL_UNSIGNED_BYTE : GL_FLOAT;

    GLuint fbo = 0;
    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex_id, 0);

    bool success = false;
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE) {
        // Align packing
        glPixelStorei(GL_PACK_ALIGNMENT, 1);

        // Create an ephemeral pixel pack buffer
        GLuint pbo = 0;
        glGenBuffers(1, &pbo);
        glBindBuffer(GL_PIXEL_PACK_BUFFER, pbo);
        glBufferData(GL_PIXEL_PACK_BUFFER, sub_height * dst_stride, nullptr, GL_STREAM_READ);

        glReadPixels(x, y, sub_width, sub_height, gl_format, gl_type, 0);
        if (GLenum err = glGetError() != GL_NO_ERROR) {
            fprintf(stderr, "glReadPixels error: %d\n", err);
        }
        markTextureRead(it->second);
        glFlush();

        // Map buffer to CPU memory
        void* mapped = glMapBufferRange(GL_PIXEL_PACK_BUFFER, 0, sub_height * dst_stride, GL_MAP_READ_BIT);
        if (mapped)
        {
            // Copy rows from mapped buffer to dst
            for (unsigned row = 0; row < sub_height; row++)
            {
                memcpy((unsigned char*)dst + row * dst_stride, (unsigned char*)mapped + row * dst_stride, sub_width * num_chans * ((type == 1) ? 1 : 4));
            }
            glUnmapBuffer(GL_PIXEL_PACK_BUFFER);
        } else {
            if (GLenum err = glGetError() != GL_NO_ERROR) {
                fprintf(stderr, "glMapBufferRange error: %d\n", err);
            }
        }

        glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
        glDeleteBuffers(1, &pbo);

        success = true;
    } else {
        if (GLenum err = glGetError() != GL_NO_ERROR) {
            fprintf(stderr, "Framebuffer status error: %d\n", err);
        }
    }

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glDeleteFramebuffers(1, &fbo);
    return success;
}

bool SDLViewport::checkPrimaryThread() {
    return SDL_GetCurrentThreadID() == sdlMainThreadId;
}

bool SDLViewport::addWindowIcon(void* data, int width, int height, 
                              int rowStride, int colStride, int chanStride) {
    if (!data || width <= 0 || height <= 0) {
        return false;
    }
    
    if (windowHandle != NULL) {
        // Window already initialized, can't add icons
        return false;
    }
    
    // Create an SDL surface from the RGBA data
    SDL_Surface* newSurface = SDL_CreateSurface(width, height, SDL_PIXELFORMAT_RGBA32);
    if (!newSurface) {
        return false;
    }
    
    // Lock the surface for pixel manipulation
    if (SDL_LockSurface(newSurface) != 0) {
        SDL_DestroySurface(newSurface);
        return false;
    }
    
    // Copy the pixel data to the surface
    uint8_t* srcRow = static_cast<uint8_t*>(data);
    uint8_t* dstRow = static_cast<uint8_t*>(newSurface->pixels);
    
    for (int y = 0; y < height; y++) {
        uint8_t* srcPixel = srcRow;
        uint8_t* dstPixel = dstRow;
        
        for (int x = 0; x < width; x++) {
            // Copy RGBA channels
            for (int c = 0; c < 4; c++) {
                dstPixel[c] = srcPixel[c * chanStride];
            }
            
            // Move to next pixel
            srcPixel += colStride;
            dstPixel += 4; // 4 bytes per pixel in RGBA32
        }
        
        // Move to next row
        srcRow += rowStride;
        dstRow += newSurface->pitch;
    }
    
    // Unlock the surface
    SDL_UnlockSurface(newSurface);
    
    // Check if this is the first icon or an additional one
    if (iconSurface == nullptr) {
        // First icon
        iconSurface = newSurface;
    } else {
        // Add as alternate icon
        if (SDL_AddSurfaceAlternateImage(iconSurface, newSurface) != 0) {
            // Failed to add alternate image
            SDL_DestroySurface(newSurface);
            return false;
        }
        // SDL_AddSurfaceAlternateImage takes ownership of newSurface
    }
    
    return true;
}
