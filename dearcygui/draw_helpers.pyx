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

from libc.math cimport M_PI, sqrt, sin, cos, fabs, fmod, fmax, fmin, ceil

from .c_types cimport DCGVector

cdef void generate_bezier_cubic_points(DCGVector[float]& points,
                                       DCGVector[float]& normals,
                                       float x1, float y1,
                                       float x2, float y2,
                                       float x3, float y3,
                                       float x4, float y4,
                                       int num_segments) noexcept nogil:
    """
    Generate the points of a cubic Bezier curve, from (x1, y1) to (x4, y4).
    """
    cdef int i
    cdef float t, u, w1, w2, w3, w4, tx, ty, tlen2, inv_len
    cdef float a_x, a_y, b_x, b_y, second_derivative

    if num_segments <= 0:
        # Chord error of a segment is at most M / (8 n^2) with M a bound on |B''|
        a_x = x1 - 2. * x2 + x3
        a_y = y1 - 2. * y2 + y3
        b_x = x2 - 2. * x3 + x4
        b_y = y2 - 2. * y3 + y4
        second_derivative = 6. * fmax(sqrt(a_x * a_x + a_y * a_y),
                                      sqrt(b_x * b_x + b_y * b_y))
        # 0.2 pixel tolerance: n = sqrt(M / (8 * 0.2))
        num_segments = <int>ceil(sqrt(second_derivative * 0.625))
        num_segments = min(max(3, num_segments), 200)

    points.reserve(points.size() + 2 * (num_segments + 1))
    normals.reserve(normals.size() + 2 * (num_segments + 1))

    for i in range(num_segments + 1):
        t = <float>i / num_segments
        u = 1. - t
        w1 = u * u * u
        w2 = 3. * u * u * t
        w3 = 3. * u * t * t
        w4 = t * t * t
        points.push_back(w1 * x1 + w2 * x2 + w3 * x3 + w4 * x4)
        points.push_back(w1 * y1 + w2 * y2 + w3 * y3 + w4 * y4)

        # Tangent: B'(t) / 3
        tx = u * u * (x2 - x1) + 2. * u * t * (x3 - x2) + t * t * (x4 - x3)
        ty = u * u * (y2 - y1) + 2. * u * t * (y3 - y2) + t * t * (y4 - y3)
        tlen2 = tx * tx + ty * ty
        if tlen2 < 1e-12:
            # Coincident control points zero the tangent at an end: use the chord
            tx = x4 - x1
            ty = y4 - y1
            tlen2 = tx * tx + ty * ty
        if tlen2 < 1e-12:
            normals.push_back(0.)
            normals.push_back(0.)
        else:
            inv_len = 1. / sqrt(tlen2)
            normals.push_back(ty * inv_len)
            normals.push_back(-tx * inv_len)


cdef void generate_bezier_quadratic_points(DCGVector[float]& points,
                                           DCGVector[float]& normals,
                                           float x1, float y1,
                                           float x2, float y2,
                                           float x3, float y3,
                                           int num_segments) noexcept nogil:
    """
    Generate the points of a quadratic Bezier curve, from (x1, y1) to (x3, y3).
    """
    cdef int i
    cdef float t, u, w1, w2, w3, tx, ty, tlen2, inv_len
    cdef float a_x, a_y, second_derivative

    if num_segments <= 0:
        # |B''| = 2 |p1 - 2 p2 + p3|, chord error <= |B''| / (8 n^2), 0.2 pixel tolerance
        a_x = x1 - 2. * x2 + x3
        a_y = y1 - 2. * y2 + y3
        second_derivative = 2. * sqrt(a_x * a_x + a_y * a_y)
        num_segments = <int>ceil(sqrt(second_derivative * 0.625))
        num_segments = min(max(3, num_segments), 200)

    points.reserve(points.size() + 2 * (num_segments + 1))
    normals.reserve(normals.size() + 2 * (num_segments + 1))

    for i in range(num_segments + 1):
        t = <float>i / num_segments
        u = 1. - t
        w1 = u * u
        w2 = 2. * u * t
        w3 = t * t
        points.push_back(w1 * x1 + w2 * x2 + w3 * x3)
        points.push_back(w1 * y1 + w2 * y2 + w3 * y3)

        # Tangent: B'(t) / 2
        tx = u * (x2 - x1) + t * (x3 - x2)
        ty = u * (y2 - y1) + t * (y3 - y2)
        tlen2 = tx * tx + ty * ty
        if tlen2 < 1e-12:
            # Coincident control points zero the tangent at an end: use the chord
            tx = x3 - x1
            ty = y3 - y1
            tlen2 = tx * tx + ty * ty
        if tlen2 < 1e-12:
            normals.push_back(0.)
            normals.push_back(0.)
        else:
            inv_len = 1. / sqrt(tlen2)
            normals.push_back(ty * inv_len)
            normals.push_back(-tx * inv_len)


