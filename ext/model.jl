"""
    EMG.update_objective(m, 𝒩, 𝒯, 𝒫, ℒᵗʳᵃⁿˢ, modeltype::InvestmentModel)

Create objective function overloading the default from EMB for InvestmentModel.

Maximize Net Present Value from revenues, investments (CAPEX) and operations (OPEX) 

## TODO: 
# * consider passing expression around for updating
# * consider reading objective and adding terms/coefficients (from model object `m`)
"""
function EMG.update_objective(m, 𝒯, ℳ, modeltype::InvestmentModel)

    # Extraction of data
    𝒯ᴵⁿᵛ    = strategic_periods(𝒯)
    ℳᴵⁿᵛ   = EMI.has_investment(ℳ)
    r       = modeltype.r
    obj     = JuMP.objective_function(m)

    # Update of the cost function for modes with investments
    for t ∈  𝒯ᴵⁿᵛ, tm ∈ ℳᴵⁿᵛ
        obj -= obj_weight_inv(r, 𝒯, t) * m[:capex_trans][tm, t]
        obj -= obj_weight_inv(r, 𝒯, t) * m[:trans_opex_fixed][tm, t]
        obj -= obj_weight_inv(r, 𝒯, t) * m[:trans_opex_var][tm, t]
    end

    @objective(m, Max, obj)

end

"""
    EMG.variables_trans_capex(m, 𝒯, ℳ,, modeltype::InvestmentModel)

Create variables for the capital costs for the investments in transmission.
"""
function EMG.variables_trans_capex(m, 𝒯, ℳ, modeltype::InvestmentModel)

    ℳᴵⁿᵛ = EMI.has_investment(ℳ)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m, capex_trans[ℳᴵⁿᵛ,  𝒯ᴵⁿᵛ] >= 0)
end

"""
    EMG.variables_trans_capacity(m, 𝒯, ℳ, modeltype::InvestmentModel)

Create variables to track how much of installed transmision capacity is used for all 
time periods `t ∈ 𝒯` and how much energy is lossed. Introduction of the additional
constraints for investments.
    
Additional variables for investment in capacity:
    * `:trans_cap_invest_b` - binary variable whether investments in capacity are happening
    * `:trans_cap_remove_b` - binary variable whether investments in capacity are removed
    * `:trans_cap_current` - installed capacity for storage in each strategic period
    * `:trans_cap_add` - added capacity
    * `:trans_cap_rem` - removed capacity
"""
function EMG.variables_trans_capacity(m, 𝒯, ℳ, modeltype::InvestmentModel)

    @variable(m, trans_cap[ℳ, 𝒯] >= 0)

    𝒯ᴵⁿᵛ  = strategic_periods(𝒯)
    ℳᴵⁿᵛ = EMI.has_investment(ℳ)

    # Add transmission specific investment variables for each strategic period:
    @variable(m, trans_cap_invest_b[ℳᴵⁿᵛ, 𝒯ᴵⁿᵛ])
    @variable(m, trans_cap_remove_b[ℳᴵⁿᵛ, 𝒯ᴵⁿᵛ])
    @variable(m, trans_cap_current[ℳᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)   # Installed capacity
    @variable(m, trans_cap_add[ℳᴵⁿᵛ, 𝒯ᴵⁿᵛ]  >= 0)      # Add capacity
    @variable(m, trans_cap_rem[ℳᴵⁿᵛ, 𝒯ᴵⁿᵛ]  >= 0)      # Remove capacity
    

    # Additional constraints (e.g. for binary investments) are added per node depending on 
    # investment mode on each node. (One alternative could be to build variables iteratively with 
    # JuMPUtils.jl)
    constraints_transmission_invest(m, 𝒯, ℳ, modeltype)
end


"""
    constraints_transmission_invest(m, 𝒯, ℳ, modeltype::InvestmentModel)
Set capacity-related constraints for `TransmissionMode`s `ℳ` for investment time structure `𝒯`:
* bounds
* binary for BinaryInvestment
* link capacity variables

"""
function constraints_transmission_invest(m, 𝒯, ℳ, modeltype::InvestmentModel)
    
    𝒯ᴵⁿᵛ  = strategic_periods(𝒯)
    ℳᴵⁿᵛ = EMI.has_investment(ℳ)
    
    # Constraints capex
    for t_inv ∈ 𝒯ᴵⁿᵛ, tm ∈ ℳᴵⁿᵛ 
        set_capacity_cost(m, tm, 𝒯, t_inv, modeltype)
    end

    # Set investment properties based on investment mode of `TransmissionMode` tm
    for t_inv ∈ 𝒯ᴵⁿᵛ, tm ∈ ℳᴵⁿᵛ 
        EMI.set_investment_properties(tm, m[:trans_cap_invest_b][tm, t_inv])  
    end

    # Link capacity to installed capacity 
    for tm ∈ ℳᴵⁿᵛ
        for t_inv ∈ 𝒯ᴵⁿᵛ, t ∈ t_inv
            @constraint(m, m[:trans_cap][tm, t] == m[:trans_cap_current][tm, t_inv])
        end
    end
    for tm ∈ setdiff(ℳ, ℳᴵⁿᵛ)
        for t ∈ 𝒯
            @constraint(m, m[:trans_cap][tm, t] == tm.Trans_cap[t])
        end
    end

    # Transmission capacity updating
    for tm ∈ ℳᴵⁿᵛ
        inv_data = EMI.investment_data(tm)
        for t_inv ∈ 𝒯ᴵⁿᵛ
            start_cap = EMI.get_start_cap(tm, t_inv, inv_data.Trans_start)
            @constraint(m, m[:trans_cap_current][tm, t_inv] <=
            inv_data.Trans_max_inst[t_inv])
            @constraint(m, m[:trans_cap_current][tm, t_inv] ==
            (isfirst(t_inv) ? start_cap : m[:trans_cap_current][tm, previous(t_inv,𝒯)])
            + m[:trans_cap_add][tm, t_inv] 
            - (isfirst(t_inv) ? 0 : m[:trans_cap_rem][tm, previous(t_inv,𝒯)]))
        end
        set_trans_cap_installation(m, tm, 𝒯ᴵⁿᵛ)
    end
end


"""
    set_trans_cap_installation(m, tm, 𝒯ᴵⁿᵛ, investment_mode)

Add constraints related to capacity installation depending on investment mode of
`TransmissionMode` tm.
"""
set_trans_cap_installation(m, tm, 𝒯ᴵⁿᵛ) = 
    set_trans_cap_installation(m, tm, 𝒯ᴵⁿᵛ, EMI.investment_mode(tm))
function set_trans_cap_installation(m, tm, 𝒯ᴵⁿᵛ, ::EMI.Investment)
    # Extract the investment data
    inv_data = EMI.investment_data(tm)

    # Set the limits
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:trans_cap_add][tm, t_inv] <= 
                            inv_data.Trans_max_add[t_inv])
        @constraint(m, m[:trans_cap_add][tm, t_inv] >=
                            inv_data.Trans_min_add[t_inv])
        @constraint(m, m[:trans_cap_rem][tm, t_inv] == 0)
    end
