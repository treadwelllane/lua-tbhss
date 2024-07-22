local test = require("santoku.test")
local util = require("tbhss.util")
local hash = require("tbhss.hash")
local bm = require("santoku.bitmap")
local arr = require("santoku.array")

test("fingerprint", function ()

  local sentences = {
    { original = "The quick brown fox" },
    { original = "The brown quick fox" },
    { original = "A quick brown fox" },
    { original = "A brown quick fox" },
    { original = "The quick brown cat" },
    { original = "The brown quick cat" },
    { original = "The speedy brown fox" },
    { original = "The quick green fox" },
    { original = "The speedy brown cat" },
    { original = "The speedy green cat" },
  }

  local ids = {}
  local next_id = 1

  for i = 1, #sentences do
    sentences[i].split = util.split(sentences[i].original)
    sentences[i].tokens = {}
    for j = 1, #sentences[i].split do
      local word = sentences[i].split[j]
      local id = ids[word]
      if not id then
        id = next_id
        ids[word] = next_id
        next_id = next_id + 1
      end
      arr.push(sentences[i].tokens, id)
    end
  end

  local scores = {
    [ids.the] = 1,
    [ids.a] = 1,
    [ids.quick] = 3,
    [ids.speedy] = 3,
    [ids.brown] = 4,
    [ids.green] = 5,
    [ids.fox] = 7,
    [ids.cat] = 7,
  }

  local bits
  local topic_segments = 1
  local pos_segments = 1
  local pos_dimensions = 2
  local pos_buckets = 4

  for i = 1, #sentences do
    local raw
    raw, bits = hash.fingerprint(
      sentences[i].tokens,
      scores,
      topic_segments,
      pos_segments,
      pos_dimensions,
      pos_buckets)
    sentences[i].fingerprint = bm.from_raw(raw)
  end

  print()
  print(sentences[1].original)
  print()

  for i = 2, #sentences do
    local dist = bm.hamming(sentences[1].fingerprint, sentences[i].fingerprint) / bits
    print(sentences[i].original, dist)
  end

end)
