# [Public interface](@id sec_lib_public)

## `InvestmentModel`

An `AbstractInvestmentModel` is a subtype of an `EnergyModel` as declared in `EnergyModelsBase`
This new type allows for the introduction of investment options to the energy system model.

The composite type `InvestmentModel` contains some key information for the model such as the emissions limits and penalties for each `ResourceEmit`, as well as the `ResourceEmit` instance of CO₂.
It uses hence the same fields as an `OperationalModel` as declared in `EnergyModelsBase`.
In addition, it takes as input the `discount_rate`.
The `discount_rate` is an important element of investment analysis needed to represent the present value of future cash flows.
It is provided to the model as a value between 0 and 1 (*e.g.* a discount rate of 5 % is 0.05).

```@docs
AbstractInvestmentModel
InvestmentModel
```

## Additional Data for Investments

Additional data for investment is specified when creating the nodes through subtypes of the type `InvestmentData` and `GeneralInvData`.
`GeneralInvData` is introduced in this version to allow for making `EnergyModelsInvestments` independent of `EnergyModelsBase`, although this is not yet implemented in the model.

```@docs
InvestmentData
GeneralInvData
```

This additional data is node specific, not technology specific.
It is hence possible to provide different values for the same technology through different instances of said technology.

Two types are used to define the parameters necessary for production technologies and transmission modes ([`SingleInvData`](@ref)) and storages ([`StorageInvData`](@ref)).
The different types are required as the required parameters differ.
It is also possible for the user to define new subtypes of `InvestmentData` if they require additional parameters for including investments in capacities of technologies.

### `GeneralInvData` subtypes

`GeneralInvData` is used to add the required investment data to the individual technology capacities.
The subtypes of `GeneralInvData` are used for all technologies, that is nodes and transmission modes.

The following fields have to be added for all provided types:

- `capex::TimeProfile`: Capital expenditures (CAPEX) of the `Node`. The capital expenditures are relative costs. Hence, it is important to consider the unit for both costs and the energy of the technology. The total contribution to the objective function ``y`` is then given through the equation ``y = \texttt{capex} \times x`` where ``x`` corresponds to the invested capacity.
- `max_inst::TimeProfile`: Maximum installed capacity of the `Node`. The maximum installed capacity is limiting the total installed capacity of the Node. It is possible to have different values for different `Node`s representing the same technology. This can be useful for, *e.g.*, the potential for wind power in different regions.
- `inv_mode::Investment`: Investment mode of the `Node`. The individual investment modes are explained in detail in *[Investment types](@ref sec_types_inv_mode)*.
- `life_mode::LifetimeMode`: Lifetime mode of the `Node`. The lifetime mode is describing how the lifetime of the node is implemented. This includes as well final values and retiring of the individual technologies. The default value is [`UnlimitedLife`](@ref). More information can be found in *[`LifetimeMode`](@ref life_mode)*.

The type `StartInvData` allows in addition for providing the initial capacity in the first year through:

- `initial::Real`: Starting capacity of the technology in the first strategic period. The starting capacity is only valid for the first strategic period. This capacity will remain present in the simulation horizon, except if retiring is desired by the model. It is not possible to provide a reducing capacity over time for the initial capacity.

while it utilizes the capacity of the technology if the value is not provided through the function [`EMI.start_cap`](@ref).

!!! warning
    If you do not use `StartInvData`, you have to provide the function [`EMI.start_cap`](@ref) for your type. Otherwise, `EnergyModelsInvestments` is not able to deduce the starting capcity.

`GeneralInvData` types have constructors that allow ommitting the last field, `life_mode`.

!!! warning
    All fields that are provided as `TimeProfile` are accessed in strategic periods.
    This implies that the provided `TimeProfile`s are not allowed to have any variations below strategic periods through, *e.g.* the application of `OperationalProfile` or `RepresentativeProfile`.

```@docs
NoStartInvData
StartInvData
```

### `InvestmentData` subtypes

`InvestmentData` subtypes are used to provide technologies introduced in `EnergyModelsX` (nodes and transmission modes) a subtype of `Data` that can be used for dispatching.
Two different types are directly introduced, `SingleInvData` and `StorageInvData`.

`SingleInvData` is providing a composite type with a single field.
It is used for investments in technologies with a single capacity, that is all nodes except for storage nodes as well as tranmission modes.

`StorageInvData` is required as `Storage` nodes behave differently compared to the other nodes.
In `Storage` nodes, it is possible to invest both in the charge capacity for storing energy, the storage capacity, that is the level of a `Storage` node, as well as the discharge capacity, that is how fast energy can be withdrawn.
Correspondingly, it is necessary to have individual parameters for the potential investments in each capacity, that is through the fields `:charge`, `:level`, and `:discharge`.

