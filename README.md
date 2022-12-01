# EnergyModelsInvestments

[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

EnergyModelsInvestments is a package to add continuous or discrete investment decisions to operational models. It is developed primarily to add this functionality to EnergyModelsBase.jl.

This package is currently experimental/proof-of-concept and under heavy development. Expect breaking changes.

## Usage

```julia
using EnergyModelsInvestments
EnergyModelsInvestments.run_model("/path/to/input/data")
```

## Discussion points
* model type discrete or continuous investments (or mix?)
* linked by capacity (investment)
* must align discounting
* Operational: all cash flows nominal (undiscounted)


## Funding

EnergyModelsInvestments was funded by the Norwegian Research Council in the project Clean Export, project number [308811](https://prosjektbanken.forskningsradet.no/project/FORISS/308811)