using JuMP, DataFrames, OffsetArrays, JLD2, Dates, CairoMakie

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
    if case_data.experiment == nothing
        filename = "results/planning/" * string(length(case_data.K)) * string(case_data.market) * string(isnothing(case_data.Cs) ? "_nocyclelimit" : Int(case_data.Cs)) * "_shedding_" * string(case_data.load_shedding) * "_" * string(isnothing(case_data.J) ? "no" : length(case_data.J)) * "J_backup_" * string("b" in case_data.R) * "_newbackup_" * string(case_data.x̄["b"] != 0.0) * "_newstorage_" * string(case_data.x̄["s"] != 0.0) * "_freestorage_" * string(mean(case_data.p["s", :]) <= 10000) * ".jld"
    else
        filename = "results/experiments/ex" * case_data.experiment * ".jld" 
    end
    @save filename model_results case_data
end

function return_investment_experiment(experiment::String)
    result_file = "results/experiments/" * experiment * ".jld"
    experiment_results = JLD2.load(result_file)
    case_data = experiment_results["case_data"]
    model_results = experiment_results["model_results"]
    return model_results["x"]
end

function investment_overview(; experiment_list = ["ex1", "ex2", "ex3", "ex4", "ex5", "ex6", "ex7", "ex8", "ex9"])
    ov = Dict()
    for i in 1:length(experiment_list)
        ov[i] = return_investment_experiment(experiment_list[i])
    end
    return ov
end

function print_min_discharge_ratio(case_data::CaseDataPlan, model_results, r::String, c::Int; scarcity_events = [(date="Aug-01", hour=18), (date="Aug-01", hour=19), (date="Aug-01", hour=20), (date="Jun-18", hour=18), (date="Jun-18", hour=19)])
    min_ratio = 1
    for event in scarcity_events, n in case_data.N
        # take max to avoid division by zero
        if model_results["xtot"][r, n, 0] > 0
            min_ratio = min(min_ratio, model_results["ys"][r, n, event.date, event.hour, c] / model_results["xtot"][r, n, 0])
        end
    end
    println(min_ratio)
end

function return_ys_net(result_file::String; year::Int=2025)
    experiment_results = JLD2.load(result_file)
    model_results = experiment_results["model_results"]
    model_results["ys"]["b", year, :, :, :] = model_results["ys"]["b", year, :, :, :]/model_results["xtot"]["b", year, 0]
    model_results["ys"]["g", year, :, :, 0] = (model_results["ys"]["g", year, :, :, 0] .- model_results["yd"]["g", year, :, :, 0])/model_results["xtot"]["g", year, 0]
    model_results["ys"]["g", year, :, :, 1] = (model_results["ys"]["g", year, :, :, 1] .- model_results["yd"]["g", year, :, :, 1])/model_results["xtot"]["g", year, 1]
    model_results["ys"]["s", year, :, :, :] = (model_results["ys"]["s", year, :, :, :] .- model_results["yd"]["s", year, :, :, :])/model_results["xtot"]["s", year, 0]
    return model_results["ys"][:,year,:,:,:]
end

