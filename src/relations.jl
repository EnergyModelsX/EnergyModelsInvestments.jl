"""
    max_budget(model, limit, investments, periods; strategic_periods = nothing)

Constrain the total CAPEX of `investments` across the selected strategic periods to be at
most `limit`. Each item in `investments` is a `(prefix, element)` tuple.

# Arguments
- `m`: the JuMP model instance.
- `limit`: the maximum total CAPEX allowed across `investments` and the selected periods.
- `investments`: the `(prefix, element)` tuples whose CAPEX variables are included in the
    budget.
- `periods`: the time structure containing the strategic periods over which the budget is
    applied.
- `strategic_periods`: the strategic periods to include. By default, all strategic periods
    in `periods` are selected.
"""
function max_budget(m, limit, investments, periods; strategic_periods = nothing)
    selected_periods =
        isnothing(strategic_periods) ? strat_periods(periods) : strategic_periods
    @constraint(
        m,
        sum(
            get_var_capex(m, prefix)[element, t_inv] for
            (prefix, element) in investments, t_inv in selected_periods
        ) <= limit,
    )
end

"""
    max_investments(model, limit, investments, periods; strategic_periods = nothing)

Constrain the total number of investments for `investments` across the selected strategic
periods to be at most `limit`. Each item in `investments` is a `(prefix, element)` tuple.

This relation requires binary `*_invest_b` variables for all tuples and strategic periods
in `periods`.

# Arguments
- `m`: the JuMP model instance.
- `limit`: the maximum total number of investments allowed across `investments` and the
    selected periods.
- `investments`: the `(prefix, element)` tuples whose investment variables are counted.
- `periods`: the time structure containing the strategic periods over which the limit is
    applied.
- `strategic_periods`: the strategic periods to include. By default, all strategic periods
    in `periods` are selected.
"""
function max_investments(m, limit, investments, periods; strategic_periods = nothing)
    selected_periods =
        isnothing(strategic_periods) ? strat_periods(periods) : strategic_periods
    for (prefix, element) in investments
        _get_binary_investment(m, prefix, element, periods)
    end
    return @constraint(
        m,
        sum(
            get_var_invest_b(m, prefix)[element, t_inv] for
            (prefix, element) in investments, t_inv in selected_periods
        ) <= limit,
    )
end

"""
    min_investments(model, limit, investments, periods; strategic_periods = nothing)

Constrain the total number of investments for `investments` across the selected strategic
periods to be at least `limit`. Each item in `investments` is a `(prefix, element)` tuple.

This relation requires binary `*_invest_b` variables for all tuples and strategic periods
in `periods`.

# Arguments
- `m`: the JuMP model instance.
- `limit`: the minimum total number of investments required across `investments` and the
    selected periods.
- `investments`: the `(prefix, element)` tuples whose investment variables are counted.
- `periods`: the time structure containing the strategic periods over which the limit is
    applied.
- `strategic_periods`: the strategic periods to include. By default, all strategic periods
    in `periods` are selected.
"""
function min_investments(m, limit, investments, periods; strategic_periods = nothing)
    selected_periods =
        isnothing(strategic_periods) ? strat_periods(periods) : strategic_periods
    for (prefix, element) in investments
        _get_binary_investment(m, prefix, element, periods)
    end
    return @constraint(
        m,
        sum(
            get_var_invest_b(m, prefix)[element, t_inv] for
            (prefix, element) in investments, t_inv in selected_periods
        ) >= limit,
    )
end


"""
    requires_capacity(
        model,
        dependent_prefix,
        dependent_element,
        prerequisite_prefix,
        prerequisite_element,
        periods;
        capacity_ratio = 1,
    )

Require the installed capacity of one investment to be supported by another investment.
For each selected strategic period, the dependent capacity must be at most
`capacity_ratio` times the prerequisite capacity.

The default `capacity_ratio = 1` is appropriate when both capacities use the same unit.
Set it explicitly when one unit of prerequisite capacity supports a different amount of
dependent capacity.

# Arguments
- `m`: the JuMP model instance.
- `dependent_prefix`: the prefix used to identify the dependent capacity variable family.
- `dependent_element`: the element whose installed capacity depends on the prerequisite
    investment.
- `prerequisite_prefix`: the prefix used to identify the prerequisite capacity variable
    family.
- `prerequisite_element`: the element providing the prerequisite installed capacity.
- `periods`: the time structure containing the strategic periods over which the relation is
    applied.
- `capacity_ratio`: the maximum dependent capacity supported by one unit of prerequisite
    capacity.
"""
function requires_capacity(
    m,
    dependent_prefix,
    dependent_element,
    prerequisite_prefix,
    prerequisite_element,
    periods;
    capacity_ratio = 1,
)
    dependent = get_var_current(m, dependent_prefix, dependent_element)
    prerequisite = get_var_current(m, prerequisite_prefix, prerequisite_element)
    @constraint(
        m,
        [t_inv in strat_periods(periods)],
        dependent[t_inv] <= capacity_ratio * prerequisite[t_inv],
    )
end

