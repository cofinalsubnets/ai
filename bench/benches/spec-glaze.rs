include!("../lib/bench.rs");

use std::hint::black_box;

// tree-walking interpreter ev1 over a fixed AST P (Horner of 2x^3+3x^2+5x+7); sum P(i mod 97) mod
// 1e9+7 for i in [0,N). checksum = 474938608. N is black_box'd so rustc can't const-fold the loop
// (apples-to-apples with ai's runtime input -- both run the interpreter honestly).
enum Node { Lit(i64), Var, Add(Box<Node>, Box<Node>), Mul(Box<Node>, Box<Node>) }

fn ev1(nd: &Node, x: i64) -> i64 {
    match nd {
        Node::Lit(n) => *n,
        Node::Var => x,
        Node::Add(a, b) => ev1(a, x) + ev1(b, x),
        Node::Mul(a, b) => ev1(a, x) * ev1(b, x),
    }
}

const N: i64 = 1000000;

fn main() {
    use Node::*;
    let l = |n| Box::new(Lit(n));
    let p = Add(Box::new(Mul(Box::new(Add(Box::new(Mul(Box::new(Add(Box::new(Mul(l(2), Box::new(Var))), l(3))), Box::new(Var))), l(5))), Box::new(Var))), l(7));
    bench("spec-glaze", || {
        let n = black_box(N);
        let mut a: i64 = 0;
        let mut i: i64 = 0;
        while i < n {
            a = (a + ev1(&p, i % 97)) % 1000000007;
            i += 1;
        }
        a
    });
}
