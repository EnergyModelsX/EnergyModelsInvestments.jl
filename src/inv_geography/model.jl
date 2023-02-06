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
    𝒯ᴵⁿᵛ        = strategic_periods(𝒯)
    ℒᵗʳᵃⁿˢᴵⁿᵛ   = (i for i ∈ ℒᵗʳᵃⁿˢ if has_trans_investment(i))
    r           = modeltype.r
    obj = JuMP.objective_function(m)

    # Update of teh cost function for modes with winvestments
    if haskey(m, :capex_trans) && isempty(ℒᵗʳᵃⁿˢᴵⁿᵛ) == false
        for l ∈ ℒᵗʳᵃⁿˢᴵⁿᵛ, t ∈  𝒯ᴵⁿᵛ, cm ∈ corridor_modes_with_inv(l)
            obj -= obj_weight_inv(r, 𝒯, t) * m[:capex_trans][l,t,cm] 
        end
    end

    @objective(m, Max, obj)

end

"""
    GEO.variables_capex_transmission(m, 𝒯, ℒᵗʳᵃⁿˢ,, modeltype::InvestmentModel)

Create variables for the capital costs for the investments in transmission.
"""
function GEO.variables_capex_transmission(m, 𝒯, ℒᵗʳᵃⁿˢ, modeltype::InvestmentModel)

    ℒᵗʳᵃⁿˢᴵⁿᵛ   = (i for i ∈ ℒᵗʳᵃⁿˢ if has_trans_investment(i))
    𝒯ᴵⁿᵛ        = strategic_periods(𝒯)

    @variable(m, capex_trans[l ∈ ℒᵗʳᵃⁿˢᴵⁿᵛ,  𝒯ᴵⁿᵛ, corridor_modes_with_inv(l)]  >= 0)
end

"""
    GEO.variables_transmission(m, 𝒯, ℒᵗʳᵃⁿˢ, modeltype::InvestmentModel)

Create variables to track how much of installed transmision capacity is used for all 
time periods `t ∈ 𝒯` and how much energy is lossed.
Create variables for investments into transmission.
"""
function GEO.variables_transmission(m, 𝒯, ℒᵗʳᵃⁿˢ, modeltype::InvestmentModel)

    
    @variable(m, trans_in[l ∈ ℒᵗʳᵃⁿˢ,  𝒯, GEO.corridor_modes(l)])
    @variable(m, trans_out[l ∈ ℒᵗʳᵃⁿˢ, 𝒯, GEO.corridor_modes(l)])
    @variable(m, trans_loss[l ∈ ℒᵗʳᵃⁿˢ, 𝒯, GEO.corridor_modes(l)] >= 0)
    @variable(m, trans_cap[l ∈ ℒᵗʳᵃⁿˢ, 𝒯, GEO.corridor_modes(l)] >= 0)
    @variable(m, trans_loss_neg[l ∈ ℒᵗʳᵃⁿˢ, 𝒯, GEO.modes_of_dir(l, 2)] >= 0)
    @variable(m, trans_loss_pos[l ∈ ℒᵗʳᵃⁿˢ, 𝒯, GEO.modes_of_dir(l, 2)] >= 0)

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Add transmission specific investment variables for each strategic period:
    @variable(m, trans_invest_b[l ∈ ℒᵗʳᵃⁿˢ, 𝒯ᴵⁿᵛ, GEO.corridor_modes(l)])
    @variable(m, trans_remove_b[l ∈ ℒᵗʳᵃⁿˢ, 𝒯ᴵⁿᵛ, GEO.corridor_modes(l)])
    @variable(m, trans_cap_current[l ∈ ℒᵗʳᵃⁿˢ, 𝒯ᴵⁿᵛ, GEO.corridor_modes(l)] >= 0)        # Installed capacity
    @variable(m, trans_cap_add[l ∈ ℒᵗʳᵃⁿˢ, 𝒯ᴵⁿᵛ, GEO.corridor_modes(l)]  >= 0)        # Add capacity
    @variable(m, trans_cap_rem[l ∈ ℒᵗʳᵃⁿˢ, 𝒯ᴵⁿᵛ, GEO.corridor_modes(l)]  >= 0)        # Remove capacity
    

    # Additional constraints (e.g. for binary investments) are added per node depending on 
    # investment mode on each node. (One alternative could be to build variables iteratively with 
    # JuMPUtils.jl)
    constraints_transmission_invest(m, 𝒯, ℒᵗʳᵃⁿˢ)
