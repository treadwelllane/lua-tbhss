local test = require("santoku.test")
local fs = require("santoku.fs")
local sys = require("santoku.system")

local db_file = "tmp/test-cluster.db"

fs.mkdirp(fs.dirname(db_file))
fs.rm(db_file, true)
fs.rm(db_file .. "-wal", true)
fs.rm(db_file .. "-shm", true)

test("cluster", function ()

  sys.execute({
    "lua", "bin/tbhss.lua", "load", "words",
    "--cache", db_file,
    "--name", "glove",
    "--file", "test/res/glove_snli_dev.train.txt",
  })

  sys.execute({
    "lua", "bin/tbhss.lua", "create", "clusters",
    "--cache", db_file,
    "--name", "glove",
    "--words", "glove",
    "--clusters", "1024",
    "--min", "1",
    "--max", "1",
    "--cutoff", "0",
  })

end)
