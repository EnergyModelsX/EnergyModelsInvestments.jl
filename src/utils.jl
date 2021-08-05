"""
    has_capacity(i)

Check if node i should be used for capacity calculations, i.e.
    * is not Availability
    * has capacity

    TODO: Move to EMB?
"""
function testdata()
    data = EMB.read_data("")
end

function has_capacity(i)
    ~isa(i, EMB.Availability) && 
    (
        hasproperty(i, :capacity) 
    )
end

function has_investment(i)
    ~isa(i, EMB.Availability) && 
    (
        hasproperty(i, :data) &&
        (
            hasproperty(i.data["InvestmentModels"], :max_inst_cap) ||
            hasproperty(i.data["InvestmentModels"], :capex) ||
            hasproperty(i.data["InvestmentModels"], :ExistingCapacity) ||
            hasproperty(i.data["InvestmentModels"], :min_add) ||
            hasproperty(i.data["InvestmentModels"], :min_add)
        )
    )
end
