module Judy

import Base.getindex
import Base.setindex!
import Base.show
import Base.length
import Base.start
import Base.done
import Base.next

const _judylib = "libJudy"
const MAX_STR_IDX_LEN = (1024*10)

export Judy1, JudyL, JudySL, JudyHS
export ju_set, ju_unset, ju_get
export ju_mem_used
export ju_count, ju_by_count
export ju_first, ju_next, ju_last, ju_prev
export ju_first_empty, ju_next_empty, ju_last_empty, ju_prev_empty

##
## TYPES BEGIN
##
type JudyArrayBase
    jarr::Ptr{Void}
    pjarr::Array{Ptr{Void}}
    nth_idx::Array

    JudyArrayBase(nidx) = new(C_NULL, zeros(Ptr{Void}, 1), nidx)
end

type Judy1
    b::JudyArrayBase
    function Judy1()
        j = new(JudyArrayBase(zeros(Uint, 1)))
        finalizer(j, ju_free)
        j
    end
end

type JudyL
    b::JudyArrayBase
    function JudyL()
        j = new(JudyArrayBase(zeros(Uint, 1)))
        finalizer(j, ju_free)
        j
    end
end

type JudySL
    b::JudyArrayBase
    function JudySL()
        j = new(JudyArrayBase(zeros(Uint8, MAX_STR_IDX_LEN)))
        finalizer(j, ju_free)
        j
    end
end

type JudyHS
    b::JudyArrayBase
    function JudyHS()
        j = new(JudyArrayBase(zeros(Uint8, 0)))
        finalizer(j, ju_free)
        j
    end
end

##
## TYPES END
##

show(io::IO, j::Judy1) = println(io, (j.b.jarr == C_NULL) ? "$(typeof(j)) (empty)" : "$(typeof(j)) (count: $(dec(ju_count(j))))")
show(io::IO, j::JudyL) = println(io, (j.b.jarr == C_NULL) ? "$(typeof(j)) (empty)" : "$(typeof(j)) (count: $(dec(ju_count(j))))")
show(io::IO, j::JudySL) = println(io, (j.b.jarr == C_NULL) ? "$(typeof(j)) (empty)" : "$(typeof(j)) (populated)")
show(io::IO, j::JudyHS) = println(io, (j.b.jarr == C_NULL) ? "$(typeof(j)) (empty)" : "$(typeof(j)) (populated)")

##
## INDEXABLE COLLECTIONS BEGIN
##
getindex(arr::Judy1, idx::Integer) = (ju_get(arr, idx) == 1)
setindex!(arr::Judy1, isset::Bool, idx::Integer) = isset ? ju_set(arr, idx) : ju_unset(arr, idx)

function getindex(arr::JudyL, idx::Integer)
    ret_tuple = ju_get(arr, idx)
    return (ret_tuple[2] == C_NULL) ? Nothing : ret_tuple[1]
end

function setindex!(arr::JudyL, val::Any, idx::Integer)
    if Nothing == val
        ju_unset(arr, idx)
        return Nothing
    end
    (C_NULL != ju_set(arr, idx, val)) ? val : Nothing
end

function getindex(arr::JudySL, idx::String)
    ret_tuple = ju_get(arr, idx)
    return (ret_tuple[2] == C_NULL) ? Nothing : ret_tuple[1]
end

function setindex!(arr::JudySL, val::Any, idx::String)
    if Nothing == val
        ju_unset(arr, idx)
        return Nothing
    end
    (C_NULL != ju_set(arr, idx, val)) ? val : Nothing
end

function getindex(arr::JudyHS, idx::Array{Uint8})
    ret_tuple = ju_get(arr, idx)
    return (ret_tuple[2] == C_NULL) ? Nothing : ret_tuple[1]
end

function setindex!(arr::JudyHS, val::Any, idx::Array{Uint8})
    if Nothing == val
        ju_unset(arr, idx)
        return Nothing
    end
    (C_NULL != ju_set(arr, idx, val)) ? val : Nothing
end

length(arr::Judy1) = ju_count(arr)
length(arr::JudyL) = ju_count(arr)

##
## INDEXABLE COLLECTIONS END
##

