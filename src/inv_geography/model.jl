const GEO = EnergyModelsGeography

"""
    GEO.update_objective(m, 𝒩, 𝒯, 𝒫, ℒᵗʳᵃⁿˢ, modeltype::InvestmentModel)

Create objective function overloading the default from EMB for InvestmentModel.

Maximize Net Present Value from revenues, investments (CAPEX) and operations (OPEX) 

## TODO: 
# * consider passing expression around for updating
# * consider reading objective and adding terms/coefficients (from model object `m`)
"""
function GEO.update_objective(m, 𝒩, 𝒯, 𝒫, ℒᵗʳᵃⁿˢ, modeltype::InvestmentModel)

    # Extraction of data
    𝒯ᴵⁿᵛ    = strategic_periods(𝒯)
    𝒞ℳ      = GEO.corridor_modes(ℒᵗʳᵃⁿˢ)
    𝒞ℳᴵⁿᵛ   = has_investment(𝒞ℳ)
    r       = modeltype.r
    obj     = JuMP.objective_function(m)

    # Update of the cost function for modes with investments
    for t ∈  𝒯ᴵⁿᵛ, cm ∈ 𝒞ℳᴵⁿᵛ
        obj -= obj_weight_inv(r, 𝒯, t) * m[:capex_trans][cm, t]
    end

    @objective(m, Max, obj)

end

"""
    GEO.variables_trans_capex(m, 𝒯, ℒᵗʳᵃⁿˢ,, modeltype::InvestmentModel)

Create variables for the capital costs for the investments in transmission.
"""
function GEO.variables_trans_capex(m, 𝒯, ℒᵗʳᵃⁿˢ, modeltype::InvestmentModel)

    𝒞ℳ      = GEO.corridor_modes(ℒᵗʳᵃⁿˢ)
    𝒞ℳᴵⁿᵛ   = has_investment(𝒞ℳ)
    𝒯ᴵⁿᵛ    = strategic_periods(𝒯)

    @variable(m, capex_trans[𝒞ℳᴵⁿᵛ,  𝒯ᴵⁿᵛ] >= 0)
end

"""
    GEO.variables_trans_capacity(m, 𝒯, 𝒞ℳ, modeltype::InvestmentModel)

Create variables to track how much of installed transmision capacity is used for all 
time periods `t ∈ 𝒯` and how much energy is lossed. Introduction of the additional
constraints for investments.
    
Additional variables for investment in capacity:
    * `:trans_invest_b` - binary variable whether investments in capacity are happening
    * `:trans_remove_b` - binary variable whether investments in capacity are removed
    * `:trans_cap_current` - installed capacity for storage in each strategic period
    * `:trans_cap_add` - added capacity
    * `:trans_cap_rem` - removed capacity
"""
function GEO.variables_trans_capacity(m, 𝒯, 𝒞ℳ, modeltype::InvestmentModel)

    @variable(m, trans_cap[𝒞ℳ, 𝒯] >= 0)

    𝒯ᴵⁿᵛ  = strategic_periods(𝒯)
    𝒞ℳᴵⁿᵛ = has_investment(𝒞ℳ)

    # Add transmission specific investment variables for each strategic period:
    @variable(m, trans_invest_b[𝒞ℳᴵⁿᵛ, 𝒯ᴵⁿᵛ])
    @variable(m, trans_remove_b[𝒞ℳᴵⁿᵛ, 𝒯ᴵⁿᵛ])
    @variable(m, trans_cap_current[𝒞ℳᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)   # Installed capacity
    @variable(m, trans_cap_add[𝒞ℳᴵⁿᵛ, 𝒯ᴵⁿᵛ]  >= 0)      # Add capacity
    @variable(m, trans_cap_rem[𝒞ℳᴵⁿᵛ, 𝒯ᴵⁿᵛ]  >= 0)      # Remove capacity
    

    # Additional constraints (e.g. for binary investments) are added per node depending on 
    # investment mode on each node. (One alternative could be to build variables iteratively with 
    # JuMPUtils.jl)
    constraints_transmission_invest(m, 𝒯, 𝒞ℳ, modeltype)
end


"""
    constraints_transmission_invest(m, 𝒯, 𝒞ℳ, modeltype::InvestmentModel)
Set capacity-related constraints for `TransmissionMode`s `𝒞ℳ` for investment time structure `𝒯`:
* bounds
* binary for BinaryInvestment
* link capacity variables

"""
function constraints_transmission_invest(m, 𝒯, 𝒞ℳ, modeltype::InvestmentModel)
    
    𝒯ᴵⁿᵛ  = strategic_periods(𝒯)
    𝒞ℳᴵⁿᵛ = has_investment(𝒞ℳ)
    
    # Constraints capex
    for t_inv ∈ 𝒯ᴵⁿᵛ, cm ∈ 𝒞ℳᴵⁿᵛ 
        set_capacity_cost(m, cm, 𝒯, t_inv, modeltype)
    end

    # Set investment properties based on investment mode of `TransmissionMode` cm
    for t_inv ∈ 𝒯ᴵⁿᵛ, cm ∈ 𝒞ℳᴵⁿᵛ 
        set_investment_properties(cm, m[:trans_invest_b][cm, t_inv])  
    end

    # Link capacity to installed capacity 
    for cm ∈ 𝒞ℳᴵⁿᵛ
        for t_inv ∈ 𝒯ᴵⁿᵛ, t ∈ t_inv
            @constraint(m, m[:trans_cap][cm, t] == m[:trans_cap_current][cm, t_inv])
        end
    end
    for cm ∈ setdiff(𝒞ℳ, 𝒞ℳᴵⁿᵛ)
        for t ∈ 𝒯
            @constraint(m, m[:trans_cap][cm, t] == cm.Trans_cap[t])
        end
    end

    # Transmission capacity updating
    for cm ∈ 𝒞ℳᴵⁿᵛ
        for t_inv ∈ 𝒯ᴵⁿᵛ
            start_cap = get_start_cap(cm, t_inv, cm.Data["Investments"].Trans_start)
            @constraint(m, m[:trans_cap_current][cm, t_inv] <=
                                cm.Data["Investments"].Trans_max_inst[t_inv])
            @constraint(m, m[:trans_cap_current][cm, t_inv] ==
                (TS.isfirst(t_inv) ? start_cap : m[:trans_cap_current][cm, previous(t_inv,𝒯)])
                + m[:trans_cap_add][cm, t_inv] 
                - (TS.isfirst(t_inv) ? 0 : m[:trans_cap_rem][cm, previous(t_inv,𝒯)]))
        end
        set_trans_cap_installation(m, cm, 𝒯ᴵⁿᵛ)
    end
end

function get_start_cap(cm::GEO.TransmissionMode, t, ::Nothing)
    return cm.Trans_cap[t]
end

"""
    set_trans_cap_installation(m, cm, 𝒯ᴵⁿᵛ, investmentmode)

Add constraints related to capacity installation depending on investment mode of
`TransmissionMode` cm.
"""
set_trans_cap_installation(m, cm, 𝒯ᴵⁿᵛ) = 
    set_trans_cap_installation(m, cm, 𝒯ᴵⁿᵛ, investmentmode(cm))
function set_trans_cap_installation(m, cm, 𝒯ᴵⁿᵛ, investmentmode)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:trans_cap_add][cm, t_inv] <= 
                            cm.Data["Investments"].Trans_max_add[t_inv])
        @constraint(m, m[:trans_cap_add][cm, t_inv] >=
                            cm.Data["Investments"].Trans_min_add[t_inv])
        @constraint(m, m[:trans_cap_rem][cm, t_inv] == 0)
    end
