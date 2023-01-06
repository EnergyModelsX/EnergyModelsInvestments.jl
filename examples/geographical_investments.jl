using HiGHS
using JuMP

using EnergyModelsBase
using EnergyModelsGeography
using EnergyModelsInvestments
using TimeStructures


const EMB = EnergyModelsBase
const GEO = EnergyModelsGeography
const IM = EnergyModelsInvestments


function run_model(case, model, optimizer=nothing)
    @info "Run model" model optimizer
 
    m = EMB.create_model(case, model)
 
    set_optimizer(m, optimizer)
    optimize!(m)
    return m
end


function generate_data(modeltype::InvestmentModel)
    @debug "Generate case data"
    @info "Generate data coded dummy model for now (Investment Model)"

    # Retrieve the products
    𝒫₀, 𝒫ᵉᵐ₀, products = GEO.get_resources()
    NG    = products[1]
    Power = products[3]
    CO2   = products[4]

    # Create input data for the areas
    area_ids    = [1, 2, 3, 4]
    d_scale     = Dict(1=>3.0, 2=>1.5, 3=>1.0, 4=>0.5)
    mc_scale    = Dict(1=>2.0, 2=>2.0, 3=>1.5, 4=>0.5)
    gen_scale   = Dict(1=>1.0, 2=>1.0, 3=>1.0, 4=>0.5)

    # Create identical areas with index according to input array
    an           = Dict()
    transmission = []
    nodes        = []
    links        = []
    for a_id in area_ids
        n, l = get_sub_system_data(a_id, 𝒫₀, 𝒫ᵉᵐ₀, products, modeltype; 
                                       gen_scale = gen_scale[a_id], mc_scale = mc_scale[a_id],
                                       d_scale = d_scale[a_id])
        append!(nodes, n)
        append!(links, l)

        # Add area node for each subsystem
        an[a_id] = n[1]
    end

    # Create the individual areas and transmission modes
    areas = [GEO.Area(1, "Oslo",        10.751, 59.921, an[1]),
             GEO.Area(2, "Bergen",       5.334, 60.389, an[2]),
             GEO.Area(3, "Trondheim",   10.398, 63.437, an[3]),
             GEO.Area(4, "Tromsø",      18.953, 69.669, an[4])]

    OverheadLine_50MW   = GEO.RefStatic("PowerLine_50", Power, 50.0, 0.05, 2)#, EMB.Linear)
    LNG_Ship_100MW      = GEO.RefDynamic("LNG_100", NG, 100.0, 0.05, 2)#, EMB.Linear)

 transmission = [GEO.Transmission(areas[1], areas[2], [OverheadLine_50MW],Dict("Investments"=> Dict{GEO.TransmissionMode,EMB.Data}(OverheadLine_50MW => TransInvData(Capex_trans=FixedProfile(500), Trans_max_inst=FixedProfile(50), Trans_max_add=FixedProfile(100), Trans_min_add=FixedProfile(0), Inv_mode=DiscreteInvestment())))),
 GEO.Transmission(areas[1], areas[3], [OverheadLine_50MW],Dict("Investments"=> Dict{GEO.TransmissionMode,EMB.Data}(OverheadLine_50MW => TransInvData(Capex_trans=FixedProfile(10), Trans_max_inst=FixedProfile(100), Trans_max_add=FixedProfile(100), Trans_min_add=FixedProfile(10), Inv_mode=SemiContinuousInvestment(), Trans_start=0)))),
 GEO.Transmission(areas[2], areas[3], [OverheadLine_50MW],Dict("Investments"=> Dict{GEO.TransmissionMode,EMB.Data}(OverheadLine_50MW => TransInvData(Capex_trans=FixedProfile(10), Trans_max_inst=FixedProfile(50), Trans_max_add=FixedProfile(100), Trans_min_add=FixedProfile(5), Inv_mode=IntegerInvestment(), Trans_increment=FixedProfile(6), Trans_start=20)))),
 GEO.Transmission(areas[3], areas[4], [OverheadLine_50MW],Dict("Investments"=> Dict{GEO.TransmissionMode,EMB.Data}(OverheadLine_50MW => TransInvData(Capex_trans=FixedProfile(10), Trans_max_inst=FixedProfile(50), Trans_max_add=FixedProfile(100), Trans_min_add=FixedProfile(1), Inv_mode=ContinuousInvestment(), Trans_start=0)))),
 GEO.Transmission(areas[4], areas[2], [LNG_Ship_100MW],Dict(""=> EMB.EmptyData()))]

    # Creation of the time structure and global data
    T           = UniformTwoLevel(1, 4, 1, UniformTimes(1, 24, 1))
    em_limits   = Dict(NG => FixedProfile(1e6), CO2 => StrategicFixedProfile([450, 400, 350, 300]))
    em_cost     = Dict(NG => FixedProfile(0),   CO2 => FixedProfile(0))
    global_data = IM.GlobalData(em_limits, em_cost, 0.07)


    # WIP data structure
    case = Dict(
                :areas          => Array{GEO.Area}(areas),
                :transmission   => Array{GEO.Transmission}(transmission),
                :nodes          => Array{EMB.Node}(nodes),
                :links          => Array{EMB.Link}(links),
                :products       => products,
                :T              => T,
                :global_data    => global_data
                )
    return case
