include("03_model.jl")
include("04_analysis.jl")
using ArgParse

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "--dates", "-d"
            arg_type=String
            default="peak"
            help="Operational horizon: peak or year"
        "--stride", "-s"
            arg_type=Int
            default=1
            help="Stride for daily operating problems"
        "--market", "-m"
            arg_type = String
            default = "full"
            help="Market participation: full, no_exports, limited_backup, or peak_shaving"
        "--cycles", "-c"
            arg_type=Float64
            default=150.
            help="Max. yearly battery cycles"
        "--timelimit", "-t"
            arg_type=Float64
            default=41400.
            help="Time limit for Gurobi solver in seconds"
        "--load_shedding", "-l"
            arg_type=Bool
            default=true
            help="Allow load shedding (default: true)"
        "--backup", "-b"
            arg_type=Bool
            default=true
            help="Allow for backup generation (default: true)"    
        "--new_backup"
            arg_type=Bool
            default=true
            help="Allow for new backup investment (default: true)"    
        "--new_storage"
            arg_type=Bool
            default=true
            help="Allow for new storage investment (default: true)"
        "--free_storage"
            arg_type=Bool
            default=false
            help="Free storage investments (default: false)"
        "--mipgap", "-g"
            arg_type=Float64
            default=0.001
            help="MIP gap for Gurobi (default: 0.001)"
        "--experiment"
            arg_type=Union{Nothing, String}
            default = nothing
            help="Experiment number (default nothing)"
    end
    return parse_args(s)
end

function main()
    # parse command line arguments
    args = parse_commandline()
    date = args["dates"]
    stride = args["stride"]
    market_str = args["market"]
    market = parse_market(market_str)
    Cs = args["cycles"]
    timelimit = args["timelimit"]
    load_shedding = args["load_shedding"]
    backup = args["backup"]
    new_backup = args["new_backup"]
    new_storage = args["new_storage"]
    free_storage = args["free_storage"]
    grb_mipgap = args["mipgap"]
    experiment = args["experiment"]
    # run julia script
    save_planning_results(run_model(build_data_plan(date = date, stride = stride, market = market, Cs = Cs, grb_silent = false, grb_mipgap = grb_mipgap, grb_timelimit = timelimit, load_shedding = load_shedding, backup = backup, new_backup = new_backup, new_storage = new_storage, free_storage = free_storage, experiment = experiment)))
end

main()
