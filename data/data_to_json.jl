using JSON3

# for investment costs
consumer_price_index = Dict("2025" => 321.465, "2022" => 292.655, "2020" => 258.811, "2019" => 255.657, "2018" => 251.107) # https://www.rateinflation.com/consumer-price-index/usa-historical-cpi/

# --------------------------
# specify data and functions to construct the data dictionary
N = 2025:2050
r = 0.0  # - discount rate (-), PNNL assumed 0.0685
storage_duration = 8
battery_costs_per_MW = 1000 * storage_duration * [966.22307225, 936.33988445, 903.966431, 874.0832432, 841.70978974, 811.82660194, 799.37527369, 786.92394544, 774.47261719, 762.02128894, 749.56996069, 737.11863244, 724.66730419, 712.21597594, 699.76464769, 687.31331944, 674.86199119, 662.41066293, 649.95933468, 637.50800643, 625.05667818, 612.60534993, 600.15402168, 587.70269343, 575.25136518, 562.80003693] # see notebooks/nrel_battery_costs.ipynb for details
peak_load_day_2024 = [39.051, 39.051, 35.968, 33.913, 32.885, 32.885, 32.885, 36.996, 42.134, 46.245, 47.273, 48.300, 50.356, 51.383, 52.411, 54.466, 55.494, 58.577, 58.577, 56.522, 54.466, 52.411, 49.328, 46.245]
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
# diesel
price_per_l = 4/3.785    # in $/liter, about $4 per gallon, see https://www.eia.gov/petroleum/gasdiesel/
turbine_heat_rate = 10.4 # MJ/kWh at 90F, see https://s7d2.scene7.com/is/content/Caterpillar/CM20150703-52095-43744
diesel_LHV = 36          # MJ/liter, see https://www.engineeringtoolbox.com/fuels-higher-calorific-values-d_169.html

storage_lifetime = 20 # years
backup_lifetime = 20 # years
grid_lifetime = 40 # years

# adjust investment costs with discounted salvage value based on linear depreciation
function adjust_investment_cost(C::Vector{Float64}, L::Int64, r::Float64, salvage_value::Bool)
    N = length(C)
    cadj = zeros(N)
    for i in eachindex(C)
        cadj[i] = C[i] * (1/(1+r)^(i-1) - salvage_value * max(L - (N - i + 1), 0) / (L * (1+r)^N))  
    end
    return cadj
end

# return combustion turbine max ouput in MW, computed based on Figure 3.4 in PNNL report, turbine datasheet: https://s7d2.scene7.com/is/content/Caterpillar/CM20150703-52095-43744
# assumed to have a 20 year lifetime
function ctg_max_output(temp_in_F::Float64)
    return (-0.2362 * temp_in_F^2 - 20.027 * temp_in_F  + 16637)/1000
end
# --------------------------
# construct data dictionary
data = Dict(
    "planning periods" => N,
    "peak load (MW)" => peak_load_evolution/maximum(peak_load_day_2024) .* ones(26, 24) .* peak_load_day_2024',
    "storage existing capacity (MW)" => reshape(vcat(ones(15) * 6, zeros(11)), 1, :),
    "storage existing units (-)" => 1,
    "grid existing capacity (MW)" => hcat(vcat(ones(12) * 36, zeros(14)), vcat(ones(22)*38, zeros(4)))',
    "grid existing units (-)" => 2,
    "backup existing capacity (MW)" => reshape(vcat(ones(15) * ctg_max_output(90.), zeros(11)), 1, :),
    "backup existing units (-)" => 1,
    "backup capital cost (\$/MW)" => 1e6 * adjust_investment_cost(35.6/68.6 * 81 * consumer_price_index["2025"]/consumer_price_index["2019"] * ones(26), backup_lifetime, r, true), # see nrel_battery_costs.ipynb for details
    "storage capital cost (\$/MW)" => adjust_investment_cost(battery_costs_per_MW, storage_lifetime, r, true),
    "grid capital cost (\$/MW)" => 1e6 * adjust_investment_cost(5 * consumer_price_index["2025"]/consumer_price_index["2019"] * ones(26), grid_lifetime, r, true), # a 40MW line would have cost $200 million in 2019, see Nantucket press release
    "time discretization (h)" => 1.,
    "value of lost load (\$/MWh)" => 10000 .* (1 - r).^(0:(length(N)-1)), # preliminary, could be refined with actual ISONE data
    "storage lifetime (years)" => storage_lifetime,
    "storage min. investment (MW)" => 2,
    "storage max. investment (MW)" => 24.,
    "storage duration (h)" => storage_duration,
    "storage charging efficiency (-)" => 0.92,
    "storage discharging efficiency (-)" => 0.92,
    "grid lifetime (years)" => grid_lifetime,
    "grid min. investment (MW)" => 40.,
    "grid max. investment (MW)" => 40.,
    "backup lifetime (years)" => backup_lifetime,
    "backup min. investment (MW)" => 2.,
    "backup max. investment (MW)" => 30.,
    "backup electricity price (\$/MWh)" => (1000 * price_per_l / diesel_LHV * turbine_heat_rate) .* (1 - r).^(0:(length(N)-1)),
    "electricity peak load price (\$/MWh)" => [62.31, 71.83, 48.56, 35.36, 30.38, 32.18, 34.61, 40.13, 32.08, 29.59, 35.10, 45.30, 49.03, 46.26, 57.91, 64.44, 107.19, 65.80, 86.22, 54.13, 94.15, 47.81, 41.72, 46.61] .* (1 - r).^(0:(length(N)-1))',
    "probability-adjusted peak load days (-)" => ones(26,2) .* [30 1],
    "discount rate (-)" => r,
    "peak load evolution (MW)" => peak_load_evolution,
    "storage max. cycles per year (-)" => 150.
)

# write to JSON
write("data/nantucket.json", JSON3.write(data))
