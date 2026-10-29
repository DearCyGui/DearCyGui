#cython: freethreading_compatible=True

cimport dearcygui as dcg

from dearcygui.core cimport lock_gil_friendly
from dearcygui.c_types cimport unique_lock, DCGMutex
from dearcygui.imgui cimport draw_image_quad, t_draw_image_quad
from libc.stdint cimport int32_t, int64_t
from libcpp.cmath cimport round as cround
from libc.math cimport floor as cfloor, ceil as cceil
from libcpp.map cimport map as cpp_map, pair
from libcpp.set cimport set as cpp_set
from libcpp.vector cimport vector
from cython.operator cimport dereference
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF
from libcpp.memory cimport unique_ptr

import pathlib
import sys
import traceback
from xml.etree import ElementTree
from typing import Tuple

"""
Data structure to store the tile data.
"""
cdef struct TileData:
    double xmin # We store as double to avoid rounding overhead during draw
    double xmax
    double ymin
    double ymax
    int32_t width
    int32_t height
    int64_t last_frame_count
    bint show
    PyObject *texture

cdef class DrawTiledImage(dcg.drawingItem):
    """
    This item enables to easily display a possibly huge
    image by only loading the image times that are currently
    visible.

    The texture management is handled implicitly.
    """

    cdef double margin
    # We use a pointer for fixed structure size
    # if the map/set implementation changes.
    cdef cpp_map[int64_t, TileData] *_tiles
    cdef cpp_set[pair[int32_t, int32_t]] *_requested_tiles

    def __cinit__(self):
        self.margin = 128
        self._tiles = new cpp_map[int64_t, TileData]()
        self._requested_tiles = new cpp_set[pair[int32_t, int32_t]]()

    def __dealloc__(self):
        cdef pair[int64_t, TileData] tile_data
        for tile_data in dereference(self._tiles):
            Py_DECREF(<dcg.Texture>tile_data.second.texture)
        if self._tiles != NULL:
            del self._tiles
        if self._requested_tiles != NULL:
            del self._requested_tiles

    '''
    @property
    def margin(self):
        """
        Margin in pixels around the visible area for
        the area that is loaded in advance.
        """
        return self.margin
    '''

    def get_tile_data(self, int64_t uuid) -> dict:
        """
        Get tile information
        """
        cdef cpp_map[int64_t, TileData].iterator tile_data = self._tiles.find(uuid)
        cdef pair[int64_t, TileData] tile
        if tile_data != self._tiles.end():
            tile = dereference(tile_data)
            Py_INCREF(<dcg.Texture>tile.second.texture)
            return {
                "xmin": tile.second.xmin,
                "xmax": tile.second.xmax,
                "ymin": tile.second.ymin,
                "ymax": tile.second.ymax,
                "width": tile.second.width,
                "height": tile.second.height,
                "show": tile.second.show,
                "last_frame_count": tile.second.last_frame_count,
                "texture": (<dcg.Texture>tile.second.texture)
            }
        else:
            raise KeyError("Tile not found")

    def get_tile_uuids(self) -> list[int]:
        """
        Get the list of uuids of the tiles.
        """
        result = []
        cdef pair[int64_t, TileData] tile_data
        for tile_data in dereference(self._tiles):
            result.append(tile_data.first)
        return result

    def get_oldest_tile(self) -> int:
        """
        Get the uuid of the oldest tile (the one
        with smallest last_frame_count).
        """
        cdef pair[int64_t, TileData] tile_data
        cdef int64_t uuid = -1
        cdef int64_t worst_last_frame_count = -1
        for tile_data in dereference(self._tiles):
            if uuid == -1 or \
               tile_data.second.last_frame_count < worst_last_frame_count:
                uuid = tile_data.first
                worst_last_frame_count = tile_data.second.last_frame_count
        if uuid >= 0:
            return uuid
        else:
            return None

    def add_tile(self,
                 content,
                 coord,
                 opposite_coord=None,
                 nearest_neighbor_upsampling=False,
                 visible=True) -> None:
        """
        Add a tile to the list of tiles.
        Inputs:
            content: numpy array, the content of the tile.
                Alternatively a dcg.Texture object, in which
                case nearest_neighbor_upsampling is ignored.
            coord: the top-left coordinate of the tile
            opposite_coord (optional): if not given,
                defaults to coord + content.shape.
                Else corresponds to the opposite coordinate
                of the tile.
            visible (optional): whether the tile should start visible or not.
            nearest_neighbor_upsampling: whether to use nearest neighbor
                upsampling when rendering the tile.
        Outputs:
            Unique uuid of the tile.
        """
        cdef unique_lock[DCGMutex] m
        cdef dcg.Texture texture
        cdef double[2] top_left
        cdef double[2] bottom_right
        if isinstance(content, dcg.Texture):
            texture = content
        else:
            texture = dcg.Texture(self.context,
                                  content,
                                  nearest_neighbor_upsampling=nearest_neighbor_upsampling)

        dcg.read_coord(top_left, coord)
        if opposite_coord is None:
            bottom_right[0] = top_left[0] + texture.width
            bottom_right[1] = top_left[1] + texture.height
        else:
            dcg.read_coord(bottom_right, opposite_coord)
        cdef int64_t uuid = self.context.next_uuid.fetch_add(1)
        cdef TileData tile
        tile.xmin = top_left[0]
        tile.xmax = bottom_right[0]
        tile.ymin = top_left[1]
        tile.ymax = bottom_right[1]
        tile.width = content.shape[1]
        tile.height = content.shape[0]
        tile.last_frame_count = 0
        tile.show = visible
        Py_INCREF(<dcg.Texture>texture)
        tile.texture = <PyObject*>texture
        # No need to block rendering before adding the tile
        m = unique_lock[DCGMutex](self.mutex)
        cdef pair[int64_t, TileData] tile_data
        tile_data.first = uuid
        tile_data.second = tile
        self._tiles.insert(tile_data)
        return uuid

    def remove_tile(self, uuid) -> None:
        """
        Remove a tile from the list of tiles.
        Inputs:
            uuid: the unique identifier of the tile.
        """
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        cdef cpp_map[int64_t, TileData].iterator tile_data = self._tiles.find(uuid)
        if tile_data != self._tiles.end():
            Py_DECREF(<dcg.Texture>dereference(tile_data).second.texture)
            self._tiles.erase(tile_data)
        else:
            raise KeyError("Tile not found")

    def set_tile_visibility(self, uuid, visible) -> None:
        """
        Set the visibility status of a tile.
        Inputs:
            uuid: the unique identifier of the tile.
            visible: Whether the tile should be visible or not.
        By default tiles start visible.
        """
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        cdef cpp_map[int64_t, TileData].iterator tile_data = self._tiles.find(uuid)
        if tile_data != self._tiles.end():
            dereference(tile_data).second.show = visible
        else:
            raise KeyError("Tile not found")

    def update_tile(self, uuid, content) -> None:
        """
        Update the content of a tile.
        Inputs:
            uuid: the unique identifier of the tile.
            content: the new content of the tile.
        """
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        cdef cpp_map[int64_t, TileData].iterator tile_data = self._tiles.find(uuid)
        cdef pair[int64_t, TileData] tile
        if tile_data != self._tiles.end():
            tile = dereference(tile_data)
            (<dcg.Texture>tile.second.texture).set_value(content)
        else:
            raise KeyError("Tile not found")

    cdef void draw(self, void* drawlist) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        # Retrieve min/max visible area

        cdef double xmin, xmax, ymin, ymax
        # top left of the drawing area
        cdef float[2] start, end
        start[0] = self.context.viewport.parent_pos.x
        start[1] = self.context.viewport.parent_pos.y
        end[0] = start[0] + self.context.viewport.parent_size.x
        end[1] = start[1] + self.context.viewport.parent_size.y
        cdef double[2] start_coord, end_coord
        self.context.viewport.screen_to_coordinate(start_coord, start)
        self.context.viewport.screen_to_coordinate(end_coord, end)
        # the min/max are because there could be
        # inversions in the screen to coordinate transform.
        xmin = min(start_coord[0], end_coord[0])
        xmax = max(start_coord[0], end_coord[0])
        ymin = min(start_coord[1], end_coord[1])
        ymax = max(start_coord[1], end_coord[1])

        # Display each tile already loaded that are visible:
        cdef pair[int64_t, TileData] tile_data
        cdef TileData tile
        for tile_data in dereference(self._tiles):
            tile = tile_data.second
            if tile.xmin < xmax and tile.xmax > xmin and tile.ymin < ymax and tile.ymax > ymin and tile.show:
                # Draw the tile
                draw_image_quad(self.context,
                                drawlist,
                                (<dcg.Texture>tile.texture).allocated_texture,
                                tile.xmin, tile.ymin,
                                tile.xmax, tile.ymin,
                                tile.xmax, tile.ymax,
                                tile.xmin, tile.ymax,
                                0., 0.,
                                1., 0.,
                                1., 1.,
                                0., 1.,
                                4294967295)
                tile.last_frame_count = self.context.viewport.frame_count
        return



