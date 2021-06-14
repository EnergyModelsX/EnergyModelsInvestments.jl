
function EMB.variables_capacity(m, 𝒩, 𝒯, modeltype::DiscreteInvestmentModel)
    @info "Create discret investment variables"
    # Add /remove decisions, binary on strategic periods

    @variable(m, cap_usage[𝒩, 𝒯] >= 0)
    
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    @variable(m, add_cap[𝒩, 𝒯ᴵⁿᵛ], Bin)
    @variable(m, rem_cap[𝒩, 𝒯ᴵⁿᵛ], Bin)

end

"""
    create_capacity_variables(m, 𝒩, 𝒯, modeltype::DiscreteInvestmentModel)

Create variables to track how much of installed capacity is used in each node
in terms of either `flow_in` or `flow_out` (depending on node `n ∈ 𝒩`) for all 
time periods `t ∈ 𝒯`.
"""
function EMB.variables_capacity(m, 𝒩, 𝒯, modeltype::ContinuousInvestmentModel)

    @variable(m, cap_usage[𝒩, 𝒯] >= 0)

end


function constraints_capacity(m, 𝒩, 𝒯, modeltype::InvestmentModel)
    for n ∈ 𝒩, t ∈ 𝒯
        @constraint(m, cap_usage[n, t] <= n.capacity[t]) # sum add_cap/rem_cap
    end
end




# Pattern to use for node dispatch on investment mode trait:

# Dispatch definition of investment variables on investmentmode trait:
variables_investment(x) = variables_investment(x, investmentmode(x))

# Examples:
variables_investment(x, mode::DiscreteInvestment) = "discrete"
variables_investment(x, mode::ContinuousInvestment) = "continuous"
"""
    Look up if binary investment from x and dispatch on that
"""
function variables_investment(x, mode::IndividualInvestment)
    dispatch_mode = x.bininvest ? DiscreteInvestment() : ContinuousInvestment()
    variables_investment(x, dispatch_mode)
end
variables_investment(x, mode::FixedInvestment) = "fixed"