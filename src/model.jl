"""
    EMB.objective(m, 𝒩, 𝒯, modeltype::InvestmentModel)

Create objective function overloading the default from EMB for InvestmentModel.

Maximize Net Present Value from revenues, investments (CAPEX) and operations (OPEX) 

## TODO: 
# * consider passing expression around for updating
# * consider reading objective and adding terms/coefficients (from model object `m`)

"""
function EMB.objective(m, 𝒩, 𝒯, 𝒫, global_data, modeltype::InvestmentModel)#, sense=Max)

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    𝒩ᶜᵃᵖ = (i for i ∈ 𝒩 if has_capacity(i))
    𝒩ᴵⁿᵛ = (i for i ∈ 𝒩 if has_investment(i))
    𝒫ᵉᵐ  = EMB.res_sub(𝒫, ResourceEmit)
    𝒩ˢᵗᵒʳ = EMB.node_sub(𝒩, Storage)
    r = global_data.r                               # Discount rate

    capexunit = 1 # TODO: Fix scaling if operational units are different form CAPEX

    obj = JuMP.AffExpr()

    haskey(m, :revenue)     && (obj += sum(obj_weight(r, 𝒯, t_inv, t) * m[:revenue][i, t] / capexunit for i ∈ 𝒩ᶜᵃᵖ, t_inv ∈ 𝒯ᴵⁿᵛ, t ∈ 𝒯))
    haskey(m, :opex_var)    && (obj -= sum(obj_weight_inv(r, 𝒯, t_inv) * m[:opex_var][i, t_inv] * t_inv.duration  for i ∈ 𝒩ᶜᵃᵖ, t_inv ∈  𝒯ᴵⁿᵛ))
    haskey(m, :opex_fixed)  && (obj -= sum(obj_weight_inv(r, 𝒯, t_inv) * m[:opex_fixed][i, t_inv] * t_inv.duration  for i ∈ 𝒩ᶜᵃᵖ, t_inv ∈  𝒯ᴵⁿᵛ))
    haskey(m, :capex_cap)   && !isempty(𝒩ᴵⁿᵛ) && (obj -= sum(obj_weight_inv(r, 𝒯, t_inv) * m[:capex_cap][i, t_inv]  for i ∈ 𝒩ᴵⁿᵛ, t_inv ∈  𝒯ᴵⁿᵛ))
    if haskey(m, :capex_stor) && isempty(𝒩ˢᵗᵒʳ) == false
        obj -= sum(obj_weight_inv(r, 𝒯, t_inv) * m[:capex_stor][i, t_inv]  for i ∈ 𝒩ˢᵗᵒʳ, t_inv ∈  𝒯ᴵⁿᵛ) #capex of the capacity part ofthe storage (by opposition to the power part)
    end
    if haskey(m, :capex_rate) && isempty(𝒩ˢᵗᵒʳ) == false
        obj -= sum(obj_weight_inv(r, 𝒯, t_inv) * m[:capex_rate][i, t_inv]  for i ∈ 𝒩ˢᵗᵒʳ, t_inv ∈  𝒯ᴵⁿᵛ) #capex of the capacity part ofthe storage (by opposition to the power part)
    end
    em_price = global_data.Emission_price
    obj -= sum(obj_weight_inv(r, 𝒯, t_inv) * m[:emissions_strategic][t_inv, p_em] * em_price[p_em][t_inv] for p_em ∈ 𝒫ᵉᵐ, t_inv ∈ 𝒯ᴵⁿᵛ)
    
    # TODO: Maintentance cost

    @objective(m, Max, obj)
end

"""
    EMB.variables_capex(m, 𝒩, 𝒯, 𝒫, ::InvestmentModel)

Create variables for the capital costs for the invesments in storage and 
technology nodes.
"""
function EMB.variables_capex(m, 𝒩, 𝒯, 𝒫, global_data, modeltype::InvestmentModel)
    
    𝒩ⁿᵒᵗ = EMB.node_not_av(𝒩)
    𝒩ˢᵗᵒʳ = EMB.node_sub(𝒩, Storage)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m,capex_cap[𝒩ⁿᵒᵗ, 𝒯ᴵⁿᵛ] >= 0)
    @variable(m,capex_stor[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ] >= 0)
    @variable(m,capex_rate[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ] >= 0)

