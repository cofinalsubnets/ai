package main

// tree-walking interpreter ev1 over a fixed AST P (Horner of 2x^3+3x^2+5x+7); sum P(i mod 97) mod
// 1e9+7 for i in [0,N). each iteration walks + dispatches the AST -- the interpretation cost ai's
// autospec specializes away. checksum = 474938608.
type node struct {
	tag  int
	lit  int64
	a, b *node
}

func ev1(nd *node, x int64) int64 {
	switch nd.tag {
	case 0:
		return nd.lit
	case 1:
		return x
	case 2:
		return ev1(nd.a, x) + ev1(nd.b, x)
	default:
		return ev1(nd.a, x) * ev1(nd.b, x)
	}
}

func main() {
	lit := func(n int64) *node { return &node{tag: 0, lit: n} }
	vr := &node{tag: 1}
	add := func(a, b *node) *node { return &node{tag: 2, a: a, b: b} }
	mul := func(a, b *node) *node { return &node{tag: 3, a: a, b: b} }
	P := add(mul(add(mul(add(mul(lit(2), vr), lit(3)), vr), lit(5)), vr), lit(7))
	bench("spec-glaze", func() int64 {
		var a int64
		for i := int64(0); i < 1000000; i++ {
			a = (a + ev1(P, i%97)) % 1000000007
		}
		return a
	})
}
