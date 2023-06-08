# Philosophy

This package aims at extending `EnergyModelsBase` with investment functionalities. To this end, multiple dispatch is used to redefine certain methods (creation of nodes, model building including objective function,...) and new ones are created. The package is intended to provide as much options as possible to represent investment options.
This means defining a wide array of investment modes, lifetime mode and discounting methods.
The model is also compatible with `EnergyModelsGeography` to extend its concept to investment in transmission.
