local helpers = require("tbhss.helpers")

local M = {}

M.load_vectors = function (glove_file, limit_words)

  local words = {}
  local vectors = {}
  local n_words = 0
  local n_dimensions = nil

  for line in io.lines(glove_file) do

    local iter = line:gmatch("%S+")
    local word = iter()
    words[#words + 1] = word
    local floats = {}
    for float in iter do
      floats[#floats + 1] = tonumber(float)
    end

    if not n_dimensions then
      n_dimensions = #floats
    elseif #floats ~= n_dimensions then
      error("Wrong number of dimensions for vector #" .. n_words + 1 .. ": " .. #floats)
    end

    helpers.normalize(floats)

    vectors[word] = floats

    n_words = n_words + 1

    if n_words % 5000 == 0 then
      print("Load Vectors", n_words)
    end

    if limit_words and n_words >= limit_words then
      break
    end

  end

  print("Load Vectors", n_words)

  return words, vectors, n_words, n_dimensions

end

return M
