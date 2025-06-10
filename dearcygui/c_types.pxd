from libc.stdint cimport int32_t, uint64_t

cimport cpython
from cpython.object cimport PyObject
from cython.view cimport array as cython_array

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

# Due to ABI differences between compilers and compiler
# versions, we define our own simple std items here.

cdef extern from * nogil:
    """
    #include <inttypes.h>
    #define MAX_STR_LEN (64*1024*1024)
    #define SMALL_BUF_SIZE 64  // Enough for most labels + uuid

    struct DCGString {
        char _small_buf[SMALL_BUF_SIZE];
        char* _data;
        size_t _length;
        size_t _capacity;

        DCGString() : _data(nullptr), _length(0), _capacity(SMALL_BUF_SIZE) {
            _small_buf[0] = 0;
        }
        
        DCGString(const char* str) : _data(nullptr), _length(0), _capacity(SMALL_BUF_SIZE) {
            if (!str) {
                _small_buf[0] = 0;
                return;
            }
            _length = strnlen(str, MAX_STR_LEN);
            if (_length < SMALL_BUF_SIZE) {
                memcpy(_small_buf, str, _length);
                _small_buf[_length] = 0;
            } else {
                _capacity = _length + 1;
                _data = (char*)malloc(_capacity);
                memcpy(_data, str, _length);
                _data[_length] = 0;
            }
        }

        DCGString(const char* str, size_t len) : _data(nullptr), _length(0), _capacity(SMALL_BUF_SIZE) {
            if (!str || len <= 0) {
                _small_buf[0] = 0;
                return;
            }
            if (len > MAX_STR_LEN) {
                _small_buf[0] = 0;
                throw std::range_error("String too long");
            }

            _length = len;
            if (_length < SMALL_BUF_SIZE) {
                memcpy(_small_buf, str, _length);
                _small_buf[_length] = 0;
            } else {
                _capacity = _length + 1;
                _data = (char*)malloc(_capacity);
                memcpy(_data, str, _length);
                _data[_length] = 0;
            }
        }

        DCGString(const DCGString& other) : _data(nullptr), _length(other._length), _capacity(SMALL_BUF_SIZE) {
            if (_length < SMALL_BUF_SIZE) {
                memcpy(_small_buf, other._small_buf, _length + 1);
            } else {
                _capacity = other._capacity;
                _data = (char*)malloc(_capacity);
                memcpy(_data, other._data, _length + 1);
            }
        }

        DCGString& operator=(const DCGString& other) {
            if (this != &other) {
                if (_data) {
                    free(_data);
                    _data = nullptr;
                }
                _length = other._length;
                
                if (_length < SMALL_BUF_SIZE) {
                    _capacity = SMALL_BUF_SIZE;
                    memcpy(_small_buf, other._small_buf, _length + 1);
                } else {
                    _capacity = other._capacity;
                    _data = (char*)malloc(_capacity);
                    memcpy(_data, other._data, _length + 1);
                }
            }
            return *this;
        }

        bool operator==(const DCGString& other) const {
            if (_length != other._length) return false;
            const char* this_str = _data ? _data : _small_buf;
            const char* other_str = other._data ? other._data : other._small_buf;
            return memcmp(this_str, other_str, _length) == 0;
        }

        ~DCGString() {
            if (_data) free(_data);
        }

        bool empty() const { return _length == 0; }
        size_t size() const { return _length; }
        size_t capacity() const { return _capacity; }

        const char* c_str() const {
            return _data ? _data : _small_buf;
        }

        char* data() {
            return _data ? _data : _small_buf;
        }

        // Modify label to contain only uuid
        void set_uuid_label(uint64_t uuid) {
            if (_data) {
                free(_data);
                _data = nullptr;
            }
            _length = snprintf(_small_buf, SMALL_BUF_SIZE, "###%" PRIu64, uuid);
            _capacity = SMALL_BUF_SIZE;
        }

        // Modify label to contain user label + uuid
        void set_composite_label(const char* user_label, size_t label_len, uint64_t uuid) {
            if (!user_label || label_len <= 0) {
                set_uuid_label(uuid);
                return;
            }
            if (!user_label && label_len > 0) {
                throw std::invalid_argument("Null label pointer with non-zero length");
            }
            
            size_t total_len = label_len + 32;  // 32 is more than enough for "###" + uuid
            
            if (total_len <= SMALL_BUF_SIZE) {
                if (_data) {
                    free(_data);
                    _data = nullptr;
                }
                memcpy(_small_buf, user_label, label_len);
                _length = label_len + snprintf(
                    _small_buf + label_len,
                    SMALL_BUF_SIZE - label_len,
                    "###%" PRIu64,
                    uuid
                );
                _capacity = SMALL_BUF_SIZE;
            } else {
                if (total_len > MAX_STR_LEN) {
                    throw std::range_error("Label exceeds maximum length");
                }
                char* new_data = (char*)malloc(total_len);
                memcpy(new_data, user_label, label_len);
                size_t uuid_len = snprintf(
                    new_data + label_len,
                    total_len - label_len,
                    "###%" PRIu64,
                    uuid
                );
                if (_data) {
                    free(_data);
                }
                _data = new_data;
                _length = label_len + uuid_len;
                _capacity = total_len;
            }
        }

        void clear() {
            if (_data) {
                free(_data);
                _data = nullptr;
            }
            _length = 0;
            _capacity = SMALL_BUF_SIZE;
            _small_buf[0] = 0;
        }
    };
    """
    cdef cppclass DCGString:
        DCGString() except +
        DCGString(const char*) except +
        DCGString(const char*, size_t) except +
        DCGString(const DCGString&) except +
        DCGString& operator=(const DCGString&) except +
        bint operator==(const DCGString&)
        bint empty()
        size_t size()
        const char* c_str()
        char *data()
        void set_uuid_label(uint64_t) except +
        void set_composite_label(const char*, size_t, uint64_t) except +
        void clear()

