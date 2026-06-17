; string-literal escape sequences. the C reader (g.c:g_read1) parses this
; source file at load time; the second block exercises the same reader via
; the charlist port (g.c:ci_getc, used by the REPL submit path) so the
; in-memory edit buffer agrees with file input.

(assert
  ; --- C reader path: this file is parsed by it ---
  ; \n / \t / \r / \0 become 1-byte strings with the corresponding byte.
  (= 1 (tally "\n"))           (= "\n" (string (hook 10 0)))
  (= 1 (tally "\t"))           (= "\t" (string (hook 9 0)))
  (= 1 (tally "\r"))           (= "\r" (string (hook 13 0)))
  (= 1 (tally "\0"))           (= "\0" (string (hook 0 0)))
  ; \xHH: two hex digits.
  (= 1 (tally "\x00"))         (= "\x00" (string (hook 0 0)))
  (= 1 (tally "\x41"))         (= "\x41" (string (hook 65 0)))
  (= 1 (tally "\xff"))         (= "\xff" (string (hook 255 0)))
  (= "\x41" "A")             (= "\x0a" "\n")
  (= "\xAB" "\xab")          ; mixed case
  ; \\ and \" still pass through via the take-next-char-as-is fallback.
  (= 1 (tally "\\"))           (= "\\" (string (hook 92 0)))
  (= 1 (tally "\""))           (= "\"" (string (hook 34 0)))
  ; embedded mid-string
  (= 3 (tally "a\nb"))         (= "a\nb" (string (hook 97 (hook 10 (hook 98 0)))))
  (= 3 (tally "a\tb"))         (= "a\tb" (string (hook 97 (hook 9  (hook 98 0)))))
  (= 3 (tally "a\rb"))         (= "a\rb" (string (hook 97 (hook 13 (hook 98 0)))))
  (= 3 (tally "a\0b"))         (= "a\0b" (string (hook 97 (hook 0  (hook 98 0)))))
  (= 3 (tally "a\x42b"))       (= "a\x42b" (string (hook 97 (hook 66 (hook 98 0))))))

; --- charlist port path: feed the C reader a charlist of `"..."` source
; through the ci synth port (the editor's submit path).
(:
 ; chars-of-source-with-quotes -> the parsed datum.
 (parse cl) (read (sip cl) 0)
 (assert
   (= (string (hook 10 0))                   (parse '(34 92 110 34)))   ; "\n"
   (= (string (hook 9 0))                    (parse '(34 92 116 34)))   ; "\t"
   (= (string (hook 13 0))                   (parse '(34 92 114 34)))   ; "\r"
   (= (string (hook 0 0))                    (parse '(34 92 48 34)))    ; "\0"
   (= (string (hook 92 0))                   (parse '(34 92 92 34)))    ; "\\"
   (= (string (hook 34 0))                   (parse '(34 92 34 34)))    ; "\""
   ; \xHH: 120='x', then 2 hex digits
   (= (string (hook 0 0))                    (parse '(34 92 120 48 48 34)))    ; "\x00"
   (= (string (hook 65 0))                   (parse '(34 92 120 52 49 34)))    ; "\x41" = 'A'
   (= (string (hook 255 0))                  (parse '(34 92 120 102 102 34)))  ; "\xff"
   (= (string (hook 171 0))                  (parse '(34 92 120 65 66 34)))    ; "\xAB"
   (= (string (hook 97 (hook 10 (hook 98 0))))     (parse '(34 97 92 110 98 34)))   ; "a\nb"
   (= (string (hook 97 (hook  9 (hook 98 0))))     (parse '(34 97 92 116 98 34)))   ; "a\tb"
   (= (string (hook 97 (hook 13 (hook 98 0))))     (parse '(34 97 92 114 98 34)))   ; "a\rb"
   (= (string (hook 97 (hook  0 (hook 98 0))))     (parse '(34 97 92 48 98 34)))    ; "a\0b"
   (= (string (hook 97 (hook 66 (hook 98 0))))     (parse '(34 97 92 120 52 50 98 34))))) ; "a\x42b"
