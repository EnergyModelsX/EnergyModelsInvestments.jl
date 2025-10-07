"""
    CRF(inv_data, t_inv, 𝒯ᴵⁿᵛ)

Computes the Capital Recovery Factor (CRF) for the investment data `inv_data` 
in the strategic period `t_inv`, given the set of investment periods `𝒯ᴵⁿᵛ`. 

The formula of the annuity-due factor, assuming the payments start immediately, in the same period as the
investment. 

The CRF is calculated based on the discount rate of `inv_data` and the remaining horizon of `t_inv` 
within `𝒯ᴵⁿᵛ`. It represents the annualised payment factor used to recover the investment cost 
over its economic lifetime.
"""
function CRF(inv_data::AbstractInvData, t_inv, 𝒯ᴵⁿᵛ)
    disc_rate = get_discount_rate(inv_data)
    remaining_horizon = remaining(t_inv, 𝒯ᴵⁿᵛ)
    annuity = (disc_rate * (1 + disc_rate)^(remaining_horizon-1)) / ((1 + disc_rate)^(remaining_horizon) - 1)
    return annuity
end

function set_period_annuity(inv_data::AbstractInvData, t_inv)
    disc_rate = get_discount_rate(inv_data)
    d = t_inv.duration

    return ((1 + disc_rate)^d - 1)/(disc_rate * (1 + disc_rate)^(d-1))
end