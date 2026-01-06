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

    # Test that the CAPEX is correctly calculated
    # - set_capex_value(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, ::Investment)
    @testset "Capex calculation" begin
        @test all(
            value.(m[:cap_capex])[n, t_inv] ==
                value.(m[:cap_add])[n, t_inv] * EMI.capex(inv_data, t_inv) for
        t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(value.(m[:cap_capex])[n, t_inv] ≈ capex[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
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
    m, para = simple_model(;inv_data, demand)

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
    invest = StrategicProfile([10, 5, 15, 5])

    # Tests of the lifetime calculation
    # - set_capacity_cost(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, disc_rate, ::StudyLife)
    @testset "Lifetime calculations" begin
        # Test the additions are following the predicted value
        @test all(value.(m[:cap_add][n, t_inv]) ≈ invest[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

        # Test the capacities are removed in the end, if it is required
        @test value.(m[:cap_rem][n, last(𝒯ᴵⁿᵛ)]) ≈ 30

        # Test that the CAPEX is correctly calculated
        # - set_capex_discounter(years, lifetime, disc_rate)
        @test all(
            value.(m[:cap_capex])[n, t_inv] ≈
                value.(m[:cap_add])[n, t_inv] * EMI.capex(inv_data, t_inv) *
                EMI.set_capex_discounter(
                    EMI.remaining(t_inv, 𝒯ᴵⁿᵛ),
                    EMI.lifetime(inv_data, t_inv),
                    para[:disc_rate]
        ) for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(value.(m[:cap_capex])[n, t_inv] ≈ capex[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
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
    m, para = simple_model(;inv_data, demand)

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
        # Test that `:cap_add` is equal to `cap_rem` in each investment period and equal
        # to the predicted value
        @test all(value.(m[:cap_add][n, t_inv]) == value.(m[:cap_rem][n, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(value.(m[:cap_add][n, t_inv]) == invest[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

        # Test that the CAPEX is correctly calculated
        # - set_capex_discounter(years, lifetime, disc_rate)
        @test all(
            value.(m[:cap_capex])[n, t_inv] ≈
                value.(m[:cap_add])[n, t_inv] * EMI.capex(inv_data, t_inv) *
                EMI.set_capex_discounter(
                    duration_strat(t_inv),
                    EMI.lifetime(inv_data, t_inv),
                    para[:disc_rate]
        ) for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(value.(m[:cap_capex])[n, t_inv] ≈ capex[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
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
    m, para = simple_model(;inv_data, demand)

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
        # Test that `:cap_add` is equal to `cap_rem` in each investment period and equal
        # to the predicted value
        @test all(value.(m[:cap_add][n, t_inv]) == value.(m[:cap_rem][n, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(value.(m[:cap_add][n, t_inv]) == invest[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

        # Test that the CAPEX is correctly calculated
        # - set_capex_discounter(years, lifetime, disc_rate)
        @test all(
            value.(m[:cap_capex])[n, t_inv] ≈
                value.(m[:cap_add])[n, t_inv] * EMI.capex(inv_data, t_inv) *
                EMI.set_capex_discounter(
                    duration_strat(t_inv),
                    EMI.lifetime(inv_data, t_inv),
                    para[:disc_rate]
                )
        for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(value.(m[:cap_capex])[n, t_inv] ≈ capex[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
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
    m, para = simple_model(;inv_data, demand)

    # Extraction of required data
    n = para[:node]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    inv_data = para[:inv_data]
    invest = StrategicProfile([5, 10, 15, 15])

    # Explicit calculation of CAPEX
    # Investments require no reinvestments and have no remaining value.
    capex = invest * 1e3

    # Tests of the lifetime calculation
    # - set_capacity_cost(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, disc_rate, ::RollingLife)
    @testset "Lifetime calculations" begin
        # Test that `:cap_add` is equal to `cap_rem` in each investment period and equal
        # to the predicted value
        @test all(value.(m[:cap_add][n, t_inv]) == value.(m[:cap_rem][n, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(value.(m[:cap_add][n, t_inv]) == invest[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

        # Test that the CAPEX is correctly calculated
        @test all(
            value.(m[:cap_capex])[n, t_inv] ≈
                value.(m[:cap_add])[n, t_inv] * EMI.capex(inv_data, t_inv)
        for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(value.(m[:cap_capex])[n, t_inv] ≈ capex[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
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
    m, para = simple_model(;inv_data, demand)

    # Extraction of required data
    n = para[:node]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    inv_data = para[:inv_data]
    disc_rate = 1/(1+para[:disc_rate])^10
    invest = StrategicProfile([5, 5, 10, 5])

    # Retirements are at the end of the strategic period following the investment period
    removal = StrategicProfile([0, 5, 5, 10])

    # Explicit calculation of CAPEX
    # 1. Investments do not require reinvestments.
    # 2. The investment in strategic period 4 has a final value, equal to discounted 10/20 %
    #    of the intial value
    capex = StrategicProfile([5, 5, 10, 5*(1-0.5*disc_rate)]) * 1e3

    # Tests of the lifetime calculation
    # - set_capacity_cost(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, disc_rate, ::RollingLife)
    @testset "Lifetime calculations" begin
        # Test that `:cap_rem` follows the lifetime
        @test all(value.(m[:cap_rem][n, t_inv]) == removal[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

        # Test that `:cap_add` follows the lifetime
        @test all(value.(m[:cap_add][n, t_inv]) == invest[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

        # Test that the CAPEX is correctly calculated
        # - set_capex_discounter(years, lifetime, disc_rate)
        @test all(
            value.(m[:cap_capex])[n, t_inv] ≈
                value.(m[:cap_add])[n, t_inv] * EMI.capex(inv_data, t_inv) *
                StrategicProfile([1, 1, 1, 1*(1-0.5*disc_rate)])[t_inv]
        for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(value.(m[:cap_capex])[n, t_inv] ≈ capex[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
    end
end

@testset "RollingLife - Early removal" begin
    # Creation and solving of the model
    inv_data = NoStartInvData(
        FixedProfile(1000),
        FixedProfile(40),
        ContinuousInvestment(FixedProfile(0), FixedProfile(15)),
        RollingLife(FixedProfile(20))
    )
    demand = StrategicProfile([15,15,15,0])
    fixed_opex = FixedProfile(10)
    m, para = simple_model(;inv_data, demand, fixed_opex);

    # Extraction of required data
    n = para[:node]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    inv_data = para[:inv_data]
    disc_rate = 1/(1+para[:disc_rate])^10
    invest = StrategicProfile([15, 0, 15, 0])

    # Retirements are at the end of the strategic period following the investment period
    removal = StrategicProfile([0, 15, 15, 0])

    # Explicit calculation of CAPEX
    # 1. Investments do not require reinvestments.
    # 2. The investment in strategic period 4 has a final value, equal to discounted 10/20 %
    #    of the intial value
    capex = StrategicProfile([15, 0, 15, 0]) * 1e3

    # Tests of the lifetime calculation
    # - set_capacity_cost(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, disc_rate, ::RollingLife)
    @testset "Lifetime calculations" begin
        # Test that `:cap_rem` follows the lifetime
        @test all(value.(m[:cap_rem][n, t_inv]) == removal[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

        # Test that `:cap_add` follows the lifetime
        @test all(value.(m[:cap_add][n, t_inv]) == invest[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

        # Test that the CAPEX is correctly calculated
        # - set_capex_discounter(years, lifetime, disc_rate)
        @test all(
            value.(m[:cap_capex])[n, t_inv] ≈
                value.(m[:cap_add])[n, t_inv] * EMI.capex(inv_data, t_inv) *
                StrategicProfile([1, 1, 1, 1*(1-0.5*disc_rate)])[t_inv]
        for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(value.(m[:cap_capex])[n, t_inv] ≈ capex[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
    end
end

@testset "RollingLife - Multiple removal in one sp" begin
    # Creation and solving of the model
    ts = TwoLevel(4,10,SimpleTimes(4,1))
    inv_data = NoStartInvData(
        FixedProfile(1000),
        FixedProfile(40),
        ContinuousInvestment(FixedProfile(0), FixedProfile(15)),
        RollingLife(StrategicProfile([20,15,25,20]))
    )
    demand = StrategicProfile([5,10,15,15])
    m, para = simple_model(;ts, inv_data, demand)

    # Extraction of required data
    n = para[:node]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    inv_data = para[:inv_data]
    disc_rate_1 = 1/(1+para[:disc_rate])^10
    disc_rate_2 = 1/(1+para[:disc_rate])^20
    invest = StrategicProfile([5, 5, 15, 0])

    # Explicit removal in strategic period 2 due to the retirement of investments from
    # strategic period 1 and 2
    removal = StrategicProfile([0, 10, 0, 0])

    # Explicit calculation of CAPEX
    # 1. Investments do not require reinvestments.
    # 2. The investment in strategic period 2 has a final value, equal to discounted 5/15 %
    #    of the intial value
    # 3. The investment in strategic period 4 has a final value, equal to discounted 5/25 %
    #    of the intial value
    capex = StrategicProfile([5, 5*(1-1/3*disc_rate_1), 15*(1-0.2*disc_rate_2), 0]) * 1e3
    capex_prof = StrategicProfile([1, 1*(1-1/3*disc_rate_1), 1*(1-0.2*disc_rate_2), 1])

    # Tests of the lifetime calculation
    # - set_capacity_cost(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, disc_rate, ::RollingLife)
    @testset "Lifetime calculations" begin
        # Test that `:cap_rem` follows the lifetime
        @test all(value.(m[:cap_rem][n, t_inv]) == removal[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

        # Test that `:cap_add` follows the lifetime
        @test all(value.(m[:cap_add][n, t_inv]) == invest[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

        # Test that the CAPEX is correctly calculated
        # - set_capex_discounter(years, lifetime, disc_rate)
        @test all(
            value.(m[:cap_capex])[n, t_inv] ≈
                value.(m[:cap_add])[n, t_inv] * EMI.capex(inv_data, t_inv) * capex_prof[t_inv]
        for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(value.(m[:cap_capex])[n, t_inv] ≈ capex[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
    end
end

@testset "RollingLife - TwoLevelTree" begin
    # Creation and solving of the model
    inv_data = NoStartInvData(
        FixedProfile(1000),
        FixedProfile(40),
        ContinuousInvestment(FixedProfile(0), FixedProfile(15)),
        RollingLife(FixedProfile(15))
    )
    demand = StrategicProfile([5,15,15,15,15])
    penalty_surplus = FixedProfile(1000)
    fixed_opex = FixedProfile(10)
    op_pers = SimpleTimes(4, 1)
    ts = TwoLevelTree(TreeNode(5, op_pers,
        TreeNode(5, op_pers, [0.7, 0.1, 0.2], [
            TreeNode(2, op_pers, TreeNode(3, op_pers, TreeNode(5, op_pers))),
            TreeNode(4, op_pers, TreeNode(6, op_pers)),
            TreeNode(2, op_pers, TreeNode(8, op_pers))
        ]),
    ); op_per_strat=1.0)
    m, para = simple_model(;inv_data, demand, ts, penalty_surplus, fixed_opex)

    # Extraction of required data
    n = para[:node]
    𝒯 = ts
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    disc(x::Int) = 1/(1+para[:disc_rate])^x
    invest = StrategicStochasticProfile([[5], [10], [0, 0, 0], [0, 5, 5], [5]])

    # Retirements are after 15 years and differing for the different branches
    removal = StrategicStochasticProfile([[0], [0], [0, 5, 5], [5, 10, 10], [10]])

    # Explicit calculation of CAPEX
    # 1. Investments of strategic period 1 require reinvestments (in differing periods in
    #    each branch) and have an end value, depending on the branch.
    # 2. Investments of strategic period 2 do not require reinvestments and do not have and
    #    end value
    # 3. Investments in strategic period 4 and 5 have an end value which is depending on the
    #    branch
    capex = StrategicStochasticProfile([
        [5] .* 1000 * ((1)*0.7 + (1 - 1/15*disc(14))*0.1 + (1 - 3/15*disc(12))*0.2),
        [10] .* 1e3,
        [0, 0, 0],
        [0, 5 * 0.1 * (1-9/15*disc(6)), 5 * 0.2 * (1-7/15*disc(8))] .* 1e3,
        [5 * 0.7] .* 1e3 * (1-10/15*disc(5)),
    ])
    disc_prof = StrategicStochasticProfile([
        [(1)*0.7 + (1 - 1/15*disc(14))*0.1 + (1 - 3/15*disc(12))*0.2],
        [1],
        [0, 0, 0],
        [0, (1-9/15*disc(6)), (1-7/15*disc(8))],
        [(1-10/15*disc(5))],
    ])

    # Tests of the lifetime calculation
    # - set_capacity_cost(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, disc_rate, ::RollingLife)
    @testset "Lifetime calculations" begin
        # Test that `:cap_rem` follows the lifetime
        @test all(value.(m[:cap_rem][n, t_inv]) == removal[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

        # Test that `:cap_add` follows the lifetime
        @test all(value.(m[:cap_add][n, t_inv]) == invest[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

        # Test that the CAPEX is correctly calculated
        # - set_capex_discounter(years, lifetime, disc_rate)
        @test all(
            value.(m[:cap_capex])[n, t_inv] ≈
                value.(m[:cap_add])[n, t_inv] * EMI.capex(inv_data, t_inv) *
                disc_prof[t_inv] * probability_branch(t_inv)
        for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(value.(m[:cap_capex])[n, t_inv] ≈ capex[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
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
    m, para = simple_model(;inv_data, demand)

    # Extraction of required data
    n = para[:node]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    inv_data = para[:inv_data]
    disc_rate = 1/(1+para[:disc_rate])^10
    invest = StrategicProfile([8, 16, 16, 24])

    # Retirements are at the end of the strategic period following the investment period
    removal = StrategicProfile([0, 8, 16, 16])

    # Explicit calculation of CAPEX
    # 1. Investments do not require reinvestments.
    # 2. The investment in strategic period 4 has a final value, equal to discounted 10/20 %
    #    of the intial value
    capex = StrategicProfile([8, 16, 16, 24*(1-0.5*disc_rate)]) * 1e3

    # Tests of the lifetime calculation
    # - set_capacity_cost(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, disc_rate, ::RollingLife)
    @testset "Lifetime calculations" begin
        # Test that `:cap_rem` follows the lifetime
        @test all(value.(m[:cap_rem][n, t_inv]) == removal[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

        # Test that `:cap_add` follows the lifetime
        @test all(value.(m[:cap_add][n, t_inv]) == invest[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

        # Test that the CAPEX is correctly calculated
        # - set_capex_discounter(years, lifetime, disc_rate)
        @test all(
            value.(m[:cap_capex])[n, t_inv] ≈
                value.(m[:cap_add])[n, t_inv] * EMI.capex(inv_data, t_inv) *
                StrategicProfile([1, 1, 1, 1*(1-0.5*disc_rate)])[t_inv]
        for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(value.(m[:cap_capex])[n, t_inv] ≈ capex[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
    end
end
