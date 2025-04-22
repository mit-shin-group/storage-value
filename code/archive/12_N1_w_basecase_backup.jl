using JSON3, DataFrames
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

# run sweep on T_{n,1} vs T_{n,0}}
df = DataFrame(T=Float64[], cost=Float64[], lost_load = Float64[], MWh_charged = Float64[], battery_MW_installed = Float64[], cable_MW_installed = Float64[], battery_cost = Float64[], cable_cost = Float64[])
for T1 in 1:10
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
        # lines
        pℓ = data["line capital cost (\$/MW)"],
        x̲ℓ = data["cable min. investment (MW)"],
        x̄ℓ = data["cable max. investment (MW)"],
        l̄0 = reshape(data["existing line capacity (MW)"], (data["number of existing lines (-)"], length(data["planning periods"]))),
        Nℓ = data["cable lifetime (years)"],
        # backup
        pg = data["backup capital cost (\$/MW)"],
        x̲g = data["backup min. investment (MW)"],
        x̄g = data["backup max. investment (MW)"],
        Ng = data["backup lifetime (years)"],
        x̄g0 = reshape(data["existing backup capacity (MW)"], (data["number of existing backup generators (-)"], length(data["planning periods"]))),
        p̄g =data["backup electricity price (\$/MWh)"], 
        # grid and demand
        ℓ = reshape(data["peak load (MW)"], (length(data["planning periods"]), Int(length(data["peak load (MW)"])/length(data["planning periods"])))),
        p = reshape(data["electricity peak load price (\$/MWh)"], (length(data["planning periods"]), Int(length(data["electricity peak load price (\$/MWh)"])/length(data["planning periods"])))),
        p̄ = data["value of lost load (\$/MWh)"],
        T = [1 T1] .* reshape(data["probability-adjusted peak load days (-)"], (length(data["planning periods"]), Int(length(data["probability-adjusted peak load days (-)"])/length(data["planning periods"])))),
        # generic
        Δt = data["time discretization (h)"]            
    )
    # solve the joint planning and operation problem
    JP = solve_JP(case_data = case_data)
    # analyze_JP
    analyze_JP(JP, case_data)
    # add results to DataFrame
    push!(df, [T1, objective_value(JP), 
                sum(sum(case_data.T[:,c]' * value.(JP[:s][:,:,c]) for c in eachindex(case_data.T[1,:]))),
                sum(sum(case_data.T[:,c]' * value.(JP[:xc][:,:,c]) for c in eachindex(case_data.T[1,:]))), 
                sum(value.(JP[:xb])), sum(value.(JP[:xℓ])), sum(case_data.pb .* value.(JP[:xb]))/1e6, sum(case_data.pℓ .* value.(JP[:xℓ]))/1e6])
end