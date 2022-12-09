# Definition of the individual resources used in the simple system
CO2     = ResourceEmit("CO2", 1.)
Power   = ResourceCarrier("Power", 0.)

ROUND_DIGITS = 8

# import Gurobi
# const env = Gurobi.Env()

"""


Creates a simple geography test case with the potential for investments in transmission infrastructure
if provided with transmission investments through the argument `inv`
"""
function small_graph(; data=nothing, source=nothing, sink=nothing)
    products = [Power, CO2]

    # Creation of a dictionary with entries of 0. for all resources
    𝒫₀ = Dict(k  => 0 for k ∈ products)

    # Creation of a dictionary with entries of 0. for all emission resources
    𝒫ᵉᵐ₀ = Dict(k  => 0. for k ∈ products if typeof(k) == ResourceEmit{Float64})

    # Creation of the source and sink module as well as the arrays used for nodes and links
    if isnothing(source)
        source = EMB.RefSource(
                    "-src",
                    FixedProfile(50),
                    FixedProfile(10),
                    FixedProfile(5),
                    Dict(Power => 1),
                    𝒫ᵉᵐ₀,
                    Dict("" => EMB.EmptyData())
                )
    end

    if isnothing(sink)
        sink = EMB.RefSink(
                    "-snk",
                    StrategicFixedProfile([20, 25, 30, 35]),
                    Dict(:Surplus => FixedProfile(0), :Deficit => FixedProfile(1e6)),
                    Dict(Power => 1),
                    𝒫ᵉᵐ₀,
                )
    end

    nodes = [GEO.GeoAvailability(1, 𝒫₀, 𝒫₀), GEO.GeoAvailability(1, 𝒫₀, 𝒫₀), source, sink]
    links = [EMB.Direct(31, nodes[3], nodes[1], EMB.Linear())
             EMB.Direct(24, nodes[2], nodes[4], EMB.Linear())]
    
    # Creation of the two areas and potential transmission lines
    areas = [GEO.Area(1, "Oslo", 10.751, 59.921, nodes[1]), 
             GEO.Area(2, "Trondheim", 10.398, 63.4366, nodes[2])]        

    transmission_line = GEO.RefStatic("transline", Power, 10, 0.1, 1)
    
    # Check if investments are included
    if isnothing(data)
        data = Dict("" => EMB.EmptyData())
    else
        data = Dict("Investments" => Dict{GEO.TransmissionMode,EMB.Data}(transmission_line => data))
    end

    transmissions = [
                    GEO.Transmission(areas[1], areas[2], [transmission_line], data),
                    ]

    # Creation of the time structure and the used global data
    T = UniformTwoLevel(1, 4, 1, UniformTimes(1, 1, 1))
    global_data = IM.GlobalData(
                            Dict(CO2 => StrategicFixedProfile([450, 400, 350, 300])),
                            Dict(CO2 => StrategicFixedProfile([0, 0, 0, 0])),
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
                :global_data    => global_data,
                )

    return case
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
    optimize(cases)

