
struct StrategicCase <: EMB.Case
    CO2_limit::TimeProfile
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
struct DiscreteInvestment <: Investment end 	# Binary variables
struct ContinuousInvestment <: Investment end 	# Continuous variables
struct FixedInvestment <: Investment end 		# Fixed variables or as parameter
struct IndividualInvestment <: Investment end 	# Look up property of each node to decide

# Define Structure for the additional parameters passed 
# to the technology structures defined in other packages
struct extra_inv_data <: EMB.Data
    capex::TimeProfile
    max_inst_cap::TimeProfile
    ExistingCapacity::Real
    max_add::TimeProfile
    min_add::TimeProfile
    inv_mode::Investment
    # min_inst_cap::TimeProfile #TO DO Implement
 end

"""
    investmentmode(x)

Return investment mode of node `x`. By default, all investments are continuous.
Implement specialised methods to add more investment modes, e.g.:
## Example
```
investmentmode(::Battery) = DiscreteInvestment()    # Discrete for Battery nodes
investmentmode(::FuelCell) = IndividualInvestment() # Look up for each FuelCell node
```

"""
investmentmode(x) = ContinuousInvestment() 			# Default to continuous
