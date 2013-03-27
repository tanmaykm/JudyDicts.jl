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
const EMSG_UNSUP_TYPE = "no JudyArray available for this key and value type combination"

export JudyArray
export ju_set, ju_unset, ju_get
export ju_mem_used
export ju_count, ju_by_count
export ju_first, ju_next, ju_last, ju_prev
export ju_first_empty, ju_next_empty, ju_last_empty, ju_prev_empty

type JudyArray{Tk, Tv}
    jarr::Ptr{Void}
    pjarr::Array{Ptr{Void}}
    nth_idx::Array
    function JudyArray()
        if((Tk <: Integer) && ((Tv <: Bool) || (Tv <: Integer)))
            j = new(C_NULL, zeros(Ptr{Void},1), zeros(Uint, 1))
        elseif((Tk <: String) && (Tv <: Integer))
            j = new(C_NULL, zeros(Ptr{Void},1), zeros(Uint8, MAX_STR_IDX_LEN))
        elseif((Tk <: Array{Uint8}) && (Tv <: Integer))
            j = new(C_NULL, zeros(Ptr{Void},1), zeros(Uint8, 0))
        else
            error(EMSG_UNSUP_TYPE)
        end
        finalizer(j, ju_free)
        j
    end
end


show(io::IO, j::JudyArray{Integer, Bool}) = println(io, (j.jarr == C_NULL) ? "$(typeof(j)) (empty)" : "$(typeof(j)) (count: $(dec(ju_count(j))))")
show(io::IO, j::JudyArray{Integer, Integer}) = println(io, (j.jarr == C_NULL) ? "$(typeof(j)) (empty)" : "$(typeof(j)) (count: $(dec(ju_count(j))))")
show(io::IO, j::JudyArray{String, Integer}) = println(io, (j.jarr == C_NULL) ? "$(typeof(j)) (empty)" : "$(typeof(j)) (populated)")
show(io::IO, j::JudyArray{Array{Uint8}, Integer}) = println(io, (j.jarr == C_NULL) ? "$(typeof(j)) (empty)" : "$(typeof(j)) (populated)")

macro _ju_free(arr, fn)
    quote
        ret::Uint = ccall(($(fn), _judylib), Uint, (Ptr{Ptr{Void}}, Ptr{Void}), $(arr).pjarr, C_NULL)
        $(arr).jarr = $(arr).pjarr[1]
        ret
    end
end

ju_free(arr::JudyArray{Integer, Bool}) = @_ju_free arr :Judy1FreeArray
ju_free(arr::JudyArray{Integer, Integer}) = @_ju_free arr :JudyLFreeArray
ju_free(arr::JudyArray{String, Integer}) = @_ju_free arr :JudySLFreeArray
ju_free(arr::JudyArray{Array{Uint8}, Integer}) = @_ju_free arr :JudyHSFreeArray

## returns bytes of memory used currently by the judy array
ju_mem_used(arr::JudyArray{Integer, Bool}) = ccall((:Judy1MemUsed, _judylib), Uint, (Ptr{Void},), arr.jarr)
ju_mem_used(arr::JudyArray{Integer, Integer}) = ccall((:JudyLMemUsed, _judylib), Uint, (Ptr{Void},), arr.jarr)

##
## INDEXABLE COLLECTIONS BEGIN
##

macro _unset(arr, val, idx)
    quote
        (Nothing == val) ? (ju_unset(arr, idx); Nothing) : error("Unknown value type: $(typeof(val))")
    end
end

macro _get(arr, idx)
    quote
        local ret_tuple = ju_get(arr, idx)
        (ret_tuple[2] == C_NULL) ? Nothing : ret_tuple[1]
    end
end

setindex!(arr::JudyArray{Integer, Bool}, isset::Bool, idx::Integer) = isset ? ju_set(arr, idx) : ju_unset(arr, idx)
getindex(arr::JudyArray{Integer, Bool}, idx::Integer) = (ju_get(arr, idx) == 1)

setindex!(arr::JudyArray{Integer, Integer}, val::Any, idx::Integer) = @_unset arr val idx
setindex!(arr::JudyArray{Integer, Integer}, val::Integer, idx::Integer) = (C_NULL != ju_set(arr, idx, val)) ? val : error("Error setting value")
getindex(arr::JudyArray{Integer, Integer}, idx::Integer) = @_get arr idx

