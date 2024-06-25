# Philosophy

## General design philosophy

`EnergyModelsInvestments` is a package that calculates the capital expenditures through investments in technologies.
It cannot be used as a stand-alone package, but simplfieis the incorporation of investment options into energy system models.
The user still has to define several functions within their own package, as outlined in *[Use `EnergyModelsInvestments`](@ref sec_how_to_use)*.

The aim in the package development is to provide the user with maximum flexibility on how to incorporate investment decisions.
In the case of investments, the flexibility is required for selecting:

1. the investment mode for a given technology in a given region and
2. the lifetime description for a given technology in a given region.

The model is also compatible with `EnergyModelsGeography` to extend its concept to investment in `TransmissionMode`s.

## Investment modes

Investment modes are different approaches for implementing investments in technologies.
They are explained in detail in *[Investment Types](@ref sec_types_inv_mode)*.
`EnergyModelsInvestments` allows for different investment modes for technologies, both for different technologies, but also for the same technology implemented through different instances.

Different technologies require different descriptions of the investments.
Consider as an example a wind turbine within a model describing a country as single region.
An onshore wind turbine has a maximum capacity of around 6 MW, depending on the available infrastructure for transporting the blades.
If the total investments in wind turbines are in the GW scale, it is possible to model the wind turbines as continuous investments.
A natural gas reforming plant with CCS behaves in this situation differently.
Chemical processes experience in practice significant economy of scales up to a maximum capacity.
Hence, it is in this situation beneficial to use discrete or semi-continuous investments for a natural gas reforming plant.

It can however be also useful to use differing investment modes for the same technology in different regions.
Consider again the wind turbine.
If a second region allows as well for wind turbine investments, however at significantly reduced size, it can be beneficial in this region to apply discrete investments or alternatively, if the region corresponds to an offshore field, semi-continuous investments to account for economy of scales and minimum invested capacities.

Allowing for differing investment modes results in a reduction in the computational demand while simultaneously allowing for improved description of certain technologies.

## Lifetime modes

Lifetime modes can be used for describing how the lifetime of a technology should be handled.
In practice, models either do not consider the lifetime, include annualized costs for each year, or use the total costs with a potential final value, if the technology still has a remaining lifetime at the end of the optimizaztion horizon.
`EnergyModelsInvestments` allows to choose as well differing lifetime modes for the individual technologies.

## As extension to `EnergyModelsBase`

An example on the application of `EnergyModelsInvestments` is given by the `EMIEXt` in `EnergyModelsBase` which provide the operational model with the potential for investments.
The extension is achieved through providing a new `InvestmentModel` which is subsequently used for dispatching on several core functions within `EnergyModelsBase`.
Hence, its application does not require any changes to the model itself.
This corresponds to the 3ʳᵈ bullet point in the list of *[Extensions to the model](https://energymodelsx.github.io/EnergyModelsBase.jl/stable/manual/philosophy/#sec_phil_ext)*.

Specifically, the extensions provides three new functions to `EnergyModelsBase`:

1. a new calculation of the objective function including the capital expenses,
2. a new method for the CAPEX variables which creates the required variables, and
3. a new method for provding the bounds on the installed capacities.
