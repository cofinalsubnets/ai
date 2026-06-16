; host CLI driver: with file args, load each (after stripping -r flags);
; otherwise read-eval stdin to EOF. Loaded by main.c when argv is non-empty.
; -r <file> preloads (requires) a file before the main program -- the ruby/node
; convention (`ruby -r lib prog`, `node -r ./lib prog`), not C's -l (link a lib).
(: (load1 p)
   (: q (open p "r")
      (? q ((: (g e q) (: r (read q e) (? (= e r) 0 (: _ (ev 'ev r) (g e q))))) (mint 0) q)
           (: _ (fputs err (+ "ai: cannot open " p)) (exit 1)))))
(: (strip-r a)
   (? (& (twop a) (= (cap a) "-r"))
      (: _ (load1 (cap (cup a))) (strip-r (cup (cup a))))
      a))
(: argv (strip-r (cup argv)))   ; drop the program-name head: main.c now passes the whole argv (cmdline keeps it)
(? (twop argv) (load1 (cap argv))
   ((: (g e) (: r (read in e) (? (= e r) 0 (: _ (ev 'ev r) (g e))))) (mint 0)))
