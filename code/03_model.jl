using JuMP, Gurobi, Setfield
include("01_data.jl")
include("02_peak_shaving_potential.jl")

function build_model(case_data::CaseDataPlan; env::Gurobi.Env = Gurobi.Env())
    # this function requires ["g"] in R and ["ℓ"] in D
    # unpack important data
    @unpack R, D, N, K, J, C, x̲, x̄, x0, I, Nr, ȳℓ, Δt, ηc, ηd, Ts, p, ps, pd, c0, T, market, Cs, load_shedding = case_data
    # set Gurobi environment
    model = Model(() -> Gurobi.Optimizer(env))
    # Decision variables
    # - investment decisions
    @variable(model, x[r in R, n in N] >= 0)
    @variable(model, xtot[r in R, n in N, c in C] >= 0)
    @variable(model, xmax[n in N] >= 0)
    @variable(model, z[r in R, n in N], Bin)
    # - operating decisions
    if isnothing(J)
        @variable(model, ys[r in R, n in N, k in K, c in C] >= 0)
        @variable(model, yd[r in D, n in N, k in K, c in C] >= 0)
    else
        @variable(model, ys[r in R, n in N, j in J, k in K, c in C] >= 0)
        @variable(model, yd[r in D, n in N, j in J, k in K, c in C] >= 0)
    end
    
    # constraints
    # - limited investment choice
    @constraint(model, [r in R, n in N], x[r,n] <= x̄[r] * z[r,n])
    @constraint(model, [r in R, n in N], x[r,n] >= x̲[r] * z[r,n])
    # - total capacity at the beginning of planning period N, backup and storage capacity is always in base case
    if !isempty(setdiff(R, ["g"]))
        @constraint(model, [r in setdiff(R, ["g"]), n in N, c in [0]], xtot[r,n,c] == sum(x0[r,n,i] for i in I[r]) + sum(x[r,i] for i in n̲(n, Nr[r], N = N) : n))
    end
    @constraint(model, [r in ["g"], n in N, c in C], xtot[r,n,c] == sum(x0[r, n, i] for i in I[r]) + sum(x[r,i] for i in n̲(n, Nr[r], N = N): n) - c*xmax[n])
    @constraint(model, [r in ["g"], n in N, i in n̲(n, Nr[r], N = N):n], xmax[n] >= x[r, i])
    @constraint(model, [r in ["g"], n in N, i in I[r]], xmax[n] >= x0[r, n, i])
    # -- operational decisions
    if "s" in R
        # - initial state of charge 
        @variable(model, y0[n in N] >= 0)
        @constraint(model, [n in N], y0[n] <= Ts * xtot["s", n, 0])
    end
    if isnothing(J)
        # - balance
        @constraint(model, [n in N, k in K, c in C], sum(ys[r,n,k,c] for r in R) == sum(yd[r,n,k,c] for r in D))
        # - capacity limit
        # -- supply
        @constraint(model, [r in ["g"], n in N, k in K, c in C], ys[r,n,k,c] <= xtot[r,n,c])
        if !isempty(setdiff(R, ["g"]))
            @constraint(model, [r in setdiff(R, ["g"]), n in N, k in K, c in C], ys[r,n,k,c] <= xtot[r,n,0])
        end
        # -- demand
        if load_shedding
            @constraint(model, [r in ["ℓ"], n in N, k in K, c in C], yd[r,n,k,c] <= ȳℓ[n,k])
        else
            for c in C
                fix.(yd["ℓ",:,:,c], ȳℓ; force = true)
            end
        end
        if "g" in D
            @constraint(model, [r in ["g"], n in N, k in K, c in C], yd[r,n,k,c] <= xtot[r,n,c])
        end
        if !isempty(setdiff(D, ["ℓ", "g"]))
            @constraint(model, [r in setdiff(D, ["ℓ"]), n in N, k in K, c in C], yd[r,n,k,c] <= xtot[r,n,0])
        end
        # - storage
        if "s" in R
            # - evolving state of charge
            @variable(model, ysoc[n in N, k in K, c in C] >= 0)
            @constraint(model, [n in N, c in C], ysoc[n, :, c] .<= Ts * xtot["s", n, 0])
            # - state-of-charge evolution
            @constraint(model, [n in N, c in C], ysoc[n,1,c] == y0[n] + Δt * (ηc * yd["s", n, 1, c] - ys["s", n, 1, c] / ηd)) 
            @constraint(model, [n in N, k in K[2:end], c in C], ysoc[n,k,c] == ysoc[n,k-1,c] + Δt * (ηc * yd["s", n, k, c] - ys["s", n, k, c] / ηd))
            # - state of charge balance
            @constraint(model, [n in N, c in C], ysoc[n, end, c] >= y0[n])
            # - discharge limit
            if !isnothing(Cs)
                @constraint(model, [n in N, c in C], Δt * sum(sum(T[n,c] for c in C) * ys["s",n,k,c] for k in K)/ηd <= Cs * Ts * xtot["s", n, 0])
            end
        end
        # - market participation
        if market == no_exports
            @constraint(model, [r in ["g"], n in N, k in K, c in C], yd[r,n,k,c] == 0)
        elseif market == peak_shaving
            # construct M -- (TODO: update constants)
            x̄tot_s = compute_x̄tot_s(case_data)
            M̲1 = -maximum(ȳℓ) - 2*x̄["g"]
            M̲2 = -2*maximum(ȳℓ) - 2*x̄["g"] - x̄["b"] - x̄["s"] - x̄tot_s
            M̅1 = compute_M̄1(case_data)
            M̅2 = maximum(ȳℓ) + x̄["b"] + x̄["s"] + x̄tot_s
            # add additional variables and constraints
            @variable(model, zM[n in N, k in K, c in C], Bin)
            @constraint(model, [n in N, k in K, c in C], (1 - zM[n,k,c]) * M̲1 <= yd["ℓ",n,k,c] - xtot["g",n,c])
            @constraint(model, [n in N, k in K, c in C], zM[n,k,c] * M̅1[n,k,c] >= yd["ℓ",n,k,c] - xtot["g",n,c])
            @constraint(model, [n in N, k in K, c in C], sum(ys[r,n,k,c] for r in setdiff(R, ["g"]); init = 0) <= yd["ℓ",n,k,c] - xtot["g", n, c] - (1 - zM[n,k,c])*M̲2)
            @constraint(model, [n in N, k in K, c in C], sum(ys[r,n,k,c] for r in setdiff(R, ["g"]); init = 0) <= zM[n,k,c] * M̅2)
        end
    else
        # - balance
        @constraint(model, [n in N, j in J, k in K, c in C], sum(ys[r,n,j,k,c] for r in R) == sum(yd[r,n,j,k,c] for r in D))
        # - capacity limit
        # -- supply
        @constraint(model, [r in ["g"], n in N, j in J, k in K, c in C], ys[r,n,j,k,c] <= xtot[r,n,c])
        if !isempty(setdiff(R, ["g"]))
            @constraint(model, [r in setdiff(R, ["g"]), n in N, j in J, k in K, c in C], ys[r,n,j,k,c] <= xtot[r,n,0])
        end
        # -- demand
        if load_shedding
            @constraint(model, [r in ["ℓ"], n in N, j in J, k in K, c in C], yd[r,n,j,k,c] <= ȳℓ[n,j,k])
        else
            for c in C
                fix.(yd["ℓ",:,:,:,c], ȳℓ; force = true)
            end
        end
        if "g" in D
            @constraint(model, [r in ["g"], n in N, j in J, k in K, c in C], yd[r,n,j,k,c] <= xtot[r,n,c])
        end
        if !isempty(setdiff(D, ["ℓ", "g"]))
            @constraint(model, [r in setdiff(D, ["ℓ"]), n in N, j in J, k in K, c in C], yd[r,n,j,k,c] <= xtot[r,n,0])
        end
        # - storage
        if "s" in R
            # - evolving state of charge
            @variable(model, ysoc[n in N, j in J, k in K, c in C] >= 0)
            @constraint(model, [n in N, c in C], ysoc[n, :, :, c] .<= Ts * xtot["s", n, 0])
            # - state-of-charge evolution
            @constraint(model, [n in N, j in J, c in C], ysoc[n,j,1,c] == y0[n] + Δt * (ηc * yd["s", n, j, 1, c] - ys["s", n, j, 1, c] / ηd)) 
            @constraint(model, [n in N, j in J, k in K[2:end], c in C], ysoc[n,j,k,c] == ysoc[n,j,k-1,c] + Δt * (ηc * yd["s", n, j, k, c] - ys["s", n, j, k, c] / ηd))
            # - state of charge balance
            @constraint(model, [n in N, j in J, c in C], ysoc[n, j, end, c] == y0[n])
            # - discharge limit
            if !isnothing(Cs)
                @constraint(model, [n in N, c in C], Δt * sum( sum(T[n,j,c] for c in C) * ys["s",n,j,k,c] for k in K for j in J)/ηd <= Cs * Ts * xtot["s", n, 0])
            end
        end
        # - market participation
        if market == no_exports
            @constraint(model, [r in ["g"], n in N, j in J, k in K, c in C], yd[r,n,j,k,c] == 0)
        elseif market == peak_shaving
            # construct M
            # x̄tot_s = compute_x̄tot_s(case_data)
            M̲1 = -maximum(ȳℓ) - 2*x̄["g"]
            M̲2 = -maximum(ȳℓ) .- 2*x̄["g"] .- ȳℓ
            M̅1 = compute_M̄1(case_data)
            M̅2 = ȳℓ
            # add additional variables and constraints
            @variable(model, zM[n in N, j in J, k in K, c in C], Bin)
            @constraint(model, [n in N, j in J, k in K, c in C], (1 - zM[n,j,k,c]) * M̲1 <= yd["ℓ",n,j,k,c] - xtot["g",n,c])
            @constraint(model, [n in N, j in J, k in K, c in C], zM[n,j,k,c] * M̅1[n,j,k,c] >= yd["ℓ",n,j,k,c] - xtot["g",n,c])
            @constraint(model, [n in N, j in J, k in K, c in C], sum(ys[r,n,j,k,c] for r in setdiff(R, ["g"]); init = 0) <= yd["ℓ",n,j,k,c] - xtot["g", n, c] - (1 - zM[n,j,k,c])*M̲2[n,j,k])
            @constraint(model, [n in N, j in J, k in K, c in C], sum(ys[r,n,j,k,c] for r in setdiff(R, ["g"]); init = 0) <= zM[n,j,k,c] * M̅2[n,j,k])
        end
    end

    # objective
    if isnothing(J)
        @objective(model, Min, sum( sum( p[r,n] * x[r,n] + c0[r,n] * z[r,n] for r in R) 
        + sum( T[n,c] * sum( sum( ps[r,n,k] * ys[r,n,k,c] for r in R) 
        - sum(pd[r,n,k] * yd[r,n,k,c] for r in D) for k in K) for c in C) 
        for n in N))
    else
        @objective(model, Min, sum( sum( p[r,n] * x[r,n] + c0[r,n] * z[r,n] for r in R) 
        + sum( T[n,j,c] * sum( sum( ps[r,n,j,k] * ys[r,n,j,k,c] for r in R) 
        - sum(pd[r,n,j,k] * yd[r,n,j,k,c] for r in D) for k in K) for j in J for c in C) 
        for n in N))
    end
    # Return result
    return model
