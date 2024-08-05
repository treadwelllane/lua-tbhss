local err = require("santoku.error")
local it = require("santoku.iter")
local str = require("santoku.string")
local arr = require("santoku.array")
local fs = require("santoku.fs")
local sys = require("santoku.system")
local init_db = require("tbhss.db")
local util = require("tbhss.util")
local clusters = require("tbhss.clusters")
local hash = require("tbhss.hash")

local function tokenize_words (db, id_model, args, words)
  local positions, similarities = {}, {}
  if args.id_parent_model then
    local n = 0
    local new_words = {}
    for i = 1, #words do
      local w = db.get_sentence_word_id(args.id_parent_model, words[i])
      if w then
        n = n + 1
        new_words[n] = w
        positions[n] = n
        similarities[n] = 1
      end
    end
    return new_words, positions, similarities
  else
    for i = 1, #words do
      words[i] = db.add_sentence_word(id_model, words[i])
      positions[i] = i
      similarities[i] = 1
    end
    return words, positions, similarities
  end
end

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
    local a_positions, b_positions
    local a_similarities, b_similarities
    a = arr.concat(a_words, " ")
    b = arr.concat(b_words, " ")
    a_words, a_positions, a_similarities = tokenize_words(db, id_model, args, a_words)
    b_words, b_positions, b_similarities = tokenize_words(db, id_model, args, b_words)
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
    db.set_sentence_tokens(id_model, a_id, a_words, a_positions, a_similarities, #a_words, true)
    db.set_sentence_tokens(id_model, b_id, b_words, b_positions, b_similarities, #b_words, true)
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
    min = args.clusters.min_set,
    max = args.clusters.max_set,
    cutoff = args.clusters.min_similarity
  })
  args.clusters.name = clusters_model.name
  args.id_clusters_model = clusters_model.id
  db.set_sentences_args(args.id_sentences_model, args)
end

local function create_model (db, model, args)
  local id_model = model and model.id
  if not id_model then
    id_model = db.add_sentences_model(args.name, args)
  end
  args.id_sentences_model = id_model
  return id_model
end

local function get_expanded_tokens (model, tokens0, nearest)
  local tokens = {}
  local positions = {}
  local similarities = {}
  local p = 1
  for i = 1, #tokens0 do
    local t = tokens0[i]
    if not model.args.clusters or model.args.clusters.include_raw then
      arr.push(tokens, t)
      arr.push(positions, p)
      arr.push(similarities, 1)
      p = p + 1
    end
    if model.args.clusters then
      local ns = nearest[t]
      if ns then
        for j = 1, #ns do
          local n = ns[j]
          arr.push(tokens, -n.cluster)
          arr.push(positions, p)
          arr.push(similarities, n.similarity)
        end
        p = p + 1
      end
    end
  end
  return tokens, positions, similarities, p - 1
end

local function expand_tokens (db, id_model, args)
  print("Expanding tokens")
  local n = 0
  local jobs = args.jobs or sys.get_num_cores()
  local sentences = db.get_sentences(id_model)
  local model = db.get_sentences_model_by_id(args.id_parent_model or id_model)
  local nearest = model.args.clusters and db.get_nearest_clusters(model.args.id_clusters_model)
  local chunk_size = math.floor(#sentences / jobs)
  for _ in sys.sh({
    jobs = jobs, fn = function (job)
      db = init_db(db.file, true)
      local first_id = (job - 1) * chunk_size + 1
      local last_id = job == jobs
        and #sentences
        or (first_id + chunk_size - 1)
      for s_id = first_id, last_id do
        local s = sentences[s_id]
        local tokens, positions, similarities, length = get_expanded_tokens(model, s.tokens, nearest)
        db.set_sentence_tokens(id_model, s.id, tokens, positions, similarities, length)
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

local function update_tfdf (db, id_model, args)
  print("Updating TF and DF")
  db.set_sentence_tf(id_model)
  if not args.id_parent_model then
    db.set_sentence_df(id_model)
  end
end

local function score_tokens (tokens, tfs, dfs, saturation, length_normalization, average_doc_length, total_docs)
  local scores = {}
  local log = math.log
  for i = 1, #tokens do
    local t = tokens[i]
    if not scores[t] then
      local tf = tfs[t] or 0
      local df = dfs[t] or 0
      local tf =
        tf * (saturation + 1) /
        (tf + saturation *
          (1 - length_normalization + length_normalization *
            (#tokens / average_doc_length)))
      local idf = log((total_docs - df + 0.5) / (df + 0.5) + 1)
      scores[t] = tf * idf
    end
  end
  return scores
end

local function create_fingerprints (db, id_model, args)

  print("Creating fingerprints")
  local n = 0
  local jobs = args.jobs or sys.get_num_cores()
  local sentences = db.get_sentences(id_model)
  local model = db.get_sentences_model_by_id(args.id_parent_model or id_model)
  local chunk_size = math.floor(#sentences / jobs)
  local average_doc_length = db.get_average_doc_length(model.id)
  local total_docs = db.get_total_docs(model.id)
  local dfs = db.get_dfs(model.id)
  local tfs = db.get_tfs(id_model)
  for _ in sys.sh({
    jobs = jobs, fn = function (job)
      db = init_db(db.file, true)
      local first_id = (job - 1) * chunk_size + 1
      local last_id = job == jobs
        and #sentences
        or (first_id + chunk_size - 1)
      for s_id = first_id, last_id do
        local sentence = sentences[s_id]
        local scores = score_tokens(
          sentence.tokens,
          tfs[sentence.id],
          dfs,
          model.args.saturation,
          model.args.length_normalization,
          average_doc_length,
          total_docs)
        sentence.fingerprint = hash.simhash(
          sentence.tokens,
          sentence.positions,
          sentence.similarities,
          scores,
          model.args.segments,
          model.args.dimensions,
          model.args.buckets)
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

local function load_sentences_from_file (db, model, args, is_train)

  print("Loading sentences from file:", args.file)

  local id_model

  if is_train then

    id_model = create_model(db, model, args)

    db.db.transaction(function ()
      read_sentences(db, id_model, args)
    end)

    db.db.transaction(function ()
      create_clusters(db, args)
    end)

    expand_tokens(db, id_model, args)

    db.db.transaction(function ()
      update_tfdf(db, id_model, args)
    end)

    create_fingerprints(db, id_model, args)

  else

    local parent_model = db.get_sentences_model_by_name(args.model)

    if not (parent_model and parent_model.loaded == 1) then
      err.error("Parent sentences model not loaded")
    end

    args.id_parent_model = parent_model.id

    id_model = create_model(db, model, args)

    db.db.transaction(function ()
      read_sentences(db, id_model, args)
    end)

    expand_tokens(db, id_model, args)

    db.db.transaction(function ()
      update_tfdf(db, id_model, args)
    end)

    create_fingerprints(db, id_model, args)

  end

  db.set_sentences_loaded(id_model)

end

local function load_sentences (db, args, is_train)
  local model = db.get_sentences_model_by_name(args.name)
  if not model or model.loaded ~= 1 then
    return load_sentences_from_file(db, model, args, is_train)
  else
    err.error("Sentences already loaded")
  end
end

local function load_train_sentences (db, args)
  return load_sentences(db, args, true)
end

local function load_test_sentences (db, args)
  return load_sentences(db, args, false)
end

local function modeler ()
  err.error("unimplemented: modeler")
end

return {
  load_train_sentences = load_train_sentences,
  load_test_sentences = load_test_sentences,
  modeler = modeler
}
