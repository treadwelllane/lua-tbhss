local fs = require("santoku.fs")
local sys = require("santoku.system")

local db_file = "tmp/test.db"

fs.mkdirp(fs.dirname(db_file))
fs.rm(db_file, true)
fs.rm(db_file .. "-wal", true)
fs.rm(db_file .. "-shm", true)
fs.rm("test/res/.train.pairs.txt", true)
fs.rm("test/res/.test.pairs.txt", true)
fs.rm("test/res/.train.triplets.txt", true)
fs.rm("test/res/.test.triplets.txt", true)

sys.execute({
  "lua", "bin/tbhss.lua", "process", "snli-pairs",
  "--inputs", "test/res/snli_1.0_dev.txt",
  "--train-test-ratio", "0.9",
  "--output-train", ".train.pairs.txt",
  "--output-test", ".test.pairs.txt",
})

sys.execute({
  "lua", "bin/tbhss.lua", "load", "words",
  "--cache", db_file,
  "--name", "glove",
  "--file", "test/res/glove_snli_dev.train.txt",
})

sys.execute({
  "lua", "bin/tbhss.lua", "load", "train-pairs",
  "--cache", db_file,
  "--name", "dev-train",
  "--file", ".train.pairs.txt",
  "--clusters", "glove", "k-medoids", "32", "32",
  "--fingerprints", "hashed", "4096", "256", "1", "128",
  "--weighting", "bm25", "1.2", "0.75",
  -- "--max-records", "1000",
  -- "--include-pos", "--pos-ancestors", "1",
  -- "--clusters", "glove", "k-medoids", "128", "2",
})

sys.execute({
  "lua", "bin/tbhss.lua", "load", "test-pairs",
  "--cache", db_file,
  "--name", "dev-test",
  "--file", ".test.pairs.txt",
  "--model", "dev-train",
  -- "--max-records", "100",
})

sys.execute({
  "lua", "bin/tbhss.lua", "create", "classifier",
  "--cache", db_file,
  "--name", "snli-dev",
  "--pairs", "dev-train", "dev-test",
  "--clauses", "512",
  "--state-bits", "8",
  "--threshold", "36",
  "--specificity", "2", "200",
  "--active-clause", "0.85",
  "--boost-true-positive", "false",
  "--evaluate-every", "1",
  "--epochs", "10"
})

-- sys.execute({
--   "lua", "bin/tbhss.lua", "create", "autoencoder",
--   "--cache", db_file,
--   "--name", "snli-dev",
--   "--triplets", "dev-train", "dev-test",
--   "--max-records", "1000", "100",
--   "--encoded-bits", "256",
--   "--clauses", "128",
--   "--state-bits", "8",
--   "--threshold", "36",
--   "--specificity", "4", "12",
--   "--loss-alpha", "0.125",
--   "--active-clause", "0.85",
--   "--boost-true-positive", "false",
--   "--evaluate-every", "1",
--   "--epochs", "5"
-- })

-- sys.execute({
--   "lua", "bin/tbhss.lua", "load", "compressed-triplets",
--   "--cache", db_file,
--   "--name", "dev-train-compressed",
--   "--triplets", "dev-train",
--   "--autoencoder", "snli-dev",
-- })

-- sys.execute({
--   "lua", "bin/tbhss.lua", "load", "compressed-triplets",
--   "--cache", db_file,
--   "--name", "dev-test-compressed",
--   "--triplets", "dev-test",
--   "--autoencoder", "snli-dev",
-- })

-- sys.execute({
--   "lua", "bin/tbhss.lua", "create", "encoder",
--   "--cache", db_file,
--   "--name", "snli-dev",
--   "--triplets", "dev-train-compressed", "dev-test-compressed",
--   "--max-records", "1000", "100",
--   "--encoded-bits", "128",
--   "--clauses", "512",
--   "--state-bits", "8",
--   "--threshold", "36",
--   "--specificity", "4", "12",
--   "--margin", "0.15",
--   "--loss-alpha", "0.25",
--   "--active-clause", "0.85",
--   "--boost-true-positive", "true",
--   "--evaluate-every", "1",
--   "--epochs", "50"
-- })
