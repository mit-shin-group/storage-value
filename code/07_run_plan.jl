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
    # run julia script
    save_planning_results(run_model(build_data_plan(date = date, market = market, Cs = Cs, grb_silent = false, grb_mipgap = 0.01)))
end

main()
