module MimiRFFSPs

using DataDeps

global g_datasets = Dict{Symbol,Any}()

include("components/SPs.jl")
include("components/RegionAggregatorSum.jl")

function __init__()
    register(DataDep(
        "rffsps_v4",
        "RFF SPs prerelease version v3.",
        "https://rffsps.s3.us-west-1.amazonaws.com/rffsps_v4.7z",
        "6f76c41b6e1297b8d0695ff331030fc9be11a6a259046ca9b63ead336cac4b40",
        post_fetch_method=unpack
    ))
end

end # module
