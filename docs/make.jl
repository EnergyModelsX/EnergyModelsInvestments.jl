using Documenter
using DocumenterInterLinks

using EnergyModelsInvestments
using TimeStruct
const EMI = EnergyModelsInvestments

# Copy the NEWS.md file
news = "docs/src/manual/NEWS.md"
cp("NEWS.md", news; force=true)

links = InterLinks(
    "TimeStruct" => "https://sintefore.github.io/TimeStruct.jl/stable/",
)

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
            "Mathematical description" => "manual/math_desc.md",
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
    ],
    plugins=[links],
)

deploydocs(;
    repo = "github.com/EnergyModelsX/EnergyModelsInvestments.jl.git",
)
