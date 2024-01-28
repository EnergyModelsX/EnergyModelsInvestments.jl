# EnergyModelsInvestments.jl

This Julia package provides investment options for the operational, multi carrier energy model [`EnergyModelsBase`](https://energymodelsx.github.io/EnergyModelsBase.jl/).
It furthermore adds investment options for the transmission modes introduced in [`EnergyModelsGeography`](https://energymodelsx.github.io/EnergyModelsGeography.jl/), if the package is loaded.

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
```

## Library outline

```@contents
Pages = [
    "library/public.md",
    "library/internals.md"
]
```
