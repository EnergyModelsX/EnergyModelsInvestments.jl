
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

    ## Test for sp2
    t_indx = 2
    t_inv = collect(𝒯ᴵⁿᵛ)[t_indx]

    capex_sp = StrategicProfile([0, 1, 0, 0])*1e4
    CRF = EMI.CRF(inv_data, t_inv, 𝒯ᴵⁿᵛ)
    @testset "Calculation CRF" begin
        @test isapprox(CRF, (0.07 * 1.07^30)/(1.07^30-1))
    end
    annuity_capex = capex_sp[t_inv] * EMI.CRF(inv_data, t_inv, 𝒯ᴵⁿᵛ) # calculate the annuity extended for the entire TH pv_annuity = present_value(annuity_capex, 0.07, 1, 30) # compute the present value of the annuities
    period_annuity_capex = annuity_capex * EMI.set_period_annuity(inv_data, t_inv) # compute the value of single payments at the beginning of each period
    pv = present_value(period_annuity_capex, 0.07, t_inv.duration, 3)
    @testset "Check present value of annuity and period annuity" begin
        @test isapprox(pv_annuity, capex_sp[t_inv])
        @test isapprox(pv, capex_sp[t_inv])
    end

    Tᶜᵘᵐ = EMI.get_cumulative_periods(𝒯ᴵⁿᵛ)
    annuity_capex = Dict(t_inv => capex_sp[t_inv] * EMI.CRF(inv_data, t_inv, 𝒯ᴵⁿᵛ) for t_inv in 𝒯ᴵⁿᵛ)
    period_annuity_capex = Dict(t_inv => annuity_capex[t_inv] * EMI.set_period_annuity(inv_data, t_inv) for t_inv in 𝒯ᴵⁿᵛ)
    cap_capex = Dict(t_inv => sum(period_annuity_capex[t] for t in Tᶜᵘᵐ[t_inv]) for t_inv in 𝒯ᴵⁿᵛ)
    @testset "Check assignment of period_annuities" begin
        @test cap_capex[first(collect(𝒯ᴵⁿᵛ))] == 0 # sp1 has 0 cost from investments in sp2
        @test all([cap_capex[t] == period_annuity_capex[t_inv] for t in collect(𝒯ᴵⁿᵛ)[t_indx:end]]) # from sp2 onwards, annual costs allocated
    end

    vector_capex = [
        StrategicProfile([1, 0, 0, 0])*1e4,
        StrategicProfile([0, 1, 0, 0])*1e4,
        StrategicProfile([0, 0, 1, 0])*1e4,
        StrategicProfile([0, 0, 0, 0])*1e4,
    ]
    annualised_capex = [
        sum((vector_capex[i][t] * EMI.CRF(inv_data, t, 𝒯ᴵⁿᵛ) * EMI.set_period_annuity(inv_data, t)) for t in Tᶜᵘᵐ[t_inv])
        for i in 1:4, t_inv in 𝒯ᴵⁿᵛ]
    @testset "Check explicit calculations with model's results" begin
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
    annualised_capex_sp = [
        sum(capex_sp[t] * EMI.CRF(inv_data, t, 𝒯ᴵⁿᵛ) for t in Tᶜᵘᵐ[t_inv]) for t_inv in 𝒯ᴵⁿᵛ
    ]
    pv = present_value(annualised_capex_sp[t_indx], 0.07, TS.remaining(collect(𝒯ᴵⁿᵛ)[t_indx], 𝒯ᴵⁿᵛ))
    @testset "Check annualised costs allocation and value" begin
        @test first(annualised_capex_sp) == 0 # sp1 has 0 cost from investments in sp2
        @test isapprox(pv, capex_sp[collect(𝒯ᴵⁿᵛ)[t_indx]]) 
    end

    # Check all annualisation of capex 
    vector_capex = [
        StrategicProfile([10* (1 + 1/1.07^20), 0, 0, 0])*1e3,
        StrategicProfile([0, 5* (1 + (1/1.07^20 - 0.5 * 1/1.07^30)), 0, 0])*1e3,
        StrategicProfile([0, 0, 15, 0])*1e3,
        StrategicProfile([0, 0, 0, 5* (1 - 0.5 *  1/1.07^10)])*1e3,
    ]
    annualised_capex = [
        sum(vector_capex[i][t] * EMI.CRF(inv_data, t, 𝒯ᴵⁿᵛ) for t in Tᶜᵘᵐ[t_inv])
        for i in 1:4, t_inv in 𝒯ᴵⁿᵛ]
    @testset "Check with results" begin
        @test all(isapprox.(sum(annualised_capex, dims=1), value.(m[:cap_capex])))        
    end