cdef int32_t _MAX_TEXTURE_SIZE = 16384


cdef inline double _remap(double v, double lo, double hi) noexcept nogil:
    """Map v from the [lo, hi] range to [0, 1]"""
    return (v - lo) / (hi - lo)


cdef tuple _clamp_window(int32_t start, int32_t stop, int32_t limit):
    """Return a non-empty [start, stop) window of at most _MAX_TEXTURE_SIZE within [0, limit]"""
    if stop <= start:
        stop = min(limit, start + 1)
        start = stop - 1
    if stop - start > _MAX_TEXTURE_SIZE:
        start = max(0, min(start, limit - _MAX_TEXTURE_SIZE))
        stop = start + _MAX_TEXTURE_SIZE
    return (start, stop)


def _parse_viewbox_size(data: bytes) -> tuple[float, float]:
    """Return the (width, height) of the root viewBox, or (0, 0) if absent."""
    try:
        root = ElementTree.fromstring(data)
        values = [float(v) for v in root.get('viewBox', '').replace(',', ' ').split()]
    except (ElementTree.ParseError, ValueError):
        return (0., 0.)
    if len(values) != 4:
        return (0., 0.)
    return (values[2], values[3])


cdef class SVGRenderer:
    """
    Base class for SVG renderers.
    """
    # Texture the SVG is rendered to (set by allocate_texture)
    cdef public object texture

    def __init__(self, svg_path=None, *, svg_data=None):
        pass

    @property
    def content_bounds(self) -> Tuple[float, float, float, float]:
        """Get the SVG content bounds (x, y, width, height). Must be overridden."""
        raise NotImplementedError

    def get_fit_scale(self,
                      target_width: float,
                      target_height: float,
                      preserve_ratio: bool = True) -> Tuple[float, float]:
        """Calculate (scalex, scaley) to fit SVG in target dimensions"""
        _, _, content_w, content_h = self.content_bounds
        if content_w <= 0 or content_h <= 0:
            return (1.0, 1.0)
        scale_x = target_width / content_w
        scale_y = target_height / content_h
        if preserve_ratio:
            scale_x = min(scale_x, scale_y)
            scale_y = scale_x
        return (scale_x, scale_y)

    def get_centered_translation(self,
                                 target_width: float,
                                 target_height: float,
                                 scalex: float,
                                 scaley: float) -> Tuple[float, float]:
        """Calculate translation to center SVG in target dimensions at given scale"""
        content_x, content_y, content_w, content_h = self.content_bounds
        if scalex == 0 or scaley == 0:
            return (0, 0)
        tx = (target_width / scalex - content_w) / 2 - content_x
        ty = (target_height / scaley - content_h) / 2 - content_y
        return (tx, ty)

    def release(self) -> None:
        """Release the resources held by the renderer"""
        pass

    def allocate_texture(self, C: dcg.Context, width: int, height: int, allow_gpu: bool = False) -> None:
        """Allocate self.texture (RGBA, straight alpha) for rendering. Must be overridden."""
        raise NotImplementedError

    def render(self,
               scalex: float,
               scaley: float,
               tx: float,
               ty: float) -> None:
        """Render the SVG content to the texture at given scale and position. Must be overridden."""
        raise NotImplementedError


