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

local function get_baseline (dataset)
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

local function get_dataset (db, sentences_model, args, max)

  print("Loading sentence triplets")
  local triplets = db.get_sentence_triplets(sentences_model.id, max)

  local fingerprint_bits = hash.segment_bits * args.segments * args.dimensions

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

local function pack_dataset (dataset)
  local gs = {}
  for i = 1, #dataset.triplets do
    local s = dataset.triplets[i]
    arr.push(gs, s.group)
  end
  return bm.raw_matrix(gs, dataset.input_bits * 3)
end

local function create_encoder (db, args)

  print("Creating encoder")

  local sentences_model_train = db.get_sentences_model_by_name(args.sentences[1])
  if not sentences_model_train or sentences_model_train.loaded ~= 1 then
    err.error("Train sentences model not loaded", args.sentences[1])
  end

  local sentences_model_test = db.get_sentences_model_by_name(args.sentences[2])
  if not sentences_model_test or sentences_model_test.loaded ~= 1 then
    err.error("Test sentences model not loaded", args.sentences[2])
  end
  if sentences_model_test.args.id_parent_model ~= sentences_model_train.id then
    err.error("Test sentences model it not related to train model", sentences_model_train.name, sentences_model_test.name)
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

  print("Loading datasets")

  -- local dataset = get_dataset(db, sentences_model_train, sentences_model_train.args, args.max_records and args.max_records[1] or nil)
  -- local train_dataset = { triplets = arr.copy({}, dataset.triplets, 1, 1, math.floor(#dataset.triplets * 0.8)), input_bits = dataset.input_bits, fingerprint_bits = dataset.fingerprint_bits }
  -- local test_dataset = { triplets = arr.copy({}, dataset.triplets, 1, math.floor(#dataset.triplets * 0.8) + 1, #dataset.triplets), input_bits = dataset.input_bits, fingerprint_bits = dataset.fingerprint_bits }

  local train_dataset = get_dataset(db, sentences_model_train, sentences_model_train.args, args.max_records and args.max_records[1] or nil)
  local test_dataset = get_dataset(db, sentences_model_test, sentences_model_train.args, args.max_records and args.max_records[2] or nil)

  print("Calculating baselines")

  local train_baseline = get_baseline(train_dataset)
  local test_baseline = get_baseline(test_dataset)

  print("Packing datasets")

  local train_data = pack_dataset(train_dataset)
  local test_data = pack_dataset(test_dataset)

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
      args.margin, args.loss_alpha)
    local duration = os.time() - start

    if epoch == args.epochs or epoch % args.evaluate_every == 0 then
      local train_score = tm.evaluate(t, #train_dataset.triplets, train_data, args.margin)
      local test_score = tm.evaluate(t, #test_dataset.triplets, test_data, args.margin)
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
