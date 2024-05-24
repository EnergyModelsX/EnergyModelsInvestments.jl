"""
    EMB.objective(m, 𝒩, 𝒯, modeltype::AbstractInvestmentModel)

Create objective function overloading the default from EMB for AbstractInvestmentModel.

Maximize Net Present Value from investments (CAPEX) and operations (OPEX and emission costs)

## TODO:
Consider adding contributions from
 - revenue (as positive variable, adding positive)
 - maintenance based on usage (as positive variable, adding negative)
These variables would need to be introduced through the package `SparsVariables`.

Both are not necessary, as it is possible to include them through the OPEX values, but it
would be beneficial for a better separation and simpler calculations from the results.
"""
function EMB.objective(m, 𝒩, 𝒯, 𝒫, modeltype::AbstractInvestmentModel)

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    𝒩ᶜᵃᵖ = EMB.nodes_not_av(𝒩)                          # Nodes with capacity

    𝒩ᴵⁿᵛ = filter(has_investment, filter(!EMB.is_storage, 𝒩))
    𝒩ˢᵗᵒʳ = filter(EMB.is_storage, 𝒩)
    𝒩ˡᵉᵛᵉˡ = filter(n -> has_investment(n, :level), 𝒩ˢᵗᵒʳ)
    𝒩ᶜʰᵃʳᵍᵉ = filter(n -> has_investment(n, :charge), 𝒩ˢᵗᵒʳ)
    𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ = filter(n -> has_investment(n, :discharge), 𝒩ˢᵗᵒʳ)

    𝒫ᵉᵐ  = filter(EMB.is_resource_emit, 𝒫)              # Emissions resources

    disc = Discounter(discount_rate(modeltype), 𝒯)      # Discount type declaration

    # Calculation of the OPEX contribution
    opex = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum((m[:opex_var][n, t_inv] + m[:opex_fixed][n, t_inv]) for n ∈ 𝒩ᶜᵃᵖ)
    )

    # Calculation of the emission costs contribution
    emissions = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum(m[:emissions_strategic][t_inv, p] * emission_price(modeltype, p, t_inv) for p ∈ 𝒫ᵉᵐ)
    )

    # Calculation of the capital cost contribution
    capex_cap = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum(m[:cap_capex][n, t_inv]  for n ∈ 𝒩ᴵⁿᵛ)
    )

    # Calculation of the capital cost contribution of storage nodes
    capex_stor = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum(m[:stor_level_capex][n, t_inv] for n ∈ 𝒩ˡᵉᵛᵉˡ) +
        sum(m[:stor_charge_capex][n, t_inv] for n ∈ 𝒩ᶜʰᵃʳᵍᵉ) +
        sum(m[:stor_discharge_capex][n, t_inv] for n ∈ 𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ)
    )

    # Calculation of the objective function.
    @objective(m, Max,
        -sum(
            (opex[t_inv] + emissions[t_inv]) * duration_strat(t_inv) * objective_weight(t_inv, disc; type="avg") +
            (capex_cap[t_inv] + capex_stor[t_inv]) * objective_weight(t_inv, disc)
        for t_inv ∈ 𝒯ᴵⁿᵛ)
    )
end


