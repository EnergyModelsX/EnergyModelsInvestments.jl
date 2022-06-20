"""
    discount_mult_avg(start_year, discount_rate, duration_years)

Return average discount for the time period
This is a limit case n->infinity of dividing the time period into n pieces and discounting each separately

``1 / (t_1 - t_0) * \\int_{t=t_0}^{t_1} (1 + r)^{-t} dt``

The advantage of this way of calculating the discount rate is that the discounting does not change if we divide the period in two
"""
function discount_mult_avg(discount_rate, start_year, duration_years)
    if discount_rate > 0
        δ = 1/(1+discount_rate)
        m  = (δ^start_year - δ^(start_year + duration_years)) / log(1 + discount_rate) / duration_years
        return m
    else
        return 1.0
    end
end

"""
    obj_weight_inv(discount_rate, ts::TimeStructure, sp::StrategicPeriod)

Return weight to use in operational period `op` in objective function based on duration and discounting
assuming investment in *start* of strategic period `sp`
"""
function obj_weight_inv(discount_rate, ts::TimeStructure, sp::StrategicPeriod)
    disc_year = 1 / (1 + discount_rate)
    return disc_year^startyear(ts, sp)
end
"""
    obj_weight_inv_end(discount_rate, ts::TimeStructure, sp::StrategicPeriod)

Return weight to use in operational period `op` in objective function based on duration and discounting
assuming investment in *end* of strategic period `sp`
"""
function obj_weight_inv_end(discount_rate, ts::TimeStructure, sp::StrategicPeriod)
    disc_year = 1 / (1 + discount_rate)
    return disc_year^endyear(ts, sp)
end

"""
    obj_weight(discount_rate, ts::TimeStructure, sp::StrategicPeriod, op::OperationalPeriod)
    
Return weight to use in operational period `op` in objective function based on duration and discounting 
assuming cost *spread evenly* over strategic period `sp`   
"""
function obj_weight(discount_rate, ts::TimeStructure, sp::StrategicPeriod, op::OperationalPeriod)
    disc_avg = 1.0
    if discount_rate > 0
        disc_year = 1 / (1 + discount_rate)
        disc_avg =  (disc_year^startyear(ts, sp) - disc_year^(startyear(ts, sp) + duration_years(ts, sp))) / 
        log(1 + discount_rate) / duration_years(ts, sp)
    end
    return disc_avg * sp.operational.len * op.duration
end

function discount_mult_avg(discount_rate, ts::TimeStructure, sp::StrategicPeriod)
    discount_mult_avg(discount_rate, startyear(ts, sp), duration_years(ts, sp))
end