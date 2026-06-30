import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
from bench import bench

# a tree-walking interpreter ev1 over a fixed AST P (Horner of 2x^3+3x^2+5x+7); sum P(i mod 97) mod
# 1e9+7 for i in [0,N). every iteration walks + dispatches the AST -- the interpretation overhead that
# ai's autospec (partial evaluation, the 1st Futamura projection) specializes away. checksum = 474938608.
LIT, VAR, ADD, MUL = 0, 1, 2, 3
P = (ADD, (MUL, (ADD, (MUL, (ADD, (MUL, (LIT, 2), (VAR,)), (LIT, 3)), (VAR,)), (LIT, 5)), (VAR,)), (LIT, 7))
def ev1(nd, x):
    t = nd[0]
    if t == LIT: return nd[1]
    if t == VAR: return x
    if t == ADD: return ev1(nd[1], x) + ev1(nd[2], x)
    return ev1(nd[1], x) * ev1(nd[2], x)
def work():
    a = 0
    for i in range(1000000):
        a = (a + ev1(P, i % 97)) % 1000000007
    return a
bench("spec-glaze", work)
