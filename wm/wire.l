; wm/wire.l -- the X11 wire protocol: connect, the setup handshake, request
; writers, the substructure redirect, keyboard mapping/grabs, and the event
; decoder. Host-only (needs the connectu nif, host/wm.c). Every op takes the
; socket port `s` EXPLICITLY -- so these leak as globals with no closure over a
; free `s` and no nif shadow (the codec's byte writers call the real `put`/`get`
; nifs, never a WM helper). A body-LESS `:` -- all of it leaks to the driver.
;
; The screen record `(x-setup s)` returns: (root wpx hpx minkc maxkc idbase).
; The event record `(x-next s)` returns: (code detail window state) -- enough for
; MapRequest/DestroyNotify/ConfigureRequest/MapNotify/KeyPress; () at EOF.
(:
   ; --- byte IO over the socket (little-endian) ---
   (x-w8 s v)  (put s v)
   (x-w16 s v) (: _ (put s (& 255 v)) (put s (& 255 (>> v 8))))
   (x-w32 s v) (: _ (x-w16 s (& 65535 v)) (x-w16 s (& 65535 (>> v 16))))
   (x-flush s) (flush s)
   (x-r8 s)  (get s)
   (x-r16 s) (: a (get s) b (get s) (| a (<< b 8)))
   (x-r32 s) (: a (x-r16 s) b (x-r16 s) (| a (<< b 16)))
   (x-skip s n) (: (go i) (? (< i n) (: _ (get s) (go (+ i 1))) 0) (go 0))
   (x-rstr s n) (: (go i acc) (? (< i n) (go (+ i 1) (+ acc (get s))) acc) (go 0 ""))
   (x-pad4 n) (% (- 4 (% n 4)) 4)
   (x-wname s t) (: (go i) (? (< i (tally t)) (: _ (put s (t i)) (go (+ i 1))) 0) (go 0))

   ; --- connect + the setup handshake -> the screen record | () ---
   (x-connect path) (connectu path)
   (x-setup s)
    (: _ (x-w8 s 108) _ (x-w8 s 0) _ (x-w16 s 11) _ (x-w16 s 0)
       _ (x-w16 s 0) _ (x-w16 s 0) _ (x-w16 s 0) _ (x-flush s)
       st (x-r8 s)
       (? (! (= st 1)) ()                                                       ; refused
          (: _ (x-r8 s) _ (x-r16 s) _ (x-r16 s)
             alen (x-r16 s)
             _ (x-r32 s) idbase (x-r32 s) _ (x-r32 s) _ (x-r32 s)
             vlen (x-r16 s) _ (x-r16 s)
             _ (x-r8 s) nfmt (x-r8 s)
             _ (x-skip s 4)
             minkc (x-r8 s) maxkc (x-r8 s)
             _ (x-skip s 4)
             _ (x-skip s (+ vlen (x-pad4 vlen)))
             _ (x-skip s (* 8 nfmt))
             root (x-r32 s) _ (x-r32 s) _ (x-r32 s) _ (x-r32 s) _ (x-r32 s)
             wpx (x-r16 s) hpx (x-r16 s)
             _ (x-skip s (- (* 4 alen) (+ 32 (+ (+ vlen (x-pad4 vlen)) (+ (* 8 nfmt) 24)))))
             (L root wpx hpx minkc maxkc idbase))))
   (scr-root sc) (cap sc)  (scr-w sc) (caup sc)  (scr-h sc) (caup (cup sc))
   (scr-mink sc) (nthl sc 3)  (scr-maxk sc) (nthl sc 4)  (scr-idbase sc) (nthl sc 5)

   ; --- requests ---
   (x-cwa-events s win mask)                                                     ; ChangeWindowAttributes: CWEventMask
    (: _ (x-w8 s 2) _ (x-w8 s 0) _ (x-w16 s 4) _ (x-w32 s win) _ (x-w32 s 2048) (x-w32 s mask))
   (x-configure s win x y w h)                                                   ; ConfigureWindow: x y w h border=0
    (: _ (x-w8 s 12) _ (x-w8 s 0) _ (x-w16 s 8) _ (x-w32 s win) _ (x-w16 s 31) _ (x-w16 s 0)
       _ (x-w32 s x) _ (x-w32 s y) _ (x-w32 s w) _ (x-w32 s h) (x-w32 s 0))
   (x-map s win)   (: _ (x-w8 s 8) _ (x-w8 s 0) _ (x-w16 s 2) (x-w32 s win))
   (x-unmap s win) (: _ (x-w8 s 10) _ (x-w8 s 0) _ (x-w16 s 2) (x-w32 s win))
   (x-focus s win) (: _ (x-w8 s 42) _ (x-w8 s 1) _ (x-w16 s 3) _ (x-w32 s win) (x-w32 s 0))   ; SetInputFocus, PointerRoot revert
   (x-border s win px) (: _ (x-w8 s 12) _ (x-w8 s 0) _ (x-w16 s 4) _ (x-w32 s win) _ (x-w16 s 16) _ (x-w16 s 0) (x-w32 s px))   ; ConfigureWindow border-width

   ; --- InternAtom (name -> atom), used as the redirect sync point ---
   (x-intern s nm)
    (: n (tally nm)
       _ (x-w8 s 16) _ (x-w8 s 0) _ (x-w16 s (+ 2 (/ (+ n (x-pad4 n)) 4)))
       _ (x-w16 s n) _ (x-w16 s 0) _ (x-wname s nm)
       _ (: (go i) (? (< i (x-pad4 n)) (: _ (put s 0) (go (+ i 1))) 0) (go 0))
       _ (x-flush s)
       b0 (x-r8 s)
       (? (! (= b0 1)) (: _ (x-skip s 31) ())
          (: _ (x-r8 s) _ (x-r16 s) _ (x-r32 s) atom (x-r32 s) _ (x-skip s 20) atom)))

   ; --- become the WM: SubstructureRedirect|Notify on the root, synced by an
   ;     intern round-trip. 1 = we hold it, 0 = another WM (Access error). ---
   (x-redirect s root)
    (: _ (x-cwa-events s root 1572864) at (x-intern s "WM_STATE")
       (? at 1 0))

   ; --- keyboard: GetKeyboardMapping -> a keysym->keycode map; GrabKey ---
   (x-keymap s mink maxk syms)                                                   ; syms = the keysyms we want located
    (: nkc (+ 1 (- maxk mink))
       _ (x-w8 s 101) _ (x-w8 s 0) _ (x-w16 s 2) _ (x-w8 s mink) _ (x-w8 s nkc) _ (x-w16 s 0) _ (x-flush s)
       _ (x-r8 s) kpc (x-r8 s) _ (x-r16 s) _ (x-r32 s) _ (x-skip s 24)
       km (tablet 8)
       _ (: (go i) (? (< i (* nkc kpc))
                      (: sym (x-r32 s)
                         _ (? (&& (any (\ x (= x sym)) syms) (! (peep km sym 0)))
                              (pin km sym (+ mink (// i kpc))) 0)
                         (go (+ i 1))) 0) (go 0))
       km)
   (x-grab s root mods kc) (? (< kc 1) 0
                              (: _ (x-w8 s 33) _ (x-w8 s 1) _ (x-w16 s 4) _ (x-w32 s root)
                                 _ (x-w16 s mods) _ (x-w8 s kc) _ (x-w8 s 1) _ (x-w8 s 1)
                                 _ (x-w8 s 0) _ (x-w8 s 0) (x-w8 s 0)))

   ; --- the event decoder: one 32-byte event -> (code detail window state) | ()
   ;     code 0 = X error (window is garbage). window at byte 8, state at byte 28,
   ;     detail (keycode) at byte 1 -- enough for every event the WM handles. ---
   (x-next s)
    (: b0 (x-r8 s)
       (? (= b0 -1) ()
          (: detail (x-r8 s) _ (x-skip s 6) window (x-r32 s)
             _ (x-skip s 16) state (x-r16 s) _ (x-skip s 2)
             (L (& 127 b0) detail window state))))
   (ev-code e) (cap e)  (ev-detail e) (caup e)  (ev-window e) (nthl e 2)  (ev-state e) (nthl e 3))
