NG          = ResourceEmit("NG", 0.2)
CO2         = ResourceEmit("CO2", 1.)
Power       = ResourceCarrier("Power", 0.)
Coal        = ResourceCarrier("Coal", 0.35)
products    = [NG, Power, CO2, Coal]
ROUND_DIGITS = 8
𝒫ᵉᵐ₀ = Dict(k  => 0 for k ∈ products if typeof(k) == ResourceEmit{Float64})

function small_graph(;
                    source=nothing,
                    sink=nothing,
                    data=nothing,
                    T=UniformTwoLevel(1, 4, 10, UniformTimes(1, 4, 1)),
                    discount_rate = 0.05,
                    )

    # products = [NG, Coal, Power, CO2]
    products = [NG, Power, CO2, Coal]
    
    # Creation of a dictionary with entries of 0. for all resources
    𝒫₀ = Dict(k => 0 for k ∈ products)

    if isnothing(data)
        investment_data_source = IM.extra_inv_data(
            Capex_Cap       = FixedProfile(1000),       # capex [€/kW]
            Cap_max_inst    = FixedProfile(30),         # max installed capacity [kW]
            Cap_max_add     = FixedProfile(20),         # max_add [kW]
            Cap_min_add     = FixedProfile(5),          # min_add [kW]
            Inv_mode        = IM.ContinuousInvestment() # investment mode
        )
        demand_profile = FixedProfile(20)
    else
        investment_data_source = data["investment_data"]
        demand_profile         = data["profile"]
    end

    # Creation of the source and sink module as well as the arrays used for nodes and links
    if isnothing(source)
        source = EMB.RefSource("-src", FixedProfile(0), FixedProfile(10), 
                               FixedProfile(5), Dict(Power => 1), 𝒫ᵉᵐ₀,
                               Dict("EnergyModelsInvestments"=>investment_data_source))
    end
    if isnothing(sink)
        sink = EMB.RefSink("-snk", demand_profile, 
            Dict(:Surplus => FixedProfile(0), :Deficit => FixedProfile(1e6)), 
            Dict(Power => 1), 𝒫ᵉᵐ₀)
    end
    nodes = [EMB.GenAvailability(1, 𝒫₀, 𝒫₀), source, sink]
    links = [EMB.Direct(21, nodes[2], nodes[1], EMB.Linear())
             EMB.Direct(13, nodes[1], nodes[3], EMB.Linear())]

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
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
    set_optimizer(m, optimizer)
    set_optimizer_attribute(m, "output_flag", false)
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

    @testset "Investment example - user interface" begin
        
        model = IM.InvestmentModel()

        # Create simple model
        m, case = IM.run_model("", model, HiGHS.Optimizer)

        # Check model
        @test size(all_variables(m))[1] == 11948

        # Check results
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test round(objective_value(m)) ≈ -292700
        
        CH4 = case[:products][1]
        CO2 = case[:products][4]
        𝒯    = case[:T]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        emissions_CO2 = [value.(m[:emissions_strategic])[t_inv, CO2] for t_inv ∈ 𝒯ᴵⁿᵛ]
        @test emissions_CO2 <= [450, 400, 350, 300]
    end

    @testset "Investment example - small_graph Continuous" begin
    
        # Cration and solving of the model
        case = small_graph()
        m = optimize(case)

        # Extraction of required data
        source = case[:nodes][2]
        sink   = case[:nodes][3]
        𝒯    = case[:T]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        @testset "cap_inst" begin
            # Check that cap_inst is less than node.data.Cap_max_inst at all times.
            @test sum(value.(m[:cap_inst][source, t]) <= 
                        source.Data["EnergyModelsInvestments"].Cap_max_inst[t] for t ∈ 𝒯) == length(𝒯)

            for t_inv in 𝒯ᴵⁿᵛ, t ∈ t_inv
                # Check the initial installed capacity is correct set.
                @test value.(m[:cap_inst][source, t]) == 
                            TS.getindex(source.Cap,t_inv) + value.(m[:cap_add][source, t_inv])
                break
            end

            # Check that cap_inst is larger or equal to demand profile in sink and deficit
            @test sum(value.(m[:cap_inst][source, t])+value.(m[:sink_deficit][sink, t]) 
                        >= sink.Cap[t] for t ∈ 𝒯) == length(𝒯)
        end
        @test sum(value.(m[:cap_add][source, t_inv]) >= 
                    source.Data["EnergyModelsInvestments"].Cap_min_add[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)

    end

    @testset "Investment example - small_graph Discrete" begin
        
        # Variation in the test structure
        investment_data_source = IM.extra_inv_data(
            Capex_Cap       = FixedProfile(1000),       # capex [€/kW]
            Cap_max_inst    = FixedProfile(30),         # max installed capacity [kW]
            Cap_max_add     = FixedProfile(20),         # max_add [kW]
            Cap_min_add     = FixedProfile(5),          # min_add [kW]
            Cap_start       = 0,                        # Starting capacity 
            Inv_mode        = IM.DiscreteInvestment()   # investment mode
        )
        demand_profile = StrategicFixedProfile([0, 20, 20, 0])
        data = Dict(
                    "investment_data" => investment_data_source,
                    "profile"         => demand_profile
                    )

        
        source = EMB.RefSource("-src", FixedProfile(20), FixedProfile(10), 
                                FixedProfile(5), Dict(Power => 1), 𝒫ᵉᵐ₀,
                                Dict("EnergyModelsInvestments"=>investment_data_source))
        
        # Cration and solving of the model
        case = small_graph(source=source, data=data)
        m = optimize(case)

        # Extraction of required data
        source = case[:nodes][2]
        sink   = case[:nodes][3]
        𝒯    = case[:T]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        
        # Check the binary variables
        @test sum(value.(m[:cap_invest_b][source, t_inv]) ≈ 1 for t_inv ∈ 𝒯ᴵⁿᵛ) +
                sum(value.(m[:cap_invest_b][source, t_inv]) ≈ 0 for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)
        @test sum(value.(m[:cap_inst][source, t]) <= source.Cap[t] for t ∈ 𝒯) == length(𝒯)

    end
    
    @testset "Investment example - small_graph ContinuousFixed" begin
        
        # Variation in the test structure
        𝒯 = UniformTwoLevel(1, 4, 10, UniformTimes(1, 4, 1))
        sp1 = strategic_period(𝒯, 2)
        investment_data_source = IM.extra_inv_data(
            Capex_Cap       = FixedProfile(1000),       # capex [€/kW]
            Cap_max_inst    = FixedProfile(30),         # max installed capacity [kW]
            Cap_max_add     = FixedProfile(30),         # max_add [kW]
            Cap_min_add     = FixedProfile(5),          # min_add [kW]
            Cap_start       = 0,                        # Starting capacity 
            Inv_mode        = IM.ContinuousFixedInvestment(sp1)   # investment mode
        )
        demand_profile = StrategicFixedProfile([0, 20, 25, 30])
        data = Dict(
                    "investment_data" => investment_data_source,
                    "profile"         => demand_profile
                    )

        
        source = EMB.RefSource("-src", FixedProfile(20), FixedProfile(10), 
                                FixedProfile(5), Dict(Power => 1), 𝒫ᵉᵐ₀,
                                Dict("EnergyModelsInvestments"=>investment_data_source))
        
        # Cration and solving of the model
        case = small_graph(source=source, data=data, T=𝒯)
        m = optimize(case)

        # Extraction of required data
        source = case[:nodes][2]
        sink   = case[:nodes][3]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        
        # Check that the investment is only happening in one strategic period
        @test sum(value.(m[:cap_add][source, t_inv]) > 0 for t_inv ∈ 𝒯ᴵⁿᵛ) == 1
    end

    @testset "Investment example - small_graph Continuous fixed manually" begin
        
        # Variation in the test structure
        investment_data_source = IM.extra_inv_data(
            Capex_Cap       = FixedProfile(1000),       # capex [€/kW]
            Cap_max_inst    = FixedProfile(30),         # max installed capacity [kW]
            Cap_max_add     = StrategicFixedProfile([0, 30, 0, 0]),         # max_add [kW]
            Cap_min_add     = StrategicFixedProfile([0, 5, 0, 0]),          # min_add [kW]
            Cap_start       = 0,                        # Starting capacity 
            Inv_mode        = IM.ContinuousInvestment()   # investment mode
        )
        demand_profile = StrategicFixedProfile([0, 20, 25, 30])
        data = Dict(
                    "investment_data" => investment_data_source,
                    "profile"         => demand_profile
                    )

        
        source = EMB.RefSource("-src", FixedProfile(20), FixedProfile(10), 
                                FixedProfile(5), Dict(Power => 1), 𝒫ᵉᵐ₀,
                                Dict("EnergyModelsInvestments"=>investment_data_source))
        
        # Cration and solving of the model
        case = small_graph(source=source, data=data)
        m = optimize(case)

        # Extraction of required data
        source = case[:nodes][2]
        sink   = case[:nodes][3]
        𝒯    = case[:T]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        
        # Check that the investment is only happening in one strategic period
        @test sum(value.(m[:cap_add][source, t_inv]) > 0 for t_inv ∈ 𝒯ᴵⁿᵛ) == 1
    end
end