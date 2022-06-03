

abstract type AbstractInvestmentModel <: EMB.EnergyModel end

struct InvestmentModel <: AbstractInvestmentModel
    # Discount rate
    r
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

# Investment type traits for nodes
abstract type Investment end 					# Kind of investment variables 
struct DiscreteInvestment       <: Investment end 	# Binary variables
struct IntegerInvestment        <: Investment end 	# Integer variables (investments in capacity increments)
struct ContinuousInvestment     <: Investment end 	# Continuous variables
struct SemiContinuousInvestment <: Investment end 	# Semi-Continuous variables
struct FixedInvestment          <: Investment end   # Fixed variables or as parameter
struct IndividualInvestment     <: Investment end 	# Look up property of each node to decide

abstract type LifetimeMode end
struct UnlimitedLife        <: LifetimeMode end    # The investment life is not limited. The investment costs do not consider any reinvestment or rest value.
struct StudyLife            <: LifetimeMode end    # The investment last for the whole study period with adequate reinvestments at end of lifetime and rest value.
struct PeriodLife           <: LifetimeMode end    # The investment is considered to last only for the strategic period. The excess lifetime is considered in the rest value.
struct RollingLife          <: LifetimeMode end    # The investment is rolling to the next strategic periods and it is retired at the end of its lifetime or the the end of the previous sp if its lifetime ends between two sp.

# Define Structure for the additional parameters passed 
# to the technology structures defined in other packages
Base.@kwdef struct extra_inv_data <: EMB.Data
    Capex_Cap::TimeProfile
    Cap_max_inst::TimeProfile
    Cap_max_add::TimeProfile
    Cap_min_add::TimeProfile
    Inv_mode::Investment = ContinuousInvestment()
    Cap_start::Union{Real, Nothing} = nothing
    Cap_increment::TimeProfile = FixedProfile(0)
    # min_inst_cap::TimeProfile #TO DO Implement
    Life_mode::LifetimeMode = UnlimitedLife()
    Lifetime::TimeProfile = FixedProfile(0)
 end


 Base.@kwdef struct extra_inv_data_storage <: EMB.Data
    #Investment data related to storage power
    Capex_rate::TimeProfile #capex of power
    Rate_max_inst::TimeProfile
    Rate_max_add::TimeProfile
    Rate_min_add::TimeProfile
    #Investment data related to storage capacity
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
#Consider package Parameters.jl to define struct with default values

# """
#     investmentmode(x)

# Return investment mode of node `x`. By default, all investments are continuous.
# Implement specialised methods to add more investment modes, e.g.:
# ## Example
# ```
# investmentmode(::Battery) = DiscreteInvestment()    # Discrete for Battery nodes
# investmentmode(::FuelCell) = IndividualInvestment() # Look up for each FuelCell node
# TO DO SemiContinuous investment mode
# ```

# """
# investmentmode(x) = ContinuousInvestment() 			# Default to continuous


"""
    investmentmode_inst(n)

Return the investment mode of the node 'n'. By default, all investments are continuous (set in the struct
 definition with the kwdef function).
"""

investmentmode(n) = n.Data["InvestmentModels"].Inv_mode
lifetimemode(n) = n.Data["InvestmentModels"].Life_mode

# TO DO function to fetch investment mode from the node type?