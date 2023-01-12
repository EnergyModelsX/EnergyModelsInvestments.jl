
@testset "Run examples" begin
    exdir = joinpath(@__DIR__, "../examples")

    files = first(walkdir(exdir))[3]
    for file in files
        if splitext(file)[2] == ".jl"
            @testset "Example $file" begin
                @info "Run example $file"
                include(joinpath(exdir, file))
            end
        end
    end
end
