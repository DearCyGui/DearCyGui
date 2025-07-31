# Generated with for i in freetype/*; do pxdgen $i -x c++ -f defines -f includerefs -f includerefs -f importall ; done;
# then cleaned up manually



cdef extern from "freetype/fttypes.h":
    const int FT_MAKE_TAG(...)
    const int FT_IS_EMPTY(...)
    const int FT_BOOL(...)
    const int FT_ERR_XCAT(...)
    const int FT_ERR_CAT(...)
    const int FT_ERR(...)
    const int FT_ERROR_BASE(...)
    const int FT_ERROR_MODULE(...)
    const int FT_ERR_EQ(...)
    const int FT_ERR_NEQ(...)
    ctypedef int FT_Bool
    ctypedef short FT_FWord
    ctypedef unsigned short FT_UFWord
    ctypedef signed char FT_Char
    ctypedef unsigned char FT_Byte
    ctypedef FT_Byte* FT_Bytes
    ctypedef int FT_Tag
    ctypedef char FT_String
    ctypedef short FT_Short
    ctypedef unsigned short FT_UShort
    ctypedef int FT_Int
    ctypedef unsigned int FT_UInt
    ctypedef long FT_Long
    ctypedef unsigned long FT_ULong
    ctypedef int FT_Int32
    ctypedef short FT_F2Dot14
    ctypedef long FT_F26Dot6
    ctypedef long FT_Fixed
    ctypedef int FT_Error
    ctypedef void* FT_Pointer
    ctypedef int FT_Offset
    ctypedef int FT_PtrDist
    struct FT_UnitVector_:
        FT_F2Dot14 x
        FT_F2Dot14 y
    ctypedef FT_UnitVector_ FT_UnitVector
    struct FT_Matrix_:
        FT_Fixed xx
        FT_Fixed xy
        FT_Fixed yx
        FT_Fixed yy
    ctypedef FT_Matrix_ FT_Matrix
    struct FT_Data_:
        FT_Byte* pointer
        FT_UInt length
    ctypedef FT_Data_ FT_Data
    ctypedef void (*FT_Generic_Finalizer)(void*)
    struct FT_Generic_:
        void* data
        FT_Generic_Finalizer finalizer
    ctypedef FT_Generic_ FT_Generic
    ctypedef FT_ListNodeRec_* FT_ListNode
    ctypedef FT_ListRec_* FT_List
    struct FT_ListNodeRec_:
        FT_ListNode prev
        FT_ListNode next
        void* data
    ctypedef FT_ListNodeRec_ FT_ListNodeRec
    struct FT_ListRec_:
        FT_ListNode head
        FT_ListNode tail
    ctypedef FT_ListRec_ FT_ListRec

cdef extern from "freetype/ftadvanc.h":
    const int FT_ADVANCE_FLAG_FAST_ONLY


cdef extern from "freetype/ftbdf.h":
    enum BDF_PropertyType_:
        BDF_PROPERTY_TYPE_NONE = 0
        BDF_PROPERTY_TYPE_ATOM = 1
        BDF_PROPERTY_TYPE_INTEGER = 2
        BDF_PROPERTY_TYPE_CARDINAL = 3
    ctypedef int BDF_PropertyType
    ctypedef BDF_PropertyRec_* BDF_Property
    union pxdgen_anon_BDF_PropertyRec__0:
        const char* atom
        int integer
        int cardinal
    struct BDF_PropertyRec_:
        BDF_PropertyType type
        pxdgen_anon_BDF_PropertyRec__0 u
    ctypedef BDF_PropertyRec_ BDF_PropertyRec

cdef extern from "freetype/ftcache.h":
    struct FTC_ManagerRec_:
        pass
    struct FTC_CMapCacheRec_:
        pass
    struct FTC_ImageCacheRec_:
        pass
    struct FTC_NodeRec_:
        pass
    struct FTC_SBitCacheRec_:
        pass
    const int FTC_IMAGE_TYPE_COMPARE(...)
    ctypedef int (*FTC_Face_Requester)(int, int, FT_Pointer, int*)
    ctypedef FTC_ManagerRec_* FTC_Manager
    ctypedef FTC_NodeRec_* FTC_Node
    struct FTC_ScalerRec_:
        int face_id
        int width
        int height
        int pixel
        int x_res
        int y_res
    ctypedef FTC_ScalerRec_ FTC_ScalerRec
    ctypedef FTC_ScalerRec_* FTC_Scaler
    ctypedef FTC_CMapCacheRec_* FTC_CMapCache
    struct FTC_ImageTypeRec_:
        int face_id
        int width
        int height
        int flags
    ctypedef FTC_ImageTypeRec_ FTC_ImageTypeRec
    ctypedef FTC_ImageTypeRec_* FTC_ImageType
    ctypedef FTC_ImageCacheRec_* FTC_ImageCache
    ctypedef FTC_SBitRec_* FTC_SBit
    struct FTC_SBitRec_:
        int width
        int height
        int left
        int top
        int format
        int max_grays
        int pitch
        int xadvance
        int yadvance
        int* buffer
    ctypedef FTC_SBitRec_ FTC_SBitRec
    ctypedef FTC_SBitCacheRec_* FTC_SBitCache


cdef extern from "freetype/ftcolor.h":
    const unsigned long FT_PALETTE_FOR_LIGHT_BACKGROUND = 0x01
    const unsigned long FT_PALETTE_FOR_DARK_BACKGROUND = 0x02
    struct FT_Color_:
        int blue
        int green
        int red
        int alpha
    ctypedef int FT_Color
    struct FT_Palette_Data_:
        int num_palettes
        const int* palette_name_ids
        const int* palette_flags
        int num_palette_entries
        const int* palette_entry_name_ids
    ctypedef FT_Palette_Data_ FT_Palette_Data
    struct FT_LayerIterator_:
        int num_layers
        int layer
        int* p
    ctypedef FT_LayerIterator_ FT_LayerIterator
    enum FT_PaintFormat_:
        FT_COLR_PAINTFORMAT_COLR_LAYERS = 1
        FT_COLR_PAINTFORMAT_SOLID = 2
        FT_COLR_PAINTFORMAT_LINEAR_GRADIENT = 4
        FT_COLR_PAINTFORMAT_RADIAL_GRADIENT = 6
        FT_COLR_PAINTFORMAT_SWEEP_GRADIENT = 8
        FT_COLR_PAINTFORMAT_GLYPH = 10
        FT_COLR_PAINTFORMAT_COLR_GLYPH = 11
        FT_COLR_PAINTFORMAT_TRANSFORM = 12
        FT_COLR_PAINTFORMAT_TRANSLATE = 14
        FT_COLR_PAINTFORMAT_SCALE = 16
        FT_COLR_PAINTFORMAT_ROTATE = 24
        FT_COLR_PAINTFORMAT_SKEW = 28
        FT_COLR_PAINTFORMAT_COMPOSITE = 32
        FT_COLR_PAINT_FORMAT_MAX = 33
        FT_COLR_PAINTFORMAT_UNSUPPORTED = 255
    ctypedef FT_PaintFormat_ FT_PaintFormat
    struct FT_ColorStopIterator_:
        int num_color_stops
        int current_color_stop
        int* p
        int read_variable
    ctypedef FT_ColorStopIterator_ FT_ColorStopIterator
    struct FT_ColorIndex_:
        int palette_index
        int alpha
    ctypedef FT_ColorIndex_ FT_ColorIndex
    struct FT_ColorStop_:
        int stop_offset
        FT_ColorIndex color
    ctypedef FT_ColorStop_ FT_ColorStop
    enum FT_PaintExtend_:
        FT_COLR_PAINT_EXTEND_PAD = 0
        FT_COLR_PAINT_EXTEND_REPEAT = 1
        FT_COLR_PAINT_EXTEND_REFLECT = 2
    ctypedef FT_PaintExtend_ FT_PaintExtend
    struct FT_ColorLine_:
        FT_PaintExtend extend
        FT_ColorStopIterator color_stop_iterator
    ctypedef FT_ColorLine_ FT_ColorLine
    struct FT_Affine_23_:
        int xx
        int xy
        int dx
        int yx
        int yy
        int dy
    ctypedef FT_Affine_23_ FT_Affine23
    enum FT_Composite_Mode_:
        FT_COLR_COMPOSITE_CLEAR = 0
        FT_COLR_COMPOSITE_SRC = 1
        FT_COLR_COMPOSITE_DEST = 2
        FT_COLR_COMPOSITE_SRC_OVER = 3
        FT_COLR_COMPOSITE_DEST_OVER = 4
        FT_COLR_COMPOSITE_SRC_IN = 5
        FT_COLR_COMPOSITE_DEST_IN = 6
        FT_COLR_COMPOSITE_SRC_OUT = 7
        FT_COLR_COMPOSITE_DEST_OUT = 8
        FT_COLR_COMPOSITE_SRC_ATOP = 9
        FT_COLR_COMPOSITE_DEST_ATOP = 10
        FT_COLR_COMPOSITE_XOR = 11
        FT_COLR_COMPOSITE_PLUS = 12
        FT_COLR_COMPOSITE_SCREEN = 13
        FT_COLR_COMPOSITE_OVERLAY = 14
        FT_COLR_COMPOSITE_DARKEN = 15
        FT_COLR_COMPOSITE_LIGHTEN = 16
        FT_COLR_COMPOSITE_COLOR_DODGE = 17
        FT_COLR_COMPOSITE_COLOR_BURN = 18
        FT_COLR_COMPOSITE_HARD_LIGHT = 19
        FT_COLR_COMPOSITE_SOFT_LIGHT = 20
        FT_COLR_COMPOSITE_DIFFERENCE = 21
        FT_COLR_COMPOSITE_EXCLUSION = 22
        FT_COLR_COMPOSITE_MULTIPLY = 23
        FT_COLR_COMPOSITE_HSL_HUE = 24
        FT_COLR_COMPOSITE_HSL_SATURATION = 25
        FT_COLR_COMPOSITE_HSL_COLOR = 26
        FT_COLR_COMPOSITE_HSL_LUMINOSITY = 27
        FT_COLR_COMPOSITE_MAX = 28
    ctypedef FT_Composite_Mode_ FT_Composite_Mode
    struct FT_Opaque_Paint_:
        int* p
        int insert_root_transform
    ctypedef FT_Opaque_Paint_ FT_OpaquePaint
    struct FT_PaintColrLayers_:
        FT_LayerIterator layer_iterator
    ctypedef FT_PaintColrLayers_ FT_PaintColrLayers
    struct FT_PaintSolid_:
        FT_ColorIndex color
    ctypedef FT_PaintSolid_ FT_PaintSolid
    struct FT_PaintLinearGradient_:
        FT_ColorLine colorline
        int p0
        int p1
        int p2
    ctypedef FT_PaintLinearGradient_ FT_PaintLinearGradient
    struct FT_PaintRadialGradient_:
        FT_ColorLine colorline
        int c0
        int r0
        int c1
        int r1
    ctypedef FT_PaintRadialGradient_ FT_PaintRadialGradient
    struct FT_PaintSweepGradient_:
        FT_ColorLine colorline
        int center
        int start_angle
        int end_angle
    ctypedef FT_PaintSweepGradient_ FT_PaintSweepGradient
    struct FT_PaintGlyph_:
        FT_OpaquePaint paint
        int glyphID
    ctypedef FT_PaintGlyph_ FT_PaintGlyph
    struct FT_PaintColrGlyph_:
        int glyphID
    ctypedef FT_PaintColrGlyph_ FT_PaintColrGlyph
    struct FT_PaintTransform_:
        FT_OpaquePaint paint
        FT_Affine23 affine
    ctypedef FT_PaintTransform_ FT_PaintTransform
    struct FT_PaintTranslate_:
        FT_OpaquePaint paint
        int dx
        int dy
    ctypedef FT_PaintTranslate_ FT_PaintTranslate
    struct FT_PaintScale_:
        FT_OpaquePaint paint
        int scale_x
        int scale_y
        int center_x
        int center_y
    ctypedef FT_PaintScale_ FT_PaintScale
    struct FT_PaintRotate_:
        FT_OpaquePaint paint
        int angle
        int center_x
        int center_y
    ctypedef FT_PaintRotate_ FT_PaintRotate
    struct FT_PaintSkew_:
        FT_OpaquePaint paint
        int x_skew_angle
        int y_skew_angle
        int center_x
        int center_y
    ctypedef FT_PaintSkew_ FT_PaintSkew
    struct FT_PaintComposite_:
        FT_OpaquePaint source_paint
        FT_Composite_Mode composite_mode
        FT_OpaquePaint backdrop_paint
    ctypedef FT_PaintComposite_ FT_PaintComposite
    union pxdgen_anon_FT_COLR_Paint__0:
        FT_PaintColrLayers colr_layers
        FT_PaintGlyph glyph
        FT_PaintSolid solid
        FT_PaintLinearGradient linear_gradient
        FT_PaintRadialGradient radial_gradient
        FT_PaintSweepGradient sweep_gradient
        FT_PaintTransform transform
        FT_PaintTranslate translate
        FT_PaintScale scale
        FT_PaintRotate rotate
        FT_PaintSkew skew
        FT_PaintComposite composite
        FT_PaintColrGlyph colr_glyph
    struct FT_COLR_Paint_:
        FT_PaintFormat format
        pxdgen_anon_FT_COLR_Paint__0 u
    ctypedef FT_COLR_Paint_ FT_COLR_Paint
    enum FT_Color_Root_Transform_:
        FT_COLOR_INCLUDE_ROOT_TRANSFORM = 0
        FT_COLOR_NO_ROOT_TRANSFORM = 1
        FT_COLOR_ROOT_TRANSFORM_MAX = 2
    ctypedef FT_Color_Root_Transform_ FT_Color_Root_Transform
    struct FT_ClipBox_:
        int bottom_left
        int top_left
        int top_right
        int bottom_right
    ctypedef FT_ClipBox_ FT_ClipBox


cdef extern from "freetype/ftdriver.h":
    const int FTDRIVER_H_
    const long FT_HINTING_FREETYPE = 0
    const long FT_HINTING_ADOBE = 1
    const int FT_CFF_HINTING_FREETYPE
    const int FT_CFF_HINTING_ADOBE
    const long TT_INTERPRETER_VERSION_35 = 35
    const long TT_INTERPRETER_VERSION_38 = 38
    const long TT_INTERPRETER_VERSION_40 = 40
    const long FT_AUTOHINTER_SCRIPT_NONE = 0
    const long FT_AUTOHINTER_SCRIPT_LATIN = 1
    const long FT_AUTOHINTER_SCRIPT_CJK = 2
    const long FT_AUTOHINTER_SCRIPT_INDIC = 3
    struct FT_Prop_GlyphToScriptMap_:
        int face
        int* map
    ctypedef int FT_Prop_GlyphToScriptMap
    struct FT_Prop_IncreaseXHeight_:
        int face
        int limit
    ctypedef FT_Prop_IncreaseXHeight_ FT_Prop_IncreaseXHeight