end


function get_resources()

    # Define the different resources
    NG       = ResourceEmit("NG", 0.2)
    Coal     = ResourceCarrier("Coal", 0.35)
    Power    = ResourceCarrier("Power", 0.)
    CO2      = ResourceEmit("CO2",1.)
    products = [NG, Coal, Power, CO2]

    # Creation of a dictionary with entries of 0. for all resources
    𝒫₀ = Dict(k  => 0 for k ∈ products)

    # Creation of a dictionary with entries of 0. for all emission resources
    𝒫ᵉᵐ₀ = Dict(k  => 0. for k ∈ products if typeof(k) == ResourceEmit{Float64})
    𝒫ᵉᵐ₀[CO2] = 0.0

    return 𝒫₀, 𝒫ᵉᵐ₀, products
end


function get_sub_system_data(i,𝒫₀, 𝒫ᵉᵐ₀, products, modeltype::InvestmentModel;
                    gen_scale::Float64=1.0, mc_scale::Float64=1.0, d_scale::Float64=1.0, demand=false)
    
    NG, Coal, Power, CO2 = products

    if demand == false
        demand = [20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
                20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
                20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
                20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20]
        demand *= d_scale
    end

    j=(i-1)*100
    nodes = [
            GEO.GeoAvailability(j+1, 𝒫₀, 𝒫₀),
            EMB.RefSink(j+2, DynamicProfile(demand),
                    Dict(:Surplus => FixedProfile(0), :Deficit => FixedProfile(1e6)), Dict(Power => 1), 𝒫ᵉᵐ₀),
            EMB.RefSource(j+3, FixedProfile(30), FixedProfile(30*mc_scale), FixedProfile(100), Dict(NG => 1), 𝒫ᵉᵐ₀,Dict("Investments" => extra_inv_data(Capex_Cap=FixedProfile(1000),Cap_max_inst=FixedProfile(200),Cap_max_add=FixedProfile(200),Cap_min_add=FixedProfile(0),Inv_mode=ContinuousInvestment(), Cap_increment=FixedProfile(5), Cap_start=0))),  
            EMB.RefSource(j+4, FixedProfile(9), FixedProfile(9*mc_scale), FixedProfile(100), Dict(Coal => 1), 𝒫ᵉᵐ₀,Dict("Investments" => extra_inv_data(Capex_Cap=FixedProfile(1000),Cap_max_inst=FixedProfile(200),Cap_max_add=FixedProfile(200),Cap_min_add=FixedProfile(0),Inv_mode=ContinuousInvestment(), Cap_start=0))),  
            EMB.RefGeneration(j+5, FixedProfile(0), FixedProfile(5.5*mc_scale), FixedProfile(100), Dict(NG => 2), Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0.9,Dict("Investments" => extra_inv_data(Capex_Cap=FixedProfile(600),Cap_max_inst=FixedProfile(25),Cap_max_add=FixedProfile(25),Cap_min_add=FixedProfile(0),Inv_mode=ContinuousInvestment()))),  
            EMB.RefGeneration(j+6, FixedProfile(0), FixedProfile(6*mc_scale), FixedProfile(100),  Dict(Coal => 2.5), Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0,Dict("Investments" => extra_inv_data(Capex_Cap=FixedProfile(800),Cap_max_inst=FixedProfile(25),Cap_max_add=FixedProfile(25),Cap_min_add=FixedProfile(0),Inv_mode=ContinuousInvestment()))),  
            EMB.RefStorage(j+7, FixedProfile(0), FixedProfile(0), FixedProfile(9.1*mc_scale), FixedProfile(100),  Dict(CO2 => 1, Power => 0.02), Dict(CO2 => 1),Dict("Investments" => extra_inv_data_storage(Capex_rate=FixedProfile(500),Rate_max_inst=FixedProfile(600),Rate_max_add=FixedProfile(600),Rate_min_add=FixedProfile(0),Capex_stor=FixedProfile(500),Stor_max_inst=FixedProfile(600),Stor_max_add=FixedProfile(600),Stor_min_add=FixedProfile(0),Inv_mode=ContinuousInvestment()))),
            EMB.RefGeneration(j+8, FixedProfile(0), FixedProfile(0*mc_scale), FixedProfile(0),  Dict(Coal => 2.5), Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0,Dict("Investments" => extra_inv_data(Capex_Cap=FixedProfile(1000),Cap_max_inst=FixedProfile(25),Cap_max_add=FixedProfile(2),Cap_min_add=FixedProfile(0),Inv_mode=ContinuousInvestment()))),  
            EMB.RefStorage(j+9, FixedProfile(3), FixedProfile(5), FixedProfile(0*mc_scale), FixedProfile(0),  Dict(CO2 => 1, Power => 0.02), Dict(CO2 => 1),Dict("Investments" => extra_inv_data_storage(Capex_rate=FixedProfile(500),Rate_max_inst=FixedProfile(30),Rate_max_add=FixedProfile(3),Rate_min_add=FixedProfile(0),Capex_stor=FixedProfile(500),Stor_max_inst=FixedProfile(50),Stor_max_add=FixedProfile(5),Stor_min_add=FixedProfile(0),Inv_mode=ContinuousInvestment()))),
            EMB.RefGeneration(j+10, FixedProfile(0), FixedProfile(0*mc_scale), FixedProfile(0),  Dict(Coal => 2.5), Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0,Dict("Investments" => extra_inv_data(Capex_Cap=FixedProfile(10000),Cap_max_inst=FixedProfile(10000),Cap_max_add=FixedProfile(10000),Cap_min_add=FixedProfile(0),Inv_mode=ContinuousInvestment()))),  
                ]

    links = [
            EMB.Direct(j*10+15,nodes[1],nodes[5],EMB.Linear())
            EMB.Direct(j*10+16,nodes[1],nodes[6],EMB.Linear())
            EMB.Direct(j*10+17,nodes[1],nodes[7],EMB.Linear())
            EMB.Direct(j*10+18,nodes[1],nodes[8],EMB.Linear())
            EMB.Direct(j*10+19,nodes[1],nodes[9],EMB.Linear())
            EMB.Direct(j*10+110,nodes[1],nodes[10],EMB.Linear())
            EMB.Direct(j*10+12,nodes[1],nodes[2],EMB.Linear())
            EMB.Direct(j*10+31,nodes[3],nodes[1],EMB.Linear())
            EMB.Direct(j*10+41,nodes[4],nodes[1],EMB.Linear())
            EMB.Direct(j*10+51,nodes[5],nodes[1],EMB.Linear())
            EMB.Direct(j*10+61,nodes[6],nodes[1],EMB.Linear())
            EMB.Direct(j*10+71,nodes[7],nodes[1],EMB.Linear())
            EMB.Direct(j*10+81,nodes[8],nodes[1],EMB.Linear())
            EMB.Direct(j*10+91,nodes[9],nodes[1],EMB.Linear())
            EMB.Direct(j*10+101,nodes[10],nodes[1],EMB.Linear())
                    ]
    return nodes, links
end


# Generate case data
model_type = InvestmentModel()
case_data = generate_data(model_type)

# Run the optimization as an investment model.
m = run_model(case_data, model_type, HiGHS.Optimizer)

# Uncomment to print all the constraints set in the model.
# print(m)

solution_summary(m)
