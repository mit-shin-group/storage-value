using JuMP, OffsetArrays

# include("01_data.jl")

function analysis(model::Model; case_data::CaseData = CaseData(), print_result::Bool = true)
    @unpack K, N, C, ȳℓ, p, c0, T, ps, pd, r = case_data;
    # retrieve necessary information
    ys = value.(model[:ys])
    yd = value.(model[:yd])
    x = value.(model[:x])
    z = value.(model[:z])
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

function analysis_ops(model_data::Tuple{Model, CaseDataOps}; print_result::Bool = true)
    model = model_data[1]
    case_data = model_data[2]
    @unpack R, K, D, market, load_shedding, ps, pd, Δt, xtot, Ts, ȳℓ = case_data;
    # retrieve necessary information
    ys = value.(model[:ys])
    yd = value.(model[:yd])
    if "s" in R
        y0 = value(model[:y0])/(Ts * xtot["s"])
    else
        y0 = 0.
    end
    if print_result
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
        println(solve_time(model))
        println(Bool(MOI.get(model, Gurobi.ModelAttribute("IsMIP"))) ? relative_gap(model) : 0.)
        println(sum((ys["s", :] .* yd["s", :]) .>= 1e-8)/length(yd["s", :]))
        println(y0)
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
end