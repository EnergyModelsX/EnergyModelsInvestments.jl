# [Relationships between investments](@id man-rel)

The additional constraints from the package do not allow for relationships between individual investments.
However, it can sometimes be beneficial to model relationships between individual technologies, *e.g.*, for modelling a maximum budget for investments in a set of technologies or couplings between different technology investments.
To this end, `EnergyModelsInvestments` provides the user with several functions which must be called **after** the creation of the `JuMP` model instance.

If not stated differently, the constraints are added for all investment periods, *i.e.*,  ``\forall t_{inv} \in T^{Inv}``.

```@index
Pages = ["relations.md"]
```

## [Maximum budget](@id man-rel-max_budget)

The function [`max_budget`](@ref) can be utilized to provide a maximum budget for investments in a given set of technologies.
This budget can be either for all investment periods within the model or alternatively, if you *e.g.*, utilize a [`TwoLevelTree`](@extref TimeStruct.TwoLevelTree) and want to limit the budget within an individual scenario or only have a budget in a subset of the investment periods, for a specified set of investment periods.

Given a set of investments specified as a `Vector` of `Tuples`, corresponding to the `element` as first entry and the capacity `prefix` as second entry, it limits the sum of the undiscounted capital expenditures into these technologies based on the specified `limit`.

An example would be given by the following code snippet

```julia
# Included technologies in the budgets
investments = [
    (tech, :cap),
    (storage, :stor_charge),
    (pipeline, :trans_cap),
]

# Maximum budget
limit = 1e7

# Addition of the constraints
max_budget(m, limit, investments, 𝒯)
```

In this situation, we have an overall budget of 10 000 000 € to invest into three technologies, a technology `tech` in which the capacity variables use the prefix `:cap`, a storage technology `storage` in which the capacity variables use the prefix `:stor_charge` (the charging capacity), and a transmission mode `pipeline` in which the capacity variables use the prefix `:trans_cap`.
This budget applies to all investment periods, given as ``T^{Inv}``, of the time structure.

This corresponds to the following mathematical description

```math
\begin{aligned}
1e7 \geq \sum_{t_{inv} \in T^{Inv}} & \texttt{cap\_add}[tech, t_{inv}] + {} \\
& \texttt{stor\_charge\_add}[storage, t_{inv}] + {} \\
& \texttt{trans\_cap\_add}[pipeline, t_{inv}] \\
\end{aligned}
```

or generally speaking to

```math
limit \geq \sum_{t_{inv} \in sps, (element, prefix) \in investments}{\texttt{prefix\_add}[element, t_{inv}]}
```

where ``sps`` corresponds either to all investment periods ``T^{Inv}`` as in the example above or to the specified investment periods through the keyword arguments ``sps\_spec``.

## [Relations between investment actions](@id man-rel-inv)

There are several functions for creating relations between investment actions in technologies.
These relations link binary activations, not necessarily positive capacity additions.
This implies that the capacity additions of the elements are not directly affected.

!!! warning "Supported investment modes"
    These relations requires binary ``*\_invest\_b`` variables for both elements and all strategic periods in ``T^{Inv}``.
    Hence, they can only be utilized for [`BinaryInvestment`](@ref), [`SemiContinuousInvestment`](@ref), and [`SemiContinuousOffsetInvestment`](@ref).
    For [`BinaryInvestment`](@ref), the binary controls installed capacity above baseline.
    For semicontinuous modes, they enable capacity additions, which can be zero when the minimum addition is zero.

    You will receive an `ArgumentError` if you utilize an unsupported `InvestmentMode`.

### [Maximum and minimum number of investments](@id man-rel-inv-max_min_inv)

The functions [`max_investments`](@ref) and [`min_investments`](@ref) provide bounds to the number of investment actions for a given set of technologies.

Considering again the example from above,