##
## DESTRUCTOR BEGIN
##
# destructor that frees the judy array completely
macro _ju_free(arr, fn)
    quote
        ret::Uint = ccall(($(fn), _judylib), Uint, (Ptr{Ptr{Void}}, Ptr{Void}), $(arr).b.pjarr, C_NULL)
        $(arr).b.jarr = $(arr).b.pjarr[1]
        ret
    end
end

ju_free(arr::Judy1) = @_ju_free arr :Judy1FreeArray
ju_free(arr::JudyL) = @_ju_free arr :JudyLFreeArray
ju_free(arr::JudySL) = @_ju_free arr :JudySLFreeArray
ju_free(arr::JudyHS) = @_ju_free arr :JudyHSFreeArray
##
## DESTRUCTOR END
##

## returns bytes of memory used currently by the judy array
ju_mem_used(arr::Judy1) = ccall((:Judy1MemUsed, _judylib), Uint, (Ptr{Void},), arr.b.jarr)
ju_mem_used(arr::JudyL) = ccall((:JudyLMemUsed, _judylib), Uint, (Ptr{Void},), arr.b.jarr)


## set bit at the index
## return 1 if bit was previously unset (successful), otherwise 0 if the bit was already set (unsuccessful).
ju_set(arr::Judy1, idx::Integer) = ju_set(arr, convert(Uint, idx))
function ju_set(arr::Judy1, idx::Uint)
    ret::Int32 = ccall((:Judy1Set, _judylib), Int32, (Ptr{Ptr{Void}}, Uint, Ptr{Void}), arr.b.pjarr, idx, C_NULL)
    arr.b.jarr = arr.b.pjarr[1]
    return ret
end


## set value (val) at index (idx)
## return a pointer to the value. the pointer is valid till the next call to a judy method.
## return C_NULL on error
ju_set(arr::JudyL, idx::Integer, val::Integer) = ju_set(arr, convert(Uint, idx), convert(Uint, val))
function ju_set(arr::JudyL, idx::Uint, val::Uint)
    ret::Ptr{Uint} = ccall((:JudyLIns, _judylib), Ptr{Uint}, (Ptr{Ptr{Void}}, Uint, Ptr{Void}), arr.b.pjarr, idx, C_NULL)
    if (ret != C_NULL)
        unsafe_assign(ret, val)
        arr.b.jarr = arr.b.pjarr[1]
    end
    ret
end

ju_set(arr::JudySL, idx::String, val::Integer) = ju_set(arr, idx, convert(Uint, val))
function ju_set(arr::JudySL, idx::String, val::Uint)
    ret::Ptr{Uint} = ccall((:JudySLIns, _judylib), Ptr{Uint}, (Ptr{Ptr{Void}}, Ptr{Uint8}, Ptr{Void}), arr.b.pjarr, bytestring(idx), C_NULL)
    if (ret != C_NULL)
        unsafe_assign(ret, val)
        arr.b.jarr = arr.b.pjarr[1]
    end
    ret
end

ju_set(arr::JudyHS, idx::Array{Uint8}, val::Integer) = ju_set(arr, idx, convert(Uint, val))
function ju_set(arr::JudyHS, idx::Array{Uint8}, val::Uint)
    ret::Ptr{Uint} = ccall((:JudyHSIns, _judylib), Ptr{Uint}, (Ptr{Ptr{Void}}, Ptr{Uint8}, Uint, Ptr{Void}), arr.b.pjarr, idx, convert(Uint, length(idx)), C_NULL)
    if (ret != C_NULL)
        unsafe_assign(ret, val)
        arr.b.jarr = arr.b.pjarr[1]
    end
    ret
end


## unset value at index
## return 1 if index was previously set (successful), otherwise 0 if the index was already unset (unsuccessful).
macro _ju_unset(arr, idx, itype, fn)
    quote
        local ret::Int32 = ccall(($(fn), _judylib), Int32, (Ptr{Ptr{Void}}, $(itype), Ptr{Void}), $(arr).b.pjarr, $(idx), C_NULL)
        $(arr).b.jarr = $(arr).b.pjarr[1]
        ret
    end
end

ju_unset(arr::Judy1, idx::Integer) = ju_unset(arr, convert(Uint, idx))
ju_unset(arr::Judy1, idx::Uint) = @_ju_unset arr idx Uint :Judy1Unset

