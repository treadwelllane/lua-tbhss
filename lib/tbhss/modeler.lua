local err = require("santoku.error")
local varg = require("santoku.varg")
local arr = require("santoku.array")
local tm = require("santoku.tsetlin")
local tbl = require("santoku.table")
local str = require("santoku.string")
local fs = require("santoku.fs")
local sys = require("santoku.system")
local init_db = require("tbhss.db")
local clusters = require("tbhss.clusters")
local hash = require("tbhss.hash")
local re = require("re")

local function tokenize_words (db, id_model, args, words, pos)
  local new_pos = {}
  local new_words = {}
  local positions, similarities = {}, {}
  if args.id_parent_model then
    local n = 0
    for i = 1, #words do
      local w = db.get_sentence_word_id(args.id_parent_model, words[i])
      if w then
        n = n + 1
        new_words[n] = w
        positions[n] = n
        similarities[n] = 1
        new_pos[n] = pos and db.get_sentence_pos_id(args.id_parent_model, pos[i]) or -1
      end
    end
    return new_words, new_pos, positions, similarities
  else
    for i = 1, #words do
      new_words[i] = db.add_sentence_word(id_model, words[i])
      new_pos[i] = pos and db.add_sentence_pos(id_model, pos[i]) or -1
      positions[i] = i
      similarities[i] = 1
    end
    return new_words, new_pos, positions, similarities
  end
end

local segment_pat = re.compile([[
  segment <- token / node
  node <- {| "(" {:tag:ident:} {:segments: {| (space {: ({| token |} / segment) :})* |} :} ")" |}
  token <- {:token: ident :}
  ident <- [^%s()]+
  space <- %s+
]])

