"""
    add_investment_constraints(
        m,
        element,
        inv_data::AbstractInvData,
        cap,
        prefix,
        𝒯ᴵⁿᵛ::TS.AbstractStratPers,
        disc_rate::Float64,
    )

Core function for introducing constraints on the investments. The constraints include
introducing bounds on the available capacities as well as the calculation of the CAPEX.

The function calls two additional subroutines, [`set_capacity_installation`](@ref) and
[`set_capacity_cost`](@ref) which are used for introducing bounds on the investment
variables and calculating the CAPEX contribution of each investments. The utilization of
subroutines allows the introduction of dispatch for the individual investment and lifetime
options.

# Arguments
- `m`: the JuMP model instance.
- `element`: the element for which investment constraints should be added. Any potential
  element can be used. In `EnergyModelsBase`, the individual element is either a `Node` or a
  `TransmissionMode`.
- `inv_data::AbstractInvData`: the investment data for the node and capacity `cap`.
- `cap`: the field that is used if several capacities are provided.
- `prefix`: the prefix used for variables for this element. This argument is used for
  extracting the individual investment variables.
- `𝒯::Union{TwoLevel, TwoLevelTree}`: the time structure.
- `disc_rate`: the discount rate used in the lifetime calculation for reinvestment and
  end of life calculations.
"""
function add_investment_constraints(
    m,
    element,
    inv_data::AbstractInvData,
    cap,
    prefix,
    𝒯::Union{TwoLevel, TwoLevelTree},
    disc_rate::Float64,
)
    # Extract the strategic periods
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Deduce required variables and values
    var_current = get_var_current(m, prefix, element)
    var_inst = get_var_inst(m, prefix, element)
    var_add = get_var_add(m, prefix, element)
    var_rem = get_var_rem(m, prefix, element)
    val_start_cap = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], start_cap(element, t_inv, inv_data, cap))

    # Identify the investment periods relevant for capacity addition in each investment period
    life_dict = Dict(t_inv => eltype(𝒯ᴵⁿᵛ)[] for t_inv ∈ 𝒯ᴵⁿᵛ)
    populate_lifetime_vectors!(life_dict, lifetime_mode(inv_data), 𝒯ᴵⁿᵛ)

    for (t_inv_prev, t_inv) ∈ withprev(𝒯ᴵⁿᵛ)
        # Link capacity usage to installed capacity
        @constraint(m, [t ∈ t_inv], var_inst[t] == var_current[t_inv])

        # Set the upper bound of the variable
        set_upper_bound(var_current[t_inv], max_installed(inv_data, t_inv))

        # Capacity updating
        if isnothing(t_inv_prev)
            @constraint(m, var_current[t_inv] == val_start_cap[t_inv] + var_add[t_inv])
        else
            @constraint(m,
                var_current[t_inv] ==
                    val_start_cap[t_inv] - val_start_cap[t_inv_prev] +
                    var_current[t_inv_prev] + var_add[t_inv] - var_rem[t_inv_prev]
            )
            @constraint(m,
                var_current[t_inv] ≤
                    val_start_cap[t_inv] - val_start_cap[t_inv_prev] +
                    sum(var_add[sp] for sp ∈ life_dict[t_inv])
            )
        end
    end
    # Constraints for investments
    set_capacity_installation(m, element, prefix, 𝒯ᴵⁿᵛ, val_start_cap, investment_mode(inv_data))

    # Constraints for the CAPEX calculation
    set_capacity_cost(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, disc_rate)
end

"""
    set_capacity_installation(m, element, prefix, 𝒯ᴵⁿᵛ, inv_data, inv_mode)

Add constraints related to upper and lower bounds for investments depending on investment
mode of type `element`.

These constraints differ dependent on the chosen [`Investment`](@ref):
- **[`Investment`](@ref)** results in provding a lower and upper bound to the variable
  `var_add` through the functions [`min_add`](@ref) and [`max_add`](@ref). This approach
  is the default approach for all investment modes.
- **[`BinaryInvestment`](@ref)** results in setting the variable `var_invest_b` as binary
  variable. Furthermore, the variable `var_current` is only able to be 0 or a provided
  value through the function [`invest_capacity`](@ref).
- **[`DiscreteInvestment`](@ref)** results in setting the variables `var_invest_b` and
  `var_remove_b`as positive integer variables. Furthermore, the variable `var_current` is
  only able to be equal to a multiple of a provided value through the function
  [`increment`](@ref).
- **[`SemiContiInvestment`](@ref)** results in setting the variable `var_invest_b` as binary
  variable. Furthermore, the variable `var_add` is bound through the functions
  [`min_add`](@ref) and [`max_add`](@ref) or 0.
- **[`FixedInvestment`](@ref)** results in setting the variable `var_invest_b` as binary
  variable. Furthermore, the variable `var_current` is fixed to a provided value through
  the function [`invest_capacity`](@ref). This allows to incorporate the cost for the correct
  value of the objective function.

!!! tip "Introducing new investment modes"
    This function can be extended with a new method if you introduce a new
    [`Investment`](@ref). If not, you have to make certain that the functions
    [`min_add`](@ref) and [`max_add`](@ref) are applicable for your investment mode.
"""
function set_capacity_installation(m, element, prefix, 𝒯ᴵⁿᵛ, val_start_cap, inv_mode::Investment)
    # Deduce the required variable
    var_add = get_var_add(m, prefix, element)

    # Set the limits
    for t_inv ∈ 𝒯ᴵⁿᵛ
        set_lower_bound(var_add[t_inv], min_add(inv_mode, t_inv))
        set_upper_bound(var_add[t_inv], max_add(inv_mode, t_inv))
    end
