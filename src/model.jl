"""
    EMB.objective(m, 𝒩, 𝒯, modeltype::InvestmentModel)

Create objective function overloading the default from EMB for InvestmentModel.

Maximize Net Present Value from revenues, investments (CAPEX) and operations (OPEX) 

## TODO: 
# * consider passing expression around for updating
# * consider reading objective and adding terms/coefficients (from model object `m`)

"""
function EMB.objective(m, 𝒩, 𝒯, 𝒫, modeltype::InvestmentModel)#, sense=Max)

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    𝒩ᶜᵃᵖ = EMB.node_not_av(𝒩)                       # Nodes with capacity
    𝒩ˢᵗᵒʳ = EMB.node_sub(𝒩, Storage)                # Storage nodes
    𝒩ˢᵗᵒʳᴵⁿᵛ = has_investment(𝒩ˢᵗᵒʳ)                # Storage nodes with investments
    𝒩ᴵⁿᵛ = setdiff(has_investment(𝒩), 𝒩ˢᵗᵒʳᴵⁿᵛ)     # Other nodes with investments
    𝒫ᵉᵐ  = EMB.res_sub(𝒫, ResourceEmit)             # Emissions resources
    r = modeltype.r                                 # Discount rate
    
    capexunit = 1 # TODO: Fix scaling if operational units are different form CAPEX

    obj = JuMP.AffExpr()
    haskey(m, :revenue)     && (obj += sum(obj_weight(r, 𝒯, t_inv, t) * m[:revenue][i, t] / capexunit for i ∈ 𝒩ᶜᵃᵖ, t_inv ∈ 𝒯ᴵⁿᵛ, t ∈ 𝒯))
    haskey(m, :opex_var)    && (obj -= sum(obj_weight_inv(r, 𝒯, t_inv) * m[:opex_var][i, t_inv] * t_inv.duration  for i ∈ 𝒩ᶜᵃᵖ, t_inv ∈  𝒯ᴵⁿᵛ))
    haskey(m, :opex_fixed)  && (obj -= sum(obj_weight_inv(r, 𝒯, t_inv) * m[:opex_fixed][i, t_inv] * t_inv.duration  for i ∈ 𝒩ᶜᵃᵖ, t_inv ∈  𝒯ᴵⁿᵛ))
    haskey(m, :capex_cap)   && !isempty(𝒩ᴵⁿᵛ) && (obj -= sum(obj_weight_inv(r, 𝒯, t_inv) * m[:capex_cap][i, t_inv]  for i ∈ 𝒩ᴵⁿᵛ, t_inv ∈  𝒯ᴵⁿᵛ))
    if haskey(m, :capex_stor) && !isempty(𝒩ˢᵗᵒʳᴵⁿᵛ)
        obj -= sum(obj_weight_inv(r, 𝒯, t_inv) * m[:capex_stor][i, t_inv]  for i ∈ 𝒩ˢᵗᵒʳᴵⁿᵛ, t_inv ∈  𝒯ᴵⁿᵛ) #capex of the capacity part ofthe storage (by opposition to the power part)
        obj -= sum(obj_weight_inv(r, 𝒯, t_inv) * m[:capex_rate][i, t_inv]  for i ∈ 𝒩ˢᵗᵒʳᴵⁿᵛ, t_inv ∈  𝒯ᴵⁿᵛ) #capex of the capacity part ofthe storage (by opposition to the power part)
    end

    em_price = modeltype.Emission_price
    obj -= sum(obj_weight_inv(r, 𝒯, t_inv) * m[:emissions_strategic][t_inv, p_em] * em_price[p_em][t_inv] for p_em ∈ 𝒫ᵉᵐ, t_inv ∈ 𝒯ᴵⁿᵛ)
    
    # TODO: Maintentance cost

    @objective(m, Max, obj)
end


