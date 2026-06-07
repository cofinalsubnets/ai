;; list pipeline: square every element, keep the even results, sum them.
(load-file "lib/bench.clj")
(def data (doall (range 0 10000)))
(bench "mapfilter" (fn [] (reduce + (filter even? (map #(* % %) data)))))
