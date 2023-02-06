
""" Extra data for investing in transmission.

Define the structure for the additional parameters passed to the technology structures defined in other packages
It uses Base.@kwdef to use keyword arguments and default values. The name of the parameters have to be specified.

# Fields
- **`Capex_trans::TimeProfile`** Capital Expenditure for the transmission capacity, here investment costs of the transmission in each period.\n
- **`Trans_max_inst::TimeProfile`** Maximum possible installed transmission capacity in each period.\n
- **`Trans_max_add::TimeProfile`** Maximum transmission capacity addition in one period from the previous.\n
- **`Trans_min_add::TimeProfile`** Minimum transmission capacity addition in one period from the previous.\n
- **`Inv_mode::Investment = ContinuousInvestment()`** Type of the investment: DiscreteInvestment, IntegerInvestment, ContinuousInvestment, SemiContinuousInvestment or FixedInvestment.\n
- **`Trans_start::Union{Real, Nothing} = nothing`** Starting transmission capacity in first period. If nothing is given, it is set by get_start_cap() to the capacity Trans_Cap of the transmission.\n
- **`Trans_increment::TimeProfile = FixedProfile(0)`** Transmission capacity increment used in the case of IntegerInvestment\n
"""
Base.@kwdef struct TransInvData <: EMB.Data
    Capex_trans::TimeProfile
    Trans_max_inst::TimeProfile
    Trans_max_add::TimeProfile
    Trans_min_add::TimeProfile
    Inv_mode::Investment = ContinuousInvestment()
    Trans_start::Union{Real, Nothing} = nothing
    Trans_increment::TimeProfile = FixedProfile(0)
end
