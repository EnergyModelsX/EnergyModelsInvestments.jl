using Test
using InvestmentModels
using TimeStructures
using EnergyModelsBase
using JuMP
using GLPK
const IM = InvestmentModels
const EMB = EnergyModelsBase


include("test_discounting.jl")
include("test_model.jl")