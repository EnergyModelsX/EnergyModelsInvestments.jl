"""
    max_budget(
        m,
        limit::Number,
        elements::Vector{<:Tuple{<:Any, Symbol}},
        𝒯::Union{TwoLevel, TwoLevelTree};
        sps_spec = nothing,
    )

Constrain the total CAPEX of `investments` across the selected strategic periods to be at
most `limit`. Each item in `elements` is an `(element, prefix)` tuple.

# Arguments
- `m`: the JuMP model instance.
- `limit::Number`: the maximum total CAPEX allowed across `elements` and the selected periods.
- `elements::Vector{<:Tuple{<:Any, Symbol}}`: the `(element, prefix)` tuples whose CAPEX
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
    elements::Vector{<:Tuple{<:Any,Symbol}},
    𝒯::Union{TwoLevel,TwoLevelTree};
    sps_spec = nothing,
)
    # Extract the strategic periods and identify the strategic periods to be included
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sps_select = isnothing(sps_spec) ? 𝒯ᴵⁿᵛ : sps_spec

    # Add the constraint on the total budget
    @constraint(m,
        sum(
            get_var_capex(m, prefix)[element, t_inv]
        for(element, prefix) ∈ elements, t_inv ∈ sps_select) ≤
            limit,
    )
end

"""
    max_investments(
        m,
        limit::Number,
        elements::Vector{<:Tuple{<:Any, Symbol}},
        𝒯::Union{TwoLevel, TwoLevelTree};
        sps_spec = nothing,
    )

Constrain the total number of investments for `elements` across the selected strategic
periods to be at most `limit`. Each item in `elements` is an `(element, prefix)` tuple.

This implies that the number of investment actions across the selected strategic periods is
limited to `limit` while the invested capacity can be larger if using
[`SemiContinuousInvestment`](@ref) or [`SemiContinuousOffsetInvestment`](@ref).

!!! warning "Supported investment modes"
    This relation requires binary `*_invest_b` variables for all elements and strategic periods
    in `𝒯`. This implies that it can be utilized for [`BinaryInvestment`](@ref),
    [`SemiContinuousInvestment`](@ref), and [`SemiContinuousOffsetInvestment`](@ref).

# Arguments
- `m`: the JuMP model instance.
- `limit::Number`: the maximum total number of investment actions allowed across `elements`
  and the selected periods.
- `elements::Vector{<:Tuple{<:Any, Symbol}}`: the `(element, prefix)` tuples representing
  the elements whose binary investment variables are considered.
- `𝒯::Union{TwoLevel, TwoLevelTree}`: the time structure containing the strategic periods
  over which the limit is applied.

# Keyword arguments
- `sps_spec`: the strategic periods to include. By default, all strategic periods
  in `𝒯` are selected.
"""
function max_investments(
    m,
    limit::Number,
    elements::Vector{<:Tuple{<:Any,Symbol}},
    𝒯::Union{TwoLevel,TwoLevelTree};
    sps_spec = nothing,
)
    # Extract the strategic periods and identify the strategic periods to be included
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sps_select = isnothing(sps_spec) ? 𝒯ᴵⁿᵛ : sps_spec

    # Check that all elements have binary investment variables
    _check_binary_invest(m, elements, 𝒯)

    # Add the constraint on the total limit
    @constraint(m,
        sum(
            get_var_invest_b(m, prefix)[element, t_inv]
        for (element, prefix) ∈ elements, t_inv ∈ sps_select) ≤
                limit,
    )
end

"""
    min_investments(
        m,
        limit::Number,
        elements::Vector{<:Tuple{<:Any, Symbol}},
        𝒯::Union{TwoLevel, TwoLevelTree};
        sps_spec = nothing,
    )

Constrain the total number of investments for `elements` across the selected strategic
periods to be at least `limit`. Each item in `elements` is an `(element, prefix)` tuple.

This implies that the number of investment actions across the selected strategic periods is
at least the value of `limit` while the invested capacity is not affected using
[`SemiContinuousInvestment`](@ref) or [`SemiContinuousOffsetInvestment`](@ref).

!!! warning "Supported investment modes"
    This relation requires binary `*_invest_b` variables for all elements and strategic periods
    in `𝒯`. This implies that it can be utilized for [`BinaryInvestment`](@ref),
    [`SemiContinuousInvestment`](@ref), and [`SemiContinuousOffsetInvestment`](@ref).

# Arguments
- `m`: the JuMP model instance.
- `limit::Number`: the minimum total number of investment actions required across `elements`
  and the selected periods.
- `elements::Vector{<:Tuple{<:Any, Symbol}}`: the `(element, prefix)` tuples representing
  the elements whose binary investment variables are considered.
- `𝒯::Union{TwoLevel, TwoLevelTree}`: the time structure containing the strategic periods
  over which the limit is applied.

