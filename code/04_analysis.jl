using JuMP, DataFrames, OffsetArrays, JLD2

include("01_data.jl")

function save_planning_results(model_data::Tuple{Model, CaseDataPlan})
    # unpack model data
    model = model_data[1]
    case_data = model_data[2]
    # create dict with model vars
    model_results = Dict(
        "x" => value.(model[:x]),
        "xmax" => value.(model[:xmax]),
        "xtot" => value.(model[:xtot]),
        "ys" => value.(model[:ys]),
        "yd" => value.(model[:yd]),
        "z" => value.(model[:z]),
        "y0" => "s" in case_data.R ? value.(model[:y0]) : 0.,
        "ysoc" => "s" in case_data.R ? value.(model[:ysoc]) : 0.,
        "objective_value" => objective_value(model),
        "solve_time" => solve_time(model),
        "relative_gap" => Bool(MOI.get(model, Gurobi.ModelAttribute("IsMIP"))) ? relative_gap(model) : 0.,
    )
    # save model data and case_data to jld
    filename = "results/planning/" * string(length(case_data.K)) * string(case_data.market) * string(Int(case_data.Cs)) * ".jld"
    @save filename model_results case_data
end

function print_planning_results(result_file::String)
    planning_results = JLD2.load(result_file)
    case_data = planning_results["case_data"]
    model_results = planning_results["model_results"]
    # --- Parameters
    # max. battery cycles per year
    println(case_data.Cs)
    # value of lost load in 2025
    println(mean(case_data.pd["ℓ", 2025, :]))
    # load shedding
    println(case_data.load_shedding)
    # time horizon
    println(length(case_data.K))
    # contingency probability
    println(100*mean(case_data.T[:,1]))
    # base case probability
    println(100*mean(case_data.T[:,0]))
    # available resources
    println(case_data.R)
    # market participation
    println(case_data.market)
    # discount rate
    println(case_data.r)
    # --- Model results
    println()
    # objective value
    println(-model_results["objective_value"])
    # solve time
    println(model_results["solve_time"])
    # maximum optimality gap
    println(100 * model_results["relative_gap"])
    # complementarity violation
    println(sum((model_results["ys"]["s", :, :, :] .* model_results["yd"]["s", :, : , :]) .>= 1e-8)/length(model_results["yd"]["s", :, : , :]))
    # storage supply cycles
    for c in case_data.C
        # avg.
        println(mean(case_data.Δt * sum(model_results["ys"]["s",:,k,c] for k in case_data.K)./(case_data.ηd * case_data.Ts * model_results["xtot"]["s", :, 0])))
        # max.
        println(maximum(case_data.Δt * sum(model_results["ys"]["s",:,k,c] for k in case_data.K)./(case_data.ηd * case_data.Ts * model_results["xtot"]["s", :, 0])))   
    end
    # total operating cost -- base case and contingency
    for c in case_data.C
        println(case_data.Δt * sum( sum(case_data.ps[r,n,k] * model_results["ys"][r,n,k,c] for r in case_data.R) 
            - sum(case_data.pd[r,n,k] * model_results["yd"][r,n,k,c] for r in setdiff(case_data.D, ["ℓ"])) 
            for n in case_data.N, k in case_data.K))
    end
    # total cost of lost load -- base case and contingency
    for c in case_data.C
        println(case_data.Δt * sum(case_data.pd["ℓ",n,k] * (case_data.ȳℓ[n,k] - model_results["yd"]["ℓ",n,k,c]) for n in case_data.N, k in case_data.K))
    end
    # total capital cost
    println(sum(case_data.p[r,n] * model_results["x"][r,n] + case_data.c0[r,n] * model_results["z"][r,n] for n in case_data.N for r in case_data.R))
    # terminal capacity
    println()
    for r in ["b", "g", "s"]
        if r in case_data.R
            println(model_results["xtot"][r, end, 0])
        else
            println(0.)
        end
    end
    # total investment (MW)
    println()
    for r in ["b", "g", "s"]
        if r in case_data.R
            println(sum(model_results["x"][r, n] for n in case_data.N))
        else
            println(0.)
        end
    end
    # total investment (M$)
    println()
    for r in ["b", "g", "s"]
        if r in case_data.R
            println(sum(case_data.p[r, n] * model_results["x"][r, n] + case_data.c0[r, n] * model_results["z"][r, n] for n in case_data.N))
        else
            println(0.)
        end
    end
    # -- operations
    for c in case_data.C
        println()
        # max supply(MW)
        println()
        for r in ["b", "g", "s"]
            if r in case_data.R
                println(r == "g" ? max(maximum(model_results["ys"]["g", :, :, c] .- model_results["yd"]["g", :, :, c]), 0) : maximum(model_results["ys"][r, :, :, c])
                )
            else
                println(0.)
            end
        end
        println(maximum(case_data.ȳℓ .- model_results["yd"]["ℓ", :, :, c]))
        # max demand (MW)
        println()
        for r in ["g", "ℓ", "s"]
            if r in case_data.D
                println(r == "g" ? max(maximum(model_results["yd"]["g", :, :, c] .- model_results["ys"]["g", :, :, c]), 0) : maximum(model_results["yd"][r, :, :, c])
                )
            else
                println(0.)
            end
        end
        # total supply (MWh)
        println()
        for r in ["b", "g", "s"]
            if r in case_data.R
                println(r == "g" ? case_data.Δt * sum(max.(model_results["ys"]["g", :, :, c] .- model_results["yd"]["g", :, :, c], 0)) : 
                    case_data.Δt * sum(model_results["ys"][r, :, :, c]))
            else
                println(0.)
            end
        end
        println(case_data.Δt * sum(case_data.ȳℓ .- model_results["yd"]["ℓ", :, :, c]))
        # total demand (MWh)
        println()
        for r in ["g", "ℓ", "s"]
            if r in case_data.D
                println(r == "g" ? case_data.Δt * sum(max.(model_results["yd"]["g", :, :, c] .- model_results["ys"]["g", :, :, c], 0)) : 
                    case_data.Δt * sum(model_results["yd"][r, :, :, c]))
            else
                println(0.)
            end
        end
        # supply cost
        println()
        for r in ["b", "g", "s"]
            if r in case_data.R
                println(r == "g" ? case_data.Δt * sum(case_data.ps["g",:,:] .* max.(model_results["ys"]["g", :, :, c] .- model_results["yd"]["g", :, :, c], 0)) : 
                    case_data.Δt * sum(case_data.ps[r,:,:] .* model_results["ys"][r, :, :, c]))
            else
                println(0.)
            end
        end
        # demand revenue
        println()   
        for r in ["g", "ℓ", "s"]
            if r in case_data.D
                println(r == "g" ? case_data.Δt * sum(case_data.pd["g",:,:] .* max.(model_results["yd"]["g", :, :, c] .- model_results["ys"]["g", :, :, c], 0)) : 
                    case_data.Δt * sum(case_data.pd[r,:,:] .* model_results["yd"][r, :, :, c]))
            else
                println(0.)
            end
        end
    end
