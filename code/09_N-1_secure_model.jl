using JuMP, Gurobi
include("00_data.jl")

# lifetime functions
function n̲(n::Int, N::Int)
    return max(1, n - N + 1)
end

function build_JP(; case_data::CaseDataN1 = CaseDataN1())
    # unpack data
    @unpack Nb, Nℓ, l̄0, x̄b0, pb, pℓ, x̲ℓ, x̄ℓ, x̲b, x̄b, p̄, p, ℓ, ηc, ηd, T, Ts, Δt = case_data;
    K = size(p, 2)
    N = length(pb) 
    C = size(T, 2)
    # C = 1
    # build battery operation Model
    JP = Model()
    # add variables
    # -- planning
    @variable(JP, xb[1:N] >= 0.)
    @variable(JP, xℓ[1:N] >= 0.)
    @variable(JP, x̄[1:N, 1:C] >= 0.)
    @variable(JP, zb[1:N], Bin)
    @variable(JP, zℓ[1:N], Bin) 
    # -- operational
    @variable(JP, xc[1:N, 1:K, 1:C] >= 0.)
    @variable(JP, xd[1:N, 1:K, 1:C] >= 0.)
    @variable(JP, y0[1:N, 1:C] >= 0.)
    @variable(JP, 0 <= s[1:N, 1:K, 1:C])
    # add constraints
    # -- planning
    @constraint(JP, zb .* x̲b .<= xb)
    @constraint(JP, xb .<= zb .* x̄b)
    @constraint(JP, zℓ .* x̲ℓ .<= xℓ)
    @constraint(JP, xℓ .<= zℓ .* x̄ℓ)
    # - max line capacity
    @constraint(JP, [n = 1:N, m = n̲(n, Nℓ) : n, c = 1:C], x̄[n,c] >= (c-1)*xℓ[m])
    @constraint(JP, [i = 1:size(l̄0,1), c = 1:C], x̄[:,c] .>= (c-1)*l̄0[i,:])
    # -- operational
    # - max charging power
    @constraint(JP, [n = 1:N, k = 1:K, c = 1:C], xc[n,k,c] - xd[n,k,c] <= sum(x̄b0[i,n] for i in eachindex(x̄b0[:,1])) + sum( xb[i] for i in n̲(n, Nb):n ))
    # - max discharing power
    @constraint(JP, [n = 1:N, k = 1:K, c = 1:C], xc[n,k,c] - xd[n,k,c] >= -x̄b0[n] - sum( xb[i] for i in n̲(n, Nb):n ))
    # - max initial soc
    @constraint(JP, [n = 1:N, c = 1:C], y0[n,c] <= Ts * (x̄b0[n] + sum( xb[i] for i in n̲(n, Nb):n )))
    # - upper bound on soc
    @constraint(JP, [n = 1:N, k = 1:K, c = 1:C], y0[n,c] + Δt * sum( ηc * xc[n,l,c] - xd[n,l,c]/ηd for l = 1:k) <= Ts * (x̄b0[n] + sum( xb[i] for i in n̲(n, Nb):n )) )
    # - lower bound on soc
    @constraint(JP, [n = 1:N, k = 1:K-1, c = 1:C], y0[n,c] + Δt * sum( ηc * xc[n,l,c] - xd[n,l,c]/ηd for l = 1:k) >= 0.)
    # - energy balance
    @constraint(JP, [n = 1:N, c = 1:C], sum( ηc * xc[n,l,c] - xd[n,l,c]/ηd for l = 1:K) >= 0)
    # add objective
    # - slack variable
    @constraint(JP, [n = 1:N, k=1:K, c=1:C], s[n,k,c] >= xc[n,k,c] - xd[n,k,c] + ℓ[n,k] - sum(l̄0[i,n] for i in eachindex(l̄0[:,1])) - sum( xℓ[i] for i in n̲(n, Nℓ):n ) + x̄[n,c])
    # - actual objective
    @objective(JP, Min, sum( pb[n] * xb[n] + pℓ[n] * xℓ[n] + sum( T[n,c] * sum( p̄ * s[n,k,c] + p[n,k] * (xc[n,k,c] - xd[n,k,c]) for k = 1:K ) for c in 1:C) for n in 1:N))
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

function analyze_JP(JP::Model, case_data::CaseDataN1)
    # Cumulative results
    println("Cumulative results")
    println("Objective (million \$): ", round(objective_value(JP)/1e6, digits = 3))
    println("Battery capital cost (million \$): ", round(sum(case_data.pb .* value.(JP[:xb]))/1e6, digits = 3))
    println("Battery investment (MW): ", sum(value.(JP[:xb])))
    println("Subsea investment (MW): ", sum(value.(JP[:xℓ])))
    println("Subsea capital cost (million \$): ", round(sum(case_data.pℓ .* value.(JP[:xℓ]))/1e6, digits = 3))
    println("Lost load (MWh): ", sum(sum(case_data.T[:,c]' * value.(JP[:s][:,:,c]) for c in eachindex(case_data.T[1,:]))))
    println("Energy charged (MWh): ", sum(sum(case_data.T[:,c]' * value.(JP[:xc][:,:,c]) for c in eachindex(case_data.T[1,:]))))
    println("Energy discharged (MWh): ", sum(sum(case_data.T[:,c]' * value.(JP[:xd][:,:,c]) for c in eachindex(case_data.T[1,:]))))
    # 2050 peak results
    println("Snapshot 2050")
    N = length(case_data.pb) 
    println("Peak load (MW): ", maximum(case_data.ℓ[end, :]))
    println("Subsea (MW): ", case_data.l̄0[end] + value(sum( JP[:xℓ][i] for i in n̲(N, case_data.Nℓ):N )))
    println("Battery (MW): ", case_data.x̄b0[end] + value(sum( JP[:xb][i] for i in n̲(N, case_data.Nb):N )))
end

