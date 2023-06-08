using Pkg
# Activate the test-environment, where PrettyTables and HiGHS are added as dependencies.
Pkg.activate(joinpath(@__DIR__, "../test"))
# Install the dependencies.
Pkg.instantiate()
# Add the package EnergyModelsInvestments to the environment.
Pkg.develop(path=joinpath(@__DIR__, ".."))

using EnergyModelsBase
using EnergyModelsInvestments
using HiGHS
using JuMP
using PrettyTables
using TimeStruct

const EMB = EnergyModelsBase
const EMI = EnergyModelsInvestments
const TS = TimeStruct

# Define the required resources
CO2 = ResourceEmit("CO2", 1.0)
Power = ResourceCarrier("Power", 0.0)
products = [Power, CO2]

function demo_invest(lifemode = UnlimitedLife(); discount_rate = 0.05)
    lifetime = FixedProfile(15)
    sp_dur = 5

    products = [Power, CO2]
    # Create dictionary with entries of 0. for all resources
    𝒫₀ = Dict(k => 0 for k ∈ products)
    # Create dictionary with entries of 0. for all emission resources
    𝒫ᵉᵐ₀ = Dict(k => 0.0 for k ∈ products if typeof(k) == ResourceEmit{Float64})
    𝒫ᵉᵐ₀[CO2] = 0.0

    investment_data_source = InvData(
        Capex_cap = FixedProfile(1000), # capex [€/kW]
        Cap_max_inst = FixedProfile(30), #  max installed capacity [kW]
        Cap_max_add = FixedProfile(30), # max_add [kW]
        Cap_min_add = FixedProfile(0), # min_add [kW]
        Life_mode = lifemode,
        Lifetime = lifetime,
    )

    source = EMB.RefSource(
        "src",
        FixedProfile(0),
        FixedProfile(10),
        FixedProfile(5),
        Dict(Power => 1),
        [investment_data_source],
    )

    sink = EMB.RefSink(
        "snk",
        FixedProfile(20),
        Dict(:Surplus => FixedProfile(0), :Deficit => FixedProfile(1e6)),
        Dict(Power => 1),
    )

    nodes = [EMB.GenAvailability(1, 𝒫₀, 𝒫₀), source, sink]
    links = [
        EMB.Direct(21, nodes[2], nodes[1], EMB.Linear())
        EMB.Direct(13, nodes[1], nodes[3], EMB.Linear())
    ]

    T = TwoLevel(4, sp_dur, SimpleTimes(4, 1))
    em_limits =
        Dict(CO2 => StrategicProfile([450, 400, 350, 300]))
    em_cost = Dict(CO2 => FixedProfile(0))
    model = InvestmentModel(em_limits, em_cost, CO2, discount_rate)

    case = Dict(
        :nodes => nodes,
        :links => links,
        :products => products,
        :T => T,
    )

    # Create model and optimize
    m = EMB.create_model(case, model)
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
    set_optimizer(m, optimizer)
    optimize!(m)

    # Display some results
    pretty_table(
        JuMP.Containers.rowtable(
            value,
            m[:cap_add];
            header = [:Source, :StrategicPeriod, :CapInvest],
        ),
    )
    return m
end

m = demo_invest();
