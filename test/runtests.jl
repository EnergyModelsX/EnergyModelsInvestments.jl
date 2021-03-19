using Test
using InvestmentModels
const IM = InvestmentModels

@testset "Integration tests" begin
    
    # Dummy for now
    @test IM.run_model("") == 0

end