```julia
# Included technologies in the budgets
investments = [
    (tech, :cap),
    (storage, :stor_charge),
    (pipeline, :trans_cap),
]

# Maximum number of investment actions
max_limit = 5
max_investments(m, max_limit, investments, 𝒯)

# Minimum number of investment actions
min_limit = 3
min_investments(m, min_limit, investments, 𝒯)
```

the addition of the constraints implies that we need to have at least ***three*** investment actions and at maximum ***five***.
This limit applies to all investment periods, given as ``T^{Inv}``, of the time structure.

This corresponds to the following mathematical description

```math
\begin{aligned}
3 \leq \sum_{t_{inv} \in T^{Inv}} & \texttt{cap\_invest\_b}[tech, t_{inv}] + {} \\
& \texttt{stor\_charge\_invest\_b}[storage, t_{inv}] + {} \\
& \texttt{trans\_cap\_invest\_b}[pipeline, t_{inv}]  \\
\leq {} & {} 5
\end{aligned}
```

or generally speaking to

```math
\sum_{t_{inv} \in sps, (element, prefix) \in investments}{\texttt{prefix\_invest\_b}[element, t_{inv}]} \leq limit
```

or

```math
\sum_{t_{inv} \in sps, (element, prefix) \in investments}{\texttt{prefix\_invest\_b}[element, t_{inv}]} \geq limit
```

where ``sps`` corresponds either to all investment periods ``T^{Inv}`` as in the example above or to the specified investment periods through the keyword arguments ``sps\_spec``.

### [Required investment actions](@id man-rel-inv_require)

Required investment actions, introduced through the function [`require_investment`](@ref), imply that you must invest in the prerequisite element if you want to invest in the dependent element.
However, it is possible to invest in the prerequisite element without investing into the dependent element

Consider the following example:

```julia
# Dependent elements
elements_dep = [
    (tech_1, :cap),
    (tech_2, :cap),
]

# Prerequisite element
element_pre = (tech_3, :cap)

# Add the constraints
require_investment(m, elements_dep, element_pre, 𝒯)
```

This corresponds to the following mathematical description

```math
\texttt{cap\_invest\_b}[tech\_1, t_{inv}] \leq \texttt{cap\_invest\_b}[tech\_3, t_{inv}]
```

or generally speaking ``\forall (element\_dep, prefix\_dep) \in elements\_dep`` to

```math
\texttt{prefix\_dep\_invest\_b}[element\_dep, t_{inv}] \leq \texttt{prefix\_pre\_invest\_b}[element\_pre, t_{inv}]
```

### [Couple investment actions](@id man-rel-inv-couple)

Coupling investment actions, introduced through the function [`couple_investments`](@ref), behave similar to [`require_investment`](@ref), but the constraint is replaced through an equality constraint requiring the investment in both elements or none.

Consider the following example:

```julia
# Investments to exclude
elements = [
    (tech_1, :cap),
    (tech_2, :cap),
]

# Add the constraints
couple_investments(m, elements, 𝒯)
```

This corresponds to the following mathematical description

```math
\texttt{cap\_invest\_b}[tech\_1, t_{inv}] = \texttt{cap\_invest\_b}[tech\_2, t_{inv}]
```

or generally speaking ``\forall (element, prefix) \in elements[2:end]`` to

```math
\texttt{elements[1][2]\_invest\_b}[elements[1][1], t_{inv}]  = \texttt{prefix\_invest\_b}[element, t_{inv}]
```

### [Exclude investment actions](@id man-rel-inv-exclude)

Exclude investments, introduced through the function [`exclude_investments`](@ref), results in constraints that you can in each strategic period ``t_{inv}`` only invest in one of the elements.

Consider the following example:

```julia
# Investments to exclude
elements = [
    (tech_1, :cap),
    (tech_2, :cap),
]

# Add the constraints
exclude_investments(m, elements, 𝒯)
```

This corresponds to the following mathematical description

```math
\texttt{cap\_invest\_b}[tech\_1, t_{inv}] + \texttt{cap\_invest\_b}[tech\_2, t_{inv}] \leq 1
```

