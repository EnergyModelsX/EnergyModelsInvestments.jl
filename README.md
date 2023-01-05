# EnergyModelsInvestments

[![Pipeline: passing](https://gitlab.sintef.no/clean_export/energymodelsinvestments.jl/badges/main/pipeline.svg)](https://gitlab.sintef.no/clean_export/energymodelsinvestments.jl/-/jobs)
[![Docs: stable](https://img.shields.io/badge/docs-stable-4495d1.svg)](https://clean_export.pages.sintef.no/energymodelsinvestments.jl)

<!---[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
--->
`EnergyModelsInvestments` is a package to add continuous or discrete investment decisions to operational models. It is developed primarily to add this functionality to `EnergyModelsBase`.

> **Note**
> This is an internal pre-release not intended for distribution outside the project consortium. 

## Usage

The documentation for `EnergyModelsInvestments` is in development. An example of how to create an investment model is presented below:

```julia
using EnergyModelsBase
using EnergyModelsInvestments
using HiGHS
using JuMP
using PrettyTables
using Test
using TimeStructures

const EMB = EnergyModelsBase
const IM = EnergyModelsInvestments
const TS = TimeStructures

NG = ResourceEmit("NG", 0.2)
CO2 = ResourceEmit("CO2", 1.0)
Power = ResourceCarrier("Power", 0.0)
Coal = ResourceCarrier("Coal", 0.35)
products = [NG, Power, CO2, Coal]
𝒫ᵉᵐ₀ = Dict(k => FixedProfile(0) for k ∈ products if typeof(k) == ResourceEmit{Float64})

function demo_invest(lifemode = IM.UnlimitedLife(); discount_rate = 0.05)
    lifetime = FixedProfile(15)
    sp_dur = 5

    products = [NG, Power, CO2, Coal]
    # Create dictionary with entries of 0. for all resources
    𝒫₀ = Dict(k => 0 for k ∈ products)
    # Create dictionary with entries of 0. for all emission resources
    𝒫ᵉᵐ₀ = Dict(k => 0.0 for k ∈ products if typeof(k) == ResourceEmit{Float64})
    𝒫ᵉᵐ₀[CO2] = 0.0

    investment_data_source = IM.extra_inv_data(
        Capex_Cap = FixedProfile(1000), # capex [€/kW]
        Cap_max_inst = FixedProfile(30), #  max installed capacity [kW]
        Cap_max_add = FixedProfile(30), # max_add [kW]
        Cap_min_add = FixedProfile(0), # min_add [kW]
        Life_mode = lifemode,
        Lifetime = lifetime,
    )

    source = EMB.RefSource(
        "src",
        FixedProfile(0),
        FixedProfile(10),
        FixedProfile(5),
        Dict(Power => 1),
        𝒫ᵉᵐ₀,
        Dict("Investments" => investment_data_source),
    )

    sink = EMB.RefSink(
        "snk",
        FixedProfile(20),
        Dict(:Surplus => FixedProfile(0), :Deficit => FixedProfile(1e6)),
        Dict(Power => 1),
        𝒫ᵉᵐ₀,
    )

    nodes = [EMB.GenAvailability(1, 𝒫₀, 𝒫₀), source, sink]
    links = [
        EMB.Direct(21, nodes[2], nodes[1], EMB.Linear())
        EMB.Direct(13, nodes[1], nodes[3], EMB.Linear())
    ]

    T = UniformTwoLevel(1, 4, sp_dur, UniformTimes(1, 4, 1))
    em_limits =
        Dict(NG => FixedProfile(1e6), CO2 => StrategicFixedProfile([450, 400, 350, 300]))
    em_cost = Dict(NG => FixedProfile(0), CO2 => FixedProfile(0))
    global_data = IM.GlobalData(em_limits, em_cost, discount_rate)

    case = Dict(
        :nodes => nodes,
        :links => links,
        :products => products,
        :T => T,
        :global_data => global_data,
    )

    # Create model and optimize
    model = IM.InvestmentModel()
    m = EMB.create_model(case, model)
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
    set_optimizer(m, optimizer)
    optimize!(m)

    # Display some results
    pretty_table(
        JuMP.Containers.rowtable(
            value,
            m[:cap_add];
            header = [:Source, :StrategicPeriod, :CapInvest],
        ),
    )
end

demo_invest()
```


## Funding

`EnergyModelsInvestments` was funded by the Norwegian Research Council in the project [Clean Export](https://www.sintef.no/en/projects/2020/cleanexport/), project number [308811](https://prosjektbanken.forskningsradet.no/project/FORISS/308811)