"""
    couple_capacity(
        m,
        first_prefix,
        first_element,
        second_prefix,
        second_element,
        periods;
        capacity_ratio = 1,
    )

Couple the installed capacities of two investments.

The default `capacity_ratio = 1` is appropriate when both capacities use the same unit.
Set it explicitly when one unit of the second investment corresponds to a different amount
of the first investment.

# Arguments
- `m`: the JuMP model instance.
- `first_prefix`: the prefix used to identify the first capacity variable family.
- `first_element`: the element whose installed capacity is on the left-hand side of the
    coupling relation.
- `second_prefix`: the prefix used to identify the second capacity variable family.
- `second_element`: the element whose installed capacity is on the right-hand side of the
    coupling relation.
- `periods`: the time structure containing the strategic periods over which the relation is
    applied.
- `capacity_ratio`: the amount of first capacity corresponding to one unit of second
    capacity.
"""
function couple_capacity(
    m,
    first_prefix,
    first_element,
    second_prefix,
    second_element,
    periods;
    capacity_ratio = 1,
)
    first_capacity = get_var_current(m, first_prefix, first_element)
    second_capacity = get_var_current(m, second_prefix, second_element)
    @constraint(
        m,
        [t_inv in strat_periods(periods)],
        first_capacity[t_inv] == capacity_ratio * second_capacity[t_inv],
    )
end

"""
    _predecessor_periods(periods)

Return a dictionary mapping each strategic period to the strategic periods preceding it on
the same scenario path. For a linear time structure, the predecessors are all earlier
strategic periods. For a tree structure, only ancestor periods on the corresponding path
are included.
"""
function _predecessor_periods(periods)
    predecessors = Dict()
    for scenario in strategic_scenarios(periods)
        path = collect(strat_periods(scenario))
        for (index, period) in enumerate(path)
            haskey(predecessors, period) || (predecessors[period] = path[1:(index-1)])
        end
    end
    return predecessors
end

"""
    precede_capacity(
        model,
        dependent_prefix,
        dependent_element,
        prerequisite_prefix,
        prerequisite_element,
        periods;
        capacity_ratio = 1,
    )

Require prerequisite capacity to exist before capacity can be added to a dependent
investment.

The default `capacity_ratio = 1` is appropriate when both capacities use the same unit.
Set it explicitly when one unit of prerequisite capacity supports a different amount of
dependent capacity. The first strategic period on every path cannot receive dependent
capacity through this relation.

# Arguments
- `m`: the JuMP model instance.
- `dependent_prefix`: the prefix used to identify the dependent capacity variable family.
- `dependent_element`: the element receiving the capacity addition.
- `prerequisite_prefix`: the prefix used to identify the prerequisite capacity variable
    family.
- `prerequisite_element`: the element whose installed capacity must already exist.
- `periods`: the time structure containing the strategic periods and scenario paths used to
    determine predecessor periods.
- `capacity_ratio`: the maximum dependent capacity addition supported by one unit of
    prerequisite capacity from earlier periods. The value must be positive.
"""
function precede_capacity(
    m,
    dependent_prefix,
    dependent_element,
    prerequisite_prefix,
    prerequisite_element,
    periods;
    capacity_ratio = 1,
)
    predecessors = _predecessor_periods(periods)
    dependent_add = get_var_add(m, dependent_prefix, dependent_element)
    prereq_cap = get_var_current(m, prerequisite_prefix, prerequisite_element)
    return @constraint(
        m,
        [t_inv in strat_periods(periods)],
        dependent_add[t_inv] <=
        capacity_ratio * sum(prereq_cap[prev] for prev in predecessors[t_inv]; init = 0),
    )
end

function _get_binary_investment(m, prefix, element, periods)
    investment_variables = get_var_invest_b(m, prefix)

    for t_inv in strat_periods(periods)
        variable = investment_variables[element, t_inv]
        binary = variable isa JuMP.GenericVariableRef && JuMP.is_binary(variable)
        binary ||
            throw(ArgumentError("investment relations require binary investment variables"))
    end

    return investment_variables
end

"""
    excludes(
        m,
        first_prefix,
        first_element,
        second_prefix,
        second_element,
        periods,
    )

Make two investments mutually exclusive. For each strategic period, at most one of the
two binary investment decision variables may be active.

This relation only supports investments with existing binary `*_invest_b` variables. It
throws an [`ArgumentError`](@ref) when either investment has no decision variable or its
decision variable is not binary.

# Arguments
- `m`: the JuMP model instance.
- `first_prefix`: the prefix used to identify the first investment variable family.
- `first_element`: the element corresponding to the first investment.
- `second_prefix`: the prefix used to identify the second investment variable family.
- `second_element`: the element corresponding to the second investment.
- `periods`: the time structure containing the strategic periods over which the relation is
    applied.
"""
function excludes(m, first_prefix, first_element, second_prefix, second_element, periods)
    first_invest_b = _get_binary_investment(m, first_prefix, first_element, periods)
    second_invest_b = _get_binary_investment(m, second_prefix, second_element, periods)

    return @constraint(
        m,
        [t_inv in strat_periods(periods)],
        first_invest_b[first_element, t_inv] + second_invest_b[second_element, t_inv] <= 1,
    )
end
