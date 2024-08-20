using HiGHS
using JuMP
using Pkg
using Test

using EnergyModelsBase
using EnergyModelsInvestments
using TimeStruct

const EMB = EnergyModelsBase
const EMI = EnergyModelsInvestments
const TS = TimeStruct

include("utils.jl")

@testset "Investments" begin
    @testset "Investments | model" begin
        include("test_model.jl")
    end

    @testset "Investments | lifetime" begin
        include("test_lifetime.jl")
    end

    @testset "Investments | checks" begin
        include("test_checks.jl")
    end

    @testset "Investments | examples" begin
        include("test_examples.jl")
    end
end
