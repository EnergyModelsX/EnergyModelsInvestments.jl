"""
    check_investment_data(n, 𝒯)

Performs various checks on investment data:
 - `min_add` has to be less than `max_add` in investments data.
 - Existing capacity can not be larger than `max_installed` capacity in the beginning.
 - TimeProfiles cannot include `OperationalProfile`, `RepresentativeProfile`, or `ScenarioProfile`
"""
function check_investment_data(n::EMB.Node, 𝒯)
    !has_investment(n) && return

    inv_data = filter(data -> typeof(data) <: InvestmentData, data(n))

    @assert_or_log length(inv_data) <= 1 "Only one InvestmentData can be added to each node"

    for field_name ∈ fieldnames(typeof(inv_data))
        time_profile = getfield(inv_data, field_name)
        !isa(time_profile, TimeProfile) && continue
        isa(time_profile, FixedProfile) && continue
        @assert_or_log isa(time_profile, OperationalProfile) "Operational profiles are not allowed for the field :"*String(field_name)
        @assert_or_log isa(time_profile, ScenarioProfile) "Scenario profiles are not allowed for the field :"*String(field_name)
        @assert_or_log isa(time_profile, RepresentativeProfile) "Representative profiles are not allowed for the field :"*String(field_name)
        if isa(time_profile, StrategicProfile)
            @assert_or_log isa(time_profile.vals, Vector{<:OperationalProfile}) "Operational profiles in strategic profiles are not allowed for the field :"*String(field_name)
            @assert_or_log isa(time_profile.vals, Vector{<:ScenarioProfile}) "Scenario profiles in strategic profiles are not allowed for the field :"*String(field_name)
            @assert_or_log isa(time_profile.vals, Vector{<:RepresentativeProfile}) "Representative profiles in strategic profiles are not allowed for the field :"*String(field_name)
        end
    end

    @assert_or_log sum(min_add(n, t) ≤ max_add(n, t) for t ∈ 𝒯) == length(𝒯) "min_add has to be less than max_add in investments data (Node.Data)."

    cap = capacity(n)
    t_1 = collect(𝒯)[1]
    @assert_or_log cap[t_1] ≤ max_installed(n, t_1) "Existing capacity can not be larger than max installed capacity in the beginning."
end


function check_investment_data(n::Storage, 𝒯)

    !has_investment(n) && return

    inv_data = filter(data -> typeof(data) <: InvestmentData, data(n))

    @assert_or_log length(inv_data) <= 1 "Only one InvestmentData can be added to each node"

    @assert_or_log typeof(inv_data) == InvDataStorage "The investment data for a Storage must be of type `InvDataStorage`."

    for field_name ∈ fieldnames(typeof(inv_data))
        time_profile = getfield(inv_data, field_name)
        !isa(time_profile, TimeProfile) && continue
        isa(time_profile, FixedProfile) && continue
        @assert_or_log isa(time_profile, OperationalProfile) "Operational profiles are not allowed for the field :"*String(field_name)
        @assert_or_log isa(time_profile, ScenarioProfile) "Scenario profiles are not allowed for the field :"*String(field_name)
        @assert_or_log isa(time_profile, RepresentativeProfile) "Representative profiles are not allowed for the field :"*String(field_name)
        if isa(time_profile, StrategicProfile)
            @assert_or_log isa(time_profile.vals, Vector{<:OperationalProfile}) "Operational profiles in strategic profiles are not allowed for the field :"*String(field_name)
            @assert_or_log isa(time_profile.vals, Vector{<:ScenarioProfile}) "Scenario profiles in strategic profiles are not allowed for the field :"*String(field_name)
            @assert_or_log isa(time_profile.vals, Vector{<:RepresentativeProfile}) "Representative profiles in strategic profiles are not allowed for the field :"*String(field_name)
        end
    end

    @assert_or_log sum(min_add(n, t).level ≤ max_add(n, t).level for t ∈ 𝒯) == length(𝒯) "Stor_min_add has to be less than Stor_max_add in investments data (Node.Data)."
    @assert_or_log sum(min_add(n, t).rate ≤ max_add(n, t).rate for t ∈ 𝒯) == length(𝒯) "Rate_min_add has to be less than Rate_max_add in investments data (Node.Data)."

    for t ∈ 𝒯
        # Check that the installed capacity at the start is below the lower bound.
        @assert_or_log capacity(n, t).level <= max_installed(n, t).level "Existing storage capacity can not be larger than max installed capacity in the beginning."
        @assert_or_log capacity(n, t).rate <= max_installed(n, t).rate "Existing storage rate can not be larger than max installed rate in the beginning."

        if !=(inv_data.rate_start,nothing) && isfirst(t)
            @assert_or_log n.rate_start <= max_installed(n, t).rate "Starting storage rate can not be larger than max installed rate."
        end

        if !=(inv_data.stor_start,nothing) && isfirst(t)
            @assert_or_log n.stor_start <= max_installed(n, t).level "Starting storage capacity can not be larger than max installed storage capacity."
        end

        break
    end
end

"""
    check_data(case, modeltype)

Check if the case data is consistent. Use the @assert_or_log macro when testing.
Currently only checking node data.
"""
function check_data(case, modeltype::AbstractInvestmentModel)
    # TODO would it be useful to create an actual type for case, instead of using a Dict with
    # naming conventions? Could be implemented as a mutable in energymodelsbase.jl maybe?

    # TODO this usage of the global vector 'logs' doesn't seem optimal. Should consider using
    #   the actual logging macros underneath instead.
    global logs = []
    log_by_element = Dict()

    𝒯 = case[:T]

    for n ∈ case[:nodes]
        # Empty the logs list before each check.
        global logs = []
        check_investment_data(n, 𝒯)
        check_node(n, 𝒯, modeltype)
        check_time_structure(n, 𝒯)
        # Put all log messages that emerged during the check, in a dictionary with the node as key.
        log_by_element[n] = logs
    end

    logs = []
    check_model(case, modeltype)
    log_by_element[modeltype] = logs

    if ASSERTS_AS_LOG
        compile_logs(case, log_by_element)
    end
end
