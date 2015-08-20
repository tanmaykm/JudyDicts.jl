using JudyDicts

import Base.getindex

const NLOOPS = isempty(ARGS) ? 1000000 : int(ARGS[1])
const kk = [ bytestring(repeat(string(idx), 10)) for idx in 1:NLOOPS ]

macro nogc_elapsed(ex)
    quote
        gc_disable()
        local t0 = time_ns()
        local val = $(esc(ex))
        local ret = (time_ns()-t0)/1e9
        gc_enable(); gc()
        ret
    end
end

macro bmsetstrobjloop(nloops, arr)
    quote
        local i::Int
        @nogc_elapsed for i in 1:$(nloops)
            $(arr)[kk[i]] = kk[i]
        end
    end
end

macro bmgetstrobjloop(nloops, arr)
    quote
        local x::String = ""
        @nogc_elapsed for i in 1:$(nloops)
            x = $(arr)[kk[i]]
        end
    end
end

function compare_str_obj()
    println("items ", NLOOPS, " compare: JudyDict{String, ASCIIString} vs. Dict{String, ASCIIString}")
    local dict_ins, dict_access, ja_ins, ja_access

    let ja = JudyDict{String, ASCIIString}()
        ja_ins = @bmsetstrobjloop NLOOPS ja
        ja_access = @bmgetstrobjloop NLOOPS ja
    end
    gc()

    let d = Dict{String, ASCIIString}()
        dict_ins = @bmsetstrobjloop NLOOPS d
        dict_access = @bmgetstrobjloop NLOOPS d
    end
    gc()
    #println("dict ins:", dict_ins, " access:", dict_access)

    println("set => dict: ", dict_ins, ", judy: ", ja_ins);
    println("get => dict: ", dict_access, ", judy: ", ja_access);
end

macro bmgetstrloop(nloops, arr)
    quote
        local x::Int = 0
        @nogc_elapsed for i in 1:$(nloops)
            x += $(arr)[kk[i]]
        end
    end
end

macro bmsetstrloop(nloops, arr)
    quote
        @nogc_elapsed for i in 1:$(nloops)
            $(arr)[kk[i]] = i
        end
    end
end

function compare_str()
    println("items ", NLOOPS, " compare: JudyDict{String, Int} vs. Dict{String, Int64}")
    local dict_ins, dict_access, ja_ins, ja_access

    let ja = JudyDict{String, Int}()
        ja_ins = @bmsetstrloop NLOOPS ja
        ja_access = @bmgetstrloop NLOOPS ja
    end
    gc()

    let d = Dict{String, Int64}()
        dict_ins = @bmsetstrloop NLOOPS d
        dict_access = @bmgetstrloop NLOOPS d
    end
    gc()

    println("set => dict: ", dict_ins, ", judy: ", ja_ins);
    println("get => dict: ", dict_access, ", judy: ", ja_access);
end

macro bmsetintloop(nloops, arr)
    quote
        @nogc_elapsed for i in 1:$(nloops); $(arr)[i] = i; end
    end
end

macro bmgetintloop(nloops, arr)
    quote
        local x::Int = 0
        @nogc_elapsed for i in 1:$(nloops); x += $(arr)[i]; end
    end
end

function compare_int64()
    println("items ", NLOOPS, " compare: JudyDict{Int, Int} vs. Dict{Int64, Int64}")
    local dict_ins, dict_access, ja_ins, ja_access

    let d = Dict{Int64, Int64}()
        dict_ins = @bmsetintloop NLOOPS d
        dict_access = @bmgetintloop NLOOPS d
    end
    gc()

    let ja = JudyDict{Int, Int}()
        ja_ins = @bmsetintloop NLOOPS ja
        ja_access = @bmgetintloop NLOOPS ja
    end
    gc()

    println("set => dict: ", dict_ins, ", judy: ", ja_ins);
    println("get => dict: ", dict_access, ", judy: ", ja_access);
end

compare_int64()
println("")
compare_str()
println("")
compare_str_obj()

