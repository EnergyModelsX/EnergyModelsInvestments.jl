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
    investments::Vector{<:Tuple{Symbol,<:Any}},
    𝒯::Union{TwoLevel,TwoLevelTree};
    sps_spec = nothing,
)
    # Extract the strategic periods and identify the strategic periods to be included
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sps_select = isnothing(sps_spec) ? 𝒯ᴵⁿᵛ : sps_spec

    # Add the constraint on the total budget
    @constraint(m,
        sum(
            get_var_capex(m, prefix)[element, t_inv] for
            (prefix, element) ∈ investments, t_inv ∈ sps_select
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
    investments::Vector{<:Tuple{Symbol,<:Any}},
    𝒯::Union{TwoLevel,TwoLevelTree};
    sps_spec = nothing,
)
    # Extract the strategic periods and identify the strategic periods to be included
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sps_select = isnothing(sps_spec) ? 𝒯ᴵⁿᵛ : sps_spec

    # Identify whether the elements have binary investments
    for (prefix, element) ∈ investments
        _get_binary_investment(m, prefix, element, 𝒯)
    end

    # Add the constraint on the total limit
    @constraint(m,
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
    investments::Vector{<:Tuple{Symbol,<:Any}},
    𝒯::Union{TwoLevel,TwoLevelTree};
    sps_spec = nothing,
)
    # Extract the strategic periods and identify the strategic periods to be included
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sps_select = isnothing(sps_spec) ? 𝒯ᴵⁿᵛ : sps_spec

    # Identify whether the elements have binary investments
    for (prefix, element) ∈ investments
        _get_binary_investment(m, prefix, element, 𝒯)
    end

    # Add the constraint on the minimum limit
    @constraint(m,
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
For each strategic period, the dependent capacity specified by `prefix_dep` for element
`element_dep` must be at most `capacity_ratio` times the prerequisite capacity specified by
`prefix_pre` for element `element_pre`.

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
    𝒯::Union{TwoLevel,TwoLevelTree};
    capacity_ratio::Number = 1,
)
    # Extract the strategic periods
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Extract the variables
    var_current_dep = get_var_current(m, prefix_dep, element_dep)
    var_current_pre = get_var_current(m, prefix_pre, element_pre)

    # Add the constraint on the upper limit on the capacity ratio
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

Couple the installed capacities of two investments. This implies that the capacities (given
by `prefix_1` and `prefix_2`) of the two technologies (`element_1` and `element_2`) must be
equal in each strategic period.

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
    𝒯::Union{TwoLevel,TwoLevelTree};
    capacity_ratio::Number = 1,
)
    # Extract the strategic periods
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Extract the variables
    var_current_1 = get_var_current(m, prefix_1, element_1)
    var_current_2 = get_var_current(m, prefix_2, element_2)

    # Add the constraint on the capacity ratio
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_current_1[t_inv] == capacity_ratio * var_current_2[t_inv],
    )
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

Require all installed dependent capacity, specified by `prefix_dep`, of element `element_dep`
to have a prerequisite capacity, specified by `prefix_pre`, of `element_pre` available in the
same strategic period, excluding prerequisite additions made in that period.

This requirement applies in every strategic period, including to initial dependent capacity.
Initial prerequisite capacity can provide support in the first period.

The default `capacity_ratio = 1` is appropriate when both capacities use the same unit.
Set it explicitly when one unit of the second investment corresponds to a different amount
of the first investment.

# Arguments
- `m`: the JuMP model instance.
- `prefix_dep::Symbol`: the prefix used to identify the dependent capacity variable family.
- `element_dep`: the element whose installed capacity requires support.
- `prefix_pre::Symbol`: the prefix used to identify the prerequisite capacity variable
  family.
- `element_pre`: the element whose installed capacity must already exist.
- `𝒯::Union{TwoLevel, TwoLevelTree}`: the time structure containing the strategic periods
  over which this relation is applied.

# Keyword arguments
- `capacity_ratio`: maximum dependent installed capacity supported per unit of available
  prerequisite capacity.
