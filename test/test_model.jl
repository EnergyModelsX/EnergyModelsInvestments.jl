
#IM = InvestmentModels
#EMB = EnergyModelsBase


NG          = ResourceEmit("NG", 0.2)
CO2         = ResourceEmit("CO2", 1.)
Power       = ResourceCarrier("Power", 0.)
Coal        = ResourceCarrier("Coal", 0.35)
products    = [NG, Power, CO2, Coal]
ROUND_DIGITS = 8
𝒫ᵉᵐ₀ = Dict(k  => FixedProfile(0) for k ∈ products if typeof(k) == ResourceEmit{Float64})

function small_graph(source=nothing, sink=nothing; discount_rate = 0.05)
    # products = [NG, Coal, Power, CO2]
    products = [NG, Power, CO2, Coal]
    
    # Creation of a dictionary with entries of 0. for all resources
    𝒫₀ = Dict(k  => 0 for k ∈ products)

    # Creation of a dictionary with entries of 0. for all emission resources
    𝒫ᵉᵐ₀ = Dict(k  => 0. for k ∈ products if typeof(k) == ResourceEmit{Float64})
    𝒫ᵉᵐ₀[CO2] = 0.0

    if isnothing(source)
        investment_data_source = IM.extra_inv_data(
            Capex_Cap       = FixedProfile(1000), # capex [€/kW]
            Cap_max_inst    = FixedProfile(30), #  max installed capacity [kW]
            Cap_max_add     = FixedProfile(15), # max_add [kW]
            Cap_min_add     = FixedProfile(5), # min_add [kW]
            #IM.ContinuousInvestment() # investment mode
        )
        source = EMB.RefSource("-src", FixedProfile(0), FixedProfile(10), 
                               FixedProfile(5), Dict(Power => 1), 𝒫ᵉᵐ₀,
                               Dict("InvestmentModels"=>investment_data_source))
    end
    if isnothing(sink)
        sink = EMB.RefSink("-snk", FixedProfile(20), Dict(:Surplus => 0, :Deficit => 1e6), Dict(Power => 1), 𝒫ᵉᵐ₀)
    end
    nodes = [EMB.GenAvailability(1, 𝒫₀, 𝒫₀), source, sink]
    links = [EMB.Direct(21, nodes[2], nodes[1], EMB.Linear())
             EMB.Direct(13, nodes[1], nodes[3], EMB.Linear())]

    T = UniformTwoLevel(1, 4, 1, UniformTimes(1, 4, 1))

    em_limits   = Dict(NG => FixedProfile(1e6), CO2 => StrategicFixedProfile([450, 400, 350, 300]))
    em_cost     = Dict(NG => FixedProfile(0), CO2 => FixedProfile(0))
    global_data = IM.GlobalData(em_limits, em_cost, discount_rate)

    case = Dict(:nodes       => nodes,
                :links       => links,
                :products    => products,
                :T           => T,
                :global_data => global_data)
    return case
end

function optimize(case)
    model = IM.InvestmentModel()
    m = EMB.create_model(case, model)
    optimizer = GLPK.Optimizer
    set_optimizer(m, optimizer)
    optimize!(m)
    return m
end


function general_tests(m)
    # Check if the solution is optimal.
    @testset "optimal solution" begin
        @test termination_status(m) == MOI.OPTIMAL

        if termination_status(m) != MOI.OPTIMAL
            @show termination_status(m)
        end
    end
end


@testset "Test investments" begin

    @testset "Investment example" begin
        
        model = IM.InvestmentModel()

        # Create simple model
        m, case = IM.run_model("", model, GLPK.Optimizer)

        # Check model
        @test size(all_variables(m))[1] == 11948

        # println(solution_summary(m))

        # Check results
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test round(objective_value(m)) ≈ -292700
        
        print("~~~~~~ GEN CAPACITY ~~~~~~ \n")
        for n in (i for i ∈ case[:nodes] if IM.has_investment(i))
           print(n,": ")
           for t in strategic_periods(case[:T])
               print(JuMP.value(m[:cap_current][n,t]),", ")
           end
           print("\n")
        end
        print("~~~~~~ ADD_CAP ~~~~~~ \n")
        for n in (i for i ∈ case[:nodes] if IM.has_investment(i))
            print(n,": ")
            for t in strategic_periods(case[:T])
                print(JuMP.value(m[:cap_add][n,t]),", ")
            end
            print("\n")
        end
        print("~~~~~~ REM_CAP ~~~~~~ \n")
        for n in (i for i ∈ case[:nodes] if IM.has_investment(i))
            print(n,": ")
            for t in strategic_periods(case[:T])
                print(JuMP.value(m[:cap_rem][n,t]),", ")
            end
            print("\n")
        end
        print("~~~~~~ STOR CAPACITY ~~~~~~ \n")
        for n in (i for i ∈ case[:nodes] if IM.has_storage_investment(i))
           print(n,": ")
           for t in strategic_periods(case[:T])
               print(JuMP.value(m[:stor_cap_current][n,t]),", ", JuMP.value(m[:stor_rate_current][n,t]),", ")
           end
           print("\n")
        end


        CH4 = case[:products][1]
        CO2 = case[:products][4]
        𝒯ᴵⁿᵛ = strategic_periods(case[:T])
        emissions_CO2 = [value.(m[:emissions_strategic])[t_inv,CO2] for t_inv ∈ 𝒯ᴵⁿᵛ]
        @test emissions_CO2 <= [450, 400, 350, 300]
        emissions_CH4 = [value.(m[:emissions_strategic])[t_inv,CH4] for t_inv ∈ 𝒯ᴵⁿᵛ]
        @test emissions_CH4 <= [0, 0, 0, 0]
        # With binary variables

        # Check model/results
    end

    @testset "Investment example 1" begin
    
        case = small_graph()
        m = optimize(case)

        # println(solution_summary(m))

        general_tests(m)
        @show value.(m[:cap_use])
        println()
        @show value.(m[:cap_inst])
        println()
        @show value.(m[:cap_add])
        println()
        @show value.(m[:cap_rem])
        println()
        @show value.(m[:cap_current])

        source = case[:nodes][2]
        𝒯 = case[:T]
        𝒯ⁱⁿᵛ = strategic_periods(𝒯)

        @testset "cap_inst" begin
            # Check that cap_inst is less than node.data.Cap_max_inst at all times.
            @test sum(value.(m[:cap_inst][source, t]) <= source.Data["InvestmentModels"].Cap_max_inst[t] for t ∈ 𝒯) == length(𝒯)

            for t_inv in 𝒯ⁱⁿᵛ, t ∈ t_inv
                # Check the initial installed capacity is correct set.
                @test value.(m[:cap_inst][source, t]) == TimeStructures.getindex(source.Cap,t_inv) + value.(m[:cap_add][source, t_inv])
                break
            end        
        end

    end

end