end

"""
    EMB.variables_capacity(m, 𝒩, 𝒯, modeltype::InvestmentModel)

Create variables to track how much of installed capacity is used in each node
in terms of either `flow_in` or `flow_out` (depending on node `n ∈ 𝒩`) for all 
time periods `t ∈ 𝒯`.
Create variables for investments into capacities
"""
function EMB.variables_capacity(m, 𝒩, 𝒯, global_data, modeltype::InvestmentModel)
    @debug "Create investment variables"

    
    @variable(m, cap_use[𝒩, 𝒯] >= 0) # Linking variables used in EMB
    @variable(m, cap_inst[𝒩, 𝒯]>= 0)       # Max capacity

    # Add investment variables for each strategic period:
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    𝒩ᴵⁿᵛ = (i for i ∈ 𝒩 if has_investment(i))

    @variable(m, cap_invest_b[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ])
    @variable(m, cap_remove_b[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ])
    @variable(m, cap_current[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)     # Installed capacity
    @variable(m, cap_add[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ]  >= 0)        # Add capacity
    @variable(m, cap_rem[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ]  >= 0)        # Remove capacity
    

    # Additional constraints (e.g. for binary investments) are added per node depending on 
    # investment mode on each node. (One alternative could be to build variables iteratively with 
    # JuMPUtils.jl)
    constraints_capacity_invest(m, 𝒩, 𝒯, global_data, modeltype)
end

"""
    EMB.variables_storage(m, 𝒩, 𝒯, modeltype::InvestmentModel)


Create variables to track how much of installed rate is used in each storage node
in terms of either `flow_in` or `flow_out` (depending on node `n ∈ 𝒩`) for all 
time periods `t ∈ 𝒯` and what storage level exists.
Create variables for investments into storages.
"""
function EMB.variables_storage(m, 𝒩, 𝒯, global_data, modeltype::InvestmentModel)

    𝒩ˢᵗᵒʳ = EMB.node_sub(𝒩, Storage)

    @variable(m, stor_level[𝒩ˢᵗᵒʳ, 𝒯] >= 0)
    @variable(m, stor_rate_use[𝒩ˢᵗᵒʳ, 𝒯] >= 0)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Add storage specific investment variables for each strategic period:
    @variable(m, stor_cap_invest_b[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ])
    @variable(m, stor_cap_remove_b[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ])
    @variable(m, stor_cap_current[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ] >= 0)    # Installed capacity
    @variable(m, stor_cap_add[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ] >= 0)    # Add capacity
    @variable(m, stor_cap_rem[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ] >= 0)    # Remove capacity
    @variable(m, stor_cap_inst[𝒩ˢᵗᵒʳ, 𝒯]    >= 0)    # Max storage capacity

    @variable(m, stor_rate_invest_b[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ])
    @variable(m, stor_rate_remove_b[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ])
    @variable(m, stor_rate_current[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ] >= 0)    # Installed power/rate
    @variable(m, stor_rate_add[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ] >= 0)    # Add power
    @variable(m, stor_rate_rem[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ] >= 0)    # Remove power
    @variable(m, stor_rate_inst[𝒩ˢᵗᵒʳ, 𝒯]    >= 0)    # Max power

    # Additional constraints (e.g. for binary investments) are added per node depending on 
    # investment mode on each node. (One alternative could be to build variables iteratively with 
    # JuMPUtils.jl)
    constraints_storage_invest(m, 𝒩ˢᵗᵒʳ, 𝒯, global_data, modeltype)
end

"""
    constraints_capacity_invest(m, 𝒩, 𝒯)
Set capacity-related constraints for nodes `𝒩` for investment time structure `𝒯`:
* bounds
* binary for DiscreteInvestment
* link capacity variables

"""
function constraints_capacity_invest(m, 𝒩, 𝒯, global_data, modeltype::InvestmentModel)

    𝒩ᶜᵃᵖ = (i for i ∈ 𝒩 if has_capacity(i))
    𝒩ˢᵗᵒʳᶜᵃᵖ = (i for i ∈ 𝒩 if has_stor_capacity(i)) 
    𝒩ᴵⁿᵛ = (i for i ∈ 𝒩 if has_investment(i))
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    #constraints capex
    for n ∈ 𝒩ᴵⁿᵛ, t_inv ∈ 𝒯ᴵⁿᵛ
        set_capacity_cost(m, n, 𝒯, t_inv, global_data)
    end 
    
    
    # TODO, constraint for setting the minimum investment capacity
    # using binaries/semi continuous variables

    # Set investment properties based on investment mode of node n
    for n ∈ 𝒩ᴵⁿᵛ, t_inv ∈ 𝒯ᴵⁿᵛ
        set_investment_properties(n, m[:cap_invest_b][n, t_inv])  
    end

    # Link capacity usage to installed capacity 
    for n ∈ setdiff(𝒩ᶜᵃᵖ,𝒩ˢᵗᵒʳᶜᵃᵖ)
        if n ∈ 𝒩ᴵⁿᵛ
            for t_inv in 𝒯ᴵⁿᵛ, t in t_inv
                @constraint(m, m[:cap_inst][n, t] == m[:cap_current][n,t_inv])
            end
        else
            for t in 𝒯
                @constraint(m, m[:cap_inst][n, t] == n.Cap[t])
            end
        end
    end

    for n ∈ setdiff(𝒩ᶜᵃᵖ,𝒩ˢᵗᵒʳᶜᵃᵖ), t ∈ 𝒯
        @constraint(m, m[:cap_use][n, t] <= m[:cap_inst][n, t]) # sum cap_add/cap_rem
    end

    # Capacity updating
    for n ∈ 𝒩ᴵⁿᵛ
        for t_inv ∈ 𝒯ᴵⁿᵛ
            start_cap = get_start_cap(n,t_inv, n.Data["InvestmentModels"].Cap_start)
            @constraint(m, m[:cap_current][n, t_inv] <= n.Data["InvestmentModels"].Cap_max_inst[t_inv])
            @constraint(m, m[:cap_current][n, t_inv] ==
                (TS.isfirst(t_inv) ? start_cap : m[:cap_current][n, previous(t_inv,𝒯)])
                + m[:cap_add][n, t_inv] 
                - (TS.isfirst(t_inv) ? 0 : m[:cap_rem][n, previous(t_inv,𝒯)]))
        end
        set_capacity_installation(m, n, 𝒯ᴵⁿᵛ)
    end
end

"""
    constraints_storage_invest(m, 𝒩ˢᵗᵒʳ, 𝒯)
Set storage-related constraints for nodes `𝒩ˢᵗᵒʳ` for investment time structure `𝒯`:
* bounds
* binary for DiscreteInvestment
* link storage variables

"""
function constraints_storage_invest(m, 𝒩ˢᵗᵒʳ, 𝒯, global_data, modeltype::InvestmentModel)
    
    𝒩ᴵⁿᵛ = (i for i ∈ 𝒩ˢᵗᵒʳ if has_storage_investment(i))
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Constraints capex
    for n ∈ 𝒩ᴵⁿᵛ, t_inv ∈ 𝒯ᴵⁿᵛ
        set_capacity_cost(m, n, 𝒯, t_inv, global_data)
    end 
    

    # Set investment properties based on investment mode of node n
    for n ∈ 𝒩ᴵⁿᵛ, t_inv ∈ 𝒯ᴵⁿᵛ
        set_investment_properties(n, m[:stor_cap_invest_b][n, t_inv])  
        set_investment_properties(n, m[:stor_rate_invest_b][n, t_inv]) 
    end

    # Link capacity usage to installed capacity 
    for n ∈ 𝒩ˢᵗᵒʳ
        if n ∈ 𝒩ᴵⁿᵛ
            for t_inv in 𝒯ᴵⁿᵛ, t in t_inv
                @constraint(m, m[:stor_cap_inst][n, t] == m[:stor_cap_current][n,t_inv])
                @constraint(m, m[:stor_rate_inst][n, t] == m[:stor_rate_current][n,t_inv])
            end
        else
            for t in 𝒯
                @constraint(m, m[:stor_cap_inst][n, t] == n.Stor_cap[t])
                @constraint(m, m[:stor_rate_inst][n, t] == n.Rate_cap[t])
            end
        end
    end

    for n ∈ 𝒩ˢᵗᵒʳ, t ∈ 𝒯
        @constraint(m, m[:stor_rate_use][n, t] <= m[:stor_rate_inst][n, t]) # sum cap_add/cap_rem
        @constraint(m, m[:stor_level][n, t] <= m[:stor_cap_inst][n, t])
    end

    # Capacity updating
    for n ∈ 𝒩ᴵⁿᵛ
        for t_inv ∈ 𝒯ᴵⁿᵛ
            start_cap = get_start_cap_storage(n,t_inv,n.Data["InvestmentModels"].Stor_start)
            @constraint(m, m[:stor_cap_current][n, t_inv] <= n.Data["InvestmentModels"].Stor_max_inst[t_inv])
            @constraint(m, m[:stor_cap_current][n, t_inv] == 
                (TS.isfirst(t_inv) ? start_cap : m[:stor_cap_current][n, previous(t_inv,𝒯)]) 
                + m[:stor_cap_add][n, t_inv]
                - (TS.isfirst(t_inv) ? 0 : m[:stor_cap_rem][n, previous(t_inv,𝒯)]))

            start_rate = get_start_rate_storage(n,t_inv,n.Data["InvestmentModels"].Rate_start)
            @constraint(m, m[:stor_rate_current][n, t_inv] <= n.Data["InvestmentModels"].Rate_max_inst[t_inv])
            @constraint(m, m[:stor_rate_current][n, t_inv] == 
                (TS.isfirst(t_inv) ? start_rate : m[:stor_rate_current][n, previous(t_inv,𝒯)]) 
                + m[:stor_rate_add][n, t_inv]
                - (TS.isfirst(t_inv) ? 0 : m[:stor_rate_rem][n, previous(t_inv,𝒯)]))
        end
        set_storage_installation(m, n, 𝒯ᴵⁿᵛ)
    end
end

"""
    set_capacity_installation(m, n, 𝒯ᴵⁿᵛ)

Add constraints related to capacity installation depending on investment mode of node `n`
"""
set_capacity_installation(m, n, 𝒯ᴵⁿᵛ) = set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, investmentmode(n))
function set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, investmentmode)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:cap_add][n, t_inv] <= n.Data["InvestmentModels"].Cap_max_add[t_inv])
        @constraint(m, m[:cap_add][n, t_inv] >= n.Data["InvestmentModels"].Cap_min_add[t_inv])
        #@constraint(m, m[:cap_rem][n, t_inv] == 0)
    end
