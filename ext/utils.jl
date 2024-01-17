"""
    EMI.has_investment(tm::TransmissionMode)

For a given `TransmissionMode`, checks that it contains ithe required investment data.
"""
function EMI.has_investment(tm::TransmissionMode)
    (
        hasproperty(tm, :data) &&
        !isempty(filter(data -> typeof(data) <: InvestmentData, tm.data))
    )
end

"""
    EMI.has_investment(ℳ::Vector{<:TransmissionMode})

For a given `Vector{<:TransmissionMode}`, return all `TransmissionMode`s with investments.
"""
EMI.nodes_investment(ℳ::Vector{<:TransmissionMode}) = filter(EMI.has_investment, ℳ)


"""
    EMI.start_cap(m, tm, t, stcap, modeltype)

Returns the starting capacity of the `TransmissionMode` `tm` in the first investment period.
If no starting capacity is provided in `InvestmentData` (default = Nothing), then use the
provided capacity from the field `trans_Cap`.
"""
EMI.start_cap(m, tm::TransmissionMode, t, ::Nothing, modeltype) = tm.trans_cap[t]


"""
   EMI.max_add(n::TransmissionMode)

Returns the maximum allowed added capacity of `TransmissionMode` `tm` as `TimeProfile`.
"""
EMI.max_add(tm::TransmissionMode) = EMI.investment_data(tm).trans_max_add
"""
   EMI.max_add(n::TransmissionMode, t_inv)

Returns the maximum allowed added capacity of `TransmissionMode` `tm` in investment period
`t_inv`.
"""
EMI.max_add(tm::TransmissionMode, t_inv) = EMI.investment_data(tm).trans_max_add[t_inv]

"""
    EMI.min_add(n::TransmissionMode)

Returns the minimum allowed added capacity of `TransmissionMode` `tm` as `TimeProfile`.
"""
EMI.min_add(tm::TransmissionMode) = EMI.investment_data(tm).trans_min_add
"""
    EMI.min_add(n::TransmissionMode, t_inv)

Returns the minimum allowed added capacity of `TransmissionMode` `tm` in investment period
`t_inv`.
"""
EMI.min_add(tm::TransmissionMode, t_inv) = EMI.investment_data(tm).trans_min_add[t_inv]

"""
    EMI.max_installed(n::TransmissionMode)

Returns the maximum allowed installed capacity of `TransmissionMode` `tm` as `TimeProfile`.
"""
EMI.max_installed(tm::TransmissionMode) = EMI.investment_data(tm).trans_max_inst
"""
    EMI.max_installed(n::TransmissionMode, t_inv)

Returns the maximum allowed installed capacity of `TransmissionMode` `tm` in investment
period `t_inv`.
"""
EMI.max_installed(tm::TransmissionMode, t_inv) =
    EMI.investment_data(tm).trans_max_inst[t_inv]

"""
    EMI.capex(n::TransmissionMode)

Returns the CAPEX of `TransmissionMode` `tm` as `TimeProfile`.
"""
EMI.capex(tm::TransmissionMode) = EMI.investment_data(tm).capex_trans
"""
    EMI.capex(n::TransmissionMode, t_inv)

Returns the CAPEX of `TransmissionMode` `tm` in investment period `t_inv`.
"""
EMI.capex(tm::TransmissionMode, t_inv) = EMI.investment_data(tm).capex_trans[t_inv]

"""
    capex_offset(n::TransmissionMode)

Returns the offset of the CAPEX of `TransmissionMode` `tm` as `TimeProfile`.
"""
EMI.capex_offset(tm::TransmissionMode) = EMI.investment_data(tm).capex_trans

"""
    capex_offset(n::TransmissionMode, t_inv)

Returns the offset of the CAPEX of `TransmissionMode` `tm` in investment period `t_inv`.
"""
EMI.capex_offset(tm::TransmissionMode, t_inv) = EMI.investment_data(tm).capex_trans[t_inv]

"""
    EMI.increment(tm::TransmissionMode)

Returns the minimum added capacity of `TransmissionMode` `tm` as `TimeProfile`.
"""
EMI.increment(tm::TransmissionMode) = EMI.investment_data(tm).trans_increment

"""
    EMI.increment(tm::TransmissionMode, t_inv)

Returns the minimum added capacity of `TransmissionMode` `tm` in investment period `t_inv`.
"""
EMI.increment(tm::TransmissionMode, t_inv) = EMI.investment_data(tm).trans_increment[t_inv]
