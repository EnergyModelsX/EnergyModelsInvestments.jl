# [Public interface](@id sec_lib_public)

## `InvestmentModel`

This structure defines a new type of Energy Model than the one available from EnergyModelsBase. This new structure is used when investment needs to be part of the analysis.
This struct is a subtype of `AbstractInvestmentModel` which is itself a subtype of `EMB.EnergyModel`.

The structure contains some key information for the model such as the emissions limits and penalties for each `ResourceEmit`.
The discout rate is an important element of investment analysis needed to represent the present value of future cash flows. It is provided to the model as a value between 0 and 1 ( e.g. a discount rate of 5% is 0.05).


## Investment Types

Different investment types are available to help represent different situations. The investment type is defined in `Inv_mode` in [`extra_inv_data`](@ref) and [`extra_inv_data_storage`](@ref). The other fields in those struct are used to define the relevant parameters of the different investment types.

### `BinaryInvestment`

[`BinaryInvestment`](@ref) is a type of investment that can either be installed, or not, at the defined capacity. The capacity of the investment cannot be adjusted by the optimization. 

!!! note
    This investment type leads to the addition of binary variables.


### `DiscreteInvestment`

[`DiscreteInvestment`](@ref) is a type of investment where a technology can be invested in increments of a given size. It can for example be used to represent investment in modular technologies that can be scaled by adding several modules together.
The field `Cap_increment::TimeProfile` from [`extra_inv_data`](@ref), or `Rate_increment::TimeProfile` and `Stor_increment::TimeProfile` from [`extra_inv_data_storage`](@ref) should be provided.

!!! note
    This investment type leads to the addition of integer variables.

### `ContinuousInvestment`
[`ContinuousInvestment`](@ref) is a type of investment where the investment in the capacity happens linearly from 0 and up to a given `Cap_max_inst::TimeProfile`. The rate of installation of the technology can also be limited with `Cap_max_add::TimeProfile`

!!! note
    Defining `Cap_min_add::TimeProfile` for this type of investment will lead to a forced investment of at least `Cap_min_add` in each period.

### `SemiContinuousInvestment`
[`SemiContinuousInvestment`](@ref) is a type of investment similar to [`ContinuousInvestment`](@ref), but where the investment is either 0 or between a minimum and maximum value. This means you can define `Cap_min_add::TimeProfile` without forcing investment in the technology.

!!! note
    This investment type leads to the addition of binary variables.

### `SemiContinuousOffsetInvestment`
[`SemiContinuousOffsetInvestment`](@ref) is a type of investment similar to [`SemiContinuousInvestment`](@ref) and implemented for investments in transmission infrastructure. It does  differ with respect to how the costs are calculated. A `SemiContinuousOffsetInvestment` has an offset in the cost implemented through the the field `Capex_trans_offset`. This offset corresponds to the theoretical cost at an invested capacity of 0.

!!! note
    This investment type leads to the addition of binary variables.


### `FixedInvestment`
[`FixedInvestment`](@ref) is a type of investment where an investment in the given capacity is forced.
It allows to account for the investment cost of known investments.

## `LifetimeMode`
Several ways to define the lifetime of a technology are available in the package and presented below.

### `UnlimitedLife`

This `LifetimeMode` is used when the lifetime of an asset is not limited. No reinvestment is considered by the optimization and there is also ne salvage value (or rest value) in the last period.


### `StudyLife`

This `LifetimeMode` is used to define that the investment should be available for the whole study period. That means that this technology will be reinvested in at the end of its lifetime, and as many times as necessary to reach the end of the study. A rest value is also calculated for the remaining years at the end of the study period.


### `PeriodLife`

This `LifetimeMode` is used to define that the investment is only lasting for the strategic period in which it happens. Additional year of lifetime are counted as a rest value. Reinvestment inside the strategic periods are also considered in case the lifetime is shorter than the length of the startegic period.

### `RollingLife`

This `LifetimeMode` is used to define that the investment rolls over to the next strategic periods as long as the lifetime is not reached. If the remaining lifetime falls between two strategic periods, the investment is not carried to the next period and a rest value is used t oaccount for the remaining lifetime.

## Additional Data for Investments
Additional data for investment is specified when creating the nodes. Two struct are used to define the paramters necessary for production technologies ([`InvData`](@ref)) and storages ([`InvDataStorage`](@ref))

### `InvData`
Define the structure for the additional parameters passed to the technology structures
defined in other packages. It uses `Base.@kwdef` to use keyword arguments and default values.
The name of the parameters have to be specified.

!!!note 
    Depending on the type of investment mode chosen, not all parameters are necessary. It is however possible to set parameters even if they will not be used t obe able to change the investment type more easily.

### `InvDataStorage`
Define the structure for the additional parameters passed to the technology
structures defined in other packages. It uses `Base.@kwdef` to use keyword 
arguments and default values. The name of the parameters have to be specified.
The parameters are separated between Rate and Stor. The Rate refers to 
instantaneous component (Power, Flow, ...) for instance, charging and discharging power
for batteries, while the Stor refers to a volumetric component (Energy, Volume, ...),
for instance storage capacity for a battery.

!!!note 
    Depending on the type of investment mode chosen, not all parameters are necessary. It is however possible to set parameters even if they will not be used t obe able to change the investment type more easily.
### `TransInvData`
Similarly as for [`InvData`](@ref), this struct defines additional parameters necessary for handling the investment in transmission between geographical areas. This struct is used in addition to `EnergyModelsGeography` to add investment in transmission.

## Index

```@index
Pages = ["public.md"]
```

## Types

```@autodocs
Modules = [EnergyModelsInvestments]
Private = false
Order = [:type]
```

## Methods

```@autodocs
Modules = [EnergyModelsInvestments]
Private = false
Order = [:function]
```
