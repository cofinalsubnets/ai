;; build an N-char string by repeated single-char concatenation, then hash it.
(set package.path (.. "lib/?.lua;" package.path))
(local bench (require :bench))
(local HMOD 1000000007)
(local N 4000)
(bench "strcat" (fn []
  (var s "")
  (for [i 0 (- N 1)] (set s (.. s (string.char (+ 48 (% i 10))))))
  (var h 0)
  (for [i 1 (length s)] (set h (% (+ (* h 31) (string.byte s i)) HMOD)))
  h))
