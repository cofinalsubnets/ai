; arm64 CALL-OUT EXECUTION -- run ONLY under qemu-aarch64 (tools/arm64check.sh), NEVER in the x86
; corpus: it builds nifs with `jitcalloutx ... 'arm64`, whose code is aarch64 bytes -- calling one on
; x86 jumps into arm64 machine code (a fault). It lives in test/arm64/ (a subfolder), so the
; non-recursive test/*.l corpus glob (make test / ai0 bake) never sees it. arm64check cats it in.
;
; Proves the stackless call-out bridge (emit.l calloutir/calloutframeir) EXECUTES correctly on aarch64:
; the near pc-relative resume address (`lar` -> ADR, translation-invariant in the word-aligned mmap blob,
; where la's page-relative ADRP would mis-page) and the tagged-accumulator overflow gate (the fixnum TAG
; boundary at 2^62, not the 64-bit 2^63). == the interpreter across fast path, empty, the [2^62,2^63)
; window, past 2^63, and the float (gate 1) deopt -- both the DIRECT emit and the AUTO-glaze (natjit hook).

; --- direct emit: build the aarch64 nif by hand and run it ---
(: G glaze  jitcalloutx (G 'jitcalloutx)
   (ca-sq i)   (* i i)
   (ca-half i) (* i 0.5)
   ca-src   '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (ca-sq i)))   a)) 0 0))
   caf-src  '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (ca-half i))) a)) 0 0))
   nat  (jitcalloutx ca-sq   ca-src  'arm64)      ; native aarch64 call-out
   natf (jitcalloutx ca-half caf-src 'arm64)
   r3m ((: (go i a) (? (< i 3000000) (go (+ i 1) (+ a (ca-sq i))) a)) 0 0)   ; interp reference (inline sum; a closure never glazed -> pure interp) for the boundary case
   ; NB: STRICT PREFIX `(= a b)` throughout -- opfix currently mis-factors compound=compound infix
   ; (((f x) = (g y)) -> (f (= x (g y)))), so prefix sidesteps it entirely (opfix fix is a follow-up).
   _ (assert
       (= 0 (nat 0))                                 ; empty
       (= 285 (nat 10))                              ; fixnum fast path
       (= 2666664666667000000 (nat 2000000))         ; ~2.6e15 fixnum
       (= 8999995500000500000 (nat 3000000))         ; [2^62,2^63): tag-overflow -> bignum (garbage on the untagged gate)
       (= (nat 3000000) r3m)                          ; ... == interp
       (= 333333283333335000000 (nat 10000000))      ; ~3.3e20, well past 2^63
       (= 95.0 (natf 20))))                           ; GATE 1: float call-out result -> deopt to interp twin, gem

; --- auto-glaze: the natjit hook (now installed on aarch64) glazes these at closure creation, no manual
; jitcalloutx. ag-sum is a top-level GLOBAL-F sum (hook's calloutinfo -> jitcalloutx arch); ag-summer
; returns an EMBEDDED captured closure (only the hook catches it -> njit-calloutframe arch, the frame-read
; F + hand-rolled lvm_ret, the genuinely-new aarch64 path). == interp across the same fast/gate cases.
(: (ag-sq i)  (* i i)
   (ag-half i) (* i 0.5)
   (ag-sum n)  ((: (go i a) (? (< i n) (go (+ i 1) (+ a (ag-sq i))) a)) 0 0)          ; global-F: hook -> jitcalloutx arch
   (ag-summer f) (\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (f i))) a)) 0 0))      ; captured: hook -> njit-calloutframe arch
   cs (ag-summer ag-sq)  cf (ag-summer ag-half)
   ag30 (ag-sum 30)                                                                  ; global reference for the captured==global cross-check
   _ (assert
       (= 285 (ag-sum 10)) (= 0 (ag-sum 0))                                          ; global auto-glaze fast path + empty
       (= 8555 (ag-sum 30))                                                          ; global auto-glaze == 0+1+4+..+841
       (= 8999995500000500000 (ag-sum 3000000))                                      ; global gate-2 boundary -> bignum
       (= 285 (cs 10)) (= 0 (cs 0)) (= 8555 (cs 30))                                 ; captured auto-glaze fast path
       (= (cs 30) ag30)                                                              ; captured == global
       (= 8999995500000500000 (cs 3000000))                                          ; captured gate-2 boundary -> bignum
       (= 95.0 (cf 20)))                                                             ; captured gate-1 float
   (say err "test/arm64/callout: aarch64 call-out execution (direct + auto-glaze, lar/ADR resume + tagged-accumulator gate) ok\n"))
