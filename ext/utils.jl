"""
    EMI.has_investment(cm::EMG.TransmissionMode)

For a given `TransmissionMode`, checks that it contains ithe required investment data.
"""
function EMI.has_investment(cm::EMG.TransmissionMode)
    (
        hasproperty(cm, :Data) && 
        !isempty(filter(data -> typeof(data) <: InvestmentData, cm.Data))
    )
end

"""
    EMI.has_investment(𝒞ℳ::Vector{<:EMG.TransmissionMode})

For a given `Vector{<:TransmissionMode}`, return all `TransmissionMode`s with investments.
"""
function EMI.has_investment(𝒞ℳ::Vector{<:EMG.TransmissionMode})

    return [cm for cm ∈ 𝒞ℳ if EMI.has_investment(cm)]
end


"""
    EMI.get_start_cap(n, t, stcap)

Returns the starting capacity of the `TransmissionMode` in the first investment period.
If no starting capacity is provided in `InvestmentData` (default = Nothing), then use the
provided capacity from the field `Trans_Cap`.
"""
EMI.get_start_cap(cm::EMG.TransmissionMode, t, ::Nothing) = cm.Trans_cap[t]


"""
   EMI.max_add(n::EMG.TransmissionMode, t_inv)

Returns the maximum added capacity in the investment period `t_inv`.
"""
EMI.max_add(cm::EMG.TransmissionMode, t_inv) = investment_data(cm).Trans_max_add[t_inv]
"""
    EMI.min_add(n::EMG.TransmissionMode, t_inv)

Returns the minimum added capacity in the investment period `t_inv`.
"""
EMI.min_add(cm::EMG.TransmissionMode, t_inv) = investment_data(cm).Trans_min_add[t_inv]