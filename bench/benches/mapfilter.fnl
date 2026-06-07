;; list pipeline: square every element, keep the even results, sum them.
(set package.path (.. "lib/?.lua;" package.path))
(local bench (require :bench))
(local data [])
(for [i 0 9999] (tset data (+ i 1) i))
(bench "mapfilter" (fn []
  (var s 0)
  (for [i 1 (length data)]
    (let [y (* (. data i) (. data i))]
      (when (= (% y 2) 0) (set s (+ s y)))))
  s))
