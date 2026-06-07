Code.require_file("../lib/bench.exs", __DIR__)

data = Enum.to_list(0..9999)

# square every element, keep the even squares, sum them.
Bench.run("mapfilter", fn ->
  data
  |> Enum.map(&(&1 * &1))
  |> Enum.filter(&(rem(&1, 2) == 0))
  |> Enum.sum()
end)
