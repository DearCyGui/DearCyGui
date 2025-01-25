from dearcygui.wrapper cimport imgui, implot
from .core cimport Context
from .c_types cimport *

from libcpp.algorithm cimport swap
from libcpp.vector cimport vector
from libcpp.cmath cimport atan, atan2, sin, cos, sqrt, trunc, floor, round as cround
from libc.math cimport M_PI, INFINITY

cdef void t_draw_line(Context context, void* drawlist,
                    float x1, float y1, float x2, float y2,
                    uint32_t color, float thickness) noexcept nogil:
    # Create imgui.ImVec2 points
    cdef imgui.ImVec2 ip1 = imgui.ImVec2(x1, y1)
    cdef imgui.ImVec2 ip2 = imgui.ImVec2(x2, y2) 

    (<imgui.ImDrawList*>drawlist).AddLine(ip1, ip2, color, thickness)

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

cdef void t_draw_rect(Context context, void* drawlist,
                      float x1, float y1, float x2, float y2,
                      uint32_t color, uint32_t fill_color,
                      float thickness, float rounding) noexcept nogil:
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

cdef void t_draw_rect_multicolor(Context context, void* drawlist,
                                 float x1, float y1, float x2, float y2,
                                 uint32_t col_up_left, uint32_t col_up_right, 
                                 uint32_t col_bot_right, uint32_t col_bot_left) noexcept nogil:

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

cdef void t_draw_triangle(Context context, void* drawlist,
                          float x1, float y1, float x2, float y2, float x3, float y3,
                          uint32_t color, uint32_t fill_color,
                          float thickness) noexcept nogil:
    # Create imgui.ImVec2 points
    cdef imgui.ImVec2 ip1 = imgui.ImVec2(x1, y1)
    cdef imgui.ImVec2 ip2 = imgui.ImVec2(x2, y2)
    cdef imgui.ImVec2 ip3 = imgui.ImVec2(x3, y3)

    # Check ordering
    cdef bint ccw = (ip2.x - ip1.x) * (ip3.y - ip1.y) - (ip2.y - ip1.y) * (ip3.x - ip1.x) > 0

    # ImGui requires clockwise order for correct AA
    if ccw:
        if fill_color & imgui.IM_COL32_A_MASK != 0:
            (<imgui.ImDrawList*>drawlist).AddTriangleFilled(ip1, ip3, ip2, fill_color)
        if color & imgui.IM_COL32_A_MASK != 0:
            (<imgui.ImDrawList*>drawlist).AddTriangle(ip1, ip3, ip2, color, thickness)
    else:
        if fill_color & imgui.IM_COL32_A_MASK != 0:
            (<imgui.ImDrawList*>drawlist).AddTriangleFilled(ip1, ip2, ip3, fill_color)
        if color & imgui.IM_COL32_A_MASK != 0:
            (<imgui.ImDrawList*>drawlist).AddTriangle(ip1, ip2, ip3, color, thickness)

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

cdef void t_draw_textured_triangle(Context context, void* drawlist,
                                  void* texture,
                                  float x1, float y1, float x2, float y2, float x3, float y3,
                                  float u1, float v1, float u2, float v2, float u3, float v3,
                                  uint32_t tint_color) noexcept nogil:
    if tint_color == 0:
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

