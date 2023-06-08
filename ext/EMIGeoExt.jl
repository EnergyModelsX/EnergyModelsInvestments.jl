module EMIGeoExt

using EnergyModelsBase
using EnergyModelsInvestments
using EnergyModelsGeography
using JuMP
using TimeStruct

const EMB = EnergyModelsBase
const EMI = EnergyModelsInvestments
const EMG = EnergyModelsGeography
const TS = TimeStruct

include("datastructures.jl")
include("model.jl")
include("utils.jl")

end