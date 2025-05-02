from libc.math cimport M_PI
from libcpp.algorithm cimport swap
from libcpp.cmath cimport sin, cos, sqrt, atan2, pow, fmod

from .core cimport Context
from .c_types cimport DCGVector
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


cdef void _draw_compute_normals(float* normals,
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

    # Inverse normals length
    for i in range(points_count):
        dx = normals[2*i]
        dy = normals[2*i+1]
        d_len = dx*dx + dy*dy
        if d_len > 1e-3:
            normals[2*i] = dx / d_len
            normals[2*i+1] = dy / d_len
        elif d_len < 1e-8:
            normals[2*i] = 0.0 # This will result in no AA fringe, but it's better than an artifact
            normals[2*i+1] = 0.0
        else:
            # Use trigonometry for precision in near-degenerate cases
            edge_angle = atan2(dy, dx)
            normals[2*i] = sin(edge_angle) * 100. # clampling 1/d_len to 1./min_valid_len2
            normals[2*i+1] = -cos(edge_angle) * 100.


cdef void _draw_polygon_outline(void* drawlist_ptr,
                                const float* points,
                                int points_count,
                                const float* normals,
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
    cdef imgui.ImVec2 uv = imgui.GetFontTexUvWhitePixel()
    cdef imgui.ImU32 color_trans = color & ~imgui.IM_COL32_A_MASK
    cdef float AA_SIZE = draw_list._FringeScale
    

    cdef bint thick_line = thickness > 1.0

    # Apply alpha scaling for thickness < 1.0
    cdef uint32_t alpha
    cdef float alpha_scale
    if thickness < 1.0:
        # Extract current alpha value
        alpha = (color >> 24) & 0xFF
        
        # Apply power function with exponent 0.7 (smoother transition than linear)
        # This keeps thin lines more visible while still fading appropriately
        alpha_scale = pow(max(thickness, 0.), 0.7)
        
        # Modify alpha channel while preserving RGB
        alpha = <uint32_t>(alpha * alpha_scale)
        if alpha == 0:
            # Nothing to draw
            return
        color = (color & 0x00FFFFFF) | (alpha << 24)
    
    # Compute normals for each edge with improved precision handling
    cdef int i0, i1
    # Reserve space for vertices and indices
    cdef int vtx_count, idx_count
    
    if thick_line:
        vtx_count = points_count * 4  # 4 vertices per point for thick AA lines 
        idx_count = (points_count - 1) * 18  # 6 triangles (18 indices) per line segment
        if closed and points_count > 2:
            idx_count += 18  # Add space for the closing segment
    else:
        vtx_count = points_count * 3  # 3 vertices per point (center + 2 AA edges)
        idx_count = (points_count - 1) * 12  # 4 triangles (12 indices) per line segment
        if closed and points_count > 2:
            idx_count += 12  # Add space for the closing segment
    
    draw_list.PrimReserve(idx_count, vtx_count)
    
    cdef unsigned int vtx_base_idx = draw_list._VtxCurrentIdx
    cdef unsigned int idx0, idx1
    cdef float half_inner_thickness
    cdef float dm_x, dm_y, fringe_x, fringe_y
    
    if thick_line:
        # Thick anti-aliased lines implementation
        half_inner_thickness = (thickness - AA_SIZE) * 0.5
        
        for i0 in range(points_count):
            dm_x = normals[2*i0]
            dm_y = normals[2*i0+1]
            
            # Calculate vertex positions for thick line with AA fringe
            # Inner vertices (closer to center line)
            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] + dm_x * half_inner_thickness, 
                             points[2*i0+1] + dm_y * half_inner_thickness),
                uv, <imgui.ImU32>color  # Inner edge, full color
            )
            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] - dm_x * half_inner_thickness, 
                             points[2*i0+1] - dm_y * half_inner_thickness),
                uv, <imgui.ImU32>color  # Inner edge, full color
            )
            
            # Outer vertices (with AA fringe)
            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] + dm_x * (half_inner_thickness + AA_SIZE),
                             points[2*i0+1] + dm_y * (half_inner_thickness + AA_SIZE)),
                uv, <imgui.ImU32>color_trans  # Outer edge, transparent
            )
            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] - dm_x * (half_inner_thickness + AA_SIZE),
                             points[2*i0+1] - dm_y * (half_inner_thickness + AA_SIZE)),
                uv, <imgui.ImU32>color_trans  # Outer edge, transparent
            )

        for i0 in range(points_count):
            i1 = i0 + 1
            if i1 == points_count:  # Wrap to start for closed line
                i1 = 0

            # Add indices for thick line segment (only between valid points)
            if i0 < points_count - 1 or (closed and points_count > 2):
                idx0 = vtx_base_idx + i0 * 4
                idx1 = vtx_base_idx + i1 * 4
                
                # Inner rectangle
                draw_list.PrimWriteIdx(idx0 + 1)
                draw_list.PrimWriteIdx(idx1 + 1)
                draw_list.PrimWriteIdx(idx1 + 0)
                
                draw_list.PrimWriteIdx(idx0 + 1)
                draw_list.PrimWriteIdx(idx1 + 0)
                draw_list.PrimWriteIdx(idx0 + 0)
                
                # Upper AA fringe
                draw_list.PrimWriteIdx(idx0 + 0)
                draw_list.PrimWriteIdx(idx1 + 0)
                draw_list.PrimWriteIdx(idx1 + 2)
                
                draw_list.PrimWriteIdx(idx0 + 0)
                draw_list.PrimWriteIdx(idx1 + 2)
                draw_list.PrimWriteIdx(idx0 + 2)
                
                # Lower AA fringe
                draw_list.PrimWriteIdx(idx0 + 1)
                draw_list.PrimWriteIdx(idx1 + 3)
                draw_list.PrimWriteIdx(idx1 + 1)
                
                draw_list.PrimWriteIdx(idx0 + 1)
                draw_list.PrimWriteIdx(idx0 + 3)
                draw_list.PrimWriteIdx(idx1 + 3)
    else:
        # Thin anti-aliased lines implementation
        for i0 in range(points_count):
            dm_x = normals[2*i0]
            dm_y = normals[2*i0+1]
                
            # Center vertex
            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0], points[2*i0+1]),
                uv, 
                <imgui.ImU32>color  # Center, full color
            )
            
            # Edge vertices with AA fringe
            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] + dm_x * AA_SIZE,
                            points[2*i0+1] + dm_y * AA_SIZE),
                uv, <imgui.ImU32>color_trans  # Edge, transparent
            )
            draw_list.PrimWriteVtx(
                imgui.ImVec2(points[2*i0] - dm_x * AA_SIZE,
                            points[2*i0+1] - dm_y * AA_SIZE),
                uv, <imgui.ImU32>color_trans  # Edge, transparent
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


cdef void _draw_polygon_filling(void* drawlist_ptr,
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
        
    # Add vertices and fringe triangles
    for i0 in range(points_count):
        i1 = (i0 + 1) % points_count
        
        # Average normals for smoother AA
        dm_x = normals[2*i0]
        dm_y = normals[2*i0+1]
        if flip_normals:
            dm_x = -dm_x
            dm_y = -dm_y
        
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

cdef void t_draw_polygon(Context context,
                         void* drawlist_ptr,
                         const float* points,
                         int points_count,
                         const float* inner_points,
                         int inner_points_count,
                         const uint32_t* indices,
                         int indices_count, 
                         uint32_t fill_color,
                         uint32_t outline_color,
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
        fill_color: Color to fill the polygon with (ImU32)
        outline_color: Color for the polygon outline (ImU32)
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
    _draw_compute_normals(context.viewport.temp_normals.data(),
                          points, points_count, True)

    # Render the filling
    _draw_polygon_filling(drawlist_ptr,
                          points,
                          points_count,
                          context.viewport.temp_normals.data(),
                          inner_points,
                          inner_points_count,
                          indices,
                          indices_count,
                          fill_color)

    # Render the outline
    _draw_polygon_outline(drawlist_ptr,
                          points,
                          points_count,
                          context.viewport.temp_normals.data(),
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
                       uint32_t fill_color,
                       uint32_t outline_color,
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
        fill_color,
        outline_color,
        thickness
    )

cdef void t_draw_polyline(Context context,
                          void* drawlist_ptr,
                          const float* points,
                          int points_count,
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

    _draw_compute_normals(context.viewport.temp_normals.data(),
                          points, points_count, closed)

    _draw_polygon_outline(drawlist_ptr,
                          points,
                          points_count,
                          context.viewport.temp_normals.data(),
                          color,
                          thickness,
                          closed)

cdef void draw_polyline(Context context,
                        void* drawlist,
                        const double* points,
                        int points_count,
                        uint32_t color,
                        bint closed,
                        float thickness) noexcept nogil:
    cdef int i
    cdef DCGVector[float] *ipoints = &context.viewport.temp_point_coords

    if points_count < 2:
        return

    if 2 * points_count < ipoints.size():
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
        color,
        closed,
        thickness
    )

cdef void t_draw_line(Context context, void* drawlist,
                      float x1, float y1, float x2, float y2,
                      uint32_t color, float thickness) noexcept nogil:
    cdef float[4] coords = [x1, y1, x2, y2]

    if t_item_fully_clipped(context,
                            drawlist,
                            min(x1, x2) - thickness,
                            max(x1, x2) + thickness,
                            min(y1, y2) - thickness,
                            max(y1, y2) + thickness):
        return

    t_draw_polyline(context,
                   drawlist,
                   coords,
                   2,
                   color,
                   False,
                   thickness)

cdef void draw_line(Context context, void* drawlist,
                    double x1, double y1, double x2, double y2,
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

    t_draw_line(context, drawlist, p1[0], p1[1], p2[0], p2[1], color, thickness)

cdef void t_draw_triangle(Context context, void* drawlist,
                          float x1, float y1, float x2, float y2, float x3, float y3,
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
                   fill_color,
                   color,
                   thickness)

cdef void draw_triangle(Context context, void* drawlist,
                       double x1, double y1, double x2, double y2, double x3, double y3,
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
                    color, fill_color, thickness)

# We use AddRect as it supports rounding
cdef void t_draw_rect(Context context, void* drawlist,
                      float x1, float y1, float x2, float y2,
                      uint32_t color, uint32_t fill_color,
                      float thickness, float rounding) noexcept nogil:
    if t_item_fully_clipped(context,
                            drawlist,
                            min(x1, x2) - thickness,
                            max(x1, x2) + thickness,
                            min(y1, y2) - thickness,
                            max(y1, y2) + thickness):
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
                color, fill_color, thickness, rounding)


cdef void t_draw_quad(Context context, void* drawlist,
                    float x1, float y1, float x2, float y2,
                    float x3, float y3, float x4, float y4, 
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
                   fill_color,
                   color,
                   thickness)


cdef void draw_quad(Context context, void* drawlist,
                    double x1, double y1, double x2, double y2,
                    double x3, double y3, double x4, double y4, 
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
                color, fill_color, thickness)


# We use AddCircle as it does the computation of the points for us
cdef void t_draw_circle(Context context, void* drawlist,
                      float x, float y, float radius,
                      uint32_t color, uint32_t fill_color,
                      float thickness, int32_t num_segments) noexcept nogil:
    radius = abs(radius)
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
                      uint32_t color, uint32_t fill_color,
                      float thickness, int32_t num_segments) noexcept nogil:
    # Transform coordinates
    cdef float[2] center
    cdef double[2] pos
    pos[0] = x
    pos[1] = y
    (context.viewport).coordinate_to_screen(center, pos)

    t_draw_circle(context, drawlist, center[0], center[1], radius, color, fill_color, thickness, num_segments)


cdef void t_draw_regular_polygon(Context context, void* drawlist,
                                 float centerx, float centery,
                                 float radius, float direction,  
                                 int32_t num_points,
                                 uint32_t color, uint32_t fill_color,
                                 float thickness) noexcept nogil:
    radius = abs(radius)
    direction = fmod(direction, M_PI * 2.) # Doing so increases precision

    if num_points <= 1:
        # Draw circle instead
        t_draw_circle(context, drawlist, centerx, centery, radius,
                   color, fill_color, thickness, 0)
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
        fill_color,
        color,
        thickness
    )


cdef void draw_regular_polygon(Context context, void* drawlist,
                             double centerx, double centery,
                             double radius, double direction,  
                             int32_t num_points,
                             uint32_t color, uint32_t fill_color,
                             float thickness) noexcept nogil:
    cdef float[2] center
    cdef double[2] pos
    pos[0] = centerx 
    pos[1] = centery
    (context.viewport).coordinate_to_screen(center, pos)

    t_draw_regular_polygon(context, drawlist, center[0], center[1],
                           radius, direction, num_points, color,
                           fill_color, thickness)


cdef void t_draw_star(Context context, void* drawlist,
                      float centerx, float centery, 
                      float radius, float inner_radius,
                      float direction, int32_t num_points,
                      uint32_t color, uint32_t fill_color,
                      float thickness) noexcept nogil:

    if num_points < 3:
        # Draw circle instead for degenerate cases
        t_draw_circle(context, drawlist, centerx, centery, radius,
                      color, fill_color, thickness, 0)
        return
    
    radius = abs(radius)
    inner_radius = min(radius, abs(inner_radius))
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
                t_draw_line(context, drawlist, px1, py1, px2, py2, color, thickness)
        else:
            # Draw lines to center for odd number of points
            for i in range(num_points):
                angle = -direction + i * (2.0 * M_PI / num_points)
                px = centerx + radius * cos(angle)
                py = centery + radius * sin(angle)
                t_draw_line(context, drawlist, px, py, centerx, centery, color, thickness)
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
        fill_color,
        color,
        thickness
    )


