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

from libc.math cimport M_PI
from libcpp.algorithm cimport swap
from libcpp.cmath cimport sin, cos, sqrt, atan2, pow, fmod, fabs, fmin, fmax

from .core cimport Context
from .c_types cimport DCGVector
from .draw_helpers cimport generate_elliptical_arc_points
from .imgui_types cimport ImGuiStyleIndex, ImVec2Vec2
from .texture cimport Pattern, get_pattern_u
from .wrapper cimport imgui


cdef bint t_item_fully_clipped(Context context,
                               void* drawlist_ptr,
                               float item_x_min,
                               float item_x_max,
                               float item_y_min,
                               float item_y_max) noexcept nogil:
    cdef imgui.ImDrawList* draw_list = <imgui.ImDrawList*>drawlist_ptr
    cdef imgui.ImVec2 clip_min = draw_list.GetClipRectMin()
    cdef imgui.ImVec2 clip_max = draw_list.GetClipRectMax()

    # For safe clipping, the vertices must be fully on the same
    # side of the clipping rectangle
    if (item_x_min > clip_max.x
        or item_x_max < clip_min.x
        or item_y_min > clip_max.y
        or item_y_max < clip_min.y):
        return True  # Polygon is fully clipped
    return False  # Polygon is clipped, partially clipped or not clipped


cdef bint _is_polygon_counter_clockwise(const float* points, int points_count) noexcept nogil:
    """
    Determines if the provided polygon vertices are in counter-clockwise order.
    
    Uses the shoelace formula to calculate the signed area of the polygon.
    
    Args:
        points: Array of polygon vertices
        points_count: Number of vertices
        
    Returns:
        True if vertices are in counter-clockwise order, False otherwise
    """
    if points_count < 3:
        return True  # Not enough points for meaningful orientation
    
    cdef float area = 0.0
    cdef int i, next_i
    
    # Calculate signed area using the shoelace formula
    for i in range(points_count):
        next_i = (i + 1) % points_count
        area += (points[2*i] * points[2*next_i+1]) - (points[2*next_i] * points[2*i+1])
    
    # Positive area means counter-clockwise orientation
    return area > 0.0


cdef void t_draw_compute_normals(Context context,
                                 float* normals,
                                 const float* points,
                                 int points_count,
                                 bint closed) noexcept nogil:
    """
    Computes the normals at each point of an outline
    Inputs:
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
    cdef int i0, i1, i
    cdef float dx, dy, d_len, edge_angle, edge_length
    cdef float min_valid_len = 1e-4
    cdef float min_valid_len2 = 1e-2
    if points_count < 2:
        return

    # Calculate normals towards the outside of the polygon
    for i0 in range(points_count):
        normals[2*i0] = 0
        normals[2*i0+1] = 0
        i1 = (i0 + 1) % points_count

        # Calculate edge vector
        dx = points[2*i1] - points[2*i0]
        dy = points[2*i1+1] - points[2*i0+1]
        
        # Compute squared length
        d_len = dx*dx + dy*dy
        
        # Handle degenerate edges robustly
        # The thresholds are assuming points
        # are floats in screen coordinates (about 1e3)
        if d_len > 1e-3:
            d_len = 1.0 / sqrt(d_len)
            # Normal is perpendicular to edge
            normals[2*i0] = dy * d_len
            normals[2*i0+1] = -dx * d_len
        elif d_len < 1e-8:
            normals[2*i0] = 0.0
            normals[2*i0+1] = 0.0  # When averaging this will give priority to the neighboring normals
        else:
            # Use trigonometry for precision in near-degenerate cases
            edge_angle = atan2(dy, dx)
            normals[2*i0] = sin(edge_angle)
            normals[2*i0+1] = -cos(edge_angle)

    # To retrieve the normal at each point, we average the normals of the two edges
    # that meet at that point. This is done to ensure smooth transitions between edges.

    cdef float[2] last_normal = [normals[2*(points_count - 1)],
                                 normals[2*(points_count - 1)+1]]
    if closed:
        normals[2*(points_count - 1)] = (normals[2*(points_count - 1)] + normals[2*(points_count - 2)]) * 0.5
        normals[2*(points_count - 1)+1] = (normals[2*(points_count - 1)+1] + normals[2*(points_count - 2)+1]) * 0.5
    else:
        # In that case the normal we have computed in this slot is incorrect
        # since we looped back. The correct normal is the one in the previous slot.
        normals[2*(points_count - 1)] = normals[2*(points_count - 2)]
        normals[2*(points_count - 1)+1] = normals[2*(points_count - 2)+1]

    for i in range(points_count-2, 0, -1):
        i0 = i
        i1 = i - 1
        normals[2*i0] = (normals[2*i0] + normals[2*i1]) * 0.5
        normals[2*i0+1] = (normals[2*i0+1] + normals[2*i1+1]) * 0.5

    if closed:
        normals[0] = (normals[0] + last_normal[0]) * 0.5
        normals[1] = (normals[1] + last_normal[1]) * 0.5

    cdef float dx_n, dy_n, d_len2
    # Inverse normals length
    for i in range(points_count):
        dx_n = normals[2*i]
        dy_n = normals[2*i+1]
        d_len2 = dx_n*dx_n + dy_n*dy_n
        if d_len2 > 1e-3:
            normals[2*i] = dx_n / d_len2
            normals[2*i+1] = dy_n / d_len2
        elif d_len2 < 1e-8:
            # Either the points were too close and we lost accuracy,
            # or the edge does a 180 degree turn.
            # if we have a 180 degrees turn, the normal is parallel
            # to the edge, and we clamp its length to 100.
            i1 = (i0 + 1) % points_count
            # Calculate edge vector
            dx = points[2*i1] - points[2*i0]
            dy = points[2*i1+1] - points[2*i0+1]
            d_len = dx*dx + dy*dy
            if d_len < 1e-8:
                # Points are too close, we cannot compute a normal
                # Setting to zero will result in no AA fringe,
                # but it's better than an artifact
                normals[2*i] = 0.0
                normals[2*i+1] = 0.0
            else:
                d_len = 1. / sqrt(d_len)
                normals[2*i] = -dx * 100. * d_len
                normals[2*i+1] = -dy * 100. * d_len
        else:
            # Use trigonometry for precision in near-degenerate cases
            edge_angle = atan2(dy_n, dx_n)
            normals[2*i] = sin(edge_angle) * 100. # clampling 1/d_len2 to 1./min_valid_len2
            normals[2*i+1] = -cos(edge_angle) * 100.


cdef void t_draw_compute_normal_at(Context context,
                                   float* normal_out,
                                   const float* points,
                                   int points_count,
                                   int point_idx,
                                   bint closed) noexcept nogil:
    """
    Computes the normal vector at a specific point index of an outline.
    
    Args:
        normal_out: Output array [dx, dy] where the normal will be written
        points: Array of points [x0, y0, ..., xn-1, yn-1]
        points_count: Number of points n
        point_idx: Index of the point to compute the normal for (0 to points_count-1)
        closed: Whether the last point connects to the first point
    
    The normal is computed as the average of the normals of the two 
    adjacent edges, scaled by the inverse of the squared length.
    """
    if points_count < 2 or point_idx < 0 or point_idx >= points_count:
        normal_out[0] = 0.0
        normal_out[1] = 0.0
        return
        
    cdef float dx0, dy0, d_len0
    cdef float dx1, dy1, d_len1
    cdef float edge_angle
    cdef float normal_x = 0.0
    cdef float normal_y = 0.0
    cdef int prev_idx, next_idx
    
    # Handle special cases for first and last points
    if point_idx == 0:
        prev_idx = (points_count - 1) if closed else  0
    else:
        prev_idx = point_idx - 1
        
    if point_idx == points_count - 1:
        next_idx = 0 if closed else (points_count - 1)
    else:
        next_idx = point_idx + 1
    
    # Calculate normal for the "incoming" edge (prev -> current)
    if prev_idx != point_idx:
        dx0 = points[2*point_idx] - points[2*prev_idx]
        dy0 = points[2*point_idx+1] - points[2*prev_idx+1]
        d_len0 = dx0*dx0 + dy0*dy0
        
        if d_len0 > 1e-3:
            d_len0 = 1.0 / sqrt(d_len0)
            normal_x += dy0 * d_len0
            normal_y += -dx0 * d_len0
        elif d_len0 >= 1e-8:
            edge_angle = atan2(dy0, dx0)
            normal_x += sin(edge_angle)
            normal_y += -cos(edge_angle)
    
    # Calculate normal for the "outgoing" edge (current → next)
    if next_idx != point_idx:
        dx1 = points[2*next_idx] - points[2*point_idx]
        dy1 = points[2*next_idx+1] - points[2*point_idx+1]
        d_len1 = dx1*dx1 + dy1*dy1
        
        if d_len1 > 1e-3:
            d_len1 = 1.0 / sqrt(d_len1)
            normal_x += dy1 * d_len1
            normal_y += -dx1 * d_len1
        elif d_len1 >= 1e-8:
            edge_angle = atan2(dy1, dx1)
            normal_x += sin(edge_angle)
            normal_y += -cos(edge_angle)
    
    # Average the normals
    if (prev_idx != point_idx) and (next_idx != point_idx):
        normal_x *= 0.5
        normal_y *= 0.5 # TODO: when there are equal points, look further away to compute the normal
    
    # Scale by inverse squared length (like in the original function)
    d_len0 = normal_x*normal_x + normal_y*normal_y
    
    if d_len0 > 1e-3:
        normal_out[0] = normal_x / d_len0
        normal_out[1] = normal_y / d_len0
    elif d_len0 < 1e-8:
        dx1 = points[2*next_idx] - points[2*point_idx]
        dy1 = points[2*next_idx+1] - points[2*point_idx+1]
        d_len1 = dx1*dx1 + dy1*dy1
        if d_len1 > 1e-8:
            d_len1 = 1.0 / sqrt(d_len1)
            normal_out[0] = -dx1 * 100.0 * d_len1
            normal_out[1] = -dy1 * 100.0 * d_len1
        else:
            # Degenerate case, no valid normal
            normal_out[0] = 0.0
            normal_out[1] = 0.0
    else:
        # Handle near-degenerate case with trigonometry
        edge_angle = atan2(normal_y, normal_x)
        normal_out[0] = sin(edge_angle) * 100.0
        normal_out[1] = -cos(edge_angle) * 100.0

"""
    ## AA strategy for polylines

    The original imgui code adapted for this function used Miter joints.

    The issue is that when the angle between two edges get very sharp, the
    joints become very large and look quite bad. However for joints with
    a small angle, the miter joints are very small and look good.

    The advantage of miter joints is that they produce fewer vertices
    and are cheap to compute.

    A second point is that since we would like to support mapping a texture
    on the outline, we need symmetry of the triangulation of the joints.

    A third point is that we would like that the rendering an end of line
    gives the same visual result as the rendering of a 180 joint angle.

    A fourth point is that we would like the rendering to give no sharp
    changes when slowly changing the position of the points.

    For the opaque part of the outline, when summing all these
    constraints, a proposed strategy is to hold the following guarantee:
    ** The distance to the border of the opaque outline of the vertices
       is always less or equal to sqrt(2)/2 times the half width of the opaque edge **

    This results that for an angle below or equal to 90 degrees, miter joints
    can be used.

    For angles above 90 degrees, we use a clipped miter joint, with a clipping bound
    such that the maximum distance is kept (the clipping distance is lower than the
    distance!)

    The strategy converges when the angles gets to 180 degrees to a squared cap.

    On top of that, for the AA part, a bevel joint is used to ensure a constant 1
    pixel wide on the while edge, except for the corners, where the AA can be slightly
    less.

