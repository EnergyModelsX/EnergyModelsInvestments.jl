using HiGHS
using JuMP
using Test

using EnergyModelsBase
using EnergyModelsInvestments
using TimeStructures

const EMB = EnergyModelsBase
const IM = EnergyModelsInvestments
const TS = TimeStructures


@testset "EnergyModelsInvestments" begin
    include("test_discounting.jl")
    include("test_model.jl")
    include("test_lifetime.jl")
end

using EnergyModelsGeography
const GEO = EnergyModelsGeography
@testset "EnergyModelsInvestments with EnergyModelsGeography" begin
    include("test_geo_new.jl")
end