setindex!(arr::JudyArray{String, Integer}, val::Integer, idx::String) = (C_NULL != ju_set(arr, idx, val)) ? val : error("Error setting value")
setindex!(arr::JudyArray{String, Integer}, val::Any, idx::String) = @_unset arr val idx
getindex(arr::JudyArray{String, Integer}, idx::String) = @_get arr idx

setindex!(arr::JudyArray{Array{Uint8}, Integer}, val::Any, idx::Array{Uint8}) = @_unset arr val idx
setindex!(arr::JudyArray{Array{Uint8}, Integer}, val::Integer, idx::Array{Uint8}) = (C_NULL != ju_set(arr, idx, val)) ? val : error("Error setting value")
getindex(arr::JudyArray{Array{Uint8}, Integer}, idx::Array{Uint8}) = @_get arr idx

length(arr::JudyArray{Integer, Bool}) = ju_count(arr)
length(arr::JudyArray{Integer, Integer}) = ju_count(arr)

##
## INDEXABLE COLLECTIONS END
##

## set bit at the index
## return 1 if bit was previously unset (successful), otherwise 0 if the bit was already set (unsuccessful).
function ju_set(arr::JudyArray{Integer, Bool}, idx::Integer)
    ret::Int32 = ccall((:Judy1Set, _judylib), Int32, (Ptr{Ptr{Void}}, Uint, Ptr{Void}), arr.pjarr, convert(Uint, idx), C_NULL)
    arr.jarr = arr.pjarr[1]
    return ret
end


## set value (val) at index (idx)
## return a pointer to the value. the pointer is valid till the next call to a judy method.
## return C_NULL on error
function ju_set(arr::JudyArray{Integer, Integer}, idx::Integer, val::Integer)
    ret::Ptr{Uint} = ccall((:JudyLIns, _judylib), Ptr{Uint}, (Ptr{Ptr{Void}}, Uint, Ptr{Void}), arr.pjarr, convert(Uint, idx), C_NULL)
    if (ret != C_NULL)
        unsafe_assign(ret, val)
        arr.jarr = arr.pjarr[1]
    end
    ret
end


function ju_set(arr::JudyArray{String, Integer}, idx::String, val::Integer)
    @assert length(idx) < MAX_STR_IDX_LEN
    ret::Ptr{Uint} = ccall((:JudySLIns, _judylib), Ptr{Uint}, (Ptr{Ptr{Void}}, Ptr{Uint8}, Ptr{Void}), arr.pjarr, bytestring(idx), C_NULL)
    if (ret != C_NULL)
        unsafe_assign(ret, convert(Uint, val))
        arr.jarr = arr.pjarr[1]
    end
    ret
end

function ju_set(arr::JudyArray{Array{Uint8}, Integer}, idx::Array{Uint8}, val::Integer)
    ret::Ptr{Uint} = ccall((:JudyHSIns, _judylib), Ptr{Uint}, (Ptr{Ptr{Void}}, Ptr{Uint8}, Uint, Ptr{Void}), arr.pjarr, idx, convert(Uint, length(idx)), C_NULL)
    if (ret != C_NULL)
        unsafe_assign(ret, convert(Uint, val))
        arr.jarr = arr.pjarr[1]
    end
    ret
end


## unset value at index
## return 1 if index was previously set (successful), otherwise 0 if the index was already unset (unsuccessful).
macro _ju_unset(arr, idx, itype, fn)
    quote
        local ret::Int32 = ccall(($(fn), _judylib), Int32, (Ptr{Ptr{Void}}, $(itype), Ptr{Void}), $(arr).pjarr, $(idx), C_NULL)
        $(arr).jarr = $(arr).pjarr[1]
        ret
    end
end

ju_unset(arr::JudyArray{Integer, Bool}, idx::Integer) = @_ju_unset arr convert(Uint, idx) Uint :Judy1Unset
ju_unset(arr::JudyArray{Integer, Integer}, idx::Integer) = @_ju_unset arr convert(Uint, idx) Uint :JudyLDel
ju_unset(arr::JudyArray{String, Integer}, idx::String) = @_ju_unset arr bytestring(idx) Ptr{Uint8} :JudySLDel
function ju_unset(arr::JudyArray{Array{Uint8}, Integer}, idx::Array{Uint8})
    ret::Int32 = ccall((:JudyHSDel, _judylib), Int32, (Ptr{Ptr{Void}}, Ptr{Uint8}, Uint, Ptr{Void}), arr.pjarr, idx, convert(Uint, length(idx)), C_NULL)
    arr.jarr = arr.pjarr[1]
    ret
