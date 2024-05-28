local serialize = require("santoku.serialize") -- luacheck: ignore
local tm = require("santoku.tsetlin")
local it = require("santoku.iter")
local fs = require("santoku.fs")
local str = require("santoku.string")
local rand = require("santoku.random")
local bm = require("santoku.bitmap")
local arr = require("santoku.array")
local num = require("santoku.num")
local err = require("santoku.error")

local tbhss = require("tbhss")

local function prep_bitmap (word_bitmaps, word_bits)
  local b0 = bm.create()
  for i = 1, #word_bitmaps do
    bm["or"](b0, word_bitmaps[i])
  end
  local flipped = bm.copy(b0)
  bm.flip(flipped, word_bits)
  bm.extend(b0, flipped, word_bits)
  return b0
end

local function get_dataset (db, tokenizer, sentences_model, args)

  print("Loading sentence triplets")
  local triplets = db.get_sentence_triplets(sentences_model.id, args.max_records)

  print("Tokenizing")
  for i = 1, #triplets do
    local s = triplets[i]
    s.anchor, s.anchor_words = tokenizer.tokenize(s.anchor)
    s.negative, s.negative_words = tokenizer.tokenize(s.negative)
    s.positive, s.positive_words = tokenizer.tokenize(s.positive)
    s.anchor = prep_bitmap(s.anchor, tokenizer.bits)
    s.negative = prep_bitmap(s.negative, tokenizer.bits)
    s.positive = prep_bitmap(s.positive, tokenizer.bits)
    s.group = bm.matrix({ s.anchor, s.negative, s.positive, }, tokenizer.bits * 2)
  end

  for i = 1, 1 --[[#triplets]] do
    local s = triplets[i]
    str.printf("Anchor: %s\n", arr.concat(s.anchor_words, " "))
    str.printf("  %s\n", bm.tostring(s.anchor, tokenizer.bits * 2))
    str.printf("Negative: %s\n", arr.concat(s.negative_words, " "))
    str.printf("  %s\n", bm.tostring(s.negative, tokenizer.bits * 2))
    str.printf("Positive: %s\n", arr.concat(s.positive_words, " "))
    str.printf("  %s\n", bm.tostring(s.positive, tokenizer.bits * 2))
    print()
  end

  return {
    triplets = triplets,
    token_bits = tokenizer.bits,
    encoded_bits = args.encoded_bits,
  }

end

local function split_dataset (dataset, s, e)
  local gs = {}
  for i = s, e do
    local s = dataset.triplets[i]
    arr.push(gs, s.group)
  end
  return bm.raw_matrix(gs, dataset.token_bits * 2 * 3)
end

local function create_encoder (db, args)

  print("Creating encoder")

  local tokenizer = tbhss.tokenizer(db, args.bitmaps)

  if not tokenizer then
    err.error("Tokenzer not loaded")
  end

  local encoder_model = db.get_encoder_model_by_name(args.name)

  if not encoder_model then
    local id = db.add_encoder_model(args.name, tokenizer.bitmaps_model.id, args)
    encoder_model = db.get_encoder_model_by_id(id)
    assert(encoder_model, "this is a bug! encoder model not created")
  end

  if encoder_model.trained == 1 then
    err.error("Encoder already created")
  end

  local sentences_model = db.get_sentences_model_by_name(args.sentences)

  if not sentences_model or sentences_model.loaded ~= 1 then
    err.error("Sentences model not loaded", args.sentences)
  end

  local dataset = get_dataset(db, tokenizer, sentences_model, args)

  print("Splitting & packing")
  local n_train = num.floor(#dataset.triplets * args.train_test_ratio)
  local n_test = #dataset.triplets - n_train

  local train_data = split_dataset(dataset, 1, n_train)
  local test_data = split_dataset(dataset, n_train + 1, n_train + n_test)

  print("Token Bits", dataset.token_bits)
  print("Encoded Bits", dataset.encoded_bits)
  print("Total Train", n_train)
  print("Total Test", n_test)

  local t = tm.encoder(
    args.encoded_bits, dataset.token_bits, args.clauses,
    args.state_bits, args.threshold, args.boost_true_positive)

  print("Training")

  local train_score = tm.evaluate(t, n_train, train_data, args.margin, args.loss_alpha)
  local test_score = tm.evaluate(t, n_test, test_data, args.margin, args.loss_alpha)
  str.printf("Initial                Test %4.2f  Train %4.2f\n", test_score, train_score)

  for epoch = 1, args.epochs do

    local start = os.time()
    tm.train(t, n_train, train_data,
      args.specificity, args.active_clause,
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