ju_unset(arr::JudyL, idx::Integer) = ju_unset(arr, convert(Uint, idx))
ju_unset(arr::JudyL, idx::Uint) = @_ju_unset arr idx Uint :JudyLDel

ju_unset(arr::JudySL, idx::String) = @_ju_unset arr bytestring(idx) Ptr{Uint8} :JudySLDel

function ju_unset(arr::JudyHS, idx::Array{Uint8})
    ret::Int32 = ccall((:JudyHSDel, _judylib), Int32, (Ptr{Ptr{Void}}, Ptr{Uint8}, Uint, Ptr{Void}), arr.b.pjarr, idx, convert(Uint, length(idx)), C_NULL)
    arr.b.jarr = arr.b.pjarr[1]
    ret
end


## get the value at index (if set)
## return 1 if index's bit was set, 0 if it was unset (index was absent).
ju_get(arr::Judy1, idx::Integer) = ju_get(arr, convert(Uint, idx))
function ju_get(arr::Judy1, idx::Uint)
    ret::Int32 = ccall((:Judy1Test, _judylib), Int32, (Ptr{Void}, Uint, Ptr{Void}), arr.b.jarr, idx, C_NULL)
    return ret
end

## get the value at index (if set)
## return a tuple (value, pointer to value) if index's bit was set, (undefined, C_NULL) if it was unset (index was absent).
## the pointer is valid till the next call to a judy method.
function ju_get(arr::JudyHS, idx::Array{Uint8})
    ret::Ptr{Uint} = ccall((:JudyHSGet, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint8}, Uint, Ptr{Void}), arr.b.jarr, idx, convert(Uint, length(idx)), C_NULL)
    ret_val::Uint = (ret != C_NULL) ? unsafe_ref(ret) : C_NULL
    (ret_val, ret)
end

macro _ju_get(arr, idx, itype, fn)
    quote
        local ret::Ptr{Uint} = ccall(($(fn), _judylib), Ptr{Uint}, (Ptr{Void}, $(itype), Ptr{Void}), $(arr).b.jarr, $(idx), C_NULL)
        local ret_val::Uint = (ret != C_NULL) ? unsafe_ref(ret) : C_NULL
        (ret_val, ret)
    end
end

ju_get(arr::JudyL, idx::Integer) = ju_get(arr, convert(Uint, idx))
ju_get(arr::JudyL, idx::Uint) = @_ju_get arr idx Uint :JudyLGet
ju_get(arr::JudySL, idx::String) = @_ju_get arr bytestring(idx) Ptr{Uint8} :JudySLGet

## count the number of indexes present between idx1 and idx2 (inclusive).
## returns the count.
## a return value of 0 can be valid as a count, or it can indicate a special case for fully populated array (32-bit machines only).
## see Judy documentation for ways to resolve this.
ju_count(arr::Judy1) = ju_count(arr, 0, -1)
ju_count(arr::Judy1, idx1::Integer, idx2::Integer) = ju_count(arr, convert(Uint, idx1), convert(Uint, idx2))
ju_count(arr::Judy1, idx1::Uint, idx2::Uint) = ccall((:Judy1Count, _judylib), Uint, (Ptr{Void}, Uint, Uint, Ptr{Void}), arr.b.jarr, idx1, idx2, C_NULL)
ju_count(arr::JudyL) = ju_count(arr, 0, -1)
ju_count(arr::JudyL, idx1::Integer, idx2::Integer) = ju_count(arr, convert(Uint, idx1), convert(Uint, idx2))
ju_count(arr::JudyL, idx1::Uint, idx2::Uint) = ccall((:JudyLCount, _judylib), Uint, (Ptr{Void}, Uint, Uint, Ptr{Void}), arr.b.jarr, idx1, idx2, C_NULL)


## locate the nth index that is present (n starts wih 1)
## to refer to the last index in a fully populated array (all indexes present, which is rare), use n = 0.
## return tuple (1, index_pos) on success or (0, undefined) on not found/error
ju_by_count(arr::Judy1, n::Integer) = ju_by_count(arr, convert(Uint, n))
function ju_by_count(arr::Judy1, n::Uint)
    ret::Int32 = ccall((:Judy1ByCount, _judylib), Int32, (Ptr{Void}, Uint, Ptr{Uint}, Ptr{Void}), arr.b.jarr, n, arr.b.nth_idx, C_NULL)
    return (ret, arr.b.nth_idx[1])
