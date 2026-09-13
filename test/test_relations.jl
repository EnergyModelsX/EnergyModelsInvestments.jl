@testset "Max budget" begin
    periods = TwoLevel(2, 1, SimpleTimes(1, 1))
    strategic = collect(strat_periods(periods))

    function budget_status(limit)
        inv_data = NoStartInvData(
            FixedProfile(1),
            FixedProfile(1000),
            ContinuousInvestment(FixedProfile(0), FixedProfile(1000)),
        )
        model, para = simple_model(;
            ts = periods,
            demand = FixedProfile(0),
            inv_data,
            two_investments = true,
        )
        nodes = para[:nodes]
        @constraint(model, model[:cap_capex][nodes[1], strategic[1]] == 100)
        @constraint(model, model[:cap_capex][nodes[2], strategic[1]] == 100)
        investments = [(:cap, node) for node in nodes]
        max_budget(model, limit, investments, periods)
        optimize!(model)
        termination_status(model)
    end

    @test budget_status(150) == JuMP.MOI.INFEASIBLE
    @test budget_status(250) == JuMP.MOI.OPTIMAL

    model, para =
        simple_model(; ts = periods, demand = FixedProfile(0), two_investments = true)
    nodes = para[:nodes]
    @constraint(model, model[:cap_capex][nodes, strategic] .== 100)
    investments = [(:cap, node) for node in nodes]
    max_budget(model, 200, investments, periods; sps_spec = strategic[1:1])
    optimize!(model)

    @test termination_status(model) == JuMP.MOI.OPTIMAL
end

