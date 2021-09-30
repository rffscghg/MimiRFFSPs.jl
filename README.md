# MimiRFFSPs.jl 

This repository holds a component using the [Mimi](https://www.mimiframework.org) framework which provides parameters from the Resources for the Future (RFF) RFF Socioeconomic Projections (RFF SPs). These include socioeconomic (population and GDP) and emissions (CO2, CH4, and CH4), to be connected with as desired with other Mimi components and run in Mimi models.

## Preparing the Software Environment

To add the package to your current environment, run the following command at the julia package REPL:
```julia
pkg> add https://github.com/anthofflab/MimiRFFSPs.jl.git
```
You probably also want to install the Mimi package into your julia environment, so that you can use some of the tools in there:
```
pkg> add Mimi
```

## Running the Model

The model uses the Mimi framework and it is highly recommended to read the Mimi documentation first to understand the code structure. This model presents two components, which will most often be used in tandem. The basic way to access the MimiRFFSPs components, both `RFF-SPs` and `RegionAggregatorSum` and explore the results is the following:

```julia
using Mimi 
using MimiRFFSPs

# Create the a model
m = Model()

# Set the time dimension for the whole model, which can run longer than an individual component if desired
set_dimension!(m, :time, 1750:2300)

# Add the Sps component as imported from `MimiRFFSPs`
add_comp!(m, MimiRFFSPs.SPs, first = 2020, last = 2300)

# Set country dimension and related parameter: this should indicate all the countries you wish to pull SP data for, noting that you must provide a subset of the three-digit ISO country codes you can find here: `data/keys/MimiRFFSPs_ISO3.csv`.  In this case we will use all of them for illustrative purposes.
all_countries = load(joinpath(@__DIR__, "data", "keys", "MimiRFFSPs_ISO3.csv")) |> DataFrame
set_dimension!(m, :country, all_countries.ISO3)
update_param!(m, :SPs, :country_names, all_countries.ISO3) # should match the dimension

# Run the model
run(m)

# Explore interactive plots of all the model output.
explore(m)

# Access a specific variable
emissions = m[:SPs, :gdp]
```
Importantly, note that there is an optional parameter in this component, `id` which defaults to `1`, the "most likely" case to produce a single run [TODO decide how to choose this and explain further] for debugging purposes.  This refers to the run with ID `1` in `data/projections`.  By nature of the projections, this component should be run using a Monte Carlo Simulation sampling over the IDs in order to obtain a representative distribution of plausible outcomes. See the section below for more information.

---

Now say you want to connect the `m[:SPs, :population]` output variable to another Mimi component that requires population at a regional level.  This is where the `RegionAggregatorSum` component can be helpful, which, as the name indicates, aggregates countries to regions with a provided mapping via the `sum` function (other functions can be added as desired, this is a relatively new and nimble component). You will need to provide a mapping between the input regions (countries here) and output regions (regions here) in a Vector of the length of the input regions and each element being one of the output regions.

```julia
# Start with the model `m` from above and add the component with the name `:PopulationAggregator`
add_comp!(m, MimiRFFSPs.RegionAggregatorSum, :PopulationAggregator, first = 2020, last = 2300)

# Bring in a dummy mapping between the countries list from the model above and our current one. Note that this DataFrame has two columns, `InputRegion` and `OutputRegion`, where `InputRegion` is identical to `all_countries.ISO3` above but we will reset here for clarity.
mapping = load(joinpath(@__DIR__, "data", "keys", "MimiRFFSPs_dummyInputOutput.csv")) |> DataFrame
inputregions = mapping.Input_Region
outputregions = sort(unique(mapping.Output_Region))

# Set the region dimensions
set_dimension!(m, :inputregions, inputregions)
set_dimension!(m, :outputregions, outputregions)

# Provide the mapping parameter as well as the the names of the input regions and output regions, which should just take copies of what you provided to `set_dimension!` above
update_param!(m, :PopulationAggregator, :input_region_names, inputregions)
update_param!(m, :PopulationAggregator, :output_region_names, outputregions)
update_param!(m, :PopulationAggregator, :input_output_mapping, mapping.Output_Region) # Vector with length of input regions, each element matching an output region in the output_region_names parameter (and outputregions dimension)

# Make SPs component `:population` variable the feed into the `:input` variable of the `PopulationAggregator` component
connect_param!(m, :PopulationAggregator, :input, :SPs, :population)

run(m)

# View the aggregated population variable, aggregated from 171 countries to 11 regions
getdataframe(m, :PopulationAggregator, :output)

```

## A Note on Sampling and Monte Carlo Simulations

[TODO] 

## Data and Calibration

- [TODO citation]
- [TODO describe source https://github.com/rffscghg/rff-socioeconomic-projections when public]
- The _data/projections_ folder holds one file per projection, making 10,000 files in each of the subfolders _socioeconomic_ and _emissions_.
