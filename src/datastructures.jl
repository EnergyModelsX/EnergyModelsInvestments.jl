
""" Global data for the study

# Fields
**`Emission_limit::Dict{ResourceEmit, TimeProfile}`** are the caps for the different 
emissions types considered.\n
**`Emission_price::Dict{ResourceEmit, TimeProfile}`** are the prices for the different 
emissions types considered.\n
**`r`** is the discount rate in the investment optimization.
"""
struct GlobalData <: AbstractGlobalData
    Emission_limit::Dict{ResourceEmit, TimeProfile}
    Emission_price::Dict{ResourceEmit, TimeProfile}
    r       # Discount rate
end


""" An abstract investment model type
"""
abstract type AbstractInvestmentModel <: EMB.EnergyModel end

""" An concrete basic investment model type
"""
struct InvestmentModel <: AbstractInvestmentModel
end

# struct DiscreteInvestmentModel <: AbstractInvestmentModel
#     case
#     # Discount rate
#     r       
# end
# struct ContinuousInvestmentModel <: AbstractInvestmentModel
#     case
#     # Discount rate
#     r       
# end

""" Investment type traits for nodes. """
abstract type Investment end 
""" Binary investment in given capacity with binary variables. Requires specification
of `Cap_start` in `extra_inv_data` for proper analyses."""
struct DiscreteInvestment       <: Investment end
""" Investment in fixed increments with integer variables. """
struct IntegerInvestment        <: Investment end 
""" Continuous investment between zero and a maximum value. """
struct ContinuousInvestment     <: Investment end
""" Semi-continuous investment, either zero or between a minimum and a maximum value,
involves a binary variable. """
struct SemiContinuousInvestment <: Investment end
""" Forced investment in given capacity. """
struct FixedInvestment          <: Investment end
""" Continuous investment between zero and a maximum value in a given time period.

This investment strategy alows to specifiy the strategic period `Strat_period` in which
the model can invest into the technology.

# Fields
**`Strat_period::StrategicPeriod`** Strategic period in which investments can happen.
"""
struct ContinuousFixedInvestment     <: Investment
    Strat_period::StrategicPeriod
end

""" Abstract lifetime type """
abstract type LifetimeMode end
""" The investment's life is not limited. The investment costs do not consider any 
reinvestment or rest value. """
struct UnlimitedLife        <: LifetimeMode end
""" The investment lasts for the whole study period with adequate reinvestments at the 
end of the lifetime and considering the rest value. """
struct StudyLife            <: LifetimeMode end
""" The investment is considered to last only for the strategic period. The excess 
lifetime is considered in the rest value. If the lifetime is lower than the length 
of the period, reivnvestment is considered as well. """
struct PeriodLife           <: LifetimeMode end
""" The investment is rolling to the next strategic periods and it is retired at the 
end of its lifetime or the the end of the previous startegic period if its lifetime 
ends between two periods."""
struct RollingLife          <: LifetimeMode end