"""

cdef void _t_draw_polygon_outline_thin(Context context,
                                       void* drawlist_ptr,
                                       const float* points,
                                       int points_count,
                                       const float* normals,
                                       uint32_t color,
                                       float thickness,
                                       bint closed) noexcept nogil:
    """
    t_draw_polygon_outline for thickness <= AA_SIZE
    """
    cdef imgui.ImDrawList* draw_list = <imgui.ImDrawList*>drawlist_ptr
    cdef imgui.ImVec2 uv_white = imgui.GetFontTexUvWhitePixel()
    cdef imgui.ImU32 color_trans = color & ~imgui.IM_COL32_A_MASK
    cdef float AA_SIZE = draw_list._FringeScale

    # Apply alpha scaling for thickness < AA_SIZE
    cdef uint32_t alpha
    cdef float alpha_scale, d_len0, d_len1

    if thickness < AA_SIZE:
        # Extract current alpha value
        alpha = (color >> 24) & 0xFF
            
        # Apply power function with exponent 0.7 (smoother transition than linear)
        # This keeps thin lines more visible while still fading appropriately
        alpha_scale = pow(fmax(thickness/AA_SIZE, 0.), 0.7)
            
        # Modify alpha channel while preserving RGB
        alpha = <uint32_t>(alpha * alpha_scale)
        if alpha == 0:
            # Nothing to draw
            return
        color = (color & 0x00FFFFFF) | (alpha << 24)
    
    # Compute normals for each edge with improved precision handling
    cdef int i0, i1, i2
    # Reserve space for vertices and indices
    cdef int vtx_count, idx_count
    
    vtx_count = points_count * 3  # 3 vertices per point (center + 2 AA edges)
    idx_count = (points_count - 1) * 12  # 4 triangles (12 indices) per line segment
    if closed and points_count > 2:
        idx_count += 12  # Add space for the closing segment
    
    draw_list.PrimReserve(idx_count, vtx_count)
    
    cdef unsigned int vtx_base_idx = draw_list._VtxCurrentIdx
    cdef unsigned int idx0, idx1
    cdef float dm_x, dm_y, fringe_x, fringe_y
    cdef float dm0_x, dm0_y
    cdef float dm1_x, dm1_y
   
    # Thin anti-aliased lines implementation
    for i0 in range(points_count):
        dm_x = normals[2*i0]
        dm_y = normals[2*i0+1]
            
        # Center vertex
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0], points[2*i0+1]),
            uv_white, 
            <imgui.ImU32>color  # Center, full color
        )
        
        # Edge vertices with AA fringe
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] + dm_x * AA_SIZE,
                        points[2*i0+1] + dm_y * AA_SIZE),
            uv_white,
            <imgui.ImU32>color_trans  # Edge, transparent
        )
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] - dm_x * AA_SIZE,
                        points[2*i0+1] - dm_y * AA_SIZE),
            uv_white,
            <imgui.ImU32>color_trans  # Edge, transparent
        )
        
        # Add indices for thin line segment
        if i0 < points_count - 1 or (closed and points_count > 2):
            idx0 = vtx_base_idx + i0 * 3
            idx1 = vtx_base_idx + ((i0 + 1) % points_count) * 3
            
            # Right side triangles
            draw_list.PrimWriteIdx(idx0 + 0)
            draw_list.PrimWriteIdx(idx1 + 0)
            draw_list.PrimWriteIdx(idx0 + 1)
            
            draw_list.PrimWriteIdx(idx0 + 1)
            draw_list.PrimWriteIdx(idx1 + 0)
            draw_list.PrimWriteIdx(idx1 + 1)
            
            # Left side triangles
            draw_list.PrimWriteIdx(idx0 + 2)
            draw_list.PrimWriteIdx(idx1 + 2)
            draw_list.PrimWriteIdx(idx0 + 0)
            
            draw_list.PrimWriteIdx(idx0 + 0)
            draw_list.PrimWriteIdx(idx1 + 2)
            draw_list.PrimWriteIdx(idx1 + 0)

cdef void _t_draw_polygon_outline_thick(Context context,
                                        void* drawlist_ptr,
                                        const float* points,
                                        int points_count,
                                        const float* normals,
                                        uint32_t color,
                                        float thickness,
                                        bint closed) noexcept nogil:
    """
    t_draw_polygon_outline for thickness > AA_SIZE.
    """
    cdef imgui.ImDrawList* draw_list = <imgui.ImDrawList*>drawlist_ptr
    cdef imgui.ImVec2 uv_white = imgui.GetFontTexUvWhitePixel()
    cdef imgui.ImU32 color_trans = color & ~imgui.IM_COL32_A_MASK
    cdef float AA_SIZE = draw_list._FringeScale

    # Reserve space for vertices and indices
    cdef int max_vtx_count = points_count * 6
    cdef int max_idx_count = points_count * 27 + 24  # Worst case for all segments

    if points_count < 2:
        return
    
    draw_list.PrimReserve(max_idx_count, max_vtx_count)
    
    cdef unsigned int vtx_base_idx = draw_list._VtxCurrentIdx
    cdef float half_inner_thickness = (thickness - AA_SIZE) * 0.5

    cdef int i0, i1
    cdef float dm_x, dm_y
    cdef float dx, dy, dn_x, dn_y
    cdef bint normal_direction_inverted
    
    cdef float miter_distance, clipped_miter_distance, perpendicular_distance
    cdef float sin_theta_half, cos_theta_half
    cdef float inner_distance

    cdef int vtx_count = 0
    cdef int idx_count = 0
    cdef int idx_exterior_aa, idx_interior_aa
    cdef int idx_exterior, idx_interior

    # key vertices for the next vertex to connect to
    cdef int next_idx_exterior_aa, next_idx_interior_aa
    cdef int next_idx_exterior, next_idx_interior

    # key vertices of the previous vertex to connect to
    cdef int prev_idx_exterior_aa = -1
    cdef int prev_idx_exterior = -1
    cdef int prev_idx_interior = -1
    cdef int prev_idx_interior_aa = -1

    # key vertices for the first vertex when not closed
    cdef int zero_idx_exterior_aa = -1
    cdef int zero_idx_exterior = -1
    cdef int zero_idx_interior = -1
    cdef int zero_idx_interior_aa = -1

    # exterior: where the normal points to
    # interior: the other direction
    # inner: the thick part of the outline
    # outer: the AA part of the outline

    # CAP
    if not closed:
        # We use a rectangular cap for open lines
        # The cap is such that it gives the same visual
        # result as a 180 degree joint angle.
        # The cap is a rectangle of size thickness x thickness,
        # with the center at the end of the line.
        # The rectangle is aligned with the line.

        dm_x = normals[0] # NOTE: for extremities the normals are normalized.
        dm_y = normals[1]

        # Retrieve the normalized direction
        dn_x = -dm_y
        dn_y = dm_x

        # orient dn away from the next point
        dx = points[2*1] - points[0]
        dy = points[2*1+1] - points[0+1]
        # scalar product sign check
        if dx * dn_x + dy * dn_y > 0:
            dn_x = -dn_x
            dn_y = -dn_y

        # Inner vertices (closer to center line)
        i0 = 0
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] - dm_x * half_inner_thickness + dn_x * half_inner_thickness, 
                         points[2*i0+1] - dm_y * half_inner_thickness + dn_y * half_inner_thickness),
            uv_white, <imgui.ImU32>color  # Inner edge, full color
        )
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] + dm_x * half_inner_thickness + dn_x * half_inner_thickness, 
                         points[2*i0+1] + dm_y * half_inner_thickness + dn_y * half_inner_thickness),
            uv_white, <imgui.ImU32>color  # Inner edge, full color
        )

        # Outer vertices (with AA fringe)
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] - dm_x * (half_inner_thickness + AA_SIZE) + dn_x * (half_inner_thickness + AA_SIZE),
                         points[2*i0+1] - dm_y * (half_inner_thickness + AA_SIZE) + dn_y * (half_inner_thickness + AA_SIZE)),
            uv_white, <imgui.ImU32>color_trans  # Outer edge, transparent
        )
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] + dm_x * (half_inner_thickness + AA_SIZE) + dn_x * (half_inner_thickness + AA_SIZE),
                         points[2*i0+1] + dm_y * (half_inner_thickness + AA_SIZE) + dn_y * (half_inner_thickness + AA_SIZE)),
            uv_white, <imgui.ImU32>color_trans  # Outer edge, transparent
        )

        idx_exterior_aa = 3
        idx_exterior = 1
        idx_interior = 0
        idx_interior_aa = 2

        # two triangles at the end of the cap
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)

        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)

        vtx_count += 4
        idx_count += 6

        prev_idx_exterior_aa = idx_exterior_aa
        prev_idx_exterior = idx_exterior
        prev_idx_interior = idx_interior
        prev_idx_interior_aa = idx_interior_aa


    for i0 in range(0 if closed else 1, points_count if closed else (points_count-1)):
        dm_x = normals[2*i0]
        dm_y = normals[2*i0+1]

        if dm_x * dm_x + dm_y * dm_y <= 2.01: # sqrt(2) distance with rounding margin
            # Use miter joints for angles <= 90 degrees

            # Calculate vertex positions for thick line with AA fringe
            # Inner vertices (closer to center line)
            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] - dm_x * half_inner_thickness, 
                             points[2*i0+1] - dm_y * half_inner_thickness),
                uv_white, <imgui.ImU32>color  # Inner edge, full color
            )
            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] + dm_x * half_inner_thickness, 
                             points[2*i0+1] + dm_y * half_inner_thickness),
                uv_white, <imgui.ImU32>color  # Inner edge, full color
            )
            
            # Outer vertices (with AA fringe)
            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] - dm_x * (half_inner_thickness + AA_SIZE),
                             points[2*i0+1] - dm_y * (half_inner_thickness + AA_SIZE)),
                uv_white, <imgui.ImU32>color_trans  # Outer edge, transparent
            )
            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] + dm_x * (half_inner_thickness + AA_SIZE),
                             points[2*i0+1] + dm_y * (half_inner_thickness + AA_SIZE)),
                uv_white, <imgui.ImU32>color_trans  # Outer edge, transparent
            )

            idx_exterior_aa = vtx_count + 3
            idx_exterior = vtx_count + 1
            idx_interior = vtx_count
            idx_interior_aa = vtx_count + 2
            next_idx_exterior_aa = idx_exterior_aa
            next_idx_exterior = idx_exterior
            next_idx_interior = idx_interior
            next_idx_interior_aa = idx_interior_aa

            vtx_count += 4
        else:
            miter_distance = sqrt(dm_x*dm_x + dm_y*dm_y)
            # normalize normal - note miter_distance passed the previous threshold
            # and is thus non-negligleable
            dm_x *= 1./miter_distance
            dm_y *= 1./miter_distance

            # normal vector to the normal
            dn_x = -dm_y
            dn_y = dm_x

            # Clipped miter joints for angles > 90 degrees
            i1 = i0 + 1
            if i1 >= points_count:
                i1 = 0

            # orient dn towards the next point
            dx = points[2*i1] - points[2*i0]
            dy = points[2*i1+1] - points[2*i0+1]
            if fabs(dx * dn_x + dy * dn_y) < 1e-8:
                # The next point is too close, we could orient dn
                # incorrectly. Thus used the previous point.
                if i0 == 0:
                    # We are at the first point, use the last point
                    i1 = points_count - 1
                else:
                    i1 = i0 - 1
                dx = points[2*i0] - points[2*i1]
                dy = points[2*i0+1] - points[2*i1+1]
            # scalar product sign check
            if dx * dn_x + dy * dn_y < 0:
                dn_x = -dn_x
                dn_y = -dn_y

            # orient dm towards the angular part of the intersection
            # scalar product sign check
            if dx * dm_x + dy * dm_y > 0:
                dm_x = -dm_x
                dm_y = -dm_y
                normal_direction_inverted = True
            else:
                normal_direction_inverted = False

            # Angular part

            # We must find perpendicular distance and clipped miter distance
            # given the equations:
            # max_distance**2 = perpendicular_distance**2 + clipped_miter_distance**2
            # tan(theta/2) = perpendicular_distance / (miter_distance - clipped_miter_distance)
            # sin(theta/2) = (thickness / 2) / miter_distance
            # And using that max_distance = sqrt(2) * (thickness / 2)
            # We find that, with T2 = (thickness / 2):
            # clipped_miter_distance = T2 * (sqrt(1-(T2/miter_distance)**2) + T2/miter_distance)))
            # perpendicular_distance = T2 * (sqrt(1-(T2/miter_distance)**2) - T2/miter_distance)))

            sin_theta_half = 1. / miter_distance # miter_distance is already normalized by T2, and >= sqrt(2)
            if miter_distance > 99.9: # 180 degrees angle
                sin_theta_half = 0.
            cos_theta_half = sqrt(1. - sin_theta_half * sin_theta_half)
            clipped_miter_distance = half_inner_thickness * (cos_theta_half + sin_theta_half)
            perpendicular_distance = half_inner_thickness * (cos_theta_half - sin_theta_half)

            # Inner vertices (closer to center line)

            # Interior part of the intersection
            # Use a single vertex for the inner part of the intersection
            inner_distance = (<float>(1.414213562373095)) * half_inner_thickness # sqrt(2) * half_inner_thickness
            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] - dm_x * inner_distance, 
                             points[2*i0+1] - dm_y * inner_distance),
                uv_white,
                <imgui.ImU32>color  # Inner edge, full color
            )

            # Exterior part of the intersection
            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] + dm_x * clipped_miter_distance - dn_x * perpendicular_distance, 
                             points[2*i0+1] + dm_y * clipped_miter_distance - dn_y * perpendicular_distance),
                uv_white,
                <imgui.ImU32>color  # Inner edge, full color
            )

            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] + dm_x * clipped_miter_distance + dn_x * perpendicular_distance, 
                             points[2*i0+1] + dm_y * clipped_miter_distance + dn_y * perpendicular_distance),
                uv_white,
                <imgui.ImU32>color  # Inner edge, full color
            )

            # Outer vertices (with AA fringe):
            # Interior part of the intersection
            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] - dm_x * inner_distance - dm_x * AA_SIZE, 
                             points[2*i0+1] - dm_y * inner_distance - dm_y * AA_SIZE),
                uv_white,
                <imgui.ImU32>color_trans  # Outer edge, transparent
            )

            # Angular part: the points are aligned.
            # ((half_inner_thickness+1.)/half_inner_thickness) times previous ones
            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] + \
                             (half_inner_thickness+AA_SIZE) * (dm_x * (cos_theta_half + sin_theta_half) - dn_x * (cos_theta_half - sin_theta_half)),
                             points[2*i0+1] + \
                             (half_inner_thickness+AA_SIZE) * (dm_y * (cos_theta_half + sin_theta_half) - dn_y * (cos_theta_half - sin_theta_half))),
                uv_white,
                <imgui.ImU32>color_trans  # Outer edge, transparent
            )

            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] + \
                             (half_inner_thickness+AA_SIZE) * (dm_x * (cos_theta_half + sin_theta_half) + dn_x * (cos_theta_half - sin_theta_half)), 
                             points[2*i0+1] + \
                             (half_inner_thickness+AA_SIZE) * (dm_y * (cos_theta_half + sin_theta_half) + dn_y * (cos_theta_half - sin_theta_half))),
                uv_white,
                <imgui.ImU32>color_trans  # Outer edge, transparent
            )

            # Add the joint triangles
            # Interior triangle
            draw_list.PrimWriteIdx(vtx_base_idx + vtx_count)
            draw_list.PrimWriteIdx(vtx_base_idx + vtx_count + 1)
            draw_list.PrimWriteIdx(vtx_base_idx + vtx_count + 2)

            # Exterior triangles
            draw_list.PrimWriteIdx(vtx_base_idx + vtx_count + 1)
            draw_list.PrimWriteIdx(vtx_base_idx + vtx_count + 4)
            draw_list.PrimWriteIdx(vtx_base_idx + vtx_count + 5)
            draw_list.PrimWriteIdx(vtx_base_idx + vtx_count + 1)
            draw_list.PrimWriteIdx(vtx_base_idx + vtx_count + 5)
            draw_list.PrimWriteIdx(vtx_base_idx + vtx_count + 2)

            if normal_direction_inverted:
                # We inverted the direction of the normal,
                # which we need to take into account
                # for the "exterior" and "interior" vertices.
                # connection with the previous segment
                idx_exterior_aa = vtx_count + 3
                idx_exterior = vtx_count
                idx_interior = vtx_count + 1
                idx_interior_aa = vtx_count + 4
                # connection with the next segment
                next_idx_exterior_aa = vtx_count + 3
                next_idx_exterior = vtx_count
                next_idx_interior = vtx_count + 2
                next_idx_interior_aa = vtx_count + 5
            else:
                # connection with the previous segment
                idx_exterior_aa = vtx_count + 4
                idx_exterior = vtx_count + 1
                idx_interior = vtx_count
                idx_interior_aa = vtx_count + 3
                # connection with the next segment
                next_idx_exterior_aa = vtx_count + 5
                next_idx_exterior = vtx_count + 2
                next_idx_interior = vtx_count
                next_idx_interior_aa = vtx_count + 3

            # Update vertex count and index count
            vtx_count += 6
            idx_count += 9


        # Connect with the previous index
        if prev_idx_exterior_aa >= 0:
            # Inner rectangle
            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)
            draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
            draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)

            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)
            draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)
            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)

            # Upper AA fringe
            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior_aa)
            draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior_aa)
            draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
            
            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior_aa)
            draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)

            # Lower AA fringe
            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)
            draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)
            draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)

            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)
            draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)
            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior_aa)

            # Update index count
            idx_count += 18
        else:
            # Closed polygon. Remember what to connect to
            zero_idx_exterior_aa = idx_exterior_aa
            zero_idx_exterior = idx_exterior
            zero_idx_interior = idx_interior
            zero_idx_interior_aa = idx_interior_aa

        # Prepare next segment
        prev_idx_exterior_aa = next_idx_exterior_aa
        prev_idx_exterior = next_idx_exterior
        prev_idx_interior = next_idx_interior
        prev_idx_interior_aa = next_idx_interior_aa

    # CAP
    if not closed:
        # We use a rectangular cap for open lines
        # The cap is such that it gives the same visual
        # result as a 180 degree joint angle.
        # The cap is a rectangle of size thickness x thickness,
        # with the center at the end of the line.
        # The rectangle is aligned with the line.

        dm_x = normals[(points_count-1)*2] # NOTE: for extremities the normals are normalized.
        dm_y = normals[(points_count-1)*2+1]

        # Retrieve the normalized direction
        dn_x = -dm_y
        dn_y = dm_x

        # orient dn away from the previous point
        dx = points[2*(points_count-1)] - points[2*(points_count-2)]
        dy = points[2*(points_count-1)+1] - points[2*(points_count-2)+1]
        # scalar product sign check
        if dx * dn_x + dy * dn_y < 0:
            dn_x = -dn_x
            dn_y = -dn_y

        # Inner vertices (closer to center line)
        i0 = points_count-1
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] - dm_x * half_inner_thickness + dn_x * half_inner_thickness, 
                         points[2*i0+1] - dm_y * half_inner_thickness + dn_y * half_inner_thickness),
            uv_white, <imgui.ImU32>color  # Inner edge, full color
        )
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] + dm_x * half_inner_thickness + dn_x * half_inner_thickness, 
                         points[2*i0+1] + dm_y * half_inner_thickness + dn_y * half_inner_thickness),
            uv_white, <imgui.ImU32>color  # Inner edge, full color
        )

        # Outer vertices (with AA fringe)
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] - dm_x * (half_inner_thickness + AA_SIZE) + dn_x * (half_inner_thickness + AA_SIZE),
                         points[2*i0+1] - dm_y * (half_inner_thickness + AA_SIZE) + dn_y * (half_inner_thickness + AA_SIZE)),
            uv_white, <imgui.ImU32>color_trans  # Outer edge, transparent
        )
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] + dm_x * (half_inner_thickness + AA_SIZE) + dn_x * (half_inner_thickness + AA_SIZE),
                         points[2*i0+1] + dm_y * (half_inner_thickness + AA_SIZE) + dn_y * (half_inner_thickness + AA_SIZE)),
            uv_white, <imgui.ImU32>color_trans  # Outer edge, transparent
        )

        idx_exterior_aa = vtx_count + 3
        idx_exterior = vtx_count + 1
        idx_interior = vtx_count
        idx_interior_aa = vtx_count + 2

        # Connect with the previous index
        assert prev_idx_exterior_aa >= 0
        # Inner rectangle
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)

        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)

        # Upper AA fringe
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)

        # Lower AA fringe
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)

        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior_aa)

        # Add the cap
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)

        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)

        # Update vertex and index count
        vtx_count += 4
        idx_count += 24

    else:
        # Closed polygon. Connect the last segment to the first
        if points_count > 2:
            # Inner rectangle
            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)
            draw_list.PrimWriteIdx(vtx_base_idx + zero_idx_exterior)
            draw_list.PrimWriteIdx(vtx_base_idx + zero_idx_interior)

            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)
            draw_list.PrimWriteIdx(vtx_base_idx + zero_idx_interior)
            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)

            # Upper AA fringe
            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior_aa)
            draw_list.PrimWriteIdx(vtx_base_idx + zero_idx_exterior_aa)
            draw_list.PrimWriteIdx(vtx_base_idx + zero_idx_exterior)

            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior_aa)
            draw_list.PrimWriteIdx(vtx_base_idx + zero_idx_exterior)
            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)

            # Lower AA fringe
            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)
            draw_list.PrimWriteIdx(vtx_base_idx + zero_idx_interior)
            draw_list.PrimWriteIdx(vtx_base_idx + zero_idx_interior_aa)

            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)
            draw_list.PrimWriteIdx(vtx_base_idx + zero_idx_interior_aa)
            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior_aa)
            # Update index count
            idx_count += 18

    # Finalize the draw list
    assert vtx_count <= max_vtx_count
    assert idx_count <= max_idx_count

    draw_list.PrimUnreserve(max_idx_count - idx_count, max_vtx_count - vtx_count)



cdef inline imgui.ImVec2 _uv(float u, float v) noexcept nogil:
    """
    Build an UV pair.
    
    Args:
        u: U coordinate
        v: V coordinate
    
    Returns:
        imgui.ImVec2 containing the U and V coordinates
    """
    return imgui.ImVec2(u, v)

cdef void _t_draw_polygon_outline_pattern(Context context,
                                          void* drawlist_ptr,
                                          const float* points,
                                          int points_count,
                                          const float* normals,
                                          Pattern pattern,
                                          uint32_t color,
                                          float thickness,
                                          bint closed) noexcept nogil:
    """
    t_draw_polygon_outline with a pattern

    pattern strategy at corners:
    - interior point AA is the reference at which u should be worth
        the value given by _get_point_uv for the point
    - For both segments, we project this point on them (though forcing
        that the point is falling inside the segment)
    - The projections produce (with segment normal) two inner points and one exterior AA point
    - Previous segment connect to these points
    - We keep all the other vertices of the outline_thick implementation. All them
       will have the same u (of _get_point_uv).
    => This strategy ensures that the pattern is rightfully perpendicular to the outline
    - thickness <= AA_SIZE: rather than implementing a outline_thin path, we merge both
        by using half_inner_thickness and generating all vertices as in the thick path (thus
        there will be empty triangles and redundant vertices).
    - non closed outline: For the rectangular cap, we use the same strategy as in the
        outline_thick path. However due to the above strategy, unlike for outline_thick,
        the visual result is not the same as a 180 degree joint angle.

    The code is not as optimized as it could be, and there are some duplicated
    computations.
    """
    cdef imgui.ImDrawList* draw_list = <imgui.ImDrawList*>drawlist_ptr
    cdef imgui.ImU32 color_trans = color & ~imgui.IM_COL32_A_MASK
    cdef float AA_SIZE = draw_list._FringeScale

    if points_count < 2:
        return
    
    cdef unsigned int vtx_base_idx = draw_list._VtxCurrentIdx
    cdef float half_inner_thickness = (thickness - AA_SIZE) * 0.5
    # Apply alpha scaling for thickness < AA_SIZE
    cdef uint32_t alpha
    cdef float alpha_scale
    if thickness < AA_SIZE:
        # Extract current alpha value
        alpha = (color >> 24) & 0xFF
            
        # Apply power function with exponent 0.7 (smoother transition than linear)
        # This keeps thin lines more visible while still fading appropriately
        alpha_scale = pow(fmax(thickness/AA_SIZE, 0.), 0.7)
            
        # Modify alpha channel while preserving RGB
        alpha = <uint32_t>(alpha * alpha_scale)
        if alpha == 0:
            # Nothing to draw
            return
        color = (color & 0x00FFFFFF) | (alpha << 24)
        half_inner_thickness = 0.

    # Reserve space for vertices and indices (worst case)
    cdef int max_vtx_count = points_count * 20
    cdef int max_idx_count = points_count * 60

    draw_list.PushTextureID(<imgui.ImTextureID>pattern._texture.allocated_texture)

    draw_list.PrimReserve(max_idx_count, max_vtx_count)

    cdef int i0, i1, i_next, i_prev
    cdef float u, v
    cdef float dm_x, dm_y # miter direction + length
    cdef float dn0_x, dn0_y # with previous segment
    cdef float dn1_x, dn1_y # with next segment
    cdef float dm_x_proj, dm_y_proj
    cdef float aa_interior
    cdef float d_len_sq
    cdef float dx0, dy0, dx1, dy1, d_len0, d_len1
    cdef float dx, dy, dn_x, dn_y
    cdef bint normal_direction_inverted
    
    cdef float miter_distance, clipped_miter_distance, perpendicular_distance
    cdef float sin_theta_half, cos_theta_half
    cdef float inner_distance, inner_distance_factor

    cdef double length = 0.# accumulated length

    cdef int vtx_count = 0
    cdef int idx_count = 0
    cdef int idx_exterior_aa, idx_interior_aa
    cdef int idx_exterior, idx_interior

    # key vertices for the next vertex to connect to
    cdef int next_idx_exterior_aa, next_idx_interior_aa
    cdef int next_idx_exterior, next_idx_interior

    # key vertices of the previous vertex to connect to
    cdef int prev_idx_exterior_aa = -1
    cdef int prev_idx_exterior = -1
    cdef int prev_idx_interior = -1
    cdef int prev_idx_interior_aa = -1

    # key vertices for the first vertex when not closed
    cdef imgui.ImVec2 zero_vtx_exterior_aa = imgui.ImVec2(0., 0.)
    cdef imgui.ImVec2 zero_vtx_exterior = imgui.ImVec2(0., 0.)
    cdef imgui.ImVec2 zero_vtx_interior = imgui.ImVec2(0., 0.)
    cdef imgui.ImVec2 zero_vtx_interior_aa = imgui.ImVec2(0., 0.)

    # exterior: where the normal points to
    # interior: the other direction
    # inner: the thick part of the outline
    # outer: the AA part of the outline

    # CAP
    if not closed:
        # We use a rectangular cap for open lines
        # The cap is such that it gives the same visual
        # result as a 180 degree joint angle.
        # The cap is a rectangle of size thickness x thickness,
        # with the center at the end of the line.
        # The rectangle is aligned with the line.

        dm_x = normals[0] # NOTE: for extremities the normals are normalized.
        dm_y = normals[1]

        # Retrieve the normalized direction
        dn_x = -dm_y
        dn_y = dm_x

        # orient dn away from the next point
        dx = points[2*1] - points[0]
        dy = points[2*1+1] - points[0+1]
        # scalar product sign check
        if dx * dn_x + dy * dn_y > 0:
            dn_x = -dn_x
            dn_y = -dn_y

        u = get_pattern_u(context, pattern, 0, 0.)

        # Inner vertices (closer to center line)
        i0 = 0
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] - dm_x * half_inner_thickness + dn_x * half_inner_thickness, 
                         points[2*i0+1] - dm_y * half_inner_thickness + dn_y * half_inner_thickness),
            _uv(u, 0.), <imgui.ImU32>color  # Inner edge, full color
        )
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] + dm_x * half_inner_thickness + dn_x * half_inner_thickness, 
                         points[2*i0+1] + dm_y * half_inner_thickness + dn_y * half_inner_thickness),
            _uv(u, 1.), <imgui.ImU32>color  # Inner edge, full color
        )

        # Outer vertices (with AA fringe)
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] - dm_x * (half_inner_thickness + AA_SIZE) + dn_x * (half_inner_thickness + AA_SIZE),
                         points[2*i0+1] - dm_y * (half_inner_thickness + AA_SIZE) + dn_y * (half_inner_thickness + AA_SIZE)),
            _uv(u, 0.), <imgui.ImU32>color_trans  # Outer edge, transparent
        )
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] + dm_x * (half_inner_thickness + AA_SIZE) + dn_x * (half_inner_thickness + AA_SIZE),
                         points[2*i0+1] + dm_y * (half_inner_thickness + AA_SIZE) + dn_y * (half_inner_thickness + AA_SIZE)),
            _uv(u, 1.), <imgui.ImU32>color_trans  # Outer edge, transparent
        )

        idx_exterior_aa = 3
        idx_exterior = 1
        idx_interior = 0
        idx_interior_aa = 2

        # two triangles at the end of the cap
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)

        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)

        vtx_count += 4
        idx_count += 6

        prev_idx_exterior_aa = idx_exterior_aa
        prev_idx_exterior = idx_exterior
        prev_idx_interior = idx_interior
        prev_idx_interior_aa = idx_interior_aa

        # Connect with perpendicular section

        # perpendicular section at the point
        # Inner vertices (closer to center line)
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] - dm_x * half_inner_thickness,
                         points[2*i0+1] - dm_y * half_inner_thickness),
            _uv(u, 0.), <imgui.ImU32>color  # Inner edge, full color
        )
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] + dm_x * half_inner_thickness,
                         points[2*i0+1] + dm_y * half_inner_thickness),
            _uv(u, 1.), <imgui.ImU32>color  # Inner edge, full color
        )

        # Outer vertices (with AA fringe)
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] - dm_x * (half_inner_thickness + AA_SIZE),
                         points[2*i0+1] - dm_y * (half_inner_thickness + AA_SIZE)),
            _uv(u, 0.), <imgui.ImU32>color_trans  # Outer edge, transparent
        )
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] + dm_x * (half_inner_thickness + AA_SIZE),
                         points[2*i0+1] + dm_y * (half_inner_thickness + AA_SIZE)),
            _uv(u, 1.), <imgui.ImU32>color_trans  # Outer edge, transparent
        )
        idx_exterior_aa = vtx_count + 3
        idx_exterior = vtx_count + 1
        idx_interior = vtx_count + 0
        idx_interior_aa = vtx_count + 2

        # connecting the cap and the perpendicular section
        # exterior rectangle
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)
        # inner rectangle
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)
        # interior rectangle
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior_aa)

        vtx_count += 4
        idx_count += 18

        prev_idx_exterior_aa = idx_exterior_aa
        prev_idx_exterior = idx_exterior
        prev_idx_interior = idx_interior
        prev_idx_interior_aa = idx_interior_aa


    for i0 in range(0 if closed else 1, points_count if closed else (points_count-1)):
        i_prev = i0 - 1
        if i0 == 0:
            i_prev = (points_count - 1) if closed else 0
        i_next = i0 + 1
        if i_next >= points_count:
            i_next = 0

        if i0 > 0:
            length += sqrt((points[2*i0] - points[2*i_prev])**2 + (points[2*i0+1] - points[2*i_prev+1])**2)

        u = get_pattern_u(context, pattern, i0, length)

        # Get normalized vector pointing to previous point
        dx0 = points[2*i_prev] - points[2*i0]
        dy0 = points[2*i_prev+1] - points[2*i0+1]
        d_len0 = dx0*dx0 + dy0*dy0
        
        if d_len0 > 1e-3:
            d_len0 = 1.0 / sqrt(d_len0)
            dn0_x = dx0 * d_len0
            dn0_y = dy0 * d_len0
        else:
            dn0_x = 0.
            dn0_y = 0.

        dm_x = normals[2*i0]
        dm_y = normals[2*i0+1]
        d_len_sq = dm_x * dm_x + dm_y * dm_y
        #d_len = sqrt(d_len_sq)

        # inner_distance: distance of the reference point to the inner point
        # inner_distance_factor: factor to apply to the minus normal to get the inner point
        #if d_len < <float>(1.414213562373095):
        #    inner_distance = d_len * half_inner_thickness
        #    inner_distance_factor = half_inner_thickness
        #else:
        #    inner_distance = <float>(1.414213562373095) * half_inner_thickness
        #    inner_distance_factor = <float>(1.414213562373095) / d_len * half_inner_thickness

        # project the inner point on the left segment
        # dm_x_proj: projection on the normalized vector pointing to the previous point
        dm_x_proj = (dm_x * dn0_x + dm_y * dn0_y) * half_inner_thickness# * inner_distance_factor
        # dm_y_proj: projection on orthogonal to the normalized vector pointing to the previous point
        dm_y_proj = (dm_x * dn0_y - dm_y * dn0_x) * half_inner_thickness# * inner_distance_factor

        if dm_x_proj < 0:
            # dm_x/y points to the exterior of the polygon,
            # which can be the interior or the exterior of the joint.
            dm_x_proj = -dm_x_proj
        dm_y_proj = -dm_y_proj # make dm_y_proj point to the interior of the polygon

        # Do not go further than the previous point
        dm_x_proj = fmin(dx0 * dn0_x + dy0 * dn0_y, dm_x_proj)

        # First perpendicular section: 4 points
        # Inner vertices (closer to center line)
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] + dm_x_proj * dn0_x + dm_y_proj * dn0_y,
                         points[2*i0+1] + dm_x_proj * dn0_y - dm_y_proj * dn0_x),
            _uv(u, 0.), <imgui.ImU32>color  # Inner edge, full color
        )
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] + dm_x_proj * dn0_x - dm_y_proj * dn0_y,
                         points[2*i0+1] + dm_x_proj * dn0_y + dm_y_proj * dn0_x),
            _uv(u, 1.), <imgui.ImU32>color  # Inner edge, full color
        )
        aa_interior = AA_SIZE
        if dm_y_proj < 0:
            aa_interior = -aa_interior
        # Outer vertices (with AA fringe)
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] + dm_x_proj * dn0_x + (dm_y_proj + aa_interior) * dn0_y,
                         points[2*i0+1] + dm_x_proj * dn0_y - (dm_y_proj + aa_interior) * dn0_x),
            _uv(u, 0.), <imgui.ImU32>color_trans  # Outer edge, transparent
        )
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] + dm_x_proj * dn0_x - (dm_y_proj + aa_interior) * dn0_y,
                         points[2*i0+1] + dm_x_proj * dn0_y + (dm_y_proj + aa_interior) * dn0_x),
            _uv(u, 1.), <imgui.ImU32>color_trans  # Outer edge, transparent
        )

        idx_exterior_aa = vtx_count + 3
        idx_exterior = vtx_count + 1
        idx_interior = vtx_count
        idx_interior_aa = vtx_count + 2
        vtx_count += 4

        # Connect the triangulation with the previous point
        if prev_idx_exterior_aa >= 0:
            # Inner rectangle
            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)
            draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
            draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)

            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)
            draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)
            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)

            # Upper AA fringe
            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior_aa)
            draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior_aa)
            draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
            
            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior_aa)
            draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)

            # Lower AA fringe
            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)
            draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)
            draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)

            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)
            draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)
            draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior_aa)

            # Update index count
            idx_count += 18
        else:
            # Closed polygon. Remember what to connect to
            zero_vtx_exterior_aa = \
                imgui.ImVec2(points[2*i0] + dm_x_proj * dn0_x - (dm_y_proj + aa_interior) * dn0_y,
                             points[2*i0+1] + dm_x_proj * dn0_y + (dm_y_proj + aa_interior) * dn0_x)
            zero_vtx_exterior = \
                imgui.ImVec2(points[2*i0] + dm_x_proj * dn0_x - dm_y_proj * dn0_y,
                             points[2*i0+1] + dm_x_proj * dn0_y + dm_y_proj * dn0_x)
            zero_vtx_interior = \
                imgui.ImVec2(points[2*i0] + dm_x_proj * dn0_x + dm_y_proj * dn0_y,
                             points[2*i0+1] + dm_x_proj * dn0_y - dm_y_proj * dn0_x)
            zero_vtx_interior_aa = \
                imgui.ImVec2(points[2*i0] + dm_x_proj * dn0_x + (dm_y_proj + aa_interior) * dn0_y,
                             points[2*i0+1] + dm_x_proj * dn0_y - (dm_y_proj + aa_interior) * dn0_x)

        # Replace the previous index with the current ones
        prev_idx_exterior_aa = idx_exterior_aa
        prev_idx_exterior = idx_exterior
        prev_idx_interior = idx_interior
        prev_idx_interior_aa = idx_interior_aa

        # This section below is the same as the outline_thick path

        if d_len_sq <= 2.01: # sqrt(2) distance with rounding margin
            # Use miter joints for angles <= 90 degrees

            # Calculate vertex positions for thick line with AA fringe
            # Inner vertices (closer to center line)
            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] - dm_x * half_inner_thickness, 
                             points[2*i0+1] - dm_y * half_inner_thickness),
                _uv(u, 0.), <imgui.ImU32>color  # Inner edge, full color
            )
            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] + dm_x * half_inner_thickness, 
                             points[2*i0+1] + dm_y * half_inner_thickness),
                _uv(u, 1.), <imgui.ImU32>color  # Inner edge, full color
            )
            
            # Outer vertices (with AA fringe)
            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] - dm_x * (half_inner_thickness + AA_SIZE),
                             points[2*i0+1] - dm_y * (half_inner_thickness + AA_SIZE)),
                 _uv(u, 0.), <imgui.ImU32>color_trans  # Outer edge, transparent
            )
            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] + dm_x * (half_inner_thickness + AA_SIZE),
                             points[2*i0+1] + dm_y * (half_inner_thickness + AA_SIZE)),
                 _uv(u, 1.), <imgui.ImU32>color_trans  # Outer edge, transparent
            )

            idx_exterior_aa = vtx_count + 3
            idx_exterior = vtx_count + 1
            idx_interior = vtx_count
            idx_interior_aa = vtx_count + 2
            next_idx_exterior_aa = idx_exterior_aa
            next_idx_exterior = idx_exterior
            next_idx_interior = idx_interior
            next_idx_interior_aa = idx_interior_aa

            vtx_count += 4
        else:
            miter_distance = sqrt(dm_x*dm_x + dm_y*dm_y)
            # normalize normal - note miter_distance passed the previous threshold
            # and is thus non-negligleable
            dm_x *= 1./miter_distance
            dm_y *= 1./miter_distance

            # normal vector to the normal
            dn_x = -dm_y
            dn_y = dm_x

            # Clipped miter joints for angles > 90 degrees

            # orient dn towards the next point
            i1 = i_next
            dx = points[2*i1] - points[2*i0]
            dy = points[2*i1+1] - points[2*i0+1]
            if fabs(dx * dn_x + dy * dn_y) < 1e-8:
                # The next point is too close, we could orient dn
                # incorrectly. Thus used the previous point.
                if i0 == 0:
                    # We are at the first point, use the last point
                    i1 = points_count - 1
                else:
                    i1 = i0 - 1
                dx = points[2*i0] - points[2*i1]
                dy = points[2*i0+1] - points[2*i1+1]
            # scalar product sign check
            if dx * dn_x + dy * dn_y < 0:
                dn_x = -dn_x
                dn_y = -dn_y

            # orient dm towards the angular part of the intersection
            # scalar product sign check
            if dx * dm_x + dy * dm_y > 0:
                dm_x = -dm_x
                dm_y = -dm_y
                normal_direction_inverted = True
            else:
                normal_direction_inverted = False

            # Angular part

            # We must find perpendicular distance and clipped miter distance
            # given the equations:
            # max_distance**2 = perpendicular_distance**2 + clipped_miter_distance**2
            # tan(theta/2) = perpendicular_distance / (miter_distance - clipped_miter_distance)
            # sin(theta/2) = (thickness / 2) / miter_distance
            # And using that max_distance = sqrt(2) * (thickness / 2)
            # We find that, with T2 = (thickness / 2):
            # clipped_miter_distance = T2 * (sqrt(1-(T2/miter_distance)**2) + T2/miter_distance)))
            # perpendicular_distance = T2 * (sqrt(1-(T2/miter_distance)**2) - T2/miter_distance)))

            sin_theta_half = 1. / miter_distance # miter_distance is already normalized by T2, and >= sqrt(2)
            if miter_distance > 99.9: # 180 degrees angle
                sin_theta_half = 0.
            cos_theta_half = sqrt(1. - sin_theta_half * sin_theta_half)
            clipped_miter_distance = half_inner_thickness * (cos_theta_half + sin_theta_half)
            perpendicular_distance = half_inner_thickness * (cos_theta_half - sin_theta_half)

            # Inner vertices (closer to center line)

            # Interior part of the intersection
            # Use a single vertex for the inner part of the intersection
            inner_distance = (<float>(1.414213562373095)) * half_inner_thickness # sqrt(2) * half_inner_thickness
            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] - dm_x * inner_distance, 
                             points[2*i0+1] - dm_y * inner_distance),
                _uv(u, 1. if normal_direction_inverted else 0.),
                <imgui.ImU32>color  # Inner edge, full color
            )

            # Exterior part of the intersection
            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] + dm_x * clipped_miter_distance - dn_x * perpendicular_distance, 
                             points[2*i0+1] + dm_y * clipped_miter_distance - dn_y * perpendicular_distance),
                _uv(u, 0. if normal_direction_inverted else 1.),
                <imgui.ImU32>color  # Inner edge, full color
            )

            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] + dm_x * clipped_miter_distance + dn_x * perpendicular_distance, 
                             points[2*i0+1] + dm_y * clipped_miter_distance + dn_y * perpendicular_distance),
                _uv(u, 0. if normal_direction_inverted else 1.),
                <imgui.ImU32>color  # Inner edge, full color
            )

            # Outer vertices (with AA fringe):
            # Interior part of the intersection
            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] - dm_x * inner_distance - dm_x * AA_SIZE, 
                             points[2*i0+1] - dm_y * inner_distance - dm_y * AA_SIZE),
                _uv(u, 1. if normal_direction_inverted else 0.),
                <imgui.ImU32>color_trans  # Outer edge, transparent
            )

            # Angular part: the points are aligned.
            # ((half_inner_thickness+1.)/half_inner_thickness) times previous ones
            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] + \
                             (half_inner_thickness+AA_SIZE) * (dm_x * (cos_theta_half + sin_theta_half) - dn_x * (cos_theta_half - sin_theta_half)),
                             points[2*i0+1] + \
                             (half_inner_thickness+AA_SIZE) * (dm_y * (cos_theta_half + sin_theta_half) - dn_y * (cos_theta_half - sin_theta_half))),
                _uv(u, 0. if normal_direction_inverted else 1.),
                <imgui.ImU32>color_trans  # Outer edge, transparent
            )

            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] + \
                             (half_inner_thickness+AA_SIZE) * (dm_x * (cos_theta_half + sin_theta_half) + dn_x * (cos_theta_half - sin_theta_half)), 
                             points[2*i0+1] + \
                             (half_inner_thickness+AA_SIZE) * (dm_y * (cos_theta_half + sin_theta_half) + dn_y * (cos_theta_half - sin_theta_half))),
                _uv(u, 0. if normal_direction_inverted else 1.),
                <imgui.ImU32>color_trans  # Outer edge, transparent
            )

            # Add the joint triangles
            # Interior triangle
            draw_list.PrimWriteIdx(vtx_base_idx + vtx_count)
            draw_list.PrimWriteIdx(vtx_base_idx + vtx_count + 1)
            draw_list.PrimWriteIdx(vtx_base_idx + vtx_count + 2)

            # Exterior triangles
            draw_list.PrimWriteIdx(vtx_base_idx + vtx_count + 1)
            draw_list.PrimWriteIdx(vtx_base_idx + vtx_count + 4)
            draw_list.PrimWriteIdx(vtx_base_idx + vtx_count + 5)
            draw_list.PrimWriteIdx(vtx_base_idx + vtx_count + 1)
            draw_list.PrimWriteIdx(vtx_base_idx + vtx_count + 5)
            draw_list.PrimWriteIdx(vtx_base_idx + vtx_count + 2)

            if normal_direction_inverted:
                # We inverted the direction of the normal,
                # which we need to take into account
                # for the "exterior" and "interior" vertices.
                # connection with the previous segment
                idx_exterior_aa = vtx_count + 3
                idx_exterior = vtx_count
                idx_interior = vtx_count + 1
                idx_interior_aa = vtx_count + 4
                # connection with the next segment
                next_idx_exterior_aa = vtx_count + 3
                next_idx_exterior = vtx_count
                next_idx_interior = vtx_count + 2
                next_idx_interior_aa = vtx_count + 5
            else:
                # connection with the previous segment
                idx_exterior_aa = vtx_count + 4
                idx_exterior = vtx_count + 1
                idx_interior = vtx_count
                idx_interior_aa = vtx_count + 3
                # connection with the next segment
                next_idx_exterior_aa = vtx_count + 5
                next_idx_exterior = vtx_count + 2
                next_idx_interior = vtx_count
                next_idx_interior_aa = vtx_count + 3

            # Update vertex count and index count
            vtx_count += 6
            idx_count += 9


        # Connect with the first perpendicular section
        # Inner rectangle
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)

        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)

        # Upper AA fringe
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)

        # Lower AA fringe
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)

        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior_aa)

        # Update index count
        idx_count += 18

        # Prepare next segment
        prev_idx_exterior_aa = next_idx_exterior_aa
        prev_idx_exterior = next_idx_exterior
        prev_idx_interior = next_idx_interior
        prev_idx_interior_aa = next_idx_interior_aa

        # End of the outline_thick path

        # Now similarly to the connection with the previous index,
        # we make a perpendicular section.

        # Get normalized vector pointing to next point
        dx1 = points[2*i_next] - points[2*i0]
        dy1 = points[2*i_next+1] - points[2*i0+1]
        d_len1 = dx1*dx1 + dy1*dy1

        if d_len1 > 1e-3:
            d_len1 = 1.0 / sqrt(d_len1)
            dn1_x = dx1 * d_len1
            dn1_y = dy1 * d_len1
        else:
            dn1_x = 0.
            dn1_y = 0.

        dm_x = normals[2*i0]
        dm_y = normals[2*i0+1]

        # dm_x_proj: projection on the normalized vector pointing to the next point
        dm_x_proj = (dm_x * dn1_x + dm_y * dn1_y) * half_inner_thickness# * inner_distance_factor
        # dm_y_proj: projection on orthogonal to the normalized vector pointing to the next point
        dm_y_proj = (dm_x * dn1_y - dm_y * dn1_x) * half_inner_thickness# * inner_distance_factor

        if dm_x_proj < 0:
            # dm_x/y points to the exterior of the polygon,
            # which can be the interior or the exterior of the joint.
            dm_x_proj = -dm_x_proj
        dm_y_proj = -dm_y_proj # make dm_y_proj point to the interior of the polygon

        # Do not go further than the next point
        dm_x_proj = fmin(dx1 * dn1_x + dy1 * dn1_y, dm_x_proj)

        # Second perpendicular section: 4 points
        # Inner vertices (closer to center line)
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] + dm_x_proj * dn1_x + dm_y_proj * dn1_y,
                         points[2*i0+1] + dm_x_proj * dn1_y - dm_y_proj * dn1_x),
            _uv(u, 0.), <imgui.ImU32>color  # Inner edge, full color
        )
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] + dm_x_proj * dn1_x - dm_y_proj * dn1_y,
                         points[2*i0+1] + dm_x_proj * dn1_y + dm_y_proj * dn1_x),
            _uv(u, 1.), <imgui.ImU32>color  # Inner edge, full color
        )
        aa_interior = AA_SIZE
        if dm_y_proj < 0:
            aa_interior = -aa_interior
        # Outer vertices (with AA fringe)
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] + dm_x_proj * dn1_x + (dm_y_proj + aa_interior) * dn1_y,
                         points[2*i0+1] + dm_x_proj * dn1_y - (dm_y_proj + aa_interior) * dn1_x),
            _uv(u, 0.), <imgui.ImU32>color_trans  # Outer edge, transparent
        )
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] + dm_x_proj * dn1_x - (dm_y_proj + aa_interior) * dn1_y,
                         points[2*i0+1] + dm_x_proj * dn1_y + (dm_y_proj + aa_interior) * dn1_x),
            _uv(u, 1.), <imgui.ImU32>color_trans  # Outer edge, transparent
        )

        idx_exterior_aa = vtx_count + 3
        idx_exterior = vtx_count + 1
        idx_interior = vtx_count
        idx_interior_aa = vtx_count + 2
        vtx_count += 4

        # Connect the triangulation with the current point
        # Inner rectangle
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)

        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)

        # Upper AA fringe
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)

        # Lower AA fringe
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)

        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior_aa)

        # Update index count
        idx_count += 18

        # Replace the previous indices with the current ones
        prev_idx_exterior_aa = idx_exterior_aa
        prev_idx_exterior = idx_exterior
        prev_idx_interior = idx_interior
        prev_idx_interior_aa = idx_interior_aa

    # CAP
    if not closed:
        # We use a rectangular cap for open lines
        # The cap is such that it gives the same visual
        # result as a 180 degree joint angle.
        # The cap is a rectangle of size thickness x thickness,
        # with the center at the end of the line.
        # The rectangle is aligned with the line.

        dm_x = normals[(points_count-1)*2] # NOTE: for extremities the normals are normalized.
        dm_y = normals[(points_count-1)*2+1]

        # Retrieve the normalized direction
        dn_x = -dm_y
        dn_y = dm_x

        # orient dn away from the previous point
        dx = points[2*(points_count-1)] - points[2*(points_count-2)]
        dy = points[2*(points_count-1)+1] - points[2*(points_count-2)+1]
        # scalar product sign check
        if dx * dn_x + dy * dn_y < 0:
            dn_x = -dn_x
            dn_y = -dn_y

        # Inner vertices (closer to center line)
        i0 = points_count-1
        i_prev = points_count-2
        length += sqrt((points[2*i0] - points[2*i_prev])**2 + (points[2*i0+1] - points[2*i_prev+1])**2)
        
        u = get_pattern_u(context, pattern, i0, length)

        # perpendicular section at the point
        # Inner vertices (closer to center line)
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] - dm_x * half_inner_thickness,
                        points[2*i0+1] - dm_y * half_inner_thickness),
            _uv(u, 0.), <imgui.ImU32>color  # Inner edge, full color
        )
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] + dm_x * half_inner_thickness,
                        points[2*i0+1] + dm_y * half_inner_thickness),
            _uv(u, 1.), <imgui.ImU32>color  # Inner edge, full color
        )

        # Outer vertices (with AA fringe)
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] - dm_x * (half_inner_thickness + AA_SIZE),
                        points[2*i0+1] - dm_y * (half_inner_thickness + AA_SIZE)),
            _uv(u, 0.), <imgui.ImU32>color_trans  # Outer edge, transparent
        )
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] + dm_x * (half_inner_thickness + AA_SIZE),
                        points[2*i0+1] + dm_y * (half_inner_thickness + AA_SIZE)),
            _uv(u, 1.), <imgui.ImU32>color_trans  # Outer edge, transparent
        )

        # Connect with the previous index
        idx_exterior_aa = vtx_count + 3
        idx_exterior = vtx_count + 1
        idx_interior = vtx_count
        idx_interior_aa = vtx_count + 2
        vtx_count += 4
        # Inner rectangle
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)

        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)

        # Upper AA fringe
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)

        # Lower AA fringe
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)

        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior_aa)
        # Update index count
        idx_count += 18
        # Replace the previous indices with the current ones
        prev_idx_exterior_aa = idx_exterior_aa
        prev_idx_exterior = idx_exterior
        prev_idx_interior = idx_interior
        prev_idx_interior_aa = idx_interior_aa

        # Now we need to add the cap
        # Rectangular cap vertices
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] - dm_x * half_inner_thickness + dn_x * half_inner_thickness, 
                        points[2*i0+1] - dm_y * half_inner_thickness + dn_y * half_inner_thickness),
            _uv(u, 0.), <imgui.ImU32>color  # Inner edge, full color
        )
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] + dm_x * half_inner_thickness + dn_x * half_inner_thickness, 
                        points[2*i0+1] + dm_y * half_inner_thickness + dn_y * half_inner_thickness),
            _uv(u, 1.), <imgui.ImU32>color  # Inner edge, full color
        )

        # Outer vertices (with AA fringe)
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] - dm_x * (half_inner_thickness + AA_SIZE) + dn_x * (half_inner_thickness + AA_SIZE),
                        points[2*i0+1] - dm_y * (half_inner_thickness + AA_SIZE) + dn_y * (half_inner_thickness + AA_SIZE)),
            _uv(u, 0.), <imgui.ImU32>color_trans  # Outer edge, transparent
        )
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] + dm_x * (half_inner_thickness + AA_SIZE) + dn_x * (half_inner_thickness + AA_SIZE),
                        points[2*i0+1] + dm_y * (half_inner_thickness + AA_SIZE) + dn_y * (half_inner_thickness + AA_SIZE)),
            _uv(u, 1.), <imgui.ImU32>color_trans  # Outer edge, transparent
        )

        idx_exterior_aa = vtx_count + 3
        idx_exterior = vtx_count + 1
        idx_interior = vtx_count
        idx_interior_aa = vtx_count + 2

        # Connect with the previous indices
        assert prev_idx_exterior_aa >= 0
        # Inner rectangle
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)

        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)

        # Upper AA fringe
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)

        # Lower AA fringe
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)

        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior_aa)

        # Add the cap
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)

        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)

        # Update vertex and index count
        vtx_count += 4
        idx_count += 24

    elif points_count > 2:
        # Closed polygon. Connect the last segment to the first
        # However as the u coordinate is not the same, we need to
        # Create new vertices for the last segment
        i0 = points_count-1

        # Update length
        length += sqrt((points[2*i0] - points[0])**2 + (points[2*i0+1] - points[1])**2)
        # Retrieve u at the end of the segment
        u = get_pattern_u(context, pattern, points_count, length)

        # Generate duplication of the connection vertices
        draw_list.PrimWriteVtx(
            zero_vtx_interior,
            _uv(u, 0.), <imgui.ImU32>color  # Inner edge, full color
        )
        draw_list.PrimWriteVtx(
            zero_vtx_exterior,
            _uv(u, 1.), <imgui.ImU32>color  # Inner edge, full color
        )
        draw_list.PrimWriteVtx(
            zero_vtx_interior_aa,
            _uv(u, 0.), <imgui.ImU32>color_trans  # Outer edge, transparent
        )
        draw_list.PrimWriteVtx(
            zero_vtx_exterior_aa,
            _uv(u, 1.), <imgui.ImU32>color_trans  # Outer edge, transparent
        )

        idx_exterior_aa = vtx_count + 3
        idx_exterior = vtx_count + 1
        idx_interior = vtx_count
        idx_interior_aa = vtx_count + 2

        vtx_count += 4

        # Inner rectangle
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)

        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)

        # Upper AA fringe
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)

        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_exterior)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_exterior)

        # Lower AA fringe
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)

        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior)
        draw_list.PrimWriteIdx(vtx_base_idx + idx_interior_aa)
        draw_list.PrimWriteIdx(vtx_base_idx + prev_idx_interior_aa)

        # Update index count
        idx_count += 18

    # Finalize the draw list
    assert vtx_count <= max_vtx_count
    assert idx_count <= max_idx_count

    draw_list.PrimUnreserve(max_idx_count - idx_count, max_vtx_count - vtx_count)
    draw_list.PopTextureID()


cdef void t_draw_polygon_outline(Context context,
                                 void* drawlist_ptr,
                                 const float* points,
                                 int points_count,
                                 const float* normals,
                                 Pattern pattern,
                                 uint32_t color,
                                 float thickness,
                                 bint closed) noexcept nogil:
    """
    Draws an antialiased outline centered on the edges defined
    by the set of points.

    Inputs:
        drawlist_ptr: ImGui draw list to render to
        points: array of points [x0, y0, ..., xn-1, yn-1]
        points_count: number of points n
        normals: array of normals [dx0, dy0, ..., dxn-1, dyn-1] for each point
        color: color of the outline
        thickness: thickness of the outline
        closed: Whether the last point of the outline is
            connected to the first point
    """
    cdef imgui.ImDrawList* draw_list = <imgui.ImDrawList*>drawlist_ptr

    if pattern is not None:
        _t_draw_polygon_outline_pattern(
            context, drawlist_ptr, points, points_count,
            normals, pattern, color, thickness, closed
        )
        return

    if thickness <= draw_list._FringeScale:
        _t_draw_polygon_outline_thin(
            context, drawlist_ptr, points, points_count,
            normals, color, thickness, closed
        )
    else:
        _t_draw_polygon_outline_thick(
            context, drawlist_ptr, points, points_count,
            normals, color, thickness, closed
        )



cdef void t_draw_polygon_filling(Context context,
                                 void* drawlist_ptr,
                                 const float* points,
                                 int points_count,
                                 const float* normals,
                                 const float* inner_points,
                                 int inner_points_count,
                                 const uint32_t* indices,
                                 int indices_count,
                                 uint32_t fill_color) noexcept nogil:
    """
    Draws a filled polygon using the provided points, indices and normals.
    
    Args:
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
    cdef bint has_fill = (fill_color & imgui.IM_COL32_A_MASK) != 0
    
    # Exit early if nothing to draw or not enough points
    if not(has_fill) or (points_count + inner_points_count) < 3 or indices_count < 3 or indices_count % 3 != 0:
        return

    cdef imgui.ImDrawList* draw_list = <imgui.ImDrawList*>drawlist_ptr
    cdef imgui.ImVec2 uv = imgui.GetFontTexUvWhitePixel()
    cdef imgui.ImU32 fill_col_trans = fill_color & ~imgui.IM_COL32_A_MASK
    cdef float AA_SIZE = draw_list._FringeScale

    # Determine polygon orientation
    cdef bint flip_normals = not(_is_polygon_counter_clockwise(points, points_count))
    
    cdef int i0, i1, i
    
    # FILL RENDERING
    cdef int vtx_count_fill, idx_count_fill
    cdef unsigned int vtx_inner_idx, vtx_outer_idx
    cdef float dm_x, dm_y, fringe_x, fringe_y

    # Reserve space for fill vertices and indices
    vtx_count_fill = points_count * 2 + inner_points_count  # Inner and outer vertices for each point + inner points
    idx_count_fill = indices_count + points_count * 6  # Interior triangles + AA fringe triangles
        
    draw_list.PrimReserve(idx_count_fill, vtx_count_fill)
        
    # Add triangles for inner fill from provided indices
    vtx_inner_idx = draw_list._VtxCurrentIdx
    for i in range(indices_count):
        if indices[i] < <uint32_t>points_count:
            draw_list.PrimWriteIdx(vtx_inner_idx + 2 * indices[i])
        else:
            draw_list.PrimWriteIdx(vtx_inner_idx + points_count + indices[i])

    # Generate AA fringe for the outline
    vtx_outer_idx = vtx_inner_idx + 1
    cdef float length
        
    # Add vertices and fringe triangles
    for i0 in range(points_count):
        i1 = (i0 + 1) % points_count
        
        # Average normals for smoother AA
        dm_x = normals[2*i0]
        dm_y = normals[2*i0+1]
        if flip_normals:
            dm_x = -dm_x
            dm_y = -dm_y

        """
        AA fringe: ideally it would be 1 pixel wide, but this
        would mean that pointy corners would get a large blurred band.
        We cannot easily split the polygon point into several
        points (round corner, etc), because it affects the triangulation.

        Instead the compromise here is to force the blurred band
        to be maximum 1 pixel-wide everywhere, even if it means some
        borders have less than 1 pixel-wide AA (and possibly different
        AA from a point to another).

        This compromise also ensures that any joints handling is ok
        for the outline rendering, and that we don't get a different
        visual when the outline moves from alpha=254 (AA filling) to
        alpha=255 (no AA filling).

        An alternative would be to split the exterior point only,
        for instance with a bevel, or with a round corner.
        """
        length = sqrt(dm_x*dm_x + dm_y*dm_y)
        if length > 1e-6:
            # Normalize the normal vector
            dm_x /= length
            dm_y /= length
        else:
            # Degenerate case, no AA fringe
            dm_x = 0.0
            dm_y = 0.0

        # Scale for AA fringe
        fringe_x = dm_x * AA_SIZE * 0.5
        fringe_y = dm_y * AA_SIZE * 0.5
        
        # Inner vertex
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] - fringe_x, points[2*i0+1] - fringe_y),
            uv, 
            <imgui.ImU32>fill_color
        )
        
        # Outer vertex
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0] + fringe_x, points[2*i0+1] + fringe_y),
            uv, 
            <imgui.ImU32>fill_col_trans
        )

        # Add fringe triangles
        draw_list.PrimWriteIdx(vtx_inner_idx + (i0 << 1))
        draw_list.PrimWriteIdx(vtx_inner_idx + (i1 << 1))
        draw_list.PrimWriteIdx(vtx_outer_idx + (i1 << 1))

        draw_list.PrimWriteIdx(vtx_outer_idx + (i1 << 1))
        draw_list.PrimWriteIdx(vtx_outer_idx + (i0 << 1))
        draw_list.PrimWriteIdx(vtx_inner_idx + (i0 << 1))

    # Add inner points if provided
    for i0 in range(inner_points_count):
        draw_list.PrimWriteVtx(
            imgui.ImVec2(inner_points[2*i0], inner_points[2*i0+1]),
            uv, 
            <imgui.ImU32>fill_color
        )

