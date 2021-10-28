using Geography
const GEO = Geography

#------------- From test in Geography ----------------------------------------------------

import Statistics


# Define the different resources
NG          = ResourceEmit("NG", 0.2)
CO2         = ResourceEmit("CO2", 1.)
Power       = ResourceCarrier("Power", 0.)
Coal        = ResourceCarrier("Coal", 0.35)
products    = [NG, Power, CO2, Coal]
𝒫ᵉᵐ₀        = Dict(k  => FixedProfile(0) for k ∈ products if typeof(k) == ResourceEmit{Float64})

# Create and run the model
model   = IM.InvestmentModel()
m, case = GEO.run_model("", model, GLPK.Optimizer)

# Extract the indiviudal data from the model
𝒯       = case[:T]
𝒯ᴵⁿᵛ    = strategic_periods(𝒯)
𝒩       = case[:nodes]
𝒩ⁿᵒᵗ    = EMB.node_not_av(𝒩)
av      = 𝒩[findall(x -> isa(x, EMB.Availability), 𝒩)]
areas   = case[:areas]
ℒᵗʳᵃⁿˢ  = case[:transmission]
𝒫       = case[:products]

CH4     = 𝒫[1]
Power   = 𝒫[3]
CO2     = 𝒫[4]

# Calculatie the CO2 emissions
emissions_CO2 = [value.(m[:emissions_strategic])[t_inv, CO2] for t_inv ∈ 𝒯ᴵⁿᵛ]

# Flow in to availability nodes in each area
flow_in = Dict(a => [value.(m[:flow_in])[a.An, t, Power] for t ∈ 𝒯] for a ∈ areas)
println("Power generation")
println(flow_in, "\n")

# Flow out from availability nodes in each area
flow_out = [[value.(m[:flow_out])[a.An, t, Power] for t ∈ 𝒯] for a ∈ areas]

trans = Dict()
for l ∈ ℒᵗʳᵃⁿˢ
    for cm ∈ l.Modes
        trans[l, cm.Name] =  [value.(m[:trans_out])[l, t, cm] for t ∈ 𝒯]
    end
end

print("~~~~~~ GEN CAPACITY ~~~~~~ \n")
 for n in (i for i ∈ case[:nodes] if IM.has_investment(i))
    print(n,": ")
    for t in strategic_periods(case[:T])
        print(JuMP.value(m[:cap_current][n,t]),", ")
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
 print("~~~~~~ TRANS CAPACITY ~~~~~~ \n")
 for l in case[:transmission], cm in GEO.corridor_modes(l)
    print(l, " ", cm,": ")
    for t in strategic_periods(case[:T])
        print(JuMP.value(m[:trans_cap_current][l,t,cm]),", ")
    end
    print("\n")
 end

trans_in = Dict()
for l ∈ ℒᵗʳᵃⁿˢ
    for cm ∈ l.Modes
        trans_in[l, cm.Name] =  [value.(m[:trans_in])[l, t, cm] for t ∈ 𝒯]
    end
end

trans_loss = Dict()
for l ∈ ℒᵗʳᵃⁿˢ
    for cm ∈ l.Modes
        trans_loss[l, cm.Name] =  [value.(m[:trans_loss])[l, t, cm] for t ∈ 𝒯]
    end
end

exch = Dict()
for a ∈ areas
    for cm ∈ GEO.exchange_resources(ℒᵗʳᵃⁿˢ, a)
        exch[a, cm] =  [value.(m[:area_exchange])[a, t, cm] for t ∈ 𝒯]
    end
end
println("Exchange")
println(exch)

## Plot map - areas and transmission

function system_map()
    marker = attr(size=20,
                  color=10)
    layout = Layout(geo=attr(scope="europe", resolution=50, fitbounds="locations",
                             showland=true, landcolor="lightgrey", showocean=true, oceancolor="lightblue"),
                    width=500, height=550, margin=attr(l=0, r=0, t=10, b=0))

    nodes = scattergeo(mode="markers", lat=[i.Lat for i in case[:areas]], lon=[i.Lon for i in case[:areas]],
                        marker=marker, name="Areas", text = [i.Name for i in case[:areas]])

    linestyle = attr(line= attr(width = 2.0, dash="dash"))
    lines = []
    for l in case[:transmission]
        line = scattergeo(;mode="lines", lat=[l.From.Lat, l.To.Lat], lon=[l.From.Lon, l.To.Lon],
                        marker=linestyle, width=2.0,  name=join([cm.Name for cm ∈ l.Modes]))
        lines = vcat(lines, [line])
    end
    plot(Array{GenericTrace}(vcat(nodes, lines)), layout)
end

#system_map()

## Plot map with sizing for resource

function resource_map_avg(m, resource, times, lines; line_scale = 10, node_scale = 20)

    layout = Layout(geo=attr(scope="europe", resolution=50, fitbounds="locations",
                            showland=true, landcolor="lightgrey", showocean=true, oceancolor="lightblue"),
                    width=500, height=550, margin=attr(l=0, r=0, t=10, b=0),
                    title=attr(text=resource.id, y=0.9))
    # Production data
    time_values = Dict(a.Name => [value.(m[:flow_in])[a.An, t, 𝒫[3]] for t ∈ 𝒯] for a ∈ areas)
    mean_values = Dict(k => round(Statistics.mean(v), digits=2) for (k, v) in time_values)
    scale = node_scale/maximum(values(mean_values))
    nodes = scattergeo(;lat=[i.Lat for i in case[:areas]], lon=[i.Lon for i in case[:areas]],
                       mode="markers", marker=attr(size=[mean_values[i.Name]*scale for i in data[:areas]], color=10),
                       name="Areas", text = [join([i.Name, ": ", mean_values[i.Name]]) for i in data[:areas]])

    # Transmission data
    trans = Dict()
    for l ∈ lines
        trans[l] = zeros(length(times))
        for cm in l.Modes
            if cm.Resource == resource
                trans[l] += [value.(m[:trans_out])[l, t, cm] for t ∈ times]
            end
        end
    end
    println(trans)
    mean_values = Dict(k=> round(Statistics.mean(v), digits=2) for (k, v) in trans)
    scale = line_scale/maximum(values(mean_values))
    lines = []
    for l in data[:transmission]
        line = scattergeo(;lat=[l.From.Lat, l.To.Lat], lon=[l.From.Lon, l.To.Lon],
                          mode="lines", line = attr(width=mean_values[l]*scale),
                          text =  mean_values[l], name=join([cm.Name for cm ∈ l.Modes]))
        lines = vcat(lines, [line])
    end
    plot(Array{GenericTrace}(vcat(nodes, lines)), layout)

end
#resource_map_avg(m, 𝒫[3], 𝒯, ℒᵗʳᵃⁿˢ)