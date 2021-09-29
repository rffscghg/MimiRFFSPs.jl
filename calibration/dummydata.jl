country_names = load(joinpath(@__DIR__, "..", "data", "keys", "MimiRFF-SPs_ISO.csv")) |> DataFrame
years = collect(2020:5:2300)

pop = []
multipliers = vcat(collect(1:.1:2.2), collect(2.2:-0.05:0.7), ones(13))
for country in country_names.ISO
    append!(pop, rand() .* multipliers)
end

gdp = []
multipliers = vcat(collect(1:.1:2.2), collect(2.2:0.05:2.5), collect(2.5:0.025:3), ones(16))
for country in country_names.ISO
    append!(gdp, rand() .* multipliers)
end

DataFrame(:country => sort(repeat(country_names.ISO, length(years))), 
            :year => repeat(years, length(country_names.ISO)),
            :population => pop, 
            :gdp => gdp) |> 
    
    save(joinpath(@__DIR__, "..", "data", "socioeconomic", "socioeconomic_1.csv"))
