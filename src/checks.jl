
function check_investment_data(n, 𝒯)
    inv_data = n.Data["InvestmentModels"]
 
    @assert_or_log sum(inv_data.Cap_min_add[t] ≤ inv_data.Cap_max_add[t] for t ∈ 𝒯) == length(𝒯) "min_add has to be less than max_add in investments data (Node.data)."

    for t ∈ 𝒯
        # Check that the installed capacity at the start is below the lower bound.
        @assert_or_log TimeStructures.getindex(n.Cap,t) <= inv_data.Cap_max_inst[t] "Existing capacity can not be larger than max installed capacity in the beginning."
        break
    end
end

function check_investment_data(n::EMB.Storage, 𝒯)
    inv_data = n.Data["InvestmentModels"]
 
    @assert_or_log sum(inv_data.Stor_min_add[t] ≤ inv_data.Stor_max_add[t] for t ∈ 𝒯) == length(𝒯) "Stor_min_add has to be less than Stor_max_add in investments data (Node.data)."
    @assert_or_log sum(inv_data.Rate_min_add[t] ≤ inv_data.Rate_max_add[t] for t ∈ 𝒯) == length(𝒯) "Rate_min_add has to be less than Rate_max_add in investments data (Node.data)."

    for t ∈ 𝒯
        # Check that the installed capacity at the start is below the lower bound.
        @assert_or_log TimeStructures.getindex(n.Stor_cap,t) <= inv_data.Stor_max_inst[t] "Existing storage capacity can not be larger than max installed capacity in the beginning."
        @assert_or_log TimeStructures.getindex(n.Rate_cap,t) <= inv_data.Rate_max_inst[t] "Existing storage rate can not be larger than max installed rate in the beginning."
        
        if !=(inv_data.Rate_start,nothing) && isfirst(t)
            @assert_or_log n.Rate_start <= inv_data.Rate_max_inst[t] "Starting storage rate can not be larger than max installed rate."
        end

        if !=(inv_data.Stor_start,nothing) && isfirst(t)
            @assert_or_log n.Stor_start <= inv_data.Stor_max_inst[t] "Starting storage capacity can not be larger than max installed storage capacity."
        end

        break
    end
        
end


function EMB.check_node(n::EMB.Node, 𝒯, modeltype::InvestmentModel)
    if hasfield(typeof(n), :Data) && haskey(n.Data, "InvestmentModels")
        check_investment_data(n, 𝒯)
    end

    # Do other checks not related to investments.
    EMB.check_node(n, 𝒯, EMB.OperationalModel())

end

# TODO
# - check that max_add and min_add only have strategic period resolution (and not for every operational period)