"""
    EMB.variables_capex(m, 𝒩, 𝒯, 𝒫, modeltype::InvestmentModel)

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
function EMB.variables_capex(m, 𝒩, 𝒯, 𝒫, modeltype::InvestmentModel)
    
    𝒩ˢᵗᵒʳ = EMB.node_sub(𝒩, Storage)
    𝒩ˢᵗᵒʳᴵⁿᵛ = has_investment(𝒩ˢᵗᵒʳ)
    𝒩ᴵⁿᵛ = setdiff(has_investment(𝒩), 𝒩ˢᵗᵒʳᴵⁿᵛ)

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
    EMB.constraints_capacity_installed(m, n::EMB.Node, 𝒯, modeltype::InvestmentModel

Set capacity-related constraints for nodes `𝒩` for investment time structure `𝒯`:
* bounds
* binary for BinaryInvestment
* link capacity variables

"""
function EMB.constraints_capacity_installed(m, n::EMB.Node, 𝒯::TimeStructure, modeltype::InvestmentModel)

    # Extraction of the required subsets
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    if has_investment(n)
        for t_inv ∈ 𝒯ᴵⁿᵛ
            # Extract the investment data
            inv_data = investment_data(n)
            
            # Constraints for the CAPEX calculation
            set_capacity_cost(m, n, 𝒯, t_inv, modeltype)

            # Set investment properties based on investment mode of node `n`
            set_investment_properties(n, m[:cap_invest_b][n, t_inv])  
            
            # Link capacity usage to installed capacity 
            @constraint(m, [t ∈ t_inv], m[:cap_inst][n, t] == m[:cap_current][n, t_inv])

            # Capacity updating
            @constraint(m, m[:cap_current][n, t_inv] <=
                                inv_data.Cap_max_inst[t_inv])
            if TS.isfirst(t_inv)
                start_cap = get_start_cap(n,t_inv, inv_data.Cap_start)
                @constraint(m, m[:cap_current][n, t_inv] ==
                    start_cap + m[:cap_add][n, t_inv])
            else
                @constraint(m, m[:cap_current][n, t_inv] ==
                    m[:cap_current][n, previous(t_inv,𝒯)]
                    + m[:cap_add][n, t_inv] - m[:cap_rem][n, previous(t_inv,𝒯)])
            end
        end
        set_capacity_installation(m, n, 𝒯ᴵⁿᵛ)

    else
        @constraint(m, [t ∈ 𝒯], m[:cap_inst][n, t] == n.Cap[t])
    end
end

"""
    constraints_capacity_installed(m, n::Storage, 𝒯::TimeStructure, modeltype::InvestmentModel)
Set storage-related constraints for nodes `𝒩ˢᵗᵒʳ` for investment time structure `𝒯`:
* bounds
* binary for BinaryInvestment
* link storage variables

"""
function EMB.constraints_capacity_installed(m, n::Storage, 𝒯::TimeStructure, modeltype::InvestmentModel)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    if has_investment(n)
        for t_inv ∈ 𝒯ᴵⁿᵛ
            # Extract the investment data
            inv_data = investment_data(n)
            
            # Constraints for the CAPEX calculation
            set_capacity_cost(m, n, 𝒯, t_inv, modeltype)

            # Set investment properties based on investment mode of node n
            set_investment_properties(n, m[:stor_cap_invest_b][n, t_inv])
            set_investment_properties(n, m[:stor_rate_invest_b][n, t_inv])

            # Link capacity usage to installed capacity
            @constraint(m, [t ∈ t_inv], m[:stor_cap_inst][n, t] == m[:stor_cap_current][n,t_inv])
            @constraint(m, [t ∈ t_inv], m[:stor_rate_inst][n, t] == m[:stor_rate_current][n,t_inv])

            # Capacity updating
            @constraint(m, m[:stor_cap_current][n, t_inv] <=
                                inv_data.Stor_max_inst[t_inv])
            @constraint(m, m[:stor_rate_current][n, t_inv] <=
                                inv_data.Rate_max_inst[t_inv])
            if TS.isfirst(t_inv)
                start_cap = get_start_cap_storage(n, t_inv, inv_data.Stor_start)
                @constraint(m, m[:stor_cap_current][n, t_inv] == 
                    start_cap + m[:stor_cap_add][n, t_inv])

                start_rate = get_start_rate_storage(n, t_inv, inv_data.Rate_start)
                @constraint(m, m[:stor_rate_current][n, t_inv] == 
                    start_rate + m[:stor_rate_add][n, t_inv])
            else
                @constraint(m, m[:stor_cap_current][n, t_inv] == 
                    m[:stor_cap_current][n, previous(t_inv,𝒯)]
                    + m[:stor_cap_add][n, t_inv] - m[:stor_cap_rem][n, previous(t_inv,𝒯)])

                @constraint(m, m[:stor_rate_current][n, t_inv] == 
                    m[:stor_rate_current][n, previous(t_inv,𝒯)]
                    + m[:stor_rate_add][n, t_inv] - m[:stor_rate_rem][n, previous(t_inv,𝒯)])
            end
        end
        set_storage_installation(m, n, 𝒯ᴵⁿᵛ)
    else
        @constraint(m, [t ∈ 𝒯], m[:stor_cap_inst][n, t] == n.Stor_cap[t])
        @constraint(m, [t ∈ 𝒯], m[:stor_rate_inst][n, t] == n.Rate_cap[t])
    end
