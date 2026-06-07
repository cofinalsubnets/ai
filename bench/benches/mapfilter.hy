;; list pipeline: square every element, keep the even results, sum them.
(import sys)
(sys.path.insert 0 "lib")
(import bench [bench])
(setv data (list (range 10000)))
(defn work [] (sum (filter (fn [x] (= (% x 2) 0)) (map (fn [x] (* x x)) data))))
(bench "mapfilter" work)
