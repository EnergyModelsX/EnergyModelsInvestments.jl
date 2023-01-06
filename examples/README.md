# Running the examples


## Adding the internal package registry

First, we need to add the  `EnergyModelsBase` internal Julia registry. First start the Julia REPL by running the following in the root directory of this package,
```shell script
~/../energymodelsinvestments.jl $ julia
```
Now add the registry by
```julia
julia > ] registry add git@gitlab.sintef.no:clean_export/registrycleanexport.git
```


## Running

The examples can be run by executing,
```shell script
~/../energymodelsinvestments.jl $ julia --project=. examples/user_interface.jl
```
The flag `--proejct=.` activates a julia environment in the current directory. The package manager `Pkg` will then download the needed dependencies.