_MODE_CPU = 0 # skia raster surface, pixels uploaded with set_value
_MODE_GPU_BLIT = 1 # skia GPU surface, converted to the texture on the GPU
_MODE_GPU_READBACK = 2 # skia GPU surface, pixels read back and uploaded

_BLIT_VERTEX_SHADER = """
#version 330 core
void main() {
    // Fullscreen triangle generated from the vertex index
    vec2 pos = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2);
    gl_Position = vec4(pos * 2.0 - 1.0, 0.0, 1.0);
}
"""

_BLIT_FRAGMENT_SHADER = """
#version 330 core
uniform sampler2D src;
out vec4 color;
void main() {
    // skia renders premultiplied alpha, ImGui expects straight alpha
    vec4 c = texelFetch(src, ivec2(gl_FragCoord.xy), 0);
    color = c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
"""


class _UnpremultiplyBlit:
    """Copy a premultiplied RGBA GL texture to another one as straight alpha.

    Both textures must be owned by the GL context wrapped by the
    moderngl context, which must be current when calling the methods.
    """

    def __init__(self, moderngl, ctx, src_gl_id: int, dst_gl_id: int,
                 width: int, height: int) -> None:
        self._moderngl = moderngl
        self._ctx = ctx
        self._src = ctx.external_texture(src_gl_id, (width, height), 4, 0, "f1")
        self._dst = ctx.external_texture(dst_gl_id, (width, height), 4, 0, "f1")
        self._dst_fbo = ctx.framebuffer(color_attachments=[self._dst])
        self._program = ctx.program(vertex_shader=_BLIT_VERTEX_SHADER,
                                    fragment_shader=_BLIT_FRAGMENT_SHADER)
        self._program['src'] = 0
        self._vao = ctx.vertex_array(self._program, [])

    def blit(self) -> None:
        """Run the conversion."""
        self._dst_fbo.use()
        self._ctx.disable(self._moderngl.BLEND | self._moderngl.DEPTH_TEST)
        self._src.use(0)
        self._vao.render(self._moderngl.TRIANGLES, vertices=3)

    def release(self) -> None:
        """Free the GL objects (the wrapped textures are not deleted)."""
        for obj in (self._vao, self._program, self._dst_fbo, self._dst, self._src):
            obj.release()