# Keyword arguments
- `sps_spec`: the strategic periods to include. By default, all strategic periods
  in `𝒯` are selected.
"""
function min_investments(
    m,
    limit::Number,
    elements::Vector{<:Tuple{<:Any,Symbol}},
    𝒯::Union{TwoLevel,TwoLevelTree};
    sps_spec = nothing,
)
    # Extract the strategic periods and identify the strategic periods to be included
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    sps_select = isnothing(sps_spec) ? 𝒯ᴵⁿᵛ : sps_spec

    # Check that all elements have binary investment variables
    _check_binary_invest(m, elements, 𝒯)

    # Add the constraint on the minimum limit
    @constraint(m,
        sum(
            get_var_invest_b(m, prefix)[element, t_inv]
        for (element, prefix) ∈ elements, t_inv ∈ sps_select) ≥
            limit,
    )
end

"""
    require_investment(
        m,
        elements_dep::Vector{<:Tuple{<:Any, Symbol}},
        element_pre::Tuple{<:Any, Symbol},
        𝒯::Union{TwoLevel, TwoLevelTree},
    )

Require investments in the prerequisite technology specified by `element_pre` whenever there
should be investments in any dependent technology specified by `elements_dep` in the same
strategic period.

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
- `elements_dep::Vector{<:Tuple{<:Any, Symbol}}`: a vector of `(element, prefix)` tuples
  representing the dependent elements.
- `element_pre::Tuple{<:Any, Symbol}`: the prerequisite element and its capacity `prefix`.
- `𝒯::Union{TwoLevel, TwoLevelTree}`: the time structure containing the strategic periods
  over which the relation is applied.
"""
function require_investment(
    m,
    elements_dep::Vector{<:Tuple{<:Any, Symbol}},
    element_pre::Tuple{<:Any, Symbol},
    𝒯::Union{TwoLevel,TwoLevelTree},
)
    # Extract the strategic periods
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Check that all elements have binary investment variables
    _check_binary_invest(m, vcat(elements_dep, [element_pre]), 𝒯)

    # Extract the variables
    element_pre, prefix_pre = element_pre

    # Add the constraint on the dependency of investment actions
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ, (element_dep, prefix_dep) ∈ elements_dep],
        get_var_invest_b(m, prefix_dep)[element_dep, t_inv] ≤
            get_var_invest_b(m, prefix_pre)[element_pre, t_inv],
    )
end

"""
    couple_investments(
        m,
        elements::Vector{<:Tuple{<:Any, Symbol}},
        𝒯::Union{TwoLevel, TwoLevelTree},
    )

Couple all investments specified by `elements`. For each strategic period, it is only
possible to invest in all elements or in none of the elements

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
- `elements::Vector{<:Tuple{<:Any, Symbol}}`: a vector of `(element, prefix)` tuples
  specifying the coupled elements.
- `𝒯::Union{TwoLevel, TwoLevelTree}`: the time structure containing the strategic periods
  over which the relation is applied.
"""
function couple_investments(
    m,
    elements::Vector{<:Tuple{<:Any, Symbol}},
    𝒯::Union{TwoLevel,TwoLevelTree},
)
    # Extract the strategic periods
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Check that all elements have binary investment variables
    _check_binary_invest(m, elements, 𝒯)

    # Use the first investment as the reference activation
    element_1, prefix_1 = first(elements)

    # Add the constraints coupling all investment actions
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ, (element, prefix) ∈ elements[2:end]],
        get_var_invest_b(m, prefix_1)[element_1, t_inv] ==
            get_var_invest_b(m, prefix)[element, t_inv],
    )
end

"""
    exclude_investments(
        m,
        elements::Vector{<:Tuple{<:Any, Symbol}},
        𝒯::Union{TwoLevel, TwoLevelTree},
    )

Make all investments specified by `elements` mutually exclusive. For each strategic period,
at most one of the binary investment decision variables may be active.

!!! warning "Supported investment modes"
    This relation requires binary `*_invest_b` variables for all elements and strategic periods
    in `𝒯`. This implies that it can be utilized for [`BinaryInvestment`](@ref),
    [`SemiContinuousInvestment`](@ref), and [`SemiContinuousOffsetInvestment`](@ref).

# Arguments
- `m`: the JuMP model instance.
- `elements::Vector{<:Tuple{<:Any, Symbol}}`: a vector of `(element, prefix)` tuples
  specifying the elements to exclude.
- `𝒯::Union{TwoLevel, TwoLevelTree}`: the time structure containing the strategic periods
  over which the relation is applied.
