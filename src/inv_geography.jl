const GEO = Geography

## Datastructures

Base.@kwdef struct TransInvData <: EMB.Data
Capex_trans::TimeProfile
Trans_max_inst::TimeProfile
Trans_max_add::TimeProfile
Trans_min_add::TimeProfile
Inv_mode::Investment = ContinuousInvestment()
Trans_start::Union{Real, Nothing} = nothing
Trans_increment::TimeProfile = FixedProfile(0)
end

## Model
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
    variables_capex_transmission(m, 𝒯, ℒᵗʳᵃⁿˢ, modeltype)

    # Construction of constraints for the problem
    GEO.constraints_area(m, 𝒜, 𝒯, 𝒫, modeltype)
    GEO.constraints_transmission(m, 𝒜, 𝒯, ℒᵗʳᵃⁿˢ, modeltype)

    # Update Objective function
    update_objective(m, 𝒩, 𝒯, 𝒫, ℒᵗʳᵃⁿˢ, modeltype)

    return m
end

function variables_capex_transmission(m, 𝒯, ℒᵗʳᵃⁿˢ, modeltype)

    ℒᵗʳᵃⁿˢᴵⁿᵛ = (i for i ∈ ℒᵗʳᵃⁿˢ if has_trans_investment(i))
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m, capex_trans[l ∈ ℒᵗʳᵃⁿˢᴵⁿᵛ,  𝒯ᴵⁿᵛ, corridor_modes_with_inv(l)]  >= 0)
end

function GEO.variables_transmission(m, 𝒯, ℒᵗʳᵃⁿˢ, ::InvestmentModel)
    @variable(m, trans_in[l ∈ ℒᵗʳᵃⁿˢ,  𝒯, GEO.corridor_modes(l)] >= 0)
    @variable(m, trans_out[l ∈ ℒᵗʳᵃⁿˢ, 𝒯, GEO.corridor_modes(l)] >= 0)
    @variable(m, trans_loss[l ∈ ℒᵗʳᵃⁿˢ, 𝒯, GEO.corridor_modes(l)] >= 0)
    @variable(m, trans_cap[l ∈ ℒᵗʳᵃⁿˢ, 𝒯, GEO.corridor_modes(l)] >= 0)

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m, trans_invest[l ∈ ℒᵗʳᵃⁿˢ, 𝒯ᴵⁿᵛ, GEO.corridor_modes(l)])
    @variable(m, trans_remove[l ∈ ℒᵗʳᵃⁿˢ, 𝒯ᴵⁿᵛ, GEO.corridor_modes(l)])
    @variable(m, trans_capacity[l ∈ ℒᵗʳᵃⁿˢ, 𝒯ᴵⁿᵛ, GEO.corridor_modes(l)] >= 0)        # Installed capacity
    @variable(m, trans_cap_add[l ∈ ℒᵗʳᵃⁿˢ, 𝒯ᴵⁿᵛ, GEO.corridor_modes(l)]  >= 0)        # Add capacity
    @variable(m, trans_cap_rem[l ∈ ℒᵗʳᵃⁿˢ, 𝒯ᴵⁿᵛ, GEO.corridor_modes(l)]  >= 0)        # Remove capacity
end


