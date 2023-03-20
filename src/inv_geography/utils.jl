const GEO = EnergyModelsGeography

"""
    has_investment(cm::GEO.TransmissionMode)

For a given `TransmissionMode`, checks that it contains ithe required investment data.
"""
function has_investment(cm::GEO.TransmissionMode)
    (
        hasproperty(cm, :Data) && 
        haskey(cm.Data, "Investments") && 
        typeof(cm.Data["Investments"]) == TransInvData
    )
end

"""
    has_investment(𝒞ℳ::Vector{<:GEO.TransmissionMode})

For a given `Vector{<:TransmissionMode}`, return all `TransmissionMode`s with investments.
"""
function has_investment(𝒞ℳ::Vector{<:GEO.TransmissionMode})

    return [cm for cm ∈ 𝒞ℳ if has_investment(cm)]
end

"""
    investmentmode(cm::GEO.TransmissionMode) 

Returns the investment mode for a given`TransmissionMode` cm.
"""
investmentmode(cm::GEO.TransmissionMode) = cm.Data["Investments"].Inv_mode