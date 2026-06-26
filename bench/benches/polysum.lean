import Bench

-- the same odd-squares map/filter/fold pipeline as deforest, but with a PURE
-- polynomial body (see bench/benches/polysum.l) -- the row where ai's loop-closer
-- collapses it to O(1) and every other language runs the O(n) pipeline.
-- checksum = sum_{odd k < 20000} k^2 = 1333333330000 (< 2^53, exact everywhere).

-- `z` is the harness's opaque 0, threaded into the range length so the pipeline
-- is not folded to a compile-time constant (see lib/Bench.lean).
def main : IO Unit := bench "polysum" (fun z =>
  (((List.range (20000 + z)).filter (fun x => x % 2 == 1)).map
    (fun x => let xi := Int.ofNat x; xi * xi)).foldl (· + ·) 0)
