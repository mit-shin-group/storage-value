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
end

function build_model(data::Data)
  @unpack K, x̅, ℓ, c = data
  PM = Model(Gurobi.Optimizer)
  # add variables
  @variable(PM, z[K], Bin)
  # constraints
  @constraint(PM, [k in K], x̅ * sum(z[l] for l = K[begin]:k) - ℓ[k - K[begin] + 1] >= 0)
  # objective function
  @objective(PM, Min, sum(z .* c))
  # return
  return PM
end

function solve_model(data::Data = Data())
  PM = build_model(data)
  optimize!(PM)
  return PM
end

function analyze_solution(PM, data::Data = Data())
  @unpack K, ℓ, c, x̅ = data
  z = Array(value.(PM[:z]))
  results = DataFrame(year=collect(K), 
                      z=z,
                      margin= x̅ * cumsum(z) .- ℓ,
                      cumcost = cumsum(z .* c)
                      )
  return results
end