using JuMP, Gurobi, Setfield
include("01_data.jl")

function build_model(case_data::CaseData = CaseData())
    # this function requires ["g"] in R and ["ℓ"] in D
    # unpack important data
    @unpack R, D, N, K, C, x̲, x̄, x0, I, Nr, ȳℓ, Δt, ηc, ηd, Ts, p, ps, pd, c0, T, market = case_data
    # start modeling
    model = Model()
    # Decision variables
    @variable(model, x[r in R, n in N] >= 0)
    @variable(model, xtot[r in R, n in N, c in C] >= 0)
    @variable(model, xmax[n in N] >= 0)
    @variable(model, ys[r in R, n in N, k in K, c in C] >= 0)
    @variable(model, yd[r in D, n in N, k in K, c in C] >= 0)
    @variable(model, y0[n in N] >= 0)
    @variable(model, z[r in R, n in N], Bin)
    # constraints
    # - limited investment choice
    @constraint(model, [r in R, n in N], x[r,n] <= x̄[r] * z[r,n])
    @constraint(model, [r in R, n in N], x[r,n] >= x̲[r] * z[r,n])
    # - total capacity at the beginning of planning period N
    if !isempty(setdiff(R, ["g"]))
        @constraint(model, [r in setdiff(R, ["g"]), n in N, c in C], xtot[r,n,c] == sum(x0[r,n,i] for i in I[r]) + sum(x[r,i] for i in n̲(n, Nr[r], N = N) : n))
    end
    @constraint(model, [r in ["g"], n in N, c in C], xtot[r,n,c] == sum(x0[r, n, i] for i in I[r]) + sum(x[r,i] for i in n̲(n, Nr[r], N = N): n) - c*xmax[n])
    @constraint(model, [r in ["g"], n in N, i in n̲(n, Nr[r], N = N):n], xmax[n] >= x[r, i])
    @constraint(model, [r in ["g"], n in N, i in I[r]], xmax[n] >= x0[r, n, i])
    # - balance
    @constraint(model, [n in N, k in K, c in C], sum(ys[r,n,k,c] for r in R) == sum(yd[r,n,k,c] for r in D))
    # - capacity limit
    @constraint(model, [r in R, n in N, k in K, c in C], ys[r,n,k,c] <= xtot[r,n,c])
    @constraint(model, [r in ["ℓ"], n in N, k in K, c in C], yd[r,n,k,c] <= ȳℓ[n,k])
    if !isempty(setdiff(D, ["ℓ"]))
        @constraint(model, [r in setdiff(D, ["ℓ"]), n in N, k in K, c in C], yd[r,n,k,c] <= xtot[r,n,c])
    end
    if "s" in R
        # - state-of-charge bounds
        @constraint(model, [r in ["s"], n in N, k in first(K) - 1:last(K), c in C], y0[n] + Δt * sum(ηc * yd[r,n,l,c] - ys[r,n,l,c]/ηd for l = first(K) : k; init = 0) <= Ts * xtot[r,n,c])
        @constraint(model, [r in ["s"], n in N, k in first(K) - 1:last(K), c in C], y0[n] + Δt * sum(ηc * yd[r,n,l,c] - ys[r,n,l,c]/ηd for l = first(K) : k; init = 0) >= 0)
        # - state of charge balance
        @constraint(model, [r in ["s"], n in N, c in C], sum(ηc * yd[r,n,k,c] - ys[r,n,k,c]/ηd for k in K) >= 0)
    end
    # - market participation
    if market == no_exports
        @constraint(model, [r in ["g"], n in N, k in K, c in C], yd[r,n,k,c] == 0)
    elseif market == peak_shaving
        # Continue here 
    end
    # objective
    @objective(model, Min, sum( sum( p[r,n] * x[r,n] + c0[r,n] * z[r,n] for r in R) 
    + sum( T[n,c] * sum( sum( ps[r,n,k] * ys[r,n,k,c] for r in R) 
    - sum(pd[r,n,k] * yd[r,n,k,c] for r in D) for k in K) for c in C) 
    for n in N))
    # Return result
    return model
end

function run_model(case_data::CaseData = CaseData())
    model = build_model(case_data)
    set_optimizer(model, Gurobi.Optimizer)
    optimize!(model)
    return model
end

function M̲(case_data::CaseData = CaseData())
    # copy case data setting market to 
    model = run_model(case_data)
end