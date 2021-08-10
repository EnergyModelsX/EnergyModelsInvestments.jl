"""
    objective(m, 𝒩, 𝒯, modeltype::InvestmentModel)

Create objective function overloading the default from EMB for InvestmentModel.

Maximize Net Present Value from revenues, investments (CAPEX) and operations (OPEX) 

## TODO: 
# * consider passing expression around for updating
# * consider reading objective and adding terms/coefficients (from model object `m`)

"""
function EMB.objective(m, 𝒩, 𝒯, modeltype::InvestmentModel)#, sense=Max)

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    𝒩ᶜᵃᵖ = (i for i ∈ 𝒩 if has_capacity(i))
    𝒩ˢᵗᵒʳ = EMB.node_sub(𝒩, Storage)
    r = modeltype.r     # Discount rate

    capexunit = 1 # TODO: Fix scaling if operational units are different form CAPEX

    obj = JuMP.AffExpr()

    haskey(m, :revenue) && (obj += sum(obj_weight(r, 𝒯, t_inv, t) * m[:revenue][i, t] / capexunit for i ∈ 𝒩ᶜᵃᵖ, t_inv ∈ 𝒯ᴵⁿᵛ, t ∈ 𝒯))
    haskey(m, :opex_var) && (obj -= sum(obj_weight_inv(r, 𝒯, t) * m[:opex_var][i, t]  for i ∈ 𝒩ᶜᵃᵖ, t ∈  𝒯ᴵⁿᵛ))
    haskey(m, :opex_fixed) && (obj -= sum(obj_weight_inv(r, 𝒯, t) * m[:opex_fixed][i, t]  for i ∈ 𝒩ᶜᵃᵖ, t ∈  𝒯ᴵⁿᵛ))
    haskey(m, :capex) && (obj -= sum(obj_weight_inv(r, 𝒯, t) * m[:capex][i,t]  for i ∈ 𝒩ᶜᵃᵖ, t ∈  𝒯ᴵⁿᵛ))
    haskey(m, :capex_capacity) && (obj -= sum(obj_weight_inv(r, 𝒯, t) * m[:capex_capacity][i,t]  for i ∈ 𝒩ˢᵗᵒʳ, t ∈  𝒯ᴵⁿᵛ)) #capex of the capacity part ofthe storage (by opposition to the power part)
    
    # TODO: Maintentance cost
    # TODO: Residual value

    @objective(m, Max, obj)
end


"""
    create_capacity_variables(m, 𝒩, 𝒯, modeltype::DiscreteInvestmentModel)

Create variables to track how much of installed capacity is used in each node
in terms of either `flow_in` or `flow_out` (depending on node `n ∈ 𝒩`) for all 
time periods `t ∈ 𝒯`.
"""
function EMB.variables_capacity(m, 𝒩, 𝒯, modeltype::InvestmentModel)
    @debug "Create investment variables"


    @variable(m, cap_usage[𝒩, 𝒯] >= 0) # Linking variables used in EMB

    # Add investment variables for each strategic period:
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    @variable(m,  invest[𝒩, 𝒯ᴵⁿᵛ])
    @variable(m, capacity[𝒩, 𝒯ᴵⁿᵛ] >= 0) # Installed capacity
    @variable(m, add_cap[𝒩, 𝒯ᴵⁿᵛ] >= 0)  # Add capacity
    @variable(m, rem_cap[𝒩, 𝒯ᴵⁿᵛ]>= 0)  # Remove capacity
    @variable(m, cap_max[𝒩, 𝒯] >= 0)     # Max capacity

    # Add storage specific investment variables for each strategic period:
    𝒩ˢᵗᵒʳ = EMB.node_sub(𝒩, Storage)
    @variable(m, invest_capacity[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ])
    @variable(m, cap_storage[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ] >= 0) # Installed capacity
    @variable(m, add_cap_capacity[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ] >= 0)  # Add capacity
    @variable(m, rem_cap_capacity[𝒩ˢᵗᵒʳ, 𝒯ᴵⁿᵛ] >= 0)  # Remove capacity
    @variable(m, stor_max[𝒩ˢᵗᵒʳ, 𝒯] >= 0)     # Max storage capacity

    # Additional constraints (e.g. for binary investments) are added per node depending on 
    # investment mode on each node. (One alternative could be to build variables iteratively with 
    # JuMPUtils.jl)
    constraints_capacity(m, 𝒩, 𝒯)
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
    𝒩ˢᵗᵒʳ = EMB.node_sub(𝒩, Storage)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    #constraints capex
    for n ∈ 𝒩ᴵⁿᵛ, t ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:capex][n,t] == n.data["InvestmentModels"].capex[t] * m[:add_cap][n,t])
    end 
    for n ∈ 𝒩ˢᵗᵒʳ, t ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:capex_capacity][n,t] == n.data["InvestmentModels"].capex_capacity[t] * m[:add_cap_capacity][n,t])
    end 
    
    
    # TODO, constraint for setting the minimum investment capacity
    # using binaries/semi continuous variables

    # Set investment properties based on investment mode of node n
    for n ∈ 𝒩ᴵⁿᵛ, t ∈ 𝒯ᴵⁿᵛ
        set_investment_properties(n, m[:invest][n, t])  
    end
    for n ∈ 𝒩ˢᵗᵒʳ, t ∈ 𝒯ᴵⁿᵛ
        set_investment_properties(n, m[:invest_capacity][n, t])  
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
    for n ∈ 𝒩ˢᵗᵒʳ
        if n ∈ 𝒩ᴵⁿᵛ
            for t_inv in 𝒯ᴵⁿᵛ
                for t in t_inv
                    @constraint(m, m[:stor_max][n, t] == m[:cap_storage][n,t_inv])
                end
            end
        else
            for t in 𝒯
                @constraint(m, m[:stor_max][n, t] == n.cap_storage[t])
            end
        end
    end

    for n ∈ 𝒩ᶜᵃᵖ, t ∈ 𝒯
        @constraint(m, m[:cap_usage][n, t] <= m[:cap_max][n, t]) # sum add_cap/rem_cap
    end

    isfirst(sp::StrategicPeriod) = sp.sp == 1 # TODO: Replace with TimeStructures method when released
    # Capacity updating
    for n ∈ 𝒩ᴵⁿᵛ
        existing_cap = n.data["InvestmentModels"].ExistingCapacity
        for t ∈ 𝒯ᴵⁿᵛ
            @constraint(m, m[:capacity][n, t] <= n.data["InvestmentModels"].max_inst_cap[t])
            @constraint(m, m[:capacity][n, t] == (isfirst(t) ? existing_cap : m[:capacity][n, previous(t,𝒯)]) + m[:add_cap][n, t] - 
                (isfirst(t) ? 0 : m[:rem_cap][n, previous(t,𝒯)]))
        end
        set_capacity_installation(m, n, 𝒯ᴵⁿᵛ)
    end
    for n ∈ 𝒩ˢᵗᵒʳ
        existing_cap_cap = n.data["InvestmentModels"].ExistingCapacity_capacity
        for t ∈ 𝒯ᴵⁿᵛ
            @constraint(m, m[:cap_storage][n, t] <= n.data["InvestmentModels"].max_inst_cap_capacity[t])
            @constraint(m, m[:cap_storage][n, t] == (isfirst(t) ? existing_cap_cap : m[:cap_storage][n, previous(t,𝒯)]) + m[:add_cap_capacity][n, t] - 
                    (isfirst(t) ? 0 : m[:rem_cap_capacity][n, previous(t,𝒯)]))
        end
    end


