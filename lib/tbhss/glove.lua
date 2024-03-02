local err = require("santoku.error")
local error = err.error
local assert = err.assert

local mtx = require("santoku.matrix")
local matrix = mtx.matrix
local mreshape = mtx.reshape
local mextend = mtx.extend
local mset = mtx.set
local mrows = mtx.rows
local mcolumns = mtx.columns
local mnormalize = mtx.normalize
local mto_raw = mtx.to_raw

local fs = require("santoku.fs")
local flines = fs.lines

local varg = require("santoku.varg")
local vtup = varg.tup

local str = require("santoku.string")
local smatch = str.match
local ssub = str.sub
local snumber = str.number

local iter = require("santoku.iter")
local imap = iter.map
local icollect = iter.collect

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

  local mtx = matrix(0, 0)

  for line, s, e in flines(glove_file) do

    local chunks = smatch(line, "%S+", false, s, e)
    local word = ssub(chunks())

    icollect(imap(snumber, chunks), floats, 1)

    if #word_names > 0 and #floats ~= n_dims then
      error("Wrong number of dimensions for vector", #word_names, #floats)
    elseif #word_names == 0 then
      mreshape(mtx, #word_names, #floats)
      n_dims = #floats
    end

    word_names[#word_names + 1] = word
    word_numbers[word] = #word_names
    mreshape(mtx, mrows(mtx) + 1, n_dims)
    mset(mtx, #word_names, floats)

    if mrows(mtx) % 5000 == 0 then
      print("Loaded:", mrows(mtx))
    end

  end

  mnormalize(mtx)

  print("Loaded:", mrows(mtx), mcolumns(mtx))
  print("Persisting word vectors")

  local id_model = model and model.id

  if not id_model then
    id_model = add_model(tag or glove_file, n_dims)
    model = get_model_by_id(id_model)
  end

  for i = 1, mrows(mtx) do
    add_word(id_model, word_names[i], i, mto_raw(mtx, i))
  end

  set_words_loaded(id_model)

  return model, mtx, word_numbers, word_names

end

local function load_vectors_from_db (db, model)

  print("Loading words from database")

  local word_matrix = matrix(0, model.dimensions)
  local word_numbers = {}
  local word_names = {}

  for word in db.get_words(model.id) do
    mextend(word_matrix, word.vector)
    word_names[#word_names + 1] = word.name
    assert(#word_names == word.id, "Word order/id mismatch")
    word_numbers[word.name] = word.id
  end

  print("Loaded:", mrows(word_matrix))

  return model, word_matrix, word_numbers, word_names

end

local function load_vectors (db, model, glove_file, tag)
  db.begin()
  -- TODO: use db.transaction
  return vtup(function (ok, ...)
    if not ok then
      db.rollback()
      error(...)
    else
      db.commit()
      return ...
    end
  end, pcall(function ()
    if model and model.words_loaded == 1 then
      return load_vectors_from_db(db, model)
    else
      return load_vectors_from_file(db, model, glove_file, tag)
    end
  end))
end

return {
  load_vectors = load_vectors
}
