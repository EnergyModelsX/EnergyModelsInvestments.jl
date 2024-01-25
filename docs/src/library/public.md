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

Additional data for investment is specified when creating the nodes through subtypes of the type `InvestmentData`.

```@docs
InvestmentData
```

This additional data is node specific, not technology specific.
It is hence possible to provide different values for the same technology through different instances of said technology.

Two types are used to define the parameters necessary for production technologies ([`InvData`](@ref)) and storages ([`InvDataStorage`](@ref)), while one is used for transmission modes ([`TransInvData`](@ref)) through the `EMIGeoExt` extension.
The different types are required as the required parameters differ.
It is also possible for the user to define new subtypes of `InvestmentData` if they require additional parameters for including investments in technologies.

!!! note
    Depending on the chosen investment mode, not all parameters are necessary.
    It is however possible to set parameters even if they will not be used.
    This allows for a simple change of the investment mode.

    The required parameters will be described in *[Investment Types](@ref sec_types_inv_mode)* for each investment option.
    All `InvestmentData` types use `Base.@kwdef` to simplify the creation of constructors.
    Hence, it is necessary to specify the the name of the parameters when creating instances of the types.

!!! note
    It is planned in a future iteration to revamp how we provide the investment data.
    A key change is related to the approach for `Storage` and `TransmissionMode` investments to reduce repetitions in the functions.

### `InvData`

`InvData` is used to add the required investment data to the individual technology nodes.
It is used for almost all technology nodes, except for `Storage` nodes.

The following fields have to be added as keyword arguments:

- `capex_cap::TimeProfile`: Capital expenditures (CAPEX) of the `Node`. The capital expenditures are relative costs. Hence, it is important to consider the unit for both costs and the energy of the technology. The total contribution to the objective function ``y`` is then given through the equation ``y = \texttt{capex\_cap} \times x`` where ``x`` corresponds to the invested capacity.
- `cap_max_inst::TimeProfile`: Maximum installed capacity of the `Node`. The maximum installed capacity is limiting the total installed capacity of the Node. It is possible to have different values for different `Node`s representing the same technology. This can be useful for, *e.g.*, the potential for wind power in different regions.
- `cap_max_add::TimeProfile`: The maximum added capacity in a strategic period. The maximum added capacity is providing the limit on how fast we can expend a given technology in a strategic period. In general, this value is dependent on the potential construction time and how fast it is possible to build a technology.
- `cap_min_add::TimeProfile`: The minimum added capacity in a strategic period. The minimum added capacity is providing the lower limit on investments in a strategic period. Its meaning changes, dependent on the chosen investment mode, as outlined in *[Investment types](@ref sec_types_inv_mode)*.

In addition, there are also parameters with a default value.
These values do not have to be provided, but can be provided, if desired.
The following parameter can be modified:

- `inv_mode::Investment`: Investment mode of the `Node`. The individual investment modes are explained in detail in *[Investment types](@ref sec_types_inv_mode)*. The default investment mode is [`ContinuousInvestment`](@ref).
- `cap_start::Union{Real, Nothing}`: Starting capacity of the `Node` in the first strategic period. The starting capacity is only valid for the first strategic period. This capacity will remain present in the simulation horizon, except if retiring is desired by the model. It is not possible to provide a reducing capacity over time for the initial capacity. The model extracts alternatively the value of the capacity in the first strategic period, if no value is provided. This is the default value.
- `cap_increment::TimeProfile`: Increment in the case of [`DiscreteInvestment`](@ref). The increment corresponds to the potential increase in the case of DiscreteInvestment. Its usage will be explained further in *[Investment types](@ref sec_types_inv_mode)*. The default value is 0 corresponding to no investment possibility.
- `life_mode::LifetimeMode`: Lifetime mode of the `Node`. The lifetime mode is describing how the lifetime of the node is implemented. This includes as well final values and retiring of the individual technologies. The default value is [`UnlimitedLife`](@ref). More information can be found in *[`LifetimeMode`](@ref life_mode)*.
- `lifetime::TimeProfile`: Lifetime of the `Node`. The lifetime corresponds to the lifetime of the invested `Node`. Its requirement is dependent on the chosen `LifetimeMode`. The default value is 0 corresponding to no lifetime.

