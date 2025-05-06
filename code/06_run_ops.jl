include("03_model.jl")
include("04_analysis.jl")

# call with julia --threads X --project=.

# Read dates from the file
dates = readlines(ARGS[1])
result_path = "results/ops/2024_base/"

# run for peak load to fix y0
println("Running for peak load")
result_dict, case_dict = analysis_ops(run_model(build_data_ops(date = "peak", y0 = nothing, market = no_exports)), print_result = false, save_result = result_path * "peak")

# Create separate Gurobi environments per thread
n_threads = Threads.nthreads()
envs = [Gurobi.Env() for _ in 1:n_threads]

# Use Threads.@threads to process each date
Threads.@threads for date in dates
    thread_id = Threads.threadid()
    println("Running for date: ", date, " on thread: ", thread_id)
    analysis_ops(run_model(build_data_ops(date = date, y0 = result_dict["y0"], market = no_exports), envs[thread_id]), print_result = false, save_result = result_path * date)
end

# analysis_ops(run_model(build_data_ops(date = "peak", y0 = nothing, market = no_exports), env), print_result = false, save_result = nothing)