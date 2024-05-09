
"""
    investment_data(type)

Return the investment data of the type `type`.
"""
investment_data(type) = filter(data -> typeof(data) <: InvestmentData, type.data)[1]

"""
    has_investment(n::EMB.Node)

For a given `Node`, checks that it contains the required investment data.
"""
function has_investment(n::EMB.Node)
    (
        hasproperty(n, :data) &&
        !isempty(filter(data -> typeof(data) <: InvestmentData, n.data))
    )
end

"""
    nodes_investment(𝒩::Vector{<:EMB.Node})

For a given `Vector{<:Node}`, return all `Node`s with investments.
"""
nodes_investment(𝒩::Vector{<:EMB.Node}) = filter(has_investment, 𝒩)

"""
    set_capex_discounter(years, lifetime, r)

Calculate the discounted values used in the lifetime calculations, when the `LifetimeMode`
is given by `PeriodLife` and `StudyLife`.

# Arguments
- `years:`: the remaining years for calculating the discounted value. The years are
depending on the considered `LifetimeMode`, using `remaining(t_inv, 𝒯)` for `StudyLife` \
and `duration(t_inv)` for `PeriodLife`.
- `lifetime`: the lifetime of the node.
- `r`: the discount rate.
"""
function set_capex_discounter(years, lifetime, r)
    N_inv = ceil(years/lifetime)
    capex_disc = sum((1+r)^(-n_inv * lifetime) for n_inv ∈ 0:N_inv-1) -
                 ((N_inv * lifetime - years)/lifetime) * (1+r)^(-years)
    return capex_disc
end

"""
    investment_mode(type)

Return the investment mode of the type `type`. By default, all investments are continuous.
"""
investment_mode(type) = investment_data(type).inv_mode


"""
    lifetime_mode(type)

Return the lifetime mode of the type `type`. By default, all investments are unlimited.
"""
lifetime_mode(type) = investment_data(type).life_mode

"""
    lifetime(type)

Return the lifetime of the type `type` as `TimeProfile`.
"""
lifetime(type) = investment_data(type).lifetime

"""
    lifetime(type, t)

Return the lifetime of the type `type` in period `t`.
"""
lifetime(type, t) = investment_data(type).lifetime[t]


"""
    start_cap(m, n, t, stcap, modeltype)

Returns the starting capacity of the node in the first investment period. If no
starting capacity is provided in `InvestmentData` (default = Nothing), then use the
provided capacity from the field Cap.
"""
start_cap(m, n, t, stcap, modeltype::EMB.EnergyModel) = stcap
start_cap(m, n::EMB.Node, t, stcap::Nothing, modeltype::EMB.EnergyModel) = n.cap[t]

start_cap_storage(m, n::Storage, t, stcap, modeltype::EMB.EnergyModel) = stcap
start_cap_storage(m, n::Storage, t, stcap::Nothing, modeltype::EMB.EnergyModel) = n.stor_cap[t]
start_rate_storage(m, n::Storage, t, stcap, modeltype::EMB.EnergyModel) = stcap
start_rate_storage(m, n::Storage, t, stcap::Nothing, modeltype::EMB.EnergyModel) = n.rate_cap[t]


"""
    capex(n::EMB.Node)

Returns the CAPEX of a node `n` as `TimeProfile`.
"""
capex(n::EMB.Node) = investment_data(n).capex_cap
"""
    capex(n::EMB.Node, t_inv)

Returns the CAPEX of a node `n` in investment period `t_inv`.
"""
capex(n::EMB.Node, t_inv) = investment_data(n).capex_cap[t_inv]

"""
    capex(n::Storage)

Returns the CAPEX of a Storage node `n` as `TimeProfile`.
"""
capex(n::Storage) = (
    level = investment_data(n).capex_stor[t_inv],
    rate = investment_data(n).capex_rate[t_inv],
)
"""
    capex(n::Storage, t_inv)

Returns the CAPEX of a Storage node `n` in investment period `t_inv`.
"""
capex(n::Storage, t_inv) = (
    level = investment_data(n).capex_stor[t_inv],
    rate = investment_data(n).capex_rate[t_inv],
)

"""
    capex_offset(n::Node, t_inv)

Returns the offset of the CAPEX of node `n` in investment period `t_inv`.
"""
capex_offset(n::EMB.Node, t_inv) = 0