function GEO.constraints_transmission(m, 𝒜, 𝒯, ℒᵗʳᵃⁿˢ, ::InvestmentModel)

    ℒᵗʳᵃⁿˢᴵⁿᵛ = (i for i ∈ ℒᵗʳᵃⁿˢ if has_trans_investment(i))
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    for l ∈ ℒᵗʳᵃⁿˢᴵⁿᵛ, t_inv ∈ 𝒯ᴵⁿᵛ, cm ∈ corridor_modes_with_inv(l) 
        @constraint(m, m[:capex_trans][l, t_inv, cm] == l.data[get_cm_index(cm,l)]["InvestmentModels"].Capex_trans[t_inv] * m[:trans_cap_add][l, t_inv, cm])
    end

    for l ∈ ℒᵗʳᵃⁿˢᴵⁿᵛ, t_inv ∈ 𝒯ᴵⁿᵛ, cm ∈ corridor_modes_with_inv(l) 
        set_investment_properties(l, cm, m[:trans_invest][l, t_inv,cm])  
    end

    for l ∈ ℒᵗʳᵃⁿˢ, cm ∈ GEO.corridor_modes(l)
        CM_inv = corridor_modes_with_inv(l) 
        if cm ∈ CM_inv
            for t_inv ∈ 𝒯ᴵⁿᵛ
                for t ∈ t_inv
                    @constraint(m, m[:trans_cap][l, t, cm] == m[:trans_capacity][l, t_inv, cm])
                end
            end
        else
            for t in 𝒯
                @constraint(m, m[:trans_cap][l, t, cm] == cm.capacity)
            end
        end
    end

    # Transmission capacity updating
    for l ∈ ℒᵗʳᵃⁿˢᴵⁿᵛ, cm ∈ corridor_modes_with_inv(l)
        for t_inv ∈ 𝒯ᴵⁿᵛ
            start_cap= get_start_cap(cm, t_inv, l.data[get_cm_index(cm, l)]["InvestmentModels"].Trans_start)
            @constraint(m, m[:trans_capacity][l, t_inv, cm] <= l.data[get_cm_index(cm,l)]["InvestmentModels"].Trans_max_inst[t_inv])
            @constraint(m, m[:trans_capacity][l, t_inv, cm] ==
                (TS.isfirst(t_inv) ? start_cap : m[:trans_capacity][l, previous(t_inv,𝒯), cm])
                + m[:trans_cap_add][l, t_inv, cm] 
                - (TS.isfirst(t_inv) ? 0 : m[:trans_cap_rem][l, previous(t_inv,𝒯), cm]))
        end
        set_transcap_installation(m, l, 𝒯ᴵⁿᵛ, cm)
    end

    for a ∈ 𝒜
        ℒᶠʳᵒᵐ, ℒᵗᵒ = GEO.trans_sub(ℒᵗʳᵃⁿˢ, a)
        @constraint(m, [t ∈ 𝒯, p ∈ GEO.export_resources(ℒᵗʳᵃⁿˢ, a)], 
            m[:area_export][a, t, p] == sum(sum(m[:trans_in][l, t, cm] for cm in l.modes if cm.resource == p) for l in ℒᶠʳᵒᵐ))
        @constraint(m, [t ∈ 𝒯, p ∈ GEO.import_resources(ℒᵗʳᵃⁿˢ, a)], 
            m[:area_import][a, t, p] == sum(sum(m[:trans_out][l, t, cm] for cm in l.modes if cm.resource == p) for l in ℒᵗᵒ ))
    end

    for l in ℒᵗʳᵃⁿˢ
        GEO.create_trans(m, 𝒯, l)
    end

end

function get_start_cap(cm::GEO.TransmissionMode, t, ::Nothing)
    if cm.capacity isa Base.Real
        return cm.capacity
    elseif cm.capacity isa TimeStructures.TimeProfile
        return TimeStructures.getindex(cm.capacity,t)
    else 
        print("Type error of cm.capacity")
    end
end

investmentmode(cm::GEO.TransmissionMode,l::GEO.Transmission) = l.data[get_cm_index(cm, l)]["InvestmentModels"].Inv_mode

set_transcap_installation(m, l, 𝒯ᴵⁿᵛ, cm) = set_transcap_installation(m, l, 𝒯ᴵⁿᵛ, cm, investmentmode(cm,l))
function set_transcap_installation(m, l, 𝒯ᴵⁿᵛ, cm, investmentmode)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:trans_cap_add][l, t_inv, cm] <= l.data[get_cm_index(cm, l)]["InvestmentModels"].Trans_max_add[t_inv])
        @constraint(m, m[:trans_cap_add][l, t_inv, cm] >= l.data[get_cm_index(cm, l)]["InvestmentModels"].Trans_min_add[t_inv])
        @constraint(m, m[:trans_cap_rem][l, t_inv, cm] == 0)
    end
end

function set_capacity_installation(m, l, 𝒯ᴵⁿᵛ, cm, ::DiscreteInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:trans_capacity][l, t_inv, cm] == cm.capacity[t_inv] * m[:trans_invest][l, t_inv]) 
    end
end

