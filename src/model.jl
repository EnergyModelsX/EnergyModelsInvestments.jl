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
    𝒩ˢᵗᵒʳ = filter(EMB.is_storage, 𝒩)                   # Storage nodes
    𝒩ˢᵗᵒʳᴵⁿᵛ = filter(has_investment, 𝒩ˢᵗᵒʳ)            # Storage nodes with investments
    𝒩ᴵⁿᵛ = setdiff(filter(has_investment, 𝒩), 𝒩ˢᵗᵒʳᴵⁿᵛ) # Other nodes with investments

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
        sum(m[:capex_cap][n, t_inv]  for n ∈ 𝒩ᴵⁿᵛ)
    )

    # Calculation of the capital cost contribution of storage nodes
    capex_stor = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum(m[:capex_stor][n, t_inv] + m[:capex_rate][n, t_inv]  for n ∈ 𝒩ˢᵗᵒʳᴵⁿᵛ)
    )

    # Calculation of the objective function.
    @objective(m, Max,
        -sum(
            (opex[t_inv] + emissions[t_inv]) * duration(t_inv) * objective_weight(t_inv, disc, type="avg") +
            (capex_cap[t_inv] + capex_stor[t_inv]) * objective_weight(t_inv, disc)
        for t_inv ∈ 𝒯ᴵⁿᵛ)
    )
end


