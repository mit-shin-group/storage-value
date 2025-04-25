using JSON3

# --------------------------
# specify data and functions to construct the data dictionary
N = 2025:2050
r = 0.0  # - discount rate (-), PNNL assumed 0.0685
storage_duration = 8
battery_costs_per_MW = 1000 * storage_duration * [959.06052087, 929.39885527, 897.26538421, 867.60371862, 835.47024756, 805.80858196, 793.44955463, 781.0905273, 768.73149997, 756.37247264, 744.01344531, 731.65441798, 719.29539065, 706.93636332, 694.57733599, 682.21830866, 669.85928133, 657.500254  , 645.14122666, 632.78219933, 620.423172  , 608.06414467, 595.70511734, 583.34609001, 570.98706268, 558.62803535]
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
    "existing battery capacity (MW)" => reshape(vcat(ones(15) * 6, zeros(11)), 1, :),
    "number of existing batteries (-)" => 1,
    "existing line capacity (MW)" => hcat(vcat(ones(12) * 36, zeros(14)), vcat(ones(22)*38, zeros(4)))',
    "number of existing lines (-)" => 2,
    "existing backup capacity (MW)" => reshape(vcat(ones(15) * ctg_max_output(90.), zeros(11)), 1, :),
    "number of existing backup generators (-)" => 1,
    "backup capital cost (\$/MW)" => 1e6 * adjust_investment_cost(35.6/68.6 * 81 * 319.082/255.657 * ones(26), 20, r, true), 
    "battery capital cost (\$/MW)" => adjust_investment_cost(battery_costs_per_MW, 20, r, true),
    "line capital cost (\$/MW)" => 1e6 * adjust_investment_cost(5 * 319.082/255.657 * ones(26), 40, r, true),
    "time discretization (h)" => 1.,
    "value of lost load (\$/MWh)" => 2500. .* (1 - r).^(0:(length(N)-1)),
    "battery lifetime (years)" => 20,
    "battery min. investment (MW)" => 2,
    "battery max. investment (MW)" => 24.,
    "battery duration (h)" => storage_duration,
    "battery charging efficiency (-)" => 0.92,
    "battery discharging efficiency (-)" => 0.92,
    "cable lifetime (years)" => 40,
    "cable min. investment (MW)" => 40.,
    "cable max. investment (MW)" => 40.,
    "backup lifetime (years)" => 20,
    "backup min. investment (MW)" => 2.,
    "backup max. investment (MW)" => 30.,
    "backup electricity price (\$/MWh)" => (1000 * price_per_l / diesel_LHV * turbine_heat_rate) .* (1 - r).^(0:(length(N)-1)),
    "electricity peak load price (\$/MWh)" => [62.31, 71.83, 48.56, 35.36, 30.38, 32.18, 34.61, 40.13, 32.08, 29.59, 35.10, 45.30, 49.03, 46.26, 57.91, 64.44, 107.19, 65.80, 86.22, 54.13, 94.15, 47.81, 41.72, 46.61] .* (1 - r).^(0:(length(N)-1))',
    "probability-adjusted peak load days (-)" => ones(26,2) .* [30 1],
    "discount rate (-)" => r
)

# write to JSON
write("data/nantucket.json", JSON3.write(data))
