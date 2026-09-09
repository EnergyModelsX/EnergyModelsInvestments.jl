using HiGHS
using JuMP
using SparseVariables
using Test

using EnergyModelsInvestments
using TimeStruct

const EMI = EnergyModelsInvestments
const TS = TimeStruct

# Define absolute tolerance for floating point comparisons
const TEST_ATOL = 1e-6
≲(a::Real, b::Real) = a ≤ b + TEST_ATOL
≳(a::Real, b::Real) = a + TEST_ATOL ≥ b

include("utils.jl")

@testset "Investments" begin
    @testset "Investments | Investment modes" begin
        include("test_invest.jl")
    end

    @testset "Investments | Lifetime" begin
        include("test_lifetime.jl")
    end
    @testset "Investments | Relations" begin
        include("test_relations.jl")
    end
end
