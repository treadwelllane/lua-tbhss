local fs = require("santoku.fs")
-- local str = require("santoku.string")
local sys = require("santoku.system")
-- local bm = require("santoku.bitmap")
-- local tbhss = require("tbhss")

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
  "--min-similarity", " 0",
})

sys.execute({
  "lua", "bin/tbhss.lua", "create", "encoder",
  "--cache", db_file,
  "--name", "glove",
  "--bitmaps", "glove",
  "--segments", "1",
  "--encoded-bits", "256",
  "--sentences", "snli-dev",
  "--train-test-ratio", "0.5",
  "--clauses", "256",
  "--state-bits", "8",
  "--threshold", "512",
  "--margin", "0.1",
  "--loss-alpha", "0.125",
  "--specificity", "40",
  "--active-clause", "0.85",
  "--boost-true-positive", "false",
  "--evaluate-every", "1",
  "--max-records", "1000",
  "--epochs", "50",
})
