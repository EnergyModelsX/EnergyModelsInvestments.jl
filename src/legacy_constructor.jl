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

    # Create the new investment mode structures
    if isa(inv_mode, BinaryInvestment)
        inv_mode_rate = BinaryInvestment()
        inv_mode_cap = BinaryInvestment()
    elseif isa(inv_mode, FixedInvestment)
        inv_mode_rate = FixedInvestment()
        inv_mode_cap = FixedInvestment()
    elseif isa(inv_mode, DiscreteInvestment)
        inv_mode_rate = DiscreteInvestment(rate_increment)
        inv_mode_cap = DiscreteInvestment(stor_increment)
    elseif isa(inv_mode, ContinuousInvestment)
        inv_mode_rate = ContinuousInvestment(rate_max_add, rate_min_add)
        inv_mode_cap = ContinuousInvestment(stor_max_add, stor_min_add)
    elseif isa(inv_mode, SemiContinuousInvestment)
        inv_mode_rate = SemiContinuousInvestment(rate_max_add, rate_min_add)
        inv_mode_cap = SemiContinuousInvestment(stor_max_add, stor_min_add)
    end

    # Create the new lifetime mode structures
    if isa(life_mode, UnlimitedLife)
        tmp_life_mode = UnlimitedLife()
    elseif isa(life_mode, StudyLife)
        tmp_life_mode = StudyLife(lifetime)
    elseif isa(life_mode, PeriodLife)
        tmp_life_mode = PeriodLife(lifetime)
    elseif isa(life_mode, RollingLife)
        tmp_life_mode = RollingLife(lifetime)
    end

    # Create the new generalized investment data
    if isnothing(rate_start)
        charge_type = NoStartInvData(
            capex = capex_rate,
            max_inst = rate_max_inst,
            inv_mode = inv_mode_rate,
            life_mode = tmp_life_mode,
        )
    else
        charge_type = StartInvData(
            capex = capex_rate,
            max_inst = rate_max_inst,
            initial = rate_start,
            inv_mode = inv_mode_rate,
            life_mode = tmp_life_mode,
        )
    end
    if isnothing(stor_start)
        level_type = NoStartInvData(
            capex = capex_stor,
            max_inst = stor_max_inst,
            inv_mode = inv_mode_cap,
            life_mode = tmp_life_mode,
        )
    else
        level_type = StartInvData(
            capex = capex_stor,
            max_inst = stor_max_inst,
            initial = stor_start,
            inv_mode = inv_mode_cap,
            life_mode = tmp_life_mode,
        )
    end

    return StorageInvData(
        charge = charge_type,
        level = level_type,
    )
end

DiscreteInvestment() = DiscreteInvestment(FixedProfile(0))
ContinuousInvestment() = ContinuousInvestment(FixedProfile(0), FixedProfile(0))
SemiContinuousInvestment() = SemiContinuousInvestment(FixedProfile(0), FixedProfile(0))
SemiContinuousOffsetInvestment() = SemiContinuousOffsetInvestment(FixedProfile(0), FixedProfile(0), FixedProfile(0))

StudyLife() = StudyLife(FixedProfile(0))
PeriodLife() = PeriodLife(FixedProfile(0))
RollingLife() = RollingLife(FixedProfile(0))
