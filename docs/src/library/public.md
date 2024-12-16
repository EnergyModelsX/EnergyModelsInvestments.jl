# [Public interface](@id lib-pub)

## [Additional Data for Investments](@id lib-pub-data)

### [General type structure](@id lib-pub-data-abstract)

Additional data for investment is specified when creating the nodes through subtypes of the type `AbstractInvData`.

```@docs
AbstractInvData
```

This additional data is node specific, not technology specific.
It is hence possible to provide different values for the same technology through different instances of said technology.
`EnergyModelsInvestments` provides two subtypes for `AbstractInvData`, `NoStartInvData` and `StartInvData` as explained in the following subsection.

It is also possible to create new subtypes with changing parameters.

!!! warning "Introducing new subtypes"
    If you introduce new subtypes to `AbstractInvData`, it is necessary that you either incorporate the fields outlined in the following subsection with the same names, or alternatively declare methods for the functions [`investment_mode`](@ref), [`EMI.lifetime_mode`](@ref), [`EMI.lifetime`](@ref), [`EMI.max_installed`](@ref), [`EMI.capex`](@ref), and [`EMI.capex_offset`](@ref) for the new type.

### [`AbstractInvData` subtypes](@id lib-pub-data-conc)

`AbstractInvData` subtypes area used to add the required investment data to the individual technology capacities.

The following fields have to be added for all provided types:

- `capex::TimeProfile`: Capital expenditures (CAPEX) of the `Node`. The capital expenditures are relative to the capacity. Hence, it is important to consider the unit for both costs and the energy of the technology. The total contribution to the objective function ``y`` is then given through the equation ``y = \texttt{capex} \times x`` where ``x`` corresponds to the invested capacity.
- `max_inst::TimeProfile`: Maximum installed capacity of the `Node`. The maximum installed capacity is limiting the total installed capacity of the Node. It is possible to have different values for different `Node`s representing the same technology. This can be useful for, *e.g.*, the potential for wind power in different regions.
- `inv_mode::Investment`: Investment mode of the `Node`. The individual investment modes are explained in detail in *[Investment types](@ref lib-pub-inv_mode)*.
- `life_mode::LifetimeMode`: Lifetime mode of the `Node`. The lifetime mode is describing how the lifetime of the node is implemented. This includes as well final values and retiring of the individual technologies. The default value is [`UnlimitedLife`](@ref). More information can be found in *[`LifetimeMode`](@ref lib-pub-life_mode)*.

The type `StartInvData` allows in addition for providing the initial capacity in the first year through:

- `initial::Real`: Starting capacity of the technology in the first investment period. The starting capacity is only valid for the first investment period. This capacity will remain present in the simulation horizon, except if retiring is desired by the model. It is not possible to provide a reducing capacity over time for the initial capacity.

while it utilizes the capacity of the technology if the value is not provided through the function [`EMI.start_cap`](@ref).

!!! warning
    If you do not use `StartInvData`, you have to provide the function [`EMI.start_cap`](@ref) for your type. Otherwise, `EnergyModelsInvestments` is not able to deduce the starting capcity.

`AbstractInvData` types have constructors that allow omitting the last field, `life_mode`.

!!! warning
    All fields that are provided as `TimeProfile` are accessed in strategic periods.
    This implies that the provided `TimeProfile`s are not allowed to have any variations below strategic periods through, *e.g.* the application of `OperationalProfile` or `RepresentativeProfile`.
    `EnergyModelsBase` provides explicit checks for the time profiles which is a beneficial approach if you use `EnergyModelsInvestments` without `EnergyModelsBase`.

```@docs
NoStartInvData
StartInvData
```

### [Additional functions](@id lib-pub-data-func)

`EnergyModelsInvestments` provides additional functions for extracting field informations from the investment data:

```@docs
investment_mode
```

In addition, it provides shell functions that can be used by the user for identifying nodes with investments or extracting the investments from a given element:

```@docs
has_investment
investment_data
```

These shell functions are not directly used by EnergyModelsInvestments, but can be useful.

## [Investment modes](@id lib-pub-inv_mode)

Different investment modes are available to help represent different situations.
The investment mode is included in the field `inv_mode` in [`NoStartInvData`](@ref) and [`StartInvData`](@ref).
The investment mode determines how the model can invest and which constraints are imposed on the investments.

### [Potential fields in investment modes](@id lib-pub-inv_mode-fields)

