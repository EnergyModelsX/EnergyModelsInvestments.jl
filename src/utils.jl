"""
    investment_mode(type)

Return the investment mode of the type `type`. By default, all investments are continuous.
"""
investment_mode(type) = investment_data(type).inv_mode

"""
    investment_mode(type, field::Symbol)

Return the investment mode of the type `type` and the capacity `field`.
"""
investment_mode(type, field::Symbol) = investment_mode(investment_data(type, field))

"""
    start_cap(type, t_inv, inv_data::GeneralInvData, field)

Returns the starting capacity of the node in the first investment period.
If [`NoStartInvData`](@ref) is used for the starting capacity, it deduces the value from the
provided initial capacity.
"""
start_cap(type, t_inv, inv_data::StartInvData, field) =
    inv_data.initial
start_cap(type, t_inv, inv_data::NoStartInvData, field) =
    capacity(type, t_inv)
start_cap(n::Storage, t_inv, inv_data::NoStartInvData, field) =
    capacity(getproperty(n, field), t_inv)

"""
    get_var_capex(m, prefix::Symbol)

Extracts the CAPEX variable with a given `prefix` from the model.
"""
get_var_capex(m, prefix::Symbol) = m[Symbol(prefix, :_capex)]
"""
    get_var_capex(m, prefix::Symbol, type)

When the node `type` is used as conditional input, it extracts only the variable for
the specified node.
"""
get_var_capex(m, prefix::Symbol, type)  = m[Symbol(prefix, :_capex)][type, :]

"""
    get_var_inst(m, prefix::Symbol)

Extracts the installed capacity variable with a given `prefix` from the model.
"""
get_var_inst(m, prefix::Symbol) = m[Symbol(prefix, :_inst)]
"""
    get_var_inst(m, prefix::Symbol, type)

When the node `type` is used as conditional input, it extracts only the variable for
the specified node.
"""
get_var_inst(m, prefix::Symbol, type)  = m[Symbol(prefix, :_inst)][type, :]

"""
    get_var_current(m, prefix::Symbol)

Extracts the current capacity variable with a given `prefix` from the model.
"""
get_var_current(m, prefix::Symbol) = m[Symbol(prefix, :_current)]
"""
    get_var_current(m, prefix::Symbol, type)

When the node `type` is used as conditional input, it extracts only the variable for
the specified node.
"""
get_var_current(m, prefix::Symbol, type)  = m[Symbol(prefix, :_current)][type, :]

"""
    get_var_add(m, prefix::Symbol)

Extracts the investment capacity variable with a given `prefix` from the model.
"""
get_var_add(m, prefix::Symbol) = m[Symbol(prefix, :_add)]
"""
    get_var_add(m, prefix::Symbol, type)

When the node `type` is used as conditional input, it extracts only the variable for
the specified node.
"""
get_var_add(m, prefix::Symbol, type)  = m[Symbol(prefix, :_add)][type, :]

"""
    get_var_rem(m, prefix::Symbol)

Extracts the retired capacity variable with a given `prefix` from the model.
"""
get_var_rem(m, prefix::Symbol) = m[Symbol(prefix, :_rem)]
"""
    get_var_rem(m, prefix::Symbol, type)

When the node `type` is used as conditional input, it extracts only the variable for
the specified node.
"""
get_var_rem(m, prefix::Symbol, type)  = m[Symbol(prefix, :_rem)][type, :]

"""
    get_var_invest_b(m, prefix::Symbol)

Extracts the binary investment variable with a given `prefix` from the model.
"""
get_var_invest_b(m, prefix::Symbol) = m[Symbol(prefix, :_invest_b)]
"""
    get_var_invest_b(m, prefix::Symbol, type)

When the node `type` is used as conditional input, it extracts only the variable for
the specified node.
"""
get_var_invest_b(m, prefix::Symbol, type)  = m[Symbol(prefix, :_invest_b)][type, :]

"""
    get_var_remove_b(m, prefix::Symbol)

Extracts the binary retirement variable with a given `prefix` from the model.
"""
get_var_remove_b(m, prefix::Symbol) = m[Symbol(prefix, :_remove_b)]
"""
    get_var_remove_b(m, prefix::Symbol, type)

When the node `type` is used as conditional input, it extracts only the variable for
the specified node.
"""
get_var_remove_b(m, prefix::Symbol, type)  = m[Symbol(prefix, :_remove_b)][type, :]

"""
    set_capex_value(m, type, inv_data, prefix, 𝒯ᴵⁿᵛ)

Calculate the cost value for the different investment modes of the investment data
`inv_data` for type `type`.

# Arguments
- `m`: the JuMP model instance.
- `type`: the type for which the absolute CAPEX should be calculated.
- `r`: the discount rate.
- `inv_data`: the investment data given as subtype of `GeneralInvData`.
- `prefix`: the prefix used for variables for this type.
- `𝒯ᴵⁿᵛ`: the strategic periods structure.
"""
set_capex_value(m, type, inv_data, prefix, 𝒯ᴵⁿᵛ) =
    set_capex_value(m, type, inv_data, prefix, 𝒯ᴵⁿᵛ, investment_mode(inv_data))

"""
    set_capex_value(m, type, inv_data, prefix, 𝒯ᴵⁿᵛ, ::Investment)

When no specialized method is defined for the investment mode, it calculates the capital
cost based on the multiplication of the field `capex` in `inv_data` with the added capacity.
"""
function set_capex_value(m, type, inv_data, prefix, 𝒯ᴵⁿᵛ, ::Investment)
    # Deduce the required variable
    var_add = get_var_add(m, prefix, type)

    return @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], capex(inv_data, t_inv) * var_add[t_inv])
end

"""
    set_capex_value(m, type, inv_data, prefix, 𝒯ᴵⁿᵛ, ::SemiContinuousOffsetInvestment)

When the investment mode is given by [`SemiContinuousOffsetInvestment`](@ref) then there is
an additional offset for the CAPEX.
"""
function set_capex_value(m, type, inv_data, prefix, 𝒯ᴵⁿᵛ, inv_mode::SemiContinuousOffsetInvestment)
    # Deduce the required variables
    var_add = get_var_add(m, prefix, type)
    var_invest_b = get_var_invest_b(m, prefix)

    return @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        capex(inv_data, t_inv) * var_add[t_inv] +
        capex_offset(inv_mode, t_inv) * var_invest_b[type, t_inv]
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
- `lifetime`: the lifetime of the ttype.
- `disc_rate`: the discount rate.
"""
function set_capex_discounter(years, lifetime, disc_rate)
    N_inv = ceil(years/lifetime)
    capex_disc = sum((1+disc_rate)^(-n_inv * lifetime) for n_inv ∈ 0:N_inv-1) -
                 ((N_inv * lifetime - years)/lifetime) * (1+disc_rate)^(-years)
    return capex_disc
end
