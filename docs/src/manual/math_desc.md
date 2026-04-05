# [Mathematical description](@id man-desc)

The package provides some additional constraints to the implementation of the model.
These constraints can be grouped into three distinctive groups,

1. general constraints implemented independently of the investment or lifetime mode,
2. constraints for the allowed capacity changes depending on the chosen investment mode, and
3. constraints for both CAPEX calculation and capacity removal depending on the chosen lifetime mode.

!!! tip "Mathematical notation"
    In the following mathematical equations, we use the name for variables and functions used in the model.
    Variables are in general represented as

    ``\texttt{var\_example}[index_1, index_2]``

    with square brackets, while functions are represented as

    ``func\_example(index_1, index_2)``

    with parantheses.

## [General constraints](@id man-desc-gen)

The general constraints are introduced through the function [`ENI.add_investment_constraints`].
They are not directly affected by the chosen investment or lifetime mode.
All constraints are introduced for each investment period ``t_{inv}``.

For simplification purposes, we assume that `EnergyModelsInvestments` is utilized in `EnergyModelsBase` and that all functions accessing fields of the `inv_data` are accessing the fields of the node `n`.

We first must equal the two introduced capacity variables

```math
\texttt{cap\_inst}[n, t] = \texttt{cap\_current}[n, t_{inv}] \qquad \forall t \in t_{inv}
```

and limit the installed capacity to the maximum allowed capacity

```math
\texttt{cap\_current}[n, t_{inv}] \leq max\_installed(n, t_{inv})
```

An auxiliary expression \texttt{start\_cap}[t_{inv}] is subsequently introduced to identify the specified initial capacity in each investment period, either deduced from the node directly or alternatively from the investment data as explained in the *[public library](@ref lib-pub-data-conc)*.

We have to implement two sets of constraints depending on the investment period.

1. The first investment period ``t_{inv, 1}`` does not include capacity retirements yet as the capacity is retired at the end of an investment period:

   ```math
   \texttt{cap\_current}[n, t_{inv, 1}] = \texttt{start\_cap}[t_{inv, 1}] + \texttt{cap\_add}[n, t_{inv, 1}]
   ```

2. The subsequent investment periods include capacity retirements.
   The following function links the current capacity in investment period ``t_{inv}`` with the previous investment period ``t_{inv,prev}``, the specified capacity changes ``\texttt{start\_cap}[t_{inv}] - \texttt{start\_cap}[t_{inv,prev}]`` as well as the chosen investments and retirements in the model.

   ```math
   \begin{aligned}
   \texttt{cap\_current}[n, t_{inv}] = & \texttt{cap\_current}[n, t_{inv, prev}] \\
     & \texttt{start\_cap}[t_{inv}] - \texttt{start\_cap}[t_{inv,prev}] + \\
     & \texttt{cap\_add}[n, t_{inv}] - \texttt{cap\_rem}[n, t_{inv,prev}]
   \end{aligned}
   ```

   !!! info
       Specified capacity additions are **not** included in the variable ``\texttt{cap\_add}`` while specified capacity removals are neither included in the function ``\texttt{cap\_rem}`` as both are exogeneous.

   The constraint above does however not support early capacity retirements.
   This is achieved through the following constraint

   ```math
   \begin{aligned}
   \texttt{cap\_current}[n, t_{inv}] \leq & \texttt{start\_cap}[t_{inv}] - \texttt{start\_cap}[t_{inv,prev}] + \\
     & \sum_{sp \in life\_dict(sp)} \texttt{cap\_add}[n, sp]
   \end{aligned}
   ```

   The specified ``life\_dict`` represents all capacity additions in previous investment periods whose lifetime has not expired at the end of investment period ``t_{inv}``.
   It is populated through the function [`populate_lifetime_vectors!`](@ref EMI.populate_lifetime_vectors!).
   The exact nature is depending on the chosen *[lifetime mode](@ref lib-pub-life_mode)* and time structure:

   1. If the lifetime mode is a [`PeriodLife`](@ref), it is only including the current investment period.
   2. If the lifetime mode is [`UnlimitedLife`](@ref) or [`StudyLife`](@ref) it includes all investment periods up to the current investment period.
   3. If the lifetime mode is a [`RollingLife`](@ref), it identifies all investment periods whose lifetime has not expired at the end of investment period ``t_{inv}``.
   4. If the time structure is a [`TwoLevelTree`](@extref TimeStruct man-multi-twoleveltree), the individual functions are called for each strategic scenario.

## [Constraints for capacity changes](@id man-desc-cap_change)

Capacity change constraints are incorporated through the function [`set_capacity_installation`](@ref EMI.set_capacity_installation), a function with methods depending on the chosen *[investment mode](@ref lib-pub-inv_mode)*:

