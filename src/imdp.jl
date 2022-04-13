# IMDP definitions and functions
abstract type IMDP end

"""
    SystemIMDP(states, actions, P̌, P̂, labels)
Structure of interval MDP components.

    - states::UnitRange{Int64} -- IMDP states
    - actions: IMDP actions
    - P̌: transition interval lower-bounds
    - P̂: transition interval upper-bounds 
    - labels: IMDP state labels
"""
struct SystemIMDP <: IMDP
    states::UnitRange{Int64}
    actions::UnitRange{Int64}
    P̌
    P̂
    labels::Dict{Int, Any}
end

"""
    create_imdp

Create an IMDP with multiple modes from an array of transition matrices
"""
function create_imdp(P̌_array, P̂_array)
    num_modes = length(P̌_array)
    mat_size = size(P̌_array[1], 1)
    P̌_full = spzeros(mat_size*num_modes, mat_size)
    P̂_full = spzeros(mat_size*num_modes, mat_size)

    for i=1:num_modes
        P̌_full[i:num_modes:end, :] = P̌_array[i]
        P̂_full[i:num_modes:end, :] = P̂_array[i]
    end

    return SystemIMDP(1:mat_size, 1:num_modes, P̌_full, P̂_full, Dict())
end

"""
    validate(imdp::IMDP)

Validate that the IMDP transition intervals are in expected ranges.
"""
function validate(imdp::IMDP)
    for (minrow, maxrow) in zip(eachrow(imdp.P̌), eachrow(imdp.P̂))
        @assert sum(maxrow) >= 1
        @assert sum(minrow) <= 1
    end
end

