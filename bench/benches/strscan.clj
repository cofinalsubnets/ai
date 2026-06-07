;; fixed string built once; the timed work is a linear rolling-hash scan.
(load-file "lib/bench.clj")
(def hmod 1000000007)
(def data (apply str (map (fn [i] (char (+ 32 (mod (* 7 i) 95)))) (range 0 20000))))
(bench "strscan"
  (fn []
    (loop [j 0 h 0]
      (if (< j (count data))
        (recur (inc j) (mod (+ (* h 31) (int (.charAt data j))) hmod))
        h))))
