# Declaration of the required resources
CO2 = ResourceEmit("CO2", 1.)
Power = ResourceCarrier("Power", 0.)
products = [Power, CO2]

"""
Creates a simple test case with the potential for investments in capacity 
if provided with investments through the argument `inv_data`.
"""
function small_graph(;
                    source=nothing,
                    sink=nothing,
                    inv_data=nothing,
                    T=TwoLevel(4, 10, SimpleTimes(4, 1)),
                    discount_rate = 0.05,
                    )

    # Creation of a dictionary with entries of 0. for all resources
    𝒫₀ = Dict(k => 0 for k ∈ products)

    if isnothing(inv_data)
        investment_data_source = EMI.InvData(
            Capex_cap       = FixedProfile(1000),       # capex [€/kW]
            Cap_max_inst    = FixedProfile(30),         # max installed capacity [kW]
            Cap_max_add     = FixedProfile(20),         # max_add [kW]
            Cap_min_add     = FixedProfile(5),          # min_add [kW]
            Inv_mode        = EMI.ContinuousInvestment() # investment mode
        )
        demand_profile = FixedProfile(20)
    else
        investment_data_source = inv_data["investment_data"]
        demand_profile         = inv_data["profile"]
    end

    # Creation of the source and sink module as well as the arrays used for nodes and links
    if isnothing(source)
        source = EMB.RefSource("-src", FixedProfile(0), FixedProfile(10), 
                               FixedProfile(5), Dict(Power => 1),
                               [investment_data_source])
    end
    if isnothing(sink)
        sink = EMB.RefSink("-snk", demand_profile, 
            Dict(:Surplus => FixedProfile(0), :Deficit => FixedProfile(1e6)), 
            Dict(Power => 1))
    end
    nodes = [EMB.GenAvailability(1, 𝒫₀, 𝒫₀), source, sink]
    links = [EMB.Direct(21, nodes[2], nodes[1], EMB.Linear())
             EMB.Direct(13, nodes[1], nodes[3], EMB.Linear())]

    em_limits   = Dict(CO2 => StrategicProfile([450, 400, 350, 300]))
    em_cost     = Dict(CO2 => FixedProfile(0))
    modeltype  = InvestmentModel(em_limits, em_cost, CO2, discount_rate)

    case = Dict(:nodes       => nodes,
                :links       => links,
                :products    => products,
                :T           => T,
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


@testset "Test investments" begin

    @testset "Investment example - user interface" begin
        
        # Create simple model
        case, modeltype = generate_data()
        m                = optimize(case, modeltype)

        # Check model
        @test size(all_variables(m))[1] == 10496

        # Check results
        @test JuMP.termination_status(m) == MOI.OPTIMAL
        @test round(objective_value(m)) ≈ -313189
        
        CH4 = case[:products][1]
        CO2 = case[:products][4]
        𝒯    = case[:T]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)

        emissions_CO2 = [value.(m[:emissions_strategic])[t_inv, CO2] for t_inv ∈ 𝒯ᴵⁿᵛ]
        @test emissions_CO2 <= [450, 400, 350, 300]
    end

    @testset "Investment example - small_graph Continuous" begin
    
        # Cration and solving of the model
        case, modeltype = small_graph()
        m                = optimize(case, modeltype)

        # Extraction of required data
        source = case[:nodes][2]
        sink   = case[:nodes][3]
        𝒯    = case[:T]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        inv_data = EMI.investment_data(source)

        @testset "cap_inst" begin
            # Check that cap_inst is less than node.data.Cap_max_inst at all times.
            @test sum(value.(m[:cap_inst][source, t]) <= 
                        inv_data.Cap_max_inst[t] for t ∈ 𝒯) == length(𝒯)

            for t_inv in 𝒯ᴵⁿᵛ, t ∈ t_inv
                # Check the initial installed capacity is correct set.
                @test value.(m[:cap_inst][source, t]) == 
                            source.Cap[t_inv] + value.(m[:cap_add][source, t_inv])
                break
            end

            # Check that cap_inst is larger or equal to demand profile in sink and deficit
            @test sum(value.(m[:cap_inst][source, t])+value.(m[:sink_deficit][sink, t]) 
                        >= sink.Cap[t] for t ∈ 𝒯) == length(𝒯)
        end
        @test sum(value.(m[:cap_add][source, t_inv]) >= 
                    inv_data.Cap_min_add[t_inv] for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ)

    end

    @testset "Investment example - small_graph Discrete" begin
        
        # Variation in the test structure
        investment_data_source = EMI.InvData(
            Capex_cap       = FixedProfile(1000),       # capex [€/kW]
            Cap_max_inst    = FixedProfile(30),         # max installed capacity [kW]
            Cap_max_add     = FixedProfile(20),         # max_add [kW]
            Cap_min_add     = FixedProfile(5),          # min_add [kW]
            Cap_start       = 0,                        # Starting capacity 
            Inv_mode        = EMI.BinaryInvestment()   # investment mode
        )
        demand_profile = StrategicProfile([0, 20, 20, 0])
        inv_data = Dict(
                    "investment_data" => investment_data_source,
                    "profile"         => demand_profile
                    )

        
        source = EMB.RefSource("-src", FixedProfile(20), FixedProfile(10), 
                                FixedProfile(5), Dict(Power => 1),
                                [investment_data_source])
        
        # Cration and solving of the model
        case, modeltype = small_graph(source=source, inv_data=inv_data)
        m                = optimize(case, modeltype)

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
        𝒯 = TwoLevel(4, 10, SimpleTimes(4, 1))
        investment_data_source = EMI.InvData(
            Capex_cap       = FixedProfile(1000),       # capex [€/kW]
            Cap_max_inst    = FixedProfile(30),         # max installed capacity [kW]
            Cap_max_add     = StrategicProfile([0, 30, 0, 0]), # max_add [kW]
            Cap_min_add     = FixedProfile(0),          # min_add [kW]
            Cap_start       = 0,                        # Starting capacity 
            Inv_mode        = EMI.ContinuousInvestment()   # investment mode
        )
        demand_profile = StrategicProfile([0, 20, 25, 30])
        inv_data = Dict(
                    "investment_data" => investment_data_source,
                    "profile"         => demand_profile
                    )

        
        source = EMB.RefSource("-src", FixedProfile(20), FixedProfile(10), 
                                FixedProfile(5), Dict(Power => 1),
                                [investment_data_source])
        
        # Cration and solving of the model
        case, modeltype = small_graph(source=source, inv_data=inv_data, T=𝒯)
        m                = optimize(case, modeltype)

        # Extraction of required data
        source = case[:nodes][2]
        sink   = case[:nodes][3]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        
        # Check that the investment is only happening in one strategic period
        @test sum(value.(m[:cap_add][source, t_inv]) > 0 for t_inv ∈ 𝒯ᴵⁿᵛ) == 1
    end

    @testset "Investment example - small_graph Continuous fixed manually" begin
        
        # Variation in the test structure
        investment_data_source = EMI.InvData(
            Capex_cap       = FixedProfile(1000),       # capex [€/kW]
            Cap_max_inst    = FixedProfile(30),         # max installed capacity [kW]
            Cap_max_add     = StrategicProfile([0, 30, 0, 0]),         # max_add [kW]
            Cap_min_add     = StrategicProfile([0, 5, 0, 0]),          # min_add [kW]
            Cap_start       = 0,                        # Starting capacity 
            Inv_mode        = EMI.ContinuousInvestment()   # investment mode
        )
        demand_profile = StrategicProfile([0, 20, 25, 30])
        inv_data = Dict(
                    "investment_data" => investment_data_source,
                    "profile"         => demand_profile
                    )

        
        source = EMB.RefSource("-src", FixedProfile(20), FixedProfile(10), 
                                FixedProfile(5), Dict(Power => 1),
                                [investment_data_source])
        
        # Cration and solving of the model
        case, modeltype = small_graph(source=source, inv_data=inv_data)
        m                = optimize(case, modeltype)

        # Extraction of required data
        source = case[:nodes][2]
        sink   = case[:nodes][3]
        𝒯    = case[:T]
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        
        # Check that the investment is only happening in one strategic period
        @test sum(value.(m[:cap_add][source, t_inv]) > 0 for t_inv ∈ 𝒯ᴵⁿᵛ) == 1
    end
end