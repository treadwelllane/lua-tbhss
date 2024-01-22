local blas = require("tbhss.blas")

local M = {}

M.load_vectors = function (glove_file, word_limit)

  local word_numbers = {}
  local word_names = {}
  local word_matrix = blas.matrix(0, 0)
  local n_words = 0
  local n_dims = 0

  for line in io.lines(glove_file) do

    local iter = line:gmatch("%S+")
    local word = iter()

    word_names[#word_names + 1] = word
    word_numbers[word] = #word_names

    local floats = {}

    for float in iter do
      floats[#floats + 1] = tonumber(float)
    end

    if n_words > 0 and #floats ~= n_dims then
      error("Wrong number of dimensions for vector #" .. n_words + 1 .. ": " .. #floats)
    elseif n_words == 0 then
      word_matrix:reshape(n_words, #floats)
      n_dims = #floats
    end

    word_matrix:extend({ floats })
    n_words = n_words + 1

    if word_limit and n_words >= word_limit then
      break
    end

    if n_words % 5000 == 0 then
      print("Load Words", n_words)
    end

  end

  print("Load Words", n_words)

  word_matrix:normalize()

  return word_matrix, word_numbers, word_names

end

return M
