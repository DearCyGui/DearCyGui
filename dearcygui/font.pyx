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

from libc.math cimport logf, ceil, INFINITY
from libc.stdint cimport uintptr_t, int32_t
from libcpp cimport bool
from libcpp.deque cimport deque
from libcpp.vector cimport vector

cimport cython
from cython.view cimport array as cython_array
from cpython cimport PySequence_Check
from dearcygui.wrapper cimport imgui

from .core cimport baseFont, baseItem, Callback, \
    lock_gil_friendly, clear_obj_vector, append_obj_vector
from .c_types cimport unique_lock, DCGMutex
from .texture cimport Texture
from .types cimport parse_texture

import ctypes
from concurrent.futures import ThreadPoolExecutor

"""
Loading a font is complicated.

This file proposes some helpers to load a font in a format
that DearCyGui can use. You can adapt to your needs.

What DearCyGui needs to render a text:
- A texture (RGBA or just Alpha) containing the font
- Correspondance between the unicode characters and where
  the character is in the texture.
- Correspondance between the unicode characters and their size
  and position when rendered (for instance A and g usually do not start
  and stop at the same coordinates).
- The vertical spacing taken by the font when rendered. It corresponds
  to the height of the box that will be allocated in the UI elements
  to the text.
- The horizontal spacing between the end of a character and the start of a
  new one. Note that some fonts have a different spacing depending on the pair
  of characters (it is called kerning), but it is not supported yet.

What is up to you to provide:
- Rendered bitmaps of your characters, at the target scale. Basically for
  good quality rendering, you should try to ensure that the size
  of the character when rendered is the same as the size in the bitmap.
  The size of the rendered character is affected by the rendering scale
  (screen dpi scale, window scale, plot scale, etc).
- Passing correct spacing value to have characters properly aligned, etc
"""

import freetype
import freetype.raw
import os

def get_system_fonts() -> list[str]:
    """
    Returns a list of available fonts
    """
    fonts_filename = []
    try:
        from find_system_fonts_filename import get_system_fonts_filename, FindSystemFontsFilenameException
        fonts_filename = get_system_fonts_filename()
    except FindSystemFontsFilenameException:
        # Deal with the exception
        pass
    return fonts_filename


