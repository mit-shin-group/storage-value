using JuMP, Gurobi
include("00_data.jl")

function build_BO(; case_data::CaseData = CaseData())
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
    # add objective
    @constraint(BO, s .>= xc .- xd .+ ℓ .- ℓ̄)
    @objective(BO, Min, Δt * sum( p̄ * s[k] + p[k] * (xc[k] - xd[k]) for k = 1:K ))
    return BO
end

function solve_BO(; case_data::CaseData = CaseData())
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