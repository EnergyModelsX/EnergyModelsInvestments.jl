# [Update your model to the latest versions](@id sec_how_to_update)

`EnergyModelsInvestments` is still in a pre-release version.
Hence, there are frequently breaking changes occuring, although we plan to keep backwards compatibility.
This document is designed to provide users with information regarding how they have to adjust their models to keep compatibility to the latest changes.
We will as well implement information regarding the adjustment of extension packages, although this is more difficult due to the vast majority of potential changes.

## Adjustments from 0.5.x

### Key changes for investment type descriptions

Version 0.7 in `EnergyModelsBase` introduced the potential to have charge and discharge capacities through _storage parameters_.
This required hence a rework of how we model investments into storage nodes.
We decided to use this requirement as an approach for a full rework of the investment options, increasing the potential to make `EnergyModelsInvestments` independent of `EnergyModelsBase`.

The key changes are:

- All parameters for investment or lifetime modes are incorporated in the respective investment or lifetime mode.
- The previously used investment data, [`InvData`](@ref), [`InvDataStorage`](@ref), and [`TransInvData`](@ref), are replaced by [`SingleInvData`](@ref) (for standard node and transmission mode investments) and [`StorageInvData`](@ref) (for storage investments).
- CAPEX cariables are renamed:
  - `:capex_cap` is now `:cap_capex`,
  - `:capex_rate` is now given by `:stor_charge_capex` and `:stor_discharge_capex`,
  - `:capex_stor` is now given by `:stor_level_capex`, and
  - `:capex_trans` is now given by `:trans_cap_capex`.

!!! note
    The legacy constructors for calls of the composite type of version 0.5 will be included at least until version 0.7.

### [`InvData`](@ref) and [`TransInvData`](@ref)

The following changes are written down for `InvData`, but are equivalent for `TransInvData`.
The previous description for nodal investments was given by:

```julia
@kwdef struct InvData <: InvestmentData
    capex_cap::TimeProfile
    cap_max_inst::TimeProfile
    cap_max_add::TimeProfile
    cap_min_add::TimeProfile
    inv_mode::Investment = ContinuousInvestment()
    cap_start::Union{Real, Nothing} = nothing
    cap_increment::TimeProfile = FixedProfile(0)
    life_mode::LifetimeMode = UnlimitedLife()
    lifetime::TimeProfile = FixedProfile(0)
end
```

while the new type for single investments is given as

```julia
struct SingleInvData <: InvestmentData
    cap::AbstractInvData
end
```

with a constructor allowing directly the creation without having to specify the intermediate type.

The new type, [`AbstractInvData`](@ref) has at the time being two subtypes, [`NoStartInvData`](@ref) and [`StartInvData`](@ref), given as:

```julia
@kwdef struct NoStartInvData <: AbstractInvData
    capex::TimeProfile       # Capex to install cap
    max_inst::TimeProfile    # Max installable capacity in one period (in total)
    inv_mode::Investment
    life_mode::LifetimeMode
end

@kwdef struct StartInvData <: AbstractInvData
    capex::TimeProfile      # Capex to install cap
    max_inst::TimeProfile   # Max installable capacity in one period (in total)
    initial::Real           # Initially installed capacity
    inv_mode::Investment
    life_mode::LifetimeMode
end
```

Hence, the original `InvData` type would be translated as

```julia
# If no starting capacity was provided
SingleInvData(
    capex_cap,
    cap_max_inst,
    tmp_inv_mode,
    tmp_life_mode,
)

# If a starting capacity was provided
SingleInvData(
    capex_cap,
    cap_max_inst,
    cap_start,
    tmp_inv_mode,
    tmp_life_mode,
)

```

The translation of the parameters `cap_max_add`, `cap_min_add`, and `cap_increment` is dependent on the chosen investment mode, see below.
This makes the legacy constructor slightly more complex as it is necessary to check for the individual type.

### [`InvDataStorage`](@ref)

`InvDataStorage` was significantly reworked since version 0.5.
The total rework is provided below.

The previous description for storage investments was given by:

```julia
@kwdef struct InvDataStorage <: InvestmentData
    capex_rate::TimeProfile
    rate_max_inst::TimeProfile
    rate_max_add::TimeProfile
    rate_min_add::TimeProfile
    capex_stor::TimeProfile
    stor_max_inst::TimeProfile
    stor_max_add::TimeProfile
    stor_min_add::TimeProfile
    inv_mode::Investment = ContinuousInvestment()
    rate_start::Union{Real, Nothing} = nothing
    stor_start::Union{Real, Nothing} = nothing
    rate_increment::TimeProfile = FixedProfile(0)
    stor_increment::TimeProfile = FixedProfile(0)
    life_mode::LifetimeMode = UnlimitedLife()
    lifetime::TimeProfile = FixedProfile(0)
end
```

The new storage investment type is now layered, allowing for different options for the individual capacities given through the fields `charge`, `level`, and `discharge`:

```julia
@kwdef struct StorageInvData <: InvestmentData
    charge::Union{AbstractInvData, Nothing} = nothing
    level::Union{AbstractInvData, Nothing} = nothing
    discharge::Union{AbstractInvData, Nothing} = nothing
end
```

