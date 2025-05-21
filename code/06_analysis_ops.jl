using JSON3
using DataFrames
using Plots
using Dates
using CSV

# result parameters
dates_file = "code/06_dates.txt"
experiment_list = ["full base", "full contingency", "peak shaving base", "peak shaving contingency"]

function daily_results(dates_file::String = "code/06_dates.txt", experiment_list::Vector{String} = ["full base", "full contingency", "peak shaving base", "peak shaving contingency", "no storage full base", "no storage full contingency", "no storage peak shaving base", "no storage peak shaving contingency"])
    # Load dates from file
    dates = readlines(dates_file)
    # Initialize an empty dict
    results = Dict()
    # Loop over experiments
    for experiment in experiment_list
        # Initialize an empty DataFrame
        results_df = DataFrame(date=String[], operating_cost=Float64[], load_shed=Float64[], yss=Float64[], ysb = Float64[], ysg = Float64[], yds = Float64[], ydℓ = Float64[])
        # Loop through each date and load the operating cost
        for date in dates
            if experiment == "full base"
                market = "no_exports"
                grid = "74.0"
                storage = "6.0"
            elseif experiment == "full contingency"
                market = "no_exports"
                grid = "36.0"
                storage = "6.0"
            elseif experiment == "peak shaving base"
                market = "peak_shaving"
                grid = "74.0"
                storage = "6.0"
            elseif experiment == "peak shaving contingency"
                market = "peak_shaving"
                grid = "36.0"
                storage = "6.0"
            elseif experiment == "no storage full base"
                market = "no_exports"
                grid = "74.0"
                storage = "0.0"
            elseif experiment == "no storage full contingency"
                market = "no_exports"
                grid = "36.0"
                storage = "0.0"
            elseif experiment == "no storage peak shaving base"
                market = "peak_shaving"
                grid = "74.0"
                storage = "0.0"
            elseif experiment == "no storage peak shaving contingency"
                market = "peak_shaving"
                grid = "36.0"
                storage = "0.0"                
            else
                error("Invalid experiment type: $experiment")
            end
            # Construct the file path
            json_file = joinpath("results", "ops", "2024_" * market * "_" * grid * "g_" * storage * "s_12.921b", "$(date)_result.json")
            if isfile(json_file)
                data = JSON3.read(json_file)
                operating_cost = get(data, "operating_cost", missing)
                load_shed = get(data, "load_shed", missing)
                ys = get(data, "ys", missing)
                yd = get(data, "yd", missing)
                if (operating_cost !== missing) & (load_shed !== missing) & (ys !== missing) & (yd !== missing)
                    push!(results_df, (date, operating_cost, load_shed, sum(ys["s"]), sum(ys["b"]), sum(ys["g"]), sum(yd["s"]), sum(yd["ℓ"])))
                else
                    println("Warning: 'operating_cost', 'load shed', 'ys', or 'yd' not found in $json_file")
                end
            else
                println("Warning: File $json_file does not exist")
            end
        end
        # Convert dates to Date objects for better formatting
        results_df.date = Date.(results_df.date, "yyyy-mm-dd")
        results[experiment] = results_df
    end
    return results
end

function yearly_opex(dates_file::String = "code/06_dates.txt", experiment_list::Vector{String} = ["full base", "full contingency", "peak shaving base", "peak shaving contingency"])
    # Load dates from file
    dates = readlines(dates_file)
    # Create a DataFrame to store the results
    # s_values = vcat(collect(0.0:15.0), [20.0, 25.0, 50.0, 100.0]) 
    s_values = 0.0:50.0
    summary_df = DataFrame(Symbol("s")=>Float64[], Symbol("full base")=>Float64[], Symbol("full contingency")=>Float64[], Symbol("peak shaving base")=>Float64[], Symbol("peak shaving contingency")=>Float64[])
    # Loop over s values
    for s in s_values
        row = Dict(:s => s)
        for experiment in experiment_list
            if experiment == "full base"
                market = "no_exports"
                grid = "74.0"
            elseif experiment == "full contingency"
                market = "no_exports"
                grid = "36.0"
            elseif experiment == "peak shaving base"
                market = "peak_shaving"
                grid = "74.0"
            elseif experiment == "peak shaving contingency"
                market = "peak_shaving"
                grid = "36.0"
            else
                error("Invalid experiment type: $experiment")
            end

            # Construct the directory path
            dir_path = joinpath("results", "ops", "2024_" * market * "_" * grid * "g_$(s)s_12.921b")

            # Print progress
            println("Processing: $dir_path")
            # Initialize the total cost
            total_cost = 0.0

            # Loop through each date and sum the operating costs
            for date in dates
                json_file = joinpath(dir_path, "$(date)_result.json")
                if isfile(json_file)
                    data = JSON3.read(json_file)
                    operating_cost = get(data, "operating_cost", missing)
                    if operating_cost !== missing
                        total_cost += operating_cost
                    else
                        println("Warning: 'operating_cost' not found in $json_file")
                    end
                else
                    println("Warning: File $json_file does not exist")
                end
            end

            # Add the total cost to the row
            row[Symbol(experiment)] = total_cost
        end

        # Push the row to the DataFrame
        push!(summary_df, row)
    end
    return summary_df
