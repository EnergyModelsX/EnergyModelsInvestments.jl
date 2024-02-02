# Running the examples

You have to add the package `EnergyModelsInvestments` to your current project in order to run the example.
It is not necessary to add the other used packages, as the example is instantiating itself.
How to add packages is explained in the *[Quick start](https://energymodelsx.github.io/EnergyModelsBase.jl/stable/manual/quick-start/)* of the documentation of `EnergyModelsBase`.

You can run from the Julia REPL the following code:

```julia
# Starts the Julia REPL
using EnergyModelsInvestments
# Get the path of the examples directory
exdir = joinpath(pkgdir(EnergyModelsInvestments), "examples")
# Include the code into the Julia REPL to run the examples
include(joinpath(exdir, "sink_source.jl"))
include(joinpath(exdir, "network.jl"))
include(joinpath(exdir, "geography.jl"))
```

The *[geography example](https://github.com/EnergyModelsX/EnergyModelsInvestments.jl/blob/main/examples/geography.jl)* will be simpliefied in a future version.
It shows however how investments in transmission mdoes can be included.
It is hence not as commented as the other examples.
