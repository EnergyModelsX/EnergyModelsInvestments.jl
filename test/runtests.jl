using HiGHS
using JuMP
using Test

using EnergyModelsBase
using EnergyModelsGeography
using EnergyModelsInvestments
using TimeStruct

const EMB = EnergyModelsBase
const EMG = EnergyModelsGeography
const EMI = EnergyModelsInvestments
const TS = TimeStruct

const TEST_ATOL = 1e-6
⪆(x,y) = x > y || isapprox(x,y;atol=TEST_ATOL)
const OPTIMIZER = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)


"""
    general_tests(m)

Check if the solution is optimal.
"""
function general_tests(m)
    @testset "Optimal solution" begin
        @test termination_status(m) == MOI.OPTIMAL

        if termination_status(m) != MOI.OPTIMAL
            @show termination_status(m)
        end
    end
end

include("generate_data.jl")

@testset "Investments" begin
    include("test_model.jl")
    include("test_lifetime.jl")
    include("test_examples.jl")

    @testset "w/Geography" begin
        include("test_geo.jl")
    end
end

