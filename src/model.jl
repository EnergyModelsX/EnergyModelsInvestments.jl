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
    @variable(m, add_cap[𝒩, 𝒯ᴵⁿᵛ])  # Add capacity
    @variable(m, rem_cap[𝒩, 𝒯ᴵⁿᵛ])  # Remove capacity

    # Additional constraints (e.g. for binary investments) are added per node depending on 
    # investment mode on each node. (One alternative could be to build variables iteratively with 
    # JuMPUtils.jl)
    constraints_capacity(m, 𝒩, 𝒯ᴵⁿᵛ)
end

"""
    constraints_capacity(m, 𝒩, 𝒯ᴵⁿᵛ)
Set capacity-related constraints for nodes `𝒩` for investment time periods `𝒯ᴵⁿᵛ`:
* bounds
* binary for DiscreteInvestment
* link capacity variables

"""
function constraints_capacity(m, 𝒩, 𝒯ᴵⁿᵛ)
    for n ∈ 𝒩, t ∈ 𝒯ᴵⁿᵛ
        set_investment_properties(n, m[:add_cap][n, t])
        set_investment_properties(n, m[:rem_cap][n, t])
        @constraint(m, cap_usage[n, t] <= n.capacity[t]) # sum add_cap/rem_cap
    end

    # TO DO: Add constraints on capacity addition, removal etc.

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