cdef void t_draw_quad(Context context, void* drawlist,
                    float x1, float y1, float x2, float y2,
                    float x3, float y3, float x4, float y4, 
                    uint32_t color, uint32_t fill_color,
                    float thickness) noexcept nogil:
    # Create imgui.ImVec2 points
    cdef imgui.ImVec2 ip1 = imgui.ImVec2(x1, y1)
    cdef imgui.ImVec2 ip2 = imgui.ImVec2(x2, y2)
    cdef imgui.ImVec2 ip3 = imgui.ImVec2(x3, y3)
    cdef imgui.ImVec2 ip4 = imgui.ImVec2(x4, y4)
    cdef bint ccw

    # Draw filled triangles
    if fill_color & imgui.IM_COL32_A_MASK != 0:
        ccw = (ip2.x - ip1.x) * (ip3.y - ip1.y) - (ip2.y - ip1.y) * (ip3.x - ip1.x) > 0
        if ccw:
            (<imgui.ImDrawList*>drawlist).AddTriangleFilled(ip1, ip3, ip2, fill_color)
        else:
            (<imgui.ImDrawList*>drawlist).AddTriangleFilled(ip1, ip2, ip3, fill_color)
            
        ccw = (ip1.x - ip4.x) * (ip3.y - ip4.y) - (ip1.y - ip4.y) * (ip3.x - ip4.x) > 0
        if ccw:
            (<imgui.ImDrawList*>drawlist).AddTriangleFilled(ip1, ip3, ip4, fill_color)
        else:
            (<imgui.ImDrawList*>drawlist).AddTriangleFilled(ip1, ip4, ip3, fill_color)

    # Draw outline
    (<imgui.ImDrawList*>drawlist).AddLine(ip1, ip2, color, thickness)
    (<imgui.ImDrawList*>drawlist).AddLine(ip2, ip3, color, thickness)
    (<imgui.ImDrawList*>drawlist).AddLine(ip3, ip4, color, thickness)
    (<imgui.ImDrawList*>drawlist).AddLine(ip4, ip1, color, thickness)

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

cdef void t_draw_circle(Context context, void* drawlist,
                      float x, float y, float radius,
                      uint32_t color, uint32_t fill_color,
                      float thickness, int32_t num_segments) noexcept nogil:
    # Create imgui.ImVec2 point
    cdef imgui.ImVec2 icenter = imgui.ImVec2(x, y)
    radius = abs(radius)
    
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

cdef void t_draw_image_quad(Context context, void* drawlist,
                         void* texture,
                         float x1, float y1, float x2, float y2,
                         float x3, float y3, float x4, float y4,
                         float u1, float v1, float u2, float v2,
                         float u3, float v3, float u4, float v4,
                         uint32_t tint_color) noexcept nogil:
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

cdef void t_draw_regular_polygon(Context context, void* drawlist,
                                 float centerx, float centery,
                                 float radius, float direction,  
                                 int32_t num_points,
                                 uint32_t color, uint32_t fill_color,
                                 float thickness) noexcept nogil:

    if num_points <= 1:
        # Draw circle instead
        t_draw_circle(context, drawlist, centerx, centery, radius,
                   color, fill_color, thickness, 0)
        return

    cdef imgui.ImVec2 icenter = imgui.ImVec2(centerx, centery)
    cdef vector[imgui.ImVec2] points
    points.reserve(num_points)

    radius = abs(radius)
    
    cdef float angle
    cdef float angle_step = 2.0 * M_PI / num_points
    cdef float px, py
    cdef int32_t i
    
    for i in range(num_points):
        angle = -direction + i * angle_step  # Negative direction for y-up coords
        px = centerx + radius * cos(angle)
        py = centery + radius * sin(angle)
        points.push_back(imgui.ImVec2(px, py))

    if num_points == 2:
        # Draw line instead
        (<imgui.ImDrawList*>drawlist).AddLine(points[0], points[1], color, thickness)
        return

    # Draw fill
    if fill_color & imgui.IM_COL32_A_MASK != 0:
        (<imgui.ImDrawList*>drawlist).AddConvexPolyFilled(
            points.data(),
            num_points,
            fill_color)

    # Draw outline - connect points with lines
    if color & imgui.IM_COL32_A_MASK != 0:
        (<imgui.ImDrawList*>drawlist).AddPolyline(
            points.data(), 
            num_points,
            color,
            imgui.ImDrawFlags_Closed,
            thickness)

