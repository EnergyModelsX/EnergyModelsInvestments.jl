""" An abstract investment model type
"""
abstract type AbstractInvestmentModel <: EMB.EnergyModel end

"""
An concrete basic investment model type

# Fields
- **`Emission_limit::Dict{ResourceEmit, TimeProfile}`** are the emission caps for the different 
emissions types considered.\n
- **`Emission_price::Dict{ResourceEmit, TimeProfile}`** are the prices for the different 
emissions types considered.\n
- **`CO2_instance`** is a `ResourceEmit` and corresponds to the type used for CO2.\n
- **`r`** is the discount rate in the investment optimization.
"""
struct InvestmentModel <: AbstractInvestmentModel
    Emission_limit::Dict{ResourceEmit, TimeProfile}
    Emission_price::Dict{ResourceEmit, TimeProfile}
    CO2_instance::ResourceEmit
    r       # Discount rate
end


""" Investment type traits for nodes. """
abstract type Investment end 
""" Binary investment in given capacity with binary variables. Requires specification
of `Cap_start` in `InvData` for proper analyses."""
struct BinaryInvestment <: Investment end
""" Investment in fixed increments with integer variables. """
struct DiscreteInvestment <: Investment end 
""" Continuous investment between zero and a maximum value. """
struct ContinuousInvestment <: Investment end
""" Forced investment in given capacity. """
struct FixedInvestment <: Investment end
""" Semi-continuous investment, either zero or between a minimum and a maximum value,
involves a binary variable. """
abstract type SemiContiInvestment <: Investment end
""" Semi-continuous investment where the cost is going through the origin. """
struct SemiContinuousInvestment <: SemiContiInvestment end
""" Semi-continuous investment where the cost has an additional offset"""
struct SemiContinuousOffsetInvestment <: SemiContiInvestment end


""" Abstract lifetime type """
abstract type LifetimeMode end
""" The investment's life is not limited. The investment costs do not consider any 
reinvestment or rest value. """
struct UnlimitedLife <: LifetimeMode end
""" The investment lasts for the whole study period with adequate reinvestments at the 
end of the lifetime and considering the rest value. """
struct StudyLife <: LifetimeMode end
""" The investment is considered to last only for the strategic period. The excess 
lifetime is considered in the rest value. If the lifetime is lower than the length 
of the period, reinvestment is considered as well. """
struct PeriodLife <: LifetimeMode end
""" The investment is rolling to the next strategic periods and it is retired at the 
end of its lifetime or the end of the previous strategic period if its lifetime 
ends between two periods."""
struct RollingLife <: LifetimeMode end

"""
Abstract type for the extra data for investing in technologies.
"""
abstract type InvestmentData <: EMB.Data end

