local serialize = require("santoku.serialize") -- luacheck: ignore
local tm = require("santoku.tsetlin")
local arr = require("santoku.array")
local err = require("santoku.error")
local utc = require("santoku.utc")
local fs = require("santoku.fs")
local str = require("santoku.string")
local bm = require("santoku.bitmap")
local modeler = require("tbhss.modeler")
local util = require("tbhss.util")

local function get_baseline (dataset)
  local correct = 0
  for i = 1, #dataset.triplets do
    local t = dataset.triplets[i]
    local dn = bm.hamming(t.a, t.n)
    local dp = bm.hamming(t.a, t.p)
    if dp < dn then
      correct = correct + 1
    end
  end
  return correct / #dataset.triplets
end

local function get_dataset (modeler, bits, fp)
  print("Loading sentence triplets")
  local triplets = {}
  local bms = {}
  for line in fs.lines(fp) do
    local chunks = str.gmatch(line, "[^\t]+")
    local a = chunks()
    local n = chunks()
    local p = chunks()
    local af = bms[a] or util.prep_fingerprint(modeler.model(a), bits)
    bms[a] = af
    local nf = bms[n] or util.prep_fingerprint(modeler.model(n), bits)
    bms[n] = nf
    local pf = bms[p] or util.prep_fingerprint(modeler.model(p), bits)
    bms[p] = pf
    arr.push(triplets, {
      a = af,
      n = nf,
      p = pf
    })
  end
  return {
    triplets = triplets,
    bits = bits,
  }
end

local function pack_dataset (dataset)
  local gs = {}
  for i = 1, #dataset.triplets do
    local s = dataset.triplets[i]
    arr.push(gs, s.a, s.n, s.p)
  end
  return bm.raw_matrix(gs, dataset.bits * 2)
end

local function create (db, args)

  if db.encoder_exists(args.name) then
    return err.error("Encoder exists", args.name)
  end

  print("Creating triplet encoder")
  local modeler = modeler.open(db, args.modeler)

  print("Loading train")
  local train_dataset = get_dataset(modeler, modeler.hidden, args.triplets[1])
  local train_data = pack_dataset(train_dataset)

  print("Loading test")
  local test_dataset = get_dataset(modeler, modeler.hidden, args.triplets[2])
  local test_data = pack_dataset(test_dataset)

  print("Calculating baselines")
  local train_baseline = get_baseline(train_dataset)
  local test_baseline = get_baseline(test_dataset)

  print("Input Bits", train_dataset.bits)
  print("Encoded Bits", args.hidden)
  print("Total Train", #train_dataset.triplets)
  print("Total Test", #test_dataset.triplets)

  local encoder = tm.encoder({
    visible = train_dataset.bits,
    hidden = args.hidden,
    clauses = args.clauses,
    state_bits = args.state_bits,
    target = args.target,
    boost_true_positive = args.boost_true_positive,
    evaluate_every = args.evaluate_every,
  })

  print("Training")
  str.printf("Baseline  Test %4.2f  Train %4.2f\n", test_baseline, train_baseline)
  local stopwatch = utc.stopwatch()
  encoder.train({
    corpus = train_data,
    samples = #train_dataset.triplets,
    active_clause = args.active_clause,
    loss_alpha = args.loss_alpha,
    margin = args.margin,
    iterations = args.iterations,
    each = function (epoch)
      local duration, total = stopwatch()
      if epoch == args.epochs or epoch % args.evaluate_every == 0 then
        local train_score = encoder.evaluate({
          corpus = train_data,
          samples = #train_dataset.triplets,
          margin = args.margin
        })
        local test_score = encoder.evaluate({
          corpus = test_data,
          samples = #test_dataset.triplets,
          margin = args.margin
        })
        str.printf("Epoch %-4d   Time  %6.2f  %6.2f   Test %4.2f  Train %4.2f\n",
          epoch, duration, total, test_score, train_score)
      else
        str.printf("Epoch %-4d   Time  %6.2f  %6.2f\n",
          epoch, duration, total)
      end
    end
  })

  local efp = fs.join(fs.dirname(db.file), args.name .. ".encoder.bin")
  encoder.persist(efp)

  db.add_encoder(args.name, modeler.name, efp)

end

local function open (db, name)
  local e = db.get_encoder(name)
  if not e then
    return err.error("Encoder not found", name)
  end
  e.modeler = modeler.open(db, e.modeler)
  e.encoder = tm.load(e.encoder)
  e.encode = function (a)
    a = util.prep_fingerprint(e.modeler.model(a), e.modeler.hidden)
    return e.encoder.predict(a)
  end
  return e
end

return {
  create = create,
  open = open,
}
