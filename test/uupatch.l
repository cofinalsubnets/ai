; test/uupatch.l -- the PATCH GROUPOID's named-slot slice as uu proof TERMS: the
; uu-term rung of the patch arc. test/patch.l's first form states L1..L3b as
; executable asserts; proof/rocq/patch.v hand-proved them as scaffolding and
; PROMISED this file (its provenance note): the laws re-proven inside uu's own
; kernel, then emitted to Rocq AND Lean by tools/uu2coq.l + tools/uu2lean.l --
; two independent kernels re-certifying the same terms, the de Bruijn criterion
; the rest of the proof corpus already rides. Substrate: test/uu.l (this file
; loads after it by sort order, like test/uulay.l).
;
; the model mirrors the .l's first form name for name: a tree is a total map
; (key -> value, nats -- the .v's closure of "a missing slot reads 0"), a patch
; (chg k a b) one slot-change carrying its context, commute the partial swap.
; where patch.v case-split on Nat.eqb with tactics, the terms here case on
; isdeceqnat -- decidable equality as a COPROD, so every branch carries the
; path evidence a bool would have dropped; refusal is the unit summand. all
; equality of trees is pointwise (no funext anywhere), exactly the .v's rule.

; --- the model: patch, tree, apply, validity, inverse, commute ---
(assert
 (defn 'patch 'UU '(total2 k nat (total2 a nat nat)))
 (defn 'chg '(pi k nat (pi a nat (pi b nat patch)))
   '(lam k (lam a (lam b (tpair k (tpair a b))))))
 (defn 'pk '(pi p patch nat) '(lam p (pr1 p)))
 (defn 'pa '(pi p patch nat) '(lam p (pr1 (pr2 p))))
 (defn 'pb '(pi p patch nat) '(lam p (pr2 (pr2 p))))
 (defn 'tree 'UU '(pi k nat nat))
 (defn 'apon '(pi t tree (pi p patch tree))
   '(lam t (lam p (lam q (coprod_rect (lam c nat)
                           (lam e (pb p))
                           (lam ne (t q))
                           (isdeceqnat q (pk p)))))))
 (defn 'valid '(pi t tree (pi p patch bool))
   '(lam t (lam p (coprod_rect (lam c bool)
                    (lam e true)
                    (lam ne false)
                    (isdeceqnat (t (pk p)) (pa p))))))
 (defn 'invert '(pi p patch patch)
   '(lam p (chg (pk p) (pb p) (pa p))))
 (defn 'ppair 'UU '(total2 x patch patch))
 (defn 'commute '(pi p patch (pi q patch (coprod ppair unit)))
   '(lam p (lam q (coprod_rect (lam c (coprod ppair unit))
                    (lam e (ii2 tt))
                    (lam ne (ii1 (tpair q p)))
                    (isdeceqnat (pk p) (pk q))))))
 ; the model COMPUTES: apply writes its slot and only its slot; invert is its
 ; own inverse; independent keys swap, a shared key refuses
 (9 = (vof 0 '(apon (lam k 7) (chg 3 7 9) 3)))
 (7 = (vof 0 '(apon (lam k 7) (chg 3 7 9) 5)))
 ((vof 0 '(chg 3 7 9)) = (vof 0 '(invert (invert (chg 3 7 9)))))
 (id? (vof 0 'true)  (vof 0 '(valid (lam k 5) (chg 3 5 9))))
 (id? (vof 0 'false) (vof 0 '(valid (lam k 5) (chg 3 4 9))))
 ((vof 0 '(commute (chg 3 0 1) (chg 5 0 2)))
  = (vof 0 '(ii1 (tpair (chg 5 0 2) (chg 3 0 1)))))
 ((vof 0 '(commute (chg 3 0 1) (chg 3 1 2))) = (vof 0 '(ii2 tt))))

; --- (L1) commute is INVOLUTIVE. cmside is the coprod no-confusion family (a
; --- recorded refusal is never a success); the ii1 lane rides maponpaths of
; --- "re-commute the carried pair", so the involution IS the algebra: commute
; --- q p computes straight to ii1 (p,q) once the keys are known distinct ---
(assert
 (defn 'cmside '(pi c (coprod ppair unit) UU)
   '(lam c (coprod_rect (lam x UU) (lam x empty) (lam x unit) c)))
 (defq 'commute-involutive
   '(pi p patch (pi q patch (pi q2 patch (pi p2 patch
      (pi h (paths (coprod ppair unit) (commute p q) (ii1 (tpair q2 p2)))
        (paths (coprod ppair unit) (commute q2 p2) (ii1 (tpair p q))))))))
   '(lam p (lam q (lam q2 (lam p2
      ((coprod_rect
         (lam c (pi h (paths (coprod ppair unit)
                        (coprod_rect (lam c2 (coprod ppair unit))
                          (lam e2 (ii2 tt))
                          (lam ne2 (ii1 (tpair q p)))
                          c)
                        (ii1 (tpair q2 p2)))
                  (paths (coprod ppair unit) (commute q2 p2) (ii1 (tpair p q)))))
         (lam e (lam h (fromempty
            (paths (coprod ppair unit) (commute q2 p2) (ii1 (tpair p q)))
            (transportf (coprod ppair unit) cmside (ii2 tt) (ii1 (tpair q2 p2)) h tt))))
         (lam ne (lam h
            (pathscomp0 (coprod ppair unit)
              (commute q2 p2) (commute q p) (ii1 (tpair p q))
              (pathsinv0 (coprod ppair unit) (commute q p) (commute q2 p2)
                (maponpaths (coprod ppair unit) (coprod ppair unit)
                  (lam c (coprod_rect (lam x (coprod ppair unit))
                           (lam z (commute (pr1 z) (pr2 z)))
                           (lam u (ii2 tt))
                           c))
                  (ii1 (tpair q p)) (ii1 (tpair q2 p2)) h))
              ((coprod_rect
                 (lam c (paths (coprod ppair unit)
                          (coprod_rect (lam c2 (coprod ppair unit))
                            (lam e2 (ii2 tt))
                            (lam ne2 (ii1 (tpair p q)))
                            c)
                          (ii1 (tpair p q))))
                 (lam e2 (fromempty
                    (paths (coprod ppair unit) (ii2 tt) (ii1 (tpair p q)))
                    (ne (pathsinv0 nat (pk q) (pk p) e2))))
                 ; the ascriptions pin tpair's implicit family and the reduced
                 ; refl type: Lean's elaborator won't iota-reduce the stuck rec
                 ; in the expected type while a metavariable is live (the
                 ; based-J seam, uu2lean's note); Rocq needed nothing
                 (lam ne2 (the (paths (coprod ppair unit)
                                 (ii1 (tpair p q)) (ii1 (tpair p q)))
                               (idpath (ii1 (the ppair (tpair p q))))))
                 (isdeceqnat (pk q) (pk p)))))))
         (isdeceqnat (pk p) (pk q))))))))))

