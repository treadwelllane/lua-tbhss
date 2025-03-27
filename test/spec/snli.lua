local fs = require("santoku.fs")

local db_file = ".test.db"
fs.rm(db_file, true)

local db = require("tbhss.db")(db_file)

local modeler = require("tbhss.modeler")
local encoder = require("tbhss.encoder")
local process = require("tbhss.preprocess")

process.snli({
  inputs = { "test/res/snli_1.0_dev.txt" },
  train_test_ratio = 0.9,
  sentences = {
    "test/res/snli.train.sentences.txt",
    "test/res/snli.test.sentences.txt"
  },
  triplets = {
    "test/res/snli.train.triplets.txt",
    "test/res/snli.test.triplets.txt"
  },
  max = 2000
})

modeler.create(db, {
  name = "snli",
  vocab = 1024,
  hidden = 256,
  wavelength = 4096,
  dimensions = 1,
  buckets = 1,
  sentences = "test/res/snli.train.sentences.txt",
  iterations = 10,
})

encoder.create(db, {
  name = "snli",
  modeler = "snli",
  hidden = 256,
  clauses = 4096,
  state_bits = 8,
  target = 256,
  active_clause = 0.85,
  boost_true_positive = false,
  spec_low = 2,
  spec_high = 200,
  margin = 0.15,
  loss_alpha = 0.5,
  triplets = {
    "test/res/snli.train.triplets.txt",
    "test/res/snli.test.triplets.txt"
  },
  evaluate_every = 1,
  iterations = 10,
})
