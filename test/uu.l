; uu -- a univalent kernel: MLTT with the UniMath Preamble's seven inductives
; (empty unit bool coprod nat paths total2), bidirectional checking, NbE
; conversion (de bruijn levels as fresh vars, sigma- and pi-eta), type-in-type --
; the universe stance of the reference (UniMath/Foundations/Init.v: Unset
; Universe Checking). an axiom is a book entry with a type and no value: a
; sanctioned anon. names follow UniMath so the port reads literally.
;
; terms are quoted lists: UU nat bool unit empty zero tt true false <fixnum>
;   (pi x A B) (lam x b) (total2 x A B) (tpair a b) (pr1 w) (pr2 w) (succ n)
;   (coprod A B) (ii1 a) (ii2 b) (paths A a b) (idpath a) (the T t)
;   (nat_rect P z s n) (bool_rect P t f b) (unit_rect P u x)
;   (coprod_rect P f g v) (empty_rect P e) (paths_rect P pr e)
; and any other list is an application spine. (f) == f here too.

; --- the kernel: values, evaluation, conversion, checking ---
(: GLOB (tablet 0) TRAPC (tablet 0)

   (tagv v) (? (twop v) (cap v) v)
   (e2 l) (cap (cbp l))
   (e3 l) (cap (cbp (cbp l)))
   (e4 l) (cap (cbp (cbp (cbp l))))
   (e5 l) (cap (cbp (cbp (cbp (cbp l))))))