"""
function exclude_investments(
    m,
    elements::Vector{<:Tuple{<:Any, Symbol}},
    𝒯::Union{TwoLevel,TwoLevelTree},
)
    # Extract the strategic periods
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Check that all elements have binary investment variables
    _check_binary_invest(m, elements, 𝒯)

    # Add the constraint that only one investment can happen in each strategic period
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum(get_var_invest_b(m, prefix)[element, t_inv] for (element, prefix) ∈ elements) ≤ 1,
    )
end

"""
    require_capacity(
        m,
        elements_dep::Vector{<:Tuple{<:Any, Symbol}},
        element_pre::Tuple,
        𝒯::Union{TwoLevel, TwoLevelTree};
        capacity_ratio::Number = 1,
    )

Require the installed capacity of each dependent investment to be supported by one
prerequisite investment. For each strategic period, the dependent capacity specified by
each `(element_dep, prefix_dep)` tuple in `elements_dep` must be at most
`capacity_ratio` times the prerequisite capacity specified by the `(element_pre, prefix_pre)`
tuple in `element_pre`.

The default `capacity_ratio = 1` is appropriate when both capacities use the same unit.
Set it explicitly when one unit of prerequisite capacity supports a different amount of
dependent capacity.

# Arguments
- `m`: the JuMP model instance.
- `elements_dep::Vector{<:Tuple{<:Any, Symbol}}`: a vector of `(element, prefix)` tuples
  representing the dependent elements.
- `element_pre::Tuple{<:Any, Symbol}`: the prerequisite element and its capacity `prefix`.
- `𝒯::Union{TwoLevel, TwoLevelTree}`: the time structure containing the strategic periods
  over which the relation is applied.

# Keyword arguments
- `capacity_ratio`: the maximum dependent capacity supported by one unit of prerequisite
  capacity.
"""
function require_capacity(
    m,
    elements_dep::Vector{<:Tuple{<:Any, Symbol}},
    element_pre::Tuple,
    𝒯::Union{TwoLevel,TwoLevelTree};
    capacity_ratio::Number = 1,
)
    # Extract the strategic periods
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Extract the variables
    element_pre, prefix_pre = element_pre
    var_current_pre = get_var_current(m, prefix_pre, element_pre)

    # Add the constraints on the upper limit on the capacity ratio
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ, (element_dep, prefix_dep) ∈ elements_dep],
        get_var_current(m, prefix_dep, element_dep)[t_inv] ≤
            capacity_ratio * var_current_pre[t_inv],
    )
end

"""
    couple_capacity(
        m,
        element_1::Tuple{<:Any, Symbol},
        element_2::Tuple{<:Any, Symbol},
        𝒯::Union{TwoLevel, TwoLevelTree};
        capacity_ratio::Number = 1,
    )

Couple the installed capacities of two investments specified by `(element, prefix)` tuples.
This implies that the capacities of the two investments must be equal in each strategic period.

The default `capacity_ratio = 1` is appropriate when both capacities use the same unit.
Set it explicitly when one unit of the second investment corresponds to a different amount
of the first investment.

# Arguments
- `m`: the JuMP model instance.
- `element_1::Tuple{<:Any, Symbol}`: an `(element_1, prefix_1)` tuple identifying the first
  capacity variable.
- `element_2`::Tuple{<:Any, Symbol}: an `(element_2, prefix_2)` tuple identifying the second
  capacity variable.
- `𝒯::Union{TwoLevel, TwoLevelTree}`: the time structure containing the strategic periods
  over which the relation is applied.

# Keyword arguments
- `capacity_ratio`: the amount of first capacity corresponding to one unit of second
  capacity.
"""
function couple_capacity(
    m,
    element_1::Tuple{<:Any, Symbol},
    element_2::Tuple{<:Any, Symbol},
    𝒯::Union{TwoLevel,TwoLevelTree};
    capacity_ratio::Number = 1,
)
    # Extract the strategic periods
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Extract the variables
    element_1, prefix_1 = element_1
    element_2, prefix_2 = element_2
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
        elements_dep::Vector{<:Tuple{<:Any, Symbol}},
        element_pre::Tuple{<:Any, Symbol},
        𝒯::Union{TwoLevel, TwoLevelTree};
        capacity_ratio::Number = 1,
    )

Require all installed dependent capacities specified by the `(element_dep, prefix_dep)` tuples
in `elements_dep` to have the prerequisite capacity specified by the `(element_pre, prefix_pre)`
tuple in `element_pre` available in the same strategic period, excluding prerequisite additions
made in that period.

This requirement applies in every strategic period, including to initial dependent capacity.
Initial prerequisite capacity can provide support in the first period.

The default `capacity_ratio = 1` is appropriate when both capacities use the same unit.
Set it explicitly when one unit of the second investment corresponds to a different amount
of the first investment.

# Arguments
- `m`: the JuMP model instance.
- `elements_dep::Vector{<:Tuple{<:Any, Symbol}}`: a vector of `(element, prefix)` tuples
  representing the dependent elements.
- `element_pre::Tuple{<:Any, Symbol}`: the prerequisite element and its capacity `prefix`.
- `𝒯::Union{TwoLevel, TwoLevelTree}`: the time structure containing the strategic periods
  over which this relation is applied.

# Keyword arguments
- `capacity_ratio`: maximum dependent installed capacity supported per unit of available
  prerequisite capacity.
"""
function precede_capacity(
    m,
    elements_dep::Vector{<:Tuple{<:Any, Symbol}},
    element_pre::Tuple{<:Any, Symbol},
    𝒯::Union{TwoLevel,TwoLevelTree};
    capacity_ratio::Number = 1,
)
    # Extract the strategic periods
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Extract the variables
    element_pre, prefix_pre = element_pre
    var_current_pre = get_var_current(m, prefix_pre, element_pre)
    var_add_pre = get_var_add(m, prefix_pre, element_pre)

    # Add the constraint on the dependency on the initial capacity in the sp
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ, (element_dep, prefix_dep) ∈ elements_dep],
        get_var_current(m, prefix_dep, element_dep)[t_inv] ≤
            capacity_ratio * (var_current_pre[t_inv] - var_add_pre[t_inv]),
    )
