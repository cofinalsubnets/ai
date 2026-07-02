; wm/wm.l -- the driver: wire the pure core (wm/core.l) and the X protocol
; (wm/wire.l) into a running window manager. Concatenate them:
;   cat wm/core.l wm/wire.l wm/wm.l | out/host/ai      (against `Xephyr :7 -ac`)
; This is the scaffold's proof that the modular split composes -- rungs 1-5 of the
; spike (manage/tile/focus/keyboard) plus workspaces (rung 6, clean this time: no
; single-`:` name collisions, because the WM vocabulary lives in core.l/wire.l and
; never shadows a nif). Tall is inlined here for now; layout.l lifts it out later.
; The bindings are a scaffold subset of the target config (mod = super/mod4):
;   mod+j / mod+k  focus down/up      mod+Return  focused -> master
;   mod+1..9       view workspace      mod+shift+1..9  send focused there
(: s (x-connect "/tmp/.X11-unix/X7")
   _ (? s 0 (: _ (say err "wm: no display :7 -- Xephyr up?\n") (nap 1)))
   (line m) (: _ (say out m) _ (say out "\n") (flush out))
   sc (x-setup s)
   _ (? sc 0 (: _ (say err "wm: setup refused\n") (nap 1)))
   root (scr-root sc) wpx (scr-w sc) hpx (scr-h sc)
   _ (? (x-redirect s root) 0 (: _ (say err "wm: another WM owns :7\n") (nap 1)))
   _ (line (+ "wm: managing " (+ (show root) (+ " " (+ (show wpx) (+ "x" (show hpx)))))))

   ; --- keyboard: locate keycodes, grab mod4 + the digits (plain and shifted) ---
   mod (<< 1 6)                                                                  ; mod4 = super = 0x40
   km (x-keymap s (scr-mink sc) (scr-maxk sc) '(106 107 65293 49 50 51 52 53 54 55 56 57))
   kj (peep km 106 0) kk (peep km 107 0) kret (peep km 65293 0)
   digits (map (\ d (L d (peep km (+ 48 d) 0))) (map (+ 1) (jot 9)))            ; ((tag keycode)..), tags 1..9
   _ (map (\ p (: kc (caup p) _ (x-grab s root mod kc) (x-grab s root (| mod 1) kc))) digits)
   _ (map (\ kc (x-grab s root mod kc)) (L kj kk kret))
   _ (x-flush s)
   _ (line "wm: grabbed mod+{j,k,ret,1..9} and mod+shift+{1..9}")

   ; --- Tall over the current row (master left half, rest a right column) ---
   (nth l i) (? (< i 1) (cap l) (nth (cup l) (- i 1)))
   (tile rw)
    (: n (tally rw)
       (? (< n 1) ()
          (= n 1) (L (L (cap rw) 0 0 wpx hpx))
          (: mw (// wpx 2) k (- n 1) rh (// hpx k)
             (link (L (cap rw) 0 0 mw hpx)
                   (: (go i l) (? (! (two? l)) ()
                                  (link (L (cap l) mw (* i rh) (- wpx mw)
                                           (? (= i (- k 1)) (- hpx (* (- k 1) rh)) rh))
                                        (go (+ i 1) (cup l))))
                      (go 0 (cup rw)))))))
   (render sh)                                                                   ; place the current tiled row (tile ONLY -- focus is separate:
    (: _ (map (\ t (x-configure s (nth t 0) (nth t 1) (nth t 2) (nth t 3) (nth t 4))) (tile (wsrow sh)))   ; SetInputFocus on a not-yet-viewable window is BadMatch)
       (x-flush s))
   (refocus sh) (? (wsfoc sh) (: _ (x-focus s (wsfoc sh)) (x-flush s)) 0)        ; focus the current top -- only when it is mapped/viewable
   (switch sh t)                                                                 ; view: hide the leaving row, show the arriving
    (? (|| (= t (wscur sh)) (! (wsknown? sh t))) sh
       (: old (wsrow sh) sh2 (wsview sh t)
          _ (map (\ w (x-map s w)) (wsrow sh2))
          _ (render sh2)
          _ (map (\ w (x-unmap s w)) old) _ (x-flush s)
          _ (line (+ "wm: view " (+ (show t) (+ " " (show (wsrow sh2))))))
          sh2))

   ; --- the event loop over the sheaf ---
   (loop sh live)
    (: e (x-next s)
       (? (! e) (line "wm: display gone")
          (= (ev-code e) 0) (: _ (line (+ "wm: X error " (show (ev-detail e)))) (loop sh live))
          (: code (ev-code e) win (ev-window e)
             (? (= code 20)                                                      ; MapRequest: manage + tile + map
                (: sh2 (admit sh win) _ (render sh2) _ (x-map s win) _ (x-flush s)
                   _ (line (+ "wm: + " (+ (show win) (+ " " (show (wsrow sh2)))))) (loop sh2 1))
                (= code 19) (: _ (? (= win (wsfoc sh)) (: _ (x-focus s win) (x-flush s)) 0) (loop sh live))   ; MapNotify: focus if it's the top
                (= code 17)                                                      ; DestroyNotify: unmanage + tile
                (: (? (! (wsknownw? sh win)) (loop sh live)
                      (: sh2 (evict sh win) _ (render sh2)
                         _ (line (+ "wm: - " (+ (show win) (+ " " (show (wsrow sh2))))))
                         (? (&& live (! (wswins sh2))) (line "wm: empty -- down") (loop sh2 live)))))
                (= code 2)                                                       ; KeyPress: drive the core (focus is safe -- the windows are viewable)
                (: kc (ev-detail e) st (ev-state e) shifted (& st 1)
                   (? (= kc kj) (: sh2 (wsmap sh zfocdn) _ (render sh2) _ (refocus sh2) (loop sh2 live))
                      (= kc kk) (: sh2 (wsmap sh zfocup) _ (render sh2) _ (refocus sh2) (loop sh2 live))
                      (= kc kret) (: sh2 (wsmap sh zmaster) _ (render sh2) _ (refocus sh2) (loop sh2 live))
                      (: hit (afind (\ p (= (caup p) kc)) digits)
                         (? (! (two? hit)) (loop sh live)
                            (: t (cap hit)
                               (? shifted (: sh2 (shiftto sh t) _ (render sh2)
                                             _ (line (+ "wm: sent -> " (show t))) (loop sh2 live))
                                  (loop (switch sh t) live)))))))
                (= code 23) (: _ (? (wsknownw? sh win) (render sh) 0) (loop sh live))   ; ConfigureRequest: the layout answers
                (loop sh live)))))
   _ (loop (sheaf (map (+ 1) (jot 9))) 0)                                        ; workspaces 1..9 (numeric tags)
   _ (close s)
   (line "wm: done"))
