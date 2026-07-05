; crew/phos/sigs.l -- phos's OVERLAY: an optional, observe-only type domain for
; the pure StackSet (crew/phos/core.l) + the layout geometry (crew/phos/layout.l).
; The vocabulary as dies: a WINDOW is not a TAG is not a RECT -- nominal kinds
; over values that are all innocent charms/lists at runtime, so the classic
; slip (a tag handed to zins, a window handed to wsview) is flagged at compile
; time and nothing changes at run time (the overlay law: erasable). Gradual:
; an unknown (a cap/cup harvest, a local) rides through; only a KNOWN kind in
; the wrong seat clashes. Install with (overlay-set phos-dom phos-sigs), or check
; a form pure with ((overlay 'ov-check1) phos-dom phos-sigs form) -- boot/overlay.l
; gates core.l + layout.l CLEAN against this table, and the deliberate wound
; flagged. This is rung 1 of typing phos; the uu-proved StackSet laws ride
; on top of it (memory: the verified-xmonad ladder).
;
; a body-LESS `:` -- phos-dom/phos-sigs leak; neither shadows a nif.
(:
   (phos-join a b) (? (= a b) a 'top)
   (phos-tr op a b) 'top
   (phos-lit e) 'top
   (phos-okr bd decl) (? (member? bd '(top bot)) 1 (= bd decl))
   phos-dom (hash 'dice '(window tag rect zipper sheaf wrow trow fmap lay)
                'ctors ()
                'join phos-join 'tr phos-tr 'litdie phos-lit 'okr phos-okr)

   ; --- the boundaries: (name (param-dies..) result-die). wrow = a row of
   ;     windows, trow = a row of tags, fmap = the floating alist. `top` in a
   ;     result keeps the def gradual (predicates, raw board reads). ---
   phos-sigs '(
     ; the zipper (core.l)
     (zmk      (window wrow wrow)     zipper)
     (zfoc     (zipper)               window)
     (zrow     (zipper)               wrow)
     (zfrom    (wrow)                 zipper)
     (zrev     (zipper)               zipper)
     (zfocup   (zipper)               zipper)
     (zfocdn   (zipper)               zipper)
     (zswapup  (zipper)               zipper)
     (zswapdn  (zipper)               zipper)
     (zmaster  (zipper)               zipper)
     (zins     (window zipper)        zipper)
     (znub     (window wrow)          wrow)
     (zdel     (window zipper)        zipper)
     (zhas?    (window zipper)        top)
     (zfromrow (wrow window)          zipper)
     (zfocto   (window zipper)        zipper)
     (zswapw   (window window zipper) zipper)
     (znodup?  (wrow)                 top)
     ; the sheaf (core.l)
     (sheaf    (trow)                 sheaf)
     (wscur    (sheaf)                tag)
     (wsboard  (sheaf)                top)
     (wsfloat  (sheaf)                fmap)
     (wsmake   (tag a fmap)           sheaf)
     (wsknown? (sheaf tag)            top)
     (wsget    (sheaf tag)            zipper)
     (wsset    (sheaf tag zipper)     sheaf)
     (wsview   (sheaf tag)            sheaf)
     (wsrow    (sheaf)                wrow)
     (wsfoc    (sheaf)                window)
     (wsmap    (sheaf a)              sheaf)
     (wsunfl   (window fmap)          fmap)
     (wsfloating? (sheaf window)      top)
     (wsrect   (sheaf window)         rect)
     (wsdel-tiled (sheaf window)      top)
     (wsdofloat (sheaf window rect)   sheaf)
     (wssink   (sheaf window)         sheaf)
     (wstiled  (sheaf)                wrow)
     (wswins   (sheaf)                wrow)
     (wsknownw? (sheaf window)        top)
     (wstagof  (sheaf window)         tag)
     (admit    (sheaf window)         sheaf)
     (evict    (sheaf window)         sheaf)
     (shiftto  (sheaf tag)            sheaf)
     (wssane?  (sheaf)                top)
     ; the geometry (layout.l)
     (rct      (a b c d)              rect)
     (rx       (rect)                 top)
     (ry       (rect)                 top)
     (rw       (rect)                 top)
     (rh       (rect)                 top)
     (splitv-eq (a rect)              top)
     (splitv-w  (a rect)              top)
     (splith-by (a rect)              top)
     (placeat  (wrow a)               top)
     (lay-tile (lay rect zipper)      top)
     (lay-msg  (lay a zipper)         top)
     (resizable-tall (a b c)          lay)
     (tall     (a)                    lay)
     (dwindle  (a)                    lay)))
