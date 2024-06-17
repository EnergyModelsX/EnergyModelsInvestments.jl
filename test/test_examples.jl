using Pkg
ENV["EMX_TEST"] = true # Set flag for example scripts to check if they are run as part of the tests

@testset "Run examples" begin
    exdir = joinpath(@__DIR__, "../examples")
    files = filter(endswith(".jl"), readdir(exdir))
    for file in files
        @testset "Example $file" begin
            include(joinpath(exdir, file))
            @test termination_status(m) == MOI.OPTIMAL
        end
    end
    Pkg.activate(@__DIR__)
end