end

function set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, ::DiscreteInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:cap_current][n, t_inv] == n.capacity[t_inv] * m[:cap_invest_b][n, t_inv]) 
    end
end

function set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, ::IntegerInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        set_investment_properties(n, m[:cap_remove_b][n,t_inv])
        @constraint(m, m[:cap_add][n, t_inv] == n.Data["InvestmentModels"].Cap_increment[t_inv] * m[:cap_invest_b][n, t_inv])
        @constraint(m, m[:cap_rem][n, t_inv] == n.Data["InvestmentModels"].Cap_increment[t_inv] * m[:cap_remove_b][n, t_inv])
    end
end

function set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, ::SemiContinuousInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:cap_add][n, t_inv] <= n.Data["InvestmentModels"].Cap_max_add[t_inv] )
        @constraint(m, m[:cap_add][n, t_inv] >= n.Data["InvestmentModels"].Cap_min_add[t_inv] * m[:cap_invest_b][n, t_inv]) 
        #@constraint(m, m[:cap_rem][n, t_inv] == 0)
    end
end

function set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, ::FixedInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:cap_current][n, t_inv] == n.Cap[t_inv] * m[:Cap_invest_b][n, t_inv])
    end
end

function get_start_cap(n, t, stcap)
    return stcap
