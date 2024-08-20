# Running the examples

You have to add the package `EnergyModelsInvestments` to your current project in order to run the example.
It is not necessary to add the other used packages, as the example is instantiating itself.
How to add packages is explained in the *[Quick start](https://energymodelsx.github.io/EnergyModelsBase.jl/stable/manual/quick-start/)* of the documentation of `EnergyModelsBase`.

You can run from the Julia REPL the following code:

```julia
# Import EnergyModelsInvestments
using EnergyModelsInvestments

# Get the path of the examples directory
exdir = joinpath(pkgdir(EnergyModelsInvestments), "examples")

# Include the code into the Julia REPL to run the individual examples
include(joinpath(exdir, "sink_source.jl"))
include(joinpath(exdir, "network.jl"))
```