"""
Main module for `EnergyModelsInvestments`.

This module implements functionalities allowing to run investment analysis.

It is in its current version extending `EnergyModelsBase` and cannot be used as a
stand-alone module.

The extension `EMIGeoExt` includes furthermore the investment options for transmission
modes as described in `EnergyModelsGeography`.
"""
module EnergyModelsInvestments

using JuMP
using TimeStruct
using SparseVariables

const TS = TimeStruct

# Different introduced types
include(joinpath("structures", "investment_mode.jl"))
include(joinpath("structures", "lifetime_mode.jl"))
include(joinpath("structures", "investment_data.jl"))

# Core structure of the code
include("model.jl")
include("utils.jl")

# Functions to be extended by users of EnergyModelsInvestments
include("interface.jl")

# Export of the types for investment modes
export Investment,
    BinaryInvestment,
    DiscreteInvestment,
    ContinuousInvestment,
    SemiContiInvestment,
    SemiContinuousInvestment,
    SemiContinuousOffsetInvestment,
    FixedInvestment

# Export of the different lifetime modes
export LifetimeMode
export UnlimitedLife, StudyLife, PeriodLife, RollingLife

# Export of the types for the additional investment data
export AbstractInvData, NoStartInvData, StartInvData

# Export of the types for extracting fields
export investment_data, investment_mode

# Geographical investment data
export TransInvData

# Utility functions
export has_investment


end # module
