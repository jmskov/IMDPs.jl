# Tools to simulate IMDP behavior 

"""
    transition(imdp::IMDP, state, action)

Simulate a transition in the IMDP using an adversary that chooses from the transition intervals uniformly.
"""
function transition(imdp::IMDP, state::Int, action::Int)

    idx = (state-1)*maximum(imdp.actions) + action
    p̌_row = imdp.P̌[idx, :] 
    p̂_row = imdp.P̂[idx, :]
    successors = findall(x->x>0., p̂_row) 

    # Given all of the intervals, use a uniform adversary starting from a random possible successor state
    remainder = 1.0
    p_vals = zeros(size(successors))
    for (i,j) in enumerate(shuffle!(successors))
        p_val = minimum([rand(Uniform(p̌_row[i], p̂_row[i])), remainder])
        remainder -= p_val
        p_vals[j] = p_val
        remainder <= 0. ? break : nothing
    end
    new_state = sample(successors, Weights(p_vals))
    return new_state
end