"""
function precede_capacity(
    m,
    prefix_dep::Symbol,
    element_dep,
    prefix_pre::Symbol,
    element_pre,
    𝒯::Union{TwoLevel,TwoLevelTree};
    capacity_ratio::Number = 1,
)
    # Extract the strategic periods
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Extract the variables
    var_current_dep = get_var_current(m, prefix_dep, element_dep)
    var_current_pre = get_var_current(m, prefix_pre, element_pre)
    var_add_pre = get_var_add(m, prefix_pre, element_pre)

    # Add the constraint on the dependency on the initial capacity in the sp
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_current_dep[t_inv] ≤
            capacity_ratio * (var_current_pre[t_inv] - var_add_pre[t_inv]),
    )
end

"""
    retire_capacity(
        m,
        prefix_dep::Symbol,
        element_dep,
        inv_data_dep::AbstractInvData,
        prefix_pre::Symbol,
        element_pre,
        inv_data_pre::AbstractInvData,
        𝒯::Union{TwoLevel, TwoLevelTree};
    )

Require all prerequisite capacity, specified by `prefix_pre`, of `element_pre` to be removed
before investments in dependent capacity, specified by `prefix_dep`, of element `element_dep`
can take place. No investments in `element_pre` can occur after initial investments in
`element_dep` took place.

This requirement applies in every strategic period, including to initial prerequisite capacity.
In this case, no investments in `element_dep` can occur in the first strategic period and
any initial capacity results in an infeasible model.

!!! warning "Binary variables"
    This method includes binary variables to the model. The number of binary variables is
    equal to the number of strategic periods

# Arguments
- `m`: the JuMP model instance.
- `prefix_dep::Symbol`: the prefix used to identify the dependent capacity variable family.
- `element_dep`: the element whose installed capacity requires the retirement of the
  prerequisite element.
- `inv_data_dep::AbstractInvData`: the investment data of the dependent capacity.
- `prefix_pre::Symbol`: the prefix used to identify the prerequisite capacity variable
  family.
- `element_pre`: the element whose installed capacity must be removed to allow for a capacity
  in the dependent element.
- `inv_data_pre::AbstractInvData`: the investment data of the prerequisite capacity.
- `𝒯::Union{TwoLevel, TwoLevelTree}`: the time structure containing the strategic periods
  over which this relation is applied.
"""
function retire_capacity(
    m,
    prefix_dep::Symbol,
    element_dep,
    inv_data_dep::AbstractInvData,
    prefix_pre::Symbol,
    element_pre,
    inv_data_pre::AbstractInvData,
    𝒯::Union{TwoLevel, TwoLevelTree},
)
    # Extract the strategic periods and the initial capacity of the two elements
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Exception handling for infeasible models
    for t_inv ∈ 𝒯ᴵⁿᵛ
        cap_init_pre = start_cap(element_pre, t_inv, inv_data_pre, prefix_pre)
        cap_init_dep = start_cap(element_dep, t_inv, inv_data_dep, prefix_dep)
        if cap_init_pre > 0 && cap_init_dep > 0
            throw(ArgumentError(
                "The initial capacity in strategic period $(t_inv) of both the dependent " *
                "element and the prerequisite model is larger than 0. This would lead to " *
                "an infeasible model. It is hence not allowed."
            ))
        end
    end

    # Extract the variables
    var_current_dep = get_var_current(m, prefix_dep, element_dep)
    var_current_pre = get_var_current(m, prefix_pre, element_pre)

    # Create an anonymous variable
    var_bin = @variable(m, [𝒯ᴵⁿᵛ], Bin)

    # Add the constraint that once element_pre is retired, it cannot be added again
    @constraint(m, [(t_inv_pre, t_inv) ∈ withprev(𝒯ᴵⁿᵛ); !isnothing(t_inv_pre)],
        var_bin[t_inv] ≥ var_bin[t_inv_pre],
    )

    # Add upper bounds to the current capacity.
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_current_pre[t_inv] ≤
            (1 - var_bin[t_inv]) * max_installed(inv_data_pre, t_inv),
    )
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_current_dep[t_inv] ≤
            var_bin[t_inv] * max_installed(inv_data_dep, t_inv),
    )
end

"""
    require_investment(
        m,
        prefix_dep::Symbol,
        element_dep,
        prefix_pre::Symbol,
        element_pre,
        𝒯::Union{TwoLevel, TwoLevelTree},
    )

Require investments to the prerequisite technology, specified by `prefix_dep` and element
`element_dep`, whenever there should be ivnestments to the dependent technology, specified
by `prefix_pre` and element `element_pre`, in the same strategic period.

However, it is possible to have capacity additions in the prerequisite investment without
additions in the dependent investment.

The actual capacity additions are not affected, only if there are capacity additions.

