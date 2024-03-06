
@testset "Investment example - simple network" begin

    # Create simple model
    case, modeltype = network_graph()
    m               = optimize(case, modeltype)

    # Test for the total number of variables
    # (-576 compared to 0.4.x as only defined for technologies with EmissionData)
    # (+192 compared to 0.4.x as increase in storage variables)
    @test size(all_variables(m))[1] == 10112

    # Test results
    general_tests(m)
    @test round(objective_value(m)) ≈ -303348

    CH4 = case[:products][1]
    CO2 = case[:products][4]
    𝒯    = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    emissions_CO2 = [value.(m[:emissions_strategic])[t_inv, CO2] for t_inv ∈ 𝒯ᴵⁿᵛ]
    @test emissions_CO2 <= [450, 400, 350, 300]
end

@testset "Test InvData" begin
    @testset "ContinuousInvestment" begin

        # Creation and solving of the model
        case, modeltype = small_graph()
        m               = optimize(case, modeltype)
        general_tests(m)

        # Extraction of required data
        source = case[:nodes][1]
        sink   = case[:nodes][2]
        𝒯    = case[:T]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        inv_data = EMI.investment_data(source)

        @testset "cap_inst" begin
            # Test that cap_inst is less than node.data.cap_max_inst at all times.
            @test sum(value.(m[:cap_inst][source, t]) <=
                        EMI.max_installed(source, t) for t ∈ 𝒯) == length(𝒯)

            for t_inv in 𝒯ᴵⁿᵛ, t ∈ t_inv
                # Test the initial installed capacity is correct set.
                @test value.(m[:cap_inst][source, t]) ==
                            capacity(source, t) + value.(m[:cap_add][source, t_inv])
                break
            end

            # Test that cap_inst is larger or equal to demand profile in sink and deficit
            @test sum(value.(m[:cap_inst][source, t])+value.(m[:sink_deficit][sink, t])
                        ≥ capacity(sink, t) for t ∈ 𝒯) == length(𝒯)
        end
        @test sum(value.(m[:cap_add][source, t_inv]) ≥
                    EMI.min_add(source, t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)

    end

    @testset "SemiContinuousInvestment" begin

        inv_data = Dict(
            "investment_data" => [InvData(
                capex_cap       = FixedProfile(1000),       # capex [€/kW]
                cap_max_inst    = FixedProfile(30),         # max installed capacity [kW]
                cap_max_add     = FixedProfile(30),         # max_add [kW]
                cap_min_add     = FixedProfile(10),         # min_add [kW]
                cap_start       = 0,                        # Starting capacity
                inv_mode        = SemiContinuousInvestment()   # investment mode
            )],
            "profile"         => StrategicProfile([0, 20, 25, 30]),
        )

        # Creation and solving of the model
        case, modeltype = small_graph(;inv_data)
        m               = optimize(case, modeltype)
        general_tests(m)

        # Extraction of required data
        source = case[:nodes][1]
        sink   = case[:nodes][2]
        𝒯    = case[:T]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        inv_data = EMI.investment_data(source)

        @testset "cap_inst" begin
            # Test that cap_inst is less than node.data.cap_max_inst at all times.
            @test sum(value.(m[:cap_inst][source, t]) <=
                        EMI.max_installed(source, t) for t ∈ 𝒯) == length(𝒯)

            for t_inv in 𝒯ᴵⁿᵛ, t ∈ t_inv
                # Test the initial installed capacity is correct set.
                @test value.(m[:cap_inst][source, t]) ==
                            capacity(source, t) + value.(m[:cap_add][source, t_inv])
                break
            end

            # Test that cap_inst is larger or equal to demand profile in sink and deficit
            @test sum(value.(m[:cap_inst][source, t])+value.(m[:sink_deficit][sink, t])
                        ≥ capacity(sink, t) for t ∈ 𝒯) == length(𝒯)
        end

        # Test that the semi continuous bound is always followed
        @test sum(value.(m[:cap_add][source, t_inv]) ≥
                    EMI.min_add(source, t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ) +
                sum(value.(m[:cap_add][source, t_inv]) ≈
                   0 for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
        @test sum(value.(m[:cap_add][source, t_inv]) ≥
                    EMI.min_add(source, t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ) > 0
        @test sum(value.(m[:cap_add][source, t_inv]) ≈0 for t_inv ∈ 𝒯ᴵⁿᵛ) > 0

        # Test that the variable cap_invest_b is a binary
        @test sum(is_binary.(m[:cap_invest_b])) == length(𝒯ᴵⁿᵛ)
    end

    @testset "DiscreteInvestment" begin

        # Variation in the test structure
        investment_data_source = [InvData(
            capex_cap       = FixedProfile(1000),   # capex [€/kW]
            cap_max_inst    = FixedProfile(30),     # max installed capacity [kW]
            cap_max_add     = FixedProfile(10),     # max_add [kW]
            cap_min_add     = FixedProfile(5),      # min_add [kW]
            cap_start       = 0,                    # Starting capacity
            inv_mode        = DiscreteInvestment(),    # investment mode
            cap_increment   = FixedProfile(8)    # investment mode
        )]
        inv_data = Dict(
            "investment_data" => investment_data_source,
            "profile"         => StrategicProfile([0, 20, 20, 0]),
        )

        # Creation and solving of the model
        case, modeltype = small_graph(;inv_data)
        m               = optimize(case, modeltype)
        general_tests(m)

        # Extraction of required data
        source = case[:nodes][1]
        sink   = case[:nodes][2]
        𝒯    = case[:T]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        # Test the integer variables
        @test sum(value.(m[:cap_invest_b][source, t_inv]) > 0 for t_inv ∈ 𝒯ᴵⁿᵛ) +
                sum(value.(m[:cap_invest_b][source, t_inv]) ≈ 0 for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
        @test sum(is_integer.(m[:cap_invest_b])) == length(𝒯ᴵⁿᵛ)

        # Test that the variable cap_invest_b is 3 exactly once
        @test sum(value.(m[:cap_invest_b][source, t_inv]) ≈ 3 for t_inv ∈ 𝒯ᴵⁿᵛ) == 1
    end

    @testset "FixedInvestment" begin

        # Variation in the test structure
        inv_data = Dict(
            "investment_data" => [InvData(
                capex_cap       = FixedProfile(1000),   # capex [€/kW]
                cap_max_inst    = FixedProfile(30),     # max installed capacity [kW]
                cap_max_add     = FixedProfile(30),     # max_add [kW]
                cap_min_add     = FixedProfile(0),      # min_add [kW]
                cap_start       = 0,                    # Starting capacity
                inv_mode        = FixedInvestment()     # investment mode
            )],
            "profile"         => StrategicProfile([0, 20, 25, 30]),
        )
        source = RefSource(
            "-src",
            StrategicProfile([0, 20, 25, 30]),
            FixedProfile(10),
            FixedProfile(5),
            Dict(Power => 1),
            inv_data["investment_data"],
        )

        # Creation and solving of the model
        case, modeltype = small_graph(;source, inv_data)
        m               = optimize(case, modeltype)

        # Extraction of required data
        source = case[:nodes][1]
        sink   = case[:nodes][2]
        𝒯ᴵⁿᵛ = strategic_periods(case[:T])
        inv_profile = StrategicProfile([0, 20, 5, 5])

        # Test that the investments are happening based on the specified profile
        @test sum(
            value.(m[:cap_add][source, t_inv]) ≈ inv_profile[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ
            ) == length(𝒯ᴵⁿᵛ)

        # Test that the variable `cap_invest_b` is fixed
        @test sum(is_fixed.(m[:cap_invest_b])) == length(𝒯ᴵⁿᵛ)
    end

    @testset "Continuous fixed manually" begin

        # Variation in the test structure
        inv_data = Dict(
            "investment_data" => [InvData(
                capex_cap       = FixedProfile(1000),       # capex [€/kW]
                cap_max_inst    = FixedProfile(30),         # max installed capacity [kW]
                cap_max_add     = StrategicProfile([0, 30, 0, 0]),  # max_add [kW]
                cap_min_add     = StrategicProfile([0, 5, 0, 0]),   # min_add [kW]
                cap_start       = 0,                        # Starting capacity
                inv_mode        = ContinuousInvestment()   # investment mode
            )],
            "profile"         => StrategicProfile([0, 20, 25, 30])
        )

        # Creation and solving of the model
        case, modeltype = small_graph(;inv_data)
        m               = optimize(case, modeltype)
        general_tests(m)

        # Extraction of required data
        source = case[:nodes][1]
        sink   = case[:nodes][2]
        𝒯    = case[:T]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        # Test that the investments is happening in one strategic period
        @test sum(value.(m[:cap_add][source, t_inv]) > 0 for t_inv ∈ 𝒯ᴵⁿᵛ) == 1
    end
end

# @testset "Test InvDataStorage" begin
#     @testset "ContinuousInvestment" begin

#         # Creation and solving of the model
#         case, modeltype = small_graph_stor()
#         m               = optimize(case, modeltype)

#         # Extraction of required data
#         source = case[:nodes][1]
#         stor   = case[:nodes][2]
#         sink   = case[:nodes][3]
#         𝒯    = case[:T]
#         𝒯ᴵⁿᵛ = strategic_periods(𝒯)
#         inv_data = EMI.investment_data(stor)

#         # General tests for installed capacity
#         general_tests_stor(m, stor, 𝒯, 𝒯ᴵⁿᵛ)

#         # Test the bounds for minimum and maximum added capacity are not violated
#         @testset "Installation bounds" begin
#             @test sum(value.(m[:stor_rate_add][stor, t_inv]) ≥
#                         EMI.min_add(stor, t_inv).rate for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
#             @test sum(value.(m[:stor_cap_add][stor, t_inv]) ≥
#                         EMI.min_add(stor, t_inv).level for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
#             @test sum(value.(m[:stor_rate_add][stor, t_inv]) ≤
#                         EMI.max_add(stor, t_inv).rate for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
#             @test sum(value.(m[:stor_cap_add][stor, t_inv]) ≤
#                         EMI.max_add(stor, t_inv).level for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
#         end
#     end

#     @testset "SemiContinuousInvestment" begin

#         inv_data = [InvDataStorage(
#             capex_rate = FixedProfile(20),
#             rate_max_inst = FixedProfile(30),
#             rate_max_add = FixedProfile(30),
#             rate_min_add = FixedProfile(15),
#             capex_stor = FixedProfile(500),
#             stor_max_inst = FixedProfile(600),
#             stor_max_add = FixedProfile(600),
#             stor_min_add = FixedProfile(150),
#             inv_mode = SemiContinuousInvestment(),
#         )]

#         # Creation and solving of the model
#         case, modeltype = small_graph_stor(;inv_data)
#         m               = optimize(case, modeltype)

#         # Extraction of required data
#         source = case[:nodes][1]
#         stor   = case[:nodes][2]
#         sink   = case[:nodes][3]
#         𝒯    = case[:T]
#         𝒯ᴵⁿᵛ = strategic_periods(𝒯)
#         inv_data = EMI.investment_data(stor)

#         # General tests for installed capacity
#         general_tests_stor(m, stor, 𝒯, 𝒯ᴵⁿᵛ)

#         # Test the bounds for minimum and maximum added capacity are not violated
#         @testset "Installation bounds" begin
#             @test sum(value.(m[:stor_rate_add][stor, t_inv]) ≥
#                         EMI.min_add(stor, t_inv).rate for t_inv ∈ 𝒯ᴵⁿᵛ) +
#                     sum(value.(m[:stor_rate_add][stor, t_inv]) ≈
#                        0 for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
#             @test sum(value.(m[:stor_cap_add][stor, t_inv]) ≥
#                         EMI.min_add(stor, t_inv).level for t_inv ∈ 𝒯ᴵⁿᵛ) +
#                     sum(value.(m[:stor_cap_add][stor, t_inv]) ≈
#                         0 for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
#         end

#         # Test that investments are happening at least once
#         @test sum(value.(m[:stor_rate_invest_b][stor, t_inv]) ≈ 1 for t_inv ∈ 𝒯ᴵⁿᵛ) > 0
#         @test sum(value.(m[:stor_cap_invest_b][stor, t_inv]) ≈ 1 for t_inv ∈ 𝒯ᴵⁿᵛ) > 0

#         # Test that the variable stor_rate_invest_b and stor_cap_invest_b are binaries
#         @test sum(is_binary.(m[:stor_rate_invest_b])) == length(𝒯ᴵⁿᵛ)
#         @test sum(is_binary.(m[:stor_cap_invest_b])) == length(𝒯ᴵⁿᵛ)
#     end

#     @testset "DiscreteInvestment" begin

#         # Variation in the test structure
#         inv_data = [InvDataStorage(
#             capex_rate = FixedProfile(20),
#             rate_max_inst = FixedProfile(30),
#             rate_max_add = FixedProfile(30),
#             rate_min_add = FixedProfile(15),
#             capex_stor = FixedProfile(500),
#             stor_max_inst = FixedProfile(600),
#             stor_max_add = FixedProfile(600),
#             stor_min_add = FixedProfile(150),
#             inv_mode = DiscreteInvestment(),
#             rate_increment = FixedProfile(5),
#             stor_increment = FixedProfile(150),
#         )]

#         # Creation and solving of the model
#         case, modeltype = small_graph_stor(;inv_data)
#         m               = optimize(case, modeltype)

#         # Extraction of required data
#         source = case[:nodes][1]
#         stor   = case[:nodes][2]
#         sink   = case[:nodes][3]
#         𝒯    = case[:T]
#         𝒯ᴵⁿᵛ = strategic_periods(𝒯)
#         inv_data = EMI.investment_data(stor)

#         # General tests for installed capacity
#         general_tests_stor(m, stor, 𝒯, 𝒯ᴵⁿᵛ)

#         # Test the bounds for minimum and maximum added capacity are not violated
#         @testset "Installation bounds" begin
#             @test sum(value.(m[:stor_rate_add][stor, t_inv]) ≥
#                         EMI.min_add(stor, t_inv).rate for t_inv ∈ 𝒯ᴵⁿᵛ) +
#                     sum(value.(m[:stor_rate_add][stor, t_inv]) ≈
#                        0 for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
#             @test sum(value.(m[:stor_cap_add][stor, t_inv]) ≥
#                         EMI.min_add(stor, t_inv).level for t_inv ∈ 𝒯ᴵⁿᵛ) +
#                     sum(value.(m[:stor_cap_add][stor, t_inv]) ≈
#                         0 for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
#         end

#         # Test that investments are happening at least once
#         @test sum(value.(m[:stor_rate_invest_b][stor, t_inv]) ≥ 1 for t_inv ∈ 𝒯ᴵⁿᵛ) > 0
#         @test sum(value.(m[:stor_cap_invest_b][stor, t_inv]) ≥ 1 for t_inv ∈ 𝒯ᴵⁿᵛ) > 0

#         # Test that the variable stor_rate_invest_b and stor_cap_invest_b are binaries
#         @test sum(is_integer.(m[:stor_rate_invest_b])) == length(𝒯ᴵⁿᵛ)
#         @test sum(is_integer.(m[:stor_cap_invest_b])) == length(𝒯ᴵⁿᵛ)

#         # Test that the variable cap_invest_b is 3 exactly once
#         @test sum(
#             value.(m[:stor_rate_invest_b][stor, t_inv]) ≈ 3 for t_inv ∈ 𝒯ᴵⁿᵛ,
#             atol ∈ TEST_ATOL) == 1
#         @test sum(
#             value.(m[:stor_cap_invest_b][stor, t_inv]) ≈ 1 for t_inv ∈ 𝒯ᴵⁿᵛ,
#             atol ∈ TEST_ATOL) == 1
#     end

#     @testset "FixedInvestment" begin

#         # Variation in the test structure
#         inv_data = [InvDataStorage(
#             capex_rate = FixedProfile(20),
#             rate_max_inst = FixedProfile(30),
#             rate_max_add = FixedProfile(30),
#             rate_min_add = FixedProfile(15),
#             rate_start = 0,
#             capex_stor = FixedProfile(500),
#             stor_max_inst = FixedProfile(600),
#             stor_max_add = FixedProfile(600),
#             stor_min_add = FixedProfile(150),
#             stor_start = 0,
#             inv_mode = FixedInvestment(),
#         )]
#         rate_cap = StrategicProfile([15, 20])
#         stor_cap = StrategicProfile([150, 200])

#         # Creation and solving of the model
#         case, modeltype = small_graph_stor(;inv_data, rate_cap, stor_cap)
#         m               = optimize(case, modeltype)

#         # Extraction of required data
#         source = case[:nodes][1]
#         stor   = case[:nodes][2]
#         sink   = case[:nodes][3]
#         𝒯    = case[:T]
#         𝒯ᴵⁿᵛ = strategic_periods(𝒯)
#         inv_data = EMI.investment_data(stor)

#         # General tests for installed capacity
#         general_tests_stor(m, stor, 𝒯, 𝒯ᴵⁿᵛ)

#         inv_profile_rate = StrategicProfile([15, 5, 0, 0])
#         inv_profile_stor = StrategicProfile([150, 50, 0, 0])

#         # Test that the investments are happening based on the specified profile
#         @test sum(
#             value.(m[:stor_rate_add][stor, t_inv]) ≈ inv_profile_rate[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ
#             ) == length(𝒯ᴵⁿᵛ)
#         @test sum(
#             value.(m[:stor_cap_add][stor, t_inv]) ≈ inv_profile_stor[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ
#             ) == length(𝒯ᴵⁿᵛ)

#         # Test that the variables `stor_cap_invest_b` and `stor_rate_invest_b` are fixed
#         @test sum(is_fixed.(m[:stor_cap_invest_b])) == length(𝒯ᴵⁿᵛ)
#         @test sum(is_fixed.(m[:stor_rate_invest_b])) == length(𝒯ᴵⁿᵛ)
#     end
# end
