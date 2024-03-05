"""
   EMB.check_node_data(n::EMB.Node, data::InvestmentData, 𝒯, modeltype::AbstractInvestmentModel)

Performs various checks on investment data for standard nodes.

## Checks
- Each node can only have a single `InvestmentData`.
- For each field with `TimeProfile`:
    - If the `TimeProfile` is a `StrategicProfile`, it will check that the profile is in \
    accordance with the `TimeStructure`
    - `TimeProfile`s in `InvestmentData` cannot include `OperationalProfile`, \
    `RepresentativeProfile`, or `ScenarioProfile` as this is not allowed through indexing \
    on the `TimeProfile`.
- The field `:cap_min_add` has to be less than `:cap_max_add` in `InvestmentData`.
- Existing capacity cannot be larger than `:cap_max_inst` capacity in the beginning. \
If `cap_start` is `nothing`, it also checks that the the field `:cap` of the node `n` \
is not including `OperationalProfile`, `RepresentativeProfile`, or `ScenarioProfile`.
"""
function EMB.check_node_data(n::EMB.Node, data::InvestmentData, 𝒯, modeltype::AbstractInvestmentModel)

    inv_data = filter(data -> typeof(data) <: InvestmentData, node_data(n))
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    t_inv_1 = collect(𝒯)[1]

    @assert_or_log(
        length(inv_data) <= 1,
        "Only one `InvestmentData` can be added to each node."
    )

    for field_name ∈ fieldnames(typeof(data))
        time_profile = getfield(data, field_name)
        !isa(time_profile, TimeProfile) && continue
        isa(time_profile, FixedProfile) && continue
        message = "are not allowed for the field: "*String(field_name)

        if isa(time_profile, StrategicProfile)
            @assert_or_log(
                length(time_profile.vals) == length(𝒯ᴵⁿᵛ),
                "Field '" * string(field_name) * "' does not match the strategic structure."
            )
        end
        check_invest_profile(time_profile, message)
    end

    if isnothing(data.cap_start)
        time_profile = capacity(n)
        message = "are not allowed for the capacity, if investments are allowed and the \
            field `cap_start` is `nothing`."
        check_invest_profile(time_profile, message)

        cap = capacity(n)
        @assert_or_log(
            cap[t_inv_1] ≤ max_installed(n, t_inv_1),
            "Existing capacity can not be larger than max installed capacity in the beginning."
        )
    else
        @assert_or_log(
            data.cap_start ≤ max_installed(n, t_inv_1),
            "Existing capacity can not be larger than max installed capacity in the beginning."
        )

    end

    @assert_or_log(
        sum(min_add(n, t) ≤ max_add(n, t) for t ∈ 𝒯) == length(𝒯),
        "min_add has to be less than max_add in investments data (n.data)."
    )

