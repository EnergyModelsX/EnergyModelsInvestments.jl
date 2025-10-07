
"""
    struct SimpleNode

Simple type for testing with a single capacity
"""
struct SimpleNode
    cap::TimeProfile
end

"""
    simple_model(;
        ts = TwoLevel(4,5,SimpleTimes(24,1)),
        initial = FixedProfile(10),
        inv_data = NoStartInvData(
            FixedProfile(1e6),
            FixedProfile(40),
            ContinuousInvestment(FixedProfile(0), FixedProfile(10)),
        ),
        demand = FixedProfile(10),
        penalty_deficit = FixedProfile(150),
        penalty_surplus = FixedProfile(0),
        fixed_opex = FixedProfile(0),
        disc_rate = 0.07,
    )

Create a simple JuMP model that is utilized for testing the individual functionality of the
system. It consists of a simple generator and demand with both surplus and deficit penalties.
"""
function simple_model(;
    ts = TwoLevel(4,10,SimpleTimes(4,1)),
    initial = FixedProfile(0),
    inv_data = NoStartInvData(
        FixedProfile(1000),
        FixedProfile(30),
        ContinuousInvestment(FixedProfile(0), FixedProfile(10)),
    ),
    demand = StrategicProfile([10,30,30,40]),
    penalty_deficit = FixedProfile(1e4),
    penalty_surplus = FixedProfile(0),
    fixed_opex = FixedProfile(0),
    disc_rate = 0.05,
)

    # Creation of the model and extraction of strategic periods
    m = JuMP.Model()
    𝒯 = ts
    𝒯ᴵⁿᵛ = strat_periods(𝒯)
    disc = Discounter(disc_rate, 𝒯)

    # Call of the function for variable declaration
    n = SimpleNode(initial)
    variables(m, n, 𝒯)

    # Create the optimization problem
    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] + m[:deficit][t] ==
            demand[t] + m[:surplus][t]
    )
    @constraint(m, [t ∈ 𝒯], m[:cap_use][n, t] ≤ m[:cap_inst][n, t])

    # Add the investment constraints
    EMI.add_investment_constraints(m, n, inv_data, nothing, :cap, 𝒯ᴵⁿᵛ, disc_rate)

    # Calculation of the OPEX contribution
    opex = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum(
            (
                m[:deficit][t] * penalty_deficit[t] +
                m[:surplus][t] * penalty_surplus[t]
            ) * duration(t) * multiple_strat(t_inv, t)
        for t ∈ t_inv) +
        m[:cap_current][n, t_inv] * fixed_opex[t_inv]
    )

    # Calculation of the objective function.
    @objective(m, Max,
    -sum(
        opex[t_inv] * duration_strat(t_inv) * objective_weight(t_inv, disc; type = "avg") +
        m[:cap_capex][n, t_inv] * objective_weight(t_inv, disc)
        for t_inv ∈ 𝒯ᴵⁿᵛ)
    )
    set_optimizer(m, HiGHS.Optimizer)
    set_optimizer_attribute(m, MOI.Silent(), true)
    optimize!(m)

    para = Dict(
        :node => n,
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
    @variable(m, cap_use[[n], 𝒯] ≥ 0)
    @variable(m, cap_inst[[n], 𝒯] ≥ 0)

    # Add investment variables for reference nodes for each strategic period:
    @variable(m, cap_capex[[n], 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, cap_current[[n], 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, cap_add[[n], 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, cap_rem[[n], 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, cap_invest_b[[n], 𝒯ᴵⁿᵛ] ≥ 0; container = IndexedVarArray)
    @variable(m, cap_remove_b[[n], 𝒯ᴵⁿᵛ] ≥ 0; container = IndexedVarArray)

    # Add demand variables
    @variable(m, surplus[𝒯] ≥ 0)
    @variable(m, deficit[𝒯] ≥ 0)
end

function present_value(annuity_period, r, period_duration, n_periods)
    pv = sum([annuity_period/(1+r)^(period_duration*i) for i in 0:(n_periods-1)])
    return pv
end