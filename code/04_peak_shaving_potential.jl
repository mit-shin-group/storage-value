using JuMP, Gurobi, DataFrames, Statistics

# Define load signal
ℓ = [
38,
35,
33,
32,
32,
32,
36,
41,
45,
46,
47,
49,
50,
51,
53,
54,
57,
57,
55,
53,
51,
48,
45,
45
]

ℓ2050 = [
65
65
60
57
55
55
55
62
70
77
79
81
84
86
88
91
93
98
98
95
91
88
83
77
]

function build_model_unlimited(η::Float64, ℓ::Vector{Int64})
    K = length(ℓ)
    PS = Model()
    # variables
    @variable(PS, x[1:K])
    @variable(PS, ℓ0)
    # constraints
    @constraint(PS, sum(x) >= 0)
    @constraint(PS, [k = 1:K], x[k] <= η * (ℓ0 - ℓ[k]))
    @constraint(PS, [k = 1:K], x[k] <= ℓ0 - ℓ[k])
    # objective
    @objective(PS, Min, ℓ0)
    return PS
end

function build_model(η::Float64, ℓ::Vector{Int64}, ȳ::Float64; Δt::Float64 = 1.0)
    K = length(ℓ)
    PS = Model()
    # variables
    @variable(PS, x[1:K])
    @variable(PS, α[1:K])
    @variable(PS, γ[1:K] >= 0)
    @variable(PS, δ[1:K] >= 0)
    @variable(PS, β)
    # constraints
    @constraint(PS, sum(α) <= 0)
    @constraint(PS, [k = 1:K], α[k] >= x[k])
    @constraint(PS, [k = 1:K], α[k] >= η*x[k])
    @constraint(PS, [k = 1:K], β >= ℓ[k] - x[k])
    # limit on min and max state-of-charge: limiting α is exact if load is "unimodal"
    @constraint(PS, [k = 1:K], γ[k] >= x[k])
    @constraint(PS, [k = 1:K], δ[k] >= -x[k])
    @constraint(PS, Δt * sum(γ) <= ȳ)
    @constraint(PS, Δt * η * sum(δ) <= ȳ)
    # objective
    @objective(PS, Min, β)
    return PS
end

function run_model_unlimited(; η::Float64 = 0.92, ℓ::Vector{Int64} = ℓ)
    PS = build_model_unlimited(η, ℓ)
    set_optimizer(PS, Gurobi.Optimizer)
    optimize!(PS)
    return PS
end

function run_model(; η::Float64 = 0.92, ℓ::Vector{Int64} = ℓ, ȳ::Float64 = 1.)
    PS = build_model(η, ℓ, ȳ)
    set_optimizer(PS, Gurobi.Optimizer)
    optimize!(PS)
    return PS
end

function run_η(η_list::Vector{Float64})
    ℓ_list = []
    α_list = []
    for η in η_list
        PS = run_model(η = η)
        push!(ℓ_list, round(objective_value(PS), digits = 3))
        push!(α_list, round(sum(max.(value.(PS[:α]), 0)), digits = 3))
    end
    return DataFrame(η = η_list, ℓ = ℓ_list, α = α_list)
end

function run_η_unlimited(η_list::Vector{Float64}, ℓ::Vector{Int64})
    ℓ0_list = []
    for η in η_list
        PS = run_model_unlimited(η = η, ℓ = ℓ)
        push!(ℓ0_list, round(objective_value(PS), digits = 3))
    end
    return DataFrame(η = η_list, ℓ = ℓ0_list)
end

function run_ȳ(ȳ_list::Vector{Float64}; ℓ::Vector{Int64} = ℓ)
    ℓ_list = []
    γ_list = []
    xin_list = []
    xout_list = []
    for ȳ in ȳ_list
        PS = run_model(ȳ = ȳ, ℓ = ℓ)
        push!(ℓ_list, round(objective_value(PS), digits = 3))
        push!(γ_list, round(sum(max.(value.(PS[:x]), 0)), digits = 3))
        push!(xin_list, -round(minimum(value.(PS[:x])), digits = 3))
        push!(xout_list, round(maximum(value.(PS[:x])), digits = 3))
    end
    return DataFrame(ȳ = ȳ_list, ℓ = ℓ_list, γ = γ_list, xin = xin_list, xout = xout_list)
end

η_list = 0.0:0.01:1.0

ȳmax = sum(max.(ℓ .- mean(ℓ), 0))
ȳ_list = 0.0:1:ceil(ȳmax)