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

> **Note**
>
> The *[geography example](https://github.com/EnergyModelsX/EnergyModelsInvestments.jl/blob/main/examples/geography.jl)* is not running yet, as the instantiation would require that the package [`EnergyModelsGeography`](https://github.com/EnergyModelsX/EnergyModelsBase.jl) is registered.
> It is however possible to run the code directly from a local project in which the packages `TimeStruct`, `EnergyModelsBase`,`EnergyModelsGeography`, `EnergyModelsInvestments`, `JuMP`, and `HiGHS` are loaded.
> In this case, you have to comment lines 2-7 out:
>
> ```julia
> # Activate the test-environment, where HiGHS is added as dependency.
> Pkg.activate(joinpath(@__DIR__, "../test"))
> # Install the dependencies.
> Pkg.instantiate()
> # Add the package EnergyModelsInvestments to the environment.
> Pkg.develop(path=joinpath(@__DIR__, ".."))
> ```
