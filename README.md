[Judy arrays](http://en.wikipedia.org/wiki/Judy_array) are fast associative arrays with low memory usage.

This is a wrapper over the Judy C library at [http://judy.sourceforge.net/](http://judy.sourceforge.net/), and also provides array like syntax for ease of use.

Speed comparison (output of test/time\_test.jl):
-----------------------------------------------
loops: 10000000 compare: JudyArray{Int, Int} vs. Dict{Int64, Int64}
set => dict: 3.384667585, judy: 2.062912086
get => dict: 2.647226134, judy: 3.763169382

loops: 20000 compare: JudyArray{String, Int} vs. Dict{String, Int64} vs. Trie{Int64}
set => dict: 1.698076728, trie: 1.886814575, judy: 1.102385142
get => dict: 2.695508126, trie: 1.082784111, judy: 1.032443957

loops: 20000 compare: JudyArray{String, ASCIIString} vs. Dict{String, ASCIIString} vs. Trie{ASCIIString}
set => dict: 1.631594123, trie: 1.643936574, judy: 1.958270702
get => dict: 3.427168931, trie: 1.908051037, judy: 1.577238887


These tests are just indicative and extensive testing hasn't been done yet.
JudyArray seems better performing when the key is a String, but still very close to Trie.

JudyArray with Julia objects as value type actually also hold the object references in an internal Dict to prevent them being gc'd. They could be faster if it could somehow indicate certain object\_ids to gc as protected, but unfortunately there doesn't seem to be a way to do that.



Example (simple):
-----------------
    julia> using Judy

    julia> ja = JudyArray{Int, Int}()
    JudyArray{Int64,Int64} (empty)

    julia> ja[1] = 100
    100

    julia> ja[2] = 200
    200

    julia> println(ja[2] / ja[1])
    2.0

    julia> ja[2] * ja[1]
    0x0000000000004e20

    julia> ja = JudyArray{String, Int}()
    JudyArray{String,Int64} (empty)

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
*    **ju_set**: Set value (val) at index (idx). Return a pointer to the value. the pointer is valid till the next call to a judy method. Return C\_NULL on error
*    **ju_unset**: Unset value at index. Return 1 if index was previously set (successful), otherwise 0 if the index was already unset (unsuccessful).
*    **ju_get**: Get the value at index (if set). For Judy1 arrays, return 1 if index's bit was set, 0 if it was unset (index was absent). Otherwise, return a tuple (value, pointer to value) if index's bit was set, (undefined, C\_NULL) if it was not. The pointer is valid till the next call to a judy method.
*    **ju_count**: Count the number of indexes present between idx1 and idx2 (inclusive).
*    **ju_by_count**: locate the nth index that is present (n starts wih 1)
*    **ju_first, ju_next, ju_last, ju_prev**: iterators over populated indices
*    **ju_first_empty, ju_next_empty, ju_last_empty, ju_prev_empty**: iterators over empty slots