!!! warning
    All fields that are provided as `TimeProfile` are accessed in strategic periods.
    This implies that the provided `TimeProfile`s are not allowed to have any variations below strategic periods through, *e.g.* the application of `OperationalProfile` or `RepresentativeProfile`.

```@docs
InvData
```

### `InvDataStorage`

`InvDataStorage` is required as `Storage` nodes behave differently compared to the other nodes.
In `Storage` nodes, it is possible to invest both in the rate for storing energy as well as in the storage capacity, that is the level of a `Storage` node.
Correspondingly, it is necessary to have individual parameters for both the rate and the level.
`Storage` nodes have in general the same fields with a slightly different naming to account for both rate and level investments:

- `capex_cap` is provided for both the rate (`capex_rate`) and the level (`capex_stor`),
- `cap_max_inst` is provided for both the rate (`rate_max_inst`) and the level (`stor_max_inst`),
- `cap_max_add` is provided for both the rate (`rate_max_add`) and the level (`stor_max_add`),
- `cap_min_add` is provided for both the rate (`rate_min_add`) and the level (`stor_min_add`),
- `cap_start` is provided for both the rate (`rate_start`) and the level (`stor_start`), and
- `cap_increment` is provided for both the rate (`rate_increment`) and the level (`stor_increment`).

Both the `Investment` mode and `LifetimeMode` are the same for investments in rate and storage level.
The same holds as well for the lifetime of the technology.

The required fields are the same as in [`InvData`](@ref).

```@docs
InvDataStorage
```

### `TransInvData`

Similarly as for [`InvData`](@ref), this type defines additional parameters necessary for handling the investment in transmission between geographical areas.
This type is used in combination with `EnergyModelsGeography` to add investments in transmission.

There are in general not too many changes compared to [`InvData`](@ref).
The individual fields have however different names:

- `capex_cap` is called `capex_trans`,
- `cap_max_inst` is called `trans_max_inst`,
- `cap_max_add` is called `trans_max_add`,
- `cap_min_add` is called `trans_min_add`,
- `cap_start` is called `trans_start`, and
- `cap_increment` is called `trans_increment`.

In addition, the following field is added:

- `capex_trans_offset::TimeProfile`: The offset is a special parameter only required for the [`SemiContinuousOffsetInvestment`](@ref) mode. The offset can be best described with the equation ``y = \texttt{capex\_trans} \times x + \texttt{capex\_trans\_offset}`` where ``x`` corresponds to the invested capacity and ``y`` to the total capital cost.

```@docs
TransInvData
```

## [Investment modes](@id sec_types_inv_mode)

Different investment modes are available to help represent different situations.
The investment mode is included in the field `inv_mode` in [`InvData`](@ref), [`InvDataStorage`](@ref), and [`TransInvData`](@ref).
The investment mode determines which other parameters are relevant in the investment and how these are treated.

### `Investment`

`Investment` is the abstract supertype for all investment modes.
It is used to allow for a simple extension of the potential investment modes.
It is also possible for the user to define new investment modes without major changes to the core structure through specifying a new subtype of `Investment`.

```@docs
Investment
```

### `ContinuousInvestment`

`ContinuousInvestment` is the default investment option for all investments, if no alternative is chosen.
Continuous investments implies that you can invest in any capacity specified between `cap_min_add` and `cap_max_add`.
This implies as well that, if `cap_min_add` is specified, it is necessary to invest in every strategic period in at least this capacity.
This approach is the standard approach in large energy system models as it avoids binary variables.
However, it can lead to, *e.g.*, investments into a 10~MW nuclear power plant.

Fields without a meaning in `ContinuousInvestment`:

- `cap_increment`
- (`trans_capex_offset` if using [`TransInvData`](@ref))

!!! warning
    Defining `cap_min_add::TimeProfile` for this mode of investment will lead to a forced investment of at least `cap_min_add` in each period.

```@docs
ContinuousInvestment
```

### `BinaryInvestment`

[`BinaryInvestment`](@ref) implies that one can choose to invest in the specified capacity (field `cap` of the node) in the given strategic period, or not.
The capacity of the investment cannot be adjusted by the optimization.
This implies that the meaning of the capacity of a `Node`, `cap`, is redefined.
Hence, it is important to specify `cap_start` to avoid issues in the first strategic period.

