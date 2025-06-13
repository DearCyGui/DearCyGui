"""
This file is a collection of wrappers around a subset of ImGui that
are useful to do custom items in DearCyGui.

It doesn't need the user to compile or link against ImGui.

ALL THESE FUNCTIONS SHOULD ONLY BE CALLED FROM draw() METHODS OF CUSTOM ITEMS.

Viewport Rendering Fields
-----------------------
When implementing custom drawing items, several fields from the Viewport class 
affect how coordinates and sizes are transformed:

global_scale (float):
    Current global DPI scaling factor that affects all rendering.
    Should be applied to any pixel coordinate values.
    This is already integrated automatically in the coordinate
    transform.

scales/shifts (double[2]):
    Current coordinate space transform (when not in a plot, else
    implot handles the transform).
    The helpers already include this transform.
    To apply the transform, call viewport.coordinate_to_screen.
    To reverse the transform, call viewport.screen_to_coordinate.

thickness_multiplier (float):
    Factor to apply to line thicknesses. Already includes global_scale.
    Multiply any thickness values by this. The helpers DO NOT include
    this transform.

size_multiplier (float): 
    Factor to apply to object sizes drawn in coordinate space.
    For coordinate space sizes, multiply radius by this.
    For screen space sizes, multiply radius by global_scale instead.
    The helpers DO NOT include this transform.

window_pos (Vec2):
    Position of parent window in viewport screen coordinates.

parent_pos (Vec2):
    Position of direct parent in viewport screen coordinates.
    Note the coordinate transform already takes that into account,
    and the coordinates passed are relative to the parent, and
    its transform.

In addition, the viewports provides some temporary storage for rendering.
This storage should only be used for the current drawing command.

points_coord (DCGVector[float]):
    Temporary storage for points in screen space.
    This is used by several draw_* functions.

temp_normals (DCGVector[float]):
    Temporary storage for normals in screen space.
    This is used by t_draw_polygon and t_draw_polyline,
    which is used beneath most functions. Thus do not use this.

temp_colors (DCGVector[uint32_t]):
    Temporary storage for colors associated with points.
    Unused for now, it is a placeholder for future use.

temp_indices (DCGVector[uint32_t]):
    Temporary storage for indices associated with points.
    It is used by several t_draw_* functions, but not
    t_draw_polygon and t_draw_polyline.

If you call t_draw_polygon or t_draw_polyline directly, you can use
all the above vectors except temp_normals.

If you call draw_polygon or draw_polyline directly, you can use
all the above vectors except temp_normals and points_coord.

points_coord can be used if you call the t_draw_* functions,
except for t_draw_regular_polygon and t_draw_star,
and the t_draw_elli* functions
"""

from libc.stdint cimport uint32_t, int32_t

from .core cimport Context
from .texture cimport Texture, Pattern
from .c_types cimport Vec2, Vec4

### Drawing helpers ###

## Polygons/Polylines ##
# These functions are used to draw polygons and polylines,
# with proper anti-aliasing and fill.
# Many of the other functions essentially map to these two functions,
# but may be more convenient and readable to used.

cdef void draw_polygon(Context context,
                       void* drawlist,
                       const double* points,
                       int points_count,
                       const double* inner_points,
                       int inner_points_count,
                       const uint32_t* indices,
                       int indices_count, 
                       Pattern pattern,
                       uint32_t outline_color,
                       uint32_t fill_color,
                       float thickness) noexcept nogil
"""
    Draw a polygon with both fill and outline in a single call.
    
    Args:
        context: The DearCyGui context
        drawlist_ptr: ImGui draw list to render to
        points: array of points [x0, y0, ..., xn-1, yn-1] defining the outline in order.
        points_count: number of points n
        inner_points: optional array of points [x0, y0, ..., xm-1, ym-1]
            defining points inside the polygon that are referenced for the triangulation,
            but are not on the outline. for instance an index of n+1 will refer to the
            second point in the inner_points array.
        inner_points_count: number of inner points m
        indices: Triangulation indices for the polygon (groups of 3 indices per triangle)
        indices_count: Number of indices (should be a multiple of 3)
        outline_color: Color for the polygon outline (ImU32)
        pattern: Pattern to use for the polygon outline
        fill_color: Color to fill the polygon with (ImU32)
        thickness: Thickness of the outline in pixels

    The points can be either in counter-clockwise or clockwise order.
    If fill_color alpha is 0, only the outline is drawn.
    If outline_color alpha is 0 or thickness is 0, only the fill is drawn.
"""

