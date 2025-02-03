using CSV, DataFrames
include("05_energy_balance.jl")

# read info for the full years
data_file = "data/Nantucket_2024.csv"
data = CSV.read(data_file, DataFrame)

# Nantucket arbitrage in 2024 data
case_data = CaseDataBO(
    # general parameters
    # - time discretization (h)
    Δt = 1.,
    # - electricity price ($/MWh)
    p = data.Price,
    # - value of lost load ($/MWh)
    p̄ = 2500.,
    # - load (MW), rows years, columns hours
    ℓ = data[!, "MW Factor"],
    # battery
    # - max discharging power (MW)
    x̲ = -6,
    # - max charging power (MW)
    x̄ = 6,
    # - energy capacity (MWh)
    ȳ = 48,
    # - initial state-of-charge (MWh)
    y0 = nothing,
    # - storage charging efficiency (-)
    ηc = 0.92,
    # - storage discharging efficiency (-)
    ηd = 0.92,
    # subsea cables
    # - capacity (MW)
    ℓ̄  = 74
)

# solve the problem
BO = solve_BO(case_data = case_data)

# print summary
sol_summary(BO, case_data = case_data)