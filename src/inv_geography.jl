const GEO = Geography


function GEO.create_model(data, modeltype::InvestmentModel)
        @debug "Construct model"
    m = EMB.create_model(data, modeltype) # Basic model

    𝒜 = data[:areas]
    ℒᵗʳᵃⁿˢ = data[:transmission]
    𝒫 = data[:products]
    𝒯 = data[:T]
    𝒩 = data[:nodes]
    # Add geo elements

    # Declaration of variables for the problem
    GEO.variables_area(m, 𝒜, 𝒯, 𝒫, modeltype)
    GEO.variables_transmission(m, 𝒯, ℒᵗʳᵃⁿˢ, modeltype)

    # Construction of constraints for the problem
    GEO.constraints_area(m, 𝒜, 𝒯, 𝒫, modeltype)
    GEO.constraints_transmission(m, 𝒜, 𝒯, ℒᵗʳᵃⁿˢ, modeltype)

    return m
end

function GEO.get_sub_system_data(i,𝒫₀, 𝒫ᵉᵐ₀, products; mc_scale, d_scale, modeltype::InvestmentModel)

    NG, Coal, Power, CO2 = products

    demand = [20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
              20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
              20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
              20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20]
    demand *= d_scale

    j=(i-1)*100
    nodes = [
            GEO.GeoAvailability(j+1, 𝒫₀, 𝒫₀),
            EMB.RefSink(j+2, DynamicProfile([20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
                                       20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
                                       20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20;
                                       20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20]),
                    Dict(:surplus => 0, :deficit => 1e6), Dict(Power => 1), 𝒫ᵉᵐ₀),
            EMB.RefSource(j+3, FixedProfile(30), FixedProfile(30*mc_scale), FixedProfile(100), Dict(NG => 1), 𝒫ᵉᵐ₀,Dict("InvestmentModels" => extra_inv_data(FixedProfile(1000),FixedProfile(200),FixedProfile(200),FixedProfile(0),ContinuousInvestment()))),  
            EMB.RefSource(j+4, FixedProfile(9), FixedProfile(9*mc_scale), FixedProfile(100), Dict(Coal => 1), 𝒫ᵉᵐ₀,Dict("InvestmentModels" => extra_inv_data(FixedProfile(1000),FixedProfile(200),FixedProfile(200),FixedProfile(0),ContinuousInvestment()))),  
            EMB.RefGeneration(j+5, FixedProfile(0), FixedProfile(5.5*mc_scale), FixedProfile(100), Dict(NG => 2), Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0.9,Dict("InvestmentModels" => extra_inv_data(FixedProfile(600),FixedProfile(25),FixedProfile(25),FixedProfile(0),ContinuousInvestment()))),  
            EMB.RefGeneration(j+6, FixedProfile(0), FixedProfile(6*mc_scale), FixedProfile(100),  Dict(Coal => 2.5), Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0,Dict("InvestmentModels" => extra_inv_data(FixedProfile(800),FixedProfile(25),FixedProfile(25),FixedProfile(0),ContinuousInvestment()))),  
            EMB.RefStorage(j+7, FixedProfile(0), FixedProfile(0), FixedProfile(9.1*mc_scale), FixedProfile(100),  Dict(CO2 => 1, Power => 0.02), Dict(CO2 => 1),Dict("InvestmentModels" => extra_inv_data_storage(FixedProfile(0),FixedProfile(600),FixedProfile(600),FixedProfile(0),FixedProfile(500),FixedProfile(600),FixedProfile(600),FixedProfile(0),ContinuousInvestment()))),
            EMB.RefGeneration(j+8, FixedProfile(2), FixedProfile(0*mc_scale), FixedProfile(0),  Dict(Coal => 2.5), Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0,Dict("InvestmentModels" => extra_inv_data(FixedProfile(0),FixedProfile(25),FixedProfile(2),FixedProfile(2),ContinuousInvestment()))),  
            EMB.RefStorage(j+9, FixedProfile(3), FixedProfile(5), FixedProfile(0*mc_scale), FixedProfile(0),  Dict(CO2 => 1, Power => 0.02), Dict(CO2 => 1),Dict("InvestmentModels" => extra_inv_data_storage(FixedProfile(0),FixedProfile(30),FixedProfile(3),FixedProfile(3),FixedProfile(0),FixedProfile(50),FixedProfile(5),FixedProfile(5),ContinuousInvestment()))),
            EMB.RefGeneration(j+10, FixedProfile(0), FixedProfile(0*mc_scale), FixedProfile(0),  Dict(Coal => 2.5), Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0,Dict("InvestmentModels" => extra_inv_data(FixedProfile(10000),FixedProfile(10000),FixedProfile(10000),FixedProfile(0),ContinuousInvestment()))),  
                
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