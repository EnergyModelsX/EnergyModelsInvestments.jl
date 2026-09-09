"""
    max_budget(
        m,
        limit::Number,
        investments::Vector{<:Tuple{Symbol, <:Any}},
        𝒯::Union{TwoLevel, TwoLevelTree};
        sps_spec = nothing,
    )

Constrain the total CAPEX of `investments` across the selected strategic periods to be at
most `limit`. Each item in `investments` is a `(prefix, element)` tuple.

# Arguments
- `m`: the JuMP model instance.
- `limit::Number`: the maximum total CAPEX allowed across `investments` and the selected periods.
- `investments::Vector{<:Tuple{Symbol, <:Any}}`: the `(prefix, element)` tuples whose CAPEX
  variables are included in the budget.
- `𝒯::Union{TwoLevel, TwoLevelTree}`: the time structure containing the strategic periods
    over which the budget is applied.

# Keyword arguments
- `sps_spec`: the strategic periods to include. By default, all strategic periods
  in `𝒯` are selected.
"""
function max_budget(
    m,
    limit::Number,
    investments::Vector{<:Tuple{Symbol, <:Any}},
    𝒯::Union{TwoLevel, TwoLevelTree};
    sps_spec = nothing,
)
    # Extract the strategic periods and identify the strategic periods to be included
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sps_select = isnothing(sps_spec) ? 𝒯ᴵⁿᵛ : sps_spec

    @constraint(m,
        sum(
            get_var_capex(m, prefix)[element, t_inv] for
            (prefix, element) in investments, t_inv in sps_select
        ) ≤ limit,
    )
end

"""
    max_investments(
        m,
        limit::Number,
        investments::Vector{<:Tuple{Symbol, <:Any}},
        𝒯::Union{TwoLevel, TwoLevelTree};
        sps_spec = nothing,
    )

Constrain the total number of investments for `investments` across the selected strategic
periods to be at most `limit`. Each item in `investments` is a `(prefix, element)` tuple.
This implies that the number of investment actions across the selected strategic periods is
limited to `limit` while the invested capacity can be larger if using
[`SemiContinuousInvestment`](@ref) or [`SemiContinuousOffsetInvestment`](@ref).

!!! warning "Supported investment modes"
    This relation requires binary `*_invest_b` variables for all elements and strategic periods
    in `𝒯`. This implies that it can be utilized for [`BinaryInvestment`](@ref),
    [`SemiContinuousInvestment`](@ref), and [`SemiContinuousOffsetInvestment`](@ref).

# Arguments
- `m`: the JuMP model instance.
- `limit::Number`: the maximum total number of investment actions allowed across `investments` and
  the selected periods.
- `investments::Vector{<:Tuple{Symbol, <:Any}}`: the `(prefix, element)` tuples whose
  investment variables are counted.
- `𝒯::Union{TwoLevel, TwoLevelTree}`: the time structure containing the strategic periods
  over which the limit is applied.

# Keyword arguments
- `sps_spec`: the strategic periods to include. By default, all strategic periods
  in `𝒯` are selected.
"""
function max_investments(
    m,
    limit::Number,
    investments::Vector{<:Tuple{Symbol, <:Any}},
    𝒯::Union{TwoLevel, TwoLevelTree};
    sps_spec = nothing,
)
    # Extract the strategic periods and identify the strategic periods to be included
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sps_select = isnothing(sps_spec) ? 𝒯ᴵⁿᵛ : sps_spec

    # Identify whether the elements have binary investments
    for (prefix, element) ∈ investments
        _get_binary_investment(m, prefix, element, 𝒯)
    end
    return @constraint(m,
        sum(
            get_var_invest_b(m, prefix)[element, t_inv] for
            (prefix, element) ∈ investments, t_inv ∈ sps_select
        ) ≤ limit,
    )
end

"""
    min_investments(
        m,
        limit::Number,
        investments::Vector{<:Tuple{Symbol, <:Any}},
        𝒯::Union{TwoLevel, TwoLevelTree};
        sps_spec = nothing,
    )

Constrain the total number of investments for `investments` across the selected strategic
periods to be at least `limit`. Each item in `investments` is a `(prefix, element)` tuple.

This implies that the number of investment actions across the selected strategic periods is
at least the value of `limit` while the invested capacity is not affected using
[`SemiContinuousInvestment`](@ref) or [`SemiContinuousOffsetInvestment`](@ref).

!!! warning "Supported investment modes"
    This relation requires binary `*_invest_b` variables for all elements and strategic periods
    in `𝒯`. This implies that it can be utilized for [`BinaryInvestment`](@ref),
    [`SemiContinuousInvestment`](@ref), and [`SemiContinuousOffsetInvestment`](@ref).

# Arguments
- `m`: the JuMP model instance.
- `limit::Number`: the minimum total number of investment actions required across `investments`
  and the selected periods.
- `investments::Vector{<:Tuple{Symbol, <:Any}}`: the `(prefix, element)` tuples whose
  investment variables are counted.
- `𝒯::Union{TwoLevel, TwoLevelTree}`: the time structure containing the strategic periods
  over which the limit is applied.

# Keyword arguments
- `sps_spec`: the strategic periods to include. By default, all strategic periods
  in `𝒯` are selected.
"""
function min_investments(
    m,
    limit::Number,
    investments::Vector{<:Tuple{Symbol, <:Any}},
    𝒯::Union{TwoLevel, TwoLevelTree};
    sps_spec = nothing,
)
    # Extract the strategic periods and identify the strategic periods to be included
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sps_select = isnothing(sps_spec) ? 𝒯ᴵⁿᵛ : sps_spec

    # Identify whether the elements have binary investments
    for (prefix, element) ∈ investments
        _get_binary_investment(m, prefix, element, 𝒯)
    end
    return @constraint(m,
        sum(
            get_var_invest_b(m, prefix)[element, t_inv] for
            (prefix, element) ∈ investments, t_inv ∈ sps_select
        ) ≥ limit,
    )
