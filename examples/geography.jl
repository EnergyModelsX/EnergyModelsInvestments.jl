using Pkg
# Activate the local environment including EnergyModelsInvestments, HiGHS, PrettyTables
Pkg.activate(@__DIR__)
# Install the dependencies.
Pkg.instantiate()

# Import the required packages
using EnergyModelsBase
using EnergyModelsGeography
using EnergyModelsInvestments
using HiGHS
using JuMP
using TimeStruct

const EMB = EnergyModelsBase
const EMG = EnergyModelsGeography
const EMI = EnergyModelsInvestments

"""
    generate_example_data()

Generate the data for an example consisting of a simple electricity network. The simple \
network is existing within 5 regions with differing demand. Each region has the same \
technologies.

The example is partly based on the provided example `network.jl` in `EnergyModelsGeography`.
It will be repalced in the near future with a simplified example.
"""

function generate_example_data()
    @debug "Generate case data"
    @info "Generate data coded dummy model for now (Investment Model)"

    # Retrieve the products
    products = get_resources()
    NG = products[1]
    Power = products[3]
    CO2 = products[4]

    # Create input data for the areas
    area_ids = [1, 2, 3, 4]
    d_scale = Dict(1 => 3.0, 2 => 1.5, 3 => 1.0, 4 => 0.5)
    mc_scale = Dict(1 => 2.0, 2 => 2.0, 3 => 1.5, 4 => 0.5)
    gen_scale = Dict(1 => 1.0, 2 => 1.0, 3 => 1.0, 4 => 0.5)

    # Create identical areas with index according to input array
    an = Dict()
    transmission = []
    nodes = []
    links = []
    for a_id in area_ids
        n, l = get_sub_system_data(
            a_id,
            products;
            gen_scale = gen_scale[a_id],
            mc_scale = mc_scale[a_id],
            d_scale = d_scale[a_id],
        )
        append!(nodes, n)
        append!(links, l)

        # Add area node for each subsystem
        an[a_id] = n[1]
    end

    # Create the individual areas
    areas = [
        RefArea(1, "Oslo", 10.751, 59.921, an[1]),
        RefArea(2, "Bergen", 5.334, 60.389, an[2]),
        RefArea(3, "Trondheim", 10.398, 63.437, an[3]),
        RefArea(4, "Tromsø", 18.953, 69.669, an[4]),
    ]

    # Create the investment data for the different power line investment modes
    inv_data_12 = TransInvData(
        capex_trans = FixedProfile(500),
        trans_max_inst = FixedProfile(50),
        trans_max_add = FixedProfile(100),
        trans_min_add = FixedProfile(0),
        inv_mode = BinaryInvestment(),
        trans_start = 0,
    )

    inv_data_13 = TransInvData(
        capex_trans = FixedProfile(10),
        trans_max_inst = FixedProfile(100),
        trans_max_add = FixedProfile(100),
        trans_min_add = FixedProfile(10),
        inv_mode = SemiContinuousInvestment(),
        trans_start = 0,
    )

    inv_data_23 = TransInvData(
        capex_trans = FixedProfile(10),
        trans_max_inst = FixedProfile(50),
        trans_max_add = FixedProfile(100),
        trans_min_add = FixedProfile(5),
        inv_mode = DiscreteInvestment(),
        trans_increment = FixedProfile(6),
        trans_start = 20,
    )

    inv_data_34 = TransInvData(
        capex_trans = FixedProfile(10),
        trans_max_inst = FixedProfile(50),
        trans_max_add = FixedProfile(100),
        trans_min_add = FixedProfile(1),
        inv_mode = ContinuousInvestment(),
        trans_start = 0,
    )

    # Create the TransmissionModes and the Transmission corridors
    OverheadLine_50MW_12 = RefStatic("PowerLine_50", Power, FixedProfile(50.0), FixedProfile(0.05), FixedProfile(0), FixedProfile(0), 2, [inv_data_12])
    OverheadLine_50MW_13 = RefStatic("PowerLine_50", Power, FixedProfile(50.0), FixedProfile(0.05), FixedProfile(0), FixedProfile(0), 2, [inv_data_13])
    OverheadLine_50MW_23 = RefStatic("PowerLine_50", Power, FixedProfile(50.0), FixedProfile(0.05), FixedProfile(0), FixedProfile(0), 2, [inv_data_23])
    OverheadLine_50MW_34 = RefStatic("PowerLine_50", Power, FixedProfile(50.0), FixedProfile(0.05), FixedProfile(0), FixedProfile(0), 2, [inv_data_34])
    LNG_Ship_100MW = RefDynamic("LNG_100", NG, FixedProfile(100.0), FixedProfile(0.05), FixedProfile(0), FixedProfile(0), 2, [])

    transmission = [
        Transmission(
            areas[1],
            areas[2],
            [OverheadLine_50MW_12],
        ),
        Transmission(
            areas[1],
            areas[3],
            [OverheadLine_50MW_13],
        ),
        Transmission(
            areas[2],
            areas[3],
            [OverheadLine_50MW_23],
        ),
        Transmission(
            areas[3],
            areas[4],
            [OverheadLine_50MW_34],
        ),
        Transmission(areas[4], areas[2], [LNG_Ship_100MW]),
    ]

    # Creation of the time structure and global data
    T = TwoLevel(4, 1, SimpleTimes(24, 1))
    em_limits =
        Dict(NG => FixedProfile(1e6), CO2 => StrategicProfile([450, 400, 350, 300]))
    em_cost = Dict(NG => FixedProfile(0), CO2 => FixedProfile(0))
    modeltype = InvestmentModel(em_limits, em_cost, CO2, 0.07)


    # WIP data structure
    case = Dict(
        :areas => Array{Area}(areas),
        :transmission => Array{Transmission}(transmission),
        :nodes => Array{EMB.Node}(nodes),
        :links => Array{Link}(links),
        :products => products,
        :T => T,
    )
    return case, modeltype
