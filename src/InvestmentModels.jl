module InvestmentModels

using EnergyModelsBase
using JuMP
using TimeStructures

const EMB = EnergyModelsBase

include("datastructures.jl")
include("model.jl")
include("user_interface.jl")

end # module
