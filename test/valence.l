; the VALENCE LAW: a glued operator run is MONADIC -- the reader emits
; (mono (run datum)) and opfix factors the run against book['monadics]
; (then the operators table at one, so live pins keep the dynamic lane).
; spaced, a run keeps its dyadic/infix life. HEAD POSITION NEVER FUSES:
; a run right after an open delimiter is the form's operator -- the
; section/escape law, and what keeps minified source legal. the words
; behind the sigils: < cap, > cbp (<< >> <> >< the compounds), + net,
; * prod, | abs, - neg, / recip, % frac, ? bit; $ ! . ride the same lane.
(assert
 ; cap and cbp, and the compounds by greedy monadic factorization
 (1 = <'(1 2 3)) ('(2 3) = >'(1 2 3))
 (2 = <>'(1 2 3)) ('(3) = >>'(1 2 3))
 (9 = <<'((9 8) 2)) ('(2) = ><'((1 2) 9))
 ; the content measure and its product twin, + and * turned inward
 (6 = +'(1 2 3)) (294 = +"abc") (0 = +"") (7 = +@(3 4))
 (-1 = +'(-2 1))                                ; the net, UNCLAMPED: $ would read 0
 (~(0 8) = +(L ~(3 4) ~(-3 4)))                 ; phases sum as vectors
 (24 = *'(1 2 3 4)) (7 = *7) (6 = *@(1 2 3))
 ; the dyadics turned inward
 (5 = |-5) (5.0 = |~(3 4)) (-3 = -(1 + 2)) (0.25 = /4) (0.5 = %2.5)
 ; the truth panel: the bit is the Iverson bracket
 (1 = ?7) (0 = ?0) (0 = ?"") (0 = !7) (1 = !!7)
 ; glued monadics compose with infix; spaced runs keep their dyadic life
 (15 = (5 + <'(10 20))) (197 = ($"ab" + 2))
 (3 = (1 + 2)) (2 = (5 - 3)) (8 = (5 - -3))
 ; head position: the call, the section, the curry law -- never fused
 (3 = (+ 1 2)) (3 = ((1 +) 2)) (1 = ((< 5) 9)) (6 = (foldl (+) 0 '(1 2 3)))
 ; the data lane: a glued run READS as the mono node, and round-trips
 ('(f (mono (< x))) = (read (sip '(40 102 32 60 120 41)) 99))
 ; the words are real, the sigils their spellings
 (-7 = (neg 7)) (0.5 = (recip 2)) (0.25 = (frac 5.25)) (1 = (bit 9))
 (6 = (net '(1 2 3))) (24 = (prod '(2 3 4))) (idp 'cap (monadics '<)))
