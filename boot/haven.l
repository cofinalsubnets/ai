; --- boot/haven.l: haven + skiff, end to end under a headless X ---
; NOT in the test/*.l corpus (shore/wl-send/memfd/connectu/mind are host/*.c).
; spawns an Xvfb, sails haven (the wayland compositor) as one child and skiff
; (the client) as another, then reads haven's X WINDOW back with GetImage:
; skiff's solid color must land -- the whole loop: wayland socket ->
; SCM_RIGHTS fd -> shm pool -> commit -> mapin -> px-ship -> X -> GetImage.
;
;   cat test/00-init.l boot/haven.l | out/host/ai
;
; no Xvfb on the box -> a polite skip (the sentinel still prints).

(reads (open "apps/wm/core.l" "r"))
(reads (open "apps/wm/wire.l" "r"))

(: dpy "/tmp/.X11-unix/X78"
   sock "/tmp/haven-boot.sock"
   xv (mind `("Xvfb" ":78" "-screen" "0" "640x480x24" "-nolisten" "tcp"))
   (wfx p) (: g2 (gather p) (? (two? g2) g2 (: _ (rest 2) (wfx p))))
   (waitsock pth t) (? (< t 1) ()
                      (: p (connectu pth)
                         (? (lit? p) (: _ (close p) 1)
                            (: _ (rest 50) (waitsock pth (- t 1))))))
 _ (? (! (two? xv))
      (: _ (puts "haven: ok (no Xvfb, skipped)") (nap 0))
      0)
 _ (assert (waitsock dpy 100))

 ; GetImage (opcode 73, ZPixmap): w*h pixels back as a byte list
 (px-getimg s d x y w h)
  (: _ (x-w8 s 73) _ (x-w8 s 2) _ (x-w16 s 5)
     _ (x-w32 s d) _ (x-w16 s x) _ (x-w16 s y) _ (x-w16 s w) _ (x-w16 s h)
     _ (x-w32 s 4294967295) _ (x-flush s)
     hdr (x-reply s)
     (x-rbytes s (* 4 (u32 hdr 4))))
 (lit-in px) (foldl (\ a b (+ a (? (= 192 b) 1 0))) 0 px)

 ; haven on its own X window + shore; skiff rows 0xc0c0c0 over
 hv (mind `("out/host/ai" "-l" "apps/wm/core.l" "-l" "apps/wm/wire.l" "-l" "apps/quay/pier.l"
            "-l" "apps/haven/wire.l" "-l" "apps/haven/haven.l"
            "-e" "(haven \"/tmp/haven-boot.sock\" \"/tmp/.X11-unix/X78\" () 320 240)"))
 _ (assert (two? hv))
 _ (assert (waitsock sock 100))
 sk (mind `("out/host/ai" "-l" "apps/haven/wire.l" "-l" "apps/haven/skiff.l"
            "-e" "(skiff \"/tmp/haven-boot.sock\" 320 240 12632256)"))
 _ (assert (two? sk))

 ; our own eyes: find the window, wait till it's viewable, read the pixels
 s (connectu dpy)
 sc (x-setup s ())
 _ (assert (two? sc) (= 24 (scr-depth sc)))
 (waitwin t) (? (< t 1) ()
                (: ws (x-querytree s (scr-root sc))
                   (? (two? ws) (cap ws) (: _ (rest 100) (waitwin (- t 1))))))
 win (waitwin 100)
 _ (assert (charm? win))
 (waitmap t) (? (< t 1) 0
                (? (= 2 (cap (x-attrs s win))) 1
                   (: _ (rest 50) (waitmap (- t 1)))))
 _ (assert (waitmap 100))

 ; an 8x8 patch mid-window: 64 solid 0xc0c0c0 pixels = 192 lit bytes
 (waitlit t) (? (< t 1) 0
                (: n (lit-in (px-getimg s win 100 100 8 8))
                   (? (< 100 n) n (: _ (rest 100) (waitlit (- t 1))))))
 _ (assert (< 100 (waitlit 100)))

 ; strike the camp
 _ (still (cap sk) 15) _ (wfx (cap sk)) _ (close (cup sk))
 _ (still (cap hv) 15) _ (wfx (cap hv)) _ (close (cup hv))
 _ (close s)
 _ (still (cap xv) 15)
 _ (wfx (cap xv))
 (puts "haven: ok"))
