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
    create_imdp

Create an IMDP with multiple modes and add labels to states from a specification file.
"""
function create_imdp(P̌_array, P̂_array, specification_filename::String, state_means)
    imdp = IMDPs.create_imdp(P̌_array, P̂_array)
    lbl, _, _, _, _, _ = IMDPs.load_PCTL_specification(specification_filename)
    create_imdp_labels(lbl, imdp, state_means)
    return imdp
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

"""
    create_imdp_labels

Label each state of an IMDP with states in continous space using a label function.
"""
function create_imdp_labels(labels_fn, imdp, all_state_means)
    for i = eachindex(all_state_means) 
        imdp.labels[i] = labels_fn(all_state_means[i])
    end
    imdp.labels[length(imdp.states)] = labels_fn(nothing, unsafe=true)
end

"""
    is_point_in_rectangle

Checks whether the given point is inside the hyperrectangle.
"""
function is_point_in_rectangle(pt, rectangle)
	dim = length(pt)
	# Format of rectange: [lowers, uppers]
	res = true
	for i=1:dim
		res = rectangle[i] <= pt[i] <= rectangle[i+dim]
		if !res 
			return false
		end
	end
	return true
end
