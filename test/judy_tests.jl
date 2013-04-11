using JudyDicts
using Base.Test


function test_juHS()
    #println("testing JUHS...")
    local ja = JudyDict{Array{Uint8}, Int}()

    local indices = [(b"0001", 11), (b"00021", 121), (b"0005", 15)]

    for i in indices
        ret_ptr = ju_set(ja, i[1], i[2])
        @test C_NULL != ret_ptr
        @test i[2] == unsafe_ref(ret_ptr)
    end

    for i in indices
        ret_tuple = ju_get(ja, i[1])
        @test i[2] == ret_tuple[1]
        @test C_NULL != ret_tuple[2]
    end

    @test (indices[1])[2] == ja[(indices[1])[1]]
    ja[(indices[1])[1]] = 2 * (indices[1])[2]
    @test (2 * ((indices[1])[2])) == ja[(indices[1])[1]]

    @test 1 == ju_unset(ja, (indices[1])[1])
    ja[(indices[1])[1]] = 2 * (indices[1])[2]
    @test (2 * ((indices[1])[2])) == ja[(indices[1])[1]]
    ja[(indices[1])[1]] = Nothing
    @test Nothing == ja[(indices[1])[1]]

    @test C_NULL == (ju_get(ja, (indices[1])[1]))[2]
end

function test_juSO()
    #println("testing JUSL...")
    local ja = JudyDict{String, ASCIIString}()

    local indices = [("0001", "11"), ("00021", "121"), ("0005", "15")]

    for i in indices
        ja[i[1]] = i[2]
    end

    for i in indices
        @test i[2] == ja[i[1]]
    end

    ret_tuple = (Nothing, C_NULL, 0)
    for i in 1:length(indices)
        ret_tuple = (i == 1) ? ju_first(ja) : ju_next(ja)
        @test ((indices[i])[2] == ret_tuple[1]) && (C_NULL != ret_tuple[2]) && ((indices[i])[1] == ret_tuple[3])
    end
    @test C_NULL == (ju_next(ja))[2]
    for i in 1:length(indices)
        ret_tuple = (i == 1) ? ju_last(ja) : ju_prev(ja)
        local rev_idx = length(indices)-i+1
        @test ((indices[rev_idx])[2] == ret_tuple[1]) && (C_NULL != ret_tuple[2]) && ((indices[rev_idx])[1] == ret_tuple[3])
    end
    @test C_NULL == (ju_prev(ja))[2]

    i = 1
    for x in ja
        @test ((indices[i])[2] == x[1]) && ((indices[i])[1] == x[2])
        i+=1
    end

    @test (indices[1])[2] == ja[(indices[1])[1]]
    ja[(indices[1])[1]] = "2" * (indices[1])[2]
    @test ("2" * ((indices[1])[2])) == ja[(indices[1])[1]]

    @test 1 == ju_unset(ja, (indices[1])[1])
    @test C_NULL == (ju_get(ja, (indices[1])[1]))[2]
end


function test_juSL()
    #println("testing JUSL...")
    local ja = JudyDict{String, Int}()

    local indices = [("0001", 11), ("00021", 121), ("0005", 15)]

    for i in indices
        ret_ptr = ju_set(ja, i[1], i[2])
        @test C_NULL != ret_ptr
        @test i[2] == unsafe_ref(ret_ptr)
    end

    for i in indices
        ret_tuple = ju_get(ja, i[1])
        @test i[2] == ret_tuple[1]
        @test C_NULL != ret_tuple[2]
    end

    ret_tuple = (0, C_NULL, 0)
    for i in 1:length(indices)
        ret_tuple = (i == 1) ? ju_first(ja) : ju_next(ja)
        @test ((indices[i])[2] == ret_tuple[1]) && (C_NULL != ret_tuple[2]) && ((indices[i])[1] == ret_tuple[3])
    end
    @test C_NULL == (ju_next(ja))[2]
    for i in 1:length(indices)
        ret_tuple = (i == 1) ? ju_last(ja) : ju_prev(ja)
        local rev_idx = length(indices)-i+1
        @test ((indices[rev_idx])[2] == ret_tuple[1]) && (C_NULL != ret_tuple[2]) && ((indices[rev_idx])[1] == ret_tuple[3])
    end
    @test C_NULL == (ju_prev(ja))[2]

    i = 1
    for x in ja
        @test ((indices[i])[2] == x[1]) && ((indices[i])[1] == x[2])
        i+=1
    end

    @test (indices[1])[2] == ja[(indices[1])[1]]
    ja[(indices[1])[1]] = 2 * (indices[1])[2]
    @test (2 * ((indices[1])[2])) == ja[(indices[1])[1]]

    @test 1 == ju_unset(ja, (indices[1])[1])
    @test C_NULL == (ju_get(ja, (indices[1])[1]))[2]