cdef void draw_polyline(Context context,
                        void* drawlist,
                        const double* points,
                        int points_count,
                        Pattern pattern,
                        uint32_t color,
                        bint closed,
                        float thickness) noexcept nogil
"""
    Draw a series of connected segments with proper anti-aliasing.
    
    Args:
        context: The DearCyGui context
        drawlist_ptr: ImGui draw list to render to
        points: array of points [x0, y0, ..., xn-1, yn-1] defining the polyline in order.
        points_count: number of points n
        pattern: pattern to use for the lines
        color: Color of the line (ImU32)
        closed: Whether to connect the last point back to the first
        thickness: Thickness of the line in pixels
    
    This function handles both thin and thick lines with proper anti-aliasing,
    with special handling for degenerate edges and AA fringes.
 """

# Helpers that directly map to Polygon/Polyline

cdef void draw_line(Context context, void* drawlist,
                    double x1, double y1, double x2, double y2,
                    Pattern pattern,
                    uint32_t color, float thickness) noexcept nogil
"""
    Draw a line segment between two points.

    Args:
        context: The DearCyGui context
        drawlist: ImDrawList to render into
        x1, y1: Starting point coordinates in coordinate space
        x2, y2: Ending point coordinates in coordinate space  
        pattern: Pattern to use for the line
        color: Line color as 32-bit RGBA value
        thickness: Line thickness in pixels
"""

cdef void draw_triangle(Context context, void* drawlist,
                        double x1, double y1, double x2, double y2,
                        double x3, double y3, Pattern pattern,
                        uint32_t color, uint32_t fill_color,
                        float thickness) noexcept nogil
"""
    Draw a triangle defined by three points.

    Args:
        context: The DearCyGui context
        drawlist: ImDrawList to render into
        x1, y1: First point coordinates in coordinate space
        x2, y2: Second point coordinates in coordinate space  
        x3, y3: Third point coordinates in coordinate space
        pattern: Pattern to use for the triangle outline
        color: Outline color as 32-bit RGBA value, alpha=0 for no outline
        fill_color: Fill color as 32-bit RGBA value, alpha=0 for no fill
        thickness: Outline thickness in pixels
"""

cdef void draw_rect(Context context, void* drawlist,
                    double x1, double y1, double x2, double y2,
                    Pattern pattern,
                    uint32_t color, uint32_t fill_color,
                    float thickness, float rounding) noexcept nogil
"""
    Draw a rectangle defined by two corner points.

    Args:
        context: The DearCyGui context
        drawlist: ImDrawList to render into
        x1, y1: First corner coordinates in coordinate space
        x2, y2: Opposite corner coordinates in coordinate space
        pattern: Pattern to use for the rectangle outline
        color: Outline color as 32-bit RGBA value, alpha=0 for no outline
        fill_color: Fill color as 32-bit RGBA value, alpha=0 for no fill
        thickness: Outline thickness in pixels
        rounding: Corner rounding radius in pixels
"""

cdef void draw_quad(Context context, void* drawlist,
                    double x1, double y1, double x2, double y2,
                    double x3, double y3, double x4, double y4,
                    Pattern pattern,
                    uint32_t color, uint32_t fill_color,
                    float thickness) noexcept nogil
"""
    Draw a quadrilateral defined by four points.

    Args:
        context: The DearCyGui context 
        drawlist: ImDrawList to render into
        x1, y1: First point coordinates in coordinate space
        x2, y2: Second point coordinates in coordinate space
        x3, y3: Third point coordinates in coordinate space
        x4, y4: Fourth point coordinates in coordinate space
        pattern: Pattern to use for the quadrilateral outline
        color: Outline color as 32-bit RGBA value, alpha=0 for no outline
        fill_color: Fill color as 32-bit RGBA value, alpha=0 for no fill
        thickness: Outline thickness in pixels

    Points should be specified in counter-clockwise order for proper antialiasing.
"""

# Helpers that map to Polygon/Polyline, but perform intermediate computations

cdef void draw_circle(Context context, void* drawlist,
                      double x, double y, double radius,
                      Pattern pattern,
                      uint32_t color, uint32_t fill_color,
                      float thickness, int32_t num_segments) noexcept nogil