cdef int compute_ellipse_num_segments(float radiusx,
                                      float radiusy,
                                      float start_angle,
                                      float end_angle) noexcept nogil:
    """
    Compute the number of segments needed to approximate an ellipse.
    
    Args:
        radiusx: Major radius of the ellipse
        radiusy: Minor radius of the ellipse
        angle: Angle in radians
    
    Returns:
        Number of segments needed for the approximation.
    """
    # Normalize angle range to [0, 2π]
    cdef float angle_range = fabs(end_angle - start_angle)

    if angle_range > 2 * M_PI:
        angle_range = 2 * M_PI
        
    # Base segment count calculation
    # Quality heuristic: larger radius and more eccentric ellipses need more segments
    cdef float max_radius = max(radiusx, radiusy)
    cdef float min_radius = max(min(radiusx, radiusy), 0.1)  # Avoid division by zero
    
    # Calculate eccentricity factor (more eccentric = more segments needed)
    cdef float aspect_ratio = max_radius / min_radius
    cdef float eccentricity_factor = min(5., sqrt(aspect_ratio))
    
    # Base count based on the maximum radius (similar to circle calculation)
    cdef float base_segments = 8 + 4 * sqrt(max_radius)
    
    # Scale by angle coverage (partial arcs need fewer segments)
    cdef float angle_factor = angle_range / (2 * M_PI)
    
    # Final segment count
    cdef int num_segments = <int>(base_segments * angle_factor * eccentricity_factor + 0.5)
    
    # Ensure minimum number of segments
    num_segments = min(max(3, num_segments), 200)
    return num_segments