"""
    EMB.variables_capex(m, 𝒩, 𝒯, 𝒫, modeltype::AbstractInvestmentModel)

Create variables for the capital costs for the invesments in storage and
technology nodes.

Additional variables for investment in capacity:
 * `:capex_cap` - CAPEX costs for a technology
 * `:cap_invest_b` - binary variable whether investments in capacity are happening
 * `:cap_remove_b` - binary variable whether investments in capacity are removed
 * `:cap_current` - installed capacity for storage in each strategic period
 * `:cap_add` - added capacity
 * `:cap_rem` - removed capacity


Additional variables for investment in storage:
 * `:capex_stor` - CAPEX costs for increases in the capacity of a storage
 * `:stor_cap_invest_b` - binary variable whether investments in capacity are happening
 * `:stor_cap_remove_b` - binary variable whether investments in capacity are removed
 * `:stor_cap_current` - installed capacity for storage in each strategic period
 * `:stor_cap_add` - added capacity
 * `:stor_cap_rem` - removed capacity


 * `:capex_rate` - CAPEX costs for increases in the rate of a storage
 * `:stor_rate_invest_b` - binary variable whether investments in rate are happening
 * `:stor_rate_remove_b` - binary variable whether investments in rate are removed
 * `:stor_rate_current` - installed rate for storage in each strategic period
 * `:stor_rate_add` - added rate
 * `:stor_rate_rem` - removed rate
"""
function EMB.variables_capex(m, 𝒩, 𝒯, 𝒫, modeltype::AbstractInvestmentModel)

    𝒩ˢᵗᵒʳ = filter(EMB.is_storage, 𝒩)
    𝒩ˢᵗᵒʳᴵⁿᵛ = filter(has_investment, 𝒩ˢᵗᵒʳ)
    𝒩ᴵⁿᵛ = setdiff(filter(has_investment, 𝒩), 𝒩ˢᵗᵒʳᴵⁿᵛ)

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)


    # Add investment variables for reference nodes for each strategic period:
    @variable(m, capex_cap[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)
    @variable(m, cap_invest_b[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ])
    @variable(m, cap_remove_b[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ])
    @variable(m, cap_current[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)     # Installed capacity
    @variable(m, cap_add[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ]  >= 0)        # Add capacity
    @variable(m, cap_rem[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ]  >= 0)        # Remove capacity

    # Add storage specific investment variables for each strategic period:
    @variable(m, capex_stor[𝒩ˢᵗᵒʳᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)
    @variable(m, stor_cap_invest_b[𝒩ˢᵗᵒʳᴵⁿᵛ, 𝒯ᴵⁿᵛ])
    @variable(m, stor_cap_remove_b[𝒩ˢᵗᵒʳᴵⁿᵛ, 𝒯ᴵⁿᵛ])
    @variable(m, stor_cap_current[𝒩ˢᵗᵒʳᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)    # Installed capacity
    @variable(m, stor_cap_add[𝒩ˢᵗᵒʳᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)        # Add capacity
    @variable(m, stor_cap_rem[𝒩ˢᵗᵒʳᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)        # Remove capacity

    @variable(m, capex_rate[𝒩ˢᵗᵒʳᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)
    @variable(m, stor_rate_invest_b[𝒩ˢᵗᵒʳᴵⁿᵛ, 𝒯ᴵⁿᵛ])
    @variable(m, stor_rate_remove_b[𝒩ˢᵗᵒʳᴵⁿᵛ, 𝒯ᴵⁿᵛ])
    @variable(m, stor_rate_current[𝒩ˢᵗᵒʳᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)   # Installed power/rate
    @variable(m, stor_rate_add[𝒩ˢᵗᵒʳᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)       # Add power
    @variable(m, stor_rate_rem[𝒩ˢᵗᵒʳᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)       # Remove power
end

"""
    EMB.constraints_capacity_installed(m, n::EMB.Node, 𝒯, modeltype::AbstractInvestmentModel

Set capacity-related constraints for nodes `𝒩` for investment time structure `𝒯`:
* bounds
* binary for BinaryInvestment
* link capacity variables

"""
function EMB.constraints_capacity_installed(m, n::EMB.Node, 𝒯::TimeStructure, modeltype::AbstractInvestmentModel)

    # Extraction of the required subsets
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    if has_investment(n)
        # Extract the investment data
        inv_data = investment_data(n)

        for (t_inv_prev, t_inv) ∈ withprev(𝒯ᴵⁿᵛ)
            # Constraints for the CAPEX calculation
            set_capacity_cost(m, n, 𝒯, t_inv, modeltype)

            # Set investment properties based on investment mode of node `n`
            set_investment_properties(n, m[:cap_invest_b][n, t_inv])

            # Link capacity usage to installed capacity
            @constraint(m, [t ∈ t_inv], m[:cap_inst][n, t] == m[:cap_current][n, t_inv])

            # Capacity updating
            @constraint(m, m[:cap_current][n, t_inv] <= max_installed(n, t_inv))
            if isnothing(t_inv_prev)
                start_cap_val = start_cap(m, n, t_inv, inv_data.cap_start, modeltype)
                @constraint(m, m[:cap_current][n, t_inv] ==
                    start_cap_val + m[:cap_add][n, t_inv])
            else
                @constraint(m, m[:cap_current][n, t_inv] ==
                    m[:cap_current][n, t_inv_prev]
                    + m[:cap_add][n, t_inv] - m[:cap_rem][n, t_inv_prev])
            end
        end
        set_capacity_installation(m, n, 𝒯ᴵⁿᵛ)

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
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    if has_investment(n)
        # Extract the investment data
        inv_data = investment_data(n)

        for (t_inv_prev, t_inv) ∈ withprev(𝒯ᴵⁿᵛ)
            # Constraints for the CAPEX calculation
            set_capacity_cost(m, n, 𝒯, t_inv, modeltype)

            # Set investment properties based on investment mode of node n
            set_investment_properties(n, m[:stor_cap_invest_b][n, t_inv])
            set_investment_properties(n, m[:stor_rate_invest_b][n, t_inv])

            # Link capacity usage to installed capacity
            @constraint(m, [t ∈ t_inv], m[:stor_cap_inst][n, t] == m[:stor_cap_current][n,t_inv])
            @constraint(m, [t ∈ t_inv], m[:stor_rate_inst][n, t] == m[:stor_rate_current][n,t_inv])

            # Capacity updating
            @constraint(m, m[:stor_cap_current][n, t_inv] <= max_installed(n, t_inv).level)
            @constraint(m, m[:stor_rate_current][n, t_inv] <= max_installed(n, t_inv).rate)
            if isnothing(t_inv_prev)
                start_cap_val = start_cap_storage(m, n, t_inv, inv_data.stor_start, modeltype)
                @constraint(m, m[:stor_cap_current][n, t_inv] ==
                    start_cap_val + m[:stor_cap_add][n, t_inv])

                start_rate_val = start_rate_storage(m, n, t_inv, inv_data.rate_start, modeltype)
                @constraint(m, m[:stor_rate_current][n, t_inv] ==
                    start_rate_val + m[:stor_rate_add][n, t_inv])
            else
                @constraint(m, m[:stor_cap_current][n, t_inv] ==
                    m[:stor_cap_current][n, t_inv_prev]
                    + m[:stor_cap_add][n, t_inv] - m[:stor_cap_rem][n, t_inv_prev])

                @constraint(m, m[:stor_rate_current][n, t_inv] ==
                    m[:stor_rate_current][n, t_inv_prev]
                    + m[:stor_rate_add][n, t_inv] - m[:stor_rate_rem][n, t_inv_prev])
            end
        end
        set_storage_installation(m, n, 𝒯ᴵⁿᵛ)
    else
        cap = capacity(n)
        @constraint(m, [t ∈ 𝒯], m[:stor_cap_inst][n, t] == cap.level[t])
        @constraint(m, [t ∈ 𝒯], m[:stor_rate_inst][n, t] == cap.rate[t])
    end
end

"""
    set_capacity_installation(m, n, 𝒯ᴵⁿᵛ)

Add constraints related to capacity installation depending on investment mode of node `n`
"""
set_capacity_installation(m, n, 𝒯ᴵⁿᵛ) = set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, investment_mode(n))
function set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, ::Investment)

    # Set the limits
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], m[:cap_add][n, t_inv] <= max_add(n, t_inv))
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], m[:cap_add][n, t_inv] >= min_add(n, t_inv))
    # This code leads to a situation in which one does not maximize early investments when using both
    # Cap_min_add and Cap_max_inst, where both result in a situation that Cap_max_inst would be violated
    # through larger investments in an early stage --> to be considered for potential soft constraints on
    # Cap_min_add and Cap_max_inst.
end

function set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, ::BinaryInvestment)
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:cap_current][n, t_inv] ==
            capacity(n, t_inv) * m[:cap_invest_b][n, t_inv]
    )
end

function set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, ::DiscreteInvestment)
    # Set the limits
    for t_inv ∈ 𝒯ᴵⁿᵛ
        set_investment_properties(n, m[:cap_remove_b][n,t_inv])
        @constraint(m, m[:cap_add][n, t_inv] ==
                            increment(n, t_inv) * m[:cap_invest_b][n, t_inv]
        )
        @constraint(m, m[:cap_rem][n, t_inv] ==
                            increment(n, t_inv) * m[:cap_remove_b][n, t_inv]
        )
    end
