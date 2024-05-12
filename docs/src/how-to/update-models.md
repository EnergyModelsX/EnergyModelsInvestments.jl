# [Update your model to the latest versions](@id sec_how_to_update)

`EnergyModelsInvestments` is still in a pre-release version.
Hence, there are frequently breaking changes occuring, although we plan to keep backwards compatibility.
This document is designed to provide users with information regarding how they have to adjust their models to keep compatibility to the latest changes.
We will as well implement information regarding the adjustment of extension packages, although this is more difficult due to the vast majority of potential changes.

## Adjustments from 0.5.x

### Key changes for investment type descriptions

Version 0.7 in `EnergyModelsBase` introduced the potential to have charge and discharge capacities through _storage parameters_.
This required hence a rework of how we model investments into storage nodes.
We decided to use this requirement as potential for a full rework of the investment options, increasing the latter potential make `EnergyModelsInvestments` independent of `EnergyModelsBase`.

!!! note
    The legacy constructors for calls of the composite type of version 0.5 will be included at least until version 0.7.

### [`InvDataStorage`](@ref)

`InvDataStorage` was significantly reworked since version 0.5.
The total rework is provided below.

The previous description for storage investments was given by:

```julia
InvDataStorage(;
    capex_rate::TimeProfile,
    rate_max_inst::TimeProfile,
    rate_max_add::TimeProfile,
    rate_min_add::TimeProfile,
    capex_stor::TimeProfile,
    stor_max_inst::TimeProfile,
    stor_max_add::TimeProfile,
    stor_min_add::TimeProfile,
    inv_mode::Investment = ContinuousInvestment(),
    rate_start::Union{Real, Nothing} = nothing,
    stor_start::Union{Real, Nothing} = nothing,
    rate_increment::TimeProfile = FixedProfile(0),
    stor_increment::TimeProfile = FixedProfile(0),
    life_mode::LifetimeMode = UnlimitedLife(),
    lifetime::TimeProfile = FixedProfile(0),
)
```

The new storage investment type is now layered, allowing for different options for the individual capacities given through the fields `charge`, `level`, and `discharge`:

```julia
@kwdef struct StorageInvData <: InvestmentData
    charge::Union{GeneralInvData, Nothing} = nothing
    level::Union{GeneralInvData, Nothing} = nothing
    discharge::Union{GeneralInvData, Nothing} = nothing
end
```

The new type, [`GeneralInvData`](@ref) has at the time being two subtypes, [`NoStartInvData`](@ref) and [`StartInvData`](@ref), given as:

```julia
@kwdef struct NoStartInvData <: GeneralInvData
    capex::TimeProfile       # Capex to install cap
    max_inst::TimeProfile    # Max installable capacity in one period (in total)
    max_add::TimeProfile     # Max capacity that can be added in one period
    min_add::TimeProfile     # Min capacity that can be added in one period
    inv_mode::Investment = ContinuousInvestment()
    increment::TimeProfile  = FixedProfile(0)
    life_mode::LifetimeMode = UnlimitedLife()
    lifetime::TimeProfile  = FixedProfile(0)
end

@kwdef struct StartInvData <: GeneralInvData
    capex::TimeProfile      # Capex to install cap
    max_inst::TimeProfile   # Max installable capacity in one period (in total)
    max_add::TimeProfile    # Max capacity that can be added in one period
    min_add::TimeProfile    # Min capacity that can be added in one period
    initial::Real           # Initially installed capacity
    inv_mode::Investment = ContinuousInvestment()
    increment::TimeProfile  = FixedProfile(0)
    life_mode::LifetimeMode = UnlimitedLife()
    lifetime::TimeProfile  = FixedProfile(0)
end
```

The introduction of two types simplifies the implementation of an initial capacity.
Depending on whether you specified in your previous `InvDataStorage` instance the field `rate_start` and `stor_start`, you will have to use either [`NoStartInvData`](@ref) (not specified) or [`StartInvData`](@ref) (specified).

In addition, if you used the `rate` variables previously for the charge or discharge rate, you have to adjust the investment data slightly.
A [`RefStorage`](https://energymodelsx.github.io/EnergyModelsBase.jl/stable/library/public/#EnergyModelsBase.RefStorage) node from `EnergyModelsBase` would be given then as:

```julia
StorageInvData(
    charge = NoStartInvData(
        capex = capex_rate,
        max_inst = rate_max_inst,
        max_add = rate_max_add,
        min_add = rate_min_add,
        inv_mode = inv_mode,
        increment = rate_increment,
        life_mode = life_mode,
        lifetime = lifetime,
    ),
    level = NoStartInvData(
        capex = capex_stor,
        max_inst = stor_max_inst,
        max_add = stor_max_add,
        min_add = stor_min_add,
        inv_mode = inv_mode,
        increment = stor_increment,
        life_mode = life_mode,
        lifetime = lifetime,
    ),
)
```

while a node [`HydroStor`](https://energymodelsx.github.io/EnergyModelsRenewableProducers.jl/stable/library/public/#EnergyModelsRenewableProducers.HydroStor) from `EnergyModelsRenewableProducers`, in which the rate was used for the discharge, would be given then as:

```julia
StorageInvData(
    level = NoStartInvData(
        capex = capex_stor,
        max_inst = stor_max_inst,
        max_add = stor_max_add,
        min_add = stor_min_add,
        inv_mode = inv_mode,
        increment = stor_increment,
        life_mode = life_mode,
        lifetime = lifetime,
    ),
    discharge = NoStartInvData(
        capex = capex_rate,
        max_inst = rate_max_inst,
        max_add = rate_max_add,
        min_add = rate_min_add,
        inv_mode = inv_mode,
        increment = rate_increment,
        life_mode = life_mode,
        lifetime = lifetime,
    ),
)
```
