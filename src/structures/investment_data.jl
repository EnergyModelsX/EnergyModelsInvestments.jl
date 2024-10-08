
"""
    AbstractInvData

Supertype for investment data for nodal investments.
"""
abstract type AbstractInvData end

"""
    NoStartInvData <: AbstractInvData

Investment data in which the initial capacity is not specified in the `AbstractInvData`.
Instead, the initial capacity is inferred  from the capacity of the technology through the
function [`start_cap(element, t_inv, inv_data::AbstractInvData, cap)`](@ref).

# Fields
- **`capex::TimeProfile`** is the capital costs for investing in a capacity. The value is
  relative to the added capacity.
- **`max_inst::TimeProfile`** is the maximum installed capacity in a investment period.
- **`inv_mode::Investment`** is the chosen investment mode for the technology. The following
  investment modes are currently available: [`BinaryInvestment`](@ref),
  [`DiscreteInvestment`](@ref), [`ContinuousInvestment`](@ref), [`SemiContinuousInvestment`](@ref)
  or [`FixedInvestment`](@ref).
- **`life_mode::LifetimeMode`** is type of handling the lifetime. Several different
  alternatives can be used: [`UnlimitedLife`](@ref), [`StudyLife`](@ref), [`PeriodLife`](@ref)
  or [`RollingLife`](@ref).
"""
struct NoStartInvData <: AbstractInvData
    capex::TimeProfile
    max_inst::TimeProfile
    inv_mode::Investment
    life_mode::LifetimeMode
end
function NoStartInvData(
    capex_trans::TimeProfile,
    trans_max_inst::TimeProfile,
    inv_mode::Investment,
)

    return NoStartInvData(capex_trans, trans_max_inst, inv_mode, UnlimitedLife())
end


"""
    StartInvData <: AbstractInvData

Investment data in which the initial capacity is specified in the `AbstractInvData`.
The structure is similiar to [`NoStartInvData`](@ref) with the addition of the field
**`initial::Real`**, see below.

# Fields in addition to [`NoStartInvData`](@ref)
- **`initial::Real`** is the initial capacity.
"""
struct StartInvData <: AbstractInvData
    capex::TimeProfile
    max_inst::TimeProfile
    initial::Real
    inv_mode::Investment
    life_mode::LifetimeMode
end
function StartInvData(
    capex_trans::TimeProfile,
    trans_max_inst::TimeProfile,
    initial::Real,
    inv_mode::Investment,
)

    return StartInvData(capex_trans, trans_max_inst, initial, inv_mode, UnlimitedLife())
end

"""
    investment_mode(inv_data::AbstractInvData)

Return the investment mode of the investment data `inv_data`. By default, all investments
are continuous.
"""
investment_mode(inv_data::AbstractInvData) = inv_data.inv_mode

"""
    lifetime_mode(inv_data::AbstractInvData)

Return the lifetime mode of the investment data `inv_data`. By default, all investments
are unlimited.
"""
lifetime_mode(inv_data::AbstractInvData) = inv_data.life_mode

"""
    lifetime(inv_data::AbstractInvData)
    lifetime(inv_data::AbstractInvData, t_inv)

Return the lifetime of the investment data `inv_data` as `TimeProfile` or in investment
period `t_inv`.
"""
lifetime(inv_data::AbstractInvData) = lifetime(lifetime_mode(inv_data))
lifetime(inv_data::AbstractInvData, t_inv) = lifetime(lifetime_mode(inv_data), t_inv)

"""
    capex(inv_data::AbstractInvData)
    capex(n::AbstractInvData, t_inv)

Returns the CAPEX of the investment data `inv_data` as `TimeProfile` or in investment
period `t_inv`.
"""
capex(inv_data::AbstractInvData) = inv_data.capex
capex(inv_data::AbstractInvData, t_inv) = inv_data.capex[t_inv]

"""
    capex_offset(inv_data::AbstractInvData)
    capex_offset(inv_data::AbstractInvData, t_inv)

Returns the offset of the CAPEX of the investment data `inv_data` as `TimeProfile` or in
investment period `t_inv`.
"""
capex_offset(inv_data::AbstractInvData) = capex_offset(investment_mode(inv_data))
capex_offset(inv_data::AbstractInvData, t_inv) =
    capex_offset(investment_mode(inv_data), t_inv)

"""
    max_installed(inv_data::AbstractInvData)
    max_installed(inv_data::AbstractInvData, t_inv)

Returns the maximum allowed installed capacity the investment data `inv_data` as
`TimeProfile` or in investment period `t_inv`.
"""
max_installed(inv_data::AbstractInvData) = inv_data.max_inst
max_installed(inv_data::AbstractInvData, t_inv) = inv_data.max_inst[t_inv]

"""
    max_add(inv_data::AbstractInvData)
    max_add(inv_data::AbstractInvData, t_inv)

Returns the maximum allowed added capacity of the investment data `inv_data` as
`TimeProfile` or in investment period `t_inv`.
"""
max_add(inv_data::AbstractInvData) = max_add(investment_mode(inv_data))
max_add(inv_data::AbstractInvData, t_inv) = max_add(investment_mode(inv_data), t_inv)

"""
    min_add(inv_data::AbstractInvData)
    min_add(inv_data::AbstractInvData, t_inv)

Returns the minimum allowed added capacity of the investment data `inv_data` as
`TimeProfile` or in investment period `t_inv`.
"""
min_add(inv_data::AbstractInvData) = min_add(investment_mode(inv_data))
min_add(inv_data::AbstractInvData, t_inv) = min_add(investment_mode(inv_data), t_inv)

"""
    increment(inv_data::AbstractInvData)
    increment(inv_data::AbstractInvData, t_inv)

Returns the capacity increment of the investment data `inv_data` as `TimeProfile` or in
investment period `t_inv`.
"""
increment(inv_data::AbstractInvData) = increment(investment_mode(inv_data))
increment(inv_data::AbstractInvData, t_inv) = increment(investment_mode(inv_data), t_inv)

"""
    invest_capacity(inv_data::AbstractInvData)
    invest_capacity(inv_data::AbstractInvData, t_inv)

Returns the capacity investments of the investment data `inv_data` as `TimeProfile` or in
investment period `t_inv`.
"""
invest_capacity(inv_data::AbstractInvData) = invest_capacity(investment_mode(inv_data))
invest_capacity(inv_data::AbstractInvData, t_inv) =
    invest_capacity(investment_mode(inv_data), t_inv)
