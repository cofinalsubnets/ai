;; build the list 1..100000 then fold-sum it -- allocation + traversal.
(load-file "lib/bench.clj")
(bench "sum" (fn [] (reduce + (range 1 100001))))
