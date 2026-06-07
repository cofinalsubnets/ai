;; build an N-char string by repeated single-char concatenation, then hash it.
(import sys)
(sys.path.insert 0 "lib")
(import bench [bench])
(setv HMOD 1000000007)
(setv N 4000)
(defn work []
  (setv s "")
  (for [i (range N)] (setv s (+ s (chr (+ 48 (% i 10))))))
  (setv h 0)
  (for [ch s] (setv h (% (+ (* h 31) (ord ch)) HMOD)))
  h)
(bench "strcat" work)
