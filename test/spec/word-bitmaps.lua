local glove = require("tbhss.glove")
local cluster = require("tbhss.cluster")

local limit_words = 10000
local bitmap_size = 100

local glove_file = assert(os.getenv("GLOVE_TXT"), "Missing GLOVE_TXT variable")

local words, word_vectors = glove.load_vectors(glove_file, limit_words)
local word_numbers = cluster.cluster_vectors(words, word_vectors, bitmap_size)

assert(word_numbers["guitar"] == word_numbers["piano"])
assert(word_numbers["guitar"] == word_numbers["guitarist"])
assert(word_numbers["guitar"] ~= word_numbers["signal"])

-- local helpers = require("tbhss.helpers")
-- local bitmaps = require("tbhss.bitmaps")
-- local word_bitmaps = bitmaps.create_bitmaps(words, word_numbers, bitmap_size)
-- local compare = { "guitar", "piano", "maple", "signal" }
-- for i = 1, #compare do
--   for j = 1, #compare do
--     print()
--     print(compare[i], compare[j], helpers.dot_product(word_vectors[compare[i]], word_vectors[compare[j]]))
--     print(word_numbers[compare[i]], word_bitmaps[compare[i]])
--     print(word_numbers[compare[j]], word_bitmaps[compare[j]])
--   end
-- end
