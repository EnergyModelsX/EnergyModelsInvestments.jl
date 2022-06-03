using GLPK
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
    include("test_geo.jl")
    include("test_lifetime.jl")
end
