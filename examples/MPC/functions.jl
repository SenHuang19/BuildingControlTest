# include standard packages
using ConfParser, DataFrames, CSV, JuMP, Ipopt, MathOptInterface

# include user-defined scripts and modules
include("helperfunctions.jl")
using .Helper

"""
Function to parse strings from config files to integer values.
"""
function parse_int(conf::ConfParser.ConfParse, section::AbstractString, variable::AbstractString)
    x = ConfParser.retrieve(conf, section, variable)
    return round(Int64, parse(Float64, x))
end


"""
Function to parse strings from config files to floating-point values.
"""
function parse_float(conf::ConfParser.ConfParse, section::AbstractString, variable::AbstractString)
    x = ConfParser.retrieve(conf, section, variable)
    return parse(Float64, x)
end

function parse_bool(conf::ConfParser.ConfParse, section::AbstractString, variable::AbstractString)
    x = ConfParser.retrieve(conf, section, variable)
    return parse(Bool, x)
end

# define user-defined data types to store model parameters
"""
Data type to store building-specific parameters.
"""
mutable struct Params
    numzones::Int
    numfloors::Int
    eff_cool::Float64
    eff_heat::Float64
    specheat::Float64
    zonetemp_min_occ::Float64              # heating setpoint in occupied period
    zonetemp_max_occ::Float64              # cooling setpoint in occupied period
    zonetemp_min_uocc::Float64             # heating setpoint in unoccupied period
    zonetemp_max_uocc::Float64             # cooling setpoint in unoccupied period
    zoneflow_min::Array{Float64,2}         # of size (numfloors, numzones)
    zoneflow_max::Array{Float64,2}         # of size (numfloors, numzones)
    zonedischargetemp_max::Float64         # max zone discharge temp max
    zonetemp_alpha::Array{Float64, 2}      # of size (numfloors, numzones)
    zonetemp_beta::Array{Float64, 2}       # of size (numfloors, numzones)
    zonetemp_gamma::Array{Float64, 2}      # of size (numfloors, numzones)
    ahusupplytemp_min::Float64
    ahusupplytemp_max::Float64
    ahusupplytemp_max_dev::Float64
    ahuflow_min::Vector{Float64}           # of length numfloors
    ahuflow_max::Vector{Float64}           # of length numfloors
    fan_params::Array{Float64,2}            # of length 4
    # pressure_min::Vector{Float64}
    # pressure_max::Vector{Float64}
    massflow_sample_0::Vector{Float64}
    massflow_sample_1::Vector{Float64}
    massflow_sample_2::Vector{Float64}
    massflow_sample_3::Vector{Float64}
    massflow_sample_4::Vector{Float64}
    massflow_sample_5::Vector{Float64}
    pressure_sample_0::Vector{Float64}
    pressure_sample_1::Vector{Float64}
    pressure_sample_2::Vector{Float64}
    pressure_sample_3::Vector{Float64}
    pressure_sample_4::Vector{Float64}
    pressure_sample_5::Vector{Float64}
    damper_min::Vector{Float64}
    damper_max::Vector{Float64}
    # startup_time::Int
    # shutdown_time::Int
    # intercept::Float64              # Power regression model - intercept
    # linear::Float64                 # Power regression model - linear term
    # quad::Float64                   # Power regression model - quadratic term
    # cubic::Float64                  # Power regression model - cubic term


    # inner constructor to initilize an object of type Params
    function Params()
        # read config file for optimization and model parameters
        conf = ConfParse("./config_bldgparams.ini")
        parse_conf!(conf)

        # define new instance
        obj = new()

        ## populate the fields of the instance
        # building-specific params
        section = "building_params"
        obj.numzones = parse_int(conf, section, "numzones")
        obj.numfloors = parse_int(conf, section, "numfloors")
        obj.eff_cool = parse_float(conf, section, "eff_cool")
        obj.eff_heat = parse_float(conf, section, "eff_heat")
        obj.specheat = parse_float(conf, section, "specheat")

        # comfort-level params
        section = "comfort_params"
        obj.zonetemp_min_occ = parse_float(conf, section, "zonetemp_min_occ")
        obj.zonetemp_max_occ = parse_float(conf, section, "zonetemp_max_occ")
        obj.zonetemp_min_uocc = parse_float(conf, section, "zonetemp_min_uocc")
        obj.zonetemp_max_uocc = parse_float(conf, section, "zonetemp_max_uocc")

        # zone flow parameters
        section = "zoneflow_params"
        obj.zoneflow_min = ones(obj.numfloors, obj.numzones)
        obj.zoneflow_max = ones(obj.numfloors, obj.numzones)
        for f in 1:obj.numfloors, z in 1:obj.numzones
            obj.zoneflow_min[f, z] = parse_float(conf, section, "floor$(f)_zone$(z)_flow_min")
            obj.zoneflow_max[f, z] = parse_float(conf, section, "floor$(f)_zone$(z)_flow_max")
        end

        # zone temp parameters alpha, beta and gamma
        obj.zonetemp_alpha = ones(obj.numfloors, obj.numzones)
        obj.zonetemp_beta = ones(obj.numfloors, obj.numzones)
        obj.zonetemp_gamma = ones(obj.numfloors, obj.numzones)
        for f in 1:obj.numfloors, z in 1:obj.numzones
            section = "zonetemp_alphas"
            obj.zonetemp_alpha[f, z] = parse_float(conf, section, "floor$(f)_zone$(z)_alpha")
            section = "zonetemp_betas"
            obj.zonetemp_beta[f, z] = parse_float(conf, section, "floor$(f)_zone$(z)_beta")
            section = "zonetemp_gammas"
            obj.zonetemp_gamma[f, z] = parse_float(conf, section, "floor$(f)_zone$(z)_gamma")
        end

        # zone discharge temp parameter
        section = "dischargetemp"
        obj.zonedischargetemp_max = parse_float(conf, section, "zonedischargetemp_max")

        # AHU level parameters
        section = "ahu_params"
        obj.ahusupplytemp_min = parse_float(conf, section, "ahusupplytemp_min")
        obj.ahusupplytemp_max = parse_float(conf, section, "ahusupplytemp_max")
        obj.ahusupplytemp_max_dev = parse_float(conf, section, "ahusupplytemp_max_dev")
        obj.ahuflow_min = ones(obj.numfloors)
        obj.ahuflow_max = ones(obj.numfloors)
        for f in 1:obj.numfloors
            obj.ahuflow_min[f] = parse_float(conf, section, "floor$(f)_ahuflow_min")
            obj.ahuflow_max[f] = parse_float(conf, section, "floor$(f)_ahuflow_max")
        end

        # fan parameters
        section = "fan_params"
        obj.fan_params = ones(obj.numfloors, 4)
        for f in 1:obj.numfloors
            for i in 1:4
                obj.fan_params[f, i] = parse_float(conf, section, "floor$(f)_fan_param$(i)")
            end
        end

        # static pressure parameters
        section = "pressure_damper_params"
        # obj.pressure_min = ones(obj.numfloors)
        # obj.pressure_max = ones(obj.numfloors)
        obj.massflow_sample_0 = ones(obj.numfloors)
        obj.massflow_sample_1 = ones(obj.numfloors)
        obj.massflow_sample_2 = ones(obj.numfloors)
        obj.massflow_sample_3 = ones(obj.numfloors)
        obj.massflow_sample_4 = ones(obj.numfloors)
        obj.massflow_sample_5 = ones(obj.numfloors)
        obj.pressure_sample_0 = ones(obj.numfloors)
        obj.pressure_sample_1 = ones(obj.numfloors)
        obj.pressure_sample_2 = ones(obj.numfloors)
        obj.pressure_sample_3 = ones(obj.numfloors)
        obj.pressure_sample_4 = ones(obj.numfloors)
        obj.pressure_sample_5 = ones(obj.numfloors)
        obj.damper_min = ones(obj.numfloors)
        obj.damper_max = ones(obj.numfloors)
        for f in 1:obj.numfloors
            obj.massflow_sample_0[f] = parse_float(conf, section, "floor$(f)_massflow_sample_0")
            obj.massflow_sample_1[f] = parse_float(conf, section, "floor$(f)_massflow_sample_1")
            obj.massflow_sample_2[f] = parse_float(conf, section, "floor$(f)_massflow_sample_2")
            obj.massflow_sample_3[f] = parse_float(conf, section, "floor$(f)_massflow_sample_3")
            obj.massflow_sample_4[f] = parse_float(conf, section, "floor$(f)_massflow_sample_4")
            obj.massflow_sample_5[f] = parse_float(conf, section, "floor$(f)_massflow_sample_5")
            obj.pressure_sample_0[f] = parse_float(conf, section, "floor$(f)_pressure_sample_0")
            obj.pressure_sample_1[f] = parse_float(conf, section, "floor$(f)_pressure_sample_1")
            obj.pressure_sample_2[f] = parse_float(conf, section, "floor$(f)_pressure_sample_2")
            obj.pressure_sample_3[f] = parse_float(conf, section, "floor$(f)_pressure_sample_3")
            obj.pressure_sample_4[f] = parse_float(conf, section, "floor$(f)_pressure_sample_4")
            obj.pressure_sample_5[f] = parse_float(conf, section, "floor$(f)_pressure_sample_5")
            # obj.pressure_min[f] = parse_float(conf, section, "floor$(f)_pressure_min")
            # obj.pressure_max[f] = parse_float(conf, section, "floor$(f)_pressure_max")
            obj.damper_min[f] = parse_float(conf, section, "floor$(f)_damper_min")
            obj.damper_max[f] = parse_float(conf, section, "floor$(f)_damper_max")
        end

        # # chiller ramp up and ramp down parameters
        # section = "chiller_params"
        # obj.startup_time = parse_int(conf, section, "startup_time")
        # obj.shutdown_time = parse_int(conf, section, "shutdown_time")
        #
        # # chiller power model
        # section = "chiller_power_params"
        # obj.intercept = parse_float(conf, section, "intercept")
        # obj.linear = parse_float(conf, section, "linear")
        # obj.quad = parse_float(conf, section, "quad")
        # obj.cubic = parse_float(conf, section, "cubic")
        return obj
    end
