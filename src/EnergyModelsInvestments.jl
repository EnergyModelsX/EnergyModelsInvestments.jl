"""
Main module for `EnergyModelsInvestments.jl`.

This module implements functionalities allowing to run investment analysis.
It also defines weighting and discounting options: obj_weight, obj_weight_inv, obj_weight_inv_end
export discount_mult_avg.
"""
module EnergyModelsInvestments

using EnergyModelsBase
using JuMP
using TimeStruct

const EMB = EnergyModelsBase
const TS = TimeStruct

include("datastructures.jl")
include("model.jl")
# include("scaling_and_discounting.jl")
include("utils.jl")
include("checks.jl")


export InvestmentModel
export BinaryInvestment, DiscreteInvestment, ContinuousInvestment, SemiContinuousInvestment, 
    SemiContinuousOffsetInvestment, FixedInvestment

export LifetimeMode
export UnlimitedLife, StudyLife, PeriodLife, RollingLife

export InvData, InvDataStorage

export InvestmentData

# Geographical investments
export TransInvData

end # module