cdef class Font(baseFont):
    """
    Represents a font that can be used in the UI.
    
    A Font object encapsulates the rendering information for text in the UI. 
    It contains the texture data, size information, and scaling behavior.
    
    Fonts are typically created through FontTexture.add_font_file() or 
    FontTexture.add_custom_font() rather than directly instantiated.
    """
    def __cinit__(self, context, *args, **kwargs):
        self.can_have_sibling = False
        self._font = NULL
        self._container = None
        self._scale = 1.
        self._dpi_scaling = True

    @property
    def texture(self):
        """
        The FontTexture containing this font.
        
        This property returns the parent FontTexture object that created and 
        contains this font. The texture stores the actual bitmap data used 
        for rendering.
        """
        return self._container

    @property
    def size(self):
        """
        Native height of characters in pixels.
        
        This is the original size at which the font was created. The actual 
        rendered size will be affected by the scale property and the global 
        scaling factor.
        """
        if self._font == NULL:
            raise ValueError("Uninitialized font")
        return (<imgui.ImFont*>self._font).FontSize

    @property
    def scale(self):
        """
        Multiplicative factor to scale the font when used.
        
        This scale is applied in addition to any global scaling. Can be used 
        to make specific fonts larger or smaller than others. A value of 1.0 
        means no additional scaling.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._scale

    @scale.setter
    def scale(self, float value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value <= 0.:
            raise ValueError(f"Invalid scale {value}")
        self._scale = value

    @property
    def no_scaling(self):
        """
        Controls whether font is affected by DPI scaling.
        
        When True, the font ignores the global DPI scaling and only uses its own
        scale property. This is useful for fonts that should maintain consistent
        size regardless of screen resolution. Default is False.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return not(self._dpi_scaling)

    @no_scaling.setter
    def no_scaling(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._dpi_scaling = not(value)

    cdef void push(self) noexcept nogil:
        if self._font == NULL:
            return
        self.mutex.lock()
        cdef imgui.ImFont *font = <imgui.ImFont*>self._font
        self._scales_backup.push_back(font.Scale)
        font.Scale = \
            (self.context.viewport.global_scale if self._dpi_scaling else 1.) * self._scale
        imgui.PushFont(font)

    cdef void pop(self) noexcept nogil:
        if self._font == NULL:
            return
        # If we applied PushFont and the previous Font
        # was already this font, then PopFont will apply
        # the Font again, but the Scale is incorrect if
        # we don't restore it first.
        cdef imgui.ImFont *font = <imgui.ImFont*>self._font
        font.Scale = self._scales_backup.back()
        self._scales_backup.pop_back()
        imgui.PopFont()
        self.mutex.unlock()

cdef class FontMultiScales(baseFont):
    """
    A font container that manages multiple Font objects at different scales.
    
    Automatically selects the font with the inverse scale closest to the 
    current global scale when used. This provides sharp text rendering across 
    different display densities without manual font switching. The font with 
    scale closest to 1/global_scale will be selected to minimize distortion.
    
    This class tracks recently encountered scales to optimize font selection 
    and provides a callback mechanism to notify when new scales are encountered, 
    allowing for dynamic font creation as needed.
    """

    def __cinit__(self, context, *args, **kwargs):
        self.can_have_sibling = False

    def __dealloc__(self):
        clear_obj_vector(self._fonts)
        clear_obj_vector(self._callbacks) 

    @property
    def fonts(self):
        """
        List of attached fonts with different scales.
        
        Each font in this list should have a different scale value to provide 
        optimal rendering at different display densities. The font with scale 
        closest to 1/global_scale will be used when this FontMultiScales is 
        pushed.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int32_t i
        for i in range(<int>self._fonts.size()):
            result.append(<Font>self._fonts[i])
        return result

    @fonts.setter 
    def fonts(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            clear_obj_vector(self._fonts)
            return

        # Convert to list if single font
        if PySequence_Check(value) == 0:
            value = (value,)

        # Validate all inputs are Font objects
        for font in value:
            if not isinstance(font, Font):
                raise TypeError(f"{font} is not a Font instance")

        # Success - store fonts
        clear_obj_vector(self._fonts)
        append_obj_vector(self._fonts, value)

    @property 
    def recent_scales(self):
        """
        List of up to 10 most recent global scales encountered during rendering.
        
        These scales represent the display density values recently seen while 
        rendering UI. This information can be used to create additional font 
        instances optimized for these specific scales. The scales are not stored 
        in any particular order.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef list result = []
        cdef int32_t i
        for i in range(<int>self._stored_scales.size()):
            result.append(self._stored_scales[i])
        return result

    @property
    def callbacks(self):
        """
        Callbacks triggered when a new scale is encountered.
        
        Each callback is called with the sender (this object), the target (also 
        this object), and the new scale value that was just encountered. This 
        mechanism enables dynamic font generation for new display densities.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        result = []
        cdef int32_t i
        for i in range(<int>self._callbacks.size()):
            result.append(<Callback>self._callbacks[i])
        return result

    @callbacks.setter 
    def callbacks(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is None:
            clear_obj_vector(self._callbacks)
            return
        cdef list items = []
        if PySequence_Check(value) == 0:
            value = (value,)
        for v in value:
            items.append(v if isinstance(v, Callback) else Callback(v))
        clear_obj_vector(self._callbacks)
        append_obj_vector(self._callbacks, items)

    cdef void push(self) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        self.mutex.lock()
        if self._fonts.empty():
            return

        # Find font with closest invert scale to current global scale
        # (we want that scale * global_scale == 1, to have sharp fonts)
        cdef float global_scale = self.context.viewport.global_scale
        cdef float target_scale = logf(global_scale)
        cdef float best_diff = 1e10
        cdef float diff
        cdef PyObject *best_font = NULL
        cdef int32_t i
        
        for i in range(<int>self._fonts.size()):
            diff = abs(logf((<Font>self._fonts[i])._scale) + target_scale)
            if diff < best_diff:
                best_diff = diff
                best_font = self._fonts[i]

        if best_font == NULL:
            best_font = self._fonts[0]
        (<Font>best_font).push()
        self._applied_fonts.push_back(best_font)

        # Keep seen scales
        cdef bint scale_found = False
        cdef float past_scale
        for i in range(<int>self._stored_scales.size()):
            past_scale = self._stored_scales[i]
            # scale already in list
            if abs(past_scale - global_scale) < 1e-6:
                scale_found = True
                break

        if scale_found:
            return

        # add to list - emulating a deque
        if self._stored_scales.size() < 10:
            self._stored_scales.resize(self._stored_scales.size() + 1)

        # Shift elements to the right to make room at front
        for i in range(<int>self._stored_scales.size() - 1, 0, -1):
            self._stored_scales[i] = self._stored_scales[i-1]
            
        # Insert new scale at the front
        self._stored_scales[0] = global_scale

        # Notify callbacks of new scale
        if not(self._callbacks.empty()):
            for i in range(<int>self._callbacks.size()):
                self.context.queue_callback_arg1float(<Callback>self._callbacks[i],
                                                    self, 
                                                    self,
                                                    global_scale)

    cdef void pop(self) noexcept nogil:
        if not self._fonts.empty():
            # We only pushed one font, so only need one pop
            (<Font>self._applied_fonts.back()).pop()
            self._applied_fonts.pop_back()
        self.mutex.unlock()


cdef class AutoFont(FontMultiScales):
    """
    A self-managing font container that automatically creates and caches fonts at different scales.
    
    Automatically creates new font sizes when needed to match global_scale changes.
    
    Parameters
    ----------
    context : Context
        The context this font belongs to
    base_size : float = 17.0
        Base font size before scaling
    font_creator : callable = None
        Function to create fonts. Takes size as first argument and optional kwargs.
        The output should be a GlyphSet.
        If None, uses make_extended_latin_font.
    **kwargs : 
        Additional arguments passed to font_creator
    """
    def __init__(self, context, 
                 float base_size=17.0,
                 font_creator=None,
                 **kwargs):
        super().__init__(context)
                 
        self._base_size = base_size
        self._kwargs = kwargs
        self._font_creator = font_creator if font_creator is not None else make_extended_latin_font
        self._font_creation_executor = ThreadPoolExecutor(max_workers=1)
        self._pending_fonts = set()
        
        # Set up callback for new scales
        self.callbacks = self._on_new_scale
        
        # Create initial font at current global scale
        # Pass exceptions for the first time we create the font
        self._pending_fonts.add(self.context.viewport.global_scale)
        self._create_font_at_scale(self.context.viewport.global_scale, False)

    def __del__(self):
        if self._font_creation_executor is not None:
            self._font_creation_executor.shutdown(wait=True)

    def _on_new_scale(self, sender, target, float scale) -> None:
        """Called when a new global scale is encountered"""
        # Only queue font creation if we don't have it pending already
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if scale in self._pending_fonts:
            return
        self._pending_fonts.add(scale)
        m.unlock()
        self._font_creation_executor.submit(self._create_font_at_scale, scale, True)
        
    cpdef void _create_font_at_scale(self, float scale, bint no_fail):
        """Create a new font at the given scale"""
        cdef unique_lock[DCGMutex] m
        # Create texture and font
        cdef FontTexture texture = FontTexture(self.context)
        cdef Font font = None
        
        # Calculate scaled size
        cdef int32_t scaled_size = int(round(self._base_size * scale))

        try:
            # Create glyph set using the font creator
            glyph_set = self._font_creator(scaled_size, **self._kwargs)

            # Add to texture and build
            texture.add_custom_font(glyph_set)
            texture.build()

            # Get font and configure scale
            font = texture._fonts[0] 
            font.scale = 1.0/scale

            self._add_new_font_to_list(font)
        except Exception as e:
            if not(no_fail):
                raise e
            pass # ignore failures (maybe we have a huge scale and
                 # the font is too big to fit in the texture)
        finally:
            # We do not lock the mutex before to not block rendering
            # during texture creation.
            lock_gil_friendly(m, self.mutex)
            self._pending_fonts.remove(scale)

    cdef void _add_new_font_to_list(self, Font new_font):
        """Add new font and prune fonts list to keep best matches"""
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        # Get recent scales we want to optimize for
        cdef DCGVector[float] target_scales = self._stored_scales
        cdef float target_scale

        # Calculate scores for all fonts including new one
        cdef dict best_fonts = {}
        cdef float score, current_score
        cdef Font font
        cdef int32_t i
        
        for font in list(self.fonts) + [new_font]:
            for i in range(<int>target_scales.size()):
                target_scale = target_scales[i]
                # Calculate score based on the difference between
                # the font scale and the target scale
                # We want to minimize the absolute difference
                # between log(font_scale) and log(target_scale)
                score = abs(logf(font._scale) + logf(target_scale))
                current_score = best_fonts.get(target_scale, (1e10, None))[0]
                if score < current_score:
                    best_fonts[target_scale] = (score, font)

        # Retain only the best fonts for each target scale
        retained_fonts = set()
        for target_scale in best_fonts:
            retained_fonts.add(best_fonts[target_scale][1])

        if len(retained_fonts) == 0:
            # No font was retained, maybe we haven't been
            # applied yet and the list of scales is empty.
            # keep the new font
            retained_fonts.add(new_font)
        # Update the fonts list
        self.fonts = list(retained_fonts)

cdef extern from * nogil:
    """
    const ImWchar minimal_font_range[] = {
        0          // Array terminator (required)
    };

        //'a', 'a',  // Range from 'a' to 'a' (just the single character)
    """
    imgui.ImWchar * minimal_font_range



cdef class FontTexture(baseItem):
    """
    Packs one or several fonts into
    a texture for internal use by ImGui.

    In order to have sharp fonts with various screen
    dpi scalings, two options are available:
    1) Handle scaling yourself:
        Whenever the global scale changes, make
        a new font using a scaled size, and
        set no_scaling to True
    2) Handle scaling yourself at init only:
        In most cases it is reasonnable to
        assume the dpi scale will not change.
        In that case the easiest is to check
        the viewport dpi scale after initialization,
        load the scaled font size, and then set
        font.scale to the inverse of the dpi scale.
        This will render at the intended size
        as long as the dpi scale is not changed,
        and will scale if it changes (but will be
        slightly blurry).

    Currently the default font uses option 2). Call
    fonts.make_extended_latin_font(your_size) and
    add_custom_font to get the default font at a different
    scale, and implement 1) or 2) yourself.
    """
    def __cinit__(self, context, *args, **kwargs):
        self._built = False
        self.can_have_sibling = False
        self._atlas = <void*>(new imgui.ImFontAtlas())
        self._texture = Texture(context)
        self._fonts_files = []
        self._fonts = []

    def __dealloc__(self):
        cdef imgui.ImFontAtlas *atlas = <imgui.ImFontAtlas*>self._atlas
        if atlas == NULL:
            return
        atlas.Clear() # Unsure if needed
        del atlas

    def add_font_file(self,
                      str path,
                      float size=13.,
                      int32_t index_in_file=0,
                      float density_scale=1.,
                      bint align_to_pixel=False):
        """
        Prepare the target font file to be added to the FontTexture,
        using ImGui's font loader.

        path: path to the input font file (ttf, otf, etc).
        size: Target pixel size at which the font will be rendered by default.
        index_in_file: index of the target font in the font file.
        density_scale: rasterizer oversampling to better render when
            the font scale is not 1. Not a miracle solution though,
            as it causes blurry inputs if the actual scale used
            during rendering is less than density_scale.
        align_to_pixel: For sharp fonts, will prevent blur by
            aligning font rendering to the pixel. The spacing
            between characters might appear slightly odd as
            a result, so don't enable when not needed.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        cdef imgui.ImFontAtlas *atlas = <imgui.ImFontAtlas*>self._atlas
        if self._built:
            raise ValueError("Cannot add Font to built FontTexture")
        if not(os.path.exists(path)):
            raise ValueError(f"File {path} does not exist")
        if size <= 0. or density_scale <= 0.:
            raise ValueError("Invalid texture size")
        cdef imgui.ImFontConfig config = imgui.ImFontConfig()
        # Unused with freetype
        #config.OversampleH = 3 if subpixel else 1
        #config.OversampleV = 3 if subpixel else 1
        #if not(subpixel):
        config.PixelSnapH = align_to_pixel
        config.OversampleH = 1
        config.OversampleV = 1
        with open(path, 'rb') as fp:
            font_data = fp.read()
        cdef const unsigned char[:] font_data_u8 = font_data
        config.SizePixels = size
        config.RasterizerDensity = density_scale
        config.FontNo = index_in_file
        config.FontDataOwnedByAtlas = False
        cdef imgui.ImFont *font = \
            atlas.AddFontFromMemoryTTF(<void*>&font_data_u8[0],
                                            font_data_u8.shape[0],
                                            size,
                                            &config,
                                            NULL)
        if font == NULL:
            raise ValueError(f"Failed to load target Font file {path}")
        cdef Font font_object = Font(self.context)
        font_object._container = self
        font_object._font = font
        self._fonts.append(font_object)

    def add_custom_font(self, GlyphSet glyph_set):
        """
        See fonts.py for a detailed explanation of
        the input arguments.

        Currently add_custom_font calls build()
        and thus prevents adding new fonts, but
        this might not be true in the future, thus
        you should still call build().
        """
        cdef imgui.ImFontAtlas *atlas = <imgui.ImFontAtlas*>self._atlas
        if self._built:
            raise ValueError("Cannot add Font to built FontTexture")

        cdef imgui.ImFontConfig config = imgui.ImFontConfig()
        config.SizePixels = glyph_set.height
        config.FontDataOwnedByAtlas = False
        config.OversampleH = 1
        config.OversampleV = 1
        config.GlyphRanges = minimal_font_range
        

        # Imgui currently requires a font
        # to be able to add custom glyphs
        cdef imgui.ImFont *font = \
            atlas.AddFontDefault(&config)

        keys = sorted(glyph_set.images.keys())
        cdef float x, y, advance
        cdef int32_t w, h, i, j
        for i, key in enumerate(keys):
            image = glyph_set.images[key]
            h = image.shape[0] + 1
            w = image.shape[1] + 1
            (y, x, advance) = glyph_set.positioning[key]
            j = atlas.AddCustomRectFontGlyph(font,
                                             int(key),
                                             w, h,
                                             advance,
                                             imgui.ImVec2(x, y))
            assert(j == i)

        cdef Font font_object = Font(self.context)
        font_object._container = self
        font_object._font = font
        self._fonts.append(font_object)

        atlas.Flags |= imgui.ImFontAtlasFlags_NoMouseCursors # SDL supports all cursors

        # build
        if not(atlas.Build()):
            raise RuntimeError("Failed to build target texture data")
        # Retrieve the target buffer
        cdef unsigned char *data = NULL
        cdef int width, height, bpp
        cdef bint use_color = False
        for image in glyph_set.images.values():
            if len(image.shape) == 2 and image.shape[2] > 1:
                if image.shape[2] != 4:
                    raise ValueError("Color data must be rgba (4 channels)")
                use_color = True
        if atlas.TexPixelsUseColors or use_color:
            atlas.GetTexDataAsRGBA32(&data, &width, &height, &bpp)
        else:
            atlas.GetTexDataAsAlpha8(&data, &width, &height, &bpp)

        # write our font characters at the target location
        cdef cython_array data_array = cython_array(shape=(height, width, bpp), itemsize=1, format='B', mode='c', allocate_buffer=False)
        data_array.data = <char*>data
        cdef imgui.ImFontAtlasCustomRect *rect
        cdef int32_t ym, yM, xm, xM
        cdef unsigned char[:,:,:] array_view = data_array
        cdef unsigned char[:,:,:] src_view
        for i, key in enumerate(keys):
            rect = atlas.GetCustomRectByIndex(i)
            ym = rect.Y
            yM = rect.Y + rect.Height
            xm = rect.X
            xM = rect.X + rect.Width
            src_view = glyph_set.images[key]
            array_view[ym:(yM-1), xm:(xM-1),:] = src_view[:,:,:]
            array_view[yM-1, xm:xM,:] = 0
            array_view[ym:yM, xM-1,:] = 0

        # Upload texture
        if use_color:
            self._texture._filtering_mode = 0 # rgba bilinear
        else:
            self._texture._filtering_mode = 2 # 111A bilinear
        self._texture.set_value(data_array.get_memview())
        assert(self._texture.allocated_texture != NULL)
        self._texture._readonly = True
        atlas.SetTexID(<imgui.ImTextureID>self._texture.allocated_texture)

        # Release temporary CPU memory
        atlas.ClearInputData()
        self._built = True

    @property
    def built(self):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._built

    @property
    def texture(self):
        """
        Readonly texture containing the font data.
        build() must be called first
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if not(self._built):
            raise ValueError("Texture not yet built")
        return self._texture

    def __len__(self):
        """The number of fonts in the texture"""
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if not(self._built):
            return 0
        cdef imgui.ImFontAtlas *atlas = <imgui.ImFontAtlas*>self._atlas
        return <int>atlas.Fonts.size()

    def __getitem__(self, index):
        """Get a built Font object by index"""
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if not(self._built):
            raise ValueError("Texture not yet built")
        cdef imgui.ImFontAtlas *atlas = <imgui.ImFontAtlas*>self._atlas
        if index < 0 or index >= <int>atlas.Fonts.size():
            raise IndexError("Outside range")
        return self._fonts[index]

    def build(self):
        """
        Packs all the fonts appended with add_font_file
        into a readonly texture. 
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if self._built:
            return
        cdef imgui.ImFontAtlas *atlas = <imgui.ImFontAtlas*>self._atlas
        if atlas.Fonts.Size == 0:
            raise ValueError("You must add fonts first")
        atlas.Flags |= imgui.ImFontAtlasFlags_NoMouseCursors # SDL supports all cursors
        # build
        if not(atlas.Build()):
            raise RuntimeError("Failed to build target texture data")
        # Retrieve the target buffer
        cdef unsigned char *data = NULL
        cdef int width, height, bpp
        if atlas.TexPixelsUseColors:
            atlas.GetTexDataAsRGBA32(&data, &width, &height, &bpp)
        else:
            atlas.GetTexDataAsAlpha8(&data, &width, &height, &bpp)

        # Upload texture
        cdef cython_array data_array = cython_array(shape=(height, width, bpp), itemsize=1, format='B', mode='c', allocate_buffer=False)
        data_array.data = <char*>data
        self._texture._filtering_mode = 2 # 111A bilinear
        self._texture.set_value(data_array.get_memview())
        assert(self._texture.allocated_texture != NULL)
        self._texture._readonly = True
        atlas.SetTexID(<imgui.ImTextureID>self._texture.allocated_texture)

        # Release temporary CPU memory
        atlas.ClearInputData()
        self._built = True

