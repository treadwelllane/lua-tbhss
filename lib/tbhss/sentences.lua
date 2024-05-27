local err = require("santoku.error")
local it = require("santoku.iter")
local str = require("santoku.string")
local fs = require("santoku.fs")
local tbhss = require("tbhss")

local function load_sentences_from_file (db, model, args)

  print("Loading sentences from file:", args.file)

  local id_model = model and model.id

  if not id_model then
    id_model = db.add_sentences_model(args.name)
  end

  local words = {}

  local n = 0
  for line in it.drop(1, fs.lines(args.file)) do
    n = n + 1
    local chunks = str.splits(line, "\t")
    local label = str.sub(chunks())
    chunks = it.drop(4, chunks)
    local a = str.sub(chunks())
    local b = str.sub(chunks())
    db.add_sentence(n, id_model, label, a, b)
    tbhss.split(a, false, words)
    for i = 1, #words do
      db.add_sentence_word(id_model, words[i])
    end
  end

  db.set_sentences_loaded(id_model)

  print("Loaded:", n)

end

local function load_sentences (db, args)
  return db.db.transaction(function ()
    local model = db.get_sentences_model_by_name(args.name)
    if not model or model.loaded ~= 1 then
      return load_sentences_from_file(db, model, args)
    else
      err.error("Sentences already loaded")
    end
  end)
end

return {
  load_sentences = load_sentences,
}
