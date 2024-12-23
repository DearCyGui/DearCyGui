from .core cimport drawingItem, Texture, baseFont, SharedValue
from .c_types cimport double2, float2

from libcpp.string cimport string
from libcpp.vector cimport vector

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
    cdef float _start_angle
    cdef float _end_angle
    cdef float _rotation
    cdef float _thickness
    cdef unsigned int _color # imgui.ImU32
    cdef unsigned int _fill # imgui.ImU32

cdef class DrawArrow(drawingItem):
    cdef double[2] _start
    cdef double[2] _end
    cdef double[2] _corner1
    cdef double[2] _corner2
    cdef unsigned int _color # imgui.ImU32
    cdef float _thickness
    cdef float _size
    cdef void draw(self, void*) noexcept nogil
    cdef void __compute_tip(self)

cdef class DrawBezierCubic(drawingItem):
    cdef double[2] _p1
    cdef double[2] _p2
    cdef double[2] _p3
    cdef double[2] _p4
    cdef unsigned int _color # imgui.ImU32
    cdef float _thickness
    cdef int _segments
    cdef void draw(self, void*) noexcept nogil

cdef class DrawBezierQuadratic(drawingItem):
    cdef double[2] _p1
    cdef double[2] _p2
    cdef double[2] _p3
    cdef unsigned int _color # imgui.ImU32
    cdef float _thickness
    cdef int _segments
    cdef void draw(self, void*) noexcept nogil

cdef class DrawCircle(drawingItem):
    cdef double[2] _center
    cdef float _radius
    cdef unsigned int _color # imgui.ImU32
    cdef unsigned int _fill # imgui.ImU32
    cdef float _thickness
    cdef int _segments
    cdef void draw(self, void*) noexcept nogil

cdef class DrawEllipse(drawingItem):
    cdef double[2] _pmin
    cdef double[2] _pmax
    cdef unsigned int _color # imgui.ImU32
    cdef unsigned int _fill # imgui.ImU32
    cdef float _thickness
    cdef int _segments
    cdef vector[double2] _points
    cdef void __fill_points(self)
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
    cdef unsigned int _color_multiplier # imgui.ImU32
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
    cdef unsigned int _color # imgui.ImU32
    cdef float _thickness
    cdef void update_center(self) noexcept nogil
    cdef void update_extremities(self) noexcept nogil
    cdef void draw(self, void*) noexcept nogil

cdef class DrawPolyline(drawingItem):
    cdef unsigned int _color # imgui.ImU32
    cdef float _thickness
    cdef bint _closed
    cdef vector[double2] _points
    cdef void draw(self, void*) noexcept nogil

cdef class DrawPolygon(drawingItem):
    cdef unsigned int _color # imgui.ImU32
    cdef unsigned int _fill # imgui.ImU32
    cdef float _thickness
    cdef vector[double2] _points
    cdef int[:,:] _triangulation_indices
    cdef void __triangulate(self)
    cdef void draw(self, void*) noexcept nogil

cdef class DrawQuad(drawingItem):
    cdef double[2] _p1
    cdef double[2] _p2
    cdef double[2] _p3
    cdef double[2] _p4
    cdef unsigned int _color # imgui.ImU32
    cdef unsigned int _fill # imgui.ImU32
    cdef float _thickness
    cdef void draw(self, void*) noexcept nogil

cdef class DrawRect(drawingItem):
    cdef double[2] _pmin
    cdef double[2] _pmax
    cdef unsigned int _color # imgui.ImU32
    cdef unsigned int _color_upper_left # imgui.ImU32
    cdef unsigned int _color_upper_right # imgui.ImU32
    cdef unsigned int _color_bottom_left # imgui.ImU32
    cdef unsigned int _color_bottom_right # imgui.ImU32
    cdef unsigned int _fill # imgui.ImU32
    cdef float _rounding
    cdef float _thickness
    cdef bint _multicolor
    cdef void draw(self, void*) noexcept nogil

cdef class DrawRegularPolygon(drawingItem):
    cdef double[2] _center
    cdef float _radius
    cdef double _direction
    cdef unsigned int _color # imgui.ImU32
    cdef unsigned int _fill # imgui.ImU32
    cdef float _thickness
    cdef int _num_points
    cdef vector[float2] _points
    cdef bint _dirty
    cdef void draw(self, void*) noexcept nogil

cdef class DrawStar(drawingItem):
    cdef double[2] _center
    cdef float _radius
    cdef float _inner_radius
    cdef double _direction
    cdef unsigned int _color # imgui.ImU32
    cdef unsigned int _fill # imgui.ImU32
    cdef float _thickness
    cdef int _num_points
    cdef vector[float2] _points
    cdef vector[float2] _inner_points
    cdef bint _dirty
    cdef void draw(self, void*) noexcept nogil

cdef class DrawText(drawingItem):
    cdef double[2] _pos
    cdef string _text
    cdef unsigned int _color # imgui.ImU32
    cdef float _size
    cdef baseFont _font
    cdef void draw(self, void*) noexcept nogil

cdef class DrawTriangle(drawingItem):
    cdef double[2] _p1
    cdef double[2] _p2
    cdef double[2] _p3
    cdef unsigned int _color # imgui.ImU32
    cdef unsigned int _fill # imgui.ImU32
    cdef float _thickness
    cdef void draw(self, void*) noexcept nogil

cdef class DrawValue(drawingItem):
    cdef char[256] buffer
    cdef double[2] _pos
    cdef string _print_format
    cdef unsigned int _color  # imgui.ImU32
    cdef int _type
    cdef float _size
    cdef baseFont _font
    cdef SharedValue _value
    cdef void draw(self, void*) noexcept nogil