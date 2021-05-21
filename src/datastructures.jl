abstract type InvestmentModel <: EnergyModel end
struct DiscreteInvestmentModel <: InvestmentModel
    case
end
struct ContinuousInvestmentModel <: InvestmentModel
    case
end