# [Optimization variables](@id optimization_variables)

`EnergyModelsInvestments` adds additional variables to `EnergyModelsBase`.
These variables are required for being able to extend the model with the potential for investments.
The current implementation creates different variables for investments in standard `Node`s, `Storage` nodes, and `TransmissionMode`s.

The individual variables can be differentiated in *[Cost variables](@ref var_cost)*, *[Capacity variables](@ref var_capacity)*, and *[Auxiliary variables](@ref var_aux)*.
In the case of `Storage` nodes, they are only defined if the node has investment in the respective fields, that is, `charge`, `level`, and/or `discharge`.

!!! note
    As it is the case in `EnergyModelsBase`, we define almost exclusively variables relative to the rate in `EnergyModelsInvestments`.
    The only exception is given for investments in the level/capacity of `Storage` nodes.
    These variables start with the prefix ``\texttt{stor}`` or end with it as suffix.

## [Cost variables](@id var_cost)

`EnergyModelsInvestments` introduces variables that help extracting the cost of investments in a technology `Node` or `TransmissionMode` at each strategic period.
The different variables are:

- ``\texttt{cap\_capex}[n_\texttt{inv}, t_\texttt{inv}]``: Undiscounted total CAPEX of `Node` ``n_\texttt{inv}`` with investments in strategic period ``t_\texttt{inv}``,
- ``\texttt{stor\_charge\_capex}[n_\texttt{stor,inv}, t_\texttt{inv}]``: Undiscounted total CAPEX for charge capacity investments of `Storage` node ``n_\texttt{stor,inv}`` with investments in strategic period ``t_\texttt{inv}``,
- ``\texttt{stor\_level\_capex}[n_\texttt{stor,inv}, t_\texttt{inv}]``: Undiscounted total CAPEX for level investments of `Storage` node ``n_\texttt{stor,inv}`` with investments in strategic period ``t_\texttt{inv}``,
- ``\texttt{stor\_discharge\_capex}[n_\texttt{stor,inv}, t_\texttt{inv}]``: Undiscounted total CAPEX for discharge capacity investments of `Storage` node ``n_\texttt{stor,inv}`` with investments in strategic period ``t_\texttt{inv}``, and
- ``\texttt{trans\_cap\_capex}[m_\texttt{inv}, t_\texttt{inv}]``: Undiscounted total CAPEX of `TransmissionMode` ``m_\texttt{inv}`` with investments in strategic period ``t_\texttt{inv}``.

The total CAPEX takes into account the invested capacity to calculate the total costs as well as the end of horizon value of the individual technologies including discounting.
The end of horizon value is currently not considered for transmission technologies.
It is only defined for nodes with investments.
The variable is an absolute cost with a unit of, *e.g., €.

## [Capacity variables](@id var_capacity)

Capacity variables are variables that manipulate the installed capacity.
In general, we can differentiate in installed capacity variables and change of capacity variables.
The installed capacity variables are:

- ``\texttt{cap\_current}[n_\texttt{inv}, t_\texttt{inv}]``: Installed capacity of `Node` ``n_\texttt{inv}`` with investments in strategic period ``t_\texttt{inv}``,
- ``\texttt{stor\_charge\_current}[n_\texttt{stor,inv}, t_\texttt{inv}]``: Installed charge capacity of `Storage` node ``n_\texttt{stor,inv}`` with investments in strategic period ``t_\texttt{inv}``,
- ``\texttt{stor\_level\_current}[n_\texttt{stor,inv}, t_\texttt{inv}]``: Installed level capacity of `Storage` node ``n_\texttt{stor,inv}`` with investments in strategic period ``t_\texttt{inv}``,
- ``\texttt{stor\_discharge\_current}[n_\texttt{stor,inv}, t_\texttt{inv}]``: Installed charge capacity of `Storage` node ``n_\texttt{stor,inv}`` with investments in strategic period ``t_\texttt{inv}``, and
- ``\texttt{trans\_cap\_current}[m_\texttt{inv}, t_\texttt{inv}]``: Installed capacity of `TransmissionMode` ``m_\texttt{inv}`` with investments in strategic period ``t_\texttt{inv}``.

The approach is similar to the *[Cost variables](@ref var_cost)* as variables are created for each of the individual types.
It would be also possible to utilize the variable ``\texttt{cap\_inst}`` as introduced in `EnergyModelsBase`.
This variable is however indexed over operational periods ``t`` to allow for variations in the demand on an operational level.
The introduction of a new variable through ``\texttt{cap\_current}`` for the capacity at a strategic period simplifies the calculations.
It is in practice not necessary and in most cases removed by the presolve routines of the optimization solver.

In addition, we introduce variables for investments in a strategic period as:

