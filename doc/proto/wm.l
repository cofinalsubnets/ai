; wm -- rung 2 of the xmonad-in-ai port: BECOME the window manager. Rides the
; x11.l wire codec (rung 1) over the REAL door -- the unix display socket via
; the wm app's (connectu path) nif (host/wm.c) -- no TCP, exactly how a real
; session would run. The WM handshake is one request: ChangeWindowAttributes on
; the ROOT selecting SubstructureRedirect|SubstructureNotify -- from then on no
; client can map/resize a top-level without the server ASKING US (MapRequest /
; ConfigureRequest). We manage the first client the xmonad way, degenerate
; case: one window, full screen (Tall of one). run against `Xephyr :7 -ac`:
;   out/host/ai doc/proto/wm.l &  then  DISPLAY=:7 xterm
; the Access error (code 10) on the redirect means another WM owns the display.
(: s (connectu "/tmp/.X11-unix/X7")
   _ (? s 0 (: _ (say err "wm: no display socket /tmp/.X11-unix/X7 -- Xephyr up?\n") (nap 1)))
   (line m) (: _ (say out m) _ (say out "\n") (flush out))

   ; --- the codec (x11.l's helpers) ---
   (w8 v)   (put s v)
   (w16 v)  (: _ (put s (& 255 v)) (put s (& 255 (>> v 8))))
   (w32 v)  (: _ (w16 (& 65535 v)) (w16 (& 65535 (>> v 16))))
   (r8 u)   (get s)
   (r16 u)  (: a (get s) b (get s) (| a (<< b 8)))
   (r32 u)  (: a (r16 ()) b (r16 ()) (| a (<< b 16)))
   (skip n) (: (go i) (? (< i n) (: _ (get s) (go (+ i 1))) 0) (go 0))
   (rstr n) (: (go i acc) (? (< i n) (go (+ i 1) (+ acc (get s))) acc) (go 0 ""))
   (pad4 n) (% (- 4 (% n 4)) 4)

   ; --- handshake + setup parse (only what the wm needs) ---
   _ (w8 108) _ (w8 0) _ (w16 11) _ (w16 0) _ (w16 0) _ (w16 0) _ (w16 0)
   _ (flush s)
   st (r8 ())
   _ (? (= st 1) 0
        (: rlen (r8 ()) _ (skip 6) why (rstr rlen)
           _ (say err (+ "wm: setup refused: " (+ why "\n"))) (nap 1)))
   _ (r8 ()) _ (r16 ()) _ (r16 ())
   alen (r16 ())
   _ (r32 ()) idbase (r32 ()) idmask (r32 ()) _ (r32 ())
   vlen (r16 ()) _ (r16 ())
   nscr (r8 ()) nfmt (r8 ())
   _ (skip 10)
   _ (skip (+ vlen (pad4 vlen)))
   _ (skip (* 8 nfmt))
   root (r32 ()) _ (r32 ()) _ (r32 ()) _ (r32 ()) _ (r32 ())
   wpx (r16 ()) hpx (r16 ())
   _ (skip (- (* 4 alen) (+ 32 (+ (+ vlen (pad4 vlen)) (+ (* 8 nfmt) 24)))))

   ; --- request writers ---
   (cwa-events win mask)                            ; ChangeWindowAttributes: CWEventMask only
    (: _ (w8 2) _ (w8 0) _ (w16 4) _ (w32 win) _ (w32 2048) (w32 mask))
   (configure win x y w h)                          ; ConfigureWindow: x y w h border (mask 0x1F)
    (: _ (w8 12) _ (w8 0) _ (w16 8) _ (w32 win) _ (w16 31) _ (w16 0)
       _ (w32 x) _ (w32 y) _ (w32 w) _ (w32 h) (w32 0))
   (mapwin win) (: _ (w8 8) _ (w8 0) _ (w16 2) (w32 win))

   ; --- become the wm: redirect the root's substructure. no reply on success;
   ;     an Access error (code 10) arrives if another wm already holds it, so
   ;     round-trip an InternAtom as the sync point -- its reply = we are in.
   _ (cwa-events root 1572864)                      ; SubstructureRedirect|SubstructureNotify
   _ (w8 16) _ (w8 0) _ (w16 5) _ (w16 12) _ (w16 0)
   _ (: (go i) (? (< i 12) (: _ (put s ("WM_PROTOCOLS" i)) (go (+ i 1))) 0) (go 0))
   _ (flush s)
   b0 (r8 ())
   _ (? (= b0 1) (skip 31)
        (: code (r8 ()) _ (skip 30)
           _ (say err (? (= code 10) "wm: another wm owns this display (Access)\n"
                         (+ "wm: X error at redirect, code " (+ (show code) "\n"))))
           (nap 1)))
   _ (line (+ "wm: managing root " (+ (show root) (+ " (" (+ (show wpx) (+ "x" (+ (show hpx) ")")))))))

   ; --- the event loop: honor ConfigureRequests, manage the first MapRequest
   ;     fullscreen (Tall of one), then confirm its MapNotify and hold.
   (dispatch won)                                    ; won = the managed window | 0
    (: b0 (r8 ())
       (? (= b0 0)
          (: code (r8 ()) _ (skip 30)
             _ (line (+ "wm: X error, code " (show code))) (dispatch won))
          (: code (& 127 b0)
             (? (= code 20)                          ; MapRequest: parent, window
                (: _ (r8 ()) _ (r16 ()) _ (r32 ()) win (r32 ()) _ (skip 20)
                   _ (configure win 0 0 wpx hpx)     ; the layout: one window, the whole screen
                   _ (mapwin win)
                   _ (flush s)
                   _ (line (+ "wm: managed " (+ (show win) (+ " -> 0,0 " (+ (show wpx) (+ "x" (show hpx)))))))
                   (dispatch win))
                (= code 23)                          ; ConfigureRequest: pre-map geometry ask
                (: _ (r8 ()) _ (r16 ()) _ (r32 ()) win (r32 ()) _ (skip 4)
                   x (r16 ()) y (r16 ()) w (r16 ()) h (r16 ()) _ (r16 ())
                   _ (r16 ()) _ (skip 4)
                   _ (configure win x y w h)         ; pre-manage: grant it verbatim
                   _ (flush s)
                   _ (line (+ "wm: granted configure for " (show win)))
                   (dispatch won))
                (&& (= code 19) (! (= won 0)))       ; MapNotify for the managed one: proof
                (: _ (skip 31)
                   _ (line (+ "wm: " (+ (show won) " is up -- holding 6s (xwininfo -display :7)")))
                   won)
                (: _ (skip 31) (dispatch won))))))   ; other Substructure noise: skip
   w (dispatch 0)
   _ (rest 6000)
   _ (close s)
   (line "wm: done"))
