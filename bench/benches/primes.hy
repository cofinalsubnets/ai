;; count primes below 30000 by trial division; checksum = pi(30000) = 3245.
(import sys)
(sys.path.insert 0 "lib")
(import bench [bench])
(defn is-prime [n]
  (setv d 2)
  (while (<= (* d d) n)
    (when (= (% n d) 0) (return False))
    (setv d (+ d 1)))
  True)
(defn count-primes [lo hi]
  (setv c 0)
  (for [n (range lo hi)] (when (is-prime n) (setv c (+ c 1))))
  c)
(bench "primes" (fn [] (count-primes 2 30000)))