cdef class GlyphSet:
    """Container for font glyph data with convenient access methods"""

    def __init__(self, height: int, origin_y: int):
        """Initialize empty GlyphSet with specified dimensions
        
        Args:
            height: fixed vertical space reserved to render text.
                A good value would be the size needed to render
                all glyphs loaded with proper alignment,
                but in some cases some rarely used glyphs can be
                very large. Thus you might want to use only a subset
                of the glyphs to fit this space.
                All y coordinates (dy in add_glyph and origin_y),
                take as origin (y=0) the top of this reserved
                vertical space, and use a top down coordinate system.
            origin_y: Y coordinate of the baseline (bottom of 'A'
                character) from the top of the reserved vertical space
                (in a top down coordinate system).
        """
        if height <= 0:
            raise ValueError("height must be positive")
        if origin_y < 0 or origin_y >= height:
            raise ValueError("origin_y is expected to be within [0, height)")
            
        self.height = height
        self.origin_y = origin_y
        self.images = {}
        self.positioning = {}
        
    cpdef void add_glyph(self,
                         int32_t unicode_key, 
                         object image,
                         float dy,
                         float dx,
                         float advance):
        """insert a glyph into the set
        
        Args:
            unicode_key: UTF-8 code for the character
            image: Array containing glyph bitmap (h,w,c)
            dy: Y offset from cursor to glyph top (top down axis)
            dx: X offset from cursor to glyph left
            advance: Horizontal advance to next character
        """
        if not isinstance(unicode_key, int):
            raise TypeError("Unicode key must be an integer")

        cdef memoryview image_view
        try:
            image_view = memoryview(image)
        except:
            image_view = memoryview(parse_texture(image))
            
        if len(image_view.shape) < 2:
            raise ValueError("Image must have at least 2 dimensions")
            
        if image_view.format != 'B':
            raise TypeError("Image must be uint8")
            
        if advance < 0.:
            raise ValueError("Advance must be non-negative")
            
        # Calculate actual glyph height including offsets
        #glyph_height = image_view.shape[0] + abs(dy)
        #if glyph_height > self.height:
        #    raise ValueError(f"Glyph height {glyph_height} exceeds font height {self.height}")
            
        # Store the glyph data
        self.images[unicode_key] = image_view
        self.positioning[unicode_key] = (dy, dx, advance)

    def __getitem__(self, key):
        """Returns the information stored for a given
        character.
        The output Format is (image, dy, dx, advance)"""
        if isinstance(key, str):
            key = ord(key)
        if not(isinstance(key, int)):
            raise KeyError(f"Invalid key type for {key}")
        if key not in self.images:
            raise IndexError(f"{key} not found in {self}")
        image = self.images[key]
        (dy, dx, advance) = self.positioning[key]
        return (image, dy, dx, advance)

    def __iter__(self):
        """Iterate over all glyphs.

        Elements are of signature (unicode_key, image, dy, dx, advance)
        """
        result = []
        for key in self.images:
            image = self.images[key]
            (dy, dx, advance) = self.positioning[key]
            result.append((key, image, dy, dx, advance))
        return iter(result)

    def insert_padding(self, top=0, bottom=0, left=0, right=0) -> None:
        """
        Shift all characters from their top-left origin
        by adding empty areas.
        Note the character images are untouched. Only the positioning
        information and the reserved height may change.
        """
        character_positioning = self.positioning
        if top != 0:
            character_positioning_prev = character_positioning
            character_positioning = {}
            for (key, (dy, dx, advance)) in character_positioning_prev.items():
                character_positioning[key] = (dy + top, dx, advance)
            self.height += top
            self.origin_y += top
        if bottom != 0:
            self.height += bottom
        if left != 0:
            character_positioning_prev = character_positioning
            character_positioning = {}
            for (key, (dy, dx, advance)) in character_positioning_prev.items():
                character_positioning[key] = (dy, left+dx, advance)
        if right != 0:
            character_positioning_prev = character_positioning
            character_positioning = {}
            for (key, (dy, dx, advance)) in character_positioning_prev.items():
                character_positioning[key] = (dy, left, advance + right)
        self.positioning = character_positioning

    def fit_to_new_height(self, target_height) -> None:
        """
        Update the height, by inserting equal padding
        at the top and bottom.
        """
        # Center the font around the new height
        top_pad = round((target_height-self.height)/2)
        remaining_pad = target_height - self.height - top_pad
        self.insert_padding(top=top_pad, bottom=remaining_pad)

    def center_on_glyph(self, target_unicode=ord("B")) -> None:
        """
        Center the glyphs on the target glyph (B if not given).

        This function adds the relevant padding in needed to ensure
        when rendering in widgets the glyphs, the target character
        is properly centered.

        Inputs:
        -------
        target_unicode: unicode integer for the character on which we will center.
                        default is ord("B")
        """
        if isinstance(target_unicode, str):
            target_unicode = ord(target_unicode)
        if not(isinstance(target_unicode, int)):
            raise ValueError("target_unicode must be an int32_t (ord('B') for instance)")
        if target_unicode not in self.positioning:
            raise ValueError(f"target unicode character not found")

        (min_y, _, _) = self.positioning[target_unicode]
        max_y = self.origin_y
        current_center_y = self.height/2.
        target_center_y = (min_y+max_y)/2.
        # delta by which all coordinates must be shifted to center on the target
        delta = current_center_y - target_center_y
        # round to not introduce blur. round will round up y, which means
        # bottom visually
        delta = round(delta)
        if delta > 0:
            # we just shift everything down and increase height
            self.insert_padding(top=delta)
        elif delta < 0:
            # pad the bottom, thus just increase height
            self.insert_padding(bottom=delta)

    def remap(self,
              src_codes : list[int] | list[str],
              dst_codes: list[int] | list[str]) -> None:
        """
        Provide the set of dst_codes unicode codes by
        using the glyphs from src_codes
        """
        for (src_code, dst_code) in zip(src_codes, dst_codes):
            (image, dy, dx, advance) = self[src_code]
            if isinstance(dst_code, str):
                dst_code = ord(dst_code)
            self.add_glyph(dst_code, image, dy, dx, advance)

    @classmethod
    def fit_glyph_sets(cls, list[GlyphSet] glyphs) -> None:
        """
        Given list of GlyphSets, update the positioning
        information of the glyphs such that the glyphs of
        all sets take the same reserved height, and their
        baseline are aligned.

        This is only useful for merging GlyphSet in a single
        font, as else the text rendering should already handle
        this alignment.
        """
        # find extremum positioning
        # in a top-down coordinate system centered on the bottom of 'A'
        cdef GlyphSet g
        min_y = min([-g.origin_y for g in glyphs])
        #max_y = max([g.height-g.origin_y-1 for g in glyphs])
        new_target_origin = -min_y
        for g in glyphs:
            delta = new_target_origin-g.origin_y
            g.insert_padding(top=delta)
        common_height = max([g.height for g in glyphs])
        # height = max_y - min_y + 1
        for g in glyphs:
            g.height = common_height

    @classmethod
    def merge_glyph_sets(cls, list[GlyphSet] glyphs):
        """
        Merge together a list of GlyphSet-s into a single
        GlyphSet.

        The new GlyphSet essentially:
        - Homogeneizes the GlyphSets origins and vertical
            spacing by calling `fit_glyph_sets`
        - Merge the character codes. In case of character
            duplication, the first character seen takes
            priority.

        *WARNING* Since `fit_glyph_sets` is called, the original
        glyphsets are modified.

        Note:
        -----
        It is expected that the glyphs are already
        rendered at the proper size. No resizing is performed.
        The image data is not copied, just referenced.
        """
        cdef GlyphSet g
        GlyphSet.fit_glyph_sets(glyphs)
        cdef GlyphSet new_glyphset = GlyphSet(glyphs[0].height, glyphs[0].origin_y)
        cdef int32_t key
        cdef object image
        cdef float dy, dx, advance
        for g in glyphs:
            for key in g.images:
                if key in new_glyphset.images:
                    continue
                image = g.images[key]
                (dy, dx, advance) = g.positioning[key]
                new_glyphset.add_glyph(key, image, dy, dx, advance)
        return new_glyphset