"""
    max_installed(n::EMB.Node)

Returns the maximum allowed installed capacity of node `n` as `TimeProfile`.
"""
max_installed(n::EMB.Node) = investment_data(n).cap_max_inst
"""
    max_installed(n::EMB.Node, t_inv)

Returns the maximum allowed installed capacity of node `n` in investment period `t_inv`.
"""
max_installed(n::EMB.Node, t_inv) = investment_data(n).cap_max_inst[t_inv]

"""
    max_installed(n::Storage)

Returns the maximum allowed installed capacity of `Storage` node `n` as `TimeProfile`.
"""
max_installed(n::Storage) = (
    level = investment_data(n).stor_max_inst,
    rate = investment_data(n).rate_max_inst,
)
"""
    max_installed(n::Storage, t_inv)

Returns the maximum allowed installed capacity of `Storage` node `n` in investment period
`t_inv`.
"""
max_installed(n::Storage, t_inv) = (
    level = investment_data(n).stor_max_inst[t_inv],
    rate = investment_data(n).rate_max_inst[t_inv],
)

"""
    max_add(n::EMB.Node)

Returns the maximum allowed added capacity of Node `n` as `TimeProfile`.
"""
max_add(n::EMB.Node) = investment_data(n).cap_max_add[t_inv]
"""
    max_add(n::EMB.Node, t_inv)

Returns the maximum allowed added capacity of Node `n` in investment period `t_inv`.
"""
max_add(n::EMB.Node, t_inv) = investment_data(n).cap_max_add[t_inv]

"""
    max_add(n::Storage)

Returns the maximum allowed added capacity of Storage node `n` as `TimeProfile`.
"""
max_add(n::Storage) = (
    level = investment_data(n).stor_max_add,
    rate = investment_data(n).rate_max_add,
)
"""
    max_add(n::Storage, t_inv)

Returns the maximum allowed added capacity of Storage node `n` in investment period `t_inv`.
"""
max_add(n::Storage, t_inv) = (
    level = investment_data(n).stor_max_add[t_inv],
    rate = investment_data(n).rate_max_add[t_inv],
)

"""
    min_add(n::EMB.Node)

Returns the minimum allowed added capacity of node `n` as `TimeProfile`.
"""
min_add(n::EMB.Node) = investment_data(n).cap_min_add
"""
    min_add(n::EMB.Node, t_inv)

Returns the minimum allowed added capacity of node `n` in investment period `t_inv`.
"""
min_add(n::EMB.Node, t_inv) = investment_data(n).cap_min_add[t_inv]

"""
    min_add(n::Storage)

Returns the minimum allowed added capacity of Storage node `n` as `TimeProfile`.
"""
min_add(n::Storage) = (
    level = investment_data(n).stor_min_add[t_inv],
    rate = investment_data(n).rate_min_add[t_inv],
)
"""
    min_add(n::Storage, t_inv)

Returns the minimum allowed added capacity of Storage node `n` in investment period `t_inv`.
"""
min_add(n::Storage, t_inv) = (
    level = investment_data(n).stor_min_add[t_inv],
    rate = investment_data(n).rate_min_add[t_inv],
)

"""
    increment(n::EMB.Node)

Returns the capacity increment of node `n` as `TimeProfile`.
"""
increment(n::EMB.Node) = investment_data(n).cap_increment
"""
    increment(n::EMB.Node, t_inv)

Returns the capacity increment of node `n` in investment period `t_inv`.
"""
increment(n::EMB.Node, t_inv) = investment_data(n).cap_increment[t_inv]

"""
    increment(n::Storage)

Returns the capacity increment of Storage node `n` as `TimeProfile`.
"""
increment(n::Storage) = (
    level = investment_data(n).stor_increment,
    rate = investment_data(n).rate_increment,
)
"""
    increment(n::Storage, t_inv)

Returns the capacity increment of Storage node `n` in investment period `t_inv`.
"""
increment(n::Storage, t_inv) = (
    level = investment_data(n).stor_increment[t_inv],
    rate = investment_data(n).rate_increment[t_inv],
)


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
    investment_mode(inv_data::GeneralInvData)

Return the investment mode of the investment data `inv_data`. By default, all investments
are continuous.
"""
investment_mode(inv_data::GeneralInvData) = inv_data.inv_mode

"""
    lifetime_mode(inv_data::GeneralInvData)

Return the lifetime mode of the investment data `inv_data`. By default, all investments
are unlimited.
"""
lifetime_mode(inv_data::GeneralInvData) = inv_data.life_mode

"""
    lifetime(inv_data::GeneralInvData)

