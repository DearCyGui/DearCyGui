#cython: freethreading_compatible=True

cimport dearcygui as dcg

from dearcygui.core cimport lock_gil_friendly
from dearcygui.c_types cimport unique_lock, DCGMutex
from dearcygui.imgui cimport draw_image_quad, t_draw_image_quad
from libc.stdint cimport int32_t, int64_t
from libcpp.cmath cimport round as cround
from libcpp.map cimport map, pair
from libcpp.set cimport set
from libcpp.vector cimport vector
from cython.operator cimport dereference
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF
from libcpp.memory cimport unique_ptr

import pathlib
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
    int32_t last_frame_count
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
    cdef map[int64_t, TileData] *_tiles
    cdef set[pair[int32_t, int32_t]] *_requested_tiles

    def __cinit__(self):
        self.margin = 128
        self._tiles = new map[int64_t, TileData]()
        self._requested_tiles = new set[pair[int32_t, int32_t]]()

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
        cdef map[int64_t, TileData].iterator tile_data = self._tiles.find(uuid)
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
        cdef int32_t worst_last_frame_count = -1
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
        cdef map[int64_t, TileData].iterator tile_data = self._tiles.find(uuid)
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
        cdef map[int64_t, TileData].iterator tile_data = self._tiles.find(uuid)
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
        cdef map[int64_t, TileData].iterator tile_data = self._tiles.find(uuid)
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



class SVGRenderer:
    """
    Base class for SVG renderers.
    """

    def __init__(self, svg_path: str):
        pass

    @property
    def content_bounds(self) -> Tuple[float, float, float, float]:
        """Get the SVG content bounds (x, y, width, height)"""
        return (0, 0, 0, 0)

    def get_fit_scale(self, target_width: float, target_height: float) -> float:
        """Calculate scale factor to fit SVG in target dimensions while preserving aspect ratio"""
        return 1.0, 1.0

    def get_centered_translation(self, target_width: float, target_height: float, scalex: float, scaley: float) -> Tuple[float, float]:
        """Calculate translation to center SVG in target dimensions at given scale"""
        return (0, 0)

    def allocate_texture(self, C: dcg.Context, width: int, height: int, allow_gpu: bool = False):
        """Allocate a texture for rendering the SVG content"""
        pass

    def render(self,
               scalex: float,
               scaley: float,
               tx: float,
               ty: float):
        """Render the SVG content to the texture at given scale and position"""
        pass


