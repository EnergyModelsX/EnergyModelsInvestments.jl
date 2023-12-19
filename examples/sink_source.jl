if !isequal(splitpath(Base.active_project())[end-1], "test")
    using Pkg
    # Activate the test-environment, where PrettyTables and HiGHS are added as dependencies.
    Pkg.activate(joinpath(@__DIR__, "../test"))
    # Install the dependencies.
    Pkg.instantiate()
    # Add the package EnergyModelsInvestments to the environment.
    Pkg.develop(path=joinpath(@__DIR__, ".."))
end

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

    investment_data_source = InvData(
        capex_cap = FixedProfile(1000), # capex [€/kW]
        cap_max_inst = FixedProfile(30), #  max installed capacity [kW]
        cap_max_add = FixedProfile(30), # max_add [kW]
        cap_min_add = FixedProfile(0), # min_add [kW]
        life_mode = lifemode,
        lifetime = lifetime,
    )

    source = RefSource(
        "src",
        FixedProfile(0),
        FixedProfile(10),
        FixedProfile(5),
        Dict(Power => 1),
        [investment_data_source],
    )

    sink = RefSink(
        "snk",
        FixedProfile(20),
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
        Dict(Power => 1),
    )

    nodes = [GenAvailability(1,products), source, sink]
    links = [
        Direct(21, nodes[2], nodes[1], Linear())
        Direct(13, nodes[1], nodes[3], Linear())
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
