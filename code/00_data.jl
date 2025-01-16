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