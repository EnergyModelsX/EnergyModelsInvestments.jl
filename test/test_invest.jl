@testset "ContinuousInvestment" begin
    # Creation and solving of the model
    m, para = simple_model()

    # Extraction of required data
    n = para[:node]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    inv_data = para[:inv_data]
    capex = StrategicProfile([1,1,1,0])*1e4

    # Tests of the objective value
    @test objective_value(m) ≈ -688804.2

    # Tests of the capacities
    # - add_investment_constraints()
    @testset "Investment balance" begin
        # Test that cap_inst is less than the maximum installed capacity at all times
        @test sum(
            value.(m[:cap_inst][n, t]) ≤ EMI.max_installed(inv_data, t) for t ∈ 𝒯
        ) == length(𝒯)

        # Test that :cap_inst is equivalent to the :cap_current
        @test sum(
                sum(
                    value.(m[:cap_inst][n, t]) == value.(m[:cap_current][n, t_inv])
                for t ∈ t_inv)
            for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯)

        # Test the initial installed capacity is correctly set.
        @test value.(m[:cap_current][n, first(𝒯ᴵⁿᵛ)]) ==
            para[:initial][first(𝒯ᴵⁿᵛ)] + value.(m[:cap_add][n, first(𝒯ᴵⁿᵛ)]
        )
        @test sum(
                value.(m[:cap_current][n, t_inv]) ==
                    value.(m[:cap_current][n, t_inv_prev]) +
                    value.(m[:cap_add][n, t_inv]) - value.(m[:cap_rem][n, t_inv_prev]) for
                (t_inv_prev, t_inv) ∈ withprev(𝒯ᴵⁿᵛ) if !isnothing(t_inv_prev)
            ) == length(𝒯ᴵⁿᵛ) - 1
        @test sum(
                value.(m[:cap_current][n, t_inv]) == para[:demand][t_inv]
            for t_inv ∈ 𝒯ᴵⁿᵛ) == 2
    end

    # Test that we do not violate the bounds
    # - set_capacity_installation(m, element, prefix, 𝒯ᴵⁿᵛ, inv_mode::Investment)
    @testset "Bounds" begin
        @test sum(
                value.(m[:cap_add][n, t_inv]) ≥ EMI.min_add(inv_data, t_inv) for
                t_inv ∈ 𝒯ᴵⁿᵛ
            ) == length(𝒯ᴵⁿᵛ)

        @test sum(
                value.(m[:cap_add][n, t_inv]) ≤ EMI.max_add(inv_data, t_inv) for
                t_inv ∈ 𝒯ᴵⁿᵛ
            ) == length(𝒯ᴵⁿᵛ)
    end

    # Test that the binary variables are not created for the element
    @test isempty(m[:cap_invest_b])
    @test isempty(m[:cap_remove_b])

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

