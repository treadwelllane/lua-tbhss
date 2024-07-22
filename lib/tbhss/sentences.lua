local err = require("santoku.error")
local it = require("santoku.iter")
local str = require("santoku.string")
local arr = require("santoku.array")
local fs = require("santoku.fs")
local util = require("tbhss.util")
local clusters = require("tbhss.clusters")
local hash = require("tbhss.hash")

local function read_sentences (db, id_model, args)
  local n = 0
  for line in it.drop(1, fs.lines(args.file)) do
    local chunks = str.splits(line, "\t")
    local label = str.sub(chunks())
    chunks = it.drop(4, chunks)
    local a = str.sub(chunks())
    local b = str.sub(chunks())
    local a_words = util.split(a)
    local b_words = util.split(b)
    a = arr.concat(a_words, " ")
    b = arr.concat(b_words, " ")
    local a_id = db.get_sentence_id(id_model, a)
    if not a_id then
      n = n + 1
      a_id = n
      db.add_sentence(a_id, id_model, a)
    end
    local b_id = db.get_sentence_id(id_model, b)
    if not b_id then
      n = n + 1
      b_id = n
      db.add_sentence(b_id, id_model, b)
    end
    for i = 1, #a_words do
      a_words[i] = db.add_sentence_word(id_model, a_words[i])
    end
    db.set_sentence_tokens(id_model, a_id, a_words, true)
    for i = 1, #b_words do
      b_words[i] = db.add_sentence_word(id_model, b_words[i])
    end
    db.set_sentence_tokens(id_model, b_id, b_words, true)
    db.add_sentence_pair(id_model, a_id, b_id, label)
    if args.max_records and n >= args.max_records then
      break
    end
  end
  print("Loaded:", n)
end

local function create_clusters (db, args)
  local clusters_model = clusters.create_clusters(db, {
    name = args.name .. ".clusters",
    words = args.clusters.words,
    filter_words = args.name,
    clusters = args.clusters.clusters,
  })
  args.clusters.name = clusters_model.name
  args.id_clusters_model = clusters_model.id
  db.set_sentences_clusters(args)
end

local function create_model (db, model, args)
  local id_model = model and model.id
  if not id_model then
    id_model = db.add_sentences_model(args)
  end
  args.id_sentences_model = id_model
  return id_model
end

local function get_cached_nearest_clusters (db, id_model, t, min_set, max_set, min_similarity, cache)
  cache = cache or {}
  if not cache[t] then
    cache[t] = {}
    for c in db.get_nearest_clusters(id_model, t, min_set, max_set, min_similarity) do
      arr.push(cache[t], -c.id)
    end
  end
  return cache[t]
end

local function expand_tokens (db, id_model, args)
  print("Expanding tokens")
  local cache = {}
  for s in db.get_sentences(id_model) do
    local tokens = {}
    for i = 1, #s.tokens do
      local t = s.tokens[i]
      arr.push(tokens, t)
      arr.extend(tokens, get_cached_nearest_clusters(db, id_model, t,
        args.clusters.min_set,
        args.clusters.max_set,
        args.clusters.min_similarity,
        cache))
    end
    db.set_sentence_tokens(id_model, s.id, tokens)
  end
end

local function update_fts (db, id_model)
  print("Updating fts5")
  db.create_sentences_fts5(id_model)
  local add_sentence = db.sentence_fts_adder(id_model)
  for s in db.get_sentences(id_model) do
    local data = arr.concat(s.tokens, " ")
    add_sentence(data)
  end
end

local function create_fingerprints (db, id_model, args)
  print("Creating fingerprints")
  local get_scores = db.sentence_token_scores_getter(id_model)
  for sentence in db.get_sentences(id_model) do
    local scores = get_scores(sentence.id, args.saturation, args.length_normalization)
    sentence.fingerprint = hash.fingerprint(
      sentence.tokens, scores,
      args.topic_segments,
      args.position_segments,
      args.position_dimensions,
      args.position_buckets)
    db.add_sentence_fingerprint(id_model, sentence.id, sentence.fingerprint)
  end
end

local function load_sentences_from_file (db, model, args)

  print("Loading sentences from file:", args.file)

  local id_model = create_model(db, model, args)

  read_sentences(db, id_model, args)
  create_clusters(db, args)
  expand_tokens(db, id_model, args)
  update_fts(db, id_model, args)
  create_fingerprints(db, id_model, args)

  db.set_sentences_loaded(id_model)

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

local function modeler (db, m)

  db = util.get_db(db)

  local model =
    (type(m) == "table" and m) or
    (type(m) == "number" and db.get_sentences_model_by_id(m)) or
    (type(m) == "string" and db.get_sentences_model_by_name(m))

  if not model or model.loaded ~= 1 then
    err.error("Sentences not loaded")
  end

  return {
    sentences_model = model,
    model = function (s, tokens_only)
      local words = util.split(s)
      local tokens = {}
      for i = 1, #words do
        local t = db.get_sentence_word(model.id, words[i])
        if t then
          arr.push(tokens, t)
          for c in db.get_nearest_clusters(
              model.id, t,
              model.min_set, model.max_set,
              model.min_similarity) do
            arr.push(tokens, -c.id)
          end
        end
      end
      if tokens_only then
        return tokens
      end
      local scores = db.get_token_scores(
        model.id,
        tokens,
        model.saturation,
        model.length_normalization)
      return hash.fingerprint(
        tokens,
        scores,
        model.topic_segments,
        model.position_segments,
        model.position_dimensions,
        model.position_buckets)
    end
  }

end

return {
  load_sentences = load_sentences,
  modeler = modeler
}
