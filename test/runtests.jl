using IMDPs
using Test

using SparseArrays

@testset "IMDPs.jl" begin
    ## Multimodal test
    p̌1 = spzeros(2,2)
    p̌2 = 0.2*ones(2,2)
    p̂1 = 0.9*ones(2,2)
    p̂2 = 0.8*ones(2,2)

    imdp = create_imdp([p̌1, p̌2], [p̂1, p̂2])

    p̌_true = spzeros(4,2)
    p̌_true[2:2:end,:] .= 0.2
    p̂_true = spzeros(4,2)
    p̂_true[1:2:end,:] .= 0.9
    p̂_true[2:2:end,:] .= 0.8

    @test p̌_true == imdp.P̌ 
    @test p̂_true == imdp.P̂ 

    ## PIMDP Test
    imdp.labels[1] = "!a∧!b"
    imdp.labels[2] = "a∧!b"

    # TODO: Move DFA definition to TOML or auto create from LTL spec
    dfa_states = collect(1:3)
    dfa_props = ["a", "b"]
    dfa_transitions = [(1, "!a∧!b", 1),
                        (1, "a∧!b", 2),
                        (2, "true", 2),
                        (1, "!a∧b", 3),
                        (3, "true", 3)]
    dfa_accepting_state = 2
    dfa_sink_state = 3
    dfa_initial_state = 1

    dfa = IMDPs.DFA(dfa_states, dfa_props, dfa_transitions, dfa_accepting_state, dfa_sink_state, dfa_initial_state) 

    # TODO: do a real test on this!
    pimdp = IMDPs.construct_DFA_IMDP_product(dfa, imdp)
    IMDPs.validate(pimdp)
    acc_states = pimdp.states[findall(x->x>0, pimdp.accepting_flags)]
    sink_states = pimdp.states[findall(x->x>0, pimdp.sink_flags)]
    IMDPs.write("test-pimdp-out.txt", pimdp; acc_states=acc_states, sink_states=sink_states)
    @info pimdp
end
