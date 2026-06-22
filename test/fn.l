; functions print as value forms that reconstruct under eval: builtins -> the bare
; name; lambdas -> (\ …) source with \-bound vars as interned d<lvl> de Bruijn LEVELS
; (a-canonical: outermost binder = d0). Interned names -> the print form round-trips
; (see roundtrip.l). a-equivalent lambdas print identically. a CAPTURED value renders as a
; leading binder -- but THAT rendering is intensional and free to vary (cprop may inline a
; constant capture), so captures are asserted EXTENSIONALLY: show -> read -> eval rebuilds a
; function of the same behavior (rt below; the dedicated suite is roundtrip.l).
(: (s2cl s) ((: (g i) (? (< i (tally s)) (link (peep s i 0) (g (+ 1 i))))) 0)
   (rt x) (ev (sound (tap (s2cl (show x))) (nom 0)))
 (assert
  (= "\+" (show (+)))
  (= "link" (show link))
  (= "(\\ d0 d0)" (show (\ x x)))
  (= "(\\ d0 d1 (+ d0 d1))" (show (\ a b (+ a b))))
  (= (show (\ x x)) (show (\ y y)))               ; a-equivalent -> identical print
  (= "(\\ d0 (\\ d1 d1))" (show (\ x (\ x x))))      ; shadow: inner binder = d1
  (= "(\\ d0 'y)" (show (\ x 'y)))                   ; quoted datum not renamed
  (= "(+ 1)" (show (+ 1)))                            ; partial app of a builtin: stable form
  (= 3 ((rt ((\ a b (+ a b)) 1)) 2))                 ; partial-applied lambda round-trips (capture rendering free to vary)
  (= 9 (: y (+ 2 3) ((rt (\ x (+ x y))) 4)))         ; closure with a captured var round-trips to a working fn
  (string? (show map))
  (< 10 (tally (show map)))))
