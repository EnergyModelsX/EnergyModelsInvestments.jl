"""
    has_investment(n::EMB.Node)

For a given `Node`, checks that it contains the required investment data.
"""
function has_investment(n::EMB.Node)
    (
        hasproperty(n, :Data) && 
        haskey(n.Data,"Investments") && 
        typeof(n.Data["Investments"]) <: InvestmentData
    )
end


"""
    has_investment(𝒩::Vector{<:EMB.Node})

For a given `Vector{<:TransmissionMode}`, return all `TransmissionMode`s with investments.
"""
function has_investment(𝒩::Vector{<:EMB.Node})

    return [n for n ∈ 𝒩 if has_investment(n)]
end


"""
    investment_mode(type)

Return the investment mode of the type `type`. By default, all investments are continuous.
"""
investment_mode(type) = type.Data["Investments"].Inv_mode


"""
    lifetime_mode(type)

Return the lifetime mode of the type `type`. By default, all investments are unlimited.
"""
lifetime_mode(type) = type.Data["Investments"].Life_mode


"""
    get_start_cap(n, t, stcap)

Returns the starting capacity of the storage in the first investment period. If no
starting capacity is provided in `InvestmentData` (default = Nothing), then use the
provided capacity from the field Cap.
"""
get_start_cap(n, t, stcap) = stcap
get_start_cap(n::EMB.Node, t, stcap::Nothing) = n.Cap[t]

get_start_cap_storage(n::Storage, t, stcap) = stcap
get_start_cap_storage(n::Storage, t, stcap::Nothing) = n.Stor_cap[t]
get_start_rate_storage(n::Storage, t, stcap) = stcap
get_start_rate_storage(n::Storage, t, stcap::Nothing) = n.Rate_cap[t]

"""
    max_add(n::EMB.Node, t_inv)

Returns the maximum added capacity in the investment period `t_inv`.
"""
max_add(n::EMB.Node, t_inv) = n.Data["Investments"].Cap_max_add[t_inv]
"""
    min_add(n::EMB.Node, t_inv)

Returns the minimum added capacity in the investment period `t_inv`.
"""
min_add(n::EMB.Node, t_inv) = n.Data["Investments"].Cap_min_add[t_inv]