"""
    investment_data(type)

Return the investment data of the type `type`.
"""
investment_data(type) = filter(data -> typeof(data) <: InvestmentData, type.data)[1]

"""
    has_investment(type)

For a given `Node`, checks that it contains the required investment data.
"""
function has_investment(type)
    (
        hasproperty(type, :data) &&
        !isempty(filter(data -> typeof(data) <: InvestmentData, type.data))
    )
end

"""
    nodes_investment(𝒩::Vector{<:EMB.Node})

For a given `Vector{<:Node}`, return all `Node`s with investments.
"""
nodes_investment(𝒩::Vector{<:EMB.Node}) = filter(has_investment, 𝒩)

"""
    discount_rate(modeltype::AbstractInvestmentModel)

Returns the discount rate of `EnergyModel` modeltype
"""
discount_rate(modeltype::AbstractInvestmentModel) = modeltype.r

"""
    has_investment(n::Storage, field::Symbol)

For a given `Storage` node, checks that it contains investments for the field `field`, that
is `:charge`, `:level`, or `:discharge`.
"""
function has_investment(n::Storage, field::Symbol)
    (
        hasproperty(n, :data) &&
        !isempty(filter(data -> typeof(data) <: InvestmentData, n.data)) &&
        !isnothing(getproperty(investment_data(n), field))
    )
end

"""
    investment_data(type, field::Symbol)

Return the investment data of the type `type`.
"""
investment_data(type, field::Symbol) = getproperty(investment_data(type), field)

"""
    investment_mode(type)

Return the investment mode of the type `type`. By default, all investments are continuous.
"""
investment_mode(type) = investment_data(type).inv_mode

"""
    investment_mode(inv_data::GeneralInvData)

Return the investment mode of the investment data `inv_data`. By default, all investments
are continuous.
"""
investment_mode(inv_data::GeneralInvData) = inv_data.inv_mode

"""
    investment_mode(type, ::Nothing)

Return the investment mode of the type `type`.
"""
investment_mode(type, ::Nothing) = investment_mode(investment_data(type))

"""
    investment_mode(type, field::Symbol)

Return the investment mode of the type `type` and the capacity `field`.
"""
investment_mode(type, field::Symbol) = investment_mode(investment_data(type, field))

"""
    lifetime_mode(inv_data::GeneralInvData)

Return the lifetime mode of the investment data `inv_data`. By default, all investments
are unlimited.
"""
lifetime_mode(inv_data::GeneralInvData) = inv_data.life_mode

"""
    lifetime(lifetime_mode::LifetimeMode)

Return the lifetime of the lifetime mode `lifetime_mode` as `TimeProfile`.
"""
lifetime(lifetime_mode::LifetimeMode) = lifetime_mode.lifetime
"""
    lifetime(inv_data::GeneralInvData)

Return the lifetime of the investment data `inv_data` as `TimeProfile`.
"""
lifetime(inv_data::GeneralInvData) = lifetime(lifetime_mode(inv_data))
"""
    lifetime(lifetime_mode::LifetimeMode, t_inv)

Return the lifetime of the lifetime mode `lifetime_mode` in investment period `t_inv`.
"""
lifetime(lifetime_mode::LifetimeMode, t_inv) = lifetime_mode.lifetime[t_inv]
"""
    lifetime(inv_data::GeneralInvData, t_inv)

Return the lifetime of the investment data `inv_data` in investment period `t_inv`.
"""
lifetime(inv_data::GeneralInvData, t_inv) = lifetime(lifetime_mode(inv_data), t_inv)

"""
    start_cap(type, t_inv, inv_data::GeneralInvData, field, modeltype::EnergyModel)

Returns the starting capacity of the node in the first investment period.
If [`NoStartInvData`](@ref) is used for the starting capacity, it deduces the value from the
provided initial capacity.
"""
start_cap(type, t_inv, inv_data::StartInvData, field, modeltype::EnergyModel) =
    inv_data.initial
start_cap(type, t_inv, inv_data::NoStartInvData, field, modeltype::EnergyModel) =
    capacity(type, t_inv)
start_cap(n::Storage, t_inv, inv_data::NoStartInvData, field, modeltype::EnergyModel) =
    capacity(getproperty(n, field), t_inv)

"""
    capex(inv_data::GeneralInvData)

Returns the CAPEX of the investment data `inv_data` as `TimeProfile`.
"""
capex(inv_data::GeneralInvData) = inv_data.capex
"""
    capex(n::GeneralInvData, t_inv)

Returns the CAPEX of the investment data `inv_data` in investment period `t_inv`.
"""
capex(inv_data::GeneralInvData, t_inv) = inv_data.capex[t_inv]

"""
    capex_offset(inv_mode::SemiContinuousOffsetInvestment)

Returns the offset of the CAPEX of the investment mode `inv_mode` as `TimeProfile`.
"""
capex_offset(inv_mode::SemiContinuousOffsetInvestment) = inv_mode.capex_offset
"""
    capex_offset(inv_data::GeneralInvData)

Returns the offset of the CAPEX of the investment data `inv_data` as `TimeProfile`.
"""
capex_offset(inv_data::GeneralInvData) = capex_offset(investment_mode(inv_data))

