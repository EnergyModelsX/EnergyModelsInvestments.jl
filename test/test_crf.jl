
@testset "UnlimitedLife - CRF" begin
    # Creation and solving of the model
    demand = StrategicProfile([10,30,30,20])
    inv_data = NoStartInvData(
        FixedProfile(1000),
        FixedProfile(30),
        ContinuousInvestment(FixedProfile(0), FixedProfile(10)),
        0.07
    )
    m, para = simple_model(;demand=demand, inv_data=inv_data)

    # Extraction of required data
    n = para[:node]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    inv_data = para[:inv_data]
    capex = StrategicProfile([1,1,1,0])*1e4

    # Test the Annualised Capital Cost
    Tᶜᵘᵐ = EMI.get_cumulative_periods(𝒯ᴵⁿᵛ)

    ## Test for sp2
    t_indx = 2
    capex_sp = StrategicProfile([0, 1, 0, 0])*1e4
    CRF = EMI.CRF(inv_data, collect(𝒯ᴵⁿᵛ)[t_indx], 𝒯ᴵⁿᵛ)
    @testset "Calculation CRF" begin
        @test isapprox(CRF, (0.07 * 1.07^30)/(1.07^30-1))
    end

    annualised_capex_sp = [
        sum(capex_sp[t] * EMI.CRF(inv_data, t, 𝒯ᴵⁿᵛ) * t.duration for t in Tᶜᵘᵐ[t_inv]) for t_inv in 𝒯ᴵⁿᵛ
    ]
    pv_annualised_capex_sp = present_value(annualised_capex_sp[t_indx:end], 0.07, 10)
    @testset "Check annualised costs allocation and value" begin
        @test first(annualised_capex_sp) == 0 # sp1 has 0 cost from investments in sp2
        @test all(annualised_capex_sp[t_indx:end] .== CRF * 1e4 * 10) # from sp2 onwards, annual costs allocated

        @test sum(pv_annualised_capex_sp) > capex_sp[collect(𝒯ᴵⁿᵛ)[t_indx]] # present value of sum of annual costs is higher than capex as it includes return costs
    end

    vector_capex = [
        StrategicProfile([1, 0, 0, 0])*1e4,
        StrategicProfile([0, 1, 0, 0])*1e4,
        StrategicProfile([0, 0, 1, 0])*1e4,
        StrategicProfile([0, 0, 0, 0])*1e4,
    ]
    annualised_capex = [
        sum(vector_capex[i][t] * EMI.CRF(inv_data, t, 𝒯ᴵⁿᵛ) * t.duration for t in Tᶜᵘᵐ[t_inv])
        for i in 1:4, t_inv in 𝒯ᴵⁿᵛ
            ]
    @testset "Check with results" begin
        @test all(isapprox.(sum(annualised_capex, dims=1), value.(m[:cap_capex])))        
    end

end


@testset "StudyLife - CRF" begin
    # Creation and solving of the model
    demand = StrategicProfile([10,10,30,35])
    inv_data = NoStartInvData(
        FixedProfile(1000),
        FixedProfile(40),
        ContinuousInvestment(FixedProfile(0), FixedProfile(15)),
        StudyLife(FixedProfile(20)),
        0.07
    )
    m, para = simple_model(;demand=demand, inv_data=inv_data)

    # Extraction of required data
    n = para[:node]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    inv_data = para[:inv_data]
    
    capex = StrategicProfile([
            10 ,
            5 ,
            15,
            5 ,
            ])*1e3
    capex_disc = StrategicProfile([
        EMI.set_capex_discounter(
            remaining(t_inv, 𝒯ᴵⁿᵛ),
            EMI.lifetime(inv_data, t_inv), EMI.get_discount_rate(inv_data)
        ) for t_inv ∈ 𝒯ᴵⁿᵛ
    ])

    # Test the discount calculation 
    capex_explicit = StrategicProfile([
                                        10 * (1 + 1/1.07^20),
                                        5 * (1 + (1/1.07^20 - 0.5 * 1/1.07^30)),
                                        15,
                                        5 * (1 - 0.5 *  1/1.07^10),
                                        ])*1e3
    @testset "Discounted Capex calculations" begin
        @test all(isapprox.([capex[t_inv] * capex_disc[t_inv] for t_inv in 𝒯ᴵⁿᵛ], [capex_explicit[t_inv] for t_inv in 𝒯ᴵⁿᵛ]))
    end
    
        # Test the Annualised Capital Cost
    Tᶜᵘᵐ = EMI.get_cumulative_periods(𝒯ᴵⁿᵛ)

    ## Test for sp2
    t_indx =2
    capex_sp = StrategicProfile([0, 5 * (1 + (1/1.07^20 - 0.5 * 1/1.07^30)), 0, 0])*1e3
    CRF = EMI.CRF(inv_data, collect(𝒯ᴵⁿᵛ)[t_indx], 𝒯ᴵⁿᵛ)
    @testset "Calculation CRF" begin
        @test isapprox(CRF, (0.07 * 1.07^30)/(1.07^30-1))
    end

    annualised_capex_sp = [
        sum(capex_sp[t] * EMI.CRF(inv_data, t, 𝒯ᴵⁿᵛ) * t.duration for t in Tᶜᵘᵐ[t_inv]) for t_inv in 𝒯ᴵⁿᵛ
    ]
    pv_annualised_capex_sp = present_value(annualised_capex_sp[t_indx:end], 0.07, 10)
    @testset "Check annualised costs allocation and value" begin
        @test first(annualised_capex_sp) == 0 # sp1 has 0 cost from investments in sp2
        @test sum(pv_annualised_capex_sp) > capex_sp[collect(𝒯ᴵⁿᵛ)[t_indx]] # present value of sum of annual costs is higher than capex as it includes return costs
    end

    # Check all annualisation of capex 
    vector_capex = [
        StrategicProfile([10* (1 + 1/1.07^20), 0, 0, 0])*1e3,
        StrategicProfile([0, 5* (1 + (1/1.07^20 - 0.5 * 1/1.07^30)), 0, 0])*1e3,
        StrategicProfile([0, 0, 15, 0])*1e3,
        StrategicProfile([0, 0, 0, 5* (1 - 0.5 *  1/1.07^10)])*1e3,
    ]
    annualised_capex = [
        sum(vector_capex[i][t] * EMI.CRF(inv_data, t, 𝒯ᴵⁿᵛ) * t.duration for t in Tᶜᵘᵐ[t_inv])
        for i in 1:4, t_inv in 𝒯ᴵⁿᵛ]
    @testset "Check with results" begin
        @test all(isapprox.(sum(annualised_capex, dims=1), value.(m[:cap_capex])))        
    end
end