cdef inline int32_t get_freetype_load_flags(str hinter, bint allow_color):
    """Prepare FreeType loading flags"""

    """
    Prepare rendering flags
    Available flags are:
    freetype.FT_LOAD_FLAGS["FT_LOAD_NO_BITMAP"]:
        When a font contains pre-rendered bitmaps,
        ignores them instead of using them when the
        requested size is a perfect match.
    freetype.FT_LOAD_FLAGS["FT_LOAD_NO_HINTING"]:
        Disables "hinting", which is an algorithm
        to improve the sharpness of fonts.
        Small sizes may render blurry with this flag.
    freetype.FT_LOAD_FLAGS["FT_LOAD_FORCE_AUTOHINT"]:
        Ignores the font encapsulated hinting, and
        replace it with a general one. Useful for fonts
        with non-optimized hinting.
    freetype.FT_LOAD_TARGETS["FT_LOAD_TARGET_NORMAL"]:
        Default font rendering with gray levels
    freetype.FT_LOAD_TARGETS["FT_LOAD_TARGET_LIGHT"]:
        Used with FT_LOAD_FORCE_AUTOHINT to use
        a variant of the general hinter that is less
        sharp, but respects more the original shape
        of the font.
    freetype.FT_LOAD_TARGETS["FT_LOAD_TARGET_MONO"]:
        The hinting is optimized to render monochrome
        targets (no blur/antialiasing).
        Should be set with
        freetype.FT_LOAD_TARGETS["FT_LOAD_MONOCHROME"].
    Other values exist but you'll likely not need them.
    """
    
    cdef int32_t load_flags = 0
    if hinter == "none":
        load_flags |= freetype.FT_LOAD_TARGETS["FT_LOAD_TARGET_NORMAL"]
        load_flags |= freetype.FT_LOAD_FLAGS["FT_LOAD_NO_HINTING"]
        load_flags |= freetype.FT_LOAD_FLAGS["FT_LOAD_NO_AUTOHINT"]
    elif hinter == "font":
        load_flags |= freetype.FT_LOAD_TARGETS["FT_LOAD_TARGET_NORMAL"]
    elif hinter == "light":
        load_flags |= freetype.FT_LOAD_TARGETS["FT_LOAD_TARGET_LIGHT"]
        load_flags |= freetype.FT_LOAD_FLAGS["FT_LOAD_FORCE_AUTOHINT"]
    elif hinter == "strong":
        load_flags |= freetype.FT_LOAD_TARGETS["FT_LOAD_TARGET_NORMAL"]
        load_flags |= freetype.FT_LOAD_FLAGS["FT_LOAD_FORCE_AUTOHINT"]
    elif hinter == "monochrome":
        load_flags |= freetype.FT_LOAD_TARGETS["FT_LOAD_TARGET_MONO"]
        load_flags |= freetype.FT_LOAD_FLAGS["FT_LOAD_MONOCHROME"]
    else:
        raise ValueError("Invalid hinter. Must be none, font, light, strong or monochrome")

    if allow_color:
        load_flags |= freetype.FT_LOAD_FLAGS["FT_LOAD_COLOR"]
        
    return load_flags

