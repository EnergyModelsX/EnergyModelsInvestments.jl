# [Use `EnergyModelsInvestments`](@id sec_how_to_use)

`EnergyModelsInvestments` was initially designed as extension package for [`EnergyModelsBase`](https://energymodelsx.github.io/EnergyModelsBase.jl/).
Hence, many design choices are impacted by the requirements of `EnergyModelsBase`.
We realized however that it can be beneficial to make it independent of `EnergyModelsBase` to use the incorporated methods in other energy system optimization models that may be under development.

Using `EnergyModelsInvestments` requires the following implementations in your model.

!!! tip "Implementation"
    If you are uncertain on how to best implement investment options, it can be beneficial to investigate the appraoches chosen in [`EnergyModelsBase`](https://github.com/EnergyModelsX/EnergyModelsBase.jl/tree/main/ext/EMIExt) and [`EnergyModelsGeography`](https://github.com/EnergyModelsX/EnergyModelsGeography.jl/tree/main/ext/EMIExt).

## Auxiliary functions

The are several additional functions which are specific for the individual types.
This functions are either used as example for a simplified interface or alternatively required in `EnergyModelsInvestments`.
The latter requires you to implement these methods within your model through multiple dispatch as they are called within `EnergyModelsInvestments`.

### Required methods

When you are using the type [`NoStartInvData`](@ref), you have to specify the function

```julia
start_cap(element, t_inv, inv_data::NoStartInvData, cap)
```

for your type.
The main reason is that in this case you do not specify the initial capacity in `EnergyModelsInvestments`, but instead deduce it from the provided initial capacity in your energiy system optimization model.

In the case of EnergyModelsBase, this is given through the methods

```julia
EMI.start_cap(n::EMB.Node, t_inv, inv_data::NoStartInvData, cap) =
    capacity(n, t_inv)
EMI.start_cap(n::Storage, t_inv, inv_data::NoStartInvData, cap) =
    capacity(getproperty(n, cap), t_inv)
```

and the application of the internal function `capacity()`.

### Simplified interface functions

`EnergyModelsBase` creates new types for the investment data instead of using [`NoStartInvData`](@ref) and [`StartInvData`](@ref).
The background for this approach is that we like to have the potential for multiple capacities within a node, *e.g.*, charge, level, and discharge capacities in `Storage` nodes as well as the potential for investments in the individual capacities.
Hence, we create new methods for the function [`investment_data()`](@ref) to directly access the individual fields of the new investment data types from the node level.
In addition, we incorporate the function [`has_investment()`](@ref) to allow a limitation of investments to a subset
of the nodes.

Both functions are not directly used in `EnergyModelsInvestments` in this context.
Hence, it is not required to declare new methods for these functions. It can however be beneficial to create methods as it may simplify the subsequent structure.

## Variable declarations

As outlined in *[Optimization variables](@ref optimization_variables)*, we require that the user follows a given variable naming convention.
The variables used within `EnergyModelsInvestments` are extracted with the help of the following functions:

- [`EMI.get_var_capex`](@ref) for capital expenses variables, declared over strategic periods,
- [`EMI.get_var_inst`](@ref) for capacity variables, declared over operational periods,
- [`EMI.get_var_current`](@ref) for capacity variables, declared over strategic periods,
- [`EMI.get_var_add`](@ref) for capacity addtion variables, declared over strategic periods,
- [`EMI.get_var_rem`](@ref) for capacity removal variables, declared over strategic periods,
- [`EMI.get_var_invest_b`](@ref) for helper variables for investments, declared over strategic periods, and
- [`EMI.get_var_remove_b`](@ref) for helper variables for removals, declared over strategic periods.

The provided functions utilize a `prefix::Symbol` argument which is the corresponding prefix for all variables.
*[Optimization variables](@ref optimization_variables)* explains the required names for the variables with `prefix = :cap`.

Although it is in general possible to provide dispatch on these functions for new types, we unfortunately require in the current implementation that the naming convention has to be followed at least for the *[Auxiliary variables](@ref var_aux)* as [`SparseVariables`](https://github.com/sintefore/SparseVariables.jl) requires the extraction of all variables with a given name before the insertion.

Hence, it is best to declare all variables as, *e.g.* using the prefix `:cap`:

```julia
𝒯ᴵⁿᵛ = strategic_periods(𝒯)

# Add investment variables for reference nodes for each strategic period:
@variable(m, cap_inst[𝒩ᴵⁿᵛ] >= 0)
@variable(m, cap_capex[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)
@variable(m, cap_current[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)
@variable(m, cap_add[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)
@variable(m, cap_rem[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0)
@variable(m, cap_invest_b[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0; container = IndexedVarArray)
@variable(m, cap_remove_b[𝒩ᴵⁿᵛ, 𝒯ᴵⁿᵛ] >= 0; container = IndexedVarArray)
```

with `𝒩ᴵⁿᵛ` corresponding to nodes with investments.

## Inclusion of investment constraints

Investment constraints are included through the function

```julia
function add_investment_constraints(
    m,                          # JuMP model
    element,                    # Element for which investments are added
    inv_data::AbstractInvData,  # Investment data for the element
    cap,                        # Capacity that has investments
    prefix,                     # Used prefix in variable declaration
    𝒯ᴵⁿᵛ::TS.StratPeriods,      # Strategic periods
    disc_rate::Float64,         # Discount rate in absolute values
)
```

The individual input is as well described in the [documentation](@ref EnergyModelsInvestments.add_investment_constraints)

This functions includes constraints on the capacity and calculates the capital expenses for each `element`.
There are two main points one has to consider:

1. We add the investments constraints for each individual `element`. In the case of multiple `element`s, it is necessary to iterate through the vector of `element`s.
2. We add the investment constraints for each individual capacity `cap`. This argument is only relevant if an `element` has multiple capacities as it is the case for `Storage` nodes in `EnergyModelsBase`.

Consequently, you have to iterate through all `element`s and their capacities `cap` if you want to add investment constraints.

Given the example nodes above with single capacities, this would be given as:

```julia
for n ∈ 𝒩ᴵⁿᵛ
    # Extract the investment data, the discount rate, and the strategic periods
    disc_rate = discount_rate(modeltype)
    inv_data = investment_data(n, :cap)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Add the investment constraints
    EMI.add_investment_constraints(m, n, inv_data, :cap, :cap, 𝒯ᴵⁿᵛ, disc_rate)
end
```

Note that we included in this example a method for `investment_data()` as outlined above.

## Updating the objective function

`EnergyModelsInvestments` does not change the objective function.
This would require detailed knowledge regarding the individual contributing factors.
Hence, we decided that it is beneficial to instead calculate the capital expense contributions in each strategic period.
As a consequence, when using `EnergyModelsInvestments`, you have to include the variable ``\texttt{cap\_capex}`` (if you used `prefix = :cap`) for all elements with investments to your objective function.

An illustrative example is given in the function `EMB.objective(m, 𝒩, 𝒯, 𝒫, modeltype::AbstractInvestmentModel)` compared to the function `objective(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)` in `EnergyModelsBase`.

!!! note
    We plan to add the links to the functions once we have both updates registered.
