local fs = require("santoku.fs")

local db_file = ".test.db"
fs.rm(db_file, true)

local db = require("tbhss.db")(db_file)

local modeler = require("tbhss.modeler")
local classifier = require("tbhss.classifier")
local process = require("tbhss.preprocess")

process.imdb({
  dirs = { "test/res/imdb.dev" },
  train_test_ratio = 0.9,
  sentences = {
    "test/res/imdb.train.sentences.txt",
    "test/res/imdb.test.sentences.txt"
  },
  samples = {
    "test/res/imdb.train.triplets.txt",
    "test/res/imdb.test.triplets.txt"
  },
  max = 2000
})

modeler.create(db, {
  name = "imdb",
  max_df = 0.2,
  min_len = 3,
  hidden = 1024,
  wavelength = 4096,
  dimensions = 1,
  buckets = 1,
  sentences = "test/res/imdb.train.sentences.txt",
  iterations = 100,
})

classifier.create(db, {
  name = "imdb",
  modeler = "imdb",
  clauses = 4096,
  state_bits = 8,
  target = 256,
  active_clause = 0.85,
  boost_true_positive = false,
  spec_low = 2,
  spec_high = 200,
  samples = {
    "test/res/imdb.train.samples.txt",
    "test/res/imdb.test.samples.txt"
  },
  evaluate_every = 1,
  iterations = 10,
})
