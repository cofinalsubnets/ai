;; count primes below 30000 by trial division; checksum = pi(30000) = 3245.
(set package.path (.. "lib/?.lua;" package.path))
(local bench (require :bench))
(fn is-prime [n]
  (var d 2) (var ok true)
  (while (and ok (<= (* d d) n))
    (if (= (% n d) 0) (set ok false) (set d (+ d 1))))
  ok)
(bench "primes" (fn []
  (var c 0)
  (for [n 2 29999] (when (is-prime n) (set c (+ c 1))))
  c))
