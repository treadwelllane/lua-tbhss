local fs = require("santoku.fs")
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
  "--file", "test/res/glove.txt",
})

-- sys.execute({
--   "lua", "bin/tbhss.lua", "create", "clusters",
--   "--cache", db_file,
--   "--name", "glove",
--   "--words", "glove",
--   "--clusters", "64"
-- })

sys.execute({
  "lua", "bin/tbhss.lua", "load", "sentences",
  "--cache", db_file,
  "--name", "snli-dev",
  "--file", "test/res/snli_1.0_dev.txt",
  "--clusters", "glove", "1024", "1", "3", "0", "false",
  "--segments", "1",
  "--dimensions", "4",
  "--buckets", "10",
  "--saturation", "1.2",
  "--length-normalization", "0.75",
  "--max-records", "2000",
})

sys.execute({
  "lua", "bin/tbhss.lua", "create", "encoder",
  "--cache", db_file,
  "--name", "snli-dev",
  "--sentences", "snli-dev",
  "--train-test-ratio", "0.8",
  "--encoded-bits", "128",
  "--clauses", "2048",
  "--state-bits", "8",
  "--threshold", "32",
  "--specificity", "2", "200",
  "--margin", "0.5",
  "--loss-alpha", "0.25",
  "--active-clause", "0.85",
  "--boost-true-positive", "true",
  "--evaluate-every", "1",
  "--epochs", "100"
})
