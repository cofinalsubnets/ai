; list pipeline: square every element, keep the even results, sum them.
; l's idiom is the typed array, so the squaring, the even-mask, and the sum
; all run through the baked array kernels (one C loop each, no per-element
; closure): sq = d*d ; zero the odd squares with (1 - sq%2) ; asum.
; checksum matches the hook-list version (166616670000).
(: data (arr z '(10000) (jot 10000))
 (bench "mapfilter" (\ _ (: sq (data * data) (asum (sq * (1 - (sq % 2))))))))
