using Judy
using Test
require("Trie")
using Tries

import Base.getindex

getindex{V}(t::Trie{V},k::String) = get(t,k)


macro bmsetstrobjloop(nloops, arr)
    quote
        gc_disable()
        local i::Int
        local tm = @elapsed for i in 1:$(nloops)
            $(arr)[repeat(string(i), 10)] = string(i)
        end
        gc_enable()
        gc()
        tm
    end
end

macro bmgetstrobjloop(nloops, arr)
    quote
        local x::String = ""
        gc_disable()
        local tm = @elapsed for i in 1:$(nloops)
            x *= $(arr)[repeat(string(i), 10)]
        end
        gc_enable()
        arr = Nothing
        gc()
        tm
    end
end

function compare_str_obj()
    println("comparing JudyArray{String, ASCIIString} with Dict{String, ASCIIString} and Trie{ASCIIString}")
    const nloops = 20000

    ja = JudyArray{String, ASCIIString}()
    ja_ins = @bmsetstrobjloop nloops ja
    ja_access = @bmgetstrobjloop nloops ja
    #println("judy ins:", ja_ins, " access:", ja_access)

    t = Trie{ASCIIString}()
    trie_ins = @bmsetstrobjloop nloops t
    trie_access = @bmgetstrobjloop nloops t
    #println("trie ins:", trie_ins, " access:", trie_access)

    d = Dict{String, ASCIIString}()
    dict_ins = @bmsetstrobjloop nloops d
    dict_access = @bmgetstrobjloop nloops d
    #println("dict ins:", dict_ins, " access:", dict_access)

    println("inserts  => dict: ", dict_ins, ", trie: ", trie_ins, ", judy: ", ja_ins);
    println("accesses => dict: ", dict_access, ", trie: ", trie_access, ", judy: ", ja_access);
end

macro bmgetstrloop(nloops, arr)
    quote
        local x::Int = 0
        gc_disable()
        local tm = @elapsed for i in 1:$(nloops)
            x += $(arr)[repeat(string(i), 10)]
        end
        gc_enable()
        arr = Nothing
        gc()
        tm
    end
end

macro bmsetstrloop(nloops, arr)
    quote
        gc_disable()
        local i::Int
        local tm = @elapsed for i in 1:$(nloops)
            $(arr)[repeat(string(i), 10)] = i
        end
        gc_enable()
        gc()
        tm
    end
end

function compare_str()
    println("comparing JudyArray{String, Int} with Dict{String, Int64} and Trie{Int64}")
    const nloops = 50000

    ja = JudyArray{String, Int}()
    ja_ins = @bmsetstrloop nloops ja
    ja_access = @bmgetstrloop nloops ja

    t = Trie{Int64}()
    trie_ins = @bmsetstrloop nloops t
    trie_access = @bmgetstrloop nloops t

    d = Dict{String, Int64}()
    dict_ins = @bmsetstrloop nloops d
    dict_access = @bmgetstrloop nloops d

    println("inserts  => dict: ", dict_ins, ", trie: ", trie_ins, ", judy: ", ja_ins);
    println("accesses => dict: ", dict_access, ", trie: ", trie_access, ", judy: ", ja_access);
end

macro bmsetintloop(nloops, arr)
    quote
        gc_disable()
        local i::Int
        local tm = @elapsed for i in 1:$(nloops)
            $(arr)[i] = i
        end
        gc_enable()
        gc()
        tm
    end
end

macro bmgetintloop(nloops, arr)
    quote
        local x::Int = 0
        gc_disable()
        local tm = @elapsed for i in 1:$(nloops)
            x += $(arr)[i]
        end
        gc_enable()
        arr = Nothing
        gc()
        tm
    end
end

function compare_int64()
    println("comparing JudyArray{Int, Int} with Dict{Int64, Int64}")
    const nloops = 10000000

    d = Dict{Int64, Int64}()
    dict_ins = @bmsetintloop nloops d
    dict_access = @bmgetintloop nloops d

    ja = JudyArray{Int, Int}()
    ja_ins = @bmsetintloop nloops ja
    ja_access = @bmgetintloop nloops ja

    println("inserts  => dict: ", dict_ins, ", judy: ", ja_ins);
    println("accesses => dict: ", dict_access, ", judy: ", ja_access);
end

compare_int64()
println("")
compare_str()
println("")
compare_str_obj()

