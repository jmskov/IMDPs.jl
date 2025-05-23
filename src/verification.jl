"""
    pctl_verification

Given an IMDP and labels, performs PCTL verification.
"""
function pctl_verification(imdp::IMDP, phi1::Union{Nothing,String}, phi2::String, 
    k::Int, result_dir::String, spec_name::String; synthesis_flag=false)

    if isnothing(phi1) 
        @info "Performing $k-step global PCTL verification: G^[$k] $phi2" 
        result_mat = globally(imdp, phi2, k, result_dir, spec_name; synthesis_flag=synthesis_flag)
    else
        @info "Performing bounded-until PCTL verification: $phi1 U^[$k] $phi2"
        result_mat = bounded_until(imdp, phi1, phi2, k, result_dir, spec_name; synthesis_flag=synthesis_flag)
    end
    return result_mat
end

"""
    pctl_verification

Given the components to create an IMDP and a specification with labels, perform PCTL verificaion.
"""
function pctl_verification(P̌_array, P̂_array, specification_filename::String, state_means, results_dir::String)
    imdp = create_imdp(P̌_array, P̂_array, specification_filename::String, state_means)
    _, _, ϕ1, ϕ2, steps, spec_name = IMDPs.load_PCTL_specification(specification_filename)
    result_matrix = IMDPs.pctl_verification(imdp, ϕ1, ϕ2, steps, results_dir, spec_name)
    return result_matrix
end

"""
    bounded_until

Perform verification of a bounded-until property indicated by phi1 U phi2 within k steps (k = -1 is infinite horizon)
"""
function bounded_until(imdp::IMDP, phi1::Union{Nothing,String}, phi2::String, 
                      k::Int, result_dir::String, spec_name::String; synthesis_flag=false, Qyes=[])

    # Convert labels dictionary to an array 
    labels_vector = Array{String}(undef, length(imdp.states))
    labels_vector .= ""
    for label_key in keys(imdp.labels)
        labels_vector[label_key] = imdp.labels[label_key]
    end
    
    # Get the Qyes and Qno states
    acc_states = findall(x->x==phi2, labels_vector)

    sink_states = isnothing(phi1) ? [] : findall(x->!(x==phi1 || x==phi2), labels_vector)

    if !isempty(Qyes)
        # Define sink states differently
        all_states = collect(1:length(labels_vector))
        good_idxs = sort(acc_states ∪ Qyes)
        sink_states = deleteat!(all_states, good_idxs)
    end

    # Write the IMDP to file 
    imdp_filename = "$result_dir/$spec_name-IMDP.txt"
    write(imdp_filename, imdp, acc_states=acc_states, sink_states=sink_states)
    mode1 = synthesis_flag ? "maximize" : "minimize"

    globally_flag = isnothing(phi1)
    if synthesis_flag
        result_mat = optimistic_synthesis(imdp_filename, k; tag=spec_name, globally_flag=globally_flag)
    else
        result_mat = run_imdp_synthesis(imdp_filename, k; mode1="minimize", mode2="pessimistic", tag=spec_name)
    end

    return result_mat 
end

"""
    globally

Perform verification of a global property indicated by phi for k steps (k = -1 is infinite horizon)
"""
function globally(imdp::IMDP, phi::String, k::Int, results_dir::String, spec_name::String; synthesis_flag=false)

    phi1 = nothing
    phi2 = "!$phi"

    result_mat = bounded_until(imdp, phi1, phi2, k, results_dir, spec_name, synthesis_flag=synthesis_flag)
    safety_result_mat = zeros(size(result_mat))
    safety_result_mat[:, 1] = result_mat[:, 1]
    safety_result_mat[:, 2] = result_mat[:, 2]
    safety_result_mat[:, 3] = 1 .- result_mat[:, 4]
    safety_result_mat[:, 4] = 1 .- result_mat[:, 3]
    return safety_result_mat
end


