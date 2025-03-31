local serialize = require("santoku.serialize") -- luacheck: ignore
local tm = require("santoku.tsetlin")
local arr = require("santoku.array")
local utc = require("santoku.utc")
local fs = require("santoku.fs")
local str = require("santoku.string")
local bm = require("santoku.bitmap")
local mtx = require("santoku.matrix")
local json = require("cjson")
local modeler = require("tbhss.modeler")
local util = require("tbhss.util")

local function get_dataset (modeler, bits, fp)
  print("Loading sentence samples")
  local label_id_next = 1
  local labels = {}
  local samples = {}
  local bms = {}
  for line in fs.lines(fp) do
    local chunks = str.gmatch(line, "[^\t\n]+")
    local label = chunks()
    local sample = chunks()
    local samplef = bms[sample] or modeler.model(sample)
    bms[sample] = samplef
    local label_id = labels[label]
    if not label_id then
      label_id = label_id_next
      label_id_next = label_id_next + 1
      labels[label] = label_id
      labels[label_id] = label
    end
    arr.push(samples, { label = label_id, sample = samplef })
  end
  return {
    samples = samples,
    n_labels = label_id_next - 1,
    labels = labels,
    bits = bits,
  }
end

local function pack_dataset (dataset)
  local ss = {}
  local ps = {}
  for i = 1, #dataset.samples do
    local p = dataset.samples[i]
    local problem = util.prep_fingerprint(p.sample, dataset.bits)
    local solution = p.label - 1 -- TODO: annoying that tsetlin is 0 and lua is 1-based
    ps[i] = problem
    ss[i] = solution
  end
  ss = mtx.create(ss)
  return
    bm.raw_matrix(ps, dataset.bits * 2),
    mtx.raw(ss, nil, nil, "u32")
end

local function create (db, args)

  print("Creating classifier")
  local modeler = modeler.open(db, args.modeler)

  print("Loading train")
  local train_dataset = get_dataset(modeler, modeler.hidden, args.samples[1])
  local train_problems, train_solutions = pack_dataset(train_dataset)

  print("Loading test")
  local test_dataset = get_dataset(modeler, modeler.hidden, args.samples[2])
  local test_problems, test_solutions = pack_dataset(test_dataset)

  print("Input Bits", train_dataset.bits * 2)
  print("Labels", train_dataset.n_labels)
  print("Total Train", #train_dataset.samples)
  print("Total Test", #test_dataset.samples)

  print("Creating classifier")
  local t = tm.classifier({
    classes = train_dataset.n_labels,
    features = train_dataset.bits * 2,
    clauses = args.clauses,
    state_bits = args.state_bits,
    target = args.target,
    boost_true_positive = args.boost_true_positive,
    spec_low = args.spec_low or args.specificity[1],
    spec_high = args.spec_high or args.specificity[2],
    evaluate_every = args.evaluate_every,
  })

  print("Training classifier")
  local stopwatch = utc.stopwatch()
  t.train({
    problems = train_problems,
    solutions = train_solutions,
    samples = #train_dataset.samples,
    active_clause = args.active_clause,
    iterations = args.iterations,
    each = function (epoch)
      local duration, total = stopwatch()
      if epoch == args.epochs or epoch % args.evaluate_every == 0 then
        local train_score = t.evaluate({
          problems = train_problems,
          solutions = train_solutions,
          samples = #train_dataset.samples
        })
        local test_score = t.evaluate({
          problems = test_problems,
          solutions = test_solutions,
          samples = #test_dataset.samples
        })
        str.printf("Epoch %-4d   Time  %6.2f  %6.2f   Test %4.2f  Train %4.2f\n",
          epoch, duration, total, test_score, train_score)
      else
        str.printf("Epoch %-4d   Time  %6.2f  %6.2f\n",
          epoch, duration, total)
      end
    end
  })

  local cfp = fs.join(fs.dirname(db.file), args.name .. ".classifier.bin")
  t.persist(cfp)

  db.add_classifier(args.name, modeler.name, json.encode(train_dataset.labels), cfp)

end

local function open (db, name)
  local c = db.get_classifier(name)
  c.labels = json.decode(c.labels)
  c.modeler = modeler.open(db, c.modeler)
  c.classifier = tm.load(c.classifier)
  c.classify = function (a)
    a = util.prep_fingerprint(c.modeler.model(a), c.modeler.hidden)
    local id = c.classifier.predict(a)
    return id and c.labels[id]
  end
  return c
end

return {
  create = create,
  open = open,
}
