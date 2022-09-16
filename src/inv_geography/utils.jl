const GEO = Geography

"""
    has_trans_investment(i)

For a given transmission, checks that it contains extra data
(i.Data : list containing the extra data of the different corridor modes) and that 
at leat one corridor mode has investment data defined.
 """
function has_trans_investment(i)
    isa(i, GEO.Transmission) && 
    (
        hasproperty(i, :Data) && 
        haskey(i.Data, "InvestmentModels") && 
        !isempty(i.Data["InvestmentModels"]) && 
        any(x -> x != EMB.EmptyData(), values(i.Data["InvestmentModels"]))
    )
end

"""
    has_cm_investment(cm,l)
    
For a given transmission and corridor mode, checks that it contains extra data:
 - Trans_max_inst
 - Capex_trans
 - Trans_max_add
 - Trans_min_add
 """
function has_cm_investment(cm,l)
    isa(cm, GEO.TransmissionMode) &&
    isa(l, GEO.Transmission) &&
    cm ∈ l.Modes  &&
    haskey(l.Data, "InvestmentModels") &&
    (
        hasproperty(l.Data["InvestmentModels"][cm], :Trans_max_inst) ||
        hasproperty(l.Data["InvestmentModels"][cm], :Capex_trans) ||
        hasproperty(l.Data["InvestmentModels"][cm], :Trans_max_add) ||
        hasproperty(l.Data["InvestmentModels"][cm], :Trans_min_add)
    )
end

"""
    corridor_modes_with_inv(l)
    
Returns a list of corridors modes that have non empty investment data for a given transmission line 
"""
function corridor_modes_with_inv(l)
    if "InvestmentModels" ∈ keys(l.Data)
        return [m for m ∈ l.Modes if (!=(typeof(l.Data["InvestmentModels"][m]), EMB.EmptyData))]
    else
        return []
    end
end

"""
    investmentmode(cm::GEO.TransmissionMode,l::GEO.Transmission) 

Returns the investment mode for a given `Transmission` l and `TransmissionMode` cm.
"""
investmentmode(cm::GEO.TransmissionMode,l::GEO.Transmission) = l.Data["InvestmentModels"][cm].Inv_mode