or generally speaking to

```math
\sum_{(element, prefix) \in elements} \texttt{prefix\_invest\_b}[element, t_{inv}] \leq 1
```

## [Relations between installed capacities](@id man-rel-cap)

There are several functions for creating relations between the installed capacity of two elements.

### [Coupled capacities](@id man-rel-cap-couple)

The installed capacities (specified by `prefix_1` and `prefix_2`) of two elements (specified by `element_1` and `element_2`) can be coupled through the function [`couple_capacity`](@ref).

Consider the following example:

```julia
# Investments to couple
element_1 = (tech_1, :cap)
element_2 = (tech_2, :cap)

# Ratio between the capacity
capacity_ratio = 2

# Addition of the constraints
couple_capacity(m, element_1, element_2, 𝒯; capacity_ratio)
```

This implies that the capacity of ``tech\_1`` must be twice the capacity of ``tech\_2``.
The following mathematical description is hence given

```math
\texttt{cap\_current}[tech\_1, t_{inv}] = 2 \times \texttt{cap\_current}[tech\_2, t_{inv}]
```

or generally speaking to

```math
\begin{aligned}
\texttt{element\_1[2]\_current}&[element\_1[1], t_{inv}] = \\
&capacity\_ratio \times \texttt{element\_2[2]\_current}[element\_2[1], t_{inv}]
\end{aligned}
```

!!! tip "Utilization of `couple_capacity`"
    You can also use `couple_capacity` for connecting the investments for the different capacities of a storage node.
    In this case, `element_1` and `element_2` would be the same.

### [Required and preceded capacities](@id man-rel-cap-req)

Capacity requirements can be introduced through the functions [`require_capacity`](@ref) and [`precede_capacity`](@ref).
These functions connect the capacities of dependent elements, specified as `(element_dep, prefix_dep)` tuples, with the capacity of a prerequisite element specified as an `(element_pre, prefix_pre)` tuple.
The two capacities are linked through the keyword argument `capacity_ratio`.

Consider the following example:

```julia
# Dependent elements
elements_dep = [
    (tech_1, :cap),
    (tech_2, :cap),
]

# Prerequisite element
element_pre = (tech_3, :cap)

# Ratio between the capacity
capacity_ratio = 2

# Addition of the constraints
require_capacity(m, elements_dep, element_pre, 𝒯; capacity_ratio)
```

This implies that we can invest in at most twice the capacity of each dependent technology
relative to the capacity of ``tech\_3``.
The following mathematical description is hence given

```math
\begin{aligned}
\texttt{cap\_current}[tech\_1, t_{inv}] & {} \leq 2 \times \texttt{cap\_current}[tech\_3, t_{inv}] \\
\texttt{cap\_current}[tech\_2, t_{inv}] & {} \leq 2 \times \texttt{cap\_current}[tech\_3, t_{inv}]
\end{aligned}
```

or generally speaking to

```math
\begin{aligned}
\texttt{prefix\_dep\_current}&[element\_dep, t_{inv}] \leq \\
& capacity\_ratio \times \texttt{prefix\_pre\_current}[element\_pre, t_{inv}] \\
\forall (element\_dep, & prefix\_dep) \in elements\_dep
\end{aligned}
```

!!! tip "Utilization of `require_capacity`"
    You can also use `require_capacity` for connecting the investments for the different capacities of a storage node in cases where, *e.g.*, the charge capacity cannot exceed a fraction of the installed storage level.

[`precede_capacity`](@ref) works similarly but requires the capacity to be available at the beginning of the investment period, that is, any capacity additions within the investment period do not count towards the requirement.

Given the example from above, the following call adds the preceded-capacity constraints:

```julia
precede_capacity(m, elements_dep, element_pre, 𝒯; capacity_ratio)
```