end

## get the value at index (if set)
## return 1 if index's bit was set, 0 if it was unset (index was absent).
ju_get(arr::JudyArray{Integer, Bool}, idx::Integer) = ccall((:Judy1Test, _judylib), Int32, (Ptr{Void}, Uint, Ptr{Void}), arr.jarr, convert(Uint, idx), C_NULL)

## get the value at index (if set)
## return a tuple (value, pointer to value) if index's bit was set, (undefined, C_NULL) if it was unset (index was absent).
## the pointer is valid till the next call to a judy method.
function ju_get(arr::JudyArray{Array{Uint8}, Integer}, idx::Array{Uint8})
    ret::Ptr{Uint} = ccall((:JudyHSGet, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint8}, Uint, Ptr{Void}), arr.jarr, idx, convert(Uint, length(idx)), C_NULL)
    ((ret != C_NULL) ? unsafe_ref(ret) : C_NULL, ret)
end

macro _ju_get(arr, idx, itype, fn)
    quote
        local ret::Ptr{Uint} = ccall(($(fn), _judylib), Ptr{Uint}, (Ptr{Void}, $(itype), Ptr{Void}), $(arr).jarr, $(idx), C_NULL)
        ((ret != C_NULL) ? unsafe_ref(ret) : C_NULL, ret)
    end
end

ju_get(arr::JudyArray{Integer, Integer}, idx::Integer) = @_ju_get arr convert(Uint, idx) Uint :JudyLGet
ju_get(arr::JudyArray{String, Integer}, idx::String) = @_ju_get arr bytestring(idx) Ptr{Uint8} :JudySLGet

## count the number of indexes present between idx1 and idx2 (inclusive).
## returns the count.
## a return value of 0 can be valid as a count, or it can indicate a special case for fully populated array (32-bit machines only).
## see Judy documentation for ways to resolve this.
ju_count(arr::JudyArray{Integer, Bool}, idx1::Integer, idx2::Integer) = ju_count(arr, convert(Uint, idx1), convert(Uint, idx2))
ju_count(arr::JudyArray{Integer, Bool}, idx1::Uint, idx2::Uint) = ccall((:Judy1Count, _judylib), Uint, (Ptr{Void}, Uint, Uint, Ptr{Void}), arr.jarr, idx1, idx2, C_NULL)
ju_count(arr::JudyArray{Integer, Bool}) = ju_count(arr, 0, -1)
ju_count(arr::JudyArray{Integer, Integer}, idx1::Integer, idx2::Integer) = ju_count(arr, convert(Uint, idx1), convert(Uint, idx2))
ju_count(arr::JudyArray{Integer, Integer}, idx1::Uint, idx2::Uint) = ccall((:JudyLCount, _judylib), Uint, (Ptr{Void}, Uint, Uint, Ptr{Void}), arr.jarr, idx1, idx2, C_NULL)
ju_count(arr::JudyArray{Integer, Integer}) = ju_count(arr, 0, -1)


## locate the nth index that is present (n starts wih 1)
## to refer to the last index in a fully populated array (all indexes present, which is rare), use n = 0.
## return tuple (1, index_pos) on success or (0, undefined) on not found/error
function ju_by_count(arr::JudyArray{Integer, Bool}, n::Integer)
    ret::Int32 = ccall((:Judy1ByCount, _judylib), Int32, (Ptr{Void}, Uint, Ptr{Uint}, Ptr{Void}), arr.jarr, convert(Uint, n), arr.nth_idx, C_NULL)
    return (ret, arr.nth_idx[1])
end


## locate the nth index that is present (n starts wih 1)
## return tuple (value at index, pointer to value, index_pos) on success or (undefined, C_NULL, undefined) on not found/error
function ju_by_count(arr::JudyArray{Integer, Integer}, n::Integer)
    ret::Ptr{Uint} = ccall((:JudyLByCount, _judylib), Ptr{Uint}, (Ptr{Void}, Uint, Ptr{Uint}, Ptr{Void}), arr.jarr, convert(Uint, n), arr.nth_idx, C_NULL)
    ret_val::Uint = (ret != C_NULL) ? unsafe_ref(ret) : C_NULL
    return (ret_val, ret, arr.nth_idx[1])
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
start(arr::JudyArray{Integer, Bool}) = ju_first(arr)
done(arr::JudyArray{Integer, Bool}, state) = (0 == state[1])
next(arr::JudyArray{Integer, Bool}, state) = done(arr, state) ? (Nothing, state) : ((true, state[2]), ju_next(arr))

