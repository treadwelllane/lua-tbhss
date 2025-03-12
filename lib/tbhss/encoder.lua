local serialize = require("santoku.serialize") -- luacheck: ignore
local tm = require("santoku.tsetlin")
local rand = require("santoku.random")
local fs = require("santoku.fs")
local str = require("santoku.string")
local bm = require("santoku.bitmap")
local mtx = require("santoku.matrix")
local arr = require("santoku.array")
local err = require("santoku.error")

local function prep_fingerprint (fingerprint, bits)
  local flipped = bm.copy(fingerprint)
  bm.flip(flipped, 1, bits)
  bm.extend(fingerprint, flipped, bits + 1)
  return fingerprint
end

local function get_baseline_triplet (dataset)
  local correct = 0
  for i = 1, #dataset.triplets do
    local t = dataset.triplets[i]
    local dn = bm.hamming(t.anchor_fingerprint, t.negative_fingerprint)
    local dp = bm.hamming(t.anchor_fingerprint, t.positive_fingerprint)
    if dp < dn then
      correct = correct + 1
    end
  end
  return correct / #dataset.triplets
end

local function get_dataset_triplet (db, triplets_model, max)

  print("Loading sentence triplets")
  local triplets = db.get_sentence_triplets(triplets_model.id, max)

  local fingerprint_bits = triplets_model.bits

  for i = 1, #triplets do
    local s = triplets[i]
    s.anchor_fingerprint = bm.from_raw(s.anchor_fingerprint, fingerprint_bits)
    s.negative_fingerprint = bm.from_raw(s.negative_fingerprint, fingerprint_bits)
    s.positive_fingerprint = bm.from_raw(s.positive_fingerprint, fingerprint_bits)
    s.group = bm.matrix({
      prep_fingerprint(s.anchor_fingerprint, fingerprint_bits),
      prep_fingerprint(s.negative_fingerprint, fingerprint_bits),
      prep_fingerprint(s.positive_fingerprint, fingerprint_bits),
    }, fingerprint_bits * 2)
  end

  return {
    triplets = triplets,
    fingerprint_bits = fingerprint_bits,
    input_bits = fingerprint_bits * 2,
  }

end

local function load_fingerprint (f, b)
  return type(f) ~= "string" and f or bm.from_raw(f, b)
end

