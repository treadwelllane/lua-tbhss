local fs = require("santoku.fs")
local str = require("santoku.string")
local env = require("santoku.env")
local init_db = require("tbhss.db")
local glove = require("tbhss.glove")
local cluster = require("tbhss.cluster")

local glove_file = env.var("GLOVE_TXT", "test/res/glove.2500.txt")
local db_file = "tmp/test.db"

local clusters = 16
local bitmap_scale_factor = 1
local bitmap_cutoff = 0.2

fs.mkdirp(fs.dirname(db_file))
fs.rm(db_file, true)
fs.rm(db_file .. "-wal", true)
fs.rm(db_file .. "-shm", true)

local db = init_db(db_file)
local model, word_matrix, _, word_names = glove.load_vectors(db, nil, glove_file, nil)
local distance_matrix = cluster.cluster_vectors(db, model, word_matrix, clusters)
local word_bitmaps = cluster.create_bitmaps(distance_matrix, bitmap_scale_factor, bitmap_cutoff)

local bm = require("santoku.bitmap")
local it = require("santoku.iter")
it.each(print, it.map(function (k, v)
  return k, str.format("%-15s", v), bm.tostring(word_bitmaps[k], clusters)
end, it.ipairs(word_names)))