end

"""
    set_capacity_installation(m, n, 𝒯ᴵⁿᵛ)

Add constraints related to capacity installation depending on investment mode of node `n`
"""
set_capacity_installation(m, n, 𝒯ᴵⁿᵛ) = set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, investment_mode(n))
function set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, ::Investment)
    # Extract the investment data
    inv_data = investment_data(n)

    # Set the limits
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:cap_add][n, t_inv] <=
                            inv_data.Cap_max_add[t_inv])
        @constraint(m, m[:cap_add][n, t_inv] >=
                            inv_data.Cap_min_add[t_inv])
        # This code leads to a situation in which one does not maximize early investments when using both
        # Cap_min_add and Cap_max_inst, where both result in a situation that Cap_max_inst would be violated
        # through larger investments in an early stage --> to be considered for potential soft constraints on
        # Cap_min_add and Cap_max_inst.
    end
end

function set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, ::BinaryInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:cap_current][n, t_inv] == n.Cap[t_inv] * m[:cap_invest_b][n, t_inv]) 
    end
end

function set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, ::DiscreteInvestment)
    # Extract the investment data
    inv_data = investment_data(n)

    # Set the limits
    for t_inv ∈ 𝒯ᴵⁿᵛ
        set_investment_properties(n, m[:cap_remove_b][n,t_inv])
        @constraint(m, m[:cap_add][n, t_inv] == 
                            inv_data.Cap_increment[t_inv]
                            * m[:cap_invest_b][n, t_inv])
        @constraint(m, m[:cap_rem][n, t_inv] ==
                            inv_data.Cap_increment[t_inv]
                            * m[:cap_remove_b][n, t_inv])
    end
end

function set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, ::SemiContiInvestment)
    # Extract the investment data
    inv_data = investment_data(n)

    # Set the limits
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:cap_add][n, t_inv] <=
                            inv_data.Cap_max_add[t_inv]
                            * m[:cap_invest_b][n, t_inv]) 
        @constraint(m, m[:cap_add][n, t_inv] >=
                            inv_data.Cap_min_add[t_inv]
                            * m[:cap_invest_b][n, t_inv]) 
        #@constraint(m, m[:cap_rem][n, t_inv] == 0)
    end
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
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:cap_current][n, t_inv] ==
                            n.Cap[t_inv] * m[:cap_invest_b][n, t_inv])
    end
end