@testset "Investment count limits" begin
    periods = TwoLevel(2, 1, SimpleTimes(1, 1))
    strategic = collect(strat_periods(periods))
    inv_data = NoStartInvData(
        FixedProfile(1),
        FixedProfile(1000),
        BinaryInvestment(FixedProfile(1)),
    )

    function maximum_status(limit)
        model, para = simple_model(;
            ts = periods,
            demand = FixedProfile(0),
            inv_data,
            two_investments = true,
        )
        nodes = para[:nodes]
        investments = [(:cap, node) for node in nodes]
        for node in nodes
            @constraint(model, model[:cap_invest_b][node, strategic[1]] == 1)
        end
        max_investments(model, limit, investments, periods)
        optimize!(model)
        termination_status(model)
    end

    @test maximum_status(1) == JuMP.MOI.INFEASIBLE
    @test maximum_status(2) == JuMP.MOI.OPTIMAL

    model, para = simple_model(;
        ts = periods,
        demand = FixedProfile(0),
        inv_data,
        two_investments = true,
    )
    nodes = para[:nodes]
    investments = [(:cap, node) for node in nodes]
    for node in nodes
        @constraint(model, model[:cap_invest_b][node, strategic[1]] == 0)
    end
    min_investments(model, 2, investments, periods; sps_spec = strategic[1:1])
    optimize!(model)

    @test termination_status(model) == JuMP.MOI.INFEASIBLE

    model, para = simple_model(;
        ts = periods,
        demand = FixedProfile(0),
        inv_data,
        two_investments = true,
    )
    nodes = para[:nodes]
    investments = [(:cap, node) for node in nodes]
    @constraint(model, model[:cap_invest_b][nodes[1], strategic[1]] == 1)
    min_investments(model, 1, investments, periods; sps_spec = strategic[1:1])
    optimize!(model)

    @test termination_status(model) == JuMP.MOI.OPTIMAL
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
                capacity_ratio * value(m[:cap_current][nodes[2], t_inv])
            for t_inv ∈ 𝒯ᴵⁿᵛ
        ) == length(𝒯ᴵⁿᵛ)
        @test sum(
            isapprox(value(m[:cap_current][nodes[2], t_inv]), capacity[t_inv] / capacity_ratio;
                atol = TEST_ATOL) for t_inv ∈ 𝒯ᴵⁿᵛ
        ) == length(𝒯ᴵⁿᵛ)
    end

    # Prerequisite capacity alone must not force dependent capacity
    @testset "Prerequisite capacity" begin
        for t_inv ∈ 𝒯ᴵⁿᵛ
            unfix(m[:cap_current][nodes[1], t_inv])
            fix(m[:cap_current][nodes[2], t_inv], capacity[t_inv]; force = true)
        end
        optimize!(m)

        @test termination_status(m) == JuMP.MOI.OPTIMAL
        @test sum(
            isapprox(value(m[:cap_current][nodes[1], t_inv]), 0; atol = TEST_ATOL)
            for t_inv ∈ 𝒯ᴵⁿᵛ
        ) == length(𝒯ᴵⁿᵛ)
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
            isapprox(value(m[:cap_current][nodes[1], t_inv]),
                capacity_ratio * value(m[:cap_current][nodes[2], t_inv]);
                atol = TEST_ATOL) for t_inv ∈ 𝒯ᴵⁿᵛ
        ) == length(𝒯ᴵⁿᵛ)
        @test sum(
            isapprox(value(m[:cap_current][node, t_inv]), capacity[t_inv];
                atol = TEST_ATOL) for t_inv ∈ 𝒯ᴵⁿᵛ
        ) == length(𝒯ᴵⁿᵛ)
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
            fix(m[:cap_current][nodes[2], t_inv], prerequisite[t_inv] / capacity_ratio;
                force = true)
        end
        optimize!(m)

        @test termination_status(m) == JuMP.MOI.OPTIMAL
        @test sum(
            value(m[:cap_current][nodes[1], t_inv]) ≲ capacity_ratio * (
                value(m[:cap_current][nodes[2], t_inv]) -
                value(m[:cap_add][nodes[2], t_inv])
            ) for t_inv ∈ 𝒯ᴵⁿᵛ
        ) == length(𝒯ᴵⁿᵛ)
        @test sum(
            isapprox(value(m[:cap_current][nodes[1], t_inv]), capacity[t_inv];
                atol = TEST_ATOL) for t_inv ∈ 𝒯ᴵⁿᵛ
        ) == length(𝒯ᴵⁿᵛ)
    end

    # Prerequisite additions in the same period cannot support dependent capacity
    @testset "Same-period prerequisite capacity" begin
        for t_inv ∈ 𝒯ᴵⁿᵛ
            fix(m[:cap_current][nodes[2], t_inv], capacity[t_inv] / capacity_ratio;
                force = true)
        end
        optimize!(m)

        @test termination_status(m) == JuMP.MOI.INFEASIBLE
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
        @test sum(
            isapprox(value(m[:cap_invest_b][node, t_inv]), activation[t_inv];
                atol = TEST_ATOL) for t_inv ∈ 𝒯ᴵⁿᵛ
        ) == length(𝒯ᴵⁿᵛ)
        @test sum(
            isapprox(value(m[:cap_invest_b][element, t_inv]), 0; atol = TEST_ATOL)
            for element ∈ setdiff(nodes, [node]), t_inv ∈ 𝒯ᴵⁿᵛ
        ) == length(𝒯ᴵⁿᵛ)
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
        @test sum(
            isapprox(value(m[:cap_invest_b][nodes[2], t_inv]), activation[t_inv];
                atol = TEST_ATOL) for t_inv ∈ 𝒯ᴵⁿᵛ
        ) == length(𝒯ᴵⁿᵛ)
    end

    # Prerequisite investments alone must not force dependent investments
    @testset "Prerequisite activation" begin
        for t_inv ∈ 𝒯ᴵⁿᵛ
            unfix(m[:cap_invest_b][nodes[1], t_inv])
            fix(m[:cap_invest_b][nodes[2], t_inv], activation[t_inv]; force = true)
        end
        optimize!(m)

        @test termination_status(m) == JuMP.MOI.OPTIMAL
        @test sum(
            isapprox(value(m[:cap_invest_b][nodes[1], t_inv]), 0; atol = TEST_ATOL)
            for t_inv ∈ 𝒯ᴵⁿᵛ
        ) == length(𝒯ᴵⁿᵛ)
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
        @test sum(
            isapprox(value(m[:cap_invest_b][element, t_inv]), activation[t_inv];
                atol = TEST_ATOL) for element ∈ nodes, t_inv ∈ 𝒯ᴵⁿᵛ
        ) == length(nodes) * length(𝒯ᴵⁿᵛ)
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