"""
    Draw a circle.

    Args:
        context: The DearCyGui context
        drawlist: ImDrawList to render into
        x, y: Center coordinates in coordinate space
        radius: Circle radius in coordinate space units. Negative for screen space
        pattern: Pattern to use for the circle outline
        color: Outline color as 32-bit RGBA value 
        fill_color: Fill color as 32-bit RGBA value, alpha=0 for no fill
        thickness: Outline thickness in pixels
        num_segments: Number of segments used to approximate the circle,
                     0 for auto-calculated based on radius
"""

cdef void draw_regular_polygon(Context context, void* drawlist,
                               double centerx, double centery,
                               double radius, double direction,  
                               int32_t num_points, Pattern pattern,
                               uint32_t color, uint32_t fill_color,
                               float thickness) noexcept nogil
"""
    Draw a regular polygon with n points.

    Args:
        context: The DearCyGui context
        drawlist: ImDrawList to render into
        centerx,centery: Center coordinates in coordinate space
        radius: Circle radius that contains the points. Negative for screen space.
        direction: Angle of first point from horizontal axis
        num_points: Number of points. If 0 or 1, draws a circle.
        pattern: Pattern to use for the polygon outline
        color: Outline color as 32-bit RGBA value, alpha=0 for no outline
        fill_color: Fill color as 32-bit RGBA value, alpha=0 for no fill
        thickness: Outline thickness in pixels
"""

cdef void draw_star(Context context, void* drawlist,
                    double centerx, double centery, 
                    double radius, double inner_radius,
                    double direction, int32_t num_points,
                    Pattern pattern,
                    uint32_t color, uint32_t fill_color,
                    float thickness) noexcept nogil
"""
    Draw a star shaped polygon.

    Args:
        context: The DearCyGui context
        drawlist: ImDrawList to render into
        centerx,centery: Center coordinates in coordinate space
        radius: Outer circle radius.
        inner_radius: Inner circle radius
        direction: Angle of first point from horizontal axis
        num_points: Number of outer points
        pattern: Pattern to use for the polygon outline
        color: Outline color as 32-bit RGBA value, alpha=0 for no outline
        fill_color: Fill color as 32-bit RGBA value, alpha=0 for no fill
        thickness: Outline thickness in pixels
"""

## Special ##

cdef void draw_rect_multicolor(Context context, void* drawlist,
                               double x1, double y1, double x2, double y2,
                               uint32_t col_up_left, uint32_t col_up_right,
                               uint32_t col_bot_right, uint32_t col_bot_left) noexcept nogil
"""
    Draw a rectangle with different colors at each corner.

    Args:
        context: The DearCyGui context
        drawlist: ImDrawList to render into  
        x1, y1: Top-left corner coordinates in coordinate space
        x2, y2: Bottom-right corner coordinates in coordinate space
        col_up_left: Color for top-left corner as 32-bit RGBA
        col_up_right: Color for top-right corner as 32-bit RGBA
        col_bot_right: Color for bottom-right corner as 32-bit RGBA
        col_bot_left: Color for bottom-left corner as 32-bit RGBA

    The colors are linearly interpolated between the corners.
"""

## Textured drawing functions ##

# Unlike Polyline/Polygon, these functions do not do antialiasing.

# Base texture drawing function. Other functions more or less map to this one.
cdef void draw_textured_triangle(Context context, void* drawlist,
                                 void *texture,
                                 double x1, double y1,
                                 double x2, double y2,
                                 double x3, double y3,
                                 float u1, float v1,
                                 float u2, float v2,
                                 float u3, float v3,
                                 uint32_t color_factor) noexcept nogil
"""
    Draw a triangle extracted from a texture.

    Args:
        context: The DearCyGui context
        drawlist: ImDrawList to render into
        x1, y1: First point coordinates in coordinate space
        x2, y2: Second point coordinates in coordinate space  
        x3, y3: Third point coordinates in coordinate space
        u1, v1: Texture coordinates for first point (0-1 range)
        u2, v2: Texture coordinates for second point
        u3, v3: Texture coordinates for third point
        color_factor: Color to multiply texture samples with (32-bit RGBA)

    A neutral value for color_factor is 0xFFFFFFFF (uint32_teger: 4294967295)
"""

# Helpers that map to the above function

