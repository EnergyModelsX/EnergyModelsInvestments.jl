"""
    testdata()

Read dummy data from EnergyModelsBase
"""
function testdata()
    data = EMB.read_data("")
end

"""
    has_capacity(i)

Check if node i should be used for capacity calculations, i.e.
    * is not Availability
    * has capacity

Can also be used for storages.

    TODO: Move to EMB?
"""
function has_capacity(i)
    ~isa(i, EMB.Availability) && 
    (
        hasproperty(i, :Cap) ||
        (hasproperty(i, :Rate_cap) && hasproperty(i, :Stor_cap))
    )
end

"""
    has_stor_capacity(i)

Check if storage node i should be used for capacity calculations, i.e.
    * is not Availability
    * has capacity for rate and storage volume

Can only be used for storages.
"""
function has_stor_capacity(i)
    ~isa(i, EMB.Availability) && 
    (
        (hasproperty(i, :Rate_cap) && hasproperty(i, :Stor_cap))
    )
end

"""
    has_investment(i)

Check if node i should be used for investment analysis, i.e.
    * is not Availability
    * has investment data that contains at least:
        *Capex_Cap
        *Cap_max_inst
        *Cap_max_add
        *Cap_min_add

"""
function has_investment(i)
    ~isa(i, EMB.Availability) && 
    (
        hasproperty(i, :Data) && (
            haskey(i.Data,"EnergyModelsInvestments") &&
            (
                hasproperty(i.Data["EnergyModelsInvestments"], :Capex_Cap) ||
                hasproperty(i.Data["EnergyModelsInvestments"], :Cap_max_inst) ||
                hasproperty(i.Data["EnergyModelsInvestments"], :Cap_max_add) ||
                hasproperty(i.Data["EnergyModelsInvestments"], :Cap_min_add)
            )
        )
    )
end

"""
has_storage_investment(i)

Check if storage node i should be used for investment analysis, i.e.
    * is not Availability
    * has investment data that contains at least:
        *Capex_stor
        *Stor_max_inst
        *Stor_max_add
        *Stor_min_add
"""
function has_storage_investment(i)
    ~isa(i, EMB.Availability) && 
    (
        hasproperty(i, :Data) && (
            haskey(i.Data,"EnergyModelsInvestments") &&
            (
                hasproperty(i.Data["EnergyModelsInvestments"], :Capex_stor) ||
                hasproperty(i.Data["EnergyModelsInvestments"], :Stor_max_inst) ||
                hasproperty(i.Data["EnergyModelsInvestments"], :Stor_max_add) ||
                hasproperty(i.Data["EnergyModelsInvestments"], :Stor_min_add)
            )
        )
    )
end
