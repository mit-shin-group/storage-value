using JuMP, Gurobi
include("00_data.jl")

function build_BO(; case_data::CaseDataBO = CaseDataBO())
    # unpack data
    @unpack Δt, p̄, p, x̲, x̄, ℓ, ℓ̄, ȳ, ηc, ηd = case_data;
    K = length(ℓ)
    # build battery operation Model
    BO = Model()
    # add variables
    @variable(BO, xc[1:K] >= 0.)
    @variable(BO, xd[1:K] >= 0.)
    @variable(BO, 0. <= y0 <= ȳ)
    @variable(BO, s[1:K] >= 0.)
    # add constraints
    @constraint(BO, xc .- xd .<= x̄)
    @constraint(BO, xc .- xd .>= x̲)
    @constraint(BO, [k = 1:K], y0 + Δt * sum( ηc * xc[l] - xd[l]/ηd for l = 1:k) <= ȳ)
    @constraint(BO, [k = 1:K-1], y0 + Δt * sum( ηc * xc[l] - xd[l]/ηd for l = 1:k) >= 0)
    @constraint(BO, sum( ηc * xc[l] - xd[l]/ηd for l = 1:K) >= 0)
    # initial soc
    if case_data.y0 != nothing
        fix(y0, case_data.y0; force = true)
    end
    # add objective
    @constraint(BO, s .>= xc .- xd .+ ℓ .- ℓ̄)
    @objective(BO, Min, Δt * sum( p̄ * s[k] + p[k] * (xc[k] - xd[k]) for k = 1:K ))
    return BO
end

function solve_BO(; case_data::CaseDataBO = CaseDataBO())
    BO = build_BO(case_data = case_data)
    set_optimizer(BO, Gurobi.Optimizer)
    optimize!(BO)
    return BO
end

function printsol(model::Model)
    println("Objective value: ", round(objective_value(model), digits = 3))
    println("...")
    println("Optimal decisions:") 
    for var in all_variables(model) 
        println("$(name(var)) = $(round(value(var), digits = 3))")
    end
end

function sol_summary(BO::Model; case_data = CaseDataBO)
    # extract optimal decisions
    xc = value.(BO[:xc])
    xd = value.(BO[:xd])
    s = value.(BO[:s])
    y0 = value.(BO[:y0])
    # compute summary statistics
    # -- energy
    println("Energy charged (MWh): ", round(case_data.Δt * sum(xc), digits = 2))
    println("Energy discharged (MWh): ", round(case_data.Δt * sum(xd), digits = 2))
    println("Energy nonserved (MWh): ", round(case_data.Δt * sum(s), digits = 2))
    println("Initial state-of-charge (MWh): ", round(y0, digits = 2))
    # -- prices
    println("Energy sale (\$): ", round(case_data.Δt * sum(case_data.p .* xd), digits = 2))
    println("Energy purchase (\$): ", round(case_data.Δt * sum(case_data.p .* xc), digits = 2))
    println("Lost load (\$): ", round(case_data.Δt * sum(case_data.p̄ .* s), digits = 2))
    println("Profit (\$): ", -round(objective_value(BO), digits = 2))
    # -- linear relaxation
    println("Complementarity constraint violation (MWh²): ", round( case_data.Δt^2 * sum(xc .* xd) , digits = 2))
    # -- solution time
    println("Solution time (s): ", round(solve_time(BO), digits = 2))
end