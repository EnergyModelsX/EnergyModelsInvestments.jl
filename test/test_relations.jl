@testset "Max budget" begin
    # Investment data with positive costs and continuous capacity additions
    inv_data = NoStartInvData(
        FixedProfile(1),
        FixedProfile(1000),
        ContinuousInvestment(FixedProfile(0), FixedProfile(1000)),
    )

    # A budget below the combined CAPEX is infeasible
    @testset "Insufficient budget" begin
        # Creation of the model with positive investment costs and no demand
        m, para = simple_model(;
            ts = TwoLevel(2, 1, SimpleTimes(1, 1)),
            demand = FixedProfile(0),
            inv_data,
            two_investments = true,
        )

        # Extraction of required data and addition of the investment relation
        nodes = para[:nodes]
        𝒯 = para[:T]
        𝒯ᴵⁿᵛ = strat_periods(𝒯)
        investments = [(:cap, node) for node in nodes]
        max_budget(m, 150, investments, 𝒯)
        for node ∈ nodes
            fix(m[:cap_capex][node, first(𝒯ᴵⁿᵛ)], 100; force = true)
        end
        optimize!(m)

        @test termination_status(m) == JuMP.MOI.INFEASIBLE
    end

    # A budget covering the combined CAPEX is feasible
    @testset "Sufficient budget" begin
        # Creation of the model with positive investment costs and no demand
        m, para = simple_model(;
            ts = TwoLevel(2, 1, SimpleTimes(1, 1)),
            demand = FixedProfile(0),
            inv_data,
            two_investments = true,
        )

        # Extraction of required data and addition of the investment relation
        nodes = para[:nodes]
        𝒯 = para[:T]
        𝒯ᴵⁿᵛ = strat_periods(𝒯)
        investments = [(:cap, node) for node in nodes]
        max_budget(m, 250, investments, 𝒯)
        for node ∈ nodes
            fix(m[:cap_capex][node, first(𝒯ᴵⁿᵛ)], 100; force = true)
        end
        optimize!(m)

        @test termination_status(m) == JuMP.MOI.OPTIMAL
    end

    # CAPEX outside the selected strategic periods must not consume the budget
    @testset "Selected periods" begin
        # Creation of the model with positive investment costs and no demand
        m, para = simple_model(;
            ts = TwoLevel(2, 1, SimpleTimes(1, 1)),
            demand = FixedProfile(0),
            inv_data,
            two_investments = true,
        )

        # Extraction of required data and addition of the investment relation
        nodes = para[:nodes]
        𝒯 = para[:T]
        𝒯ᴵⁿᵛ = strat_periods(𝒯)
        investments = [(:cap, node) for node in nodes]
        max_budget(m, 200, investments, 𝒯; sps_spec = [first(𝒯ᴵⁿᵛ)])
        for node ∈ nodes, t_inv ∈ 𝒯ᴵⁿᵛ
            fix(m[:cap_capex][node, t_inv], 100; force = true)
        end
        optimize!(m)

        @test termination_status(m) == JuMP.MOI.OPTIMAL
    end
end