end


"""
    constraints_transmission_invest(m, 𝒯, ℒᵗʳᵃⁿˢ)
Set capacity-related constraints for transmissions `ℒᵗʳᵃⁿˢ` for investment time structure `𝒯`:
* bounds
* binary for BinaryInvestment
* link capacity variables

"""
function constraints_transmission_invest(m, 𝒯, ℒᵗʳᵃⁿˢ)
    
    ℒᵗʳᵃⁿˢᴵⁿᵛ = (i for i ∈ ℒᵗʳᵃⁿˢ if has_trans_investment(i))
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Constraints capex
    for l ∈ ℒᵗʳᵃⁿˢᴵⁿᵛ, t_inv ∈ 𝒯ᴵⁿᵛ, cm ∈ corridor_modes_with_inv(l) 
        @constraint(m, m[:capex_trans][l, t_inv, cm] ==
                            l.Data["Investments"][cm].Capex_trans[t_inv]
                            * m[:trans_cap_add][l, t_inv, cm])
    end

    # Set investment properties based on investment mode of transmission l
    for l ∈ ℒᵗʳᵃⁿˢᴵⁿᵛ, t_inv ∈ 𝒯ᴵⁿᵛ, cm ∈ corridor_modes_with_inv(l) 
        set_investment_properties(l, cm, m[:trans_invest_b][l, t_inv, cm])  
    end

    # Link capacity to installed capacity 
    for l ∈ ℒᵗʳᵃⁿˢ, cm ∈ GEO.corridor_modes(l)
        CM_inv = corridor_modes_with_inv(l) 
        if cm ∈ CM_inv
            for t_inv ∈ 𝒯ᴵⁿᵛ
                for t ∈ t_inv
                    @constraint(m, m[:trans_cap][l, t, cm] == m[:trans_cap_current][l, t_inv, cm])
                end
            end
        else
            for t in 𝒯
                @constraint(m, m[:trans_cap][l, t, cm] == cm.Trans_cap)
            end
        end
    end

    # Transmission capacity updating
    for l ∈ ℒᵗʳᵃⁿˢᴵⁿᵛ, cm ∈ corridor_modes_with_inv(l)
        for t_inv ∈ 𝒯ᴵⁿᵛ
            start_cap = get_start_cap(cm, t_inv, l.Data["Investments"][cm].Trans_start)
            @constraint(m, m[:trans_cap_current][l, t_inv, cm] <=
                                l.Data["Investments"][cm].Trans_max_inst[t_inv])
            @constraint(m, m[:trans_cap_current][l, t_inv, cm] ==
                (TS.isfirst(t_inv) ? start_cap : m[:trans_cap_current][l, previous(t_inv,𝒯), cm])
                + m[:trans_cap_add][l, t_inv, cm] 
                - (TS.isfirst(t_inv) ? 0 : m[:trans_cap_rem][l, previous(t_inv,𝒯), cm]))
        end
        set_trans_cap_installation(m, l, 𝒯ᴵⁿᵛ, cm)
    end
end

function get_start_cap(cm::GEO.TransmissionMode, t, ::Nothing)
    if cm.Trans_cap isa Base.Real
        return cm.Trans_cap
    elseif cm.Trans_cap isa TimeStructures.TimeProfile
        return TimeStructures.getindex(cm.Trans_cap,t)
    else 
        print("Type error of cm.Trans_cap")
    end
