; --- boot/baotest.l: the editor + repl + parseall unit battery, bao-loaded ---
; the multi-line line editor (ed*), the history zipper (uphist/downhist/mkframe/
; detach), joinln/flatten/splitat, and parseall used to be USER-VISIBLE book
; globals only because the corpus (the old test/repl.l + test/replio.l) tested
; them by name. They now live INSIDE bao's closure (ai/bao.l), off the global
; book -- so the corpus can no longer reach them, and that is the point.
;
; bao still exercises them, from INSIDE the closure, via `bao-selftest` (a public
; entry that computes the whole boolean battery against the private helpers and
; returns the results as a flat list). bao is the BAKED shell core (in the host
; egg), so bao-selftest is a book global -- this file gates its list through the
; real test harness with no -l:
;
;   cat test/00-init.l boot/baotest.l | out/host/ai
;
; (wired into `make test_hostnif`.) green dots = pass.

(: results (bao-selftest 0)
   ; every check in the battery must be true.
   _ (each results (\ b (assert b)))
   ; and the battery must be non-trivial (a typo'd selftest returning () would
   ; vacuously pass the each above).
   _ (assert (< 50 (tally results))))

(puts "baotest: ok") (putc 10)