cdef class FontRenderer:
    """
    A class that manages font loading,
    glyph rendering and text rendering."""
    def __init__(self, path):
        if not os.path.exists(path):
            raise ValueError(f"Font file {path} not found")
        self._face = freetype.Face(path)
        if self._face is None:
            raise ValueError("Failed to open the font")

    def render_text_to_array(self, str text not None,
                             int target_size,
                             align_to_pixels=True,
                             enable_kerning=True,
                             str hinter="light",
                             allow_color=True) -> tuple[memoryview, int]:
        """Render text string to an array and return the array and bitmap_top"""
        self._face.set_pixel_sizes(0, <int>round(target_size))

        load_flags = get_freetype_load_flags(hinter, allow_color)

        # Calculate rough dimensions for initial buffer
        rough_width, rough_height, _, _ = self.estimate_text_dimensions(
            text, load_flags, align_to_pixels, enable_kerning
        )
        
        # Add margins to prevent overflow
        cdef int margin = target_size
        cdef int height = <int>ceil(rough_height) + 2 * margin
        cdef int width = <int>ceil(rough_width) + 2 * margin
        
        # Create output image array with margins
        image = cython_array(shape=(height, width, 4), itemsize=1, format='B', mode='c', allocate_buffer=True)
        
        # Track actual bounds with local variables
        cdef double min_x = INFINITY
        cdef double max_x = -INFINITY
        cdef double min_y = INFINITY
        cdef double max_y = -INFINITY
        cdef double max_top = -INFINITY
        
        # Render each character
        cdef double x_offset = margin
        cdef double y_offset = margin
        previous_char = None
        kerning_mode = freetype.FT_KERNING_DEFAULT if align_to_pixels else freetype.FT_KERNING_UNFITTED
        
        for char in text:
            self._face.load_char(char, flags=load_flags)
            glyph = self._face.glyph
            bitmap = glyph.bitmap
            
            if enable_kerning and previous_char is not None:
                kerning = self._face.get_kerning(previous_char, char, mode=kerning_mode)
                x_offset += kerning.x / 64.0

            # Update bounds
            min_x = min(min_x, x_offset)
            max_x = max(max_x, x_offset + bitmap.width)
            min_y = min(min_y, y_offset + bitmap.rows - glyph.bitmap_top)
            max_y = max(max_y, y_offset + bitmap.rows)
            max_top = max(max_top, glyph.bitmap_top)

            self._render_glyph_to_image(glyph, image, x_offset, y_offset, align_to_pixels)

            if align_to_pixels:
                x_offset += round(glyph.advance.x/64)
            else:
                x_offset += glyph.linearHoriAdvance/65536
            previous_char = char

        # Handle empty text
        if min_x == INFINITY:
            return cython_array(shape=(1, 1, 4), itemsize=1, format='B', mode='c', allocate_buffer=True), 0

        # Crop to actual content plus small margin
        cdef int crop_margin = 2
        cdef int crop_x1 = max(<int>min_x - crop_margin, 0)
        cdef int crop_y1 = max(<int>min_y - crop_margin, 0)
        cdef int crop_x2 = min(<int>(ceil(max_x)) + crop_margin, width)
        cdef int crop_y2 = min(<int>(ceil(max_y)) + crop_margin, height)

        return image[crop_y1:crop_y2, crop_x1:crop_x2], max_top

    def estimate_text_dimensions(self, text: str, load_flags : int, align_to_pixels: bool, enable_kerning: bool):
        """Calculate the dimensions needed for the text"""
        width, max_top, max_bottom = 0, 0, 0
        previous_char = None
        kerning_mode = freetype.FT_KERNING_DEFAULT if align_to_pixels else freetype.FT_KERNING_UNFITTED
        
        for char in text:
            self._face.load_char(char, flags=load_flags)
            glyph = self._face.glyph
            bitmap = glyph.bitmap
            top = glyph.bitmap_top
            bottom = bitmap.rows - top
            max_top = max(max_top, top)
            max_bottom = max(max_bottom, bottom)
            
            if align_to_pixels:
                width += glyph.advance.x/64
            else:
                width += glyph.linearHoriAdvance/65536
                
            if enable_kerning and previous_char is not None:
                kerning = self._face.get_kerning(previous_char, char, mode=kerning_mode)
                width += kerning.x / 64.0
            previous_char = char
            
        return width, max_top + max_bottom, max_top, max_bottom

    cdef void _render_glyph_to_image(self, glyph, unsigned char[:,:,::1] image, double x_offset, double y_offset, bint align_to_pixels):
        """Render a single glyph to the image array"""
        if glyph.format == freetype.FT_GLYPH_FORMAT_BITMAP:
            bitmap = glyph.bitmap
            self._copy_bitmap_to_image(bitmap, image, x_offset, y_offset)
        else:
            # Handle non-bitmap glyphs
            if not align_to_pixels:
                subpixel_offset = freetype.FT_Vector(
                    int((x_offset - float(int(x_offset))) * 64), 0
                )
                gglyph = glyph.get_glyph()
                bglyph = gglyph.to_bitmap(freetype.FT_RENDER_MODE_NORMAL, subpixel_offset, True)
                self._copy_bitmap_to_image(bglyph.bitmap, image, x_offset, y_offset)

    cdef void _copy_bitmap_to_image(self, bitmap, unsigned char[:,:,::1] image, double x_offset, double y_offset):
        """Copy bitmap data to the image array"""
        cdef int x, y
        cdef int i_x_offset = <int>x_offset
        cdef int i_y_offset = <int>y_offset
        cdef unsigned char* buffer_ptr = <unsigned char*>bitmap.buffer
        cdef int num_rows = bitmap.rows
        cdef int num_cols = bitmap.width
        cdef int pitch = bitmap.pitch

        for y in range(num_rows):
            for x in range(num_cols):
                if bitmap.pixel_mode == freetype.FT_PIXEL_MODE_GRAY:
                    image[y + i_y_offset, i_x_offset + x, 3] = buffer_ptr[y * pitch + x]
                elif bitmap.pixel_mode == freetype.FT_PIXEL_MODE_BGRA:
                    image[y + i_y_offset, i_x_offset + x, 0] = buffer_ptr[y * pitch + x * 4 + 2]  # R
                    image[y + i_y_offset, i_x_offset + x, 1] = buffer_ptr[y * pitch + x * 4 + 1]  # G 
                    image[y + i_y_offset, i_x_offset + x, 2] = buffer_ptr[y * pitch + x * 4]      # B
                    image[y + i_y_offset, i_x_offset + x, 3] = buffer_ptr[y * pitch + x * 4 + 3]  # A

    cpdef GlyphSet render_glyph_set(self,
                                    target_pixel_height=None,
                                    target_size=0,
                                    str hinter="light",
                                    restrict_to=None,
                                    allow_color=True):
        """
        Render the glyphs of the font at the target scale,
        in order to them load them in a Font object.

        Inputs:
        -------
        target_pixel_height: if set, scale the characters to match
            this height in pixels. The height here, refers to the
            distance between the maximum top of a character,
            and the minimum bottom of the character, when properly
            aligned.
        target_size: if set, scale the characters to match the
            font 'size' by scaling the pixel size at the 'nominal'
            value (default size of the font).
        hinter: "font", "none", "light", "strong" or "monochrome".
            The hinter is the rendering algorithm that
            impacts a lot the aspect of the characters,
            especially at low scales, to make them
            more readable. "none" will simply render
            at the target scale without any specific technique.
            "font" will use the font guidelines, but the result
            will depend on the quality of these guidelines.
            "light" will try to render sharp characters, while
            attempting to preserve the original shapes.
            "strong" attemps to render very sharp characters,
            even if the shape may be altered.
            "monochrome" will render extremely sharp characters,
            using only black and white pixels.
        restrict_to: set of ints that contains the unicode characters
            that should be loaded. If None, load all the characters
            available.
        allow_color: If the font contains colored glyphs, this enables
            to render them in color.

        Outputs:
        --------
        GlyphSet object containing the rendered characters.

        """

        # Indicate the target scale
        if target_pixel_height is not None:
            assert(False)# TODO
            #req = freetype.raw.FT_Size_Re
            #freetype.raw.FT_Request_Size(face, req)
        else:
            self._face.set_pixel_sizes(0, int(round(target_size)))

        load_flags = get_freetype_load_flags(hinter, allow_color)

        # Track max dimensions while loading glyphs
        max_bitmap_top = 0
        max_bitmap_bot = 0

        cdef const unsigned char* buffer_view
        cdef unsigned char[:,::1] image_view
        cdef unsigned char[:,:,::1] color_image_view
        cdef int32_t rows, cols, pitch, i, j, idx
        cdef uintptr_t buffer_ptr
        
        # First pass - collect all glyphs and find dimensions
        glyphs_data = []  # Store temporary glyph data
        for unicode_key, glyph_index in self._face.get_chars():
            if (restrict_to is not None) and (unicode_key not in restrict_to):
                continue
                
            # Render at target scale
            self._face.load_glyph(glyph_index, flags=load_flags)
            glyph : freetype.GlyphSlot = self._face.glyph
            
            # Apply appropriate rendering mode
            if hinter == "monochrome":
                glyph.render(freetype.FT_RENDER_MODES["FT_RENDER_MODE_MONO"])
            elif hinter == "light":
                glyph.render(freetype.FT_RENDER_MODES["FT_RENDER_MODE_LIGHT"])
            else:
                glyph.render(freetype.FT_RENDER_MODES["FT_RENDER_MODE_NORMAL"])

            bitmap : freetype.Bitmap = glyph.bitmap
            metric : freetype.FT_Glyph_Metrics = glyph.metrics
            rows = bitmap.rows
            cols = bitmap.width
            pitch = bitmap.pitch

            # Calculate advance (positioning relative to the next glyph)

            # lsb is the subpixel offset of our origin compared to the previous advance
            # rsb is the subpixel offset of the next origin compared to our origin
            # horiadvance is the horizontal displacement between
            # our origin and the next one
            # Currently the backend does not support rounding the advance when rendering
            # the font (which would enable best support for lsb and rsb), thus we pre-round.
            advance = (glyph._FT_GlyphSlot.contents.lsb_delta - 
                      glyph._FT_GlyphSlot.contents.rsb_delta + 
                      metric.horiAdvance) / 64.
            advance = round(advance)
            
            bitmap_top = glyph.bitmap_top
            bitmap_left = glyph.bitmap_left

            # Create image array based on bitmap mode
            if rows == 0 or cols == 0:
                # Handle empty bitmap (space character for instance)
                image = cython_array(shape=(1, 1, 1), itemsize=1, format='B', mode='c', allocate_buffer=True)
                bitmap_top = 0
                bitmap_left = 0
            elif bitmap.pixel_mode == freetype.FT_PIXEL_MODE_MONO:
                #image = 255*np.unpackbits(np.array(bitmap.buffer, dtype=np.uint8), 
                #                        count=bitmap.rows * 8*bitmap.pitch).reshape([bitmap.rows, 8*bitmap.pitch])
                #image = image[:, :bitmap.width, np.newaxis]
                buffer_ptr = <uintptr_t>ctypes.addressof(bitmap._FT_Bitmap.buffer.contents)
                buffer_view = <unsigned char*>buffer_ptr
                image = cython_array(shape=(rows, cols, 1), itemsize=1, format='B', mode='c', allocate_buffer=True)
                image_view = image[:,:,0]
        
                # Unpack bits
                for i in range(rows):
                    for j in range(cols):
                        image_view[i,j] = 255 if (buffer_view[i * pitch + (j >> 3)] & (1 << (7 - (j & 7)))) else 0
            elif bitmap.pixel_mode == freetype.FT_PIXEL_MODE_GRAY:
                #image = np.array(bitmap.buffer, dtype=np.uint8).reshape([bitmap.rows, bitmap.pitch])
                #image = image[:, :bitmap.width, np.newaxis]
                buffer_ptr = <uintptr_t>ctypes.addressof(bitmap._FT_Bitmap.buffer.contents)
                buffer_view = <unsigned char*>buffer_ptr
                image = cython_array(shape=(rows, cols, 1), itemsize=1, format='B', mode='c', allocate_buffer=True)
                image_view = image[:,:,0]
        
                for i in range(rows):
                    for j in range(cols):
                        image_view[i,j] = buffer_view[i * pitch + j]
            elif bitmap.pixel_mode == freetype.FT_PIXEL_MODE_BGRA:
                #image = np.array(bitmap.buffer, dtype=np.uint8).reshape([bitmap.rows, bitmap.pitch//4, 4])
                #image = image[:, :bitmap.width, :]
                #image[:, :, [0, 2]] = image[:, :, [2, 0]]  # swap B and R
                buffer_ptr = <uintptr_t>ctypes.addressof(bitmap._FT_Bitmap.buffer.contents)
                buffer_view = <unsigned char*>buffer_ptr
                image = cython_array(shape=(rows, cols, 4), itemsize=1, format='B', mode='c', allocate_buffer=True)
                color_image_view = image
                # Copy and swap R/B channels directly
                for i in range(rows):
                    for j in range(cols):
                        idx = i * pitch + j * 4
                        color_image_view[i,j,0] = buffer_view[idx + 2]  # R
                        color_image_view[i,j,1] = buffer_view[idx + 1]  # G
                        color_image_view[i,j,2] = buffer_view[idx]      # B
                        color_image_view[i,j,3] = buffer_view[idx + 3]  # A
            else:
                continue  # Skip unsupported bitmap modes

            # Update max dimensions
            max_bitmap_top = max(max_bitmap_top, bitmap_top)
            max_bitmap_bot = max(max_bitmap_bot, image.shape[0] - bitmap_top)
            
            # Store glyph data for second pass
            glyphs_data.append((unicode_key, image, bitmap_top, bitmap_left, advance))

        # Calculate final dimensions
        height = max_bitmap_top + max_bitmap_bot + 1
        target_origin_y = max_bitmap_top

        # Create GlyphSet with calculated dimensions
        glyph_set = GlyphSet(height, target_origin_y)

        # Second pass - add glyphs with correct positioning
        for unicode_key, image, bitmap_top, bitmap_left, advance in glyphs_data:
            dy = target_origin_y - bitmap_top  # Convert to top-down coordinate system
            glyph_set.add_glyph(unicode_key, image, dy, bitmap_left, advance)

        return glyph_set

