; SAT model-counting via ai's generic ring -- a CNF formula is a product of sums
; of unification literals (kanren is in prel: var/===/+/*/load). over n boolean
; vars x0..x(n-1), clauses (x_i | x_(i+1)) cyclically -- "no two adjacent 0s".
; the solution STREAM is counted tail-recursively (scount), never materialized,
; so RAM stays flat; the count carries search multiplicity (a model is re-derived
; once per clause that justifies it -- the stream is a semiring, not a set).
; checksum = 6726 (n=10).  ai-only: no cross-language counterpart.
(: (boolean x) ((x === 0) + (x === 1))
   (nth l k) (? (= k 0) (cap l) (nth (cup l) (+ k -1)))
   (scount s) ((: (go acc s) (s (\ _ acc) (\ s2 (go acc s2)) (\ x s2 (go (+ 1 acc) s2)))) 0 s)
   (sat n) (:
     vs (map var (map (\ i (intern (+ "x" (show i)))) (jot n)))
     bools (map boolean vs)
     clauses (map (\ i (+ ((nth vs i) === 1) ((nth vs (% (+ i 1) n)) === 1))) (jot n))
     formula (foldl (*) () (cat bools clauses))
     (scount ((load formula) '(0))))
 (bench "sat" (\ _ (sat 10))))