end


## locate the nth index that is present (n starts wih 1)
## return tuple (value at index, pointer to value, index_pos) on success or (undefined, C_NULL, undefined) on not found/error
ju_by_count(arr::JudyL, n::Integer) = ju_by_count(arr, convert(Uint, n))
function ju_by_count(arr::JudyL, n::Uint)
    ret::Ptr{Uint} = ccall((:JudyLByCount, _judylib), Ptr{Uint}, (Ptr{Void}, Uint, Ptr{Uint}, Ptr{Void}), arr.b.jarr, n, arr.b.nth_idx, C_NULL)
    ret_val::Uint = (ret != C_NULL) ? unsafe_ref(ret) : C_NULL
    return (ret_val, ret, arr.b.nth_idx[1])
end

macro _strlen(ba)
    quote
        ccall((:strlen, "libc"), Uint, (Ptr{Uint8},), $(ba))
    end
end

macro _strcpy(dest, src)
    quote
        ccall((:strcpy, "libc"), Ptr{Uint8}, (Ptr{Uint8},Ptr{Uint8}), $(dest), $(src))
    end
end

## iterators. return tuple of (value, index)
start(arr::Judy1) = ju_first(arr)
done(arr::Judy1, state) = (0 == state[1])
next(arr::Judy1, state) = done(arr, state) ? (Nothing, state) : ((true, state[2]), ju_next(arr))

start(arr::JudyL) = ju_first(arr)
done(arr::JudyL, state) = (C_NULL == state[2])
next(arr::JudyL, state) = done(arr, state) ? (Nothing, state) : ((state[1], state[3]), ju_next(arr))

start(arr::JudySL) = ju_first(arr)
done(arr::JudySL, state) = (C_NULL == state[2])
next(arr::JudySL, state) = done(arr, state) ? (Nothing, state) : ((state[1], state[3]), ju_next(arr))

## The base iteration methods
## These return a pointer to the value as well
ju_first(arr::Judy1) = ju_first(arr, uint(0))
ju_first(arr::Judy1, idx::Integer) = ju_first(arr, convert(Uint, idx))
function ju_first(arr::Judy1, idx::Uint)
    arr.b.nth_idx[1] = idx
    ret::Int32 = ccall((:Judy1First, _judylib), Int32, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.b.jarr, arr.b.nth_idx, C_NULL)
    return (ret, arr.b.nth_idx[1])
end

ju_first(arr::JudyL) = ju_first(arr, uint(0))
ju_first(arr::JudyL, idx::Integer) = ju_first(arr, convert(Uint, idx))
function ju_first(arr::JudyL, idx::Uint)
    arr.b.nth_idx[1] = idx
    ret::Ptr{Uint} = ccall((:JudyLFirst, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.b.jarr, arr.b.nth_idx, C_NULL)
    ret_val::Uint = (ret != C_NULL) ? unsafe_ref(ret) : C_NULL
    return (ret_val, ret, arr.b.nth_idx[1])
end

ju_first(arr::JudySL) = ju_first(arr, "")
function ju_first(arr::JudySL, idx::String)
    @assert length(idx) < MAX_STR_IDX_LEN
    @_strcpy arr.b.nth_idx bytestring(idx)
    ret::Ptr{Uint} = ccall((:JudySLFirst, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint8}, Ptr{Void}), arr.b.jarr, arr.b.nth_idx, C_NULL)
    if(ret != C_NULL)
        ret_val::Uint = unsafe_ref(ret)
        len::Uint = @_strlen arr.b.nth_idx
        (ret_val, ret, ASCIIString(arr.b.nth_idx[1:len]))
    else
        (uint(0), C_NULL, "")
    end
end


ju_next(arr::Judy1, idx::Integer) = ju_next(arr, convert(Uint, idx))
function ju_next(arr::Judy1, idx::Uint)
    arr.b.nth_idx[1] = idx
    ju_next(arr)
end
function ju_next(arr::Judy1)
    ret::Int32 = ccall((:Judy1Next, _judylib), Int32, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.b.jarr, arr.b.nth_idx, C_NULL)
    return (ret, arr.b.nth_idx[1])
end


