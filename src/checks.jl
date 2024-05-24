"""
    EMB.check_node_data(n::EMB.Node, data::InvestmentData, 𝒯, modeltype::AbstractInvestmentModel, check_timeprofiles::Bool)

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
function EMB.check_node_data(n::EMB.Node, data::InvestmentData, 𝒯, modeltype::AbstractInvestmentModel, check_timeprofiles::Bool)

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
        message = "are not allowed for the field: " * String(field_name)

        if isa(time_profile, StrategicProfile) && check_timeprofiles
            @assert_or_log(
                length(time_profile.vals) == length(𝒯ᴵⁿᵛ),
                "Field `" * string(field_name) * "` does not match the strategic structure."
            )
        end
        EMB.check_strategic_profile(time_profile, message)
    end

    if isnothing(data.cap_start)
        time_profile = capacity(n)
        message = "are not allowed for the capacity, if investments are allowed and the \
            field `cap_start` is `nothing`."
        EMB.check_strategic_profile(time_profile, message)

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
    EMB.check_node_data(
        n::Storage,
        data::InvestmentData,
        𝒯,
        modeltype::AbstractInvestmentModel,
        check_timeprofiles::Bool,
    )

Performs various checks on investment data for standard nodes. It is similar to the standard
check nodes functions, but adds checks on

## Checks
- Each node can only have a single `InvestmentData`.
- The `InvestmentData` must be `StorageInvData`.
- For each individual investment field
  - For each field with `TimeProfile`:
      - If the `TimeProfile` is a `StrategicProfile`, it will check that the profile is in
        accordance with the `TimeStructure`
      - `TimeProfile`s in `InvestmentData` cannot include `OperationalProfile`,
        `RepresentativeProfile`, or `ScenarioProfile` as this is not allowed through indexing
        on the `TimeProfile`.
  - The field `:min_add` has to be less than `:max_add`.
  - Existing capacity cannot be larger than `:max_inst` capacity in the beginning.
    If `NoStartInvData` is used, it also checks that the the field `:cap` of the subfield of
    node `n` is not including `OperationalProfile`, `RepresentativeProfile`, or
    `ScenarioProfile` to avoid indexing problems.
"""
function EMB.check_node_data(
    n::Storage,
    data::InvestmentData,
    𝒯,
    modeltype::AbstractInvestmentModel,
    check_timeprofiles::Bool
)

    inv_data = filter(data -> typeof(data) <: InvestmentData, node_data(n))
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    t_inv_1 = collect(𝒯)[1]

    @assert_or_log(
        length(inv_data) <= 1,
        "Only one InvestmentData can be added to each node"
    )

    @assert_or_log(
        isa(data, StorageInvData),
        "The investment data for a Storage must be of type `StorageInvData`."
    )

    if !isa(data, StorageInvData)
        return
    end

    for cap_fields ∈ fieldnames(typeof(data))
        inv_data = getfield(data, cap_fields)
        isnothing(inv_data) && continue

        for field_name ∈ fieldnames(typeof(inv_data))
            time_profile = getfield(inv_data, field_name)
            !isa(time_profile, TimeProfile) && continue
            isa(time_profile, FixedProfile) && continue
            message = "are not allowed for the field: "*String(field_name)*
                "in the investment data field: "*String(cap_fields)

            if isa(time_profile, StrategicProfile) && check_timeprofiles
                @assert_or_log(
                    length(time_profile.vals) == length(𝒯ᴵⁿᵛ),
                    "Field `" * string(field_name) * "` does not match the strategic structure."
                )
            end
            EMB.check_strategic_profile(time_profile, message)
        end
        if isa(inv_data, StartInvData)
                @assert_or_log(
                    inv_data.initial <= max_installed(inv_data, t_inv_1),
                    "Starting value for " * String(cap_fields) *
                    " can not be larger than the maximum installed constraint."
                )
        else
            time_profile = capacity(getproperty(n, cap_fields))
            message = "are not allowed for the capacity of the field" * String(cap_fields) *
                ", if investments are allowed and the chosen investment type is `NoStartInvData`."
            EMB.check_strategic_profile(time_profile, message)

            @assert_or_log(
                capacity(getproperty(n, cap_fields), t_inv_1) <= max_installed(inv_data, t_inv_1),
                "Existing capacity for `" *String(cap_fields) * "` can not be larger than \
                the maximum installed value in the first strategic period."
            )

        end
        @assert_or_log(
            sum(min_add(inv_data, t) ≤ max_add(inv_data, t) for t ∈ 𝒯) == length(𝒯),
            "`min_add` has to be less than `max_add` in investments for field: " *
            String(cap_fields) * "."
        )
    end
end
