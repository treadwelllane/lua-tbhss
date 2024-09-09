local test = require("santoku.test")
local sys = require("santoku.system")
local tbhss = require("tbhss")
local bm = require("santoku.bitmap")

test("sts", function ()

  local encoder = tbhss.encoder(
    "test/res/snli5.db",
    "test/res/snli5.bin",
    "snli5")

end)
