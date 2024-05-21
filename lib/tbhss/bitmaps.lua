local serialize = require("santoku.serialize") -- luacheck: ignore
local bitmap = require("santoku.bitmap")
local rand = require("santoku.random")
local num = require("santoku.num")
local mtx = require("santoku.matrix")
local err = require("santoku.error")
local tm = require("santoku.tsetlin")
local arr = require("santoku.array")
local str = require("santoku.string")
local booleanizer = require("santoku.tsetlin.booleanizer")
local it = require("santoku.iter")

local function create_bitmaps_clustered (db, args)
  return db.db.transaction(function ()

    print("Creating bitmaps")

    local clusters_model = db.get_clusters_model_by_name(args.clusters)

    if not clusters_model or clusters_model.clustered ~= 1 then
      err.error("Words not clustered")
    end

    local bitmaps_model = db.get_bitmaps_model_by_name(args.name)

    if not bitmaps_model then
      local id = db.add_bitmaps_model(args.name, clusters_model.id_words_model, clusters_model.id, {
        clusters = args.clusters,
        min_similarity = args.min_similarity,
        min_set = args.min_set,
        max_set = args.max_set,
      })
      bitmaps_model = db.get_bitmaps_model_by_id(id)
      err.assert(bitmaps_model, "This is a bug! Bitmaps model not created")
    end

    if bitmaps_model.created == 1 then
      err.error("Bitmaps already created")
    end

    for id_words = 1, db.get_total_words(clusters_model.id_words_model) do
      local bm = bitmap.create()
      for c in db.get_nearest_clusters_by_id(
        clusters_model.id, id_words,
        args.min_set, args.max_set, args.min_similarity)
      do
        bitmap.set(bm, c.id)
      end
      db.add_bitmap(bitmaps_model.id, id_words, bitmap.raw(bm, clusters_model.clusters))
    end

    db.set_bitmaps_created(bitmaps_model.id)
    print("Persisted bitmaps")

  end)
end

