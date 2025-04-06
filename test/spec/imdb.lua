local fs = require("santoku.fs")

local db_file = ".test.db"
fs.rm(db_file, true)

local db = require("tbhss.db")(db_file)

local modeler = require("tbhss.modeler")
local classifier = require("tbhss.classifier")
local process = require("tbhss.preprocess")

process.imdb({
  dirs = { "test/res/imdb.dev" },
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
  min_df = 0.001,
  max_len = 20,
  min_len = 3,
  ngrams = 1,
  cgrams = 0,
  compress = true,
  hidden = 128,
  -- Note: Training the modeler with train and test sentences to simulate a
  -- larger unsupervised corpus. Can we avoid this?
  sentences = {
    "test/res/imdb.train.sentences.txt",
    "test/res/imdb.test.sentences.txt"
  },
  iterations = 10,
  eps = 0.0001,
  threads = nil,
})

classifier.create(db, {
  name = "imdb",
  modeler = "imdb",
  clauses = 8192,
  state = 8,
  target = 32,
  boost = true,
  active = 0.75,
  negatives = 0.25,
  replicas = 0,
  specificity_low = 2,
  specificity_high = 200,
  samples = {
    "test/res/imdb.train.samples.txt",
    "test/res/imdb.test.samples.txt"
  },
  evaluate_every = 1,
  iterations = 50,
  threads = nil,
})