```@docs
SingleInvData
StorageInvData
```

### Legacy constructors

We provide a legacy constructor, `InvData`, `InvDataStorage`, and `InvDataTrans`, that use the same input as in version 0.5.x.
If you want to adjust your model to the latest changes, please refer to the section *[Update your model to the latest version](@ref sec_how_to_update)*.

```@docs
InvData
InvDataStorage
TransInvData
```

## [Investment modes](@id sec_types_inv_mode)

Different investment modes are available to help represent different situations.
The investment mode is included in the field `inv_mode` in [`NoStartInvData`](@ref) and [`StartInvData`](@ref).
The investment mode how the model can invest and which constraints are imposed on the investments.

### Potential fields in investment modes

Investment modes are including the required fields for the investments.
These fields are given below with a detailed description in the individual subsections.

- `max_add::TimeProfile`: The maximum added capacity in a strategic period.
  The maximum added capacity is providing the limit on how fast we can expend a given technology in a strategic period.
  In general, this value is dependent on the potential construction time and how fast it is possible to build a technology.
  It is introduced for `ContinuousInvestment` and `SemiContiInvestment` modes.
- `min_add::TimeProfile`: The minimum added capacity in a strategic period.
  The minimum added capacity is providing the lower limit on investments in a strategic period.
  Its meaning changes, dependent on the chosen investment mode.
  It is introduced for `ContinuousInvestment` and `SemiContiInvestment` modes.
- `capex_offset::TimeProfile`: CAPEX offset for the [`SemiContinuousOffsetInvestment`](@ref) mode.
  The offset can be best described with the equation ``y = \texttt{capex} \times x + \texttt{capex\_offset}`` where ``x`` corresponds to the invested capacity and ``y`` to the total capital cost.
- `cap_increment::TimeProfile`: Increment in the case of [`DiscreteInvestment`](@ref).
  The increment corresponds to the potential increase in the case of `DiscreteInvestment`.

### `Investment`

`Investment` is the abstract supertype for all investment modes.
It is used to allow for a simple extension of the potential investment modes.
It is also possible for the user to define new investment modes without major changes to the core structure through specifying a new subtype of `Investment`.

```@docs
Investment
```

### `ContinuousInvestment`

`ContinuousInvestment` is the default investment option for all investments, if no alternative is chosen.
Continuous investments implies that you can invest in any capacity specified between `min_add` and `max_add`.
This implies as well that, if `min_add` is specified, it is necessary to invest in every strategic period in at least this capacity.
This approach is the standard approach in large energy system models as it avoids binary variables.
However, it can lead to, *e.g.*, investments into a 10~MW nuclear power plant.

!!! warning
    Defining `min_add::TimeProfile` for this mode of investment will lead to a forced investment of at least `min_add` in each period.

```@docs
ContinuousInvestment
```

### `BinaryInvestment`

[`BinaryInvestment`](@ref) implies that one can choose to invest to avhieve the specified capacity in the given strategic period, or not.
The capacity of the investment cannot be adjusted by the optimization.

!!! warning
    This investment type leads to the addition of binary variables.
    The number of binary variables is equal to the number of strategic periods times the number of `Node`s with the `BinaryInvestment` mode.

```@docs
BinaryInvestment
```

### `DiscreteInvestment`

`DiscreteInvestment` allow for only a discrete increase in the capacity.
This increase is specified through the field `increment`.
Hence, it can be also dependent on the strategic period.

`DiscreteInvestment` can for example be used to represent investment in modular technologies that can be scaled by adding several modules together.
In addition, it is beneficial to include for technologies that experience significant economy of scale.
In this situation, several instances with different `increment` and `capex` can be used

!!! note
    This investment type leads to the addition of integer variables.
    The number of integer variables is equal to the number of strategic periods times the number of `Node`s with the `DiscreteInvestment` mode.

```@docs
DiscreteInvestment
```

### `SemiContiInvestment`

`SemiContiInvestment` is an abstract type used for two investment modes:

1. `SemiContinuousInvestment` and
2. `SemiContinuousOffsetInvestment`.

These investment modes are similar with respect to how you can increase the capacity.
They differ however on how the overall cost is calculated.
Both investment modes are in general similar to [`ContinuousInvestment`](@ref), but the investment is either 0 or between a minimum and maximum value.
This means you can define the field `min_add::TimeProfile` without forcing investment in the technology.
Instead, the value determines that **_if_** the model decides to invest, then it has to at leas invest in the value provided through **_`min_add`_**.
This can be also described as:

``x = 0 \lor \texttt{_min\_add} \leq x \leq \texttt{max\_add}``

with ``x`` corresponding to the invested capacity

```@docs
SemiContiInvestment
```