cdef void draw_image_quad(Context context, void* drawlist,
                          void* texture,
                          double x1, double y1, double x2, double y2,
                          double x3, double y3, double x4, double y4,
                          float u1, float v1, float u2, float v2,
                          float u3, float v3, float u4, float v4,
                          uint32_t color_factor) noexcept nogil
"""
    Draw a textured quad with custom UV coordinates.

    Args:
        context: The DearCyGui context
        drawlist: ImDrawList to render into
        texture: ImTextureID to sample from
        x1,y1: First point coordinates in coordinate space 
        x2,y2: Second point coordinates in coordinate space
        x3,y3: Third point coordinates in coordinate space
        x4,y4: Fourth point coordinates in coordinate space
        u1,v1: Texture coordinates for first point (0-1 range)
        u2,v2: Texture coordinates for second point
        u3,v3: Texture coordinates for third point  
        u4,v4: Texture coordinates for fourth point
        color_factor: Color to multiply texture samples with (32-bit RGBA)

    A neutral value for color_factor is 0xFFFFFFFF (unsigned integer: 4294967295)
"""

cdef void draw_text(Context context, void* drawlist,
                    double x, double y,
                    const char* text,
                    uint32_t color,
                    void* font, float size) noexcept nogil
"""
    Draw text at a position.

    Args:
        context: The DearCyGui context
        drawlist: ImDrawList to render into  
        x,y: Text position in coordinate space
        text: Text string to draw
        color: Text color as 32-bit RGBA value
        font: ImFont* to use, NULL for default
        size: Text size. Negative is screen space, 0 for default
"""

cdef void draw_text_quad(Context context, void* drawlist,
                         double x1, double y1, double x2, double y2,  
                         double x3, double y3, double x4, double y4,
                         const char* text, uint32_t color,
                         void* font, bint preserve_ratio) noexcept nogil
"""
    Draw text deformed to fit inside a quad shape.

    Args:
        context: The DearCyGui context
        drawlist: ImDrawList to render into
        x1,y1: top-left coordinates in coordinate space 
        x2,y2: Top-right coordinates in coordinate space
        x3,y3: bottom right coordinates in coordinate space
        x4,y4: bottom left coordinates in coordinate space
        text: Text string to draw
        color: Text color as 32-bit RGBA value. Alpha=0 to use style color.
        font: ImFont* to use, NULL for default
        preserve_ratio: Whether to maintain text aspect ratio when fitting.
            If the text dimension is reduced in one dimension, the resulting
            text is centered on it.
        
    The text is rendered as if it was an image filling a quad shape.
    The quad vertices control the deformation/orientation of the text.
"""

# All above functions take thickness and radius in screen pixels.
# Here is what is needed to have the equivalent behaviour to Draw* items.

cdef inline float get_scaled_thickness(Context context, float thickness) noexcept nogil:
    """
    Thickness parameter handling used by Draw* items.

    Args:
        context: The DearCyGui context
        thickness: Requested thickness

    Returns:
        Corresponding requested thickness in screen pixels

    Positive thickness: in coordinate space
    Negative thickness: in unscaled screen space
    """
    thickness *= context.viewport.thickness_multiplier
    if thickness > 0:
        thickness *= context.viewport.size_multiplier
    return abs(thickness)

cdef inline float get_scaled_radius(Context context, float radius) noexcept nogil:
    """
    Radius parameter handling used by Draw* items.

    Args:
        context: The DearCyGui context
        radius: Requested radius
    Returns:
        Corresponding requested radius in screen pixels

    Positive radius: in coordinate space
    Negative radius: in unscaled screen space
    """
    if radius < 0:
        # screen space radius
        radius = -radius * context.viewport.global_scale
    else:
        radius = radius * context.viewport.size_multiplier
    return radius

# t_draw* variants: Same as above, except all coordinates are in
# 'screen' coordinates instead (top left of the viewport = (0, 0))
# This corresponds to the result of viewport's coordinate_to_screen.
# draw* functions include the transform, while t_draw* functions
# don't. (The t_ prefix is because the coordinates must be transformed)

cdef bint t_item_fully_clipped(Context context,
                               void* drawlist,
                               float item_x_min,
                               float item_x_max,
                               float item_y_min,
                               float item_y_max) noexcept nogil
