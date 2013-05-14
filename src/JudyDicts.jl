module JudyDicts

import  Base.getindex,
        Base.setindex!,
        Base.show,
        Base.length,
        Base.start,
        Base.done,
        Base.next

const _judylib = "libJudy"
const MAX_STR_IDX_LEN = (1024*10)
const EMSG_UNSUP_TYPE = "no JudyDict available for this key and value type combination"

export  JudyDict,
        ju_set, ju_unset, ju_get,
        ju_mem_used,
        ju_count, ju_by_count,
        ju_first, ju_next, ju_last, ju_prev,
        ju_first_empty, ju_next_empty, ju_last_empty, ju_prev_empty

type JudyDict{Tk, Tv}
    pjarr::Array{Ptr{Void}}
    nth_idx::Array
    gc_store::ObjectIdDict
    function JudyDict()
        if(Tk <: Int)
            j = new(zeros(Ptr{Void},1), zeros(Uint, 1), ObjectIdDict())
        elseif(Tk <: Array{Uint8})
            j = new(zeros(Ptr{Void},1), zeros(Uint8, 0), ObjectIdDict())
        elseif(Tk <: String)
            j = new(zeros(Ptr{Void},1), zeros(Uint8, MAX_STR_IDX_LEN), ObjectIdDict())
        else
            error(EMSG_UNSUP_TYPE)
        end
        finalizer(j, ju_free)
        j
    end
end


show(io::IO, j::JudyDict{Int, Bool}) = println(io, (j.pjarr[1] == C_NULL) ? "$(typeof(j)) (empty)" : "$(typeof(j)) (count: $(dec(ju_count(j))))")
show(io::IO, j::JudyDict{Int, Int}) = println(io, (j.pjarr[1] == C_NULL) ? "$(typeof(j)) (empty)" : "$(typeof(j)) (count: $(dec(ju_count(j))))")
show{K,V}(io::IO, j::JudyDict{K, V}) = println(io, (j.pjarr[1] == C_NULL) ? "$(typeof(j)) (empty)" : "$(typeof(j)) (populated)")

macro _ju_free(arr, fn)
    quote
        ccall(($(fn), _judylib), Uint, (Ptr{Ptr{Void}}, Ptr{Void}), $(arr).pjarr, C_NULL)
    end
end

ju_free(arr::JudyDict{Int, Bool}) = @_ju_free arr :Judy1FreeArray
ju_free{V}(arr::JudyDict{Int,V}) = @_ju_free arr :JudyLFreeArray
ju_free{V}(arr::JudyDict{String,V}) = @_ju_free arr :JudySLFreeArray
ju_free{V}(arr::JudyDict{Array{Uint8},V}) = @_ju_free arr :JudyHSFreeArray

## returns bytes of memory used currently by the judy array
ju_mem_used(arr::JudyDict{Int, Bool}) = ccall((:Judy1MemUsed, _judylib), Uint, (Ptr{Void},), arr.pjarr[1])
ju_mem_used{V}(arr::JudyDict{Int,V}) = ccall((:JudyLMemUsed, _judylib), Uint, (Ptr{Void},), arr.pjarr[1])

##
## INDEXABLE COLLECTIONS BEGIN
##

macro _unset(arr, val, idx)
    quote
        (Nothing == val) ? (ju_unset(arr, idx); Nothing) : error("Unknown value type: $(typeof(val))")
    end
end

setindex!(arr::JudyDict{Int, Bool}, isset::Bool, idx::Int) = isset ? ju_set(arr, idx) : ju_unset(arr, idx)
getindex(arr::JudyDict{Int, Bool}, idx::Int) = (ju_get(arr, idx) == 1)

