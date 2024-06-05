"""
Abstract type for the extra data for investing in technologies.
"""
abstract type InvestmentData end

"""
    StorageInvData <: InvestmentData

Extra investment data for storage investments. The extra investment data for storage
investments can, but does not require investment data for the charge capacity of the storage
(**`charge`**), increasing the storage capacity (**`level`**), or the discharge capacity of
the storage (**`discharge`**).

It uses the macro `@kwdef` to use keyword arguments and default values.
Hence, the names of the parameters have to be specified.

# Fields
- **`charge::Union{AbstractInvData, Nothing}`** is the investment data for the charge capacity.
- **`level::Union{AbstractInvData, Nothing}`** is the investment data for the level capacity.
- **`discharge::Union{AbstractInvData, Nothing}`** is the investment data for the
  discharge capacity.
"""
@kwdef struct StorageInvData <: InvestmentData
    charge::Union{AbstractInvData, Nothing} = nothing
    level::Union{AbstractInvData, Nothing} = nothing
    discharge::Union{AbstractInvData, Nothing} = nothing
end

"""
    SingleInvData <: InvestmentData

Extra investment data for type investments. The extra investment data has only a single
field in which [`AbstractInvData`](@ref) has to be added.

The advantage of separating `AbstractInvData` from the `InvestmentData` node is to allow
easier separation of `EnergyModelsInvestments` and `EnergyModelsBase` and provides the user
with the potential of introducing new capacities for types.

# Fields
- **`cap::AbstractInvData`** is the investment data for the capacity.

When multiple inputs are provided, a constructor directly creates the corresponding
`AbstractInvData`.

# Fields
- **`capex::TimeProfile`** is the capital costs for investing in a capacity. The value is
  relative to the added capacity.
- **`max_inst::TimeProfile`** is the maximum installed capacity in a strategic period.
- **`initial::Real`** is the initial capacity. This results in the creation of a
  [`SingleInvData`](@ref) type for the investment data.
- **`inv_mode::Investment`** is the chosen investment mode for the technology. The following
  investment modes are currently available: [`BinaryInvestment`](@ref),
  [`DiscreteInvestment`](@ref), [`ContinuousInvestment`](@ref), [`SemiContinuousInvestment`](@ref)
  or [`FixedInvestment`](@ref).
- **`life_mode::LifetimeMode`** is type of handling the lifetime. Several different
  alternatives can be used: [`UnlimitedLife`](@ref), [`StudyLife`](@ref), [`PeriodLife`](@ref)
  or [`RollingLife`](@ref). If `life_mode` is not specified, the model assumes an
  [`UnlimitedLife`](@ref).
"""
struct SingleInvData <: InvestmentData
    cap::AbstractInvData
end
function SingleInvData(
        capex_trans::TimeProfile,
        trans_max_inst::TimeProfile,
        inv_mode::Investment,
)

    return SingleInvData(
        NoStartInvData(
            capex_trans,
            trans_max_inst,
            inv_mode,
        )
    )
end
function SingleInvData(
        capex_trans::TimeProfile,
        trans_max_inst::TimeProfile,
        inv_mode::Investment,
        life_mode::LifetimeMode,
)

    return SingleInvData(
        NoStartInvData(
            capex_trans,
            trans_max_inst,
            inv_mode,
            life_mode,
        )
    )
end
function SingleInvData(
    capex_trans::TimeProfile,
    trans_max_inst::TimeProfile,
    initial::Real,
    inv_mode::Investment,
)

    return SingleInvData(
        StartInvData(
            capex_trans,
            trans_max_inst,
            initial,
            inv_mode,
        )
    )
end
function SingleInvData(
    capex_trans::TimeProfile,
    trans_max_inst::TimeProfile,
    initial::Real,
    inv_mode::Investment,
    life_mode::LifetimeMode,
)

    return SingleInvData(
        StartInvData(
            capex_trans,
            trans_max_inst,
            initial,
            inv_mode,
            life_mode,
        )
    )
end
"""
    investment_data(element)

Return the investment data of the type `element`.
"""
investment_data(element) = filter(data -> typeof(data) <: InvestmentData, element.data)[1]

"""

investment_data(inv_data::SingleInvData)

Return the investment data of the investment data `SingleInvData`.
"""
investment_data(inv_data::SingleInvData) = inv_data.cap

"""
    investment_data(element, field::Symbol)

Return the investment data of the type `element` of the capacity `field`.
"""
investment_data(element, field::Symbol) =
    getproperty(investment_data(element), field)

"""
    has_investment(element)

For a given type `element`, checks that it contains the required investment data.
"""
function has_investment(element)
    (
        hasproperty(element, :data) &&
        !isnothing(findfirst(data->typeof(data)<:InvestmentData, element.data))
    )
end