end

function analysis_plan(model_data::Tuple{Model, CaseDataPlan}; print_result::Bool = true, save_result::Union{Nothing, String} = nothing)
    model = model_data[1]
    case_data = model_data[2]
    @unpack R, D, K, N, C, Cs, ȳℓ, p, ps, pd, Δt, c0, T, Ts, r, market, ηc, ηd = case_data;   
    # build result dict for saving
    result_dict = Dict(
        "ys" => Dict(r => ys),
        "yd" => yd,
        "x" => Dict(r => x[r, :].data for r in R),
        "z" => z,
        "y0" => y0,
        "ysoc" => ysoc,
        "objective_value" => objective_value(model),
        "solve_time" => solve_time(model),
        "relative_gap" => Bool(MOI.get(model, Gurobi.ModelAttribute("IsMIP"))) ? relative_gap(model) : 0.,
    )

    open(save_result * "_result.json", "w") do io
            JSON3.write(io, result_dict)
    end
    # save_result = "results/planning/peak_full"

    # write result dict
    result_dict = Dict(
        # parameters
        "discount rate" => r,
        # general
        "objective" => objective_value(model),
        "solve time" => solve_time(model),
        "optimality gap" => relative_gap(model),
        "complementarity violation" => sum((ys["s", :, :, :] .* yd["s", :, : , :]) .>= 1e-8)/length(yd["s", :, : , :]),
        # terminal capacity
        "terminal backup" => value(model[:xtot]["b", end, 0]),
        "terminal grid" => value(model[:xtot]["g", end, 0]),
        "terminal storage" => value(model[:xtot]["s", end, 0]),
        "terminal peak demand" => maximum(yd["ℓ", end, :, 0]),
        "terminal peak unmet demand" => maximum(ȳℓ[end, :] - yd["ℓ", end, :, 1]),
        # total investment (MW)
        "total investment backup (MW)" => sum(x["b", :]),
        "total investment grid (MW)" => sum(x["g", :]),
        "total investment storage (MW)" => sum(x["s", :]),
        # total investment (money)
        "total investment backup (money)" => sum( p["b", n] * x["b", n] + c0["b", n] * z["b", n] for n in N),
        "total investment grid (money)" => sum( p["g", n] * x["g", n] + c0["g", n] * z["g", n] for n in N),
        "total investment storage (money)" => sum( p["s", n] * x["s", n] + c0["s", n] * z["s", n] for n in N),
        # total supply (MWh)
        "total supply backup (MWh)" => sum(T[n,c] * sum(ys["b", n, k, c] for k in K) for n in N, c in C),
        "total supply grid (MWh)" => sum(T[n,c] * sum(ys["g", n, k, c] for k in K) for n in N, c in C),
        "total supply storage (MWh)" => sum(T[n,c] * sum(ys["s", n, k, c] for k in K) for n in N, c in C),
        # total demand (MWh)
        "total demand grid (MWh)" => sum(T[n,c] * sum(yd["g", n, k, c] for k in K) for n in N, c in C),
        "total demand load (MWh)" => sum(T[n,c] * sum(yd["ℓ", n, k, c] for k in K) for n in N, c in C),
        "total unmet load (MWh)" => sum(T[n,c] * sum(ȳℓ[n,k] - yd["ℓ", n, k, c] for k in K) for n in N, c in C),
        "total demand storage (MWh)" => sum(T[n,c] * sum(yd["s", n, k, c] for k in K) for n in N, c in C),
        # supply cost ($)
        "supply cost backup (money)" => sum(T[n,c] * sum(ps["b", n, k] * ys["b", n, k, c] for k in K) for n in N, c in C),
        "supply cost grid (money)" => sum(T[n,c] * sum(ps["g", n, k] * ys["g", n, k, c] for k in K) for n in N, c in C),
        "supply cost storage (money)" => sum(T[n,c] * sum(ps["s", n, k] * ys["s", n, k, c] for k in K) for n in N, c in C),
        # demand revenue ($)
        "demand revenue grid (money)" => sum(T[n,c] * sum(pd["g", n, k] * yd["g", n, k, c] for k in K) for n in N, c in C),
        "demand revenue load (money)" => sum(T[n,c] * sum(pd["ℓ", n, k] * yd["ℓ", n, k, c] for k in K) for n in N, c in C),
        "demand revenue storage (money)" => sum(T[n,c] * sum(pd["s", n, k] * yd["s", n, k, c] for k in K) for n in N, c in C),
        )
    if print_result
        println("Discount rate")
        println(result_dict["discount rate"])
        println("General")
        println(result_dict["objective"])
        println(result_dict["solve time"])
        println(result_dict["optimality gap"])
        println(result_dict["complementarity violation"])
        # println("Terminal capacity")
        println()
        println(result_dict["terminal backup"])
        println(result_dict["terminal grid"])
        println(result_dict["terminal storage"])
        println(result_dict["terminal peak demand"])
        println(result_dict["terminal peak unmet demand"])
        # println("Total investment (MW)")
        println()
        println(result_dict["total investment backup (MW)"])
        println(result_dict["total investment grid (MW)"])
        println(result_dict["total investment storage (MW)"])
        # println("Total investment (\$)")
        println()
        println(result_dict["total investment backup (money)"])
        println(result_dict["total investment grid (money)"])
        println(result_dict["total investment storage (money)"])
        # println("Total supply (MWh)")
        println()
        println(result_dict["total supply backup (MWh)"])
        println(result_dict["total supply grid (MWh)"])
        println(result_dict["total supply storage (MWh)"])
        # println("Total demand (MWh)")
        println()
        println(result_dict["total demand grid (MWh)"])
        println(result_dict["total demand load (MWh)"])
        println(result_dict["total unmet load (MWh)"])
        println(result_dict["total demand storage (MWh)"])
        # println("Supply cost (\$)")
        println()
        println(result_dict["supply cost backup (money)"])
        println(result_dict["supply cost grid (money)"])
        println(result_dict["supply cost storage (money)"])
        # println("Demand revenue (\$)")
        println()
        println(result_dict["demand revenue grid (money)"])
        println(result_dict["demand revenue load (money)"])
        println(result_dict["demand revenue storage (money)"])
    end
    return result_dict