cdef void t_draw_polygon_filling_no_aa(Context context,
                                       void* drawlist_ptr,
                                       const float* points,
                                       int points_count,
                                       const float* inner_points,
                                       int inner_points_count,
                                       const uint32_t* indices,
                                       int indices_count,
                                       uint32_t fill_color) noexcept nogil:
    """
    Draws a filled polygon without anti-aliasing for improved performance.
    
    Args:
        drawlist_ptr: ImGui draw list to render to
        points: array of points [x0, y0, ..., xn-1, yn-1] defining the polygon in order
        points_count: number of points n
        inner_points: optional array of points inside the polygon for triangulation
        inner_points_count: number of inner points
        indices: Triangulation indices for the polygon (groups of 3 indices per triangle)
        indices_count: Number of indices (should be a multiple of 3)
        fill_color: Color to fill the polygon with (ImU32)
    """
    cdef bint has_fill = (fill_color & imgui.IM_COL32_A_MASK) != 0
    
    # Exit early if nothing to draw or not enough points
    if not(has_fill) or (points_count + inner_points_count) < 3 or indices_count < 3 or indices_count % 3 != 0:
        return

    cdef imgui.ImDrawList* draw_list = <imgui.ImDrawList*>drawlist_ptr
    cdef imgui.ImVec2 uv = imgui.GetFontTexUvWhitePixel()
    cdef int i0, i
    
    # FILL RENDERING - SIMPLIFIED WITHOUT AA
    cdef int vtx_count_fill = points_count + inner_points_count  # One vertex per point
    cdef int idx_count_fill = indices_count  # Only triangulation indices
    cdef unsigned int vtx_base_idx
    
    # Reserve space for vertices and indices
    draw_list.PrimReserve(idx_count_fill, vtx_count_fill)
    vtx_base_idx = draw_list._VtxCurrentIdx
    
    # Add perimeter points
    for i0 in range(points_count):
        draw_list.PrimWriteVtx(
            imgui.ImVec2(points[2*i0], points[2*i0+1]),
            uv, 
            <imgui.ImU32>fill_color
        )
    
    # Add inner points if provided
    for i0 in range(inner_points_count):
        draw_list.PrimWriteVtx(
            imgui.ImVec2(inner_points[2*i0], inner_points[2*i0+1]),
            uv, 
            <imgui.ImU32>fill_color
        )
    
    # Add triangulation indices - directly reference the vertices
    for i in range(indices_count):
        if indices[i] < <uint32_t>points_count:
            draw_list.PrimWriteIdx(vtx_base_idx + indices[i])
        else:
            # Inner points are stored after perimeter points
            draw_list.PrimWriteIdx(vtx_base_idx + (indices[i] - points_count) + points_count)

