
#IM = InvestmentModels
#EMB = EnergyModelsBase


NG = ResourceEmit("NG", 0.2)
CO2 = ResourceEmit("CO2", 1.)
Power = ResourceCarrier("Power", 0.)
Coal = ResourceCarrier("Coal", 0.35)
products = [NG, Power, CO2, Coal]
ROUND_DIGITS = 8
𝒫ᵉᵐ₀ = Dict(k  => FixedProfile(0) for k ∈ products if typeof(k) == ResourceEmit{Float64})

function small_graph(source=nothing, sink=nothing)
    # products = [NG, Coal, Power, CO2]
    products = [NG, Power, CO2, Coal]
    # Creation of a dictionary with entries of 0. for all resources
    𝒫₀ = Dict(k  => 0 for k ∈ products)
    # Creation of a dictionary with entries of 0. for all emission resources
    𝒫ᵉᵐ₀ = Dict(k  => 0. for k ∈ products if typeof(k) == ResourceEmit{Float64})
    𝒫ᵉᵐ₀[CO2] = 0.0

    if isnothing(source)
        investment_data_source = IM.extra_inv_data(
            FixedProfile(1000), # capex [€/kW]
            FixedProfile(30), #  max installed capacity [kW]
            FixedProfile(15), # max_add [kW]
            FixedProfile(5), # min_add [kW]
            IM.ContinuousInvestment() # investment mode
        )
        source = EMB.RefSource("-src", FixedProfile(0), FixedProfile(10), 
            FixedProfile(5), Dict(Power => 1), 𝒫ᵉᵐ₀, Dict("InvestmentModels"=>investment_data_source))
    end
    if isnothing(sink)
        sink = EMB.RefSink("-snk", FixedProfile(20), Dict(:surplus => 0, :deficit => 1e6), Dict(Power => 1), 𝒫ᵉᵐ₀)
    end
    nodes = [EMB.GenAvailability(1, 𝒫₀, 𝒫₀), source, sink]
    links = [EMB.Direct(21, nodes[2], nodes[1], EMB.Linear())
            EMB.Direct(13, nodes[1], nodes[3], EMB.Linear())]

    T = UniformTwoLevel(1, 4, 1, UniformTimes(1, 4, 1))

    data = Dict(:nodes => nodes,
                :links => links,
                :products => products,
                :T => T)
    return data
end

function optimize(data, case; discount_rate=5)
    model = IM.InvestmentModel(case, discount_rate)
    m = EMB.create_model(data, model)
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
        
        r = 0.07
        case = IM.StrategicCase(StrategicFixedProfile([450, 400, 350, 300]),𝒫ᵉᵐ₀)    # 
        model = IM.InvestmentModel(case, r)

        # Create simple model
        m, data = IM.run_model("", model, GLPK.Optimizer)
        # Check model
        @test size(all_variables(m))[1] == 11548

        println(solution_summary(m))

        # Check results
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test round(objective_value(m)) ≈ -204382
        
        print("~~~~~~ CAPACITY ~~~~~~ \n")
        for n in data[:nodes],t in strategic_periods(data[:T])
            print(n,", ",t,"   :   ",JuMP.value(m[:capacity][n,t]),"\n")
        end
        print("~~~~~~ ADD_CAP ~~~~~~ \n")
        for n in data[:nodes],t in strategic_periods(data[:T])
            print(n,", ",t,"   :   ",JuMP.value(m[:add_cap][n,t]),"\n")
        end
        print("~~~~~~ REM_CAP ~~~~~~ \n")
        for n in data[:nodes],t in strategic_periods(data[:T])
    
            print(n,", ",t,"   :   ",JuMP.value(m[:rem_cap][n,t]),"\n")
        end


        CH4 = data[:products][1]
        CO2 = data[:products][4]
        𝒯ᴵⁿᵛ = strategic_periods(data[:T])
        emissions_CO2 = [value.(m[:emissions_strategic])[t_inv,CO2] for t_inv ∈ 𝒯ᴵⁿᵛ]
        @test emissions_CO2 <= [450, 400, 350, 300]
        emissions_CH4 = [value.(m[:emissions_strategic])[t_inv,CH4] for t_inv ∈ 𝒯ᴵⁿᵛ]
        @test emissions_CH4 <= [0, 0, 0, 0]
        # With binary variables

        # Check model/results
    end

    @testset "Investment example 1" begin
    
        data = small_graph()
        case = IM.StrategicCase(StrategicFixedProfile([450, 400, 350, 300]),𝒫ᵉᵐ₀)
        m = optimize(data, case)

        println(solution_summary(m))

        general_tests(m)
        @show value.(m[:cap_usage])
        println()
        @show value.(m[:cap_max])
        println()
        @show value.(m[:add_cap])
        println()
        @show value.(m[:capacity])
        println()
        @show value.(m[:rem_cap])
        println()
        # @show value.(m[:rem_cap])

        source = data[:nodes][2]
        𝒯 = data[:T]
        𝒯ⁱⁿᵛ = strategic_periods(𝒯)

        @testset "cap_max" begin
            # Check that cap_max is less than node.data.max_inst_cap at all times.
            @test sum(value.(m[:cap_max][source, t]) <= source.data["InvestmentModels"].max_inst_cap[t] for t ∈ 𝒯) == length(𝒯)

            for t_inv in 𝒯ⁱⁿᵛ, t ∈ t_inv
                # Check the initial installed capacity is correct set.
                @test value.(m[:cap_max][source, t]) == TimeStructures.getindex(source.capacity,t_inv) + value.(m[:add_cap][source, t_inv])
                break
            end        
        end

    end

end