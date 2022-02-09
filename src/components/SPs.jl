using Mimi, CSVFiles, DataFrames, Query, Interpolations, Arrow, CategoricalArrays, DataDeps
import IteratorInterfaceExtensions, Tables

# (10/25/2021) BEA Table 1.1.9, line 1 GDP annual values as linked here: https://apps.bea.gov/iTable/iTable.cfm?reqid=19&step=3&isuri=1&select_all_years=0&nipa_table_list=13&series=a&first_year=2005&last_year=2020&scale=-99&categories=survey&thetable=
const pricelevel_2011_to_2005 = 87.504/98.164

function fill_socioeconomics!(source_Year, source_Country, source_Pop, source_GDP, population, gdp, country_lookup, start_year, end_year)
    for i in 1:length(source_Year)
        if source_Year[i] >= start_year && source_Year[i] <= end_year
            year_index = TimestepIndex(source_Year[i] - start_year + 1)
            # year_index = TimestepValue(source_Year[i]) # current bug in Mimi
            country_index = country_lookup[source_Country[i]]

            population[year_index, country_index] = source_Pop[i] ./ 1e3 # convert thousands to millions
            gdp[year_index, country_index] = source_GDP[i] ./ 1e3 .* pricelevel_2011_to_2005 # convert millions to billions; convert $2011 to $2005

        end
    end
end

function fill_deathrates!(source_Year, source_ISO3, source_DeathRate, deathrate, country_lookup, start_year, end_year)
    for i in 1:length(source_Year)
        if source_Year[i] >= start_year && source_Year[i] <= end_year
            year_index = TimestepIndex(source_Year[i] - start_year + 1)
            # year_index = TimestepValue(source_Year[i]) # current bug in Mimi
            country_index = country_lookup[source_ISO3[i]]
            deathrate[year_index, country_index] = source_DeathRate[i]
        end
    end
end

function fill_emissions!(source, emissions_var, sample_id, start_year, end_year)
    for row in source
        if row.year >= start_year && row.year <= end_year && row.sample == sample_id
            year_index = TimestepIndex(row.year - start_year + 1)
            # year_index = TimestepValue(row.year) # current bug in Mimi
            emissions_var[year_index] = row.value
        end
    end
end

function fill_population1990!(source, population1990, country_lookup)
    for row in source
        country_index = country_lookup[row.ISO3]
        population1990[country_index] = row.Population # millions
    end
end

function fill_gdp1990!(source, gdp1990, population1990, country_lookup, sample_id)
    for row in source
        if row.sample == sample_id
            country_index = country_lookup[row.country]
            gdp1990[country_index] = (row.value * population1990[country_index]) .* pricelevel_2011_to_2005 ./ 1e3 # convert $2011 to $2005 and divide by 1e3 to get millions -> billions
        end
    end
end

