# The functions in this file are designed to be extended for types defined in packages using EnergyModelsInvestments

"""
    has_investment(element)

Return boolean indicating whether an `element` shall have variables and constraints
constructed for investments.

The default implementation does not have an associated method. Instead, it is only used for
dispatch in other packages.
"""
function has_investment end

"""
    investment_data(element)

Return the investment data of the element.

The default implementation results in an error as this function requires an additional
method for the individual elements.
"""
investment_data(element) = error(
    "The function `investment_data` is not implemented for $(typeof(element))",
)

"""
    start_cap(element, t_inv, inv_data::AbstractInvData, cap)

Returns the starting capacity of the type `element` in the first investment period.
If [`NoStartInvData`](@ref) is used for the starting capacity, it requires the definition
of a method for the corresponding `element`.
"""
start_cap(element, t_inv, inv_data::StartInvData, cap) = inv_data.initial
start_cap(element, t_inv, inv_data::NoStartInvData, cap) = error(
    "The function `start_cap` is not implemented for $(typeof(element)) and " *
    "`NoStartInvData`. If you want to use `NoStartInvData` as investment data, " *
    "you have create this function for your type $(typeof(element)).",
)