"""
    EMB.variables_capex(m, 𝒩, 𝒯, 𝒫, modeltype::AbstractInvestmentModel)

Create variables for the capital costs for the invesments in storage and
technology nodes.

Additional variables for investment in capacity:
 * `:cap_capex` - CAPEX costs for a technology
 * `:cap_current` - installed capacity for storage in each strategic period
 * `:cap_add` - added capacity
 * `:cap_rem` - removed capacity
 * `:cap_invest_b` - binary variable whether investments in capacity are happening
 * `:cap_remove_b` - binary variable whether investments in capacity are removed


Additional variables for investment in storage:
 * `:stor_level_capex` - CAPEX costs for increases in the capacity of a storage
 * `:stor_level_current` - installed capacity for storage in each strategic period
 * `:stor_level_add` - added capacity
 * `:stor_level_rem` - removed capacity
 * `:stor_level_invest_b` - binary variable whether investments in capacity are happening
 * `:stor_level_remove_b` - binary variable whether investments in capacity are removed


 * `:stor_charge_capex` - CAPEX costs for increases in the rate of a storage
 * `:stor_charge_current` - installed rate for storage in each strategic period
 * `:stor_charge_add` - added rate
 * `:stor_charge_rem` - removed rate
 * `:stor_charge_invest_b` - binary variable whether investments in rate are happening
 * `:stor_charge_remove_b` - binary variable whether investments in rate are removed
"""
function EMB.variables_capex(m, 𝒩, 𝒯, 𝒫, modeltype::AbstractInvestmentModel)

    𝒩ᴵⁿᵛ = filter(has_investment, filter(!EMB.is_storage, 𝒩))
    𝒩ˢᵗᵒʳ = filter(EMB.is_storage, 𝒩)
    𝒩ˡᵉᵛᵉˡ = filter(n -> has_investment(n, :level), 𝒩ˢᵗᵒʳ)
    𝒩ᶜʰᵃʳᵍᵉ = filter(n -> has_investment(n, :charge), 𝒩ˢᵗᵒʳ)
    𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ = filter(n -> has_investment(n, :discharge), 𝒩ˢᵗᵒʳ)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Add investment variables for reference nodes for each strategic period:
    @variable(m, cap_capex[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)
    @variable(m, cap_current[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)     # Installed capacity
    @variable(m, cap_add[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ]  >= 0)        # Add capacity
    @variable(m, cap_rem[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ]  >= 0)        # Remove capacity
    @variable(m, cap_invest_b[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ]; container=IndexedVarArray)
    @variable(m, cap_remove_b[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ]; container=IndexedVarArray)

    # Add storage specific investment variables for each strategic period:
    @variable(m, stor_level_capex[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] >= 0)
    @variable(m, stor_level_current[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] >= 0)    # Installed capacity
    @variable(m, stor_level_add[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] >= 0)        # Add capacity
    @variable(m, stor_level_rem[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] >= 0)        # Remove capacity
    @variable(m, stor_level_invest_b[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] >= 0; container=IndexedVarArray)
    @variable(m, stor_level_remove_b[𝒩ˡᵉᵛᵉˡ, 𝒯ᴵⁿᵛ] >= 0; container=IndexedVarArray)

    @variable(m, stor_charge_capex[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0)
    @variable(m, stor_charge_current[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0)   # Installed power/rate
    @variable(m, stor_charge_add[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0)       # Add power
    @variable(m, stor_charge_rem[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0)       # Remove power
    @variable(m, stor_charge_invest_b[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0; container=IndexedVarArray)
    @variable(m, stor_charge_remove_b[𝒩ᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0; container=IndexedVarArray)

    @variable(m, stor_discharge_capex[𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0)
    @variable(m, stor_discharge_current[𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0)   # Installed power/rate
    @variable(m, stor_discharge_add[𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0)       # Add power
    @variable(m, stor_discharge_rem[𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0)       # Remove power
    @variable(m, stor_discharge_invest_b[𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0; container=IndexedVarArray)
    @variable(m, stor_discharge_remove_b[𝒩ᵈⁱˢᶜʰᵃʳᵍᵉ, 𝒯ᴵⁿᵛ] >= 0; container=IndexedVarArray)
end

"""
    EMB.constraints_capacity_installed(m, n::EMB.Node, 𝒯, modeltype::AbstractInvestmentModel

Set capacity-related constraints for nodes `𝒩` for investment time structure `𝒯`:
* bounds
* binary for BinaryInvestment
* link capacity variables

"""
function EMB.constraints_capacity_installed(m, n::EMB.Node, 𝒯::TimeStructure, modeltype::AbstractInvestmentModel)

    if has_investment(n)
        # Extract the investment data
        inv_data = investment_data(n)
        prefix = :cap

        # Add the investment constraints
        add_investment_constraints(m, n, inv_data, nothing, prefix, 𝒯, modeltype)

    else
        @constraint(m, [t ∈ 𝒯], m[:cap_inst][n, t] == capacity(n, t))
    end
end

"""
    constraints_capacity_installed(m, n::Storage, 𝒯::TimeStructure, modeltype::AbstractInvestmentModel)
Set storage-related constraints for nodes `𝒩ˢᵗᵒʳ` for investment time structure `𝒯`:
* bounds
* binary for BinaryInvestment
* link storage variables

"""
function EMB.constraints_capacity_installed(m, n::Storage, 𝒯::TimeStructure, modeltype::AbstractInvestmentModel)

    cap_fields = [:charge, :level, :discharge]

    for cap ∈ cap_fields
        if !hasfield(typeof(n), cap)
            continue
        end
        stor_par = getfield(n, cap)
        prefix = Symbol(:stor_, cap)
        var_inst = get_var_inst(m, prefix, n)
        if has_investment(n, cap)
            # Extract the investment data
            inv_data = investment_data(n, cap)

            # Add the investment constraints
            add_investment_constraints(m, n, inv_data, cap, prefix, 𝒯, modeltype)

        elseif isa(stor_par, EMB.UnionCapacity)
            for t ∈ 𝒯
                fix(var_inst[t], capacity(stor_par, t); force=true)
            end
        end
    end
end

function add_investment_constraints(m, n, inv_data, cap, prefix, 𝒯, modeltype)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Deduce required variables
    var_current = get_var_current(m, prefix, n)
    var_inst = get_var_inst(m, prefix, n)
    var_add = get_var_add(m, prefix, n)
    var_rem = get_var_rem(m, prefix, n)

    for (t_inv_prev, t_inv) ∈ withprev(𝒯ᴵⁿᵛ)
        # Link capacity usage to installed capacity
        @constraint(m, [t ∈ t_inv], var_inst[t] == var_current[t_inv])

        # Capacity updating
        @constraint(m, var_current[t_inv] <= max_installed(inv_data, t_inv))
        if isnothing(t_inv_prev)
            start_cap_val = start_cap(n, t_inv, inv_data, cap, modeltype)
            @constraint(m, var_current[t_inv] == start_cap_val + var_add[t_inv])
        else
            @constraint(m,
                var_current[t_inv] ==
                    var_current[t_inv_prev] + var_add[t_inv] - var_rem[t_inv_prev]
            )
        end
    end
    # Constraints for investments
    set_capacity_installation(m, n, cap, prefix, 𝒯ᴵⁿᵛ)

    # Constraints for the CAPEX calculation
    set_capacity_cost(m, n, inv_data, prefix, 𝒯ᴵⁿᵛ, modeltype)
end

"""
    set_capacity_installation(m, n, field, prefix, 𝒯ᴵⁿᵛ)

Add constraints related to installation depending on investment mode of type `n`.
"""
set_capacity_installation(m, n, cap, prefix, 𝒯ᴵⁿᵛ) =
    set_capacity_installation(m, n, cap, prefix, 𝒯ᴵⁿᵛ, investment_mode(n, cap))

function set_capacity_installation(m, n, cap, prefix, 𝒯ᴵⁿᵛ, inv_mode::Investment)
    # Deduce the required variable
    var_add = get_var_add(m, prefix, n)

    # Set the limits
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], var_add[t_inv] <= max_add(inv_mode, t_inv))
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], var_add[t_inv] >= min_add(inv_mode, t_inv))
end

function set_capacity_installation(m, n, cap, prefix, 𝒯ᴵⁿᵛ, inv_mode::BinaryInvestment)
    # Add the binary variable to the `SparseVariables` containers and add characteristics
    var_invest_b = get_var_invest_b(m, prefix)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        insertvar!(var_invest_b, n, t_inv)
        set_binary(var_invest_b[n, t_inv])
    end

    # Deduce the required variables
    var_current = get_var_current(m, prefix, n)

    # Extract the capacity from the node
    if isnothing(cap)
        cap_used = capacity(n)
    else
        cap_used = capacity(getproperty(n, cap))
    end

    # Set the limits
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_current[t_inv] ==
        cap_used[t_inv] * var_invest_b[n, t_inv]
    )
end

function set_capacity_installation(m, n, cap, prefix, 𝒯ᴵⁿᵛ, inv_mode::DiscreteInvestment)
    # Add the binary variable to the `SparseVariables` containers and add characteristics
    var_invest_b = get_var_invest_b(m, prefix)
    var_remove_b = get_var_remove_b(m, prefix)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        insertvar!(var_invest_b, n, t_inv)
        set_integer(var_invest_b[n, t_inv])
        insertvar!(var_remove_b, n, t_inv)
        set_integer(var_remove_b[n, t_inv])
    end

    # Deduce the required variables
    var_add = get_var_add(m, prefix, n)
    var_rem = get_var_rem(m, prefix, n)

    # Set the limits
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_add[t_inv] ==
            increment(inv_mode, t_inv) * var_invest_b[n, t_inv]
    )
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_rem[t_inv] ==
            increment(inv_mode, t_inv) * var_remove_b[n, t_inv]
    )
end

function set_capacity_installation(m, n, cap, prefix, 𝒯ᴵⁿᵛ, inv_mode::SemiContiInvestment)
    # Add the binary variable to the `SparseVariables` containers and add characteristics
    var_invest_b = get_var_invest_b(m, prefix)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        insertvar!(var_invest_b, n, t_inv)
        set_binary(var_invest_b[n, t_inv])
    end

    # Deduce the required variables
    var_add = get_var_add(m, prefix, n)

    # Set the limits
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_add[t_inv] <=
            max_add(inv_mode, t_inv) * var_invest_b[n, t_inv]
    )
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_add[t_inv] >=
            min_add(inv_mode, t_inv) * var_invest_b[n, t_inv]
    )
end

function set_capacity_installation(m, n, cap, prefix, 𝒯ᴵⁿᵛ, inv_mode::FixedInvestment)
    # Add the binary variable to the `SparseVariables` containers and add characteristics
    var_invest_b = get_var_invest_b(m, prefix)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        insertvar!(var_invest_b, n, t_inv)
        fix(var_invest_b[n, t_inv], 1; force=true)
    end

    # Deduce the required variables
    var_current = get_var_current(m, prefix, n)

    # Extract the capacity from the node
    if isnothing(cap)
        cap_used = capacity(n)
    else
        cap_used = capacity(getproperty(n, cap))
    end

    # Set the limits
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_current[t_inv] ==
            cap_used[t_inv] * var_invest_b[n, t_inv]
    )
end

"""
    set_capacity_cost(m, n, inv_data, prefix, 𝒯ᴵⁿᵛ, modeltype)

Set the capex_cost based on the technology investment cost, and strategic period length
to include the needs for reinvestments and the rest value.
It implements different versions of the lifetime implementation:
- UnlimitedLife:    The investment life is not limited. The investment costs do not \
                    consider any reinvestment or rest value.
- StudyLife:        The investment last for the whole study period with adequate \
                    reinvestments at end of lifetime and rest value.
- PeriodLife:       The investment is considered to last only for the strategic period. \
                    the excess lifetime is considered in the rest value.
- RollingLife:      The investment is rolling to the next strategic periods and it is \
                    retired at the end of its lifetime or the end of the previous sp if \
                    its lifetime ends between two sp.
"""
set_capacity_cost(m, n, inv_data, prefix, 𝒯ᴵⁿᵛ, modeltype) =
    set_capacity_cost(m, n, inv_data, prefix, 𝒯ᴵⁿᵛ, modeltype, lifetime_mode(inv_data))
function set_capacity_cost(m, n, inv_data, prefix, 𝒯ᴵⁿᵛ, modeltype, ::UnlimitedLife)
    # Deduce the required variables
    var_capex = get_var_capex(m, prefix, n)
    var_rem = get_var_rem(m, prefix, n)

    # The capacity has an unlimited lifetime, one investment at the beginning of t_inv
    capex_val = set_capex_value(m, n, inv_data, prefix, 𝒯ᴵⁿᵛ)
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], var_capex[t_inv] == capex_val[t_inv])

    # Fix the binary variable
    for t_inv ∈ 𝒯ᴵⁿᵛ
        fix(var_rem[t_inv], 0; force=true)
    end
end

function set_capacity_cost(m, n, inv_data, prefix, 𝒯ᴵⁿᵛ, modeltype, ::StudyLife)
    # Deduce the required variables
    var_capex = get_var_capex(m, prefix, n)
    var_rem = get_var_rem(m, prefix, n)

    # The capacity is limited to the end of the study. Reinvestments are included
    # No capacity removed as there are reinvestments according to the study length
    capex_disc = StrategicProfile(
        [
            set_capex_discounter(
                remaining(t_inv, 𝒯ᴵⁿᵛ),
                lifetime(inv_data, t_inv),
                discount_rate(modeltype)
            ) for t_inv ∈ 𝒯ᴵⁿᵛ
        ]
    )
    capex_val = set_capex_value(m, n, inv_data, prefix, 𝒯ᴵⁿᵛ)
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], var_capex[t_inv] == capex_val[t_inv] * capex_disc[t_inv])

    # Fix the binary variable
    for t_inv ∈ 𝒯ᴵⁿᵛ
        fix(var_rem[t_inv], 0; force=true)
    end
