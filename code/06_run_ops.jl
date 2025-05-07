include("03_model.jl")
include("04_analysis.jl")
using ArgParse

# call with 
# julia --threads 8 --project=. code/06_run_ops.jl -d code/06_dates.txt -m full

# Function to parse the market type from a string
function parse_market(x::AbstractString)
    lower_x = lowercase(x)
    if lower_x == "full"
        return full
    elseif lower_x == "no_exports"
        return no_exports
    elseif lower_x == "limited_backup"
        return limited_backup
    elseif lower_x == "peak_shaving"
        return peak_shaving
    else
        throw(ArgumentError("Invalid market type: $x"))
    end
end

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "--dates", "-d"
            default="code/06_dates_short.txt"
            help="File with dates"
        "--result_path", "-r"
            default="results/ops/2024_"
            help="Path to save results"
        "--market", "-m"
            arg_type = String
            default = "full"
            help="Market participation: full, no_exports, limited_backup, peak_shaving"
        "--grid", "-g"
            arg_type=Float64
            default=74.
            help="Grid (MW)"
        "--storage", "-s"
            arg_type=Float64
            default=6.
            help="Storage (MW)"
        "--backup", "-b"
            arg_type=Float64
            default=12.921
            help="Backup (MW)"
    end
    return parse_args(s)
end

function main()
    # parse command line arguments
    args = parse_commandline()
    dates = readlines(args["dates"])
    market_str = args["market"]
    market = parse_market(market_str)
    grid = args["grid"]
    storage = args["storage"]
    backup = args["backup"]
    
    # build result path
    result_path = args["result_path"] * market_str * "_" * string(grid) * "g_" * string(storage) * "s_" * string(backup) * "b" * "/"
    if !isdir(result_path)
        mkdir(result_path)
    end

    # Available capacity under N-1 contingency
    xtot=Containers.DenseAxisArray([backup, grid, storage], ["b", "g", "s"])

    # run for peak load to fix y0
    println("Running for peak load")
    result_dict, case_dict = analysis_ops(run_model(build_data_ops(date = "peak", y0 = nothing, market = market, xtot = xtot)), print_result = false, save_result = result_path * "peak")

    # Create separate Gurobi environments per thread
    n_threads = Threads.nthreads()
    envs = [Gurobi.Env() for _ in 1:n_threads]

    # Use Threads.@threads to process each date
    Threads.@threads for date in dates
        thread_id = Threads.threadid()
        println("Running for date: ", date, " on thread: ", thread_id)
        analysis_ops(run_model(build_data_ops(date = date, y0 = result_dict["y0"], market = market, xtot = xtot), envs[thread_id]), print_result = false, save_result = result_path * date)
    end
end

main()