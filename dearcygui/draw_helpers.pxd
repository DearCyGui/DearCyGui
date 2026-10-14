from .c_types cimport DCGVector


# A set of helper functions to draw complex shapes.

cdef void generate_bezier_cubic_points(DCGVector[float]& points,
                                       DCGVector[float]& normals,
                                       float x1, float y1,
                                       float x2, float y2,
                                       float x3, float y3,
                                       float x4, float y4,
                                       int num_segments) noexcept nogil
"""
    Generate the points of a cubic Bezier curve, from (x1, y1) to (x4, y4).

    Args:
        points: Output vector to store generated points
        normals: Output vector to store normals for each point
        x1, y1: Start point
        x2, y2: First control point
        x3, y3: Second control point
        x4, y4: End point
        num_segments: Number of segments (if <= 0, automatically calculated
            from the control points, which must be in screen space)

    num_segments + 1 points are appended. The first point is (x1, y1), so
    patterns start there.
"""

cdef void generate_bezier_quadratic_points(DCGVector[float]& points,
                                           DCGVector[float]& normals,
                                           float x1, float y1,
                                           float x2, float y2,
                                           float x3, float y3,
                                           int num_segments) noexcept nogil
"""
    Generate the points of a quadratic Bezier curve, from (x1, y1) to (x3, y3).

    Args:
        points: Output vector to store generated points
        normals: Output vector to store normals for each point
        x1, y1: Start point
        x2, y2: Control point
        x3, y3: End point
        num_segments: Number of segments (if <= 0, automatically calculated
            from the control points, which must be in screen space)

    num_segments + 1 points are appended. The first point is (x1, y1), so
    patterns start there. Normals are unit vectors, using the same side
    convention as t_draw_compute_normals.
"""

cdef void generate_elliptical_arc_points(DCGVector[float]& points,
                                         DCGVector[float]& normals,
                                         float centerx,
                                         float centery,
                                         float radiusx,
                                         float radiusy,
                                         float rotation,
                                         float start_angle,
                                         float end_angle,
                                         int num_segments,
                                         bint inner_normals) noexcept nogil
"""
    Generate points for an elliptical arc.
    
    Args:
        points: Output vector to store generated points
        normals: Output vector to store normals for each point
        centerx, centery: Center of the ellipse
        radiusx, radiusy: Major and minor radii of the ellipse
        rotation: Rotation of the ellipse in radians
        start_angle, end_angle: Start and end angles in radians
        num_segments: Number of segments to generate (if ≤ 0, automatically calculated)
        normals_sign: If True the normals points towards the center the arc instead of the outside.

    The start_angle and end_angle parameters are in the ellipse's own coordinate
    system before rotation is applied.
"""

cdef void generate_rect_points(DCGVector[float]& points,
                               DCGVector[float]& normals,
                               float x1, float y1,
                               float x2, float y2,
                               float rounding,
                               int num_segments) noexcept nogil
"""
    Generate the outline points of a (possibly rounded) axis-aligned rectangle.

    Args:
        points: Output vector to store generated points
        normals: Output vector to store normals for each point
        x1, y1: First corner. The outline starts here.
        x2, y2: Opposite corner (any ordering relative to x1, y1)
        rounding: Corner radius. Values below 0.5 give sharp corners.
        num_segments: Segments per rounded corner (if <= 0, automatically calculated)

    The path goes (x1, y1) -> (x2, y1) -> (x2, y2) -> (x1, y2). With rounding,
    the first point is the start of the rounded corner at (x1, y1).
    Normals use the same side convention as t_draw_compute_normals.
"""