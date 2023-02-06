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
using Requires

const EMB = EnergyModelsBase
const TS = TimeStructures

include("datastructures.jl")
include("model.jl")
include("scaling_and_discounting.jl")
include("utils.jl")
include("checks.jl")

function __init__()
    @require EnergyModelsGeography="3f775d88-a4da-46c4-a2cc-aa9f16db6708" include("inv_geography/datastructures.jl")
    @require EnergyModelsGeography="3f775d88-a4da-46c4-a2cc-aa9f16db6708" include("inv_geography/model.jl")
    @require EnergyModelsGeography="3f775d88-a4da-46c4-a2cc-aa9f16db6708" include("inv_geography/utils.jl")
end


export InvestmentModel
export BinaryInvestment, DiscreteInvestment, ContinuousInvestment, SemiContinuousInvestment, 
    FixedInvestment, ContinuousFixedInvestment
export extra_inv_data, extra_inv_data_storage

export obj_weight, obj_weight_inv, obj_weight_inv_end
export discount_mult_avg

# Geographical investments
export TransInvData

end # module
