# Definition of the individual resources used in the simple system
CO2     = ResourceEmit("CO2", 1.)
Power   = ResourceCarrier("Power", 0.)
products = [Power, CO2]

"""
Creates a simple geography test case with the potential for investments in transmission infrastructure
if provided with transmission investments through the argument `inv_data`.
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

    # Check if investments are included
    if isnothing(inv_data)
        inv_data = []
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
    inv_data = TransInvData(
                capex_trans     = FixedProfile(10),     # capex [€/kW]
                trans_max_inst  = FixedProfile(250),    # max installed capacity [kW]
                trans_max_add   = FixedProfile(30),     # max_add [kW]
                trans_min_add   = FixedProfile(0),      # min_add [kW]
                inv_mode        = ContinuousInvestment(),
                trans_increment = FixedProfile(10),
                trans_start     = 0,
            )

    case, modeltype = small_graph_geo(inv_data=inv_data)
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
                                    ≈ capacity(sink, t)-inv_data.trans_start)
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
    inv_data = EMI.TransInvData(
                capex_trans     = FixedProfile(10),     # capex [€/kW]
                trans_max_inst  = FixedProfile(250),    # max installed capacity [kW]
                trans_max_add   = FixedProfile(30),     # max_add [kW]
                trans_min_add   = FixedProfile(10),     # min_add [kW]
                inv_mode        = SemiContinuousInvestment(),
                trans_increment = FixedProfile(10),
                trans_start     = 0,
            )

    case, modeltype = small_graph_geo(inv_data=inv_data)
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
                                        >= max(capacity(sink, t) - inv_data.trans_start,
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
    inv_data = EMI.TransInvData(
                capex_trans     = FixedProfile(1),     # capex [€/kW]
                capex_trans_offset = FixedProfile(10),    # capex [€]
                trans_max_inst  = FixedProfile(250),    # max installed capacity [kW]
                trans_max_add   = FixedProfile(30),     # max_add [kW]
                trans_min_add   = FixedProfile(10),     # min_add [kW]
                inv_mode        = SemiContinuousOffsetInvestment(),
                trans_increment = FixedProfile(10),
                trans_start     = 0,
            )

    case, modeltype = small_graph_geo(inv_data=inv_data)
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
                                        >= max(capacity(sink, t) - inv_data.trans_start,
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
    inv_data = EMI.TransInvData(
                capex_trans     = FixedProfile(10),     # capex [€/kW]
                trans_max_inst  = FixedProfile(250),    # max installed capacity [kW]
                trans_max_add   = FixedProfile(30),     # max_add [kW]
                trans_min_add   = FixedProfile(10),     # min_add [kW]
                inv_mode        = DiscreteInvestment(),
                trans_increment = FixedProfile(5),
                trans_start     = 5,
            )

    case, modeltype = small_graph_geo(inv_data=inv_data)
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