"""
t_draw_polygon and t_draw_polyline do not perform any clipping.
It can be good for performance however to avoid submitting
items completly outside the rendered region. This skips CPU
and GPU work.

Clipping is already handled by all the other function calls.
Unless you call t_draw_polygon/polyline directly you don't
need to call this.

Inputs:
    context: The DearCyGui context
    drawlist: ImDrawList to render into
    item_x_min: x lower bound for the item
    item_x_max: x higher bound for the item
    item_y_min: y lower bound for the item
    item_y_max: y higher bound for the item

The bounds must be in transformed screen coordinates.
"""

cdef void t_draw_polygon(Context context,
                         void* drawlist_ptr,
                         const float* points,
                         int points_count,
                         const float* inner_points,
                         int inner_points_count,
                         const uint32_t* indices,
                         int indices_count, 
                         Pattern pattern,
                         uint32_t outline_color,
                         uint32_t fill_color,
                         float thickness) noexcept nogil

cdef void t_draw_polyline(Context context,
                          void* drawlist_ptr,
                          const float* points,
                          int points_count,
                          Pattern pattern,
                          uint32_t color,
                          bint closed,
                          float thickness) noexcept nogil

cdef void t_draw_line(Context context, void* drawlist,
                      float x1, float y1, float x2, float y2,
                      Pattern pattern,
                      uint32_t color, float thickness) noexcept nogil

cdef void t_draw_triangle(Context context, void* drawlist,
                          float x1, float y1, float x2, float y2,
                          float x3, float y3, Pattern pattern,
                          uint32_t color, uint32_t fill_color,
                          float thickness) noexcept nogil

cdef void t_draw_rect(Context context, void* drawlist,
                      float x1, float y1, float x2, float y2,
                      Pattern pattern,
                      uint32_t color, uint32_t fill_color,
                      float thickness, float rounding) noexcept nogil

cdef void t_draw_quad(Context context, void* drawlist,
                    float x1, float y1, float x2, float y2,
                    float x3, float y3, float x4, float y4, 
                    Pattern pattern,
                    uint32_t color, uint32_t fill_color,
                    float thickness) noexcept nogil

cdef void t_draw_circle(Context context, void* drawlist,
                      float x, float y, float radius,
                      Pattern pattern,
                      uint32_t color, uint32_t fill_color,
                      float thickness, int32_t num_segments) noexcept nogil

# Helpers that map to Polygon/Polyline, but perform intermediate computations
cdef void t_draw_elliptical_arc(Context context, void* drawlist,
                                float center_x, float center_y,
                                float radius_x, float radius_y,
                                float start_angle, float end_angle,
                                float rotation,  
                                int32_t num_points,
                                Pattern pattern,
                                uint32_t outline_color,
                                uint32_t fill_color,
                                float thickness) noexcept nogil
"""
    Draws a partial ellipse arc with anti-aliasing.

    This version doesn't connect to the center of the ellipse.
    Args:
        context: The DearCyGui context
        drawlist_ptr: ImGui draw list to render to
        center_x, center_y: Center of the ellipse
        radius_x, radius_y: Radii of the ellipse
        start_angle: Starting angle of the arc in radians
        end_angle: Ending angle of the arc in radians
        rotation: Rotation angle of the ellipse in radians
        num_points: Number of points to use for the arc (0 means auto)
        outline_color: Color for the outline (ImU32)
        fill_color: Color for the filling (ImU32)
        thickness: Thickness of the outline
"""

cdef void t_draw_elliptical_pie_slice(Context context, void* drawlist,
                                      float center_x, float center_y,
                                      float radius_x, float radius_y,
                                      float start_angle, float end_angle,
                                      float rotation,  
                                      int32_t num_points,
                                      Pattern pattern,
                                      uint32_t outline_color,
                                      uint32_t fill_color,
                                      float thickness) noexcept nogil
"""
    Draws an elliptical arc segment connected to the center.

    This version does connect to the center of the ellipse.
    Args:
        context: The DearCyGui context
        drawlist_ptr: ImGui draw list to render to
        center_x, center_y: Center of the ellipse
        radius_x, radius_y: Radii of the ellipse
        start_angle: Starting angle of the arc in radians
        end_angle: Ending angle of the arc in radians
        rotation: Rotation angle of the ellipse in radians
        num_points: Number of points to use for the arc (0 means auto)
        outline_color: Color for the outline (ImU32)
        fill_color: Color for the filling (ImU32)
        thickness: Thickness of the outline
"""

