; ============================================================================
; overlay-matrix -- a substantial DEPENDENT-TYPES showcase: matrices carry their
; dimensions, and the overlay enforces shape compatibility + COMPUTES result shapes
; at COMPILE time. Run (needs uu's normalizer + the deft toolkit):
;
;   cat test/uu.l doc/proto/overlay-lib.l doc/proto/overlay-matrix.l | out/host/ai /dev/stdin
;
;   matmul  : (mat m n) (mat n p) -> (mat m p)        inner dims MUST match (unify), thread m,p
;   hconcat : (mat r a) (mat r b) -> (mat r (add a b))  rows match (unify), cols ADD (uu computes)
;
; Combines all three dependent-type moves: UNIFICATION (inner dims / rows), COMPUTATION
; (uu adds columns), and THREADING (dims flow through a chain of matmuls). Every check is
; at compile time (deft checks at macro expansion); errors name the exact matrices/dims.
; See memory pluggable-types; the vec-length version is doc/proto/overlay-uu.l.
; ============================================================================
(: uu-nf    (\ x (vof () x))                                     ; uu normal form of a dim term (a number, or add..)
   mat-dims (\ d (? (&& (two? d) (id? (cap d) 'mat) (= 3 (tally d)))
                    (L 'mat (uu-nf (cap (cup d))) (uu-nf (cap (cup (cup d))))) d))   ; normalize both dims via uu
   mat-dom #('dice () 'ctors '(mat add succ zero)
             'join (\ a b (? (= (mat-dims a) (mat-dims b)) a 'top))
             'okr  (\ bd decl (= (mat-dims bd) (mat-dims decl)))  ; result ok iff dims match after uu-normalization
             'litdie (\ e 'top) 'tr (\ op a b 'top))
   _ (overlay-off ())
   _ (ev '(: (matmul a b) a (hconcat a b) a))                    ; runtime stubs so the defs run
   _ (overlay-set mat-dom ())
   _ (overlay-sig '(matmul ((mat m n) (mat n p)) (mat m p)))     ; the dependent types
   _ (overlay-sig '(hconcat ((mat r a) (mat r b)) (mat r (add a b)))))

(deft (pipeline  (a (mat 3 4)) (b (mat 4 5)) (c (mat 5 2))) (mat 3 2) (matmul (matmul a b) c))  ; OK  3x4.4x5.5x2 -> 3x2
(deft (oops      (a (mat 3 4)) (b (mat 5 2)))               (mat 3 2) (matmul a b))             ; ERR inner 4 vs 5
(deft (side      (a (mat 2 3)) (b (mat 2 4)))               (mat 2 7) (hconcat a b))            ; OK  cols 3+4=7 (uu)
(deft (sidewrong (a (mat 2 3)) (b (mat 2 4)))               (mat 2 8) (hconcat a b))            ; ERR uu says 7, not 8
(deft (rowbad    (a (mat 2 3)) (b (mat 5 4)))               (mat 2 7) (hconcat a b))            ; ERR rows 2 vs 5
(: _ (puts "-- pipeline & side check silently; oops/sidewrong/rowbad are flagged above\n") 0)