cdef extern from "freetype/fterrors.h":
    const int FT_ERR_PREFIX
    const long FT_ERR_BASE = 0
    const int FT_INCLUDE_ERR_PROTOS
    const int FT_ERRORDEF
    const int FT_ERROR_START_LIST
    const int FT_ERROR_END_LIST
    const int FT_ERR_PROTOS_DEFINED


cdef extern from "freetype/ftgasp.h":
    const long FT_GASP_NO_TABLE = -1
    const unsigned long FT_GASP_DO_GRIDFIT = 0x01
    const unsigned long FT_GASP_DO_GRAY = 0x02
    const unsigned long FT_GASP_SYMMETRIC_GRIDFIT = 0x04
    const unsigned long FT_GASP_SYMMETRIC_SMOOTHING = 0x08




cdef extern from "freetype/ftgxval.h":
    const long FT_VALIDATE_feat_INDEX = 0
    const long FT_VALIDATE_mort_INDEX = 1
    const long FT_VALIDATE_morx_INDEX = 2
    const long FT_VALIDATE_bsln_INDEX = 3
    const long FT_VALIDATE_just_INDEX = 4
    const long FT_VALIDATE_kern_INDEX = 5
    const long FT_VALIDATE_opbd_INDEX = 6
    const long FT_VALIDATE_trak_INDEX = 7
    const long FT_VALIDATE_prop_INDEX = 8
    const long FT_VALIDATE_lcar_INDEX = 9
    const int FT_VALIDATE_GX_LAST_INDEX
    const int FT_VALIDATE_GX_LENGTH
    const unsigned long FT_VALIDATE_GX_START = 0x4000
    const int FT_VALIDATE_GX_BITFIELD(...)
    const int FT_VALIDATE_feat
    const int FT_VALIDATE_mort
    const int FT_VALIDATE_morx
    const int FT_VALIDATE_bsln
    const int FT_VALIDATE_just
    const int FT_VALIDATE_kern
    const int FT_VALIDATE_opbd
    const int FT_VALIDATE_trak
    const int FT_VALIDATE_prop
    const int FT_VALIDATE_lcar
    const int FT_VALIDATE_GX
    const int FT_VALIDATE_MS
    const int FT_VALIDATE_APPLE
    const int FT_VALIDATE_CKERN


cdef extern from "freetype/ftimage.h":
    struct FT_RasterRec_:
        pass
    const int ft_pixel_mode_none
    const int ft_pixel_mode_mono
    const int ft_pixel_mode_grays
    const int ft_pixel_mode_pal2
    const int ft_pixel_mode_pal4
    const int FT_OUTLINE_CONTOURS_MAX
    const int FT_OUTLINE_POINTS_MAX
    const unsigned long FT_OUTLINE_NONE = 0x0
    const unsigned long FT_OUTLINE_OWNER = 0x1
    const unsigned long FT_OUTLINE_EVEN_ODD_FILL = 0x2
    const unsigned long FT_OUTLINE_REVERSE_FILL = 0x4
    const unsigned long FT_OUTLINE_IGNORE_DROPOUTS = 0x8
    const unsigned long FT_OUTLINE_SMART_DROPOUTS = 0x10
    const unsigned long FT_OUTLINE_INCLUDE_STUBS = 0x20
    const unsigned long FT_OUTLINE_OVERLAP = 0x40
    const unsigned long FT_OUTLINE_HIGH_PRECISION = 0x100
    const unsigned long FT_OUTLINE_SINGLE_PASS = 0x200
    const int ft_outline_none
    const int ft_outline_owner
    const int ft_outline_even_odd_fill
    const int ft_outline_reverse_fill
    const int ft_outline_ignore_dropouts
    const int ft_outline_high_precision
    const int ft_outline_single_pass
    const int FT_CURVE_TAG(...)
    const unsigned long FT_CURVE_TAG_ON = 0x01
    const unsigned long FT_CURVE_TAG_CONIC = 0x00
    const unsigned long FT_CURVE_TAG_CUBIC = 0x02
    const unsigned long FT_CURVE_TAG_HAS_SCANMODE = 0x04
    const unsigned long FT_CURVE_TAG_TOUCH_X = 0x08
    const unsigned long FT_CURVE_TAG_TOUCH_Y = 0x10
    const int FT_CURVE_TAG_TOUCH_BOTH
    const int FT_Curve_Tag_On
    const int FT_Curve_Tag_Conic
    const int FT_Curve_Tag_Cubic
    const int FT_Curve_Tag_Touch_X
    const int FT_Curve_Tag_Touch_Y
    const int FT_Outline_MoveTo_Func
    const int FT_Outline_LineTo_Func
    const int FT_Outline_ConicTo_Func
    const int FT_Outline_CubicTo_Func
    const int FT_IMAGE_TAG(...)
    const int ft_glyph_format_none
    const int ft_glyph_format_composite
    const int ft_glyph_format_bitmap
    const int ft_glyph_format_outline
    const int ft_glyph_format_plotter
    const int FT_Raster_Span_Func
    const unsigned long FT_RASTER_FLAG_DEFAULT = 0x0
    const unsigned long FT_RASTER_FLAG_AA = 0x1
    const unsigned long FT_RASTER_FLAG_DIRECT = 0x2
    const unsigned long FT_RASTER_FLAG_CLIP = 0x4
    const unsigned long FT_RASTER_FLAG_SDF = 0x8
    const int ft_raster_flag_default
    const int ft_raster_flag_aa
    const int ft_raster_flag_direct
    const int ft_raster_flag_clip
    const int FT_Raster_New_Func
    const int FT_Raster_Done_Func
    const int FT_Raster_Reset_Func
    const int FT_Raster_Set_Mode_Func
    const int FT_Raster_Render_Func
    ctypedef int FT_Pos
    struct FT_Vector_:
        FT_Pos x
        FT_Pos y
    ctypedef FT_Vector_ FT_Vector
    struct FT_BBox_:
        FT_Pos xMin
        FT_Pos yMin
        FT_Pos xMax
        FT_Pos yMax
    ctypedef FT_BBox_ FT_BBox
    enum FT_Pixel_Mode_:
        FT_PIXEL_MODE_NONE = 0
        FT_PIXEL_MODE_MONO = 1
        FT_PIXEL_MODE_GRAY = 2
        FT_PIXEL_MODE_GRAY2 = 3
        FT_PIXEL_MODE_GRAY4 = 4
        FT_PIXEL_MODE_LCD = 5
        FT_PIXEL_MODE_LCD_V = 6
        FT_PIXEL_MODE_BGRA = 7
        FT_PIXEL_MODE_MAX = 8
    ctypedef FT_Pixel_Mode_ FT_Pixel_Mode
    struct FT_Bitmap_:
        unsigned int rows
        unsigned int width
        int pitch
        unsigned char* buffer
        unsigned short num_grays
        unsigned char pixel_mode
        unsigned char palette_mode
        void* palette
    ctypedef FT_Bitmap_ FT_Bitmap
    struct FT_Outline_:
        unsigned short n_contours
        unsigned short n_points
        FT_Vector* points
        unsigned char* tags
        unsigned short* contours
        int flags
    ctypedef FT_Outline_ FT_Outline
    ctypedef int (*FT_Outline_MoveToFunc)(FT_Vector*, void*)
    ctypedef int (*FT_Outline_LineToFunc)(FT_Vector*, void*)
    ctypedef int (*FT_Outline_ConicToFunc)(FT_Vector*, FT_Vector*, void*)
    ctypedef int (*FT_Outline_CubicToFunc)(FT_Vector*, FT_Vector*, FT_Vector*, void*)
    struct FT_Outline_Funcs_:
        FT_Outline_MoveToFunc move_to
        FT_Outline_LineToFunc line_to
        FT_Outline_ConicToFunc conic_to
        FT_Outline_CubicToFunc cubic_to
        int shift
        FT_Pos delta
    ctypedef FT_Outline_Funcs_ FT_Outline_Funcs
    enum FT_Glyph_Format_:
        FT_GLYPH_FORMAT_NONE = 0
        FT_GLYPH_FORMAT_COMPOSITE = 1
        FT_GLYPH_FORMAT_BITMAP = 2
        FT_GLYPH_FORMAT_OUTLINE = 3
        FT_GLYPH_FORMAT_PLOTTER = 4
        FT_GLYPH_FORMAT_SVG = 5
    ctypedef FT_Glyph_Format_ FT_Glyph_Format
    struct FT_Span_:
        short x
        unsigned short len
        unsigned char coverage
    ctypedef FT_Span_ FT_Span
    ctypedef void (*FT_SpanFunc)(int, int, FT_Span*, void*)
    ctypedef int (*FT_Raster_BitTest_Func)(int, int, void*)
    ctypedef void (*FT_Raster_BitSet_Func)(int, int, void*)
    struct FT_Raster_Params_:
        FT_Bitmap* target
        const void* source
        int flags
        FT_SpanFunc gray_spans
        FT_SpanFunc black_spans
        FT_Raster_BitTest_Func bit_test
        FT_Raster_BitSet_Func bit_set
        void* user
        FT_BBox clip_box
    ctypedef FT_Raster_Params_ FT_Raster_Params
    ctypedef FT_RasterRec_* FT_Raster
    ctypedef int (*FT_Raster_NewFunc)(void*, FT_Raster*)
    ctypedef void (*FT_Raster_DoneFunc)(FT_Raster)
    ctypedef void (*FT_Raster_ResetFunc)(FT_Raster, unsigned char*, unsigned long)
    ctypedef int (*FT_Raster_SetModeFunc)(FT_Raster, unsigned long, void*)
    ctypedef int (*FT_Raster_RenderFunc)(FT_Raster, FT_Raster_Params*)
    struct FT_Raster_Funcs_:
        FT_Glyph_Format glyph_format
        FT_Raster_NewFunc raster_new
        FT_Raster_ResetFunc raster_reset
        FT_Raster_SetModeFunc raster_set_mode
        FT_Raster_RenderFunc raster_render
        FT_Raster_DoneFunc raster_done
    ctypedef FT_Raster_Funcs_ FT_Raster_Funcs


cdef extern from "freetype/ftincrem.h":
    struct FT_IncrementalRec_:
        pass
    ctypedef int* FT_Incremental
    struct FT_Incremental_MetricsRec_:
        int bearing_x
        int bearing_y
        int advance
        int advance_v
    ctypedef FT_Incremental_MetricsRec_ FT_Incremental_MetricsRec
    ctypedef FT_Incremental_MetricsRec_* FT_Incremental_Metrics
    ctypedef int (*FT_Incremental_GetGlyphDataFunc)(FT_Incremental, int, int*)
    ctypedef void (*FT_Incremental_FreeGlyphDataFunc)(FT_Incremental, int*)
    ctypedef int (*FT_Incremental_GetGlyphMetricsFunc)(FT_Incremental, int, int, FT_Incremental_MetricsRec*)
    struct FT_Incremental_FuncsRec_:
        FT_Incremental_GetGlyphDataFunc get_glyph_data
        FT_Incremental_FreeGlyphDataFunc free_glyph_data
        FT_Incremental_GetGlyphMetricsFunc get_glyph_metrics
    ctypedef FT_Incremental_FuncsRec_ FT_Incremental_FuncsRec
    struct FT_Incremental_InterfaceRec_:
        FT_Incremental_FuncsRec* funcs
        FT_Incremental object
    ctypedef FT_Incremental_InterfaceRec_ FT_Incremental_InterfaceRec
    ctypedef FT_Incremental_InterfaceRec* FT_Incremental_Interface


cdef extern from "freetype/ftlcdfil.h":
    const long FT_LCD_FILTER_FIVE_TAPS = 5
    enum FT_LcdFilter_:
        FT_LCD_FILTER_NONE = 0
        FT_LCD_FILTER_DEFAULT = 1
        FT_LCD_FILTER_LIGHT = 2
        FT_LCD_FILTER_LEGACY1 = 3
        FT_LCD_FILTER_LEGACY = 16
        FT_LCD_FILTER_MAX = 17
    ctypedef int FT_LcdFilter
    ctypedef int[5] FT_LcdFiveTapFilter



cdef extern from "freetype/ftlist.h":
    ctypedef int (*FT_List_Iterator)(int, void*)
    ctypedef void (*FT_List_Destructor)(int, void*, void*)


cdef extern from "freetype/ftlogging.h":
    ctypedef void (*FT_Custom_Log_Handler)(const char*, const char*, int)


cdef extern from "freetype/ftmm.h":
    const long T1_MAX_MM_AXIS = 4
    const long T1_MAX_MM_DESIGNS = 16
    const long T1_MAX_MM_MAP_POINTS = 20
    const long FT_VAR_AXIS_FLAG_HIDDEN = 1
    struct FT_MM_Axis_:
        int* name
        int minimum
        int maximum
    ctypedef int FT_MM_Axis
    struct FT_Multi_Master_:
        int num_axis
        int num_designs
        FT_MM_Axis axis[4]
    ctypedef FT_Multi_Master_ FT_Multi_Master
    struct FT_Var_Axis_:
        int* name
        int minimum
        #int def
        int maximum
        int tag
        int strid
    ctypedef FT_Var_Axis_ FT_Var_Axis
    struct FT_Var_Named_Style_:
        int* coords
        int strid
        int psid
    ctypedef FT_Var_Named_Style_ FT_Var_Named_Style
    struct FT_MM_Var_:
        int num_axis
        int num_designs
        int num_namedstyles
        FT_Var_Axis* axis
        FT_Var_Named_Style* namedstyle
    ctypedef FT_MM_Var_ FT_MM_Var


cdef extern from "freetype/ftmodapi.h":
    const long FT_MODULE_FONT_DRIVER = 1
    const long FT_MODULE_RENDERER = 2
    const long FT_MODULE_HINTER = 4
    const long FT_MODULE_STYLER = 8
    const unsigned long FT_MODULE_DRIVER_SCALABLE = 0x100
    const unsigned long FT_MODULE_DRIVER_NO_OUTLINES = 0x200
    const unsigned long FT_MODULE_DRIVER_HAS_HINTER = 0x400
    const unsigned long FT_MODULE_DRIVER_HINTS_LIGHTLY = 0x800
    const int ft_module_font_driver
    const int ft_module_renderer
    const int ft_module_hinter
    const int ft_module_styler
    const int ft_module_driver_scalable
    const int ft_module_driver_no_outlines
    const int ft_module_driver_has_hinter
    const int ft_module_driver_hints_lightly
    const int FT_FACE_DRIVER_NAME(...)
    const long FT_DEBUG_HOOK_TRUETYPE = 0
    ctypedef int (*FT_Module_Constructor)(int)
    ctypedef void (*FT_Module_Destructor)(int)
    ctypedef int (*FT_Module_Requester)(int, const char*)
    struct FT_Module_Class_:
        int module_flags
        int module_size
        const int* module_name
        int module_version
        int module_requires
        const void* module_interface
        FT_Module_Constructor module_init
        FT_Module_Destructor module_done
        FT_Module_Requester get_interface
    ctypedef FT_Module_Class_ FT_Module_Class
    ctypedef int (*FT_DebugHook_Func)(void*)
    enum FT_TrueTypeEngineType_:
        FT_TRUETYPE_ENGINE_TYPE_NONE = 0
        FT_TRUETYPE_ENGINE_TYPE_UNPATENTED = 1
        FT_TRUETYPE_ENGINE_TYPE_PATENTED = 2
    ctypedef FT_TrueTypeEngineType_ FT_TrueTypeEngineType


