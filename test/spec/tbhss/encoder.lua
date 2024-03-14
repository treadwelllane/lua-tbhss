-- Step 1: Train a TM to convert a word embedding vector to a bitmap where
-- hamming distance approximates cosine similarity.
--
-- Dataset & training:
-- - Randomly sample a subset of vector pairs and calculate cosine similarity
-- - Run each vector through and calculate hamming distance
-- - Compare the hamming distance of the bitmaps to the cosine similarity of the
--   vectors
-- - If too high, reinforce outputting 0s
-- - If too low, reinforce outputting 1s
--
-- Testing:
-- - Convert all word vectors to bitmaps, building a hash table from word to
--   bitmap (many words will have a hamming distance of zero, allowing for
--   re-use of bitmaps)
-- - Evaluate sentence similarity using the sts-benchmark dataset, representing
--   sentences as a word-bitmap bloom filter and similarity as hamming distance

-- Step 2: Train a TM to add semantic understanding to the sentence bloom
-- filters using the sts-benchmark dataset
--
-- Datset & training:
-- - Convert the [sentence, sentence, score] records in the sts-benchmark
--   dataset to [sentence-bloom, sentence-bloom, score]
-- - Perform the same training as in Step 1, this time comparing hamming
--   distance to the similarity score
--
-- Usage:
-- - Evaluate sentence similarity as in Step 1, representing sentences as
--   word-bitmap bloom filters that have been processed by this second TM

local fs = require("santoku.fs")
local str = require("santoku.string")
local env = require("santoku.env")
local init_db = require("tbhss.db")
local glove = require("tbhss.glove")
local encoder = require("tbhss.encoder")

local glove_file = env.var("GLOVE_TXT", "test/res/glove.2500.txt")
local db_file = "tmp/test.db"

local encoded_size = 64
local threshold_levels = 10
local clauses = 40
local threshold = 10
local specificity = 3
local drop_clause = 0.85
local max_epochs = 100
local evaluate_every = 10
local train_test_ratio = 0.5

fs.mkdirp(fs.dirname(db_file))
fs.rm(db_file, true)
fs.rm(db_file .. "-wal", true)
fs.rm(db_file .. "-shm", true)

local db = init_db(db_file)
local model, word_matrix, _, word_names = glove.load_vectors(db, nil, glove_file, nil)
local word_bitmaps, n_features = encoder.create_bitmaps(word_matrix, threshold_levels)

local t = tm.encoder(encoded_size, n_features, clauses, threshold)

local bm = require("santoku.bitmap")
local it = require("santoku.iter")
it.each(print, it.map(function (k, v)
  return k, str.format("%-15s", v), bm.tostring(word_bitmaps[k], clusters)
end, it.ipairs(word_names)))

