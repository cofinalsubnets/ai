; ============================================================================
; overlay-matrix -- a RUNNABLE dependent-types showcase. Real matrices (lists of rows),
; real matmul/hconcat, dependent-type-checked shapes, executed for real. Run:
;   cat test/uu.l doc/proto/overlay-lib.l doc/proto/overlay-matrix.l | out/host/ai /dev/stdin
;
; The split the user asked about: the two PRIMITIVES (matmul, hconcat) declare their
; dependent type ONCE with `sig` (the trusted boundary -- their bodies are raw list code
; the checker can't infer through). Everything else is `deft` -- checked, not asserted.
; ============================================================================

; --- FORM 1: real matrix operations on lists-of-rows (a 2x3 = ((1 2 3)(4 5 6))) ---
(: (rdot a b)     (? (atom? a) 0 (+ (* (cap a) (cap b)) (rdot (cup a) (cup b))))   ; NB: `dot` is the print builtin -> rdot
   (transpose m)  (? (atom? (cap m)) () (link (map cap m) (transpose (map cup m))))
   (matmul a b)   (: bt (transpose b) (map (\ ra (map (\ bc (rdot ra bc)) bt)) a))
   (hconcat a b)  (? (atom? a) () (link (cat (cap a) (cap b)) (hconcat (cup a) (cup b)))))   ; body-less: these ops LEAK as globals

; --- FORM 2: the matrix type-domain (dims normalized by uu, so cols can be computed) ---
(: uu-nf    (\ x (vof () x))
   mat-dims (\ d (? (&& (two? d) (id? (cap d) 'mat) (= 3 (tally d)))
                    (L 'mat (uu-nf (cap (cup d))) (uu-nf (cap (cup (cup d))))) d))
   mat-dom  #('dice () 'ctors '(mat add succ zero)
              'join (\ a b (? (= (mat-dims a) (mat-dims b)) a 'top))
              'okr  (\ bd decl (= (mat-dims bd) (mat-dims decl)))
              'litdie (\ e 'top) 'tr (\ op a b 'top))
   _ (overlay-set mat-dom ()) 0)

; --- FORM 3: declare the PRIMITIVES' dependent types, ONCE (the trusted boundary) ---
(sig matmul  ((mat m n) (mat n p)) (mat m p))
(sig hconcat ((mat r a) (mat r b)) (mat r (add a b)))

; --- FORM 4: USER code via deft -- checked at compile time, NOT hand-typed ---
(: _ (deft (prod  (a (mat 2 3)) (b (mat 3 2))) (mat 2 2) (matmul a b))    ; ok: inner 3=3 -> 2x2
   _ (deft (side  (a (mat 2 3)) (b (mat 2 1))) (mat 2 4) (hconcat a b))   ; ok: cols 3+1=4 (uu computes)
   _ (deft (oops  (a (mat 2 3)) (b (mat 4 2))) (mat 2 2) (matmul a b))    ; ERR: inner 3 vs 4
   0)

; --- FORM 5: RUN them on real matrices -> real results ---
(: A '((1 2 3) (4 5 6))   B '((1 0) (0 1) (1 1))   C '((7) (8))
   _ (puts "prod A B  (2x3 x 3x2) = ") _ (puts (show (prod A B))) _ (putc 10)
   _ (puts "side A C  (2x3 | 2x1) = ") _ (puts (show (side A C))) _ (putc 10)
   0)