cdef class SkiaSVGRenderer(SVGRenderer):
    """
    A SVG renderer using Skia for rendering,
    with optional GPU acceleration.

    The renderer can be used to render SVG content
    to a texture. It is possible to render the SVG
    content at a specific scale and position.

    Skia is pretty fast. By default the GPU is not used,
    but it can be enabled by setting allow_gpu=True.
    GPU rendering is not always faster, it depends on
    the complexity of the SVG content and the target.

    With the GPU, skia renders into its own texture, which then
    has to be transferred to the DearCyGui texture. If moderngl
    is available the transfer is done on the GPU, else the pixels
    are read back to the CPU. If the GPU cannot be initialized,
    the renderer falls back to the CPU.
    """
    cdef object skia
    cdef object moderngl
    cdef object svg_dom
    cdef object original_size
    cdef object info # skia ImageInfo of the surface
    cdef object matrix # skia Matrix reused at every render
    cdef object surface
    cdef int _mode
    # Requested allocation
    cdef int32_t _width
    cdef int32_t _height
    cdef bint _gpu_requested
    cdef bint _gpu_failed # do not retry after a GPU failure
    # GPU state
    cdef object gl_context
    cdef object gr_context
    cdef object backend_texture
    cdef object moderngl_context
    cdef object blitter

    def __init__(self, svg_path=None, *, svg_data=None):
        """Load the SVG from a file path, or from svg_data (str or bytes)."""
        try:
            import skia
        except ImportError:
            raise ImportError("skia-python is required for this renderer")
        try:
            import moderngl
        except ImportError:
            moderngl = None # moderngl is optional
        if (svg_path is None) == (svg_data is None):
            raise ValueError("Exactly one of svg_path and svg_data must be provided")
        self.skia = skia
        self.moderngl = moderngl
        self._mode = _MODE_CPU

        # Retrieve the raw SVG content
        if svg_data is None:
            data = pathlib.Path(svg_path).read_bytes()
        elif isinstance(svg_data, str):
            data = svg_data.encode('utf-8')
        else:
            data = bytes(svg_data)

        self.svg_dom = skia.SVGDOM.MakeFromStream(skia.MemoryStream.MakeCopy(data))
        if not(self.svg_dom):
            raise ValueError("Failed to load SVG")

        # Without width/height, skia reports an empty size: use the viewBox
        size = self.svg_dom.containerSize()
        if size.width() <= 0 or size.height() <= 0:
            size = skia.Size(*_parse_viewbox_size(data))
            if size.width() <= 0 or size.height() <= 0:
                raise ValueError("The SVG has no width/height nor valid viewBox")
            self.svg_dom.setContainerSize(size)
        self.original_size = size

    @property
    def content_bounds(self) -> Tuple[float, float, float, float]:
        if not self.svg_dom:
            return (0, 0, 0, 0)
        return (0, 0, self.original_size.width(), self.original_size.height())

    def allocate_texture(self, C : dcg.Context,
                         int32_t width, int32_t height,
                         bint allow_gpu = False) -> None:
        # Keep the current resources if they already match the request
        if self.surface is not None and \
           self._width == width and \
           self._height == height and \
           self._gpu_requested == allow_gpu:
            return

        # Free the resources of the previous allocation
        self._release_surface()

        # Allocate the texture
        self.texture = dcg.Texture(C)
        self.texture.allocate(width=width, height=height, uint8=True, num_chans=4)
        self._width = width
        self._height = height
        self._gpu_requested = allow_gpu
        self.info = self.skia.ImageInfo.Make(width, height,
                                             self.skia.kRGBA_8888_ColorType,
                                             self.skia.kPremul_AlphaType)
        # The matrix passed to render() does the scaling
        self.svg_dom.setContainerSize(self.original_size)

        # Create the surface, on the GPU if possible
        if allow_gpu and not(self._gpu_failed):
            try:
                self._init_gpu_surface(C)
                return
            except Exception:
                traceback.print_exc()
                self._gpu_failed = True
                self._release_surface()
        self._init_cpu_surface()

    def release(self) -> None:
        self._release_surface()
        self.moderngl_context = None
        self.gl_context = None
        self.texture = None

    def render(self, float scalex, float scaley, float tx, float ty) -> None:
        """Render the SVG content to the texture at given scale and position"""
        if not self.svg_dom or not self.surface:
            return None

        if self._mode == _MODE_CPU:
            self._draw_svg(scalex, scaley, tx, ty)
            pixels = self._read_pixels()
        else:
            pixels = self._render_gpu(scalex, scaley, tx, ty)

        # The GL context is released by now
        if pixels is not None:
            self.texture.set_value(pixels)

    def _init_cpu_surface(self) -> None:
        """Create a raster surface with explicit RGBA layout."""
        self._mode = _MODE_CPU
        self.surface = self.skia.Surface.MakeRaster(self.info)
        if self.surface is None:
            raise ValueError("Failed to create the CPU surface")
        self.matrix = self.skia.Matrix()

    def _init_gpu_surface(self, C : dcg.Context) -> None:
        """Create a skia GPU surface and the means to transfer it.

        Raises if the GPU cannot be used. The caller must then call
        _release_surface.
        """
        skia = self.skia
        if self.gl_context is None:
            # 3.3 core is the minimum for skia and moderngl, and macOS caps at 4.1
            self.gl_context = C.create_new_shared_gl_context(3, 3)
        self.gl_context.make_current()
        try:
            # Surface rendering to a skia owned texture
            self.gr_context = self._make_gr_context()
            self.backend_texture = self.gr_context.createBackendTexture(
                self._width, self._height, skia.kRGBA_8888_ColorType,
                skia.GrMipmapped.kNo, skia.GrRenderable.kYes
            )
            self.surface = skia.Surface.MakeFromBackendTexture(
                self.gr_context,
                self.backend_texture,
                skia.kTopLeft_GrSurfaceOrigin,
                0,
                skia.ColorType.kRGBA_8888_ColorType,
                skia.ColorSpace.MakeSRGB(),
                None
            )
            if self.surface is None:
                raise RuntimeError("Failed to create the GPU surface")
            self.matrix = skia.Matrix()

            # GPU conversion if possible, else pixels will be read back
            if self.moderngl is None:
                self._mode = _MODE_GPU_READBACK
            else:
                self.blitter = self._make_blitter()
                self._mode = _MODE_GPU_BLIT
        finally:
            self.gl_context.release()

    def _make_gr_context(self):
        """Create the skia GL context. Raises if no GL interface works.

        The default native interface only looks at GLX, which fails when
        the context was created with EGL (e.g. Wayland), so try EGL too.
        """
        skia = self.skia
        context = skia.GrDirectContext.MakeGL()
        if context is not None:
            return context
        # EGL/GLX interfaces only exist in the Linux builds of skia-python
        if sys.platform.startswith("linux"):
            for name in ("MakeEGL", "MakeGLX"):
                maker = getattr(skia.GrGLInterface, name, None)
                gl_interface = maker() if maker is not None else None
                if gl_interface is not None:
                    context = skia.GrDirectContext.MakeGL(gl_interface)
                    if context is not None:
                        return context
        raise RuntimeError("Failed to create the skia GL context (no usable GL interface)")

    def _make_moderngl_context(self):
        """Wrap the current GL context with moderngl.

        The default detection only supports GLX. With EGL (e.g. Wayland)
        the context must be attached with the egl backend instead.
        """
        try:
            return self.moderngl.create_context()
        except Exception:
            # WGL (Windows) and CGL (macOS) detection is reliable: only
            # Linux can have EGL contexts
            if not sys.platform.startswith("linux"):
                raise
            return self.moderngl.create_context(backend='egl', share=True)

    def _make_blitter(self):
        """Create the GPU conversion from the skia texture to self.texture."""
        info = self.skia.GrGLTextureInfo()
        if not self.backend_texture.getGLTextureInfo(info):
            raise RuntimeError("Failed to retrieve the GL texture info")
        if self.moderngl_context is None:
            self.moderngl_context = self._make_moderngl_context()
        return _UnpremultiplyBlit(self.moderngl, self.moderngl_context,
                                  info.fID, self.texture.texture_id,
                                  self._width, self._height)

    def _release_surface(self) -> None:
        """Free the surface and the GPU objects of the current allocation."""
        if self.gl_context is not None:
            self.gl_context.make_current()
        try:
            # moderngl objects reference the skia texture: free them first
            if self.blitter is not None:
                self.blitter.release()
            self.surface = None
            if self.gr_context is not None:
                if self.backend_texture is not None:
                    self.gr_context.deleteBackendTexture(self.backend_texture)
                self.gr_context.releaseResourcesAndAbandonContext()
        finally:
            if self.gl_context is not None:
                self.gl_context.release()
        self.blitter = None
        self.backend_texture = None
        self.gr_context = None
        self._mode = _MODE_CPU

    def _draw_svg(self, float scalex, float scaley, float tx, float ty) -> None:
        """Draw the SVG on the (cleared) skia surface."""
        canvas = self.surface.getCanvas()
        canvas.clear(self.skia.ColorTRANSPARENT)
        self.matrix.setScale(scalex, scaley)
        self.matrix.preTranslate(tx, ty)
        canvas.setMatrix(self.matrix)
        self.svg_dom.render(canvas)

    def _render_gpu(self, float scalex, float scaley, float tx, float ty):
        """Render on the GPU.

        Returns the pixels to upload, or None if the texture was already
        written on the GPU.
        """
        pixels = None
        self.gl_context.make_current()
        try:
            self._draw_svg(scalex, scaley, tx, ty)
            self.gr_context.flush()
            if self._mode == _MODE_GPU_BLIT:
                self.texture.gl_begin_write()
                try:
                    self.blitter.blit()
                finally:
                    self.texture.gl_end_write()
                # moderngl changed the GL state behind skia's back
                self.gr_context.resetContext()
            else:
                pixels = self._read_pixels()
        finally:
            self.gl_context.release()
        return pixels

    def _read_pixels(self):
        """Read the surface back as straight alpha RGBA.

        ImGui blends with straight alpha while skia renders premultiplied.
        """
        image = self.surface.makeImageSnapshot()
        return image.toarray(colorType=self.skia.kRGBA_8888_ColorType,
                             alphaType=self.skia.kUnpremul_AlphaType)


