# Definition of the individual resources used in the simple system
CO2     = ResourceEmit("CO2", 1.)
Power   = ResourceCarrier("Power", 0.)
products = [Power, CO2]


"""
    optimize(cases)

Optimize the `case`.
"""
function optimize(case, modeltype)
    m = EMG.create_model(case, modeltype)
    set_optimizer(m, OPTIMIZER)
    optimize!(m)
    return m
end

# Test set for analysing the proper behaviour when no investment was included
@testset "Unidirectional transmission without investments" begin

    # Creation and run of the optimization problem
    case, modeltype = small_graph_geo()
    m               = optimize(case, modeltype)

    general_tests(m)

    # Extraction of required data
    𝒯    = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sink = case[:nodes][4]
    tr_osl_trd  = case[:transmission][1]
    tm  = modes(tr_osl_trd)[1]

    # Test identifying that the proper deficit is calculated
    @test sum(value.(m[:sink_deficit][sink, t])
                        ≈ capacity(sink, t) - capacity(tm, t) for t ∈ 𝒯) == length(𝒯)

    # Test showing that no investment variables are created
    @test size(m[:trans_cap_invest_b])[1] == 0
    @test size(m[:trans_cap_remove_b])[1] == 0
    @test size(m[:trans_cap_current])[1] == 0
    @test size(m[:trans_cap_add])[1] == 0
    @test size(m[:trans_cap_rem])[1] == 0

end

# Test set for continuous investments
@testset "Unidirectional transmission with ContinuousInvestment" begin

    # Creation and run of the optimization problem
    inv_data = [TransInvData(
                capex_trans     = FixedProfile(10),     # capex [€/kW]
                trans_max_inst  = FixedProfile(250),    # max installed capacity [kW]
                trans_max_add   = FixedProfile(30),     # max_add [kW]
                trans_min_add   = FixedProfile(0),      # min_add [kW]
                inv_mode        = ContinuousInvestment(),
                trans_increment = FixedProfile(10),
                trans_start     = 0,
            )]

    case, modeltype = small_graph_geo(;inv_data)
    m               = optimize(case, modeltype)

    general_tests(m)

    # Extraction of required data
    𝒯    = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sink = case[:nodes][4]
    tr_osl_trd  = case[:transmission][1]
    tm  = modes(tr_osl_trd)[1]

    # Test identifying that the there is no deficit
    @test sum(value.(m[:sink_deficit][sink, t])  == 0 for t ∈ 𝒯) == length(𝒯)

    # Test showing that the investments are as expected
    for (t_inv_prev, t_inv) ∈ withprev(𝒯ᴵⁿᵛ)
        if isnothing(t_inv_prev)
            @testset "First investment period" begin
                for t ∈ t_inv
                    @test (value.(m[:trans_cap_add][tm, t_inv])
                                    ≈ capacity(sink, t)-inv_data[1].trans_start)
                end
            end
        else
            @testset "Subsequent investment periods" begin
                for t ∈ t_inv
                    @test (value.(m[:trans_cap_add][tm, t_inv])
                            ≈ capacity(sink, t)-value.(m[:trans_cap_current][tm, t_inv_prev]))
                end
            end
        end
    end

end

# Test set for semicontinuous investments
@testset "Unidirectional transmission with SemiContinuousInvestment" begin

    # Creation and run of the optimization problem
    inv_data = [EMI.TransInvData(
        capex_trans     = FixedProfile(10),     # capex [€/kW]
        trans_max_inst  = FixedProfile(250),    # max installed capacity [kW]
        trans_max_add   = FixedProfile(30),     # max_add [kW]
        trans_min_add   = FixedProfile(10),     # min_add [kW]
        inv_mode        = SemiContinuousInvestment(),
        trans_increment = FixedProfile(10),
        trans_start     = 0,
    )]

    case, modeltype = small_graph_geo(;inv_data)
    m               = optimize(case, modeltype)

    general_tests(m)

    # Extraction of required data
    𝒯    = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sink = case[:nodes][4]
    tr_osl_trd  = case[:transmission][1]
    tm  = modes(tr_osl_trd)[1]

    # Test identifying that the there is no deficit
    @test sum(value.(m[:sink_deficit][sink, t])  == 0 for t ∈ 𝒯) == length(𝒯)

    # Test showing that the investments are as expected
    for (t_inv_prev, t_inv) ∈ withprev(𝒯ᴵⁿᵛ)
        @testset "Investment period $(t_inv.sp)" begin
            @testset "Invested capacity" begin
                if isnothing(t_inv_prev)
                    for t ∈ t_inv
                        @test (value.(m[:trans_cap_add][tm, t_inv])
                                        >= max(capacity(sink, t) - inv_data[1].trans_start,
                                            EMI.min_add(tm, t) * value.(m[:trans_cap_invest_b][tm, t_inv])))
                    end
                else
                    for t ∈ t_inv
                        @test (value.(m[:trans_cap_add][tm, t_inv])
                                        ⪆ max(capacity(sink, t) - value.(m[:trans_cap_current][tm, t_inv_prev]),
                                            EMI.min_add(tm, t) * value.(m[:trans_cap_invest_b][tm, t_inv])))
                    end
                end
            end

            # Test that the binary value is regulating the investments
            @testset "Binary value" begin
                if value.(m[:trans_cap_invest_b][tm, t_inv]) == 0
                    @test value.(m[:trans_cap_add][tm, t_inv]) == 0
                else
                    @test value.(m[:trans_cap_add][tm, t_inv]) ⪆ 0
                end
            end
        end
    end