end

function set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, ::SemiContiInvestment)
    # Set the limits
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:cap_add][n, t_inv] <=
            max_add(n, t_inv) * m[:cap_invest_b][n, t_inv]
    )
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
            m[:cap_add][n, t_inv] >=
            min_add(n, t_inv) * m[:cap_invest_b][n, t_inv]
    )
end


function set_capacity_installation_mockup(m, n, 𝒯ᴵⁿᵛ, ::SemiContiInvestment, cap_add_name=:cap_add)
    cap_add = m[cap_add_name] # or better use :cap_add everywhere, but add variables indices where necessary (e.g. using SparseVariables)
    cap_add_b = m[join(cap_add_name, :_b)] # Or something safer, perhaps?

    # These may even be put in separate functions for reuse in other investment modes
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, cap_add[n, t_inv] <= max_add(n, t_inv) * cap_add_b[n, t_inv])
        @constraint(m, cap_add[n, t_inv] >= min_add(n, t_inv) * cap_add_b[n, t_inv])
        @constraint(m, cap_rem[n, t_inv] == 0)
    end
end



function set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, ::FixedInvestment)
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:cap_current][n, t_inv] ==
            capacity(n, t_inv) * m[:cap_invest_b][n, t_inv]
    )
end

"""
    set_storage_installation(m, n, 𝒯ᴵⁿᵛ)

Add constraints related to storage installation depending on investment mode of node `n`
"""
set_storage_installation(m, n, 𝒯ᴵⁿᵛ) = set_storage_installation(m, n, 𝒯ᴵⁿᵛ, investment_mode(n))
set_storage_installation(m, n, 𝒯ᴵⁿᵛ, investment_mode) = empty
function set_storage_installation(m, n::Storage, 𝒯ᴵⁿᵛ, investment_mode)
    # Set the limits
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], m[:stor_cap_add][n, t_inv] <= max_add(n, t_inv).level)
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], m[:stor_cap_add][n, t_inv] >= min_add(n, t_inv).level)

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], m[:stor_rate_add][n, t_inv] <= max_add(n, t_inv).rate)
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], m[:stor_rate_add][n, t_inv] >= min_add(n, t_inv).rate)
end

