# Files for writing IMDPs to file

function write(filename::String, imdp::IMDP; acc_states=[], sink_states=[])
    open(filename, "w") do f
        state_num = length(imdp.states)
        action_num =length(imdp.actions)
        @printf(f, "%d \n", state_num)
        @debug "Length actions: " length(imdp.actions)
        @printf(f, "%d \n", length(imdp.actions))
        @printf(f, "%d \n", length(acc_states))
        [@printf(f, "%d ", acc_state-1) for acc_state in acc_states]
        @printf(f, "\n")

        for i=1:state_num
            if isnothing(sink_states) || !(i∈sink_states)
                for action in imdp.actions
                    row_idx = (i-1)*action_num + action
                    ij = findall(>(0.), imdp.P̂[(i-1)*action_num + action, :])   
                    # Something about if the upper bound is less than one? Perhaps for numerical issues?
                    @debug action, i
                    psum = sum(imdp.P̂[row_idx, :])
                    psum >= 1 ? nothing : throw(AssertionError("Bad max sum: $psum for state $i")) 
                    for j=ij
                        @printf(f, "%d %d %d %f %f", i-1, action-1, j-1, imdp.P̌[row_idx, j], imdp.P̂[row_idx, j])
                        if (i < state_num || j < ij[end] || action < action_num)
                            @printf(f, "\n")
                        end
                    end
                end
            else
                @printf(f, "%d %d %d %f %f", i-1, 0, i-1, 1.0, 1.0)
                if i<state_num
                    @printf(f, "\n")
                end
            end
        end
    end
end

function write_dot_graph(filename::String, imdp::IMDP; initial_state::Int=1)
    open(filename, "w") do f
        println(f, "digraph G {")
        println(f, "  rankdir=LR\n  node [shape=\"circle\"]\n  fontname=\"Lato\"\n  node [fontname=\"Lato\"]\n  edge [fontname=\"Lato\"]")
        println(f, "  size=\"8.2,8.2\" node[style=filled,fillcolor=\"#FDEDD3\"] edge[arrowhead=vee, arrowsize=.7]")

        # Initial State
        @printf(f, "  I [label=\"\", style=invis, width=0]\n  I -> %d\n", initial_state)

        for state in imdp.states
            imdp_label = state ∈ keys(imdp.labels) ? imdp.labels[state] : ""
            @printf(f, "  %d [label=<q<SUB>%d</SUB>>, xlabel=<%s>]\n", state, state, imdp_label)
            
            for action in imdp.actions
                row_idx = (state-1)*length(imdp.actions) + action

                for idx in findall(>(0.), imdp.P̂[row_idx, :])
                    state_p = idx
                    @printf(f, "  %d -> %d [label=<a<SUB>%d</SUB>: %.2f-%.2f >]\n", state, state_p, action, imdp.P̌[row_idx,state_p], imdp.P̂[row_idx,state_p])
                end
            end
        end
        println(f, "}")
    end
end