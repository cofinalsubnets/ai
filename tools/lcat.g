; lcat.g -- re-serialize a gwen source file into a C string literal, replacing
; host/lcat.c. Reads the forms of the file named in (car (cdr argv)), prints
; each via the printer (inspect), space-separated, C-escaped, wrapped in "...".
; The result is #included as the compiled-in prelude (boot.h / repl.h).
;
; bif-only (no prelude functions) so it runs on the prelude-less bootstrap gl0.
; Mirrors lcat.c's escaping exactly: \n -> \n, and \ and " are backslashed;
; every other byte passes through (the printer already escapes string bodies).

(: (cesc s)                          ; emit s to out, C-escaping it like lcat_putc
   ((: (loop i n)
       (? (< i n)
          (: c (get 0 i s)
             _ (? (= c 10) (fputs out "\\n")
                  (? (| (= c 92) (= c 34)) (: _ (fputc out 92) (fputc out c))
                     (fputc out c)))
             (loop (+ i 1) n))
          0))
    0 (len s)))

(: p (open (car (cdr argv)) "r")
   _ (? p 0 (: _ (fputs err "lcat: cannot open input") (exit 1)))
   _ (fputc out 34)                  ; opening "
   ; thread the port p as a parameter (a captured heap port doesn't survive
   ; the GC fread triggers in a near-empty heap -- see the project memory).
   _ ((: (g first e p)               ; print each form, space-separated
         (: r (fread p e)
            (? (= e r) 0
               (: _ (? first (fputs out " ") 0)
                  _ (cesc (inspect r))
                  (g -1 e p)))))
      0 (sym 0) p)
   _ (fputc out 34)                  ; closing "
   (fputc out 10))
