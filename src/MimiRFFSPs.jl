module MimiRFFSPs

global g_datasets = Dict{Symbol,Any}()

include("components/SPs.jl")
include("components/RegionAggregatorSum.jl")

end # module
