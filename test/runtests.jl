using Test
using InvestmentModels
using TimeStructures
const IM = InvestmentModels


# @testset "Integration tests" begin
    
#     # Dummy for now
#     @test_broken IM.run_model("") !== nothing

# end

include("test_discounting.jl")