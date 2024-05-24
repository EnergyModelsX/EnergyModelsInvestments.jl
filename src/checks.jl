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
        sub_data = getfield(data, cap_fields)
        isnothing(sub_data) && continue
        check_inv_data(
            sub_data,
            capacity(getproperty(n, cap_fields)),
            𝒯,
            " of field `" * String(cap_fields) * "`",
            check_timeprofiles
        )
    end
end

function check_inv_data(
    inv_data::GeneralInvData,
    capacity_profile::TimeProfile,
    𝒯,
    message::String,
    check_timeprofiles::Bool,
)

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    t_inv_1 = collect(𝒯)[1]

    # Check on the individual time profiles
    for field_name ∈ fieldnames(typeof(inv_data))
        time_profile = getfield(inv_data, field_name)
        if isa(time_profile, Union{Investment, LifetimeMode})
            for sub_field_name ∈ fieldnames(typeof(time_profile))
                sub_time_profile = getfield(time_profile, sub_field_name)
                message = "are not allowed for the field: " * String(field_name) *
                    "of the mode " * String(sub_field_name) *
                    "in the investment data" * message * "."
                if isa(sub_time_profile, StrategicProfile) && check_timeprofiles
                    @assert_or_log(
                        length(sub_time_profile.vals) == length(𝒯ᴵⁿᵛ),
                        "Field `" * string(sub_field_name) * "` does not match the strategic structure."
                    )
                end
                EMB.check_strategic_profile(sub_time_profile, message)
            end
        end
        !isa(time_profile, TimeProfile) && continue
        isa(time_profile, FixedProfile) && continue
        message = "are not allowed for the field: " * String(field_name) *
            "in the investment data" * message * "."

        if isa(time_profile, StrategicProfile) && check_timeprofiles
            @assert_or_log(
                length(time_profile.vals) == length(𝒯ᴵⁿᵛ),
                "Field `" * string(field_name) * "` does not match the strategic " *
                "structure in the investment data" * message * "."
            )
        end
        EMB.check_strategic_profile(time_profile, message)
    end

    # Check on the initial capacity in the first strategic period
    if isa(inv_data, StartInvData)
            @assert_or_log(
                inv_data.initial <= max_installed(inv_data, t_inv_1),
                "The starting value in the investment data " * message *
                " can not be larger than the maximum installed constraint."
            )
    else
        message = "are not allowed for the capacity of the investment data " * message *
            ", if investments are allowed and the chosen investment type is `NoStartInvData`."
        EMB.check_strategic_profile(capacity_profile, message)

        @assert_or_log(
            capacity_profile[t_inv_1] <= max_installed(inv_data, t_inv_1),
            "The existing capacity can not be larger than the maximum installed value in " *
            " the first strategic period for the capacity coupled to the investment data" *
            message * "."
        )

    end

    # Check on the minmimum and maximum added capacities
    if isa(investment_mode(inv_data), Union{ContinuousInvestment, SemiContiInvestment})
        @assert_or_log(
            sum(min_add(inv_data, t) ≤ max_add(inv_data, t) for t ∈ 𝒯) == length(𝒯),
            "`min_add` has to be less than `max_add` in the investment data" *
            message * "."
        )
    end
end