cdef void draw_star(Context context, void* drawlist,
                    double centerx, double centery, 
                    double radius, double inner_radius,
                    double direction, int32_t num_points,
                    uint32_t color, uint32_t fill_color,
                    float thickness) noexcept nogil:
    # Transform center coordinates
    cdef float[2] center
    cdef double[2] pos
    pos[0] = centerx
    pos[1] = centery
    (context.viewport).coordinate_to_screen(center, pos)

    t_draw_star(context, drawlist, center[0], center[1], radius, inner_radius,
                direction, num_points, color, fill_color, thickness)


cdef void t_draw_rect_multicolor(Context context, void* drawlist,
                                 float x1, float y1, float x2, float y2,
                                 uint32_t col_up_left, uint32_t col_up_right, 
                                 uint32_t col_bot_right, uint32_t col_bot_left) noexcept nogil:

    if t_item_fully_clipped(context,
                            drawlist,
                            min(x1, x2),
                            max(x1, x2),
                            min(y1, y2),
                            max(y1, y2)):
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
                                   float x1, float y1, float x2, float y2, float x3, float y3,
                                   float u1, float v1, float u2, float v2, float u3, float v3,
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
                                double x1, double y1, double x2, double y2, double x3, double y3,
                                float u1, float v1, float u2, float v2, float u3, float v3,
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
        (<imgui.ImDrawList*>drawlist).AddText(NULL, abs(size), ipos, color, text, NULL)

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

