"""
    avg_disc_yearly(discount_rate, start_year, duration_years)
Return average of yearly discounting by end of year for comparison in tests.
"""
function avg_disc_yearly(discount_rate, start_year, duration_years)
    δ = 1/(1+discount_rate)
    m = 0
    for y=start_year:duration_years-1
        m += δ^(y+1)
    end
    return m / duration_years
end    

"""
    avg_disc_midyear(discount_rate, start_year, duration_years)
Return average of yearly discounting by mid-year for comparison in tests
"""
function avg_disc_midyear(discount_rate, start_year, duration_years)
    δ = 1/(1+discount_rate)
    m = 0
    for y=start_year:start_year+duration_years-1
        m += (δ^y + δ^(y+1))/2
    end
    return m / duration_years
end

@testset "Discounting tests" begin
    r = 0.07
    uniform_day  = SimpleTimes(24, 1)
    uniform_year = TwoLevel(365, 1//365, uniform_day)
    scale_year   = TwoLevel(1, 1, uniform_day)
    scale_2years = TwoLevel(1, 2, uniform_day)

    @test isapprox(EMI.discount_mult_avg(r, scale_2years, first(strategic_periods(scale_2years))),
                      1/(1+r), atol = 0.001)

    for n_periods ∈ (1, 10, 8760)
        for dur_y ∈ (1, 2, 10)
            for ut ∈ [SimpleTimes(24 * 365 * dur_y, 1)]
                ts = TwoLevel(1, dur_y, ut)
                sp = first(strategic_periods(ts))
                op = first(collect(sp))
                for discount_rate ∈ (0, 0.07, 0.10)
                    # Investment/strategic period discounting:
                    @test obj_weight_inv(discount_rate, ts, sp) ≈ (1 + discount_rate)^(-startyear(ts, sp))                       
                
                    # Operational period discounting/weight:
                    ow = obj_weight(discount_rate, ts, sp, op)
                    period_scale = 365*24 * sum(duration_years(ts,p) for p in strategic_periods(ts))
                    
                    # should be between average yearly discount rate scaled at year start/end
                    @test ow <= avg_disc_yearly(discount_rate, startyear(ts, sp) - 1, dur_y) * period_scale
                    @test ow >= avg_disc_yearly(discount_rate, startyear(ts, sp)    , dur_y) * period_scale
                    @test isapprox(ow, avg_disc_midyear(discount_rate, startyear(ts, sp), duration_years(ts, sp)) * period_scale; rtol=discount_rate/2)
                    @test ow ≈ discount_mult_avg(discount_rate, startyear(ts, sp), dur_y) * period_scale
                end
            end
        end
    end        
end