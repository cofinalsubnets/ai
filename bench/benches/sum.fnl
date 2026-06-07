;; build the table 1..100000 then sum it -- allocation + traversal.
(set package.path (.. "lib/?.lua;" package.path))
(local bench (require :bench))
(local data [])
(for [i 1 100000] (tset data i i))
(bench "sum" (fn []
  (var s 0)
  (for [i 1 (length data)] (set s (+ s (. data i))))
  s))
