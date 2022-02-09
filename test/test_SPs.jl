using Mimi, MimiRFFSPs, DataFrames, CSVFiles, Query, Test, Arrow, DataDeps
import MimiRFFSPs: SPs

all_countries = load(joinpath(@__DIR__, "..", "data", "keys", "MimiRFFSPs_ISO3.csv")) |> DataFrame
tolerance = 1e-9

# BASIC API

m = Model()
set_dimension!(m, :time, 2020:2300)
set_dimension!(m, :country, all_countries.ISO3)
add_comp!(m, MimiRFFSPs.SPs)
update_param!(m, :SPs, :country_names, all_countries.ISO3)

run(m)

m = Model()
set_dimension!(m, :time, 2050:2300)
# set_dimension!(m, :country, all_countries.ISO3[1:10]) # we enforce using all countries for now
set_dimension!(m, :country, all_countries.ISO3)
add_comp!(m, MimiRFFSPs.SPs, first = 2060, last = 2300)
# update_param!(m, :SPs, :country_names, all_countries.ISO3[1:10]) # we enforce using all countries for now
update_param!(m, :SPs, :country_names, all_countries.ISO3)
update_param!(m, :SPs, :start_year, 2060)
run(m)

# ERRORS

m = Model()
set_dimension!(m, :time, 2019:2300)
set_dimension!(m, :country, all_countries.ISO3)
add_comp!(m, MimiRFFSPs.SPs)
update_param!(m, :SPs, :country_names, all_countries.ISO3)

error_msg = (try eval(run(m)) catch err err end).msg
@test occursin("Cannot run SP component in year 2019", error_msg)

dummy_countries = ["Sun", "Rain", "Cloud"]

m = Model()
set_dimension!(m, :time, 2020:2300)
set_dimension!(m, :country, dummy_countries)
add_comp!(m, MimiRFFSPs.SPs)
update_param!(m, :SPs, :country_names, dummy_countries)

@test_throws KeyError run(m) # looks for the key "Sun" in the data and can't find it

# VALIDATION

id = Int(700) # choose any random value between 1 and 10_000

m = Model()
set_dimension!(m, :time, 2020:2300)
set_dimension!(m, :country, all_countries.ISO3)
add_comp!(m, MimiRFFSPs.SPs)
update_param!(m, :SPs, :id, id)
update_param!(m, :SPs, :country_names, all_countries.ISO3)

run(m)

# check emissions

ch4 = load(joinpath(datadep"rffsps_v5", "emissions", "rffsp_ch4_emissions.csv")) |> 
    DataFrame |> @filter(_.year in collect(2020:2300)) |> @filter(_.sample == id) |> DataFrame
n2o = load(joinpath(datadep"rffsps_v5", "emissions", "rffsp_n2o_emissions.csv")) |> 
    DataFrame |> @filter(_.year in collect(2020:2300)) |> @filter(_.sample == id) |> DataFrame
co2 = load(joinpath(datadep"rffsps_v5", "emissions", "rffsp_co2_emissions.csv")) |> 
    DataFrame |> @filter(_.year in collect(2020:2300)) |> @filter(_.sample == id) |> DataFrame

@test m[:SPs, :co2_emissions][findfirst(i -> i == 2020, collect(2020:2300)):end] ≈ co2.value atol = tolerance
@test m[:SPs, :ch4_emissions][findfirst(i -> i == 2020, collect(2020:2300)):end] ≈ ch4.value atol = tolerance
@test m[:SPs, :n2o_emissions][findfirst(i -> i == 2020, collect(2020:2300)):end] ≈ n2o.value atol = tolerance

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

    pop_data_model = getdataframe(m, :SPs, :population) |>
        @filter(_.time in collect(2020:5:2300) && _.country == country) |>
        DataFrame |>
        @orderby(:time) |>
        DataFrame

    gdp_data_model = getdataframe(m, :SPs, :gdp) |>
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

model_population_global = getdataframe(m, :SPs, :population_global) |> @filter(_.time in collect(2020:5:2300)) |> @orderby(:time) |> DataFrame
model_gdp_global = getdataframe(m, :SPs, :gdp_global) |> @filter(_.time in collect(2020:5:2300)) |> @orderby(:time)|> DataFrame

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

    deathrate_data_model = getdataframe(m, :SPs, :deathrate) |>
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

@test m[:SPs, :population1990] ≈ population1990.Population atol = tolerance

# # check gdp 1990

ypc1990 = load(joinpath(datadep"rffsps_v5", "ypc1990", "rffsp_ypc1990.csv")) |> 
                DataFrame |> 
                i -> insertcols!(i, :sample => 1:10_000) |> 
                i -> stack(i, Not(:sample)) |> 
                DataFrame |> 
                @filter(_.sample == id) |>
                DataFrame |>
                @orderby(_.variable) |>
                DataFrame
                
gdp1990_model = getdataframe(m, :SPs, :gdp1990) # billions
pop1990_model = getdataframe(m, :SPs, :population1990) # millions
ypc1990_model = gdp1990_model.gdp1990  ./ pop1990_model.population1990 .* 1e3 # per capita

@test ypc1990_model ≈ ypc1990.value .* MimiRFFSPs.pricelevel_2011_to_2005 atol = tolerance