end

function analysis_ops(model_data::Tuple{Model, CaseDataOps}; print_result::Bool = true, save_result::Union{Nothing, String} = nothing)  
    # unpack model data
    model = model_data[1]
    case_data = model_data[2]
    @unpack R, K, D, market, load_shedding, ps, pd, Δt, xtot, Ts, ȳℓ, Cs, ηd, T = case_data;
    # retrieve necessary information
    ys = value.(model[:ys])
    yd = value.(model[:yd])
    if "s" in R
        if isnothing(case_data.y0)
            y0 = value(model[:y0])
        else
            y0 = case_data.y0
        end
    else
        y0 = 0.
    end

    # build dataframe with time resolution
    if !isnothing(T)
        df = DataFrame(T=T, yss = ys["s",:].data, ysd = yd["s", :].data, yℓ = ȳℓ.data)
    end

    # parse JuMP data
    ys_dict = Dict()
    yd_dict = Dict()
    for r in R
        ys_dict[r] = ys[r, :].data
    end
    for r in D
        yd_dict[r] = yd[r, :].data
    end

    # build result_dict
    result_dict = Dict(
        "ys" => ys_dict,
        "yd" => yd_dict,
        "y0" => y0,
        "objective_value" => objective_value(model),
        "solve_time" => solve_time(model),
        "relative_gap" => Bool(MOI.get(model, Gurobi.ModelAttribute("IsMIP"))) ? relative_gap(model) : 0.,
        "operating_cost" => Δt * sum( sum(ps[r,k] * ys[r,k] for r in R) 
        - sum(pd[r,k] * yd[r,k] for r in setdiff(D, ["ℓ"])) 
        +  pd["ℓ",k] * (ȳℓ[k] - yd["ℓ",k])
        for k in K),
        "load_shed" => Δt * sum(ȳℓ - yd["ℓ", :]),
    )

    # prepare case_data for saving
    case_dict = Dict(field => getfield(case_data, field) for field in fieldnames(typeof(case_data)))
    xtot_dict = Dict()
    for r in R
        xtot_dict[r] = xtot[r]
    end
    case_dict[:xtot] = xtot_dict
    case_dict[:ȳℓ] = ȳℓ.data
    

    # printing
    if print_result
        println(!isnothing(Cs) ? Cs * Ts * xtot["s"] * ηd : "")
        println(mean(case_data.pd["ℓ", :]))
        println(length(case_data.K))
        println(!isnothing(T) ? length(unique(df[df.yℓ .> xtot["g"], :T])) : "")
        println()
        for r in ["b", "g", "s"] 
            println(r in R ? xtot[r] : 0.)
        end
        println()
        for i in instances(Market)
            println(Int(market == i))
        end
        println()
        println(Int(load_shedding))
        println()
        println(Int(isnothing(y0)))
        println()
        println(objective_value(model))
        println(Δt * sum( sum(ps[r,k] * ys[r,k] for r in R) 
                        - sum(pd[r,k] * yd[r,k] for r in setdiff(D, ["ℓ"])) 
                        +  pd["ℓ",k] * (ȳℓ[k] - yd["ℓ",k])
                        for k in K)
              )
        println(solve_time(model))
        println(Bool(MOI.get(model, Gurobi.ModelAttribute("IsMIP"))) ? relative_gap(model) : 0.)
        println(sum((ys["s", :] .* yd["s", :]) .>= 1e-8)/length(yd["s", :]))
        println(y0)
        println( !isnothing(T) ? length(unique(df[ (df.yss .!= 0.0), :T ])) : "")
        println( !isnothing(T) ? length(unique(df[ (df.ysd .!= 0.0), :T ])) : "")
        println()
        # max supply (MWh)
        for r in ["b", "g", "s"] 
            println(r in R ? maximum(ys[r, :]) : 0.)
        end
        println()
        # max demand (MWh)
        for r in ["g", "ℓ", "s"] 
            println(r in D ? maximum(yd[r, :]) : 0.)
        end
        println()
        # total supply (MWh)
        for r in ["b", "g", "s"] 
            println(r in R ? Δt * sum(ys[r, :]) : 0.)
        end
        println()
        # total demand (MWh)
        for r in ["g", "ℓ", "s"] 
            println(r in D ? Δt * sum(yd[r, :]) : 0.)
        end
        # unmet load
        println(Δt * sum(ȳℓ - yd["ℓ", :]))
        println()
        # supply cost ($)
        for r in ["b", "g", "s"] 
            println(r in R ? Δt * sum(ps[r, k] * ys[r, k] for k in K) : 0.)
        end
        println()
        # demand revenue ($)
        for r in ["g", "ℓ", "s"]
            println(r in D ? Δt * sum(pd[r, k] * yd[r, k] for k in K) : 0.)
        end
    end

    # save result
    if !isnothing(save_result)
        open(save_result * "_result.json", "w") do io
            JSON3.write(io, result_dict)
        end
        open(save_result * "_case.json", "w") do io
            JSON3.write(io, case_dict)            
        end
    end

    return result_dict, case_dict
end