end

"""
Data type to store optimization model and solver parameters.
"""
mutable struct OptimizationParams
    numstages::Int
    controlwindow::Int
    numwindows::Int
    weight_fan::Float64
    weight_heat::Float64
    weight_cool::Float64
    weight_norm::Float64
    penalty::Float64
    modelflag::Int
    oatpredflag::Int
    loadpredflag::Int
    solverflag::Int
    maxiter::Int
    # cl_baseline::Int
    # cl_startday::Float64
    # cl_numdays::Float64
    # cl_nompcdays::Float64
    # cl_nosolvewindow::Int
    cl_MAwindow::Int
    # cl_rate_supplytemp::Float64
    # cl_minPerSample::Float64
    # mpcMovingBlockImpl::Bool

    # inner constructor
    function OptimizationParams()
        # read config file for optimization and model parameters
        conf = ConfParse("./config_optparams.ini")
        parse_conf!(conf)

        # define new instance
        obj = new()

        ## populate the fields of the instance
        # model params
        obj.numstages = parse_int(conf, "model_params", "numstages")
        obj.controlwindow = parse_int(conf, "model_params", "controlwindow")
        obj.numwindows = obj.numstages % obj.controlwindow == 0 ?
                        round(Int64, obj.numstages / obj.controlwindow) :
                        error("Number of stages not divisible by control window; choose new values")
        obj.weight_fan = parse_float(conf, "model_params", "weight_fan")
        obj.weight_heat = parse_float(conf, "model_params", "weight_heat")
        obj.weight_cool = parse_float(conf, "model_params", "weight_cool")
        obj.weight_norm = parse_float(conf, "model_params", "weight_norm")
        obj.penalty = parse_float(conf, "model_params", "penalty")

        # flags
        obj.modelflag = parse_int(conf, "flags", "modelflag")
        obj.oatpredflag = parse_int(conf, "flags", "oatpredflag")
        obj.loadpredflag = parse_int(conf, "flags", "loadpredflag")

        # solver params
        obj.solverflag = parse_int(conf, "solver_params", "solverflag")
        obj.maxiter = parse_int(conf, "solver_params", "maxiter")

        # # closedloop params
        # obj.cl_baseline = parse_int(conf, "cl_params", "baseline")
        # obj.cl_startday = parse_float(conf, "cl_params", "startday")
        # obj.cl_numdays = parse_float(conf, "cl_params", "numdays")
        # obj.cl_nompcdays = parse_float(conf, "cl_params", "nompcdays")
        # obj.cl_nosolvewindow = parse_int(conf, "cl_params", "nosolvewindow")
        obj.cl_MAwindow = parse_int(conf, "other_params", "MAwindow")
        # obj.cl_rate_supplytemp = parse_float(conf, "cl_params", "rate_supplytemp")
        # obj.cl_minPerSample = parse_float(conf, "cl_params", "minPerSample")
        # obj.mpcMovingBlockImpl = parse_bool(conf, "cl_params", "mpcMovingBlockImpl")

        return obj
    end
end

# """
# Data type to store connection details.
# """
# mutable struct Connection
#     ip::String
#     port::Int64
#
#     # inner constructor
#     function Connection()
#         # read config file for connection settings
#         conf = ConfParse("./config_connection.ini")
#         parse_conf!(conf)
#
#         # define new instance
#         obj = new()
#         obj.ip = ConfParser.retrieve(conf, "basic_settings", "ip")
#         obj.port = parse_int(conf, "basic_settings", "port")
#
#         return obj
#     end
# end

# initialize instances storing the required parameters
p = Params()                    # instance of building-specific parameters
o = OptimizationParams()        # instance of model-and-solver-specific parameters
# conn = Connection()             # instance of server-client connection settings

# Build the initial MPC model in JuMP. Some parameters are initialized
# using default values which are dynamically updated during closed-loop runs

# set nonlinear solver
# solver = IpoptSolver(max_iter = o.maxiter, print_level = 0)
#solver = Ipopt.Optimizer(max_iter = o.maxiter, print_level = 0)

# define initial model
# m = JuMP.Model(solver = solver)
m = JuMP.Model(with_optimizer(Ipopt.Optimizer, max_iter = o.maxiter, print_level = 3))

# map decision stages to control windows in MPC
window_index = Dict(t => round(Int, ceil(t/o.controlwindow)) for t = 1:o.numstages)
global true_outsidetemp = DataFrames.DataFrame()
if  o.oatpredflag == 1
    true_outsidetemp = CSV.read("daily_oat_sample.csv", DataFrame);
end

## list of supervisory setpoints set by MPC (these are sent to Modelica)
# supply-air temperatures at the AHU level
@variable(m, ahusupplytemp[f = 1:p.numfloors, h = 1:o.numwindows],
            lower_bound = p.ahusupplytemp_min, upper_bound = p.ahusupplytemp_max)

# damper positions at the AHU level
@variable(m, ahudamper[f = 1:p.numfloors, h = 1:o.numwindows],
            lower_bound = p.damper_min[f], upper_bound = p.damper_max[f])

# discharge-air temperatures at the zone level
@variable(m, zonedischargetemp[f = 1:p.numfloors, z = 1:p.numzones, h = 1:o.numwindows],
             upper_bound = p.zonedischargetemp_max)

