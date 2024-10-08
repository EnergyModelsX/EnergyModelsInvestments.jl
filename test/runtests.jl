using HiGHS
using JuMP
using SparseVariables
using Test

using EnergyModelsInvestments
using TimeStruct

const EMI = EnergyModelsInvestments
const TS = TimeStruct

const TEST_ATOL = 1e-6

include("utils.jl")

@testset "Investments" begin
    @testset "Investments | Investment modes" begin
        include("test_invest.jl")
    end

    @testset "Investments | Lifetime" begin
        include("test_lifetime.jl")
    end
end
