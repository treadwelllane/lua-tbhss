local err = require("santoku.error")

local mtx = require("santoku.matrix")
local mcreate = mtx.create
local mmultiply = mtx.multiply
local mget = mtx.get
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

  local word_matrix = mcreate(0, 0)

  for line in flines(args.file) do

    local chunks = smatches(line, "%S+")
    local word = ssub(chunks())

    icollect(imap(snumber, chunks), floats, 1)

    if #word_names > 0 and #floats ~= n_dims then
      err.error("Wrong number of dimensions for embedding", #word_names, #floats)
    elseif #word_names == 0 then
      mreshape(word_matrix, #word_names, #floats)
      n_dims = #floats
    end

    word_names[#word_names + 1] = word
    word_numbers[word] = #word_names
    mreshape(word_matrix, mrows(word_matrix) + 1, n_dims)
    mset(word_matrix, #word_names, floats)

    if mrows(word_matrix) % 5000 == 0 then
      print("Loaded:", mrows(word_matrix))
    end

  end

  print("Loaded All:", mrows(word_matrix))
  print("Dimensions:", mcolumns(word_matrix))

  local id_model = model and model.id

  print("Persisting words")

  if not id_model then
    id_model = db.add_words_model(args.name, mrows(word_matrix), mcolumns(word_matrix), mtx.raw(word_matrix))
    model = db.get_words_model_by_id(id_model)
  end

  print("Persisting word names")

  for i = 1, mrows(word_matrix) do
    db.add_word(i, id_model, word_names[i])
  end

  db.set_words_loaded(id_model)

  print("Done")

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
}