setindex!(arr::JudyDict{Int, Int}, val::Any, idx::Int) = @_unset arr val idx
setindex!(arr::JudyDict{Int, Int}, val::Int, idx::Int) = (C_NULL != ju_set(arr, idx, val)) ? val : error("Error setting value")
setindex!{V}(arr::JudyDict{Int,V}, val::V, idx::Int) = (C_NULL != ju_set(arr, idx, val)) ? val : error("Error setting value")
getindex{V}(arr::JudyDict{Int,V}, idx::Int) = ju_get(arr, idx)[1] 


setindex!(arr::JudyDict{String, Int}, val::Any, idx::String) = @_unset arr val idx
setindex!(arr::JudyDict{String, Int}, val::Int, idx::String) = (C_NULL != ju_set(arr, idx, val)) ? val : error("Error setting value")
setindex!{V}(arr::JudyDict{String, V}, val::V, idx::String) = (C_NULL != ju_set(arr, idx, val)) ? val : error("Error setting value")
getindex{V}(arr::JudyDict{String, V}, idx::String) = ju_get(arr, idx)[1] 

setindex!(arr::JudyDict{Array{Uint8}, Int}, val::Any, idx::Array{Uint8}) = @_unset arr val idx
setindex!(arr::JudyDict{Array{Uint8}, Int}, val::Integer, idx::Array{Uint8}) = (C_NULL != ju_set(arr, idx, val)) ? val : error("Error setting value")
getindex(arr::JudyDict{Array{Uint8}, Int}, idx::Array{Uint8}) = ju_get(arr, idx)[1] 

length(arr::JudyDict{Int, Bool}) = int(ju_count(arr))
length{V}(arr::JudyDict{Int,V}) = int(ju_count(arr))

##
## INDEXABLE COLLECTIONS END
##

## set bit at the index
## return 1 if bit was previously unset (successful), otherwise 0 if the bit was already set (unsuccessful).
ju_set(arr::JudyDict{Int, Bool}, idx::Int) = ccall((:Judy1Set, _judylib), Int32, (Ptr{Ptr{Void}}, Uint, Ptr{Void}), arr.pjarr, convert(Uint, idx), C_NULL)

## set value (val) at index (idx)
## return a pointer to the value. the pointer is valid till the next call to a judy method.
## return C_NULL on error
function ju_set{V}(arr::JudyDict{Int,V}, idx::Int, val::V)
    ju_unset(arr, idx)      # unset first to remove old object from gc_store
    ret::Ptr{Uint} = ccall((:JudyLIns, _judylib), Ptr{Uint}, (Ptr{Ptr{Void}}, Uint, Ptr{Void}), arr.pjarr, convert(Uint, idx), C_NULL)
    if (ret != C_NULL)
        arr.gc_store[val] = val
        unsafe_store!(ret, convert(Uint, pointer_from_objref(val)))
    end
    ret
end
function ju_set(arr::JudyDict{Int, Int}, idx::Int, val::Int)
    ret::Ptr{Uint} = ccall((:JudyLIns, _judylib), Ptr{Uint}, (Ptr{Ptr{Void}}, Uint, Ptr{Void}), arr.pjarr, convert(Uint, idx), C_NULL)
    if (ret != C_NULL)
        unsafe_store!(ret, convert(Uint, val))
    end
    ret
end

function ju_set{V}(arr::JudyDict{String, V}, idx::String, val::V)
    @assert length(idx) < MAX_STR_IDX_LEN
    ju_unset(arr, idx)      # unset first to remove old object from gc_store
    ret::Ptr{Uint} = ccall((:JudySLIns, _judylib), Ptr{Uint}, (Ptr{Ptr{Void}}, Ptr{Uint8}, Ptr{Void}), arr.pjarr, idx, C_NULL)
    if (ret != C_NULL)
        arr.gc_store[val] = val
        unsafe_store!(ret, convert(Uint, pointer_from_objref(val)))
    end
    ret
end