cdef inline DCGString string_from_bytes(bytes b):
    return DCGString(<const char*>b, <size_t>len(b))

cdef inline DCGString string_from_str(str s):
    cdef bytes b = s.encode(encoding='utf-8')
    return string_from_bytes(b)

cdef inline bytes string_to_bytes(DCGString &s):
    return cpython.PyBytes_FromStringAndSize(s.c_str(), s.size())

cdef inline str string_to_str(DCGString &s):
    return string_to_bytes(s).decode(encoding='utf-8')

# The int32_t return value is to let cython return -1 on
# exception and avoid an exception check else.
cdef inline int32_t set_uuid_label(DCGString &s, uint64_t uuid):
    """Equivalent to = string_from_bytes(bytes(b'###%ld'% self.uuid))"""
    s.set_uuid_label(uuid)
    return 0

cdef inline int32_t set_composite_label(DCGString &s, str user_label, uint64_t uuid):
    """Equivalent to string_from_bytes(bytes(self._user_label, 'utf-8') + bytes(b'###%ld'% self.uuid))"""
    cdef bytes b = user_label.encode('utf-8')
    s.set_composite_label(<const char*>b, len(b), uuid)
    return 0

cdef extern from * nogil:
    """
    template<typename T>
    struct DCGVector {
        T* _data;
        size_t _length;
        size_t _capacity;

        DCGVector() : _data(nullptr), _length(0), _capacity(0) {}

        ~DCGVector() {
            if (_data) {
                for(size_t i = 0; i < _length; ++i) {
                    _data[i].~T();
                }
                free(_data);
            }
        }

        DCGVector(const DCGVector& other) : _data(nullptr), _length(0), _capacity(0) {
            reserve(other.size());
            for(size_t i = 0; i < other.size(); ++i) {
                new (&_data[i]) T(other[i]);
            }
            _length = other.size();
        }

        void reserve(size_t new_cap) {
            if (new_cap <= _capacity) return;
            T* new_data = static_cast<T*>(malloc(new_cap * sizeof(T)));
            if (!new_data) {
                throw std::bad_alloc();
            }
            try {
                for(size_t i = 0; i < _length; i++) {
                    new (&new_data[i]) T(std::move(_data[i]));
                    _data[i].~T();
                }
            } catch (...) {
                free(new_data);
                throw;
            }
            if (_data) free(_data);
            _data = new_data;
            _capacity = new_cap;
        }

        void push_back(const T& value) {
            if (_length == _capacity) {
                reserve(_capacity ? _capacity * 2 : 1);
            }
            new (&_data[_length]) T(value);
            ++_length;
        }

        void pop_back() {
            if (_length > 0) {
                --_length;
                _data[_length].~T();
            }
        }

        T& operator[](size_t index) {
            return _data[index];
        }

        const T& operator[](size_t index) const {
            return _data[index];
        }

        size_t size() const { return _length; }
        bool empty() const { return _length == 0; }
        size_t capacity() const { return _capacity; }

        void clear() {
            for(size_t i = 0; i < _length; ++i) {
                _data[i].~T();
            }
            _length = 0;
        }

        DCGVector& operator=(const DCGVector& other) {
            if (this != &other) {
                clear();
                reserve(other.size());
                for(size_t i = 0; i < other.size(); ++i) {
                    new (&_data[i]) T(other[i]);
                }
                _length = other.size();
            }
            return *this;
        }
        bool operator==(const DCGVector& other) const {
            if (_length != other.size()) return false;
            for(size_t i = 0; i < _length; ++i) {
                if (!(_data[i] == other[i])) return false;
            }
            return true;
        }
        void resize(size_t new_size) {
            if (new_size > _length) {
                reserve(new_size);
                for(size_t i = _length; i < new_size; ++i) {
                    new (&_data[i]) T();
                }
            } else if (new_size < _length) {
                for(size_t i = new_size; i < _length; ++i) {
                    _data[i].~T();
                }
            }
            _length = new_size;
        }

        void resize(size_t new_size, const T& value) {
            if (new_size > _length) {
                reserve(new_size);
                for(size_t i = _length; i < new_size; ++i) {
                    new (&_data[i]) T(value);
                }
            } else if (new_size < _length) {
                for(size_t i = new_size; i < _length; ++i) {
                    _data[i].~T();
                }
            }
            _length = new_size;
        }

        T* data() { return _data; }

        T& front() { return _data[0]; }
        T& back() { return _data[_length - 1]; }
    };
    """
    cdef cppclass DCGVector[T]:
        DCGVector() except +
        void push_back(const T&) except +
        void pop_back()
        T& operator[](size_t)
        bint operator==(const DCGVector&)
        size_t size()
        bint empty()
        size_t capacity()
        void clear()
        void reserve(size_t) except +
        void resize(size_t) except +
        void resize(size_t, const T&) except +
        T* data()
        T& back()
        T& front()

