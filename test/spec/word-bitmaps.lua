local fs = require("santoku.fs")
local err = require("santoku.err")

local init_db = require("tbhss.db")
local glove = require("tbhss.glove")
local cluster = require("tbhss.cluster")

local glove_file = "test/res/glove.txt"
local db_file = "tmp/test.db"

local clusters = 32

err.check(err.pwrap(function(check)

  check(fs.mkdirp(fs.dirname(db_file)))
  check(fs.rm(db_file, true))
  check(fs.rm(db_file .. "-wal", true))
  check(fs.rm(db_file .. "-shm", true))

  local db = check(init_db(db_file))
  local model, word_matrix = check(glove.load_vectors(db, nil, glove_file, nil))
  check(cluster.cluster_vectors(db, model, word_matrix, clusters))

end))
