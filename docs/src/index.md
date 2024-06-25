# EnergyModelsInvestments

This Julia package provides the description of different investment options for energy system models.
Initially, it was an extension package to the operational, multi carrier energy model [`EnergyModelsBase`](https://energymodelsx.github.io/EnergyModelsBase.jl/) with an additional extension for geographical investments if [`EnergyModelsGeography`](https://energymodelsx.github.io/EnergyModelsGeography.jl/) was used.

However, since Version 0.7, `EnergyModelsInvestments` can be used independently from [`EnergyModelsBase`](https://energymodelsx.github.io/EnergyModelsBase.jl/) to provide different investment options to existing energy system models written in [`JuMP`](https://jump.dev/JuMP.jl/stable/).
In this case, `EnergyModelsInvestments` provides a mathematical formulation for both different investement modes (_e.g._, discrete investments or semi-continuous investments) and lifetime modes (_e.g._, for the whole study period or only for a limitid number of years).
A detailed description on how you can use `EnergyModelsInvestments` can be found in *[Use `EnergyModelsInvestments`](@ref sec_how_to_use)*.

!!! info
    The documentation is currently in the transition from the case in which `EnergyModelsInvestments` was an extension of `EnergyModelsBase`.
    Hence, we do not provide as many links to the individual types and how to apply `EnergyModelsInvestments` as we plan for in the near future.

```@docs
EnergyModelsInvestments
```

`EnergyModelsInvestments` follows the same philosophy with respect to extendibility as `EnergyModelsBase`.
Its aim is to allow the user to come up with new ideas to include investments without major changes to the core structure.

## Manual outline

```@contents
Pages = [
    "manual/quick-start.md",
    "manual/philosophy.md",
    "manual/optimization-variables.md",
    "manual/simple-example.md",
]
Depth = 1
```

## How to guides

```@contents
Pages = [
    "how-to/update-models.md",
    "how-to/use-emi.md",
    "how-to/contribute.md",
]
Depth = 1
```

## Library outline

```@contents
Pages = [
    "library/public.md",
    "library/internals.md"
]
Depth = 1
```
