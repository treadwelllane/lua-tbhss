local err = require("santoku.error")

local mtx = require("santoku.matrix")
local mcreate = mtx.create
local mreshape = mtx.reshape
local mextend = mtx.extend
local mset = mtx.set
local mrows = mtx.rows
local mcolumns = mtx.columns
local mnormalize = mtx.normalize
local mraw = mtx.raw

local fs = require("santoku.fs")
local flines = fs.lines

local str = require("santoku.string")
local smatches = str.matches
local ssub = str.sub
local snumber = str.number

local iter = require("santoku.iter")
local imap = iter.map
local icollect = iter.collect

local function load_words_from_file (db, model, args)

  print("Loading words from file:", args.file)

  local word_numbers = {}
  local word_names = {}
  local n_dims = nil
  local floats = {}

  local mtx = mcreate(0, 0)

  for line in flines(args.file) do

    local chunks = smatches(line, "%S+")
    local word = ssub(chunks())

    icollect(imap(snumber, chunks), floats, 1)

    if #word_names > 0 and #floats ~= n_dims then
      err.error("Wrong number of dimensions for embedding", #word_names, #floats)
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
  print("Persisting words")

  local id_model = model and model.id

  if not id_model then
    id_model = db.add_words_model(args.name, n_dims)
    model = db.get_words_model_by_id(id_model)
  end

  for i = 1, mrows(mtx) do
    db.add_word(i, id_model, word_names[i], mraw(mtx, i))
  end

  db.set_words_loaded(id_model)

  return model, mtx, word_numbers, word_names

end

local function get_words (db, name)

  local model = db.get_words_model_by_name(name)

  if not model then
    return
  end

  print("Loading words from database")

  local word_matrix = mcreate(0, model.dimensions)
  local word_numbers = {}
  local word_names = {}

  for word in db.get_words(model.id) do
    mextend(word_matrix, word.embedding)
    word_names[#word_names + 1] = word.name
    err.assert(#word_names == word.id, "Word order/id mismatch")
    word_numbers[word.name] = word.id
  end

  print("Loaded:", mrows(word_matrix))

  return model, word_matrix, word_numbers, word_names

end

local function load_words (db, args)
  return db.db.transaction(function ()
    local model = db.get_words_model_by_name(args.name)
    if not model or model.loaded ~= 1 then
      return load_words_from_file(db, model, args)
    else
      err.error("Words already loaded")
    end
  end)
end

return {
  load_words = load_words,
  get_words = get_words,
}