@testset "Investment count limits" begin
    # Investment data with positive costs and binary investment decisions
    inv_data = NoStartInvData(
        FixedProfile(1),
        FixedProfile(1000),
        BinaryInvestment(FixedProfile(1)),
    )

    # A maximum count below the number of active investments is infeasible
    @testset "Insufficient maximum count" begin
        # Creation of the model with positive investment costs and no demand
        m, para = simple_model(;
            ts = TwoLevel(2, 1, SimpleTimes(1, 1)),
            demand = FixedProfile(0),
            inv_data,
            two_investments = true,
        )

        # Extraction of required data and addition of the investment relation
        nodes = para[:nodes]
        𝒯 = para[:T]
        𝒯ᴵⁿᵛ = strat_periods(𝒯)
        investments = [(:cap, node) for node in nodes]
        max_investments(m, 1, investments, 𝒯)
        for node ∈ nodes
            fix(m[:cap_invest_b][node, first(𝒯ᴵⁿᵛ)], 1; force = true)
        end
        optimize!(m)

        @test termination_status(m) == JuMP.MOI.INFEASIBLE
    end

    # A maximum count covering all active investments is feasible
    @testset "Sufficient maximum count" begin
        # Creation of the model with positive investment costs and no demand
        m, para = simple_model(;
            ts = TwoLevel(2, 1, SimpleTimes(1, 1)),
            demand = FixedProfile(0),
            inv_data,
            two_investments = true,
        )

        # Extraction of required data and addition of the investment relation
        nodes = para[:nodes]
        𝒯 = para[:T]
        𝒯ᴵⁿᵛ = strat_periods(𝒯)
        investments = [(:cap, node) for node in nodes]
        max_investments(m, 2, investments, 𝒯)
        for node ∈ nodes
            fix(m[:cap_invest_b][node, first(𝒯ᴵⁿᵛ)], 1; force = true)
        end
        optimize!(m)

        @test termination_status(m) == JuMP.MOI.OPTIMAL
    end

    # A minimum count above the number of active investments is infeasible
    @testset "Insufficient minimum count" begin
        # Creation of the model with positive investment costs and no demand
        m, para = simple_model(;
            ts = TwoLevel(2, 1, SimpleTimes(1, 1)),
            demand = FixedProfile(0),
            inv_data,
            two_investments = true,
        )

        # Extraction of required data and addition of the investment relation
        nodes = para[:nodes]
        𝒯 = para[:T]
        𝒯ᴵⁿᵛ = strat_periods(𝒯)
        investments = [(:cap, node) for node in nodes]
        min_investments(m, 2, investments, 𝒯; sps_spec = [first(𝒯ᴵⁿᵛ)])
        for node ∈ nodes
            fix(m[:cap_invest_b][node, first(𝒯ᴵⁿᵛ)], 0; force = true)
        end
        optimize!(m)

        @test termination_status(m) == JuMP.MOI.INFEASIBLE
    end

    # A minimum count met by one active investment is feasible
    @testset "Sufficient minimum count" begin
        # Creation of the model with positive investment costs and no demand
        m, para = simple_model(;
            ts = TwoLevel(2, 1, SimpleTimes(1, 1)),
            demand = FixedProfile(0),
            inv_data,
            two_investments = true,
        )

        # Extraction of required data and addition of the investment relation
        nodes = para[:nodes]
        𝒯 = para[:T]
        𝒯ᴵⁿᵛ = strat_periods(𝒯)
        investments = [(:cap, node) for node in nodes]
        min_investments(m, 1, investments, 𝒯; sps_spec = [first(𝒯ᴵⁿᵛ)])
        fix(m[:cap_invest_b][nodes[1], first(𝒯ᴵⁿᵛ)], 1; force = true)
        fix(m[:cap_invest_b][nodes[2], first(𝒯ᴵⁿᵛ)], 0; force = true)
        optimize!(m)

        @test termination_status(m) == JuMP.MOI.OPTIMAL
    end
end

