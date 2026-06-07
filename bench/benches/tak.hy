;; the takeuchi function -- deep non-tail recursion, no allocation.
(import sys)
(sys.path.insert 0 "lib")
(import bench [bench])
(defn tak [x y z]
  (if (< y x) (tak (tak (- x 1) y z) (tak (- y 1) z x) (tak (- z 1) x y)) z))
(bench "tak" (fn [] (tak 22 12 6)))