end

"""
    set_capacity_installation(m, n, 𝒯ᴵⁿᵛ)

Add constraints related to capacity installation depending on investment mode of node `n`
"""
set_capacity_installation(m, n, 𝒯ᴵⁿᵛ) = set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, investmentmode(n))
function set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, investmentmode)
    for t ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:add_cap][n, t] <= n.data["InvestmentModels"].max_add[t])
        @constraint(m, m[:add_cap][n, t] >= n.data["InvestmentModels"].min_add[t])
    end
end

function set_capacity_installation(m, n, 𝒯ᴵⁿᵛ, ::DiscreteInvestment)
    for t ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:add_cap][n, t] <= n.data["InvestmentModels"].max_add[t] * m[:invest][n, t])
        @constraint(m, m[:add_cap][n, t] >= n.data["InvestmentModels"].min_add[t] * m[:invest][n, t]) 
    end
end

function set_capacity_installation(m, n::Storage, 𝒯ᴵⁿᵛ, investmentmode)
    for t ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:add_cap][n, t] <= n.data["InvestmentModels"].max_add[t])
        @constraint(m, m[:add_cap][n, t] >= n.data["InvestmentModels"].min_add[t])
        @constraint(m, m[:add_cap_capacity][n, t] <= n.data["InvestmentModels"].max_add_capacity[t])
        @constraint(m, m[:add_cap_capacity][n, t] >= n.data["InvestmentModels"].min_add_capacity[t])
    end
end

function set_capacity_installation(m, n::Storage, 𝒯ᴵⁿᵛ, ::DiscreteInvestment)
    for t ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:add_cap][n, t] <= n.data["InvestmentModels"].max_add[t] * m[:invest][n, t])
        @constraint(m, m[:add_cap][n, t] >= n.data["InvestmentModels"].min_add[t] * m[:invest][n, t])
        @constraint(m, m[:add_cap_capacity][n, t] <= n.data["InvestmentModels"].max_add_capacity[t] * m[:invest_capacity][n, t])
        @constraint(m, m[:add_cap_capacity][n, t] >= n.data["InvestmentModels"].min_add_capacity[t] * m[:invest_capacity][n, t])
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

function EMB.variables_storage(m, 𝒩, 𝒯, modeltype::InvestmentModel)
    𝒩ˢᵗᵒʳ = EMB.node_sub(𝒩, Storage)

    # @variable(m, bypass[𝒩ˢᵗᵒʳ, 𝒯] >= 0)
    @variable(m, stor_level[𝒩ˢᵗᵒʳ, 𝒯] >= 0)

end