from libcpp.vector cimport vector

# Since Delaunator provides a non-nullary constructor,
# we need to wrap it, thus why we provide a wrapper function
# instead of the class

cdef extern from * nogil:
    """
    #include "delaunator.hpp"

    inline std::vector<std::size_t> delaunator_get_triangles(const std::vector<double>& coords) {
        delaunator::Delaunator d(coords);
        return d.triangles;
    }
    """
    vector[size_t] delaunator_get_triangles(const vector[double]& coords) except +