function ju_set(arr::JudyDict{String, Int}, idx::String, val::Int)
    @assert length(idx) < MAX_STR_IDX_LEN
    ret::Ptr{Uint} = ccall((:JudySLIns, _judylib), Ptr{Uint}, (Ptr{Ptr{Void}}, Ptr{Uint8}, Ptr{Void}), arr.pjarr, bytestring(idx), C_NULL)
    if (ret != C_NULL)
        unsafe_store!(ret, convert(Uint, val))
    end
    ret
end

function ju_set(arr::JudyDict{Array{Uint8}, Int}, idx::Array{Uint8}, val::Int)
    ret::Ptr{Uint} = ccall((:JudyHSIns, _judylib), Ptr{Uint}, (Ptr{Ptr{Void}}, Ptr{Uint8}, Uint, Ptr{Void}), arr.pjarr, idx, convert(Uint, length(idx)), C_NULL)
    if (ret != C_NULL)
        unsafe_store!(ret, convert(Uint, val))
    end
    ret
end


## get the value at index (if set)
## return 1 if index's bit was set, 0 if it was unset (index was absent).
ju_get(arr::JudyDict{Int, Bool}, idx::Int) = ccall((:Judy1Test, _judylib), Int32, (Ptr{Void}, Uint, Ptr{Void}), arr.pjarr[1], convert(Uint, idx), C_NULL)

## get the value at index (if set)
## return a tuple (value, pointer to value) if index's bit was set, (undefined, C_NULL) if it was unset (index was absent).
## the pointer is valid till the next call to a judy method.
function ju_get(arr::JudyDict{Array{Uint8}, Int}, idx::Array{Uint8})
    ret::Ptr{Uint} = ccall((:JudyHSGet, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint8}, Uint, Ptr{Void}), arr.pjarr[1], idx, convert(Uint, length(idx)), C_NULL)
    ((ret != C_NULL) ? unsafe_load(ret) : Nothing, ret)
end

macro _ju_get(arr, idx, itype, fn)
    quote
        local ret::Ptr{Uint} = ccall(($(fn), _judylib), Ptr{Uint}, (Ptr{Void}, $(itype), Ptr{Void}), $(arr).pjarr[1], $(idx), C_NULL)
        ((ret != C_NULL) ? unsafe_load(ret) : Nothing, ret)
    end
end

ju_get(arr::JudyDict{Int, Int}, idx::Int) = @_ju_get arr convert(Uint, idx) Uint :JudyLGet
ju_get(arr::JudyDict{String, Int}, idx::String) = @_ju_get arr bytestring(idx) Ptr{Uint8} :JudySLGet
function ju_get{V}(arr::JudyDict{Int,V}, idx::Int)
    ret_tuple = @_ju_get arr convert(Uint, idx) Uint :JudyLGet
    ((ret_tuple[2] != C_NULL) ? unsafe_pointer_to_objref(convert(Ptr{Void}, ret_tuple[1])) : Nothing, ret_tuple[2])
end
function ju_get{V}(arr::JudyDict{String,V}, idx::String)
    ret_tuple = @_ju_get arr bytestring(idx) Ptr{Uint8} :JudySLGet
    ((ret_tuple[2] != C_NULL) ? unsafe_pointer_to_objref(convert(Ptr{Void}, ret_tuple[1])) : Nothing, ret_tuple[2])
end


## unset value at index
## return 1 if index was previously set (successful), otherwise 0 if the index was already unset (unsuccessful).
macro _ju_unset(arr, idx, itype, fn)
    quote
        ccall(($(fn), _judylib), Int32, (Ptr{Ptr{Void}}, $(itype), Ptr{Void}), $(arr).pjarr, $(idx), C_NULL)
    end
end