cdef void t_draw_text_quad(Context context, void* drawlist,
                         float x1, float y1, float x2, float y2,  
                         float x3, float y3, float x4, float y4,
                         const char* text, uint32_t color,
                         void* font, bint preserve_ratio) noexcept nogil:
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
    cdef imgui.ImVec2 text_size = imgui.CalcTextSize(text)
    cdef float total_w = text_size.x
    cdef float total_h = text_size.y
    if total_w <= 0:
        if font != NULL:
            imgui.PopFont()
        return

    # Calculate normalized direction vectors for quad
    cdef float quad_w = sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
    cdef float quad_h = sqrt((x4 - x1) * (x4 - x1) + (y4 - y1) * (y4 - y1))
    
    # Skip if quad is too small
    if quad_w < 1.0 or quad_h < 1.0:
        if font != NULL:
            imgui.PopFont()
        return

    cdef float dir_x = (x2 - x1) / quad_w
    cdef float dir_y = (y2 - y1) / quad_w
    cdef float up_x = (x4 - x1) / quad_h  
    cdef float up_y = (y4 - y1) / quad_h

    # Calculate scale 
    cdef float scale_x = quad_w / total_w
    cdef float scale_y = quad_h / total_h
    cdef float scale = min(scale_x, scale_y) if preserve_ratio else 1.0
    
    # Calculate starting position to center text in quad
    cdef float start_x = x1
    cdef float start_y = y1
    if preserve_ratio:
        start_x += (quad_w - total_w * scale) * 0.5 * dir_x + (quad_h - total_h * scale) * 0.5 * up_x
        start_y += (quad_w - total_w * scale) * 0.5 * dir_y + (quad_h - total_h * scale) * 0.5 * up_y

    # Process each character
    cdef const char* text_end = NULL  # Process until null terminator
    cdef uint32_t c = 0
    cdef int32_t bytes_read = 0
    cdef const char* s = text
    cdef const imgui.ImFontGlyph* glyph = NULL
    cdef float char_width
    cdef float x = start_x
    cdef float y = start_y
    
    # Get font texture and UV scale
    cdef imgui.ImTextureID font_tex_id = cur_font.ContainerAtlas.TexID
    cdef float tex_uvscale_x = 1.0 / cur_font.ContainerAtlas.TexWidth
    cdef float tex_uvscale_y = 1.0 / cur_font.ContainerAtlas.TexHeight
    cdef float c_x0, c_y0, c_x1, c_y1
    cdef imgui.ImVec2 tl, tr, br, bl
    cdef imgui.ImVec2 uv0, uv1, uv2, uv3

    while s[0] != 0:
        # Get next character and advance string pointer
        bytes_read = imgui.ImTextCharFromUtf8(&c, s, text_end)
        s += bytes_read if bytes_read > 0 else 1

        # Get glyph
        glyph = cur_font.FindGlyph(c)
        if glyph == NULL:
            continue

        # Skip glyphs with no pixels
        if glyph.Visible == 0:
            continue

        # Calculate character quad size and UVs 
        char_width = glyph.AdvanceX * scale

        # Calculate vertex positions for character quad
        c_x0 = x + glyph.X0 * scale
        c_y0 = y + glyph.Y0 * scale
        c_x1 = x + glyph.X1 * scale 
        c_y1 = y + glyph.Y1 * scale

        # Transform quad corners by direction vectors
        tl = imgui.ImVec2(
            c_x0 * dir_x + c_y0 * up_x,
            c_x0 * dir_y + c_y0 * up_y
        )
        tr = imgui.ImVec2(
            c_x1 * dir_x + c_y0 * up_x,
            c_x1 * dir_y + c_y0 * up_y
        )
        br = imgui.ImVec2(
            c_x1 * dir_x + c_y1 * up_x,
            c_x1 * dir_y + c_y1 * up_y
        )
        bl = imgui.ImVec2(
            c_x0 * dir_x + c_y1 * up_x,
            c_x0 * dir_y + c_y1 * up_y
        )

        # Calculate UVs
        uv0 = imgui.ImVec2(glyph.U0, glyph.V0)
        uv1 = imgui.ImVec2(glyph.U1, glyph.V0)
        uv2 = imgui.ImVec2(glyph.U1, glyph.V1)
        uv3 = imgui.ImVec2(glyph.U0, glyph.V1)

        # Add vertices (6 per character - 2 triangles)
        draw_list.PrimReserve(6, 4)
        draw_list.PrimQuadUV(tl, tr, br, bl, uv0, uv1, uv2, uv3, color)

        # Advance cursor
        x += char_width * dir_x
        y += char_width * dir_y

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

    t_draw_text_quad(context, drawlist, pos1[0], pos1[1],
                     pos2[0], pos2[1], pos3[0], pos3[1],
                     pos4[0], pos4[1], text, color, font,
                     preserve_ratio)

