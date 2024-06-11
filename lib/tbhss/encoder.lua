local serialize = require("santoku.serialize") -- luacheck: ignore
local tm = require("santoku.tsetlin")
local fs = require("santoku.fs")
local str = require("santoku.string")
local bm = require("santoku.bitmap")
local arr = require("santoku.array")
local num = require("santoku.num")
local err = require("santoku.error")

local tbhss = require("tbhss")
local hash = require("tbhss.hash")

local function get_fingerprint (data, normalizer, args)
  local tokens = normalizer.normalize(data, args.clusters[2], args.clusters[3], args.clusters[3], true)
  local raw, bits = hash.fingerprint(tokens, args.segments)
  local b = bm.from_raw(raw)
  local flipped = bm.copy(b)
  bm.flip(flipped, 1, bits)
  bm.extend(b, flipped, bits + 1)
  return b, tokens
end

local function get_dataset (db, normalizer, sentences_model, args)

  print("Loading sentence triplets")
  local triplets = db.get_sentence_triplets(sentences_model.id, args.max_records)

  local input_bits = args.segments * hash.segment_bits * 4

  print("Tokenizing")
  for i = 1, #triplets do
    local s = triplets[i]
    s.original = { anchor = s.anchor, negative = s.negative, positive = s.positive }
    s.anchor, s.anchor_tokens = get_fingerprint(s.anchor, normalizer, args)
    s.negative, s.negative_tokens = get_fingerprint(s.negative, normalizer, args)
    s.positive, s.positive_tokens = get_fingerprint(s.positive, normalizer, args)
    s.group = bm.matrix({ s.anchor, s.negative, s.positive, }, input_bits)
  end

  return {
    triplets = triplets,
    input_bits = input_bits,
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

  local normalizer = tbhss.normalizer(db, args.clusters[1])

  local encoder_model = db.get_encoder_model_by_name(args.name)

  if not encoder_model then
    local id = db.add_encoder_model(args.name, nil, args)
    encoder_model = db.get_encoder_model_by_id(id)
    assert(encoder_model, "this is a bug! encoder model not created")
  end

  if encoder_model.trained == 1 then
    err.error("Encoder already created")
  end

  local n_train, train_data, train_dataset
  local n_test, test_data, test_dataset

  if #args.sentences == 1 then
    args.sentences = args.sentences[1]
    local sentences_model = db.get_sentences_model_by_name(args.sentences)
    if not sentences_model or sentences_model.loaded ~= 1 then
      err.error("Sentences model not loaded", args.sentences)
    end
    train_dataset = get_dataset(db, normalizer, sentences_model, args)
    print("Splitting & packing")
    n_train = num.floor(#train_dataset.triplets * args.train_test_ratio)
    n_test = #train_dataset.triplets - n_train
    train_data = split_dataset(train_dataset, 1, n_train)
    test_data = split_dataset(train_dataset, n_train + 1, n_train + n_test)
  else
    local sm_train = db.get_sentences_model_by_name(args.sentences[1])
    local sm_test = db.get_sentences_model_by_name(args.sentences[2])
    if not (sm_train and sm_test and sm_train.loaded == 1 and sm_test.loaded == 1) then
      err.error("Sentences model not loaded", args.sentences[1] or "nil", args.sentences[2] or "nil")
    end
    train_dataset = get_dataset(db, normalizer, sm_train, args)
    test_dataset = get_dataset(db, normalizer, sm_test, args)
    n_train = #train_dataset.triplets
    n_test = #test_dataset.triplets
    train_data = split_dataset(train_dataset, 1, n_train)
    test_data = split_dataset(test_dataset, 1, n_test)
  end

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

  local train_score = tm.evaluate(t, n_train, train_data, args.margin, args.loss_alpha)
  local test_score = tm.evaluate(t, n_test, test_data, args.margin, args.loss_alpha)
  str.printf("Initial                Test %4.2f  Train %4.2f\n", test_score, train_score)

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
