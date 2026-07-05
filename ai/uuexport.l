; ai/uuexport.l -- the uu module boundary (the holo/glaze pattern): every name
; the kernel span leaked since `uu-mark` sweeps off the global book into ONE
; book pinned under `uu` -- the surface is (uu 'vof), (uu 'defn), (uu 'chk),
; and every internal stays a probe away. Baked right after out/lib/uukern.l
; (the Makefile composes a names-mark + test/uu.l's kernel span -- the corpus
; file stays the one source of truth; nothing here edits it). The span defines
; only NEW names (probed: 31, zero rebinds of pre-existing globals), so the
; host book grows by exactly one name: `uu`.
(: seen (: t (tablet 0) _ (each uu-mark (\ k (pin t k 1))) t)
   uum (tablet 0)
   _ (each (names ())
      (\ k (? (peep seen k 0) 0
              (: v (peep book k 0) _ (pull book k 0) (pin uum k v)))))
   _ (pull book 'uu-mark 0)
   _ (pull uum 'uu-mark 0)
   _ (pin book 'uu uum)
   0)