end


"""
    requires_capacity(
        m,
        prefix_dep::Symbol,
        element_dep,
        prefix_pre::Symbol,
        element_pre,
        𝒯::Union{TwoLevel, TwoLevelTree};
        capacity_ratio::Number = 1,
    )

Require the installed capacity of one investment to be supported by another investment.
For each selected strategic period, the dependent capacity specified by `prefix_dep` for
element `element_dep` must be at most `capacity_ratio` times the prerequisite capacity
specified by `prefix_pre` for element `element_pre`.

The default `capacity_ratio = 1` is appropriate when both capacities use the same unit.
Set it explicitly when one unit of prerequisite capacity supports a different amount of
dependent capacity.

# Arguments
- `m`: the JuMP model instance.
- `prefix_dep::Symbol`: the prefix used to identify the dependent capacity variable family.
- `element_dep`: the element whose installed capacity depends on the prerequisite
  investment.
- `prefix_pre::Symbol`: the prefix used to identify the prerequisite capacity variable
  family.
- `element_pre`: the element providing the prerequisite installed capacity.
- `𝒯::Union{TwoLevel, TwoLevelTree}`: the time structure containing the strategic periods
  over which the relation is applied.

# Keyword arguments
- `capacity_ratio`: the maximum dependent capacity supported by one unit of prerequisite
  capacity.
"""
function requires_capacity(
    m,
    prefix_dep::Symbol,
    element_dep,
    prefix_pre::Symbol,
    element_pre,
    𝒯::Union{TwoLevel, TwoLevelTree};
    capacity_ratio::Number = 1,
)
    # Extract the strategic periods
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Extract the variables
    var_current_dep = get_var_current(m, prefix_dep, element_dep)
    var_current_pre = get_var_current(m, prefix_pre, element_pre)

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_current_dep[t_inv] ≤ capacity_ratio * var_current_pre[t_inv],
    )
end

"""
    couple_capacity(
        m,
        prefix_1::Symbol,
        element_1,
        prefix_2::Symbol,
        element_2,
        𝒯::Union{TwoLevel, TwoLevelTree};
        capacity_ratio::Number = 1,
    )

Couple the installed capacities of two investments.

The default `capacity_ratio = 1` is appropriate when both capacities use the same unit.
Set it explicitly when one unit of the second investment corresponds to a different amount
of the first investment.

# Arguments
- `m`: the JuMP model instance.
- `prefix_1::Symbol`: the prefix used to identify the first capacity variable family.
- `element_1`: the element whose installed capacity is on the left-hand side of the
  coupling relation.
- `prefix_2::Symbol`: the prefix used to identify the second capacity variable family.
- `element_2`: the element whose installed capacity is on the right-hand side of the
  coupling relation.
- `𝒯::Union{TwoLevel, TwoLevelTree}`: the time structure containing the strategic periods
  over which the relation is applied.

# Keyword arguments
- `capacity_ratio`: the amount of first capacity corresponding to one unit of second
  capacity.
"""
function couple_capacity(
    m,
    prefix_1::Symbol,
    element_1,
    prefix_2::Symbol,
    element_2,
    𝒯::Union{TwoLevel, TwoLevelTree};
    capacity_ratio::Number = 1,
)
    # Extract the strategic periods
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Extract the variables
    var_current_1 = get_var_current(m, prefix_1, element_1)
    var_current_2 = get_var_current(m, prefix_2, element_2)

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_current_1[t_inv] == capacity_ratio * var_current_2[t_inv],
    )
end

"""
    _predecessor_periods(𝒯::TwoLevel)
    _predecessor_periods(𝒯::TwoLevelTree)

Return a dictionary mapping each strategic period to the strategic periods preceding it on
the same scenario path. For a linear time structure, the predecessors are all earlier
strategic periods. For a tree structure, only ancestor periods on the corresponding path
are included.
"""
function _predecessor_periods(𝒯::TwoLevel)
    sps = collect(strat_periods(𝒯))
    return Dict(t_inv => sps[1:idx-1] for (idx, t_inv) ∈ enumerate(sps))
