; t/tokens.g — sign-attachment at token boundaries. A leading `-`/`+`
; followed by a digit attaches as a number only when the sign is at a
; token boundary: preceded by whitespace/comment, the start of input,
; or a delimiter char `( [ { ' "`. Otherwise the sign tokenizes as a
; punc-class symbol. Exercises both the C reader (which parses this
; file) and the gwen reader (via read1 on charlists).

; --- helpers (top-level defglob) ---
(: (s2cl s) (: (loop i acc) (? (< i 0) acc
                                (loop (- i 1) (cons (get 0 i s) acc)))
              (loop (- (len s) 1) 0))
   (parse s) (car (read1 (s2cl s))))

; --- C reader (literals below are parsed by the C tokenizer) ---
(assert
 ; sign at start of input
 (= -5 -5)
 (= 5  +5)
 ; (sign-digit) inside a list, immediately after the opening paren
 (= 1 (len '(-5)))    (= -5 (car '(-5)))
 (= 1 (len '(+5)))    (= 5  (car '(+5)))
 ; sign after whitespace
 (= 2 (len '(1 -5)))  (= -5 (cadr '(1 -5)))
 (= 2 (len '(1 +5)))  (= 5  (cadr '(1 +5)))
 ; sign WITHOUT a boundary -- the fix -- splits into three tokens
 (= 3 (len '(1+2)))   (= '+ (cadr '(1+2)))  (= 2 (caddr '(1+2)))
 (= 3 (len '(1-2)))   (= '- (cadr '(1-2)))  (= 2 (caddr '(1-2)))
 (= 3 (len '(x-5)))   (= '- (cadr '(x-5)))  (= 5 (caddr '(x-5)))
 (= 3 (len '(x+5)))   (= '+ (cadr '(x+5)))  (= 5 (caddr '(x+5)))
 ; `--` is a punc-class symbol regardless; trailing digit splits off
 (= 2 (len '(-- 5)))  (= '-- (car '(-- 5)))
 (= 2 (len '(--5)))   (= '-- (car '(--5)))   (= 5 (cadr '(--5)))
 ; quote is a delim, so the next token IS at a boundary
 (= -5 '-5))

; --- gwen reader (read1 walks a charlist) ---
(assert
 (= '(1 + 2)  (parse "(1+2)"))
 (= '(1 - 2)  (parse "(1-2)"))
 (= '(1 + 2)  (parse "(1 + 2)"))
 (= '(1 2)    (parse "(1 +2)"))                  ; whitespace boundary
 (= '(-5)     (parse "(-5)"))                    ; delim boundary
 (= '(5)      (parse "(+5)"))
 ; no-boundary -> three tokens
 (= '(x - 5)  (parse "(x-5)"))
 (= '(x + 5)  (parse "(x+5)"))
 ; whitespace before sign re-enables attachment
 (= '(x -5)   (parse "(x -5)"))
 (= '(x 5)    (parse "(x +5)"))
 ; -- symbol is unaffected
 (= '(-- 5)   (parse "(--5)"))
 (= '(-- 5)   (parse "(-- 5)"))
 ; quote prefix is a delim
 (= '(` -5)   (parse "'-5"))
 ; top-level (single datum) signed literals
 (= -5        (parse "-5"))
 (= 5         (parse "+5"))
 (= 'x        (parse "x")))