cdef void t_draw_polygon_filling_adaptive(Context context,
                                          void* drawlist_ptr,
                                          const float* points,
                                          int points_count,
                                          const float* normals,
                                          const float* inner_points,
                                          int inner_points_count,
                                          const uint32_t* indices,
                                          int indices_count,
                                          Pattern pattern,
                                          uint32_t outline_color,
                                          uint32_t fill_color,
                                          float thickness) noexcept nogil:
    """
    Draws a filled polygon using the provided points, indices and normals.
    Adaptively switches to AA or no AA depending on the outline properties
    
    Args:
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
        pattern: The outline pattern (None for solid)
        outline_color: Color for the polygon outline (ImU32)
        fill_color: Color to fill the polygon with (ImU32)
        thickness: Thickness of the outline
    """
    # If the outline is opaque we don't need AA borders for the filling
    if pattern is None and thickness >= 1.\
       and (outline_color & imgui.IM_COL32_A_MASK) == imgui.IM_COL32_A_MASK:
        # Draw the filling without AA
        t_draw_polygon_filling_no_aa(context,
                                     drawlist_ptr,
                                     points,
                                     points_count,
                                     inner_points,
                                     inner_points_count,
                                     indices,
                                     indices_count,
                                     fill_color)
    else:
        # Draw the filling with AA
        t_draw_polygon_filling(context,
                               drawlist_ptr,
                               points,
                               points_count,
                               normals,
                               inner_points,
                               inner_points_count,
                               indices,
                               indices_count,
                               fill_color)

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
                         float thickness) noexcept nogil:
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
        pattern: The outline pattern (None for solid)
        outline_color: Color for the polygon outline (ImU32)
        fill_color: Color to fill the polygon with (ImU32)
        thickness: Thickness of the outline

    The points can be either in counter-clockwise or clockwise order.
    If fill_color alpha is 0, only the outline is drawn.
    If outline_color alpha is 0 or thickness is 0, only the fill is drawn.
    """

    # Exit early if not enough points
    if points_count < 2:
        return

    # Allocate space for normals
    if (2 * points_count) > <int>context.viewport.temp_normals.size():
        context.viewport.temp_normals.resize(points_count * 2)

    # Compute normals for the polygon
    t_draw_compute_normals(context,
                           context.viewport.temp_normals.data(),
                           points, points_count, True)

    # Render the filling

    t_draw_polygon_filling_adaptive(context,
                                    drawlist_ptr,
                                    points,
                                    points_count,
                                    context.viewport.temp_normals.data(),
                                    inner_points,
                                    inner_points_count,
                                    indices,
                                    indices_count,
                                    pattern,
                                    outline_color,
                                    fill_color,
                                    thickness)

    # Render the outline
    t_draw_polygon_outline(context,
                           drawlist_ptr,
                           points,
                           points_count,
                           context.viewport.temp_normals.data(),
                           pattern,
                           outline_color,
                           thickness,
                           True)


cdef void draw_polygon(Context context,
                       void* drawlist_ptr,
                       const double* points,
                       int points_count,
                       const double* inner_points,
                       int inner_points_count,
                       const uint32_t* indices,
                       int indices_count,
                       Pattern pattern,
                       uint32_t outline_color,
                       uint32_t fill_color,
                       float thickness) noexcept nogil:
    cdef int i
    cdef DCGVector[float] *ipoints = &context.viewport.temp_point_coords

    if points_count < 2:
        return

    if (2 * (points_count + inner_points_count)) > <int>ipoints.size():
        ipoints.resize(2*(points_count+inner_points_count))

    cdef float *ipoints_p = ipoints.data()
    cdef double[2] p
    for i in range(points_count):
        p[0] = points[2*i]
        p[1] = points[2*i+1]
        (context.viewport).coordinate_to_screen(&ipoints_p[2*i], p)
    for i in range(inner_points_count):
        p[0] = inner_points[2*(points_count+i)]
        p[1] = inner_points[2*(points_count+i)+1]
        (context.viewport).coordinate_to_screen(&ipoints_p[2*(points_count+i)], p)

    t_draw_polygon(
        context,
        drawlist_ptr,
        ipoints.data(),
        points_count,
        ipoints.data() + 2*points_count,
        inner_points_count,
        indices,
        indices_count,
        pattern,
        outline_color,
        fill_color,
        thickness
    )

cdef void t_draw_polyline(Context context,
                          void* drawlist_ptr,
                          const float* points,
                          int points_count,
                          Pattern pattern,
                          uint32_t color,
                          bint closed,
                          float thickness) noexcept nogil:
    """
    Draw a series of connected segments with proper anti-aliasing.
    
    Args:
        context: The DearCyGui context
        drawlist_ptr: ImGui draw list to render to
        points: array of points [x0, y0, ..., xn-1, yn-1] defining the polyline in order.
        points_count: number of points n
        pattern: Pattern for the lines (None for solid)
        color: Color of the line (ImU32)
        closed: Whether to connect the last point back to the first
        thickness: Thickness of the line
    
    This function handles both thin and thick lines with proper anti-aliasing,
    with special handling for degenerate edges and AA fringes.
    """
    # Exit early if nothing to draw or not enough points
    if (color & imgui.IM_COL32_A_MASK == 0) or points_count < 2:
        return

    if (2 * points_count) > <int>context.viewport.temp_normals.size():
        context.viewport.temp_normals.resize(points_count * 2)

    t_draw_compute_normals(context,
                           context.viewport.temp_normals.data(),
                           points, points_count, closed)

    t_draw_polygon_outline(context,
                           drawlist_ptr,
                           points,
                           points_count,
                           context.viewport.temp_normals.data(),
                           pattern,
                           color,
                           thickness,
                           closed)

cdef void draw_polyline(Context context,
                        void* drawlist,
                        const double* points,
                        int points_count,
                        Pattern pattern,
                        uint32_t color,
                        bint closed,
                        float thickness) noexcept nogil:
    cdef int i
    cdef DCGVector[float] *ipoints = &context.viewport.temp_point_coords

    if points_count < 2:
        return

    if 2 * points_count < <int>ipoints.size():
        ipoints.resize(2*points_count)

    cdef float *ipoints_p = ipoints.data()
    cdef double[2] p
    for i in range(points_count):
        p[0] = points[2*i]
        p[1] = points[2*i+1]
        (context.viewport).coordinate_to_screen(&ipoints_p[2*i], p)

    t_draw_polyline(
        context,
        drawlist,
        ipoints.data(),
        points_count,
        pattern,
        color,
        closed,
        thickness
    )

cdef void t_draw_line(Context context, void* drawlist,
                      float x1, float y1, float x2, float y2,
                      Pattern pattern,
                      uint32_t color, float thickness) noexcept nogil:
    cdef float[4] coords = [x1, y1, x2, y2]

    if t_item_fully_clipped(context,
                            drawlist,
                            fmin(x1, x2) - thickness,
                            fmax(x1, x2) + thickness,
                            fmin(y1, y2) - thickness,
                            fmax(y1, y2) + thickness):
        return

    t_draw_polyline(context,
                   drawlist,
                   coords,
                   2,
                   pattern,
                   color,
                   False,
                   thickness)

cdef void draw_line(Context context, void* drawlist,
                    double x1, double y1, double x2, double y2,
                    Pattern pattern,
                    uint32_t color, float thickness) noexcept nogil:
    # Transform coordinates 
    cdef float[2] p1, p2
    cdef double[2] pos1, pos2
    pos1[0] = x1
    pos1[1] = y1 
    pos2[0] = x2
    pos2[1] = y2
    (context.viewport).coordinate_to_screen(p1, pos1)
    (context.viewport).coordinate_to_screen(p2, pos2)

    t_draw_line(context, drawlist, p1[0], p1[1], p2[0], p2[1], pattern, color, thickness)

cdef void t_draw_triangle(Context context, void* drawlist,
                          float x1, float y1, float x2, float y2,
                          float x3, float y3, Pattern pattern,
                          uint32_t color, uint32_t fill_color,
                          float thickness) noexcept nogil:
    cdef float[6] coords = [x1, y1, x2, y2, x3, y3]
    cdef uint32_t[3] indices = [0, 1, 2]

    if t_item_fully_clipped(context,
                            drawlist,
                            min(x1, x2, x3) - thickness,
                            max(x1, x2, x3) + thickness,
                            min(y1, y2, y3) - thickness,
                            max(y1, y2, y3) + thickness):
        return

    t_draw_polygon(context,
                   drawlist,
                   coords,
                   3,
                   NULL,
                   0,
                   indices,
                   3,
                   pattern,
                   color,
                   fill_color,
                   thickness)

cdef void draw_triangle(Context context, void* drawlist,
                        double x1, double y1, double x2,
                        double y2, double x3, double y3,
                        Pattern pattern,
                        uint32_t color, uint32_t fill_color,
                        float thickness) noexcept nogil:
    # Transform coordinates
    cdef float[2] p1, p2, p3
    cdef double[2] pos1, pos2, pos3
    pos1[0] = x1
    pos1[1] = y1
    pos2[0] = x2
    pos2[1] = y2
    pos3[0] = x3
    pos3[1] = y3
    (context.viewport).coordinate_to_screen(p1, pos1)
    (context.viewport).coordinate_to_screen(p2, pos2)
    (context.viewport).coordinate_to_screen(p3, pos3)

    t_draw_triangle(context, drawlist, p1[0], p1[1], p2[0], p2[1], p3[0], p3[1],
                    pattern, color, fill_color, thickness)

# We use AddRect as it supports rounding TODO: pattern
cdef void t_draw_rect(Context context, void* drawlist,
                      float x1, float y1, float x2, float y2,
                      Pattern pattern,
                      uint32_t color, uint32_t fill_color,
                      float thickness, float rounding) noexcept nogil:
    if t_item_fully_clipped(context,
                            drawlist,
                            fmin(x1, x2) - thickness,
                            fmax(x1, x2) + thickness,
                            fmin(y1, y2) - thickness,
                            fmax(y1, y2) + thickness):
        return

    # Create imgui.ImVec2 points
    cdef imgui.ImVec2 ipmin = imgui.ImVec2(x1, y1)
    cdef imgui.ImVec2 ipmax = imgui.ImVec2(x2, y2)

    # Handle coordinate order
    if ipmin.x > ipmax.x:
        swap(ipmin.x, ipmax.x)
    if ipmin.y > ipmax.y:
        swap(ipmin.y, ipmax.y)

    if fill_color & imgui.IM_COL32_A_MASK != 0:
        (<imgui.ImDrawList*>drawlist).AddRectFilled(ipmin,
                            ipmax,
                            fill_color,
                            rounding,
                            imgui.ImDrawFlags_RoundCornersAll)

    (<imgui.ImDrawList*>drawlist).AddRect(ipmin,
                        ipmax,
                        color,
                        rounding,
                        imgui.ImDrawFlags_RoundCornersAll,
                        thickness)


cdef void draw_rect(Context context, void* drawlist,
                    double x1, double y1, double x2, double y2,
                    Pattern pattern,
                    uint32_t color, uint32_t fill_color,
                    float thickness, float rounding) noexcept nogil:
    # Transform coordinates
    cdef float[2] pmin, pmax
    cdef double[2] pos1, pos2
    pos1[0] = x1
    pos1[1] = y1
    pos2[0] = x2
    pos2[1] = y2
    (context.viewport).coordinate_to_screen(pmin, pos1)
    (context.viewport).coordinate_to_screen(pmax, pos2)

    t_draw_rect(context, drawlist, pmin[0], pmin[1], pmax[0], pmax[1],
                pattern, color, fill_color, thickness, rounding)


cdef void t_draw_quad(Context context, void* drawlist,
                    float x1, float y1, float x2, float y2,
                    float x3, float y3, float x4, float y4,
                    Pattern pattern,
                    uint32_t color, uint32_t fill_color,
                    float thickness) noexcept nogil:
    if t_item_fully_clipped(context,
                            drawlist,
                            min(x1, x2, x3, x4) - thickness,
                            max(x1, x2, x3, x4) + thickness,
                            min(y1, y2, y3, y4) - thickness,
                            max(y1, y2, y3, y4) + thickness):
        return

    cdef float[8] coords = [x1, y1, x2, y2, x3, y3, x4, y4]
    cdef uint32_t[6] indices = [0, 1, 2, 0, 2, 3]

    t_draw_polygon(context,
                   drawlist,
                   coords,
                   4,
                   NULL,
                   0,
                   indices,
                   6,
                   pattern,
                   color,
                   fill_color,
                   thickness)


cdef void draw_quad(Context context, void* drawlist,
                    double x1, double y1, double x2, double y2,
                    double x3, double y3, double x4, double y4,
                    Pattern pattern,
                    uint32_t color, uint32_t fill_color,
                    float thickness) noexcept nogil:
    # Transform coordinates
    cdef float[2] p1, p2, p3, p4
    cdef double[2] pos1, pos2, pos3, pos4
    pos1[0] = x1
    pos1[1] = y1
    pos2[0] = x2
    pos2[1] = y2
    pos3[0] = x3
    pos3[1] = y3
    pos4[0] = x4
    pos4[1] = y4
    (context.viewport).coordinate_to_screen(p1, pos1)
    (context.viewport).coordinate_to_screen(p2, pos2)
    (context.viewport).coordinate_to_screen(p3, pos3)
    (context.viewport).coordinate_to_screen(p4, pos4)

    t_draw_quad(context, drawlist, p1[0], p1[1], p2[0], p2[1], p3[0], p3[1], p4[0], p4[1],
                pattern, color, fill_color, thickness)


# We use AddCircle as it does the computation of the points for us. TODO: pattern
cdef void t_draw_circle(Context context, void* drawlist,
                        float x, float y, float radius,
                        Pattern pattern,
                        uint32_t color, uint32_t fill_color,
                        float thickness, int32_t num_segments) noexcept nogil:

    radius = fabs(radius)

    if pattern is not None:
        t_draw_ellipse(context,
                       drawlist,
                       x, y,
                       radius, radius,
                       0.0,
                       num_segments,
                       pattern,
                       color, fill_color,
                       thickness)
        return

    # Early clipping test
    cdef float expanded_radius = radius + thickness
    cdef float item_x_min = x - expanded_radius
    cdef float item_x_max = x + expanded_radius
    cdef float item_y_min = y - expanded_radius
    cdef float item_y_max = y + expanded_radius
    
    if t_item_fully_clipped(context, drawlist, item_x_min, item_x_max, item_y_min, item_y_max):
        return

    # Create imgui.ImVec2 point
    cdef imgui.ImVec2 icenter = imgui.ImVec2(x, y)
    
    if fill_color & imgui.IM_COL32_A_MASK != 0:
        (<imgui.ImDrawList*>drawlist).AddCircleFilled(icenter, radius, fill_color, num_segments)
    
    (<imgui.ImDrawList*>drawlist).AddCircle(icenter, radius, color, num_segments, thickness)


cdef void draw_circle(Context context, void* drawlist,
                      double x, double y, double radius,
                      Pattern pattern,
                      uint32_t color, uint32_t fill_color,
                      float thickness, int32_t num_segments) noexcept nogil:
    # Transform coordinates
    cdef float[2] center
    cdef double[2] pos
    pos[0] = x
    pos[1] = y
    (context.viewport).coordinate_to_screen(center, pos)

    t_draw_circle(context, drawlist, center[0], center[1], radius, pattern, color, fill_color, thickness, num_segments)


cdef inline bint t_ellipse_fully_clipped(Context context,
                                         void* drawlist,
                                         float center_x, float center_y,
                                         float radius_x, float radius_y,
                                         float rotation, float thickness) noexcept nogil:
    """
    Check if an ellipse is fully clipped and doesn't need to be rendered.
    
    Args:
        context: The DearCyGui context
        drawlist: ImDrawList to render into
        center_x, center_y: Center of the ellipse
        radius_x, radius_y: Radii of the ellipse
        rotation: Rotation angle in radians
        thickness: Outline thickness to account for in bounds
        
    Returns:
        True if the ellipse is completely outside the clip rect
    """
    # For a rotated ellipse, the most conservative bounding box is a circle
    # with radius equal to the maximum radius plus thickness
    cdef float max_radius = fmax(radius_x, radius_y) + thickness
    
    # Early clipping test
    cdef float item_x_min = center_x - max_radius
    cdef float item_x_max = center_x + max_radius
    cdef float item_y_min = center_y - max_radius
    cdef float item_y_max = center_y + max_radius
    
    return t_item_fully_clipped(context, drawlist, item_x_min, item_x_max, item_y_min, item_y_max)


cdef void t_draw_elliptical_arc(Context context, void* drawlist,
                                float center_x, float center_y,
                                float radius_x, float radius_y,
                                float start_angle, float end_angle,
                                float rotation,  
                                int32_t num_points,
                                Pattern pattern,
                                uint32_t outline_color,
                                uint32_t fill_color,
                                float thickness) noexcept nogil:
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
        pattern: The outline pattern (None for solid)
        outline_color: Color for the outline (ImU32)
        fill_color: Color for the filling (ImU32)
        thickness: Thickness of the outline
    """
    if t_ellipse_fully_clipped(context, drawlist, center_x, center_y, 
                               radius_x, radius_y, rotation, thickness):
        return
    # For correct filling, angles must be increasing
    if end_angle < start_angle:
        swap(start_angle, end_angle)  

    # Clear previous points
    context.viewport.temp_point_coords.clear()
    context.viewport.temp_normals.clear()

    generate_elliptical_arc_points(
        context.viewport.temp_point_coords,
        context.viewport.temp_normals,
        center_x,
        center_y,
        radius_x,
        radius_y,
        rotation,
        start_angle,
        end_angle,
        num_points,
        True
    )
    cdef int num_points_upper_arc = context.viewport.temp_point_coords.size() >> 1
    if num_points_upper_arc < 2:
        return

    # Arc + joined filling
    cdef int i
    if fill_color != 0:
        # Generate indices for the arc filling
        context.viewport.temp_indices.clear()
        for i in range(num_points_upper_arc - 1):
            context.viewport.temp_indices.push_back(i)
            context.viewport.temp_indices.push_back(i + 1)
            context.viewport.temp_indices.push_back(num_points_upper_arc - 1)
        context.viewport.temp_indices.push_back(num_points_upper_arc - 1)
        context.viewport.temp_indices.push_back(0)
        context.viewport.temp_indices.push_back(num_points_upper_arc - 2)

        # Fill the arc
        t_draw_polygon_filling_adaptive(
            context,
            drawlist,
            context.viewport.temp_point_coords.data(),
            context.viewport.temp_point_coords.size() >> 1,
            context.viewport.temp_normals.data(),
            NULL,
            0,
            context.viewport.temp_indices.data(),
            context.viewport.temp_indices.size(),
            pattern,
            outline_color,
            fill_color,
            thickness
        )

    # Draw the arc
    t_draw_polygon_outline(
        context,
        drawlist,
        context.viewport.temp_point_coords.data(),
        context.viewport.temp_point_coords.size() >> 1,
        context.viewport.temp_normals.data(),
        pattern,
        outline_color,
        thickness,
        False
    )

