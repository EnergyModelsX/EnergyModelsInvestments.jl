const TEST_ATOL = 1e-6
⪆(x,y) = x > y || isapprox(x,y;atol=TEST_ATOL)
const OPTIMIZER = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)

"""
    optimize(cases)

Optimize the `case`.
"""
function optimize(case, modeltype; check_timeprofiles=true)
    m = EMB.create_model(case, modeltype; check_timeprofiles)
    set_optimizer(m, OPTIMIZER)
    optimize!(m)
    return m
end

"""
    general_tests(m)

Check if the solution is optimal.
"""
function general_tests(m)
    @testset "Optimal solution" begin
        @test termination_status(m) == MOI.OPTIMAL

        if termination_status(m) != MOI.OPTIMAL
            @show termination_status(m)
        end
    end
end


"""
    general_tests_stor(m)

Check if the solution is optimal.
"""
function general_tests_stor(m, stor, 𝒯, 𝒯ᴵⁿᵛ)
    @testset "Optimal solution" begin
        @test termination_status(m) == MOI.OPTIMAL

        if termination_status(m) != MOI.OPTIMAL
            @show termination_status(m)
        end
    end

    @testset "cap_inst" begin
        # Test that cap_inst is less than node.data.cap_max_inst at all times.
        @test sum(value.(m[:stor_level_inst][stor, t]) ≤
                    EMI.max_installed(EMI.investment_data(stor, :level), t) for t ∈ 𝒯) ==
                length(𝒯)
        @test sum(value.(m[:stor_charge_inst][stor, t]) ≤
                    EMI.max_installed(EMI.investment_data(stor, :charge), t) for t ∈ 𝒯) ==
                length(𝒯)
    end
    @testset "cap_add" begin
        # Test that the capacity is at least added once
        @test sum(value.(m[:stor_level_add][stor, t_inv]) > 0 for t_inv ∈ 𝒯ᴵⁿᵛ) > 0
        @test sum(value.(m[:stor_charge_add][stor, t_inv]) > 0 for t_inv ∈ 𝒯ᴵⁿᵛ) > 0
    end
end

# Declaration of the required resources
CO2 = ResourceEmit("CO2", 1.)
Power = ResourceCarrier("Power", 0.)
products = [Power, CO2]

"""
    small_graph()

Creates a simple test case consisting of a sink and source with the potential for
investments in capacity of the source if provided with investments through the
argument `inv_data`.
"""
function small_graph(;
                    source=nothing,
                    sink=nothing,
                    inv_data=nothing,
                    T=TwoLevel(4, 10, SimpleTimes(4, 1)),
                    discount_rate = 0.05,
                    )

    if isnothing(inv_data)
        investment_data_source = [
            NoStartInvData(
                FixedProfile(1000),     # capex [€/kW]
                FixedProfile(30),       # max installed capacity [kW]
                ContinuousInvestment(FixedProfile(5), FixedProfile(20)), # investment mode
                UnlimitedLife(),        # lifetime mode
            )
        ]
        demand_profile = FixedProfile(20)
    else
        investment_data_source = inv_data["investment_data"]
        demand_profile         = inv_data["profile"]
    end

    # Creation of the source and sink module as well as the arrays used for nodes and links
    if isnothing(source)
        source = RefSource("-src", FixedProfile(0), FixedProfile(10),
                               FixedProfile(5), Dict(Power => 1),
                               investment_data_source)
    end
    if isnothing(sink)
        sink = RefSink("-snk", demand_profile,
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e4)),
            Dict(Power => 1))
    end
    nodes = [source, sink]
    links = [Direct("scr-sink", nodes[1], nodes[2], Linear())]

    em_limits   = Dict(CO2 => StrategicProfile([450, 400, 350, 300]))
    em_cost     = Dict(CO2 => FixedProfile(0))
    modeltype  = InvestmentModel(em_limits, em_cost, CO2, discount_rate)

    case = Dict(:nodes       => nodes,
                :links       => links,
                :products    => products,
                :T           => T,
                )
    return case, modeltype
end