ju_unset(arr::JudyDict{Int, Bool}, idx::Int) = @_ju_unset arr convert(Uint, idx) Uint :Judy1Unset
ju_unset(arr::JudyDict{Int, Int}, idx::Int) = @_ju_unset arr convert(Uint, idx) Uint :JudyLDel
ju_unset(arr::JudyDict{Array{Uint8}, Int}, idx::Array{Uint8}) = ccall((:JudyHSDel, _judylib), Int32, (Ptr{Ptr{Void}}, Ptr{Uint8}, Uint, Ptr{Void}), arr.pjarr, idx, convert(Uint, length(idx)), C_NULL)
function ju_unset{V}(arr::JudyDict{Int,V}, idx::Int)
    ret_tuple = ju_get(arr, idx)
    if(ret_tuple[2] != C_NULL)
        # we had a value set there. unset it from the array and delete the stored reference from gc_store
        ret = @_ju_unset arr convert(Uint, idx) Uint :JudyLDel
        delete!(arr.gc_store, ret_tuple[1])
        return ret
    end
    int32(0)
end
ju_unset(arr::JudyDict{String, Int}, idx::String) = @_ju_unset arr bytestring(idx) Ptr{Uint8} :JudySLDel
function ju_unset{V}(arr::JudyDict{String,V}, idx::String)
    ret_tuple = ju_get(arr, idx)
    if(ret_tuple[2] != C_NULL)
        # we had a value set there. unset it from the array and delete the stored reference from gc_store
        ret = @_ju_unset arr idx Ptr{Uint8} :JudySLDel
        delete!(arr.gc_store, ret_tuple[1])
        return ret
    end
    int32(0)
end


## count the number of indexes present between idx1 and idx2 (inclusive).
## returns the count.
## a return value of 0 can be valid as a count, or it can indicate a special case for fully populated array (32-bit machines only).
## see Judy documentation for ways to resolve this.
ju_count(arr::JudyDict{Int, Bool}, idx1::Int=0, idx2::Int=-1) = ccall((:Judy1Count, _judylib), Uint, (Ptr{Void}, Uint, Uint, Ptr{Void}), arr.pjarr[1], convert(Uint, idx1), convert(Uint, idx2), C_NULL)
ju_count{V}(arr::JudyDict{Int,V}, idx1::Int=0, idx2::Int=-1) = ccall((:JudyLCount, _judylib), Uint, (Ptr{Void}, Uint, Uint, Ptr{Void}), arr.pjarr[1], convert(Uint, idx1), convert(Uint, idx2), C_NULL)


## locate the nth index that is present (n starts wih 1)
## to refer to the last index in a fully populated array (all indexes present, which is rare), use n = 0.
## return tuple (1, index_pos) on success or (0, undefined) on not found/error
function ju_by_count(arr::JudyDict{Int, Bool}, n::Int)
    ret::Int32 = ccall((:Judy1ByCount, _judylib), Int32, (Ptr{Void}, Uint, Ptr{Uint}, Ptr{Void}), arr.pjarr[1], convert(Uint, n), arr.nth_idx, C_NULL)
    return (ret, arr.nth_idx[1])
end


## locate the nth index that is present (n starts wih 1)
## return tuple (value at index, pointer to value, index_pos) on success or (undefined, C_NULL, undefined) on not found/error
function ju_by_count(arr::JudyDict{Int,Int}, n::Int)
    ret::Ptr{Uint} = ccall((:JudyLByCount, _judylib), Ptr{Uint}, (Ptr{Void}, Uint, Ptr{Uint}, Ptr{Void}), arr.pjarr[1], convert(Uint, n), arr.nth_idx, C_NULL)
    ret_val::Uint = (ret != C_NULL) ? unsafe_load(ret) : C_NULL
    return (ret_val, ret, arr.nth_idx[1])
end
function ju_by_count{V}(arr::JudyDict{Int,V}, n::Int)
    ret::Ptr{Uint} = ccall((:JudyLByCount, _judylib), Ptr{Uint}, (Ptr{Void}, Uint, Ptr{Uint}, Ptr{Void}), arr.pjarr[1], convert(Uint, n), arr.nth_idx, C_NULL)
    if(ret != C_NULL)
        ret_val::Uint = unsafe_load(ret)
        (unsafe_pointer_to_objref(convert(Ptr{Void}, ret_val)), ret, arr.nth_idx[1])
    else
        (Nothing, C_NULL, arr.nth_idx[1])
    end
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
start(arr::JudyDict{Int, Bool}) = ju_first(arr)
done(arr::JudyDict{Int, Bool}, state) = (0 == state[1])
next(arr::JudyDict{Int, Bool}, state) = done(arr, state) ? (Nothing, state) : ((true, state[2]), ju_next(arr))

