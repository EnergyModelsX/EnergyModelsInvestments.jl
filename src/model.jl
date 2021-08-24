"""
    objective(m, 𝒩, 𝒯, modeltype::InvestmentModel)

Create objective function overloading the default from EMB for InvestmentModel.

Maximize Net Present Value from revenues, investments (CAPEX) and operations (OPEX) 

## TODO: 
# * consider passing expression around for updating
# * consider reading objective and adding terms/coefficients (from model object `m`)

"""
function EMB.objective(m, 𝒩, 𝒯, 𝒫, modeltype::InvestmentModel)#, sense=Max)

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    𝒩ᶜᵃᵖ = (i for i ∈ 𝒩 if has_capacity(i))
    𝒩ᴵⁿᵛ = (i for i ∈ 𝒩 if has_investment(i))
    𝒫ᵉᵐ  = EMB.res_sub(𝒫, ResourceEmit)
    𝒩ˢᵗᵒʳ = EMB.node_sub(𝒩, Storage)
    r = modeltype.r     # Discount rate

    capexunit = 1 # TODO: Fix scaling if operational units are different form CAPEX

    obj = JuMP.AffExpr()

    haskey(m, :revenue) && (obj += sum(obj_weight(r, 𝒯, t_inv, t) * m[:revenue][i, t] / capexunit for i ∈ 𝒩ᶜᵃᵖ, t_inv ∈ 𝒯ᴵⁿᵛ, t ∈ 𝒯))
    haskey(m, :opex_var) && (obj -= sum(obj_weight_inv(r, 𝒯, t) * m[:opex_var][i, t]  for i ∈ 𝒩ᶜᵃᵖ, t ∈  𝒯ᴵⁿᵛ))
    haskey(m, :opex_fixed) && (obj -= sum(obj_weight_inv(r, 𝒯, t) * m[:opex_fixed][i, t]  for i ∈ 𝒩ᶜᵃᵖ, t ∈  𝒯ᴵⁿᵛ))
    haskey(m, :capex) && (obj -= sum(obj_weight_inv(r, 𝒯, t) * m[:capex][i,t]  for i ∈ 𝒩ᴵⁿᵛ, t ∈  𝒯ᴵⁿᵛ))
    if haskey(m, :capex_stor) && isempty(𝒩ˢᵗᵒʳ) == false
        obj -= sum(obj_weight_inv(r, 𝒯, t) * m[:capex_stor][i,t]  for i ∈ 𝒩ˢᵗᵒʳ, t ∈  𝒯ᴵⁿᵛ) #capex of the capacity part ofthe storage (by opposition to the power part)
    end
    em_price = modeltype.case.emissions_price
    obj -= sum(obj_weight_inv(r, 𝒯, t) * m[:emissions_strategic][t, p_em] * em_price[p_em][t] for p_em ∈ 𝒫ᵉᵐ, t ∈ 𝒯ᴵⁿᵛ)
    
    # TODO: Maintentance cost
    # TODO: Residual value

    @objective(m, Max, obj)
end


"""
    variables_capacity(m, 𝒩, 𝒯, modeltype::InvestmentModel)

Create variables to track how much of installed capacity is used in each node
in terms of either `flow_in` or `flow_out` (depending on node `n ∈ 𝒩`) for all 
time periods `t ∈ 𝒯`.
"""
function EMB.variables_capacity(m, 𝒩, 𝒯, modeltype::InvestmentModel)
    @debug "Create investment variables"


    @variable(m, cap_usage[𝒩, 𝒯] >= 0) # Linking variables used in EMB

    # Add investment variables for each strategic period:
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    @variable(m, invest[𝒩, 𝒯ᴵⁿᵛ])
    @variable(m, capacity[𝒩, 𝒯ᴵⁿᵛ] >= 0)        # Installed capacity
    @variable(m, add_cap[𝒩, 𝒯ᴵⁿᵛ]  >= 0)        # Add capacity
    @variable(m, rem_cap[𝒩, 𝒯ᴵⁿᵛ]  >= 0)        # Remove capacity
    @variable(m, cap_max[𝒩, 𝒯]     >= 0)        # Max capacity

    # Additional constraints (e.g. for binary investments) are added per node depending on 
    # investment mode on each node. (One alternative could be to build variables iteratively with 
    # JuMPUtils.jl)
    constraints_capacity(m, 𝒩, 𝒯)
