from libcpp.deque cimport deque
from libcpp.vector cimport vector
from cpython.ref cimport PyObject
from .types cimport *
from .core cimport baseItem, baseFont, Texture

cdef class Font(baseFont):
    cdef void* _font # imgui.ImFont*
    cdef FontTexture _container
    cdef bint _dpi_scaling
    cdef float _scale
    cdef vector[float] _scales_backup
    cdef void push(self) noexcept nogil
    cdef void pop(self) noexcept nogil

cdef class FontMultiScales(baseFont):
    cdef vector[PyObject*] _fonts # type Font
    cdef deque[float] _stored_scales # Store last 10 scales
    cdef vector[PyObject*] _callbacks # type Callback
    cdef vector[PyObject*] _applied_fonts # type Font
    cdef void push(self) noexcept nogil
    cdef void pop(self) noexcept nogil

cdef class AutoFont(FontMultiScales):
    cdef str _main_font_path
    cdef str _italic_font_path
    cdef str _bold_font_path 
    cdef str _bold_italic_path
    cdef dict _kwargs
    cdef float _base_size
    cdef object _font_creation_executor  # ThreadPoolExecutor
    cdef set _pending_fonts  # set of scales being created
    cdef object _font_creator  # Callable that creates fonts
    cpdef void _create_font_at_scale(self, float scale, bint no_fail)
    cdef void _add_new_font_to_list(self, Font font)

cdef class FontTexture(baseItem):
    """
    Packs one or several fonts into
    a texture for internal use by ImGui.
    """
    cdef void* _atlas # imgui.ImFontAtlas *
    cdef Texture _texture
    cdef bint _built
    cdef list _fonts_files # content of the font files
    cdef list _fonts

cdef class GlyphSet:
    cdef readonly int height
    cdef readonly dict images
    cdef readonly dict positioning
    cdef readonly int origin_y
    cpdef void add_glyph(self,
                         int unicode_key, 
                         object image,
                         float dy,
                         float dx,
                         float advance)

cdef class FontRenderer:
    cdef object _face
    cpdef GlyphSet render_glyph_set(self,
                                    target_pixel_height=?,
                                    target_size=?,
                                    str hinter=?,
                                    restrict_to=?,
                                    allow_color=?)