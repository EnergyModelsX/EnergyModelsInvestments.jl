# Set the global to true to suppress the error message
EMB.TEST_ENV = true

@testset "Test checks - InvestmentData" begin

    # Testing, that the checks for InvData are working
    # - EMB.check_node_data(n::EMB.Node, data::InvData, 𝒯, modeltype::AbstractInvestmentModel)
    @testset "InvData" begin

        function run_simple_graph(max_add)
            investment_data_source = [InvData(
                capex_cap       = FixedProfile(1000),       # capex [€/kW]
                cap_max_inst    = FixedProfile(30),         # max installed capacity [kW]
                cap_max_add     = max_add,                  # max_add [kW]
                cap_min_add     = FixedProfile(0),          # min_add [kW]
                inv_mode        = ContinuousInvestment()    # investment mode
            )]
            inv_data = Dict(
                "investment_data" => investment_data_source,
                "profile"         => demand_profile,
            )
            case, modeltype = small_graph(;inv_data)

            return optimize(case, modeltype)
        end


        demand_profile = FixedProfile(20)

        # Check that we receive an error if we provide two `InvestmentData`
        investment_data_source = [
            InvData(
                capex_cap       = FixedProfile(1000),       # capex [€/kW]
                cap_max_inst    = FixedProfile(30),         # max installed capacity [kW]
                cap_max_add     = FixedProfile(20),         # max_add [kW]
                cap_min_add     = FixedProfile(5),          # min_add [kW]
            ),
            InvData(
                capex_cap       = FixedProfile(1000),       # capex [€/kW]
                cap_max_inst    = FixedProfile(30),         # max installed capacity [kW]
                cap_max_add     = FixedProfile(20),         # max_add [kW]
                cap_min_add     = FixedProfile(5),          # min_add [kW]
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

        # Check that we receive an error if the capacity is an operational profile
        investment_data_source = [InvData(
            capex_cap       = FixedProfile(1000),       # capex [€/kW]
            cap_max_inst    = FixedProfile(10),          # max installed capacity [kW]
            cap_max_add     = FixedProfile(20),         # max_add [kW]
            cap_min_add     = FixedProfile(0),          # min_add [kW]
            inv_mode        = ContinuousInvestment()    # investment mode
        )]
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
        investment_data_source = [InvData(
            capex_cap       = FixedProfile(1000),       # capex [€/kW]
            cap_max_inst    = FixedProfile(0),          # max installed capacity [kW]
            cap_max_add     = FixedProfile(20),         # max_add [kW]
            cap_min_add     = FixedProfile(0),          # min_add [kW]
            inv_mode        = ContinuousInvestment()    # investment mode
        )]
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
        investment_data_source = [InvData(
            capex_cap       = FixedProfile(1000),       # capex [€/kW]
            cap_max_inst    = FixedProfile(0),          # max installed capacity [kW]
            cap_max_add     = FixedProfile(20),         # max_add [kW]
            cap_min_add     = FixedProfile(0),          # min_add [kW]
            inv_mode        = ContinuousInvestment(),    # investment mode
            cap_start       = 10,                       # Starting capacity
        )]
        inv_data = Dict(
            "investment_data" => investment_data_source,
            "profile"         => demand_profile,
        )
        case, modeltype = small_graph(;source, inv_data)
        @test_throws AssertionError optimize(case, modeltype)

        # Check that we receive an error if we provide a larger min_add than max_add
        max_add = FixedProfile(10)
        min_add = FixedProfile(15)
        investment_data_source = [InvData(
            capex_cap       = FixedProfile(1000),       # capex [€/kW]
            cap_max_inst    = FixedProfile(30),         # max installed capacity [kW]
            cap_max_add     = max_add,                  # max_add [kW]
            cap_min_add     = min_add,                  # min_add [kW]
            inv_mode        = ContinuousInvestment()    # investment mode
        )]
        inv_data = Dict(
            "investment_data" => investment_data_source,
            "profile"         => demand_profile,
        )
        case, modeltype = small_graph(;inv_data)
        @test_throws AssertionError optimize(case, modeltype)
    end

    # Testing, that the checks for InvData are working
    # - EMB.check_node_data(n::EMB.Storage, data::InvestmentData, 𝒯, modeltype::AbstractInvestmentModel)
    @testset "InvDataStorage" begin

        function run_simple_graph(rate_max_add, stor_max_add)
            inv_data = [InvDataStorage(
                capex_rate = FixedProfile(20),
                rate_max_inst = FixedProfile(30),
                rate_max_add = rate_max_add,
                rate_min_add = FixedProfile(5),
                capex_stor = FixedProfile(500),
                stor_max_inst = FixedProfile(600),
                stor_max_add = stor_max_add,
                stor_min_add = FixedProfile(5),
                inv_mode = ContinuousInvestment(),
            )]
            case, modeltype = small_graph_stor(;inv_data)

            return optimize(case, modeltype)
        end

        # Check that we receive an error if we provide the wrong `InvestmentData`
        inv_data = [
            InvData(
                capex_cap       = FixedProfile(1000),       # capex [€/kW]
                cap_max_inst    = FixedProfile(30),         # max installed capacity [kW]
                cap_max_add     = FixedProfile(20),         # max_add [kW]
                cap_min_add     = FixedProfile(5),          # min_add [kW]
            ),
        ]
        case, modeltype = small_graph_stor(;inv_data)
        @test_throws AssertionError optimize(case, modeltype)

        # Check that we receive an error if we provide the wrong `InvestmentData`
        inv_data = [
            InvDataStorage(
                capex_rate = FixedProfile(20),
                rate_max_inst = FixedProfile(30),
                rate_max_add = FixedProfile(20),
                rate_min_add = FixedProfile(5),
                capex_stor = FixedProfile(500),
                stor_max_inst = FixedProfile(600),
                stor_max_add = FixedProfile(600),
                stor_min_add = FixedProfile(5),
                inv_mode = ContinuousInvestment(),
            ),
            InvDataStorage(
                capex_rate = FixedProfile(20),
                rate_max_inst = FixedProfile(30),
                rate_max_add = FixedProfile(20),
                rate_min_add = FixedProfile(5),
                capex_stor = FixedProfile(500),
                stor_max_inst = FixedProfile(600),
                stor_max_add = FixedProfile(600),
                stor_min_add = FixedProfile(5),
                inv_mode = ContinuousInvestment(),
            ),
        ]
        case, modeltype = small_graph_stor(;inv_data)
        @test_throws AssertionError optimize(case, modeltype)

        # Check that we receive an error if the profiles are wrong
        rprofile = RepresentativeProfile([FixedProfile(4)])
        scprofile = ScenarioProfile([FixedProfile(4)])
        oprofile = OperationalProfile(ones(4))

        stor_max_add = FixedProfile(600)

        rate_max_add = oprofile
        @test_throws AssertionError run_simple_graph(rate_max_add, stor_max_add)
        rate_max_add = scprofile
        @test_throws AssertionError run_simple_graph(rate_max_add, stor_max_add)
        rate_max_add = rprofile
        @test_throws AssertionError run_simple_graph(rate_max_add, stor_max_add)
        rate_max_add = StrategicProfile([4])
        @test_throws AssertionError run_simple_graph(rate_max_add, stor_max_add)

        rate_max_add = StrategicProfile([oprofile, oprofile, oprofile, oprofile])
        @test_throws AssertionError run_simple_graph(rate_max_add, stor_max_add)
        rate_max_add = StrategicProfile([scprofile, scprofile, scprofile, scprofile])
        @test_throws AssertionError run_simple_graph(rate_max_add, stor_max_add)
        rate_max_add = StrategicProfile([rprofile, rprofile, rprofile, rprofile])
        @test_throws AssertionError run_simple_graph(rate_max_add, stor_max_add)

        rate_max_add = FixedProfile(20)

        stor_max_add = oprofile
        @test_throws AssertionError run_simple_graph(rate_max_add, stor_max_add)
        stor_max_add = scprofile
        @test_throws AssertionError run_simple_graph(rate_max_add, stor_max_add)
        stor_max_add = rprofile
        @test_throws AssertionError run_simple_graph(rate_max_add, stor_max_add)
        stor_max_add = StrategicProfile([4])
        @test_throws AssertionError run_simple_graph(rate_max_add, stor_max_add)

        stor_max_add = StrategicProfile([oprofile, oprofile, oprofile, oprofile])
        @test_throws AssertionError run_simple_graph(rate_max_add, stor_max_add)
        stor_max_add = StrategicProfile([scprofile, scprofile, scprofile, scprofile])
        @test_throws AssertionError run_simple_graph(rate_max_add, stor_max_add)
        stor_max_add = StrategicProfile([rprofile, rprofile, rprofile, rprofile])
        @test_throws AssertionError run_simple_graph(rate_max_add, stor_max_add)

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
        inv_data = [InvDataStorage(
            capex_rate = FixedProfile(20),
            rate_max_inst = FixedProfile(30),
            rate_max_add = FixedProfile(20),
            rate_min_add = FixedProfile(5),
            rate_start = 40,
            capex_stor = FixedProfile(500),
            stor_max_inst = FixedProfile(600),
            stor_max_add = FixedProfile(600),
            stor_min_add = FixedProfile(5),
            inv_mode = ContinuousInvestment(),
        )]
        case, modeltype = small_graph_stor(;inv_data)
        @test_throws AssertionError optimize(case, modeltype)
        stor_cap = FixedProfile(700)
        case, modeltype = small_graph_stor(;stor_cap)
        @test_throws AssertionError optimize(case, modeltype)
        inv_data = [InvDataStorage(
            capex_rate = FixedProfile(20),
            rate_max_inst = FixedProfile(30),
            rate_max_add = FixedProfile(20),
            rate_min_add = FixedProfile(5),
            capex_stor = FixedProfile(500),
            stor_max_inst = FixedProfile(600),
            stor_max_add = FixedProfile(600),
            stor_min_add = FixedProfile(5),
            inv_mode = ContinuousInvestment(),
            stor_start = 40,
        )]
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