# mass-flow rates at the zone level
@variable(m, zoneflow[f = 1:p.numfloors, z = 1:p.numzones, h = 1:o.numwindows],
             lower_bound = p.zoneflow_min[f, z], upper_bound = p.zoneflow_max[f, z])

# static pressures at the AHU level
# note static pressure is not a true decision variable; it is computed using convex hull info once MPC is solved
@NLparameter(m, ahupressures[f = 1:p.numfloors, t = 1:o.numstages] == 0.0)

## list of  auxiliary optimization variables (these are NOT sent to Modelica)
# mixed-air temperatures at the AHU level
@variable(m, ahumixedtemp[f = 1:p.numfloors, t = 1:o.numstages])

# return-air temperatures at the AHU level
@variable(m, ahureturntemp[f = 1:p.numfloors, t = 1:o.numstages])

# # internal-air temperatures at the AHU level
# @variable(m, ahuinternaltemp[f = 1:p.numfloors, t = 1:o.numstages])

# zone temperatures
@variable(m, zonetemp[f = 1:p.numfloors, z = 1:p.numzones, t = 1:o.numstages])

# slack variable
@variable(m, slack >= 0.0)


## initialize model parameters with garbage values
# Energy price
@NLparameter(m, price == 1.0)

# outside-air temperature
@NLparameter(m, oat[t = 1:o.numstages] == 0.0)

# internal loads
@NLparameter(m, intload[f = 1:p.numfloors, z = 1:p.numzones, t = 1:o.numstages] == 0.0)

# initial zone temperature
@NLparameter(m, zonetemp_init[f = 1:p.numfloors, z = 1:p.numzones] == 0.0)

# default min and max zone temperatures
@NLparameter(m, heatsetpoint[t = 1:o.numstages] == 0.0)
@NLparameter(m, coolsetpoint[t = 1:o.numstages] == 0.0)

## model constraints
include("./zone_temp_constraints.jl")
# # zone temperature dynamic constraints
# expr = Dict{Tuple{Int64, Int64, Int64}, JuMP.NonlinearExpression}()  # initialize an empty expression
# for f in 1:p.numfloors, z in 1:p.numzones, t in 1:o.numstages
#     h = window_index[t]
#     # expression for zone dynamics minus the alpha * (zonetemp[t-1]) term
#     expr[f, z, t]  = @NLexpression(m,
#                     zonetemp[f, z, t] - p.zonetemp_beta[f, z] * zoneflow[f, z, h] * (zonedischargetemp[f, z, h] - zonetemp[f, z, t])
#                     - p.zonetemp_gamma[f, z] * oat[t] - intload[f, z, t])
# end
#
# # zone temperature constraints in stage 1
# @NLconstraint(m, zone_cons_first[f = 1:p.numfloors, z = 1:p.numzones, t = 1:1],
#                 expr[f, z, t] == p.zonetemp_alpha[f, z] * zonetemp_init[f, z])
#
# # zone temperature constraints in other stages
# @NLconstraint(m, zone_cons[f = 1:p.numfloors, z = 1:p.numzones, t = 2:o.numstages],
#                 expr[f, z, t] == p.zonetemp_alpha[f, z] * zonetemp[f, z, t-1])

# return-air temperature constraints (definiton)
@NLconstraint(m, return_cons[f = 1:p.numfloors, t = 1:o.numstages],
                ahureturntemp[f, t] * sum(zoneflow[f, z, window_index[t]] for z in 1:p.numzones) == sum(zoneflow[f, z, window_index[t]] * zonetemp[f, z, t] for z in 1:p.numzones))

# mixed-air temperature constraints (definition)
@NLconstraint(m, mixed_cons[f = 1:p.numfloors, t = 1:o.numstages],
                ahumixedtemp[f, t] == ahudamper[f, window_index[t]] * oat[t] + (1.0 - ahudamper[f, window_index[t]]) * ahureturntemp[f, t])

# comfort bounding constraints
@NLconstraint(m, mincomfort_cons[f = 1:p.numfloors, z = 1:p.numzones, t = 1:o.numstages] ,zonetemp[f, z, t] >= heatsetpoint[t] - slack)
@NLconstraint(m, maxcomfort_cons[f = 1:p.numfloors, z = 1:p.numzones, t = 1:o.numstages], zonetemp[f, z, t] <= coolsetpoint[t] + slack)

# # internal temperature is upper bound of mixed-air temperature
# @constraint(m, intmixed_cons[f = 1:p.numfloors, t = 1:o.numstages], ahuinternaltemp[f, t] >= ahumixedtemp[f, t])
#
# # internal temperature is upper bound of supply-air temperature
# @constraint(m, intsupply_cons[f = 1:p.numfloors, t = 1:o.numstages], ahuinternaltemp[f, t] >= ahusupplytemp[f, window_index[t]])

# discharge temperature is upper bound of supply-air temperatures
@constraint(m, discsup_cons[f = 1:p.numfloors, z = 1:p.numzones, h = 1:o.numwindows], zonedischargetemp[f, z, h] >= ahusupplytemp[f, h])

# deviation between supply-air temp and mixed-air temp
# upper and lower bound for the difference between mixedair temp and supply-air temp
# these parameters are used to control HVAC start/stop
@NLparameter(m, bound[t = 1:o.numstages] == 0.0)
@NLconstraint(m, supmix_upper_cons[f = 1:p.numfloors, t=1:o.numstages], ahusupplytemp[f, window_index[t]] - ahumixedtemp[f, t] <= bound[t])
@NLconstraint(m, supmix_lower_cons[f = 1:p.numfloors, t=1:o.numstages], ahumixedtemp[f, t] - ahusupplytemp[f, window_index[t]] <= bound[t])

# rate of change of supply-air temperature setpoints are bounded for baseline 1 in closed loop
#if o.cl_baseline == 1
    # previously implemented supply-air temperature setpoints
    #@NLparameter(m, current_ahusupplytemp[f = 1:p.numfloors] == 0.0)
    #@NLparameter(m, true_ahusupplytemp[f = 1:p.numfloors] == max(p.ahusupplytemp_min, getvalue(current_ahusupplytemp[f])))
    ##bounds for first-stage
    #@NLconstraint(m, deltasupplytemp_lower_cons[f = 1:p.numfloors],
    #                ahusupplytemp[f, 1] - true_ahusupplytemp[f] >= -1.0 * o.cl_rate_supplytemp)
    #@NLconstraint(m, deltasupplytemp_upper_cons[f = 1:p.numfloors],
    #                ahusupplytemp[f, 1] - true_ahusupplytemp[f] <= 1.0 * o.cl_rate_supplytemp)
#end

# constraining the change between 2 consecutive AHU supply temperature set points to avoid big jumps as consequences of
# calculating for comfort or energy savings
@NLconstraint(m, [f = 1:p.numfloors, h = 1:o.numwindows-1],
            ahusupplytemp[f, h + 1] - ahusupplytemp[f, h] <= p.ahusupplytemp_max_dev)

## Objective cost function
# expression for sum of mass flows at each stage
@NLexpression(m, sum_zoneflows[f = 1:p.numfloors, t = 1:o.numstages], sum(zoneflow[f, z, window_index[t]] for z in 1:p.numzones))

# expression for fan energy (= fan power x sampling interval) consumption
@NLexpression(m, fanenergy[f = 1:p.numfloors, t = 1:o.numstages],
                (p.fan_params[f,1] + p.fan_params[f,2] * sum_zoneflows[f, t] + p.fan_params[f,3] * (sum_zoneflows[f, t])^2 + p.fan_params[f,4] * ahupressures[f, t]))

# expression for chiller capacity (energy) delivered
@NLexpression(m, chillercapacity[f = 1:p.numfloors, t = 1:o.numstages],
                p.specheat * sum_zoneflows[f, t] * (ahumixedtemp[f, t] - ahusupplytemp[f, window_index[t]]))

