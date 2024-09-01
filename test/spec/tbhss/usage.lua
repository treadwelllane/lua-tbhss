local test = require("santoku.test")
local tbhss = require("tbhss")
local bm = require("santoku.bitmap")

test("encode", function ()
  local raw, bits
  local encoder = tbhss.encoder("test/res/tbhss.08.31.2024.db", "snli405")
  raw, bits = encoder.encode("there are two people running in a field")
  print("Encoded", #raw, bits, bm.tostring(bm.from_raw(raw, bits), bits))
end)