end

"""
    retire_capacity(
        m,
        elements_dep::Vector{<:Tuple{<:Any, Symbol, <:AbstractInvData}},
        element_pre::Tuple{<:Any, Symbol, <:AbstractInvData},
        𝒯::Union{TwoLevel, TwoLevelTree};
    )

Require all prerequisite capacity specified by `element_pre` to be removed before investments
in any dependent capacity specified by `elements_dep` can take place. No investments in the
prerequisite element can occur after initial investments in a dependent element took place.

This requirement applies in every strategic period, including to initial prerequisite capacity.
In this case, no investments in any dependent element can occur in the first strategic period
and any initial capacity pair results in an infeasible model.

!!! warning "Binary variables"
    This method includes binary variables to the model. The number of binary variables is
    equal to the number of strategic periods

# Arguments
- `m`: the JuMP model instance.
- `elements_dep::Vector{<:Tuple{<:Any, Symbol, <:AbstractInvData}}`: a vector of
  `(element, prefix, inv_data)` tuples representing the dependent elements.
- `element_pre::Tuple{<:Any, Symbol <:AbstractInvData}}`: the prerequisite element, its
  capacity `prefix`, and its investment data.
- `𝒯::Union{TwoLevel, TwoLevelTree}`: the time structure containing the strategic periods
  over which this relation is applied.
"""
function retire_capacity(
    m,
    elements_dep::Vector{<:Tuple{<:Any, Symbol, <:AbstractInvData}},
    element_pre::Tuple{<:Any, Symbol, <:AbstractInvData},
    𝒯::Union{TwoLevel, TwoLevelTree},
)
    # Extract the strategic periods and the prerequisite element
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    element_pre, prefix_pre, inv_data_pre = element_pre

    # Exception handling for infeasible models
    track_dict = Dict(t_inv => Any[] for t_inv in 𝒯ᴵⁿᵛ)
    for t_inv ∈ 𝒯ᴵⁿᵛ
        cap_init_pre = start_cap(element_pre, t_inv, inv_data_pre, prefix_pre)
        for (element_dep, prefix_dep, inv_data) ∈ elements_dep
            cap_init_dep = start_cap(element_dep, t_inv, inv_data, prefix_dep)
            if cap_init_pre > 0 && cap_init_dep > 0
                push!(track_dict[t_inv], element_dep)
            end
        end
    end
    if any([!isempty(track_dict[t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ])
        msg = "The initial capacities are not consistent:\n"
        for t_inv ∈ 𝒯ᴵⁿᵛ
            if !isempty(track_dict[t_inv])
                msg *= " - $t_inv: Elements $(track_dict[t_inv])\n"
            end
        end
        throw(ArgumentError(msg))
    end

    # Extract the variables
    var_current_pre = get_var_current(m, prefix_pre, element_pre)

    # Create an anonymous variable
    var_bin = @variable(m, [𝒯ᴵⁿᵛ], Bin)

    # Add the constraint that once element_pre is retired, it cannot be added again
    @constraint(m, [(t_inv_pre, t_inv) ∈ withprev(𝒯ᴵⁿᵛ); !isnothing(t_inv_pre)],
        var_bin[t_inv] ≥ var_bin[t_inv_pre],
    )

    # Add upper bounds to the prerequisite capacity and all dependent capacities.
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        var_current_pre[t_inv] ≤
            (1 - var_bin[t_inv]) * max_installed(inv_data_pre, t_inv),
    )
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ, (element_dep, prefix_dep, inv_data) ∈ elements_dep],
        get_var_current(m, prefix_dep, element_dep)[t_inv] ≤
            var_bin[t_inv] * max_installed(inv_data, t_inv),
    )
end
