
function check_investment_data(n, 𝒯)
    inv_data = n.data["InvestmentModels"]
 
    @assert_or_log sum(inv_data.min_add[t] ≤ inv_data.max_add[t] for t ∈ 𝒯) == length(𝒯) "min_add has to be less than max_add in investments data (Node.data)."

    for t ∈ 𝒯
        # Check that the installed capacity at the start is below the lower bound.
        @assert_or_log TimeStructures.getindex(n.capacity,t) <= inv_data.max_inst_cap[t] "Existing capacity can not be larger than max installed capacity in the beginning."
        break
    end
end


function EMB.check_node(n::EMB.Node, 𝒯, modeltype::InvestmentModel)
    if hasfield(typeof(n), :data) && haskey(n.data, "InvestmentModels")
        check_investment_data(n, 𝒯)
    end

    # Do other checks not related to investments.
    EMB.check_node(n, 𝒯, EMB.OperationalModel(modeltype.case))

end

# TODO
# - check that max_add and min_add only have strategic period resolution (and not for every operational period)
