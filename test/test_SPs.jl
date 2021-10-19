using Mimi, MimiRFFSPs, DataFrames, CSVFiles, Query, Test, Arrow
import MimiRFFSPs: SPs

all_countries = load(joinpath(@__DIR__, "..", "data", "keys", "MimiRFFSPs_ISO3.csv")) |> DataFrame

# BASIC API

m = Model()
set_dimension!(m, :time, 2020:2300)
set_dimension!(m, :country, all_countries.ISO3)
add_comp!(m, MimiRFFSPs.SPs)
update_param!(m, :SPs, :country_names, all_countries.ISO3)

run(m)

m = Model()
set_dimension!(m, :time, 2050:2300)
set_dimension!(m, :country, all_countries.ISO3[1:10])
add_comp!(m, MimiRFFSPs.SPs, first = 2060, last = 2300)
update_param!(m, :SPs, :country_names, all_countries.ISO3[1:10])

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

error_msg = (try eval(run(m)) catch err err end).msg
@test occursin("All countries in countries parameter must be found in SPs component Socioeconomic Dataframe, the following were not found:", error_msg)

# VALIDATION

id = Int(700)

m = Model()
set_dimension!(m, :time, 2020:2300)
set_dimension!(m, :country, all_countries.ISO3)
add_comp!(m, MimiRFFSPs.SPs)
update_param!(m, :SPs, :id, id)
update_param!(m, :SPs, :country_names, all_countries.ISO3)

run(m)

# check emissions

ch4 = load(joinpath(@__DIR__, "..", "data", "RFFSPs_large_datafiles", "emissions", "CH4_Emissions_Trajectories.csv")) |> 
    DataFrame |> @filter(_.year in collect(2020:2300)) |> @filter(_.sample == id) |> DataFrame
n2o = load(joinpath(@__DIR__, "..", "data", "RFFSPs_large_datafiles", "emissions", "N2O_Emissions_Trajectories.csv")) |> 
    DataFrame |> @filter(_.year in collect(2020:2300)) |> @filter(_.sample == id) |> DataFrame
co2 = load(joinpath(@__DIR__, "..", "data", "RFFSPs_large_datafiles", "emissions", "CO2_Emissions_Trajectories.csv")) |> 
    DataFrame |> @filter(_.year in collect(2020:2300)) |> @filter(_.sample == id) |> DataFrame

@test m[:SPs, :co2_emissions][findfirst(i -> i == 2020, collect(2020:2300)):end] ≈ co2.value atol = 1e-9
@test m[:SPs, :ch4_emissions][findfirst(i -> i == 2020, collect(2020:2300)):end] ≈ ch4.value atol = 1e-9
@test m[:SPs, :n2o_emissions][findfirst(i -> i == 2020, collect(2020:2300)):end] ≈ n2o.value atol = 1e-9

# check socioeconomics

t = Arrow.Table(joinpath(@__DIR__, "..", "data", "RFFSPs_large_datafiles", "rffsps", "run_$id.feather"))
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

    @test pop_data_model.population  ≈ socio_df_country.Pop  atol = 1e-9
    @test gdp_data_model.gdp  ≈ socio_df_country.GDP  atol = 1e-9
end

# check death rate

pop_trajectory_key = (load(joinpath(@__DIR__, "..", "data", "keys", "sampled_pop_trajectory_numbers.csv")) |> DataFrame).x
deathrate_trajectory_id = convert(Int64, pop_trajectory_key[id])
        
# Load Feather File
original_years = collect(2023:5:2300)
t = Arrow.Table(joinpath(@__DIR__, "..", "data", "RFFSPs_large_datafiles", "death_rates", "death_rates_Trajectory$(deathrate_trajectory_id).feather"))
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

    @test deathrate_data_model.deathrate  ≈ deathrate_df_country.DeathRate  atol = 1e-9
end
