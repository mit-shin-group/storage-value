using Parameters, JuMP, JSON3, Dates, Statistics, CSV, DataFrames

function n̲(n, Nr; N = 1:25)
    return max(first(N), n - Nr + 1)
end

# Market participation types
@enum Market full no_exports limited_backup peak_shaving 

function read_data(file_path)
    open(file_path) do io
        data = JSON3.read(io)
        return data
    end
end

@with_kw struct CaseDataPlan
    # Index Sets
    # - Supply resource types
    R::Vector{String}
    # - Existing resources
    I::Dict{String, UnitRange{Int64}}
    # - Demand resource types
    D::Vector{String}
    # - Planning periods
    N::UnitRange{Int64}
    # - Operating periods
    K::UnitRange{Int64}
    # - Contingencies
    C::UnitRange{Int64}
    # Lifetimes
    Nr::Dict{String, Int64}
    # Operating period duration/probability
    T::Containers.DenseAxisArray{}
    # - initial resources
    # Investment costs
    p::Containers.DenseAxisArray{}
    c0::Containers.DenseAxisArray{}
    # Operating costs
    ps::Containers.DenseAxisArray{}
    pd::Containers.DenseAxisArray{}
    # Initial capacities
    x0::Containers.SparseAxisArray{}
    # Investment ranges
    x̲::Dict{String, Float64}
    x̄::Dict{String, Float64}
    # Load
    ȳℓ::Containers.DenseAxisArray{}
    # Time discretization (hours)
    Δt::Float64
    # Charging and discharging efficiencies
    ηc::Float64 
    ηd::Float64
    # Storage duration
    Ts::Float64
    # Max number of storage cycles per planning period
    Cs::Float64
    # Market participation
    market::Market
    # Discount rate
    r::Float64
    # Gurobi parameters
    grb_silent::Bool
end

@with_kw struct CaseDataOps
    # Index Sets
    # - Supply resource types
    R::Vector{String}
    # - Demand resource types
    D::Vector{String}
    # - Operating periods
    K::UnitRange{Int64}
    # Operating costs
    ps::Containers.DenseAxisArray{}
    pd::Containers.DenseAxisArray{}
    # Load
    ȳℓ::Containers.DenseAxisArray{}
    # Time discretization (hours)
    Δt::Float64
    # Charging and discharging efficiencies
    ηc::Float64
    ηd::Float64
    # Storage duration
    Ts::Float64
    # Max number of storage cycles per planning period
    Cs::Float64
    # Market participation
    market::Market
    # Investment decisions
    xtot::Containers.DenseAxisArray{}
    # Initial state-of-charge (ratio)
    y0::Union{Float64, Nothing}
    # Allow for load schedding
    load_shedding::Bool
    # Gurobi parameters
    grb_silent::Bool
end

function build_data_plan(; date::String = "peak", market::Market = full, grb_silent::Bool = true, Cs = 150.)
    # - planning horizon
    N = 2025:2050
    # - contingency set
    C = 0:1
    # read general parameters
    file_path = "data/nantucket.json"
    file_data = read_data(file_path)
    # read timeseries parameters
    data_file = "data/Nantucket_2024.csv"
    yearly_data = CSV.read(data_file, DataFrame)
    # specify resources
    R = ["b", "g", "s"]
    D = ["g", "ℓ", "s"]
    I = Dict(r => i for (r,i) in zip(R, [1:1, 1:2, 1:1]))
    # date-independent parameters
    pb = file_data["backup electricity price (\$/MWh)"]
    pℓ = file_data["value of lost load (\$/MWh)"]
    discount_rate = file_data["discount rate (-)"]
    # - existing capacity
    x0 = Containers.@container([r in R, n in N, i in I[r]], 
        if r == "b"
            reshape(file_data["existing backup capacity (MW)"], Int(length(file_data["existing backup capacity (MW)"])/26), 26)[i, n̲(n, first(N))]
        elseif r == "g"
            reshape(file_data["existing line capacity (MW)"], Int(length(file_data["existing line capacity (MW)"])/26), 26)[i, n̲(n, first(N))]
        elseif r == "s"
            reshape(file_data["existing battery capacity (MW)"], Int(length(file_data["existing battery capacity (MW)"])/26), 26)[i, n̲(n, first(N))]
        end
    )
    # - investment ranges
    x̲ = Dict("b" => file_data["backup min. investment (MW)"],
            "g" => file_data["cable min. investment (MW)"],
            "s" => file_data["battery min. investment (MW)"])
    x̄ = Dict("b" => file_data["backup max. investment (MW)"],
            "g" => file_data["cable max. investment (MW)"],
            "s" => file_data["battery max. investment (MW)"])   
    # - investment cost
    p = Containers.@container([r in R, n in N], 
        if r == "b"
            file_data["battery capital cost (\$/MW)"][n̲(n, first(N))]
        elseif r == "g"
            file_data["backup capital cost (\$/MW)"][n̲(n, first(N))]
        else
            file_data["line capital cost (\$/MW)"][n̲(n, first(N))]
        end
    )
    c0 = Containers.@container([r in R, n in N], 0)
    # - investment lifetime
    Nr = Dict("b" => file_data["backup lifetime (years)"], 
            "g" => file_data["cable lifetime (years)"], 
            "s" => file_data["battery lifetime (years)"])
    # - time discretization (hours)
    Δt = file_data["time discretization (h)"]    
    # - charging and discharging efficiencies
    ηc = file_data["battery charging efficiency (-)"]
    ηd = file_data["battery discharging efficiency (-)"]
    # - storage duration
    Ts = file_data["battery duration (h)"]
    # - max number of storage cycles per planning period
    Cs = Cs
    # date-dependent parameters
    if date == "peak"
        # based on the N days with highest load in the reference year and on load growth projection
        K = 1:24
        N_days = 5
        top_days = sort(combine(groupby(yearly_data, :Day), :"MW Factor" => maximum => :PeakLoad), :PeakLoad, rev=true)[1:N_days, :Day]
        peak_day = combine(groupby(filter(row -> row.Day in top_days, yearly_data), :Hour), 
        :"MW Factor" => maximum => :Load,
        :"Price" => mean => :Price
        )
        # linear scaling for load evolution
        ȳℓ = Containers.@container([n in N, k in K], peak_day[!, :Load][k] * file_data["peak load evolution (MW)"][n̲(n, first(N))]/maximum(peak_day[!, :Load]))
        # price of grid electricity
        pg = peak_day[!, :Price]
        # probability-adjusted peak load days
        T = Containers.@container([n in N, c in C],
            if c == 0.
                (15:40)[n̲(n, first(N))]
            else
                (0.2 * (15:40))[n̲(n, first(N))]
            end
        )   
    elseif date == "year"
        K = 1:nrow(yearly_data)
        ȳℓ = Containers.@container([n in N, k in K], yearly_data[!, "MW Factor"][k] * file_data["peak load evolution (MW)"][n̲(n, first(N))]/maximum(yearly_data[!, "MW Factor"]))
        pg = yearly_data[!, "Price"]
        T = Containers.@container([n in N, c in C],
            if c == 0.
                1
            else
                0.2
            end
        )
    end
    # - overall operational prices
    ps = Containers.@container([r in R, n in N, k in K], 
        if r == "g"
            pg[k] * (1 - discount_rate)^(n - first(N))
        elseif r == "b"
            pb[n̲(n, first(N))]
        else
            0.
        end
    )
    pd = Containers.@container([r in D, n in N, k in K], 
        if r == "g"
            pg[k] * (1 - discount_rate)^(n - first(N))
        elseif r == "ℓ"
            pℓ[n̲(n, first(N))]
        else
            0.
        end
    )
    # fill case_data
    return CaseDataPlan(
        R = R, I = I, D = D, N = N, K = K, C = C, Nr = Nr, T = T,
        p = p, c0 = c0, ps = ps, pd = pd, x0 = x0, x̲ = x̲, x̄ = x̄,
        ȳℓ = ȳℓ, Δt = Δt, ηc = ηc, ηd = ηd, Ts = Ts, Cs = Cs,
        market = market, r = discount_rate, grb_silent = grb_silent
    )