end

function set_trans_cap_installation(m, tm, 𝒯ᴵⁿᵛ, ::BinaryInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:trans_cap_current][tm, t_inv] ==
                            tm.Trans_cap[t_inv] * m[:trans_cap_invest_b][tm, t_inv]) 
    end
end

function set_trans_cap_installation(m, tm, 𝒯ᴵⁿᵛ, ::DiscreteInvestment)
    # Extract the investment data
    inv_data = EMI.investment_data(tm)

    # Set the limits
    for t_inv ∈ 𝒯ᴵⁿᵛ
        EMI.set_investment_properties( tm, m[:trans_cap_remove_b][tm, t_inv])
        @constraint(m, m[:trans_cap_add][tm, t_inv] == 
                            inv_data.Trans_increment[t_inv]
                            * m[:trans_cap_invest_b][tm, t_inv])
        @constraint(m, m[:trans_cap_rem][tm, t_inv] == 
                            inv_data.Trans_increment[t_inv]
                            * m[:trans_cap_remove_b][tm, t_inv])
    end
end

function set_trans_cap_installation(m, tm, 𝒯ᴵⁿᵛ, ::SemiContiInvestment)
    # Extract the investment data
    inv_data = EMI.investment_data(tm)

    # Set the limits
    for t_inv ∈ 𝒯ᴵⁿᵛ
        # Disjunctive constraints when investing
        @constraint(m, m[:trans_cap_add][tm, t_inv] <=
                            inv_data.Trans_max_add[t_inv]
                            * m[:trans_cap_invest_b][tm, t_inv]) 
        @constraint(m, m[:trans_cap_add][tm, t_inv] >=
                            inv_data.Trans_min_add[t_inv]
                            * m[:trans_cap_invest_b][tm, t_inv]) 
        @constraint(m, m[:trans_cap_rem][tm, t_inv] == 0)
    end
end

function set_trans_cap_installation(m, tm, 𝒯ᴵⁿᵛ, ::FixedInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:trans_cap_current][tm, t_inv] ==
                            tm.Trans_cap[t_inv] * m[:trans_cap_invest_b][tm, t_inv])
    end
end


"""
    set_capacity_cost(m, tm::EMG.TransmissionMode, 𝒯, t_inv, modeltype)
Set `capex_trans` based on the technology investment cost to include the potential for either
semi continuous costs with offsets or piecewise linear costs. 
It implements different versions of cost calculations:
- `Investment`: The cost is linear dependent on the installed capacity. This is the default
for all invcestment options
- `SemiContinuousOffsetInvestment`: The cost is linear dependent on the added capacity with a
given offset
"""
set_capacity_cost(m, tm::EMG.TransmissionMode, 𝒯, t_inv, modeltype) = set_capacity_cost(m, tm, 𝒯, t_inv, modeltype, EMI.investment_mode(tm))

function set_capacity_cost(m, tm::EMG.TransmissionMode, 𝒯, t_inv, modeltype, ::EMI.Investment)
    # Extract the investment data
    inv_data = EMI.investment_data(tm)

    # Set the cost contribution
    @constraint(m, m[:capex_trans][tm, t_inv] ==
                        inv_data.Capex_trans[t_inv]
                        * m[:trans_cap_add][tm, t_inv])
end

function set_capacity_cost(m, tm::EMG.TransmissionMode, 𝒯, t_inv, modeltype, ::SemiContinuousOffsetInvestment)
    # Extract the investment data
    inv_data = EMI.investment_data(tm)

    # Set the cost contribution
    @constraint(m, m[:capex_trans][tm, t_inv] ==
                        inv_data.Capex_trans[t_inv] * m[:trans_cap_add][tm, t_inv] + 
                        inv_data.Capex_trans_offset[t_inv] * m[:trans_cap_invest_b][tm, t_inv])
end
