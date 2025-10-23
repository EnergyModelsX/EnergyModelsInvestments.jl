"""
    get_var_capex(m, prefix::Symbol)
    get_var_capex(m, prefix::Symbol, element)

Extracts the CAPEX variable with a given `prefix` from the model or only the variable for
    the specified `element`.
"""
get_var_capex(m, prefix::Symbol) = m[Symbol(prefix, :_capex)]
get_var_capex(m, prefix::Symbol, element) = m[Symbol(prefix, :_capex)][element, :]

"""
    get_var_inst(m, prefix::Symbol)
    get_var_inst(m, prefix::Symbol, element)

Extracts the installed capacity variable with a given `prefix` from the model or only the
variable for the specified `element`.
"""
get_var_inst(m, prefix::Symbol) = m[Symbol(prefix, :_inst)]
get_var_inst(m, prefix::Symbol, element) = m[Symbol(prefix, :_inst)][element, :]

"""
    get_var_current(m, prefix::Symbol)
    get_var_current(m, prefix::Symbol, element)

Extracts the current capacity variable with a given `prefix` from the model or only the
variable for the specified `element`.
"""
get_var_current(m, prefix::Symbol) = m[Symbol(prefix, :_current)]
get_var_current(m, prefix::Symbol, element) = m[Symbol(prefix, :_current)][element, :]

"""
    get_var_add(m, prefix::Symbol)
    get_var_add(m, prefix::Symbol, element)

Extracts the investment capacity variable with a given `prefix` from the model or only the
variable for the specified `element`.
"""
get_var_add(m, prefix::Symbol) = m[Symbol(prefix, :_add)]
get_var_add(m, prefix::Symbol, element) = m[Symbol(prefix, :_add)][element, :]

"""
    get_var_rem(m, prefix::Symbol)
    get_var_rem(m, prefix::Symbol, element)

Extracts the retired capacity variable with a given `prefix` from the model or only the
variable for the specified `element`.
"""
get_var_rem(m, prefix::Symbol) = m[Symbol(prefix, :_rem)]
get_var_rem(m, prefix::Symbol, element) = m[Symbol(prefix, :_rem)][element, :]

"""
    get_var_invest_b(m, prefix::Symbol)
    get_var_invest_b(m, prefix::Symbol, element)

Extracts the binary investment variable with a given `prefix` from the model or only the
variable for the specified `element`.
"""
get_var_invest_b(m, prefix::Symbol) = m[Symbol(prefix, :_invest_b)]
get_var_invest_b(m, prefix::Symbol, element) = m[Symbol(prefix, :_invest_b)][element, :]

"""
    get_var_remove_b(m, prefix::Symbol)
    get_var_remove_b(m, prefix::Symbol, element)

Extracts the binary retirement variable with a given `prefix` from the model or only the
variable for the specified `element`.
"""
get_var_remove_b(m, prefix::Symbol) = m[Symbol(prefix, :_remove_b)]
get_var_remove_b(m, prefix::Symbol, element) = m[Symbol(prefix, :_remove_b)][element, :]

"""
    set_capex_value(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ)

Calculate the cost value for the different investment modes of the investment data
`inv_data` for element `element`.

# Arguments
- `m`: the JuMP model instance.
- `element`: the element type for which the absolute CAPEX should be calculated.
- `r`: the discount rate.
- `inv_data`: the investment data given as subtype of `AbstractInvData`.
- `prefix`: the prefix used for variables for this element.
- `𝒯ᴵⁿᵛ`: the strategic periods structure.
"""
set_capex_value(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ) =
    set_capex_value(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, investment_mode(inv_data))

"""
    set_capex_value(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, ::Investment)

When no specialized method is defined for the investment mode, it calculates the capital
cost based on the multiplication of the field `capex` in `inv_data` with the added capacity
extracted from the model through the function [`get_var_add`](@ref).
"""
function set_capex_value(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, ::Investment)
    # Deduce the required variable
    var_add = get_var_add(m, prefix, element)

    return @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], capex(inv_data, t_inv) * var_add[t_inv])
end

"""
    set_capex_value(m, element, inv_data, prefix, 𝒯ᴵⁿᵛ, inv_mode::SemiContinuousOffsetInvestment)

When the investment mode is given by [`SemiContinuousOffsetInvestment`](@ref) then there is
an additional offset for the CAPEX.
"""
function set_capex_value(
    m,
    element,
    inv_data,
    prefix,
    𝒯ᴵⁿᵛ,
    inv_mode::SemiContinuousOffsetInvestment,
)
    # Deduce the required variables
    var_add = get_var_add(m, prefix, element)
    var_invest_b = get_var_invest_b(m, prefix)

    return @expression(
        m,
        [t_inv ∈ 𝒯ᴵⁿᵛ],
        capex(inv_data, t_inv) * var_add[t_inv] +
        capex_offset(inv_mode, t_inv) * var_invest_b[element, t_inv]
    )
