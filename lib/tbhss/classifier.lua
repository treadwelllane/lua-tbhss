local serialize = require("santoku.serialize") -- luacheck: ignore
local tm = require("santoku.tsetlin")
local fs = require("santoku.fs")
local str = require("santoku.string")
local bm = require("santoku.bitmap")
local mtx = require("santoku.matrix")
local err = require("santoku.error")

local function prep_fingerprint (fingerprint, bits)
  local flipped = bm.copy(fingerprint)
  bm.flip(flipped, 1, bits)
  bm.extend(fingerprint, flipped, bits + 1)
  return fingerprint
end

local function get_dataset (db, pairs_model, max)
  print("Loading sentence pairs")
  local pairs = db.get_sentence_pairs(pairs_model.id, max)
  local fingerprint_bits = pairs_model.bits
  local label_id_next = 1
  local labels = {}
  for i = 1, #pairs do
    local s = pairs[i]
    s.a_fingerprint = bm.from_raw(s.a_fingerprint, fingerprint_bits)
    s.b_fingerprint = bm.from_raw(s.b_fingerprint, fingerprint_bits)
    s.label_id = labels[s.label]
    if not s.label_id then
      s.label_id = label_id_next
      label_id_next = label_id_next + 1
      labels[s.label] = s.label_id
    end
  end
  return {
    pairs = pairs,
    n_labels = label_id_next - 1,
    labels = labels,
    fingerprint_bits = fingerprint_bits,
  }
end

local function pack_dataset (dataset)
  local ss = {}
  local ps = {}
  for i = 1, #dataset.pairs do
    local p = dataset.pairs[i]
    ps[i] = prep_fingerprint(bm.matrix({
      p.a_fingerprint,
      p.b_fingerprint,
    }, dataset.fingerprint_bits), dataset.fingerprint_bits)
    ss[i] = p.label_id - 1 -- TODO: annoying that this is needed to translate to C-land. C should assume 1-indexing.
  end
  ss = mtx.create(ss)
  return
    bm.raw_matrix(ps, dataset.fingerprint_bits * 2 * 2),
    mtx.raw(ss, nil, nil, "u32")
end

local function create_classifier (db, args)

  print("Creating classifier")

  local pairs_model_train = db.get_triplets_model_by_name(args.pairs[1])
  if not pairs_model_train or pairs_model_train.loaded ~= 1 then
    err.error("Train pairs model not loaded", args.pairs[1])
  elseif pairs_model_train.type ~= "pairs" then
    err.error("Not a pairs model")
  end

  local pairs_model_test = db.get_triplets_model_by_name(args.pairs[2])
  if not pairs_model_test or pairs_model_test.loaded ~= 1 then
    err.error("Test pairs model not loaded", args.pairs[2])
  elseif pairs_model_test.type ~= "pairs" then
    err.error("Not a pairs model")
  end
  if pairs_model_test.args.id_parent_model ~= pairs_model_train.id then
    print("WARNING: test pairs model is not related to train model",
      pairs_model_train.name, pairs_model_test.name)
  end

  local classifier_model = db.get_classifier_model_by_name(args.name)

  if not classifier_model then
    local id = db.add_classifier_model(args.name, pairs_model_train.id, args)
    classifier_model = db.get_classifier_model_by_id(id)
    assert(classifier_model, "this is a bug! classifier model not created")
  end

  if classifier_model.trained == 1 then
    err.error("Classifier already created")
  end

  print("Loading datasets")

  local train_dataset = get_dataset(db, pairs_model_train,
    args.max_records and args.max_records[1] or nil)

  local test_dataset = get_dataset(db, pairs_model_test,
    args.max_records and args.max_records[2] or nil)

  print("Packing datasets")

  local train_problems, train_solutions = pack_dataset(train_dataset)
  local test_problems, test_solutions = pack_dataset(test_dataset)

  print("Input Bits", train_dataset.fingerprint_bits * 2 * 2)
  print("Labels", train_dataset.n_labels)
  print("Total Train", #train_dataset.pairs)
  print("Total Test", #test_dataset.pairs)

  local t = tm.classifier(
    train_dataset.n_labels,
    train_dataset.fingerprint_bits * 2,
    args.clauses,
    args.state_bits,
    args.threshold,
    args.boost_true_positive,
    args.specificity and args.specificity[1] or nil,
    args.specificity and args.specificity[2] or nil)

  print("Training")

  for epoch = 1, args.epochs do

    local start = os.time()
    tm.train(t, #train_dataset.pairs, train_problems, train_solutions, args.active_clause)
    local duration = os.time() - start

    if epoch == args.epochs or epoch % args.evaluate_every == 0 then
      local train_score = tm.evaluate(t, #train_dataset.pairs, train_problems, train_solutions)
      local test_score = tm.evaluate(t, #test_dataset.pairs, test_problems, test_solutions)
      str.printf("Epoch %-4d  Time %-4d  Test %4.2f  Train %4.2f\n",
        epoch, duration, test_score, train_score)
    else
      str.printf("Epoch %-4d  Time %d\n",
        epoch, duration)
    end

  end

  -- TODO: write directly to sqlite without temporary file
  local fp = fs.tmpname()
  tm.persist(t, fp)
  db.set_classifier_trained(classifier_model.id, fs.readfile(fp))
  fs.rm(fp)

end

return {
  create_classifier = create_classifier,
}
