@testset "Test investments" begin

    @testset "Investment example - simple network" begin

        # Create simple model
        case, modeltype = network_graph()
        m               = optimize(case, modeltype)

        # Test for the total number of variables
        # (-576 compared to 0.4.x as only defined for technologies with EmissionData)
        # (+192 compared to 0.4.x as increase in storage variables)
        @test size(all_variables(m))[1] == 10112

        # Test results (new solution -303348.0, to be checked where the difference comes from)
        # Potentially changes in fixed OPEX for RefStorage (from capacity to rate)
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test round(objective_value(m)) ≈ -303348

        CH4 = case[:products][1]
        CO2 = case[:products][4]
        𝒯    = case[:T]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        emissions_CO2 = [value.(m[:emissions_strategic])[t_inv, CO2] for t_inv ∈ 𝒯ᴵⁿᵛ]
        @test emissions_CO2 <= [450, 400, 350, 300]
    end

    @testset "Investment example - small_graph Continuous" begin

        # Creation and solving of the model
        case, modeltype = small_graph()
        m               = optimize(case, modeltype)

        # Extraction of required data
        source = case[:nodes][2]
        sink   = case[:nodes][3]
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
                        >= capacity(sink, t) for t ∈ 𝒯) == length(𝒯)
        end
        @test sum(value.(m[:cap_add][source, t_inv]) >=
                    EMI.min_add(source, t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)

    end

    @testset "Investment example - small_graph Discrete" begin

        # Variation in the test structure
        investment_data_source = InvData(
            capex_cap       = FixedProfile(1000),   # capex [€/kW]
            cap_max_inst    = FixedProfile(30),     # max installed capacity [kW]
            cap_max_add     = FixedProfile(20),     # max_add [kW]
            cap_min_add     = FixedProfile(5),      # min_add [kW]
            cap_start       = 0,                    # Starting capacity
            inv_mode        = BinaryInvestment()    # investment mode
        )
        inv_data = Dict(
            "investment_data" => investment_data_source,
            "profile"         => StrategicProfile([0, 20, 20, 0]),
        )
        source = RefSource(
            "-src",
            FixedProfile(20),
            FixedProfile(10),
            FixedProfile(5),
            Dict(Power => 1),
            [investment_data_source],
        )

        # Creation and solving of the model
        case, modeltype = small_graph(;source, inv_data)
        m               = optimize(case, modeltype)

        # Extraction of required data
        source = case[:nodes][2]
        sink   = case[:nodes][3]
        𝒯    = case[:T]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        # Test the binary variables
        @test sum(value.(m[:cap_invest_b][source, t_inv]) ≈ 1 for t_inv ∈ 𝒯ᴵⁿᵛ) +
                sum(value.(m[:cap_invest_b][source, t_inv]) ≈ 0 for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
        @test sum(value.(m[:cap_inst][source, t]) <= capacity(source, t) for t ∈ 𝒯) == length(𝒯)

        # Test that the model invests
        @test sum(value.(m[:cap_invest_b][source, t_inv]) ≈ 1 for t_inv ∈ 𝒯ᴵⁿᵛ) > 0
    end

    @testset "Investment example - small_graph ContinuousFixed" begin

        # Variation in the test structure
        T = TwoLevel(4, 10, SimpleTimes(4, 1))
        inv_data = Dict(
            "investment_data" => InvData(
                capex_cap       = FixedProfile(1000),       # capex [€/kW]
                cap_max_inst    = FixedProfile(30),         # max installed capacity [kW]
                cap_max_add     = StrategicProfile([0, 30, 0, 0]), # max_add [kW]
                cap_min_add     = FixedProfile(0),          # min_add [kW]
                cap_start       = 0,                        # Starting capacity
                inv_mode        = ContinuousInvestment()   # investment mode
            ),
            "profile"         => StrategicProfile([0, 20, 25, 30]),
        )

        # Creation and solving of the model
        case, modeltype = small_graph(;inv_data, T)
        m               = optimize(case, modeltype)

        # Extraction of required data
        source = case[:nodes][2]
        sink   = case[:nodes][3]
        𝒯ᴵⁿᵛ = strategic_periods(T)

        # Test that the investment is only happening in one strategic period
        @test sum(value.(m[:cap_add][source, t_inv]) > 0 for t_inv ∈ 𝒯ᴵⁿᵛ) == 1
    end

    @testset "Investment example - small_graph Continuous fixed manually" begin

        # Variation in the test structure
        inv_data = Dict(
            "investment_data" => InvData(
                capex_cap       = FixedProfile(1000),       # capex [€/kW]
                cap_max_inst    = FixedProfile(30),         # max installed capacity [kW]
                cap_max_add     = StrategicProfile([0, 30, 0, 0]),  # max_add [kW]
                cap_min_add     = StrategicProfile([0, 5, 0, 0]),   # min_add [kW]
                cap_start       = 0,                        # Starting capacity
                inv_mode        = ContinuousInvestment()   # investment mode
            ),
            "profile"         => StrategicProfile([0, 20, 25, 30])
        )

        # Creation and solving of the model
        case, modeltype = small_graph(;inv_data)
        m                = optimize(case, modeltype)

        # Extraction of required data
        source = case[:nodes][2]
        sink   = case[:nodes][3]
        𝒯    = case[:T]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        # Test that the investment is only happening in one strategic period
        @test sum(value.(m[:cap_add][source, t_inv]) > 0 for t_inv ∈ 𝒯ᴵⁿᵛ) == 1
    end
end
