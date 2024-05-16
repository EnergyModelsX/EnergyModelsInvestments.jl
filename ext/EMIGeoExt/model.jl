"""
    EMG.update_objective(m, 𝒩, 𝒯, 𝒫, ℒᵗʳᵃⁿˢ, modeltype::EMI.AbstractInvestmentModel)

Create objective function overloading the default from EMB for EMI.AbstractInvestmentModel.

Maximize Net Present Value from revenues, investments (CAPEX) and operations (OPEX)

## TODO:
# * consider passing expression around for updating
# * consider reading objective and adding terms/coefficients (from model object `m`)
"""
function EMG.update_objective(m, 𝒯, ℳ, modeltype::EMI.AbstractInvestmentModel)

    # Extraction of data
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    ℳᴵⁿᵛ = filter(EMI.has_investment, ℳ)
    obj  = JuMP.objective_function(m)
    disc = Discounter(EMI.discount_rate(modeltype), 𝒯)

    # Update of the cost function for modes with investments
    for t_inv ∈  𝒯ᴵⁿᵛ, tm ∈ ℳ
        if tm ∈ ℳᴵⁿᵛ
            obj -= objective_weight(t_inv, disc) * m[:trans_cap_capex][tm, t_inv]
        end
        obj -= duration_strat(t_inv) * objective_weight(t_inv, disc, type="avg") *
            m[:trans_opex_fixed][tm, t_inv]
        obj -= duration_strat(t_inv) * objective_weight(t_inv, disc, type="avg") *
            m[:trans_opex_var][tm, t_inv]
    end

    @objective(m, Max, obj)

end

"""
    EMG.variables_trans_capex(m, 𝒯, ℳ,, modeltype::EMI.AbstractInvestmentModel)

Create variables for the capital costs for the investments in transmission.
"""
function EMG.variables_trans_capex(m, 𝒯, ℳ, modeltype::EMI.AbstractInvestmentModel)

    ℳᴵⁿᵛ = filter(EMI.has_investment, ℳ)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m, trans_cap_capex[ℳᴵⁿᵛ,  𝒯ᴵⁿᵛ] >= 0)
end

"""
    EMG.variables_trans_capacity(m, 𝒯, ℳ, modeltype::EMI.AbstractInvestmentModel)

Create variables to track how much of installed transmision capacity is used for all
time periods `t ∈ 𝒯`. Introduction of the additional constraints for investments.

Additional variables for investment in capacity:
* `:trans_cap_current` - installed capacity for storage in each strategic period
* `:trans_cap_add` - added capacity
* `:trans_cap_rem` - removed capacity
* `:trans_cap_invest_b` - binary variable whether investments in capacity are happening
* `:trans_cap_remove_b` - binary variable whether investments in capacity are removed
"""
function EMG.variables_trans_capacity(m, 𝒯, ℳ, modeltype::EMI.AbstractInvestmentModel)

    @variable(m, trans_cap[ℳ, 𝒯] >= 0)

    𝒯ᴵⁿᵛ  = strategic_periods(𝒯)
    ℳᴵⁿᵛ = filter(EMI.has_investment, ℳ)

    # Add transmission specific investment variables for each strategic period:
    @variable(m, trans_cap_current[ℳᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)    # Installed capacity
    @variable(m, trans_cap_add[ℳᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)        # Add capacity
    @variable(m, trans_cap_rem[ℳᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)        # Remove capacity
    @variable(m, trans_cap_invest_b[ℳᴵⁿᵛ, 𝒯ᴵⁿᵛ]; container=IndexedVarArray)
    @variable(m, trans_cap_remove_b[ℳᴵⁿᵛ, 𝒯ᴵⁿᵛ]; container=IndexedVarArray)

    # Additional constraints (e.g. for binary investments) are added per transmission mode
    # depending on the investment mode on each transmission mode.
    # (One alternative could be to build variables iteratively with JuMPUtils.jl)
    for tm ∈ ℳ
        if EMI.has_investment(tm)
            # Extract the investment data and the discount rate
            disc_rate = EMI.discount_rate(modeltype)
            inv_data = EMI.investment_data(tm, :cap)

            # Add the investment constraints
            EMI.add_investment_constraints(m, tm, inv_data, :cap, :trans_cap, 𝒯ᴵⁿᵛ, disc_rate)

        else
            for t ∈ 𝒯
                fix(m[:trans_cap][tm, t], capacity(tm, t); force=true)
            end
        end
    end
end
