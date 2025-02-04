cimport cpython
from libc.stdint cimport uint64_t

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
                throw std::runtime_error("String too long");
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
            _length = snprintf(_small_buf, SMALL_BUF_SIZE, "###%lu", uuid);
            _capacity = SMALL_BUF_SIZE;
        }

        // Modify label to contain user label + uuid
        void set_composite_label(const char* user_label, size_t label_len, uint64_t uuid) {
            if (!user_label || label_len <= 0) {
                set_uuid_label(uuid);
                return;
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
                    "###%lu",
                    uuid
                );
                _capacity = SMALL_BUF_SIZE;
            } else {
                if (total_len > MAX_STR_LEN) {
                    throw std::runtime_error("Label too long");
                }
                char* new_data = (char*)malloc(total_len);
                memcpy(new_data, user_label, label_len);
                size_t uuid_len = snprintf(
                    new_data + label_len,
                    total_len - label_len,
                    "###%lu",
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

cdef inline void set_uuid_label(DCGString &s, uint64_t uuid):
    """Equivalent to = string_from_bytes(bytes(b'###%ld'% self.uuid))"""
    s.set_uuid_label(uuid)

cdef inline void set_composite_label(DCGString &s, str user_label, uint64_t uuid):
    """Equivalent to string_from_bytes(bytes(self._user_label, 'utf-8') + bytes(b'###%ld'% self.uuid))"""
    cdef bytes b = user_label.encode('utf-8')
    s.set_composite_label(<const char*>b, len(b), uuid)

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
            T* new_data = (T*)malloc(new_cap * sizeof(T));
            for(size_t i = 0; i < _length; ++i) {
                new (&new_data[i]) T(std::move(_data[i]));
                _data[i].~T();
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

    class DCGMutex {
    private:
        alignas(8) std::atomic<std::thread::id> owner_{std::thread::id()};
        alignas(4) std::atomic<int32_t> count_{0};

    public:
        DCGMutex() noexcept = default;
        
        void lock() noexcept {
            const auto self = std::this_thread::get_id();
            
            while (true) {
                // Try to acquire if unowned
                auto expected = std::thread::id();
                if (owner_.compare_exchange_strong(expected, self)) {
                    count_.store(1);
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
            if (owner_.compare_exchange_strong(expected, self)) {
                count_.store(1);
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
            
            if (count_.fetch_sub(1) == 1) {
                owner_.store(std::thread::id());
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