class SkiaSVGRenderer(SVGRenderer):
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
    The GPU backend might require moderngl.
    """
    def __init__(self, svg_path : str):
        try:
            import skia
        except ImportError:
            raise ImportError("Skia is required for this renderer")
        try:
            import moderngl
        except ImportError:
            moderngl = None # moderngl is optional
        self.skia = skia
        self.moderngl = moderngl
        svg_path = str(pathlib.Path(svg_path).resolve())
        skia_stream = skia.Stream.MakeFromFile(svg_path)
        self.svg_dom = skia.SVGDOM.MakeFromStream(skia_stream)
        if not(self.svg_dom):
            raise ValueError("Failed to load SVG")
        self.original_size = self.svg_dom.containerSize()
        #root_svg = self.svg_dom.getRoot()
        #self.original_bounds = root_svg.objectBoundingBox()

    @property
    def content_bounds(self) -> Tuple[float, float, float, float]:
        """Get the SVG content bounds (x, y, width, height)"""
        if not self.svg_dom:
            return (0, 0, 0, 0)
        #bounds = self.original_bounds
        #return (bounds.x(), bounds.y(), bounds.width(), bounds.height())
        return (0, 0, self.original_size.width(), self.original_size.height())

    def get_fit_scale(self,
                      float target_width,
                      float target_height,
                      bint preserve_ratio = True) -> float:
        """Calculate scale factor to fit SVG in target dimensions while preserving aspect ratio"""
        if not self.svg_dom:
            return 1.0
        content_x, content_y, content_w, content_h = self.content_bounds
        if content_w == 0 or content_h == 0:
            return 1.0
        scale_x = target_width / content_w
        scale_y = target_height / content_h
        if preserve_ratio:
            scale_x = min(scale_x, scale_y)
            scale_y = scale_x
        return scale_x, scale_y
    
    def get_centered_translation(self,
                                 target_width: float,
                                 target_height: float, 
                                 scalex: float,
                                 scaley: float) -> Tuple[float, float]:
        """Calculate translation to center SVG in target dimensions at given scale"""
        if not self.svg_dom:
            return (0, 0)
        content_x, content_y, content_w, content_h = self.content_bounds
        
        # Calculate centered position
        tx = (target_width / scalex - content_w) / 2 - content_x
        ty = (target_height / scaley - content_h) / 2 - content_y
        return (tx, ty)

    def allocate_texture(self, C : dcg.Context,
                         int32_t width, int32_t height,
                         bint allow_gpu = False) -> None:
        """Allocate a texture for rendering the SVG content"""
        skia = self.skia
        # GPU Context setup
        self.texture = dcg.Texture(C)
        self.texture.allocate(width=width, height=height, uint8=True, num_chans=4)
        # Reinit old data
        self.backend_texture = None
        self.surface = None
        self.imported_texture = None
        self.context = None
        self.moderngl_dst_texture = None
        self.moderngl_src_texture = None
        self.moderngl_src_fbo = None
        self.moderngl_dst_fbo = None
        self.moderngl_context = None
        self.gl_context = None

        self._container_width = width
        self._container_height = height
        if self.svg_dom:
            self.svg_dom.setContainerSize((width, height))

        if allow_gpu:
            self.gl_context = C.create_new_shared_gl_context(4,3)
            self.gl_context.make_current()
            self.context = skia.GrDirectContext.MakeGL()
            self.moderngl_context = None
        self.info = skia.ImageInfo.MakeN32Premul(width, height)
        self.cpu_rendering = False
        self.gpu_blit = False
        
        if self.context:
            # Create GPU surface

            self.imported_texture = skia.GrBackendTexture(
                width, height,
                skia.GrMipmapped.kNo,
                skia.GrGLTextureInfo(
                    target=3553, #GL_TEXTURE_2D,
                    id=self.texture.texture_id,
                    format=skia.GrGLFormat.kRGBA8
                )
            )

            # I haven't made it work yet, not sure why
            self.surface = skia.Surface.MakeFromBackendTexture(
                self.context,
                self.imported_texture,
                skia.kTopLeft_GrSurfaceOrigin,
                0,
                skia.ColorType.kRGBA_8888_ColorType,
                skia.ColorSpace.MakeSRGB(),
                None
            )

        if self.context and self.surface is None:
            # Fallback to GPU texture not imported
            # Create a GPU surface using a rendertarget texture
            self.backend_texture = self.context.createBackendTexture(
                width, height, skia.kRGBA_8888_ColorType,
                skia.GrMipmapped.kNo, skia.GrRenderable.kYes
            )
            GrGLTextureInfo = skia.GrGLTextureInfo()
            self.surface = skia.Surface.MakeFromBackendTexture(
                self.context,
                self.backend_texture,
                skia.kTopLeft_GrSurfaceOrigin,
                0,
                skia.ColorType.kRGBA_8888_ColorType,
                skia.ColorSpace.MakeSRGB(),
                None
            )

            if self.surface is not None and self.moderngl:
                GrGLTextureInfo = skia.GrGLTextureInfo()
                assert(self.backend_texture.getGLTextureInfo(GrGLTextureInfo))
                self.gpu_blit = True
                self.moderngl_context = self.moderngl.create_context()
                self.moderngl_dst_texture = \
                    self.moderngl_context.external_texture(
                        self.texture.texture_id,
                        (self.texture.width, self.texture.height),
                        4, 0, "f1")
                self.moderngl_src_texture = \
                    self.moderngl_context.external_texture(
                        GrGLTextureInfo.fID,
                        (width, height),
                        4, 0, "f1")
                self.moderngl_src_fbo = self.moderngl_context.framebuffer(
                    color_attachments=[self.moderngl_src_texture],
                    depth_attachment=None
                )
                self.moderngl_dst_fbo = self.moderngl_context.framebuffer(
                    color_attachments=[self.moderngl_dst_texture],
                    depth_attachment=None
                )

        if self.surface is None:
            self.surface = skia.Surface(width, height)
            self.cpu_rendering = True

        if self.surface is None:
            raise ValueError("Failed to create surface")
        
        # SVG DOM
        self.matrix = skia.Matrix()
        if self.gl_context:
            self.gl_context.release()
    
    def render(self, float scalex, float scaley, float tx, float ty) -> None:
        """Render the SVG content to the texture at given scale and position"""
        skia = self.skia
        if not self.svg_dom or not self.surface:
            return None
        if self.gl_context:
            self.gl_context.make_current()
        if not(self.cpu_rendering) and not(self.gpu_blit):
            self.texture.gl_begin_write()
        # Clear and setup transform
        canvas = self.surface.getCanvas()
        canvas.clear(skia.Color4f(1.0, 1.0, 1.0, 0.0))
        
        # Set transform
        self.matrix.setScale(scalex, scaley)
        self.matrix.preTranslate(tx, ty)
        canvas.setMatrix(self.matrix)
        # Render SVG
        self.svg_dom.render(canvas)
        if not(self.cpu_rendering):
            self.context.flush()
            # If using GPU but not imported texture, we need to copy
            if self.gpu_blit:
                self.texture.gl_begin_write()
                self.moderngl_context.copy_framebuffer(self.moderngl_dst_fbo, self.moderngl_src_fbo)
            self.texture.gl_end_write()
            if self.gl_context:
                self.gl_context.release()
        else:
            # Upload to the texture
            image = self.surface.makeImageSnapshot()
            if self.gl_context:
                self.gl_context.release()
            self.texture.set_value(image)

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
    # size of the texture
    cdef int32_t _texture_width
    cdef int32_t _texture_height
    # size of the rendered area which the texture contains a crop of
    cdef int32_t _rendered_ref_width
    cdef int32_t _rendered_ref_height
    # relative coordinates of the rendered area that maps to the texture
    cdef double _texture_u0
    cdef double _texture_u1
    cdef double _texture_v0
    cdef double _texture_v1
    cdef bint _preserve_ratio
    cdef bint _no_fill_area
    cdef bint _no_centering

    def __cinit__(self):
        self._pmin = [0., 0.]
        self._pmax = [1., 1.]
        self._texture_width = 0
        self._texture_height = 0
        self._texture_u0 = 0
        self._texture_u1 = 1.
        self._texture_v0 = 0
        self._texture_v1 = 1.
        self._preserve_ratio = True
        self._no_fill_area = False
        self._no_centering = False
        self._texture = dcg.Texture(self.context)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

    @property
    def svg_path(self):
        """
        Path to the SVG file being displayed.

        This path identifies the SVG file loaded by the renderer. Setting this
        property will create a new renderer instance with the provided file.
        """
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return str(self._svg_path, encoding='utf-8')

    @svg_path.setter
    def svg_path(self, str value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        # Store path and create renderer
        self._svg_path = value
        self._renderer = SkiaSVGRenderer(value)

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

    ''' Hidden as should be reworked
    @property
    def no_fill_area(self):
        """Whether to avoid scaling up the SVG to fill the area"""
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        return self._no_fill_area

    @no_fill_area.setter
    def no_fill_area(self, bint value):
        cdef unique_lock[DCGMutex] m
        lock_gil_friendly(m, self.mutex)
        self._no_fill_area = value
    '''

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

        # Calculate UV coordinates if the texture covered the full area
        cdef double u0 = start_x / full_width, v0 = start_y / full_height
        cdef double u1 = stop_x / full_width, v1 = stop_y / full_height
        if self._texture_width != 0:
            # In practice the texture might only cover a subsection
            # of relative coordinates (self._texture_u0, self._texture_v0) to (self._texture_u1, self._texture_v1)
            u0 = (u0 - self._texture_u0) / (self._texture_u1 - self._texture_u0)
            u1 = (u1 - self._texture_u0) / (self._texture_u1 - self._texture_u0)
            v0 = (v0 - self._texture_v0) / (self._texture_v1 - self._texture_v0)
            v1 = (v1 - self._texture_v0) / (self._texture_v1 - self._texture_v0)

        # Round to integers
        cdef int32_t width = <int>cround(w)
        cdef int32_t height = <int>cround(h)
        cdef double scalex, scaley


        # Check if we need to reallocate texture
        # Only reallocate if:
        # 1. We don't have texture yet
        # 2. required content is outside of current texture
        # 3. New required resolution is larger than 1.2 * that of current texture
        # 4. New required size is much smaller (less than 50%) to save memory and prevent aliasing
        cdef double epsilon = 1e-6 # for rounding imprecision
        cdef bint need_realloc = self._texture_width == 0 or \
                                u0 < -epsilon or \
                                u1 > 1. + epsilon or \
                                v0 < -epsilon or \
                                v1 > 1. + epsilon or \
                                full_width > 1.2 * self._rendered_ref_width or \
                                full_height > 1.2 * self._rendered_ref_height or \
                                (full_width < self._rendered_ref_width / 2 and \
                                 full_height < self._rendered_ref_height / 2)

        cdef double rendered_start_x, rendered_start_y
        cdef double rendered_stop_x, rendered_stop_y
        if need_realloc:
            with gil:
                full_width = cround(full_width)
                full_height = cround(full_height)
                # Add 20% margin to reduce recreation frequency
                rendered_start_x = max(0, start_x - 0.1 * width)
                rendered_start_y = max(0, start_y - 0.1 * height)
                rendered_stop_x = min(full_width, stop_x + 0.1 * width)
                rendered_stop_y = min(full_height, stop_y + 0.1 * height)
                self._texture_width = <int>(rendered_stop_x - rendered_start_x)
                self._texture_height = <int>(rendered_stop_y - rendered_start_y)
                self._rendered_ref_width = <int>full_width
                self._rendered_ref_height = <int>full_height
                self._renderer.allocate_texture(self.context,
                                                self._texture_width,
                                                self._texture_height)
                # Calculate scale and translation for full area
                
                # If no_fill_area is set scale only by pixel size
                if self._no_fill_area:
                    scalex = abs((screen_pmax[0] - screen_pmin[0]) / (pmax[0] - pmin[0]))
                    scaley = abs((screen_pmax[1] - screen_pmin[1]) / (pmax[1] - pmin[1]))
                    if self._preserve_ratio:
                        scalex = min(scalex, scaley)
                        scaley = scalex
                else:
                    scalex, scaley = \
                        self._renderer.get_fit_scale(self._rendered_ref_width,
                                                     self._rendered_ref_height,
                                                     self._preserve_ratio)

                if self._no_centering:
                    # Align to top-left
                    tx = 0
                    ty = 0
                else:
                    # Center the SVG
                    tx, ty = \
                        self._renderer.get_centered_translation(self._rendered_ref_width,
                                                                self._rendered_ref_height,
                                                                scalex,
                                                                scaley)

                # Apply shift in full area coordinate
                tx -= rendered_start_x / scalex    
                ty -= rendered_start_y / scaley

                self._renderer.render(scalex, scaley, tx, ty)
                self._texture = self._renderer.texture
                self._texture_u0 = rendered_start_x / full_width
                self._texture_u1 = rendered_stop_x / full_width
                self._texture_v0 = rendered_start_y / full_height
                self._texture_v1 = rendered_stop_y / full_height
                u0 = start_x / full_width
                v0 = start_y / full_height
                u1 = stop_x / full_width
                v1 = stop_y / full_height
                u0 = (u0 - self._texture_u0) / (self._texture_u1 - self._texture_u0)
                u1 = (u1 - self._texture_u0) / (self._texture_u1 - self._texture_u0)
                v0 = (v0 - self._texture_v0) / (self._texture_v1 - self._texture_v0)
                v1 = (v1 - self._texture_v0) / (self._texture_v1 - self._texture_v0)
                

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