cdef extern from "freetype/ftmoderr.h":
    const int FT_MODERRDEF
    const int FT_MODERR_START_LIST
    const int FT_MODERR_END_LIST


cdef extern from "freetype/ftotval.h":
    const unsigned long FT_VALIDATE_BASE = 0x0100
    const unsigned long FT_VALIDATE_GDEF = 0x0200
    const unsigned long FT_VALIDATE_GPOS = 0x0400
    const unsigned long FT_VALIDATE_GSUB = 0x0800
    const unsigned long FT_VALIDATE_JSTF = 0x1000
    const unsigned long FT_VALIDATE_MATH = 0x2000
    const int FT_VALIDATE_OT



cdef extern from "freetype/ftparams.h":
    const int FT_PARAM_TAG_IGNORE_TYPOGRAPHIC_FAMILY
    const int FT_PARAM_TAG_IGNORE_PREFERRED_FAMILY
    const int FT_PARAM_TAG_IGNORE_TYPOGRAPHIC_SUBFAMILY
    const int FT_PARAM_TAG_IGNORE_PREFERRED_SUBFAMILY
    const int FT_PARAM_TAG_INCREMENTAL
    const int FT_PARAM_TAG_IGNORE_SBIX
    const int FT_PARAM_TAG_LCD_FILTER_WEIGHTS
    const int FT_PARAM_TAG_RANDOM_SEED
    const int FT_PARAM_TAG_STEM_DARKENING
    const int FT_PARAM_TAG_UNPATENTED_HINTING


cdef extern from "freetype/ftrender.h":
    const int FTRENDER_H_
    const int FT_Glyph_Init_Func
    const int FT_Glyph_Done_Func
    const int FT_Glyph_Transform_Func
    const int FT_Glyph_BBox_Func
    const int FT_Glyph_Copy_Func
    const int FT_Glyph_Prepare_Func
    const int FTRenderer_render
    const int FTRenderer_transform
    const int FTRenderer_getCBox
    const int FTRenderer_setMode
    #ctypedef int FT_Error(int, int) ()(int*)
    ctypedef void (*FT_Glyph_DoneFunc)(int)
    ctypedef void (*FT_Glyph_TransformFunc)(int, const int*, const int*)
    ctypedef void (*FT_Glyph_GetBBoxFunc)(int, int*)
    ctypedef int (*FT_Glyph_CopyFunc)(int, int)
    ctypedef int (*FT_Glyph_PrepareFunc)(int, int)
    struct FT_Glyph_Class_:
        int glyph_size
        int glyph_format
        int glyph_init
        FT_Glyph_DoneFunc glyph_done
        FT_Glyph_CopyFunc glyph_copy
        FT_Glyph_TransformFunc glyph_transform
        FT_Glyph_GetBBoxFunc glyph_bbox
        FT_Glyph_PrepareFunc glyph_prepare
    ctypedef int (*FT_Renderer_RenderFunc)(int, int, int, const int*)
    ctypedef int (*FT_Renderer_TransformFunc)(int, int, const int*, const int*)
    ctypedef void (*FT_Renderer_GetCBoxFunc)(int, int, int*)
    ctypedef int (*FT_Renderer_SetModeFunc)(int, int, int)
    struct FT_Renderer_Class_:
        int root
        int glyph_format
        FT_Renderer_RenderFunc render_glyph
        FT_Renderer_TransformFunc transform_glyph
        FT_Renderer_GetCBoxFunc get_glyph_cbox
        FT_Renderer_SetModeFunc set_mode
        const int* raster_class
    ctypedef FT_Renderer_Class_ FT_Renderer_Class


cdef extern from "freetype/ftsnames.h":
    struct FT_SfntName_:
        int platform_id
        int encoding_id
        int language_id
        int name_id
        int* string
        int string_len
    ctypedef int FT_SfntName
    struct FT_SfntLangTag_:
        int* string
        int string_len
    ctypedef FT_SfntLangTag_ FT_SfntLangTag


cdef extern from "freetype/ftstroke.h":
    struct FT_StrokerRec_:
        pass
    ctypedef int* FT_Stroker
    enum FT_Stroker_LineJoin_:
        FT_STROKER_LINEJOIN_ROUND = 0
        FT_STROKER_LINEJOIN_BEVEL = 1
        FT_STROKER_LINEJOIN_MITER_VARIABLE = 2
        FT_STROKER_LINEJOIN_MITER = 2
        FT_STROKER_LINEJOIN_MITER_FIXED = 3
    ctypedef FT_Stroker_LineJoin_ FT_Stroker_LineJoin
    enum FT_Stroker_LineCap_:
        FT_STROKER_LINECAP_BUTT = 0
        FT_STROKER_LINECAP_ROUND = 1
        FT_STROKER_LINECAP_SQUARE = 2
    ctypedef FT_Stroker_LineCap_ FT_Stroker_LineCap
    enum FT_StrokerBorder_:
        FT_STROKER_BORDER_LEFT = 0
        FT_STROKER_BORDER_RIGHT = 1
    ctypedef FT_StrokerBorder_ FT_StrokerBorder


cdef extern from "freetype/ftsystem.h":
    ctypedef int* FT_Memory
    ctypedef void* (*FT_Alloc_Func)(FT_Memory, long)
    ctypedef void (*FT_Free_Func)(FT_Memory, void*)
    ctypedef void* (*FT_Realloc_Func)(FT_Memory, long, long, void*)
    struct FT_MemoryRec_:
        void* user
        FT_Alloc_Func alloc
        FT_Free_Func free
        FT_Realloc_Func realloc
    ctypedef FT_StreamRec_* FT_Stream
    union FT_StreamDesc_:
        long value
        void* pointer
    ctypedef FT_StreamDesc_ FT_StreamDesc
    ctypedef unsigned long (*FT_Stream_IoFunc)(FT_Stream, unsigned long, unsigned char*, unsigned long)
    ctypedef void (*FT_Stream_CloseFunc)(FT_Stream)
    struct FT_StreamRec_:
        unsigned char* base
        unsigned long size
        unsigned long pos
        FT_StreamDesc descriptor
        FT_StreamDesc pathname
        FT_Stream_IoFunc read
        FT_Stream_CloseFunc close
        FT_Memory memory
        unsigned char* cursor
        unsigned char* limit
    ctypedef FT_StreamRec_ FT_StreamRec


cdef extern from "freetype/fttrigon.h":
    const int FTTRIGON_H_
    const int FT_ANGLE_PI
    const int FT_ANGLE_2PI
    const int FT_ANGLE_PI2
    const int FT_ANGLE_PI4
    int FT_Angle





cdef extern from "freetype/ftwinfnt.h":
    const int FTWINFNT_H_
    const long FT_WinFNT_ID_CP1252 = 0
    const long FT_WinFNT_ID_DEFAULT = 1
    const long FT_WinFNT_ID_SYMBOL = 2
    const long FT_WinFNT_ID_MAC = 77
    const long FT_WinFNT_ID_CP932 = 128
    const long FT_WinFNT_ID_CP949 = 129
    const long FT_WinFNT_ID_CP1361 = 130
    const long FT_WinFNT_ID_CP936 = 134
    const long FT_WinFNT_ID_CP950 = 136
    const long FT_WinFNT_ID_CP1253 = 161
    const long FT_WinFNT_ID_CP1254 = 162
    const long FT_WinFNT_ID_CP1258 = 163
    const long FT_WinFNT_ID_CP1255 = 177
    const long FT_WinFNT_ID_CP1256 = 178
    const long FT_WinFNT_ID_CP1257 = 186
    const long FT_WinFNT_ID_CP1251 = 204
    const long FT_WinFNT_ID_CP874 = 222
    const long FT_WinFNT_ID_CP1250 = 238
    const long FT_WinFNT_ID_OEM = 255
    struct FT_WinFNT_HeaderRec_:
        int version
        int file_size
        int copyright[60]
        int file_type
        int nominal_point_size
        int vertical_resolution
        int horizontal_resolution
        int ascent
        int internal_leading
        int external_leading
        int italic
        int underline
        int strike_out
        int weight
        int charset
        int pixel_width
        int pixel_height
        int pitch_and_family
        int avg_width
        int max_width
        int first_char
        int last_char
        int default_char
        int break_char
        int bytes_per_row
        int device_offset
        int face_name_offset
        int bits_pointer
        int bits_offset
        int reserved
        int flags
        int A_space
        int B_space
        int C_space
        int color_table_offset
        int reserved1[4]
    ctypedef int FT_WinFNT_HeaderRec
    ctypedef FT_WinFNT_HeaderRec_* FT_WinFNT_Header

cdef extern from "freetype/otsvg.h":
    #ctypedef int FT_Error(int*) ()(int*)
    ctypedef void (*SVG_Lib_Free_Func)(int*)
    ctypedef int (*SVG_Lib_Render_Func)(int, int*)
    ctypedef int (*SVG_Lib_Preset_Slot_Func)(int, int, int*)
    struct SVG_RendererHooks_:
        int init_svg
        SVG_Lib_Free_Func free_svg
        SVG_Lib_Render_Func render_svg
        SVG_Lib_Preset_Slot_Func preset_slot
    ctypedef SVG_RendererHooks_ SVG_RendererHooks
    struct FT_SVG_DocumentRec_:
        int* svg_document
        int svg_document_length
        int metrics
        int units_per_EM
        int start_glyph_id
        int end_glyph_id
        int transform
        int delta
    ctypedef FT_SVG_DocumentRec_ FT_SVG_DocumentRec
    ctypedef FT_SVG_DocumentRec_* FT_SVG_Document


cdef extern from "freetype/t1tables.h":
    const int T1TABLES_H_
    const int t1_blend_underline_position
    const int t1_blend_underline_thickness
    const int t1_blend_italic_angle
    const int t1_blend_blue_values
    const int t1_blend_other_blues
    const int t1_blend_standard_widths
    const int t1_blend_standard_height
    const int t1_blend_stem_snap_widths
    const int t1_blend_stem_snap_heights
    const int t1_blend_blue_scale
    const int t1_blend_blue_shift
    const int t1_blend_family_blues
    const int t1_blend_family_other_blues
    const int t1_blend_force_bold
    const int t1_blend_max
    struct PS_FontInfoRec_:
        int* version
        int* notice
        int* full_name
        int* family_name
        int* weight
        int italic_angle
        int is_fixed_pitch
        int underline_position
        int underline_thickness
    ctypedef int PS_FontInfoRec
    ctypedef PS_FontInfoRec_* PS_FontInfo
    ctypedef PS_FontInfoRec T1_FontInfo
    struct PS_PrivateRec_:
        int unique_id
        int lenIV
        int num_blue_values
        int num_other_blues
        int num_family_blues
        int num_family_other_blues
        int blue_values[14]
        int other_blues[10]
        int family_blues[14]
        int family_other_blues[10]
        int blue_scale
        int blue_shift
        int blue_fuzz
        int standard_width[1]
        int standard_height[1]
        int num_snap_widths
        int num_snap_heights
        int force_bold
        int round_stem_up
        int snap_widths[13]
        int snap_heights[13]
        int expansion_factor
        int language_group
        int password
        int min_feature[2]
    ctypedef PS_PrivateRec_ PS_PrivateRec
    ctypedef PS_PrivateRec_* PS_Private
    ctypedef PS_PrivateRec T1_Private
    enum T1_Blend_Flags_:
        T1_BLEND_UNDERLINE_POSITION = 0
        T1_BLEND_UNDERLINE_THICKNESS = 1
        T1_BLEND_ITALIC_ANGLE = 2
        T1_BLEND_BLUE_VALUES = 3
        T1_BLEND_OTHER_BLUES = 4
        T1_BLEND_STANDARD_WIDTH = 5
        T1_BLEND_STANDARD_HEIGHT = 6
        T1_BLEND_STEM_SNAP_WIDTHS = 7
        T1_BLEND_STEM_SNAP_HEIGHTS = 8
        T1_BLEND_BLUE_SCALE = 9
        T1_BLEND_BLUE_SHIFT = 10
        T1_BLEND_FAMILY_BLUES = 11
        T1_BLEND_FAMILY_OTHER_BLUES = 12
        T1_BLEND_FORCE_BOLD = 13
        T1_BLEND_MAX = 14
    ctypedef T1_Blend_Flags_ T1_Blend_Flags
    struct CID_FaceDictRec_:
        PS_PrivateRec private_dict
        int len_buildchar
        int forcebold_threshold
        int stroke_width
        int expansion_factor
        int paint_type
        int font_type
        int font_matrix
        int font_offset
        int num_subrs
        int subrmap_offset
        int sd_bytes
    ctypedef CID_FaceDictRec_ CID_FaceDictRec
    ctypedef CID_FaceDictRec_* CID_FaceDict
    ctypedef CID_FaceDictRec CID_FontDict
    struct CID_FaceInfoRec_:
        int* cid_font_name
        int cid_version
        int cid_font_type
        int* registry
        int* ordering
        int supplement
        PS_FontInfoRec font_info
        int font_bbox
        int uid_base
        int num_xuid
        int xuid[16]
        int cidmap_offset
        int fd_bytes
        int gd_bytes
        int cid_count
        int num_dicts
        CID_FaceDict font_dicts
        int data_offset
    ctypedef CID_FaceInfoRec_ CID_FaceInfoRec
    ctypedef CID_FaceInfoRec_* CID_FaceInfo
    ctypedef CID_FaceInfoRec CID_Info
    enum T1_EncodingType_:
        T1_ENCODING_TYPE_NONE = 0
        T1_ENCODING_TYPE_ARRAY = 1
        T1_ENCODING_TYPE_STANDARD = 2
        T1_ENCODING_TYPE_ISOLATIN1 = 3
        T1_ENCODING_TYPE_EXPERT = 4
    ctypedef T1_EncodingType_ T1_EncodingType
    enum PS_Dict_Keys_:
        PS_DICT_FONT_TYPE = 0
        PS_DICT_FONT_MATRIX = 1
        PS_DICT_FONT_BBOX = 2
        PS_DICT_PAINT_TYPE = 3
        PS_DICT_FONT_NAME = 4
        PS_DICT_UNIQUE_ID = 5
        PS_DICT_NUM_CHAR_STRINGS = 6
        PS_DICT_CHAR_STRING_KEY = 7
        PS_DICT_CHAR_STRING = 8
        PS_DICT_ENCODING_TYPE = 9
        PS_DICT_ENCODING_ENTRY = 10
        PS_DICT_NUM_SUBRS = 11
        PS_DICT_SUBR = 12
        PS_DICT_STD_HW = 13
        PS_DICT_STD_VW = 14
        PS_DICT_NUM_BLUE_VALUES = 15
        PS_DICT_BLUE_VALUE = 16
        PS_DICT_BLUE_FUZZ = 17
        PS_DICT_NUM_OTHER_BLUES = 18
        PS_DICT_OTHER_BLUE = 19
        PS_DICT_NUM_FAMILY_BLUES = 20
        PS_DICT_FAMILY_BLUE = 21
        PS_DICT_NUM_FAMILY_OTHER_BLUES = 22
        PS_DICT_FAMILY_OTHER_BLUE = 23
        PS_DICT_BLUE_SCALE = 24
        PS_DICT_BLUE_SHIFT = 25
        PS_DICT_NUM_STEM_SNAP_H = 26
        PS_DICT_STEM_SNAP_H = 27
        PS_DICT_NUM_STEM_SNAP_V = 28
        PS_DICT_STEM_SNAP_V = 29
        PS_DICT_FORCE_BOLD = 30
        PS_DICT_RND_STEM_UP = 31
        PS_DICT_MIN_FEATURE = 32
        PS_DICT_LEN_IV = 33
        PS_DICT_PASSWORD = 34
        PS_DICT_LANGUAGE_GROUP = 35
        PS_DICT_VERSION = 36
        PS_DICT_NOTICE = 37
        PS_DICT_FULL_NAME = 38
        PS_DICT_FAMILY_NAME = 39
        PS_DICT_WEIGHT = 40
        PS_DICT_IS_FIXED_PITCH = 41
        PS_DICT_UNDERLINE_POSITION = 42
        PS_DICT_UNDERLINE_THICKNESS = 43
        PS_DICT_FS_TYPE = 44
        PS_DICT_ITALIC_ANGLE = 45
        PS_DICT_MAX = 45
    ctypedef PS_Dict_Keys_ PS_Dict_Keys


