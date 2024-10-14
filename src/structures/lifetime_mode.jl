"""
    LifetimeMode

Supertype for the lifetime mode.
"""
abstract type LifetimeMode end

"""
    UnlimitedLife <: LifetimeMode

The investment's life is not limited. The investment costs do not consider any
reinvestment or rest value.
"""
struct UnlimitedLife <: LifetimeMode end

"""
    StudyLife <: LifetimeMode

The investment lasts for the whole study period with adequate reinvestments at the end of
the lifetime and considering the rest value.

# Fields
- **`lifetime::TimeProfile`** is the chosen lifetime of the technology.
"""
struct StudyLife <: LifetimeMode
    lifetime::TimeProfile
end
"""
    PeriodLife <: LifetimeMode

The investment is considered to last only for the investment period. The excess
lifetime is considered in the rest value. If the lifetime is lower than the length
of the period, reinvestment is considered as well.

# Fields
- **`lifetime::TimeProfile`** is the chosen lifetime of the technology.
"""
struct PeriodLife <: LifetimeMode
    lifetime::TimeProfile
end

"""
    RollingLife <: LifetimeMode

The investment is rolling to the next strategic periods and it is retired at the
end of its lifetime or the end of the previous investment period if its lifetime
ends between two periods.

# Fields
- **`lifetime::TimeProfile`** is the chosen lifetime of the technology.
"""
struct RollingLife <: LifetimeMode
    lifetime::TimeProfile
end

"""
    lifetime(lifetime_mode::LifetimeMode)
    lifetime(lifetime_mode::LifetimeMode, t_inv)

Return the lifetime of the lifetime mode `lifetime_mode` as `TimeProfile` or in
investment period `t_inv`.
"""
lifetime(lifetime_mode::LifetimeMode) = lifetime_mode.lifetime
lifetime(lifetime_mode::LifetimeMode, t_inv) = lifetime_mode.lifetime[t_inv]
