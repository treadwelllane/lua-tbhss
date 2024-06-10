local test = require("santoku.test")
local fingerprint = require("tbhss.fingerprint")
local bm = require("santoku.bitmap")

test("fingerprint", function ()

  local t = {}

  for i = 1, 100 do
    t[i] = i
  end

  local a = bm.from_raw(fingerprint(t, 2))
  print("> a", bm.tostring(a, 128))

  t[1] = 100
  local b = bm.from_raw(fingerprint(t, 2))
  print("> b", bm.tostring(b, 128))

  t[2] = 101
  t[3] = 102
  t[4] = 103
  local c = bm.from_raw(fingerprint(t, 2))
  print("> c", bm.tostring(c, 128))

  print("> dist a a", bm.hamming(a, a))
  print("> dist a b", bm.hamming(a, b))
  print("> dist a c", bm.hamming(a, c))

end)
