module MimiRFFSPs

using DataDeps

global g_datasets = Dict{Symbol,Any}()

include("components/SPs.jl")
include("components/RegionAggregatorSum.jl")

function __init__()
    register(DataDep(
        "rffsps_v2",
        "RFF SPs prerelease version v2.",
        "https://rffsps.s3.us-west-1.amazonaws.com/rffsps_v2.7z",
        post_fetch_method=unpack
    ))
end

end # module