end
"""
   EMB.check_node_data(n::Storage, data::InvestmentData, 𝒯, modeltype::AbstractInvestmentModel)

Performs various checks on investment data for standard nodes. It is similar to the standard
check nodes functions, but adds checks on

## Checks
- Each node can only have a single `InvestmentData`.
- The `InvestmentData` must be `InvDataStorage`.
- For each field with `TimeProfile`:
    - If the `TimeProfile` is a `StrategicProfile`, it will check that the profile is in \
    accordance with the `TimeStructure`
    - `TimeProfile`s in `InvestmentData` cannot include `OperationalProfile`, \
    `RepresentativeProfile`, or `ScenarioProfile` as this is not allowed through indexing \
    on the `TimeProfile`.
- The field `:rate_min_add` has to be less than `:rate_max_add` in `InvDataStorage`.
- The field `:stor_min_add` has to be less than `:stor_max_add` in `InvDataStorage`.
- Existing capacity cannot be larger than `:rate_max_inst` capacity in the beginning. \
If `rate_start` is `nothing`, it also checks that the the field `:stor_rate` of the node \
`n` is not including `OperationalProfile`, `RepresentativeProfile`, or `ScenarioProfile`.
- Existing capacity cannot be larger than `:stor_max_inst` capacity in the beginning. \
If `stor_start` is `nothing`, it also checks that the the field `:stor_cap` of the node \
`n` is not including `OperationalProfile`, `RepresentativeProfile`, or `ScenarioProfile`.
"""
function EMB.check_node_data(n::Storage, data::InvestmentData, 𝒯, modeltype::AbstractInvestmentModel)

    inv_data = filter(data -> typeof(data) <: InvestmentData, node_data(n))
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    t_inv_1 = collect(𝒯)[1]

    @assert_or_log(
        length(inv_data) <= 1,
        "Only one InvestmentData can be added to each node"
    )

    @assert_or_log(
        isa(typeof(data), InvDataStorage),
        "The investment data for a Storage must be of type `InvDataStorage`."
    )

    if !isa(typeof(data), InvDataStorage)
        return
    end

    for field_name ∈ fieldnames(typeof(data))
        time_profile = getfield(data, field_name)
        !isa(time_profile, TimeProfile) && continue
        isa(time_profile, FixedProfile) && continue
        message = "are not allowed for the field: "*String(field_name)

        if isa(time_profile, StrategicProfile)
            @assert_or_log(
                length(time_profile.vals) == length(𝒯ᴵⁿᵛ),
                "Field '" * string(field_name) * "' does not match the strategic structure."
            )
        end
        check_invest_profile(time_profile, message)
    end

    if isnothing(data.rate_start)
        time_profile = capacity(n).rate
        message = "are not allowed for the rate capacity, if investments are allowed and \
            the field `rate_start` is `nothing`."
        check_invest_profile(time_profile, message)

        @assert_or_log(
            capacity(n, t_inv_1).rate <= max_installed(n, t_inv_1).rate,
            "Existing storage rate can not be larger than max installed rate in the \
            beginning."
        )
    else
        @assert_or_log(
            data.rate_start <= max_installed(n, t_inv_1).rate,
            "Starting storage rate can not be larger than max installed rate."
        )
    end
    if isnothing(data.stor_start)
        time_profile = capacity(n).level
        message = "are not allowed for the storage capacity, if investments are allowed \
            and the field `stor_start` is `nothing`."
        check_invest_profile(time_profile, message)

        @assert_or_log(
            capacity(n, t_inv_1).level <= max_installed(n, t_inv_1).level,
            "Existing storage capacity can not be larger than max installed capacity in \
            the beginning."
        )
    else
        @assert_or_log(
            data.stor_start <= max_installed(n, t_inv_1).level,
            "Starting storage capacity can not be larger than max installed storage \
            capacity."
        )
    end

    @assert_or_log(
        sum(min_add(n, t).level ≤ max_add(n, t).level for t ∈ 𝒯) == length(𝒯),
        "`stor_min_add` has to be less than `stor_max_add` in investments data (n.data)."
    )
    @assert_or_log(
        sum(min_add(n, t).rate ≤ max_add(n, t).rate for t ∈ 𝒯) == length(𝒯),
        "`Rate_min_add` has to be less than `rate_max_add` in investments data (n.data)."
    )

end
"""
    check_invest_profile(time_profile, message)

Function for checking that and individual `TimeProfile` does not include the wrong type for
the indexing within EnergyModelsInvestments

## Checks
- `TimeProfile`s in `InvestmentData` cannot include `OperationalProfile`, \
`RepresentativeProfile`, or `ScenarioProfile` as this is not allowed through indexing \
on the `TimeProfile`.
"""
function check_invest_profile(time_profile, message)

    @assert_or_log(
        !isa(time_profile, OperationalProfile),
        "Operational profiles " * message
    )
    @assert_or_log(
        !isa(time_profile, ScenarioProfile),
        "Scenario profiles " * message
    )
    @assert_or_log(
        !isa(time_profile, RepresentativeProfile),
        "Representative profiles " * message
    )
    if isa(time_profile, StrategicProfile)
        @assert_or_log(
            !isa(time_profile.vals, Vector{<:OperationalProfile}),
            "Operational profiles in strategic profiles " * message
        )
        @assert_or_log(
            !isa(time_profile.vals, Vector{<:ScenarioProfile}),
            "Scenario profiles in strategic profiles " * message
        )
        @assert_or_log(
            !isa(time_profile.vals, Vector{<:RepresentativeProfile}),
            "Representative profiles in strategic profiles " * message
        )
    end
end
