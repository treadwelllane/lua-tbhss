local serialize = require("santoku.serialize") -- luacheck: ignore
local tm = require("santoku.tsetlin")
local it = require("santoku.iter")
local fs = require("santoku.fs")
local str = require("santoku.string")
local arr = require("santoku.array")
local rand = require("santoku.random")
local num = require("santoku.num")
local err = require("santoku.error")

local tbhss = require("tbhss")

local function get_dataset (db, tokenizer, sentences_model, args)

  local anchors = {}
  local negatives = {}
  local positives = {}

  local triplets = it.collect(db.get_sentence_triplets(sentences_model.id))

  print("Shuffling")
  rand.seed()
  arr.shuffle(triplets)

  for i = 1, #triplets do
    local s = triplets[i]
    local a = tokenizer.tokenize(s.anchor)
    local n = tokenizer.tokenize(s.negative)
    local p = tokenizer.tokenize(s.positive)
    if a and n and p then
      arr.push(anchors, a)
      arr.push(negatives, n)
      arr.push(positives, p)
      if (args.max_records and args.max_records > 0) and #anchors >= args.max_records then
        break
      end
    end
  end

  return {
    anchors = anchors,
    negatives = negatives,
    positives = positives,
    total = #anchors,
    token_bits = tokenizer.clusters_model.clusters,
    output_bits = args.output_bits,
  }

end

local function split_dataset (dataset, s, e)
  local as = arr.copy({}, dataset.anchors, 1, s, e)
  local ns = arr.copy({}, dataset.negatives, 1, s, e)
  local ps = arr.copy({}, dataset.positives, 1, s, e)
  return as, ns, ps
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
  local train_as, train_ns, train_ps = split_dataset(dataset, 1, n_train)
  local test_as, test_ns, test_ps = split_dataset(dataset, n_train + 1, n_train + n_test)

  print("Token Bits", dataset.token_bits)
  print("Output Bits", dataset.output_bits)
  print("Total Train", n_train)
  print("Total Test", n_test)

  local t = tm.recurrent_encoder(
    args.output_bits, dataset.token_bits, args.clauses,
    args.state_bits, args.threshold, args.boost_true_positive)

  print("Training")
  for epoch = 1, args.epochs do

    local start = os.clock()
    tm.train(t, train_as, train_ns, train_ps,
      args.specificity, args.drop_clause,
      args.margin, args.scale_loss,
      args.scale_loss_min, args.scale_loss_max)
    local duration = os.clock() - start

    if epoch == args.epochs or epoch % args.evaluate_every == 0 then
      local train_score = tm.evaluate(t, train_as, train_ns, test_ps, args.margin)
      local test_score = tm.evaluate(t, test_as, test_ns, test_ps, args.margin)
      str.printf("Epoch %-4d  Time %f  Test %4.2f  Train %4.2f\n",
        epoch, duration, test_score, train_score)
    else
      str.printf("Epoch %-4d  Time %f\n",
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
