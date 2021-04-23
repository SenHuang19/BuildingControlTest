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
url = "http://127.0.0.1:5500"#"http://eplus:5500"
length = 24 * 3600
step = 60
step_def = JSON.parse(String(HTTP.get("$url/step").body))
HTTP.post("$url/advance", ["Content-Type" => "application/json","connecttimeout"=>30.0], JSON.json(Dict());retry_non_idempotent=true)
HTTP.put("$url/reset",["Content-Type" => "application/json"], JSON.json(Dict("start_time" => 190*86400,"end_time" => 204*86400)))

#
numfloors = 3
numzones = 5

global u_ini = MPC.initialize()

#Timestep = 1; # Read the $Timestep row of csv file
global CurrentMeasurements = Dict{String, Float64}()

# Simulation time in seconds
for Timestep in 1:1:1440*14
    if Timestep == 1
	    global df_y = DataFrames.DataFrame()
	    global u = u_ini
	    global u_control = Dict{String, Float64}()
		global y = JSON.parse(String(HTTP.post("$url/advance", ["Content-Type" => "application/json","connecttimeout"=>30.0], JSON.json(u_control);retry_non_idempotent=true).body))
		global start_minute = y["time"]/60
		@eval MPC start_minute,dfPastSetpoints = Main.start_minute, MPC.dict2df!(MPC.dfPastSetpoints,Main.u)
		println("Starting minute:",start_minute)
    elseif mod(Timestep,5) ==0
	  if y["occ"]>0
	    u = MPC.compute_control!(u, CurrentMeasurements)
	    for f = 1 : numfloors
#          u_control["floor$(f)_ahu_dis_temp_set_u"] = u["floor$(f)_aHU_con_oveTSetSupAir_u"]
#          u_control["floor$(f)_ahu_dis_temp_set_activate"] = 1
          println(u["floor$(f)_aHU_con_oveTSetSupAir_u"])
          for z = 1 : numzones
		     Tz_ind = (f-1)*numfloors + z
             u_control["mAirFlow[$(Tz_ind)]"] = u["floor$(f)_zon$(z)_oveAirFloRat_u"]
             u_control["mAirFlow_activate[$(Tz_ind)]"] = 1
			 println(u["floor$(f)_zon$(z)_oveAirFloRat_u"])
#             u_control["yPos[$(Tz_ind)]"] = u["floor$(f)_zon$(z)_oveHeaOut_u"]
#             u_control["yPos_activate[$(Tz_ind)]"] = 1
          end
        end
      else
        u_control = Dict{String, Float64}()
      end
	  y = JSON.parse(String(HTTP.post("$url/advance", ["Content-Type" => "application/json","connecttimeout"=>30.0], JSON.json(u_control);retry_non_idempotent=true).body))
	else
	  y = JSON.parse(String(HTTP.post("$url/advance", ["Content-Type" => "application/json","connecttimeout"=>30.0], JSON.json(u_control);retry_non_idempotent=true).body))
    end
	df_y = MPC.dict2df!(df_y, y) # Convert y into dataframes
	if Timestep == 1
		CSV.write("./result_all.csv", df_y)
	else
		CSV.write("./result_all.csv", df_y, append=true)
	end
	CurrentMeasurements["Time"] = y["time"];
	CurrentMeasurements["TOutDryBul_y"] = y["outdoor_air_temp"];
	CurrentMeasurements["EnergyPrice"] = 1.0
	for f = 1 : numfloors
    # ahu supply temperatures
       CurrentMeasurements["floor$(f)_TSupAir_y"] = y["floor$(f)_ahu_dis_T"]-273.15# Celsius
       CurrentMeasurements["floor$(f)_TMixAir_y"] = y["floor$(f)_ahu_mix_T"]-273.15# Celsius
       CurrentMeasurements["floor$(f)_TRetAir_y"] = y["floor$(f)_ahu_ret_T"]-273.15# Celsius
       for z = 1 : numzones
          Tz_ind = (f-1)*numfloors + z # Index of TZone[Tz_ind]
          CurrentMeasurements["floor$(f)_zon$(z)_TRooAir_y"] = y["TZon[$(Tz_ind)]"]-273.15 #zonetemp
          CurrentMeasurements["floor$(f)_zon$(z)_TSupAir_y"] = y["floor$(f)_vav$(z)_dis_T"]-273.15# zonedischargetemp
          CurrentMeasurements["floor$(f)_zon$(z)_mSupAir_y"] = y["floor$(f)_vav$(z)_dis_mflow"]# # zoneflow
       end
    end
end
