local serialize = require("santoku.serialize") -- luacheck: ignore
local tm = require("santoku.tsetlin")
local arr = require("santoku.array")
local err = require("santoku.error")
local utc = require("santoku.utc")
local fs = require("santoku.fs")
local str = require("santoku.string")
local bm = require("santoku.bitmap")
local mtx = require("santoku.matrix")
local json = require("cjson")
local modeler = require("tbhss.modeler")

local function get_dataset (modeler, fp, labels)
  print("Loading sentence samples")
  local has_labels = labels
  local labels = has_labels or { n = 0, id_to_label = {}, label_to_id = {} }
  local ss = {}
  local ps = {}
  for r in fs.lines(fp) do
    local label, sample = str.match(r, "(%d)\t(.*)")
    local label_id = labels.label_to_id[label]
    if not label_id and has_labels then
      err.error("unexpected label", label, label_id)
    elseif not label_id then
      label_id = labels.n
      labels.n = labels.n + 1
      labels.label_to_id[label] = label_id
      labels.id_to_label[label_id] = label
    end
    arr.push(ss, label_id)
    arr.push(ps, sample)
  end
  print("Encoding samples")
  local n = #ps
  print("Modeling")
  ps = modeler.model(ps)
  print("Flip interleave")
  ps = bm.flip_interleave(ps, n, modeler.hidden)
  print("Raw")
  ps = bm.raw(ps, n * modeler.hidden * 2)
  ss = mtx.raw(mtx.create(ss), nil, nil, "u32")
  return n, ps, ss, labels, modeler.hidden
end

local function create (db, args)

  if db.classifier_exists(args.name) then
    return err.error("Classifier exists", args.name)
  end

  print("Creating classifier")
  local modeler = modeler.open(db, args.modeler)

  print("Loading train")
  local n_train, ps_train, ss_train, labels =
    get_dataset(modeler, args.samples[1])

  print("Loading test")
  local n_test, ps_test, ss_test =
    get_dataset(modeler, args.samples[2], labels)

  print("Input Bits", modeler.hidden * 2)
  print("Labels", labels.n)
  print("Total Train", n_train)
  print("Total Test", n_test)

  print("Creating classifier")
  local classifier = tm.classifier({
    classes = labels.n,
    features = modeler.hidden,
    clauses = args.clauses,
    state = args.state,
    target = args.target,
    replicas = args.replicas,
    threads = args.threads,
    boost = args.boost,
    specificity_low = args.specificity_low,
    specificity_high = args.specificity_high,
    evaluate_every = args.evaluate_every,
  })

  print("Training classifier")
  local stopwatch = utc.stopwatch()
  classifier.train({
    problems = ps_train,
    solutions = ss_train,
    samples = n_train,
    negatives = args.negatives,
    active = args.active,
    iterations = args.iterations,
    each = function (epoch)
      local duration, total = stopwatch()
      if epoch == args.epochs or epoch % args.evaluate_every == 0 then
        local train_score = classifier.evaluate({
          problems = ps_train,
          solutions = ss_train,
          samples = n_train
        })
        local test_score = classifier.evaluate({
          problems = ps_test,
          solutions = ss_test,
          samples = n_test
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
  classifier.persist(cfp)

  db.add_classifier(args.name, modeler.name, json.encode(labels), cfp)

end

local function open (db, name)
  local c = db.get_classifier(name)
  if not c then
    return err.error("Classifier not found", name)
  end
  c.labels = json.decode(c.labels)
  c.modeler = modeler.open(db, c.modeler)
  c.classifier = tm.load(c.classifier)
  c.classify = function (a)
    a = c.modeler.model(a)
    a = bm.extend_flipped(a, modeler.hidden)
    a = bm.raw(a, modeler.hidden * 2)
    a = c.classifier.predict(a)
    return c.labels[a]
  end
  return c
end

return {
  create = create,
  open = open,
}
