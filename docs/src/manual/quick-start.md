# Quick Start

To start using the package, refer to installation instruction onthe README page from the git repository.  

Once the package is installed, you can start using the package. You can start by using an existing model from `EnergyModelsBase` and converting it with investments.
To achieve this, the model type has to be changed from `OperationalModel` to `InvestmentModel` and additional parameters must be provided (emission penalties and a discount rate).
New nodes can then be added including investment or investment can be added to existing nodes. To modify an existing node to an investment option, you must provide extra investment data in the field `Data` of your node. This will take the form of an `Arrary` entry of `InvData` or `InvDataStorage` in case the technology is a storage.
You can find information about the different investment parameters that can be provided to `InvData` in the following documentation.

You can check out and run the examples provided to see simple cases including investment in technologies and transmission.
