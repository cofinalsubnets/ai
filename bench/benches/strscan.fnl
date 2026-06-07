;; fixed string built once; the timed work is a linear rolling-hash scan.
(set package.path (.. "lib/?.lua;" package.path))
(local bench (require :bench))
(local HMOD 1000000007)
(local parts [])
(for [i 0 19999] (tset parts (+ i 1) (string.char (+ 32 (% (* 7 i) 95)))))
(local data (table.concat parts))
(bench "strscan" (fn []
  (var h 0)
  (for [i 1 (length data)] (set h (% (+ (* h 31) (string.byte data i)) HMOD)))
  h))
