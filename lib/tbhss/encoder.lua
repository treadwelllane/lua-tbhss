local serialize = require("santoku.serialize") -- luacheck: ignore
local test = require("santoku.test")
local tm = require("santoku.tsetlin")
local booleanizer = require("santoku.tsetlin.booleanizer")
local bm = require("santoku.bitmap")
local mtx = require("santoku.matrix")
local it = require("santoku.iter")
local fs = require("santoku.fs")
local str = require("santoku.string")
local arr = require("santoku.array")
local rand = require("santoku.random")
local num = require("santoku.num")
local err = require("santoku.error")

local glove = require("tbhss.glove")

local function get_dataset (db, embeddings_model, args)

  local observations = {}
  local embeddings = {}

  for e in db.get_embeddings(embeddings_model.id) do
    local embedding = mtx.create(e.embedding, embeddings_model.dimensions)
    arr.push(embeddings, embedding)
    for i = 1, mtx.columns(embedding) do
      observations[mtx.get(embedding, 1, i)] = true
    end
  end

  local thresholds = booleanizer.thresholds(observations, args.threshold_levels)

  local as = {}
  local bs = {}
  local scores = {}
  local bits = {}

  for i = 1, #embeddings do
    local embedding = embeddings[i]
    for j = 1, mtx.columns(embedding) do
      for k = 1, #thresholds do
        local t = thresholds[k]
        local v = mtx.get(embedding, 1, j)
        if v <= t.value then
          bits[(j - 1) * #thresholds * 2 + t.bit] = true
          bits[(j - 1) * #thresholds * 2 + t.bit + #thresholds] = false
        else
          bits[(j - 1) * #thresholds * 2 + t.bit] = false
          bits[(j - 1) * #thresholds * 2 + t.bit + #thresholds] = true
        end
      end
    end
    arr.push(as, bm.create(bits, 2 * #thresholds * embeddings_model.dimensions))
  end

  for i = 1, #as do
    local i0 = rand.fast_random() % #as + 1
    bs[i] = as[i0]
    scores[i] = mtx.dot(embeddings[i], embeddings[i0])
  end

  return {
    as = as,
    bs = bs,
    scores = scores,
    n_features = #thresholds * embeddings_model.dimensions,
    n_pairs = #as,
  }

end

local function split_dataset (dataset, s, e)
  local as = bm.raw_matrix(dataset.as, dataset.n_features * 2, s, e)
  local bs = bm.raw_matrix(dataset.bs, dataset.n_features * 2, s, e)
  local scores = mtx.raw(mtx.create(dataset.scores, s, e))
  return as, bs, scores
end

local function create_encoder (db, args)
  return db.db.transaction(function ()

    local embeddings_model = db.get_embeddings_model_by_name(args.embeddings)

    if not embeddings_model or embeddings_model.loaded ~= 1 then
      err.error("Embeddings model not loaded")
    end

    local encoder_model = db.get_encoder_model_by_name(args.name)

    if not encoder_model then
      local id = db.add_encoder_model(args.name, embeddings_model.id, args)
      encoder_model = db.get_encoder_model_by_id(id)
      assert(encoder_model, "this is a bug! encoder model not created")
    end

    if encoder_model.created == 1 then
      err.error("Encoder already created")
    end

    print("Reading data")
    local dataset = get_dataset(db, embeddings_model, args)

    print("Shuffling")
    rand.seed()
    arr.shuffle(dataset.as, dataset.bs, dataset.scores)

    print("Splitting & packing")
    local n_train = num.floor(dataset.n_pairs * args.train_test_ratio)
    local n_test = dataset.n_pairs - n_train
    local train_as, train_bs, train_scores = split_dataset(dataset, 1, n_train)
    local test_as, test_bs, test_scores = split_dataset(dataset, n_train + 1, n_train + n_test)

    print("Input Features", dataset.n_features * 2)
    print("Encoded Features", args.bits)
    print("Train", n_train)
    print("Test", n_test)

    local t = tm.encoder(args.bits, dataset.n_features, args.clauses, args.state_bits, args.threshold, args.boost_true_positive)

    print("Training")
    for epoch = 1, args.epochs do

      local start = os.clock()
      tm.train(t, n_train, train_as, train_bs, train_scores, args.specificity, args.update_probability, args.drop_clause)
      local duration = os.clock() - start

      if epoch == args.epochs or epoch % args.evaluate_every == 0 then
        local test_score, nh, nl = tm.evaluate(t, n_test, test_as, test_bs, test_scores)
        local train_score = tm.evaluate(t, n_train, train_as, train_bs, train_scores)
        str.printf("Epoch %-4d  Time %f  Test %4.2f  Train %4.2f  High %d  Low %d\n",
          epoch, duration, test_score, train_score, nh, nl)
      else
        str.printf("Epoch %-4d  Time %f\n",
          epoch, duration)
      end

    end

    -- TODO: write directly to sqlite without temporary file
    local fp = fs.tmpname()
    tm.persist(t, fp)
    db.set_encoder_created(encoder_model.id, fs.readfile(fp))
    fs.rm(fp)

  end)
end

return {
  create_encoder = create_encoder
}