@defcomp SPs begin

    country = Index()

    start_year = Parameter{Int}(default=Int(2020)) # year (annual) data should start
    end_year = Parameter{Int}(default=Int(2300)) # year (annual) data should end
    country_names = Parameter{String}(index=[country]) # need the names of the countries from the dimension
    id = Parameter{Int64}(default=Int(6546)) # the sample (out of 10,000) to be used
    
    population  = Variable(index=[time, country], unit="million")
    population_global  = Variable(index=[time], unit="million")
    deathrate   = Variable(index=[time, country], unit="deaths/1000 persons/yr")
    gdp         = Variable(index=[time, country], unit="billion US\$2005/yr")
    gdp_global         = Variable(index=[time], unit="billion US\$2005/yr")
    
    population1990  = Variable(index=[country], unit = "million")
    gdp1990         = Variable(index=[country], unit = unit="billion US\$2005/yr")
    
    co2_emissions   = Variable(index=[time], unit="GtC/yr")
    ch4_emissions   = Variable(index=[time], unit="MtCH4/yr")
    n2o_emissions   = Variable(index=[time], unit="MtN2/yr")

    function init(p,v,d)

        # add countrys to a dictionary where each country key has a value holding it's 
        # index in country_names
        country_lookup = Dict{String,Int}(name=>i for (i,name) in enumerate(p.country_names))
        country_indices = d.country::Vector{Int} # helper for type stable country indices

        # ----------------------------------------------------------------------
        # Socioeconomic Data
        #   population in millions of individuals
        #   GDP in billions of $2005 USD
       
        # Load Feather File
        t = Arrow.Table(joinpath(datadep"rffsps_v5", "pop_income", "rffsp_pop_income_run_$(p.id).feather"))
        fill_socioeconomics!(t.Year, t.Country, t.Pop, t.GDP, v.population, v.gdp, country_lookup, p.start_year, p.end_year)

        for year in p.start_year:5:p.end_year-5, country in country_indices
            year_as_timestep = TimestepIndex(year - p.start_year + 1)
            pop_interpolator = LinearInterpolation(Float64[year, year+5], [log(v.population[year_as_timestep,country]), log(v.population[year_as_timestep+5,country])])
            gdp_interpolator = LinearInterpolation(Float64[year, year+5], [log(v.gdp[year_as_timestep,country]), log(v.gdp[year_as_timestep+5,country])])
            for year2 in year+1:year+4
                year2_as_timestep = TimestepIndex(year2 - p.start_year + 1)
                v.population[year2_as_timestep,country] = exp(pop_interpolator[year2])
                v.gdp[year2_as_timestep,country] = exp(gdp_interpolator[year2])
            end
        end
        
        # add global data for future accessibility and quality control
        v.gdp_global[:,:] = sum(v.gdp[:,:], dims = 2) # sum across countries, which are the second dimension
        v.population_global[:,:] = sum(v.population[:,:], dims = 2) # sum across countries, which are the second dimension

        # ----------------------------------------------------------------------
        # Death Rate Data
        #   crude death rate in deaths per 1000 persons

        # key between population trajectory and death rates - each population
        # trajectory is assigned to one of the 1000 death rates
        if !haskey(g_datasets, :pop_trajectory_key)
            g_datasets[:pop_trajectory_key] = (load(joinpath(datadep"rffsps_v5", "sample_numbers", "sampled_pop_trajectory_numbers.csv")) |> DataFrame).x
        end
        deathrate_trajectory_id = convert(Int64, g_datasets[:pop_trajectory_key][p.id])
        
        # Load Feather File
        t = Arrow.Table(joinpath(datadep"rffsps_v5", "death_rates", "rffsp_death_rates_run_$(deathrate_trajectory_id).feather"))
        fill_deathrates!(t.Year, t.ISO3, t.DeathRate, v.deathrate, country_lookup, p.start_year, p.end_year)
        # TODO could handle the repeating of years here instead of loading bigger files

        # ----------------------------------------------------------------------
        # Emissions Data
        #   carbon dioxide emissions in GtC
        #   nitrous oxide emissions in MtN2
        #   methane emissions in MtCH4
        
        # add data to the global dataset if it's not there
        if !haskey(g_datasets, :ch4)
            g_datasets[:ch4] = load(joinpath(datadep"rffsps_v5", "emissions", "rffsp_ch4_emissions.csv")) |> DataFrame
        end
        if !haskey(g_datasets, :n2o)
            g_datasets[:n2o] = load(joinpath(datadep"rffsps_v5", "emissions", "rffsp_n2o_emissions.csv")) |> DataFrame
        end
        if !haskey(g_datasets, :co2)
            g_datasets[:co2] = load(joinpath(datadep"rffsps_v5", "emissions", "rffsp_co2_emissions.csv")) |> DataFrame
        end

        # fill in the variales
        fill_emissions!(IteratorInterfaceExtensions.getiterator(g_datasets[:ch4]), v.ch4_emissions, p.id, p.start_year, p.end_year)
        fill_emissions!(IteratorInterfaceExtensions.getiterator(g_datasets[:co2]), v.co2_emissions, p.id, p.start_year, p.end_year)
        fill_emissions!(IteratorInterfaceExtensions.getiterator(g_datasets[:n2o]), v.n2o_emissions, p.id, p.start_year, p.end_year)

        # ----------------------------------------------------------------------
        # Population and GDP 1990 Values

        if !haskey(g_datasets, :ypc1990)
            g_datasets[:ypc1990] = load(joinpath(datadep"rffsps_v5", "ypc1990", "rffsp_ypc1990.csv")) |> 
                DataFrame |> 
                i -> insertcols!(i, :sample => 1:10_000) |> 
                i -> stack(i, Not(:sample)) |> 
                DataFrame |> 
                i -> rename!(i, [:sample, :country, :value]) |> 
                DataFrame
        end
        if !haskey(g_datasets, :pop1990)
            g_datasets[:pop1990] = load(joinpath(@__DIR__, "..", "..", "data/population1990.csv")) |> DataFrame
        end

        fill_population1990!(IteratorInterfaceExtensions.getiterator(g_datasets[:pop1990]), v.population1990, country_lookup)
        fill_gdp1990!(IteratorInterfaceExtensions.getiterator(g_datasets[:ypc1990]), v.gdp1990, v.population1990, country_lookup, p.id)

    end

    function run_timestep(p,v,d,t)

        if !(gettime(t) in p.start_year:p.end_year)
            error("Cannot run SP component in year $(gettime(t)), SP data is not available for this model and year.")
        end

    end
end
