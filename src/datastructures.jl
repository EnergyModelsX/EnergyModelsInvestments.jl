
struct StrategicCase <: EMB.Case
    CO2_limit::TimeProfile
    emissions_price::Dict{ResourceEmit, TimeProfile}
end

abstract type AbstractInvestmentModel <: EMB.EnergyModel end

struct InvestmentModel <: AbstractInvestmentModel
    case::StrategicCase
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

# Define Structure for the additional parameters passed 
# to the technology structures defined in other packages

Base.@kwdef struct extra_inv_data <: EMB.Data
    capex::TimeProfile
    max_inst_cap::TimeProfile
    max_add::TimeProfile
    min_add::TimeProfile
    inv_mode::Investment = ContinuousInvestment()
    start_cap::Union{Real, Nothing} = nothing #start_cap is not necessary in the constructor, the idea is that it would then use the value speicfied in capacity of the node as a start cap
    cap_increment::TimeProfile = FixedProfile(0)
    # min_inst_cap::TimeProfile #TO DO Implement
 end


 Base.@kwdef struct extra_inv_data_storage <: EMB.Data
    #Investment data related to storage power
    capex::TimeProfile #capex of power
    max_inst_cap::TimeProfile
    max_add::TimeProfile
    min_add::TimeProfile
    #Investment data related to storage capacity
    capex_stor::TimeProfile #capex of capacity
    max_inst_stor::TimeProfile
    max_add_stor::TimeProfile
    min_add_stor::TimeProfile
    inv_mode::Investment = ContinuousInvestment()
    start_cap::Union{Real, Nothing} = nothing
    start_cap_stor::Union{Real, Nothing} = nothing
    cap_increment::TimeProfile = FixedProfile(0)
    cap_increment_stor::TimeProfile = FixedProfile(0)
    # min_inst_cap::TimeProfile #TO DO Implement
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

investmentmode(n) = n.data["InvestmentModels"].inv_mode

# TO DO function to fetch investment mode from the node type?