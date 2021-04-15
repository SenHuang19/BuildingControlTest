# zone temperature dynamic constraints
expr = Dict{Tuple{Int64, Int64, Int64}, JuMP.NonlinearExpression}()  # initialize an empty expression
for f in 1:p.numfloors, z in 1:p.numzones, t in 1:o.numstages
    h = window_index[t]
    # expression for zone dynamics minus the alpha * (zonetemp[t-1]) term
    expr[f, z, t]  = @NLexpression(m,
                    zonetemp[f, z, t] - p.zonetemp_beta[f, z] * zoneflow[f, z, h] * (zonedischargetemp[f, z, h] - zonetemp[f, z, t])
                    - p.zonetemp_gamma[f, z] * oat[t] - intload[f, z, t])
end

# zone temperature constraints in stage 1
@NLconstraint(m, zone_cons_first[f = 1:p.numfloors, z = 1:p.numzones, t = 1:1],
                expr[f, z, t] == p.zonetemp_alpha[f, z] * zonetemp_init[f, z])

# zone temperature constraints in other stages
@NLconstraint(m, zone_cons[f = 1:p.numfloors, z = 1:p.numzones, t = 2:o.numstages],
                expr[f, z, t] == p.zonetemp_alpha[f, z] * zonetemp[f, z, t-1])
