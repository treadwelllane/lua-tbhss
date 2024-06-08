local test = require("santoku.test")
local hash = require("tbhss.hash")
local bm = require("santoku.bitmap")

local str = "@@ -69,7 +69,7 @@ nohup stdbuf -oL tbhss create bitmaps clustered  nohup stdbuf -oL tbhss create encoder  --cache tbhss.db  --name glove.6B.300d.256.train.1.8.00.8.256  -  --bitmaps glove.6B.300d.256.train.1.8.00   +  --bitmaps glove.6B.300d.256.train.1.8.00  --sentences snli_1.0.train snli_1.0.test  --segments 8  ...skipping... diff --git a/res/scripts.sh b/res/scripts.sh index 62cf717..e9b7650 100644 --- a/res/scripts.sh +++ b/res/scripts.sh @@ -28,7 +28,7 @@ nohup stdbuf -oL tbhss create bitmaps clustered  nohup stdbuf -oL tbhss create encoder  --cache tbhss.db  --name glove.6B.300d.256.test.1.8.00.8.256  -  --bitmaps glove.6B.300d.256.test.1.8.00   +  --bitmaps glove.6B.300d.256.test.1.8.00  --sentences snli_1.0.test  --segments 8  --encoded-bits 256  @@ -69,7 +69,7 @@ nohup stdbuf -oL tbhss create bitmaps clustered  nohup stdbuf -oL tbhss create encoder  --cache tbhss.db  --name glove.6B.300d.256.train.1.8.00.8.256  -  --bitmaps glove.6B.300d.256.train.1.8.00   +  --bitmaps glove.6B.300d.256.train.1.8.00  --sentences snli_1.0.train snli_1.0.test  --segments 8  ...skipping... diff --git a/res/scripts.sh b/res/scripts.sh index 62cf717..e9b7650 100644" -- luacheck: ignore

test("hash", function ()
  print(bm.tostring(bm.from_raw(hash(str)), 64))
  print(bm.tostring(bm.from_raw(hash(str)), 64))
  print(bm.tostring(bm.from_raw(hash(str, 2)), 64 * 2))
  print(bm.tostring(bm.from_raw(hash(str, 3)), 64 * 3))
  print(bm.tostring(bm.from_raw(hash(str, 4)), 64 * 4))
end)
