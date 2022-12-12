using HiGHS
using JuMP
using Test

using EnergyModelsBase
using EnergyModelsInvestments
using TimeStructures

const EMB = EnergyModelsBase
const IM = EnergyModelsInvestments
const TS = TimeStructures

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

@testset "Investments" begin
    include("test_discounting.jl")
    include("test_model.jl")
    include("test_lifetime.jl")
end

using EnergyModelsGeography
const GEO = EnergyModelsGeography
@testset "w/Geography" begin
    include("test_geo_new.jl")
end
