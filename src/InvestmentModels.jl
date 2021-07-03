module InvestmentModels

using EnergyModelsBase
using JuMP
using TimeStructures

const EMB = EnergyModelsBase

include("datastructures.jl")
include("model.jl")
include("scaling_and_discounting.jl")
include("user_interface.jl")
incldue("utils.jl")

export obj_weight, obj_weight_inv, obj_weight_inv_end
export discount_mult_avg

end # module
