using Pkg

@testset "Run examples" begin
    exdir = joinpath(@__DIR__, "../examples")

    # Add the package EnergyModelsInvestments to the environment.
    Pkg.develop(path=joinpath(@__DIR__, ".."))

    files = first(walkdir(exdir))[3]
    for file in files

        # Removal of Geography example as EMG is not yet registered
        if file == "geography.jl"
            continue
        end
        # The section here has to be removed once EMG is registered

        if splitext(file)[2] == ".jl"
            @testset "Example $file" begin
                @info "Run example $file"
                include(joinpath(exdir, file))

                @test termination_status(m) == MOI.OPTIMAL
            end
        end
    end

    # Cleanup the test environment. Remove EnergyModelsInvestments from the environment,
    # since it is added with `Pkg.develop` by the examples. The tests can not be run with
    # with the package in the environment.
    Pkg.rm("EnergyModelsInvestments")
end