ju_next(arr::JudyL, idx::Integer) = ju_next(arr, convert(Uint, idx))
function ju_next(arr::JudyL, idx::Uint)
    arr.b.nth_idx[1] = idx
    ju_next(arr)
end
function ju_next(arr::JudyL)
    ret::Ptr{Uint} = ccall((:JudyLNext, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.b.jarr, arr.b.nth_idx, C_NULL)
    ret_val::Uint = (ret != C_NULL) ? unsafe_ref(ret) : C_NULL
    return (ret_val, ret, arr.b.nth_idx[1])
end

function ju_next(arr::JudySL, idx::String)
    @assert length(idx) < MAX_STR_IDX_LEN
    @_strcpy arr.b.nth_idx bytestring(idx)
    ju_next(arr)
end
function ju_next(arr::JudySL)
    ret::Ptr{Uint} = ccall((:JudySLNext, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint8}, Ptr{Void}), arr.b.jarr, arr.b.nth_idx, C_NULL)
    if(ret != C_NULL)
        ret_val::Uint = unsafe_ref(ret)
        len::Uint = @_strlen arr.b.nth_idx
        (ret_val, ret, ASCIIString(arr.b.nth_idx[1:len]))
    else
        (uint(0), C_NULL, "")
    end
end


ju_last(arr::Judy1) = ju_last(arr, -1)
ju_last(arr::Judy1, idx::Integer) = ju_last(arr, convert(Uint, idx))
function ju_last(arr::Judy1, idx::Uint)
    arr.b.nth_idx[1] = idx
    ret::Int32 = ccall((:Judy1Last, _judylib), Int32, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.b.jarr, arr.b.nth_idx, C_NULL)
    return (ret, arr.b.nth_idx[1])
end

ju_last(arr::JudyL) = ju_last(arr, -1)
ju_last(arr::JudyL, idx::Integer) = ju_last(arr, convert(Uint, idx))
function ju_last(arr::JudyL, idx::Uint)
    arr.b.nth_idx[1] = idx
    ret::Ptr{Uint} = ccall((:JudyLLast, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.b.jarr, arr.b.nth_idx, C_NULL)
    ret_val::Uint = (ret != C_NULL) ? unsafe_ref(ret) : C_NULL
    return (ret_val, ret, arr.b.nth_idx[1])
end

function ju_last(arr::JudySL)
    ccall((:memset, "libc"), Ptr{Uint8}, (Ptr{Uint8}, Uint8, Uint), arr.b.nth_idx, 0xff, MAX_STR_IDX_LEN-1)
    arr.b.nth_idx[MAX_STR_IDX_LEN-1] = 0
    ret::Ptr{Uint} = ccall((:JudySLLast, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint8}, Ptr{Void}), arr.b.jarr, arr.b.nth_idx, C_NULL)
    if(ret != C_NULL)
        ret_val::Uint = unsafe_ref(ret)
        len::Uint = @_strlen arr.b.nth_idx
        (ret_val, ret, ASCIIString(arr.b.nth_idx[1:len]))
    else
        (uint(0), C_NULL, "")
    end
end
function ju_last(arr::JudySL, idx::String)
    @assert length(idx) < MAX_STR_IDX_LEN
    @_strcpy arr.b.nth_idx bytestring(idx)
    ret::Ptr{Uint} = ccall((:JudySLLast, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint8}, Ptr{Void}), arr.b.jarr, arr.b.nth_idx, C_NULL)
    if(ret != C_NULL)
        ret_val::Uint = unsafe_ref(ret)
        len::Uint = @_strlen arr.b.nth_idx
        (ret_val, ret, ASCIIString(arr.b.nth_idx[1:len]))
    else
        (uint(0), C_NULL, "")
    end
end


ju_prev(arr::Judy1, idx::Integer) = ju_prev(arr, convert(Uint, idx))
function ju_prev(arr::Judy1, idx::Uint)
    arr.b.nth_idx[1] = idx
    ju_prev(arr)
end
function ju_prev(arr::Judy1)
    ret::Int32 = ccall((:Judy1Prev, _judylib), Int32, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.b.jarr, arr.b.nth_idx, C_NULL)
    return (ret, arr.b.nth_idx[1])
end


ju_prev(arr::JudyL, idx::Integer) = ju_prev(arr, convert(Uint, idx))
function ju_prev(arr::JudyL, idx::Uint)
    arr.b.nth_idx[1] = idx
    ju_prev(arr)
