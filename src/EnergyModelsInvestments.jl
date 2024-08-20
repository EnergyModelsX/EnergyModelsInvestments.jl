"""
Main module for `EnergyModelsInvestments`.

This module implements functionalities allowing to run investment analysis for [EnergyModelsX](https://github.com/EnergyModelsX)
system optimization models.

`EnergyModelsInvestments` cannot be used as stand-alone model. Instead, it extends existing
models and simplifies the incorporation of investment decisions. It can be used to any JuMP
model as long as certain functions are declared. One example is given by
[`EnergyModelsBase`](https://energymodelsx.github.io/EnergyModelsBase.jl/stable/).
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
