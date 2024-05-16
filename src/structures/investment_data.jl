
"""
    GeneralInvData

Supertype for investment data for nodal investments.
"""
abstract type GeneralInvData end

"""
    StartInvData <: GeneralInvData

Investment data in which the initial capacity is not specified in the `InvestmentData`.
Instead, the initial capacity is deduced from the capacity of the technology.

# Fields
- **`capex::TimeProfile`** is the capital costs for investing in a capacity. The value is
  relative to the added capacity.
- **`max_inst::TimeProfile`** is the maximum installed capacity in a strategic period.
- **`inv_mode::Investment`** is the chosen investment mode for the technology. The following
  investment modes are currently available: [`BinaryInvestment`](@ref),
  [`DiscreteInvestment`](@ref), [`ContinuousInvestment`](@ref), [`SemiContinuousInvestment`](@ref)
  or [`FixedInvestment`](@ref).
- **`life_mode::LifetimeMode`** is type of handling the lifetime. Several different
  alternatives can be used: [`UnlimitedLife`](@ref), [`StudyLife`](@ref), [`PeriodLife`](@ref)
  or [`RollingLife`](@ref).
"""
struct NoStartInvData <: GeneralInvData
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

    return NoStartInvData(
        capex_trans,
        trans_max_inst,
        inv_mode,
        UnlimitedLife(),
    )
end


"""
    StartInvData <: GeneralInvData

Investment data in which the initial capacity is specified in the `InvestmentData`.
The structure is similiar to [`NoStartInvData`](@ref) with the addition of the field
**`initial::Real`**, see below.

# Fields in addition to [`NoStartInvData`](@ref)
- **`initial::Real`** is the initial capacity.
"""
struct StartInvData <: GeneralInvData
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

    return StartInvData(
        capex_trans,
        trans_max_inst,
        initial,
        inv_mode,
        UnlimitedLife(),
    )
end

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
    lifetime(inv_data::GeneralInvData, t_inv)

Return the lifetime of the investment data `inv_data` in investment period `t_inv`.
"""
lifetime(inv_data::GeneralInvData, t_inv) = lifetime(lifetime_mode(inv_data), t_inv)

"""
    lifetime(inv_data::GeneralInvData)

Return the lifetime of the investment data `inv_data` as `TimeProfile`.
"""
lifetime(inv_data::GeneralInvData) = lifetime(lifetime_mode(inv_data))

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
    capex_offset(inv_data::GeneralInvData)

Returns the offset of the CAPEX of the investment data `inv_data` as `TimeProfile`.
"""
capex_offset(inv_data::GeneralInvData) = capex_offset(investment_mode(inv_data))
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
    max_add(inv_data::GeneralInvData)

Returns the maximum allowed added capacity of the investment data `inv_data` as
`TimeProfile`.
"""
max_add(inv_data::GeneralInvData) = max_add(investment_mode(inv_data))
"""
    max_add(inv_data::GeneralInvData, t_inv)

Returns the maximum allowed added capacity of the investment data `inv_data` in investment
period `t_inv`.
"""
max_add(inv_data::GeneralInvData, t_inv) = max_add(investment_mode(inv_data), t_inv)

"""
    min_add(inv_data::GeneralInvData)

Returns the minimum allowed added capacity of the investment data `inv_data` as
`TimeProfile`.
"""
min_add(inv_data::GeneralInvData) = min_add(investment_mode(inv_data))
"""
    min_add(inv_data::GeneralInvData, t_inv)

Returns the minimum allowed added capacity of the investment data `inv_data` in investment
period `t_inv`.
"""
min_add(inv_data::GeneralInvData, t_inv) = min_add(investment_mode(inv_data), t_inv)

"""
    increment(inv_data::GeneralInvData)

Returns the capacity increment of the investment data `inv_data` as `TimeProfile`.
"""
increment(inv_data::GeneralInvData) = increment(investment_mode(inv_data))
"""
    increment(inv_data::GeneralInvData, t_inv)

Returns the capacity increment of the investment data `inv_data` in investment period `t_inv`.
"""
increment(inv_data::GeneralInvData, t_inv) = increment(investment_mode(inv_data), t_inv)

"""
    invest_capacity(inv_data::GeneralInvData)

Returns the capacity investments of the investment data `inv_data` as `TimeProfile`.
"""
invest_capacity(inv_data::GeneralInvData) = invest_capacity(investment_mode(inv_data))
"""
    invest_capacity(inv_data::GeneralInvData, t_inv)

Returns the capacity profile for investments of the investment data `inv_data` in investment
period `t_inv`.
"""
invest_capacity(inv_data::GeneralInvData, t_inv) =
    invest_capacity(investment_mode(inv_data), t_inv)
