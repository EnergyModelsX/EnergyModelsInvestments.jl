# TODO: 
# * Add/remove/invest etc ala HyOpt
# * Tests
"""
    objective(m, 𝒩, 𝒯, modeltype::InvestmentModel)

Create objective function overloading the default from EMB for InvestmentModel.

Maximize Net Present Value from revenues, investments (CAPEX) and operations (OPEX) 

## TODO: 
# * consider passing expression around for updating
# * consider reading objective and adding terms/coefficients (from model object `m`)

"""
function EMB.objective(m, 𝒩, 𝒯, modeltype::InvestmentModel, sense=Max)
    
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    𝒩ᶜᵃᵖ = (i for i ∈ 𝒩 if has_capacity(i))
    r = modeltype.r     # Discount rate

    capexunit = 1 # TODO: Fix scaling if operational units are different form CAPEX

    obj = JuMP.AffExpr()

    is_defined(m, :revenue) && (obj += sum(obj_weight(r, 𝒯, t) * m[:revenue][i, t] / capexunit for i ∈ 𝒩ᶜᵃᵖ, t ∈ 𝒯))
    is_defined(m, :opex_var) && (obj -= sum(obj_weight_inv(r, 𝒯, t) * m[:opex_var][i, t]  for i ∈ 𝒩ᶜᵃᵖ, t ∈  𝒯ᴵⁿᵛ))
    is_defined(m, :opex_fixed) && (obj -= sum(obj_weight_inv(r, 𝒯, t) * m[:opex_fixed][i, t]  for i ∈ 𝒩ᶜᵃᵖ, t ∈  𝒯ᴵⁿᵛ))
    is_defined(m, :capex) && (obj -= sum(obj_weight_inv(r, 𝒯, t) * m[:capex][i,t]  for i ∈ 𝒩ᶜᵃᵖ, t ∈  𝒯ᴵⁿᵛ))
    
    # TODO: Maintentance cost
    # TODO: Residual value

    @objective(m, sense, obj)
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

    # Add constraints on capacity addition, removal etc.
    for n ∈ 𝒩, t ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:cap_max][n, t] == m[:cap_max][n, t-1] + m[:add_cap][n, t] - m[:rem_cap][n, t])
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