using Test
ENV["DATADEPS_ALWAYS_ACCEPT"] = "true"

@testset "SPs Component" begin
    include("test_SPs.jl")
end

@testset "RegionAggregatorSum Component" begin
    include("test_RegionAggregatorSum.jl")
end

@testset "Coupled" begin
    include("test_Coupled.jl")
end

@testset "API" begin
    include("test_API.jl")
end
