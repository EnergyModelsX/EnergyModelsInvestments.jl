using Test
using InvestmentModels
using TimeStructures
using EnergyModelsBase
using JuMP
using GLPK
const IM = InvestmentModels
const EMB = EnergyModelsBase
const TS = TimeStructures


#include("test_discounting.jl")
#include("test_model.jl")
#include("test_geo.jl")
include("test_lifetime.jl")
