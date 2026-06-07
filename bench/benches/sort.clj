;; sort N pseudo-random ints (MINSTD LCG), order-dependent rolling-hash checksum.
(load-file "lib/bench.clj")
(def N 5000)
(defn gen [n]
  (loop [i 0 x 1 acc []]
    (if (< i n)
      (let [nx (mod (* 16807 x) 2147483647)] (recur (inc i) nx (conj acc nx)))
      acc)))
(defn hsh [coll]
  (reduce (fn [h v] (mod (+ (* h 31) v) 1000000007)) 0 coll))
(bench "sort" (fn [] (hsh (sort (gen N)))))
