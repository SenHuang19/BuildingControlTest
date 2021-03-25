module MPC
using HTTP, JSON, CSV, DataFrames, Dates, Printf, DelimitedFiles, MathOptInterface
const MOI = MathOptInterface
# import the Julia script with the optimization model and associated dependencies
include("functions.jl")
global status_goodSolution = [MOI.OPTIMAL, MOI.LOCALLY_SOLVED, MOI.ALMOST_OPTIMAL]
global status_badSolution = [MOI.ALMOST_LOCALLY_SOLVED, MOI.INFEASIBLE, MOI.DUAL_INFEASIBLE, MOI.LOCALLY_INFEASIBLE, MOI.INFEASIBLE_OR_UNBOUNDED, MOI.ALMOST_INFEASIBLE, MOI.ALMOST_DUAL_INFEASIBLE]
global status_userLim = [MOI.ITERATION_LIMIT, MOI.TIME_LIMIT, MOI.NODE_LIMIT, MOI.SOLUTION_LIMIT, MOI.MEMORY_LIMIT, MOI.OBJECTIVE_LIMIT, MOI.NORM_LIMIT, MOI.OTHER_LIMIT]

global dfCurrentSetpoints = DataFrames.DataFrame()
global dfPastSetpoints = DataFrames.DataFrame()
global dfCurrentMeasurements = DataFrames.DataFrame()
global dfCurrentMeasurements_history = DataFrames.DataFrame()
global originalMaxIter = o.maxiter
global start_minute = 0
"""
This module implements an MPC controller.
"""