As outlined, [`AbstractInvData`](@ref) has at the time being two subtypes, [`NoStartInvData`](@ref) and [`StartInvData`](@ref).
Depending on whether you specified in your previous `InvDataStorage` instance the field `rate_start` and `stor_start`, you will have to use either [`NoStartInvData`](@ref) (not specified) or [`StartInvData`](@ref) (specified).

In addition, if you used the `rate` variables previously for the charge or discharge rate, you have to adjust the investment data slightly.
A [`RefStorage`](https://energymodelsx.github.io/EnergyModelsBase.jl/stable/library/public/#EnergyModelsBase.RefStorage) node from `EnergyModelsBase` would be given then as:

```julia
StorageInvData(
    charge = NoStartInvData(
        capex = capex_rate,
        max_inst = rate_max_inst,
        inv_mode = inv_mode,
        life_mode = life_mode,
    ),
    level = NoStartInvData(
        capex = capex_stor,
        max_inst = stor_max_inst,
        inv_mode = inv_mode,
        life_mode = life_mode,
    ),
)
```

while a node [`HydroStor`](https://energymodelsx.github.io/EnergyModelsRenewableProducers.jl/stable/library/public/#EnergyModelsRenewableProducers.HydroStor) from `EnergyModelsRenewableProducers`, in which the rate was used for the discharge, would be then given as:

```julia
StorageInvData(
    level = NoStartInvData(
        capex = capex_stor,
        max_inst = stor_max_inst,
        inv_mode = inv_mode,
        life_mode = life_mode,
    ),
    discharge = NoStartInvData(
        capex = capex_stor,
        max_inst = stor_max_inst,
        inv_mode = inv_mode,
        life_mode = life_mode,
    ),
)
```

The translation of the parameters `rate_max_add`, `rate_min_add`, `rate_increment`, `stor_max_add`, `stor_min_add`,  `stor_increment` is dependent on the chosen investment mode, see below.
This makes the legacy constructor slightly more complex as it is necessary to check for the individual type.

### [Investment modes](@ref sec_types_inv_mode)

Investment modes include now the required data.
This implies that the direct translation is now dependent on the individual investment mode.
Below, you can find the approach for `InvData` legacy constructors, although the approach is the same for `InvDataStorage` and `TransInvData`.

```julia
# DiscreteInvestment
inv_mode = DiscreteInvestment(cap_increment)

# ContinuousInvestment
inv_mode = ContinuousInvestment(cap_min_add, cap_max_add)

# SemiContinuousInvestment
inv_mode = SemiContinuousInvestment(cap_min_add, cap_max_add)

# SemiContinuousOffsetInvestment
inv_mode = SemiContinuousOffsetInvestment(trans_min_add, trans_max_add, capex_trans_offset)
```

!!! warning
    We do not provide any constructors for `BinaryInvestment` and `FixedInvestment` as it is not possible to deduce the capacity directly from the provided constructor.
    Instead, the model will throw an error.

`BinaryInvestment` and `FixedInvestment` can be solved using the following approach, outlined for a `Source` node:

```julia
# Consider the following Source node in which the investment_data_source used
# BinaryInvestment or FixedInvestment
source = RefSource(
    "electricity source",       # Node ID
    StrategicProfile([10, 15]), # Capacity in MW
    FixedProfile(10),           # Variable OPEX in EUR/MW
    FixedProfile(5),            # Fixed OPEX in EUR/year
    Dict(Power => 1),           # Output from the Node, in this gase, Power
    [investment_data_source],   # Additional data used for adding the investment data
)

# The original investment data type was given as
investment_data_source = InvData(
    capex_cap = FixedProfile(300000),   # CAPEX [€/MW]
    cap_max_inst = FixedProfile(30),    # max installed capacity [MW]
    cap_max_add = FixedProfile(30),     # max added capactity per sp [MW]
    cap_min_add = FixedProfile(0),      # min added capactity per sp [MW]
    inv_mode = FixedInvestments(),      # investment mode
    cap_start = 0,                      # initial capacity
    life_mode = RollingLife(),          # Lifetime mode
    lifetime = FixedProfile(15),        # Lifetime
)

# The new investment data type is then given as
investment_data_source = SingleInvData(
    FixedProfile(300*1e3),          # CAPEX [€/MW]
    FixedProfile(30),               # max installed capacity [MW]
    FixedProfile(0),                # max installed capacity [MW]
    FixedInvestments(StrategicProfile([10, 15])),
    # Line above: Investment mode with the following arguments:
    # New capacity in the strategic period, if invested in [MW]
    RollingLife(FixedProfile(15)),  # Lifetime mode
)
```

### [Lifetime modes](@ref life_mode)

Investment modes now include the required lifetime.
Below, you can find the approach for `InvData` legacy constructors, although the approach is the same for `InvDataStorage` and `TransInvData`.

```julia
# StudyLife
life_mode = StudyLife(lifetime)

# StudyLife
life_mode = PeriodLife(lifetime)

# StudyLife
life_mode = RollingLife(lifetime)
```
