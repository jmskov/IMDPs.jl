using Documenter, IMDPs

makedocs(sitename="IMDPs.jl", 
         modules=[IMDPs],
         format = Documenter.HTML(
            prettyurls = get(ENV, "CI", nothing) == "true"
))