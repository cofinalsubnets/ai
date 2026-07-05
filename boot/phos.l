; --- boot/phos.l: a runnable smoke test for phos's socket nif (host/phos.c) ---
; Standalone against the built binary, like boot/net.l and for the same reason
; (host/*.c links the final `ai` only; ai0 bakes the corpus without it):
;
;   cat test/00-init.l boot/phos.l | out/host/ai
;
; (connectu path) opens a unix-domain stream socket. A REAL round trip needs a
; unix listener on the other end -- that is an X display socket in practice, so
; the integration proof lives in the phos spikes (doc/proto/phos.l against Xephyr),
; not the gate. Here: the nif is present and every refusal lane answers nil,
; not a scare -- absence is nothing.
(assert (lit? connectu))
(assert !(connectu "/nonexistent/never/sock"))     ; no such path -> nil
(assert !(connectu ""))                            ; empty path -> nil
(assert !(connectu "/tmp"))                        ; a directory, not a socket -> nil
(assert !(connectu 7))                             ; not a string -> nil
(say err "boot/phos: ok\n")
