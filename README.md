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

# Set country dimension and related parameter: As of now this must be exactly the 184 countries in the following file, but we will add flexibility for this in the future.
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
The `id` parameter in this component (default id of 6546) which allows one to run the model with a specified parameter set of ID `id` within the data.  By nature of these projections, this component should be run using a Monte Carlo Simulation sampling over the IDs in order to obtain a representative distribution of plausible outcomes, but providing an ID may be useful for debugging purposes. See the section below for more information.

Also note that the `SPs` component has optional arguments `start_year` (default = 2020) and `end_year` (default = 2300) that can be altered to values within the 2020 - 2300 timeframe.  Timesteps must be annual as of now, but we will add flexibility to this in the future.

---

If a user wants to connect the `m[:SPs, :population]` output variable to another Mimi component that requires population at a more aggregated regional level, the `RegionAggregatorSum` component can be helpful. This helper component aggregates countries to regions with a provided mapping via the `sum` function (other functions can be added as desired, this is a relatively new and nimble component). You will need to provide a mapping between the input regions (countries here) and output regions (regions here) in a Vector of the length of the input regions and each element being one of the output regions. Note that this component is not yet optimized for performance.

```julia
# Start with the model `m` from above and add the component with the name `:PopulationAggregator`
add_comp!(m, MimiRFFSPs.RegionAggregatorSum, :PopulationAggregator, first = 2020, last = 2300)

# Bring in a dummy mapping between the countries list from the model above and our current one. Note that this DataFrame has two columns, `InputRegion` and `OutputRegion`, where `InputRegion` is identical to `all_countries.ISO3` above but we will reset here for clarity.
mapping = load(joinpath(@__DIR__, "test", "data", "MimiRFFSPs_dummyInputOutput.csv")) |> DataFrame
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

# View the aggregated population variable, aggregated from 184 countries to 11 regions
getdataframe(m, :PopulationAggregator, :output)

```

## Data Sources

Most data inputs to this model and components are hosted on `Zenodo.com` and retrieved upon  along with a snapshot of the `rff-socioeconomic-projections` private Github repository at the time when these data were produced. These files will be downloaded automatically to your machine upon running this package, as indicated by the following `__init__()` function specification from `MimiRFFSPs.jl`.

```
function __init__()
    register(DataDep(
        "rffsps_v5",
        "RFF SPs version v5",
        "https://zenodo.org/record/6016583/files/rffsps_v5.7z",
        "a39b51d7552d198123b1863ea5a131533715a7a7c9ff6fad4b493594ece49497",
        post_fetch_method=unpack
    ))
end
```

Details on any files hosted within this repository in the `data` folder can be found in Data_README.md within that folder.

## Citations

Rennert, K. et al. The Social Cost of Carbon: Advances in Long-Term Probabilistic Projections of Population, GDP, Emissions, and Discount Rates. Brook. Pap. Econ. Act. (Forthcoming).

