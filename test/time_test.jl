using Judy
using Test

function compare_str_dict()
    println("comparing JudySL with Dict{String, Int64}")
    #const nloops = 10000000
    const nloops = 100000
    local x::Int64 = 0

    d = Dict{String, Int64}()
    gc_disable()
    #println("inserts: Dict{String, Int64}...")
    dict_ins = @elapsed for i in 1:nloops
        d[repeat(string(i), 10)] = i
    end
    gc_enable()
    gc()
    x = 0
    #println("access Dict{String, Int64}...")
    dict_access = @elapsed for i in 1:nloops
        x += d[repeat(string(i), 10)]
    end
    gc_enable()
    d = Nothing
    gc()

    ja = JudySL()
    gc_disable()
    #println("inserts JudySL...")
    ja_ins = @elapsed for i in 1:nloops
        ja[repeat(string(i), 10)] = i
    end
    gc_enable()
    gc()
    #println("access JudySL...")
    ja_access = @elapsed for i in 1:nloops
        x += ja[repeat(string(i), 10)]
    end
    gc_enable()
    ja = Nothing
    gc()
    println("inserts  => dict: ", dict_ins, ", judy: ", ja_ins);
    println("accesses => dict: ", dict_access, ", judy: ", ja_access);
end

function compare_int64_dict()
    println("comparing JudyL with Dict{Int64, Int64}")
    const nloops = 10000000
    local x::Int64 = 0

    d = Dict{Int64, Int64}()
    gc_disable()
    #println("inserts: Dict{Int64, Int64}...")
    dict_ins = @elapsed for i in 1:nloops
        d[i] = i
    end
    gc_enable()
    gc()
    x = 0
    #println("access: Dict{Int64, Int64}...")
    dict_access = @elapsed for i in 1:nloops
        x += d[i]
    end
    gc_enable()
    d = Nothing
    gc()

    ja = JudyL()
    gc_disable()
    #println("inserts: JudyL...")
    ja_ins = @elapsed for i in 1:nloops
        ja[i] = i
    end
    gc_enable()
    gc()
    x = 0
    #println("access: JudyL")
    ja_access = @elapsed for i in 1:nloops
        x += ja[i]
    end
    gc_enable()
    ja = Nothing
    gc()
    println("inserts  => dict: ", dict_ins, ", judy: ", ja_ins);
    println("accesses => dict: ", dict_access, ", judy: ", ja_access);
end

compare_int64_dict()
compare_str_dict()

