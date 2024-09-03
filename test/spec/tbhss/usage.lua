local test = require("santoku.test")
local tbhss = require("tbhss")
local bm = require("santoku.bitmap")

test("encode", function ()
  local a, n, p, bits
  local encoder = tbhss.encoder(
    "test/res/snli3.db", "snli3",
    "test/res/snli3.bin")
  a, bits = encoder.encode("there are two people running in a field")
  n = encoder.encode("it's raining outside'")
  p = encoder.encode("there are two animals running in a forest")
  a = bm.from_raw(a, bits)
  n = bm.from_raw(n, bits)
  p = bm.from_raw(p, bits)
  print("A-N", bm.hamming(a, n))
  print("A-P", bm.hamming(a, p))
end)