-- Doesn't the TM booleanizer module provide something for this?
local function booleanize_vector (vector, words_model, thresholds, bits)
  for j = 1, words_model.dimensions do
    for k = 1, #thresholds do
      local t = thresholds[k]
      if mtx.get(vector, 1, j) <= t.value then
        bits[(j - 1) * #thresholds * 2 + t.bit] = true
        bits[(j - 1) * #thresholds * 2 + t.bit + #thresholds] = false
      else
        bits[(j - 1) * #thresholds * 2 + t.bit] = false
        bits[(j - 1) * #thresholds * 2 + t.bit + #thresholds] = true
      end
    end
  end
  return bitmap.create(bits, 2 * #thresholds * words_model.dimensions)
end

local function get_autoencoder_data (db, args, words_model)

  local problems = {}
  local bits = {}
  local observations = {}

  local ms = mtx.create(db.get_word_embeddings(words_model.id), words_model.dimensions)

  print("Vectors", mtx.rows(ms))

  for i = 1, mtx.rows(ms) do
    for j = 1, words_model.dimensions do
      local v = mtx.get(ms, i, j)
      observations[v] = true
    end
  end

  local thresholds = booleanizer.thresholds(observations, args.threshold_levels)

  local m0 = mtx.create(1, words_model.dimensions)
  for i = 1, mtx.rows(ms) do
    mtx.copy(m0, ms, i, i, 1)
    local b = booleanize_vector(m0, words_model, thresholds, bits)
    arr.push(problems, b)
  end

  return problems, #thresholds * words_model.dimensions, thresholds, ms

end

local function get_word_triplets (db, words_model, max, sim_neg, sim_pos)
  local triplets = {}
  local ms = mtx.create(db.get_word_embeddings(words_model.id), words_model.dimensions)
  local ds = mtx.create(db.get_word_similarities(words_model.id), words_model.total)
  for i = 1, words_model.total do
    local i_n, i_p
    for _ = 1, words_model.total do
      local j = rand.fast_random() % words_model.total + 1
      if i ~= j then
        local sim = mtx.get(ds, i, j)
        if not i_n and sim < sim_neg then
          i_n = j
        end
        if not i_p and sim > sim_pos then
          i_p = j
        end
        if i_n and i_p then
          local m_a = mtx.create(1, words_model.dimensions)
          local m_n = mtx.create(1, words_model.dimensions)
          local m_p = mtx.create(1, words_model.dimensions)
          mtx.copy(m_a, ms, i, i, 1)
          mtx.copy(m_n, ms, i_n, i_n, 1)
          mtx.copy(m_p, ms, i_p, i_p, 1)
          arr.push(triplets, {
            anchor = m_a,
            negative = m_n,
            positive = m_p,
          })
          if max and #triplets >= max then
            return triplets, ms
          end
          break
        end
      end
    end
  end
  return triplets, ms
end

local function get_encoder_data (db, args, words_model)

  local triplets, word_matrix = get_word_triplets(db, words_model, args.max_records, args.similarity_negative, args.similarity_positive)

  local observations = {}

  for i = 1, #triplets do
    local t = triplets[i]
    for j = 1, words_model.dimensions do
      observations[mtx.get(t.anchor, 1, j)] = true
      observations[mtx.get(t.negative, 1, j)] = true
      observations[mtx.get(t.positive, 1, j)] = true
    end
  end

  local thresholds = booleanizer.thresholds(observations, args.threshold_levels)

  local bits = {}
  local as, ns, ps = {}, {}, {}

  for i = 1, #triplets do
    local t = triplets[i]
    t.anchor = booleanize_vector(t.anchor, words_model, thresholds, bits)
    t.negative = booleanize_vector(t.negative, words_model, thresholds, bits)
    t.positive = booleanize_vector(t.positive, words_model, thresholds, bits)
  end

  return {
    triplets = triplets,
    word_matrix = word_matrix,
    thresholds = thresholds,
    n_features = #thresholds * words_model.dimensions, thresholds,
  }

end

local function get_thresholded_data (db, args, words_model)

  local observations = {}

  local ms = mtx.create(db.get_word_embeddings(words_model.id), words_model.dimensions)

  print("Vectors", mtx.rows(ms))

  for i = 1, mtx.rows(ms) do
    for j = 1, words_model.dimensions do
      local v = mtx.get(ms, i, j)
      observations[v] = true
    end
  end

  local thresholds = booleanizer.thresholds(observations, args.threshold_levels)

  return {
    thresholds = thresholds,
    word_matrix = ms,
    bits = #thresholds * words_model.dimensions * 2
  }

end

local function create_bitmaps_auto_encoded (db, args)
  return db.db.transaction(function ()

    local words_model = db.get_words_model_by_name(args.words)

    if not words_model or words_model.loaded ~= 1 then
      err.error("Words model not loaded")
    end

    local bitmaps_model = db.get_bitmaps_model_by_name(args.name)

    if not bitmaps_model then
      local id = db.add_bitmaps_model(args.name, words_model.id, nil, args)
      bitmaps_model = db.get_bitmaps_model_by_id(id)
      err.assert(bitmaps_model, "This is a bug! Bitmaps model not created")
    end

    if bitmaps_model.created == 1 then
      err.error("Bitmaps already created")
    end

    print("Training the auto encoder")

    local data, n_features, thresholds, word_matrix = get_autoencoder_data(db, args, words_model)

    print("Shuffling")
    rand.seed()
    arr.shuffle(data)

    print("Splitting & packing")
    local n_train = num.floor(#data * args.train_test_ratio)
    local n_test = #data - n_train
    local train = bitmap.raw_matrix(data, n_features * 2, 1, n_train)
    local test = bitmap.raw_matrix(data, n_features * 2, n_train + 1, #data)

    print("Input Features", n_features * 2)
    print("Encoded Features", args.encoded_bits)
    print("Train", n_train)
    print("Test", n_test)

    local t = tm.auto_encoder(args.encoded_bits, n_features, args.clauses, args.state_bits, args.threshold, args.boost_true_positive)

    print("Training")
    for epoch = 1, args.epochs do

      local start = os.time()
      tm.train(t, n_train, train, args.specificity, args.drop_clause, args.scale_loss, args.scale_loss_min, args.scale_loss_max)
      local duration = os.time() - start

      if epoch == args.epochs or epoch % args.evaluate_every == 0 then
        local test_score = tm.evaluate(t, n_test, test)
        local train_score = tm.evaluate(t, n_train, train)
        str.printf("Epoch\t%-4d\tTime\t%d\tTest\t%4.2f\tTrain\t%4.2f\n", epoch, duration, test_score, train_score)
      else
        str.printf("Epoch\t%-4d\tTime\t%d\n", epoch, duration)
      end

    end

    print("Encoding bitmaps")

    local bits = {}
    local m0 = mtx.create(1, words_model.dimensions)
    for i = 1, mtx.rows(word_matrix) do
      mtx.copy(m0, word_matrix, i, i, 1)
      local input = booleanize_vector(m0, words_model, thresholds, bits)
      local output = tm.predict(t, bitmap.raw(input, n_features * 2))
      db.add_bitmap(bitmaps_model.id, i, output)
    end

    db.set_bitmaps_created(bitmaps_model.id)
    print("Persisted bitmaps")

  end)
end

local function split_encoder_data (dataset, s, e)
  local data = {}
  for i = s, e do
    local t = dataset.triplets[i]
    arr.push(data, t.anchor, t.negative, t.positive)
  end
  return bitmap.raw_matrix(data, dataset.n_features * 2)
end

local function create_bitmaps_encoded (db, args)
  return db.db.transaction(function ()

    local words_model = db.get_words_model_by_name(args.words)

    if not words_model or words_model.loaded ~= 1 then
      err.error("Words model not loaded")
    end

    local bitmaps_model = db.get_bitmaps_model_by_name(args.name)

    if not bitmaps_model then
      local id = db.add_bitmaps_model(args.name, words_model.id, nil, args)
      bitmaps_model = db.get_bitmaps_model_by_id(id)
      err.assert(bitmaps_model, "This is a bug! Bitmaps model not created")
    end

    if bitmaps_model.created == 1 then
      err.error("Bitmaps already created")
    end

    print("Training the encoder")

    local dataset = get_encoder_data(db, args, words_model)

    print("Splitting & packing")
    local n_train = num.floor(#dataset.triplets * args.train_test_ratio)
    local n_test = #dataset.triplets - n_train
    local train_data = split_encoder_data(dataset, 1, n_train)
    local test_data = split_encoder_data(dataset, n_train + 1, n_train + n_test)

    print("Input Features", dataset.n_features * 2)
    print("Encoded Features", args.encoded_bits)
    print("Train", n_train)
    print("Test", n_test)

    local t = tm.encoder(args.encoded_bits, dataset.n_features, args.clauses, args.state_bits, args.threshold, args.boost_true_positive)

    print("Training")
    for epoch = 1, args.epochs do

      local start = os.time()
      tm.train(t, n_train, train_data,
        args.specificity, args.drop_clause, args.margin,
        args.scale_loss, args.scale_loss_min, args.scale_loss_max)
      local duration = os.time() - start

      if epoch == args.max_epochs or epoch % args.evaluate_every == 0 then
        local train_score = tm.evaluate(t, n_train, train_data)
        local test_score = tm.evaluate(t, n_test, test_data)
        str.printf("Epoch %-4d  Time %d  Test %4.2f  Train %4.2f\n",
          epoch, duration, test_score, train_score)
      else
        str.printf("Epoch %-4d  Time %d\n",
          epoch, duration)
      end

    end

    print("Encoding bitmaps")

    local bits = {}
    local m0 = mtx.create(1, words_model.dimensions)
    for i = 1, words_model.total do
      mtx.copy(m0, dataset.word_matrix, i, i, 1)
      local input = booleanize_vector(m0, words_model, dataset.thresholds, bits)
      local output = tm.predict(t, bitmap.raw(input, dataset.n_features * 2))
      db.add_bitmap(bitmaps_model.id, i, output)
    end

    db.set_bitmaps_created(bitmaps_model.id)
    print("Persisted bitmaps")

  end)
end

local function create_bitmaps_thresholded (db, args)
  return db.db.transaction(function ()

    local words_model = db.get_words_model_by_name(args.words)

    if not words_model or words_model.loaded ~= 1 then
      err.error("Words model not loaded")
    end

    print("Getting thresholds")

    local dataset = get_thresholded_data(db, args, words_model)

    local bitmaps_model = db.get_bitmaps_model_by_name(args.name)

    if not bitmaps_model then
      args.encoded_bits = dataset.bits
      local id = db.add_bitmaps_model(args.name, words_model.id, nil, args)
      bitmaps_model = db.get_bitmaps_model_by_id(id)
      err.assert(bitmaps_model, "This is a bug! Bitmaps model not created")
    end

    print("Encoding bitmaps")

    local bits = {}
    local m0 = mtx.create(1, words_model.dimensions)
    for i = 1, words_model.total do
      mtx.copy(m0, dataset.word_matrix, i, i, 1)
      local input = booleanize_vector(m0, words_model, dataset.thresholds, bits)
      db.add_bitmap(bitmaps_model.id, i, bitmap.raw(input, dataset.bits))
    end

    db.set_bitmaps_created(bitmaps_model.id)

    print("Persisted bitmaps")

  end)

end

return {
  create_bitmaps_clustered = create_bitmaps_clustered,
  create_bitmaps_auto_encoded = create_bitmaps_auto_encoded,
  create_bitmaps_encoded = create_bitmaps_encoded,
  create_bitmaps_thresholded = create_bitmaps_thresholded,
}
