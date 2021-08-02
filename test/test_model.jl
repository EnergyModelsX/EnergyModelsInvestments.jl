
@testset "Investment Model" begin
    
    # Create simple model
    
    # Dummy data
    data = IM.testdata()
    r = 0.07
    @test length(data) == 4
    
    case = IM.StrategicCase(StrategicFixedProfile([450, 400, 350, 300]))    # 
    model = IM.InvestmentModel(case, r)
    m = EMB.create_model(data, model)

    # Check model

    # Check results

    # With binary variables

    # Check model/results


end