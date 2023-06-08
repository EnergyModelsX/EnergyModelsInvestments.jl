"""
    EMI.has_investment(tm::EMG.TransmissionMode)

For a given `TransmissionMode`, checks that it contains ithe required investment data.
"""
function EMI.has_investment(tm::EMG.TransmissionMode)
    (
        hasproperty(tm, :Data) && 
        !isempty(filter(data -> typeof(data) <: InvestmentData, tm.Data))
    )
end

"""
    EMI.has_investment(ℳ::Vector{<:EMG.TransmissionMode})

For a given `Vector{<:TransmissionMode}`, return all `TransmissionMode`s with investments.
"""
function EMI.has_investment(ℳ::Vector{<:EMG.TransmissionMode})

    return [tm for tm ∈ ℳ if EMI.has_investment(tm)]
end


"""
    EMI.get_start_cap(n, t, stcap)

Returns the starting capacity of the `TransmissionMode` in the first investment period.
If no starting capacity is provided in `InvestmentData` (default = Nothing), then use the
provided capacity from the field `Trans_Cap`.
"""
EMI.get_start_cap(tm::EMG.TransmissionMode, t, ::Nothing) = tm.Trans_cap[t]


"""
   EMI.max_add(n::EMG.TransmissionMode, t_inv)

Returns the maximum added capacity in the investment period `t_inv`.
"""
EMI.max_add(tm::EMG.TransmissionMode, t_inv) = investment_data(tm).Trans_max_add[t_inv]
"""
    EMI.min_add(n::EMG.TransmissionMode, t_inv)

Returns the minimum added capacity in the investment period `t_inv`.
"""
EMI.min_add(tm::EMG.TransmissionMode, t_inv) = investment_data(tm).Trans_min_add[t_inv]