A_int = ord('A')
Z_int = ord('Z')
a_int = ord('a')
z_int = ord('z')
zero_int = ord('0')
nine_int = ord('9')

A_bold = ord("\U0001D400")
a_bold = ord("\U0001D41A")

A_italic = ord("\U0001D434")
a_italic = ord("\U0001D44E")

A_bitalic = ord("\U0001D468")
a_bitalic = ord("\U0001D482")

def make_chr_italic(c: str) -> str:
    """
    Convert a single character to its italic version
    using the mathematical italic character encodings.
    """
    code = ord(c)
    if code >= A_int and code <= Z_int:
        code = code - A_int + A_italic
    elif code >= a_int and code <= z_int:
        code = code - a_int + a_italic
    return chr(code)

def make_chr_bold(c: str) -> str:
    """
    Convert a single character to its bold version
    using the mathematical bold character encodings.
    """
    code = ord(c)
    if code >= A_int and code <= Z_int:
        code = code - A_int + A_bold
    elif code >= a_int and code <= z_int:
        code = code - a_int + a_bold
    return chr(code)

def make_chr_bold_italic(c: str) -> str:
    """
    Convert a single character to its bold-italic version
    using the mathematical bold-italic character encodings.
    """
    code = ord(c)
    if code >= A_int and code <= Z_int:
        code = code - A_int + A_bitalic
    elif code >= a_int and code <= z_int:
        code = code - a_int + a_bitalic
    return chr(code)

