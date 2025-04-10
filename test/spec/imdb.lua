local fs = require("santoku.fs")

local db_file = ".test.db"
fs.rm(db_file, true)

local db = require("tbhss.db")(db_file)

local modeler = require("tbhss.modeler")
local classifier = require("tbhss.classifier")
local process = require("tbhss.preprocess")

process.imdb({
  dirs = { "../../../tmp/aclImdb/test" },
  train_test_ratio = 0.95,
  sentences = {
    "test/res/imdb.train.sentences.txt",
    "test/res/imdb.test.sentences.txt"
  },
  samples = {
    "test/res/imdb.train.samples.txt",
    "test/res/imdb.test.samples.txt"
  },
})

modeler.create(db, {
  name = "imdb",
  max_df = 0.95,
  min_df = 0.005,
  max_len = 20,
  min_len = 2,
  ngrams = 3,
  cgrams = 0,
  compress = true,
  hidden = 128,
  -- sentences = { "test/res/imdb.train.sentences.txt", },
  samples = { "test/res/imdb.train.samples.txt", },
  supervision = 0.25,
  iterations = 100,
  eps = 0.001,
  threads = nil,
})

classifier.create(db, {
  name = "imdb",
  modeler = "imdb",
  clauses = 32768,
  state = 8,
  target = 128,
  boost = true,
  active = 0.85,
  specificity_low = 2,
  specificity_high = 200,
  samples = { "test/res/imdb.train.samples.txt", "test/res/imdb.test.samples.txt" },
  evaluate_every = 1,
  iterations = 20,
  threads = nil,
})