start(arr::JudyArray{Integer, Integer}) = ju_first(arr)
done(arr::JudyArray{Integer, Integer}, state) = (C_NULL == state[2])
next(arr::JudyArray{Integer, Integer}, state) = done(arr, state) ? (Nothing, state) : ((state[1], state[3]), ju_next(arr))

start(arr::JudyArray{String, Integer}) = ju_first(arr)
done(arr::JudyArray{String, Integer}, state) = (C_NULL == state[2])
next(arr::JudyArray{String, Integer}, state) = done(arr, state) ? (Nothing, state) : ((state[1], state[3]), ju_next(arr))

## The base iteration methods return a pointer to the value as well
ju_first(arr::JudyArray{Integer, Bool}) = ju_first(arr, uint(0))
ju_first(arr::JudyArray{Integer, Bool}, idx::Integer) = ju_first(arr, convert(Uint, idx))
function ju_first(arr::JudyArray{Integer, Bool}, idx::Uint)
    arr.nth_idx[1] = idx
    ret::Int32 = ccall((:Judy1First, _judylib), Int32, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.jarr, arr.nth_idx, C_NULL)
    return (ret, arr.nth_idx[1])
end

ju_first(arr::JudyArray{Integer, Integer}) = ju_first(arr, uint(0))
ju_first(arr::JudyArray{Integer, Integer}, idx::Integer) = ju_first(arr, convert(Uint, idx))
function ju_first(arr::JudyArray{Integer, Integer}, idx::Uint)
    arr.nth_idx[1] = idx
    ret::Ptr{Uint} = ccall((:JudyLFirst, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.jarr, arr.nth_idx, C_NULL)
    ret_val::Uint = (ret != C_NULL) ? unsafe_ref(ret) : C_NULL
    return (ret_val, ret, arr.nth_idx[1])
end

ju_first(arr::JudyArray{String, Integer}) = ju_first(arr, "")
function ju_first(arr::JudyArray{String, Integer}, idx::String)
    @assert length(idx) < MAX_STR_IDX_LEN
    @_strcpy arr.nth_idx bytestring(idx)
    ret::Ptr{Uint} = ccall((:JudySLFirst, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint8}, Ptr{Void}), arr.jarr, arr.nth_idx, C_NULL)
    if(ret != C_NULL)
        ret_val::Uint = unsafe_ref(ret)
        len::Uint = @_strlen arr.nth_idx
        (ret_val, ret, ASCIIString(arr.nth_idx[1:len]))
    else
        (uint(0), C_NULL, "")
    end
end


ju_next(arr::JudyArray{Integer, Bool}, idx::Integer) = ju_next(arr, convert(Uint, idx))
function ju_next(arr::JudyArray{Integer, Bool}, idx::Uint)
    arr.nth_idx[1] = idx
    ju_next(arr)
end
function ju_next(arr::JudyArray{Integer, Bool})
    ret::Int32 = ccall((:Judy1Next, _judylib), Int32, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.jarr, arr.nth_idx, C_NULL)
    return (ret, arr.nth_idx[1])
end


ju_next(arr::JudyArray{Integer, Integer}, idx::Integer) = ju_next(arr, convert(Uint, idx))
function ju_next(arr::JudyArray{Integer, Integer}, idx::Uint)
    arr.nth_idx[1] = idx
    ju_next(arr)
end
function ju_next(arr::JudyArray{Integer, Integer})
    ret::Ptr{Uint} = ccall((:JudyLNext, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.jarr, arr.nth_idx, C_NULL)
    ret_val::Uint = (ret != C_NULL) ? unsafe_ref(ret) : C_NULL
    return (ret_val, ret, arr.nth_idx[1])
end

function ju_next(arr::JudyArray{String, Integer}, idx::String)
    @assert length(idx) < MAX_STR_IDX_LEN
    @_strcpy arr.nth_idx bytestring(idx)
    ju_next(arr)
end
function ju_next(arr::JudyArray{String, Integer})
    ret::Ptr{Uint} = ccall((:JudySLNext, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint8}, Ptr{Void}), arr.jarr, arr.nth_idx, C_NULL)
    if(ret != C_NULL)
        ret_val::Uint = unsafe_ref(ret)
        len::Uint = @_strlen arr.nth_idx
        (ret_val, ret, ASCIIString(arr.nth_idx[1:len]))
    else
        (uint(0), C_NULL, "")
    end
