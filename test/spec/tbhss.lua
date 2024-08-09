local fs = require("santoku.fs")
local sys = require("santoku.system")

local db_file = "tmp/test.db"

fs.mkdirp(fs.dirname(db_file))
fs.rm(db_file, true)
fs.rm(db_file .. "-wal", true)
fs.rm(db_file .. "-shm", true)
fs.rm("test/res/.train.triplets.txt", true)
fs.rm("test/res/.test.triplets.txt", true)

sys.execute({
  "lua", "bin/tbhss.lua", "process", "snli",
  "--inputs", "test/res/snli_1.0_dev.txt",
  "--train-test-ratio", "0.9",
  "--output-train", ".train.triplets.txt",
  "--output-test", ".test.triplets.txt",
})

sys.execute({
  "lua", "bin/tbhss.lua", "load", "words",
  "--cache", db_file,
  "--name", "glove",
  "--file", "test/res/glove_snli_dev.train.txt",
})

sys.execute({
  "lua", "bin/tbhss.lua", "load", "train-triplets",
  "--cache", db_file,
  "--name", "dev-train",
  "--file", ".train.triplets.txt",
  "--clusters", "glove", "1024", "1", "3", "0", "false",
  "--dimensions", "4",
  "--buckets", "20",
  "--saturation", "1.2",
  "--length-normalization", "0.75",
})

sys.execute({
  "lua", "bin/tbhss.lua", "load", "test-triplets",
  "--cache", db_file,
  "--name", "dev-test",
  "--file", ".test.triplets.txt",
  "--model", "dev-train",
})

sys.execute({
  "lua", "bin/tbhss.lua", "create", "encoder",
  "--cache", db_file,
  "--name", "snli-dev",
  "--triplets", "dev-train", "dev-test",
  "--encoded-bits", "128",
  "--clauses", "2048",
  "--state-bits", "8",
  "--threshold", "32",
  "--specificity", "2", "200",
  "--margin", "0.1",
  "--loss-alpha", "0.25",
  "--active-clause", "0.85",
  "--boost-true-positive", "true",
  "--evaluate-every", "1",
  "--epochs", "50"
})

-- sys.execute({
--   "lua", "bin/tbhss.lua", "create", "clusters",
--   "--cache", db_file,
--   "--name", "glove",
--   "--words", "glove",
--   "--clusters", "1024",
--   "--min", "1",
--   "--max", "3",
--   "--cutoff", "0",
-- })