cdef extern from * nogil:
    """
#include <xsimd/xsimd.hpp>
#include <cmath>
#include <algorithm>
#include <cstring>

template <typename T>
inline void process_elliptical_arc_batch(
    T* points_data,
    T* normals_data,
    std::size_t point_offset,
    std::size_t count,
    T centerx,
    T centery,
    T radiusx,
    T radiusy,
    T cos_rotation,
    T sin_rotation,
    T start_angle,
    T angle_step,
    bool inner_normals
) {
    using batch_type = xsimd::batch<T>;
    
    // Load angles into a batch
    constexpr std::size_t batch_size = batch_type::size;
    alignas(batch_type) T angles_for_index[batch_size];
    for (std::size_t i = 0; i < batch_size; ++i) {
        angles_for_index[i] = start_angle + i * angle_step;
    }

    batch_type angles = batch_type::load_aligned(angles_for_index);
    
    // Calculate sin/cos of angles
    auto trig = xsimd::sincos(angles);
    batch_type sin_angles = trig.first;   // sine values
    batch_type cos_angles = trig.second;  // cosine values
    
    // Generate ellipse points
    batch_type x = cos_angles * radiusx;
    batch_type y = sin_angles * radiusy;
    
    // Apply rotation
    batch_type rotated_x = x * cos_rotation - y * sin_rotation;
    batch_type rotated_y = x * sin_rotation + y * cos_rotation;
    
    // Apply translation
    batch_type final_x = centerx + rotated_x;
    batch_type final_y = centery + rotated_y;
    
    // Prepare output pointer
    T* batch_start = points_data + point_offset;
    
    // Interleave x,y coordinates using SIMD zip operations
    batch_type zipped_lo = xsimd::zip_lo(final_x, final_y);
    zipped_lo.store_unaligned(batch_start);
    
    batch_type zipped_hi = xsimd::zip_hi(final_x, final_y);
    zipped_hi.store_unaligned(batch_start + count);

    // Compute normals
    // For an ellipse, the normal vector can be calculated analytically:
    // nx = (-rx*sin(t)*sin(theta) + ry*cos(t)*cos(theta))
    // ny = (rx*sin(t)*cos(theta) + ry*cos(t)*sin(theta))
    // (need to normalize afterward)

    // Calculate unnormalized normal components
    batch_type nx = radiusx * sin_angles * sin_rotation - radiusy * cos_angles * cos_rotation;
    batch_type ny = -radiusx * sin_angles * cos_rotation - radiusy * cos_angles * sin_rotation;

    // Adjust normals based on inner_normals flag
    if (inner_normals) {
        nx = -nx;
        ny = -ny;
    }

    // Calculate length for normalization
    batch_type nx_squared = nx * nx;
    batch_type ny_squared = ny * ny;
    batch_type length_squared = nx_squared + ny_squared;

    // Safely normalize (handle near-zero cases)
    batch_type very_small = batch_type(1e-8f);
    auto is_valid = length_squared > very_small;

    // Normalize normals
    // This doesn't exactly match the scaling in _draw_compute_normals
    // But in the case of arcs, the difference is small.
    batch_type inv_length = xsimd::select(is_valid,
                                          xsimd::rsqrt(length_squared),
                                          batch_type(0.0f));

    // Apply correct scaling (1/length instead of 1/sqrt(length))
    nx = nx * inv_length;
    ny = ny * inv_length;

    // Store normalized normals
    T* normal_batch_start = normals_data + point_offset;

    // Interleave and store normal x,y coordinates
    batch_type normal_zipped_lo = xsimd::zip_lo(nx, ny);
    normal_zipped_lo.store_unaligned(normal_batch_start);

    batch_type normal_zipped_hi = xsimd::zip_hi(nx, ny);
    normal_zipped_hi.store_unaligned(normal_batch_start + batch_size);
}

template <typename T>
void fast_generate_elliptical_arc_points(
    T* points_data,
    T* normals_data,
    int num_points,
    T centerx,
    T centery,
    T radiusx,
    T radiusy,
    T cos_rotation,
    T sin_rotation,
    T start_angle,
    T angle_step,
    bool inner_normals
) {
    using batch_type = xsimd::batch<T>;
    constexpr std::size_t batch_size = batch_type::size;
    
    // Number of full batches
    const std::size_t n_full_batches = num_points / batch_size;
    // Remaining points after processing full batches
    const std::size_t remainder = num_points % batch_size;
    
    // Process batches
    for (std::size_t batch_idx = 0; batch_idx < n_full_batches; ++batch_idx) {
        // Process this batch
        process_elliptical_arc_batch(
            points_data,
            normals_data,
            batch_idx * batch_size * 2,
            batch_size,
            centerx,
            centery,
            radiusx,
            radiusy,
            cos_rotation,
            sin_rotation,
            start_angle + batch_idx * batch_size * angle_step,
            angle_step,
            inner_normals
        );
    }
    
    // Process remaining points
    if (remainder > 0) {
        const size_t remain_offset = n_full_batches * batch_size;
        
        // Process the remainder using the same function (but with temp buffer)
        alignas(batch_type) T temp_buffer_points[batch_size * 2];
        alignas(batch_type) T temp_buffer_normals[batch_size * 2];
        
        // Use the same processing function
        process_elliptical_arc_batch(
            temp_buffer_points,
            temp_buffer_normals,
            0,  // Starting at beginning of temp buffer
            batch_size,
            centerx,
            centery,
            radiusx,
            radiusy,
            cos_rotation,
            sin_rotation,
            start_angle + n_full_batches * batch_size * angle_step,
            angle_step,
            inner_normals
        );
        
        // Copy only the needed values from temp buffer to the final destination
        for (std::size_t i = 0; i < remainder; ++i) {
            points_data[(remain_offset + i) * 2] = temp_buffer_points[i * 2];
            points_data[(remain_offset + i) * 2 + 1] = temp_buffer_points[i * 2 + 1];
            normals_data[(remain_offset + i) * 2] = temp_buffer_normals[i * 2];
            normals_data[(remain_offset + i) * 2 + 1] = temp_buffer_normals[i * 2 + 1];
        }
    }
}

// Explicit instantiation for float
template void fast_generate_elliptical_arc_points<float>(
    float*, float*, int, float, float, float, float, float, float, float, float, bool
);

    """
    cdef void fast_generate_elliptical_arc_points(
        float* points_data,
        float* normals_data,
        int num_points,
        float centerx,
        float centery,
        float radiusx,
        float radiusy,
        float cos_rotation,
        float sin_rotation,
        float start_angle,
        float angle_step,
        bint inner_normals
    ) noexcept

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
                                         bint inner_normals) noexcept nogil:
    """
    Generate points for an elliptical arc.
    
    Args:
        points: Output vector to store generated points
        normals: Output vector to store scaled normals
        centerx, centery: Center of the ellipse
        radiusx, radiusy: Major and minor radii of the ellipse
        rotation: Rotation of the ellipse in radians
        start_angle, end_angle: Start and end angles in radians
        num_segments: Number of segments to generate (if ≤ 0, automatically calculated)
        normals_sign: If True the normals points towards the center the arc instead of the outside.
    
    The start_angle and end_angle parameters are in the ellipse's own coordinate
    system before rotation is applied.
    """
    # Handle degenerate cases
    if radiusx <= 0 or radiusy <= 0:
        return

    # Calculate appropriate number of segments if not specified
    if num_segments <= 0:
        num_segments = compute_ellipse_num_segments(
            radiusx, radiusy, start_angle, end_angle
        )

    # Pre-compute rotation factors
    rotation = fmod(rotation, 2 * M_PI) # improves precision
    cdef float cos_rotation = cos(rotation)
    cdef float sin_rotation = sin(rotation)

    # Calculate angle increment
    cdef float range = end_angle - start_angle
    if fabs(range) > 2 * M_PI:
        range = 2 * M_PI if range > 0 else -2 * M_PI
    if fabs(range) < 1e-3:
        range = 1e-3 # Avoid artifacts due to several identical points
    cdef float angle_step = range / num_segments
    start_angle = fmod(start_angle, 2 * M_PI)

    # Reserve capacity to avoid reallocations
    cdef int initial_size_points = points.size()
    cdef int initial_size_normals = normals.size()
    points.resize(initial_size_points + (num_segments + 1) * 2)
    normals.resize(initial_size_normals + (num_segments + 1) * 2)
    cdef float *data = points.data()
    cdef float *normals_data = normals.data()

    cdef int i
    cdef float angle, x, y, rotated_x, rotated_y

    """
    Non-SIMD version for reference:
    # Generate points using parametric equation of ellipse with rotation
    for i in range(num_segments + 1):
        angle = start_angle + i * angle_step

        # Ellipse point before rotation (in ellipse's own coordinate system)
        x = cos(angle) * radiusx
        y = sin(angle) * radiusy

        # Apply rotation transform
        rotated_x = x * cos_rotation - y * sin_rotation
        rotated_y = x * sin_rotation + y * cos_rotation

        # Add point with translation to center
        data[initial_size + i * 2] = centerx + rotated_x
        data[initial_size + i * 2 + 1] = centery + rotated_y
    """
    # Generate points using SIMD for performance
    fast_generate_elliptical_arc_points(
        data + initial_size_points,
        normals_data + initial_size_normals,
        num_segments + 1,
        centerx,
        centery,
        radiusx,
        radiusy,
        cos_rotation,
        sin_rotation,
        start_angle,
        angle_step,
        inner_normals
    )