"""
    small_graph_stor()

Creates a simple test case consisting of a source, storage, and sink with the potential for
investments in capacity of the storage if provided with investments through the
argument `inv_data`.
"""
function small_graph_stor(;
                    inv_data=nothing,
                    rate_cap = FixedProfile(0),
                    stor_cap = FixedProfile(0),
                    rate_min_add = 5,
                    stor_min_add = 5,
                    op_dur = 10
                    )

    if isnothing(inv_data)
        inv_data = [
            StorageInvData(
                charge = NoStartInvData(
                    FixedProfile(20),
                    FixedProfile(30),
                    ContinuousInvestment(FixedProfile(rate_min_add), FixedProfile(30)),
                    UnlimitedLife(),
                ),
                level = NoStartInvData(
                    FixedProfile(500),
                    FixedProfile(600),
                    ContinuousInvestment(FixedProfile(stor_min_add), FixedProfile(600)),
                    UnlimitedLife(),
                )
            )
        ]
    end

    # Creation of the source and sink module as well as the arrays used for nodes and links
    source = RefSource(
        "src",
        OperationalProfile([10, 30, 5, 35]),
        FixedProfile(10),
        FixedProfile(5),
        Dict(Power => 1),
    )
    storage = RefStorage{CyclicStrategic}(
        "stor",
        StorCapOpexVar(rate_cap, FixedProfile(0)),
        StorCapOpexFixed(stor_cap, FixedProfile(100)),
        Power,
        Dict(Power => 1.0),
        Dict(Power => 1.0),
        inv_data,
    )
    sink = RefSink(
        "snk",
        FixedProfile(20),
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e5)),
        Dict(Power => 1),
        )
    nodes = [source, storage, sink]
    links = [
        Direct("src-stor", nodes[1], nodes[2], Linear())
        Direct("src-snk", nodes[1], nodes[3], Linear())
        Direct("stor-snk", nodes[2], nodes[3], Linear())
    ]

    em_limits   = Dict(CO2 => StrategicProfile([450, 400]))
    em_cost     = Dict(CO2 => FixedProfile(0))
    modeltype  = InvestmentModel(em_limits, em_cost, CO2, 0.05)

    T = TwoLevel(2, 5, SimpleTimes(4, op_dur))

    case = Dict(:nodes       => nodes,
                :links       => links,
                :products    => products,
                :T           => T,
                )
    return case, modeltype
end

"""
    small_graph_geo()

Creates a simple geography test case with the potential for investments in transmission
    infrastructure if provided with transmission investments through the argument `inv_data`.
"""
function small_graph_geo(; source=nothing, sink=nothing, inv_data=nothing)

    # Creation of the source and sink module as well as the arrays used for nodes and links
    if isnothing(source)
        source = RefSource(
                    "-src",
                    FixedProfile(50),
                    FixedProfile(10),
                    FixedProfile(5),
                    Dict(Power => 1),
                    Array{Data}([]),
                )
    end

    if isnothing(sink)
        sink = RefSink(
                    "-snk",
                    StrategicProfile([20, 25, 30, 35]),
                    Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
                    Dict(Power => 1),
                )
    end

    nodes = [GeoAvailability(1, products), GeoAvailability(2, products), source, sink]
    links = [Direct(31, nodes[3], nodes[1], Linear())
             Direct(24, nodes[2], nodes[4], Linear())]

    # Creation of the two areas and potential transmission lines
    areas = [RefArea(1, "Oslo", 10.751, 59.921, nodes[1]),
             RefArea(2, "Trondheim", 10.398, 63.4366, nodes[2])]


    if isnothing(inv_data)
        inv_data = Data[]
    else
        inv_data = [inv_data]
    end
    transmission_line = RefStatic(
        "transline",
        Power,
        FixedProfile(10),
        FixedProfile(0.1),
        FixedProfile(0.0),
        FixedProfile(0.0),
        1,
        inv_data,
    )

    transmissions = [Transmission(areas[1], areas[2], [transmission_line])]

    # Creation of the time structure and the used global data
    T = TwoLevel(4, 1, SimpleTimes(1, 1))
    modeltype = InvestmentModel(
                            Dict(CO2 => StrategicProfile([450, 400, 350, 300])),
                            Dict(CO2 => StrategicProfile([0, 0, 0, 0])),
                            CO2,
                            0.07
                        )

    # Creation of the case dictionary
    case = Dict(
                :nodes          => nodes,
                :links          => links,
                :products       => products,
                :areas          => areas,
                :transmission   => transmissions,
                :T              => T,
                )

    return case, modeltype
