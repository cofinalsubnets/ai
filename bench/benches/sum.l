; sum 0..N. written as a fold over a range -- the deforest/closeable idiom -- so
; ai plays to its strength: the loop-closer (ai/glaze/auto.l loopclose) reads it and
; collapses Σ_{i<N} i to the closed form N(N-1)/2, O(1) independent of N (the
; degree-1 case of the engine that closes polysum). exact integer arithmetic,
; promoting fixnum->wide->bignum exactly as the fold would, so it is =/show-identical
; at every N. checksum = sum 0..100000 = 5000050000.
(: (work n) (foldl (+) 0 (jot n))
 (bench "sum" (\ _ (work 100001))))