cdef void t_draw_elliptical_pie_slice(Context context, void* drawlist,
                                      float center_x, float center_y,
                                      float radius_x, float radius_y,
                                      float start_angle, float end_angle,
                                      float rotation,  
                                      int32_t num_points,
                                      Pattern pattern,
                                      uint32_t outline_color,
                                      uint32_t fill_color,
                                      float thickness) noexcept nogil:
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
        pattern: The outline pattern (None for solid)
        outline_color: Color for the outline (ImU32)
        fill_color: Color for the filling (ImU32)
        thickness: Thickness of the outline
    """
    if t_ellipse_fully_clipped(context, drawlist, center_x, center_y, 
                               radius_x, radius_y, rotation, thickness):
        return
    # For correct filling, angles must be increasing
    if end_angle < start_angle:
        swap(start_angle, end_angle)  

    # Clear previous points
    context.viewport.temp_point_coords.clear()
    context.viewport.temp_normals.clear()

    generate_elliptical_arc_points(
        context.viewport.temp_point_coords,
        context.viewport.temp_normals,
        center_x,
        center_y,
        radius_x,
        radius_y,
        rotation,
        start_angle,
        end_angle,
        num_points,
        True
    )
    cdef int num_points_upper_arc = context.viewport.temp_point_coords.size() >> 1
    if num_points_upper_arc < 2:
        return

    context.viewport.temp_point_coords.push_back(center_x)
    context.viewport.temp_point_coords.push_back(center_y)

    # Center normal
    cdef float[2] normal
    t_draw_compute_normal_at(
        context,
        normal,
        context.viewport.temp_point_coords.data(),
        context.viewport.temp_point_coords.size() >> 1,
        num_points_upper_arc,
        True
    )

    # push the normal
    context.viewport.temp_normals.push_back(normal[0])
    context.viewport.temp_normals.push_back(normal[1])

    # Replaces normals for arc extremums
    t_draw_compute_normal_at(
        context,
        context.viewport.temp_normals.data(),
        context.viewport.temp_point_coords.data(),
        context.viewport.temp_point_coords.size() >> 1,
        0,
        True
    )
    t_draw_compute_normal_at(
        context,
        context.viewport.temp_normals.data() + 
            (num_points_upper_arc - 1) * 2,
        context.viewport.temp_point_coords.data(),
        context.viewport.temp_point_coords.size() >> 1,
        num_points_upper_arc - 1,
        True
    )

    cdef int i
    if fill_color != 0:
        context.viewport.temp_indices.clear()
        # Connect each point to the center
        for i in range(num_points_upper_arc-1):
            context.viewport.temp_indices.push_back(i)
            context.viewport.temp_indices.push_back(num_points_upper_arc)
            context.viewport.temp_indices.push_back(i + 1)

        # Fill the arc
        t_draw_polygon_filling_adaptive(
            context,
            drawlist,
            context.viewport.temp_point_coords.data(),
            context.viewport.temp_point_coords.size() >> 1,
            context.viewport.temp_normals.data(),
            NULL,
            0,
            context.viewport.temp_indices.data(),
            context.viewport.temp_indices.size(),
            pattern,
            outline_color,
            fill_color,
            thickness
        )
    # Draw the outline
    t_draw_polygon_outline(
        context,
        drawlist,
        context.viewport.temp_point_coords.data(),
        context.viewport.temp_point_coords.size() >> 1,
        context.viewport.temp_normals.data(),
        pattern,
        outline_color,
        thickness,
        True
    )

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
                                         float thickness) noexcept nogil:
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
    if t_ellipse_fully_clipped(context, drawlist, center_x, center_y, 
                               radius_x, radius_y, rotation, thickness):
        return
    # For correct filling, angles must be increasing
    if end_angle < start_angle:
        swap(start_angle, end_angle)  

    # Clear previous points
    context.viewport.temp_point_coords.clear()
    context.viewport.temp_normals.clear()

    generate_elliptical_arc_points(
        context.viewport.temp_point_coords,
        context.viewport.temp_normals,
        center_x,
        center_y,
        radius_x,
        radius_y,
        rotation,
        start_angle,
        end_angle,
        num_points,
        True
    )
    cdef int num_points_upper_arc = context.viewport.temp_point_coords.size() >> 1
    if num_points_upper_arc < 2:
        return

    # Generate the inner arc in the reverse order

    # TODO: this is probably just a scaled version of the upper one when the ratio
    # of radiuses match

    generate_elliptical_arc_points(
        context.viewport.temp_point_coords,
        context.viewport.temp_normals,
        center_x,
        center_y,
        inner_radius_x,
        inner_radius_y,
        rotation,
        end_angle,
        start_angle,
        num_points_upper_arc-1, # To simplify filling we request same number of points
        False
    )

    # Fix the normals at extremums of both arcs
    t_draw_compute_normal_at(
        context,
        context.viewport.temp_normals.data(),
        context.viewport.temp_point_coords.data(),
        context.viewport.temp_point_coords.size() >> 1,
        0,
        True
    )
    t_draw_compute_normal_at(
        context,
        context.viewport.temp_normals.data() + 
            (num_points_upper_arc - 1) * 2,
        context.viewport.temp_point_coords.data(),
        context.viewport.temp_point_coords.size() >> 1,
        num_points_upper_arc - 1,
        True
    )
    t_draw_compute_normal_at(
        context,
        context.viewport.temp_normals.data() + 
            num_points_upper_arc * 2,
        context.viewport.temp_point_coords.data(),
        context.viewport.temp_point_coords.size() >> 1,
        num_points_upper_arc,
        True
    )
    cdef int num_points_tot = context.viewport.temp_point_coords.size() >> 1
    t_draw_compute_normal_at(
        context,
        context.viewport.temp_normals.data() + 
            (num_points_tot - 1) * 2,
        context.viewport.temp_point_coords.data(),
        context.viewport.temp_point_coords.size() >> 1,
        num_points_tot - 1,
        True
    )

    cdef int num_points_inner_arc = num_points_tot - num_points_upper_arc
    assert num_points_inner_arc == num_points_upper_arc
    cdef int i, outer_current, outer_next, inner_current, inner_next

    if fill_color != 0:
        # Generate indices for the arc filling
        context.viewport.temp_indices.clear()
        # Calculate the number of inner arc points

        # Connect outer arc points to corresponding inner arc points with triangles
        for i in range(num_points_upper_arc - 1):
            # Outer arc indices
            outer_current = i
            outer_next = i + 1
            
            # Corresponding inner arc indices (inner arc is reversed)
            inner_current = num_points_inner_arc - 1 - i
            inner_next = inner_current - 1  # Next point in inner arc
            
            # Triangle 1: outer_current, outer_next, inner_current
            context.viewport.temp_indices.push_back(outer_current)
            context.viewport.temp_indices.push_back(outer_next)
            context.viewport.temp_indices.push_back(num_points_upper_arc + inner_current)
            
            # Triangle 2: outer_next, inner_next, inner_current
            context.viewport.temp_indices.push_back(outer_next)
            context.viewport.temp_indices.push_back(num_points_upper_arc + inner_next)
            context.viewport.temp_indices.push_back(num_points_upper_arc + inner_current)


        # Draw the arc filling
        t_draw_polygon_filling_adaptive(
            context,
            drawlist,
            context.viewport.temp_point_coords.data(),
            context.viewport.temp_point_coords.size() >> 1,
            context.viewport.temp_normals.data(),
            NULL,
            0,
            context.viewport.temp_indices.data(),
            context.viewport.temp_indices.size(),
            pattern,
            outline_color,
            fill_color,
            thickness
        )
    t_draw_polygon_outline(
        context,
        drawlist,
        context.viewport.temp_point_coords.data(),
        context.viewport.temp_point_coords.size() >> 1,
        context.viewport.temp_normals.data(),
        pattern,
        outline_color,
        thickness,
        True
    )


cdef void t_draw_ellipse(Context context, void* drawlist,
                         float center_x, float center_y,
                         float radius_x, float radius_y,
                         float rotation,  
                         int32_t num_points,
                         Pattern pattern,
                         uint32_t outline_color,
                         uint32_t fill_color,
                         float thickness) noexcept nogil:
    """
    Draws a complete ellipse with anti-aliasing.

    Args:
        context: The DearCyGui context
        drawlist_ptr: ImGui draw list to render to
        center_x, center_y: Center of the ellipse
        radius_x, radius_y: Radii of the ellipse
        rotation: Rotation angle of the ellipse in radians
        num_points: Number of points to use for the external arc (0 means auto)
        pattern: The outline pattern (None for solid)
        outline_color: Color for the outline (ImU32)
        fill_color: Color for the filling (ImU32)
        thickness: Thickness of the outline
    """
    if t_ellipse_fully_clipped(context, drawlist, center_x, center_y, 
                               radius_x, radius_y, rotation, thickness):
        return
    # Clear previous points
    context.viewport.temp_point_coords.clear()
    context.viewport.temp_normals.clear()

    generate_elliptical_arc_points(
        context.viewport.temp_point_coords,
        context.viewport.temp_normals,
        center_x,
        center_y,
        radius_x,
        radius_y,
        rotation,
        0,
        2 * M_PI,
        num_points,
        True
    )
    cdef int num_points_upper_arc = context.viewport.temp_point_coords.size() >> 1
    if num_points_upper_arc < 2:
        return
    cdef int i

    # triangulation of the inside
    if fill_color != 0:
        # Add center point as inner point for the triangulation
        context.viewport.temp_point_coords.push_back(center_x)
        context.viewport.temp_point_coords.push_back(center_y)

        context.viewport.temp_indices.clear()
        for i in range(num_points_upper_arc - 1):
            context.viewport.temp_indices.push_back(i)
            context.viewport.temp_indices.push_back(i + 1)
            context.viewport.temp_indices.push_back(num_points_upper_arc) # center point
        context.viewport.temp_indices.push_back(num_points_upper_arc - 1)
        context.viewport.temp_indices.push_back(0)
        context.viewport.temp_indices.push_back(num_points_upper_arc) # center point
    
        # Fill the arc
        t_draw_polygon_filling_adaptive(
            context,
            drawlist,
            context.viewport.temp_point_coords.data(),
            num_points_upper_arc,
            context.viewport.temp_normals.data(),
            context.viewport.temp_point_coords.data() + 2 * num_points_upper_arc,
            1,
            context.viewport.temp_indices.data(),
            context.viewport.temp_indices.size(),
            pattern,
            outline_color,
            fill_color,
            thickness
        )

    # Draw the outline
    t_draw_polygon_outline(
        context,
        drawlist,
        context.viewport.temp_point_coords.data(),
        num_points_upper_arc,
        context.viewport.temp_normals.data(),
        pattern,
        outline_color,
        thickness,
        True
    )


cdef void t_draw_elliptical_ring(Context context, void* drawlist,
                                 float center_x, float center_y,
                                 float radius_x, float radius_y,
                                 float inner_radius_x, float inner_radius_y,
                                 float rotation,  
                                 int32_t num_points,
                                 Pattern pattern,
                                 uint32_t outline_color,
                                 uint32_t fill_color,
                                 float thickness) noexcept nogil:
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
        pattern: The outline pattern (None for solid)
        outline_color: Color for the outline (ImU32)
        fill_color: Color for the filling (ImU32)
        thickness: Thickness of the outline

    The parameters must verify:
        0 < inner_radius_x < radius_x
        0 < inner_radius_y < radius_y
    """
    if t_ellipse_fully_clipped(context, drawlist, center_x, center_y, 
                               radius_x, radius_y, rotation, thickness):
        return
    # Clear previous points
    context.viewport.temp_point_coords.clear()
    context.viewport.temp_normals.clear()

    generate_elliptical_arc_points(
        context.viewport.temp_point_coords,
        context.viewport.temp_normals,
        center_x,
        center_y,
        radius_x,
        radius_y,
        rotation,
        0,
        2 * M_PI,
        num_points,
        True
    )
    cdef int num_points_upper_arc = context.viewport.temp_point_coords.size() >> 1
    if num_points_upper_arc < 2:
        return

    cdef int i, outer_current, outer_next, inner_current, inner_next
    cdef int num_points_inner_arc = num_points_upper_arc

    # Ring ellipse
    generate_elliptical_arc_points(
        context.viewport.temp_point_coords,
        context.viewport.temp_normals,
        center_x,
        center_y,
        inner_radius_x,
        inner_radius_y,
        rotation,
        2 * M_PI,
        0,
        num_points_inner_arc-1, # To simplify filling we request same number of points
        False
    )
    # Generate indices for the arc filling
    context.viewport.temp_indices.clear()

    # Connect outer arc points to corresponding inner arc points with triangles
    for i in range(num_points_upper_arc - 1):
        # Outer arc indices
        outer_current = i
        outer_next = i + 1
        
        # Corresponding inner arc indices (inner arc is reversed)
        inner_current = num_points_inner_arc - 1 - i
        inner_next = inner_current - 1  # Next point in inner arc
        
        # Triangle 1: outer_current, outer_next, inner_current
        context.viewport.temp_indices.push_back(outer_current)
        context.viewport.temp_indices.push_back(outer_next)
        context.viewport.temp_indices.push_back(num_points_inner_arc + inner_current)
        
        # Triangle 2: outer_next, inner_next, inner_current
        context.viewport.temp_indices.push_back(outer_next)
        context.viewport.temp_indices.push_back(num_points_inner_arc + inner_next)
        context.viewport.temp_indices.push_back(num_points_inner_arc + inner_current)
            
    # To draw the inside, as polygon_filling requires a closed shape,
    # we use no AA for the inside TODO: can be improved

    # Inside
    t_draw_polygon_filling_adaptive(
        context,
        drawlist,
        context.viewport.temp_point_coords.data(),
        num_points_upper_arc,
        context.viewport.temp_normals.data(),
        context.viewport.temp_point_coords.data() + num_points_upper_arc * 2,
        num_points_inner_arc,
        context.viewport.temp_indices.data(),
        context.viewport.temp_indices.size(),
        pattern,
        outline_color,
        fill_color,
        thickness
    )

    # Draw the external outline
    t_draw_polygon_outline(
        context,
        drawlist,
        context.viewport.temp_point_coords.data(),
        num_points_upper_arc,
        context.viewport.temp_normals.data(),
        pattern,
        outline_color,
        thickness,
        True
    )
    # Draw the internal outline
    t_draw_polygon_outline(
        context,
        drawlist,
        context.viewport.temp_point_coords.data() + num_points_upper_arc * 2,
        num_points_upper_arc,
        context.viewport.temp_normals.data() + num_points_upper_arc * 2,
        pattern,
        outline_color,
        thickness,
        True
    )