"""
Since our use case is that most of the case
the recursive mutex will be uncontended - and 
the recursive mutex property is rarely hit. We
use a spinlock with an non-negligible wait to not
hog the cpu.
Another advantage is that skipping std::mutex avoids
ABI issues.
"""
cdef extern from * nogil:
    """
    #include <atomic>
    #include <thread>

    struct DCGMutex {
    private:
        alignas(8) std::atomic<std::thread::id> owner_{std::thread::id()};
        alignas(8) std::atomic<int64_t> count_{0};

    public:
        DCGMutex() noexcept = default;
        
        void lock() noexcept {
            const auto self = std::this_thread::get_id();
            
            while (true) {
                // Try to acquire if unowned
                auto expected = std::thread::id();
                if (owner_.compare_exchange_strong(expected, self, std::memory_order_acquire)) {
                    count_.store(1, std::memory_order_relaxed);
                    return;
                }
                
                // Check if we already own it
                if (expected == self) {
                    count_.fetch_add(1);
                    return;
                }
                
                // Spin wait with sleep
                std::this_thread::sleep_for(std::chrono::microseconds(10));
            }
        }
        
        bool try_lock() noexcept {
            const auto self = std::this_thread::get_id();
            
            auto expected = std::thread::id();
            if (owner_.compare_exchange_strong(expected, self, std::memory_order_acquire)) {
                count_.store(1, std::memory_order_relaxed);
                return true;
            }
            
            if (expected == self) {
                count_.fetch_add(1);
                return true;
            }
            
            return false;
        }
        
        void unlock() noexcept {
            const auto self = std::this_thread::get_id();
            if (owner_.load() != self) {
                return;
            }

            if (count_.fetch_sub(1, std::memory_order_release) == 1) {
                owner_.store(std::thread::id(), std::memory_order_release);
            }
        }

        ~DCGMutex() = default;
        DCGMutex(const DCGMutex&) = delete;
        DCGMutex& operator=(const DCGMutex&) = delete;
    };
    """
    cppclass DCGMutex:
        DCGMutex()
        DCGMutex(DCGMutex&)
        DCGMutex& operator=(DCGMutex&)
        void lock()
        bint try_lock()
        void unlock()

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
    #cppclass recursive_mutex:
    #    recursive_mutex()
    #    recursive_mutex(recursive_mutex&)
    #    recursive_mutex& operator=(recursive_mutex&)
    #    void lock()
    #    bint try_lock()
    #    void unlock()
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

cdef extern from "<condition_variable>" namespace "std" nogil:
    cppclass condition_variable:
        condition_variable()
        void notify_one() noexcept
        void notify_all() noexcept
        void wait(unique_lock[mutex]& lock)

# Basic array operators to avoid linking to numpy