start{V}(arr::JudyDict{Int, V}) = ju_first(arr)
done{V}(arr::JudyDict{Int, V}, state) = (C_NULL == state[2])
next{V}(arr::JudyDict{Int, V}, state) = done(arr, state) ? (Nothing, state) : ((state[1], state[3]), ju_next(arr))

start{V}(arr::JudyDict{String, V}) = ju_first(arr)
done{V}(arr::JudyDict{String, V}, state) = (C_NULL == state[2])
next{V}(arr::JudyDict{String, V}, state) = done(arr, state) ? (Nothing, state) : ((state[1], state[3]), ju_next(arr))

## The base iteration methods return a pointer to the value as well
function ju_first(arr::JudyDict{Int, Bool}, idx::Int=0)
    arr.nth_idx[1] = convert(Uint, idx)
    ret::Int32 = ccall((:Judy1First, _judylib), Int32, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.pjarr[1], arr.nth_idx, C_NULL)
    return (ret, arr.nth_idx[1])
end

function ju_first(arr::JudyDict{Int, Int}, idx::Int=0)
    arr.nth_idx[1] = convert(Uint, idx)
    ret::Ptr{Uint} = ccall((:JudyLFirst, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.pjarr[1], arr.nth_idx, C_NULL)
    ret_val::Uint = (ret != C_NULL) ? unsafe_load(ret) : C_NULL
    return (ret_val, ret, arr.nth_idx[1])
end
function ju_first{V}(arr::JudyDict{Int, V}, idx::Int=0)
    arr.nth_idx[1] = convert(Uint, idx)
    ret::Ptr{Uint} = ccall((:JudyLFirst, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.pjarr[1], arr.nth_idx, C_NULL)
    if(ret != C_NULL)
        return (unsafe_pointer_to_objref(convert(Ptr{Void}, unsafe_load(ret))), ret, arr.nth_idx[1])
    end
    (C_NULL, C_NULL, arr.nth_idx[1])
end

function ju_first(arr::JudyDict{String, Int}, idx::String="")
    @assert length(idx) < MAX_STR_IDX_LEN
    @_strcpy arr.nth_idx bytestring(idx)
    ret::Ptr{Uint} = ccall((:JudySLFirst, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint8}, Ptr{Void}), arr.pjarr[1], arr.nth_idx, C_NULL)
    if(ret != C_NULL)
        len::Uint = @_strlen arr.nth_idx
        return (unsafe_load(ret), ret, ASCIIString(arr.nth_idx[1:len]))
    end
    (uint(0), C_NULL, "")
end
function ju_first{V}(arr::JudyDict{String, V}, idx::String="")
    @assert length(idx) < MAX_STR_IDX_LEN
    @_strcpy arr.nth_idx bytestring(idx)
    ret::Ptr{Uint} = ccall((:JudySLFirst, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint8}, Ptr{Void}), arr.pjarr[1], arr.nth_idx, C_NULL)
    if(ret != C_NULL)
        len::Uint = @_strlen arr.nth_idx
        return (unsafe_pointer_to_objref(convert(Ptr{Void}, unsafe_load(ret))), ret, ASCIIString(arr.nth_idx[1:len]))
    end
    (Nothing, C_NULL, "")
end


ju_next(arr::JudyDict{Int, Bool}, idx::Int) = ju_next(arr, convert(Uint, idx))
function ju_next(arr::JudyDict{Int, Bool}, idx::Uint)
    arr.nth_idx[1] = idx
    ju_next(arr)
