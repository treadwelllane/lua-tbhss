local serialize = require("santoku.serialize") -- luacheck: ignore
local tm = require("santoku.tsetlin")
local it = require("santoku.iter")
local fs = require("santoku.fs")
local str = require("santoku.string")
local mtx = require("santoku.matrix")
local bm = require("santoku.bitmap")
local arr = require("santoku.array")
local num = require("santoku.num")
local err = require("santoku.error")

local tbhss = require("tbhss")

local function get_dataset (db, tokenizer, sentences_model, args)

  local a_lens = {}
  local n_lens = {}
  local p_lens = {}
  local a_data = {}
  local n_data = {}
  local p_data = {}
  local a_words = {}
  local n_words = {}
  local p_words = {}

  local triplets = db.get_sentence_triplets(sentences_model.id)

  if args.max_records then
    triplets = it.take(args.max_records, triplets)
  end

  triplets = it.collect(triplets)

  for i = 1, #triplets do
    local s = triplets[i]
    local a, aw = tokenizer.tokenize(s.anchor)
    local n, nw = tokenizer.tokenize(s.negative)
    local p, pw = tokenizer.tokenize(s.positive)
    if a and n and p then
      arr.push(a_lens, #a)
      arr.push(n_lens, #n)
      arr.push(p_lens, #p)
      arr.push(a_data, a)
      arr.push(n_data, n)
      arr.push(p_data, p)
      arr.push(a_words, aw)
      arr.push(n_words, nw)
      arr.push(p_words, pw)
    end
  end

  local token_bits = tokenizer.clusters_model.clusters

  return {
    a_lens = a_lens,
    n_lens = n_lens,
    p_lens = p_lens,
    a_data = a_data,
    n_data = n_data,
    p_data = p_data,
    a_words = a_words,
    n_words = n_words,
    p_words = p_words,
    total = #a_lens,
    token_bits = token_bits,
    output_bits = args.output_bits,
  }

end

local function split_dataset (dataset, s, e)

  local indices = {}
  local tokens = {}
  -- local words = {}

  local n = 0

  for i = s, e do
    arr.push(indices, n, dataset.a_lens[i])
    n = n + dataset.a_lens[i]
    arr.push(indices, n, dataset.n_lens[i])
    n = n + dataset.n_lens[i]
    arr.push(indices, n, dataset.p_lens[i])
    n = n + dataset.p_lens[i]
    arr.extend(tokens, dataset.a_data[i])
    arr.extend(tokens, dataset.n_data[i])
    arr.extend(tokens, dataset.p_data[i])
    -- arr.extend(words, dataset.a_words[i])
    -- arr.extend(words, dataset.n_words[i])
    -- arr.extend(words, dataset.p_words[i])
  end

  -- for i = 1, #indices, 6 do
  --   local i_off = indices[i]
  --   local i_len = indices[i + 1]
  --   str.printf("%d %d | ", i_off, i_len)
  --   for j = 1, i_len do
  --     str.printf(" %s", words[j + i_off])
  --   end
  --   str.printf("\n")
  -- end

  -- for i = 1, #indices, 6 do
  --   str.printf("Pre %d\n", i / 6)
  --   str.printf("  a: %d %d\n", indices[i], indices[i + 1])
  --   str.printf("  n: %d %d\n", indices[i + 2], indices[i + 3])
  --   str.printf("  p: %d %d\n", indices[i + 4], indices[i + 5])
  --   for j = 1, indices[i + 1] do
  --     print("", words[j + indices[i]], bm.tostring(tokens[j + indices[i]], dataset.token_bits))
  --   end
  -- end

  return
    mtx.raw(mtx.create(indices), 1, 1, "u32"),
    bm.raw_matrix(tokens, dataset.token_bits)

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

  print("Reading data")
  local dataset = get_dataset(db, tokenizer, sentences_model, args)

  print("Splitting & packing")
  local n_train = num.floor(dataset.total * args.train_test_ratio)
  local n_test = dataset.total - n_train

  local train_indices, train_tokens = split_dataset(dataset, 1, n_train)
  local test_indices, test_tokens = split_dataset(dataset, n_train + 1, n_train + n_test)

  print("Token Bits", dataset.token_bits)
  print("Output Bits", dataset.output_bits)
  print("Total Train", n_train)
  print("Total Test", n_test)

  local t = tm.recurrent_encoder(
    args.output_bits, dataset.token_bits, args.clauses,
    args.state_bits, args.threshold, args.boost_true_positive)

  print("Training")
  for epoch = 1, args.epochs do

    local start = os.time()
    tm.train(t, n_train, train_indices, train_tokens,
      args.specificity, args.drop_clause,
      args.margin, args.scale_loss,
      args.scale_loss_min, args.scale_loss_max)
    local duration = os.time() - start

    if epoch == args.epochs or epoch % args.evaluate_every == 0 then
      local train_score = tm.evaluate(t, n_train, train_indices, train_tokens, args.margin)
      local test_score = tm.evaluate(t, n_test, test_indices, test_tokens, args.margin)
      str.printf("Epoch %-4d  Time %d  Test %4.2f  Train %4.2f\n",
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
  create_encoder = create_encoder
}
