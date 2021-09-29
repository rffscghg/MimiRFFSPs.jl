using Test

@testset "SPs Component" begin
    include("test_SPs.jl")
end

@testset "RegionAggregatorSum Component" begin
    include("test_RegionAggregatorSum.jl")
end

@testset "Coupled" begin
    include("test_Coupled.jl")
end
