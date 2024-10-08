# [Examples](@id man-exampl)

For the content of the individual examples, see the [examples](https://github.com/EnergyModelsX/EnergyModelsInvestments.jl/tree/main/examples) directory in the project repository.
These examples are based on the applicatoin of [`EnergyModelsBase`](https://energymodelsx.github.io/EnergyModelsBase.jl/stable/).

## The package is installed with `] add`

From the Julia REPL, run

```julia
# Starts the Julia REPL
using EnergyModelsInvestments
# Get the path of the examples directory
exdir = joinpath(pkgdir(EnergyModelsInvestments), "examples")
# Include the code into the Julia REPL to run the examples
include(joinpath(exdir, "sink_source.jl"))
include(joinpath(exdir, "network.jl"))
```

## The code was downloaded with `git clone`

The examples can be run from the terminal with

```shell script
~/.../energymodelsinvestments.jl/examples $ julia sink_source.jl
~/.../energymodelsinvestments.jl/examples $ julia network.jl
```
