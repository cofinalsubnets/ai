; string-literal escape sequences. both readers must agree:
; the C reader (g.c:g_read1) parses this source file at load time;
; the gwen reader (repl.g:rdstr, reached via read1) is exercised
; explicitly below by parsing source charlists.

(assert
  ; --- C reader path: this file is parsed by it ---
  ; \n becomes a 1-byte string containing LF (10).
  (= 1 (len "\n"))
  (= "\n" (str (X 10 0)))
  ; \\ and \" still pass through via the take-next-char-as-is fallback.
  (= 1 (len "\\"))
  (= "\\" (str (X 92 0)))
  (= 1 (len "\""))
  (= "\"" (str (X 34 0)))
  ; embedded mid-string
  (= 3 (len "a\nb"))
  (= "a\nb" (str (X 97 (X 10 (X 98 0))))))

; --- gwen reader path: feed read1 a charlist of `"..."` source ---
(:
 ; chars-of-source-with-quotes -> the parsed datum.
 (parse cl) (car (read1 cl))
 (assert
   (= (str (X 10 0))                   (parse '(34 92 110 34)))   ; "\n"
   (= (str (X 92 0))                   (parse '(34 92 92 34)))    ; "\\"
   (= (str (X 34 0))                   (parse '(34 92 34 34)))    ; "\""
   (= (str (X 97 (X 10 (X 98 0))))     (parse '(34 97 92 110 98 34)))))  ; "a\nb"
