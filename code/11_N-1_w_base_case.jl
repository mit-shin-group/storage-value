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
    x̄b0 = reshape(data["existing battery capacity (MW)"], (data["number of existing batteries (-)"], length(data["planning periods"]))),
    ηc = data["battery charging efficiency (-)"],
    ηd = data["battery discharging efficiency (-)"],
    Nb = data["battery lifetime (years)"],
    Ts = data["battery duration (h)"],
    # # lines
    pℓ = data["line capital cost (\$/MW)"],
    x̲ℓ = data["cable min. investment (MW)"],
    x̄ℓ = data["cable max. investment (MW)"],
    l̄0 = reshape(data["existing line capacity (MW)"], (data["number of existing lines (-)"], length(data["planning periods"]))),
    Nℓ = data["cable lifetime (years)"],
    # grid and demand
    ℓ = reshape(data["peak load (MW)"], (length(data["planning periods"]), Int(length(data["peak load (MW)"])/length(data["planning periods"])))),
    p = reshape(data["electricity peak load price (\$/MWh)"], (length(data["planning periods"]), Int(length(data["electricity peak load price (\$/MWh)"])/length(data["planning periods"])))),
    p̄ = data["value of lost load (\$/MWh)"],
    T = reshape(data["probability-adjusted peak load days (-)"], (length(data["planning periods"]), Int(length(data["probability-adjusted peak load days (-)"])/length(data["planning periods"])))),
    # generic
    Δt = data["time discretization (h)"]            
)

# run sweep on T_{n,1} vs T_{n,2}}