cdef void t_draw_elliptical_ring_segment(Context context, void* drawlist,
                                         float center_x, float center_y,
                                         float radius_x, float radius_y,
                                         float inner_radius_x, float inner_radius_y,
                                         float start_angle, float end_angle,
                                         float rotation,  
                                         int32_t num_points,
                                         Pattern pattern,
                                         uint32_t outline_color,
                                         uint32_t fill_color,
                                         float thickness) noexcept nogil
"""
    Draws a partial ellipse arc with anti-aliasing.

    This version does use an inner arc for the outline and filling
    Args:
        context: The DearCyGui context
        drawlist_ptr: ImGui draw list to render to
        center_x, center_y: Center of the ellipse
        radius_x, radius_y: Radii of the ellipse
        inner_radius_x, inner_radius_y: Inner radii of the inner ellipse
        start_angle: Starting angle of the arc in radians
        end_angle: Ending angle of the arc in radians
        rotation: Rotation angle of the ellipse in radians
        num_points: Number of points to use for the external arc (0 means auto)
        outline_color: Color for the outline (ImU32)
        fill_color: Color for the filling (ImU32)
        thickness: Thickness of the outline

    The parameters must verify:
        0 < inner_radius_x < radius_x
        0 < inner_radius_y < radius_y
"""

cdef void t_draw_ellipse(Context context, void* drawlist,
                         float center_x, float center_y,
                         float radius_x, float radius_y,
                         float rotation,  
                         int32_t num_points,
                         Pattern pattern,
                         uint32_t outline_color,
                         uint32_t fill_color,
                         float thickness) noexcept nogil
"""
    Draws a complete ellipse with anti-aliasing.

    Args:
        context: The DearCyGui context
        drawlist_ptr: ImGui draw list to render to
        center_x, center_y: Center of the ellipse
        radius_x, radius_y: Radii of the ellipse
        rotation: Rotation angle of the ellipse in radians
        num_points: Number of points to use for the external arc (0 means auto)
        outline_color: Color for the outline (ImU32)
        fill_color: Color for the filling (ImU32)
        thickness: Thickness of the outline
"""

cdef void t_draw_elliptical_ring(Context context, void* drawlist,
                                 float center_x, float center_y,
                                 float radius_x, float radius_y,
                                 float inner_radius_x, float inner_radius_y,
                                 float rotation,  
                                 int32_t num_points,
                                 Pattern pattern,
                                 uint32_t outline_color,
                                 uint32_t fill_color,
                                 float thickness) noexcept nogil
"""
    Draws a full ellipse with a hole

    Args:
        context: The DearCyGui context
        drawlist_ptr: ImGui draw list to render to
        center_x, center_y: Center of the ellipse
        radius_x, radius_y: Radii of the ellipse
        inner_radius_x, inner_radius_y: Inner radii of the inner ellipse
        rotation: Rotation angle of the ellipse in radians
        num_points: Number of points to use for the external arc (0 means auto)
        outline_color: Color for the outline (ImU32)
        fill_color: Color for the filling (ImU32)
        thickness: Thickness of the outline

    The parameters must verify:
        0 < inner_radius_x < radius_x
        0 < inner_radius_y < radius_y
"""

cdef void t_draw_regular_polygon(Context context, void* drawlist,
                                 float centerx, float centery,
                                 float radius, float direction,  
                                 int32_t num_points,
                                 Pattern pattern,
                                 uint32_t color, uint32_t fill_color,
                                 float thickness) noexcept nogil

cdef void t_draw_star(Context context, void* drawlist,
                      float centerx, float centery, 
                      float radius, float inner_radius,
                      float direction, int32_t num_points,
                      Pattern pattern,
                      uint32_t color, uint32_t fill_color,
                      float thickness) noexcept nogil

cdef void t_draw_rect_multicolor(Context context, void* drawlist,
                                 float x1, float y1, float x2, float y2,
                                 uint32_t col_up_left, uint32_t col_up_right, 
                                 uint32_t col_bot_right, uint32_t col_bot_left) noexcept nogil

cdef void t_draw_textured_triangle(Context context, void* drawlist,
                                  void* texture,
                                  float x1, float y1, float x2, float y2, float x3, float y3,
                                  float u1, float v1, float u2, float v2, float u3, float v3,
                                  uint32_t tint_color) noexcept nogil