"""
    capex_offset(inv_mode::SemiContinuousOffsetInvestment, t_inv)

Returns the offset of the CAPEX of the investment mode `inv_mode` in investment period `t_inv`.
"""
capex_offset(inv_mode::SemiContinuousOffsetInvestment, t_inv) = inv_mode.capex_offset[t_inv]
"""
    capex_offset(inv_data::GeneralInvData, t_inv)

Returns the offset of the CAPEX of the investment data `inv_data` in investment period `t_inv`.
"""
capex_offset(inv_data::GeneralInvData, t_inv) = capex_offset(investment_mode(inv_data), t_inv)

"""
    max_installed(inv_data::GeneralInvData)

Returns the maximum allowed installed capacity the investment data `inv_data` as
`TimeProfile`.
"""
max_installed(inv_data::GeneralInvData) = inv_data.max_inst
"""
    max_installed(inv_data::GeneralInvData, t_inv)

Returns the maximum allowed installed capacity of the investment data `inv_data` in
investment period `t_inv`.
"""
max_installed(inv_data::GeneralInvData, t_inv) = inv_data.max_inst[t_inv]

"""
    max_add(inv_mode::Investment)

Returns the maximum allowed added capacity of the investment mode `inv_mode` as
`TimeProfile`.
"""
max_add(inv_mode::Investment) = inv_mode.max_add
"""
    max_add(inv_data::GeneralInvData)

Returns the maximum allowed added capacity of the investment data `inv_data` as
`TimeProfile`.
"""
max_add(inv_data::GeneralInvData) = max_add(investment_mode(inv_data))
"""
    max_add(inv_mode::Investment, t_inv)

Returns the maximum allowed added capacity of the investment mode `inv_mode` investment
period `t_inv`.
"""
max_add(inv_mode::Investment, t_inv) = inv_mode.max_add[t_inv]

"""
    max_add(inv_data::GeneralInvData, t_inv)

Returns the maximum allowed added capacity of the investment data `inv_data` in investment
period `t_inv`.
"""
max_add(inv_data::GeneralInvData, t_inv) = max_add(investment_mode(inv_data), t_inv)

"""
    min_add(inv_mode::Investment)

Returns the minimum allowed added capacity of the investment mode `inv_mode` as
`TimeProfile`.
"""
min_add(inv_mode::Investment) = inv_mode.min_add
"""
    min_add(inv_data::GeneralInvData)

Returns the minimum allowed added capacity of the investment data `inv_data` as
`TimeProfile`.
"""
min_add(inv_data::GeneralInvData) = min_add(investment_mode(inv_data))
"""
    min_add(inv_mode::Investment, t_inv)

Returns the minimum allowed added capacity of the investment mode `inv_mode` in investment
period `t_inv`.
"""
min_add(inv_mode::Investment, t_inv) = inv_mode.min_add[t_inv]

"""
    min_add(inv_data::GeneralInvData, t_inv)

Returns the minimum allowed added capacity of the investment data `inv_data` in investment
period `t_inv`.
"""
min_add(inv_data::GeneralInvData, t_inv) = min_add(investment_mode(inv_data), t_inv)

"""
    increment(inv_mode::Investment)

Returns the capacity increment of the investment mode `inv_mode` as `TimeProfile`.
"""
increment(inv_mode::Investment) = inv_mode.increment
"""
    increment(inv_data::GeneralInvData)

Returns the capacity increment of the investment data `inv_data` as `TimeProfile`.
"""
increment(inv_data::GeneralInvData) = increment(investment_mode(inv_data))
"""
    increment(inv_mode::Investment, t_inv)

Returns the capacity increment of the investment mode `inv_mode` in investment period `t_inv`.
"""
increment(inv_mode::Investment, t_inv) = inv_mode.increment[t_inv]
"""
    increment(inv_data::GeneralInvData, t_inv)

Returns the capacity increment of the investment data `inv_data` in investment period `t_inv`.
"""
increment(inv_data::GeneralInvData, t_inv) = increment(investment_mode(inv_data), t_inv)

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
    # Deduce the required variable
    var_add = get_var_add(m, prefix, type)
    var_invest_b = get_var_invest_b(m, prefix)
    t_inv = collect(𝒯ᴵⁿᵛ)[1]
    println(var_invest_b)

    return @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        capex(inv_data, t_inv) * var_add[t_inv] +
        capex_offset(inv_mode, t_inv) * var_invest_b[type, t_inv]
    )
end

"""
    set_capex_discounter(years, lifetime, r)

Calculate the discounted values used in the lifetime calculations, when the `LifetimeMode`
is given by `PeriodLife` and `StudyLife`.

# Arguments
- `years:`: the remaining years for calculating the discounted value. The years are
  depending on the considered [`LifetimeMode`](@ref), using `remaining(t_inv, 𝒯)` for
  [`StudyLife`](@ref) and `duration(t_inv)` for [`PeriodLife`](@ref).
- `lifetime`: the lifetime of the node.
- `r`: the discount rate.
"""
function set_capex_discounter(years, lifetime, r)
    N_inv = ceil(years/lifetime)
    capex_disc = sum((1+r)^(-n_inv * lifetime) for n_inv ∈ 0:N_inv-1) -
                 ((N_inv * lifetime - years)/lifetime) * (1+r)^(-years)
    return capex_disc
end
