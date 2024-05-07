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
  "lua", "bin/tbhss.lua", "load", "embeddings",
  "--cache", db_file,
  "--name", "glove",
  "--file", "test/res/glove.txt",
})

sys.execute({
  "lua", "bin/tbhss.lua", "create", "clusters",
  "--cache", db_file,
  "--name", "glove.128",
  "--embeddings", "glove",
  "--clusters", "128"
})

sys.execute({
  "lua", "bin/tbhss.lua", "create", "bitmaps", "clustered",
  "--cache", db_file,
  "--name", "glove.clustered.128.1.10.60",
  "--clusters", "glove.128",
  "--min-set", "1",
  "--max-set", "10",
  "--min-similarity", "0.6",
})

sys.execute({
  "lua", "bin/tbhss.lua", "create", "encoder",
  "--cache", db_file,
  "--name", "glove.encoded.20",
  "--bits", "128",
  "--embeddings", "glove",
  "--threshold-levels", "20",
  "--train-test-ratio", "0.1",
  "--clauses", "40",
  "--state-bits", "8",
  "--threshold", "80",
  "--specificity", "3",
  "--update-probability", "2",
  "--drop-clause", "0.75",
  "--evaluate-every", "5",
  "--epochs", "200",
})

sys.execute({
  "lua", "bin/tbhss.lua", "create", "bitmaps", "encoded",
  "--cache", db_file,
  "--name", "glove.encoded.20",
  "--encoder", "glove.encoded.20",
})

local normalizer = tbhss.normalizer(db_file, "glove.128")

print("\nNormalizer\n")
print(normalizer.normalize("the quick brown fox", 1, 1, 0))
print(normalizer.normalize("the quick brown fox", 1, 3, 0))
print(normalizer.normalize("the quick brown fox", 1, 10, 0.6))

local bitmapper0 = tbhss.bitmapper(db_file, "glove.clustered.128.1.10.60")

print("\nBitmapper (clustered)\n")
print("the", bm.tostring(bitmapper0.encode("the"), bitmapper0.bits))
print("quick", bm.tostring(bitmapper0.encode("quick"), bitmapper0.bits))
print("brown", bm.tostring(bitmapper0.encode("brown"), bitmapper0.bits))
print("fox", bm.tostring(bitmapper0.encode("fox"), bitmapper0.bits))
print("merged:", bm.tostring(bitmapper0.encode("the quick brown fox"), bitmapper0.bits))

local bitmapper1 = tbhss.bitmapper(db_file, "glove.encoded.20")

print("\nBitmapper (encoded)\n")
print("the", bm.tostring(bitmapper1.encode("the"), bitmapper1.bits))
print("quick", bm.tostring(bitmapper1.encode("quick"), bitmapper1.bits))
print("brown", bm.tostring(bitmapper1.encode("brown"), bitmapper1.bits))
print("fox", bm.tostring(bitmapper1.encode("fox"), bitmapper1.bits))
print("merged:", bm.tostring(bitmapper1.encode("the quick brown fox"), bitmapper1.bits))