cdef extern from "freetype/ttnameid.h":
    const int TTNAMEID_H_
    const long TT_PLATFORM_APPLE_UNICODE = 0
    const long TT_PLATFORM_MACINTOSH = 1
    const long TT_PLATFORM_ISO = 2
    const long TT_PLATFORM_MICROSOFT = 3
    const long TT_PLATFORM_CUSTOM = 4
    const long TT_PLATFORM_ADOBE = 7
    const long TT_APPLE_ID_DEFAULT = 0
    const long TT_APPLE_ID_UNICODE_1_1 = 1
    const long TT_APPLE_ID_ISO_10646 = 2
    const long TT_APPLE_ID_UNICODE_2_0 = 3
    const long TT_APPLE_ID_UNICODE_32 = 4
    const long TT_APPLE_ID_VARIANT_SELECTOR = 5
    const long TT_APPLE_ID_FULL_UNICODE = 6
    const long TT_MAC_ID_ROMAN = 0
    const long TT_MAC_ID_JAPANESE = 1
    const long TT_MAC_ID_TRADITIONAL_CHINESE = 2
    const long TT_MAC_ID_KOREAN = 3
    const long TT_MAC_ID_ARABIC = 4
    const long TT_MAC_ID_HEBREW = 5
    const long TT_MAC_ID_GREEK = 6
    const long TT_MAC_ID_RUSSIAN = 7
    const long TT_MAC_ID_RSYMBOL = 8
    const long TT_MAC_ID_DEVANAGARI = 9
    const long TT_MAC_ID_GURMUKHI = 10
    const long TT_MAC_ID_GUJARATI = 11
    const long TT_MAC_ID_ORIYA = 12
    const long TT_MAC_ID_BENGALI = 13
    const long TT_MAC_ID_TAMIL = 14
    const long TT_MAC_ID_TELUGU = 15
    const long TT_MAC_ID_KANNADA = 16
    const long TT_MAC_ID_MALAYALAM = 17
    const long TT_MAC_ID_SINHALESE = 18
    const long TT_MAC_ID_BURMESE = 19
    const long TT_MAC_ID_KHMER = 20
    const long TT_MAC_ID_THAI = 21
    const long TT_MAC_ID_LAOTIAN = 22
    const long TT_MAC_ID_GEORGIAN = 23
    const long TT_MAC_ID_ARMENIAN = 24
    const long TT_MAC_ID_MALDIVIAN = 25
    const long TT_MAC_ID_SIMPLIFIED_CHINESE = 25
    const long TT_MAC_ID_TIBETAN = 26
    const long TT_MAC_ID_MONGOLIAN = 27
    const long TT_MAC_ID_GEEZ = 28
    const long TT_MAC_ID_SLAVIC = 29
    const long TT_MAC_ID_VIETNAMESE = 30
    const long TT_MAC_ID_SINDHI = 31
    const long TT_MAC_ID_UNINTERP = 32
    const long TT_ISO_ID_7BIT_ASCII = 0
    const long TT_ISO_ID_10646 = 1
    const long TT_ISO_ID_8859_1 = 2
    const long TT_MS_ID_SYMBOL_CS = 0
    const long TT_MS_ID_UNICODE_CS = 1
    const long TT_MS_ID_SJIS = 2
    const long TT_MS_ID_PRC = 3
    const long TT_MS_ID_BIG_5 = 4
    const long TT_MS_ID_WANSUNG = 5
    const long TT_MS_ID_JOHAB = 6
    const long TT_MS_ID_UCS_4 = 10
    const int TT_MS_ID_GB2312
    const long TT_ADOBE_ID_STANDARD = 0
    const long TT_ADOBE_ID_EXPERT = 1
    const long TT_ADOBE_ID_CUSTOM = 2
    const long TT_ADOBE_ID_LATIN_1 = 3
    const long TT_MAC_LANGID_ENGLISH = 0
    const long TT_MAC_LANGID_FRENCH = 1
    const long TT_MAC_LANGID_GERMAN = 2
    const long TT_MAC_LANGID_ITALIAN = 3
    const long TT_MAC_LANGID_DUTCH = 4
    const long TT_MAC_LANGID_SWEDISH = 5
    const long TT_MAC_LANGID_SPANISH = 6
    const long TT_MAC_LANGID_DANISH = 7
    const long TT_MAC_LANGID_PORTUGUESE = 8
    const long TT_MAC_LANGID_NORWEGIAN = 9
    const long TT_MAC_LANGID_HEBREW = 10
    const long TT_MAC_LANGID_JAPANESE = 11
    const long TT_MAC_LANGID_ARABIC = 12
    const long TT_MAC_LANGID_FINNISH = 13
    const long TT_MAC_LANGID_GREEK = 14
    const long TT_MAC_LANGID_ICELANDIC = 15
    const long TT_MAC_LANGID_MALTESE = 16
    const long TT_MAC_LANGID_TURKISH = 17
    const long TT_MAC_LANGID_CROATIAN = 18
    const long TT_MAC_LANGID_CHINESE_TRADITIONAL = 19
    const long TT_MAC_LANGID_URDU = 20
    const long TT_MAC_LANGID_HINDI = 21
    const long TT_MAC_LANGID_THAI = 22
    const long TT_MAC_LANGID_KOREAN = 23
    const long TT_MAC_LANGID_LITHUANIAN = 24
    const long TT_MAC_LANGID_POLISH = 25
    const long TT_MAC_LANGID_HUNGARIAN = 26
    const long TT_MAC_LANGID_ESTONIAN = 27
    const long TT_MAC_LANGID_LETTISH = 28
    const long TT_MAC_LANGID_SAAMISK = 29
    const long TT_MAC_LANGID_FAEROESE = 30
    const long TT_MAC_LANGID_FARSI = 31
    const long TT_MAC_LANGID_RUSSIAN = 32
    const long TT_MAC_LANGID_CHINESE_SIMPLIFIED = 33
    const long TT_MAC_LANGID_FLEMISH = 34
    const long TT_MAC_LANGID_IRISH = 35
    const long TT_MAC_LANGID_ALBANIAN = 36
    const long TT_MAC_LANGID_ROMANIAN = 37
    const long TT_MAC_LANGID_CZECH = 38
    const long TT_MAC_LANGID_SLOVAK = 39
    const long TT_MAC_LANGID_SLOVENIAN = 40
    const long TT_MAC_LANGID_YIDDISH = 41
    const long TT_MAC_LANGID_SERBIAN = 42
    const long TT_MAC_LANGID_MACEDONIAN = 43
    const long TT_MAC_LANGID_BULGARIAN = 44
    const long TT_MAC_LANGID_UKRAINIAN = 45
    const long TT_MAC_LANGID_BYELORUSSIAN = 46
    const long TT_MAC_LANGID_UZBEK = 47
    const long TT_MAC_LANGID_KAZAKH = 48
    const long TT_MAC_LANGID_AZERBAIJANI = 49
    const long TT_MAC_LANGID_AZERBAIJANI_CYRILLIC_SCRIPT = 49
    const long TT_MAC_LANGID_AZERBAIJANI_ARABIC_SCRIPT = 50
    const long TT_MAC_LANGID_ARMENIAN = 51
    const long TT_MAC_LANGID_GEORGIAN = 52
    const long TT_MAC_LANGID_MOLDAVIAN = 53
    const long TT_MAC_LANGID_KIRGHIZ = 54
    const long TT_MAC_LANGID_TAJIKI = 55
    const long TT_MAC_LANGID_TURKMEN = 56
    const long TT_MAC_LANGID_MONGOLIAN = 57
    const long TT_MAC_LANGID_MONGOLIAN_MONGOLIAN_SCRIPT = 57
    const long TT_MAC_LANGID_MONGOLIAN_CYRILLIC_SCRIPT = 58
    const long TT_MAC_LANGID_PASHTO = 59
    const long TT_MAC_LANGID_KURDISH = 60
    const long TT_MAC_LANGID_KASHMIRI = 61
    const long TT_MAC_LANGID_SINDHI = 62
    const long TT_MAC_LANGID_TIBETAN = 63
    const long TT_MAC_LANGID_NEPALI = 64
    const long TT_MAC_LANGID_SANSKRIT = 65
    const long TT_MAC_LANGID_MARATHI = 66
    const long TT_MAC_LANGID_BENGALI = 67
    const long TT_MAC_LANGID_ASSAMESE = 68
    const long TT_MAC_LANGID_GUJARATI = 69
    const long TT_MAC_LANGID_PUNJABI = 70
    const long TT_MAC_LANGID_ORIYA = 71
    const long TT_MAC_LANGID_MALAYALAM = 72
    const long TT_MAC_LANGID_KANNADA = 73
    const long TT_MAC_LANGID_TAMIL = 74
    const long TT_MAC_LANGID_TELUGU = 75
    const long TT_MAC_LANGID_SINHALESE = 76
    const long TT_MAC_LANGID_BURMESE = 77
    const long TT_MAC_LANGID_KHMER = 78
    const long TT_MAC_LANGID_LAO = 79
    const long TT_MAC_LANGID_VIETNAMESE = 80
    const long TT_MAC_LANGID_INDONESIAN = 81
    const long TT_MAC_LANGID_TAGALOG = 82
    const long TT_MAC_LANGID_MALAY_ROMAN_SCRIPT = 83
    const long TT_MAC_LANGID_MALAY_ARABIC_SCRIPT = 84
    const long TT_MAC_LANGID_AMHARIC = 85
    const long TT_MAC_LANGID_TIGRINYA = 86
    const long TT_MAC_LANGID_GALLA = 87
    const long TT_MAC_LANGID_SOMALI = 88
    const long TT_MAC_LANGID_SWAHILI = 89
    const long TT_MAC_LANGID_RUANDA = 90
    const long TT_MAC_LANGID_RUNDI = 91
    const long TT_MAC_LANGID_CHEWA = 92
    const long TT_MAC_LANGID_MALAGASY = 93
    const long TT_MAC_LANGID_ESPERANTO = 94
    const long TT_MAC_LANGID_WELSH = 128
    const long TT_MAC_LANGID_BASQUE = 129
    const long TT_MAC_LANGID_CATALAN = 130
    const long TT_MAC_LANGID_LATIN = 131
    const long TT_MAC_LANGID_QUECHUA = 132
    const long TT_MAC_LANGID_GUARANI = 133
    const long TT_MAC_LANGID_AYMARA = 134
    const long TT_MAC_LANGID_TATAR = 135
    const long TT_MAC_LANGID_UIGHUR = 136
    const long TT_MAC_LANGID_DZONGKHA = 137
    const long TT_MAC_LANGID_JAVANESE = 138
    const long TT_MAC_LANGID_SUNDANESE = 139
    const long TT_MAC_LANGID_GALICIAN = 140
    const long TT_MAC_LANGID_AFRIKAANS = 141
    const long TT_MAC_LANGID_BRETON = 142
    const long TT_MAC_LANGID_INUKTITUT = 143
    const long TT_MAC_LANGID_SCOTTISH_GAELIC = 144
    const long TT_MAC_LANGID_MANX_GAELIC = 145
    const long TT_MAC_LANGID_IRISH_GAELIC = 146
    const long TT_MAC_LANGID_TONGAN = 147
    const long TT_MAC_LANGID_GREEK_POLYTONIC = 148
    const long TT_MAC_LANGID_GREELANDIC = 149
    const long TT_MAC_LANGID_AZERBAIJANI_ROMAN_SCRIPT = 150
    const unsigned long TT_MS_LANGID_ARABIC_SAUDI_ARABIA = 0x0401
    const unsigned long TT_MS_LANGID_ARABIC_IRAQ = 0x0801
    const unsigned long TT_MS_LANGID_ARABIC_EGYPT = 0x0C01
    const unsigned long TT_MS_LANGID_ARABIC_LIBYA = 0x1001
    const unsigned long TT_MS_LANGID_ARABIC_ALGERIA = 0x1401
    const unsigned long TT_MS_LANGID_ARABIC_MOROCCO = 0x1801
    const unsigned long TT_MS_LANGID_ARABIC_TUNISIA = 0x1C01
    const unsigned long TT_MS_LANGID_ARABIC_OMAN = 0x2001
    const unsigned long TT_MS_LANGID_ARABIC_YEMEN = 0x2401
    const unsigned long TT_MS_LANGID_ARABIC_SYRIA = 0x2801
    const unsigned long TT_MS_LANGID_ARABIC_JORDAN = 0x2C01
    const unsigned long TT_MS_LANGID_ARABIC_LEBANON = 0x3001
    const unsigned long TT_MS_LANGID_ARABIC_KUWAIT = 0x3401
    const unsigned long TT_MS_LANGID_ARABIC_UAE = 0x3801
    const unsigned long TT_MS_LANGID_ARABIC_BAHRAIN = 0x3C01
    const unsigned long TT_MS_LANGID_ARABIC_QATAR = 0x4001
    const unsigned long TT_MS_LANGID_BULGARIAN_BULGARIA = 0x0402
    const unsigned long TT_MS_LANGID_CATALAN_CATALAN = 0x0403
    const unsigned long TT_MS_LANGID_CHINESE_TAIWAN = 0x0404
    const unsigned long TT_MS_LANGID_CHINESE_PRC = 0x0804
    const unsigned long TT_MS_LANGID_CHINESE_HONG_KONG = 0x0C04
    const unsigned long TT_MS_LANGID_CHINESE_SINGAPORE = 0x1004
    const unsigned long TT_MS_LANGID_CHINESE_MACAO = 0x1404
    const unsigned long TT_MS_LANGID_CZECH_CZECH_REPUBLIC = 0x0405
    const unsigned long TT_MS_LANGID_DANISH_DENMARK = 0x0406
    const unsigned long TT_MS_LANGID_GERMAN_GERMANY = 0x0407
    const unsigned long TT_MS_LANGID_GERMAN_SWITZERLAND = 0x0807
    const unsigned long TT_MS_LANGID_GERMAN_AUSTRIA = 0x0C07
    const unsigned long TT_MS_LANGID_GERMAN_LUXEMBOURG = 0x1007
    const unsigned long TT_MS_LANGID_GERMAN_LIECHTENSTEIN = 0x1407
    const unsigned long TT_MS_LANGID_GREEK_GREECE = 0x0408
    const unsigned long TT_MS_LANGID_ENGLISH_UNITED_STATES = 0x0409
    const unsigned long TT_MS_LANGID_ENGLISH_UNITED_KINGDOM = 0x0809
    const unsigned long TT_MS_LANGID_ENGLISH_AUSTRALIA = 0x0C09
    const unsigned long TT_MS_LANGID_ENGLISH_CANADA = 0x1009
    const unsigned long TT_MS_LANGID_ENGLISH_NEW_ZEALAND = 0x1409
    const unsigned long TT_MS_LANGID_ENGLISH_IRELAND = 0x1809
    const unsigned long TT_MS_LANGID_ENGLISH_SOUTH_AFRICA = 0x1C09
    const unsigned long TT_MS_LANGID_ENGLISH_JAMAICA = 0x2009
    const unsigned long TT_MS_LANGID_ENGLISH_CARIBBEAN = 0x2409
    const unsigned long TT_MS_LANGID_ENGLISH_BELIZE = 0x2809
    const unsigned long TT_MS_LANGID_ENGLISH_TRINIDAD = 0x2C09
    const unsigned long TT_MS_LANGID_ENGLISH_ZIMBABWE = 0x3009
    const unsigned long TT_MS_LANGID_ENGLISH_PHILIPPINES = 0x3409
    const unsigned long TT_MS_LANGID_ENGLISH_INDIA = 0x4009
    const unsigned long TT_MS_LANGID_ENGLISH_MALAYSIA = 0x4409
    const unsigned long TT_MS_LANGID_ENGLISH_SINGAPORE = 0x4809
    const unsigned long TT_MS_LANGID_SPANISH_SPAIN_TRADITIONAL_SORT = 0x040A
    const unsigned long TT_MS_LANGID_SPANISH_MEXICO = 0x080A
    const unsigned long TT_MS_LANGID_SPANISH_SPAIN_MODERN_SORT = 0x0C0A
    const unsigned long TT_MS_LANGID_SPANISH_GUATEMALA = 0x100A
    const unsigned long TT_MS_LANGID_SPANISH_COSTA_RICA = 0x140A
    const unsigned long TT_MS_LANGID_SPANISH_PANAMA = 0x180A
    const unsigned long TT_MS_LANGID_SPANISH_DOMINICAN_REPUBLIC = 0x1C0A
    const unsigned long TT_MS_LANGID_SPANISH_VENEZUELA = 0x200A
    const unsigned long TT_MS_LANGID_SPANISH_COLOMBIA = 0x240A
    const unsigned long TT_MS_LANGID_SPANISH_PERU = 0x280A
    const unsigned long TT_MS_LANGID_SPANISH_ARGENTINA = 0x2C0A
    const unsigned long TT_MS_LANGID_SPANISH_ECUADOR = 0x300A
    const unsigned long TT_MS_LANGID_SPANISH_CHILE = 0x340A
    const unsigned long TT_MS_LANGID_SPANISH_URUGUAY = 0x380A
    const unsigned long TT_MS_LANGID_SPANISH_PARAGUAY = 0x3C0A
    const unsigned long TT_MS_LANGID_SPANISH_BOLIVIA = 0x400A
    const unsigned long TT_MS_LANGID_SPANISH_EL_SALVADOR = 0x440A
    const unsigned long TT_MS_LANGID_SPANISH_HONDURAS = 0x480A
    const unsigned long TT_MS_LANGID_SPANISH_NICARAGUA = 0x4C0A
    const unsigned long TT_MS_LANGID_SPANISH_PUERTO_RICO = 0x500A
    const unsigned long TT_MS_LANGID_SPANISH_UNITED_STATES = 0x540A
    const unsigned long TT_MS_LANGID_FINNISH_FINLAND = 0x040B
    const unsigned long TT_MS_LANGID_FRENCH_FRANCE = 0x040C
    const unsigned long TT_MS_LANGID_FRENCH_BELGIUM = 0x080C
    const unsigned long TT_MS_LANGID_FRENCH_CANADA = 0x0C0C
    const unsigned long TT_MS_LANGID_FRENCH_SWITZERLAND = 0x100C
    const unsigned long TT_MS_LANGID_FRENCH_LUXEMBOURG = 0x140C
    const unsigned long TT_MS_LANGID_FRENCH_MONACO = 0x180C
    const unsigned long TT_MS_LANGID_HEBREW_ISRAEL = 0x040D
    const unsigned long TT_MS_LANGID_HUNGARIAN_HUNGARY = 0x040E
    const unsigned long TT_MS_LANGID_ICELANDIC_ICELAND = 0x040F
    const unsigned long TT_MS_LANGID_ITALIAN_ITALY = 0x0410
    const unsigned long TT_MS_LANGID_ITALIAN_SWITZERLAND = 0x0810
    const unsigned long TT_MS_LANGID_JAPANESE_JAPAN = 0x0411
    const unsigned long TT_MS_LANGID_KOREAN_KOREA = 0x0412
    const unsigned long TT_MS_LANGID_DUTCH_NETHERLANDS = 0x0413
    const unsigned long TT_MS_LANGID_DUTCH_BELGIUM = 0x0813
    const unsigned long TT_MS_LANGID_NORWEGIAN_NORWAY_BOKMAL = 0x0414
    const unsigned long TT_MS_LANGID_NORWEGIAN_NORWAY_NYNORSK = 0x0814
    const unsigned long TT_MS_LANGID_POLISH_POLAND = 0x0415
    const unsigned long TT_MS_LANGID_PORTUGUESE_BRAZIL = 0x0416
    const unsigned long TT_MS_LANGID_PORTUGUESE_PORTUGAL = 0x0816
    const unsigned long TT_MS_LANGID_ROMANSH_SWITZERLAND = 0x0417
    const unsigned long TT_MS_LANGID_ROMANIAN_ROMANIA = 0x0418
    const unsigned long TT_MS_LANGID_RUSSIAN_RUSSIA = 0x0419
    const unsigned long TT_MS_LANGID_CROATIAN_CROATIA = 0x041A
    const unsigned long TT_MS_LANGID_SERBIAN_SERBIA_LATIN = 0x081A
    const unsigned long TT_MS_LANGID_SERBIAN_SERBIA_CYRILLIC = 0x0C1A
    const unsigned long TT_MS_LANGID_CROATIAN_BOSNIA_HERZEGOVINA = 0x101A
    const unsigned long TT_MS_LANGID_BOSNIAN_BOSNIA_HERZEGOVINA = 0x141A
    const unsigned long TT_MS_LANGID_SERBIAN_BOSNIA_HERZ_LATIN = 0x181A
    const unsigned long TT_MS_LANGID_SERBIAN_BOSNIA_HERZ_CYRILLIC = 0x1C1A
    const unsigned long TT_MS_LANGID_BOSNIAN_BOSNIA_HERZ_CYRILLIC = 0x201A
    const unsigned long TT_MS_LANGID_SLOVAK_SLOVAKIA = 0x041B
    const unsigned long TT_MS_LANGID_ALBANIAN_ALBANIA = 0x041C
    const unsigned long TT_MS_LANGID_SWEDISH_SWEDEN = 0x041D
    const unsigned long TT_MS_LANGID_SWEDISH_FINLAND = 0x081D
    const unsigned long TT_MS_LANGID_THAI_THAILAND = 0x041E
    const unsigned long TT_MS_LANGID_TURKISH_TURKEY = 0x041F
    const unsigned long TT_MS_LANGID_URDU_PAKISTAN = 0x0420
    const unsigned long TT_MS_LANGID_INDONESIAN_INDONESIA = 0x0421
    const unsigned long TT_MS_LANGID_UKRAINIAN_UKRAINE = 0x0422
    const unsigned long TT_MS_LANGID_BELARUSIAN_BELARUS = 0x0423
    const unsigned long TT_MS_LANGID_SLOVENIAN_SLOVENIA = 0x0424
    const unsigned long TT_MS_LANGID_ESTONIAN_ESTONIA = 0x0425
    const unsigned long TT_MS_LANGID_LATVIAN_LATVIA = 0x0426
    const unsigned long TT_MS_LANGID_LITHUANIAN_LITHUANIA = 0x0427
    const unsigned long TT_MS_LANGID_TAJIK_TAJIKISTAN = 0x0428
    const unsigned long TT_MS_LANGID_VIETNAMESE_VIET_NAM = 0x042A
    const unsigned long TT_MS_LANGID_ARMENIAN_ARMENIA = 0x042B
    const unsigned long TT_MS_LANGID_AZERI_AZERBAIJAN_LATIN = 0x042C
    const unsigned long TT_MS_LANGID_AZERI_AZERBAIJAN_CYRILLIC = 0x082C
    const unsigned long TT_MS_LANGID_BASQUE_BASQUE = 0x042D
    const unsigned long TT_MS_LANGID_UPPER_SORBIAN_GERMANY = 0x042E
    const unsigned long TT_MS_LANGID_LOWER_SORBIAN_GERMANY = 0x082E
    const unsigned long TT_MS_LANGID_MACEDONIAN_MACEDONIA = 0x042F
    const unsigned long TT_MS_LANGID_SETSWANA_SOUTH_AFRICA = 0x0432
    const unsigned long TT_MS_LANGID_ISIXHOSA_SOUTH_AFRICA = 0x0434
    const unsigned long TT_MS_LANGID_ISIZULU_SOUTH_AFRICA = 0x0435
    const unsigned long TT_MS_LANGID_AFRIKAANS_SOUTH_AFRICA = 0x0436
    const unsigned long TT_MS_LANGID_GEORGIAN_GEORGIA = 0x0437
    const unsigned long TT_MS_LANGID_FAEROESE_FAEROE_ISLANDS = 0x0438
    const unsigned long TT_MS_LANGID_HINDI_INDIA = 0x0439
    const unsigned long TT_MS_LANGID_MALTESE_MALTA = 0x043A
    const unsigned long TT_MS_LANGID_SAMI_NORTHERN_NORWAY = 0x043B
    const unsigned long TT_MS_LANGID_SAMI_NORTHERN_SWEDEN = 0x083B
    const unsigned long TT_MS_LANGID_SAMI_NORTHERN_FINLAND = 0x0C3B
    const unsigned long TT_MS_LANGID_SAMI_LULE_NORWAY = 0x103B
    const unsigned long TT_MS_LANGID_SAMI_LULE_SWEDEN = 0x143B
    const unsigned long TT_MS_LANGID_SAMI_SOUTHERN_NORWAY = 0x183B
    const unsigned long TT_MS_LANGID_SAMI_SOUTHERN_SWEDEN = 0x1C3B
    const unsigned long TT_MS_LANGID_SAMI_SKOLT_FINLAND = 0x203B
    const unsigned long TT_MS_LANGID_SAMI_INARI_FINLAND = 0x243B
    const unsigned long TT_MS_LANGID_IRISH_IRELAND = 0x083C
    const unsigned long TT_MS_LANGID_MALAY_MALAYSIA = 0x043E
    const unsigned long TT_MS_LANGID_MALAY_BRUNEI_DARUSSALAM = 0x083E
    const unsigned long TT_MS_LANGID_KAZAKH_KAZAKHSTAN = 0x043F
    const int TT_MS_LANGID_KYRGYZ_KYRGYZSTAN
    const unsigned long TT_MS_LANGID_KISWAHILI_KENYA = 0x0441
    const unsigned long TT_MS_LANGID_TURKMEN_TURKMENISTAN = 0x0442
    const unsigned long TT_MS_LANGID_UZBEK_UZBEKISTAN_LATIN = 0x0443
    const unsigned long TT_MS_LANGID_UZBEK_UZBEKISTAN_CYRILLIC = 0x0843
    const unsigned long TT_MS_LANGID_TATAR_RUSSIA = 0x0444
    const unsigned long TT_MS_LANGID_BENGALI_INDIA = 0x0445
    const unsigned long TT_MS_LANGID_BENGALI_BANGLADESH = 0x0845
    const unsigned long TT_MS_LANGID_PUNJABI_INDIA = 0x0446
    const unsigned long TT_MS_LANGID_GUJARATI_INDIA = 0x0447
    const unsigned long TT_MS_LANGID_ODIA_INDIA = 0x0448
    const unsigned long TT_MS_LANGID_TAMIL_INDIA = 0x0449
    const unsigned long TT_MS_LANGID_TELUGU_INDIA = 0x044A
    const unsigned long TT_MS_LANGID_KANNADA_INDIA = 0x044B
    const unsigned long TT_MS_LANGID_MALAYALAM_INDIA = 0x044C
    const unsigned long TT_MS_LANGID_ASSAMESE_INDIA = 0x044D
    const unsigned long TT_MS_LANGID_MARATHI_INDIA = 0x044E
    const unsigned long TT_MS_LANGID_SANSKRIT_INDIA = 0x044F
    const int TT_MS_LANGID_MONGOLIAN_MONGOLIA
    const unsigned long TT_MS_LANGID_MONGOLIAN_PRC = 0x0850
    const unsigned long TT_MS_LANGID_TIBETAN_PRC = 0x0451
    const unsigned long TT_MS_LANGID_WELSH_UNITED_KINGDOM = 0x0452
    const unsigned long TT_MS_LANGID_KHMER_CAMBODIA = 0x0453
    const unsigned long TT_MS_LANGID_LAO_LAOS = 0x0454
    const unsigned long TT_MS_LANGID_GALICIAN_GALICIAN = 0x0456
    const unsigned long TT_MS_LANGID_KONKANI_INDIA = 0x0457
    const unsigned long TT_MS_LANGID_SYRIAC_SYRIA = 0x045A
    const unsigned long TT_MS_LANGID_SINHALA_SRI_LANKA = 0x045B
    const unsigned long TT_MS_LANGID_INUKTITUT_CANADA = 0x045D
    const unsigned long TT_MS_LANGID_INUKTITUT_CANADA_LATIN = 0x085D
    const unsigned long TT_MS_LANGID_AMHARIC_ETHIOPIA = 0x045E
    const unsigned long TT_MS_LANGID_TAMAZIGHT_ALGERIA = 0x085F
    const unsigned long TT_MS_LANGID_NEPALI_NEPAL = 0x0461
    const unsigned long TT_MS_LANGID_FRISIAN_NETHERLANDS = 0x0462
    const unsigned long TT_MS_LANGID_PASHTO_AFGHANISTAN = 0x0463
    const unsigned long TT_MS_LANGID_FILIPINO_PHILIPPINES = 0x0464
    const unsigned long TT_MS_LANGID_DHIVEHI_MALDIVES = 0x0465
    const unsigned long TT_MS_LANGID_HAUSA_NIGERIA = 0x0468
    const unsigned long TT_MS_LANGID_YORUBA_NIGERIA = 0x046A
    const unsigned long TT_MS_LANGID_QUECHUA_BOLIVIA = 0x046B
    const unsigned long TT_MS_LANGID_QUECHUA_ECUADOR = 0x086B
    const unsigned long TT_MS_LANGID_QUECHUA_PERU = 0x0C6B
    const unsigned long TT_MS_LANGID_SESOTHO_SA_LEBOA_SOUTH_AFRICA = 0x046C
    const unsigned long TT_MS_LANGID_BASHKIR_RUSSIA = 0x046D
    const unsigned long TT_MS_LANGID_LUXEMBOURGISH_LUXEMBOURG = 0x046E
    const unsigned long TT_MS_LANGID_GREENLANDIC_GREENLAND = 0x046F
    const unsigned long TT_MS_LANGID_IGBO_NIGERIA = 0x0470
    const unsigned long TT_MS_LANGID_YI_PRC = 0x0478
    const unsigned long TT_MS_LANGID_MAPUDUNGUN_CHILE = 0x047A
    const unsigned long TT_MS_LANGID_MOHAWK_MOHAWK = 0x047C
    const unsigned long TT_MS_LANGID_BRETON_FRANCE = 0x047E
    const unsigned long TT_MS_LANGID_UIGHUR_PRC = 0x0480
    const unsigned long TT_MS_LANGID_MAORI_NEW_ZEALAND = 0x0481
    const unsigned long TT_MS_LANGID_OCCITAN_FRANCE = 0x0482
    const unsigned long TT_MS_LANGID_CORSICAN_FRANCE = 0x0483
    const unsigned long TT_MS_LANGID_ALSATIAN_FRANCE = 0x0484
    const unsigned long TT_MS_LANGID_YAKUT_RUSSIA = 0x0485
    const unsigned long TT_MS_LANGID_KICHE_GUATEMALA = 0x0486
    const unsigned long TT_MS_LANGID_KINYARWANDA_RWANDA = 0x0487
    const unsigned long TT_MS_LANGID_WOLOF_SENEGAL = 0x0488
    const unsigned long TT_MS_LANGID_DARI_AFGHANISTAN = 0x048C
    const unsigned long TT_MS_LANGID_ARABIC_GENERAL = 0x0001
    const int TT_MS_LANGID_CATALAN_SPAIN
    const unsigned long TT_MS_LANGID_CHINESE_GENERAL = 0x0004
    const int TT_MS_LANGID_CHINESE_MACAU
    const int TT_MS_LANGID_GERMAN_LIECHTENSTEI
    const unsigned long TT_MS_LANGID_ENGLISH_GENERAL = 0x0009
    const unsigned long TT_MS_LANGID_ENGLISH_INDONESIA = 0x3809
    const unsigned long TT_MS_LANGID_ENGLISH_HONG_KONG = 0x3C09
    const int TT_MS_LANGID_SPANISH_SPAIN_INTERNATIONAL_SORT
    const unsigned long TT_MS_LANGID_SPANISH_LATIN_AMERICA = 0xE40AU
    const unsigned long TT_MS_LANGID_FRENCH_WEST_INDIES = 0x1C0C
    const unsigned long TT_MS_LANGID_FRENCH_REUNION = 0x200C
    const unsigned long TT_MS_LANGID_FRENCH_CONGO = 0x240C
    const int TT_MS_LANGID_FRENCH_ZAIRE
    const unsigned long TT_MS_LANGID_FRENCH_SENEGAL = 0x280C
    const unsigned long TT_MS_LANGID_FRENCH_CAMEROON = 0x2C0C
    const unsigned long TT_MS_LANGID_FRENCH_COTE_D_IVOIRE = 0x300C
    const unsigned long TT_MS_LANGID_FRENCH_MALI = 0x340C
    const unsigned long TT_MS_LANGID_FRENCH_MOROCCO = 0x380C
    const unsigned long TT_MS_LANGID_FRENCH_HAITI = 0x3C0C
    const unsigned long TT_MS_LANGID_FRENCH_NORTH_AFRICA = 0xE40CU
    const int TT_MS_LANGID_KOREAN_EXTENDED_WANSUNG_KOREA
    const unsigned long TT_MS_LANGID_KOREAN_JOHAB_KOREA = 0x0812
    const int TT_MS_LANGID_RHAETO_ROMANIC_SWITZERLAND
    const unsigned long TT_MS_LANGID_MOLDAVIAN_MOLDAVIA = 0x0818
    const unsigned long TT_MS_LANGID_RUSSIAN_MOLDAVIA = 0x0819
    const unsigned long TT_MS_LANGID_URDU_INDIA = 0x0820
    const unsigned long TT_MS_LANGID_CLASSIC_LITHUANIAN_LITHUANIA = 0x0827
    const int TT_MS_LANGID_SLOVENE_SLOVENIA
    const unsigned long TT_MS_LANGID_FARSI_IRAN = 0x0429
    const int TT_MS_LANGID_BASQUE_SPAIN
    const int TT_MS_LANGID_SORBIAN_GERMANY
    const unsigned long TT_MS_LANGID_SUTU_SOUTH_AFRICA = 0x0430
    const unsigned long TT_MS_LANGID_TSONGA_SOUTH_AFRICA = 0x0431
    const int TT_MS_LANGID_TSWANA_SOUTH_AFRICA
    const unsigned long TT_MS_LANGID_VENDA_SOUTH_AFRICA = 0x0433
    const int TT_MS_LANGID_XHOSA_SOUTH_AFRICA
    const int TT_MS_LANGID_ZULU_SOUTH_AFRICA
    const unsigned long TT_MS_LANGID_SAAMI_LAPONIA = 0x043B
    const unsigned long TT_MS_LANGID_IRISH_GAELIC_IRELAND = 0x043C
    const unsigned long TT_MS_LANGID_SCOTTISH_GAELIC_UNITED_KINGDOM = 0x083C
    const unsigned long TT_MS_LANGID_YIDDISH_GERMANY = 0x043D
    const int TT_MS_LANGID_KAZAK_KAZAKSTAN
    const int TT_MS_LANGID_KIRGHIZ_KIRGHIZ_REPUBLIC
    const int TT_MS_LANGID_KIRGHIZ_KIRGHIZSTAN
    const int TT_MS_LANGID_SWAHILI_KENYA
    const int TT_MS_LANGID_TATAR_TATARSTAN
    const unsigned long TT_MS_LANGID_PUNJABI_ARABIC_PAKISTAN = 0x0846
    const int TT_MS_LANGID_ORIYA_INDIA
    const int TT_MS_LANGID_MONGOLIAN_MONGOLIA_MONGOLIAN
    const int TT_MS_LANGID_TIBETAN_CHINA
    const unsigned long TT_MS_LANGID_DZONGHKA_BHUTAN = 0x0851
    const int TT_MS_LANGID_TIBETAN_BHUTAN
    const int TT_MS_LANGID_WELSH_WALES
    const unsigned long TT_MS_LANGID_BURMESE_MYANMAR = 0x0455
    const int TT_MS_LANGID_GALICIAN_SPAIN
    const int TT_MS_LANGID_MANIPURI_INDIA
    const int TT_MS_LANGID_SINDHI_INDIA
    const unsigned long TT_MS_LANGID_SINDHI_PAKISTAN = 0x0859
    const int TT_MS_LANGID_SINHALESE_SRI_LANKA
    const unsigned long TT_MS_LANGID_CHEROKEE_UNITED_STATES = 0x045C
    const int TT_MS_LANGID_TAMAZIGHT_MOROCCO
    const int TT_MS_LANGID_TAMAZIGHT_MOROCCO_LATIN
    const int TT_MS_LANGID_KASHMIRI_PAKISTAN
    const unsigned long TT_MS_LANGID_KASHMIRI_SASIA = 0x0860
    const int TT_MS_LANGID_KASHMIRI_INDIA
    const unsigned long TT_MS_LANGID_NEPALI_INDIA = 0x0861
    const int TT_MS_LANGID_DIVEHI_MALDIVES
    const unsigned long TT_MS_LANGID_EDO_NIGERIA = 0x0466
    const unsigned long TT_MS_LANGID_FULFULDE_NIGERIA = 0x0467
    const unsigned long TT_MS_LANGID_IBIBIO_NIGERIA = 0x0469
    const int TT_MS_LANGID_SEPEDI_SOUTH_AFRICA
    const int TT_MS_LANGID_SOTHO_SOUTHERN_SOUTH_AFRICA
    const unsigned long TT_MS_LANGID_KANURI_NIGERIA = 0x0471
    const unsigned long TT_MS_LANGID_OROMO_ETHIOPIA = 0x0472
    const unsigned long TT_MS_LANGID_TIGRIGNA_ETHIOPIA = 0x0473
    const unsigned long TT_MS_LANGID_TIGRIGNA_ERYTHREA = 0x0873
    const int TT_MS_LANGID_TIGRIGNA_ERYTREA
    const unsigned long TT_MS_LANGID_GUARANI_PARAGUAY = 0x0474
    const unsigned long TT_MS_LANGID_HAWAIIAN_UNITED_STATES = 0x0475
    const unsigned long TT_MS_LANGID_LATIN = 0x0476
    const unsigned long TT_MS_LANGID_SOMALI_SOMALIA = 0x0477
    const int TT_MS_LANGID_YI_CHINA
    const unsigned long TT_MS_LANGID_PAPIAMENTU_NETHERLANDS_ANTILLES = 0x0479
    const int TT_MS_LANGID_UIGHUR_CHINA
    const long TT_NAME_ID_COPYRIGHT = 0
    const long TT_NAME_ID_FONT_FAMILY = 1
    const long TT_NAME_ID_FONT_SUBFAMILY = 2
    const long TT_NAME_ID_UNIQUE_ID = 3
    const long TT_NAME_ID_FULL_NAME = 4
    const long TT_NAME_ID_VERSION_STRING = 5
    const long TT_NAME_ID_PS_NAME = 6
    const long TT_NAME_ID_TRADEMARK = 7
    const long TT_NAME_ID_MANUFACTURER = 8
    const long TT_NAME_ID_DESIGNER = 9
    const long TT_NAME_ID_DESCRIPTION = 10
    const long TT_NAME_ID_VENDOR_URL = 11
    const long TT_NAME_ID_DESIGNER_URL = 12
    const long TT_NAME_ID_LICENSE = 13
    const long TT_NAME_ID_LICENSE_URL = 14
    const long TT_NAME_ID_TYPOGRAPHIC_FAMILY = 16
    const long TT_NAME_ID_TYPOGRAPHIC_SUBFAMILY = 17
    const long TT_NAME_ID_MAC_FULL_NAME = 18
    const long TT_NAME_ID_SAMPLE_TEXT = 19
    const long TT_NAME_ID_CID_FINDFONT_NAME = 20
    const long TT_NAME_ID_WWS_FAMILY = 21
    const long TT_NAME_ID_WWS_SUBFAMILY = 22
    const long TT_NAME_ID_LIGHT_BACKGROUND = 23
    const long TT_NAME_ID_DARK_BACKGROUND = 24
    const long TT_NAME_ID_VARIATIONS_PREFIX = 25
    const int TT_NAME_ID_PREFERRED_FAMILY
    const int TT_NAME_ID_PREFERRED_SUBFAMILY
    const int TT_UCR_BASIC_LATIN
    const int TT_UCR_LATIN1_SUPPLEMENT
    const int TT_UCR_LATIN_EXTENDED_A
    const int TT_UCR_LATIN_EXTENDED_B
    const int TT_UCR_IPA_EXTENSIONS
    const int TT_UCR_SPACING_MODIFIER
    const int TT_UCR_COMBINING_DIACRITICAL_MARKS
    const int TT_UCR_GREEK
    const int TT_UCR_COPTIC
    const int TT_UCR_CYRILLIC
    const int TT_UCR_ARMENIAN
    const int TT_UCR_HEBREW
    const int TT_UCR_VAI
    const int TT_UCR_ARABIC
    const int TT_UCR_NKO
    const int TT_UCR_DEVANAGARI
    const int TT_UCR_BENGALI
    const int TT_UCR_GURMUKHI
    const int TT_UCR_GUJARATI
    const int TT_UCR_ORIYA
    const int TT_UCR_TAMIL
    const int TT_UCR_TELUGU
    const int TT_UCR_KANNADA
    const int TT_UCR_MALAYALAM
    const int TT_UCR_THAI
    const int TT_UCR_LAO
    const int TT_UCR_GEORGIAN
    const int TT_UCR_BALINESE
    const int TT_UCR_HANGUL_JAMO
    const int TT_UCR_LATIN_EXTENDED_ADDITIONAL
    const int TT_UCR_GREEK_EXTENDED
    const int TT_UCR_GENERAL_PUNCTUATION
    const int TT_UCR_SUPERSCRIPTS_SUBSCRIPTS
    const int TT_UCR_CURRENCY_SYMBOLS
    const int TT_UCR_COMBINING_DIACRITICAL_MARKS_SYMB
    const int TT_UCR_LETTERLIKE_SYMBOLS
    const int TT_UCR_NUMBER_FORMS
    const int TT_UCR_ARROWS
    const int TT_UCR_MATHEMATICAL_OPERATORS
    const int TT_UCR_MISCELLANEOUS_TECHNICAL
    const int TT_UCR_CONTROL_PICTURES
    const int TT_UCR_OCR
    const int TT_UCR_ENCLOSED_ALPHANUMERICS
    const int TT_UCR_BOX_DRAWING
    const int TT_UCR_BLOCK_ELEMENTS
    const int TT_UCR_GEOMETRIC_SHAPES
    const int TT_UCR_MISCELLANEOUS_SYMBOLS
    const int TT_UCR_DINGBATS
    const int TT_UCR_CJK_SYMBOLS
    const int TT_UCR_HIRAGANA
    const int TT_UCR_KATAKANA
    const int TT_UCR_BOPOMOFO
    const int TT_UCR_HANGUL_COMPATIBILITY_JAMO
    const int TT_UCR_CJK_MISC
    const int TT_UCR_KANBUN
    const int TT_UCR_PHAGSPA
    const int TT_UCR_ENCLOSED_CJK_LETTERS_MONTHS
    const int TT_UCR_CJK_COMPATIBILITY
    const int TT_UCR_HANGUL
    const int TT_UCR_SURROGATES
    const int TT_UCR_NON_PLANE_0
    const int TT_UCR_PHOENICIAN
    const int TT_UCR_CJK_UNIFIED_IDEOGRAPHS
    const int TT_UCR_PRIVATE_USE
    const int TT_UCR_CJK_COMPATIBILITY_IDEOGRAPHS
    const int TT_UCR_ALPHABETIC_PRESENTATION_FORMS
    const int TT_UCR_ARABIC_PRESENTATION_FORMS_A
    const int TT_UCR_COMBINING_HALF_MARKS
    const int TT_UCR_CJK_COMPATIBILITY_FORMS
    const int TT_UCR_SMALL_FORM_VARIANTS
    const int TT_UCR_ARABIC_PRESENTATION_FORMS_B
    const int TT_UCR_HALFWIDTH_FULLWIDTH_FORMS
    const int TT_UCR_SPECIALS
    const int TT_UCR_TIBETAN
    const int TT_UCR_SYRIAC
    const int TT_UCR_THAANA
    const int TT_UCR_SINHALA
    const int TT_UCR_MYANMAR
    const int TT_UCR_ETHIOPIC
    const int TT_UCR_CHEROKEE
    const int TT_UCR_CANADIAN_ABORIGINAL_SYLLABICS
    const int TT_UCR_OGHAM
    const int TT_UCR_RUNIC
    const int TT_UCR_KHMER
    const int TT_UCR_MONGOLIAN
    const int TT_UCR_BRAILLE
    const int TT_UCR_YI
    const int TT_UCR_PHILIPPINE
    const int TT_UCR_OLD_ITALIC
    const int TT_UCR_GOTHIC
    const int TT_UCR_DESERET
    const int TT_UCR_MUSICAL_SYMBOLS
    const int TT_UCR_MATH_ALPHANUMERIC_SYMBOLS
    const int TT_UCR_PRIVATE_USE_SUPPLEMENTARY
    const int TT_UCR_VARIATION_SELECTORS
    const int TT_UCR_TAGS
    const int TT_UCR_LIMBU
    const int TT_UCR_TAI_LE
    const int TT_UCR_NEW_TAI_LUE
    const int TT_UCR_BUGINESE
    const int TT_UCR_GLAGOLITIC
    const int TT_UCR_TIFINAGH
    const int TT_UCR_YIJING
    const int TT_UCR_SYLOTI_NAGRI
    const int TT_UCR_LINEAR_B
    const int TT_UCR_ANCIENT_GREEK_NUMBERS
    const int TT_UCR_UGARITIC
    const int TT_UCR_OLD_PERSIAN
    const int TT_UCR_SHAVIAN
    const int TT_UCR_OSMANYA
    const int TT_UCR_CYPRIOT_SYLLABARY
    const int TT_UCR_KHAROSHTHI
    const int TT_UCR_TAI_XUAN_JING
    const int TT_UCR_CUNEIFORM
    const int TT_UCR_COUNTING_ROD_NUMERALS
    const int TT_UCR_SUNDANESE
    const int TT_UCR_LEPCHA
    const int TT_UCR_OL_CHIKI
    const int TT_UCR_SAURASHTRA
    const int TT_UCR_KAYAH_LI
    const int TT_UCR_REJANG
    const int TT_UCR_CHAM
    const int TT_UCR_ANCIENT_SYMBOLS
    const int TT_UCR_PHAISTOS_DISC
    const int TT_UCR_OLD_ANATOLIAN
    const int TT_UCR_GAME_TILES
    const int TT_UCR_ARABIC_PRESENTATION_A
    const int TT_UCR_ARABIC_PRESENTATION_B
    const int TT_UCR_COMBINING_DIACRITICS
    const int TT_UCR_COMBINING_DIACRITICS_SYMB