!!! warning "Supported investment modes"
    This relation requires binary `*_invest_b` variables for both elements and all strategic
    periods in `𝒯`. It can be utilized for [`BinaryInvestment`](@ref),
    [`SemiContinuousInvestment`](@ref), and [`SemiContinuousOffsetInvestment`](@ref).
    For [`BinaryInvestment`](@ref), the binary controls installed capacity above baseline.
    For semicontinuous modes, it enables capacity additions, which can be zero when the
    minimum addition is zero. This relation links binary activations, not necessarily
    positive capacity additions.

# Arguments
- `m`: the JuMP model instance.
- `prefix_dep::Symbol`: the prefix used to identify the dependent investment variable family.
- `element_dep`: the element whose investment binary requires prerequisite activation.
- `prefix_pre::Symbol`: the prefix used to identify the prerequisite investment variable family.
- `element_pre`: the element providing the prerequisite investment binary.
- `𝒯::Union{TwoLevel, TwoLevelTree}`: the time structure containing the strategic periods
  over which the relation is applied.
"""
function require_investment(
    m,
    prefix_dep::Symbol,
    element_dep,
    prefix_pre::Symbol,
    element_pre,
    𝒯::Union{TwoLevel,TwoLevelTree},
)
    # Extract the strategic periods
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Extract the variables
    var_invest_b_dep = _get_binary_investment(m, prefix_dep, element_dep, 𝒯)
    var_invest_b_pre = _get_binary_investment(m, prefix_pre, element_pre, 𝒯)

    # Add the constraint on the dependency of investment actions
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_invest_b_dep[element_dep, t_inv] ≤ var_invest_b_pre[element_pre, t_inv],
    )
end

"""
    couple_investment(
        m,
        prefix_1::Symbol,
        element_1,
        prefix_2::Symbol,
        element_2,
        𝒯::Union{TwoLevel, TwoLevelTree},
    )

Couple two investments, specified by `prefix_1` and element `element_1` as well as
`prefix_2` and element `element_2`. For each strategic period, it is only possible to
invest in both investments or in none of the technologies.

The actual capacity additions are not affected, only if there are capacity additions.

!!! warning "Supported investment modes"
    This relation requires binary `*_invest_b` variables for both elements and all strategic
    periods in `𝒯`. It can be utilized for [`BinaryInvestment`](@ref),
    [`SemiContinuousInvestment`](@ref), and [`SemiContinuousOffsetInvestment`](@ref).
    For [`BinaryInvestment`](@ref), the binary controls installed capacity above baseline.
    For semicontinuous modes, it enables capacity additions, which can be zero when the
    minimum addition is zero. This relation links binary activations, not necessarily
    positive capacity additions.

# Arguments
- `m`: the JuMP model instance.
- `prefix_1::Symbol`: the prefix used to identify the first investment variable family.
- `element_1`: the element corresponding to the first investment.
- `prefix_2::Symbol`: the prefix used to identify the second investment variable family.
- `element_2`: the element corresponding to the second investment.
- `𝒯::Union{TwoLevel, TwoLevelTree}`: the time structure containing the strategic periods
  over which the relation is applied.
"""
function couple_investment(
    m,
    prefix_1::Symbol,
    element_1,
    prefix_2::Symbol,
    element_2,
    𝒯::Union{TwoLevel,TwoLevelTree},
)
    # Extract the strategic periods
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Extract the variables
    var_invest_b_1 = _get_binary_investment(m, prefix_1, element_1, 𝒯)
    var_invest_b_2 = _get_binary_investment(m, prefix_2, element_2, 𝒯)

    # Add the constraint on the dependency of investment actions
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_invest_b_1[element_1, t_inv] == var_invest_b_2[element_2, t_inv],
    )
end

"""
    exclude_investment(
        m,
        prefix_1::Symbol,
        element_1,
        prefix_2::Symbol,
        element_2,
        𝒯::Union{TwoLevel, TwoLevelTree},
    )

Make two investments, specified by `prefix_1` and element `element_1` as well as `prefix_2`
and element `element_2`, mutually exclusive. For each strategic period, at most one of the
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
function exclude_investment(
    m,
    prefix_1::Symbol,
    element_1,
    prefix_2::Symbol,
    element_2,
    𝒯::Union{TwoLevel,TwoLevelTree},
)
    # Extract the strategic periods
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Extract the variables
    var_invest_b_1 = _get_binary_investment(m, prefix_1, element_1, 𝒯)
    var_invest_b_2 = _get_binary_investment(m, prefix_2, element_2, 𝒯)

    # Add the constraint that only one investment can happen in each strategic period
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_invest_b_1[element_1, t_inv] + var_invest_b_2[element_2, t_inv] ≤ 1,
    )
end
