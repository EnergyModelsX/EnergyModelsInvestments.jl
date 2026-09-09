"""
    struct SimpleNode

Simple type for testing with a single capacity
"""
struct SimpleNode
    cap::TimeProfile
    id::Int
end

SimpleNode(cap::TimeProfile) = SimpleNode(cap, 1)

"""
    simple_model(;
        ts = TwoLevel(4, 10, SimpleTimes(4, 1)),
        initial = FixedProfile(0),
        inv_data = NoStartInvData(
            FixedProfile(1000),
            FixedProfile(30),
            ContinuousInvestment(FixedProfile(0), FixedProfile(10)),
        ),
        demand = StrategicProfile([10, 30, 30, 40]),
        penalty_deficit = FixedProfile(1e4),
        penalty_surplus = FixedProfile(0),
        fixed_opex = FixedProfile(0),
        disc_rate = 0.05,
        ret_cost = 0.2,
        two_investments = false,
    )

Create a simple JuMP model that is utilized for testing the individual functionality of the
system. It consists of a simple generator (or two) and demand with both surplus and deficit
penalties.
"""
function simple_model(;
    ts = TwoLevel(4, 10, SimpleTimes(4, 1)),
    initial = FixedProfile(0),
    inv_data = NoStartInvData(
        FixedProfile(1000),
        FixedProfile(30),
        ContinuousInvestment(FixedProfile(0), FixedProfile(10)),
    ),
    demand = StrategicProfile([10, 30, 30, 40]),
    penalty_deficit = FixedProfile(1e4),
    penalty_surplus = FixedProfile(0),
    fixed_opex = FixedProfile(0),
    disc_rate = 0.05,
    ret_cost = 0.2,
    two_investments = false,
)

    # Creation of the model and extraction of strategic periods
    m = JuMP.Model()
    𝒯 = ts
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    disc = Discounter(disc_rate, 𝒯)

    # Call of the function for variable declaration
    nodes =
        two_investments ? [SimpleNode(initial, 1), SimpleNode(initial, 2)] :
        [SimpleNode(initial)]
    n = first(nodes)
    variables(m, nodes, 𝒯)

    # Create the optimization problem
    @constraint(m, [t ∈ 𝒯],
        sum(m[:cap_use][node, t] for node ∈ nodes) + m[:deficit][t] ==
        demand[t] + m[:surplus][t]
    )
    @constraint(m, [node ∈ nodes, t ∈ 𝒯], m[:cap_use][node, t] ≤ m[:cap_inst][node, t])

    # Add the investment constraints
    for node ∈ nodes
        EMI.add_investment_constraints(m, node, inv_data, nothing, :cap, 𝒯, disc_rate)
    end

    # Calculation of the OPEX contribution
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex][t_inv] ==
        sum(
            (m[:deficit][t] * penalty_deficit[t] + m[:surplus][t] * penalty_surplus[t]) *
            duration(t) * multiple_strat(t_inv, t)
        for t ∈ t_inv) +
        sum(m[:cap_current][node, t_inv] for node ∈ nodes) * fixed_opex[t_inv]
    )

    # Calculation of the objective function.
    @objective(m, Max,
        -sum(
            m[:opex][t_inv] * duration_strat(t_inv) *
            objective_weight(t_inv, disc; type = "avg") +
            sum(m[:cap_capex][node, t_inv] for node ∈ nodes) *
            objective_weight(t_inv, disc) for t_inv ∈ 𝒯ᴵⁿᵛ
        )
    )
    set_optimizer(m, HiGHS.Optimizer)
    set_optimizer_attribute(m, MOI.Silent(), true)
    optimize!(m)

    para = Dict(
        :node => n,
        :nodes => nodes,
        :T => 𝒯,
        :initial => initial,
        :inv_data => inv_data,
        :demand => demand,
        :penalty_deficit => penalty_deficit,
        :penalty_surplus => penalty_surplus,
        :fixed_opex => fixed_opex,
        :disc_rate => disc_rate,
    )
    return m, para
end

# Function required for utilizing EnergyModelsInvestments
EMI.start_cap(n::SimpleNode, t_inv, inv_data::NoStartInvData, cap) = n.cap[t_inv]

"""
    variables(m, n, 𝒯)

Create the required variables. This set is an absolut minimum required for
EnergyModelsInvestments to work.
"""
function variables(m, n, 𝒯)
    # Extract strategic periods
    𝒯ᴵⁿᵛ = strat_periods(𝒯)

    # Add capacity variables for the production
    nodes = n isa AbstractVector ? n : [n]
    @variable(m, cap_use[nodes, 𝒯] ≥ 0)
    @variable(m, cap_inst[nodes, 𝒯] ≥ 0)

    # Add investment variables for reference nodes for each strategic period:
    @variable(m, cap_capex[nodes, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, cap_current[nodes, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, cap_add[nodes, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, cap_rem[nodes, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, cap_invest_b[nodes, 𝒯ᴵⁿᵛ] ≥ 0; container = IndexedVarArray)
    @variable(m, cap_remove_b[nodes, 𝒯ᴵⁿᵛ] ≥ 0; container = IndexedVarArray)

    # Add additional variables
    @variable(m, opex[𝒯ᴵⁿᵛ])
    @variable(m, surplus[𝒯] ≥ 0)
    @variable(m, deficit[𝒯] ≥ 0)
end