def make_italic(text: str) -> str:
    """
    Helper to convert a string into
    its italic version using the mathematical
    italic character encodings.
    """
    return "".join([make_chr_italic(c) for c in text])

def make_bold(text: str) -> str:
    """
    Helper to convert a string into
    its bold version using the mathematical
    bold character encodings.
    """
    return "".join([make_chr_bold(c) for c in text])

def make_bold_italic(text: str) -> str:
    """
    Helper to convert a string into
    its bold-italic version using the mathematical
    bold-italic character encodings.
    """
    return "".join([make_chr_bold_italic(c) for c in text])


# Replace make_extended_latin_font implementation with:
def make_extended_latin_font(size: int,
                             main_font_path: str | None = None,
                             italic_font_path: str | None = None, 
                             bold_font_path: str | None = None,
                             bold_italic_path: str | None = None,
                             **kwargs) -> GlyphSet:
    """Create an extended latin font with bold/italic variants for the target size"""

    # Use default font paths if not specified
    if main_font_path is None:
        root_dir = os.path.dirname(__file__)
        main_font_path = os.path.join(root_dir, 'lmsans17-regular.otf')
    if italic_font_path is None:
        root_dir = os.path.dirname(__file__)
        italic_font_path = os.path.join(root_dir, 'lmromanslant17-regular.otf')
    if bold_font_path is None:
        root_dir = os.path.dirname(__file__)
        bold_font_path = os.path.join(root_dir, 'lmsans10-bold.otf')
    if bold_italic_path is None:
        root_dir = os.path.dirname(__file__)
        bold_italic_path = os.path.join(root_dir, 'lmromandemi10-oblique.otf')

    # Prepare font configurations
    restricted_latin = [ord(c) for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"]
    main_restrict = kwargs.pop("restrict_to", set(range(0, 256)))

    def make_bold_map(key):
        if key < a_int:
            return key - A_int + A_bold
        return key - a_int + a_bold

    def make_italic_map(key):
        if key < a_int:
            return key - A_int + A_italic  
        return key - a_int + a_italic

    def make_bold_italic_map(key):
        if key < a_int:
            return key - A_int + A_bitalic
        return key - a_int + a_bitalic

    main = FontRenderer(main_font_path).render_glyph_set(target_size=size, restrict_to=main_restrict, **kwargs)
    bold = FontRenderer(main_font_path).render_glyph_set(target_size=size, restrict_to=restricted_latin, **kwargs)
    bold_italic = FontRenderer(bold_italic_path).render_glyph_set(target_size=size, restrict_to=restricted_latin, **kwargs)
    italic = FontRenderer(italic_font_path).render_glyph_set(target_size=size, restrict_to=restricted_latin, **kwargs)

    bold.remap(restricted_latin,
               [make_bold_map(c) for c in restricted_latin])
    bold_italic.remap(restricted_latin,
                      [make_bold_italic_map(c) for c in restricted_latin])
    italic.remap(restricted_latin,
                 [make_italic_map(c) for c in restricted_latin])
    merged = GlyphSet.merge_glyph_sets([main, bold, bold_italic, italic])
    merged.center_on_glyph("B")
    return merged



