using Documenter

using EnergyModelsInvestments
const INV = EnergyModelsInvestments

# Copy the NEWS.md file
news = "src/manual/NEWS.md"
if isfile(news)
    rm(news)
end
cp(joinpath(@__DIR__,"..","NEWS.md"), joinpath(@__DIR__,"src/manual/NEWS.md"), force=true)

makedocs(
    sitename = "EnergyModelsInvestments.jl",
    repo="https://gitlab.sintef.no/clean_export/energymodelsinvestments.jl/blob/{commit}{path}#{line}",
    format = Documenter.HTML(
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://clean_export.pages.sintef.no/energymodelsinvestments.jl/",
        edit_link="main",
        assets=String[],
    ),
    modules = [EnergyModelsInvestments],
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "Quick Start" => "manual/quick-start.md",
            "Philosophy" => "manual/philosophy.md",
            "Example" => "manual/simple-example.md",
            "Release notes" => "manual/NEWS.md",
        ],
        "Library" => Any[
            "Public" => "library/public.md",
            "Internals" => "library/internals.md"
        ]
    ]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