Investment modes are including the required fields.
These fields are given below with a detailed description in the individual subsections.

- `max_add::TimeProfile`: The maximum added capacity in an investment period.
  The maximum added capacity is providing the limit on how fast we can expend a given technology in a investment period.
  In general, this value is dependent on the potential construction time and how fast it is possible to build a technology.
  It is introduced for `ContinuousInvestment` and `SemiContiInvestment` modes.
- `min_add::TimeProfile`: The minimum added capacity in an investment period.
  The minimum added capacity is providing the lower limit on investments in an investment period.
  Its meaning changes, dependent on the chosen investment mode.
  It is introduced for `ContinuousInvestment` and `SemiContiInvestment` modes.
- `capex_offset::TimeProfile`: CAPEX offset for the [`SemiContinuousOffsetInvestment`](@ref) mode.
  The offset can be best described with the equation ``y = \texttt{capex} \times x + \texttt{capex\_offset}`` where ``x`` corresponds to the invested capacity and ``y`` to the total capital cost.
- `cap_increment::TimeProfile`: Increment in the case of [`DiscreteInvestment`](@ref).
  The increment corresponds to the potential increase in the case of `DiscreteInvestment`.
- `cap::TimeProfile`: Capacity in the case of [`BinaryInvestment`](@ref) and [`FixedInvestment`](@ref).
  The capacity corresponds to the _**additional**_ invested capacity.

### `Investment`

`Investment` is the abstract supertype for all investment modes.
It is used to allow for a simple extension of the potential investment modes.
It is also possible for the user to define new investment modes without major changes to the core structure through specifying a new subtype of `Investment`.

```@docs
Investment
```

### [`ContinuousInvestment`](@id lib-pub-inv_mode-con)

`ContinuousInvestment` is the default investment option for all investments, if no alternative is chosen.
Continuous investments implies that you can invest in any capacity specified between `min_add` and `max_add`.
This implies as well that, if `min_add` is specified, it is necessary to invest in every investment period in at least this capacity.
This approach is the standard approach in large energy system models as it avoids binary variables.
However, it may lead to nonsensical solutions, *e.g.*, investments into a 10~MW nuclear power plant.

!!! warning
    Defining `min_add::TimeProfile` for this mode of investment will lead to a forced investment of at least `min_add` in each period.

```@docs
ContinuousInvestment
```

### [`BinaryInvestment`](@id lib-pub-inv_mode-bin)

[`BinaryInvestment`](@ref) implies that one can choose to invest to achieve the specified capacity in the given investment period, or not.
The capacity of the investment cannot be adjusted by the optimization.

!!! warning
    This investment type leads to the addition of binary variables.
    The number of binary variables is equal to the number of strategic periods times the number of `Node`s with the `BinaryInvestment` mode.

```@docs
BinaryInvestment
```

### [`DiscreteInvestment`](@id lib-pub-inv_mode-disc)

`DiscreteInvestment` allow for only a discrete increase in the capacity.
This increase is specified through the field `increment`.
Hence, it can be also dependent on the investment period.

`DiscreteInvestment` can for example be used to represent investment in modular technologies that can be scaled by adding several modules together.
In addition, it is beneficial to include for technologies that experience significant economy of scale.
In this situation, several instances with different `increment` and `capex` can be used

!!! note
    This investment type leads to the addition of integer variables.
    The number of integer variables is equal to the number of strategic periods times the number of `Node`s with the `DiscreteInvestment` mode.

```@docs
DiscreteInvestment
```

### [`SemiContiInvestment`](@id lib-pub-inv_mode-semi_con)

`SemiContiInvestment` is an abstract type used for two investment modes:

1. `SemiContinuousInvestment` and
2. `SemiContinuousOffsetInvestment`.

These investment modes are similar with respect to how you can increase the capacity.
They differ however on how the overall cost is calculated.
Both investment modes are in general similar to [`ContinuousInvestment`](@ref), but the investment is either 0 or between a minimum and maximum value.
This means you can define the field `min_add::TimeProfile` without forcing investment in the technology.
Instead, the value determines that **_if_** the model decides to invest, then it has to at least invest in the value provided through **`min_add`**.
This can be also described as:

``x = 0 \lor \texttt{min\_add} \leq x \leq \texttt{max\_add}``

with ``x`` corresponding to the invested capacity

```@docs
SemiContiInvestment
```

