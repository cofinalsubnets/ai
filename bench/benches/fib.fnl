;; naive recursive fibonacci -- function-call and integer-arithmetic stress.
(set package.path (.. "lib/?.lua;" package.path))
(local bench (require :bench))
(fn fib [n] (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))
(bench "fib" (fn [] (fib 30)))
