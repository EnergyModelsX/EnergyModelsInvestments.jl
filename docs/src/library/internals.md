# Internals

## Index

```@index
Pages = ["internals.md"]
```

## Core functions

```@docs
EnergyModelsInvestments.add_investment_constraints
EnergyModelsInvestments.set_capacity_installation
EnergyModelsInvestments.set_capacity_cost
EnergyModelsInvestments.set_capex_value
```

## Variable extraction functions

```@docs
EnergyModelsInvestments.get_var_capex
EnergyModelsInvestments.get_var_inst
EnergyModelsInvestments.get_var_current
EnergyModelsInvestments.get_var_rem
EnergyModelsInvestments.get_var_add
EnergyModelsInvestments.get_var_invest_b
EnergyModelsInvestments.get_var_remove_b
```

## Functions for extracting fields

```@docs
EnergyModelsInvestments.capex
EnergyModelsInvestments.max_installed
EnergyModelsInvestments.min_add
EnergyModelsInvestments.max_add
EnergyModelsInvestments.capex_offset
EnergyModelsInvestments.invest_capacity
EnergyModelsInvestments.increment
EnergyModelsInvestments.lifetime_mode
EnergyModelsInvestments.lifetime
```

## Utility functions

```@docs
EnergyModelsInvestments.set_capex_discounter
EnergyModelsInvestments.start_cap
```
