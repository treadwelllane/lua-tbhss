local test = require("santoku.test")
local fingerprint = require("tbhss.fingerprint")
local bm = require("santoku.bitmap")

test("fingerprint", function ()

  local t = {}

  for i = 1, 100 do
    t[i] = i
  end

  local segments = 2

  local a, bits = fingerprint(t, segments)
  a = bm.from_raw(a)
  print("> a", bm.tostring(a, bits))

  t[1] = 100
  local b, bits = fingerprint(t, segments)
  b = bm.from_raw(b)
  print("> b", bm.tostring(b, bits))

  t[2] = 101
  t[3] = 102
  t[4] = 103
  local c, bits = fingerprint(t, segments)
  c = bm.from_raw(c)
  print("> c", bm.tostring(c, bits))

  t[5] = 104
  t[6] = 105
  t[7] = 106
  local d, bits = fingerprint(t, segments)
  d = bm.from_raw(d)
  print("> d", bm.tostring(d, bits))

  print("> dist a a", bm.hamming(a, a))
  print("> dist a b", bm.hamming(a, b))
  print("> dist a c", bm.hamming(a, c))
  print("> dist a d", bm.hamming(a, d))

end)