""" Extra data for investing in technologies.

Define the structure for the additional parameters passed to the technology structures
defined in other packages. It uses `Base.@kwdef` to use keyword arguments and default values.
The name of the parameters have to be specified.

# Fields
- **`Capex_Cap::TimeProfile`** Capital Expenditure for the capacity, here investment costs of 
the technology in each period.\n
- **`Cap_max_inst::TimeProfile`** Maximum possible installed capacity of the technology in 
each period.\n
- **`Cap_max_add::TimeProfile`** Maximum capacity addition in one period from the previous.\n
- **`Cap_min_add::TimeProfile`** Minimum capacity addition in one period from the previous.\n
- **`Inv_mode::Investment = ContinuousInvestment()`** Type of the investment:
`BinaryInvestment`, `DiscreteInvestment`, `ContinuousInvestment`, `SemiContinuousInvestment`,
 or `FixedInvestment`.\n
- **`Cap_start::Union{Real, Nothing} = nothing`** Starting capacity in first period.
If nothing is given, it is set by `get_start_cap()` to the capacity `Cap` of the node.\n
- **`Cap_increment::TimeProfile = FixedProfile(0)`** Capacity increment used in the case of
`DiscreteInvestment`\n
- **`Life_mode::LifetimeMode = UnlimitedLife()`** Type of handling of the lifetime:
`UnlimitedLife`, `StudyLife`, `PeriodLife` or `RollingLife`\n
- **`Lifetime::TimeProfile = FixedProfile(0)`** Duration/Lifetime of the technology invested
in each period.
"""
Base.@kwdef struct InvData <: InvestmentData
    Capex_cap::TimeProfile
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
- **`Capex_rate::TimeProfile`** Capital Expenditure for storage rate, here investment
costs of the technology rate in each period.\n
- **`Rate_max_inst::TimeProfile`** Maximum possible installed rate of the technology in
each period.\n
- **`Rate_max_add::TimeProfile`** Maximum rate addition in one period from the previous.\n
- **`Rate_min_add::TimeProfile`** Minimum rate addition in one period from the previous.\n
- **`Capex_stor::TimeProfile`** Capital Expenditure, here investment costs of the technology 
storage volume in each period.\n
- **`Stor_max_inst::TimeProfile`** Maximum possible installed storage volume of the technology 
in each period.\n
- **`Stor_max_add::TimeProfile`** Maximum storage volume addition in one period from the 
previous.\n
- **`Stor_min_add::TimeProfile`** Minimum storage volume addition in one period from the 
previous.\n
- **`Inv_mode::Investment = ContinuousInvestment()`** Type of the investment:
`BinaryInvestment`, `DiscreteInvestment`, `ContinuousInvestment`, `SemiContinuousInvestment` 
or `FixedInvestment`.\n
- **`Rate_start::Union{Real, Nothing} = nothing`** Starting rate in first period. 
If nothing is given, it is set by `get_start_cap()` to the capacity `Rate_cap` of the node.\n
- **`Stor_start::Union{Real, Nothing} = nothing`** Starting storage volume in first period.
If nothing is given, it is set by `get_start_cap()` to the capacity `Stor_cap` of the node.\n
- **`Rate_increment::TimeProfile = FixedProfile(0)`** Rate increment used in the case of 
`DiscreteInvestment`\n
- **`Stor_increment::TimeProfile = FixedProfile(0)`** Storage volume increment used in the
case of `DiscreteInvestment`\n
- **`Life_mode::LifetimeMode = UnlimitedLife()`** Type of handling of the lifetime:
`UnlimitedLife`, `StudyLife`, `PeriodLife`, or `RollingLife`\n
- **`Lifetime::TimeProfile = FixedProfile(0)`** Duration/Lifetime of the technology invested
in each period.
"""
Base.@kwdef struct InvDataStorage <: InvestmentData
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

""" Extra data for investing in transmission.

Define the structure for the additional parameters passed to the technology structures defined in other packages
It uses Base.@kwdef to use keyword arguments and default values. The name of the parameters have to be specified.

# Fields
- **`Capex_trans::TimeProfile`** Capital Expenditure for the transmission capacity, here investment costs of the transmission in each period.\n
- **`Trans_max_inst::TimeProfile`** Maximum possible installed transmission capacity in each period.\n
- **`Trans_max_add::TimeProfile`** Maximum transmission capacity addition in one period from the previous.\n
- **`Trans_min_add::TimeProfile`** Minimum transmission capacity addition in one period from the previous.\n
- **`Inv_mode::Investment = ContinuousInvestment()`** Type of the investment: BinaryInvestment, DiscreteInvestment, ContinuousInvestment, SemiContinuousInvestment or FixedInvestment.\n
- **`Trans_start::Union{Real, Nothing} = nothing`** Starting transmission capacity in first period. If nothing is given, it is set by get_start_cap() to the capacity Trans_Cap of the transmission.\n
- **`Trans_increment::TimeProfile = FixedProfile(0)`** Transmission capacity increment used in the case of DiscreteInvestment\n
"""
Base.@kwdef struct TransInvData <: InvestmentData
    Capex_trans::TimeProfile
    Trans_max_inst::TimeProfile
    Trans_max_add::TimeProfile
    Trans_min_add::TimeProfile
    Inv_mode::EnergyModelsInvestments.Investment = ContinuousInvestment()
    Trans_start::Union{Real, Nothing} = 0 # Nothing caused error in one of the examples
    Trans_increment::TimeProfile = FixedProfile(0)
    Capex_trans_offset::TimeProfile = FixedProfile(0)
end