cdef void t_draw_image_quad(Context context, void* drawlist,
                            void* texture,
                            float x1, float y1, float x2, float y2,
                            float x3, float y3, float x4, float y4,
                            float u1, float v1, float u2, float v2,
                            float u3, float v3, float u4, float v4,
                            uint32_t tint_color) noexcept nogil

cdef void t_draw_text(Context, void*, float, float,
                      const char*, uint32_t, void*, float) noexcept nogil

cdef void t_draw_text_quad(Context, void*, float, float, float, float,
                           float, float, float, float,
                           const char*, uint32_t, void*, bint) noexcept nogil

# Advanced polygon functions
cdef void t_draw_compute_normals(Context context,
                                 float* normals,
                                 const float* points,
                                 int points_count,
                                 bint closed) noexcept nogil
"""
    Computes the normals at each point of an outline
    Inputs:
        context: The DearCyGui context
        points: array of points [x0, y0, ..., xn-1, yn-1]
        points_count: number of points n
        closed: Whether the last point of the outline is
            connected to the first point
    Outputs:
        normals: array of normals [dx0, dy0, ..., dxn-1, dyn-1]
            The array must be preallocated.

    The normals are the average of the normals of the two neighboring edges.
    They are scaled to the inverse of the length of this average, this results that
    adding a width of w to the two edges will intersect in a point located to w times
    the normal of the point.
"""

cdef void t_draw_compute_normal_at(Context context,
                                   float* normal_out,
                                   const float* points,
                                   int points_count,
                                   int point_idx,
                                   bint closed) noexcept nogil
"""
    Computes the normal vector at a specific point index of an outline.
    Useful if you have computed the normals for most points with a formula
    and needs to fix it at specific points.
    
    Args:
        context: The DearCyGui context
        normal_out: Output array [dx, dy] where the normal will be written
        points: Array of points [x0, y0, ..., xn-1, yn-1]
        points_count: Number of points n
        point_idx: Index of the point to compute the normal for (0 to points_count-1)
        closed: Whether the last point connects to the first point

    The normal is computed as the average of the normals of the two 
    adjacent edges, scaled by the inverse of the squared length.
"""

cdef void t_draw_polygon_outline(Context context,
                                 void* drawlist_ptr,
                                 const float* points,
                                 int points_count,
                                 const float* normals,
                                 Pattern pattern,
                                 uint32_t color,
                                 float thickness,
                                 bint closed) noexcept nogil
"""
    Draws an antialiased outline centered on the edges defined
    by the set of points.

    Inputs:
        context: The DearCyGui context
        drawlist_ptr: ImGui draw list to render to
        points: array of points [x0, y0, ..., xn-1, yn-1]
        points_count: number of points n
        normals: array of normals [dx0, dy0, ..., dxn-1, dyn-1] for each point
        pattern: The outline pattern (None for solid)
        color: color of the outline
        thickness: thickness of the outline
        closed: Whether the last point of the outline is
            connected to the first point
"""

cdef void t_draw_polygon_filling(Context context,
                                 void* drawlist_ptr,
                                 const float* points,
                                 int points_count,
                                 const float* normals,
                                 const float* inner_points,
                                 int inner_points_count,
                                 const uint32_t* indices,
                                 int indices_count,
                                 uint32_t fill_color) noexcept nogil
"""
    Draws a filled polygon using the provided points, indices and normals.
    
    Args:
        context: The DearCyGui context
        drawlist_ptr: ImGui draw list to render to
        points: array of points [x0, y0, ..., xn-1, yn-1] defining the polygon in order.
        points_count: number of points n
        normals: array of normals [dx0, dy0, ..., dxn-1, dyn-1] for each point
        inner_points: optional array of points [x0, y0, ..., xm-1, ym-1]
            defining points inside the polygon that are referenced for the triangulation,
            but are not on the outline. for instance an index of n+1 will refer to the
            second point in the inner_points array.
        inner_points_count: number of inner points m
        indices: Triangulation indices for the polygon (groups of 3 indices per triangle)
        indices_count: Number of indices (should be a multiple of 3)
        fill_color: Color to fill the polygon with (ImU32)
"""

cdef void t_draw_polygon_filling_no_aa(Context context,
                                       void* drawlist_ptr,
                                       const float* points,
                                       int points_count,
                                       const float* inner_points,
                                       int inner_points_count,
                                       const uint32_t* indices,
                                       int indices_count,
                                       uint32_t fill_color) noexcept nogil