end

function build_data_ops(; date::String = "peak", 
    market::Market = full,
    xtot::Containers.DenseAxisArray=Containers.DenseAxisArray([12.921, 74.000, 6.000], ["b", "g", "s"]),
    y0::Union{Nothing, Float64} = nothing,
    load_shedding::Bool = true,
    grb_silent::Bool = true,
    Cs::Float64 = 150.
    )
    # read general parameters
    file_path = "data/nantucket.json"
    file_data = read_data(file_path)
    # read timeseries parameters
    data_file = "data/Nantucket_2024.csv"
    yearly_data = CSV.read(data_file, DataFrame)
    # specify resources
    R = ["b", "g", "s"]
    D = ["g", "ℓ", "s"]
    # date-independent parameters
    pb = file_data["backup electricity price (\$/MWh)"][1]
    pℓ = file_data["value of lost load (\$/MWh)"][1]
    # - time discretization (hours)
    Δt = file_data["time discretization (h)"]    
    # - charging and discharging efficiencies
    ηc = file_data["battery charging efficiency (-)"]
    ηd = file_data["battery discharging efficiency (-)"]
    # - storage duration
    Ts = file_data["battery duration (h)"]
    # - max number of storage cycles per planning period
    Cs = Cs
    # date-dependent parameters
    if date == "peak"
        # based on the N days with highest load in that year, not on load growth projection
        K = 1:24
        N_days = 5
        top_days = sort(combine(groupby(yearly_data, :Day), :"MW Factor" => maximum => :PeakLoad), :PeakLoad, rev=true)[1:N_days, :Day]
        peak_day = combine(groupby(filter(row -> row.Day in top_days, yearly_data), :Hour), 
        :"MW Factor" => maximum => :Load,
        :"Price" => mean => :Price
        )
        ȳℓ = Containers.@container([k in K], peak_day[!, :Load][k])
        pg = peak_day[!, :Price]
    elseif date == "year"
        K = 1:nrow(yearly_data)
        ȳℓ = Containers.@container([k in K], yearly_data[!, "MW Factor"][k])
        pg = yearly_data[!, "Price"]
    else
        date_data = filter(row -> row.Day == Date(date, dateformat"yyyy-mm-dd"), yearly_data)
        K = 1:nrow(date_data)
        ȳℓ = Containers.@container([k in K], date_data[!, "MW Factor"][k])
        pg = date_data[!, "Price"]
    end
    # overall operating costs
    ps = Containers.@container([r in R, k in K], 
        if r == "g"
            pg[k]
        elseif r == "b"
            pb
        else
            0.
        end
    )
    pd = Containers.@container([r in D, k in K], 
        if r == "g"
            pg[k]
        elseif r == "ℓ"
            pℓ
        else
            0.
        end
    )
    return CaseDataOps(
        R = R, D = D, K = K, ps = ps, pd = pd, ȳℓ = ȳℓ,
        Δt = Δt, ηc = ηc, ηd = ηd, Ts = Ts, Cs = Cs,
        market = market, xtot = xtot, y0 = y0,
        load_shedding = load_shedding, grb_silent = grb_silent
    )
end