Return the lifetime of the investment data `inv_data` as `TimeProfile`.
"""
lifetime(inv_data::GeneralInvData) = inv_data.lifetime

"""
    lifetime(inv_data::GeneralInvData, t)

Return the lifetime of the investment data `inv_data` in period `t`.
"""
lifetime(inv_data::GeneralInvData, t) = inv_data.lifetime[t]

start_cap(n::EMB.Node, t_inv, inv_data::StartInvData, field, modeltype::EnergyModel) =
    inv_data.initial
start_cap(n::EMB.Node, t_inv, inv_data::NoStartInvData, field, modeltype::EnergyModel) =
    capacity(n, t_inv)
start_cap(n::Storage, t_inv, inv_data::StartInvData, field, modeltype::EnergyModel) =
    inv_data.initial
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
    max_add(inv_data::GeneralInvData)

Returns the maximum allowed added capacity of the investment data `inv_data` as
`TimeProfile`.
"""
max_add(inv_data::GeneralInvData) = inv_data.max_add
"""
    max_add(inv_data::GeneralInvData, t_inv)

Returns the maximum allowed added capacity of the investment data `inv_data` in investment
period `t_inv`.
"""
max_add(inv_data::GeneralInvData, t_inv) = inv_data.max_add[t_inv]

"""
    min_add(inv_data::GeneralInvData)

Returns the minimum allowed added capacity of the investment data `inv_data` as
`TimeProfile`.
"""
min_add(inv_data::GeneralInvData) = inv_data.min_add
"""
    min_add(inv_data::GeneralInvData, t_inv)

Returns the minimum allowed added capacity of the investment data `inv_data` in investment
period `t_inv`.
"""
min_add(inv_data::GeneralInvData, t_inv) = inv_data.min_add[t_inv]

"""
    increment(inv_data::GeneralInvData)

Returns the capacity increment of the investment data `inv_data` as `TimeProfile`.
"""
increment(inv_data::GeneralInvData) = inv_data.increment
"""
    increment(inv_data::GeneralInvData, t_inv)

Returns the capacity increment of the investment data `inv_data` in investment period `t_inv`.
"""
increment(inv_data::GeneralInvData, t_inv) = inv_data.increment[t_inv]

set_capex_value(m, n, inv_data, prefix, 𝒯ᴵⁿᵛ) =
    set_capex_value(m, n, inv_data, prefix, 𝒯ᴵⁿᵛ, investment_mode(inv_data))
function set_capex_value(m, n, inv_data, prefix, 𝒯ᴵⁿᵛ, ::Investment)
    # Deduce the required variable
    add = m[Symbol(prefix, :_add)][n, :]

    return @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], capex(inv_data, t_inv) * add[t_inv])
end

get_var_capex(m, prefix::Symbol) = m[Symbol(prefix, :_capex)]
get_var_capex(m, prefix::Symbol, n::EMB.Node)  = m[Symbol(:capex_, prefix)][n, :]
get_var_capex(m, prefix::Symbol, n::Storage)  = m[Symbol(prefix, :_capex)][n, :]

get_var_inst(m, prefix::Symbol) = m[Symbol(prefix, :_inst)]
get_var_inst(m, prefix::Symbol, n::EMB.Node)  = m[Symbol(prefix, :_inst)][n, :]

get_var_current(m, prefix::Symbol) = m[Symbol(prefix, :_current)]
get_var_current(m, prefix::Symbol, n::EMB.Node)  = m[Symbol(prefix, :_current)][n, :]

get_var_add(m, prefix::Symbol) = m[Symbol(prefix, :_add)]
get_var_add(m, prefix::Symbol, n::EMB.Node)  = m[Symbol(prefix, :_add)][n, :]

get_var_rem(m, prefix::Symbol) = m[Symbol(prefix, :_rem)]
get_var_rem(m, prefix::Symbol, n::EMB.Node)  = m[Symbol(prefix, :_rem)][n, :]

get_var_invest_b(m, prefix::Symbol) = m[Symbol(prefix, :_invest_b)]
get_var_invest_b(m, prefix::Symbol, n::EMB.Node)  = m[Symbol(prefix, :_invest_b)][n, :]

get_var_remove_b(m, prefix::Symbol) = m[Symbol(prefix, :_remove_b)]
get_var_remove_b(m, prefix::Symbol, n::EMB.Node)  = m[Symbol(prefix, :_remove_b)][n, :]
