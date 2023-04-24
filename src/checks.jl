"""
    check_investment_data(n, 𝒯)

Performs various checks on investment data:
 - min_add has to be less than max_add in investments data (Node.Data).
 - Existing capacity can not be larger than max installed capacity in the beginning.
"""
function check_investment_data(n, 𝒯)
    !haskey(n.Data, "Investments") && return
    inv_data = n.Data["Investments"]
 
    @assert_or_log sum(inv_data.Cap_min_add[t] ≤ inv_data.Cap_max_add[t] for t ∈ 𝒯) == length(𝒯) "min_add has to be less than max_add in investments data (Node.Data)."

    t_1 = collect(𝒯)[1]
    @assert_or_log n.Cap[t_1] ≤ inv_data.Cap_max_inst[t_1] "Existing capacity can not be larger than max installed capacity in the beginning."
end


function EMB.check_node(n::Source, 𝒯, modeltype::InvestmentModel)
    check_investment_data(n, 𝒯)

    operational_model = EMB.OperationalModel(modeltype.Emission_limit, modeltype.CO2_instance)
    # Do other checks not related to investments.
    EMB.check_node(n, 𝒯, operational_model)
end


function EMB.check_node(n::Network, 𝒯, modeltype::InvestmentModel)
    hasfield(typeof(n), :Data) && check_investment_data(n, 𝒯)

    # Do other checks not related to investments.
    operational_model = EMB.OperationalModel(modeltype.Emission_limit, modeltype.CO2_instance)
    EMB.check_node(n, 𝒯, operational_model)
end


function EMB.check_node(n::Storage, 𝒯, modeltype::InvestmentModel)

    if has_investment(n)
        inv_data = n.Data["Investments"]

        @assert_or_log typeof(inv_data) == extra_inv_data_storage "The investment data for a Storage must be of type `extra_inv_data_storage`."
    
        @assert_or_log sum(inv_data.Stor_min_add[t] ≤ inv_data.Stor_max_add[t] for t ∈ 𝒯) == length(𝒯) "Stor_min_add has to be less than Stor_max_add in investments data (Node.Data)."
        @assert_or_log sum(inv_data.Rate_min_add[t] ≤ inv_data.Rate_max_add[t] for t ∈ 𝒯) == length(𝒯) "Rate_min_add has to be less than Rate_max_add in investments data (Node.Data)."

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
    
    # Do other checks not related to investments.
    operational_model = EMB.OperationalModel(modeltype.Emission_limit, modeltype.CO2_instance)
    EMB.check_node(n, 𝒯, operational_model)
end


# TODO
# - check that max_add and min_add only have strategic period resolution (and not for every operational period)
