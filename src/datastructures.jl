""" An abstract investment model type.

This abstract model type should be used when creating additional `EnergyModel` types that
should utilize investments.
An example for additional types is given by the inclusion of, *e.g.*, `SDDP`.
"""
abstract type AbstractInvestmentModel <: EMB.EnergyModel end

"""
A concrete basic investment model type based on the standard `OperationalModel` as declared
in `EnergyModelsBase`.
The concrete basic investment model is similar to an `OperationalModel`, but allows for
investments and additional discounting of future years.

# Fields
- **`emission_limit::Dict{<:ResourceEmit, <:TimeProfile}`** are the emission caps for the \
different emissions types considered.\n
- **`emission_price::Dict{<:ResourceEmit, <:TimeProfile}`** are the prices for the \
different emissions types considered.\n
- **`co2_instance`** is a `ResourceEmit` and corresponds to the type used for CO₂.\n
- **`r`** is the discount rate in the investment optimization.
"""
struct InvestmentModel <: AbstractInvestmentModel
    emission_limit::Dict{<:ResourceEmit, <:TimeProfile}
    emission_price::Dict{<:ResourceEmit, <:TimeProfile}
    co2_instance::ResourceEmit
    r       # Discount rate
end

"""
    Investment

Investment type traits for nodes.
The investment type corresponds to the chosen investment mode and includes the required
input.
"""
abstract type Investment end

"""
    BinaryInvestment <: Investment

Binary investment in a given capacity with binary variables.
The chosen capacity within a strategic period is given by the capacity of the Node.

Binary investments do not require additional input aside the specified input.
Binary investments introduce one binary variable for each strategic period.
"""
struct BinaryInvestment <: Investment end

"""
    DiscreteInvestment <: Investment

Discrete investment with integer variables using an increment.
The increment for the discrete investment can be different for the individual strategic
periods.

Discrete investments introduce one integer variable for each strategic period.

# Fields
- **`increment::TimeProfile`** is the used increment.
"""
struct DiscreteInvestment <: Investment
    increment::TimeProfile
end

"""
    ContinuousInvestment <: Investment

Continuous investment between a lower and upper bound.
The increment for the discrete investment can be different for the individual strategic
periods.

# Fields
- **`min_add::TimeProfile`** is the minimum added capacity in a strategic period. In the
  case of `ContinuousInvestment`, this implies that the model **must** invest at least
  in this capacity in each strategic period.
- **`max_add::TimeProfile`** is the maximum added capacity in a strategic period.
"""
struct ContinuousInvestment <: Investment
    min_add::TimeProfile
    max_add::TimeProfile
end
"""
    FixedInvestment <: Investment

Fixed investment in a given capacity.
The model is forced to invest in the capacity provided by the node.

Fixed investments do not require additional input aside the specified input.
"""
struct FixedInvestment <: Investment end

"""
    SemiContiInvestment <: Investment

Supertype for semi-continuous investments, that is the added capacity is either zero or
between a minimum and a maximum value.

Semi-continuous investments introduce one binary variable for each strategic period.
"""
abstract type SemiContiInvestment <: Investment end

"""
    SemiContinuousInvestment <: Investment

Semi-continuous investments, that is the added capacity is either zero or between a minimum
and a maximum value. In this subtype, the cost is crossing the origin, that is the CAPEX is
still linear dependent on the

Semi-continuous investments introduce one binary variable for each strategic period.

# Fields
- **`min_add::TimeProfile`** is the minimum added capacity in a strategic period. In the
  case of `SemiContinuousInvestment`, this implies that the model **must** invest at least
  in this capacity in each strategic period. The model can also choose not too invest at
  all.
- **`max_add::TimeProfile`** is the maximum added capacity in a strategic period.
"""
struct SemiContinuousInvestment <: SemiContiInvestment
    min_add::TimeProfile
    max_add::TimeProfile
end

