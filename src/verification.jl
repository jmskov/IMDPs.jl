"""
    bounded_until

Perform verification of a bounded-until property indicated by phi1 U phi2 within k steps (k = -1 is infinite horizon)
"""
function bounded_until(imdp::IMDP, phi1::Union{Nothing,String}, phi2::String, 
                      k::Int, result_dir::String, filename::String; synthesis_flag=false)

    # Convert labels dictionary to an array 
    labels_vector = Array{String}(undef, length(imdp.states))
    labels_vector .= ""
    for label_key in keys(imdp.labels)
        labels_vector[label_key] = imdp.labels[label_key]
    end
    
    # Get the Qyes and Qno states
    acc_states = findall(x->x==phi2, labels_vector)
    sink_states = isnothing(phi1) ? [] : findall(x->!(x==phi1 || x==phi2), labels_vector)

    # Write the IMDP to file 
    imdp_filename = "$result_dir/$filename-IMDP.txt"
    write(imdp_filename, imdp, acc_states=acc_states, sink_states=sink_states)
    mode1 = synthesis_flag ? "maximize" : "minimize"
    result_mat = run_imdp_synthesis(imdp_filename, k; mode1=mode1, mode2="pessimistic", tag=filename)

    return result_mat 
end

"""
    globally

Perform verification of a global property indicated by phi for k steps (k = -1 is infinite horizon)
"""
function globally(imdp::IMDP, phi::String, k::Int, results_dir::String, filename::String; synthesis_flag=false)

    phi1 = nothing
    phi2 = "!$phi"

    result_mat = bounded_until(imdp, phi1, phi2, k, results_dir, filename, synthesis_flag=synthesis_flag)
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
function run_imdp_synthesis(imdp_file, k; mode1="maximize", mode2="pessimistic", tag=nothing)
    exe_path = "/usr/local/bin/synthesis"  # Assumes that this program is on the user's path
    @assert isfile(imdp_file)
    # TODO: Julia implementation on this tool
    # TODO: Or a way to use it without explicitly saving the IMDP
    res = read(`$exe_path $mode1 $mode2 $k 0.000001 $imdp_file`, String)
    dst_dir = dirname(imdp_file)
    result_name = isnothing(tag) ? "verification-result" : "$tag-result"
    open("$dst_dir/$result_name-$k.txt", "w") do f
        print(f, res) 
    end
    res_mat = res_to_numbers(res)
    return res_mat
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