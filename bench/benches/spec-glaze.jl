include(joinpath(@__DIR__, "..", "lib", "bench.jl"))

# tree-walking interpreter ev1 over a fixed AST P (Horner of 2x^3+3x^2+5x+7); sum P(i mod 97) mod
# 1e9+7 for i in [0,N). checksum = 474938608.
const LIT, VAR, ADD, MUL = 0, 1, 2, 3
const P = (ADD, (MUL, (ADD, (MUL, (ADD, (MUL, (LIT, 2), (VAR,)), (LIT, 3)), (VAR,)), (LIT, 5)), (VAR,)), (LIT, 7))
function ev1(nd, x)
    t = nd[1]
    t == LIT && return nd[2]
    t == VAR && return x
    t == ADD && return ev1(nd[2], x) + ev1(nd[3], x)
    return ev1(nd[2], x) * ev1(nd[3], x)
end
function spec_work()
    a = 0
    for i in 0:999999
        a = (a + ev1(P, i % 97)) % 1000000007
    end
    return a
end
bench("spec-glaze", spec_work)