end

# CSV.write("results/ops/2024_opex_vs_storage.csv", df, writeheader=true, delim=",")
# df = CSV.read("results/ops/2024_opex_vs_storage.csv", DataFrame)

# Prints costs
function print_costs(results)
    for experiment in keys(results)
        results_df = results[experiment]
        println("Experiment: $experiment")
        println("Operating cost: $(round(sum(results_df.operating_cost)/1000)) k\$")
        println("Load shed: $(round(sum(results_df.load_shed)/1000, digits = 3)) GWh")
        println("Storage supply: $(round(sum(results_df.yss)/1000, digits = 3)) GWh") 
    end
end

# Plot results
# --- operating cost ---
function plot_operating_cost(results; experiment_list = experiment_list)
    for experiment in experiment_list
        results_df = results[experiment]
        if experiment == first(experiment_list)
            plot(results_df.date, results_df.operating_cost/1000,
                # title="Operating Cost Over Time",
                xlabel="Date",
                ylabel="Daily Operating Cost (k\$)",
                xticks=(results_df.date[1:30:end], Dates.format.(results_df.date[1:30:end], "mm-dd")),
                label=experiment,
                #  legend=:topright,
                #  marker=:o,
                grid=true,
            )
        else
            plot!(results_df.date, results_df.operating_cost/1000,
                #  title="Operating Cost Over Time",
                xlabel="Date",
                ylabel="Daily Operating Cost (k\$)",
                xticks=(results_df.date[1:30:end], Dates.format.(results_df.date[1:30:end], "mm-dd")),
                label=experiment,
                #  legend=:topright,
                #  marker=:o,
                grid=true,
            )
        end
    end
    display(current())
end

# --- ecdf cycles ---
function plot_ecdf_cycles(results; experiment_list = experiment_list)
    for experiment in experiment_list
        results_df = results[experiment]
        # Sort the cycles
        sorted_cycles = sort(results_df.yss)/48
        if experiment == first(experiment_list)
            # Plot the ECDF of cycles
            plot(sorted_cycles, collect(1:length(sorted_cycles))/length(sorted_cycles),
                # title="ECDF of Cycles",
                xlabel="Daily Cycles (-)",
                ylabel="Empirical Probability (-)",
                label=experiment,
                grid=true,
                ylim = (0, 1),
                xlim= (0, 1.5),
                lw = 1.2
            )
        else
            plot!(sorted_cycles, collect(1:length(sorted_cycles))/length(sorted_cycles),
                # title="ECDF of Cycles",
                xlabel="Daily Cycles (-)",
                ylabel="Empirical Probability (-)",
                label=experiment,
                grid=true,
                ylim = (-0.05, 1.05),
                xlim= (-0.075, 1.5),
                lw = 1.2
            )
        end
    end
    display(current())
end

# value of storage
function plot_value_of_storage(results; experiment_list = ["full base", "full contingency", "peak shaving base", "peak shaving contingency"])
    for experiment in experiment_list
        results_df = results[experiment]
        # Sort the operating costs
        if experiment == "full base"
            sorted_value = sort(results["no storage full base"].operating_cost - results_df.operating_cost)
        elseif experiment == "full contingency"
            sorted_value = sort(results["no storage full contingency"].operating_cost - results_df.operating_cost)
        elseif experiment == "peak shaving base"
            sorted_value = sort(results["no storage peak shaving base"].operating_cost - results_df.operating_cost)
        elseif experiment == "peak shaving contingency"
            sorted_value = sort(results["no storage peak shaving contingency"].operating_cost - results_df.operating_cost)
        else
            error("Invalid experiment type: $experiment")
        end
        # Plot the value of storage
        if experiment == first(experiment_list) 
            plot(sorted_value/1000, collect(1:length(sorted_value))/length(sorted_value),
                # title="Value of Storage",
                xlabel="Value of Storage (k\$)",
                ylabel="Empirical Probability (-)",
                label=experiment,
                grid=true,
                ylim = (-0.05, 1.05),
                # xlim= (0, ),
                lw = 1.2
            )
        else
             plot!(sorted_value/1000, collect(1:length(sorted_value))/length(sorted_value),
                # title="Value of Storage",
                xlabel="Value of Storage (k\$)",
                ylabel="Empirical Probability (-)",
                label=experiment,
                grid=true,
                ylim = (-0.05, 1.05),
                # xlim= (0, ),
                lw = 1.2
            )
        end
    end
    display(current())
end

# Option to change font sizes if necessary
# Plots.scalefontsizes(α)
# default(fontfamily="Arial")
# savefig("results/ops/2024_no_exports_36.0g_6.0s_12.921b/supply.svg")
# savefig("results/ops/2024_peak_shaving_36.0g_6.0s_12.921b/supply.svg")
# savefig("results/ops/2024_opex_vs_storage_50.svg") 