end

"""
    variables_storage(m, 𝒩, 𝒯, modeltype::InvestmentModel)

Create variables to track how much of installed capacity is used in each node
in terms of either `flow_in` or `flow_out` (depending on node `n ∈ 𝒩`) for all 
time periods `t ∈ 𝒯`.
"""
function EMB.variables_storage(m, 𝒩, 𝒯, modeltype::InvestmentModel)

    𝒩ˢᵗᵒʳ = EMB.node_sub(𝒩, Storage)

    @variable(m, stor_level[𝒩ˢᵗᵒʳ, 𝒯] >= 0)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Add storage specific investment variables for each strategic period:
    @variable(m, invest_stor[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ])
    @variable(m, cap_stor[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ] >= 0)    # Installed capacity
    @variable(m, add_stor[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ] >= 0)    # Add capacity
    @variable(m, rem_stor[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ] >= 0)    # Remove capacity
    @variable(m, stor_max[𝒩ˢᵗᵒʳ, 𝒯]    >= 0)    # Max storage capacity

    # Additional constraints (e.g. for binary investments) are added per node depending on 
    # investment mode on each node. (One alternative could be to build variables iteratively with 
    # JuMPUtils.jl)
    constraints_storage(m, 𝒩ˢᵗᵒʳ, 𝒯)
end

"""
    constraints_capacity(m, 𝒩, 𝒯)
Set capacity-related constraints for nodes `𝒩` for investment time structure `𝒯`:
* bounds
* binary for DiscreteInvestment
* link capacity variables

"""
function constraints_capacity(m, 𝒩, 𝒯)
    

    𝒩ᶜᵃᵖ = (i for i ∈ 𝒩 if has_capacity(i))
    𝒩ᴵⁿᵛ = (i for i ∈ 𝒩 if has_investment(i))
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    #constraints capex
    for n ∈ 𝒩ᴵⁿᵛ, t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:capex][n,t_inv] == n.data["InvestmentModels"].capex[t_inv] * m[:add_cap][n, t_inv])
    end 
    
    
    # TODO, constraint for setting the minimum investment capacity
    # using binaries/semi continuous variables

    # Set investment properties based on investment mode of node n
    for n ∈ 𝒩ᴵⁿᵛ, t_inv ∈ 𝒯ᴵⁿᵛ
        set_investment_properties(n, m[:invest][n, t_inv])  
    end

    # Link capacity usage to installed capacity 
    for n ∈ 𝒩ᶜᵃᵖ
        if n ∈ 𝒩ᴵⁿᵛ
            for t_inv in 𝒯ᴵⁿᵛ
                for t in t_inv
                    @constraint(m, m[:cap_max][n, t] == m[:capacity][n,t_inv])
                end
            end
        else
            for t in 𝒯
                @constraint(m, m[:cap_max][n, t] == n.capacity[t])
            end
        end
    end

    for n ∈ 𝒩ᶜᵃᵖ, t ∈ 𝒯
        @constraint(m, m[:cap_usage][n, t] <= m[:cap_max][n, t]) # sum add_cap/rem_cap
    end

    # Capacity updating
    for n ∈ 𝒩ᴵⁿᵛ
        for t_inv ∈ 𝒯ᴵⁿᵛ
            @constraint(m, m[:capacity][n, t_inv] <= n.data["InvestmentModels"].max_inst_cap[t_inv])
            @constraint(m, m[:capacity][n, t_inv] ==
                (TS.isfirst(t_inv) ? TimeStructures.getindex(n.capacity,t_inv) : m[:capacity][n, previous(t_inv,𝒯)])
                + m[:add_cap][n, t_inv] 
                - (TS.isfirst(t_inv) ? 0 : m[:rem_cap][n, previous(t_inv,𝒯)]))
        end
        set_capacity_installation(m, n, 𝒯ᴵⁿᵛ)
    end
end