- [`Investment`](@ref)s introduce lower and upper bounds:

  ```math
  \begin{aligned}
  \texttt{cap\_add}[n, t_{inv}] & \geq min\_add(n, t_{inv}) \\
  \texttt{cap\_add}[n, t_{inv}] & \leq max\_add(n, t_{inv})
  \end{aligned}`
  ```

- [`BinaryInvestment`](@ref)s introduce discrete capacity values based on the specified investment profiles:

  ```math
  \begin{aligned}
  \texttt{cap\_current}[n, t_{inv}] = & \texttt{start\_cap}[t_{inv}] \\
    & invest\_capacity(n, t_{inv}) \times \texttt{cap\_invest\_b}[n, t_{inv}]
  \end{aligned}
  ```

  It does not directly include bounds on the capacity changes, although the bounds are implicitly introduced.
  The variable ``\texttt{cap\_invest\_b}`` is in this case a binary variable.

- [`DiscreteInvestment`](@ref)s introduce discrete capacity additions and removals:

  ```math
  \begin{aligned}
  \texttt{cap\_add}[n, t_{inv}] & = increment(n, t_{inv}) \times \texttt{cap\_invest\_b}[n, t_{inv}] \\
  \texttt{cap\_rem}[n, t_{inv}] & = increment(n, t_{inv}) \times \texttt{cap\_remove\_b}[n, t_{inv}]
  \end{aligned}
  ```math

  The variables ``\texttt{cap\_invest\_b}`` and ``\texttt{cap\_invest\_b}`` are in this case specified as discrete variable.

- [`SemiContiInvestment`](@ref)s, that is [`SemiContinuousInvestment`](@ref) and [`SemiContinuousOffsetInvestment`](@ref), require that the minimum added capacity is above a specified threshold:

  ```math
  \begin{aligned}
  \texttt{cap\_add}[n, t_{inv}] & \geq min\_add(n, t_{inv}) \times \texttt{cap\_invest\_b}[n, t_{inv}]\\
  \texttt{cap\_add}[n, t_{inv}] & \leq max\_add(n, t_{inv}) \times \texttt{cap\_invest\_b}[n, t_{inv}]
  \end{aligned}
  ```

  The threshold does not apply to capacity removals.

- [`FixedInvestment`](@ref)s introduce discrete capacity values based on the specified investment profiles.
  These are always included contrary to [`BinaryInvestment`](@ref):

  ```math
  \begin{aligned}
  \texttt{cap\_current}[n, t_{inv}] = & \texttt{start\_cap}[t_{inv}] \\
    & invest\_capacity(n, t_{inv}) \times \texttt{cap\_invest\_b}[n, t_{inv}]
  \end{aligned}
  ```

  It does not directly include bounds on the capacity changes, although the bounds are implicitly introduced.
  The variable ``\texttt{cap\_invest\_b}`` is in this case a fixed variable to a value of 1.

## [Constraints for CAPEX and capacity removal](@id man-desc-capex)

CAPEX and capacity removal constraints are incorporated through the function [`set_capacity_cost`](@ref EMI.set_capacity_cost), a function with methods depending on the chosen *[lifetime mode](@ref lib-pub-life_mode)*.

The undiscounted CAPEX value is in the following defined as ``\texttt{capex\_val}[n, t_{inv}]``.
It is calculated through the function [`set_capex_value`](@ref EnergyModelsInvestments.set_capex_value) depending on the chosen investment mode as outlined *[below](@ref man-desc-utils-capex)*.

The discount factor ``capex\_disc`` is calculated for each technology indificually through the function [`set_capex_discounter`](@ref EnergyModelsInvestments.set_capex_discounter).
It supports the calculation of the rest value, but also the required reinvestments, depending on the ratio between the input values `years` and `lifetime`.

The function [`set_capacity_cost`](@ref EMI.set_capacity_cost) has the following methods with their respective constraints:

- [`UnlimitedLife`](@ref):\
  We do not consider any rest value in the case of an unlimited life.
  As a consequence, no discounting is applied on the undiscounted CAPEX value:

  ```math
  \texttt{cap\_capex}[n, t_{inv}] = \texttt{capex\_val}[n, t_{inv}]
  ```

- [`StudyLife`](@ref):\
  Study life requires the calculation of potential reinvestments and the rest value of technology at the end of the study life.
  The `years` argument in the function [`set_capex_discounter`](@ref EnergyModelsInvestments.set_capex_discounter) is given by the remaining years in the model horizon from the current investment period.
  The function is explained *[below](@ref man-desc-utils-disc)* in detail.
  The calculated ``capex\_disc`` is then utilized for modifying the CAPEX variable:

  ```math
  \texttt{cap\_capex}[n, t_{inv}] = \texttt{capex\_val}[n, t_{inv}] \times capex\_disc(t_{inv})
  ```

  In addition, all capacity that required reinvestments and all capacity whose lifetime expires at the end of the model horizon are removed within the model horizon:

  ```math
  \sum_{t_{inv} \in T^{inv}} \texttt{cap\_rem}[n, t_{inv}] = \sum_{t_{inv} \in T^{inv},~capex\_disc(t_{inv}) \geq 1} \texttt{cap\_add}[n, t_{inv}]
  ```

  The removal can occur earlier than the last investment period even if reinvestments are included.

- [`PeriodLife`](@ref):\
  Period life requires the calculation of the discounted rest value for a technology at the end of each investment period.
  The `years` argument in the function [`set_capex_discounter`](@ref EnergyModelsInvestments.set_capex_discounter) is given by the duration of the current investment period.
  The function is explained *[below](@ref man-desc-utils-disc)* in detail.
  The calculated ``capex\_disc`` is then utilized for modifying the CAPEX variable:

  ```math
  \texttt{cap\_capex}[n, t_{inv}] = \texttt{capex\_val}[n, t_{inv}] \times capex\_disc(t_{inv})
  ```

  The capacity must be removed at the end of the current investment period:

  ```math
  \texttt{cap\_rem}[n, t_{inv}] = \texttt{cap\_add}[n, t_{inv}]
  ```

- [`RollingLife`](@ref):\
  Rolling life is slighty more complx compared to the other investment modes.
  In rolling life, we use the lifetime of a technology to identify at which point it must be latest retired.
  This is achieved through the function [`capacity_removal!`](@ref EnergyModelsInvestments.capacity_removal!) in which we calculate both the discount factor and identify in which investment period this capacity must be removed the latest.
  The latter is saved in the ``rem\_dict``, indexed over the `AbstractStratPers` subtype.

  The discount factor ``capex\_disc`` is calculated for all investment periods similar to the approach for [`StudyLife`](@ref) (when there is a remaining lifetime in a subsequent investment period that is short than the duration of the investment period) and [`PeriodLife`](@ref) (when the lifetime is shorter than the duration of a investment period).
  The capacity is furthermore added to the ``rem\_dict`` if it must be removed within the model horizon.

  In the case of strategic scenarios, we calculate the discount factor of an investment period for each strategic scenario in which the investment period is present.
  We subsequently weight the individual discount factors with the probability of the respective strategic scenario.
  Similarly, we create the ``rem\_dict`` for each strategic scenario

  The calculated discount factor is then utilized for modifying the CAPEX variable

  ```math
  \texttt{cap\_capex}[n, t_{inv}] = \texttt{capex\_val}[n, t_{inv}] \times capex\_disc(t_{inv})
  ```

  while the capacity removal dictionary is is introduced in

  ```math
  \sum_{t_{inv} \in T^{inv}} \texttt{cap\_add}[n, t_{inv}] = \sum_{t_{inv} \in rem\_dict[T^{inv}]} \texttt{capex\_rem}[n, t_{inv}] \qquad \forall T^{inv} \in keys(rem\_dict)
  ```

  !!! note "Dictionary for capacity removals"
      The dictionary is only required due to the support for strategic uncertainty through [`TwoLevelTree`](@extref TimeStruct man-multi-twoleveltree) time structures.

## [Utility functions](@id man-desc-utils)

### [Capacity cost calculations](@id man-desc-utils-capex)

The capacity costs in each investment period is calculated through the function [`set_capacity_cost`](@ref EMI.set_capacity_cost).
We currently support two methods:

1. For all [`Investment`](@ref)s if not specified differently:

   ```math
   \texttt{capex\_val}[n, t_{inv}] = capex(n, t_{inv}) \times \texttt{cap\_add}[n, t_{inv}]
   ```

2. For [`SemiContinuousOffsetInvestment`](@ref):

   ```math
   \texttt{capex\_val}[n, t_{inv}] = capex(n, t_{inv}) \times \texttt{cap\_add}[n, t_{inv}] + capex\_offset(n, t_{inv})
   ```

   This approach introduces the offset for capacity cost calculations.

### [Discounter calculations](@id man-desc-utils-disc)

The CAPEX discounter is calculated using the function [`set_capex_discounter`](@ref EnergyModelsInvestments.set_capex_discounter).
The function first calculates the number of investments ``N_{inv}``.
This number also includes reinvestments, if required.
It subsequently utilizes the discount rate ``r``, the lifetime `LT`, and the years `T` to calculate the discount factor as

```math
\begin{aligned}
capex\_disc = & \sum_{n_{inv} \in [0,N_{inv}-1]}\frac{1}{(1+r)^{n_{inv}LT}} - \\
  & \frac{N_{inv}LT-T}{LT(1+r)^T}
\end{aligned}
```

The summation includes required reinvestments in cases where ``N_{inv} > 1`` while it reverts to a value of 1 if ``N_{inv} \leq 1``.
The second term calculates the rest value based on both linear deprecation and discounting.

Reinvestments can be identified by a value larger than 1.