end

"""
    network_graph()

Creates a more complex case to test several potential errors
"""
function network_graph()
    # Define the different resources
    NG       = ResourceEmit("NG", 0.2)
    Coal     = ResourceCarrier("Coal", 0.35)
    Power    = ResourceCarrier("Power", 0.)
    CO2      = ResourceEmit("CO2",1.)
    products = [NG, Coal, Power, CO2]

    op_profile = OperationalProfile([20, 20, 20, 20, 25, 30, 35, 35, 40, 40, 40, 40, 40, 35, 35, 30, 25, 30, 35, 30, 25, 20, 20, 20])

    nodes = [
        GenAvailability(1, products),
        RefSink(
            2,
            op_profile,
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
            Dict(Power => 1),
        ),
        RefSource(
            3,
            FixedProfile(30),
            FixedProfile(30),
            FixedProfile(100),
            Dict(NG => 1),
            [
                StartInvData(
                    FixedProfile(1000), # capex [€/kW]
                    FixedProfile(200),  # max installed capacity [kW]
                    15,                 # initial capacity [kW]
                    ContinuousInvestment(FixedProfile(10), FixedProfile(200)), # investment mode
                    UnlimitedLife(),    # lifetime mode
                ),
            ],
        ),
        RefSource(
            4,
            FixedProfile(9),
            FixedProfile(9),
            FixedProfile(100),
            Dict(Coal => 1),
            [
                NoStartInvData(
                    FixedProfile(1000), # capex [€/kW]
                    FixedProfile(200),  # max installed capacity [kW]
                    ContinuousInvestment(FixedProfile(0), FixedProfile(200)), # investment mode
                    UnlimitedLife(),    # lifetime mode
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
                NoStartInvData(
                    FixedProfile(600),  # capex [€/kW]
                    FixedProfile(25),   # max installed capacity [kW]
                    ContinuousInvestment(FixedProfile(0), FixedProfile(25)), # investment mode
                    UnlimitedLife(),    # lifetime mode
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
            7,
            StorCapOpex(FixedProfile(0), FixedProfile(9.1), FixedProfile(100)),
            StorCap(FixedProfile(0)),
            CO2,
            Dict(CO2 => 1, Power => 0.02),
            Dict(CO2 => 1),
            [
                StorageInvData(
                    charge = NoStartInvData(
                        FixedProfile(0),
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
            8,
            FixedProfile(2),
            FixedProfile(0),
            FixedProfile(0),
            Dict(Coal => 2.5),
            Dict(Power => 1),
            [
                NoStartInvData(
                    FixedProfile(0),    # capex [€/kW]
                    FixedProfile(25),    # max installed capacity [kW]
                    ContinuousInvestment(FixedProfile(2), FixedProfile(2)), # investment mode
                    UnlimitedLife(),    # lifetime mode
                ),
                EmissionsEnergy(),
            ],
        ),
        RefStorage{AccumulatingEmissions}(
            9,
            StorCapOpex(FixedProfile(3), FixedProfile(0), FixedProfile(0)),
            StorCap(FixedProfile(5)),
            CO2,
            Dict(CO2 => 1, Power => 0.02),
            Dict(CO2 => 1),
            [
                StorageInvData(
                    charge = NoStartInvData(
                        FixedProfile(0),
                        FixedProfile(30),
                        ContinuousInvestment(FixedProfile(3), FixedProfile(3)),
                        UnlimitedLife(),
                    ),
                    level = NoStartInvData(
                        FixedProfile(0),
                        FixedProfile(50),
                        ContinuousInvestment(FixedProfile(5), FixedProfile(5)),
                        UnlimitedLife(),
                    )
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
                NoStartInvData(
                    FixedProfile(10000),        # capex [€/kW]
                    FixedProfile(10000),     # max installed capacity [kW]
                    ContinuousInvestment(FixedProfile(0), FixedProfile(10000)),  # investment mode
                    UnlimitedLife(),    # lifetime mode
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