end


ju_last(arr::JudyArray{Integer, Bool}) = ju_last(arr, -1)
ju_last(arr::JudyArray{Integer, Bool}, idx::Integer) = ju_last(arr, convert(Uint, idx))
function ju_last(arr::JudyArray{Integer, Bool}, idx::Uint)
    arr.nth_idx[1] = idx
    ret::Int32 = ccall((:Judy1Last, _judylib), Int32, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.jarr, arr.nth_idx, C_NULL)
    return (ret, arr.nth_idx[1])
end

ju_last(arr::JudyArray{Integer, Integer}) = ju_last(arr, -1)
ju_last(arr::JudyArray{Integer, Integer}, idx::Integer) = ju_last(arr, convert(Uint, idx))
function ju_last(arr::JudyArray{Integer, Integer}, idx::Uint)
    arr.nth_idx[1] = idx
    ret::Ptr{Uint} = ccall((:JudyLLast, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.jarr, arr.nth_idx, C_NULL)
    ret_val::Uint = (ret != C_NULL) ? unsafe_ref(ret) : C_NULL
    return (ret_val, ret, arr.nth_idx[1])
end

function ju_last(arr::JudyArray{String, Integer})
    ccall((:memset, "libc"), Ptr{Uint8}, (Ptr{Uint8}, Uint8, Uint), arr.nth_idx, 0xff, MAX_STR_IDX_LEN-1)
    arr.nth_idx[MAX_STR_IDX_LEN-1] = 0
    ret::Ptr{Uint} = ccall((:JudySLLast, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint8}, Ptr{Void}), arr.jarr, arr.nth_idx, C_NULL)
    if(ret != C_NULL)
        ret_val::Uint = unsafe_ref(ret)
        len::Uint = @_strlen arr.nth_idx
        (ret_val, ret, ASCIIString(arr.nth_idx[1:len]))
    else
        (uint(0), C_NULL, "")
    end
end
function ju_last(arr::JudyArray{String, Integer}, idx::String)
    @assert length(idx) < MAX_STR_IDX_LEN
    @_strcpy arr.nth_idx bytestring(idx)
    ret::Ptr{Uint} = ccall((:JudySLLast, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint8}, Ptr{Void}), arr.jarr, arr.nth_idx, C_NULL)
    if(ret != C_NULL)
        ret_val::Uint = unsafe_ref(ret)
        len::Uint = @_strlen arr.nth_idx
        (ret_val, ret, ASCIIString(arr.nth_idx[1:len]))
    else
        (uint(0), C_NULL, "")
    end
end


ju_prev(arr::JudyArray{Integer, Bool}, idx::Integer) = ju_prev(arr, convert(Uint, idx))
function ju_prev(arr::JudyArray{Integer, Bool}, idx::Uint)
    arr.nth_idx[1] = idx
    ju_prev(arr)
end
function ju_prev(arr::JudyArray{Integer, Bool})
    ret::Int32 = ccall((:Judy1Prev, _judylib), Int32, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.jarr, arr.nth_idx, C_NULL)
    return (ret, arr.nth_idx[1])
end


ju_prev(arr::JudyArray{Integer, Integer}, idx::Integer) = ju_prev(arr, convert(Uint, idx))
function ju_prev(arr::JudyArray{Integer, Integer}, idx::Uint)
    arr.nth_idx[1] = idx
    ju_prev(arr)
