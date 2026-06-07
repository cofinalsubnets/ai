;; sort N pseudo-random ints (MINSTD LCG), order-dependent rolling-hash checksum.
(import sys)
(sys.path.insert 0 "lib")
(import bench [bench])
(setv N 5000)
(defn work []
  (setv x 1 data [])
  (for [_ (range N)]
    (setv x (% (* 16807 x) 2147483647))
    (.append data x))
  (.sort data)
  (setv h 0)
  (for [v data] (setv h (% (+ (* h 31) v) 1000000007)))
  h)
(bench "sort" (fn [] (work)))
