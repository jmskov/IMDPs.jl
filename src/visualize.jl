# functions for visualizing verification results

function terminal_plot(result_matrix::AbstractMatrix)
    plt = UnicodePlots.histogram(result_matrix[:,3], title="LB Sat. Prob.")
    show(plt)
    plt = UnicodePlots.histogram(result_matrix[:,4], title="UB Sat. Prob.")
    show(plt)
end

function terminal_plot(result_filename::String, globally_safe::Bool)
    result_matrix = load_result(result_filename, globally_safe=globally_safe)
    terminal_plot(result_matrix)
end