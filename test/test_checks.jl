# Set the global to true to suppress the error message
EMB.TEST_ENV = true

@testset "Test checks - InvestmentData" begin

    # Testing, that the checks for NoStartInvData and StartInvData are working
    # - EMB.check_node_data(n::EMB.Node, data::InvestmentData, 𝒯, modeltype::AbstractInvestmentModel)
    @testset "SingleInvData" begin

        function run_simple_graph(max_add; check_timeprofiles=true)
            investment_data_source = [
                SingleInvData(
                    FixedProfile(1000),     # capex [€/kW]
                    FixedProfile(30),       # max installed capacity [kW]
                    ContinuousInvestment(FixedProfile(0), max_add),   # investment mode
                ),
            ]
            inv_data = Dict(
                "investment_data" => investment_data_source,
                "profile"         => demand_profile,
            )
            case, modeltype = small_graph(;inv_data)

            return optimize(case, modeltype; check_timeprofiles)
        end
        demand_profile = FixedProfile(20)

        # Check that we receive an error if we provide two `InvestmentData`
        investment_data_source = [
            SingleInvData(
                FixedProfile(1000),     # capex [€/kW]
                FixedProfile(30),       # max installed capacity [kW]
                ContinuousInvestment(FixedProfile(0), FixedProfile(20)), # investment mode
            ),
            SingleInvData(
                FixedProfile(1000),     # capex [€/kW]
                FixedProfile(30),       # max installed capacity [kW]
                ContinuousInvestment(FixedProfile(0), FixedProfile(20)),   # investment mode
            ),
        ]
        inv_data = Dict(
            "investment_data" => investment_data_source,
            "profile"         => demand_profile,
        )
        case, modeltype = small_graph(;inv_data)
        @test_throws AssertionError optimize(case, modeltype)

        # Check that we receive an error if the profiles are wrong
        rprofile = RepresentativeProfile([FixedProfile(4)])
        scprofile = ScenarioProfile([FixedProfile(4)])
        oprofile = OperationalProfile(ones(4))

        max_add = oprofile
        @test_throws AssertionError run_simple_graph(max_add)
        max_add = scprofile
        @test_throws AssertionError run_simple_graph(max_add)
        max_add = rprofile
        @test_throws AssertionError run_simple_graph(max_add)
        max_add = StrategicProfile([4])
        @test_throws AssertionError run_simple_graph(max_add)

        max_add = StrategicProfile([oprofile, oprofile, oprofile, oprofile])
        @test_throws AssertionError run_simple_graph(max_add)
        max_add = StrategicProfile([scprofile, scprofile, scprofile, scprofile])
        @test_throws AssertionError run_simple_graph(max_add)
        max_add = StrategicProfile([rprofile, rprofile, rprofile, rprofile])
        @test_throws AssertionError run_simple_graph(max_add)

        max_add = StrategicProfile([4])
        msg = "Checking of the time profiles is deactivated:\n" *
        "Deactivating the checks for the time profiles is strongly discouraged. " *
        "While the model will still run, unexpected results can occur, as well as " *
        "inconsistent case data.\n\n" *
        "Deactivating the checks for the timeprofiles should only be considered, " *
        "when testing new components. In all other instances, it is recommended to " *
        "provide the correct timeprofiles using a preprocessing routine.\n\n" *
        "If timeprofiles are not checked, inconsistencies can occur."
        @test_logs (:warn, msg) run_simple_graph(max_add; check_timeprofiles=false)

        # Check that we receive an error if the capacity is an operational profile
        investment_data_source = [
            SingleInvData(
                FixedProfile(1000),     # capex [€/kW]
                FixedProfile(30),       # max installed capacity [kW]
                ContinuousInvestment(FixedProfile(0), FixedProfile(20)),   # investment mode
            ),
        ]
        source = RefSource(
            "-src",
            OperationalProfile(ones(4)),
            FixedProfile(10),
            FixedProfile(5),
            Dict(Power => 1),
            investment_data_source,
        )
        inv_data = Dict(
            "investment_data" => investment_data_source,
            "profile"         => demand_profile,
        )
        case, modeltype = small_graph(;source, inv_data)
        @test_throws AssertionError optimize(case, modeltype)

        # Check that we receive an error if the initial capacity is higher than the
        # allowed maximum installed
        investment_data_source = [
            SingleInvData(
                FixedProfile(1000),     # capex [€/kW]
                FixedProfile(0),        # max installed capacity [kW]
                ContinuousInvestment(FixedProfile(0), FixedProfile(20)),   # investment mode
            ),
        ]
        source = RefSource(
            "-src",
            FixedProfile(10),
            FixedProfile(10),
            FixedProfile(5),
            Dict(Power => 1),
            investment_data_source,
        )
        inv_data = Dict(
            "investment_data" => investment_data_source,
            "profile"         => demand_profile,
        )
        case, modeltype = small_graph(;source, inv_data)
        @test_throws AssertionError optimize(case, modeltype)
        investment_data_source = [
            StartInvData(
                FixedProfile(1000),     # capex [€/kW]
                FixedProfile(10),       # max installed capacity [kW]
                30,                     # initial capacity
                ContinuousInvestment(FixedProfile(0), FixedProfile(20)),   # investment mode
            ),
        ]
        inv_data = Dict(
            "investment_data" => investment_data_source,
            "profile"         => demand_profile,
        )
        case, modeltype = small_graph(;source, inv_data)
        @test_throws AssertionError optimize(case, modeltype)

        # Check that we receive an error if we provide a larger min_add than max_add
        investment_data_source = [
            SingleInvData(
                FixedProfile(1000),     # capex [€/kW]
                FixedProfile(10),       # max installed capacity [kW]
                ContinuousInvestment(FixedProfile(15), FixedProfile(10)),   # investment mode
            ),
        ]
        inv_data = Dict(
            "investment_data" => investment_data_source,
            "profile"         => demand_profile,
        )
        case, modeltype = small_graph(;inv_data)
        @test_throws AssertionError optimize(case, modeltype)
    end

    # Testing, that the checks for StorageInvData are working
    # - EMB.check_node_data(n::EMB.Storage, data::InvestmentData, 𝒯, modeltype::AbstractInvestmentModel)
    @testset "StorageInvData" begin

        function run_simple_graph(charge_max_add, level_max_add; check_timeprofiles=true)
            inv_data = [
                StorageInvData(
                    charge = NoStartInvData(
                        FixedProfile(20),
                        FixedProfile(30),
                        ContinuousInvestment(FixedProfile(5), charge_max_add),
                    ),
                    level = NoStartInvData(
                        FixedProfile(500),
                        FixedProfile(600),
                        ContinuousInvestment(FixedProfile(5), level_max_add),
                    )
                )
            ]
            case, modeltype = small_graph_stor(;inv_data)

            return optimize(case, modeltype; check_timeprofiles)
        end

        # Check that we receive an error if we provide the wrong `InvestmentData`
        inv_data = [
            SingleInvData(
                FixedProfile(1000),     # capex [€/kW]
                FixedProfile(30),       # max installed capacity [kW]
                ContinuousInvestment(FixedProfile(5), FixedProfile(20)),
            )
        ]
        case, modeltype = small_graph_stor(;inv_data)
        @test_throws AssertionError optimize(case, modeltype)

        # Check that we receive an error if we provide the wrong `InvestmentData`
        inv_data = [
            StorageInvData(
                charge = NoStartInvData(
                    FixedProfile(20),
                    FixedProfile(30),
                    ContinuousInvestment(FixedProfile(5), FixedProfile(20)),
                ),
                level = NoStartInvData(
                    FixedProfile(500),
                    FixedProfile(600),
                    ContinuousInvestment(FixedProfile(5), FixedProfile(600)),
                )
            ),
            StorageInvData(
                charge = NoStartInvData(
                    FixedProfile(20),
                    FixedProfile(30),
                    ContinuousInvestment(FixedProfile(5), FixedProfile(20)),
                ),
                level = NoStartInvData(
                    FixedProfile(500),
                    FixedProfile(600),
                    ContinuousInvestment(FixedProfile(5), FixedProfile(600)),
                )
            ),
        ]
        case, modeltype = small_graph_stor(;inv_data)
        @test_throws AssertionError optimize(case, modeltype)

        # Check that we receive an error if the profiles are wrong
        rprofile = RepresentativeProfile([FixedProfile(4)])
        scprofile = ScenarioProfile([FixedProfile(4)])
        oprofile = OperationalProfile(ones(4))

        level_max_add = FixedProfile(600)

        charge_max_add = oprofile
        @test_throws AssertionError run_simple_graph(charge_max_add, level_max_add)
        charge_max_add = scprofile
        @test_throws AssertionError run_simple_graph(charge_max_add, level_max_add)
        charge_max_add = rprofile
        @test_throws AssertionError run_simple_graph(charge_max_add, level_max_add)
        charge_max_add = StrategicProfile([4])
        @test_throws AssertionError run_simple_graph(charge_max_add, level_max_add)

        charge_max_add = StrategicProfile([oprofile, oprofile, oprofile, oprofile])
        @test_throws AssertionError run_simple_graph(charge_max_add, level_max_add)
        charge_max_add = StrategicProfile([scprofile, scprofile, scprofile, scprofile])
        @test_throws AssertionError run_simple_graph(charge_max_add, level_max_add)
        charge_max_add = StrategicProfile([rprofile, rprofile, rprofile, rprofile])
        @test_throws AssertionError run_simple_graph(charge_max_add, level_max_add)

        charge_max_add = FixedProfile(20)

        level_max_add = oprofile
        @test_throws AssertionError run_simple_graph(charge_max_add, level_max_add)
        level_max_add = scprofile
        @test_throws AssertionError run_simple_graph(charge_max_add, level_max_add)
        level_max_add = rprofile
        @test_throws AssertionError run_simple_graph(charge_max_add, level_max_add)
        level_max_add = StrategicProfile([6])
        @test_throws AssertionError run_simple_graph(charge_max_add, level_max_add)

        level_max_add = StrategicProfile([oprofile, oprofile, oprofile, oprofile])
        @test_throws AssertionError run_simple_graph(charge_max_add, level_max_add)
        level_max_add = StrategicProfile([scprofile, scprofile, scprofile, scprofile])
        @test_throws AssertionError run_simple_graph(charge_max_add, level_max_add)
        level_max_add = StrategicProfile([rprofile, rprofile, rprofile, rprofile])
        @test_throws AssertionError run_simple_graph(charge_max_add, level_max_add)

        level_max_add = StrategicProfile([6])
        msg = "Checking of the time profiles is deactivated:\n" *
        "Deactivating the checks for the time profiles is strongly discouraged. " *
        "While the model will still run, unexpected results can occur, as well as " *
        "inconsistent case data.\n\n" *
        "Deactivating the checks for the timeprofiles should only be considered, " *
        "when testing new components. In all other instances, it is recommended to " *
        "provide the correct timeprofiles using a preprocessing routine.\n\n" *
        "If timeprofiles are not checked, inconsistencies can occur."
        @test_logs (:warn, msg) run_simple_graph(charge_max_add, level_max_add; check_timeprofiles=false)


        # Check that we receive an error if the capacity is an operational profile
        rate_cap = OperationalProfile(ones(4))
        case, modeltype = small_graph_stor(;rate_cap)
        @test_throws AssertionError optimize(case, modeltype)
        stor_cap = OperationalProfile(ones(4))
        case, modeltype = small_graph_stor(;stor_cap)
        @test_throws AssertionError optimize(case, modeltype)

        # Check that we receive an error if the initial capacity is higher than the
        # allowed maximum installed
        rate_cap = FixedProfile(60)
        case, modeltype = small_graph_stor(;rate_cap)
        @test_throws AssertionError optimize(case, modeltype)
        inv_data = [
            StorageInvData(
                charge = StartInvData(
                    FixedProfile(20),
                    FixedProfile(30),
                    40,
                    ContinuousInvestment(FixedProfile(5), FixedProfile(20)),
                ),
                level = NoStartInvData(
                    FixedProfile(500),
                    FixedProfile(600),
                    ContinuousInvestment(FixedProfile(5), FixedProfile(600)),
                )
            )
        ]
        case, modeltype = small_graph_stor(;inv_data)
        @test_throws AssertionError optimize(case, modeltype)
        stor_cap = FixedProfile(700)
        case, modeltype = small_graph_stor(;stor_cap)
        @test_throws AssertionError optimize(case, modeltype)
        inv_data = [
            StorageInvData(
                charge = NoStartInvData(
                    FixedProfile(20),
                    FixedProfile(30),
                    ContinuousInvestment(FixedProfile(5), FixedProfile(20)),
                ),
                level = StartInvData(
                    FixedProfile(500),
                    FixedProfile(600),
                    700,
                    ContinuousInvestment(FixedProfile(5), FixedProfile(600)),
                )
            )
        ]
        case, modeltype = small_graph_stor(;inv_data)
        @test_throws AssertionError optimize(case, modeltype)

        # Check that we receive an error if we provide a larger min_add than max_add
        rate_min_add = 40
        case, modeltype = small_graph_stor(;rate_min_add)
        @test_throws AssertionError optimize(case, modeltype)
        stor_min_add = 700
        case, modeltype = small_graph_stor(;stor_min_add)
        @test_throws AssertionError optimize(case, modeltype)
    end
end

# Set the global again to false
EMB.TEST_ENV = false