function set_storage_installation(m, n::Storage, 𝒯ᴵⁿᵛ, ::BinaryInvestment)
    # Extract the values
    cap = capacity(n)

    # Set the limits
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:stor_cap_current][n, t_inv] <=
            cap.level[t_inv] * m[:stor_cap_invest_b][n, t_inv]
    )

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:stor_rate_current][n, t_inv] <=
            cap.rate[t_inv] * m[:stor_rate_invest_b][n, t_inv]
    )
end

function set_storage_installation(m, n::Storage, 𝒯ᴵⁿᵛ, ::DiscreteInvestment)
    # Set the limits
    for t_inv ∈ 𝒯ᴵⁿᵛ
        set_investment_properties(n, m[:stor_cap_remove_b][n, t_inv])
        @constraint(m, m[:stor_cap_add][n, t_inv] ==
                            increment(n, t_inv).level
                            * m[:stor_cap_invest_b][n, t_inv])
        @constraint(m, m[:stor_cap_rem][n, t_inv] ==
                            increment(n, t_inv).level
                            * m[:stor_cap_remove_b][n, t_inv])

        set_investment_properties(n, m[:stor_rate_remove_b][n, t_inv])
        @constraint(m, m[:stor_rate_add][n, t_inv] ==
                            increment(n, t_inv).rate
                            * m[:stor_rate_invest_b][n, t_inv])
        @constraint(m, m[:stor_rate_rem][n, t_inv] ==
                            increment(n, t_inv).rate
                            * m[:stor_rate_remove_b][n, t_inv])
    end
end

function set_storage_installation(m, n::Storage, 𝒯ᴵⁿᵛ, ::SemiContiInvestment)
    # Set the limits
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:stor_cap_add][n, t_inv] <=
            max_add(n, t_inv).level * m[:stor_cap_invest_b][n, t_inv]
    )
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:stor_cap_add][n, t_inv] >=
            min_add(n, t_inv).level * m[:stor_cap_invest_b][n, t_inv]
    )

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:stor_rate_add][n, t_inv] <=
            max_add(n, t_inv).rate * m[:stor_rate_invest_b][n, t_inv]
    )
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:stor_rate_add][n, t_inv] >=
            min_add(n, t_inv).rate * m[:stor_rate_invest_b][n, t_inv]
    )
end

function set_storage_installation(m, n::Storage, 𝒯ᴵⁿᵛ, ::FixedInvestment)
    # Extract the values
    cap = capacity(n)

    # Set the limits
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:stor_cap_current][n, t_inv] ==
            cap.level[t_inv] * m[:stor_cap_invest_b][n, t_inv]
    )

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:stor_rate_current][n, t_inv] ==
            cap.rate[t_inv] * m[:stor_rate_invest_b][n, t_inv]
    )
end

"""
    set_investment_properties(n, var)

Set investment properties for variable `var` for type `n`, e.g., set to binary for
`BinaryInvestment`, bounds, etc.
"""
set_investment_properties(n, var) =
    set_investment_properties(var, investment_mode(n))
function set_investment_properties(var, ::Investment)
    JuMP.set_lower_bound(var, 0)
end

function set_investment_properties(var, ::BinaryInvestment)
    JuMP.set_binary(var)
end

function set_investment_properties(var, ::SemiContiInvestment)
    JuMP.set_binary(var)
end

function set_investment_properties(var, ::FixedInvestment) # TO DO
    JuMP.fix(var, 1)
end

function set_investment_properties(var, ::DiscreteInvestment) # TO DO
    JuMP.set_integer(var)
    JuMP.set_lower_bound(var,0)
end

