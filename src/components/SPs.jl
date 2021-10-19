
using Mimi, CSVFiles, DataFrames, Query, Interpolations, Arrow, CategoricalArrays

@defcomp SPs begin

    country = Index()

    country_names = Parameter{String}(index=[country]) # need the names of the countries from the dimension
    id = Parameter{Int64}(default=Int(6397)) # the sample (out of 10,000) to be used

    population  = Variable(index=[time, country], unit="million")
    deathrate   = Variable(index=[time, country], unit="deaths/1000 persons/yr")
    gdp         = Variable(index=[time, country], unit="billion US\$2005/yr")
    
    co2_emissions   = Variable(index=[time], unit="GtC/yr")
    ch4_emissions   = Variable(index=[time], unit="MtCH4/yr")
    n2o_emissions   = Variable(index=[time], unit="MtN/yr")

    function init(p,v,d)

        # ----------------------------------------------------------------------
        # Load Socioeconomic Data as Needed
        #   population in billions of individuals
        #   GDP in billions of $2005 USD
       
        # Load Feather File
        t = Arrow.Table(joinpath(@__DIR__, "..", "..", "data", "RFFSPs_large_datafiles", "rffsps", "run_$(p.id).feather"))
        socioeconomic_years = copy(t.Year)
        socioeconomic_countries = copy(t.Country)
        socioeconomic_pop = copy(t.Pop)
        socioeconomic_gdp = copy(t.GDP)

        # Check Countries - each country found in the model countries parameter
        # must exist in the RFF socioeconomics dataframe 
        missing_countries = []
        unique_socioeconomic_countries = unique(socioeconomic_countries)
        for country in p.country_names
            !(country in unique_socioeconomic_countries) && push!(missing_countries, country)
        end
        !isempty(missing_countries) && error("All countries in countries parameter must be found in SPs component Socioeconomic Dataframe, the following were not found: $(missing_countries)")

        # Preallocate the Socioeconomics DataFrame
        socioeconomic_df = DataFrame(:year => [], :country => [], :population => [], :gdp => [])

        all_years = collect(minimum(socioeconomic_years):maximum(socioeconomic_years))
        data_countries = unique(socioeconomic_countries)
        country_int = indexin(socioeconomic_countries, data_countries)

        for (c, country) in enumerate(data_countries)

            country_idxs = findall(i -> i == c, country_int)
            population_itp = LinearInterpolation(convert.(Float64, socioeconomic_years[country_idxs]), socioeconomic_pop[country_idxs])
            gdp_itp = LinearInterpolation(convert.(Float64, socioeconomic_years[country_idxs]), socioeconomic_gdp[country_idxs])
            
            append!(socioeconomic_df, DataFrame(
                :year => all_years,
                :country => fill(country, length(all_years)),
                :population => population_itp[all_years],
                :gdp => gdp_itp[all_years]
            ))
        end
        
        socioeconomic_df.year = convert.(Int64, socioeconomic_df.year)
        socioeconomic_df.country = convert.(String, socioeconomic_df.country)
        socioeconomic_df.population = convert.(Float64, socioeconomic_df.population)
        socioeconomic_df.gdp = convert.(Float64, socioeconomic_df.gdp)

        # will overwrite since id will change each run, don't want to overflow
        # memory so will replace not append
        g_datasets[:socioeconomic] = socioeconomic_df

        # ----------------------------------------------------------------------
        # Load Death Rate Data as Needed
        #   population in billions of individuals
        #   GDP in billions of $2005 USD

        # key between population trajectory and death rates - each population
        # trajectory is assigned to one of the 1000 death rates
        if !haskey(g_datasets, :pop_trajectory_key)
            g_datasets[:pop_trajectory_key] = (load(joinpath(@__DIR__, "..", "..", "data", "keys", "sampled_pop_trajectory_numbers.csv")) |> DataFrame).x
        end
        deathrate_trajectory_id = convert(Int64, g_datasets[:pop_trajectory_key][p.id])
        
        # Load Feather File
        t = Arrow.Table(joinpath(@__DIR__, "..", "..", "data", "RFFSPs_large_datafiles", "death_rates", "death_rates_Trajectory$(deathrate_trajectory_id).feather"))
        death_rate_years = copy(t.Year)
        death_rate_countries = copy(t.ISO3)
        death_rate_deathrate = copy(t.DeathRate)

        # Check Countries - each country found in the model countries parameter
        # must exist in the RFF socioeconomics dataframe 
        missing_countries = []
        unique_death_rate_countries = unique(death_rate_countries)
        for country in p.country_names
            !(country in unique_death_rate_countries) && push!(missing_countries, country)
        end
        !isempty(missing_countries) && error("All countries in countries parameter must be found in SPs component Socioeconomic Dataframe, the following were not found: $(missing_countries)")

        # will overwrite since id will change each run, don't want to overflow
        # memory so will replace not append
        g_datasets[:deathrate] = DataFrame(:year => death_rate_years, :country => death_rate_countries, :deathrate => death_rate_deathrate)

        # ----------------------------------------------------------------------
        # Load Emissions Data as Needed
        #   carbon dioxide emissions in GtC
        #   nitrous oxide emissions in MtN
        #   methane emissions in MtCH4
        
        if !haskey(g_datasets, :emissions)
            
            ch4 = load(joinpath(@__DIR__, "..", "..", "data", "RFFSPs_large_datafiles", "emissions", "CH4_Emissions_Trajectories.csv")) |> DataFrame
            n2o = load(joinpath(@__DIR__, "..", "..", "data", "RFFSPs_large_datafiles", "emissions", "N2O_Emissions_Trajectories.csv")) |> DataFrame
            co2 = load(joinpath(@__DIR__, "..", "..", "data", "RFFSPs_large_datafiles", "emissions", "CO2_Emissions_Trajectories.csv")) |> DataFrame
            
            g_datasets[:emissions] = DataFrame( :sample => co2.sample, 
                                                :year => co2.year, 
                                                :ch4 => ch4.value, 
                                                :n2o => n2o.value, 
                                                :co2 => co2.value
                                            )
        end

    end

    function run_timestep(p,v,d,t)

        year_label = gettime(t)

        # check that we only run the component where we have data
        if !(year_label in unique(g_datasets[:socioeconomic].year))
            error("Cannot run SP component in year $(year_label), SP socioeconomic variables not available for this model and year.")
        end
        if !(year_label in unique(g_datasets[:emissions].year))
            error("Cannot run SP component in year $(year_label), SP emissions variables not available for this model and year.")
        end
        if !(year_label in unique(g_datasets[:deathrate].year))
            error("Cannot run SP component in year $(year_label), SP death rate variables only available for this model and year.")
        end

        # ----------------------------------------------------------------------
        # Socioeconomic

        # filter the dataframe for values with the year matching timestep
        # t and only the SP countries found in the model countries list,
        # already checked that all model countries are in SP countries list
        subset = g_datasets[:socioeconomic] |>
            @filter(_.year == year_label && _.country in p.country_names) |>
            DataFrame

        # get the ordered indices of the SP countries within the parameter 
        # of the model countries, already checked that all model countries
        # are in SP countries list
        order = indexin(p.country_names, subset.country)

        v.population[t,:] = subset.population[order]
        v.gdp[t,:] = subset.gdp[order]

        # ----------------------------------------------------------------------
        # Death Rate

        subset = g_datasets[:deathrate] |>
            @filter(_.year == year_label) |>
            DataFrame

        # get the ordered indices of the SP countries within the parameter 
        # of the model countries, already checked that all model countries
        # are in SP countries list
        order = indexin(p.country_names, subset.country)

        v.deathrate[t,:] = subset.deathrate[order]

        # ----------------------------------------------------------------------
        # Emissions

        subset = g_datasets[:emissions] |>
                    @filter(_.year == year_label && _.sample == p.id) |>
                    DataFrame

        v.co2_emissions[t] = subset.co2[1]
        v.ch4_emissions[t] = subset.ch4[1]
        v.n2o_emissions[t] = subset.n2o[1]

    end
end