end

function get_start_cap(n::EMB.Node, t, ::Nothing)
    return TimeStructures.getindex(n.Cap,t)
end

"""
    set_storage_installation(m, n, 𝒯ᴵⁿᵛ)

Add constraints related to storage installation depending on investment mode of node `n`
"""
set_storage_installation(m, n, 𝒯ᴵⁿᵛ) = set_storage_installation(m, n, 𝒯ᴵⁿᵛ, investmentmode(n))
set_storage_installation(m, n, 𝒯ᴵⁿᵛ, investmentmode) = empty
function set_storage_installation(m, n::Storage, 𝒯ᴵⁿᵛ, investmentmode)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:stor_cap_add][n, t_inv] <= n.Data["InvestmentModels"].Stor_max_add[t_inv])
        @constraint(m, m[:stor_cap_add][n, t_inv] >= n.Data["InvestmentModels"].Stor_min_add[t_inv])

        @constraint(m, m[:stor_rate_add][n, t_inv] <= n.Data["InvestmentModels"].Rate_max_add[t_inv])
        @constraint(m, m[:stor_rate_add][n, t_inv] >= n.Data["InvestmentModels"].Rate_min_add[t_inv])
    end
end

function set_storage_installation(m, n::Storage, 𝒯ᴵⁿᵛ, ::DiscreteInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:stor_cap_current][n, t_inv] <= n.Stor_cap[t_inv] * m[:stor_cap_invest_b][n, t_inv])

        @constraint(m, m[:stor_rate_current][n, t_inv] <= n.Rate_cap[t_inv] * m[:stor_rate_invest_b][n, t_inv])
    end
