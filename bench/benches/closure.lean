import Bench

-- closure / higher-order-function stress (see bench/benches/closure.l): per i,
-- build (adder i) and (twice (adder i)), then apply -- twice(f) = \x f(f x), so
-- (twice (adder i)) i = i + 2i = 3i. checksum = sum of 3i over [0, N) = 14999850000.
def twice (f : Int → Int) : Int → Int := fun x => f (f x)
def adder (i : Int) : Int → Int := fun x => x + i
def N : Nat := 100000

-- `z` is the harness's opaque 0, threaded into the loop bound so the sum is not
-- folded to a compile-time constant (see lib/Bench.lean).
def main : IO Unit := bench "closure" (fun z => Id.run do
  let mut s : Int := 0
  for i in [0 : N + z] do
    let ii := Int.ofNat i
    s := s + twice (adder ii) ii
  return s)