# expression for VAV-box reheat (energy) consumption
@NLexpression(m, vavcapacity[f = 1:p.numfloors, t = 1:o.numstages],
                p.specheat * sum(zoneflow[f, z, window_index[t]] * (zonedischargetemp[f, z, window_index[t]] - ahusupplytemp[f, window_index[t]]) for z in 1:p.numzones))

# expression for total heating capacity (AHU + VAV) (energy) delivered
@NLexpression(m, heatingcapacity[f = 1:p.numfloors, t = 1:o.numstages],
                vavcapacity[f, t])

# # expression for total chiller capacity per stage
# @NLexpression(m, chillercap_total[t = 1:o.numstages],
#                 sum(chillercapacity[f, t] for f = 1:p.numfloors))
# # expression for total chiller power per stage
# @NLexpression(m, chillerpower[t = 1:o.numstages],
#                 p.intercept + p.linear * chillercap_total[t] + p.quad * chillercap_total[t] ^ 2
#                 + p.cubic * chillercap_total[t] ^ 3)
# set model objetive for different type of models
# for model 1
if o.modelflag == 1
    # Model 1 minimizes HVAC energy capacity + fan energy +  comfort deviation
    @NLobjective(m, Min,
                60.0 * price * sum(o.weight_heat * heatingcapacity[f, t] + o.weight_cool * chillercapacity[f, t] + o.weight_fan  * fanenergy[f, t] for f = 1:p.numfloors, t = 1:o.numstages) + o.penalty * slack^2)
# # model 2 where we additionally optimzie the norms of mass flows
# elseif o.modelflag == 2
#     # L1 norm for mass flows
#     @NLexpression(m, L1, sum(abs(zoneflow[f, z, h])
#                         for f = 1:p.numfloors, z = 1:p.numzones, h = 1:o.numwindows ))
#     # L∞ norm for mass flows
#     @variable(m, L∞)
#     @NLconstraint(m, norminf[f = 1:p.numfloors, z = 1:p.numzones, h = 1:o.numwindows],
#                     L∞ >= abs(zoneflow[f, z, h]))
#     # Model 2 minimizes L1 + L∞ norms for massflow + energy (heater+chiller) + comfort deviation
#     @NLobjective(m, Min, o.weight_norm * (L1 + L∞)
#                         + sum(o.weight_heat * heatingcapacity[f, t]
#                         + o.weight_cool * chillercapacity[f, t]
#                         for f = 1:p.numfloors, t = 1:o.numstages)
#                         + o.penalty * slack^2)
# # model 3 with chiller power
# elseif o.modelflag == 3
#     @NLobjective(m, Min, 60.0 * o.weight_cool * sum(chillerpower[t] for t = 1:o.numstages)
#                         + 60.0 * sum(o.weight_heat * heatingcapacity[f, t] + o.weight_fan  * fanenergy[f, t] for f = 1:p.numfloors, t = 1:o.numstages)
#                         + o.penalty * slack^2)
end
# build the JuMP model without optimizing it
# JuMP.build(m) ---->>>>>> I believe there is no need for this anymore


#################################################################################################
##############  User-defined functions ##########################################################

# Start Julia-side server with given IP and port information
#=
function startserver(ip::String = "127.0.0.1", port::Int64 = 8888)

    # import "socket" module of Python 3 within Julia function using pyimport (and not @pyimport)
    sock_mod = pyimport(:socket)

    # initialize server-side socket object
    socket = sock_mod[:socket]()
    socket[:setsockopt](sock_mod[:SOL_SOCKET], sock_mod[:SO_REUSEADDR], 1)

    # bind socket object to given ip and port
    socket[:bind]((ip, port))
    socket[:listen](10)
    return socket
end
=#

"""
Create new directory for the current MPC run.
"""
function createdir()
    # parent directory
    parent = joinpath("./results")
    # run index
    run = 1
    # check if directory with same name exists
    while isdir(joinpath(parent, "run$run"))
        run += 1
    end
    # create directory with unique name
    dirpath = joinpath(parent, "run$run")
    mkpath(dirpath)
    return dirpath
end

"""
Receive data from client using socket connection.
"""
function getCaseInfo(url, case)
    # GET CASE INFORMATION
    # --------------------
    # Test case name
    case.name = JSON.parse(String(HTTP.get("$url/name").body))
    # Inputs available
    case.inputs = JSON.parse(String(HTTP.get("$url/inputs").body))
    # Measurements available
    case.measurements = JSON.parse(String(HTTP.get("$url/measurements").body))
    # Default simulation step
    case.step_def = JSON.parse(String(HTTP.get("$url/step").body))
    return case
end

function ctrlInitialize(inputs)
    global u = Dict{String, Float64}()
    for ind = 1 : length(inputs)
      if occursin("_u", inputs[ind])
        u[inputs[ind]] = 1e-27
      elseif occursin("_activate", inputs[ind])
        u[inputs[ind]] = 0
      end
    end
    return u
end

"""
Save current data (measurement) into a dataframe.
"""
function dict2df!(df::DataFrames.DataFrame, data::Dict)
    df = DataFrames.DataFrame([typeof(data[k]) for k in keys(data)], [Symbol(k) for k in keys(data)], 1)
    # loop over variable names in data
    for v in keys(data)
        # make sure that value is stored as float even if integer value is sent for a "Double" type sent by client
        if typeof(data[v]) == "Float64"
            # df.v = [values(data[v]) * 1.0] # store corresponding value as float
            df[1, Symbol(v)] = values(data[v]) * 1.0 # store corresponding value as float
        else
            # df.v = [values(data[v])]    # store corresponding value as  integer
            df[1, Symbol(v)] = values(data[v])    # store corresponding value as  integer
        end
    end
    return df
end

"""
Convert data frame to dict, to go from Julia setpoints to JSON u.
"""
function df2dict!(data::Dict{String, Float64}, df::DataFrames.DataFrame)
    # loop over variable names in data
    for v in keys(data)
        data[v] = df[1, Symbol(v)]
    end
    return data
end

"""
Returns the heating and cooling setpoints (comfort bounds) over the MPC
prediction horizon, starting from a given time instant.
"""
function comfortbounds(current_minute::Float64)

    h = zeros(o.numstages)   # initialize lower bounds (heating setpoints)
    c = zeros(o.numstages)   # initialize upper bounds (cooling setpoints)

    for i in 1:o.numstages
        min = current_minute + i # clock time (in minutes) for i-th stage
        hour = ceil(min/60.0)    # clock time (in hour) for i-th stage
        min_of_day = Helper.minute_of_day(min) # minute of day for i-th stage
        day_of_week = Helper.day_of_week(hour) # day of the week for i-th stage

        # heating and cooling setpoints depending on time
        if day_of_week == 1.0  # Sunday
            h[i] = p.zonetemp_min_uocc
            c[i] = p.zonetemp_max_uocc
        elseif 60.0 * 6 <= min_of_day < 60.0 * 20 # occupied periods in weekdays and Saturday
            h[i] = p.zonetemp_min_occ
            c[i] = p.zonetemp_max_occ
        else #unoccupied periods in weekdays and Saturday
            h[i] = p.zonetemp_min_uocc
            c[i] = p.zonetemp_max_uocc
        end
    end

    return h, c
end

"""
Predict ambient temperature over the prediction horizon.
"""
function predictambient(current_temp::Float64, minute_of_day::Float64;
                        unit::String = "Kelvin")
    if o.oatpredflag == 0  # use current temp as prediction over entire horizon
        temps = current_temp * ones(o.numstages)

    elseif o.oatpredflag == 1 # use complete future information
        minute = round(Int, minute_of_day)   # starting row index (integer)

        if minute + o.numstages <= 1440 # 1440 = total number of minutes in a day
            temps = true_outsidetemp[minute:(minute + o.numstages), :temp] # dataframe
            temps = convert(Array, temps)  # convert to Array
        else
            temps = true_outsidetemp[minute] * ones(o.numstages)
        end
    end

    if unit == "Kelvin"
        temps .-= 273.15  # convert current temps to Celsius from Kelvin
    end

    return temps