end

function set_storage_installation(m, n, 𝒯ᴵⁿᵛ, ::IntegerInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        set_investment_properties(n, m[:stor_cap_remove_b][n,t_inv])
        @constraint(m, m[:stor_cap_add][n, t_inv] == n.Data["InvestmentModels"].Stor_increment[t_inv] * m[:stor_cap_invest_b][n, t_inv])
        @constraint(m, m[:stor_cap_rem][n, t_inv] == n.Data["InvestmentModels"].Stor_increment[t_inv] * m[:stor_cap_remove_b][n, t_inv])

        set_investment_properties(n, m[:stor_rate_remove_b][n,t_inv])
        @constraint(m, m[:stor_rate_add][n, t_inv] == n.Data["InvestmentModels"].Rate_increment[t_inv] * m[:stor_rate_invest_b][n, t_inv])
        @constraint(m, m[:stor_rate_rem][n, t_inv] == n.Data["InvestmentModels"].Rate_increment[t_inv] * m[:stor_rate_remove_b][n, t_inv])
    end
end

function set_storage_installation(m, n::Storage, 𝒯ᴵⁿᵛ, ::SemiContinuousInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:stor_cap_add][n, t_inv] <= n.Data["InvestmentModels"].Stor_max_add[t_inv] )
        @constraint(m, m[:stor_cap_add][n, t_inv] >= n.Data["InvestmentModels"].Stor_min_add[t_inv] * m[:stor_cap_invest_b][n, t_inv]) 

        @constraint(m, m[:stor_rate_add][n, t_inv] <= n.Data["InvestmentModels"].Rate_max_add[t_inv] )
        @constraint(m, m[:stor_rate_add][n, t_inv] >= n.Data["InvestmentModels"].Rate_min_add[t_inv] * m[:stor_rate_invest_b][n, t_inv]) 
    end
end

function set_storage_installation(m, n::Storage, 𝒯ᴵⁿᵛ, ::FixedInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:stor_cap_current][n, t_inv] == n.Stor_cap * m[:stor_cap_invest_b][n, t_inv])

        @constraint(m, m[:stor_rate_current][n, t_inv] == n.Rate_cap * m[:stor_rate_invest_b][n, t_inv])
    end
end

function get_start_cap_storage(n, t, stcap)
    return stcap
end

function get_start_cap_storage(n, t, ::Nothing)
    return TimeStructures.getindex(n.Stor_cap,t)
end

function get_start_rate_storage(n, t, stcap)
    return stcap
end

function get_start_rate_storage(n, t, ::Nothing)
    return TimeStructures.getindex(n.Rate_cap,t)
end

"""
    set_investment_properties(n, var)
Set investment properties for variable `var` for node `n`, e.g. set to binary for DiscreteInvestment, 
bounds etc
"""
set_investment_properties(n, var) = set_investment_properties(n, var, investmentmode(n))
function set_investment_properties(n, var, mode)
    set_lower_bound(var, 0)
end

function set_investment_properties(n, var, ::DiscreteInvestment)
    JuMP.set_binary(var)
end

function set_investment_properties(n, var, ::SemiContinuousInvestment)
    JuMP.set_binary(var)
end
    
