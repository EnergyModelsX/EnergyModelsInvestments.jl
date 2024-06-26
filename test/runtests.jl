using HiGHS
using JuMP
using Pkg
using Test

using EnergyModelsBase
using EnergyModelsGeography
using EnergyModelsInvestments
using Logging
using TimeStruct

const EMB = EnergyModelsBase
const EMG = EnergyModelsGeography
const EMI = EnergyModelsInvestments
const TS = TimeStruct

include("utils.jl")

@testset "Investments" begin
    nologger = ConsoleLogger(devnull, Logging.Debug)
    with_logger(nologger) do
        include("test_model.jl")
        include("test_lifetime.jl")
        include("test_checks.jl")
        include("test_examples.jl")

        @testset "w/Geography" begin
            include("test_geo.jl")
        end
    end
end