function compute_control!(u::Dict, currentMeasurements::Dict)
    # compute the control input from the measurement.
    # y contains the current values of the measurements.
    # {<measurement_name>:<measurement_value>}
    # compute the control input from the measurement.
    # u: dict Defines the control input to be used for the next step.
    # {<input_name> : <input_value>}
    # global start_minute = 288001 # 17280060/60
    current_minute = currentMeasurements["Time"]/60.0
    # println("MPC:",start_minute)
    minute = current_minute - start_minute
    minute_of_day = Helper.minute_of_day(current_minute)
    global dfCurrentMeasurements = dict2df!(dfCurrentMeasurements, currentMeasurements)
    # note df_history only requires "updated" measurements, not setpoints
    global dfCurrentMeasurements_history = minute == 1.0 ? dfCurrentMeasurements : updatehistory!(dfCurrentMeasurements_history, dfCurrentMeasurements)

    h, c =  comfortbounds(current_minute)
    pred_oat = predictambient(dfCurrentMeasurements[1, :TOutDryBul_y], minute_of_day)
    # obtain internal loads for each zone (3D array)
    pred_load = predictloads(dfCurrentMeasurements_history)
    # Renew the energy price
    price = currentMeasurements["EnergyPrice"]
    # update MPC model parameters
    mpc_params = Dict("EnergyPrice"=>price, "heat_sp" => h, "cool_sp" => c, "pred_oat" => pred_oat, "pred_loads" => pred_load)
    updatemodelparams(dfCurrentMeasurements, mpc_params)

    # solve MPC model
    global solverinfo = solvemodel()
    @printf("================= Quick statistics of optimization algorithms. =============\n")
    @printf("Going for %d max iterations.\n", o.maxiter)
    # println(JuMP.SimplexIterations(m))
    #println(MOI.get(m, MOI.SimplexIterations()))
    @printf("Optimization took %.4f seconds, and ended with status %s.\n", solverinfo["soltime"], solverinfo["status"])
    #@printf("size of ahusupplytemp: %d, %d, %d\n", size(ahusupplytemp, 1), size(ahusupplytemp, 2), size(ahusupplytemp, 3))
    #@printf("size of ahudamper: %d, %d, %d\n", size(ahudamper, 1), size(ahudamper, 2), size(ahudamper, 3))
    #@printf("size of zonedischargetemp: %d, %d, %d\n", size(zonedischargetemp, 1), size(zonedischargetemp, 2), size(zonedischargetemp, 3))
    #@printf("size of zoneflow: %d, %d, %d\n", size(zoneflow, 1), size(zoneflow, 2), size(zoneflow, 3))
    #@printf("size of ahupressures: %d, %d, %d\n", size(ahupressures, 1), size(ahupressures, 2), size(ahupressures, 3))
    #@printf("size of zonetemp: %d, %d, %d\n", size(zonetemp, 1), size(zonetemp, 2), size(zonetemp, 3))
    for f = 1 : p.numfloors
        @printf("floor %d -> ahusupplytemp = %.4f, constrain: [%.2f, %.2f]\n", f, JuMP.value(ahusupplytemp[f, 1]), p.ahusupplytemp_min, p.ahusupplytemp_max)
        @printf("floor %d -> ahudamper = %.4f, constrain: [%.2f, %2f]\n", f, JuMP.value(ahudamper[f, 1]), p.damper_min[f], p.damper_max[f])
        for z = 1 : p.numzones
            @printf("floor %d, zone %d -> zonedischargetemp = %.4f, constrain: [%.2f, %2f]\n", f, z, JuMP.value(zonedischargetemp[f, z, 1]), JuMP.value(ahusupplytemp[f, 1]), p.zonedischargetemp_max)
            @printf("floor %d, zone %d -> zoneflow = %.4f, constrain: [%.2f, %2f]\n", f, z, JuMP.value(zoneflow[f, z, 1]), p.zoneflow_min[z], p.zoneflow_max[z])
            @printf("floor %d, zone %d -> reheat valve opening = %.4f, constrain: [%.2f, %2f]\n", f, z, JuMP.value(zoneflow[f, z, 1])/p.zoneflow_max[z], p.zoneflow_min[z]/p.zoneflow_max[z], p.zoneflow_max[z]/p.zoneflow_max[z])
        end
    end
    global currMPCStatus = solverinfo["status"]
    if in(solverinfo["status"], status_goodSolution)
      # store current overrides
      global currMPCStage = 1
      @printf("Using stage %d of the MPC prediction horizon.\n", currMPCStage)
      global dfCurrentSetpoints = setoverrides!(dfCurrentSetpoints, control = "MPC", stage = currMPCStage)
      @printf("<<<<<<< RE-INITIALIZE THE MODEL WITH THE LAST VALUES OF THE PREVIOUS SOLVER. >>>>>>>\n")
      JuMP.set_start_value.(JuMP.all_variables(m), JuMP.value.(JuMP.all_variables(m)))
      o.maxiter = originalMaxIter
      @printf("New max iteration number: %d.\n", o.maxiter)
    elseif solverinfo["status"] == status_userLim[1] # MOI.ITERATION_LIMIT
      global currMPCStage = "n/a"
      @printf("<<<<< THIS TIME: USER MAXIMUM ITERATION NUMBER REACHED. >>>>>>>\n")
      @printf("<<<<<<< RE-INITIALIZE THE MODEL WITH THE LAST VALUES OF THE PREVIOUS SOLVER. >>>>>>>\n")
      JuMP.set_start_value.(JuMP.all_variables(m), JuMP.value.(JuMP.all_variables(m)))
      # store previously computed MPC overrides
      global dfCurrentSetpoints = setoverrides!(dfCurrentSetpoints, dfPastSetpoints, minute_of_day, control = "MPC")
      o.maxiter += 100
      @printf("New max iteration number: %d.\n", o.maxiter)
    elseif in(solverinfo["status"], status_badSolution)
      global currMPCStage = "n/a"
      @printf("Optimization algorithm terminated with INFEASIBLE or UNBOUNDED solution.\n")
      @printf("<<<<<<< RE-INITIALIZE THE MODEL WITH THE LAST VALUES OF THE PREVIOUS SOLVER. >>>>>>>\n")
      JuMP.set_start_value.(JuMP.all_variables(m), JuMP.value.(JuMP.all_variables(m)))
      # store previously computed MPC overrides
      global dfCurrentSetpoints = setoverrides!(dfCurrentSetpoints, dfPastSetpoints, minute_of_day, control = "MPC")
    elseif in(solverinfo["status"], status_userLim[2:end])
      global currMPCStage = "n/a"
      @printf("<<<<<<< SOME OTHER SORT OF LIMIT HAS BEEN REACHED, that is %s. >>>>>>>>>>", string(solverinfo["status"]))
      @printf("<<<<<<< RE-INITIALIZE THE MODEL WITH THE LAST VALUES OF THE PREVIOUS SOLVER. >>>>>>>\n")
      JuMP.set_start_value.(JuMP.all_variables(m), JuMP.value.(JuMP.all_variables(m)))
      # store previously computed MPC overrides
      global dfCurrentSetpoints = setoverrides!(dfCurrentSetpoints, dfPastSetpoints, minute_of_day, control = "MPC")
    end
    mpcOptEndTime = Base.Libc.time()
    global dfPastSetpoints = deepcopy(dfCurrentSetpoints)
    # send back data (with overrides)
    u = df2dict!(u, dfCurrentSetpoints) # u
    return u
end