end
function ju_next(arr::JudyDict{Int, Bool})
    ret::Int32 = ccall((:Judy1Next, _judylib), Int32, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.pjarr[1], arr.nth_idx, C_NULL)
    return (ret, arr.nth_idx[1])
end


function ju_next{V}(arr::JudyDict{Int, V}, idx::Int)
    arr.nth_idx[1] = convert(Uint, idx)
    ju_next(arr)
end
function ju_next(arr::JudyDict{Int, Int})
    ret::Ptr{Uint} = ccall((:JudyLNext, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.pjarr[1], arr.nth_idx, C_NULL)
    ret_val::Uint = (ret != C_NULL) ? unsafe_load(ret) : C_NULL
    return (ret_val, ret, arr.nth_idx[1])
end
function ju_next{V}(arr::JudyDict{Int, V})
    ret::Ptr{Uint} = ccall((:JudyLNext, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.pjarr[1], arr.nth_idx, C_NULL)
    if(ret != C_NULL)
        return (unsafe_pointer_to_objref(convert(Ptr{Void}, unsafe_load(ret))), ret, arr.nth_idx[1])
    end
    (C_NULL, C_NULL, arr.nth_idx[1])
end

function ju_next{V}(arr::JudyDict{String, V}, idx::String)
    @assert length(idx) < MAX_STR_IDX_LEN
    @_strcpy arr.nth_idx bytestring(idx)
    ju_next(arr)
end
function ju_next(arr::JudyDict{String, Int})
    ret::Ptr{Uint} = ccall((:JudySLNext, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint8}, Ptr{Void}), arr.pjarr[1], arr.nth_idx, C_NULL)
    if(ret != C_NULL)
        len::Uint = @_strlen arr.nth_idx
        return (unsafe_load(ret), ret, ASCIIString(arr.nth_idx[1:len]))
    end
    (uint(0), C_NULL, "")
end
function ju_next{V}(arr::JudyDict{String, V})
    ret::Ptr{Uint} = ccall((:JudySLNext, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint8}, Ptr{Void}), arr.pjarr[1], arr.nth_idx, C_NULL)
    if(ret != C_NULL)
        len::Uint = @_strlen arr.nth_idx
        return (unsafe_pointer_to_objref(convert(Ptr{Void}, unsafe_load(ret))), ret, ASCIIString(arr.nth_idx[1:len]))
    end
    (Nothing, C_NULL, "")
end


function ju_last(arr::JudyDict{Int, Bool}, idx::Int=-1)
    arr.nth_idx[1] = convert(Uint, idx)
    ret::Int32 = ccall((:Judy1Last, _judylib), Int32, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.pjarr[1], arr.nth_idx, C_NULL)
    return (ret, arr.nth_idx[1])
end