cdef void draw_regular_polygon(Context context, void* drawlist,
                             double centerx, double centery,
                             double radius, double direction,  
                             int32_t num_points,
                             uint32_t color, uint32_t fill_color,
                             float thickness) noexcept nogil:

    if num_points <= 1:
        # Draw circle instead
        draw_circle(context, drawlist, centerx, centery, radius,
                   color, fill_color, thickness, 0)
        return

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

    # Generate points
    cdef vector[imgui.ImVec2] outer_points
    cdef vector[imgui.ImVec2] inner_points
    outer_points.reserve(num_points)
    inner_points.reserve(num_points)
    
    cdef double angle, inner_angle
    cdef double angle_step = M_PI / num_points
    cdef float px, py
    cdef imgui.ImVec2 pt
    cdef int32_t i
    
    # Generate outer and inner points alternating
    for i in range(num_points * 2):
        if i % 2 == 0:
            # Outer point
            angle = -direction + i * angle_step
            px = centerx + radius * cos(angle) 
            py = centery + radius * sin(angle)
            pt = imgui.ImVec2(px, py)
            outer_points.push_back(pt)
        else:
            # Inner point on circle
            angle = -direction + i * angle_step
            px = centerx + inner_radius * cos(angle)
            py = centery + inner_radius * sin(angle)
            pt = imgui.ImVec2(px, py)
            inner_points.push_back(pt)

    if inner_radius == 0.:
        if num_points % 2 == 0:
            for i in range(num_points//2):
                (<imgui.ImDrawList*>drawlist).AddLine(outer_points[i], outer_points[i+num_points//2], <imgui.ImU32>color, thickness)
        else:
            for i in range(num_points):
                (<imgui.ImDrawList*>drawlist).AddLine(outer_points[i], imgui.ImVec2(centerx, centery), <imgui.ImU32>color, thickness)
        return

    if fill_color & imgui.IM_COL32_A_MASK != 0:
        # fill inner region
        (<imgui.ImDrawList*>drawlist).AddConvexPolyFilled(inner_points.data(), <int>inner_points.size(), <imgui.ImU32>fill_color)
        # fill the rest
        for i in range(num_points-1):
            (<imgui.ImDrawList*>drawlist).AddTriangleFilled(outer_points[i],
                                        inner_points[i],
                                        inner_points[i+1],
                                        fill_color)
        (<imgui.ImDrawList*>drawlist).AddTriangleFilled(outer_points[num_points-1],
                                    inner_points[num_points-1],
                                    inner_points[0],
                                    fill_color)

    if color == 0:
        return

    for i in range(num_points-1):
        (<imgui.ImDrawList*>drawlist).AddLine(outer_points[i], inner_points[i], <imgui.ImU32>color, thickness)
        (<imgui.ImDrawList*>drawlist).AddLine(outer_points[i], inner_points[i+1], <imgui.ImU32>color, thickness)
    (<imgui.ImDrawList*>drawlist).AddLine(outer_points[num_points-1], inner_points[num_points-1], <imgui.ImU32>color, thickness)
    (<imgui.ImDrawList*>drawlist).AddLine(outer_points[num_points-1], inner_points[0], <imgui.ImU32>color, thickness)


cdef void draw_star(Context context, void* drawlist,
                    double centerx, double centery, 
                    double radius, double inner_radius,
                    double direction, int32_t num_points,
                    uint32_t color, uint32_t fill_color,
                    float thickness) noexcept nogil:

    if num_points < 3:
        # Draw circle instead for degenerate cases
        draw_circle(context, drawlist, centerx, centery, radius,
                   color, fill_color, thickness, 0)
        return

    # Transform center coordinates
    cdef float[2] center
    cdef double[2] pos
    pos[0] = centerx
    pos[1] = centery
    (context.viewport).coordinate_to_screen(center, pos)

    t_draw_star(context, drawlist, center[0], center[1], radius, inner_radius,
                direction, num_points, color, fill_color, thickness)

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