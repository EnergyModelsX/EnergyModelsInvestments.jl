
@testset "Investment Model" begin
    
    # Create simple model
    
    r = 0.07
    
    case = IM.StrategicCase(StrategicFixedProfile([450, 400, 350, 300]))    # 
    model = IM.InvestmentModel(case, r)
    #m = EMB.create_model(data, model)

    m, data = IM.run_model("", model, GLPK.Optimizer)
    # Check model
    @test size(all_variables(m))[1] == 11548

    # Check results
    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test round(objective_value(m)) ≈ -204382

    print("~~~~~~ CAPACITY ~~~~~~ \n")
    for n in data[:nodes],t in strategic_periods(data[:T])
        print(n,", ",t,"   :   ",JuMP.value(m[:capacity][n,t]),"\n")
    end
    print("~~~~~~ ADD_CAP ~~~~~~ \n")
    for n in data[:nodes],t in strategic_periods(data[:T])
        print(n,", ",t,"   :   ",JuMP.value(m[:add_cap][n,t]),"\n")
    end
    print("~~~~~~ REM_CAP ~~~~~~ \n")
    for n in data[:nodes],t in strategic_periods(data[:T])

        print(n,", ",t,"   :   ",JuMP.value(m[:rem_cap][n,t]),"\n")
    end

    CH4 = data[:products][1]
    CO2 = data[:products][4]
    𝒯ᴵⁿᵛ = strategic_periods(data[:T])
    emissions_CO2 = [value.(m[:emissions_strategic])[t_inv,CO2] for t_inv ∈ 𝒯ᴵⁿᵛ]
    @test emissions_CO2 <= [450, 400, 350, 300]
    emissions_CH4 = [value.(m[:emissions_strategic])[t_inv,CH4] for t_inv ∈ 𝒯ᴵⁿᵛ]
    @test emissions_CH4 <= [0, 0, 0, 0]
    # With binary variables

    # Check model/results


end

#𝒩ᶜᵃᵖ = (i for i ∈ data[:nodes] if IM.has_capacity(i))
#for n in 𝒩ᶜᵃᵖ,t in strategic_periods(data[:T])
#    print(JuMP.value(m[:capex][n,t]))
#    print(JuMP.value(m[:capacity][n,t]))
#end