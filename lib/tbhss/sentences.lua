local err = require("santoku.error")
local bm = require("santoku.bitmap")
local it = require("santoku.iter")
local str = require("santoku.string")
local arr = require("santoku.array")
local fs = require("santoku.fs")
local sys = require("santoku.system")
local init_db = require("tbhss.db")
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
    local a_positions = {}
    local b_positions = {}
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
      a_positions[i] = i
    end
    db.set_sentence_tokens(id_model, a_id, a_words, true)
    db.set_sentence_token_positions(id_model, a_id, a_positions, true)
    for i = 1, #b_words do
      b_words[i] = db.add_sentence_word(id_model, b_words[i])
      b_positions[i] = i
    end
    db.set_sentence_tokens(id_model, b_id, b_words, true)
    db.set_sentence_token_positions(id_model, b_id, b_positions, true)
    db.add_sentence_pair(id_model, a_id, b_id, label)
    if args.max_records and n >= args.max_records then
      break
    end
  end
  print("Loaded:", n)
end

local function create_clusters (db, args)
  if not args.clusters then
    return
  end
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

local function get_expanded_tokens (db, id_model, args, tokens0, cache)
  local tokens = {}
  local positions = {}
  for i = 1, #tokens0 do
    local t = tokens0[i]
    if not args.clusters or args.clusters.include_raw then
      arr.push(tokens, t)
      arr.push(positions, i)
    end
    if args.clusters then
      local nearest = get_cached_nearest_clusters(db, id_model, t,
        args.clusters.min_set,
        args.clusters.max_set,
        args.clusters.min_similarity,
        cache)
      arr.extend(tokens, nearest)
      for _ = 1, #nearest do
        arr.push(positions, i)
      end
    end
  end
  return tokens, positions
end

local function expand_tokens (db, id_model, args)
  print("Expanding tokens")
  local n = 0
  local jobs = args.jobs or sys.get_num_cores()
  local sentences = it.collect(db.get_sentences(id_model))
  local chunk_size = math.floor(#sentences / jobs)
  for _ in sys.sh({
    jobs = jobs, fn = function (job)
      local cache = {}
      db = init_db(db.file, true)
      local first_id = (job - 1) * chunk_size + 1
      local last_id = job == jobs
        and #sentences
        or (first_id + chunk_size - 1)
      for s_id = first_id, last_id do
        local s = sentences[s_id]
        local tokens, positions = get_expanded_tokens(db, id_model, args, s.tokens, cache)
        db.set_sentence_tokens(id_model, s.id, tokens)
        db.set_sentence_token_positions(id_model, s.id, positions)
        print()
      end
    end
  }) do
    n = n + 1
    if n % 50 == 0 then
      print("Expanded", n)
    end
  end
  print("Expanded", n)
end

local function update_fts (db, id_model)
  print("Updating TF and DF")
  db.set_sentence_tf(id_model)
  db.set_sentence_df(id_model)
end

local function create_fingerprints (db, id_model, args)

  print("Creating fingerprints")
  local n = 0
  local jobs = args.jobs or sys.get_num_cores()
  local sentences = it.collect(db.get_sentences(id_model))
  local chunk_size = math.floor(#sentences / jobs)
  for _ in sys.sh({
    jobs = jobs, fn = function (job)
      db = init_db(db.file, true)
      local first_id = (job - 1) * chunk_size + 1
      local last_id = job == jobs
        and #sentences
        or (first_id + chunk_size - 1)
      for s_id = first_id, last_id do
        local sentence = sentences[s_id]
        local scores = db.get_token_scores(id_model, sentence.id, args.saturation, args.length_normalization)
        sentence.fingerprint = hash.simhash(
          sentence.tokens,
          sentence.positions,
          scores,
          args.segments,
          args.dimensions,
          args.buckets)
        db.add_sentence_fingerprint(id_model, sentence.id, sentence.fingerprint)
        print(sentence.id)
      end
    end
  }) do
    n = n + 1
    if n % 50 == 0 then
      print("Created", n)
    end
  end
  print("Created", n)

end

local function load_sentences_from_file (db, model, args)

  print("Loading sentences from file:", args.file)

  local id_model = create_model(db, model, args)

  db.db.transaction(function ()
    read_sentences(db, id_model, args)
  end)

  db.db.transaction(function ()
    create_clusters(db, args)
  end)

  expand_tokens(db, id_model, args)

  db.db.transaction(function ()
    update_fts(db, id_model, args)
  end)

  create_fingerprints(db, id_model, args)

  db.set_sentences_loaded(id_model)

end

local function load_sentences (db, args)
  local model = db.get_sentences_model_by_name(args.name)
  if not model or model.loaded ~= 1 then
    return load_sentences_from_file(db, model, args)
  else
    err.error("Sentences already loaded")
  end
end

local function modeler ()
  err.error("unimplemented: modeler")
end

return {
  load_sentences = load_sentences,
  modeler = modeler
}
