;; naive recursive fibonacci -- function-call and integer-arithmetic stress.
(import sys)
(sys.path.insert 0 "lib")
(import bench [bench])
(defn fib [n] (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))
(bench "fib" (fn [] (fib 30)))
