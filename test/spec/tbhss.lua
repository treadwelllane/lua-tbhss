local fs = require("santoku.fs")
local sys = require("santoku.system")

local db_file = "tmp/test.db"

fs.mkdirp(fs.dirname(db_file))
fs.rm(db_file, true)
fs.rm(db_file .. "-wal", true)
fs.rm(db_file .. "-shm", true)
fs.rm("test/res/.train.sentences.txt", true)
fs.rm("test/res/.test.sentences.txt", true)
fs.rm("test/res/.train.pairs.txt", true)
fs.rm("test/res/.test.pairs.txt", true)
fs.rm("test/res/.train.triplets.txt", true)
fs.rm("test/res/.test.triplets.txt", true)

-- -- Loads glove embeddings
-- sys.execute({
--   "lua", "bin/tbhss.lua", "load", "words",
--   "--cache", db_file,
--   "--name", "glove",
--   "--file", "test/res/glove_snli_dev.train.txt",
-- })

-- -- Clusters glove embeddings
-- sys.execute({
--   "lua", "bin/tbhss.lua", "create", "clusters",
--   "--cache", db_file,
--   "--name", "glove",
--   "--words", "glove",
--   "--algorithm", "dbscan", "2", "0.625"
--   -- TODO: specify a .txt file containing words to filter by
--   -- "--filter-words", "test/res/filter_words.txt"
-- })

-- Cleans snli dataset
sys.execute({
  "lua", "bin/tbhss.lua", "process", "snli",
  "--inputs", "test/res/snli_1.0_dev.txt",
  "--train-test-ratio", "0.9",
  "--pairs", ".train.pairs.txt", ".test.pairs.txt",
  "--triplets", ".train.triplets.txt", ".test.triplets.txt",
  "--sentences", ".train.sentences.txt", ".test.sentences.txt",
})

sys.execute({
  "lua", "bin/tbhss.lua", "create", "modeler",
  "--cache", db_file,
  "--name", "snli-dev",
  "--vocab", "1024",
  "--position", "4096", "8", "8",
  "--hidden", "2048",
  "--sentences", ".train.sentences.txt",
  "--iterations", "50",
})

sys.execute({
  "lua", "bin/tbhss.lua", "create", "classifier",
  "--cache", db_file,
  "--name", "snli-dev",
  "--modeler", "snli-dev",
  "--pairs", ".train.pairs.txt", ".test.pairs.txt",
  "--clauses", "512",
  "--state-bits", "8",
  "--target", "36",
  "--specificity", "2", "200",
  "--active-clause", "0.85",
  "--boost-true-positive", "false",
  "--evaluate-every", "1",
  "--iterations", "50"
})

sys.execute({
  "lua", "bin/tbhss.lua", "create", "encoder",
  "--cache", db_file,
  "--name", "snli-dev",
  "--modeler", "snli-dev",
  "--hidden", "1024",
  "--clauses", "512",
  "--state-bits", "8",
  "--target", "36",
  "--specificity", "4", "12",
  "--margin", "0.15",
  "--loss-alpha", "0.25",
  "--active-clause", "0.85",
  "--boost-true-positive", "false",
  "--evaluate-every", "1",
  "--iterations", "50"
})
