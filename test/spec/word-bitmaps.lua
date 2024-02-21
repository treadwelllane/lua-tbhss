local test = require("santoku.test")

test("word bitmaps", function ()

  local fs = require("santoku.fs")
  local env = require("santoku.env")

  local init_db = require("tbhss.db")
  local glove = require("tbhss.glove")
  local cluster = require("tbhss.cluster")
  local bitmaps = require("tbhss.bitmaps")

  local glove_file = env.var("GLOVE_TXT", "test/res/glove.2500.txt")
  local db_file = "tmp/test.db"

  local clusters = 16
  local bitmap_scale_factor = 8

  fs.mkdirp(fs.dirname(db_file))
  fs.rm(db_file, true)
  fs.rm(db_file .. "-wal", true)
  fs.rm(db_file .. "-shm", true)

  local db = init_db(db_file)
  local model, word_matrix = glove.load_vectors(db, nil, glove_file, nil)
  local distance_matrix = cluster.cluster_vectors(db, model, word_matrix, clusters)
  bitmaps.create_bitmaps(distance_matrix, bitmap_scale_factor)

end)
