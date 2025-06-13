from .core cimport drawingItem, baseFont, SharedValue
from .c_types cimport double2, float2, DCGVector, DCGString
from .texture cimport Texture, Pattern

from libc.stdint cimport uint32_t, int32_t

cdef class ViewportDrawList(drawingItem):
    cdef bint _front
    cdef void draw(self, void*) noexcept nogil

cdef class DrawingList(drawingItem):
    pass

cdef class DrawingClip(drawingItem):
    cdef double[2] _pmin
    cdef double[2] _pmax
    cdef float _scale_min
    cdef float _scale_max
    cdef bint _no_global_scale
    cdef void draw(self, void*) noexcept nogil

cdef class DrawingScale(drawingItem):
    cdef double[2] _scales
    cdef double[2] _shifts
    cdef bint _no_parent_scale
    cdef bint _no_global_scale
    cdef void draw(self, void*) noexcept nogil

cdef class DrawSplitBatch(drawingItem):
    cdef void draw(self, void*) noexcept nogil

cdef class DrawArc(drawingItem):
    cdef double[2] _center
    cdef double[2] _radius
    cdef double[2] _inner_radius
    cdef float _start_angle
    cdef float _end_angle
    cdef float _rotation
    cdef float _thickness
    cdef int32_t _segments
    cdef Pattern _pattern
    cdef uint32_t _color # imgui.ImU32
    cdef uint32_t _fill # imgui.ImU32

cdef class DrawArrow(drawingItem):
    cdef double[2] _start
    cdef double[2] _end
    cdef double[2] _corner1
    cdef double[2] _corner2
    cdef Pattern _pattern
    cdef uint32_t _color # imgui.ImU32
    cdef float _thickness
    cdef float _size
    cdef void draw(self, void*) noexcept nogil
    cdef void __compute_tip(self)

cdef class DrawBezierCubic(drawingItem):
    cdef double[2] _p1
    cdef double[2] _p2
    cdef double[2] _p3
    cdef double[2] _p4
    cdef Pattern _pattern
    cdef uint32_t _color # imgui.ImU32
    cdef float _thickness
    cdef int32_t _segments
    cdef void draw(self, void*) noexcept nogil

cdef class DrawBezierQuadratic(drawingItem):
    cdef double[2] _p1
    cdef double[2] _p2
    cdef double[2] _p3
    cdef Pattern _pattern
    cdef uint32_t _color # imgui.ImU32
    cdef float _thickness
    cdef int32_t _segments
    cdef void draw(self, void*) noexcept nogil

cdef class DrawCircle(drawingItem):
    cdef double[2] _center
    cdef float _radius
    cdef Pattern _pattern
    cdef uint32_t _color # imgui.ImU32
    cdef uint32_t _fill # imgui.ImU32
    cdef float _thickness
    cdef int32_t _segments
    cdef void draw(self, void*) noexcept nogil

cdef class DrawEllipse(drawingItem):
    cdef double[2] _pmin
    cdef double[2] _pmax
    cdef Pattern _pattern
    cdef uint32_t _color # imgui.ImU32
    cdef uint32_t _fill # imgui.ImU32
    cdef float _thickness
    cdef int32_t _segments
    cdef void draw(self, void*) noexcept nogil

cdef class DrawImage(drawingItem):
    cdef double[2] _p1
    cdef double[2] _p2
    cdef double[2] _p3
    cdef double[2] _p4
    cdef double[2] _center
    cdef double _direction
    cdef double _height
    cdef double _width
    cdef float[2] _uv1
    cdef float[2] _uv2
    cdef float[2] _uv3
    cdef float[2] _uv4
    cdef float _rounding
    cdef uint32_t _color_multiplier # imgui.ImU32
    cdef Texture _texture
    cdef void update_center(self) noexcept nogil
    cdef void update_extremities(self) noexcept nogil
    cdef void draw(self, void*) noexcept nogil

cdef class DrawLine(drawingItem):
    cdef double[2] _p1
    cdef double[2] _p2
    cdef double[2] _center
    cdef double _length
    cdef double _direction
    cdef Pattern _pattern
    cdef uint32_t _color # imgui.ImU32
    cdef float _thickness
    cdef void update_center(self) noexcept nogil
    cdef void update_extremities(self) noexcept nogil
    cdef void draw(self, void*) noexcept nogil

