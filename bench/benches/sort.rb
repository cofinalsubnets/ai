require_relative "../lib/bench"

# sort N pseudo-random ints (MINSTD LCG), order-dependent rolling-hash checksum.
N = 5000

def work
  x = 1
  data = []
  N.times { x = (16807 * x) % 2147483647; data << x }
  data.sort!
  h = 0
  data.each { |v| h = (h * 31 + v) % 1000000007 }
  h
end

bench("sort") { work }
