"""
    investment_data(element)

Return the investment data of the element.

The default implementation results in an error as this function requires an additional
method for the individual elements.
"""
investment_data(element) = error(
    "The function `investment_data` is not implemented for $(typeof(element))",
)

"""
    start_cap(element, t_inv, inv_data::AbstractInvData, cap)

Returns the starting capacity of the type `element` in the first investment period.
If [`NoStartInvData`](@ref) is used for the starting capacity, it requires the definition
of a method for the corresponding `element`.
"""
start_cap(element, t_inv, inv_data::StartInvData, cap) = inv_data.initial
start_cap(element, t_inv, inv_data::NoStartInvData, cap) = error(
    "The function `start_cap` is not implemented for $(typeof(element)) and " *
    "`NoStartInvData`. If you want to use `NoStartInvData` as investment data, " *
    "you have create this function for your type $(typeof(element)).",
)

"""
    get_var_capex(m, prefix::Symbol)

Extracts the CAPEX variable with a given `prefix` from the model.
"""
get_var_capex(m, prefix::Symbol) = m[Symbol(prefix, :_capex)]
"""
    get_var_capex(m, prefix::Symbol, element)

When the type `element` is used as conditional input, it extracts only the variable for
the specified node.
"""
get_var_capex(m, prefix::Symbol, element) = m[Symbol(prefix, :_capex)][element, :]

"""
    get_var_inst(m, prefix::Symbol)

Extracts the installed capacity variable with a given `prefix` from the model.
"""
get_var_inst(m, prefix::Symbol) = m[Symbol(prefix, :_inst)]
"""
    get_var_inst(m, prefix::Symbol, element)

When the type `element` is used as conditional input, it extracts only the variable for
the specified node.
"""
get_var_inst(m, prefix::Symbol, element) = m[Symbol(prefix, :_inst)][element, :]

"""
    get_var_current(m, prefix::Symbol)

Extracts the current capacity variable with a given `prefix` from the model.
"""
get_var_current(m, prefix::Symbol) = m[Symbol(prefix, :_current)]
"""
    get_var_current(m, prefix::Symbol, element)

When the type `element` is used as conditional input, it extracts only the variable for
the specified node.
"""
get_var_current(m, prefix::Symbol, element) = m[Symbol(prefix, :_current)][element, :]

"""
    get_var_add(m, prefix::Symbol)

Extracts the investment capacity variable with a given `prefix` from the model.
"""
get_var_add(m, prefix::Symbol) = m[Symbol(prefix, :_add)]
"""
    get_var_add(m, prefix::Symbol, element)

When the type `element` is used as conditional input, it extracts only the variable for
the specified node.
"""
get_var_add(m, prefix::Symbol, element) = m[Symbol(prefix, :_add)][element, :]

"""
    get_var_rem(m, prefix::Symbol)

Extracts the retired capacity variable with a given `prefix` from the model.
"""
get_var_rem(m, prefix::Symbol) = m[Symbol(prefix, :_rem)]
"""
    get_var_rem(m, prefix::Symbol, element)

When the type `element` is used as conditional input, it extracts only the variable for
the specified node.
"""
get_var_rem(m, prefix::Symbol, element) = m[Symbol(prefix, :_rem)][element, :]

"""
    get_var_invest_b(m, prefix::Symbol)

Extracts the binary investment variable with a given `prefix` from the model.
"""
get_var_invest_b(m, prefix::Symbol) = m[Symbol(prefix, :_invest_b)]
"""
    get_var_invest_b(m, prefix::Symbol, element)

When the type `element` is used as conditional input, it extracts only the variable for
the specified node.
"""
get_var_invest_b(m, prefix::Symbol, element) = m[Symbol(prefix, :_invest_b)][element, :]

"""
    get_var_remove_b(m, prefix::Symbol)

Extracts the binary retirement variable with a given `prefix` from the model.
"""
get_var_remove_b(m, prefix::Symbol) = m[Symbol(prefix, :_remove_b)]
"""
    get_var_remove_b(m, prefix::Symbol, element)

When the type `element` is used as conditional input, it extracts only the variable for
the specified node.
"""
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
cost based on the multiplication of the field `capex` in `inv_data` with the added capacity.
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
    has_investment(element) 

Return boolean indicating whether an `element` shall have variables and constraints contstructed for investments.
"""
function has_investment end