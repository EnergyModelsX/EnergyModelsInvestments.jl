using HiGHS
using JuMP
using Test

using EnergyModelsBase
using InvestmentModels
using TimeStructures

const EMB = EnergyModelsBase
const IM = InvestmentModels
const TS = TimeStructures


@testset "InvestmentModels" begin
    include("test_discounting.jl")
    include("test_model.jl")
    include("test_lifetime.jl")
end

using Geography
const GEO = Geography
@testset "InvestmentModels with Geography" begin
    include("test_geo_new.jl")
end