function initialize()
    # u: dict Defines the initial control input to be used for the next step.
    # {<input_name> : <input_value>}
    # u = Dict("oveAct_u" => 0.0,"oveAct_activate" => 1)
    # u = ctrlInitialize(case.inputs)
    global u = Dict{String, Float64}()
    for f = 1 : p.numfloors
        # damper setpoint
        u["floor$(f)_aHU_con_oveMinOAFra_activate"] = 0
        u["floor$(f)_aHU_con_oveMinOAFra_u"] = 1e-27
        # ahu supply temperatures
        u["floor$(f)_aHU_con_oveTSetSupAir_activate"] = 0
        u["floor$(f)_aHU_con_oveTSetSupAir_u"] = 35 # Celsius
        # static pressure setpoint
        u["set_ahupressure_f$(f)"] = 100
        for z = 1 : p.numzones
            u["floor$(f)_zon$(z)_oveTSetDisAir_activate"] = 0
            u["floor$(f)_zon$(z)_oveTSetDisAir_u"] = 1e-27
            u["floor$(f)_zon$(z)_oveAirFloRat_activate"] = 0
            u["floor$(f)_zon$(z)_oveAirFloRat_u"] = 1e-27
            u["floor$(f)_zon$(z)_oveHeaOut_activate"] = 0
            u["floor$(f)_zon$(z)_oveHeaOut_u"] = 1e-27
        end
    end
    # global CurrentMeasurements = Dict{String, Float64}()
    # CurrentMeasurements["TOutDryBul_y"] = 35.0
    # CurrentMeasurements["EnergyPrice"] = 1.0
    # for f = 1 : p.numfloors
    #     # ahu supply temperatures
    #     CurrentMeasurements["floor$(f)_TSupAir_y"] = 20.0
    #     CurrentMeasurements["floor$(f)_TMixAir_y"] = 25.0 # Celsius
    #     CurrentMeasurements["floor$(f)_TRetAir_y"] = 35.0 # Celsius
    #     for z = 1 : p.numzones
    #         CurrentMeasurements["floor$(f)_zon$(z)_TRooAir_y"] = 20.0 #zonetemp
    #         CurrentMeasurements["floor$(f)_zon$(z)_TSupAir_y"] = 15.0# zonedischargetemp
    #         CurrentMeasurements["floor$(f)_zon$(z)_mSupAir_y"] = 5.0 # zoneflow
    #     end
    # end
    global dfCurrentSetpoints = dict2df!(dfCurrentSetpoints, u)
    return u #, CurrentMeasurements
end

end

# module PID
#
# function compute_control(y::Dict)
#     # compute the control input from the measurement.
#     # y contains the current values of the measurements.
#     # {<measurement_name>:<measurement_value>}
#     # compute the control input from the measurement.
#     # u: dict Defines the control input to be used for the next step.
#     # {<input_name> : <input_value>}
#
#     # control parameters
#     LowerSetp = 273.15 + 20
#     UpperSetp = 273.15 + 23
#     k_p = 2000
#
#     # compute control
#     if y["TRooAir_y"]<LowerSetp
#         e = LowerSetp - y["TRooAir_y"]
#     elseif y["TRooAir_y"]>UpperSetp
#         e = UpperSetp - y["TRooAir_y"]
#     else
#         e = 0
#     end
#
#     value = k_p*e
#     u = Dict("oveAct_u" => value,"oveAct_activate" => 1)
#     return u
# end
#
# function initialize()
#     # u: dict Defines the initial control input to be used for the next step.
#     # {<input_name> : <input_value>}
#     u = Dict("oveAct_u" => 0.0,"oveAct_activate" => 1)
#     return u
# end
#
# end
#
#
# module sup
#
# """
#
# This module implements an external signal to overwrite existing controllers in the emulator.
#
# """
#
# function compute_control(y::Dict)
#     # compute the control input from the measurement.
#     # y contains the current values of the measurements.
#     # {<measurement_name>:<measurement_value>}
#     # compute the control input from the measurement.
#     # u: dict Defines the control input to be used for the next step.
#     # {<input_name> : <input_value>}
#
#     u = Dict("oveTSetRooHea_u" => 22+273.15,"oveTSetRooHea_activate" => 1,"oveTSetRooCoo_u" => 23+273.15,"oveTSetRooCoo_activate" => 1)
#     return u
# end
#
# function initialize()
#     # u: dict Defines the initial control input to be used for the next step.
#     # {<input_name> : <input_value>}
#     u = Dict("oveTSetRooHea_u" => 22+273.15,"oveTSetRooHea_activate" => 1,"oveTSetRooCoo_u" => 23+273.15,"oveTSetRooCoo_activate" => 1)
#     return u
# end
#
# end
