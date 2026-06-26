import Bench

-- list pipeline: square every element, keep the even results, sum them.
def data : List Int := (List.range 10000).map Int.ofNat

-- `z` is the harness's opaque 0; threading it through the map lambda keeps the
-- whole pipeline from folding to a compile-time constant (see lib/Bench.lean).
def main : IO Unit := bench "mapfilter" (fun z =>
  let zi := Int.ofNat z
  ((data.map (fun x => (x + zi) * (x + zi))).filter (fun x => x % 2 == 0)).foldl (· + ·) 0)
