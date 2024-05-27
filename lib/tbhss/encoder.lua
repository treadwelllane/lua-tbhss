local serialize = require("santoku.serialize") -- luacheck: ignore
local tm = require("santoku.tsetlin")
local it = require("santoku.iter")
local fs = require("santoku.fs")
local str = require("santoku.string")
local mtx = require("santoku.matrix")
local rand = require("santoku.random")
local bm = require("santoku.bitmap")
local arr = require("santoku.array")
local num = require("santoku.num")
local err = require("santoku.error")

local tbhss = require("tbhss")

local function get_recurrent_dataset (db, tokenizer, sentences_model, args)

  local triplets = db.get_sentence_triplets(sentences_model.id)

  if args.max_records then
    triplets = it.take(args.max_records, triplets)
  end

  triplets = it.collect(it.filter(function (s)
    s.anchor, s.anchor_words = tokenizer.tokenize(s.anchor)
    s.negative, s.negative_words = tokenizer.tokenize(s.negative)
    s.positive, s.positive_words = tokenizer.tokenize(s.positive)
    return s.anchor and s.negative and s.positive
  end, triplets))

  for i = 1, 0 --[[#triplets]] do
    local s = triplets[i]
    str.printf("Anchor: %s\n", table.concat(s.anchor_words, " "))
    for j = 1, #s.anchor_words do
      str.printf("  %10s | %s\n", s.anchor_words[j], bm.tostring(s.anchor[j], tokenizer.bits))
    end
    -- str.printf("Negative: %s\n", table.concat(s.negative_words, " "))
    -- for j = 1, #s.negative_words do
    --   str.printf("  %10s | %s\n", s.negative_words[j], bm.tostring(s.negative[j], tokenizer.bits))
    -- end
    -- str.printf("Positive: %s\n", table.concat(s.positive_words, " "))
    -- for j = 1, #s.positive_words do
    --   str.printf("  %10s | %s\n", s.positive_words[j], bm.tostring(s.positive[j], tokenizer.bits))
    -- end
    print()
  end

  return {
    triplets = triplets,
    token_bits = tokenizer.bits,
    encoded_bits = args.encoded_bits,
  }

end

local function split_recurrent_dataset (dataset, s, e)

  local indices = {}
  local tokens = {}

  for i = s, e do
    arr.push(indices, #tokens, #dataset.triplets[i].anchor)
    arr.extend(tokens, dataset.triplets[i].anchor)
    arr.push(indices, #tokens, #dataset.triplets[i].negative)
    arr.extend(tokens, dataset.triplets[i].negative)
    arr.push(indices, #tokens, #dataset.triplets[i].positive)
    arr.extend(tokens, dataset.triplets[i].positive)
  end

  return
    mtx.raw(mtx.create(indices), 1, 1, "u32"),
    bm.raw_matrix(tokens, dataset.token_bits)

end

local function create_encoder_recurrent (db, args)

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

  print("Reading data")
  local dataset = get_recurrent_dataset(db, tokenizer, sentences_model, args)

  print("Splitting & packing")
  local n_train = num.floor(#dataset.triplets * args.train_test_ratio)
  local n_test = #dataset.triplets - n_train

  local train_indices, train_tokens = split_recurrent_dataset(dataset, 1, n_train)
  local test_indices, test_tokens = split_recurrent_dataset(dataset, n_train + 1, n_train + n_test)

  print("Token Bits", dataset.token_bits)
  print("Encoded Bits", dataset.encoded_bits)
  print("Total Train", n_train)
  print("Total Test", n_test)

  local t = tm.recurrent_encoder(
    args.encoded_bits, dataset.token_bits, args.clauses,
    args.state_bits, args.threshold, args.boost_true_positive)

  print("Training")

  local train_score = tm.evaluate(t, n_train, train_indices, train_tokens, args.margin)
  local test_score = tm.evaluate(t, n_test, test_indices, test_tokens, args.margin)
  str.printf("Initial                Test %4.2f  Train %4.2f\n", test_score, train_score)

  for epoch = 1, args.epochs do

    local start = os.time()
    tm.train(t, n_train, train_indices, train_tokens,
      args.specificity, args.active_clause,
      args.margin, args.loss_alpha)
    local duration = os.time() - start

    local result = ""
    -- local mask = bm.create()
    -- bm.set(mask, 1, dataset.token_bits)
    -- local result = bm.tostring(bm.from_raw(tm.predict(t,
    --   #dataset.triplets[1].anchor,
    --   bm.raw_matrix(dataset.triplets[1].anchor, dataset.token_bits),
    --   #dataset.triplets[1].anchor)),
    --   args.encoded_bits)

    if epoch == args.epochs or epoch % args.evaluate_every == 0 then
      local train_score = tm.evaluate(t, n_train, train_indices, train_tokens, args.margin)
      local test_score = tm.evaluate(t, n_test, test_indices, test_tokens, args.margin)
      str.printf("Epoch %-4d  Time %-4d  Test %4.2f  Train %4.2f  %s\n",
        epoch, duration, test_score, train_score, result)
    else
      str.printf("Epoch %-4d  Time %d  %s\n",
        epoch, duration, result)
    end

  end

  -- for i = 1, #dataset.triplets do
  --   local mask = bm.create()
  --   bm.set(mask, 1, dataset.token_bits)
  --   local s = dataset.triplets[i]
  --   str.printf("Anchor: %s\n", table.concat(s.anchor_words, " "))
  --   str.printf("  %s\n", bm.tostring(bm.from_raw(tm.predict(t,
  --     #dataset.triplets[i].anchor,
  --     bm.raw_matrix(dataset.triplets[i].anchor, dataset.token_bits),
  --     #dataset.triplets[i].anchor)),
  --     args.encoded_bits))
  --   str.printf("Negative: %s\n", table.concat(s.negative_words, " "))
  --   str.printf("  %s\n", bm.tostring(bm.from_raw(tm.predict(t,
  --     #dataset.triplets[i].negative,
  --     bm.raw_matrix(dataset.triplets[i].negative, dataset.token_bits),
  --     #dataset.triplets[i].negative)),
  --     args.encoded_bits))
  --   str.printf("Positive: %s\n", table.concat(s.positive_words, " "))
  --   str.printf("  %s\n", bm.tostring(bm.from_raw(tm.predict(t,
  --     #dataset.triplets[i].positive,
  --     bm.raw_matrix(dataset.triplets[i].positive, dataset.token_bits),
  --     #dataset.triplets[i].positive)),
  --     args.encoded_bits))
  --   print()
  -- end

  -- TODO: write directly to sqlite without temporary file
  local fp = fs.tmpname()
  tm.persist(t, fp)
  db.set_encoder_trained(encoder_model.id, fs.readfile(fp))
  fs.rm(fp)

end

local function prep_windowed_bitmap (word_bitmaps, word_bits, window_bits)
  local all = bm.matrix(word_bitmaps, word_bits, 1, #word_bitmaps, window_bits)
  local flipped = bm.copy(all)
  bm.flip(flipped, window_bits)
  bm.extend(all, flipped, window_bits)
  return all
end

local function get_windowed_dataset (db, tokenizer, sentences_model, args)

  local triplets = db.get_sentence_triplets(sentences_model.id)

  if args.max_records then
    triplets = it.take(args.max_records, triplets)
  end

  triplets = it.collect(it.filter(function (s)
    s.anchor, s.anchor_words = tokenizer.tokenize(s.anchor, args.window_size, true)
    s.negative, s.negative_words = tokenizer.tokenize(s.negative, args.window_size, true)
    s.positive, s.positive_words = tokenizer.tokenize(s.positive, args.window_size, true)
    return s.anchor and s.negative and s.positive
  end, triplets))

  local window_bits = args.window_size * tokenizer.bits

  for i = 1, #triplets do
    local s = triplets[i]
    s.group = bm.matrix({
      prep_windowed_bitmap(s.anchor, tokenizer.bits, window_bits),
      prep_windowed_bitmap(s.negative, tokenizer.bits, window_bits),
      prep_windowed_bitmap(s.positive, tokenizer.bits, window_bits)
    }, window_bits * 2)
  end

  for i = 1, 1 --[[#triplets]] do
    local s = triplets[i]
    str.printf("Anchor: %s\n", table.concat(s.anchor_words, " "))
    for j = 1, #s.anchor_words do
      str.printf("  %10s | %s\n", s.anchor_words[j], bm.tostring(s.anchor[j], tokenizer.bits))
    end
    str.printf("Negative: %s\n", table.concat(s.negative_words, " "))
    for j = 1, #s.negative_words do
      str.printf("  %10s | %s\n", s.negative_words[j], bm.tostring(s.negative[j], tokenizer.bits))
    end
    str.printf("Positive: %s\n", table.concat(s.positive_words, " "))
    for j = 1, #s.positive_words do
      str.printf("  %10s | %s\n", s.positive_words[j], bm.tostring(s.positive[j], tokenizer.bits))
    end
    print()
  end

  return {
    triplets = triplets,
    window_bits = window_bits,
    encoded_bits = args.encoded_bits,
  }

end

local function split_windowed_dataset (dataset, s, e)
  local gs = {}
  for i = s, e do
    local s = dataset.triplets[i]
    arr.push(gs, s.group)
  end
  return bm.raw_matrix(gs, dataset.window_bits * 2 * 3)
end

local function create_encoder_windowed (db, args)

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

  print("Reading data")
  local dataset = get_windowed_dataset(db, tokenizer, sentences_model, args)

  print("Shuffling")
  rand.seed()
  arr.shuffle(dataset.triplets)

  print("Splitting & packing")
  local n_train = num.floor(#dataset.triplets * args.train_test_ratio)
  local n_test = #dataset.triplets - n_train

  local train_data = split_windowed_dataset(dataset, 1, n_train)
  local test_data = split_windowed_dataset(dataset, n_train + 1, n_train + n_test)

  print("Window Words", args.window_size)
  print("Window Bits", dataset.window_bits)
  print("Encoded Bits", dataset.encoded_bits)
  print("Total Train", n_train)
  print("Total Test", n_test)

  local t = tm.encoder(
    args.encoded_bits, dataset.window_bits, args.clauses,
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
  create_encoder_recurrent = create_encoder_recurrent,
  create_encoder_windowed = create_encoder_windowed,
}
