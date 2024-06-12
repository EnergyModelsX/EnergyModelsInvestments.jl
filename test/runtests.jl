using HiGHS
using JuMP
using Pkg
using Test

using EnergyModelsBase
# using EnergyModelsGeography
using EnergyModelsInvestments
using Logging
using TimeStruct

const EMB = EnergyModelsBase
# const EMG = EnergyModelsGeography
const EMI = EnergyModelsInvestments
const TS = TimeStruct

include("utils.jl")

@testset "Investments" begin
    nologger = ConsoleLogger(devnull, Logging.Debug)
    with_logger(nologger) do

        @testset "Investments | model" begin
            include("test_model.jl")
        end

        @testset "Investments | lifetime" begin
            include("test_lifetime.jl")
        end

        @testset "Investments | checks" begin
            include("test_checks.jl")
        end

        @testset "Investments | examples" begin
            include("test_examples.jl")
        end

        # @testset "w/Geography" begin
        #         include("test_geo.jl")
        # end
    end
end