"""
    Draws a filled polygon without anti-aliasing for improved performance.
    
    Args:
        context: The DearCyGui context
        drawlist_ptr: ImGui draw list to render to
        points: array of points [x0, y0, ..., xn-1, yn-1] defining the polygon in order
        points_count: number of points n
        inner_points: optional array of points inside the polygon for triangulation
        inner_points_count: number of inner points
        indices: Triangulation indices for the polygon (groups of 3 indices per triangle)
        indices_count: Number of indices (should be a multiple of 3)
        fill_color: Color to fill the polygon with (ImU32)
"""


# When subclassing drawingItem and Draw* items, the drawlist
# is passed to the draw method. This is a helper to get the
# drawlist for the current window if subclassing uiItem.
cdef void* get_window_drawlist(Context context) noexcept nogil
"""
    Get the ImDrawList for the current window.
    
    Used by draw items that want to render into the current window.

    Args:
        context: The DearCyGui context

    Returns:
        ImDrawList* for the current window
"""

cdef Vec2 get_cursor_pos(Context context) noexcept nogil
"""
    Get the current cursor position in the current window.
    Useful when drawing on top of subclassed UI items.
    To properly transform the coordinates, swap this
    with viewports's parent_pos before drawing,
    and restore parent_pos afterward.
"""

    
# Theme functions
# The indices of must be resolved using
# ImGuiColorIndex, etc enums which are available
# using an import dearcygui.
# Load these indices in your __cinit__.
cdef void push_theme_color(Context context, int32_t idx, float r, float g, float b, float a) noexcept nogil
"""Push a theme color onto the stack (use at start of drawing code)"""

cdef void pop_theme_color(Context context) noexcept nogil
"""Pop a theme color from the stack (use at end of drawing code)"""

cdef void push_theme_style_float(Context context, int32_t idx, float val) noexcept nogil
"""Push a float style value onto the stack"""

cdef void push_theme_style_vec2(Context context, int32_t idx, float x, float y) noexcept nogil  
"""Push a Vec2 style value onto the stack"""

cdef void pop_theme_style(Context context) noexcept nogil
"""Pop a style value from the stack"""

cdef Vec4 get_theme_color(Context context, int32_t idx) noexcept nogil
"""
Retrieve the current theme color for a target idx.

Args:
    context: The DearCyGui context
    idx: ThemeCol index to query

Returns:
    Vec4 containing RGBA color values
"""


cdef float get_theme_style_float(Context context, int32_t idx) noexcept nogil
"""
Retrieve the current theme style float value for a target idx.
Args:
    context: The DearCyGui context
    idx: ImGuiStyleVar index to query
Returns:
    float value for the style variable.
"""

cdef Vec2 get_theme_style_vec2(Context context, int32_t idx) noexcept nogil
"""
Retrieve the current theme style Vec2 value for a target idx.
Args:
    context: The DearCyGui context
    idx: ImGuiStyleVar index to query
Returns:
    Vec2 containing the style variable value.
"""


# Text measurement functions
cdef Vec2 calc_text_size(Context context, const char* text, void* font, float size, float wrap_width) noexcept nogil
"""
Calculate text size in screen coordinates.

Args:
    context: The DearCyGui context
    text: Text string to measure
    font: ImFont* to use, NULL for default 
    size: Text size, 0 for default, negative for screen space
    wrap_width: Width to wrap text at, 0 for no wrap

Returns:
    Vec2 containing width and height in pixels
"""

cdef struct GlyphInfo:
    float advance_x     # Distance to advance cursor after rendering (in pixels)
    float size_x       # Glyph width in pixels 
    float size_y       # Glyph height in pixels
    float u0, v0       # Texture coordinates for top-left
    float u1, v1       # Texture coordinates for bottom-right
    float offset_x     # Horizontal offset from cursor position
    float offset_y     # Vertical offset from cursor position
    bint visible       # True if glyph has a visible bitmap
    
cdef GlyphInfo get_glyph_info(Context context, void* font, uint32_t codepoint) noexcept nogil
"""
Get rendering information for a Unicode codepoint.

Args:
    context: The DearCyGui context
    codepoint: Unicode codepoint value
    font: ImFont* to query, NULL for default font

Returns:  
    GlyphInfo struct containing metrics and texture coords
"""

