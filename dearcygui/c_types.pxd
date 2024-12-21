cdef extern from * nogil:
    """
    struct float2 {
        float p[2];
    };
    typedef struct float2 float2;
    struct Vec2 {
        float x;
        float y;
    };
    typedef struct Vec2 Vec2;
    struct Vec4 {
        float x;
        float y;
        float z;
        float w;
    };
    typedef struct Vec4 Vec4;
    struct double2 {
        double p[2];
    };
    typedef struct double2 double2;
    """
    ctypedef struct float2:
        float[2] p
    ctypedef struct Vec2:
        float x
        float y
    ctypedef struct Vec4:
        float x
        float y
        float z
        float w
    ctypedef struct double2:
        double[2] p

cdef inline Vec2 make_Vec2(float x, float y) noexcept nogil:
    cdef Vec2 v
    v.x = x
    v.y = y
    return v

cdef inline void swap_Vec2(Vec2 &a, Vec2 &b) noexcept nogil:
    cdef float x, y
    x = a.x
    y = a.y
    a.x = b.x
    a.y = b.y
    b.x = x
    b.y = y

# generated with pxdgen /usr/include/c++/11/mutex -x c++

cdef extern from "<mutex>" namespace "std" nogil:
    cppclass mutex:
        mutex()
        mutex(mutex&)
        mutex& operator=(mutex&)
        void lock()
        bint try_lock()
        void unlock()
    cppclass __condvar:
        __condvar()
        __condvar(__condvar&)
        __condvar& operator=(__condvar&)
        void wait(mutex&)
        #void wait_until(mutex&, timespec&)
        #void wait_until(mutex&, clockid_t, timespec&)
        void notify_one()
        void notify_all()
    cppclass defer_lock_t:
        defer_lock_t()
    cppclass try_to_lock_t:
        try_to_lock_t()
    cppclass adopt_lock_t:
        adopt_lock_t()
    cppclass recursive_mutex:
        recursive_mutex()
        recursive_mutex(recursive_mutex&)
        recursive_mutex& operator=(recursive_mutex&)
        void lock()
        bint try_lock()
        void unlock()
    #int try_lock[_Lock1, _Lock2, _Lock3](_Lock1&, _Lock2&, _Lock3 &...)
    #void lock[_L1, _L2, _L3](_L1&, _L2&, _L3 &...)
    cppclass lock_guard[_Mutex]:
        ctypedef _Mutex mutex_type
        lock_guard(mutex_type&)
        lock_guard(mutex_type&, adopt_lock_t)
        lock_guard(lock_guard&)
        lock_guard& operator=(lock_guard&)
    cppclass scoped_lock[_MutexTypes]:
        #scoped_lock(_MutexTypes &..., ...)
        scoped_lock()
        scoped_lock(_MutexTypes &)
        #scoped_lock(adopt_lock_t, _MutexTypes &...)
        #scoped_lock(scoped_lock&)
        scoped_lock& operator=(scoped_lock&)
    cppclass unique_lock[_Mutex]:
        ctypedef _Mutex mutex_type
        unique_lock()
        unique_lock(mutex_type&)
        unique_lock(mutex_type&, defer_lock_t)
        unique_lock(mutex_type&, try_to_lock_t)
        unique_lock(mutex_type&, adopt_lock_t)
        unique_lock(unique_lock&)
        unique_lock& operator=(unique_lock&)
        #unique_lock(unique_lock&&)
        #unique_lock& operator=(unique_lock&&)
        void lock()
        bint try_lock()
        void unlock()
        void swap(unique_lock&)
        mutex_type* release()
        bint owns_lock()
        mutex_type* mutex()
    void swap[_Mutex](unique_lock[_Mutex]&, unique_lock[_Mutex]&)