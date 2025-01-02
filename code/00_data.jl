using Parameters

@with_kw struct CaseData
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