; --- (L2) the INVERSE round-trips IN CONTEXT: where the patch is valid, apply
; --- then unpull restores every slot -- pointwise, quantifying the key like
; --- the .v does; validity opened by ONE convoy on its own decision, the main
; --- case abstracting BOTH apon layers' shared scrutinee at once ---
(assert
 (defq 'invert-roundtrip
   '(pi t tree (pi p patch (pi hv (paths bool (valid t p) true)
      (pi q nat (paths nat (apon (apon t p) (invert p) q) (t q))))))
   '(lam t (lam p
      ((coprod_rect
         (lam c (pi hv (paths bool
                         (coprod_rect (lam c2 bool) (lam e2 true) (lam ne2 false) c)
                         true)
                  (pi q nat (paths nat (apon (apon t p) (invert p) q) (t q)))))
         (lam e (lam hv (lam q
           ((coprod_rect
              (lam c (paths nat
                       (coprod_rect (lam c2 nat)
                         (lam e2 (pa p))
                         (lam ne2 (coprod_rect (lam c3 nat)
                                    (lam e3 (pb p))
                                    (lam ne3 (t q))
                                    c))
                         c)
                       (t q)))
              (lam e1 (pathscomp0 nat (pa p) (t (pk p)) (t q)
                        (pathsinv0 nat (t (pk p)) (pa p) e)
                        (maponpaths nat nat t (pk p) q (pathsinv0 nat q (pk p) e1))))
              (lam ne1 (idpath (t q)))
              (isdeceqnat q (pk p)))))))
         (lam ne (lam hv (fromempty
            (pi q nat (paths nat (apon (apon t p) (invert p) q) (t q)))
            (nopathsfalsetotrue hv))))
         (isdeceqnat (t (pk p)) (pa p)))))))
 ; and it computes: apply then unpull reads the old value back
 (7 = (vof 0 '(apon (apon (lam k 7) (chg 3 7 9)) (invert (chg 3 7 9)) 3))))

; --- (L3a) independent patches are ORDER-FREE (the semantic heart -- what makes
; --- merge and cherry-pick sound). apon-comm is the raw form off the key
; --- disequality; commute-sound ties it to the primitive: a successful commute
; --- WITNESSES order-freedom. the double convoy cases each decision once,
; --- abstracting all its occurrences on both sides ---
(assert
 (defq 'apon-comm
   '(pi p patch (pi q patch (pi ne (pi e (paths nat (pk p) (pk q)) empty)
      (pi t tree (pi r nat
        (paths nat (apon (apon t p) q r) (apon (apon t q) p r)))))))
   '(lam p (lam q (lam ne (lam t (lam r
      ((coprod_rect
         (lam c (paths nat
                  (coprod_rect (lam c2 nat)
                    (lam e2 (pb q))
                    (lam ne2 (coprod_rect (lam c3 nat)
                               (lam e3 (pb p))
                               (lam ne3 (t r))
                               (isdeceqnat r (pk p))))
                    c)
                  (coprod_rect (lam c2 nat)
                    (lam e2 (pb p))
                    (lam ne2 (coprod_rect (lam c3 nat)
                               (lam e3 (pb q))
                               (lam ne3 (t r))
                               c))
                    (isdeceqnat r (pk p)))))
         (lam e1
           ((coprod_rect
              (lam c (paths nat (pb q)
                       (coprod_rect (lam c2 nat)
                         (lam e2 (pb p))
                         (lam ne2 (pb q))
                         c)))
              (lam e2 (fromempty (paths nat (pb q) (pb p))
                        (ne (pathscomp0 nat (pk p) r (pk q)
                              (pathsinv0 nat r (pk p) e2)
                              e1))))
              (lam ne2 (idpath (pb q)))
              (isdeceqnat r (pk p)))))
         (lam ne1
           ((coprod_rect
              (lam c (paths nat
                       (coprod_rect (lam c2 nat) (lam e2 (pb p)) (lam ne2 (t r)) c)
                       (coprod_rect (lam c2 nat) (lam e2 (pb p)) (lam ne2 (t r)) c)))
              (lam e2 (idpath (pb p)))
              (lam ne2 (idpath (t r)))
              (isdeceqnat r (pk p)))))
         (isdeceqnat r (pk q))))))))))
 (defq 'commute-sound
   '(pi p patch (pi q patch
      (pi h (paths (coprod ppair unit) (commute p q) (ii1 (tpair q p)))
        (pi t tree (pi r nat
          (paths nat (apon (apon t p) q r) (apon (apon t q) p r)))))))
   '(lam p (lam q
      ((coprod_rect
         (lam c (pi h (paths (coprod ppair unit)
                        (coprod_rect (lam c2 (coprod ppair unit))
                          (lam e2 (ii2 tt))
                          (lam ne2 (ii1 (tpair q p)))
                          c)
                        (ii1 (tpair q p)))
                  (pi t tree (pi r nat
                    (paths nat (apon (apon t p) q r) (apon (apon t q) p r))))))
         (lam e (lam h (fromempty
            (pi t tree (pi r nat
              (paths nat (apon (apon t p) q r) (apon (apon t q) p r))))
            (transportf (coprod ppair unit) cmside (ii2 tt) (ii1 (tpair q p)) h tt))))
         (lam ne (lam h (apon-comm p q ne)))
         (isdeceqnat (pk p) (pk q)))))))
 ; both pull orders land the same tree, at the touched keys and elsewhere
 (1 = (vof 0 '(apon (apon (lam k 0) (chg 3 0 1)) (chg 5 0 2) 3)))
 (1 = (vof 0 '(apon (apon (lam k 0) (chg 5 0 2)) (chg 3 0 1) 3)))
 (2 = (vof 0 '(apon (apon (lam k 0) (chg 3 0 1)) (chg 5 0 2) 5)))
 (2 = (vof 0 '(apon (apon (lam k 0) (chg 5 0 2)) (chg 3 0 1) 5))))

; --- (L3b) a FRONTIER is stable under an adjacent swap of independent patches.
; --- patch lists are UniMath-style vectors at patch (a plist's length is pr1,
; --- like nlist); applall is the .l's left fold. the lift is two congruence
; --- lemmas (one apon, then the whole fold -- patch.v's apon_ext /
; --- fold_apon_ext) and one induction down the prefix; the swap at the head is
; --- exactly apon-comm under the fold. meaning is order-free, so the
; --- (unordered) patch set is a sound version identity -- the reproducibility
; --- tie, now machine-checked in three kernels ---
(assert
 (defn 'pvec '(pi n nat UU)
   '(lam n (nat_rect (lam q UU) unit (lam k (lam r (total2 h patch r))) n)))
 (defn 'plist 'UU '(total2 n nat (pvec n)))
 (defn 'pnil 'plist '(tpair 0 tt))
 (defn 'pcons '(pi x patch (pi l plist plist))
   '(lam x (lam l (tpair (succ (pr1 l)) (tpair x (pr2 l))))))
 (defn 'papp '(pi a plist (pi b plist plist))
   '(lam a (lam b ((nat_rect (lam q (pi v (pvec q) plist))
                     (lam v b)
                     (lam k (lam IH (lam v (pcons (pr1 v) (IH (pr2 v))))))
                     (pr1 a))
                   (pr2 a)))))
 (defn 'applall '(pi l plist (pi t tree tree))
   '(lam l (lam t ((nat_rect (lam q (pi v (pvec q) (pi t2 tree tree)))
                     (lam v (lam t2 t2))
                     (lam k (lam IH (lam v (lam t2 (IH (pr2 v) (apon t2 (pr1 v)))))))
                     (pr1 l))
                   (pr2 l) t))))
 (defq 'apon-ext
   '(pi t1 tree (pi t2 tree (pi p patch
      (pi hp (pi k nat (paths nat (t1 k) (t2 k)))
        (pi r nat (paths nat (apon t1 p r) (apon t2 p r)))))))
   '(lam t1 (lam t2 (lam p (lam hp (lam r
      ((coprod_rect
         (lam c (paths nat
                  (coprod_rect (lam c2 nat) (lam e2 (pb p)) (lam ne2 (t1 r)) c)
                  (coprod_rect (lam c2 nat) (lam e2 (pb p)) (lam ne2 (t2 r)) c)))
         (lam e (idpath (pb p)))
         (lam ne (hp r))
         (isdeceqnat r (pk p))))))))))
 (defq 'applall-ext
   '(pi l plist (pi t1 tree (pi t2 tree
      (pi hp (pi k nat (paths nat (t1 k) (t2 k)))
        (pi r nat (paths nat (applall l t1 r) (applall l t2 r)))))))
   '(lam l ((nat_rect
       (lam q (pi v (pvec q) (pi t1 tree (pi t2 tree
                (pi hp (pi k nat (paths nat (t1 k) (t2 k)))
                  (pi r nat (paths nat (applall (tpair q v) t1 r)
                                       (applall (tpair q v) t2 r))))))))
       (lam v (lam t1 (lam t2 (lam hp (lam r (hp r))))))
       (lam k (lam IH (lam v (lam t1 (lam t2 (lam hp
         (IH (pr2 v) (apon t1 (pr1 v)) (apon t2 (pr1 v))
             (apon-ext t1 t2 (pr1 v) hp))))))))
       (pr1 l))
     (pr2 l))))
 (defq 'applall-swap
   '(pi p patch (pi q patch (pi ne (pi e (paths nat (pk p) (pk q)) empty)
      (pi pre plist (pi post plist (pi t tree (pi r nat
        (paths nat
          (applall (papp pre (pcons p (pcons q post))) t r)
          (applall (papp pre (pcons q (pcons p post))) t r)))))))))
   '(lam p (lam q (lam ne (lam pre (lam post
      ((nat_rect
         (lam n (pi v (pvec n) (pi t tree (pi r nat
           (paths nat
             (applall (papp (tpair n v) (pcons p (pcons q post))) t r)
             (applall (papp (tpair n v) (pcons q (pcons p post))) t r))))))
         (lam v (lam t (applall-ext post
                  (apon (apon t p) q)
                  (apon (apon t q) p)
                  (apon-comm p q ne t))))
         (lam k (lam IH (lam v (lam t
           (IH (pr2 v) (apon t (pr1 v)))))))
         (pr1 pre))
       (pr2 pre))))))))
 ; the fold COMPUTES, and the frontier agrees either order
 (2 = (vof 0 '(applall (pcons (chg 3 0 1) (pcons (chg 5 0 2) pnil)) (lam k 0) 5)))
 ((vof 0 '(applall (pcons (chg 3 0 1) (pcons (chg 5 0 2) pnil)) (lam k 0) 3))
  = (vof 0 '(applall (pcons (chg 5 0 2) (pcons (chg 3 0 1) pnil)) (lam k 0) 3))))