end

function build_model(case_data::CaseDataOps; env::Gurobi.Env = Gurobi.Env())
    # this function requires ["g"] in R and ["ℓ"] in D
    # unpack important data
    @unpack R, D, K, ȳℓ, Δt, ηc, ηd, Ts, ps, pd, market, xtot, y0, load_shedding, Cs = case_data
    model = Model(() -> Gurobi.Optimizer(env))
    # Decision variables
    @variable(model, ys[r in R, k in K] >= 0)
    @variable(model, yd[r in D, k in K] >= 0)
    if isnothing(y0) & ("s" in R)
        @variable(model, 0 <= y0 <= 1)
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
        @variable(model, ysoc[k in K] >= 0) # state of charge
        # - state-of-charge evolution
        @constraint(model, ysoc[1] == y0 * Ts * xtot["s"] + Δt * (ηc * yd["s", 1] - ys["s", 1] / ηd)) 
        @constraint(model, [k in K[2:end]], ysoc[k] == ysoc[k-1] + Δt * (ηc * yd["s", k] - ys["s", k] / ηd))
        # - state-of-charge bounds
        @constraint(model, ysoc .<= Ts * xtot["s"])
        # - state of charge balance
        @constraint(model, ysoc[end] >= y0 * Ts * xtot["s"])
        # - discharge limit
        if !isnothing(Cs)
            @constraint(model, Δt * sum(ys["s",k] for k in K)/ηd <= Cs * Ts * xtot["s"])
        end
    end
    # - market participation
    if (market == no_exports) & ("g" in R)
        @constraint(model, [r in ["g"], k in K], yd[r,k] == 0.)
    elseif market == peak_shaving
        if load_shedding
            # construct M (safe to assume that "g" is in R, otherwise there is no use for peak shaving)
            M̲1 = -xtot["g"]
            M̲2 = -sum(xtot)
            M̅1 = ȳℓ .- xtot["g"]
            M̅2 = sum(xtot[r] for r in setdiff(R, ["g"]); init = 0)
            # add additional variables and constraints
            @variable(model, zM[k in K], Bin)
            @constraint(model, [k in K], (1 - zM[k]) * M̲1 <= yd["ℓ",k] - xtot["g"])
            @constraint(model, [k in K], zM[k] * M̅1[k] >= yd["ℓ",k] - xtot["g"])
            @constraint(model, [k in K], sum(ys[r,k] for r in setdiff(R, ["g"]); init = 0) <= yd["ℓ",k] - xtot["g"] - (1 - zM[k])*M̲2)
            @constraint(model, [k in K], sum(ys[r,k] for r in setdiff(R, ["g"]); init = 0) <= zM[k] * M̅2)
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