cdef extern from *:
    """
    #include <Python.h>

    enum DCGArrayType {
        DCG_INT32 = 0,
        DCG_FLOAT = 1,
        DCG_DOUBLE = 2,
        DCG_UINT8 = 3
    };

    inline bool is_little_endian() {
        const uint16_t test = 0x0001;
        return *reinterpret_cast<const uint8_t*>(&test) == 0x01;
    }

    struct DCG1DArrayView {
        void* _data;
        void* _owned_data;  // If we need to make a copy
        PyObject* _pyobj;
        Py_buffer _view;
        size_t _size;
        size_t _stride;
        union {
            struct {
                DCGArrayType _type;
                bool _has_view;
            };
            // Forces 8-byte alignment
            struct {
                uint64_t _alignment_union1;
                uint64_t _alignment_union2;
            };
        };
        
        DCG1DArrayView() : _data(nullptr), _owned_data(nullptr), 
                          _pyobj(nullptr), _size(0), _stride(0), 
                          _type(DCG_DOUBLE), _has_view(false) {}

        template<typename T>
        static double convert_number(T value) {
            return static_cast<double>(value);
        }

        template<typename T>
        void convert_array_to_double(char* src, double* dst) {
            for (size_t i = 0; i < _size; i++) {
                dst[i] = convert_number(*reinterpret_cast<T*>(src + i * _stride));
            }
        }

        void _convert_to_double() {
            double* new_data = static_cast<double*>(malloc(_size * sizeof(double)));
            if (!new_data) {
                throw std::bad_alloc();
            }
            char* src = static_cast<char*>(_data);
            const char* format = _view.format;
            
            try {
                // Handle NULL format - treat as unsigned bytes per Python spec
                static const char default_format = 'B';
                if (!format) format = &default_format;
                
                // Skip byte order indicators
                while (*format == '@' || *format == '=' || *format == '<' || 
                       *format == '>' || *format == '!') format++;

                // We do not support size/repeat indicators
                if (isdigit(*format))
                    throw std::runtime_error("Unsupported buffer format for conversion");

                switch (*format) {
                    case 'b': convert_array_to_double<int8_t>(src, new_data); break;
                    case 'B': convert_array_to_double<uint8_t>(src, new_data); break;
                    case 'h': convert_array_to_double<int16_t>(src, new_data); break;
                    case 'H': convert_array_to_double<uint16_t>(src, new_data); break;
                    case 'i': convert_array_to_double<int32_t>(src, new_data); break;
                    case 'l':
                        if (_view.itemsize == 4) {
                            convert_array_to_double<int32_t>(src, new_data);
                        } else {
                            convert_array_to_double<int64_t>(src, new_data);
                        }
                        break;
                    case 'I': convert_array_to_double<uint32_t>(src, new_data); break;
                    case 'L':
                        if (_view.itemsize == 4) {
                            convert_array_to_double<uint32_t>(src, new_data);
                        } else {
                            convert_array_to_double<uint64_t>(src, new_data);
                        }
                        break;
                    case 'q': convert_array_to_double<int64_t>(src, new_data); break;
                    case 'Q': convert_array_to_double<uint64_t>(src, new_data); break;
                    case 'f': convert_array_to_double<float>(src, new_data); break;
                    case 'd': convert_array_to_double<double>(src, new_data); break;
                    case 'O': // Python object
                        for (size_t i = 0; i < _size; i++) {
                            PyObject* item = *reinterpret_cast<PyObject**>(src + i * _stride);
                            if (PyNumber_Check(item)) {
                                PyObject* float_obj = PyNumber_Float(item);
                                if (float_obj) {
                                    new_data[i] = PyFloat_AsDouble(float_obj);
                                    Py_DECREF(float_obj);
                                } else {
                                    throw std::runtime_error("Failed to convert Python object to float");
                                }
                            } else {
                                throw std::runtime_error("Python object is not a number");
                            }
                        }
                        break;
                    default:
                        throw std::runtime_error("Unsupported buffer format for conversion");
                }

                if (_owned_data) free(_owned_data);
                _owned_data = new_data;
                _data = new_data;
                _stride = sizeof(double);
                _type = DCG_DOUBLE;

            } catch (...) {
                free(new_data);
                throw;
            }
        }

        // Returns true if the buffer can be treated as 1D
        bool _get_effective_1d_shape(const Py_buffer& view, size_t& out_size, size_t& out_stride) {
            if (view.ndim <= 0) {
                throw std::invalid_argument("Buffer has invalid dimensions");
            }
            out_size = 1;
            out_stride = 0;
            int effective_dim = -1;

            // Find the non-1 dimension
            for (int i = 0; i < view.ndim; i++) {
                if (view.shape[i] > 1) {
                    if (effective_dim != -1) {
                        return false;  // More than one non-1 dimension
                    }
                    effective_dim = i;
                    out_size = view.shape[i];
                }
            }

            // All dimensions are 1
            if (effective_dim == -1) {
                effective_dim = 0;
                out_size = 1;
            }

            out_stride = view.strides[effective_dim];
            return true;
        }

        void _cleanup() {
            if (_owned_data) {
                free(_owned_data);
                _owned_data = nullptr;
            }
            if (_has_view) {
                PyBuffer_Release(&_view);
                _has_view = false;
            }
            if (_pyobj) {
                Py_DECREF(_pyobj);
                _pyobj = nullptr;
            }
            _data = nullptr;
            _size = 0;
            _stride = 0;
            _type = DCG_DOUBLE;
        }

        bool try_get_sequence_size(PyObject* obj, size_t& out_size) {
            if (!PySequence_Check(obj)) return false;
            Py_ssize_t len = PySequence_Length(obj);
            if (len < 0) {
                PyErr_Clear();
                return false;
            }
            out_size = static_cast<size_t>(len);
            return true;
        }

        void reset() {
            _cleanup();
        }

        void reset(PyObject* obj) {
            _cleanup();
            
            if (!obj) {
                throw std::invalid_argument("Null Python object");
            }

            // First try buffer protocol
            if (PyObject_GetBuffer(obj, &_view, PyBUF_RECORDS_RO) >= 0) {
                _has_view = true;

                size_t effective_size, effective_stride;
                if (!_get_effective_1d_shape(_view, effective_size, effective_stride)) {
                    PyBuffer_Release(&_view);
                    throw std::invalid_argument("Buffer cannot be interpreted as 1-dimensional");
                }

                _size = effective_size;
                _stride = effective_stride; 
                _data = _view.buf;
                
                // Set initial type and convert if needed
                const char* format = _view.format;
                if (!format) {
                    _convert_to_double();
                } else {
                    const bool native_little = is_little_endian();
                    bool format_little = true;  // default to native
                    
                    if (*format == '<') {
                        format_little = true;
                        format++;
                    } else if (*format == '>') {
                        format_little = false;
                        format++;
                    } else if (*format == '=' || *format == '@') {
                        format_little = native_little;
                        format++;
                    } else if (*format == '!') {
                        format_little = false;
                        format++;
                    }
                    
                    if (format_little != native_little) {
                        PyBuffer_Release(&_view);
                        throw std::invalid_argument("Buffer endianness does not match platform");
                    }

                    if (_view.itemsize == 4 && (
                        *format == 'i' ||
                        *format == 'l')) {
                        _type = DCG_INT32;
                    } else if (*format == 'f') {
                        _type = DCG_FLOAT;
                    } else if (*format == 'd') {
                        _type = DCG_DOUBLE;
                    } else if (*format == 'B' || *format == 'b') {
                        _type = DCG_UINT8;
                    } else {
                        // Convert unsupported types to double
                        _convert_to_double();
                    }
                }
            }
            // Then try sequence protocol
            else {
                PyErr_Clear();  // Clear buffer protocol error
                size_t seq_size;
                if (!try_get_sequence_size(obj, seq_size)) {
                    throw std::invalid_argument("Object supports neither buffer nor sequence protocol");
                }

                _size = seq_size;
                double* new_data = static_cast<double*>(malloc(_size * sizeof(double)));
                if (!new_data) {
                    throw std::bad_alloc();
                }

                try {
                    for (size_t i = 0; i < _size; i++) {
                        PyObject* item = PySequence_GetItem(obj, i);
                        if (!item) {
                            PyErr_Clear();
                            throw std::invalid_argument("Failed to get sequence item");
                        }

                        PyObject* float_obj = PyNumber_Float(item);
                        Py_DECREF(item);
                        
                        if (!float_obj) {
                            PyErr_Clear();
                            throw std::invalid_argument("Sequence item is not convertible to float");
                        }

                        new_data[i] = PyFloat_AsDouble(float_obj);
                        Py_DECREF(float_obj);
                        
                        if (new_data[i] == -1. && PyErr_Occurred()) {
                            PyErr_Clear();
                            throw std::invalid_argument("Error converting sequence item to float");
                        }
                    }

                    _owned_data = new_data;
                    _data = new_data;
                    _stride = sizeof(double);
                    _type = DCG_DOUBLE;

                } catch (...) {
                    free(new_data);
                    throw;
                }
            }

            _pyobj = obj;
            Py_INCREF(_pyobj);
        }

        ~DCG1DArrayView() {
            _cleanup();
        }

        template<typename T>
        T* data() const { return static_cast<T*>(_data); }
        
        size_t size() const { return _size; }
        size_t stride() const { return _stride; }
        DCGArrayType type() const { return _type; }
        PyObject* pyobj() const { return _pyobj; }

        void ensure_contiguous() {
            if (!_data || !_size) return;
            
            // Already contiguous with proper stride
            size_t element_size = -1;
            switch (_type) {
                case DCG_INT32: element_size = sizeof(int32_t); break;
                case DCG_FLOAT: element_size = sizeof(float); break;
                case DCG_DOUBLE: element_size = sizeof(double); break;
                case DCG_UINT8: element_size = sizeof(uint8_t); break;
            }
            if (_stride == element_size) return;
            
            void* new_data = malloc(_size * element_size);
            char* src = static_cast<char*>(_data);
            char* dst = static_cast<char*>(new_data);
            
            for (size_t i = 0; i < _size; i++) {
                memcpy(dst + i * element_size, 
                      src + i * _stride, 
                      element_size);
            }
            
            if (_owned_data) free(_owned_data);
            _owned_data = new_data;
            _data = new_data;
            _stride = element_size;
        }

        void ensure_double() {
            if (_type == DCG_DOUBLE) return;
            _convert_to_double();
        }
    };

    struct DCG2DContiguousArrayView {
        void* _data;
        void* _owned_data;
        PyObject* _pyobj;
        Py_buffer _view;
        size_t _rows;
        size_t _cols;
        union {
            struct {
                DCGArrayType _type;
                bool _has_view;
            };
            struct {
                uint64_t _alignment_union1;
                uint64_t _alignment_union2;
            };
        };
        
        DCG2DContiguousArrayView() : _data(nullptr), _owned_data(nullptr),
                                    _pyobj(nullptr), _rows(0), _cols(0),
                                    _type(DCG_DOUBLE), _has_view(false) {}

        template<typename T>
        static double convert_number(T value) {
            return static_cast<double>(value);
        }

        template<typename T>
        void convert_array_to_double(const char* src, double* dst, size_t stride_row, size_t stride_col) {
            for (size_t i = 0; i < _rows; i++) {
                const char* row = src + i * stride_row;
                for (size_t j = 0; j < _cols; j++) {
                    dst[i * _cols + j] = convert_number(*reinterpret_cast<const T*>(row + j * stride_col));
                }
            }
        }

        void _convert_to_double() {
            size_t total = _rows * _cols;
            double* new_data = static_cast<double*>(malloc(total * sizeof(double)));
            if (!new_data) {
                throw std::bad_alloc();
            }

            try {
                const char* format = _view.format;
                
                // Handle NULL format - treat as unsigned bytes per Python spec
                static const char default_format = 'B';
                if (!format) format = &default_format;
                
                // Skip byte order indicators
                while (*format == '@' || *format == '=' || *format == '<' || 
                       *format == '>' || *format == '!') format++;

                // We do not support size/repeat indicators
                if (isdigit(*format))
                    throw std::runtime_error("Unsupported buffer format for conversion");

                // Get source strides
                size_t stride_row = _view.strides[0];
                size_t stride_col = _view.strides[1];
                const char* src = static_cast<const char*>(_data);

                switch (*format) {
                    case 'b': convert_array_to_double<int8_t>(src, new_data, stride_row, stride_col); break;
                    case 'B': convert_array_to_double<uint8_t>(src, new_data, stride_row, stride_col); break;
                    case 'h': convert_array_to_double<int16_t>(src, new_data, stride_row, stride_col); break;
                    case 'H': convert_array_to_double<uint16_t>(src, new_data, stride_row, stride_col); break;
                    case 'i': convert_array_to_double<int32_t>(src, new_data, stride_row, stride_col); break;
                    case 'l': 
                        if (_view.itemsize == 4) {
                            convert_array_to_double<int32_t>(src, new_data, stride_row, stride_col);
                        } else {
                            convert_array_to_double<int64_t>(src, new_data, stride_row, stride_col);
                        }
                        break;
                    case 'I': convert_array_to_double<uint32_t>(src, new_data, stride_row, stride_col); break;
                    case 'L':
                        if (_view.itemsize == 4) {
                            convert_array_to_double<uint32_t>(src, new_data, stride_row, stride_col);
                        } else {
                            convert_array_to_double<uint64_t>(src, new_data, stride_row, stride_col);
                        }
                        break;
                    case 'q': convert_array_to_double<int64_t>(src, new_data, stride_row, stride_col); break;
                    case 'Q': convert_array_to_double<uint64_t>(src, new_data, stride_row, stride_col); break;
                    case 'f': convert_array_to_double<float>(src, new_data, stride_row, stride_col); break;
                    case 'd': convert_array_to_double<double>(src, new_data, stride_row, stride_col); break;
                    default:
                        throw std::runtime_error("Unsupported buffer format for conversion");
                }

                if (_owned_data) free(_owned_data);
                _owned_data = new_data;
                _data = new_data;
                _type = DCG_DOUBLE;

            } catch (...) {
                free(new_data);
                throw;
            }
        }

        void _ensure_contiguous() {
            if (!_data || !_rows || !_cols) return;
            
            size_t element_size = -1;
            switch (_type) {
                case DCG_INT32: element_size = sizeof(int32_t); break;
                case DCG_FLOAT: element_size = sizeof(float); break;
                case DCG_DOUBLE: element_size = sizeof(double); break;
                case DCG_UINT8: element_size = sizeof(uint8_t); break;
            }
            
            // Only use fast path when:
            // - Column stride matches element size exactly
            // - Row stride equals cols * element size
            // This ensures we have a proper row-major layout
            bool is_contiguous = (
                _view.strides[1] == static_cast<Py_ssize_t>(element_size) && 
                _view.strides[0] == static_cast<Py_ssize_t>(_cols * element_size)
            );
            
            if (is_contiguous) return;
            
            size_t total = _rows * _cols;
            size_t required_size = total * element_size;
            void* new_data = malloc(required_size);
            if (!new_data) throw std::bad_alloc();
            
            try {
                const char* src = static_cast<const char*>(_data);
                char* dst = static_cast<char*>(new_data);
                
                if (_view.strides[1] == static_cast<Py_ssize_t>(element_size)) {
                    for (size_t i = 0; i < _rows; i++) {
                        memcpy(dst + i * _cols * element_size,
                               src + i * _view.strides[0],
                               _cols * element_size);
                    }
                } else {
                    for (size_t i = 0; i < _rows; i++) {
                        const char* row = src + i * _view.strides[0];
                        char* dst_row = dst + i * _cols * element_size;
                        for (size_t j = 0; j < _cols; j++) {
                            memcpy(dst_row + j * element_size,
                                   row + j * _view.strides[1],
                                   element_size);
                        }
                    }
                }
                
                if (_owned_data) free(_owned_data);
                _owned_data = new_data;
                _data = new_data;
                
            } catch (...) {
                free(new_data);
                throw;
            }
        }

        void _cleanup() {
            if (_owned_data) {
                free(_owned_data);
                _owned_data = nullptr;
            }
            if (_has_view) {
                PyBuffer_Release(&_view);
                _has_view = false;
            }
            if (_pyobj) {
                Py_DECREF(_pyobj);
                _pyobj = nullptr;
            }
            _data = nullptr;
            _rows = _cols = 0;
            _type = DCG_DOUBLE;
        }

        bool try_get_sequence_size(PyObject* obj, size_t& out_size) {
            if (!PySequence_Check(obj)) return false;
            Py_ssize_t len = PySequence_Length(obj);
            if (len < 0) {
                PyErr_Clear();
                return false;
            }
            out_size = static_cast<size_t>(len);
            return true;
        }

        void reset() {
            _cleanup();
        }

        void reset(PyObject* obj) {
            _cleanup();
            
            if (!obj) {
                throw std::invalid_argument("Null Python object");
            }

            // First try buffer protocol
            if (PyObject_GetBuffer(obj, &_view, PyBUF_RECORDS_RO) >= 0) {
                _has_view = true;

                if (_view.ndim != 2) {
                    PyBuffer_Release(&_view);
                    throw std::invalid_argument("Buffer must be 2-dimensional");
                }

                _rows = _view.shape[0];
                _cols = _view.shape[1];
                _data = _view.buf;

                const char* format = _view.format;
                if (!format) {
                    _convert_to_double();
                } else {
                    const bool native_little = is_little_endian();
                    bool format_little = true;  // default to native
                    
                    if (*format == '<') {
                        format_little = true;
                        format++;
                    } else if (*format == '>') {
                        format_little = false;
                        format++;
                    } else if (*format == '=' || *format == '@') {
                        format_little = native_little;
                        format++;
                    } else if (*format == '!') {
                        format_little = false;
                        format++;
                    }
                    
                    if (format_little != native_little) {
                        PyBuffer_Release(&_view);
                        throw std::invalid_argument("Buffer endianness does not match platform");
                    }

                    if (_view.itemsize == 4 && (*format == 'i' || *format == 'l')) {
                        _type = DCG_INT32;
                        _ensure_contiguous();
                    } else if (*format == 'f') {
                        _type = DCG_FLOAT;
                        _ensure_contiguous();
                    } else if (*format == 'd') {
                        _type = DCG_DOUBLE;
                        _ensure_contiguous();
                    } else if (*format == 'B') {
                        _type = DCG_UINT8;
                        _ensure_contiguous();
                    } else {
                        _convert_to_double();
                    }
                }
            }
            // Then try sequence protocol
            else {
                PyErr_Clear();  // Clear buffer protocol error
                size_t rows;
                if (!try_get_sequence_size(obj, rows)) {
                    throw std::invalid_argument("Object supports neither buffer nor sequence protocol");
                }

                if (rows == 0) {
                    _rows = _cols = 0;
                    return;
                }

                // Get first row to determine number of columns
                PyObject* first_row = PySequence_GetItem(obj, 0);
                if (!first_row) {
                    PyErr_Clear();
                    throw std::invalid_argument("Failed to get first row");
                }

                size_t cols;
                if (!try_get_sequence_size(first_row, cols)) {
                    Py_DECREF(first_row);
                    throw std::invalid_argument("Row items must be sequences");
                }
                Py_DECREF(first_row);

                if (cols == 0) {
                    throw std::invalid_argument("Rows cannot be empty");
                }

                // Allocate contiguous array
                double* new_data = static_cast<double*>(malloc(rows * cols * sizeof(double)));
                if (!new_data) {
                    throw std::bad_alloc();
                }

                try {
                    // Convert all elements to double
                    for (size_t i = 0; i < rows; i++) {
                        PyObject* row = PySequence_GetItem(obj, i);
                        if (!row) {
                            PyErr_Clear();
                            throw std::invalid_argument("Failed to get row");
                        }

                        size_t row_size;
                        if (!try_get_sequence_size(row, row_size) || row_size != cols) {
                            Py_DECREF(row);
                            throw std::invalid_argument("All rows must have the same length");
                        }

                        for (size_t j = 0; j < cols; j++) {
                            PyObject* item = PySequence_GetItem(row, j);
                            if (!item) {
                                Py_DECREF(row);
                                PyErr_Clear();
                                throw std::invalid_argument("Failed to get item");
                            }

                            PyObject* float_obj = PyNumber_Float(item);
                            Py_DECREF(item);

                            if (!float_obj) {
                                Py_DECREF(row);
                                PyErr_Clear();
                                throw std::invalid_argument("All items must be convertible to float");
                            }

                            new_data[i * cols + j] = PyFloat_AsDouble(float_obj);
                            Py_DECREF(float_obj);

                            if (new_data[i * cols + j] == -1 && PyErr_Occurred()) {
                                Py_DECREF(row);
                                PyErr_Clear();
                                throw std::invalid_argument("Error converting item to float");
                            }
                        }
                        Py_DECREF(row);
                    }

                    _owned_data = new_data;
                    _data = new_data;
                    _rows = rows;
                    _cols = cols;
                    _type = DCG_DOUBLE;

                } catch (...) {
                    free(new_data);
                    throw;
                }
            }

            _pyobj = obj;
            Py_INCREF(_pyobj);
        }

        ~DCG2DContiguousArrayView() {
            _cleanup();
        }

        template<typename T>
        T* data() const { return static_cast<T*>(_data); }
        
        size_t rows() const { return _rows; }
        size_t cols() const { return _cols; }
        DCGArrayType type() const { return _type; }
        PyObject* pyobj() const { return _pyobj; }

        void ensure_double() {
            if (_type == DCG_DOUBLE) return;
            _convert_to_double();
        }
    };
    """

    cdef cppclass DCG1DArrayView:
        void* _data
        size_t _size
        size_t _stride
        DCGArrayType _type
        
        DCG1DArrayView() except +
        void reset() except +
        void reset(object) except +
        T* data[T]() nogil
        size_t size() nogil
        size_t stride() nogil
        DCGArrayType type() nogil
        cpython.PyObject* pyobj()
        void ensure_contiguous() except +
        void ensure_double() except +

    cdef cppclass DCG2DContiguousArrayView:
        void* _data
        size_t _rows
        size_t _cols
        DCGArrayType _type
        
        DCG2DContiguousArrayView() except +
        void reset() except +
        void reset(object) except +
        T* data[T]() nogil
        size_t rows() nogil
        size_t cols() nogil
        DCGArrayType type() nogil
        cpython.PyObject* pyobj()
        void ensure_double() except +

    ctypedef enum DCGArrayType:
        DCG_INT32
        DCG_FLOAT
        DCG_DOUBLE
        DCG_UINT8

