# EnergyModelsInvestments

[![Build Status](https://github.com/EnergyModelsX/EnergyModelsInvestments.jl/workflows/CI/badge.svg)](https://github.com/EnergyModelsX/EnergyModelsInvestments.jl/actions?query=workflow%3ACI)
[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://energymodelsx.github.io/EnergyModelsInvestments.jl//stable)
[![In Development](https://img.shields.io/badge/docs-dev-blue.svg)](https://energymodelsx.github.io/EnergyModelsInvestments.jl/dev/)

`EnergyModelsInvestments` is a package to investment decisions to models designed using the [`EnergyModelsBase`](https://github.com/EnergyModelsX/EnergyModelsBase.jl) package.
If the package [`EnergyModelsGeography`](https://github.com/EnergyModelsX/EnergyModelsGeography.jl) is loaded, it will also provide investment options to transmission mode.

> **Note:**
>
> We migrated recently from an internal Git solution to GitHub, including the package [`EnergyModelsGeography`](https://github.com/EnergyModelsX/EnergyModelsGeography.jl).
> As `EnergyModelsGeography` is not yet registered, it is not possible to run all tests.
> Hence, we plan to wait with creating a release to be certain that the tests are running.
> As a result, the stable docs are not yet available.
> This may impact as well some links.

## Usage

The usage of the package is based illustrated through the commented [`examples`](examples).
The examples are minimum working examples highlighting how to add investment options to simple energy system models.
This includes as well investments into transmission infrastructure.
All examples are extending the examples in `EnergyModelsBase` and `EnergyModelsGeography`.

## Cite

If you find `EnergyModelsInvestments` useful in your work, we kindly request that you cite the following publication:

```bibtex
@article{boedal_2024,
  title = {Hydrogen for harvesting the potential of offshore wind: A {N}orth {S}ea case study},
  journal = {Applied Energy},
  volume = {357},
  pages = {122484},
  year = {2024},
  issn = {0306-2619},
  doi = {https://doi.org/10.1016/j.apenergy.2023.122484},
  url = {https://www.sciencedirect.com/science/article/pii/S0306261923018482},
  author = {Espen Flo B{\o}dal and Sigmund Eggen Holm and Avinash Subramanian and Goran Durakovic and Dimitri Pinel and Lars Hellemo and Miguel Mu{\~n}oz Ortiz and Brage Rugstad Knudsen and Julian Straus}
}
```

## Funding

The development of `EnergyModelsInvestments` was funded by the Norwegian Research Council in the project [Clean Export](https://www.sintef.no/en/projects/2020/cleanexport/), project number [308811](https://prosjektbanken.forskningsradet.no/project/FORISS/308811)