cdef void* get_window_drawlist() noexcept nogil:
    return <void*>imgui.GetWindowDrawList()

cdef Vec2 get_cursor_pos() noexcept nogil:
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

cdef void push_theme_color(int32_t idx, float r, float g, float b, float a) noexcept nogil:
    imgui.PushStyleColor(idx, imgui.ImVec4(r, g, b, a))

cdef void pop_theme_color() noexcept nogil:
    imgui.PopStyleColor(1)
    
cdef void push_theme_style_float(int32_t idx, float val) noexcept nogil:
    imgui.PushStyleVar(idx, val)

cdef void push_theme_style_vec2(int32_t idx, float x, float y) noexcept nogil:
    cdef imgui.ImVec2 val = imgui.ImVec2(x, y)
    imgui.PushStyleVar(idx, val)
    
cdef void pop_theme_style() noexcept nogil:
    imgui.PopStyleVar(1)

cdef Vec4 get_theme_color(int32_t idx) noexcept nogil:
    """Retrieve the current theme color for a target idx."""
    cdef imgui.ImVec4 color = imgui.GetStyleColorVec4(idx)
    cdef Vec4 result
    result.x = color.x
    result.y = color.y
    result.z = color.z
    result.w = color.w
    return result

cdef Vec2 calc_text_size(const char* text, void* font, float size, float wrap_width) noexcept nogil:
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
        scale = abs(size) / cur_font.FontSize
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

cdef GlyphInfo get_glyph_info(void* font, uint32_t codepoint) noexcept nogil:
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