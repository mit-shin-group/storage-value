using Parameters

@with_kw struct CaseDataBO
    Δt::Float64 = 1.
    p̄::Float64 = 10.
    p::Vector{Float64} = [1., 1., 1.]
    ℓ::Vector{Float64} = [1., 2., 1.]
    ℓ̄::Float64 = 1.5
    x̄::Float64 = 1.
    x̲::Float64 = -1.
    ȳ::Float64 = 8.
    y0::Union{Nothing, Float64} = nothing
    ηc::Float64 = 0.92
    ηd::Float64 = 0.92
end

@with_kw struct CaseData
    Nb::Int64 = 1
    Nℓ::Int64 = 2
    l̄0::Vector{Float64} = [0., 0.]
    x̄b0::Vector{Float64} = [0., 0.]
    pb::Vector{Float64} = [1., 1.]
    pℓ::Vector{Float64} = [0.5, 0.5]
    x̲ℓ::Float64 = 2.
    x̄ℓ::Float64 = 2.
    x̲b::Float64 = 0.
    x̄b::Float64 = 2.
    p̄::Float64 = 10.
    p::Matrix{Float64} = ones(2,3)
    ℓ::Matrix{Float64} = [[1., 2., 1.], [1.25, 2.5, 1.25]]
    ηc::Float64 = 0.92
    ηd::Float64 = 0.92
    T::Vector{Float64} = 1/length(p[1])
    Ts::Float64 = 8.
    Δt::Float64 = 1.
end

@with_kw struct CaseDataN1
    Nb::Int64 = 1
    Nℓ::Int64 = 2
    Ng::Int64 = 2
    l̄0::Matrix{Float64} =[0. 0.; 1. 0.]       # dim1: units, dim2: planning periods
    x̄b0::Matrix{Float64} = [0. 0.; 1. 0.]     # dim1: units, dim2: planning periods
    x̄g0::Matrix{Float64} = [0. 0.; 1. 0.]     # dim1: units, dim2: planning periods
    pb::Vector{Float64} = [1., 1.]
    pℓ::Vector{Float64} = [0.5, 0.5]
    pg::Vector{Float64} = [0.25, 0.25]
    x̲ℓ::Float64 = 2.
    x̄ℓ::Float64 = 2.
    x̲b::Float64 = 0.
    x̄b::Float64 = 2.
    x̲g::Float64 = 0.
    x̄g::Float64 = 15.
    p̄::Float64 = 10.
    p̄g::Float64 = 5.
    p::Matrix{Float64} = ones(2,3)  # dim1: planning periods, dim2: operating periods
    ℓ::Matrix{Float64} = [1. 2. 1.; 1.25 2.5 1.25] # dim1: planning periods, dim2: operating periods
    ηc::Float64 = 0.92
    ηd::Float64 = 0.92
    T::Matrix{Float64} = [1/size(p, 2) * ones(size(p,1)) 1/size(p, 2) * ones(size(p,1))] # dim1: planning periods, dim2: contingency case
    Ts::Float64 = 8.
    Δt::Float64 = 1.
end