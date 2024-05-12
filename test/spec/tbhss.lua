local fs = require("santoku.fs")
local sys = require("santoku.system")
local bm = require("santoku.bitmap")
local tbhss = require("tbhss")

local db_file = "tmp/test.db"

fs.mkdirp(fs.dirname(db_file))
fs.rm(db_file, true)
fs.rm(db_file .. "-wal", true)
fs.rm(db_file .. "-shm", true)

sys.execute({
  "lua", "bin/tbhss.lua", "load", "words",
  "--cache", db_file,
  "--name", "glove",
  "--file", os.getenv("GLOVE_TXT") or "test/res/glove.txt",
})

sys.execute({
  "lua", "bin/tbhss.lua", "create", "clusters",
  "--cache", db_file,
  "--name", "glove",
  "--words", "glove",
  "--clusters", "128"
})

sys.execute({
  "lua", "bin/tbhss.lua", "create", "bitmaps",
  "--cache", db_file,
  "--name", "glove",
  "--clusters", "glove",
  "--min-set", "1",
  "--max-set", "10",
  "--min-similarity", "0.6",
})

sys.execute({
  "lua", "bin/tbhss.lua", "load", "sentences",
  "--cache", db_file,
  "--name", "snli-dev",
  "--file", "test/res/snli_1.0_dev.txt",
})

sys.execute({
  "lua", "bin/tbhss.lua", "create", "encoder",
  "--cache", db_file,
  "--name", "glove",
  "--bitmaps", "glove",
  "--sentences", "snli-dev",
  "--output-bits", "128",
  "--train-test-ratio", "0.8",
  "--clauses", "40",
  "--state-bits", "8",
  "--threshold", "10",
  "--margin", "0.1",
  "--scale-loss", "0.25",
  "--specificity", "2",
  "--drop-clause", "0.75",
  "--boost-true-positive", "false",
  "--evaluate-every", "1",
  "--epochs", os.getenv("MAX_EPOCHS") or "10",
})

local normalizer = tbhss.normalizer(db_file, "glove")

print("\nNormalizer\n")
print(normalizer.normalize("the quick brown fox", 1, 1, 0))
print(normalizer.normalize("the quick brown fox", 1, 3, 0))
print(normalizer.normalize("the quick brown fox", 1, 10, 0.6))

local encoder = tbhss.encoder(db_file, "glove")

print("\nEncoder\n")
print("the", bm.tostring(encoder.encode("the"), encoder.bits))
print("quick", bm.tostring(encoder.encode("quick"), encoder.bits))
print("brown", bm.tostring(encoder.encode("brown"), encoder.bits))
print("fox", bm.tostring(encoder.encode("fox"), encoder.bits))
print("merged:", bm.tostring(encoder.encode("the quick brown fox"), encoder.bits))
