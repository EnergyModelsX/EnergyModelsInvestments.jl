"""
    StartInvData(
        capex_trans::TimeProfile,
        trans_max_inst::TimeProfile,
        initial::Real,
        inv_mode::Investment,
        life_mode::LifetimeMode,    # This value is conditional
    )

Legacy constructor for a `StartInvData`.
This version will be discontinued in the near future and replaced with the new version of
in which the initial capacity is instead given as `TimeProfile`,

See the *[documentation](https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/how-to/update-models/)*
for further information regarding how you can translate your existing model to the new model.
"""
function StartInvData(
    capex_trans::TimeProfile,
    trans_max_inst::TimeProfile,
    initial::Real,
    inv_mode::Investment,
)
    @warn(
        "The used implementation of a `StartInvData` will be discontinued in the near future.\n" *
        "You have to only change the value of the field `initial` to a `FixedProfile` " *
        "for utilizing the new version.",
        maxlog = 1
    )
    return StartInvData(
        capex_trans,
        trans_max_inst,
        FixedProfile(initial),
        inv_mode,
        UnlimitedLife(),
    )
end

function StartInvData(
    capex_trans::TimeProfile,
    trans_max_inst::TimeProfile,
    initial::Real,
    inv_mode::Investment,
    life_mode::LifetimeMode,
)
    @warn(
        "The used implementation of a `StartInvData` will be discontinued in the near future.\n" *
        "You have to only change the value of the field `initial` to a `FixedProfile` " *
        "for utilizing the new version.",
        maxlog = 1
    )
    return  StartInvData(
        capex_trans,
        trans_max_inst,
        FixedProfile(initial),
        inv_mode,
        life_mode,
    )
end
