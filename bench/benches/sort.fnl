;; sort N pseudo-random ints (MINSTD LCG), order-dependent rolling-hash checksum.
(set package.path (.. "lib/?.lua;" package.path))
(local bench (require :bench))
(local N 5000)
(bench "sort" (fn []
  (var x 1)
  (local data [])
  (for [i 1 N] (set x (% (* 16807 x) 2147483647)) (tset data i x))
  (table.sort data)
  (var h 0)
  (for [i 1 N] (set h (% (+ (* h 31) (. data i)) 1000000007)))
  h))