# --- supply mix ---
# Plot supply mix
function plot_supply_mix(results_df)
    day_month = [1, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 30]
    plot(results_df.date, results_df.ysg, 
        # xlabel="Date",
        ylabel="Supply (MWh)",
        xticks=(results_df.date[cumsum(day_month)[1:2:end]], Dates.format.(results_df.date[cumsum(day_month)[1:2:end]], "mm-dd")),
        label="Grid",
        alpha=0.5,
        color=:gray,
        lw=0,
        grid=true,
        fill_between=(zeros(length(results_df.ysb)), results_df.ysg),
        ylim=(0,1250),
    )

    plot!(results_df.date, results_df.ysg .+ results_df.yds, 
        label="Storage",
        color=:green,
        lw=0,
        fill_between=(results_df.ysg, results_df.ysg .+ results_df.yds)
    )

    plot!(results_df.date, results_df.ysb .+ results_df.yds .+ results_df.ysg, 
        label="Backup",
        color=:orange,
        lw=0,
        fill_between=(results_df.ysg .+ results_df.yds, results_df.ysb .+ results_df.yds .+ results_df.ysg)
    )

    plot!(results_df.date, results_df.ysb .+ results_df.yds .+ results_df.ysg .+ results_df.load_shed, 
        label="Lost load",
        color=:blue,
        lw=0,
        fill_between=(results_df.ysg .+ results_df.yds .+ results_df.ysb, results_df.ysb .+ results_df.yds .+ results_df.ysg .+ results_df.load_shed)
    )

    plot!(results_df.date, results_df.ydℓ, 
        label="Load",
        color=:black,
        lw=1.7
        # seriestype=:scatter
    )
end

function plot_opex_vs_storage(df::DataFrame, experiment_list::Vector{String} = ["peak shaving base", "peak shaving contingency", "full base", "full contingency"])
    color_list = [:black, :black, :red, :red]
    style_list = [:solid, :dash, :solid, :dash]
    # Plot the operating cost vs storage
    plot(df.s, df[!, experiment_list[1]]/1e6, 
        xlabel="Storage Capacity (MW)",
        ylabel="2024 Operating Cost (M\$)",
        # title="Operating Cost vs Storage",
        label=experiment_list[1],
        color=:black,
        grid=true,
        ylim = (6, 11.5),
        xlim= (0, 50),
        lw = 1.5,
        ls = :solid,
    )
    for i in 2:length(experiment_list)
        plot!(df.s, df[!, experiment_list[i]]/1e6, label=experiment_list[i], color=color_list[i], lw = 1.5, ls = style_list[i])
    end
    display(current())

    # add values
    plot!(df.s[[1, end]], [df[!, "full base"][1], (df[!, "full base"][2] - df[!, "full base"][1]) * (df[!, "s"][end] - df[!, "s"][1]) + df[!, "full base"][1]]/1e6,
    color=:black,
    lw = 1.2,
    ls = :dashdot,
    label = "Market value < \$65/kW"
    )

    plot!(df.s[[1, end]], [df[!, "peak shaving contingency"][1], (df[!, "peak shaving contingency"][2] - df[!, "peak shaving contingency"][1]) * (df[!, "s"][end] - df[!, "s"][1]) + df[!, "peak shaving contingency"][1]]/1e6,
    color=:red,
    lw = 1.2,
    ls = :dashdot,
    label = "Grid value < \$250/kW"
    )
end

function plot_opex_vs_storage_manual(df::DataFrame, experiment_list::Vector{String} = ["full base", "full contingency", "peak shaving base", "peak shaving contingency"])
    # Plot the operating cost vs storage
    plot(df.s, df[!, "peak shaving contingency"]/1e6, 
        xlabel="Storage Capacity (MW)",
        ylabel="2024 Operating Cost (M\$)",
        # title="Operating Cost vs Storage",
        label="Peak shaving only",
        color=:black,
        lw = 1.5,
        grid=true,
        ylim = (8, 11),
        xlim= (0, 15)
    )

    plot!(df.s, df[!, "full contingency"]/1e6, 
    label="Peak shaving + Arbitrage",
    color=:red,
    lw = 1.5,
    )

    # add values
    plot!(df.s[[1, end]], [df[!, "peak shaving contingency"][1], (df[!, "peak shaving contingency"][2] - df[!, "peak shaving contingency"][1]) * (df[!, "s"][end] - df[!, "s"][1]) + df[!, "peak shaving contingency"][1]]/1e6,
    color=:black,
    lw = 1.2,
    ls = :dash,
    label = "Grid value < \$250/kW"
    )

    plot!(df.s[[1, end]], [(df[!, "full contingency"][end-1] - df[!, "full contingency"][end]) * (df[!, "s"][end] - df[!, "s"][1]) + df[!, "full contingency"][end], df[!, "full contingency"][end]]/1e6,
    color=:red,
    lw = 1.2,
    ls = :dash,
    label = "Market value > \$45/kW"
    )

    display(current())
end