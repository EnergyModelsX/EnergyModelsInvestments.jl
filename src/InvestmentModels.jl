module InvestmentModels

using EnergyModelsBase
using JuMP
using TimeStructures
using Requires

const EMB = EnergyModelsBase
const TS = TimeStructures

include("datastructures.jl")
include("model.jl")
include("scaling_and_discounting.jl")
include("user_interface.jl")
include("utils.jl")
include("checks.jl")

function __init__()
    @require Geography="3f775d88-a4da-46c4-a2cc-aa9f16db6708" include("inv_geography/datastructures.jl")
    @require Geography="3f775d88-a4da-46c4-a2cc-aa9f16db6708" include("inv_geography/model.jl")
    @require Geography="3f775d88-a4da-46c4-a2cc-aa9f16db6708" include("inv_geography/user_interface.jl")
    @require Geography="3f775d88-a4da-46c4-a2cc-aa9f16db6708" include("inv_geography/utils.jl")
end

export obj_weight, obj_weight_inv, obj_weight_inv_end
export discount_mult_avg

end # module
