; square 0..N-1, keep the even squares, sum them. written as map/filter/fold -- the
; deforest/closeable idiom -- so the loop-closer reads it and emits a closed
; polynomial: a square is even iff its base is, so the even-result filter is the
; structural EVEN filter (polysum's odd-filter sibling), reparametrized to k=2j ->
; Σ_{j<(N+1)/2} (2j)^2, O(1). exact integers, =/show-identical to the O(n) pipeline.
; checksum = sum of even squares in [0,10000) = 166616670000.
(: (work n) (foldl (+) 0 (map (\ x (* x x)) (filter (\ x (= 0 (% x 2))) (jot n))))
 (bench "mapfilter" (\ _ (work 10000))))