""" 
    run_imdp_synthesis

Call the bounded MDP synthesis tool with the given inputs. 

- imdpfile::String -- location of the IMDP file
- k::Int -- synthesis horizon
- mode1::String -- either "minimize" or "maximize" 
- mode2::String -- either "pessimistic" or "optimistic"
"""
function run_imdp_synthesis(imdp_file, horizon; mode1="maximize", mode2="pessimistic", tag=nothing)
    exe_path = "/usr/local/bin/synthesis"  # Assumes that this program is on the user's path
    @assert isfile(imdp_file)
    # TODO: Julia implementation on this tool
    # TODO: Or a way to use it without explicitly saving the IMDP
    res = read(`$exe_path $mode1 $mode2 $horizon 0.000001 $imdp_file`, String)
    dst_dir = dirname(imdp_file)
    result_name = isnothing(tag) ? "$dst_dir/verification-$mode1-$mode2-$horizon-result.txt" : "$dst_dir/$tag-$mode1-$mode2-$horizon-result.txt"
    save_result_mat(result_name, res)
    res_mat = res_to_numbers(res)
    return res_mat
end

"""
Run optimistic IMDP syntheis, both on the LB and UB
"""
function optimistic_synthesis(imdp_file, horizon; tag=nothing, globally_flag=false)
    res_mat = run_imdp_synthesis(imdp_file, horizon, tag=tag)
    res_mat_opt = run_imdp_synthesis(imdp_file, horizon, mode2="optimistic", tag=tag)

    if globally_flag
        for j in 1:length(res_mat[:,1])
            if res_mat[j, 4] == res_mat_opt[j, 4] && res_mat_opt[j,3] < res_mat[j,3] 
                res_mat[j, 2] = res_mat_opt[j, 2]
                res_mat[j, 3] = res_mat_opt[j, 3] 
            end
        end
    else
        for j in 1:length(res_mat[:,1])
            if res_mat[j, 3] == res_mat_opt[j, 3] && res_mat_opt[j,4] > res_mat[j,4] 
                res_mat[j, 2] = res_mat_opt[j, 2]
                res_mat[j, 4] = res_mat_opt[j, 4] 
            end
        end
    end

    dst_dir = dirname(imdp_file)
    result_name = isnothing(tag) ? "$dst_dir/verification-all-opt-$horizon-result.txt" : "$dst_dir/$tag-all-opt-$horizon-result.txt"
    save_result_mat_string(result_name, res_mat)
    
    return res_mat
end

function save_result_mat(filename, res_mat)
    open(filename, "w") do f
        print(f, res_mat) 
    end
end

function save_result_mat_string(filename, res_mat)
    open(filename, "w") do f
        for i=1:size(res_mat,1)
            @printf(f, "%d %d %f %f\n", i-1, res_mat[i,2]-1, res_mat[i,3], res_mat[i,4])
        end
    end 
end

# Creates a matrix from the string output of the BMDP synthesis tool.
function res_to_numbers(res_string)
    filter_res = replace(res_string, "\n"=>" ")
    res_split = split(filter_res)
    num_rows = Int(length(res_split)/4)

    res_mat = zeros(num_rows, 4)
    for i=1:num_rows
        res_mat[i, 1] = parse(Int, res_split[(i-1)*4+1])+1.
        res_mat[i, 2] = parse(Int, res_split[(i-1)*4+2])+1.
        res_mat[i, 3] = parse(Float64, res_split[(i-1)*4+3])
        res_mat[i, 4] = parse(Float64, res_split[(i-1)*4+4])
    end

    return res_mat
end

function load_result(filename; globally_safe=false)
    f = open(filename)
    res_string = read(f, String)
    res_mat = res_to_numbers(res_string)

    if globally_safe
        safety_result_mat = copy(res_mat)
        safety_result_mat[:, 3] = 1 .- res_mat[:, 4]
        safety_result_mat[:, 4] = 1 .- res_mat[:, 3]
        res_mat = safety_result_mat
    end

    return res_mat
end