cdef extern from "freetype/tttables.h":
    const int ft_sfnt_head
    const int ft_sfnt_maxp
    const int ft_sfnt_os2
    const int ft_sfnt_hhea
    const int ft_sfnt_vhea
    const int ft_sfnt_post
    const int ft_sfnt_pclt
    struct TT_Header_:
        int Table_Version
        int Font_Revision
        int CheckSum_Adjust
        int Magic_Number
        int Flags
        int Units_Per_EM
        int Created[2]
        int Modified[2]
        int xMin
        int yMin
        int xMax
        int yMax
        int Mac_Style
        int Lowest_Rec_PPEM
        int Font_Direction
        int Index_To_Loc_Format
        int Glyph_Data_Format
    ctypedef int TT_Header
    struct TT_HoriHeader_:
        int Version
        int Ascender
        int Descender
        int Line_Gap
        int advance_Width_Max
        int min_Left_Side_Bearing
        int min_Right_Side_Bearing
        int xMax_Extent
        int caret_Slope_Rise
        int caret_Slope_Run
        int caret_Offset
        int Reserved[4]
        int metric_Data_Format
        int number_Of_HMetrics
        void* long_metrics
        void* short_metrics
    ctypedef TT_HoriHeader_ TT_HoriHeader
    struct TT_VertHeader_:
        int Version
        int Ascender
        int Descender
        int Line_Gap
        int advance_Height_Max
        int min_Top_Side_Bearing
        int min_Bottom_Side_Bearing
        int yMax_Extent
        int caret_Slope_Rise
        int caret_Slope_Run
        int caret_Offset
        int Reserved[4]
        int metric_Data_Format
        int number_Of_VMetrics
        void* long_metrics
        void* short_metrics
    ctypedef TT_VertHeader_ TT_VertHeader
    struct TT_OS2_:
        int version
        int xAvgCharWidth
        int usWeightClass
        int usWidthClass
        int fsType
        int ySubscriptXSize
        int ySubscriptYSize
        int ySubscriptXOffset
        int ySubscriptYOffset
        int ySuperscriptXSize
        int ySuperscriptYSize
        int ySuperscriptXOffset
        int ySuperscriptYOffset
        int yStrikeoutSize
        int yStrikeoutPosition
        int sFamilyClass
        int panose[10]
        int ulUnicodeRange1
        int ulUnicodeRange2
        int ulUnicodeRange3
        int ulUnicodeRange4
        int achVendID[4]
        int fsSelection
        int usFirstCharIndex
        int usLastCharIndex
        int sTypoAscender
        int sTypoDescender
        int sTypoLineGap
        int usWinAscent
        int usWinDescent
        int ulCodePageRange1
        int ulCodePageRange2
        int sxHeight
        int sCapHeight
        int usDefaultChar
        int usBreakChar
        int usMaxContext
        int usLowerOpticalPointSize
        int usUpperOpticalPointSize
    ctypedef TT_OS2_ TT_OS2
    struct TT_Postscript_:
        int FormatType
        int italicAngle
        int underlinePosition
        int underlineThickness
        int isFixedPitch
        int minMemType42
        int maxMemType42
        int minMemType1
        int maxMemType1
    ctypedef TT_Postscript_ TT_Postscript
    struct TT_PCLT_:
        int Version
        int FontNumber
        int Pitch
        int xHeight
        int Style
        int TypeFamily
        int CapHeight
        int SymbolSet
        int TypeFace[16]
        int CharacterComplement[8]
        int FileName[6]
        int StrokeWeight
        int WidthType
        int SerifStyle
        int Reserved
    ctypedef TT_PCLT_ TT_PCLT
    struct TT_MaxProfile_:
        int version
        int numGlyphs
        int maxPoints
        int maxContours
        int maxCompositePoints
        int maxCompositeContours
        int maxZones
        int maxTwilightPoints
        int maxStorage
        int maxFunctionDefs
        int maxInstructionDefs
        int maxStackElements
        int maxSizeOfInstructions
        int maxComponentElements
        int maxComponentDepth
    ctypedef TT_MaxProfile_ TT_MaxProfile
    enum FT_Sfnt_Tag_:
        FT_SFNT_HEAD = 0
        FT_SFNT_MAXP = 1
        FT_SFNT_OS2 = 2
        FT_SFNT_HHEA = 3
        FT_SFNT_VHEA = 4
        FT_SFNT_POST = 5
        FT_SFNT_PCLT = 6
        FT_SFNT_MAX = 7
    ctypedef FT_Sfnt_Tag_ FT_Sfnt_Tag


