; apps/haven/haven.l -- haven, the wayland compositor: a shore the clients
; moor at. speaks wl_shm / wl_compositor / xdg_wm_base / wl_output, and
; composites every committed buffer straight into its own X window (the
; pier's blit lane: px-ship over apps/wm/wire.l) -- a wayland client draws,
; and X shows it. loads after apps/wm/{core,wire}.l + apps/quay/pier.l +
; apps/haven/wire.l:
;
;   ai -l apps/wm/core.l -l apps/wm/wire.l -l apps/quay/pier.l \
;      -l apps/haven/wire.l -l apps/haven/haven.l \
;      -e '(haven "/run/user/1000/haven-0" () () 800 600)'
;
; a body-LESS `:` -- the helpers leak; none shadows a nif.
(:
   ; --- the registry: (name interface version kind), what get_registry sings ---
   hv-globals '((1 "wl_shm" 1 shm) (2 "wl_compositor" 4 compositor)
                (3 "xdg_wm_base" 2 wmbase) (4 "wl_output" 2 output))
   (hv-kind nm) (: (go l) (? (two? l)
                             (? (= nm (cap (cap l))) (nthl (cap l) 3) (go (cup l)))
                             ())
                   (go hv-globals))

   ; --- the compositor's one move: a committed buffer lands in the fb, row by
   ;     row off the client's mapping, and ships. x = (s win gc depth wpx hpx) ---
   (hv-blit x fb buf pool)
     (: s (nthl x 0) win (nthl x 1) gc (nthl x 2) depth (nthl x 3)
        fbw (nthl x 4) fbh (nthl x 5)
        boff (nthl buf 2) w (nthl buf 3) h (nthl buf 4) stride (nthl buf 5)
        ptr (nthl pool 1)
        rows (? (< h fbh) h fbh) cols (? (< w fbw) w fbw)
        bytes (* cols 4) rowb (* fbw 4)
        (go y) (? (< y rows)
                  (: _ (mapin fb (* y rowb) ptr (+ boff (* y stride)) bytes)
                     (go (+ y 1)))
                  0)
        _ (? (< 0 ptr) (go 0) 0)
        (px-ship s win gc depth fb fbw 0 rows))

   ; --- one request. ob keeps the client's objects (id -> (kind ..)); st the
   ;     seam (slot 2 the configure serial); k the carry the offsets index ---
   (hv-on c st ob k x fb obj op off sz)
     (: rec (peep ob obj ())
        kind (? (two? rec) (cap rec) (? (= obj 1) 'display ()))
        (? (= kind 'display)
             (? (= op 0) (: cb (wl-u32 k off)             ; sync: done, then let go
                            _ (wl-ship c cb 0 (L 0) ())
                            (wl-ship c 1 1 (L cb) ()))
                (= op 1) (: rid (wl-u32 k off)            ; get_registry: the globals
                            _ (pin ob rid (L 'registry))
                            (map (\ g (wl-ship c rid 0
                                        (link (cap g) (cat (wl-strw (nthl g 1)) (L (nthl g 2))))
                                        ()))
                                 hv-globals))
                0)
           (= kind 'registry)                             ; bind: kind by name
             (: nm (wl-u32 k off)
                vo (wl-rskip k (+ off 4))
                nid (wl-u32 k (+ vo 4))
                kd (hv-kind nm)
                _ (pin ob nid (L kd))
                (? (= kd 'shm)                            ; the formats: argb, xrgb
                   (: _ (wl-ship c nid 0 (L 0) ()) (wl-ship c nid 0 (L 1) ()))
                   0))
           (= kind 'compositor)                           ; create_surface
             (? (= op 0) (pin ob (wl-u32 k off) (L 'surface 0 0)) 0)
           (= kind 'shm)                                  ; create_pool: the fd docks
             (? (= op 0) (: nid (wl-u32 k off) size (wl-i32 k (+ off 4))
                            fd (wl-popfd st)
                            ptr (? (< fd 0) 0 (mapfd fd size))
                            (pin ob nid (L 'pool ptr size fd)))
                0)
           (= kind 'pool)                                 ; create_buffer
             (? (= op 0) (pin ob (wl-u32 k off)
                              (L 'buffer obj (wl-i32 k (+ off 4)) (wl-i32 k (+ off 8))
                                 (wl-i32 k (+ off 12)) (wl-i32 k (+ off 16))))
                0)
           (= kind 'surface)                              ; (surface pending cbid)
             (? (= op 1) (pin ob obj (L 'surface (wl-u32 k off) (nthl rec 2)))   ; attach
                (= op 3) (pin ob obj (L 'surface (nthl rec 1) (wl-u32 k off)))   ; frame
                (= op 6) (: pend (nthl rec 1) cb (nthl rec 2)                    ; commit
                            _ (? (< 0 pend)
                                 (: buf (peep ob pend ())
                                    pool (peep ob (nthl buf 1) ())
                                    _ (hv-blit x fb buf pool)
                                    (wl-ship c pend 0 () ()))                    ; release
                                 0)
                            _ (? (< 0 cb)
                                 (: _ (wl-ship c cb 0 (L 0) ()) (wl-ship c 1 1 (L cb) ()))
                                 0)
                            (pin ob obj (L 'surface pend 0)))
                0)
           (= kind 'wmbase)                               ; get_xdg_surface
             (? (= op 2) (pin ob (wl-u32 k off) (L 'xdgsurf (wl-u32 k (+ off 4)))) 0)
           (= kind 'xdgsurf)
             (? (= op 1) (: nid (wl-u32 k off)            ; get_toplevel: configure now
                            _ (pin ob nid (L 'toplevel))
                            _ (wl-ship c nid 0 (L (nthl x 4) (nthl x 5) 0) ())
                            srl (peep st 2 1)
                            _ (pin st 2 (+ srl 1))
                            (wl-ship c obj 0 (L srl) ()))
                0)
           0))

   ; --- one client, cradle to grave: park, pump, part ---
   (hv-serve c x fb)
     (: k (cask 65536) sc (cask 65536)
        st (tablet 4) _ (pin st 0 0) _ (pin st 1 ()) _ (pin st 2 1)
        ob (tablet 64)
        (on obj op off sz) (hv-on c st ob k x fb obj op off sz)
        (drain _) (: r (wl-pump c k sc st on) (? (< 0 r) (drain ()) r))
        (park _) (: _ (await c)
                    r (drain ())
                    (? (< r 0) (park ()) (close c)))
        (park ()))

   ; --- the harbor: an X window for the glass, a shore for the door ---
   (haven path dpy auth wpx hpx)
     (: s (x-connect dpy)
        (? (! (lit? s)) 'no-socket
         (: sc (x-setup s auth)
            (? (! (two? sc)) (: _ (close s) 'refused)
             (: win (scr-idbase sc) gc (+ 1 (scr-idbase sc)) depth (scr-depth sc)
                _ (px-mkwin s win (scr-root sc) 0 0 wpx hpx)
                _ (px-gc s gc win)
                _ (px-title s win "haven")
                _ (x-map s win)
                _ (x-flush s)
                fb (cask (* wpx (* hpx 4)))
                x (L s win gc depth wpx hpx)
                lp (shore path)
                (? (! (lit? lp)) (: _ (close s) 'no-shore)
                 (: (knock _) (: _ (await lp)
                                 c (accept lp)
                                 _ (? (lit? c) (spin (\ _ (hv-serve c x fb)) 0) 0)
                                 (knock ()))
                    (knock ())))))))))
