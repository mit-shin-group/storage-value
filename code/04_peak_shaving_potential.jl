using JuMP, Gurobi, DataFrames, JSON3, Statistics, CSV

function model_unlimited(η::Float64, ℓ::Vector{Float64})
    K = length(ℓ)
    PS = Model()    # PS: peak-shaving
    # variables
    @variable(PS, ys[1:K] >= 0)  # supply: discharging
    @variable(PS, yd[1:K] >= 0)  # demand: charging
    @variable(PS, ℓ0)            # epigraphical variable
    # constraints
    @constraint(PS, η*sum(yd) - sum(ys) >= 0)
    @constraint(PS, [k = 1:K], ℓ0 >= ℓ[k] - ys[k] + yd[k])
    # objective
    @objective(PS, Min, ℓ0)
    set_optimizer(PS, Gurobi.Optimizer)
    optimize!(PS)
    return PS
end

function compute_results(η::Float64, ℓ::Vector{Float64}; Δt::Float64 = 1.)
    if η == 0.
        new_peak = maximum(ℓ)/mean(ℓ) - 1
        power = ' '
        duration = 0.
    else
        PS = model_unlimited(η, ℓ)
        new_peak = objective_value(PS)/mean(ℓ) - 1
        power = max(maximum(value.(PS[:ys])), maximum(value.(PS[:yd])))/mean(ℓ)
        running_sum = Δt * cumsum(value.(sqrt(η)*PS[:yd]) - value.(PS[:ys])/sqrt(η))
        duration = (maximum(running_sum) - minimum(running_sum))/max(maximum(value.(PS[:ys])), maximum(value.(PS[:yd])))/12
    end
    return (nsq = η, new_peak = new_peak, power = power, duration = duration)
end

function analysis()
    # read data
    file_path = "data/nantucket.json"
    function read_data(file_path)
        open(file_path) do io
            data = JSON3.read(io)
            return data
        end
    end
    data = read_data(file_path)
    # extract load (rows: planning periods, columns: operating periods)
    ℓ = reshape(data["peak load (MW)"], (length(data["planning periods"]), Int(length(data["peak load (MW)"])/length(data["planning periods"]))))

    η_list = 0:0.01:1
    df = DataFrame([compute_results(η, ℓ[1,:]) for η in η_list])
    CSV.write("results/potential.txt", df)
    return df
end