end
function ju_prev(arr::JudyArray{Integer, Integer})
    ret::Ptr{Uint} = ccall((:JudyLPrev, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.jarr, arr.nth_idx, C_NULL)
    ret_val::Uint = (ret != C_NULL) ? unsafe_ref(ret) : C_NULL
    return (ret_val, ret, arr.nth_idx[1])
end

function ju_prev(arr::JudyArray{String, Integer}, idx::String)
    @assert length(idx) < MAX_STR_IDX_LEN
    @_strcpy arr.nth_idx bytestring(idx)
    ju_prev(arr)
end
function ju_prev(arr::JudyArray{String, Integer})
    ret::Ptr{Uint} = ccall((:JudySLPrev, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.jarr, arr.nth_idx, C_NULL)
    if(ret != C_NULL)
        ret_val::Uint = unsafe_ref(ret)
        len::Uint = @_strlen arr.nth_idx
        (ret_val, ret, ASCIIString(arr.nth_idx[1:len]))
    else
        (0, C_NULL, "")
    end
end


macro _ju_iter_empty_cont(arr, fn)
    quote
        ret::Int32 = ccall(($(fn), _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), $(arr).jarr, $(arr).nth_idx, C_NULL)
        (ret, $(arr).nth_idx[1])
    end
end

macro _ju_iter_empty(arr, idx, fn)
    quote
        $(arr).nth_idx[1] = $(idx)
        @_ju_iter_empty_cont $(arr) $(fn)
    end
end

ju_first_empty(arr::JudyArray{Integer, Bool}) = ju_first_empty(arr, uint(0))
ju_first_empty(arr::JudyArray{Integer, Bool}, idx::Integer) = ju_first_empty(arr, convert(Uint, idx))
ju_first_empty(arr::JudyArray{Integer, Bool}, idx::Uint) = @_ju_iter_empty arr idx :Judy1FirstEmpty

ju_first_empty(arr::JudyArray{Integer, Integer}) = ju_first_empty(arr, uint(0))
ju_first_empty(arr::JudyArray{Integer, Integer}, idx::Integer) = ju_first_empty(arr, convert(Uint, idx))
ju_first_empty(arr::JudyArray{Integer, Integer}, idx::Uint) = @_ju_iter_empty arr idx :JudyLFirstEmpty

ju_next_empty(arr::JudyArray{Integer, Bool}, idx::Integer) = ju_next_empty(arr, convert(Uint, idx))
ju_next_empty(arr::JudyArray{Integer, Bool}, idx::Uint) = @_ju_iter_empty arr idx :Judy1NextEmpty
ju_next_empty(arr::JudyArray{Integer, Bool}) = @_ju_iter_empty_cont arr :Judy1NextEmpty

ju_next_empty(arr::JudyArray{Integer, Integer}, idx::Integer) = ju_next_empty(arr, convert(Uint, idx))
ju_next_empty(arr::JudyArray{Integer, Integer}, idx::Uint) = @_ju_iter_empty arr idx :JudyLNextEmpty
ju_next_empty(arr::JudyArray{Integer, Integer}) = @_ju_iter_empty_cont arr :JudyLNextEmpty

ju_last_empty(arr::JudyArray{Integer, Bool}) = ju_last_empty(arr, uint(-1))
ju_last_empty(arr::JudyArray{Integer, Bool}, idx::Integer) = ju_last_empty(arr, convert(Uint, idx))
ju_last_empty(arr::JudyArray{Integer, Bool}, idx::Uint) = @_ju_iter_empty arr idx :Judy1LastEmpty

ju_last_empty(arr::JudyArray{Integer, Integer}) = ju_last_empty(arr, uint(-1))
ju_last_empty(arr::JudyArray{Integer, Integer}, idx::Integer) = ju_last_empty(arr, convert(Uint, idx))
ju_last_empty(arr::JudyArray{Integer, Integer}, idx::Uint) = @_ju_iter_empty arr idx :JudyLLastEmpty

ju_prev_empty(arr::JudyArray{Integer, Bool}, idx::Integer) = ju_prev_empty(arr, convert(Uint, idx))
ju_prev_empty(arr::JudyArray{Integer, Bool}, idx::Uint) = @_ju_iter_empty arr idx :JudyLPrevEmpty
ju_prev_empty(arr::JudyArray{Integer, Bool}) = @_ju_iter_empty_cont arr :JudyLPrevEmpty

ju_prev_empty(arr::JudyArray{Integer, Integer}, idx::Integer) = ju_prev_empty(arr, convert(Uint, idx))
ju_prev_empty(arr::JudyArray{Integer, Integer}, idx::Uint) = @_ju_iter_empty arr idx :JudyLPrevEmpty
ju_prev_empty(arr::JudyArray{Integer, Integer}) = @_ju_iter_empty_cont arr :JudyLPrevEmpty

end
