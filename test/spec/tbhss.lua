local fs = require("santoku.fs")
local str = require("santoku.string")
local sys = require("santoku.system")

local db_file = "tmp/test.db"

fs.mkdirp(fs.dirname(db_file))
fs.rm(db_file, true)
fs.rm(db_file .. "-wal", true)
fs.rm(db_file .. "-shm", true)

sys.execute({
  "lua", "bin/tbhss.lua", "load", "words",
  "--cache", db_file,
  "--name", "glove",
  "--file", os.getenv("GLOVE") or "test/res/glove.txt",
})

sys.execute({
  "lua", "bin/tbhss.lua", "load", "sentences",
  "--cache", db_file,
  "--name", "snli-dev",
  "--file", os.getenv("SNLI") or "test/res/snli_1.0_dev.txt",
})

sys.execute({
  "lua", "bin/tbhss.lua", "create", "clusters",
  "--cache", db_file,
  "--name", "glove",
  "--words", "glove",
  "--filter-words", "snli-dev",
  "--clusters", "256"
})

sys.execute({
  "lua", "bin/tbhss.lua", "create", "bitmaps", "clustered",
  "--cache", db_file,
  "--name", "glove",
  "--clusters", "glove",
  "--min-set", "1",
  "--max-set", "8",
  "--min-similarity", "0",
})

sys.execute({
  "sh", "-c", str.interp([[
    lua bin/tbhss.lua create encoder \
    --cache %db \
    --name glove \
    --bitmaps glove \
    --sentences snli-dev \
    --segments 1 \
    --encoded-bits 256 \
    --train-test-ratio 0.5 \
    --clauses 64 \
    --state-bits 8 \
    --threshold 256 \
    --specificity 35 45 \
    --margin 0.1 \
    --loss-alpha 0.25 \
    --active-clause 0.85 \
    --boost-true-positive false \
    --max-records 4000 \
    --evaluate-every 1 \
    --epochs 100
  ]], {
    db = db_file,
  })
})
