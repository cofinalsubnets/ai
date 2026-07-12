; test/patch.l -- the PATCH GROUPOID, the executable SOURCE-OF-TRUTH spec.
;
; the drift anchor for the whole patch stack: doc/proto/patch.l is the design (the
; argument that a distribution / namespace / repo-state are ONE algebra of
; selectable sets, with COMMUTE the primitive underneath); proof/rocq/patch.v
; machine-checks the first slice axiom-free. the laws asserted HERE are what those
; are gated to agree with -- the .v today, and the next rung (L1..L3b as uu proof
; TERMS emitted to rocq + lean by tools/uu2coq.l + tools/uu2lean.l) tomorrow; a
; hand .v drifts (the wm2uu lesson), so this file is the truth it regenerates off.
;
; the named-slot model: a tree is a (key . value) assoc, a patch a single
; slot-change carrying its CONTEXT (old -> new -- not a bare diff), commute the
; partial swap. the laws:
;   L1  commute is involutive              L3a commute is sound: independent
;   L2  inverse round-trips (in context)       patches are ORDER-FREE
;                                          L3b a FRONTIER is stable under an
;                                              adjacent swap of independent patches
; helpers stay LOCAL (the corpus runs concatenated in one scope); the asserts run
; inside the body, so the whole spec is one leak-free form.

(:
 ; --- the model (mirror of doc/proto/patch.l) ---
 (chg k a b) (link 'chg (link k (link a (link b 0))))     ; patch: change slot k, old->new
 (pk p) (cap (cup p))                                     ; the slot it touches
 (pa p) (cap (cup (cup p)))                               ; its context (old value)
 (pb p) (cap (cup (cup (cup p))))                         ; the new value
 (tget t k) (? (atom? t) 0 (: c (cap t) (? (id? k (cap c)) (cup c) (tget (cup t) k))))
 (tset t k v) (link (link k v) t)                         ; newest shadows; a missing slot reads 0
 (valid t p) (id? (tget t (pk p)) (pa p))                 ; a patch belongs iff its context matches
 (apon t p) (tset t (pk p) (pb p))                        ; lay the patch's new value
 (applall t ps) (foldl apon t ps)                         ; fold a whole frontier onto a tree
 (invert p) (chg (pk p) (pb p) (pa p))                    ; the groupoid inverse (unpull)
 (commute p q) (? (id? (pk p) (pk q)) 0 (link q (link p 0)))  ; partial: 0 = a dependency

 ; --- spec-local equality: deep-structural (patches are lists), and tree agreement
 ;     at a witness key set (trees are maps -> compare pointwise, as the .v does) ---
 (leq a b) (? (&& (atom? a) (atom? b)) (id? a b)
              (|| (atom? a) (atom? b)) 0
              (&& (leq (cap a) (cap b)) (leq (cup a) (cup b))))
 (teq a b ks) (? (atom? ks) 1 (&& (id? (tget a (cap ks)) (tget b (cap ks))) (teq a b (cup ks))))
 (cat2 a b) (? (atom? a) b (link (cap a) (cat2 (cup a) b)))

 ; --- witnesses ---
 px (chg 'x 0 1) py (chg 'y 0 2)                          ; independent -- different slots
 p1 (chg 'x 0 1) p2 (chg 'x 1 2)                          ; dependent -- same slot

 ; (L1) commute is INVOLUTIVE: swap two independent patches, swap the result back,
 ;      and you are home. same-slot patches DON'T commute -- 0, a dependency.
 _ (assert
    (leq (commute px py) (link py (link px 0)))                       ; p;q -> q;p
    (: c (commute px py) (leq (commute (cap c) (cap (cup c)))
                              (link px (link py 0))))                 ; ...and back to p;q
    (! (commute p1 p2))                                              ; same slot -> no commute
    (leq p1 p1) (! (leq px py)))                                     ; leq itself is honest

 ; (L2) INVERSE round-trips IN CONTEXT: where the patch is valid, apply then unpull
 ;      (apply the inverse) restores every slot; invert is its own inverse.
 _ (: t0 (tset 0 'x 5) p (chg 'x 5 9)
      (assert
       (valid t0 p)                                                  ; p belongs on t0
       (: t1 (apon (apon t0 p) (invert p)) (teq t1 t0 '(x y)))       ; apply;unpull == id
       (leq p (invert (invert p)))))                                 ; invert involutive

 ; (L3a) independent patches are ORDER-FREE (the semantic heart -- what makes merge
 ;       and cherry-pick sound): both pull orders land the same tree.
 _ (: a (apon (apon 0 px) py) b (apon (apon 0 py) px)
      (assert (teq a b '(x y)) (= 1 (tget a 'x)) (= 2 (tget a 'y))))

 ; (L3b) a FRONTIER is stable under swapping two adjacent independent patches -- the
 ;       reproducibility tie: meaning is order-free, so the (unordered) patch set is
 ;       a sound version identity. and the distribution face: two disjoint COMPONENTS
 ;       install to the same frontier whichever is pulled first.
 _ (: pre (link (chg 'a 0 7) 0) post (link (chg 'b 0 8) 0)
      f1 (applall 0 (cat2 pre (link px (link py post))))             ; pre ++ [px py] ++ post
      f2 (applall 0 (cat2 pre (link py (link px post))))             ; ...px,py swapped
      _ (assert (teq f1 f2 '(a b x y)))
      (: holo (link (chg 'holo 0 1) 0) glaze (link (chg 'glaze 0 1) 0)
         (assert (teq (applall 0 (cat2 holo glaze))
                      (applall 0 (cat2 glaze holo)) '(holo glaze)))))
 0)
