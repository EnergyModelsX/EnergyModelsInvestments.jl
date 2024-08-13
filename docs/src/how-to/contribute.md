# [Contribute to EnergyModelsInvestments](@id how_to-con)

Contributing to `EnergyModelsInvestments` can be achieved in several different ways.

## [File a bug report](@id how_to-con-bug_rep)

Another approach to contributing to `EnergyModelsInvestments` is through filing a bug report as an [_issue_](https://github.com/EnergyModelsX/EnergyModelsInvestments.jl/issues/new) when unexpected behaviour is occuring.

When filing a bug report, please follow the following guidelines:

1. Be certain that the bug is a bug and originating in `EnergyModelsInvestments`:
    - If the problem is within the results of the optimization problem, please check first that the nodes are correctly linked with each other.
      Frequently, missing links (or wrongly defined links) restrict the transport of energy/mass.
      If you are certain that all links are set correctly, it is most likely a bug in `EnergyModelsInvestments` and should be reported.
    - If the problem occurs in model construction, it is most likely a bug  in either `EnergyModelsBase` or `EnergyModelsInvestments` and should be reported in the respective package.
      The error message of Julia should provide you with the failing function and whether the failing function is located in `EnergyModelsBase` or `EnergyModelsInvestments`.
      It can occur, that the last shown failing function is within `JuMP` or `MathOptInterface`.
      In this case, it is best to trace the error to the last called `EnergyModelsBase` or `EnergyModelsInvestments` function.
    - If the problem is only appearing for specific solvers, it is most likely not a bug in `EnergyModelsInvestments`, but instead a problem of the solver wrapper for `MathOptInterface`.
      In this case, please contact the developers of the corresponding solver wrapper.
2. Label the issue as bug, and
3. Provide a minimum working example of a case in which the bug occurs.

!!! note
    We are aware that certain design choices within `EnergyModelsInvestments` can lead to method ambiguities.
    Our aim is to extend the documentation to improve the description on how to best extend the base functionality as well as which caveats can occur.

    In order to improve the code, we welcome any reports of potential method ambiguities to help us improving the structure of the framework.

## [Feature requests](@id how_to-feat_req)

`EnergyModelsInvestments` includes several `Investment` options and `LifetimeMode`s.
However, not all potential options are included.
Hence, if you require a new investment or lifetime mode, it is best to provide a feature request.

Feature requests for `EnergyModelsInvestments` should follow the guidelines developed for [_`EnergyModelsBase`_](https://energymodelsx.github.io/EnergyModelsBase.jl/stable/how-to/contribute/).

!!! note
    `EnergyModelsInvestments` is slightly different than `EnergyModelsBase`.

    Contrary to the other package, we consider that it is beneficial to have all potential features of investment decisions within `EnergyModelsInvestments`.
    Hence, requiring a new `Investment` mode or `LifetimeMode` should be addressed directly to `EnergyModelsInvestments` through creating an [_issue_](https://github.com/EnergyModelsX/EnergyModelsInvestments.jl/issues/new).