function plot_experiment(; year::Int=2025)
    # used to plot Figure 6 in the manuscript
    ys_ps = return_ys_net("results/experiments/ex2.jld", year = year)
    ys_mp = return_ys_net("results/experiments/ex3.jld", year = year)
    months = Date(year, 1, 1):Month(1):Date(year, 12, 1)
    xticks_pos = [dayofyear(m) for m in months]
    xticks_lab = [Dates.format(m, "u") for m in months]
    xticks_lab_empty = fill("", length(xticks_lab))

    yticks_pos = [1,7,13,19,24]
    yticks_lab = ["0:00","6:00","12:00","18:00","24:00"]
    yticks_lab_empty = fill("", length(yticks_lab))

    fig = Figure(size=(1200,1000))
    # Shared color scale
    vmin = -1
    vmax = 1
    colormap = :coolwarm
    # Heatmaps
    # ---- base operations
    Label(fig[0, 1:3], "Base case", fontsize=16, font=:regular)
    # -- no arbitrage
    heatmap!(Axis(fig[1,1]; title = "Backup", titlefont=:regular, titlesize=14, yreversed=true, ylabel = "No market participation", xticks=(xticks_pos, xticks_lab_empty), yticks=(yticks_pos, yticks_lab)), Array(ys_ps["b", :, :, 0]); colormap=colormap, colorrange=(vmin,vmax))
    heatmap!(Axis(fig[1,2]; title = "Grid", titlefont=:regular, titlesize=14, yreversed=true, xticks=(xticks_pos, xticks_lab_empty), yticks=(yticks_pos, yticks_lab_empty)), Array(ys_ps["g", :, :, 0]); colormap=colormap, colorrange=(vmin,vmax))
    heatmap!(Axis(fig[1,3]; title = "Storage", titlefont=:regular, titlesize=14, yreversed=true, xticks=(xticks_pos, xticks_lab_empty), yticks=(yticks_pos, yticks_lab_empty)), Array(ys_ps["s", :, :, 0]); colormap=colormap, colorrange=(vmin,vmax)) 
    # -- with arbitrage
    heatmap!(Axis(fig[2,1]; yreversed=true, ylabel = "With market participation", xticks=(xticks_pos, xticks_lab), yticks=(yticks_pos, yticks_lab)), Array(ys_mp["b", :, :, 0]); colormap=colormap, colorrange=(vmin,vmax))
    heatmap!(Axis(fig[2,2]; yreversed=true, xticks=(xticks_pos, xticks_lab), yticks=(yticks_pos, yticks_lab_empty)), Array(ys_mp["g", :, :, 0]); colormap=colormap, colorrange=(vmin,vmax))
    heatmap!(Axis(fig[2,3]; yreversed=true, xticks=(xticks_pos, xticks_lab), yticks=(yticks_pos, yticks_lab_empty)), Array(ys_mp["s", :, :, 0]); colormap=colormap, colorrange=(vmin,vmax)) 
    # ---- contingency operations
    Label(fig[3, 1:3], "Contingency", fontsize=16, font=:regular)
    # -- no arbitrage
    heatmap!(Axis(fig[4,1]; yreversed=true, ylabel = "No market participation", xticks=(xticks_pos, xticks_lab_empty), yticks=(yticks_pos, yticks_lab)), Array(ys_ps["b", :, :, 1]); colormap=colormap, colorrange=(vmin,vmax))
    heatmap!(Axis(fig[4,2]; yreversed=true, xticks=(xticks_pos, xticks_lab_empty), yticks=(yticks_pos, yticks_lab_empty)), Array(ys_ps["g", :, :, 1]); colormap=colormap, colorrange=(vmin,vmax))
    heatmap!(Axis(fig[4,3]; yreversed=true, xticks=(xticks_pos, xticks_lab_empty), yticks=(yticks_pos, yticks_lab_empty)), Array(ys_ps["s", :, :, 1]); colormap=colormap, colorrange=(vmin,vmax)) 
    # -- with arbitrage
    heatmap!(Axis(fig[5,1]; yreversed=true, ylabel = "With market participation", xticks=(xticks_pos, xticks_lab), yticks=(yticks_pos, yticks_lab)), Array(ys_mp["b", :, :, 1]); colormap=colormap, colorrange=(vmin,vmax))
    heatmap!(Axis(fig[5,2]; yreversed=true, xticks=(xticks_pos, xticks_lab), yticks=(yticks_pos, yticks_lab_empty)), Array(ys_mp["g", :, :, 1]); colormap=colormap, colorrange=(vmin,vmax))
    hm = heatmap!(Axis(fig[5,3]; yreversed=true, xticks=(xticks_pos, xticks_lab), yticks=(yticks_pos, yticks_lab_empty)), Array(ys_mp["s", :, :, 1]); colormap=colormap, colorrange=(vmin,vmax)) 
    # Shared colorbar below all three axes
    Colorbar(fig[6, 1:3], hm, label="Normalized power generation (-)", vertical=false, flipaxis=false)
    save("pics/heatmap.pdf", fig)
end

