using JSON3

# --------------------------
# specify data and functions to construct the data dictionary
# for investment costs (https://www.rateinflation.com/consumer-price-index/usa-historical-cpi/)
consumer_price_index = Dict("2025" => 323.048, "2022" => 292.655, "2020" => 258.811, "2019" => 255.657, "2018" => 251.107) 
N = 2025:2050
r = 0.0  # - discount rate (-), PNNL assumed 0.0685
storage_duration = 8
battery_costs_per_MW = 1000 * storage_duration * [813.32630135, 780.38785301, 762.65176544, 742.38195108, 724.64586351, 706.90977594, 689.17368837, 671.4376008, 651.16778644, 633.43169887, 615.6956113 , 605.56070412, 592.89207014, 582.75716296, 572.62225578, 559.9536218, 549.81871462, 539.68380744, 529.54890026, 516.88026628, 506.7453591 , 496.61045192, 483.94181794, 473.80691076, 463.67200357, 451.0033696] # see notebooks/nrel_battery_costs.ipynb for details
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
] # National Grid Electric Sector Modernization Plan, p. 62, https://www.nationalgridus.com/media/pdfs/our-company/massachusetts-grid-modernization/future-grid-full-plan.pdf

# capacity payments, see https://www.iso-ne.com/markets-operations/markets/forward-capacity-market/, half-yearly resolution starting in 2025, forecast from mid 2028 on
capacity_price =
[
3.980,
2.639,
2.639,
2.590,
2.590,
3.580,
3.580,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064,
3.064
]
# transform capacity prices into yearly resolution, they last from Jan through May (151 days excluding leap years) and from Jun through December (214 days excluding leap years), and transform from $/kW-month to $/MW-year
capacity_price = 12 * 1000 * [151/365 * capacity_price[2 * i - 1] + 214/365 * capacity_price[2*i] for i in 1:length(capacity_price) ÷ 2]

# diesel
price_per_l = 4/3.785    # in $/liter, about $4 per gallon, see https://www.eia.gov/petroleum/gasdiesel/
turbine_heat_rate = 10.4 # MJ/kWh at 90F, see https://s7d2.scene7.com/is/content/Caterpillar/CM20150703-52095-43744
diesel_LHV = 36          # MJ/liter, see https://www.engineeringtoolbox.com/fuels-higher-calorific-values-d_169.html
diesel_operating_temperature = 90.0 # F (worst-case assumption for Nantucket)

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
    "storage existing capacity (MW)" => reshape(vcat(ones(15) * 6, zeros(11)), 1, :),
    "grid existing capacity (MW)" => hcat(vcat(ones(12) * 36, zeros(14)), vcat(ones(22)*38, zeros(4)))',
    "backup existing capacity (MW)" => reshape(vcat(ones(15) * ctg_max_output(diesel_operating_temperature), zeros(11)), 1, :),
    "backup capital cost (\$/MW)" => 1e6 * adjust_investment_cost(35.6/68.6 * 81/ctg_max_output(diesel_operating_temperature) * consumer_price_index["2025"]/consumer_price_index["2019"] * ones(26), backup_lifetime, r, true), # see nrel_battery_costs.ipynb for details
    "storage capital cost (\$/MW)" => adjust_investment_cost(battery_costs_per_MW, storage_lifetime, r, true),
    "grid capital cost (\$/MW)" => 1e6 * adjust_investment_cost(5 * consumer_price_index["2025"]/consumer_price_index["2019"] * ones(26), grid_lifetime, r, true), # a 40MW line would have cost $200 million in 2019, see Nantucket press release
    "time discretization (h)" => 1.,
    "value of lost load (\$/MWh)" => 9337 .* (1 - r).^(0:(length(N)-1)), # does not matter if load shedding is disallowed, none of our experiments allow for it
    "storage lifetime (years)" => storage_lifetime,
    "storage min. investment (MW)" => 2,
    "storage max. investment (MW)" => 24.,
    "storage duration (h)" => storage_duration,
    "storage charging efficiency (-)" => 0.913,
    "storage discharging efficiency (-)" => 0.913,
    "grid lifetime (years)" => grid_lifetime,
    "grid min. investment (MW)" => 40.,
    "grid max. investment (MW)" => 40.,
    "backup lifetime (years)" => backup_lifetime,
    "backup min. investment (MW)" => 2.,
    "backup max. investment (MW)" => 30.,
    "backup electricity price (\$/MWh)" => (1000 * price_per_l / diesel_LHV * turbine_heat_rate) .* (1 - r).^(0:(length(N)-1)),
    "discount rate (-)" => r,
    "peak load evolution (MW)" => peak_load_evolution,
    "capacity price (\$/MW-year)" => capacity_price
)

# write to JSON
write("data/nantucket.json", JSON3.write(data))