"""
    set_investment_properties(n, var, ::IndividualInvestment)
Look up if binary investment from n and dispatch on that
"""
function set_investment_properties(n, var, ::IndividualInvestment)
    dispatch_mode = n.Data["InvestmentModels"].Inv_mode
    set_investment_properties(n, var, dispatch_mode)
end

function set_investment_properties(n, var, ::FixedInvestment) # TO DO
    JuMP.fix(var, 1)
end

function set_investment_properties(n, var, ::IntegerInvestment) # TO DO
    JuMP.set_integer(var)
    JuMP.set_lower_bound(var,0)
end

"""
    set_capacity_cost(m, n, 𝒯, t_inv, global_data)
Set the capex_cost based on the technology investment cost, and period strategic period length to include the needs for reinvestments and the rest value. 
It implements different versions of the lifetime implementation:
- UnlimitedLife:    The investment life is not limited. The investment costs do not consider any reinvestment or rest value.
- StudyLife:        The investment last for the whole study period with adequate reinvestments at end of lifetime and rest value.
- PeriodLife:       The investment is considered to last only for the strategic period. The excess lifetime is considered in the rest value.
- RollingLife:      The investment is rolling to the next strategic periods and it is retired at the end of its lifetime or the end 
                    of the previous sp if its lifetime ends between two sp.
"""
set_capacity_cost(m, n, 𝒯, t_inv, global_data) = set_capacity_cost(m, n, 𝒯, t_inv, global_data, lifetimemode(n))
function set_capacity_cost(m, n, 𝒯, t_inv, global_data, ::UnlimitedLife)
    # The capacity has an unlimited lifetime, one investment at the beginning of t_inv
    Data = n.Data["InvestmentModels"]
    @constraint(m, m[:capex_cap][n, t_inv] == Data.Capex_Cap[t_inv] * m[:cap_add][n, t_inv])
    @constraint(m, m[:cap_rem][n, t_inv] == 0)
end

function set_capacity_cost(m, n, 𝒯, t_inv, global_data, ::StudyLife)
    # The capacity is limited to the end of the study. Reinvestments are included
    # No capacity removed as there are reinvestments according to the study length
    Data = n.Data["InvestmentModels"]
    capex = Data.Capex_Cap[t_inv] * set_capex_value(TS.remaining_years(𝒯, t_inv), Data.Lifetime[t_inv], global_data.r)
    @constraint(m, m[:capex_cap][n, t_inv] == capex * m[:cap_add][n, t_inv])
    @constraint(m, m[:cap_rem][n, t_inv] == 0)
end

function set_capacity_cost(m, n, 𝒯, t_inv, global_data, ::PeriodLife)
    # The capacity is limited to the current sp. It has to be removed in the next sp.
    # The formula for capacity updating uses the cap_rem for the previous sp, hence the sps used here.
    Data = n.Data["InvestmentModels"]
    capex = Data.Capex_Cap[t_inv] * set_capex_value(TS.duration_years(𝒯, t_inv), Data.Lifetime[t_inv], global_data.r)
    @constraint(m, m[:capex_cap][n, t_inv] == capex * m[:cap_add][n, t_inv])
    @constraint(m, m[:cap_rem][n, t_inv] == m[:cap_add][n, t_inv] )
end

function set_capacity_cost(m, n, 𝒯, t_inv, global_data, ::RollingLife)
    Data = n.Data["InvestmentModels"]
    Lifetime = Data.Lifetime[t_inv]
    r = global_data.r                     # discount rate

     # If Lifetime is shorer than the sp duration , we apply the method for PeriodLife
    if Lifetime < TS.duration_years(𝒯, t_inv)
        set_capacity_cost(m, n, 𝒯, t_inv, global_data, PeriodLife())

    # If Lifetime is equal to sp duration we only need to invest once and there is no rest value
    elseif Lifetime == TS.duration_years(𝒯, t_inv)
        capex = Data.Capex_Cap[t_inv]
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
        capex = Data.Capex_Cap[t_inv] - ((remaining_lifetime/Lifetime) * Data.Capex_Cap[t_inv] * (1+r)^(-(Lifetime - remaining_lifetime)))
        @constraint(m, m[:capex_cap][n,t_inv] == capex * m[:cap_add][n, t_inv])

        # Capacity to be removed when remaining_lifetime < duration_years, i.e., in ante_sp
        if ante_sp.sp < t_inv.sps
            @constraint(m, m[:cap_rem][n, ante_sp] == m[:cap_add][n, t_inv])
        end
    end
