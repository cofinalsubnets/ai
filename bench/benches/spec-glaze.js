// tree-walking interpreter ev1 over a fixed AST P (Horner of 2x^3+3x^2+5x+7); sum P(i mod 97) mod
// 1e9+7 for i in [0,N). each iteration walks + dispatches the AST -- the interpretation cost ai's
// autospec specializes away. checksum = 474938608 (< 2^53, exact as a double).
const { bench } = require("../lib/bench");
const LIT = 0, VAR = 1, ADD = 2, MUL = 3;
const P = [ADD, [MUL, [ADD, [MUL, [ADD, [MUL, [LIT, 2], [VAR]], [LIT, 3]], [VAR]], [LIT, 5]], [VAR]], [LIT, 7]];
function ev1(nd, x) {
  switch (nd[0]) {
    case LIT: return nd[1];
    case VAR: return x;
    case ADD: return ev1(nd[1], x) + ev1(nd[2], x);
    default:  return ev1(nd[1], x) * ev1(nd[2], x);
  }
}
bench("spec-glaze", () => {
  let a = 0;
  for (let i = 0; i < 1000000; i++) a = (a + ev1(P, i % 97)) % 1000000007;
  return a;
});