cdef void t_draw_regular_polygon(Context context, void* drawlist,
                                 float centerx, float centery,
                                 float radius, float direction,  
                                 int32_t num_points, Pattern pattern,
                                 uint32_t color, uint32_t fill_color,
                                 float thickness) noexcept nogil:
    radius = fabs(radius)
    direction = fmod(direction, M_PI * 2.) # Doing so increases precision

    if num_points <= 1:
        # Draw circle instead
        t_draw_circle(context, drawlist, centerx, centery, radius,
                      pattern, color, fill_color, thickness, 0)
        return

    # Early clipping test
    cdef float expanded_radius = radius + thickness
    cdef float item_x_min = centerx - expanded_radius
    cdef float item_x_max = centerx + expanded_radius
    cdef float item_y_min = centery - expanded_radius
    cdef float item_y_max = centery + expanded_radius
    
    if t_item_fully_clipped(context, drawlist, item_x_min, item_x_max, item_y_min, item_y_max):
        return

    # Generate points for the polygon
    cdef DCGVector[float] *points = &context.viewport.temp_point_coords
    points.clear()

    cdef float angle
    cdef float angle_step = 2.0 * M_PI / num_points
    cdef int32_t i

    # Add perimeter points
    for i in range(num_points):
        angle = -direction + i * angle_step
        points.push_back(centerx + radius * cos(angle))
        points.push_back(centery + radius * sin(angle))

    # Add center point 
    points.push_back(centerx)
    points.push_back(centery)

    # Create triangulation indices
    cdef DCGVector[uint32_t] *indices = &context.viewport.temp_indices
    indices.clear()

    for i in range(num_points - 1):
        # Triangle: center, current point, next point
        indices.push_back(num_points) # Center point
        indices.push_back(i)
        indices.push_back(i + 1)

    # Close the polygon - last triangle
    indices.push_back(num_points) # Center point
    indices.push_back(num_points - 1)
    indices.push_back(0)

    # Draw using t_draw_polygon
    t_draw_polygon(
        context,
        drawlist,
        points.data(),
        num_points,
        &points.data()[2 * num_points], # Center point address
        1,                              # One inner point (center)
        indices.data(),
        indices.size(),
        pattern,
        color,
        fill_color,
        thickness
    )


