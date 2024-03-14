local err = require("santoku.error")
local error = err.error
local assert = err.assert
local mtx = require("santoku.matrix")
local fs = require("santoku.fs")
local str = require("santoku.string")
local it = require("santoku.iter")

local function load_vectors_from_file (db, model, glove_file, tag)

  local add_model = db.add_model
  local get_model_by_id = db.get_model_by_id
  local add_word = db.add_word
  local set_words_loaded = db.set_words_loaded

  print("Loading words from file:", glove_file)

  local word_numbers = {}
  local word_names = {}
  local n_dims = nil
  local floats = {}

  local m = mtx.create(0, 0)

  for line, s, e in fs.lines(glove_file) do

    local chunks = str.matches(line, "%S+", false, s, e)
    local word = str.sub(chunks())

    it.collect(it.map(str.number, chunks), floats, 1)

    if #word_names > 0 and #floats ~= n_dims then
      error("Wrong number of dimensions for vector", #word_names, #floats)
    elseif #word_names == 0 then
      mtx.reshape(m, #word_names, #floats)
      n_dims = #floats
    end

    word_names[#word_names + 1] = word
    word_numbers[word] = #word_names
    mtx.reshape(m, mtx.rows(m) + 1, n_dims)
    mtx.set(m, #word_names, floats)

    if mtx.rows(m) % 5000 == 0 then
      print("Loaded:", mtx.rows(m))
    end

  end

  mtx.normalize(m)

  print("Loaded:", mtx.rows(m), mtx.columns(m))
  print("Persisting word vectors")

  local id_model = model and model.id

  if not id_model then
    id_model = add_model(tag or glove_file, n_dims)
    model = get_model_by_id(id_model)
  end

  for i = 1, mtx.rows(m) do
    add_word(id_model, word_names[i], i, mtx.raw(m, i))
  end

  set_words_loaded(id_model)

  return model, m, word_numbers, word_names

end

local function load_vectors_from_db (db, model)

  print("Loading words from database")

  local word_matrix = mtx.create(0, model.dimensions)
  local word_numbers = {}
  local word_names = {}

  for word in db.get_words(model.id) do
    mtx.extend(word_matrix, word.vector)
    word_names[#word_names + 1] = word.name
    assert(#word_names == word.id, "Word order/id mismatch")
    word_numbers[word.name] = word.id
  end

  print("Loaded:", mtx.rows(word_matrix))

  return model, word_matrix, word_numbers, word_names

end

local function load_vectors (db, model, glove_file, tag)
  return db.transaction(function ()
    if model and model.words_loaded == 1 then
      return load_vectors_from_db(db, model)
    else
      return load_vectors_from_file(db, model, glove_file, tag)
    end
  end)
end

return {
  load_vectors = load_vectors
}