@testset "Requires capacity - ratio $capacity_ratio" for capacity_ratio ∈ [1, 2]
    # Creation of the model with positive investment costs and no demand
    m, para = simple_model(; demand = FixedProfile(0), two_investments = true)

    # Extraction of required data and addition of the investment relation
    nodes = para[:nodes]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    capacity = StrategicProfile([0, 2, 4, 6])
    requires_capacity(m, :cap, nodes[1], :cap, nodes[2], 𝒯; capacity_ratio)

    # Dependent capacity must be supported by prerequisite capacity in each period
    @testset "Dependent capacity" begin
        for t_inv ∈ 𝒯ᴵⁿᵛ
            fix(m[:cap_current][nodes[1], t_inv], capacity[t_inv]; force = true)
        end
        optimize!(m)

        @test termination_status(m) == JuMP.MOI.OPTIMAL
        @test sum(
            value(m[:cap_current][nodes[1], t_inv]) ≲
            capacity_ratio * value(m[:cap_current][nodes[2], t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ
        ) == length(𝒯ᴵⁿᵛ)
        @test matches_profile(
            m[:cap_current],
            nodes[2],
            capacity * (1 / capacity_ratio),
            𝒯ᴵⁿᵛ,
        )
    end

    # Prerequisite capacity alone must not force dependent capacity
    @testset "Prerequisite capacity" begin
        for t_inv ∈ 𝒯ᴵⁿᵛ
            unfix(m[:cap_current][nodes[1], t_inv])
            fix(m[:cap_current][nodes[2], t_inv], capacity[t_inv]; force = true)
        end
        optimize!(m)

        @test termination_status(m) == JuMP.MOI.OPTIMAL
        @test matches_profile(m[:cap_current], nodes[1], FixedProfile(0), 𝒯ᴵⁿᵛ)
    end

    # Dependent capacity without supporting prerequisite capacity is infeasible
    @testset "Unsupported capacity" begin
        fix(m[:cap_current][nodes[1], first(𝒯ᴵⁿᵛ)], 1; force = true)
        optimize!(m)

        @test termination_status(m) == JuMP.MOI.INFEASIBLE
    end
end

@testset "Couple capacity - ratio $capacity_ratio" for capacity_ratio ∈ [1, 2]
    # Creation of the model with positive investment costs and no demand
    m, para = simple_model(; demand = FixedProfile(0), two_investments = true)

    # Extraction of required data and addition of the investment relation
    nodes = para[:nodes]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    capacity = StrategicProfile([0, 2, 4, 6])
    couple_capacity(m, :cap, nodes[1], :cap, nodes[2], 𝒯; capacity_ratio)

    # Either element must establish the corresponding capacity of its partner
    @testset "Capacity by element $node" for node ∈ nodes
        for element ∈ nodes, t_inv ∈ 𝒯ᴵⁿᵛ
            is_fixed(m[:cap_current][element, t_inv]) &&
                unfix(m[:cap_current][element, t_inv])
        end
        for t_inv ∈ 𝒯ᴵⁿᵛ
            fix(m[:cap_current][node, t_inv], capacity[t_inv]; force = true)
        end
        optimize!(m)

        @test termination_status(m) == JuMP.MOI.OPTIMAL
        @test sum(
            isapprox(
                value(m[:cap_current][nodes[1], t_inv]),
                capacity_ratio * value(m[:cap_current][nodes[2], t_inv]);
                atol = TEST_ATOL,
            ) for t_inv ∈ 𝒯ᴵⁿᵛ
        ) == length(𝒯ᴵⁿᵛ)
        @test matches_profile(m[:cap_current], node, capacity, 𝒯ᴵⁿᵛ)
    end

    # Capacities that violate the coupling ratio are infeasible
    @testset "Mismatched capacity" begin
        fix(m[:cap_current][nodes[1], first(𝒯ᴵⁿᵛ)], 1; force = true)
        optimize!(m)

        @test termination_status(m) == JuMP.MOI.INFEASIBLE
    end
end

@testset "Precede capacity - ratio $capacity_ratio" for capacity_ratio ∈ [1, 2]
    # Creation of the model with positive investment costs and no demand
    m, para = simple_model(; demand = FixedProfile(0), two_investments = true)

    # Extraction of required data and addition of the investment relation
    nodes = para[:nodes]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    capacity = StrategicProfile([0, 2, 4, 6])
    prerequisite = StrategicProfile([2, 4, 6, 6])
    precede_capacity(m, :cap, nodes[1], :cap, nodes[2], 𝒯; capacity_ratio)

    # Without initial capacity, dependent capacity cannot exist in the first period
    @testset "First-period capacity" begin
        fix(m[:cap_current][nodes[1], first(𝒯ᴵⁿᵛ)], 1; force = true)
        optimize!(m)

        @test termination_status(m) == JuMP.MOI.INFEASIBLE
    end

    # Earlier prerequisite additions must support dependent capacity in later periods
    @testset "Earlier prerequisite capacity" begin
        for t_inv ∈ 𝒯ᴵⁿᵛ
            fix(m[:cap_current][nodes[1], t_inv], capacity[t_inv]; force = true)
            fix(
                m[:cap_current][nodes[2], t_inv],
                prerequisite[t_inv] / capacity_ratio;
                force = true,
            )
        end
        optimize!(m)

        @test termination_status(m) == JuMP.MOI.OPTIMAL
        @test sum(
            value(m[:cap_current][nodes[1], t_inv]) ≲
            capacity_ratio *
            (value(m[:cap_current][nodes[2], t_inv]) - value(m[:cap_add][nodes[2], t_inv]))
            for t_inv ∈ 𝒯ᴵⁿᵛ
        ) == length(𝒯ᴵⁿᵛ)
        @test matches_profile(m[:cap_current], nodes[1], capacity, 𝒯ᴵⁿᵛ)
    end

    # Prerequisite additions in the same period cannot support dependent capacity
    @testset "Same-period prerequisite capacity" begin
        for t_inv ∈ 𝒯ᴵⁿᵛ
            fix(
                m[:cap_current][nodes[2], t_inv],
                capacity[t_inv] / capacity_ratio;
                force = true,
            )
        end
        optimize!(m)

        @test termination_status(m) == JuMP.MOI.INFEASIBLE
    end
end

@testset "Capacity retention - $relation" for relation ∈ [
    requires_capacity,
    precede_capacity,
    couple_capacity,
]
    # Creation of the model with early retirement and an incentive to avoid fixed OPEX
    inv_data = NoStartInvData(
        FixedProfile(1000),
        FixedProfile(30),
        ContinuousInvestment(FixedProfile(0), FixedProfile(10)),
        StudyLife(FixedProfile(40)),
    )
    m, para = simple_model(;
        demand = FixedProfile(0),
        fixed_opex = FixedProfile(10),
        inv_data,
        two_investments = true,
    )

    # Extraction of required data and prevention of replacement investments
    nodes = para[:nodes]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    prerequisite_add = StrategicProfile([1, 0, 0, 0])
    # Coupled capacities must be present together from the first investment period
    if relation == couple_capacity
        dependent_add = StrategicProfile([1, 0, 0, 0])
        dependent_capacity = StrategicProfile([1, 1, 1, 0])
    else
        dependent_add = StrategicProfile([0, 1, 0, 0])
        dependent_capacity = StrategicProfile([0, 1, 1, 0])
    end
    for t_inv ∈ 𝒯ᴵⁿᵛ
        fix(m[:cap_add][nodes[2], t_inv], prerequisite_add[t_inv]; force = true)
        fix(m[:cap_add][nodes[1], t_inv], dependent_add[t_inv]; force = true)
        fix(m[:cap_current][nodes[1], t_inv], dependent_capacity[t_inv]; force = true)
    end
    optimize!(m)
    objective_without_relation = objective_value(m)

    # Without a relation, the prerequisite retires immediately to avoid fixed OPEX
    @testset "Retirement without relation" begin
        @test termination_status(m) == JuMP.MOI.OPTIMAL
        @test matches_profile(m[:cap_current], nodes[2], prerequisite_add, 𝒯ᴵⁿᵛ)
        @test isapprox(value(m[:cap_rem][nodes[2], 𝒯ᴵⁿᵛ[1]]), 1; atol = TEST_ATOL)
    end

    # The relation retains prerequisite capacity despite the additional fixed OPEX
    @testset "Retention while required" begin
        relation(m, :cap, nodes[1], :cap, nodes[2], 𝒯)
        optimize!(m)
        prerequisite_capacity = StrategicProfile([1, 1, 1, 0])
        prerequisite_removal = StrategicProfile([0, 0, 1, 0])

        @test termination_status(m) == JuMP.MOI.OPTIMAL
        @test matches_profile(m[:cap_current], nodes[2], prerequisite_capacity, 𝒯ᴵⁿᵛ)
        @test matches_profile(m[:cap_rem], nodes[2], prerequisite_removal, 𝒯ᴵⁿᵛ)
        @test objective_value(m) < objective_without_relation - TEST_ATOL
    end
end

@testset "Excludes capacity" begin
    # Creation of the model with positive investment costs and no demand
    inv_data = NoStartInvData(
        FixedProfile(1),
        FixedProfile(1000),
        SemiContinuousInvestment(FixedProfile(1), FixedProfile(10)),
    )
    m, para = simple_model(; demand = FixedProfile(0), inv_data, two_investments = true)

    # Extraction of required data and addition of the investment relation
    nodes = para[:nodes]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    activation = StrategicProfile([0, 1, 0, 1])
    excludes_capacity(m, :cap, nodes[1], :cap, nodes[2], 𝒯)

    # Either element can activate, but its partner must remain inactive
    @testset "Activation by element $node" for node ∈ nodes
        for element ∈ nodes, t_inv ∈ 𝒯ᴵⁿᵛ
            is_fixed(m[:cap_invest_b][element, t_inv]) &&
                unfix(m[:cap_invest_b][element, t_inv])
        end
        for t_inv ∈ 𝒯ᴵⁿᵛ
            fix(m[:cap_invest_b][node, t_inv], activation[t_inv]; force = true)
        end
        optimize!(m)

        @test termination_status(m) == JuMP.MOI.OPTIMAL
        @test matches_profile(m[:cap_invest_b], node, activation, 𝒯ᴵⁿᵛ)
        @test all(
            matches_profile(m[:cap_invest_b], element, FixedProfile(0), 𝒯ᴵⁿᵛ) for
            element ∈ setdiff(nodes, [node])
        )
    end
end

@testset "Require investment" begin
    # Creation of the model with positive investment costs and no demand
    inv_data = NoStartInvData(
        FixedProfile(1),
        FixedProfile(1000),
        SemiContinuousInvestment(FixedProfile(1), FixedProfile(10)),
    )
    m, para = simple_model(; demand = FixedProfile(0), inv_data, two_investments = true)

    # Extraction of required data and addition of the investment relation
    nodes = para[:nodes]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    activation = StrategicProfile([0, 1, 0, 1])
    require_investment(m, :cap, nodes[1], :cap, nodes[2], 𝒯)

    # Dependent investments must activate the prerequisite in the same periods
    @testset "Dependent activation" begin
        for t_inv ∈ 𝒯ᴵⁿᵛ
            fix(m[:cap_invest_b][nodes[1], t_inv], activation[t_inv]; force = true)
        end
        optimize!(m)

        @test termination_status(m) == JuMP.MOI.OPTIMAL
        @test sum(
            value(m[:cap_invest_b][nodes[1], t_inv]) ≲
            value(m[:cap_invest_b][nodes[2], t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ
        ) == length(𝒯ᴵⁿᵛ)
        @test matches_profile(m[:cap_invest_b], nodes[2], activation, 𝒯ᴵⁿᵛ)
    end

    # Prerequisite investments alone must not force dependent investments
    @testset "Prerequisite activation" begin
        for t_inv ∈ 𝒯ᴵⁿᵛ
            unfix(m[:cap_invest_b][nodes[1], t_inv])
            fix(m[:cap_invest_b][nodes[2], t_inv], activation[t_inv]; force = true)
        end
        optimize!(m)

        @test termination_status(m) == JuMP.MOI.OPTIMAL
        @test matches_profile(m[:cap_invest_b], nodes[1], FixedProfile(0), 𝒯ᴵⁿᵛ)
    end
end

@testset "Couple investment" begin
    # Creation of the model with positive investment costs and no demand
    inv_data = NoStartInvData(
        FixedProfile(1),
        FixedProfile(1000),
        SemiContinuousInvestment(FixedProfile(1), FixedProfile(10)),
    )
    m, para = simple_model(; demand = FixedProfile(0), inv_data, two_investments = true)

    # Extraction of required data and addition of the investment relation
    nodes = para[:nodes]
    𝒯 = para[:T]
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    activation = StrategicProfile([0, 1, 0, 1])
    couple_investment(m, :cap, nodes[1], :cap, nodes[2], 𝒯)

    # Either element must activate its partner, and both remain inactive in other periods
    @testset "Activation by element $node" for node ∈ nodes
        for element ∈ nodes, t_inv ∈ 𝒯ᴵⁿᵛ
            is_fixed(m[:cap_invest_b][element, t_inv]) &&
                unfix(m[:cap_invest_b][element, t_inv])
        end
        for t_inv ∈ 𝒯ᴵⁿᵛ
            fix(m[:cap_invest_b][node, t_inv], activation[t_inv]; force = true)
        end
        optimize!(m)

        @test termination_status(m) == JuMP.MOI.OPTIMAL
        @test sum(
            value(m[:cap_invest_b][nodes[1], t_inv]) ≈
            value(m[:cap_invest_b][nodes[2], t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ
        ) == length(𝒯ᴵⁿᵛ)
        @test all(
            matches_profile(m[:cap_invest_b], element, activation, 𝒯ᴵⁿᵛ) for element ∈ nodes
        )
    end
end


@testset "Binary relations - no binary investment variables" begin
    periods = TwoLevel(2, 1, SimpleTimes(1, 1))

    # Discrete investments do not create binary investment variables
    inv_data = NoStartInvData(
        FixedProfile(1),
        FixedProfile(1000),
        DiscreteInvestment(FixedProfile(1)),
    )
    integer_model, para = simple_model(;
        ts = periods,
        demand = FixedProfile(0),
        inv_data,
        two_investments = true,
    )
    nodes = para[:nodes]
    investments = [(:cap, node) for node in nodes]

    # Binary relations require binary investment variables for both elements
    @test_throws ArgumentError excludes_capacity(
        integer_model,
        :cap,
        nodes[1],
        :cap,
        nodes[2],
        periods,
    )
    @test_throws ArgumentError require_investment(
        integer_model,
        :cap,
        nodes[1],
        :cap,
        nodes[2],
        periods,
    )
    @test_throws ArgumentError couple_investment(
        integer_model,
        :cap,
        nodes[1],
        :cap,
        nodes[2],
        periods,
    )
    @test_throws ArgumentError max_investments(integer_model, 1, investments, periods)
    @test_throws ArgumentError min_investments(integer_model, 1, investments, periods)

    # Models without investment data also lack binary investment variables
    missing_model, para =
        simple_model(; ts = periods, demand = FixedProfile(0), two_investments = true)
    nodes = para[:nodes]
    investments = [(:cap, node) for node in nodes]

    # Every binary relation must reject models without binary investment variables
    @test_throws ArgumentError excludes_capacity(
        missing_model,
        :cap,
        nodes[1],
        :cap,
        nodes[2],
        periods,
    )
    @test_throws ArgumentError require_investment(
        missing_model,
        :cap,
        nodes[1],
        :cap,
        nodes[2],
        periods,
    )
    @test_throws ArgumentError couple_investment(
        missing_model,
        :cap,
        nodes[1],
        :cap,
        nodes[2],
        periods,
    )
    @test_throws ArgumentError max_investments(missing_model, 1, investments, periods)
    @test_throws ArgumentError min_investments(missing_model, 1, investments, periods)
end