cdef extern from "freetype/tttags.h":
    const int TTAGS_H_
    const int TTAG_avar
    const int TTAG_BASE
    const int TTAG_bdat
    const int TTAG_BDF
    const int TTAG_bhed
    const int TTAG_bloc
    const int TTAG_bsln
    const int TTAG_CBDT
    const int TTAG_CBLC
    const int TTAG_CFF
    const int TTAG_CFF2
    const int TTAG_CID
    const int TTAG_cmap
    const int TTAG_COLR
    const int TTAG_CPAL
    const int TTAG_cvar
    const int TTAG_cvt
    const int TTAG_DSIG
    const int TTAG_EBDT
    const int TTAG_EBLC
    const int TTAG_EBSC
    const int TTAG_feat
    const int TTAG_FOND
    const int TTAG_fpgm
    const int TTAG_fvar
    const int TTAG_gasp
    const int TTAG_GDEF
    const int TTAG_glyf
    const int TTAG_GPOS
    const int TTAG_GSUB
    const int TTAG_gvar
    const int TTAG_HVAR
    const int TTAG_hdmx
    const int TTAG_head
    const int TTAG_hhea
    const int TTAG_hmtx
    const int TTAG_JSTF
    const int TTAG_just
    const int TTAG_kern
    const int TTAG_lcar
    const int TTAG_loca
    const int TTAG_LTSH
    const int TTAG_LWFN
    const int TTAG_MATH
    const int TTAG_maxp
    const int TTAG_META
    const int TTAG_MMFX
    const int TTAG_MMSD
    const int TTAG_mort
    const int TTAG_morx
    const int TTAG_MVAR
    const int TTAG_name
    const int TTAG_opbd
    const int TTAG_OS2
    const int TTAG_OTTO
    const int TTAG_PCLT
    const int TTAG_POST
    const int TTAG_post
    const int TTAG_prep
    const int TTAG_prop
    const int TTAG_sbix
    const int TTAG_sfnt
    const int TTAG_SING
    const int TTAG_SVG
    const int TTAG_trak
    const int TTAG_true
    const int TTAG_ttc
    const int TTAG_ttcf
    const int TTAG_TYP1
    const int TTAG_typ1
    const int TTAG_VDMX
    const int TTAG_vhea
    const int TTAG_vmtx
    const int TTAG_VVAR
    const int TTAG_wOFF
    const int TTAG_wOF2
    const int TTAG_0xA5kbd
    const int TTAG_0xA5lst