!!! note
    These investment modes leads to the addition of binary variables.
    The number of binary variables is equal to the number of strategic periods times the number of `Node`s with the `SemiContinuousInvestment` and `SemiContinuousOffsetInvestment` mode.

#### [`SemiContinuousInvestment`](@id lib-pub-inv_mode-semi_con-lin)

The cost function in `SemiContinuousInvestment` is calculated in the same way as in [`ContinuousInvestment`](@ref).
The total contribution of invested capacity ``x`` to the objective function ``y`` is given through the equation

``y = \texttt{capex} \times x``.

```@docs
SemiContinuousInvestment
```

#### [`SemiContinuousOffsetInvestment`](@id lib-pub-inv_mode-semi_con-off)

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

### [`FixedInvestment`](@id lib-pub-inv_mode-fix)

`FixedInvestment` is a type of investment where an investment in the given capacity is forced.
It allows to account for the investment cost of known investments.
In practice, there is however not too much use in including the fixed investment, except if one is interested in the values of the dual variables.

```@docs
FixedInvestment
```

## [`LifetimeMode`](@id lib-pub-life_mode)

`EnergyModelsInvestments` allows for differing descriptions for the lifetime of a technology.
A key problem is when the lifetime of a technology is not equal to the duration of strategic periods.
To this end, several ways to define the lifetime of a technology are available in the package and presented below.

It is also possible for the user to define new `LifetimeMode`s.
In practice, this requires only the introduction of a new subtype to `LifetimeMode` as well as a single function.

```@docs
LifetimeMode
```

!!! warning "Existing capacity and lifetime"
    The current implementation does not provide a lifetime for the existing capacity, independently if you use [`NoStartInvData`](@ref) or [`StartInvData`](@ref).
    This is caused by the background of development of `EnergyModelsInvestments`.
    However, we are aware of this situation and look into potential approaches for including it.
    One such approach is outlined in [Issue 30](https://github.com/EnergyModelsX/EnergyModelsInvestments.jl/issues/30).

### [`UnlimitedLife`](@id lib-pub-life_mode-un)

This `LifetimeMode` is used when the lifetime of a `Node` is not limited.
No reinvestment is considered by the optimization and there is also no salvage value (or rest value) at the end of the last investment period.
Hence, the costs are the same, independent of if the investments in the `Node` are happening in the first investment period (and the technology is used for, *e.g*, 25 years) or the last investment period (with a usage of, *e.g.*, 5 years) when excluding discounting effects.

`UnlimitedLife` is the default lifetime mode, if no other mode is specified.

```@docs
UnlimitedLife
```

### [`StudyLife`](@id lib-pub-life_mode-stud)

`StudyLife` includes the technology for the full investigated horizon.
If the `Lifetime` is shorter than the remaining horizon, reinvestments are considered.
These reinvestments are included in the costs of the investment investment period, but discounted to their actual value.

As an example, consider investments with a lifetime of 20 years in 2030, while the study horizon ends in 2055.
In this situation, reinvestments are required in 2050 to allow for operation in the last 5 years.
The CAPEX are then correspondingly adjusted to account for both discounted reinvestments and final value in 2055.

```@docs
StudyLife
```

### [`PeriodLife`](@id lib-pub-life_mode-per)

`PeriodLife` is used to define that the investment is only lasting for the investment period in which it happens.
Additional year of lifetime are counted as a rest value.
Reinvestment inside the strategic periods are also considered in case the lifetime is shorter than the length of the investment period.

```@docs
PeriodLife
```

### [`RollingLife`](@id lib-pub-life_mode-rol)

`RollingLife` corresponds to the classical roll-over of investments from one investment period to the next until the end of life is reached.
In general, three different cases can be differentiated:

1. The lifetime is shorter than the duration of the investment period. In this situation, a [`PeriodLife`](@ref) is assumed.
2. The lifetime equals the duration of the investment period. In this situation, the capacity is retired at the end of the investment period
3. The lifetime is longer than the duration of the investment period. This leaves however a problem if the lifetime does fall in-between two strategic periods, as it would be the case for a lifetime of, *e.g.*, 8 years and two strategic periods of, *e.g*, 5 years. In this case, the technology would only be available for the first 3 years of the second investment period leaving the question on how to handle this situation. `EnergyModelsInvestments` retires the technology at the last full investment period and calculates the remaining value for the technology.

```@docs
RollingLife
```
