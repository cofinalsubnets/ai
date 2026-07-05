; apps/haven/skiff.l -- skiff, the little wayland client: rows one solid
; color over to whatever compositor listens at the path. binds the registry,
; raises an xdg toplevel, brushes a memfd pool, attaches + commits -- then
; holds the line so the window stays up. loads after apps/haven/wire.l.
; the proof lane for haven (boot/haven.l reads the pixels back off the X
; server) -- and an honest little client for any other compositor too.
;
;   ai -l apps/haven/wire.l -l apps/haven/skiff.l \
;      -e '(skiff "/run/user/1000/haven-0" 320 240 12632256)'
;
; our ids: 2 registry, 3 shm, 4 compositor, 5 wm_base, 6 surface,
; 7 xdg_surface, 8 toplevel, 9 pool, 10 buffer, 99 the sync oar.
(:
   (skiff path w h rgb)
     (: c (connectu path)
        (? (! (lit? c)) 'no-socket
         (: k (cask 65536) sc (cask 65536)
            st (tablet 4) _ (pin st 0 0) _ (pin st 1 ())
            got (tablet 8)          ; 0..2 the global names (shm compositor
            _ (map (\ i (pin got i 0)) '(0 1 2 3 4 5))    ; wm_base), 3 the sync
            (on obj op off sz)      ; echo, 4 the configure serial, 5 the release
              (? (= obj 2)
                   (? (= op 0)
                      (: nm (wl-u32 k off) i (wl-rstr k (+ off 4))
                         (? (= i "wl_shm") (pin got 0 nm)
                            (= i "wl_compositor") (pin got 1 nm)
                            (= i "xdg_wm_base") (pin got 2 nm)
                            0))
                      0)
                 (= obj 99) (pin got 3 1)
                 (= obj 7) (? (= op 0) (pin got 4 (wl-u32 k off)) 0)
                 (= obj 10) (pin got 5 1)
                 0)
            (pump _) (: r (wl-pump c k sc st on) (? (< 0 r) (pump ()) r))
            (until i) (? (< 0 (peep got i 0)) (peep got i 0)
                         (: _ (await c) _ (pump ()) (until i)))
            _ (wl-ship c 1 1 (L 2) ())                    ; get_registry
            _ (wl-ship c 1 0 (L 99) ())                   ; sync: the registry fence
            _ (until 3)
            (? (! (* (peep got 0 0) (* (peep got 1 0) (peep got 2 0))))
               (: _ (close c) 'no-globals)
             (: _ (wl-ship c 2 0 (link (peep got 0 0) (cat (wl-strw "wl_shm") (L 1 3))) ())
                _ (wl-ship c 2 0 (link (peep got 1 0) (cat (wl-strw "wl_compositor") (L 4 4))) ())
                _ (wl-ship c 2 0 (link (peep got 2 0) (cat (wl-strw "xdg_wm_base") (L 2 5))) ())
                _ (wl-ship c 4 0 (L 6) ())                ; create_surface
                _ (wl-ship c 5 2 (L 7 6) ())              ; get_xdg_surface
                _ (wl-ship c 7 1 (L 8) ())                ; get_toplevel
                _ (wl-ship c 6 6 () ())                   ; commit, bufferless
                srl (until 4)
                _ (wl-ship c 7 4 (L srl) ())              ; ack_configure
                ; the pool: one solid row, brushed down the whole mapping
                stride (* w 4) size (* stride h)
                fd (memfd size) m (mapfd fd size)
                (? (? (< fd 0) 1 (< m 1)) (: _ (close c) 'no-pool)
                 (: row (cask stride)
                    (fill i) (? (< i w)
                                (: _ (pin row (* i 4) (& 255 rgb))
                                   _ (pin row (+ (* i 4) 1) (& 255 (>> rgb 8)))
                                   _ (pin row (+ (* i 4) 2) (& 255 (>> rgb 16)))
                                   _ (pin row (+ (* i 4) 3) 0)
                                   (fill (+ i 1)))
                                0)
                    _ (fill 0)
                    (paint y) (? (< y h)
                                 (: _ (mapout m (* y stride) row 0 stride) (paint (+ y 1)))
                                 0)
                    _ (paint 0)
                    _ (wl-ship c 3 0 (L 9 size) (L fd))   ; create_pool: the fd rides
                    _ (wl-ship c 9 0 (L 10 0 w h stride 1) ())   ; buffer, xrgb8888
                    _ (wl-ship c 6 1 (L 10 0 0) ())       ; attach
                    _ (wl-ship c 6 2 (L 0 0 w h) ())      ; damage
                    _ (wl-ship c 6 6 () ())               ; commit
                    _ (until 5)                           ; the release lands
                    _ (puts "skiff: shipped")
                    (hold _) (: _ (await c) r (pump ())   ; the window stays up
                                (? (< r 0) (hold ()) (close c)))
                    (hold ())))))))))
