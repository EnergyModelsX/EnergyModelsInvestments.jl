const GEO = EnergyModelsGeography

"""
    has_investment(cm::GEO.TransmissionMode)

For a given `TransmissionMode`, checks that it contains ithe required investment data.
"""
function has_investment(cm::GEO.TransmissionMode)
    (
        hasproperty(cm, :Data) && 
        haskey(cm.Data, "Investments") && 
        typeof(cm.Data["Investments"]) == TransInvData
    )
end

"""
    has_investment(𝒞ℳ::Vector{<:GEO.TransmissionMode})

For a given `Vector{<:TransmissionMode}`, return all `TransmissionMode`s with investments.
"""
function has_investment(𝒞ℳ::Vector{<:GEO.TransmissionMode})

    return [cm for cm ∈ 𝒞ℳ if has_investment(cm)]
end


"""
    get_start_cap(n, t, stcap)

Returns the starting capacity of the `TransmissionMode` in the first investment period.
If no starting capacity is provided in `InvestmentData` (default = Nothing), then use the
provided capacity from the field `Trans_Cap`.
"""
get_start_cap(cm::GEO.TransmissionMode, t, ::Nothing) = cm.Trans_cap[t]


"""
    max_add(n::GEO.TransmissionMode, t_inv)

Returns the maximum added capacity in the investment period `t_inv`.
"""
max_add(n::GEO.TransmissionMode, t_inv) = n.Data["Investments"].Trans_max_add[t_inv]
"""
    min_add(n::GEO.TransmissionMode, t_inv)

Returns the minimum added capacity in the investment period `t_inv`.
"""
min_add(n::GEO.TransmissionMode, t_inv) = n.Data["Investments"].Trans_min_add[t_inv]