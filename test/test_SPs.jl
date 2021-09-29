using Mimi, MimiRFFSPs, DataFrames, CSVFiles, Query, Test
import MimiRFFSPs: SPs

all_countries = load(joinpath(@__DIR__, "..", "data", "keys", "MimiRFFSPs_ISO.csv")) |> DataFrame

# BASIC API

m = Model()
set_dimension!(m, :time, 2020:5:2300)
set_dimension!(m, :countries, all_countries.ISO)
add_comp!(m, MimiRFFSPs.SPs)
update_param!(m, :SPs, :country_names, all_countries.ISO)

run(m)

m = Model()
set_dimension!(m, :time, 2050:5:2300)
set_dimension!(m, :countries, all_countries.ISO[1:10])
add_comp!(m, MimiRFFSPs.SPs, first = 2060, last = 2300)
update_param!(m, :SPs, :country_names, all_countries.ISO[1:10])

run(m)

# ERRORS

m = Model()
set_dimension!(m, :time, 2020:1:2300)
set_dimension!(m, :countries, all_countries.ISO)
add_comp!(m, MimiRFFSPs.SPs)
update_param!(m, :SPs, :country_names, all_countries.ISO)

error_msg = (try eval(run(m)) catch err err end).msg
@test occursin("Cannot run SP component in year 2021", error_msg)

dummy_countries = ["Sun", "Rain", "Cloud"]

m = Model()
set_dimension!(m, :time, 2020:5:2300)
set_dimension!(m, :countries, dummy_countries)
add_comp!(m, MimiRFFSPs.SPs)
update_param!(m, :SPs, :country_names, dummy_countries) # error because countries aren't in SSP set

error_msg = (try eval(run(m)) catch err err end).msg
@test occursin("All countries in countries parameter must be found in SPs component Socioeconomic Dataframe, the following were not found:", error_msg)

# VALIDATION

id = 1

m = Model()
set_dimension!(m, :time, 2020:5:2300)
set_dimension!(m, :countries, all_countries.ISO)
add_comp!(m, MimiRFFSPs.SPs)
update_param!(m, :SPs, :id, id)
update_param!(m, :SPs, :country_names, all_countries.ISO)

run(m)

emissions_data = load(joinpath(@__DIR__, "..", "data", "emissions", "emissions_$(convert(Int, id)).csv")) |> 
    DataFrame |>
    @filter(_.year in collect(2020:5:20300)) |>
    DataFrame

@test m[:SPs, :co2_emissions][findfirst(i -> i == 2020, collect(2020:5:2300)):end] ≈ emissions_data.co2  atol = 1e-9
@test m[:SPs, :ch4_emissions][findfirst(i -> i == 2020, collect(2020:5:2300)):end] ≈ emissions_data.ch4  atol = 1e-9
@test m[:SPs, :n2o_emissions][findfirst(i -> i == 2020, collect(2020:5:2300)):end] ≈ emissions_data.n2o atol = 1e-9

socioeconomic_data = load(joinpath(@__DIR__, "..", "data", "socioeconomic", "socioeconomic_$(convert(Int, id)).csv")) |> 
    DataFrame |>
    @filter(_.year in collect(2020:5:20300)) |>
    DataFrame

for country in all_countries.ISO

    pop_data_model = getdataframe(m, :SPs, :population) |>
        @filter(_.time in collect(2020:5:2300) && _.countries == country) |>
        DataFrame |>
        @orderby(:time) |>
        DataFrame

    gdp_data_model = getdataframe(m, :SPs, :gdp) |>
        @filter(_.time in collect(2020:5:2300) && _.countries == country) |>
        DataFrame |>
        @orderby(:time) |>
        DataFrame

    socioeconomic_data_country = socioeconomic_data |>
        @filter(_.year in collect(2020:5:2300) && _.country == country) |>
        DataFrame |>
        @orderby(:year) |>
        DataFrame

    @test pop_data_model.population  ≈ socioeconomic_data_country.population  atol = 1e-9
    @test gdp_data_model.gdp  ≈ socioeconomic_data_country.gdp  atol = 1e-9
end
