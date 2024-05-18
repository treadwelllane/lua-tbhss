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

  local triplets = db.get_sentence_triplets(sentences_model.id)

  if args.max_records then
    triplets = it.take(args.max_records, triplets)
  end

  triplets = it.collect(triplets)

  for i = 1, #triplets do
    local s = triplets[i]
    local a = tokenizer.tokenize(s.anchor)
    local n = tokenizer.tokenize(s.negative)
    local p = tokenizer.tokenize(s.positive)
    if a and n and p then
      arr.push(a_lens, #a)
      arr.push(n_lens, #n)
      arr.push(p_lens, #p)
      arr.push(a_data, a)
      arr.push(n_data, n)
      arr.push(p_data, p)
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
    total = #a_lens,
    token_bits = token_bits,
    output_bits = args.output_bits,
  }

end

local function split_dataset (dataset, s, e)

  local a_lens, n_lens, p_lens = {}, {}, {}
  local a_offsets, n_offsets, p_offsets = { 0 }, { 0 }, { 0 }
  for i = s, e do
    arr.push(a_lens, dataset.a_lens[i])
    arr.push(a_offsets, a_offsets[#a_offsets] + dataset.a_lens[i])
    arr.push(n_lens, dataset.n_lens[i])
    arr.push(n_offsets, n_offsets[#n_offsets] + dataset.n_lens[i])
    arr.push(p_lens, dataset.p_lens[i])
    arr.push(p_offsets, p_offsets[#p_offsets] + dataset.p_lens[i])
  end
  a_lens = mtx.raw(mtx.create(a_lens), 1, 1, "u32")
  n_lens = mtx.raw(mtx.create(n_lens), 1, 1, "u32")
  p_lens = mtx.raw(mtx.create(p_lens), 1, 1, "u32")
  a_offsets = mtx.raw(mtx.create(a_offsets), 1, 1, "u32")
  n_offsets = mtx.raw(mtx.create(n_offsets), 1, 1, "u32")
  p_offsets = mtx.raw(mtx.create(p_offsets), 1, 1, "u32")

  local a_data, n_data, p_data = {}, {}, {}
  for i = s, e do
    arr.extend(a_data, dataset.a_data[i])
    arr.extend(n_data, dataset.n_data[i])
    arr.extend(p_data, dataset.p_data[i])
  end
  a_data = bm.raw_matrix(a_data, dataset.token_bits)
  n_data = bm.raw_matrix(n_data, dataset.token_bits)
  p_data = bm.raw_matrix(p_data, dataset.token_bits)

  return a_lens, a_offsets, a_data,
         n_lens, n_offsets, n_data,
         p_lens, p_offsets, p_data

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

  local train_a_lens, train_a_offsets, train_a_data,
        train_n_lens, train_n_offsets, train_n_data,
        train_p_lens, train_p_offsets, train_p_data = split_dataset(dataset, 1, n_train)

  local test_a_lens, test_a_offsets, test_a_data,
        test_n_lens, test_n_offsets, test_n_data,
        test_p_lens, test_p_offsets, test_p_data = split_dataset(dataset, n_train + 1, n_train + n_test)

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
    tm.train(t,
      n_train,
      train_a_lens, train_a_offsets, train_a_data,
      train_n_lens, train_n_offsets, train_n_data,
      train_p_lens, train_p_offsets, train_p_data,
      args.specificity, args.drop_clause,
      args.margin, args.scale_loss,
      args.scale_loss_min, args.scale_loss_max)
    local duration = os.time() - start

    if epoch == args.epochs or epoch % args.evaluate_every == 0 then
      local train_score = tm.evaluate(t,
        n_train,
        train_a_lens, train_a_offsets, train_a_data,
        train_n_lens, train_n_offsets, train_n_data,
        train_p_lens, train_p_offsets, train_p_data,
        args.margin)
      local test_score = tm.evaluate(t,
        n_test,
        test_a_lens, test_a_offsets, test_a_data,
        test_n_lens, test_n_offsets, test_n_data,
        test_p_lens, test_p_offsets, test_p_data,
        args.margin)
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