end

function set_capacity_installation(m, element, prefix, 𝒯ᴵⁿᵛ, val_start_cap, inv_mode::BinaryInvestment)
    # Add the binary variable to the `SparseVariables` containers and add characteristics
    var_invest_b = get_var_invest_b(m, prefix)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        insertvar!(var_invest_b, element, t_inv)
        set_binary(var_invest_b[element, t_inv])
    end

    # Deduce the required variables and values
    var_current = get_var_current(m, prefix, element)

    # Set the limits
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_current[t_inv] ==
            val_start_cap[t_inv] +
            invest_capacity(inv_mode, t_inv) * var_invest_b[element, t_inv]
    )
end
function set_capacity_installation(m, element, prefix, 𝒯ᴵⁿᵛ, val_start_cap, inv_mode::DiscreteInvestment)
    # Add the binary variable to the `SparseVariables` containers and add characteristics
    var_invest_b = get_var_invest_b(m, prefix)
    var_remove_b = get_var_remove_b(m, prefix)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        insertvar!(var_invest_b, element, t_inv)
        set_integer(var_invest_b[element, t_inv])
        insertvar!(var_remove_b, element, t_inv)
        set_integer(var_remove_b[element, t_inv])
    end

    # Deduce the required variables
    var_add = get_var_add(m, prefix, element)
    var_rem = get_var_rem(m, prefix, element)

    # Set the limits
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_add[t_inv] == increment(inv_mode, t_inv) * var_invest_b[element, t_inv]
    )
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_rem[t_inv] == increment(inv_mode, t_inv) * var_remove_b[element, t_inv]
    )
end
function set_capacity_installation(m, element, prefix, 𝒯ᴵⁿᵛ, val_start_cap, inv_mode::SemiContiInvestment)
    # Add the binary variable to the `SparseVariables` containers and add characteristics
    var_invest_b = get_var_invest_b(m, prefix)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        insertvar!(var_invest_b, element, t_inv)
        set_binary(var_invest_b[element, t_inv])
    end

    # Deduce the required variables
    var_add = get_var_add(m, prefix, element)

    # Set the limits
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_add[t_inv] ≤ max_add(inv_mode, t_inv) * var_invest_b[element, t_inv]
    )
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_add[t_inv] ≥ min_add(inv_mode, t_inv) * var_invest_b[element, t_inv]
    )
end
function set_capacity_installation(m, element, prefix, 𝒯ᴵⁿᵛ, val_start_cap, inv_mode::FixedInvestment)
    # Add the binary variable to the `SparseVariables` containers and add characteristics
    var_invest_b = get_var_invest_b(m, prefix)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        insertvar!(var_invest_b, element, t_inv)
        fix(var_invest_b[element, t_inv], 1; force = true)
    end

    # Deduce the required variables
    var_current = get_var_current(m, prefix, element)

    # Set the limits
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_current[t_inv] ==
            val_start_cap[t_inv] +
            invest_capacity(inv_mode, t_inv) * var_invest_b[element, t_inv]
    )
end

