using JSON3, CSV, DataFrames

# read standard data
file_path = "data/nantucket.json"
function read_data(file_path)
    open(file_path) do io
        data = JSON3.read(io)
        return data
    end
end
data = read_data(file_path)

# read info for the full years
data_file = "data/Nantucket_2024.csv"
yearly_data = CSV.read(data_file, DataFrame)

N = 2025:2050
R = ["b", "g", "s"]
D = ["ℓ", "g", "s"]
K = 1:nrow(yearly_data)

# Assume evolving load
peak_load_evolution = [
    62.455,
    63.987,
    65.328,
    66.669,
    68.202,
    70.117,
    71.650,
    73.182,
    75.098,
    77.013,
    78.929,
    80.653,
    82.377,
    84.292,
    86.208,
    88.123,
    89.273,
    90.805,
    91.955,
    93.104,
    93.870,
    95.020,
    95.786,
    96.744,
    97.318,
    98.084,       
]
ȳℓ = peak_load_evolution/maximum(yearly_data[!, "MW Factor"]) .* ones(26, length(K)) .* yearly_data[!, "MW Factor"]'
ȳℓ = Containers.@container([n in N, k in K], ȳℓ[n̲(n, first(N)), k])

# and constant prices
# - discount rate
r = data["discount rate (-)"]
# - construct prices
pg = yearly_data[!, "Price"] .* (1 - r).^(0:(length(N)-1))'
pb = data["backup electricity price (\$/MWh)"]
pℓ = 4 * data["value of lost load (\$/MWh)"]
ps = [ones(length(K)) * pb', pg, zeros(length(K), length(N))]
pd = [ones(length(K)) * pℓ', pg, zeros(length(K), length(N))]

# set operating costs
# Operating costs
ps = Dict((r,n,k) => ps[ri][k, n̲(n, first(N))] for (ri, r) in enumerate(R), n in N, k in K)
pd = Dict((r,n,k) => pd[ri][k, n̲(n, first(N))] for (ri, r) in enumerate(D), n in N, k in K)

case_data = CaseData(K = K, R = R, D = D, ps = ps, pd = pd, ȳℓ = ȳℓ)