end

function test_juLO()
    #println("testing JUL...")
    local ja = JudyDict{Int, ASCIIString}()

    @test 0 == ju_mem_used(ja)

    local indices = [(1, "11"), (5, "15"), (21, "121"), (41, "141"), (51, "151"), (61, "161")]

    for i in indices
        ja[i[1]] = i[2]
    end

    for i in indices
        @test i[2] == ja[i[1]]
    end

    @test length(indices) == ju_count(ja)

    for i in 1:length(indices)
        ret_tuple = ju_by_count(ja, i)
        @test ((indices[i])[2] == ret_tuple[1]) && (C_NULL != ret_tuple[2]) && ((indices[i])[1] == ret_tuple[3])
    end

    @test ju_mem_used(ja) > 0

    ret_tuple = (0, C_NULL, 0)
    for i in 1:length(indices)
        ret_tuple = (i == 1) ? ju_first(ja) : ju_next(ja)
        @test ((indices[i])[2] == ret_tuple[1]) && (C_NULL != ret_tuple[2]) && ((indices[i])[1] == ret_tuple[3])
    end
    @test C_NULL == (ju_next(ja))[2]
    for i in 1:length(indices)
        ret_tuple = (i == 1) ? ju_last(ja) : ju_prev(ja)
        local rev_idx = length(indices)-i+1
        @test ((indices[rev_idx])[2] == ret_tuple[1]) && (C_NULL != ret_tuple[2]) && ((indices[rev_idx])[1] == ret_tuple[3])
    end
    @test C_NULL == (ju_prev(ja))[2]

    i = 1
    for x in ja
        @test ((indices[i])[2] == x[1]) && ((indices[i])[1] == x[2])
        i+=1
    end

    for i in 1:20
        ret_tuple = (i == 1) ? ju_first_empty(ja) : ju_next_empty(ja)
        @test 1 == ret_tuple[1]
    end
    for i in 1:20
        ret = (i == 1) ? ju_last_empty(ja) : ju_prev_empty(ja)
        @test 1 == ret_tuple[1]
    end

    @test (indices[1])[2] == ja[(indices[1])[1]]
    ja[(indices[1])[1]] = "2" * (indices[1])[2]
    @test "2" * (indices[1])[2] == ja[(indices[1])[1]]

    @test 1 == ju_unset(ja, (indices[1])[1])
    @test C_NULL == (ju_get(ja, (indices[1])[1]))[2]
end