function ju_last(arr::JudyDict{Int, Int}, idx::Int=-1)
    arr.nth_idx[1] = convert(Uint, idx)
    ret::Ptr{Uint} = ccall((:JudyLLast, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.pjarr[1], arr.nth_idx, C_NULL)
    ret_val::Uint = (ret != C_NULL) ? unsafe_load(ret) : C_NULL
    return (ret_val, ret, arr.nth_idx[1])
end
function ju_last{V}(arr::JudyDict{Int, V}, idx::Int=-1)
    arr.nth_idx[1] = convert(Uint, idx)
    ret::Ptr{Uint} = ccall((:JudyLLast, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.pjarr[1], arr.nth_idx, C_NULL)
    if(ret != C_NULL)
        return (unsafe_pointer_to_objref(convert(Ptr{Void}, unsafe_load(ret))), ret, arr.nth_idx[1])
    end
    return (C_NULL, C_NULL, arr.nth_idx[1])
end

function ju_last(arr::JudyDict{String, Int})
    ccall((:memset, "libc"), Ptr{Uint8}, (Ptr{Uint8}, Uint8, Uint), arr.nth_idx, 0xff, MAX_STR_IDX_LEN-1)
    arr.nth_idx[MAX_STR_IDX_LEN-1] = 0
    ret::Ptr{Uint} = ccall((:JudySLLast, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint8}, Ptr{Void}), arr.pjarr[1], arr.nth_idx, C_NULL)
    if(ret != C_NULL)
        ret_val::Uint = unsafe_load(ret)
        len::Uint = @_strlen arr.nth_idx
        return (ret_val, ret, ASCIIString(arr.nth_idx[1:len]))
    end
    (uint(0), C_NULL, "")
end
function ju_last(arr::JudyDict{String, Int}, idx::String)
    @assert length(idx) < MAX_STR_IDX_LEN
    @_strcpy arr.nth_idx bytestring(idx)
    ret::Ptr{Uint} = ccall((:JudySLLast, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint8}, Ptr{Void}), arr.pjarr[1], arr.nth_idx, C_NULL)
    if(ret != C_NULL)
        ret_val::Uint = unsafe_load(ret)
        len::Uint = @_strlen arr.nth_idx
        return (ret_val, ret, ASCIIString(arr.nth_idx[1:len]))
    end
    (uint(0), C_NULL, "")
end
function ju_last{V}(arr::JudyDict{String, V})
    ccall((:memset, "libc"), Ptr{Uint8}, (Ptr{Uint8}, Uint8, Uint), arr.nth_idx, 0xff, MAX_STR_IDX_LEN-1)
    arr.nth_idx[MAX_STR_IDX_LEN-1] = 0
    ret::Ptr{Uint} = ccall((:JudySLLast, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint8}, Ptr{Void}), arr.pjarr[1], arr.nth_idx, C_NULL)
    if(ret != C_NULL)
        len::Uint = @_strlen arr.nth_idx
        return (unsafe_pointer_to_objref(convert(Ptr{Void}, unsafe_load(ret))), ret, ASCIIString(arr.nth_idx[1:len]))
    end
    (Nothing, C_NULL, "")
end
function ju_last{V}(arr::JudyDict{String, V}, idx::String)
    @assert length(idx) < MAX_STR_IDX_LEN
    @_strcpy arr.nth_idx bytestring(idx)
    ret::Ptr{Uint} = ccall((:JudySLLast, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint8}, Ptr{Void}), arr.pjarr[1], arr.nth_idx, C_NULL)
    if(ret != C_NULL)
        len::Uint = @_strlen arr.nth_idx
        return (unsafe_pointer_to_objref(convert(Ptr{Void}, unsafe_load(ret))), ret, ASCIIString(arr.nth_idx[1:len]))
    end
    (Nothing, C_NULL, "")
end



ju_prev(arr::JudyDict{Int, Bool}, idx::Int) = ju_prev(arr, convert(Uint, idx))
function ju_prev(arr::JudyDict{Int, Bool}, idx::Uint)
    arr.nth_idx[1] = idx
    ju_prev(arr)
end
function ju_prev(arr::JudyDict{Int, Bool})
    ret::Int32 = ccall((:Judy1Prev, _judylib), Int32, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.pjarr[1], arr.nth_idx, C_NULL)
    return (ret, arr.nth_idx[1])
end


function ju_prev{V}(arr::JudyDict{Int, V}, idx::Int)
    arr.nth_idx[1] = convert(Uint, idx)
    ju_prev(arr)
