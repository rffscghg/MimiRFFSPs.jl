module MimiRFFSPs

using Mimi,
    CSVFiles,
    DataDeps,
    DataFrames,
    Query,
    Interpolations,
    Arrow,
    CategoricalArrays

import IteratorInterfaceExtensions

global g_datasets = Dict{Symbol,Any}()

include("components/SPs.jl")
include("components/RegionAggregatorSum.jl")

function __init__()
    register(DataDep(
        "rffsps_v5",
        "RFF SPs version v5",
        "https://zenodo.org/record/6016583/files/rffsps_v5.7z",
        "a39b51d7552d198123b1863ea5a131533715a7a7c9ff6fad4b493594ece49497",
        post_fetch_method=unpack
    ))
end

function get_model()
    m = Model()

    set_dimension!(m, :time, 1750:2300)

    add_comp!(m, SPs, :rffsp, first = 2020, last = 2300)

    all_countries = CSVFiles.load(joinpath(@__DIR__, "..", "data", "keys", "MimiRFFSPs_ISO3.csv")) |> DataFrame    

    set_dimension!(m, :country, all_countries.ISO3)

    update_param!(m, :rffsp, :country_names, all_countries.ISO3)

    return m
end

function get_mcs(sampling_ids::Union{Vector{Int}, Nothing} = nothing)
    # define the Monte Carlo Simulation and add some simple random variables
    mcs = @defsim begin
    end

    distrib = isnothing(sampling_ids) ? Mimi.EmpiricalDistribution(collect(1:10_000)) : Mimi.SampleStore(sampling_ids)
    Mimi.add_RV!(mcs, :socio_id_rv, distrib)
    Mimi.add_transform!(mcs, :rffsp, :id, :(=), :socio_id_rv)

    return mcs
end

end # module
