using Judy
using Test

function compare_str_dict()
    println("comparing JudySL with Dict{String, Int64}")

    const nloops = 10000000

    println("Dict{String, Int64}...")
    d = Dict{String, Int64}()
    @time for i in 1:nloops
        d[string(i)] = i
    end
    d = Nothing
    gc()

    println("JudySL...")
    ja = JudySL()
    @time for i in 1:nloops
        ja[string(i)] = i
    end
    ja = Nothing
    gc()
end

function compare_int64_dict()
    println("comparing JudyL with Dict{Int64, Int64}")
    const nloops = 10000000

    println("Dict{Int64, Int64}...")
    d = Dict{Int64, Int64}()
    @time for i in 1:nloops
        d[i] = i
    end
    d = Nothing
    gc()

    println("JudyL...")
    ja = JudyL()
    @time for i in 1:nloops
        ja[i] = i
    end
    ja = Nothing
    gc()

end

compare_int64_dict()
compare_str_dict()