end


function get_resources()

    # Define the different resources
    NG = ResourceEmit("NG", 0.2)
    Coal = ResourceCarrier("Coal", 0.35)
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)
    products = [NG, Coal, Power, CO2]

    return products
end


function get_sub_system_data(
        i,
        products;
        gen_scale::Float64 = 1.0,
        mc_scale::Float64 = 1.0,
        d_scale::Float64 = 1.0,
        demand = false,
    )

    NG, Coal, Power, CO2 = products

    if demand == false
        demand = [
            OperationalProfile([20, 20, 20, 20, 25, 30, 35, 35, 40, 40, 40, 40, 40, 35, 35, 30, 25, 30, 35, 30, 25, 20, 20, 20]),
            OperationalProfile([20, 20, 20, 20, 25, 30, 35, 35, 40, 40, 40, 40, 40, 35, 35, 30, 25, 30, 35, 30, 25, 20, 20, 20]),
            OperationalProfile([20, 20, 20, 20, 25, 30, 35, 35, 40, 40, 40, 40, 40, 35, 35, 30, 25, 30, 35, 30, 25, 20, 20, 20]),
            OperationalProfile([20, 20, 20, 20, 25, 30, 35, 35, 40, 40, 40, 40, 40, 35, 35, 30, 25, 30, 35, 30, 25, 20, 20, 20])
        ]
        demand *= d_scale
    end

    j = (i - 1) * 100
    nodes = [
        GeoAvailability(j + 1, products),
        RefSink(
            j + 2,
            StrategicProfile(demand),
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
            Dict(Power => 1),
        ),
        RefSource(
            j + 3,
            FixedProfile(30),
            FixedProfile(30 * mc_scale),
            FixedProfile(100),
            Dict(NG => 1),
            [
                NoStartInvData(
                    FixedProfile(1000), # capex [€/kW]
                    FixedProfile(200),  # max installed capacity [kW]
                    ContinuousInvestment(FixedProfile(10), FixedProfile(200)), # investment mode
                    UnlimitedLife(),    # lifetime mode
                ),
            ],
        ),
        RefSource(
            j + 4,
            FixedProfile(9),
            FixedProfile(9 * mc_scale),
            FixedProfile(100),
            Dict(Coal => 1),
            [
                StartInvData(
                    FixedProfile(1000), # capex [€/kW]
                    FixedProfile(200),  # max installed capacity [kW]
                    0,
                    ContinuousInvestment(FixedProfile(10), FixedProfile(200)), # investment mode
                    UnlimitedLife(),    # lifetime mode
                ),
            ],
        ),
        RefNetworkNode(
            j + 5,
            FixedProfile(0),
            FixedProfile(5.5 * mc_scale),
            FixedProfile(100),
            Dict(NG => 2),
            Dict(Power => 1, CO2 => 0),
            [
                NoStartInvData(
                    FixedProfile(600),  # capex [€/kW]
                    FixedProfile(25),   # max installed capacity [kW]
                    ContinuousInvestment(FixedProfile(0), FixedProfile(25)), # investment mode
                    UnlimitedLife(),    # lifetime mode
                ),
                CaptureEnergyEmissions(0.9)
            ],
        ),
        RefNetworkNode(
            j + 6,
            FixedProfile(0),
            FixedProfile(6 * mc_scale),
            FixedProfile(100),
            Dict(Coal => 2.5),
            Dict(Power => 1),
            [
                NoStartInvData(
                    FixedProfile(800),  # capex [€/kW]
                    FixedProfile(25),   # max installed capacity [kW]
                    ContinuousInvestment(FixedProfile(0), FixedProfile(25)), # investment mode
                    UnlimitedLife(),    # lifetime mode
                ),
                EmissionsEnergy(),
            ],
        ),
        RefStorage{AccumulatingEmissions}(
            j + 7,
            StorCapOpex(FixedProfile(0), FixedProfile(9.1 * mc_scale), FixedProfile(100)),
            StorCap(FixedProfile(0)),
            CO2,
            Dict(CO2 => 1, Power => 0.02),
            Dict(CO2 => 1),
            [
                StorageInvData(
                    charge = NoStartInvData(
                        FixedProfile(500),
                        FixedProfile(600),
                        ContinuousInvestment(FixedProfile(0), FixedProfile(600)),
                        UnlimitedLife(),
                    ),
                    level = NoStartInvData(
                        FixedProfile(500),
                        FixedProfile(600),
                        ContinuousInvestment(FixedProfile(0), FixedProfile(600)),
                        UnlimitedLife(),
                    )
                ),
            ],
        ),
        RefNetworkNode(
            j + 8,
            FixedProfile(0),
            FixedProfile(0 * mc_scale),
            FixedProfile(0),
            Dict(Coal => 2.5),
            Dict(Power => 1),
            [
                NoStartInvData(
                    FixedProfile(10000),    # capex [€/kW]
                    FixedProfile(25),       # max installed capacity [kW]
                    ContinuousInvestment(FixedProfile(0), FixedProfile(2)), # investment mode
                    UnlimitedLife(),        # lifetime mode
                ),
                EmissionsEnergy(),
            ],
        ),
        RefStorage{AccumulatingEmissions}(
            j + 9,
            StorCapOpex(FixedProfile(3), FixedProfile(0 * mc_scale), FixedProfile(0)),
            StorCap(FixedProfile(5)),
            CO2,
            Dict(CO2 => 1, Power => 0.02),
            Dict(CO2 => 1),
            [
                StorageInvData(
                    charge = NoStartInvData(
                        FixedProfile(500),
                        FixedProfile(30),
                        ContinuousInvestment(FixedProfile(0), FixedProfile(3)),
                        UnlimitedLife(),
                    ),
                    level = NoStartInvData(
                        FixedProfile(500),
                        FixedProfile(50),
                        ContinuousInvestment(FixedProfile(0), FixedProfile(2)),
                        UnlimitedLife(),
                    )
                ),
            ],
        ),
        RefNetworkNode(
            j + 10,
            FixedProfile(0),
            FixedProfile(0 * mc_scale),
            FixedProfile(0),
            Dict(Coal => 2.5),
            Dict(Power => 1),
            [
                NoStartInvData(
                    FixedProfile(10000),        # capex [€/kW]
                    FixedProfile(10000),     # max installed capacity [kW]
                    ContinuousInvestment(FixedProfile(0), FixedProfile(10000)), # investment mode
                    UnlimitedLife(),    # lifetime mode
                ),
                EmissionsEnergy(),
            ],
        ),
    ]

    links = [
        Direct(j * 10 + 15, nodes[1], nodes[5], Linear())
        Direct(j * 10 + 16, nodes[1], nodes[6], Linear())
        Direct(j * 10 + 17, nodes[1], nodes[7], Linear())
        Direct(j * 10 + 18, nodes[1], nodes[8], Linear())
        Direct(j * 10 + 19, nodes[1], nodes[9], Linear())
        Direct(j * 10 + 110, nodes[1], nodes[10], Linear())
        Direct(j * 10 + 12, nodes[1], nodes[2], Linear())
        Direct(j * 10 + 31, nodes[3], nodes[1], Linear())
        Direct(j * 10 + 41, nodes[4], nodes[1], Linear())
        Direct(j * 10 + 51, nodes[5], nodes[1], Linear())
        Direct(j * 10 + 61, nodes[6], nodes[1], Linear())
        Direct(j * 10 + 71, nodes[7], nodes[1], Linear())
        Direct(j * 10 + 81, nodes[8], nodes[1], Linear())
        Direct(j * 10 + 91, nodes[9], nodes[1], Linear())
        Direct(j * 10 + 101, nodes[10], nodes[1], Linear())
    ]
    return nodes, links
end


# Generate case data
case, model = generate_example_data()
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
m = EMG.create_model(case, model)
set_optimizer(m, optimizer)
optimize!(m)

solution_summary(m)

# Uncomment to print all the constraints set in the model.
# print(m)

solution_summary(m)