function set_capacity_installation(m, l, 𝒯ᴵⁿᵛ, cm, ::IntegerInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        set_investment_properties(l, cm, m[:trans_remove][l,t_inv,cm])
        @constraint(m, m[:trans_cap_add][l, t_inv, cm] == l.data[get_cm_index(cm, l)]["InvestmentModels"].Trans_increment[t_inv] * m[:trans_invest][l, t_inv, cm])
        @constraint(m, m[:trans_cap_rem][l, t_inv, cm] == l.data[get_cm_index(cm, l)]["InvestmentModels"].Trans_increment[t_inv] * m[:trans_remove][l, t_inv, cm])
    end
end

function set_capacity_installation(m, l, 𝒯ᴵⁿᵛ, cm, ::SemiContinuousInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:trans_cap_add][l, t_inv, cm] <= l.data[get_cm_index(cm, l)]["InvestmentModels"].Trans_max_add[t_inv] )
        @constraint(m, m[:trans_cap_add][l, t_inv, cm] >= l.data[get_cm_index(cm, l)]["InvestmentModels"].Trans_min_add[t_inv] * m[:trans_invest][l, t_inv, cm]) 
        @constraint(m, m[:trans_cap_rem][l, t_inv, cm] == 0)
    end
end

function set_capacity_installation(m, l, 𝒯ᴵⁿᵛ, cm, ::FixedInvestment)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m, m[:trans_capacity][l, t_inv, cm] == cm.capacity[t_inv] * m[:trans_invest][l, t_inv, cm])
    end
end

set_investment_properties(l::GEO.Transmission, cm::GEO.TransmissionMode, var) = set_investment_properties(l, cm, var, investmentmode(cm, l))
function set_investment_properties(l, cm, var, mode)
    set_lower_bound(var, 0)
end

function set_investment_properties(l, cm, var, ::DiscreteInvestment)
    JuMP.set_binary(var)
end

function set_investment_properties(l, cm, var, ::SemiContinuousInvestment)
    JuMP.set_binary(var)
end
    
function set_investment_properties(l, cm, var, ::IndividualInvestment)
    dispatch_mode = l.data[get_cm_index(cm, l)]["InvestmentModels"].Inv_mode
    set_investment_properties(l, cm, var, dispatch_mode)
end

function set_investment_properties(l, cm, var, ::FixedInvestment) # TO DO
    JuMP.fix(var, 1)
end

function set_investment_properties(l, cm, var, ::IntegerInvestment) # TO DO
    JuMP.set_integer(var)
    JuMP.set_lower_bound(var,0)
end


function update_objective(m, 𝒩, 𝒯, 𝒫, ℒᵗʳᵃⁿˢ, modeltype::InvestmentModel)

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    ℒᵗʳᵃⁿˢᴵⁿᵛ = (i for i ∈ ℒᵗʳᵃⁿˢ if has_trans_investment(i))
    r= modeltype.r

    obj= JuMP.objective_function(m)
    if haskey(m, :capex_trans) && isempty(ℒᵗʳᵃⁿˢᴵⁿᵛ) == false
        for l ∈ ℒᵗʳᵃⁿˢᴵⁿᵛ, t ∈  𝒯ᴵⁿᵛ, cm ∈ corridor_modes_with_inv(l)
            obj += obj_weight_inv(r, 𝒯, t) * m[:capex_trans][l,t,cm] 
        end
    end

    @objective(m, Max, obj)

end

## Utils

function has_trans_investment(i)
    """For a given transmission, checks that it contains extra data (i.data : list containing the extra data of the different corridor modes ) and that 
    at leat one corridor mode has investment data defined.
     """
    isa(i, GEO.Transmission) && 
    (
        hasproperty(i, :data) &&
        #!=(Base.unique(i.data), Dict{"InvestmentModels", EMB.EmptyData()}) &&
        #!=(Base.unique([d for d  in i.data if "InvestmentModels" ∈ keys(d)]), Dict{"InvestmentModels", EMB.EmptyData()}) &&
        !=([d for d in i.data if ("InvestmentModels" ∈ keys(d) && !=(get(d, "InvestmentModels", EMB.EmptyData()), EMB.EmptyData()) )], [])
    )
end