end

"""
    set_capex_discounter(years, lifetime, disc_rate)

Calculate the discounted values used in the lifetime calculations, when the `LifetimeMode`
is given by `PeriodLife` and `StudyLife`.

# Arguments
- `years:`: the remaining years for calculating the discounted value. The years are
  depending on the considered [`LifetimeMode`](@ref), using `remaining(t_inv, 𝒯)` for
  [`StudyLife`](@ref) and `duration(t_inv)` for [`PeriodLife`](@ref).
- `lifetime`: the lifetime of the element.
- `disc_rate`: the discount rate.
"""
function set_capex_discounter(years, lifetime, disc_rate)
    N_inv = ceil(years / lifetime)
    capex_disc =
        sum((1 + disc_rate)^(-n_inv * lifetime) for n_inv ∈ 0:N_inv-1) -
        ((N_inv * lifetime - years) / lifetime) * (1 + disc_rate)^(-years)
    return capex_disc
end

"""
    capacity_removal!(rem_dict::Dict, t_inv, lifetime_val, 𝒯ᴵⁿᵛ::TS.StratTreeNodes, disc_rate)
    capacity_removal!(rem_dict::Dict, t_inv, lifetime_val, 𝒯ᴵⁿᵛ::Union{TS.StratPers, TS.StrategicScenario}, disc_rate)

Update the dictionary used for calculation of capacity removal and return the value used for
discounting the investment costs given a lifetime differing from the resolution of the time
structure.

Both the dictionary and the discounting value take into account potentially differing
strategic durations in a [`TwoLevelTree`](@extref TimeStruct.TwoLevelTree) time structure.
"""
function capacity_removal!(rem_dict::Dict, t_inv, lifetime_val, 𝒯ᴵⁿᵛ::TS.StratPers, disc_rate)
    return _cap_rem!(rem_dict, t_inv, lifetime_val, 𝒯ᴵⁿᵛ, disc_rate)
end
function capacity_removal!(rem_dict::Dict, t_inv, lifetime_val, 𝒯ᴵⁿᵛ::TS.StratTreeNodes, disc_rate)

    strat_scens = strategic_scenarios(𝒯ᴵⁿᵛ.ts)
    disc_dict = Dict()
    for scen ∈ strat_scens
        sps = strategic_periods(scen)
        if t_inv ∈ sps
            disc_dict[scen] = _cap_rem!(rem_dict, t_inv, lifetime_val, sps, disc_rate)
        end
    end

    # Calculation of the averaged discounting factor considering different branches
    capex_disc = 0
    for (scen, disc) ∈ disc_dict
        capex_disc += disc * scen.probability
    end
    return capex_disc
end
function _cap_rem!(rem_dict::Dict, t_inv, lifetime_val, 𝒯ᴵⁿᵛ::Union{TS.StratPers, TS.ScenTreeNodes}, disc_rate)
    # Initialize the variables used for calculating the remaining life at the end of a
    # strategic period
    remaining_lifetime = lifetime_val
    t_inv_rem = t_inv
    bool_lifetime = true
    bool_shorter = true

    # Iterate through the strategic periods to identify the last period at which the
    # remaining life is larger or equal than the duration of the strategic period
    for sp ∈ 𝒯ᴵⁿᵛ
        if sp ≥ t_inv
            remaining_lifetime < duration_strat(sp) && break
            remaining_lifetime -= duration_strat(sp)
            t_inv_rem = sp
            bool_shorter = false
            if sp == last(𝒯ᴵⁿᵛ) && remaining_lifetime > 0
                bool_lifetime = false
            end
        end
    end
    bool_lifetime && push!(rem_dict[t_inv_rem], t_inv)

    # Calculation of discounting factor considering the salvage value
    if bool_shorter
        # If lifetime is shorter than the sp duration, we apply the method for PeriodLife
        # to account for the required reinvestments
        capex_disc = set_capex_discounter(duration_strat(t_inv), lifetime_val, disc_rate)
    else
        # If lifetime is equal or longer than sp duration, the discounting rate is including
        # a potential rest value, depending on the remaining lifetime at the end of the
        # last period it is active.
        capex_disc = (
            1 -
            (remaining_lifetime / lifetime_val) *
            (1 + disc_rate)^(-(lifetime_val - remaining_lifetime))
        )
    end
    return capex_disc
end