!!! note
    These investment modes leads to the addition of binary variables.
    The number of binary variables is equal to the number of strategic periods times the number of `Node`s with the `SemiContinuousInvestment` and `SemiContinuousOffsetInvestment` mode.

#### `SemiContinuousInvestment`

The cost function in `SemiContinuousInvestment` is calculated in the same way as in [`ContinuousInvestment`](@ref).
The total contribution of invested capacity ``x`` to the objective function ``y`` is given through the equation

``y = \texttt{capex} \times x``.

```@docs
SemiContinuousInvestment
```

#### `SemiContinuousOffsetInvestment`

[`SemiContinuousOffsetInvestment`](@ref) is a type of investment similar to [`SemiContinuousInvestment`](@ref) and implemented for investments in transmission infrastructure.
It does differ with respect to how the costs are calculated.
A `SemiContinuousOffsetInvestment` has an offset in the cost implemented through the the field `capex_offset`.
This offset corresponds to the theoretical cost at an invested capacity of 0.

While  [`SemiContinuousInvestment`](@ref)utilizes the same relative cost, even if a lower limit is specified, `SemiContinuousOffsetInvestment` allows for the specification of an offset in the cost through the field `capex_offset`.
This offset is an absolute cost.
It corresponds to the theoretical cost at an invested capacity of 0.
This changes the contribution to the cost function from

``y = \texttt{capex} \times x``

to

``y = \texttt{capex} \times x + \texttt{capex\_offset}``

where ``x`` corresponds to the invested capacity and ``y`` to the total capital cost.

```@docs
SemiContinuousOffsetInvestment
```

### `FixedInvestment`

`FixedInvestment` is a type of investment where an investment in the given capacity is forced.
It allows to account for the investment cost of known investments.
In practice, there is however not too much use in including the fixed investment, except if one is interested in the values of the dual variables.

The fields `cap_min_add`, `cap_max_add`, and `cap_increment` do not have a meaning when using `FixedInvestment`.

```@docs
FixedInvestment
```

## [`LifetimeMode`](@id life_mode)

`EnergyModelsInvestments` allows for differing descriptions for the lifetime of a technology.
A key problem is when the lifetime of a technology is not equal to the duration of strategic periods.
To this end, several ways to define the lifetime of a technology are available in the package and presented below.

It is also possible for the user to define new `LifetimeMode`s.
In practice, this requires only the introduction of a new subtype to `LifetimeMode` as well as a single function.

```@docs
LifetimeMode
```

### `UnlimitedLife`

This `LifetimeMode` is used when the lifetime of a `Node` is not limited.
No reinvestment is considered by the optimization and there is also ne salvage value (or rest value) at the end of the last strategic period.
Hence, the costs are the same, independent of if the investments in the `Node` are happening in the first strategic period (and the technology is used for, *e.g*, 25 years) or the last strategic period (with a usage of, *e.g.*, 5 years) when excluding discounting effects.

`UnlimitedLife` is the default lifetime mode, if no other mode is specified.

```@docs
UnlimitedLife
```

### `StudyLife`

`StudyLife` includes the technology for the full investigated horizon.
If the `Lifetime` is shorter than the remaining horizon, reinvestments are considered.
These reinvestments are included in the costs of the investment strategic period, but discounted to their actual value.

As an example, consider investments with a lifetime of 20 years in 2030, while the study horizon ends in 2055.
In this situation, reinvestments are required in 2050 to allow for operation in the last 5 years.
The CAPEX are then correspondingly adjusted to account for both discounted reinvestments and final value in 2055.

```@docs
StudyLife
```

### `PeriodLife`

`PeriodLife` is used to define that the investment is only lasting for the strategic period in which it happens.
Additional year of lifetime are counted as a rest value.
Reinvestment inside the strategic periods are also considered in case the lifetime is shorter than the length of the strategic period.

```@docs
PeriodLife
```

### `RollingLife`

`RollingLife` corresponds to the classical roll-over of investments from one strategic period to the next until the end of life is reached.
In general, three different cases can be differentiated:

1. The lifetime is shorter than the duration of the strategic period. In this situation, a [`PeriodLife`](@ref) is assumed.
2. The lifetime equals the duration of the strategic period. In this situation, the capacity is retired at the end of the strategic period
3. The lifetime is longer than the duration of the strategic period. This leaves however a problem if the lifetime does fall in-between two strategic periods, as it would be the case for a lifetime of, *e.g.*, 8 years and two strategic periods of, *e.g*, 5 years. In this case, the technology would only be available for the first 3 years of the second strategic period leaving the question on how to handle this situation. `EnergyModelsInvestments` retires the technology at the last full strategic period and calculates the remaining value for the technology.

```@docs
RollingLife
```
