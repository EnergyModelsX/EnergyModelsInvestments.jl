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

@testset "Requires capacity" begin
    periods = TwoLevel(2, 1, SimpleTimes(1, 1))
    strategic = collect(strat_periods(periods))

    infeasible, para =
        simple_model(; ts = periods, demand = FixedProfile(0), two_investments = true)
    nodes = para[:nodes]
    requires_capacity(infeasible, :cap, nodes[1], :cap, nodes[2], periods)
    @constraint(infeasible, infeasible[:cap_current][nodes[1], strategic[1]] == 1)
    @constraint(infeasible, infeasible[:cap_current][nodes[2], strategic[1]] == 0)
    optimize!(infeasible)

    @test termination_status(infeasible) == JuMP.MOI.INFEASIBLE

    feasible, para =
        simple_model(; ts = periods, demand = FixedProfile(0), two_investments = true)
    nodes = para[:nodes]
    requires_capacity(feasible, :cap, nodes[1], :cap, nodes[2], periods; capacity_ratio = 2)
    @constraint(feasible, feasible[:cap_current][nodes[1], strategic[1]] == 2)
    @constraint(feasible, feasible[:cap_current][nodes[2], strategic[1]] == 1)
    optimize!(feasible)

    @test termination_status(feasible) == JuMP.MOI.OPTIMAL
end

@testset "Couple capacity" begin
    periods = TwoLevel(2, 1, SimpleTimes(1, 1))
    strategic = collect(strat_periods(periods))

    infeasible, para =
        simple_model(; ts = periods, demand = FixedProfile(0), two_investments = true)
    nodes = para[:nodes]
    couple_capacity(infeasible, :cap, nodes[1], :cap, nodes[2], periods)
    @constraint(infeasible, infeasible[:cap_current][nodes[1], strategic[1]] == 1)
    @constraint(infeasible, infeasible[:cap_current][nodes[2], strategic[1]] == 0)
    optimize!(infeasible)

    @test termination_status(infeasible) == JuMP.MOI.INFEASIBLE

    feasible, para =
        simple_model(; ts = periods, demand = FixedProfile(0), two_investments = true)
    nodes = para[:nodes]
    couple_capacity(feasible, :cap, nodes[1], :cap, nodes[2], periods; capacity_ratio = 2)
    @constraint(feasible, feasible[:cap_current][nodes[1], strategic[1]] == 2)
    @constraint(feasible, feasible[:cap_current][nodes[2], strategic[1]] == 1)
    optimize!(feasible)

    @test termination_status(feasible) == JuMP.MOI.OPTIMAL
end

@testset "Precede capacity" begin
    periods = TwoLevel(3, 1, SimpleTimes(1, 1))
    strategic = collect(strat_periods(periods))

    infeasible, para =
        simple_model(; ts = periods, demand = FixedProfile(0), two_investments = true)
    nodes = para[:nodes]
    precede_capacity(infeasible, :cap, nodes[1], :cap, nodes[2], periods)
    @constraint(infeasible, infeasible[:cap_add][nodes[1], strategic[1]] == 1)
    optimize!(infeasible)

    @test termination_status(infeasible) == JuMP.MOI.INFEASIBLE

    feasible, para =
        simple_model(; ts = periods, demand = FixedProfile(0), two_investments = true)
    nodes = para[:nodes]
    precede_capacity(feasible, :cap, nodes[1], :cap, nodes[2], periods)
    @constraint(feasible, feasible[:cap_add][nodes[1], strategic[2]] == 1)
    @constraint(feasible, feasible[:cap_current][nodes[2], strategic[1]] == 1)
    optimize!(feasible)

    @test termination_status(feasible) == JuMP.MOI.OPTIMAL
end

@testset "Excludes" begin
    periods = TwoLevel(2, 1, SimpleTimes(1, 1))
    strategic = collect(strat_periods(periods))
    inv_data = NoStartInvData(
        FixedProfile(1),
        FixedProfile(1000),
        SemiContinuousInvestment(FixedProfile(0), FixedProfile(10)),
    )

    infeasible, para = simple_model(;
        ts = periods,
        demand = FixedProfile(0),
        inv_data,
        two_investments = true,
    )
    nodes = para[:nodes]
    excludes_capacity(infeasible, :cap, nodes[1], :cap, nodes[2], periods)
    @constraint(infeasible, infeasible[:cap_invest_b][nodes[1], strategic[1]] == 1)
    @constraint(infeasible, infeasible[:cap_invest_b][nodes[2], strategic[1]] == 1)
    @objective(infeasible, Min, 0)
    optimize!(infeasible)

    @test termination_status(infeasible) == JuMP.MOI.INFEASIBLE

    feasible, para = simple_model(;
        ts = periods,
        demand = FixedProfile(0),
        inv_data,
        two_investments = true,
    )
    nodes = para[:nodes]
    excludes_capacity(feasible, :cap, nodes[1], :cap, nodes[2], periods)
    @constraint(feasible, feasible[:cap_invest_b][nodes[1], strategic[1]] == 1)
    @objective(feasible, Min, 0)
    optimize!(feasible)

    @test termination_status(feasible) == JuMP.MOI.OPTIMAL
    @test value(feasible[:cap_invest_b][nodes[2], strategic[1]]) ≈ 0
end

@testset "Excludes - no binary investment variables" begin
    periods = TwoLevel(2, 1, SimpleTimes(1, 1))
    strategic = collect(strat_periods(periods))

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
    @test_throws ArgumentError excludes_capacity(
        integer_model,
        :cap,
        nodes[1],
        :cap,
        nodes[2],
        periods,
    )
    @test_throws ArgumentError max_investments(integer_model, 1, investments, periods)
    @test_throws ArgumentError min_investments(integer_model, 1, investments, periods)

    missing_model, para =
        simple_model(; ts = periods, demand = FixedProfile(0), two_investments = true)
    nodes = para[:nodes]
    investments = [(:cap, node) for node in nodes]
    @test_throws ArgumentError excludes_capacity(
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