end
function _predecessor_periods(𝒯::TwoLevelTree)
    sps_pre = Dict()
    for scenario ∈ strategic_scenarios(𝒯)
        path = collect(strat_periods(scenario))
        for (idx, period) ∈ enumerate(path)
            !haskey(sps_pre, period) && (sps_pre[period] = path[1:(idx-1)])
        end
    end
    return sps_pre
end

"""
    precede_capacity(
        m,
        prefix_dep::Symbol,
        element_dep,
        prefix_pre::Symbol,
        element_pre,
        𝒯::Union{TwoLevel, TwoLevelTree};
        capacity_ratio::Number = 1,
    )

Require prerequisite capacity, specified by `prefix_pre`, of element `element_pre` to exist
before a capacity, specified by `prefix_dep`, can be added to a dependent investment element
`element_dep`.

The default `capacity_ratio = 1` is appropriate when both capacities use the same unit.
Set it explicitly when one unit of prerequisite capacity supports a different amount of
dependent capacity. The first strategic period on every path cannot receive dependent
capacity through this relation.

# Arguments
- `m`: the JuMP model instance.
- `prefix_dep::Symbol`: the prefix used to identify the dependent capacity variable family.
- `element_dep`: the element receiving the capacity addition.
- `prefix_pre::Symbol`: the prefix used to identify the prerequisite capacity variable
  family.
- `element_pre`: the element whose installed capacity must already exist.
- `𝒯::Union{TwoLevel, TwoLevelTree}`: the time structure containing the strategic periods
  and scenario paths used to determine predecessor periods.

# Keyword arguments
- `capacity_ratio`: the maximum dependent capacity addition supported by one unit of
  prerequisite capacity from earlier periods. The value must be positive.
"""
function precede_capacity(
    m,
    prefix_dep::Symbol,
    element_dep,
    prefix_pre::Symbol,
    element_pre,
    𝒯::Union{TwoLevel, TwoLevelTree};
    capacity_ratio::Number = 1,
)
    # Extract the strategic periods and identify the predecessor periods for each strategic
    # period
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sps_pre = _predecessor_periods(𝒯)

    # Extract the variables
    var_add_dep = get_var_add(m, prefix_dep, element_dep)
    var_current_pre = get_var_current(m, prefix_pre, element_pre)

    return @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_add_dep[t_inv] ≤
            capacity_ratio *
            sum(var_current_pre[prev] for prev ∈ sps_pre[t_inv]; init = 0),
    )
end

function _get_binary_investment(m, prefix, element, 𝒯::Union{TwoLevel, TwoLevelTree})
    # Extract the strategic periods
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Extract the investment variables
    var_invest_b = get_var_invest_b(m, prefix)

    # Identify whether the element `element` has a binary investment variable for each
    # strategic period.
    for t_inv ∈ 𝒯ᴵⁿᵛ
        var = var_invest_b[element, t_inv]
        if !(isa(var, JuMP.GenericVariableRef) && JuMP.is_binary(var))
            throw(ArgumentError("investment relations require binary investment variables"))
        end
    end

    return var_invest_b
end

"""
    excludes_capacity(
        m,
        prefix_1::Symbol,
        element_1,
        prefix_2::Symbol,
        element_2,
        𝒯::Union{TwoLevel, TwoLevelTree},
    )

Make two investments mutually exclusive. For each strategic period, at most one of the
two binary investment decision variables may be active.

!!! warning "Supported investment modes"
    This relation requires binary `*_invest_b` variables for all elements and strategic periods
    in `𝒯`. This implies that it can be utilized for [`BinaryInvestment`](@ref),
    [`SemiContinuousInvestment`](@ref), and [`SemiContinuousOffsetInvestment`](@ref).

# Arguments
- `m`: the JuMP model instance.
- `prefix_1::Symbol`: the prefix used to identify the first investment variable family.
- `element_1`: the element corresponding to the first investment.
- `prefix_2::Symbol`: the prefix used to identify the second investment variable family.
- `element_2`: the element corresponding to the second investment.
- `𝒯::Union{TwoLevel, TwoLevelTree}`: the time structure containing the strategic periods
  over which the relation is applied.
"""
function excludes_capacity(
    m,
    prefix_1::Symbol,
    element_1,
    prefix_2::Symbol,
    element_2,
    𝒯::Union{TwoLevel, TwoLevelTree},
)
    # Extract the strategic periods
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Extract the variables
    var_invest_b_1 = _get_binary_investment(m, prefix_1, element_1, 𝒯)
    var_invest_b_2 = _get_binary_investment(m, prefix_2, element_2, 𝒯)

    # Add the constraint that only one investment can happen in each strategic period
    return @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_invest_b_1[element_1, t_inv] + var_invest_b_2[element_2, t_inv] ≤ 1,
    )
end