end

"""
    set_trans_cap_installation(m, l, 𝒯ᴵⁿᵛ, cm, investmentmode)

Add constraints related to capacity installation depending on investment mode of
`TransmissionMode` cm of `Transmission` l.
"""
set_trans_cap_installation(m, l, 𝒯ᴵⁿᵛ, cm) = 
    set_trans_cap_installation(m, l, 𝒯ᴵⁿᵛ, cm, investmentmode(cm,l))
function set_trans_cap_installation(m, l, 𝒯ᴵⁿᵛ, cm, investmentmode)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:trans_cap_add][l, t_inv, cm] <= 
                            l.Data["Investments"][cm].Trans_max_add[t_inv])
        @constraint(m, m[:trans_cap_add][l, t_inv, cm] >=
                            l.Data["Investments"][cm].Trans_min_add[t_inv])
        @constraint(m, m[:trans_cap_rem][l, t_inv, cm] == 0)
    end
end

function set_trans_cap_installation(m, l, 𝒯ᴵⁿᵛ, cm, ::BinaryInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:trans_cap_current][l, t_inv, cm] ==
                            cm.Trans_cap[t_inv] * m[:trans_invest_b][l, t_inv]) 
    end
end

function set_trans_cap_installation(m, l, 𝒯ᴵⁿᵛ, cm, ::DiscreteInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        set_investment_properties(l, cm, m[:trans_remove_b][l,t_inv,cm])
        @constraint(m, m[:trans_cap_add][l, t_inv, cm] == 
                            l.Data["Investments"][cm].Trans_increment[t_inv]
                            * m[:trans_invest_b][l, t_inv, cm])
        @constraint(m, m[:trans_cap_rem][l, t_inv, cm] == 
                            l.Data["Investments"][cm].Trans_increment[t_inv]
                            * m[:trans_remove_b][l, t_inv, cm])
    end
end

function set_trans_cap_installation(m, l, 𝒯ᴵⁿᵛ, cm, ::SemiContinuousInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        # Disjunctive constraints when investing
        @constraint(m, m[:trans_cap_add][l, t_inv, cm] <=
                            l.Data["Investments"][cm].Trans_max_add[t_inv]
                            * m[:trans_invest_b][l, t_inv, cm]) 
        @constraint(m, m[:trans_cap_add][l, t_inv, cm] >=
                            l.Data["Investments"][cm].Trans_min_add[t_inv]
                            * m[:trans_invest_b][l, t_inv, cm]) 
        @constraint(m, m[:trans_cap_rem][l, t_inv, cm] == 0)
    end
end

function set_trans_cap_installation(m, l, 𝒯ᴵⁿᵛ, cm, ::FixedInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:trans_cap_current][l, t_inv, cm] ==
                            cm.Trans_cap[t_inv] * m[:trans_invest_b][l, t_inv, cm])
    end
end

"""
    set_investment_properties(l, cm, var, mode)
Set investment properties for variable `var` for transmission `l` and transmision mode (cm),
e.g. set to binary for BinaryInvestment, 
bounds etc
"""
set_investment_properties(l::GEO.Transmission, cm::GEO.TransmissionMode, var) =
    set_investment_properties(l, cm, var, investmentmode(cm, l))
function set_investment_properties(l, cm, var, mode)
    set_lower_bound(var, 0)
end

function set_investment_properties(l, cm, var, ::BinaryInvestment)
    JuMP.set_binary(var)
end

function set_investment_properties(l, cm, var, ::SemiContinuousInvestment)
    JuMP.set_binary(var)
end
    
function set_investment_properties(l, cm, var, ::FixedInvestment) # TO DO
    JuMP.fix(var, 1)
end

function set_investment_properties(l, cm, var, ::DiscreteInvestment) # TO DO
    JuMP.set_integer(var)
    JuMP.set_lower_bound(var,0)
end
