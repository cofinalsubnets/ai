; --- boot/overlay.l: the wm type overlay + the baked uu book, end to end ---
; NOT in the test/*.l corpus (the overlay + uu ride the HOST binary's post-egg
; layer; ai0/kernel/wasm have no post.l). Three legs:
;   1. apps/wm/sigs.l checks CLEAN over the real core.l + layout.l sources
;      (read as DATA, checked pure with (overlay 'ov-check1) -- no install,
;      no eval, observe-only squared), and a deliberately wounded def is
;      flagged by name.
;   2. the gradual laws: an unknown arg rides into a typed seat; a partial
;      application reads open, not clashing (the curried language's law).
;   3. the uu book is baked and COMPUTES: (uu 'defn) type-checks a nat_rect
;      adder, (uu 'vof) normalizes 2+1=3 -- no concat, a bare binary.
;
;   cat test/00-init.l boot/overlay.l | out/host/ai

(reads (open "apps/wm/sigs.l" "r"))

(: (forms path) (: q (open path "r") e (mint 0)
                   ((: (g acc) (: r (sound q e) (? (= e r) (rev acc) (g (link r acc))))) ()))
   chk1 (overlay 'ov-check)
   (sweep path) (foldl (\ a f (cat a (chk1 wm-dom wm-sigs f))) () (forms path))

 ; leg 1: the shipped sources check clean...
 _ (assert (! (sweep "apps/wm/core.l"))
           (! (sweep "apps/wm/layout.l")))
 ; ...and a KNOWN kind in the wrong seat is caught: zins wants (window zipper),
 ; the wound hands it a tag and a sheaf
 hurt (chk1 wm-dom (link '(oops (sheaf tag) top) wm-sigs)
            '(: (oops s t) (zins (wstagof s t) s)))
 _ (assert (two? hurt) (id? 'oops (cap (cap hurt))))

 ; leg 2: the gradual laws
 sg2 (link '(g1 (rect) window) (link '(g2 (window) top) wm-sigs))
 _ (assert (! (chk1 wm-dom sg2 '(: (g1 r) (zfoc (cap r)))))       ; unknown arg: consistent
           (! (chk1 wm-dom sg2 '(: (g2 w) (zins w))))             ; partial app: open, not a clash
           (two? (chk1 wm-dom sg2 '(: (g1 r) (zfoc r)))))         ; a RECT in the zipper seat: flagged

 ; leg 3: uu, baked -- define, certify, compute
 _ ((uu 'defn) 'boot-add '(pi m nat (pi n nat nat))
               '(lam m (lam n (nat_rect (lam q nat) n (lam k (lam r (succ r))) m))))
 _ (assert (= 3 ((uu 'vof) () '(boot-add 2 1)))
           (= 5 ((uu 'vof) () '(boot-add 2 3)))))

; the kernel refuses through the help cell -- install the escape (test/uu.l's
; own tail move; the kernel span rightly bakes NO global help), probe, uninstall
(: (help s p e) (? (more? s) p (eof? s) e
                   (: h (peep (uu 'HELPC) () 0) (? h (h s p e) 0))))
(assert (id? 'rejected ((uu 'rejects) (\ z ((uu 'defn) 'boot-bad 'nat '(lam x x))))))
(: help 0)
(puts "overlay: ok")