end

"""
Predict internal loads over the prediction horizon, given the past history.
"""
function predictloads(history::DataFrames.DataFrame)

    # flag for load prediction (Int)
    flag = o.loadpredflag

    # check if we want to use zero loads
    if flag == 0
        loads = zeros(p.numfloors, p.numzones, o.numstages)  # zero loads

    # loads computed using a moving average model
    elseif flag == 1
        if size(history, 1) < o.cl_MAwindow  # not enough history available
            loads = zeros(p.numfloors, p.numzones, o.numstages) # zero loads

        else
            loads = zeros(p.numfloors, p.numzones, o.numstages)  # initialize
            for (f, z) in zip(1:p.numfloors, 1:p.numzones)
                sum_error = 0.0
                alpha = p.zonetemp_alpha[f, z]
                beta = p.zonetemp_beta[f, z]
                gamma = p.zonetemp_gamma[f, z]
                for row in 1:(size(history, 1) - 1)

                    # extract variables of interest
                    temp = history[row, Symbol("floor$(f)_zon$(z)_TRooAir_y")] # ("zonetemp_f$(f)z$z")]
                    flow = history[row, Symbol("floor$(f)_zon$(z)_mSupAir_y")] # ("zoneflow_f$(f)z$z")]
                    dischargetemp = history[row, Symbol("floor$(f)_zon$(z)_TSupAir_y")] # ("zonedischargetemp_f$(f)z$z")]
                    ambient = history[row, Symbol("TOutDryBul_y")] # ("outside_temp")]

                    # predicted temp (from model) for data in row+1 given data in row
                    pred =  alpha * temp +  beta * flow * (dischargetemp - temp) + gamma * ambient
                    # actual observation for data in row+1
                    actual = history[row + 1, Symbol("floor$(f)_zon$(z)_TRooAir_y")] # ("zonetemp_f$(f)z$z")]
                    sum_error += (actual - pred)
                end
                loads[f, z, :] .= sum_error / o.cl_MAwindow  # average of the mispredictions
            end
        end
    end
    return loads
end

"""
Set appropriate setpoints from the MPC model.
"""
function setoverrides!(df::DataFrames.DataFrame;
                        control = "MPC",
                        stage::Int64 = 1,
                        default::Float64 = 1e-27,
                        unit::String = "Kelvin")
    if control == "MPC"
        for f = 1:p.numfloors
                # damper setpoint
                df[1, Symbol("floor$(f)_aHU_con_oveMinOAFra_activate")] = 1
                df[1, Symbol("floor$(f)_aHU_con_oveMinOAFra_u")] = JuMP.value(ahudamper[f, stage])

                # ahu supply temperatures
                df[1, Symbol("floor$(f)_aHU_con_oveTSetSupAir_activate")] = 1
                if unit == "Kelvin"
                    df[1, Symbol("floor$(f)_aHU_con_oveTSetSupAir_u")] = 35 + 273.15
                    # JuMP.value(ahusupplytemp[f, stage]) + 273.15
                else
                    df[1, Symbol("floor$(f)_aHU_con_oveTSetSupAir_u")] = 35
                    # JuMP.value(ahusupplytemp[f, stage])
                end

                # static pressure setpoint
                mflow = JuMP.value(sum_zoneflows[f, 1])
                # if in(Symbol("set_ahupressure_f$(f)"), names(df))
                #     df[1, Symbol("set_ahupressure_f$f")] = staticpressure(mflow)
                # else
                #     insertcols!(df, size(df, 2) + 1, Symbol("set_ahupressure_f$f") => staticpressure(mflow))
                # end
                df[1, Symbol("set_ahupressure_f$f")] = staticpressure(mflow, f)

                ## zone-level setpoints
                for z = 1:p.numzones
                    # zone flows
                    df[1, Symbol("floor$(f)_zon$(z)_oveAirFloRat_activate")] = 1
                    df[1, Symbol("floor$(f)_zon$(z)_oveAirFloRat_u")] = JuMP.value(zoneflow[f, z, stage])/p.zoneflow_max[f, z]

                    df[1, Symbol("floor$(f)_zon$(z)_oveHeaOut_activate")] = 1
                    df[1, Symbol("floor$(f)_zon$(z)_oveHeaOut_u")] = (JuMP.value(zonedischargetemp[f, z, stage]) - JuMP.value(ahusupplytemp[f, stage])) / (p.zonedischargetemp_max - JuMP.value(ahusupplytemp[f, stage]))

                    # discharge temperatures - this is just for data saving purpose
                    # and it comes in Celsius from the MPC algorithm
                    df[1, Symbol("floor$(f)_zon$(z)_oveTSetDisAir_activate")] = 1
                    df[1, Symbol("floor$(f)_zon$(z)_oveTSetDisAir_u")] = JuMP.value(zonedischargetemp[f, z, stage])
                end
        end
    elseif control == "DEFAULT"
        for f = 1:p.numfloors
            # damper setpoint
            df[1, Symbol("floor$(f)_aHU_con_oveMinOAFra_activate")] = 0
            df[1, Symbol("floor$(f)_aHU_con_oveMinOAFra_u")] = default
            # ahu supply temperatures
            df[1, Symbol("floor$(f)_aHU_con_oveTSetSupAir_activate")] = 0
            df[1, Symbol("floor$(f)_aHU_con_oveTSetSupAir_u")] = default

            # static pressure setpoint
            if in(Symbol("set_ahupressure_f$(f)"), names(df))
                df[1, Symbol("set_ahupressure_f$f")] = default
            else
                insertcols!(df, size(df, 2) + 1, Symbol("set_ahupressure_f$f") => default)
            end
            # df[1, Symbol("set_ahupressure_f$f")] = default

            ## zone-level setpoints
            for z = 1:p.numzones
                # zone flows
                df[1, Symbol("floor$(f)_zon$(z)_oveAirFloRat_activate")] = 0
                df[1, Symbol("floor$(f)_zon$(z)_oveAirFloRat_u")] = default

                df[1, Symbol("floor$(f)_zon$(z)_oveHeaOut_activate")] = 0
                df[1, Symbol("floor$(f)_zon$(z)_oveHeaOut_u")] = default

                # discharge temperatures - this is just for data saving purpose
                df[1, Symbol("floor$(f)_zon$(z)_oveTSetDisAir_activate")] = 0
                df[1, Symbol("floor$(f)_zon$(z)_oveTSetDisAir_u")] = default
            end
        end
    else
        nothing  # error message
    end
    return df
end

"""
Copy setpoint values in a target dataframe from a source dataframe.
"""
function setoverrides!(target::DataFrames.DataFrame,
                       source::DataFrames.DataFrame,
                       minute_of_day::Float64;
                       control = "MPC")
    if control == "MPC"
        # filter list of all variable names for setpoints
        # setpoints = filter!(x -> occursin("set_", String(x)), names(source)) # this line is not needed anymore as we store set points in a separate vector
        # copy corresponding values in target dataframe
        #for col in names(source) # setpoints
        #    target[col] = 0.0
        #    target[1, col] = source[1, col]
        #end
        target = source

        # special case: 5:59 am (maximize the flow)
        #if minute_of_day == 6 * 60.0 - 1.0
        #    for f = 1:p.numfloors, z = 1:p.numzones
        #        target[1, Symbol("floor$(f)_zon$(z)_oveAirFloRat_activate")] = 1
        #        target[1, Symbol("floor$(f)_zon$(z)_oveAirFloRat_u")] = p.zoneflow_max[z]/p.zoneflow_max[z]
        #    end
        #end
    else
        nothing # display error message
    end

    return target
