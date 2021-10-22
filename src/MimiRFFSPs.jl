module MimiRFFSPs

using DataDeps

global g_datasets = Dict{Symbol,Any}()

include("components/SPs.jl")
include("components/RegionAggregatorSum.jl")

function __init__()
    register(DataDep(
        "rffsps",
        "RFF SPs prerelease version.",
        "https://rffsps.s3.us-west-1.amazonaws.com/RFFSPs_large_datafiles.7z",
        post_fetch_method=unpack
    ))
end

end # module
