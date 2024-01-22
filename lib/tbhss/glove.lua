local blas = require("tbhss.blas")

local M = {}

M.load_vectors = function (glove_file, word_limit)

  local word_numbers = {}
  local word_names = {}
  local word_matrix = nil

  for line in io.lines(glove_file) do

    local iter = line:gmatch("%S+")
    local word = iter()

    word_names[#word_names + 1] = word
    word_numbers[word] = #word_names

    local floats = {}

    for float in iter do
      floats[#floats + 1] = tonumber(float)
    end

    if not word_matrix then
      word_matrix = blas.matrix({ floats })
    elseif #floats ~= word_matrix:columns() then
      error("Wrong number of dimensions for vector #" .. word_matrix:rows() + 1 .. ": " .. #floats)
    else
      word_matrix:extend({ floats })
    end

    if word_limit and word_matrix:rows() >= word_limit then
      break
    end

    if word_matrix:rows() % 5000 == 0 then
      print("Load Words", word_matrix:rows())
    end

  end

  print("Load Words", word_matrix:rows())

  word_matrix:normalize()

  return word_matrix, word_numbers, word_names

end

return M
