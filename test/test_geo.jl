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
 for n in (i for i ∈ data[:nodes] if IM.has_investment(i))
    print(n,": ")
    for t in strategic_periods(data[:T])
        print(JuMP.value(m[:cap_current][n,t]),", ")
    end
    print("\n")
 end

 print("~~~~~~ STOR CAPACITY ~~~~~~ \n")
 for n in (i for i ∈ data[:nodes] if IM.has_storage_investment(i))
    print(n,": ")
    for t in strategic_periods(data[:T])
        print(JuMP.value(m[:stor_cap_current][n,t]),", ", JuMP.value(m[:stor_rate_current][n,t]),", ")
    end
    print("\n")
 end
 print("~~~~~~ TRANS CAPACITY ~~~~~~ \n")
 for l in data[:transmission], cm in GEO.corridor_modes(l)
    print(l, " ", cm,": ")
    for t in strategic_periods(data[:T])
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

trace=[]
for (k, v) in trans
    global trace
    print(string(k[1]))
    tr = scatter(; y=v, mode="lines", name=join([string(k[1]), "<br>", k[2], " transmission"]))
    trace = vcat(trace, tr)
    tr = scatter(; y=trans_loss[k], mode="lines", name=join([string(k[1]), "<br>", k[2], " loss"]))
    trace = vcat(trace, tr)
end
plot(Array{GenericTrace}(trace))

trace=[]
k = collect(keys(trans))[1]
tr = scatter(; y=trans[k], mode="lines", name=join([string(k[1]), "<br>", k[2], " trans out"]))
trace = vcat(trace, tr)
tr = scatter(; y=trans_in[k], mode="lines", name=join([string(k[1]), "<br>", k[2], " trans in"]))
trace = vcat(trace, tr)
tr = scatter(; y=trans_loss[k], mode="lines", name=join([string(k[1]), "<br>", k[2], " loss"]))
trace = vcat(trace, tr)
plot(Array{GenericTrace}(trace))

exch = Dict()
for a ∈ areas
    for cm ∈ GEO.exchange_resources(ℒᵗʳᵃⁿˢ, a)
        exch[a, cm] =  [value.(m[:area_exchange])[a, t, cm] for t ∈ 𝒯]
    end
end
println("Exchange")
println(exch)

#trans = Dict((l, cm.Name) => [value.(m[:trans_out])[l, t, cm] for t ∈ 𝒯] for l ∈ ℒᵗʳᵃⁿˢ, cm ∈ l.Modes)

## Plot map - areas and transmission

function system_map()
    marker = attr(size=20,
                  color=10)
    layout = Layout(geo=attr(scope="europe", resolution=50, fitbounds="locations",
                             showland=true, landcolor="lightgrey", showocean=true, oceancolor="lightblue"),
                    width=500, height=550, margin=attr(l=0, r=0, t=10, b=0))

    nodes = scattergeo(mode="markers", lat=[i.Lat for i in data[:areas]], lon=[i.Lon for i in data[:areas]],
                        marker=marker, name="Areas", text = [i.Name for i in data[:areas]])

    linestyle = attr(line= attr(width = 2.0, dash="dash"))
    lines = []
    for l in data[:transmission]
        line = scattergeo(;mode="lines", lat=[l.From.Lat, l.To.Lat], lon=[l.From.Lon, l.To.Lon],
                        marker=linestyle, width=2.0,  name=join([cm.Name for cm ∈ l.Modes]))
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
    time_values = Dict(a.Name => [value.(m[:flow_in])[a.An, t, 𝒫[3]] for t ∈ 𝒯] for a ∈ areas)
    mean_values = Dict(k => round(Statistics.mean(v), digits=2) for (k, v) in time_values)
    scale = node_scale/maximum(values(mean_values))
    nodes = scattergeo(;lat=[i.Lat for i in data[:areas]], lon=[i.Lon for i in data[:areas]],
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
resource_map_avg(m, 𝒫[3], 𝒯, ℒᵗʳᵃⁿˢ)