function run_model(case_data::Union{CaseDataPlan, CaseDataOps}; env::Gurobi.Env = Gurobi.Env())
    @time model = build_model(case_data, env = env)
    if case_data.grb_silent
        set_silent(model)
        set_optimizer_attribute(model, "OutputFlag", 0)
    end
    set_optimizer_attribute(model, "MIPGap", case_data.grb_mipgap)
    if !isnothing(case_data.grb_timelimit)
        set_optimizer_attribute(model, "TimeLimit", case_data.grb_timelimit)
    end
    # set_optimizer(model, Gurobi.Optimizer)
    @time optimize!(model)
    return model, case_data
end

function compute_x̄tot_s(case_data::CaseDataPlan)
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

function compute_xtot(x::Dict{Int64, Float64}, case_data::CaseDataPlan; r::String = "g")
    @unpack N, C, x0, I, Nr = case_data
    if r in ["b", "s"]
        return Dict((n,c) => sum( x0[r, n, i] for i in I[r]; init = 0) + sum( x[i] for i in n̲(n, Nr[r], N = N) : n ) for n in N, c in C)
    elseif r == "g"
        return Dict((n,c) => sum( x0[r, n, i] for i in I[r]; init = 0) + sum( x[i] for i in n̲(n, Nr[r], N = N) : n ) - c * max(maximum(x0[r, n, i] for i in I[r]; init = 0), maximum(x[i] for i in n̲(n, Nr[r], N = N) : n)) for n in N, c in C)
    end
end

function compute_M̄1(case_data::CaseDataPlan)
    @unpack ȳℓ, N, J, K, C = case_data
    xtot = compute_xtot(Dict(n => 0. for n in N), case_data, r = "g")
    if isnothing(J)
        return Containers.@container([n in N, k in K, c in C], ȳℓ[n, k] - xtot[n,c])
    else
        return Containers.@container([n in N, j in J, k in K, c in C], ȳℓ[n, j, k] - xtot[n,c])
    end
end 