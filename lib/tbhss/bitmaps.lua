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

  local vectors = db.get_word_vectors(words_model.id)

  if args.max_records then
    vectors = it.take(args.max_records, vectors)
  end

  vectors = it.collect(vectors)

  for i = 1, #vectors do
    local vector = vectors[i]
    for j = 1, words_model.dimensions do
      local v = mtx.get(vector, 1, j)
      observations[v] = true
    end
  end

  local thresholds = booleanizer.thresholds(observations, args.threshold_levels)

  for i = 1, #vectors do
    local b = booleanize_vector(vectors[i], words_model, thresholds, bits)
    arr.push(problems, b)
  end

  return problems, #thresholds * words_model.dimensions, thresholds

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

    print("Training the auto encoder")

    local data, n_features, thresholds = get_autoencoder_data(db, args, words_model)

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
    for word in db.get_words(words_model.id) do
      local input = booleanize_vector(mtx.create(word.embedding, word.dimensions), words_model, thresholds, bits)
      local output = tm.predict(t, bitmap.raw(input, n_features * 2))
      db.add_bitmap(bitmaps_model.id, word.id, output)
    end

    db.set_bitmaps_created(bitmaps_model.id)
    print("Persisted bitmaps")

  end)
end

return {
  create_bitmaps_clustered = create_bitmaps_clustered,
  create_bitmaps_encoded = create_bitmaps_encoded,
}
