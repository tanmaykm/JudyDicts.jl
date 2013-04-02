[Judy arrays](http://en.wikipedia.org/wiki/Judy_array) are fast associative arrays with low memory usage.

This is a wrapper over the Judy C library at [http://judy.sourceforge.net/](http://judy.sourceforge.net/), and also provides array like syntax for ease of use.

Speed comparison (output of test/time\_test.jl):
-----------------------------------------------
````
items 10000000 compare: JudyDict{Int, Int} vs. Dict{Int64, Int64}
set => dict: 3.52637685, judy: 2.08612242
get => dict: 2.622192309, judy: 3.117356024

items 20000 compare: JudyDict{String, Int} vs. Dict{String, Int64} vs. Trie{Int64}
set => dict: 1.660365446, trie: 1.847608276, judy: 1.069796761
get => dict: 2.665482163, trie: 1.105458666, judy: 0.987667069

items 20000 compare: JudyDict{String, ASCIIString} vs. Dict{String, ASCIIString} vs. Trie{ASCIIString}
set => dict: 1.572052548, trie: 1.580906381, judy: 1.930858175
get => dict: 3.755708956, trie: 1.872941903, judy: 1.582678214
````

These tests are just indicative and extensive testing hasn't been done yet.
JudyDict seems better performing when the key is a String, but still very close to Trie.

JudyDict with Julia objects as value type actually also hold the object references in an internal Dict to prevent them being gc'd. They could be faster if it could somehow indicate certain object\_ids to gc as protected, but unfortunately there doesn't seem to be a way to do that.



Example (simple):
-----------------
    julia> using JudyDicts

    julia> ja = JudyDict{Int, Int}()
    JudyDict{Int64,Int64} (empty)

    julia> ja[1] = 100
    100

    julia> ja[2] = 200
    200

    julia> println(ja[2] / ja[1])
    2.0

    julia> ja[2] * ja[1]
    0x0000000000004e20

    julia> ja = JudyDict{String, Int}()
    JudyDict{String,Int64} (empty)

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
