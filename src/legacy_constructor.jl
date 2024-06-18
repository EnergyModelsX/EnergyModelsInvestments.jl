"""
    TransInvData(;
        capex_trans::TimeProfile,
        trans_max_inst::TimeProfile,
        trans_max_add::TimeProfile,
        trans_min_add::TimeProfile,
        inv_mode::Investment = ContinuousInvestment(),
        trans_start::Union{Real,Nothing} = nothing,
        trans_increment::TimeProfile = FixedProfile(0),
        capex_trans_offset::TimeProfile = FixedProfile(0),
    )

Legacy constructor for a `InvData`.

The new storage descriptions allows now for a reduction in functions which is used
to make `EnergModelsInvestments` less dependent on `EnergyModelsBase`.

The core changes to the existing structure is the move of the required parameters to the
type [`Investment`](@ref) (_e.g._, the minimum and maximum added capacity is only required
for investment mdodes that require these parameters) as well as moving the `lifetime` to the
type [`LifetimeMode`], when required.

See the _[documentation](https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/how-to/update-models)_
for further information regarding how you can translate your existing model to the new model.
"""
function TransInvData(;
    capex_trans::TimeProfile,
    trans_max_inst::TimeProfile,
    trans_max_add::TimeProfile,
    trans_min_add::TimeProfile,
    inv_mode::Investment = ContinuousInvestment(),
    trans_start::Union{Real,Nothing} = nothing,
    trans_increment::TimeProfile = FixedProfile(0),
    capex_trans_offset::TimeProfile = FixedProfile(0),
)
    # Create the new investment mode structures
    if isa(inv_mode, BinaryInvestment)
        @error(
            "BinaryInvestment() cannot use the constructor as it is not possible to " *
            "deduce the capacity for the investment. You have to instead use the new " *
            "types as outlined in the documentation (https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/how-to/update-models)"
        )
        return
    elseif isa(inv_mode, FixedInvestment)
        @error(
            "FixedInvestment() cannot use the constructor as it is not possible to " *
            "deduce the capacity for the investment. You have to instead use the new " *
            "types as outlined in the documentation (https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/how-to/update-models)"
        )
        return
    elseif isa(inv_mode, DiscreteInvestment)
        tmp_inv_mode = DiscreteInvestment(trans_increment)
    elseif isa(inv_mode, ContinuousInvestment)
        tmp_inv_mode = ContinuousInvestment(trans_min_add, trans_max_add)
    elseif isa(inv_mode, SemiContinuousInvestment)
        tmp_inv_mode = SemiContinuousInvestment(trans_min_add, trans_max_add)
    elseif isa(inv_mode, SemiContinuousOffsetInvestment)
        tmp_inv_mode =
            SemiContinuousOffsetInvestment(trans_min_add, trans_max_add, capex_trans_offset)
    end

    @warn(
        "The used implementation of a `TransInvData` will be discontinued in the near " *
        "future. See the documentation for the new implementation using the type " *
        "`SingleInvData` in the section on _How to update your model to the latest versions_.\n" *
        "The core change is that we allow the individual parameters are moved to the " *
        "field `inv_mode` and we allow now for `life_mode`.\n",
        maxlog = 1,
    )

    # Create the new generalized investment data
    if isnothing(trans_start)
        return SingleInvData(capex_trans, trans_max_inst, tmp_inv_mode)
    else
        return SingleInvData(capex_trans, trans_max_inst, trans_start, tmp_inv_mode)
    end
end