cdef void generate_rect_points(DCGVector[float]& points,
                               DCGVector[float]& normals,
                               float x1, float y1,
                               float x2, float y2,
                               float rounding,
                               int num_segments) noexcept nogil:
    """
    Generate the outline points of a (possibly rounded) axis-aligned rectangle.
    """
    cdef float sx = 1. if x2 >= x1 else -1.
    cdef float sy = 1. if y2 >= y1 else -1.
    # Mirrored paths have the opposite winding, hence opposite normals
    cdef float flip = sx * sy
    cdef int corner, i
    cdef float cx, cy, ax, ay, bx, by, t, dx, dy

    # Clamp the rounding to half of the minimum dimension of the rectangle to avoid overlapping corners
    rounding = fmin(rounding, 0.5 * fmin(fabs(x2 - x1), fabs(y2 - y1)))

    # Fast path for rectangles with negligible or no rounding
    if rounding < 0.5:
        points.resize(8)
        normals.resize(8)
        points[0] = x1; points[1] = y1
        points[2] = x2; points[3] = y1
        points[4] = x2; points[5] = y2
        points[6] = x1; points[7] = y2
        # Miter normals of 90 degree corners
        normals[0] = -sx * flip; normals[1] = -sy * flip
        normals[2] = sx * flip; normals[3] = -sy * flip
        normals[4] = sx * flip; normals[5] = sy * flip
        normals[6] = -sx * flip; normals[7] = sy * flip
        return

    # Deduce the number of segments for the rounded corners if not specified
    if num_segments <= 0:
        num_segments = compute_ellipse_num_segments(rounding, rounding, 0., M_PI / 2.)

    # Clear the points and normals vectors and reserve space for the rounded corners
    points.clear()
    normals.clear()
    points.reserve(8 * (num_segments + 1))
    normals.reserve(8 * (num_segments + 1))

    # Generate the points for each rounded corner of the rectangle
    for corner in range(4):
        # Arc center, and the outward directions of the incoming (a) and outgoing (b) edges
        # (x1, y1)
        if corner == 0:
            cx = x1 + sx * rounding; cy = y1 + sy * rounding
            ax = -sx; ay = 0.; bx = 0.; by = -sy
        # (x2, y1)
        elif corner == 1:
            cx = x2 - sx * rounding; cy = y1 + sy * rounding
            ax = 0.; ay = -sy; bx = sx; by = 0.
        # (x2, y2)
        elif corner == 2:
            cx = x2 - sx * rounding; cy = y2 - sy * rounding
            ax = sx; ay = 0.; bx = 0.; by = sy
        # (x1, y2)
        else:
            cx = x1 + sx * rounding; cy = y2 - sy * rounding
            ax = 0.; ay = sy; bx = -sx; by = 0.
        # Generate the points along the arc for the current corner
        for i in range(num_segments + 1):
            t = (0.5 * M_PI) * i / num_segments
            dx = ax * cos(t) + bx * sin(t)
            dy = ay * cos(t) + by * sin(t)
            points.push_back(cx + dx * rounding)
            points.push_back(cy + dy * rounding)
            normals.push_back(dx * flip)
            normals.push_back(dy * flip)