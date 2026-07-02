; --- boot/wm.l: a runnable smoke test for the wm app's socket nif (host/wm.c) ---
; Standalone against the built binary, like boot/net.l and for the same reason
; (host/*.c links the final `ai` only; ai0 bakes the corpus without it):
;
;   cat test/00-init.l boot/wm.l | out/host/ai
;
; (connectu path) opens a unix-domain stream socket. A REAL round trip needs a
; unix listener on the other end -- that is an X display socket in practice, so
; the integration proof lives in the wm spikes (doc/proto/wm.l against Xephyr),
; not the gate. Here: the nif is present and every refusal lane answers nil,
; not a scare -- absence is nothing.
(assert (lit? connectu))
(assert !(connectu "/nonexistent/never/sock"))     ; no such path -> nil
(assert !(connectu ""))                            ; empty path -> nil
(assert !(connectu "/tmp"))                        ; a directory, not a socket -> nil
(assert !(connectu 7))                             ; not a string -> nil
(say err "boot/wm: ok\n")
