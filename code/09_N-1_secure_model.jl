using JuMP, Gurobi
include("00_data.jl")

# lifetime functions
function n̲(n::Int, N::Int)
    return max(1, n - N + 1)
end

function build_JP(; case_data::CaseDataN1 = CaseDataN1())
    # unpack data
    @unpack Nb, Nℓ, l̄0, x̄b0, pb, pℓ, x̲ℓ, x̄ℓ, x̲b, x̄b, p̄, p, ℓ, ηc, ηd, T, Ts, Δt = case_data;
    K = size(case_data.p, 2)
    N = length(pb) 
    # build battery operation Model
    JP = Model()
    # add variables
    # -- planning
    @variable(JP, xb[1:N] >= 0.)
    @variable(JP, xℓ[1:N] >= 0.)
    @variable(JP, x̄[1:N] >= 0.)
    @variable(JP, zb[1:N], Bin)
    @variable(JP, zℓ[1:N], Bin) 
    # -- operational
    @variable(JP, xc[1:N, 1:K] >= 0.)
    @variable(JP, xd[1:N, 1:K] >= 0.)
    @variable(JP, y0[1:N] >= 0.)
    @variable(JP, s[1:N, 1:K] >= 0.)
    # add constraints
    # -- planning
    @constraint(JP, zb .* x̲b .<= xb)
    @constraint(JP, xb .<= zb .* x̄b)
    @constraint(JP, zℓ .* x̲ℓ .<= xℓ)
    @constraint(JP, xℓ .<= zℓ .* x̄ℓ)
    # - max line capacity
    @constraint(JP, [n = 1:N, m = n̲(n, Nℓ) : n], x̄[n] >= xℓ[m])
    @constraint(JP, [i = 1:size(l̄0,1)], x̄ .>= l̄0[i,:])
    # -- operational
    @constraint(JP, [n = 1:N, k = 1:K], xc[n,k] - xd[n,k] <= sum(x̄b0[i,n] for i in 1:size(x̄b0,1)) + sum( xb[i] for i in n̲(n, Nb):n ))
    @constraint(JP, [n = 1:N, k = 1:K], xc[n,k] - xd[n,k] >= -x̄b0[n] - sum( xb[i] for i in n̲(n, Nb):n ))
    @constraint(JP, [n = 1:N], y0[n] <= Ts * (x̄b0[n] + sum( xb[i] for i in n̲(n, Nb):n )))
    @constraint(JP, [n = 1:N, k = 1:K], y0[n] + Δt * sum( ηc * xc[n,l] - xd[n,l]/ηd for l = 1:k) <= Ts * (x̄b0[n] + sum( xb[i] for i in n̲(n, Nb):n )) )
    @constraint(JP, [n = 1:N, k = 1:K-1], y0[n] + Δt * sum( ηc * xc[n,l] - xd[n,l]/ηd for l = 1:k) >= 0.)
    @constraint(JP, [n = 1:N], sum( ηc * xc[n,l] - xd[n,l]/ηd for l = 1:K) >= 0)
    # add objective
    @constraint(JP, [n = 1:N, k=1:K], s[n,k] >= xc[n,k] - xd[n,k] + ℓ[n,k] - sum(l̄0[i,n] for i in 1:size(l̄0,1)) - sum( xℓ[i] for i in n̲(n, Nℓ):n ) + x̄[n])
    @objective(JP, Min, sum( pb[n] * xb[n] + pℓ[n] * xℓ[n] + T[n] * sum( p̄ * s[n,k] + p[n,k] * (xc[n,k] - xd[n,k]) for k = 1:K ) for n in 1:N))
    return JP
end

function solve_JP(; case_data::CaseDataN1 = CaseDataN1())
    JP = build_JP(case_data = case_data)
    set_optimizer(JP, Gurobi.Optimizer)
    optimize!(JP)
    return JP
end

function printsol(model::Model)
    println("Objective value: ", round(objective_value(model), digits = 3))
    println("...")
    println("Optimal decisions:") 
    for var in all_variables(model) 
        println("$(name(var)) = $(round(value(var), digits = 3))")
    end
end