end

"""
Update MPC parameters using predicted outside temp, predicted internal loads
and comfort bounds.
"""
function updatemodelparams(df::DataFrames.DataFrame, params::Dict)
    # extract relevant parameters
    h = params["heat_sp"]
    c = params["cool_sp"]
    pred_oat = params["pred_oat"]
    pred_loads = params["pred_loads"]
################################################################################
    JuMP.set_value(price, df[1, Symbol("EnergyPrice")])
################################################################################

    for tInd in 1:o.numstages
      # update outside-air temperature parameters
      JuMP.set_value(oat[tInd], pred_oat[tInd])
      # update heating and cooling setpoints
      JuMP.set_value(heatsetpoint[tInd], h[tInd])
      JuMP.set_value(coolsetpoint[tInd], c[tInd])
      # Tsa - Tma is unconstrained for all stages
      JuMP.set_value(bound[tInd], 1e2)
    end

    # update internal-load parameters
    for fInd = 1:p.numfloors, zInd = 1:p.numzones, tInd = 1:o.numstages
        JuMP.set_value(intload[fInd, zInd, tInd], pred_loads[fInd, zInd, tInd])
    end

    # update initial zone temperature
    for fInd = 1:p.numfloors, zInd = 1:p.numzones
        JuMP.set_value(zonetemp_init[fInd, zInd], df[1, Symbol("floor$(fInd)_zon$(zInd)_TRooAir_y")]) #  "zonetemp_f$(fInd)z$(zInd)")])
    end

    # first set zone flows to correct bounds (if it was currently in state 1)
    for fInd = 1:p.numfloors, zInd = 1:p.numzones, hInd = 1:o.numwindows
        JuMP.set_lower_bound(zoneflow[fInd, zInd, hInd], p.zoneflow_min[fInd, zInd])
        JuMP.set_upper_bound(zoneflow[fInd, zInd, hInd], p.zoneflow_max[fInd, zInd])
    end
end

"""
Solve MPC model.
"""
function solvemodel()
    # message
    println("Solving MPC model ... ")

    # solve mpc
    _, solTime, solAllocatedBytes, garbageCollectorTime, solMemAllocs = @timed JuMP.optimize!(m)
    status = JuMP.termination_status(m)
    objValue = JuMP.objective_value(m)

    # solution info
    solverinfo = Dict("optcost"   => objValue,
                      "status"    => status,
                      "soltime"   => solTime)
    return solverinfo
end

"""
Determine static pressure setpoints using convex hull information.
"""
function staticpressure(mflow::Float64, fInd::Int64)
    # # massflow breakpoints
    # m0, m1, m2, m3, m4, m5 = sum(p.zoneflow_min), 5.81, 16.68, 17.05, 17.61, sum(p.zoneflow_max)
    # # pressure breakpoints
    # p0, p1, p2, p3, p4, p5 = 24.88, 24.88, 121.51, 128.68, 160.88, 160.88
    f = fInd # Index of floor level
    # massflow breakpoints
    m0, m1, m2, m3, m4, m5 = p.massflow_sample_0[f], p.massflow_sample_1[f], p.massflow_sample_2[f], p.massflow_sample_3[f], p.massflow_sample_4[f], p.massflow_sample_5[f]
    # pressure breakpoints
    p0, p1, p2, p3, p4, p5 = p.pressure_sample_0[f], p.pressure_sample_1[f], p.pressure_sample_2[f], p.pressure_sample_3[f], p.pressure_sample_4[f], p.pressure_sample_5[f]

    # piecewise-linear pressure function
    if  m0 <= mflow <= m1
        pressure = p0 + (p1 - p0) * (mflow - m0) / (m1 - m0)
    elseif m1 < mflow <= m2
        pressure = p1 + (p2 - p1) * (mflow - m1) / (m2 - m1)
    elseif m2 < mflow <= m3
        pressure = p2 + (p3 - p2) * (mflow - m2) / (m3 - m2)
    elseif m3 < mflow <= m4
        pressure = p3 + (p4 - p3) * (mflow - m3) / (m4 - m3)
    else
        pressure = p4 + (p5 - p4) * (mflow - m4) / (m5 - m4)
    end
    return pressure
end

"""
Convert all temperature measurements from Kelvin to Celsius.
"""
function kelvintocelsius!(df::DataFrames.DataFrame)
    # this function assumes the measurement data frame includes all that is below and they come in Kelvin
    ## AHU-level measurements
    for f in 1:p.numfloors
        # supply-air temp
        df[1, Symbol("floor$(f)_TSupAir_y")] -= 273.15 # ahusupplytemp_f$f
        # mixed-air temp
        df[1, Symbol("floor$(f)_TMixAir_y")]  -= 273.15 # ahumixedtemp_f$f
        # return temp
        df[1, Symbol("floor$(f)_TRetAir_y")] -= 273.15 # ahureturntemp_f$f

        ## zone-level variables
        for z in 1:p.numzones
            # zone temps
            df[1, Symbol("floor$(f)_zon$(z)_TRooAir_y")] -= 273.15 # zonetemp_f$(f)z$z
            # discharge temps
            df[1, Symbol("floor$(f)_zon$(z)_TSupAir_y")] -= 273.15 # zonedischargetemp_f$(f)z$z
            # zone return temps
            # ????????????????????????? This one does not exist at this time
            # df[1, Symbol("zonereturntemp_f$(f)z$z")] -= 273.15
        end
    end
    # outside-air temp
    df[1, :TOutDryBul_y] -= 273.15 # :outside_temp
    return df
end

"""
Compute relevant time information for the given minute index.
"""
function timeinfo(minuteclock::Float64)
    d = Dict{String, Float64}()
    d["minute"] = minuteclock               # clock time (in minutes) for simulation horizon
    d["second"] = d["minute"] * 60.0        # clock time (in seconds) for simulation horizon
    d["hour"] = ceil(d["minute"] / 60.0)    # clock time (in hours) for simulation horizon
    d["day"] = ceil(d["hour"] / 24.0)       # clock time (in days) for simulation horizon
    d["minute_of_day"] = Helper.minute_of_day(d["minute"])  # minute of the day ∈ {1,2,...., 1440}
    d["hour_of_day"] =  ceil(d["minute_of_day"] / 60.0)     # hour of the day ∈ {1,2, ..24}
    d["day_of_week"] =  Helper.day_of_week(d["hour"])       # day of the week ∈ {1, 2, ..7}
return d
end

"""
Display message during simulation.
"""
function printmessage(sample::Int64, sampling_timer::Int64;
                        data_type = "measurements", control::String = "MPC",
                        optimize::String = "No")

        println()
        println("********************************************************************************")
        if data_type == "measurements"
            println("Measurements: Sample = $sample, Sampling timer = $sampling_timer")
        elseif data_type == "overrides"
            println("Overrides: Sample = $sample, Sampling timer = $sampling_timer, Control = $control, Optimize = $optimize")
        else
            nothing
        end
        println("********************************************************************************")
        println()
end

"""
Method for timeinfo when input is integer.
"""
timeinfo(minuteclock::Int64) = timeinfo(minuteclock * 1.0)

"""
Update table of input data over a rolling horizon.
"""
function updatehistory!(history::DataFrames.DataFrame, current::DataFrames.DataFrame)
    history = vcat(history, current)     # append current measurements at the end of history
    if size(history, 1) > o.cl_MAwindow  # check if number of rows > length of rolling window
        history = history[2:end, :]      # remove first row
    end
    return history
end

