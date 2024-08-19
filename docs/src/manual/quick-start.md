# [Quick Start](@id man-quick)

To start using the package, refer to the installation instructions on the README page from the git repository.

Once the package is installed, you can start using the package. You can start by using an existing model from [`EnergyModelsBase`](https://energymodelsx.github.io/EnergyModelsBase.jl/) and include investment options for the different technologies.
To achieve this, the model type has to be changed from [`OperationalModel`](https://energymodelsx.github.io/EnergyModelsBase.jl/dev/library/public/#Model-and-data) to `InvestmentModel` which requires the addition of a discount rate as parameter.
New nodes can then be added including investment or investment can be added to existing nodes. To modify an existing node to an investment option, you must provide extra investment data in the field `data` of your node. This will take the form of an `Array` entry of `SingleInvData` or `StorageInvData` in case the technology is a `Storage` node.

You can check out and run the provided *[examples](@ref man-exampl)* to see simple cases including investment in technologies and transmission.