end
function ju_prev(arr::JudyL)
    ret::Ptr{Uint} = ccall((:JudyLPrev, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.b.jarr, arr.b.nth_idx, C_NULL)
    ret_val::Uint = (ret != C_NULL) ? unsafe_ref(ret) : C_NULL
    return (ret_val, ret, arr.b.nth_idx[1])
end

function ju_prev(arr::JudySL, idx::String)
    @assert length(idx) < MAX_STR_IDX_LEN
    @_strcpy arr.b.nth_idx bytestring(idx)
    ju_prev(arr)
end
function ju_prev(arr::JudySL)
    ret::Ptr{Uint} = ccall((:JudySLPrev, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.b.jarr, arr.b.nth_idx, C_NULL)
    if(ret != C_NULL)
        ret_val::Uint = unsafe_ref(ret)
        len::Uint = @_strlen arr.b.nth_idx
        (ret_val, ret, ASCIIString(arr.b.nth_idx[1:len]))
    else
        (0, C_NULL, "")
    end
end


macro _ju_iter_empty_cont(arr, fn)
    quote
        ret::Int32 = ccall(($(fn), _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), $(arr).b.jarr, $(arr).b.nth_idx, C_NULL)
        (ret, $(arr).b.nth_idx[1])
    end
end

macro _ju_iter_empty(arr, idx, fn)
    quote
        $(arr).b.nth_idx[1] = $(idx)
        @_ju_iter_empty_cont $(arr) $(fn)
    end
end

ju_first_empty(arr::Judy1) = ju_first_empty(arr, uint(0))
ju_first_empty(arr::Judy1, idx::Integer) = ju_first_empty(arr, convert(Uint, idx))
ju_first_empty(arr::Judy1, idx::Uint) = @_ju_iter_empty arr idx :Judy1FirstEmpty

ju_first_empty(arr::JudyL) = ju_first_empty(arr, uint(0))
ju_first_empty(arr::JudyL, idx::Integer) = ju_first_empty(arr, convert(Uint, idx))
ju_first_empty(arr::JudyL, idx::Uint) = @_ju_iter_empty arr idx :JudyLFirstEmpty

ju_next_empty(arr::Judy1, idx::Integer) = ju_next_empty(arr, convert(Uint, idx))
ju_next_empty(arr::Judy1, idx::Uint) = @_ju_iter_empty arr idx :Judy1NextEmpty
ju_next_empty(arr::Judy1) = @_ju_iter_empty_cont arr :Judy1NextEmpty

ju_next_empty(arr::JudyL, idx::Integer) = ju_next_empty(arr, convert(Uint, idx))
ju_next_empty(arr::JudyL, idx::Uint) = @_ju_iter_empty arr idx :JudyLNextEmpty
ju_next_empty(arr::JudyL) = @_ju_iter_empty_cont arr :JudyLNextEmpty

ju_last_empty(arr::Judy1) = ju_last_empty(arr, uint(-1))
ju_last_empty(arr::Judy1, idx::Integer) = ju_last_empty(arr, convert(Uint, idx))
ju_last_empty(arr::Judy1, idx::Uint) = @_ju_iter_empty arr idx :Judy1LastEmpty

ju_last_empty(arr::JudyL) = ju_last_empty(arr, uint(-1))
ju_last_empty(arr::JudyL, idx::Integer) = ju_last_empty(arr, convert(Uint, idx))
ju_last_empty(arr::JudyL, idx::Uint) = @_ju_iter_empty arr idx :JudyLLastEmpty

ju_prev_empty(arr::Judy1, idx::Integer) = ju_prev_empty(arr, convert(Uint, idx))
ju_prev_empty(arr::Judy1, idx::Uint) = @_ju_iter_empty arr idx :JudyLPrevEmpty
ju_prev_empty(arr::Judy1) = @_ju_iter_empty_cont arr :JudyLPrevEmpty

ju_prev_empty(arr::JudyL, idx::Integer) = ju_prev_empty(arr, convert(Uint, idx))
ju_prev_empty(arr::JudyL, idx::Uint) = @_ju_iter_empty arr idx :JudyLPrevEmpty
ju_prev_empty(arr::JudyL) = @_ju_iter_empty_cont arr :JudyLPrevEmpty

end
