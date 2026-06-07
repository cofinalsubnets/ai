;; fixed string built once; the timed work is a linear rolling-hash scan.
(import sys)
(sys.path.insert 0 "lib")
(import bench [bench])
(setv HMOD 1000000007)
(setv data (.join "" (lfor i (range 20000) (chr (+ 32 (% (* 7 i) 95))))))
(defn work []
  (setv h 0)
  (for [ch data] (setv h (% (+ (* h 31) (ord ch)) HMOD)))
  h)
(bench "strscan" work)
