resulting_obj = Dict()
@testset "Test Lifetime" begin

    lifetime = 15
    for sp_dur ∈ [2, 4, 6, 15]#,10,15,20]
        push!(resulting_obj, "$(sp_dur) years" => [])
        @testset "Modes - $(sp_dur) years" begin
            for life_mode ∈ [UnlimitedLife(), StudyLife(FixedProfile(15)), PeriodLife(FixedProfile(15)), RollingLife(FixedProfile(15))]
                @testset "Mode $(life_mode)" begin
                    @debug "~~~~~~~~ $(life_mode) - $(sp_dur) years ~~~~~~~~"

                    inv_data = Dict(
                        "investment_data" => [
                            SingleInvData(
                                FixedProfile(1000), # capex [€/kW]
                                FixedProfile(30),   # max installed capacity [kW]
                                ContinuousInvestment(FixedProfile(0), FixedProfile(30)), # investment mode
                                life_mode,          # lifetime mode
                            ),
                        ],
                        "profile" => FixedProfile(20),
                    )
                    T = TwoLevel(4, sp_dur, SimpleTimes(4, 1))
                    case, modeltype = small_graph(;inv_data, T)
                    m               = optimize(case, modeltype)

                    general_tests(m)

                    @debug value.(m[:cap_current])
                    @debug value.(m[:cap_add])
                    @debug value.(m[:cap_rem])

                    push!(resulting_obj["$(sp_dur) years"], objective_value(m))

                    source = case[:nodes][1]
                    inv_data = EMI.investment_data(source, :cap)
                    𝒯 = case[:T]
                    𝒯ⁱⁿᵛ = strategic_periods(𝒯)

                    @testset "cap_inst" begin
                        # Check that cap_inst is less than node.data.Cap_max_inst at all times.
                        @test sum(value.(m[:cap_inst][source, t]) <= EMI.max_installed(inv_data, t) for t ∈ 𝒯) == length(𝒯)

                        for t_inv in 𝒯ⁱⁿᵛ, t ∈ t_inv
                            # Check the initial installed capacity is correct set.
                            @test value.(m[:cap_inst][source, t]) == capacity(source, t_inv) + value.(m[:cap_add][source, t_inv])
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
