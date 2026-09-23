@testset "`max_budget`" begin
    # A budget requiring investments in the expensive node with the high fixed OPEX
    # Investment data with positive costs and continuous capacity additions
    fixed_opex = [
        FixedProfile(0),
        FixedProfile(1),
        FixedProfile(10),
    ]

    # Creation of the model with positive investment costs and no demand
    inv_data = NoStartInvData(
        FixedProfile(10),
        FixedProfile(10),
        ContinuousInvestment(FixedProfile(0), FixedProfile(10)),
    )
    demand = FixedProfile(20)

    @testset "No constraints added" begin
        # Creation of the model
        m, para = simple_model(; demand, inv_data, fixed_opex, num_invest = 3)

        # Extraction of required data
        n_1, n_2, n_3 = para[:nodes]
        𝒯 = para[:T]
        𝒯ᴵⁿᵛ = strat_periods(𝒯)

        # Variable reassignment
        var_cur = value.(m[:cap_current])

        # Test that without any limits, it only invests in node 1 and 2 in the first period
        prof_cur_1 = FixedProfile(10)
        prof_cur_2 = FixedProfile(10)
        prof_cur_3 = FixedProfile(0)
        @test all(var_cur[n_1, t_inv] ≈ prof_cur_1[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(var_cur[n_2, t_inv] ≈ prof_cur_2[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(var_cur[n_3, t_inv] ≈ prof_cur_3[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
    end

    @testset "`max_budget`" begin
        @testset "All strategic periods" begin
            # Creation of the model
            m, para = simple_model(; demand, inv_data, fixed_opex, num_invest = 3)

            # Extraction of required data
            n_1, n_2, n_3 = para[:nodes]
            𝒯 = para[:T]
            𝒯ᴵⁿᵛ = strat_periods(𝒯)

            # Variable reassignment
            var_cur = value.(m[:cap_current])

            # Addition of the investment relation and reoptimization
            investments = [(n_1, :cap), (n_2, :cap)]
            max_budget(m, 150, investments, 𝒯)
            optimize!(m)
            var_cur = value.(m[:cap_current])

            # Test that with limits, it must invest in node 3 in the first period to avoid a
            # deficit
            prof_cur_1 = FixedProfile(10)
            prof_cur_2 = FixedProfile(5)
            prof_cur_3 = FixedProfile(5)
            @test all(var_cur[n_1, t_inv] ≈ prof_cur_1[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
            @test all(var_cur[n_2, t_inv] ≈ prof_cur_2[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
            @test all(var_cur[n_3, t_inv] ≈ prof_cur_3[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

            # Test that the budget is not violated
            @test sum(
                value.(m[:cap_capex][n, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ, n ∈ [n_1, n_2]
            ) ≲ 150
        end
    end

    @testset "`max_budget`" begin
        @testset "Limited strategic periods" begin
            # Creation of the model
            m, para = simple_model(; demand, inv_data, fixed_opex, num_invest = 3)

            # Extraction of required data
            n_1, n_2, n_3 = para[:nodes]
            𝒯 = para[:T]
            𝒯ᴵⁿᵛ = strat_periods(𝒯)

            # Addition of the investment relation and reoptimizationc
            sps_spec = collect(𝒯ᴵⁿᵛ)[1:2]
            investments = [(n_1, :cap), (n_2, :cap)]
            max_budget(m, 150, investments, 𝒯; sps_spec)
            optimize!(m)
            var_cur = value.(m[:cap_current])

            # Test that with limits, it must invest in node 3 in the first period to avoid a
            # deficit, but reinvests in node 2 in period 3 with removal of the capacity of node 1
            prof_cur_1 = FixedProfile(10)
            prof_cur_2 = StrategicProfile([5, 5, 10, 10])
            prof_cur_3 = StrategicProfile([5, 5, 0, 0])
            @test all(var_cur[n_1, t_inv] ≈ prof_cur_1[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
            @test all(var_cur[n_2, t_inv] ≈ prof_cur_2[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
            @test all(var_cur[n_3, t_inv] ≈ prof_cur_3[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

            # Test that the budget is not violated
            @test sum(
                value.(m[:cap_capex][n, t_inv]) for t_inv ∈ sps_spec, n ∈ [n_1, n_2]
            ) ≲ 150
        end
    end
end

@testset "`max_investments` and `min_investments`" begin
    # Investment data with positive costs and semi continuous investment decisions
    inv_data = NoStartInvData(
        FixedProfile(100),
        FixedProfile(60),
        SemiContinuousOffsetInvestment(FixedProfile(5), FixedProfile(20), FixedProfile(500)),
    )
    demand = StrategicProfile([30, 40, 50, 40])
    fixed_opex = [FixedProfile(1), FixedProfile(1.1)]


    @testset "No constraints added" begin
        # Creation of the model
        m, para = simple_model(; demand, inv_data, fixed_opex, num_invest = 2)

        # Extraction of required data
        n_1, n_2 = para[:nodes]
        𝒯 = para[:T]
        𝒯ᴵⁿᵛ = strat_periods(𝒯)

        # Variable reassignment
        var_add = value.(m[:cap_add])

        # Test that without any limits, it invests according to the demand increase
        prof_add_1 = StrategicProfile([20, 10, 10, 0])
        prof_add_2 = StrategicProfile([10, 0, 0, 0])
        @test all(var_add[n_1, t_inv] ≈ prof_add_1[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(var_add[n_2, t_inv] ≈ prof_add_2[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

        # Test that 4 investments is optimal
        @test sum(value.(m[:cap_invest_b][n, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ, n ∈ [n_1, n_2]) ≈ 4
    end

    @testset "`max_investments`" begin
        @testset "All strategic periods" begin
            # Creation of the model
            m, para = simple_model(; demand, inv_data, fixed_opex, num_invest = 2)

            # Extraction of required data
            n_1, n_2 = para[:nodes]
            𝒯 = para[:T]
            𝒯ᴵⁿᵛ = strat_periods(𝒯)

            # Addition of the investment relation and reoptimization
            investments = [(n_1, :cap), (n_2, :cap)]
            max_investments(m, 2, investments, 𝒯)
            optimize!(m)
            var_add = value.(m[:cap_add])

            # Test that with limits, it must overinvest in node 2 in the first period to avoid a
            # deficit
            prof_add_1 = StrategicProfile([20, 0, 0, 0])
            prof_add_2 = StrategicProfile([20, 0, 0, 0])
            @test all(var_add[n_1, t_inv] ≈ prof_add_1[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
            @test all(var_add[n_2, t_inv] ≈ prof_add_2[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

            # Test that the budget is not violated
            @test sum(
                value.(m[:cap_invest_b][n, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ, n ∈ [n_1, n_2]
            ) ≲ 2

            # Test that this leads to a deficit in periods 3 and 4, despite its significant cost
            prof_def = StrategicProfile([0, 0, 10, 0])
            @test all(value.(m[:deficit][t]) ≈ prof_def[t] for t ∈ 𝒯)
        end

        @testset "Limited strategic periods" begin
            # Creation of the model with positive investment costs and no demand
            m, para = simple_model(; demand, inv_data, fixed_opex, num_invest = 2)

            # Extraction of required data
            n_1, n_2 = para[:nodes]
            𝒯 = para[:T]
            𝒯ᴵⁿᵛ = strat_periods(𝒯)

            # Addition of the investment relation and reoptimizationc
            sps_spec = collect(𝒯ᴵⁿᵛ)[1:2]
            investments = [(n_1, :cap), (n_2, :cap)]
            max_investments(m, 2, investments, 𝒯; sps_spec)
            optimize!(m)
            var_add = value.(m[:cap_add])

            # Test that with limits, it must overinvest in node 2 in the first period to avoid a
            # deficit in the second. The additional investment in the third period is no longer
            # covered by the limit
            prof_add_1 = StrategicProfile([20, 0, 10, 0])
            prof_add_2 = StrategicProfile([20, 0, 0, 0])
            @test all(var_add[n_1, t_inv] ≈ prof_add_1[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
            @test all(var_add[n_2, t_inv] ≈ prof_add_2[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

            # Test that the budget is not violated in the relevant periods
            @test sum(
                value.(m[:cap_invest_b][n, t_inv]) for t_inv ∈ sps_spec, n ∈ [n_1, n_2]
            ) ≲ 2

            # Test that there is not deficit in any period
            @test all(value.(m[:deficit][t]) ≈ 0 for t ∈ 𝒯)
        end
    end

    @testset "`min_investments`" begin
        @testset "All strategic periods" begin
            # Creation of the model with positive investment costs and no demand
            m, para = simple_model(; demand, inv_data, fixed_opex, num_invest = 2)

            # Extraction of required data
            n_1, n_2 = para[:nodes]
            𝒯 = para[:T]
            𝒯ᴵⁿᵛ = strat_periods(𝒯)

            # Addition of the investment relation and reoptimization
            investments = [(n_1, :cap), (n_2, :cap)]
            min_investments(m, 5, investments, 𝒯)
            optimize!(m)
            var_add = value.(m[:cap_add])

            # Test that with limits, it must invest in period 3 in both the cheap and expensive
            # technology to maintain the limit
            prof_add_1 = StrategicProfile([20, 10, 5, 0])
            prof_add_2 = StrategicProfile([10, 0, 5, 0])
            @test all(var_add[n_1, t_inv] ≈ prof_add_1[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
            @test all(var_add[n_2, t_inv] ≈ prof_add_2[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

            # Test that the budget is not violated
            @test sum(value.(m[:cap_invest_b][n, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ, n ∈ [n_1, n_2]) ≳ 5
        end

        @testset "Limited strategic periods" begin
            # Creation of the model with positive investment costs and no demand
            m, para = simple_model(; demand, inv_data, fixed_opex, num_invest = 2)

            # Extraction of required data
            n_1, n_2 = para[:nodes]
            𝒯 = para[:T]
            𝒯ᴵⁿᵛ = strat_periods(𝒯)

            # Addition of the investment relation and reoptimization
            sps_spec = collect(𝒯ᴵⁿᵛ)[1:2]
            investments = [(n_1, :cap), (n_2, :cap)]
            min_investments(m, 4, investments, 𝒯; sps_spec)
            optimize!(m)
            var_add = value.(m[:cap_add])

            # Test that with limits, it must invest in period 2 in both the cheap and expensive
            # technology to maintain the limit
            prof_add_1 = StrategicProfile([20, 5, 10, 0])
            prof_add_2 = StrategicProfile([10, 5, 0, 0])
            @test all(var_add[n_1, t_inv] ≈ prof_add_1[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
            @test all(var_add[n_2, t_inv] ≈ prof_add_2[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

            # Test that the budget is not violated
            @test sum(value.(m[:cap_invest_b][n, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ, n ∈ [n_1, n_2]) ≳ 4
        end
    end

    @testset "Binary relations - no binary investment variables" begin
        # Continuous investments do not create binary investment variables
        inv_data = NoStartInvData(
            FixedProfile(100),
            FixedProfile(60),
            ContinuousInvestment(FixedProfile(0), FixedProfile(30)),
        )
        m, para = simple_model(;inv_data, num_invest = 2)
        n_1, n_2 = para[:nodes]
        𝒯 = para[:T]
        investments = [(node, :cap) for node ∈ para[:nodes]]
        @test_throws ArgumentError max_investments(m, 1, investments, 𝒯)
        @test_throws ArgumentError min_investments(m, 1, investments, 𝒯)

        # No investment data also does not create binary variables
        m, para = simple_model(; num_invest = 2)
        n_1, n_2 = para[:nodes]
        𝒯 = para[:T]
        investments = [(node, :cap) for node ∈ para[:nodes]]
        @test_throws ArgumentError max_investments(m, 1, investments, 𝒯)
        @test_throws ArgumentError min_investments(m, 1, investments, 𝒯)
    end
end

@testset "`requires_capacity`, `couple_capacity`, `precede_capacity`, and `retire_capacity`" begin
    # Investment data with positive costs and semi continuous investment decisions
    # The semi continuous investment can lead to early capacity retirement
    inv_data = NoStartInvData(
        FixedProfile(100),
        FixedProfile(60),
        SemiContinuousInvestment(FixedProfile(5), FixedProfile(30)),
    )
    demand = StrategicProfile([30, 40, 50, 40])
    fixed_opex = [FixedProfile(1), FixedProfile(1.1)]

    @testset "No constraints added" begin
        # Creation of the model
        m, para = simple_model(; demand, inv_data, fixed_opex, num_invest = 2)

        # Extraction of required data
        n_1, n_2 = para[:nodes]
        𝒯 = para[:T]
        𝒯ᴵⁿᵛ = strat_periods(𝒯)

        # Variable reassignment
        var_cur = value.(m[:cap_current])

        # Test that without any constraints, it invests according to the demand in node 1 to
        # satisfy the demand
        prof_cur_2 = FixedProfile(0)
        @test all(var_cur[n_1, t_inv] ≈ demand[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(var_cur[n_2, t_inv] ≈ prof_cur_2[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
    end

    @testset "`requires_capacity`" begin
        @testset "no keyword argument used" begin
            # Creation of the model
            fixed_opex = [FixedProfile(1), FixedProfile(1.1), FixedProfile(1.2)]
            m, para = simple_model(; demand, inv_data, fixed_opex, num_invest = 3)

            # Extraction of required data
            n_1, n_2, n_3 = para[:nodes]
            𝒯 = para[:T]
            𝒯ᴵⁿᵛ = strat_periods(𝒯)

            # Addition of the investment relation and reoptimization
            elements_dep = [(n_1, :cap), (n_2, :cap)]
            element_pre = (n_3, :cap)
            requires_capacity(m, elements_dep, element_pre, 𝒯)
            optimize!(m)
            var_cur = value.(m[:cap_current])

            # Test that each dependent capacity is at most the prerequisite capacity
            prof_cur_13 = StrategicProfile([15, 20, 20, 20])
            prof_cur_2 = StrategicProfile([0, 0, 10, 0])
            @test all(var_cur[n_1, t_inv] ≈ prof_cur_13[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
            @test all(var_cur[n_2, t_inv] ≈ prof_cur_2[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
            @test all(var_cur[n_3, t_inv] ≈ prof_cur_13[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
            @test all(
                var_cur[element_dep, t_inv] ≲ var_cur[n_3, t_inv]
            for (element_dep, _) ∈ elements_dep, t_inv ∈ 𝒯ᴵⁿᵛ)
        end

        @testset "Keyword argument used" begin
            # Creation of the model
            m, para = simple_model(; demand, inv_data, fixed_opex, num_invest = 2)

            # Extraction of required data
            n_1, n_2 = para[:nodes]
            𝒯 = para[:T]
            𝒯ᴵⁿᵛ = strat_periods(𝒯)

            # Addition of the investment relation and reoptimization
            capacity_ratio = 2
            elements_dep = [(n_1, :cap)]
            element_pre = (n_2, :cap)
            requires_capacity(m, elements_dep, element_pre, 𝒯; capacity_ratio)
            optimize!(m)
            var_cur = value.(m[:cap_current])

            # Test that with limits, it must have at most the same capacity in node 1 as in
            # node 2 times the value `capacity_ratio`
            # The difference in strategic periods 2 and 3 is due to the semicontinuous investment
            prof_cur_1 = StrategicProfile([20, 25, 30, 40*2/3])
            prof_cur_2 = StrategicProfile([10, 15, 20, 40*1/3])
            @test all(var_cur[n_1, t_inv] ≈ prof_cur_1[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
            @test all(var_cur[n_2, t_inv] ≈ prof_cur_2[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
            @test all(
                var_cur[n_1, t_inv] ≲ var_cur[n_2, t_inv] * capacity_ratio
            for t_inv ∈ 𝒯ᴵⁿᵛ)
        end
    end

    @testset "`couple_capacity`" begin
        @testset "No keyword argument used" begin
            # Creation of the model
            m, para = simple_model(; demand, inv_data, fixed_opex, num_invest = 2)

            # Extraction of required data
            n_1, n_2 = para[:nodes]
            𝒯 = para[:T]
            𝒯ᴵⁿᵛ = strat_periods(𝒯)

            # Addition of the investment relation and reoptimization
            couple_capacity(m, (n_1, :cap), (n_2, :cap), 𝒯)
            optimize!(m)
            var_cur = value.(m[:cap_current])

            # Test that with limits, it must have the same capacity in both nodes
            prof_cur = StrategicProfile([15, 20, 25, 20])
            @test all(var_cur[n_1, t_inv] ≈ prof_cur[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
            @test all(var_cur[n_2, t_inv] ≈ prof_cur[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
        end

        @testset "Keyword argument used" begin
            # Creation of the model
            m, para = simple_model(; demand, inv_data, fixed_opex, num_invest = 2)

            # Extraction of required data
            n_1, n_2 = para[:nodes]
            𝒯 = para[:T]
            𝒯ᴵⁿᵛ = strat_periods(𝒯)

            # Addition of the investment relation and reoptimization
            capacity_ratio = 2
            ratio = 1 / (capacity_ratio + 1)
            couple_capacity(m, (n_1, :cap), (n_2, :cap), 𝒯; capacity_ratio)
            optimize!(m)
            var_cur = value.(m[:cap_current])
            var_rem = value.(m[:cap_rem])

            # Test that with limits, the capacities are linked through the parameter
            # `capacity_ratio`
            @test all(
                var_cur[n_1, t_inv] ≈ demand[t_inv] * ratio * capacity_ratio
            for t_inv ∈ 𝒯ᴵⁿᵛ)
            @test all(var_cur[n_2, t_inv] ≈ demand[t_inv] * ratio for t_inv ∈ 𝒯ᴵⁿᵛ)
            @test all(
                var_cur[n_1, t_inv] ≈ var_cur[n_2, t_inv] * capacity_ratio
            for t_inv ∈ 𝒯ᴵⁿᵛ)

            # The removal is based on the semi continuous investments in periods 1 and 2 to
            # avoid overinvestments in periods 2 and 3 (prof_rem_2) and based on the ratio
            # in period 3
            prof_rem_1 = StrategicProfile([0, 0, 10 * ratio * capacity_ratio, 0])
            prof_rem_2 = StrategicProfile([5 * ratio, 5 * ratio, 10 * ratio, 0])
            @test all(var_rem[n_1, t_inv] ≈ prof_rem_1[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
            @test all(var_rem[n_2, t_inv] ≈ prof_rem_2[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
        end
    end

    @testset "`precede_capacity`" begin
        @testset "No keyword argument used" begin
            # Creation of the model
            fixed_opex = [FixedProfile(1), FixedProfile(1.1), FixedProfile(100)]
            m, para = simple_model(; demand, inv_data, fixed_opex, num_invest = 3)

            # Extraction of required data
            n_1, n_2, n_3 = para[:nodes]
            𝒯 = para[:T]
            𝒯ᴵⁿᵛ = strat_periods(𝒯)

            # Addition of the investment relation and reoptimization
            elements_dep = [(n_1, :cap), (n_2, :cap)]
            element_pre = (n_3, :cap)
            precede_capacity(m, elements_dep, element_pre, 𝒯)
            optimize!(m)
            var_cur = value.(m[:cap_current])
            var_add = value.(m[:cap_add])

            # Test that with limits, it must invest in node 3 in the first period to avoid a
            # deficit as it is a prerequisite while subsequent investments are in nodes 1 and 2
            prof_cur_1 = StrategicProfile([0, 50/3, 50/3, 40/3])
            prof_cur_2 = StrategicProfile([0, 20/3, 50/3, 40/3])
            prof_cur_3 = StrategicProfile([30, 50/3, 50/3, 40/3])
            @test all(var_cur[n_1, t_inv] ≈ prof_cur_1[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
            @test all(var_cur[n_2, t_inv] ≈ prof_cur_2[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
            @test all(var_cur[n_3, t_inv] ≈ prof_cur_3[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
            @test all(
                var_cur[n_1, t_inv] ≲ var_cur[n_3, t_inv] - var_add[n_3, t_inv]
            for t_inv ∈ 𝒯ᴵⁿᵛ)
            @test all(
                var_cur[n_2, t_inv] ≲ var_cur[n_3, t_inv] - var_add[n_3, t_inv]
            for t_inv ∈ 𝒯ᴵⁿᵛ)
        end

        @testset "Keyword argument used" begin
            # Creation of the model
            demand = StrategicProfile([10, 30, 50, 40])
            fixed_opex = [FixedProfile(1), FixedProfile(100)]
            m, para = simple_model(; demand, inv_data, fixed_opex, num_invest = 2)

            # Extraction of required data
            n_1, n_2 = para[:nodes]
            𝒯 = para[:T]
            𝒯ᴵⁿᵛ = strat_periods(𝒯)

            # Addition of the investment relation and reoptimization
            capacity_ratio = 2
            ratio = 1 / (capacity_ratio + 1)
            elements_dep = [(n_1, :cap)]
            element_pre = (n_2, :cap)
            precede_capacity(m, elements_dep, element_pre, 𝒯; capacity_ratio)
            optimize!(m)
            var_cur = value.(m[:cap_current])
            var_add = value.(m[:cap_add])

            # Test that with limits, it must invest in node 2 in the first period to avoid a
            # deficit. The investment in node 2 in period 2 is a prequisite for the
            # investments in node 1 in period 3
            prof_cur_1 = StrategicProfile([0, 20, 50, 40]) * ratio * capacity_ratio
            prof_cur_2 = StrategicProfile([10, 50 * ratio, 50 * ratio, 40 * ratio])
            @test all(var_cur[n_1, t_inv] ≈ prof_cur_1[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
            @test all(var_cur[n_2, t_inv] ≈ prof_cur_2[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
            @test all(
                var_cur[n_1, t_inv] ≲
                    (var_cur[n_2, t_inv] - var_add[n_2, t_inv]) * capacity_ratio
            for t_inv ∈ 𝒯ᴵⁿᵛ)
        end
    end

    @testset "`retire_capacity`" begin
        # Creation and solving of the model
        fixed_opex = FixedProfile(-10)
        demand = FixedProfile(40)
        m, para = simple_model(; demand, inv_data, fixed_opex, num_invest = 3)

        # Extraction of required data
        n_1, n_2, n_3 = para[:nodes]
        𝒯 = para[:T]
        𝒯ᴵⁿᵛ = strat_periods(𝒯)

        # Add constraints for usage
        prof_min = StrategicProfile([30, 0, 0, 0])
        @constraint(m, [t ∈ 𝒯], m[:cap_use][n_3, t] ≥ prof_min[t])
        prof_max = StrategicProfile([50, 50, 50, 0])
        @constraint(m, [t ∈ 𝒯], m[:cap_use][n_3, t] ≤ prof_max[t])
        optimize!(m)

        # Variable reassignment
        var_add = value.(m[:cap_add])
        var_rem = value.(m[:cap_rem])

        # Test that the maximum investments is happening in the first period for both nodes
        # and no retirement of nodes 1 and 2 due to the negative fixed OPEX
        prof_add = StrategicProfile([30, 30, 0, 0])
        prof_rem = FixedProfile(0)
        @test all(var_add[n, t_inv] ≈ prof_add[t_inv] for n ∈ para[:nodes], t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(var_rem[n, t_inv] ≈ prof_rem[t_inv] for n ∈ para[:nodes], t_inv ∈ 𝒯ᴵⁿᵛ)

        # Test that the number of variables
        n_var = 192
        @test num_variables(m) == n_var

        # Add exlusivity constraints
        elements_dep = [(n_1, :cap, inv_data), (n_2, :cap, inv_data)]
        element_pre = (n_3, :cap, inv_data)
        retire_capacity(m, elements_dep, element_pre, 𝒯)
        optimize!(m)
        var_add = value.(m[:cap_add])
        var_rem = value.(m[:cap_rem])

        # Test that the number of variables is increased by 4
        @test num_variables(m) == n_var + 4

        # Test that the 2 investments are mutually exlusive and node 1 is removed at the end
        # of period 1 to be able to invest in node 2 and 3 in period 2 to maximize the
        # profit from the the negative fixed OPEX
        prof_add_12 = StrategicProfile([0, 30, 30, 0])
        prof_add_rem_3 = StrategicProfile([30, 0, 0, 0])
        @test all(var_add[n, t_inv] ≈ prof_add_12[t_inv] for n ∈ [n_1, n_2], t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(var_rem[n, t_inv] ≈ prof_rem[t_inv] for n ∈ [n_1, n_2], t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(var_add[n_3, t_inv] ≈ prof_add_rem_3[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(var_rem[n_3, t_inv] ≈ prof_add_rem_3[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

        # Test that there is an argument error with a specified initial capacity
        inv_data = StartInvData(
            FixedProfile(100),
            FixedProfile(60),
            FixedProfile(10),
            SemiContinuousInvestment(FixedProfile(5), FixedProfile(30)),
        )
        m, para = simple_model(; demand, inv_data, fixed_opex, num_invest = 3)
        n_1, n_2, n_3 = para[:nodes]
        elements_dep = [(n_1, :cap, inv_data), (n_2, :cap, inv_data)]
        element_pre = (n_3, :cap, inv_data)
        @test_throws ArgumentError retire_capacity(m, elements_dep, element_pre, 𝒯)
    end
end

@testset "`require_investment`, `couple_investment`, and `exclude_investment`" begin
    # Investment data with positive costs and semi continuous investment decisions
    # The semi continuous investment can lead to early capacity retirement
    inv_data = NoStartInvData(
        FixedProfile(100),
        FixedProfile(60),
        SemiContinuousInvestment(FixedProfile(5), FixedProfile(30)),
    )
    demand = StrategicProfile([30, 40, 50, 40])
    fixed_opex = [
        StrategicProfile([1, 1.1, 1.1, 1]),
        StrategicProfile([1.05, 1, 1.1, 1.05]),
        StrategicProfile([1.1, 1.1, 1, 1.1]),
    ]

    @testset "No constraints added" begin
        # Creation of the model
        m, para = simple_model(; demand, inv_data, fixed_opex, num_invest = 3)

        # Extraction of required data
        n_1, n_2, n_3 = para[:nodes]
        𝒯 = para[:T]
        𝒯ᴵⁿᵛ = strat_periods(𝒯)

        # Variable reassignment
        var_cur = value.(m[:cap_current])

        # Test that without any constraints, it invests according to the demand in node 1 in
        # period 1, node 2 in period 2, and node 3 in period 3 to satisfy the demand.
        # Node 3 is removed as it is no longer needed in period 4
        prof_cur_1 = StrategicProfile([30, 30, 30, 30])
        prof_cur_2 = StrategicProfile([0, 10, 10, 10])
        prof_cur_3 = StrategicProfile([0, 0, 10, 0])
        @test all(var_cur[n_1, t_inv] ≈ prof_cur_1[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(var_cur[n_2, t_inv] ≈ prof_cur_2[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(var_cur[n_3, t_inv] ≈ prof_cur_3[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
    end

    @testset "`require_investment`" begin
        # Creation of the model
        m, para = simple_model(; demand, inv_data, fixed_opex, num_invest = 3)

        # Extraction of required data
        n_1, n_2, n_3 = para[:nodes]
        𝒯 = para[:T]
        𝒯ᴵⁿᵛ = strat_periods(𝒯)

        # Addition of the investment relation and reoptimization
        elements_dep = [(n_1, :cap), (n_2, :cap)]
        element_pre = (n_3, :cap)
        require_investment(m, elements_dep, element_pre, 𝒯)
        optimize!(m)
        var_add = value.(m[:cap_add])

        # Test that with limits, it invests in node 3 in periods 1 and 2 as prerequisite but
        # in period 3 due to the lower OPEX without investing in node 1 or node 2
        prof_add_1 = StrategicProfile([25, 0, 0, 0])
        prof_add_2 = StrategicProfile([0, 5, 0, 0])
        prof_add_3 = StrategicProfile([5, 5, 10, 0])
        @test all(var_add[n_1, t_inv] ≈ prof_add_1[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(var_add[n_2, t_inv] ≈ prof_add_2[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(var_add[n_3, t_inv] ≈ prof_add_3[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

        # Test that the activation is following the profile and is equal
        prof_act_1 = StrategicProfile([1, 0, 0, 0])
        prof_act_2 = StrategicProfile([0, 1, 0, 0])
        prof_act_3 = StrategicProfile([1, 1, 1, 0])
        @test all(value.(m[:cap_invest_b][n_1, t_inv]) ≈ prof_act_1[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(value.(m[:cap_invest_b][n_2, t_inv]) ≈ prof_act_2[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(value.(m[:cap_invest_b][n_3, t_inv]) ≈ prof_act_3[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
    end

    @testset "`couple_investment`" begin
        # Creation of the model
        fixed_opex = [
            StrategicProfile([1, 1, 1.1, 1]),
            StrategicProfile([1.1, 1.1, 1, 1.1]),
        ]
        m, para = simple_model(; demand, inv_data, fixed_opex, num_invest = 2)

        # Extraction of required data
        n_1, n_2 = para[:nodes]
        𝒯 = para[:T]
        𝒯ᴵⁿᵛ = strat_periods(𝒯)

        # Addition of the investment relation and reoptimization
        elements = [(n_1, :cap), (n_2, :cap)]
        couple_investment(m, elements, 𝒯)
        optimize!(m)
        var_add = value.(m[:cap_add])

        # Test that with limits, it invests in node 2 in all periods when it invests in node
        # 1 given the minimum investment.
        prof_add_1 = StrategicProfile([25, 5, 5, 0])
        prof_add_2 = StrategicProfile([5, 5, 5, 0])
        @test all(var_add[n_1, t_inv] ≈ prof_add_1[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(var_add[n_2, t_inv] ≈ prof_add_2[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)

        # Test that the activation is following the profile and is equal
        prof_act = StrategicProfile([1, 1, 1, 0])
        @test all(value.(m[:cap_invest_b][n_1, t_inv]) ≈ prof_act[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(value.(m[:cap_invest_b][n_2, t_inv]) ≈ prof_act[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
    end

    @testset "`exclude_investment`" begin
        # Creation of the model
        inv_data = NoStartInvData(
            FixedProfile(100),
            FixedProfile(60),
            SemiContinuousInvestment(FixedProfile(5), FixedProfile(25)),
        )
        fixed_opex = [
            StrategicProfile([1, 1, 1.1, 1]),
            StrategicProfile([1.1, 1.1, 1, 1.1]),
        ]
        m, para = simple_model(; demand, inv_data, fixed_opex, num_invest = 2)

        # Extraction of required data
        n_1, n_2 = para[:nodes]
        𝒯 = para[:T]
        𝒯ᴵⁿᵛ = strat_periods(𝒯)

        # Addition of the investment relation and reoptimization
        elements = [(n_1, :cap), (n_2, :cap)]
        exclude_investment(m, elements, 𝒯)
        optimize!(m)
        var_add = value.(m[:cap_add])

        # Test that with limits, it cannot satisfy the demand in period 1 due to the max
        # capacity addition
        prof_add_1 = StrategicProfile([25, 15, 0, 0])
        prof_add_2 = StrategicProfile([0, 0, 10, 0])
        prof_def = StrategicProfile([5, 0, 0, 0])
        @test all(var_add[n_1, t_inv] ≈ prof_add_1[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(var_add[n_2, t_inv] ≈ prof_add_2[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(value.(m[:deficit][t]) ≈ prof_def[t] for t ∈ 𝒯)

        # Test that the activation is following the profile and is exclusive
        prof_act_1 = StrategicProfile([1, 1, 0, 0])
        prof_act_2 = StrategicProfile([0, 0, 1, 0])
        @test all(value.(m[:cap_invest_b][n_1, t_inv]) ≈ prof_act_1[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(value.(m[:cap_invest_b][n_2, t_inv]) ≈ prof_act_2[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ)
        @test all(
            sum(value.(m[:cap_invest_b][n, t_inv]) for n ∈ [n_1, n_2]) ≤ 1
        for t_inv ∈ 𝒯ᴵⁿᵛ)
    end

    @testset "Binary relations - no binary investment variables" begin
        # Continuous investments do not create binary investment variables
        inv_data = NoStartInvData(
            FixedProfile(100),
            FixedProfile(60),
            ContinuousInvestment(FixedProfile(0), FixedProfile(30)),
        )
        m, para = simple_model(;inv_data, num_invest = 2)
        n_1, n_2 = para[:nodes]
        𝒯 = para[:T]
        investments = [(node, :cap) for node ∈ para[:nodes]]

        @test_throws ArgumentError require_investment(m, [(n_1, :cap)], (n_2, :cap), 𝒯)
        @test_throws ArgumentError exclude_investment(m, [(n_1, :cap), (n_2, :cap)], 𝒯)
        @test_throws ArgumentError couple_investment(m, [(n_1, :cap), (n_2, :cap)], 𝒯)

        # Models without investment data also lack binary investment variables
        m, para = simple_model(; num_invest = 2)
        n_1, n_2 = para[:nodes]
        investments = [(node, :cap) for node ∈ para[:nodes]]

        @test_throws ArgumentError require_investment(m, [(n_1, :cap)], (n_2, :cap), 𝒯)
        @test_throws ArgumentError exclude_investment(m, [(n_1, :cap), (n_2, :cap)], 𝒯)
        @test_throws ArgumentError couple_investment(m, [(n_1, :cap), (n_2, :cap)], 𝒯)
    end
end
