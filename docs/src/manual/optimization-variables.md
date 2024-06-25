# [Optimization variables](@id optimization_variables)

`EnergyModelsInvestments` requires that variables are declared by the package which uses it.
These variables are required for being able to extend the model with the potential for investments.
The variables are required to follow a given nomenclature utilizing a `prefix` symbol.

The individual variables can be differentiated in *[Cost variables](@ref var_cost)*, *[Capacity variables](@ref var_capacity)*, and *[Auxiliary variables](@ref var_aux)*.

## General structure of variables

As an example, consider the capex variables.
The capex variables with a prefix `:cap` are given by ``\texttt{cap\_capex}[n_\texttt{inv}, t_\texttt{inv}]`` for `Node` ``n_\texttt{inv}`` with investments in strategic period ``t_\texttt{inv}``.
They are extracted using the functions functions [`EMI.get_var_capex(m, prefix::Symbol)`](@ref) and [`EMI.get_var_capex(m, prefix::Symbol, element)`](@ref) in which `m` corresponds to the JuMP model, prefix to a prefix used in variable declaration (in this case `:cap`) and element to an instance of the element (in the previous example given as ``n_\texttt{inv}``).

They are **not** declared within `EnergyModelsInvestments`, but have to be declared within the model using `EnergyModelsInvestments`.
This is illustrated in the `EMIExt` of `EnergyModelsBase`.

## [Cost variables](@id var_cost)

`EnergyModelsInvestments` requires the introduction of variables that help extracting the cost of investments in an element at each strategic period.
One example is given through `EnergyModelsBase`:

- ``\texttt{cap\_capex}[n_\texttt{inv}, t_\texttt{inv}]``: Undiscounted total CAPEX of `Node` ``n_\texttt{inv}`` with investments in strategic period ``t_\texttt{inv}``.

The total CAPEX takes into account the invested capacity to calculate the total costs as well as the end of horizon value of the individual technologies including discounting.

The variable is extracted using the functions [`EMI.get_var_capex(m, prefix::Symbol)`](@ref) (for all variables) and [`EMI.get_var_capex(m, prefix::Symbol, element)`](@ref) (for only the variable from a given element instance) in which `m` corresponds to the JuMP model, and `prefix` to a prefix used in variable declaratio.

!!! tip "Units of cost variables"
    Cost variables provide the absolute costs within a strategic period ``t_\texttt{inv}``.
    An example unit would be € or $.

## [Capacity variables](@id var_capacity)

Capacity variables are variables that manipulate the installed capacity.
In general, we can differentiate in installed capacity variables and change of capacity variables.
The installed capacity variables are:

- ``\texttt{cap\_inst}[n, t]``: Installed capacity of `Node` ``n`` with investments in operational period ``t`` and
- ``\texttt{cap\_current}[n_\texttt{inv}, t_\texttt{inv}]``: Installed capacity of `Node` ``n_\texttt{inv}`` with investments in strategic period ``t_\texttt{inv}``.

The approach is similar to the *[Cost variables](@ref var_cost)* as variables are created for each of the individual elements.
They are extracted using the functions functions [`EMI.get_var_inst(m, prefix::Symbol)`](@ref) and [`EMI.get_var_inst(m, prefix::Symbol, element)`](@ref) as well as [`EMI.get_var_current(m, prefix::Symbol)`](@ref) and [`EMI.get_var_current(m, prefix::Symbol, element)`](@ref).

!!! info "Why two capacity variables"
    The variable ``\texttt{cap\_inst}`` is slightly redundant in this design.
    It is indexed over operational periods ``t`` to allow for variations in the demand on an operational level within nodes without investments.
    This could have been also solved by using a profile, but it was decided to keep the current design.
    The introduction of a new variable through ``\texttt{cap\_current}`` for the capacity at a strategic period simplifies the indexing.

    If you do not have nodes without investments, you still have to create the variable.
    In this case, we suggest to not use this variable at all and link the capacity usage directly to ``\texttt{cap\_current}``

In addition, we introduce variables for investments in a strategic period as:

- ``\texttt{cap\_add}[n_\texttt{inv}, t_\texttt{inv}]``: Added capacity of `Node` ``n_\texttt{inv}`` with investments in the beginning of strategic period ``t_\texttt{inv}``.

The investments are available at the beginning of a strategic period.
They are extracted using the functions functions [`EMI.get_var_add(m, prefix::Symbol)`](@ref) and [`EMI.get_var_add(m, prefix::Symbol, element)`](@ref).

The model can also choose to retire technologies at the end of each strategic period through removal variables given as:

- ``\texttt{cap\_rem}[n_\texttt{inv}, t_\texttt{inv}]``: Retired capacity of `Node` ``n_\texttt{inv}`` with investments at the end of strategic period ``t_\texttt{inv}``.

The retired capacity corresponds to removal of capacity, either due to the end of lifetime or due to lack of usage.
Capacity removal has an impact on the objective function due to removal of the fixed OPEX.
It can hence be beneficial for the model to remove unused capacity to avoid fixed OPEX when the technology is not used in the future.
Early removal of a technology, that is before the end of its lifetime, does not provide a rest value to the objective function.
The variables are extracted using the functions functions [`EMI.get_var_rem(m, prefix::Symbol)`](@ref) and [`EMI.get_var_rem(m, prefix::Symbol, element)`](@ref).

!!! tip "Units of capacity variables"
    The units of the capacity variables are defined by the user.
    Within `EnergyModelsBase`, we use both rates (normal nodes as well as charge and discharge capacity of `Storage` nodes) and energy/mass (level capacity of `Storage` nodes).
    Hence, it is important to consider the requirement of the model when deciding the unit.

## [Auxiliary variables](@id var_aux)

Auxiliary variables are variables that are required for certain investment modes.
The model creates these variables only if the investment mode requires them.
The meaning of the auxiliary variables changes depending on the investment mode.

These variables are:

- ``\texttt{cap\_invest\_b}[n_\texttt{inv}, t_\texttt{inv}]`` and
- ``\texttt{cap\_remove\_b}[n_\texttt{inv}, t_\texttt{inv}]``,

accessed through the functions [`EMI.get_var_invest_b(m, prefix::Symbol)`](@ref), [`EMI.get_var_invest_b(m, prefix::Symbol, element)`](@ref), [`EMI.get_var_remove_b(m, prefix::Symbol)`](@ref), and [`EMI.get_var_remove_b(m, prefix::Symbol, element)`](@ref).

The auxiliary variables are only created if the investment mode requires them through the application [`SparseVariables`](https://github.com/sintefore/SparseVariables.jl).

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
