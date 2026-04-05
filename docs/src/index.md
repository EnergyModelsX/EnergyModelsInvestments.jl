# EnergyModelsInvestments

This Julia package provides the mathematical description of different investment options for energy system models.
Initially, it was an extension package to the operational, multi carrier energy model [`EnergyModelsBase`](https://energymodelsx.github.io/EnergyModelsBase.jl/) with an additional extension for geographical investments if [`EnergyModelsGeography`](https://energymodelsx.github.io/EnergyModelsGeography.jl/) was used.

However, since Version 0.7, `EnergyModelsInvestments` can be used independently from [`EnergyModelsBase`](https://energymodelsx.github.io/EnergyModelsBase.jl/) to provide different investment options to existing energy system models written in [`JuMP`](https://jump.dev/JuMP.jl/stable/).
In this case, `EnergyModelsInvestments` provides a mathematical formulation for both different investement modes (*e.g.*, discrete investments or semi-continuous investments) and lifetime modes (*e.g.*, for the whole study period or only for a limitid number of years).
A detailed description on how you can use `EnergyModelsInvestments` can be found in *[Use `EnergyModelsInvestments`](@ref how_to-use_emi)*.

`EnergyModelsInvestments` is designed to be an extensible package that can work with multiple different energy system model.
In addition, it is designed for maximum flexibility and the potential to introduce new investment and lifetime modes without modifications to the core structure.

## Manual outline

```@contents
Pages = [
    "manual/quick-start.md",
    "manual/philosophy.md",
    "manual/optimization-variables.md",
    "manual/math_desc.md",
    "manual/simple-example.md",
    "manual/NEWS.md",
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
