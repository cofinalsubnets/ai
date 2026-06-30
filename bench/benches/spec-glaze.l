; spec-glaze -- a tiny tree-walking interpreter `ev1` over a fixed AST program P (the Horner form of
; 2x^3+3x^2+5x+7), summing P(i mod 97) mod 1e9+7 over i in [0,N). The naive way to run a program: walk
; its AST and dispatch on each node's head, every iteration. ai's glaze does PARTIAL EVALUATION
; (autospec, ai/glaze/auto.l -- the 1st Futamura projection): ev1 applied to the STATIC program P is
; specialized, the dispatch + tree navigation fold away to P's straight-line arithmetic, and the
; residual loop then natives. THIS IS DEFAULT, ALWAYS-ON BEHAVIOR -- the glaze is baked into the
; shipped binary and applied to every qualifying closure (probe: `out/host/ai this-file` glazes it
; with no flags), NOT a benchmark-only switch. The % 1e9+7 keeps every value in int64 (no bignum
; deopt), so the number reflects native code vs interpretation.
;
; WHAT THE CROSS-LANGUAGE ROW MEASURES (read honestly): the cost of INTERPRETING a small program, and
; whether a language ELIMINATES it. ai specializes the interpreter away at compile time (autospec); the
; AOT languages (go/rust) and most JITs (node/luajit) still walk the AST every iteration, so ai beats
; them here. But this is NOT a guaranteed win: a META-TRACING JIT does the same specialization at
; runtime -- PyPy traces ev1-over-P down to the residual and BEATS ai on this bench. So read it as "ai's
; partial evaluator lands in the same class as a tracing JIT", not "ai is fastest". The interpreter-
; overhead analogue of `deforest` (fusion) -- a real capability on a real workload, honestly placed.
; checksum = sum_{i<N} P(i mod 97) mod 1000000007, N=1000000.
(: (ev1 nd x) (? (id? (cap nd) 'lit) (caup nd)  (id? (cap nd) 'var) x
                 (id? (cap nd) 'add) (+ (ev1 (caup nd) x) (ev1 (cap (cuup nd)) x))
                 (id? (cap nd) 'mul) (* (ev1 (caup nd) x) (ev1 (cap (cuup nd)) x))  0)
   P '(add (mul (add (mul (add (mul (lit 2) (var)) (lit 3)) (var)) (lit 5)) (var)) (lit 7))
   (run n) ((: (go i a) (? (< i n) (go (+ i 1) (% (+ a (ev1 P (% i 97))) 1000000007)) a)) 0 0)
   (bench "spec-glaze" (\ _ (run 1000000))))