cdef void draw_regular_polygon(Context context, void* drawlist,
                               double centerx, double centery,
                               double radius, double direction,  
                               int32_t num_points, Pattern pattern,
                               uint32_t color, uint32_t fill_color,
                               float thickness) noexcept nogil:
    cdef float[2] center
    cdef double[2] pos
    pos[0] = centerx 
    pos[1] = centery
    (context.viewport).coordinate_to_screen(center, pos)

    t_draw_regular_polygon(context, drawlist, center[0], center[1],
                           radius, direction, num_points, pattern,
                           color, fill_color, thickness)


cdef void t_draw_star(Context context, void* drawlist,
                      float centerx, float centery, 
                      float radius, float inner_radius,
                      float direction, int32_t num_points,
                      Pattern pattern,
                      uint32_t color, uint32_t fill_color,
                      float thickness) noexcept nogil:

    if num_points < 3:
        # Draw circle instead for degenerate cases
        t_draw_circle(context, drawlist, centerx, centery, radius,
                      pattern, color, fill_color, thickness, 0)
        return
    
    radius = fabs(radius)
    inner_radius = fmin(radius, fabs(inner_radius))
    direction = fmod(direction, M_PI * 2.)

    # Early clipping test
    cdef float expanded_radius = radius + thickness
    cdef float item_x_min = centerx - expanded_radius
    cdef float item_x_max = centerx + expanded_radius
    cdef float item_y_min = centery - expanded_radius
    cdef float item_y_max = centery + expanded_radius
    
    if t_item_fully_clipped(context, drawlist, item_x_min, item_x_max, item_y_min, item_y_max):
        return

    cdef float angle
    cdef int32_t i
    cdef float px1, py1, px2, py2
    cdef float px, py

    # Special case for inner_radius = 0
    if inner_radius == 0.0:
        if num_points % 2 == 0:
            # Draw crossing lines for even number of points
            for i in range(num_points//2):
                angle = -direction + i * (M_PI / (num_points/2))
                px1 = centerx + radius * cos(angle)
                py1 = centery + radius * sin(angle)
                px2 = centerx - radius * cos(angle)
                py2 = centery - radius * sin(angle)
                t_draw_line(context, drawlist, px1, py1, px2, py2, pattern, color, thickness)
        else:
            # Draw lines to center for odd number of points
            for i in range(num_points):
                angle = -direction + i * (2.0 * M_PI / num_points)
                px = centerx + radius * cos(angle)
                py = centery + radius * sin(angle)
                t_draw_line(context, drawlist, px, py, centerx, centery, pattern, color, thickness)
        return

    # Prepare angles for star pattern
    cdef float start_angle = -direction
    cdef float start_angle_inner = -direction + M_PI / num_points
    cdef float angle_step = (M_PI * 2.0) / num_points

    # Generate points for the star
    cdef DCGVector[float] *points = &context.viewport.temp_point_coords
    points.clear()
    points.reserve(num_points * 4 + 2)

    # Add alternating outer and inner points
    for i in range(num_points):
        # Outer point
        angle = start_angle + (i / float(num_points)) * (M_PI * 2.0)
        points.push_back(centerx + radius * cos(angle))
        points.push_back(centery + radius * sin(angle))

        # Inner point
        angle = start_angle_inner + (i / float(num_points)) * (M_PI * 2.0)
        points.push_back(centerx + inner_radius * cos(angle))
        points.push_back(centery + inner_radius * sin(angle))

    # Add center point
    points.push_back(centerx)
    points.push_back(centery)

    # Create triangulation indices
    cdef DCGVector[uint32_t] *indices = &context.viewport.temp_indices
    indices.clear()
    indices.reserve(num_points * 6)
    cdef uint32_t center_idx = num_points * 2
    cdef int32_t next_i

    # Inner polygon triangulation
    for i in range(num_points - 1):
        indices.push_back(center_idx)      # Center point
        indices.push_back(i * 2 + 1)       # Current inner point
        indices.push_back((i + 1) * 2 + 1) # Next inner point

    # Close inner polygon
    indices.push_back(center_idx)          # Center point
    indices.push_back((num_points - 1) * 2 + 1) # Last inner point
    indices.push_back(1)                   # First inner point

    # Outer to inner connections
    for i in range(num_points):
        next_i = (i + 1) % num_points
        # Triangle connecting inner point, next outer point, and next inner point
        indices.push_back(i * 2 + 1)           # Current inner point
        indices.push_back(next_i * 2)          # Next outer point
        indices.push_back(next_i * 2 + 1)      # Next inner point

    # Draw using t_draw_polygon
    t_draw_polygon(
        context,
        drawlist,
        points.data(),
        num_points * 2,            # Outer + inner points 
        &points.data()[num_points * 4],  # Center point address
        1,                         # One inner point (center)
        indices.data(),
        indices.size(),
        pattern,
        color,
        fill_color,
        thickness
    )


cdef void draw_star(Context context, void* drawlist,
                    double centerx, double centery, 
                    double radius, double inner_radius,
                    double direction, int32_t num_points,
                    Pattern pattern,
                    uint32_t color, uint32_t fill_color,
                    float thickness) noexcept nogil:
    # Transform center coordinates
    cdef float[2] center
    cdef double[2] pos
    pos[0] = centerx
    pos[1] = centery
    (context.viewport).coordinate_to_screen(center, pos)

    t_draw_star(context, drawlist, center[0], center[1], radius, inner_radius,
                direction, num_points, pattern, color, fill_color, thickness)


cdef void t_draw_rect_multicolor(Context context, void* drawlist,
                                 float x1, float y1, float x2, float y2,
                                 uint32_t col_up_left, uint32_t col_up_right, 
                                 uint32_t col_bot_right, uint32_t col_bot_left) noexcept nogil:

    if t_item_fully_clipped(context,
                            drawlist,
                            fmin(x1, x2),
                            fmax(x1, x2),
                            fmin(y1, y2),
                            fmax(y1, y2)):
        return

    cdef imgui.ImVec2 ipmin = imgui.ImVec2(x1, y1)
    cdef imgui.ImVec2 ipmax = imgui.ImVec2(x2, y2)

    # Handle coordinate order 
    if ipmin.x > ipmax.x:
        swap(ipmin.x, ipmax.x)
        swap(col_up_left, col_up_right)
        swap(col_bot_left, col_bot_right)
    if ipmin.y > ipmax.y:
        swap(ipmin.y, ipmax.y)
        swap(col_up_left, col_bot_left)
        swap(col_up_right, col_bot_right)

    (<imgui.ImDrawList*>drawlist).AddRectFilledMultiColor(ipmin,
                                    ipmax,
                                    col_up_left,
                                    col_up_right,
                                    col_bot_right,
                                    col_bot_left)

cdef void draw_rect_multicolor(Context context, void* drawlist,
                               double x1, double y1, double x2, double y2,
                               uint32_t col_up_left, uint32_t col_up_right, 
                               uint32_t col_bot_right, uint32_t col_bot_left) noexcept nogil:
    # Transform coordinates
    cdef float[2] pmin, pmax  
    cdef double[2] pos1, pos2
    pos1[0] = x1
    pos1[1] = y1
    pos2[0] = x2
    pos2[1] = y2
    (context.viewport).coordinate_to_screen(pmin, pos1)
    (context.viewport).coordinate_to_screen(pmax, pos2)

    t_draw_rect_multicolor(context, drawlist, pmin[0], pmin[1], pmax[0], pmax[1],
                           col_up_left, col_up_right, col_bot_right, col_bot_left)


cdef void t_draw_textured_triangle(Context context, void* drawlist,
                                   void* texture,
                                   float x1, float y1, float x2,
                                   float y2, float x3, float y3,
                                   float u1, float v1, float u2,
                                   float v2, float u3, float v3,
                                   uint32_t tint_color) noexcept nogil:
    if tint_color == 0:
        return
    if t_item_fully_clipped(context,
                            drawlist,
                            min(x1, x2, x3),
                            max(x1, x2, x3),
                            min(y1, y2, y3),
                            max(y1, y2, y3)):
        return
    # Create imgui.ImVec2 points
    cdef imgui.ImVec2 ip1 = imgui.ImVec2(x1, y1)
    cdef imgui.ImVec2 ip2 = imgui.ImVec2(x2, y2)
    cdef imgui.ImVec2 ip3 = imgui.ImVec2(x3, y3)
    
    cdef imgui.ImVec2 uv1 = imgui.ImVec2(u1, v1)
    cdef imgui.ImVec2 uv2 = imgui.ImVec2(u2, v2)
    cdef imgui.ImVec2 uv3 = imgui.ImVec2(u3, v3)

    (<imgui.ImDrawList*>drawlist).PushTextureID(<imgui.ImTextureID>texture)

    # Draw triangle with the texture.
    # Note AA will not be available this way.
    (<imgui.ImDrawList*>drawlist).PrimReserve(3, 3)
    (<imgui.ImDrawList*>drawlist).PrimVtx(ip1, uv1, tint_color)
    (<imgui.ImDrawList*>drawlist).PrimVtx(ip2, uv2, tint_color)
    (<imgui.ImDrawList*>drawlist).PrimVtx(ip3, uv3, tint_color)

    (<imgui.ImDrawList*>drawlist).PopTextureID()


cdef void draw_textured_triangle(Context context, void* drawlist,
                                 void* texture,
                                 double x1, double y1, double x2,
                                 double y2, double x3, double y3,
                                 float u1, float v1, float u2,
                                 float v2, float u3, float v3,
                                 uint32_t tint_color) noexcept nogil:
    # Transform coordinates
    cdef float[2] p1, p2, p3
    cdef double[2] pos1, pos2, pos3
    pos1[0] = x1
    pos1[1] = y1
    pos2[0] = x2
    pos2[1] = y2
    pos3[0] = x3
    pos3[1] = y3
    (context.viewport).coordinate_to_screen(p1, pos1)
    (context.viewport).coordinate_to_screen(p2, pos2)
    (context.viewport).coordinate_to_screen(p3, pos3)

    t_draw_textured_triangle(context, drawlist, texture,
                             p1[0], p1[1], p2[0], p2[1], p3[0], p3[1],
                             u1, v1, u2, v2, u3, v3, tint_color)


cdef void t_draw_image_quad(Context context, void* drawlist,
                            void* texture,
                            float x1, float y1, float x2, float y2,
                            float x3, float y3, float x4, float y4,
                            float u1, float v1, float u2, float v2,
                            float u3, float v3, float u4, float v4,
                            uint32_t tint_color) noexcept nogil:
    if tint_color == 0:
        return
    if t_item_fully_clipped(context,
                            drawlist,
                            min(x1, x2, x3, x4),
                            max(x1, x2, x3, x4),
                            min(y1, y2, y3, y4),
                            max(y1, y2, y3, y4)):
        return
    # Create imgui.ImVec2 points
    cdef imgui.ImVec2 ip1 = imgui.ImVec2(x1, y1)
    cdef imgui.ImVec2 ip2 = imgui.ImVec2(x2, y2)
    cdef imgui.ImVec2 ip3 = imgui.ImVec2(x3, y3)
    cdef imgui.ImVec2 ip4 = imgui.ImVec2(x4, y4)
    
    cdef imgui.ImVec2 uv1 = imgui.ImVec2(u1, v1)
    cdef imgui.ImVec2 uv2 = imgui.ImVec2(u2, v2)
    cdef imgui.ImVec2 uv3 = imgui.ImVec2(u3, v3)
    cdef imgui.ImVec2 uv4 = imgui.ImVec2(u4, v4)

    (<imgui.ImDrawList*>drawlist).AddImageQuad(<imgui.ImTextureID>texture,
                                              ip1, ip2, ip3, ip4,
                                              uv1, uv2, uv3, uv4,
                                              tint_color)

cdef void draw_image_quad(Context context, void* drawlist,
                          void* texture,
                          double x1, double y1, double x2, double y2,
                          double x3, double y3, double x4, double y4,
                          float u1, float v1, float u2, float v2,
                          float u3, float v3, float u4, float v4,
                          uint32_t tint_color) noexcept nogil:
    # Transform coordinates
    cdef float[2] p1, p2, p3, p4
    cdef double[2] pos1, pos2, pos3, pos4
    pos1[0] = x1
    pos1[1] = y1
    pos2[0] = x2
    pos2[1] = y2
    pos3[0] = x3
    pos3[1] = y3
    pos4[0] = x4
    pos4[1] = y4
    (context.viewport).coordinate_to_screen(p1, pos1)
    (context.viewport).coordinate_to_screen(p2, pos2)
    (context.viewport).coordinate_to_screen(p3, pos3)
    (context.viewport).coordinate_to_screen(p4, pos4)

    t_draw_image_quad(context, drawlist, texture, p1[0], p1[1],
                      p2[0], p2[1], p3[0], p3[1], p4[0], p4[1],
                      u1, v1, u2, v2, u3, v3, u4, v4, tint_color)


cdef void t_draw_text(Context context, void* drawlist,
                      float x, float y,
                      const char* text,
                      uint32_t color,
                      void* font, float size) noexcept nogil:    
    # Create ImVec2 point
    cdef imgui.ImVec2 ipos = imgui.ImVec2(x, y)
    
    # Push font if provided
    if font != NULL:
        imgui.PushFont(<imgui.ImFont*>font)
        
    # Draw text
    if size == 0:
        (<imgui.ImDrawList*>drawlist).AddText(ipos, color, text, NULL)
    else:
        (<imgui.ImDrawList*>drawlist).AddText(NULL, fabs(size), ipos, color, text, NULL)

    # Pop font if it was pushed
    if font != NULL:
        imgui.PopFont()

cdef void draw_text(Context context, void* drawlist,
                    double x, double y,
                    const char* text,
                    uint32_t color,
                    void* font, float size) noexcept nogil:
    # Transform coordinates
    cdef float[2] pos
    cdef double[2] coord
    coord[0] = x
    coord[1] = y
    (context.viewport).coordinate_to_screen(pos, coord)
    
    t_draw_text(context, drawlist, pos[0], pos[1], text, color, font, size)

cdef Vec2 calc_text_rect(const char* text) noexcept nogil:
    """
    Calculate minimum rect size to render the target text
    by processing each character's glyph metrics individually.
    
    Args:
        context: The DearCyGui context
        text: UTF-8 encoded text to measure
        
    Returns:
        Vec2 with calculated width and height
    """
    # Push font if provided
    cdef imgui.ImFont* cur_font = imgui.GetFont()
    
    # Variables for text measurement
    cdef const char* text_end = NULL  # Process until null terminator
    cdef uint32_t c = 0
    cdef int32_t bytes_read = 0
    cdef const char* s = text
    cdef const imgui.ImFontGlyph* glyph = NULL
    
    # Result variables
    cdef float max_width = 0.0
    cdef float current_width = 0.0
    #cdef float line_y1 = 0.0
    #cdef float line_y0 = cur_font.FontSize
    cdef int num_rows = 1

    # deduce line height from the rendered characters
    while s[0] != 0:
        # Handle newline
        if s[0] == '\n':
            if s[1] != 0:
                num_rows += 1
            max_width = fmax(max_width, current_width)
            current_width = 0.0
            s += 1
            continue
        
        # Get next character and advance string pointer
        bytes_read = imgui.ImTextCharFromUtf8(&c, s, text_end)
        s += bytes_read if bytes_read > 0 else 1
        
        # Get glyph
        glyph = cur_font.FindGlyph(c)
        if glyph == NULL:
            continue

        # Add advance to width
        current_width += glyph.AdvanceX
        
        # Update line height if this glyph is taller
        #line_y1 = fmax(line_y1, glyph.Y1)
        #line_y0 = fmin(line_y0, glyph.Y0)

    cdef float line_height = cur_font.FontSize #line_y1 - line_y0 -> no to avoid moving text on update
    
    # Final width check (for text without newlines)
    max_width = fmax(max_width, current_width)
    
    # Return result
    cdef Vec2 result
    result.x = max_width
    result.y = line_height * num_rows
    return result

cdef void t_draw_text_quad(Context context, void* drawlist,
                           float x1, float y1, float x2, float y2,  
                           float x3, float y3, float x4, float y4,
                           const char* text, uint32_t color,
                           void* font, bint preserve_ratio) noexcept nogil:
    # x1/y1: top left of the text
    # x2/y2: top right of the text
    # x3/y3: bottom right of the text
    # x4/y4: bottom left of the text
    if t_item_fully_clipped(context,
                            drawlist,
                            min(x1, x2, x3, x4),
                            max(x1, x2, x3, x4),
                            min(y1, y2, y3, y4),
                            max(y1, y2, y3, y4)):
        return

    # Get draw list for low-level operations
    cdef imgui.ImDrawList* draw_list = <imgui.ImDrawList*>drawlist
    
    # Push font if provided
    cdef imgui.ImFont* cur_font
    if font != NULL:
        imgui.PushFont(<imgui.ImFont*>font)
    cur_font = imgui.GetFont()

    # Get text metrics
    cdef Vec2 text_size = calc_text_rect(text)
    cdef float total_w = text_size.x
    cdef float total_h = text_size.y
    if total_w <= 0:
        if font != NULL:
            imgui.PopFont()
        return

    # Skip if quad is too small
    if (x1 - x3) * (x1 - x3) + (y1 - y3) * (y1 - y3) < 1.0:
        if font != NULL:
            imgui.PopFont()
        return

    # normalized step in the direction of the "right" of the quad
    # x1 + total_w * dir_x_top = x2
    cdef float w_step = 1. / total_w
    cdef float dir_x_top = (x2 - x1) * w_step
    cdef float dir_y_top = (y2 - y1) * w_step
    cdef float dir_x_bottom = (x3 - x4) * w_step
    cdef float dir_y_bottom = (y3 - y4) * w_step

    # normalized step in the direction of the "up" of the quad
    cdef float h_step = 1. / total_h
    cdef float up_x_left = (x1 - x4) * h_step
    cdef float up_y_left = (y1 - y4) * h_step
    cdef float up_x_right = (x2 - x3) * h_step
    cdef float up_y_right = (y2 - y3) * h_step
    
    # Calculate starting position to center text in quad
    cdef float start_x_top = x1
    cdef float start_x_bottom = x4
    cdef float start_y_top = y1
    cdef float start_y_bottom = y4

    cdef float horiz_offset, vert_offset, quad_w, quad_h
    cdef float xc_left, xc_right, yc_top, yc_bottom
    cdef float xc_top, xc_bottom, yc_left, yc_right
    cdef float scale
    if preserve_ratio:
        # Compute quad_w/h at the middle of the original borders
        xc_left = (x1 + x4) * 0.5
        xc_right = (x2 + x3) * 0.5
        xc_top = (x1 + x2) * 0.5
        xc_bottom = (x3 + x4) * 0.5
        yc_left = (y1 + y4) * 0.5
        yc_right = (y2 + y3) * 0.5
        yc_top = (y1 + y2) * 0.5
        yc_bottom = (y3 + y4) * 0.5

        quad_w = sqrt((xc_right - xc_left) * (xc_right - xc_left) + 
                      (yc_right - yc_left) * (yc_right - yc_left))
        quad_h = sqrt((xc_top - xc_bottom) * (xc_top - xc_bottom) +
                      (yc_top - yc_bottom) * (yc_top - yc_bottom))
        # Use the minimum scale in all directions
        scale = fmin(quad_w * w_step, quad_h * h_step)

        # Deduce direction vectors
        dir_x_top = scale * (xc_right - xc_left) / quad_w
        dir_x_bottom = dir_x_top
        dir_y_top = scale * (yc_right - yc_left) / quad_w
        dir_y_bottom = dir_y_top
        up_x_left = scale * (xc_top - xc_bottom) / quad_h
        up_x_right = up_x_left
        up_y_left = scale * (yc_top - yc_bottom) / quad_h
        up_y_right = up_y_left

        # Deduce starting positions
        start_x_top = (xc_left + xc_right) * 0.5 - (0.5 * total_w) * dir_x_top + \
                      (0.5 * total_h) * up_x_left
        start_x_bottom = start_x_top - total_h * up_x_left
        start_y_top = (yc_top + yc_bottom) * 0.5 - (0.5 * total_w) * dir_y_top + \
                      (0.5 * total_h) * up_y_left
        start_y_bottom = start_y_top - total_h * up_y_left

    # Process each character
    cdef const char* text_end = NULL  # Process until null terminator
    cdef uint32_t c = 0
    cdef int32_t bytes_read = 0
    cdef const char* s = text
    cdef const imgui.ImFontGlyph* glyph = NULL
    cdef float x_top = start_x_top
    cdef float y_top = start_y_top
    cdef float x_bottom = start_x_bottom
    cdef float y_bottom = start_y_bottom
    
    # Get font texture and UV scale
    cdef imgui.ImTextureID font_tex_id = cur_font.ContainerAtlas.TexID
    cdef float c_xl, c_yt, c_xr, c_yb
    cdef imgui.ImVec2 tl, tr, br, bl
    cdef imgui.ImVec2 uv0, uv1, uv2, uv3

    cdef float o_x, o_y
    cdef float up_y, up_x
    cdef float advance_percentage = 0., advance_percentage_l, advance_percentage_r

    while s[0] != 0:
        # Get next character and advance string pointer
        bytes_read = imgui.ImTextCharFromUtf8(&c, s, text_end)
        s += bytes_read if bytes_read > 0 else 1

        # Get glyph
        glyph = cur_font.FindGlyph(c)
        if glyph == NULL:
            continue

        # Calculate vertex positions for character quad
        c_xl = glyph.X0
        c_yb = glyph.Y0
        c_xr = glyph.X1
        c_yt = glyph.Y1

        # origin position
        o_x = x_bottom
        o_y = y_bottom

        # Transform quad corners by direction vectors
        advance_percentage_l = advance_percentage + c_xl * w_step
        up_x = advance_percentage_l * up_x_right + (1.0 - advance_percentage_l) * up_x_left
        up_y = advance_percentage_l * up_y_right + (1.0 - advance_percentage_l) * up_y_left

        tl = imgui.ImVec2(
            o_x + c_xl * dir_x_top + c_yt * up_x,
            o_y + c_xl * dir_y_top + c_yt * up_y
        )
        bl = imgui.ImVec2(
            o_x + c_xl * dir_x_bottom + c_yb * up_x,
            o_y + c_xl * dir_y_bottom + c_yb * up_y
        )

        advance_percentage_r = advance_percentage + c_xr * w_step
        up_x = advance_percentage_r * up_x_right + (1.0 - advance_percentage_r) * up_x_left
        up_y = advance_percentage_r * up_y_right + (1.0 - advance_percentage_r) * up_y_left

        tr = imgui.ImVec2(
            o_x + c_xr * dir_x_top + c_yt * up_x,
            o_y + c_xr * dir_y_top + c_yt * up_y
        )
        br = imgui.ImVec2(
            o_x + c_xr * dir_x_bottom + c_yb * up_x,
            o_y + c_xr * dir_y_bottom + c_yb * up_y
        )

        # Add vertices (6 per character - 2 triangles)
        if glyph.Visible:
            # Calculate UVs
            uv0 = imgui.ImVec2(glyph.U0, glyph.V1) # top left
            uv1 = imgui.ImVec2(glyph.U1, glyph.V1) # top right
            uv2 = imgui.ImVec2(glyph.U1, glyph.V0) # bottom right
            uv3 = imgui.ImVec2(glyph.U0, glyph.V0) # bottom left

            draw_list.PrimReserve(6, 4)
            draw_list.PrimQuadUV(tl, tr, br, bl, uv0, uv1, uv2, uv3, color)

        # Advance cursor
        x_top += glyph.AdvanceX * dir_x_top
        x_bottom += glyph.AdvanceX * dir_x_bottom
        y_top += glyph.AdvanceX * dir_y_top
        y_bottom += glyph.AdvanceX * dir_y_bottom
        advance_percentage += glyph.AdvanceX * w_step

    # Pop font if pushed
    if font != NULL:
        imgui.PopFont()

cdef void draw_text_quad(Context context, void* drawlist,
                         double x1, double y1, double x2, double y2,  
                         double x3, double y3, double x4, double y4,
                         const char* text, uint32_t color,
                         void* font, bint preserve_ratio) noexcept nogil:
    # Transform coordinates
    cdef float[2] p1, p2, p3, p4
    cdef double[2] pos1, pos2, pos3, pos4
    pos1[0] = x1
    pos1[1] = y1
    pos2[0] = x2
    pos2[1] = y2
    pos3[0] = x3
    pos3[1] = y3
    pos4[0] = x4
    pos4[1] = y4
    (context.viewport).coordinate_to_screen(p1, pos1)
    (context.viewport).coordinate_to_screen(p2, pos2)
    (context.viewport).coordinate_to_screen(p3, pos3)
    (context.viewport).coordinate_to_screen(p4, pos4)

    t_draw_text_quad(context, drawlist, p1[0], p1[1],
                     p2[0], p2[1], p3[0], p3[1],
                     p4[0], p4[1], text, color, font,
                     preserve_ratio)

cdef void* get_window_drawlist(Context context) noexcept nogil:
    return <void*>imgui.GetWindowDrawList()

cdef Vec2 get_cursor_pos(Context context) noexcept nogil:
    """
    Get the current cursor position in the current window.
    Useful when drawing on top of subclassed UI items.
    To properly transform the coordinates, swap this
    with viewport's parent_pos before drawing,
    and restore parent_pos afterward.
    """
    cdef imgui.ImVec2 pos = imgui.GetCursorScreenPos()
    cdef Vec2 result
    result.x = pos.x
    result.y = pos.y
    return result

cdef void push_theme_color(Context context, int32_t idx, float r, float g, float b, float a) noexcept nogil:
    imgui.PushStyleColor(idx, imgui.ImVec4(r, g, b, a))

cdef void pop_theme_color(Context context) noexcept nogil:
    imgui.PopStyleColor(1)
    
cdef void push_theme_style_float(Context context, int32_t idx, float val) noexcept nogil:
    imgui.PushStyleVar(idx, val)

cdef void push_theme_style_vec2(Context context, int32_t idx, float x, float y) noexcept nogil:
    cdef imgui.ImVec2 val = imgui.ImVec2(x, y)
    imgui.PushStyleVar(idx, val)
    
cdef void pop_theme_style(Context context) noexcept nogil:
    imgui.PopStyleVar(1)

cdef Vec4 get_theme_color(Context context, int32_t idx) noexcept nogil:
    """Retrieve the current theme color for a target idx."""
    cdef imgui.ImVec4 color = imgui.GetStyleColorVec4(idx)
    cdef Vec4 result
    result.x = color.x
    result.y = color.y
    result.z = color.z
    result.w = color.w
    return result

cdef float get_theme_style_float(Context context, int32_t idx) noexcept nogil:
    if idx == <int>ImGuiStyleIndex.ALPHA:
        return imgui.GetStyle().Alpha
    elif idx == <int>ImGuiStyleIndex.DISABLED_ALPHA:
        return imgui.GetStyle().DisabledAlpha
    elif idx == <int>ImGuiStyleIndex.WINDOW_ROUNDING:
        return imgui.GetStyle().WindowRounding
    elif idx == <int>ImGuiStyleIndex.WINDOW_BORDER_SIZE:
        return imgui.GetStyle().WindowBorderSize
    elif idx == <int>ImGuiStyleIndex.CHILD_ROUNDING:
        return imgui.GetStyle().ChildRounding
    elif idx == <int>ImGuiStyleIndex.CHILD_BORDER_SIZE:
        return imgui.GetStyle().ChildBorderSize
    elif idx == <int>ImGuiStyleIndex.POPUP_ROUNDING:
        return imgui.GetStyle().PopupRounding
    elif idx == <int>ImGuiStyleIndex.POPUP_BORDER_SIZE:
        return imgui.GetStyle().PopupBorderSize
    elif idx == <int>ImGuiStyleIndex.FRAME_ROUNDING:
        return imgui.GetStyle().FrameRounding
    elif idx == <int>ImGuiStyleIndex.FRAME_BORDER_SIZE:
        return imgui.GetStyle().FrameBorderSize
    elif idx == <int>ImGuiStyleIndex.INDENT_SPACING:
        return imgui.GetStyle().IndentSpacing
    elif idx == <int>ImGuiStyleIndex.SCROLLBAR_SIZE:
        return imgui.GetStyle().ScrollbarSize
    elif idx == <int>ImGuiStyleIndex.SCROLLBAR_ROUNDING:
        return imgui.GetStyle().ScrollbarRounding
    elif idx == <int>ImGuiStyleIndex.GRAB_MIN_SIZE:
        return imgui.GetStyle().GrabMinSize
    elif idx == <int>ImGuiStyleIndex.GRAB_ROUNDING:
        return imgui.GetStyle().GrabRounding
    elif idx == <int>ImGuiStyleIndex.TAB_ROUNDING:
        return imgui.GetStyle().TabRounding
    elif idx == <int>ImGuiStyleIndex.TAB_BORDER_SIZE:
        return imgui.GetStyle().TabBorderSize
    elif idx == <int>ImGuiStyleIndex.TAB_BAR_BORDER_SIZE:
        return imgui.GetStyle().TabBarBorderSize
    elif idx == <int>ImGuiStyleIndex.TAB_BAR_OVERLINE_SIZE:
        return imgui.GetStyle().TabBarOverlineSize
    elif idx == <int>ImGuiStyleIndex.TABLE_ANGLED_HEADERS_ANGLE:
        return imgui.GetStyle().TableAngledHeadersAngle
    elif idx == <int>ImGuiStyleIndex.SEPARATOR_TEXT_BORDER_SIZE:
        return imgui.GetStyle().SeparatorTextBorderSize
    # For Vec2 styles, return first component
    elif idx == <int>ImGuiStyleIndex.WINDOW_PADDING:
        return imgui.GetStyle().WindowPadding.x
    elif idx == <int>ImGuiStyleIndex.WINDOW_MIN_SIZE:
        return imgui.GetStyle().WindowMinSize.x
    elif idx == <int>ImGuiStyleIndex.WINDOW_TITLE_ALIGN:
        return imgui.GetStyle().WindowTitleAlign.x
    elif idx == <int>ImGuiStyleIndex.FRAME_PADDING:
        return imgui.GetStyle().FramePadding.x
    elif idx == <int>ImGuiStyleIndex.ITEM_SPACING:
        return imgui.GetStyle().ItemSpacing.x
    elif idx == <int>ImGuiStyleIndex.ITEM_INNER_SPACING:
        return imgui.GetStyle().ItemInnerSpacing.x
    elif idx == <int>ImGuiStyleIndex.CELL_PADDING:
        return imgui.GetStyle().CellPadding.x
    elif idx == <int>ImGuiStyleIndex.TABLE_ANGLED_HEADERS_TEXT_ALIGN:
        return imgui.GetStyle().TableAngledHeadersTextAlign.x
    elif idx == <int>ImGuiStyleIndex.BUTTON_TEXT_ALIGN:
        return imgui.GetStyle().ButtonTextAlign.x
    elif idx == <int>ImGuiStyleIndex.SELECTABLE_TEXT_ALIGN:
        return imgui.GetStyle().SelectableTextAlign.x
    elif idx == <int>ImGuiStyleIndex.SEPARATOR_TEXT_ALIGN:
        return imgui.GetStyle().SeparatorTextAlign.x
    elif idx == <int>ImGuiStyleIndex.SEPARATOR_TEXT_PADDING:
        return imgui.GetStyle().SeparatorTextPadding.x
    else:
        # Fallback for unhandled indices
        return 0.0

cdef Vec2 get_theme_style_vec2(Context context, int32_t idx) noexcept nogil:
    if idx == <int>ImGuiStyleIndex.WINDOW_PADDING:
        return ImVec2Vec2(imgui.GetStyle().WindowPadding)
    elif idx == <int>ImGuiStyleIndex.WINDOW_MIN_SIZE:
        return ImVec2Vec2(imgui.GetStyle().WindowMinSize)
    elif idx == <int>ImGuiStyleIndex.WINDOW_TITLE_ALIGN:
        return ImVec2Vec2(imgui.GetStyle().WindowTitleAlign)
    elif idx == <int>ImGuiStyleIndex.FRAME_PADDING:
        return ImVec2Vec2(imgui.GetStyle().FramePadding)
    elif idx == <int>ImGuiStyleIndex.ITEM_SPACING:
        return ImVec2Vec2(imgui.GetStyle().ItemSpacing)
    elif idx == <int>ImGuiStyleIndex.ITEM_INNER_SPACING:
        return ImVec2Vec2(imgui.GetStyle().ItemInnerSpacing)
    elif idx == <int>ImGuiStyleIndex.CELL_PADDING:
        return ImVec2Vec2(imgui.GetStyle().CellPadding)
    elif idx == <int>ImGuiStyleIndex.TABLE_ANGLED_HEADERS_TEXT_ALIGN:
        return ImVec2Vec2(imgui.GetStyle().TableAngledHeadersTextAlign)
    elif idx == <int>ImGuiStyleIndex.BUTTON_TEXT_ALIGN:
        return ImVec2Vec2(imgui.GetStyle().ButtonTextAlign)
    elif idx == <int>ImGuiStyleIndex.SELECTABLE_TEXT_ALIGN:
        return ImVec2Vec2(imgui.GetStyle().SelectableTextAlign)
    elif idx == <int>ImGuiStyleIndex.SEPARATOR_TEXT_ALIGN:
        return ImVec2Vec2(imgui.GetStyle().SeparatorTextAlign)
    elif idx == <int>ImGuiStyleIndex.SEPARATOR_TEXT_PADDING:
        return ImVec2Vec2(imgui.GetStyle().SeparatorTextPadding)
    else:
        # For non-Vec2 styles or unhandled indices, return zero vector
        return Vec2(0.0, 0.0)

cdef Vec2 calc_text_size(Context context, const char* text, void* font, float size, float wrap_width) noexcept nogil:
    # Push font if provided
    if font != NULL:
        imgui.PushFont(<imgui.ImFont*>font)

    # Calculate text size
    cdef imgui.ImVec2 text_size
    cdef imgui.ImFont* cur_font
    cdef float scale
    if size == 0:
        text_size = imgui.CalcTextSize(text, NULL, False, wrap_width)
    else:
        # Get current font and scale it
        cur_font = imgui.GetFont()
        scale = fabs(size) / cur_font.FontSize
        text_size = imgui.CalcTextSize(text, NULL, False, wrap_width)
        text_size.x *= scale
        text_size.y *= scale
    
    # Pop font if it was pushed
    if font != NULL:
        imgui.PopFont()

    # Convert to Vec2
    cdef Vec2 result
    result.x = text_size.x
    result.y = text_size.y
    return result

cdef GlyphInfo get_glyph_info(Context context, void* font, uint32_t codepoint) noexcept nogil:
    # Get font
    cdef imgui.ImFont* cur_font
    if font != NULL:
        cur_font = <imgui.ImFont*>font 
    else:
        cur_font = imgui.GetFont()

    # Find glyph
    cdef const imgui.ImFontGlyph* glyph = cur_font.FindGlyph(codepoint)
    
    # Pack info into result struct
    cdef GlyphInfo result
    if glyph == NULL:
        # Return empty metrics for missing glyphs
        result.advance_x = 0
        result.size_x = 0
        result.size_y = 0
        result.u0 = 0
        result.v0 = 0
        result.u1 = 0
        result.v1 = 0
        result.offset_x = 0
        result.offset_y = 0
        result.visible = False
    else:
        result.advance_x = glyph.AdvanceX
        result.size_x = glyph.X1 - glyph.X0
        result.size_y = glyph.Y1 - glyph.Y0
        result.u0 = glyph.U0
        result.v0 = glyph.V0
        result.u1 = glyph.U1
        result.v1 = glyph.V1
        result.offset_x = glyph.X0
        result.offset_y = glyph.Y0
        result.visible = glyph.Visible != 0
        
    return result