using Documenter

using EnergyModelsInvestments
const EMI = EnergyModelsInvestments

# Copy the NEWS.md file
news = "docs/src/manual/NEWS.md"
cp("NEWS.md", news; force=true)

makedocs(
    sitename = "EnergyModelsInvestments",
    format = Documenter.HTML(
        prettyurls=get(ENV, "CI", "false") == "true",
        edit_link="main",
        assets=String[],
    ),
    modules = [
        EMI
    ],
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "Quick Start" => "manual/quick-start.md",
            "Philosophy" => "manual/philosophy.md",
            "Optimization variables" => "manual/optimization-variables.md",
            "Example" => "manual/simple-example.md",
            "Release notes" => "manual/NEWS.md",
        ],
        "How to" => Any[
            "Update models" => "how-to/update-models.md",
            "Use EMI" => "how-to/use-emi.md",
            "Contribute to EnergyModelsInvestments" => "how-to/contribute.md",
        ],
        "Library" => Any[
            "Public" => "library/public.md",
            "Internals" => "library/internals.md"
        ]
    ]
)

deploydocs(;
    repo = "github.com/EnergyModelsX/EnergyModelsInvestments.jl.git",
)
