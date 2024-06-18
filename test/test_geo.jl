"""
    optimize_geo(case)

Optimize the `case`.
"""
function optimize_geo(case, modeltype)
    m = EMG.create_model(case, modeltype)
    set_optimizer(m, OPTIMIZER)
    optimize!(m)
    return m
end

# Test set for analysing the proper behaviour when no investment was included
@testset "Unidirectional transmission without investments" begin

    # Creation and run of the optimization problem
    case, modeltype = small_graph_geo()
    m               = optimize_geo(case, modeltype)

    general_tests(m)

    # Extraction of required data
    𝒯    = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sink = case[:nodes][4]
    tr_osl_trd  = case[:transmission][1]
    tm  = modes(tr_osl_trd)[1]

    # Test identifying that the proper deficit is calculated
    @test sum(
        value.(m[:sink_deficit][sink, t])
            ≈ capacity(sink, t) - capacity(tm, t) for t ∈ 𝒯
        ) == length(𝒯)

    # Test showing that no investment variables are created
    @test isempty((m[:trans_cap_current]))
    @test isempty((m[:trans_cap_add]))
    @test isempty((m[:trans_cap_rem]))
    @test isempty((m[:trans_cap_invest_b]))
    @test isempty((m[:trans_cap_remove_b]))
end

# Test set for continuous investments
@testset "Unidirectional transmission with ContinuousInvestment" begin

    # Creation and run of the optimization problem
    inv_data = SingleInvData(
        FixedProfile(10),       # capex [€/kW]
        FixedProfile(250),      # max installed capacity [kW]
        0,                      # initial capacity [kW]
        ContinuousInvestment(FixedProfile(0), FixedProfile(30)),
    )

    case, modeltype = small_graph_geo(;inv_data)
    m               = optimize_geo(case, modeltype)

    general_tests(m)

    # Extraction of required data
    𝒯    = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sink = case[:nodes][4]
    tr_osl_trd  = case[:transmission][1]
    tm  = modes(tr_osl_trd)[1]
    inv_data = EMI.investment_data(tm, :cap)

    # Test identifying that the there is no deficit
    @test sum(value.(m[:sink_deficit][sink, t])  == 0 for t ∈ 𝒯) == length(𝒯)

    # Test showing that the investments are as expected
    for (t_inv_prev, t_inv) ∈ withprev(𝒯ᴵⁿᵛ)
        if isnothing(t_inv_prev)
            @testset "First investment period" begin
                for t ∈ t_inv
                    @test (value.(m[:trans_cap_add][tm, t_inv])
                                    ≈ capacity(sink, t)-inv_data.initial) atol=TEST_ATOL
                end
            end
        else
            @testset "Subsequent investment periods" begin
                for t ∈ t_inv
                    @test (value.(m[:trans_cap_add][tm, t_inv])
                            ≈ capacity(sink, t) -
                              value.(m[:trans_cap_current][tm, t_inv_prev])) atol=TEST_ATOL
                end
            end
        end
    end

end

