local fs = require("santoku.fs")
local sys = require("santoku.system")

local db_file = "tmp/test.db"

fs.mkdirp(fs.dirname(db_file))
fs.rm(db_file, true)
fs.rm(db_file .. "-wal", true)
fs.rm(db_file .. "-shm", true)
fs.rm("test/res/.triplets.txt", true)
fs.rm("test/res/.train.triplets.txt", true)
fs.rm("test/res/.test.triplets.txt", true)

sys.execute({
  "lua", "bin/tbhss.lua", "process", "snli",
  "--input", "test/res/snli_1.0_dev.txt",
  "--output", ".train.triplets.txt",
  "--quality", "1", "1",
})

sys.execute({
  "lua", "bin/tbhss.lua", "process", "snli",
  "--input", "test/res/snli_1.0_test.txt",
  "--output", ".test.triplets.txt",
  "--quality", "1", "1",
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
  "--max-records", "2000",
  "--clusters", "glove", "dbscan", "2", "0.645", "5",
  "--merge", "false",
  "--dimensions", "4",
  "--buckets", "8",
  "--wavelength", "200",
  "--saturation", "1.2",
  "--length-normalization", "0.75",
})

sys.execute({
  "lua", "bin/tbhss.lua", "load", "test-triplets",
  "--cache", db_file,
  "--name", "dev-test",
  "--file", ".test.triplets.txt",
  "--max-records", "200",
  "--model", "dev-train",
})

sys.execute({
  "lua", "bin/tbhss.lua", "create", "encoder",
  "--cache", db_file,
  "--persist-file", ".tmp.bin",
  "--persist-state", "false",
  "--name", "snli-dev",
  "--triplets", "dev-train", "dev-test",
  "--encoded-bits", "64",
  "--clauses", "512",
  "--state-bits", "8",
  "--threshold", "36",
  "--specificity", "4", "12",
  "--margin", "0.15",
  "--loss-alpha", "0",
  "--active-clause", "0.85",
  "--boost-true-positive", "true",
  "--evaluate-every", "1",
  "--epochs", "50"
})
