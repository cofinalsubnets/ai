; layer-2 spike: a standalone online PARTIAL EVALUATOR (`mix`) -- the first Futamura
; projection in miniature. mix walks a source expr under an env that splits each
; variable STATIC (a known value) or DYNAMIC (a residual variable), folds the static
; parts, and RESIDUALIZES the dynamic ones into fresh source. specialize the recursive
; `power` to a static exponent and the recursion evaporates into straight-line product.
;
; this is the all-static folding the egg already does (feels/hgen in ai/ev.l), generalized
; to PARTIAL staticness -- the difference between constant-folding and partial evaluation.
; the companion to doc/proto/kinds.l: kinds.l is the binding-time ANALYSIS half (a static<dyn
; fixpoint reuses that same engine), mix is the SPECIALIZATION half it would feed.
;
; over a naive unroller it adds the three things that make it a real specializer:
;   * a GENERAL definition table (functions read from `defs`, not inlined by bespoke code)
;   * a TERMINATION guard: a call whose static signature is already in progress is residualized
;     instead of unfolded forever -- static-driven recursion unrolls, dynamic-driven stops clean
;   * an apcap FUEL bound (a one-shot call-cc escape; the real apcap raises (scare 'apcap k))
;
; NB the house nil-trap: end-of-list is a SPINE test (two?), never (! l) -- `!` reads the NET,
; and a list of falsy cells like '(0 0) nets to nothing, so (! '(0 0)) is TRUE. and pe/pcond/
; pe-call are MUTUALLY RECURSIVE, so they share one body-less `:` letrec (boxfix resolves the
; forward edges); a plain sequence of top-level defines would freeze a forward `pe` as missing.

(:
 (nul? l) (! (two? l))                          ; end-of-list = spine test, not the net

 ; --- pe-values: (s v) static, (r c) residual source ---
 (stat v) (L 's v)
 (dyn c)  (L 'r c)
 (stat? p) ('s = (cap p))
 (pval p)  (caup p)
 (reify p) (pval p)                             ; static payloads here are numbers (self-evaluating)
 (statval? p v) (&& (stat? p) (v = (pval p)))

 ; --- little list helpers ---
 (inset? k s) (? (nul? s) 0 (? (k = (cap s)) 1 (inset? k (cup s))))
 (alls l)     (? (nul? l) 1 (? (cap l) (alls (cup l)) 0))
 (allstat apv)(alls (map stat? apv))
 (sig apv)    (map (\ p (? (stat? p) (pval p) '_)) apv)        ; static signature (dynamic slots -> _)
 (zipenv ps apv) (? (nul? ps) () (link (L (cap ps) (cap apv)) (zipenv (cup ps) (cup apv))))

 ; --- env: name -> pe-value; an unbound name is a residual variable (dynamic) ---
 (look env k)
   (? (nul? env)            (dyn k)
      (k = (cap (cap env)))  (caup (cap env))
                             (look (cup env) k))

 ; --- the function definition table: (name params body). closed recursive source. ---
 defs (L
   (L 'power '(n b) '(? (! n) 1 (* b (power (- n 1) b))))      ; b^n
   (L 'down  '(b)   '(? (! b) 0 (down (- b 1))))               ; recursion driven by DYNAMIC b
   (L 'poly  '(x)   '(+ (* 3 (power 2 x)) (+ (* 2 x) 1))))     ; 3x^2 + 2x + 1, calls power
 (deflook nm)      (deflook-go nm defs)
 (deflook-go nm l) (? (nul? l) () (? (nm = (cap (cap l))) (cap l) (deflook-go nm (cup l))))

 ; --- apcap fuel: charged per unfold; exhausted -> a one-shot escape (the real apcap scares) ---
 pe-fuel (tablet 0)
 (tick u) (: n (peep pe-fuel 'n 0)              ; u is a dummy: a 0-arg (tick) is a VALUE, not a fn
             (? (! n) ((peep pe-fuel 'esc 0) (L 'APCAP (peep pe-fuel 'cap 0)))
                      (pin pe-fuel 'n (- n 1))))

 ; --- primitives: fold when all args static, else residualize (unit-aware on * and +) ---
 (prim? h) (inset? h (L '* '- '+ '!))
 (simp1 h a b)
   (? (&& (h = '*) (statval? a 1)) b
      (&& (h = '*) (statval? b 1)) a
      (&& (h = '+) (statval? a 0)) b
      (&& (h = '+) (statval? b 0)) a
                                  (dyn (L h (reify a) (reify b))))
 (pe-prim h apv)
   (? (allstat apv)     (stat (ev (link h (map pval apv))))    ; fold: run the op on the known values
      (2 = (tally apv)) (simp1 h (cap apv) (caup apv))          ; binary: residualize, drop units
                        (dyn (link h (map reify apv))))

 ; --- cond: a static test keeps one branch (this is what lets static recursion terminate) ---
 (pcond cv athen belse env seen)
   (? (stat? cv) (? (! (pval cv)) (pe belse env seen) (pe athen env seen))
                 (dyn (L '? (reify cv) (reify (pe athen env seen)) (reify (pe belse env seen)))))

 ; --- a defined-function call: unfold, unless this static instance is already in progress ---
 (pe-call def apv seen)
   (: nm (cap def) ps (caup def) bd (caup (cup def))
      key (link nm (sig apv))
      (? (inset? key seen)  (dyn (link nm (map reify apv)))     ; no static progress -> residual call
         (: _ (tick 0)
            (pe bd (zipenv ps apv) (link key seen)))))

 ; --- the partial evaluator ---
 (pe x env seen)
   (? (constellation? x) (stat x)
      (nom? x)           (look env x)
      (atom? x)          (stat x)
      (: h (cap x) a (cup x)
         (? (h = '?)  (pcond (pe (cap a) env seen) (caup a) (caup (cup a)) env seen)
            (prim? h) (pe-prim h (map (\ e (pe e env seen)) a))
            (: d (deflook h)
               (? d (pe-call d (map (\ e (pe e env seen)) a) seen)
                    (dyn (link h (map reify (map (\ e (pe e env seen)) a)))))))))

 ; --- entry points ---
 (mixf expr env fuel)
   (call-cc (\ esc (: _ (pin pe-fuel 'n fuel) _ (pin pe-fuel 'cap fuel) _ (pin pe-fuel 'esc esc)
                      (pe expr env ()))))
 (mix expr env)       (mixf expr env (apcap 0))
 (envb nv) (L (L 'n (stat nv)) (L 'b (dyn 'b)))               ; n static, b dynamic

 ; --- residual source -> a compiled unary lambda, for the equivalence checks ---
 (resid expr env v) ((ev (L '\ v (reify (mix expr env)))))    ; () outer: ev returns the closure

 ; ============================ self-checks ============================
 ; the first Futamura projection: the residual of `power` specialized to a static exponent
 ; computes the SAME function as the original program -- straight-line, no recursion left.
 _ (assert ('(* b (* b b)) = (reify (mix '(power n b) (envb 3)))) "power n=3 unrolls")
 _ (assert (125 = ((resid '(power n b) (envb 3) 'b) 5))         "residual(power,3)(5) == 5^3")
 _ (assert (32  = ((resid '(power n b) (envb 5) 'b) 2))         "residual(power,5)(2) == 2^5")
 _ (assert ('b  = (reify (mix '(power n b) (envb 1))))          "power n=1 -> b (unit simp)")
 _ (assert (1   = (reify (mix '(power n b) (envb 0))))          "power n=0 -> 1")
 _ (assert (8   = (pval (mix '(power n b) (L (L 'n (stat 3)) (L 'b (stat 2)))))) "both static folds")
 ; a nested call unrolls inside a larger expression:
 _ (assert (57  = ((resid '(poly x) (L (L 'x (dyn 'x))) 'x) 4)) "residual(poly)(4) == 3*16+8+1")
 ; recursion driven by a DYNAMIC value cannot unroll -> the guard leaves it intact:
 _ (assert ('(? (! b) 0 (down (- b 1))) = (reify (mix '(down b) (L (L 'b (dyn 'b)))))) "down stays residual")
 ; the apcap fuel bounds a huge static unfold instead of building a million-node residual:
 _ (assert ('APCAP = (cap (mixf '(power n b) (envb 1000) 8)))   "apcap guard fires")
 (. ";; doc/proto/mix.l: partial evaluator self-checks pass\n"))
