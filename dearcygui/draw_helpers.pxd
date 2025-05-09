from .c_types cimport DCGVector


# A set of helper functions to draw complex shapes.

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