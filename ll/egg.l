(\ egg (:
 (go e z a) (? a (go e (e (A a)) (B a)) z)
 t0 (clock 0)
 e (go (go ev 0 egg) 0 egg)
 _ (pin dict 'ev e)
 t1 (clock t0)
 (pin dict 'boot-ticks t1)))
