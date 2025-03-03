using JSON3
include("09_N-1_secure_model.jl")

# read data
file_path = "data/nantucket.json"

function read_data(file_path)
    open(file_path) do io
        data = JSON3.read(io)
        return data
    end
end

data = read_data(file_path)

# populate data structure
case_data = CaseDataN1(
    # batteries
    x̲b = data["battery min. investment (MW)"],
    x̄b = data["battery max. investment (MW)"],
    pb = data["battery capital cost (\$/MW)"],
    x̄b0 = data["existing battery capacity (MW)"],
    ηc = data["battery charging efficiency (-)"],
    ηd = data["battery discharging efficiency (-)"],
    Nb = data["battery lifetime (years)"],
    Ts = data["battery duration (h)"],
    # lines
    pℓ = data["line capital cost (\$/MW)"],
    x̲ℓ = data["cable min. investment (MW)"],
    x̄ℓ = data["cable max. investment (MW)"],
    Nℓ = data["cable lifetime (years)"],
    # grid and demand
    ℓ = data["peak load (MW)"],
    p = data["electricity peak load price (\$/MWh)"],
    p̄ = data["value of lost load (\$/MWh)"],
    T = data["probability-adjusted peak load days (-)"],
    # generic
    Δt = data["time discretization (h)"]            
)

# run sweep on T_{n,1} vs T_{n,2}}
