"""
Main module for `EnergyModelsInvestments.jl`.

This module implements functionalities allowing to run investment analysis.
It also defines weighting and discounting options: obj_weight, obj_weight_inv, obj_weight_inv_end
export discount_mult_avg.
"""
module EnergyModelsInvestments

using EnergyModelsBase
using JuMP
using TimeStructures

const EMB = EnergyModelsBase
const TS = TimeStructures

include("datastructures.jl")
include("model.jl")
include("scaling_and_discounting.jl")
include("utils.jl")
include("checks.jl")


export InvestmentModel
export BinaryInvestment, DiscreteInvestment, ContinuousInvestment, SemiContinuousInvestment, 
    FixedInvestment, ContinuousFixedInvestment
export InvData, InvDataStorage

export obj_weight, obj_weight_inv, obj_weight_inv_end
export discount_mult_avg

export InvestmentData

# Geographical investments
export TransInvData

end # module
