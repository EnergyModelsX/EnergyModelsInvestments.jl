
function run_model(fn, optimizer=nothing)
    @debug "Run model" fn optimizer
 
     data = EMB.read_data(fn)

     m = EMB.create_model(data, DiscreteInvestmentModel(""))
 
     if !isnothing(optimizer)
         set_optimizer(m, optimizer)
         optimize!(m)
         # TODO: print_solution(m) optionally show results summary (perhaps using upcoming JuMP function)
         # TODO: save_solution(m) save results
     else
         @info "No optimizer given"
     end
     return 0
 end