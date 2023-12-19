"""
    generate_data()

Generate the data for the tests.
"""
function generate_data()
    # Define the different resources
    NG       = ResourceEmit("NG", 0.2)
    Coal     = ResourceCarrier("Coal", 0.35)
    Power    = ResourceCarrier("Power", 0.)
    CO2      = ResourceEmit("CO2",1.)
    products = [NG, Coal, Power, CO2]

    nodes = [
        GenAvailability(1, products),
        RefSink(
            2,
            StrategicProfile([OperationalProfile([20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20]),
                              OperationalProfile([20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20]),
                              OperationalProfile([20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20]),
                              OperationalProfile([20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20])]
            ),
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
            Dict(Power => 1),
        ),
        RefSource(
            3,
            FixedProfile(30),
            FixedProfile(30),
            FixedProfile(100),
            Dict(NG => 1),
            [InvData(
                capex_cap = FixedProfile(1000),
                cap_max_inst = FixedProfile(200),
                cap_max_add = FixedProfile(200),
                cap_min_add = FixedProfile(10),
                inv_mode = ContinuousInvestment(),
                cap_increment = FixedProfile(5),
                cap_start = 15,
                ),
            ],
        ),
        RefSource(
            4,
            FixedProfile(9),
            FixedProfile(9),
            FixedProfile(100),
            Dict(Coal => 1),
            [InvData(
                    capex_cap = FixedProfile(1000),
                    cap_max_inst = FixedProfile(200),
                    cap_max_add = FixedProfile(200),
                    cap_min_add = FixedProfile(0),
                    inv_mode = ContinuousInvestment(),
                ),
            ],
        ),
        RefNetworkNode(
            5,
            FixedProfile(0),
            FixedProfile(5.5),
            FixedProfile(100),
            Dict(NG => 2),
            Dict(Power => 1, CO2 => 0),
            [
                InvData(
                    capex_cap = FixedProfile(600),
                    cap_max_inst = FixedProfile(25),
                    cap_max_add = FixedProfile(25),
                    cap_min_add = FixedProfile(0),
                    inv_mode = ContinuousInvestment(),
                ),
                CaptureEnergyEmissions(0.9),
            ],
        ),
        RefNetworkNode(
            6,
            FixedProfile(0),
            FixedProfile(6),
            FixedProfile(100),
            Dict(Coal => 2.5),
            Dict(Power => 1),
            [
                InvData(
                    capex_cap = FixedProfile(800),
                    cap_max_inst = FixedProfile(25),
                    cap_max_add = FixedProfile(25),
                    cap_min_add = FixedProfile(0),
                    inv_mode = ContinuousInvestment(),
                ),
                EmissionsEnergy(),
            ],
        ),
        RefStorage(
            7,
            FixedProfile(0),
            FixedProfile(0),
            FixedProfile(9.1),
            FixedProfile(100),
            CO2,
            Dict(CO2 => 1, Power => 0.02),
            Dict(CO2 => 1),
            [InvDataStorage(
                    capex_rate = FixedProfile(0),
                    rate_max_inst = FixedProfile(600),
                    rate_max_add = FixedProfile(600),
                    rate_min_add = FixedProfile(0),
                    capex_stor = FixedProfile(500),
                    stor_max_inst = FixedProfile(600),
                    stor_max_add = FixedProfile(600),
                    stor_min_add = FixedProfile(0),
                    inv_mode = ContinuousInvestment(),
                ),
            ],
        ),
        RefNetworkNode(
            8,
            FixedProfile(2),
            FixedProfile(0),
            FixedProfile(0),
            Dict(Coal => 2.5),
            Dict(Power => 1),
            [
                InvData(
                    capex_cap = FixedProfile(0),
                    cap_max_inst = FixedProfile(25),
                    cap_max_add = FixedProfile(2),
                    cap_min_add = FixedProfile(2),
                    inv_mode = ContinuousInvestment(),
                ),
                EmissionsEnergy(),
            ],
        ),
        RefStorage(
            9,
            FixedProfile(3),
            FixedProfile(5),
            FixedProfile(0),
            FixedProfile(0),
            CO2,
            Dict(CO2 => 1, Power => 0.02),
            Dict(CO2 => 1),
            [InvDataStorage(
                    capex_rate = FixedProfile(0),
                    rate_max_inst = FixedProfile(30),
                    rate_max_add = FixedProfile(3),
                    rate_min_add = FixedProfile(3),
                    capex_stor = FixedProfile(0),
                    stor_max_inst = FixedProfile(50),
                    stor_max_add = FixedProfile(5),
                    stor_min_add = FixedProfile(5),
                    inv_mode = ContinuousInvestment(),
                ),
            ],
        ),
        RefNetworkNode(
            10,
            FixedProfile(0),
            FixedProfile(0),
            FixedProfile(0),
            Dict(Coal => 2.5),
            Dict(Power => 1),
            [
                InvData(
                    capex_cap = FixedProfile(10000),
                    cap_max_inst = FixedProfile(10000),
                    cap_max_add = FixedProfile(10000),
                    cap_min_add = FixedProfile(0),
                    inv_mode = ContinuousInvestment(),
                ),
                EmissionsEnergy(),
            ],
        ),
    ]
    links = [
        Direct(15,nodes[1],nodes[5],Linear())
        Direct(16,nodes[1],nodes[6],Linear())
        Direct(17,nodes[1],nodes[7],Linear())
        Direct(18,nodes[1],nodes[8],Linear())
        Direct(19,nodes[1],nodes[9],Linear())
        Direct(110,nodes[1],nodes[10],Linear())
        Direct(12,nodes[1],nodes[2],Linear())
        Direct(31,nodes[3],nodes[1],Linear())
        Direct(41,nodes[4],nodes[1],Linear())
        Direct(51,nodes[5],nodes[1],Linear())
        Direct(61,nodes[6],nodes[1],Linear())
        Direct(71,nodes[7],nodes[1],Linear())
        Direct(81,nodes[8],nodes[1],Linear())
        Direct(91,nodes[9],nodes[1],Linear())
        Direct(101,nodes[10],nodes[1],Linear())
    ]

    # Creation of the time structure and global data
    T           = TwoLevel(4, 1, SimpleTimes(24, 1), op_per_strat=24)
    em_limits   = Dict(NG => FixedProfile(1e6), CO2 => StrategicProfile([450, 400, 350, 300]))
    em_cost     = Dict(NG => FixedProfile(0),   CO2 => FixedProfile(0))
    modeltype = InvestmentModel(em_limits, em_cost, CO2, 0.07)

    # WIP case structure
    case = Dict(
                :nodes       => nodes,
                :links       => links,
                :products    => products,
                :T           => T,
                )
    return case, modeltype
end