end

#same function dispatched for storages
function set_capacity_cost(m, n::Storage, 𝒯, t_inv, global_data, ::UnlimitedLife)
    # The capacity has an unlimited lifetime, one investment at the beginning of t_inv
    Data = n.Data["InvestmentModels"]
    @constraint(m, m[:capex_stor][n, t_inv] == Data.Capex_stor[t_inv] * m[:stor_cap_add][n, t_inv])
    @constraint(m, m[:capex_rate][n, t_inv] == Data.Capex_rate[t_inv] * m[:stor_rate_add][n, t_inv])
    @constraint(m, m[:stor_cap_rem][n, t_inv] == 0)
    @constraint(m, m[:stor_rate_rem][n, t_inv] == 0)
end

function set_capacity_cost(m, n::Storage, 𝒯, t_inv, global_data, ::StudyLife)
    # The capacity is limited to the end of the study. Reinvestments are included
    # No capacity removed as there are reinvestments according to the study length
    Data = n.Data["InvestmentModels"]
    stor_capex = Data.Capex_stor[t_inv] * set_capex_value(TS.remaining_years(𝒯, t_inv), Data.Lifetime[t_inv], global_data.r)
    rate_capex = Data.Capex_rate[t_inv] * set_capex_value(TS.remaining_years(𝒯, t_inv), Data.Lifetime[t_inv], global_data.r)
    @constraint(m, m[:capex_stor][n, t_inv] == stor_capex * m[:stor_cap_add][n, t_inv])
    @constraint(m, m[:capex_rate][n, t_inv] == rate_capex * m[:stor_rate_add][n, t_inv])
    @constraint(m, m[:stor_cap_rem][n, t_inv] == 0)
    @constraint(m, m[:stor_rate_rem][n, t_inv] == 0)
end

function set_capacity_cost(m, n::Storage, 𝒯, t_inv, global_data, ::PeriodLife)
    # The capacity is limited to the current sp. It has to be removed in the next sp.
    # The formula for capacity updating uses the cap_rem for the previous sp, hence the sps used here.
    Data = n.Data["InvestmentModels"]
    stor_capex = Data.Capex_stor[t_inv] * set_capex_value(TS.duration_years(𝒯, t_inv), Data.Lifetime[t_inv], global_data.r)
    rate_capex = Data.Capex_rate[t_inv] * set_capex_value(TS.duration_years(𝒯, t_inv), Data.Lifetime[t_inv], global_data.r)
    @constraint(m, m[:capex_stor][n, t_inv] == stor_capex * m[:stor_cap_add][n, t_inv])
    @constraint(m, m[:capex_rate][n, t_inv] == rate_capex * m[:stor_rate_add][n, t_inv])
    @constraint(m, m[:stor_cap_rem][n, t_inv] == m[:stor_cap_add][n, t_inv] )
    @constraint(m, m[:stor_rate_rem][n, t_inv] == m[:stor_rate_add][n, t_inv] )
end

function set_capacity_cost(m, n::Storage, 𝒯, t_inv, global_data, ::RollingLife)
    Data = n.Data["InvestmentModels"]
    Lifetime = Data.Lifetime[t_inv]
    r = global_data.r                     # discount rate
    
    # If Lifetime is shorer than the sp duration , we apply the method for PeriodLife
    if Lifetime < TS.duration_years(𝒯, t_inv)
        set_capacity_cost(m, n, 𝒯, t_inv, global_data, PeriodLife())
        
    # If Lifetime is equal to sp duration we only need to invest once and there is no rest value
    elseif Lifetime == TS.duration_years(𝒯, t_inv)
        stor_capex = Data.Capex_stor[t_inv]
        rate_capex = Data.Capex_rate[t_inv]
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
        stor_capex = Data.Capex_stor[t_inv] - ((remaining_lifetime/Lifetime) * Data.Capex_stor[t_inv] * (1+r)^(-(Lifetime - remaining_lifetime)))
        rate_capex = Data.Capex_rate[t_inv] - ((remaining_lifetime/Lifetime) * Data.Capex_rate[t_inv] * (1+r)^(-(Lifetime - remaining_lifetime)))
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