"""
    SemiContinuousOffsetInvestment <: Investment

Semi-continuous investments, that is the added capacity is either zero or between a minimum
and a maximum value. In this subtype, the cost is not crossing the origin. Instead, there
is an offset.

Semi-continuous investments introduce one binary variable for each strategic period.

# Fields
- **`max_add::TimeProfile`** is the maximum added capacity in a strategic period.
- **`min_add::TimeProfile`** is the minimum added capacity in a strategic period. In the
  case of `SemiContinuousInvestment`, this implies that the model **must** invest at least
  in this capacity in each strategic period. The model can also choose not too invest at
  all.
- **`capex_offset::TimeProfile`** is offset for the CAPEX in a strategic period.
"""
struct SemiContinuousOffsetInvestment <: SemiContiInvestment
    min_add::TimeProfile
    max_add::TimeProfile
    capex_offset::TimeProfile
end

"""
    LifetimeMode

Supertype for the lifetime mode.
"""
abstract type LifetimeMode end

"""
    UnlimitedLife <: LifetimeMode

The investment's life is not limited. The investment costs do not consider any
reinvestment or rest value.
"""
struct UnlimitedLife <: LifetimeMode end

"""
    StudyLife <: LifetimeMode

The investment lasts for the whole study period with adequate reinvestments at the end of
the lifetime and considering the rest value.

# Fields
- **`lifetime::TimeProfile`** is the chosen lifetime of the technology.
"""
struct StudyLife <: LifetimeMode
    lifetime::TimeProfile
end
"""
    PeriodLife <: LifetimeMode

The investment is considered to last only for the strategic period. The excess
lifetime is considered in the rest value. If the lifetime is lower than the length
of the period, reinvestment is considered as well.

# Fields
- **`lifetime::TimeProfile`** is the chosen lifetime of the technology.
"""
struct PeriodLife <: LifetimeMode
    lifetime::TimeProfile
end

"""
    RollingLife <: LifetimeMode

The investment is rolling to the next strategic periods and it is retired at the
end of its lifetime or the end of the previous strategic period if its lifetime
ends between two periods.

# Fields
- **`lifetime::TimeProfile`** is the chosen lifetime of the technology.
"""
struct RollingLife <: LifetimeMode
    lifetime::TimeProfile
end

"""
Abstract type for the extra data for investing in technologies.
"""
abstract type InvestmentData <: EMB.Data end

"""
    GeneralInvData

Supertype for investment data for nodal investments.
"""
abstract type GeneralInvData <: InvestmentData end

"""
    StartInvData <: GeneralInvData

Investment data in which the initial capacity is not specified in the `InvestmentData`.
Instead, the initial capacity is deduced from the capacity of the technology.

It uses the macro `Base.@kwdef` to use keyword arguments and default values.
Hence, the name of the parameters have to be specified.

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

"""
    StartInvData <: GeneralInvData

Investment data in which the initial capacity is specified in the `InvestmentData`.
The structure is similiar to [`NoStartInvData`](@ref) with the addition of the field
**`initial::Real`**, see below.

It uses the macro `Base.@kwdef` to use keyword arguments and default values.
Hence, the name of the parameters have to be specified.

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
"""
    StorageInvData <: InvestmentData

Extra investment data for storage investments. The extra ivnestment data for storage
investments can, but does not require investment data for the charge capacity of the storage
(**`charge`**), increasing the storage capacity (**`level`**), or the doscharge capacity of
the storage (**`discharge`**).

It uses the macro `Base.@kwdef` to use keyword arguments and default values.
Hence, the name of the parameters have to be specified.

# Fields
- **`charge::Union{GeneralInvData, Nothing}`** is the investment data for the charge capacity.
- **`level::Union{GeneralInvData, Nothing}`** is the investment data for the level capacity.
- **`discharge::Union{GeneralInvData, Nothing}`** is the investment data for the
  discharge capacity.
"""
@kwdef struct StorageInvData <: InvestmentData
    charge::Union{GeneralInvData, Nothing} = nothing
    level::Union{GeneralInvData, Nothing} = nothing
    discharge::Union{GeneralInvData, Nothing} = nothing
end
