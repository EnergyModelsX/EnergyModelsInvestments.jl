using Test
using InvestmentModels
using TimeStructures
using EnergyModelsBase
const IM = InvestmentModels
const EMB = EnergyModelsBase


# @testset "Integration tests" begin
    
#     # Dummy for now
#     @test_broken IM.run_model("") !== nothing

# end

include("test_discounting.jl")
include("test_model.jl")