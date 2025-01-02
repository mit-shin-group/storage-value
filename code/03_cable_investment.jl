using Parameters, JuMP, Gurobi, DataFrames

@with_kw struct Data
  K::UnitRange{Int64} = 2019:2050
  x̅::Float64 = 40.
  ℓ::Vector{Float64} = [
    -43.272,
    -39.058,
    -38.866,
    -35.802,
    -34.844,
    -33.311,
    -32.545,
    -31.013,
    -29.672,
    -28.331,
    -26.798,
    -24.883,
    -23.350,
    -21.818,
    -19.902,
    -17.987,
    -16.071,
    -14.347,
     23.377,
     25.292,
     27.208,
     35.123,
     36.273,
     37.805,
     38.955,
     40.104,
     40.870,
     42.020,
     80.786,
     81.744,
     82.318,
     83.084]
  c::Vector{Float64} = [
    160,
    155,
    150,
    145,
    140,
    135,
    130,
    125,
    120,
    115,
    110,
    105,
    100,
     95,
     90,
     85,
     80,
     75,
     70,
     65,
     60,
     55,
     50,
     45,
     40,
     35,
     30,
     25,
     20,
     15,
     10,
      5]
  xsea::Vector{Float64} = [
    74.000,
    74.000,
    74.000,
    74.000,
    74.000,
    74.000,
    74.000,
    74.000,
    74.000,
    74.000,
    74.000,
    74.000,
    74.000,
    74.000,
    74.000,
    74.000,
    74.000,
    74.000,
    38.000,
    38.000,
    38.000,
    38.000,
    38.000,
    38.000,
    38.000,
    38.000,
    38.000,
    38.000,
     0.000,
     0.000,
     0.000,
     0.000]
  xseamin::Float64 = 70.
  Lbat::Int64 = 20
  pbat::Vector{Float64} = [
    12.00,
    11.68,
    11.35,
    11.03,
    10.71,
    10.39,
    10.06,
     9.74,
     9.42,
     9.10,
     8.77,
     8.45,
     8.13,
     7.42,
     6.74,
     6.09,
     5.47,
     4.89,
     4.34,
     3.82,
     3.33,
     2.87,
     2.45,
     2.06,
     1.70,
     1.38,
     1.08,
     0.82,
     0.59,
     0.40,
     0.23,
     0.10]
end

function build_model(data::Data)
  @unpack K, x̅, ℓ, c, xsea, xseamin, Lbat, pbat = data
  xbatmax = 100
  xbatmin = 1
  PM = Model(Gurobi.Optimizer)
  # add variables
  @variable(PM, z[K], Bin)
  @variable(PM, zbat[K], Bin)
  @variable(PM, xbat[K] >= 0)
  # constraints
  # - peak power
  @constraint(PM, [k in K], x̅ * sum(z[l] for l = K[begin]:k) + sum(xbat[l] for l = max(K[begin], k - Lbat + 1) : k) - ℓ[k - K[begin] + 1] >= 0)
  # - subsea connection
  @constraint(PM, [k in K], x̅ * sum(z[l] for l = K[begin]:k) + xsea[k - K[begin] + 1] >= xseamin)
  # - minimum battery investment
  @constraint(PM, [k in K], xbat[k] <= zbat[k] * xbatmax)
  @constraint(PM, [k in K], xbat[k] >= zbat[k] * xbatmin)
  # objective function
  @objective(PM, Min, sum(z .* c .+ xbat .* pbat))
  # return
  return PM
end

function solve_model(data::Data = Data())
  PM = build_model(data)
  optimize!(PM)
  return PM
end

function analyze_solution(PM, data::Data = Data())
  @unpack K, ℓ, c, x̅, xsea, pbat, Lbat = data
  z = Array(value.(PM[:z]))
  xbat = Array(value.(PM[:xbat]))
  xbatcum = [sum(xbat[l - K[begin] + 1] for l = max(K[begin], k - Lbat + 1) : k) for k in K]
  results = DataFrame(year=collect(K), 
                      z=z,
                      xbat = xbat,
                      margin= x̅ * cumsum(z) .+ xbatcum .- ℓ,
                      cumcost = cumsum(z .* c .+ xbat .* pbat),
                      xsea = x̅ * cumsum(z) .+ xsea,
                      xbatcum = xbatcum
                      )
  return results
end