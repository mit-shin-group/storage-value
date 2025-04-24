using Parameters, JuMP, JSON3

function n̲(n, Nr; N = 1:25)
    return max(first(N), n - Nr + 1)
end

# Market participation types
@enum Market full no_exports limited_backup peak_shaving 

# read data
file_path = "data/nantucket.json"
function read_data(file_path)
    open(file_path) do io
        data = JSON3.read(io)
        return data
    end
end
data = read_data(file_path)

# for initialization
# - investment cost
p = [data["backup capital cost (\$/MW)"], data["line capital cost (\$/MW)"], data["battery capital cost (\$/MW)"]]
# - operating cost
pg = reshape(data["electricity peak load price (\$/MWh)"], 24, Int(length(data["electricity peak load price (\$/MWh)"])/24))
pb = data["backup electricity price (\$/MWh)"]
pℓ = data["value of lost load (\$/MWh)"]
ps = [ones(24) * pb', pg, zeros(24, Int(length(data["electricity peak load price (\$/MWh)"])/24))]
pd = [ones(24) * pℓ', pg, zeros(24, Int(length(data["electricity peak load price (\$/MWh)"])/24))]
# - time/probability weights
T = [5:30, 0.1 * (5:30)]
# - existing capacity
x0 = [reshape(data["existing backup capacity (MW)"], Int(length(data["existing backup capacity (MW)"])/26), 26), 
      reshape(data["existing line capacity (MW)"], Int(length(data["existing line capacity (MW)"])/26), 26),
      reshape(data["existing battery capacity (MW)"], Int(length(data["existing battery capacity (MW)"])/26), 26)]
# - investment ranges
x̲ = [data["backup min. investment (MW)"], data["cable min. investment (MW)"], data["battery min. investment (MW)"]]
x̄ = [data["backup max. investment (MW)"], data["cable max. investment (MW)"], data["battery max. investment (MW)"]]
# - peak load
ȳℓ = reshape(data["peak load (MW)"], 26, 24)

@with_kw struct CaseData
    # Index Sets
    # - Supply resource types
    R::Vector{String} = ["b", "g", "s"]
    # - Existing resources
    I::Dict{String, UnitRange{Int64}} = Dict(r => i for (r,i) in zip(R, [1:1, 1:2, 1:1]))
    # - Demand resource types
    D::Vector{String} = ["ℓ", "g", "s"]
    # - Planning periods
    N::UnitRange{Int64} = 2025:2050
    # - Operating periods
    K::UnitRange{Int64} = 1:24
    # - Contingencies
    C::UnitRange{Int64} = 0:1
    # Lifetimes
    Nr::Dict{String, Int64} = Dict(r => l for (r,l) in zip(R, [20, 40, 20]))
    # Operating period duration/probability
    T::Dict{Tuple{Int64, Int64}, Float64} = Dict((n,c) => T[n̲(c, first(C))][n̲(n, first(N))] for n in N, c in C)
    # Investment costs
    p::Dict{Tuple{String, Int64}, Float64} = Dict((r,n) => p[ri][n̲(n, first(N))] for (ri, r) in enumerate(R), n in N)
    c0::Dict{Tuple{String, Int64}, Float64} = Dict((r,n) => 0. for (ri, r) in enumerate(R), n in N)
    # Operating costs
    ps::Dict{Tuple{String, Int64, Int64}, Float64} = Dict((r,n,k) => ps[ri][k, n̲(n, first(N))] for (ri, r) in enumerate(R), n in N, k in K)
    pd::Dict{Tuple{String, Int64, Int64}, Float64} = Dict((r,n,k) => pd[ri][k, n̲(n, first(N))] for (ri, r) in enumerate(D), n in N, k in K)
    # Initial capacities
    x0::Dict{Tuple{String, Int64, Int64}, Float64} = Dict((r,n,i) => x0[ri][i, n̲(n, first(N))] for (ri, r) in enumerate(R) for n in N for i in I[r])
    # Investment ranges
    x̲::Dict{String, Float64} = Dict(r => x for (r,x) in zip(R, x̲))
    x̄::Dict{String, Float64} = Dict(r => x for (r,x) in zip(R, x̄))
    # Load
    # ȳℓ::Dict{Tuple{Int64, Int64}, Float64} = Dict((n,k) => ȳℓ[n̲(n, first(N)), k] for n in N, k in K)
    ȳℓ = Containers.@container([n in N, k in K], ȳℓ[n̲(n, first(N)), k])
    # Time discretization (hours)
    Δt::Float64 = 1.
    # Charging and discharging efficiencies
    ηc::Float64 = 0.92
    ηd::Float64 = 0.92
    # Storage duration
    Ts::Float64 = 8.
    # Market participation
    market::Market = full
end