function test_juL()
    #println("testing JUL...")
    local ja = JudyDict{Int, Int}()

    @test 0 == ju_mem_used(ja)

    local indices = [(1, 11), (5, 15), (21, 121), (41, 141), (51, 151), (61, 161)]

    for i in indices
        ret_ptr = ju_set(ja, i[1], i[2])
        @test C_NULL != ret_ptr
        @test i[2] == unsafe_ref(ret_ptr)
    end

    for i in indices
        ret_tuple = ju_get(ja, i[1])
        @test i[2] == ret_tuple[1]
        @test C_NULL != ret_tuple[2]
    end

    @test length(indices) == ju_count(ja)

    for i in 1:length(indices)
        ret_tuple = ju_by_count(ja, i)
        @test ((indices[i])[2] == ret_tuple[1]) && (C_NULL != ret_tuple[2]) && ((indices[i])[1] == ret_tuple[3])
    end

    @test ju_mem_used(ja) > 0

    ret_tuple = (0, C_NULL, 0)
    for i in 1:length(indices)
        ret_tuple = (i == 1) ? ju_first(ja) : ju_next(ja)
        @test ((indices[i])[2] == ret_tuple[1]) && (C_NULL != ret_tuple[2]) && ((indices[i])[1] == ret_tuple[3])
    end
    @test C_NULL == (ju_next(ja))[2]
    for i in 1:length(indices)
        ret_tuple = (i == 1) ? ju_last(ja) : ju_prev(ja)
        local rev_idx = length(indices)-i+1
        @test ((indices[rev_idx])[2] == ret_tuple[1]) && (C_NULL != ret_tuple[2]) && ((indices[rev_idx])[1] == ret_tuple[3])
    end
    @test C_NULL == (ju_prev(ja))[2]

    i = 1
    for x in ja
        @test ((indices[i])[2] == x[1]) && ((indices[i])[1] == x[2])
        i+=1
    end

    for i in 1:20
        ret_tuple = (i == 1) ? ju_first_empty(ja) : ju_next_empty(ja)
        @test 1 == ret_tuple[1]
    end
    for i in 1:20
        ret = (i == 1) ? ju_last_empty(ja) : ju_prev_empty(ja)
        @test 1 == ret_tuple[1]
    end

    @test (indices[1])[2] == ja[(indices[1])[1]]
    ja[(indices[1])[1]] = 2 * (indices[1])[2]
    @test (2 * ((indices[1])[2])) == ja[(indices[1])[1]]

    @test 1 == ju_unset(ja, (indices[1])[1])
    @test C_NULL == (ju_get(ja, (indices[1])[1]))[2]
end

function test_ju1()
    #println("testing JU1...")
    local ja = JudyDict{Int, Bool}()

    @test 0 == ju_mem_used(ja)

    local indices = [1, 5]
    for i in indices
        @test 1 == ju_set(ja, i)
    end
    for i in indices
        @test 1 == ju_get(ja, i)
    end
    @test length(indices) == ju_count(ja)

    for i in 1:length(indices)
        ret_tuple = ju_by_count(ja, i)
        @test (1 == ret_tuple[1]) && (indices[i] == ret_tuple[2])
    end

    @test ju_mem_used(ja) > 0

    local ret = (0, 0)
    for i in 1:length(indices)
        ret = (i == 1) ? ju_first(ja) : ju_next(ja)
        @test (1 == ret[1]) && (indices[i] == ret[2])
    end
    @test 0 == (ju_next(ja))[1]
    for i in 1:length(indices)
        ret = (i == 1) ? ju_last(ja) : ju_prev(ja)
        @test (1 == ret[1]) && (indices[length(indices)-i+1] == ret[2])
    end
    @test 0 == (ju_prev(ja))[1]

    i = 1
    for x in ja
        @test (indices[i] == x[2])
        i+=1
    end

    for i in 1:20
        ret = (i == 1) ? ju_first_empty(ja) : ju_next_empty(ja)
        @test 1 == ret[1]
    end
    for i in 1:20
        ret = (i == 1) ? ju_last_empty(ja) : ju_prev_empty(ja)
        @test 1 == ret[1]
    end

    @test true == ja[indices[1]]
    ja[indices[1]] = false
    @test false == ja[indices[1]]
    ja[indices[1]] = true

    @test 1 == ju_unset(ja, indices[1])
    @test 1 != ju_get(ja, indices[1])
end

test_juHS()
test_juSL()
test_juL()
test_ju1()
test_juLO()
test_juSO()