"""
    set_capacity_cost(m, n, 𝒯, t_inv, modeltype)
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
set_capacity_cost(m, n, 𝒯, t_inv, modeltype) = set_capacity_cost(m, n, 𝒯, t_inv, modeltype, lifetime_mode(n))
function set_capacity_cost(m, n, 𝒯, t_inv,  modeltype::EnergyModel, ::UnlimitedLife)
    # The capacity has an unlimited lifetime, one investment at the beginning of t_inv
    @constraint(m, m[:capex_cap][n, t_inv] == capex(n, t_inv) * m[:cap_add][n, t_inv])
    @constraint(m, m[:cap_rem][n, t_inv] == 0)
end

function set_capacity_cost(m, n, 𝒯, t_inv, modeltype::EnergyModel, ::StudyLife)
    # The capacity is limited to the end of the study. Reinvestments are included
    # No capacity removed as there are reinvestments according to the study length
    capex_val = capex(n, t_inv) * set_capex_value(remaining(t_inv, 𝒯), lifetime(n, t_inv), discount_rate(modeltype))
    @constraint(m, m[:capex_cap][n, t_inv] == capex_val * m[:cap_add][n, t_inv])
    @constraint(m, m[:cap_rem][n, t_inv] == 0)
end

function set_capacity_cost(m, n, 𝒯, t_inv,  modeltype::EnergyModel, ::PeriodLife)
    # The capacity is limited to the current sp. It has to be removed in the next sp.
    # The formula for capacity updating uses the cap_rem for the previous sp, hence the sps used here.
    capex_val = capex(n, t_inv) * set_capex_value(duration(t_inv), lifetime(n, t_inv), discount_rate(modeltype))
    @constraint(m, m[:capex_cap][n, t_inv] == capex_val * m[:cap_add][n, t_inv])
    @constraint(m, m[:cap_rem][n, t_inv] == m[:cap_add][n, t_inv])
end

function set_capacity_cost(m, n, 𝒯, t_inv,  modeltype::EnergyModel, ::RollingLife)
    lifetime_val = lifetime(n, t_inv)
    r = discount_rate(modeltype)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

     # If lifetime is shorter than the sp duration, we apply the method for PeriodLife
    if lifetime_val < duration(t_inv)
        set_capacity_cost(m, n, 𝒯, t_inv, modeltype, PeriodLife())

    # If lifetime is equal to sp duration we only need to invest once and there is no rest value
    elseif lifetime_val == duration(t_inv)
        capex_val = capex(n, t_inv)
        @constraint(m, m[:capex_cap][n, t_inv] == capex_val * m[:cap_add][n, t_inv])
        @constraint(m, m[:cap_rem][n, t_inv] == m[:cap_add][n, t_inv] )

    # If lifetime is longer than sp duration, the capacity can roll over to the next sp.
    elseif lifetime_val > duration(t_inv)
        # Initialization of the ante_sp and the remaining lifetime
        # ante_sp represents the last sp in which the remaining lifetime is  sufficient
        # to cover the whole sp duration.
        ante_sp = t_inv
        remaining_lifetime = lifetime_val

        # Iteration to identify sp in which remaining_lifetime is smaller than sp duration
        for sp ∈ 𝒯ᴵⁿᵛ
            if sp >= t_inv
                if remaining_lifetime < duration(sp)
                    break
                end
                remaining_lifetime -= duration(sp)
                ante_sp = sp
            end
        end

        # Calculation of cost and rest value
        capex_val = capex(n, t_inv) *
                (1 - (remaining_lifetime/lifetime_val) * (1+r)^(-(lifetime_val - remaining_lifetime)))
        @constraint(m, m[:capex_cap][n, t_inv] == capex_val * m[:cap_add][n, t_inv])

        # Capacity to be removed when remaining_lifetime < duration_years, i.e., in ante_sp
        if ante_sp.sp < length(𝒯ᴵⁿᵛ)
            @constraint(m, m[:cap_rem][n, ante_sp] == m[:cap_add][n, t_inv])
        end
    end
end

#same function dispatched for storages
function set_capacity_cost(m, n::Storage, 𝒯, t_inv,  modeltype::EnergyModel, ::UnlimitedLife)
    # The capacity has an unlimited lifetime, one investment at the beginning of t_inv
    capex_val = capex(n, t_inv)
    @constraint(m, m[:capex_stor][n, t_inv] == capex_val.level * m[:stor_cap_add][n, t_inv])
    @constraint(m, m[:capex_rate][n, t_inv] == capex_val.rate * m[:stor_rate_add][n, t_inv])
    @constraint(m, m[:stor_cap_rem][n, t_inv] == 0)
    @constraint(m, m[:stor_rate_rem][n, t_inv] == 0)
end

function set_capacity_cost(m, n::Storage, 𝒯, t_inv,  modeltype::EnergyModel, ::StudyLife)
    # The capacity is limited to the end of the study. Reinvestments are included
    # No capacity removed as there are reinvestments according to the study length
    capex_val = capex(n, t_inv)
    stor_capex = capex_val.level * set_capex_value(remaining(t_inv, 𝒯), lifetime(n, t_inv), discount_rate(modeltype))
    rate_capex = capex_val.rate * set_capex_value(remaining(t_inv, 𝒯), lifetime(n, t_inv), discount_rate(modeltype))
    @constraint(m, m[:capex_stor][n, t_inv] == stor_capex * m[:stor_cap_add][n, t_inv])
    @constraint(m, m[:capex_rate][n, t_inv] == rate_capex * m[:stor_rate_add][n, t_inv])
    @constraint(m, m[:stor_cap_rem][n, t_inv] == 0)
    @constraint(m, m[:stor_rate_rem][n, t_inv] == 0)
end

function set_capacity_cost(m, n::Storage, 𝒯, t_inv,  modeltype::EnergyModel, ::PeriodLife)
    # The capacity is limited to the current sp. It has to be removed in the next sp.
    # The formula for capacity updating uses the cap_rem for the previous sp, hence the sps used here.
    capex_val = capex(n, t_inv)
    stor_capex = capex_val.level * set_capex_value(duration(t_inv), lifetime(n, t_inv), discount_rate(modeltype))
    rate_capex = capex_val.rate * set_capex_value(duration(t_inv), lifetime(n, t_inv), discount_rate(modeltype))
    @constraint(m, m[:capex_stor][n, t_inv] == stor_capex * m[:stor_cap_add][n, t_inv])
    @constraint(m, m[:capex_rate][n, t_inv] == rate_capex * m[:stor_rate_add][n, t_inv])
    @constraint(m, m[:stor_cap_rem][n, t_inv] == m[:stor_cap_add][n, t_inv] )
    @constraint(m, m[:stor_rate_rem][n, t_inv] == m[:stor_rate_add][n, t_inv] )
end

function set_capacity_cost(m, n::Storage, 𝒯, t_inv,  modeltype::EnergyModel, ::RollingLife)
    capex_val = capex(n, t_inv)
    lifetime_val = lifetime(n, t_inv)
    r = discount_rate(modeltype)                    # discount rate
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # If lifetime is shorer than the sp duration , we apply the method for PeriodLife
    if lifetime_val < duration(t_inv)
        set_capacity_cost(m, n, 𝒯, t_inv, modeltype, PeriodLife())

    # If lifetime is equal to sp duration we only need to invest once and there is no rest value
    elseif lifetime_val == duration(t_inv)
        stor_capex = capex_val.level
        rate_capex = capex_val.rate
        @constraint(m, m[:capex_stor][n, t_inv] == stor_capex * m[:stor_cap_add][n, t_inv])
        @constraint(m, m[:capex_rate][n, t_inv] == rate_capex * m[:stor_rate_add][n, t_inv])
        @constraint(m, m[:stor_cap_rem][n, t_inv] == m[:stor_cap_add][n, t_inv])
        @constraint(m, m[:stor_rate_rem][n, t_inv] == m[:stor_rate_add][n, t_inv])

    # If lifetime is longer than sp duration, the capacity can roll over to the next sp.
    elseif lifetime_val > duration(t_inv)
        # Initialization of the ante_sp and the remaining lifetime
        # ante_sp represents the last sp in which the remaining lifetime is sufficient
        # to cover the whole sp duration.
        ante_sp = t_inv
        remaining_lifetime = lifetime_val

        # Iteration to identify sp in which remaining_lifetime is smaller than sp duration
        for sp ∈ 𝒯ᴵⁿᵛ
            if sp >= t_inv
                if remaining_lifetime < duration(sp)
                    break
                end
                remaining_lifetime -= duration(sp)
                ante_sp = sp
            end
        end

        # Calculation of cost and rest value
        stor_capex = capex_val.level *
                    (1 - (remaining_lifetime/lifetime_val) * (1+r)^(-(lifetime_val - remaining_lifetime)))
        rate_capex = capex_val.rate *
                    (1 - (remaining_lifetime/lifetime_val) * (1+r)^(-(lifetime_val - remaining_lifetime)))
        @constraint(m, m[:capex_stor][n, t_inv] == stor_capex * m[:stor_cap_add][n, t_inv])
        @constraint(m, m[:capex_rate][n, t_inv] == rate_capex * m[:stor_rate_add][n, t_inv])

        # Capacity to be removed when remaining_lifetime < duration_years, i.e., in ante_sp
        if ante_sp.sp < length(𝒯ᴵⁿᵛ)
            @constraint(m, m[:stor_cap_rem][n, ante_sp] == m[:stor_cap_add][n, t_inv])
            @constraint(m, m[:stor_rate_rem][n, ante_sp] == m[:stor_rate_add][n, t_inv])
        end
    end
end
