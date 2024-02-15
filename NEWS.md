Release Notes

=============
Version 0.5.2 (2024-02-15)
--------------------------
### Bugfix
 * Fixed the function for extracting the field `capex_trans_offset` in `TransInvData`.

Version 0.5.1 (2024-01-17)
--------------------------
### Feature
 * Added the JuMP model `m` and `modeltype` as arguments to the start-capacity methods.

Version 0.5.0 (2023-12-19)
--------------------------
### Adjustment
Adjusted to changes in `EnergyModelsBase` v0.6.
These changes are mainly:

* All fields of composite types are now lower case.
* An extensive number of functions to access the individual fields were included, allowing for differing definitions of the individual nodes.

In addition this version includes:

* A rewriting of the calculation of the objective function.

Version 0.4.6 (2023-11-23)
--------------------------
### Bugfix
 * Added strategic period duration multiplication for emissions prices

Version 0.4.5 (2023-10-24)
--------------------------
### Bugfix
 * Include opex for transmission modes without investments.

Version 0.4.4 (2023-09-15)
--------------------------
### Bugfix
 * Use correct index on parameter values.

Version 0.4.3 (2023-09-08)
--------------------------
### Bugfix
 * Bugfix from v0.4.1 `RollingLife` was reverted due to rebasing in v0.4.2. This was fixed

Version 0.4.2 (2023-08-24)
--------------------------
### Changes in discounting
 * Previously, strategic periods were discounted using the start year for both OPEX and CAPEX
 * This was changed for OPEX and emission cost calculations to account for longer strategic periods

Version 0.4.1 (2023-08-02)
--------------------------
### Bugfix
 * Included calling of `strategic_periods` in `::RollingLife` which was missing

Version 0.4.0 (2023-06-06)
--------------------------
### Switch to TimeStruct.jl
 * Switched the time structure representation to [TimeStruct.jl](https://github.com/sintefore/TimeStruct.jl)
 * TimeStruct.jl is implemented with only the basis features that were available in TimesStructures.jl. This implies that neither operational nor strategic uncertainty is included in the model

Version 0.3.2 (2023-06-01)
--------------------------
 * Bugfix related to `FixedInvestment`

Version 0.3.1 (2023-06-01)
--------------------------
 * Added dispatch on `EMI.has_investment` in the extension instead of defining a new, local function

Version 0.3.0 (2023-05-xx)
--------------------------
 * Adjustment to changes in `EnergyModelsBase` v0.4.0 and `EnergyModelsGeography` v 0.6.0
 * The new filter method for data can be used as example for subsequent usage of `Array{Data}`
 * Migrate from Requires.jl to support for weak dependencies in julia v1.9.

Version 0.2.8 (2023-05-15)
--------------------------
 * Fixed a bug that could lead to method ambiguity errors when a subtype of `Storage` required additional variables. This solution results in significant changes regarding where and how variables and constraints are declared.

Version 0.2.7 (2023-04-27)
--------------------------
* Requirements changed to ^0.5.0 for `EnergyModelsGeography`

Version 0.2.6 (2023-04-24)
--------------------------
 * Introduction of abstract type `InvestmentData` as subtype of `Data` to dispatch specifically on data related to investments
 * Changes in the individual utility functions for improved utilization of the multiple dispatch

Version 0.2.5 (2023-04-18)
--------------------------
 * Bugfix related to constraint on `cap_use`,  `stor_rate_use`, and `stor_level`:
    - The variables are constrained using the function `constraints_capacity` and in addition in `constraints_capacity_invest` and `constraints_storage_invest` with the latter constraint being inconsistent for `Sink` nodes.
    - The constraint in `EnergyModelsInvestments` was therefore removed

Version 0.2.4 (2023-03-31)
--------------------------
 * Removal of type `ContinuousFixedInvestment` as this can be represented with `ContinuousInvestment` and `Cap_max_add` limited to a given period
 * Introduction of abstract type `SemiContiInvestment` and composite type `SemiContinuousOffsetInvestment` to introduce semi-continuous investments in which the cost function has an offset. This is only included for Transmission in the first step

Version 0.2.3 (2023-03-20)
--------------------------
 * Adjustments in tests and functions to changes introduced in `EnergyModelsGeography` version 0.4.0

Version 0.2.2 (2023-02-17)
--------------------------
 * Adjustments in tests and functions to changes introduced in `EnergyModelsGeography` version 0.3.1

Version 0.2.1 (2023-02-06)
--------------------------
 * Renaming of investment modes:
    - Rename `DiscreteInvestment` to `BinaryInvestment`
    - Rename `IntegerInvestment` to `DiscreteInvestment`

Version 0.2.0 (2023-02-03)
--------------------------
### Adjustmends to updates in EnergyModelsBase
Adjustment to version 0.3.0, namely:
* Changed type (`Node`) calls in tests to be consistent with version 0.3.0
* Changed call of function for the creation of `Storage` variables
* Removal of the type `GlobalData` and replacement with fields in the type `InvestmentModel` in all tests

Version 0.1.5 (2022-12-12)
--------------------------
### Internal release
* Update Readme

Version 0.1.4 (2022-12-09)
--------------------------
### Changes in naming
 * Renamed dictionary keys from `EnergyModelsInvestments` to `Investments`

Version 0.1.3 (2022-30-11)
--------------------------
### Renamed to EnergyModelsInvestments
* Renamed for more internally consistent package names

Version 0.1.2 (2021-09-07)
--------------------------
### Changes in naming
* Major changes in both variable and parameter naming, check the commit message for an overview

Version 0.1.1 (2021-08-20)
--------------------------
* Inclusion for investment in storage (energy)
* Changes to the datastructures

Version 0.1.0 (2021-07-06)
--------------------------
* Initial version
* Inclusion of discounting