Fields without a meaning in `BinaryInvestment`:

- `cap_min_add`
- `cap_max_add`
- `cap_increment`
- (`trans_capex_offset` if using [`TransInvData`](@ref))

!!! warning
    This investment type leads to the addition of binary variables.
    The number of binary variables is equal to the number of strategic periods times the number of `Node`s with the `BinaryInvestment` mode.

```@docs
BinaryInvestment
```

### `DiscreteInvestment`

`DiscreteInvestment` allow for only a discrete increase in the capacity.
This increase is specified through the field `cap_increment`.
Hence, it can be also dependent on the strategic period.

`DiscreteInvestment` can for example be used to represent investment in modular technologies that can be scaled by adding several modules together.
In addition, it is beneficial to include for technologies that experience significant economy of scale.
In this situation, several instances with different `cap_increment` and `capex_cap` can be used

Fields without a meaning in `DiscreteInvestment`:

- `cap_min_add`
- `cap_max_add`
- (`trans_capex_offset` if using [`TransInvData`](@ref))

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
This means you can define the field `cap_min_add::TimeProfile` without forcing investment in the technology.
Instead, the value determines that **_if_** the model decides to invest, then it has to at leas invest in the value provided through **_`cap_min_add`_**.
This can be also described as:

``x = 0 \lor \texttt{cap\_min\_add} \leq x \leq \texttt{cap\_max\_add}``

with ``x`` corresponding to the invested capacity

Fields without a meaning in `SemiContiInvestment`:

- `cap_increment`

```@docs
SemiContiInvestment
```

!!! note
    These investment modes leads to the addition of binary variables.
    The number of binary variables is equal to the number of strategic periods times the number of `Node`s with the `SemiContinuousInvestment` and `SemiContinuousOffsetInvestment` mode.

#### `SemiContinuousInvestment`

The cost function in `SemiContinuousInvestment` is calculated in the same way as in [`ContinuousInvestment`](@ref).
The total contribution of invested capacity ``x`` to the objective function ``y`` is given through the equation

``y = \texttt{capex\_cap} \times x``.

Fields without a meaning in `SemiContinuousInvestment`:

- (`trans_capex_offset` if using [`TransInvData`](@ref))

```@docs
SemiContinuousInvestment
```

#### `SemiContinuousOffsetInvestment`

[`SemiContinuousOffsetInvestment`](@ref) is a type of investment similar to [`SemiContinuousInvestment`](@ref) and implemented for investments in transmission infrastructure.
It does differ with respect to how the costs are calculated.
A `SemiContinuousOffsetInvestment` has an offset in the cost implemented through the the field `Capex_trans_offset`.
This offset corresponds to the theoretical cost at an invested capacity of 0.

While  [`SemiContinuousInvestment`](@ref)utilizes the same relative cost, even if a lower limit is specified, `SemiContinuousOffsetInvestment` allows for the specification of an offset in the cost through the field `trans_capex_offset`.
This offset is an absolute cost.
It corresponds to the theoretical cost at an invested capacity of 0.
This changes the contribution to the cost function from

``y = \texttt{capex\_cap} \times x``

to

``y = \texttt{capex\_trans} \times x + \texttt{capex\_trans\_offset}``

where ``x`` corresponds to the invested capacity and ``y`` to the total capital cost.

`SemiContinuousOffsetInvestment` is currently only implemented for investments in `TransmissionMode`s as its implementation would interact with the lifetime calculations.

```@docs
SemiContinuousOffsetInvestment
```

### `FixedInvestment`

`FixedInvestment` is a type of investment where an investment in the given capacity is forced.
The capacity used is provided through the fields `cap`, `cap_stor`, `cap_rate`, and `trans_cap`.
It allows to account for the investment cost of known investments.
In practice, there is however not too much use in including the fixed investment, except if one is interested in the values of the dual variables.

The fields `cap_min_add`, `cap_max_add`, and `cap_increment` do not have a meaning when using `FixedInvestment`.

Fields without a meaning in `DiscreteInvestment`:

- `cap_min_add`
- `cap_max_add`
- `cap_increment`
- (`trans_capex_offset` if using [`TransInvData`](@ref))

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

The field `Lifetime` does not have a meaning when using `UnlimitedLife`.

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