# Test set for semicontinuous investments
@testset "Unidirectional transmission with SemiContinuousInvestment" begin

    # Creation and run of the optimization problem
    inv_data = SingleInvData(
        FixedProfile(10),       # capex [€/kW]
        FixedProfile(250),      # max installed capacity [kW]
        0,                      # initial capacity [kW]
        SemiContinuousInvestment(FixedProfile(10), FixedProfile(30)),
    )

    case, modeltype = small_graph_geo(;inv_data)
    m               = optimize_geo(case, modeltype)

    general_tests(m)

    # Extraction of required data
    𝒯    = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sink = case[:nodes][4]
    tr_osl_trd  = case[:transmission][1]
    tm  = modes(tr_osl_trd)[1]
    inv_data = EMI.investment_data(tm, :cap)

    # Test identifying that the there is no deficit
    @test sum(value.(m[:sink_deficit][sink, t])  == 0 for t ∈ 𝒯) == length(𝒯)

    # Test showing that the investments are as expected
    for (t_inv_prev, t_inv) ∈ withprev(𝒯ᴵⁿᵛ)
        @testset "Investment period $(t_inv.sp)" begin
            @testset "Invested capacity" begin
                if isnothing(t_inv_prev)
                    for t ∈ t_inv
                        @test (value.(m[:trans_cap_add][tm, t_inv])
                                        >= max(capacity(sink, t) - inv_data.initial,
                                            EMI.min_add(inv_data, t) * value.(m[:trans_cap_invest_b][tm, t_inv])))
                    end
                else
                    for t ∈ t_inv
                        @test (value.(m[:trans_cap_add][tm, t_inv])
                                        ⪆ max(capacity(sink, t) - value.(m[:trans_cap_current][tm, t_inv_prev]),
                                            EMI.min_add(inv_data, t) * value.(m[:trans_cap_invest_b][tm, t_inv])))
                    end
                end
            end

            # Test that the binary value is regulating the investments
            @testset "Binary value" begin
                if value.(m[:trans_cap_invest_b][tm, t_inv]) ≈ 0 atol=TEST_ATOL
                    @test value.(m[:trans_cap_add][tm, t_inv]) ≈ 0 atol=TEST_ATOL
                else
                    @test value.(m[:trans_cap_add][tm, t_inv]) ⪆ 0
                end
            end
        end
    end

    # Test that the variable cap_invest_b is a binary
    @test sum(is_binary(m[:trans_cap_invest_b][tm, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
end

# Test set for semicontinuous investments with offsets in the cost
@testset "Unidirectional transmission with SemiContinuousOffsetInvestment" begin

    # Creation and run of the optimization problem
    inv_data = SingleInvData(
        FixedProfile(10),       # capex [€/kW]
        FixedProfile(250),      # max installed capacity [kW]
        0,                      # initial capacity [kW]
        SemiContinuousOffsetInvestment(FixedProfile(10), FixedProfile(30), FixedProfile(10)),
    )

    case, modeltype = small_graph_geo(;inv_data)
    m               = optimize_geo(case, modeltype)

    general_tests(m)

    # Extraction of required data
    𝒯    = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sink = case[:nodes][4]
    tr_osl_trd  = case[:transmission][1]
    tm  = modes(tr_osl_trd)[1]
    inv_data = EMI.investment_data(tm, :cap)
    inv_mode = EMI.investment_mode(inv_data)

    # Test identifying that the there is no deficit
    @test sum(value.(m[:sink_deficit][sink, t])  == 0 for t ∈ 𝒯) == length(𝒯)

    # Test showing that the investments are as expected
    for (t_inv_prev, t_inv) ∈ withprev(𝒯ᴵⁿᵛ)
        @testset "Investment period $(t_inv.sp)" begin
            @testset "Invested capacity" begin
                if isnothing(t_inv_prev)
                    for t ∈ t_inv
                        @test (value.(m[:trans_cap_add][tm, t_inv])
                                        >= max(capacity(sink, t) - inv_data.initial,
                                            EMI.min_add(inv_data, t) * value.(m[:trans_cap_invest_b][tm, t_inv])))
                    end
                else
                    for t ∈ t_inv
                        @test (value.(m[:trans_cap_add][tm, t_inv])
                                        ⪆ max(capacity(sink, t) - value.(m[:trans_cap_current][tm, t_inv_prev]),
                                            EMI.min_add(inv_data, t) * value.(m[:trans_cap_invest_b][tm, t_inv])))
                    end
                end
            end

            # Test that the binary value is regulating the investments
            @testset "Binary value" begin
                if value.(m[:trans_cap_invest_b][tm, t_inv]) ≈ 0
                    @test value.(m[:trans_cap_add][tm, t_inv]) ≈ 0 atol=TEST_ATOL
                else
                    @test value.(m[:trans_cap_add][tm, t_inv]) ⪆ 0
                end
            end
        end
    end
    @testset "Investment costs" begin
        @test sum(value(m[:trans_cap_add][tm, t_inv]) * EMI.capex(inv_data, t_inv) +
            EMI.capex_offset(inv_mode, t_inv) * value(m[:trans_cap_invest_b][tm, t_inv]) ≈
            value(m[:trans_cap_capex][tm, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ, atol=TEST_ATOL) == length(𝒯ᴵⁿᵛ)
    end

    # Test that the variable cap_invest_b is a binary
    @test sum(is_binary(m[:trans_cap_invest_b][tm, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
end

# Test set for discrete investments
@testset "Unidirectional transmission with DiscreteInvestment" begin

    # Creation and run of the optimization problem
    inv_data = SingleInvData(
        FixedProfile(10),       # capex [€/kW]
        FixedProfile(250),      # max installed capacity [kW]
        0,                      # initial capacity [kW]
        DiscreteInvestment(FixedProfile(5)),
    )

    case, modeltype = small_graph_geo(;inv_data)
    m               = optimize_geo(case, modeltype)

    general_tests(m)

    # Extraction of required data
    𝒯    = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sink = case[:nodes][4]
    tr_osl_trd  = case[:transmission][1]
    tm  = modes(tr_osl_trd)[1]
    inv_data = EMI.investment_data(tm, :cap)

    # Test identifying that the there is no deficit
    @test sum(value.(m[:sink_deficit][sink, t])  == 0 for t ∈ 𝒯) == length(𝒯)

    # Test showing that the investments are as expected
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @testset "Invested capacity $(t_inv.sp)" begin
            if value.(m[:trans_cap_invest_b][tm, t_inv]) ≈ 0 atol=TEST_ATOL
                @test value.(m[:trans_cap_add][tm, t_inv]) ≈ 0 atol=TEST_ATOL
            else
                @test value.(m[:trans_cap_add][tm, t_inv]) ≈
                    EMI.increment(inv_data, t_inv) * value.(m[:trans_cap_invest_b][tm, t_inv])
            end
        end
    end

    # Test that the variable cap_invest_b is a binary
    @test sum(is_integer(m[:trans_cap_invest_b][tm, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
end
