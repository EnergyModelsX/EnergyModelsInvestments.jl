# Running the examples


## Adding the internal package registry

First, we need to add the  `EnergyModelsBase` internal Julia registry. First, start the Julia REPL in the root of this package,
```shell script
~/../energymodelsinvestments.jl $ julia
```
Now add the registry by
```
julia> ] 
pkg> registry add git@gitlab.sintef.no:clean_export/registrycleanexport.git
```
Install the dependencies,
```julia
pkg> instantiate
```


## Running

The examples can be run by executing,
```shell script
~/../energymodelsinvestments.jl $ julia --project=@. examples/simple_model.jl
```
The flag `--project=@.` activates a Julia environment in the current directory, or in the parent directory if no `Project.toml` file is found.
