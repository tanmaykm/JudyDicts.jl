[Judy arrays](http://en.wikipedia.org/wiki/Judy_array) are fast associative arrays with low memory usage.

This is a wrapper over the Judy C library at [http://judy.sourceforge.net/](http://judy.sourceforge.net/), but **also** provides a array like syntax for ease of use.

Example (simple):
-----------------
    julia> using Judy

    julia> ja = JudyL()
    JudyL(JudyArrayBase(Ptr{Void} @0x0000000000000000,[Ptr{Void} @0x0000000000000000],[0x0000000000000000]))

    julia> ja[1] = 100
    100

    julia> ja[2] = 200
    200

    julia> println(ja[2] / ja[1])
    2.0

    julia> ja[2] * ja[1]
    0x0000000000004e20

    julia> ja = JudySL()
    JudySL(JudyArrayBase(Ptr{Void} @0x0000000000000000,[Ptr{Void} @0x0000000000000000],[0x00,..., 0x00]))

    julia> ja["First"] = 100
    100

    julia> ja["One More"] = 200
    200

    julia> println(ja["One More"] / ja["First"])
    2.0

Other APIs:
-----------
*    ju_mem_used: Return bytes of memory used currently by the judy array
*    ju_set: Set value (val) at index (idx). Return a pointer to the value. the pointer is valid till the next call to a judy method. Return C_NULL on error
*    ju_unset: Unset value at index. Return 1 if index was previously set (successful), otherwise 0 if the index was already unset (unsuccessful).
*    ju_get: Get the value at index (if set). For Judy1 arrays, return 1 if index's bit was set, 0 if it was unset (index was absent). Otherwise, return a tuple (value, pointer to value) if index's bit was set, (undefined, C_NULL) if it was not. The pointer is valid till the next call to a judy method.
*    ju_count: Count the number of indexes present between idx1 and idx2 (inclusive).
*    ju_by_count: locate the nth index that is present (n starts wih 1)
*    ju_first, ju_next, ju_last, ju_prev: iterators over populated indices
*    ju_first_empty, ju_next_empty, ju_last_empty, ju_prev_empty: iterators over empty slots
