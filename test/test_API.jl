using MimiRFFSPs

# test higher level functionality

##
## 1. get_model 
##

# basic function
m = MimiRFFSPs.get_model()
run(m)

# validation
tolerance = 1e-9
id = Int(500) # choose any random value between 1 and 10_000

m = MimiRFFSPs.get_model()
update_param!(m, :rffsp, :id, id)
run(m)

# check emissions
ch4 = load(joinpath(datadep"rffsps_v5", "emissions", "rffsp_ch4_emissions.csv")) |> 
    DataFrame |> @filter(_.year in collect(2020:2300)) |> @filter(_.sample == id) |> DataFrame
n2o = load(joinpath(datadep"rffsps_v5", "emissions", "rffsp_n2o_emissions.csv")) |> 
    DataFrame |> @filter(_.year in collect(2020:2300)) |> @filter(_.sample == id) |> DataFrame
co2 = load(joinpath(datadep"rffsps_v5", "emissions", "rffsp_co2_emissions.csv")) |> 
    DataFrame |> @filter(_.year in collect(2020:2300)) |> @filter(_.sample == id) |> DataFrame

@test m[:rffsp, :co2_emissions][findfirst(i -> i == 2020, collect(1750:2300)):end] ≈ co2.value atol = tolerance
@test m[:rffsp, :ch4_emissions][findfirst(i -> i == 2020, collect(1750:2300)):end] ≈ ch4.value atol = tolerance
@test m[:rffsp, :n2o_emissions][findfirst(i -> i == 2020, collect(1750:2300)):end] ≈ n2o.value atol = tolerance

# check socioeconomics

t = Arrow.Table(joinpath(datadep"rffsps_v5", "pop_income", "rffsp_pop_income_run_$id.feather"))
socio_df = DataFrame(   :Year => copy(t.Year), 
                        :Country => copy(t.Country), 
                        :Pop => copy(t.Pop), 
                        :GDP => copy(t.GDP)
                    ) |>
                    @filter(_.Year in collect(2020:5:2300)) |>
                    DataFrame

for country in all_countries.ISO3

    pop_data_model = getdataframe(m, :rffsp, :population) |>
        @filter(_.time in collect(2020:5:2300) && _.country == country) |>
        DataFrame |>
        @orderby(:time) |>
        DataFrame

    gdp_data_model = getdataframe(m, :rffsp, :gdp) |>
        @filter(_.time in collect(2020:5:2300) && _.country == country) |>
        DataFrame |>
        @orderby(:time) |>
        DataFrame

    socio_df_country = socio_df |>
        @filter(_.Year in collect(2020:5:2300) && _.Country == country) |>
        DataFrame |>
        @orderby(:Year) |>
        DataFrame

    @test pop_data_model.population  ≈ socio_df_country.Pop ./ 1e3  atol = tolerance
    @test gdp_data_model.gdp  ≈ socio_df_country.GDP ./ 1e3 .* MimiRFFSPs.pricelevel_2011_to_2005 atol = tolerance
end

socio_gdf = groupby(socio_df, :Year)

model_population_global = getdataframe(m, :rffsp, :population_global) |> @filter(_.time in collect(2020:5:2300)) |> @orderby(:time) |> DataFrame
model_gdp_global = getdataframe(m, :rffsp, :gdp_global) |> @filter(_.time in collect(2020:5:2300)) |> @orderby(:time)|> DataFrame

@test model_population_global.population_global ≈ (combine(socio_gdf, :Pop => sum).Pop_sum ./ 1e3)  atol = tolerance
@test model_gdp_global.gdp_global ≈ (combine(socio_gdf, :GDP => sum).GDP_sum ./ 1e3 .* MimiRFFSPs.pricelevel_2011_to_2005)  atol = 1e-7 # slightly higher tolerance

# check death rate
pop_trajectory_key = (load(joinpath(datadep"rffsps_v5", "sample_numbers", "sampled_pop_trajectory_numbers.csv")) |> DataFrame).x
deathrate_trajectory_id = convert(Int64, pop_trajectory_key[id])
        
# Load Feather File
original_years = collect(2023:5:2300)
t = Arrow.Table(joinpath(datadep"rffsps_v5", "death_rates", "rffsp_death_rates_run_$(deathrate_trajectory_id).feather"))
deathrate_df = DataFrame(:Year => copy(t.Year), 
                        :Country => copy(t.ISO3), 
                        :DeathRate => copy(t.DeathRate)
                    ) |>
                    @filter(_.Year in original_years) |>
                    DataFrame

for country in all_countries.ISO3

    deathrate_data_model = getdataframe(m, :rffsp, :deathrate) |>
        @filter(_.time in original_years && _.country == country) |>
        DataFrame |>
        @orderby(:time) |>
        DataFrame

    deathrate_df_country = deathrate_df |>         
        @filter(_.Year in original_years && _.Country == country) |>
        DataFrame |>
        @orderby(:Year) |>
        DataFrame

    @test deathrate_data_model.deathrate  ≈ deathrate_df_country.DeathRate  atol = tolerance
end

# check pop 1990

population1990 = load(joinpath(@__DIR__, "..", "data", "population1990.csv")) |> 
    DataFrame |>
    @orderby(_.ISO3) |>
    DataFrame

@test m[:rffsp, :population1990] ≈ population1990.Population atol = tolerance

# check gdp 1990

ypc1990 = load(joinpath(datadep"rffsps_v5", "ypc1990", "rffsp_ypc1990.csv")) |> 
                DataFrame |> 
                i -> insertcols!(i, :sample => 1:10_000) |> 
                i -> stack(i, Not(:sample)) |> 
                DataFrame |> 
                @filter(_.sample == id) |>
                DataFrame |>
                @orderby(_.variable) |>
                DataFrame
                
gdp1990_model = getdataframe(m, :rffsp, :gdp1990) # billions
pop1990_model = getdataframe(m, :rffsp, :population1990) # millions
ypc1990_model = gdp1990_model.gdp1990  ./ pop1990_model.population1990 .* 1e3 # per capita

@test ypc1990_model ≈ ypc1990.value .* MimiRFFSPs.pricelevel_2011_to_2005 atol = tolerance

# 2. get_mcs

# get the SimulationDef
mcs = MimiRFFSPs.get_mcs()

# run the Monte Carlo Simulation on model `m` for 10 trials and return the results
m = MimiRFFSPs.get_model()

# Add some data to save
Mimi.add_save!(mcs, (:rffsp, :id))
Mimi.add_save!(mcs, (:rffsp, :co2_emissions))

# run the mcs
results = run(mcs, m, 10)

# examine outputs
ids = getdataframe(results, :rffsp, :id).id
for id in ids
    @test id in collect(1:10_000)
end

# Alternatively run the Monte Carlo Simulation on model `m` for sample ids 1,2, and 3
mcs = MimiRFFSPs.get_mcs([1,2,3])
Mimi.add_save!(mcs, (:rffsp, :id))
Mimi.add_save!(mcs, (:rffsp, :co2_emissions))
results = run(mcs, m, 3)

@test getdataframe(results, :rffsp, :id).id == [1,2,3]
