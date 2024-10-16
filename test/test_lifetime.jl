@testset "UnlimitedLife" begin
    # Creation and solving of the model
    demand = StrategicProfile([10,30,30,20])
    m, para = simple_model(;demand)

    # Extraction of required data
    n = para[:node]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    inv_data = para[:inv_data]
    capex = StrategicProfile([1,1,1,0])*1e4

    # Tests of the lifetime calculation
    # - set_capacity_cost(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, disc_rate, ::UnlimitedLife)
    @testset "Lifetime calculations" begin
        # Test that `:cap_rem` is fixed to 0
        @test sum(is_fixed(m[:cap_rem][n, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ==
            length(𝒯ᴵⁿᵛ)
    end

    # Test that the CAPEX is correctly calculated
    # - set_capex_value(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, ::Investment)
    @testset "Capex calculation" begin
        @test sum(
            value.(m[:cap_capex])[n, t_inv] ==
                value.(m[:cap_add])[n, t_inv] * EMI.capex(inv_data, t_inv) for
            t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
        @test sum(
            value.(m[:cap_capex])[n, t_inv] == capex[t_inv] for
            t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
    end
end

@testset "StudyLife" begin
    # Creation and solving of the model
    inv_data = NoStartInvData(
        FixedProfile(1000),
        FixedProfile(40),
        ContinuousInvestment(FixedProfile(0), FixedProfile(15)),
        StudyLife(FixedProfile(20))
    )
    demand = StrategicProfile([10,10,30,35])
    m, para = simple_model(;inv_data,demand)

    # Extraction of required data
    n = para[:node]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    inv_data = para[:inv_data]
    disc_rates = [objective_weight(t_inv, Discounter(para[:disc_rate], 𝒯)) for t_inv ∈ 𝒯ᴵⁿᵛ]
    # Explicit calculation of CAPEX
    # 1. Investments in the first investment period require reinvestments in current period +2 (3).
    #    The reinvestments use their complete lifetime.
    # 2. Investments in the second investment period require reinvestments in current period +2 (3).
    #    The reinvestments use half of their lifetime (-0.5). Due to linear deprecation,
    #    we still have a discounted final value.
    # 3. Investments in the second investment period require do not require reinvestments
    #    and use their complete lifetime.
    # 4. Investments in the second investment period require do not require reinvestments
    #    and use half of their lifetime (-0.5). Due to linear deprecation, we still have a
    #    discounted final value.
    capex = StrategicProfile([
        10 * (1 + disc_rates[3]),
        5 * (1 + (disc_rates[3] - 0.5 * disc_rates[4])),
        15,
        5 * (1 - 0.5 *  disc_rates[2]),
    ])*1e3

    # Tests of the lifetime calculation
    # - set_capacity_cost(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, disc_rate, ::StudyLife)
    @testset "Lifetime calculations" begin
        # Test that `:cap_rem` is fixed to 0
        @test sum(is_fixed(m[:cap_rem][n, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ==
            length(𝒯ᴵⁿᵛ)

        # Test that the CAPEX is correctly calculated
        # - set_capex_discounter(years, lifetime, disc_rate)
        @test sum(
            value.(m[:cap_capex])[n, t_inv] ≈
                value.(m[:cap_add])[n, t_inv] * EMI.capex(inv_data, t_inv) *
                EMI.set_capex_discounter(
                    EMI.remaining(t_inv, 𝒯ᴵⁿᵛ),
                    EMI.lifetime(inv_data, t_inv),
                    para[:disc_rate]
                ) for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
        @test sum(
            value.(m[:cap_capex])[n, t_inv] ≈ capex[t_inv] for
            t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
    end
end

@testset "PeriodLife" begin
    # Creation and solving of the model
    inv_data = NoStartInvData(
        FixedProfile(1000),
        FixedProfile(40),
        ContinuousInvestment(FixedProfile(0), FixedProfile(15)),
        PeriodLife(FixedProfile(20))
    )
    demand = StrategicProfile([5,10,15,15])
    m, para = simple_model(;inv_data,demand)

    # Extraction of required data
    n = para[:node]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    inv_data = para[:inv_data]
    disc_rates = [objective_weight(t_inv, Discounter(para[:disc_rate], 𝒯)) for t_inv ∈ 𝒯ᴵⁿᵛ]
    invest = StrategicProfile([5, 10, 15, 15])
    # Explicit calculation of CAPEX
    # Investments require reinvestments and use half of their lifetime (-0.5).
    # Due to linear deprecation, we still have a discounted final value.
    capex = invest * (1 - 0.5 * disc_rates[2]) * 1e3

    # Tests of the lifetime calculation
    # - set_capacity_cost(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, disc_rate, ::PeriodLife)
    @testset "Lifetime calculations" begin
        # Test that `:cap_add` is equal to `cap_rem` in each investment period
        @test sum(value.(m[:cap_add][n, t_inv]) == value.(m[:cap_rem][n, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ==
            length(𝒯ᴵⁿᵛ)

        # Test that the CAPEX is correctly calculated
        # - set_capex_discounter(years, lifetime, disc_rate)
        @test sum(
            value.(m[:cap_capex])[n, t_inv] ≈
                value.(m[:cap_add])[n, t_inv] * EMI.capex(inv_data, t_inv) *
                EMI.set_capex_discounter(
                    duration_strat(t_inv),
                    EMI.lifetime(inv_data, t_inv),
                    para[:disc_rate]
                ) for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
        @test sum(
            value.(m[:cap_capex])[n, t_inv] ≈ capex[t_inv] for
            t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
    end
end

@testset "RollingLife - Shorter lifetime" begin
    # Creation and solving of the model
    inv_data = NoStartInvData(
        FixedProfile(1000),
        FixedProfile(40),
        ContinuousInvestment(FixedProfile(0), FixedProfile(15)),
        RollingLife(FixedProfile(5))
    )
    demand = StrategicProfile([5,10,15,15])
    m, para = simple_model(;inv_data,demand)

    # Extraction of required data
    n = para[:node]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    inv_data = para[:inv_data]
    disc_rate = 1/(1+para[:disc_rate])^5
    invest = StrategicProfile([5, 10, 15, 15])
    # Explicit calculation of CAPEX
    # Investments require reinvestments.
    capex = invest * (1 + disc_rate) * 1e3

    # Tests of the lifetime calculation
    # - set_capacity_cost(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, disc_rate, ::RollingLife)
    @testset "Lifetime calculations" begin
        # Test that `:cap_add` is equal to `cap_rem` in each investment period
        @test sum(value.(m[:cap_add][n, t_inv]) == value.(m[:cap_rem][n, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ==
            length(𝒯ᴵⁿᵛ)

        # Test that the CAPEX is correctly calculated
        # - set_capex_discounter(years, lifetime, disc_rate)
        @test sum(
            value.(m[:cap_capex])[n, t_inv] ≈
                value.(m[:cap_add])[n, t_inv] * EMI.capex(inv_data, t_inv) *
                EMI.set_capex_discounter(
                    duration_strat(t_inv),
                    EMI.lifetime(inv_data, t_inv),
                    para[:disc_rate]
                ) for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
        @test sum(
            value.(m[:cap_capex])[n, t_inv] ≈ capex[t_inv] for
            t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
    end
end

@testset "RollingLife - Equal lifetime" begin
    # Creation and solving of the model
    inv_data = NoStartInvData(
        FixedProfile(1000),
        FixedProfile(40),
        ContinuousInvestment(FixedProfile(0), FixedProfile(15)),
        RollingLife(FixedProfile(10))
    )
    demand = StrategicProfile([5,10,15,15])
    m, para = simple_model(;inv_data,demand)

    # Extraction of required data
    n = para[:node]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    inv_data = para[:inv_data]
    invest = StrategicProfile([5, 10, 15, 15])
    capex = invest * 1e3

    # Tests of the lifetime calculation
    # - set_capacity_cost(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, disc_rate, ::RollingLife)
    @testset "Lifetime calculations" begin
        # Test that `:cap_add` is equal to `cap_rem` in each investment period
        @test sum(value.(m[:cap_add][n, t_inv]) == value.(m[:cap_rem][n, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ==
            length(𝒯ᴵⁿᵛ)

        # Test that the CAPEX is correctly calculated
        @test sum(
            value.(m[:cap_capex])[n, t_inv] ≈
                value.(m[:cap_add])[n, t_inv] * EMI.capex(inv_data, t_inv)
            for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
        @test sum(
            value.(m[:cap_capex])[n, t_inv] ≈ capex[t_inv] for
            t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
    end
end

@testset "RollingLife - Longer lifetime" begin
    # Creation and solving of the model
    inv_data = NoStartInvData(
        FixedProfile(1000),
        FixedProfile(40),
        ContinuousInvestment(FixedProfile(0), FixedProfile(15)),
        RollingLife(FixedProfile(20))
    )
    demand = StrategicProfile([5,10,15,15])
    m, para = simple_model(;inv_data,demand)

    # Extraction of required data
    n = para[:node]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    inv_data = para[:inv_data]
    disc_rate = 1/(1+para[:disc_rate])^10
    invest = StrategicProfile([5, 5, 10, 5])
    removal = StrategicProfile([0, 5, 5, 0])
    capex = StrategicProfile([5, 5, 10, 5*(1-0.5*disc_rate)]) * 1e3

    # Tests of the lifetime calculation
    # - set_capacity_cost(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, disc_rate, ::RollingLife)
    @testset "Lifetime calculations" begin
        # Test that `:cap_rem` follows the lifetime
        @test sum(value.(m[:cap_rem][n, t_inv]) == removal[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ) ==
            length(𝒯ᴵⁿᵛ)

        # Test that the CAPEX is correctly calculated
        # - set_capex_discounter(years, lifetime, disc_rate)
        @test sum(
            value.(m[:cap_capex])[n, t_inv] ≈
                value.(m[:cap_add])[n, t_inv] * EMI.capex(inv_data, t_inv) *
                StrategicProfile([1, 1, 1, 1*(1-0.5*disc_rate)])[t_inv]
            for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
        @test sum(
            value.(m[:cap_capex])[n, t_inv] ≈ capex[t_inv] for
            t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
    end
end

@testset "RollingLife - Longer lifetime, DiscreteInvestment" begin
    # Creation and solving of the model
    inv_data = NoStartInvData(
        FixedProfile(1000),
        FixedProfile(40),
        DiscreteInvestment(FixedProfile(8)),
        RollingLife(FixedProfile(20))
    )
    demand = StrategicProfile([7, 23, 24.5, 40])
    m, para = simple_model(;inv_data,demand)

    # Extraction of required data
    n = para[:node]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    inv_data = para[:inv_data]
    disc_rate = 1/(1+para[:disc_rate])^10
    invest = StrategicProfile([8, 16, 16, 24])
    removal = StrategicProfile([0, 8, 16, 0])
    capex = StrategicProfile([8, 16, 16, 24*(1-0.5*disc_rate)]) * 1e3

    # Tests of the lifetime calculation
    # - set_capacity_cost(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, disc_rate, ::RollingLife)
    @testset "Lifetime calculations" begin
        # Test that `:cap_rem` follows the lifetime
        @test sum(value.(m[:cap_rem][n, t_inv]) == removal[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ) ==
            length(𝒯ᴵⁿᵛ)

        # Test that the CAPEX is correctly calculated
        # - set_capex_discounter(years, lifetime, disc_rate)
        @test sum(
            value.(m[:cap_capex])[n, t_inv] ≈
                value.(m[:cap_add])[n, t_inv] * EMI.capex(inv_data, t_inv) *
                StrategicProfile([1, 1, 1, 1*(1-0.5*disc_rate)])[t_inv]
            for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
        @test sum(
            value.(m[:cap_capex])[n, t_inv] ≈ capex[t_inv] for
            t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
    end
end