function has_cm_investment(cm,l)
    isa(cm, GEO.TransmissionMode) &&
    isa(l, GEO.Transmission) &&
    cm ∈ l.modes  &&
    (
        hasproperty(l.data[get_cm_index(cm,l)]["InvestmentModels"], :Trans_max_inst) ||
        hasproperty(l.data[get_cm_index(cm,l)]["InvestmentModels"], :Capex_trans) ||
        hasproperty(l.data[get_cm_index(cm,l)]["InvestmentModels"], :Trans_max_add) ||
        hasproperty(l.data[get_cm_index(cm,l)]["InvestmentModels"], :Trans_min_add)
    )
end

function corridor_modes_with_inv(l)
    return [m for m in l.modes if ("InvestmentModels" in keys(l.data[get_cm_index(m,l)])  && !=(l.data[get_cm_index(m,l)]["InvestmentModels"], EMB.EmptyData))]
end

function get_cm_index(cm,l)
    """ Returns the index of the given corridor mode in the defined transmission """
    findfirst(x -> x==cm, l.modes)# we assume that all transmission modes have a different name
end

## User_interface

function GEO.read_data(modeltype::InvestmentModel)
    @debug "Read data"
    @info "Hard coded dummy model for now (Investment Model)"

    𝒫₀, 𝒫ᵉᵐ₀, products = GEO.get_resources()

    #
    area_ids = [1, 2, 3, 4]
    d_scale = Dict(1=>3.0, 2=>1.5, 3=>1.0, 4=>0.5)
    mc_scale = Dict(1=>2.0, 2=>2.0, 3=>1.5, 4=>0.5)


    # Create identical areas with index accoriding to input array
    an = Dict()
    transmission = []
    nodes = []
    links = []
    for a_id in area_ids
        n, l = GEO.get_sub_system_data(a_id, 𝒫₀, 𝒫ᵉᵐ₀, products; mc_scale = mc_scale[a_id], d_scale = d_scale[a_id], modeltype=modeltype)
        append!(nodes, n)
        append!(links, l)

        # Add area node for each subsystem
        an[a_id] = n[1]
    end

    areas = [GEO.Area(1, "Oslo", 10.751, 59.921, an[1]),
            GEO.Area(2, "Bergen", 5.334, 60.389, an[2]),
            GEO.Area(3, "Trondheim", 10.398, 63.4366, an[3]),
            GEO.Area(4, "Tromsø", 18.953, 69.669, an[4])]

    NG = products[2]
    Power = products[3]

    OverheadLine_50MW = GEO.RefStatic("PowerLine_50", Power, 50.0, 0.05)#, EMB.Linear)
    LNG_Ship_100MW = GEO.RefDynamic("LNG_100", NG, 100.0, 0.05)#, EMB.Linear)

    # Create transmission between areas
    transmission = [GEO.Transmission(areas[1], areas[2], [OverheadLine_50MW],[Dict("InvestmentModels"=> TransInvData(Capex_trans=FixedProfile(1000), Trans_max_inst=FixedProfile(50), Trans_max_add=FixedProfile(100), Trans_min_add=FixedProfile(0), Inv_mode=DiscreteInvestment()))]),
                    GEO.Transmission(areas[1], areas[3], [OverheadLine_50MW],[Dict("InvestmentModels"=> TransInvData(Capex_trans=FixedProfile(1000), Trans_max_inst=FixedProfile(100), Trans_max_add=FixedProfile(100), Trans_min_add=FixedProfile(0)))]),
                    GEO.Transmission(areas[2], areas[3], [OverheadLine_50MW],[Dict(""=> EMB.EmptyData())]),
                    GEO.Transmission(areas[3], areas[4], [OverheadLine_50MW],[Dict(""=> EMB.EmptyData())]),
                    GEO.Transmission(areas[4], areas[2], [LNG_Ship_100MW],[Dict(""=> EMB.EmptyData())])]

    T = UniformTwoLevel(1, 4, 1, UniformTimes(1, 24, 1))
    # WIP data structure
    data = Dict(
                :areas => Array{GEO.Area}(areas),
                :transmission => Array{GEO.Transmission}(transmission),
                :nodes => Array{EMB.Node}(nodes),
                :links => Array{EMB.Link}(links),
                :products => products,
                :T => T
                )
    return data
