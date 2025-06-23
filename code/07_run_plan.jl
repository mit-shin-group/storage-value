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
            default=28800.
            help="Time limit for Gurobi solver in seconds"
        "--load_shedding", "-l"
            arg_type=Bool
            default=true
            help="Allow load shedding (default: true)"
        "--mip_gap", "-g"
            arg_type=Float64
            default=0.001
            help="MIP gap for Gurobi (default: 0.001)"
    end
    return parse_args(s)
end

function main()
    # parse command line arguments
    args = parse_commandline()
    date = args["dates"]
    market_str = args["market"]
    market = parse_market(market_str)
    Cs = args["cycles"]
    timelimit = args["timelimit"]
    load_shedding = args["load_shedding"]
    grb_mipgap = args["mip_gap"]
    # run julia script
    save_planning_results(run_model(build_data_plan(date = date, market = market, Cs = Cs, grb_silent = false, grb_mipgap = grb_mipgap, grb_timelimit = timelimit, load_shedding = load_shedding)))
end

main()