end

function set_capacity_cost(m, n, inv_data, prefix, 𝒯ᴵⁿᵛ,  modeltype, ::PeriodLife)
    # Deduce the required variables
    var_capex = get_var_capex(m, prefix, n)
    var_add = get_var_add(m, prefix, n)
    var_rem = get_var_rem(m, prefix, n)

    # The capacity is limited to the current sp. It has to be removed in the next sp.
    # The formula for capacity updating uses the cap_rem for the previous sp, hence the sps used here.
    capex_disc = StrategicProfile(
        [
            set_capex_discounter(
            duration_strat(t_inv),
            lifetime(inv_data, t_inv),
            discount_rate(modeltype)
            ) for t_inv ∈ 𝒯ᴵⁿᵛ
        ]
    )
    capex_val = set_capex_value(m, n, inv_data, prefix, 𝒯ᴵⁿᵛ)
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], var_capex[t_inv] == capex_val[t_inv] * capex_disc[t_inv])
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], var_rem[t_inv] == var_add[t_inv])
end

function set_capacity_cost(m, n, inv_data, prefix, 𝒯ᴵⁿᵛ, modeltype, ::RollingLife)
    # Deduce the required variables
    var_capex = get_var_capex(m, prefix, n)
    var_add = get_var_add(m, prefix, n)
    var_rem = get_var_rem(m, prefix, n)

    r = discount_rate(modeltype)
    capex_val = set_capex_value(m, n, inv_data, prefix, 𝒯ᴵⁿᵛ)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        # Extract the values
        lifetime_val = lifetime(inv_data, t_inv)

        # If lifetime is shorter than the sp duration, we apply the method for PeriodLife
        if lifetime_val < duration_strat(t_inv)
            set_capacity_cost(m, n, inv_data, prefix, 𝒯ᴵⁿᵛ, modeltype, PeriodLife())

        # If lifetime is equal to sp duration we only need to invest once and there is no rest value
        elseif lifetime_val == duration_strat(t_inv)
            @constraint(m, var_capex[t_inv] == capex_val)
            @constraint(m, var_rem[t_inv] == var_add[t_inv] )

        # If lifetime is longer than sp duration, the capacity can roll over to the next sp.
        elseif lifetime_val > duration_strat(t_inv)
            # Initialization of the ante_sp and the remaining lifetime
            # ante_sp represents the last sp in which the remaining lifetime is  sufficient
            # to cover the whole sp duration.
            ante_sp = t_inv
            remaining_lifetime = lifetime_val

            # Iteration to identify sp in which remaining_lifetime is smaller than sp duration
            for sp ∈ 𝒯ᴵⁿᵛ
                if sp >= t_inv
                    if remaining_lifetime < duration_strat(sp)
                        break
                    end
                    remaining_lifetime -= duration_strat(sp)
                    ante_sp = sp
                end
            end

            # Calculation of cost and rest value
            capex_disc =
                    (1 - (remaining_lifetime/lifetime_val) * (1+r)^(-(lifetime_val - remaining_lifetime)))
            @constraint(m, var_capex[t_inv] == capex_val[t_inv] * capex_disc)

            # Capacity to be removed when remaining_lifetime < duration_years, i.e., in ante_sp
            if ante_sp.sp < length(𝒯ᴵⁿᵛ)
                @constraint(m, var_rem[ante_sp] == var_add[t_inv])
            end
        end
    end
end
