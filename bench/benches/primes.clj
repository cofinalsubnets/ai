;; count primes below 30000 by trial division; checksum = pi(30000) = 3245.
(load-file "lib/bench.clj")
(defn prime? [n]
  (loop [d 2]
    (cond (> (* d d) n) true (zero? (rem n d)) false :else (recur (inc d)))))
(defn cnt [lo hi]
  (loop [n lo c 0] (if (< n hi) (recur (inc n) (if (prime? n) (inc c) c)) c)))
(bench "primes" (fn [] (cnt 2 30000)))