"""
    set_storage_installation(m, n, 𝒯ᴵⁿᵛ)

Add constraints related to storage installation depending on investment mode of node `n`
"""
set_storage_installation(m, n, 𝒯ᴵⁿᵛ) = set_storage_installation(m, n, 𝒯ᴵⁿᵛ, investment_mode(n))
set_storage_installation(m, n, 𝒯ᴵⁿᵛ, investment_mode) = empty
function set_storage_installation(m, n::Storage, 𝒯ᴵⁿᵛ, investment_mode)
    # Extract the investment data
    inv_data = investment_data(n)

    # Set the limits
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:stor_cap_add][n, t_inv] <=
                            inv_data.Stor_max_add[t_inv])
        @constraint(m, m[:stor_cap_add][n, t_inv] >=
                            inv_data.Stor_min_add[t_inv])

        @constraint(m, m[:stor_rate_add][n, t_inv] <=
                            inv_data.Rate_max_add[t_inv])
        @constraint(m, m[:stor_rate_add][n, t_inv] >=
                            inv_data.Rate_min_add[t_inv])
    end
end

function set_storage_installation(m, n::Storage, 𝒯ᴵⁿᵛ, ::BinaryInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:stor_cap_current][n, t_inv] <= 
                            n.Stor_cap[t_inv] * m[:stor_cap_invest_b][n, t_inv])

        @constraint(m, m[:stor_rate_current][n, t_inv] <= 
                            n.Rate_cap[t_inv] * m[:stor_rate_invest_b][n, t_inv])
    end
end

function set_storage_installation(m, n, 𝒯ᴵⁿᵛ, ::DiscreteInvestment)
    # Extract the investment data
    inv_data = investment_data(n)

    # Set the limits
    for t_inv ∈ 𝒯ᴵⁿᵛ
        set_investment_properties(n, m[:stor_cap_remove_b][n, t_inv])
        @constraint(m, m[:stor_cap_add][n, t_inv] ==
                            inv_data.Stor_increment[t_inv]
                            * m[:stor_cap_invest_b][n, t_inv])
        @constraint(m, m[:stor_cap_rem][n, t_inv] ==
                            inv_data.Stor_increment[t_inv]
                            * m[:stor_cap_remove_b][n, t_inv])

        set_investment_properties(n, m[:stor_rate_remove_b][n, t_inv])
        @constraint(m, m[:stor_rate_add][n, t_inv] ==
                            inv_data.Rate_increment[t_inv]
                            * m[:stor_rate_invest_b][n, t_inv])
        @constraint(m, m[:stor_rate_rem][n, t_inv] ==
                            inv_data.Rate_increment[t_inv]
                            * m[:stor_rate_remove_b][n, t_inv])
    end
end

function set_storage_installation(m, n::Storage, 𝒯ᴵⁿᵛ, ::SemiContiInvestment)
    # Extract the investment data
    inv_data = investment_data(n)

    # Set the limits
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:stor_cap_add][n, t_inv] <= 
                            inv_data.Stor_max_add[t_inv]
                            * m[:stor_cap_invest_b][n, t_inv]) 
        @constraint(m, m[:stor_cap_add][n, t_inv] >=
                            inv_data.Stor_min_add[t_inv]
                            * m[:stor_cap_invest_b][n, t_inv]) 

        @constraint(m, m[:stor_rate_add][n, t_inv] <=
                            inv_data.Rate_max_add[t_inv]
                            * m[:stor_rate_invest_b][n, t_inv]) 
        @constraint(m, m[:stor_rate_add][n, t_inv] >=
                            inv_data.Rate_min_add[t_inv]
                            * m[:stor_rate_invest_b][n, t_inv]) 
    end
end

