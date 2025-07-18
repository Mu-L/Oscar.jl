using Documenter, Oscar

include(normpath(joinpath(Oscar.oscardir, "docs", "make_work.jl")))

Base.invokelatest(BuildDoc.doit, Oscar; warnonly=false, local_build=false, doctest=false)

should_push_preview = true
if get(ENV, "GITHUB_ACTOR", "") == "dependabot[bot]"
  # skip preview for dependabot PRs as they fail due to lack of permissions
  should_push_preview = false
end

deploydocs(
   repo   = "github.com/oscar-system/Oscar.jl.git",
   deploy_repo = "github.com/oscar-system/OscarDocumentation",
   push_preview = should_push_preview,
   forcepush = true,
)