"""
    set_capacity_cost(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, disc_rate)

Function for creating constraints for the variable `var_capex` dependent on the chosen
[`Investment`](@ref) and [`LifetimeMode`](@ref).

The lifetime calculations are located within this function while the corresponding
undiscounted CAPEX values are calculated in the function [`set_capex_value`](@ref),
depending on the chosen investment mode.

It implements different versions of the lifetime implementation:
- **[`UnlimitedLife`](@ref)** results in an unlimited investment. The investment costs do
  not consider any reinvestment or rest value.
- **[`StudyLife`](@ref)** results in the investment lasting for the whole study period with
  adequate reinvestments at end of lifetime and rest value.
- **[`PeriodLife`](@ref)** results in the investment lasting only for the investment period,
  independent of the duration of the investment period. The excess lifetime is considered in
  the calculation of the rest value.
- **[`RollingLife`](@ref)** results in the investment rolling to the next strategic periods.
  A capacity is retired at the end of its lifetime or the end of the previous strategic
  period if its lifetime ends between two strategic periods.

!!! tip "Introducing new lifetime modes"
    This function can be extended with a new method if you introduce a new
    [`LifetimeMode`](@ref). If not, you have to make certain that the function
    [`lifetime`](@ref) is applicable for your lifetime mode.
"""
set_capacity_cost(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, disc_rate) = set_capacity_cost(
    m,
    element,
    inv_data,
    prefix,
    𝒯ᴵⁿᵛ,
    disc_rate,
    lifetime_mode(inv_data),
)
function set_capacity_cost(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, disc_rate, ::UnlimitedLife)
    # Deduce the required variables
    var_capex = get_var_capex(m, prefix, element)

    # The capacity has an unlimited lifetime, one investment at the beginning of t_inv
    capex_val = set_capex_value(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ)
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], var_capex[t_inv] == capex_val[t_inv])
end
function set_capacity_cost(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, disc_rate, ::StudyLife)
    # Deduce the required variables
    var_capex = get_var_capex(m, prefix, element)
    var_add = get_var_add(m, prefix, element)
    var_rem = get_var_rem(m, prefix, element)

    # The capacity is limited to the end of the study. Reinvestments are included
    disc_fact = StrategicProfile([
        set_capex_discounter(
            remaining(t_inv, 𝒯ᴵⁿᵛ),
            lifetime(inv_data, t_inv), disc_rate
        ) for t_inv ∈ 𝒯ᴵⁿᵛ
    ])
    capex_val = set_capex_value(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ)
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], var_capex[t_inv] == capex_val[t_inv] * disc_fact[t_inv])

    # All capacities that require reinvestments or should be retired at the end of the study
    # are removed
    @constraint(m,
        sum(var_rem[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ) ≥
            sum(var_add[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ if disc_fact[t_inv] ≥ 1.0)
    )
end
function set_capacity_cost(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, disc_rate, ::PeriodLife)
    # Deduce the required variables
    var_capex = get_var_capex(m, prefix, element)
    var_add = get_var_add(m, prefix, element)
    var_rem = get_var_rem(m, prefix, element)

    # The capacity is limited to the current sp. It has to be removed in the next sp.
    # The capacity removal variable is corresponding to the removal of the capacity at the
    # end of the investment period. Hence, we have to enforce `var_rem[t_inv] == var_add[t_inv]`
    disc_fact = StrategicProfile([
        set_capex_discounter(
            duration_strat(t_inv),
            lifetime(inv_data, t_inv), disc_rate
        ) for t_inv ∈ 𝒯ᴵⁿᵛ
    ])
    capex_val = set_capex_value(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ)
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], var_capex[t_inv] == capex_val[t_inv] * disc_fact[t_inv])
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], var_rem[t_inv] == var_add[t_inv])
end
function set_capacity_cost(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, disc_rate, lifetime_mode::RollingLife)
    # Deduce the required variables
    var_capex = get_var_capex(m, prefix, element)
    var_add = get_var_add(m, prefix, element)
    var_rem = get_var_rem(m, prefix, element)

    # Calculate the CAPEX value based on the chosen investment mode
    capex_val = set_capex_value(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ)

    # Initialize the capacity removal dictionary
    rem_dict = _init_rem_dict(𝒯ᴵⁿᵛ)

    # Depending on the lifetime, different approaches are used through the function
    # `capacity_removal!` where the rest value (or additional costs) are calculated given
    # the lifetime of the element and the duration. The outer for loop is required to
    # differentiate between `TwoLevel` and `TwoLevelTree`
    for t_inv ∈ 𝒯ᴵⁿᵛ
        disc_fact = capacity_removal!(
            rem_dict, t_inv, lifetime(inv_data, t_inv), 𝒯ᴵⁿᵛ, disc_rate
        )
        @constraint(m, var_capex[t_inv] == capex_val[t_inv] * disc_fact)
    end
    # Requirement for total capacity removal given the investments whose lifetime ends within
    # the study period
    @constraint(m, [𝒯ᴵⁿᵛ ∈ keys(rem_dict)],
        sum(var_rem[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ) ==
            sum(var_add[t_inv] for t_inv ∈ rem_dict[𝒯ᴵⁿᵛ])
    )
end