"""
Save information for the current sampling period in a .csv file.
"""
function saveresults(dfMeasurements::DataFrames.DataFrame,
                     dfSetpoints::DataFrames.DataFrame,
                     dict::Dict{String, Any},
                     dirpath::String;
                     experiment::String = "closeloop",
                     unit::String = "Kelvin")
    # Extract info
    h = dict["mpcparams"]["heat_sp"]
    c = dict["mpcparams"]["cool_sp"]
    day_of_week = dict["timedata"]["day_of_week"]
    minute_of_day = dict["timedata"]["minute_of_day"]
    hour_of_day = dict["timedata"]["hour_of_day"]
    controller = dict["controller"]
    status = dict["solverinfo"]["status"]
    soltime = dict["solverinfo"]["soltime"]
    load = dict["mpcparams"]["pred_loads"]
    looptime = dict["loopTime"]
    currMPCstage = dict["MPC stage"]

    # Save data
    d = DataFrames.DataFrame()          # dataframe to be saved in csv file
    insertcols!(d, size(d, 2) + 1, :day_of_week => day_of_week)
    # d[1, :day_of_week] = day_of_week       # day of the week
    insertcols!(d, size(d, 2) + 1, :hour_of_day => hour_of_day)
    # d[1, :hour_of_day] = hour_of_day       # hour of the day
    insertcols!(d, size(d, 2) + 1, :minute_of_day => minute_of_day)
    # d[1, :minute_of_day] = minute_of_day   # minute of the day
    insertcols!(d, size(d, 2) + 1, :heatsp => h[1])
    # d[1, :heatsp] = h[1]                   # heating setpoint
    insertcols!(d, size(d, 2) + 1, :coosp => c[1])
    # d[1, :coolsp] = c[1]                   # cooling setpoint
    insertcols!(d, size(d, 2) + 1, :status => status)
    # d[1, :status] = status                 # status of solver
    insertcols!(d, size(d, 2) + 1, :controller => controller)
    # d[1, :controller] = controller         # controller type
    insertcols!(d, size(d, 2) + 1, :MPCstages => o.numstages)
    # d[1, :MPCstages] = o.numstages         # number of stages for MPC model
    insertcols!(d, size(d, 2) + 1, :currMPCstage => currMPCstage)
    # d[1, :currMPCstage] = currMPCstage     # current MPC prediction stage used to advance between MPC optimization periods
    insertcols!(d, size(d, 2) + 1, :soltime => soltime)
    # d[1, :soltime] = soltime               # solution time for MPC if applicable
    insertcols!(d, size(d, 2) + 1, :looptime => looptime)
    # d[1, :looptime] = looptime             # time to execute one single sample loop
    insertcols!(d, size(d, 2) + 1, :penaltyparam => o.penalty)
    # d[1, :penaltyparam] = o.penalty        # penalty parameter
    insertcols!(d, size(d, 2) + 1, :experiment => experiment)
    #d[1, :experiment] = experiment         # type of experiment

    # store slack value
    insertcols!(d, size(d, 2) + 1, :slack => controller == "MPC" ? JuMP.value(slack) : 1e-27)
    # d[1, :slack] = controller == "MPC" ? JuMP.value(slack) : 1e-27

    # store timestamp for openloop experiments
    if experiment == "openloop"
        insertcols!(d, size(d, 2) + 1, :current_minute => dict["current_minute"])
        # d[:current_minute] = dict["current_minute"]
    end

     # concatenate dataframes
    d = hcat(d, deepcopy(dfMeasurements), deepcopy(dfSetpoints))

    # predicted internal loads
    if experiment == "closeloop"
        for f = 1:p.numfloors, z = 1:p.numzones
            name = Symbol("load_f$(f)z$z")
            insertcols!(d, size(d, 2) + 1, name => load[f, z, 1])
            # d[1, name] = load[f, z, 1]
        end
    end

    # store setpoint temperatures
    for f = 1:p.numfloors
        # supply-air temperature setpoint AHU
        name = Symbol("floor$(f)_aHU_con_oveTSetSupAir_u")
        if unit == "Kelvin"
            # insertcols!(d, size(d, 2) + 1, name => dfSetpoints[1, name] - 273.15)
            # d[1, name] = dfSetpoints[1, name] - 273.15 # store as celsius
            d[1, name] = d[1, name] - 273.15 # store as celsius
        # else
            # insertcols!(d, size(d, 2) + 1, name => dfSetpoints[1, name])
            # d[1, name] = dfSetpoints[1, name]  # already in celsius
        end
        #for z = 1:p.numzones
            # discharge-air temperatures at zones
            # these are for saving purposes only, so will be kept as they get calculated, in Celsius
        #    name = Symbol("floor$(f)_zon$(z)_oveTSetDisAir_u")
        #    insertcols!(d, size(d, 2) + 1, name => dfSetpoints[1, name])
            # d[1, name] = dfSetpoints[1, name] # already in celsius
        #end
    end

    # different ways of storing csv file
    if experiment == "closeloop"
        sample = dict["sample"]
        #fpath = joinpath(dirpath, "sample$(sample).csv")
        if sample == 1
            global fpath = joinpath(dirpath, "cl_results.csv")
        end
    else
        sample = 1
        while isfile(joinpath(dirpath, "result_sample$(sample).csv"))
            sample += 1
        end
        fpath = joinpath(dirpath, "result_sample$(sample).csv")
    end

    # store as CSV file
    if sample == 1
        CSV.write(fpath, d)
    else
        CSV.write(fpath, d, append=true)
    end
end


#=



"""
Extract the input loads from dataframe.
"""
function extractloads(df::DataFrames.DataFrame; source::String = "default")

    # default loads
    loads = zeros(p.numfloors, p.numzones, o.numstages)

    if source != "default"
        for (f, z) in zip(1:p.numfloors, 1:p.numzones)
            loads[f, z, :] = df[1, Symbol("load_f$(f)z$z")]
        end
    end
    return loads
end






"""
Check if there is no discomfort over the entire planning horizon in terms of
the slack variable for the MPC model solved for state 1.
"""
function cl_checkslack()

    # optimal slack value in MPC model for state 1
    value = getvalue(slack)
    # check if slack is close to 0.0 (upto floating point accuracy)
    flag = isapprox(value, 0.0; atol = 0.01, rtol = 0)

    return flag
end





