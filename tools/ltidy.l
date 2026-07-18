; tools/ltidy.l -- the .l linter/janitor. NOT a pretty-printer: .l indentation is
; paren-depth + deliberate hand-alignment (aligned ? clauses, : bindings, go
; continuations), which no mechanical pass reproduces without fighting the house
; style. so it LINTS instead -- paren/bracket/brace balance (a matched-pair stack,
; so ([)] is caught), unclosed strings, and stray tabs -- QUIET when clean, warnings
; with line numbers on err, and EXIT 1 on any imbalance (so `make lint` gates on it;
; tabs warn but never fail). it reads .l correctly -- `;` and `#!` start comments to
; end of line, `"..."` is the only string, and `'` / backtick are READER OPERATORS
; (quote, list-ctor), never delimiters, so they scan as ordinary code (the trap a C
; lexer falls into). -w also rewrites each file with trailing whitespace stripped.
; usage: ltidy [-w] FILE ..
(:
   (ws? c) (|| (c = 32) (c = 9))
   (rtrim s) (: n (tally s) (g j) (? (&& (0 < j) (ws? (s (j - 1)))) (g (j - 1)) (snip s 0 j)) (g n))
   (linesof s) (: n (tally s)
                  (g i st acc) (? (n <= i) (rev (link (snip s st n) acc))
                                  ((s i) = 10) (g (i + 1) (i + 1) (link (snip s st i) acc))
                                  (g (i + 1) st acc))
                  (g 0 0 ()))
   (unlines ls) (? (! (two? ls)) "" (foldl (\ a x (a + "\n" + x)) <ls >ls))
   (hastab? s) (: n (tally s) (g i) (? (n <= i) () ((s i) = 9) 1 (g (i + 1))) (g 0))

   ; --- .l-aware balance walk over the whole source. stk is a list of expected
   ; closers (a matched-pair stack, so ([)] is caught, not just a net count).
   ; states: code | cmt (; to EOL) | str ("..", \ escapes). answers a warnings list. ---
   (closer c) (? (c = 40) 41 (c = 91) 93 125)                      ; ( -> )   [ -> ]   { -> }
   (scanbal src)
    (: n (tally src)
       (w i st stk line warns)
        (? (n <= i)
            (: w1 (? (id? st 'str) (link ("unclosed string (opened on line " + (show line) + ")") warns) warns)
               (rev (? (two? stk) (link ((show (tally stk)) + " unclosed paren(s)/bracket(s) at end of file") w1) w1)))
           (: c (src i)
              (? (id? st 'str)                                     ; inside "..."
                  (? (c = 92) (w (i + 2) 'str stk line warns)      ; \ escape: skip next
                     (c = 34) (w (i + 1) 'code stk line warns)
                     (c = 10) (w (i + 1) 'str stk (line + 1) warns)
                     (w (i + 1) 'str stk line warns))
                 (id? st 'cmt)                                     ; ; comment to EOL
                  (? (c = 10) (w (i + 1) 'code stk (line + 1) warns) (w (i + 1) 'cmt stk line warns))
                 (c = 59) (w (i + 1) 'cmt stk line warns)          ; ; -- start comment
                 (&& (c = 35) (&& ((i + 1) < n) ((src (i + 1)) = 33))) (w (i + 2) 'cmt stk line warns)   ; #! shebang comment to EOL
                 (c = 34) (w (i + 1) 'str stk line warns)          ; " -- start string
                 (c = 10) (w (i + 1) 'code stk (line + 1) warns)
                 (|| (c = 40) (|| (c = 91) (c = 123)))             ; ( [ {  -- push closer
                  (w (i + 1) 'code (link (closer c) stk) line warns)
                 (|| (c = 41) (|| (c = 93) (c = 125)))             ; ) ] }  -- match / report
                  (? (! (two? stk)) (w (i + 1) 'code stk line (link ("stray '" + (string c) + "' on line " + (show line)) warns))
                     (! (<stk = c)) (w (i + 1) 'code >stk line (link ("mismatched '" + (string c) + "' on line " + (show line)) warns))
                     (w (i + 1) 'code >stk line warns))
                 (w (i + 1) 'code stk line warns))))               ; ' ` \ and every other char: ordinary code
       (w 0 'code () 1 ()))

   ; lines carrying a tab, as warnings (kept separate from balance so line numbers stay 1-based)
   (tabwarns lines)
    (: (g ls k acc) (? (! (two? ls)) (rev acc)
                       (g >ls (k + 1) (? (hastab? <ls) (link ("tab on line " + (show k)) acc) acc)))
       (g lines 1 ()))

   ; lint one file: warnings (with line numbers) to err, QUIET when clean. -w also
   ; rewrites it with trailing whitespace stripped. answers the count of FATAL
   ; (balance/string) warnings -- tabs warn but never fail the gate.
   (tidy src path fix)
    (: lines (linesof src)
       bwarns (scanbal src)
       warns (bwarns + (tabwarns lines))
       _ (foldl (\ _ m (: _ (say err (path + ": " + m + "\n")) 0)) 0 warns)
       _ (? fix (: q (open path "w") _ (say q (unlines (map rtrim lines))) (close q)) 0)
       (tally bwarns))

   ; --- driver: ltidy [-w] FILE ..  (lint -> err, exit 1 on any imbalance; -w strips trailing ws) ---
   (rdf p) (: q (open p "r") (? q (: t (slurp q) _ (close q) `(1 t)) ()))
   (each fs fix bad) (? (! (two? fs)) bad
                        (: r (rdf <fs)
                           n (? (two? r) (tidy <>r <fs fix) (: _ (say err ("ltidy: cannot open " + <fs + "\n")) 1))
                           (each >fs fix (bad + n))))
   (flags as fix acc) (? (! (two? as)) `(fix (rev acc))
                         (<as = "-w") (flags >as 1 acc)
                         (flags >as fix (link <as acc)))
   f (flags >>cmdline () ())
   files <>f
   nbad (? (two? files) (each files <f 0) (: _ (say err "usage: ltidy [-w] FILE ..\n") 0))
   (? (0 < nbad) (quit 1) 0))
