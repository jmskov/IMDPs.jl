# PIMDP definition

# > PIMDP is just an IMDP, so don't need a new definition. If I want to match old stuff, create more informative structs

"""
    SystemProductIMDP(states, actions, P̌, P̂, labels)
Structure of interval MDP components.

    - states::UnitRange{Int64} -- IMDP states
    - actions: IMDP actions
    - P̌: transition interval lower-bounds
    - P̂: transition interval upper-bounds 
    - labels: IMDP state labels
"""
struct SystemProductIMDP <: IMDP
    states::UnitRange{Int64}
    actions::UnitRange{Int64}
    P̌
    P̂
    labels::Dict{Int, Any}
    state_tuples
    accepting_flags
    sink_flags
    dfa::DFA
end


"""
Construct a product IMDP from a (multimode) IMDP and DFA.
"""
function construct_DFA_IMDP_product(dfa, imdp)
    # Intial state
    # qinit = δ(dfa.transitions, dfa.initial_state, imdp.labels[imdp.initial_state])
    sizeQ = length(dfa.states)
    # pinit = (imdp.initial_state, qinit)
    dfa_acc_state = dfa.accepting_state
    dfa_sink_state = dfa.sink_state

    # Transition matrix size will be Nx|Q| -- or the original transition matrix permutated with the number of states in DFA
    Pmin = imdp.P̌
    Pmax = imdp.P̂
    N, M = size(Pmin)
    Pmin_new = spzeros(N*sizeQ, M*sizeQ)
    Pmax_new = spzeros(N*sizeQ, M*sizeQ) 

    pimdp_states = [] 
    pimdp_state_idxs = 1:length(imdp.states)*length(dfa.states)
    pimdp_actions = imdp.actions
    sizeA = length(pimdp_actions)
    @debug "Actions: " pimdp_actions
    for s in imdp.states
        for q in dfa.states
            new_state = (s, q)
            push!(pimdp_states, new_state)
            # Check for transitions to other states
        end
    end

    # TODO: Do not do this explicitly
    for sq in pimdp_states
        for a in pimdp_actions
            for sqp in pimdp_states
                qp_test = δ(dfa.transitions, sq[2], imdp.labels[sq[1]])
                if qp_test == sqp[2]
                    # Get the corresponding entry of the transition interval matrices
                    row_idx = (sq[1]-1)*sizeQ*sizeA + (sq[2]-1)*sizeA + a 
                    if (sq[2] == dfa_acc_state && sqp[2] == dfa_acc_state) || (sq[2] == dfa_sink_state && sqp[2] == dfa_sink_state)
                        # Flush out the old probabilities
                        col_idx = (sq[1]-1)*sizeQ + sq[2]  
                        Pmin_new[row_idx, :] .= 0. 
                        Pmax_new[row_idx, :] .= 0.
                        Pmin_new[row_idx, col_idx] = 1.0
                        Pmax_new[row_idx, col_idx] = 1.0
                    else
                        col_idx = (sqp[1]-1)*sizeQ + sqp[2]
                        Pmin_new[row_idx, col_idx] = Pmin[(sq[1]-1)*sizeA + a, sqp[1]]
                        Pmax_new[row_idx, col_idx] = Pmax[(sq[1]-1)*sizeA + a, sqp[1]]
                    end
                end
            end
        end
    end
   
    labels = zeros(M*sizeQ)
    if !isnothing(dfa_acc_state)
        labels[dfa_acc_state:sizeQ:M*sizeQ] .= 1
    end

    sink_labels = zeros(M*sizeQ)
    if !isnothing(dfa_sink_state)
        sink_labels[dfa_sink_state:sizeQ:M*sizeQ] .= 1
    end

    pimdp = SystemProductIMDP(pimdp_state_idxs, imdp.actions, Pmin_new, Pmax_new, Dict(), pimdp_states, labels, sink_labels, dfa)
    return pimdp 
end