end
function ju_prev(arr::JudyDict{Int, Int})
    ret::Ptr{Uint} = ccall((:JudyLPrev, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.pjarr[1], arr.nth_idx, C_NULL)
    ret_val::Uint = (ret != C_NULL) ? unsafe_load(ret) : C_NULL
    return (ret_val, ret, arr.nth_idx[1])
end
function ju_prev{V}(arr::JudyDict{Int, V})
    ret::Ptr{Uint} = ccall((:JudyLPrev, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.pjarr[1], arr.nth_idx, C_NULL)
    if(ret != C_NULL)
        return (unsafe_pointer_to_objref(convert(Ptr{Void}, unsafe_load(ret))), ret, arr.nth_idx[1])
    end
    return (C_NULL, C_NULL, arr.nth_idx[1])
end

function ju_prev{V}(arr::JudyDict{String, V}, idx::String)
    @assert length(idx) < MAX_STR_IDX_LEN
    @_strcpy arr.nth_idx bytestring(idx)
    ju_prev(arr)
end
function ju_prev(arr::JudyDict{String, Int})
    ret::Ptr{Uint} = ccall((:JudySLPrev, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.pjarr[1], arr.nth_idx, C_NULL)
    if(ret != C_NULL)
        ret_val::Uint = unsafe_load(ret)
        len::Uint = @_strlen arr.nth_idx
        return (ret_val, ret, ASCIIString(arr.nth_idx[1:len]))
    end
    (0, C_NULL, "")
end
function ju_prev{V}(arr::JudyDict{String, V})
    ret::Ptr{Uint} = ccall((:JudySLPrev, _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), arr.pjarr[1], arr.nth_idx, C_NULL)
    if(ret != C_NULL)
        len::Uint = @_strlen arr.nth_idx
        return (unsafe_pointer_to_objref(convert(Ptr{Void}, unsafe_load(ret))), ret, ASCIIString(arr.nth_idx[1:len]))
    end
    (Nothing, C_NULL, "")
end


macro _ju_iter_empty_cont(arr, fn)
    quote
        ret::Int32 = ccall(($(fn), _judylib), Ptr{Uint}, (Ptr{Void}, Ptr{Uint}, Ptr{Void}), $(arr).pjarr[1], $(arr).nth_idx, C_NULL)
        (ret, $(arr).nth_idx[1])
    end
end

macro _ju_iter_empty(arr, idx, fn)
    quote
        $(arr).nth_idx[1] = $(idx)
        @_ju_iter_empty_cont $(arr) $(fn)
    end
end

ju_first_empty(arr::JudyDict{Int, Bool}, idx::Int=0) = @_ju_iter_empty arr convert(Uint, idx) :Judy1FirstEmpty
ju_first_empty{V}(arr::JudyDict{Int, V}, idx::Int=0) = @_ju_iter_empty arr convert(Uint, idx) :JudyLFirstEmpty

ju_next_empty(arr::JudyDict{Int, Bool}, idx::Int) = @_ju_iter_empty arr convert(Uint, idx) :Judy1NextEmpty
ju_next_empty(arr::JudyDict{Int, Bool}) = @_ju_iter_empty_cont arr :Judy1NextEmpty

ju_next_empty{V}(arr::JudyDict{Int, V}, idx::Int) = @_ju_iter_empty arr convert(Uint, idx) :JudyLNextEmpty
ju_next_empty{V}(arr::JudyDict{Int, V}) = @_ju_iter_empty_cont arr :JudyLNextEmpty

ju_last_empty(arr::JudyDict{Int, Bool}, idx::Int=-1) = @_ju_iter_empty arr convert(Uint, idx) :Judy1LastEmpty
ju_last_empty{V}(arr::JudyDict{Int, V}, idx::Int=-1) = @_ju_iter_empty arr convert(Uint, idx) :JudyLLastEmpty

ju_prev_empty(arr::JudyDict{Int, Bool}, idx::Int) = @_ju_iter_empty arr convert(Uint, idx) :Judy1PrevEmpty
ju_prev_empty(arr::JudyDict{Int, Bool}) = @_ju_iter_empty_cont arr :Judy1PrevEmpty

ju_prev_empty{V}(arr::JudyDict{Int, V}, idx::Int) = @_ju_iter_empty arr convert(Uint, idx) :JudyLPrevEmpty
ju_prev_empty{V}(arr::JudyDict{Int, V}) = @_ju_iter_empty_cont arr :JudyLPrevEmpty

end