"""
    constraints_storage(m, 𝒩ˢᵗᵒʳ, 𝒯)
Set storage-related constraints for nodes `𝒩ˢᵗᵒʳ` for investment time structure `𝒯`:
* bounds
* binary for DiscreteInvestment
* link storage variables

"""
function constraints_storage(m, 𝒩ˢᵗᵒʳ, 𝒯)
    
    𝒩ᴵⁿᵛ = (i for i ∈ 𝒩ˢᵗᵒʳ if has_storage_investment(i))
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Constraints capex
    for n ∈ 𝒩ᴵⁿᵛ, t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:capex_stor][n,t_inv] == n.data["InvestmentModels"].capex_stor[t_inv] * m[:add_stor][n, t_inv])
    end 
    
    
    # TODO, constraint for setting the minimum investment capacity
    # using binaries/semi continuous variables

    # Set investment properties based on investment mode of node n
    for n ∈ 𝒩ᴵⁿᵛ, t_inv ∈ 𝒯ᴵⁿᵛ
        set_investment_properties(n, m[:invest_stor][n, t_inv])  
    end

    # Link capacity usage to installed capacity 
    for n ∈ 𝒩ˢᵗᵒʳ
        if n ∈ 𝒩ᴵⁿᵛ
            for t_inv in 𝒯ᴵⁿᵛ
                for t in t_inv
                    @constraint(m, m[:stor_max][n, t] == m[:cap_stor][n,t_inv])
                end
            end
        else
            for t in 𝒯
                @constraint(m, m[:stor_max][n, t] == n.cap_stor[t])
            end
        end
    end

    # Capacity updating
    for n ∈ 𝒩ᴵⁿᵛ
        for t_inv ∈ 𝒯ᴵⁿᵛ
            @constraint(m, m[:cap_stor][n, t_inv] <= n.data["InvestmentModels"].max_inst_stor[t_inv])
            @constraint(m, m[:cap_stor][n, t_inv] == 
                (TS.isfirst(t_inv) ? TimeStructures.getindex(n.cap_storage,t_inv) : m[:cap_stor][n, previous(t_inv,𝒯)]) 
                + m[:add_stor][n, t_inv]
                - (TS.isfirst(t_inv) ? 0 : m[:rem_stor][n, previous(t_inv,𝒯)]))
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
        @constraint(m, m[:add_cap][n, t_inv] <= n.data["InvestmentModels"].max_add[t_inv])
        @constraint(m, m[:add_cap][n, t_inv] >= n.data["InvestmentModels"].min_add[t_inv])
    end
end

function set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, ::DiscreteInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:add_cap][n, t_inv] <= n.data["InvestmentModels"].max_add[t_inv] * m[:invest][n, t_inv])
        @constraint(m, m[:add_cap][n, t_inv] >= n.data["InvestmentModels"].min_add[t_inv] * m[:invest][n, t_inv]) 
    end
end

"""
    set_storage_installation(m, n, 𝒯ᴵⁿᵛ)

Add constraints related to storage installation depending on investment mode of node `n`
"""
set_storage_installation(m, n, 𝒯ᴵⁿᵛ) = set_storage_installation(m, n, 𝒯ᴵⁿᵛ, investmentmode(n))
set_storage_installation(m, n, 𝒯ᴵⁿᵛ) = empty
function set_storage_installation(m, n::Storage, 𝒯ᴵⁿᵛ, investmentmode)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:add_stor][n, t_inv] <= n.data["InvestmentModels"].max_add_stor[t_inv])
        @constraint(m, m[:add_stor][n, t_inv] >= n.data["InvestmentModels"].min_add_stor[t_inv])
    end
end

function set_storage_installation(m, n::Storage, 𝒯ᴵⁿᵛ, ::DiscreteInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:add_stor][n, t_inv] <= n.data["InvestmentModels"].max_add_stor[t_inv] * m[:invest_stor][n, t_inv])
        @constraint(m, m[:add_stor][n, t_inv] >= n.data["InvestmentModels"].min_add_stor[t_inv] * m[:invest_stor][n, t_inv])
    end
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
    
"""
    set_investment_properties(n, var, ::IndividualInvestment)
Look up if binary investment from n and dispatch on that
"""
function set_investment_properties(n, var, ::IndividualInvestment)
    dispatch_mode = n.bininvest ? DiscreteInvestment() : ContinuousInvestment()
    set_investment_properties(n, var, dispatch_mode)
end
set_investment_properties(n, var, ::FixedInvestment) = "fixed" # TO DO

#Other possibility to define investment mode, talk with LArs
#function investmentmode(n)
#    return n.data["InvestmentModels"].inv_mode
#end