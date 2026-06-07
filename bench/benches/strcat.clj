;; build an N-char string by repeated single-char concatenation, then hash it.
(load-file "lib/bench.clj")
(def hmod 1000000007)
(def nn 4000)
(bench "strcat"
  (fn []
    (let [s (loop [i 0 s ""]
              (if (< i nn) (recur (inc i) (str s (char (+ 48 (mod i 10))))) s))]
      (loop [j 0 h 0]
        (if (< j (count s))
          (recur (inc j) (mod (+ (* h 31) (int (.charAt s j))) hmod))
          h)))))
