using MimiRFFSPs

# test higher level functionality

# 1. get_model 

m = MimiRFFSPs.get_model()
run(m)
explore(m)

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

# Explore the resulting distributions of co2 emissions and ID
explore(results)

# Alternatively run the Monte Carlo Simulation on model `m` for sample ids 1,2, and 3
# note here that `num_trials` provided (3) must be shorter than or equal to the 
# length of the provided vector of IDs
mcs = MimiRFFSPs.get_mcs([1,2,3])
Mimi.add_save!(mcs, (:rffsp, :id))
Mimi.add_save!(mcs, (:rffsp, :co2_emissions))
results = run(mcs, m, 3)
explore(results)
