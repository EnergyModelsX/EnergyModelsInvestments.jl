
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
