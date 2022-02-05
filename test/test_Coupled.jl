using Mimi, MimiRFFSPs, DataFrames, CSVFiles, Query, Test

dummy_input_output = load(joinpath(@__DIR__, "data", "MimiRFFSPs_dummyInputOutput.csv")) |> DataFrame

inputregions = dummy_input_output.Input_Region
outputregions = sort(unique(dummy_input_output.Output_Region))

m = Model()
set_dimension!(m, :time, 2000:2300)

# Handle the MimiRFFSPs.SPs component
add_comp!(m, MimiRFFSPs.SPs, first = 2020)
set_dimension!(m, :country, inputregions)
update_param!(m, :SPs, :country_names, inputregions)

# Handle the MimiRFFSPs.RegionAggregatorSum component
add_comp!(m, MimiRFFSPs.RegionAggregatorSum, first = 2020)

set_dimension!(m, :inputregions, inputregions)
set_dimension!(m, :outputregions, outputregions)

update_param!(m, :RegionAggregatorSum, :input_region_names, inputregions)
update_param!(m, :RegionAggregatorSum, :output_region_names, outputregions)
update_param!(m, :RegionAggregatorSum, :input_output_mapping, dummy_input_output.Output_Region)

connect_param!(m, :RegionAggregatorSum, :input, :SPs, :population)

run(m)

# Should also work if Aggregator runs long, using backup data
Mimi.set_first_last!(m, :RegionAggregatorSum, first = 2000)
backup = zeros(301, 184)
connect_param!(m, :RegionAggregatorSum, :input, :SPs, :population, backup, ignoreunits=true)

run(m)
