module EMIGeoExt

using EnergyModelsBase
using EnergyModelsInvestments
using EnergyModelsGeography
using JuMP
using TimeStructures

const EMB = EnergyModelsBase
const EMI = EnergyModelsInvestments
const EMG = EnergyModelsGeography
const TS = TimeStructures

include("datastructures.jl")
include("model.jl")
include("utils.jl")

end