Optimize the `case`.
"""
function optimize(case)
    model = IM.InvestmentModel()
    m = GEO.create_model(case, model)
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
    set_optimizer(m, optimizer)
    # set_optimizer(m,() -> Gurobi.Optimizer(env))
    optimize!(m)
    return m
end

# Test set for analysing the proper behaviour when no investment was included
@testset "Unidirectional transmission without investments" begin

    # Creation and run of the optimization problem
    case = small_graph()
    m    = optimize(case)

    general_tests(m)

    # Extraction of required data
    𝒯    = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sink = case[:nodes][4]
    tr_osl_trd  = case[:transmission][1]
    trans_mode  = tr_osl_trd.Modes[1]

    # Test identifying that the proper deficit is calculated
    @test sum(value.(m[:sink_deficit][sink, t])
                        ≈ sink.Cap[t] - trans_mode.Trans_cap for t ∈ 𝒯) == length(𝒯)
                        
    # Test showing that no investments take place
    @test sum(value.(m[:trans_cap_add][tr_osl_trd, t_inv, trans_mode])
                        == 0 for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)

end

# Test set for continuous investments
@testset "Unidirectional transmission with ContinuousInvestment" begin

    # Creation and run of the optimization problem
    data = IM.TransInvData(
                Capex_trans     = FixedProfile(10),     # capex [€/kW]
                Trans_max_inst  = FixedProfile(250),    # max installed capacity [kW]
                Trans_max_add   = FixedProfile(30),     # max_add [kW]
                Trans_min_add   = FixedProfile(0),      # min_add [kW]
                Inv_mode        = IM.ContinuousInvestment(),
                Trans_increment = FixedProfile(10),
                Trans_start     = 0,
            )

    case = small_graph(data=data)
    m    = optimize(case)

    general_tests(m)

    # Extraction of required data
    𝒯    = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sink = case[:nodes][4]
    tr_osl_trd  = case[:transmission][1]
    trans_mode  = tr_osl_trd.Modes[1]

    # Test identifying that the there is no deficit
    @test sum(value.(m[:sink_deficit][sink, t])  == 0 for t ∈ 𝒯) == length(𝒯)
                        
    # Test showing that the investments are as expected
    for t_inv ∈ 𝒯ᴵⁿᵛ
        if TS.isfirst(t_inv)
            @testset "First investment period" begin
                for t ∈ t_inv
                    @test (value.(m[:trans_cap_add][tr_osl_trd, t_inv, trans_mode]) 
                                    ≈ sink.Cap[t]-data.Trans_start)
                end
            end
        else
            @testset "Subsequent investment periods" begin
                for t ∈ t_inv
                    @test (value.(m[:trans_cap_add][tr_osl_trd, t_inv, trans_mode]) 
                            ≈ sink.Cap[t]-value.(m[:trans_cap_current][tr_osl_trd, previous(t_inv, 𝒯), trans_mode]))
                end
            end
        end
    end

end

# Test set for semicontinuous investments
@testset "Unidirectional transmission with SemiContinuousInvestment" begin

    # Creation and run of the optimization problem
    data = IM.TransInvData(
                Capex_trans     = FixedProfile(10),     # capex [€/kW]
                Trans_max_inst  = FixedProfile(250),    # max installed capacity [kW]
                Trans_max_add   = FixedProfile(30),     # max_add [kW]
                Trans_min_add   = FixedProfile(10),     # min_add [kW]
                Inv_mode        = IM.SemiContinuousInvestment(),
                Trans_increment = FixedProfile(10),
                Trans_start     = 0,
            )

    case = small_graph(data=data)
    m    = optimize(case)

    general_tests(m)

    # Extraction of required data
    𝒯    = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sink = case[:nodes][4]
    tr_osl_trd  = case[:transmission][1]
    trans_mode  = tr_osl_trd.Modes[1]

    # Test identifying that the there is no deficit
    @test sum(value.(m[:sink_deficit][sink, t])  == 0 for t ∈ 𝒯) == length(𝒯)
                        
    # Test showing that the investments are as expected
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @testset "Investment period $(t_inv.sp)" begin
            @testset "Invested capacity" begin
                if TS.isfirst(t_inv)
                    for t ∈ t_inv
                        @test (value.(m[:trans_cap_add][tr_osl_trd, t_inv, trans_mode]) 
                                        >= max(sink.Cap[t] - data.Trans_start, 
                                            data.Trans_min_add[t] * value.(m[:trans_invest_b][tr_osl_trd, t_inv, trans_mode])))
                    end
                else
                    for t ∈ t_inv
                        @test (value.(m[:trans_cap_add][tr_osl_trd, t_inv, trans_mode]) 
                                >= max(sink.Cap[t] - value.(m[:trans_cap_current][tr_osl_trd, previous(t_inv, 𝒯), trans_mode]), 
                                    data.Trans_min_add[t] * value.(m[:trans_invest_b][tr_osl_trd, t_inv, trans_mode])))
                    end
                end
            end

            # Test that the binary value is regulating the investments
            @testset "Binary value" begin
                if value.(m[:trans_invest_b][tr_osl_trd, t_inv, trans_mode]) == 0
                    @test value.(m[:trans_cap_add][tr_osl_trd, t_inv, trans_mode]) == 0
                else
                    @test value.(m[:trans_cap_add][tr_osl_trd, t_inv, trans_mode]) > 0
                end
            end
        end
    end

end


# Test set for discrete investments
@testset "Unidirectional transmission with IntegerInvestment" begin

    # Creation and run of the optimization problem
    data = IM.TransInvData(
                Capex_trans     = FixedProfile(10),     # capex [€/kW]
                Trans_max_inst  = FixedProfile(250),    # max installed capacity [kW]
                Trans_max_add   = FixedProfile(30),     # max_add [kW]
                Trans_min_add   = FixedProfile(10),     # min_add [kW]
                Inv_mode        = IM.IntegerInvestment(),
                Trans_increment = FixedProfile(5),
                Trans_start     = 5,
            )

    case = small_graph(data=data)
    m    = optimize(case)

    general_tests(m)

    # Extraction of required data
    𝒯    = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sink = case[:nodes][4]
    tr_osl_trd  = case[:transmission][1]
    trans_mode  = tr_osl_trd.Modes[1]

    # Test identifying that the there is no deficit
    @test sum(value.(m[:sink_deficit][sink, t])  == 0 for t ∈ 𝒯) == length(𝒯)
                        
    # Test showing that the investments are as expected
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @testset "Invested capacity $(t_inv.sp)" begin
            if value.(m[:trans_invest_b][tr_osl_trd, t_inv, trans_mode]) == 0
                @test value.(m[:trans_cap_add][tr_osl_trd, t_inv, trans_mode]) == 0
            else
                @test value.(m[:trans_cap_add][tr_osl_trd, t_inv, trans_mode]) ≈ 
                    data.Trans_increment[t_inv] * value.(m[:trans_invest_b][tr_osl_trd, t_inv, trans_mode]) 
            end
        end
    end

end