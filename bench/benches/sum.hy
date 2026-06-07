;; build the list 1..100000 then sum it.
(import sys)
(sys.path.insert 0 "lib")
(import bench [bench])
(bench "sum" (fn [] (sum (range 1 100001))))
