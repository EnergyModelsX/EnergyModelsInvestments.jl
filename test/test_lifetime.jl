# Declaration of the required resources
CO2 = ResourceEmit("CO2", 1.)
Power = ResourceCarrier("Power", 0.)
products = [Power, CO2]

"""
Creates a simple test case for testing the individual Life_mode in the model
"""
function small_graph(sp_dur, Lifemode, L, source=nothing, sink=nothing; discount_rate=0.05)

    # Creation of a dictionary with entries of 0. for all resources
    𝒫₀ = Dict(k  => 0 for k ∈ products)
    if isnothing(source)
        investment_data_source = EMI.InvData(
            Capex_cap = FixedProfile(1000), # capex [€/kW]
            Cap_max_inst = FixedProfile(30), #  max installed capacity [kW]
            Cap_max_add = FixedProfile(30), # max_add [kW]
            Cap_min_add = FixedProfile(0), # min_add [kW]
            #EMI.ContinuousInvestment() # investment mode
            Life_mode = Lifemode,
            Lifetime = L,
        )
        source = EMB.RefSource("-src", FixedProfile(0), FixedProfile(10), 
            FixedProfile(5), Dict(Power => 1), [investment_data_source])
    end
    if isnothing(sink)
        sink = EMB.RefSink("-snk", FixedProfile(20), 
            Dict(:Surplus => FixedProfile(0), :Deficit => FixedProfile(1e6)), Dict(Power => 1))
    end
    nodes = [EMB.GenAvailability(1, 𝒫₀, 𝒫₀), source, sink]
    links = [EMB.Direct(21, nodes[2], nodes[1], EMB.Linear())
             EMB.Direct(13, nodes[1], nodes[3], EMB.Linear())]

    T = TwoLevel(4, sp_dur, SimpleTimes(4, 1))

    em_limits   = Dict(CO2 => StrategicProfile([450, 400, 350, 300]))
    em_cost     = Dict(CO2 => FixedProfile(0))
    modeltype  = InvestmentModel(em_limits, em_cost, CO2, discount_rate)

    case = Dict(:nodes => nodes,
                :links => links,
                :products => products,
                :T => T,
                )
    return case, modeltype
end

"""
    optimize(cases)

Optimize the `case`.
"""
function optimize(case, modeltype)
    m = EMB.create_model(case, modeltype)
    set_optimizer(m, OPTIMIZER)
    optimize!(m)
    return m
end


resulting_obj = Dict()

@testset "Test Lifetime" begin

    lifetime = 15
    for sp_dur ∈ [2,4,6]#,10,15,20]
        push!(resulting_obj, "$(sp_dur) years" => [])
        @testset "Modes - $(sp_dur) years" begin
            for Lifemode ∈ [EMI.UnlimitedLife(), EMI.StudyLife(), EMI.PeriodLife(),EMI.RollingLife()]
                @testset "Mode $(Lifemode)" begin
                    @debug "~~~~~~~~ $(Lifemode) - $(sp_dur) years ~~~~~~~~"
                    case, modeltype = small_graph(sp_dur, Lifemode, FixedProfile(lifetime))
                    m               = optimize(case, modeltype)

                    general_tests(m)

                    @debug value.(m[:cap_current])
                    @debug value.(m[:cap_add])
                    @debug value.(m[:cap_rem])

                    push!(resulting_obj["$(sp_dur) years"], objective_value(m))

                    source = case[:nodes][2]
                    𝒯 = case[:T]
                    𝒯ⁱⁿᵛ = strategic_periods(𝒯)

                    @testset "cap_inst" begin
                        # Check that cap_inst is less than node.data.Cap_max_inst at all times.
                        @test sum(value.(m[:cap_inst][source, t]) <= EMI.investment_data(source).Cap_max_inst[t] for t ∈ 𝒯) == length(𝒯)

                        for t_inv in 𝒯ⁱⁿᵛ, t ∈ t_inv
                            # Check the initial installed capacity is correct set.
                            @test value.(m[:cap_inst][source, t]) == source.Cap[t_inv] + value.(m[:cap_add][source, t_inv])
                            break
                        end        
                    end
                end
            end
        end
        @testset "Cost comparisons - $(sp_dur) years" begin
            if sp_dur > lifetime
                @test floor(resulting_obj["$(sp_dur) years"][3]) == floor(resulting_obj["$(sp_dur) years"][4])
            elseif sp_dur == lifetime
                @test floor(resulting_obj["$(sp_dur) years"][3]) == floor(resulting_obj["$(sp_dur) years"][4])
                @test floor(resulting_obj["$(sp_dur) years"][2]) == floor(resulting_obj["$(sp_dur) years"][3])
            end
            if sp_dur*4 < lifetime #4 corresponds to the len of T, i.e. the number of strategic periods.
                @test floor(resulting_obj["$(sp_dur) years"][2]) ≈ floor(resulting_obj["$(sp_dur) years"][4])
            end
        end
    end
end
@debug resulting_obj