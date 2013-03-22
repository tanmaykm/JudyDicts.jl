[Judy arrays](http://en.wikipedia.org/wiki/Judy_array) are fast associative arrays with low memory usage.

This is a wrapper over the Judy C library at [http://judy.sourceforge.net/](http://judy.sourceforge.net/), and also provides array like syntax for ease of use.

Speed comparison (output of test/time_test.jl):
-----------------------------------------------
comparing JudyL with Dict{Int64, Int64}
Dict{Int64, Int64}...
elapsed time: 3.432425353 seconds
JudyL...
elapsed time: 2.395959441 seconds

comparing JudySL with Dict{String, Int64}
Dict{String, Int64}...
elapsed time: 36.843917985 seconds
JudySL...
elapsed time: 6.631340927 seconds


Example (simple):
-----------------
    julia> using Judy

    julia> ja = JudyL()
    JudyL (empty)

    julia> ja[1] = 100
    100

    julia> ja[2] = 200
    200

    julia> println(ja[2] / ja[1])
    2.0

    julia> ja[2] * ja[1]
    0x0000000000004e20

    julia> ja = JudySL()
    JudySL (empty)

    julia> ja["First"] = 100
    100

    julia> ja["One More"] = 200
    200

    julia> println(ja["One More"] / ja["First"])
    2.0

    julia> for x in ja
             println(x)
           end
    (0x0000000000000064,"First")
    (0x00000000000000c8,"One More")

Other APIs:
-----------
*    **ju_mem_used**: Return bytes of memory used currently by the judy array
*    **ju_set**: Set value (val) at index (idx). Return a pointer to the value. the pointer is valid till the next call to a judy method. Return C_NULL on error
*    **ju_unset**: Unset value at index. Return 1 if index was previously set (successful), otherwise 0 if the index was already unset (unsuccessful).
*    **ju_get**: Get the value at index (if set). For Judy1 arrays, return 1 if index's bit was set, 0 if it was unset (index was absent). Otherwise, return a tuple (value, pointer to value) if index's bit was set, (undefined, C_NULL) if it was not. The pointer is valid till the next call to a judy method.
*    **ju_count**: Count the number of indexes present between idx1 and idx2 (inclusive).
*    **ju_by_count**: locate the nth index that is present (n starts wih 1)
*    **ju_first, ju_next, ju_last, ju_prev**: iterators over populated indices
*    **ju_first_empty, ju_next_empty, ju_last_empty, ju_prev_empty**: iterators over empty slots