cdef inline object get_object_from_1D_array_view(DCG1DArrayView &view):
    cdef cpython.PyObject *obj = view.pyobj()
    if obj == NULL:
        # return empty array of 1 dim
        return cython_array(shape=(1,), itemsize=8, format='d')[:0]
    return <object>obj

cdef inline object get_object_from_2D_array_view(DCG2DContiguousArrayView &view):
    cdef cpython.PyObject *obj = view.pyobj()
    if obj == NULL:
        # return empty array of 2 dims
        return cython_array(shape=(1, 1), itemsize=8, format='d')[:0, :0]
    return <object>obj

cdef extern from *:
    """
    struct ValueOrItem {
        float _value;
        int32_t _changed;
        PyObject* _item;

        ValueOrItem() : _value(0.0f), _changed(1), _item(nullptr) {}
        ValueOrItem(float value) : _value(value), _changed(1), _item(nullptr) {}
        ValueOrItem(const ValueOrItem& other) : _value(other._value),
                                                _changed(other._changed),
                                                _item(nullptr) {
            if (other._item) {
                Py_INCREF(other._item);
                _item = other._item;
            }
        }
        ValueOrItem(ValueOrItem&& other) noexcept : _value(other._value),
                                                    _changed(other._changed),
                                                    _item(other._item) {
            other._item = nullptr;
        }
        ValueOrItem& operator=(const ValueOrItem& other) {
            if (this != &other) {
                _value = other._value;
                _changed = other._changed;
                if (_item) {
                    Py_DECREF(_item);
                    _item = nullptr;
                }
                if (other._item) {
                    Py_INCREF(other._item);
                    _item = other._item;
                }
            }
            return *this;
        }
        ValueOrItem& operator=(ValueOrItem&& other) noexcept {
            if (this != &other) {
                if (_item) {
                    Py_DECREF(_item);
                }
                _value = other._value;
                _changed = other._changed;
                _item = other._item;
                other._item = nullptr;
            }
            return *this;
        }
        ~ValueOrItem() {
            if (_item) {
                Py_DECREF(_item);
                _item = nullptr;
            }
        }
        void set_value(float value) {
            _changed |= value != _value;
            _value = value;
            if (_item) {
                Py_DECREF(_item);
                _item = nullptr;
            }
        }
        void set_item(PyObject* item) {
            // We do not set change here
            // as it could resolve to the same
            // value. It is checked in set_item_value.
            if (_item) {
                Py_DECREF(_item);
            }
            _item = item;
            if (_item) {
                Py_INCREF(_item);
            }
        }
        void set_item_o(PyObject* item) {
            // Variant that gets an object
            set_item(item);
        }
        // Called to inform about the item
        // resolved value.
        inline void set_item_value(float value) {
            _changed |= value != _value;
            _value = value;
        }
        inline float get_value() const {
            return _value;
        }
        inline PyObject* get_item() const {
            return _item;
        }
        inline bool is_item() const {
            return _item != nullptr;
        }
        inline bool has_changed() {
            bool result = _changed != 0;
            _changed = 0;
            return result;
        }
    };
    """
    cdef cppclass ValueOrItem:
        float _value
        int32_t _changed
        PyObject* _item

        ValueOrItem() except +
        ValueOrItem(float) except +
        ValueOrItem(const ValueOrItem&) except +
        void set_value(float)
        void set_item(PyObject*)
        void set_item_o(object)
        void set_item_value(float) noexcept nogil
        PyObject* get_item() noexcept nogil
        float get_value() noexcept nogil
        bint is_item() noexcept nogil
        bint has_changed() noexcept nogil # To be called after get_*(). Resets only after being checked.