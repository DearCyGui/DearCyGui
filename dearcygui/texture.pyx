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
#distutils: language=c++

from libc.stdint cimport uint8_t, uintptr_t, int32_t

from cython.view cimport array as cython_array
from cython.operator cimport dereference
cimport cpython

# This file is the only one that is linked to the C++ code
# Thus it is the only one allowed to make calls to it

from .backends.backend cimport platformViewport
from .core cimport baseItem, lock_gil_friendly
from .c_types cimport unique_lock, DCGMutex
from .types cimport parse_texture


cdef class Texture(baseItem):
    """
    Represents a texture that can be used in the UI.

    Attributes:
    - hint_dynamic: Boolean indicating if the texture is dynamic.
    - nearest_neighbor_upsampling: Boolean indicating if nearest neighbor upsampling is used.
    - width: Width of the texture.
    - height: Height of the texture.
    - num_chans: Number of channels in the texture.
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
            (<platformViewport*>self.context.viewport._platform).freeTexture(self.allocated_texture)
            (<platformViewport*>self.context.viewport._platform).releaseUploadContext()

    @property
    def hint_dynamic(self):
        """
        Hint for texture placement that
        the texture will be updated very
        frequently.
        Must be set before set_value/allocate.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._hint_dynamic
    @hint_dynamic.setter
    def hint_dynamic(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._hint_dynamic = value
    @property
    def nearest_neighbor_upsampling(self):
        """
        Whether to use nearest neighbor interpolation
        instead of bilinear interpolation when upscaling
        the texture. Must be set before set_value/allocate.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return True if self._filtering_mode == 1 else 0
    @nearest_neighbor_upsampling.setter
    def nearest_neighbor_upsampling(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._filtering_mode = 1 if value else 0
    @property
    def width(self):
        """ Width of the current texture content """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.width
    @property
    def height(self):
        """ Height of the current texture content """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.height
    @property
    def num_chans(self):
        """ Number of channels of the current texture content """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self.num_chans

    @property
    def texture_id(self):
        """ Internal texture ID used by the rendering backend
        for the current allocation. May change if set_value is
        called, and is released when the Texture is freed."""
        return <uintptr_t>self.allocated_texture

    def allocate(self, *,
                 int32_t width,
                 int32_t height,
                 int32_t num_chans,
                 bint uint8 = False,
                 bint float32 = False,
                 bint no_realloc = True):
        """
        Allocate the buffer backing. You don't need
        to use this for normal texture usage as it is done
        automatically by set_value.

        This function is useful when needing to write to a texture
        using external rendering tools (OpenGL, etc) and you don't
        want to do a first set_value to initialize

        Inputs:
        - width: width of the target texture
        - height: height of the target texture
        - num_chans: number of channels (1, 2, 3, 4)
        - uint8: (False by default) the texture format is unsigned bytes
        - float32: (False by default) the texture format is float32
        - no_realloc: (True by default) reallocations of the texture
            will be prevented (set_value, etc), thus guaranteeing a fixed
            allocated_texture ID.
        uint8 or float32 must be set.
        """
        if self.allocated_texture != NULL and self._no_realloc:
            raise ValueError("Texture backing cannot be reallocated")

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
            self.allocated_texture = \
                (<platformViewport*>self.context.viewport._platform).allocateTexture(width,
                                                                    height,
                                                                    num_chans,
                                                                    self._dynamic,
                                                                    buffer_type,
                                                                    self._filtering_mode)
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
        Pass an array as texture data.
        The currently native formats are:
        - data type: uint8 or float32.
            Anything else will be converted to float32
            float32 data must be normalized between 0 and 1.
        - number of channels: 1 (R), 2 (RG), 3 (RGB), 4 (RGBA)

        In the case of single channel textures, during rendering, R is
        duplicated on G and B, thus the texture is displayed as gray,
        not red.

        If set_value is called on a texture which already
        has content, the previous allocation will be reused
        if the size, type and number of channels is identical.

        The data is uploaded right away during set_value,
        thus the call is not instantaneous.
        The data can be discarded after set_value.

        If you change the data of a texture, you don't
        need to bind it again to the objects it is
        bound. The objects will automatically take
        the updated texture.
        """
        cdef int chan, row, col
        cdef int num_chans, num_rows, num_cols
        cdef double min_value = 255., max_value = 0.
        cdef bint has_float
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
                (<platformViewport*>self.context.viewport._platform).makeUploadContextCurrent()
                (<platformViewport*>self.context.viewport._platform).freeTexture(self.allocated_texture)
                self.allocated_texture = NULL
                self.context.imgui_mutex.unlock()
            else:
                m2.unlock()
                (<platformViewport*>self.context.viewport._platform).makeUploadContextCurrent()
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
                                                                    self._filtering_mode)

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
            m.unlock()
            m2.unlock() # Release before we get gil again
        cpython.PyBuffer_Release(&buf_info)
        if not(success):
            raise MemoryError("Failed to upload target texture")

    def read(self, int32_t x0=0, int32_t y0=0, int32_t crop_width=0, int32_t crop_height=0):
        """
        Read the texture content. The texture must be
        allocated and have content.

        Inputs:
        - x0: x coordinate of the top left corner of the crop
        - y0: y coordinate of the top left corner of the crop
        - crop_width: width of the crop (0 for full width)
        - crop_height: height of the crop (0 for full_height)

        Returns:
        - cython array: the texture content (similar to numpy array)
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef int32_t width = self.width
        cdef int32_t height = self.height
        cdef int32_t num_chans = self.num_chans
        cdef int32_t buffer_type = self._buffer_type
        cdef int32_t crop_width_ = crop_width if crop_width > 0 else width
        cdef int32_t crop_height_ = crop_height if crop_height > 0 else height
        if x0 < 0 or y0 < 0 or crop_width_ <= 0 or crop_height_ <= 0 or x0 + crop_width_ > width or y0 + crop_height_ > height:
            raise ValueError("Invalid crop coordinates")
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
            success = \
                (<platformViewport*>self.context.viewport._platform).downloadTexture(self.allocated_texture,
                                x0, y0, crop_width_, crop_height_, num_chans,
                                self._buffer_type, data, stride)
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
        Locks a texture for a read operation for an external GL context.

        The target GL context MUST be current.

        The call inserts a GPU fence to ensure any previous
        DearCyGui rendering or upload finishes before the texture
        is read.
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
        Unlocks a texture after a read operation for an external GL context.

        The target GL context MUST be current.

        The call issues a GPU fence that will be used by
        DearCyGui to ensure the texture is not written to
        before the read operation has finished.
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
        Locks a texture for a write operation for an external GL context.

        The target GL context MUST be current.

        The call inserts a GPU fence to ensure any previous
        DearCyGui rendering reading from the texture finishes
        before the texture is written to.
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
        Unlocks a texture after a write operation for an external GL context.

        The target GL context MUST be current.

        The call issues a GPU fence that will be used by
        DearCyGui to ensure the texture is not read from
        before the write operation has finished.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self.c_gl_end_write()
