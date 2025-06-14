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

from libc.stdint cimport uint8_t, uintptr_t, int32_t
from libc.string cimport memset

from cython.view cimport array as cython_array
from cython.operator cimport dereference
cimport cpython

# This file is the only one that is linked to the C++ code
# Thus it is the only one allowed to make calls to it

from .backends.backend cimport platformViewport
from .core cimport baseItem, lock_gil_friendly
from .c_types cimport unique_lock, DCGMutex
from .types cimport parse_texture

from weakref import WeakKeyDictionary, WeakValueDictionary


cdef class Texture(baseItem):
    """
    Represents a texture that can be used in the UI or drawings.
    
    A texture holds image data that can be displayed in the UI or manipulated.
    Textures can be created from various array-like data sources and can be
    dynamically updated. They support different color formats, filtering modes,
    and can be read from or written to.
    """

    def __init__(self, context, *args, **kwargs):
        baseItem.__init__(self, context, **kwargs)
        if len(args) == 1:
            self.set_value(args[0])
        elif len(args) != 0:
            raise ValueError("Invalid arguments passed to Texture. Expected content")

    def __cinit__(self):
        self._hint_dynamic = False
        self._dynamic = False
        self._no_realloc = False
        self._readonly = False
        self.allocated_texture = NULL
        self.width = 0
        self.height = 0
        self.num_chans = 0
        self._buffer_type = 0
        self._filtering_mode = 0
        self._repeat_mode = 0

    def __dealloc__(self):
        cdef unique_lock[DCGMutex] imgui_m
        # Note: textures might be referenced during imgui rendering.
        # Thus we should wait there is no rendering to free a texture.
        # However, doing so would stall python's garbage collection,
        # and the gil. OpenGL is fine with the texture being deleted
        # while it is still in use (there will just be an artefact),
        # plus we delay texture deletion for a few frames,
        # so it should be fine.
        if self.allocated_texture != NULL and self.context is not None \
           and self.context.viewport is not None:
            (<platformViewport*>self.context.viewport._platform).makeUploadContextCurrent()
            try:
                (<platformViewport*>self.context.viewport._platform).freeTexture(self.allocated_texture)
            finally:
                (<platformViewport*>self.context.viewport._platform).releaseUploadContext()

    @property
    def hint_dynamic(self):
        """
        Hint that the texture will be updated frequently.
        
        This property should be set before calling set_value or allocate to
        optimize texture memory placement for frequent updates.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._hint_dynamic
    @hint_dynamic.setter
    def hint_dynamic(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self.allocated_texture != NULL and self._hint_dynamic != value:
            raise PermissionError("hint_dynamic cannot be changed after texture allocation")
        self._hint_dynamic = value

    @property
    def antialiased(self):
        """
        Whether this texture uses mipmapping with anisotropic filtering for antialiasing.
        
        When True, the texture will use mipmaps and anisotropic filtering
        to create smoother patterns when viewed at different angles and scales.
        This is particularly useful for line patterns to prevent aliasing.

        This setting is not compatible with nearest_neighbor_upsampling.

        This should be set before uploading texture data.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if self._filtering_mode == 3 else False
    @antialiased.setter
    def antialiased(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self.allocated_texture != NULL:
            if (((self._filtering_mode == 3) and not value) or ((self._filtering_mode == 0) and value)):
                raise PermissionError("antialiased cannot be changed after texture allocation")
            return
        if value:
            self._filtering_mode = 3
        elif self._filtering_mode == 3:
            self._filtering_mode = 0  # Reset to default filtering

    @property
    def nearest_neighbor_upsampling(self):
        """
        Whether to use nearest neighbor interpolation when upscaling.
        
        When True, nearest neighbor interpolation is used instead of bilinear
        interpolation when upscaling the texture.

        This should be set before calling `set_value` or `allocate`.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if self._filtering_mode == 1 else 0
    @nearest_neighbor_upsampling.setter
    def nearest_neighbor_upsampling(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self.allocated_texture != NULL:
            if (((self._filtering_mode == 0) and value) or ((self._filtering_mode == 1) and not value)):
                raise PermissionError("nearest_neighbor_upsampling cannot be changed after texture allocation")
            return
        self._filtering_mode = 1 if value else 0

    @property
    def wrap_x(self):
        """
        Whether to repeat the texture on x.

        When set, reading outside the texture on x will
        wrap to inside the texture (GL_REPEAT), instead
        of the default clamping to the edge.

        This should be set before calling `set_value` or `allocate`.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if self._repeat_mode & 1 else False
    @wrap_x.setter
    def wrap_x(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self.allocated_texture != NULL and \
           ((self._repeat_mode & 1) != 0) != value:
            raise PermissionError("wrap_x cannot be changed after texture allocation")
        self._repeat_mode &= ~1
        if value:
            self._repeat_mode |= 1

    @property
    def wrap_y(self):
        """
        Whether to repeat the texture on y.

        When set, reading outside the texture on y will
        wrap to inside the texture (GL_REPEAT), instead
        of the default clamping to the edge.

        This should be set before calling `set_value` or `allocate`.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if self._repeat_mode & 2 else False
    @wrap_y.setter
    def wrap_y(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self.allocated_texture != NULL and \
           ((self._repeat_mode & 2) != 0) != value:
            raise PermissionError("wrap_y cannot be changed after texture allocation")
        self._repeat_mode &= ~2
        if value:
            self._repeat_mode |= 2
        
    @property
    def width(self):
        """
        Width of the current texture content in pixels.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.width
        
    @property
    def height(self):
        """
        Height of the current texture content in pixels.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.height
        
    @property
    def num_chans(self):
        """
        Number of channels in the current texture content.
        
        This value is typically 1 (grayscale), 3 (RGB), or 4 (RGBA).
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.num_chans

    @property
    def texture_id(self):
        """
        Internal texture ID used by the rendering backend.
        
        This ID may change if set_value is called and is released when the 
        Texture is freed. It can be used for advanced integration with external
        rendering systems.
        """
        return <uintptr_t>self.allocated_texture

    def allocate(self, *,
                 int32_t width,
                 int32_t height,
                 int32_t num_chans,
                 bint uint8 = False,
                 bint float32 = False,
                 bint no_realloc = True):
        """
        Allocate the buffer backing for the texture.
        
        This function is primarily useful when working with external rendering 
        tools (OpenGL, etc.) and you need a texture handle without setting 
        initial content. For normal texture usage, set_value will handle 
        allocation automatically.
        
        Parameters:
        - width: Width of the target texture in pixels
        - height: Height of the target texture in pixels
        - num_chans: Number of channels (1, 2, 3, or 4)
        - uint8: Whether the texture format is unsigned bytes (default: False)
        - float32: Whether the texture format is float32 (default: False)
        - no_realloc: Whether to prevent future reallocations (default: True)
        
        Either uint8 or float32 must be set to True.
        """
        if self.allocated_texture != NULL and self._no_realloc:
            raise ValueError("Texture backing cannot be reallocated")
        
        # Validate dimensions
        if width <= 0:
            raise ValueError("Width must be positive")
        if height <= 0:
            raise ValueError("Height must be positive")
        if num_chans < 1 or num_chans > 4:
            raise ValueError("Number of channels must be between 1 and 4")

        cdef unsigned buffer_type
        if uint8:
            buffer_type = 1
        elif float32:
            buffer_type = 0
        else:
            raise ValueError("Invalid texture format. Float32 or uint8 must be set")

        cdef bint success
        with nogil:
            (<platformViewport*>self.context.viewport._platform).makeUploadContextCurrent()
            self.mutex.lock()
            try:
                self.allocated_texture = \
                    (<platformViewport*>self.context.viewport._platform).allocateTexture(width,
                                                                        height,
                                                                        num_chans,
                                                                        self._dynamic,
                                                                        buffer_type,
                                                                        self._filtering_mode,
                                                                        self._repeat_mode)
            finally:
                (<platformViewport*>self.context.viewport._platform).releaseUploadContext()
                success = self.allocated_texture != NULL
                if success:
                    self.width = width
                    self.height = height
                    self.num_chans = num_chans
                    self._buffer_type = buffer_type
                    self._no_realloc = no_realloc
                self.mutex.unlock()
        if not(success):
            raise MemoryError("Failed to allocate target texture")


    def set_value(self, src):
        """
        Set the texture data from an array.
        
        The data is uploaded immediately during this call. After uploading,
        the source data can be safely discarded. If the texture already has
        content, the previous allocation will be reused if compatible.
        
        Supported formats:
        - Data type: uint8 (0-255) or float32 (0.0-1.0)
          (other types will be converted to float32)
        - Channels: 1 (R), 2 (RG), 3 (RGB), or 4 (RGBA)
          
        Note that for single-channel textures, R is duplicated to G and B
        during rendering, displaying as gray rather than red.
        """
        if cpython.PyObject_CheckBuffer(src):
            value = src
        else:
            value = parse_texture(src)
        self.set_content(value)

    cdef void set_content(self, content): # TODO: deadlock when held by external lock
        # The write mutex is to ensure order of processing of set_content
        # as we might release the item mutex to wait for imgui to render
        cdef unique_lock[DCGMutex] m
        cdef unique_lock[DCGMutex] m2
        lock_gil_friendly(m, self._write_mutex)
        lock_gil_friendly(m2, self.mutex)
        if self._readonly: # set for fonts
            raise ValueError("Target texture is read-only")
        cdef cpython.Py_buffer buf_info
        if cpython.PyObject_GetBuffer(content, &buf_info, cpython.PyBUF_RECORDS_RO) < 0:
            raise TypeError("Failed to retrieve buffer information")
        cdef int32_t ndim = buf_info.ndim
        if ndim > 3 or ndim == 0:
            cpython.PyBuffer_Release(&buf_info)
            raise ValueError("Invalid number of texture dimensions")
        cdef int32_t height = 1
        cdef int32_t width = 1
        cdef int32_t num_chans = 1
        cdef int32_t stride = 1
        cdef int32_t col_stride = buf_info.itemsize
        cdef int32_t chan_stride = buf_info.itemsize

        if ndim >= 1:
            height = buf_info.shape[0]
            stride = buf_info.strides[0]
        if ndim >= 2:
            width = buf_info.shape[1]
            col_stride = buf_info.strides[1]
        if ndim >= 3:
            num_chans = buf_info.shape[2]
            chan_stride = buf_info.strides[2]
        if width * height * num_chans == 0:
            cpython.PyBuffer_Release(&buf_info)
            raise ValueError("Cannot set empty texture")
        if buf_info.format[0] != b'B' and buf_info.format[0] != b'f':
            cpython.PyBuffer_Release(&buf_info)
            raise ValueError("Invalid texture format. Must be uint8[0-255] or float32[0-1]")

        # rows must be contiguous
        cdef cython_array copy_array
        cdef float[:,:,::1] copy_array_float
        cdef unsigned char[:,:,::1] copy_array_uint8
        cdef int32_t row, col, chan
        if col_stride != (num_chans * buf_info.itemsize) or \
           chan_stride != buf_info.itemsize:
            copy_array = cython_array(shape=(height, width, num_chans), itemsize=buf_info.itemsize, format=buf_info.format, mode='c', allocate_buffer=True)
            if buf_info.itemsize == 1:
                copy_array_uint8 = copy_array
                for row in range(height):
                    for col in range(width):
                        for chan in range(num_chans):
                            copy_array_uint8[row, col, chan] = (<unsigned char*>buf_info.buf)[row * stride + col * col_stride + chan * chan_stride]
                stride = width * num_chans
            else:
                copy_array_float = copy_array
                for row in range(height):
                    for col in range(width):
                        for chan in range(num_chans):
                            copy_array_float[row, col, chan] = \
                                dereference(<float*>&((<unsigned char*>buf_info.buf)[row * stride + col * col_stride + chan * chan_stride]))
                stride = width * num_chans * 4

        cdef bint reuse = self.allocated_texture != NULL
        cdef bint success
        cdef unsigned buffer_type = 1 if buf_info.itemsize == 1 else 0
        reuse = reuse and not(self.width != width or self.height != height or self.num_chans != num_chans or self._buffer_type != buffer_type)
        if not(reuse) and self._no_realloc:
            cpython.PyBuffer_Release(&buf_info)
            raise ValueError("Texture cannot be reallocated and upload data is not of the same size/type as the texture")

        cdef bint holds_upload_mutex = False
        cdef void* previous_texture = NULL

        try:
            with nogil:
                if self.allocated_texture != NULL and not(reuse):
                    # We must wait there is no rendering since the current rendering might reference the texture
                    # Release current lock to not block rendering
                    # Wait we can prevent rendering
                    if not(self.context.imgui_mutex.try_lock()):
                        m2.unlock()
                        # rendering can take some time, fortunately we avoid holding the gil
                        self.context.imgui_mutex.lock()
                        m2.lock()
                        # Note: we maintained a lock on _write_mutex, thus the texture hasn't changed.
                    (<platformViewport*>self.context.viewport._platform).makeUploadContextCurrent()
                    holds_upload_mutex = True
                    previous_texture = self.allocated_texture
                    self.allocated_texture = NULL
                    (<platformViewport*>self.context.viewport._platform).freeTexture(previous_texture)
                    self.context.imgui_mutex.unlock()
                else:
                    m2.unlock()
                    (<platformViewport*>self.context.viewport._platform).makeUploadContextCurrent()
                    holds_upload_mutex = True
                    m2.lock()

                # Note we don't need the imgui mutex to create or upload textures.
                # In the case of GL, as only one thread can access GL data at a single
                # time, MakeUploadContextCurrent and ReleaseUploadContext enable
                # to upload/create textures from various threads. They hold a mutex.
                # That mutex is held in the relevant parts of frame rendering.

                self.width = width
                self.height = height
                self.num_chans = num_chans
                self._buffer_type = buffer_type

                if not(reuse):
                    self._dynamic = self._hint_dynamic
                    self.allocated_texture = \
                        (<platformViewport*>self.context.viewport._platform).allocateTexture(width,
                                                                        height,
                                                                        num_chans,
                                                                        self._dynamic,
                                                                        buffer_type,
                                                                        self._filtering_mode,
                                                                        self._repeat_mode)

                success = self.allocated_texture != NULL
                if success:
                    if self._dynamic:
                        success = \
                            (<platformViewport*>self.context.viewport._platform).updateDynamicTexture(
                                                        self.allocated_texture,
                                                        width,
                                                        height,
                                                        num_chans,
                                                        buffer_type,
                                                        buf_info.buf,
                                                        stride)
                    else:
                        success = (<platformViewport*>self.context.viewport._platform).updateStaticTexture(
                                                        self.allocated_texture,
                                                        width,
                                                        height,
                                                        num_chans,
                                                        buffer_type,
                                                        buf_info.buf,
                                                        stride)
                (<platformViewport*>self.context.viewport._platform).releaseUploadContext()
                holds_upload_mutex = False
                m.unlock()
                m2.unlock() # Release before we get gil again
        finally:
            if holds_upload_mutex:
                # If we held the upload mutex, we must release it
                (<platformViewport*>self.context.viewport._platform).releaseUploadContext()
            cpython.PyBuffer_Release(&buf_info)
        if not(success):
            raise MemoryError("Failed to upload target texture")

    def read(self, int32_t x0=0, int32_t y0=0, int32_t crop_width=0, int32_t crop_height=0):
        """
        Read the texture content.
        
        Retrieves the current texture data, with optional cropping. The texture
        must be allocated and have content before calling this method.
        
        Parameters:
        - x0: X coordinate of the top-left corner of the crop (default: 0)
        - y0: Y coordinate of the top-left corner of the crop (default: 0)
        - crop_width: Width of the crop, 0 for full width (default: 0)
        - crop_height: Height of the crop, 0 for full height (default: 0)
        
        Returns:
        - A Cython array containing the texture data
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        
        # Check if texture exists
        if self.allocated_texture == NULL:
            raise ValueError("Cannot read from unallocated texture")
        
        cdef int32_t width = self.width
        cdef int32_t height = self.height
        cdef int32_t num_chans = self.num_chans
        cdef int32_t buffer_type = self._buffer_type
        cdef int32_t crop_width_ = width if crop_width == 0 else crop_width
        cdef int32_t crop_height_ = height if crop_height == 0 else crop_height
        
        # Validate crop coordinates
        if x0 < 0:
            raise ValueError(f"Negative x coordinate ({x0})")
        if y0 < 0:
            raise ValueError(f"Negative y coordinate ({y0})")
        if crop_width_ <= 0:
            raise ValueError(f"Invalid crop width ({crop_width_})")
        if crop_height_ <= 0:
            raise ValueError(f"Invalid crop height ({crop_height_})")
        if x0 + crop_width_ > width:
            raise ValueError(f"Crop extends beyond texture width ({x0 + crop_width_} > {width})")
        if y0 + crop_height_ > height:
            raise ValueError(f"Crop extends beyond texture height ({y0 + crop_height_} > {height})")
        
        cdef cython_array array
        cdef void *data
        cdef bint success

        # allocate array
        cdef uint8_t[:,:,:] array_view_uint8
        cdef float[:,:,:] array_view_float
        if buffer_type == 1:
            array = cython_array(shape=(crop_height_, crop_width_, num_chans), itemsize=1, format='B', mode='c', allocate_buffer=True)
            array_view_uint8 = array
            data = <void*>&array_view_uint8[0, 0, 0]
        else:
            array = cython_array(shape=(crop_height_, crop_width_, num_chans), itemsize=4, format='f', mode='c', allocate_buffer=True)
            array_view_float = array
            data = <void*>&array_view_float[0, 0, 0]

        cdef int32_t stride = crop_width_ * num_chans * (1 if buffer_type == 1 else 4)
        with nogil:
            m.unlock()
            (<platformViewport*>self.context.viewport._platform).makeUploadContextCurrent()
            m.lock()
            try:
                success = \
                    (<platformViewport*>self.context.viewport._platform).downloadTexture(self.allocated_texture,
                                    x0, y0, crop_width_, crop_height_, num_chans,
                                    self._buffer_type, data, stride)
            finally:
                (<platformViewport*>self.context.viewport._platform).releaseUploadContext()
        if not(success):
            raise ValueError("Failed to read the texture")
        return array

    cdef void c_gl_begin_read(self) noexcept nogil:
        """
        Same as gl_begin_read, but for cython item draw subclassing
        """
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        (<platformViewport*>self.context.viewport._platform).beginExternalRead(<uintptr_t>self.allocated_texture)

    def gl_begin_read(self):
        """
        Lock a texture for external GL context read operations.
        
        This method must be called before reading from the texture in an
        external GL context. The target GL context MUST be current when calling
        this method. A GPU fence is created to ensure any previous DearCyGui
        rendering or uploads finish before the texture is read.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.c_gl_begin_read()

    cdef void c_gl_end_read(self) noexcept nogil:
        """
        Same as gl_end_read, but for cython item draw subclassing
        """
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        (<platformViewport*>self.context.viewport._platform).endExternalRead(<uintptr_t>self.allocated_texture)

    def gl_end_read(self):
        """
        Unlock a texture after an external GL context read operation.
        
        This method must be called after reading from the texture in an
        external GL context. The target GL context MUST be current when calling
        this method. A GPU fence is created to ensure DearCyGui won't write to
        the texture until the read operation has completed.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.c_gl_end_read()

    cdef void c_gl_begin_write(self) noexcept nogil:
        """
        Same as gl_begin_write, but for cython item draw subclassing
        """
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        (<platformViewport*>self.context.viewport._platform).beginExternalWrite(<uintptr_t>self.allocated_texture)

    def gl_begin_write(self):
        """
        Lock a texture for external GL context write operations.
        
        This method must be called before writing to the texture in an
        external GL context. The target GL context MUST be current when calling
        this method. A GPU fence is created to ensure any previous DearCyGui
        rendering reading from the texture finishes before writing.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.c_gl_begin_write()

    cdef void c_gl_end_write(self) noexcept nogil:
        """
        Same as gl_end_write, but for cython item draw subclassing
        """
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        (<platformViewport*>self.context.viewport._platform).endExternalWrite(<uintptr_t>self.allocated_texture)

    def gl_end_write(self):
        """
        Unlock a texture after an external GL context write operation.
        
        This method must be called after writing to the texture in an
        external GL context. The target GL context MUST be current when calling
        this method. A GPU fence is created to ensure DearCyGui won't read from
        the texture until the write operation has completed.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.c_gl_end_write()

# Global pattern cache: context -> {pattern_key -> weak_pattern}
_pattern_cache = WeakKeyDictionary()

# Function to create a hashable key from pattern parameters
cdef tuple _create_pattern_key(str pattern_type, dict params):
    # Convert params to sorted tuple of (key, value) pairs for hashability
    param_items = sorted(params.items())
    return (pattern_type,) + tuple(param_items)

# Function to check if a pattern exists in the cache
cdef object _get_pattern_from_cache(Context context, str pattern_type, dict params):
    # Initialize cache for this context if needed
    if context not in _pattern_cache:
        _pattern_cache[context] = WeakValueDictionary()
        return None
    
    # Create a hashable key from the parameters
    key = _create_pattern_key(pattern_type, params)
    
    # Try to get from cache
    cache = _pattern_cache[context]
    if key in cache:
        pattern = cache[key]
        if pattern is not None:
            return pattern
    
    return None

# Function to store a pattern in the cache
cdef object _store_pattern_in_cache(Context context, str pattern_type, dict params, pattern):
    # Initialize cache for this context if needed
    if context not in _pattern_cache:
        _pattern_cache[context] = WeakValueDictionary()
    
    # Create a hashable key from the parameters
    key = _create_pattern_key(pattern_type, params)
    
    # Store the pattern
    cache = _pattern_cache[context]
    cache[key] = pattern


cdef class Pattern(baseItem):
    """
    Defines a repeating pattern for outlining shapes.
    
    A pattern consists of a texture that gets sampled along the outline path,
    with configurable sampling behavior. The texture is applied in GL_REPEAT mode.
    
    The x-coordinate of the texture is sampled along the path of the outline,
    while the y-coordinate is sampled across the width of the outline (from
    interior to exterior).
    """

    def __cinit__(self):
        self._texture = None
        self._x_mode = 0  # default to points mode
        self._scale_factor = 1.0
        self._screen_space = False

    @property
    def texture(self):
        """
        Texture to use for the pattern.
        
        This texture will be sampled along the outline of the shape.
        The texture should have wrap_x set to True to enable repetition.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._texture

    @texture.setter
    def texture(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if not(isinstance(value, Texture)) and value is not None:
            raise TypeError("texture must be a Texture object or None")
        self._texture = value

    @property
    def x_mode(self):
        """
        How to sample the x-coordinate of the texture.
        
        'points': x goes from 0 to 1 between each point in the outline
        'length': x increases linearly with the length of the path in pixels
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return "points" if self._x_mode == 0 else "length"
    @x_mode.setter
    def x_mode(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value == "points":
            self._x_mode = 0
        elif value == "length":
            self._x_mode = 1
        else:
            raise ValueError("x_mode must be 'points' or 'length'")

    @property
    def scale_factor(self):
        """
        Scaling factor for the pattern repetition.
        
        For 'points' mode: controls how many repetitions per segment
        For 'length' mode: controls how many repetitions per pixel

        Note scale_factor must be positive, but can be float.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._scale_factor
    @scale_factor.setter
    def scale_factor(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value <= 0:
            raise ValueError("scale_factor must be positive")
        self._scale_factor = value

    @property
    def screen_space(self):
        """
        Whether the 'length' mode is in screen space (pixels) or coordinate space.
        
        When True, the number of pattern repetitions depends on the zoom level,
           but the visual effect of the pattern is invariant of zoom.
        When False, the number of pattern repetitions is invariant of zoom.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._screen_space
    @screen_space.setter
    def screen_space(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._screen_space = value

    # Base factory method
    @staticmethod
    def from_array(context: Context, array, int32_t upscale_factor=1, bint antialiased=True, **kwargs):
        """
        Creates a pattern from a provided array with optional upscaling.
        
        The upscaling maintains the sharp edges of the original pattern, while the
        mipmapping system handles antialiasing when the pattern is displayed at
        different scales.
        
        Args:
            context: The DearCyGui context
            array: Source array defining the pattern (1D or 2D with 4th dimension as RGBA)
            upscale_factor: Integer factor to upscale the pattern (must be >= 1)
            antialiased: Whether to enable mipmapping for antialiasing
            **kwargs: Additional arguments passed to Pattern constructor
        
        Returns:
            Pattern: A pattern using the provided array data
        """
        if context is None:
            raise ValueError("Context cannot be None")
        
        if array is None:
            raise ValueError("Array source cannot be None")
        
        if upscale_factor < 1:
            raise ValueError("upscale_factor must be at least 1")
        
        cdef Pattern pattern = Pattern(context)
        cdef cpython.Py_buffer buf_info
        cdef bint buffer_acquired = False
        cdef cython_array upscaled_arr
        cdef Texture texture
        cdef int32_t ndim
        cdef int32_t src_height = 1
        cdef int32_t src_width = 1
        cdef int32_t num_chans = 1
        cdef int32_t stride = 1
        cdef int32_t col_stride
        cdef int32_t chan_stride
        cdef int32_t dst_width
        cdef int32_t dst_height
        cdef uint8_t[:,:,:] upscaled_view
        cdef int32_t dst_x, dst_y, chan
        cdef int32_t src_x, src_y
        cdef float val_float
        cdef uint8_t val_uint8
        cdef uint8_t* src_ptr
        cdef unsigned char* src_byte_ptr
        cdef bint is_uint8
        cdef bint is_float32
        
        pattern._x_mode = 1  # "length" mode
        
        try:
            if cpython.PyObject_GetBuffer(array, &buf_info, cpython.PyBUF_RECORDS_RO) < 0:
                raise TypeError("Failed to retrieve buffer information")
            buffer_acquired = True
            
            ndim = buf_info.ndim
            if ndim > 3 or ndim == 0:
                raise ValueError("Invalid number of dimensions")
            
            col_stride = buf_info.itemsize
            chan_stride = buf_info.itemsize
            
            if ndim >= 1:
                src_height = buf_info.shape[0]
                stride = buf_info.strides[0]
            if ndim >= 2:
                src_width = buf_info.shape[1]
                col_stride = buf_info.strides[1]
            if ndim >= 3:
                num_chans = buf_info.shape[2]
                chan_stride = buf_info.strides[2]
            if num_chans > 4:
                raise ValueError("Invalid number of channels, must be 1, 2, 3, or 4")
            
            # Calculate dimensions of upscaled texture
            dst_width = src_width * upscale_factor
            dst_height = src_height * upscale_factor
            
            # Create destination array with appropriate dimensions
            upscaled_arr = cython_array(
                shape=(dst_height, dst_width, 4), 
                itemsize=1, 
                format='B', 
                mode='c', 
                allocate_buffer=True
            )
            
            upscaled_view = upscaled_arr
            is_uint8 = buf_info.format[0] == b'B'
            is_float32 = buf_info.format[0] == b'f'
            
            if not (is_uint8 or is_float32):
                raise ValueError("Unsupported buffer format, expected uint8 or float32")
            
            # Perform nearest-neighbor upscaling
            for dst_y in range(dst_height):
                src_y = dst_y // upscale_factor
                for dst_x in range(dst_width):
                    src_x = dst_x // upscale_factor
                    
                    # Initialize to transparent black
                    upscaled_view[dst_y, dst_x, 0] = 0
                    upscaled_view[dst_y, dst_x, 1] = 0
                    upscaled_view[dst_y, dst_x, 2] = 0
                    upscaled_view[dst_y, dst_x, 3] = 0
                    
                    # 1D array case (single row)
                    if ndim == 1 and src_y == 0:
                        if is_uint8:
                            src_ptr = <uint8_t*>buf_info.buf + src_x * stride
                            upscaled_view[dst_y, dst_x, 0] = src_ptr[0]
                            upscaled_view[dst_y, dst_x, 1] = src_ptr[0]
                            upscaled_view[dst_y, dst_x, 2] = src_ptr[0]
                            upscaled_view[dst_y, dst_x, 3] = 255
                        elif is_float32:
                            src_byte_ptr = <unsigned char*>buf_info.buf + src_x * stride
                            val_float = dereference(<float*>src_byte_ptr)
                            val_uint8 = <uint8_t>max(0, min(255, int(val_float * 255)))
                            upscaled_view[dst_y, dst_x, 0] = val_uint8
                            upscaled_view[dst_y, dst_x, 1] = val_uint8
                            upscaled_view[dst_y, dst_x, 2] = val_uint8
                            upscaled_view[dst_y, dst_x, 3] = 255
                    
                    # 2D or 3D array case
                    elif ndim >= 2:
                        if is_uint8:
                            src_ptr = <uint8_t*>buf_info.buf + src_y * stride + src_x * col_stride
                            
                            # Handle different channel counts
                            if num_chans == 1:  # Grayscale
                                upscaled_view[dst_y, dst_x, 0] = src_ptr[0]
                                upscaled_view[dst_y, dst_x, 1] = src_ptr[0]
                                upscaled_view[dst_y, dst_x, 2] = src_ptr[0]
                                upscaled_view[dst_y, dst_x, 3] = 255
                            elif num_chans == 2:  # Grayscale + Alpha
                                upscaled_view[dst_y, dst_x, 0] = src_ptr[0]
                                upscaled_view[dst_y, dst_x, 1] = src_ptr[0]
                                upscaled_view[dst_y, dst_x, 2] = src_ptr[0]
                                upscaled_view[dst_y, dst_x, 3] = src_ptr[chan_stride]
                            elif num_chans == 3:  # RGB
                                upscaled_view[dst_y, dst_x, 0] = src_ptr[0]
                                upscaled_view[dst_y, dst_x, 1] = src_ptr[chan_stride]
                                upscaled_view[dst_y, dst_x, 2] = src_ptr[2 * chan_stride]
                                upscaled_view[dst_y, dst_x, 3] = 255
                            elif num_chans >= 4:  # RGBA
                                upscaled_view[dst_y, dst_x, 0] = src_ptr[0]
                                upscaled_view[dst_y, dst_x, 1] = src_ptr[chan_stride]
                                upscaled_view[dst_y, dst_x, 2] = src_ptr[2 * chan_stride]
                                upscaled_view[dst_y, dst_x, 3] = src_ptr[3 * chan_stride]
                        
                        elif is_float32:
                            src_byte_ptr = <unsigned char*>buf_info.buf + src_y * stride + src_x * col_stride
                            
                            # Handle different channel counts
                            if num_chans == 1:  # Grayscale
                                val_float = dereference(<float*>src_byte_ptr)
                                val_uint8 = <uint8_t>max(0, min(255, int(val_float * 255)))
                                upscaled_view[dst_y, dst_x, 0] = val_uint8
                                upscaled_view[dst_y, dst_x, 1] = val_uint8
                                upscaled_view[dst_y, dst_x, 2] = val_uint8
                                upscaled_view[dst_y, dst_x, 3] = 255
                            elif num_chans == 2:  # Grayscale + Alpha
                                val_float = dereference(<float*>src_byte_ptr)
                                val_uint8 = <uint8_t>max(0, min(255, int(val_float * 255)))
                                upscaled_view[dst_y, dst_x, 0] = val_uint8
                                upscaled_view[dst_y, dst_x, 1] = val_uint8
                                upscaled_view[dst_y, dst_x, 2] = val_uint8
                                
                                val_float = dereference(<float*>(src_byte_ptr + chan_stride))
                                upscaled_view[dst_y, dst_x, 3] = <uint8_t>max(0, min(255, int(val_float * 255)))
                            elif num_chans == 3:  # RGB
                                for chan in range(3):
                                    val_float = dereference(<float*>(src_byte_ptr + chan * chan_stride))
                                    upscaled_view[dst_y, dst_x, chan] = <uint8_t>max(0, min(255, int(val_float * 255)))
                                upscaled_view[dst_y, dst_x, 3] = 255
                            elif num_chans >= 4:  # RGBA
                                for chan in range(4):
                                    val_float = dereference(<float*>(src_byte_ptr + chan * chan_stride))
                                    upscaled_view[dst_y, dst_x, chan] = <uint8_t>max(0, min(255, int(val_float * 255)))
            
            # Create and configure texture
            texture = Texture(context)
            texture.wrap_x = True
                
            # Enable antialiasing via mipmapping
            texture.antialiased = antialiased
            
            # Set texture data
            texture.set_value(upscaled_arr)
            
            # Configure pattern
            pattern.texture = texture
            pattern.scale_factor = 1.0 / dst_width

            for key, value in kwargs.items():
                if hasattr(pattern, key):
                    setattr(pattern, key, value)
                else:
                    raise AttributeError(f"Unknown parameter '{key}' for Pattern")
            
            return pattern
        
        finally:
            # Clean up buffer regardless of success or failure
            if buffer_acquired:
                cpython.PyBuffer_Release(&buf_info)

    # Factory methods for common patterns
    @staticmethod
    def solid(context: Context, **kwargs):
        """
        Creates a solid line pattern (no pattern).

        This is equivalent to not using a pattern at all.

        Args:
            context: The DearCyGui context

        Returns:
            Pattern: A solid pattern
        """
        # Create parameters dict for caching
        cdef dict params = {}  # No specific parameters for solid
        params.update(kwargs)
        
        # Check if already in cache
        cached_pattern = _get_pattern_from_cache(context, "solid", params)
        if cached_pattern is not None:
            return cached_pattern
            
        # Create new pattern if not in cache
        pattern = Pattern(context, **kwargs)

        # Create a solid white 1x1 texture using cython array with uint8
        texture = Texture(context)
        cdef cython_array arr = \
            cython_array(shape=(1, 1, 4), itemsize=1,
                         format='B', mode='c', allocate_buffer=True)
        cdef uint8_t[:,:,:] arr_view = arr
        arr_view[0, 0, 0] = 255
        arr_view[0, 0, 1] = 255
        arr_view[0, 0, 2] = 255
        arr_view[0, 0, 3] = 255
        texture.set_value(arr)
        pattern.texture = texture
        
        # Store in cache
        _store_pattern_in_cache(context, "solid", params, pattern)
        
        return pattern

    @staticmethod
    def dashed(context: Context, int32_t dash_length=10, int32_t gap_length=10,
               int32_t upscale_factor=32, bint opaque=False, **kwargs):
        """
        Creates a dashed line pattern.

        Args:
            context: The DearCyGui context
            dash_length: Length of the dash in pixels
            gap_length: Length of the gap in pixels
            upscale_factor: Upscaling factor for the pattern
            opaque: Whether gaps should be black (True) or transparent (False)

        Returns:
            Pattern: A dashed line pattern
        """
        # Create parameters dict for caching
        cdef dict params = {
            'dash_length': dash_length,
            'gap_length': gap_length,
            'upscale_factor': upscale_factor,
            'opaque': opaque
        }
        params.update(kwargs)
        
        # Check if already in cache
        cached_pattern = _get_pattern_from_cache(context, "dashed", params)
        if cached_pattern is not None:
            return cached_pattern
            
        # Not in cache, create new pattern
        if context is None:
            raise ValueError("Context cannot be None")
        
        if dash_length <= 0:
            raise ValueError("dash_length must be positive")
        
        if gap_length <= 0:
            raise ValueError("gap_length must be positive")
        
        if upscale_factor < 1:
            raise ValueError("upscale_factor must be at least 1")
        
        # Create a texture with dash_length white followed by gap_length transparent
        cdef int32_t width = dash_length + gap_length
        cdef cython_array arr = \
            cython_array(shape=(1, width, 4), itemsize=1,
                         format='B', mode='c', allocate_buffer=True)
        cdef uint8_t[:,:,:] arr_view = arr
        cdef int32_t x

        if opaque:
            # Set everything to black and opaque
            for x in range(width):
                arr_view[0, x, 0] = 0
                arr_view[0, x, 1] = 0
                arr_view[0, x, 2] = 0
                arr_view[0, x, 3] = 255
        else:
            # Initialize to transparent black
            memset(&arr_view[0, 0, 0], 0, arr_view.nbytes)

        # Set dash section to white (255)
        for x in range(dash_length):
            arr_view[0, x, 0] = 255
            arr_view[0, x, 1] = 255
            arr_view[0, x, 2] = 255
            arr_view[0, x, 3] = 255

        pattern = Pattern.from_array(context, arr, upscale_factor=upscale_factor, **kwargs)
        
        # Store in cache
        _store_pattern_in_cache(context, "dashed", params, pattern)
        
        return pattern

    @staticmethod
    def dotted(context: Context, int32_t dot_size=2, int32_t spacing=8,
               int32_t upscale_factor=64, bint opaque=False, **kwargs):
        """
        Creates a dotted line pattern.

        Args:
            context: The DearCyGui context
            dot_size: Size of each dot in pixels
            spacing: Total spacing between dots in pixels
            upscale_factor: Upscaling factor for the pattern
            opaque: Whether gaps should be black (True) or transparent (False)

        Returns:
            Pattern: A dotted line pattern
        """
        # Create parameters dict for caching
        cdef dict params = {
            'dot_size': dot_size,
            'spacing': spacing,
            'upscale_factor': upscale_factor,
            'opaque': opaque
        }
        params.update(kwargs)
        
        # Check if already in cache
        cached_pattern = _get_pattern_from_cache(context, "dotted", params)
        if cached_pattern is not None:
            return cached_pattern
            
        # Not in cache, create new pattern
        if context is None:
            raise ValueError("Context cannot be None")
        
        if dot_size <= 0:
            raise ValueError("dot_size must be positive")
        
        if spacing <= 0:
            raise ValueError("spacing must be positive")
        
        if upscale_factor < 1:
            raise ValueError("upscale_factor must be at least 1")
        
        # Create a texture with a dot and spacing
        cdef int32_t width = max(dot_size + spacing, 2)
        cdef cython_array arr = \
            cython_array(shape=(1, width, 4), itemsize=1,
                         format='B', mode='c', allocate_buffer=True)
        cdef uint8_t[:,:,:] arr_view = arr
        cdef int32_t x

        if opaque:
            # Set everything to black and opaque
            for x in range(width):
                arr_view[0, x, 0] = 0
                arr_view[0, x, 1] = 0
                arr_view[0, x, 2] = 0
                arr_view[0, x, 3] = 255
        else:
            # Initialize to transparent black
            memset(&arr_view[0, 0, 0], 0, arr_view.nbytes)

        # Set dot section to white (255)
        for x in range(dot_size):
            arr_view[0, x, 0] = 255
            arr_view[0, x, 1] = 255
            arr_view[0, x, 2] = 255
            arr_view[0, x, 3] = 255

        pattern = Pattern.from_array(context, arr, upscale_factor=upscale_factor, **kwargs)
        
        # Store in cache
        _store_pattern_in_cache(context, "dotted", params, pattern)
        
        return pattern

    @staticmethod
    def dash_dot(context: Context, int32_t dash_length=10, int32_t dot_size=2,
                 int32_t spacing=5, int32_t upscale_factor=64,
                 bint opaque=False, **kwargs):
        """
        Creates a dash-dot-dash pattern (commonly used in technical drawings).

        Args:
            context: The DearCyGui context
            dash_length: Length of each dash in pixels
            dot_size: Size of each dot in pixels
            spacing: Spacing between elements in pixels
            upscale_factor: Upscaling factor for the pattern
            opaque: Whether gaps should be black (True) or transparent (False)

        Returns:
            Pattern: A dash-dot pattern
        """
        # Create parameters dict for caching
        cdef dict params = {
            'dash_length': dash_length,
            'dot_size': dot_size,
            'spacing': spacing,
            'upscale_factor': upscale_factor,
            'opaque': opaque
        }
        params.update(kwargs)
        
        # Check if already in cache
        cached_pattern = _get_pattern_from_cache(context, "dash_dot", params)
        if cached_pattern is not None:
            return cached_pattern
            
        # Not in cache, create new pattern
        if context is None:
            raise ValueError("Context cannot be None")
        
        if dash_length <= 0:
            raise ValueError("dash_length must be positive")
        
        if dot_size <= 0:
            raise ValueError("dot_size must be positive")
        
        if spacing <= 0:
            raise ValueError("spacing must be positive")
        
        if upscale_factor < 1:
            raise ValueError("upscale_factor must be at least 1")
        
        # Create pattern: dash - space - dot - space
        cdef int32_t width = dash_length + spacing + dot_size + spacing
        cdef cython_array arr = \
            cython_array(shape=(1, width, 4), itemsize=1,
                         format='B', mode='c', allocate_buffer=True)
        cdef uint8_t[:,:,:] arr_view = arr
        cdef int32_t x

        if opaque:
            # Set everything to black and opaque
            for x in range(width):
                arr_view[0, x, 0] = 0
                arr_view[0, x, 1] = 0
                arr_view[0, x, 2] = 0
                arr_view[0, x, 3] = 255
        else:
            # Initialize to transparent black
            memset(&arr_view[0, 0, 0], 0, arr_view.nbytes)

        # Set dash section to white (255)
        for x in range(dash_length):
            arr_view[0, x, 0] = 255
            arr_view[0, x, 1] = 255
            arr_view[0, x, 2] = 255
            arr_view[0, x, 3] = 255

        # Set dot section to white (255)
        for x in range(dot_size):
            arr_view[0, dash_length + spacing + x, 0] = 255
            arr_view[0, dash_length + spacing + x, 1] = 255
            arr_view[0, dash_length + spacing + x, 2] = 255
            arr_view[0, dash_length + spacing + x, 3] = 255

        pattern = Pattern.from_array(context, arr, upscale_factor=upscale_factor, **kwargs)

        # Store in cache
        _store_pattern_in_cache(context, "dash_dot", params, pattern)

        return pattern

    @staticmethod
    def dash_dot_dot(context: Context, int32_t dash_length=10, int32_t dot_size=2,
                     int32_t spacing=5, int32_t upscale_factor=64,
                     bint opaque=False, **kwargs):
        """
        Creates a dash-dot-dot pattern with one dash followed by two dots.

        Args:
            context: The DearCyGui context
            dash_length: Length of the dash in pixels
            dot_size: Size of each dot in pixels
            spacing: Spacing between elements in pixels
            upscale_factor: Upscaling factor for the pattern
            opaque: Whether gaps should be black (True) or transparent (False)

        Returns:
            Pattern: A dash-dot-dot pattern
        """
        # Create parameters dict for caching
        cdef dict params = {
            'dash_length': dash_length,
            'dot_size': dot_size,
            'spacing': spacing,
            'upscale_factor': upscale_factor,
            'opaque': opaque
        }
        params.update(kwargs)
        
        # Check if already in cache
        cached_pattern = _get_pattern_from_cache(context, "dash_dot_dot", params)
        if cached_pattern is not None:
            return cached_pattern
            
        # Not in cache, create new pattern
        if context is None:
            raise ValueError("Context cannot be None")
        
        if dash_length <= 0:
            raise ValueError("dash_length must be positive")
        
        if dot_size <= 0:
            raise ValueError("dot_size must be positive")
        
        if spacing <= 0:
            raise ValueError("spacing must be positive")
        
        if upscale_factor < 1:
            raise ValueError("upscale_factor must be at least 1")
        
        # Create pattern: dash - space - dot - space - dot - space
        cdef int32_t width = dash_length + spacing + dot_size + spacing + dot_size + spacing
        cdef cython_array arr = \
            cython_array(shape=(1, width, 4), itemsize=1,
                         format='B', mode='c', allocate_buffer=True)
        cdef uint8_t[:,:,:] arr_view = arr
        cdef int32_t x

        if opaque:
            # Set everything to black and opaque
            for x in range(width):
                arr_view[0, x, 0] = 0
                arr_view[0, x, 1] = 0
                arr_view[0, x, 2] = 0
                arr_view[0, x, 3] = 255
        else:
            # Initialize to transparent black
            memset(&arr_view[0, 0, 0], 0, arr_view.nbytes)

        # Set dash section
        for x in range(dash_length):
            arr_view[0, x, 0] = 255
            arr_view[0, x, 1] = 255
            arr_view[0, x, 2] = 255
            arr_view[0, x, 3] = 255

        # Set first dot
        for x in range(dot_size):
            arr_view[0, dash_length + spacing + x, 0] = 255
            arr_view[0, dash_length + spacing + x, 1] = 255
            arr_view[0, dash_length + spacing + x, 2] = 255
            arr_view[0, dash_length + spacing + x, 3] = 255

        # Set second dot
        for x in range(dot_size):
            arr_view[0, dash_length + spacing + dot_size + spacing + x, 0] = 255
            arr_view[0, dash_length + spacing + dot_size + spacing + x, 1] = 255
            arr_view[0, dash_length + spacing + dot_size + spacing + x, 2] = 255
            arr_view[0, dash_length + spacing + dot_size + spacing + x, 3] = 255

        pattern = Pattern.from_array(context, arr, upscale_factor=upscale_factor, **kwargs)

        # Store in cache
        _store_pattern_in_cache(context, "dash_dot_dot", params, pattern)

        return pattern

    @staticmethod
    def railroad(context: Context, int32_t track_width=4, int32_t tie_width=10,
                 int32_t tie_spacing=10, upscale_factor=64,
                 bint opaque=False, **kwargs):
        """
        Creates a railroad track pattern with parallel lines and perpendicular ties.

        Args:
            context: The DearCyGui context
            track_width: Width between the parallel lines in pixels
            tie_width: Width of the perpendicular ties in pixels
            tie_spacing: Spacing between ties in pixels
            opaque: Whether gaps should be black (True) or transparent (False)

        Returns:
            Pattern: A railroad track pattern
        """
        # Create parameters dict for caching
        cdef dict params = {
            'track_width': track_width,
            'tie_width': tie_width,
            'tie_spacing': tie_spacing,
            'opaque': opaque
        }
        params.update(kwargs)
        
        # Check if already in cache
        cached_pattern = _get_pattern_from_cache(context, "railroad", params)
        if cached_pattern is not None:
            return cached_pattern
            
        # Not in cache, create new pattern
        if context is None:
            raise ValueError("Context cannot be None")
        
        if track_width <= 0:
            raise ValueError("track_width must be positive")
        
        if tie_width <= 0:
            raise ValueError("tie_width must be positive")
        
        if tie_spacing <= 0:
            raise ValueError("tie_spacing must be positive")
        
        if upscale_factor < 1:
            raise ValueError("upscale_factor must be at least 1")
        
        # Create pattern: two horizontal lines with vertical ties
        cdef int32_t width = tie_width + tie_spacing
        cdef int32_t height = track_width + 2  # +2 for the tracks
        cdef cython_array arr = \
            cython_array(shape=(height, width, 4), itemsize=1,
                         format='B', mode='c', allocate_buffer=True)
        cdef uint8_t[:,:,:] arr_view = arr
        cdef int32_t x, y

        if opaque:
            # Set everything to black and opaque
            for x in range(width):
                arr_view[0, x, 0] = 0
                arr_view[0, x, 1] = 0
                arr_view[0, x, 2] = 0
                arr_view[0, x, 3] = 255
        else:
            # Initialize to transparent black
            memset(&arr_view[0, 0, 0], 0, arr_view.nbytes)

        # Draw top horizontal line
        for x in range(width):
            arr_view[0, x, 0] = 255
            arr_view[0, x, 1] = 255
            arr_view[0, x, 2] = 255
            arr_view[0, x, 3] = 255

        # Draw bottom horizontal line
        for x in range(width):
            arr_view[height-1, x, 0] = 255
            arr_view[height-1, x, 1] = 255
            arr_view[height-1, x, 2] = 255
            arr_view[height-1, x, 3] = 255

        # Draw vertical ties
        for x in range(tie_width):
            for y in range(height):
                arr_view[y, x, 0] = 255
                arr_view[y, x, 1] = 255
                arr_view[y, x, 2] = 255
                arr_view[y, x, 3] = 255

        pattern = Pattern.from_array(context, arr, upscale_factor=upscale_factor, **kwargs)

        # Store in cache
        _store_pattern_in_cache(context, "railroad", params, pattern)

        return pattern

    @staticmethod
    def double_dash(context: Context, int32_t dash_length=10, int32_t gap_length=5,
                    int32_t dash_width=2, int32_t upscale_factor=64,
                    bint opaque=False, **kwargs):
        """
        Creates a double-dashed line pattern with two parallel dashed lines.

        Args:
            context: The DearCyGui context
            dash_length: Length of each dash in pixels
            gap_length: Length of the gap between dashes in pixels
            dash_width: Width of each dash line in pixels
            opaque: Whether gaps should be black (True) or transparent (False)
            
        Returns:
            Pattern: A double-dashed pattern
        """
        cdef dict params = {
            'dash_length': dash_length,
            'gap_length': gap_length,
            'dash_width': dash_width,
            'upscale_factor': upscale_factor,
            'opaque': opaque
        }
        params.update(kwargs)

        # Check if already in cache
        cached_pattern = _get_pattern_from_cache(context, "double_dash", params)
        if cached_pattern is not None:
            return cached_pattern

        # Not in cache, create new pattern

        if context is None:
            raise ValueError("Context cannot be None")
        
        if dash_length <= 0:
            raise ValueError("dash_length must be positive")
        
        if gap_length <= 0:
            raise ValueError("gap_length must be positive")
        
        if dash_width <= 0:
            raise ValueError("dash_width must be positive")
        
        if upscale_factor < 1:
            raise ValueError("upscale_factor must be at least 1")
        
        # Create pattern: two parallel dashes with a gap
        cdef int32_t width = dash_length + gap_length
        cdef int32_t height = dash_width * 3  # Space for two dashes and gap between
        cdef cython_array arr = \
            cython_array(shape=(height, width, 4), itemsize=1,
                         format='B', mode='c', allocate_buffer=True)
        cdef uint8_t[:,:,:] arr_view = arr
        cdef int32_t x, y

        if opaque:
            # Set everything to black and opaque
            for x in range(width):
                arr_view[0, x, 0] = 0
                arr_view[0, x, 1] = 0
                arr_view[0, x, 2] = 0
                arr_view[0, x, 3] = 255
        else:
            # Initialize to transparent black
            memset(&arr_view[0, 0, 0], 0, arr_view.nbytes)

        # Top dash
        for y in range(dash_width):
            for x in range(dash_length):
                arr_view[y, x, 0] = 255
                arr_view[y, x, 1] = 255
                arr_view[y, x, 2] = 255
                arr_view[y, x, 3] = 255

        # Bottom dash
        for y in range(height-dash_width, height):
            for x in range(dash_length):
                arr_view[y, x, 0] = 255
                arr_view[y, x, 1] = 255
                arr_view[y, x, 2] = 255
                arr_view[y, x, 3] = 255

        pattern = Pattern.from_array(context, arr, upscale_factor=upscale_factor, **kwargs)

        # Store in cache
        _store_pattern_in_cache(context, "double_dash", params, pattern)

        return pattern

    @staticmethod
    def checkerboard(context: Context, int32_t cell_size=5, int32_t stripe_width=1,
                     int32_t upscale_factor=64, bint opaque=False, **kwargs):
        """
        Creates a checkerboard pattern with white stripes borders.
        
        Args:
            context: The DearCyGui context
            cell_size: Size of each square cell in pixels
            stripe_width: Width of white stripes borders (applied to both sides)
            upscale_factor: Factor to upscale the pattern for better quality (default: 8)
            opaque: Whether black squares should be opaque (True) or transparent (False)
            
        Returns:
            Pattern: A checkerboard pattern with white stripes
        """
        cdef dict params = {
            'cell_size': cell_size,
            'stripe_width': stripe_width,
            'upscale_factor': upscale_factor,
            'opaque': opaque
        }
        params.update(kwargs)

        # Check if already in cache
        cached_pattern = _get_pattern_from_cache(context, "checkerboard", params)
        if cached_pattern is not None:
            return cached_pattern

        if context is None:
            raise ValueError("Context cannot be None")
        
        if cell_size <= 0:
            raise ValueError("cell_size must be positive")
        
        if stripe_width < 0:
            raise ValueError("stripe_width cannot be negative")
        
        if upscale_factor < 1:
            raise ValueError("upscale_factor must be at least 1")
        
        # Calculate dimensions for a 2x2 cell pattern plus border stripes
        cdef int32_t grid_unit = cell_size
        cdef int32_t width = grid_unit * 2
        cdef int32_t height = grid_unit * 2
        
        # Add border stripes (one stripe width on each side)
        height += stripe_width * 2
        
        cdef cython_array arr = \
            cython_array(shape=(height, width, 4), itemsize=1,
                        format='B', mode='c', allocate_buffer=True)
        cdef uint8_t[:,:,:] arr_view = arr
        cdef int32_t x, y
    
        # Initialize all pixels to white and fully opaque
        memset(&arr_view[0, 0, 0], 255, arr_view.nbytes)
                
        # Fill the checkerboard pattern (skipping border stripes)
        for y in range(stripe_width, height - stripe_width):
            # Calculate grid position (adjusted for borders)
            grid_y = (y - stripe_width) // cell_size
            
            for x in range(width):
                # Calculate grid position (adjusted for borders)
                grid_x = x // cell_size
                
                # Create checkerboard pattern
                if (grid_x + grid_y) % 2 == 1:
                    arr_view[y, x, 0] = 0
                    arr_view[y, x, 1] = 0
                    arr_view[y, x, 2] = 0
                    # Set alpha based on opaque parameter
                    arr_view[y, x, 3] = 255 if opaque else 0
    
        # Create pattern with proper wrapping for both dimensions
        pattern = Pattern.from_array(context, arr, upscale_factor=upscale_factor, **kwargs)

        # Store in cache
        _store_pattern_in_cache(context, "checkerboard", params, pattern)

        return pattern