cdef class DrawPolyline(drawingItem):
    cdef Pattern _pattern
    cdef uint32_t _color # imgui.ImU32
    cdef float _thickness
    cdef bint _closed
    cdef DCGVector[double2] _points
    cdef void draw(self, void*) noexcept nogil

cdef class DrawPolygon(drawingItem):
    cdef Pattern _pattern
    cdef uint32_t _color # imgui.ImU32
    cdef uint32_t _fill # imgui.ImU32
    cdef float _thickness
    cdef bint _hull
    cdef DCGVector[double2] _points
    cdef DCGVector[uint32_t] _hull_triangulation
    cdef DCGVector[uint32_t] _polygon_triangulation
    cdef DCGVector[uint32_t] _hull_indices
    cdef bint _constrained_success
    cdef void _triangulate(self)
    cdef void draw(self, void*) noexcept nogil

cdef class DrawQuad(drawingItem):
    cdef double[2] _p1
    cdef double[2] _p2
    cdef double[2] _p3
    cdef double[2] _p4
    cdef Pattern _pattern
    cdef uint32_t _color # imgui.ImU32
    cdef uint32_t _fill # imgui.ImU32
    cdef float _thickness
    cdef void draw(self, void*) noexcept nogil

cdef class DrawRect(drawingItem):
    cdef double[2] _pmin
    cdef double[2] _pmax
    cdef Pattern _pattern
    cdef uint32_t _color # imgui.ImU32
    cdef uint32_t _color_upper_left # imgui.ImU32
    cdef uint32_t _color_upper_right # imgui.ImU32
    cdef uint32_t _color_bottom_left # imgui.ImU32
    cdef uint32_t _color_bottom_right # imgui.ImU32
    cdef uint32_t _fill # imgui.ImU32
    cdef float _rounding
    cdef float _thickness
    cdef bint _multicolor
    cdef void draw(self, void*) noexcept nogil

cdef class DrawRegularPolygon(drawingItem):
    cdef double[2] _center
    cdef float _radius
    cdef double _direction
    cdef Pattern _pattern
    cdef uint32_t _color # imgui.ImU32
    cdef uint32_t _fill # imgui.ImU32
    cdef float _thickness
    cdef int32_t _num_points
    cdef void draw(self, void*) noexcept nogil

cdef class DrawStar(drawingItem):
    cdef double[2] _center
    cdef float _radius
    cdef float _inner_radius
    cdef double _direction
    cdef Pattern _pattern
    cdef uint32_t _color # imgui.ImU32
    cdef uint32_t _fill # imgui.ImU32
    cdef float _thickness
    cdef int32_t _num_points
    cdef DCGVector[float2] _points
    cdef void draw(self, void*) noexcept nogil

cdef class DrawText(drawingItem):
    cdef double[2] _pos
    cdef DCGString _text
    cdef uint32_t _color # imgui.ImU32
    cdef float _size
    cdef baseFont _font
    cdef void draw(self, void*) noexcept nogil

cdef class DrawTextQuad(drawingItem):
    cdef double[2] _p1
    cdef double[2] _p2
    cdef double[2] _p3
    cdef double[2] _p4
    cdef DCGString _text
    cdef uint32_t _color # imgui.ImU32
    cdef bint _preserve_ratio
    cdef baseFont _font

cdef class DrawTriangle(drawingItem):
    cdef double[2] _p1
    cdef double[2] _p2
    cdef double[2] _p3
    cdef Pattern _pattern
    cdef uint32_t _color # imgui.ImU32
    cdef uint32_t _fill # imgui.ImU32
    cdef float _thickness
    cdef void draw(self, void*) noexcept nogil

cdef class DrawValue(drawingItem):
    cdef char[256] buffer
    cdef double[2] _pos
    cdef DCGString _print_format
    cdef uint32_t _color  # imgui.ImU32
    cdef int32_t _type
    cdef float _size
    cdef baseFont _font
    cdef SharedValue _value
    cdef void draw(self, void*) noexcept nogil