end

function GEO.get_sub_system_data(i,𝒫₀, 𝒫ᵉᵐ₀, products; mc_scale::Float64=1.0, d_scale::Float64=1.0, modeltype::InvestmentModel)
    
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
            EMB.RefSource(j+3, FixedProfile(30), FixedProfile(30*mc_scale), FixedProfile(100), Dict(NG => 1), 𝒫ᵉᵐ₀,Dict("InvestmentModels" => extra_inv_data(capex=FixedProfile(1000),max_inst_cap=FixedProfile(200),max_add=FixedProfile(200),min_add=FixedProfile(10),inv_mode=ContinuousInvestment(), cap_increment=FixedProfile(5), start_cap=15))),  
            EMB.RefSource(j+4, FixedProfile(9), FixedProfile(9*mc_scale), FixedProfile(100), Dict(Coal => 1), 𝒫ᵉᵐ₀,Dict("InvestmentModels" => extra_inv_data(capex=FixedProfile(1000),max_inst_cap=FixedProfile(200),max_add=FixedProfile(200),min_add=FixedProfile(0),inv_mode=ContinuousInvestment()))),  
            EMB.RefGeneration(j+5, FixedProfile(0), FixedProfile(5.5*mc_scale), FixedProfile(100), Dict(NG => 2), Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0.9,Dict("InvestmentModels" => extra_inv_data(capex=FixedProfile(600),max_inst_cap=FixedProfile(25),max_add=FixedProfile(25),min_add=FixedProfile(0),inv_mode=ContinuousInvestment()))),  
            EMB.RefGeneration(j+6, FixedProfile(0), FixedProfile(6*mc_scale), FixedProfile(100),  Dict(Coal => 2.5), Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0,Dict("InvestmentModels" => extra_inv_data(capex=FixedProfile(800),max_inst_cap=FixedProfile(25),max_add=FixedProfile(25),min_add=FixedProfile(0),inv_mode=ContinuousInvestment()))),  
            EMB.RefStorage(j+7, FixedProfile(0), FixedProfile(0), FixedProfile(9.1*mc_scale), FixedProfile(100),  Dict(CO2 => 1, Power => 0.02), Dict(CO2 => 1),Dict("InvestmentModels" => extra_inv_data_storage(capex=FixedProfile(0),max_inst_cap=FixedProfile(600),max_add=FixedProfile(600),min_add=FixedProfile(0),capex_stor=FixedProfile(500),max_inst_stor=FixedProfile(600),max_add_stor=FixedProfile(600),min_add_stor=FixedProfile(0),inv_mode=ContinuousInvestment()))),
            EMB.RefGeneration(j+8, FixedProfile(2), FixedProfile(0*mc_scale), FixedProfile(0),  Dict(Coal => 2.5), Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0,Dict("InvestmentModels" => extra_inv_data(capex=FixedProfile(0),max_inst_cap=FixedProfile(25),max_add=FixedProfile(2),min_add=FixedProfile(2),inv_mode=ContinuousInvestment()))),  
            EMB.RefStorage(j+9, FixedProfile(3), FixedProfile(5), FixedProfile(0*mc_scale), FixedProfile(0),  Dict(CO2 => 1, Power => 0.02), Dict(CO2 => 1),Dict("InvestmentModels" => extra_inv_data_storage(capex=FixedProfile(0),max_inst_cap=FixedProfile(30),max_add=FixedProfile(3),min_add=FixedProfile(3),capex_stor=FixedProfile(0),max_inst_stor=FixedProfile(50),max_add_stor=FixedProfile(5),min_add_stor=FixedProfile(5),inv_mode=ContinuousInvestment()))),
            EMB.RefGeneration(j+10, FixedProfile(0), FixedProfile(0*mc_scale), FixedProfile(0),  Dict(Coal => 2.5), Dict(Power => 1, CO2 => 1), 𝒫ᵉᵐ₀, 0,Dict("InvestmentModels" => extra_inv_data(capex=FixedProfile(10000),max_inst_cap=FixedProfile(10000),max_add=FixedProfile(10000),min_add=FixedProfile(0),inv_mode=ContinuousInvestment()))),  
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