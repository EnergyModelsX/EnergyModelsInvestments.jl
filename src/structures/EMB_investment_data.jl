"""
Abstract type for the extra data for investing in technologies.
"""
abstract type InvestmentData <: EMB.Data end

"""
    StorageInvData <: InvestmentData

Extra investment data for storage investments. The extra ivnestment data for storage
investments can, but does not require investment data for the charge capacity of the storage
(**`charge`**), increasing the storage capacity (**`level`**), or the doscharge capacity of
the storage (**`discharge`**).

It uses the macro `Base.@kwdef` to use keyword arguments and default values.
Hence, the names of the parameters have to be specified.

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

"""
    SingleInvData <: InvestmentData

Extra investment data for type investments. The extra investment data has only a single
field in which [`GeneralInvData`](@ref) has to be added.

The advantage of separating `GeneralInvData` from the `InvestmentData` node is to allow
easier separation of `EnergyModelsInvestments` and `EnergyModelsBase` and provides the user
with the potential of introducing new capacities for types.

# Fields
- **`cap::GeneralInvData`** is the investment data for the capacity.

When multiple inputs are provided, a constructor directly creates the corresponding
`GeneralInvData`.

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
    cap::GeneralInvData
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
    investment_data(type)

Return the investment data of the type `type`.
"""
investment_data(type) = filter(data -> typeof(data) <: InvestmentData, type.data)[1]

"""

investment_data(inv_data::SingleInvData)

Return the investment data of the investment data `SingleInvData`.
"""
investment_data(inv_data::SingleInvData) = inv_data.cap

"""
    investment_data(type, field::Symbol)

Return the investment data of the type `type` of the capacity `field`.
"""
investment_data(type, field::Symbol) =
    getproperty(investment_data(type), field)

"""
    has_investment(type)

For a given `Node`, checks that it contains the required investment data.
"""
function has_investment(type)
    (
        hasproperty(type, :data) &&
        !isempty(filter(data -> typeof(data) <: InvestmentData, type.data))
    )
end
"""
    has_investment(n::Storage, field::Symbol)

When the type is a `Storage` node, checks that it contains investments for the field
`field`, that is `:charge`, `:level`, or `:discharge`.
"""
function has_investment(n::Storage, field::Symbol)
    (
        hasproperty(n, :data) &&
        !isempty(filter(data -> typeof(data) <: InvestmentData, node_data(n))) &&
        !isnothing(getproperty(investment_data(n), field))
    )
end

"""
    nodes_investment(𝒩::Vector{<:EMB.Node})

For a given `Vector{<:Node}`, return all `Node`s with investments.
"""
nodes_investment(𝒩::Vector{<:EMB.Node}) = filter(has_investment, 𝒩)