(: (vsucc v) (? (fixp v) (v + 1) (L 'succ v))

   (capp cl v) (vof (cons (L (e3 cl) v) (e2 cl)) (e4 cl))

   (vapp f a) (? (idp (tagv f) 'lam) (capp (e2 f) a) (L 'na f a))

   (dop1 v) (? (idp (tagv v) 'pair) (e2 v) (L 'np1 v))
   (dop2 v) (? (idp (tagv v) 'pair) (e3 v) (L 'np2 v))

   (donr P z s m)
   (? (fixp m) (: (go k acc) (? (k = m) acc (go (k + 1) (vapp (vapp s k) acc)))
                  (go 0 z))
      (idp (tagv m) 'succ) (vapp (vapp s (e2 m)) (donr P z s (e2 m)))
      (L 'nnr P z s m))

   (dobr P x y v) (? (idp v 'true) x (idp v 'false) y (L 'nbr P x y v))
   (dour P x v) (? (idp v 'tt) x (L 'nur P x v))
   (docr P f g v) (? (idp (tagv v) 'i1) (vapp f (e2 v))
                     (idp (tagv v) 'i2) (vapp g (e2 v))
                     (L 'ncr P f g v))
   (doer P v) (L 'ner P v)
   (dojr P r ev) (? (idp (tagv ev) 'refl) r (L 'njr P r ev))

   (vof-sym en x)
   (: e (assq x en)
      (? e (e2 e)
         (: g (peep GLOB x 0)
            (? g (e2 g) (scare 'uu-unbound x)))))

   (vof en t)
   (? (fixp t) t
      (symp t) (? (memq t '(UU nat bool unit empty tt true false)) t
                  (idp t 'zero) 0
                  (vof-sym en t))
      (: h (cap t)
         (? (twop h) (vof-spine en (vof en h) (cbp t))
            (idp h 'lam)    (L 'lam (L 'clo en (e2 t) (e3 t)))
            (idp h 'pi)     (L 'pi  (vof en (e3 t)) (L 'clo en (e2 t) (e4 t)))
            (idp h 'total2) (L 'sig (vof en (e3 t)) (L 'clo en (e2 t) (e4 t)))
            (idp h 'tpair)  (L 'pair (vof en (e2 t)) (vof en (e3 t)))
            (idp h 'pr1)    (dop1 (vof en (e2 t)))
            (idp h 'pr2)    (dop2 (vof en (e2 t)))
            (idp h 'succ)   (vsucc (vof en (e2 t)))
            (idp h 'coprod) (L 'coprod (vof en (e2 t)) (vof en (e3 t)))
            (idp h 'ii1)    (L 'i1 (vof en (e2 t)))
            (idp h 'ii2)    (L 'i2 (vof en (e2 t)))
            (idp h 'paths)  (L 'paths (vof en (e2 t)) (vof en (e3 t)) (vof en (e4 t)))
            (idp h 'idpath) (L 'refl (vof en (e2 t)))
            (idp h 'the)    (vof en (e3 t))
            (idp h 'nat_rect)    (donr (vof en (e2 t)) (vof en (e3 t)) (vof en (e4 t)) (vof en (e5 t)))
            (idp h 'bool_rect)   (dobr (vof en (e2 t)) (vof en (e3 t)) (vof en (e4 t)) (vof en (e5 t)))
            (idp h 'unit_rect)   (dour (vof en (e2 t)) (vof en (e3 t)) (vof en (e4 t)))
            (idp h 'coprod_rect) (docr (vof en (e2 t)) (vof en (e3 t)) (vof en (e4 t)) (vof en (e5 t)))
            (idp h 'empty_rect)  (doer (vof en (e2 t)) (vof en (e3 t)))
            (idp h 'paths_rect)  (dojr (vof en (e2 t)) (vof en (e3 t)) (vof en (e4 t)))
            (vof-spine en (vof en h) (cbp t)))))

   (vof-spine en f as)
   (? !as f (vof-spine en (vapp f (vof en (cap as))) (cbp as)))

   (conv d a b)
   (? (&& (fixp a) (fixp b)) (a = b)
      (&& (symp a) (symp b)) (idp a b)
      (|| (idp (tagv a) 'lam) (idp (tagv b) 'lam))
      (: fr (L 'nv d) (conv (d + 1) (vapp a fr) (vapp b fr)))
      (&& (idp (tagv a) 'pair) (twop b) !(idp (cap b) 'pair))
      (&& (conv d (e2 a) (dop1 b)) (conv d (e3 a) (dop2 b)))
      (&& (idp (tagv b) 'pair) (twop a) !(idp (cap a) 'pair))
      (&& (conv d (dop1 a) (e2 b)) (conv d (dop2 a) (e3 b)))
      (&& (idp (tagv a) 'pi) (idp (tagv b) 'pi))
      (&& (conv d (e2 a) (e2 b))
          (: fr (L 'nv d) (conv (d + 1) (capp (e3 a) fr) (capp (e3 b) fr))))
      (&& (idp (tagv a) 'sig) (idp (tagv b) 'sig))
      (&& (conv d (e2 a) (e2 b))
          (: fr (L 'nv d) (conv (d + 1) (capp (e3 a) fr) (capp (e3 b) fr))))
      (&& (twop a) (twop b) (idp (cap a) (cap b))) (conv-args d (cbp a) (cbp b))
      0)

   (conv-args d as bs)
   (? (&& !as !bs) 1
      (|| !as !bs) 0
      (&& (conv d (cap as) (cap bs)) (conv-args d (cbp as) (cbp bs))))

   (inf-sym cx x)
   (? (idp x 'UU) 'UU
      (memq x '(nat bool unit empty)) 'UU
      (idp x 'zero) 'nat
      (idp x 'tt) 'unit
      (memq x '(true false)) 'bool
      (: e (assq x cx)
         (? e (e2 e)
            (: g (peep GLOB x 0)
               (? g (cap g) (scare 'uu-unbound x))))))

   (inf-spine cx en d f as)
   (? !as f
      (idp (tagv f) 'pi)
      (: a (cap as)
         _ (chk cx en d a (e2 f))
         (inf-spine cx en d (capp (e3 f) (vof en a)) (cbp as)))
      (scare 'uu-not-a-pi as))

   (chk cx en d t T)
   (? (&& (twop t) (idp (cap t) 'lam))
      (? (idp (tagv T) 'pi)
         (: x (e2 t) fr (L 'nv d)
            (chk (cons (L x (e2 T)) cx) (cons (L x fr) en) (d + 1)
                 (e3 t) (capp (e3 T) fr)))
         (scare 'uu-lam-needs-pi t))
      (&& (twop t) (idp (cap t) 'tpair))
      (? (idp (tagv T) 'sig)
         (: _ (chk cx en d (e2 t) (e2 T))
            (chk cx en d (e3 t) (capp (e3 T) (vof en (e2 t)))))
         (scare 'uu-tpair-needs-total2 t))
      (&& (twop t) (idp (cap t) 'ii1))
      (? (idp (tagv T) 'coprod) (chk cx en d (e2 t) (e2 T)) (scare 'uu-ii1-needs-coprod t))
      (&& (twop t) (idp (cap t) 'ii2))
      (? (idp (tagv T) 'coprod) (chk cx en d (e2 t) (e3 T)) (scare 'uu-ii2-needs-coprod t))
      (&& (twop t) (idp (cap t) 'idpath))
      (? (idp (tagv T) 'paths)
         (: _ (chk cx en d (e2 t) (e2 T))
            v (vof en (e2 t))
            (? (&& (conv d v (e3 T)) (conv d v (e4 T))) 1 (scare 'uu-idpath-mismatch t)))
         (scare 'uu-idpath-needs-paths t))
      (: Ti (inf cx en d t)
         (? (conv d T Ti) 1 (scare 'uu-type-mismatch t))))

   (inf cx en d t)
   (? (fixp t) 'nat
      (symp t) (inf-sym cx t)
      (: h (cap t)
         (? (twop h) (inf-spine cx en d (inf cx en d h) (cbp t))
            (idp h 'pi)
            (: x (e2 t)
               _ (chk cx en d (e3 t) 'UU)
               fr (L 'nv d)
               _ (chk (cons (L x (vof en (e3 t))) cx) (cons (L x fr) en) (d + 1) (e4 t) 'UU)
               'UU)
            (idp h 'total2)
            (: x (e2 t)
               _ (chk cx en d (e3 t) 'UU)
               fr (L 'nv d)
               _ (chk (cons (L x (vof en (e3 t))) cx) (cons (L x fr) en) (d + 1) (e4 t) 'UU)
               'UU)
            (idp h 'coprod)
            (: _ (chk cx en d (e2 t) 'UU) _ (chk cx en d (e3 t) 'UU) 'UU)
            (idp h 'paths)
            (: _ (chk cx en d (e2 t) 'UU)
               Av (vof en (e2 t))
               _ (chk cx en d (e3 t) Av)
               _ (chk cx en d (e4 t) Av)
               'UU)
            (idp h 'succ) (: _ (chk cx en d (e2 t) 'nat) 'nat)
            (idp h 'idpath)
            (: Av (inf cx en d (e2 t)) v (vof en (e2 t)) (L 'paths Av v v))
            (idp h 'pr1)
            (: S (inf cx en d (e2 t))
               (? (idp (tagv S) 'sig) (e2 S) (scare 'uu-pr1-needs-total2 t)))
            (idp h 'pr2)
            (: S (inf cx en d (e2 t))
               (? (idp (tagv S) 'sig) (capp (e3 S) (dop1 (vof en (e2 t))))
                  (scare 'uu-pr2-needs-total2 t)))
            (idp h 'the)
            (: _ (chk cx en d (e2 t) 'UU)
               Tv (vof en (e2 t))
               _ (chk cx en d (e3 t) Tv)
               Tv)
            (idp h 'nat_rect)
            (: P (e2 t)
               _ (chk cx en d (e5 t) 'nat)
               _ (chk cx en d P (vof 0 '(pi x nat UU)))
               Pv (vof en P)
               _ (chk cx en d (e3 t) (vapp Pv 0))
               _ (chk cx en d (e4 t)
                      (vof (L (L 'P Pv)) '(pi k nat (pi r (P k) (P (succ k))))))
               (vapp Pv (vof en (e5 t))))
            (idp h 'bool_rect)
            (: P (e2 t)
               _ (chk cx en d (e5 t) 'bool)
               _ (chk cx en d P (vof 0 '(pi x bool UU)))
               Pv (vof en P)
               _ (chk cx en d (e3 t) (vapp Pv 'true))
               _ (chk cx en d (e4 t) (vapp Pv 'false))
               (vapp Pv (vof en (e5 t))))
            (idp h 'unit_rect)
            (: P (e2 t)
               _ (chk cx en d (e4 t) 'unit)
               _ (chk cx en d P (vof 0 '(pi x unit UU)))
               Pv (vof en P)
               _ (chk cx en d (e3 t) (vapp Pv 'tt))
               (vapp Pv (vof en (e4 t))))
            (idp h 'empty_rect)
            (: P (e2 t)
               _ (chk cx en d (e3 t) 'empty)
               _ (chk cx en d P (vof 0 '(pi x empty UU)))
               (vapp (vof en P) (vof en (e3 t))))
            (idp h 'coprod_rect)
            (: S (inf cx en d (e5 t))
               (? (idp (tagv S) 'coprod)
                  (: A (e2 S) B (e3 S) P (e2 t)
                     _ (chk cx en d P
                            (vof (L (L 'A A) (L 'B B)) '(pi x (coprod A B) UU)))
                     Pv (vof en P)
                     _ (chk cx en d (e3 t)
                            (vof (L (L 'A A) (L 'P Pv)) '(pi a A (P (ii1 a)))))
                     _ (chk cx en d (e4 t)
                            (vof (L (L 'B B) (L 'P Pv)) '(pi b B (P (ii2 b)))))
                     (vapp Pv (vof en (e5 t))))
                  (scare 'uu-coprod_rect t)))
            (idp h 'paths_rect)
            (: E (inf cx en d (e4 t))
               (? (idp (tagv E) 'paths)
                  (: A (e2 E) av (e3 E) bv (e4 E) P (e2 t)
                     _ (chk cx en d P
                            (vof (L (L 'A A) (L 'a av)) '(pi b A (pi e (paths A a b) UU))))
                     Pv (vof en P)
                     _ (chk cx en d (e3 t) (vapp (vapp Pv av) (L 'refl av)))
                     (vapp (vapp Pv bv) (vof en (e4 t))))
                  (scare 'uu-paths_rect t)))
            (memq h '(lam tpair ii1 ii2)) (scare 'uu-cannot-infer t)
            (inf-spine cx en d (inf-sym cx h) (cbp t))))))

; --- drivers: a definition is checked then pinned; an axiom is a book entry
; --- with a type and no value (its value is its own neutral name); rejects
; --- runs a thunk expecting the kernel to refuse (the trap cell escapes).
(: (defn nm T t)
   (: _ (chk 0 0 0 T 'UU)
      Tv (vof 0 T)
      _ (chk 0 0 0 t Tv)
      _ (pin GLOB nm (L Tv (vof 0 t)))
      nm)
   (axm nm T)
   (: _ (chk 0 0 0 T 'UU)
      _ (pin GLOB nm (L (vof 0 T) (L 'nv nm)))
      nm)
   (rejects th)
   (: r (call-cc (\ k (: _ (pin TRAPC () (\ s a b (k 'rejected)))
                         v (th 0)
                         'accepted)))
      _ (pin TRAPC () 0)
      r))

; --- UniMath Foundations PartA, the core slice: every name is the original.
(assert
 (defn 'idfun '(pi T UU (pi x T T)) '(lam T (lam x x)))
 (defn 'funcomp
   '(pi X UU (pi Y UU (pi Z UU (pi f (pi x X Y) (pi g (pi y Y Z) (pi x X Z))))))
   '(lam X (lam Y (lam Z (lam f (lam g (lam x (g (f x)))))))))
 (defn 'iscontr '(pi T UU UU) '(lam T (total2 c T (pi t T (paths T t c)))))
 (defn 'hfiber
   '(pi X UU (pi Y UU (pi f (pi x X Y) (pi y Y UU))))
   '(lam X (lam Y (lam f (lam y (total2 x X (paths Y (f x) y)))))))
 (defn 'isweq
   '(pi X UU (pi Y UU (pi f (pi x X Y) UU)))
   '(lam X (lam Y (lam f (pi y Y (iscontr (hfiber X Y f y)))))))
 (defn 'weq '(pi X UU (pi Y UU UU))
   '(lam X (lam Y (total2 f (pi x X Y) (isweq X Y f)))))
 (defn 'transportf
   '(pi A UU (pi P (pi x A UU) (pi a A (pi b A (pi e (paths A a b) (pi p (P a) (P b)))))))
   '(lam A (lam P (lam a (lam b (lam e
      (paths_rect (lam bp (lam ep (pi p (P a) (P bp)))) (lam p p) e)))))))
 (defn 'pathsinv0
   '(pi A UU (pi a A (pi b A (pi e (paths A a b) (paths A b a)))))
   '(lam A (lam a (lam b (lam e
      (paths_rect (lam bp (lam ep (paths A bp a))) (idpath a) e))))))
 (defn 'pathscomp0
   '(pi A UU (pi a A (pi b A (pi c A (pi e1 (paths A a b) (pi e2 (paths A b c) (paths A a c)))))))
   '(lam A (lam a (lam b (lam c (lam e1 (lam e2
      (paths_rect (lam cp (lam ep (paths A a cp))) e1 e2))))))))
 (defn 'maponpaths
   '(pi A UU (pi B UU (pi f (pi x A B) (pi a A (pi b A (pi e (paths A a b) (paths B (f a) (f b))))))))
   '(lam A (lam B (lam f (lam a (lam b (lam e
      (paths_rect (lam bp (lam ep (paths B (f a) (f bp)))) (idpath (f a)) e))))))))
 (defn 'unitpath '(pi u unit (paths unit u tt))
   '(lam u (unit_rect (lam v (paths unit v tt)) (idpath tt) u)))
 (defn 'iscontrunit '(iscontr unit) '(tpair tt (lam t (unitpath t))))
 (defn 'proofirrelevancecontr
   '(pi X UU (pi i (iscontr X) (pi x X (pi y X (paths X x y)))))
   '(lam X (lam i (lam x (lam y
      (pathscomp0 X x (pr1 i) y ((pr2 i) x) (pathsinv0 X y (pr1 i) ((pr2 i) y))))))))
 (defn 'fromempty '(pi P UU (pi e empty P)) '(lam P (lam e (empty_rect (lam x P) e))))
 (defn 'negb '(pi b bool bool) '(lam b (bool_rect (lam x bool) false true b)))
 (defn 'add '(pi n nat (pi m nat nat))
   '(lam n (lam m (nat_rect (lam x nat) m (lam k (lam r (succ r))) n)))))

; the eliminators COMPUTE: proofs by idpath are proofs by evaluation.
(assert
 (defn 'uu-two-plus-two '(paths nat (add 2 2) 4) '(idpath 4))
 (defn 'uu-negb-true '(paths bool (negb true) false) '(idpath false))
 (defn 'uu-fromsum '(pi v (coprod nat bool) nat)
   '(lam v (coprod_rect (lam x nat) (lam a a) (lam b (bool_rect (lam x nat) 1 0 b)) v)))
 (defn 'uu-fromsum-ii2 '(paths nat (uu-fromsum (ii2 true)) 1) '(idpath 1))
 (4 = (vof 0 '(add 2 2))))

; the crown: the identity is a weak equivalence (PartA idisweq -- the proof
; needs sigma-eta), the inverse falls out of contractible fibers, and
; univalence is the axiom over a checked eqweqmap, exactly UnivalenceAxiom.v.
(assert
 (defn 'idisweq '(pi T UU (isweq T T (idfun T)))
   '(lam T (lam y (tpair (tpair y (idpath y))
      (lam t (paths_rect
        (lam bp (lam ep (paths (hfiber T T (idfun T) bp)
                               (tpair (pr1 t) ep)
                               (tpair bp (idpath bp)))))
        (idpath (tpair (pr1 t) (idpath (pr1 t))))
        (pr2 t)))))))
 (defn 'idweq '(pi T UU (weq T T)) '(lam T (tpair (lam x x) (idisweq T))))
 (defn 'eqweqmap '(pi X UU (pi Y UU (pi e (paths UU X Y) (weq X Y))))
   '(lam X (lam Y (lam e (paths_rect (lam Yp (lam ep (weq X Yp))) (idweq X) e)))))
 (axm 'univalenceAxiom
   '(pi X UU (pi Y UU (isweq (paths UU X Y) (weq X Y) (eqweqmap X Y)))))
 (axm 'funextemptyAxiom
   '(pi X UU (pi f (pi x X empty) (pi g (pi x X empty) (paths (pi x X empty) f g)))))
 (defn 'uu-eqweqmap-idpath
   '(pi X UU (paths (weq X X) (eqweqmap X X (idpath X)) (idweq X)))
   '(lam X (idpath (idweq X))))
 (defn 'invmap
   '(pi X UU (pi Y UU (pi w (weq X Y) (pi y Y X))))
   '(lam X (lam Y (lam w (lam y (pr1 (pr1 ((pr2 w) y))))))))
 (defn 'homotweqinvweq
   '(pi X UU (pi Y UU (pi w (weq X Y) (pi y Y (paths Y ((pr1 w) (invmap X Y w y)) y)))))
   '(lam X (lam Y (lam w (lam y (pr2 (pr1 ((pr2 w) y)))))))))

; the h-level ladder grounded at iscontr by nat-recursion (PartB isofhlevel;
; the motive lands in UU -> UU), the bridges holding DEFINITIONALLY, and
; Propositions.v's impredicative truncation: no higher inductive anywhere.
(assert
 (defn 'isaprop '(pi X UU UU)
   '(lam X (pi x X (pi y X (iscontr (paths X x y))))))
 (defn 'isaset '(pi X UU UU)
   '(lam X (pi x X (pi y X (isaprop (paths X x y))))))
 (defn 'isofhlevel '(pi n nat (pi X UU UU))
   '(lam n (nat_rect (lam q (pi X UU UU))
                     iscontr
                     (lam k (lam rec (lam X (pi x X (pi y X (rec (paths X x y)))))))
                     n)))
 (defn 'uu-isaprop-is-level1
   '(pi X UU (paths UU (isaprop X) (isofhlevel 1 X)))
   '(lam X (idpath (isaprop X))))
 (defn 'uu-isaset-is-level2
   '(pi X UU (paths UU (isaset X) (isofhlevel 2 X)))
   '(lam X (idpath (isaset X))))
 (defn 'hProp 'UU '(total2 X UU (isaprop X)))
 (defn 'hSet 'UU '(total2 X UU (isaset X)))
 (defn 'ishinh '(pi X UU UU)
   '(lam X (pi P hProp (pi f (pi x X (pr1 P)) (pr1 P)))))
 (defn 'hinhpr '(pi X UU (pi x X (ishinh X)))
   '(lam X (lam x (lam P (lam f (f x))))))
 (defn 'hinhuniv
   '(pi X UU (pi P hProp (pi f (pi x X (pr1 P)) (pi w (ishinh X) (pr1 P)))))
   '(lam X (lam P (lam f (lam w (w P f)))))))

; --- the kernel refuses: ill-typed terms scare; the trap cell catches them.
; --- (install per the trap law -- more/eof keep the read protocol.)
(: (trap s p e) (? (more? s) p (eof? s) e
                   (: h (peep TRAPC () 0) (? h (h s p e) 0))))
(assert
 (idp 'rejected (rejects (\ z (defn 'uu-bad1 '(paths nat 1 2) '(idpath 1)))))
 (idp 'rejected (rejects (\ z (defn 'uu-bad2 '(pi x nat nat) '(lam x (succ y))))))
 (idp 'rejected (rejects (\ z (defn 'uu-bad3 'nat '(lam x x)))))
 (idp 'rejected (rejects (\ z (defn 'uu-bad4 '(coprod nat bool) '(ii1 true)))))
 (idp 'accepted (rejects (\ z (defn 'uu-good '(paths nat 2 2) '(idpath 2))))))
(: trap 0)
