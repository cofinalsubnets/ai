package.path = (arg[0]:match("(.*/)") or "./") .. "../lib/?.lua;" .. package.path
local bench = require("bench")
-- tree-walking interpreter ev1 over a fixed AST P (Horner of 2x^3+3x^2+5x+7); sum P(i mod 97) mod
-- 1e9+7 for i in [0,N). checksum = 474938608.
local LIT, VAR, ADD, MUL = 0, 1, 2, 3
local P = {ADD, {MUL, {ADD, {MUL, {ADD, {MUL, {LIT, 2}, {VAR}}, {LIT, 3}}, {VAR}}, {LIT, 5}}, {VAR}}, {LIT, 7}}
local function ev1(nd, x)
  local t = nd[1]
  if t == LIT then return nd[2]
  elseif t == VAR then return x
  elseif t == ADD then return ev1(nd[2], x) + ev1(nd[3], x)
  else return ev1(nd[2], x) * ev1(nd[3], x) end
end
bench("spec-glaze", function()
  local a = 0
  for i = 0, 999999 do a = (a + ev1(P, i % 97)) % 1000000007 end
  return a
end)