function print_experiments(experiment::String)
    result_file = "results/experiments/" * experiment * ".jld"
    experiment_results = JLD2.load(result_file)
    case_data = experiment_results["case_data"]
    model_results = experiment_results["model_results"]
    # --- Parameters
    # market participation
    println(case_data.market)
    # available resources
    println(case_data.R)
    # storage investment cost per MWh
    println(mean(case_data.p["s", :]) * case_data.Ts)
    # max. battery cycles per year
    println(case_data.Cs)
    # capacity payment
    println(mean(case_data.pcap["s", :])/12/1000)
    # --- Solution quality
    println()
    # total cost
    println(model_results["objective_value"]/1e6)
    # solve time
    println(model_results["solve_time"])
    # maximum MIP gap
    println(100 * model_results["relative_gap"])
    # --- Costs
    println()
    # total operating
    println(sum(case_data.T[n,j,c] * sum( sum(case_data.ps[r,n,j,k] * model_results["ys"][r,n,j,k,c] for r in case_data.R) 
            - sum(case_data.pd[r,n,j,k] * model_results["yd"][r,n,j,k,c] for r in setdiff(case_data.D, ["ℓ"])) for k in case_data.K) 
            for n in case_data.N, j in case_data.J, c in case_data.C)/1e6)
    # operating (base case)
    # operating (contingency)
    for c in case_data.C
        println(sum(sum( sum(case_data.ps[r,n,j,k] * model_results["ys"][r,n,j,k,c] for r in case_data.R) 
            - sum(case_data.pd[r,n,j,k] * model_results["yd"][r,n,j,k,c] for r in setdiff(case_data.D, ["ℓ"])) for k in case_data.K) 
            for n in case_data.N, j in case_data.J)/1e6)
    end
    # total capital
    println(sum(case_data.p[r,n] * model_results["x"][r,n] + case_data.p0[r,n] * model_results["z"][r,n] for n in case_data.N for r in case_data.R)/1e6)
    # capital
    for r in ["b", "g", "s"]
        if r in case_data.R
            println(sum(case_data.p[r,n] * model_results["x"][r,n] + case_data.p0[r,n] * model_results["z"][r,n] for n in case_data.N)/1e6)
        else
            println(0.)
        end
    end
    # total capacity payment
    println(sum(case_data.pcap[r,n] * model_results["xtot"][r,n,0] for n in case_data.N for r in case_data.R)/1e6)
    for r in ["b", "g", "s"]
        if r in case_data.R
            println(sum(case_data.pcap[r,n] * model_results["xtot"][r,n,0] for n in case_data.N)/1e6)
        else
            println(0.)
        end
    end
    # --- Investment
    println()
    # terminal capacity
    println(sum(model_results["xtot"][r, end, 0] for r in case_data.R))
    for r in ["b", "g", "s"]
        if r in case_data.R
            println(model_results["xtot"][r, end, 0])
        else
            println(0.)
        end
    end
    # total investment (MW)
    println(sum(model_results["x"][r, n] for n in case_data.N for r in case_data.R))
    for r in ["b", "g", "s"]
        if r in case_data.R
            println(sum(model_results["x"][r, n] for n in case_data.N))
        else
            println(0.)
        end
    end
    # --- Operating
    println()
    for c in case_data.C
        demand_wo_storage = 0
        # demand
        for r in ["g", "ℓ"]
            if r in case_data.D
                r == "g" ? demand_wo_storage += case_data.Δt * sum(max.(model_results["yd"]["g", :, :, :, c] .- model_results["ys"]["g", :, :, :, c], 0)) / 1e3 / length(case_data.N) : 
                    demand_wo_storage += case_data.Δt * sum(model_results["yd"][r, :, :, :, c]) / 1e3 / length(case_data.N)
            end
        end
        println(demand_wo_storage)
        for r in ["g", "ℓ", "s"]
            if r in case_data.D
                println(r == "g" ? case_data.Δt * sum(max.(model_results["yd"]["g", :, :, :, c] .- model_results["ys"]["g", :, :, :, c], 0)) / 1e3 / length(case_data.N) : 
                    case_data.Δt * sum(model_results["yd"][r, :, :, :, c]) / 1e3 / length(case_data.N))
            else
                println(0.)
            end
        end
        # supply
        supply_wo_storage = 0
         for r in ["b", "g"]
            if r in case_data.R
                r == "g" ? supply_wo_storage += case_data.Δt * sum(max.(model_results["ys"]["g", :, :, :, c] .- model_results["yd"]["g", :, :, :, c], 0)) / 1e3 / length(case_data.N) : 
                    supply_wo_storage += case_data.Δt * sum(model_results["ys"][r, :, :, :, c]) / 1e3 / length(case_data.N)
            end
        end
        println(supply_wo_storage)
        for r in ["b", "g", "s"]
            if r in case_data.R
                println(r == "g" ? case_data.Δt * sum(max.(model_results["ys"]["g", :, :, :, c] .- model_results["yd"]["g", :, :, :, c], 0)) / 1e3 / length(case_data.N) : 
                    case_data.Δt * sum(model_results["ys"][r, :, :, :, c]) / 1e3 / length(case_data.N))
            else
                println(0.)
            end
        end
        println()
    end
    # --- Discharge cycles 
    # storage supply cycles
    for c in case_data.C
        # avg.
        println(mean(replace((case_data.Δt * sum(model_results["ys"]["s",:,j,k,c] for j in case_data.J, k in case_data.K)./(case_data.ηd * case_data.Ts * model_results["xtot"]["s", :, 0])).data, NaN => 0.0)))
        # max.
        println(maximum(replace((case_data.Δt * sum(model_results["ys"]["s",:,j,k,c] for j in case_data.J, k in case_data.K)./(case_data.ηd * case_data.Ts * model_results["xtot"]["s", :, 0])).data, NaN => 0.0)))
    end
        # --- Discharge ratio during scarcity events
    println()
    for c in case_data.C
        for r in ["b", "s"]
            if r in case_data.R
                print_min_discharge_ratio(case_data, model_results, r, c)
            else
                println(0.)
            end
        end
    end
end