end

function set_trans_cap_installation(m, cm, 𝒯ᴵⁿᵛ, ::BinaryInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:trans_cap_current][cm, t_inv] ==
                            cm.Trans_cap[t_inv] * m[:trans_invest_b][cm, t_inv]) 
    end
end

function set_trans_cap_installation(m, cm, 𝒯ᴵⁿᵛ, ::DiscreteInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        set_investment_properties( cm, m[:trans_remove_b][cm, t_inv])
        @constraint(m, m[:trans_cap_add][cm, t_inv] == 
                            cm.Data["Investments"].Trans_increment[t_inv]
                            * m[:trans_invest_b][cm, t_inv])
        @constraint(m, m[:trans_cap_rem][cm, t_inv] == 
                            cm.Data["Investments"].Trans_increment[t_inv]
                            * m[:trans_remove_b][cm, t_inv])
    end
end

function set_trans_cap_installation(m, cm, 𝒯ᴵⁿᵛ, investment_mode::SemiContiInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        # Disjunctive constraints when investing
        @constraint(m, m[:trans_cap_add][cm, t_inv] <=
                            cm.Data["Investments"].Trans_max_add[t_inv]
                            * m[:trans_invest_b][cm, t_inv]) 
        @constraint(m, m[:trans_cap_add][cm, t_inv] >=
                            cm.Data["Investments"].Trans_min_add[t_inv]
                            * m[:trans_invest_b][cm, t_inv]) 
        @constraint(m, m[:trans_cap_rem][cm, t_inv] == 0)
    end
end

function set_trans_cap_installation(m, cm, 𝒯ᴵⁿᵛ, ::FixedInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:trans_cap_current][cm, t_inv] ==
                            cm.Trans_cap[t_inv] * m[:trans_invest_b][cm, t_inv])
    end
end


"""
    set_capacity_cost(m, cm::GEO.TransmissionMode, 𝒯, t_inv, modeltype)
Set `capex_trans` based on the technology investment cost to include the potential for either
semi continuous costs with offsets or piecewise linear costs. 
It implements different versions of cost calculations:
- `Investment`: The cost is linear dependent on the installed capacity. This is the default
for all invcestment options
- `SemiContinuousOffsetInvestment`: The cost is linear dependent on the added capacity with a
given offset
"""
set_capacity_cost(m, cm::GEO.TransmissionMode, 𝒯, t_inv, modeltype) = set_capacity_cost(m, cm, 𝒯, t_inv, modeltype, investmentmode(cm))

function set_capacity_cost(m, cm::GEO.TransmissionMode, 𝒯, t_inv, modeltype, investment_mode::Investment)
    @constraint(m, m[:capex_trans][cm, t_inv] ==
                        cm.Data["Investments"].Capex_trans[t_inv]
                        * m[:trans_cap_add][cm, t_inv])
end

function set_capacity_cost(m, cm::GEO.TransmissionMode, 𝒯, t_inv, modeltype, investment_mode::SemiContinuousOffsetInvestment)
    @constraint(m, m[:capex_trans][cm, t_inv] ==
                        cm.Data["Investments"].Capex_trans[t_inv] * m[:trans_cap_add][cm, t_inv] + 
                        cm.Data["Investments"].Capex_trans_offset[t_inv] * m[:trans_invest_b][cm, t_inv])
end