""" Extra data for investing in technologies.

Define the structure for the additional parameters passed to the technology structures
defined in other packages. It uses `Base.@kwdef` to use keyword arguments and default values.
The name of the parameters have to be specified.

# Fields
**`Capex_Cap::TimeProfile`** Capital Expenditure for the capacity, here investment costs of 
the technology in each period.\n
**`Cap_max_inst::TimeProfile`** Maximum possible installed capacity of the technology in 
each period.\n
**`Cap_max_add::TimeProfile`** Maximum capacity addition in one period from the previous.\n
**`Cap_min_add::TimeProfile`** Minimum capacity addition in one period from the previous.\n
**`Inv_mode::Investment = ContinuousInvestment()`** Type of the investment:
`DiscreteInvestment`, `IntegerInvestment`, `ContinuousInvestment`, `SemiContinuousInvestment`,
 or `FixedInvestment`.\n
**`Cap_start::Union{Real, Nothing} = nothing`** Starting capacity in first period.
If nothing is given, it is set by `get_start_cap()` to the capacity `Cap` of the node.\n
**`Cap_increment::TimeProfile = FixedProfile(0)`** Capacity increment used in the case of
`IntegerInvestment`\n
**`Life_mode::LifetimeMode = UnlimitedLife()`** Type of handling of the lifetime:
`UnlimitedLife`, `StudyLife`, `PeriodLife` or `RollingLife`\n
**`Lifetime::TimeProfile = FixedProfile(0)`** Duration/Lifetime of the technology invested
in each period.
"""
Base.@kwdef struct extra_inv_data <: EMB.Data # TODO? Move from kwdef to @with_kw from Parameters.jl
    Capex_Cap::TimeProfile
    Cap_max_inst::TimeProfile
    Cap_max_add::TimeProfile
    Cap_min_add::TimeProfile
    Inv_mode::Investment = ContinuousInvestment()
    Cap_start::Union{Real, Nothing} = nothing
    Cap_increment::TimeProfile = FixedProfile(0)
    # min_inst_cap::TimeProfile # TODO: Implement
    Life_mode::LifetimeMode = UnlimitedLife()
    Lifetime::TimeProfile = FixedProfile(0)
 end

 """ Extra data for investing in storages.

Define the structure for the additional parameters passed to the technology
structures defined in other packages. It uses `Base.@kwdef` to use keyword 
arguments and default values. The name of the parameters have to be specified.
The parameters are separated between Rate and Stor. The Rate refers to 
instantaneous component (Power, Flow, ...) for instance, charging and discharging power
for batteries, while the Stor refers to a volumetric component (Energy, Volume, ...),
for instance storage capacity for a battery.
 
# Fields
**`Capex_rate::TimeProfile`** Capital Expenditure for storage rate, here investment
costs of the technology rate in each period.\n
**`Rate_max_inst::TimeProfile`** Maximum possible installed rate of the technology in
each period.\n
**`Rate_max_add::TimeProfile`** Maximum rate addition in one period from the previous.\n
**`Rate_min_add::TimeProfile`** Minimum rate addition in one period from the previous.\n
**`Capex_stor::TimeProfile`** Capital Expenditure, here investment costs of the technology 
storage volume in each period.\n
**`Stor_max_inst::TimeProfile`** Maximum possible installed storage volume of the technology 
in each period.\n
**`Stor_max_add::TimeProfile`** Maximum storage volume addition in one period from the 
previous.\n
**`Stor_min_add::TimeProfile`** Minimum storage volume addition in one period from the 
previous.\n
**`Inv_mode::Investment = ContinuousInvestment()`** Type of the investment:
`DiscreteInvestment`, `IntegerInvestment`, `ContinuousInvestment`, `SemiContinuousInvestment` 
or `FixedInvestment`.\n
**`Rate_start::Union{Real, Nothing} = nothing`** Starting rate in first period. 
If nothing is given, it is set by `get_start_cap()` to the capacity `Rate_cap` of the node.\n
**`Stor_start::Union{Real, Nothing} = nothing`** Starting storage volume in first period.
If nothing is given, it is set by `get_start_cap()` to the capacity `Stor_cap` of the node.\n
**`Rate_increment::TimeProfile = FixedProfile(0)`** Rate increment used in the case of 
`IntegerInvestment`\n
**`Stor_increment::TimeProfile = FixedProfile(0)`** Storage volume increment used in the
case of `IntegerInvestment`\n
**`Life_mode::LifetimeMode = UnlimitedLife()`** Type of handling of the lifetime:
`UnlimitedLife`, `StudyLife`, `PeriodLife`, or `RollingLife`\n
**`Lifetime::TimeProfile = FixedProfile(0)`** Duration/Lifetime of the technology invested
in each period.
"""
 Base.@kwdef struct extra_inv_data_storage <: EMB.Data
    #Investment data related to storage power
    Capex_rate::TimeProfile #capex of power
    Rate_max_inst::TimeProfile
    Rate_max_add::TimeProfile
    Rate_min_add::TimeProfile         
    Capex_stor::TimeProfile #capex of capacity
    Stor_max_inst::TimeProfile
    Stor_max_add::TimeProfile
    Stor_min_add::TimeProfile
    # General inv data
    Inv_mode::Investment = ContinuousInvestment()
    Rate_start::Union{Real, Nothing} = nothing
    Stor_start::Union{Real, Nothing} = nothing
    Rate_increment::TimeProfile = FixedProfile(0)
    Stor_increment::TimeProfile = FixedProfile(0)
    # min_inst_cap::TimeProfile #TO DO Implement
    Life_mode::LifetimeMode = UnlimitedLife()
    Lifetime::TimeProfile = FixedProfile(0)
 end
# TODO: Consider package Parameters.jl to define struct with default values

"""
investmentmode(n)

Return the investment mode of the node 'n'. By default, all investments are continuous.
"""
investmentmode(n) = n.Data["Investments"].Inv_mode
"""
lifetimemode(n)

Return the lifetime mode of the node 'n'. By default, all investments are unlimited.
"""
lifetimemode(n) = n.Data["Investments"].Life_mode