cdef class DrawSVG(dcg.drawingItem):
    """
    Draw SVG content scaled to fit within given bounds.

    The SVG is rendered to a texture at an appropriate resolution
    based on the visible area, and reuses the texture when possible
    to avoid unnecessary re-rendering.
    """

    cdef str _svg_path
    cdef double[2] _pmin
    cdef double[2] _pmax
    cdef object _renderer
    cdef dcg.Texture _texture
    # False until a texture has been rendered for the current renderer
    cdef bint _has_texture
    # size of the rendered area which the texture contains a crop of
    cdef int32_t _rendered_ref_width
    cdef int32_t _rendered_ref_height
    # relative coordinates of the rendered area that maps to the texture
    cdef double _texture_u0
    cdef double _texture_u1
    cdef double _texture_v0
    cdef double _texture_v1
    cdef bint _allow_gpu
    cdef bint _preserve_ratio
    cdef bint _no_fill_area
    cdef bint _no_centering

    def __cinit__(self):
        self._pmin = [0., 0.]
        self._pmax = [1., 1.]
        self._has_texture = False
        self._texture_u0 = 0
        self._texture_u1 = 1.
        self._texture_v0 = 0
        self._texture_v1 = 1.
        self._allow_gpu = False
        self._preserve_ratio = True
        self._no_fill_area = False
        self._no_centering = False
        self._texture = dcg.Texture(self.context)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

    def __dealloc__(self):
        self._release_renderer()

    cdef void _release_renderer(self) noexcept:
        """Release the current renderer resources (mutex held or object dying)"""
        if self._renderer is None:
            return
        try:
            self._renderer.release()
        except Exception:
            traceback.print_exc()

    cdef void _set_renderer(self, object renderer, object path) noexcept:
        """Replace the renderer and force a re-render. Mutex must be held."""
        self._release_renderer()
        self._svg_path = path
        self._renderer = renderer
        self._has_texture = False

    @property
    def renderer(self):
        """
        Renderer (SVGRenderer instance) used to rasterize the SVG.

        Setting it allows to use a custom renderer. The item takes
        ownership of the renderer and calls its release() method when
        it is replaced or when the item is destroyed.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._renderer

    @renderer.setter
    def renderer(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value is not None and not isinstance(value, SVGRenderer):
            raise TypeError("renderer must be an SVGRenderer instance")
        self._set_renderer(value, None)

    @property
    def svg_path(self):
        """
        Path to the SVG file being displayed.

        This path identifies the SVG file loaded by the renderer. Setting this
        property will create a new renderer instance with the provided file.
        None if the content was not set from a file.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._svg_path

    @svg_path.setter
    def svg_path(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)

        # Create the new renderer first, so that a failure keeps the old state
        self._set_renderer(SkiaSVGRenderer(value), value)

    @property
    def svg_data(self):
        """
        Write-only: SVG content (str or bytes) to display.

        Setting this property creates a new renderer from the content.
        """
        raise AttributeError("svg_data is write-only")

    @svg_data.setter
    def svg_data(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._set_renderer(SkiaSVGRenderer(svg_data=value), None)

    @property
    def allow_gpu(self):
        """
        Whether to try GPU rendering of the SVG (default False).

        Falls back to CPU rendering if the GPU backend cannot be
        initialized. GPU rendering is not always faster.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._allow_gpu

    @allow_gpu.setter
    def allow_gpu(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        if value != self._allow_gpu:
            self._allow_gpu = value
            self._has_texture = False

    @property
    def pmin(self):
        """
        Top-left position in coordinate space.

        Defines the upper-left corner of the rectangle where the SVG will be
        drawn. Together with pmax, this determines the display area bounds.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return dcg.Coord.build(self._pmin)

    @pmin.setter
    def pmin(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        dcg.read_coord(self._pmin, value)

    @property 
    def pmax(self):
        """
        Bottom-right position in coordinate space.

        Defines the lower-right corner of the rectangle where the SVG will be
        drawn. Together with pmin, this determines the display area bounds.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return dcg.Coord.build(self._pmax)

    @pmax.setter
    def pmax(self, value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        dcg.read_coord(self._pmax, value)

    @property
    def no_preserve_ratio(self):
        """
        Whether to allow stretching the SVG to fit the area.

        When True, the SVG can be stretched in both dimensions independently to
        fill the entire display area. When False (default), the aspect ratio is
        preserved.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return not(self._preserve_ratio)

    @no_preserve_ratio.setter 
    def no_preserve_ratio(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._preserve_ratio = not(value)
        self._has_texture = False

    @property
    def no_fill_area(self):
        """
        Whether to map SVG units to coordinate units instead of fitting.

        When True, one SVG unit spans one unit of the coordinate space
        (the SVG is not scaled to fill [pmin, pmax]). Default is False.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._no_fill_area

    @no_fill_area.setter
    def no_fill_area(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._no_fill_area = value
        self._has_texture = False

    @property
    def no_centering(self):
        """
        Whether to align SVG to top-left instead of centering.

        When True, the SVG is aligned to the top-left corner of the display area.
        When False (default), the SVG is centered within the display area.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._no_centering

    @no_centering.setter
    def no_centering(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._no_centering = value
        self._has_texture = False

    cdef bint _update_texture(self,
                              double fu0, double fu1,
                              double fv0, double fv1,
                              double full_width, double full_height,
                              double unit_scalex, double unit_scaley) noexcept:
        """Render the SVG to a texture covering the visible area (+ margin).

        (fu0, fv0)-(fu1, fv1) is the visible area relative to the full area.
        Must be called with the GIL and the item mutex held.
        Returns False on failure, after disabling the renderer.
        """
        cdef int32_t ref_w = max(1, <int>cround(full_width))
        cdef int32_t ref_h = max(1, <int>cround(full_height))
        cdef int32_t start_x, start_y, stop_x, stop_y
        cdef double margin_x = 0.1 * (fu1 - fu0) * ref_w
        cdef double margin_y = 0.1 * (fv1 - fv0) * ref_h

        # Pixel aligned window (with a 10% margin to reduce reallocations)
        start_x = <int>cfloor(max(0., fu0 * ref_w - margin_x))
        start_y = <int>cfloor(max(0., fv0 * ref_h - margin_y))
        stop_x = <int>cceil(min(<double>ref_w, fu1 * ref_w + margin_x))
        stop_y = <int>cceil(min(<double>ref_h, fv1 * ref_h + margin_y))
        start_x, stop_x = _clamp_window(start_x, stop_x, ref_w)
        start_y, stop_y = _clamp_window(start_y, stop_y, ref_h)

        try:
            self._renderer.allocate_texture(self.context,
                                            stop_x - start_x,
                                            stop_y - start_y,
                                            self._allow_gpu)

            # Scale and translation for the full area
            if self._no_fill_area:
                scalex = unit_scalex
                scaley = unit_scaley
                if self._preserve_ratio:
                    scalex = min(scalex, scaley)
                    scaley = scalex
            else:
                scalex, scaley = self._renderer.get_fit_scale(ref_w, ref_h,
                                                              self._preserve_ratio)
            if self._no_centering:
                tx = 0.
                ty = 0.
            else:
                tx, ty = self._renderer.get_centered_translation(ref_w, ref_h,
                                                                 scalex, scaley)

            # Shift to the window origin
            tx -= start_x / scalex
            ty -= start_y / scaley

            self._renderer.render(scalex, scaley, tx, ty)
            new_texture = self._renderer.texture
            if new_texture is None:
                raise ValueError("The renderer did not provide a texture")
        except Exception:
            # Do not retry (and spam) at every frame
            traceback.print_exc()
            self._release_renderer()
            self._renderer = None
            self._has_texture = False
            return False

        # Commit the state only once the rendering succeeded
        self._texture = new_texture
        self._has_texture = True
        self._rendered_ref_width = ref_w
        self._rendered_ref_height = ref_h
        self._texture_u0 = <double>start_x / ref_w
        self._texture_u1 = <double>stop_x / ref_w
        self._texture_v0 = <double>start_y / ref_h
        self._texture_v1 = <double>stop_y / ref_h
        return True

    cdef void draw(self, void* drawlist) noexcept nogil:
        cdef unique_lock[DCGMutex] m = unique_lock[DCGMutex](self.mutex)
        if not(self._show) or self._renderer is None:
            return

        # Transform coordinate bounds to screen space
        cdef float[2] screen_pmin, screen_pmax
        cdef double[2] pmin = self._pmin
        cdef double[2] pmax = self._pmax
        self.context.viewport.coordinate_to_screen(screen_pmin, pmin)
        self.context.viewport.coordinate_to_screen(screen_pmax, pmax)

        cdef float tmp
        cdef bint flip_x = screen_pmax[0] < screen_pmin[0]
        cdef bint flip_y = screen_pmax[1] < screen_pmin[1]
        if flip_x:
            tmp = screen_pmax[0]
            screen_pmax[0] = screen_pmin[0]
            screen_pmin[0] = tmp
        if flip_y:
            tmp = screen_pmax[1]
            screen_pmax[1] = screen_pmin[1]
            screen_pmin[1] = tmp

        cdef float full_width = screen_pmax[0] - screen_pmin[0]
        cdef float full_height = screen_pmax[1] - screen_pmin[1]

        if full_width <= 0.5 or full_height <= 0.5:
            return

        # Get visible area bounds
        cdef float visible_x = self.context.viewport.parent_pos.x
        cdef float visible_y = self.context.viewport.parent_pos.y
        cdef float visible_w = self.context.viewport.parent_size.x
        cdef float visible_h = self.context.viewport.parent_size.y

        # Clip to visible area
        cdef float x = max(screen_pmin[0], visible_x)
        cdef float y = max(screen_pmin[1], visible_y)
        cdef float w = min(screen_pmax[0], visible_x + visible_w) - x
        cdef float h = min(screen_pmax[1], visible_y + visible_h) - y

        # Corresponding area relative to the top left of the (full_width, full_height) area
        cdef double start_x, start_y, stop_x, stop_y
        start_x = x - screen_pmin[0]
        start_y = y - screen_pmin[1]
        stop_x = start_x + w
        stop_y = start_y + h
        if flip_x:
            start_x, stop_x = full_width - stop_x, full_width - start_x
        if flip_y:
            start_y, stop_y = full_height - stop_y, full_height - start_y

        if w <= 0.5 or h <= 0.5:
            return

        # Position of the visible area relative to the full area (0-1)
        cdef double fu0 = start_x / full_width, fv0 = start_y / full_height
        cdef double fu1 = stop_x / full_width, fv1 = stop_y / full_height

        # Check if we need to reallocate texture
        # Only reallocate if:
        # 1. We don't have texture yet
        # 2. required content is outside of current texture
        # 3. New required resolution is larger than 1.2 * that of current texture
        # 4. New required size is much smaller (less than 50%) in one dimension
        #    to save memory and prevent aliasing
        cdef double epsilon = 1e-6 # for rounding imprecision
        cdef bint need_realloc = not(self._has_texture) or \
                                fu0 < self._texture_u0 - epsilon or \
                                fu1 > self._texture_u1 + epsilon or \
                                fv0 < self._texture_v0 - epsilon or \
                                fv1 > self._texture_v1 + epsilon or \
                                full_width > 1.2 * self._rendered_ref_width or \
                                full_height > 1.2 * self._rendered_ref_height or \
                                full_width < self._rendered_ref_width / 2 or \
                                full_height < self._rendered_ref_height / 2

        cdef bint success
        cdef double unit_scalex, unit_scaley
        if need_realloc:
            # Pixels per coordinate unit (used by no_fill_area)
            unit_scalex = abs(full_width / (pmax[0] - pmin[0]))
            unit_scaley = abs(full_height / (pmax[1] - pmin[1]))
            with gil:
                success = self._update_texture(fu0, fu1, fv0, fv1,
                                               full_width, full_height,
                                               unit_scalex, unit_scaley)
            if not(success):
                return

        # UV coordinates: the texture covers only a subsection of the full area
        cdef double u0 = _remap(fu0, self._texture_u0, self._texture_u1)
        cdef double u1 = _remap(fu1, self._texture_u0, self._texture_u1)
        cdef double v0 = _remap(fv0, self._texture_v0, self._texture_v1)
        cdef double v1 = _remap(fv1, self._texture_v0, self._texture_v1)

        # Draw texture mapped to coordinate bounds
        if flip_x:
            u0, u1 = u1, u0
        if flip_y:
            v0, v1 = v1, v0

        t_draw_image_quad(self.context,
                          drawlist,
                          self._texture.allocated_texture,
                          x, y,
                          x+w, y,
                          x+w, y+h,
                          x, y+h,
                          u0, v0,
                          u1, v0,
                          u1, v1,
                          u0, v1,
                          4294967295)