function set_storage_installation(m, n::Storage, 𝒯ᴵⁿᵛ, ::FixedInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:stor_cap_current][n, t_inv] == 
                            n.Stor_cap * m[:stor_cap_invest_b][n, t_inv])

        @constraint(m, m[:stor_rate_current][n, t_inv] ==
                            n.Rate_cap * m[:stor_rate_invest_b][n, t_inv])
    end
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
- UnlimitedLife:    The investment life is not limited. The investment costs do not consider any reinvestment or rest value.
- StudyLife:        The investment last for the whole study period with adequate reinvestments at end of lifetime and rest value.
- PeriodLife:       The investment is considered to last only for the strategic period. The excess lifetime is considered in the rest value.
- RollingLife:      The investment is rolling to the next strategic periods and it is retired at the end of its lifetime or the end 
                    of the previous sp if its lifetime ends between two sp.
"""
set_capacity_cost(m, n, 𝒯, t_inv, modeltype) = set_capacity_cost(m, n, 𝒯, t_inv, modeltype, lifetime_mode(n))
function set_capacity_cost(m, n, 𝒯, t_inv,  modeltype::EnergyModel, ::UnlimitedLife)
    # The capacity has an unlimited lifetime, one investment at the beginning of t_inv
    data = investment_data(n)
    @constraint(m, m[:capex_cap][n, t_inv] == data.Capex_cap[t_inv] * m[:cap_add][n, t_inv])
    @constraint(m, m[:cap_rem][n, t_inv] == 0)
end

function set_capacity_cost(m, n, 𝒯, t_inv, modeltype::EnergyModel, ::StudyLife)
    # The capacity is limited to the end of the study. Reinvestments are included
    # No capacity removed as there are reinvestments according to the study length
    data = investment_data(n)
    capex = data.Capex_cap[t_inv] * set_capex_value(TS.remaining_years(𝒯, t_inv), data.Lifetime[t_inv], modeltype.r)
    @constraint(m, m[:capex_cap][n, t_inv] == capex * m[:cap_add][n, t_inv])
    @constraint(m, m[:cap_rem][n, t_inv] == 0)
end

function set_capacity_cost(m, n, 𝒯, t_inv,  modeltype::EnergyModel, ::PeriodLife)
    # The capacity is limited to the current sp. It has to be removed in the next sp.
    # The formula for capacity updating uses the cap_rem for the previous sp, hence the sps used here.
    data = investment_data(n)
    capex = data.Capex_cap[t_inv] * set_capex_value(TS.duration_years(𝒯, t_inv), data.Lifetime[t_inv], modeltype.r)
    @constraint(m, m[:capex_cap][n, t_inv] == capex * m[:cap_add][n, t_inv])
    @constraint(m, m[:cap_rem][n, t_inv] == m[:cap_add][n, t_inv] )
end

function set_capacity_cost(m, n, 𝒯, t_inv,  modeltype::EnergyModel, ::RollingLife)
    data = investment_data(n)
    Lifetime = data.Lifetime[t_inv]
    r = modeltype.r                     # discount rate

     # If Lifetime is shorer than the sp duration , we apply the method for PeriodLife
    if Lifetime < TS.duration_years(𝒯, t_inv)
        set_capacity_cost(m, n, 𝒯, t_inv, modeltype, PeriodLife())

    # If Lifetime is equal to sp duration we only need to invest once and there is no rest value
    elseif Lifetime == TS.duration_years(𝒯, t_inv)
        capex = data.Capex_cap[t_inv]
        @constraint(m, m[:capex_cap][n, t_inv] == capex * m[:cap_add][n, t_inv])
        @constraint(m, m[:cap_rem][n, t_inv] == m[:cap_add][n, t_inv] )

    # If Lifetime is longer than sp duration, the capacity can roll over to the next sp.
    elseif Lifetime > TS.duration_years(𝒯, t_inv)
        # Initialization of the last_sp, ante_sp (the sp before), and the remaining lifetime
        # last_sp represents the sp in which the remaining Lifetime is not sufficient to cover the whole sp duration.
        last_sp = t_inv
        ante_sp = nothing
        remaining_lifetime = Lifetime

        # Iteration to identify sp in which remaining_lifetime is smaller than sp duration
        while remaining_lifetime >= TS.duration_years(𝒯, last_sp)
            remaining_lifetime -= TS.duration_years(𝒯, last_sp)
            ante_sp = last_sp
            last_sp = TS.next(last_sp, 𝒯)
            # If last_sp beyond the number of sps in the model, we stop the loop
            if last_sp.sp > t_inv.sps
                break
            end
        end

        # Calculation of cost and rest value
        capex = data.Capex_cap[t_inv] - ((remaining_lifetime/Lifetime) * data.Capex_cap[t_inv] * (1+r)^(-(Lifetime - remaining_lifetime)))
        @constraint(m, m[:capex_cap][n,t_inv] == capex * m[:cap_add][n, t_inv])

        # Capacity to be removed when remaining_lifetime < duration_years, i.e., in ante_sp
        if ante_sp.sp < t_inv.sps
            @constraint(m, m[:cap_rem][n, ante_sp] == m[:cap_add][n, t_inv])
        end
    end
end

#same function dispatched for storages
function set_capacity_cost(m, n::Storage, 𝒯, t_inv,  modeltype::EnergyModel, ::UnlimitedLife)
    # The capacity has an unlimited lifetime, one investment at the beginning of t_inv
    data = investment_data(n)
    @constraint(m, m[:capex_stor][n, t_inv] == data.Capex_stor[t_inv] * m[:stor_cap_add][n, t_inv])
    @constraint(m, m[:capex_rate][n, t_inv] == data.Capex_rate[t_inv] * m[:stor_rate_add][n, t_inv])
    @constraint(m, m[:stor_cap_rem][n, t_inv] == 0)
    @constraint(m, m[:stor_rate_rem][n, t_inv] == 0)
end

function set_capacity_cost(m, n::Storage, 𝒯, t_inv,  modeltype::EnergyModel, ::StudyLife)
    # The capacity is limited to the end of the study. Reinvestments are included
    # No capacity removed as there are reinvestments according to the study length
    data = investment_data(n)
    stor_capex = data.Capex_stor[t_inv] * set_capex_value(TS.remaining_years(𝒯, t_inv), data.Lifetime[t_inv], modeltype.r)
    rate_capex = data.Capex_rate[t_inv] * set_capex_value(TS.remaining_years(𝒯, t_inv), data.Lifetime[t_inv], modeltype.r)
    @constraint(m, m[:capex_stor][n, t_inv] == stor_capex * m[:stor_cap_add][n, t_inv])
    @constraint(m, m[:capex_rate][n, t_inv] == rate_capex * m[:stor_rate_add][n, t_inv])
    @constraint(m, m[:stor_cap_rem][n, t_inv] == 0)
    @constraint(m, m[:stor_rate_rem][n, t_inv] == 0)
end

function set_capacity_cost(m, n::Storage, 𝒯, t_inv,  modeltype::EnergyModel, ::PeriodLife)
    # The capacity is limited to the current sp. It has to be removed in the next sp.
    # The formula for capacity updating uses the cap_rem for the previous sp, hence the sps used here.
    data = investment_data(n)
    stor_capex = data.Capex_stor[t_inv] * set_capex_value(TS.duration_years(𝒯, t_inv), data.Lifetime[t_inv], modeltype.r)
    rate_capex = data.Capex_rate[t_inv] * set_capex_value(TS.duration_years(𝒯, t_inv), data.Lifetime[t_inv], modeltype.r)
    @constraint(m, m[:capex_stor][n, t_inv] == stor_capex * m[:stor_cap_add][n, t_inv])
    @constraint(m, m[:capex_rate][n, t_inv] == rate_capex * m[:stor_rate_add][n, t_inv])
    @constraint(m, m[:stor_cap_rem][n, t_inv] == m[:stor_cap_add][n, t_inv] )
    @constraint(m, m[:stor_rate_rem][n, t_inv] == m[:stor_rate_add][n, t_inv] )
end

function set_capacity_cost(m, n::Storage, 𝒯, t_inv,  modeltype::EnergyModel, ::RollingLife)
    data = investment_data(n)
    Lifetime = data.Lifetime[t_inv]
    r = modeltype.r                     # discount rate
    
    # If Lifetime is shorer than the sp duration , we apply the method for PeriodLife
    if Lifetime < TS.duration_years(𝒯, t_inv)
        set_capacity_cost(m, n, 𝒯, t_inv, modeltype, PeriodLife())
        
    # If Lifetime is equal to sp duration we only need to invest once and there is no rest value
    elseif Lifetime == TS.duration_years(𝒯, t_inv)
        stor_capex = data.Capex_stor[t_inv]
        rate_capex = data.Capex_rate[t_inv]
        @constraint(m, m[:capex_stor][n, t_inv] == stor_capex * m[:stor_cap_add][n, t_inv])
        @constraint(m, m[:capex_rate][n, t_inv] == rate_capex * m[:stor_rate_add][n, t_inv])
        @constraint(m, m[:stor_cap_rem][n, t_inv] == m[:stor_cap_add][n, t_inv])
        @constraint(m, m[:stor_rate_rem][n, t_inv] == m[:stor_rate_add][n, t_inv])

    # If Lifetime is longer than sp duration, the capacity can roll over to the next sp.
    elseif Lifetime > TS.duration_years(𝒯, t_inv)
        # Initialization of the last_sp, ante_sp (the sp before), and the remaining lifetime
        # last_sp represents the sp in which the remaining Lifetime is not sufficient to cover the whole sp duration.
        last_sp = t_inv
        ante_sp = nothing
        remaining_lifetime = Lifetime

        # Iteration to identify sp in which remaining_lifetime is smaller than sp duration
        while remaining_lifetime >= TS.duration_years(𝒯, last_sp) 
            remaining_lifetime -= TS.duration_years(𝒯, last_sp)
            ante_sp = last_sp #register the sp before the last sp
            last_sp = TS.next(last_sp, 𝒯)
            if last_sp.sp > t_inv.sps #if last_sp is beyond the sps in the model, we stop the loop
                break
            end
        end

        # Calculation of cost and rest value
        stor_capex = data.Capex_stor[t_inv] - ((remaining_lifetime/Lifetime) * data.Capex_stor[t_inv] * (1+r)^(-(Lifetime - remaining_lifetime)))
        rate_capex = data.Capex_rate[t_inv] - ((remaining_lifetime/Lifetime) * data.Capex_rate[t_inv] * (1+r)^(-(Lifetime - remaining_lifetime)))
        @constraint(m, m[:capex_stor][n, t_inv] == stor_capex * m[:stor_cap_add][n, t_inv])
        @constraint(m, m[:capex_rate][n, t_inv] == rate_capex * m[:stor_rate_add][n, t_inv])

        # Capacity to be removed when remaining_lifetime < duration_years, i.e., in ante_sp
        if ante_sp.sp < t_inv.sps
            @constraint(m, m[:stor_cap_rem][n, ante_sp] == m[:stor_cap_add][n, t_inv])
            @constraint(m, m[:stor_rate_rem][n, ante_sp] == m[:stor_rate_add][n, t_inv])
        end
    end
end

    
"""
    set_capex_value(years, Capex, Lifetime, r)
Calculate the discounted values used in the lifetime calculations.
The input to the function is given as:
    years       Either TS.remaining_years(𝒯, t_inv) for Stud_inv or
                TS.duration_years(𝒯, t_inv) for  Period_inv
                the calculation of required investments
    Lifetime    Lifetime of the node
    r           Discount rate
"""
function set_capex_value(years, Lifetime, r)
    N_inv = ceil(years/Lifetime)
    capex_disc = sum((1+r)^(-n_inv * Lifetime) for n_inv ∈ 0:N_inv-1) - 
                 ((N_inv * Lifetime - years)/Lifetime) * (1+r)^(-years)
    return capex_disc
end