end

# Test set for semicontinuous investments with offsets in the cost
@testset "Unidirectional transmission with SemiContinuousOffsetInvestment" begin

    # Creation and run of the optimization problem
    inv_data = [EMI.TransInvData(
        capex_trans     = FixedProfile(1),     # capex [€/kW]
        capex_trans_offset = FixedProfile(10),    # capex [€]
        trans_max_inst  = FixedProfile(250),    # max installed capacity [kW]
        trans_max_add   = FixedProfile(30),     # max_add [kW]
        trans_min_add   = FixedProfile(10),     # min_add [kW]
        inv_mode        = SemiContinuousOffsetInvestment(),
        trans_increment = FixedProfile(10),
        trans_start     = 0,
    )]

    case, modeltype = small_graph_geo(;inv_data)
    m               = optimize(case, modeltype)

    general_tests(m)

    # Extraction of required data
    𝒯    = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sink = case[:nodes][4]
    tr_osl_trd  = case[:transmission][1]
    tm  = modes(tr_osl_trd)[1]

    # Test identifying that the there is no deficit
    @test sum(value.(m[:sink_deficit][sink, t])  == 0 for t ∈ 𝒯) == length(𝒯)

    # Test showing that the investments are as expected
    for (t_inv_prev, t_inv) ∈ withprev(𝒯ᴵⁿᵛ)
        @testset "Investment period $(t_inv.sp)" begin
            @testset "Invested capacity" begin
                if isnothing(t_inv_prev)
                    for t ∈ t_inv
                        @test (value.(m[:trans_cap_add][tm, t_inv])
                                        >= max(capacity(sink, t) - inv_data[1].trans_start,
                                            EMI.min_add(tm, t) * value.(m[:trans_cap_invest_b][tm, t_inv])))
                    end
                else
                    for t ∈ t_inv
                        @test (value.(m[:trans_cap_add][tm, t_inv])
                                        ⪆ max(capacity(sink, t) - value.(m[:trans_cap_current][tm, t_inv_prev]),
                                            EMI.min_add(tm, t) * value.(m[:trans_cap_invest_b][tm, t_inv])))
                    end
                end
            end

            # Test that the binary value is regulating the investments
            @testset "Binary value" begin
                if value.(m[:trans_cap_invest_b][tm, t_inv]) == 0
                    @test value.(m[:trans_cap_add][tm, t_inv]) == 0
                else
                    @test value.(m[:trans_cap_add][tm, t_inv]) ⪆ 0
                end
            end
        end
    end
    @testset "Investment costs" begin
        @test sum(value(m[:trans_cap_add][tm, t_inv]) * EMI.capex(tm, t_inv) +
            EMI.capex_offset(tm, t_inv) * value(m[:trans_cap_invest_b][tm, t_inv]) ≈
            value(m[:capex_trans][tm, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ, atol=TEST_ATOL) == length(𝒯ᴵⁿᵛ)
    end
end

# Test set for discrete investments
@testset "Unidirectional transmission with DiscreteInvestment" begin

    # Creation and run of the optimization problem
    inv_data = [EMI.TransInvData(
        capex_trans     = FixedProfile(10),     # capex [€/kW]
        trans_max_inst  = FixedProfile(250),    # max installed capacity [kW]
        trans_max_add   = FixedProfile(30),     # max_add [kW]
        trans_min_add   = FixedProfile(10),     # min_add [kW]
        inv_mode        = DiscreteInvestment(),
        trans_increment = FixedProfile(5),
        trans_start     = 5,
    )]

    case, modeltype = small_graph_geo(;inv_data)
    m               = optimize(case, modeltype)

    general_tests(m)

    # Extraction of required data
    𝒯    = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sink = case[:nodes][4]
    tr_osl_trd  = case[:transmission][1]
    tm  = modes(tr_osl_trd)[1]

    # Test identifying that the there is no deficit
    @test sum(value.(m[:sink_deficit][sink, t])  == 0 for t ∈ 𝒯) == length(𝒯)

    # Test showing that the investments are as expected
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @testset "Invested capacity $(t_inv.sp)" begin
            if value.(m[:trans_cap_invest_b][tm, t_inv]) == 0
                @test value.(m[:trans_cap_add][tm, t_inv]) == 0
            else
                @test value.(m[:trans_cap_add][tm, t_inv]) ≈
                    EMI.increment(tm, t_inv) * value.(m[:trans_cap_invest_b][tm, t_inv])
            end
        end
    end
end
