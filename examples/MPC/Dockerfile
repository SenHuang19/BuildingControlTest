FROM julia
ENV PATH="/usr/julia:${PATH}"
RUN julia -e "using Pkg; Pkg.add(\"HTTP\");Pkg.add(\"JSON\");Pkg.add(\"ConfParser\");Pkg.add(\"CSV\");Pkg.add(\"DataFrames\");Pkg.add(\"JuMP\");Pkg.add(\"Ipopt\");Pkg.add(\"MathOptInterface\")"
ADD . /usr/myapp/
