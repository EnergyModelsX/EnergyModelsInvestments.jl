Base.@kwdef struct TransInvData <: EMB.Data
    Capex_trans::TimeProfile
    Trans_max_inst::TimeProfile
    Trans_max_add::TimeProfile
    Trans_min_add::TimeProfile
    Inv_mode::Investment = ContinuousInvestment()
    Trans_start::Union{Real, Nothing} = nothing
    Trans_increment::TimeProfile = FixedProfile(0)
    end