local function get_dataset_contrastive (db, triplets_model, max, num_pairs)

  print("Loading sentence pairs")

  local sentences = db.get_sentence_fingerprints(triplets_model.id, max)

  local fingerprint_bits = triplets_model.bits

  for i = 1, #sentences do
    local s = sentences[i]
    s.fingerprint = load_fingerprint(s.fingerprint, fingerprint_bits)
    s.pairs = {}
    while #s.pairs < (num_pairs or 1) do
      local p = rand.num(1, #sentences)
      if not arr.find(s.pairs, function (p)
        return p.idx == p
      end) then
        p = { idx = p, pair = sentences[p] }
        p.pair.fingerprint = load_fingerprint(p.pair.fingerprint, fingerprint_bits)
        p.dist = bm.hamming(s.fingerprint, p.pair.fingerprint)
        arr.push(s.pairs, p)
      end
    end
  end

  local pairs = {}

  for i = 1, #sentences do
    local s = sentences[i]
    for j = 1, #s.pairs do
      local p = s.pairs[j]
      arr.push(pairs, {
        a = s.fingerprint,
        b = p.pair.fingerprint,
        d = p.dist
      })
    end
  end

  return {
    pairs = pairs,
    fingerprint_bits = fingerprint_bits,
    input_bits = fingerprint_bits * 2,
  }

end

local function pack_dataset_triplet (dataset)
  local gs = {}
  for i = 1, #dataset.triplets do
    local s = dataset.triplets[i]
    arr.push(gs, s.group)
  end
  return bm.raw_matrix(gs, dataset.input_bits * 3)
end

local function pack_dataset_contrastive (dataset)
  local problems = {}
  local solutions = {}
  for i = 1, #dataset.pairs do
    local p = dataset.pairs[i]
    arr.push(problems,
      prep_fingerprint(p.a, dataset.fingerprint_bits),
      prep_fingerprint(p.b, dataset.fingerprint_bits))
    arr.push(solutions,
      p.d / dataset.fingerprint_bits)
  end
  local ps = bm.raw_matrix(problems, dataset.input_bits)
  local ss = mtx.create(solutions)
  return ps, ss
end

local function create_encoder_triplet (db, args)

  print("Creating triplet encoder")

  local triplets_model_train = db.get_triplets_model_by_name(args.triplets[1])
  if not triplets_model_train or triplets_model_train.loaded ~= 1 then
    err.error("Train triplets model not loaded", args.triplets[1])
  end

  local triplets_model_test = db.get_triplets_model_by_name(args.triplets[2])
  if not triplets_model_test or triplets_model_test.loaded ~= 1 then
    err.error("Test triplets model not loaded", args.triplets[2])
  end
  if triplets_model_test.args.id_parent_model ~= triplets_model_train.id then
    print("WARNING: test triplets model is not related to train model",
      triplets_model_train.name, triplets_model_test.name)
  end

  local encoder_model = db.get_encoder_model_by_name(args.name)

  if not encoder_model then
    local id = db.add_encoder_model(args.name, triplets_model_train.id, args)
    encoder_model = db.get_encoder_model_by_id(id)
    assert(encoder_model, "this is a bug! encoder model not created")
  end

  if encoder_model.trained == 1 then
    err.error("Encoder already created")
  end

  print("Loading datasets")

  local train_dataset = get_dataset_triplet(db, triplets_model_train,
    args.max_records and args.max_records[1] or nil)

  local test_dataset = get_dataset_triplet(db, triplets_model_test,
    args.max_records and args.max_records[2] or nil)

  print("Calculating baselines")

  local train_baseline = get_baseline_triplet(train_dataset)
  local test_baseline = get_baseline_triplet(test_dataset)

  print("Packing datasets")

  local train_data = pack_dataset_triplet(train_dataset)
  local test_data = pack_dataset_triplet(test_dataset)

  print("Input Bits", train_dataset.input_bits)
  print("Encoded Bits", args.encoded_bits)
  print("Total Train", #train_dataset.triplets)
  print("Total Test", #test_dataset.triplets)

  local t = tm.encoder(
    args.encoded_bits, train_dataset.input_bits / 2, args.clauses,
    args.state_bits, args.threshold, args.boost_true_positive,
    args.specificity and args.specificity[1] or nil,
    args.specificity and args.specificity[2] or nil)

  print("Training")

  str.printf("Initial                Test %4.2f  Train %4.2f\n", test_baseline, train_baseline)

  for epoch = 1, args.epochs do

    local start = os.time()
    tm.train(t, #train_dataset.triplets, train_data, args.active_clause,
      args.loss_alpha, arr.spread(args.loss_function))
    local duration = os.time() - start

    if epoch == args.epochs or epoch % args.evaluate_every == 0 then
      local train_score = tm.evaluate(t, #train_dataset.triplets, train_data, arr.spread(args.loss_function))
      local test_score = tm.evaluate(t, #test_dataset.triplets, test_data, arr.spread(args.loss_function))
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
  db.set_encoder_trained(encoder_model.id, fs.readfile(fp))
  fs.rm(fp)

end

local function create_encoder_contrastive (db, args)

  print("Creating contrastive encoder")

  local triplets_model_train = db.get_triplets_model_by_name(args.triplets[1])
  if not triplets_model_train or triplets_model_train.loaded ~= 1 then
    err.error("Train triplets model not loaded", args.triplets[1])
  end

  local triplets_model_test = db.get_triplets_model_by_name(args.triplets[2])
  if not triplets_model_test or triplets_model_test.loaded ~= 1 then
    err.error("Test triplets model not loaded", args.triplets[2])
  end

  if triplets_model_test.args.id_parent_model ~= triplets_model_train.id then
    print("WARNING: test triplets model is not related to train model",
      triplets_model_train.name, triplets_model_test.name)
  end

  local encoder_model = db.get_encoder_model_by_name(args.name)

  if not encoder_model then
    local id = db.add_encoder_model(args.name, triplets_model_train.id, args)
    encoder_model = db.get_encoder_model_by_id(id)
    assert(encoder_model, "this is a bug! encoder model not created")
  end

  if encoder_model.trained == 1 then
    err.error("Encoder already created")
  end

  print("Loading datasets")

  local train_dataset = get_dataset_contrastive(db, triplets_model_train,
    args.max_records and args.max_records[1] or nil, arr.spread(args.loss_function, 2))

  local test_dataset = get_dataset_contrastive(db, triplets_model_test,
    args.max_records and args.max_records[2] or nil, arr.spread(args.loss_function, 2))

  print("Packing datasets")

  print("Test 1")
  local train_data = pack_dataset_contrastive(train_dataset)
  print("Test 2", #test_dataset.pairs, test_dataset.fingerprint_bits, test_dataset.input_bits)
  local test_data = pack_dataset_contrastive(test_dataset)
  print("Test 3")

  print("Input Bits", train_dataset.input_bits)
  print("Encoded Bits", args.encoded_bits)
  print("Total Train", #train_dataset.pairs)
  print("Total Test", #test_dataset.pairs)

  local t = tm.encoder(
    args.encoded_bits, train_dataset.input_bits / 2, args.clauses,
    args.state_bits, args.threshold, args.boost_true_positive,
    args.specificity and args.specificity[1] or nil,
    args.specificity and args.specificity[2] or nil)

  print("Training")

  for epoch = 1, args.epochs do

    local start = os.time()
    tm.train(t, #train_dataset.pairs, train_data, args.active_clause,
      args.loss_alpha, arr.spread(args.loss_function))
    local duration = os.time() - start

    if epoch == args.epochs or epoch % args.evaluate_every == 0 then
      local train_score = tm.evaluate(t, #train_dataset.pairs, train_data, arr.spread(args.loss_function))
      local test_score = tm.evaluate(t, #test_dataset.pairs, test_data, arr.spread(args.loss_function))
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
  db.set_encoder_trained(encoder_model.id, fs.readfile(fp))
  fs.rm(fp)

end

local function create_encoder (db, args)

  if args.loss_function[1] == "contrastive" then
    return create_encoder_contrastive(db, args)
  elseif args.loss_function[1] == "triplet" then
    return create_encoder_triplet(db, args)
  else
    return err.error("unknown loss function", arr.spread(args.loss_function))
  end

end

return {
  create_encoder = create_encoder,
}