local function parse_pos (segment, args)
  local tags = {}
  local stack = {}
  local words = {}
  local pos = args.include_pos and {} or nil
  local r = err.assert(re.match(segment, segment_pat), "failed to parse segment", segment)
  err.assert(r.tag == "ROOT", "unexpected root tag")
  err.assert(r.segments, "no root segments found")
  arr.push(stack, r)
  while #stack > 0 do
    local v = stack[#stack]
    if v.token then
      arr.push(words, v.token)
      if pos then
        local ps
        if args.pos_ancestors then
          local idx = #tags - args.pos_ancestors + 1
          idx = idx < 2 and 2 or idx
          ps = { arr.spread(tags, idx) }
        elseif args.dedupe_pos then
          ps = arr.push({}, arr.spread(tags, 2))
          arr.filter(ps, function (p, i)
            return p ~= ps[i + 1]
          end)
        else
          ps = { arr.spread(tags, 2) }
        end
        arr.push(pos, arr.concat(ps, "/"))
      end
      arr.pop(stack)
    elseif v.done then
      arr.pop(stack)
      arr.pop(tags)
    elseif v.tag and not v.idx then
      v.idx = 1
    elseif v.tag and v.segments and v.idx <= #v.segments then
      arr.push(stack, v.segments[v.idx])
      if v.idx == 1 then
        arr.push(tags, v.tag)
      end
      v.idx = v.idx + 1
    else
      v.done = true
    end
  end
  return words, pos
end

local function load_sentence (db, id_model, args, n, sentence)
  local words, pos = parse_pos(sentence, args)
  local positions, similarities
  sentence = arr.concat(words, " ")
  words, pos, positions, similarities = tokenize_words(db, id_model, args, words, pos)
  local id = db.get_sentence_id(id_model, sentence)
  if not id then
    n = n + 1
    id = n
    db.add_sentence(id, id_model, sentence)
  end
  db.set_sentence_tokens(id_model, id, words, pos, positions, similarities, #words, true)
  return id, n
end

local function load_sentence_bytes (db, id_model, args, n, sentence)
  local words = parse_pos(sentence, args)
  sentence = arr.concat(words, " ")
  local words = hash.byte_ids(sentence)
  local positions = {}
  local similarities = {}
  for i = 1, #words do
    positions[i] = i
    similarities[i] = 1
  end
  local id = db.get_sentence_id(id_model, sentence)
  if not id then
    n = n + 1
    id = n
    db.add_sentence(id, id_model, sentence)
  end
  db.set_sentence_tokens(id_model, id, words, nil, positions, similarities, #words, true)
  return id, n
end

local function get_fields (line, type)
  local chunks = str.splits(line, "\t")
  if type == "pairs" then
    local a = str.sub(chunks())
    local b = str.sub(chunks())
    local label = str.sub(chunks())
    return label, a, b
  elseif type == "triplets" then
    local anchor = str.sub(chunks())
    local positive = str.sub(chunks())
    local negative = str.sub(chunks())
    return anchor, positive, negative
  end
end

local tokenization_algorithms = {

  ["bytes"] = function (db, id_model, args, type)
    local n = 0
    local nt = 0
    for line in fs.lines(args.file) do
      if type == "pairs" then
        local label, a, b = get_fields(line, type, args)
        local id_a, id_b
        id_a, n = load_sentence_bytes(db, id_model, args, n, a)
        id_b, n = load_sentence_bytes(db, id_model, args, n, b)
        db.add_sentence_pair(id_model, id_a, id_b, label)
        nt = nt + 1
        if args.max_records and nt >= args.max_records then
          break
        end
      elseif type == "triplets" then
        local anchor, positive, negative = get_fields(line, type, args)
        local id_anchor, id_positive, id_negative
        id_anchor, n = load_sentence_bytes(db, id_model, args, n, anchor)
        id_positive, n = load_sentence_bytes(db, id_model, args, n, positive)
        id_negative, n = load_sentence_bytes(db, id_model, args, n, negative)
        db.add_sentence_triplet(id_model, id_anchor, id_positive, id_negative)
        nt = nt + 1
        if args.max_records and nt >= args.max_records then
          break
        end
      else
        err.error("unexpected", type)
      end
    end
    str.printf("Loaded %d groups and %d sentences\n", nt, n)
  end,

  ["default"] = function (db, id_model, args, type)
    local n = 0
    local nt = 0
    for line in fs.lines(args.file) do
      if type == "pairs" then
        local label, a, b = get_fields(line, type, args)
        local id_a, id_b
        id_a, n = load_sentence(db, id_model, args, n, a)
        id_b, n = load_sentence(db, id_model, args, n, b)
        db.add_sentence_pair(id_model, id_a, id_b, label)
        nt = nt + 1
        if args.max_records and nt >= args.max_records then
          break
        end
      elseif type == "triplets" then
        local anchor, positive, negative = get_fields(line, type, args)
        local id_anchor, id_positive, id_negative
        id_anchor, n = load_sentence(db, id_model, args, n, anchor)
        id_positive, n = load_sentence(db, id_model, args, n, positive)
        id_negative, n = load_sentence(db, id_model, args, n, negative)
        db.add_sentence_triplet(id_model, id_anchor, id_positive, id_negative)
        nt = nt + 1
        if args.max_records and nt >= args.max_records then
          break
        end
      else
        err.error("unexpected type", type)
      end
    end
    str.printf("Loaded %d groups and %d sentences\n", nt, n)
  end

}

local function read_triplets (db, id_model, args)
  local model = err.assert(db.get_triplets_model_by_id(args.id_parent_model or id_model),
    "Model not found", args.id_parent_model or id_model)
  local tokenizer = model.args.tokenizer or { "default" }
  local algo = err.assert(tokenization_algorithms[tokenizer[1]], "tokenizer not found", tokenizer[1])
  return algo(db, id_model, args, "triplets", varg.sel(2, arr.spread(tokenizer)))
end

local function read_pairs (db, id_model, args)
  local model = err.assert(db.get_triplets_model_by_id(args.id_parent_model or id_model),
    "Model not found", args.id_parent_model or id_model)
  local tokenizer = model.args.tokenizer or { "default" }
  local algo = err.assert(tokenization_algorithms[tokenizer[1]], "tokenizer not found", tokenizer[1])
  return algo(db, id_model, args, "pairs", varg.sel(2, arr.spread(tokenizer)))
end

local function create_clusters (db, args)
  if not args.clusters then
    return
  end
  local clusters_model = clusters.create_clusters(db, {
    name = args.name .. ".clusters",
    words = args.clusters[1],
    filter_words = args.name,
    algorithm = { varg.sel(2, arr.spread(args.clusters)) },
  })
  args.id_clusters_model = clusters_model.id
  db.set_triplets_args(args.id_triplets_model, args)
end

local function create_model (db, model, args, type)
  local id_model = model and model.id
  if not id_model then
    id_model = db.add_triplets_model(args.name, type, args)
  end
  args.id_triplets_model = id_model
  return id_model
end

local function get_expanded_tokens (model, tokens0, pos0, nearest)
  local tokens = {}
  local pos = {}
  local positions = {}
  local similarities = {}
  local p = 1
  for i = 1, #tokens0 do
    local t = tokens0[i]
    local ps = pos0[i]
    if not model.args.clusters then
      arr.push(tokens, t)
      arr.push(pos, ps)
      arr.push(positions, p)
      arr.push(similarities, 1)
      p = p + 1
    elseif model.args.clusters then
      local ns = nearest[t]
      if ns then
        for j = 1, #ns do
          local n = ns[j]
          arr.push(tokens, n.cluster)
          arr.push(pos, ps)
          arr.push(positions, p)
          arr.push(similarities, n.similarity)
        end
        p = p + 1
      end
    end
  end
  return tokens, pos, positions, similarities, p - 1
end

local function expand_tokens (db, id_model, args)
  local model = db.get_triplets_model_by_id(args.id_parent_model or id_model)
  if not model or not model.args.clusters then
    return
  end
  print("Expanding tokens")
  local n = 0
  local jobs = args.jobs or sys.get_num_cores()
  local sentences = db.get_sentences(id_model)
  local nearest = model.args.clusters and db.get_nearest_clusters(model.id)
  local chunk_size
  if jobs > #sentences then
    jobs = #sentences
    chunk_size = 1
  else
    chunk_size = math.floor(#sentences / jobs)
  end
  for _ in sys.sh({
    jobs = jobs, fn = function (job)
      db = init_db(db.file, true)
      local first_id = (job - 1) * chunk_size + 1
      local last_id = job == jobs
        and #sentences
        or (first_id + chunk_size - 1)
      for s_id = first_id, last_id do
        local s = sentences[s_id]
        local tokens, pos, positions, similarities, length = get_expanded_tokens(model, s.tokens, s.pos, nearest)
        db.set_sentence_tokens(id_model, s.id, tokens, pos, positions, similarities, length)
        print(s.id)
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

local function bm25_score_tokens (tokens, tfs, dfs, saturation, length_normalization, average_doc_length, total_docs)
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
      scores[t] = tf * idf + 10000 -- to prevent negatives
    end
  end
  return scores
end

local weighting_algorithms = {

  ["bm25"] = function (db, model, _, saturation, length_normalization)
    local average_doc_length = db.get_average_doc_length(model.id)
    local total_docs = db.get_total_docs(model.id)
    local dfs = db.get_dfs(model.id)
    local tfs = db.get_tfs(model.id)
    return function (sentence)
      return bm25_score_tokens(
        sentence.tokens,
        tfs[sentence.id],
        dfs,
        saturation,
        length_normalization,
        average_doc_length,
        total_docs)
    end
  end

}

local fingerprint_algorithms = {

  ["set-of-positions"] = function (db, model, _, wavelength, dimensions, buckets)
    local n_clusters = err.assert(db.get_num_clusters(model.args.id_clusters_model),
      "Missing clusters model", model.args.id_clusters_model)
    if n_clusters < hash.segment_bits then
      n_clusters = hash.segment_bits
    else
      n_clusters = n_clusters + (hash.segment_bits - 1 - ((n_clusters - 1) % hash.segment_bits))
    end
    return function (sentence)
      return hash.set_of_positions(
        sentence.tokens, sentence.positions,
        n_clusters, dimensions, buckets, wavelength)
    end, n_clusters * dimensions * buckets
  end,

  ["set-of-clusters"] = function (db, model)
    local n_clusters
    if model.args.id_clusters_model then
      n_clusters = db.get_num_clusters(model.args.id_clusters_model)
    elseif model.args.tokenizer and model.args.tokenizer[1] == "bytes" then
      n_clusters = 256
    else
      err.error("Can't figure out how what to use for n_clusters")
    end
    if n_clusters < hash.segment_bits then
      n_clusters = hash.segment_bits
    else
      n_clusters = n_clusters + (hash.segment_bits - 1 - ((n_clusters - 1) % hash.segment_bits))
    end
    return function (sentence)
      return hash.set_of_clusters(sentence.tokens, n_clusters)
    end, n_clusters
  end,

  ["hashed-pos"] = function (_, _, _, wavelength, dimensions, segments, buckets)
    return function (sentence)
      return hash.hashed_pos(
        sentence.tokens,
        sentence.positions,
        sentence.pos,
        -- TODO: consider using these
        -- sentence.similarities
        -- scores,
        wavelength,
        dimensions,
        segments,
        buckets)
    end, hash.segment_bits * dimensions * segments
  end,

  ["simhash-simple"] = function (_, _, _, segments)
    return function (sentence, scores)
      return hash.simhash_simple(
        sentence.tokens, sentence.similarities,
        scores, segments)
    end, hash.segment_bits * segments
  end,

  ["simhash-positional"] = function (_, _, _, wavelength, dimensions, buckets)
    return function (sentence, scores)
      return hash.simhash_positional(
        sentence.tokens, sentence.positions, sentence.similarities,
        scores, dimensions, buckets, wavelength)
    end, hash.segment_bits * dimensions
  end

}

local function create_fingerprints (db, id_model, args)

  print("Creating fingerprints")
  local n = 0
  local jobs = args.jobs or sys.get_num_cores()
  local sentences = db.get_sentences(id_model)
  local model = db.get_triplets_model_by_id(args.id_parent_model or id_model)

  local weighting
  local fingerprint, fingerprint_bits

  do
    local wa = tbl.get(weighting_algorithms, tbl.get(model, "args", "weighting", 1))
    if wa then
      weighting = wa(db, model, args,
        varg.sel(2, arr.spread(model.args.weighting)))
    end
    local fa = err.assert(tbl.get(fingerprint_algorithms, tbl.get(model, "args", "fingerprints", 1)),
      "fingerprint algorithm doesn't exist", model.args.fingerprints[1])
    if fa then
      fingerprint, fingerprint_bits =
        fa(db, model, args, varg.sel(2, arr.spread(model.args.fingerprints)))
    end
  end

  local chunk_size

  if jobs > #sentences then
    jobs = #sentences
    chunk_size = 1
  else
    chunk_size = math.floor(#sentences / jobs)
  end

  for _ in sys.sh({
    jobs = jobs, fn = function (job)
      db = init_db(db.file, true)
      local first_id = (job - 1) * chunk_size + 1
      local last_id = job == jobs
        and #sentences
        or (first_id + chunk_size - 1)
      for s_id = first_id, last_id do
        local sentence = sentences[s_id]
        local scores = weighting and weighting(sentence) or nil
        sentence.fingerprint = fingerprint(sentence, scores)
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
  return fingerprint_bits

end

local function load_triplets_from_file (db, model, args, is_train)

  print("Loading triplets from file:", args.file)

  local id_model, bits

  if is_train then

    id_model = create_model(db, model, args, "triplets")

    db.db.transaction(function ()
      read_triplets(db, id_model, args)
    end)

    db.db.transaction(function ()
      create_clusters(db, args)
    end)

    expand_tokens(db, id_model, args)

    db.db.transaction(function ()
      update_tfdf(db, id_model, args)
    end)

    bits = create_fingerprints(db, id_model, args)

  else

    local parent_model = db.get_triplets_model_by_name(args.model)

    if not (parent_model and parent_model.loaded == 1) then
      err.error("Parent triplets model not loaded")
    end

    args.id_parent_model = parent_model.id

    id_model = create_model(db, model, args, "triplets")

    db.db.transaction(function ()
      read_triplets(db, id_model, args)
    end)

    expand_tokens(db, id_model, args)

    db.db.transaction(function ()
      update_tfdf(db, id_model, args)
    end)

    bits = create_fingerprints(db, id_model, args)

  end

  db.set_triplets_loaded(id_model, bits)

end

local function load_triplets (db, args, is_train)
  local model = db.get_triplets_model_by_name(args.name)
  if not model or model.loaded ~= 1 then
    return load_triplets_from_file(db, model, args, is_train)
  else
    err.error("Triplets already loaded")
  end
end

local function load_train_triplets (db, args)
  return load_triplets(db, args, true)
end

local function load_test_triplets (db, args)
  return load_triplets(db, args, false)
end

local function load_compressed_triplets (db, args)
  db.db.transaction(function ()
    local model = db.get_triplets_model_by_name(args.name)
    if model and model.loaded == 1 then
      return err.error("Compressed triplets already loaded")
    end
    local triplets_model = db.get_triplets_model_by_name(args.triplets)
    if not triplets_model or triplets_model.loaded ~= 1 then
      return err.error("Source triplets model not found or not loaded")
    end
    local autoencoder_model = db.get_autoencoder_model_by_name(args.autoencoder)
    if not autoencoder_model then
      return err.error("Auto encoder model not found")
    end
    local autoencoder = db.get_autoencoder(autoencoder_model.id)
    if not autoencoder then
      return err.error("Auto encoder not found")
    end
    args.id_parent_model = triplets_model.id
    local id_model = create_model(db, model, args, "triplets")
    local sentences = db.get_sentence_fingerprints(triplets_model.id, args.max_records)
    -- TODO: multiprocess
    local bits = autoencoder_model.args.encoded_bits
    for i = 1, #sentences do
      local sentence = sentences[i]
      local fingerprint = tm.predict(autoencoder, sentence.fingerprint)
      db.add_sentence_with_fingerprint(sentence.id, id_model, sentence.sentence, fingerprint)
      if i % 500 == 0 then
        print("Compresssed", i)
      end
    end
    print("Compresssed", #sentences)
    db.copy_triplets(triplets_model.id, id_model)
    db.set_triplets_loaded(id_model, bits)
  end)
end

local function load_pairs_from_file (db, model, args, is_train)

  print("Loading pairs from file:", args.file)

  local id_model, bits

  if is_train then

    id_model = create_model(db, model, args, "pairs")

    db.db.transaction(function ()
      read_pairs(db, id_model, args)
    end)

    db.db.transaction(function ()
      create_clusters(db, args)
    end)

    expand_tokens(db, id_model, args)

    db.db.transaction(function ()
      update_tfdf(db, id_model, args)
    end)

    bits = create_fingerprints(db, id_model, args)

  else

    local parent_model = db.get_triplets_model_by_name(args.model)

    if not (parent_model and parent_model.loaded == 1) then
      err.error("Parent pairs model not loaded")
    end

    args.id_parent_model = parent_model.id

    id_model = create_model(db, model, args, "pairs")

    db.db.transaction(function ()
      read_pairs(db, id_model, args)
    end)

    expand_tokens(db, id_model, args)

    db.db.transaction(function ()
      update_tfdf(db, id_model, args)
    end)

    bits = create_fingerprints(db, id_model, args)

  end

  db.set_triplets_loaded(id_model, bits)

end

local function load_pairs (db, args, is_train)
  local model = db.get_triplets_model_by_name(args.name)
  if not model or model.loaded ~= 1 then
    return load_pairs_from_file(db, model, args, is_train)
  else
    err.error("Pairs already loaded")
  end
end

local function load_train_pairs (db, args)
  return load_pairs(db, args, true)
end

local function load_test_pairs (db, args)
  return load_pairs(db, args, false)
end

local function modeler ()
  err.error("unimplemented: modeler")
end

return {
  load_train_pairs = load_train_pairs,
  load_test_pairs = load_test_pairs,
  load_train_triplets = load_train_triplets,
  load_test_triplets = load_test_triplets,
  load_compressed_triplets = load_compressed_triplets,
  modeler = modeler
}
