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

@testset "Investments" begin
    include("utils.jl")
    include("test_model.jl")
    include("test_lifetime.jl")
    include("test_examples.jl")

    @testset "w/Geography" begin
        include("test_geo.jl")
    end
end
