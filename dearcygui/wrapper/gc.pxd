
from cpython.ref cimport PyObject

cdef extern from "Python.h":
    ctypedef struct PyGC_Head:
        pass

    # GC interface
    int PyGC_Enable()
    int PyGC_Disable()
    int PyGC_IsEnabled()
    Py_ssize_t PyGC_Collect()

    # GC tracking interface
    void PyObject_GC_Track(object op)
    void PyObject_GC_UnTrack(object op)
    
    # GC information
    int PyObject_IS_GC(object obj)