```math
\begin{aligned}
\texttt{cap\_current}[tech\_1, t_{inv}] & {} \leq 2 \times (\texttt{cap\_current}[tech\_3, t_{inv}] - \texttt{cap\_add}[tech\_3, t_{inv}]) \\
\texttt{cap\_current}[tech\_2, t_{inv}] & {} \leq 2 \times (\texttt{cap\_current}[tech\_3, t_{inv}] - \texttt{cap\_add}[tech\_3, t_{inv}])
\end{aligned}
```

or generally speaking to

```math
\begin{aligned}
\texttt{prefix\_dep\_current}[element\_dep, t_{inv}] & \leq capacity\_ratio \times {} \\
(\texttt{prefix\_pre\_current}&[element\_pre, t_{inv}] - \texttt{prefix\_pre\_add}[element\_pre, t_{inv}]) \\
 \forall (element\_dep, prefix\_dep) & \in elements\_dep
\end{aligned}
```

### [Retirement of capacities](@id man-rel-cap-ret)

In some cases, it is required that the capacity of a technology is retired before it is possible to invest in the capacity of a second technology.
This is achieved through the function [`retire_capacity`](@ref), which requires the retirement of the capacity of the prerequisite technology before it is possible to invest in the capacity of the dependent technology.

Consider the following example:

```julia
# Dependent elements
elements_dep = [
    (tech_1, :cap, investment_data(tech_1)),
    (tech_2, :cap, investment_data(tech_2)),
]

# Prerequisite element
element_pre = (tech_3, :cap, investment_data(tech_3))

# Add the constraints
retire_capacity(m, elements_dep, element_pre, 𝒯)
```

The function introduces first a number of binary variables similar to the number of investment periods ``T^{Inv}``.
These variables are not registered with a name.
Hence, they are called ``\texttt{var\_bin}`` below.
The binary variables correspond to the retirement of the prerequisite element, *i.e.*, a value of 1 implies that the installed capacity of the prerequisite element has an upper bound of 0.

The binary variables of subsequent investment periods (``t_{inv,pre}`` and ``t_{inv}``) are coupled by

```math
\texttt{var\_bin}[t_{inv}] \geq \texttt{var\_bin}[t_{inv,pre}]
```

This implies that once the prerequisite technology is retired, it cannot be invested in any longer.

The main constraints are
then given by

```math
\begin{aligned}
\texttt{cap\_current}[tech\_1, t_{inv}] & {} \leq {} \texttt{var\_bin}[t_{inv}] \times max\_installed(inv\_data\_dep, t_{inv}) {} \\
\texttt{cap\_current}[tech\_2, t_{inv}] & {} \leq {} \texttt{var\_bin}[t_{inv}] \times max\_installed(inv\_data\_dep, t_{inv}) {} \\
\texttt{cap\_current}[tech\_3, t_{inv}] & {} \leq (1-\texttt{var\_bin}[t_{inv}]) \times max\_installed(inv\_data\_pre, t_{inv}) {} \\
\end{aligned}
```

or generally speaking ``\forall (element\_dep, prefix\_dep, inv\_data\_dep) \in elements\_dep`` to

```math
\begin{aligned}
\texttt{prefix\_dep\_current} & {} [element\_dep, t_{inv}] \leq \\
& {} \texttt{var\_bin}[t_{inv}] \times max\_installed(inv\_data\_dep, t_{inv})
\end{aligned}
```

and for the prerequisite element to

```math
\begin{aligned}
\texttt{prefix\_pre\_current} & {} [element\_pre, t_{inv}] \leq  \\
& {} (1-\texttt{var\_bin}[t_{inv}]) \times max\_installed(inv\_data\_pre, t_{inv})
\end{aligned}
```

!!! warning "Initial capacities"
    The model can theoretically include initial capacities which are not consistent with the additional constraints.
    This would then lead to infeasible models.
    An example would be the application of [`StartInvData`](@ref) for both technologies and using a `FixedProfile` for the field `:initial` with values larger than 0.
