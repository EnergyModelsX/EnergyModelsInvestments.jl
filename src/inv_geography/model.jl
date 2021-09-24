const GEO = Geography

function GEO.variables_capex_transmission(m, 𝒯, ℒᵗʳᵃⁿˢ, ::InvestmentModel)

    ℒᵗʳᵃⁿˢᴵⁿᵛ = (i for i ∈ ℒᵗʳᵃⁿˢ if has_trans_investment(i))
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m, capex_trans[l ∈ ℒᵗʳᵃⁿˢᴵⁿᵛ,  𝒯ᴵⁿᵛ, corridor_modes_with_inv(l)]  >= 0)
end

function GEO.variables_transmission(m, 𝒯, ℒᵗʳᵃⁿˢ, ::InvestmentModel)
    @variable(m, trans_in[l ∈ ℒᵗʳᵃⁿˢ,  𝒯, GEO.corridor_modes(l)] >= 0)
    @variable(m, trans_out[l ∈ ℒᵗʳᵃⁿˢ, 𝒯, GEO.corridor_modes(l)] >= 0)
    @variable(m, trans_loss[l ∈ ℒᵗʳᵃⁿˢ, 𝒯, GEO.corridor_modes(l)] >= 0)
    @variable(m, trans_cap[l ∈ ℒᵗʳᵃⁿˢ, 𝒯, GEO.corridor_modes(l)] >= 0)

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m, trans_invest[l ∈ ℒᵗʳᵃⁿˢ, 𝒯ᴵⁿᵛ, GEO.corridor_modes(l)])
    @variable(m, trans_remove[l ∈ ℒᵗʳᵃⁿˢ, 𝒯ᴵⁿᵛ, GEO.corridor_modes(l)])
    @variable(m, trans_capacity[l ∈ ℒᵗʳᵃⁿˢ, 𝒯ᴵⁿᵛ, GEO.corridor_modes(l)] >= 0)        # Installed capacity
    @variable(m, trans_cap_add[l ∈ ℒᵗʳᵃⁿˢ, 𝒯ᴵⁿᵛ, GEO.corridor_modes(l)]  >= 0)        # Add capacity
    @variable(m, trans_cap_rem[l ∈ ℒᵗʳᵃⁿˢ, 𝒯ᴵⁿᵛ, GEO.corridor_modes(l)]  >= 0)        # Remove capacity
end


function GEO.constraints_transmission(m, 𝒜, 𝒯, ℒᵗʳᵃⁿˢ, ::InvestmentModel)

    ℒᵗʳᵃⁿˢᴵⁿᵛ = (i for i ∈ ℒᵗʳᵃⁿˢ if has_trans_investment(i))
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    for l ∈ ℒᵗʳᵃⁿˢᴵⁿᵛ, t_inv ∈ 𝒯ᴵⁿᵛ, cm ∈ corridor_modes_with_inv(l) 
        @constraint(m, m[:capex_trans][l, t_inv, cm] == l.Data[get_cm_index(cm,l)]["InvestmentModels"].Capex_trans[t_inv] * m[:trans_cap_add][l, t_inv, cm])
    end

    for l ∈ ℒᵗʳᵃⁿˢᴵⁿᵛ, t_inv ∈ 𝒯ᴵⁿᵛ, cm ∈ corridor_modes_with_inv(l) 
        set_investment_properties(l, cm, m[:trans_invest][l, t_inv,cm])  
    end

    for l ∈ ℒᵗʳᵃⁿˢ, cm ∈ GEO.corridor_modes(l)
        CM_inv = corridor_modes_with_inv(l) 
        if cm ∈ CM_inv
            for t_inv ∈ 𝒯ᴵⁿᵛ
                for t ∈ t_inv
                    @constraint(m, m[:trans_cap][l, t, cm] == m[:trans_capacity][l, t_inv, cm])
                end
            end
        else
            for t in 𝒯
                @constraint(m, m[:trans_cap][l, t, cm] == cm.capacity)
            end
        end
    end

    # Transmission capacity updating
    for l ∈ ℒᵗʳᵃⁿˢᴵⁿᵛ, cm ∈ corridor_modes_with_inv(l)
        for t_inv ∈ 𝒯ᴵⁿᵛ
            start_cap= get_start_cap(cm, t_inv, l.Data[get_cm_index(cm, l)]["InvestmentModels"].Trans_start)
            @constraint(m, m[:trans_capacity][l, t_inv, cm] <= l.Data[get_cm_index(cm,l)]["InvestmentModels"].Trans_max_inst[t_inv])
            @constraint(m, m[:trans_capacity][l, t_inv, cm] ==
                (TS.isfirst(t_inv) ? start_cap : m[:trans_capacity][l, previous(t_inv,𝒯), cm])
                + m[:trans_cap_add][l, t_inv, cm] 
                - (TS.isfirst(t_inv) ? 0 : m[:trans_cap_rem][l, previous(t_inv,𝒯), cm]))
        end
        set_transcap_installation(m, l, 𝒯ᴵⁿᵛ, cm)
    end

    for a ∈ 𝒜
        ℒᶠʳᵒᵐ, ℒᵗᵒ = GEO.trans_sub(ℒᵗʳᵃⁿˢ, a)
        @constraint(m, [t ∈ 𝒯, p ∈ GEO.export_resources(ℒᵗʳᵃⁿˢ, a)], 
            m[:area_export][a, t, p] == sum(sum(m[:trans_in][l, t, cm] for cm in l.modes if cm.resource == p) for l in ℒᶠʳᵒᵐ))
        @constraint(m, [t ∈ 𝒯, p ∈ GEO.import_resources(ℒᵗʳᵃⁿˢ, a)], 
            m[:area_import][a, t, p] == sum(sum(m[:trans_out][l, t, cm] for cm in l.modes if cm.resource == p) for l in ℒᵗᵒ ))
    end

    for l in ℒᵗʳᵃⁿˢ
        GEO.create_trans(m, 𝒯, l)
    end

