abstract type InvestmentModel <: EnergyModel end
struct DiscreteInvestmentModel <: InvestmentModel end
struct ContinuousInvestmentModel <: InvestmentModel end