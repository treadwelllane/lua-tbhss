local fs = require("santoku.fs")
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

-- sys.execute({
--   "lua", "bin/tbhss.lua", "create", "bitmaps", "thresholded",
--   "--cache", db_file,
--   "--name", "glove.thresholded",
--   "--words", "glove",
--   "--threshold-levels", "3"
-- })

 sys.execute({
   "lua", "bin/tbhss.lua", "create", "clusters",
   "--cache", db_file,
   "--name", "glove",
   "--words", "glove",
   "--clusters", "128"
 })

 sys.execute({
   "lua", "bin/tbhss.lua", "create", "bitmaps", "clustered",
   "--cache", db_file,
   "--name", "glove.clustered",
   "--clusters", "glove",
   "--min-set", "1",
   "--max-set", "10",
   "--min-similarity", "0.6",
 })

 -- sys.execute({
 --   "lua", "bin/tbhss.lua", "create", "bitmaps", "encoded",
 --   "--cache", db_file,
 --   "--name", "glove.encoded",
 --   "--words", "glove",
 --   "--encoded-bits", "128",
 --   "--threshold-levels", "3",
 --   "--train-test-ratio", "0.5",
 --   "--margin", "0.1",
 --   "--similarity-positive", "0.7",
 --   "--similarity-negative", "0.5",
 --   "--clauses", "80",
 --   "--state-bits", "8",
 --   "--threshold", "200",
 --   "--specificity", "5",
 --   "--drop-clause", "0.75",
 --   "--loss-alpha", "5",
 --   "--boost-true-positive", "false",
 --   "--evaluate-every", "5",
 --   "--epochs", "50",
 -- })

-- sys.execute({
--   "lua", "bin/tbhss.lua", "create", "bitmaps", "auto-encoded",
--   "--cache", db_file,
--   "--name", "glove.auto-encoded",
--   "--words", "glove",
--   "--encoded-bits", "128",
--   "--threshold-levels", "3",
--   "--train-test-ratio", "0.5",
--   "--clauses", "80",
--   "--state-bits", "8",
--   "--threshold", "200",
--   "--loss-alpha", "0.001",
--   "--specificity", "1.003",
--   "--drop-clause", "0.75",
--   "--boost-true-positive", "false",
--   "--max-records", "1000",
--   "--evaluate-every", "5",
--   "--epochs", "20",
-- })

sys.execute({
  "lua", "bin/tbhss.lua", "load", "sentences",
  "--cache", db_file,
  "--name", "snli-dev",
  "--file", os.getenv("SNLI") or "test/res/snli_1.0_dev.txt",
})

sys.execute({
  "lua", "bin/tbhss.lua", "create", "encoder",
  "--cache", db_file,
  "--name", "glove",
  -- "--bitmaps", "glove.thresholded",
  -- "--bitmaps", "glove.auto-encoded",
  "--bitmaps", "glove.clustered",
  "--sentences", "snli-dev",
  "--encoded-bits", "128",
  "--train-test-ratio", "0.5",
  "--clauses", "80",
  "--state-bits", "8",
  "--threshold", "200",
  "--margin", "0.01",
  "--loss-alpha", "0.75",
  "--specificity", "2",
  "--drop-clause", "0.75",
  "--boost-true-positive", "false",
  "--evaluate-every", "1",
  "--max-records", "100",
  "--epochs", "1000",
})

-- local normalizer = tbhss.normalizer(db_file, "glove")
--
-- print("\nNormalizer\n")
--
-- print(normalizer.normalize("the quick brown fox", 1, 1, 0))
-- print(normalizer.normalize("the quick brown fox", 1, 3, 0))
-- print(normalizer.normalize("the quick brown fox", 1, 10, 0.6))
--
-- local encoder = tbhss.encoder(db_file, "glove")
--
-- print("\nEncoder\n")
--
-- luacheck: push ignore
--  local docs = {
--    {
--      anchor = "Two women are embracing while holding to go packages.",
--      positive = "Two woman are holding packages.",
--      negative = "The sisters are hugging goodbye while holding to go packages after just eating lunch."
--    },
--    {
--      anchor = "Two women are embracing while holding to go packages.",
--      positive = "Two woman are holding packages.",
--      negative = "The men are fighting outside a deli."
--    },
--    {
--      anchor = "Two women are embracing while holding to go packages.",
--      positive = "Two woman are holding packages.",
--      negative = "The sisters are hugging goodbye while holding to go packages after just eating lunch."
--    },
--    {
--      anchor = "Two women are embracing while holding to go packages.",
--      positive = "Two woman are holding packages.",
--      negative = "The men are fighting outside a deli."
--    },
--    {
--      anchor = "Two women are embracing while holding to go packages.",
--      positive = "Two woman are holding packages.",
--      negative = "The sisters are hugging goodbye while holding to go packages after just eating lunch."
--    },
--    {
--      anchor = "Two women are embracing while holding to go packages.",
--      positive = "Two woman are holding packages.",
--      negative = "The men are fighting outside a deli."
--    },
--    {
--      anchor = "Two young children in blue jerseys, one with the number 9 and one with the number 2 are standing on wooden steps in a bathroom and washing their hands in a sink.", -- luacheck: ignore
--      positive = "Two kids in numbered jerseys wash their hands.",
--      negative = "Two kids at a ballgame wash their hands."
--    },
--    {
--      anchor = "Two young children in blue jerseys, one with the number 9 and one with the number 2 are standing on wooden steps in a bathroom and washing their hands in a sink.", -- luacheck: ignore
--      positive = "Two kids in numbered jerseys wash their hands.",
--      negative = "Two kids in jackets walk to school."
--    },
--    {
--      anchor = "Two young children in blue jerseys, one with the number 9 and one with the number 2 are standing on wooden steps in a bathroom and washing their hands in a sink.", -- luacheck: ignore
--      positive = "Two kids in numbered jerseys wash their hands.",
--      negative = "Two kids at a ballgame wash their hands."
--    },
--    {
--      anchor = "Two young children in blue jerseys, one with the number 9 and one with the number 2 are standing on wooden steps in a bathroom and washing their hands in a sink.", -- luacheck: ignore
--      positive = "Two kids in numbered jerseys wash their hands.",
--      negative = "Two kids in jackets walk to school."
--    }
--  }
-- luacheck: pop ignore
--
--  for i = 1, #docs do
--    local d = docs[i]
--    local a = encoder.encode(d.anchor)
--    local n = encoder.encode(d.negative)
--    local p = encoder.encode(d.positive)
--    local dan = bm.hamming(a, n)
--    local dap = bm.hamming(a, p)
--    print(d.anchor)
--    print("", "negative", dan, d.negative)
--    print("", "positive", dap, d.positive)
--    print("", dap < dan)
--    print()
--  end

