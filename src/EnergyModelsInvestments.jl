"""
Main module for `EnergyModelsInvestments`.

This module implements functionalities allowing to run investment analysis.

It is in its current version extending `EnergyModelsBase` and cannot be used as a
stand-alone module.

The extension `EMIGeoExt` includes furthermore the investment options for transmission
modes as described in `EnergyModelsGeography`.
"""
module EnergyModelsInvestments

using EnergyModelsBase
using JuMP
using TimeStruct

const EMB = EnergyModelsBase
const TS = TimeStruct

include("datastructures.jl")
include("model.jl")
include("utils.jl")
include("checks.jl")

# Export of the types for investment models
export AbstractInvestmentModel, InvestmentModel

# Export of the types for investment modes
export Investment, BinaryInvestment, DiscreteInvestment, ContinuousInvestment,
    SemiContiInvestment, SemiContinuousInvestment, SemiContinuousOffsetInvestment,
    FixedInvestment

# Export of the different lifetime modes
export LifetimeMode
export UnlimitedLife, StudyLife, PeriodLife, RollingLife

# Export of the types for the additional investment data
export InvestmentData
export InvData, InvDataStorage

# Geographical investment data
export TransInvData

end # module