end

@testset "PeriodLife - CRF" begin
    # Creation and solving of the model
    inv_data = NoStartInvData(
        FixedProfile(1000),
        FixedProfile(40),
        ContinuousInvestment(FixedProfile(0), FixedProfile(15)),
        PeriodLife(FixedProfile(20)),
        0.07
    )
    demand = StrategicProfile([5,10,15,15])
    m, para = simple_model(;inv_data,demand)

    # Extraction of required data
    n = para[:node]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    inv_data = para[:inv_data]
    invest = StrategicProfile([5, 10, 15, 15])*1e3
    capex_explicit = invest * (1 - 0.5 * 1/1.07^10)

    capex = StrategicProfile([
            5 ,
            10 ,
            15,
            15 ,
            ])*1e3
    capex_disc = StrategicProfile([
        EMI.set_capex_discounter(
            duration_strat(t_inv),
            EMI.lifetime(inv_data, t_inv), EMI.get_discount_rate(inv_data)) for t_inv ∈ 𝒯ᴵⁿᵛ])

    @testset "Discounted Capex calculations" begin
        @test all(isapprox.([capex[t_inv] * capex_disc[t_inv] for t_inv in 𝒯ᴵⁿᵛ], [capex_explicit[t_inv] for t_inv in 𝒯ᴵⁿᵛ]))
    end
    
    # Test the Annualised Capital Cost
    Tᶜᵘᵐ = EMI.get_cumulative_periods(𝒯ᴵⁿᵛ)

    ## Test for sp2
    t_indx =2
    capex_sp = StrategicProfile([0, 10 * (1 - 0.5 * 1/1.07^10), 0, 0])*1e3
    CRF = EMI.CRF(inv_data, collect(𝒯ᴵⁿᵛ)[t_indx], 𝒯ᴵⁿᵛ)
    annualised_capex_sp = [
        sum(capex_sp[t] * EMI.CRF(inv_data, t, 𝒯ᴵⁿᵛ) for t in Tᶜᵘᵐ[t_inv]) for t_inv in 𝒯ᴵⁿᵛ
    ]
    pv = present_value(annualised_capex_sp[t_indx], 0.07, TS.remaining(collect(𝒯ᴵⁿᵛ)[t_indx], 𝒯ᴵⁿᵛ))
    @testset "Check annualised costs allocation and value" begin
        @test first(annualised_capex_sp) == 0 # sp1 has 0 cost from investments in sp2
        @test isapprox(pv, capex_sp[collect(𝒯ᴵⁿᵛ)[t_indx]])     
    end

    # Check all annualisation of capex 
    vector_capex = [
        StrategicProfile([5 * (1 - 0.5 * 1/1.07^10), 0, 0, 0])*1e3,
        StrategicProfile([0, 10 * (1 - 0.5 * 1/1.07^10), 0, 0])*1e3,
        StrategicProfile([0, 0, 15 * (1 - 0.5 * 1/1.07^10), 0])*1e3,
        StrategicProfile([0, 0, 0, 15* (1 - 0.5 *  1/1.07^10)])*1e3,
    ]
    annualised_capex = [
        sum(vector_capex[i][t] * EMI.CRF(inv_data, t, 𝒯ᴵⁿᵛ) for t in Tᶜᵘᵐ[t_inv])
        for i in 1:4, t_inv in 𝒯ᴵⁿᵛ]
    @testset "Check with results" begin
        @test all(isapprox.(sum(annualised_capex, dims=1), value.(m[:cap_capex])))        
    end

end