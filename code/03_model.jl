using JuMP, Gurobi, Setfield
include("01_data.jl")
include("02_peak_shaving_potential.jl")

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
        # construct M
        x̄tot_s = compute_x̄tot_s(case_data)
        M̲1 = -maximum(ȳℓ) - 2*x̄["g"]
        M̲2 = -2*maximum(ȳℓ) - 2*x̄["g"] - x̄["b"] - x̄["s"] - x̄tot_s
        M̅1 = compute_M̄1(case_data)
        M̅2 = maximum(ȳℓ) + x̄["b"] + x̄["s"] + x̄tot_s
        # add additional variables and constraints
        @variable(model, zM[n in N, k in K, c in C], Bin)
        @constraint(model, [n in N, k in K, c in C], (1 - zM[n,k,c]) * M̲1 <= yd["ℓ",n,k,c] - xtot["g",n,c])
        @constraint(model, [n in N, k in K, c in C], zM[n,k,c] * M̅1[n,k,c] >= yd["ℓ",n,k,c] - xtot["g",n,c])
        @constraint(model, [n in N, k in K, c in C], sum(ys[r,n,k,c] for r in ["b", "s"]) <= yd["ℓ",n,k,c] - xtot["g", n, c] - (1 - zM[n,k,c])*M̲2)
        @constraint(model, [n in N, k in K, c in C], sum(ys[r,n,k,c] for r in ["b", "s"]) <= zM[n,k,c] * M̅2)
    end
    # objective
    @objective(model, Min, sum( sum( p[r,n] * x[r,n] + c0[r,n] * z[r,n] for r in R) 
    + sum( T[n,c] * sum( sum( ps[r,n,k] * ys[r,n,k,c] for r in R) 
    - sum(pd[r,n,k] * yd[r,n,k,c] for r in D) for k in K) for c in C) 
    for n in N))
    # Return result
    return model
end

function build_model(case_data::CaseDataOps = CaseDataOps())
    # this function requires ["g"] in R and ["ℓ"] in D
    # unpack important data
    @unpack R, D, K, ȳℓ, Δt, ηc, ηd, Ts, ps, pd, market, xtot, y0, load_shedding = case_data
    # start modeling
    model = Model()
    # Decision variables
    @variable(model, ys[r in R, k in K] >= 0)
    @variable(model, yd[r in D, k in K] >= 0)
    if isnothing(y0) & ("s" in R)
        @variable(model, 0 <= y0 <= Ts * xtot["s"])
    end
    # constraints
    # - balance
    @constraint(model, [k in K], sum(ys[r,k] for r in R) == sum(yd[r,k] for r in D))
    # - capacity limit
    @constraint(model, [r in R, k in K], ys[r,k] <= xtot[r])
    @constraint(model, [r in ["ℓ"], k in K], yd[r,k] <= ȳℓ[k])
    if !load_shedding
            fix.(yd["ℓ",:], ȳℓ; force = true)
    end
    if !isempty(setdiff(D, ["ℓ"]))
        @constraint(model, [r in setdiff(D, ["ℓ"]), k in K], yd[r,k] <= xtot[r])
    end
    if "s" in R
        # - state-of-charge bounds
        @constraint(model, [r in ["s"], k in first(K) - 1:last(K)], y0 + Δt * sum(ηc * yd[r,l] - ys[r,l]/ηd for l = first(K) : k; init = 0) <= Ts * xtot[r])
        @constraint(model, [r in ["s"], k in first(K) - 1:last(K)], y0 + Δt * sum(ηc * yd[r,l] - ys[r,l]/ηd for l = first(K) : k; init = 0) >= 0)
        # - state of charge balance
        @constraint(model, [r in ["s"]], sum(ηc * yd[r,k] - ys[r,k]/ηd for k in K) >= 0)
    end
    # - market participation
    if market == no_exports
        @constraint(model, [r in ["g"], k in K], yd[r,k] == 0)
    elseif market == peak_shaving
        if load_shedding
            # construct M
            M̲1 = -xtot["g"]
            M̲2 = -sum(xtot)
            M̅1 = ȳℓ .- xtot["g"]
            M̅2 = sum(xtot[r] for r in ["b", "s"])
            # add additional variables and constraints
            @variable(model, zM[k in K], Bin)
            @constraint(model, [k in K], (1 - zM[k]) * M̲1 <= yd["ℓ",k] - xtot["g"])
            @constraint(model, [k in K], zM[k] * M̅1[k] >= yd["ℓ",k] - xtot["g"])
            @constraint(model, [k in K], sum(ys[r,k] for r in ["b", "s"]) <= yd["ℓ",k] - xtot["g"] - (1 - zM[k])*M̲2)
            @constraint(model, [k in K], sum(ys[r,k] for r in ["b", "s"]) <= zM[k] * M̅2)
        else
            @constraint(model, [k in K], sum( ys[r,k] for r in setdiff(R, ["ℓ"])) <= max( fix_value(yd["ℓ", k]) - xtot["g"], 0))
        end
    end
    # objective
    @objective(model, Min,
    Δt * sum( sum( ps[r,k] * ys[r,k] for r in R) 
    - sum(pd[r,k] * yd[r,k] for r in D) for k in K))
    # Return result
    return model
end

function run_model(case_data::Union{CaseData, CaseDataOps} = CaseData())
    model = build_model(case_data)
    set_optimizer(model, Gurobi.Optimizer)
    optimize!(model)
    return model, case_data
end

function compute_x̄tot_s(case_data::CaseData = CaseData())
    @unpack ȳℓ, Δt, ηc, ηd, Ts = case_data
    # find planning period with maximum demand
    n = argmax(Array(ȳℓ))[1]
    # compute normalized potential
    _, _, power, duration = compute_potential(ηc * ηd, Array(ȳℓ)[n, :], Δt = Δt)
    # denormalize power and duration
    power = power * mean(Array(ȳℓ)[n, :])
    duration = duration * 12
    # compute result
    return max(1, duration/Ts)*power
end

function compute_xtot(x::Dict{Int64, Float64}; case_data::CaseData = CaseData(), r::String = "g")
    @unpack N, C, x0, I, Nr = case_data
    if r in ["b", "s"]
        return Dict((n,c) => sum( x0[r, n, i] for i in I[r]; init = 0) + sum( x[i] for i in n̲(n, Nr[r], N = N) : n ) for n in N, c in C)
    elseif r == "g"
        return Dict((n,c) => sum( x0[r, n, i] for i in I[r]; init = 0) + sum( x[i] for i in n̲(n, Nr[r], N = N) : n ) - c * max(maximum(x0[r, n, i] for i in I[r]; init = 0), maximum(x[i] for i in n̲(n, Nr[r], N = N) : n)) for n in N, c in C)
    end
end

function compute_M̄1(case_data::CaseData = CaseData())
    @unpack ȳℓ, N, K, C = case_data
    xtot = compute_xtot(Dict(n => 0. for n in N), case_data = case_data, r = "g")
    return Dict((n,k,c) => ȳℓ[n, k] - xtot[n,c] for n in N, k in K, c in C)
end