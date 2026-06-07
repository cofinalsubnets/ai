;; naive recursive fibonacci -- function-call and integer-arithmetic stress.
(load-file "lib/bench.clj")
(defn fib [n] (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))
(bench "fib" (fn [] (fib 30)))
