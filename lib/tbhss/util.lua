local bm = require("santoku.bitmap")
local init_db = require("tbhss.db")
local str = require("santoku.string")
local arr = require("santoku.array")

local function get_db (db_file)
  return type(db_file) == "string" and init_db(db_file) or db_file
end

local function split (s, max, words)
  words = words or {}
  local n = 1
  for w in str.gmatch(s, "%S+") do
    words[n] = str.lower(w)
    words[n] = str.gsub(words[n], "^%p*", "")
    words[n] = str.gsub(words[n], "%p*$", "")
    n = n + 1
    if max and n > max then
      break
    end
  end
  arr.clear(words, n)
  return words
end

local function prep_fingerprint (fingerprint, bits)
  local flipped = bm.copy(fingerprint)
  bm.flip(flipped, 1, bits)
  bm.extend(fingerprint, flipped, bits + 1)
  return fingerprint
end

return {
  get_db = get_db,
  split = split,
  prep_fingerprint = prep_fingerprint,
}