"""
Save information for the current sampling period in a .csv file.
"""
function saveresults(df::DataFrames.DataFrame,
                    dict::Dict{String, Any},
                    dirpath::String;
                    experiment::String = "closeloop",
                    unit::String = "Kelvin")
    # Extract info
    h = dict["mpcparams"]["heat_sp"]
    c = dict["mpcparams"]["cool_sp"]
    day_of_week = dict["timedata"]["day_of_week"]
    minute_of_day = dict["timedata"]["minute_of_day"]
    hour_of_day = dict["timedata"]["hour_of_day"]
    controller = dict["controller"]
    status = dict["solverinfo"]["status"]
    soltime = dict["solverinfo"]["soltime"]
    load = dict["mpcparams"]["pred_loads"]

    # Save data
    d = DataFrames.DataFrame()          # dataframe to be saved in csv file
    d[:heatsp] = h[1]                   # heating setpoint
    d[:coolsp] = c[1]                   # cooling setpoint
    d[:day_of_week] = day_of_week       # day of the week
    d[:minute_of_day] = minute_of_day   # minute of the day
    d[:hour_of_day] = hour_of_day       # hour of the day
    d[:status] = status                 # status of solver
    d[:controller] = controller         # controller type
    d[:MPCstages] = o.numstages         # number of stages for MPC model
    d[:soltime] = soltime               # solution time for MPC if applicable
    d[:penaltyparam] = o.penalty        # penalty parameter
    d[:experiment] = experiment         # type of experiment

    # store slack value
    d[:slack] = controller == "MPC" ? getvalue(slack) : 1e-27

    # store timestamp for openloop experiments
    if experiment == "openloop"
        d[:current_minute] = dict["current_minute"]
    end

     # concatenate dataframes
    d = hcat(d, deepcopy(df))

    # predicted internal loads
    if experiment == "closeloop"
        for f = 1:p.numfloors, z = 1:p.numzones
            name = Symbol("load_f$(f)z$z")
            d[name] = load[f, z, 1]
    end

    # store setpoint temperatures
    for f = 1:p.numfloors
        # supply-air setpointd AHU
        name = Symbol("set_ahusupplytemp_f$f")
        if unit == "Kelvin"
            d[1, name] = df[1, name] - 273.15 # store as celsius
        else
            d[1, name] = df[1, name]  # already in celsius
        end

        # discharge-air temperatures at zones
        for z = 1:p.numzones
            var = Symbol("set_zonedischargetemp_f$(f)z$z")
            if unit == "Kelvin"
                d[1, var] = df[1, var] - 273.15 # store as celsius
            else
                d[1, var] = df[1, var] # already in celsius
            end
            end
        end
    end

    # different ways of storing csv file
    if experiment == "closeloop"
        sample = dict["sample"]
        fpath = joinpath(dirpath, "sample$(sample).csv")
    else
        sample = 1
        while isfile(joinpath(dirpath, "result_sample$(sample).csv"))
            sample += 1
        end
        fpath = joinpath(dirpath, "result_sample$(sample).csv")
    end

    # store as CSV file
    CSV.write(fpath, d)
end


"""
Return a dataframe aggregating results from each sampling period.
"""
function combineresults(dirpath::String, numsamples::Int64)

    # import first results file into a dataframe
    # df = CSV.read(joinpath(dirpath, "sample1.csv"), allowmissing = :none)  # julia v0.7+
	df = CSV.readtable(joinpath(dirpath, "sample1.csv"))                     # julia v0.6.2

    # concatenate result from every other sample to this dataframe
    for sample in 2:numsamples
        # temp = CSV.read(joinpath(dirpath, "sample$(sample).csv"), allowmissing = :none)  # julia v0.7+
		temp = CSV.readtable(joinpath(dirpath, "sample$(sample).csv")) # julia v0.6.2
        df  = vcat(df, temp)
    end

    # power variables
    val = 0.92 # val = 0.8
    df[:chiller_p] *= val
    df[:hotpumpr_p] *= val
    df[:pripump_p] *= val
    df[:cooTower_p] *= val

    # save the dataframe to a csv file
    fpath = joinpath(dirpath, "allsamples.csv")
    CSV.write(fpath, df)
end


"""
Return a dataframe aggregating results from each sample
of an open-loop experiment.
"""
function combineresults(dirpath::String;
                        numsamples::Int64=1,
                        experiment::String = "openloop")

    # import first results file into a dataframe
    # df = CSV.read(joinpath(dirpath, "sample1.csv"), allowmissing = :none)  # julia v0.7+

    # check type of experiment
    if experiment == "closeloop"
        combineresults(dirpath, numsamples)  # combine results for closeloop simulation
    # combine results from open loop experiment
    else
        df = CSV.readtable(joinpath(dirpath, "result_sample1.csv"))                     # julia v0.6.2

        # concatenate result from every other sample to this dataframe
        for sample in 2:numsamples
            # temp = CSV.read(joinpath(dirpath, "sample$(sample).csv"), allowmissing = :none)  # julia v0.7+
    		temp = CSV.readtable(joinpath(dirpath, "result_sample$(sample).csv")) # julia v0.6.2
            df  = vcat(df, temp)
        end

        # save the dataframe to a csv file
        fpath = joinpath(dirpath, "allsamples.csv")
        CSV.write(fpath, df)
    end
end

"""
Display measurement data packet (in ordered form) received from client.
"""
function printdata(data::Dict; padding::Int64 = 36)
    for var in keys(data)
        # make sure that value is stored as float even if integer value is sent for a "Double" type sent by client
        if data[var]["type"] == "Double"
            value = data[var]["value"] * 1.0 # store corresponding value as float
        else
            value = data[var]["value"]    # store corresponding value as  integer
        end
        unit = data[var]["unit"]
        vartype = typeof(value)
        @printf("%s %s %s %s \n",
                rpad("variable = $var", padding, " "),
                rpad("value = $value", padding, " "),
                rpad("unit = $unit", padding, " "),
                rpad("type = $vartype", padding, " "))
    end
end


"""
Display override data packet (in ordered form) received from client.
"""
function printdata(data::Array; padding::Int64 = 40)
    var = data[1]
    time = data[end]
    @printf("%s %s \n",
            rpad("variable = $var", padding, " "),
            rpad("time = $time", padding, " "))
end


"""
Display override data packet (in ordered form) and value of override variable, if any.
"""
function printdata(data::Array, df::DataFrames.DataFrame = DataFrames.DataFrame();
                   control::String = "DEFAULT", padding::Int64 = 40)
    var = data[1]  #variable name

    if control == "DEFAULT"
        override = "No"
        value = "N/A"
    elseif control == "MPC"
        override = "Yes"
        value =  df[1, Symbol(var)]
    else
        override = "N/A"
        value = "N/A"
    end

    @printf("%s %s %s \n",
            rpad("variable = $var", padding, " "),
            rpad("override = $override", padding, " "),
            rpad("value = $value", padding, " "))
end


"""
Display data during openloop experiments.
"""
function printdata(dict::Dict, solverdict::Dict; padding::Int = 30)
    println("************************************************************")
    @printf("\n %s %s %s",
            rpad("minute timestamp = $(dict["minute"])", padding, " "),
            rpad("minute of day = $(dict["minute_of_day"])", padding, " "),
            rpad("optim status = $(solverdict["status"])", padding, " "))
end


######################################################################################
#######################################################################################
########## Code for  open loop / Machine Learning experiments #########################
"""
Solve a particular instance (or sample). This is useful for openloop experiments.
It is assumed that the sample is stored as a dataframe. The results are
directly stored as a .csv file.
"""
function solvesample(df::DataFrames.DataFrame, dirpath::String = "./")

    # Name of the inputs expected:
    # zonetemp_f$fz$z
    # load_f$fz$z
    # current_minute
    # outside_temp

    # exract inputs
    current_minute = df[1, :current_minute] # current_minute (float) is in range 1,2,3, , 1440, 1441, ..2880, ...
    outside_temp = df[1, :outside_temp]     # in Celsius

    # computed attributes
    timedata = timeinfo(current_minute)
    minute_of_day = timedata["minute_of_day"]   # minute of the day ∈ (1, …, 1440)
    hour_of_day = timedata["hour_of_day"]       # hour of the day ∈ (1, …, 24)

    # computed MPC attributes
    h, c = comfortbounds(current_minute)
    pred_oat = predictambient(outside_temp, minute_of_day, unit = "Celsius")
    pred_load = extractloads(df, source = "default")

    # dictionary of computed MPC params
    mpc_params = Dict("heat_sp" => h,
                      "cool_sp" => c,
                      "pred_oat" => pred_oat,
                      "pred_loads" => pred_load)

    # update model params
    updatemodelparams(df, mpc_params)

    # solve MPC model
    solverinfo = solvemodel()

    # message
    printdata(timedata, solverinfo)

    # store current setpoint values
    df = setoverrides!(df, control = "MPC", unit = "Celsius")

    # all info
    allinfo = Dict("solverinfo" => solverinfo,
                   "timedata" => timedata,
                   "mpcparams" => mpc_params,
                   "controller" => "MPC",
                   "current_minute" => current_minute)

    # save results
    saveresults(df, allinfo, dirpath, experiment = "openloop", unit = "Celsius")
end
=#
