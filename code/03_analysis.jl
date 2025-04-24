using JuMP, OffsetArrays

# include("01_data.jl")

function analysis(model::Model; case_data::CaseData = CaseData(), print_result::Bool = false)
    @unpack K, N, C, ȳℓ, p, c0, T, ps, pd = case_data;
    # retrieve necessary information
    ys = value.(model[:ys])
    yd = value.(model[:yd])
    x = value.(model[:x])
    z = value.(model[:z])
    # write result dict
    result_dict = Dict(
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
        println("General")
        println(result_dict["objective"])
        println(result_dict["solve time"])
        println(result_dict["optimality gap"])
        println(result_dict["complementarity violation"])
        println("Terminal capacity")
        println(result_dict["terminal backup"])
        println(result_dict["terminal grid"])
        println(result_dict["terminal storage"])
        println(result_dict["terminal peak demand"])
        println(result_dict["terminal peak unmet demand"])
        println("Total investment (MW)")
        println(result_dict["total investment backup (MW)"])
        println(result_dict["total investment grid (MW)"])
        println(result_dict["total investment storage (MW)"])
        println("Total investment (\$)")
        println(result_dict["total investment backup (money)"])
        println(result_dict["total investment grid (money)"])
        println(result_dict["total investment storage (money)"])
        println("Total supply (MWh)")
        println(result_dict["total supply backup (MWh)"])
        println(result_dict["total supply grid (MWh)"])
        println(result_dict["total supply storage (MWh)"])
        println("Total demand (MWh)")
        println(result_dict["total demand grid (MWh)"])
        println(result_dict["total demand load (MWh)"])
        println(result_dict["total demand storage (MWh)"])
        println("Supply cost (\$)")
        println(result_dict["supply cost backup (money)"])
        println(result_dict["supply cost grid (money)"])
        println(result_dict["supply cost storage (money)"])
        println("Demand revenue (\$)")
        println(result_dict["demand revenue grid (money)"])
        println(result_dict["demand revenue load (money)"])
        println(result_dict["demand revenue storage (money)"])
    end
    return result_dict
end