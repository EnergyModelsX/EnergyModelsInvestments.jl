
function run_model(fn, model, optimizer=nothing)
    @debug "Run model" fn optimizer
 
     data = read_data(fn)

     m = EMB.create_model(data, model)
 
     if !isnothing(optimizer)
         set_optimizer(m, optimizer)
         optimize!(m)
         # TODO: print_solution(m) optionally show results summary (perhaps using upcoming JuMP function)
         # TODO: save_solution(m) save results
     else
         @info "No optimizer given"
     end
     return m, data
 end


 function read_data(fn)
    @debug "Read data"
    @info "Hard coded dummy model for now"

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


    nodes = [
            EMB.GenAvailability(1, 𝒫₀, 𝒫₀),
            EMB.RefSink(2, DynamicProfile([20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
                                       20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
                                       20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
                                       20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20]),
                    Dict(:surplus => 0, :deficit => 1e6), Dict(Power => 1), 𝒫ᵉᵐ₀),
            EMB.RefSource(3, FixedProfile(0), FixedProfile(30), FixedProfile(100), Dict(NG => 1), 𝒫ᵉᵐ₀,Dict("InvestmentModels" => extra_inv_data(FixedProfile(1000),FixedProfile(200),30,FixedProfile(200),FixedProfile(0),ContinuousInvestment()))),  
            EMB.RefSource(4, FixedProfile(0), FixedProfile(9), FixedProfile(100), Dict(Coal => 1), 𝒫ᵉᵐ₀,Dict("InvestmentModels" => extra_inv_data(FixedProfile(1000),FixedProfile(200),9,FixedProfile(200),FixedProfile(0),ContinuousInvestment()))),  
            EMB.RefGeneration(5, FixedProfile(0), FixedProfile(5.5), FixedProfile(100), Dict(NG => 2), Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0.9,Dict("InvestmentModels" => extra_inv_data(FixedProfile(600),FixedProfile(25),0,FixedProfile(25),FixedProfile(0),ContinuousInvestment()))),  
            EMB.RefGeneration(6, FixedProfile(0), FixedProfile(6), FixedProfile(100),  Dict(Coal => 2.5), Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0,Dict("InvestmentModels" => extra_inv_data(FixedProfile(800),FixedProfile(25),0,FixedProfile(25),FixedProfile(0),ContinuousInvestment()))),  
            EMB.RefStorage(7, FixedProfile(0), FixedProfile(0), FixedProfile(9.1), FixedProfile(100),  Dict(CO2 => 1, Power => 0.02), Dict(CO2 => 1),Dict("InvestmentModels" => extra_inv_data_storage(FixedProfile(0),FixedProfile(600),0,FixedProfile(600),FixedProfile(0),FixedProfile(500),FixedProfile(600),0,FixedProfile(600),FixedProfile(0),ContinuousInvestment()))),
            EMB.RefGeneration(8, FixedProfile(0), FixedProfile(0), FixedProfile(0),  Dict(Coal => 2.5), Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0,Dict("InvestmentModels" => extra_inv_data(FixedProfile(0),FixedProfile(25),2,FixedProfile(2),FixedProfile(2),ContinuousInvestment()))),  
            EMB.RefStorage(9, FixedProfile(0), FixedProfile(0), FixedProfile(0), FixedProfile(0),  Dict(CO2 => 1, Power => 0.02), Dict(CO2 => 1),Dict("InvestmentModels" => extra_inv_data_storage(FixedProfile(0),FixedProfile(30),3,FixedProfile(3),FixedProfile(3),FixedProfile(0),FixedProfile(50),5,FixedProfile(5),FixedProfile(5),ContinuousInvestment()))),
            EMB.RefGeneration(10, FixedProfile(1000), FixedProfile(0), FixedProfile(0),  Dict(Coal => 2.5), Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0,Dict("InvestmentModels" => extra_inv_data(FixedProfile(10000),FixedProfile(10000),0,FixedProfile(10000),FixedProfile(0),ContinuousInvestment()))),  
            
            ]
    links = [
        EMB.Direct(15,nodes[1],nodes[5],EMB.Linear())
        EMB.Direct(16,nodes[1],nodes[6],EMB.Linear())
        EMB.Direct(17,nodes[1],nodes[7],EMB.Linear())
        EMB.Direct(18,nodes[1],nodes[8],EMB.Linear())
        EMB.Direct(19,nodes[1],nodes[9],EMB.Linear())
        EMB.Direct(110,nodes[1],nodes[10],EMB.Linear())
        EMB.Direct(12,nodes[1],nodes[2],EMB.Linear())
        EMB.Direct(31,nodes[3],nodes[1],EMB.Linear())
        EMB.Direct(41,nodes[4],nodes[1],EMB.Linear())
        EMB.Direct(51,nodes[5],nodes[1],EMB.Linear())
        EMB.Direct(61,nodes[6],nodes[1],EMB.Linear())
        EMB.Direct(71,nodes[7],nodes[1],EMB.Linear())
        EMB.Direct(8,nodes[8],nodes[1],EMB.Linear())
        EMB.Direct(91,nodes[9],nodes[1],EMB.Linear())
        EMB.Direct(101,nodes[10],nodes[1],EMB.Linear())
            ]

    T = UniformTwoLevel(1, 4, 1, UniformTimes(1, 24, 1))
    # WIP data structure
    data = Dict(
                :nodes => nodes,
                :links => links,
                :products => products,
                :T => T,
                )
    return data
end