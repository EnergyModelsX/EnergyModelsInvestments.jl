"""
Legacy constructor for a `InvDataStorage`.

Storage descriptions were changed in EnergyModelsBase v0.7 resulting in the requirement for
rewriting the investment options for `Storage` nodes.

See the documentation for further information regarding how you can translate your existing
model to the new model.
"""
function InvDataStorage(;
    #Investment data related to storage power
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


    @warn(
        "The used implementation of a `InvDataStorage` will be discontinued in the near " *
        "future. See the documentation for the new implementation using the type " *
        "`StorageInvData` in the section on _How to update your model to the latest " *
        "versions_.\n" *
        "The core change is that we allow now for individual investments in `charge`, " *
        "`level`, as well `discharge` capacities.\n" *
        "This constructore should NOT be used for `HydroStor` or `PumpedHydroStor nodes " *
        "introduced in the package [EnergyModelsRenewableProducers]" *
        "(https://energymodelsx.github.io/EnergyModelsRenewableProducers.jl/stable/library/public/#EnergyModelsRenewableProducers.HydroStor)."
    )

    if isnothing(rate_start)
        charge_type = NoStartInvData(
            capex = capex_rate,
            max_inst = rate_max_inst,
            max_add = rate_max_add,
            min_add = rate_min_add,
            inv_mode = inv_mode,
            increment = rate_increment,
            life_mode = life_mode,
            lifetime = lifetime,
        )
    else
        charge_type = StartInvData(
            capex = capex_rate,
            max_inst = rate_max_inst,
            max_add = rate_max_add,
            min_add = rate_min_add,
            initial = rate_start,
            inv_mode = inv_mode,
            increment = rate_increment,
            life_mode = life_mode,
            lifetime = lifetime,
        )
    end
    if isnothing(stor_start)
        level_type = NoStartInvData(
            capex = capex_stor,
            max_inst = stor_max_inst,
            max_add = stor_max_add,
            min_add = stor_min_add,
            inv_mode = inv_mode,
            increment = stor_increment,
            life_mode = life_mode,
            lifetime = lifetime,
        )
    else
        level_type = StartInvData(
            capex = capex_stor,
            max_inst = stor_max_inst,
            max_add = stor_max_add,
            min_add = stor_min_add,
            initial = stor_start,
            inv_mode = inv_mode,
            increment = stor_increment,
            life_mode = life_mode,
            lifetime = lifetime,
        )
    end

    return StorageInvData(
        charge = charge_type,
        level = level_type,
    )
end
