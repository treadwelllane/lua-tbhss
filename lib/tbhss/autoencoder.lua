local serialize = require("santoku.serialize") -- luacheck: ignore
local tm = require("santoku.tsetlin")
local fs = require("santoku.fs")
local str = require("santoku.string")
local bm = require("santoku.bitmap")
local arr = require("santoku.array")
local err = require("santoku.error")

local function prep_fingerprint (fingerprint, bits)
  local flipped = bm.copy(fingerprint)
  bm.flip(flipped, 1, bits)
  bm.extend(fingerprint, flipped, bits + 1)
  return fingerprint
end

local function get_dataset (db, triplets_model, max)
  print("Loading sentences")
  local sentences = db.get_sentence_fingerprints(triplets_model.id, max)
  local fingerprint_bits = triplets_model.bits
  local problems = {}
  for i = 1, #sentences do
    local s = sentences[i]
    arr.push(problems, prep_fingerprint(bm.from_raw(s.fingerprint, fingerprint_bits), fingerprint_bits))
  end
  return {
    problems = problems,
    fingerprint_bits = fingerprint_bits,
    input_bits = fingerprint_bits * 2,
  }
end

local function pack_dataset (dataset)
  local gs = {}
  for i = 1, #dataset.problems do
    arr.push(gs, dataset.problems[i])
  end
  return bm.raw_matrix(gs, dataset.input_bits)
end

local function create_autoencoder (db, args)

  print("Creating autoencoder")

  local triplets_model_train = db.get_triplets_model_by_name(args.triplets[1])
  if not triplets_model_train or triplets_model_train.loaded ~= 1 then
    err.error("Train triplets model not loaded", args.triplets[1])
  elseif triplets_model_train.type ~= "triplets" then
    err.error("Not a triplets model")
  end

  local triplets_model_test = db.get_triplets_model_by_name(args.triplets[2])
  if not triplets_model_test or triplets_model_test.loaded ~= 1 then
    err.error("Test triplets model not loaded", args.triplets[2])
  elseif triplets_model_test.type ~= "triplets" then
    err.error("Not a triplets model")
  end

  if triplets_model_test.args.id_parent_model ~= triplets_model_train.id then
    err.error("Test triplets model is not related to the train model",
      triplets_model_train.name, triplets_model_test.name)
  end

  local autoencoder_model = db.get_autoencoder_model_by_name(args.name)

  if not autoencoder_model then
    local id = db.add_autoencoder_model(args.name, triplets_model_train.id, args)
    autoencoder_model = db.get_autoencoder_model_by_id(id)
    assert(autoencoder_model, "this is a bug! autoencoder model not created")
  end

  if autoencoder_model.trained == 1 then
    err.error("Autoencode already created")
  end

  print("Loading datasets")

  local train_dataset = get_dataset(db, triplets_model_train,
    args.max_records and args.max_records[1] or nil)

  local test_dataset = get_dataset(db, triplets_model_test,
    args.max_records and args.max_records[2] or nil)

  print("Packing datasets")

  local train_data = pack_dataset(train_dataset)
  local test_data = pack_dataset(test_dataset)

  print("Input Bits", train_dataset.input_bits)
  print("Encoded Bits", args.encoded_bits)
  print("Total Train", #train_dataset.problems)
  print("Total Test", #test_dataset.problems)

  local t = tm.auto_encoder(
    args.encoded_bits, train_dataset.fingerprint_bits, args.clauses,
    args.state_bits, args.threshold, args.boost_true_positive,
    args.specificity and args.specificity[1] or nil,
    args.specificity and args.specificity[2] or nil)

  print("Training")

  for epoch = 1, args.epochs do

    local start = os.time()
    tm.train(t, #train_dataset.problems, train_data, args.active_clause, args.loss_alpha)
    local duration = os.time() - start

    if epoch == args.epochs or epoch % args.evaluate_every == 0 then
      local train_score = tm.evaluate(t, #train_dataset.problems, train_data, args.margin)
      local test_score = tm.evaluate(t, #test_dataset.problems, test_data, args.margin)
      str.printf("Epoch %-4d  Time %-4d  Test %4.2f  Train %4.2f\n", epoch, duration, test_score, train_score)
    else
      str.printf("Epoch %-4d  Time %d\n", epoch, duration)
    end

  end

  -- TODO: write directly to sqlite without temporary file
  local fp = fs.tmpname()
  tm.persist(t, fp)
  db.set_autoencoder_trained(autoencoder_model.id, fs.readfile(fp))
  fs.rm(fp)

end

return {
  create_autoencoder = create_autoencoder,
}
