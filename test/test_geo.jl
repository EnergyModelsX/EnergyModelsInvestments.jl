using Geography
const GEO = Geography

#------------- From test in Geography ----------------------------------------------------

using DataFrames: Statistics
using Revise
using PlotlyJS, DataFrames, CSV
import Statistics


NG = ResourceEmit("NG", 0.2)
CO2 = ResourceEmit("CO2", 1.)
Power = ResourceCarrier("Power", 0.)
Coal = ResourceCarrier("Coal", 0.35)
products = [NG, Power, CO2, Coal]
𝒫ᵉᵐ₀ = Dict(k  => FixedProfile(0) for k ∈ products if typeof(k) == ResourceEmit{Float64})

r=0.07
case = IM.StrategicCase(StrategicFixedProfile([450, 400, 350, 300]),𝒫ᵉᵐ₀)
model = IM.InvestmentModel(case,r)

m, data = GEO.run_model("", model, GLPK.Optimizer)

𝒯ᴵⁿᵛ = strategic_periods(data[:T])
𝒯 = data[:T]
𝒩 = data[:nodes]
𝒩ⁿᵒᵗ = EMB.node_not_av(𝒩)
av = 𝒩[findall(x -> isa(x, EMB.Availability), 𝒩)]
areas = data[:areas]
ℒᵗʳᵃⁿˢ = data[:transmission]
𝒫 = data[:products]

CH4 = data[:products][1]
CO2 = data[:products][4]

emissions_CO2 = [value.(m[:emissions_strategic])[t_inv, CO2] for t_inv ∈ 𝒯ᴵⁿᵛ]

Power = 𝒫[3]

# Flow in to availability nodes in each area
flow_in = Dict(a => [value.(m[:flow_in])[a.an, t, Power] for t ∈ 𝒯] for a ∈ areas)
println("Power generation")
println(flow_in, "\n")

# Flow out from availability nodes in each area
flow_out = [[value.(m[:flow_out])[a.an, t, Power] for t ∈ 𝒯] for a ∈ areas]

trans = Dict()
for l ∈ ℒᵗʳᵃⁿˢ
    for cm ∈ l.modes
        trans[l, cm.name] =  [value.(m[:trans_out])[l, t, cm] for t ∈ 𝒯]
    end
end
println("Power flow")
println(trans)

print("~~~~~~ CAPACITY ~~~~~~ \n")
 for n in data[:nodes]
    print(n,": ")
    for t in strategic_periods(data[:T])
        print(JuMP.value(m[:capacity][n,t]),", ")
    end
    print("\n")
 end

#trans = Dict((l, cm.name) => [value.(m[:trans_out])[l, t, cm] for t ∈ 𝒯] for l ∈ ℒᵗʳᵃⁿˢ, cm ∈ l.modes)

## Plot map - areas and transmission

function system_map()
    marker = attr(size=20,
                  color=10)
    layout = Layout(geo=attr(scope="europe", resolution=50, fitbounds="locations",
                             showland=true, landcolor="lightgrey", showocean=true, oceancolor="lightblue"),
                    width=500, height=550, margin=attr(l=0, r=0, t=10, b=0))

    nodes = scattergeo(mode="markers", lat=[i.lat for i in data[:areas]], lon=[i.lon for i in data[:areas]],
                        marker=marker, name="Areas", text = [i.name for i in data[:areas]])

    linestyle = attr(line= attr(width = 2.0, dash="dash"))
    lines = []
    for l in data[:transmission]
        line = scattergeo(;mode="lines", lat=[l.from.lat, l.to.lat], lon=[l.from.lon, l.to.lon],
                        marker=linestyle, width=2.0,  name=join([cm.name for cm ∈ l.modes]))
        lines = vcat(lines, [line])
    end
    plot(Array{GenericTrace}(vcat(nodes, lines)), layout)
end

system_map()

## Plot map with sizing for resource

function resource_map_avg(m, resource, times, lines; line_scale = 10, node_scale = 20)

    layout = Layout(geo=attr(scope="europe", resolution=50, fitbounds="locations",
                            showland=true, landcolor="lightgrey", showocean=true, oceancolor="lightblue"),
                    width=500, height=550, margin=attr(l=0, r=0, t=10, b=0),
                    title=attr(text=resource.id, y=0.9))
    # Production data
    time_values = Dict(a.name => [value.(m[:flow_in])[a.an, t, 𝒫[3]] for t ∈ 𝒯] for a ∈ areas)
    mean_values = Dict(k=> round(Statistics.mean(v), digits=2) for (k, v) in time_values)
    scale = node_scale/maximum(values(mean_values))
    nodes = scattergeo(;lat=[i.lat for i in data[:areas]], lon=[i.lon for i in data[:areas]],
                       mode="markers", marker=attr(size=[mean_values[i.name]*scale for i in data[:areas]], color=10),
                       name="Areas", text = [join([i.name, ": ", mean_values[i.name]]) for i in data[:areas]])

    # Transmission data
    trans = Dict()
    for l ∈ lines
        trans[l] = zeros(length(times))
        for cm in l.modes
            if cm.resource == resource
                trans[l] += [value.(m[:trans_out])[l, t, cm] for t ∈ times]
            end
        end
    end
    println(trans)
    mean_values = Dict(k=> round(Statistics.mean(v), digits=2) for (k, v) in trans)
    scale = line_scale/maximum(values(mean_values))
    lines = []
    for l in data[:transmission]
        line = scattergeo(;lat=[l.from.lat, l.to.lat], lon=[l.from.lon, l.to.lon],
                          mode="lines", line = attr(width=mean_values[l]*scale),
                          text =  mean_values[l], name=join([cm.name for cm ∈ l.modes]))
        lines = vcat(lines, [line])
    end
    plot(Array{GenericTrace}(vcat(nodes, lines)), layout)

end
resource_map_avg(m, 𝒫[3], 𝒯, ℒᵗʳᵃⁿˢ)