end

function get_start_cap(cm::GEO.TransmissionMode, t, ::Nothing)
    if cm.capacity isa Base.Real
        return cm.capacity
    elseif cm.capacity isa TimeStructures.TimeProfile
        return TimeStructures.getindex(cm.capacity,t)
    else 
        print("Type error of cm.capacity")
    end
end

investmentmode(cm::GEO.TransmissionMode,l::GEO.Transmission) = l.Data[get_cm_index(cm, l)]["InvestmentModels"].Inv_mode

set_transcap_installation(m, l, 𝒯ᴵⁿᵛ, cm) = set_transcap_installation(m, l, 𝒯ᴵⁿᵛ, cm, investmentmode(cm,l))
function set_transcap_installation(m, l, 𝒯ᴵⁿᵛ, cm, investmentmode)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:trans_cap_add][l, t_inv, cm] <= l.Data[get_cm_index(cm, l)]["InvestmentModels"].Trans_max_add[t_inv])
        @constraint(m, m[:trans_cap_add][l, t_inv, cm] >= l.Data[get_cm_index(cm, l)]["InvestmentModels"].Trans_min_add[t_inv])
        @constraint(m, m[:trans_cap_rem][l, t_inv, cm] == 0)
    end
end

function set_capacity_installation(m, l, 𝒯ᴵⁿᵛ, cm, ::DiscreteInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:trans_capacity][l, t_inv, cm] == cm.capacity[t_inv] * m[:trans_invest][l, t_inv]) 
    end
end

function set_capacity_installation(m, l, 𝒯ᴵⁿᵛ, cm, ::IntegerInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        set_investment_properties(l, cm, m[:trans_remove][l,t_inv,cm])
        @constraint(m, m[:trans_cap_add][l, t_inv, cm] == l.Data[get_cm_index(cm, l)]["InvestmentModels"].Trans_increment[t_inv] * m[:trans_invest][l, t_inv, cm])
        @constraint(m, m[:trans_cap_rem][l, t_inv, cm] == l.Data[get_cm_index(cm, l)]["InvestmentModels"].Trans_increment[t_inv] * m[:trans_remove][l, t_inv, cm])
    end
end

function set_capacity_installation(m, l, 𝒯ᴵⁿᵛ, cm, ::SemiContinuousInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:trans_cap_add][l, t_inv, cm] <= l.Data[get_cm_index(cm, l)]["InvestmentModels"].Trans_max_add[t_inv] )
        @constraint(m, m[:trans_cap_add][l, t_inv, cm] >= l.Data[get_cm_index(cm, l)]["InvestmentModels"].Trans_min_add[t_inv] * m[:trans_invest][l, t_inv, cm]) 
        @constraint(m, m[:trans_cap_rem][l, t_inv, cm] == 0)
    end
end

function set_capacity_installation(m, l, 𝒯ᴵⁿᵛ, cm, ::FixedInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:trans_capacity][l, t_inv, cm] == cm.capacity[t_inv] * m[:trans_invest][l, t_inv, cm])
    end
end

set_investment_properties(l::GEO.Transmission, cm::GEO.TransmissionMode, var) = set_investment_properties(l, cm, var, investmentmode(cm, l))
function set_investment_properties(l, cm, var, mode)
    set_lower_bound(var, 0)
end

function set_investment_properties(l, cm, var, ::DiscreteInvestment)
    JuMP.set_binary(var)
end

function set_investment_properties(l, cm, var, ::SemiContinuousInvestment)
    JuMP.set_binary(var)
end
    
function set_investment_properties(l, cm, var, ::IndividualInvestment)
    dispatch_mode = l.Data[get_cm_index(cm, l)]["InvestmentModels"].Inv_mode
    set_investment_properties(l, cm, var, dispatch_mode)
end

function set_investment_properties(l, cm, var, ::FixedInvestment) # TO DO
    JuMP.fix(var, 1)
end

function set_investment_properties(l, cm, var, ::IntegerInvestment) # TO DO
    JuMP.set_integer(var)
    JuMP.set_lower_bound(var,0)
end


function GEO.update_objective(m, 𝒩, 𝒯, 𝒫, ℒᵗʳᵃⁿˢ, ::InvestmentModel)

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    ℒᵗʳᵃⁿˢᴵⁿᵛ = (i for i ∈ ℒᵗʳᵃⁿˢ if has_trans_investment(i))
    r= modeltype.r

    obj= JuMP.objective_function(m)
    if haskey(m, :capex_trans) && isempty(ℒᵗʳᵃⁿˢᴵⁿᵛ) == false
        for l ∈ ℒᵗʳᵃⁿˢᴵⁿᵛ, t ∈  𝒯ᴵⁿᵛ, cm ∈ corridor_modes_with_inv(l)
            obj += obj_weight_inv(r, 𝒯, t) * m[:capex_trans][l,t,cm] 
        end
    end

    @objective(m, Max, obj)

end