- ``\texttt{cap\_add}[n_\texttt{inv}, t_\texttt{inv}]``: Added capacity of `Node` ``n_\texttt{inv}`` with investments in the beginning of strategic period ``t_\texttt{inv}``,
- ``\texttt{stor\_charge\_add}[n_\texttt{stor,inv}, t_\texttt{inv}]``: Added charge capacity of `Storage` node ``n_\texttt{stor,inv}`` with investments in the beginning of strategic period ``t_\texttt{inv}``,
- ``\texttt{stor\_level\_add}[n_\texttt{stor,inv}, t_\texttt{inv}]``: Added level capacity of `Storage` node ``n_\texttt{stor,inv}`` with investments in the beginning of strategic period ``t_\texttt{inv}``,
- ``\texttt{stor\_discharge\_add}[n_\texttt{stor,inv}, t_\texttt{inv}]``: Added discharge capacity of `Storage` node ``n_\texttt{stor,inv}`` with investments in the beginning of strategic period ``t_\texttt{inv}``, and
- ``\texttt{trans\_cap\_add}[m_\texttt{inv}, t_\texttt{inv}]``: Added capacity of `TransmissionMode` ``m_\texttt{inv}`` with investments in the beginning of strategic period ``t_\texttt{inv}``.

These investments are available at the beginning of a strategic period.

The model can also choose to retire technologies at the end of each strategic period through removal variables given as:

- ``\texttt{cap\_rem}[n_\texttt{inv}, t_\texttt{inv}]``: Retired capacity of `Node` ``n_\texttt{inv}`` with investments at the end of strategic period ``t_\texttt{inv}``,
- ``\texttt{stor\_charge\_rem}[n_\texttt{stor,inv}, t_\texttt{inv}]``: Retired charge capacity of `Storage` node ``n_\texttt{stor,inv}`` with investments at the end of strategic period ``t_\texttt{inv}``,
- ``\texttt{stor\_level\_rem}[n_\texttt{stor,inv}, t_\texttt{inv}]``: Retired level capacity of `Storage` node ``n_\texttt{stor,inv}`` with investments at the end of strategic period ``t_\texttt{inv}``,
- ``\texttt{stor\_discharge\_rem}[n_\texttt{stor,inv}, t_\texttt{inv}]``: Retired discharge capacity of `Storage` node ``n_\texttt{stor,inv}`` with investments at the end of strategic period ``t_\texttt{inv}``, and
- ``\texttt{trans\_cap\_rem}[m_\texttt{inv}, t_\texttt{inv}]``: Retired capacity of `TransmissionMode` ``m_\texttt{inv}`` with investments at the end of strategic period ``t_\texttt{inv}``.

The retired capacity corresponds to removal of capacity, either due to the end of lifetime or due to lack of usage.
Capacity removal only has a reduced impact on the objective function due to removal of the fixed OPEX.
It can however be beneficial for the model to remove unused capacity to avoid fixed OPEX when the technology is not used in the future.
Early removal of a technology, that is before the end of its lifetime, does not provide a rest value to the system.

## [Auxiliary variables](@id var_aux)

Auxiliary variables are variables that are required for certain investment modes.
The model creates these variables only if the investment mode requires them.
The meaning of the auxiliary variables changes depending on the investment mode.

These variables are:

- ``\texttt{cap\_invest\_b}[n_\texttt{inv}, t_\texttt{inv}]`` and ``\texttt{cap\_remove\_b}[n_\texttt{inv}, t_\texttt{inv}]`` ,
- ``\texttt{stor\_charge\_invest\_b}[n_\texttt{stor,inv}, t_\texttt{inv}]`` and ``\texttt{stor\_charge\_remove\_b}[n_\texttt{stor,inv}, t_\texttt{inv}]``,
- ``\texttt{stor\_level\_invest\_b}[n_\texttt{stor,inv}, t_\texttt{inv}]`` and ``\texttt{stor\_level\_remove\_b}[n_\texttt{stor,inv}, t_\texttt{inv}]``, and
- ``\texttt{trans\_cap\_invest\_b}[m_\texttt{inv}, t_\texttt{inv}]`` and ``\texttt{trans\_cap\_remove\_b}[m_\texttt{inv}, t_\texttt{inv}]``.

### [`BinaryInvestment`](@ref)

The variable ``\texttt{cap\_invest\_b}`` is a binary and used in calculating the current capacity.
The variable ``\texttt{cap\_remove\_b}`` is not included in any constraint.

### [`DiscreteInvestment`](@ref)

The variable ``\texttt{cap\_invest\_b}`` is an integer and used in calculating the added capacity.
The variable ``\texttt{cap\_remove\_b}`` is an integer and used in calculating the removed capacity.

### [`SemiContiInvestment`](@ref)

The variable ``\texttt{cap\_invest\_b}`` is a binary and used in calculating the added capacity by providing a lower bound as well as in the CAPEX calculation in the case of [`SemiContinuousOffsetInvestment`](@ref).
The variable ``\texttt{cap\_remove\_b}`` is not included in any constraint.

### [`FixedInvestment`](@ref)

The variable ``\texttt{cap\_invest\_b}`` is fixed to 1 and used in calculating the current capacity.
The variable ``\texttt{cap\_remove\_b}`` is not included in any constraint.
