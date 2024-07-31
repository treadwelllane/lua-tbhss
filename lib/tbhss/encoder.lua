local serialize = require("santoku.serialize") -- luacheck: ignore
local tm = require("santoku.tsetlin")
local fs = require("santoku.fs")
local str = require("santoku.string")
local bm = require("santoku.bitmap")
local arr = require("santoku.array")
local num = require("santoku.num")
local err = require("santoku.error")

local hash = require("tbhss.hash")

local function prep_fingerprint (fingerprint, bits)
  local flipped = bm.copy(fingerprint)
  bm.flip(flipped, 1, bits)
  bm.extend(fingerprint, flipped, bits + 1)
  return fingerprint
end

local function get_baseline (dataset, s, e)
  local correct = 0
  s, e = s or 1, e or #dataset.triplets
  for i = s, e do
    local t = dataset.triplets[i]
    local dn = bm.hamming(t.anchor_fingerprint, t.negative_fingerprint)
    local dp = bm.hamming(t.anchor_fingerprint, t.positive_fingerprint)
    if dp < dn then
      correct = correct + 1
    end
  end
  return correct / #dataset.triplets
end

local function get_dataset (db, sentences_model, args)

  print("Loading sentence triplets")
  local triplets = db.get_sentence_triplets(sentences_model.id, args.max_records)

  local fingerprint_bits = hash.segment_bits * sentences_model.segments * sentences_model.dimensions

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
    encoded_bits = args.encoded_bits,
  }

end

local function split_dataset (dataset, s, e)
  local gs = {}
  for i = s, e do
    local s = dataset.triplets[i]
    arr.push(gs, s.group)
  end
  return bm.raw_matrix(gs, dataset.input_bits * 3)
end

local function create_encoder (db, args)

  print("Creating encoder")

  local sentences_model_train = db.get_sentences_model_by_name(args.sentences[1])

  if not sentences_model_train or sentences_model_train.loaded ~= 1 then
    err.error("Sentences model not loaded", args.sentences)
  end

  local encoder_model = db.get_encoder_model_by_name(args.name)

  if not encoder_model then
    local id = db.add_encoder_model(args.name, sentences_model_train.id, args)
    encoder_model = db.get_encoder_model_by_id(id)
    assert(encoder_model, "this is a bug! encoder model not created")
  end

  if encoder_model.trained == 1 then
    err.error("Encoder already created")
  end

  local n_train, train_data, train_dataset, train_baseline
  local n_test, test_data, test_dataset, test_baseline

  local train_dataset = get_dataset(db, sentences_model_train, args)

  print("Splitting & packing")

  n_train = num.floor(#train_dataset.triplets * args.train_test_ratio)
  n_test = #train_dataset.triplets - n_train
  train_data = split_dataset(train_dataset, 1, n_train)
  test_data = split_dataset(train_dataset, n_train + 1, n_train + n_test)
  train_baseline = get_baseline(train_dataset, 1, n_train)
  test_baseline = get_baseline(train_dataset, n_train + 1, n_train + n_test)

  print("Input Bits", train_dataset.input_bits)
  print("Encoded Bits", train_dataset.encoded_bits)
  print("Total Train", n_train)
  print("Total Test", n_test)

  local t = tm.encoder(
    args.encoded_bits, train_dataset.input_bits / 2, args.clauses,
    args.state_bits, args.threshold, args.boost_true_positive,
    args.specificity and args.specificity[1] or nil,
    args.specificity and args.specificity[2] or nil)

  print("Training")

  str.printf("Initial                Test %4.2f  Train %4.2f\n", test_baseline, train_baseline)

  for epoch = 1, args.epochs do

    local start = os.time()
    tm.train(t, n_train, train_data, args.active_clause,
      args.margin, args.loss_alpha)
    local duration = os.time() - start

    if epoch == args.epochs or epoch % args.evaluate_every == 0 then
      local train_score = tm.evaluate(t, n_train, train_data, args.margin)
      local test_score = tm.evaluate(t, n_test, test_data, args.margin)
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

return {
  create_encoder = create_encoder,
}
