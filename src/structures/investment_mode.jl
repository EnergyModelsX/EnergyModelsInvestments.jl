"""
    Investment

Investment type traits for nodes.
The investment type corresponds to the chosen investment mode and includes the required
input.
"""
abstract type Investment end

"""
    FixedInvestment <: Investment

Fixed investment in a given capacity.
The model is forced to invest in the capacity provided by the field `cap`.

# Fields
- **`cap::TimeProfile`** is capacity used for the fixed investments. These investments
  come in addition to the existing capacity.
"""
struct FixedInvestment <: Investment
    cap::TimeProfile
end

"""
    BinaryInvestment <: Investment

Binary investment in a given capacity with binary variables.
The chosen capacity within an investment period is given by the field `cap`.

Binary investments introduce one binary variable for each investment period.

# Fields
- **`cap::TimeProfile`** is the capacity used for the binary investments. These investments
  come in addition to the existing capacity.
"""
struct BinaryInvestment <: Investment
    cap::TimeProfile
end

"""
    DiscreteInvestment <: Investment

Discrete investment with integer variables using an increment.
The increment for the discrete investment can be different for the individual strategic
periods.

Discrete investments introduce one integer variable for each investment period.

# Fields
- **`increment::TimeProfile`** is the used increment.
"""
struct DiscreteInvestment <: Investment
    increment::TimeProfile
end

"""
    ContinuousInvestment <: Investment

Continuous investment between a lower and upper bound.

# Fields
- **`min_add::TimeProfile`** is the minimum added capacity in an investment period. In the
  case of `ContinuousInvestment`, this implies that the model **must** invest at least
  in this capacity in each investment period.
- **`max_add::TimeProfile`** is the maximum added capacity in an investment period.
"""
struct ContinuousInvestment <: Investment
    min_add::TimeProfile
    max_add::TimeProfile
end

"""
    SemiContiInvestment <: Investment

Supertype for semi-continuous investments, that is the added capacity is either zero or
between a minimum and a maximum value.

Semi-continuous investments introduce one binary variable for each investment period.
"""
abstract type SemiContiInvestment <: Investment end

"""
    SemiContinuousInvestment <: Investment

Semi-continuous investments, that is the added capacity is either zero or between a minimum
and a maximum value. In this subtype, the cost is crossing the origin, that is the CAPEX is
still linear dependent on the

Semi-continuous investments introduce one binary variable for each investment period.

# Fields
- **`min_add::TimeProfile`** is the minimum added capacity in an investment period. In the
  case of `SemiContinuousInvestment`, this implies that the model **must** invest at least
  in this capacity in each investment period. in this capacity in each investment period where
  the model decides to invest. The model can also choose not too invest at all.
- **`max_add::TimeProfile`** is the maximum added capacity in an investment period.
"""
struct SemiContinuousInvestment <: SemiContiInvestment
    min_add::TimeProfile
    max_add::TimeProfile
end

"""
    SemiContinuousOffsetInvestment <: Investment

Semi-continuous investments, that is the added capacity is either zero or between a minimum
and a maximum value. In this subtype, the cost is not crossing the origin. Instead, there
is an offset (y- intercept) in the variable `capex_cap`, that is its value is larger or smaller
than 0 at an invested capacity of 0 given by the field `capex_offset`. This allows to the
user to use different slopes, and hence, account for economy of scales.

Semi-continuous investments introduce one binary variable for each investment period.

# Fields
- **`max_add::TimeProfile`** is the maximum added capacity in an investment period.
- **`min_add::TimeProfile`** is the minimum added capacity in an investment period. In the
  case of `SemiContinuousOffsetInvestment`, this implies that the model **must** invest at
  least in this capacity in each investment period. in this capacity in each investment period
  where the model decides to invest. The model can also choose not too invest at all.
- **`capex_offset::TimeProfile`** is offset for the CAPEX in an investment period.
"""
struct SemiContinuousOffsetInvestment <: SemiContiInvestment
    min_add::TimeProfile
    max_add::TimeProfile
    capex_offset::TimeProfile
end

"""
    capex_offset(inv_mode::SemiContinuousOffsetInvestment)
    capex_offset(inv_mode::SemiContinuousOffsetInvestment, t_inv)

Returns the offset of the CAPEX of the investment mode `inv_mode` as `TimeProfile` or in
investment period `t_inv`.
"""
capex_offset(inv_mode::SemiContinuousOffsetInvestment) = inv_mode.capex_offset
capex_offset(inv_mode::SemiContinuousOffsetInvestment, t_inv) = inv_mode.capex_offset[t_inv]

"""
    min_add(inv_mode::Investment)
    min_add(inv_mode::Investment, t_inv)

Returns the minimum allowed added capacity of the investment mode `inv_mode` as
`TimeProfile` or in investment period `t_inv`.
"""
min_add(inv_mode::Investment) = inv_mode.min_add
min_add(inv_mode::Investment, t_inv) = inv_mode.min_add[t_inv]

"""
    max_add(inv_mode::Investment)
    max_add(inv_mode::Investment, t_inv)

Returns the maximum allowed added capacity of the investment mode `inv_mode` as
`TimeProfile` or in investment period `t_inv`.
"""
max_add(inv_mode::Investment) = inv_mode.max_add
max_add(inv_mode::Investment, t_inv) = inv_mode.max_add[t_inv]

"""
    increment(inv_mode::Investment)
    increment(inv_mode::Investment, t_inv)

Returns the capacity increment of the investment mode `inv_mode` as `TimeProfile` or in
investment period `t_inv`.
"""
increment(inv_mode::Investment) = inv_mode.increment
increment(inv_mode::Investment, t_inv) = inv_mode.increment[t_inv]

"""
    invest_capacity(inv_mode::Investment)
    invest_capacity(inv_mode::Investment, t_inv)

Returns the capacity investments of the investment mode `inv_mode` as `TimeProfile` or in
investment period `t_inv`.
"""
invest_capacity(inv_mode::Investment) = inv_mode.cap
invest_capacity(inv_mode::Investment, t_inv) = inv_mode.cap[t_inv]