cdef extern from "freetype/freetype.h":
    struct FT_DriverRec_:
        pass
    struct FT_SubGlyphRec_:
        pass
    struct FT_Size_InternalRec_:
        pass
    struct FT_Slot_InternalRec_:
        pass
    struct FT_ModuleRec_:
        pass
    struct FT_LibraryRec_:
        pass
    struct FT_Face_InternalRec_:
        pass
    struct FT_RendererRec_:
        pass
    const int FT_ENC_TAG(...)
    const int ft_encoding_none
    const int ft_encoding_unicode
    const int ft_encoding_symbol
    const int ft_encoding_latin_1
    const int ft_encoding_latin_2
    const int ft_encoding_sjis
    const int ft_encoding_gb2312
    const int ft_encoding_big5
    const int ft_encoding_wansung
    const int ft_encoding_johab
    const int ft_encoding_adobe_standard
    const int ft_encoding_adobe_expert
    const int ft_encoding_adobe_custom
    const int ft_encoding_apple_roman
    const int FT_FACE_FLAG_SCALABLE
    const int FT_FACE_FLAG_FIXED_SIZES
    const int FT_FACE_FLAG_FIXED_WIDTH
    const int FT_FACE_FLAG_SFNT
    const int FT_FACE_FLAG_HORIZONTAL
    const int FT_FACE_FLAG_VERTICAL
    const int FT_FACE_FLAG_KERNING
    const int FT_FACE_FLAG_FAST_GLYPHS
    const int FT_FACE_FLAG_MULTIPLE_MASTERS
    const int FT_FACE_FLAG_GLYPH_NAMES
    const int FT_FACE_FLAG_EXTERNAL_STREAM
    const int FT_FACE_FLAG_HINTER
    const int FT_FACE_FLAG_CID_KEYED
    const int FT_FACE_FLAG_TRICKY
    const int FT_FACE_FLAG_COLOR
    const int FT_FACE_FLAG_VARIATION
    const int FT_FACE_FLAG_SVG
    const int FT_FACE_FLAG_SBIX
    const int FT_FACE_FLAG_SBIX_OVERLAY
    const int FT_HAS_HORIZONTAL(...)
    const int FT_HAS_VERTICAL(...)
    const int FT_HAS_KERNING(...)
    const int FT_IS_SCALABLE(...)
    const int FT_IS_SFNT(...)
    const int FT_IS_FIXED_WIDTH(...)
    const int FT_HAS_FIXED_SIZES(...)
    const long FT_HAS_FAST_GLYPHS(...)
    const int FT_HAS_GLYPH_NAMES(...)
    const int FT_HAS_MULTIPLE_MASTERS(...)
    const int FT_IS_NAMED_INSTANCE(...)
    const int FT_IS_VARIATION(...)
    const int FT_IS_CID_KEYED(...)
    const int FT_IS_TRICKY(...)
    const int FT_HAS_COLOR(...)
    const int FT_HAS_SVG(...)
    const int FT_HAS_SBIX(...)
    const int FT_HAS_SBIX_OVERLAY(...)
    const int FT_STYLE_FLAG_ITALIC
    const int FT_STYLE_FLAG_BOLD
    const unsigned long FT_OPEN_MEMORY = 0x1
    const unsigned long FT_OPEN_STREAM = 0x2
    const unsigned long FT_OPEN_PATHNAME = 0x4
    const unsigned long FT_OPEN_DRIVER = 0x8
    const unsigned long FT_OPEN_PARAMS = 0x10
    const int ft_open_memory
    const int ft_open_stream
    const int ft_open_pathname
    const int ft_open_driver
    const int ft_open_params
    const unsigned long FT_LOAD_DEFAULT = 0x0
    const int FT_LOAD_NO_SCALE
    const int FT_LOAD_NO_HINTING
    const int FT_LOAD_RENDER
    const int FT_LOAD_NO_BITMAP
    const int FT_LOAD_VERTICAL_LAYOUT
    const int FT_LOAD_FORCE_AUTOHINT
    const int FT_LOAD_CROP_BITMAP
    const int FT_LOAD_PEDANTIC
    const int FT_LOAD_IGNORE_GLOBAL_ADVANCE_WIDTH
    const int FT_LOAD_NO_RECURSE
    const int FT_LOAD_IGNORE_TRANSFORM
    const int FT_LOAD_MONOCHROME
    const int FT_LOAD_LINEAR_DESIGN
    const int FT_LOAD_SBITS_ONLY
    const int FT_LOAD_NO_AUTOHINT
    const int FT_LOAD_COLOR
    const int FT_LOAD_COMPUTE_METRICS
    const int FT_LOAD_BITMAP_METRICS_ONLY
    const int FT_LOAD_NO_SVG
    const int FT_LOAD_ADVANCE_ONLY
    const int FT_LOAD_SVG_ONLY
    const int FT_LOAD_TARGET_(...)
    const int FT_LOAD_TARGET_NORMAL
    const int FT_LOAD_TARGET_LIGHT
    const int FT_LOAD_TARGET_MONO
    const int FT_LOAD_TARGET_LCD
    const int FT_LOAD_TARGET_LCD_V
    const int FT_LOAD_TARGET_MODE(...)
    const int ft_render_mode_normal
    const int ft_render_mode_mono
    const int ft_kerning_default
    const int ft_kerning_unfitted
    const int ft_kerning_unscaled
    const long FT_SUBGLYPH_FLAG_ARGS_ARE_WORDS = 1
    const long FT_SUBGLYPH_FLAG_ARGS_ARE_XY_VALUES = 2
    const long FT_SUBGLYPH_FLAG_ROUND_XY_TO_GRID = 4
    const long FT_SUBGLYPH_FLAG_SCALE = 8
    const unsigned long FT_SUBGLYPH_FLAG_XY_SCALE = 0x40
    const unsigned long FT_SUBGLYPH_FLAG_2X2 = 0x80
    const unsigned long FT_SUBGLYPH_FLAG_USE_MY_METRICS = 0x200
    const unsigned long FT_FSTYPE_INSTALLABLE_EMBEDDING = 0x0000
    const unsigned long FT_FSTYPE_RESTRICTED_LICENSE_EMBEDDING = 0x0002
    const unsigned long FT_FSTYPE_PREVIEW_AND_PRINT_EMBEDDING = 0x0004
    const unsigned long FT_FSTYPE_EDITABLE_EMBEDDING = 0x0008
    const unsigned long FT_FSTYPE_NO_SUBSETTING = 0x0100
    const unsigned long FT_FSTYPE_BITMAP_EMBEDDING_ONLY = 0x0200
    const long FREETYPE_MAJOR = 2
    const long FREETYPE_MINOR = 13
    const long FREETYPE_PATCH = 3
    struct FT_Glyph_Metrics_:
        FT_Pos width
        FT_Pos height
        FT_Pos horiBearingX
        FT_Pos horiBearingY
        FT_Pos horiAdvance
        FT_Pos vertBearingX
        FT_Pos vertBearingY
        FT_Pos vertAdvance
    ctypedef FT_Glyph_Metrics_ FT_Glyph_Metrics
    struct FT_Bitmap_Size_:
        int height
        int width
        int size
        int x_ppem
        int y_ppem
    ctypedef FT_Bitmap_Size_ FT_Bitmap_Size
    ctypedef FT_LibraryRec_* FT_Library
    ctypedef FT_ModuleRec_* FT_Module
    ctypedef FT_DriverRec_* FT_Driver
    ctypedef FT_RendererRec_* FT_Renderer
    ctypedef FT_FaceRec_* FT_Face
    ctypedef FT_SizeRec_* FT_Size
    ctypedef FT_GlyphSlotRec_* FT_GlyphSlot
    ctypedef FT_CharMapRec_* FT_CharMap
    enum FT_Encoding_:
        FT_ENCODING_NONE = 0
        FT_ENCODING_MS_SYMBOL = 1
        FT_ENCODING_UNICODE = 2
        FT_ENCODING_SJIS = 3
        FT_ENCODING_PRC = 4
        FT_ENCODING_BIG5 = 5
        FT_ENCODING_WANSUNG = 6
        FT_ENCODING_JOHAB = 7
        FT_ENCODING_GB2312 = 4
        FT_ENCODING_MS_SJIS = 3
        FT_ENCODING_MS_GB2312 = 4
        FT_ENCODING_MS_BIG5 = 5
        FT_ENCODING_MS_WANSUNG = 6
        FT_ENCODING_MS_JOHAB = 7
        FT_ENCODING_ADOBE_STANDARD = 8
        FT_ENCODING_ADOBE_EXPERT = 9
        FT_ENCODING_ADOBE_CUSTOM = 10
        FT_ENCODING_ADOBE_LATIN_1 = 11
        FT_ENCODING_OLD_LATIN_2 = 12
        FT_ENCODING_APPLE_ROMAN = 13
    ctypedef FT_Encoding_ FT_Encoding
    struct FT_CharMapRec_:
        FT_Face face
        FT_Encoding encoding
        int platform_id
        int encoding_id
    ctypedef FT_CharMapRec_ FT_CharMapRec
    ctypedef FT_Face_InternalRec_* FT_Face_Internal
    struct FT_FaceRec_:
        int num_faces
        int face_index
        int face_flags
        int style_flags
        int num_glyphs
        int* family_name
        int* style_name
        int num_fixed_sizes
        FT_Bitmap_Size* available_sizes
        int num_charmaps
        FT_CharMap* charmaps
        int generic
        int bbox
        int units_per_EM
        int ascender
        int descender
        int height
        int max_advance_width
        int max_advance_height
        int underline_position
        int underline_thickness
        FT_GlyphSlot glyph
        FT_Size size
        FT_CharMap charmap
        FT_Driver driver
        int memory
        int stream
        int sizes_list
        int autohint
        void* extensions
        FT_Face_Internal internal
    ctypedef FT_FaceRec_ FT_FaceRec
    ctypedef FT_Size_InternalRec_* FT_Size_Internal
    struct FT_Size_Metrics_:
        int x_ppem
        int y_ppem
        int x_scale
        int y_scale
        int ascender
        int descender
        int height
        int max_advance
    ctypedef FT_Size_Metrics_ FT_Size_Metrics
    struct FT_SizeRec_:
        FT_Face face
        int generic
        FT_Size_Metrics metrics
        FT_Size_Internal internal
    ctypedef FT_SizeRec_ FT_SizeRec
    ctypedef FT_SubGlyphRec_* FT_SubGlyph
    ctypedef FT_Slot_InternalRec_* FT_Slot_Internal
    struct FT_GlyphSlotRec_:
        FT_Library library
        FT_Face face
        FT_GlyphSlot next
        FT_UInt glyph_index
        FT_Generic  generic
        FT_Glyph_Metrics metrics
        FT_Fixed linearHoriAdvance
        FT_Fixed linearVertAdvance
        FT_Vector advance
        FT_Glyph_Format format
        FT_Bitmap  bitmap
        FT_Int bitmap_left
        FT_Int bitmap_top
        FT_Outline outline
        FT_UInt num_subglyphs
        FT_SubGlyph subglyphs
        void* control_data
        long control_len
        FT_Pos lsb_delta
        FT_Pos rsb_delta
        void* other
        FT_Slot_Internal internal
    ctypedef FT_GlyphSlotRec_ FT_GlyphSlotRec
    struct FT_Parameter_:
        int tag
        int data
    ctypedef FT_Parameter_ FT_Parameter
    struct FT_Open_Args_:
        int flags
        const int* memory_base
        int memory_size
        int* pathname
        int stream
        FT_Module driver
        int num_params
        FT_Parameter* params
    ctypedef FT_Open_Args_ FT_Open_Args
    enum FT_Size_Request_Type_:
        FT_SIZE_REQUEST_TYPE_NOMINAL = 0
        FT_SIZE_REQUEST_TYPE_REAL_DIM = 1
        FT_SIZE_REQUEST_TYPE_BBOX = 2
        FT_SIZE_REQUEST_TYPE_CELL = 3
        FT_SIZE_REQUEST_TYPE_SCALES = 4
        FT_SIZE_REQUEST_TYPE_MAX = 5
    ctypedef FT_Size_Request_Type_ FT_Size_Request_Type
    struct FT_Size_RequestRec_:
        FT_Size_Request_Type type
        int width
        int height
        int horiResolution
        int vertResolution
    ctypedef FT_Size_RequestRec_ FT_Size_RequestRec
    ctypedef FT_Size_RequestRec_* FT_Size_Request
    enum FT_Render_Mode_:
        FT_RENDER_MODE_NORMAL = 0
        FT_RENDER_MODE_LIGHT = 1
        FT_RENDER_MODE_MONO = 2
        FT_RENDER_MODE_LCD = 3
        FT_RENDER_MODE_LCD_V = 4
        FT_RENDER_MODE_SDF = 5
        FT_RENDER_MODE_MAX = 6
    ctypedef FT_Render_Mode_ FT_Render_Mode
    enum FT_Kerning_Mode_:
        FT_KERNING_DEFAULT = 0
        FT_KERNING_UNFITTED = 1
        FT_KERNING_UNSCALED = 2
    ctypedef FT_Kerning_Mode_ FT_Kerning_Mode
    FT_Error FT_Init_FreeType(FT_Library* alibrary)
    FT_Error FT_Done_FreeType(FT_Library library)
    
    # Face management
    FT_Error FT_New_Face(FT_Library library, const char* filepathname, FT_Long face_index, FT_Face* aface)
    FT_Error FT_New_Memory_Face(FT_Library library, const FT_Byte* file_base, FT_Long file_size, 
                               FT_Long face_index, FT_Face* aface)
    FT_Error FT_Done_Face(FT_Face face)
    
    # Size management
    FT_Error FT_Set_Char_Size(FT_Face face, FT_F26Dot6 char_width, FT_F26Dot6 char_height,
                             FT_UInt horz_resolution, FT_UInt vert_resolution)
    FT_Error FT_Set_Pixel_Sizes(FT_Face face, FT_UInt pixel_width, FT_UInt pixel_height)
    
    # Glyph loading and rendering
    FT_UInt FT_Get_Char_Index(FT_Face face, FT_ULong charcode)
    FT_Error FT_Load_Glyph(FT_Face face, FT_UInt glyph_index, FT_Int32 load_flags)
    FT_Error FT_Load_Char(FT_Face face, FT_ULong char_code, FT_Int32 load_flags)
    FT_Error FT_Render_Glyph(FT_GlyphSlot slot, FT_Render_Mode render_mode)
    
    # Character enumeration
    FT_ULong FT_Get_First_Char(FT_Face face, FT_UInt* agindex)
    FT_ULong FT_Get_Next_Char(FT_Face face, FT_ULong charcode, FT_UInt* agindex)
    
    # Kerning
    FT_Error FT_Get_Kerning(FT_Face face, FT_UInt left_glyph, FT_UInt right_glyph, 
                           FT_UInt kern_mode, FT_Vector* akerning)



