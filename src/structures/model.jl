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
- **`r::Float64`** is the discount rate in the investment optimization.
"""
struct InvestmentModel <: AbstractInvestmentModel
    emission_limit::Dict{<:ResourceEmit, <:TimeProfile}
    emission_price::Dict{<:ResourceEmit, <:TimeProfile}
    co2_instance::ResourceEmit
    r::Float64
end

"""
    discount_rate(modeltype::AbstractInvestmentModel)

Returns the discount rate of `EnergyModel` modeltype
"""
discount_rate(modeltype::AbstractInvestmentModel) = modeltype.r
