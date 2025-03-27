local fs = require("santoku.fs")

local db_file = ".test.db"
fs.rm(db_file, true)

local db = require("tbhss.db")(db_file)

local words = require("tbhss.words")
local clusters = require("tbhss.clusters")

words.load(db, {
  file = "test/res/glove_snli_dev.train.txt",
  name = "glove-snli-dev",
})

clusters.create(db, {
  name = "glove-snli-dev",
  words = "glove-snli-dev",
  algorithm = { "dbscan", 2, 0.625, 10 },
})
