local fs = require("santoku.fs")
local err = require("santoku.err")
local str = require("santoku.string")
local vec = require("santoku.vector")
local blas = require("tbhss.blas")

local M = {}

local function load_vectors_from_file (check, db, model, glove_file, tag)

  print("Loading words from file:", glove_file)

  local word_numbers = {}
  local word_names = vec()
  local word_matrix = blas.matrix(0, 0)
  local n_dims = 0

  check(fs.lines(glove_file)):each(function (line)

    local floats = str.split(line)
    local word = floats[1]
    floats:remove(1, 1):map(tonumber)

    if word_names.n > 0 and floats.n ~= n_dims then
      error("Wrong number of dimensions for vector #" .. word_names.n .. ": " .. floats.n)
    elseif word_names.n == 0 then
      word_matrix:reshape(word_names.n, floats.n)
      n_dims = floats.n
    end

    word_names:append(word)
    word_numbers[word] = word_names.n
    word_matrix:extend({ floats })

    if word_matrix:rows() % 5000 == 0 then
      print("Loaded:", word_matrix:rows())
    end

  end)

  word_matrix:normalize()

  print("Loaded:", word_matrix:rows())
  print("Persisting word vectors")

  check(db.db:begin())
  if not model then
    local id_model = check(db.add_model(tag or glove_file, n_dims))
    model = check(db.get_model_by_id(id_model))
  end
  for i = 1, word_matrix:rows() do
    check(db.add_word(model.id, word_names[i], i, word_matrix:raw(i)))
  end
  check(db.set_words_loaded(model.id))
  check(db.db:commit())

  return model, word_matrix, word_numbers, word_names

end

local function load_vectors_from_db (check, db, model)

  print("Loading words from database")

  local word_matrix = blas.matrix(0, model.dimensions)
  local word_numbers = {}
  local word_names = vec()

  check(db.db:begin())
  check(db.get_words(model.id)):map(check):each(function (word)
    word_matrix:extend(word.vector)
    word_names:append(word.name)
    assert(word_names.n == word.id, "Word order/id mismatch")
    word_numbers[word.name] = word.id
  end)
  check(db.db:commit())

  print("Loaded:", word_matrix:rows())

  return model, word_matrix, word_numbers, word_names

end

M.load_vectors = function (db, model, glove_file, tag)
  return err.pwrap(function (check)

    if model and model.words_loaded == 1 then
      return load_vectors_from_db(check, db, model)
    else
      return load_vectors_from_file(check, db, model, glove_file, tag)
    end

  end)
end

return M
