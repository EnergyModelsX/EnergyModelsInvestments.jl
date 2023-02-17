Release Notes
=============

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
