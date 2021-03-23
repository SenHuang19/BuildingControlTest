###This module is an example julia-based testing interface.  It uses the
###``requests`` package to make REST API calls to the test case container,
###which mus already be running.  A controller is tested, which is
###imported from a different module.


# GENERAL PACKAGE IMPORT
# ----------------------
using HTTP, JSON, CSV, DataFrames

# TEST CONTROLLER IMPORT
# ----------------------
include("./controllers.jl")
using .MPC

clearconsole()

Results_file = "./results1.csv"
df = CSV.read(Results_file, DataFrame);

#
numfloors = 3
numzones = 5

u = MPC.initialize()

Timestep = 10; # Read the $Timestep row of csv file
global CurrentMeasurements = Dict{String, Float64}()
# Simulation time in seconds
CurrentMeasurements["Time"] = df[!, Symbol("time")][Timestep];
# Outside temperature in Kelvin
CurrentMeasurements["TOutDryBul_y"] = df[!, Symbol("outdoor_air_temp")][Timestep]-273.15 # in Celsius
# Real time price...
CurrentMeasurements["EnergyPrice"] = 1.0

for f = 1 : numfloors
    # ahu supply temperatures
    CurrentMeasurements["floor$(f)_TSupAir_y"] = df[!, Symbol("floor$(f)_ahu_dis_T")][Timestep]-273.15# Celsius
    CurrentMeasurements["floor$(f)_TMixAir_y"] = df[!, Symbol("floor$(f)_ahu_mix_T")][Timestep]-273.15# Celsius
    CurrentMeasurements["floor$(f)_TRetAir_y"] = df[!, Symbol("floor$(f)_ahu_ret_T")][Timestep]-273.15# Celsius
    for z = 1 : numzones
        Tz_ind = (f-1)*numfloors + z # Index of TZone[Tz_ind]
        CurrentMeasurements["floor$(f)_zon$(z)_TRooAir_y"] = df[!, Symbol("TZon[$(Tz_ind)]")][Timestep]-273.15 #zonetemp
        CurrentMeasurements["floor$(f)_zon$(z)_TSupAir_y"] = df[!, Symbol("floor$(f)_vav$(z)_dis_T")][Timestep]-273.15# zonedischargetemp
        CurrentMeasurements["floor$(f)_zon$(z)_mSupAir_y"] = df[!, Symbol("floor$(f)_vav$(z)_dis_mflow")][Timestep]# # zoneflow in Kg/s
    end
end

# u, CurrentMeasurements = MPC.initialize()

u = MPC.compute_control!(u, CurrentMeasurements)
println(u["floor1_aHU_con_oveMinOAFra_u"])