@testset "SemiContinuousInvestment" begin
    # Creation and solving of the model
    inv_data = NoStartInvData(
        FixedProfile(1000),
        FixedProfile(30),
        SemiContinuousInvestment(FixedProfile(10), FixedProfile(30)),
    )
    demand = StrategicProfile([0, 20, 25, 30])
    m, para = simple_model(; inv_data, demand)

    # Extraction of required data
    n = para[:node]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)

    # Test that we do not violate the bounds
    # - set_capacity_installation(m, element, prefix, 𝒯ᴵⁿᵛ, inv_mode::SemiContiInvestment)
    @testset "Bounds" begin
        @test sum(
                value.(m[:cap_add][n, t_inv]) ≥ EMI.min_add(inv_data, t_inv) for
                t_inv ∈ 𝒯ᴵⁿᵛ
            ) + sum(value.(m[:cap_add][n, t_inv]) ≈ 0 for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
        @test sum(
                value.(m[:cap_add][n, t_inv]) ≥ EMI.min_add(inv_data, t_inv) for
                t_inv ∈ 𝒯ᴵⁿᵛ
            ) > 0
        @test sum(value.(m[:cap_add][n, t_inv]) ≈ 0 for t_inv ∈ 𝒯ᴵⁿᵛ) == 2
    end

    # Test that the variable `:cap_invest_b` is a binary and created for the element
    # while `:cap_remove_b` is not created
    @testset "Binary variables" begin
        @test sum(is_binary(m[:cap_invest_b][n, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ==
            length(𝒯ᴵⁿᵛ)
        @test length(m[:cap_invest_b]) == length(𝒯ᴵⁿᵛ)
        @test isempty(m[:cap_remove_b])
    end
end

@testset "SemiContinuousOffsetInvestment" begin
    # Creation and solving of the model
    inv_data = NoStartInvData(
        FixedProfile(10),
        FixedProfile(30),
        SemiContinuousOffsetInvestment(FixedProfile(10), FixedProfile(30), FixedProfile(1000)),
    )
    demand = StrategicProfile([0, 20, 25, 30])
    m, para = simple_model(; inv_data, demand)

    # Extraction of required data
    n = para[:node]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    capex = StrategicProfile([0, 1300, 0, 0])

    # Test that we do not violate the bounds
    # - set_capacity_installation(m, element, prefix, 𝒯ᴵⁿᵛ, inv_mode::SemiContiInvestment)
    @testset "Bounds" begin
        @test sum(
                value.(m[:cap_add][n, t_inv]) ≥ EMI.min_add(inv_data, t_inv) for
                t_inv ∈ 𝒯ᴵⁿᵛ
            ) + sum(value.(m[:cap_add][n, t_inv]) ≈ 0 for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
        @test sum(
                value.(m[:cap_add][n, t_inv]) ≥ EMI.min_add(inv_data, t_inv) for
                t_inv ∈ 𝒯ᴵⁿᵛ
            ) > 0
        @test sum(value.(m[:cap_add][n, t_inv]) ≈ 0 for t_inv ∈ 𝒯ᴵⁿᵛ) == 3
    end

    # Test that the variable `:cap_invest_b` is a binary and created for the element
    # while `:cap_remove_b` is not created
    @testset "Binary variables" begin
        @test sum(is_binary(m[:cap_invest_b][n, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ==
            length(𝒯ᴵⁿᵛ)
        @test length(m[:cap_invest_b]) == length(𝒯ᴵⁿᵛ)
        @test isempty(m[:cap_remove_b])
    end

    # Test that the CAPEX is correctly calculated
    # - set_capex_value(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, ::Investment)
    @testset "Capex calculation" begin
        @test sum(
            value.(m[:cap_capex])[n, t_inv] ==
                value.(m[:cap_add])[n, t_inv] * EMI.capex(inv_data, t_inv) +
                value.(m[:cap_invest_b][n, t_inv]) * EMI.capex_offset(inv_data, t_inv)
            for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
        @test sum(
            value.(m[:cap_capex])[n, t_inv] == capex[t_inv] for
            t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
    end
end

@testset "DiscreteInvestment" begin
    # Creation and solving of the model
    inv_data = NoStartInvData(
        FixedProfile(1000),
        FixedProfile(40),
        DiscreteInvestment(FixedProfile(8)),
    )
    demand = StrategicProfile([7, 8.5, 24, 40])
    penalty_deficit = FixedProfile(5e2)
    fixed_opex = FixedProfile(10)
    m, para = simple_model(; inv_data, demand, penalty_deficit, fixed_opex)

    # Extraction of required data
    n = para[:node]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    invest = StrategicProfile([8, 0, 16, 16])

    # Test that we do not violate the bounds
    # - set_capacity_installation(m, element, prefix, 𝒯ᴵⁿᵛ, inv_mode::DiscreteInvestment)
    @testset "Bounds" begin
        @test sum(
                value.(m[:cap_add][n, t_inv]) ==
                    EMI.increment(inv_data, t_inv) * value.(m[:cap_invest_b][n, t_inv])
                for t_inv ∈ 𝒯ᴵⁿᵛ
            ) == length(𝒯ᴵⁿᵛ)
        @test sum(value.(m[:cap_add][n, t_inv]) == invest[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ) ==
            length(𝒯ᴵⁿᵛ)
        @test sum(value.(m[:cap_add][n, t_inv]) ≈ 0 for t_inv ∈ 𝒯ᴵⁿᵛ) == 1
    end

    # Test the properties of the integer variables
    # - set_capacity_installation(m, element, prefix, 𝒯ᴵⁿᵛ, inv_mode::DiscreteInvestment)
    @testset "Integer variables" begin
        # Test that the integer variables are created
        @test sum(is_integer(m[:cap_invest_b][n, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ==
            length(𝒯ᴵⁿᵛ)
        @test sum(is_integer(m[:cap_remove_b][n, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ==
            length(𝒯ᴵⁿᵛ)

        # Test that the variable cap_invest_b is 2 exactly twice
        @test sum(value.(m[:cap_invest_b][n, t_inv]) ≈ 2 for t_inv ∈ 𝒯ᴵⁿᵛ) == 2
    end
end

@testset "FixedInvestment" begin
    # Creation and solving of the model
    inv_data = NoStartInvData(
        FixedProfile(1000),
        FixedProfile(40),
        FixedInvestment(StrategicProfile([2, 20, 25, 30])),
    )
    demand = StrategicProfile([2, 20, 25, 30])
    m, para = simple_model(; inv_data, demand)

    # Extraction of required data
    n = para[:node]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    invest = StrategicProfile([2, 18, 5, 5])

    # Test that we do not violate the bounds
    # - set_capacity_installation(m, element, prefix, 𝒯ᴵⁿᵛ, inv_mode::FixedInvestment)
    @testset "Bounds" begin
        # Test that the investments are happening based on the specified profile
        @test sum(
            value.(m[:cap_current][n, t_inv]) ≈ EMI.invest_capacity(inv_data, t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ
        ) == length(𝒯ᴵⁿᵛ)

        # Test that the capacity addition is correctly calculated
        @test sum(
            value.(m[:cap_add][n, t_inv]) ≈ invest[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ
        ) == length(𝒯ᴵⁿᵛ)
    end

    # Test the properties of the binary variables
    # - set_capacity_installation(m, element, prefix, 𝒯ᴵⁿᵛ, inv_mode::FixedInvestment)
    @testset "Integer variables" begin
        # Test that the variable `cap_invest_b` is fixed
        @test sum(is_fixed(m[:cap_invest_b][n, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ==
                length(𝒯ᴵⁿᵛ)
        @test isempty(m[:cap_remove_b])
    end
end

@testset "BinaryInvestment" begin
    # Creation and solving of the model
    inv_data = NoStartInvData(
        FixedProfile(1000),
        FixedProfile(40),
        BinaryInvestment(StrategicProfile([2, 20, 25, 30])),
    )
    demand = StrategicProfile([7, 8.5, 24, 40])
    penalty_deficit = FixedProfile(5e2)
    fixed_opex = FixedProfile(10)
    m, para = simple_model(; inv_data, demand, penalty_deficit, fixed_opex)

    # Extraction of required data
    n = para[:node]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    invest = StrategicProfile([2, 18, 5, 5])

    # Test that we do not violate the bounds
    # - set_capacity_installation(m, element, prefix, 𝒯ᴵⁿᵛ, inv_mode::DiscreteInvestment)
    @testset "Bounds" begin
        # Test that the investments are happening based on the specified profile
        @test sum(
            value.(m[:cap_current][n, t_inv]) ≈ EMI.invest_capacity(inv_data, t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ
        ) == length(𝒯ᴵⁿᵛ)

        # Test that the capacity addition is correctly calculated
        @test sum(
            value.(m[:cap_add][n, t_inv]) ≈ invest[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ
        ) == length(𝒯ᴵⁿᵛ)
    end

    # Test the properties of the binary variables
    # - set_capacity_installation(m, element, prefix, 𝒯ᴵⁿᵛ, inv_mode::DiscreteInvestment)
    @testset "Integer variables" begin
        # Test that the binary variables are created
        @test sum(is_binary(m[:cap_invest_b][n, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ==
            length(𝒯ᴵⁿᵛ)

        # Test that the variable cap_invest_b is always one
        @test sum(value.(m[:cap_invest_b][n, t_inv]) ≈ 1 for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
    end
end