cdef extern from "freetype/ftoutln.h":
    enum FT_Orientation_:
        FT_ORIENTATION_TRUETYPE = 0
        FT_ORIENTATION_POSTSCRIPT = 1
        FT_ORIENTATION_FILL_RIGHT = 0
        FT_ORIENTATION_FILL_LEFT = 1
        FT_ORIENTATION_NONE = 2
    ctypedef FT_Orientation_ FT_Orientation
    FT_Error FT_Outline_Get_Bitmap(FT_Library library, FT_Outline* outline, FT_Bitmap* abitmap)
    FT_Error FT_Outline_Decompose(FT_Outline* outline, const FT_Outline_Funcs* func_interface, void* user)


cdef extern from "freetype/ftglyph.h":
    struct FT_Glyph_Class_:
        pass
    const int FTGLYPH_H_
    const int ft_glyph_bbox_unscaled
    const int ft_glyph_bbox_subpixels
    const int ft_glyph_bbox_gridfit
    const int ft_glyph_bbox_truncate
    const int ft_glyph_bbox_pixels
    ctypedef int FT_Glyph_Class
    ctypedef FT_GlyphRec_* FT_Glyph
    struct FT_GlyphRec_:
        int library
        FT_Glyph_Class* clazz
        int format
        int advance
    ctypedef FT_GlyphRec_ FT_GlyphRec
    ctypedef FT_BitmapGlyphRec_* FT_BitmapGlyph
    struct FT_BitmapGlyphRec_:
        FT_GlyphRec root
        int left
        int top
        FT_Bitmap bitmap
    ctypedef FT_BitmapGlyphRec_ FT_BitmapGlyphRec
    ctypedef FT_OutlineGlyphRec_* FT_OutlineGlyph
    struct FT_OutlineGlyphRec_:
        FT_GlyphRec root
        int outline
    ctypedef FT_OutlineGlyphRec_ FT_OutlineGlyphRec
    ctypedef FT_SvgGlyphRec_* FT_SvgGlyph
    struct FT_SvgGlyphRec_:
        FT_GlyphRec root
        int* svg_document
        int svg_document_length
        int glyph_index
        int metrics
        int units_per_EM
        int start_glyph_id
        int end_glyph_id
        int transform
        int delta
    ctypedef FT_SvgGlyphRec_ FT_SvgGlyphRec
    enum FT_Glyph_BBox_Mode_:
        FT_GLYPH_BBOX_UNSCALED = 0
        FT_GLYPH_BBOX_SUBPIXELS = 0
        FT_GLYPH_BBOX_GRIDFIT = 1
        FT_GLYPH_BBOX_TRUNCATE = 2
        FT_GLYPH_BBOX_PIXELS = 3
    ctypedef FT_Glyph_BBox_Mode_ FT_Glyph_BBox_Mode
    FT_Error FT_Get_Glyph(FT_GlyphSlot slot, FT_Glyph* aglyph)
    FT_Error FT_Glyph_To_Bitmap(FT_Glyph* the_glyph, FT_Render_Mode render_mode,
                               FT_Vector* origin, FT_Bool destroy)
    void FT_Done_Glyph(FT_Glyph glyph)